---
name: feedback-patient-with-new-actions
description: A change that adds an action or step to canary's pipeline is planned and parked, not landed in passing
metadata:
  type: feedback
---

Be patient with changes that add an action (user, 2026-09-29, holding the
`resolve_sys` recording step to rethink the overview's workflow first).

**Why:** a new action or step changes what every run does — the step
graph, the run cache and its markers, the tests that list steps, what the
overview draws — so it deserves a look at the whole workflow, not the
momentum of the last increment.

**How to apply:** when a plan adds an action, a step (recording, bridge,
placeholder) or a probe, write the plan down where its item lives (for
example `doc/canary/design/overview.md` §6), mark it held, and bring it
back when the user chooses. Work that adds no action (derivations,
readers, rendering, docs) proceeds as usual.

Related: [[feedback-design-forks]].
