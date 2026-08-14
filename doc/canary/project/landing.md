# Canary projects — how to land one

The landing guide: the workflow, the data structures to write, and the
testing harness that verifies each step. Split out of `index.md` in the
2026-08-12 reorganization (a future `onboard-new-project`-style skill
will be built on this doc — the previous skill was retired the same
day). Coverage status is [`coverage.md`](coverage.md); bugs/todo in
[`status_project.md`](status_project.md); the conceptual model in
[`index.md`](index.md) §1.

---

## 1. Mechanics — adding a new project today

Each project lives in `src/canary/projects/canary_project_<name>.ml` and is
wired by **one registry entry** in
`src/canary/projects/canary_registry.ml`. Three entry shapes, cheapest
first:

- **`simple` (Pattern A)** — system lib + opam binding, no source build.
  The `canary_pattern_a.ml` template brings each spec down to ~40 lines
  (`runner_spec`), then
  `let <name>_run = Canary_project_run.simple ~name ~runner_spec` wraps
  it as a `project_run` (lib + binding Fetched@Stable → exactly 1
  scenario). Registry entry: `("<name>", <name>_run)`. zarith,
  cairo, libffi.
- **`project_run` (generic path, Level C)** — the project declares DATA:
  a `pr_spec` universe table (artifact × (provision × versions)) +
  artifact rows with providers, and `pr_runner_spec = realize ∘
  dispatch` over an action table. The general enumeration computes the
  scenario list; `run_project_run` executes it. tiny-full, sqlite, z3,
  llvm, ssl. See [`../design/ssot.md`](../design/ssot.md) §6.1 and
  [`../design/algorithm_explainer.md`](../design/algorithm_explainer.md).
- **store pins** — a binding whose provider declares `versions`
  (`Lang_pkg`) enumerates one scenario per pin; the fetch is a
  pin-checked store operation (warm-skip only when the switch provably
  holds the pin) and the probes carry world assertions. ssl is the
  reference shape (2 scenarios × 2 probes). See
  [`store_switching.md`](store_switching.md).

Source-built projects are still the expensive ones — z3 ~600 lines, llvm
~470 — and A5 made their *shape* identical without yet sharing their
command templates.

**The landing workflow** (the full loop):

1. **Pick a coverage level** (§5: A positive-only / B derived failure /
   C scenario matrix) and write the per-project plan checklist first:
   - which native library + which binding(s) — explicit artifact kinds;
   - install paths per PM (apt / brew / opam / pip / conda);
   - watchlists — native symbols, OCaml modules, Python attrs (this is
     also the *evidence* a Level-B prediction is derived from);
   - probe examples — a small program that exercises the binding;
   - expected drift / failure cases — which contract (c1..c8) ought to
     attribute it;
   - open questions that only surface during implementation.
2. **Write `canary_project_<name>.ml`** + `canary/examples/<name>/`
   probe. Reuse tool/ primitives (`canary_build_cmd`,
   `canary_artifact_native`, `canary_artifact_lang`,
   `canary_action_table`) — framework infra is consumed, never forked.
3. **Add the registry entry** — that alone wires `action`, `spec`,
   `scenarios`, and the `@all` sweeps; the bin layer has no per-project
   cases anymore.
4. **The testing harness** (each step guards the previous):
   - `dune build` after every edit;
   - `make canary-test` (pure project-test + artifact-test + pm-test);
     the `registry.entries_enumerate` pin fails if an entry's
     enumeration is empty or the name list drifts;
   - `canary action <name>` — first full run, read
     `_out/canary/projects/<name>/-run/actions.log` on failure;
   - `canary spec <name>` / `canary scenarios <name>` / `canary status
     <name>` — the three display surfaces;
   - `make canary-post-check` before commit.
5. **After landing**: move from the queue table to
   [`coverage.md`](coverage.md)'s landing history, add the status-matrix
   row, update `CLAUDE.md`'s project list, and file any rough edge in
   [`status_project.md`](status_project.md).

---


## 2. Scenario coverage — three levels, pick one

New projects choose *how much* scenario coverage they want.
tiny1 is not the reference to copy; it's the framework's
own regression suite. Pick the level that matches the
project's purpose:

| Level                               | What you write                                                                                                                                                       | Example                                                                                                                           | When it's right                                                                                                                                     |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A. Positive-only**                | `runner_spec` + `api_source` + probe examples that must build/run. No failure prediction.                                                                            | zarith, cairo (system lib works; probe compiles)                                                                                  | The project is a demo that a canary session terminates cleanly on a known-good setup. No version-mismatch or breakage story.                        |
| **B. A derived failure prediction** | Level A + enough declared **evidence** (watchlists / `api_source`) for the shared lowering to find the break itself. Since A7 you do *not* hand-write the substring. | z3 (`parser_context` missing from the wheel → `xfail[c2]`), llvm (`Opcode.UncondBr` → `xfail[c2]`), ssl (`060_nlv` → `xfail[c2]`) | You want to demonstrate a real version drift on this project. Cheapest way to say "here's an API break canary *computed*".                          |
| **C. Scenario matrix**              | Level B + a `pr_spec` universe declaring the provision/version axes; the general enumeration produces the scenarios.                                                 | tiny-full (6), sqlite (3), z3 / llvm (2 each)                                                                                     | You want *systematic* coverage across an artifact's provision/version axes. No longer exotic — it is the default shape for a `project_run` project. |

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
[`design/algorithm_explainer.md`](../design/algorithm_explainer.md).
