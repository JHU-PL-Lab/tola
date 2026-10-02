---
name: diagram-model-refactor
description: On hold — refactor the Mermaid diagram rendering (canary_diagram.ml) to a model-first architecture with merge/unmerge ops
metadata:
  type: project
---
# Diagram model refactor (spin-off TODO)

**On hold** (user, 2026-10-01: the old diagram is less interesting for
now).

Current state: `canary_diagram.ml` has two independent renderers (`mermaid_of_action_rule_schema` ~633 lines, `mermaid_full` ~447 lines) that both emit Mermaid text directly from rules/steps. They duplicate node emission, edge routing, CSS styling, and status mapping.

Target architecture:
1. A `diagram_model` type: nodes (with associated `[N]` IDs), edges, styling — format-agnostic
2. `model_of_rules` — builds a full-expanded model from the rule set + step data
3. Merge/unmerge operations on the model — collapse a kind into a pool node, expand a kind into per-variant nodes, inline summaries — these are the "zoom" operations
4. `mermaid_of_model` — a thin renderer that walks the model and emits Mermaid text
5. Overview = full model → merge all → render. Focused view = full model → selectively expand one kind → render. Full = keep all expanded → render.

This eliminates the ~1100-line duplication between the two renderers and makes the merge/expand logic explicit and testable.

**Why:** user noted the current file is large because the two renderers are structurally independent. A model-first approach would share all the rendering infrastructure.

**When:** after current split stabilizes. Low priority — the current code works and the split is already a big improvement.

**Related:**
- Invariant checker (in `canary_diagram.ml`) currently parses `.mmd` output. With a model-first approach, it would compare models directly — no parsing needed.
- Connectivity check has false positives on BFS path finding; reachability through intermediate artifact nodes needs fixing.
- Documented in `doc/canary/design/diagram.md` §Future direction.
