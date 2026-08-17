# Contract registry — the belief module

> 2026-08-17. M2 step 6 design (producer-first; consumers migrate after).
> One statement per contract: WHAT the invariant is, HOW we check it
> (tool-based), WHERE it fires (derived from mechanism × provision ×
> stage). The expectations are entirely OUR machinery — unlike build
> commands, nothing external has to be respected; a hand-written
> per-project table is our own data and gets deleted once the derived
> firings pin equal.

## 1. Producer-first, two-agent-safe

The registry is a NEW additive module — `surface/canary_contract_registry.ml` —
that consumes nothing from `project/` or `main/`. It assembles the belief
from theory pieces that already exist:

- comparators + the `contract_check` proto-row (`id/name/layer/status/
  enabled/predict`) — `surface/canary_compat.ml`
- the predict closures + `registered_checks` — `surface/canary_compat_run.ml`
- the input template (`inputs_of_contract ?mechanism contract lang`) — M2
  step 2, same file
- the fault tags — `scenario.md`'s catalogue + `canary_expected_of`

Consumers (the lowering, the per-project binding tables, spec-check, the
tiny oracle) migrate in a SECOND phase, one at a time, each pinned. The
only rendezvous with the other agent is this module's exposed type, fixed
here — so the producer side can land while project work continues.

## 2. The row

Extending the existing `contract_check`, one row per contract states the
whole belief:

```ocaml
type evidence_kind =
  | Inspect_based   (* reads artifact SURFACES via tools — nm, objinfo, dir(), mli *)
  | Trace_based     (* reads the probe's EXECUTION trace — c3 only *)

type contract_row = {
  row_check   : Canary_compat.contract_check;
      (* id, name, layer, status, enabled, predict — already exists *)
  invariant   : string;
      (* the one-sentence agreement, phrased as a FALSIFIER (§5); the
         reconciliation point for ssot's Ag.X ↔ C1..C8 drift decision *)
  evidence    : evidence_kind;
  inputs      : Canary_mechanism.mechanism -> Canary_lang.lang ->
                Canary_compat.inspect_input list;
      (* the step-2 template — WHAT files the check reads, derived from
         the binding_decl (coupling products, surface_path) *)
  firing      : Canary_mechanism.mechanism ->
                Canary_enumerate.provision -> Canary_scenario.firing_site list;
      (* WHERE it fires — the derivation that replaces the hand-written
         per-project tables (§3) *)
  fault_tags  : string list;
      (* step 9: sym_missing ↔ c1, api_drop ↔ c2, … — the tag ↔ contract
         mapping becomes data on the row, not a synced-by-hand table *)
}

let contract_registry : contract_row list = [ ... c1 .. c8 ... ]
```

`firing` is THE new piece. Everything else is consolidation.

## 3. Provision-gated firing — which checks apply depends on which stages we got

A Fetched artifact (from the internet / a PM) and a Built artifact (from
source) are different WORLDS for checking, because different stages exist:

- **Built**: build sites exist — build-time contracts fire (c6's
  header/stub type match at `build_binding`), then link + probe sites.
- **Fetched / Vendored / Cached**: the product was given, nothing was
  built — build sites do not exist, and build-time contracts have nothing
  to fire on; probe-side checks (c1/c2/c4 at probe) still apply.

So the firing derivation has TWO axes, both already known to the framework:

1. **mechanism** (M2 step 3): Static_c_abi → build + probe sites;
   Dynamic_ffi → probe only.
2. **provision** (the action graph): a Fetched binding has no
   `Build_binding` step at all — the enumeration already prunes it.

`cr_firing mechanism provision` states both axes per contract instead of
per-project hand-listing. The pre/post conditions to check become a pure
function of `(decl, mechanism, provision)`.

## 4. The three roles — expectations, probes, and the project's own testing

Three things coexist today and their roles must be stated, because the
overlap is real ("checking a lib" vs "probing a lib"):

1. **Surface expectations** — the contracts (c1..c8 minus c3). They
   check what an artifact PRESENTS at its boundary (the five surfaces,
   Sf.1..Sf.5 in the draft): declared vs extracted, via tools. Static-
   sourced, dynamic-checked: inspect JSON → predict → grep probe.log.
   Evidence kind: `Inspect_based`.

2. **Runtime observations** — the probes. The draft already drew the
   line: *runtime observation is not a surface* (Sn.6 — probe input →
   expected output — is an observation of execution). Two sub-roles:
   - the probe as the CHECK CARRIER: probe.log is the substrate the
     surface predictions land in (the "dynamic-checked" half) — the
     probe step is the harness, not the check;
   - the probe as a behavioral contract: c3 (Behavior) — the trace's
     CONTENT is the invariant (tiny's sum outputs, sqlite's version
     string). The only contract whose evidence is execution. Evidence
     kind: `Trace_based`.

3. **The project's own testing** (M3 real-world) — upstream test suites
   (z3's regression tests, llvm lit, a wheel's pytest). Role: an
   EXTERNAL evidence source. When canary disproves compatibility, the
   upstream suite validates the fix (the GH PR runs the project's
   tests) and pre-screens candidate forks. It is NOT a canary contract
   — canary cannot own upstream suites. The registry models the SLOT
   (a `Project_suite` evidence source the landing workflow consumes),
   so the taxonomy is complete without pretending to run the world's
   tests.

The three read as one pipeline: **surfaces say what must hold,
traces show what happened, upstream suites vouch for the fix.**

## 5. The falsification stance

Version compatibility is hard to prove and easy to disprove — every
contract check is a DISPROVER, never a proof:

- c1 can catch a missing symbol, never prove the binding needs nothing
  else (nm only sees what the watchlist names);
- c2 catches watchlist drops, never proves API completeness;
- c3 refutes behavioral equivalence with ONE diverging output;
- c4 catches a soname bump, never proves ABI stability.

Registry implications:

- the `invariant` string is phrased as the FALSIFIER: "every
  watchlisted symbol exists in the lib" — not "the binding needs
  exactly the lib's symbols";
- `Expect_success` is "no counterexample found", never proof — the
  good-run PASS and the 0/0-bad-scenarios coverage line already say
  this; the registry makes it explicit per row;
- the watchlists are the disprover's ammunition: the decl's
  `c_api.functions` + the analysis watchlists ARE the test set the
  falsifier is armed with. A richer decl = a stronger disprover.

## 6. What remains project-specific (and shrinks)

- `enabled` / `disabled_contracts` — policy, already declarative;
- the watchlists — analysis side, canonicalized through
  `api_source`/`surface_of_api`;
- the probe scripts / examples (`probe_decl`) — which consumer runs;
- c3's behavior-grep patterns — the project's own behavior.

Everything else (inputs, firing sites, prediction wiring, tag mapping)
derives from `(registry × decl × mechanism × provision)`.

## 7. Sequence (each step keeps the suite green)

1. Land the producer: `contract_registry` rows for c1..c8 (statuses,
   invariant strings, evidence kinds, fault tags, input template,
   firing derivation). Consumers untouched — `registered_checks` and
   the per-project tables keep working. Pins: every row complete; the
   fault-tag mapping equals `canary_expected_of`; the invariant
   strings resolve the ssot Ag.X drift (the Ag.8 decision).
2. Switch `lower_expectation_agnostic` to derive firings from the
   registry; pin the derived firings equal to the hand-written tables
   (tiny first — richest case — then z3/llvm/sqlite).
3. Delete the per-project `*_contract_bindings`; the tiny oracle
   combinator (`expectation_of_entry`) consumes the registry.
4. Close the gaps inside the registry: c4/OCaml's Placeholder
   prediction, `symbol_orphan`'s build failure (a new id), statuses
   → all Wired.
5. Fault-tag sync (step 9) lands as `fault_tags` on the rows.
