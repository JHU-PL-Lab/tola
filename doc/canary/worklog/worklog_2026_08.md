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
