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

## 7. The to-do

Ordered by what unblocks what. Items marked ⇢ have a home in
[`../project/issues.md`](../project/issues.md) with the full finding.

### Next, and small

1. **`spec-check --probe-pm`** *(approved 2026-08-26, not started)*. Every
   declared `system_package_spec` is a NAME nobody validates:
   `check_stable_lib` is a presence audit, so a wrong `macos_pkg` stays
   invisible until `fetch_lib` fails mid-run on that machine. The pieces
   exist and are unused — each driver has `check_available_cmd`; what is
   missing is a `Canary_pm` hub and a caller, the same shape as the
   `installed_version_cmd` gap. Opt-in flag, because `spec-check` is
   deliberately static and must stay usable offline. It would have
   reported `llvm@19` (declared, formula exists, **not installed**)
   immediately, and it is what makes a `--platform=macos` review from the
   WSL box fully trustworthy rather than half: the cross-render shows the
   declared names, not whether they are real.

   **Same shape, same second: a declared source REF.** A project declares
   a repo and a ref, and nothing validates that the ref resolves —
   `git ls-remote --exit-code <url> <ref>` answers it in 1.1s and 0 bytes
   (measured 2026-08-27). It belongs here rather than in a run: a world
   that does not build from its source no longer fetches it at all
   ([`enumeration/stage5_realize_steps.md`](enumeration/stage5_realize_steps.md)
   §3b), so
   obtainability became a claim about the DECLARATION — which is what
   `spec-check` is for.
2. **`brew install llvm@19`** on the mac — llvm's stable lib point does
   not exist here (this machine has `llvm 22.1.5`), so its pair has one
   point until then.
3. **Thread `run_config.platform`.** The field records the platform, but
   consumers still call `Canary_store.platform ()` rather than reading it
   off the config they were handed. The two cannot disagree today (the
   CLI sets the override before any config is built), so this is about
   making it structural instead of circumstantial.

### The substantial one

4. **tiny's Mach-O naming port** ⇢. `libtiny.so.1` is spelled out in ~40
   declarations — scenario recipes, the workspace materializer, the c4
   SONAME fixtures, the `Dlopen` coupling, several pins.
   `Canary_basic.shared_lib_name` knows both conventions and nothing
   calls it. Until it does, `canary tiny run` (the 22-scenario oracle)
   and tiny-full's vendored artifacts are Linux-only. The C library now
   *links* on macOS — the version script is guarded — so this is naming,
   not toolchain. Largest remaining piece, and self-contained.

### Decisions, not tasks

5. **c5 on Mach-O** ⇢ — no symbol versioning exists there, but
   `LC_ID_DYLIB`'s `compatibility_version` is a loader-enforced version
   floor at LIBRARY granularity. Is that c5 at coarser resolution, or a
   new contract? The second reading is the more interesting one for the
   manuscript: the same checking-point exists on both platforms at
   different resolution, which says something about what a surface theory
   must be parametric in. The inspector already extracts the field.
6. **The cross-platform viewer.** The per-platform tracked-output split
   (`matrix_mac.html`, `<p>_mac/`) is a POSTPONEMENT, not the design.
   The real answer is a runner per platform feeding one aggregating
   viewer — the same question the fingerprint answers for the switch and
   the platform: how does a verdict name the world it was earned in?
   Landing it means deleting `Canary_basic.platform_suffix` and its two
   call sites.

### Deliberately not doing

7. **z3** ⇢ — `pkg-config` → `dpkg -L` → `ldconfig -p` over `libz3.so`,
   in a hand-written cascade rather than through `Pm_lib`. Renaming its
   loader variable alone would advertise a portability it does not have.
   It is muted; it gets ported whole or not at all.

## 8. Confirming §2b, rather than asserting it (2026-08-26, WSL)

User: *"how about the platform affecting the enumeration? it should be
agnostic until the runner, but can we confirm that?"*

§2b says passes 1–4 never see the platform. That was a design intent
written while making the mac run; this section is the measurement.

**The answer is yes**, by two independent routes.

*Empirically, through the CLI.* For all ten catalogued projects (z3
included — it is muted, not unspecified), `emit <p> --stage
declare|enumerate|select|order --json` is **byte-identical** under
`--platform=wsl` and `--platform=macos`. Forty comparisons, no
differences.

*Mechanically, as a pin.* `platform.enumeration_is_agnostic`
(`canary project-test`) runs passes 1–4 over both platforms and compares,
for every project in the CATALOGUE.

**Two vacuity traps had to be closed, and both were real.**

1. *The invariant could hold because nothing reaches anything.* If the
   override never touched the pipeline, "identical" would be automatic.
   So the pin also asserts that a realized command DOES change — sqlite's
   step set carries `probe_lib_apt` on one platform and `probe_lib_brew`
   on the other. Surveyed once across the roster: **every project's
   realized commands differ** between the two platforms, which is pass 5
   doing its job.
2. *A spec can be FROZEN rather than agnostic.* The registry hands
   `z3_run`/`llvm_run` a literal `Wsl`, and every `project_run` is built
   at module initialization — so a declaration that honoured the platform
   would bake in one answer and then compare equal to itself forever. The
   pin therefore also REBUILDS the declaration under each platform
   (argument and ambient override) for the seven projects that expose a
   builder, which includes every prebuilt-bearing one. sqlite, tiny-full
   and ssl are eager values with no builder to call and are covered by
   the weaker check only — the one gap in the confirmation.

**What the pin compares, exactly.** The world set and its order: which
artifacts exist, at which provisions and versions, which a run selects,
in what sequence. NOT the realization data hanging off a declaration —
making a `Vendored_at` payload platform-dependent does not turn it red,
because `json_declare` reports the provision, not its origin string. That
is the right scope (an origin string is pass 5's to resolve), but it
means the claim is *both machines enumerate the same worlds*, not
*nothing below a declaration mentions a platform*. Falsified by making
the world set itself vary — dropping the Dev version point on macOS in
the Pattern-A lib row turns it red.

**One correction to the record.** A first pass at this read
`emit --stage realize` under both platforms, found zlib's and llvm's
output identical, and took that for a frozen spec. It is not: that dump
carries step tags and deps, never command text, so it cannot show a
command difference at all. sqlite's only "difference" there was its
PM-keyed step TAG. The command-level survey above is what settles it.
