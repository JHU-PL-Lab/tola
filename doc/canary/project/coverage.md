# Canary projects — current coverage

Which projects exist and what machinery each exercises. Updated per
landing. Split out of `index.md` in the 2026-08-12 reorganization; the
landing how-to is [`landing.md`](landing.md), bugs/todo in
[`status_project.md`](status_project.md).

---

## 1. Status matrix

Compact per-project status: which projects exist and what machinery each
exercises. Updated per landing.

Legend — **origin** / **discovery** per §1.
**coverage**: `positive` (happy-path) · `+failure` (a version mismatch is
predicted; since A7 every prediction is *derived* and contract-attributed,
e.g. `xfail[c2]`) · `matrix` (multi-scenario grid).
**runner**: `project_run` (the generic path — `pr_spec` data table →
`scenarios_of` → `realize ∘ dispatch` → `derive_steps`) · `simple`
(`Canary_project_run.simple` — the minimal Pattern A wrapper, also a
`project_run`) · `factory` (tiny1's own harness).
**fetch_lib**: `Derived` (from `store_config`) · `Raw` (closure).
**surface**: checking type (`Canary_surface`) · `api_source`
(pre-redesign) · `—`. **scenarios**: what one full run enumerates.

| project       | origin           | discovery    | coverage             | runner            | fetch_lib   | surface      | scenarios      | local / CI |
| ------------- | ---------------- | ------------ | -------------------- | ----------------- | ----------- | ------------ | -------------- | ---------- |
| **tiny1**     | Built (own C)    | n/a          | oracle matrix        | factory           | Raw         | `api_source` | 22 (**22/22**) | ✓ / —      |
| **tiny-full** | Vendored + Built | n/a          | matrix               | **`project_run`** | n/a         | `api_source` | 6              | ✓ / —      |
| **sqlite**    | System + Built   | Conf         | matrix               | **`project_run`** | **Derived** | —            | 3              | ✓ / ✓      |
| **z3**        | Built + System   | n/a          | +failure `xfail[c2]` | **`project_run`** | Raw         | `api_source` | 2              | ✓ / ✓      |
| **llvm**      | Built + System   | Conf/Locator | +failure `xfail[c2]` | **`project_run`** | Raw         | `api_source` | 2              | ✓ / ✓      |
| **ssl**       | System           | Conf         | +failure `xfail[c2]` | **`project_run`** (store pins) | **Derived** | —  | 2 scenarios × 2 probes | ✓ / ✓      |
| **zarith**    | System           | Conf         | positive             | **`simple`**      | **Derived** | —            | 1              | ✓ / ✓      |
| **cairo**     | System           | Conf         | positive             | **`simple`**      | **Derived** | —            | 1              | ✓ / —      |
| **libffi**    | System           | Conf         | positive             | **`simple`**      | **Derived** | —            | 1              | ✓ / ✓      |
| **zlib**      | System + Vendored | Conf        | positive (2×2 lib axis) | **`simple`**   | **Derived** | —            | 2              | ✓ / —      |

Notes:
- **The registry is the single source of truth** (2026-08-12):
  `Canary_registry.all_projects` — `action`/`spec`/`scenarios` each do one
  `List.assoc_opt` lookup; adding a project = adding one entry. All 9
  projects are plain `project_run` entries (ssl migrated off the retired
  `Multi` via store pins, 2026-08-12).
- **ssl's store-pin shape**: 2 scenarios (binding pinned 0.6.0/0.7.0 via
  `Lang_pkg.versions`), each probing BOTH apps as different actions (core
  = Probe_binding, nlv = Probe_app). The 2×2's red cell = scenario@0.6.0's
  `probe_app_ocaml` xfail[c2]. See
  [`store_switching.md`](store_switching.md).
- **The generic path** (tiny-full, sqlite, z3, llvm) is unchanged since
  2026-08-05 (A5): each declares a `pr_spec` data table and the general
  enumeration produces its scenario list — no hand-built scenario list can
  exist (`pr_enumerate` is retired). Pattern A projects (zarith/cairo/
  libffi) ride `Canary_project_run.simple` over their constant
  `runner_spec` (lib + binding Fetched@Stable → exactly 1 scenario).
- **Expectations are unified** (A7, 2026-08-05): every real project
  derives its prediction through the ONE lowering
  (`lower_expectation_agnostic` — evidence-based, contract-attributed), so
  a `+failure` row means *canary computed the failure*, not that the spec
  hand-wrote a substring. `Canary_scenario.lower_expectation` is retired
  from the framework; the oracle is now a tiny-factory combinator whose
  only consumer is tiny1.
- **Detection**: the S5a trivial detector runs on every executed step, in
  every project — uniform, so it is no longer a table column.
- **sqlite's Built scenarios probe the BUILT lib** — soname symlink +
  `LD_LIBRARY_PATH` repoint, and the probe *asserts* the runtime version
  (a named **world-identity assertion**, outside the expectation
  unification). Python's runtime sqlite is **Ambient** (uv python
  statically bundles its own — observed, not asserted); OCaml's is
  **Independent**.
- **tiny-full has no `fetch_lib`**: it assembles pre-built vendored cached
  artifacts inside its `pr_runner_spec` (overlay, no rebuild). That
  assemble step is tiny-factory machinery
  (`canary_tiny_workspace.ml`) — **not** a template to copy (§5).
- **tiny1 vs tiny-full are different things.** tiny1 (`canary tiny run`)
  is the hand-written mutation **oracle** — 22 scenarios, 22/22 PASS.
  tiny-full (`canary action tiny-full`) is a *project* peer of z3/sqlite
  whose 6 scenarios are spec-derived. Factory *detection* coverage is
  12/24; the undetected 12 are watchlist-blind (c5/c6/abi) and need richer
  inspectors, not plumbing.
- **fetch_lib Derived** landed via S4a (`opam_binding` + sqlite); it lifted
  zarith/ssl/cairo at once. z3/llvm/tiny stay `Raw` (not migrated —
  z3/llvm deliberately untouched; tiny is the regression fixture).
- **surface** is unpopulated on the Derived projects: their watchlists
  still ride explicit `inspect` closures (or `opam_binding`'s `t` fields).
  Moving them to `Canary_surface` waits on the detector grow (S5) that
  actually reads it. See [`design/ssot.md`](../design/ssot.md) §6.1.
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
  set. Jobs wired: llvm-19, z3-dev, sqlite, zarith, ssl, cairo, libffi.
  Neither tiny variant has a CI job. Realigning CI with the generic path
  is open — tracked in [`status_project.md`](status_project.md).
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

---


## 2. Landing history

| #   | Project              | Landed     | Notes                                                                                                                                                                                        |
| --- | -------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | z3                   | 2026-03    | Pattern C self-build; local + CI                                                                                                                                                             |
| 2   | llvm                 | 2026-03    | A+C hybrid; local + CI                                                                                                                                                                       |
| 3   | sqlite               | 2026-03    | Pattern A; local + CI                                                                                                                                                                        |
| —   | python primitives    | 2026-04-23 | Sqlite/z3/llvm pip probes, both local + CI                                                                                                                                                   |
| 7   | zarith               | 2026-04-25 | Pattern A. Surfaced `inspect_native.py` GMP `__gmp*` stripping bug                                                                                                                           |
| 5   | ssl                  | 2026-04-25 | Pattern A second datapoint. `Ssl.get_version` doesn't exist in v0.7.0                                                                                                                        |
| —   | Pattern A template   | 2026-04-25 | `canary_opam_binding.ml` 135 lines compresses each spec to ~40 lines                                                                                                                            |
| —   | api-compat milestone | 2026-05-01 | `Expect_compat_failure` derived expectations for OCaml + Python; see [`research/surface_draft/implementation.md`](../research/surface_draft/implementation.md) §2.7                          |
| 12  | cairo                | 2026-07-23 | Pattern A. First project onboarded on the post-redesign machinery (`Derived` fetch_lib via `store_config`; S5a detection runs). `cairo2` 0.6.5, 420 `cairo_` symbols; probe green first try. |
| —   | tiny-full            | 2026-08-02 | tiny-full becomes a PROJECT (peer of z3/sqlite), not a `tiny` subcommand. 6 spec-derived scenarios; forward API mismatch derived as `xfail[c1]`.                                             |
| 3   | sqlite → generic     | 2026-08-05 | sqlite gains a `Built` provision (canary compiles libsqlite3 from two amalgamation versions) and moves to `project_run`. 3 scenarios; Built worlds assert the runtime version.               |
| 1,2 | z3 + llvm → generic  | 2026-08-05 | A5: both move off raw `run_project_multi` onto `project_run` (`pr_spec` + `realize ∘ dispatch`). 2 scenarios each; their xfails are now *derived* and contract-attributed.                   |
| —   | libffi               | 2026-08-11 | Pattern A. First Dynamic_ffi project (ctypes-foreign uses libffi at runtime — Ctypes mechanism vs the Static_c_abi of existing projects). 38 `ffi_` symbols; probe green first try.          |
| —   | registry             | 2026-08-12 | `Canary_registry.all_projects` becomes the single source of truth; zarith/cairo/libffi migrate to `project_run` via `simple`; `run_legacy` deleted everywhere.                                         |
| —   | ssl store pins       | 2026-08-12 | ssl migrates off `Multi`: `Lang_pkg.versions` pins → 2 enumerated scenarios; pin-checked fetch (`SB.pin_check_post`) + world assertions; the 2×2 red cell derives as `probe_app_ocaml` xfail[c2]. |
| —   | zlib                 | 2026-08-20 | First landing chosen by the MEASURED conf-* survey ranking (§G5) rather than by hand. The lib pair needs no build: apt libz 1.3 vs conda-forge libzlib 1.3.2, same soname. Introduces `probe_names_lib` — the probe reads `/proc/self/maps` and the vendored world ASSERTS which libz answered, closing the "pointed but not checked" gap cairo/libffi still have. |
