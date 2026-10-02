---
name: feedback-bottom-up-design
description: Grow canary bottom-up by concrete increments; design docs consolidate last, from accumulated cases
metadata:
  type: feedback
---

Prefer bottom-up. Keep unifying frames (e.g. "actions are patterns with
slots") in mind, but do not run top-down design passes. Grow by concrete
increments — add an action, reconsider a role, onboard a project, audit a
project's missing cases — and regroup or rename only when the
accumulated evidence forces it. Design consolidation comes last.

**Why:** top-down plans look convincing and then bend the code to fit
themselves; strong models over-design and go off track (user, 2026-08-05).
Evidence first keeps the design honest and the sessions on track.

**How to apply:** when proposing next steps, offer the smallest concrete
increment, not a phase plan. Write a design doc only to record what
landed or to capture a question the user raised. Each increment ships
with its guard, as CLAUDE.md's *Four layers of checks* states. Related:
[[feedback-design-forks]].
