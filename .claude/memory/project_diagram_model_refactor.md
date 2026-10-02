---
name: diagram-model-refactor
description: On hold — rewrite canary_diagram.ml's two Mermaid renderers as one model with merge and expand operations
metadata:
  type: project
---

**On hold** (user, 2026-10-01: the old diagram is less interesting for
now).

`canary_diagram.ml` has two independent Mermaid renderers that duplicate
node emission, edge routing, styling and status mapping. The idea: one
format-agnostic diagram model built from the rules and steps, with merge
and expand operations (collapse a kind into one node, expand it per
variant) and a thin renderer, so the overview, focused and full views
become different merges of one model, and the invariant checker compares
models instead of parsing `.mmd`. The plan is in
`doc/canary/design/diagram.md` (Open work).
