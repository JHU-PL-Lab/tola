# Canary code audit - Codex - 2026-06-01

## Scope and method

Scope: all 33 OCaml implementation files under `src/canary/`, including the
`projects/` and `legacy/` sub-libraries. The audit is static only: I read the
requested context (`CLAUDE.md`, `src/canary/dune`,
`doc/canary/research/surface_theory.md`, `src/canary/projects/canary_project_tiny.ml`)
and the existing `doc/canary/audit_2026_06_01.md`, then checked current code
with `rg`, `wc -l`, and line-numbered reads.

Verification: `eval $(opam env) && dune build src/canary/ src/bin/canary_main.exe` completed successfully.

Layer reference: `src/canary/dune` declares the normative order as
`base/`, `surface/`, `tool/`, `action/`, `backend/`, `test/`, with
`projects/` and `legacy/` as opt-out sub-libraries
(`src/canary/dune:20`, `src/canary/dune:25`, `src/canary/dune:30`,
`src/canary/dune:34`, `src/canary/dune:40`, `src/canary/dune:42`,
`src/canary/dune:43`, `src/canary/dune:46`, `src/canary/dune:47`).

In-degree is an approximate distinct-file count from:
`rg -l "\b<Module>\b" src/canary src/bin/canary_main.ml`, excluding the module
file itself.

## Per-module catalog

Verdicts: coherent = one clear job; mixed = separable concerns; kitchen =
unrelated live/dead themes; legacy = intentionally parked or terminal harness.

### base/

| Module | LOC | In | Verdict | Top-level shape and evidence |
| --- | ---: | ---: | --- | --- |
| `base/canary_basic.ml` | 460 | 13 | kitchen | Live vocabulary begins with runner/probe/mode/artifact/project/step types (`src/canary/base/canary_basic.ml:6`, `src/canary/base/canary_basic.ml:34`, `src/canary/base/canary_basic.ml:70`, `src/canary/base/canary_basic.ml:85`) but the same file also carries retired YAML/backend config types and helpers (`src/canary/base/canary_basic.ml:95`, `src/canary/base/canary_basic.ml:112`, `src/canary/base/canary_basic.ml:122`, `src/canary/base/canary_basic.ml:169`, `src/canary/base/canary_basic.ml:231`, `src/canary/base/canary_basic.ml:331`). |
| `base/canary_store.ml` | 119 | 13 | coherent | Store/package vocabulary and helpers only: package spec/location/stage (`src/canary/base/canary_store.ml:9`, `src/canary/base/canary_store.ml:21`, `src/canary/base/canary_store.ml:28`, `src/canary/base/canary_store.ml:36`), string/install helpers (`src/canary/base/canary_store.ml:38`, `src/canary/base/canary_store.ml:86`, `src/canary/base/canary_store.ml:94`). |
| `base/canary_pm_types.ml` | 15 | 5 | coherent | Tiny PM vocabulary only: package manager, behavior, scope, properties (`src/canary/base/canary_pm_types.ml:5`, `src/canary/base/canary_pm_types.ml:6`, `src/canary/base/canary_pm_types.ml:7`, `src/canary/base/canary_pm_types.ml:9`). |
| `base/canary_output_path.ml` | 45 | 12 | coherent | Output layout helpers only: step directory mapping and variant-aware filenames (`src/canary/base/canary_output_path.ml:19`, `src/canary/base/canary_output_path.ml:34`, `src/canary/base/canary_output_path.ml:40`). |

### surface/

| Module | LOC | In | Verdict | Top-level shape and evidence |
| --- | ---: | ---: | --- | --- |
| `surface/canary_artifact_api.ml` | 162 | 14 | coherent, misplaced atom | API surface record vocabulary: `lang`, native API, binding API, watchlist and scan helpers (`src/canary/surface/canary_artifact_api.ml:16`, `src/canary/surface/canary_artifact_api.ml:72`, `src/canary/surface/canary_artifact_api.ml:88`, `src/canary/surface/canary_artifact_api.ml:124`, `src/canary/surface/canary_artifact_api.ml:145`). The `lang` type is foundational enough that base already depends on it, which is the placement issue. |
| `surface/canary_compat.ml` | 465 | 2 | coherent | Pure comparator module: JSON loaders (`src/canary/surface/canary_compat.ml:41`), inspect records (`src/canary/surface/canary_compat.ml:63`, `src/canary/surface/canary_compat.ml:68`), and c1/c4/c5/c6/c7/c8-style checks (`src/canary/surface/canary_compat.ml:133`, `src/canary/surface/canary_compat.ml:186`, `src/canary/surface/canary_compat.ml:265`, `src/canary/surface/canary_compat.ml:352`, `src/canary/surface/canary_compat.ml:409`, `src/canary/surface/canary_compat.ml:456`). |
| `surface/canary_compat_run.ml` | 487 | 6 | mixed | Its header says it combines cached-artifact path resolution, prediction, CLI, verification, and reporting (`src/canary/surface/canary_compat_run.ml:1`, `src/canary/surface/canary_compat_run.ml:15`, `src/canary/surface/canary_compat_run.ml:18`). That is cohesive around "run compat", but more action/CLI-shaped than pure surface. |

### tool/

| Module | LOC | In | Verdict | Top-level shape and evidence |
| --- | ---: | ---: | --- | --- |
| `tool/canary_toolchain.ml` | 466 | 9 | mixed | Opam/OCaml/Python config types (`src/canary/tool/canary_toolchain.ml:9`, `src/canary/tool/canary_toolchain.ml:37`, `src/canary/tool/canary_toolchain.ml:47`), OCaml/opam/pip command generators (`src/canary/tool/canary_toolchain.ml:89`, `src/canary/tool/canary_toolchain.ml:138`, `src/canary/tool/canary_toolchain.ml:294`, `src/canary/tool/canary_toolchain.ml:378`), and generic cmake/ninja/dune build primitives (`src/canary/tool/canary_toolchain.ml:419`, `src/canary/tool/canary_toolchain.ml:435`, `src/canary/tool/canary_toolchain.ml:450`, `src/canary/tool/canary_toolchain.ml:460`). |
| `tool/canary_artifact_native.ml` | 149 | 7 | coherent | Native-library probing/inspection only: platform/nm helpers and native inspect commands (`src/canary/tool/canary_artifact_native.ml:25`, `src/canary/tool/canary_artifact_native.ml:54`, `src/canary/tool/canary_artifact_native.ml:72`, `src/canary/tool/canary_artifact_native.ml:103`, `src/canary/tool/canary_artifact_native.ml:118`). |
| `tool/canary_artifact_lang.ml` | 215 | 5 | coherent | Language artifact inspection only: OCaml archive/stub/mli helpers and Python import/inspect helpers (`src/canary/tool/canary_artifact_lang.ml:42`, `src/canary/tool/canary_artifact_lang.ml:65`, `src/canary/tool/canary_artifact_lang.ml:118`, `src/canary/tool/canary_artifact_lang.ml:136`, `src/canary/tool/canary_artifact_lang.ml:177`, `src/canary/tool/canary_artifact_lang.ml:194`). |
| `tool/canary_artifact_source.ml` | 116 | 5 | coherent | Source repo model/fetch/scan helpers only (`src/canary/tool/canary_artifact_source.ml:11`, `src/canary/tool/canary_artifact_source.ml:19`, `src/canary/tool/canary_artifact_source.ml:60`, `src/canary/tool/canary_artifact_source.ml:100`). |
| `tool/canary_inspect_diff.ml` | 130 | 1 | coherent | Leaf inspect-diff command: JSON field readers plus set/count diff printers (`src/canary/tool/canary_inspect_diff.ml:7`, `src/canary/tool/canary_inspect_diff.ml:24`, `src/canary/tool/canary_inspect_diff.ml:41`, `src/canary/tool/canary_inspect_diff.ml:75`). |
| `tool/canary_pm_apt.ml` | 36 | 2 | coherent | Apt PM driver only (`src/canary/tool/canary_pm_apt.ml:4`, `src/canary/tool/canary_pm_apt.ml:12`, `src/canary/tool/canary_pm_apt.ml:16`, `src/canary/tool/canary_pm_apt.ml:27`). |
| `tool/canary_pm_brew.ml` | 33 | 2 | coherent | Brew PM driver only (`src/canary/tool/canary_pm_brew.ml:4`, `src/canary/tool/canary_pm_brew.ml:12`, `src/canary/tool/canary_pm_brew.ml:18`, `src/canary/tool/canary_pm_brew.ml:27`). |
| `tool/canary_pm_opam.ml` | 60 | 3 | coherent | Opam PM driver only (`src/canary/tool/canary_pm_opam.ml:10`, `src/canary/tool/canary_pm_opam.ml:18`, `src/canary/tool/canary_pm_opam.ml:27`, `src/canary/tool/canary_pm_opam.ml:50`). |
| `tool/canary_pm_pip.ml` | 40 | 2 | coherent | Pip PM driver only (`src/canary/tool/canary_pm_pip.ml:5`, `src/canary/tool/canary_pm_pip.ml:13`, `src/canary/tool/canary_pm_pip.ml:20`, `src/canary/tool/canary_pm_pip.ml:36`). |

### action/

| Module | LOC | In | Verdict | Top-level shape and evidence |
| --- | ---: | ---: | --- | --- |
| `action/canary.ml` | 648 | 11 | kitchen | Starts with dead legacy project plumbing (`src/canary/action/canary.ml:6`, `src/canary/action/canary.ml:17`, `src/canary/action/canary.ml:34`), then live node/action-rule graph (`src/canary/action/canary.ml:72`, `src/canary/action/canary.ml:96`, `src/canary/action/canary.ml:107`), step expectation model (`src/canary/action/canary.ml:185`, `src/canary/action/canary.ml:249`, `src/canary/action/canary.ml:275`, `src/canary/action/canary.ml:286`), path table (`src/canary/action/canary.ml:356`, `src/canary/action/canary.ml:512`, `src/canary/action/canary.ml:554`), and diagram status helpers (`src/canary/action/canary.ml:631`). |
| `action/canary_action.ml` | 1248 | 10 | mixed | The file is internally sectioned but broad: project `script_spec` (`src/canary/action/canary_action.ml:61`), runner (`src/canary/action/canary_action.ml:197`, `src/canary/action/canary_action.ml:257`, `src/canary/action/canary_action.ml:426`), shared command helpers (`src/canary/action/canary_action.ml:488`, `src/canary/action/canary_action.ml:502`), step derivation (`src/canary/action/canary_action.ml:721`), and run-state/index rendering (`src/canary/action/canary_action.ml:937`, `src/canary/action/canary_action.ml:1022`, `src/canary/action/canary_action.ml:1130`, `src/canary/action/canary_action.ml:1213`). |
| `action/canary_step_cache.ml` | 71 | 2 | coherent | Small cache load/save helper only; its role is visible from the dependency in `run_project` (`src/canary/action/canary_action.ml:1160`) and the module's own small size/one-file placement. |

### backend/

| Module | LOC | In | Verdict | Top-level shape and evidence |
| --- | ---: | ---: | --- | --- |
| `backend/canary_backend_gh.ml` | 226 | 1 | coherent | GH YAML renderer only: render steps/jobs/workflow plus a backend-local job spec (`src/canary/backend/canary_backend_gh.ml:31`, `src/canary/backend/canary_backend_gh.ml:157`, `src/canary/backend/canary_backend_gh.ml:202`, `src/canary/backend/canary_backend_gh.ml:211`). |
| `backend/canary_backend_html.ml` | 538 | 2 | coherent | HTML view/index renderer only: view/step/index records and render functions (`src/canary/backend/canary_backend_html.ml:16`, `src/canary/backend/canary_backend_html.ml:22`, `src/canary/backend/canary_backend_html.ml:33`, `src/canary/backend/canary_backend_html.ml:96`, `src/canary/backend/canary_backend_html.ml:467`). |
| `backend/canary_diagram.ml` | 2283 | 3 | mixed | All diagram/index-adjacent, but very large: schema diagram (`src/canary/backend/canary_diagram.ml:54`), step graph (`src/canary/backend/canary_diagram.ml:780`), view machinery (`src/canary/backend/canary_diagram.ml:843`, `src/canary/backend/canary_diagram.ml:1576`), project index scanning (`src/canary/backend/canary_diagram.ml:1803`), and output writing (`src/canary/backend/canary_diagram.ml:1860`). |

### test/

| Module | LOC | In | Verdict | Top-level shape and evidence |
| --- | ---: | ---: | --- | --- |
| `test/canary_artifact_test.ml` | 915 | 1 | mixed | One harness covers many domains: native, OCaml, compat, c1/c4/c5/c6/c7/c8 pure tests, and shell tests (`src/canary/test/canary_artifact_test.ml:25`, `src/canary/test/canary_artifact_test.ml:45`, `src/canary/test/canary_artifact_test.ml:65`, `src/canary/test/canary_artifact_test.ml:121`, `src/canary/test/canary_artifact_test.ml:172`, `src/canary/test/canary_artifact_test.ml:227`, `src/canary/test/canary_artifact_test.ml:307`, `src/canary/test/canary_artifact_test.ml:372`, `src/canary/test/canary_artifact_test.ml:609`, `src/canary/test/canary_artifact_test.ml:720`). |
| `test/canary_pm_test.ml` | 121 | 2 | coherent | PM driver test harness only: test_case/result, PM-specific test lists, runner (`src/canary/test/canary_pm_test.ml:10`, `src/canary/test/canary_pm_test.ml:16`, `src/canary/test/canary_pm_test.ml:38`, `src/canary/test/canary_pm_test.ml:89`). |

### projects/

| Module | LOC | In | Verdict | Top-level shape and evidence |
| --- | ---: | ---: | --- | --- |
| `projects/canary_pattern_a.ml` | 129 | 2 | coherent | Template for Pattern A projects only: declaration type, locator, script spec generator (`src/canary/projects/canary_pattern_a.ml:26`, `src/canary/projects/canary_pattern_a.ml:34`, `src/canary/projects/canary_pattern_a.ml:51`, `src/canary/projects/canary_pattern_a.ml:88`). |
| `projects/canary_project_tiny.ml` | 317 | 1 | coherent | In-tree witness spec: root/lib/watchlists, API source, script spec (`src/canary/projects/canary_project_tiny.ml:50`, `src/canary/projects/canary_project_tiny.ml:60`, `src/canary/projects/canary_project_tiny.ml:92`, `src/canary/projects/canary_project_tiny.ml:129`). |
| `projects/canary_project_sqlite.ml` | 110 | 3 | coherent | SQLite project spec: OCaml/Python configs, watchlists, script spec (`src/canary/projects/canary_project_sqlite.ml:4`, `src/canary/projects/canary_project_sqlite.ml:38`, `src/canary/projects/canary_project_sqlite.ml:52`, `src/canary/projects/canary_project_sqlite.ml:60`). |
| `projects/canary_project_z3.ml` | 592 | 4 | coherent | Larger but single project spec: API source, source variants, tool configs, script-spec generator (`src/canary/projects/canary_project_z3.ml:12`, `src/canary/projects/canary_project_z3.ml:107`, `src/canary/projects/canary_project_z3.ml:153`, `src/canary/projects/canary_project_z3.ml:255`). |
| `projects/canary_project_llvm.ml` | 555 | 3 | coherent | Larger but single project spec: API source, source variants, configs, script-spec generator (`src/canary/projects/canary_project_llvm.ml:28`, `src/canary/projects/canary_project_llvm.ml:86`, `src/canary/projects/canary_project_llvm.ml:153`, `src/canary/projects/canary_project_llvm.ml:263`). |
| `projects/canary_project_ssl.ml` | 44 | 2 | coherent | Thin Pattern A declaration only (`src/canary/projects/canary_project_ssl.ml:10`, `src/canary/projects/canary_project_ssl.ml:44`). |
| `projects/canary_project_zarith.ml` | 38 | 2 | coherent | Thin Pattern A declaration only (`src/canary/projects/canary_project_zarith.ml:6`, `src/canary/projects/canary_project_zarith.ml:38`). |
| `projects/canary_run.ml` | 138 | 2 | coherent | Project orchestration/CI entry points only (`src/canary/projects/canary_run.ml:26`, `src/canary/projects/canary_run.ml:92`, `src/canary/projects/canary_run.ml:103`, `src/canary/projects/canary_run.ml:115`, `src/canary/projects/canary_run.ml:122`). |

### legacy/

| Module | LOC | In | Verdict | Top-level shape and evidence |
| --- | ---: | ---: | --- | --- |
| `legacy/canary_dead_code.ml` | 433 | 1 | legacy | Parked by the sub-library comment, and consumed by `example_sp` only (`src/canary/legacy/dune:1`, `src/canary/legacy/dune:8`, `src/canary/legacy/example_sp.ml:134`). It still references live `Canary_basic.mk_canary_config` (`src/canary/legacy/canary_dead_code.ml:91`). |
| `legacy/example_sp.ml` | 227 | 0 | legacy | Own executable, legacy demo plumbing (`src/canary/legacy/dune:24`, `src/canary/legacy/example_sp.ml:136`, `src/canary/legacy/example_sp.ml:176`, `src/canary/legacy/example_sp.ml:206`). |

## Cross-cutting findings

### 1. The main layer violation is real: `base/` depends on `surface/`

The normative layer order says base is below surface (`src/canary/dune:25`,
`src/canary/dune:30`), but base types refer to `Canary_artifact_api.lang` in
`artifact_kind`, `project_spec`, `phase_kind`, and `rule`
(`src/canary/base/canary_basic.ml:34`, `src/canary/base/canary_basic.ml:74`,
`src/canary/base/canary_basic.ml:102`, `src/canary/base/canary_basic.ml:410`).
`Canary_artifact_api.lang` itself is declared in surface
(`src/canary/surface/canary_artifact_api.ml:16`). This is not just an
`open` convenience issue: base data constructors physically mention a later
layer.

`Canary_store` also has the same base-to-surface dependency through
`Lang_pm { lang : Canary_artifact_api.lang; pm : package_manager }`
(`src/canary/base/canary_store.ml:21`, `src/canary/base/canary_store.ml:23`).

### 2. Dead legacy plumbing is still live-linked through `legacy/`

The earlier audit is right that the YAML/config era is dead from the live
pipeline, but it is not entirely unreferenced. A repo-wide qualified search
found `Canary_basic.mk_canary_config` references in `legacy/canary_dead_code.ml`
(`src/canary/legacy/canary_dead_code.ml:91`, `src/canary/legacy/canary_dead_code.ml:341`,
`src/canary/legacy/canary_dead_code.ml:413`). The legacy library deliberately
links against `canary_lib` (`src/canary/legacy/dune:8`, `src/canary/legacy/dune:17`),
so deleting the old `canary_basic.ml` config helpers requires either moving
them into `legacy/` or deleting/updating `canary_legacy`.

Within `canary_basic.ml`, the retired cluster is clear: `system_pkg`,
`phase_kind`, `step_phase`, `job_spec`, YAML preamble/job/config types, and
backend script helpers occupy `src/canary/base/canary_basic.ml:95` through
`src/canary/base/canary_basic.ml:174`, with construction/rendering helpers at
`src/canary/base/canary_basic.ml:202`, `src/canary/base/canary_basic.ml:221`,
`src/canary/base/canary_basic.ml:225`, `src/canary/base/canary_basic.ml:231`,
`src/canary/base/canary_basic.ml:277`, `src/canary/base/canary_basic.ml:294`,
`src/canary/base/canary_basic.ml:302`, `src/canary/base/canary_basic.ml:320`,
and `src/canary/base/canary_basic.ml:331`.

`action/canary.ml` has the matching legacy front matter:
`project_config`, `verify_of_phase`, and `steps_of_phase`
(`src/canary/action/canary.ml:6`, `src/canary/action/canary.ml:17`,
`src/canary/action/canary.ml:34`). Those functions consume the old
`step_phase`/`job_spec` vocabulary from `Canary_basic`, not the current
`script_spec -> action_step` pipeline.

### 3. Two `job_spec` types with different meanings create avoidable grep noise

The old `Canary_basic.job_spec` is a distro/phases/disabled record
(`src/canary/base/canary_basic.ml:112`). The current GH backend job spec is
`id/name/project/sys_deps/preamble_steps/steps`
(`src/canary/backend/canary_backend_gh.ml:202`). Both names are module-scoped
and type-safe, so this is not a runtime bug. It is a reorganization smell
because searches for `job_spec` mix a retired YAML-era model with the live GH
renderer model.

### 4. `Canary.compat_inspect_input` duplicates `Canary_compat_run.typed_input`

The expectation intent type in `action/canary.ml` has six constructors carrying
path lists (`src/canary/action/canary.ml:249`). The resolved form in
`surface/canary_compat_run.ml` has the same six constructor names carrying one
path each (`src/canary/surface/canary_compat_run.ml:292`). The duplication is
acknowledged in the doc-comment (`src/canary/surface/canary_compat_run.ml:269`,
`src/canary/surface/canary_compat_run.ml:272`), and it forces manual
translations in both the local runner and GH backend
(`src/canary/action/canary_action.ml:332`, `src/canary/action/canary_action.ml:354`,
`src/canary/backend/canary_backend_gh.ml:131`, `src/canary/backend/canary_backend_gh.ml:152`).

This is a small but concrete source of drift risk: adding a new compat input
requires editing two ADTs and two translators.

### 5. `canary_toolchain.ml` is a real split candidate

`Canary_toolchain` holds three separable families:

- OCaml/opam configuration and command-generation types/functions
  (`src/canary/tool/canary_toolchain.ml:9`, `src/canary/tool/canary_toolchain.ml:37`,
  `src/canary/tool/canary_toolchain.ml:89`, `src/canary/tool/canary_toolchain.ml:212`,
  `src/canary/tool/canary_toolchain.ml:378`).
- Python toolchain/probe/install helpers (`src/canary/tool/canary_toolchain.ml:47`,
  `src/canary/tool/canary_toolchain.ml:294`, `src/canary/tool/canary_toolchain.ml:324`,
  `src/canary/tool/canary_toolchain.ml:336`).
- Generic build primitives for marker-writing, cmake, ninja, and dune
  (`src/canary/tool/canary_toolchain.ml:419`, `src/canary/tool/canary_toolchain.ml:426`,
  `src/canary/tool/canary_toolchain.ml:435`, `src/canary/tool/canary_toolchain.ml:444`,
  `src/canary/tool/canary_toolchain.ml:450`, `src/canary/tool/canary_toolchain.ml:460`).

The generic build primitives are used by project specs directly, e.g. tiny
uses `cmake_configure_cmd`, `cmake_build_cmd`, `dune_build_cmd`, and
`with_marker` (`src/canary/projects/canary_project_tiny.ml:139`,
`src/canary/projects/canary_project_tiny.ml:147`,
`src/canary/projects/canary_project_tiny.ml:164`,
`src/canary/projects/canary_project_tiny.ml:170`), while z3/llvm use cmake/ninja
helpers (`src/canary/projects/canary_project_z3.ml:338`,
`src/canary/projects/canary_project_z3.ml:347`,
`src/canary/projects/canary_project_llvm.ml:322`,
`src/canary/projects/canary_project_llvm.ml:334`). They do not need to live
next to opam type vocabulary.

### 6. `canary_action.ml` is broad, but the broadness has a coherent center

The file is 1248 lines and spans project declaration, step derivation,
runner, and run-state rendering. The most central coupling is defensible:
`script_spec` declares per-rule command fields (`src/canary/action/canary_action.ml:61`)
and `derive_steps` consumes those fields into `action_step`s
(`src/canary/action/canary_action.ml:721`). The more separable tail is
run metadata/state/view orchestration (`src/canary/action/canary_action.ml:937`,
`src/canary/action/canary_action.ml:1022`, `src/canary/action/canary_action.ml:1130`,
`src/canary/action/canary_action.ml:1213`).

The practical conclusion differs slightly from the existing audit: do not split
`script_spec` from `derive_steps` first. If this file is split, pull out
run-state/view/reporting before pulling apart the spec/deriver core.

### 7. Documentation pointers are stale after the subdirectory move

`surface_theory.md` still points implementation references at old flat paths
such as `src/canary/canary_compat.ml`, `src/canary/canary_action.ml`, and
`src/canary/canary_artifact_api.ml`
(`doc/canary/research/surface_theory.md:610`,
`doc/canary/research/surface_theory.md:611`,
`doc/canary/research/surface_theory.md:612`,
`doc/canary/research/surface_theory.md:613`,
`doc/canary/research/surface_theory.md:614`,
`doc/canary/research/surface_theory.md:615`). The current files live under
`surface/`, `action/`, and `tool/` (`src/canary/dune:30`,
`src/canary/dune:34`, `src/canary/dune:40`). This does not affect runtime
behavior, but it weakens the "theory -> code" traceability that the audit prompt
explicitly relies on.

### 8. Warning discipline is uneven

The main canary library does not declare local warning flags in
`src/canary/dune:1`, while the legacy executable suppresses warnings 32 and 37
(`src/canary/legacy/dune:54`). That means unused opens in live code are not
explicitly documented as tolerated, but the audit found several broad opens:
`Canary_toolchain` opens three canary modules (`src/canary/tool/canary_toolchain.ml:3`,
`src/canary/tool/canary_toolchain.ml:4`, `src/canary/tool/canary_toolchain.ml:5`),
`Canary_action` opens `Canary` wholesale (`src/canary/action/canary_action.ml:4`),
and projects open several broad modules (`src/canary/projects/canary_project_llvm.ml:2`,
`src/canary/projects/canary_project_llvm.ml:7`,
`src/canary/projects/canary_project_z3.ml:3`,
`src/canary/projects/canary_project_z3.ml:8`,
`src/canary/projects/canary_project_tiny.ml:43`,
`src/canary/projects/canary_project_tiny.ml:44`).

I did not classify individual opens as unused because the local compiler is
unavailable; treat this as a hygiene follow-up, not a confirmed bug.

## Proposed direction

1. Move `lang` to base first.
   The foundational language enum is declared in surface (`src/canary/surface/canary_artifact_api.ml:16`) but used by base (`src/canary/base/canary_basic.ml:34`, `src/canary/base/canary_store.ml:23`). A small `base/canary_lang.ml` or a carefully named section in `canary_basic.ml` would eliminate the real layer violation without changing behavior.

2. Park or delete legacy config/YAML plumbing as one explicit operation.
   The cleanup target is `src/canary/base/canary_basic.ml:95` through
   `src/canary/base/canary_basic.ml:331` plus `src/canary/action/canary.ml:6`
   through `src/canary/action/canary.ml:70`. Because `legacy/canary_dead_code.ml`
   still calls `Canary_basic.mk_canary_config` (`src/canary/legacy/canary_dead_code.ml:91`),
   either move those declarations into `legacy/` or delete/update the legacy
   library at the same time.

3. Rename or split the live `Canary_basic.job_spec` conflict.
   If the old job model stays parked, move it out of `Canary_basic`; if it
   stays live, rename one side. The two competing definitions are
   `src/canary/base/canary_basic.ml:112` and
   `src/canary/backend/canary_backend_gh.ml:202`.

4. Unify compat expectation input in one type family.
   Replace the duplicated `compat_inspect_input` / `typed_input` pair
   (`src/canary/action/canary.ml:249`, `src/canary/surface/canary_compat_run.ml:292`)
   with a parameterized representation or one shared role enum plus separate
   path payload types. This removes the two translation blocks in
   `Canary_action` and `Canary_backend_gh`
   (`src/canary/action/canary_action.ml:332`,
   `src/canary/backend/canary_backend_gh.ml:131`).

5. Extract build-command primitives from `Canary_toolchain`.
   A new `tool/canary_build_cmd.ml` containing marker/cmake/ninja/dune helpers
   (`src/canary/tool/canary_toolchain.ml:419` through
   `src/canary/tool/canary_toolchain.ml:466`) would leave `Canary_toolchain`
   focused on opam/OCaml/Python packaging and probing.

6. Split `Canary_action` only after the previous cleanups.
   If needed, extract the run-state/reporting tail
   (`src/canary/action/canary_action.ml:937` through
   `src/canary/action/canary_action.ml:1248`) before touching the
   `script_spec`/`derive_steps` core (`src/canary/action/canary_action.ml:61`,
   `src/canary/action/canary_action.ml:721`).

7. Update theory implementation pointers after code moves.
   The stale path table in `doc/canary/research/surface_theory.md:605` through
   `doc/canary/research/surface_theory.md:615` should point at current
   subdirectories once the source layout settles.

## Open questions

1. Should `legacy/` remain compilable? If yes, the legacy config/YAML types
   should probably move there rather than disappear, because
   `canary_legacy` currently links against `canary_lib`
   (`src/canary/legacy/dune:8`, `src/canary/legacy/dune:17`).

2. Is `Canary_compat_run` conceptually surface or action? It lives in
   `surface/`, but its own header lists cached path resolution, CLI entry
   points, and verification as responsibilities
   (`src/canary/surface/canary_compat_run.ml:15`,
   `src/canary/surface/canary_compat_run.ml:18`). Keeping pure comparators in
   `surface/` and moving cache/CLI integration to `action/` would make the
   layer story cleaner.

3. Should `projects/` be allowed to open action modules directly? Current
   specs open `Canary` in several places (`src/canary/projects/canary_project_llvm.ml:7`,
   `src/canary/projects/canary_project_z3.ml:8`,
   `src/canary/projects/canary_project_tiny.ml:44`), mostly to name
   expectation constructors and action types. A narrower exported project-spec
   API would make project files more declarative.

4. Should the next cleanup enforce warning 33 in live canary code? The current
   dune stanza does not document warning policy (`src/canary/dune:1`), and the
   only explicit warning suppression is in legacy (`src/canary/legacy/dune:54`).
