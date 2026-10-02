---
name: feedback-stage-by-name
description: Stage commits file by file, never a directory — the user's drafts under doc/canary/research/ stay unstaged
metadata:
  type: feedback
---

Stage every commit by explicit file name; never `git add <directory>`,
`-A` or `.`. The user keeps in-progress edits in the working tree —
`doc/canary/research/draft.md`, `draft.pdf`, `draft_drift.md` and the
untracked `doc/audit/multi_pm.md` — and they must stay unstaged.

**Why:** on 2026-10-01 a docs commit staged `doc/canary` as a directory
and swept the three drafts in. It was caught at once and undone with
`git reset --soft HEAD~1` plus `git restore --staged` on the drafts,
their contents checked unchanged by checksum, but it broke the user's
standing rule: "never touch draft.md ... Stage files by name and check
`git reflog` before committing."

**How to apply:** list the paths (`git add a.ml b.md …`); before
`git commit`, read `git diff --cached --stat` and confirm no
`research/` draft or untracked user file is in it. Related:
[[gotcha-shared-working-tree]].
