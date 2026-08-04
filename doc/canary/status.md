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
space, assembles **cached artifacts** (no rebuild), and **canary computes**
detection + expectation + the fail-fast collapse, via `run_project_run` over a
`project_run` spec. Honest coverage is **12/24** (thin **12/20**), **cold ==
warm** — the earlier "20/20"/"24/24" were warm-cache fake-green (a failed probe
cached as success; fixed). The 12 undetected are watchlist-blind (c5/c6/abi) and
need richer *inspectors*, not plumbing. **sqlite runs through the SAME generic
runner** (Fetched + Built). z3/llvm stay raw-script (`run_project_multi`),
untouched. Trilogy + principle: **ssot §4.2.5**; full arc history
[`worklog/worklog_2026_08.md`](worklog/worklog_2026_08.md).

**Recently landed** (2026-08-03/04, the honest-coverage arc): Fix B (cache
soundness) · `spec` dry-run · Fix A (cached artifact carries source) + born-safe
ids + robust verdict · thin `--thin` · naming unification + `pretty_id` · quick
hygiene. Net: tiny-full went from a fake 24/24 to an honest, stable 12/24. Full
detail in [`worklog/worklog_2026_08.md`](worklog/worklog_2026_08.md).

**To-do, regrouped.**

### A. Convergence — one enumeration algorithm, one project spec (current focus)

**Two paths today.** The enumeration ALGORITHM (`canary_enumerate.run_config`)
is already shared by config — `tiny_slice` (mutation axis) and `general_slice`
(provision/version) are both presets — but only the **display** (`tiny engine`,
`scenarios`) + tests call it. The **run** hand-builds a list (`pr_enumerate`
closure → `tiny_full_assignments` / sqlite's list), which isn't guaranteed to
match what the algorithm would produce (e.g. sqlite hand-builds `lib-only-Built`
where the algorithm gives `lib=Built + bindings=Fetched`). Converge the run onto
the algorithm.

**Roles** (one algorithm, not one runner): general projects (tiny-full, sqlite,
z3…) **GENERATE** scenarios from `run_config`; **tiny1 stays STANDALONE** (the
hand-authored oracle, `canary tiny run`) and `run_config` **PROJECTS** it for
cross-check (already the `tiny engine` view). The mutation axis (`bad_tags`) is
tiny-only — a polymorphic `'m` overlay on the all-Good `point.assignment`; real
projects pass `mutations = []`. The universal spec has no `bad_tags`.

Steps:

- **A1 — per-artifact provisions.** ✅ done 2026-08-04 (`828e105`).
  `enumerate`/`run_config`/`assignments_of` take a per-artifact universe
  (`provisions_of : artifact_id -> provision list`) instead of one global
  `provision list`. `tiny_slice`/`general_slice` keep their sigs (constant fn), no
  caller ripple. Pure — changed no run; `project-test` `per_artifact_provisions`
  proves the sqlite shape.
- **A2 — point → assignment fold.** `assignment_of_point : ('m -> string) -> 'm
  point -> assignment` (folds `mutation = Some (aid, m)` → that artifact's
  `quality = Bad (tag m)`) — bridges the algorithm's `point` (mutation separate)
  to the run's `assignment` (Bad folded). Pure. + `project-test`.
- **A3a — declared `project_spec` + `assignments_of_spec`.** ✅ done 2026-08-04
  (`5473c8a`). The declared-axes type + `run_config`+fold; plus `assignment_ok`'s
  Built-lib source requirement made conditional on `a_source` being *declared*
  (sqlite models Built as self-contained). Pure; `project-test`
  `project_spec_sqlite_shape`. Reading the code surfaced two **modeling
  findings** that A3b/A4 must decide:
  - *sqlite provision-coupling*: the algorithm's product gives `lib=Built +
    bindings=Fetched` (bindings present) — sqlite's hand-built list had lib-only
    Built. So converging sqlite **changes** it: the binding runs *over the
    built lib* (= coverage-C). It also can't reproduce "bindings absent iff lib
    Fetched" (that's a cross-artifact coupling the independent per-artifact
    product doesn't express) — arguably correct (drop the coupling).
  - *tiny multi-mutation*: `point.mutation` is a single `option`, but tiny's
    **combinations** are multi-bad. The algorithm can't yet emit multi-mutation
    points → A4 needs a multi-mutation extension (or combinations stay a
    tiny-only overlay).
- **A3b — flip sqlite's run** onto `assignments_of_spec`. **Behavior change** (not
  a drop-in): the Built scenario gains a binding-over-built-lib probe, so sqlite's
  two runner_specs (`runner_spec` Fetched / `built_runner_spec` Built) must
  **unify** into one provision-dispatched spec that always fetches+probes the
  bindings (with `LD_LIBRARY_PATH` → the built lib). This IS coverage-C; do it
  deliberately.
- **A4 — wire tiny-full** (the `'m=string` mutation instantiation via A2);
  `--thin` becomes `config.mutation = Subset`, not a separate `thin_assignments`
  filter. Cross-check generated tiny-full vs projected tiny1.
- **A5 — wire z3/llvm/ssl** onto `project_spec`; retire `run_project_multi` +
  `print_spec_variants`.
- **A6 — collapse** `Canary_project.project` into `project_run` — one identity.
- **A7 — unify** the 3-way expectation model (agnostic / contract-bound /
  hand-written → derived; §1c #1).

**Graph-model recap + gate (2026-08-04).** The two findings are one model: **an
artifact can be a built result — a resource generates (`built_from`) or contains
(a bundle) other artifacts, so `provision` is a per-EDGE provider, not a flat
label.** The instance graph already exists (`artifact_node` + `make_action_graph`);
the merge is to **extend `artifact_node`** with `ext` + typed `version` +
`provision` and drive the run off it — `runner_spec` is keyed on actions and
barely moves (`runner_spec : graph :: codegen : IR`). Design SSOT:
[`design/dynamic_enumeration.md`](design/dynamic_enumeration.md).

- **✅ seam** — `built_from_of_assignment` reads edges off the action catalogue
  (proves the flat assignment == the action graph).
- **✅ first-cut node merge (2026-08-04, no run change):** **M1.0** relocated
  `artifact_node` base→action (`fa85cd6`); **M1** extended it with `ext` + typed
  `version` + `provision`, populated from the producing action, `paths`/diagram
  byte-identical (`1f3a24f`); **M2/M3** `node_of_assignment` lifts flat→node graph
  via the seam + chain cross-check (`64ed970`). The node model is now real in code.
  - **Finding:** `make_action_graph` UNDER-records the `lib ← source` edge (its
    `Build_lib` node omits `built_from=source`, source-as-implicit-root), while the
    catalogue + seam include it. Reconciling that source edge is a follow-up for
    the full merge.
- **Next — grow the node model** (still no run change): versions → the mismatch
  cartesian; app → build-vs-run edge; provision breadth (Staged/PM/Contained).
  Then **A3b + A4** (the run-flips) build on it. A1/A2/A3a are the entry rung; the
  ~61-site pair→enriched-kind fold is a decoupled later cleanup.

### B. Coverage — make canary detect more

- **Richer agnostic inspectors** (the lever for 12 → more): c5 symbol-version, c6
  type, abi/soname wired into the agnostic derivation. The remaining 12 undetected
  fail *unexpectedly* because the watchlist can't predict them.
- **Version deploy-mismatch** (*beyond the algorithm milestone*): **backward** (a
  stable consumer @ newer incompatible lib — soname/symver, `Bs.4`/`Bs.3` → c4/c5)
  + **forward** (a dev-only symbol `tiny_scale` @stable → c1/c2, needs a dev
  consumer). Broad = **missing *and* added** symbols → multi-app / per-version
  required-symbol watchlists (like z3/llvm). Design + build together.
- **Fetched provision for tiny** — canary fetches from a PM at run time, the one
  provision tiny still lacks (Built + Vendored + Dev/Stable done).

### C. Real-project breadth (sqlite)

- Binding **built against the Built lib** (the Built scenario is lib-only today).
- **Real version axis** — the amalgamation URL is hardcoded `3450100`; derive it
  from `placement.version`.
- **distro × sys-PM × lang-PM** packaging enumeration (couples with §1b).

### D. Deferred design cluster

§1b (instance graph / per-edge version / versioning / packaging / headers
provision / §5 rewrite). Pick up when B/C force it.

### E. Polish

Tri-view command (factory / tiny1 / tiny-full on the `Bs.N` key) · factory
comment sweep (resource → cached artifact in the 2229-line
`canary_tiny_scenario.ml`, minding the legit `Vendored` *provision*) · full-lazy
`detect_pm` · wire the `latest` channel (§1c #3) · scenario names + `docs/canary`
output volume.

## 1c. Project-file review (2026-08-03)

Read across `src/canary/projects/*.ml`. The headline: **three ways to define a
project**, and **two** project-identity types — the core non-uniformity the
unification pass (to-do #5) resolves.

| Tier | Mechanism | Projects | Runner |
| --- | --- | --- | --- |
| **project_run** | declare artifacts + enumerate + materialize + runner_spec | tiny-full, sqlite | generic `run_project_run` |
| **raw runner_spec** | `mk_runner_spec ~source` / `mk_variant` per variant | z3, llvm, ssl | `run_project_multi` |
| **Pattern A** | ~40-line declaration → runner_spec | zarith, cairo | `run_project_multi` |

Ranked issues:

1. **Expectation model is 3 different things** — tiny-full **agnostic**
   (`expectation_agnostic`, derived by inspection); z3/llvm **contract-bound**
   (`lower_expectation` over `*_contract_bindings`); ssl **hand-written**
   (`Expect_failure { contains_any = ["native_library_version"] }`). Unify toward
   derived once one runner (to-do #5) is in place.
2. **Module-init side effects** — `Canary_store.detect_pm ()` runs at *module
   load* (`ssl.ml:56`, `sqlite.ml:61`, via pattern_a). ~ **Memoized** 2026-08-04
   (one PM probe per run, not ~4×). *Still open*: fully SKIP it for PM-irrelevant
   commands (`spec`/`paths`/`graph`) — needs deferring runner_spec construction
   (pm is baked into store_config data). → E.
3. **Unwired `latest` channel** (NOT dead — intended spec data). z3/llvm declare
   a third release channel `z3_source_latest` / `llvm_source_latest`
   (`version="latest"; ref_="HEAD"`) beside dev (pinned) and stable (released),
   plus `llvm_sources = [dev; stable; latest]`. 0 live uses today — nothing runs
   the `latest` variant. **Keep**; wire it when a 3rd-channel variant / the
   version-axis work lands (§1b). Don't delete.
4. **Terminology sweep** — identifiers renamed; spec-file comments swept
   2026-08-04. *Remaining*: the factory (`canary_tiny_scenario.ml`,
   `canary_tiny_workspace.ml`) still mixes "resource" with the legit `Vendored`
   *provision* in comments. → E.
5. **sqlite carries two shapes** — the older Fetched-only `runner_spec` (used by
   CI) + the newer `sqlite_run` project_run; plus `built_runner_spec` uses raw
   `gcc`/`curl` `Printf` instead of `Canary_cc`/`build_cmd`, and the version axis
   is cosmetic (see to-do #2).
6. **z3 / llvm are structural twins that share nothing** (~600 lines each, same
   skeleton) — no "Pattern C" template. Lower priority (genuinely more complex:
   cmake, `opam.in`, sccache).
7. **Minor** — `canary_run.sqlite_job` duplicates a `ci_jobs` entry (debug-only);
   `open Canary` shim still consumed.

**Good**: `project_run` is minimal and right; Pattern A is a clean compression;
watchlists are documented with rationale.

## 1a. The tiny trilogy + enumeration state (design: ssot §4.2 / §4.2.5)

- **tiny-factory** — the machinery (`canary_tiny_scenario.ml` specs +
  `canary_tiny_workspace.ml` materializer / cache_artifact / assembler) that
  *makes* every artifact variant as a **cached artifact** + holds the tiny1 oracle.
- **tiny1** — the single-scenario projects, each a hand-written good/bad case =
  the ground-truth **oracle** (validates the tooling/checkers). `canary tiny run`.
- **tiny-full** — the *one* project (peer of sqlite/z3) that **declares** those
  cached artifacts; **canary computes** detection/expectation/collapse
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
- **P3** cached artifacts + combinations — cache→assemble→run; `action
  tiny-full` reported **20/20** via assembly (later found warm-cache inflated —
  honest **12/24** after Fix B); `tiny assemble-combo` for the beyond-tiny1
  multi-bad; canary computes the collapse (`94fa841` … `d627890`).
- **Convergence 1** `canary_project_tiny.ml` (project module + `project_run`
  interface, `ab4bcd4`); **2** `run_project_run` — the project-agnostic runner
  drives tiny-full via closures, z3/llvm untouched (`a620b15`).

**Enumeration state** (model: [ssot §4.2](design/ssot.md)). One abstract
product-then-filter algorithm (`action/canary_enumerate.ml`); a `config` sets
each axis to `Free`/`Subset`/`Full`. Axes wired: **provision**
(`Absent`/`Fetched`/`Built`/`Vendored`, coarse origin), **version**
(`build_id = {channel; quality}` — quality folds the mutation into the version
identity), **mutation**, and **mechanism/app-wiring** (the precise
`(artifact, ext)` identity, kept off the base `artifact_kind`). tiny now
exercises **Dev/Stable × Built/Vendored** (to-do #1 done); **Fetched** still to
add. Still open (→ §1b below): fold `(artifact, ext)`
into base `artifact_kind`; provision sub-structure (PM × distro); Headers
provision; versioning unification ([versioning.md](design/versioning.md)); the
§5 rewrite ("bad scenario" -> "scenario with a bad *result*").

## 1b. Deferred design — one cluster (enumeration / graph / packaging)

Not started; interrelated — pick up together when the tiny axes (to-do #1)
force them. Home docs carry the detail.

- **Instance graph + per-edge version + versioning + dynamic enumeration** — the
  deploy mismatch (build-version != run-version) is a per-edge property; the graph
  that generates it **already exists** (`artifact_node` + `make_action_graph`), so
  the work is a *merge* into one instance type (`artifact_node` + `ext` + typed
  `version`), not a new graph. The **2026-08-04 refinement** (an artifact can be a
  built result — `provision` is a per-edge provider, a resource generates/contains
  other artifacts) is the same cluster and now gates the convergence's project
  run-flips (§A A3b/A4). [`dynamic_enumeration.md`](design/dynamic_enumeration.md),
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
8. **Tiny packaging coverage** — folds into §1 to-do #1's
   Fetched provision + the §1b packaging cluster. (The old
   `tiny.md §7.5` pointer is stale — tiny.md needs the §2 audit.)
9. **Operational-taxonomy code sweep** — see §5 below
   ("Deferred code polish").

## 4. Structural in-flight

Larger design shifts. None active; awareness only.

- **Cross-project symmetry** — *partly overtaken by the convergence.*
  `Canary_project_tiny.project_run` + the generic `run_project_run`
  now give the uniform enumerate→materialize→run shape this wanted;
  what remains is z3/sqlite implementing `project_run` (§1 to-do #4)
  so a real project's variants come from the algorithm, not a
  hand-written list.

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

Not blocking; the "uniformity eventually" pass. (Newer polish — scenario
names, tiny-full `docs/canary` output volume — is in §1 to-do #5.)

- **First-class `artifact_details`.** `base/canary_store.ml` splits two
  artifact axes: `provision` (origin / blame — wired now) and
  `artifact_status` + `location` (whereabouts — moves). A first-class
  `artifact_details` `{ provision; status; location; … }` would let an
  artifact be blamed to its origin while its state is tracked. Deferred until
  a consumer needs provenance/blame; `artifact_status` stays unused until then.
- **Sync `scenario.actions` with the runtime.** Today `scenario.actions` is
  metadata; canary's factory emits the full spec regardless. Making the factory
  respect it (emit steps only for the listed actions) would let a `Bs.N` run
  skip the language chain its mutation doesn't touch (e.g. Bs.10's OCaml-only
  mutation wouldn't run the Python probe). Touches `derive_steps`; couples with
  the recipe-interface work.

Done + chronicled in the 2026-07 worklog: Task 3 term-rename sweep, derive
`related_artifacts` from `actions`. The old "engine vocabulary alignment" item
is superseded — the framing is now the *enumeration algorithm*, and
`canary_project_tiny.ml` exists as the project module.
