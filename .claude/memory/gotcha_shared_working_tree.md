---
name: gotcha-shared-working-tree
description: Two Claude Code sessions in ONE working tree — a checkout switches the branch under the other, and a `git add -A` sweeps the other's uncommitted files into its commit
metadata:
  type: project
---

CLAUDE.md's "Concurrent agents (worktrees)" section covers two agents in
two **worktrees**. The failure mode it does not cover is two sessions in
**one** working tree, which is what happened on 2026-09-21 and is worth
recognising because both symptoms are silent.

What was observed, in one afternoon in `/home/red/code/research/tola`:

- **A checkout switches the branch under the other session.** This
  session ran `git checkout main` to fast-forward `main` onto
  `ds-workflow`; a concurrent session had been launched against
  `ds-workflow`. Its next commit therefore landed on `main` — harmless
  here only because the two were identical content at that moment.
- **A `git add -A` sweeps the other session's uncommitted files into its
  commit.** Two memory files written but not yet committed by this
  session appear in commit `f8de4aed`, whose message is entirely about
  the agreement overview's kind glossary. Nothing was lost, but the
  commit no longer describes its own contents, and `git status` came
  back clean to a session that had not committed anything.
- A `dune build` in each races on the same `_build`.

**How to notice.** `git reflog <branch>` is the cheap tell — an entry
you did not make, between two you did. Also distrust a suddenly-clean
`git status` when you know you have unstaged work.

**Practice.** Run one session at a time in a given tree. If two are
genuinely needed, the second gets its own worktree — but note the user's
2026-08-17 finding (in CLAUDE.md) that worktrees touching shared-core
files were tried and judged a bad idea, so the honest answer for
shared-core work is to serialize rather than parallelize. Remote-runner
work (`status.md` §2.1) is maximally shared-core: it touches
`canary_step_model.ml`, `canary_step_builder.ml`, `canary_local_runner.ml`
and `canary_gh.ml`.

Related: [[gotcha-mac-runner-reachability]].
