# The enumeration — stage map

**Kind: reference.** THE entry point for this subdirectory, and the doc
to read first if you are about to change how scenarios are produced.
Every row names the code that implements a stage and the pins that guard
it, so "is this doc still aligned with the code?" is a question you can
answer mechanically instead of by reading.

> Created 2026-08-23 from the design/ audit. The problem it fixes: nine
> docs all described the enumeration, but each was written from the
> *occasion* that produced it (a rerun, a user question, a landing)
> rather than from a *stage* of the pipeline. A reader could ask "what
> happened on 2026-08-19?" and get a good answer, but not "what happens
> between the product and the assignment list?" — which is where the
> subtle parts live.

## Per-stage consolidation — in progress

2026-08-23, user: *"each stage (layer) should be standalone enough."* A
doc that spans stages is not a component doc, so the material is being
moved into one standalone document per stage, gradually.

| # | pass | doc | state |
| --- | --- | --- | --- |
| — | *vocabulary* (not a pass) | [`stage0_naming.md`](stage0_naming.md) | the four senses, the naming scheme, the fault tags |
| 1 | **declare** | [`stage1_project_spec.md`](stage1_project_spec.md) | what a project states — absorbed `repo_model.md` + `versioning.md` |
| 2 | **enumerate** | [`stage2_filters.md`](stage2_filters.md) | the product and the five constraints that prune it |
| 3 | **select** | [`stage3_select.md`](stage3_select.md) | what a RUN asked for — landed 2026-08-24 |
| 4 | **order** | [`stage4_order.md`](stage4_order.md) | identity, exclusive resources, run order |
| 5 | **realize** | [`stage5_realize.md`](stage5_realize.md) | commands, steps, execution, the cache |
| 6 | **report** | [`stage6_report.md`](stage6_report.md) | what a matrix row is and what names it |

Each pass answers to both its name and its index:
`canary emit <project> --stage select` is `--stage 3`
([`emit_stages.md`](emit_stages.md)).

**Every pass has a standalone doc.** The other two files are proposals:
[`multi_lib.md`](multi_lib.md) (`Lib` carries no name, so a project
cannot declare a second C lib) and [`emit_stages.md`](emit_stages.md)
(`canary emit --stage <pass>` — one dump per pass; steps 1–4 and 6
landed, `--json` and `--why` remain).

Four docs left rather than being kept: `algorithm_explainer.md` (the
walkthrough that predated this README — its sections went to the stages
they belonged to), `run_model_revisit.md` (findings to stage 5 §7 and
`../artifact_cache.md` §6; to-dos to the tracker), `staged_parity.md` →
`../staged_parity.md` (a checking principle, not a stage), and
`store_switching.md` → `../../project/opam_exclusive_store_issue.md` (one
package manager's problem, not a general algorithm principle).

## The pipeline

```
project module          declares artifact_rows
  │                        (identity + universe + provider + follows/runtime)
  ▼  stage 1
project_spec            ps_universe : artifact × (provision × versions)
  │
  ▼  stage 2            enumerate ~tag ~policy
run_config                 product over provision × version × mutation,
  │                        each level-resolved PER ARTIFACT
  ▼                     then FIVE constraints prune it  ──►  filters.md
assignment list         (artifact_id × placement) list
  │
  ▼  stage 3            scenarios_of → scenarios_in_run_order
ordered scenarios          identity = scenario_dir_of; order = store_state_key
  │
  ▼  stage 4            pr_runner_spec = realize ∘ dispatch
runner_spec → steps        derive_steps walks the action catalogue
  │                        (a second, parallel view: node_of_assignment →
  │                         close_deps → execution_plan)
  ▼  stage 5            run_graph → actions.log → matrix / status / html
verdicts
```

## Stage → code → doc → pins

| stage                   | what happens                                                                                                                                       | code                                                                                                                                                                                                     | doc                                                                                                                                                                                                                                    | pins                                                                                                                                                                                                                                                                                                                                                                                                               |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **0. vocabulary**       | the types every stage reuses: `artifact_kind`, `provision`, `channel`, `version`, `build_id`, `artifact_id`, `placement`, `assignment`, `dep_mode` | `base/canary_basic.ml`, `base/canary_store.ml`, `base/canary_artifact.ml`                                                                                                                                | [`../ssot.md`](../ssot.md) (IDs), [`stage0_naming.md`](stage0_naming.md) (the four senses of "scenario")                                                                                                                                         | `vocab.binding_source_off_tree`, `surface.split_keeps_checks_drops_provenance`, `scenario.lower_expectation_agnostic_c1`                                                                                                                                                                                                                                                                                           |
| **1. declaration**      | a project states which artifacts exist, at which provisions, at which versions, and who provides each                                              | `action/canary_project_spec.ml` (`artifact_row`, `project_spec_of_rows`), `base/canary_artifact.ml` (`axes = {ax_universe; ax_runtime; ax_follows; ax_pins}`), `tool/canary_store_config.ml` (providers) | **[`stage1_project_spec.md`](stage1_project_spec.md)** — THE stage-1 doc, standalone (absorbed `repo_model.md` + `versioning.md`, purged 2026-08-23). Background: [`../../project/opam_exclusive_store_issue.md`](../../project/opam_exclusive_store_issue.md) what a pin costs, [`multi_lib.md`](multi_lib.md) what cannot be declared | `enumerate.project_spec_sqlite_shape`, `enumerate.per_artifact_provisions`, `enumerate.per_artifact_versions`, `enumerate.per_provision_versions`, `repo_model.axes_pins`, `repo_model.contents_invariant`, `spec.vendored_prebuilt_pair`, `spec.pm_dep_gate_groups`, `sqlite.provider_rows`, `z3.provider_rows`                                                                                                   |
| **2. enumeration**      | the product, then the constraints that prune it                                                                                                    | `action/canary_enumerate.ml` (`run_config`, `enumerate_points`, `assignment_of_point`, then `assignment_ok`, `ax_follows`, `binding_couples`, `source_ref_ok`, `shadow_filter`, `ref_filter`)            | **[`stage2_filters.md`](stage2_filters.md)** — the product and the five constraints                                                                                                                            | `enumerate.config_levels`, `enumerate.subset_intersects_universe`, `enumerate.thin_is_version_subset`, `enumerate.refs_subset`, `enumerate.shadow_policy_drops_same_cell_built`, `enumerate.point_to_assignment_fold`, `enumerate.two_projections_and_filter`, `enumerate.version_axis`, `enumerate.built_from_of_assignment`, `enumerate.mismatch_direction`, `enumerate.deploy_mismatch`, `shadow.policy_ladder` |
| **3. identity + order** | which assignments are the SAME scenario, and in what order they run                                                                                | `project/canary_project_run.ml` (`scenarios_of`, `scenario_dir_of`, `store_state_key`, `scenarios_in_run_order`)                                                                                         | **[`stage4_order.md`](stage4_order.md)** — THE stage-3 doc, standalone. Background: [`../../project/opam_exclusive_store_issue.md`](../../project/opam_exclusive_store_issue.md) (the opam instance)                                                                                                  | `run_order.groups_by_store_state`, `matrix.registry_shape`, `z3.install_prefix_isolated`, `z3.env_guard_paths`, `world.one_vocabulary`                                                                                                                                                                                                                                                                                                                                                         |
| **4. realization**      | assignment → commands → steps; and the parallel node-graph view                                                                                    | `project/*` (`pr_runner_spec = realize ∘ dispatch`), `action/canary_step_builder.ml` (`derive_steps`), `action/canary_action.ml` (`node_of_assignment`, `close_deps`, `execution_plan`)                  | **[`stage5_realize.md`](stage5_realize.md)** — THE stage-4 doc, standalone. [`../action_playbook.md`](../action_playbook.md) to add an action                                                                                                          | `action.node_of_assignment_chain`, `action.close_deps_deploy_mismatch`, `action.execution_plan_topo_and_edges`, `arrow.providing_action_total_and_consistent`, `enumerate.dispatch_coordinate_reads`, `z3.dispatch_reads_source_placement`, `derive.fetch_lib_matches_helper`, `probe_invariant.consumes_eq_artifacts`                                                                                             |
| **5. reporting**        | what a row is and what names it                                                                                                                    | `main/canary_matrix.ml`, `backend/canary_status.ml`, `backend/canary_html.ml`                                                                                                                            | [`stage6_report.md`](stage6_report.md)                                                                                                                                                                                                               | `matrix.row_index`, `matrix.row_order`, `matrix.cell_stage_progression`, `matrix.setting_block_identifies_world`, `matrix.marks_from_log`                                                                                                                                                                                                                                                                          |

**Cross-cutting**, because they are not one stage:

| doc                                            | what it perturbs                                                                                                     |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| [`../staged_parity.md`](../staged_parity.md)         | stage 1 (Installed is a PROVISION, so a staged consumer is a WORLD) and stage 5 (build-vs-install parity is a check) |
| [`multi_lib.md`](multi_lib.md)                 | stage 0/1 — `Lib` carries no name, so a project cannot declare a second C lib                                        |

## What is NOT here

- The **cache** — `../artifact_cache.md` (proposal) and
  [`stage5_realize.md`](stage5_realize.md) §4 (what exists).
- **Adding an action** — `../action_playbook.md`.
- The **checking** side (what a probe asserts, which contract fires) —
  `../agreement_registry_audit.md` and `surface/`.
- Anything **per project** — `../../project/`.

## The alignment rule

The pin names above are the mechanical half of "is this doc still true?".
Each one is a registered test — `canary project-test` prints them — so
when you land a change to a stage, the fastest check is whether that
stage's pins still exist and still pass.

**Not automated today.** A check that failed the build when a doc cited a
deleted pin was built and removed on 2026-08-23: it worked, but it was
one narrow instance of a general problem (docs citing pins, docs citing
source paths, comments citing docs, docs citing CLI verbs), wired to one
directory with a hand-maintained exclusion list. The general form is
backlog #48. Until it exists, this is a convention, not a guarantee — and
so is the converse, which no check would cover anyway: a pin can exist
while the prose around it describes something the code stopped doing.

## Known drift, recorded rather than hidden

- **Two dependency relations.** `step.deps` (what the runner enforces via
  `check_pre`) and the node graph's edges (`close_deps`) are separate
  relations that have drifted. Execution is sound — every step enforces
  its real deps — but the drawn diagram under-connects, so the
  connectivity invariant is muted behind `CANARY_DIAGRAM_CONN=1`.
  Reconciling them into ONE relation is tracked in `../../status.md` §A.
- **The mechanism / app-wiring axes are not config axes.** They are
  ranged via the artifact-identity set (each `a_binding lang mech` is its
  own enumerated artifact). A dedicated `config` axis for them is open —
  see the `'m config` comment in `canary_enumerate.ml`.
