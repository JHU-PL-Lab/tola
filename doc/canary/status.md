# Canary Status

Rolling backlog for the canary framework. Absorbs the old
SSOT §8 (open reconciliation tasks) and §9 (strategic /
forward planning). Kept out of `design/ssot.md` per
2026-07-08 refactor — SSOT is truth (definitions), this file
is status.

For tiny-scoped items see the wish-list in
[`design/tiny.md`](design/tiny.md) §7. For the after-tiny
research task see
[`design/bad_scenario_flavors.md`](design/bad_scenario_flavors.md).
Historical chronicles in [`worklog/`](worklog/).

## 1. Now

*(Nothing in flight. Picking order (2026-07-10):*
*~~Cluster C — SSOT §6.6 project_spec doc — done~~; next up*
*is Cluster C's other half*
*([`design/tiny.md §7.9`](design/tiny.md#79-derive-related_artifacts-from-actions),*
*derive `related_artifacts`) then Cluster B — Task 2*
*([`design/tiny.md §7.8`](design/tiny.md#78-task-2--recipemutation-integration-project-hookable-factory)).*
*`tiny_recipe` synthesis (tiny.md §7.2) postponed per user.)*

## 2. Near-term

Ordered rough priority.

- **Tiny wish-list items** — see
  [`design/tiny.md`](design/tiny.md) §7 (picking-order table
  at the top). Filling derived cells + `tiny_recipe`
  synthesis both postponed; §7.8 (Task 2) and §7.9 (derive
  related_artifacts) are the active pickup candidates.

- **Flavor-2 catalogue extension** —
  [`design/bad_scenario_flavors.md`](design/bad_scenario_flavors.md).
  Cull open-source bug trackers for failure kinds not
  covered by c1..c8; propose new contracts. Foundation for
  tiny-as-bug-categorisation. Explicitly after tiny wish-list.

- **`Package` mutation source.** SSOT §5 `pkg_*` roadmap
  needs either a `Package` case on `artifact_kind` or a new
  `mutation_kind` variant. Deferred until a project needs
  it — PyTorch Tier-1 canary target
  (`design/new_project.md`) is the likely trigger.

- **Task 2 — recipe / mutation integration.** Unify
  `tiny_recipe.mutation` with `scenario.mutation`;
  project-hookable recipe interface so z3/llvm/sqlite can
  supply their own. Tiny's factory already reads
  `recipe.mutation` for store synthesis; the
  z3/llvm/sqlite side has no analogue yet. Fuller writeup
  at [`design/tiny.md §7.8`](design/tiny.md#78-task-2--recipemutation-integration-project-hookable-factory).

- **Re-do expectation as per-step contract outcome.**
  Every action's outcome (success or failure) should
  contribute to a scenario-wise testing semantics —
  positive contributions as well as negatives. Implies a
  contract layer between §6 (action steps) and §3
  (agreements), where step results are typed observations
  into the contract rather than substring assertions.
  Partially realised in Task 1.6 (hand-coded predicates
  killed for tiny), but the broader per-step framing across
  all projects is still open. Was §9.4 in old SSOT.

## 3. SSOT reconciliation

Structural items about the SSOT itself. Numbering preserved
from the old §8 to keep references stable.

0. ~~**SSOT lacks `project_spec`** — done 2026-07-10.~~
   [SSOT §6.6](design/ssot.md#66-project_spec--the-code-side-project-handoff)
   documents the type, its composition with §6.5's action
   catalogue, `derive_steps`, the four consuming backends,
   and the multi-variant pattern (tiny factory + z3/llvm
   hand-coded variants).

1. **Ar.0..Ar.3 vs code's 5 kinds.** Decide if `Headers`
   gets an Ar slot or stays implicit under Ar.1.
2. **§2 vs §3 Ag numbering.** Renumber §2 to point at the
   §3 catalogue IDs.
3. **Sf.5 / runtime.** Is Python/runtime its own Sf.5 or
   part of Sf.4 (binding_lib)?
4. **C8 ↔ Ag.X.** Add Ag.8 (API-faithfulness) or fold into
   another.
5. **Code-side rename** (deferred to polish pass per
   "uniformity eventually"): C1..C8 → Ag.X, inspect_input
   renames → Sf.X aggregates.
6. **Sf.X ↔ Ar.X alignment (Principle 2).** Renumber Sf so
   Sf.k is the surface of Ar.k.
7. ~~**Mutation matrix ↔ bad scenarios (Principle 3).**~~
   Doc half ✓ SSOT §5.1. Code half ✓ Task 1.5's
   `derive_scenarios`. Closed 2026-07-07.
8. **Tiny packaging coverage** — see
   [`design/tiny.md`](design/tiny.md) §7.5.
9. **Operational-taxonomy code sweep** — see §5 below
   ("Deferred code polish").

## 4. Structural in-flight

Larger design shifts. None active; awareness only.

- **One-time spec covering one scenario across both engines.**
  The current shape has two engines — tiny-based mutation
  (concrete trace per agreement) and canary-based enumeration
  (abstract trace across variants). Task 1.5 delivered the
  unified `Canary_scenario.scenario` shape used by both.
  What remains: making mutation record itself drive both
  sides symmetrically (today the tiny factory reads
  `recipe.mutation` but z3/llvm variants don't have a
  parallel).

- **Dual-view artifact index.** Artifact-centric mutation
  list, direct + inherited. Complement to the scenario-centric
  `tiny list`.

- **Iteration helpers over §1/§2/§3.** `canary_ssot.ml`
  exposing typed iterators — every artifact, every surface,
  every agreement. Useful for validators and coverage checks
  once we lean on them.

- **Alignment invariant as a runtime test.** Needs both
  `derive_scenarios` outputs and both index views. Assert
  they agree.

## 5. Deferred code polish

Not blocking; part of the post-stabilisation "uniformity
eventually" pass.

- **Task 3 — term-rename sweep** per SSOT §6.2 (rule → action,
  action_step → step, current `stage` → `artifact_status` /
  `lifecycle_state`). After Task 2.
- **Engine vocabulary alignment in code.** Add explicit
  *mutation engine* / *combinator engine* naming to
  `canary_project_tiny.ml` (combinator-side) and
  `canary/examples/tiny/scenarios/` (mutation-side; largely
  retired). See `backlog.md` #46.
- **Derive `related_artifacts` from `actions`** — currently
  hand-mapped in tiny entries; a `consumes/produces` helper
  on `rule` would let the hand field be dropped once
  verified against the current 15 values.

## 6. Done — pointers

- **§9.1 Migrate tiny scenario engine Python → OCaml**
  (Phases A / B / C / C.5 / C.4b / C.6 / D / E) — done by
  end of 2026-06. Chronicles in
  [`worklog_2026_06.md`](worklog/worklog_2026_06.md).
- **§9.3 Scenario remodel** (Task 1 / 1.5 / 1.6) — done by
  2026-07-08. Chronicle in
  [`worklog_2026_07.md`](worklog/worklog_2026_07.md).
- **§9.4 Re-do expectation** — hand-coded predicates
  eliminated for tiny via Task 1.6. Broader per-step
  contract framing tracked above in §2.
