---
name: feedback-design-forks
description: Discuss a design fork before changing code; a general finding outranks finishing the task in hand
metadata:
  type: feedback
---

When a task surfaces a real design fork (a terminology split, a new
abstraction), describe the options and recommend one; change the code
only after the user picks. An analysis not acted on is saved where it
belongs: a design doc or a to-do in `status.md`.

**Why:** names and interfaces are load-bearing across the draft, the docs
and the code, and a premature rename churns all three.

**How to apply:**
- Mechanical, reversible steps in an agreed direction (per-project code,
  display fixes, tests) proceed without asking.
- When a task turns up a general finding, the finding comes first: stop,
  write it up with its falsifier, run the falsifier, and leave the task
  as a resume point. A cheap tooling gap that blocks every future task
  is fixed first, and in full.
- Observations (a watchlist lag, an xfail) surface in command output,
  not only in JSON files.

Related: [[feedback-bottom-up-design]], [[feedback-patient-with-new-actions]].
