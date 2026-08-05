# Canary Status

Rolling backlog for the canary framework. Absorbs the old
SSOT §8 (open reconciliation tasks) and §9 (strategic /
forward planning). Kept out of `design/ssot.md` per
2026-07-08 refactor — SSOT is truth (definitions), this file
is status. Completed work is FLUSHED to
[`worklog/`](worklog/) (last flush 2026-08-05); only open
items + just-enough context live here.

**Operating principle** (updated 2026-08-05; supersedes the
2026-07-20 "tiny+SSOT first, sqlite/z3/llvm second-tier"
framing — sqlite is now a first-class generic project): the
current milestone is the **faithful scenario combination**
(§1). Cadence unchanged: code-first, doc-synced — land a
concrete code answer, update SSOT/docs in the same commit;
modeling questions get resolved as side effects of code
decisions.

For tiny-scoped items see the wish-list in
[`design/tiny.md`](design/tiny.md) §7 (stale — audit queued,
§2). For the after-tiny research task see
[`design/bad_scenario_flavors.md`](design/bad_scenario_flavors.md).

## 1. Now

**Current state (2026-08-05).** Two projects run through the fully generic
path: `pr_spec` (ONE data table: artifact × (provision × versions)) →
`scenarios_of ?policy` (the general enumeration; `--thin` = a runner policy)
→ per-scenario `pr_runner_spec = realize ∘ dispatch` (pure `scenario_case`
data + command templates) → `derive_steps` → run, with scenario identity/
dedup (`scenario_dir_of`; Fetched is version-ambient), per-scenario verdicts
(`scenarios.tsv`), xfail surfaced end-to-end, and pre/post views (`spec`,
`spec --by-artifact`, `status` per-scenario, `--json`).

- **tiny-full**: 6 spec-derived scenarios = lib {V:S, B:S, B:D} × ocaml
  binding {V:S, V:D}. The two binding@dev-over-stable-lib scenarios are the
  **forward API mismatch** (dev consumer of `tiny_scale`), c1-predicted
  agnostically → detected xfail; binding@dev × built-dev-lib green. The dev
  binding is DECLARED a forward probe (`pr_mismatch_probes` design-intent
  table, 2026-08-05); `spec` marks the designed scenarios
  `[forward-mismatch probe]`, gated by the computed direction
  (`mismatch_direction_of`: consumer channel vs provider channel).
- **sqlite**: 3 scenarios = lib {F, B:3.45.1, B:3.46.1}. Built scenarios
  probe OVER the built lib with the runtime version ASSERTED; built-dev is a
  real verified run-lib ≠ build-lib deploy scenario. Python's runtime sqlite
  is **Ambient** (uv python statically bundles its own — observed, not
  asserted); OCaml's is **Independent** (repointed + asserted).
- **tiny1** (`canary tiny run`): the standalone mutation ORACLE; factory
  coverage 12/24 — the 12 undetected are watchlist-blind (c5/c6/abi) and
  need richer *inspectors* (§B), not plumbing.
- **z3/llvm**: still raw-script (`run_project_multi`), 2 variants each with
  contract-bound expectations. Migration = A5.

Trilogy + principle: **ssot §4.2.5**; arc history:
[`worklog/worklog_2026_08.md`](worklog/worklog_2026_08.md).

**MILESTONE — enough projects really run as z3/llvm did, with a FAITHFUL
scenario combination** (derived from the declared spec; the run's scenario
set == what the algorithm + graph say the project's worlds are).
- **(a) combination derived from the spec — DONE** for sqlite + tiny-full
  (no hand-built scenario list can exist: `pr_enumerate` is retired).
- **(b) real mismatch/failure scenarios — HALF DONE.** Shipped: sqlite's
  verified deploy scenario (runner-realized repoint) + tiny-full's
  enumerated, c1-detected forward mismatch (flat form: binding-version ≠
  lib-version). Still open: TWO lib instances in ONE scenario (build-lib ≠
  run-lib proper) needs `close_deps Independent` wired into `scenarios_of`
  — the node-graph half (§A).
- **(c) z3/llvm on the generic path — NOT STARTED** (= A5).

## A. Convergence — one enumeration algorithm, one project spec

Done steps (A1–A4, A3b, A6, A8, A9-step-1, the spec/policy split,
per-provision versions, `pr_enumerate` retirement, node-graph first cut
M1–M3 + `close_deps`, `make_action_graph` as forward engine, layering) are
chronicled in [`worklog_2026_08.md`](worklog/worklog_2026_08.md). Settled
design lives in
[`design/dynamic_enumeration.md`](design/dynamic_enumeration.md) (graph =
mid-layer VIEW, `derive_steps` = engine; build edges grammatical, runtime
edges resolved via `dep_mode`). Open:

- **A5 — wire z3/llvm onto `project_run`** (retire `run_project_multi` +
  `print_spec_variants`). The forcing function for two missing
  abstractions: (i) the **location sub-axis** — one z3 variant probes the
  lib at three locations (build-tree / staged / apt), a dimension the flat
  placement doesn't model; (ii) the **`dep_mode` value source** — who
  declares "this probe runs over lib@Y while built against lib@X"
  (`close_deps Independent`'s owner). Both land naturally with A9-step-2.
  ssl/zarith/cairo follow once the shape exists.
  **Execution plan (2026-08-05; user: zero-cache rebuild cost is acceptable
  — and z3/llvm's guarded external build trees mean scenario-id changes
  don't force full rebuilds anyway). z3 first, llvm after the shape
  settles. Phases, each shippable:**
  1. ~~*Declared spec, no behavior change*~~ — **DONE 2026-08-05.**
     `z3_spec` ps_universe (`canary_project_z3.ml`): source
     Fetched@{Stable,Dev}, lib Fetched@Stable | Built@Dev, python wheel
     Fetched@Stable (constant row). Enumerates to THREE assignments →
     exactly the current 2 variants as *scenarios*: source-primary prunes
     (source@Stable × lib Built@Dev); the two all-Fetched assignments
     collapse under the Fetched-ambient identity rule (`scenario_dir_of`)
     into ONE stable world. Pinned by `z3.spec_enumerates_current_variants`
     in NEW `canary_projects_test.ml` (projects-layer pins, appended to
     `canary project-test` via `run_tests ~extra` — the pure suite sits
     below `canary_projects` and can't see live specs). Two findings:
     (a) the **OCaml binding is NOT in the enumerated universe** — its
     provision follows the chain (Built@Dev dev / opam-fetched stable),
     and the flat product can't express "follows the built chain": either
     single option is wrong for one chain, both options mint the 2 mixed
     mismatch worlds. It joins the universe with graph-structural version
     propagation (§A below) — confirming A5 as that work's forcing
     function; until then it rides inside the realization (phase 2).
     (b) plan said "filter yields exactly 2" — actually 3 assignments,
     2 scenario identities; the ambient dedup is load-bearing, and the
     stable-first universe order keeps both surviving representatives
     channel-coherent (baseline = all-Fetched chain, as sqlite).
  2. *dispatch/realize*: `scenario_case = Dev_chain | Stable_chain`;
     `realize` = the existing `mk_runner_spec ~source:…` (the whole raw
     spec becomes the realization — command churn ~zero); `z3_run :
     project_run` (+ providers, + mismatch-probe roles for the
     stable-wheel demo); `action z3` → `run_project_run`.
  3. *Locations stay INSIDE the realization* (3 probe_lib steps per
     scenario, as today) — the location sub-axis is deliberately NOT
     modeled here; it's A9-step-2's acceptance test.
  4. *Expectations unchanged* (contract-bound `lower_expectation` in the
     realization; A7 comes AFTER) — verify the stable compat-failure demos
     surface as xfail in `status`/`spec`.
  5. *llvm same shape*; then retire `run_project_multi` +
     `print_spec_variants` (ssl/zarith/cairo last).
  **A5↔A7 order settled: A5 first** — migration needs no expectation
  change (the runner consumes any expectation closure; Expect_compat_
  failure already maps to xfail), and A7 is best done once all three
  expectation styles sit on ONE runner. *Related finding
  (2026-08-05)*: an **Ambient** runtime edge makes a step
  SCENARIO-INVARIANT — sqlite's python probe/inspect run identically in
  all 3 scenarios (placement F:stable + bundled lib never vary with the
  lib axis); once `dep_mode` is declared per edge, the runner can
  share/dedup such steps across scenarios (the step-level analogue of the
  Fetched whole-scenario dedup).
- **A7 — unify the 3-way expectation model** (tiny-full derived-agnostic /
  z3-llvm contract-bound / ssl + sqlite's inline `log_grep` hand-written) →
  derived, with declared contracts canary can *report* as firings (§1c #1;
  couples with §2 "per-step contract outcome").
- **A9 step 2 — dispatch as DECLARATION** (the action-variant table).
  Step 1 (the dispatch/realization split; pure `scenario_case` data +
  general coordinate reads) shipped 2026-08-05. Remaining: replace the
  per-project `dispatch`/`realize` CODE with a declared
  (action × placement-pattern) → (template + params) TABLE over shared
  command templates (finishes TODO #18; absorbs the channel→realization
  dialects — `sqlite_amalg` URLs, tiny's `-DTINY_DEV`, z3's `ref_` — into
  declared rows; makes `spec` able to show per-scenario commands without
  executing). Design against z3's complexity (A5), not sqlite's simplicity;
  `Raw` escape hatch required. HELD for now per user (affects the action
  verb design).
- **Node-graph enumeration — PARKED until A5 needs it.** End state: ONE
  engine, `pr_spec → enumerate → node graph → run`, where a flat
  `assignment` is the degenerate node graph (one instance per kind). The
  fold is a deliberate design (not incremental): a flat assignment cannot
  hold two instances of one kind (the deploy mismatch); App identity
  carries no lang (ssot §4.2.3) so its `Build_app {lang}` action needs a
  design; Fetched location breadth (`pm_info`) + Contained/bundle provision
  are new concepts. `close_deps`/`node_of_assignment` remain test-only
  machinery until then.
- **Graph-structural version propagation.** The per-provision version axis
  killed the worst over-generation, but version *propagation* along build
  edges (`source@v → lib@v → binding@v`; cross-version pairing ONLY on a
  declared mismatch edge) is still the graph work. Until then a general
  project's version axes are per-artifact labels.
- **Merge cleanup** (rescued from the retired `enumeration_graph.md`):
  - reconcile `step.deps : string list` with the typed
    `built_from`/`runtime_dep` node graph — ONE dependency relation, not
    two. (This is also the real fix for the diagram connectivity invariant,
    muted by default since 2026-08-04 — `CANARY_DIAGRAM_CONN=1` re-enables;
    it fails for all four projects; runs are sound, the picture
    under-connects.)
  - legacy artifact-vocab sweep — `artifact` + `step_body` + `cmdline` +
    base `run_step`/`mk_system_dep_steps` + `canary_toolchain` dead verify
    helpers.
  - the `(kind × ext)` → enriched-`artifact_kind` fold (~200 coarse-kind
    matches, diagram ~61) — decoupled; the node merge does NOT need it.
- **Combinations (multi-bad) stay hand-built** — `tiny_full_combinations`
  is tiny1/factory machinery since the flavor-1 decoupling; wiring them as
  multi-mutation points is a curated-chain policy, not general-run work.

## B. Coverage — make canary detect more

- **Richer agnostic inspectors** (the lever for tiny1's 12/24 → more): c5
  symbol-version, c6 type, abi/soname wired into the agnostic derivation.
  The 12 undetected fail *unexpectedly* because the watchlists can't
  predict them.
- **Version deploy-mismatch, backward half** (forward half shipped
  2026-08-05 — worklog): a stable consumer @ newer incompatible lib
  (soname/symver, `Bs.4`/`Bs.3` → c4/c5). Broad = missing *and* added
  symbols → per-version required-symbol watchlists (like z3/llvm). Design +
  build together.
- **Fetched provision for tiny** — canary fetches from a PM at run time;
  the one provision tiny still lacks (Built + Vendored + Dev/Stable done).
- **Watchlist ROLES: expected-present vs expected-missing** (user, 2026-08-05).
  sqlite's binding-lag markers currently ride the expected-present watchlist,
  so status shows `✓ ⚠ watchlist MISSING …`; it SHOULD be an `xfail`-style
  mark (expected absence, confirmed). Needs the role declared — an
  `expect_missing` list through `inspect_python.py` → JSON
  (`expected_missing: confirmed|violated`) → status marks confirmed lag as
  xfail and a REAPPEARED lag name as ✗ (binding caught up; declaration
  stale). A blanket "missing→xfail" is wrong (tiny's watchlists are
  expected-PRESENT; missing there = drift, must stay alarming). This is the
  seed of the c7/c8 lag contract (A7-adjacent).

## C. Real-project breadth (sqlite)

- **Binding COMPILED against the built lib** — a different declared
  scenario from today's honest deploy mismatch (opam binding is compiled
  against the system lib by design; a build-against-built variant means a
  source build of the binding — heavier, likely with the action-variant
  table).
- **sqlite API-mismatch feasibility (measured 2026-08-05).** `nm` diff of
  the two built amalgamations: **3.45.1 ↔ 3.46.1 export IDENTICAL symbol
  sets** (zero added, zero removed) — so with the current version pair
  neither mismatch direction is expressible at the symbol level (the
  built-dev scenario is correctly a pure deploy-repoint demo, all green).
  - **Forward IS addable with a real pair**: `sqlite3_get_clientdata`/
    `set_clientdata` were added in 3.44.0 (present in our 3.45.1 build) —
    declare an older Built version (e.g. 3.43.x amalgamation) on the lib
    axis + a dev CONSUMER calling `get_clientdata` (a C-level probe app;
    the opam binding doesn't wrap it and Python stdlib can't) → fails over
    3.43, passes over 3.45+; predictable via a required-symbol watchlist.
  - **Backward is NOT available from upstream** — sqlite's compatibility
    promise means no C API is ever removed (the empty "removed" diff is
    the promise, measured). A synthetic removal would be a mutation =
    tiny's role. Honest division: tiny designs breaks in both directions;
    a real project contributes only the breaks it actually has (z3/llvm:
    real removals/renames; sqlite: additive-only ⇒ forward only).
- **distro × sys-PM × lang-PM** packaging enumeration (couples with §1b).

## D. Deferred design cluster

= §1b (instance graph / per-edge version / versioning / packaging / headers
provision / §5 rewrite). Pick up when B/C force it.

## E. Polish

- Tri-view command (factory / tiny1 / tiny-full on the `Bs.N` key).
- Factory comment sweep (resource → cached artifact in
  `canary_tiny_scenario.ml`, minding the legit `Vendored` *provision*).
- Full-lazy `detect_pm` (skip entirely for `spec`/`paths`/`graph` — needs
  deferring runner_spec construction; §1c #2).
- Wire the `latest` channel (§1c #3).
- Scenario names + `docs/canary` output volume.
- **Terminology sweep: `variant_*` code identifiers → `scenario_*`**
  (display unified 2026-08-05; the id rename touches cache/filename keys —
  one deliberate pass, not ad hoc).
- **"scenario" overload vs the abstract senses** (`Sc.N` patterns, coverage
  *stages*; the `canary scenarios` CLI shows stages with a stale count) —
  audit + T0/T1/T2 options + open questions in
  [`design/scenario_terms.md`](design/scenario_terms.md). OPEN — no
  decision; do T2 together with F5 + the `variant_*` sweep as ONE
  terminology pass.

## F. Inspection — artifacts × scenarios, pre and post

What exists (F1–F3 + provider unification chronicled in worklog): `spec
<pj>` = declared artifacts (grouped, provider + drift check) + every
enumerated scenario in full flat form with last-run verdicts + xfail marks;
`spec --by-artifact`; `spec @all [--json]`; `status <pj> [-v]` =
per-scenario × per-step verdict matrix (generic-runner scenarios included).

**Pipeline map (pre / run / post — where to read):**
- **pre** `canary spec <pj>` → `print_spec` → `Canary_project_run.
  scenarios_of ?policy pr` = `enumerate ~policy` over the declared
  `pr_spec`. (No prepare phase in the general interface: tiny-full assembles
  its vendored tree INSIDE its realizations — tiny-factory machinery.)
- **run** `canary action <pj>` → `run_project_run` → `realize ∘ dispatch` →
  `derive_steps` → `Canary_local_runner` → `scenarios.tsv`.
- **post** `canary spec <pj>` (re-run) / `canary status <pj> [-v]`.

Open:
- **F4 — run-closure (realised graph) view** *(gated on the node graph,
  §A)*: declared potentials vs post-run realised (built lib promoted into
  the lib group with its `built_from` edge).
- **F5 — rewire `canary scenarios` onto the core enumeration.**
  `canary_scenario_coverage.ml` is a parallel impl (zero refs to
  `Canary_enumerate`, hardcoded pre-convergence project list — hence
  `Unknown project tiny-full` and stale counts). The *view* (stage
  coverage) is worth keeping; derive it from the enumerated assignments'
  provision axis so it knows every project. Couples with the
  scenario_terms T1/T2 rename.
- **Unit tests — general artifact ops** (user-raised):
  `provision_of_provider` coverage, `string_of_provider` rendering, the
  provider⇒baseline-provision drift invariant as a test, not just a ⚠.
- **z3/llvm provider exposure** — their fetched detail is in shell
  closures; a real per-artifact provenance table comes with A5.
- Minor: `run_state.json` still holds only the LAST scenario's step state
  (the per-scenario truth is `scenarios.tsv` + `actions.log`); `spec`'s
  scenario section is flat-listed, not artifact-grouped.

## G. Docs

- **Regenerate `tiny.md` from current code** (per user) — the existing doc
  is tiny1-era; a fresh writeup should describe tiny-factory / tiny1 /
  tiny-full + the enumerate engine as they stand.
- (The 2026-08-04 design-doc consolidation — 4 docs retired into
  `dynamic_enumeration.md`/`ssot.md` — is chronicled in the worklog.)

## 1c. Project-file review (2026-08-03, updated 2026-08-05)

| Tier | Mechanism | Projects | Runner |
| --- | --- | --- | --- |
| **project_run** | `pr_spec` data table + provider table + `realize ∘ dispatch` | tiny-full, sqlite | generic `run_project_run` |
| **raw runner_spec** | `mk_runner_spec ~source` / `mk_variant` per variant | z3, llvm, ssl | `run_project_multi` |
| **Pattern A** | ~40-line declaration → runner_spec | zarith, cairo | `run_project_multi` |

Open issues (original numbering kept):

1. **Expectation model is 3 different things** → A7.
2. **Module-init side effects** — `detect_pm` memoized 2026-08-04; still
   open: fully SKIP for PM-irrelevant commands (`spec`/`paths`/`graph`). → E.
3. **Unwired `latest` channel** (NOT dead — intended spec data; z3/llvm
   declare it, 0 live uses). Keep; wire with the version-axis work. → E.
4. **Terminology** — factory comments still mix "resource" with the legit
   `Vendored` provision. → E.
5. **sqlite carries two shapes** — the older Fetched-only `runner_spec`
   (used by CI / `canary_run`) + the newer `sqlite_run`; `built_spec` uses
   raw `gcc`/`curl` `Printf` instead of `Canary_cc`/`build_cmd` (A9-step-2
   territory).
6. **z3 / llvm are structural twins that share nothing** (~600 lines each)
   — no "Pattern C" template; fold into A5.
7. **Minor** — `canary_run.sqlite_job` duplicates a `ci_jobs` entry
   (debug-only); `open Canary` shim still consumed.

## 1a. The tiny trilogy + enumeration state (design: ssot §4.2 / §4.2.5)

- **tiny-factory** — the machinery (`canary_tiny_scenario.ml` specs +
  `canary_tiny_workspace.ml` materializers / cached artifacts) that *makes*
  every artifact variant + holds the tiny1 oracle.
- **tiny1** — the single-scenario projects, each a hand-written good/bad
  case = the ground-truth **oracle**. `canary tiny run`.
- **tiny-full** — the one PROJECT (peer of sqlite/z3) that **declares**
  those artifacts; **canary computes** detection/expectation/collapse.
  `canary action tiny-full`. A real simple project is "no harder than
  tiny-full".

Full principle: **ssot §4.2.5**. The build-out arcs (P0–P3, convergence,
faithful-worlds) are chronicled in
[`worklog_2026_08.md`](worklog/worklog_2026_08.md).

**Enumeration state**: one product-then-filter algorithm
(`action/canary_enumerate.ml`); config levels Free/Subset/Full per axis.
Axes wired: provision · version per `(artifact × provision)`
(`build_id = {channel; quality}`; quality folds mutation into version
identity) · mutation ('m overlay; tiny-only) · mechanism/app-wiring via the
artifact-identity set. Still open: **Fetched** provision for tiny (§B);
graph-structural version propagation (§A); fold `(artifact, ext)` into base
`artifact_kind` (§A merge cleanup).

## 1b. Deferred design — one cluster (enumeration / graph / packaging)

Not started; interrelated — pick up together when §B/§C force them.

- **Instance graph + per-edge version + versioning** — deploy mismatch is a
  per-edge property; the graph exists (`artifact_node` +
  `make_action_graph`); the work is the run-emitting fold (§A parked item).
  [`dynamic_enumeration.md`](design/dynamic_enumeration.md),
  [`versioning.md`](design/versioning.md).
- **Packaging / provision sub-structure** — `Fetched` over PM
  (apt/opam/pip/brew) × distro; also "PM ships binary" (apt) vs "PM builds
  source at install" (opam) — the provider refinement surfaced by the
  fetched-binding question 2026-08-05.
- **Headers provision** — `Headers` payload + `Build_headers → Built`.
- **§5 principle-rewrite** — "bad scenario" → "scenario with a bad
  *result*" (result is a coordinate, not a category).

## 2. Near-term

- **`design/tiny.md` audit** — §7 wish-list predates the vendored-artifact
  model + generic runner; rewrite the still-relevant bits or retire. (Do
  before leaning on tiny.md again.)
- **`new_project.md` revisit before onboarding a new project** — checkpoint
  against the current `project_run` shape (data spec + dispatch/realize)
  before picking a Tier-1/Tier-2 target.
- **Flavor-2 catalogue extension** —
  [`design/bad_scenario_flavors.md`](design/bad_scenario_flavors.md): cull
  bug trackers for failure kinds beyond c1..c8.
- **`Package` mutation source** — needs a `Package` case on `artifact_kind`
  or a new `mutation_kind`; likely trigger = PyTorch target
  (`design/new_project.md`).
- **Task 2 — recipe / mutation integration** (project-hookable factory) —
  deferred; largely SUBSUMED by A9-step-2 (the action-variant table is the
  general form of "projects supply their own recipes"); revisit after A9.
- **Per-step contract outcome** — every action's result (success AND
  failure) as a typed observation into the contract layer, not substring
  assertions. Partially realised (agnostic derivation, xfail); the broader
  per-step framing across all projects couples with A7.

## 3. SSOT reconciliation

Structural items about the SSOT itself (numbering stable; #0 and #7
closed — chronicled).

- **#1** Ar.0..Ar.3 vs code's 5 kinds — does `Headers` get its own Ar id?
- **#2** §2 vs §3 Ag numbering — renumber §2 to the §3 catalogue ids.
- **#3** Sf.5 / runtime — Python/runtime its own Sf.5 or part of Sf.4?
- **#4** C8 ↔ Ag.X — add Ag.8 (API-faithfulness) or fold.
- **#5** Code-side rename (C1..C8 → Ag.X, inspect_input → Sf.X) — deferred
  to the polish pass ("uniformity eventually").
- **#6** Sf.X ↔ Ar.X alignment (Principle 2) — renumber Sf so Sf.k is the
  surface of Ar.k.
- **#8** Tiny packaging coverage — folds into §B Fetched-provision + §1b
  packaging.
- **#9** Operational-taxonomy code sweep — see §5.

## 4. Structural in-flight

- **Cross-project symmetry** — LARGELY DONE via the generic path; what
  remains is exactly A5 (z3/llvm) — tracked there, not here.
- **Iteration helpers over §1/§2/§3** — `canary_ssot.ml` typed iterators
  (every artifact / surface / agreement) for validators, once leaned on.
- **Alignment invariant as a runtime test** — assert the two
  `derive_scenarios` outputs + both index views agree.

(The "dual-view artifact index" item is satisfied by
`spec --by-artifact` — closed 2026-08-05.)

## 5. Deferred code polish

- **First-class `artifact_details`** — `{ provision; status; location; … }`
  so an artifact is blamed to its origin while its state is tracked;
  deferred until a consumer needs provenance/blame (`artifact_status`
  stays unused until then).
- **Sync `scenario.actions` with the runtime** — make the factory emit
  steps only for a scenario's listed actions (e.g. Bs.10's OCaml-only
  mutation skips the Python chain). Touches `derive_steps`; couples with
  the recipe/action-variant work.
