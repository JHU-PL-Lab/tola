---
name: onboard-new-project
description: Add a new project to canary — pick coverage level (positive-only / one hand-coded failure / scenario matrix), write project_<name>.ml + contract bindings, verify canary action <name> runs green.
---

# Onboarding a new canary project

You are helping the user add a new project to canary. Canary is a
dependency-testing framework that enumerates build/probe actions
for a C library + its language bindings and runs them locally
(with GH CI support). Existing live projects: **tiny** (framework's
own regression fixture with 22 scenarios), **z3** (Version_mismatch
variants dev/stable), **llvm** (same shape), **sqlite** (positive-only).

## Before writing any code

Read these in order (they're cheap and eliminate 90% of the design
questions you'd otherwise ask):

1. **[`CLAUDE.md`](../../../CLAUDE.md)** — Build/Run commands +
   the "Key source files" table + "Architecture in one paragraph".
2. **[`doc/canary/design/new_project.md`](../../../doc/canary/design/new_project.md)** —
   Especially **§2 Mechanics** and **§2.5 Scenario coverage — three
   levels**. Picking one of A / B / C at the start decides everything
   downstream.
3. **[`doc/canary/design/ssot.md`](../../../doc/canary/design/ssot.md)** —
   §1 Artifacts (`Ar.X`), §2 Surfaces (`Sf.X`), §3 Agreements (`Ag.X`
   ↔ c1..c8), §6.1 Term↔code taxonomy (project / scenario / action /
   step), §6.5 Action catalogue (12 verbs + kinds + prereq→target).
4. **[`doc/canary/design/dynamic_enumeration.md`](../../../doc/canary/design/dynamic_enumeration.md)** —
   the "Derived vs hand-written" section: the three-layer boundary — **framework infra never gets copied**;
   **reusable primitives are consumed, not forked**; only **per-project
   hand-written** (project_spec + api_source + optional bindings) is
   yours to write.
5. **[`doc/canary/design/tiny.md`](../../../doc/canary/design/tiny.md)** —
   skim §1-§6 for what tiny does. Note: tiny's `workspace/prepare/
   baseline` modules are a **regression harness for canary itself**;
   they are NOT a template for real projects. Don't copy them.

## Pick your coverage level (`new_project.md §2.5`)

| Level | What you write | Effort | Example |
|---|---|---|---|
| **A. Positive-only** | `runner_spec` (build/probe/inspect commands) + `api_source` (surface claims). No `Expect_compat_failure`, no `contract_bindings`. | ~40 LOC (Pattern A helper) or ~600 LOC (hand-written like z3/llvm) | sqlite |
| **B. One hand-coded failure prediction** | A + one `contract_binding` row for the (contract, lang) pair that fires + `version_info` strings. | A + ~15-30 LOC | z3, llvm |
| **C. Scenario matrix** | B + a full `<project>_scenario.ml` (recipes, workspace materializer, factory). | B + ~500-1500 LOC + Task 2 prerequisites. Currently only tiny. | — |

**Default recommendation: pick A or B unless you have a research
reason for C.** C requires copying tiny's framework infra (which
we've said you shouldn't) OR reproducing enough of its shape from
scratch. Not worth it for a new project — save C for after Task 2
lifts the recipe machinery.

## Level A / B implementation checklist

Create `src/canary/projects/canary_project_<name>.ml`.
Look at `canary_project_sqlite.ml` (A) or `canary_project_z3.ml` /
`canary_project_llvm.ml` (B) as templates.

**Per-project plan checklist** (from `new_project.md §2`, write this
BEFORE implementation):

1. **Which native library + which binding(s)** — explicit about artifact kinds.
2. **Install paths** per PM (apt / brew / opam / pip / conda).
3. **Watchlists** — native symbols, OCaml modules, Python attrs.
4. **Probe examples** — a small program that exercises the binding.
5. **Expected drift / failure cases** — what `Expect_failure` (or
   `Expect_compat_failure`) catches.
6. **Open questions** that only surface during implementation.

**Structural pieces to add**:

- `let <name>_ocaml_config : ... = { ... }` — package_manager spec,
  ocaml binding lib name, example file, expected symbol.
- `let <name>_python_config : ... = ...` — pip package name +
  probe snippet.
- `let <name>_source_stable : source_repo = { ... has_build_binding = false; ... }` —
  for the "stable version + old binding" variant if you want B.
- `let <name>_contract_bindings : Canary_scenario.contract_binding list = [...]` —
  ONE ROW for the (contract, lang) pair that fires. See
  `canary_project_z3.ml:z3_contract_bindings` as a minimal template.
- `let mk_runner_spec ~source ... : Canary_step_builder.runner_spec = ...` —
  the main handoff. Sets `fetch_lib`, `fetch_binding`, `probe_lib`,
  `probe_binding` closures + `expectation` calling
  `Canary_scenario.lower_expectation`.

**Wire the project into the CLI**:

- Add a case in `src/bin/canary_main.ml`'s `action_cmd` dispatch
  (search for existing project handlers).
- Optionally add a bundle in `src/canary/projects/canary_run.ml` if
  you want a `runner_spec` value that `canary action <name>` can
  consume without needing runtime arguments.

## Verification workflow (do this iteratively as you code)

1. `dune build` — catch type/module errors.
2. `dune exec src/bin/canary_main.exe -- action <name>` — first
   full run. Expect noise on the first several attempts (wrong
   package names, missing PM lookups, incorrect expected substrings).
3. Read `_out/canary/projects/<name>/-run/actions.log` when the
   run fails — it shows each step's cmd + verdict.
4. If the compat-failure prediction doesn't fire correctly, read
   `_out/canary/projects/<name>/-run/run_state.json` for what
   `Expect_compat_failure`'s inputs resolved to. The compat runner
   iterates all contracts over the inputs bag — you may need to
   add / remove inputs to hit the right prediction.
5. Once green, run `dune exec src/bin/canary_main.exe -- artifact-test`
   — the framework tests should still pass (they're independent of
   projects).

## The two hardest things

**(1) Expected-failure prediction.** For Level B, your
`contract_binding` firing points at cached inspect JSONs (`inputs :
inspect_input list`) which `predicted_contains_any_v2` at run time
reads to compute expected failure substrings via each contract's
predict closure (`canary_compat_run.ml:registered_checks`). If the
prediction doesn't materialize, the fail modes are:

- The `inputs` paths don't exist yet at prediction time (the
  install step hasn't run) → check step order.
- The referenced contracts have `enabled = false` or
  `status = Stubbed` in the registry.
- The watchlist / expected symbols in your `api_source` don't
  match what the binding actually exports.

**(2) Store convention** — where each artifact lives. `Canary_store.location`
has `Build_tree | Staged | Pm of pm_info`. Your `probe_binding`
closure takes a `location` argument telling it which store to
probe against; pick correctly per variant.

## What to hand back when done

- One commit: `canary: add <name> project (Level A/B) + <count>-line contract binding`
- Diff summary: the project file (~40-800 LOC), the CLI wiring
  (~5-20 LOC), any small `new_project.md` update if a rough edge
  surfaced.
- `canary action <name>` output at the bottom of the commit message
  (last 3-5 lines showing the pass/fail summary).

## What NOT to do

- Do NOT copy `canary/examples/tiny/` — it's the framework's
  regression fixture.
- Do NOT copy `canary_tiny_workspace.ml` / `canary_tiny_prepare.ml`
  / `canary_tiny_baseline.ml` — framework infra, not per-project code.
- Do NOT try to add a full scenario matrix (Level C) unless you
  first lift the recipe machinery via Task 2 (see
  `worklog_2026_07.md` — "Task 2 parked plan").
- Do NOT commit if `artifact-test` regressed. The framework tests
  are independent of your project; if they break, something in your
  edit affected shared code.

## Escape hatches

- Suspect a framework bug rather than a project error?
  Read `doc/canary/design/ssot.md §6.5.a` "Known refinement
  concerns" — nine documented rough edges in the action layer
  that might explain surprising behaviour.
- Design decision required (contract to fire, store convention,
  variant shape)? Pause and ask; the design cost of picking
  wrong is much higher than the pause.
