---
name: feedback-writeup-consolidation
description: "Writeup-phase working principle — uniformity eventually, not uniformly now. Don't eagerly fix vocabulary drift across docs/code; prose in SMALL steps, thesis-first"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: efe74a79-8653-4c29-8dd2-4ff850641ee3
  modified: 2026-09-30T02:39:49.297Z
---

During the canary writeup phase, `doc/canary/research/notes.md` is
the canonical consolidation point. Vocabulary may legitimately
drift between notes.md, `surface_theory.md`, and the OCaml /
Python code — and that's acceptable. The principle is **uniformity
eventually, not uniformly now**: when notes.md stabilises, we
back-port concepts and notation downstream.

**Why:** the user explicitly stated this is also a retrospection on
the implementation — the writeup is the chance to make theory,
notes, and code share consistent concepts. Trying to keep them
synchronised during drafting is "big boring" and slows the framing
work; trying to revise everything ad hoc per chat fragments the
attention budget.

**How to apply:**

- When working on canary docs/code during this phase, don't
  eagerly fix vocabulary mismatches between `notes.md` and other
  files. Surface them, queue them, move on.
- Queue revisions somewhere explicit. `doc/canary/research/drafting.md`
  was deleted 2026-06-24; since 2026-09-29 the checklist of what
  `draft.md` does not say yet is `doc/canary/research/draft_drift.md`
  (the user asked for it; terms to settle, then section by section).
  `draft_commemt.md` holds material moved out of the manuscript.
  Applied items get removed; the queue becomes the agenda for
  the post-stabilisation polish pass.
- Notation maintenance specifically is deprioritised: the
  PL scaffold in notes.md's `## Notation` section is a *destination*,
  not a constraint on draft-time prose. §1–§4 may use informal
  vocabulary.
- The polish pass is owed to: `surface_theory.md` (older theory
  attempt, may rename contracts → rules), code (OCaml type names),
  and `design/harness_canary_orthogonality.md` (already queued).
- The user prefers batched application: don't apply small
  incidental edits (README descriptions, CLAUDE.md key-file rows)
  in the same chat as the substantive work — queue them.

**Second principle: few-to-one source of truth.** Each concept
gets one canonical home; other locations link rather than restate.
Applies to written-material topics too. For instance: if the
framework's implementation factoring belongs in
`design/harness_canary_orthogonality.md`, notes.md shouldn't
repeat its leak inventory — only point at it. If the rule
catalogue belongs in surface_theory.md / §1, the Backbone
section shouldn't re-derive it. Cross-references over
duplication. This is a stronger discipline than "uniformity
eventually" — it constrains *what gets written where*, not just
*what vocabulary is used*.

**Third principle: reorganization over re-iteration.** When an
existing doc has good material but unclear presentation, structure
is the work. Don't burn cycles re-deriving what's already on the
page. The fix is to make topic divisions explicit and surface the
material's flow (via section partitions, content-kind grouping,
1-sentence pipeline openers); the content itself stays.

**Fourth principle: materials vs manuscript.** Borrow the
writing-app metaphor (scrivener-style): separate the *materials
collection* (raw drafts, longer derivations, alternative
phrasings) from the *manuscript-in-progress* (confirmed structure
and content). The two play different roles even when they cover
the same topics. Concretely (2026-06-04):
- `doc/canary/research/surface.md` (renamed from `notes.md`) =
  manuscript. Authoritative for current framing.
- `doc/canary/research/surface_draft/` (split from
  surface_theory.md) = materials. Mine for content; may be stale;
  not authoritative; pruneable when content lands in manuscript.

**Why:** user (2026-06-04) — "the current surface_theory.md is
the surface_material (in some writing app it's a collection of
possible used material), while the notes.md should be surface.md
with confirmed content."

**How to apply:**
- When the user identifies a doc as materials vs manuscript,
  reflect the role at the file level (rename, header label,
  README description) so the distinction survives across sessions.
- When prose lands in the manuscript that draws from the
  materials doc, the manuscript wins; don't preserve the
  materials' framing if it diverges.
- Materials docs aren't deleted — they're sources to mine. But
  treat them as historically-frozen unless explicitly revisited.
- **Flag whole-file deletions of materials before doing them**
  (user instruction, 2026-06-11). Pruning is OK; surprise pruning
  isn't.

**Push cadence during prose-drafting.** User instruction
(2026-06-11): during the manuscript prose-drafting phase, commit
locally but **do not push automatically**. Push only when the user
explicitly asks. Rationale: commits stay reviewable / amendable
until a coherent batch is ready to share. (Different from the
earlier code-shipping cadence where push-on-green was fine.)

**Fifth principle: doc-revision protocol (default thesis-first).**

- **Default**: agree on a section / paragraph-level thesis +
  summary first; the user writes the prose; Claude comments and
  judges.
- **Exception**: when the user says "directly update" / "write
  it" / similar, Claude drafts the prose.

**Why:** user (2026-06-11 Mac session, captured in
`doc/canary/research/handoff.md`) — establishes a stable working
mode for the prose-drafting phase distinct from the
outline-iteration phase. Reduces wasted prose-drafts when the
user wants to own voice / argument shape.

**How to apply:**
- For substantive content edits to `surface.md`: propose thesis +
  summary in conversation; wait for the user to either write the
  prose or say "write it."
- For structural / mechanical edits (cross-refs, renames, table
  migrations, applying agreed plans): proceed without thesis-
  first.
- Outline bullets (the current `surface.md` state for most
  subsections) count as outline iteration; drafting prose around
  them is content.

**Sixth principle: small steps, and my comments count as length.**
User (2026-08-26): "you would like to write and extend before I am
clear, so I have to do another pass to revise it, and your feedback
makes long revision so we are keeping increasing."

**Why:** writing ahead of the user's clarity creates revision debt, and
long *commentary* creates it too — the review load grows even when no
prose was written. Both are the same failure: producing volume before
the idea is settled.

**How to apply:**
- One thesis at a time, in chat, a few lines. Stop. Wait.
- Do not draft the next section, expand into adjacent points, or
  restate the plan "for completeness."
- Keep responses SHORT during prosing; a long critique is itself the
  problem being described.
- Ask which topic before starting; don't pick and run.

**Why:** user (2026-06-04) on `surface_theory.md` — "the material
part is quite well from the previous one. the primary problem is
the presentation is not very clear and the division of several
topics are not explicit … in other words, we may need more
high-level organization and material pipelines, rather than
re-iterating the same content."

**How to apply:**
- When confronting an older doc (surface_theory.md, tiny.md,
  etc.), diagnose what's there before proposing edits. Surface the
  TOC; identify heterogeneous sections; flag staleness vectors
  (subsections that reference code paths).
- Prefer pure-structural moves (extract subsections that don't
  belong, reposition sections, group by content-kind) over content
  rewriting.
- If the user wants to drive the reorg themselves, the cc role is
  to provide the diagnosis + a structural sketch in the queue;
  don't execute.
