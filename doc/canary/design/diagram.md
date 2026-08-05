# Diagram system — pipeline + design ideas

Every `canary action <project>` run writes Mermaid diagrams and an HTML
viewer alongside the step output. This doc covers the big-to-middle
picture: how the diagrams are produced and what design ideas the output
implements. Renderer mechanics (per-parameter behaviour, subgraph
rules) live in module docstrings under [`src/canary/backend/`](../../../src/canary/backend/).

---

## How a diagram run happens

Data flows one direction: the bin layer asks `action/` to build the
step list, then hands the list to `backend/canary_run_info.ml` which
fans out across the sibling backends.

```
  src/bin/canary_main.ml (or projects/canary_run.ml)
        │
        │  Canary_step_builder.derive_steps  (script_spec → step list)
        ▼
  action/canary_step_builder.ml   ← returns step list
        │
        ▼
  src/bin/canary_main.ml          ← now holds the step list
        │
        │  Canary_run_info.run_project ~steps:…
        ▼
  backend/canary_run_info.ml      ← orchestrates the backends
        │
        │  (1) Canary_local_runner.run_graph
        ▼
  backend/canary_local_runner.ml  ← executes each step, returns run_status
        │  returns (run_status : (tag, step_status) Hashtbl.t)
        ▼
  backend/canary_run_info.ml
        │
        │  (2) Canary_diagram.write_project_output
        │        ~steps, ~run_status, ~artifact_names
        ▼
  backend/canary_diagram.ml       ← produces every .mmd in one call
        │  (also calls Canary_html.render for result.html)
        ▼
  -run/diagrams/*.mmd + result.html + index.html
```

`canary_diagram` and `canary_local_runner` are leaf consumers —
they never call back upward. `canary_run_info` orchestrates them as
siblings, fanning out the same `step list` to each backend.

> **Four step-list backends.** Four files in `backend/` each consume
> `step list`, differing only in what they produce:
>
> - [canary_local_runner.ml](../../../src/canary/backend/canary_local_runner.ml)
>   — *executes* the steps' shell commands directly, in-process.
>   Produces `run_status` (and side effects on disk).
> - [canary_gh.ml](../../../src/canary/backend/canary_gh.ml) — emits
>   GitHub Actions YAML.
> - [canary_html.ml](../../../src/canary/backend/canary_html.ml) — renders
>   `result.html`.
> - [canary_diagram.ml](../../../src/canary/backend/canary_diagram.ml) —
>   renders `.mmd` diagram files.
>
> `backend/` also holds three non-rendering siblings:
> [canary_run_info.ml](../../../src/canary/backend/canary_run_info.ml)
> (the run orchestrator), [canary_detect.ml](../../../src/canary/backend/canary_detect.ml)
> (forecast-agnostic outcome classification), and
> [canary_status.ml](../../../src/canary/backend/canary_status.ml)
> (the `canary status` verdict matrix).
>
> Three of them write a file for someone else to consume; the local
> runner does the work itself. The retired yaml-and-shell backend pair
> both emitted files for later execution; `canary_local_runner.ml`
> replaces the shell half with in-process execution.
>
> The shared upstream is [canary_step_builder.ml](../../../src/canary/action/canary_step_builder.ml):
> it owns `script_spec` and `derive_steps`, building the
> `step list` that all four backends consume.

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
    result.html              ← interactive viewer (all diagrams + action list)
    actions.log              ← per-step verdict log
    run_info.json            ← project + env metadata
    run_state.json           ← run verdicts (for view_project re-render)
```

`_out/canary/projects/index.html` at the parent level is regenerated
after every run and links to each project's `result.html`. Web-viewable
files are copied to `docs/canary/projects/<project>/` for GitHub Pages.

---

## The HTML viewer (result.html)

[`Canary_html`](../../../src/canary/backend/canary_html.ml)
emits a single self-contained HTML file per run.

- **Left pane** — view selector tabs + Mermaid block.
- **Right pane** — action list (top) + step detail (bottom).
- **Cross-diagram navigation** — clicking an action list row
  highlights the matching diagram node in the current view and
  lazy-loads the step's output files (`probe.log`, `inspect.json`, …).
  Conversely, clicking a node selects the action list row and loads
  the same files.
- **The viewer is the action list's source of truth** — diagrams
  reflect that list, not the other way around. The truth invariant
  (see above) guarantees that clicking `[5]` in the overview and
  `[5]` in the full diagram select the same row.

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

- **GH CI result integration** — the viewer shows only local results
  today. The intent is to also pull GH CI run results committed back
  to the repo so the same viewer shows local and CI side-by-side.

- **Connectivity-check false positives** — the post-gen invariant
  checker's BFS path-finding misreports some legal routes through
  intermediate artifact nodes. Fixed by the model-first rewrite, or
  by patching the BFS directly.

- **Bundled mermaid.js** — viewer uses the CDN by default; offline
  use needs a `--bundle-mermaid` flag (not yet wired).

Backlog ref: #37 (bundled mermaid.js for offline viewing). Summary-node
fidelity (old #36) shipped — `scan_source` and each `*_inspect` follow-up
now render dedicated nodes.

---

## Where to read next

| Want to know | Read |
|---|---|
| The exact data the renderer consumes | `Canary_step_model.step` ([canary_step_model.ml](../../../src/canary/action/canary_step_model.ml)) |
| Per-renderer parameter list | top of each function in [canary_diagram.ml](../../../src/canary/backend/canary_diagram.ml) — `mermaid_of_action_rule_schema`, `mermaid_full`, `mermaid_view` |
| Why the schema and full renderers differ | [canary_diagram.ml:54+ and :1128+](../../../src/canary/backend/canary_diagram.ml) — the two big blocks |
| How the HTML viewer dispatches clicks | [canary_html.ml](../../../src/canary/backend/canary_html.ml) |
| Status-to-colour mapping | `result_status_of_run` in [canary_diagram.ml](../../../src/canary/backend/canary_diagram.ml) |
