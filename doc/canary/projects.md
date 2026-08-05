# Canary projects — status matrix

Compact per-project status: which projects exist and what machinery each
exercises. Updated per landing. Companion to (not a replacement for)
[`design/new_project.md`](design/new_project.md) — that doc is the
portfolio/narrative + candidate queue; this is the capability tracker.

Legend — projects are described by **dimensions**, not "Pattern A–F"
(those are an opam-ecosystem label; see
[new_project.md §0](design/new_project.md)).
**origin**: `System` (distro pkg) · `Built` (canary compiles from source) ·
`Vendored` (pre-built cached artifact) · mix. **discovery**: `Conf`
(conf-*/pkg-config) · `Locator` · `n/a`.
**coverage**: `positive` (happy-path) · `+failure` (a version mismatch is
predicted; since A7 every prediction is *derived* and contract-attributed,
e.g. `xfail[c2]`) · `matrix` (multi-scenario grid).
**runner**: `project_run` (the generic path — `pr_spec` data table →
`scenarios_of` → `realize ∘ dispatch` → `derive_steps`) · `raw runner_spec`
(`run_project_multi`) · `Pattern A` (~40-line declaration) · `factory`
(tiny1's own harness). **fetch_lib**: `Derived` (from `store_config`) ·
`Raw` (closure). **surface**: checking type (`Canary_surface`) ·
`api_source` (pre-redesign) · `—`. **scenarios**: what one full run
enumerates.

| project        | origin            | discovery    | coverage             | runner             | fetch_lib   | surface      | scenarios       | local / CI |
| -------------- | ----------------- | ------------ | -------------------- | ------------------ | ----------- | ------------ | --------------- | ---------- |
| **tiny1**      | Built (own C)     | n/a          | oracle matrix        | factory            | Raw         | `api_source` | 22 (**22/22**)  | ✓ / —      |
| **tiny-full**  | Vendored + Built  | n/a          | matrix               | **`project_run`**  | n/a         | `api_source` | 6               | ✓ / —      |
| **sqlite**     | System + Built    | Conf         | matrix               | **`project_run`**  | **Derived** | —            | 3               | ✓ / ✓      |
| **z3**         | Built + System    | n/a          | +failure `xfail[c2]` | **`project_run`**  | Raw         | `api_source` | 2               | ✓ / ✓      |
| **llvm**       | Built + System    | Conf/Locator | +failure `xfail[c2]` | **`project_run`**  | Raw         | `api_source` | 2               | ✓ / ✓      |
| **ssl**        | System            | Conf         | +failure `xfail[c2]` | raw `runner_spec`  | **Derived** | —            | 2×2             | ✓ / ✓      |
| **zarith**     | System            | Conf         | positive             | Pattern A          | **Derived** | —            | —               | ✓ / ✓      |
| **cairo**      | System            | Conf         | positive             | Pattern A          | **Derived** | —            | —               | ✓ / —      |

Notes:
- **Four projects are on the generic path** (tiny-full, sqlite, z3, llvm)
  as of 2026-08-05 (A5). Each declares a `pr_spec` data table and the
  general enumeration produces its scenario list — no hand-built scenario
  list can exist (`pr_enumerate` is retired). `ssl` is the last
  `run_project_multi` consumer; zarith/cairo are Pattern A. Tier table in
  [`status.md`](status.md) §1c.
- **Expectations are unified** (A7, 2026-08-05): every real project
  derives its prediction through the ONE lowering
  (`lower_expectation_agnostic` — evidence-based, contract-attributed), so
  a `+failure` row means *canary computed the failure*, not that the spec
  hand-wrote a substring. `Canary_scenario.lower_expectation` is retired
  from the framework; the oracle is now a tiny-factory combinator whose
  only consumer is tiny1.
- **Detection**: the S5a trivial detector runs on every executed step, in
  every project — uniform, so it is no longer a table column.
- **origin is a variant dimension, not a fixed category.** Every `System`
  project could also grow a `Built` variant — canary fetches the library
  source, compiles it, and generates its own conf-package pinned per
  version, checking API compat more rigorously than the ecosystem's
  conf-* maintainers. sqlite is the shipped case (`Fetched` alongside
  `Built@{3.45.1, 3.46.1}`); ssl is the natural next one. Tracked in
  [new_project.md §0](design/new_project.md).
- **sqlite's Built scenarios probe the BUILT lib** — soname symlink +
  `LD_LIBRARY_PATH` repoint, and the probe *asserts* the runtime version
  (a named **world-identity assertion**, outside the expectation
  unification). Python's runtime sqlite is **Ambient** (uv python
  statically bundles its own — observed, not asserted); OCaml's is
  **Independent**.
- **tiny-full has no `fetch_lib`**: it assembles pre-built vendored cached
  artifacts inside its `pr_runner_spec` (overlay, no rebuild). That
  assemble step is tiny-factory machinery
  (`canary_tiny_workspace.ml`) — **not** a template to copy.
- **tiny1 vs tiny-full are different things.** tiny1 (`canary tiny run`)
  is the hand-written mutation **oracle** — 22 scenarios, 22/22 PASS.
  tiny-full (`canary action tiny-full`) is a *project* peer of z3/sqlite
  whose 6 scenarios are spec-derived. Factory *detection* coverage is
  12/24; the undetected 12 are watchlist-blind (c5/c6/abi) and need richer
  inspectors, not plumbing.
- **fetch_lib Derived** landed via S4a (`pattern_a` + sqlite); it lifted
  zarith/ssl/cairo at once. z3/llvm/tiny stay `Raw` (not migrated —
  z3/llvm deliberately untouched; tiny is the regression fixture).
- **surface** is unpopulated on the Derived projects: their watchlists
  still ride explicit `inspect` closures (or `pattern_a`'s `t` fields).
  Moving them to `Canary_surface` waits on the detector grow (S5) that
  actually reads it. See [`design/ssot.md`](design/ssot.md) §6.1.
- **ssl's variant matrix**: 2 binding versions × 2 apps, realized by
  swapping the ssl version in the shared switch per variant (fast, no new
  OCaml switch). `Ssl.native_library_version` (added 0.7.0) is the drift;
  `060_nlv` is the one expected failure, now **derived** from
  `app.requires` + per-variant mli evidence (`xfail[c2]`) rather than
  hand-written. The probe asserts the switch's pinned version — the first
  binding-side world assertion.
- **CI runs the pre-A5 shape.** The `ci_jobs` in
  `projects/canary_run.ml` still build steps from the legacy
  `runner_spec` / `mk_runner_spec` values, not `run_project_run`. CI
  therefore exercises one chain per project, not the enumerated scenario
  set. Jobs wired: llvm-19, z3-dev, sqlite, zarith, ssl, cairo. Neither
  tiny variant has a CI job. Realigning CI with the generic path is A5
  residue (`status.md` §A).
- **cairo CI**: `canary action cairo` green locally; CI job wired in
  `canary_run.ml` but not yet exercised on a runner.
- **`canary status <project>`** prints the per-scenario × per-step verdict
  matrix from `actions.log` (the `run_state.json`/`result.html` collapse
  scenarios). Works for any project; expected failures render `xfail` and
  name their contract.
- **Re-runs are cache-powered (safe).** A step is skipped when its
  `output_dir` exists, its `check_post` passes, **and** its verdict marker
  is present (the marker is written only when the step met its
  expectation — Fix B, 2026-08-03; `canary cache-test` guards it).
  Measured on ssl: first run 16.7s, re-run 0.55s — a fully-cached re-run
  executes *nothing* (no `opam install`, no compile), so the shared-switch
  version state is irrelevant. Full-cache re-run and full-clear fresh run
  are both correct; only a hand-*partial* cache with the shared switch
  could probe the wrong version.
- **Source-building path convention** (matters only for source-built
  projects — z3/llvm; Pattern-A projects use opam binaries):
  source at `~/code/contrib/<project>-all/<project>`, build result at
  `~/code/contrib/<project>-all/build/<tag>` (per-tag). z3/llvm currently
  use the un-tagged `…/build` (one tree shared across variants) — to be
  updated when we source-build variants. See the TODO in
  `tool/canary_artifact_source.ml:mk_locals`.
