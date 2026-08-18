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

type source =
  | Inspection      (* inputs → predict → compat-derived expectation *)
  | Behavior_grep   (* probe.log substring → failure expectation *)
  | Placeholder     (* Expect_success until wired (missing-ness visible) *)

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
  firing      : Canary_mechanism.mechanism -> Canary_lang.lang ->
                Canary_store.provision -> Canary_basic.action list;
      (* WHERE it fires — over the ACTION CATALOGUE
         (Canary_basic.action, the general base vocabulary; SSOT §6.5).
         Contracts are general for ALL artifacts, actions and
         mechanisms — any action kind can carry a check (fetch,
         configure, build, publish, probe, …); today's rows fire at the
         build/probe actions (the wired subset). No new firing type is
         invented; the action layer refines an action into
         Canary_scenario.firing_site (location, loc_filter) in phase 2.
         A row returns [] where nothing fires; the per-project
         enabled/disabled policy is the bypass. *)
  source      : source;
      (* HOW the expectation comes to be: Inspection | Behavior_grep |
         Placeholder — the three shapes of the old per-project
         expectation_source, minus the payload. The EXPECTATION half
         of the belief, stated per row. *)
  fault_tags  : string list;
      (* step 9: sym_missing ↔ c1, api_drop ↔ c2, … — the tag ↔ contract
         mapping becomes data on the row, not a synced-by-hand table *)
}

let contract_registry : contract_row list = [ ... c1 .. c8 ... ]
```

`firing` is THE new piece. Everything else is consolidation.

**Provisional naming.** The C1..C8 ids are the OLD index, kept for now
only because the consumers still speak it. With a principled
collection the contracts should be ENUMERATED and NATURALLY NAMED,
following the scenario-naming style (Sc.\<stage\>.\<terminal\>_on_\<deps\>):
once canonical names exist for artifact-surfaces (Sf.1..Sf.5), actions,
and platforms, a contract's name derives from those primitives (user,
2026-08-17). The rename lands with the canonical-naming settle step;
the invariant strings carry the semantics, so the rename is mechanical
— the `id` field is the one rename point.

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

`firing mechanism lang provision` states both axes per contract instead
of per-project hand-listing, and the domain is the FULL action
catalogue — not only build/probe: a source-integrity contract could
fire at `Fetch Source`, a publish-verification contract at `Publish
Lib` (the publish work lives with another agent). Today's rows return
the wired subset; extending a row to a new action is a row change, not
a framework change. Per-action expectation can be bypassed through the
per-project enabled/disabled policy. The pre/post conditions to check
become a pure function of `(decl, mechanism, provision)`.

## 4. The three LOGICAL roles — slots, not a classification of methods

The roles name the structure of checking itself — the artifact-relationship
axis the action graph already has (inspect steps / build steps / probe
steps). Every concrete method, present or future, is PLACED into a slot:

| Role          | Asks                                                      | Concrete things today                                              | Future things                                                                                                                                                |
| ------------- | --------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Surface**   | what does ONE artifact present at its boundary?           | nm/objinfo/dir/mli inspections (c1, c2, c4, c5)                    | the richer inspectors (L1b/L2/L4 — step 8)                                                                                                                   |
| **Meeting**   | are TWO artifacts compatible where they MEET (link/load)? | strict-flag compiles/links, the build_binding meeting (c6, c7, c8) | dry-run builds; the interposition shim as a RECORDER — which symbols the consumer actually requests at load (the oracle for "what the binding really needs") |
| **Execution** | what happens when the pair RUNS?                          | our probe apps, behavioral greps (c3)                              | decl-DERIVED programs (generated from the API invariant — beyond symbol-missing); the shim as a FAKE provider (consumer robustness); upstream test suites    |

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

## 7. Testing AHEAD of project running — fixtures ride with the rows

Each contract ships its MINIMAL COUNTEREXAMPLE — a `fixture`: synthetic
inspect inputs (file-name references + their JSON bodies) and the
failure substrings the row's `predict` MUST yield on them. The layer
tests (`contracts.fixtures_execute`) run every fixture hermetically —
no project run, the framework-test axis (same shape as the
compat-helper tests; the loaders read real files, so the test writes
the bodies and maps names to paths). Two consequences:

- a NEW contract lands WITH its fixture — the producer self-tests
  before any project consumes it;
- a changed predict breaks the pin — the belief cannot drift silently.

The completeness pin (`contracts.fixtures_complete`) states the covered
set visibly: C1, C2 today; C3/C7 are blocked in the registry; C4/C5/C6
pend their fixture JSON shapes (elf / versioned / typed loaders).

## 8. The general matrix

The belief space is NOT a free product of its axes — most of it is
DERIVED. The matrix that is actually general: **rows = contracts,
columns = ACTIONS**, because an action already determines its
artifacts (the action catalogue's consumes/produces). The mechanism
and provision axes do not add cells — they REFINE them: they decide
which actions exist in a scenario (chain shape × enumeration) and
what the input template yields. So:

```
  cell : (contract × action) → {
    status      : Wired | Declared_empty of reason | Blocked of deps
    inputs      : mechanism -> lang -> inspect_input list
    expect      : Inspection | Behavior_grep | Placeholder
    fixture     : the bad-world counterexample (predicted substrings)
    pass_means  : the good-world reading (blame axis, §9)
  }
```

**The derivation rules** (keep the matrix mostly derived):

1. contract → role (data): Surface / Meeting / Execution;
2. role → default action attachment:
   - Surface → the actions that carry the artifact's inspect
     attachments (build_lib, build_binding, probe_binding, probe_lib,
     fetch);
   - Meeting → the join actions (build_binding, build_app — and the
     load-time join at probe for dynamic mechanisms);
   - Execution → the run actions (probe_binding, probe_app);
3. mechanism × provision → which of those actions EXIST (the firing
   derivation projects the cells onto a scenario);
4. the input template → which surfaces the cell reads (per mechanism).

Explicit per-row entries override the role defaults (that is where the
hand-written tables' fine detail lands in phase 2 — every override
pinned equal to today's tables).

**The marks.** ✓ Wired (inputs + expectation + fixture defined);
○ Declared-empty (a reason: nothing to check here by design, or
Blocked on deps); ✗ Un-answered — the completeness pin FAILS on ✗ in
the declared scope. Today's coarse shape (the fine per-cell marks are
the phase-2 pin material, taken from the hand-written tables):

| contract (role)               | fetch            | configure | scan_sources | build_lib   | build_binding | build_app | publish               | probe_lib | probe_binding | probe_app      |
| ----------------------------- | ---------------- | --------- | ------------ | ----------- | ------------- | --------- | --------------------- | --------- | ------------- | -------------- |
| c1 symbol (Sf.3×Sf.2)         | ○                | ○         | ○            | ✓(lib half) | ✓             | ○         | ○                     | ○         | ✓             | ○              |
| c2 api-completeness (Sf.4)   | ○                | ○         | ○            | ○           | ✓             | ○         | ○                     | ○         | ✓             | ○              |
| c3 behavior (Trace)          | ○                | ○         | ○            | ○           | ○             | ○         | ○                     | ○         | ✓             | ✓(tiny oracle) |
| c4 soname (Sf.2×Sf.5)        | ○                | ○         | ○            | ✓           | ✓             | ○         | ○                     | ✓         | ✓             | ○              |
| c5 sym-version (Sf.2×Sf.5)   | ○                | ○         | ○            | ✓           | ✓             | ○         | ○                     | ○         | ✓             | ○              |
| c6 type (Sf.1×Sf.3)          | ○                | ○         | (inputs)     | ○           | ✓             | ○         | ○                     | ○         | ✓             | ○              |
| c7 repack (Sf.4)             | ○                | ○         | ○            | ○           | ○             | ○         | ○(publish lands here) | ○         | ✓             | ○              |
| c8 faithfulness (Sf.4, blocked) | ✗ blocked(c6,c7) | …         | …            | …           | …             | …         | …                     | …         | …             | …              |

Widenings already designed, not landed: a fetch-side integrity cell
(pinned-ref freshness is its postcondition half, e2b4d27), publish
verification cells (the other agent's work), probe_lib/app cells
beyond the oracle, and the mechanisms/langs beyond the wired three —
their cells answer `[]` = declared-empty, never un-answered.



## 9. Coverage status and plan

The GOAL: every cell of the belief space has a DEFINED result — the
pre/post-check and the expectation hold for good AND bad intended
results (each wired cell is a disprover with a named counterexample),
so completeness of checking is itself checkable. The space:

    contract (8) × action (12 kinds × langs × app wirings)
    × artifact-kind (5) × mechanism (5) × provision (4)

**Current status — what is defined where.**

1. **Per-action pre/post — TOTAL by construction.** `check_pre` (the
   automatic dep check) and `default_check_post` (the marker table,
   `marker_of_action` — one postcondition per action kind) cover every
   step. The warm-mask fix (e2b4d27) made them SPEC-AWARE: the marker
   v2 fingerprint (cmd + expectation form) means a spec edit
   self-invalidates — pre/post results can no longer silently serve a
   stale world.
2. **Contract firings — the wired subset only.** The registry defaults
   fire at `Build_binding l` / `Probe_binding l`. Declared but
   unwired: `Probe_lib` (no row fires there — c1's lib side rides
   inspect attachments on build_lib), `Build_app`/`Probe_app` (the
   firing vocabulary has the sites; no row uses them — tiny's oracle
   covers app firings today), `Scan_sources` (c6's inputs READ its
   JSONs, c6 fires elsewhere), and the fetch/configure/install/publish
   actions (publish belongs to the other agent's work; a fetch-side
   integrity contract is designed, not landed).
3. **Expectation forms — one Placeholder left.** 6 Inspection, 2
   Behavior_grep, 1 Placeholder (c8, blocked on c6+c7); the known
   gaps (c4-OCaml, symbol_orphan) close inside the registry.
4. **Mechanisms/langs beyond the wired three.** Cffi/Dynlink and the
   Rust/Java/Cpp/CSharp langs are declared in the vocabulary with no
   belief cells yet — the row functions must answer for them too
   (returning [] = declared-empty, distinct from un-answered).

**The plan — make incompleteness visible, then close it.**

1. **The matrix pin.** Extend the registry with a `cell_status` view:
   every (contract × action × lang) in a DECLARED SCOPE is `Wired` |
   `Declared_empty of reason` | `Blocked of deps` — a cell with no
   status fails the pin. The scope grows as beliefs land (start: the
   binding actions; widen to probe_lib + app sites; then fetch/publish
   as those projects land). This is the completeness meter the user
   reads.
2. **Per-cell counterexamples.** The fixture harness generalizes from
   per-contract to per-CELL (contract × firing action): each wired
   cell ships the minimal bad-world input + its predicted substrings;
   the good-world result is the cell's pass meaning (blame axis, §7).
   A cell is "complete" only when both hold.
3. **Per-action belief statements.** The marker table gives every
   action a postcondition; the belief side adds its one-line MEANING +
   blame (what does `build.ok` pass/fail say about which artifact —
   e.g. the pinned-ref freshness check_post the other agent added is a
   fetch-side postcondition with a clear fail meaning).
4. **Order.** (a) matrix pin with the visible not-yet list → (b) fill
   probe_lib + app cells (tiny's oracle is the reference) → (c)
   fetch/publish cells as their projects land → (d) the new
   mechanisms/langs as their bindings land.

**Warm-mask ↔ phase 2.** The marker v2 fingerprint covers the step's
cmd + EXPECTATION FORM — so when phase 2 switches the lowering to
registry-derived firings, any expectation drift self-invalidates at
the RUN level (the byte-equal pin becomes runtime-enforced, not just
test-enforced). Phase-2 pins should pin the expectation form too, not
only the cmd strings.

## 10. The blame axis (open — think during the gathering)

For every checking action — any role, any artifact — what does a
correct result mean, what does an incorrect result mean, and WHO is
blamed? Not answered here completely; the frame to carry through the
gathering:

- **Pass meanings differ per role.** Surface pass: this artifact's
  presented facts cover the watchlist — it says NOTHING about the
  other side (single-artifact evidence). Meeting pass: this pair
  joined under the conditions exercised — a fact about the RELATION,
  not about either artifact alone. Execution pass: this run behaved —
  bounded by the run's coverage. Each is a bounded falsifier, never
  proof (§5).
- **Failure blame is role-shaped.** Surface failure blames the
  artifact itself (presented ≠ declared). Meeting/Execution failures
  are direction-ambiguous at the check level — the framework's
  `mismatch_direction` (Forward/Backward, already computed per
  scenario) resolves it: forward → the consumer asked too much
  (binding/app at fault); backward → the provider regressed (lib at
  fault).
- **Instrumented meetings shift blame.** The fake-provider shim
  inverts the question: the provider is a plant, so failure blames
  the consumer's robustness — or the DECL the plant embodies. The
  recorder shim blames nobody: it observes the actual request set.
- **Open questions.** Does each row need a blame column (per-role
  pass/fail semantics + the direction mapping), or does blame derive
  uniformly from (role × direction)? Can a Surface failure ever be
  direction-resolved (the artifact IS the provider in a Backward
  world)? Answer during the phase-2 consumer migration, where the
  hand-written tables show which blame distinctions actually matter.

## 11. Sequence (each step keeps the suite green)

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
