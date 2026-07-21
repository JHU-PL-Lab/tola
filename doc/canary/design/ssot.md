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

### 4.1 Concrete good scenarios

Each `Sc.N × language` admits **concrete good scenarios** —
specific workspaces (tiny today; future project-N tomorrow)
that instantiate the abstract Sc.N pattern end-to-end. A
concrete scenario is **good** (all steps `Expect_success`,
scenario carries `origin = None`) or **bad** (one or more
steps expected to fail; scenario carries `origin = Some _`
naming the cause). §5 enumerates the bad ones; the good ones
live here.

Tiny's concrete good scenarios:

| Scenario id    | Exercises                 | Name                     | What it does                                                 |
| -------------- | ------------------------- | ------------------------ | ------------------------------------------------------------ |
| `Sc.4.OCaml`   | Sc.3.OCaml + Sc.4.OCaml   | `app_over_binding_ocaml` | App links against binding, uses it directly; build + run     |
| `Sc.6.OCaml`   | Sc.5.OCaml + Sc.6.OCaml   | `app_over_helper_ocaml`  | App uses a helper library that uses the binding; build + run |

Naming convention: the id **is** the run-stage Sc.N (naming
after the most-downstream stage exercised — the run
implicitly includes its build prereq). A concrete good
scenario reuses the Sc.N id of the pattern it instantiates;
the (id, origin) joint distinguishes the concrete good
scenario from the abstract Sc.N pattern of §4 (which is a
description, not a runnable).

These concrete good scenarios used to be catalogued as `Pc.N`
(positive coverage), then briefly as "unmutated witnesses";
those labels are retired. They're just good scenarios (search
for "Pc.1"/"Pc.2" or "unmutated" in git history).

Running a concrete good scenario is what `probe_app_<lang>`
does under the hood — build the app, run it, expect success.
The `probe_` prefix reads narrow for the app step (an app
isn't observed from the outside; it's *used*), but the
semantic is already the right one: the app step exercises the
artifact as its end-user would.

## 5. Bad Scenarios (`Bs.N`; `snake_case` names)

**Flow.** `dune exec canary_main -- tiny-scenarios list` ──►
SSOT §5.1 ──► draft.md L382 table, tiny variant matrix.
**Co-providers.** OCaml (`Canary_tiny_scenario.scenario_specs`) is the
sole producer as of Phase E; the legacy Python harness
(`scenarios.py`) was archived under
[`../_legacy_code/tiny_python_harness/`](../_legacy_code/tiny_python_harness/).
**Status.** stable — 13 Bs rows here (all Mutation-origin) +
2 concrete good scenarios in §4.1 = 15 concrete scenarios in
`scenario_specs`.

**Roadmap rows** (not in code yet):

- `pkg_*` — packaging scenarios; placeholder for opam/pip/apt
  repackaging mismatches. Tracked as §7 Principle 4 gap.

### 5.1 Per-scenario detail

Columns split into two:
- **Physical facts** (constructed setup): `ID`, `Good scenario`,
  `Mutation`.
- **Secondary / derived**: `Name` (= agreement label — what's
  *expected* in the good scenario, named after what gets
  violated), `Manifests` (where the failure first surfaces
  today), `Detector today` (which contract check catches it, or
  gap).

`Bs.N` = **B**ad **s**cenario number N. IDs are stable — new
scenarios append; renames don't renumber.

Concrete good scenarios (`app_over_binding_ocaml`,
`app_over_helper_ocaml`) are catalogued under §4.1, not here.
§5 enumerates only bad scenarios; a scenario with
`origin = None` belongs under the Sc.N it instantiates.

Bad scenarios can arise from several origins (all typed via
[`Canary_scenario.origin`](../../src/canary/action/canary_scenario.ml)):

- **`Mutation`** — patch the source or binary of one artifact
  in the chain. All of tiny's 13 Bs entries today.
- **`Version_mismatch`** — pair well-formed artifacts at
  incompatible versions. Currently modeled ad-hoc in the
  llvm/z3 stable variants (`llvm.19-shared` binding + LLVM 21
  example; z3-solver pip wheel + dev example). The
  constructor is reserved in the `origin` variant but not
  wired through canary's factory.
- **`Packaging`** — wrong files in an opam/pip/apt payload.
  Roadmap row `pkg_*`; no code yet.

Ordering convention: rows grouped by Good scenario, then by
mutation similarity. Renumbering when scenarios reorder is
acceptable while §5.1 is still churning; once stable, IDs freeze.

**Code correspondence.** The 13 Bs rows below plus the 2
concrete good scenarios from §4.1 (= **15 concrete scenarios**
covering the tiny Sc.N patterns) live at
`Canary_tiny_scenario.scenario_specs`. Each carries a
`belongs_to` field naming the Good scenario(s) it relates to
— for Bs.N this is the `mutated_at` Sc.N; for a concrete good
scenario this is the Sc.N(s) it exercises.
`Canary_tiny_scenario.all_scenarios` unions the 8
language-split tiny good scenarios (Sc.1 shared + 5 .OCaml +
2 .Python) + 15 instantiations = **23 scenarios** as the
reference list for the `derive_entries` experiment (§9.3
backlog).

| ID    | Good scenario | Mutation                      | Name                     | Manifests                         | Detector today                                           |
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
   (mutation) sits at Sc.1/Sc.2. Whether Sc.3–Sc.6 admit
   their own bad scenarios (assembly-time or run-time patches) is
   an open question.
3. **Two detection gaps.** Bs.6 `api_faithful` (c8 not wired) and
   Bs.13 `api_repack_stub_orphan` (c7 static-only, not probe).
   Ideally the `derive_entries` experiment (§9.3 backlog) finds
   these automatically as "no-detector" cells.
4. **The two columns `Good scenario` and `Manifests` are
   perpendicular perspectives on each row.** `Good scenario`
   locates *where the construction happens* (mutation
   perspective); `Manifests` locates *where the failure surfaces
   downstream* (manifestation perspective). The latter recovers
   the earlier "dual-view" idea (§7 Principle 3). Their alignment
   across rows is the invariant §7 Principle 3 wants — checkable
   once the agreement/checker registry is in place.

### 5.2 Patterns vs instances

Both good scenarios (§4) and bad scenarios (§5.1) here are
**patterns** — abstract descriptions of a construction. A
concrete project (tiny today, or a future z3/llvm equivalent)
provides the **instances**: the actual mutation files,
sandbox paths, build commands, expected outcomes.

The code split reflects this:

- `Canary_scenario.scenario` — the pattern (project-agnostic).
- `Canary_tiny_scenario.entry` — a tiny instance (concrete files
  + expected outcomes for tiny).

A same-shape recipe for another project would live in a
`canary_<project>_scenario.ml` file and produce
`Canary_scenario.scenario` patterns paired with a
project-specific recipe.

**Synthesis path (§7.2 Phase 3, 2026-07-20).** For tiny, a
derived cell (Good × artifact × applicable_kind) can now be
turned into a concrete instance automatically via
[`Canary_tiny_scenario.recipe_of_derived_cell`](../../src/canary/projects/canary_tiny_scenario.ml)
— given a derived scenario, returns a `tiny_recipe option`
built from the parametric mutation vocabulary of §5.3.
Cells whose (target, kind) has an implemented primitive
synthesize; cells whose primitive is missing (§5.3's
"Missing on purpose") stay [None] — the empty slot stays
visibly empty. After §7.2 Phase 4 (2026-07-20)
`all_scenario_specs = 15 hand + 6 derived = 21` and
coverage stands at 12 of 20 cells filled after §7.1's
`Drop_python_attr` primitive landed (2026-07-21); 8 remain
awaiting App-level primitives + c4 wiring for OCaml. See
[`derived_vs_hardcoded.md`](derived_vs_hardcoded.md) for
the full field-by-field derived-vs-hand map, and
[`tiny.md §7.1`](tiny.md#71-fill-the-9-remaining-empty-derived-cells)
for the blocker-primitive breakdown.

### 5.3 Mutation shapes (parametric vocabulary)

**Flow.** [`Canary_artifact_mutation`](../../src/canary/tool/canary_artifact_mutation.ml)
 ──► per-artifact submodules (Source / Native / Binding) each
own a `type t` enumerating that artifact's mutations, plus
matching constructor helpers and an `apply_cmds` shell-command
builder. Top-level `type mutation` is a thin union
(`Of_source | Of_native | Of_binding | Patch`) for callers
that need a homogeneous type. Shipped §7.2 Phase 1
(2026-07-20).

**Framing.** "A mutation is just an artifact-flavored fact" —
per-artifact types make that framing structural, mirroring the
inspection layer symmetry (canary_artifact_source / _native /
_lang each own their artifact's inspect wrappers).

Currently implemented (with existing-patch parity where a
tiny reference case exists):

| Module | Variant | Reference patch |
|---|---|---|
| `Source` | `Rename_c_symbol { file; from_; to_ }` | `symbol_missing.patch` |
| `Source` | `Rename_version_tag { file; from_; to_ }` | `symbol_version_floor.patch` |
| `Native` | `Soname_bump { from_so; to_so }` | `abi_soname_bump` (Bs.4) |
| `Binding` | `Drop_ocaml_val { file; name }` | `api_complete.patch` |

Freeform edits (add-declaration, coordinated multi-file
changes, in-place body rewrites) stay as top-level
`Patch { patch_file }` — the escape hatch. Of tiny's 13 bad
scenarios: 4 have parametric constructors (rename + drop
shapes); 9 stay as `Patch` (adds + body/signature rewrites).

**Missing on purpose** (per user 2026-07-20 principle
"per-artifact ops make missing-ness visible"):

- `Source.Drop_c_symbol` — remove a C function definition
  (multi-line, needs brace-matching). No current tiny cell
  needs it; add when one does.

**Recently added:**

- `Binding.Drop_python_attr` — sed-range primitive that
  deletes from `^def <name>(` through the next blank line.
  Byte-parity with the existing
  `api_complete_python.patch` verified in
  `mutation_regression_tests`. Adequate for tiny; would
  need an [ast]-based upgrade for projects with decorators
  / nested defs / non-blank-line-separated defs. Landed
  §7.1 2026-07-21.

**Tests** (in
[`canary_artifact_test.ml`](../../src/canary/test/canary_artifact_test.ml),
`mutation_pure_tests` / `mutation_shell_apply_tests` /
`mutation_regression_tests`):

- Pure: constructor round-trip + apply_cmds shape.
- Shell apply: run the emitted commands on a scratch sandbox,
  grep for the mutation's mark.
- Regression anchor: apply the parametric constructor AND the
  hand-authored `.patch` file to two clean tiny sandboxes,
  assert `diff -r` reports empty. Confirms byte-identical
  parity with the existing patch for the 4 mapped variants.

### 5.4 Contract bindings (expectation lowering vocabulary)

**Motivation.** A scenario declares which contracts its
mutation `violates` (e.g. Bs.4 abi_soname_bump violates
c4). Turning that high-level fact into per-step
expectations for the runner used to happen inside
`expectation_of_entry` via ad-hoc `match rule with`
branches — every new contract-firing-site or lang
extension added another branch. §7.1 (2026-07-21) lifted
the switch table into typed data, keyed on **contract
bindings**.

**Types** (in
[`canary_scenario.ml`](../../src/canary/action/canary_scenario.ml)):

```ocaml
type firing_site =
  | At_build_binding of Canary_lang.lang
  | At_probe_binding of Canary_lang.lang
  | At_build_app of Canary_lang.lang
  | At_probe_app of Canary_lang.lang

type loc_filter =              (* Task 2 Phase B, 2026-07-21 *)
  | Any
  | At_pm_lang of Canary_lang.lang   (* fires only at that lang's PM location *)
  | Not_pm_lang of Canary_lang.lang  (* fires everywhere except that lang's PM *)
  | Only_if of (Canary_store.location option -> bool)

type expectation_source =
  | From_artifact of {
      inputs : inspect_input list;
      version_info : version_info option;    (* Task 2 Phase C, 2026-07-21 *)
    }
  | From_behavior_grep of {
      contains_any : string list;
      version_info : version_info option;
    }
  | Placeholder of { reason : string }

type firing = {                (* record shape, not 3-tuple, for future fields *)
  site : firing_site;
  loc_filter : loc_filter;
  source : expectation_source;
}

type contract_binding = {
  contract : contract_id;
  lang     : Canary_lang.lang;
  firings  : firing list;
}
```

Two-category framing: `From_artifact` is *static-sourced,
dynamic-checked* (read cached inspect JSONs → compute
predicted substrings via the contract's predict closure →
grep probe.log). `From_behavior_grep` is *dynamic-only*
(assert log substring). `Placeholder` is *shape committed,
content TBD* — emits `Expect_success` at runtime, but the
binding is registered so `binding_has_live_firing` and the
startup validator can see it. Same "missing-ness visible"
principle as §5.3's Missing-on-purpose mutation shapes.

`loc_filter` (Phase B) lets one binding row express "fires
at OCaml probe but not pip-python probe" without duplicating
the whole row — llvm's inline expectation used a nested
match on `(rule, loc)`; the same behaviour comes from
`{ site = At_probe_binding OCaml; loc_filter = Not_pm_lang Python; ... }`.
`version_info` (Phase C) carries the human-readable
provider/consumer strings that today's `Expect_compat_failure`
attaches (`provider_version = "llvm 19"; consumer_requires
= "Opcode.UncondBr"; since = ...`); tiny sets it to `None`
throughout, llvm/z3 populate it.

**Per-project data** — a project supplies its own
bindings table. Tiny's lives in
`canary_tiny_scenario.ml:tiny_contract_bindings`; c1-c7
wired for the relevant langs, c4-OCaml and c8-OCaml as
Placeholder. `expectation_of_entry` becomes a pure lookup
over this table.

**Guard consumer.** `Canary_scenario.binding_has_live_firing
bindings contract lang` returns true iff the (contract,
lang) has at least one non-Placeholder firing. Used by
`recipe_of_derived_cell`'s synthesis guards to decide
whether a mutation targeting a contract will produce a
detectable failure or emit silent Expect_success.

**Startup validator** (in `canary_tiny_scenario.ml`):
every scenario with `manifest = Possible _` must have at
least one live firing across its `violates × langs`.
Catches "you wired a Bs entry expecting failure, but
every contract you listed is Placeholder" — a design gap
that would otherwise silently pass.

**Task 2 hook.** z3 / llvm / sqlite still hand-code
`Expect_compat_failure` inline in their `project_spec`.
Task 2 (parked at `worklog_2026_07.md` — Task 2 parked
plan) can extend the pattern by letting each project
supply its own `<project>_contract_bindings` and inherit
the uniform lowering.

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
   (unified shape: added `id`, `mutation option` with
   target / kind / manifest / detector; renamed
   `interested_artifacts` → `related_artifacts`; populated
   Bs.1–Bs.13 + Pc.1–Pc.2). Existing `rule` type reused —
   rename deferred to Task 3. Explicitly not part of Task 1:
   agreement_claims field, deriving related_artifacts from
   actions (both deferred to §9.3 backlog).
3. **Task 2** — implementation-side refactor: unify
   `tiny_recipe` with `scenario.mutation` so the two
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

### 6.5.1 Per-rule consumes/produces (§7.9 derivation)

Every rule in §6.5 has an implicit input/output artifact
set. `Canary_scenario.artifacts_of_rule` (in
[canary_scenario.ml](../../src/canary/action/canary_scenario.ml))
encodes it as one flat table; `related_artifacts_of_actions`
takes a scenario's `actions` list and returns the union in
first-appearance order.

| Rule | Artifacts (ordered prerequisite → target) |
| --- | --- |
| `Configure`, `Scan_sources` | `[Source]` |
| `Build_headers` | `[Source; Headers]` |
| `Build_lib` | `[Source; Lib]` |
| `Install_lib` | `[Lib]` |
| `Build_binding L` | `[Lib; Binding L]` |
| `Build_app { lang = L }` | `[Binding L; App]` |
| `Probe_lib` | `[Lib]` |
| `Probe_binding L` | `[Binding L; Lib]` (runtime dep last) |
| `Probe_app { lang = L }` | `[Binding L; Lib; App]` |
| `Fetch k` | `[k]` |
| `Publish k` | `[k]` |

**Order convention**: prerequisite first, target next.
Runtime deps trail the direct arguments. The union across a
scenario's `actions` follows first-appearance order (no
dedup rearrangement), so §4 Good scenarios' displayed
`A1(...) A2(...) A3(...)` labels stay stable across releases.

**Origin & status** (2026-07-10): the `related_artifacts`
field on `Canary_scenario.scenario` was removed; the
derivation from `actions` is the sole source of truth.
Consumers call `Canary_scenario.related_artifacts s` (the
getter). Test-first spec pinned at
[canary_artifact_test.ml](../../src/canary/test/canary_artifact_test.ml)
under `scenario_derivation_pure_tests` — one case per
canonical Sc.N shape plus a chain composition case.

### 6.6 `project_spec` — the code-side project handoff

**Flow.** Project (`canary_project_<name>.ml`) constructs a
[`Canary_step_builder.project_spec`](../../src/canary/action/canary_step_builder.ml)
──► `derive_steps` walks it ──► `action_step list` ──► one
of four backends (local runner / GH YAML / Mermaid / HTML).

Status: **stable in code** (2026-07-08 rename from
`script_spec`; type shape stable since Phase 4).

**Shape.** `project_spec` is a record where most fields are
one closure per action verb from §6.5, plus a few policy /
metadata fields. Each closure has type
`~output_dir:string -> ~variant_key:string -> string` and
returns the shell command for that action:

- Action closures (one field per verb, all `option`):
  `fetch_source`, `scan_source`, `scan_sources` (+ optional
  `scan_sources_after` placement), `configure`,
  `build_headers` / `fetch_headers`, `build_lib` /
  `fetch_lib`, `build_binding` (per-lang list) /
  `fetch_binding` / `pack_binding`, `install_lib`,
  `build_app` / `fetch_app` / `pack_app`, `pack_lib`,
  `probe_lib` / `probe_binding` / `probe_app`.
  Missing (`None`) → the corresponding action is dropped
  from the emitted step list.
- Declarative surface metadata: `api_source :
  Canary_artifact_api.t option` (native + per-language
  binding claims — provider symbol prefixes, consumer
  module watchlists, header paths).
- Per-step policies: `check_post` (rule → optional
  postcondition predicate), `expectation` (rule →
  optional location → `step_expectation`), `symbol_check`,
  `inspect` (per-rule override for the auto-generated
  inspector step), `disabled_contracts`.
- Language wiring: `binding_user_facing_pkg`
  (`(lang * pkg_name) list` — drives auto-generated
  inspector step after `Probe (Binding lang)`).
- Diagram wiring: `artifact_name`, `inspect_note`.

Full field list + type: [`src/canary/action/canary_step_builder.ml:88`](../../src/canary/action/canary_step_builder.ml#L88).

**Composition with §6.5.** A `project_spec` is a partial
assignment from the action catalogue (§6.5) to shell
closures. Actions absent from the spec are absent from the
run. Multi-instance actions (`Build_binding`, `probe_*`)
carry per-language / per-location lists so one project can
emit distinct steps for OCaml vs Python variants.

**Derivation.** `derive_steps ~root ~project ?(langs = [OCaml])
(spec : project_spec) : action_step list` in the same file
(~line 535) walks the spec:

1. Traverse §6.5's action verbs in dependency order.
2. For each present closure, emit an `action_step` with:
   - `cmd` (from the closure, instantiated with
     `output_dir` / `variant_key`)
   - `expectation` (from `spec.expectation` for this rule,
     defaulting to `Expect_success`)
   - `check_pre` / `check_post` (defaults or from
     `spec.check_post` override)
   - `symbol_check` (from `spec.symbol_check`)
   - Per-artifact metadata (`variant_id`, `cache_key`, etc.)
3. Auto-insert inspector steps after `Probe (Binding lang)`
   using `binding_user_facing_pkg[lang]` + the language's
   inspect command from `Canary_artifact_lang`.
4. Cross-check declarative claims: if `api_source` names
   header paths / binding source paths, insert a
   `scan_source` step that verifies they exist post-fetch.

**Consumers of `action_step list`** (the four backends):

| Backend | File | What it does |
|---|---|---|
| local runner | [`backend/canary_local_runner.ml`](../../src/canary/backend/canary_local_runner.ml) | Executes each step in order, honours cache, records status |
| GH YAML | [`backend/canary_gh.ml`](../../src/canary/backend/canary_gh.ml) | Renders as GitHub Actions job(s) |
| Mermaid | [`backend/canary_diagram.ml`](../../src/canary/backend/canary_diagram.ml) | Renders as an action-graph diagram |
| HTML | [`backend/canary_html.ml`](../../src/canary/backend/canary_html.ml) | Renders interactive result viewer |

**Multi-variant projects.** Some projects run several
scenarios or version variants. The pattern is: build one
`project_spec` per variant (each with its own closures /
`expectation`), each becomes its own `action_step list`,
each runs independently. Examples:

- **tiny**: 15 concrete scenarios (13 Bs + 2 concrete good).
  A per-scenario factory (`Canary_tiny_scenario.project_spec_of_entry`)
  wraps a shared chassis `make_base_project_spec ~stores` and
  overrides `expectation` from the scenario's recipe. See
  [`design/tiny.md §3`](tiny.md#3-factory-pipeline--how-canary-runs-a-scenario).
- **z3 / llvm**: dev + stable variant. Each variant is a
  hand-coded `project_spec` value in
  `canary_project_{z3,llvm}.ml`; the stable variant carries
  a hand-written `Expect_compat_failure` predicate for the
  version mismatch. Task 2 ([`tiny.md §7.8`](tiny.md#78-task-2--recipemutation-integration-project-hookable-factory))
  proposes lifting tiny's factory pattern here so these
  projects can supply recipes analogous to tiny's.

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
3. **Good scenarios × mutation matrix = bad scenarios.**
   Bad scenarios are the projection of a scenario's interested
   entities (artifacts) through the agreement catalogue —
   computed, not maintained. Dual view (artifact-indexed
   mutations) is a checkable alignment invariant, postponed
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
   mutation/violation path). Uninterested entities exist and
   affect outcomes but aren't enumerated in the SSOT. Boundary
   is empirical (we add to the "interested" set when a
   real-world case forces it).

## 8. Downstream usage in `draft.md`

Tables in `draft.md` that should be replaced with references or
generated from this file once SSOT stabilises:

- L349 — Good scenarios table → §4 here
- L382 — Bad scenarios table → §5 here
- §3 agreements catalogue → §3 here
- (any future) artifact/surface catalogue → §1/§2 here

