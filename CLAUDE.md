# Claude Code — Project Guide

## Build & Run

```sh
dune build                                                   # build everything
dune exec src/bin/canary_main.exe -- paths                   # print 15-row action pattern table
dune exec src/bin/canary_main.exe -- paths-md                # same, markdown output
dune exec src/bin/canary_main.exe -- graph                   # write docs/canary/graph/action_rule.mmd
dune exec src/bin/canary_main.exe -- action sqlite
dune exec src/bin/canary_main.exe -- action z3               # runs z3 (dev) + z3/stable
dune exec src/bin/canary_main.exe -- action llvm             # runs llvm (dev) + llvm/19
dune exec src/bin/canary_main.exe -- artifact-test           # framework self-tests (native, ocaml, python, compat helpers)
dune exec src/bin/canary_main.exe -- pm-test                 # PM module self-tests (apt/brew/opam/pip)
dune exec src/bin/canary_main.exe -- artifact-summary --kind native --path X  # ad-hoc summary dump
dune exec src/bin/canary_main.exe -- inspect-diff --old A --new B            # diff two inspect.json files
dune exec src/bin/canary_main.exe -- compat <project> [<variant>]            # static C-symbol cross-check
dune exec src/bin/canary_main.exe -- verify <project> [<variant>]            # cross-reference prediction vs probe.log
make canary                                                  # run canary via Makefile shorthand
```

Output layout (gitignored via `_*`):
- `_out/canary/projects/<project>/<step>/` — per-project action runs
  (`action llvm` writes `projects/llvm/dev_<hash>/` + `projects/llvm/19/`;
   `action z3` writes `projects/z3/dev_<hash>/` + `projects/z3/stable/`)
- `_out/canary/test/{artifact-test,pm-test,artifact-summary}/` — framework
  self-tests and ad-hoc dumps
- `_out/canary/graph/action_rule.mmd` — universal schema diagram from `canary graph`

Web-viewable files (diagrams, HTML, JSON, logs) are copied to `docs/canary/`
for GitHub Pages deployment. `docs/canary/` is tracked in git.

## Active Work: Canary

Canary is a dependency-testing framework that enumerates all possible
build/probe actions for a C library project (with OCaml + Python bindings
today; Rust/Java/etc. plug in as data) and runs them locally, with GH CI
support.

### Layered layout

After the 2026-06-01 refactor (commits `5c0438f` → `0139e07`),
`src/canary/` is organised into 8 subdirs with a documented layer
order (also in [`src/canary/dune`](src/canary/dune)):

```
base/      vocabulary — types every other layer uses (incl. API-surface
           claim types and output-tree naming conventions)
surface/   surface theory — c1..c8 comparators + compat runner
tool/      real-world wrappers — PM drivers, inspector drivers, build cmds,
           toolchain config (incl. per-language probe specs)
action/    action graph — rules, step model, step builder, paths
backend/   step-list consumers — local runner (executes), GH YAML, HTML,
           Mermaid, run_info orchestrator
test/      framework self-tests
projects/  live project specs (canary_projects sub-library)
legacy/    parked code (canary_legacy sub-library)
```

`base/`→`surface/`→`tool/`→`action/`→`backend/` is the dependency
order; `projects/`, `test/`, `legacy/` consume the upper layers.

### Key source files

| File                                                | Purpose                                                                                                |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `src/bin/canary_main.ml`                            | CLI: `action`, `paths`, `graph`, `compat`, `verify`, `inspect-diff`, `artifact-test`, `pm-test`, …     |
| `src/canary/base/canary_lang.ml`                    | `type lang = OCaml \| Python \| …`; sibling file so `canary_basic` + `canary_store` can both use it    |
| `src/canary/base/canary_basic.ml`                   | `artifact_kind`, `kind_order`, `project_spec`, `rule`, `version`, `string_of_*`, `step_dir_of_tag`, `filename`, `variant_file` — live vocabulary including output-tree naming |
| `src/canary/base/canary_store.ml`                   | `location`, `package_manager`, `source_repo`, `distro`, `pm_properties` types (was canary_pm_types)    |
| `src/canary/base/canary_artifact_api.ml`            | Declarative `native_api` / `binding_api` types (provider/consumer claims, watchlists) — facts about library APIs |
| `src/canary/surface/canary_compat.ml`               | Pure theory: `inspect_input` ADT + c1..c8 comparators (`check_c_compat`, `check_abi`, `check_type`, …) + contract registry vocabulary (`contract_id`, `contract_status`, `contract_check`) |
| `src/canary/surface/canary_compat_run.ml`           | Drives the contract: cached-summary lookup + per-contract predict closures (`c1_predict`, …) + `registered_checks` list + `predicted_contains_any_v2 ~resolve` (4-line iterator over the registry) + CLI run/verify |
| `src/canary/tool/canary_toolchain.ml`               | OCaml toolchain types, opam packaging helpers, `pip_install_cmd` / `python_probe_only_cmd`             |
| `src/canary/tool/canary_build_cmd.ml`               | Generic build-tool primitives: `cmake_configure_cmd`, `ninja_build_cmd`, `dune_build_cmd`, `with_marker` |
| `src/canary/tool/canary_artifact_native.ml`         | nm-based native lib summaries; `--emit-symbols` for compat cross-check                                 |
| `src/canary/tool/canary_artifact_lang.ml`           | OCaml + Python summary helpers (mli, stub, ocamlobjinfo, `dir()`)                                      |
| `src/canary/tool/canary_artifact_source.ml`         | Source artifact helpers; `scan_source` post-fetch verification                                         |
| `src/canary/tool/canary_inspect_diff.ml`            | `canary inspect-diff` — counts/modules/watchlist/versioned_req drift                                   |
| `src/canary/tool/canary_pm_{apt,brew,opam,pip}.ml`  | Per-PM presence checks + install commands; `canary_pm_test.ml` runs the suite                          |
| `src/canary/action/canary.ml`                       | 24-line `include` shim re-exporting the three step-domain modules below                                |
| `src/canary/action/canary_action.ml`                | `action_rule`, `store_rules`, `make_action_rule`, `nodes_of_action_rule`, `node_status` — the schema   |
| `src/canary/action/canary_step_model.ml`            | `step_expectation` (incl. `Expect_compat_failure`), `action_step`, `logger`, `version_info`, `symbol_*` |
| `src/canary/action/canary_path_table.ml`            | 15-pattern table + `pp_job_path_table` / `pp_job_path_table_md` (CLI `paths` / `paths-md`)             |
| `src/canary/action/canary_step_builder.ml`          | `script_spec`, `derive_steps`, shared command templates, check_post compositors — the step list builder |
| `src/canary/backend/canary_local_runner.ml`         | `run_step`, `run_graph`, `merge_step_statuses` + the cross-run cache (`load_cache`, `cache_is_success`, …) — executes the step list locally (in-process backend) |
| `src/canary/backend/canary_run_info.ml`              | `run_info` + `run_project` / `run_project_multi` orchestrators + `save_run_state` / `view_project`     |
| `src/canary/backend/canary_gh.ml`           | GitHub Actions YAML rendering; resolves `Expect_compat_failure` predictions at gen time                |
| `src/canary/backend/canary_html.ml`         | HTML result page + index rendering                                                                     |
| `src/canary/backend/canary_diagram.ml`              | Mermaid diagram + view machinery (2283 LOC; biggest single file)                                       |
| `src/canary/test/canary_artifact_test.ml`           | Framework self-tests (native, OCaml, Python, compat helpers — pure + shell)                            |
| `src/canary/test/canary_pm_test.ml`                 | PM module self-tests                                                                                   |
| `src/canary/projects/canary_project_sqlite.ml`      | sqlite3 project spec; OCaml + Python (stdlib) probes                                                   |
| `src/canary/projects/canary_project_z3.ml`          | z3 spec; `z3_source_stable` has `has_build_binding=false`. Python probe demonstrates derived L3 fail   |
| `src/canary/projects/canary_project_llvm.ml`        | LLVM spec; OCaml stable variant uses `Expect_compat_failure` for forward-incompat detection            |
| `src/canary/projects/canary_project_tiny.ml`        | tiny in-tree spec (Phase 4 alignment milestone); api_source + OCaml + Python cext sub-arms; 12-step pipeline produces JSONs byte-equivalent to `make scenarios-cached`. See `doc/canary/worklog/phase4_2026_05.md`. |
| `src/canary/projects/canary_pattern_a.ml`           | Pattern A template (conf-* + opam binding); consumed by zarith + ssl specs                             |
| `src/canary/projects/canary_run.ml`                 | Project orchestrator; runs llvm+llvm/19 and z3+z3/stable                                               |
| `src/canary/legacy/canary_yaml_backend.ml`          | Parked: retired yaml-backend types + helpers (system_pkg, job_spec, canary_config, mk_canary_config, …) |
| `src/canary/legacy/canary_dead_code.ml`             | Parked: pre-canary Z3/Llvm/Sqlite plumbing; consumed only by example_sp                                |
| `src/canary/legacy/example_sp.ml`                   | Parked: legacy CLI binary using canary_dead_code                                                       |
| `canary/examples/llvm/llvm_example.ml`         | LLVM 16+ example (create_context)                                                                      |
| `canary/examples/llvm/llvm_example_dev.ml`     | LLVM 21+ example (Opcode.UncondBr); fails against llvm.19-shared                                       |
| `canary/examples/llvm/llvm_example_19.ml`      | LLVM ≤20 example (Opcode.Br); fails against dev binding                                                |
| `canary/examples/llvm/llvm_example_15.ml`      | LLVM ≤15 example (global_context); fails against LLVM 16+                                              |
| `canary/templates/opam-local-repo/`            | Local opam packages: z3.dev, llvm.dev-shared, llvm.19-shared, llvm.19-static, conf-llvm-shared.dev/19  |
| `canary/scripts/inspect_native.py`           | nm parser → `kind: native` summary (counts, by_prefix, versioned_req, optional symbol list)            |
| `canary/scripts/inspect_binding.py`          | mli + stub `.a` parser → `ocaml_mli` / `c_stub` summaries; consumer-side L0/L3 surface                 |
| `canary/scripts/inspect_ocaml.py`            | ocamlobjinfo parser → `ocaml` summary (module list)                                                    |
| `canary/scripts/inspect_python.py`           | Python `dir()` parser → `python` summary (attrs + watchlist + extras)                                  |
| `canary/scripts/assert_binary_symbols.py`      | nm-based pass/fail symbol compat check (legacy; `inspect_native.py` superseding for new code)        |
| `doc/canary/design/index.md`                   | Design narrative: vision, action graph, store model, workflow stages, design principles               |
| `doc/canary/research/README.md`                | Entry point — four-pillar alignment for surface theory + tiny witness + roadmap                       |
| `doc/canary/research/surface_theory.md`        | Theory (current): six surface roles s1..s6, eight contracts, §2.7 coverage (inspectors i*, comparators c*) + implementation pointers |
| `doc/canary/research/tiny.md`                  | Witness (current): minimal C lib + 3 bindings + 13-variant canary matrix + harness scenario table + findings |
| `doc/canary/research/plan.md`                  | Paper venues + milestones + working roadmap (steps 1-5; step 1+2 done)                                |
| `doc/canary/ops/install_targets.md`            | Z3 vs LLVM cmake install patterns; informs TODO #40                                                    |
| `doc/canary/ops/llvm_build.md`                 | LLVM source build steps, smoke test, opam install notes                                                |
| `doc/canary/backlog.md`                        | Lower-priority TODOs; api-compat group + new project spec group (see line below for current set)       |

### Architecture in one paragraph

`store_rules` in `action/canary_action.ml` defines the universal
action graph (fetch, build, probe, pack for each artifact kind: Source
→ Lib → Binding → App, per language). `pattern_rows_of_paths` in
`action/canary_path_table.ml` enumerates 15 structural patterns with
`action_path` strings like `fetch_source → build_lib → build_binding`.
A project provides a `script_spec` (shell commands per action) plus an
`api_source` (declarative provider/consumer surface — header paths,
symbol prefixes, watchlists). `derive_steps` in
`action/canary_step_builder.ml` filters the 15 patterns by project
capabilities, attaches per-artifact summaries (mli, stub, native,
python) to install steps, and instantiates them with the project's
scripts. The resulting `action_step list` is consumed by one of four
sibling backends: `backend/canary_local_runner.ml` executes it
directly (in-process); `backend/canary_gh.ml` renders it as GH
Actions YAML; `backend/canary_diagram.ml` renders it as Mermaid;
`backend/canary_html.ml` renders the interactive viewer. `run_graph` executes the steps in
dependency order with `check_pre`/`check_post` filesystem checks and
appends to `actions.log`. Probe expectations may be hand-written
(`Expect_failure`) or **derived** at runtime (`Expect_compat_failure`)
— the pure comparators live in `surface/canary_compat.ml`, and
`surface/canary_compat_run.ml`'s `predicted_contains_any_v2 ~resolve`
reads cached install-step summaries to compute the predicted failure
substrings (L0 C-symbol set diff + L3 watchlist-missing variants). The
high-level orchestrator `run_project` in `backend/canary_run_info.ml`
bundles run_info dump + `run_graph` + HTML/Mermaid rendering + run-state
save into the single call `canary_main.ml` invokes. Each project runs
two variants: dev (source build + pack_binding) and stable (fetch_lib +
fetch_binding only, no build) — the stable variant probes with the dev
example to demonstrate version mismatch detection. `canary verify`
cross-references the prediction against probe.log post-hoc.

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

Current framework tests cover "command runs, rc matches, JSON parses"
plus pure helper tests (compat helpers exercise `predicted_contains_any_v2`
against synthetic Ocaml_mli / Python_attrs fixtures). Stronger
content-shape invariants (e.g. `counts.total > 0` on libsqlite3.so,
`modules ≥ 1` on fmt.cmxa) are a candidate hardening step.

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

The expected-failure substring is no longer hand-written: llvm's
stable-variant `expectation` returns `Expect_compat_failure` and the runner
derives `Opcode.UncondBr` from the cached `fetch_ocaml_binding/inspect.json`
watchlist. z3's stable variant has a parallel Python case (`z3.parser_context`
missing from the z3-solver pip wheel) using
`Expect_compat_failure { inputs = Canary_compat.[ Python_attrs […] ]; … }`
(list-of-string-list syntax since the 2026-06-01 Phase 4 ADT unification).
See `surface_theory.md` §2.7.

### Current TODO (numbers are stable like GH issues — never renumbered)

**Active Step 4 work — all driven from
[`doc/canary/research/plan.md`](doc/canary/research/plan.md) §6 Step 3b + Step 4.**
Numbers below are still the canonical TODO ids; plan.md is the
sequencing / progress doc that absorbs them.

- **#15b** — Unit-test framework for compat/inspect logic. Plan: §6 Step 3b.
- ~~**#43**~~ — c5 cmp_sym_version: **shipped Phase 15.4**. Lib gained
  `tiny.map` version script; canary diffs `Versioned_exports` vs
  `Versioned_req`. Demoed via `lib_symbol_version_broken` variant.
- ~~**#44**~~ — c6 cmp_type: **shipped Phase 15.5b** via trivial-grep
  inspector (`inspect_tiny_typed.py`'s `header` layer uses regex; other
  layers hardcoded). Clang-AST replacement is future work, not blocker.
  Demoed via `binding_type_broken` variant.
- **#18** — Audit project specs for hardcoded shell commands. Plan: §6 Step 4
  (b) "Project-spec command decoupling". The build-primitive extraction
  half is done (commits `952498e` Step 4(b) + `800108d` Phase 3): the
  cmake / ninja / dune wrappers now live in `tool/canary_build_cmd.ml`
  and z3, llvm, tiny all use them. Remaining: any project still doing
  raw `Printf.sprintf` of shell verbs that should route through a
  named primitive (audit pending).
- **#19** — LLVM cross-version C-symbol check. Plan: §6 Step 4 (b) "Live
  demos to strengthen" (belt-and-suspenders with the existing OCaml-side
  c2 watchlist demo).
- **#25 / #40** — Real `cmake --install` instead of fake `cp`. Plan: §6 Step
  4 (b) "Project-spec command decoupling".
- **#26** — z3 cmake `build_z3_ocaml_bindings` PHONY guard. Plan: §6 Step 4
  (b).
- **#16b** — Older redundant entry, superseded by #43 in the absorbed plan.

Backlog (lower priority, paper-orthogonal): #5, #9, #11, #13b, #14, #17, #27,
#29–32 (see design/new_project.md), #33, #34, #38, #39, #45; #16, #20, #31,
#35, #41, #42 (api-compat — see research/surface_theory.md §2.7).
Details in `doc/canary/backlog.md`.

### Known Gaps (interface / expectation layer)

These are tracked here rather than the backlog because they directly affect
the `step_expectation` / interface model design.

Artifact summary progress (`doc/canary/research/surface_theory.md`):
- ✅ Step 1 — `summary_cmd` for native/ocaml/python/mli/stub kinds
- ✅ Step 2 — watchlists declared per project (z3/llvm/sqlite), `summary`
  field on `script_spec`, install-step + probe-step summaries in
  `derive_steps`
- ✅ `inspect-diff` subcommand (local only; no committed cache yet)
- ✅ Summary command coverage in `canary_artifact_test.ml` (incl. compat
  helper pure tests)
- ✅ Compat cross-check shipped — `canary compat`, `canary verify`,
  `Expect_compat_failure` derive expected probe-failure substrings from
  cached summaries. See `surface_theory.md` §2.7. Live demos on llvm/19 (OCaml
  `Opcode.UncondBr`) and z3/stable (Python `parser_context`).
- ⏳ Step 3 deferred — `summary-sync` into a committed
  `doc/canary/artifact_inspect.json` will likely ride on step-cache transport

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
  guards. The current `canary_gh.ml` hardcodes `runs-on:
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
  formalise interfaces as first-class (per `doc/canary/research/surface_theory.md`),
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
- ~~**Deeper OCaml binding analysis**~~ — ✅ resolved by
  `inspect_binding.py --kind mli`, which parses `.mli` files at the
  vals/constructors/modules level (catches `Opcode.UncondBr` drift). The
  ocamlobjinfo summary still exists but is superseded by the mli summary
  for L3 work.
- **Migrate the old tola artifact inspectors in `src/binding/` into canary**
  (not just `ocaml_files.ml`). ~1880 lines, 15 modules, uses native OCaml
  compiler libraries instead of shelling out. Called from
  `src/bin/example_sp.ml`. Each module's canary-relevance:

  | File                                                                         | Lines      | Canary-relevance                                                                                                                             |
  | ---------------------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
  | `canary.ml`                                                                  | 417        | **High** — old canary model (test case enumeration, version/API/lib mapping). Predates current canary; check overlap before re-implementing. |
  | `ocaml_files.ml`                                                             | 330        | **High** — file classification for `.o/.cmo/.cmi/.cmx/.cmxs/.ml/.mli/.cma/.cmxa` via `Objinfo.extra` + `Fl_metascanner`.                     |
  | `shared_library.ml`                                                          | 257        | **High** — `ldd`-style linked-dep extraction (`linked_dep` type). Directly enables loader-path analysis.                                     |
  | `ocamls.ml`                                                                  | 137        | **High** — `Objinfo` module; proper API to `.cmxa`/`.cma` inspection (replaces shell+python in `inspect_ocaml.py`).                        |
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
- ~~**No python summary in any project spec**~~ — ✅ resolved. z3
  (z3-solver), llvm (llvmlite), and sqlite (stdlib sqlite3) all have
  Python probes with `python_inspect_cmd` attached; pip-install split
  off into `Fetch (Binding Python)` so the summary is cached before the
  probe runs. `python_binding.md` tracker has been deleted.
- **PyTorch as multi-PM canary target** — batch-2 queued; depends on Python
  primitives landing first. Plan at `doc/canary/design/new_project.md` §4
  covers the pip × opam × apt libtorch matrix and the OCaml `torch`
  version-conflict case. Motivated by multi-PM interop (same libtorch
  shipped by many PMs).
- **Two-tier candidate queue for canary expansion** —
  `doc/canary/design/new_project.md` §1 holds a dozen tracked targets (Tier 1:
  famous libs like PyTorch, OpenSSL, FFmpeg; Tier 2: tricky packaging like
  zarith, lwt+libev, cvc5, bitwuzla, mariadb, cairo2). Picked from the
  opam survey; living doc, updated as candidates land.
- ~~**First-class API-source layer**~~ — ✅ implemented.
  `canary_artifact_api.ml` types the three-layer structure (source_repo →
  native_api → binding_api). Watchlists split into provider
  (`stable_symbols`) and consumer (`module_watchlist`) levels.
  `scan_source` step verifies header/binding-dir claims post-fetch. See
  `doc/canary/research/surface_theory.md` §2.1.
- **`version_info` dropped in GH verify step** — the verify YAML just prints
  `"PASS: expected failure confirmed"`, not the version rationale from `version_info`.
  Should annotate the echo with the context string.
- **`symbol_check` in CI is a plain `nm` shell snippet** — rendered in GH backend
  now (one extra step per symbol_check), but no project spec fills the field in yet;
  the `summary` watchlist is what's doing the real work. Decide whether to keep
  both `symbol_check` and watchlist, or collapse.
- **`symbol_entry.version_tag`** (`@@GLIBC_2.31` annotations) — typed field
  exists in the OCaml model but not yet populated; `summary.versioned_req`
  computes these at runtime via `inspect_native.py`. Connects to L1b in
  `doc/canary/research/surface_theory.md`.
- **`Expect_failure` grep is fragile for multiline output** — `grep -qF` in the
  verify step reads `probe.log` but the local runner scans all files in `output_dir`.
  Should align: both should scan `probe.log` only.
- **`Expect_compat_failure` is OCaml-shaped per language** — the variant
  takes typed inputs (`C_stub | Native_lib | Ocaml_mli | Python_attrs`)
  but the layer-vs-language mapping is hardcoded in
  `predicted_contains_any_v2`. New languages need helper extension.
  Probably fine until a fourth language joins.

### Done

Done: #1, #2, #3, #4, #6, #7, #8, #10, #12, #13, #15, #21, #23, #24, #25, #26, #28.
The api-compat milestone (Phases 1–3e: `inspect_binding.py`, `canary
compat`/`verify`, `Expect_compat_failure`, Python pip probe split, Python
derived expectation) shipped this session — see `surface_theory.md` §2.7 and
commits `2a8d2eb`, `96b143c`, `84caf5d`, `8943ba2`, `7dfb1f2`.

Worklogs: `doc/canary/worklog/worklog_2026_{03,04,05}.md`.

## Other Work: Yelu

Yelu is now a standalone project at `/home/red/code/research/yelu` with its own CLAUDE.md, build system, and opam package. It was extracted from `yelu/` on 2026-05-04. If you need to work on yelu, switch to that repo.

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
- **NEVER use sed or python on OCaml source.** Use the `Edit` tool exclusively.
  sed cannot distinguish match-case scope, `let`/`in` boundaries, or which
  `| _ -> None` is the intended anchor.  Append commands match multiple
  locations, line numbers drift after earlier edits, and one bad deletion
  can silently remove adjacent code.  `git checkout` recovery costs hours.
  Examples from this project: `_summary→_inspect` sed corrupted
  `binding_summary`; Python line-number-based removals cut into
  `_counts_from_log` and `save_run_state`.  Edit → build → diff → commit
  after each working tier.
- **Catch-all ordering in `match`**: `| _ -> ...` or `| e -> ...` must come
  LAST.  Putting it first makes all patterns below unreachable.  The
  compiler warns `redundant-case` but doesn't error — the match silently
  ignores later patterns.

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
