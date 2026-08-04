# Canary dynamic enumeration — artifacts that generate / contain artifacts

> **SSOT** (companion to [`enumeration_graph.md`](enumeration_graph.md)) for the
> model where an artifact is itself a *built result* — a resource **generates**
> or **contains** other artifacts, so `provision` is a per-EDGE provider choice,
> not a flat label. Surfaced 2026-08-04 converging the run onto the enumeration
> algorithm (status §A). The seam is built (`built_from_of_assignment`); the node
> merge (M1–M3) is drafted; A3b/A4 wait on it.

## 1. The model

**Built means "this artifact is *generated* by an action from a *dependency*
artifact"** — it's an edge, not a label. So the enumeration axis is "pick a
**provider** per dependency edge," and some providers pull in more artifacts. Two
shapes of *one resource → many artifacts*:

- **generates** (build edge = `artifact_node.built_from`): source → lib
  (`build_lib`); lib + binding-src → binding (`build_binding`).
- **contains** (a bundle — the one NEW case): one *fetch* yields several artifacts
  (a pip/opam package shipping a binding AND a lib), and the binding may be
  *configurable* to a different lib provider (bundled vs system-PM).

**What strictly needs the graph vs what flat already does (clarified 2026-08-04).**
The criterion: **does canary enumerate TWO instances of one artifact-kind in one
scenario?** If yes → node graph; if one-each → the flat `assignment` suffices.
- **Flat suffices**: sqlite's `{lib=Built, binding=Fetched}` has ONE canary lib; the
  fetched binding's own build-lib is EXTERNAL (opam's, not enumerated) → implicit.
  Its provider choice {system-PM, built} is just the lib's provision across two
  single-lib scenarios. tiny-full is likewise single-instance. So these run on flat
  (`assignments_of_spec`); they don't need the graph.
- **Node graph strictly needed** = a **deploy mismatch** where canary controls BOTH
  the build-lib and a different run-lib in ONE scenario: **old binding × dev-source**,
  and z3/llvm (build a binding against `lib@v1`, run against `lib@v2`). Two lib
  instances → the flat one-slot-per-kind model can't; the graph can (`built_from ≠
  runtime_dep`). **contains/bundle** (one fetch → many artifacts) is the other
  genuinely-new case.

**Static declaration, dynamic closure.** A project declares a **dependency graph**
(artifacts + edges + a per-edge provider universe); the enumerator walks the
closure — a Built node pulls in its source, a Contained node its bundle, a provider
choice branches the world — **postponing** a task until its inputs exist / tracking
readiness via the **cache map**. The runner topo-orders actions; the cache holds
generated artifacts (already how tiny's cached artifacts + `.verdict` markers
work). The enumerated object is the graph, so the deploy mismatch comes for free.

## 2. Inventory — what we HAVE vs what we IMPLEMENT (code map)

Both halves exist, LIVE, but disconnected in code; the merge REUSES them. The only
genuinely new piece is *contains/bundle*.

| Concern | Where (LIVE) | Used for |
|---|---|---|
| node + build/run EDGES + version-mismatch cartesian | `artifact_node` (`base/canary_basic.ml:52`) + `make_action_graph` (`action/canary_action.ml:64`) | `paths` + diagram |
| `ext` + typed `version` + mutation + config + per-artifact provision | `action/canary_enumerate.ml` (placement/assignment/enumerate/run_config) | `scenarios`/`tiny engine` + tests |
| bridge: provision ⇄ producing-action ⇄ edge | `consumes_of_action`/`store_actions` (`canary_action`), `provision_of_actions` (`canary_enumerate:358`) | the seam (§6.5) |
| the RUN's scenarios | hand-built `pr_enumerate` | run (the smell A-track removes) |
| generated-artifact readiness | cached artifacts + `.verdict` markers | run |

`canary_enumerate` has **0 refs** to `artifact_node`/`make_action_graph` — the two
graphs never meet in code. **The unifying fact: provision = which ACTION produces
the artifact; that action's consumed input IS the `built_from` edge** (`Build_lib`
⇒ Built + from=source; `Fetch Lib` ⇒ Fetched + no edge). We *read* edges off the
producing action — no new edge vocabulary. **Done:** `built_from_of_assignment`
(the seam) proves the flat assignment and the action graph are one graph.

**Implement (merge, reuse):** (1) extend `artifact_node` with `ext` + typed
`version` + `provision`; (2) enumerator emits node-graphs, reusing
`make_action_graph`'s edge cartesian; (3) per-edge provider = provision (bridged);
(4) **NEW** contains/bundle.

## 3. The compiler view (runner_spec : graph :: codegen : IR)

```
store_actions + consumes/produces_of_action  =  GRAMMAR (action IR)
the enumeration / node graph                 =  PROGRAM (nodes + edges + realizing actions)
runner_spec                                  =  per-action CODEGEN
derive_steps                                 =  the COMPILER pass → step list
local_runner / gh / diagram / html           =  TARGETS
```

The merge lives in the **IR**; codegen (`runner_spec`) stays keyed on actions (the
stable bridge), so it barely moves — *adaptation, not rewrite*. Duplicate utilities
that collapse when the node lands: version-mismatch (`make_action_graph` cartesian
vs `assignment_ok`), node/placement helpers (`mk_node`/`node_tag` vs
`placement`/`provision_of`), provision derivation (`provision_of_actions` vs the
graph's location choices).

## 4. The `artifact_node` sketch (extend, don't rename)

Flat over the two justified reused identities (`artifact_id`, `build_id`); the
`artifact_info`/`placement` middle layers are dropped.

```ocaml
type artifact_node = {                (* today's artifact_node, extended *)
  id          : artifact_id;          (* {kind; ext}       — the identity pair, kept *)
  version     : build_id;             (* {channel; quality} — typed; Bad tag (A2) *)
  provision   : provision;            (* per-EDGE provider: Fetched|Built|Vendored|Contained(new) *)
  built_from  : artifact_node option; (* Build edge — read via the seam *)
  runtime_dep : artifact_node option; (* Run edge — deploy mismatch *)
}
```

vs today's `{a_kind; a_name; origin; a_location; built_from; runtime_dep}`:
`a_kind`→`id` (+ext); `a_name`-suffix→typed `version` (+quality); `+provision`
(`a_location` derives). The flat `assignment` is the degenerate node set (no edges)
— `assignment_of_point` + `built_from_of_assignment` lift it; `placement` drops
after. Keeping `id = {kind; ext}` as a **pair** means the merge does NOT touch the
coarse-kind `match` sites — see §6.

## 5. First-cut migration (source → lib → binding, one version) — no run change

- **M1.0 — relocate `artifact_node` out of base** (layering fact, 2026-08-04):
  the identity types it must merge with (`artifact_id`/`build_id`/`ext`/`quality`/
  `app_wiring`) all live in the ACTION layer (`canary_enumerate`), and **base never
  uses `artifact_node`** (only its own recursive edges) — its real users are
  `canary_action` + `canary_path_table` (action). So `artifact_node` is action
  vocabulary, not base: move it (+ `mk_node`, `node_tag`) up to the action layer,
  update those 2 users to `Canary_action.artifact_node`. Pure move, byte-identical.
- **M1 — extend `artifact_node`**: `a_kind`→`id` (+ext), `a_name`-suffix→typed
  `version` (+quality), `+provision`; keep `a_name`/`a_location` as DISPLAY fields
  so `node_tag` (and thus `paths`+diagram) stays **byte-identical** — note `a_name`
  conflates project-name + version, so it can't be *replaced* by `version` yet, only
  augmented. (Identity types available in-layer after M1.0.)
- **M2 — `node_of_assignment`**: lift a flat `assignment` to the node graph, edges
  via the seam. Run still consumes assignments (unchanged).
- **M3 — cross-check**: `node_of_assignment` edges == `make_action_graph` edges on
  the chain (upgrades the seam test to node level).
- **then grow** (later, additive): versions→mismatch; app→build/run edge; provision
  breadth (Staged/PM/Contained).

Non-goals: no new `edge` type; don't re-enumerate the mismatch (`make_action_graph`
does — derive); the **~61-site move is a later cleanup, decoupled** — it's folding
the `(kind × ext)` pair into a single enriched `artifact_kind` (~200 coarse-kind
matches, diagram ~61), which the node merge does NOT need (it keeps the pair).

## 6. Open questions

- **contains/bundle:** a `Contained` provision? a package artifact yielding
  sub-artifacts? where does the configurable lib-edge live?
- **provider granularity:** per-edge vs per-artifact (two apps sharing a binding).
- **static vs dynamic deps:** deps are statically declared today (no dynamic
  artifact creation); dynamic ones would need the postpone/tracker machinery.
- **A3b/A4 gate:** build them against this node model, not the flat product. Tiny
  is flat-by-nature (pre-materialized); real projects dynamic-by-nature. Tracked in
  `status.md` §A / §1b.
