# Worklog — 2026-08

## The tiny-full arc (2026-08-01 → 2026-08-03)

Turned tiny-full into a real, mutation-agnostic project driven by a
project-agnostic runner. Principle now in [ssot §4.2.5](../design/ssot.md);
this is the phase-by-phase build history (moved out of `status.md` §1a on
2026-08-03 when the arc completed).

**Core principle.** The tiny-full runner knows *nothing* about mutations. A
bad artifact is a build at a **bad-quality version** (its badness is identity,
not a type the runner dispatches on). tiny-full **declares** vendored artifact
resources; **canary computes** detection, expectation, and the fail-fast
collapse. The factory (tiny1) stays the ground-truth **oracle** for the
cross-check.

| concern | owner | knows the mutation? |
|---|---|---|
| enumeration (assign versions to artifacts) | `canary_enumerate` | no |
| runner (materialize → run) | `run_project_run` + `project_run` | **no** |
| materializer (tag → concrete artifact) | `canary_tiny_workspace` | yes (hidden) |
| oracle (tag → expected verdict) | factory (tiny1) | yes (cross-check) |

### Phases (all shipped)

- **P0 — naming + `action tiny-full` as a project** (`b6ca255`, `4b003f3`).
  Named tiny-factory / tiny1 (`tiny run`) / tiny-full (`action tiny-full`);
  moved tiny-full off the `tiny` subcommand family onto the general `action`
  dispatch (peer of sqlite/z3/llvm).
- **P1 — agnostic driver over variant tags** (`3e1bc83`). The runner loop
  references only an opaque tag; all mutation/name knowledge confined to the
  materializer.
- **P2a — tag folded into the typed version identity** (`b943b1a`, grain (i)
  full unification). `canary_enumerate.placement.version` became `build_id =
  { channel; quality }`, `quality = Good | Bad of tag`. The Phase-1
  `variant_tag` side channel deleted; a bad artifact is `dev#Bs.1`.
- **P2b — contract-derived (agnostic) expectation** (spike `5bcce8e`,
  complete `c96eb1f`). `lower_expectation_agnostic` derives the expectation
  from the bindings table + (action, loc) alone — no per-scenario
  `violates`/`has_manifest` — unioning every contract's `From_artifact` inputs
  and letting `predicted_contains_any_v2` discover the break. The
  empty-prediction question resolved with an **additive** `Expect_compat_derived`
  variant: prediction empty ⇒ expect success, non-empty ⇒ expect the failure.
  z3/llvm keep `Expect_compat_failure` (zero risk). tiny-full now runs with no
  oracle.
- **P3 — vendored resources + combinations.**
  - Correction: reverted an `earliest_bad_of` collapse-key — tiny-full does
    *not* predict the collapse; canary computes it by running. `placement`
    became `Vendored`.
  - Materializer **emit → assemble → run** (`94fa841`, `dd912a7`, `7ac0cea`).
    Emit = *extract* each built artifact variant from the per-scenario
    workspaces `prepare-all` already builds (`resources/<id>/<tag>/`); assemble
    = overlay chosen variants onto the unmutated-witness base (no rebuild);
    run = the normal path over the assembled tree. Finding: vendored resources
    are the **built** artifacts (lib / ocaml-cstubs / cext); **source folds
    into lib**. `action tiny-full` full single-bad sweep: **20/20** via
    assembly. Deploy mismatch (binding built vs good lib, overlaid on bad lib)
    comes for free and canary catches it (c4).
  - Combinations (`d627890`). `tiny assemble-combo <TAG>...` assembles several
    bad artifacts — the scenarios *beyond* tiny1 — and runs with the agnostic
    expectation; canary computes the fail-fast collapse. Validated pairs +
    3-way.

### Convergence

- **Step 1 — `canary_project_tiny.ml`** (`ab4bcd4`). The tiny-full PROJECT
  module (peer of `canary_project_z3.ml`): `project` bundle + declarative
  surface + `run`, distinct from the factory that makes the ingredients. Pins
  the `project_run` interface (`{name; artifacts; enumerate; materialize;
  runner_spec}`).
- **Step 2 — the generic runner** (`a620b15`). `run_project_run` is
  project-agnostic: enumerate → materialize → runner_spec → run → report, same
  loop for any project; all specifics in the `project_run` closures.
  `Canary_project_tiny.tiny_full_run` is tiny-full's value (materialize =
  assemble; soname-aware stores via `detect_lib_filename`; agnostic
  expectation). `action tiny-full` routes through it: 20/20. **Additive** —
  z3/llvm keep their raw-script `run_project_multi` untouched.

### Agreed strategy for the rest

New runner drives tiny-full now + simple projects (sqlite) next; heavy
projects (z3/llvm) stay raw-script, migrated last by copy-modify only if ever.

### Superseded exploration (kept for archaeology)

The positive-space count churned during design before the vendored model
settled: raw per-artifact cartesian **2048** → whole-scenario version **64** →
app→binding dependency in `assignment_ok` **58** → then "presence is not a
choice, a project ships its whole declared set" made presence-enumeration a
dead end. The **per-edge version** model (build vs run version = the deploy
mismatch; ssot §4.2.4) and the finding that the instance graph **already
exists** (`artifact_node` + `make_action_graph`) remain live *deferred* design
— see [`dynamic_enumeration.md`](../design/dynamic_enumeration.md) and
[`versioning.md`](../design/versioning.md), tracked in `status.md` §1c.

## 2026-08-03/04 — honest-coverage arc (Fix B → 12/24 → naming unification)

Cold-testing the generic runner revealed the "20/20"/"24/24" was **warm-cache
fake-green**, and the honest number was gated by two bugs. Fixing them took
tiny-full agnostic detection from a real 3/24 to an honest, stable **12/24**
(thin 12/20), cold == warm. Commits, in order:

- **Fix B — run-cache soundness** (`c88a7a9`). A probe writes `probe.log` even on
  failure, so `check_post` ("probe.log exists") served a failed probe as a cached
  success on rerun. The runner now writes a per-step **verdict marker** only when
  the step met its expectation; both skip sites key on it. `canary cache-test`
  guards the invariant (proven to fail under the old condition). Metric stopped
  lying: 3/24 cold == warm.
- **`spec` dry-run** (`e812edb`, `d049349`). A pre-run snapshot over a
  `project_run`: grouped artifacts + enumerated scenarios (delta from baseline),
  no execution. z3/llvm get a read-only variant view via `provisions_of_runner_spec`
  (inferred from which runner_spec closures are set — no code change to them).
  Surfaced 26-enumerated vs 24-run (ctypes aliases cext).
- **Fix A + `:` bug + robust verdict** (`abd9785`, `8ada9d4`). (1) A cached
  artifact now carries its **source** (`subdirs_of_artifact` = built subdir +
  mli/headers), so source-manifested drift is detectable. (2) The assembled dir
  name embedded `binding:ocaml:cstubs`, and `:` is the PYTHONPATH separator, so
  only lib scenarios (no `:`) ever detected — a workspace-naming bug, not a compat
  one. (3) `run_project` returns its status table; the runner derives the verdict
  from it (not the shared, overwritten `run_state.json`) + names non-done steps on
  FAIL. Net 3 → 12/24. Remaining 12 are watchlist-blind (c5/c6/abi/behavior).
- **thin Subset config** (`141c00f`). `--thin`: Stable, single-bad, no
  ctypes/combos → 22 scenarios, 12/20 cold == warm.
- **Naming unification** (`2117d60`, `a1dc6a5`). Born-safe ids — `string_of_id`
  uses `-` not `:`, so `safe_workspace_name` is deleted (safe by construction); a
  display-only `pretty_id` restores the `:` form for `spec`. resource → **cached
  artifact** (ssot term): `cache_artifact` / `cached_artifact_dir` /
  `subdirs_of_artifact` / `artifact_key_of_tag`.
- **Quick hygiene** (`8f1d8bd`). Memoized `detect_pm` (one PM probe per run, not
  ~4× at module-load); swept resource→cached-artifact in the spec-file comments;
  confirmed the `*_latest` sources are an intended-but-unwired channel (kept).

Project-file review recorded in `status.md` §1c (three-tier project-definition
split; the convergence target).

## 2026-08-04 — convergence + views arc (flushed from status.md 2026-08-05)

One-line-each chronicle of the items that lived in status §A/§F while active:

- **A1 per-artifact provisions** (`828e105`) · **A2 point→assignment fold** ·
  **A3a declared `project_spec`** (`5473c8a`) · **A3b sqlite flipped onto the
  algorithm** (`5393cb4`; Built scenario gained the bindings) · **A4 tiny-full
  good+singles from a declared spec** (`aac490f`; `point.mutations` list
  `cbd980b`) — the convergence core proven on both generic projects.
- **Spec/policy split** (stage 1 `project_spec` facts vs stage 2 `'m policy`
  exploration; renames `enumerate_points`/`enumerate`) · **per-artifact
  version axis** (`ps_versions_of`).
- **Node-graph first cut**: M1.0 relocate `artifact_node` (`fa85cd6`), M1
  ext+version+provision (`1f3a24f`), M2/M3 `node_of_assignment` + seam
  cross-check (`64ed970`), `Build_lib` source-edge fix (`11954e8`);
  `dep_mode` + `close_deps` built, test-only (32/32). Then RE-PRIORITIZED:
  parked until the deploy-mismatch work needs two lib instances per scenario.
- **`make_action_graph` as the forward engine**: source-primary
  `Build_binding` (`9b0e76d`), `Build_app ~app_mode` (`01cd05e`),
  project-aware N/A marking (`4b67b52`), Vendored nodes (`c5ea578`),
  `construct` + `execution_plan` (topo view; `0b63f29`, `33dfcb5`).
  Layering settled: the graph is a mid-layer VIEW; `derive_steps` is the
  engine (`dynamic_enumeration.md`).
- **Inspection (F-series)**: F1 `scenarios.tsv` (`db0fe97`) · F2 verdicts in
  `spec` · F3 `--by-artifact` (`7c288c4`) · provenance + typed `provider`
  unification steps 1–3 (`087767b`, `f1f2ad8`, `c0f43b3`) · `spec @all
  [--json]` (`03a2c1e`) · single-source `sqlite_provider` (`d10a875`) ·
  uniform variant view + source-as-artifact-group (`9d904e7`, `edd5d6a`).
- **Design-doc consolidation**: retired `enumeration_graph.md`,
  `harness_canary_orthogonality.md`, `derived_vs_hardcoded.md`,
  `project_definition.md` (absorbed into `dynamic_enumeration.md` /
  `ssot.md` §6.1).
- **Ops**: diagram connectivity invariant muted by default
  (`CANARY_DIAGRAM_CONN=1`; a `step.deps`↔diagram drift in ALL four
  projects, not a run bug) · flavor-1 decoupled from tiny-full (`48afff2`:
  the general run is positive-only; mutations = tiny1's oracle) ·
  `pr_materialize` purged (runner computes `scenario_dir_of`; Fetched is
  version-ambient in scenario identity).

## 2026-08-05 — the faithful-worlds arc (sqlite + tiny-full first)

Milestone: real projects run with a FAITHFUL spec-derived scenario
combination through the generic runner.

- **sqlite Built scenarios probe the BUILT lib** (`8124bc9`): soname symlink
  + `LD_LIBRARY_PATH` repoint; probes PRINT the runtime version and Built
  scenarios ASSERT it (`log_grep sqlite_version=<dotted>`, derived from the
  channel axis) — built-dev verified discriminating (binding compiled
  against system 3.45.1, runs against built 3.46.1). **Finding**: the
  stdlib Python binding's runtime sqlite is Ambient — uv/standalone python
  statically bundles 3.50.4 (`_sqlite3` builtin) — so sqlite exhibits both
  runtime-edge modes (OCaml Independent asserted; Python Ambient observed).
- **Per-provision version universes** (`a4493b0`): `ps_versions_of` per
  `(artifact × provision)`; tiny-full's built-lib variants DERIVED from the
  spec (source-primary resolved the sqlite way: self-contained Built,
  `a_source` display-only); `--thin` = `version Subset [Stable]` config.
- **`pr_enumerate` retired** (`8c2cb74`): `project_run` carries `pr_spec`;
  `scenarios_of ?policy` (the general algorithm) is the only scenario-list
  producer; thin is a RUNNER policy.
- **`spec` lists every scenario in full flat form** (`e428a85`) + placement
  key legend.
- **tiny-full forward API mismatch** (`bf8167c`): `ocaml_dev/` dev cstubs
  consumer (`Tiny.scale` → dev-only `tiny_scale`@TINY_2.0); OCaml binding
  version axis {S,D} → 6 scenarios; binding@dev × stable-lib scenarios fail
  at the probe link and c1 PREDICTS it agnostically (detected xfail);
  binding@dev × built-dev-lib green. The z3/llvm-style demo through the
  generic path, flat form only.
- **xfail surfaced end-to-end** (`fbc2eb3`): `Step_done_xfail` through
  runner/marker-content/run_info/diagram; `action` prints `xfail: <steps>`;
  `spec` marks `✓ xfail`; scenarios.tsv + `--json` carry it.
- **`status` per-scenario for the generic runner** (`b576e44`):
  `variant_start` markers from `run_project`; warm-run seeds logged; cache
  skips render as the pass they are.
- **Terminology**: display unified to `scenario` (`0030700`; ssot §6.1
  scenario ≡ variant ≡ "world"); remaining overload (Sc.N patterns /
  coverage stages) recorded in `design/scenario_terms.md` (`804ae26`) —
  OPEN, no decision.
- **A9 step 1 — dispatch/realization split** (`adb63db`): both generic
  projects are `pr_runner_spec = realize ∘ dispatch` with pure
  `scenario_case` data; general coordinate reads
  (`channel_of`/`bad_placements`) in `canary_enumerate`.
- **A8 — spec as DATA** (`c433f51`): fused `ps_universe` table (artifact ×
  (provision × versions)); `pr_provenance` an assoc table + `provenance_of`;
  `sqlite_providers`/`tiny_providers` single sources.
- **A6 — dead project bundle deleted** (`43c9ef5`): `Canary_project.project`
  was write-only; `project_run` IS the top-level identity.
  `canary_scenario_util.ml` folded back into the tiny factory;
  `canary_enumerate`'s stale fold-into note reversed.

## 2026-08-05 — A5: z3 + llvm onto the generic path

Order settled A5-before-A7 (migration needs no expectation change; A7 is
best done once all styles sit on ONE runner). z3 first, llvm the shape
verbatim; both verified live end-to-end. Every `spec`/`action` project is
a `project_run` now; ssl is `run_project_multi`'s last consumer.

- **Phase 1 — declared spec, no behavior change** (`b97060b`): `z3_spec`
  ps_universe (source F@{S,D}; lib F@S|B@D; wheel F@S, constant row) →
  THREE assignments → the current 2 variants as scenarios (source-primary
  prunes source@S × lib B@D; the two all-Fetched assignments collapse
  under the Fetched-ambient identity rule — the dedup is LOAD-BEARING,
  and stable-first universe order keeps both surviving representatives
  channel-coherent). NEW projects-layer pin suite
  `canary_projects_test.ml` (`project-test` runs it via
  `run_tests ~extra`; the pure suite sits below `canary_projects`).
  **Finding — binding-follows-chain**: the OCaml binding cannot be an
  enumerated axis (any single option is wrong for one chain; both options
  mint the 2 mixed mismatch worlds) — it rides the realization until
  graph-structural version propagation; A5 confirmed as that work's
  forcing function.
- **Phase 2 — dispatch/realize + z3_run** (`cf44d1e`): `scenario_case =
  Dev_chain | Stable_chain`; dispatch reads the LIB placement ONLY (the
  ambient source channel is no chain signal); realize = the existing
  `mk_runner_spec ~source` verbatim (command churn zero); `z3_run :
  distro → project_run` (+ providers table; workspace ignored — guarded
  external build trees). `action z3`/`spec z3` (+ `@all`/`--json`/
  `--thin`) generic; retired `run_z3`, z3's variant view, z3-only
  `--quick`/cache plumbing. `pr_mismatch_probes = []` DELIBERATE: the
  stable-wheel demo is probe-code-vs-BINDING and scenario-invariant (the
  Ambient-edge finding) — no (consumer × channel × direction-vs-lib) row
  could fire. **Core bug found+fixed**: `Subset` config levels were taken
  VERBATIM — `thin_policy` fabricated `lib Built@Stable` worlds no
  realization backs; Subset now INTERSECTS the declared universe
  (pinned: `enumerate.subset_intersects_universe`).
- **Phases 3+4 — locations + expectations verified** (`ba71517`): full
  `action z3` through the generic runner — 3 probe_lib locations
  (793/793/705 Z3_ symbols) inside the realization; parser_context fires
  `xfail` in BOTH chains (scenario-invariance measured); C-symbol
  cross-check 776/793/0; `spec`/`status` join the verdicts.
- **Phase 5 — llvm same shape; variant view retired** (`b3444cb`):
  `llvm_spec`/dispatch/realize/`llvm_run` = the z3 shape verbatim; pins
  factored into the parameterized `two_chain_pins` generator. Opcode.
  UncondBr fires `xfail` in the STABLE chain only — chain-LOCAL vs z3's
  scenario-invariant demo: both xfail localities on one runner. RETIRED:
  `run_llvm`/`run_z3`/`source_run_info` + the whole raw variant view
  (`print_spec_variants`, `spec_variants_json_t`,
  `provisions_of_runner_spec`, `variant_kinds`, `source_repo_*`).

## 2026-08-05 — A7: the expectation unification (3-way → derived + oracle-combinator)

End state: every REAL project derives via the ONE framework lowering
(`lower_expectation_agnostic`); the oracle is a tiny-factory combinator;
zero hand-written failure expectations remain; xfails name their
contract on every surface. sqlite's `log_grep` reclassified OUT of the
unification as a WORLD-IDENTITY ASSERTION (positive invariant — "the run
really exercised the enumerated world" — opposite polarity from an
expected failure).

- **Phase 1 — per-contract prediction API** (`a79e7bf`):
  `predicted_by_contract_v2` (fired registry rows × substrings;
  `predicted_contains_any_v2` = its flatten, pinned identical) +
  `skipped_checks`; the runner's two compat branches share one
  `derived_predictions` helper logging one `compat_predicted` per fired
  contract + `contract_skipped` per disabled entry (plan.md Step 6c TODO
  discharged).
- **Phase 2 — typed contract outcome in the verdict** (`b7ea340`): a
  CONFIRMING contract = a fired row whose own substrings the failing
  output matched; persisted in marker content ("xfail c2",
  prefix-compatible), re-emitted on warm skips, surfaced everywhere
  (`action`/tsv/`spec`: `probe_binding_python[c2]`; `status`:
  `xfail[c2]`). z3 attributes [c2], tiny-full's forward mismatch [c1] —
  different contracts named end-to-end through one mechanism.
- **Phase 3 — z3 + llvm oracle → derived** (`17f3efc`): the
  violates/has_manifest knobs die at real projects; llvm's dev-chain
  exemption dissolves into input-path resolution (PACK-SIDE FIRST per
  input — order load-bearing, pinned) — dev chains derive EMPTY
  predictions ("success expected") while fetched-19 inspects coexist in
  the same scenario dir; stable chains derive the same xfails;
  expectations self-heal if upstream ships the missing API.
  **Finding (a) — shared-opam-switch state is scenario-CROSSING**:
  warm-skipped fetch/pack + live probe = probe compiles against whatever
  the last install left (observed `unexpected_success`; identical under
  the oracle). **Finding (b) — `tiny run` under-reported since xfail
  landed**: the verdict reader counted only `"done"`, so every DETECTING
  scenario read FAIL ("5 PASS, 17 FAIL"); fixed — real oracle state
  **21/22 PASS**, the one red = `type_wrong`'s build-site c6
  (pre-existing; §B inspector question).
- **Phase 3b — oracle = a combinator, not a sibling** (user-settled;
  `4898e85`): `lower_expectation` DELETED from the framework — its
  content decomposed into restrict-to-violated-contracts + gate-on-
  manifestation + strengthen Derived→must-fail, all ORACLE POLICY, now
  composed tiny-factory-locally over the one lowering
  (`expectation_of_entry`). Verified cold on all three oracle paths;
  `type_wrong` still red (the answer-key property: a blind inspector
  goes RED under the oracle where derived would be silently green).
- **Phases 4+5 — ssl derived; world-identity assertion named**
  (`c8e4ab8`): ssl's four hand-written per-variant expects retired — the
  consumer requirement is DATA (`app.requires` mli watchlist), the
  evidence an mli inspect of the fetched binding per variant, c2 +
  the one lowering derive the 2×2 (060_nlv: "⚠ MISSING
  Ssl.native_library_version" → `xfail[c2]`; the rest "no contract
  fired" → ✓ — evidence and outcome adjacent in `status`). ssl's probe
  gained the first binding-side world-identity assertion (switch must
  hold the variant's pinned version — the loud fix for finding (a) where
  version-swapping makes it acutest). `log_grep` named at definition +
  sqlite's use site.

## 2026-08-05→06 — the bottom-up increments arc (post-A5/A7)

Working mode settled (user): no top-down design passes — concrete
increments with the action frame in mind; design consolidation
(A9-step-2, terminology) LAST; every increment ships its harness guard.
The arc's increments, in order:

- **Watchlist ROLES** (`07e81f1`): expected-present vs expected-missing
  split — `inspect_python.py --expect-missing` classifies declared-absent
  names as `expected_missing.confirmed` (binding lag, an xfail-style
  pass) vs `.violated` (name appeared — declaration stale, alarming);
  sqlite's two lag markers moved off the alarming watchlist; `status`
  reads both roles ("watchlist 5/5 · xfail lag get_clientdata,…").
- **type_wrong triaged; oracle 22/22** (`8eef1fe`): TWO compounding bugs —
  the oracle's blanket Derived→must-fail strengthening applied at
  BUILD-class sites (c6 has two shapes: declaration-level lies fail at
  build via EVIDENCE; body-only lies legitimately build green, manifest
  Sc.4) → strengthening now probe-class only; and the runner's
  empty-prediction fallback checked a literal `probe.log` that never
  matches v3 variant-keyed names → resolves via `variant_file`.
  type_wrong: build green, probe xfail UNATTRIBUTED ([] — honest; the
  c6-body gap stays visible in attribution).
- **#44 clang-AST deprioritized** (user; `aa8f31c`): enhancement, not
  milestone work — no real project's derived contracts consume typed
  inputs; type_wrong is correctly oracle-handled. Design note kept: an
  impl/body layer must feed the PROBE firing only.
- **Mechanism CATALOGUE** (`b074df6`): mechanism detail as standalone
  data in base/canary_mechanism.ml (per-mechanism artifact shape, lib
  coupling, checking points, wiring); projects reference by name; `spec`
  displays from the catalogue; `design/mechanism.md` records the
  first-principles research question (derive a better mechanism/PM;
  tiny = one lib × three mechanisms × 22 mutations, the instrument).
- **Tool-routing RATCHET** (`5afa390`): per-file raw-shell-verb baselines
  in projects/; new raw uses fail. Burned sqlite to zero (`178589c`:
  curl_unzip_cmd + cc_shared_lib_cmd + native_lib_probe_cmd). The
  ratchet later caught its own author twice during the install work.
- **Small-residue batch** (`178589c`): `compat`/`verify` resolve
  scenario-keyed caches (token containment + "stable"/"19" →
  "lib-fetched" aliases); #47 drift pins
  (build_flags_match_declared_provisions).
- **Milestone-(b) slice 1 — runtime edges** (`f638f67`, relocated
  `f95f552` per user): the second lib instance as enumeration data. The
  live runtime edge is the BINDING's (no project enumerates an App);
  declared per-ARTIFACT as `artifact_axes.ax_runtime` (spec rows became
  per-artifact RECORDS; `dep_mode` moved to base beside provision);
  general `runtime_pairings_of` resolves per scenario; `spec` prints
  "binding:ocaml → lib B:dev [build-lib ≠ run-lib: DEPLOY] ·
  binding:python → ambient (bundled …)". Co-provider wheels (#45)
  DECLARED Ambient (z3/llvm python) — matching the measured
  scenario-invariant xfails. Undeclared where a static axis can't say it
  (tiny per-variant vendored build-libs; z3/llvm chain-dependent OCaml
  edges).
- **pr_provenance merged into pr_artifacts** (`ef6d7c3`, user analysis):
  THE artifact table — `artifact_decl` rows (identity + provider
  option); provider keys equaled pr_artifacts in all four projects;
  providers can't live on spec rows (the table is WIDER than
  ps_universe: display-only artifacts carry providers). Parity kept:
  pr_spec / pr_mismatch_probes / pr_runner_spec stay project fields.
- **The ARROW unification** (`ea00d65`, user): provider → action →
  artifact; FETCH IS THE SAME SHAPE AS BUILD (building = the provider is
  itself an enumerated artifact; vendored = no producing action, the
  boundary). `providing_action_of`, dual to `provision_of_actions`,
  pinned consistent over every live table; `spec` renders the arrow
  ("provider: sys-pm … ⟶ fetch_lib"). Next case-forced step: provider as
  an explicit upstream NODE (#45 co-provider = one arrow, two outputs).
- **Build-config divergence slices (i)+(ii)** (`791393e` + guard):
  z3's install is REAL (`cmake_install_cmd`; prefix carries headers +
  z3.pc + Z3Config files + versioned symlink chain; llvm NOT migrated —
  its install() rules touch the opam switch, needs component filtering);
  `status` prints an install-diff note on the staged inspect row (ELF
  soname/rpath/runpath/needed + counts; z3 today "identical" — itself a
  finding). Prefix REQUIRED at compile time + empty-expansion shell
  guard (an empty --prefix would fall back to /usr/local — canary must
  never global-install; fetch actions are the only intended
  global-store writes, typed via store_behavior).
- Also filed (user): version definitions/printers centralization (§E),
  env/PATH discipline utility (§E, the born-safe-`:` lesson), build-for-
  install as a §B failure class with slice (iii) open.

## 2026-08-06 — A5 residue arc (ds-workflow branch)

Seven items landed bottom-up, each guard-pinned (53/53 project tests,
107/107 artifact tests throughout). The `source_repo` type shed its last
build-capability booleans; the OCaml binding joined `ps_universe`;
version concepts unified in `Canary_basic`; the dep_mode value source
landed on the provider; world-identity assertions became typed data;
Ambient step dedup shipped.

### #47: `has_build_lib` / `has_build_binding` → provision axis

Both fields removed from `source_repo`; the type is now pure data (remote
URL, version, ref, locals, sys deps — no build-capability flags). z3/llvm
`mk_runner_spec` takes explicit `~build_lib:bool` and `~build_binding:bool`
parameters passed from `realize` (`Dev_chain` → both true). CI passes them
directly instead of mutating the source record. The
`build_flags_match_declared_provisions` pin retired (now a tautology).
`cmake_build_binding` stays as a finer-grained CI knob (defaults to
`build_binding`; CI overrides both independently).

### (iii) Binding-follows-chain

The OCaml binding joins `ps_universe` with `~follows:a_lib`. `ax_follows`
is a universal version constraint on `artifact_axes` — all provisions, not
just Built. The follows constraint in `assignment_ok` prunes cross-channel
mismatch pairs (dev binding over stable lib / stable binding over dev lib),
yielding exactly the 2 coherent scenarios. Threaded through
`enumerate_points` → `run_config` → `enumerate`. Two new test pins
(`z3.binding_follows_chain`, `llvm.binding_follows_chain`).

### Version definitions + printers centralize

`string_of_channel` + `string_of_version` added to `Canary_basic` (where
the `channel` and `version` types are defined). `source_repo.version`
changed from `string` to `Canary_basic.version`; `build_id` rebased from
`{channel; quality}` to `{version : Canary_basic.version; quality}` with
`good` kept as a backward-compat wrapper. All 5 inline `Dev→"dev" |
Stable→"stable"` printers killed, routed through
`Canary_basic.string_of_channel`. `version_printer_ratchet` guards against
regression. The deeper unified version identity stays in
`design/versioning.md`.

### (ii) dep_mode value source — self-contained provider

`Lang_pkg` gained `self_contained : bool`. `dep_mode_of_provider` maps
`self_contained = true` → `Some (Ambient "...")`. Three pip wheels
declared self-contained (`z3-solver`, `llvmlite`, `sqlite3 stdlib`).
Named provider values shared between `pr_artifacts` and `ps_universe` so
`ax_runtime` is derived rather than hand-written. `providing_arrow_pin`
extended to verify the self-contained→Ambient invariant. The `self_contained`
flag is the stepping stone for the full co-provider model (one provider →
two independently testable artifacts).

### §E Polish items → backlog

10 polish items (Env/PATH utility, version printers, tool-routing ratchet,
tri-view command, factory comment sweep, full-lazy detect_pm, wire latest
channel, scenario names, terminology sweep, "scenario" overload audit) moved
from status.md §E to backlog.md — all no-hurry.

### A7 residue — typed `asserts` field

`runner_spec.asserts : (action * location option * string) list` added.
`with_world_asserts` helper wraps probe commands with `grep -qF` checks.
`derive_steps` injects assertions for matching `(action, loc)` entries in
`Probe_lib` and `Probe_binding` expansions. sqlite's `log_grep` migrated
from `~log_grep:(Some version_line)` on `probe_ocaml_env_cmd` to the typed
field — the first consumer. `empty_runner_spec` defaults `asserts = []`.
Spec display deferred (polish); ssl migration and z3/llvm world assertions
deferred (need per-chain version identity).

### Ambient-edge step dedup

The runner in `run_project_run` identifies Ambient consumers from
`runtime_pairings_of` and routes their probe steps to a shared
(scenario-invariant) `output_dir` (`"<project>/-ambient"`). The first
scenario runs and caches; subsequent scenarios hit the verdict marker.
sqlite's python probe runs once instead of 3 times; z3/llvm wheel probes
run once instead of 2 times. Non-Ambient steps unaffected.

## The pattern-based enumeration arc (2026-08-07 → 2026-08-08)

### Module split + tree walk

Split `Canary_enumerate` into three modules:
- `base/canary_artifact.ml` — artifact identity types, project_spec
  (renamed from canary_artifact_api.ml, merged with identity types)
- `action/canary_project_spec.ml` — artifact_row builder, build_deps_of
- `action/canary_enumerate.ml` — enumeration engine

`enumerate_tree` (tree-structured dependency walk) fixed:
- `is_root` inverted (was checking followers-lead, now checks artifact-follows)
- `build_deps_of` checks source-is-declared (sqlite no-source case)
- Child merge uses cartesian product with dedup
- Dead branch removed (both arms of lib-provision check were identical)
- Renamed to `enumerate_assignments`

### Pattern-based enumeration

`action_catalogue` — 11 typed action signatures (consumes, produces, version rule).
`chain_of_assignment` — derives ordered action chain from assignment provisions.
`patterns_of` — enumerates (chain × assignment) pairs; chains are the scenarios,
assignments are version coordinates. Wired as primary via `scenarios_of`.
`scenarios_with_patterns` available for consumers that need chains.

Pattern classification: `scenario_pattern` type (7 variants), `pattern_of_assignment`.

### Terminology

`canary scenarios` CLI → `canary stages`. `canary_scenario.ml` marked LEGACY.
`assignment` = internal term for version coordinates; public term = "scenario coordinates."

### Tests

Audit expanded to 11 cases with pattern annotations. 5 pattern group tests (G1-G5).
Patterns-of smoke test (P1-P2). 56/56 pass.

### Bug fixes

`Poly.equal` on closures in `merge_inspect` (canary_action_table.ml) — fixed by
using `inspect_note` as proxy. `action sqlite` now works end-to-end.

### Docs

`algorithm_explainer.md` rewritten — full pipeline walkthrough with z3 example.
`scenario_coverage.md`, `ssot.md`, `dynamic_enumeration.md` updated for renames.
Status flushed. Dead code identified: `string_of_firing_site`, `nodes_of_action_graph`,
`path_id_of_node`.

### Open (next)

- Merge `action_sig` into `canary_action.ml`, replace hand-written match functions
- Remove dead code
- Pattern naming bridge (Sc.N ids → concrete scenarios)
- F5: replumb `canary stages` through enumeration engine
- `patterns_of` chain dedup (same assignment with multiple terminals)

## 2026-08-16 — M1 completed (flushed from status.md)

The whole Framework-hardening milestone closed. Twelve items, all shipped
with the suite green at each step; final state 65 project + 107 artifact
+ 14 PM tests, `make canary-test` / `make canary-post-check` as the
post-change convention.

- `run_project_spec` extraction — shared between CLI and tests
- `action_sig` merge — `consumes_of_action`/`produces_of_action` derived from catalogue
- Dead code — `nodes_of_action_graph`, `path_id_of_node`, `string_of_firing_site`
- Post-check convention — `make canary-test`, `make canary-post-check`, CLAUDE.md
- `patterns_of` dedup
- F5: `canary stages` replumbed through enumeration (`covered_actions_of` in `canary_project_run.ml`)
- Project registry (2026-08-12) — `Canary_registry.all_projects` THE name SSOT; zarith/cairo/libffi migrate to `project_run`; `run_legacy` + sqlite's pre-action-table specs deleted
- ssl store-pin migration (2026-08-12) — `Lang_pkg.versions` pins → 2 enumerated scenarios; registry's `Multi` kind deleted
- z3 store-pin migration (2026-08-12) — stable binding pinned 4.16.0, dev Publish pin-checked; FINDING: official z3 HEAD's OCaml binding broken upstream → arbipher fork as the Dev source
- Typed template dispatch (2026-08-14) — `canary_action_templates.ml`: 19 typed constructors replace string-keyed primitives (all 37 sites converted)
- Project-layer reorganization + lean bin (0c6d5b8, 2026-08-14) — `canary_runner.ml`/`canary_batch.ml`; status/spec/scenario helpers + `run_with_*` out of the bin into lib
- Module-init side effects (2026-08-14) — `detect_pm` per-call everywhere (memoized internally)

The one item that outlived the milestone — the general pre/post-checking
picture — moved to M2 step 10 (the mechanism issue it waited on is now
solid).

Also flushed: the Docs checklist's two completed entries —
`project/` doc directory (2026-08-12) and `repo_model.md`
(2026-08-15/16, e40c73e → cd9e341: `contrib_root`, `Repo` provider
unification + `Repo_axes` per-channel source repos, `Git`/`Hg`/`Tar`
remotes, repo-contents invariant; retired the dead `has_build_*` code).

## 2026-08-16 (cont.) — repo-model C1+C2: the 3-way landed, and the cold audit

The 3-way arc closed (roadmap C, `repo_model.md`; commits `cd9e341` C1,
`19077a8` C2, `dde3f10` llvm fix). Flushed here per the status
convention (status_project.md §3 keeps the pointer + the living
to-dos; the per-project scenario counts moved to its §1).

**C1 — zarith (light, pattern-A)** (`cd9e341`): `Repo_axes of
source_repo list` provider (a repo FAMILY covering the channels of one
artifact), `versions_of_provider` widened to version records (channel
PRESERVED — `Canary_basic.pinned`'s hardcoded Stable would have broken
`--thin`), pattern-A's `t.source : option` → `t.sources : list` with
per-scenario worktree dispatch (`source_for_assignment` — the
realize ∘ dispatch idiom over the SOURCE placement). zarith: 2
scenarios (source-fetched-1.14 / source-fetched-master); cairo/libffi
sources became identity-bearing as a side fix (their dirs renamed —
honest, the worktree IS pinned to the declared ref).

**C2 — z3/llvm (heavy)** (`19077a8`): the arbipher forks became labeled
third repos (`label = Some "arbipher"`, identity-bearing
`id = "arbipher"` — marker-style, like "latest"; the 2026-08-13
fork↔official cache collision resolved by design), source rows →
`Repo_axes [stable; latest; fork]`, `z3/llvm_source_for_assignment`
dispatch on the SOURCE placement (the pre-C2 lib-channel proxy
retired; the dev/stable ROW split stays driven by the lib provision in
`realize_from_rows`). `assignment_ok`'s Built-lib↔source coupling
relaxed from exact-build_id to CHANNEL equality — exact-id was right
while sources were ambient; with per-repo pins it would have killed
both dev build chains. 5 scenarios each (3 all-Fetched source worlds +
2 dev build chains); `--thin` = the stable chain only. Pins:
two_chain_pins now locks the 3-way shape (5 scenarios / 5 ids / 2 dev
chains / source-id dispatch correspondence), integration_smoke 3→5.

**The cold audit** — the scenario-dir rename forced every step cold,
and the warm `.ok` markers had been skipping broken steps since the A5
era. Five masked bugs surfaced and were fixed (all OURS — the checked
projects were innocent throughout):
1. z3's Configure row had dropped `-DZ3_BUILD_EXECUTABLE=OFF` in the A5
   table migration → `cmake --install` died on the never-built shell
   binary. The fork's old cmake cache was immune (cache
   first-write-wins); the fresh official clone exposed it. Fixed: the
   row carries the canonical what-is-built flags.
2. The `Cmake_install` template wrote `install.ok` UNCONDITIONALLY
   (the bug-B class: a failed install cached as success) → marker now
   conditional on install + layout-inspect.
3. `prefix_layout_inspect_cmd`'s printf fed the unquoted two-word
   "regular file" to `%d` (word-splitting) — the inspect had never
   actually run for z3's latest chain. Substitutions quoted.
4. llvm's table rows probed `root/llvm/CMakeLists.txt` at REALIZE
   time, before the fetch — a fresh `_out` clone always resolved the
   cmake source to `root`. This was the real bug behind the 2026-08-12
   "official clone unusable" finding (misdiagnosed twice — the clone
   was always fine). Fixed: every llvm repo is the monorepo, cmake
   source = `root/llvm` unconditionally (`dde3f10`).
5. `contrib/z3-all/z3-stable` (declared by the stable repo's locals)
   didn't exist — created at the pinned commit bd3e722.

General lesson (recorded in status_project.md): a scenario-dir rename
IS a cold-run audit — warm markers mask spec drift.

**Verification**: `action z3` 5/5 PASS (both dev chains cold-built, the
install genuinely verified for the first time since A5); `action llvm`
5/5 PASS + 3 confirmed xfails (Opcode.UncondBr in the three
stable-binding worlds; the resumed run after a machine restart cost
nothing — the clone, markers, and ninja's incremental state persist).
The verdict-matrix regression pin (cold/warm determinism) is filed as
the follow-up to-do.
