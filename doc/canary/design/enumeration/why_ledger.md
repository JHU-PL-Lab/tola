# Proposal — `--why`, the per-candidate ledger

**Kind: proposal.** **Landed when** `canary emit <project> --stage
enumerate --why` reports, per candidate the product generated, which
constraint removed it — or that nothing did. The map is
[`README.md`](README.md).

> **2026-08-25 — build it.** The trigger below has fired: see *The
> trigger for building it*. Previously postponed on the grounds that a
> reader could reason the counts through in chat; that was tested during
> a sweep and did not hold.

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
surprises whoever landed it (ncurses, lmdb, sundials queued). What
actually happened is that an EXISTING project's count was wrong and
nobody could see it, during a routine sweep:

- Auditing the counts by hand from the emitted data failed twice. A
  first product model ignored the pin axis and predicted z3 = 12 against
  an actual 16; a second look found the pins ARE emitted (as `pins` on
  the source row: `4.15.2, latest, arbipher, pre-10549`) but nest INSIDE
  a channel rather than multiplying freely, so the product is not a
  plain product. The denominator is the hard part, and it is the part
  the ledger's `kept + dropped = the product` invariant makes explicit.
- The audit then turned up a live discrepancy: `tiny-full` enumerates
  **1** world where CLAUDE.md claims 6. Restoring the axes its own dead
  `general_spec` declares yields **4**, not 6 — every `lib=built@dev`
  candidate is pruned, and *which constraint removed them is still an
  inference*, not a fact anyone can read off. Full finding in
  [`../../project/issues.md`](../../project/issues.md) §1.

That is the ledger's exact use case, on a project that has been landed
for weeks: *"I expected 6, I got 4, and I cannot tell you what ate the
other 2."* The forcing case was never going to be a new landing — a new
landing has someone's attention on it. It is a project nobody is looking
at, where a count drifts and the pins record the drift.

**A second thing this argues for.** The pins encoded `("tiny-full", 1)`
rather than failing, so the ratchet recorded the new number instead of
contesting it. A count pin cannot distinguish "this project legitimately
has N worlds" from "this project lost N worlds and someone updated the
number". A ledger can: kept + dropped = the product, with a reason per
drop, is a claim about *structure* and does not silently re-baseline.

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
