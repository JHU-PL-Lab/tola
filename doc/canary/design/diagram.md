# Diagram system

Canary generates Mermaid diagrams and an HTML viewer per run.
Backlog refs: #36 (summary node fidelity), #37 (HTML viewer).

---

## Purpose and design philosophy

The diagram series exists to make all concrete canary actions visible and
discussable. The same run produces diagrams at different levels of detail,
but they all represent the **same set of truth** — the same steps, the same
results. Action IDs (`[N]` labels) are the cross-diagram reference that lets
you verify a node in one diagram corresponds to the same action in another.

### The min–max spectrum

```
overview (all.mmd)          focused views (lib.mmd, …)          full.mmd
      ↑ min                         ↑ middle                    ↑ max
  compact, workflow            scoped to one artifact        all steps,
  and pattern level            kind, good for audit          nothing merged
```

- **Overview** — the most compact representation. Shows which *action
  patterns* will run (e.g. "we probe the lib from three sources"). Good for
  communicating the workflow and catching missing patterns. One node per rule;
  fetch step IDs embedded in artifact labels.

- **Focused views** — intermediate. Scoped to one artifact kind (lib, binding
  OCaml, …). Expands the focal artifact into per-variant nodes; keeps other
  kinds merged for context. Good for auditing one pipeline stage without losing
  the surrounding structure.

- **Full** — the most detailed representation. Every step is an individual
  node. Artifacts are split into input subgraphs (PM-fetched + build-tree) and
  product subgraphs (install/pack output). Artifact nodes carry version
  annotations where the run version is meaningful (build_tree, staged, packed
  PM). Stores appear as cylinder nodes upstream of fetch actions.

The goal of this spectrum: overview is good for ideas and workflow discussion;
full is unambiguous about what concrete things are being tested. The focused
views are the working diagrams in between.

### The truth invariant

All diagrams in a run show the same underlying step set. No diagram introduces
or hides steps — it only changes the level of node merging. An action ID `[N]`
in any diagram refers to the same step as `[N]` in any other diagram for the
same run. This makes diagrams comparable and the viewer's action list the
single source of truth.

This invariant is enforced by a **post-generation checker** that runs after all
diagrams are written. It scans every `.mmd` file for `[N]` references and
verifies the union equals the full step set from `step_ids`. A mismatch logs a
warning (`! invariant: missing step IDs [N]`) in `actions.log`. This catches
regressions where a renderer parameter change accidentally drops a step from a
view.

---

## Output layout

Every `canary action <project>` run writes:

```
_out/canary/projects/<project>/-run/
  diagrams/
    all.mmd             ← overview (min)
    full.mmd            ← full expanded (max)
    source.mmd          (if scan_source ran)
    lib.mmd
    probes.mmd
    binding_ocaml.mmd
    binding_python.mmd  (one per language)
  result.html           ← interactive HTML viewer (all views + action list)
  actions.log
  run_info.json
  run_state.json
```

Step output directories sit one level up at `_out/canary/projects/<project>/`.
`_out/canary/projects/index.html` is a top-level index across all runs.

---

## Overview diagram (`all.mmd`)

Uses the schema renderer with all expansion parameters at their defaults.
Every artifact kind is one node; every probe rule is one collapsed node.

- **Artifact pool nodes** (docs shape, orange) — one per kind. Fetch step
  IDs embedded in the label (`lib [1]`); multiple fetch variants combined
  (`lib [1][6]`).
- **Action nodes** — hexagons for build/install/pack, pills for probes and
  follow-up steps.
- **Combined probe labels** — `probe_lib [17][18][19][20][21][22]` shows all
  concrete step IDs for a rule via `steps_by_rule_tag`, with summary IDs
  inlined via `summary_tags_by_canonical`. Likewise, `pack_binding_ocaml
  [9][10][11]` inlines both pack and summary IDs. Summary inlining applies
  when a probe/pack/fetch kind is not expanded; separate summary pills only
  appear in views where the parent kind is expanded (lib, probes, binding_*).
- **Status colours** — green (done), yellow (expected-fail), red (failed),
  grey-dashed (skipped), light grey (not-in-spec).
- **Edge colours** — match the downstream step status.

---

## Full diagram (`full.mmd`)

Step-level renderer (`mermaid_full` in `canary_diagram.ml`). Every step is an
individual node; nothing is merged.

### Artifact subgraphs

Each artifact kind gets one or two subgraphs depending on whether the run
produces a new artifact of that kind:

| Kind | Input subgraph | Product subgraph |
|---|---|---|
| Lib (build + install) | `lib` — contains `lib (build_tree)` + `lib (apt)` | `lib (product)` — contains `lib (staged)` |
| Binding (build + pack) | `ocaml binding` — `ocaml binding (build_tree)` | `ocaml binding (packed)` — `ocaml binding (opam)` |
| Lib / Binding (fetch only) | single subgraph | — |
| Source, Headers, App | single subgraph | — |

**Input subgraph** = artifacts brought in from outside (PM-fetched) or built
from source but not yet installed/packed.

**Product subgraph** = artifacts produced by the canary run itself:
`install_lib` → staged, `pack_binding` → packed PM artifact.

### Version annotation

Artifact nodes carry a version suffix where the run-level version is
meaningful. Version strings come from `run_info.json` (each variant's
`version` field, e.g. `"dev"` or `"4.15.2"`).

| Variant | Annotated? | Reason |
|---|---|---|
| `build_tree` | ✓ | built from the spec's source version |
| `staged` | ✓ | installed from the same source build |
| packed PM (opam/pip) | ✓ | packed from the same source build |
| PM-fetched (apt, opam, pip via fetch) | — | run version ≠ package version; actual package version needs a fetch-step write (future work) |

### Store nodes

Package manager sources appear as cylinder nodes (`@{ shape: cyl }`) upstream
of their fetch action: `apt_store`, `opam_store`, `pip_store`, `git_store`.
One store node per unique PM across all fetch steps.

### Scan + configure chain

When `scan_source` ran, the Full diagram chains it: `source_node -.-> A_scan_source --> A_configure`. The dashed edge marks scan as an annotation step (no gate); the solid edge into configure makes the dependency explicit.

---

## Focused views (per-kind diagrams)

Each view is generated by `mermaid_view` in `canary_diagram.ml`. All focused
views use the **schema renderer** (`mermaid_of_action_rule_schema`), not the
step renderer. The schema renderer gives every non-expanded kind a pool node
by default; focal expansion parameters control what gets split out.

### Design invariant: non-focal nodes look like the overview

A binding-focused view must be composable with the overview: any non-focal
artifact kind in `binding_ocaml.mmd` renders identically to the same node in
`all.mmd`. Concretely:

- Non-focal pool nodes use `docs` shape and the same label (including embedded
  `[N]` IDs) as the overview.
- Non-focal probe kinds stay as one collapsed pill with combined IDs — never
  split into per-variant pills.
- There are no subgraphs for non-focal kinds.

This means a reader can mentally overlay a focused view on the overview without
any translation: the focal artifact is the only thing that looks different.

### `steps_by_rule_tag` variant for binding views

Binding views use `steps_by_rule_tag_overview` (scan included in the
`fetch_source` bucket) instead of `steps_by_rule_tag`. This gives the source
pool node the label `source [1][2]` — matching the overview — rather than
`source [1]` with a separate `scan_source [2]` hexagon. The binding focus is
on the binding, not on source scanning; source stays as a pool node.

### Focal probe expansion — `expand_probe_kinds`

Each view expands only its own probe kind; others stay collapsed:

| View | Expanded probe kind | Collapsed (combined ID) |
|---|---|---|
| `lib` | `Probe Lib` | all binding/app probes |
| `binding_ocaml` | `Probe (Binding OCaml)` | lib, python, app probes |
| `binding_python` | `Probe (Binding Python)` | lib, ocaml, app probes |
| `probes` | all probe kinds | — |
| `source` | none | all probes |

The `pack` view is currently hidden (the pack pipeline is not yet a priority
view; was removed to keep the tab count manageable).

### Focal artifact expansion — `expand_artifact` and subgraphs

Only `lib` and `binding_*` views expand their artifact node into per-variant
nodes, wrapped in subgraph(s) that mirror the `full` diagram structure. Each
per-variant node label embeds the **producer step's `[N]` ID** —
`build_lib [5]` → `libz3.so (dev) [5]`, `fetch_lib [7]` → `libz3.so (4.15.2) [7]`,
`pack_binding_ocaml [9]` → `z3 (dev) [9]`. This is computed by
`_compute_expand` in `canary_diagram.ml`, which maps each variant to its
producer step (build → build_tag, staged → install_lib, pack PM → pack step,
fetch PM → fetch step). The `focal_predicate` colours focal steps solid green
(`st_done`) and non-focal done steps dim green (`st_done_ctx`).

### Subgraph structure for expanded kinds

The schema renderer mirrors `mermaid_full`'s split when the expanded kind has
a "product" variant (output of `install_lib` or `pack_binding`):

| Kind | Input subgraph | Product subgraph |
|---|---|---|
| Lib (with `Install_lib` in rules) | `lib` — build_tree + PM-fetched variants | `lib (product)` — staged |
| Binding OCaml (with `Publish` in rules) | `ocaml binding` — build_tree | `ocaml binding (opam)` — opam |
| Binding Python (with `Publish` in rules) | `python binding` — build_tree | `python binding (pip)` — pip |
| Any kind with no pack/install | single `<kind>_sg` subgraph | — |

Product variant detection is rule-based (not heuristic): `Install_lib ∈ rules`
→ "staged" for Lib; `Publish (Binding OCaml) ∈ rules` → "opam"; etc. This
avoids the mis-classification that occurs when a PM-fetched variant (apt) is
confused for a pack product just because it's not "build_tree" or "staged".

---

## result.html — interactive viewer

`canary_backend_html.ml` generates a self-contained HTML page per run.

### Layout

- **Left pane** — view selector tabs + Mermaid diagram block.
- **Right pane** — action list (top) + step detail (bottom).

### View selector

Tabs: Overview, Full, Source (if ran), Lib, Probes, Binding (OCaml),
Binding (Python). Clicking re-renders the Mermaid block without a page
reload; the action list updates to reflect which steps have nodes in the
new view (steps not in the current diagram are dimmed).

### Action list

Sorted by sequential step ID (1-based, execution order). Each row shows:

```
[N]  step_tag    STATUS-BADGE
```

Steps not present as nodes in the current diagram view are dimmed (0.3
opacity). Clicking a row:
1. Selects the row (blue highlight).
2. Highlights the corresponding diagram node with a drop-shadow ring.
3. Loads the step's output files in the detail panel (probe.log,
   inspect.json, etc.) via relative fetch.

### Diagram node clicks

Clicking an `A_<tag>` node in the diagram selects the matching action list
row and loads the step detail. Collapsed overview nodes (e.g. `A_probe_lib`
representing three concrete steps) resolve to the first matching step tag
in the action list via `STEPS[t] || STEPS.find(k => k.startsWith(t+'_'))`.

### Step detail

Lazily fetches files from the step's output directory (relative to `-run/`):
`probe.log`, `inspect.json`, `summary_stub.json`, `install.log`,
`symbols.log` — all variant-qualified (`probe_dev_1d8c50.log`).

---

## index.html — top-level index

`_out/canary/projects/index.html` is regenerated after every run. Lists all
(project, variant) runs as a table with project / variant / source kind /
overall status badge / link to `result.html`.

---

## Future direction

- **GH CI integration** — the web viewer currently shows only local run
  results. The intent is to also fetch GH CI run results that are written back
  to the repo (e.g. as JSON artifacts committed to a branch). This lets the
  same viewer show local and CI results side by side, using the same diagram
  and action-list infrastructure.

- **Version annotation for PM-fetched artifacts** — currently unannotated.
  Requires each fetch step script to write a `version.txt` (e.g.
  `dpkg-query -W libz3-dev | cut -f2`) so `mermaid_full` can read it.

- **Bidirectional diagram highlight** — clicking an action list row sets a
  drop-shadow on the diagram node, but `filter` on SVG `g` elements is not
  reliably visible in all renderers. Needs investigation.

- **Bundled mermaid.js** — CDN is the current default; offline use
  requires an explicit `--bundle-mermaid` flag (not yet implemented).

- **Non-focal artifact expansion in non-lib focused views** — in the
  `probes` view, `probe_lib_staged` routes to the merged `lib_node` rather
  than a split `lib_staged_node`; the per-variant routing is only wired for
  the focal artifact kind in `lib`/`binding_*` views.

- **Model-first diagram architecture** — currently `mermaid_of_action_rule_schema`
  (~630 lines) and `mermaid_full` (~450 lines) are two independent renderers that
  both emit Mermaid text directly from rules/steps. They duplicate node emission,
  edge routing, CSS styling, and status mapping. A model-first approach would:

  1. Define a `diagram_model` type: nodes (with associated `[N]` IDs), edges,
     styling — format-agnostic.
  2. Build the fully-expanded model from rules + step data.
  3. Apply merge/unmerge as operations on the model: collapse a kind into a pool
     node, expand a kind into per-variant nodes, inline summaries. These are the
     "zoom" operations that produce overview/focused/full views from one model.
  4. Render with a thin `mermaid_of_model` walk over the model.

  This eliminates the ~1100-line duplication and makes the zoom logic explicit
  and testable. The invariant checker (see §Truth invariant) would operate
  directly on the model rather than parsing rendered `.mmd` output.

- **Invariant checker improvements** — the current checker verifies coverage
  (all `[N]` appear) and connectivity (dependencies preserved across zoom
  levels) by parsing `.mmd` output. With a model-first architecture it would
  compare models directly. The connectivity check currently produces false
  positives on BFS path finding; reachability through intermediate artifact
  nodes needs fixing.

---

## Key renderer parameters

### `mermaid_of_action_rule_schema` (overview + focused views)

| Parameter | Type | Effect |
|---|---|---|
| `expand_artifact` | `(kind * (variant_id * label) list) option` | splits one artifact node into per-variant nodes |
| `expand_probe_kinds` | `(kind * (probe_tag * variant_id * label) list) list` | splits probe action nodes into per-variant pill nodes |
| `summary_tags_by_canonical` | `(string, string list) Hashtbl.t option` | provides all concrete step tags per canonical summary tag, used for combined ID labels |
| `steps_by_rule_tag` | `(string, string list) Hashtbl.t option` | maps rule name → concrete step tags for combined ID labels on action nodes |
| `step_ids` | `(string, int) Hashtbl.t option` | maps step tag → sequential ID for `[N]` labels |
| `focal_predicate` | `(string -> bool) option` | distinguishes in-focus (`st_done`) from contextual (`st_done_ctx`) done steps |
| `summary_rules` | `(rule * string) list` | which (rule, suffix) pairs produce summary follow-up nodes |
| `has_scan` | `bool` | whether a scan_source node exists (affects source label and standalone node) |
| `chain_scan` | `bool` | Full only: route configure through scan_source node |
| `view_title` | `string option` | comment line in output (`"%% view: lib"`); omitted when None |

### `mermaid_full` (full view)

Separate step-level renderer (`canary_action.ml`). Every concrete step is an
individual node; nothing is merged. Key inputs:

| Parameter | Effect |
|---|---|
| `variant_infos` | `(variant_id * version * action_tags) list` from `run_info.json`; drives version annotation on artifact nodes |
| `step_ids` | same `[N]` label table |
| `has_scan` | whether to emit scan_source node and dashed source edge |
| `summary_rules` | accepted but ignored (summary and action IDs are both derived from `steps`) |
| `artifact_names` | `artifact_kind -> string option`; supplies real artifact names for doc node labels (e.g. `libz3.so`) |
| `view_title` | title comment in the output (default `"full"`) |
| `status` | node status hashtable for colour classes and edge colours |

Web-viewable output is copied to `docs/canary/projects/<project>/` for GitHub Pages.
Build artifacts (`.ok`, `pack-repo/`, `*_example*`) are excluded.
