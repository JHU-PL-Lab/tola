surface_draft/surface.md

L1-5 informal problem

L7-11, meta; mention tiny, which should be duplicated, mention plan.md, can be delete.

L13-16, purpose: justifies and predicts; too vague;
- the paragraph serves the movitation that the surface theory is universal, while in real-world, there are many surface theory instanec, e.g. the setting via C_API, or ctypes, or rust ffi, or so. this should be merged into that discussion.

L24-43, stating artifacts in systems, tools consume artifacts with their implicit model, esp L39 **a typed contract for artifacts** (though _typed_ is not a good term).

L45-53, not perfect, we don't need a table for transforming, since here is on artifacts; however, we can mention that tools have implicit requirements on artifacts, this is more relavent here.

L55-70. commmenting the theory should be later in the SS. at least we need present them fully first.

L72-79. meta, should be merged into the corresponding paragraphs.

L81-85. definition of surface again, including up to L114. This is better starting on definitions.
L116, the gap also naturally appear. up to L158 is ok, but a bit verbose.

L160-180, artifact as records. we don't develop the idea very clearly. It's acturally my another research topic so we can move them to the miscalleous or draft.

section starting at L182 is ok, but L184-189 is duplicated a bit.

L191-206. It's good to stay in this writeup.

L208-227. another example table, not good to be here.

L229-262. content is good. language binding side structure.

So up to now, we should have one leading outline in the section is artiract--surface--contract.

Then it starts with the contract part. L284-300 is ahead before the definition. starting from L300 is good.

L302-L313 is meta for contract

Table till L330 is good. but the coding side discusses about API-repacking,API-completeness, which should be a to-do to discuss later (which is also mentioned in L357-371). I found you discuss that in table L346-355, but now the two tables don't match.

The draft is not insisting on the importance for a universal naming, which we worked hard.

the final topic is on Hidden dependencies, which is part of the some surface contract. The code reflects a fact that, the checking framework is open to extend, since the surface checking is a complete checking, so we can have more checking targets, e.g. depenedencies, symbols (which we checked a lot), path (which is to-do)

--

# Drafting playbook for `surface.md`

Operational reference + active edit queue for drafting work on the
manuscript. Holds the drafting order, per-section sources, small
navigational notes, and any in-flight batched edits across
`doc/canary/`. The *principles* shaping this work live in the
`feedback_writeup_consolidation` memory; this file is the *how-to*
for applying them, plus the queue for what's about to be edited.

Convention: queued items get removed once applied (not retained as
history); deferred / lower-priority work moves to `backlog.md`.

## Suggested order of drafting

1. **§1 (BB) sketch** — enough to anchor the topics preview; full
   prose drafts last, after §2–§4 settle.
2. **§2 (SS)** first substantive draft — most adaptable; gives
   the writeup its theoretical anchor.
3. **§3 (TT)** second — builds on §2; mostly synthesis from
   [`tiny.md`](tiny.md).
4. **§4 (CC)** third — leaner now (4.1–4.8 after the §6 split);
   §4.6 / §4.7 (real-project material) need the real-project lift
   before honest.
5. **§5 (MM)** subsections grow as cross-cutting topics demand
   depth; 5.1 / 5.2 plausible to draft anytime, others later.
6. **§6 (Impl)** drafts last for content depth, but the
   structural outline (6.1–6.6) is in place from the start so §4
   knows what it offloads.
7. **§1 (BB) full prose pass** last — once all later topics are
   stable, BB's topics preview lands honestly.

## Per-section "Pull from" sources

Where to mine content from for each manuscript section. Sources
that say `surface_draft/*` are in the materials collection
([`surface_draft/`](surface_draft/)).

- **§1 BB Motivation** — `surface_draft/surface.md` Part A (Why
  surface?), §0 (syntactic/semantic split); `tiny.md` (concrete
  witness examples); llvm/z3/sqlite project specs (real-world
  examples); worklogs (lessons that became principles).
- **§2 SS Surface theory** — `surface_draft/surface.md` §2.4
  contract table + §2.1 surface roles + §2.2 lang-side structure;
  `surface_draft/principle.md` for P1..P6 background.
- **§3 TT Tiny** — [`tiny.md`](tiny.md) (witness spec);
  `worklog_2026_06.md` closing matrix.
- **§4 CC Canary** — `worklog_2026_06.md` (Phase 14/15 mechanics);
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md)
  (orthogonal factoring); `CLAUDE.md` (orientation map);
  [`plan.md`](plan.md) Phase 17 (real-project plans); existing
  real-project specs.
- **§5 MM** — `surface_draft/principle.md` (full principles);
  `surface_draft/package.md` (packaging);
  `surface_draft/versioning.md` (versioning cross-cuts);
  `surface_draft/surface.md` §4 (hidden deps);
  `surface_draft/main.md` §5 (related work) + §6 (calculus
  sketch); [`literature.md`](literature.md).
- **§6 Impl** — `surface_draft/implementation.md` §2.7 (code map);
  `worklog_2026_06.md` (engine machinery + harness leaks);
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md)
  (engine boundary cleanness); existing code in
  `src/canary/projects/`, `src/canary/surface/`,
  `canary/examples/tiny/scenarios/`, `canary/scripts/inspect_*`.

## Cross-section navigational notes

- **Contract-vs-check distinction.** Primary home: §2.6
  (theoretical insight about Contract independence, as one of
  the section's "properties of the theory"). Cross-reference
  from §6.3 (the implementation realises both mechanisms cleanly).

## Companion docs outside surface.md

Pointers a reader of `surface.md` might want, but which don't
belong inline in the manuscript:

- **Paper venue + roadmap** — [`plan.md`](plan.md).
- **Related-work bibliography** — [`literature.md`](literature.md).
- **Implementation status of the framework's internal factoring**
  (engine-boundary leak inventory, Phase 16 refactor plan) —
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md).

## What changes about how we work

- Coding pauses. Discussion + outline iteration is the primary
  mode while the manuscript stabilises.
- When a §4 or §6 prose draft surfaces a refactor candidate, we
  make the refactor; the prose checks it for cleanness.
- §4.6 / §4.7 work requires going back into code (real-project
  lift); that pivot happens when §2–§4.5 outlines + drafts are
  solid enough to guide the real-project shape.

### Doc-revision protocol (agreed 2026-06-11, Mac session)

- **Default**: agree on a section / paragraph-level thesis +
  summary first; the user writes the prose; Claude comments and
  judges.
- **Exception**: when the user says "directly update" / "write
  it" / similar, Claude drafts the prose.
- **File roles** (cross-check before edits touching multiple
  files):
  - `surface.md` — manuscript, edited freely.
  - `drafting.md` — batched edit queue indexed against
    `surface_draft/` by line number.
  - `surface_draft/*` — source pool, **pruneable** once material
    lands in the manuscript. **Flag whole-file deletions before
    doing them.**

## Grid-cell audit pattern

When a manuscript navigation table has cells of the form "§4 row
contains X" or "canary × contract = Y," **audit each cell** by:

1. A concrete subsection pointer (`§X.Y`) exists in the
   manuscript at that location.
2. The cell phrase describes content **actually present** at that
   subsection — not aspirational, not located in a different
   chapter (e.g. implementation content under §4 row).

The §1.5 grid was audited 2026-06-11; **canary × surface** and
**canary × contract** were describing §6 Implementation content
under the §4 row, and got reassigned to §4.4 (scan_sources
placement) and §4.5 / §4.7 (validation + real-project demos),
with §6.2 noted as the mechanism home.

Pattern is reusable for **Table — Surface roles** (§2.3), **Table
— Binding mechanism** (§2.3), **Table — Contract catalogue**
(§2.4), and any future grid in §3 / §4 prose.

## Stray scratch (from purged sections, 2026-06-05 to 2026-06-11)

Free-form marginalia rescued before purging the duplicated
*Project-wide planning grid* and *§2 SS restructure plan*
sections (those are now landed in `surface.md` §1.5 / §2.1–§2.6).
Kept here as content seeds; not actionable.

- *tiny: one good set of artifacts, plus lots of mutations…
  concrete traces (….) retire..*
- *tiny-dyn*
- *canary: src store × lib store*
- *invariant; standards; contract : sth written* — vocabulary
  exploration on the agreement word.

---

## Front matter for `surface.md` (held for reuse)

Moved here from `surface.md` on 2026-06-04 because it wasn't yet
useful for the manuscript's current shape: the role blockquote +
six-part spine declaration + ASCII diagram + numbered chapter
list. The numbered list overlaps with §1.4 Topics preview (the
canonical reader-facing roadmap inside BB), so today we keep §1.4
as the single source and park this abstract version here. Reinstate
the diagram / numbered list at the top of `surface.md` when an
end-to-end TOC or executive-summary view becomes useful (e.g.,
once prose lands and a reader can scan the spine before diving in).

### Role blockquote

```markdown
> Manuscript for the canary writeup. Materials collection sits in
> [`surface_draft/`](surface_draft/) (sister files: `main.md`,
> `surface.md`, `principle.md`, `implementation.md`, `package.md`,
> `versioning.md`). Drafting playbook + active edit queue lives
> in [`drafting.md`](drafting.md).
```

### Six-part spine prose + ASCII diagram

```markdown
**Six-part spine.** Three pillars (SS / TT / CC) sit between a
background opener (BB) and miscellaneous + implementation chapters
at the back.

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌──────────┐
│ §1  BB  │ ──→ │ §2  SS  │ ──→ │ §3  TT  │ ──→ │ §4  CC  │ ──→ │ §5  MM  │ ──→ │ §6 Impl  │
└─────────┘     └─────────┘     └─────────┘     └─────────┘     └─────────┘     └──────────┘
```
```

### Numbered chapter list

```markdown
1. **§1 Background & Motivation (BB)** — reader-facing opener.
   Motivation, approach, principles preview, and a topics preview
   that names every later topic in a sentence each.
2. **§2 Surface theory (SS)** — rules over surfaces; the spec
   space. Need not be one section internally.
3. **§3 Tiny (TT)** — a mechanism-complete, material-naive
   controlled witness.
4. **§4 Canary (CC)** — the framework that scales the witness to
   natural producers (opam, pip, apt, …); includes a methodological
   validation step against tiny.
5. **§5 Miscellaneous (MM)** — principles (full discussion),
   packaging as a trace source, versioning cross-cuts, hidden
   dependencies, related work, calculus sketch. The
   "extensions" pattern from PL papers is **held in mind** here,
   not committed.
6. **§6 Implementation (Impl)** — how the theory is realised in
   code: the two engines (mutation, combinator), inspectors and
   check mechanisms, code-citation map, the boundary between
   harness and canary. Skippable for readers who only want the
   conceptual narrative.
```

---

## Active edit queue

### §2 / §3 / §4 subsection prose audit against §1.5 grid

The §1.5 grid (manuscript) is **now the spec**. Each cell points
at a concrete `§X.Y`. Audit task: walk those §X.Y subsections in
turn and confirm the prose (or current bullets) actually says
what the grid cell promises.

- **§2 SS row.** §2.1 (kinds, boundary as check site), §2.2–2.3
  (presence axis + s1..s6), §2.4 (c1..c7 catalogue). Apply the
  grid-cell audit pattern above.
- **§3 TT row.** §3.2 (concrete artifacts), §3.2 (s1..s6
  populations — likely needs a sub-table in §3.2), §3.3
  (13-variant matrix).
- **§4 CC row.** §4.1–4.2 (stores), §4.4 (scan_sources placement
  mechanism, §6.2 home), §4.5 (validation), §4.6 (natural
  producers), §4.7 (real-project demos).

### §5.1 Principles full discussion — reshape to match §1.3

§1.3 (manuscript, reshaped 2026-06-11) now organises four
principles around the backbone: three rules/concrete-trace/
abstract-trace-aligned plus one orthogonal. **§5.1 full
discussion must adopt the same shape** next time it's touched
(currently still a flat list expanding §1.3's old four bullets).

### Note (carried from 2026-06-04 flush)

Code-comment cites in `src/canary/`
and `canary/scripts/` remain; covered by backlog #46.)
