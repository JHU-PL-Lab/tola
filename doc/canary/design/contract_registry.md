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
type role =
  | Surface    (* one artifact: what it presents at its boundary *)
  | Meeting    (* two artifacts: are they compatible where they link/load *)
  | Execution  (* two artifacts running: what the pair's trace shows *)

type contract_row = {
  row_check   : Canary_compat.contract_check;
      (* id, name, layer, status, enabled, predict — already exists *)
  invariant   : string;
      (* the one-sentence agreement, phrased as a FALSIFIER (§5); the
         reconciliation point for ssot's Ag.X ↔ C1..C8 drift decision *)
  role        : role;
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

## 4. The three LOGICAL roles — slots, not a classification of methods

The roles name the structure of checking itself — the artifact-relationship
axis the action graph already has (inspect steps / build steps / probe
steps). Every concrete method, present or future, is PLACED into a slot:

| Role | Asks | Concrete things today | Future things |
|---|---|---|---|
| **Surface** | what does ONE artifact present at its boundary? | nm/objinfo/dir/mli inspections (c1, c2, c4, c5) | the richer inspectors (L1b/L2/L4 — step 8) |
| **Meeting** | are TWO artifacts compatible where they MEET (link/load)? | strict-flag compiles/links, the build_binding meeting (c6, c7, c8) | dry-run builds; the interposition shim as a RECORDER — which symbols the consumer actually requests at load (the oracle for "what the binding really needs") |
| **Execution** | what happens when the pair RUNS? | our probe apps, behavioral greps (c3) | decl-DERIVED programs (generated from the API invariant — beyond symbol-missing); the shim as a FAKE provider (consumer robustness); upstream test suites |

**Probing vs testing — resolved.** Probing IS testing: an executing
consumer program. The distinction I previously drew (probe vs project's
own suite) is not a role — it is the PROVENANCE of the program inside
the Execution slot:

- hand-written (ours — the minimal deterministic canary),
- decl-derived (generated from the API invariant — our coverage scales
  without human effort),
- external (upstream suites — the strongest falsifier we can borrow,
  M3's fix-validation; canary doesn't own them, it consumes the slot).

**Provision still gates slots, not roles.** A Fetched binding has no
build step, but the Meeting role does not vanish — the loader's symbol
resolution AT PROBE TIME is itself a meeting, observable with the
recorder shim. Built worlds additionally meet at compile/link. The
role is stable; the stages at which it manifests follow
(mechanism × provision).

**The three read as one pipeline**: surfaces say what must hold,
meetings test whether the pair can even join, executions show what
the joined pair did — and the upstream suite vouches for the fix
after canary's falsifier found the break.

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
  falsifier is armed with. A richer decl = a stronger disprover;
- the recorder shim narrows c1's blindness WITHOUT turning it into a
  proof: it shows what the consumer actually requested in THIS run —
  requests-beyond-declared are still counterexamples, but "nothing
  beyond" holds only for the runs observed, never for all runs.

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
