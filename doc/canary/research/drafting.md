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

- **Contract-vs-check distinction.** Primary home: §2.5
  (theoretical insight about Contract independence).
  Cross-reference from §6.3 (the implementation realises both
  mechanisms cleanly).

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

## Project-wide planning grid

The writeup's organising spine is **artifact → surface → contract**
— three nouns, one progression — with the three pillars (theory /
tiny / canary) as rows. Each cell says what that pillar
contributes about that concept. Use as a sanity-check: anywhere
a cell is empty or thin, the writeup has a gap to fill.

|                  | **artifact**                                          | **surface**                                              | **contract**                                                |
| ---------------- | ----------------------------------------------------- | -------------------------------------------------------- | ----------------------------------------------------------- |
| **theory** (§2)  | kinds (Source, Lib, Binding, App); the boundary       | syntactic / semantic split; six surface roles `s1..s6`   | `c1..c7` catalogue; explicit agreement between two surfaces |
| **tiny** (§3)    | concrete artifacts (libtiny.so, 3 bindings, helper)   | each artifact populates `s1..s6` deterministically       | each perturbation breaks one contract; 13-variant matrix    |
| **canary** (§4)  | per-kind stores; producer-agnostic artifact sources   | inspectors extract surfaces from artifacts               | comparators check contracts on extracted surfaces           |

### PL analogy

The project-wide spine has a clean PL parallel:

- **artifact** ↔ *expression* — what the developer writes / ships.
- **surface** ↔ *type* — the static description of what the
  expression / artifact presents at its boundary.
- **contract** ↔ *run-time behavior, invariant, assertion* — the
  agreement that holds between two surfaces, checked statically
  or dynamically.

Making this parallel explicit in §2 SS positions surface theory
as "a type system for binding interfaces" — orientation familiar
to PL-paper readers, and a hook for §5.7 (calculus sketch) at the
end.

## §2 SS restructure plan

**Source critique.** `surface_draft/surface.md` reviewed end-to-
end on 2026-06-05 (notes at the top of this file, L1–L41).
Outline is messy with duplicated definitions, parallel motivation
passes, and material that doesn't belong. Cleanup pass below.
Apply later — outline iteration first.

### Leading spine

**artifact → surface → contract.** Linear. No preamble loops; no
parallel motivation passes; commenting on the theory comes after
the theory. (See *Project-wide planning grid* above for the spine
in tabular form.)

### Proposed §2 SS subsections (replaces current 2.1–2.6)

- **§2.1 Artifacts and the boundary.** Artifact kinds (Source,
  Lib, Binding, App). The boundary as the only thing tools see.
  Tools rely on implicit assumptions about boundaries; surface
  theory makes them explicit. *One sentence — replaces the
  tool-surfaces table.*
- **§2.2 What a surface is.** Definition: observable properties
  an artifact presents at its boundary. Syntactic / semantic
  split. The gap, briefly.
- **§2.3 The six surface roles.** `s1..s6` named explicitly:
  `native_header`, `native_lib`, `binding_stub`,
  `binding_header`, `binding_lib`, `runtime_trace`. The naming
  convention is **load-bearing** — universal vocabulary across
  theory / tiny / canary, which the project invested in. Plus:
  language-side internal structure (stub-facing → repacking →
  compiled), binding-mechanism axis (static / dynamic) as
  orthogonal.
- **§2.4 Contracts.** Definition: an *explicit* agreement pinning
  two surfaces. The `c1..c7` catalogue as **one canonical
  table** (rows: contract, provider surface, consumer surface,
  kind, where it fires). Universal naming: `c*` identifiers.
  API-repacking / API-completeness flagged as "checked via probe
  today; static check future work."
- **§2.5 Extending the framework.** The `(surface, contract)`
  machinery is open. Extensions: hidden dependencies (glibc/musl
  as a surface), symbol versions (already extensive), path
  resolution (to-do). Each extension slots into the same
  machinery — the framework's completeness-by-construction
  argument. **Absorbs current §5.4 Hidden dependencies.**
- **§2.6 Properties of the theory.** Contract-vs-check
  independence; refinement lattice (`SymbolVersion ⊑ Symbol`);
  satisfaction predicate (conjunctive). Presented after the
  contracts themselves so they have something to refer to.

### Decisions

- **Vocabulary fix.** "Typed contract" → **"explicit contract"**
  (captures lifted-from-implicit-to-explicit framing without
  overloading "typed").
- **Drop the tool-surfaces table** (`surface_draft/surface.md`
  L45–53). Replace with one sentence in §2.1.
- **Drop the Z3 instantiation table** (`surface_draft/surface.md`
  L208–227). Doesn't carry theoretical weight; `tiny.md` is the
  concrete instantiation.
- **Move artifact records** (`surface_draft/surface.md` L160–180)
  out of §2 SS. Candidate homes: a small §5 MM subsection or
  drop entirely (it's a separate research thread of the user's).
- **Defer API-repacking / API-completeness static check.** State
  the contracts exist; flag the static check as future work
  (already self-flagged in materials L357–371).
- **Fix the two contract tables that don't match**
  (`surface_draft/surface.md` L320s vs L346–355). Commit to one
  canonical table.
- **Emphasise universal naming** (`s*` / `c*`) as a first-class
  point — the project invested in this and the draft buries it.

### Section moves outside §2 SS

- **§5.4 Hidden dependencies → §2.5 Extending the framework.**
  Hidden deps becomes evidence of framework openness, not a
  sibling §5 concern. (User confirmed merge.)
- **§5.3 Versioning stays in §5 MM.** Versioning genuinely
  cross-cuts c1, c4, c5 and earns its own §5 home. (User
  confirmed keep.)

### When applied

Drives a coordinated edit pass on `surface.md`: rewrite §2
subsections (2.1–2.6 → new 2.1–2.6 above), delete §5.4 (content
absorbed into §2.5), keep §5.3, update cross-refs throughout
(§1.4 Topics preview, §5 MM goal text, etc.).

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

(empty — flushed 2026-06-04. Code-comment cites in `src/canary/`
and `canary/scripts/` remain; covered by backlog #46.)
