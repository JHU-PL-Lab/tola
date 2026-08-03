# Canary Status

Rolling backlog for the canary framework. Absorbs the old
SSOT §8 (open reconciliation tasks) and §9 (strategic /
forward planning). Kept out of `design/ssot.md` per
2026-07-08 refactor — SSOT is truth (definitions), this file
is status.

**Operating principle (ssot-tiny-canary sync, 2026-07-20)**:
the current milestone is a complete tiny + SSOT that
sqlite/z3/llvm and the writeup can cite. Those three are
"second-tier" — flush from the tiny+SSOT+code trio once it
stabilizes; don't touch them until then. Cadence:
code-first, doc-synced — land a concrete code answer in
tiny, then update SSOT and tiny.md to reflect it in the
same commit. Modeling questions (Sf/Ar alignment, C8
wiring, expectation shape, ...) get resolved as side
effects of code decisions.

For tiny-scoped items see the wish-list in
[`design/tiny.md`](design/tiny.md) §7. For the after-tiny
research task see
[`design/bad_scenario_flavors.md`](design/bad_scenario_flavors.md).
Historical chronicles in [`worklog/`](worklog/).

## 1. Now

**tiny-full is a working mutation-agnostic project** driven by a
project-agnostic runner. `canary action tiny-full` enumerates the good+bad
space, assembles vendored artifact resources (no rebuild), and **canary
computes** detection + expectation + the fail-fast collapse — 20/20, via
`run_project_run` over a `project_run` spec. z3/llvm stay raw-script
(`run_project_multi`), untouched. The tiny trilogy + principle are design
(**ssot §4.2.5**); the full arc history is
[`worklog/worklog_2026_08.md`](worklog/worklog_2026_08.md).

**To-do, in order** (tiny adjustments first — sqlite not yet):

1. **Make tiny realistic — version + provision variety** (small tiny changes):
   - **two versions** — mimic dev/stable (a dev-only `tiny_scale` symbol, or a
     `tiny.map` `TINY_1.0`→`TINY_2.0` bump) so `build_id.channel` is *real*. The
     interesting point is the **deploy mismatch** (built @dev, run @stable) —
     *one config-chosen point* (`version = Subset`), **not** a global
     per-artifact cartesian; source-primary + the config pick the meaningful
     subset. On-ramp to per-edge version (§1b).
   - **provision variety** — provision selects **which build/fetch ACTIONS
     canary runs and observes**; it is *not* a pre-run shell. `materialize`
     places only what already exists:
     · **Vendored** — already built → `materialize` places the pre-built
       resource; canary only probes (a bad vendored lib = a bad *binary*).
     · **Built** — canary runs `build_lib` from `c/src` (observable: bad source
       → build fails / bad lib); `materialize` places only the *source*.
     · **Fetched** — canary runs a `fetch` action from a PM at run time (no
       pre-fetch).
     So the good lib gains a **Built** choice (not only Vendored), and build/
     fetch stay **runner_spec actions** (`provision_of_actions`/`store_actions`),
     not `pr_materialize`. Same split sqlite needs. The Built *mechanism* is
     done — guarded real `build_lib` (`tiny built-check`); wiring it into the
     enumeration needs the provision (+version) in `variant_id` so Built and
     Vendored cache separately ([`cache.md`](design/cache.md)).
2. **Tri-view command** — one table joining factory (spec) / tiny1 (verdict) /
   tiny-full (assignment) on the shared `Bs.N` key.
3. **sqlite `project_run`** — one runner, two projects; the provision→actions
   split from (1) carries straight over (sqlite is Built/Fetched, no vendoring).
   Then the distro × sys-PM × lang-PM packaging enumeration (largest piece).
4. Deferred **design** (§1b) · deferred **polish** (scenario names; tiny-full's
   `docs/canary` output volume).

## 1a. The tiny trilogy + enumeration state (design: ssot §4.2 / §4.2.5)

- **tiny-factory** — the machinery (`canary_tiny_scenario.ml` specs +
  `canary_tiny_workspace.ml` materializer/emitter/assembler) that *makes* every
  artifact variant as a resource + holds the tiny1 oracle.
- **tiny1** — the single-scenario projects, each a hand-written good/bad case =
  the ground-truth **oracle** (validates the tooling/checkers). `canary tiny run`.
- **tiny-full** — the *one* project (peer of sqlite/z3) that **declares** those
  vendored resources; **canary computes** detection/expectation/collapse
  (validates the algorithm/integration). `canary action tiny-full`. Its
  coverage cross-checks against tiny1; a real simple project is "no harder than
  tiny-full".

Full principle — mutation-agnostic runner, badness = a bad-quality version,
declare-vs-compute, the cross-check — is **ssot §4.2.5**.

**The arc is done** (2026-08-01 → 2026-08-03) — full phase-by-phase history
in [`worklog/worklog_2026_08.md`](worklog/worklog_2026_08.md). In one line
each:

- **P0** command-level peer + `action tiny-full` as a project (`b6ca255`,
  `4b003f3`).
- **P1** agnostic driver over an opaque tag (`3e1bc83`).
- **P2a** tag folded into the typed version — `build_id = {channel; quality}`,
  a bad artifact is `dev#Bs.1` (`b943b1a`).
- **P2b** agnostic expectation — `lower_expectation_agnostic` +
  `Expect_compat_derived`; tiny-full runs with **no oracle** (`5bcce8e`,
  `c96eb1f`).
- **P3** vendored resources + combinations — emit→assemble→run; `action
  tiny-full` **20/20** via assembly; `tiny assemble-combo` for the
  beyond-tiny1 multi-bad; canary computes the collapse (`94fa841` … `d627890`).
- **Convergence 1** `canary_project_tiny.ml` (project module + `project_run`
  interface, `ab4bcd4`); **2** `run_project_run` — the project-agnostic runner
  drives tiny-full via closures, z3/llvm untouched (`a620b15`).

**Enumeration state** (model: [ssot §4.2](design/ssot.md)). One abstract
product-then-filter algorithm (`action/canary_enumerate.ml`); a `config` sets
each axis to `Free`/`Subset`/`Full`. Axes wired: **provision**
(`Absent`/`Fetched`/`Built`/`Vendored`, coarse origin), **version**
(`build_id = {channel; quality}` — quality folds the mutation into the version
identity), **mutation**, and **mechanism/app-wiring** (the precise
`(artifact, ext)` identity, kept off the base `artifact_kind`). tiny pins
`channel=Dev` + provision `Vendored` today — to-do #1 makes it exercise
Dev/Stable + Built/Fetched. Still open (→ §1b below): fold `(artifact, ext)`
into base `artifact_kind`; provision sub-structure (PM × distro); Headers
provision; versioning unification ([versioning.md](design/versioning.md)); the
§5 rewrite ("bad scenario" -> "scenario with a bad *result*").

## 1b. Deferred design — one cluster (enumeration / graph / packaging)

Not started; interrelated — pick up together when the tiny axes (to-do #1)
force them. Home docs carry the detail.

- **Instance graph + per-edge version + versioning** — the deploy mismatch
  (build-version != run-version) is a per-edge property; the graph that
  generates it **already exists** (`artifact_node` + `make_action_graph`), so
  the work is a *merge* into one instance type (`artifact_node` + `ext` + typed
  `version`), not a new graph — folded with the versioning unification.
  [`enumeration_graph.md`](design/enumeration_graph.md),
  [`versioning.md`](design/versioning.md).
- **Packaging / provision sub-structure** — provision `Fetched` (canary fetches
  from a PM at run time) over PM (apt/opam/pip/brew) x distro (local / GH CI);
  cmake Staged install uses a customized prefix. (to-do #1 starts this in tiny.)
- **Headers provision** — `Headers` payload + `Build_headers -> Built`.
- **Legacy sweep** — `artifact` + `step_body` + `cmdline` + base
  `run_step`/`mk_system_dep_steps` + `canary_toolchain` dead helpers.
- **§5 principle-rewrite** — "bad scenario" -> "scenario with a bad *result*"
  (result is a coordinate, not a category).

## 2. Near-term

Ordered rough priority.

- **`design/tiny.md` is mostly stale — audit to-do.** Its §7 wish-list
  (picking-order table, empty-cell counts, §7.1/§7.2/§7.4 framing) predates the
  vendored-resource model + the generic runner and no longer matches how
  tiny-full works. Audit against ssot §4.2.5 + `worklog_2026_08.md`; rewrite the
  still-relevant bits or retire it. (Do before leaning on tiny.md again.)

- **`new_project.md` revisit before onboarding a new project.**
  §2 mechanics + §2.5 three-level guidance were last touched
  in the derived-vs-hardcoded pass 2026-07-20; they still
  describe the current `runner_spec` shape but might want
  another look against any upgrades (Task 2 recipe interface,
  package_locator, store_config from §3) before actually
  picking a Tier-1/Tier-2 target. Not a blocker for other
  work; just a checkpoint when someone wants to add a project.

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

- **Task 2 — recipe / mutation integration.** *Deferred /
  rescoped 2026-07-20.* Would extract project-hookable
  recipe interface so z3/llvm/sqlite can supply their own.
  Scoping conversation (2026-07-17) concluded ~230 LOC for
  ~28 LOC of hand-coded predicates — ROI marginal until (a)
  more projects use the pattern (PyTorch, cvc5, ...), (b)
  §7.2 lands and tiny's recipe machinery is concrete, (c)
  expectation/contract model settles. sqlite/z3/llvm are
  "second-tier" per the ssot-tiny-canary sync line; revisit
  once §7.2 lands. Fuller writeup at
  [`design/tiny.md §7.8`](design/tiny.md#78-task-2--recipemutation-integration-project-hookable-factory).

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

0. ~~**SSOT lacks `runner_spec`** — done 2026-07-10.~~
   [SSOT §6.6](design/ssot.md#66-runner_spec--the-code-side-project-handoff)
   documents the type, its composition with §6.5's action
   catalogue, `derive_steps`, the four consuming backends,
   and the multi-variant pattern (tiny factory + z3/llvm
   hand-coded variants).

1. **Ar.0..Ar.3 vs code's 5 kinds.** Decide if `Headers`
   gets its own Ar id or stays implicit under Ar.1.
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

- **First-class `artifact_details` (parked, not enumeration-related).**
  `base/canary_store.ml` has two related-but-distinct artifact axes:
  `provision` (origin — where it came FROM / blame; fixed) and
  `artifact_status` + `location` (whereabouts — where it is NOW; moves).
  Plan is a first-class `artifact_details` record `{ provision; status;
  location; … }` so an artifact can be blamed to its origin while its
  state is tracked. Deferred until a consumer needs provenance/blame
  tracking; intent captured in the `artifact_status` comment. `provision`
  is wired now (enumeration); `artifact_status` stays unused until then.

- ~~**Task 3 — term-rename sweep**~~ ✅ shipped 2026-07-21
  (`rule → action`, `action_step → step`, `stage → artifact_status`,
  plus `project_spec → runner_spec` and `action_rule → action_graph`).
  Chronicle in [`worklog_2026_07.md`](worklog/worklog_2026_07.md).
- **Engine vocabulary alignment in code.** Add explicit
  *mutation engine* / *combinator engine* naming to
  `canary_project_tiny.ml` (combinator-side) and
  `canary/examples/tiny/scenarios/` (mutation-side; largely
  retired). See `backlog.md` #46.
- ~~**Derive `related_artifacts` from `actions`**~~ — done
  2026-07-10; field removed, getter derives from
  `scenario.actions`. See [`design/tiny.md §7.9`](design/tiny.md#79-derive-related_artifacts-from-actions-done-2026-07-10).

- **Sync `scenario.actions` with canary runtime.** Today
  `scenario.actions` is metadata (per parent Sc.N); canary's
  factory always emits the full spec regardless. Future
  task: make the factory respect `scenario.actions` and only
  emit steps for the listed rules. Would let Bs.N runs skip
  the language chain the mutation doesn't touch (e.g.
  Bs.10's OCaml-only mutation wouldn't run the Python
  probe). Non-trivial — touches `derive_steps` in
  `canary_step_builder`; couples with Task 2 (recipe
  interface), so best done as a Task 2 follow-up.
