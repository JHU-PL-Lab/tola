# Enumeration ↔ action graph — the instance/dependency graph

> **Purpose:** design note for the instance/dependency-graph model (ssot
> §4.2.4). **Its first job is to confirm we don't re-solve a solved
> problem.** The dependency graph with build/run edges and the version
> mismatch cartesian **already exists** in `action/canary_action.ml`. This
> note plans a *convergence*, not a reimplementation.

## 1. Finding — canary already has the instance graph

`Canary_basic.artifact_node` is the instance:

```ocaml
type artifact_node = {
  a_kind      : artifact_kind;
  a_name      : string;
  origin      : location;
  a_location  : location;               (* ← the store location: Build_tree | Staged | Pm *)
  built_from  : artifact_node option;   (* ← the BUILD (create) edge *)
  runtime_dep : artifact_node option;   (* ← the RUN (use) edge *)
}
```

`Canary_action.make_action_graph ~actions ~versions` builds these nodes and
**already generates the version mismatch space**:

```ocaml
| Build_binding lang ->                    (* binding built against a lib *)
    concat_map versions (fun v -> map libs (fun lib -> mk_node (Binding lang) … ~built_from:lib))
| Build_app { lang } ->                    (* app: build vs run lib *)
    concat_map bindings (fun binding -> map libs (fun runtime_lib ->
        mk_node App … ~built_from:binding ~runtime_dep:runtime_lib))
```

`Build_app` pairs each binding with **every** lib as its `runtime_dep` — so
build-lib ≠ run-lib (the **deploy mismatch**) is already enumerated. So is
the binding's build-against-lib. `built_from` = Build edge, `runtime_dep` =
Run edge, `a_location` = location. `Canary_diagram` renders this graph.

**Conclusion: the instance/dependency graph, its build/run edges, and the
version-mismatch cartesian are implemented.** Do **not** build a new one in
`canary_enumerate`.

## 2. Two observations, both confirmed

- **Fold the instance fields into the (extended) artifact.** `artifact_node`
  already *is* the instance — `a_kind` + `a_location` + `built_from` +
  `runtime_dep`. It is missing only what `canary_enumerate` added: `ext`
  (the `(lang × mechanism)` / wiring / header-flavor payload) and a **typed**
  version (today the version is encoded in `a_name = name ^ channel_suffix v`,
  not a `channel` field).
- **Edge ≈ action (a known smell, acceptable).** `built_from` / `runtime_dep`
  are *produced by* actions (`Build_lib`, `Build_binding`, `Build_app`). The
  edge is the action's dependency link; it is **not** a separate `edge`
  vocabulary to invent. `Build` vs `Run` edge ↔ `built_from` vs
  `runtime_dep` ↔ build-action vs probe/run-action. We keep this awareness
  and reuse the action's consumes/produces (§6.5) rather than duplicating.

## 3. The real gap — two representations of one graph

| | `canary_action` (the graph) | `canary_enumerate` (the algorithm) |
|---|---|---|
| node | `artifact_node` (has `a_location`, `built_from`, `runtime_dep`) | `artifact_id` + `placement` (has `ext`, typed `version`) |
| edges | explicit (`built_from`/`runtime_dep`) | implicit (`assignment_ok`) |
| version | in `a_name` (untyped) | typed `channel`, but **per-artifact flat** (no build/run split) |
| mechanism (`ext`) | — | ✓ |
| mismatch | ✓ (Build_app cartesian) | ✗ (flat placement can't) |

They are **the same graph** at different fidelities. The convergence is to
make them **one**: an instance = the extended artifact (kind + `ext`) with a
typed version, a location, and its `built_from`/`runtime_dep` edges —
i.e. `artifact_node` + `ext` + typed `version`. Then the enumeration ranges
over these instance graphs (the action graph *is* the enumerated object),
and the deploy mismatch comes for free (it already does in `make_action_graph`).

Target unified shape (folded into the artifact, per §2):

```ocaml
type instance = {
  id          : artifact_id;              (* kind + ext — enumerate's precision *)
  version     : Canary_basic.channel;     (* typed (today: a_name suffix) *)
  location    : Canary_store.location;    (* = artifact_node.a_location *)
  built_from  : instance option;          (* = artifact_node.built_from  (Build edge) *)
  runtime_dep : instance option;          (* = artifact_node.runtime_dep (Run edge) *)
}
```

This is `artifact_node` with `id`/`ext` and a typed `version` — a merge, not
a new type. (The current flat `assignment`/`placement` is the degenerate
graph: one node per kind, no explicit edges.)

## 4. First cut — full-graph shape, minimal scope

Per the plan: the **correct data structure/algorithm** (the instance graph
above), but a **small graph**:

- **one version** (no mismatch cartesian yet — proves the structure, not the
  breadth),
- **no app** (or a single case) — start with the chain **source → lib →
  binding**,
- reuse / extend `artifact_node` + `make_action_graph` rather than a parallel
  type; add `ext` + typed `version`; keep `built_from`/`runtime_dep` as the
  edges.

Grow by adding versions (the mismatch), then the app (build vs run edge),
then locations (staged / PM — the provision, via `runner_spec` commands).

## 5. Explicit non-goals (don't re-solve)

- **Do not** invent a new `edge` type or a new dependency graph — reuse
  `built_from`/`runtime_dep` and the action's consumes/produces (§6.5).
- **Do not** re-enumerate the mismatch — `make_action_graph`'s
  `bindings × libs` already does; the algorithm should *drive/derive* it,
  not duplicate it.
- The open work is the **merge** (one instance type: `artifact_node` + `ext`
  + typed version) and connecting the enumeration `config`/levels on top of
  the existing graph — not a fresh graph.

## 6. The merge — shared base definitions (info vs structure)

The artifact vocabulary is scattered across parallel types; several carry
**info** (metadata), a few carry **structure** (graph/edges). "Merge" =
define it **once in `base`**, split cleanly, and have enumerate / action /
step all consume it.

| type | file | info / structure | status |
|---|---|---|---|
| `artifact_kind` | base | info (kind) | live |
| `artifact_ext` (mechanism/wiring) | **enumerate** | info (payload) | live — *move to base* |
| `channel` / `version` | base | info (version) | live |
| `location`, `provision` | store | info (where / folds into location) | live |
| `artifact_id` = {kind; ext} | enumerate | info (composite) | live |
| `placement` = {provision; version} | enumerate | info (composite) | live |
| `artifact_node` = {a_kind; a_name; a_location; built_from; runtime_dep} | base | **structure** (node + edges) | live |
| `step` = {…; deps : string list; …} | step_model | **structure** (string-tag edges) | live |
| `artifact_status` | store | info (lifecycle) | unused (intentional) |
| `artifact`, `step_body`, `cmdline` | base | structure | **legacy** (step_body cascade → canary_toolchain) |

**Target base definitions:**

```ocaml
(* base — INFO: all of an instance's metadata (subsumes artifact_id +
   placement; artifact_ext moves here) *)
type artifact_info = {
  kind     : artifact_kind;
  ext      : artifact_ext;          (* mechanism / wiring / header-flavor *)
  version  : channel;               (* typed *)
  location : location;              (* provision folds in *)
}

(* base — STRUCTURE: the graph node = info + dependency edges *)
type artifact_node = {
  info        : artifact_info;
  built_from  : artifact_node option;   (* Build edge *)
  runtime_dep : artifact_node option;   (* Run edge *)
}
```

Then: `canary_enumerate` uses `artifact_info` (its `artifact_id` + `placement`
*are* it); `canary_action`'s node = `info + edges` (gains `ext` + typed
version, drops the untyped `a_name` version-encoding); `canary_step_model`'s
string `deps` reconciles to **typed node refs** (Q1: the runner and the
diagram then share one dependency relation instead of two).

**Two dependency-structure representations to reconcile (Q1):**
`artifact_node`'s typed `built_from`/`runtime_dep` (diagram) vs `step.deps :
string list` (runner). The typed node graph should be the source; the step
references nodes. (`built_from`/`runtime_dep` ≈ the build/run *action* — the
known edge≈action smell; reuse consumes/produces §6.5.)

**Legacy to sweep** (deferred — a cascade, not a clean pair): `artifact` +
`step_body` + `cmdline` + base `run_step`/`mk_system_dep_steps` +
`canary_toolchain`'s dead verify helpers. (`artifact_op`, dead base
`runner_spec` already removed, `9f656dd`.)

**Do this merge only when the shapes are confirmed** (then fold the graph
into one ssot section + a CLAUDE.md "the artifact graph lives in base; don't
reinvent" note — Q2).
