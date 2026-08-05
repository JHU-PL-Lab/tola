# The enumeration → node-graph model

> Canonical description of how a project's scenarios are enumerated and lifted
> to a dependency graph. Settled 2026-08-04 (converging the run onto the
> enumeration algorithm). **To-dos live in `status.md` §A** — this file is the
> stable model, not a plan.

## The pipeline

```
stage 1  project_spec         static declaration: artifacts + per-artifact
         + 'm policy           provision/version universes; policy = config levels
                               + injected mutations (tiny-factory only)
stage 2  enumerate ~policy    product-then-filter → assignment list
                               (the flat combinatorial core)
stage 3  close_deps           lift an assignment → artifact_node graph(s)
                               (add the runtime edge; branch for mismatch)
```

- **`assignment`** = `(artifact_id × placement) list`, `placement = {provision;
  version}`. One instance per kind. This is the **enumerated object** — cheap to
  produce, dedup, and label, and what the run consumes today.
- **`artifact_node` graph** = a **derived view** of an assignment: `node_of_
  assignment` computes the build edges (`built_from`) off the action catalogue
  (the *seam*, `built_from_of_assignment` — no new edge vocabulary); `close_deps`
  adds the runtime edge (`runtime_dep`). Like `diagram`/`html`/`gh` render the
  step list, the node graph **renders an assignment** — a backend, computed on
  demand. You store/enumerate assignments; you lift when you need edges.

**So why keep both?** `assignment` is the IR (flat, one-instance-per-kind, where
provision×version×mutation combinatorics live); the node graph is one rendering
of it that adds edges. They're program vs backend, not duplicates. The flat form
can't hold *two* instances of one kind — which is the whole reason stage 3 exists.

## Build edges are grammatical; runtime edges are resolved

The one settled principle:

> A build edge (`Generates`: source→lib, lib→binding) is **universal** — the seam
> reads it off `consumes_of_action`, so the flat assignment already implies every
> build edge. A **runtime** edge that *differs from* the build input — a run-lib ≠
> build-lib (deploy mismatch) or an ambient lib (libc) — is what the grammar
> can't give. That, and only that, is resolved at stage 3.

This is the flat view's one documented divergence: `consumes_of_action Build_app`
lists `Lib` as a runtime dep, and `node_of_assignment` drops it. `close_deps` is
where it comes back.

## `dep_mode` — the runtime-edge resolution knob

```ocaml
type dep_mode = Lockstep | Independent | Ambient of string
```

Carried per runtime edge (NOT a `project_spec` field — the edge is grammatical,
only its resolution varies), defaulting `Lockstep` so every current project is
unchanged. Consumed by `close_deps`:

- **`Lockstep`** — run-lib = build-lib (the chain). An App-less assignment has no
  runtime edge ⇒ `close_deps a = [node_of_assignment a]`: flat projects
  (sqlite/tiny) are byte-identical.
- **`Independent`** — run-lib is a *second* lib instance ranging over the lib's
  version universe. Combined with the build-version axis already in the
  assignment, the full build×run cartesian appears — the **deploy mismatch**.
  This is exactly what `make_action_graph`'s hardcoded `Build_app` binding×lib
  cartesian already does; `close_deps` reaches it from the flat form, unifying
  the two graphs (the App cartesian = `Independent`; the chain = `Lockstep`).
- **`Ambient s`** — an un-enumerated external lib; shape only in v1.

**Who produces the mode value?** Nothing live yet — today only the `close_deps`
test drives it. The value ("this project wants the mismatch") is a probe/run
intent; sourcing it is the **action-variant / probe revisit** (a separate topic)
and lands with A5 (wiring z3/llvm onto this). Until then `close_deps` is tested
machinery ahead of its consumer.

## Non-negotiables (don't re-solve)

- **No new `edge` vocabulary.** `built_from`/`runtime_dep` ≈ the build/run
  *action*; reuse the action's consumes/produces (§6.5), as the seam does.
- **`artifact_node` lives in the action layer** (relocated from base, M1.0), and
  is the *only* graph node — no `artifact_info` middle layer (that first-cut idea
  was dropped). The flat `assignment`/`placement` is the degenerate node graph.

## Two engines, one store/runner/producer factoring

*(Absorbed 2026-08-04 from the retired `harness_canary_orthogonality.md`.)*
Canary's methodology runs **two independent engines** over the same rules — if
both agree, the rules are validated (the surface.md claim):

- **Mutation engine** — the tiny-factory mutates ONE fixed world (apply patch /
  rename / soname-bump / drop-val in a sandbox via `canary_tiny_prepare.ml` +
  `canary_tiny_workspace.ml`), the ground-truth oracle.
- **Combinator (enumeration) engine** — canary traverses a *space* of worlds via
  `Canary_enumerate.enumerate` over `ps_provisions_of`/`ps_versions_of` (this doc).

Both slot into one cross-engine abstraction — the three concerns to keep
orthogonal:

- **Stores** — *what artifacts are available* (a self-describing dir/package of
  source/lib/binding/app; provides the artifact-kind surfaces the spec consumes).
- **Runners** — *what computation runs* (build/probe/inspect steps reading stores,
  emitting to a shared output dir; `run_project_run` is the runner).
- **Producers** — *how stores are populated* (mutation engine: sandbox-build a
  mutated workspace; real project: a PM — `opam install z3.4.13` vs `z3.dev` are
  two producers of two stores).

The open operational work is keeping producers self-describing so a store built by
the mutation engine's producer is consumable by the combinator engine's runner
without leaking assumptions only the former satisfies.

## Derived vs hand-written

*(Absorbed from the retired `derived_vs_hardcoded.md`; tiny1-scoped status entries
dropped.)* Two rules govern what is machinery vs project input:

1. **Everything derivable from a small hand input should be derived** — the hand
   input is the source of truth, the derivation is machinery. Adding a scenario /
   project / contract should touch the *hand input*, not the machinery. (The
   enumerate engine is the current high-water mark: per-artifact provision/version
   axes are now derived, not hand-listed.)
2. **What stays hand-written stays project-specific** — framework infra is never
   copied per-project (see the tiny workspace materializer); reusable primitives
   are consumed, not forked; only the per-project spec + surface + optional
   contract-bindings are hand-authored.

## Forward construction — assessment (`canary construct`, 2026-08-04)

The graph is best built **forward**: artifacts are NODES, build/fetch actions are
EDGES that generate new nodes (with variants). `make_action_graph` already does
this (diagram-only); `canary construct <pj>` makes it visible. The experiment
**confirms the forward idea is right** (the deploy mismatch — an App whose
build-lib ≠ runtime-lib — falls out) but **`make_action_graph` is NOT usable as
the engine as-is**. On a 2-version project it emits **82 App nodes**, *identical
for sqlite and tiny-full* (it's driven by the universal `store_actions`, not the
project). Concrete defects the output exposes:

1. **Not project-aware.** Ignores the project's real capabilities (sqlite doesn't
   build the OCaml binding — it's opam — nor headers, yet both appear as `built`).
   → the construction must be driven by the project's declared actions/providers.
2. **Not source-primary for bindings.** It makes `binding@stable ← lib@dev` — a
   binding *built against* a mismatched lib, which is nonsense at BUILD time. The
   only legitimate cross-version pairing is the **runtime** mismatch (build-lib vs
   run-lib) at the App/probe edge. → build edges must **propagate version**
   (`source@v → lib@v → binding@v`); the mismatch lives ONLY on the runtime edge.
3. **Full cartesian + duplicates.** `binding × lib` for every App, `Build_app`
   added per-lang, no dedup → the 82. → generate the matched chain by
   source-primary propagation, and add the mismatch as a *declared* runtime edge
   (`close_deps Independent`), not a blind product.
4. **No `Vendored` nodes.** Only build/fetch; tiny's vendored/cached artifacts
   aren't modelled → tiny-full's real graph is missing.

**Conclusion:** a real forward-construction engine = `make_action_graph`'s shape,
but (a) driven by the project (capabilities + providers), (b) **source-primary**
version propagation on build edges, (c) mismatch as a declared runtime edge only,
(d) `Vendored` nodes. That is the `close_deps`/graph work — now with a concrete
target and a diagnostic (`construct`) to check it against. (An interactive
`--step` mode — prompt per node as the run walks the DAG — is a natural follow-up
once the node set is correct; today's 82-node graph is too explosive to step.)

### Verdict: improve `make_action_graph` in place (no new function)

Analysis of the consumers settled it. `make_action_graph`'s only real consumer is
`job_paths_of_action_graph` (the `canary paths` table) — and that table was
**already wrong** for the same root reason as the `construct` explosion:
`Build_binding` paired a binding with *every* lib version (cartesian), so
`binding@stable ← lib@dev`. So the defects aren't a reason to route around the
function — they're bugs to fix in it, benefiting both consumers.

- **Fixed (`9b0e76d`): source-primary `Build_binding`** — `binding@v` builds only
  against `lib@v`. `paths` combo counts corrected (7/8: 4→2, 15: 8→4; total 62→42);
  `construct` bindings 10→6, apps 82→50. Both consumers now correct; test green.
- **Fixed (`01cd05e`): `Build_app ~app_mode` (dep_mode).** `Independent` (default)
  = the mismatch cartesian (`paths` unchanged, 42); `Lockstep` = the matched chain.
  `construct sqlite` 50 apps → `--matched` 18. `dep_mode` moved before
  `make_action_graph` so it and `close_deps` share ONE knob. The mismatch is now a
  choice, not forced.
- **Fixed (`4b67b52`): project-aware by N/A MARKING, not filtering.** `make_action_graph`
  stays universal; `node_applicable ~provisions_of_kind` marks a node applicable iff
  the project declares its `(kind, provision)` AND its build/runtime deps are — the
  mark **cascades along edges** (the `canary scenarios` idiom on nodes, reusing
  `ps_provisions_of`). `construct` shows "applicable / total (n/a)": sqlite bindings
  6→2 applicable (built ones n/a — it fetches opam), lib 4/4. This is cleaner than
  filtering (algorithm stays universal; coverage is visible).
- **Fixed (`c5ea578`): `Vendored` nodes.** `make_action_graph ~vendored` adds, per
  kind per version, a `Vendored` node (a supplied copy — an initial node, not
  action-generated). Universal (default off, `paths` unchanged); the project
  N/A-marking filters. `construct tiny-full` now lights up — every kind has 2
  applicable vendored nodes (its all-vendored scenario), where it was all-n/a.
  So `make_action_graph` carries all three provisions (Built/Fetched/Vendored)
  universally, marked per-project — **it IS the forward engine now** (universal for
  `paths`, marked for the run), one function.
- **Follow-ups (for when the run consumes the graph):** (a) tiny's BUILT lib is
  n/a because `Build_lib` builds from the FETCHED source, not tiny's *vendored*
  source — `Build_lib` should build from any source@v (a source-provision
  refinement); (b) App duplicates (a `make_action_graph` dedup); (c) the mismatch
  marker doesn't fire on a FETCHED binding (its build-lib is implicit/system, not a
  `built_from` edge).

## The path-table (pattern) approach — a post-graph scenario enumeration (warm-up)

**Three scenario representations exist; the path table is the post-graph one.**

1. **`good_scenarios` (Sc.1..Sc.6)** — `action/canary_scenario.ml`. The EARLIEST
   model (2026-03): a hand-listed catalogue of good scenarios (build native lib,
   build binding, build/run app). Alive today only as the **abstract-stage
   catalogue** behind `canary scenarios` (coverage matrix).
2. **The path table (`job_path` / `pattern_row`)** — `action/canary_path_table.ml`
   (2026-06-01, Phase 5). Takes `make_action_graph`'s constructed nodes and, for
   each node, flattens its `built_from`/`runtime_dep` chain into a **job_path**
   (action-path string + depth + origin + a mismatch annotation); `pattern_row`
   then **groups structurally-identical paths and counts version combos**. This is
   the `canary paths` / `paths-md` table (17 patterns) + the diagram node labels.
   It is **post-graph** (construct → flatten → group) and, as its own docstring
   says, *"independent of any project spec — the universal enumeration of what
   could be built."*
3. **`enumerate` (assignments)** — `action/canary_enumerate.ml` (current). The
   per-artifact **axis product** (provision × version × mutation), PRE-graph. This
   is what drives runs today.

**Status:** the path table is **display-only** — consumed only by `canary paths`
and the diagram, never by a run. It was an early *structural* scenario view;
`enumerate` (axis product) superseded it for the run. But your observation is the
key one: the path table is literally *"a post-graph scenario enumeration with
fixed patterns"* — and each pattern IS a scenario shape (`fetch_lib`,
`fetch_source → build_lib → build_binding`, `bind(build) + rt(build) mismatch`,
…). The **mismatch is a first-class pattern there** (patterns 10/12/13/15/16,
"version mismatch possible") — which the flat `enumerate` can't express.

### Suitability for sqlite / tiny-full

The path table is **universal** (every pattern). To be a *project's* scenarios it
needs one thing — **project-filtering** by the project's real capabilities — and
then the un-grouped `job_path`s (one per node) ARE the runnable scenarios.

- **sqlite — suitable now** (after the source-primary fix). Its capabilities:
  `fetch_source`(git) · `build_lib`(amalgamation) · `fetch_lib`(system PM) ·
  `fetch_binding`(opam OCaml / stdlib Python), and **no `build_binding`** (the
  binding is opam). Filtering the 17 patterns to those leaves ≈6: `fetch_lib`,
  `fetch_source→build_lib`, `fetch_binding`, and the app patterns with a **fetched
  (opam) binding × built/fetched runtime lib** — the last of which IS the deploy
  mismatch (opam binding built against system libsqlite3, run against
  `lib_built@dev`). A clean handful, not 82.
- **tiny-full — needs the `Vendored` node first.** Its artifacts are Vendored
  (source/lib/bindings) plus a `Built` lib (`cc`), and it **fetches nothing**. The
  path table today only models Build/Fetch, so tiny-full's vendored nodes are
  absent — it's suitable once `make_action_graph` gains `Vendored` provisions
  (improvement #2).

**So the path-table approach and the forward-construction engine are the SAME
thing** — `make_action_graph` builds the nodes; the path table flattens+groups
them. Fixing `make_action_graph` (source-primary ✓, + `Build_app` declared
mismatch, + `Vendored`, + project-scoped `~actions`) makes that one construction
serve *both* the universal `paths` table AND the per-project run — and the flat
`enumerate` product becomes the pre-graph degenerate that can retire.
