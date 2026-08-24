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

**Reporting is NOT a pass.** It was numbered 6 until 2026-08-24; the
matrix is built by `canary result`, which READS `actions.log` after a
run, so the pipeline's dataflow ends at pass 5 writing verdicts. The
matrix doc moved out accordingly: [`../matrix.md`](../matrix.md).

Five passes. Each answers to both its name and its index:
`canary emit <project> --stage select` is `--stage 3`
([`why_ledger.md`](why_ledger.md)).

**Every pass has a standalone doc.** The other two files are proposals:
[`multi_lib.md`](multi_lib.md) (`Lib` carries no name, so a project
cannot declare a second C lib) and [`why_ledger.md`](why_ledger.md)
(`--why`, the per-candidate ledger — deliberately postponed).

`emit_stages.md`, the proposal that produced the passes, retired
2026-08-24: once its steps landed it was code rationale, not a design
plan, so it moved here (how to look at a pass, layers vs passes, the
invariants) and into the per-pass docs. Only `--why` was still proposed,
and that is `why_ledger.md`.

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

## Looking at a pass

Every stage boundary is a **total function over a distinct first-class
type** — that is why the passes can be printed at all, and it was already
true before anything was built to exploit it:

```
canary emit <project> --stage <pass> [--json] [--raw] [--thin] [--refs A,B]
```

Each pass answers to its NAME or its index. The rule is one line, and it
is what separates `emit` from `spec`: **`--stage N` prints the value pass
N hands to pass N+1** — not a rendering of it, and not a join with a
neighbour. (`spec` is deliberately a joined human snapshot; both are
useful, for different questions.)

| flag | what it gives |
| --- | --- |
| *(default)* | a compact reading form |
| `--json` | one encoder per pass, for diffing two runs. Keys are canonical |
| `--raw` | the derived `show` form — faithful, verbose |

Two properties hold by construction, and they are the reason to reach for
`emit` rather than reasoning about the code:

- **The dump is the value.** Every pass goes through `Canary_pipeline`,
  which calls the very functions the runner calls. A dump cannot agree
  with itself while disagreeing with what runs.
- **`emit` reads the CATALOGUE, not the active set.** Muting a project
  suppresses running it, not inspecting it — and a muted project (z3) is
  the richest spec in the tree.

What it shows that nothing else did: pass 2 is what the project HAS and
pass 3 is what a run ASKED FOR, so "why isn't this running" has two
different answers. z3 has 16 worlds; `--thin` asks for 1; `--refs latest`
asks for 5.

## Layers and passes are different axes

The codebase has an organizing axis already, and it is not this one:

- **Layers** (`base/ → surface/ → tool/ → action/ → backend/`, with
  `project/` and `main/` on top) are a **dependency** discipline — who
  may reference whom. dune enforces it and it works.
- **Passes** are a **dataflow** discipline — who hands what to whom.

They genuinely cross. Passes 2 and 5 live in `action/`, but passes 3 and
4 are in `project/`, above both, because they need a `project_run`.
Dataflow says 2 → 3 → 4 → 5; layering says `action/` is below
`project/`. Neither is wrong, and **reorganizing the directories by pass
would fight a working discipline for a labelling benefit**.

What is worth having instead is one module that names the passes in
order — `main/canary_pipeline.ml`. Before it, the chain was assembled in
`Canary_runner.run_project_spec` and *partially re-assembled* in
`Canary_matrix.actions_of`, which called `derive_steps` with its own
workspace and project name. Two assemblies of one pipeline is how they
drift; both route through the module now.

## Invariants the pipeline holds

Short list, each learned from something that went wrong:

- **A dump never re-derives.** If it computed its own answer it could
  agree with itself and disagree with the runner.
- **Selection never invents.** Pass 3 only removes, so pass 2 stays the
  honest inventory (`select.is_a_subset_of_stage2`), and the default
  selects everything (`select.full_policy_selects_everything`).
- **Model constraints are not policy.** Pass 2's five constraints have no
  knob; a world they prune could not exist or was a duplicate. The one
  time a knob was added — `shadow_filter`'s `Materialize_source` and its
  `Audit_lib` rung — it was removed as misfiled.
- **The dedup key is a function of CONTENT.** `string_of_assignment`
  sorts by artifact kind, so the same world keys one way no matter which
  construction built it.
- **Passes 1–4 are pure; pass 5 is not.** Deriving steps applies
  `pr_runner_spec` — see [`stage5_realize.md`](stage5_realize.md) §9.

## Stage → code → doc → pins

| stage                   | what happens                                                                                                                                       | code                                                                                                                                                                                                     | doc                                                                                                                                                                                                                                    | pins                                                                                                                                                                                                                                                                                                                                                                                                               |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **0. vocabulary**       | the types every stage reuses: `artifact_kind`, `provision`, `channel`, `version`, `build_id`, `artifact_id`, `placement`, `assignment`, `dep_mode` | `base/canary_basic.ml`, `base/canary_store.ml`, `base/canary_artifact.ml`                                                                                                                                | [`../ssot.md`](../ssot.md) (IDs), [`stage0_naming.md`](stage0_naming.md) (the four senses of "scenario")                                                                                                                                         | `vocab.binding_source_off_tree`, `surface.split_keeps_checks_drops_provenance`, `scenario.lower_expectation_agnostic_c1`                                                                                                                                                                                                                                                                                           |
| **1. declaration**      | a project states which artifacts exist, at which provisions, at which versions, and who provides each                                              | `action/canary_project_spec.ml` (`artifact_row`, `project_spec_of_rows`), `base/canary_artifact.ml` (`axes = {ax_universe; ax_runtime; ax_follows; ax_pins}`), `tool/canary_store_config.ml` (providers) | **[`stage1_project_spec.md`](stage1_project_spec.md)** — THE stage-1 doc, standalone (absorbed `repo_model.md` + `versioning.md`, purged 2026-08-23). Background: [`../../project/opam_exclusive_store_issue.md`](../../project/opam_exclusive_store_issue.md) what a pin costs, [`multi_lib.md`](multi_lib.md) what cannot be declared | `enumerate.project_spec_sqlite_shape`, `enumerate.per_artifact_provisions`, `enumerate.per_artifact_versions`, `enumerate.per_provision_versions`, `repo_model.axes_pins`, `repo_model.contents_invariant`, `spec.vendored_prebuilt_pair`, `spec.pm_dep_gate_groups`, `sqlite.provider_rows`, `z3.provider_rows`                                                                                                   |
| **2. enumeration**      | the product, then the constraints that prune it                                                                                                    | `action/canary_enumerate.ml` (`run_config`, `enumerate_points`, `assignment_of_point`, then `assignment_ok`, `ax_follows`, `binding_couples`, `source_ref_ok`, `shadow_filter`, `ref_filter`)            | **[`stage2_filters.md`](stage2_filters.md)** — the product and the five constraints                                                                                                                            | `enumerate.config_levels`, `enumerate.subset_intersects_universe`, `enumerate.thin_is_version_subset`, `enumerate.refs_subset`, `enumerate.shadow_policy_drops_same_cell_built`, `enumerate.point_to_assignment_fold`, `enumerate.two_projections_and_filter`, `enumerate.version_axis`, `enumerate.built_from_of_assignment`, `enumerate.mismatch_direction`, `enumerate.deploy_mismatch`, `shadow.policy_ladder` |
| **3. identity + order** | which assignments are the SAME scenario, and in what order they run                                                                                | `project/canary_project_run.ml` (`scenarios_of`, `scenario_dir_of`, `store_state_key`, `scenarios_in_run_order`)                                                                                         | **[`stage4_order.md`](stage4_order.md)** — THE stage-3 doc, standalone. Background: [`../../project/opam_exclusive_store_issue.md`](../../project/opam_exclusive_store_issue.md) (the opam instance)                                                                                                  | `run_order.groups_by_store_state`, `matrix.registry_shape`, `z3.install_prefix_isolated`, `z3.env_guard_paths`, `world.one_vocabulary`                                                                                                                                                                                                                                                                                                                                                         |
| **4. realization**      | assignment → commands → steps; and the parallel node-graph view                                                                                    | `project/*` (`pr_runner_spec = realize ∘ dispatch`), `action/canary_step_builder.ml` (`derive_steps`), `action/canary_action.ml` (`node_of_assignment`, `close_deps`, `execution_plan`)                  | **[`stage5_realize.md`](stage5_realize.md)** — THE stage-4 doc, standalone. [`../action_playbook.md`](../action_playbook.md) to add an action                                                                                                          | `action.node_of_assignment_chain`, `action.close_deps_deploy_mismatch`, `action.execution_plan_topo_and_edges`, `arrow.providing_action_total_and_consistent`, `enumerate.dispatch_coordinate_reads`, `z3.dispatch_reads_source_placement`, `derive.fetch_lib_matches_helper`, `probe_invariant.consumes_eq_artifacts`                                                                                             |
| *(consumer)* — reporting        | what a row is and what names it                                                                                                                    | `main/canary_matrix.ml`, `backend/canary_status.ml`, `backend/canary_html.ml`                                                                                                                            | [`../matrix.md`](../matrix.md)                                                                                                                                                                                                               | `matrix.row_index`, `matrix.row_order`, `matrix.cell_stage_progression`, `matrix.setting_block_identifies_world`, `matrix.marks_from_log`                                                                                                                                                                                                                                                                          |

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
