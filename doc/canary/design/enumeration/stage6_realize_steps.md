# Pass 6 — realize: commands, steps, execution

**IR:** one **world** `assignment` → **steps** `step list`, the object code. (IR names: [`README.md`](README.md).)

**Kind: rationale.** Pass 6 of six, the last. Standalone. Pass 5 hands
over an ordered list of scenarios; this one turns each into a **step
list** — the pipeline's object code — and then a backend consumes it.
EXECUTING is one of four backends, not a stage above them: `run_graph`
runs it here, `render_gh_step` emits GitHub Actions YAML,
`mermaid_of_steps` draws it, `render_steps_data` renders the page. This
doc covers making the step list, running it, and deciding
what happened. The map is [`README.md`](README.md).

**It also owns the OCCASION** (§2b, added 2026-09-16) — when a check
fires and against what evidence. That is a function of `(world, action,
mechanism, lang)`, which is this directory's vocabulary; `agreement/`
owns what a check CLAIMS. The account used to live entirely in
[`../agreement/pipeline.md`](../agreement/pipeline.md), which left this
doc — the doc for the pass that attaches `agreement_ctx` to every step —
mentioning "agreement" zero times.

> Created 2026-08-24, closing the last stage gap. It ABSORBED
> `algorithm_explainer.md`, the walkthrough that predated the stage map:
> §2 (the action catalogue), §6 (the four steps), §7 (deploy-mismatch),
> §8 (pre-run ≡ post-run), §9 (the run cache), §11 (chains vs graph), §12
> and §14 (structure and ownership) are here; its §1 pipeline diagram is
> in the README, §3/§4/§5 are passes 1 and 3, §10 is pass 5 plus
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
pass 3's constraints enforce
([`stage3_enumerate_worlds.md`](stage3_enumerate_worlds.md) §1, §3) — here it is stated as a
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
4. run_graph(steps)             →  verdicts
```

**1** is pass 5's ([`stage5_order_worlds.md`](stage5_order_worlds.md) §1) — it
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

## 2b. The OCCASION — when a check fires

**This section is here because the seam runs here.** `agreement/` owns
what a check CLAIMS; this pass owns **when it is triggered and against
what** — and that is a function of `(world, action, mechanism, lang)`,
which is this directory's vocabulary and not the agreement layer's.
Until 2026-09-16 the split was declared the other way round, the
account lived in [`../agreement/pipeline.md`](../agreement/pipeline.md),
and this doc mentioned "agreement" zero times while being the doc for
the pass that attaches the context.

### The three questions, and where each is answered

A check reaching a step has passed three gates, and they are answered in
three different places. Confusing them is why a cell that could never
speak and a cell waiting on an inspector read the same for a year.

| question | needs | answered at |
| --- | --- | --- |
| **applicability** — can this PROJECT carry the claim? | mechanism, lang, declaration | **pass 2** ([`stage2_analyse_spec.md`](stage2_analyse_spec.md)) — no world |
| **firing** — does it fire at THIS action in THIS world? | + a world | **here**, at realize |
| **evidence** — is there anything to read? | + a run | the runner, per step |

Applicability moved out of the run in 2026-09-14 for a measurable
reason: it was re-answered at every firing site and logged, so sqlite
emitted the same six `not_applicable` sentences on each of ten
scenarios — sixty lines restating one static fact about cstubs. Firing
cannot move, because it takes a world.

### What realize attaches

`Canary_pipeline.steps_of` hands `derive_steps` the scenario's own
assignment and the project's declared mechanism, and `derive_steps`
attaches an **`agreement_ctx`** — mechanism, language, world — to the
steps that have binding facts (`agreement_ctx_of_action`). A
`fetch_source` step gets `None`; a `probe_binding_ocaml` step gets the
context.

The context is what turns the registry's world-dependent queries on for
that step. Without it a method's `m_firing` and `m_inputs` have no world
to ask about, and both are functions OF a world.

### When evaluation happens, today

**The runner evaluates, after the step's command.** `run_step` calls
`Canary_agreement.evaluate_step`, which produces ONE record per step
feeding BOTH the report and the step's acceptance — a compat step used
to evaluate its comparators twice, once to log and once to decide.

**Evaluation is NOT a further pass.** The step list is object code
consumed by four backends and only one of them checks anything:
GH-render, Mermaid and HTML evaluate nothing. A pass above the IR that
one consumer reaches would be a stage that three targets skip.

**A violated agreement does not, by default, fail its step.** The
acceptance policy is "the command succeeded and its postcondition
holds", and a disagreement found there is a finding about ARTIFACTS that
the action was never asked to fail on — ssl's `dependencies_provided:
violated libcrypto.so.3` is real and must not turn ssl red. `--strict`
makes the two views agree by failing the step that READ the disagreeing
evidence. See [`../agreement/landing.md`](../agreement/landing.md).

### Where the evidence is, and why that is this pass's problem

A method names its evidence as a relative path — `"fetch_binding_ocaml/
inspect.json"` — and `run_step` resolves it against the world's output
tree. The step tag in that path is **derived from the world**:
`binding_evidence_tag` reads the binding's provision (`Fetched` → the
step that fetches and installs it, `Built` → the step that builds it),
and `lib_evidence_tags` does the same for the library.

**Those derivations are world-arranging, so they are this pass's
vocabulary — and they live in `agreement/canary_agreement_common.ml`.**
That is the one place the seam is still crossed in code rather than only
in prose. It is recorded rather than patched because the fix is not a
move: `Canary_project_analysis.producers_of` plus the world's provision
computes the same function from the declarations, and deriving it is
what would also close the placement class — *the producer chooses a
step, the consumer derives one, and nothing makes them agree*, four
instances, each fixed individually (backlog §50).

### The direction: a check that produces what it reads

Today the producer (an inspection) and the consumer (a comparator) are
separate steps with an address between them, and every instance of that
class has been an address that did not match. The recorded direction is
to **bundle them into one action, because that is what checking is** —
then there is no address to negotiate, and a second consumer of the same
evidence is a cache hit rather than a coordination problem.

The codebase is already drifting that way, twice, both times to fix
exactly this class: `Native_lib_probe` emits its native summary INSIDE
the probe's own command (2026-09-13) rather than as a child step, and
`probe_ocaml_env_cmd` emits the consumer's ABI summary inline after
`RC=$?` (2026-09-15).

**Not built, and the blocker is named.** `<action>_post` is a trigger
MOMENT, not a specification of what runs at it; what runs is derived
from what the action just produced, and pass 2's join (`produced_at` /
`producers_of`) is the value that answers it. What stands in the way is
that **three locator vocabularies** exist for "where is the library" —
typed `probe_lib_location`, `lib_locator` globs, raw shell — and a
derived inspection has to resolve a location. The ordered remainder is
[`../action_model.md`](../action_model.md) §6.

Read that doc before adding a step whose name ends in `_inspect`.

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

## 3b. A fetch is not realized when nothing consumes it

`derive_steps` walks the catalogue and realizes what a project DECLARES,
which for a fetch is not always what the world NEEDS: cairo's all-`Fetched`
world cloned a repository whose tree no later step read.
`drop_unread_fetches` drops a `Fetch k` when no step in the world consumes
`k`, asked of the typed catalogue (`consumes_of_action`, pinned by
`consumes_produces.*`) rather than of `step.deps`.

Only fetches, because a `Fetch` is the only action class with no inputs —
`(Fetch Source, [], [Source])` against `(Build_lib, [Source], [Lib])`,
`(Probe_lib, [Lib], [])`. Everything else consumes something and is
therefore always attached to the graph; a fetch is the only node that can
be orphaned. Its input is really the world's *ambient store*, the same
fact seen from the other side. Why the question is answered here rather
than at enumeration, where `source_is_read` already asks it: [the README's
*Known drift*](README.md).

A declared source row stays declared — `spec-check` still reports it, and
whether its ref resolves is a question about the DECLARATION, tracked
with `spec-check --probe-pm` in [`../platform.md`](../platform.md) §7.

Pinned by `derive.steps_are_demanded` as a pair: cairo's world must lose
`fetch_source` while keeping its probes; every sqlite world with
`build_lib` must keep it. Either half alone is satisfiable by a broken
rule.

## 3c. A fetch prepares once and ensures per world

The checkout a fetch produces is SHARED (no scenario in its path —
[pass 1](stage1_declare_spec.md)) but its marker is per-world, so N worlds
at one ref each ran a full fetch to converge on a tree that was already
right. The emitted command separates the question by who is asking:

| half | question | scope | guard |
| --- | --- | --- | --- |
| clone / fetch / worktree add | *has the ref moved?* | the **run** | sentinel `<main>-refreshed-$CANARY_RUN_ID` |
| checkout + marker | *is this world's tree here?* | the **world** | none; it is cheap |

`CANARY_RUN_ID` is a process-lifetime stamp (`Canary_store.run_id`)
exported into every step's shell beside `OPAMSWITCH`. A process IS a run:
`canary action <p>` executes every world of a project in one, a GH job
runs exactly one — which is the scope in which `latest` is fixed.

```
first world in a run   0.317s     consults the remote
next world, same run   0.004s     sentinel hit, no network
first world, new run   0.278s     refreshes again
```

A moving ref still refreshes once per run, so refresh-on-demand is
preserved rather than traded for speed; stale sentinels are swept before
a new one is written. On CI the variable is unset and the workspace cold,
so the remote half runs — what a fresh runner needs.

Pinned by `source.refresh_is_run_scoped`, a SHAPE check: the clone must
sit INSIDE the guard and the marker write OUTSIDE it. Swap either and a
world re-fetches, or stops recording its own evidence.

**The other fetch kinds are deliberately not converted:**

| kind | redundant cost per extra world | state |
| --- | --- | --- |
| git source | 1.1s | converted |
| apt / brew | **0.40s** | not converted |
| opam pin | ~0s when the pin is held | covered elsewhere — the fetch is pin-checked, so the run cache warm-skips it; a real pin flip (~5.2s) is work, not waste |
| conda-forge prebuilt | ~0s | `Canary_prebuilt.is_prepared` + the `prebuilt` subcommand, out of band |
| curl archive | ~0s | sqlite's `build_lib` carries a `test -d … \|\|` guard inline |

0.40s is below a run's own variance, so converting apt/brew would be
optimising noise — and it carries a trap the git case does not. The
obvious guard, `verify_installed_cmd`, asks whether the package EXISTS: a
world declaring version X would be satisfied by installed version Y,
which is the false pass canary exists to catch. The right predicate is
`Canary_pm.installed_version_cmd` against the declared version — the apt
analogue of `holds_pin_cmd`.

## 4. The run cache

Two levels, and the reason the second is safe is subtler than it looks.

**Per-step.** A step is skipped when its output dir holds a **verdict
marker** (`<step>.verdict_<variant>.ok`). The marker is written only when
the step MET its expectation — a failed probe leaves none, so it always
re-runs. That is what stops a previously-failed step being served as a
cached success (`canary cache-test` guards it). Since 2026-08-17 the
marker also carries a **spec fingerprint** over the realized command and
the expectation's form, so an edited command invalidates it.

**Per-scenario.** The scenario dir is the key, which is why pass 5's
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
neutral cell — see [`../matrix.md`](../matrix.md) §6.

## 7. Ownership

| function | module | role |
| --- | --- | --- |
| `project_spec_of_rows` | `action/canary_project_spec.ml` | rows → spec |
| `patterns_of` | `action/canary_enumerate.ml` | spec → (chain × assignment) list |
| `scenarios_of` / `scenarios_in_run_order` | `project/canary_project_run.ml` | project → ordered assignments |
| `realize_from_rows` | `action/canary_action_templates.ml` | assignment → runner_spec |
| `derive_steps` | `action/canary_step_builder.ml` | runner_spec → step list |
| `run_graph` | `backend/canary_local_runner.ml` | step list → verdict (wrapped by `Canary_run_info.run_project`, which also writes the log, the diagrams and `run_state.json`) |

Four backends consume the same step list: the local runner executes it,
`canary_gh.ml` renders GH Actions YAML, `canary_diagram.ml` renders
Mermaid, `canary_html.ml` renders the result page.

## 8. Why a realize dump is an APPLICATION, not a projection

Two of the IRs contain closures and therefore cannot be `deriving show`:

- **`runner_spec`** is a record of command *builders*. It has no printable
  form of its own — which is fine, because it is an intermediate nobody
  needs: `emit --stage realize` prints the **step list**, its observable
  consequence.
- **`step`** carries `cmd : output_dir:… -> variant_key:… -> string`,
  `check_pre`, `check_post`.

So a realize dump is an **application**, not a projection: apply `cmd`
with the scenario's real `output_dir` and print the resulting shell
string; report `check_pre`/`check_post` as present/absent plus the
expectation variant. This path already exists —
`Canary_local_runner.step_fingerprint` realizes the full command outside
a run in order to fingerprint it, and `runner.marker_stale_on_spec_change`
depends on that. `emit --stage realize` is that realization, printed instead of hashed.

## 9. `pr_runner_spec` is not pure

Deriving a step list APPLIES `pr_runner_spec`, and that application is
not pure for every project: tiny-full's realization can call
`Canary_tiny_workspace.materialize_built_lib`, which does `rm_rf` +
rebuild. Stages 1-4 are pure; this one is not, and a caller that only
wants to LOOK at a project — a dump, a matrix cell — has to know it.

Measured 2026-08-24: **the impure branch is unreachable today.**
tiny-full enumerates one scenario, all Vendored, which dispatches to
`Base` -> `witness_base_workspace ()`, which is path arithmetic and
touches nothing. The impure branch is idempotent and writes into tiny's
own cache rather than the passed workspace, and it returns only if
tiny-full regains its Built-lib scenarios.

`Canary_pipeline.actions_of` exists for the caller that needs the action
set and not the commands (the result matrix): it passes a throwaway
workspace, which the matrix had always done without saying why.

The right fix is the one CLAUDE.md names as missing — materialization as
an ACTION in the catalogue rather than something that happens while
building the spec. That is an arc, not a patch; deferred deliberately.

---

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
