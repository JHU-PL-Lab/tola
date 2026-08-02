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

*Nothing in flight. Picking order (2026-07-20 rescope):*
*milestone is a complete tiny + SSOT that other work cites*
*("ssot-tiny-canary sync line"; sqlite/z3/llvm + writeup are*
*second-tier). Cadence: code-first, doc-synced — each*
*wish-list phase commit carries the SSOT/tiny.md sync bits*
*it opens up. Task 2 project abstraction (tiny.md §7.8)*
*deferred; ROI marginal until §7.2 lands and more projects*
*need the pattern.*

*§7.2 Phases 1-4 shipped 2026-07-20; chronicle in*
*[worklog_2026_07.md](worklog/worklog_2026_07.md). Final*
*state: `all_scenario_specs = 15 hand + 6 derived = 21`,*
*coverage 11/20 filled, `tiny run` 20/21 PASS,*
*artifact-test 98/98.*

*Next candidate: §7.1 (fill remaining 9 empty cells —*
*needs Drop_c_symbol / Drop_python_attr / App primitives*
*+ c4 wiring for OCaml) or §7.4 (Sc.3-Sc.6 wiring).*

## 1a. tiny1 / tiny-full — the validation architecture (2026-07-31)

Direction for **driving the runner from the algorithm**. Two tiers of
tiny; trust flows tooling → algorithm → real projects. **Both should be
algorithm-derived** (a human can't be relied on to derive scenarios per
project); **scenario coverage** is the metric for both.

- **tiny1** (today = the hand-written tiny-factory) — many tiny projects,
  each **one** concrete scenario: one bad artifact with **good precedents**
  (the steps before it succeed; "bad lib use" ⇒ fetch-source + build-lib
  were fine). Validates the **tooling / checkers**. Should *also* be
  algorithm-derived from the ssot ideas — but **postponed until after
  tiny-full** (hand-written is fine as the interim ground truth).
- **tiny-full** (new) — **one** general-project canary spec with multiple
  choices (provision × version; the **mechanism choice IS provision** over
  the distinct binding artifacts — cext Built + ctypes Absent, etc.).
  Behaves as a general project; the **runner iterates the algorithm's
  enumerated points**. Validates the **algorithm / skeleton / integration**.
  - Has scenarios **beyond tiny1** — real combinations (bad lib *and* bad
    binding), which in tiny1 are separate projects.
  - Under a **fail-fast canary config, the first checkable error stops the
    trace**: a detectable bad lib subsumes a downstream bad binding/app —
    they **collapse into one scenario**. So distinct observable scenarios
    are keyed by the **earliest checkable failure**; validating that
    collapse (and that good precedents pass) is tiny-full's job.
  - Trusted because its coverage **cross-checks against tiny1**.
- A **real simple project** reuses tiny-full's machinery — "no harder than
  tiny-full" **for canary-checkable errors** (a *project-internal* error is
  outside that).

**New code = an algorithm-driven materializer**: enumerated point (per-
artifact provision × version) → build that workspace → run the probes with
the fail-fast config, reusing `canary_tiny_workspace`. Wired from the
algorithm, not from a hand-written spec.

**Plan (confirmed):** tiny-full first (view, then runner); tiny1 derivation
after; packaging deferred but **must** come back (the provision axis needs
tiny published/fetched — until then provision is `Built`/`Absent` only).
**First step — tiny-full v1:** the algorithm enumerates tiny's full artifact
set over provision {Absent, Built} × version {1.0, 2.0} (tiny already has
the `TINY_1.0`/`TINY_2.0` map + all three mechanisms); view first, then
drive the runner with fail-fast + coverage.

**tiny-full v1 (view) — shipped** (`canary tiny full`), and it revealed the
taming the enumeration still needs:
- raw cartesian = **2048** scenarios (with duplicates: version was ranged
  *per-artifact*, so `absent@dev`/`absent@stable` duplicated and present
  artifacts got spurious version *mismatches*). → **fixed**: version is
  whole-scenario for the positive space (2048 → **64**).
- **app→binding dependency added** to `assignment_ok` (an app with no
  binding is degenerate; general improvement, not tiny-specific): 64 → **58**.
- 64 → **58** (app→binding dependency in `assignment_ok`).
- **presence was the wrong axis** (2026-08-01): a project **ships its whole
  declared set** — the binding list is a **fixed set of (lang, mechanism)
  pairs** (only some combos exist; tiny: 1 OCaml + 2 Python), and presence
  is **not** a choice. So the 2048→58 presence enumeration was a dead end.
- **but "2" is an over-collapse** (2026-08-01): **version is per dependency
  *edge*, create (build) vs use (run) apart** (ssot §4.2.4) — an OCaml
  binding ranges header-version × lib-version = 4; an app ranges
  build-lib-version × run-lib-version = 4 (the deploy mismatch). The count
  is a **product over consumption edges**, and those mismatch points are
  canary's *purpose*, not "bad". So the real tiny-full breadth is the
  per-edge version product, *not* 2.
  - **Model (2026-08-01, corrected):** an artifact **instance** is one
    concrete thing = its `placement` (`provision/location × version` +
    metadata) — **`placement` is correct**, an artifact is *not* a set of
    instances. The cartesian **choices** for an artifact (version × store
    **location** — build tree / staged install / PM) are carried by its
    **artifact group**; the enumeration picks one instance per group.
    **Provision folds into location** (build⇒built, PM⇒fetched,
    staged⇒installed). Using an instance at a different location needs a
    **different command** = the `runner_spec`'s job. See ssot §4.2.4.
  - **The instance graph already exists** (2026-08-01 finding):
    `Canary_basic.artifact_node` (`a_location` + `built_from` = Build edge +
    `runtime_dep` = Run edge) + `Canary_action.make_action_graph` already
    build it and already generate the deploy mismatch (`Build_app` pairs each
    binding with *every* runtime lib). So `canary_enumerate` was about to
    **reimplement** it. The work is a **merge**, not a new graph: one
    `instance` = `artifact_node` + `ext` (mechanism/wiring) + a **typed**
    version (today in `a_name`); the enumeration `config`/levels sit on top.
    Edge ≈ action (built_from/runtime_dep are action-produced) — a known,
    accepted smell. Design note:
    [`design/enumeration_graph.md`](design/enumeration_graph.md). First cut:
    full-graph shape, minimal scope (one version, no app, chain
    source→lib→binding), extend `artifact_node` not a parallel type.
  - **cmake constraint (Staged location):** installing a cmake lib must use
    a **customized install prefix**, never the global system path (avoid
    depending on / polluting the host).

## 1b. Scenario enumeration — implementation state

Model: [`design/ssot.md` §4.2 / §4.2.1](design/ssot.md) (principle —
one abstract algorithm; per-axis level `Free`/`Subset`/`Full`; a config
per use). This tracks what's actually wired.

- **Algorithm module** — `action/canary_enumerate.ml`: pure
  product-then-filter, polymorphic in the mutation. Ranges over `artifact`
  (= `Canary_basic.artifact_kind`, re-exported — no separate `slot` type);
  `provision` (`Absent`/`Fetched`/`Built`/`Vendored`), `enumerate`,
  `assignment_ok` (lib `Built`⇒source; provided binding⇒lib),
  `provision_of_actions`. (Named "engine" in early commits — prefer
  "enumeration algorithm".)
- **Config object implemented** (`type 'a level = Free | Subset of _ |
  Full`; `type 'm config = { provision; version; mutation }`; `run_config
  ~artifacts ~all_provisions ~all_versions ~all_mutations cfg`).
  `tiny_slice` (provision `Free`,
  mutation `Full`) and `general_slice` (provision `Full`, mutation `Free`)
  are now thin wrappers over `run_config`, byte-identical to before (a
  layer test pins the agreement). Only two axes are ranged so far.
- **Axes wired:** provision ✓ (coarse origin only), version ✓ (as
  channel), mutation ✓. **Remaining axes + their code gaps** (decisions in
  ssot §4.2.3):
  - **mechanism / app-wiring — identity structure shipped (interim).**
    The enumeration now keys on a precise identity — the pair
    `(artifact, artifact_ext)` (`Canary_enumerate.artifact_id`): `artifact`
    is the coarse `Canary_basic.artifact_kind` (untouched, so the ~200
    mechanism-agnostic sites — diagram 61, actions, project specs — are
    unaffected), and `artifact_ext` refines a binding by its
    `Canary_mechanism.mechanism` and an app by its `app_wiring`
    (`Direct | Via_helper`). Smart constructors `a_source`/`a_lib`/
    `a_binding lang mech`/`a_app wiring` + `kind_of` projection.
    `artifact_id` is a record `{ kind; ext }`; `provision_of_actions`
    dispatches per binding *instance* (static ⇒ Build_binding; dynamic ⇒
    pure-source present).
  - **tiny factory — done (engine projection).** `canary tiny engine` now
    renders tiny's **full artifact set** (7): source, lib,
    `binding:ocaml:cstubs`, `binding:python:cext`, `binding:python:ctypes`,
    `app:direct`, `app:via_helper`. Each mutation maps to its **precise**
    (lang × mechanism) artifact, read off the spec's mutated files
    (`ocaml/`→cstubs, `python_cext/`→cext, `python_ctypes/`→ctypes); a spec
    touching both Python layers (Bs.11/Bs.12) yields two points (cext +
    ctypes) — 20 specs → 22 points. Both app wirings are distinct artifacts
    in the positive (no longer collapsed). tiny's *running* result already
    exercised cext/ctypes/both apps via the `expected` tables — the engine
    view now matches it.
  - **Cross-check (engine view ↔ factory) — done.** The engine projection
    is *derived* from `all_scenario_specs` but is a separate code path from
    the runner (`tiny run`). Startup assertions in `canary_tiny_scenario`
    (matching the existing assertion pattern) enforce that the derivation
    stays faithful: every mutation-carrying spec with a pipeline target
    appears in `engine_mutations` (no drop), every engine point traces to a
    real spec (no phantom), and a spec mutating both Python layers yields
    the cext *and* ctypes points. Runs on every tiny command.
  - **Still to do:** general projects still render one binding per lang at
    the default mechanism (fine — they have one). And **the merge**: fold
    `(artifact, artifact_ext)` into an enriched `artifact_kind` and migrate
    the ~200 sites (diagram, ~61, last) — per the 2026-07-30 decision. The
    deeper convergence (drive the *runner* from the algorithm) is deferred;
    for tiny it's redundant (they agree, now enforced) — the payoff is
    *generating* provision/version scenarios general projects lack.
  - **provision sub-structure** — provision must carry PM (apt/opam/pip/
    brew) + distro (one local, many on GH CI); the provision level ranges
    over `(PM × distro)` combos.
  - **Headers provision** — Headers is a real artifact with its own
    provision (standalone / co-package / `Built` via `Build_headers`);
    `provision_of_actions` must handle `Build_headers → Built` (today it
    returns `Absent` for Headers).
  The interim `(artifact, artifact_ext)` avoids the base `artifact_kind`
  refactor (~206 `Binding` + ~30 `App` sites, all mechanism-agnostic) until
  the identity is validated. See ssot §4.2.3.
- **Rendered through the algorithm (demonstration, not replacement):**
  `canary tiny engine` renders tiny's mutation axis; `canary scenarios
  <p> --engine` renders a general project's provision axis and checks
  each variant is a valid, in-slice assignment. The hand-written
  enumerations (`canary_scenario.good_scenarios`, tiny's
  `all_scenario_specs`, per-project variant lists) still *own* the
  concrete detail (recipe / `violates` / `expected`).
- **To-do:** (1) add the version / mechanism / app-wiring axes (each a
  new field on `config` + universe arg to `run_config`); (2) drive the
  hand-written enumerations *from* the algorithm and fold
  `canary_enumerate` into `canary_scenario.ml`.

  - **version axis — shipped.** The enumeration ranges over the release
    **channel** `Canary_basic.channel` (`Dev | Stable`; presets
    `single_channel` = Free, `two_channels` = Subset/Full). The assignment
    cell is a `placement = { provision; version }` (per-artifact; `version`
    here holds the channel); `config` has a `version` field; source-primary
    is a filter (`Built lib ⇒ lib.version = source.version`). Cross-artifact
    mismatch (lib@Dev / binding@Stable) is a valid assignment — the z3/llvm
    demo as an algorithm instance (test `enumerate.version_axis`). Renders
    show `@dev`/`@stable`; a variant picks one version (actions don't
    encode it) — per-artifact mismatch is a *capability* the hand-written
    variants don't yet exercise. **Next axis:** mechanism-live / app-wiring.
  - **channel vs concrete version split (done).** `Canary_basic.version`
    (`Dev | Stable`) → renamed **`channel`** (the coarse role the
    enumeration ranges over; `single_channel`/`two_channels`/
    `channel_suffix`). New concrete **`Canary_basic.version = { channel;
    id : string }`** (id = commit hash for Dev, tag/release for Stable) —
    the typed replacement for string version/commit on a concrete
    artifact.
  - **Versioning unification → own tracker.** The full unification (typed
    `version` as *the* artifact identity across enumeration, source_repo,
    and cache key) needs a global design + its own tests; tracked in
    [`design/versioning.md`](design/versioning.md). **Decision (2026-07-30):**
    do the typed-version enumeration for the *simple* projects first (tiny,
    sqlite, Pattern-A ssl/cairo/zarith), leaving z3/llvm on their legacy
    string machinery (~91 interpolation sites untouched) until later.

- **Reframe parked (§5 principle-rewrite):** "Bad Scenarios" → **scenario
  with a bad result**. A scenario is not inherently bad; the enumeration
  is *uniform* (one scenario space over the axes), and good/bad is the
  **result** of a scenario — a separate outcome/oracle coordinate, not a
  scenario category. tiny's role is **result coverage**: confirm the
  checking + tooling produce the expected result per scenario (tiny's
  `expected` table already *is* that per-checking-point oracle; cf.
  `canary_detect` = raw outcome vs the expected oracle). Keep in mind
  when §5 gets the same principle-rewrite §4.2 received.

## 1c. Paused — pick-up list (enumeration / graph work)

One place to resume from. Each has a home doc with the detail.

- **Grow the tiny-full run** — renders + runs the positive (both app wirings
  PASS) **and mutations** (one per pipeline artifact: source / lib / ocaml
  cstubs / python binding, fail-fast, **4/4 detected** + coverage line).
  Reuses `run_tiny_scenario`. Next: **combinations + true fail-fast collapse**
  (multi-mutation workspaces — a bad lib subsumes a bad binding/app into one
  scenario), then **per-edge version** (the mismatch). §1a, ssot §4.2.4.
- **Per-edge version model** — `placement` is per-artifact; the deploy
  mismatch (build vs run lib) needs the graph edge to carry the consumed
  instance. **The graph already exists** (`artifact_node` + `make_action_graph`)
  — the work is a *merge*, not a new graph. ssot §4.2.4,
  [`design/enumeration_graph.md`](design/enumeration_graph.md).
- **The merge** (shared base defs) — one `artifact_info` (kind+ext+version+
  location; move `artifact_ext` to base) + `artifact_node` (info+edges);
  reconcile `step.deps` (string) with typed edges. Do when shapes confirmed,
  then one ssot section + CLAUDE.md note. `enumeration_graph.md` §6.
- **Legacy sweep (cascade)** — `artifact` + `step_body` + `cmdline` + base
  `run_step`/`mk_system_dep_steps` + `canary_toolchain` dead verify helpers.
  (`artifact_op`, dead base `runner_spec` already gone, `9f656dd`.)
  `enumeration_graph.md` §6.
- **Headers static/built flavor** — `Headers` payload (like `Binding of
  (lang×mechanism)`) + its provision (`Build_headers` → Built). ssot §4.2.4.
- **Provider axis + packaging** — provision `Built`/`Fetched` needs tiny
  published/fetched; cmake Staged install must use a **customized prefix**,
  not the global system path. §1a.
- **Provision sub-structure** — PM (apt/opam/pip/brew) + distro (local vs
  GH CI). ssot §4.2.3, §1b.
- **Versioning unification** — typed `version` across enumeration/store/cache,
  simple-projects-first. [`design/versioning.md`](design/versioning.md).
- **§5 principle-rewrite** — "bad scenario" → "scenario with a bad result"
  (see the meta note just above).

## 2. Near-term

Ordered rough priority.

- **Tiny wish-list items** — see
  [`design/tiny.md`](design/tiny.md) §7 (picking-order table
  at the top). §7.2 shipped 2026-07-20; active pickup is
  §7.1 (fill 9 remaining empty derived cells — three
  blocker primitives to land). §7.4 (Sc.3-Sc.6) overlaps
  §7.1.

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
