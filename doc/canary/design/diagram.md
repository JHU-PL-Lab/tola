# Diagram improvements — plan

The current `result.mmd` is a flat overview that's getting hard to read
as the action graph grows (summary steps, stub summaries, scan_source,
multi-language probes, multi-location lib probes). Three connected
improvements, in order of dependency.

Backlog refs: [#36](../backlog.md) (summary node fidelity), [#37](../backlog.md) (HTML viewer).

---

## Step 1 — Summary node fidelity (#36)

**What's missing today:** the rendered diagram drops several real steps:

- `scan_source` runs as a post-fetch check (verifying header/binding-dir
  claims) but shares `fetch_source`'s output dir and is invisible.
- `*_summary` follow-up steps (e.g. `probe_lib_summary`,
  `fetch_ocaml_binding_summary`) are emitted by `derive_steps` after
  every probe / install but aren't rendered.
- `*_stub_summary` (the L0 consumer-side summary on
  `fetch_ocaml_binding`) is similarly invisible.
- `fetch_python_binding_summary` (after pip install) — same gap.

**Result.** A run that executes 23 steps may show 13 nodes — the
diagram is an inaccurate picture of what canary actually runs.

**Direction.**

- Each rendered backend (`canary_backend_gh.ml`, the local Mermaid
  renderer) iterates `action_step list`. Today the renderer filters out
  `*_summary` / `scan_source` steps. Stop filtering — emit a node per
  step, with a visual treatment (different colour or shape) for
  follow-up steps so the eye still reads the primary action chain.
- Choose a cheap visual hierarchy:
  - **primary** action nodes (Fetch/Build/Probe/Pack) — same as today
  - **annotation** nodes (`*_summary`, `*_stub_summary`, `scan_source`)
    — smaller / dashed / muted colour
- Edges from primary → annotation use `dashed` or `-.->` to signal
  "follow-up", not "data-flow dep".

**Files touched.**

- `canary.ml` — `mermaid_of_action_rule_schema` (universal schema diagram)
- `canary_action.ml` — `mermaid_of_steps` (per-run diagram). Stops
  filtering follow-up steps.
- Rendering style helpers (probably new; or extend
  `node_class_of_step`).

**Output verification.** Run `canary action z3` and `canary action llvm`,
visually inspect `result.mmd` in a Mermaid renderer; expect ~all 23
steps for z3/dev (was 13–17), ~13 for llvm/19 (was 9–10).

---

## Step 2 — Multi-view diagrams per project

**Motivation.** A single all-in-one diagram has reached the readability
ceiling. Different questions demand different slices. The current
overview is good for "what's the chain?" but bad for "what stores
participate?", "which version combinations are exercised?", "what does
the OCaml binding flow look like end-to-end?", etc.

**Proposed views.** A project run produces, in addition to `result.mmd`,
a set of focused diagrams under `<run_dir>/diagrams/`:

| View              | Filename                       | Slice                                                                             |
| ----------------- | ------------------------------ | --------------------------------------------------------------------------------- |
| Overview          | `result.mmd` (current)         | Primary actions; condensed                                                        |
| Source detail     | `diagrams/source.mmd`          | Source repo, fetch_source, scan_source, version metadata, store provenance        |
| Lib detail        | `diagrams/lib.mmd`             | Build_lib / Install_lib / Fetch_lib / probe_lib*; native summary; stores per probe |
| Binding/OCaml     | `diagrams/binding_ocaml.mmd`   | Fetch/Pack ocaml_binding; mli + stub summary; probe_ocaml_binding (Build/Pm/Staged variants) |
| Binding/Python    | `diagrams/binding_python.mmd`  | Fetch_python_binding (pip install) + summary; probe_python_binding                |
| Action/Probe      | `diagrams/probes.mmd`          | All probe_* steps with their summaries + expectation type (Success/Failure/Compat) |
| Action/Pack       | `diagrams/pack.mmd`            | Pack_* steps + opam local-repo flow                                              |

**Shared shape.** Each view is the same `action_step list` filtered to
the relevant subset, plus extra annotation:

- store nodes (apt, opam, pip, build_tree, staged)
- version pins (e.g. `z3-solver 4.16.0`, `llvm.19-shared`, `Z3 4.15.2`)
- expectation tag on probe nodes (`Expect_success`,
  `Expect_failure`, `Expect_compat_failure`) — new today's diagram has
  no expectation hint
- lib summary counts inline (e.g. "1268 LLVM_ symbols")

**Implementation sketch.**

```ocaml
type diagram_filter =
  | All
  | Of_artifact_kind of artifact_kind   (* Source | Lib | Binding | App *)
  | Of_lang of lang                     (* OCaml | Python | … *)
  | Of_action_kind of action_kind       (* Fetch | Build | Probe | Pack *)

val mermaid_of_steps :
  filter:diagram_filter ->
  ?annotate_stores:bool ->
  ?annotate_versions:bool ->
  ?annotate_expectations:bool ->
  action_step list ->
  string
```

The runner emits each view by calling `mermaid_of_steps` with a
different filter; a tiny per-project `views_to_emit` decides which
views are written. Default set covers Source/Lib/Binding-OCaml/
Binding-Python/Probes; additional views opt-in per project.

**Files touched.** `canary.ml` (filter + render), `canary_action.ml`
(emit views post-run alongside `result.mmd`), project specs (add
optional `diagrams_to_emit` if non-default).

**Open questions.**

- **One Mermaid file per view, or one with subgraphs?** Per-file is
  simpler to render selectively in the HTML viewer. Subgraphs are
  better for "compare two views side-by-side" — but Mermaid's subgraph
  support is patchy. Default: per-file.
- **Where do versions come from?** For dev variants we have
  `version_cache_tag`; for stable we have `source.version`. Probe
  steps know which lib/binding version they're against (via
  `binding_summary`). Plumbing exists, just unused by the current
  renderer.
- **Coupling with the api_source layer?** The "store node" decoration
  reaches into `api_source.binding_apis` for OCaml/Python sources.
  Worth deferring until `binding_api.deps` (#35) lands so we don't
  hand-write the store→action edges.

---

## Step 3 — HTML viewer (#37)

**Motivation.** Static `.mmd` files don't compose well with the action
log (`actions.log`, `probe.log`, `summary.json`). The viewer makes a
run dir explorable: pick a view, drill into a node, read the log.

**Shape.** A static HTML file (`result.html`) generated alongside
`result.mmd` per run. Self-contained; renders in any browser without
a server.

Contents:

1. **Header** — project + variant; run timestamp; pass/fail summary.
2. **View selector** — buttons for Overview, Source, Lib, Binding/OCaml,
   Binding/Python, Probes, Pack. Switches the displayed Mermaid block
   without page reload.
3. **Mermaid render** — current view's `.mmd` rendered inline via
   mermaid.js (CDN by default; optional bundled mode for offline use).
4. **Node click → log drawer** — each Mermaid node carries a
   `data-tag="<step_tag>"` attribute; clicking reveals the step's
   `output_dir` files (probe.log, summary.json, stub_summary.json,
   actions.log excerpt) in a side panel.
5. **Filter toggles** — checkboxes to show/hide `*_summary`,
   `scan_source`, `Expect_failure` nodes etc. Stateless; pure CSS
   `.hide-summaries` body class.

**Data model.** A single embedded JSON blob in `result.html`:

```json
{
  "project": "llvm",
  "variant": "19",
  "run_at": "2026-05-01T10:52:43Z",
  "views": {
    "overview":    { "mmd": "...", "title": "Overview" },
    "binding_ocaml": { "mmd": "...", "title": "OCaml binding flow" },
    ...
  },
  "steps": {
    "probe_ocaml_binding": {
      "rule": "probe_binding",
      "expectation": "Expect_compat_failure",
      "output_dir": "probe_ocaml_binding/",
      "files": ["probe.log", "actions.log"],
      "result": "expected_failure_confirmed"
    },
    ...
  }
}
```

The HTML loads its data from the embedded blob; no external paths.
Logs themselves are loaded lazily via fetch (relative paths) when a
node is clicked — keeps the HTML small and avoids embedding multi-MB
logs.

**Implementation sketch.**

- New module `canary_backend_html.ml`. `render_view ~run_dir ~steps`
  produces the HTML string. Reuses `mermaid_of_steps` outputs.
- The runner writes `result.html` after `result.mmd` (and the per-view
  `.mmd` files from Step 2).
- Bundle a small mermaid.js shim (or fall back to a CDN tag).
- Node tags map: each Mermaid node id is its step tag, so the click
  handler is a one-liner.

**Files touched.** `canary_backend_html.ml` (new), `canary_action.ml`
(emit alongside `result.mmd`), small JS template (probably inline string).

**Open questions.**

- **Bundled vs CDN mermaid.js.** CDN is small; bundled is offline-safe.
  Default to CDN with a `--bundle-mermaid` flag.
- **One HTML per run, or one HTML index across all runs?** Start with
  per-run; the index across `_out/canary/projects/` is a tiny
  follow-up if it becomes useful.
- **Compatibility with existing `result.mmd`.** Keep `result.mmd` as
  primary artifact; HTML is purely additive. CI / scripts that consume
  `.mmd` continue to work.

---

## Sequencing

1. **Step 1 first.** Smallest change, immediate visual win. Establishes
   the "follow-up node" rendering pattern.
2. **Step 2 next.** Builds on Step 1 (now-rendered annotation nodes);
   introduces filter machinery. Multi-view diagrams useful even
   without HTML.
3. **Step 3 last.** Once we have multiple views per run, the HTML
   viewer is a natural index. Defer until at least one project has
   ≥3 views regularly emitted.

After all three: the `result.html` per run is a self-contained,
clickable, multi-view exploration of what canary just did. Pairs
naturally with the `canary verify` command (Step 3 could embed the
verify output as a top-banner status line).

---

## Out of scope (parked)

- **Live-updating dashboard during a run.** The static HTML is enough
  for post-hoc inspection. Live updates would require a long-running
  server.
- **Cross-run comparison.** "Show me how llvm/dev's diagram changed
  between yesterday and today" needs a separate diff view; orthogonal
  to per-run navigation.
- **Diagram for the universal schema.** `canary graph` already emits
  this as `_out/canary/graph/action_rule.mmd`; not affected by this
  plan.
