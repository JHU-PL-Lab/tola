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
- **Remaining (localized, next):** (i) `Build_app` runtime axis = a **declared**
  mismatch for the engine vs the full cartesian `paths` wants — a parameter (the
  `dep_mode`), not a rewrite; (ii) **`Vendored` nodes** (a provision input, for
  tiny); (iii) **project-aware** via the caller passing the *project's* actions +
  providers (not the universal `store_actions`). Then `make_action_graph` IS the
  forward engine: universal for `paths`, project-scoped + declared-mismatch for the
  run, one function.
