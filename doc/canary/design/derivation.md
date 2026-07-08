# Deriving `script_spec` from `tiny_recipe`

Task 1.6 landing reference. Documents *what shipped* — the
factory shape in
[`canary_tiny_scenario_project.ml`](../../src/canary/projects/canary_tiny_scenario_project.ml)
— not future work. For arc + rationale, see
[`worklog_2026_07.md`](../worklog/worklog_2026_07.md).

## Factory pipeline

Input: `entry = { scenario; recipe }` from
`Canary_tiny_scenario`.
Output: `Canary_step_builder.script_spec` that canary can run
as its own project via `run_project` (no multi-variant
orchestration).

Pipeline:

```
entry
  |> route_of_entry         : `Derived | `Base | `Dispatched
  |> stores_of_entry ~stores : may override stores.lib_filename
                               from recipe.perturbation
  |> match route with
     | `Derived    → base_spec with expectation = expectation_of_entry
     | `Base       → base_spec (no expectation override)
     | `Dispatched → fail (empty table today)
```

## `route_of_entry`

Decides how the entry is realised. Two facts drive it:

1. **`has_probe_manifestation`** — reads
   `scenario.perturbation.manifest`:
   - `None` (positive coverage) → false
   - `Some { manifest = Unknown_gap; _ }` → false (detection
     gap; no probe observable failure)
   - `Some _` (Definite / Possible) → true

2. **`is_derivable_contract`** — is at least one contract in
   `recipe.violates` covered by
   `compat_inputs_of_contract` or
   `is_expect_failure_contract`?

Result:

| has_probe_manifestation | violates_derivable | route |
|---|---|---|
| true | true | `Derived |
| false | * | `Base (Pc.* or Unknown_gap Bs.*) |
| true | false | `Dispatched (empty table today) |

## `expectation_of_entry` — two orthogonal axes

- **Language** (outer, per-scenario constant):
  `langs_of_scenario` reads `scenario.belongs_to` suffix:
  - `Sc.N` (no suffix) → `[OCaml; Python]`
  - `Sc.N.OCaml` → `[OCaml]`
  - `Sc.N.Python` → `[Python]`

- **Contract** (inner, per rule + lang): first violated
  contract that yields inputs for the current lang wins.

Two expectation shapes:

| Shape | Contracts | Firing step | Payload |
|---|---|---|---|
| `Expect_compat_failure` — static comparator | c1, c2, c4, c5, c6 | `Probe (Binding lang)`; c6 also at `Build_binding lang` | `inputs` (per-contract) + `version_info` |
| `Expect_failure` — probe assertion | c3, c7 | `Probe (Binding lang)` | `contains_any = ["FAIL "]` |

Compat-first priority: at `Probe (Binding lang)`, try
`compat_inputs_of_contract` for each violated contract in
list order; first `Some inputs` wins. If none, fall back to
`Expect_failure` if any behavioural contract is violated;
else `Expect_success`.

`Build_binding lang` fires only when c6 is violated (unique
site among current contracts).

## Per-contract inputs — the table today

`compat_inputs_of_contract ~lang c` returns the JSON paths
canary reads to compute the predicted substring set:

| Contract | Lang scope | Inputs |
|---|---|---|
| c1 cmp_symbol | any | `C_stub [build_binding_<lang>/inspect.json]` + `Native_lib [build_lib/inspect.json]` |
| c2 cmp_api_completeness | OCaml | `Ocaml_mli [build_binding_ocaml/inspect_mli.json]` |
| c2 cmp_api_completeness | Python | `Python_attrs [build_binding_python/inspect_attrs.json]` |
| c4 cmp_abi | Python (tiny convention) | `Native_lib [build_lib/inspect.json]` + `Abi_surface [build_binding_python/inspect.json]` |
| c5 cmp_sym_version | Python (tiny convention) | `Versioned_exports [build_lib/inspect.json]` + `Versioned_req [build_binding_python/inspect.json]` |
| c6 cmp_type | OCaml (tiny convention) | `Typed_header` + `Typed_binding_stub` from `scan_sources/` |

The "tiny convention" columns reflect tiny's store choice:
Python cext is cached from baseline; OCaml binding rebuilds
fresh each run. Only cached bindings see stale ABI /
versioned-req / cext-behaviour issues; only rebuilt bindings
see compile-time type mismatches. A different project could
scope these differently; extend
`compat_inputs_of_contract` at that time.

## `stores_of_entry` — perturbation-driven store adjustment

Some concrete perturbations change the store shape. Today
only `Soname_bump { to_so; _ }`:

```
to_so = "libtiny.so.2.0"
  →  strip_trailing_minor: last two dotted segments are numeric
  →  lib_filename = "libtiny.so.2"
```

Applied uniformly to Derived and Base routes.

## Coverage today

Distribution of the 15 tiny entries:

| Route | Count | Entries |
|---|---|---|
| `Derived | 11 | symbol_missing, symbol_orphan, api_complete, api_complete_python, behavior_silent, type_wrong, api_repack, api_repack_python, abi_soname_bump, symbol_version_floor, header_arity_bump |
| `Base | 4 | api_faithful (c8 dormant), api_repack_stub_orphan (c7 static-only), Pc.1 (app_over_binding_ocaml), Pc.2 (app_over_helper_ocaml) |
| `Dispatched | 0 | (empty table) |

Every scenario with a probe-observable manifestation
derives its expectation structurally from
`recipe.violates + scenario.belongs_to + recipe.perturbation`.
No named dispatch.

## Auto-init

`run_tiny_scenario ~name` in
[`canary_main.ml`](../../src/bin/canary_main.ml) checks
`_cache/<name>/workspace/` and auto-runs
`Canary_tiny_baseline.run ()` + `Canary_tiny_prepare.run ~name`
if missing. Single-command experience:

```
canary action tiny-scenario/symbol_missing   # first run auto-inits;
                                             # subsequent runs skip
canary action tiny-scenario                  # all 15 in list order
```

## Interaction with `recipe.perturbation`

The concrete perturbation drives *store synthesis*
(prepare → workspace) plus one lib_filename adjustment via
`stores_of_entry`. It does **not** appear in the expectation
derivation — `recipe.violates` alone determines what to
check.

This orthogonality is the payoff of Task 1.5's shape choice:
perturbation and contract are independent axes, and the
factory reads only the latter.

## Not covered

Deferred to follow-ups — see
[`bad_scenario_flavors.md`](bad_scenario_flavors.md) for
future flavor-2 / contract-catalogue work.

- Multi-contract aggregation semantics (which contract wins
  when a recipe violates several with different shapes).
  Today first-wins via list order; adequate for the 15
  entries.
- Structural inference of `scenario_langs` beyond the
  `belongs_to` suffix rule.
- `tiny_recipe` synthesis from an abstract derived cell
  (SSOT §9.3 Task 1.6 backlog).
