# The platform — where it enters, and what it changes

> 2026-08-26. Written while making the macOS side run, at the user's
> request: *"check the canary pipeline to dispatch based on platform …
> the canary config should carry the platform argument … for the direct
> tool using function, we need to make the mac's sibling ones."*
>
> This is the examination and the design it settled on. Scope: the two
> platforms canary knows, `wsl_ubuntu` and `macos_local`. Companion
> reading: [enumeration/README.md](enumeration/README.md) for the pass
> structure this doc classifies against, and
> [`../project/issues.md`](../project/issues.md) for what is still open.

## 0. The claim in one paragraph

A platform is **one fact about one machine**, and almost nothing in
canary needs to know it. The enumeration — what worlds a project has,
which ones a run asked for, what order they go in — is platform-agnostic
end to end: it ranges over *provisions* and *versions*, and neither has a
platform coordinate. Platform enters at exactly two boundaries: **pass 5,
realize**, where a world becomes shell commands, and the **tool wrappers**
those commands invoke. Everything else should be able to run without
knowing, and now does.

## 1. What was actually there (the examination)

### 1a. Three detectors, and they could disagree

Before this work the machine was sniffed independently in three places:

| site | mechanism | when |
| --- | --- | --- |
| `Canary_basic.detect_distro` | `uname -s \| grep Darwin` | on **every call** (~20 sites, unmemoized) |
| `Canary_store.detect_pm` | `which brew`, else `which apt-get` | memoized at first use |
| `Canary_artifact_native.is_macos` | its own `uname -s`, kept as a string | at module **load** |

Plus `inspect_native.py` asking `platform.system()` on the other side of
the pipe.

Two defects, one of them live:

- **They could disagree.** `detect_pm` tried brew *first*, so a Linux box
  with Linuxbrew installed answers `Brew` while `detect_distro` answers
  `Wsl`. `system_pkg_for_pm` keys on the *pm*, so that machine would pick
  the **macOS package name on Linux**. Nothing in the type system said
  those two answers were about the same fact.
- **Nobody could state it.** There was no way to say "render this for the
  other platform" — every consumer re-asked the machine, so a dump was
  always about the machine that produced it.

### 1b. What actually varies

The audit, by category. This is the whole of it:

| category | varies how | where |
| --- | --- | --- |
| **Loader search path** | `LD_LIBRARY_PATH` / `DYLD_LIBRARY_PATH` | probe commands in 6 modules |
| **Object format** | ELF/Mach-O: `nm -D` vs `-g`, symbol `_` prefix, `readelf -d` vs `otool -l`, SONAME vs install_name, `patchelf` vs `install_name_tool` | `canary_artifact_native`, `canary_artifact_mutation`, `inspect_native.py` |
| **Library naming** | `libfoo.so.1` vs `libfoo.1.dylib` — the version is on **opposite sides** of the extension | tiny (~40 sites, still ELF-only) |
| **System package manager** | apt/dpkg vs brew | `canary_pm_*`, `system_package_spec` |
| **Library locator** | `/usr/lib/x86_64-linux-gnu/…` vs `$(brew --prefix …)/lib` | `lib_locator` in project specs |
| **Prebuilt archive** | conda-forge `linux-64` vs `osx-arm64` | `Canary_prebuilt.t` |
| **Loader evidence** | `/proc/self/maps` vs `DYLD_PRINT_LIBRARIES` | zlib/zstd probe examples |
| **Machine home** | `/home/red/code` vs `/Users/ex/code` | `distro_base` |
| **Shell utilities** | GNU vs BSD `sed`; GNU vs Apple `patch` | mutation engine, patch oracle |

What does **not** vary, checked rather than assumed: `cmake`, `ninja`,
`make`, `dune`, `opam`, `ocamlfind`, `git`, `curl`, `tar`, `python3`,
`pkg-config`, and the link-time variables `LIBRARY_PATH` /
`CAML_LD_LIBRARY_PATH`. The generic build tooling really is generic; it
is the *store* and the *object format* that differ.

## 2. The design: config carries it, three consumption modes

### 2a. One value

`Canary_store.platform ()` is now the single answer — detected at most
once, overridable, and reported. `distro` stays the type: it was already
the codebase's name for "which machine" (it carries `distro_base`), and
[the base-vocabulary rule](../../../CLAUDE.md) says reconcile with the
existing type rather than invent a second one.

The system PM is **derived** from it (`system_pm_of_platform`) rather
than sniffed beside it, which makes the Linuxbrew disagreement
unrepresentable. `Canary_basic.detect_distro` and
`Canary_artifact_native.is_macos` are now forwarding aliases, not second
opinions.

It is an **argument**, not just a detection: `--platform=macos|wsl` on any
subcommand (consumed before cmdliner, like `--switch`), or
`CANARY_PLATFORM`. `Canary_project_run.run_config` carries it as a field
beside `policy` and `refs`, so a config is a complete description of what
a run was.

And it is **reported**: the run header prints it (marked when
overridden), `actions.log` gets a `platform` event per command, and it is
part of the **step fingerprint** — a verdict earned on one platform is
never served to the other.

### 2b. The three modes, mapped to real code

The user's framing, filled in:

| mode | meaning | examples |
| --- | --- | --- |
| **agnostic** | never sees the platform | passes 1–4 (`Canary_pipeline.spec_of` / `enumerated` / `ordered`), the enumeration algebra, contract theory (`canary_compat`), detection (`canary_detect`), spec-check |
| **parameterized** | takes it as an argument | `Canary_prebuilt.{path_of,libdir_of,build_of}`, `Canary_artifact_source.{mk_locals,local_for}`, `Canary_store.{distro_base,contrib_root}` — all already `distro -> …` |
| **dispatched** | asks the one value and branches | the tool wrappers: `ld_path_var`, `nm_dynamic_flag`, `c_symbol_prefix`, `dylib_ext`, `shared_lib_name`, `ld_trace_env`, `set_recorded_name_cmd`, `platform_suffix` |

The dividing line is real and worth keeping: **passes 1–4 must stay in
the first column.** A world is a choice of provisions and versions; if the
platform ever leaks into enumeration, the two machines stop enumerating
the same worlds and their results stop being comparable — which is the
entire point of running both.

### 2c. Which mode to pick when adding something

- Does it decide *what worlds exist*? Then it must not see the platform.
- Is it a **path or a name** the caller already has a `distro` for?
  Parameterize — the caller usually holds one already.
- Is it a **tool invocation**? Dispatch, in `base/` or `tool/`, as a
  named function with the two branches beside each other. Never inline
  `if is_macos` at the call site: the point of a named sibling is that
  the two answers are read together and can be pinned.

## 3. Tool siblings — the status table

"Direct tool using functions", per the user's phrasing, and whether the
macOS sibling exists.

| concern | Linux | macOS | status |
| --- | --- | --- | --- |
| exported symbols | `nm -D` | `nm -g` | ✅ `nm_dynamic_flag` |
| C symbol spelling | bare | `_`-prefixed | ✅ `c_symbol_prefix` + `inspect_native.py --strip-leading-underscore` |
| L4 ABI record | `readelf -d` | `otool -l` | ✅ `inspect_native.py:parse_abi` — same four fields |
| record own name | `patchelf --set-soname` | `install_name_tool -id @rpath/…` | ✅ tool dispatched; **name shape still ELF-only** |
| drop rpath | `patchelf --remove-rpath` | *not needed* | ✅ measured: `DYLD_LIBRARY_PATH` beats `@rpath` anyway |
| loader search path | `LD_LIBRARY_PATH` | `DYLD_LIBRARY_PATH` | ✅ `ld_path_var` / `ld_prepend` / `ld_only` |
| loader evidence | `/proc/self/maps` (probe reads it) | `DYLD_PRINT_LIBRARIES=1` (dyld prints it) | ✅ `ld_trace_env` — same `Log_names` assert |
| installed pkg version | `dpkg-query -W` | `brew list --versions` | ✅ `Canary_pm.installed_version_cmd` |
| install / verify pkg | apt | brew | ✅ pre-existing `Canary_pm` dispatch |
| resolve system lib | multilib glob + `dpkg -L` + `ldconfig -p` | `$(brew --prefix)/lib` | ✅ union-of-fallbacks (see §4) |
| in-place text edit | GNU `sed -i -E` | — | ✅ replaced by `perl -i` on **both** |
| apply a patch | GNU `patch` (fuzz) | Apple `patch 2.0` (strict) | ✅ fixtures regenerated to apply exactly on both |
| symbol versioning | version script + `@@VER` | **no referent** | ⛔ see `issues.md` |
| shared-lib filename | `libfoo.so.1` | `libfoo.1.dylib` | ⚠ `shared_lib_name` exists; tiny does not use it |

### The union-of-fallbacks pattern

`Pm_lib` (`canary_action_templates.ml`) is a third shape worth naming: it
does **not** dispatch. It declares `dpkg_pkg`, `ldconfig_name` *and*
`brew_pkg`, and emits all of them as a `test -f "$LIB" || LIB=$(…)`
cascade. One command text, correct on both, because a locator that finds
nothing costs nothing. It is the right pattern when the tools are *probes*
rather than *actions* — no side effects, cheap to attempt, and the
command stays byte-identical across platforms so the fingerprint agrees.
Prefer it to dispatch for locators; do not use it for anything that
mutates.

## 4. Project specs — is the command platform-dependent?

Audited across all ten projects. The answer the user guessed is the right
one: **the build commands are generic; the store and the locator are
not.**

| what a spec declares | platform-dependent? |
| --- | --- |
| build commands (`cmake`, `ninja`, `dune`, `make`) | no |
| opam / pip package names and pins | no |
| source repos, refs, worktree layout | no (paths parameterized by `distro`) |
| watchlists, api_source, contract bindings | no — these are facts about the *library*, not the machine |
| `system_package_spec` | **yes**, declared as a `linux_pkg` / `macos_pkg` pair |
| `lib_locator` | **yes**, declared as `linux_glob` / `brew_pkg` + `brew_dylib` |
| `Canary_prebuilt.t` | **yes**, now a `build` per platform |

So a project spec expresses platform-dependence **declaratively, as
pairs** — never as a branch in project code. That is worth holding onto:
it means a new project author states two package names and two locators
and is done, and it means `spec` can render either platform's view from
one machine.

Two exceptions, both recorded rather than hidden:

- **z3** resolves its system lib with `pkg-config` → `dpkg -L` →
  `ldconfig -p` over `libz3.so`, in a hand-written shell cascade rather
  than through `Pm_lib`. It is Linux-only and deliberately un-ported —
  renaming its loader variable alone would advertise a portability it
  does not have. z3 is muted; it gets ported whole or not at all.
- **zlib / zstd** print `… resolved: <path>` from `/proc/self/maps`. On
  macOS the examples degrade honestly (`unknown (no /proc/self/maps)`)
  and `ld_trace_env` supplies dyld's own trace instead, so the assert
  survives — but the *example source* is still Linux-shaped.

## 5. What "making the macOS side run" reached

Green on macOS: `project-test 113/113`, `artifact-test 109/109`,
`pm-test 14/14`, `mutation-test 46/46`. `canary spec`, `spec-check @all`,
`result`, `emit` and `prebuilt` all work; all four conda-forge prebuilts
download and unpack with their globs matching real Mach-O dylibs.

Not yet: **tiny** (`canary tiny run`, and tiny-full's vendored
artifacts), because `libtiny.so.1` is spelled out in ~40 declarations.
Its C library now *links* on macOS — the version script is guarded — but
its names are not built through `shared_lib_name`. That is the largest
remaining piece and it is self-contained.

Not attempted: **z3**, above.

## 6. Cross-rendering, and how the WSL side should check this

The override exists so that one machine can show what the other will do.
It reaches the whole pipeline — verified end to end:

```console
$ canary result zlib --md | grep -o '| brew [^|]*'
| brew zlib.1.3.2

$ canary --platform=wsl result zlib --md | grep -o '| apt [^|]*'
| apt zlib1g-dev
```

**A hypothetical render is not a record.** Found by doing it: the first
`--platform=wsl result` on the mac overwrote `docs/…/matrix.html` — the
WSL box's *committed* record — with a matrix the mac had produced,
because the tracked filename is chosen by the SELECTED platform. That is
exactly the cross-machine corruption the per-platform filename exists to
prevent, arriving through the door the override opened. There is no
honest filename for it (a mac's rendering of the WSL view is neither
machine's record), so an overridden run writes the **local `_out` copy
only** and says it is skipping `docs/`. The rule: what lands in the
tracked tree is what this machine measured **about itself**.

For the WSL side picking this branch up, in order:

1. `make canary-test`, then `canary mutation-test` — the second is **not**
   in `make canary-test` and had never been run on macOS before this
   work, which is how two failures had gone unnoticed.
2. Confirm the byte-identity claim: everything in the Linux path was
   changed through helpers that reproduce the old strings exactly
   (`ld_only`/`ld_prepend`, `nm_dynamic_flag`, the linux prebuilt URLs,
   `platform_suffix () = ""`). If a step re-runs that should have been
   cached, the fingerprint change (the platform is now in the digest) is
   the expected cause — once.
3. `canary --platform=macos spec-check @all` and `canary --platform=macos
   result` — these should render the mac's view from Linux, and are the
   cheapest way to review this work without a mac.
4. The two mutation fixtures deserve a real look: `perl -i` replacing
   `sed -i -E`, and the regenerated `api_faithful.patch`. Both are
   verified against the patch oracle on macOS; the oracle is
   platform-independent, so a Linux `mutation-test` re-run is the
   confirmation.

## 7. Open

Tracked in [`../project/issues.md`](../project/issues.md):

- tiny's Mach-O naming port (~40 declarations → `shared_lib_name`);
- c5 has no Mach-O referent, and whether `compatibility_version` is c5 at
  library granularity or a new contract;
- z3's Linux-only system-lib resolution;
- the per-platform tracked-output split (`matrix_mac.html`, `<p>_mac/`)
  is a **postponement**, not the design — the real answer is a runner per
  platform feeding one aggregating viewer, which is the same question the
  fingerprint answers for the switch and the platform.

One more, not yet an issue: `run_config.platform` records the platform
but consumers still call `Canary_store.platform ()` directly rather than
reading it off the config they were handed. The two cannot disagree today
(the CLI sets the override before building any config), but threading the
config properly is what would make that structural rather than
circumstantial.
