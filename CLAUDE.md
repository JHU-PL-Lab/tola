# Claude Code — Project Guide

## Build & Run

```sh
dune build                                                   # build everything
dune exec src/bin/canary_main.exe -- paths                   # print 15-row action pattern table
dune exec src/bin/canary_main.exe -- paths-md                # same, markdown output
dune exec src/bin/canary_main.exe -- graph                   # write docs/canary/graph/action_graph.mmd
dune exec src/bin/canary_main.exe -- action sqlite            # 5 scenarios (2026-08-18, provider-exclusive rows): F:apt + Built 3.45.1/3.46.1 + Installed 3.45.1/3.46.1 — the Installed worlds stage the built lib into <ws>/install (copy-out) and probe the STAGED lib; Built worlds probe the build tree (LD_LIBRARY_PATH repoint + runtime sqlite_version asserted; Python is Ambient: bundled, observed not asserted)
dune exec src/bin/canary_main.exe -- action z3               # GENERIC path (A5 + C2 3-way + C3 regression ref): 7 scenarios (2026-08-19, provider-exclusive rows) = ONE all-Fetched world (stable 4.15.2 — the source row `~follows:a_lib`, so the fetched lib pairs only with the stable repo) + each dev repo TWICE, build-tree and staged: latest/arbipher/pre-10549 × {lib=Built, lib=Installed}. The Installed worlds run cmake --install into <build>/install (per-build-tree, never shared between refs) and probe the STAGED lib + STAGED OCaml package; the Built worlds probe the build tree. parser_context xfail fires in every world (scenario-invariant). --thin = stable chain only. --refs latest,pre-10549 = THE regression pair (4 scenarios = 2 builds + their 2 staged faces): pre-10549's INSTALLED world xfails at both install ("OCAML INSTALL MISSING") and probe ("STAGED PACKAGE MISSING" — the #10549 bug visible ON the consumer) while its Built twin PASSES (the build tree has the package), and latest passes in both faces. The `--installed` flag retired 2026-08-19 — the staged consumer is an enumerated world, not a run policy
dune exec src/bin/canary_main.exe -- action llvm             # GENERIC path (A5 + C2 3-way): same 5-scenario shape as z3; Opcode.UncondBr xfail in the stable chain
dune exec src/bin/canary_main.exe -- action tiny-full        # tiny-full PROJECT (peer of z3): 6 spec-derived scenarios = {lib V:S,B:S,B:D} x {ocaml binding V:S,V:D}; binding@dev over stable lib = the forward API mismatch (undefined tiny_scale), c1-predicted xfail
dune exec src/bin/canary_main.exe -- action tiny-full --thin # thin = version Subset [Stable] policy: 2 scenarios (drops both dev axes)
dune exec src/bin/canary_main.exe -- action @all           # THE batch: every registry project under the default config — Heavy (z3/llvm) THIN (bypasses the source-built Dev chains), Light FULL; --thin forces thin everywhere; --audit-lib = full + Materialize_source (the shadowed source-built placements materialize — blame-driven, never in the batch); --refs A,B = only the source-repo refs with those pinned ids (any project; the batch never sets it); single-project runs always full
dune exec src/bin/canary_main.exe -- spec tiny-full          # DRY-RUN snapshot: grouped artifacts + enumerated scenarios (no execution). ALL of tiny-full/sqlite/z3/llvm are project_run now (the raw variant view retired with A5 phase 5)
dune exec src/bin/canary_main.exe -- spec-check @all         # STATIC spec-maturity audit (✓/✗/⚠ per project, --json for web status, exit 1 on errors; tiny-full github/opam n/a). Reads only the declared artifact table
dune exec src/bin/canary_main.exe -- tiny run                # tiny1: run every single-scenario tiny project (the factory/harness)
dune exec src/bin/canary_main.exe -- artifact-test           # framework self-tests (native, ocaml, python, compat helpers)
dune exec src/bin/canary_main.exe -- pm-test                 # PM module self-tests
dune exec src/bin/canary_main.exe -- cache-test              # run-cache soundness (failed step must not cache as success — bug B) (apt/brew/opam/pip)
dune exec src/bin/canary_main.exe -- artifact-summary --kind native --path X  # ad-hoc summary dump
dune exec src/bin/canary_main.exe -- inspect-diff --old A --new B            # diff two inspect.json files
dune exec src/bin/canary_main.exe -- compat <project> [<variant>]            # static C-symbol cross-check
dune exec src/bin/canary_main.exe -- verify <project> [<variant>]            # cross-reference prediction vs probe.log
dune exec src/bin/canary_main.exe -- stages <project|@all>                # store-lifecycle coverage matrix (✓/-/⊘ + legend)
dune exec src/bin/canary_main.exe -- scenarios <project> --engine            # render variants as enumeration-algorithm provision assignments (ssot §4.2)
dune exec src/bin/canary_main.exe -- tiny engine                             # render tiny's scenarios as enumeration-algorithm mutation-axis projection
dune exec src/bin/canary_main.exe -- tiny assemble-check --id lib Bs.4       # P3 step 2: emit+assemble a vendored resource onto the witness base (needs `tiny prepare-all`)
dune exec src/bin/canary_main.exe -- status <project|@all> [-v]              # per-scenario last-run verdict matrix (xfail/✓/✗/·)
dune exec src/bin/canary_main.exe -- result [<project>] [--md|--json]        # THE result table: rows = project × scenario, columns = actions, cells = last-run verdicts (pure read); also refreshes docs/canary/projects/matrix.html (linked from the index)
dune exec src/bin/canary_main.exe -- project-test                            # project-definition layer tests (pure; catalogue/surface/enumerate/mechanism)
dune exec src/bin/canary_main.exe -- mutation-test                           # artifact-mutation self-tests
make canary                                                  # run canary via Makefile shorthand
	make canary-test                                             # post-change verification (project-test + artifact-test + pm-test)

**Post-change verification.** After every edit that touches `src/canary/`, run
`make canary-test`. This catches regressions in enumeration, compat theory,
tool assumptions (nm/ocamlobjinfo/python3), and PM presence — 95 + 109 + 14
tests, pure + shell, ~5s. The shared `Canary_runner.run_project_spec`
means both CLI and tests exercise the same pipeline. Before committing or
ending a session, also run `make canary-post-check` (sqlite + tiny1 bridge,
heavier, ~2min).
```

See [`doc/canary/design/algorithm_explainer.md`](doc/canary/design/algorithm_explainer.md)
for the full pipeline walkthrough (project declaration → action catalogue →
chains → assignments → execution). Current state and open items in
[`doc/canary/status.md`](doc/canary/status.md).

**tiny-factory / tiny1 / tiny-full** (ssot §4.2.5, status §1a — the
2026-08-02 arc). Three named things: **tiny-factory** = the machinery
(scenario specs + workspace materializer + vendored-resource emitter/
assembler); **tiny1** = the single-scenario projects, each a hand-written
good/bad case = the ground-truth *oracle* (`canary tiny run`); **tiny-full**
= *one* project (peer of sqlite/z3) that declares static artifact
**resources** and lets **canary** compute detection/expectation/collapse
(`canary action tiny-full`, NOT a `tiny` subcommand). Design principle
(**mutation-agnostic**): the runner knows nothing about mutations — a bad
artifact is a build at a **bad-quality version** (`build_id = {channel;
quality=Good|Bad tag}` in `canary_enumerate`), the `tag` opaque to the
runner; only the materializer knows a tag → a fault. Artifacts are
**vendored** — scenarios are *assembled* from pre-built variant resources
(overlay, no rebuild), so combinations are just more overlays and a
binding-over-bad-lib is a free deploy mismatch. Key symbols:
`Canary_enumerate.{quality,build_id,good}`;
`Canary_scenario.lower_expectation_agnostic` — THE one framework lowering
since A7 (derives the expectation by inspection); the ORACLE is a
tiny-factory combinator over it (`expectation_of_entry`: restrict to the
recipe's violated contracts + gate on manifestation + strengthen
Derived→must-fail); `Canary_tiny_scenario.{tiny_full_spec,
tiny_full_assignments,run_tiny_full}`; `Canary_tiny_workspace.{emit_resource,
assemble,assemble_check}` (P3 step 2, vendored emit+assemble).

Output layout (gitignored via `_*`):
- `_out/canary/projects/<project>/<step>/` — per-project action runs
  (z3/llvm write per-SCENARIO dirs since A5, e.g.
   `projects/z3/lib-built-dev_python_binding-fetched_source-fetched/`;
   pre-A5 `dev_<hash>/`/`stable/`/`19/` dirs may linger from old runs —
   `compat`/`verify` still glob those old names, a pending reconciliation)
- `_out/canary/test/{artifact-test,pm-test,artifact-summary}/` — framework
  self-tests and ad-hoc dumps
- `_out/canary/graph/action_graph.mmd` — universal schema diagram from `canary graph`

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
project/   THE PROJECT layer (canary_project library, 2026-08-14): the
           project DATATYPE + definition utils ([Canary_project_run]:
           project_run, policies, run_config, spec helpers;
           [Canary_opam_binding]: the definition template) PLUS the
           concrete instantiation (the 8 specs + tiny's factory + the
           entry modules that NAME projects: registry, CI jobs)
main/      the RUNNING layer (canary_main library, 2026-08-14):
           Canary_runner (run_project_spec + scenario_run_result),
           batch runner, spec-check, the layer test suite — the shared
           functions the cmd, the tests, and the batch runner consume;
           takes project_run VALUES / project lists (the bin injects
           Canary_registry.all_projects); references concrete projects
           in TEST code only
```

`base/`→`surface/`→`tool/`→`action/`→`backend/` is the dependency
order; `project/`, `main/` and `test/` consume the upper layers.
Dependency direction: canary_lib ← canary_project ← canary_main
(never the reverse).
(The retired `legacy/` sub-library was moved to
`doc/_legacy_code/` in commit `302f1b3`; the retired Python
tiny harness lives at `doc/_legacy_code/tiny_python_harness/`
per Phase E of the tiny migration.)

**Read `src/canary/base/` before writing code that introduces a type.**
`base/` is the shared vocabulary every layer reuses; a new vocabulary
type belongs there (in `canary_basic`/`canary_store`/`canary_lang`/
`canary_mechanism`/`canary_surface`/`canary_artifact_api`), not invented
in an upper layer — and check base/ for an existing type before adding
one. The base vocabulary types:

| module | types |
| --- | --- |
| `base/canary_lang.ml` | `lang` |
| `base/canary_basic.ml` | `artifact_kind` (what the scenario enumeration ranges over), `action`, `channel` (`Dev`/`Stable` release role) + concrete `version` record, `runner_os`, `probe_action`, `compile_mode`, output-tree naming (`filename`, `variant_file`) |
| `base/canary_store.ml` | `location`, `artifact_status` (lifecycle state), `provision` (provenance axis — ssot §4.2), `package_manager`, `pm_info`, `system_package_spec`, `distro`, `source_repo` |
| `base/canary_artifact_api.ml` | `native_api`, `binding_api` (provider/consumer claims) |
| `base/canary_mechanism.ml` | `discipline`, `mechanism` (binding identity — ssot §4.2.1b) |
| `base/canary_surface.ml` | `native_surface`, `binding_surface`, `surface` (checking-point view) |

Example of the trap this prevents: `provision` and a redundant `slot`
subset type were first defined in `action/canary_enumerate.ml`; `provision`
is base vocabulary (now in `canary_store`), and `slot` was dropped
entirely — the enumeration ranges over the existing `canary_basic.artifact_kind`
(re-exported by `canary_enumerate` as `artifact`). `canary_store.artifact_status`
likewise already existed as a related provenance/state type — worth
reconciling with, not duplicating.

### Key source files

| File                                                | Purpose                                                                                                |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `src/bin/canary_main.ml`                            | CLI: `action`, `paths`, `graph`, `compat`, `verify`, `inspect-diff`, `artifact-test`, `pm-test`, …     |
| `src/canary/base/canary_lang.ml`                    | `type lang = OCaml \| Python \| …`; sibling file so `canary_basic` + `canary_store` can both use it    |
| `src/canary/base/canary_basic.ml`                   | `artifact_kind`, `kind_order`, `action` (constructor type; was `rule` pre-2026-07-21), `string_of_action`/`action_of_string`, `step_body` (legacy shell carrier), `version`, `filename`, `variant_file` — live vocabulary including output-tree naming |
| `src/canary/base/canary_store.ml`                   | `location`, `package_manager`, `source_repo`, `distro`, `pm_properties` types (was canary_pm_types)    |
| `src/canary/base/canary_artifact_api.ml`            | Declarative `native_api` / `binding_api` types (provider/consumer claims, watchlists) — facts about library APIs |
| `src/canary/base/canary_mechanism.ml`               | Binding `discipline` (`Static_c_abi`\|`Dynamic_ffi`) + `mechanism` (`Cstubs`/`Cext`/`Ctypes`/`Cffi`/`Dynlink`) + `discipline_of_mechanism` + `default_mechanism_of_lang` (ssot §4.2.1b). Round 1 wires only Static. |
| `src/canary/base/canary_surface.ml`                 | `native_surface` / `binding_surface` / `surface` + `surface_of_api` — checking-point view (watchlists), provenance dropped (S1 of the detection-first redesign) |
| `src/canary/surface/canary_compat.ml`               | Pure theory: `inspect_input` ADT + c1..c8 comparators (`check_c_compat`, `check_abi`, `check_type`, …) + contract registry vocabulary (`contract_id`, `contract_status`, `contract_check`) |
| `src/canary/surface/canary_compat_run.ml`           | Drives the contract: cached-summary lookup + per-contract predict closures (`c1_predict`, …) + `registered_checks` list + `predicted_contains_any_v2 ~resolve` (4-line iterator over the registry) + CLI run/verify |
| `src/canary/tool/canary_toolchain.ml`               | OCaml toolchain types, opam packaging helpers, `pip_install_cmd` / `python_probe_only_cmd`             |
| `src/canary/tool/canary_build_cmd.ml`               | Generic build-tool primitives: `cmake_configure_cmd`, `ninja_build_cmd`, `dune_build_cmd`, `with_marker` |
| `src/canary/tool/canary_store_config.ml`            | `store_config` (`source`/`lib`/`bindings` stores) + `binding_store` / `lib_store` records + `binding_pm` (S3 of the detection-first redesign; where each artifact lives, per-artifact) |
| `src/canary/tool/canary_artifact_native.ml`         | nm-based native lib summaries; `--emit-symbols` for compat cross-check                                 |
| `src/canary/tool/canary_artifact_lang.ml`           | OCaml + Python summary helpers (mli, stub, ocamlobjinfo, `dir()`)                                      |
| `src/canary/tool/canary_artifact_source.ml`         | Source artifact helpers; `scan_source` post-fetch verification                                         |
| `src/canary/tool/canary_inspect_diff.ml`            | `canary inspect-diff` — counts/modules/watchlist/versioned_req drift                                   |
| `src/canary/tool/canary_pm_{apt,brew,opam,pip}.ml`  | Per-PM presence checks + install commands; `canary_pm_test.ml` runs the suite                          |
| `src/canary/action/canary.ml`                       | 27-line `include` shim (Canary_action + Canary_step_model + Canary_path_table); still consumed by `canary_project_llvm.ml` + `canary_diagram.ml` via `open Canary`. |
| `src/canary/action/canary_action.ml`                | `action_graph` (was `action_rule` pre-2026-07-21), `store_actions`, `make_action_graph`, `nodes_of_action_graph`, `node_status`, `artifacts_of_action` (colocated 2026-07-22) — the action-graph schema + per-action consumes/produces (SSOT §6.5) |
| `src/canary/action/canary_step_model.ml`            | `step_expectation` (incl. `Expect_compat_failure`), `step` (was `action_step` pre-2026-07-21), `logger`, `version_info`, `symbol_*` |
| `src/canary/action/canary_path_table.ml`            | 15-pattern table + `pp_job_path_table` / `pp_job_path_table_md` (CLI `paths` / `paths-md`)             |
| `src/canary/action/canary_binding_templates.ml`     | M2 step 4 realization: `binding_decl` × ctx → build_binding/probe_binding/probe_lib/user_facing_pkg cmd builders (tiny consumes it; pinned byte-equal to the former hand-written literals) |
| `src/canary/action/canary_step_builder.ml`          | `runner_spec` (was `project_spec` pre-2026-07-21), `derive_steps`, shared command templates, check_post compositors — the step list builder |
| `src/canary/action/canary_scenario.ml`              | `scenario` type + Sc.1..Sc.6 patterns (`good_scenarios`); mutation vocab (`mutation_kind`, `origin`); contract binding vocab (`firing_site`, `loc_filter`, `expectation_source`, `firing`, `contract_binding`); `lower_expectation_agnostic` — THE one expectation lowering since A7 (the oracle variant retired; tiny1 composes it as a factory combinator); `derive_scenarios`; `related_artifacts_of_actions`. |
| ~~`canary_scenario_util.ml`~~ (deleted 2026-08-05)  | Folded back into `canary_tiny_scenario.ml` — the "project-agnostic scenario helpers" never gained a second consumer. |
| `src/canary/action/canary_scenario_coverage.ml`     | Store-lifecycle **abstract-stage** catalogue + per-project coverage marks (`Covered`/`Unspecified`/`Disabled` → `✓`/`-`/`⊘`). `run_app` realized by `Probe_app`\|`Probe_binding`; `build_binding` gated on `is_static_binding_lang`. Drives `canary scenarios`. |
| `src/canary/action/canary_enumerate.ml`             | The `(provision × version × mutation)` enumeration algorithm (ssot §4.2) — pure product-then-filter, polymorphic in the mutation. Ranges over `artifact` (= `Canary_basic.artifact_kind`); `placement` (per-artifact provision + version), `run_config`/`level`/`config`, `tiny_slice`/`general_slice`, `provision_of_actions`. Folds into `canary_scenario.ml` when the convergence's replacement lands. |
| ~~`canary_project.ml`~~ (deleted 2026-08-05, A6)    | The `Canary_project.project` bundle was never read by anything — `Canary_project_run.project_run` IS the project identity (§6.1 top) for generic projects; contract bindings live where consumed (`*_contract_bindings` → expectation lowering). |
| `src/canary/backend/canary_local_runner.ml`         | `run_step`, `run_graph`, `merge_step_statuses` + the cross-run cache (`load_cache`, `cache_is_success`, …) — executes the step list locally (in-process backend) |
| `src/canary/backend/canary_run_info.ml`              | `run_info` + `run_project` / `run_project_multi` orchestrators + `save_run_state` / `view_project`     |
| `src/canary/backend/canary_gh.ml`           | GitHub Actions YAML rendering; resolves `Expect_compat_failure` predictions at gen time                |
| `src/canary/backend/canary_html.ml`         | HTML result page + index rendering                                                                     |
| `src/canary/backend/canary_detect.ml`               | Forecast-agnostic detection (S5a): `finding` (`tag`/`errored`/`output_present`) + `simple_finding` — classify a step by its raw outcome, independent of any expectation/contract |
| `src/canary/backend/canary_status.ml`               | `canary status` — per-scenario last-run verdict matrix (`xfail`/`✓`/`✗`/`·`) + `-v` witness lines (tails result files); `projects_with_runs` for `@all` |
| `src/canary/backend/canary_diagram.ml`              | Mermaid diagram + view machinery (2283 LOC; biggest single file)                                       |
| `src/canary/test/canary_artifact_test.ml`           | Framework self-tests (native, OCaml, Python, compat helpers — pure + shell)                            |
| `src/canary/test/canary_pm_test.ml`                 | PM module self-tests                                                                                   |
| `src/canary/test/canary_project_test.ml`            | Project-definition layer tests (`canary project-test`) — pure: action consumes/produces catalogue, surface split, store-config derive, detect, coverage abstract stages, mechanism defaults, enumerate two-projections |
| `src/canary/project/canary_project_sqlite.ml`      | sqlite3 project spec; OCaml + Python (stdlib) probes                                                   |
| `src/canary/project/canary_project_ssl.ml`         | OpenSSL/`ssl` project; variant matrix (`variants` = 0.6.0/0.7.0 × core/native-lib-version) via `mk_variant`; folded native probe. All fetch-origin (Level A). |
| `src/canary/project/canary_project_cairo.ml`       | cairo project via `Canary_opam_binding` (conf-* + opam binding); Level A                                  |
| `src/canary/project/canary_project_zarith.ml`      | zarith project via `Canary_opam_binding` (conf-* + opam binding); Level A                                 |
| `src/canary/project/canary_project_z3.ml`          | z3 spec; `z3_source_stable` has `has_build_binding=false`. Python probe demonstrates derived L3 fail   |
| `src/canary/project/canary_project_llvm.ml`        | LLVM spec; per-variant `mk_runner_spec ~source`. Stable OCaml probe expects `Opcode.UncondBr` compat-failure — flows through `Canary_scenario.lower_expectation` over `llvm_stable_contract_bindings` (Task 2 Phase D 2026-07-21). |
| `src/canary/project/canary_project_z3.ml`          | z3 spec; per-variant `mk_runner_spec ~source`. Python probe expects `z3.parser_context` compat-failure — flows through `lower_expectation` over `z3_contract_bindings` (Task 2 Phase E 2026-07-21). `z3_source_stable` has `has_build_binding=false`. |
| `src/canary/project/canary_tiny_scenario.ml`       | Tiny's whole scenario engine + factory: scenario_spec type, all_scenario_specs (15 hand + 7 derived = 22), tiny_contract_bindings, recipe_of_derived_cell, make_base_runner_spec, project_spec_of_entry, tiny_project bundle. See `doc/canary/worklog/tiny_migration.md`. |
| `src/canary/project/canary_tiny_baseline.ml`       | `canary tiny baseline` — direct-compile clean tree + 7 inspectors + workspace materialization. |
| `src/canary/project/canary_tiny_prepare.ml`        | `canary tiny prepare[-all]` + `confirm` — sandbox-build model (live tree never mutated); surface_delta mirrors retired Python `_surface_delta`. |
| `src/canary/project/canary_tiny_workspace.ml`      | Workspace materialization for tiny scenarios: mutation dispatch (Source / Native / Binding via `canary_artifact_mutation.ml`), RUNPATH strip on cached cext, `libtiny.so` symlink synthesis. Framework infra — do NOT copy per-project (see `dynamic_enumeration.md` "Derived vs hand-written"). |
| `src/canary/project/canary_opam_binding.ml`           | Pattern A template (conf-* + opam binding); consumed by zarith + ssl + cairo + libffi specs           |
| `src/canary/project/canary_registry.ml`            | `all_projects` — THE single source of truth for project names (`Project` | `Multi`); `project_of` lookup. One entry per project; `action`/`spec`/`scenarios` dispatch through it. |
| `src/canary/project/canary_run.ml`                 | GH CI job specs (`ci_jobs`); z3/llvm source-build CI steps + Pattern A smoke jobs                        |
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
| `doc/canary/design/ssot.md`                    | Project-wide SSOT — canonical ID tables (Ar/Sf/Ag/Sc/scenarios/actions) bridging manuscript ↔ code    |
| `doc/canary/design/versioning.md`              | Versioning-unification tracker — typed `version` as artifact identity across enumeration/store/cache; scope (pieces A/B/C), simple-projects-first strategy, test plan, open questions |
| `doc/canary/design/dynamic_enumeration.md`     | The enumeration→node-graph model (short, canonical): the stage pipeline (spec/policy → `enumerate` → assignment → `close_deps` → node graph); assignment = flat IR, node graph = derived backend view; build edges grammatical (the seam), runtime edge resolved by `dep_mode` (Lockstep/Independent/Ambient). To-dos in status §A. (Absorbed the retired `enumeration_graph.md`.) |
| `doc/canary/design/scenario_terms.md`          | OPEN terminology to-do: "scenario" still overloaded vs abstract senses (`Sc.N` patterns, coverage *stages*); audit + T0/T1/T2 options + open questions. Decide before renaming `canary scenarios` or splitting the dual-use scenario type (ride F5). |
| `doc/canary/README.md`                         | Directory map + four-pillar alignment entry point (theory + tiny witness + roadmap)                   |
| `doc/canary/research/surface.md`               | **Manuscript-in-progress** (renamed from `notes.md` 2026-06-04). Confirmed-content writeup; five-part spine (BB / SS / TT / CC / MM); backbone (rules / traces / worlds), PL notation, implementation slots. **Authoritative** for current framing. |
| `doc/canary/research/surface_draft/`           | **Materials collection** (split 2026-06-04, surface_theory.md removed). Older drafts split across `main.md`, `surface.md`, `principle.md`, `implementation.md` (§2.7 pointers, may be stale), `package.md`, `versioning.md`, `notation.md`. Mine for content; not authoritative. |
| `doc/canary/research/drafting.md`              | Drafting playbook + active edit queue for `surface.md` (drafting order, per-section sources, batched edits)  |
| `doc/canary/research/tiny.md`                  | Witness (current): minimal C lib + 3 bindings + 13-variant canary matrix + harness scenario table + findings |
| `doc/canary/research/plan.md`                  | Paper venues + milestones + working roadmap (steps 1-5; step 1+2 done)                                |
| `doc/canary/ops/install_targets.md`            | Z3 vs LLVM cmake install patterns; informs TODO #40                                                    |
| `doc/canary/ops/llvm_build.md`                 | LLVM source build steps, smoke test, opam install notes                                                |
| `doc/canary/backlog.md`                        | Lower-priority TODOs; api-compat group + new project spec group (see line below for current set)       |

### Architecture in one paragraph

`store_actions ~langs` and `artifacts_of_action` in
`action/canary_action.ml` define the universal action catalogue (SSOT
§6.5): what actions run + what artifacts each touches, per kind (Source
→ Headers → Lib → Binding → App, per language). `pattern_rows_of_paths`
in `action/canary_path_table.ml` enumerates 15 structural patterns
like `fetch_source → build_lib → build_binding`. A project provides a
`runner_spec` (`action/canary_step_builder.ml` — shell commands per
action) plus an `api_source` (declarative provider/consumer surface
— header paths, symbol prefixes, watchlists) plus (optionally) a
`<project>_contract_bindings` list feeding
`Canary_scenario.lower_expectation` for per-firing failure predictions.
`derive_steps` walks the catalogue, filters by project capabilities,
attaches per-artifact summaries (mli, stub, native, python), and emits
a `step list`. Four sibling backends consume it:
`backend/canary_local_runner.ml` executes; `backend/canary_gh.ml`
renders GH Actions YAML; `backend/canary_diagram.ml` renders Mermaid;
`backend/canary_html.ml` renders HTML. `run_graph` executes with
`check_pre`/`check_post` filesystem checks and appends to
`actions.log`. Probe expectations come from `Expect_success` |
`Expect_failure { contains_any }` | `Expect_compat_failure { inputs;
version_info }` — the compat-failure inputs are read at runtime by
`surface/canary_compat_run.ml`'s `predicted_contains_any_v2 ~resolve`
which iterates the registered contracts over the inputs bag to compute
predicted failure substrings (L0 C-symbol diff + L3 watchlist-missing
etc.). The top-level project identity is `Canary_project_run.project_run`
for generic projects (A6 2026-08-05: the never-read `Canary_project.project`
bundle was deleted); each project's module owns its scenarios directly
(tiny1 has 22 via factory). `run_project_multi`'s last consumer is ssl
(4 hand-listed variants); tiny's factory (`canary_tiny_scenario.ml`)
restricts each `runner_spec` to one scenario's world. **The project
registry** (`Canary_registry.all_projects`, 2026-08-12) is THE single
source of truth for project names — `action`/`spec`/`scenarios` each do
one `List.assoc_opt` lookup; adding a project = adding one entry
(`Project pr` runs via `run_project_run`, `Multi (name, variants)` via
`run_project_multi` — ssl only). Pattern A projects wrap their
`runner_spec` via `Canary_project_run.simple`. **The generic
path** (tiny-full + sqlite + z3 + llvm since A5, 2026-08-05)
is `run_project_run` over a `Canary_project_run.project_run`
(`pr_spec → scenarios_of (the general enumerate; ?policy, --thin =
thin_policy) → pr_runner_spec → derive_steps → run`): a project declares
only DATA — `pr_spec` is ONE fused table (`ps_universe : artifact ×
(provision × versions) list`; old accessor names are functions over it),
`pr_artifacts` THE artifact table (`artifact_decl` rows: identity +
provider — the old separate `pr_provenance` assoc merged in 2026-08-06;
`provenance_of`/`artifact_ids` read it),
`pr_mismatch_probes` a design-intent table (which consumer variants are
designed forward/backward probes; per-scenario direction is COMPUTED via
`mismatch_direction_of`). `pr_runner_spec` must be `realize ∘ dispatch`
(pure project-local `scenario_case` data reading only
`Canary_enumerate.{provision_of,channel_of,provided,bad_placements}`;
`realize` holds the command templates — the only functions left). xfail
(`Step_done_xfail`, persisted in verdict-marker content) + watchlist
verdicts surface in `action`/`spec`/`status` (status rows show
`watchlist N/N` / `⚠ MISSING …`; sqlite's python watchlist carries
declared binding-lag markers). There is NO per-project enumeration
closure (`pr_enumerate` retired 2026-08-05); the runner
computes `scenario_dir_of a` (a born-safe per-scenario dir = output
path + dedup key; a `Fetched` artifact is version-ambient so its
declared version is NOT part of scenario identity — two `Fetched@v`
scenarios dedup). There is **no** `pr_materialize`/pre-place field:
tiny-full assembles its vendored tree INSIDE its `pr_runner_spec`
(the `materialize` symbol lives only in tiny-factory,
`canary_tiny_workspace`); a real project builds/fetches into the
runner-given dir. See SSOT §6.1 for the taxonomy
(project → scenario ≡ variant → runner_spec → step → action) and
`dynamic_enumeration.md` ("Derived vs hand-written") for what's data vs code.

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
See `surface_draft/implementation.md` §2.7.

### Current state

See [`doc/canary/status.md`](doc/canary/status.md) for current implementation
state and open items. Lower-priority items live in
[`doc/canary/backlog.md`](doc/canary/backlog.md). Completed work is chronicled
in [`doc/canary/worklog/`](doc/canary/worklog/).

## Other Work: Yelu

Yelu is now a standalone project at `/home/red/code/research/yelu` with its own CLAUDE.md, build system, and opam package. It was extracted from `yelu/` on 2026-05-04. If you need to work on yelu, switch to that repo.

## Gotchas

- **Diagram connectivity invariant is MUTED by default** (2026-08-05): the
  diagram self-check "does the drawn `.mmd` reproduce every `step.deps` edge?"
  fails for **all four** projects (z3/llvm/sqlite/tiny-full) — the diagram's
  hand-built edge topology (`canary_diagram.ml`) and the runner's `step.deps` are
  two separate dependency relations that drifted. It is NOT a run bug (every step
  `check_pre` enforces its real deps; execution is sound) — only the picture
  under-connects. Gated behind `CANARY_DIAGRAM_CONN=1` (default off) so runs don't
  print "connectivity errors … SOME FAILED"; the coverage invariant still runs.
  Real fix = reconcile `step.deps` with the typed node graph into one relation
  (status §A "Merge cleanup"); diagram work is on hold.
- **`Fetched` is version-ambient in scenario identity**: `scenario_dir_of`
  (`canary_main.ml`) drops a `Fetched` placement's declared version from the
  scenario id (the PM picks the actual version), so `Fetched@Stable ≡ Fetched@Dev`
  dedup to one run; `Built`/`Vendored` versions ARE identity. Since the
  per-provision version axis (2026-08-05) specs no longer declare versions a
  Fetched artifact can't pin (sqlite declares 3, runs 3 — no dedup needed);
  the identity rule stays as the generic backstop. A project that pins a
  Fetched version would override via its provider (`pr_artifacts` row) — not wired yet.
- **Run-cache stale hit looks like a real PASS**: a step is skipped when its
  `.ok` marker exists and `check_post` passes (local cache), keyed by
  `variant_id` (the part after `/` in `project`, e.g. `tiny/<name>`). Re-running
  a *different* workspace under the **same** `variant_id` (e.g. a source-only
  Built tree reusing a name previously run Vendored) serves the stale marker —
  no build runs, but status reads PASS. Force a fresh run with `rm -rf
  _out/canary/projects/<name>` or a distinct `variant_id`. To coexist (Built vs
  Vendored, dev vs stable) put those axes in `variant_id`. See
  [`doc/canary/design/algorithm_explainer.md`](doc/canary/design/algorithm_explainer.md) §8.
- **OCaml LSP stale diagnostics**: Cross-module edits show false errors
  until dune rebuilds. ocamllsp reads compiled `.cmi` files; no
  in-memory cross-module resolution. Ignore during multi-file refactors,
  verify with `dune build` at the end.
- **`open Base` shadows stdlib**: `result`, `prefix`, `id`, `append`
  are shadowed — rename in pattern matches.
- **`open Base` shadows `=`/`<>` as INT-only comparisons**:
  `Int_replace_polymorphic_compare` (import0.ml) redefines `=`/`<>`/`<`/
  `>`/`<=`/`>=` as `int -> int -> bool` externals. `a = b` on strings or
  lists under `open Base` is a TYPE ERROR ("expected of type int/2").
  Use `Poly.equal` / `Poly.(<>)` for polymorphic equality, or
  `List.is_empty`/`Bool.equal` per the codebase idiom.
- **Mermaid v11+**: User's renderer supports `@{ shape: docs }` syntax.
  Safe to use modern Mermaid features in `.mmd` files.
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
- **`python3-config` not universally available**: standard on
  systems with `python3-dev` (apt) / `python3-devel` (dnf) but
  venvs deliberately omit the `-config` wrapper, and some
  container distros strip `-dev` packages entirely. Use
  `python3 -c 'import sysconfig; print(sysconfig.get_paths()["include"])'`
  and `sysconfig.get_config_var("EXT_SUFFIX")` instead of shelling
  to `python3-config --includes`. Sysconfig is stdlib, works
  everywhere. See `canary_tiny_baseline.ml:build_python_cext`.
- **OCaml module name mangling: dune wrapping vs direct
  ocamlopt**: dune's default library-wrapping convention produces
  module names like `Tiny__` / `Tiny__Tiny_raw` / `Tiny` in a
  `.cmxa` (a wrapper module + submodules with underscore-doubled
  prefix). Direct `ocamlfind ocamlopt -a` without wrapping
  produces plain top-level modules `[Tiny_raw; Tiny]`. `bo6`
  inspection (`ocamlobjinfo`) reports the difference; any consumer
  that hardcodes specific mangled names (e.g. `Tiny__Foo`) will
  break under a direct-compile path. Watchlists that reference
  only the top-level module (`Tiny`, `Tiny.sum`) work either way.
  See `canary_tiny_baseline.ml:build_ocaml_binding` comment.

- **Artifact ids use `-` not `:` — born-safe for `$PATH`-like env vars.**
  `string_of_id` outputs `binding-ocaml-cstubs`, safe for `PYTHONPATH` /
  `LD_LIBRARY_PATH` which are `:`-separated. Never reintroduce `:` in ids.
- **A cached artifact must carry SOURCE, not just the built output** (Fix A):
  `subdirs_of_artifact` returns the built subdir **plus** the source the compat
  inspectors read (mli/headers/py). Overlaying only the built subdir left the
  base's good `.mli`/header in place, so source-manifested drift (a dropped val =
  C2) was invisible and the real failure read as *unexpected*. Terminology: the
  vendored bundle is a **cached artifact** (`cache_artifact`/`cached_artifact_dir`
  in `canary_tiny_workspace.ml`), NOT a "resource" — ssot uses artifact /
  artifact_kind.
- **Types shared by multiple `action/` modules belong in `base/`.**
  `canary_action.ml` once depended on `canary_enumerate.ml` for `build_id`,
  `assignment` — moved to `Canary_basic`/`Canary_artifact` (base/).
  Rule: put every type-like thing in `base/` unless only one module consumes it.
- **When moving types between modules, record fields and functions stay behind.**
  `type t = NewModule.t` creates an alias, but record fields belong to the module
  where the type is DEFINED (`pl.Canary_artifact.provision`, not
  `pl.Canary_enumerate.provision`). Functions on the type (`placement_of`, etc.)
  also stay in the original module unless explicitly moved. And `open Module`
  does not re-export — aliased types are not accessible through `EN.xxx`.

## Conventions

- `cc` = Claude Code (user shorthand)
- Allowed bash: `make *` and `dune *` only

## Concurrent agents (worktrees)

Two agents work on this repo: a code session (this tree, `ds-workflow`)
and a project agent (`tola-m3`, branch `m3-agent`). Setup, 2026-08-14:

- **Commit first** — a new worktree bases off HEAD, so commit the
  working tree before `git worktree add` (the dune-scan fix and tiny
  cache relocation live in the tree, not at HEAD).
- `git worktree add /home/red/code/research/tola-m3 -b m3-agent`
- **Shared `_out`** — `tola-m3/_out` is a symlink to `../tola/_out`
  (cross-run cache + run outputs shared; the tiny factory cache lives
  there too, `_out/canary/tiny/`). Each tree's root `dune` excludes
  `_out` from the walk.
- **VSCode entry** — `tola/vendor/tola-m3` symlink → `../../tola-m3`
  (gitignored; `vendor` is dune `data_only_dirs` so no recursion).
  Add it as a workspace folder.
- **Sync on demand, not per commit** (2026-08-17, user) — each tree
  works independently; commits on one branch don't touch the other
  until a merge. The main→worktree `ff-only` sync happens only when
  the worktree agent resumes work or at merge-back time — no ritual
  after every commit. Conflicts (if any) surface at merge time and
  the merging side resolves them.
- **Merge back** — normal git: commit on `m3-agent`, then
  `git merge m3-agent` from `ds-workflow`; `git worktree remove
  tola-m3` and `git branch -d m3-agent` after. `_out` is gitignored
  and shared, so merges carry source only.
- **Overlap warning** (2026-08-17, user) — two streams touching the
  same shared-core files (project_run, specs, spec_check) was tried
  and judged a bad idea: parallel checkouts don't give parallel
  development. Shared-core changes happen in the MAIN tree
  (commit-first); the worktree is for genuinely disjoint chunks
  (new-project landings that mostly add files). The m3 agent is
  PAUSED (2026-08-17); its uncommitted leftovers may sit in either
  tree.
- Worktree caveats: cold dune build per tree (~minutes, done once);
  dune-scan fix inherited only if the base commit is recent; the
  tool-routing ratchet baselines are shared — resolve at merge time.

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
