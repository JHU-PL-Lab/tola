# Agreements — the map

**Kind: index.** What an agreement is in twenty lines, then which file for
which job.

## What an agreement is

Building establishes relations, and most are checked once, by a tool, on one
machine. A compiler checks what its own rules cover; it does not check that
the library finally loaded is the one the header described, because at
compile time there is no such library, and by the time there is, the
compiler is gone. Distribution loses more: a `.so` does not remember which
headers it agreed with, and a consumer remembers only the *name* it recorded.

An **agreement** names one such relation and says how to observe it again,
from evidence that did survive. A **checking method** is one way to observe
it — what it compares, against what, where its evidence appears, and what a
pass does not establish. Evaluating a method yields one **outcome**:

```text
holds · violated · unavailable · inconclusive
not_implemented · not_applicable · disabled · error
```

Eight, because the previous API returned a substring list and an empty list
meant all of them at once. `holds` is bounded by the method's stated scope;
it never means "compatible".

## What is NOT here — the seam

*agreement/ owns the CLAIM, enumeration/ owns the OCCASION* (2026-09-16).

A **claim** is what an agreement asserts, whose rule it recovers, what
evidence it reads and what falsifies it. None of that mentions a world,
and all of it is here.

An **occasion** is `(world, action, mechanism, lang)` — which step a
check fires at, and where its evidence sits in the output tree. That is
the enumeration's vocabulary, and it is stated once, over there:

| question | lives in |
| --- | --- |
| can this PROJECT carry the claim? | [`../enumeration/stage2_analyse_spec.md`](../enumeration/stage2_analyse_spec.md) — pass 2, no world needed |
| does it fire HERE, and where does it read? | [`../enumeration/stage6_realize_steps.md`](../enumeration/stage6_realize_steps.md) §2b — pass 6 |
| what does it claim, and what falsifies it? | this directory |

One thing still crosses it in code: `binding_evidence_tag` /
`lib_evidence_tags` in `canary_agreement_common.ml` map a world to a
step tag. The fix is not to move them — it is to derive them (backlog
§50, [`../action_model.md`](../action_model.md) §6), after which nobody
owns them.

## Which file

| you are… | read |
| --- | --- |
| meeting the idea | this file, then [`model.md`](model.md) §1 |
| **asking why there is anything to check** | [`theory.md`](theory.md) |
| **looking for the NEXT agreement** | [`theory.md`](theory.md) §5–§6 |
| **asking what one agreement IS** | [`catalogue.md`](catalogue.md), or `canary checks --agreement NAME` |
| landing an agreement on a project | [`landing.md`](landing.md) |
| **asking WHEN a check fires** | [`../enumeration/stage6_realize_steps.md`](../enumeration/stage6_realize_steps.md) §2b — the occasion is not here |
| asking what is actually in use | [`landing.md`](landing.md), or `canary checks --landing` |
| **asking why THIS agreement exists** | [`components.md`](components.md), at the anchor its registry row carries |
| writing the paper | [`components.md`](components.md) — the component walk |
| debugging an `unavailable` | [`catalogue.md`](catalogue.md) for where it looks, then [`landing.md`](landing.md) points 4–5 |

- [`theory.md`](theory.md) — **where agreements come from.** An action's
  implementation embodies a relation over its inputs; running it is the only
  witness that a tuple satisfies it; the tuple is then discarded and only a
  projection survives. An agreement is a necessary condition for membership in
  that relation, decidable from what survived. §5 walks Canary's action
  catalogue and states, per action, the full-information agreement the real
  tool established and what post-fact checking can recover of it; §6 turns
  that into a procedure for finding the next one.
- [`catalogue.md`](catalogue.md) — **one agreement, everything**, GENERATED.
  Per agreement: subject, claim, obligation basis, status, fault tag, the
  sentence a counterexample refutes, what it is held against, and per method
  what it compares, against what, where it fires and what it READS in each
  world, what falsifies it, and what a pass does not establish. `make
  agreement-catalogue` rewrites it; a pin fails if it drifts from the
  registry.
- [`model.md`](model.md) — **the model.** What an agreement is, what
  separates a claim from the methods that check it, the eight outcomes
  and why there are eight (§1); and how a running step gets from its own
  action to a set of outcomes (§2).
- [`components.md`](components.md) — **why each agreement exists.** A
  walk over the five kinds of thing a binding world is made of —
  artifacts, bindings, versions, packaging, deployment — saying for each
  what could be claimed, what observation is available and what it does
  not establish. Every registry row's `ag_doc` anchor points here, and
  `agreements.doc_anchors_exist` fails if a cited section stops
  existing.
- [`landing.md`](landing.md) — **landing one, end to end.** The eight
  points where a run consults the registry, the four failure modes behind
  an `unavailable`, the dummy action, the checklist, the four undecided
  states and what each means for the work, the distance-0 backlog, and
  `--strict`. It absorbed `pipeline.md` on 2026-09-17, when the tracker's
  per-agreement table became generated and what was left of it was that
  walkthrough's tail.
- [`landing.md`](landing.md) — **what is left.** Per agreement, what it
  is waiting on; the four undecided states and the four kinds of work
  they mean; the distance-0 backlog. It does NOT carry a landed/not
  table — `canary checks --landing` does, and the hand copy that used to
  sit here went stale and contradicted itself.

## See it rather than read it

```sh
canary checks --agreement NAME       # ONE agreement's complete record
canary checks                        # the catalogue, grouped by subject
canary checks --catalogue            # every agreement, its reference expectation, its methods
canary checks --firing               # the agreement × action grid
canary checks --landing              # planned vs effective
canary checks --dummies              # every DUMMY ACTION and why it is empty
canary checks <project>              # what this project's actions select, what ran, and the GAP
canary checks <project> --observed   # what its LAST RUN actually evaluated
canary result <project>              # the scenario × check table, with blame counted

```

The last two are the pair that matters. The first says what would be
checked; the second says what was. They disagreed for every agreement on
every real project until 2026-09-12, and only the second could tell.

## Which table is which

Three docs here carry tables and they answer different questions. If you
only want one: **[`catalogue.md`](catalogue.md)**, which is generated and
complete.

| table | in | answers |
| --- | --- | --- |
| **what each one recovers** | [`catalogue.md`](catalogue.md) | the registry at a glance — action, tool, artifact, planned status. Start here |
| per-agreement records | [`catalogue.md`](catalogue.md) | what IS this agreement — claim, whose rule it recovers, where it looks, worked examples |
| the distance-0 backlog | [`landing.md`](landing.md) | which unregistered checks are cheapest to add |
| full-information per action | [`theory.md`](theory.md) §5 | what each real tool established, and what survives of it |
| **why an agreement exists** | [`components.md`](components.md) | the per-component rationale each `ag_doc` anchor points at |
| **planned vs effective** | `canary checks --landing` | which ones a real run has decided. Not copied into any file — see below |
| **what is done, and what is left** | [`catalogue.md`](catalogue.md) | per agreement, what is in its way — GENERATED from `ag_waiting_on`, so it cannot go stale the way the hand-maintained version did |
| agreement × action | `canary checks --firing` | where each one fires |
| **scenario × check** | `canary result [<project>]` | what each agreement DECIDED, per world — check columns interleaved with the actions, `pre → action → artifact → post`, one agreement per cell, plus a counted **blame** for every cell that carries no verdict |
| **could vs did, per project** | `canary checks <project>` | every action the project derives, every agreement that fires there, what the runs decided — ending in a five-class gap summary (`decided` / `could not` / `never asked` / `stood down` / `no evaluator`) |

**And one rule about tables:** a table the tool generates does not get a
hand copy. Three did — `registry.md` §1.7, `registry.md` §7.4.1 and
`landing.md`'s effective table — and all three had gone stale in the same
direction, still reporting `declared_symbols_exported` as `unavailable`
months after it began deciding on sqlite and catching a real violation.
That is why `registry.md` is gone, and why the per-agreement status
table `landing.md` used to keep by hand is generated into the catalogue
now (2026-09-17).

## Two claims worth keeping apart

[`theory.md`](theory.md) says what an agreement *is*; the rest of this
directory says which ones exist and whether they run. The first is a claim
about software; the second is a claim about this repository. Confusing them
is how a catalogue comes to describe checks that never executed.

## And a third — an agreement is not a harness assertion

An agreement is a claim about **the project's artifacts**: what the library
exports, what the stub requires, what the package contains. Canary also makes
claims about **itself** — that the switch holds the pin this scenario
declares, that the probe reported the library this world placed, that the
source tree is at the declared ref. Those are **world assertions**
(`Canary_world.Log_names`, `Opam_pin`, `pin_check_post`), and they are not
agreements however much they look like one.

They fail differently, and that is the test. A violated agreement is a
finding *about the software*. A failed world assertion means *this run tested
something other than what it says*, and every verdict in it is suspect. Put
the second on the first's list and "our harness misconfigured itself" ends up
ranked beside "this library dropped a symbol".

When it is not obvious which you have, ask `ag_rooted_in`'s question: **whose
rule does it recover?** If the answer is "canary's own", it is an assertion.
Worked through for `source_is_declared_ref` in [`theory.md`](theory.md) §7.1,
which is the case that looks most like an agreement and is not one.

## The rule this directory exists to enforce

> An agreement is landed when a **real project's log** shows it `holds` or
> `violated`, and a deliberate break flips it the other way.

Not when the comparator exists. Not when the fixture passes. Not when the
catalogue describes it. Those are all necessary and none of them is
evidence that anything was checked.

## Related

- [`../enumeration/README.md`](../enumeration/README.md) — where worlds come
  from; an agreement's firing and evidence both depend on the world.
- [`../check_evaluation.md`](../check_evaluation.md) — the proposal for
  explicit check actions across backends.
- [`../staged_parity.md`](../staged_parity.md) — build tree vs install
  prefix as a checking principle.
