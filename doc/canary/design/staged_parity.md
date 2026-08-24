# Staged parity — build vs install as a checking principle

**Kind: rationale + to-dos.** §1 records what landed; §4's four boxes are the open work and are also carried by `../project/status_project.md`.

**2026-08-18, revised 2026-08-19. A cross-agent brief: what landed, what
it means, what to track.**

## 1. What landed — the staged consumer is a WORLD

The **installed-consumer** arc (user directive: "whether a
lib-built-to-install is a separate provider, so that the binding also
needs to be built from it") landed in two steps, and the second one
answers the directive literally: the staged lib IS a separate provider,
so it takes its own row.

**Step 1 (`9083d3b`, retired)** made it a realization policy:
`consumer_lib = Build_tree | Installed` in `canary_basic`,
`run_config.consumer_lib`, a `--installed` flag, and an optional
`?consumer_lib` parameter on every project's `pr_runner_spec`. One
scenario, two possible realizations.

**Step 2 (`bf5e892` general + sqlite, `2f36e2d` z3)** made it an
enumeration axis and deleted step 1 entirely:

- `provision` gained `Installed` (base vocabulary) with **built-family**
  semantics — an Installed world fetches and builds exactly like a Built
  one, then stages. One build serves both faces.
- A project opts in by declaring it: sqlite's lib row carries
  `(Installed, [Stable; Dev])`, z3's `(Installed, [Dev])`.
- Row-level exclusivity is `ar_needs : provision option` on
  `action_row`: the `Install_lib` row and the staged probe gate
  `Some Installed`, so the Built world runs neither and keeps the
  build-tree probe. The build rows stay ungated (the family fires them).
- The consumer's paths come off the assignment: sqlite's probe env
  points at `<ws>/install/lib`, z3's OCaml probe reads
  `<prefix>/lib/ocaml/z3/z3ml.cmxa` + `<prefix>/lib/libz3.so`.
- The #10549 bug is declared ON THE CONSUMER: the pre-10549 **Installed
  world** xfails at install and at probe (`STAGED PACKAGE MISSING:
  .../z3ml.a`), while its Built twin passes — the same bug, visible or
  invisible depending on which face you consume.
- `pr_runner_spec` is back to
  `assignment -> workspace:string -> unit -> runner_spec`. **⚠
  Compile-facing for in-flight landings**: drop the `?consumer_lib`
  parameter (it no longer exists); nothing replaces it — read the lib's
  provision from the assignment if a realization needs to branch.

Pins: `sqlite.provider_rows` + `z3.provider_rows` (the general factory,
derived per source-ref group), `sqlite.staged_probe_paths` +
`z3.installed_probe_consumes_prefix` (the realizations),
`z3.regression_pre_10549_expectation` (the declared xfails, quantified
over worlds).

Live: sqlite 5/5; z3's `--refs latest,pre-10549` = 2 builds + their 2
staged faces (latest passes staged, pre-10549 double-xfails).

## 2. The general question

"How may a common project have these different binaries? Can we always
use a binary-for-install to shadow the binary purely built?"

The install is a **copy-transform step** executed on the build output
(`cmake --install` runs the generated `cmake_install.cmake` scripts
produced from the source's `install(...)` rules — no compilation). The
transform is where the two faces diverge. The known divergence classes:

| class | mechanism | example |
| --- | --- | --- |
| **A. identity transforms** | strip (debug info removed / `.dSYM` extracted on macOS), mode changes (exec bit 755→644), the versioned symlink chain is RE-SYNTHESIZED by the install rules (NAMELINK), RPATH/RUNPATH rewritten (`patchelf`, cmake `file(RPATH_CHANGE)`, `install_name_tool -change` on macOS), `LC_ID_DYLIB`/DT_SONAME set to the installed identity | z3's install strips the exec bit; PR #10549 adds an `install(CODE)` block that rewrites the installed dylib's rpath on macOS |
| **B. content selection** | install rules pick a SUBSET / different layout (private headers excluded, `lib/ocaml/z3/` vs `src/api/ml/`); install-ONLY generated files (cmake `Config/Targets` exports, `z3.pc`, ocamlfind META, module maps) | the OCaml package files exist only at their installed location |
| **C. missing rules** | a build product has NO install rule at all — the build tree has it, the prefix never gets it | **the #10549 class** (pre-fix `lib/ocaml/z3/` never staged) |
| **D. relocation failure** | baked-in build-tree absolute paths that break outside the tree: `$CAMLORIGIN/../..`, `-L<build>/lib` in cmxa/`.la`, RPATH pointing at the build dir, `config.h` prefix paths, un-substituted pkg-config `prefix=` | the LLVM cmxa `$CAMLORIGIN/../..` gotcha (CLAUDE.md) |
| **E. platform invariants, often violated** | macOS: install_name must be the INSTALLED name (`@rpath/...`), code signing lost on copy, ad-hoc re-signing, universal binaries, hardened runtime; ELF: SONAME/version-script consistency | the user's "mac installation tricky which many artifacts to install failed to hold" |
| **F. accumulation / isolation** | `cmake --install` never cleans — repeated installs MERGE (stale versions coexist); shared prefixes let one world's install merge into another's | **live finding 2026-08-18**: `z3-all/install` (shared by the contrib refs) holds a stale `libz3.so.4.15.5.0` from an old run beside the 5.1 chain |

Answer to "can the installed binary always shadow the built one": for
CONSUMER-side checks, yes — the staged artifact is what a downstream
project actually receives, so it is the authoritative consumer fact
(the Installed policy is the general default for probes). But it must
not be trusted blindly: it is itself the product of a transform that
can lose parts (C), break paths (D), or be stale/contaminated (F). So
the general shape is **shadow + verify**: the build-tree probe proves
the build produces a working artifact; the staged probe proves the
install PRESERVES it. If the pair diverges, the bug is in the install
step — that bracketing is the check.

## 3. The checking principle: staged parity

For every declared consumer-facing build product, the staged image must
satisfy:

1. **Completeness** — the artifact stages. Generalize z3's
   `assert_staged` (a hand list `[lib/ocaml/z3/META; z3ml.cmxa]`) to
   DERIVE from the declared artifact surface: every provider claim maps
   to expected staged paths.
2. **Integrity** — the platform invariants hold IN the staged file:
   SONAME / `LC_ID_DYLIB` = installed identity (not the build path),
   no build-dir absolute paths in RPATH/RUNPATH or package metadata,
   symlink chain intact, exec modes correct, signature valid (macOS).

   **The portability falsifier** (user, 2026-08-18): a binary staged
   for install shall never contain ANY concrete path of the building
   tree — a baked-in build path means the installable binary is not
   portable (divergence class D, checked as data: grep the staged
   artifact's metadata/strings for the build prefix). Special case
   for mac: some Mach-O installation paths must be patched AFTER the
   binary is moved (very hacky) — mark as a declared exception since
   we are Linux-only for now.
3. **Parity** — build vs staged surface equality: symbol-set diff
   (`nm -D`), version equality, hash equality MODULO declared
   transforms (strip/mode). Any divergence is either a declared
   transform or a bug.
4. **Isolation** — per-WORLD install prefixes: each scenario's staged
   artifact must be its own concrete fact. Today z3's contrib refs
   share `z3-all/install` (finding F) — the future model's enumerable
   installed-provider requires per-world prefixes, or one ref's install
   contaminates another's.

The existing primitives this generalizes: `Cmake_install.assert_staged`
(completeness, hand-list), z3's `probe_lib_staged` step (a staged
NATIVE probe), and the new Installed consumer policy (a staged
CONSUMER probe). The parity checker would attach to `Install_lib` as a
check_post family.

## 4. What to track (see `doc/canary/project/status_project.md`)

- [ ] The staged-parity checker (4 checks above; completeness derived
      from the declared surface instead of a hand list).
- [ ] Per-world install prefixes (fix z3's shared `z3-all/install`).
- [ ] Platform-invariant fixtures in the framework-test axis (the
      user's "enough platform invariant which is often violated":
      versioned-symbol nm output, install_name, symlink-chain,
      exec-mode fixtures) — mirrors the existing ELF-symbol-versioning
      gotcha pin.
- [ ] The future model stays recorded: installed-consumed as an
      ENUMERABLE provider so the binding-BUILD ranges over
      {build-tree, installed}; `Install_lib : Lib → Lib` stays staging
      semantics.

## 5. The evidence (read-only, live)

```
build tree      build-pre-10549/libz3.so -> libz3.so.5.1 -> libz3.so.5.1.0.0   (755)
build tree      build-pre-10549/src/api/ml/{META,libz3ml.a,dllz3ml.so,z3ml.cmxa}
install prefix  z3-all/install/lib/libz3.so -> libz3.so.5.1 -> libz3.so.5.1.0.0 (644, copied)
install prefix  z3-all/install/lib/libz3.so.4.15.5.0        (STALE — finding F)
install prefix  z3-all/install/lib/ocaml/z3/                (MISSING — the #10549 bug)
install prefix  z3-all/install/lib/cmake/z3/Z3Config.cmake + lib/pkgconfig/z3.pc  (install-only)
```
