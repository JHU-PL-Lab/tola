# Drafting playbook for `surface.md`

Operational reference + active edit queue for drafting work on the
manuscript. Holds the drafting order, per-section sources, small
navigational notes, and any in-flight batched edits across
`doc/canary/`. The *principles* shaping this work live in the
`feedback_writeup_consolidation` memory; this file is the *how-to*
for applying them, plus the queue for what's about to be edited.

Convention: queued items get removed once applied (not retained as
history); deferred / lower-priority work moves to `backlog.md`.

## §3 SS — focused work area

(SS was §2 before the 2026-06-12 restructure that lifted Tiny-tiny
to §2; theory subsections renumbered accordingly. Materials
references — `surface_draft/surface.md §X.Y` — keep the materials'
own numbering and are unchanged.)

### §3 Pull from sources

(Materials' §2.1 surface-roles table and §2.4 contract-definitions
table have been migrated to manuscript §3.3 / §3.4 — no longer
Pull-from sources.)

Remaining sources for §3 prose expansion:

- `surface_draft/surface.md` §2.2 — **language-side internal
  structure**: 3-layer breakdown (stub-facing → repacking →
  compiled artifact) + the "why the compiled artifact is the
  natural check-target" callout. Only a single-bullet summary
  has landed in manuscript §3.3; full prose still source.
- `surface_draft/surface.md` §2.4 surrounding prose —
  "Categories of invariants (cross-cutting)" subsection (NOT
  migrated; potentially feeds §3.5 or §3.6); "Two notes on the
  contracts table" (intra-language note partially migrated);
  "Currently active vs. deferred" (partial — manuscript notes
  c2 / c7 deferred and c8 retired).
- `surface_draft/principle.md` — P1..P6 background for §3.6
  *Properties of the theory* + §6.1 *Principles (full
  discussion)*.

### §3 row from grid-cell audit (against §1.4 grid)

The §1.4 grid is now the spec. Walk each §X.Y in turn and
confirm the prose (or current bullets) actually says what the
grid cell promises.

- §3.1 (artifact and its boundary), §3.2–3.3 (surface, presence
  axis, role catalogue), §3.4 (contract catalogue and agreement).
  Apply the grid-cell audit pattern below (see *Grid-cell audit
  pattern*).

### Contract-vs-check distinction (cross-section nav for §3.6 ↔ §7.3)

- **Primary home**: §3.6 (theoretical insight about Contract
  independence, as one of the section's "properties of the
  theory").
- **Cross-reference** from §7.3 (the implementation realises both
  mechanisms cleanly).

### Vocabulary deliberation: contract / invariant / agreement (parked 2026-06-11)

User flagged 2026-06-11 that **contract** carries an "explicit
written" connotation that fits c1 / c2 / c4 / c5 / c6 but stretches
for c3 Behavior (implicit, runtime-determined), c7 API-repacking
(intent-only), and the hidden-deps extension target (§3.5 — no
party writes it down). The asymmetry is real.

#### Options surveyed

| Term          | Fits explicit | Fits implicit | Two-party flavor | "Can be broken" verb             |
| ------------- | ------------- | ------------- | ---------------- | -------------------------------- |
| **Contract**  | ✓             | ✗             | ✓✓               | ✓ (break a contract)             |
| **Invariant** | ✓             | ✓             | △                | ✗ (invariants hold)              |
| **Property**  | ✓             | ✓             | ✗                | △                                |
| **Agreement** | ✓             | ✓             | ✓✓               | ✓ (break agreement)              |
| **Rule**      | ✓             | ✓             | △                | ✓ — but reused for c-meta schema |

#### User's refining cut (the deciding point)

**"Agreement is more umbrella; invariant is principle-flavor.
One can break the agreement, while the invariant should already
hold."** The verb compatibility is what tips it: canary's whole
business is to *run scenarios that violate*. "Break the
agreement" reads naturally; "break the invariant" doesn't —
invariants are by definition the things that hold, so saying
they "break" undercuts the term.

This bumps **agreement** above **invariant** as the umbrella
candidate, and re-pins **contract** as a *subtype* (an
agreement-with-a-written-carrier).

#### Where this leaves things

Three live candidates:

- **(a) Full rename to "agreement"** as the umbrella term across
  §1.4 grid + §3.4 title + table + prose. Contract becomes a
  subtype label for the c-metas that have a written carrier.
- **(b) Keep "contract" with reframing** in §3.4: "an agreement
  pinning two surfaces — most are *explicit contracts* (written
  declarations); some are implicit." Lower churn; preserves the
  established vocabulary at the cost of mild dissonance for c3 /
  c7.
- **(c) Half-rename**: §3.4 title and the `Table —` label switch
  to "Agreement"; row labels and code-level vocabulary stay
  "contract" until a wider sync.

#### Decision pending

Postponed. Revisit when next touching §3.4 prose or the §1.4 grid.

#### Scope reminder (if applied)

Manuscript touchpoints: §1.4 grid header + closing paragraph;
§1.5 §3 SS preview bullet; §3.4 section title + canonical-table
label + definition + c2 / c7 deferred-static-check prose; §3.5
"(surface, contract) machinery" phrase; §3.6
"Contract-vs-check" subsection. Materials and code remain on
"contract" until a wider sync per "uniformity eventually."

### §1.4 column-header invariant rename — vocabulary sync TBD (2026-06-11)

User changed the §1.4 grid (was §1.5) column header from
**contract** to **invariant**. Other places not yet synced:

- Cell content in `theory (§3)` row uses "agreement between two
  surfaces" — diverges from column header.
- §1.4 paragraph PL parallel still uses "contract ↔ run-time
  invariant / assertion."
- §1.4 paragraph "internal vocabulary" still uses "rules" /
  "agreements."
- §1.5 Topics preview §3 SS bullet still uses "contract catalogue"
  / "Artifact → surface → contract along an explicit spine."
- §3.4 section title still "Contracts (Agreement)"; **Table —
  Contract catalogue**; "explicit contract" definition; "(surface,
  contract) machinery" in §3.5; "Contract-vs-check independence"
  in §3.6.




Pairs with the **Vocabulary deliberation** section above. Decision
still pending; the partial rename in §1.4 is a probe to feel out
the vocabulary in context. Don't propagate until decision is made.

---

## Per-section "Pull from" sources

Where to mine content from for each manuscript section. Sources
that say `surface_draft/*` are in the materials collection
([`surface_draft/`](surface_draft/)).

- **§1 BB Motivation** — `surface_draft/surface.md` Part A (Why
  surface?), §0 (syntactic/semantic split); `tiny.md` (concrete
  witness examples); llvm/z3/sqlite project specs (real-world
  examples); worklogs (lessons that became principles).
- **§2 Tiny-tiny** — minimal touchstone; sourced inline from
  `tiny.md` for canonical names (`tiny_offset`, `tiny_sum`,
  `libtiny.so.1`).
- **§3 SS Surface theory** — moved to **§3 SS — focused work
  area** at the top.
- **§4 TT Tiny-complete** — [`tiny.md`](tiny.md) (witness spec);
  `worklog_2026_06.md` closing matrix.
- **§5 CC Canary** — `worklog_2026_06.md` (Phase 14/15 mechanics);
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md)
  (orthogonal factoring); `CLAUDE.md` (orientation map);
  [`plan.md`](plan.md) Phase 17 (real-project plans); existing
  real-project specs.
- **§6 MM** — `surface_draft/principle.md` (full principles);
  `surface_draft/package.md` (packaging);
  `surface_draft/versioning.md` (versioning cross-cuts);
  `surface_draft/surface.md` §4 (hidden deps);
  `surface_draft/main.md` §5 (related work) + §6 (calculus
  sketch); [`literature.md`](literature.md).
- **§7 Impl** — `surface_draft/implementation.md` §2.7 (code map);
  `worklog_2026_06.md` (engine machinery + harness leaks);
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md)
  (engine boundary cleanness); existing code in
  `src/canary/projects/`, `src/canary/surface/`,
  `canary/examples/tiny/scenarios/`, `canary/scripts/inspect_*`.

## Companion docs outside surface.md

Pointers a reader of `surface.md` might want, but which don't
belong inline in the manuscript:

- **Paper venue + roadmap** — [`plan.md`](plan.md).
- **Related-work bibliography** — [`literature.md`](literature.md).
- **Implementation status of the framework's internal factoring**
  (engine-boundary leak inventory, Phase 16 refactor plan) —
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md).

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

## Backbone section — verbose original (parked 2026-06-11 from surface.md L124-168)

Compressed into a single paragraph at the end of `surface.md`
§1.5 on 2026-06-11. Original verbose form kept here as material:
re-expand into a standalone `## The backbone` section if a future
reader needs the rules / traces / worlds vocabulary developed at
length (e.g. as part of §2.6 Properties or as theory front-matter
before §2).

```markdown
## The backbone: rules, traces, worlds

A **rule** says what counts as agreement between two surfaces
(the `c1..c7` catalogue). A **world** is a configuration of
artifacts; a rule is either satisfied or violated in a given
world. A **trace** is an observed verdict — the rule's status on
a particular world.

Two trace shapes do complementary work:

- **Concrete trace.** A specific world we construct by hand:
  tiny + a controlled perturbation. Each rule has at least one
  concrete trace witnessing a violation — a single, reproducible
  failure.
- **Abstract trace.** A world drawn from per-kind candidate sets:
  one artifact per kind, sourced independently. Canary's variant
  matrix is a structured walk over the abstract-trace space; the
  same shape applies to natural producers (opam / pip / apt).

In PL terms, **rules** are inference rules / property statements
and **traces** are executions — concrete traces are single runs
(tiny + a perturbation), abstract traces are the execution space
drawn from per-kind stores. This complements §1.5's spine analogy:
the spine names *what is agreed upon* (artifact / surface /
contract); the backbone names *how agreement is tested* (rules
observed via traces in worlds).

A rule is robust when both trace shapes expose it. Concrete
traces give **depth** — controlled, reproducible witnesses;
abstract traces give **breadth** — configurations that arise from
independent producers, beyond what hand-construction can reach.

This maps the §2–§4 arc: §2 names the rules; §3 covers the
concrete-trace witness (tiny); §4 covers the abstract-trace
framework (canary), including a validation step against tiny's
concrete traces along the way. How each shape is mechanically
produced is **§6 Implementation**.

The PL notation scaffold (formal rule / world / trace definitions)
is parked in [`surface_draft/notation.md`](surface_draft/notation.md)
until the theory settles enough to need it.
```

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
spine declaration + ASCII diagram + numbered chapter list. The
numbered list overlaps with §1.5 Topics preview (the canonical
reader-facing roadmap inside BB), so today we keep §1.5 as the
single source and park this abstract version here. Reinstate the
diagram / numbered list at the top of `surface.md` when an
end-to-end TOC or executive-summary view becomes useful (e.g.,
once prose lands and a reader can scan the spine before diving
in).

**Stale numbering warning.** This parked chapter list reflects
the pre-2026-06-12 six-part spine (§1 BB / §2 SS / §3 TT / §4 CC
/ §5 MM / §6 Impl). The current seven-part spine inserts
Tiny-tiny at §2 (lifting SS / TT / CC / MM / Impl by one).
Update before reuse.

### Role blockquote

```markdown
> Manuscript for the canary writeup. Materials collection sits in
> [`surface_draft/`](surface_draft/) (sister files: `main.md`,
> `surface.md`, `principle.md`, `implementation.md`, `package.md`,
> `versioning.md`). Drafting playbook + active edit queue lives
> in [`drafting.md`](drafting.md).
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

### §4 / §5 subsection prose audit against §1.4 grid

The §1.4 grid (manuscript) is **now the spec**. Each cell points
at a concrete `§X.Y`. Audit task: walk those §X.Y subsections in
turn and confirm the prose (or current bullets) actually says
what the grid cell promises. (§3 row moved to **§3 SS — focused
work area** at top.)

- **§4 TT row** (Tiny-complete). Anatomy absorbed into §2
  (touchstone); §4 focuses on witness role + perturbation matrix
  (§4.2) + what tiny demonstrates/doesn't (§4.3).
- **§5 CC row** (Canary). §5.1–5.2 (stores), §5.4 (scan_sources
  placement mechanism, §7.2 home), §5.5 (validation), §5.6
  (natural producers), §5.7 (real-project demos).

### §3.1 Artifacts and the boundary — consider adding an artifact table (2026-06-12)

User noted (2026-06-12) that canary's code has an artifact table
(artifact kinds in `Canary_basic` — `Source | Lib | Binding | App
| Package` — and the per-artifact alias dictionary used in tiny's
inventory, e.g. `n4 = lib_native.so`, `bo7 = compiled_binding_ocaml.stub-a`).
§3.1 currently just lists artifact kinds as a bullet:

> Artifact kinds (Source, Lib, Binding, App).

When §3 SS gets a prose pass, consider promoting to **Table —
Artifact kinds** (or **Table — Artifact inventory**) with one
row per kind: id / friendly name / what it is / examples. Could
mirror the §3.3 Surface roles table structure for visual
consistency.

Source: canary code (`Canary_basic.artifact_kind`); concrete
inventory in `tiny.md`'s artifact-alias section. **Not urgent**;
the existing one-bullet outline of §3.1 is fine until prose
lands.

### §6.1 Principles full discussion — reshape to match §1.3

§1.3 (manuscript, reshaped 2026-06-11) now organises four
principles around the backbone: three rules/concrete-trace/
abstract-trace-aligned plus one orthogonal. **§6.1 full
discussion must adopt the same shape** next time it's touched
(currently still a flat list expanding §1.3's old four bullets).

### Note (carried from 2026-06-04 flush)

Code-comment cites in `src/canary/`
and `canary/scripts/` remain; covered by backlog #46.

---

## Code TODOs (postponed to polish pass)

Code-level work surfaced during manuscript editing but
deliberately deferred — manuscript leads, code catches up later
per the *uniformity eventually* principle. Add items here as
they surface; revisit in a coordinated code-polish pass once the
manuscript stabilises.

### 2026-06-12 — `runtime_trace` is not a surface (from §3.3 decision)

Manuscript reclassified the former s6 `runtime_trace` as a
**runtime observation**, not a surface (§3.3 *The five surface
roles* + §3.4 c3 Behavior footnote). The code still treats it as
a surface peer to s1..s5. Items to align eventually:

- **OCaml source** (`src/canary/`):
  - `Σ_RT` / `runtime_trace` naming — rename to
    `runtime_observation` (or `behavioral_trace`), or drop the
    `Σ_*` formal label entirely for this case.
  - Any type or constructor in the `inspect_input` ADT that
    treats `Runtime_trace` as a surface-family peer — split out
    as a separate variant or document the asymmetry inline.
  - Surface-role enum / friendly-name mapping: surface roles are
    now s1..s5; runtime observation gets its own slot.
- **Python inspectors** (`canary/scripts/`):
  - `inspect_*` scripts emit JSON with a `kind` field. Probe-trace
    output's `kind` should reflect "observation" not "surface."
- **Materials** (`surface_draft/`):
  - The materials' Surface roles table still lists s6 as a
    surface row. When materials get pruned per their pruneable
    status, this gets resolved naturally; until then it stays as
    historical reference.
- **tiny.md**:
  - References to "s1..s6 surface roles" — update to "s1..s5
    surfaces + Sn.6 runtime observation" (or similar). Several
    lines reference s6 explicitly.
- **plan.md / backlog.md** — may have stale s6 references;
  scan during polish pass.

Cross-reference: backlog #46 covers the broader engine
vocabulary alignment audit; this item is narrower and specific
to the surface-vs-observation distinction. Could fold into #46
or stand alone — decide at polish-pass time.