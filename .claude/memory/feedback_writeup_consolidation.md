---
name: feedback-writeup-consolidation
description: How to work on the paper — queue drift instead of fixing it ad hoc, one home per concept, the user writes the prose, small steps
metadata:
  type: feedback
---

How the user works on the paper (`doc/canary/research/`):

- **Manuscript and materials.** `draft.md` is the manuscript and wins;
  `surface_draft/` holds materials to mine, possibly stale, never
  authoritative; `draft_commemt.md` holds what moved out of the
  manuscript. Flag a whole-file deletion of materials before doing it.
- **Uniformity eventually, not now.** Vocabulary may drift between the
  draft, the materials and the code. Don't fix a mismatch in passing:
  queue it in `draft_drift.md` (what draft.md does not say yet) and move
  on.
- **One home per concept**; other places link to it instead of
  restating it.
- **Reorganize before rewriting.** When a doc's material is good but its
  presentation unclear, the work is structure (sections, grouping,
  one-line openers), not new content.
- **The user writes the prose.** Agree a section's thesis first, in a few
  lines; the user writes and Claude comments. Draft prose only when told
  to ("write it"). Mechanical edits (cross-references, renames, an agreed
  plan) need no thesis.
- **Small steps, short replies.** One thesis at a time, then stop; long
  commentary is revision debt too.
- **Queue the incidental.** Small side edits are not mixed into the
  substantive work.
- **No push** during prose drafting: commit locally, push only when
  asked.

**Why:** writing ahead of the user's clarity, or fixing everything as it
comes up, creates revision debt and splits attention; the user owns the
voice and the argument.

Related: [[feedback-stage-by-name]] (draft.md is never touched or staged).
