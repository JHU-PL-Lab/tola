# Claude Code — Project Guide

## Build & Run

```sh
dune build                                                   # build everything
dune exec src/bin/canary_main.exe -- paths                   # print 15-row action pattern table
dune exec src/bin/canary_main.exe -- paths-md                # same, markdown output
dune exec src/bin/canary_main.exe -- graph                   # write docs/canary/graph/action_graph.mmd
dune exec src/bin/canary_main.exe -- action sqlite
dune exec src/bin/canary_main.exe -- action z3               # runs z3 (dev) + z3/stable
dune exec src/bin/canary_main.exe -- action llvm             # runs llvm (dev) + llvm/19
dune exec src/bin/canary_main.exe -- action tiny-full        # tiny-full PROJECT (peer of z3): algorithm-driven good+bad run + coverage
dune exec src/bin/canary_main.exe -- action tiny-full --thin # thin Subset config: Stable, single-bad, no ctypes/combos (12/20 cold==warm)
dune exec src/bin/canary_main.exe -- spec tiny-full          # DRY-RUN snapshot: grouped artifacts + enumerated scenarios (no execution). project_run: tiny-full/sqlite; variant view (raw runner_spec, read-only): z3/llvm
dune exec src/bin/canary_main.exe -- tiny run                # tiny1: run every single-scenario tiny project (the factory/harness)
dune exec src/bin/canary_main.exe -- artifact-test           # framework self-tests (native, ocaml, python, compat helpers)
dune exec src/bin/canary_main.exe -- pm-test                 # PM module self-tests
dune exec src/bin/canary_main.exe -- cache-test              # run-cache soundness (failed step must not cache as success — bug B) (apt/brew/opam/pip)
dune exec src/bin/canary_main.exe -- artifact-summary --kind native --path X  # ad-hoc summary dump
dune exec src/bin/canary_main.exe -- inspect-diff --old A --new B            # diff two inspect.json files
dune exec src/bin/canary_main.exe -- compat <project> [<variant>]            # static C-symbol cross-check
dune exec src/bin/canary_main.exe -- verify <project> [<variant>]            # cross-reference prediction vs probe.log
dune exec src/bin/canary_main.exe -- scenarios <project|@all>                # store-lifecycle coverage matrix (✓/-/⊘ + legend)
dune exec src/bin/canary_main.exe -- scenarios <project> --engine            # render variants as enumeration-algorithm provision assignments (ssot §4.2)
dune exec src/bin/canary_main.exe -- tiny engine                             # render tiny's scenarios as enumeration-algorithm mutation-axis projection
dune exec src/bin/canary_main.exe -- tiny assemble-check --id lib Bs.4       # P3 step 2: emit+assemble a vendored resource onto the witness base (needs `tiny prepare-all`)
dune exec src/bin/canary_main.exe -- status <project|@all> [-v]              # per-scenario last-run verdict matrix (xfail/✓/✗/·)
dune exec src/bin/canary_main.exe -- project-test                            # project-definition layer tests (pure; catalogue/surface/enumerate/mechanism)
dune exec src/bin/canary_main.exe -- mutation-test                           # artifact-mutation self-tests
make canary                                                  # run canary via Makefile shorthand
```

Scenario-enumeration model (ssot §4.2): one abstract enumeration
algorithm (`action/canary_enumerate.ml`) over per-artifact axes
(provision / version / mechanism / mutation), each axis set to a config
level (Free / Subset / Full). tiny and a real project are two configs of
the one algorithm. `scenarios`/`tiny engine` render each hand-written
enumeration through it; implementation state in `doc/canary/status.md`.

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
`Canary_enumerate.{quality,build_id,good}`; `Canary_scenario.lower_expectation`
(oracle path) vs `lower_expectation_agnostic` (P2b — derives the expectation
by inspection, no per-scenario `violates`); `Canary_tiny_scenario.{tiny_full_spec,
tiny_full_assignments,run_tiny_full}`; `Canary_tiny_workspace.{emit_resource,
assemble,assemble_check}` (P3 step 2, vendored emit+assemble).

Output layout (gitignored via `_*`):
- `_out/canary/projects/<project>/<step>/` — per-project action runs
  (`action llvm` writes `projects/llvm/dev_<hash>/` + `projects/llvm/19/`;
   `action z3` writes `projects/z3/dev_<hash>/` + `projects/z3/stable/`)
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
projects/  live project specs (canary_projects sub-library)
```

`base/`→`surface/`→`tool/`→`action/`→`backend/` is the dependency
order; `projects/` and `test/` consume the upper layers.
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
| `src/canary/action/canary_step_builder.ml`          | `runner_spec` (was `project_spec` pre-2026-07-21), `derive_steps`, shared command templates, check_post compositors — the step list builder |
| `src/canary/action/canary_scenario.ml`              | `scenario` type + Sc.1..Sc.6 patterns (`good_scenarios`); mutation vocab (`mutation_kind`, `origin`); contract binding vocab (`firing_site`, `loc_filter`, `expectation_source`, `firing`, `contract_binding`, `lower_expectation` — the shared expectation lowering used by tiny/z3/llvm); `derive_scenarios`; `related_artifacts_of_actions`. |
| `src/canary/action/canary_scenario_util.ml`         | Small project-agnostic helpers extracted from tiny (`pert`, `matches_derived_cell`, `detector_short`, `violates_label`, `artifact_index`, `bad_target_str`) — currently only consumed by tiny (via `let alias = ...`). |
| `src/canary/action/canary_scenario_coverage.ml`     | Store-lifecycle **abstract-stage** catalogue + per-project coverage marks (`Covered`/`Unspecified`/`Disabled` → `✓`/`-`/`⊘`). `run_app` realized by `Probe_app`\|`Probe_binding`; `build_binding` gated on `is_static_binding_lang`. Drives `canary scenarios`. |
| `src/canary/action/canary_enumerate.ml`             | The `(provision × version × mutation)` enumeration algorithm (ssot §4.2) — pure product-then-filter, polymorphic in the mutation. Ranges over `artifact` (= `Canary_basic.artifact_kind`); `placement` (per-artifact provision + version), `run_config`/`level`/`config`, `tiny_slice`/`general_slice`, `provision_of_actions`. Folds into `canary_scenario.ml` when the convergence's replacement lands. |
| `src/canary/action/canary_project.ml`               | `Canary_project.project` — top-level bundle at the SSOT §6.1 taxonomy top (name + contract_bindings). Concrete monomorphic; each project's module owns its scenarios directly. Only `tiny_project` inhabited today (z3/llvm/sqlite bundles deferred). |
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
| `src/canary/projects/canary_project_sqlite.ml`      | sqlite3 project spec; OCaml + Python (stdlib) probes                                                   |
| `src/canary/projects/canary_project_ssl.ml`         | OpenSSL/`ssl` project; variant matrix (`variants` = 0.6.0/0.7.0 × core/native-lib-version) via `mk_variant`; folded native probe. All fetch-origin (Level A). |
| `src/canary/projects/canary_project_cairo.ml`       | cairo project via `Canary_pattern_a` (conf-* + opam binding); Level A                                  |
| `src/canary/projects/canary_project_zarith.ml`      | zarith project via `Canary_pattern_a` (conf-* + opam binding); Level A                                 |
| `src/canary/projects/canary_project_z3.ml`          | z3 spec; `z3_source_stable` has `has_build_binding=false`. Python probe demonstrates derived L3 fail   |
| `src/canary/projects/canary_project_llvm.ml`        | LLVM spec; per-variant `mk_runner_spec ~source`. Stable OCaml probe expects `Opcode.UncondBr` compat-failure — flows through `Canary_scenario.lower_expectation` over `llvm_stable_contract_bindings` (Task 2 Phase D 2026-07-21). |
| `src/canary/projects/canary_project_z3.ml`          | z3 spec; per-variant `mk_runner_spec ~source`. Python probe expects `z3.parser_context` compat-failure — flows through `lower_expectation` over `z3_contract_bindings` (Task 2 Phase E 2026-07-21). `z3_source_stable` has `has_build_binding=false`. |
| `src/canary/projects/canary_tiny_scenario.ml`       | Tiny's whole scenario engine + factory: scenario_spec type, all_scenario_specs (15 hand + 7 derived = 22), tiny_contract_bindings, recipe_of_derived_cell, make_base_runner_spec, project_spec_of_entry, tiny_project bundle. See `doc/canary/worklog/tiny_migration.md`. |
| `src/canary/projects/canary_tiny_baseline.ml`       | `canary tiny baseline` — direct-compile clean tree + 7 inspectors + workspace materialization. |
| `src/canary/projects/canary_tiny_prepare.ml`        | `canary tiny prepare[-all]` + `confirm` — sandbox-build model (live tree never mutated); surface_delta mirrors retired Python `_surface_delta`. |
| `src/canary/projects/canary_tiny_workspace.ml`      | Workspace materialization for tiny scenarios: mutation dispatch (Source / Native / Binding via `canary_artifact_mutation.ml`), RUNPATH strip on cached cext, `libtiny.so` symlink synthesis. Framework infra — do NOT copy per-project (see `derived_vs_hardcoded.md §3`). |
| `src/canary/projects/canary_pattern_a.ml`           | Pattern A template (conf-* + opam binding); consumed by zarith + ssl specs                             |
| `src/canary/projects/canary_run.ml`                 | Project orchestrator; runs llvm+llvm/19 and z3+z3/stable                                               |
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
| `doc/canary/design/enumeration_graph.md`       | Instance/dependency-graph design note (ssot §4.2.4): the graph (nodes + build/run edges + version-mismatch) already exists as `artifact_node`/`make_action_graph` — plan is a *merge* (one instance = artifact_node + ext + typed version), not a reimplementation; edge ≈ action |
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
etc.). `Canary_project.project` (`action/canary_project.ml`) is the
top-level bundle name + contract_bindings; each project's module owns
its scenarios directly (tiny has 22 scenarios via factory; z3/llvm have
2-3 variants each via `mk_runner_spec ~source`; sqlite has none —
positive-only). `run_project_multi` runs the scenarios/variants list
per project; tiny's factory (`canary_tiny_scenario.ml`) restricts
each `runner_spec` to one scenario's world, z3/llvm build one
`runner_spec` per source variant. See SSOT §6.1 for the taxonomy
(project → scenario ≡ variant → runner_spec → step → action) and
`derived_vs_hardcoded.md` for what's data vs code.

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
#35, #41, #42 (api-compat — see research/surface_draft/implementation.md §2.7).
Details in `doc/canary/backlog.md`.

### Known Gaps (interface / expectation layer)

These are tracked here rather than the backlog because they directly affect
the `step_expectation` / interface model design.

Artifact summary progress (`doc/canary/research/surface_draft/`):
- ✅ Step 1 — `summary_cmd` for native/ocaml/python/mli/stub kinds
- ✅ Step 2 — watchlists declared per project (z3/llvm/sqlite), `summary`
  field on `script_spec`, install-step + probe-step summaries in
  `derive_steps`
- ✅ `inspect-diff` subcommand (local only; no committed cache yet)
- ✅ Summary command coverage in `canary_artifact_test.ml` (incl. compat
  helper pure tests)
- ✅ Compat cross-check shipped — `canary compat`, `canary verify`,
  `Expect_compat_failure` derive expected probe-failure substrings from
  cached summaries. See `surface_draft/implementation.md` §2.7. Live demos on llvm/19 (OCaml
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
  `step` (or extend `preamble_steps` semantics). Couples with
  "multi-ocaml-version matrix" (old supported `ocaml-version: ["5.4.0"]`
  in the matrix). GH macOS runners are paid minutes — ship selectively
  (sqlite + one other). Strictly a follow-up to (1) and (2).

  **Order to execute**: (1) finish core framework + parser fallbacks →
  (2) exercise on SSH Mac to catch gaps the Linux-only runs hid →
  (3) wire up GH CI matrix only after (1) and (2) are green. Skipping
  ahead to (3) burns paid CI minutes on known failures.
- **Missing distro × sys-PM × lang-PM enumeration model.** The retired
  YAML/shell backend plumbing (`project_config`, `step_phase`,
  `canary_backends`, `canary_config`, `mk_canary_config`, per-project
  `config distro` fns) has already been moved to
  `doc/_legacy_code/canary_yaml_backend.ml` and deleted from the live
  tree (see the comment blocks in `canary_basic.ml:100-105` and
  `canary.ml:5-7`). But it encoded intent the action-graph pipeline
  still doesn't model:
    - No distro abstraction exercised (WSL and macOS paths untested).
    - No two-OS CI (macOS matrix is the paired TODO above).
    - Sys-PM × lang-PM enumeration (apt × opam, brew × opam, apt × pip, …)
      isn't represented in the `script_spec` → `step` path.
  **Revisit together with the version/symbol/interface work**: when we
  formalise interfaces as first-class (per
  `doc/canary/research/surface.md` + `surface_draft/`), the
  PM-cross-distro enumeration becomes part of "which provider (PM on
  distro) satisfies a given interface at a given version." The retired
  code in `doc/_legacy_code/canary_yaml_backend.ml` is the historical
  reference for the shapes that need to come back typed.
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
  compiler libraries instead of shelling out. Formerly consumed by
  `src/bin/example_sp.ml` (retired with the yaml-backend removal); today
  `src/binding/` is orphaned code, still building but unreferenced from any
  live entry point. Each module's canary-relevance:

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
  `doc/canary/research/surface_draft/surface.md` §2.1.
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
  `doc/canary/research/surface_draft/surface.md`.
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
derived expectation) shipped this session — see `surface_draft/implementation.md` §2.7 and
commits `2a8d2eb`, `96b143c`, `84caf5d`, `8943ba2`, `7dfb1f2`.

Worklogs: `doc/canary/worklog/worklog_2026_{03,04,05,06,07,08}.md`
(`worklog_2026_08.md` = the tiny-full arc: agnostic runner → vendored
resources → combinations → generic runner).

## Other Work: Yelu

Yelu is now a standalone project at `/home/red/code/research/yelu` with its own CLAUDE.md, build system, and opam package. It was extracted from `yelu/` on 2026-05-04. If you need to work on yelu, switch to that repo.

## Gotchas

- **Run-cache stale hit looks like a real PASS**: a step is skipped when its
  `.ok` marker exists and `check_post` passes (local cache), keyed by
  `variant_id` (the part after `/` in `project`, e.g. `tiny/<name>`). Re-running
  a *different* workspace under the **same** `variant_id` (e.g. a source-only
  Built tree reusing a name previously run Vendored) serves the stale marker —
  no build runs, but status reads PASS. Force a fresh run with `rm -rf
  _out/canary/projects/<name>` or a distinct `variant_id`. To coexist (Built vs
  Vendored, dev vs stable) put those axes in `variant_id`. See
  [`doc/canary/design/cache.md`](doc/canary/design/cache.md).
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

## Gotchas (continued)

- **`:` in a workspace dir name breaks `PYTHONPATH`/`LD_LIBRARY_PATH`**: the
  runner interpolates the assembled-workspace path into those env vars, which are
  **`:`-separated**. A resource id like `binding:ocaml:cstubs` in the dir name
  (`_cache/assembled/binding:ocaml:cstubs#Bs.9`) made Python split PYTHONPATH into
  `.../binding`, `ocaml`, `cstubs#…/python_cext` → `ModuleNotFoundError`. Symptom
  was subtle: only **lib** scenarios detected (`lib#Bs.N` has no `:`), binding
  scenarios silently failed at an *infrastructure* step, not a compat one. Fix:
  `Canary_tiny_workspace.safe_workspace_name` sanitizes `:` `#` `+` → `-` on every
  assembled-tree dir name (matches `canary_main`'s output-path sanitizer). Keep
  env-var-interpolated paths free of separator chars.
- **Vendored resource must carry SOURCE, not just the built artifact** (Fix A):
  `subdirs_of_resource` returns the built subdir **plus** the source the compat
  inspectors read (mli/headers/py). Overlaying only the built subdir left the
  base's good `.mli`/header in place, so source-manifested drift (a dropped val =
  C2) was invisible and the real failure read as *unexpected*. See
  `canary_tiny_workspace.ml`.

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
