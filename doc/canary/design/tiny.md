# Tiny — how it works today, how we want it to work

Canonical description of tiny's implementation state and
near-term wish-list. Complements:

- [`ssot.md`](ssot.md) — truth (definitions, scenario tables)
- [`bad_scenario_flavors.md`](bad_scenario_flavors.md) —
  after-tiny research task (flavor-2 catalogue completeness)
- [`status.md`](../status.md) — rolling backlog
- [`worklog_2026_07.md`](../worklog/worklog_2026_07.md) —
  Task 1.5 / 1.6 arcs
- [`research/tiny.md`](../research/tiny.md) — manuscript
  witness (paper audience)

## 1. What tiny is

The smallest end-to-end C-library binding project canary
knows how to reason about. Physically:

```
canary/examples/tiny/
├── c/               native library
│   ├── src/tiny.c        implementation
│   ├── include/tiny.h    public header
│   ├── tiny.map          version script (TINY_1.0 exports)
│   └── build/            gcc output (libtiny.so.1 + symlinks)
├── ocaml/           OCaml binding (via C stubs)
│   ├── tiny_raw.mli / .ml      external declarations
│   ├── tiny.mli / .ml          user-facing wrappers
│   ├── tiny_stubs.c            C-glue
│   ├── tiny_helper/            downstream binding chain
│   └── examples/               probes + apps
├── python_cext/     Python binding (C extension)
│   └── tiny_cext/{__init__.py, _native.c}
├── python_ctypes/   Python binding (ctypes-based)
│   └── tiny_ctypes/{__init__.py, _raw.py}
└── scenarios/       harness sandbox root
    └── _cache/           materialised workspaces (per scenario)
```

Three binding mechanisms (OCaml SCAB, Python cext SCAB,
Python ctypes DFFI). Tiny holds SCAB fixed for both languages
today; ctypes exists but doesn't participate in canary runs
(future axis — see status.md).

## 2. Scenarios — inventory pointer

SSOT §4 defines the 6 Good scenarios (Sc.1..Sc.6, split by
language: Sc.1 shared, Sc.2..Sc.6 as .OCaml / .Python).
SSOT §4.1 catalogues the 2 concrete good scenarios
(`app_over_binding_ocaml`, `app_over_helper_ocaml`) — Sc.N
runs with `origin = None` that instantiate Sc.4.OCaml (chain
Sc.3+Sc.4) and Sc.6.OCaml (chain Sc.5+Sc.6).
SSOT §5 defines the 13 Bad scenarios (Bs.1..Bs.13) — all
Mutation-origin today. Combined: **15 concrete scenarios**
in `scenario_specs`.

Each Bad scenario has a `tiny_recipe`:

- `mutates : string list` — which files under `canary/examples/tiny/`
  the mutation touches (closed universe of ~15 files:
  `c/src/tiny.c`, `c/include/tiny.h`, `c/tiny.map`,
  `ocaml/tiny*.ml{,i}`, `ocaml/tiny_stubs.c`,
  `ocaml/tiny_helper/*.ml{,i}`,
  `python_cext/tiny_cext/{__init__.py, _native.c}`,
  `python_ctypes/tiny_ctypes/{__init__.py, _raw.py}`)
- `mutation : concrete_pert option` — either
  `C_patch <name>` / `Ml_patch <name>` (a diff to apply
  under `scenarios/patches/`) or `Soname_bump { from_so; to_so }`
- `violates : contract_id list` — which surface-theory
  contracts (c1..c8) the scenario is designed to trigger
- `expected : (step * outcome) list` — per-step Ok/Fail/Pass/Skip
  prediction, kept as documentation

## 3. Factory pipeline — how canary runs a scenario

Source: [`src/canary/projects/canary_project_tiny.ml`](../../src/canary/projects/canary_project_tiny.ml) §"Scenario factory".

```
entry
  |> stores_of_entry ~stores : may override stores.lib_filename
                               from recipe.mutation
  |> { base_spec with expectation = expectation_of_entry entry }
```

One uniform path — no per-entry routing. Concrete good
scenarios (`origin = None`, SSOT §4.1) and detection-gap Bs
entries (`Unknown_gap` manifest) get `Expect_success` for
every rule because `expectation_of_entry` checks
`has_probe_manifestation` up front. Equivalent to no override
at all; base spec runs to completion.

### 3.1 Expectation derivation

Two orthogonal axes:

- **Language** (outer, per-scenario constant):
  `langs_of_scenario` reads `belongs_to` suffix.
  `Sc.N` → `[OCaml; Python]`; `Sc.N.OCaml` → `[OCaml]`;
  `Sc.N.Python` → `[Python]`.
- **Contract** (inner, per rule + lang): first violated
  contract yielding inputs for the current lang wins.

Two expectation shapes:

| Shape                                       | Contracts          | Firing step                                             | Payload                                |
| ------------------------------------------- | ------------------ | ------------------------------------------------------- | -------------------------------------- |
| `Expect_compat_failure` — static comparator | c1, c2, c4, c5, c6 | `Probe (Binding lang)`; c6 also at `Build_binding lang` | per-contract `inputs` + `version_info` |
| `Expect_failure` — probe assertion          | c3, c7             | `Probe (Binding lang)`                                  | `contains_any = ["FAIL "]`             |

### 3.2 Per-contract inputs

`compat_inputs_of_contract ~lang c` returns the JSON paths
canary reads to compute the predicted substring set:

| Contract                | Lang scope               | Inputs                                                                               |
| ----------------------- | ------------------------ | ------------------------------------------------------------------------------------ |
| c1 cmp_symbol           | any                      | `C_stub [build_binding_<lang>/inspect.json]` + `Native_lib [build_lib/inspect.json]` |
| c2 cmp_api_completeness | OCaml                    | `Ocaml_mli [build_binding_ocaml/inspect_mli.json]`                                   |
| c2 cmp_api_completeness | Python                   | `Python_attrs [build_binding_python/inspect_attrs.json]`                             |
| c4 cmp_abi              | Python (tiny convention) | `Native_lib` + `Abi_surface [build_binding_python/inspect.json]`                     |
| c5 cmp_sym_version      | Python (tiny convention) | `Versioned_exports` + `Versioned_req [build_binding_python/inspect.json]`            |
| c6 cmp_type             | OCaml (tiny convention)  | `Typed_header` + `Typed_binding_stub` (both from `scan_sources/`)                    |

The "tiny convention" columns reflect tiny's store choice:
Python cext is cached from baseline; OCaml binding rebuilds
fresh each run. Only cached bindings see stale ABI /
versioned-req / cext-behaviour issues; only rebuilt bindings
see compile-time type mismatches. A different project could
scope these differently.

### 3.3 Store adjustment

`stores_of_entry` derives `lib_filename` from
`recipe.mutation.Soname_bump { to_so }` by stripping the
trailing minor version:

```
to_so = "libtiny.so.2.0"  →  lib_filename = "libtiny.so.2"
```

Other mutations (patches) don't adjust stores.

## 4. Cache layout

The auto-init sandbox lives at
`canary/examples/tiny/scenarios/_cache/`. Two roles:

```
_cache/
├── baseline/
│   ├── inspect/<alias>.json     clean inspector outputs (n4, bo4,
│   │                            bo6, bo7, bpe2, bpe3, bpc2)
│   ├── artifacts/               snapshot of clean build outputs
│   │   ├── c_build/libtiny.so*
│   │   ├── cext/_native.cpython-*.so
│   │   └── ocaml/examples/{probe_baseline.exe,
│   │                       app_binding.exe, app_helper.exe}
│   ├── source/                  snapshot of MUTABLE_SOURCES
│   └── workspace/               materialised workspace
└── <scenario>/
    ├── inspect/<alias>.json     mutated inspector outputs
    ├── confirm_ill.json         surface delta vs baseline
    ├── artifacts/, source/      snapshots
    └── workspace/               materialised workspace (consumed by canary)
```

Inspector aliases: `n4` (native lib), `bo4` (OCaml mli),
`bo6` (cmxa), `bo7` (cstub .a), `bpe2` (cext dir()),
`bpe3` (cext .so undef refs), `bpc2` (ctypes dir()).

Canary consumes `<scenario>/workspace/` directly via
`Canary_project_tiny.cache_workspace_of ~scenario`. The
factory reads from it; no shell-out at runtime.

## 5. Running

CLI:

```
canary action tiny/<name>     # one scenario, auto-init if missing
canary tiny run               # all 15 in tiny list order + save results.json
canary tiny status            # tree view of last-run PASS/FAIL (from results.json)
```

(`canary action tiny` — bare — was retired 2026-07-09 as
non-uniform with other projects; use `tiny run` instead.)

Auto-init: `run_tiny_scenario` in
[`canary_main.ml`](../../src/bin/canary_main.ml) checks
`_cache/<name>/workspace/`. Missing → runs
`Canary_tiny_baseline.run ()` then
`Canary_tiny_prepare.run ~name` before invoking canary.
Existing workspaces are trusted.

`tiny run`/`tiny list`/`tiny status` share iteration via
`Canary_tiny_scenario.iter_scenario_specs`, so ordering
stays synced by construction.

Related read-only commands:

```
canary tiny list             # enumeration + detector tag per entry
canary tiny expected <name>  # per-step outcome JSON
canary tiny prepare <name>   # ad-hoc workspace prep (auto-init makes this optional)
canary tiny confirm <name>   # print cached confirm_ill.json
```

## 6. Coverage today

Two independent counts, easily confused.

**Concrete entries** — the 15 authored entries in
`Canary_tiny_scenario.scenario_specs` (13 Bs, all
Mutation-origin, + 2 concrete good scenarios per SSOT §4.1).
All 15 run through the uniform derivation. Split by whether
their expectation actually fires at probe:

| has probe manifestation?       | Count | Entries                                                                                                                                                                                |
| ------------------------------ | ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| yes — expectation fires        | 11    | symbol_missing, symbol_orphan, api_complete, api_complete_python, behavior_silent, type_wrong, api_repack, api_repack_python, abi_soname_bump, symbol_version_floor, header_arity_bump |
| no — Expect_success everywhere | 4     | api_faithful (c8 dormant), api_repack_stub_orphan (c7 static-only), Sc.4.OCaml (`app_over_binding_ocaml`), Sc.6.OCaml (`app_over_helper_ocaml`)                                        |

**Derived cells** — the 20 design-space slots enumerated
by `derive_scenarios` (Good × related-artifact × applicable
kind). Header of `tiny list`:
`20 derived cells, 5 filled, 15 empty`. The 5 filled cells
contain the 13 Bs entries (several Bs entries can share a
cell); the 15 empty cells are candidate flavor-1
mutations not yet authored (see §7.1).

**Two kinds of gap** to keep distinct:

- **Missing-entry gap** — one of the 15 empty derived cells.
  Design-space admits a scenario we haven't authored;
  mechanical filling work.
- **Detection gap** — an entry exists but no comparator
  catches it at probe. Shows as `[gap]` in the detector
  column (Bs.6 api_faithful; c8 dormant) or as
  `Unknown_gap` manifest (Bs.13 api_repack_stub_orphan; c7
  static-only). Belongs to the flavor-2 catalogue
  extension (see
  [`bad_scenario_flavors.md`](bad_scenario_flavors.md)).

Every scenario with a probe-observable manifestation
derives its expectation from `recipe.violates +
scenario.belongs_to + recipe.mutation`. Zero name
dispatch, zero routing tables.

## 7. Wish-list

Tiny-focused; see [`status.md`](../status.md) for the
project-wide backlog.

### Working principle — ssot-tiny-canary sync

The milestone is a **complete tiny + SSOT** that other work
can cite: sqlite/z3/llvm lift, new projects, writeup — all
"second-tier", flush from this line once it stabilizes.

Cadence: **code-first, doc-synced**. Land a concrete code
answer in tiny; then sync SSOT and tiny.md as side effects.
Modeling questions (Sf/Ar alignment, C8 wiring, expectation
shape, contract-inputs interface, etc.) get resolved as
outputs of concrete code decisions, not as up-front debates.

Each wish-list phase-commit carries the SSOT + tiny.md sync
bits it opens up. Second-tier (sqlite/z3/llvm/writeup)
untouched until this line stabilizes.

### Picking order (as of 2026-07-20)

| #    | Item                                                                      | Cluster | Status                                          |
| ---- | ------------------------------------------------------------------------- | ------- | ----------------------------------------------- |
| §7.2 | `tiny_recipe` synthesis from an abstract cell                             | A       | **active pickup — Phase 1 next**                |
| §7.1 | Fill the 15 empty derived cells                                           | A       | naturally follows §7.2 (data-driven under it)   |
| §7.4 | Fill Sc.3–Sc.6 areas                                                      | A       | overlaps §7.1                                   |
| §7.5 | Tiny packaging coverage                                                   | D       | long-horizon; needs Package mutation source     |
| §7.6 | Contract catalogue extension                                              | D       | post-tiny research task                         |
| §7.3 | Second mechanism axis — ctypes DFFI                                       | —       | deferred (user 2026-07-06)                      |
| §7.8 | Task 2 — recipe/mutation integration (project-hookable factory)           | —       | **deferred / rescoped** (user 2026-07-20) — see below |
| §7.9 | Derive `related_artifacts` from `actions`                                 | —       | **done** 2026-07-10                             |
| §7.7 | Route tiny commands through `tool/` (R2)                                  | —       | **done** 2026-07-09; macOS follow-up            |
| —    | SSOT §6.6 — document `project_spec`                                       | —       | **done** 2026-07-10 (`b9e4abc`)                 |

Clusters: A = tiny scenario coverage / recipe machinery,
D = long-horizon. Numbering stable — sections stay at their
§7.N ids regardless of picking priority.

**Why §7.8 (project abstraction) is deferred**: the 2026-07-17
scoping conversation surfaced that extracting a
project-hookable recipe/hook layer would spend ~230 LOC to
abstract ~28 LOC of hand-coded predicates across llvm+z3
today; ROI is marginal until we (a) have more projects using
the pattern (PyTorch, cvc5, ...), (b) finish tiny's own
recipe machinery (§7.2), and (c) have a settled
expectation/contract model. All three are prerequisites, and
sqlite/z3/llvm are second-tier per the working principle
above. Revisit once §7.2 lands and the recipe layer is
concrete.

### 7.1 Fill the 15 empty derived cells

`tiny list` shows 20 derived cells (Good × related
artifact × applicable kind); 5 filled, 15 empty. Each empty
cell is a candidate flavor-1 mutation slot:

- Sc.3.OCaml, Sc.4.OCaml — app-level mutations
- Sc.5.OCaml, Sc.6.OCaml — helper-chain mutations
- Sc.2.Python (lib arm), Sc.4.Python — Python-side counterparts

Filling them means authoring: (i) a patch file, (ii) an
entry in `tiny_scenario.scenario_specs`, (iii) a Bs.N id. All are
mechanical if the recipe shape is right.

### 7.2 `tiny_recipe` synthesis from an abstract cell

**Status: active pickup — Phase 1 next** (un-postponed
2026-07-20). §7.8 (project abstraction) deferred; §7.2 is
no longer blocked by it and picks up on its own merits as
the natural next step in the ssot-tiny-canary sync line.

**Doc-sync riders** per phase — each commit lands the SSOT
+ tiny.md updates its code opens up:

| Phase | Code | SSOT sync | tiny.md sync |
|---|---|---|---|
| 1 | New `mutation` variants in `canary_artifact_mutation.ml` (~250 LOC) | §5 mutation column: add Drop_c_symbol / Rename_c_symbol / Drop_ocaml_val / Drop_python_attr rows; possibly a new §5.3 (mutation shapes) | §7.2 Phase 1: mark done pointer + new mutation table |
| 2 | Extend workspace dispatch (~30 LOC) | — | §3 factory pipeline: note new mutation dispatch |
| 3 | `recipe_of_derived_cell` + (target, kind) → mutation table (~150 LOC) | §5.2 patterns-vs-instances: point at recipe synthesis as the derivation path; possibly a new §5.3 for the table; if C8 wiring comes up here, resolve it | §7.2 Phase 3: mark done + link |
| 4 | Fold `derived_scenario_specs` into `all_scenario_specs` (~50 LOC) | §5.1: add derived-cell rows once runnable | §6 coverage: recount cells filled |

Total ~480 LOC across 4 phases; one phase per session.

---

Today derived cells are name-only. To *run* a derived cell
we'd need to generate a `tiny_recipe` (mutation + expected
outcomes) from `(Good × target × kind)`. Would let the
mechanical filling in §7.1 become data-driven — the
enumeration `derived_scenarios` directly emits runnable
recipes.

Not urgent — hand-authored `.patch` files are usable today
(15/15 fixtures pass in `mutation-test`). The plan below is
saved for when we resume; nothing needs to happen soon.

*Prerequisite already done (`77f36ad`):* the pair (scenario +
recipe) was renamed from `entry` to `scenario_spec` throughout
the tiny code + design docs. The plan below uses those names
directly.

#### Design decisions locked in (2026-07-09)

| Question                            | Decision                                                                                                                                                                                                                                            |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mutation type organisation          | Flat top-level `type mutation` for pattern matching, per-artifact constructor modules for authoring: `Canary_artifact_mutation.Source.drop_c_symbol ~file ~symbol`. Symmetric with the `canary_artifact_*` inspection layer without a wrapper type. |
| Mutation → `violates` mapping       | **Enumerated** for MVP. Surface/agreement-driven derivation is a later retrofit.                                                                                                                                                                    |
| Which cells to synthesise           | **All**, then dedupe against hand-authored (hand takes precedence). Empty cells become synthesised entries automatically.                                                                                                                           |
| Cell → sample target (which symbol) | **Parameter with hardcoded defaults**. Argument for override; default is `tiny_sum` (source) / `sum` (mli/attrs). Heuristic picking from `api_source.stable_symbols` is future work.                                                                |

#### Phase 1 — Parametric mutation constructors

New flat variants in `canary_artifact_mutation.ml`:

```ocaml
type mutation =
  | Patch of { patch_file : string }                        (* existing *)
  | Soname_bump of { from_so : string; to_so : string }     (* existing *)
  | Drop_c_symbol of { file : string; symbol : string }        (* NEW *)
  | Rename_c_symbol of { file : string; from_ : string; to_ : string }  (* NEW *)
  | Drop_ocaml_val of { file : string; name : string }        (* NEW *)
  | Drop_python_attr of { file : string; attr : string }      (* NEW *)
```

Per-artifact constructor modules (organisation, not new types):

```ocaml
module Source  = struct let drop_c_symbol ~file ~symbol = ... end
module Native  = struct let soname_bump ~from_so ~to_so = ... end
module Binding = struct
  let drop_ocaml_val ~file ~name = ...
  let drop_python_attr ~file ~attr = ...
end
```

Tool wrappers `apply_drop_c_symbol_cmds` / `apply_rename_c_symbol_cmds`
/ `apply_drop_ocaml_val_cmds` / `apply_drop_python_attr_cmds` return shell
command strings (parallel to existing `apply_patch_cmd` /
`apply_soname_bump_cmds`). Implementation uses `sed` for line-based edits
and Python one-liners for structured edits.

Tests in `mutation-test` extend to cover each new constructor
(pure shape + shell apply on sandbox). Grand total goes from 46 → ~70.

**Scope: ~250 lines. Independent commit. Doesn't touch tiny_scenario.**

#### Phase 2 — Workspace dispatch

Extend the mutation-dispatch in `run_prepare`:

```ocaml
match recipe.mutation with
| Some (Patch _) -> apply_patch ...                    (* existing *)
| Some (Soname_bump _) -> apply_soname_bump ...        (* existing *)
| Some (Drop_c_symbol { file; symbol }) ->
    let cmds = Canary_artifact_mutation.apply_drop_c_symbol_cmds ... in
    List.for_all cmds ~f:(fun c -> run_shell c = 0)
| Some (Rename_c_symbol ...) -> ...
| ...
```

**Scope: ~30 lines. One pattern extension per variant.**

#### Phase 3 — Recipe synthesis

New function:

```ocaml
val recipe_of_derived_cell : Canary_scenario.scenario -> tiny_recipe option
```

Enumerated synthesis table:

| (target, kind)             | mutation                                                                         | violates | mutates                                 |
| -------------------------- | -------------------------------------------------------------------------------- | -------- | --------------------------------------- |
| Source, On_artifact Source | `Source.drop_c_symbol ~file:"c/src/tiny.c" ~symbol:"tiny_sum"`                   | [c1]     | `["c/src/tiny.c"]`                      |
| Source, On_behavior        | `Source.rename_c_symbol` (behaviour swap)                                        | [c3]     | `["c/src/tiny.c"]`                      |
| Lib, On_artifact Lib       | `Native.soname_bump ~from_so ~to_so`                                             | [c4]     | `["c/build/libtiny.so.1"]`              |
| Binding OCaml, _           | `Binding.drop_ocaml_val ~file:"ocaml/tiny.mli" ~name:"sum"`                      | [c2]     | `["ocaml/tiny.mli"]`                    |
| Binding Python, _          | `Binding.drop_python_attr ~file:"python_cext/tiny_cext/__init__.py" ~attr:"sum"` | [c2]     | `["python_cext/tiny_cext/__init__.py"]` |
| App, _                     | (skip — return None per Sc.3-6 retrospection)                                    | —        | —                                       |

Integration: `derived_scenarios` mapped through this to
`derived_scenario_specs`; concatenate with hand-authored `scenario_specs`,
dedupe via `matches_derived_cell`.

**Scope: ~150 lines including table + integration.**

#### Phase 4 — Runnable derived cells

Fold derived cells into the entry list:

```ocaml
let all_scenario_specs =
  let hand = scenario_specs in
  let derived =
    List.filter_map derived_scenarios ~f:recipe_of_derived_cell
    |> List.filter ~f:(fun ds ->
      not (List.exists hand ~f:(fun h ->
        matches_derived_cell h.scenario ds.scenario)))
  in
  hand @ derived
```

`tiny list`, `tiny prepare`, `canary action tiny/<name>` all see them via
one list. Derived cell names use their `Dv.*` ids from `derive_scenarios`.

**Scope: ~50 lines. `all_scenario_specs` replaces `scenario_specs` in
the module's exported list.**

#### Commit shape

1. Phase 1 — parametric mutation constructors (~250 lines)
2. Phase 2 — workspace dispatch (~30 lines)
3. Phase 3 — recipe synthesis (~150 lines)
4. Phase 4 — derived cells integration (~50 lines)

Each phase leaves the tree building and tests green.

Open sub-questions to confirm before starting Phase 1:
- Include `Rename_c_symbol` in Phase 1 or add later?
- Constructor naming: `Drop_c_symbol` vs `Remove_symbol` etc.?
- App cell handling — accept ceremonial gap, or want it?

### 7.3 Second mechanism axis — ctypes DFFI

Tiny has a `python_ctypes/` binding but canary never runs
against it. Sc.2 doesn't exist for ctypes (no
build_binding step under DFFI). Reintroducing ctypes as a
first-class arm needs:

- A mechanism dimension on the entry (SCAB vs DFFI)
- Scenario ordering (Sc.1 is shared; ctypes has no Sc.2;
  Sc.4.Python.ctypes vs Sc.4.Python.cext)
- Factory routing awareness

Deferred; hardcoded SCAB per user 2026-07-06.

### 7.4 Fill Sc.3–Sc.6 areas

Observation 2 in SSOT §5.1 flags Sc.3–Sc.6 as
zero-bad-scenario stages. Whether assembly-time / run-time
mutations belong at Sc.3+ is open; either confirm they
don't or add scenarios that do. Overlaps §7.1 (empty cells
are exactly these) but also a manuscript concern —
`research/tiny.md` needs the answer for the paper's
completeness argument.

### 7.5 Tiny packaging coverage

Add packaging-error scenarios: opam/pip/apt repackaging
mistakes, cross-PM SONAME drift. Required for Principle 4
(cross-PM interop) to have a concrete witness. Blocker: a
`Package` mutation source (SSOT status §2 near-term).

### 7.6 Contract catalogue extension

After tiny fills out: extend c1..c8 based on real-world
bugs. Detailed in
[`bad_scenario_flavors.md`](bad_scenario_flavors.md). Not
tiny-scoped; belongs to the post-tiny research task.

### 7.7 Route tiny commands through `tool/` — done, macOS follow-up

**Landed 2026-07-09.** Both sub-gaps shipped: direct-compile
family in `src/canary/tool/canary_cc.ml`, inspector
`_pipe_cmd` variants in `Canary_artifact_native` /
`Canary_artifact_lang`, all 6 tiny inspectors refactored,
110 inspect JSONs byte-verified. Full arc + byte-stability
notes + the incidental `inspect_bo6` bug fix recorded in
[`worklog/worklog_2026_07.md` — R2 arc](../worklog/worklog_2026_07.md#r2-arc--route-tiny-through-tool-2026-07-09).

**Remaining open item — macOS verification (separate session).**
Tiny's inspectors now inherit
`Canary_artifact_native.nm_cmd`'s `nm -g` on macOS via the
pipe primitives; `canary_cc.ml` gives a single site to patch
for Mach-O differences. Running `tiny baseline` +
`tiny prepare-all` + `canary artifact-test` on a Mac and
diffing `_cache/*/inspect/*.json` against a known-good
Linux snapshot is the natural next step. Couples with the
broader macOS-support work called out in
[`CLAUDE.md` Known-Gap](../../CLAUDE.md).

Relates to `backlog.md` #18 (audit specs for hardcoded
shell commands routed through named primitives) and #47
(unify store-selection patterns). Nicknamed R2 in the
2026-07-08 conversation.

### 7.8 Task 2 — recipe/mutation integration (project-hookable factory)

**Status: active pickup candidate.** Sequel to Phase G. Also
tracked in [`status.md §2`](../status.md).

### Context

Phase G (2026-07-09) unified `Canary_scenario.scenario` —
`.origin` replaced `.mutation`; nullary `Version_mismatch` and
`Packaging` reserved. That was the *scenario*-side
integration. The *recipe*-side gap remains:

- Tiny defines `tiny_recipe` in
  [`canary_tiny_scenario.ml:60`](../../src/canary/projects/canary_tiny_scenario.ml#L60):
  `{ mutates; mutation; expected; violates }`. Factory
  functions (`stores_of_entry`, `expectation_of_entry`,
  `project_spec_of_entry`) derive the runnable `project_spec`
  from it. `expectation_of_entry` reads `violates + language`,
  delegates to `compat_inputs_of_contract ~lang c` for JSON
  paths, wraps in `Expect_compat_failure { inputs;
  version_info }`.
- z3 / llvm / sqlite have **no parallel**. Their variants
  hand-code `Expect_compat_failure` inline in the project
  spec — llvm's stable variant spells out the predicted
  substring by name
  ([canary_project_llvm.ml:495-512](../../src/canary/projects/canary_project_llvm.ml#L495-L512),
  18 lines: `Opcode.UncondBr` version_info); z3 stable
  Python variant same shape
  ([canary_project_z3.ml:541-551](../../src/canary/projects/canary_project_z3.ml#L541-L551),
  10 lines: `parser_context`). Structurally identical to
  tiny's derivation, just typed out inline.

Goal: lift tiny's recipe/factory pattern into a
project-hookable interface so z3 / llvm / sqlite can supply
their own recipes and inherit the uniform derivation.

### Phased plan (~230 LOC total; non-breaking per phase)

| Phase | Scope | LOC |
|---|---|---|
| **1. Generic recipe shape** | New module `Canary_recipe` (or extend `Canary_scenario`) with project-agnostic fields: `type recipe = { violates; expected; mutates }`. `tiny_recipe` becomes `{ generic : recipe; concrete_pert : mutation option }` (concrete tiny extras stay tiny-specific). No behavior change. | ~50 |
| **2. Project hooks + generic expectation deriver** | Extract `expectation_of_scenario ~hooks ~scenario`, where `hooks : { compat_inputs_of_contract; version_info_of_origin }` is project-supplied. Tiny becomes the reference implementation. Behavior byte-identical to today. | ~80 |
| **3. llvm refactor** | Add `llvm_recipe` (or use generic directly) + `llvm_hooks` with opam-path-flavored `compat_inputs_of_contract`. Replace the hand-coded `Expect_compat_failure` with recipe-driven derivation. `Version_mismatch` origin becomes the natural fit. | ~40 |
| **4. z3 refactor** | Same shape as llvm. Python variant (`Probe_binding Python`). | ~40 |
| **5. sqlite refactor** | Smallest — positive-only, so just plug in hooks; no expectation change. Sanity that the interface fits both compat-failure and positive-only projects. | ~20 |

### Verification per phase

- **Phase 1 & 2**: `canary artifact-test` (framework
  tests) + `canary tiny run` (15/15) — behavior-preserving.
- **Phase 3**: `canary action llvm` — dev + stable
  variants; stable must still produce the `Opcode.UncondBr`
  prediction and match probe.log.
- **Phase 4**: `canary action z3` — stable variant
  `parser_context` prediction unchanged.
- **Phase 5**: `canary action sqlite` — plain success.

### Prerequisite: baseline the non-tiny projects

Before Phase 1 starts, run the non-tiny projects locally to
capture current behavior:

- `canary action sqlite`
- `canary action z3`
- `canary action llvm`

Each project has a dev variant (build from source) and a
stable variant (fetch pre-built or use a distro package):

- **llvm**: dev builds LLVM from a locally-cloned source
  (ninja); stable uses `apt install libllvm-19-dev`
  + `opam install llvm.19-shared`.
- **z3**: dev builds Z3 from source (cmake); stable uses
  the `z3` opam package + `z3-solver` pip wheel.
- **sqlite**: dev builds from a fetched source; stable uses
  the system-installed `libsqlite3-dev` + Python stdlib.

The prerequisite catches: (a) which builds are actually
runnable today; (b) which cached artifacts survive from
previous runs; (c) any bit-rot in the project specs since
the R2 refactor / Phase G. Records go to
[`worklog_2026_07.md`](../worklog/worklog_2026_07.md).

### Interaction with §7.2

Postponed §7.2's phase plan assumes tiny's current recipe
shape. Task 2 will change the shape, so §7.2 must re-baseline
after Task 2 lands.

### Out of scope

Explicitly deferred to future Task 2 follow-ups:

- **Sync `scenario.actions` with runtime** — per user
  2026-07-10 (see [`status.md §5`](../status.md)); best done
  as a Task 2 follow-up because it touches `derive_steps`.
- **`Package` origin variant activation** — needs a project
  that wants it (PyTorch tier-1 target per
  [`new_project.md`](new_project.md)).

### 7.9 Derive `related_artifacts` from `actions` — done 2026-07-10

**Status: complete.** Landed in three commits under
Cluster C:

1. `67d0e12` — rule type split: `Build_app of app_info`,
   `Probe_lib` / `Probe_binding of lang` / `Probe_app of
   app_info` (retiring `Probe of artifact_kind` and nullary
   `Build_app`). Every rule now carries its own language
   explicitly — no `belongs_to` suffix reach-through in
   downstream code. 78/78 tests, 15/15 tiny run stayed
   green.
2. `8f6e6fc` — first-pass derivation: added
   `Canary_scenario.artifacts_of_rule` (per-rule
   consumes/produces table, ordered prerequisite→target)
   and `related_artifacts_of_actions`. Reconciled
   `tiny_good_scenarios.actions` per-scenario (was
   `acts_full` cargo-culted across all 8). Kept the hand
   field guarded by a startup assertion.
3. `*this commit*` — retirement: removed
   `related_artifacts` from `type scenario` entirely;
   `Canary_scenario.related_artifacts s` is now the sole
   getter; five arts_* helper values in
   `canary_tiny_scenario.ml` and 17 field-write sites
   deleted; per-rule spec tests replace the hand-vs-derived
   invariant test.

Test surface: `scenario_derivation_pure_tests` in
[canary_artifact_test.ml](../../src/canary/test/canary_artifact_test.ml)
holds 7 spec cases (one per canonical Sc.N shape plus a
chain composition case). Rules table lives in
[SSOT §6.5.1](../design/ssot.md).

Bad-scenario `related_artifacts` — the same getter now
serves them too. `validate_mutation_target` derives from
the Bs's `actions` list (tiny's `acts_full`) which produces
`[Source; Lib; Binding OCaml; Binding Python; App]`; every
Bs mutation target sits in that set. The pre-fix
narrowing hints (`arts_ocaml_only`, `arts_python_only`,
etc.) were redundant with `belongs_to` and are gone.

## 8. Gotchas / rough edges (state-of-code notes)

Not urgent, worth knowing:

- **Auto-init is silent about baseline** — first run of any
  scenario auto-runs baseline. Second scenario is fast
  because baseline is reused. Not obvious from the prompt.

- **`base` route == correct-but-quiet** — concrete good
  scenarios (§2, formerly Pc.N) and Unknown_gap Bs entries
  (Bs.6 api_faithful, Bs.13 api_repack_stub_orphan) run to
  completion with all steps passing. No expectation fires;
  nothing to confirm. Reading the log alone doesn't
  distinguish "correct positive coverage" from "detection gap
  silently passed."

- **Diagram invariants warn for singleton projects** —
  `canary action tiny/<name>` produces
  "connectivity errors" warnings from
  `check_diagram_invariant`. Semantic pass still succeeds;
  diagram-side artefact. Not blocking; ignore.

- **`stores_of_entry` strip heuristic is fragile** —
  `strip_trailing_minor` works for `libtiny.so.2.0` →
  `libtiny.so.2` but assumes both trailing segments are
  numeric. A soname like `libtiny-1.0.so` would break.
  Fine for tiny; revisit for real projects.

- **`recipe.expected` is documentation, not check** — the
  per-step Ok/Fail/Pass/Skip predictions in each entry are
  emitted by `tiny expected <name>` but the
  runner doesn't verify them. Under R2 they could become a
  cross-check against canary's actual step statuses.
