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
