# Derived vs. hardcoded — status map + guiding principle

Living status doc: what's mechanically derived, what stays
hand-written, and *why*. Update this file whenever a
hardcoded item moves to derived, or a new hardcoded input
lands.

**Guiding principle.** Two rules:

1. **Everything that can be derived from a small hand input
   should be** — the hand input is the source of truth; the
   derivation is machinery. Adding a new scenario / project /
   contract should touch the hand input, not the machinery.
2. **What stays hand-written stays project-specific by
   design** — build/probe/inspect shell strings, watchlists,
   `.patch` files. Rule for these: go through a **utility
   primitive** (e.g. `Canary_build_cmd.cmake_configure_cmd`,
   `Canary_cc.compile_c_lib`, `Canary_artifact_mutation.Native.apply_cmds`)
   rather than raw `Printf.sprintf "cmake -S ..."`. The
   commands themselves are per-project reality, but the
   phrasing should be typed.

Companion docs:
- [`design/tiny.md`](tiny.md) — tiny is the reference
  implementation for the derived side.
- [`design/new_project.md §2.5`](new_project.md) — how a new
  project chooses its scenario coverage level.
- [`design/ssot.md §5`](ssot.md) — pattern-vs-instance
  vocabulary.

---

## 1. Scenarios (per-Bs, per-cell)

Anchor: [`canary_tiny_scenario.ml`](../../src/canary/projects/canary_tiny_scenario.ml).
Today `all_scenario_specs = 15 hand + 7 derived = 22`
(coverage 12/20 cells filled).

| Field                | Hand-authored (13 Bs + 2 Pc) | Derived (§7.2 Phase 4, 2026-07-20)                                                                              |
| -------------------- | ---------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `name`               | Hand string                  | Auto `mutate_<kind>_at_<good.id>` in `Canary_scenario.derive_scenario`                                          |
| `scenario` (pattern) | Hand via `make_scenario`     | Enumerated by `Canary_scenario.derive_scenarios` (Good × related-artifact × applicable-kind)                    |
| `recipe.mutation`    | `.patch` file or typed ctor  | Synthesized by [`recipe_of_derived_cell`](../../src/canary/projects/canary_tiny_scenario.ml) — (target, kind) → mutation table |
| `recipe.violates`    | Hand list of contracts       | Hardcoded per synthesis-table row                                                                               |
| `recipe.mutates`     | Hand list of paths           | Hardcoded per row                                                                                               |
| `recipe.expected`    | Hand per-step map (legacy)   | Empty (factory ignores)                                                                                         |
| `origin.manifest`    | Hand: `Possible _`/`Unknown_gap` | Rebuilt: `Possible cell.belongs_to`                                                                         |
| `origin.detector`    | Hand: `Wired _`/`Gap`        | Rebuilt: `Wired first_violated_contract`                                                                        |

## 2. Pipeline (per scenario, downstream of `scenario_spec`)

| Piece                          | Derived (how)                                                                                                                                                                                                                                    | Hardcoded (where)                                                                                                                       |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| `scenario.actions`             | —                                                                                                                                                                                                                                                | Hand-set per parent Sc.N; Bs.N inherits parent Sc's actions (`e825f21` retired `acts_full`).                                            |
| `related_artifacts`            | ✅ `Canary_scenario.related_artifacts` → `related_artifacts_of_actions` → `artifacts_of_rule` (§7.9 2026-07-10)                                                                                                                                  | Only the per-rule consumes/produces table in `artifacts_of_rule` (one table, project-agnostic).                                         |
| `has_probe_manifestation`      | ✅ From `origin.manifest`                                                                                                                                                                                                                        | —                                                                                                                                       |
| `expectation` per (rule, loc)  | ✅ [`expectation_of_entry`](../../src/canary/projects/canary_tiny_scenario.ml) — pure data lookup over `tiny_contract_bindings` (SSOT §5.4). For each (violates × scenario_langs), matches the rule to a `firing_site` via `firing_site_of_rule` and picks the highest-priority `expectation_source` (Artifact > Grep > Placeholder-skip). Structural rewrite 2026-07-21. | `tiny_contract_bindings` per-(contract, lang) data table (~140 LOC). Placeholder rows commit the shape without wiring; startup validator catches "Possible-manifest but Placeholder-only violates". |
| `stores.lib_filename`          | ✅ `stores_of_entry`: on `Soname_bump`, strip trailing minor from `to_so`                                                                                                                                                                        | Other stores fields hand-set                                                                                                            |
| `runner_spec`                 | ✅ `runner_spec_of_entry`: base spec + derived expectation + derived stores                                                                                                                                                                     | `make_base_runner_spec` chassis (build/probe/inspect via `Canary_build_cmd` primitives)                                                |
| Step list                      | ✅ `Canary_step_builder.derive_steps` — walks action rules + project spec, filters by capabilities, attaches summaries                                                                                                                           | Shared machinery, project-agnostic                                                                                                      |
| `check_pre` / `check_post`     | ✅ Step model                                                                                                                                                                                                                                    | Shared machinery                                                                                                                        |
| `predicted_contains_any_v2`    | ✅ `Canary_compat_run.predicted_contains_any_v2 ~resolve` — reads cached inspect JSONs at prediction time; computes L0 C-symbol set-diff + L3 watchlist-missing                                                                                  | Per-contract predict closures (c1..c8) in `canary_compat.ml` (project-agnostic pure functions)                                          |
| Workspace / sandbox path       | ✅ Derived from `scenario.name`                                                                                                                                                                                                                  | Cache root hardcoded                                                                                                                    |
| Workspace materialization      | —                                                                                                                                                                                                                                                | [`canary_tiny_workspace.ml`](../../src/canary/projects/canary_tiny_workspace.ml) — RUNPATH strip, `libtiny.so` symlink synthesis. This is **framework infra**, not per-project code (see §3). |

## 3. Framework infra vs project code — the honest boundary

Three layers, only one of which a new project ever writes:

| Layer                  | Files                                                                                                                                                       | Purpose                                                                                             | Copy for a new project? |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ----------------------- |
| Framework infra        | `canary_tiny_workspace.ml`, `canary_tiny_prepare.ml`, `canary_tiny_baseline.ml`                                                                             | Prepare + materialize + baseline the 21-scenario matrix from tiny fixture. Belief-establishing harness for the framework itself. | **No**                  |
| Reusable primitives    | `canary_artifact_mutation.ml`, `canary_build_cmd.ml`, `canary_scenario.ml`, `canary_compat.ml`, `canary_step_builder.ml`, `canary_pattern_a.ml`             | Cross-project utility.                                                                              | **Consume, don't fork** |
| Per-project hand-written | `canary_project_<name>.ml` — `runner_spec` + `api_source` + optional expectation predicate                                                                | This one project's shape (watchlists, shell strings, install patterns).                             | **Yes — this only**     |

Tiny is the framework's regression suite. Its scaffolding
exists so that any change to `canary_scenario`,
`canary_artifact_mutation`, or the derivation chain can be
byte-verified against 21 known-good scenarios. Copying that
scaffolding into a new project would be copying a *test
harness*, not a *library user*.

## 4. Currently-hardcoded set (write-once inputs for tiny)

For quick reference — everything that lives on the hand side:

1. 15 hand entries in `scenario_specs` + 10 `.patch` files
   under [`scenarios/patches/`](../../canary/examples/tiny/scenarios/patches/).
2. `tiny_contract_bindings` — per-(contract, lang) firing
   sites + expectation sources (SSOT §5.4). Data table with
   Placeholder entries for c4-OCaml and c8-OCaml (visible
   TODOs, checked by startup validator). Replaces the ad-hoc
   `compat_inputs_of_contract` switch (retired 2026-07-21).
3. `artifacts_of_rule` per-rule table (project-agnostic).
4. Per-artifact mutation primitives (`Rename_c_symbol`,
   `Rename_version_tag`, `Soname_bump`, `Drop_ocaml_val`,
   `Drop_python_attr`) — hand shell commands routed through
   utility primitives.
5. `make_base_runner_spec` — hand build/probe/inspect shell
   strings via `Canary_build_cmd` / `Canary_cc` primitives
   (not raw `Printf.sprintf`).
6. Workspace fixups in `canary_tiny_workspace.ml` (RUNPATH
   strip, symlink synthesis) — framework infra, see §3.
7. `api_source` watchlists (`stable_symbols`,
   `module_watchlist`).

## 5. What could still move to derived

Not a work queue — a visibility list. Items on the
"hardcoded" side that could plausibly become derived if the
right upstream primitive lands:

- **Empty derived cells** (8 today after §7.1 shipped
  `Drop_python_attr`; see [`tiny.md §7.1`](tiny.md#71-fill-the-8-remaining-empty-derived-cells))
  — each blocked on a missing App-level mutation primitive
  or on wiring the `(C4, OCaml)` Placeholder in
  `tiny_contract_bindings` (SSOT §5.4).
- ~~**z3/llvm hand `Expect_compat_failure` predicates**~~
  ✅ shipped Task 2 Phases D/E 2026-07-21; z3/llvm/sqlite
  all consume `Canary_scenario.lower_expectation` over
  per-project contract bindings.
- **Workspace fixups** (RUNPATH strip, symlink synthesis) —
  could lift to a canary-owned "store sanitiser" per
  [`harness_canary_orthogonality.md §3`](harness_canary_orthogonality.md).

Items that should probably *stay* hardcoded:
- Per-project shell strings (build/probe/inspect commands)
  — reality is per-project; keep them typed through
  utility primitives, don't try to derive.
- Watchlists — these encode project-specific API knowledge
  the framework can't invent.
- `.patch` files whose content is essentially arbitrary
  code edits (e.g. `behavior_silent`'s subtle bug injection)
  — hand-written by design.
