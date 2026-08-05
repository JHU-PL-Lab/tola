# Canary projects — status, portfolio, and how to land one

The one project doc: how canary *describes* a project (§1), which projects
exist and what machinery each exercises (§2), which targets are queued and
why (§3), and how a new one lands mechanically (§4–§5).

Companion to [`research/draft.md`](research/draft.md) (manuscript) and
[`research/surface_draft/`](research/surface_draft/) (materials) for the
interface model the candidates collectively stress-test, and to the
[opam survey](surveys/opam.md) (data behind the tier picks).

Two things deliberately live elsewhere: the **PyTorch case study**
(a queued target's pre-implementation plan) is
[`design/project_pytorch.md`](design/project_pytorch.md), and the
**spec auto-generation plan** (#29/#32) is in
[`backlog.md`](backlog.md).

---

## 1. How canary describes a project — dimensions, not letters

canary describes each project by a few **orthogonal dimensions**, carried
as data in `store_config` (taxonomy in [`design/ssot.md`](design/ssot.md)
§6.1). The opam-survey **"Pattern A–F"** ([opam survey](surveys/opam.md)
§2) are an **ecosystem taxonomy** — what packages look like *in the wild*
— **not** canary's internal categories. They're just named points in this
space, and hybrids (e.g. bitwuzla = "A for discovery + C for building")
already break the letters. So throughout this doc we say what dimensions a
project *has*, and reserve A–F for describing opam.

| dimension             | values                                                                                                                  |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **native-lib origin** | `System` (distro pkg) · `Built` (canary compiles from source) · `Vendored` (inside the binding) · `Absent` (pure OCaml) |
| **lib discovery**     | `Conf` (conf-* / pkg-config) · `Depext` (direct depexts) · `Locator` (pkg-config/llvm-config/glob) · `n/a`              |
| **binding origin**    | `Opam` · `Built` (from the lib's source tree)                                                                           |

The survey letters are just points in this space:

| survey label           | dimensions                    |
| ---------------------- | ----------------------------- |
| A `conf-*` indirection | `{System, Conf, Opam}`        |
| B direct depexts       | `{System, Depext, Opam}`      |
| C self-building        | `{Built, n/a, Opam \| Built}` |
| D invisible C stubs    | `{Vendored, n/a, Opam}`       |
| E `clib:` tag          | `{System, clib, Opam}`        |
| F pure OCaml           | `{Absent, n/a, Opam}`         |

Two consequences:

- **A project isn't *in* a pattern; it *has* dimension values.** Pattern
  constructors (the former `canary_pattern_a`) are just sugar that fill a
  common combination — not categories anything branches on. B vs A is a
  single field value (`Depext` vs `Conf`) that barely changes how canary
  tests.
- **Provenance is a variant dimension.** The same library can run a
  `System` variant (conf-*) *and* a `Built` variant where canary fetches
  the source, compiles it, and generates its own conf-package pinned per
  version — letting canary check API compatibility more rigorously than
  the ecosystem's conf-* maintainers do. sqlite is the shipped case
  (`Fetched` alongside `Built@{3.45.1, 3.46.1}`); ssl is the natural next
  one. How this determines *which scenarios* each project covers — and
  marks the rest N/A — is
  [`design/scenario_coverage.md`](design/scenario_coverage.md).

---

## 2. Status matrix

Compact per-project status: which projects exist and what machinery each
exercises. Updated per landing.

Legend — **origin** / **discovery** per §1.
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

---

## 3. Portfolio — two-tier candidate framework

Picked from the opam survey §3 (revdep rankings) and §2 (pattern hot spots).

### Tier 1 — Famous libraries

Native library is the primary artifact; the OCaml binding is one of several
language consumers. Canary's value here is multi-language and multi-PM
interop coverage.

|    # | Library       | OCaml binding                         | Pattern         | Why interesting                                                                                   |
| ---: | ------------- | ------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------- |
|    1 | **Z3** ✓      | `z3`                                  | C (self-build)  | SMT solver, source-built, OCaml + Python + C# + Java bindings.                                    |
|    2 | **LLVM** ✓    | `llvm.{19,dev}-shared`                | A+C hybrid      | `conf-llvm-static` discovery + source build. `Opcode.UncondBr` drift demo.                        |
|    3 | **SQLite** ✓  | `sqlite3`                             | A (+ now Built) | Simplest Pattern A. Python `sqlite3` is stdlib-bundled (cross-PM edge case).                      |
|    4 | **PyTorch**   | `torch` (opam) + `torch` (pip)        | A (binary-only) | pip × opam × apt libtorch matrix. Version range `[2.1, 2.2)` is a real mismatch case. Plan: [`design/project_pytorch.md`](design/project_pytorch.md). |
|    5 | **OpenSSL** ✓ | `ssl` via `conf-libssl`               | A               | OpenSSL 1.x → 3.x API breakage; macOS keg-only paths. Classic "C library that breaks everything." |
|    6 | **FFmpeg**    | `ffmpeg-{avcodec,avformat,swscale,…}` | A (multi-pkg)   | One `conf-ffmpeg` drives a family of binding packages. Tests "one conf, many binding artifacts."  |

### Tier 2 — Tricky OCaml bindings

Library isn't necessarily a household name, but the packaging exposes
structural cases canary should model.

|    # | Library             | OCaml binding                 | Pattern        | Tricky-factor                                                                                                           |
| ---: | ------------------- | ----------------------------- | -------------- | ----------------------------------------------------------------------------------------------------------------------- |
|    7 | **GMP** ✓           | `zarith` via `conf-gmp`       | A              | 25 revdeps — most-used Pattern A. Template-worthy.                                                                      |
|    8 | **libev**           | `lwt` (optional `conf-libev`) | A + optional   | `depopts: conf-libev` + `%{conf-libev:installed}%`. First real test of optional-C-dep modelling.                        |
|    9 | **cvc5**            | `cvc5`                        | C (self-build) | SMT solver sibling of z3. Richer conf-set (`conf-cmake` + `conf-g++` + `conf-gmp`).                                     |
|   10 | **bitwuzla**        | `bitwuzla-c` + `-cxx`         | C + A hybrid   | Vendors the solver but links system GMP via `conf-gmp`. The hybrid case neither pure A nor pure C covers.               |
|   11 | **MariaDB / MySQL** | `mariadb` via `conf-mariadb`  | A+C hybrid     | Database client; conf discovery + source build; cross-PM (apt vs brew). Sibling to SQLite, very different shape.        |
|   12 | **cairo** ✓         | `cairo2` via `conf-cairo`     | A + optional   | `freetype` is a depopt; same optional-dep pattern as lwt/libev but in graphics, choice changes runtime glyph rendering. |

### Sequencing recommendation

Each addition should compound into the natural template shape without
committing to the template up-front:

1. ✓ Finish batch-1 Python side — sqlite stdlib, z3-solver, llvmlite.
2. ✓ Add **zarith (#7)** — first new-from-survey Pattern A.
3. ✓ Add **ssl (#5)** — second Pattern A datapoint.
4. ✓ Extract **Pattern A template** (`canary_pattern_a.ml`) from zarith + ssl.
5. Add **lwt** with depopt **libev (#8)** — stresses the template with optional-dep.
6. Add **cvc5 (#9)** — Pattern C second datapoint; sibling to z3.
7. **PyTorch (#4)** — highest-leverage multi-PM case
   ([`design/project_pytorch.md`](design/project_pytorch.md)).
8. Remaining — bitwuzla, mariadb, ffmpeg family — each adds one new trick.

### Intentional non-targets

- **`conf-zlib` / `camlzip`** (18 revdeps) — popular but pure Pattern A
  with no interesting wrinkles. Good "10th follower" once template is solid.
- **`conf-ncurses` / `curses`** (4 revdeps) — well-covered pattern, low research interest.
- **Pattern D (invisible C stubs)** — `mirage-crypto`, `bigstringaf` etc. (43 packages).
  No leverage until source-inspection is in the toolkit.
- **`owl` / `conf-openblas`** — multiple BLAS variants (OpenBLAS / MKL / Accelerate)
  push it to Tier 2.5. Natural follower after PyTorch.

### Done

| #   | Project              | Landed     | Notes                                                                                                                                                                                        |
| --- | -------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | z3                   | 2026-03    | Pattern C self-build; local + CI                                                                                                                                                             |
| 2   | llvm                 | 2026-03    | A+C hybrid; local + CI                                                                                                                                                                       |
| 3   | sqlite               | 2026-03    | Pattern A; local + CI                                                                                                                                                                        |
| —   | python primitives    | 2026-04-23 | Sqlite/z3/llvm pip probes, both local + CI                                                                                                                                                   |
| 7   | zarith               | 2026-04-25 | Pattern A. Surfaced `inspect_native.py` GMP `__gmp*` stripping bug                                                                                                                           |
| 5   | ssl                  | 2026-04-25 | Pattern A second datapoint. `Ssl.get_version` doesn't exist in v0.7.0                                                                                                                        |
| —   | Pattern A template   | 2026-04-25 | `canary_pattern_a.ml` 135 lines compresses each spec to ~40 lines                                                                                                                            |
| —   | api-compat milestone | 2026-05-01 | `Expect_compat_failure` derived expectations for OCaml + Python; see [`research/surface_draft/implementation.md`](research/surface_draft/implementation.md) §2.7                             |
| 12  | cairo                | 2026-07-23 | Pattern A. First project onboarded on the post-redesign machinery (`Derived` fetch_lib via `store_config`; S5a detection runs). `cairo2` 0.6.5, 420 `cairo_` symbols; probe green first try. |
| —   | tiny-full            | 2026-08-02 | tiny-full becomes a PROJECT (peer of z3/sqlite), not a `tiny` subcommand. 6 spec-derived scenarios; forward API mismatch derived as `xfail[c1]`.                                              |
| 3   | sqlite → generic     | 2026-08-05 | sqlite gains a `Built` provision (canary compiles libsqlite3 from two amalgamation versions) and moves to `project_run`. 3 scenarios; Built worlds assert the runtime version.               |
| 1,2 | z3 + llvm → generic  | 2026-08-05 | A5: both move off raw `run_project_multi` onto `project_run` (`pr_spec` + `realize ∘ dispatch`). 2 scenarios each; their xfails are now *derived* and contract-attributed.                   |

---

## 4. Mechanics — adding a new project today

Each project lives in `src/canary/projects/canary_project_<name>.ml` and is
wired in `src/bin/canary_main.ml` and `src/canary/projects/canary_run.ml`.
There are three shapes, cheapest first:

- **Pattern A** (system lib + opam binding, no source build) — the
  `canary_pattern_a.ml` template brings each spec down to ~40 lines
  (`runner_spec` + `api_source`). zarith, cairo.
- **Raw `runner_spec`** — a hand-written spec per variant, run by
  `run_project_multi`. ssl only; not the shape to copy for new work.
- **`project_run`** (the generic path, and where new projects should
  land) — the project declares DATA: a `pr_spec` universe table
  (artifact × (provision × versions)), a `pr_provenance` provider table,
  and `pr_runner_spec = realize ∘ dispatch`. The general enumeration
  computes the scenario list; `run_project_run` executes it. tiny-full,
  sqlite, z3, llvm. See [`design/ssot.md`](design/ssot.md) §6.1 and
  [`design/dynamic_enumeration.md`](design/dynamic_enumeration.md).

Source-built projects are still the expensive ones — z3 ~600 lines, llvm
~470 — and A5 made their *shape* identical without yet sharing their
command templates ([`status.md`](status.md) §1c #6).

Per-project plan checklist (write this BEFORE implementation):

1. **Which native library + which binding(s)** — explicit about artifact kinds.
2. **Install paths** per PM (apt / brew / opam / pip / conda).
3. **Watchlists** — native symbols, OCaml modules, Python attrs. This is
   also what carries the *evidence* a Level-B prediction is derived from.
4. **Probe examples** — a small program that exercises the binding.
5. **Expected drift / failure cases** — what the shared lowering should
   find, and which contract (c1..c8) ought to attribute it.
6. **Open questions** that only surface during implementation.

After landing: move from the queue table to "Done" above and update
`CLAUDE.md`.

The [`onboard-new-project`](../../.claude/skills/onboard-new-project/SKILL.md)
skill walks this checklist end-to-end.

---

## 5. Scenario coverage — three levels, pick one

New projects choose *how much* scenario coverage they want.
tiny1 is not the reference to copy; it's the framework's
own regression suite. Pick the level that matches the
project's purpose:

| Level                                    | What you write                                                                                                                             | Example                                                                                                                                              | When it's right                                                                                                                                                                 |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A. Positive-only**                     | `runner_spec` + `api_source` + probe examples that must build/run. No failure prediction.                                                   | zarith, cairo (system lib works; probe compiles)                                                                                                     | The project is a demo that a canary session terminates cleanly on a known-good setup. No version-mismatch or breakage story.                                                    |
| **B. A derived failure prediction**      | Level A + enough declared **evidence** (watchlists / `api_source`) for the shared lowering to find the break itself. Since A7 you do *not* hand-write the substring. | z3 (`parser_context` missing from the wheel → `xfail[c2]`), llvm (`Opcode.UncondBr` → `xfail[c2]`), ssl (`060_nlv` → `xfail[c2]`)                     | You want to demonstrate a real version drift on this project. Cheapest way to say "here's an API break canary *computed*".                                                       |
| **C. Scenario matrix**                   | Level B + a `pr_spec` universe declaring the provision/version axes; the general enumeration produces the scenarios.                       | tiny-full (6), sqlite (3), z3 / llvm (2 each)                                                                                                         | You want *systematic* coverage across an artifact's provision/version axes. No longer exotic — it is the default shape for a `project_run` project.                             |

**Do not copy tiny's workspace/prepare/baseline files.**
`canary_tiny_workspace.ml` + `_prepare.ml` + `_baseline.ml`
are framework infrastructure for driving tiny1's 22-scenario
mutation **oracle** through sandboxed builds — a *test harness* for the
framework itself, not a template. No level needs them: a Level C project
declares axes in its `pr_spec` and the general enumeration does the rest
(tiny-full, the project, is itself a `project_run` peer of sqlite — it
does not fork the factory).

**Effort ballpark** (per level, per project):

- **A**: ~40 LOC via `canary_pattern_a.ml` (Pattern A: system lib + opam binding), ~600 LOC hand-written for a source-built project (z3/llvm shape).
- **B**: A + the watchlist/`api_source` entries that carry the evidence — usually ~10-20 LOC, no expectation code.
- **C**: B + the `pr_spec` universe table + `realize ∘ dispatch` (sqlite: ~300 LOC including the from-source build; z3/llvm: the bulk is their build commands, not the scenario machinery).

For scenario mechanics + the derived-vs-hand principle see
[`design/dynamic_enumeration.md`](design/dynamic_enumeration.md).
