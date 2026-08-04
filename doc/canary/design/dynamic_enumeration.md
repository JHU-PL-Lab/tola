# Canary dynamic enumeration — artifacts that generate / contain artifacts

> **Purpose:** design note (companion to
> [`enumeration_graph.md`](enumeration_graph.md)) for the model where an
> artifact is itself a *built result* — a resource **generates** or **contains**
> other artifacts. Surfaced 2026-08-04 while converging the run onto the
> enumeration algorithm (status §A, A3a): the flat per-artifact `provision`
> product is an entry-level view; the real object is a **dependency graph with a
> provider choice per edge**. This note is the SSOT for that model + the
> `project_spec` shape it implies. Nothing here is built yet — A3b/A4 wait on it.

## 1. The insight — `provision` is a per-edge provider, not a flat label

"Provision" reads like a scalar tag on an artifact (Fetched / Built / Vendored).
But **Built means "this artifact is *generated* by an action from a *dependency*
artifact"** — it is an edge, not a label. So the enumeration axis isn't "pick a
provision per artifact independently"; it's "pick a **provider** for each
dependency edge," and some providers pull in more artifacts.

Two shapes of *one resource → many artifacts*:

- **GENERATES** (a build edge — already `artifact_node.built_from`): a source
  generates a lib (`build_lib`); a lib + binding-source generate a built binding
  (`build_binding`). The dependency is the edge; the cache holds the result.
- **CONTAINS** (a bundle — new here): one *fetch* yields several artifacts — a
  pip/opam package that ships **both** a binding **and** a lib; and the binding
  may be *configurable* to use a different lib provider (the package's own bundled
  lib, or a system-PM lib). One provision, multiple artifacts / a provider choice
  on the binding's lib-edge.

## 2. Motivating cases (from the 2026-08-04 discussion)

- **Old binding × dev-version source.** The dev source builds a new lib (and dev
  libs get published readily); the *old* binding deployed against the *new* lib is
  the deploy mismatch — `built_from` (binding's build lib) ≠ `runtime_dep` (run
  lib). Already enumerated by `make_action_graph`'s `Build_app` cartesian.
- **Bundled binding + configurable lib.** A pip/opam package contains a binding
  AND a lib, but the binding can be pointed at a **system-PM** lib instead. The
  binding's lib-edge has a **provider choice** {bundled-lib, system-lib} — two
  valid worlds from one declared package.
- **sqlite (the case that surfaced this).** Its Built lib is generated from the
  amalgamation *source* (`built_from = source`); the OCaml/Python binding's
  lib-edge can be {system-PM lib (Fetched), the built lib}. My A3a "make the
  Built-lib source requirement conditional" is really "the `built_from` edge is
  present only when source is a declared dependency." The provision-coupling I
  flagged **is the edge**, not a hack.

## 3. What already exists — don't re-solve

- **The instance graph** (`Canary_basic.artifact_node` + `make_action_graph`)
  already has `built_from` (build edge), `runtime_dep` (run edge), `a_location`,
  and enumerates the version-mismatch cartesian. See
  [`enumeration_graph.md`](enumeration_graph.md).
- **z3/llvm** already hit "an artifact is built from another," and the current
  solution is to **enforce step-execution order**. Ideally **action ≈ artifact**:
  an action *produces* an artifact the cache holds, and ordering is topological
  over the dependency graph — the cache map is the tracker.
- **The flat work (A1/A2/A3a)** is the **degenerate view** of this graph: nodes =
  `(artifact_id × placement)`, edges *implicit* in `assignment_ok`. Not wasted —
  it is the entry rung and the `point → assignment` fold still applies — but the
  target is the explicit graph.

## 4. The model

- **Static declaration.** A project declares a **dependency graph**: artifacts +
  edges (binding → lib, lib → source, app → binding × runtime-lib) + a
  **per-edge provider universe** (Fetched from a PM / Built from a dependency /
  Vendored / **Contained** in a bundle). This is the real `project_spec` — not a
  flat `provisions_of`.
- **Dynamic enumeration.** Walk the graph closure: a Built node pulls in its
  source dependency (expand); a Contained node is provided by its bundle; a
  provider choice on an edge branches the world. The "smarter" part is graph
  traversal — **postpone** a task until its inputs exist, or track readiness with
  a **cache map** — so the closure completes. The runner topo-orders the actions;
  the artifact cache holds generated artifacts (already how tiny's cached
  artifacts + the `.verdict` markers work).
- **Enumerated object = the instance graph**, not a flat assignment. The deploy
  mismatch then "comes for free" (it already does in `make_action_graph`).

## 5. What it lands

- **sqlite (A3b):** Built lib `built_from = source(amalgamation)`; binding lib-edge
  provider ∈ {system-PM, built-lib}. Flipping the run = walk this graph, not a
  flat product; the binding-over-built-lib scenario is a provider choice, not an
  ad-hoc coupling (= coverage-C).
- **tiny (A4):** combinations (multi-bad) = several mutated nodes in the graph.
  Multi-mutation is natural once the enumerated object is the graph rather than a
  single-`option` `point.mutation`.
- **project_spec evolution:** `provisions_of` (A3a) → declare the dependency graph
  + per-edge providers. `assignments_of_spec` becomes "enumerate the instance
  graphs," merging with `enumeration_graph.md`'s target `instance` type
  (`artifact_node` + `ext` + typed `version`).

## 6. Open questions

- **Contained / bundle:** how to represent "one fetch → many artifacts" — a
  `Contained` provision? a package artifact that yields sub-artifacts? where does
  the binding's configurable lib-edge live?
- **Provider choice granularity:** per-edge vs per-artifact (two apps sharing one
  binding may want the same or different runtime lib).
- **Static vs dynamic dependencies:** the note assumes deps are *statically*
  declared (true today — no dynamic artifact creation). If usage ever computes a
  dependency at run time, the enumeration needs the postpone/tracker machinery to
  stay closed.
- **Merge point:** fold `project_spec` (§4) + `enumeration_graph.md`'s `instance`
  into one type; retire the flat `assignment` product as the degenerate case.

## 7. Inventory — what we HAVE vs what we IMPLEMENT (code map, 2026-08-04)

We already have **both halves** of the graph model, LIVE — but disconnected in
code. The merge REUSES them; the only genuinely new piece is *contains/bundle*.

| Concern | Where (LIVE) | Used for |
|---|---|---|
| instance node + build/run EDGES + version-mismatch cartesian | `artifact_node` (`base/canary_basic.ml:52`) + `make_action_graph` (`action/canary_action.ml:64`) | `paths` table + diagram (DISPLAY) |
| `ext` (mechanism/wiring) + typed `version` + mutation + config + per-artifact provision | `action/canary_enumerate.ml` (placement / assignment / enumerate / run_config) | `scenarios` / `tiny engine` + tests (DISPLAY) |
| bridge: provision ⇄ producing-action ⇄ edge | `store_actions` / `consumes_of_action` / `produces_of_action` (`canary_action.ml`), `provision_of_actions` (`canary_enumerate.ml:358`) | the seam (§6.5) |
| the RUN's scenarios | hand-built `pr_enumerate` closures | run (the smell the A-track removes) |
| generated-artifact readiness / cache | cached artifacts + `.verdict` markers | run |

**`canary_enumerate` has 0 references to `artifact_node`/`make_action_graph`** —
the two graphs never meet in code (confirms enumeration_graph.md §3).

**The unifying fact (no new edges to invent): provision = which ACTION produces
the artifact; that action's consumed input IS the `built_from` edge.** `Build_lib`
⇒ Built + built_from=source; `Fetch Lib` ⇒ Fetched + no build edge. So provision
(enumerate) and `built_from` (action graph) are one thing seen twice, bridged by
the §6.5 action catalogue — we *read* edges off the producing action, not invent
them.

**Implement (merge, reuse):**
1. one `instance` = `artifact_node` (kind + edges + location) + `ext` + typed
   `version` (enumeration_graph.md's target type);
2. enumerator emits instance-**graphs** — reuse `make_action_graph`'s
   Build_binding/Build_app edge cartesian; the provision axis picks the producing
   action per artifact;
3. per-edge provider = the provision (already bridged);
4. **NEW:** contains/bundle (one fetch → many artifacts).

**Proposed first step (minimal, no reinvention):** a pure `edges_of_assignment`
that reads a flat `assignment`'s `built_from`/`runtime_dep` off the action
catalogue (`consumes_of_action` / `provision_of_actions`), with a `project-test`
cross-checking it against `make_action_graph` on a shared example. This connects
the two representations WITHOUT the big `instance`-type merge (the ~61-site
change enumeration_graph.md flags as last), and is the seam the full merge builds
on.

## 7b. The compiler view (runner_spec : graph :: codegen : IR)

The `runner_spec` relates to the graph like **codegen to an IR** — a clarifying
frame (2026-08-04):

```
store_actions + consumes_of_action / produces_of_action  =  GRAMMAR (action IR — what each action eats/makes)
the enumeration / instance graph                         =  PROGRAM (instances + edges + realizing actions)
runner_spec                                              =  per-action CODEGEN (this project's shell per action)
derive_steps                                             =  the COMPILER pass (grammar + program + codegen → step list)
local_runner / gh / diagram / html                       =  TARGETS (execute / CI YAML / render)
```

Consequence for the merge: it lives in the **IR** (fold the two graph
representations into one `instance`). Codegen (`runner_spec`) stays keyed on
**actions**, the stable bridge — so unifying the IR barely touches it. This is
why the graph-model work is *adaptation*, not a rewrite, and why the flat
A1/A2/A3a work (the degenerate IR view) is reused, not discarded.

Auxiliary utilities that DUPLICATE across the two halves — merge candidates when
the `instance` type lands: version-mismatch (`make_action_graph` Build_app
cartesian vs `assignment_ok`'s filter); node/placement helpers (`mk_node` /
`node_tag` vs `placement` / `provision_of`); provision derivation
(`provision_of_actions` vs the action graph's location choices).

## 8. Status

A3b (flip sqlite's run) and A4 (wire tiny + multi-mutation) **wait on this design
settling** — they should be built against the graph model, not the flat product.
A1/A2/A3a stand as the entry rung. Tiny is flat/static *by nature* (it
pre-materializes every cached artifact); real projects are dynamic *by nature*
(they generate on demand) — the flat model fit tiny and breaks on sqlite, which
is why the graph model is a real-project need. Tracked in `status.md` §A / §1b.
