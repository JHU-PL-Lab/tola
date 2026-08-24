# Stage 5 — realization and execution

**Kind: rationale.** Standalone. Stage 4 hands over an ordered list of
scenarios; this stage turns each one into commands, runs them, and decides
what happened. The map is [`README.md`](README.md).

> Created 2026-08-24, closing the last stage gap. It ABSORBED
> `algorithm_explainer.md`, the walkthrough that predated the stage map:
> §2 (the action catalogue), §6 (the four steps), §7 (deploy-mismatch),
> §8 (pre-run ≡ post-run), §9 (the run cache), §11 (chains vs graph), §12
> and §14 (structure and ownership) are here; its §1 pipeline diagram is
> in the README, §3/§4/§5 are stages 1–2, §10 is stage 3 plus
> [`../../project/opam_exclusive_store_issue.md`](../../project/opam_exclusive_store_issue.md),
> and §13's terminology is [`stage0_naming.md`](stage0_naming.md). `git
> show b4570b9` has the original.

## 1. The action catalogue — what actions exist

Every action is a typed function from inputs to an output:

```ocaml
type action_sig = {
  action   : Canary_basic.action;
  consumes : artifact list;   (* inputs *)
  produces : artifact;        (* output *)
  version  : Ambient | Follows_input;
}
```

| action | consumes | produces | version rule |
| --- | --- | --- | --- |
| `Fetch Source` | — | `Source` | Ambient (from the spec) |
| `Fetch Lib` | — | `Lib` | Ambient |
| `Build_lib` | `[Source]` | `Lib` | Follows_input — source-primary |
| `Fetch (Binding OCaml)` | — | `Binding OCaml` | Ambient |
| `Build_binding OCaml` | `[Lib]` | `Binding OCaml` | Follows_input |
| `Probe_binding OCaml` | `[Lib; Binding OCaml]` | (terminal) | — |

The version rule encodes propagation: `Build_lib` consumes a `Source`, so
its output's version IS the source's. That is the same source-primary rule
stage 2's constraints enforce
([`stage2_filters.md`](stage2_filters.md) §1, §3) — here it is stated as a
property of the action rather than as a filter over assignments, and the
two must agree.

`consumes_of_action` / `produces_of_action` are the live catalogue, pinned
per action by `consumes_produces.<action>` (13 of them). Two things are
still hand-written rather than read from it: `ax_follows` is declared on
the artifact, and `build_deps_of` hardcodes lib → source. Deriving both
from the catalogue is the open cleanup.

## 2. The four steps

```
1. scenario_dir_of(assignment)  →  output directory + cache key
2. realize ∘ dispatch           →  runner_spec  (shell command closures)
3. derive_steps(runner_spec)    →  step list
4. run_with_info_status(steps)  →  verdicts
```

**1** is stage 3's ([`stage4_order.md`](stage4_order.md) §1) — it
appears here because it is also the cache key, and §4 below depends on
that.

**2 — `realize ∘ dispatch`.** A project's `pr_runner_spec` must be exactly
this composition: `dispatch` is pure project-local data reading only the
assignment's coordinates (`provision_of`, `channel_of`, `provided`,
`bad_placements`), and `realize` holds the command templates. So the
provision decides which commands exist — `Build_lib` fires when the lib is
`Built`, `Fetch Lib` when it is `Fetched` — and nothing else in a project
branches on a scenario. Pinned by `enumerate.dispatch_coordinate_reads`
and, per project, `z3.dispatch_reads_source_placement` /
`llvm.dispatch_reads_source_placement`.

**3 — `derive_steps`.** Walks the universal catalogue; for each action
with a closure in the `runner_spec` it emits a step carrying the command,
its `deps`, a `check_post` (did the output appear?), and an
**expectation** — `Expect_success`, `Expect_failure { contains_any }`, or
`Expect_compat_failure { inputs }`, the last resolved at run time from the
cached inspect summaries. A project never hand-writes a failure substring;
every prediction goes through the one lowering.

**4 — execution.** Steps run in dependency order, each gated on its
`check_pre`, each cache-checked (§4), appending to `actions.log`. The
runner captures every step's output:
`{ ( cmd ) ; echo $? > RC ; } 2>&1 | tee LOG`. The inner parentheses are
load-bearing — many probes end in `exit $RC`, and without the nested
subshell that exits the group before the status is recorded.

## 3. The two dependency relations — and the drift

There are two projections of the catalogue, and this is the one place in
the pipeline where they disagree:

| | chains | graph |
| --- | --- | --- |
| produces | ordered action lists | artifact nodes with edges |
| best for | scenario enumeration, `canary paths` | visualization, runtime deps |
| built by | `patterns_of`, `universal_chains` | `node_of_assignment` → `close_deps` → `execution_plan` |
| status | **active** — runs `scenarios_of` | visualization and tests |

The graph is the runtime reality in principle — `derive_steps` walks a
dependency DAG, each step's `deps` are edges — but the two are **separate
relations that have drifted**. The drawn diagram under-connects relative
to `step.deps`, so the connectivity self-check is muted behind
`CANARY_DIAGRAM_CONN=1`. Execution is sound (every step's `check_pre`
enforces its real deps); only the picture is wrong. Reconciling them into
ONE relation is tracked in `../../status.md` §A.

Pins on the graph side: `action.node_of_assignment_chain`,
`action.close_deps_deploy_mismatch`,
`action.execution_plan_topo_and_edges`.

## 4. The run cache

Two levels, and the reason the second is safe is subtler than it looks.

**Per-step.** A step is skipped when its output dir holds a **verdict
marker** (`<step>.verdict_<variant>.ok`). The marker is written only when
the step MET its expectation — a failed probe leaves none, so it always
re-runs. That is what stops a previously-failed step being served as a
cached success (`canary cache-test` guards it). Since 2026-08-17 the
marker also carries a **spec fingerprint** over the realized command and
the expectation's form, so an edited command invalidates it.

**Per-scenario.** The scenario dir is the key, which is why stage 3's
identity rules are cache rules too: two assignments that differ only in an
ambient version share a directory and only one runs.

**Forcing cold:** `rm -rf _out/canary/projects/<project>/`.

**The warm/cold trust model** (the C2 lesson, 2026-08-16). A marker
certifies "this command worked, under THIS scenario identity". Two
consequences:

- **A scenario-dir rename IS a cold audit.** C2's per-repo pins renamed
  every z3/llvm scenario dir, forcing all steps cold — and five bugs the
  warm markers had been skipping since A5 surfaced at once.
- **The marker does not record WHICH ref it verified.** A concrete commit
  is immutable, but a tag or HEAD ref can move upstream under the same
  identity, and the warm hit stays stale until a cold re-run. Recording
  the verified content hash plus a `--cold` flag is open.

**What neither level models: the identity of a step's INPUT artifacts.**
Measured twice — sqlite's staging copy-out, and a `dllz3ml.so` linked
against `libz3.so.5.0` while the tree exported `5.1`. In the second case
ninja said "up to date" and canary's marker agreed, both correct by their
own rules, and the artifact was wrong. So canary cannot delegate the
question to an external build tool: *"ninja said it was up to date" is not
evidence about the artifact.* The proposal is
[`../artifact_cache.md`](../artifact_cache.md) §5 step 2.

## 5. Deploy-mismatch (Flavor 2)

A binding fetched from a package manager was built against *some* lib at
*some* version. When canary supplies a different version, the binding runs
over a lib it was never compiled against — the **deploy mismatch**:

```
binding: opam sqlite3, built against the system libsqlite3 @Stable
lib:     canary builds libsqlite3 @Dev from the amalgamation
       → rp_deploy = true   [build-lib ≠ run-lib: DEPLOY]
```

`runtime_pairings_of` computes it: when an artifact declares
`ax_runtime = Independent`, the enumeration asks whether the scenario's
run-lib differs from the consumer's build-lib, and `canary spec` annotates
those scenarios. `Probe_app` is the terminal for a deploy scenario (it
probes the app against any lib) where `Probe_binding` tests lockstep. Both
chains are generated for one assignment and share a scenario under today's
dedup; full branching awaits `close_deps` wiring. Pinned by
`enumerate.deploy_mismatch` and `sqlite.runtime_edges_two_instance_slice`.

## 6. Pre-run ≡ post-run

`scenarios_of` predicts which scenarios exist; `actions.log` records which
ran with what verdict. `canary spec` joins them on the assignment label:

```
scenarios — 5 enumerated
  ✓ xfail  source@arbipher lib@B@D binding@B@D
  ✓ xfail  source@latest   lib@B@D binding@B@D
  ✓ xfail  source@4.15.2   lib@F@S binding@F@4.16.0
```

`✓` ran and met its expectation (an xfail confirmed counts); `·`
enumerated but not run; `✗` an unexpected failure.

The invariant is **`ran ⊆ enumerated`** — a scenario that ran without
being predicted is a bug. Note the asymmetry, because it is the honest
one: the reverse containment does NOT hold and is not meant to.
Enumeration coverage is not verification coverage, and a `·` is not a
neutral cell — see [`stage6_report.md`](stage6_report.md) §6.

## 7. Ownership

| function | module | role |
| --- | --- | --- |
| `project_spec_of_rows` | `action/canary_project_spec.ml` | rows → spec |
| `patterns_of` | `action/canary_enumerate.ml` | spec → (chain × assignment) list |
| `scenarios_of` / `scenarios_in_run_order` | `project/canary_project_run.ml` | project → ordered assignments |
| `realize_from_rows` | `action/canary_action_templates.ml` | assignment → runner_spec |
| `derive_steps` | `action/canary_step_builder.ml` | runner_spec → step list |
| `run_with_info_status` | `backend/canary_local_runner.ml` | step list → verdict |

Four backends consume the same step list: the local runner executes it,
`canary_gh.ml` renders GH Actions YAML, `canary_diagram.ml` renders
Mermaid, `canary_html.ml` renders the result page.

## Pins guarding this stage

| pin | asserts |
| --- | --- |
| `consumes_produces.<action>` (13) | each action's declared inputs and output |
| `probe_invariant.consumes_eq_artifacts` | a probe consumes exactly the artifacts it names |
| `arrow.providing_action_total_and_consistent` | provider → action is total and inverse-consistent |
| `enumerate.dispatch_coordinate_reads` | `dispatch` reads only assignment coordinates |
| `z3.dispatch_reads_source_placement`, `llvm.dispatch_reads_source_placement` | …per project |
| `derive.fetch_lib_matches_helper` | the derived fetch matches the shared helper |
| `action.node_of_assignment_chain`, `action.close_deps_deploy_mismatch`, `action.execution_plan_topo_and_edges` | the graph projection |
| `enumerate.deploy_mismatch`, `sqlite.runtime_edges_two_instance_slice` | the runtime-edge / deploy computation |
| `runner.marker_stale_on_spec_change` | an edited command invalidates the warm marker |
| `s2.command_of_step_raw_identity` | a Raw command reaches the step unaltered |
