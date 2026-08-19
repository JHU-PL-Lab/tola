# Contract registry — the belief module

> 2026-08-17, refreshed 2026-08-18. M2 step 6 (producer-first; consumers
> migrate in phase 2, currently HELD). One statement per contract: WHAT
> the invariant is, HOW we check it (tool-based), WHERE it fires
> (derived from mechanism × lang × provision). The expectations are
> entirely OUR machinery — unlike build commands, nothing external has
> to be respected; a hand-written per-project table is our own data and
> gets deleted once the derived firings pin equal.
>
> **Why the registry exists, in one line**: today "what canary checks"
> is knowable only by reading five scattered places — the registry makes
> the belief PRINTABLE, and printing it shows the holes (§8's matrix,
> §8a's first fills, §9's fill list).

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
  | Inspection      (* inspect JSONs → predict → compat-derived expectation *)
  | Behavior_grep   (* the run's log substring → failure expectation *)
  | Postcondition   (* the action's check_post family: markers, pin-checks,
                       staged-parity at Install_lib, freshness *)
  | Placeholder     (* Expect_success until wired (missing-ness visible) *)

type contract_row = {
  row_check   : Canary_compat.contract_check;
      (* id, name, layer, status, enabled, predict — already exists *)
  invariant   : string;
      (* the one-sentence agreement, phrased as a FALSIFIER (§5); the
         reconciliation point for ssot's Ag.X ↔ C1..C8 drift decision *)
  role        : role;
      (* PROSE tag at most (Surface/Meeting/Execution — the legacy
         evidence vocabulary). Not a typed axis: the action column
         already implies the cell's subject (one artifact vs a pair)
         and its evidence flavor. *)
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
      (* HOW the expectation comes to be — the expectation half of
         the belief, stated per row; the ONE typed axis that survives
         (§8): inspect JSONs → predict (Inspection), grep the run's
         log (Behavior_grep), the action's check_post family
         (Postcondition — staged-parity at Install_lib, pin-checks,
         freshness), or not wired yet (Placeholder). *)
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
- **Installed** (2026-08-18): groups WITH Built — its chain includes the
  real build plus the staging step, so the build-family contracts fire;
  what differs is which concrete artifact the consumer reads (the
  staged prefix). The staging step's own checks are the
  `Install_lib × Postcondition` family (staged parity — see
  [`staged_parity.md`](staged_parity.md)).
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

## 4. The legacy roles — prose, not typed axes (demoted 2026-08-18)

The roles were our first attempt to name the structure of checking. They
remain a useful DESCRIPTION — but not a typed axis: the action already
implies a cell's subject (one artifact vs a pair) and its evidence
flavor, so nothing decides on them (§8's "one typed axis"). The table
below is kept because it still places concrete methods, present and
future, in an intuitive way:

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
failure substrings a `predict` MUST yield on them. A fixture may carry
its OWN closure (`fx_predict`) instead of the row's — that is how a
per-CELL predict is tested (the lib-only cells' decl-comparison
closures, §8a); `None` means "the row's `cr_check.predict`". The layer
tests (`contracts.fixtures_execute`) run every fixture hermetically —
no project run, the framework-test axis (same shape as the
compat-helper tests; the loaders read real files, so the test writes
the bodies and maps names to paths). Two consequences:

- a NEW contract lands WITH its fixture — the producer self-tests
  before any project consumes it;
- a changed predict breaks the pin — the belief cannot drift silently.

The completeness pin (`contracts.fixtures_complete`) states the covered
set visibly: **C1, C2 + C4/C5's lib-only cells** (2026-08-18). C3/C7
are disabled in the registry (`Blocked []` / `Stubbed`); C6 pends its
typed-loader fixture; C4/C5's PAIR cells pend theirs (only their
lib-only halves are covered).

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
    source      : Inspection | Behavior_grep | Postcondition | Placeholder
    fixture     : the bad-world counterexample (predicted substrings)
    pass_means  : the good-world reading (blame axis, §10)
  }
```

**One typed axis.** The ACTION implies the cell's subject (one artifact
at a lifecycle action vs a pair at a meeting — its consumes/produces
say which artifacts) and its evidence flavor (read / join / run). The
only typed axis that survives is the expectation MECHANICS (`source`):
how the expectation is produced — inspect JSONs → predict
(Inspection), grep the run's log (Behavior_grep), the action's
check_post family (Postcondition — where staged-parity at Install_lib,
pin-checks, and freshness live), or not wired yet (Placeholder).
The legacy roles stay prose (§4).

**The derivation rules** (what the code actually does — the roles are
NOT part of it; they were demoted to prose, §4):

1. each row names a FIRING FUNCTION — `mechanism × lang × provision →
   action list`. Three exist today:
   - `firing_default` — Static ⇒ `[Build_binding l; Probe_binding l]`
     in Built/Installed worlds, `[Probe_binding l]` where nothing is
     built; Dynamic ⇒ `[Probe_binding l]` (no compile stage);
   - `firing_with_build_lib` — the same PLUS `Build_lib` in Built
     worlds: the row also has a lib-only cell (§8a);
   - `firing_probe_only` — a run is required, so probe only, in every
     world.
2. the input template (`inputs_of_contract ?mechanism`) says which
   surfaces the cell reads — the mechanism refinement lives there
   (a dynamic binding has no stub to inspect).
3. everything else about a cell (its subject, its evidence flavor) is
   implied by the ACTION, not stored.

A new firing shape is a new small function, not a framework change;
phase 2's per-project overrides land as row-level firing functions,
each pinned equal to today's hand-written tables.

**The marks — and why there is no "un-answered".** The matrix is TOTAL
by construction: the firing function answers for every action, so
every cell has a status. (An earlier draft posited an `✗ Un-answered`
mark; it cannot occur — dropped 2026-08-18.)

| mark | status | meaning |
|---|---|---|
| `✓` | `Wired` | fires here AND ships a counterexample fixture |
| `~` | `Declared` | fires here, predict exists, NO fixture yet — **the fill list** |
| `⊘` | `Blocked` | the contract itself is disabled/blocked on deps |
| `·` | `Empty` | does not fire here — the firing derivation says so; a principled absence, not an omission |

**"Filling the matrix" therefore has a bounded, concrete meaning**:
turn `~` into `✓` — attach a counterexample to a cell that already
fires. The job is finite and enumerable (`fill_list` returns exactly
the `~` cells), not open-ended.

Today's shape under the reference world (Cstubs × OCaml × Built),
read off the firing functions:

| contract | fetch_src | conf | scan | hdrs | fetch_lib | **build_lib** | install | fetch_bind | **build_bind** | pack | probe_lib | **probe_bind** | build_app | probe_app |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| c1 symbol (Sf.3×Sf.2) | · | · | · | · | · | ✓ | · | · | ✓ | · | · | ✓ | · | · |
| c2 api-completeness (Sf.4) | · | · | · | · | · | · | · | · | ✓ | · | · | ✓ | · | · |
| c3 behavior (Trace) | · | · | · | · | · | · | · | · | · | · | · | ⊘ | · | · |
| c4 soname (Sf.2×Sf.5) | · | · | · | · | · | ✓ | · | · | ✓ | · | · | ✓ | · | · |
| c5 sym-version (Sf.2×Sf.5) | · | · | · | · | · | ✓ | · | · | ✓ | · | · | ✓ | · | · |
| c6 type (Sf.1×Sf.3) | · | · | (reads) | · | · | · | · | · | ~ | · | · | ~ | · | · |
| c7 repack (Sf.4) | · | · | · | · | · | · | · | · | · | · | · | ⊘ | · | · |
| c8 faithfulness (Sf.4) | · | · | · | · | · | · | · | · | ⊘ | · | · | ⊘ | · | · |

Reading it: the ✓ cells are the belief that is both stated AND
falsifier-tested; `~` (c6) is the whole current fill list; the `·`
majority is the honest picture — most of the action space carries no
contract yet, and the widenings below name which of those we intend
to populate. The `install_lib` column is where the staged-parity
family lands (`Postcondition` source, not a contract predict).

**Two doc↔code drifts this table exposed** (fix in the code, not by
re-wording):

1. `Stubbed` has no distinct mark — `cell_status_of` maps everything
   that is not `Blocked` to Wired/Declared, so c7/c8 currently render
   as `~` (a fill candidate) when in truth their predicts return `[]`
   by construction. `Stubbed` deserves its own status.
2. c8's registered status is `Stubbed`, while this design and
   `scenario.md` both say it is blocked on c6+c7. Reconcile to
   `Blocked [C6; C7]` so the dependency is data, not prose.

Widenings already designed, not landed: a fetch-side integrity cell
(pinned-ref freshness is its postcondition half, e2b4d27), publish
verification cells (the other agent's work), probe_lib/app cells
beyond the oracle, and the mechanisms/langs beyond the wired three —
their cells answer `[]` = declared-empty, never un-answered.



## 8a. The lib-only cells — the first fills (2026-08-18)

Three cells landed as the first deliberate fill, all on the ONE
artifact (the binary C lib) at `Build_lib`, all sharing one shape:

| cell | falsifier | evidence |
|---|---|---|
| c1 @ build_lib | a declared `c_api` function is missing from the built lib's exports | nm symbols vs the decl |
| c4 @ build_lib | the built lib's elf soname ≠ the declared soname | elf vs the decl |
| c5 @ build_lib | a declared version tag is absent from `versioned_exports` | `@@VER` vs the decl |

Their closures (`c1_decl_predict`, `c4_decl_predict`,
`c5_decl_predict` in `canary_compat_run.ml`) are **decl-comparison**
predicts: they read ONE artifact's inspected surface and compare it
against the project's DECLARED facts (`binding_decl`), with no
consumer involved.

**Why this shape is the general one** (user, 2026-08-18): the language
tools — compilers, linkers, version scripts, install rules — are
BLACK BOXES with no bit-wise operational semantics we can reason
about. A linker may silently drop a version script; a build system may
not re-run; an install may skip a rule. So we do not trust the tool's
exit code beyond its marker postcondition: we inspect the ARTIFACT it
produced and compare against what was declared. Every lifecycle cell
(make / transform / exercise) is an instance of that stance, which is
why `staged_parity.md`'s install checks and these build checks have
the same skeleton — different artifact stage, same "inspect the
product, compare to the declaration".

An observation the fill produced: **c1's lib-only cell is the same
comparison as the status-level watchlist verdict** (`watchlist N/N` /
`⚠ MISSING`). Two views of one belief — one recorded post-hoc in the
status table, one predicted as a cell. The registry is where they
reconcile.

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
2. **Contract firings — the wired subset.** The registry defaults fire
   at `Build_binding l` / `Probe_binding l`, PLUS `Build_lib` for the
   three lib-only cells (§8a). Declared but unwired: `Probe_lib` (no row fires there — c1's lib side rides
   inspect attachments on build_lib), `Build_app`/`Probe_app` (the
   firing vocabulary has the sites; no row uses them — tiny's oracle
   covers app firings today), `Scan_sources` (c6's inputs READ its
   JSONs, c6 fires elsewhere), and the fetch/configure/install/publish
   actions (publish belongs to the other agent's work; a fetch-side
   integrity contract is designed, not landed).
3. **Expectation forms.** 5 Inspection, 2 Behavior_grep, 1
   Placeholder (c8) + the `Postcondition` form reserved for the
   check_post families (markers, pin-checks, staged parity). The known
   gaps (c4-OCaml's Placeholder firing, `symbol_orphan`'s
   contract-less build failure) close inside the registry; c8's
   registered status needs the `Blocked [C6; C7]` reconciliation
   (§8's drift 2).
4. **Mechanisms/langs beyond the wired three.** Cffi/Dynlink and the
   Rust/Java/Cpp/CSharp langs are declared in the vocabulary with no
   belief cells yet — the row functions must answer for them too
   (returning [] = declared-empty, distinct from un-answered).

**The plan — make incompleteness visible, then close it.**

1. **The matrix view** — `belief_matrix` / `fill_list` /
   `pp_belief_matrix` (written 2026-08-18): the cells as data, the
   `~` set as an explicit fill list, and a rendered table. The matrix
   is total, so the pin is not "no un-answered cell" (impossible) but
   the fill-list SHAPE: the pin states today's `~` set exactly, so a
   new unfixtured cell shows up as a diff. Two code refinements the
   table exposed are listed in §8.
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
4. **Order.** (a) the matrix view + its fill-list pin → (b) fill
   probe_lib + app cells (tiny's oracle is the reference) → (c)
   fetch/publish cells as their projects land → (d) the new
   mechanisms/langs as their bindings land.

**Decided and deferred** (2026-08-18, user):

- **The C smoke probe** (`Probe_lib` Execution cell — compile a
  minimal program against the lib, load it, enter each declared
  function once). VERDICT: worth it, because it is the only check
  that exercises the LOADER — the lib's own undefined closure, broken
  NEEDED/RPATH, constructor (`.init_array`) failures, load-time
  version resolution. That class is structurally invisible to nm/elf
  tools: a lib can be perfectly formed and still fail to load. The
  program is decl-DERIVED (`c_api.functions`), so it carries no
  hand-written payload. Deeper behavior stays with the App actions.
  POSTPONED — it needs action-layer probe machinery.
- **Where an expectation is declared** (user, 2026-08-18): an
  expectation is project-AGNOSTIC whenever artifact/action/mechanism
  determine it (those live in the registry); when it is genuinely
  project-dependent it belongs in the STATIC project spec as a
  declared field — never hidden inside a realization closure. The
  smoke probe's expected-output patterns are the first case of the
  latter.
- **Checks as actions** (`[Pre; Action; Post]`, recorded in
  `status.md` design directions): would make every matrix cell an
  action in the enumeration, and the coverage pin an enumeration
  invariant. POSTPONED — the IR layer is uniform enough to wait.
- **Staged parity** (`Install_lib × Postcondition`) is the same
  belief family one artifact-stage later; it lives with the other
  agent's brief (`staged_parity.md`) and needs no new vocabulary
  here. Its portability falsifier — a staged binary must contain no
  build-tree path — is the transform-stage analogue of §8a's
  decl-comparison.

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

1. [x] **Land the producer** (2026-08-17/18): `contract_registry` rows
   for c1..c8 (invariant, reads, source, fault tags, input template,
   firing derivation) + the fixture harness + the first fills (§8a) +
   the matrix view (§8). Consumers untouched — `registered_checks` and
   the per-project tables keep working; 4 pins green. Still open
   inside this step: the ssot Ag.X ↔ C1..C8 reconciliation (the Ag.8
   decision) and §8's two drifts.
2. Switch `lower_expectation_agnostic` to derive firings from the
   registry; pin the derived firings equal to the hand-written tables
   (tiny first — richest case — then z3/llvm/sqlite).
3. Delete the per-project `*_contract_bindings`; the tiny oracle
   combinator (`expectation_of_entry`) consumes the registry.
4. Close the gaps inside the registry: c4/OCaml's Placeholder
   prediction, `symbol_orphan`'s build failure (a new id), statuses
   → all Wired.
5. Fault-tag sync (step 9) lands as `fault_tags` on the rows.
