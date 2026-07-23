# The `project` definition — detection-first, forecast-agnostic

> **Status: design draft (2026-07-22).** Captures the direction agreed
> in discussion; not yet implemented. Supersedes the minimal
> `Canary_project.project = { name; contract_bindings }` recorded in
> `worklog_2026_07.md` (2026-07-21, "Task 2 Step 1 refinement").
> Condenses into `ssot.md` §6.1 once settled.

Companion to [`new_project.md`](new_project.md) (§3 auto-generation plan,
which this subsumes) and [`ssot.md`](ssot.md) §6.1 (operational taxonomy),
§3 (the c1..c8 contracts), §6.5 (action catalogue).

---

## 1. Problem

Two problems with the current shape:

1. **`project` is inert and under-determined.** `Canary_project.project`
   is `{ name; contract_bindings }`, has a single inhabitant
   (`tiny_project`), and no consumer — `canary_main.ml` walks
   `all_scenario_specs` directly. It was deliberately settled from N=1
   (tiny only), which is exactly why it's under-determined.

2. **Forecast and detection are conflated.** The runner-facing
   `Canary_step_builder.runner_spec` (the old `project_spec`) carries
   `expectation : action -> location option -> step_expectation`. That
   field is a **hand-authored forecast**: for tiny it comes from a
   scenario's `violates` list + `tiny_contract_bindings`; for z3/llvm it
   names a specific known drift (`parser_context`, `Opcode.UncondBr`).
   A **real-world project may not have the intended contract violations**
   — you can't forecast what will break before you run the probes. You
   need to **detect** drift, not declare it up front.

The fix: make the `project` **detection-first and forecast-agnostic**,
and move the forecast (the "this should break here" oracle) out to tiny,
where it belongs as a **regression check on canary itself**.

---

## 2. The core separation — two verdicts

Today `runner_spec.expectation` + the local runner fuse two distinct
things. Separate them:

| | **Detection result** (universal) | **Oracle check** (tiny only) |
|---|---|---|
| What | probe outcome + which contracts fired + what they found | does the detection result match manufactured ground truth? |
| Source | derived from actions / `api_source` at run time | hand-authored `violates` / `expected` |
| Who has it | every project | tiny (the "project-for-scenario" regression fixture) |

- **Detection** is already discovery-based: the `predict` closures
  (`c1_predict` etc.) compute *what* broke at run time (e.g. `c1` does a
  set-diff `stub_requires ∖ lib_defines`). They don't need the answer up
  front — only *which artifacts to look at*. Today the flow gates them
  behind the hand-authored `violates`; forecast-agnostic detection
  removes that gate and runs the in-scope contracts unconditionally.
- **The oracle** (`violates` + `expected`) is tiny's business: tiny
  *manufactures* a break (e.g. `patch "symbol_missing"` renames
  `tiny_sum → tiny_total` in C only) and then asserts canary's detection
  reproduces the expected verdict. This is "checking the checking
  result." No real project carries it.

---

## 3. Target shape (strawman)

The new `project` **replaces the old `project_spec`** and owns canary's
multi-store artifact model (`Build_tree` = src, `Staged` = lib, `Pm` =
package). Forecast-free:

```ocaml
(* NAME PLACEHOLDER: "project" here is the per-variant/scenario runnable
   spec (it replaces runner_spec). The top bundle {name; variants} needs
   a different name — settled during step-2 drafting (2026-07-22). *)
type project = {
  name        : string;
  surface     : surface;         (* checking points — see §3.3; ex-`api_source`, split *)
  stores      : store_config;    (* provenance: where source/headers/lib/binding-source live *)
  steps       : step_source list;(* Derived | Raw — see §3.1 *)
  contracts_in_scope : contract_id list;    (* which detectors run; default = all enabled *)
  (* NO expectation, NO violates, NO contract_bindings *)
}
```

The `actions` are recovered from `steps`; each step's action drives the
consumes/produces relation (§ shipped: `Canary_action.consumes_of_action`)
that yields the artifact inventory. Detection facilities are **derived**,
not declared: the enabled in-scope contracts run their `predict` over the
observed artifacts at each probe step; whatever fires is reported.

**Prerequisite — shipped (step 1, 2026-07-22).** The consumes/produces
split now lives in `Canary_action.consumes_of_action` /
`produces_of_action` / `consumed_artifacts_of_actions`, with the
`canary project-test` layer-test axis. Detection pulls its inputs from
`consumes_of_action` at probe sites (invariant: probes produce nothing,
so `consumes = artifacts` there).

**Transport — reuse everything (resolved).** The detection report is
**not** a new file or schema. It rides the existing transport:
`actions.log` (one event per finding, alongside today's
`compat_predicted` / `done` / `failed` rows) and `run_state.json`. The
**step model, action graph, and cross-run cache stay identical** at the
start — the redesign changes *what drives* the verdict (derived
detection vs hand-authored forecast), not the plumbing that carries it.
Keeping the transport fixed also keeps the regression suite comparable
across the migration.

### 3.1 Steps — declarative by default, closure escape hatch

Pure-derive is fragile: real projects have bespoke commands (z3's cmake
build, `LIBTORCH` env, brew keg paths). So a step is either derived from
declarative store config *or* a raw escape hatch. Closures are "working
but dirty" — keep them where needed, don't force everything through
them.

```ocaml
type step_source =
  | Derived of store_slot          (* generated from store_config + locator — the clean path *)
  | Raw of (output_dir:string -> variant_key:string -> string)  (* escape hatch for tricky commands *)
```

The declarative half is exactly `new_project.md` §3's auto-generation
plan (`package_locator` #29, `store_config` #30,
`mk_script_spec_from_sketch` #32). This redesign delivers it as a side
effect rather than a separate task.

**Compatibility + factory (resolved 2026-07-22).** The type is a strict
superset of the old `runner_spec`: `old runner_spec ≈ new project with
all-`Raw` steps, empty surface, empty contracts`. Three producers, no
tension:

- **Derivable** — `Derived` steps from `store_config` (sqlite, Pattern A).
- **Compatible** — `Raw` *is* the old closure
  (`output_dir:… -> variant_key:… -> string`) verbatim; migrating
  z3/llvm is mechanical field-shuffling (each `fetch_lib`/`probe_binding`/
  `inspect` closure → one `Raw` step), not a rewrite.
- **Factory-generatable** — tiny's factory emits a `project` per scenario
  instead of a `runner_spec`, and gets *simpler*: forecast-agnostic means
  it **drops `expectation_of_entry`** entirely (the oracle moves to the
  sidecar, §4). It fills `Raw` steps from `make_base_runner_spec` + the
  per-scenario `surface`.

### 3.2 Fail mode — per-contract reaction (resolved)

Green/red is **not baked in**; it's a policy over the detection report,
configurable like `--disable-contract`. The unit of configuration is
**per-contract** — a general contract/expectation setting that says how
a firing reacts:

```ocaml
type reaction = Log | Print | Raise   (* Raise = OCaml exception → fail the run *)
```

- `Log` / `Print` — warn-only; the finding is recorded/surfaced but the
  run stays green.
- `Raise` — fail the run (an OCaml exception, caught at the runner
  boundary and turned into a red step/verdict).

Findings still carry a natural **severity** that sets the *default*
reaction:

- **Hard** — compile / link error / probe crash: the artifact genuinely
  does not work. Default `Raise`.
- **Soft** — a contract fired (API / symbol / type drift) but the probe
  still built and ran. Default `Log`/`Print`.

Run-level presets are just bulk settings over the per-contract table:

| Preset | Hard | Soft |
|---|---|---|
| `tolerate` (warn-only) | `Print` | `Log` |
| **`default`** | **`Raise`** | **`Print`** |
| `fail_fast` / `strict` | `Raise` | `Raise` |

A positive-only project (sqlite) is green when its positive probes
build/run; any drift the contracts happen to detect is logged/printed —
it doesn't fail the session unless a contract is set to `Raise` or a
probe hard-errors.

### 3.3 Surface — the checking points (ex-`api_source`, split)

`api_source` (a `Canary_artifact_api.t` in `base/`) was a bad name and a
conflation. It fused two concerns; split them along the seam:

- **Provenance / structure → `store_config`.** `native_api.components`,
  `native_api.headers` (`dir`/`files`), and `binding_api.source_dir` say
  *where* the source / headers / binding source code live and *what*
  components exist. A **store** owns that. `source_repo` (`tool/`, which
  currently embeds `api_source`) is the provenance carrier and stays on
  the store side.
- **Checking points → `surface`.** The watchlists and expected
  properties — `stable_symbols`, `symbol_prefixes`, `versioned_symbols`,
  `soname`, `c_runtime`, `cxx_abi` (native) and `module_watchlist`,
  `type_watchlist` (per binding) — are what detection inspects. This is
  the renamed field on `project` (name chosen 2026-07-22: **`surface`**,
  faithful to the s1..s8 surface theory these declarations instantiate).

```ocaml
type surface = {
  native   : native_surface;                (* stable_symbols, prefixes, soname, abi … *)
  bindings : (lang * binding_surface) list;  (* module_watchlist, type_watchlist per lang *)
}
```

Layering note (corrects §7): the checking type is in **`base/`**, so
`project` in `action/` referencing it is a normal upward dep — the
"downward dependency" worry was about `source_repo` (`tool/`), which is
exactly the provenance half moving to the store. The concern dissolves.

---

## 4. tiny — the regression sidecar

tiny keeps the oracle, split *out* of the `project` type:

```ocaml
(* per scenario, owned by tiny's harness — NOT on `project` *)
type oracle = {
  violates : contract_id list;
  expected : (string * outcome) list;
}
```

tiny's `project` is forecast-free like everyone else. Its harness reads
the sidecar and asserts `detection_report ≡ oracle` for each scenario.
tiny's `mutation` (world-building) stays; only the forecast/oracle moves
out of the shared type.

---

## 5. Scenarios / variants (Model A, unchanged)

Each project's module still owns its runnable units (tiny:
`all_scenario_specs`; z3/llvm: variants from `mk_runner_spec ~source`).
`scenario ≡ variant` at the middle taxonomy level (confirmed 2026-07-21).
The `project` bundle does **not** carry a `scenarios`/`variants` field —
that stays module-owned per the concrete-over-polymorphic preference.
The bundle earns its keep as the **detection scope** (stores + surface
+ contracts_in_scope), not a failure-location table.

---

## 6. Migration / ordering — gradual in-place seam plan

**Strategy (decided 2026-07-22): gradual in-place evolution of
`runner_spec`**, one seam per commit, green at every step — rather than
a parallel type swapped in at the end. The backends consume the derived
`step list`, not `runner_spec`, so the transport stays fixed; only *how a
runner is authored* and *how `derive_steps` computes the verdict* change.
Two decisions folded in: **the `derive`/compact-`project` wrapper is
postponed** (S6) — we evolve the runner through S5 first; and
**`store_config` is a record** with a named field per artifact's store
(not an assoc), matching the original "field for each artifact's store"
rationale. **Each seam ships its layer test** (§8).

Prerequisite (shipped, was "step 1"): `Canary_action.consumes_of_action`
/ `produces_of_action` / `consumed_artifacts_of_actions` + the
`project-test` axis (`08807a4`).

| # | Seam | Status |
|---|---|---|
| **S1** | `surface` type in `base/` (`Canary_surface`); route `derive_steps` watchlist reads through it (computed from `api_source`). *Test: `surface_of_api` split.* | ✅ `9186b99` |
| **S2** | `step_source = Derived \| Raw` in `step_builder`; wrap every command closure as `Raw` (type-only, behavior-preserving). | pending |
| **S3** | `store_config` **record** (field per `artifact_kind`) in `tool/`; wire `Derived` slots; move provenance reads (`source_dir`, `headers`) off `api_source`. *Test: golden-string a `Derived` step.* | pending |
| **S4** | remove `api_source` (now `surface` + `store_config`). | pending |
| **S5a** | detection runs **in parallel**, logs findings; `expectation` still decides — diff detection vs. forecast on tiny's known cases. | pending |
| **S5b** | detection **drives** the verdict; remove `expectation`; tiny oracle → sidecar (§4); `disabled_contracts` → per-contract `reaction` table (§3.2). *Test: oracle-check over a mismatched fixture.* | pending |
| **S6** (postponed) | rename `runner_spec` → `runner`; add compact `project` + `derive : project -> variant -> runner`. Variants stay explicit/selectable. | deferred |

S1–S4 and S6 are mechanical and independently green; **S5a/S5b are the
only semantic risk** — S5a's parallel-run is the safety net (prove
detection reproduces every tiny oracle result *before* flipping in S5b).

The strawman `canary_project_def` **dissolves** as seams land: its
`surface`→`base/` (done S1), `store_config`→`tool/` (S3),
`step_source`→`step_builder` (S2); the file is deleted once empty.

Then: **ssot §6.1** — condense this note into the taxonomy section.

---

## 7. Open questions — resolved (2026-07-22)

- **Report schema → reuse existing transport.** No new report format.
  Findings ride `actions.log` (one event each) and `run_state.json`; the
  step model, action graph, and cache stay identical initially. See §3
  "Transport". *Deferred:* a richer per-finding row (contract id +
  severity + store + action) can grow later without changing the file.
- **Per-contract severity → per-contract reaction.** Resolved as a
  general contract/expectation setting `reaction = Log | Print | Raise`.
  See §3.2. Hard/soft severity sets the default; presets bulk-configure.
- **Escape-hatch boundary → stays at the action/step layer.** Both
  `Derived` and `Raw` step forms are acceptable there; no boundary forced
  now. A cleaner split earns its keep once more projects land (the
  `new_project.md` §3 auto-gen threshold, ~10 projects).
- **`api_source` → split + renamed `surface` (resolved 2026-07-22).**
  The field conflated store-provenance with checking-points. Split:
  provenance (`components`, `headers`, `source_dir`) → `store_config`;
  checking-points (watchlists + expected symbols/soname/abi) → the new
  `surface` field. See §3.3. The layering worry was a mislabel —
  `Canary_artifact_api` is in `base/` (not `tool/`), so no downward
  dependency; the `tool/` part was `source_repo`, which is the
  provenance half that moves to the store.

---

## 8. Testability — layer tests (a first-class goal)

Today canary has two testing axes (`CLAUDE.md` "Two testing axes"):
**project tests** (`canary action <project>` — full run, installs
packages, builds) and **framework tests** (`canary artifact-test` /
`pm-test` — tool assumptions). Both the slow axis (project) and the
tool-drift axis are covered; what's missing is a **fast, hermetic axis
for the project *definition* itself** — so a layer can be tested without
running the whole project.

The redesign makes this axis natural, because detection is a chain of
**pure** transformations between two shell boundaries:

```
[shell: fetch / build / probe]            ← the ONLY impure part
        │  emits
        ▼
   inspect JSONs   ← cut here: commit these as fixtures
        │
        ▼  PURE from here down
  action→artifact inventory
        │
        ▼
  contract predict over artifacts  →  findings
        │
        ▼
  fail-mode policy (per-contract reaction)  →  verdict
        │
        ▼  (tiny only)
  oracle check: detection_report ≡ expected
```

Cut at the **inspect-JSON boundary** and everything downstream is a pure
function of committed fixtures. No opam, no apt, no build.

### 8.1 The pure layers, each independently testable

| Layer | Input (fixture) | Assert |
|---|---|---|
| **action → artifact** | an `action list` | derived artifact inventory (stores × kinds) |
| **step derivation** | `store_config` + locator | golden `Derived` command strings |
| **detection** | committed inspect-JSON pair (mismatched) | the findings each in-scope contract produces |
| **fail-mode policy** | findings + per-contract `reaction` table | the run verdict (green / warn / raise) |
| **oracle check** (tiny) | detection report + `oracle` | pass/fail of the regression assertion |

The **detection** layer already has a seed: `canary_artifact_test.ml`
runs `predicted_contains_any_v2` against synthetic `Ocaml_mli` /
`Python_attrs` fixtures (the compat-helper pure tests). This extends that
pattern up the whole chain.

### 8.2 Fixtures — committed inspect JSONs

Layer tests need a small committed corpus of inspect outputs: at least
one **matched** pair (green) and one **mismatched** pair (fires a
contract) per contract in scope. This is the same artefact the deferred
`summary-sync` / committed-cache idea wants
(`CLAUDE.md` "Step 3 deferred — `doc/canary/artifact_inspect.json`"), so
layer-testing and the committed cache land together: the cache *is* the
fixture corpus.

### 8.3 Where it runs

Either extend `canary artifact-test` with a `project-definition` group,
or add a `canary project-test` subcommand. Pure + fast → runs in CI on
every commit, unlike the project runs (which need PMs and are gated).
Resolves the standing **TODO #15b** ("Unit-test framework for
compat/inspect logic") for the definition layers.

### 8.4 Why the old design couldn't do this

The forecast model fused the answer into hand-authored `expectation`
data, so "testing the definition" meant re-running the project to see if
the forecast matched reality. Detection-first inverts it: the definition
is pure data + pure derivation, and the only thing that needs a real run
is refreshing the fixtures — occasionally, not per test.
