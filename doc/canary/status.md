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
**BOTTOM-UP (user, 2026-08-05, post-A5/A7):** keep the
action frame in mind but no top-down design passes — grow by
concrete increments (add an action like build-for-install,
reconsider the probe ROLE, onboard projects, audit a
project's missing cases), regroup actions when evidence
forces it. Design consolidation (A9-step-2 table, the
scenario↔action terminology) comes LAST, from the
accumulated cases. Every increment ships its harness guard
(ratchet / pin / world-identity assertion) so the project
grows stably. Near-term concrete track: two-instance
scenarios (milestone (b)) + build-for-install as a side
task.

For tiny-scoped items see the wish-list in
[`design/tiny.md`](design/tiny.md) §7 (stale — audit queued,
§2). For the after-tiny research task see
[`design/bad_scenario_flavors.md`](design/bad_scenario_flavors.md).

## 1. Now

**Current state (2026-08-05, post A5+A7 — arcs chronicled in
[`worklog_2026_08.md`](worklog/worklog_2026_08.md)).** FOUR projects run
through the fully generic path (tiny-full, sqlite, z3, llvm): `pr_spec`
(ONE data table) → `scenarios_of ?policy` (`--thin` = a runner policy) →
`pr_runner_spec = realize ∘ dispatch` → `derive_steps` → run, with
scenario identity/dedup (Fetched version-ambient), per-scenario verdicts,
xfail surfaced end-to-end, and pre/post views (`spec [--by-artifact]
[--json]`, `status`). The EXPECTATION layer is unified (A7): every real
project derives via the ONE lowering (`lower_expectation_agnostic` —
evidence-based, self-healing, contract-ATTRIBUTED: `xfail[c2]` on every
surface); the oracle is a tiny-factory combinator over it; sqlite's
`log_grep` is a named WORLD-IDENTITY ASSERTION (outside the unification);
ssl carries the first binding-side world assertion. Snapshot per project:

- **tiny-full**: 6 spec-derived scenarios; the binding@dev-over-stable-lib
  forward API mismatch derives + attributes `xfail[c1]`; dev binding
  declared a forward probe (`pr_mismatch_probes`), `spec` marks it.
- **sqlite**: 3 scenarios; Built worlds probe OVER the built lib with the
  runtime version asserted (world identity); Python runtime edge Ambient,
  OCaml Independent.
- **z3 / llvm**: two-chain specs (source F@{S,D}; lib F@S|B@D; wheel F@S)
  → 2 scenarios each; derived xfails: z3's wheel demo `[c2]`
  scenario-INVARIANT, llvm's Opcode.UncondBr `[c2]` chain-LOCAL (both
  localities on one runner).
- **ssl** (still `run_project_multi`, its last consumer): the 2×2 matrix
  derives from `app.requires` + per-variant mli evidence — `060_nlv` =
  `xfail[c2]`; probe asserts the switch's pinned version.
- **tiny1** (`canary tiny run`): the mutation ORACLE — **22/22 PASS**
  (2026-08-05: verdict reader fixed; type_wrong triaged — the oracle's
  strengthening now applies at PROBE-class sites only, and the runner's
  empty-prediction fallback resolves v3 variant-keyed log names).
  type_wrong's probe xfail is UNATTRIBUTED ([]) — honest: no static
  contract predicts a body-only c6 lie; the gap stays visible in
  attribution/coverage. Factory coverage 12/24 — the undetected are
  watchlist-blind (c5/c6/abi), need richer inspectors (§B), not plumbing.

Trilogy + principle: **ssot §4.2.5**.

**MILESTONE — enough projects really run as z3/llvm did, with a FAITHFUL
scenario combination** (derived from the declared spec; the run's scenario
set == what the algorithm + graph say the project's worlds are).
- **(a) combination derived from the spec — DONE** for sqlite + tiny-full
  + z3 + llvm (no hand-built scenario list can exist: `pr_enumerate` is
  retired).
- **(b) real mismatch/failure scenarios — MOSTLY DONE.** Shipped: sqlite's
  verified deploy scenario (runner-realized repoint) + tiny-full's
  enumerated, c1-detected forward mismatch (flat form: binding-version ≠
  lib-version). **First two-instance slice landed 2026-08-05 (bottom-up;
  relocated the same day per user)**: each consumer's runtime-edge mode
  (Independent / Ambient / Lockstep) is declared per-ARTIFACT on its spec
  row — `Canary_enumerate.artifact_axes.ax_runtime`; spec rows are
  per-artifact RECORDS now, the home for future artifact config (the
  brief `pr_runtime_edges` project table was a parallel-table smell) —
  and the GENERAL `Canary_enumerate.runtime_pairings_of` resolves the
  pairing per scenario — `spec` prints, per world, what each
  binding RUNS over vs was built against (`binding:ocaml → lib B:dev
  [build-lib ≠ run-lib: DEPLOY]`; python → ambient bundled). The second
  lib instance is enumeration DATA now, not realization folklore; the
  co-provider wheels (backlog #45) are DECLARED (z3/llvm python =
  Ambient). Still open, next slices as cases force them: a per-VARIANT
  build-lib key (tiny's vendored bindings, z3/llvm's chain-dependent
  OCaml edges — undeclared today); RANGING the run-lib beyond the
  scenario's lib placement (`close_deps Independent`'s cartesian — the
  App-level machinery stays parked, §A).
- **(c) z3/llvm on the generic path — DONE 2026-08-05** (A5; worklog).
- **(d) expectations unified + reportable — DONE 2026-08-05** (A7;
  worklog).

## A. Convergence — one enumeration algorithm, one project spec

Done steps (A1–A4, A3b, A6, A8, A9-step-1, the spec/policy split,
per-provision versions, `pr_enumerate` retirement, node-graph first cut
M1–M3 + `close_deps`, `make_action_graph` as forward engine, layering) are
chronicled in [`worklog_2026_08.md`](worklog/worklog_2026_08.md). Settled
design lives in
[`design/dynamic_enumeration.md`](design/dynamic_enumeration.md) (graph =
mid-layer VIEW, `derive_steps` = engine; build edges grammatical, runtime
edges resolved via `dep_mode`). Open:

- **A5 residue** (core DONE 2026-08-05 — z3+llvm generic; worklog):
  - ssl/zarith/cairo migration to `project_run` (retires
    `run_project_multi`; ssl is its last consumer). No hurry per user.
  - ~~`compat`/`verify` glob pre-A5 dirs~~ — DONE 2026-08-05:
    `resolve_variant` gained a scenario-id pass (known JSON base prefixes
    stripped; newest id containing the token; "stable"/"19" alias to
    "lib-fetched" since a Fetched channel never appears in scenario ids).
    Verified: `compat z3 dev`, `verify z3 stable`.
  - The three abstractions A5 was the forcing function for, now with
    concrete evidence: (i) the **location sub-axis** (one z3 scenario
    probes the lib at build-tree/staged/apt — unmodeled; A9-step-2's
    acceptance test); (ii) the **`dep_mode` value source** (who declares
    "runs over lib@Y, built against lib@X" — `close_deps Independent`'s
    owner; backlog **#45**'s "declare a pip package self-contained
    (co-provider)" is the Ambient instance of the same question); (iii)
    **binding-follows-chain** (neither z3 nor llvm could enumerate its
    OCaml binding: the flat product can't express "follows the built
    chain" without minting mismatch worlds) = the graph-structural
    version propagation below.
  - **Fold `source_repo.has_build_lib`/`has_build_binding` into the
    provision axis** (backlog **#47**, now A5-adjacent): the booleans are
    a second encoding of what `ps_universe` already declares (an
    artifact's `Built` provision), and z3/llvm's realizations still
    branch on them internally. Tractable now that dispatch reads
    placements; the `has_build_binding` boolean is exactly
    binding-follows-chain (iii) in boolean disguise — fold them together.
    PINNED meanwhile (2026-08-05):
    `z3/llvm.build_flags_match_declared_provisions` keeps the two
    encodings consistent until the fold.
- **A7 residue** (DONE 2026-08-05 — 3-way unification complete; §1c #1
  resolved; worklog):
  - typed per-probe `asserts` field (world-identity assertions as data
    `spec` can display, instead of shell-inline `log_grep`/prefixes);
  - world assertions for z3/llvm binding probes (the shared-switch
    scenario-crossing hardening; their probes span two packages — needs
    the per-chain version to assert);
  - probe-level mismatch roles in the design-intent table
    (`pr_mismatch_probes` can't express probe-code-vs-binding demos);
  - gh backend renders a Derived expectation with an EMPTY gen-time
    prediction as must-fail-any (can't distinguish "no local cache" from
    "clean artifact"); fine for current CI jobs.
- **Ambient-edge step dedup** (finding 2026-08-05): an Ambient runtime
  edge makes a step SCENARIO-INVARIANT (sqlite's python probe runs
  identically in all 3 scenarios; z3's wheel xfail fires in both chains).
  The per-edge declaration NOW EXISTS (`artifact_axes.ax_runtime`,
  milestone-(b) slice — sqlite/z3/llvm python edges declared Ambient;
  `dep_mode` is base vocabulary now, `canary_store`), so the runner
  CAN learn to share/dedup those steps across scenarios — the step-level
  analogue of the Fetched whole-scenario dedup; unblocked, not yet
  implemented. The z3-solver CO-PROVIDER entry (backlog **#45**:
  the wheel bundles its own libz3; diagram runtime edge misleading;
  `derive_steps` assumes bindings consume the external lib) is the same
  fact needing the same declaration — A5/A7 measured it live (the
  scenario-invariant wheel xfail IS the bundled lib observed).
- **A9 step 2 — dispatch as DECLARATION** (the action-variant table).
  Step 1 (the dispatch/realization split; pure `scenario_case` data +
  general coordinate reads) shipped 2026-08-05. Remaining: replace the
  per-project `dispatch`/`realize` CODE with a declared
  (action × placement-pattern) → (template + params) TABLE over shared
  command templates (finishes TODO #18; absorbs the channel→realization
  dialects — `sqlite_amalg` URLs, tiny's `-DTINY_DEV`, z3's `ref_` — into
  declared rows; makes `spec` able to show per-scenario commands without
  executing). Design against z3's complexity (A5), not sqlite's simplicity;
  `Raw` escape hatch required. Largely SUBSUMES backlog **#29/#32** step 2
  (auto-generated runner_spec — that entry already says "re-scope before
  acting" post-A8) and is where the typed per-probe `asserts` field (A7
  residue) naturally lands. **HELD — deliberately LAST (user,
  2026-08-05, bottom-up order):** the table consolidates from
  accumulated concrete actions (build-for-install, probe roles, new
  projects), it does not pre-structure them.
- **Node-graph enumeration — PARKED; its forcing functions are now the
  A5-residue abstractions** (deploy mismatch / two lib instances,
  binding-follows-chain propagation, `dep_mode` ownership). End state: ONE
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
  predict them. For c6 the concrete path is backlog **#44** (clang-AST /
  libclang extraction replacing the trivial-grep inspector) — and the
  type_wrong triage (2026-08-05) sharpened its payoff: a body-only c6 lie
  today confirms only as an UNATTRIBUTED xfail (nothing static predicts
  it); a body-reading c6 inspector turns that `[]` into `[c6]`.
  **DEPRIORITIZED (user, 2026-08-05): enhancement, not milestone work.**
  Assessed before starting: no recent check lost precision to the grep —
  the real projects' derived contracts use no typed inputs at all, and
  type_wrong is correctly handled by the oracle (22/22); the gain today
  is attribution polish + a tiny-coverage bump, while a PROPER clang
  path drags preprocessor/include/typedef handling. Stays in backlog
  #44; revisit when a real project needs a typed C surface.
- **Build-config divergence: build-tree vs installed artifact** (user,
  2026-08-05). Real projects routinely compile the local/build-tree
  artifact and the installed/packaged one with DIFFERENT flag sets (dev:
  assertions/`-g`; install/package: `-O2 -DNDEBUG`, RPATH rewritten at
  `cmake --install`, distro hardening flags) — an error-prone divergence
  canary should cover as a first-class failure class. Today it is
  INVISIBLE: the Staged location probes the same build output copied by
  a fake `cp` install (backlog **#40**), so build-tree ≡ staged by
  construction. Shape, in slices: (i) make install REAL (#40,
  `cmake --install --prefix`) so Staged is a genuinely transformed
  artifact; (ii) `inspect-diff` build-tree vs staged per scenario
  (symbol visibility, versioned refs, RPATH — the diff tool exists);
  (iii) declare build CONFIG as part of a Built artifact's identity
  (couples with the location sub-axis, A5 residue (i), and A9-step-2 — a
  flags column in the action-variant table; `versioning.md`'s `build_id`
  is the natural carrier). Demo target: z3 (already probes build-tree /
  staged / sys-PM in one scenario).
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
  seed of the c7/c8 lag contract (the natural next expectation-layer work
  now that A7 is done — same lowering, a new declared ROLE per watchlist
  entry).

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

- **Mechanism & PM design from first principles** (user, 2026-08-05;
  [`design/mechanism.md`](design/mechanism.md)). The mechanism CATALOGUE
  shipped (`base/canary_mechanism.ml`: per-mechanism `mechanism_info`
  data; project specs reference by name, `spec` displays from the
  catalogue; pinned total+consistent). OPEN research direction: today's
  mechanisms are found objects — with the design-space axes explicit as
  data (checking-point placement, surface carrier, version-identity
  transport, lib co-provision) and tiny as the controlled instrument
  (one lib × three mechanisms × 22 mutations = a per-mechanism
  manifestation matrix), can a better binding mechanism — then a better
  PM — be DERIVED rather than found? Migration path for the remaining
  scattered mechanism-coupled fragments (probe shapes, build recipes,
  inspector selection): rows in A9-step-2's action-variant table.

## E. Polish

- **Version definitions + printers: centralize** (user, 2026-08-05).
  Multiple version-ish notions (`Canary_basic.channel` + `version`,
  `Canary_enumerate.build_id`/`quality`, `source_repo.version` strings,
  opam `package_version`, `version_cache_tag`) and ≥5 hand-rolled
  Dev/Stable printers (`canary_enumerate.ml:147`, tiny's `chan_str`,
  `canary_main`'s `chan_s` + an inline match at ~577, sqlite's
  `sqlite_amalg` match) — `Canary_basic` exports no `string_of_channel`
  at all. Slice 1 (standalone hygiene): one `string_of_channel` (+
  channel-keyed helpers) in base, migrate the call sites, ratchet-style
  guard against new inline matches. The DEEPER typed unification
  (version as artifact identity across enumeration/store/cache) stays
  [`design/versioning.md`](design/versioning.md)'s tracker — not this
  item.
- **Tool-routing ratchet burn-down** (guard shipped 2026-08-05, user
  to-do: `harness.tool_routing_ratchet` in `project-test` freezes
  per-file counts of raw shell verbs in `projects/` — cmake / ninja /
  gcc / curl / unzip / pip install / opam install / nm -D / git clone /
  tar; any NEW raw use fails: route it through a `src/canary/tool`
  primitive). Remaining = shrink the baseline to zero — sqlite
  `built_spec`'s raw gcc/curl/unzip + nm (§1c #5), llvm's pip/opam
  raws — the cleanup half of TODO #18, natural with A9-step-2; lower
  the baseline in the same commit as each cleanup. (sqlite burned to
  ZERO 2026-08-05 via new `curl_unzip_cmd`/`cc_shared_lib_cmd` +
  `native_lib_probe_cmd`; remaining: llvm pip chain — needs a
  pip-install-any primitive with the uv fallback — and the opam-install
  raws.)
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
  terminology pass. **Deliberately LAST (user, 2026-08-05, bottom-up):**
  the canonical scenario↔action relation should be WRITTEN DOWN only
  after the near-term concrete actions land (build-for-install, probe
  roles, two-instance scenarios) — the added cases decide the terms,
  not the reverse. (Candidate frame to test against them, kept in mind
  not committed: action = a pattern with slots; scenario = a consistent
  slot-filling; dep_mode = a constraint on fillings.)

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
| **project_run** | `pr_spec` data table + provider table + `realize ∘ dispatch` | tiny-full, sqlite, z3, llvm | generic `run_project_run` |
| **raw runner_spec** | `mk_variant` per variant (expectations derived since A7) | ssl | `run_project_multi` |
| **Pattern A** | ~40-line declaration → runner_spec | zarith, cairo | `run_with_info` |

Open issues (original numbering kept):

1. ~~**Expectation model is 3 different things**~~ — RESOLVED (A7 phases
   1–5, 2026-08-05): every real project derives via the ONE lowering;
   the oracle is a tiny-factory combinator; sqlite's log_grep
   reclassified as a world-identity assertion.
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
6. **z3 / llvm are structural twins that share nothing** (~600 lines each;
   A5 made the SHAPE identical — spec/dispatch/realize/pins are shared or
   parameterized — but the realizations' command templates remain twin
   code). The sharing comes with A9-step-2's action-variant table, not a
   "Pattern C" template.
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
  fetched-binding question 2026-08-05. **Its key frame landed 2026-08-06
  (user): providers are ARROWS — provider → action → artifact, fetch the
  same shape as build** (`providing_action_of`, dual to
  `provision_of_actions`, pinned consistent; `spec` renders the arrow per
  row; dynamic_enumeration.md §"Providers are arrows"). Next, when a case
  forces it: the provider as an explicit upstream NODE (every artifact
  gets its incoming arrow uniformly; #45's co-provider = one arrow, two
  outputs).
- **Headers provision** — `Headers` payload + `Build_headers → Built`.
- **§5 principle-rewrite** — "bad scenario" → "scenario with a bad
  *result*" (result is a coordinate, not a category).

## 2. Near-term

- **`design/tiny.md` audit** — §7 wish-list predates the vendored-artifact
  model + generic runner; rewrite the still-relevant bits or retire. (Do
  before leaning on tiny.md again.)
- ~~**`new_project.md` revisit before onboarding a new project**~~ — DONE
  2026-08-05: de-staled against the current `project_run` shape, then
  merged into [`projects.md`](projects.md) (one project doc: dimensions,
  status matrix, portfolio, landing mechanics, coverage levels).
  `new_project.md` is retired; its PyTorch case study is
  [`design/project_pytorch.md`](design/project_pytorch.md) and its
  auto-generation plan is [`backlog.md`](backlog.md) #29/#32.
- **Flavor-2 catalogue extension** —
  [`design/bad_scenario_flavors.md`](design/bad_scenario_flavors.md): cull
  bug trackers for failure kinds beyond c1..c8.
- **`Package` mutation source** — needs a `Package` case on `artifact_kind`
  or a new `mutation_kind`; likely trigger = PyTorch target
  ([`design/project_pytorch.md`](design/project_pytorch.md)).
- **Task 2 — recipe / mutation integration** (project-hookable factory) —
  deferred; largely SUBSUMED by A9-step-2 (the action-variant table is the
  general form of "projects supply their own recipes"); revisit after A9.
- **Per-step contract outcome** — the FAILURE half shipped with A7
  phases 1–2 (per-contract predictions logged; the confirming contract
  persisted per step and surfaced as `xfail[cN]`). Remaining: the
  SUCCESS half — a passing step as a typed "contract held" observation
  (today success is just silence), plus the world-identity assertions as
  typed observations (A7 residue `asserts` field). Couples with §B
  watchlist roles.

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

- **Cross-project symmetry** — DONE for the four generic projects; what
  remains is exactly the A5 residue (ssl/zarith/cairo) — tracked there,
  not here.
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
