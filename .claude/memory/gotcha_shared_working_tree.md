---
name: gotcha-shared-working-tree
description: Two Claude Code sessions in one working tree — a checkout moves the other's branch and `git add -A` sweeps its files; check git reflog
metadata:
  type: project
---

Two sessions in **one** working tree (not two worktrees) fail silently:
- a `git checkout` in one switches the branch under the other, whose
  next commit lands on the wrong branch;
- a `git add -A` in one sweeps the other's uncommitted files into its
  commit;
- both `dune build`s race on `_build`.

**How to notice:** `git reflog <branch>` shows an entry neither session
remembers making; a suddenly clean `git status` while you have unstaged
work is suspect.

**How to apply:** run one session per tree. A second one gets its own
worktree, but shared-core work is better serialized than parallelized
(CLAUDE.md, *Concurrent agents*).

Related: [[feedback-stage-by-name]].
