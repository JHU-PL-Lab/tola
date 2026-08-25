# Pass 2 — enumerate: the product, and why it is not the answer

**IR:** **spec** `project_spec` → **worlds** `assignment list`. (IR names: [`README.md`](README.md).)

**Kind: rationale**, plus one **proposal** section at the end
(*Attribution*, absorbed from `why_ledger.md` 2026-08-25). Pass 2 of
five. Standalone. Written 2026-08-23
because it did not exist: the
product over (provision × version × mutation) is easy and documented
(§1 below), but what makes
the enumeration *correct* is the five constraints that prune it, and
those lived only in comments inside `canary_enumerate.ml`. Every one of
them exists because a specific over- or under-generation was observed.

Read [`README.md`](README.md) first for where this sits (stage 2).

## Two axes, not three

The product is over **provision × version**, per artifact. A reader of
the code will also see a mutation axis — `enumerate ~tag ~policy` is
polymorphic in one, and `'m config` has a `mutation` level — and it is
tiny-factory machinery, not part of a real project's enumeration:
`full_policy` and `thin_policy` both carry `mutations = []`, and
`config.mutation = Free` resolves to the no-fault baseline. The single
caller that supplies faults is `tiny_policy` in
`canary_tiny_scenario.ml`, tiny1's oracle. It rides the same product
because a fault is modelled as a `quality = Bad tag` on a placement —
which is elegant, and is also why the axis appears in a signature every
project touches while applying to none of them.

## Before the product: which chains apply

Easy to miss, because it is not a pass and has no dump: `chain_applicable`
filters the **38 universal chains** (`canary paths`) down to the ones this
project can run, from the SPEC ALONE — no policy, no assignment. A chain
survives when every step's output artifact is declared at a provision the
step's version rule needs (`Ambient → Fetched`, `Follows_input → Built`,
with `Vendored` passing through since the artifact exists and no action
produces it), and when a `build_binding` step has a STATIC binding to
build.

`patterns_of` then pairs each surviving chain with each assignment that
matches it. That pairing is what makes a **scenario** a chain plus
coordinates ([`stage0_naming.md`](stage0_naming.md) sense 1) rather than
just coordinates.

## The order they run in

```
                    ── PASS 2, enumerate_product ────────────────────
run_config          product, each level resolved PER ARTIFACT
  │                 (provision × version, version additionally per-provision)
  ▼
assignment_ok       ── coherence: does this world make sense at all?
  ▼
ax_follows          ── declared coupling (Lockstep mode only)
binding_couples     ── a Built binding matches its own source's channel
source_ref_ok       ── the unread-source collapse
  ▼
shadow_filter       ── a prebuilt shadows a same-cell Built
                    ── PASS 3, select ──────────────────────────────
  ▼
version subset      ── --thin
ref_filter          ── --refs
```

The three middle checks run in one sweep over the artifacts, guarded by
`version_mode = Lockstep`; `Independent` skips them and gives the raw
free product.

**Where the line falls, and why.** The first five say a world *cannot
exist* or is *indistinguishable from another*; the last two say *you did
not ask for it*. That is the difference between the model and the run,
and since 2026-08-24 it is also a pass boundary
([`stage3_select_worlds.md`](stage3_select_worlds.md)). `ref_filter` is documented here
because it is the same shape of pruning and because it ran here until the
split; it now runs from `select`.

## 1. `assignment_ok` — coherence

Four rules, all about whether a world could exist:

- A **Built or Installed lib needs its source present**, and at the same
  **channel**. Channel-level, not id-level: identity-bearing sources
  (a `Repo_axes` family's per-channel repos) carry ids the lib's
  placement can never mirror, and under id-equality both dev build chains
  would die. WHICH checkout the scenario is remains part of identity —
  it is the source placement's id (`source-fetched-latest` vs
  `source-fetched-arbipher`).
- The check is **skipped when `a_source` is not declared**. A project
  that models Built as self-contained (sqlite fetches its own
  amalgamation) omits the source artifact, and the coupling is moot.
- A **binding needs a lib**. Provided-or-Absent, per binding.
- An **app needs some binding**.

`Installed` joins `Built` here as the "built family" (2026-08-18): an
installed lib was built from source at that channel too.

## 2. `ax_follows` — the declared coupling

A project can declare that one artifact's version FOLLOWS another's
(`artifact_row ~follows`). The filter keeps only assignments where the
follower's channel equals the leader's — unless either is unprovided.

This is the blunt instrument, and its cost is why the next two exist:
the source rows used to carry `~follows:a_lib`, which killed the phantom
refs but also **forbade the FORWARD cell** — a binding built from a dev
tree probed against the released lib. That is a genuine world, and the
one most likely to find a real bug.

## 3. `binding_couples` — source-primary for a built binding

A **Built** binding builds FROM the scenario's source, so its channel
must match that source's — the same source-primary rule as the Built lib.
Its own source, note: `binding_source_of` resolves the per-language
binding source (`Binding_source lang`), which may be a different repo
from the lib's (zarith's binding is `ocaml/Zarith`, its lib is the system
gmp).

Only the source couples. The **lib pairing stays free**, which is exactly
what leaves the forward cell (Built binding × Fetched lib) alive.

## 4. `source_ref_ok` — the unread-source collapse

The phantom-ref rule, stated precisely (2026-08-19).

A world where **nothing is built from a source** still fetches it, but
WHICH ref it names changes nothing observable — so N declared refs would
produce N identical runs. Such a world keeps only the source's
**canonical pin** (the first declared; stable-first by convention).

"Read" is defined by `source_is_read`: the lib builds from the project
source (`Built` or `Installed`), or some binding is `Built` from that
source. Nothing else consumes a source.

Measured effect: llvm 5 → 3 scenarios, zarith 3 → 2, and z3's
all-Fetched worlds collapsed to ONE (its three fetched rows named
different refs over the same lib and binding).

## 5. `shadow_filter` — prebuilt shadows source

When a Built placement and a prebuilt one (`Fetched`/`Vendored`) would
materialize the **same cell** — same artifact, same channel, same
version id, everything else identical — the prebuilt wins and the Built
assignment is dropped.

The belief: a same-version prebuilt, built by someone else's script,
behaves like a self-built one. The rule came from the GMP build session
(user, 2026-08-17): building an external C lib is not reliably easy, so
the source-built path should not appear automatically.

Firing is **identity-bearing same-version**: both ids must be non-empty
and equal. An ambient (unpinned) prebuilt never shadows — the
same-version belief needs the version known on both sides. sqlite's built
amalgamations are NOT the system's, so they do not shadow.

**Unconditional since 2026-08-19.** It first landed as a two-valued
policy with an `Audit_lib` run rung and an `--audit-lib` flag to unhide
the Built column; nothing used it, and a project that wants its
source-built lib visible should declare it as a **distinct version**
rather than ask a run flag to unhide it. See
[`../wrapper_packages.md`](../wrapper_packages.md) §3.

## 6. `ref_filter` — the `--refs` subset

Keeps the assignments whose SOURCE placement's pinned id is in the
requested list (`--refs latest,pre-10549`). Orthogonal to the version
axis: thin (a channel subset) and refs (an id subset) compose. Projects
with no declared/pinned source are unaffected.

This is a **selection**, not a semantic constraint — it belongs to the
run, not to the model. That observation became a pass: since 2026-08-24
`ref_filter` is called from `select`, not from the enumeration proper,
and `--thin` moved beside it. See [`stage3_select_worlds.md`](stage3_select_worlds.md).
Folding BOTH into one general selection mechanism (channels, refs,
scenarios, actions, …) is still open — `../../project/status_project.md`
§2.

So this section documents where `ref_filter` LIVES in the pipeline (pass
3), and it is listed among the constraints here because that is where it
used to run and because the pruning it does is the same shape.

## What the constraints do NOT do

They do not remove worlds that are merely *expected to fail*. A pruned
assignment is one that could not exist or could not differ; a world that
exists and breaks is the point of the exercise, and its verdict is an
expectation, not a filter. The forward cell surviving §2's cost is the
clearest statement of that principle in the code.

## Attribution — which constraint removed my candidate

**Kind: proposal** (absorbed from `why_ledger.md`, 2026-08-25 — it was
about these constraints and nothing else). **Landed when** `canary emit
<project> --stage enumerate --why` reports, per candidate the product
generated, which constraint removed it — or that nothing did.

Everything above says what each constraint prunes *in general*. What no
command answers is the particular question: **the world I expected is not
in the output — which of the six removed it?** Today the survivors are
visible and the product is not, so a missing world is indistinguishable
from a world that was never generated.

### It is not an enhancement of `spec-check`

Different objects, and both STATIC — neither reads a run:

| | `spec-check` | `--why` |
| --- | --- | --- |
| object | the **declaration** (pass 1), row by row | the **enumeration** (pass 2→3), candidate by candidate |
| question | is this project's spec mature — does it declare what a landed project should? | given that declaration, why does the world set have exactly these members? |
| answer shape | per-row ✓ / ⚠ / ✗ presence marks | per-candidate fate + reason |
| arithmetic | none — it never multiplies anything | the whole point: `kept + dropped = the product` |

The post-run family is elsewhere entirely — `status`, `result`, `verify`
and `compat` all read `actions.log` or a probe. `--why` reads neither; it
is a function of `(project_spec, policy)`, the same inputs as
`emit <p> --stage 2`.

The independence is demonstrated, not asserted: `spec-check tiny-full`
reports **0 errors** while tiny-full enumerates one world where its own
docs claim six. Every row it needs is present and names a provider; what
is wrong is that the rows COLLECTIVELY generate one world, and a presence
audit has no way to notice that
([`../../project/issues.md`](../../project/issues.md) §1).

### Build the ledger, not the histogram

*(2026-08-24, user: "if the `why` is the printing version of how code is
working in some stages, we can also postpone it … but we will need it
finally. you decide.")* Applying that test honestly splits `--why` in two:

- **The summary** — "8 dropped by `assignment_ok`, 4 by `source_ref_ok`"
  — is *narration of the algorithm*, derivable by reading §§1–6 above
  against a spec. The tempting first version, and the less useful one.
- **The per-candidate ledger** — "the world you expected is absent, and
  HERE is what removed it" — is an *observation*, computed by the code
  that runs rather than reasoned about by a reader. This is the half
  worth building.

And it should carry **both fates**, not just removals. The user's framing
was *"a tool to inspect why something works AS EXPECTED"* — for a
checking framework the audit trail of a green run matters as much as the
diagnosis of a missing one.

### Why now (the trigger fired 2026-08-25)

The prediction was a NEW project whose scenario count surprises whoever
landed it. Two things falsified that during a routine sweep; the
per-project particulars are in
[`../../project/issues.md`](../../project/issues.md) §1, the general
lessons are these:

1. **The denominator is the hard part, not the attribution.** The premise
   was that a reader could reason the counts through against a spec.
   Tried, and failed twice on real projects: one model ignored the pin
   axis; a second found that pins ARE emitted but nest INSIDE a channel
   rather than multiplying freely, so the product is not a plain product.
   `kept + dropped = the product` earns its keep less by attributing
   drops than by forcing the denominator to be *stated*.
2. **The forcing case is a project nobody is looking at.** A new landing
   has someone's attention on it; a landed project's count can drift for
   weeks — and which constraint removed the missing candidates stays an
   *inference*, which is this section's use case verbatim.
3. **Count pins re-baseline; a structural claim does not.** The count in
   question was pinned, at its wrong value. A count pin cannot separate
   "legitimately has N worlds" from "lost some and someone updated the
   number" — updating the number is how you make it pass. `kept +
   dropped = the product` has no number to quietly move.

### What it needs

Three parts, and only the second carries behavioural risk:

1. **A recorder around the three predicates.** `assignment_ok`,
   `binding_couples` and `source_ref_ok` are already `-> bool` (§§1, 3,
   4), so attribution is running them and keeping the verdict per
   candidate. Free.
2. **The two list-filters return their drops.** `shadow_filter` and
   `ref_filter` (§§5, 6) become `list -> kept × (dropped × reason)`. This
   is the part that could change what is enumerated, so it is the part
   the invariant guards.
3. **Selection reports separately.** Pass 3 exists
   ([`stage3_select_worlds.md`](stage3_select_worlds.md)), so a missing world is either
   *pruned by a constraint* (pass 2) or *not asked for* (pass 3). The
   ledger must say which; before the split it could only say "absent".

### Tests

Structural, in the style of the pins the rest of the `emit` work shipped
— a golden ledger would churn on every legitimate spec change and get
blanket-regenerated.

| pin | asserts |
| --- | --- |
| `why.accounts_for_every_candidate` | kept + dropped = the product, per catalogued project. Nothing vanishes unexplained |
| `why.reasons_are_known` | every drop names one of the six constraints — no "other" |
| `why.kept_equals_stage2` | the ledger's kept set IS `Canary_pipeline.worlds`, so recording cannot alter enumerating |

### What not to do

- **Do not let `--why` change what is enumerated.** The recorder observes
  the constraints; it must not reorder or short-circuit them. That is
  what `why.kept_equals_stage2` is for.
- **Do not ship the histogram first.** It is the narration half; the
  ledger is the observation half, and the reason to build this at all.
