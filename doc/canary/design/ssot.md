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
python3 canary/examples/tiny/scenarios/scenarios.py list  # bad-scenario names
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

| ID    | Manuscript name | Code (`artifact_kind`) | §2 use         | §3 use            | Status      |
| ----- | --------------- | ---------------------- | -------------- | ----------------- | ----------- |
| Ar.0  | native_source   | `Source`               | L189, L252     | (TBD)             | drift       |
| Ar.1  | native_lib      | `Lib`                  | L222           | source-lib pair   | drift       |
| Ar.2  | binding_source  | (part of `Binding L`)  | L222           | (TBD)             | drift       |
| Ar.3  | binding_lib     | (part of `Binding L`)  | L282           | (TBD)             | drift       |
| —     | (headers)       | `Headers`              | not in manu    | not in manu       | drift       |
| —     | app             | `App`                  | not enumerated | not enumerated    | placeholder |

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

| ID   | Manuscript name | Aggregates code `inspect_input`                          | Status |
| ---- | --------------- | -------------------------------------------------------- | ------ |
| Sf.1 | native_source   | `Typed_header`                                           | drift  |
| Sf.2 | native_lib      | `Native_lib`, `Versioned_exports`, `Abi_surface`         | drift  |
| Sf.3 | binding_source  | `Ocaml_mli`, `Typed_binding_user`                        | drift  |
| Sf.4 | binding_lib     | `C_stub`, `Typed_binding_stub`, `Versioned_req`          | drift  |
| Sf.5 | (Python/runtime) | `Python_attrs`                                          | drift  |

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

| ID   | Manuscript name      | Code `contract_id` | OCaml fn (`canary_compat.ml`) | Status |
| ---- | -------------------- | ------------------ | ----------------------------- | ------ |
| Ag.1 | Symbol               | C1 (`cmp_symbol`)  | `check_c_compat`              | drift  |
| Ag.2 | API-completeness     | C2                 | (see compat.ml)               | drift  |
| Ag.3 | Behavior             | C3 (`cmp_behavior`) | runtime probe                | drift  |
| Ag.4 | ABI                  | C4 (`cmp_abi`)     | `check_abi`                   | drift  |
| Ag.5 | SymbolVersion        | C5 (`cmp_sym_version`) | `check_sym_version`        | drift  |
| Ag.6 | Type                 | C6 (`cmp_type`)    | `check_type`                  | drift  |
| Ag.7 | API-repacking        | C7 (`cmp_api_repack`) | `check_api_repack`          | drift  |
| —    | API-faithfulness     | C8 (`cmp_api_faithfulness`) | `check_api_faithfulness` | drift  |

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

| ID   | Scenario name              | Stage                  | Action                           | Status |
| ---- | -------------------------- | ---------------------- | -------------------------------- | ------ |
| Sc.1 | `build_native_lib`         | Upstream               | Ar.0 + Ar.1 → Ar.2               | stable |
| Sc.2 | `build_binding`            | Binding creation       | Ar.1 + Ar.2 → Ar.5               | stable |
| Sc.3 | `build_app_with_binding`   | Binding use (direct)   | (TBD)                            | stable |
| Sc.4 | `run_app_with_binding`     | Binding use (direct)   | (TBD)                            | stable |
| Sc.5 | `build_app_helper`         | Binding use (indirect) | (TBD)                            | stable |
| Sc.6 | `run_app_helper`           | Binding use (indirect) | (TBD)                            | stable |

**Code correspondence.** The 6 good scenarios aggregate over the
finer action graph: `Fetch/Build_lib/Build_binding/Build_app/Probe`
crossed with artifact kinds. The 15-pattern table from `canary paths`
is the full enumeration.

## 5. Bad Scenarios (no ID prefix; `snake_case` names)

**Flow.** `dune exec canary_main -- tiny-scenarios list`
(OCaml, Phase B ✓) — canonical producer. Legacy
`python3 canary/examples/tiny/scenarios/scenarios.py list` still
runs identically until Phase E retires it.
──► SSOT §5 ──► draft.md L382 table, tiny variant matrix.
**Co-providers.** during migration both producers coexist and
must agree; verified byte-identical (see
[`tiny_migration.md`](tiny_migration.md) §9). After Phase E, only
OCaml remains. Future `make ssot-sync` regenerates the table
block.
**Open consistency.** the 13-variant perturbation matrix in §4 (and
historically in tiny.md) is a separate enumeration shape; whether it
aligns 1:1 with the 15 `scenarios.py` rows is not currently
documented — see Open Reconciliation §7.

Status: **stable** — `scenarios.py list` output, 15 rows. Manuscript
L382 table mirrors this.

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

## 6. Actions / Stages (no ID prefix; verb_object names)

**Flow.** `canary_action.ml: rule` constructors (canary paths-md
emits) ──► SSOT §6 ──► draft.md (future), backend renderers
(GH YAML / Mermaid / HTML).
**Co-providers.** code is the sole producer.

Status: **stable in code**; not yet enumerated in manuscript.

| Action name      | Kind             | Code constructor                          | Status |
| ---------------- | ---------------- | ----------------------------------------- | ------ |
| `fetch_<kind>`   | per artifact     | `Fetch of artifact_kind`                  | stable |
| `build_lib`      | native           | `Build_lib`                               | stable |
| `build_headers`  | native           | `Build_headers`                           | stable |
| `build_binding`  | per language     | `Build_binding of lang`                   | stable |
| `build_app`      | downstream       | `Build_app`                               | stable |
| `pack_<kind>`    | per artifact     | `Publish of artifact_kind`                | stable |
| `probe_<kind>`   | per artifact     | `Probe of artifact_kind`                  | stable |
| `configure`      | upstream         | `Configure`                               | stable |
| `scan_sources`   | upstream         | `Scan_sources`                            | stable |
| `install_lib`    | upstream         | `Install_lib`                             | stable |

**15-pattern action table.** `canary paths` enumerates the 15
patterns (action_path strings) over these stages; that table is the
operational SSOT for the action graph. Reproduce with:

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
3. **Good scenarios × perturbation matrix vs bad scenarios.** Sc.X
   (6 stages) crossed with one perturbation per agreement should
   reconstruct the bad-scenario set. Whether the 13-variant matrix
   in tiny.md and the 15 `scenarios.py` rows agree, and which is
   authoritative, is not yet documented.
4. **Tiny does not exercise packaging errors.** Bad-scenario
   coverage stops at the build/link/runtime layer. Packaging
   mistakes (wrong files in opam/pip/apt artefacts; cross-PM SONAME
   inconsistencies; metadata drift) are out of tiny's current
   reach — see §8 reconciliation tail.

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
3. **Re-do expectation as per-step contract outcome.** Today
   `Expect_failure` / `Expect_compat_failure` (§6 actions) only
   capture *fail* shapes. Drafting surfaced that each step —
   success or failure — should contribute to a scenario-wise
   testing semantics: every action's outcome is evidence for or
   against the agreements (§3) it touches. Implies a contract
   layer between §6 (action steps) and §3 (agreements), where step
   results are typed observations into the contract, not just
   match-the-substring assertions. Likely the biggest manuscript
   ↔ code structural shift on the horizon.

## 10. Downstream usage in `draft.md`

Tables in `draft.md` that should be replaced with references or
generated from this file once SSOT stabilises:

- L349 — Good scenarios table → §4 here
- L382 — Bad scenarios table → §5 here
- §3 agreements catalogue → §3 here
- (any future) artifact/surface catalogue → §1/§2 here
