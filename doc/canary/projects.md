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
| **ssl** | A | `pattern_a` | **Derived** | — | — | S5a | ✓ / ✓ |
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
  needs a variant-by-opam-version path — the first candidate is an
  ssl 0.6.0 vs 0.7.0 binding×app matrix (`native_library_version` drift).
- **cairo CI**: `canary action cairo` green locally; CI job wired in
  `canary_run.ml` but not yet exercised on a runner.
