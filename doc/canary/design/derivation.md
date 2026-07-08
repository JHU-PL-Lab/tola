# Deriving expectations from `tiny_recipe`

Reference for Task 1.6 P1 — the A2-with-factory shape.
Not a plan-of-record; captures the shape of "expectation as
data" for future use, while we build tiny run-time checks
first. See [`worklog_2026_07.md`](../worklog/worklog_2026_07.md)
for the arc.

## Derivation contract

Factory input: `entry = { scenario; recipe }` from
`Canary_tiny_scenario`. Recipe carries `violates :
contract_id list` — the contracts this scenario is designed
to trigger.

Factory output: an `expectation` function that overrides the
`script_spec.expectation` field. Same shape as the hand-coded
`make_*_broken_script_spec` versions in `canary_project_tiny.ml`
but generated instead of transcribed.

## Two expectation shapes

Contracts split cleanly by check mechanism:

| Shape | Contracts | Firing step | Payload |
|---|---|---|---|
| `Expect_compat_failure` — static comparator | c1, c2, c4, c5, c6 | `Probe (Binding lang)` (c6 may also fire at `Build (Binding lang)`) | `inputs : compat_input list` + `version_info : string option` |
| `Expect_failure` — probe assertion | c3, c7 | `Probe (Binding lang)` | `contains_any : string list` (typically `["FAIL "]`) |

Behavioral contracts (c3, c7) don't need `inputs` — the
probe binary itself calls `assert` on the observed behavior.
Static-comparator contracts need per-contract inspect JSON
paths so `predicted_contains_any_v2` can compute the
predicted substring set.

## Per-contract inputs

Static-comparator contracts each have their own inputs shape
that reflects what they compare:

| Contract | Meaning | Inputs |
|---|---|---|
| c1 cmp_symbol | Set inclusion: stub-required ⊆ lib-defined | `C_stub [<lang>/inspect.json]` + `Native_lib [build_lib/inspect.json]` |
| c2 cmp_api_completeness | Watchlist ⊆ lang-surface exports | `Ocaml_mli [...]` or `Python_attrs [...]` (lang-specific input constructor) |
| c4 cmp_abi | Soname match | `Native_lib [...]` + `Abi_surface [...]` |
| c5 cmp_sym_version | Versioned exports satisfy versioned requirements | `Versioned_exports [...]` + `Versioned_req [...]` |
| c6 cmp_type | Header signature matches stub signature | `Typed_header [...]` + `Typed_binding_stub [...]` (both from `scan_sources`) |

Payoff: the derivation is a fold over `recipe.violates` — for
each contract, contribute a case to the expectation function.

## Two orthogonal axes: contract × language

Following the axes user identified 2026-07-08:

- **Contract** — inner loop; drives inputs shape.
- **Language** — outer loop; determined at scenario choice.

For a given scenario, the language(s) at which its contracts
fire is a scenario-level property, derived from
`scenario.belongs_to` (which good scenario the entry sits
under):

| Good scenario suffix | Languages | Example scenarios |
|---|---|---|
| `Sc.1` (no suffix, shared) | `[OCaml; Python]` | symbol_missing, abi_soname_bump — perturb shared artifacts; every binding sees the effect |
| `Sc.N.OCaml` | `[OCaml]` | symbol_orphan, api_repack, api_complete — perturb OCaml-only artifacts |
| `Sc.N.Python` | `[Python]` | api_repack_python, api_complete_python — perturb Python-only artifacts |

Consequence: **the expectation function must scope its
`Probe (Binding lang)` match to the scenario's language set.**
A c1 derivation that fires at all langs works for
`symbol_missing` (Sc.1 → both) but misfires for
`symbol_orphan` (Sc.2.OCaml → OCaml only, Python probe should
succeed).

## Full derivation sketch

Pseudocode reflecting both axes:

```
let expectation_of_entry (entry : entry) =
  let scenario_langs = langs_of_scenario entry.scenario in
  let violates_c1 = List.mem entry.recipe.violates C1 in
  let violates_c2 = List.mem entry.recipe.violates C2 in
  (* ... one per contract *)
  fun rule _loc ->
    match rule with
    | Probe (Binding lang) when List.mem scenario_langs lang ->
      (* Priority order: strongest contract wins, or aggregate
         inputs across contracts. TBD as more contracts land. *)
      if violates_c1 then Expect_compat_failure { c1_inputs lang; None }
      else if violates_c2 then Expect_compat_failure { c2_inputs lang; None }
      else if violates_c3 then Expect_failure { contains_any = ["FAIL "] }
      (* ... *)
      else Expect_success
    | _ -> Expect_success
```

Open questions when multiple contracts co-occur (e.g., some
Bs entries violate both c1 and c6 in cascading fashion):

- Which contract's expectation wins? (Both must be observable
  in the probe output; picking one and asserting its substring
  may pass even if the other silently held.)
- Or aggregate: emit an expectation that succeeds if *any*
  cited contract's predicted substring appears.

Deferred until scenarios that actually violate multiple
contracts get their derivation. Most tiny entries today are
single-contract.

## Failure modes noted while building the shape

- **`c6` fires at build OR probe** — `binding_type_broken` has
  the mismatch surface at `Build (Binding OCaml)` (C compile
  error) rather than `Probe`. Site is per-scenario, not
  per-contract. Encode as a site hint on the recipe, or infer
  from where inputs are produced. Deferred; today's hand-coded
  version fires at both sites.

- **Multi-contract recipes with different langs** — a
  hypothetical Sc.1 scenario that violates c1 (both langs) and
  c2 (OCaml only). The lang-scope filter must be per-contract,
  not per-scenario. If it comes up, promote `scenario_langs`
  to a `(contract * lang list) list` on the recipe.

- **`Expect_failure` vs `Expect_compat_failure` selection** —
  behavioral contracts (c3, c7) are `Expect_failure`, others
  are `Expect_compat_failure`. The choice is per-contract;
  when a recipe mixes both, we need aggregation semantics.
  Currently deferred as recipes are single-shape.

## Interaction with `recipe.perturbation`

The perturbation drives *store synthesis* (patches, soname
bumps — how to produce the perturbed workspace) but does not
appear in the expectation derivation. `recipe.violates` alone
determines the check; `scenario.perturbation.target` is
opaque to the factory.

That's the payoff of Task 1.5's shape choice — perturbation
and contract are orthogonal, and the factory only reads the
latter.

## Not doing yet

- Growing the contract coverage (this doc is reference for
  when we do).
- Multi-contract aggregation semantics.
- Site hints for `c6`.
- Structural inference of `scenario_langs` beyond the
  `belongs_to` suffix rule.
- Retiring the hand-coded `make_*_broken_script_spec`
  helpers — they stay as fallback until every contract is
  derived.
