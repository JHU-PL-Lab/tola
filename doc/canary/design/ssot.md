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
**Co-providers.** the six aggregate stages and the 15-pattern
action-path table (from `canary paths-md`) describe the same
space at different granularity. Each Sc.N corresponds to a
subgraph of the action catalogue (§6.5).

Status: **stable for manuscript**. Used in draft.md L349 table.

| ID   | Scenario name            | Stage                  | Inputs → Outputs                                  |
| ---- | ------------------------ | ---------------------- | ------------------------------------------------- |
| Sc.1 | `build_native_lib`       | Upstream               | Ar.0 (native_source) → Ar.1 (native_lib)          |
| Sc.2 | `build_binding`          | Binding creation       | Ar.1 + Ar.2 (binding_source) → Ar.3 (binding_lib) |
| Sc.3 | `build_app_with_binding` | Binding use (direct)   | Ar.3 + app_src → app_binary                       |
| Sc.4 | `run_app_with_binding`   | Binding use (direct)   | app_binary + Ar.1 (runtime) → run_output          |
| Sc.5 | `build_app_helper`       | Binding use (indirect) | Ar.3 + helper_src + app_src → helper + app_binary |
| Sc.6 | `run_app_helper`         | Binding use (indirect) | app_binary + helper + Ar.1 (runtime) → run_output |

**Code correspondence.** The 6 good scenarios aggregate over the
finer action graph (§6.5): `Fetch/Build_lib/Build_binding/Build_app/Probe`
crossed with artifact kinds. The 15-pattern action-path table
(`canary paths`) is the full enumeration at a finer grain.
Project-agnostic patterns live at `Canary_scenario.good_scenarios`;
tiny's instances (same ids, tiny-specific descriptions) at
`Canary_tiny_scenario.tiny_good_scenarios`.

## 5. Bad Scenarios (`Bs.N`; `snake_case` names)

**Flow.** `dune exec canary_main -- tiny-scenarios list` ──►
SSOT §5.1 ──► draft.md L382 table, tiny variant matrix.
**Co-providers.** OCaml (`Canary_tiny_scenario.entries`) is the
sole producer as of Phase E; the legacy Python harness
(`scenarios.py`) was archived under
[`../_legacy_code/tiny_python_harness/`](../_legacy_code/tiny_python_harness/).
**Status.** stable — 15 rows.

**Roadmap rows** (not in code yet):

- `pkg_*` — packaging scenarios; placeholder for opam/pip/apt
  repackaging mismatches. Tracked as §7 Principle 4 gap.

### 5.1 Per-scenario detail

Columns split into two:
- **Physical facts** (constructed setup): `ID`, `Good scenario`,
  `Perturbation`.
- **Secondary / derived**: `Name` (= agreement label — what's
  *expected* in the good scenario, named after what gets
  violated), `Manifests` (where the failure first surfaces
  today), `Detector today` (which contract check catches it, or
  gap).

`Bs.N` = **B**ad **s**cenario number N. IDs are stable — new
scenarios append; renames don't renumber.

Positive-coverage scenarios (`app_over_binding_ocaml`,
`app_over_helper_ocaml`) live in the tiny code registry
(`Canary_tiny_scenario.entries`) but are **not** listed here —
they're constructions that verify a good-scenario execution
without perturbation, not bad scenarios. Attribution under §4 as
"verified by" entries is a future cleanup.

Ordering convention: rows grouped by Good scenario, then by
perturbation similarity. Renumbering when scenarios reorder is
acceptable while §5.1 is still churning; once stable, IDs freeze.

**Code correspondence.** The 13 Bs + 2 Pc entries live at
`Canary_tiny_scenario.entries`. Each carries a `belongs_to`
field naming the good scenario(s) it relates to — for Bs.N this
is the `perturbed_at` Sc.N; for Pc.N this is the Sc.N(s) it
verifies. `Canary_tiny_scenario.all_scenarios` unions the 6
tiny good + 13 Bs + 2 Pc = **21 scenarios** as the reference
list for the `derive_entries` experiment (§9.3 backlog).

| ID    | Good scenario | Perturbation                      | Name                     | Manifests                         | Detector today                                           |
| ----- | ------------- | --------------------------------- | ------------------------ | --------------------------------- | -------------------------------------------------------- |
| Bs.1  | Sc.1          | native_source (c/src)             | `symbol_missing`         | Sc.4 (probe fail)                 | c1 cmp_symbol                                            |
| Bs.2  | Sc.1          | native_source (c/{include,src})   | `header_arity_bump`      | Sc.2 (binding build fail)         | c6 cmp_type                                              |
| Bs.3  | Sc.1          | native_source (c/tiny.map)        | `symbol_version_floor`   | Sc.4 (dyld load fail)             | c5 cmp_sym_version                                       |
| Bs.4  | Sc.1          | native_lib (binary surgery)       | `abi_soname_bump`        | Sc.4 (dyld load fail)             | c4 cmp_abi                                               |
| Bs.5  | Sc.1          | native_source (c/src signature)   | `type_wrong`             | Sc.4 (probe fail)                 | (weak — c6 wants clang AST)                              |
| Bs.6  | Sc.1          | native_source (c adds fn)         | `api_faithful`           | — (nothing detects)               | **gap** — c8 not wired                                   |
| Bs.7  | Sc.1          | behavior (native src semantics)   | `behavior_silent`        | Sc.4 (probe fail)                 | c3 cmp_behavior                                          |
| Bs.8  | Sc.2          | binding_source (ocaml user)       | `api_repack`             | Sc.4 (probe fail)                 | c3 cmp_behavior via probe                                |
| Bs.9  | Sc.2          | binding_source (ocaml mli)        | `api_complete`           | Sc.3 (app build fail)             | c2 cmp_api_completeness                                  |
| Bs.10 | Sc.2          | binding_source (ocaml stub)       | `symbol_orphan`          | Sc.2 (link fail on strict linker) | c1 cmp_symbol                                            |
| Bs.11 | Sc.2          | binding_source (python)           | `api_repack_python`      | Sc.4 (probe fail)                 | c3 cmp_behavior via probe                                |
| Bs.12 | Sc.2          | binding_source (python)           | `api_complete_python`    | Sc.4 (probe fail)                 | c2 cmp_api_completeness                                  |
| Bs.13 | Sc.2          | binding_source (ocaml stub layer) | `api_repack_stub_orphan` | — (probe passes)                  | **gap** — c7 static-only (bo1↔bo4 comparison, not probe) |

**Observations.**

1. **Sc.4 (runtime probe) is the dominant manifestation stage
   (8/13).** Static comparators catch things earlier (Sc.2/Sc.3
   build) when they exist; otherwise badness surfaces at runtime.
2. **Sc.3–Sc.6 have zero bad scenarios in the current
   catalogue.** Sc.1 and Sc.2 hold everything — the stages where
   sources are authored. Sc.3+ are use-and-run stages; badness
   propagates *through* them but the *construction*
   (perturbation) sits at Sc.1/Sc.2. Whether Sc.3–Sc.6 admit
   their own bad scenarios (assembly-time or run-time patches) is
   an open question.
3. **Two detection gaps.** Bs.6 `api_faithful` (c8 not wired) and
   Bs.13 `api_repack_stub_orphan` (c7 static-only, not probe).
   Ideally the `derive_entries` experiment (§9.3 backlog) finds
   these automatically as "no-detector" cells.
4. **The two columns `Good scenario` and `Manifests` are
   perpendicular perspectives on each row.** `Good scenario`
   locates *where the construction happens* (perturbation
   perspective); `Manifests` locates *where the failure surfaces
   downstream* (manifestation perspective). The latter recovers
   the earlier "dual-view" idea (§7 Principle 3). Their alignment
   across rows is the invariant §7 Principle 3 wants — checkable
   once the agreement/checker registry is in place.

### 5.2 Patterns vs instances

Both good scenarios (§4) and bad scenarios (§5.1) here are
**patterns** — abstract descriptions of a construction. A
concrete project (tiny today, or a future z3/llvm equivalent)
provides the **instances**: the actual perturbation files,
sandbox paths, build commands, expected outcomes.

The code split reflects this:

- `Canary_scenario.scenario` — the pattern (project-agnostic).
- `Canary_tiny_scenario.entry` — a tiny instance (concrete files
  + expected outcomes for tiny).

A same-shape recipe for another project would live in a
`canary_<project>_scenario.ml` file and produce
`Canary_scenario.scenario` patterns paired with a
project-specific recipe.

## 6. Operational taxonomy — scenario / action / step / stage / rule

**Flow.** Hand-curated here ──► reference for code renames + prose
consistency. Code enumerations (action catalogue below) also
consume this section for their names.

**Co-providers.** doc-side (this section) + code (`canary_action.ml`
constructors). Code lags behind — full rename sweep is deferred
(§8 reconciliation task, not blocking).

### 6.1 Hierarchy (big → small)

| Level               | Term         | Meaning                                                                                                                               | Code today                              | Rename target          |
| ------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------- | ---------------------- |
| High                | **scenario** | Named collection of actions + interested artifacts. Sc.N.                                                                             | *(new; §9.3 introduces)*                | new type `scenario`    |
| Mid                 | **action**   | Operational verb (`Build_lib`, `Probe of _`, …)                                                                                       | `rule`                                  | `action`               |
| Low                 | **step**     | Concrete instantiation of an action: cmdline + env + expectation.                                                                     | `step` + `action_step` (split)          | collapse into `step`   |
| Attribute of action | **stage**    | Where/when an action happens — pipeline phase (Upstream / Binding-creation / Downstream-use). Matches writeup "Stage for …" headings. | (not this)                              | *(new use)*            |
| Theory              | **rule**     | *What an action is for* — operational semantics / invariants. Doc-only concept.                                                       | (currently overloaded onto action verb) | free `rule` for theory |

### 6.2 Code term clashes to resolve (rename map)

Deferred code sweep; agreement first, then flush.

| Code today                             | Meaning today                             | Rename target                | Rationale                                              |
| -------------------------------------- | ----------------------------------------- | ---------------------------- | ------------------------------------------------------ |
| `rule` (`canary_action.ml`)            | Action verb variant                       | **`action`**                 | Frees `rule` for theory-level meaning                  |
| `action_step` (`canary_step_model.ml`) | step + expectation                        | **`step`**                   | The runtime unit — no reason to over-qualify           |
| `step` (`canary_basic.ml`)             | 10-field record with cmdline/env/produces | **`step_body`** or collapsed | Semi-redundant with action_step; decide when we rename |
| `stage` (`canary_store.ml`)            | Artifact-lifecycle state (`Built          | Installed                    | Packed                                                 | Fetched`)                                              | **`artifact_status`** or `lifecycle_state` | Frees `stage` for pipeline-phase meaning |
| `probe_action` (`canary_basic.ml`)     | `Compile_example                          | Run_example`                 | stays                                                  | Already appropriately scoped as one probe's sub-choice |
| `compile_mode`                         | `Native                                   | Bytecode`                    | stays                                                  | Fine as-is                                             |

### 6.3 Writeup ↔ code alignment (after rename)

- Writeup "stage" = code `stage` (pipeline phase; Sc.N is-a stage).
- Writeup "action" = code `action` (verb).
- Writeup "step" = code `step` (concrete cmdline).
- Writeup "rule" = doc-only theory; no code counterpart required.
- Writeup "compile" / "build" = colloquial for specific `action`s
  (`Build_lib`, `Build_binding`, `Build_app`).

### 6.4 Migration sequence (agreed)

1. ✓ Draft this taxonomy in SSOT (this section).
2. ✓ **Task 1** — scenario-to-action refactor. Landed in
   1111ad6 (initial split: `Canary_scenario.scenario` + tiny
   `entry = { scenario; recipe }`) and refined in 13df74e
   (unified shape: added `id`, `perturbation option` with
   target / kind / manifest / detector; renamed
   `interested_artifacts` → `related_artifacts`; populated
   Bs.1–Bs.13 + Pc.1–Pc.2). Existing `rule` type reused —
   rename deferred to Task 3. Explicitly not part of Task 1:
   agreement_claims field, deriving related_artifacts from
   actions (both deferred to §9.3 backlog).
3. **Task 2** — implementation-side refactor: unify
   `tiny_recipe` with `scenario.perturbation` so the two
   layers stop duplicating info; project-hookable interface so
   z3/llvm/sqlite can supply their own recipes.
4. **Task 3** — deferred term-rename sweep (rule → action,
   action_step → step, stage → artifact_status). No hurry; runs
   after Task 2 and a full code/doc audit.

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
7. **Perturbation matrix ↔ bad scenarios (Principle 3).** Doc
   half ✓ — §5.1 documents the 13 Bs.N entries with per-row
   `Good scenario` × `Perturbation` × `Manifests`. Code half
   still open: `derive_entries` experiment to test whether the
   13 reproduce from a smaller (Good × perturbation kind ×
   related_artifacts) generator (§9.3 backlog).
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

   **Task 1 done** (commits `1111ad6` + `13df74e` + `bfc075c`,
   late June). Unified `Canary_scenario.scenario` shape:
   `perturbation option` record (target + kind + manifest +
   detector; possibilistic `Definite` / `Possible` /
   `Unknown_gap` and `Wired` / `Detector_gap`). Tiny `entry =
   { scenario; recipe }` populated with 13 Bs + 2 Pc; recipe
   holds the concrete impl (patches, expected outcomes)
   alongside the abstract annotations. Consumers updated;
   end-to-end verified.

   **Task 1.5 done** (2026-07-05 → 07). Validators, Good
   scenarios as code, `derive_scenarios` enumeration folded
   into `tiny-scenarios list`. Chronicle in
   [`worklog_2026_07.md`](../worklog/worklog_2026_07.md);
   final state: 8-entry `good_scenarios`, 20 derived cells
   (5 filled / 15 empty / 0 extras vs 13 Bs), drift risks #1
   and #3 closed.

   **Backlog (queued):**

   Next up (Task 1.6, 2026-07-07):
   - [ ] **Coverage-tag `prepare-all`.** Report which derived
     cells the 13 Bs recipes covered after a run. Cheap;
     reuses `derived_scenarios` + `matches_derived_cell`.
   - [ ] **`tiny_recipe` synthesis from an abstract cell.**
     Generate patch files + expected outcomes from (Good ×
     target × kind) so derived cells become runnable, not just
     name-only. Unblocks concrete filling of the 15 empty
     cells.

   Later:
   - [ ] **Derive `related_artifacts` from `actions`** —
     currently hand-mapped; correlated with action verbs. Add a
     `consumes/produces` helper on `rule`, verify against the 15
     hand values, then drop the hand field.
   - [ ] **Task 2 — recipe / perturbation integration.** Unify
     `tiny_recipe.perturbation` with `scenario.perturbation`;
     project-hookable recipe interface so z3/llvm/sqlite can
     supply their own.
   - [ ] **Fill Sc.3–Sc.6 areas.** Observation 2 in §5.1 flags
     these as zero-bad-scenario. Whether assembly-time /
     run-time perturbations belong at Sc.3+ is open; either
     confirm they don't or add scenarios that do. Manuscript
     concern too.
   - [ ] **Add `Package` perturbation source.** SSOT §5
     `pkg_*` roadmap; needs either a `Package` case on
     `artifact_kind` or a new `perturbation_kind` variant.
     Deferred until a project needs it.

   Deferred, not-blocking:
   - [ ] **Task 3 — term-rename sweep** per §6.2. After Task 2.
   - [ ] Dual-view artifact index (artifact-centric perturbation
     list, direct + inherited).
   - [ ] Iteration helpers over §1/§2/§3 (`canary_ssot.ml`).
   - [ ] Alignment invariant as a runtime test — needs
     `derive_entries` and both views indexed.

   **Motivation.** Each bad scenario should name its Good
   scenario, its perturbed artifact, its manifestation, and
   its detector — as data on one record. Task 1 delivered the
   shape; Task 1.5 added string-safety + Good-scenarios-in-code
   + a `derive_scenarios` generator whose output the current 13
   Bs fully occupy (0 extras). Remaining backlog is (a) making
   `related_artifacts` derivable from `actions` rather than
   hand-mapped, (b) unifying `tiny_recipe.perturbation` with
   `scenario.perturbation` (Task 2), and (c) making derived
   cells runnable (Task 1.6).

   Payoffs: (i) §8 task #7 mapping becomes computable, code
   half now via `derive_scenarios`; (ii) §7 Principle 3
   (Good × perturbation = bad) realised structurally in code;
   (iii) unblocks §9.4 (expectation re-do — per-step contract
   outcomes attach to a coherent Good/perturbation parent);
   (iv) SSOT §4 (Good) and §5 (Bad) derivable from one source.
4. **Re-do expectation as per-step contract outcome +
   derive `Expect_compat_failure` from scenario / recipe.**
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
   `entry.recipe.violates` + `entry.recipe.expected` +
   `scenario.perturbation.detector` (kills 13 hand-coded
   `Expect_compat_failure` blocks); (b) success outcomes
   contribute positively (not just failure), enabling
   contract-level coverage claims; (c) resolves the manuscript's
   §3.4 "role of behavior" discussion at the code level.
   **Timing**: strictly after §9.3. The Good-scenario /
   perturbation structure is a prerequisite — expected outcomes
   must attach to a coherent parent. Likely the biggest
   manuscript ↔ code structural shift on the horizon.

## 10. Downstream usage in `draft.md`

Tables in `draft.md` that should be replaced with references or
generated from this file once SSOT stabilises:

- L349 — Good scenarios table → §4 here
- L382 — Bad scenarios table → §5 here
- §3 agreements catalogue → §3 here
- (any future) artifact/surface catalogue → §1/§2 here
