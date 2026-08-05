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
runner** — now **3 worlds** (system-fetched lib + two built amalgamation versions
3.45.1/3.46.1), full source→lib→binding(ocaml+python)→probe chain each. z3/llvm
stay raw-script (`run_project_multi`), untouched. Trilogy + principle: **ssot
§4.2.5**; full arc history [`worklog/worklog_2026_08.md`](worklog/worklog_2026_08.md).

**Recently landed** (2026-08-05, the layering + purge arc): graph-view vs
`derive_steps`-engine layering settled (`execution_plan` is a VIEW, `construct`
renders the plan; `dynamic_enumeration.md`) · run parity with z3/llvm verified
(both mis-called "gaps" not real) · diagram **connectivity invariant MUTED** by
default (`CANARY_DIAGRAM_CONN=1` re-enables — it fails for all four projects, a
`step.deps`↔node-graph drift, not a run bug) · sqlite runs **3 worlds** (two
built versions) · **`pr_materialize` PURGED** from the general interface — the
generic runner computes `scenario_dir_of` (born-safe per-scenario dir + dedup
key; `Fetched` is version-ambient so its version isn't identity), tiny-full's
assembly folded into its `pr_runner_spec` (the `materialize` symbol now lives
ONLY in tiny-factory). All 6 worlds green; project-test 33/33, artifact-test
101/101. Earlier (2026-08-03/04, honest-coverage arc): Fix B cache soundness ·
`spec` dry-run · Fix A · thin `--thin` · naming unification. Detail in
[`worklog/worklog_2026_08.md`](worklog/worklog_2026_08.md).

**NEXT MILESTONE — enough projects really run as z3/llvm did, with a FAITHFUL
scenario combination.** sqlite + tiny-full now run their declared scenario sets
through the generic runner, but the *combination* is still thin/hand-tuned
per project. The milestone: pick a small set of real projects and make each
enumerate + run a faithful `(provision × version × mechanism)` scenario
combination — the deploy-mismatch and cross-version worlds z3/llvm demonstrate —
through the generic runner, not raw-script. Concretely: (a) the scenario
combination should be *derived* from the declared spec (the A-convergence below),
(b) exercise real mismatch/failure worlds (needs the runtime edge — A5
`close_deps`/`dep_mode`), (c) migrate z3/llvm onto the generic `project_run` so
"raw-script vs generic" collapses to one path. Faithful = the run's scenario set
matches what the enumeration algorithm + graph say the project's worlds are.

**Milestone progress (2026-08-05, the faithful-worlds arc — sqlite + tiny-full
first):**
- **(a) DONE for sqlite + tiny-full** — both projects' *entire* scenario set
  (baseline + built-lib version variants) is now enumerated from a declared
  `project_spec`; no hand-built assignment list remains on the generic path.
  Enabler: **per-provision version universes** (`ps_versions_of` is per
  `(artifact × provision)`) — a Fetched artifact is version-ambient (one
  representative), Built ranges over buildable versions, Vendored over cached
  variants, so declared worlds == run worlds (sqlite 3==3, the dedup-reliant
  4th declaration gone; tiny-full's built-lib variants derived, the old
  source-primary blocker resolved the sqlite way — self-contained Built,
  `a_source` display-only). `--thin` is now a real config level
  (`version = Subset [Stable]`), not a hand filter.
- **(b) FIRST REAL MISMATCH WORLD, verified** — sqlite's Built worlds now
  probe **over the built lib** (build_lib plants a `libsqlite3.so.0` soname
  symlink; probes export `LD_LIBRARY_PATH=<built libdir>`), and each probe
  PRINTS the runtime-reported version, ASSERTED against the declared built
  version (`log_grep sqlite_version=<dotted>`, derived from the channel
  axis). The built-dev world is discriminating: the opam binding (compiled
  against system 3.45.1) runs against built 3.46.1 — a real, checked
  run-lib ≠ build-lib deploy world. **Finding:** the Python stdlib binding's
  runtime sqlite is `Ambient` — a uv/standalone python STATICALLY bundles
  its own (3.50.4, `_sqlite3` a builtin, no .so to repoint) — so sqlite now
  exhibits BOTH runtime-edge modes of `dynamic_enumeration.md` on one
  project: OCaml = `Independent` (asserted), Python = `Ambient` (observed
  in probe.log, not asserted). **tiny-full now ENUMERATES mismatch worlds
  from the spec** (2026-08-05, the forward mismatch — §B): the OCaml binding's
  {Stable, Dev} version axis × 3 lib instances = 6 worlds; the two
  binding@dev-over-stable-lib worlds fail at the probe link and c1 predicts
  it agnostically (detected xfail) — the z3/llvm API-mismatch demo through
  the generic path, using only the FLAT form (binding-version ≠ lib-version
  is flat-expressible; TWO lib instances in ONE world — build-lib ≠ run-lib
  proper — still needs `close_deps Independent` wired into `scenarios_of`).
- **(c) NOT STARTED** — z3/llvm still raw-script (`run_project_multi`).

**To-do, regrouped.**

### A. Convergence — one enumeration algorithm, one project spec (current focus)

**Layering settled (2026-08-04).** The node graph (`make_action_graph` /
`execution_plan` / `construct`) is a **mid-layer VIEW** (enumerate worlds + mark
applicability + visualise); the **engine** is `derive_steps → step list → 4
backends`. `derive_steps` already walks the §6.5 catalogue; `execution_plan` is
its node-rendering, carries no commands, executes nothing — do NOT grow it into a
node-driven executor (duplicates `derive_steps`, loses GH/Mermaid/HTML). Written
up in [`design/dynamic_enumeration.md`](design/dynamic_enumeration.md) ("The graph
is a mid-layer VIEW"). `execution_plan` (pure, topo-ordered, tested:
`action.execution_plan_topo_and_edges`) shipped as the construct plan view.

**Run parity with z3/llvm — ALREADY MET (verified 2026-08-04).** sqlite/tiny-full
run the full `source→lib→binding(×langs)→probe` chain through the generic runner
(sqlite: 7 steps Fetched / 9 Built, both bindings; `run_info` + `html` + `diagrams`
produced), each exercising its whole declared world set (sqlite 2 = lib
Fetched/Built; tiny-full 3), exactly as z3/llvm run their 2 variants. Two things I
first mis-called as generic-runner gaps turned out not to be:
  1. **Connectivity invariant is UNIVERSAL, not a differentiator.** The diagram
     self-check ("does the drawn `.mmd` reproduce every `step.deps` edge?") failed
     for **all four** projects (z3/llvm too), because the diagram's hand-built edge
     topology and the runner's `step.deps` are two separate dependency relations
     that drifted. Every RUN is correct (step `check_pre` enforces the real deps);
     only the picture under-connects. **MUTED by default** (2026-08-04) —
     `CANARY_DIAGRAM_CONN=1` re-enables; coverage check still runs. The real fix
     (reconcile into ONE relation) is the "Merge cleanup" item below; diagram work
     is on hold.
  2. **No enumeration collapse** — 2 workspaces IS sqlite's declared world count
     (run == enumerate == declared). Nothing to widen.

**`pr_materialize` PURGED from the general interface (2026-08-05).** The
`materialize`/`pr_materialize` symbol was tiny-factory's (assemble vendored
artifacts) but had leaked into the general `project_run` interface. Removed: the
generic runner now computes `canary_main.scenario_dir_of a` — a born-safe per-
scenario dir used for the output path AND dedup. tiny-full's assembly folded
INTO its `pr_runner_spec` closure (the assemble/materialize vocabulary now lives
only in `canary_tiny_workspace`); sqlite builds into the runner-given dir.
**Scenario-identity rule** (general, from provision semantics): a `Fetched`
artifact is version-AMBIENT (the PM picks the version), so its declared version
is dropped from the id — two `Fetched@v` scenarios dedup; `Built`/`Vendored`
versions ARE identity. A project that pins a Fetched version would override via
its provider (`pr_provenance`) — not needed yet. sqlite `Fetched@Stable ≡
Fetched@Dev` ⇒ 3 runs (not 4). Also: sqlite now runs **3 worlds** (two built
amalgamation versions 3.45.1/3.46.1); all 6 worlds (3 sqlite + 3 tiny-full) green.

**~~Two paths today~~ → ONE path (2026-08-05).** The old gap — the run
hand-building a list (`pr_enumerate` closure) that wasn't guaranteed to match
the algorithm — is CLOSED at the interface level: **`pr_enumerate` is retired**.
`project_run` now carries the STATIC declaration (`pr_spec :
Canary_enumerate.project_spec`) and the general algorithm
(`Canary_project_run.scenarios_of` = `enumerate ~policy` — `derive_steps`-style:
declaration in, derivation out) is the only producer of a project's scenario
list; the runner and every `spec` view call it. The exploration `policy` is a
RUNNER argument (`full_policy` default; `--thin` =
`Canary_project_run.thin_policy`, version `Subset [Stable]`) — a project cannot
hand over a scenario list at all.

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
  - **Finding → ✅ fixed** (`11954e8`): `make_action_graph` under-recorded the
    `lib ← source` edge (its `Build_lib` omitted `built_from=source`). Fixed by
    reusing the in-file pattern — `Build_lib` now `get pools Source` + links
    source-primary (`lib@v ← source@v`), like `Build_binding` links lib. No new
    machinery; `paths`/`graph` byte-identical (they render path-table/schema, not
    per-node edges); M3 upgraded to cross-check both graphs now agree.
- **Next — NOT incremental tweaks; the substantive merge.** `make_action_graph`
  already has versions-mismatch + app build/run edges + locations. `node_of_assignment`
  can't catch up while it's derived from a FLAT assignment — each hits a real gap:
  - *mismatch* — structural: a flat assignment has one lib placement per kind, but
    build-lib ≠ run-lib needs TWO lib instances. Only a node-graph object expresses
    it (the whole reason for the graph). ⇒ the enumeration must EMIT node-graphs,
    not flat assignments — the real fold.
  - *app runtime_dep* — blocked: App's identity carries no lang (ssot §4.2.3), so
    an App node can't map to its `Build_app {lang}` action without a heuristic.
  - *location breadth* — Fetched's `a_location = Pm` needs `pm_info` the flat
    assignment lacks; *Contained/bundle* is a new concept needing design.
  So the node-graph fold is a deliberate design/build, not a quick add.
- **Re-prioritization (2026-08-04): the node graph is needed ONLY for the deploy
  mismatch** (build-lib ≠ run-lib) — and **tiny-full + sqlite have no mismatch**, so
  the FLAT `assignments_of_spec` (A3a) is sufficient to run them. `node_of_assignment`
  has **0 runtime users** (test-only); the run path touches no node graphs. So:
  - **PARK the node-graph merge** (the fold + `node_of_assignment` growth) until the
    deploy-mismatch / version work (z3/llvm), where it's actually needed. M1's richer
    `artifact_node` + the source-edge fix stand (they improved the live
    `make_action_graph`); M2/M3 are the parked seam.
  - **ONE engine, not two.** End state: `pr_spec (declared) → enumerate → node graph
    → run`, where a flat `assignment` IS the **degenerate node graph** (one instance
    per kind, no mismatch edges). The engine produces degenerate graphs today,
    generalizes to full graphs (mismatch) later — the flat form is subsumed, not
    kept as a weaker sibling. (`pr_enumerate` retired 2026-08-05 — `pr_spec` +
    `scenarios_of` IS the `pr_spec (declared) → enumerate` half; the node-graph
    half remains.)
  - **A3b — sqlite ✅ done** (`5393cb4`): declared `sqlite_spec : unit project_spec`;
    `pr_enumerate = assignments_of_spec sqlite_spec` (hand-built list retired). The
    algorithm gives `{lib=Built, bindings=Fetched}` (not lib-only), so `built_spec`
    unifies the lib build with the bindings (extend the Fetched spec, swap
    fetched-lib → built-from-source). Both scenarios PASS. *Follow-up:* bindings run
    against the SYSTEM lib (Python sqlite3 stdlib can't repoint; OCaml
    binding-over-built-lib via `LD_LIBRARY_PATH` is coverage-C proper).
  - **A4 — tiny-full core ✅** (`aac490f`): good baseline + single-bads now come
    from a declared `string project_spec` via `assignments_of_spec` (mutation
    universe = (artifact, bad-tag) pairs). Coverage unchanged (12/24). `point.mutation`
    → `mutations : list` landed (`cbd980b`) — enables combinations. **Both sqlite +
    tiny-full now enumerate their good/singles from declared specs — the convergence
    core is proven on both.**
  - **Per-artifact version axis ✅** (2026-08-04): `ps_versions : channel list`
    → `ps_versions_of : artifact_id -> channel list`; `enumerate`/`run_config`/
    `assignments_of`/`assignments_of_spec` take `versions_of` (mirrors A1's
    per-artifact provisions). Now expressible: "lib @{Dev,Stable}, binding pinned
    Dev-only" (the deploy-mismatch shape, one artifact's axis wider than another's).
    Pure — no run change; `project-test` `per_artifact_versions` proves it. Wiring
    tiny's **built-lib** variants *through* the spec still needs the source-primary/
    dev-build-flag resolution (tiny's Dev is a `-DTINY_DEV` build flag, not a source
    version), so those variants stay hand-built for now — this delivers the axis, not
    that routing.
  - **Spec/policy split + stage names ✅** (2026-08-04): the smell was `ps_mutations`
    + `ps_config` living inside `project_spec` — they describe *how you explore this
    run*, not *what the project is*. Split into two stages:
    - **Stage 1 `project_spec`** (now monomorphic, no `'m`): `{ ps_artifacts;
      ps_provisions_of; ps_versions_of }` — the project's real option space, a
      static fact an author writes / the tiny-factory generates.
    - **Stage 2 `'m policy`** `{ config; mutations }` + `enumerate ~tag ~policy spec`:
      the exploration policy (config levels + injected faults). `full_policy ()` =
      the real-project policy (Full everywhere, no mutation). The mutation universe
      is INJECTED (a testing policy), so it left the spec; provision/version
      universes are project facts, so they stayed.
    - Renames: low-level `enumerate` → `enumerate_points`; spec consumer
      `assignments_of_spec` → `enumerate`. Pure — no run change (tiny-full 12/24,
      sqlite PASS, 31/31).
  - **Stage-3 (graph) — model settled + v1 built ✅** (2026-08-04). Model:
    [`dynamic_enumeration.md`](design/dynamic_enumeration.md) (short canonical
    description; absorbed the retired `enumeration_graph.md`). Key decision:
    runtime edges live on `artifact_node` via a per-edge `dep_mode = Lockstep |
    Independent | Ambient str` (default `Lockstep` = today), NOT a `project_spec`
    field — deploy mismatch is `runtime_dep` resolved `Independent` over the lib's
    `ps_versions_of` axis, needing no new declaration. **Built:** `dep_mode` +
    `close_deps ~run_versions_of ~mode_of : assignment -> artifact_node list list`
    (`canary_action.ml`); `Independent` = `make_action_graph`'s App cartesian
    reached from the flat form; App-less ⇒ `[node_of_assignment a]` (flat projects
    byte-identical). Pure — not wired into a run yet (sqlite PASS, tiny-full 12/24,
    paths unchanged; `project-test close_deps_deploy_mismatch`, 32/32).
  - **Pre-graph sync — design decisions (2026-08-04, before the graph goes live):**
    - **The graph is DECLARED + STATIC, not dynamic-discovered.** A project declares
      its dependency graph (artifacts + edges + version/provider axes); the
      enumerator walks it; *every* scenario is knowable pre-run — **including the
      flavor-2 mismatch** (a *declared* runtime edge over a *declared* version axis).
      Earlier "static declared-closure + dynamic discovered-closure" framing was
      wrong — `ldd`-discovery is a *future convenience*, not the core. So `spec`
      shows all scenarios pre-run once the graph is declared.
    - **flavor-1 (mutation) is NOT a general algorithm** — it's tiny1's fault ORACLE.
      **Done (`48afff2`):** tiny-full decoupled — its general `project_run` is
      positive-only (good + built-lib, like sqlite, 3 scenarios); mutations live
      ONLY in tiny1 (`canary tiny run`) + the tiny-factory machinery (dormant).
    - **`ps_versions_of` is tiny-flat, wrong for general projects.** A flat
      per-artifact version axis over-generates for a build graph (`source@dev ×
      lib@stable` is nonsense unless a *declared* mismatch). General versioning is
      **graph-structural**: enumerate the source node, propagate through build edges
      (`source@v → lib@v → binding`), and the only cross-version pairing is the
      declared mismatch edge. Keep `ps_versions_of` for tiny (all-vendored, versions
      = labels); general projects get graph-structural versions. (This is why
      sqlite's `ps_versions_of source = [dev; stable]` felt off — dev isn't
      graph-wired.) *Partial mitigation 2026-08-05:* `ps_versions_of` is now
      per `(artifact × provision)`, which kills the worst over-generation
      (version axes only where the provision really ranges: Built) — but
      version *propagation* along build edges is still the graph work.
    - **A5 prerequisite:** z3/llvm produce ZERO scenarios today (variant view, not
      `project_run`). The graph work needs them on the `enumerate`/`project_run`
      path first — that IS most of A5, not an afterthought.
  - **Stage-3 to-do:**
    - **A5 (meaningful, not urgent)** — wire z3/llvm onto `enumerate` + `close_deps`
      with `Independent`; retires `make_action_graph`'s hardcoded App cartesian.
      Blocked on the `dep_mode` VALUE source = the **probe / action-variant revisit**
      (separate topic: who declares "this project wants the mismatch"). Until then
      `close_deps` is tested machinery whose only consumer is its test.
    - **v2** — `Ambient` external libs (grammar default + `ldd` slot) + `Contained`
      bundle provision.
    - **deferred** — dynamic `ldd` discovery (fill `Ambient` / promote to
      `Independent` at run time; the postpone/readiness tracker); run-closure
      inspection view (§E).
  - **Merge cleanup (rescued from the retired `enumeration_graph.md`):**
    - reconcile `step.deps : string list` (the runner's string-tag edges) with the
      typed `built_from`/`runtime_dep` node graph — one dependency relation, not two.
    - legacy artifact-vocab sweep — `artifact` + `step_body` + `cmdline` + base
      `run_step`/`mk_system_dep_steps` + `canary_toolchain` dead verify helpers.
    - the `(kind × ext)`→enriched-`artifact_kind` fold (~200 coarse-kind matches,
      diagram ~61) — the node merge does NOT need it (keeps the pair); decoupled.
  - *A4 follow-ups:* ✅ `--thin` as a `config` level (`version = Subset
    [Stable]`, 2026-08-05); ✅ built-lib variants routed through the spec
    (per-provision versions + self-contained Built resolved source-primary,
    2026-08-05). Still hand-built: the **combinations** wired as
    multi-mutation points (the curated chain policy) — tiny1/factory-only
    since the flavor-1 decoupling.

### B. Coverage — make canary detect more

- **Richer agnostic inspectors** (the lever for 12 → more): c5 symbol-version, c6
  type, abi/soname wired into the agnostic derivation. The remaining 12 undetected
  fail *unexpectedly* because the watchlist can't predict them.
- **Version deploy-mismatch**: ✅ **forward half SHIPPED** (2026-08-05) — the
  dev consumer exists (`canary/examples/tiny/ocaml_dev/`: the cstubs binding
  gains `Tiny.scale` → native `tiny_scale`, dev-only). The OCaml binding
  carries a version axis {Stable, Dev} in `tiny_full_general_spec`, so the
  flat product yields **6 worlds** (2 binding versions × 3 lib instances):
  `binding@dev × lib@{V:stable, B:stable}` FAILS at the probe link
  (`undefined symbol: tiny_scale`) and c1 PREDICTS it agnostically from the
  stub-vs-lib inspects (`expected failure confirmed (derived)` — detected
  xfail); `binding@dev × lib@B:dev` links + runs green. The z3/llvm-style
  API-mismatch demo now runs through the generic enumerate path. Still open:
  **backward** (a stable consumer @ newer incompatible lib — soname/symver,
  `Bs.4`/`Bs.3` → c4/c5); broad = missing *and* added symbols → per-version
  required-symbol watchlists. ~~*Polish:* the xfail nature isn't surfaced
  per-world~~ → ✅ done (2026-08-05): `step_status` gained `Step_done_xfail`
  (persisted in the verdict-marker CONTENT so warm runs keep it); `action`
  world lines print `xfail: <steps>` + a "mismatch worlds: N passed via
  confirmed expected failure" summary; `spec` marks those worlds `✓ xfail`
  and lists the xfail steps under "last run" (scenarios.tsv gained an
  xfail column; `--json` gets an `"xfail"` field).
- **Fetched provision for tiny** — canary fetches from a PM at run time, the one
  provision tiny still lacks (Built + Vendored + Dev/Stable done).

### C. Real-project breadth (sqlite)

- ✅ **Binding probes RUN against the Built lib** (2026-08-05): soname symlink
  + `LD_LIBRARY_PATH` repoint + runtime-version assert (see milestone
  progress (b) above). Still open: the binding *compile* against the built
  lib's headers (the opam binding is compiled against the system lib — which
  is exactly what makes the current world the honest deploy mismatch; a
  build-against-built variant would be a *different* declared world).
- ✅ **Real version axis** — amalgamation (dotted, numeric, URL) derived from
  `placement.version.channel` (`sqlite_amalg`); Built worlds assert the
  runtime-reported dotted version.
- **distro × sys-PM × lang-PM** packaging enumeration (couples with §1b).

### D. Deferred design cluster

§1b (instance graph / per-edge version / versioning / packaging / headers
provision / §5 rewrite). Pick up when B/C force it.

### E. Polish

Tri-view command (factory / tiny1 / tiny-full on the `Bs.N` key) · factory
comment sweep (resource → cached artifact in the 2229-line
`canary_tiny_scenario.ml`, minding the legit `Vendored` *provision*) · full-lazy
`detect_pm` · wire the `latest` channel (§1c #3) · scenario names + `docs/canary`
output volume · **terminology sweep: `variant_*` code identifiers →
`scenario_*`** (2026-08-05 unified the DISPLAY term to `scenario` — ssot §6.1
scenario ≡ variant ≡ "world"; the mechanical id rename
(`variant_id`/`variant_key`/`variant_file`/`print_spec_variants`/…) is queued —
touches cache/filename keys, so do it as one deliberate pass, not ad hoc) ·
**"scenario" is STILL overloaded vs the abstract senses** — `Sc.N`
good-scenario *patterns* + the coverage command's lifecycle *stages* (and the
`canary scenarios` CLI shows stages, not scenarios, with a stale count). Full
audit + options (T0 document / T1 rename command to `stages` / T2 split the
dual-use `Canary_scenario.scenario` type, riding F5) + open questions:
[`design/scenario_terms.md`](design/scenario_terms.md). OPEN — no decision
yet; do T2 together with F5 + the `variant_*` sweep as ONE terminology pass.

### F. Inspection — show a project's artifacts × scenarios, pre and post (2026-08-04)

Motivation: make it easy to see WHICH artifacts a project involves and WHICH
scenarios it runs, both statically (before a run) and from the result (after).
`spec` + `status` already exist; this plan closes the post-run half.

**Landed:**
- **`spec <pj>` — PRE / static (good).** Artifacts grouped `source / native /
  bindings / app` with each baseline `provision@version`, plus every enumerated
  scenario as a good/bad delta from baseline. (tiny-full: 7 artifacts, 29
  scenarios; sqlite: 3, 2.) This IS the static "artifacts + scenarios" view.
- **`status <pj>` — POST / run (thin).** Last-run step-verdict tree for ONE
  variant.

**Gaps (all post-run):**
1. **`run_state.json` keeps only ONE run state** (`project_name`/`steps`/
   `artifact_names`) — a multi-scenario run (tiny-full's 24) overwrites to the
   *last* scenario. So the `12/24` coverage is printed but NOT inspectable
   per-scenario. This is the root gap.
2. **`status` shows steps, not a scenario×verdict matrix**, and isn't
   artifact-grouped — no way to see which of the 24 scenarios detected, keyed to
   `spec`'s scenario list.
3. **`scenarios <pj>` is legacy** — errors `Unknown project tiny-full` (knows only
   the old sqlite/z3/llvm/… list, not the `project_run` path).
4. **No run-closure (realised) view** — the built lib promoted into the lib group
   (below); needs the node graph.

**Plan (in order; F1 is the prerequisite):**
- **F1 — persist per-scenario results ✅** (2026-08-04, `db0fe97`).
  `run_project_run` writes `_out/canary/projects/<pj>/-run/scenarios.tsv` (one
  TAB line per scenario that ran: verdict, good|bad, label), keyed by a shared
  `scenario_label` (delta-from-baseline) — the join key between pre and post.
- **F2 — per-scenario matrix ✅** (folded into `spec`, not a separate `status`):
  `spec <pj>` now reads the summary and annotates each enumerated scenario with
  its last-run verdict — good `✓`/`✗ REGRESSED`, bad `✓ detected`/`✗ missed`,
  `·` = not run (deduped workspace) — plus a `N/M bad detected · K ran` line. So
  `spec` is the pre AND post artifact×scenario view (tiny-full 12/24 matches the
  run; sqlite 0/0). *Remaining polish:* still delta-labelled, not artifact-grouped
  in the scenario section; a `status`-side matrix is optional now that `spec` shows it.
- **F3 — artifact-centric cut ✅** (2026-08-04, `7c288c4`). `print_artifacts` —
  the dual of `print_spec` (rows = artifacts): per artifact, the scenarios that
  directly mutate it (`✓ detected`/`✗ missed`/`·`) + a per-artifact detection
  rate + a `+M upstream` count (scenarios mutating an upstream artifact). Surfaces
  what the scenario list buried — e.g. tiny-full **lib 0/6 detected** (every lib
  mutation missed), ocaml cstubs 7/11.
- **Project-first CLI — REVERTED** (`18f1797`): per-project groups felt unnatural;
  back to general verb-first (`canary spec <pj>`, project trailing). The
  artifact-centric view is now `canary spec <pj> --by-artifact`.
- **Per-artifact provenance + build capability ✅** (2026-08-04, `087767b`).
  Confidence step (no execution): `spec` shows, per artifact, its
  provision@version + a **provenance** line (a vendored PATH, or a PM + PACKAGE,
  or build-from-source) + **builds → kinds** (from the action catalogue). The
  artifact list is `pr_artifacts` (spec); provenance is a new declared accessor
  `pr_provenance` on `project_run`, filled from REAL spec data (sqlite from
  `prebuilt`; tiny from the `canary/examples/tiny/*` layout).
  - *Caveat (2):* z3/llvm use the **variant view** (`print_spec_variants`, not
    `project_run`) so they show per-variant provision only, no provider — next.
- **Provider unification (steps 1–2) ✅** (2026-08-04, `f1f2ad8`). `canary_store_config`
  gains a typed `provider = Absent | Vendored path | Cached path | Built_from
  source_repo | Sys_pkg spec | Lang_pkg {lang;pm;package}` — the one place the old
  five shapes (lib_store/binding_store/source_repo/tiny_stores/the pr_provenance
  string) converge. `provision_of_provider` derives the coarse axis so the two
  **can't drift**; `pr_provenance` retyped to `provider option`; `print_spec`
  cross-checks provider-provision == baseline (⚠ on mismatch) — **closes caveat (1)**.
  `spec --json` emits parseable artifacts × scenarios. Consumer survey first
  confirmed two clean camps (coarse via `provision_of_provider`, detail via
  `provider`).
- **Provider unification (step 3) ✅** (2026-08-04, `c0f43b3`). The RUNNER now reads
  `provider`, not `location`+`system_pkg`/`pkg_name`: `lib_store = { provider;
  components; headers }`, `binding_store = { provider; source_dir }`;
  `command_of_step` derives fetch commands from `provider` (`Sys_pkg`→fetch_lib,
  `Lang_pkg opam`→fetch_binding) — **byte-identical** (the `project-test`
  Derived==Raw fetch_lib test still passes). Constructors (sqlite/pattern_a/ssl)
  migrated. `store_config.source` stays `source_repo option` (no Derived-build
  consumer yet; `provider` already folds it via `Built_from`). project-test 32/32,
  runs unchanged. **Unification done for the live path.**
- **`spec @all [--json]` ✅** (`03a2c1e`): every project (tiny-full/sqlite project_run
  + z3/llvm variant view) in one command; `--json` → `{ projects: [...] }` tagged by
  `kind`. The refactor cross-check.
- **`derived` — resolved ✅** (`d10a875`). Scope check first: the ONLY duplication was
  sqlite's lib provider (both `store_config.lib.provider` and `pr_provenance`);
  bindings + all of tiny aren't in `store_config` (Raw fetch closures / `tiny_stores`),
  so full store_config-as-single-source is NOT straightforward. Natural fix: a single
  `sqlite_provider : artifact_id -> provider option`; the runner's `store_config.lib`
  AND `pr_provenance` both derive from it — can't drift. tiny already single-source
  (only `pr_provenance`).
- **Uniform variant view ✅** (2026-08-04, `9d904e7`). z3/llvm `spec` now matches
  `print_spec`'s look: a **source artifact = a configured repo** — a "source repos"
  section shows each variant's repo (name @version, ref, remote) + what it *builds*
  (`has_build_lib`/`has_build_binding`), then artifacts grouped with provision per
  variant + catalogue builds. Printing-only: the `source_repo` is threaded into the
  variant tuple; the runner (`mk_runner_spec ~source`) is untouched. `spec @all`
  [+`--json`] is now uniform across all four projects. *Honest limit:* fetched-artifact
  package detail is in shell closures (coarse).
- **Source-as-artifact-group + sqlite remote repo ✅** (2026-08-04, `edd5d6a`).
  `provider` gains `Source_repo of source_repo` (the SOURCE artifact from a repo →
  Fetched; sibling of `Built_from` = Built). Every project now prints **source as
  one artifact group** with its provider: tiny-full vendored (local), sqlite a
  remote repo (`github.com/sqlite/sqlite` @`version-3.45.1` — the amalgamation it
  builds + the libsqlite3 the opam binding links; `sqlite_source_dev` = trunk
  declared too), z3/llvm per-variant repos (the "source repos" section folded into
  the source row). sqlite gained `a_source` (enumeration stays 2 scenarios; run
  unchanged). *Remaining:* sqlite shows the STABLE source only — enumerating its
  **dev** version (the z3-style version-mismatch) needs a dev build / `close_deps`
  (graph work); z3/llvm still don't expose a real per-artifact `pr_provenance`
  (their fetched detail is in shell closures) — both fold in when the graph lands.
- **NEXT (user-raised): unit tests — GENERAL artifact ops only** (scope per user:
  `command_of_step` is project/graph-edge, NOT here). Test `provision_of_provider`
  coverage, `string_of_provider` rendering, and the drift invariant (each project's
  `pr_provenance` provider ⇒ its baseline provision) as a test not just a ⚠.

**Pipeline map (pre / prepare / run / post — where to read):**
- **pre** `canary spec <pj>` → `print_spec` (`canary_main.ml`) →
  `Canary_project_run.scenarios_of ?policy pr` = `Canary_enumerate.enumerate
  ~policy` (stage 2) over the declared `pr_spec` (stage 1).
  `--by-artifact` → `print_artifacts` (F3).
- **prepare** — NOT a general-interface concern (`pr_materialize` purged
  2026-08-05): tiny-full *assembles* its vendored tree INSIDE its
  `pr_runner_spec` closure (`Canary_tiny_workspace`, tiny-factory machinery);
  sqlite places nothing (its lib/binding come from canary *actions*).
- **run** `canary action <pj>` → `run_project_run` → `pr_runner_spec a` →
  `derive_steps` (`canary_step_builder`) → `Canary_local_runner` executes the
  build/fetch/**probe** actions → writes `scenarios.tsv` (F1). For tiny-full (all
  Vendored) the run is only PROBE; for sqlite it is build/fetch + probe.
- **post** `canary spec <pj>` (re-run) → `load_scenario_post` + `print_spec`/
  `print_artifacts`.
Project bundles: `canary_project_tiny.tiny_full_run` / `canary_project_sqlite.sqlite_run`
(`Canary_project_run.project_run` records).

**KNOWN GAP — honest status (2026-08-04): the graph enumeration is UNWIRED.**
`close_deps`/`dep_mode`/`node_of_assignment` appear in **nothing but the unit
test** — no project enumerates via the graph. So today's scenarios are the FLAT
stage-2 product only: tiny-full 29 (mutation axis), **sqlite 2** (provision axis:
lib Fetched|Built, one version, no mutations). What "graph discover" would add and
does NOT yet exist: the deploy mismatch (binding built @lib.vX, run @lib.vY —
needs `close_deps Independent` + ≥2 lib versions), external/ambient dep discovery
(libc/pthread via `ldd`), and richer per-project version axes. sqlite is small
because it declares one version + no mutation, AND the graph half is scaffolding.
**This is the real A5/stage-3-live work — the promised capability, not delivered.**
- **F4 — run-closure (realised graph) view** *(gated on the node graph, §A / A5)*:
  two kind-grouped views — `spec <pj>` = the DECLARED graph (potentials: a source
  that *can* build a lib sits in the source group), and a post-run **closure** read
  off `run_state`/`actions.log` (realised: the lib built-from-source promoted into
  the lib group with its `built_from` edge, source retained). Potential vs realised;
  a `closure <pj>` / `status --graph` renders the run view.
- **F5 — rewire `canary scenarios` onto the core enumeration.** Diagnosis
  (2026-08-04): `canary_scenario_coverage.ml` (102 L) is a **parallel** impl with
  ZERO refs to `Canary_enumerate` — it walks each project's `derive_steps` action
  set against a hand-listed `stage` catalogue, keyed to a hardcoded
  pre-convergence project list (hence `Unknown project tiny-full`). The *view*
  (which store-lifecycle stages a project exercises — the provision-axis
  projection) is worth keeping and is NOT redundant with `spec`'s good/bad set;
  the *plumbing* is stale. Clean end-state: derive stage coverage from the
  enumerated assignments' provision axis (`provision_of_actions`/`store_actions`,
  ssot §4.2) so it's core-backed and knows every `project_run` project — then the
  hardcoded lookup + parallel catalogue retire together.

### G. Design-doc consolidation (2026-08-04)

Done this pass — `doc/canary/design/` now 10 docs (4 retired this session):
- retired `enumeration_graph.md` (→ `dynamic_enumeration.md`).
- retired `harness_canary_orthogonality.md` + `derived_vs_hardcoded.md` — their live
  principles (two engines; store/runner/producer factoring; derived-vs-hand)
  absorbed into `dynamic_enumeration.md`; stale tiny1 status entries dropped.
- retired `project_definition.md` (superseded draft; the detection-first design
  shipped via `project_run`+`enumerate`+`canary_detect`) — 6 source-comment
  citations + doc links repointed to `ssot.md` §6.1.
- `scenario_coverage.md` kept; `ssot.md` §4.2 already cross-links it.

**To-do (per user): regenerate `tiny.md` from current code** — the existing doc has
a reframing banner but is otherwise tiny1-era; a fresh writeup should describe
tiny-factory / tiny1 / tiny-full + the enumerate engine as they stand.

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
