# Claude Code — Project Guide

## Build & Run

```sh
dune build                          # build everything
dune exec src/bin/canary_main.exe -- paths      # print 14-row action pattern table
dune exec src/bin/canary_main.exe -- paths-md   # same, markdown output
dune exec src/bin/canary_main.exe -- graph       # write _out/canary/action_rule.mmd
dune exec src/bin/canary_main.exe -- action sqlite
dune exec src/bin/canary_main.exe -- action z3       # runs z3 (dev) + z3/stable
dune exec src/bin/canary_main.exe -- action llvm     # runs llvm (dev) + llvm/19
make canary       # run canary via Makefile shorthand
```

Output layout (gitignored via `_*`):
- `_out/canary/projects/<project>/<step>/` — per-project action runs
  (`action llvm` writes `projects/llvm/dev_<hash>/` + `projects/llvm/19/`;
   `action z3` writes `projects/z3/dev_<hash>/` + `projects/z3/stable/`)
- `_out/canary/test/{artifact-test,pm-test,artifact-summary}/` — framework
  self-tests and ad-hoc dumps
- `_out/canary/graph/action_rule.mmd` — universal schema diagram from `canary graph`

Do NOT copy `_out/canary/` to the z3 repo for GH CI.

## Active Work: Canary

Canary is a dependency-testing framework that enumerates all possible
build/probe actions for a C/OCaml project and runs them locally (with
plans for GH CI).

### Key source files

| File                                           | Purpose                                                                                               |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `src/canary/canary.ml`                         | Core types, action rules, 14-pattern table, diagram generation                                        |
| `src/canary/canary_action.ml`                  | `script_spec`, `derive_steps`, runner, text log, shared templates                                     |
| `src/bin/canary_main.ml`                       | CLI entry point; `run_llvm` runs llvm+llvm/19, `run_z3` runs z3+z3/stable                             |
| `src/canary/canary_basic.ml`                   | `artifact_kind`, `kind_order`, `project_spec`                                                         |
| `src/canary/canary_store.ml`                   | `location`, `package_manager`, `source_repo`, `distro` types                                          |
| `src/canary/canary_ocaml.ml`                   | OCaml toolchain types, opam packaging, probe generation                                               |
| `src/canary/canary_artifact_check.ml`          | Artifact existence checks, nm symbol inspection, check_post                                           |
| `src/canary/projects/canary_project_sqlite.ml` | sqlite3 project spec + `script_spec`                                                                  |
| `src/canary/projects/canary_project_z3.ml`     | z3 project spec + `script_spec`; `z3_source_stable` has `has_build_binding=false`                     |
| `src/canary/projects/canary_project_llvm.ml`   | LLVM project spec + `script_spec`; `llvm_source_stable` has local path + `has_build_binding=false`    |
| `src/canary/projects/canary_run.ml`            | Project orchestrator; runs llvm+llvm/19 and z3+z3/stable                                              |
| `canary/examples/llvm/llvm_example.ml`         | LLVM 16+ example (create_context)                                                                     |
| `canary/examples/llvm/llvm_example_dev.ml`     | LLVM 21+ example (Opcode.UncondBr); fails against llvm.19-shared                                      |
| `canary/examples/llvm/llvm_example_19.ml`      | LLVM ≤20 example (Opcode.Br); fails against dev binding                                               |
| `canary/examples/llvm/llvm_example_15.ml`      | LLVM ≤15 example (global_context); fails against LLVM 16+                                             |
| `canary/templates/opam-local-repo/`            | Local opam packages: z3.dev, llvm.dev-shared, llvm.19-shared, llvm.19-static, conf-llvm-shared.dev/19 |
| `canary/scripts/assert_binary_symbols.py`      | nm-based symbol compat check                                                                          |
| `doc/canary/design/index.md`                         | Design doc: pattern table, store config, execution model                                              |
| `doc/canary/ops/install_targets.md`          | Z3 vs LLVM cmake install patterns; informs TODO #25                                                   |
| `doc/canary/ops/llvm_build.md`                | LLVM source build steps, smoke test, opam install notes                                               |
| `doc/canary/backlog.md`                        | Lower-priority TODOs (#5, #9–#11, #13b, #14, #16–#18, #22)                                            |

### Architecture in one paragraph

`store_rules` in `canary.ml` defines the universal action graph (fetch,
build, probe, pack for each artifact kind: Source → Lib → Binding → App).
`pattern_rows_of_paths` enumerates 14 structural patterns with `action_path`
strings like `fetch_source → build_lib → build_binding`. A project provides
a `script_spec` (hardcoded shell commands per action). `derive_steps` filters
the 14 patterns by project capabilities and instantiates them with the
project's scripts. `run_graph` executes the steps in dependency order with
`check_pre`/`check_post` filesystem checks and appends to `actions.log`.
Each project runs two variants: dev (source build + pack_binding) and
stable (fetch_lib + fetch_binding only, no build) — the stable variant
probes with the dev example to demonstrate version mismatch detection.

### Two testing axes

Canary's test surface has two independent axes — both are kept alive because
either can silently break first:

| Axis                | Subcommand                               | Fails when …                                                                                                                                         |
| ------------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Project tests**   | `canary action <project>`                | The project under test drifts (new Z3 renames a symbol, LLVM adds Opcode)                                                                            |
| **Framework tests** | `canary artifact-test`, `canary pm-test` | Canary's own tool assumptions drift (`nm`/`ocamlobjinfo`/`ocamlfind`/`python3` change output format, `dir(sys)` loses an attr, shell pipe semantics) |

A green project run is meaningless if `nm` silently started emitting an
extra column and our parser discarded every symbol. Framework tests fix
known-stable fixtures (sqlite3.so, fmt.cmxa, Python sys/sqlite3) that
exercise every primitive canary depends on. Especially useful when
expanding to macOS (different `nm` flags, Mach-O format, keg-only paths)
or upgrading the OCaml / Python / distro runtime — framework tests
diagnose environment drift early.

Current framework tests verify "command runs, rc matches, JSON parses."
Stronger invariants (e.g., `counts.total > 0` on libsqlite3.so, `modules
== 1` on fmt.cmxa) are a candidate hardening step.

### Multi-version probe design

`canary action llvm` runs two sequential sub-runs sharing one opam switch:

| Sub-run   | Source                | Lib                 | Binding                    | Example               | Expected                           |
| --------- | --------------------- | ------------------- | -------------------------- | --------------------- | ---------------------------------- |
| `llvm`    | dev (ninja)           | dev libLLVM.so      | `llvm.dev-shared` (packed) | `llvm_example_dev.ml` | pass                               |
| `llvm/19` | local path (no build) | `llvm-19-dev` (apt) | `llvm.19-shared` (opam)    | `llvm_example_dev.ml` | **fail — Opcode.UncondBr unbound** |

`llvm_example_dev.ml` uses `Opcode.UncondBr` (added in LLVM 21, March 2026
commit #186176 — `br` split into `uncondbr+condbr`). Against `llvm.19-shared`
it fails to compile, demonstrating API mismatch. Sequential execution avoids
opam switch conflicts.

### Current TODO (numbers are stable like GH issues — never renumbered)

19. **LLVM cross-version symbol check** — probe_binding has symbol compat
    check. `llvm/19` probe_binding_pkg now demonstrates OCaml API mismatch
    (compile error). Remaining: also verify at the C symbol level with a
    mismatched libLLVM.so version pair.

20. **Symbol diff between lib versions** — extend `assert_binary_symbols.py`
    with `--provided-lib-old / --provided-lib-new` mode. Foundation for #16.

25. **Model `cmake --install` as canary action slot** — `install_lib` /
    `install_binding` between `build_*` and `pack_binding`. See
    `doc/canary/ops/install_targets.md` for Z3 vs LLVM patterns.

Backlog (lower priority): #5, #9, #11, #13b, #14, #16, #17, #18, #22, #27, #28, #29, #30, #31, #32, #33, #34.
Details in `doc/canary/backlog.md`.

### Known Gaps (interface / expectation layer)

These are tracked here rather than the backlog because they directly affect
the `step_expectation` / interface model design.

Artifact summary progress (`doc/canary/design/interface.md`):
- ✅ Step 1 — `summary_cmd` for native/ocaml/opam kinds (per-probe `summary.json`)
- ✅ Step 2 — watchlists declared per project (z3/llvm/sqlite), `summary`
  field on `script_spec`, `derive_steps` emits follow-up `<tag>_summary` steps
- ✅ `summary-diff` subcommand (local only; no committed cache yet)
- ✅ Summary command coverage in `canary_artifact_test.ml`
- ⏳ Step 3 deferred — `summary-sync` into a committed
  `doc/canary/artifact_summary.json` will likely ride on step-cache transport

Still open:
- **macOS support (three scopes)** — each a prerequisite for the next:

  **1. Code framework** — partially scaffolded, not end-to-end viable.
  What exists: `Canary_artifact_native.is_macos` chooses `nm -g` vs `-D`
  and handles `.dylib` alongside `.so`; `Canary_store.distro` type has
  `MacOS_local`; `canary_pm_brew.ml` PM module defined; `distro_base` has
  a hardcoded `/Users/ex/code` path.
  What's missing: Mach-O ELF-analogue probes (no `.so` versioned symbols,
  different dyld semantics), proper keg-only Homebrew path handling
  (`PKG_CONFIG_PATH` for sqlite/openssl/libffi), project specs (Z3/LLVM)
  have Linux-only shell pipelines, opam sandbox behavior diverges from
  Linux (bwrap → `sandbox-exec` / different mount semantics).

  **2. Local testing** — user has SSH access to a Mac. Framework tests
  (`canary artifact-test`) should run green there against macOS fixtures:
  `/usr/lib/libSystem.dylib` instead of `libsqlite3.so.0`, `nm -g`
  output parsed correctly, Mach-O versioned-symbol analogue surfaced (or
  explicitly declared N/A), `Probe Lib` summary on at least one brew
  package. This is the cheapest way to find the framework-drift gaps
  without waiting for CI setup.

  **3. GH CI for macOS** — the retired `canary_backend_yaml.ml` had
  `ubuntu-latest` × `macos-latest` matrix + per-step `if: runner.os == …`
  guards. The current `canary_backend_gh.ml` hardcodes `runs-on:
  ubuntu-latest`. Add matrix support + a per-step guard field to
  `action_step` (or extend `preamble_steps` semantics). Couples with
  "multi-ocaml-version matrix" (old supported `ocaml-version: ["5.4.0"]`
  in the matrix). GH macOS runners are paid minutes — ship selectively
  (sqlite + one other). Strictly a follow-up to (1) and (2).

  **Order to execute**: (1) finish core framework + parser fallbacks →
  (2) exercise on SSH Mac to catch gaps the Linux-only runs hid →
  (3) wire up GH CI matrix only after (1) and (2) are green. Skipping
  ahead to (3) burns paid CI minutes on known failures.
- **Retire legacy `config distro` / `project_config` / `job_spec` plumbing**
  — now unreachable (zero callers after the yaml+shell backend removal),
  but parked rather than deleted because it encodes the *intent* of the
  distro × sys-PM × lang-PM enumeration that the current action-graph
  pipeline doesn't yet model explicitly. Specifically:
    - No distro abstraction is exercised (WSL and macOS paths untested).
    - No two-OS CI (macOS matrix is the paired TODO above).
    - Sys-PM × lang-PM enumeration (apt × opam, brew × opam, apt × pip, …)
      exists conceptually in `project_config.phases` but isn't represented
      in the new `script_spec` → `action_step` path.
  **Revisit together with the version/symbol/interface work**: when we
  formalise interfaces as first-class (per `interface_contract_design.md`),
  the PM-cross-distro enumeration becomes part of "which provider (PM on
  distro) satisfies a given interface at a given version." Delete
  `project_config` plumbing (and each project's `config distro` fn) once
  the replacement exists; until then it's dead code but documents the
  missing model. Files touched when the cleanup happens:
  `canary_basic.ml` (`job_spec`, `step_phase`, `canary_backends`,
  `canary_config`, `mk_canary_config`), `canary.ml` (`project_config`,
  `verify_of_phase`, `steps_of_phase`, `make_job`, `resolve_job_scripts`),
  each project's `config distro` + `prebuilt_*_spec` helpers.
- **Per-step `env:` fields in GH YAML** — old yaml backend had an `env_fields`
  list per step. New backend only allows raw YAML blocks via `preamble_steps`.
  Not blocking; re-add as a typed field if a project needs it.
- **Deeper OCaml binding analysis** — ocamlobjinfo is module-level only; no
  constructor-level drift (e.g., `Opcode.UncondBr`) from summaries. User flagged
  this as a dedicated future step requiring a "structure of ocaml-binding / any-
  language-binding" model, outside current local-feature scope.
- **Migrate the old tola artifact inspectors in `src/binding/` into canary**
  (not just `ocaml_files.ml`). ~1880 lines, 15 modules, uses native OCaml
  compiler libraries instead of shelling out. Called from
  `src/bin/example_sp.ml`. Each module's canary-relevance:

  | File                                                                         | Lines      | Canary-relevance                                                                                                                             |
  | ---------------------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
  | `canary.ml`                                                                  | 417        | **High** — old canary model (test case enumeration, version/API/lib mapping). Predates current canary; check overlap before re-implementing. |
  | `ocaml_files.ml`                                                             | 330        | **High** — file classification for `.o/.cmo/.cmi/.cmx/.cmxs/.ml/.mli/.cma/.cmxa` via `Objinfo.extra` + `Fl_metascanner`.                     |
  | `shared_library.ml`                                                          | 257        | **High** — `ldd`-style linked-dep extraction (`linked_dep` type). Directly enables loader-path analysis.                                     |
  | `ocamls.ml`                                                                  | 137        | **High** — `Objinfo` module; proper API to `.cmxa`/`.cma` inspection (replaces shell+python in `summarize_ocaml.py`).                        |
  | `resolve.ml`                                                                 | 125        | Medium — `Resolve_strategy` (`Via_name` / `Via_value`). Maps to watchlist vs. content-hash matching.                                         |
  | `macho.ml`                                                                   | 102        | Medium — macOS Mach-O (dyld) inspection; paired with `shared_library.ml` for cross-platform loader paths.                                    |
  | `structures.ml`                                                              | 100        | Medium — consumer of `resolve.ml`.                                                                                                           |
  | `c_utils.ml`                                                                 | 87         | Medium — `yojson_conv` precedent for serialising results.                                                                                    |
  | `path.ml`                                                                    | 76         | Low — path abstraction with roots.                                                                                                           |
  | `fs.ml`, `opam.ml`, `package.ml`, `compilers.ml`, `platform.ml`, `config.ml` | ~250 total | Mixed — check per-module; some overlaps with existing `canary_pm_*`, `canary_store`.                                                         |

  Other `src/` dirs (`ainterp`, `interp`, `langs`, `packaging`, `repl`, `std`,
  `tola`, `versioned_maps`, `versioning`) are the tola interpreter / language
  layer, mostly unrelated to canary — only cross-reference if a specific primitive
  is needed (e.g., `versioning/` for version-constraint solving per the
  interface-contract design doc).

  **Do after** local summary flow stabilises; migrate incrementally per module.
- **No source-artifact summary** — only native / ocaml / opam kinds so far.
  Source summaries (git SHA, public header count, FFI surface via C-ABI
  exports for other languages) are a natural next extension.
- **No python summary in any project spec** — `summary_cmd` helpers for python
  haven't been defined (no project uses a python artifact yet). Plan at
  `doc/canary/trackers/python_binding.md` (z3-solver, llvmlite, stdlib sqlite3);
  delete the plan doc when all three projects have Python probe + summary wired.
- **PyTorch as multi-PM canary target** — batch-2 queued; depends on Python
  primitives landing first. Plan at `doc/canary/trackers/pytorch.md` covers the
  pip × opam × apt libtorch matrix and the OCaml `torch` version-conflict
  case. Motivated by multi-PM interop (same libtorch shipped by many PMs).
- **Two-tier candidate queue for canary expansion** —
  `doc/canary/trackers/batch_candidates.md` holds a dozen tracked targets (Tier 1:
  famous libs like PyTorch, OpenSSL, FFmpeg; Tier 2: tricky packaging like
  zarith, lwt+libev, cvc5, bitwuzla, mariadb, cairo2). Picked from the
  opam survey; living doc, updated as candidates land.
- **First-class API-source layer** — implemented. `canary_artifact_api.ml`
  types the three-layer structure (source_repo → native_api → binding_api).
  Watchlists split into provider (`stable_symbols`) and consumer
  (`module_watchlist`) levels. `scan_source` step verifies header/binding-dir
  claims post-fetch. See `doc/canary/design/interface.md §4`.
- **`version_info` dropped in GH verify step** — the verify YAML just prints
  `"PASS: expected failure confirmed"`, not the version rationale from `version_info`.
  Should annotate the echo with the context string.
- **`symbol_check` in CI is a plain `nm` shell snippet** — rendered in GH backend
  now (one extra step per symbol_check), but no project spec fills the field in yet;
  the `summary` watchlist is what's doing the real work. Decide whether to keep
  both `symbol_check` and watchlist, or collapse.
- **`symbol_entry.version_tag`** (`@@GLIBC_2.31` annotations) — typed field
  exists in the OCaml model but not yet populated; `summary.versioned_req`
  computes these at runtime via `summarize_native.py`. Connects to L1b in
  `doc/canary/design/interface.md`.
- **`Expect_failure` grep is fragile for multiline output** — `grep -qF` in the
  verify step reads `probe.log` but the local runner scans all files in `output_dir`.
  Should align: both should scan `probe.log` only.

### Done

Done: #1, #2, #3, #4, #6, #7, #8, #10, #12, #13, #15, #21, #23, #24, #26. Details in
`doc/canary/worklog_2026_04.md`.

## Other Work: Yelu

Yelu lives under `yelu/` and has its own project guide. If you are working
on yelu or the cmake language layer, read `yelu/CLAUDE.md` and ignore the
rest of this file.

## Gotchas

- **OCaml LSP stale diagnostics**: Cross-module edits show false errors
  until dune rebuilds. ocamllsp reads compiled `.cmi` files; no
  in-memory cross-module resolution. Ignore during multi-file refactors,
  verify with `dune build` at the end.
- **`open Base` shadows stdlib**: `result`, `prefix`, `id`, `append`
  are shadowed — rename in pattern matches.
- **Mermaid v11+**: User's renderer supports `@{ shape: docs }` syntax.
  Safe to use modern Mermaid features in `.mmd` files.
- **`opam config subst`**: expects `foo.in` → `foo`. The template must
  be named `.in`; the command is relative to cwd, not absolute.
- **z3 git submodule leftover**: if z3 source has a `.git` file (not
  dir) pointing to `../../.git/modules/z3`, cmake fails with "could
  not find commondir". Fix: convert to standalone repo (`rm .git`,
  `git clone --bare ... .git`, `git config core.bare false`).
- **Build tree vs opam-installed binding conflict**: `-package z3 -I
  build/src/api/ml` causes "inconsistent assumptions" because
  ocamlfind loads the opam version while `-I` adds build tree `.cmi`
  files. For build tree probes, use `-package zarith` (dep only) +
  explicit `z3ml.cmxa`, not `-package z3`.
- **opam sandbox is active on WSL**: `wrap-build-commands` is set
  globally to `[sandbox.sh "build"]` even on WSL — bwrap IS active.
  The switch-level `opam option wrap-build-commands` returns `[]` but
  that is the switch override (empty = inherit global), not a disable.
  bwrap mounts the home directory **read-only**: external paths like
  `CANARY_BUILD_DIR` are readable but not writable. Fix: guard cmake
  invocations with `test -f <artifact> || cmake ...` so cmake is skipped
  when artifacts already exist (canary has built them). CI also works:
  no `CANARY_BUILD_DIR` set, so `B=build` (local to sandbox), cmake
  runs fresh in a writable local dir.
- **ELF symbol versioning in nm output**: Linux shared libs (e.g., LLVM)
  use versioned symbols — `nm -D` outputs `LLVMAddAlias2@@LLVM_19.1`
  not `LLVMAddAlias2`. `assert_binary_symbols.py` regex must allow
  `(?:@@?\S+)?$` suffix; a bare `\w+$` anchor silently matches nothing.
  Fix is in `parse_defined_symbols` in `canary/scripts/assert_binary_symbols.py`.
- **`find_llvm_config_cmd` composability**: it's a multi-line `if/elif/fi`
  shell expression. Cannot be safely nested inside `$()` as a sub-argument
  (e.g., `$(find_llvm_config_cmd --libdir)` is wrong). Always assign to a
  variable first: `LLVM_CONFIG=$(find_llvm_config_cmd)` then use `$LLVM_CONFIG`.
- **`$CAMLORIGIN/../..` breaks in opam flat layout**: LLVM's `llvm.cmxa`
  embeds `-L$CAMLORIGIN/../..` pointing to `libLLVM.so`. In the build tree
  (`build/lib/ocaml/llvm/`) this resolves to `build/lib/` ✓. After
  `ocamlfind install` to `lib/llvm/`, it resolves to the switch root ✗.
  Fix: append `linkopts = "-cclib -L<BUILD>/lib -cclib -Wl,-rpath,<BUILD>/lib"`
  to META. Proper fix (TODO #25): run `cmake --install` which regenerates cmxa.
- **`mktemp` in opam sandbox uses `/opam-tmp`, not `/tmp`**: bwrap sets
  `TMPDIR=/opam-tmp` (a tmpfs), so `mktemp` goes there. `/tmp` itself IS
  mounted rw (`--bind /tmp /tmp`), so explicit `/tmp/foo` paths work. Use
  `./name` (current dir = opam build dir, also rw) for simplicity.
- **`build_z3_ocaml_bindings` is a cmake PHONY target**: `add_custom_target`
  in cmake always generates a PHONY ninja target — ninja never considers it
  up-to-date and always reruns it. Deleting the canary `_out/` cache causes
  canary to re-run `configure` (cmake), which updates `CMakeFiles/` timestamps,
  which triggers a full z3 rebuild (~863 steps). Fix: TODO #26 artifact
  pre-check (`test -f z3ml.cmxa || ninja ...`). LLVM's `LLVM` target builds
  a concrete file (libLLVM.so) so ninja correctly skips it.
- **META.llvm `directory = "llvm"`**: OCaml archives are in a `llvm/`
  subdirectory of the build tree. Set `OCAMLPATH` to the parent
  (`build/lib/ocaml/`), not `build/lib/ocaml/llvm/`. Strip `directory`
  field when doing flat opam install.
- **cmake ANSI color codes corrupt hex pattern tests**: cmake adds `\x1b[0m`
  escape sequences to stderr when it detects a TTY. The `message/newline`
  compat test hex-encodes subprocess stderr — ANSI codes corrupt it. Fix:
  `cmake_runner.ml`'s `make_env` always injects `NO_COLOR=1`; never call
  `Unix.open_process_full` with `Unix.environment ()` directly in the runner.

## Conventions

- `cc` = Claude Code (user shorthand)
- Allowed bash: `make *` and `dune *` only

## Handoff Workflow

This file is the serialization layer for cross-machine continuity.
Local memory and chat context are ephemeral; CLAUDE.md is the durable
snapshot any fresh session on any machine can reconstruct from.

**Before ending a session**, update this file with current state:

```
Update CLAUDE.md for handoff. Include these sections:
1. Build & Run — commands to build, test, run
2. Key Files — table of important files and their purpose
3. Architecture — one-paragraph summary of how things fit together
4. Current TODO — prioritized next steps
5. Gotchas — behavioral traps, things that wasted time, workarounds
   (include *why* for each)
6. Feedback — corrections or preferences I gave you during our sessions
   that should carry forward
7. Conventions — shorthand, naming patterns, style preferences
Check your memory files for gotchas and feedback material.
Commit the result.
```

**When starting on a new machine**, load context:

```
Read CLAUDE.md and familiarize yourself with the project. Save any
gotchas and feedback items to your local memory so they persist across
conversations on this machine.
```
