# Proposal — `--why`, the per-candidate ledger

**Kind: proposal.** **Landed when** `canary emit <project> --stage
enumerate --why` reports, per candidate the product generated, which
constraint removed it — or that nothing did. The map is
[`README.md`](README.md).

> **2026-08-25 — build it.** The trigger below has fired. Previously
> postponed on the grounds that a reader could reason the counts through
> in chat; that was tested during a sweep and did not hold.

## What it is, in one table

Pass 2 forms a product of candidate worlds and five constraints prune it;
today you see only the survivors. `--why` reports each candidate's
**fate** — kept, or dropped and by which constraint.

It is **not** an enhancement of `spec-check`. The two audit different
objects, and both are STATIC — neither reads a run:

| | `spec-check` | `--why` |
| --- | --- | --- |
| object | the **declaration** (pass 1), row by row | the **enumeration** (pass 2→3), candidate by candidate |
| question | is this project's spec mature — does it declare what a landed project should? | given that declaration, why does the world set have exactly these members? |
| answer shape | per-row ✓ / ⚠ / ✗ presence marks | per-candidate fate + reason |
| arithmetic | none — it never multiplies anything | the whole point: `kept + dropped = the product` |

The post-run family is elsewhere entirely — `status`, `result`, `verify`,
`compat` all read `actions.log` or a probe. `--why` reads neither; it is
a function of `(project_spec, policy)`, the same inputs as
`emit <p> --stage 2`.

**The independence is demonstrated, not asserted**: `spec-check
tiny-full` reports **0 errors** while tiny-full enumerates one world
where its docs claim six. Every row it needs is present and names a
provider; what is wrong is that the rows COLLECTIVELY generate one
world, and a presence audit has no way to notice that.

> Split out of `why_ledger.md` on 2026-08-24, once everything else in
> that proposal had landed and become rationale. The `emit` command, its
> six passes, `--json`, `--raw`, the selection pass and the pipeline
> module are all built and described in [`README.md`](README.md) and the
> per-pass docs; what remains a PROPOSAL is this.

## The decision, and the test that produced it

*(2026-08-24, user: "if the `why` is the printing version of how code is
working in some stages, we can also postpone it, since I would ask you
directly in the chat … but we will need it finally. you decide.")*

**Decision: postponed.** The test the user proposed is the right one, and
applying it honestly splits `--why` in two:

- **The summary** — "8 dropped by `assignment_ok`, 4 by `source_ref_ok`"
  — is *narration of the algorithm*. It is derivable by reading the five
  constraints against a spec, which is exactly the thing that can be
  asked for in chat rather than built into a terminal. Postponable.
- **The per-candidate ledger** — "the world you expected is absent, and
  HERE is what removed it" — is an *observation*, computed by the code
  that runs rather than reasoned about by a reader. Not narration. This
  is the half worth building.

So when it is built, build the ledger, not the histogram. A drop-reason
count is the tempting first version and it is the less useful one.

**A sharper framing the user supplied**: *"a tool for us to inspect why
something works AS EXPECTED"* — note the positive direction. For a
checking framework the audit trail of a GREEN run matters as much as the
diagnosis of a missing one: "this world exists, and here are the five
constraints it passed" is a different and arguably more valuable
statement than "these got dropped". So the ledger should carry **both
fates**, per candidate, not just the removals.

**The trigger for building it — FIRED 2026-08-25, and not where this
note expected.** The prediction was a NEW project whose scenario count
surprises whoever landed it (ncurses, lmdb, sundials queued). Two things
falsified that, both during a routine sweep. The per-project particulars
are in [`../../project/issues.md`](../../project/issues.md) §1; what
belongs here is the general lesson each carries.

**1. The denominator is the hard part, not the attribution.** This note
assumed a reader could reason the counts through against a spec. Tried,
and failed twice on real projects: a first product model ignored the pin
axis; a second found that pins ARE emitted but nest INSIDE a channel
rather than multiplying freely, so the product is not a plain product.
`kept + dropped = the product` is valuable less because it attributes
drops than because it forces the denominator to be *stated*.

**2. The forcing case is a project nobody is looking at.** A new landing
has someone's attention on it; a landed project's count can drift for
weeks. What surfaced was an existing project enumerating far fewer worlds
than its own documentation claims, with the axes declared in code nothing
reads — and *which constraint removed the missing candidates is still an
inference*, which is the ledger's use case verbatim.

**3. Count pins re-baseline; a structural claim does not.** The count in
question was pinned — at its WRONG value. A count pin cannot distinguish
"this project legitimately has N worlds" from "this project lost some and
someone updated the number", because updating the number is how you make
it pass. `kept + dropped = the product`, with a reason per drop, is a
claim about structure: there is no number to quietly move.

**What it will need, unchanged:** three of the five constraints are
already `-> bool` predicates, so attribution is a recorder around them;
`shadow_filter` and `ref_filter` return their dropped set with a reason.
The invariant is stronger than the listing — **kept + dropped = the
product** — and it is the only part with behavioural risk.

## What it needs

Three parts, and only the second carries behavioural risk:

1. **A recorder around the three predicates.** `assignment_ok`,
   `binding_couples` and `source_ref_ok` are already `-> bool`
   ([`stage2_filters.md`](stage2_filters.md)), so attribution is running
   them and keeping the verdict per candidate. Free.
2. **The two list-filters return their drops.** `shadow_filter` and
   `ref_filter` become `list -> kept × (dropped × reason)`. This is the
   part that could change what is enumerated, so it is the part the
   invariant guards.
3. **Selection reports separately.** Pass 3 exists now
   ([`stage3_select.md`](stage3_select.md)), so a missing world is either
   *pruned by a constraint* (pass 2) or *not asked for* (pass 3). The
   ledger must say which; before the split it could only say "absent".

## Tests

Structural, in the same style as the pins the rest of the proposal
shipped — a golden ledger would churn on every legitimate spec change and
get blanket-regenerated.

| pin | asserts |
| --- | --- |
| `why.accounts_for_every_candidate` | kept + dropped = the product, per catalogued project. Nothing vanishes unexplained |
| `why.reasons_are_known` | every drop names one of the six constraints — no "other" |
| `why.kept_equals_stage2` | the ledger's kept set IS `Canary_pipeline.worlds`, so recording cannot alter enumerating |

## What not to do

- **Do not let `--why` change what is enumerated.** The recorder observes
  the constraints; it must not reorder or short-circuit them. That is
  what `why.kept_equals_stage2` is for.
- **Do not ship the histogram as the first version.** "8 dropped by
  `assignment_ok`" is the narration half — the part that can be asked for
  in chat. The ledger is the observation half, and it is the reason to
  build this at all.
