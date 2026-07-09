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
SSOT §5 defines the 13 Bad scenarios (Bs.1..Bs.13) and
2 Positive coverage scenarios (Pc.1, Pc.2).

Each Bad scenario has a `tiny_recipe`:

- `perturbs : string list` — which files under `canary/examples/tiny/`
  the perturbation touches (closed universe of ~15 files:
  `c/src/tiny.c`, `c/include/tiny.h`, `c/tiny.map`,
  `ocaml/tiny*.ml{,i}`, `ocaml/tiny_stubs.c`,
  `ocaml/tiny_helper/*.ml{,i}`,
  `python_cext/tiny_cext/{__init__.py, _native.c}`,
  `python_ctypes/tiny_ctypes/{__init__.py, _raw.py}`)
- `perturbation : concrete_pert option` — either
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
                               from recipe.perturbation
  |> { base_spec with expectation = expectation_of_entry entry }
```

One uniform path — no per-entry routing. Positive-coverage
(Pc) entries and detection-gap Bs entries (Unknown_gap
manifest) get `Expect_success` for every rule because
`expectation_of_entry` checks `has_probe_manifestation` up
front. Equivalent to no override at all; base spec runs to
completion.

### 3.1 Expectation derivation

Two orthogonal axes:

- **Language** (outer, per-scenario constant):
  `langs_of_scenario` reads `belongs_to` suffix.
  `Sc.N` → `[OCaml; Python]`; `Sc.N.OCaml` → `[OCaml]`;
  `Sc.N.Python` → `[Python]`.
- **Contract** (inner, per rule + lang): first violated
  contract yielding inputs for the current lang wins.

Two expectation shapes:

| Shape | Contracts | Firing step | Payload |
|---|---|---|---|
| `Expect_compat_failure` — static comparator | c1, c2, c4, c5, c6 | `Probe (Binding lang)`; c6 also at `Build_binding lang` | per-contract `inputs` + `version_info` |
| `Expect_failure` — probe assertion | c3, c7 | `Probe (Binding lang)` | `contains_any = ["FAIL "]` |

### 3.2 Per-contract inputs

`compat_inputs_of_contract ~lang c` returns the JSON paths
canary reads to compute the predicted substring set:

| Contract | Lang scope | Inputs |
|---|---|---|
| c1 cmp_symbol | any | `C_stub [build_binding_<lang>/inspect.json]` + `Native_lib [build_lib/inspect.json]` |
| c2 cmp_api_completeness | OCaml | `Ocaml_mli [build_binding_ocaml/inspect_mli.json]` |
| c2 cmp_api_completeness | Python | `Python_attrs [build_binding_python/inspect_attrs.json]` |
| c4 cmp_abi | Python (tiny convention) | `Native_lib` + `Abi_surface [build_binding_python/inspect.json]` |
| c5 cmp_sym_version | Python (tiny convention) | `Versioned_exports` + `Versioned_req [build_binding_python/inspect.json]` |
| c6 cmp_type | OCaml (tiny convention) | `Typed_header` + `Typed_binding_stub` (both from `scan_sources/`) |

The "tiny convention" columns reflect tiny's store choice:
Python cext is cached from baseline; OCaml binding rebuilds
fresh each run. Only cached bindings see stale ABI /
versioned-req / cext-behaviour issues; only rebuilt bindings
see compile-time type mismatches. A different project could
scope these differently.

### 3.3 Store adjustment

`stores_of_entry` derives `lib_filename` from
`recipe.perturbation.Soname_bump { to_so }` by stripping the
trailing minor version:

```
to_so = "libtiny.so.2.0"  →  lib_filename = "libtiny.so.2"
```

Other perturbations (patches) don't adjust stores.

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
│   ├── source/                  snapshot of PERTURBABLE_SOURCES
│   └── workspace/               materialised workspace
└── <scenario>/
    ├── inspect/<alias>.json     perturbed inspector outputs
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
canary action tiny            # all 15 in tiny list order
```

Auto-init: `run_tiny_scenario` in
[`canary_main.ml`](../../src/bin/canary_main.ml) checks
`_cache/<name>/workspace/`. Missing → runs
`Canary_tiny_baseline.run ()` then
`Canary_tiny_prepare.run ~name` before invoking canary.
Existing workspaces are trusted.

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
`Canary_tiny_scenario.entries` (13 Bs + 2 Pc). All 15 run
through the uniform derivation. Split by whether their
expectation actually fires at probe:

| has probe manifestation? | Count | Entries |
|---|---|---|
| yes — expectation fires | 11 | symbol_missing, symbol_orphan, api_complete, api_complete_python, behavior_silent, type_wrong, api_repack, api_repack_python, abi_soname_bump, symbol_version_floor, header_arity_bump |
| no — Expect_success everywhere | 4 | api_faithful (c8 dormant), api_repack_stub_orphan (c7 static-only), Pc.1, Pc.2 |

**Derived cells** — the 20 design-space slots enumerated
by `derive_scenarios` (Good × related-artifact × applicable
kind). Header of `tiny list`:
`20 derived cells, 5 filled, 15 empty`. The 5 filled cells
contain the 13 Bs entries (several Bs entries can share a
cell); the 15 empty cells are candidate flavor-1
perturbations not yet authored (see §7.1).

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
scenario.belongs_to + recipe.perturbation`. Zero name
dispatch, zero routing tables.

## 7. Wish-list

Near-term, tiny-focused. See
[`status.md`](../status.md) for the live backlog.

### 7.1 Fill the 15 empty derived cells

`tiny list` shows 20 derived cells (Good × related
artifact × applicable kind); 5 filled, 15 empty. Each empty
cell is a candidate flavor-1 perturbation slot:

- Sc.3.OCaml, Sc.4.OCaml — app-level perturbations
- Sc.5.OCaml, Sc.6.OCaml — helper-chain perturbations
- Sc.2.Python (lib arm), Sc.4.Python — Python-side counterparts

Filling them means authoring: (i) a patch file, (ii) an
entry in `tiny_scenario.entries`, (iii) a Bs.N id. All are
mechanical if the recipe shape is right.

### 7.2 `tiny_recipe` synthesis from an abstract cell

Today derived cells are name-only. To *run* a derived cell
we'd need to generate a `tiny_recipe` (patch + expected
outcomes) from `(Good × target × kind)`. Would let the
mechanical filling in §7.1 become data-driven — the
enumeration `derived_scenarios` directly emits runnable
recipes.

Blockers: how to parametrise a perturbation as "drop
symbol X from artifact Y" rather than a hand-authored diff.

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
perturbations belong at Sc.3+ is open; either confirm they
don't or add scenarios that do. Overlaps §7.1 (empty cells
are exactly these) but also a manuscript concern —
`research/tiny.md` needs the answer for the paper's
completeness argument.

### 7.5 Tiny packaging coverage

Add packaging-error scenarios: opam/pip/apt repackaging
mistakes, cross-PM SONAME drift. Required for Principle 4
(cross-PM interop) to have a concrete witness. Blocker: a
`Package` perturbation source (SSOT status §2 near-term).

### 7.6 Contract catalogue extension

After tiny fills out: extend c1..c8 based on real-world
bugs. Detailed in
[`bad_scenario_flavors.md`](bad_scenario_flavors.md). Not
tiny-scoped; belongs to the post-tiny research task.

### 7.7 Route tiny commands through `tool/` (R2 remainder)

The former baseline/prepare pair inlined raw compiler /
inspector commands instead of routing through
`src/canary/tool/`. Two sub-gaps remain (the third — baseline
↔ prepare paths dedup, plus the file merge into
`canary_tiny_workspace.ml` — landed 2026-07-08 in commits
`90546b8` + `fb3ffd8`):

1. **No direct-compiler family in `tool/`.**
   `canary_build_cmd.ml` covers cmake/ninja/dune only —
   there is no primitive for gcc / ocamlfind / ar today.
   The unification must first *create* the family (a
   `canary_cc.ml`, or a direct-compile section of
   `canary_build_cmd.ml`): `cc_compile_obj`,
   `cc_link_shared` (soname + version-script args),
   `ocaml_compile`, `ar_archive`, `ocaml_archive`. Substantive
   half.
2. **Inspector pipelines duplicated, not reused.**
   `tool/` already has `Canary_artifact_native.inspect_cmd`
   / `elf_inspect_cmd` and `Canary_artifact_lang.{inspect_cmd,
   mli_inspect_*, stub_inspect_*}` — but
   `canary_tiny_workspace.ml` re-inlines the
   `nm | python3 inspect_*.py` invocations. Impedance
   mismatch: tool builders emit "write JSON to
   `<output_dir>/<marker>`" commands (runner path); tiny's
   baseline/prepare want capture-JSON-to-stdout to assemble
   the reference cache. Unifying means giving the tool
   builders a stdout/capture variant.

**Constraints:**

- *Keep the "owner decides the build" rationale.* Tiny uses
  direct compilers on purpose (canary-owned, not upstream).
  The new primitives should be a first-class direct-compile
  family, not a push to make tiny go through cmake/dune.
- *Portability dividend.* Tiny hardcodes `nm -D` (Linux-only);
  `Canary_artifact_native.nm_cmd` already picks `nm -g` on
  macOS. Routing through the tool builder fixes a latent
  macOS break.

**Recommended order:** (1) direct-compile family → (2)
inspector capture-vs-marker reconciliation. Each step keeps
the reference cache byte-stable, so diff against a known-good
`prepare-all` run after each.

Relates to `backlog.md` #18 (audit specs for hardcoded
shell commands routed through named primitives) and #47
(unify store-selection patterns). Nicknamed R2 in the
2026-07-08 conversation.

## 8. Gotchas / rough edges (state-of-code notes)

Not urgent, worth knowing:

- **Auto-init is silent about baseline** — first run of any
  scenario auto-runs baseline. Second scenario is fast
  because baseline is reused. Not obvious from the prompt.

- **`base` route == correct-but-quiet** — Pc entries and
  Unknown_gap Bs entries (Bs.6 api_faithful, Bs.13
  api_repack_stub_orphan) run to completion with all steps
  passing. No expectation fires; nothing to confirm. Reading
  the log alone doesn't distinguish "correct positive
  coverage" from "detection gap silently passed."

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
