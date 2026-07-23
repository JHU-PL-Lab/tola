# Scenario coverage — generalizing tiny's scenarios to every project

> **Status: design (2026-07-23).** Design-only; no code yet. Captures how
> the per-project scenario-coverage view should work, to confirm the shape
> before building `canary scenarios`.

Builds on [`new_project.md` §0](new_project.md) (project dimensions) and
the `good_scenarios` catalogue in `action/canary_scenario.ml`. The
abstract enumeration behind *both* tiny's and a general project's listings
— **provision × mutation** — is [`ssot.md` §4.2](ssot.md); this doc is the
provision-axis (coverage) view of it.

---

## 1. Goal

tiny enumerates scenarios (`Sc.1..Sc.6`) and runs one per tiny-project.
We want the same **coverage view for every project** — show *all* possible
scenarios and mark which each project covers vs. which are **not
applicable**, and *why* not.

This makes the **full vs. partial** distinction legible:

- A **full** project (origin `Built` — z3, llvm, tiny) covers the whole
  pipeline *from source*: fetch/build source → build lib → build binding
  → build/run app.
- A **partial** project (origin `System`/opam — ssl, sqlite, cairo) starts
  from the *packaged* artifacts: fetch lib → fetch binding → run app. The
  source/build head is **N/A**.

So "Pattern A" is not a category — it's just *an opam-origining (partial,
fetch-path) project's coverage*.

---

## 2. The catalogue is build-path-only today

`good_scenarios` (`Sc.1 build_native_lib`, `Sc.2 build_binding`,
`Sc.3/5 build_app`, `Sc.4/6 run_app`) is the project-agnostic scenario
space — but its `actions` are the **build-from-source** path
(`Build_lib`, `Build_binding`, `Build_app`, `Probe_app`), i.e. tiny's
world. A conf-origin project runs the **fetch** path instead
(`Fetch Lib`, `Fetch Binding`, `Probe_binding`), so it matches *none* of
`Sc.1..Sc.6` today — not because it covers nothing, but because the
catalogue only knows one path.

Each pipeline stage has **two realizations**, selected by the dimensions:

| pipeline stage | build path (origin `Built`) | fetch path (origin `System`/opam) |
|---|---|---|
| provide source | `Fetch Source` / local checkout | — (no source) |
| provide lib | `Build_lib` (+ `Configure`, `Install_lib`) | `Fetch Lib` (system PM) |
| provide binding | `Build_binding` | `Fetch Binding` (opam) |
| run app | `Probe_app` | `Probe_binding` (the example *is* the app) |

**Design choice — keep the paths as distinct scenarios** (`build_lib`
*and* `fetch_lib`), rather than merging into one `provide_lib`. That's
what makes the coverage matrix show *which path* a project exercises and
mark the other as N/A — the whole point.

---

## 3. Applicability = dimensions (definition) + a disable list (config)

For each scenario, per project (really per **variant** — see §4), the mark
is one of:

- **Covered** — the variant's action set (from `derive_steps`) includes
  the scenario's actions.
- **N/A (definition)** — the **dimensions** preclude it. `origin = System`
  ⇒ `build_*` and `provide source` scenarios are N/A (no `source` field);
  `origin = Built` ⇒ `fetch_lib` is N/A (no system-package origin). Binding
  fetched (no `source_dir`) ⇒ `build_binding` N/A. Purely derivable from
  `store_config`.
- **N/A (config)** — *applicable by definition but disabled*. z3 *can*
  build from source (it's `Built`) but you may disable that scenario to
  save time → N/A-config, not N/A-def. Needs a small per-project
  **scenario-disable list** (mirrors `disabled_contracts`).

So: **dimensions decide which scenarios are structurally applicable;
config prunes the applicable ones.** Both surface as N/A, distinctly
marked.

---

## 4. Coverage is per-variant; the project's is the union

A project's variants can each cover different scenarios:

- ssl's `sys` variant (origin `System`) covers `fetch_lib`, `fetch_binding`,
  `run_app` (via `probe_binding`); `build_*` are N/A-def.
- ssl's future `src-<ver>` variant (origin `Built` — canary fetches
  OpenSSL source, builds it, publishes its own conf) covers `provide
  source`, `build_lib`, … — the head that was N/A on the `sys` variant.

So **adding a `Built` variant to a `System` project extends its coverage
up the pipeline** — the concrete payoff of the "canary builds its own conf,
checked more rigorously than the ecosystem maintainers" idea
([`new_project.md` §0](new_project.md)). The project's total coverage is
the **union across its variants**; a scenario is N/A for the project only
if *no* variant covers it (and it isn't disabled).

---

## 5. The command (future)

`canary scenarios [<project>]` — for each scenario in the generalized
catalogue, print the mark per project/variant:

```
ssl
  provide_source     N/A(def: no source origin)
  build_lib          N/A(def)          fetch_lib     ✓ (sys)
  build_binding      N/A(def)          fetch_binding ✓ (sys)
  run_app            ✓ (sys: probe_binding)
  # with the src-<ver> variant added, the build_* rows flip to ✓ (src)

z3
  provide_source     ✓                 fetch_lib     N/A(def: built, not fetched)
  build_lib          ✓  [N/A(config) if source-build disabled]
  build_binding      ✓
  run_app            ✓
```

Mechanics (all reuse existing data):
- **Covered** ← the variant's `derive_steps` action set.
- **N/A-def** ← the `store_config` dimensions (origin/discovery).
- **N/A-config** ← the per-project scenario-disable list.

No new machinery — the generalization of `good_scenarios` to path-aware
logical scenarios + a display walk.

---

## 6. Scope / deferrals

- **Publish/package scenario omitted** — tiny omits it too; skip for now
  (add a `publish_binding` / `publish_conf` stage later).
- **Failure-mutation overlay is a separate axis.** tiny's mutation
  scenarios (`Bs.N`: `symbol_missing`, `abi_mismatch`, …) sit *on top* of
  the pipeline stages — a stage can run positive or be mutated to fail.
  This design covers the **pipeline stages** (what runs); which *failure
  modes* a project exercises is a further axis, deferred.
- **Helper scenarios** (`Sc.5/Sc.6`, app-via-helper) are tiny-specific;
  not generalized here.
