# Handoff — 2026-06-11 (Mac → WSL)

Session-bridging note from a doc-only Mac session. Code state is at
`db5fd4c` (the pulled tip) + this commit on top; no source build was
re-run on Mac this round.

## Doc-revision protocol (agreed this session)

- **Default**: agree on a section / paragraph-level thesis + summary
  first; the user writes the prose; Claude comments and judges.
- **Exception**: when the user says "directly update" / "write it",
  Claude drafts the prose.
- **Files**:
  - `surface.md` — manuscript, edited freely.
  - `drafting.md` — batched edit queue indexed against
    `surface_draft/` by line number.
  - `surface_draft/*` — source pool, **pruneable** once material
    lands in the manuscript. Flag whole-file deletions before doing
    them.

## §1.5 grid audit pattern (used in this commit)

For each cell of a manuscript navigation table, check:

1. A concrete subsection pointer (`§X.Y`) exists in the manuscript.
2. The phrase describes content actually present at that subsection
   — not aspirational, not implementation-located-elsewhere.

The §1.5 audit caught **canary × surface** and **canary × contract**
describing §6 Implementation content under the §4 row. Reassigned
to §4.4 (scan_sources placement) and §4.5 / §4.7 (validation +
real-project demos), with §6.2 noted as the mechanism home.

Pattern is reusable for the surface-roles table at §2.3, the
binding-mechanism table at §2.3, and any future grid in §3 / §4.

## What's open (research track)

- §2 / §3 / §4 subsection prose has not yet been audited against
  the revised §1.5 grid. The grid is now the spec; subsection prose
  should match.
- `plan.md` Step 3 — shared `canary_inspectors/` Python package;
  names for the four still-missing inspectors (`bo1`, `bpc1`,
  `bpe1`, `n3`); scenario-naming consistency (`api_*` describe
  properties not violations).
- §1.3 four principles are now backbone-aligned (three + one
  orthogonal); §5.1 full discussion needs the same reshape next
  time it's touched.

## Cross-reference

- Doc layout map: [`README.md`](README.md).
- Edit queue with line anchors: [`drafting.md`](drafting.md).
- Worked plan + status: [`plan.md`](plan.md).
