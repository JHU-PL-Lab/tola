# Proposal — `canary emit`: one dump per pass

**Kind: proposal.** **Landed when** `canary emit <project> --stage N`
prints the value stage N actually hands to stage N+1, for every stage,
and the runner and the dump read the same pipeline. The map is
[`README.md`](README.md).

> 2026-08-24, user: *"is it possible to print every stage's output, so
> that making the whole pipeline a compiling-pass experience, then
> debugging and explanation can make more clear to check."* Explored
> first; this is the sized answer. Nothing here needs a model change.

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
canary emit <project> --stage <0..5> [--json] [--why] [--thin] [--refs …]
```

One rule, and it is the whole point: **`--stage N` prints the value stage
N hands to stage N+1** — not a rendering of it, and not a join with a
neighbouring stage. `spec` keeps its current job (a human-facing joined
snapshot); `emit` is the debugging surface.

`--json` for diffing two runs. `--why` is §6.

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

## 7. Code changes, in order

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
   behavioural risk (see §10).

Roughly two days, and steps 1–3 alone close the stage-3 gap.

## 8. Tests

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

Falsification for each: `stage3_is_run_order` by making the dump call
`scenarios_of`; `why_accounts_for_every_candidate` by dropping a
candidate without recording it.

Existing suites are unaffected — `emit` is additive, and step 2 is a move
whose behaviour is pinned by everything that already tests the runner.

## 9. On grouping code by stage

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

1. **One `Canary_pipeline` module (step 2 above) that names the passes in
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

## 10. What not to do

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
