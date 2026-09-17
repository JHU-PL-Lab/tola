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

## How to read this, if you are new

Four steps, ~45 minutes, and you can stop after any of them:

1. **This file, top to bottom** (~10 min). The pipeline, how to look at a
   pass, why layers and passes are different axes, and the five
   invariants. Enough to talk about the enumeration and to know where
   anything lives.
2. **Run it against a project** (~5 min). Reading beats being told:

   ```sh
   canary emit sqlite --stage declare      # what the project states
   canary emit sqlite --stage analyse      # what canary makes of it
   canary emit sqlite --stage enumerate    # 10 worlds it HAS
   canary emit sqlite --stage select       # 10 of 10 — the default asks for all
   canary emit z3     --stage select --thin        # 1 of 16
   canary emit sqlite --stage order        # the same 10, grouped by store state
   canary emit sqlite --stage realize      # one scenario's steps
   ```

   z3 is the richest spec (16 worlds, both cross cells) and is muted, so
   it is the best thing to dump and the safest to not run. Compare
   `--stage enumerate` with `--stage order` on sqlite: same ten
   scenarios, and the second shows why the run order is not the
   enumeration order.
3. **The pass whose behaviour you need** — one doc each, below. If you
   are landing a project, read [pass 1](stage1_declare_spec.md) and stop;
   it is what you will actually write.
4. **The vocabulary** ([`stage0_naming.md`](stage0_naming.md)) when a word
   stops being obvious — "scenario" has four senses and they are all in
   use.

**Where the code is**, if you would rather start there:
`project/canary_project_analysis.ml` is pass 2;
`action/canary_enumerate.ml` is passes 3 and 4;
`project/canary_project_run.ml` is passes 1 and 5;
`action/canary_step_builder.ml` is pass 6; and
`main/canary_pipeline.ml` names them all in order — that one is the
30-second version of this page.

**What to be skeptical of.** Where a doc and the code disagree, the code
is right and the doc is a bug. The pass table below names the pins for
each pass, and `canary project-test` is the arbiter — a claim with no pin
behind it is the one to distrust first.

## The pipeline

**Four IRs, six passes** — and the counts deliberately do not match.

| IR            | type                       | what it is                                                        |
| ------------- | -------------------------- | ----------------------------------------------------------------- |
| *(surface)*   | `artifact_row list`        | the project's own words: what it declares, one row per artifact   |
| **spec**      | `project_spec`             | the declared universe, fused into one table                       |
| **analysis**  | `Canary_project_analysis.t` | the spec plus what canary DERIVES from it, world-free             |
| **worlds**    | `assignment list`          | one placement per artifact — a world the project has              |
| **steps**     | `step list`                | the object code                                                   |

Each pass, with the IR it takes and the IR it hands on:

| #   | pass          | IR                 | in                  | out                                             | function                                 |
| --- | ------------- | ------------------ | ------------------- | ----------------------------------------------- | ---------------------------------------- |
| 1   | **declare**   | surface → spec     | `artifact_row list` | `project_spec`                                  | `project_spec_of_rows`                   |
| 2   | **analyse**   | spec → analysis    | `project_spec`      | the chains it admits, its bindings, its claims  | `Canary_project_analysis.of_project_run` |
| 3   | **enumerate** | analysis → worlds  | `project_spec`      | `assignment list` — every world the project HAS | `enumerate_product` ∘ 5 constraints      |
| 4   | **select**    | worlds → worlds    | `assignment list`   | `assignment list` — what this RUN asked for     | `select`                                 |
| 5   | **order**     | worlds → worlds    | `assignment list`   | `assignment list` — same elements, resequenced  | `scenarios_in_run_order`                 |
| 6   | **realize**   | world → steps      | one `assignment`    | `step list`                                     | `realize ∘ dispatch` then `derive_steps` |

```
artifact_row list    (surface)
  ▼  1 declare
project_spec         IR: spec
  ▼  2 analyse       chain applicability, mechanisms, carried claims
analysis             IR: analysis — what canary UNDERSTANDS, no world yet
  ▼  3 enumerate     product × 5 constraints
assignment list      IR: worlds  — every world the project HAS
  ▼  4 select        --thin, --refs                    ┐ same IR in and out:
assignment list      IR: worlds  — what this run asked for
  ▼  5 order         stable sort on store_state_key    ┘ two optimizations
assignment list      IR: worlds  — same elements, resequenced
  ▼  6 realize       per assignment
step list            IR: steps ──────────────────── the object code
  │
  ├──▶ run_graph          execute here          → actions.log → verdicts
  ├──▶ render_gh_step     GitHub Actions YAML
  ├──▶ mermaid_of_steps   diagram (muted)
  └──▶ render_steps_data  HTML page
```

**The diagram has no branch any more** (2026-09-16). It used to fork at
pass 1 — `├──▶ applicable chains (spec alone)` — beside an unnumbered
*(branch)* row in the table above, and the "open question" section below
listed that fork among the accidents it wanted redrawn: *"chain
applicability with nowhere to live — a real spec-only derivation that is
neither a pass nor a dump, and hides inside `patterns_of`"*. Pass 2 is
where it lives now. It is a field of the analysis (`an_chains`), it
prints (`canary emit <p> --stage analyse`), and `Canary_enumerate.applicable_chains`
is the one function both it and `patterns_of` call, so the two cannot
drift.

**Passes 4 and 5 are endomorphisms** — `worlds → worlds`. 4 removes, 5
reorders, and neither invents. That is what makes them cheap to reason
about and why `select.is_a_subset_of_stage2` and
`run_order.groups_by_store_state` can each state their whole contract in
one line. (The first pin's name still says `stage2`; it was written when
enumerate was pass 2. The pin NAMES are deliberately not renumbered —
see *The alignment rule* below.)

**Pass 2 does not lower, and it is still a pass.** `analysis` carries
the `project_spec` it was built from (`an_spec`), so what pass 3 reads is
what pass 1 wrote; what pass 2 adds is everything canary DERIVES before a
world exists. The rule for membership is the absence of a world:
applicability is `mechanism → lang → declared → _`, so it is knowable
here, while FIRING is `mechanism → lang → world → _` and cannot be. That
is the line the 2026-09-15 Python bug crossed in three different files.

**The filename convention is `stage<N>_<verb>_<IR out>.md`** (2026-08-25,
user: *"put the ir in the name so both the stage index and the ir are
clear"*):

```
stage0_naming.md            vocabulary — not a pass, so no IR
stage1_declare_spec.md      surface  → spec
stage2_analyse_spec.md      spec     → spec, enriched
stage3_enumerate_worlds.md  spec     → worlds
stage4_select_worlds.md     worlds   → worlds
stage5_order_worlds.md      worlds   → worlds
stage6_realize_steps.md     world    → steps
```

A directory listing now says three things. The **index** gives the
reading order, which no IR name can carry. The **verb** says what the
pass does. The **suffix** shows where the IR lowers and where it does
not: `_spec` twice and `_worlds` three times running make passes 2, 4 and
5 visibly enrichments or optimizations over a fixed IR rather than
lowerings — the endomorphism fact above, legible without opening a file.

Naming by IR *alone* was the first suggestion, and it collides exactly
there: 4 and 5 would both be `ir_worlds_*.md`. Compilers keep both
vocabularies for this reason — LLVM names its IRs (AST, LLVM IR,
MachineIR, MC) and its passes separately (mem2reg, GVN, regalloc),
because many passes share one IR and only a few lower between them.
Carrying both in one filename beats choosing.

**The step list is the object code, and the backends are targets.** Four
of them consume it, and **executing is one of the four**, not a stage
above them: `run_graph` runs it here, `render_gh_step` emits CI YAML,
`mermaid_of_steps` draws it, `render_steps_data` renders the page. So the
chain is 1–6 and then a fan-out, not 1–7 — numbering the targets would
imply a sequence where there is a choice.

**Pass 5 is a performance pass, not a correctness one.** The runner runs
whatever order it is given; ordering only changes how many times a
single-valued store is re-pinned (measured: sqlite 9 real swaps → 2, and
z3's `fetch_binding_ocaml` accumulating 344 s in one sampled window
because six of sixteen rows each rebuilt libz3). It is safe to reorder
*because* `pin_check_post` re-pins whenever the pin is not held — the
property is earned by pass 5 §2's verify-or-set discipline, not free.

**Identity is applied twice, at two granularities**, and pass 5 does not
own the second one. `scenarios_of` dedups on the canonical assignment
string; the runner's loop dedups again on `scenario_dir_of`, which is
COARSER because an ambient (unpinned) `Fetched` version is not part of a
scenario's identity. Both are needed — the second is where
`Fetched@Stable` and `Fetched@Dev` collapse into one run — but it means
the coarse collapse happens inside pass 6's loop rather than in the pass
named for identity. One of the things the open redesign question below
would tidy.

**A scenario is a chain PLUS coordinates** — which is what
[`stage0_naming.md`](stage0_naming.md) has always said it is, and the
chain half used to be easy to miss because it had no pass of its own. It
is computed from the SPEC ALONE, before any policy or assignment exists:
`chain_applicable` keeps the universal chains whose every step this
project can actually run (the artifact is declared, at a provision that
the step's version rule needs, and a `build_binding` step needs a STATIC
binding). `patterns_of` then pairs each surviving chain with each
assignment it matches.

That derivation is **pass 2** since 2026-09-16. `canary paths` still
prints the unfiltered 38; `canary emit <project> --stage analyse` prints
the per-project survivors, which nothing printed before.

**There is no mutation axis for a real project.** The enumeration is
polymorphic in a mutation (`enumerate ~tag`), and `config.mutation`
resolves to the no-fault baseline for every registry project —
`policy.mutations = []` in `full_policy` and `thin_policy` alike. The one
caller that supplies faults is `tiny_policy` in
`canary_tiny_scenario.ml`, which is tiny1's oracle and not a registry
project. So: two axes here, provision and version. The mutation is
tiny-factory machinery that happens to ride the same product.

## The six passes — doc, code, pins

One row per pass. Everything about a pass is reachable from its row: the
doc that explains it, the code that is it, and the pins that would fail
if the two drifted apart.

| #            | pass                      | what happens                                                                                                                                        | doc                                                                                                                     | code                                                                                                                                                                                    | pins                                                                                                                                                                                                                                                                                                                                                  |
| ------------ | ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| —            | *vocabulary* (not a pass) | the types every pass reuses: `artifact_kind`, `provision`, `channel`, `version`, `build_id`, `artifact_info`, `placement`, `assignment`, `dep_mode` | [`stage0_naming.md`](stage0_naming.md) (the four senses of "scenario"), [`../ssot.md`](../ssot.md) (IDs)                | `base/canary_basic.ml`, `base/canary_store.ml`, `base/canary_artifact.ml`                                                                                                               | `vocab.binding_source_off_tree`, `vocab.lib_name_optional`, `surface.split_keeps_checks_drops_provenance`, `scenario.lower_expectation_agnostic_c1`                                                                                                                                                                                                   |
| 1            | **declare**               | a project states which artifacts exist, at which provisions and versions, and who provides each                                                     | [`stage1_declare_spec.md`](stage1_declare_spec.md)                                                                      | `action/canary_project_spec.ml` (`artifact_row`, `project_spec_of_rows`), `base/canary_artifact.ml` (`artifact_axes`), `tool/canary_store_config.ml` (`provision_spec`)                 | `enumerate.project_spec_sqlite_shape`, `enumerate.per_artifact_provisions`, `enumerate.per_artifact_versions`, `enumerate.per_provision_versions`, `repo_model.axes_pins`, `repo_model.contents_invariant`, `spec.vendored_prebuilt_pair`, `spec.pm_dep_gate_groups`, `sqlite.provider_rows`, `z3.provider_rows`                                      |
| 2            | **analyse**               | what canary DERIVES from the spec, before any world: the chains it admits, the mechanism each language binds through, which claims it can carry | [`stage2_analyse_spec.md`](stage2_analyse_spec.md)                                                                      | `project/canary_project_analysis.ml` (`of_project_run`, `carries`, `suits`), `action/canary_enumerate.ml` (`applicable_chains`)                                                          | `checks.applicability_reads_the_declaration`, `checks.index_speaks_each_action_language`, `mechanism.dynamic_binding_has_no_build_chain`                                                                                                                                                                                                                     |
| 3            | **enumerate**             | the product, then the five constraints that prune it                                                                                                | [`stage3_enumerate_worlds.md`](stage3_enumerate_worlds.md)                                                              | `action/canary_enumerate.ml` (`enumerate_product`, then `assignment_ok`, `ax_follows`, `binding_couples`, `source_ref_ok`, `shadow_filter`)                                             | `enumerate.config_levels`, `enumerate.subset_intersects_universe`, `enumerate.shadow_policy_drops_same_cell_built`, `enumerate.point_to_assignment_fold`, `enumerate.two_projections_and_filter`, `enumerate.version_axis`, `enumerate.built_from_of_assignment`, `enumerate.mismatch_direction`, `enumerate.deploy_mismatch`, `shadow.policy_ladder` |
| 4            | **select**                | narrow to what THIS run asked for — `--thin`, `--refs`                                                                                              | [`stage4_select_worlds.md`](stage4_select_worlds.md)                                                                    | `action/canary_enumerate.ml` (`select`, `selection_of_policy`, `unselected`, `ref_filter`)                                                                                              | `select.is_a_subset_of_stage2`, `select.full_policy_selects_everything`, `select.thin_post_filter_equals_universe_restriction`, `enumerate.thin_is_version_subset`, `enumerate.refs_subset`                                                                                                                                                           |
| 5            | **order**                 | which assignments are the SAME scenario, and in what order they run                                                                                 | [`stage5_order_worlds.md`](stage5_order_worlds.md)                                                                      | `project/canary_project_run.ml` (`scenarios_of`, `scenario_dir_of`, `store_state_key`, `scenarios_in_run_order`)                                                                        | `run_order.groups_by_store_state`, `world.one_vocabulary`, `matrix.registry_shape`, `z3.install_prefix_isolated`, `z3.env_guard_paths`                                                                                                                                                                                                                |
| 6            | **realize**               | assignment → commands → steps; then a backend consumes them                                                                                         | [`stage6_realize_steps.md`](stage6_realize_steps.md), [`../action_playbook.md`](../action_playbook.md) to add an action | `project/*` (`pr_runner_spec = realize ∘ dispatch`), `action/canary_step_builder.ml` (`derive_steps`), `action/canary_action.ml` (`node_of_assignment`, `close_deps`, `execution_plan`) | `action.node_of_assignment_chain`, `action.close_deps_deploy_mismatch`, `action.execution_plan_topo_and_edges`, `arrow.providing_action_total_and_consistent`, `enumerate.dispatch_coordinate_reads`, `z3.dispatch_reads_source_placement`, `derive.fetch_lib_matches_helper`, `probe_invariant.consumes_eq_artifacts`                                |
| *(consumer)* | reporting                 | what a row is and what names it — READS `actions.log`, so not a pass                                                                                | [`../matrix.md`](../matrix.md)                                                                                          | `main/canary_matrix.ml`, `backend/canary_status.ml`, `backend/canary_html.ml`                                                                                                           | `matrix.row_index`, `matrix.row_order`, `matrix.cell_stage_progression`, `matrix.setting_block_identifies_world`, `matrix.marks_from_log`                                                                                                                                                                                                             |

**Reporting is not a pass.** It was numbered 6 until 2026-08-24; the
matrix is built by `canary result`, which reads `actions.log` *after* a
run, so the pipeline's dataflow ends at pass 5 writing verdicts.

**The two proposals** in this directory are not passes either:
[`multi_lib.md`](multi_lib.md) (a second C lib — naming landed
2026-08-25, `rp_build` and a per-slot action role remain) and
[`resolve_placements.md`](resolve_placements.md) (nothing resolves a
placement to a concrete location, and three types describe one idea).
[`../staged_parity.md`](../staged_parity.md) is cross-cutting: it
perturbs pass 1 (Installed is a provision, so a staged consumer is a
world) and pass 5 (build-vs-install parity is a check).

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

| flag        | what it gives                                                  |
| ----------- | -------------------------------------------------------------- |
| *(default)* | a compact reading form                                         |
| `--json`    | one encoder per pass, for diffing two runs. Keys are canonical |
| `--raw`     | the derived `show` form — faithful, verbose                    |

Two properties hold by construction, and they are the reason to reach for
`emit` rather than reasoning about the code:

- **The dump is the value.** Every pass goes through `Canary_pipeline`,
  which calls the very functions the runner calls. A dump cannot agree
  with itself while disagreeing with what runs.
- **`emit` reads the CATALOGUE, not the active set.** Muting a project
  suppresses running it, not inspecting it — and a muted project (z3) is
  the richest spec in the tree.

What it shows that nothing else did: pass 3 is what the project HAS and
pass 4 is what a run ASKED FOR, so "why isn't this running" has two
different answers. z3 has 16 worlds; `--thin` asks for 1; `--refs latest`
asks for 5. And pass 2 shows the chains a project's spec admits, which
nothing printed before it was a pass.

## Layers and passes are different axes

The codebase has an organizing axis already, and it is not this one:

- **Layers** (`base/ → agreement/ → tool/ → action/ → backend/`, with
  `project/` and `main/` on top) are a **dependency** discipline — who
  may reference whom. dune enforces it and it works.
- **Passes** are a **dataflow** discipline — who hands what to whom.

They genuinely cross. Passes 3 and 6 live in `action/`, but passes 2, 4
and 5 are in `project/`, above both, because they need a `project_run`.
Dataflow says 2 → 3 → 4 → 5 → 6; layering says `action/` is below
`project/`. Neither is wrong, and **reorganizing the directories by pass
would fight a working discipline for a labelling benefit**.

Pass 2 is where the two axes are most visibly at odds, and the split it
forced is worth copying. The derivation it owns — which chains a spec
admits — is implemented in `action/canary_enumerate.ml`, because
`patterns_of` is down there and needs it; what moved up to `project/` is
the *ownership of the answer*, as one field of one value. Layering keeps
the function where its other caller can reach it; dataflow gets a single
place to ask.

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
- **Selection never invents.** Pass 4 only removes, so pass 3 stays the
  honest inventory (`select.is_a_subset_of_stage2`), and the default
  selects everything (`select.full_policy_selects_everything`).
- **Model constraints are not policy.** Pass 3's five constraints have no
  knob; a world they prune could not exist or was a duplicate. The one
  time a knob was added — `shadow_filter`'s `Materialize_source` and its
  `Audit_lib` rung — it was removed as misfiled.
- **The dedup key is a function of CONTENT.** `string_of_assignment`
  sorts by artifact kind, so the same world keys one way no matter which
  construction built it.
- **Passes 1–5 are pure; pass 6 is not.** Deriving steps applies
  `pr_runner_spec` — see [`stage6_realize_steps.md`](stage6_realize_steps.md) §9.

## What is NOT here

- The **cache** — `../artifact_cache.md` (proposal) and
  [`stage6_realize_steps.md`](stage6_realize_steps.md) §4 (what exists).
- **Adding an action** — `../action_playbook.md`.
- The **checking** side — `../agreement/`, and start at its
  [`README.md`](../agreement/README.md). (The old pointer here named
  `surface/`, a directory renamed to `agreement/` on 2026-09-01 and so
  dead for a fortnight.)

  ⚠ **This boundary is being redrawn** (backlog §49). The line above
  sends *"which contract fires"* away, and that is the **occasion** — a
  function of `(world, action, mechanism, lang)`, which is this
  directory's vocabulary, not the agreement layer's. The seam is
  *agreement/ owns the CLAIM, enumeration/ owns the OCCASION*, and by it
  a section on when a check is triggered belongs in
  [`stage6_realize_steps.md`](stage6_realize_steps.md) — which today
  mentions "agreement" zero times while being the doc for the pass that
  attaches `agreement_ctx` to every step.

  Not redrawn yet, deliberately: what that section would SAY depends on
  backlog §50. Today a check is evaluated by the runner after a step's
  command; under the bundling direction a check *is* an action that
  produces the evidence it reads. Those are different paragraphs, and
  writing the first now means rewriting it.

  **Half of it has already moved, though, and that half is settled.**
  APPLICABILITY — *can this project carry this claim at all* — is
  `(mechanism, lang, declaration)` with no world in it, so it is a fact
  about the spec and it lives in pass 2
  ([`stage2_analyse_spec.md`](stage2_analyse_spec.md)). FIRING — *does it
  fire at this action in this world* — needs a world and stays at
  realize. The seam runs between those two, not between the two
  directories: agreement/ still owns what each claim SAYS.
- Anything **per project** — `../../project/`.

## The alignment rule

The pin names above are the mechanical half of "is this doc still true?".
Each one is a registered test — `canary project-test` prints them — so
when you land a change to a stage, the fastest check is whether that
stage's pins still exist and still pass.

**Pin names are not renumbered.** `select.is_a_subset_of_stage2` was
named when enumerate was pass 2 and still says `stage2`; the 2026-09-16
renumbering left every pin name alone. A pin name is an identifier that
appears in logs, in this table and in `canary project-test` output, and
renaming it to track a doc's numbering would break the one thing the name
is for — being greppable across history. Read a `stageN` inside a pin
name as a historical label, not as a claim about today's table.

**Not automated today.** A check that failed the build when a doc cited a
deleted pin was built and removed on 2026-08-23: it worked, but it was
one narrow instance of a general problem (docs citing pins, docs citing
source paths, comments citing docs, docs citing CLI verbs), wired to one
directory with a hand-maintained exclusion list. The general form is
backlog #48. Until it exists, this is a convention, not a guarantee — and
so is the converse, which no check would cover anyway: a pin can exist
while the prose around it describes something the code stopped doing.

## An open question, recorded

**Passes 3 and 4 may want a redesign** (user, 2026-08-25: *"I have a
feeling that stage 2 and stage 3 with this can have a redesign, but I am
not in a hurry"* — the numbers there are the pre-2026-09-16 ones, i.e.
enumerate and select). Not scheduled, and recorded here so the next
person does not mistake the current shape for a settled one.

What prompts it: the MODEL is two ideas — the product minus what cannot
exist, then minus what you did not ask for — but the machinery around
them accumulated things that are not part of that model. The list was
five; one is gone:

- **two constructions** (`enumerate_product`, `enumerate_follows_tree`),
  pinned equal since 2026-08-24, where one should survive;
- **a mutation axis** no registry project uses, threaded through every
  signature that touches `enumerate`;
- **a config with more knobs than uses** — `level × 3 axes ×
  version_mode`, where real projects use exactly two combinations (full
  and thin);
- ~~**chain applicability with nowhere to live**~~ — **done 2026-09-16**.
  It is pass 2. `Canary_enumerate.applicable_chains` is the one function
  `patterns_of` and the analysis both call, `an_chains` is where the
  answer lives, and `canary emit <p> --stage analyse` prints it. This was
  the item the paragraph below called "the piece that suggests the
  redraw", and doing it is what the renumbering paid for;
- **identity applied twice, in two passes** — the canonical-assignment
  dedup in pass 3 and the coarser `scenario_dir_of` dedup inside pass 6's
  loop, so the pass named for identity owns neither.

Each has a reason in its history and none is a bug. Three accidents
around two ideas is still the shape of something that would come out
simpler if drawn again — fewer than before, and the remaining three are
all about `enumerate`'s own machinery rather than about where a
derivation belongs.

## Known drift, recorded rather than hidden

- **Two dependency relations.** `step.deps` (what the runner enforces via
  `check_pre`) and the node graph's edges (`close_deps`) are separate
  relations that have drifted. Execution is sound — every step enforces
  its real deps — but the drawn diagram under-connects, so the
  connectivity invariant is muted behind `CANARY_DIAGRAM_CONN=1`.
  Reconciling them into ONE relation is tracked in `../../status.md` §A.
- **Pass 5 does not receive the world.** `derive_steps` takes a
  `runner_spec` — commands — not the assignment, so a step cannot be
  gated on a provision. That is why "don't realize a fetch nothing
  consumes" is decided from the step list and the typed catalogue
  ([`stage6_realize_steps.md`](stage6_realize_steps.md) §3b) rather than
  at enumeration, where `source_is_read` already answers the same
  question. Threading the assignment through is the same missing thread
  as the two relations above: it is what demand-driven derivation needs,
  and it is what would let an unread source be `Absent` in the world
  instead of merely unrealized in the steps. Costs, measured: the
  scenario id is the cache key, so the renamed worlds re-run cold —
  happily the cheap all-`Fetched` ones — and
  `z3.dispatch_reads_source_placement` asserts over every assignment
  including the non-building baseline.
- **The mechanism / app-wiring axes are not config axes.** They are
  ranged via the artifact-identity set (each `a_binding lang mech` is its
  own enumerated artifact). A dedicated `config` axis for them is open —
  see the `'m config` comment in `canary_enumerate.ml`.
