# Proposal — `canary emit`: one dump per pass

**Kind: proposal, partly landed.** **Landed when** `canary emit <project>
--stage N` prints the value stage N actually hands to stage N+1, for
every stage, and the runner and the dump read the same pipeline. The map
is [`README.md`](README.md).

> **Steps 1–4 landed 2026-08-24.** `deriving show` on the stage IRs;
> `Canary_pipeline` (main/) as the single assembly, with the runner and
> `Canary_matrix.actions_of` both routed through it; `canary emit
> <project> --stage <1|2|3|4> [--raw]`. Pins:
> `pipeline.ctx_matches_scenario_dir`,
> `pipeline.stages_total_over_catalogue`, both falsified. **Still open:**
> `--json`, `--why` (§6) and the selection pass (§7).

> 2026-08-24, user: *"is it possible to print every stage's output, so
> that making the whole pipeline a compiling-pass experience, then
> debugging and explanation can make more clear to check."* Explored
> first; this is the sized answer. Nothing here needs a model change.
>
> §7 answers a second question from the same day — where config and
> policy sit relative to the stages — and is the one structural change
> the proposal carries.

## 1. Why — three incidents this would have made cheap

Not a hypothetical convenience. Each of these cost real time this month:

- **A scenario that should exist doesn't.** Stage 2 is a product followed
  by five constraints ([`stage2_filters.md`](stage2_filters.md)). When a
  world is missing, the only way to find out which constraint ate it is
  to reason about all five by hand. Twice this month that reasoning was
  the debugging.
- **The run order is invisible.** `scenarios_in_run_order` landed
  2026-08-21 and appears in exactly two non-definition places — the
  runner and its pin. `canary spec` still prints *enumeration* order,
  which since that change is **not what runs**. The ordering is verified
  but cannot be looked at.
- **A step's command can only be seen by running it.** `pp_step` /
  `dump_step` were retired to `doc/_legacy_code/` on 2026-06-01 with the
  note *"the live pipeline never called any of them"*, and nothing
  replaced them. To see what `build_binding_ocaml` will run, you run it.

## 2. The enabling fact — the pipeline is already pass-shaped

Every stage boundary is a **total function over a distinct first-class
type**. That is the hard half of a compiler-pass experience, and it is
already true:

```
pr_artifacts : artifact_row list
  │ project_spec_of_rows                    action/canary_project_spec.ml
  ▼ project_spec                                                  stage 1
  │ enumerate ~tag ~policy                  action/canary_enumerate.ml
  ▼ assignment list                                               stage 2
  │ select (PROPOSED, §7 — today thin acts inside stage 2
  │         and refs at its end)             action/canary_enumerate.ml
  ▼ assignment list (selected)                                   stage 2.5
  │ scenarios_in_run_order                  project/canary_project_run.ml
  ▼ assignment list (ordered)                                     stage 3
  │ pr_runner_spec ; derive_steps           action/canary_step_builder.ml
  ▼ step list                                                     stage 4
  │ run_with_info_status                    backend/canary_local_runner.ml
  ▼ verdicts → actions.log                                        stage 5
```

## 3. Where the printing stands

| stage | value | today | gap |
| --- | --- | --- | --- |
| 1 | `project_spec` | `spec`, `spec --json` | joined with stage 2; `--by-artifact` joins stage 5 too |
| 2 | `assignment list` | `spec` lists them | enumeration order; **no attribution** for what was pruned |
| 3 | ordered `assignment list` | — | **absent**, and `spec` prints a different order |
| 4 | `step list` | — | **absent**; `graph` renders the universal catalogue, not a scenario's steps |
| 5 | verdicts | `status`, `result`, matrix.html | fine |

Also: `scenarios --engine` does **not** project the project. It builds a
synthetic `general_slice` over a hardcoded `[Absent; Fetched; Built]` and
prints a count — an illustration of the algorithm, not a dump.

## 4. The surface

```
canary emit <project> --stage <0|1|2|2.5|3|4|5> [--json] [--why] [--thin] [--refs …]
```

One rule, and it is the whole point: **`--stage N` prints the value stage
N hands to stage N+1** — not a rendering of it, and not a join with a
neighbouring stage. `spec` keeps its current job (a human-facing joined
snapshot); `emit` is the debugging surface.

`--json` for diffing two runs. `--why` is §6.

## 4a. Two findings from building steps 1–4 (2026-08-24)

**`pr_runner_spec` is not pure — but the impure branch is unreachable
today.** Deriving a step list applies `pr_runner_spec`, and tiny-full's
realization can call `Canary_tiny_workspace.materialize_built_lib`, which
does `rm_rf` + rebuild. Measured: tiny-full enumerates ONE scenario, all
Vendored, which dispatches to `Base` → `witness_base_workspace ()`, which
is path arithmetic and touches nothing. The impure branch is idempotent
and writes into tiny's own cache rather than the passed workspace, and it
becomes reachable only if tiny-full regains its Built-lib scenarios. The
right fix is the one CLAUDE.md already names as missing — materialization
as an ACTION in the catalogue rather than something that happens while
building the spec — and that is an arc, not a patch. Deferred
deliberately; `emit --stage 4` says so in its output.

**Three sanitizers, none of which can fire.** The runner mapped `:` `#`
`+` out of the scenario basename; `scenario_dir_of` maps `:` out of the
artifact kind and `/` out of a pin id; and the producer,
`string_of_artifact_kind`, emits `_` and never `:` in the first place. So
the naming scheme was already valid and the sanitizers were accreted
defensively. The runner's was removed (user: an old issue whose better
answer is a valid naming scheme); `scenario_dir_of`'s stay, because a
backstop belongs at the producer while a patch at the consumer does not.

`pipeline.scenario_names_are_born_safe` asserts the scheme rather than
the patches: whatever the producers emit, the name that reaches the
filesystem carries no character needing escaping in a path or a
`:`-separated env var. Falsifying it takes breaking the producer AND its
normalization together — which is the correct difficulty for a claim
about a scheme.

## 5. The closure problem, and its answer

Two of the IRs contain closures and therefore cannot be `deriving show`:

- **`runner_spec`** is a record of command *builders*. It has no printable
  form of its own — which is fine, because it is an intermediate nobody
  needs: `--stage 4` should print the **step list**, its observable
  consequence.
- **`step`** carries `cmd : output_dir:… -> variant_key:… -> string`,
  `check_pre`, `check_post`.

So a stage-4 dump is an **application**, not a projection: apply `cmd`
with the scenario's real `output_dir` and print the resulting shell
string; report `check_pre`/`check_post` as present/absent plus the
expectation variant. This path already exists —
`Canary_local_runner.step_fingerprint` realizes the full command outside
a run in order to fingerprint it, and `runner.marker_stale_on_spec_change`
depends on that. `emit --stage 4` is that realization, printed instead of
hashed.

## 6. `--why` — attribution, and why it is the payoff

Stage 2's constraints currently answer *yes/no*. The debugging question is
*which one, and about which artifact*. Cheaply available, because **three
of the five are already predicates**:

| constraint | shape today | to attribute |
| --- | --- | --- |
| `assignment_ok` | `assignment -> bool` | free — run it, record the verdict |
| `binding_couples` | `spec -> assignment -> id -> bool` | free, per artifact |
| `source_ref_ok` | `spec -> assignment -> id -> bool` | free, per artifact |
| `ax_follows` (lockstep) | inline in `enumerate` | small — lift to a named predicate |
| `shadow_filter` | `assignment list -> assignment list` | return `(kept, dropped × reason)` |
| `ref_filter` | `assignment list -> assignment list` | same |

Output shape:

```
$ canary emit sqlite --stage 2 --why
product: 24 candidates
  kept    10
  dropped 14
    assignment_ok        8   (lib Built@Dev without its source)
    source_ref_ok        4   (unread source: not the canonical ref)
    shadow_filter        2   (prebuilt shadows Built at the same version)
```

The invariant worth having is stronger than the listing: **kept + dropped
= the product**. Nothing disappears unexplained.

## 7. The missing pass — selection is a stage 2 → 3 function

*(2026-08-24, user: "are the possible config/policy issues either
functions from stage 2 to stage 3, or just a stage 3 refinement?")*

**Neither, as asked — because "config/policy" is currently three
different things.** Separate them and only one is a 2 → 3 function, and
it is the one the question is pointing at.

| kind | examples | where it belongs |
| --- | --- | --- |
| **model constraints** | `assignment_ok`, `binding_couples`, `source_ref_ok`, `shadow_filter` | stage 2, **unconditional** — they say a world cannot exist or is indistinguishable. Turning one off does not buy coverage, it buys wrong or duplicate worlds |
| **selection** | `--thin`, `--refs`, and the queued scenario / action / project selectors | **its own pass, 2 → 3** |
| **run configuration** | `pr_tier` Heavy/Light, failfast, root, parallelism | stage 4 and later — not about which worlds at all |

Two pieces of evidence that the tree already knows this:

- `shadow_filter` shipped with a `Shadow_prebuilt | Materialize_source`
  knob and an `Audit_lib` run rung, and both were **removed** on
  2026-08-19 (user: *"I think we remove this feature"*). That was
  recognizing shadowing as model rather than policy — the knob existed
  because it had been misfiled.
- [`stage2_filters.md`](stage2_filters.md) §6 already says `ref_filter`
  is *"a selection, not a semantic constraint — it belongs to the run,
  not to the model"*. The generalization is that the *category* is
  missing, not that one filter is misplaced.

### Why a pass, and not a stage-3 refinement

The honest part first: **selection commutes with all of stage 3.**
Selecting then dedup/order/group gives the same result as
dedup/order/group then selecting — dedup keys on the pin id and so does
`--refs`, and a stable sort preserves relative order under filtering. So
correctness does not decide this, which is exactly why the question feels
ambiguous. Legibility does, and three arguments agree:

- **Stage 2's output becomes invocation-independent** — "every world this
  project has", a fact about the project rather than about today's flags.
  That is what makes `emit --stage 2` diffable across runs, and it
  sharpens `matrix.registry_shape`, which today pins 42 rows *under the
  default config* while reading as a statement about the enumeration.
- **"Why isn't this running?" splits into two answerable questions** —
  *it does not exist* (a stage-2 constraint) versus *you did not ask for
  it* (selection). Today both look identical, which is precisely what §6
  is trying to fix.
- **One question per stage.** Stage 3 doing identity, exclusivity, order
  *and* selection is the same violation the doc reorganization has been
  removing.

### The wrinkle to know before implementing

**`--thin` acts BEFORE the product; `--refs` acts AFTER it.**
`resolve` / `resolve_versions` restrict each artifact's universe and the
product is built from what is left; `ref_filter` runs on the finished
assignment list. They cannot be unified while they act in different
places.

They are equivalent for the levels actually used — restricting a factor
of a product equals filtering the product on that factor, and `Subset`
*intersects* the universe, so an artifact with no matching version simply
contributes no placement (which is how thin z3 drops the `Built`
provision and keeps the fetch chain). `Free` ("the head of the universe")
is expressible as a post-filter but awkward, and it is tiny-only. So thin
can move to the post-filter side without changing any current result. The
cost is building a larger product first, which at today's sizes is
nothing.

**A symptom worth naming**: there are two `run_config`s in one pipeline.
`Canary_enumerate.run_config` is the *function* that resolves levels into
points; `Canary_project_run.run_config` is the *record* of a run's
settings. And `enumeration_policy_of : run_config -> policy option` maps
one into the other — category 3 reaching into category 1's machinery, in
a single line.

### What it costs, and how it lands with `emit`

1. Move `--thin`'s level resolution to the post-filter side, beside
   `ref_filter`. The equivalence above says no result changes, and
   `matrix.registry_shape` + `enumerate.thin_is_version_subset` prove it.
2. Name the pass: one `select : selection -> assignment list ->
   assignment list` in `action/canary_enumerate.ml`, with `selection` the
   single record the tracker's "ONE general SELECTION config" item wants.
3. Rename one of the two `run_config`s.

Then `emit --stage 2` is the project's worlds, `emit --stage 2.5 --why`
is what you asked for and what you did not, and stage 3 goes back to one
job. The two changes are worth doing together: `--why` is what makes the
split visible, and the split is what makes `--why` answer two different
questions instead of one blurred one.

## 8. Code changes, in order

Each step is independently useful; none depends on an unbuilt piece.

1. **`deriving show` on the stage IRs** — `placement`, `assignment`,
   `artifact_axes`, `project_spec` (`base/canary_artifact.ml`). Their
   components already derive it (`provision`, `build_id`, `artifact_id`,
   `channel`). ~10 lines. `string_of_assignment` already exists and stays
   the compact form; `show` is the faithful one.
2. **`Canary_pipeline` in `main/`** — one module naming the passes, so the
   runner and `emit` consume the same chain rather than two assemblies of
   it (see §9). ~60 lines, mostly moving.
3. **`emit` subcommand** over that module, stages 1/2/3/5. ~80 lines in
   `src/bin/canary_main.ml` + a printer per stage.
4. **Stage-4 dump** — the step-list printer described in §5. ~50 lines;
   replaces what was retired in 2026-06-01.
5. **`--why`** — the two `list -> list` filters return their dropped set
   with a reason; the three predicates are wrapped in a recorder. ~80
   lines in `action/canary_enumerate.ml`, and the only change with any
   behavioural risk (see §11).
6. **The selection pass (§7)** — move thin's level resolution beside
   `ref_filter`, name `select`, rename one `run_config`. ~100 lines.
   Independent of 1–5, but best done with 5: `--why` is what makes the
   split visible, and the split is what lets `--why` distinguish "does
   not exist" from "not asked for".

Roughly two days for 1–5, plus half a day for 6. Steps 1–3 alone close
the stage-3 gap.

## 9. Tests

**Structural invariants, not golden files.** A golden dump churns on
every legitimate spec change and gets blanket-regenerated, which trains
people to stop reading it — the opposite of the goal. Each pin below
states a *relationship* instead:

| pin | asserts |
| --- | --- |
| `emit.total_over_registry` | every stage emits for every catalogued project (muted included) without raising |
| `emit.stage2_is_scenarios_of` | the stage-2 dump equals `scenarios_of` — the dump is the value, not a re-derivation |
| `emit.stage3_is_run_order` | the stage-3 dump equals `scenarios_in_run_order`, so the printed order cannot drift from the executed one. **This is the pin that closes today's gap** |
| `emit.stage4_matches_derive_steps` | the step-list dump has the same tags, in the same order, as `derive_steps` for that scenario |
| `emit.why_accounts_for_every_candidate` | kept + dropped = the product, per project — nothing vanishes unexplained |
| `emit.why_reasons_are_known` | every drop reason names one of the six constraints (no "other") |
| `select.thin_post_filter_equals_universe_restriction` | for every catalogued project, thin-as-post-filter yields exactly the assignment set thin-as-universe-restriction does — the equivalence §7 rests on, checked rather than argued |
| `select.is_a_subset_of_stage2` | selection only removes; the selected set is a subset of the unselected one, so it can never invent a world |

Falsification for each: `stage3_is_run_order` by making the dump call
`scenarios_of`; `why_accounts_for_every_candidate` by dropping a
candidate without recording it.

Existing suites are unaffected — `emit` is additive, and step 2 is a move
whose behaviour is pinned by everything that already tests the runner.

## 10. On grouping code by stage

The user's follow-on: *"it may also help to group code in separate stages
when it's done."* Worth being precise about, because the codebase already
has an organizing axis and the two are not the same:

- **Layers** (`base/ → surface/ → tool/ → action/ → backend/`, with
  `project/` and `main/` on top) are a **dependency** discipline: who may
  reference whom. It is enforced by dune and it works.
- **Stages** are a **dataflow** discipline: who hands what to whom.

They cut across each other, and the crossing is real: stages 2 and 4 live
in `action/`, but stage 3 lives in `project/` — above both — because
`store_state_key` needs a `project_run`. Dataflow says 2 → 3 → 4;
layering says `action/` is below `project/`. Neither is wrong.

So **do not reorganize the directories by stage** — that would fight a
discipline that is working, for a labelling benefit. Two smaller moves get
the readability without the fight:

1. **One `Canary_pipeline` module (step 2 of §8) that names the passes in
   order.** Today the pipeline is assembled in exactly one place —
   `run_project_spec` in `main/canary_runner.ml` — and *partially
   re-assembled* in a second: `canary_matrix.ml` calls `derive_steps`
   itself to compute cells. Two assemblies of one pipeline is how they
   drift. A named module makes the chain a thing you can point at, and
   gives `emit` and the matrix the same one.
2. **Move stage 3's pure core down.** `scenario_dir_of` and
   `store_state_key` read only an assignment plus the providers; they sit
   in `project/` for one type. Taking the rows rather than the
   `project_run` would let them live in `action/` beside stages 2 and 4,
   leaving `project/` the project-shaped wrapper. Optional, and only
   worth doing if it stays a simplification.

## 11. What not to do

- **Do not make `emit` re-derive.** If the dump computes its own answer,
  it can agree with itself while disagreeing with the runner — the exact
  failure mode `emit.stage3_is_run_order` exists to prevent.
- **Do not let `--why` change what is enumerated.** The recorder observes
  the constraints; it must not reorder or short-circuit them. Guard with
  `emit.why_accounts_for_every_candidate` *and* by checking the kept set
  still equals `scenarios_of`.
- **Do not fold `spec` into `emit`.** `spec` is a human snapshot that
  deliberately joins stages; `emit` is one pass at a time. Both are
  useful, for different questions.
