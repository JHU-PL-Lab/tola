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

The full picture: an artifact moves through **stores** — source →
**Build** (build-tree) → **Publish** (PM) → **Fetch** (local) → **Probe** —
and the catalogue is those transitions, per artifact (lib, binding). A
project covers the **segment** its provision-path uses; the rest is N/A,
**symmetrically**:

| stage (per lib / binding) | action | tiny (`Built`, local) | ssl `sys` (`Fetched`) | ssl `src` (own conf, round-trip) |
|---|---|---|---|---|
| **Build** (source → build-tree) | `Build_lib` / `Build_binding` | ✓ | N/A | ✓ |
| **Publish** (build-tree → PM) | `Publish Lib` / `Publish Binding` | **N/A** | N/A | ✓ |
| **Fetch** (PM → local) | `Fetch Lib` / `Fetch Binding` | **N/A** | ✓ | ✓ |
| **Probe** (use) | `Probe_lib` / `Probe_binding` (the example *is* the app) | ✓ | ✓ | ✓ |

**tiny's N/A on Publish/Fetch is the same kind of cell as a general
project's N/A on Build** — both just say "this provision-path doesn't use
this transition." So Publish/Fetch belong in the core (not deferred); no
project is special-cased. The `Built`-vs-`Fetched` origin picks which
segment; the round-trip (`Build → Publish → Fetch`) is the "canary builds
its own conf" case, which alone covers `Publish`.

**Design choice — keep transitions as distinct scenarios** (`build_lib`
*and* `fetch_lib`, `publish_lib`), rather than merging into one
`provide_lib`. That's what makes the matrix show *which* transitions a
project exercises and mark the rest N/A — the whole point.

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

**Status (2026-07-23): first cut shipped.** `canary scenarios <project>`
prints the store-lifecycle catalogue (`fetch_source` · `build_lib` ·
`pack_lib` · `fetch_lib` · `probe_lib` · then per-lang binding stages)
with `✓` / `N/A`, deriving *Covered* from the project's `derive_steps`
action set (`Canary_scenario_coverage` + `Canary_run.ci_jobs`). No run
needed. **Union across variants (done).** Coverage is the union over *all* a
project's variants (`derive_steps` per variant, no run) — so z3/llvm show
their full pipeline (`build_lib ✓` from the dev variant, `fetch_lib ✓`
from stable, `pack_binding_ocaml ✓` = they publish their binding), while
sqlite/ssl/cairo stay fetch-path. `scenarios @all` walks every project.

**N/A split (done).** Three marks: `✓` (Covered), **`unspec`**
(Unspecified — N/A by definition, no path in the project's dimensions),
**`disabled`** (N/A by config). A scenario-disable list overrides Covered
(config wins). Two sources, unioned: a **persistent per-project disable
config** (`disabled_scenarios_of_project` — the canary config part of a
project's spec) plus `--disable <action>` per invocation. **z3/llvm
disable `build_lib`** (source-building the native lib is slow; the fetch
path covers `provide lib`) — so `scenarios z3` shows `build_lib disabled`,
while `scenarios sqlite` shows `build_lib unspec` (no source to build at
all). The same stage, two different N/A reasons — legible.

Still to do:
- **Unspecified is currently "not covered by any variant"**, which
  coincides with the dimension-derived N/A for today's projects but should
  be computed from `store_config` dimensions directly once they're stored.
- **tiny** isn't in the project list (scenario-based, not a `runner_spec`
  variant list); its coverage comes from the mutation axis, not
  provisions.

---

## 6. Scope / deferrals

- **Publish/Fetch are in the core** (§2), not deferred: a project that
  doesn't publish (tiny) or doesn't build (ssl `sys`) shows N/A on those
  transitions — symmetric N/A, no special-casing. `Publish` is covered
  only by the round-trip "build our own conf" case (ssl `src`).
- **Failure-mutation overlay is a separate axis.** tiny's mutation
  scenarios (`Bs.N`: `symbol_missing`, `abi_mismatch`, …) sit *on top* of
  the pipeline stages — a stage can run positive or be mutated to fail.
  This design covers the **pipeline stages** (what runs); which *failure
  modes* a project exercises is a further axis, deferred.
- **Helper scenarios** (`Sc.5/Sc.6`, app-via-helper) are tiny-specific;
  not generalized here.
