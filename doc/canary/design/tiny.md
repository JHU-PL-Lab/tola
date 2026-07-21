# Tiny — how it works today, how we want it to work

Canonical description of tiny's implementation state and
near-term wish-list. Complements:

- [`ssot.md`](ssot.md) — truth (definitions, scenario tables)
- [`derived_vs_hardcoded.md`](derived_vs_hardcoded.md) — status map
  of what's derived vs hand-written in tiny + the "utility not raw"
  principle
- [`new_project.md §2.5`](new_project.md) — three levels of scenario
  coverage a new project can pick (A positive-only / B one hand-coded
  failure / C matrix — tiny is C, don't copy)
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

### 3.4 Mutation dispatch in workspace prep

`run_prepare` in
[`canary_tiny_workspace.ml`](../../src/canary/projects/canary_tiny_workspace.ml)
applies `recipe.mutation` at two points around the sandbox
build:

| Timing | Variants handled | Path |
|---|---|---|
| Pre-build | `Patch { patch_file }` | Local `apply_patch` wrapper (resolves `patches_dir` to absolute) |
| Pre-build | `Of_source m` / `Of_binding m` | `Canary_artifact_mutation.{Source,Binding}.apply_cmds ~sandbox m` — source-level mutations must be applied before `build_c_lib` / `build_ocaml_binding` so the compilation picks them up |
| Post-build | `Of_native m` | `Canary_artifact_mutation.Native.apply_cmds ~sandbox m` — binary surgery on the built lib (e.g. `Soname_bump`) runs after `build_c_lib` |

`Of_native.Soname_bump { from_so; to_so }` now uses full
SONAME names for both fields (was major + full mixed
under the retired `apply_soname_bump` wrapper); `Native.apply_cmds`
derives major and generic symlink names via
`strip_trailing_minor`. Bs.4 recipe updated accordingly
(2026-07-20).

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

**Concrete entries** — 15 hand-authored + 7 derived
= 22 in `Canary_tiny_scenario.all_scenario_specs`
(20 Bs, all Mutation-origin, + 2 concrete good scenarios per
SSOT §4.1). All 22 run through the uniform derivation. Split
by whether their expectation actually fires at probe:

| has probe manifestation?       | Count | Notes                                                                                                                                    |
| ------------------------------ | ----- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| yes — expectation fires        | 18    | 11 hand (symbol_missing, symbol_orphan, api_complete{,_python}, behavior_silent, type_wrong, api_repack{,_python}, abi_soname_bump, symbol_version_floor, header_arity_bump) + 7 derived (Phase 4 §7.2 + §7.1 Drop_python_attr). |
| no — Expect_success everywhere | 4     | api_faithful (c8 dormant), api_repack_stub_orphan (c7 static-only), Sc.4.OCaml (`app_over_binding_ocaml`), Sc.6.OCaml (`app_over_helper_ocaml`) |

**Derived cells** — the 20 design-space slots enumerated
by `derive_scenarios` (Good × related-artifact × applicable
kind). After §7.2 Phase 4 + §7.1 `Drop_python_attr`,
`tiny list` header: `20 derived cells, 12 filled, 8 empty`.
Filled cells comprise 5 shared with hand-authored Bs entries
plus 7 fresh synthesized (Sc.2/4/6 Source + Sc.2 Binding
OCaml + Sc.2/4 Binding Python + Sc.2/4 Lib Python; some are
dedup targets of Bs.1/4/8/10/12, the rest are new coverage).
The 8 empty cells are candidate flavor-1 mutations not yet
synthesizable (missing App-level primitive + OCaml Lib cells
awaiting c4 wiring).

**Two kinds of gap** to keep distinct:

- **Missing-entry gap** — one of the 8 empty derived cells.
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

Open items only. Numbering is stable — sections keep their
§7.N ids regardless of priority.

| #    | Item                                                                      | Cluster | Status                                          |
| ---- | ------------------------------------------------------------------------- | ------- | ----------------------------------------------- |
| §7.1 | Fill the 8 remaining empty derived cells                                  | A       | active; Drop_python_attr shipped 2026-07-21 + structural expectation lowering (SSOT §5.4). Remaining: wire c4-OCaml Placeholder (3 cells) + add App primitive (5 cells) |
| §7.4 | Fill Sc.3–Sc.6 areas                                                      | A       | overlaps §7.1                                   |
| §7.5 | Tiny packaging coverage                                                   | D       | long-horizon; needs Package mutation source     |
| §7.6 | Contract catalogue extension                                              | D       | post-tiny research task                         |
| §7.3 | Second mechanism axis — ctypes DFFI                                       | —       | deferred (user 2026-07-06)                      |
| §7.8 | Task 2 — recipe/mutation integration (project-hookable factory)           | —       | deferred / rescoped 2026-07-20 — see §7.8       |

Clusters: A = tiny scenario coverage / recipe machinery,
D = long-horizon.

*Recently shipped (kept as one-line pointers below for
context; full chronicles in
[`worklog_2026_07.md`](../worklog/worklog_2026_07.md)):
§7.2 recipe synthesis 2026-07-20, §7.9 related_artifacts
derivation 2026-07-10, §7.7 route tiny through `tool/`
2026-07-09, SSOT §6.6 `runner_spec` doc 2026-07-10
(`b9e4abc`).*

### 7.1 Fill the 8 remaining empty derived cells

`tiny list` shows **12 of 20 cells filled, 8 empty** after
§7.2 Phase 4 + §7.1's `Drop_python_attr` primitive +
structural expectation lowering (2026-07-21). All 8 gaps
sit on one of two remaining positions (`app` and OCaml
`lib`), each blocked by a **Placeholder binding** in
`tiny_contract_bindings` (SSOT §5.4) that would need to
become live before its cells synthesize:

| Blocker                          | Empty cells                                                                       | Placeholder to wire                                                                                                                                                                                                                                                                                                                        |
| -------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **c4 for OCaml**                 | Sc.2.OCaml.A1, Sc.4.OCaml.A2, Sc.6.OCaml.A2 (3 cells — `lib`)                     | `tiny_contract_bindings` entry for `(C4, OCaml)` is currently `Placeholder { reason = "OCaml ABI-analogue: packed .a NEEDED vs libtiny.so SONAME. Awaiting SSOT §? — decide whether tiny's OCaml store convention rebuilds fresh (current: c4 silent) or caches the packed .a" }`. Wire → 3 `Lib` cells auto-synthesize (guard reads the binding table). |
| **App-level mutation primitive** | Sc.3.OCaml.A2, Sc.4.OCaml.A3, Sc.5.OCaml.A2, Sc.6.OCaml.A3, Sc.4.Python.A3 (5 cells — `app`) | Two-step: (1) add an `App.<constructor>` in `canary_artifact_mutation.ml` (mimic downstream import breakage — one primitive per language). (2) Add `At_build_app lang` / `At_probe_app lang` firing sites for whichever contracts the App primitive triggers. Then the synthesis table's `App, _` case can emit a recipe.                     |

**Shipped 2026-07-21:**
- `Binding.Drop_python_attr` (sed-range primitive) — byte-parity
  with `api_complete_python.patch` verified. Filled Sc.4.Python.A1;
  net coverage 11/20 → 12/20.
- **Structural expectation lowering.** Contract firing sites and
  source-of-observation are typed data in `tiny_contract_bindings`
  (SSOT §5.4). `expectation_of_entry` is a pure lookup. Adding a
  new contract wiring is a data row, not a code branch. c4-OCaml
  and c8-OCaml enter as `Placeholder` (visible-TODO); the synthesis
  guard consults `Canary_scenario.binding_has_live_firing`
  instead of hand-coding "Python in langs". Startup validator
  guards against "scenario expects to fire but all contracts
  Placeholder".

Once a Placeholder's binding gets wired (Placeholder →
`From_artifact { inputs }` or `From_behavior_grep`), its cells
synthesize automatically via `all_scenario_specs` fold — no
per-Bs authoring needed. Authoring effort collapses from
`per-cell` to `per-primitive`, and now further to
`per-binding-wiring`.

### 7.2 `tiny_recipe` synthesis from an abstract cell — shipped 2026-07-20

Phases 1-4 all shipped 2026-07-20; chronicle + design
decisions in
[`worklog_2026_07.md` — §7.2 Phases 1-4 shipped](../worklog/worklog_2026_07.md).
Follow-up: §7.1 (fill remaining 9 empty cells).

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

### 7.7 Route tiny commands through `tool/` — shipped 2026-07-09

R2 shipped 2026-07-09 (chronicle in
[`worklog_2026_07.md` — R2 arc](../worklog/worklog_2026_07.md#r2-arc--route-tiny-through-tool-2026-07-09)).
Open follow-up: macOS verification — run `tiny baseline` +
`tiny prepare-all` + `canary artifact-test` on a Mac and
diff `_cache/*/inspect/*.json` against Linux snapshots.
Couples with the broader macOS-support gap in
[`CLAUDE.md`](../../CLAUDE.md).

### 7.8 Task 2 — recipe/mutation integration (project-hookable factory)

**Deferred / rescoped 2026-07-20.** Full context + phased
plan (~230 LOC, 5 phases) parked in
[`worklog_2026_07.md` — Task 2 parked plan](../worklog/worklog_2026_07.md).
Revisit once §7.1 fills the derived cells and the recipe
layer is settled enough to abstract; sqlite/z3/llvm stay
second-tier per the working principle above.

### 7.9 Derive `related_artifacts` from `actions` — shipped 2026-07-10

Cluster C landed 2026-07-10 in three commits (`67d0e12`,
`8f6e6fc`, retirement commit). `related_artifacts` field
retired; `Canary_scenario.related_artifacts s` is the sole
getter, derived from `scenario.actions` via
`artifacts_of_rule` (per-rule consumes/produces table). Test
surface: `scenario_derivation_pure_tests` in
[canary_artifact_test.ml](../../src/canary/test/canary_artifact_test.ml).

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
