# SSOT — Single Source of Truth for Canary IDs

This file is the canonical catalogue for IDs used in the manuscript
(`draft.md`), materials (`surface_draft/`), and the canary code. Any
new occurrence of an ID type listed here should reference this file;
any rename/renumber happens here first and ripples out.

**Status legend.**

- **stable** — name and ID fixed; manuscript + code agree.
- **drift** — manuscript and code names/counts disagree; needs a decision.
- **placeholder** — listed in the manuscript as roadmap; not yet in code.
- **roadmap** — planned but not in either manuscript or code.

**Code commands that re-emit canonical lists** (rerun to confirm
this file is current):

```sh
dune exec src/bin/canary_main.exe -- tiny-scenarios list  # bad-scenario names
dune exec src/bin/canary_main.exe -- paths                # 15-pattern action table
dune exec src/bin/canary_main.exe -- graph                # rule schema diagram
```

When manuscript prose forces a decision, update the relevant table
below, then propagate to `draft.md` (and code, when the polish pass
arrives).

---

## 1. Artifacts (`Ar.X`)

**Flow.** `canary_basic.ml: artifact_kind` + tiny `scenarios.py`
artifact tree ──► SSOT §1 ──► draft.md §2 / §3; consumed by every
project spec.
**Co-providers.** `artifact_kind` (code) and tiny's scenario
artifacts must agree on kinds and global Ar.X identity. Drift here
breaks scenario→artifact mapping in §5.

Status: **drift** — manuscript Ar.0..Ar.3 (4 kinds); code has 5 (adds
`Headers`). §2's `Ar.0..Ar.2` vs §3's `Ar.1..Ar.3` is another internal
numbering inconsistency.

**Decision needed:** does the manuscript collapse `Headers` into `Lib`
(as the table currently does) or surface it as `Ar.X`?

| ID   | Manuscript name | Code (`artifact_kind`) | §2 use         | §3 use          | Status      |
| ---- | --------------- | ---------------------- | -------------- | --------------- | ----------- |
| Ar.0 | native_source   | `Source`               | L189, L252     | (TBD)           | drift       |
| Ar.1 | native_lib      | `Lib`                  | L222           | source-lib pair | drift       |
| Ar.2 | binding_source  | (part of `Binding L`)  | L222           | (TBD)           | drift       |
| Ar.3 | binding_lib     | (part of `Binding L`)  | L282           | (TBD)           | drift       |
| —    | (headers)       | `Headers`              | not in manu    | not in manu     | drift       |
| —    | app             | `App`                  | not enumerated | not enumerated  | placeholder |

## 2. Surfaces (`Sf.X`)

**Flow.** `canary_compat.ml: inspect_input` + manuscript catalogue
──► SSOT §2 ──► draft.md §3; `inspect_*.py` JSON `kind` field.
**Co-providers.** code's 10 `inspect_input` variants and manuscript's
5 Sf roles are parallel hand-curated lists; the aggregation mapping
must be kept here.
**Principle.** Sf.X numbering should align with Ar.X numbering
(Sf.k is the inspectable face of Ar.k). Current draft does not
fully honour this — see Open Reconciliation §7.

Status: **drift** — manuscript 5 surfaces; code 10 inspect_input
variants (one surface aggregates several inspect kinds).

| ID   | Manuscript name  | Aggregates code `inspect_input`                  | Status |
| ---- | ---------------- | ------------------------------------------------ | ------ |
| Sf.1 | native_source    | `Typed_header`                                   | drift  |
| Sf.2 | native_lib       | `Native_lib`, `Versioned_exports`, `Abi_surface` | drift  |
| Sf.3 | binding_source   | `Ocaml_mli`, `Typed_binding_user`                | drift  |
| Sf.4 | binding_lib      | `C_stub`, `Typed_binding_stub`, `Versioned_req`  | drift  |
| Sf.5 | (Python/runtime) | `Python_attrs`                                   | drift  |

**Roadmap / parked**

- `runtime_trace` — demoted out of surface catalogue (a runtime
  observation, not a static surface). Sn.6 in snippets kept.

## 3. Agreements (`Ag.X`)

**Flow.** `canary_compat.ml: contract_id` (C1..C8) + manuscript §3
catalogue (Ag.1..Ag.7) ──► SSOT §3 ──► draft.md §3 prose;
`Expect_compat_failure` predicate derivation.
**Co-providers.** code's `contract_id` and manuscript's `Ag.X` are
parallel hand-curated lists. C8 (API-faithfulness) currently has
no manuscript Ag.

Status: **drift** — manuscript Ag.1..Ag.7 (7 agreements); code
`contract_id = C1..C8` (8 contracts).

**Decision needed:** add `Ag.8` to the manuscript or fold C8 into an
existing Ag.

| ID   | Manuscript name  | Code `contract_id`          | OCaml fn (`canary_compat.ml`) | Status |
| ---- | ---------------- | --------------------------- | ----------------------------- | ------ |
| Ag.1 | Symbol           | C1 (`cmp_symbol`)           | `check_c_compat`              | drift  |
| Ag.2 | API-completeness | C2                          | (see compat.ml)               | drift  |
| Ag.3 | Behavior         | C3 (`cmp_behavior`)         | runtime probe                 | drift  |
| Ag.4 | ABI              | C4 (`cmp_abi`)              | `check_abi`                   | drift  |
| Ag.5 | SymbolVersion    | C5 (`cmp_sym_version`)      | `check_sym_version`           | drift  |
| Ag.6 | Type             | C6 (`cmp_type`)             | `check_type`                  | drift  |
| Ag.7 | API-repacking    | C7 (`cmp_api_repack`)       | `check_api_repack`            | drift  |
| —    | API-faithfulness | C8 (`cmp_api_faithfulness`) | `check_api_faithfulness`      | drift  |

**§2 vs §3 collision.** §2 currently uses `Ag.0..Ag.7` (eight
stage-introduced agreements, numbered from 0). §3 uses `Ag.1..Ag.7`
(the catalogue, numbered from 1). Reconciliation: prefer §3's
catalogue numbering; rewrite §2 references to point at the §3 IDs.

## 4. Good Scenarios (`Sc.X`)

**Flow.** manuscript Sc.1..Sc.6 (hand-curated) + canary action
graph aggregation ──► SSOT §4 ──► draft.md §2 + §4 prose.
**Co-providers.** the six aggregate stages and the 15-pattern path
table (from `canary paths-md`) describe the same space at different
granularity; their consistency is the §5 mapping (each bad scenario
points at one Sc).

Status: **stable for manuscript** — six aggregations of the action
graph. Used in draft.md L349 table.

| ID   | Scenario name            | Stage                  | Action             | Status |
| ---- | ------------------------ | ---------------------- | ------------------ | ------ |
| Sc.1 | `build_native_lib`       | Upstream               | Ar.0 + Ar.1 → Ar.2 | stable |
| Sc.2 | `build_binding`          | Binding creation       | Ar.1 + Ar.2 → Ar.5 | stable |
| Sc.3 | `build_app_with_binding` | Binding use (direct)   | (TBD)              | stable |
| Sc.4 | `run_app_with_binding`   | Binding use (direct)   | (TBD)              | stable |
| Sc.5 | `build_app_helper`       | Binding use (indirect) | (TBD)              | stable |
| Sc.6 | `run_app_helper`         | Binding use (indirect) | (TBD)              | stable |

<!-- package-free -->

**Code correspondence.** The 6 good scenarios aggregate over the
finer action graph: `Fetch/Build_lib/Build_binding/Build_app/Probe`
crossed with artifact kinds. The 15-pattern table from `canary paths`
is the full enumeration.

## 5. Bad Scenarios (no ID prefix; `snake_case` names)

**Flow.** `dune exec canary_main -- tiny-scenarios list`
──► SSOT §5 ──► draft.md L382 table, tiny variant matrix.
**Co-providers.** OCaml (`Canary_tiny_scenario.scenarios`) is
the sole producer as of Phase E; the legacy Python harness
(`scenarios.py`) was archived under
[`../_legacy_code/tiny_python_harness/`](../_legacy_code/tiny_python_harness/).
Future `make ssot-sync` regenerates the table block.
**Open consistency.** the 13-variant perturbation matrix in §4 (and
historically in tiny.md) is a separate enumeration shape; whether it
aligns 1:1 with the 15 `scenarios.py` rows is not currently
documented — see Open Reconciliation §7.

Status: **stable** — `canary tiny-scenarios list` output, 15 rows.
Manuscript L382 table mirrors this.

**Note on shape (post-remodel, §9.3 pending).** The "Broken
artifact" and "Notes" columns will be replaced by
**Interested artifacts** (Ar.X list, derived from perturbation
targets) + **Detected by** (contract checker id if wired; blank
means static-invisible). Implementation details (patch file
name, soname strings) drop out — they live in code. Current
table stays until the remodel lands.

| Name                     | Good counterpart | Broken artifact                | Notes                       |
| ------------------------ | ---------------- | ------------------------------ | --------------------------- |
| `symbol_missing`         | Sc.2             | native_lib                     | provider drops a symbol     |
| `header_arity_bump`      | Sc.2             | native_source                  | header signature change     |
| `symbol_version_floor`   | Sc.4             | native_lib                     | versioned-symbol floor bump |
| `abi_soname_bump`        | Sc.4             | native_lib                     | soname bump                 |
| `type_wrong`             | Sc.2             | native_source / binding_source | TBD                         |
| `api_faithful`           | Sc.1–Sc.6        | (baseline; passes)             | placeholder                 |
| `api_repack`             | Sc.3             | binding_lib                    | repack changes layout       |
| `api_complete`           | Sc.3             | binding_lib                    | missing API in binding      |
| `behavior_silent`        | Sc.4             | native_lib (runtime)           | semantics-only drift        |
| `symbol_orphan`          | Sc.2             | binding_lib                    | binding refs unused symbol  |
| `api_repack_python`      | Sc.3             | binding_lib (Python)           | Python repack analogue      |
| `api_complete_python`    | Sc.3             | binding_lib (Python)           | Python incompleteness       |
| `app_over_binding_ocaml` | Sc.3             | app                            | app pinned past binding     |
| `app_over_helper_ocaml`  | Sc.5             | app                            | app pinned past helper      |
| `api_repack_stub_orphan` | Sc.2             | binding_lib (stub)             | stub-side orphan            |

**Roadmap rows** (in manuscript only, not in `scenarios.py`):

- `pkg_*` — packaging scenarios; placeholder for opam/pip/apt
  repackaging mismatches.

### 5.1 Scenario grouping analysis (recorded 2026-07-06)

Raw facts to review; supersedes an earlier coarser grouping in
`canary_tiny_scenario.ml:stage_groups` that used SSOT §5's "Good
counterpart" column as if it were a single label.

Each scenario has (at least) two distinct stage attributions:

- **perturbed_at** — which stage's artifacts the perturbation
  modifies (or "post-Sc.N" for binary surgery on built
  artifacts).
- **manifests_at** — which stage first observes a failure (build
  fail, probe fail, or "gap" = no detector wired even though the
  perturbation exists).

**Per-scenario table.**

| Scenario                 | perturbed_at             | manifests_at         | detector today                       |
| ------------------------ | ------------------------ | -------------------- | ------------------------------------ |
| `symbol_missing`         | Sc.1 (native src)        | Sc.4 (probe fail)    | c1 cmp_symbol                        |
| `header_arity_bump`      | Sc.1 (native src)        | Sc.2 (binding build fail) | c6 cmp_type                     |
| `symbol_version_floor`   | Sc.1 (native src.map)    | Sc.4 (dyld load fail) | c5 cmp_sym_version                  |
| `abi_soname_bump`        | post-Sc.1 (binary surgery) | Sc.4 (dyld load fail) | c4 cmp_abi                        |
| `type_wrong`             | Sc.1 (native src)        | Sc.4 (probe fail)    | (weak — c6 wants clang AST)          |
| `api_faithful`           | Sc.1 (native src, adds fn) | — (nothing detects) | **gap** — c8 not wired               |
| `api_repack`             | Sc.2 (binding src)       | Sc.4 (probe fail)    | c3 cmp_behavior via probe            |
| `api_complete`           | Sc.2 (binding mli)       | Sc.3 (app build fail) | c2 cmp_api_completeness             |
| `behavior_silent`        | Sc.1 (native src)        | Sc.4 (probe fail)    | c3 cmp_behavior                      |
| `symbol_orphan`          | Sc.2 (binding src)       | Sc.2 (link fail on strict linker) | c1 cmp_symbol           |
| `api_repack_python`      | Sc.2 (binding src)       | Sc.4 (probe fail)    | c3 cmp_behavior via probe            |
| `api_complete_python`    | Sc.2 (binding src)       | Sc.4 (probe fail)    | c2 cmp_api_completeness              |
| `app_over_binding_ocaml` | — (positive)             | — (all pass)         | — (positive coverage)                |
| `app_over_helper_ocaml`  | — (positive)             | — (all pass)         | — (positive coverage)                |
| `api_repack_stub_orphan` | Sc.2 (binding stub layer) | — (probe passes)    | **gap** — c7 exists but exercised via bo1↔bo4 comparison, not runtime probe |

**Grouped by `perturbed_at`.**

- **Sc.1** — 7: symbol_missing, header_arity_bump,
  symbol_version_floor, type_wrong, api_faithful,
  behavior_silent, abi_soname_bump (via post-Sc.1 surgery)
- **Sc.2** — 6: api_repack, api_complete, symbol_orphan,
  api_repack_python, api_complete_python, api_repack_stub_orphan
- **positive coverage** — 2: app_over_binding_ocaml,
  app_over_helper_ocaml

**Grouped by `manifests_at`.**

- **Sc.2** (build-time) — 2: header_arity_bump, symbol_orphan
- **Sc.3** (app-build) — 1: api_complete
- **Sc.4** (runtime probe) — 8: symbol_missing,
  symbol_version_floor, abi_soname_bump, type_wrong, api_repack,
  behavior_silent, api_repack_python, api_complete_python
- **detection gap** — 2: api_faithful, api_repack_stub_orphan
- **positive coverage** — 2: app_over_binding_ocaml,
  app_over_helper_ocaml
- **Sc.1** — 0, **Sc.5** — 0, **Sc.6** — 0

**Observations.**

1. **Sc.4 (runtime probe) is the dominant manifestation stage
   (8/15).** Static comparators catch things earlier (Sc.2 build,
   Sc.3 app-build) when they exist; otherwise badness surfaces at
   runtime.
2. **Sc.1/Sc.5/Sc.6 have zero manifestations** in the current 15.
   Not because those stages are boring — Sc.1 is where 7
   perturbations are *applied* — but because the perturbations
   don't target failures unique to those stages. Sc.5 (build
   app_helper) and Sc.6 (run app_helper) are almost entirely
   unexplored; the sole `app_over_helper_ocaml` is positive
   coverage. Possible under-exercised area.
3. **Two agreement gaps.** `api_faithful` (c8 not wired) and
   `api_repack_stub_orphan` (c7 exists but only via static
   bo1↔bo4 comparison, not probe). These are candidates for the
   `derive_entries` experiment: the generator would emit them
   flagged "no detector." Ideally the gaps become findable via
   the agreement/checker registry rather than by hand-inspection.
4. **Detection ≠ perturbation.** Where you patch is not where the
   badness bites. The two-view separation clarifies §7
   Principle 3 (Good × perturbation → bad) — the projection has
   two axes, not one.

**Code state (as of `d44e7fb`).** `stage_groups` in
`canary_tiny_scenario.ml` uses only `manifests_at` — that's the
minority view (8/15 all at Sc.4 makes it look uninteresting).
Revising to include both views (or renaming to
`manifests_at_groups` + adding a `perturbed_at_groups`) is
queued in §9.3 backlog.

## 6. Operational taxonomy — scenario / action / step / stage / rule

**Flow.** Hand-curated here ──► reference for code renames + prose
consistency. Code enumerations (action catalogue below) also
consume this section for their names.

**Co-providers.** doc-side (this section) + code (`canary_action.ml`
constructors). Code lags behind — full rename sweep is deferred
(§8 reconciliation task, not blocking).

### 6.1 Hierarchy (big → small)

| Level | Term | Meaning | Code today | Rename target |
|---|---|---|---|---|
| High | **scenario** | Named collection of actions + interested artifacts. Sc.N. | *(new; §9.3 introduces)* | new type `scenario` |
| Mid | **action** | Operational verb (`Build_lib`, `Probe of _`, …) | `rule` | `action` |
| Low | **step** | Concrete instantiation of an action: cmdline + env + expectation. | `step` + `action_step` (split) | collapse into `step` |
| Attribute of action | **stage** | Where/when an action happens — pipeline phase (Upstream / Binding-creation / Downstream-use). Matches writeup "Stage for …" headings. | (not this) | *(new use)* |
| Theory | **rule** | *What an action is for* — operational semantics / invariants. Doc-only concept. | (currently overloaded onto action verb) | free `rule` for theory |

### 6.2 Code term clashes to resolve (rename map)

Deferred code sweep; agreement first, then flush.

| Code today | Meaning today | Rename target | Rationale |
|---|---|---|---|
| `rule` (`canary_action.ml`) | Action verb variant | **`action`** | Frees `rule` for theory-level meaning |
| `action_step` (`canary_step_model.ml`) | step + expectation | **`step`** | The runtime unit — no reason to over-qualify |
| `step` (`canary_basic.ml`) | 10-field record with cmdline/env/produces | **`step_body`** or collapsed | Semi-redundant with action_step; decide when we rename |
| `stage` (`canary_store.ml`) | Artifact-lifecycle state (`Built | Installed | Packed | Fetched`) | **`artifact_status`** or `lifecycle_state` | Frees `stage` for pipeline-phase meaning |
| `probe_action` (`canary_basic.ml`) | `Compile_example | Run_example` | stays | Already appropriately scoped as one probe's sub-choice |
| `compile_mode` | `Native | Bytecode` | stays | Fine as-is |

### 6.3 Writeup ↔ code alignment (after rename)

- Writeup "stage" = code `stage` (pipeline phase; Sc.N is-a stage).
- Writeup "action" = code `action` (verb).
- Writeup "step" = code `step` (concrete cmdline).
- Writeup "rule" = doc-only theory; no code counterpart required.
- Writeup "compile" / "build" = colloquial for specific `action`s
  (`Build_lib`, `Build_binding`, `Build_app`).

### 6.4 Migration sequence (agreed)

1. Draft this taxonomy in SSOT (this section). ✓
2. **Task 1** — scenario-to-action refactor: add `scenario` as a
   code type (list of actions + interested artifacts + agreement
   claims), using existing `rule` type without renaming yet.
   Split current `scenario_spec`: concept fields stay, tiny
   implementation fields (perturbation, patches, expected) move
   off to a Task-2-side recipe layer.
3. **Task 2** — implementation-side refactor: project-specific
   `tiny_scenario_recipe` (or similar) owns the perturbation
   machinery; produces `scenario` values consumable by any
   backend.
4. **Task 3** — deferred term-rename sweep (rule → action,
   action_step → step, stage → artifact_status). No hurry; runs
   after Tasks 1+2 and a full code/doc audit.

### 6.5 Current action catalogue

Names below stay through the code rename (they're OK regardless).
The type name (`rule`) changes; individual constructor names
(`Fetch`, `Build_lib`, …) don't.

**Flow (unchanged from prior §6).** `canary_action.ml: rule`
constructors (canary paths-md emits) ──► SSOT §6.5 ──►
draft.md (future), backend renderers (GH YAML / Mermaid / HTML).

Status: **stable in code**.

| Action name     | Kind         | Code constructor           | Status |
| --------------- | ------------ | -------------------------- | ------ |
| `fetch_<kind>`  | per artifact | `Fetch of artifact_kind`   | stable |
| `build_lib`     | native       | `Build_lib`                | stable |
| `build_headers` | native       | `Build_headers`            | stable |
| `build_binding` | per language | `Build_binding of lang`    | stable |
| `build_app`     | downstream   | `Build_app`                | stable |
| `pack_<kind>`   | per artifact | `Publish of artifact_kind` | stable |
| `probe_<kind>`  | per artifact | `Probe of artifact_kind`   | stable |
| `configure`     | upstream     | `Configure`                | stable |
| `scan_sources`  | upstream     | `Scan_sources`             | stable |
| `install_lib`   | upstream     | `Install_lib`              | stable |

**15-pattern action-path table.** `canary paths` enumerates the
15 patterns (composition strings) over these actions.

```sh
dune exec src/bin/canary_main.exe -- paths-md
```

---

## 7. Principles the SSOT should honour (awareness, not action)

Captured for later; surface here so they're visible per-section.

1. **Artifacts are globally named and indexed.** The Ar.X list is
   one flat catalogue, not per-section. Any artifact mentioned in
   any chapter resolves to the same Ar.X.
2. **Surface IDs align with artifact IDs.** Sf.k is the inspectable
   face of Ar.k. Current draft is not fully consistent (Sf.1
   pointing at native_source while §2 has Ar.0 = native_source) —
   resolving this is part of §8.
3. **Good scenarios × perturbation matrix = bad scenarios.**
   Bad scenarios are the projection of a scenario's interested
   entities (artifacts) through the agreement catalogue —
   computed, not maintained. Dual view (artifact-indexed
   perturbations) is a checkable alignment invariant, postponed
   to a follow-up after §9.3 scenario remodel lands.
4. **Tiny does not exercise packaging errors.** Bad-scenario
   coverage stops at the build/link/runtime layer. Packaging
   mistakes (wrong files in opam/pip/apt artefacts; cross-PM SONAME
   inconsistencies; metadata drift) are out of tiny's current
   reach — see §8 reconciliation tail.
5. **Anticipations are empirical, not sound.** Uninterested
   entities (system tools, compiler settings, OS behavior,
   hardware) are outside the model. Expected outcomes are bets
   tested against real runs, not theorems. Two flavours worth
   flagging: (i) emergent behavior — all static checks pass,
   specific input triggers wrong output; (ii) environmental
   interaction — artifacts good, uninterested-entity corner case
   flips result. Only discoverable empirically.
6. **Interested vs uninterested entities.** A scenario models
   its interested entities (artifacts explicitly on the
   perturbation/violation path). Uninterested entities exist and
   affect outcomes but aren't enumerated in the SSOT. Boundary
   is empirical (we add to the "interested" set when a
   real-world case forces it).

## 8. Open reconciliation tasks

1. **Ar.0..Ar.3 vs code's 5 kinds.** Decide if `Headers` gets an Ar
   slot or stays implicit under Ar.1.
2. **§2 vs §3 Ag numbering.** Renumber §2 to point at the §3
   catalogue IDs (the recommended path).
3. **Sf.5 / runtime.** Is Python/runtime its own Sf.5 or part of Sf.4
   (binding_lib)? Currently borderline.
4. **C8 ↔ Ag.X.** Add Ag.8 (API-faithfulness) or fold into another.
5. **Code-side rename** (deferred to polish pass per "uniformity
   eventually"): C1..C8 → Ag.X, inspect_input renames → Sf.X
   aggregates.
6. **Sf.X ↔ Ar.X alignment (Principle 2).** Renumber Sf so Sf.k is
   the surface of Ar.k.
7. **Perturbation matrix ↔ bad scenarios (Principle 3).** Document
   the mapping between the 13-variant matrix and the 15
   `scenarios.py` rows; declare which is authoritative.
8. **Tiny packaging coverage (Principle 4).** Add packaging-error
   scenarios to tiny (opam/pip/apt repackaging mistakes,
   cross-PM SONAME drift). Tracked as project TODO.
9. **Operational-taxonomy code sweep.** Rename `rule` → `action`,
   `action_step` → `step`, current `stage` (artifact-lifecycle
   state) → `artifact_status`/`lifecycle_state` per §6.2 rename
   map. Deferred (Task 3) until Tasks 1+2 land and a full
   code/doc audit finishes. Not blocking anything.

---

## 9. Strategic / forward planning

Larger-than-reconciliation items that shape the SSOT once
addressed. Captured as awareness; not active work.

1. **Migrate tiny's scenario engine from Python to OCaml.**
   `canary/examples/tiny/scenarios/scenarios.py` was the
   bad-scenario producer (§5); the rest of canary is OCaml. A
   single-language codebase removes the cross-language consistency
   obligation between `scenarios.py` and `canary_basic.ml:
   artifact_kind` (§1 co-providers), and lets
   perturbation/enumeration share types directly with the action
   graph.
   **Design decisions.** OCaml port adopts sandbox-build prepare:
   each scenario builds into a hermetic `_cache/<name>/`; live
   tree never mutated. CLI shrinks from ten verbs to six (`list`,
   `baseline`, `prepare`, `prepare-all`, `expected`, `confirm`).
   `apply`/`revert`/`restore`/`restore-baseline` retire with the
   Python harness at Phase E. For canary-owned artifacts (tiny is
   designed by canary, not upstream), builds use direct compilers
   (`gcc`, `ocamlfind ocamlopt`, `ar`) rather than cmake/dune/make
   — "owner decides the build system." From canary's POV a
   perturbed snapshot is a natural store that happens to provide
   ill artifacts.
   **Progress** (see [`tiny_migration.md`](tiny_migration.md) §9
   for commits):
   - Phase A ✓ inventory
   - Phase B ✓ `scenario_spec` (§9.2 one-time spec, 15 scenarios
     as data) + `tiny-scenarios list` (byte-parity)
   - Phase C.5 ✓ `expected <name>` (outcomes-parity 15/15)
   - Phase C.3 ✓ `baseline` (direct compilers, self-contained,
     7 inspect JSONs + 33-file workspace match Python)
   - Phase C.4 ✓ `prepare <name>` (sandbox-build; 15/15 scenarios
     produce correct-shape confirm_ill.json; `symbol_missing`
     byte-identical to Python)
   - Phase C.4b ✓ `prepare-all` (15/15 ok; auto-runs baseline)
   - Phase C.6 ✓ `confirm <name>` (parity with Python cmd_confirm)
   - Phase D ⏳ canary integration (see scoping below)
   - Phase E ⏳ delete Python harness + `_harness/` scripts
   **Phase D scope.** Not "port more Python" — Python is already
   out of the runtime path. The remaining seams in
   `src/canary/projects/canary_project_tiny.ml` +
   `src/bin/canary_main.ml`:
   (i) 13 canary tiny variants reference scenario names as
   *string literals* (`cache_workspace_of ~scenario:"symbol_missing"`);
   should reference `scenario_spec` values by name for
   compile-time verification;
   (ii) `Expect_compat_failure { inputs = ... }` predicates are
   hand-coded per-variant; could derive from `scenario_spec.violates`
   + `scenario_spec.expected` — but derivation logic is *new work*,
   not migration, so parked for a follow-up. Phase D as scoped is
   just (i): make the variant/scenario coupling type-safe. Small.
2. **One-time spec covering one scenario across both engines.**
   The current shape has two engines — tiny-based perturbation
   (concrete trace per agreement) and canary-based enumeration
   (abstract trace across variants). A spec that *owns* one
   scenario after enumeration would unify them: the same record
   drives perturbation construction in tiny and variant selection
   in canary. Resolves Principle 3 (perturbation × good =
   bad) by making the mapping computable, not declarative. Ties
   into §4/§5 flows.
3. **IN PROGRESS — scenario remodel.**

   **Task 1 (done, commit 1111ad6):** scenario-to-action split.
   - [x] New `Canary_scenario.scenario` (name, description, actions,
     interested_artifacts) — project-agnostic type in
     `src/canary/action/canary_scenario.ml`.
   - [x] Split `Canary_tiny_scenario`: `tiny_recipe` (perturbs,
     perturbation, expected, violates) + `entry = { scenario;
     recipe }` + `entries : entry list` (15 tiny entries).
   - [x] Consumers updated (canary_tiny_prepare uses entries;
     canary_main uses `name_of_string`).
   - [x] End-to-end verified: list / expected / baseline / prepare
     / confirm all work.
   - [x] Coarse hand-mapping of actions + interested_artifacts
     using 5 groupings (native cascade, ocaml only, python only,
     abi cascade, positive coverage). Refinement queued below.

   **Backlog (post-Task-1, still §9.3-family):**
   - [ ] **Derive `interested_artifacts` from `actions`** —
     currently hand-mapped; the two fields are correlated (which
     artifacts an action touches is knowable from the action
     verb). Add an `interested_artifacts_of_actions : rule list
     → artifact_kind list` helper; verify it produces the
     hand-mapped values for the 15 entries; drop the hand fields.
   - [~] **Regroup entries by good scenario (Sc.N)** — first
     pass landed as an additive view in commit `d44e7fb`, but
     used a single ambiguous "stage" label. §5.1 analysis
     (2026-07-06) splits this into two views —
     `perturbed_at_stage` and `manifests_at_stage`. Code needs
     revising to either rename current `stage_groups` to
     `manifests_at_groups` + add `perturbed_at_groups`, OR extend
     each group entry with both fields. Awaiting review.
   - [ ] **`derive_entries` experiment.** With the two views
     documented, implement a
     `derive_entries : perturbation_category × Sc.N ×
     interested_artifacts → entry list`
     and diff against the current 15. Extras welcome
     ("principle can cover more"). Should surface the two
     detection gaps (`api_faithful`, `api_repack_stub_orphan`) as
     "no-detector" cells naturally.
   - [ ] **Fill the Sc.5 / Sc.6 under-exercised areas.** Only
     `app_over_helper_ocaml` (positive) targets the helper-chain
     stages. No bad scenarios exercise a helper-only failure
     mode. Not urgent; note as coverage gap for the manuscript.
   - [ ] **Task 2 — perturbation to project-recipe layer.**
     Extract tiny-specific machinery (patch, soname_bump) to a
     project-hookable interface. Tied to the perturbation ↔
     artifact-failure mapping design (the same "how does badness
     manifest" question).
   - [ ] **Task 3 (deferred) — term-rename sweep** per §6.2.
     After Tasks 1+2 land.
   - [ ] Dual-view artifact index (reading (c) — artifact knows
     all perturbations touching it, direct + inherited).
   - [ ] Iteration helpers over §1/§2/§3 catalogues
     (`canary_ssot.ml` — not blocking; lift only when reach
     forces it).
   - [ ] Alignment invariant as a test — needs both views indexed.
   - [ ] SSOT §5 columns swap (`Broken artifact` + `Notes` →
     `Interested artifacts` + `Detected by`) once `Detected by`
     has a real source of truth (checker registry).

   **Motivation (unchanged):**
   Migration (§9.1) is complete; `scenario_spec` is the sole
   source for the 15-scenario list. Next step is to remodel the
   flat list into a structural hierarchy: each good scenario
   (Sc.1..Sc.6) owns its associated artifacts + the set of
   possible perturbations at that stage. Bad scenarios become
   `Sc.N × perturbation` cells rather than free-standing flat
   rows.
   Substrate today: `Canary_tiny_scenario.scenario_spec` carries
   `violates`/`perturbs`/`perturbation`/`expected`. What's
   missing structurally is *which Sc.N does this bad scenario
   belong to* — implicit today in the draft.md L382 table's
   "Good counterpart" column.
   Payoffs:
   (a) Closes §8 reconciliation task #7 (Perturbation matrix ↔
       bad scenarios) — mapping becomes computable via structural
       composition instead of documented separately.
   (b) Realises §7 Principle 3 (Good × perturbation = bad) as
       structural code, not just declarative principle.
   (c) Enables §9.4 (expectation re-do + `Expect_compat_failure`
       derivation) — expected outcomes attach coherently to
       good-scenario parents.
   (d) SSOT §4 (Good) and §5 (Bad) become derivable from one
       source; both catalogues in draft.md follow.

   Iteration helpers for §1/§2/§3 catalogues (`canary_ssot.ml`)
   are related but *not* a prerequisite — scenario-side work
   uses hand-listed `artifact_kind` values inline where needed
   and lifts to a shared iteration module only when the reach
   forces it.
4. **Re-do expectation as per-step contract outcome +
   derive `Expect_compat_failure` from `scenario_spec`.**
   *(Merged from the old §9.4 and Phase D.2 in
   `tiny_migration.md` — they're the same shift at different
   scales.)*
   Today `Expect_failure` / `Expect_compat_failure` (§6 actions)
   only capture *fail* shapes, and the predicates are hand-coded
   per variant in `canary_project_tiny.ml`'s 13
   `make_*_broken_script_spec` factories. Drafting surfaced that
   each step — success or failure — should contribute to a
   scenario-wise testing semantics: every action's outcome is
   evidence for or against the agreements (§3) it touches.
   Implies a contract layer between §6 (action steps) and §3
   (agreements), where step results are typed observations into
   the contract rather than match-the-substring assertions.
   Payoffs: (a) canary variants derive their expectations from
   `scenario_spec.violates` + `expected` (kills 13 hand-coded
   `Expect_compat_failure` blocks); (b) success outcomes
   contribute positively (not just failure), enabling
   contract-level coverage claims; (c) resolves the manuscript's
   §3.4 "role of behavior" discussion at the code level.
   **Timing**: strictly after §9.3. The good-scenario structure
   is a prerequisite — expected outcomes must attach to a
   coherent parent, not free-floating rows. This is likely the
   biggest manuscript ↔ code structural shift on the horizon.

## 10. Downstream usage in `draft.md`

Tables in `draft.md` that should be replaced with references or
generated from this file once SSOT stabilises:

- L349 — Good scenarios table → §4 here
- L382 — Bad scenarios table → §5 here
- §3 agreements catalogue → §3 here
- (any future) artifact/surface catalogue → §1/§2 here
