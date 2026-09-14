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

## Which file

| you are… | read |
| --- | --- |
| meeting the idea | this file, then `registry.md` §1 |
| **asking why there is anything to check** | [`theory.md`](theory.md) |
| **looking for the NEXT agreement** | [`theory.md`](theory.md) §5–§6 |
| **asking what one agreement IS** | [`catalogue.md`](catalogue.md), or `canary checks --agreement NAME` |
| landing an agreement on a project | [`pipeline.md`](pipeline.md) |
| asking what is actually in use | [`landing.md`](landing.md), or `canary checks --landing` |
| writing the paper | `registry.md` §§2–6 — the component walk |
| debugging an `unavailable` | [`catalogue.md`](catalogue.md) for where it looks, then [`pipeline.md`](pipeline.md) points 3–4 |

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
- [`registry.md`](registry.md) — **the model.** What an
  agreement is (§1), the catalogue (§1.7), the component walk over
  artifacts, bindings, versions, packaging and deployment (§§2–6), and
  registry integration with its open items (§7).
- [`pipeline.md`](pipeline.md) — **a project end to end.** The seven points
  where a run touches the registry, the four failure modes that make an
  agreement report `unavailable`, and the checklist for landing one.
- [`landing.md`](landing.md) — **the tracker.** Planned (from the registry)
  beside effective (from run logs), per agreement, with what each is
  waiting on.

## See it rather than read it

```sh
canary checks --agreement NAME       # ONE agreement's complete record
canary checks                        # the catalogue, grouped by subject
canary checks --catalogue            # every agreement, its reference expectation, its methods
canary checks --firing               # the agreement × action grid
canary checks --landing              # planned vs effective
canary checks --dummies              # every DUMMY ACTION and why it is empty
canary checks <project>              # what this project's actions would select
canary checks <project> --observed   # what its LAST RUN actually evaluated
```

The last two are the pair that matters. The first says what would be
checked; the second says what was. They disagreed for every agreement on
every real project until 2026-09-12, and only the second could tell.

## Which table is which

Four docs here carry tables and they answer different questions. If you only
want one: **[`catalogue.md`](catalogue.md)**, which is generated and complete.

| table | in | answers |
| --- | --- | --- |
| **what each one recovers** | [`catalogue.md`](catalogue.md) | the registry at a glance — action, tool, artifact, planned status. Start here |
| per-agreement records | [`catalogue.md`](catalogue.md) | what IS this agreement — claim, whose rule it recovers, where it looks, worked examples |
| effective | [`landing.md`](landing.md) | which ones actually run |
| the distance-0 backlog | [`landing.md`](landing.md) | which unregistered checks are cheapest to add |
| full-information per action | [`theory.md`](theory.md) §5 | what each real tool established, and what survives of it |
| the summary catalogue | [`registry.md`](registry.md) §1.7 | a one-line index — largely superseded by `catalogue.md` |
| agreement × action | `canary checks --firing` | where each one fires |

## Two claims worth keeping apart

[`theory.md`](theory.md) says what an agreement *is*; the rest of this
directory says which ones exist and whether they run. The first is a claim
about software; the second is a claim about this repository. Confusing them
is how a catalogue comes to describe checks that never executed.

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
