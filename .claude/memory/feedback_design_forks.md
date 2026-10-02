---
name: feedback-design-forks
description: Discuss design forks with the user before changing code; record analyses as design docs / status to-dos
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 32642756-51af-43b8-b570-e7441d9b9a4d
  modified: 2026-08-05T16:23:51.976Z
---

When a task surfaces a genuine design fork (e.g. terminology split, new
abstraction like the action-variant table), the user wants the issues
**described and discussed first, before making a change** (their words,
2026-08-05, on the scenario-overload T0/T1/T2 proposal). Analyses that
aren't acted on get saved as design docs (`doc/canary/design/*.md`) or
status.md to-dos — "be aware of this if it bothers you or me."

**Why:** design vocabulary and interfaces are load-bearing across the
manuscript, SSOT, and code; premature renames/refactors churn all three.

**How to apply:** present the audit + tiered options + a recommendation;
implement only after their pick. Mechanical/reversible increments on an
agreed direction (per-project code, display fixes, tests) can proceed
autonomously — they consistently approved those. Related preferences the
same day: zero-cache rebuilds are acceptable for A5 ([[project-canary-a5-plan]]);
observations (watchlist lag, xfail) must SURFACE in `spec`/`status`
command output, not just JSON files.

**Sharpened 2026-08-25** (landing ncurses): when a landing turns up a
GENERAL finding, the finding outranks finishing the landing. Offered four
options — land it as an xfail, land both cells, land stable-only, or
pause and write the finding up — they chose PAUSE. So: stop, write the
design doc (kind + falsifier per `doc/canary/design/index.md`), RUN the
falsifier before believing it, and leave the landing as a resume point in
`project/issues.md`. Same session, the reverse also held: a cheap tooling
gap blocking every future landing (`spec-check` could not see a channel
PAIR) they chose to fix FIRST, and to fix in full (both axes) rather than
the minimum written down.
