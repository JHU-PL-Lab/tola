---
name: feedback-stage-by-name
description: Stage commits file by file, never a directory — the user's drafts under doc/canary/research/ stay unstaged
metadata:
  type: feedback
---

Stage every commit by explicit file name; never `git add` a directory,
`-A` or `.`. The user's in-progress files stay unstaged and untouched:
`doc/canary/research/draft.md`, `draft.pdf`, `draft_drift.md`, and the
untracked `doc/audit/multi_pm.md`.

**Why:** a directory add once swept the drafts into a commit (2026-10-01,
undone at once). The user's standing rule: never touch draft.md, stage by
name, check `git reflog` before committing.

**How to apply:** list the paths in `git add`, then read
`git diff --cached --stat` before committing.

Related: [[gotcha-shared-working-tree]].
