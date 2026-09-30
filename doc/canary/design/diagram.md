# Diagram system — pipeline + design ideas

**Kind: rationale.** What the diagram pipeline produces today.

Every `canary action <project>` run writes Mermaid diagrams alongside
the step output. (Until 2026-09-28 it also wrote an HTML viewer showing
them beside the step list; that per-run page retired with the result
matrix's, and a run is read on the overview page —
[`overview.md`](overview.md) §6.4.) This doc covers the big-to-middle
picture: how the diagrams are produced and what design ideas the output
implements. Renderer mechanics (per-parameter behaviour, subgraph
rules) live in module docstrings under [`src/canary/backend/`](../../../src/canary/backend/).

---

## How a diagram run happens

Data flows one direction: the bin layer asks `action/` to build the
step list, then hands the list to `backend/canary_run_info.ml` which
fans out across the sibling backends. In order:
`Canary_step_builder.derive_steps` returns the step list;
`Canary_run_info.run_project ~steps` runs it with
`Canary_local_runner.run_graph`, which returns each step's status
(`run_status : (tag, step_status) Hashtbl.t`); then
`Canary_diagram.write_project_output ~steps ~run_status ~artifact_names`
writes every `.mmd` under `-run/diagrams/` in one call. Where this sits
in the whole flow, from canary's code to the overview page, is drawn in
§5 of that page (`canary overview --flow` prints it).

`canary_diagram` and `canary_local_runner` are leaf consumers —
they never call back upward. `canary_run_info` orchestrates them as
siblings, fanning out the same `step list` to each backend.

> **Three step-list backends.** Three files in `backend/` each consume
> `step list`, differing only in what they produce:
>
> - [canary_local_runner.ml](../../../src/canary/backend/canary_local_runner.ml)
>   — *executes* the steps' shell commands directly, in-process.
>   Produces `run_status` (and side effects on disk).
> - [canary_gh.ml](../../../src/canary/backend/canary_gh.ml) — emits
>   GitHub Actions YAML.
> - [canary_diagram.ml](../../../src/canary/backend/canary_diagram.ml) —
>   renders `.mmd` diagram files.
>
> A fourth, `canary_html.ml`, rendered the per-run `result.html` and
> retired with it on 2026-09-28.
>
> `backend/` also holds three non-rendering siblings:
> [canary_run_info.ml](../../../src/canary/backend/canary_run_info.ml)
> (the run orchestrator), [canary_detect.ml](../../../src/canary/backend/canary_detect.ml)
> (forecast-agnostic outcome classification), and
> [canary_status.ml](../../../src/canary/backend/canary_status.ml)
> (the `canary status` verdict matrix).
>
> Two of them write a file for someone else to consume; the local
> runner does the work itself. The retired yaml-and-shell backend pair
> both emitted files for later execution; `canary_local_runner.ml`
> replaces the shell half with in-process execution.
>
> The shared upstream is [canary_step_builder.ml](../../../src/canary/action/canary_step_builder.ml):
> it owns `script_spec` and `derive_steps`, building the
> `step list` that all three backends consume.

The single translator between layers is `result_status_of_run`
([canary_diagram.ml](../../../src/canary/backend/canary_diagram.ml)),
which maps step verdicts (`Step_done` / `Step_failed` / `Step_skipped`,
from action/) to node verdicts (`Done` / `Done_fail` / `Failed` /
`Skipped` / `Not_in_spec`, used for colour). It lives in `canary_diagram`
because `Done_fail` (an expected-failure step that succeeded as
planned) is a diagram-only colour — the runner doesn't distinguish it
from `Done`.

**Adding a new view** = add a view predicate + render call inside
`write_project_output`. No changes needed in action/.

---

## Design ideas

### The min–max spectrum

All diagrams from one run show the **same set of truth** — the same
steps, the same verdicts. They differ only in how much merging the
renderer applies. Three altitudes:

```
overview (all.mmd)        focused views (lib.mmd, …)        full.mmd
      ↑ min                       ↑ middle                  ↑ max
  compact, workflow          scoped to one artifact      every step,
  and pattern level          kind, good for audit        nothing merged
```

- **Overview** — the most compact. One node per rule; every artifact
  kind is one pool node. Fetch step IDs embedded in artifact labels
  (`lib [1]`). Good for showing *which action patterns* will run and
  catching missing ones.
- **Focused views** — intermediate. Scoped to one artifact kind
  (lib, binding OCaml, …). The focal kind expands into per-variant
  nodes; other kinds stay collapsed at overview altitude. Good for
  auditing one pipeline stage without losing the surrounding shape.
- **Full** — every concrete step is a node, every artifact split
  into input + product subgraphs. Unambiguous about what was tested.

The progression mirrors how people actually read these: start
overview to confirm "we're running the right patterns", drop to a
focused view to audit one column, fall to full only when chasing a
specific concrete step.

### The truth invariant

An action ID `[N]` in any diagram refers to **the same step** as `[N]`
in any other diagram for the same run. No diagram introduces or hides
steps; it only changes the merging level.

This is enforced post-generation: after every diagram is written, an
invariant checker scans every `.mmd` for `[N]` references and verifies
the union equals the full step set from `step_ids`. Mismatches log a
warning in `actions.log` (`! invariant: missing step IDs [N]`). The
check exists because a parameter mistake in a renderer can quietly
drop a step from one view, and you'd never notice if the diagram
still "looks right".

### Schema renderer vs step renderer

Two renderers, one model:

| Renderer | Used by | Drives nodes from | Strength |
|---|---|---|---|
| `mermaid_of_action_rule_schema` | overview, all focused views | `Canary_action.store_rules ~langs` + expansion params | predictable shape; non-focal kinds look the same across views |
| `mermaid_full` (a.k.a. step renderer) | `full.mmd` only | concrete `step list` | every step gets its own node + subgraph; nothing is hidden |

The schema renderer is the workhorse — overview and focused views
share its core, differing only in which kinds are expanded. The step
renderer exists to give one diagram where the IDs match concrete file
paths. A "model-first" refactor that unifies them into one
intermediate model + format-emitter would remove ~1100 LOC of
duplication; see *Open work* below.

---

## Output layout

```
_out/canary/projects/<project>/
  <step_tag>/                ← step output dirs (probe.log, inspect.json, …)
  -run/
    diagrams/
      all.mmd                ← overview (min altitude)
      full.mmd               ← every step (max altitude)
      source.mmd             ← if scan_source ran
      lib.mmd
      probes.mmd
      binding_ocaml.mmd
      binding_python.mmd     ← one per binding language
    manifest/<world>.json    ← the steps the runner realized for each world
    actions.log              ← per-step verdict log
    run_info.json            ← project + env metadata
    run_state.json           ← run verdicts (for view_project re-render)
```

None of it is copied to `docs/`. Until 2026-09-28 each run also wrote a
`result.html` viewer (the diagrams beside the step list) and refreshed a
run index at `_out/canary/projects/index.html`, and its web-viewable
files were copied to `docs/canary/projects/<project>/` for GitHub Pages
— 1,797 tracked files by the time the copy went. A run is read on the
overview page now (`docs/canary/overview.html`, §1 and §1.2), from the
record and the manifest; `canary view <project>` still regenerates a
run's diagrams from `run_state.json` — except where that file holds an
action `action_of_string` cannot read, which today is zarith's
(`overview.md` §6.4, the follow-ups).

---

## Open work

Each item is tracked elsewhere; this section is the diagram-side index.

- **Model-first renderer architecture** —
  `mermaid_of_action_rule_schema` (~630 LOC) and `mermaid_full`
  (~450 LOC) emit Mermaid text directly. Replacing both with a
  format-agnostic `diagram_model` + a thin `mermaid_of_model` would
  remove the duplicated node/edge/style logic and let the invariant
  checker operate on the model rather than parsing `.mmd` output.
  Largest single readability win available for backend/.

- **PM-fetched version annotation** — `mermaid_full` currently
  annotates build-tree / staged / packed-PM artifacts with the run
  version, but leaves PM-fetched artifacts (apt, opam, pip via fetch)
  unannotated because the *actual installed version* isn't recorded.
  Fixing requires each fetch step's script to write a `version.txt`.

- **GH CI result integration** — the overview page draws only local
  runs today (one runs file per machine). The intent is to also pull GH
  CI run results committed back to the repo, so the same page shows
  local and CI runs side by side.

- **Connectivity-check false positives** — the post-gen invariant
  checker's BFS path-finding misreports some legal routes through
  intermediate artifact nodes. Fixed by the model-first rewrite, or
  by patching the BFS directly.

Summary-node fidelity (old #36) shipped — `scan_source` and each
`*_inspect` follow-up now render dedicated nodes. Bundling mermaid.js for
offline viewing (old #37) went with the viewer that loaded it.

---

## Where to read next

| Want to know | Read |
|---|---|
| The exact data the renderer consumes | `Canary_step_model.step` ([canary_step_model.ml](../../../src/canary/action/canary_step_model.ml)) |
| Per-renderer parameter list | top of each function in [canary_diagram.ml](../../../src/canary/backend/canary_diagram.ml) — `mermaid_of_action_rule_schema`, `mermaid_full`, `mermaid_view` |
| Why the schema and full renderers differ | [canary_diagram.ml:54+ and :1128+](../../../src/canary/backend/canary_diagram.ml) — the two big blocks |
| Status-to-colour mapping | `result_status_of_run` in [canary_diagram.ml](../../../src/canary/backend/canary_diagram.ml) |
