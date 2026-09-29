---
name: feedback-patient-with-new-actions
description: A change that adds a new action or step to canary's pipeline is planned and parked for a deliberate point, not landed in the flow of other work
metadata:
  type: feedback
---

Be patient with modifications that need to add new actions (user, 2026-09-29: "Let me/us be more patient on modification needing to add new actions"). Said when the `resolve_sys` plan (a recording step after `fetch_lib`) was ready to implement; the user asked to save the plan and pause to rethink the overview workflow instead.

**Why:** a new action or step changes what every run does — the step graph, the run cache and its markers, the pins that list steps and placeholders, and what the overview draws — so it deserves a rethink of the whole workflow, not momentum from the previous increment.

**How to apply:** when a plan adds an action, a step, a recording step, a bridge step or a new probe, write the plan down where its item lives (e.g. `doc/canary/design/overview.md` §6), mark it held, and bring it back at a point the user chooses. Work that adds no action (derivations, readers, rendering, docs) can proceed as usual. Related: [[feedback-design-forks]].
