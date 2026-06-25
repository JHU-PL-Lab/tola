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

## 7. Open reconciliation tasks

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

---

## 8. Downstream usage in `draft.md`

Tables in `draft.md` that should be replaced with references or
generated from this file once SSOT stabilises:

- L349 — Good scenarios table → §4 here
- L382 — Bad scenarios table → §5 here
- §3 agreements catalogue → §3 here
- (any future) artifact/surface catalogue → §1/§2 here
