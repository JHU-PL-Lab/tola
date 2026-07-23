# Canary projects — status matrix

Compact per-project status: which projects exist and what machinery each
exercises. Updated per landing. Companion to (not a replacement for)
[`design/new_project.md`](design/new_project.md) — that doc is the
portfolio/narrative + candidate queue; this is the capability tracker.

Legend — **fetch_lib**: `Derived` (from `store_config`) | `Raw` (closure).
**surface**: the checking-points type (`Canary_surface`) | `api_source`
(pre-redesign) | `—`. **variants**: version/source variants run via
`run_project_multi` | `—`. **detection**: S5a trivial detector runs on
every executed step for all projects.

| project | level | pattern | fetch_lib | surface | variants | detection | local / CI |
|---|---|---|---|---|---|---|---|
| **tiny** | C | own factory | Raw | `api_source` | 22 scenarios | S5a | ✓ / ✓ |
| **z3** | B | hand (source-build) | Raw | `api_source` | dev / stable | S5a | ✓ / ✓ |
| **llvm** | A+C | hand (source-build) | Raw | `api_source` | dev / 19 | S5a | ✓ / ✓ |
| **sqlite** | A | hand | **Derived** | — | — | S5a | ✓ / ✓ |
| **zarith** | A | `pattern_a` | **Derived** | — | — | S5a | ✓ / ✓ |
| **ssl** | B | hand (variant) | **Derived** | — | 2×2 (0.6.0/0.7.0 × core/nlv) + native probe | S5a | ✓ / ✓ |
| **cairo** | A | `pattern_a` | **Derived** | — | — | S5a | ✓ / — |

Notes:
- **fetch_lib Derived** landed via S4a (`pattern_a` + sqlite); it lifted
  zarith/ssl/cairo at once. z3/llvm/tiny stay `Raw` (not migrated —
  z3/llvm deliberately untouched; tiny is the regression fixture).
- **surface** is unpopulated on the Derived projects: their watchlists
  still ride explicit `inspect` closures (or `pattern_a`'s `t` fields).
  Moving them to `Canary_surface` waits on the detector grow (S5) that
  actually reads it. See [`design/project_definition.md`](design/project_definition.md) §3.4.
- **variants** on a Pattern-A project (same lib, 2 opam binding versions)
  landed as **ssl** (consolidated 2026-07-23 — the variant form *is* the
  project; the old single-version pattern_a ssl is retired, its native-lib
  symbol probe folded in). 2 binding versions × 2 apps, realized by
  swapping the ssl version in the shared switch per variant (fast, no new
  OCaml switch). `Ssl.native_library_version` (added 0.7.0) is the drift;
  `app_nlv × 0.6.0` is the one expected failure. Run: `canary action ssl`,
  view with `canary status ssl`.
- **`canary status <project>`** prints the per-variant × per-step verdict
  matrix from `actions.log` (the `run_state.json`/`result.html` collapse
  variants). Works for any project; expected failures render `✓xfail`.
- **cairo CI**: `canary action cairo` green locally; CI job wired in
  `canary_run.ml` but not yet exercised on a runner.
- **Re-runs are cache-powered (safe).** A step is skipped when its
  `output_dir` exists and its `check_post` passes (marker / `probe.log` /
  `inspect.json` present). Measured on ssl: first run 16.7s, re-run 0.55s
  — a fully-cached re-run executes *nothing* (no `opam install`, no
  compile), so the shared-switch version state is irrelevant. Full-cache
  re-run and full-clear fresh run are both correct; only a hand-*partial*
  cache with the shared switch could probe the wrong version.
- **Source-building path convention** (matters only for source-built
  projects — z3/llvm; Pattern-A projects use opam binaries):
  source at `~/code/contrib/<project>-all/<project>`, build result at
  `~/code/contrib/<project>-all/build/<tag>` (per-tag). z3/llvm currently
  use the un-tagged `…/build` (one tree shared across variants) — to be
  updated when we source-build variants. See the TODO in
  `tool/canary_artifact_source.ml:mk_locals`.
