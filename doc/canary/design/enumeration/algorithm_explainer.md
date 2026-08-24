# How Canary Works

**Stage:** see [README.md](README.md) (the stage map). **Kind: rationale.** How the pipeline works today, end to end. Every stage described here exists in the code.

> 2026-08-08; updated 2026-08-16 (repo-model C2: per-repo source pins,
> channel-level coupling, the 5-scenario 3-way). Walks through the full
> pipeline — declaration to execution — using z3 as the concrete example.

## 1. The pipeline at a glance

```
                    ┌──────────────────────────┐
                    │   action catalogue        │  universal, pre-computed once
                    │   (typed action sigs)     │
                    └──────────┬───────────────┘
                               │ backward walk from probes
                               ▼
                    ┌──────────────────────────┐
                    │   universal chain table   │  all possible ordered action
                    │   (Fetch → Build → Probe) │  chains ending at a terminal
                    └──────────┬───────────────┘
                               │ filter: can the project realize this chain?
                               ▼
  project declaration  →  applicable chains  →  assignments  →  derive_steps  →  execute
  (provision × ver)       (ordered action      (version         (concrete       (graph
                           list per scenario)   coordinates)     step list)      saturation)
```

A **chain** is the scenario — the ordered action list:
  `Fetch Source → Build Lib → Build Binding → Probe Binding`

An **assignment** is the version coordinates within that chain:
  `{source@Dev, lib@Built@Dev, binding@Built@Dev}`

Chains are pre-computed from the action catalogue (11 actions, 3 terminals
→ a handful of chain shapes). A chain is applicable to a project if the
project declares the right provisions for every action in the chain
(Fetched for Fetch actions, Built for Build actions). Version enumeration
within each applicable chain produces the concrete assignments.

## 2. The action catalogue — what actions exist

Every action is a typed function from inputs to output:

```ocaml
type action_sig = {
  action    : Canary_basic.action;
  consumes  : artifact list;   (* inputs *)
  produces  : artifact;        (* output *)
  version   : Ambient | Follows_input;
}
```

The catalogue (excerpt):

| Action                  | Consumes               | Produces        | Version rule                             |
| ----------------------- | ---------------------- | --------------- | ---------------------------------------- |
| `Fetch Source`          | —                      | `Source`        | Ambient (version from project spec)      |
| `Fetch Lib`             | —                      | `Lib`           | Ambient                                  |
| `Build_lib`             | `[Source]`             | `Lib`           | Follows_input (version = source version) |
| `Fetch (Binding OCaml)` | —                      | `Binding OCaml` | Ambient                                  |
| `Build_binding OCaml`   | `[Lib]`                | `Binding OCaml` | Follows_input (version = lib version)    |
| `Probe_binding OCaml`   | `[Lib; Binding OCaml]` | (terminal)      | —                                        |

The version rule encodes propagation: `Build_lib` takes a `Source` as input,
so its output version IS the source's version (source-primary). `Build_binding`
takes a `Lib`, so its output version IS the lib's version (follows).

`ax_follows` is declared on the artifact (in `artifact_axes`) — it tells the
version engine that binding version must match lib version. `build_deps_of`
is hardcoded (lib → source). Both will be derived from the action catalogue
when the catalogue becomes the single source of truth for consume/produce
relationships.

## 3. What the project declares

> The full account of stage 1 is
> [`stage1_project_spec.md`](stage1_project_spec.md) — rows, identity,
> providers and what is derived from them, pins, the channel pair, and
> what cannot be declared. This section keeps the z3 example because the
> walkthrough reads better with one concrete world carried through.

A project declares which artifacts exist and at which provisions/versions.
For z3:

```
source   Fetched  @ [Stable, Dev]     ← Repo_axes pins, C2: one identity-
                                         bearing placement PER REPO:
                                         {Stable,"4.15.2"} (Z3Prover tag),
                                         {Dev,"latest"}   (Z3Prover HEAD),
                                         {Dev,"arbipher"} (the fork, HEAD)
lib      Fetched  @ [Stable]          ← PM provides (apt install libz3-dev)
         Built    @ [Dev]             ← canary builds from source
binding  Fetched  @ [Stable]          ← PM provides (opam install z3,
 (OCaml) Built    @ [Dev]               pinned 4.16.0 on the Fetched axis)
                                         ← canary builds from lib
binding  Fetched  @ [Stable]          ← PM provides (pip install z3-solver)
 (Python)
```

This is the `ps_universe` table — per-artifact provision × version axes.
`project_spec_of_rows` converts `artifact_row` lists into `project_spec`
records. The source row's provider is `Repo_axes [stable; latest; fork]`
— a repo FAMILY: `versions_of_provider` projects each repo's `version`
record into the axes' store pins (`ax_pins`), so the Fetched source
ranges over three CONCRETE placements instead of ambient channels. A
pinned placement carries its id and is **identity-bearing**; a repo
with `id = ""` stays version-ambient.

## 4. From provisions to chains

For each artifact, the provision determines which action fires:

```
Fetched → Fetch action  (PM boundary — apt/opam/pip provides the artifact)
Built   → Build action  (canary compiles it from inputs)
Vendored → none         (pre-supplied, no action)
```

Applied to z3's provisions. There are two provision combinations that
produce complete chains ending at a probe:

**Combination A — all Fetched (stable chain):**

```
Source: Fetched  →  Fetch Source
Lib:    Fetched  →  Fetch Lib
Bind:   Fetched  →  Fetch (Binding OCaml)
Probe:           →  Probe_binding OCaml (consumes Lib + Binding)
```

Chain: `Fetch Source → Fetch Lib → Fetch Binding(OCaml) → Probe_binding(OCaml)`

**Combination B — Built lib + Built binding (dev chain):**

```
Source: Fetched  →  Fetch Source
Lib:    Built    →  Build_lib (consumes Source)
Bind:   Built    →  Build_binding (consumes Lib)
Probe:           →  Probe_binding OCaml
```

Chain: `Fetch Source → Build_lib → Build_binding(OCaml) → Probe_binding(OCaml)`

The chain ordering is determined by dependency: `Fetch Source` before
`Build_lib` (Build_lib consumes Source). `Build_lib` before `Build_binding`
(Build_binding consumes Lib). Terminal (probe) last.

The dev/stable ROW split is driven by the LIB provision in
`realize_from_rows` (Build rows require a Built lib) — the repo the
scenario fetches is selected separately, by the source placement's
pinned id (`z3_source_for_assignment`), the C2 dispatch.

## 5. From chains to assignments (version enumeration)

Within each chain, version propagation works forward:

**Chain A (all Fetched):**

```
Fetch Source      → version from spec: the Repo_axes pins —
                    F@4.15.2, F@latest, F@arbipher   (3 choices, each
                    identity-bearing)
Fetch Lib         → version from spec: F@S           (1 choice)
Fetch Binding     → version from spec: F@4.16.0      (1 choice, pinned)
Probe_binding     → terminal
```

Cartesian product: 3 × 1 × 1 = 3 assignments:

```
{ source@4.15.2,  lib@F@S, binding@F@4.16.0 }   ← "scenario 1"
{ source@latest,  lib@F@S, binding@F@4.16.0 }   ← "scenario 2"
{ source@arbipher,lib@F@S, binding@F@4.16.0 }   ← "scenario 3"
```

**Chain B (Built):**

```
Fetch Source      → version from spec: 3 pins            (3 choices)
Build_lib         → version = source version             (Follows_input)
                    source@4.15.2 → lib@B@S?  No — lib Built only has Dev.
                    source@latest, source@arbipher → lib@B@D  ✓ (2 choices)
Build_binding     → version = lib version   (Follows_input)
                    Lib@B@D → binding@B@D  ✓
Probe_binding     → terminal
```

2 assignments — the version coupling is CHANNEL-level (C2): a Built lib
pairs with a source at the same CHANNEL, whatever the source's id.
Exact-id equality died with C2 — identity-bearing sources carry ids the
Built lib's channel-level placement can never mirror, and requiring it
would have killed both dev build chains. WHICH checkout the scenario
builds from is the source placement's id (already part of scenario
identity); the lib placement says only "built @ Dev".

```
{ source@latest,   lib@B@D, binding@B@D }   ← "scenario 4" (official dev)
{ source@arbipher, lib@B@D, binding@B@D }   ← "scenario 5" (forked dev)
```

Total: **5 scenarios** — 3 all-Fetched source worlds + 2 dev build chains.

### The policy's journey — thin as the worked example (2026-08-14)

The enumeration policy is the ONE knob between the declared spec and the
scenario set. `'m policy = { config : 'm config; mutations }` where
`config = { provision : level; version : level; version_mode; mutation }`.
`thin_policy ()` = `{provision=Full; version=Subset [Stable];
version_mode=Lockstep; mutation=Free}` — every other part of the
pipeline is policy-agnostic.

1. **Declaration** — `project_run.pr_artifacts` rows carry
   `ax_universe : (provision × channel list) list` per artifact (z3's lib:
   `[(Fetched,[Stable]); (Built,[Dev])]`). `project_spec_of_rows` folds the
   rows into the `project_spec` the enumerator consumes.
2. **Enumerate** — `patterns_of ~policy spec` products the per-artifact
   placements, then resolves each level through `resolve` (Full → all,
   Subset → keep only listed entries). **`version=Subset [Stable]`
   filters every per-provision version list to the Stable channel — each
   Dev placement vanishes from the product.**
3. **Thin ⇒ bypass the source-built chain, precisely**: it is NOT an
   action-skip; it is version-subsetting. z3/llvm's Build rows are only
   reachable when the lib is **Built**, and Built exists only on the Dev
   channel. With the Dev placements gone, the product yields only the
   Fetched worlds (z3/llvm: 5 scenarios → 1 — the stable source world;
   the channel filter drops the two Dev repo pins as well as the Dev
   lib), and the Build-gated rows (Configure/Scan/Build_headers/
   Build_lib/Build_binding/Publish — `action_requires_provision` gates
   them on a Built lib) never materialize in any scenario's realize.
4. **Realize** — `pr_runner_spec assignment ~workspace` (pure): reads the
   surviving placements (`provision_of`/`version_of`) and dispatches
   the action rows by the SOURCE placement's pinned repo
   (e.g. `z3_table_rows ~source:(z3_source_for_assignment a)` — C2;
   the pre-C2 lib-channel proxy retired), yielding the per-scenario
   `runner_spec` (commands, expectations, pin-checks, world
   assertions).
5. **derive_steps** → ordered step list (action + cmd + deps +
   check_pre/post + expectation).
6. **run** — `run_project_spec` iterates the assignments (deduped by
   `scenario_dir_of`), executes steps with the per-step cache, and
   returns the verdicts the display layers consume.

The run layer wraps the policy in a config (2026-08-14): `run_config =
{ policy : run_policy }` — an IMMUTABLE record the CLI/batch set and
consumers match (`run_policy = Full | Thin` today; the open mode ladder
fetch → smoke → thin → full extends the variant). `enumeration_policy_of`
is the ONE mapping to the enumeration policy; `batch_policy pr` (a
`run_policy` chooser, `Heavy → Thin` / `Light → Full`) folds into
`batch_config pr`. The same config channel carries the CLI's `--thin`
(forces `Thin` everywhere); single-project runs use the default (Full).
Future config fields (scenario parallelism, forced cache cleanup) ride
the same record — no mutable global state.

## 6. From scenarios to execution

Each scenario goes through:

```
1. scenario_dir_of(assignment) → output directory + cache key
     e.g. "_out/canary/projects/z3/ocaml_binding-built-dev_source-fetched-arbipher_lib-built-dev_python_binding-fetched/"
     Pinned Fetched placements are IDENTITY-BEARING (C1/C2): the
     placement's version id is part of the directory — three source
     worlds get three dirs (…-fetched-4.15.2 / -fetched-latest /
     -fetched-arbipher). An UNPINNED Fetched placement stays
     version-ambient (the PM picks the actual version) and renders
     just "fetched".

2. realize_from_rows(assignment) → runner_spec
     Checks provisions: Build_lib fires when lib is Built; Fetch Lib when
     Fetched. Produces closures for shell commands.

3. derive_steps(runner_spec) → step list
     Walks the universal action catalogue. For each action with a closure
     in the runner_spec, emits a step with:
       - command (shell string)
       - deps (which steps must complete first)
       - check_post (did the output exist?)
       - expectation (PASS / xfail substring / compat-derived failure)

4. run_with_info_status(step list) → verdict
     Executes steps in dependency order. Checks cache per step (.ok marker).
     Probes compile and run; their output is compared against expectation.
     Writes actions.log and scenarios.tsv for post-run views.
```

## 7. Deploy-mismatch (Flavor 2)

When a binding is fetched from a package manager (opam, pip), it was built
against the system's lib at a specific version. When canary builds a
different version of that lib, the binding runs over a lib it wasn't
compiled against — the **deploy-mismatch**.

Example (sqlite):

```
Binding: opam sqlite3, built against system libsqlite3 @Stable
Lib:     canary builds libsqlite3 @Dev from amalgamation

Scenario: binding runs over lib@B@D
  → runtime_pairing: rp_deploy = true  [build-lib ≠ run-lib: DEPLOY]
```

This is detected by `runtime_pairings_of`: when an artifact declares
`ax_runtime = Independent`, the enumeration computes whether the scenario's
run-lib differs from the consumer's build-lib. The `spec` command annotates
deploy scenarios with `[build-lib ≠ run-lib: DEPLOY]`.

`Probe_app` is the terminal for deploy scenarios — it probes the app
against any lib, while `Probe_binding` tests lockstep (binding against its
build-lib). Both chains are generated for the same assignment; they share
a scenario in the current dedup model. Full branching (separate scenarios
per run-lib version) awaits `close_deps` wiring.

## 8. Pre-run ≡ post-run

The pre-run enumeration (`scenarios_of`) predicts which scenarios exist.
The post-run output (`actions.log`) records which scenarios ran with what
verdicts. The `spec` command joins them by `scenario_label` (the assignment
string):

```
scenarios — 5 enumerated
  ✓ xfail  source@arbipher lib@B@D binding@B@D    (fork dev build chain)
  ✓ xfail  source@latest   lib@B@D binding@B@D    (official dev build chain)
  ✓ xfail  source@4.15.2   lib@F@S binding@F@4.16.0  (stable fetch chain)
  ✓ xfail  source@arbipher lib@F@S binding@F@4.16.0
  ✓ xfail  source@latest   lib@F@S binding@F@4.16.0
```

`✓` = ran and passed (or xfail — expected failure confirmed).
`·` = enumerated but not run (dedup).
No `✗` = no unexpected failure.

(C2 removed the Fetched-ambient dedup: every repo pin is a distinct
identity, so all five scenarios run.)

The invariant: `ran_scenarios ⊆ enumerated_scenarios`. Every scenario that
ran was predicted by the enumeration. A scenario that ran but wasn't
enumerated indicates a bug.

## 9. Run cache

Canary caches at two levels so re-running skips already-done work:

### Per-step cache (local)

A step is skipped when its output directory contains a **verdict marker**
(`<step>.verdict_<variant>.ok`). The marker is written only when the step
met its expectation — a failed probe leaves no marker, so it always re-runs.
This prevents stale cache hits: a previously-failed step won't be served as
a cached success.

### Per-scenario cache (global)

The scenario's output directory (`scenario_dir_of(assignment)`) is the
cache key. Fetched artifacts are version-ambient — two assignments that
differ only in Fetched version channels share the same directory, so only
one runs (dedup).

### Variant discrimination

Different provision × version combinations get distinct directory names
(e.g. `lib-built-dev_binding-fetched_source-fetched/`). The `variant_id`
in the path ensures Built@Dev and Fetched@Stable results coexist without
collision.

### Forcing a fresh run

```sh
rm -rf _out/canary/projects/<project>/
```

Or use a distinct `variant_id` (the normal path — different variants are
different runs).

### The warm/cold trust model (2026-08-16, the C2 cold-audit lesson)

A marker certifies "this step's command worked, under THIS scenario
identity". Two consequences:

- **A scenario-dir rename IS a cold-run audit.** C2's per-repo pins
  renamed every z3/llvm scenario dir, forcing all steps cold — and the
  warm markers had been skipping broken steps since the A5 era. Five
  masked bugs surfaced (the configure flags, the unconditional install
  marker, the printf quoting, the realize-time cmake probe, the missing
  checkout — chronicled in `worklog_2026_08.md` §2026-08-16).
- **The marker does not record WHICH ref it verified.** A concrete
  commit ref is immutable, but a tag/HEAD ref can move upstream under
  the same identity; the warm hit stays stale until a cold re-run.
  Recording the verified content hash in the marker + a `--cold`
  audit flag are the open follow-up (status_project.md §3, the
  verdict-matrix pin).

## 10. Store pins — writing and reading the shared store

(2026-08-12. Design writeup: [`../../project/opam_exclusive_store_issue.md`](../../project/opam_exclusive_store_issue.md).)

Some steps read or mutate a **global mutable store** — the opam switch —
which every scenario shares. This section is the algorithm-level contract
for those steps.

### Three step classes

| class | examples | cache semantics |
| --- | --- | --- |
| **content** | source fetch, build outputs | safe by scenario-dir identity (a marker means "this dir's content exists and verified") |
| **store-writing** | `Fetch (Binding opam)` installs the package; `Publish` installs the canary-built package into the switch | a **pin operation**: its `check_post` = marker AND the store provably holds the pinned version (`pin_check_post`) |
| **store-reading** | probes compiling `-package <pkg>` against the installed binding | carry a **world assertion**: the switch must hold the scenario's pin before compiling, else fail loudly |

### Enumeration rules

- A binding whose provider declares `versions : opam_pin list` (`Lang_pkg`)
  enumerates one scenario **per pin** — the pins replace the channel axis
  for that Fetched provision (`ps_versions_of`).
- A source whose provider is `Repo_axes rs` enumerates one scenario **per
  repo** (C1/C2): `versions_of_provider` projects each repo's `version`
  record (channel PRESERVED) into the same pin axis, so per-channel
  repos ride the same identity machinery as opam pins.
- A pinned placement carries the version id in its `build_id`; it is
  **identity-bearing** (`scenario_dir_of`, the assignment string, and the
  test-mirror `ambient_key` all include it), where an unpinned Fetched
  stays version-ambient. Two scenarios differing only by pin can never
  collapse onto one directory.
- The pin-check verifies the **opam package version** (`opam list
  --columns=version` — the store's own record; the findlib META version
  can differ, e.g. `z3.dev`'s META carries the source version).

### Execution rules

- **Order is a performance contract, not a correctness one.** The
  enumerated list IS the run order; a later scenario's store-write makes
  the next scenario's pin-check fail, so its fetch re-pins (the honest
  recompile) and the probes re-assert. Reverse the order and the same
  mechanism still lands each scenario in the right world — it just pays
  more switches.
- The warm-cache skip for a store-writing step only fires when
  `check_post` passes — and `check_post` *is* the pin check, so the only
  skippable fact is "the store is provably in the state this scenario
  needs". A silent wrong-version probe (the scenario-crossing hazard) is
  therefore structurally impossible for pinned artifacts.

## 11. Two enumeration approaches — chains and graphs

The chain-based approach (`patterns_of`, `universal_chains`) and the graph-based
approach (`make_action_graph`) are two projections of the same action catalogue:

| | Chains | Graph |
|---|---|---|
| **What it produces** | Ordered action lists | Artifact nodes with edges |
| **Best for** | Scenario enumeration, `paths` display | Visualization, runtime deps |
| **Extensibility** | Add 1 entry to `action_catalogue` | Add 1 case to `store_actions` + 3 match functions + graph fold |
| **Status** | Active (runs `scenarios_of`, `canary paths`) | Visualization (`canary graph`), tests |

The graph IS the runtime reality — `derive_steps` walks a dependency DAG, the
cache forms a node graph, each step's deps are graph edges. The chain approach
is a simplified projection: it strips the graph down to the ordered actions
that matter for scenario identity. Both read from `action_catalogue`. Both are
valid views; neither should be "the one true engine."

## 12. Module structure

```
Canary_artifact (base/)         artifact identity: artifact_id, artifact_ext,
                                artifact_axes, project_spec, provision, artifact.
        ↓
Canary_project_spec (action/)   builder layer: artifact_row, project_spec_of_rows,
                                build_deps_of.
        ↓
Canary_enumerate (action/)      engine: action_catalogue, patterns_of, chain_of_*,
                                assignments_of_chain, scenario_pattern.
```

## 13. Terminology

| Term           | What it is                                        | Example                                            |
| -------------- | ------------------------------------------------- | -------------------------------------------------- |
| **chain**      | Ordered action list — the scenario shape          | `Fetch Source → Build Lib → Build Binding → Probe` |
| **assignment** | Version coordinates within a chain                | `{source@Dev, lib@B@Dev, binding@B@Dev}`           |
| **scenario**   | A chain + its coordinates — what the run executes | Chain B + {source@D, lib@B@D, …}                   |
| **pattern**    | Abstract action-chain shape (Sc.N id)             | `Sc.2.OCaml` = "build OCaml binding"               |
| **stage**      | Lifecycle coverage row                            | `build_lib`, `fetch_binding`                       |

## 14. Ownership

| Function               | Module                            | Role                             |
| ---------------------- | --------------------------------- | -------------------------------- |
| `project_spec_of_rows` | `action/canary_project_spec.ml`   | rows → spec                      |
| `patterns_of`          | `action/canary_enumerate.ml`      | spec → (chain × assignment) list |
| `scenarios_of`         | `project/canary_project_run.ml`   | project → assignment list        |
| `realize_from_rows`    | `action/canary_action_templates.ml` | assignment → runner_spec       |
| `derive_steps`         | `action/canary_step_builder.ml`   | runner_spec → step list          |
| `run_with_info_status` | `backend/canary_local_runner.ml`  | step list → verdict              |
