# Agreements

**Start with the Agreement overview in `canary result` (`make view`).**
It is the reference for which claims exist, their targets and originating
rules, where they are checked, what is implemented, and what runs decided.
The candidate table records proposed claims and their blockers. We do not
maintain another catalogue or status list in these docs.

For a row's full claim, evidence, limits, and examples — and for where
its code is, both halves:

```sh
canary checks --agreement NAME
```

That record's `declared at` names the value holding the agreement's
METADATA (kind, subject, claim, rooting, methods) and the overview's
`implemented at` names its EVALUATOR. Both are derived rather than
stored: every agreement binds as `let <slug> : agreement` in its family
file, which `agreements.metadata_is_declared_under_its_slug` keeps
true.

The remaining documents explain what the table cannot:

- [theory.md](theory.md): why recombining artifacts creates something to
  check, and how to find claims by following build actions.
- [components.md](components.md): why particular evidence is useful and
  where it stops, including the ncurses counterexample.
- [mechanism.md](mechanism.md): which evidence a binding mechanism can
  supply, and the provider-linkage cases not yet modeled.

## 1. What a row means

An **agreement** is a falsifiable claim about artifacts or an execution.
A **method** is a way of checking it from available evidence. One agreement
can have several methods and occupy several overview rows when firing
differs by mechanism. A pass covers only that method's stated scope;
matching symbol names does not establish correct types or behaviour.

Keep three questions separate, because two of them shared a field until
2026-09-17 and the confusion outlived it. `ag_kind` says **what the claim
asserts**; `m_reference` says **what a method compares against** — an
artifact, declaration, peer, sibling world, or test suite; `ag_rooted_in`
names **the tool's original rule and action**. They are independent:
`api_names_present` is a PAIRING claim whose method uses a declared
watchlist to approximate an application's uses, so its kind and its
reference disagree and both are right.

`ag_kind` is the overview's `kind` column, and the six values are model
vocabulary rather than a list of agreements, so they are defined here:

| kind | asserts |
| --- | --- |
| `pairing` | could these two artifacts have been the inputs of ONE action — would the tool have accepted the pair? |
| `promise` | is this ONE artifact what its own producer said it would be? Nothing is matched |
| `quality` | is it sound on its own terms, whatever it is paired with? No second side at all |
| `preservation` | still the same thing after a transformation? Two COPIES of one artifact, so no disagreement between distinct components can violate it |
| `behaviour` | does running it produce what was specified? The only kind whose evidence is an execution |
| `composition` | a verdict over other verdicts, asserting nothing of its own |

Which agreements are which is the overview's business, not this
document's. The table's legend repeats these definitions beside the
data, and `canary checks --agreement NAME` prints one row's `asserts`
with the rest of its record.

Authority matters when interpreting a violation. A declaration mismatch
implicates the artifact only if the declaration is trusted; a peer mismatch
initially implicates the pairing. Version direction helps explain a failure
but does not exclude packaging or environment faults.

World assertions answer a different question: did Canary realize the world
it says it tested? A wrong package pin or source ref calls the run's evidence
into question. It is not an agreement finding about the tested software.

## 2. Reading a result

Only `holds` and `violated` are decided comparisons. Other labels distinguish
missing evidence (`unavailable`), a missing declaration (`undeclared`),
nothing of that kind to check (`vacuous`), and evidence that cannot settle
the comparison (`inconclusive`). `not_implemented`, `disabled`,
`not_applicable`, and `error` explain why evaluation did not decide.
These ten labels come from eight outcome constructors: `Unavailable` has
three typed causes.

A finding and a step verdict are separate. Normally an `Expect_success`
step passes when its command and postcondition succeed, even if an agreement
finds a mismatch. An expected-failure test can confirm a finding by observing
its predicted diagnostic. `--strict` instead fails the step that observes a
violation; intentional mismatch worlds can therefore fail correctly in that
mode. Strict and permissive verdicts have different cache fingerprints.

The overview's implementation and observed-result columns are also separate:
an evaluator can exist without ever reaching useful evidence. A cached step
does not re-evaluate methods or emit fresh outcomes. Inspect a last run with
`canary checks <project> --observed`; its skip count explains coverage lost
to warm steps. [matrix.md](../matrix.md) owns the table layout and cell legend.

## 3. Where results come from

Project analysis determines which claims a mechanism can carry. Realization
places inspections and attaches a world, language, and mechanism to steps.
The runner's `evaluate_step` selects firing, suitable methods, resolves their
evidence, and merges results into one record used by reporting and acceptance.
The log records `agreement_outcome` events, from which the result page is read.
The full pipeline belongs to [enumeration/](../enumeration/README.md), with
applicability in pass 2 and firing/evidence placement in pass 6.

Compat expectations can also supply explicit evidence paths for layouts the
derivation cannot express. Both routes use the same evaluators; a violation
outranks a holding result, and a decided result outranks an undecided one.
Readers select inspection files by their declared kind. A fetched binding's
evidence is normally at its fetch step, a built binding's at its build step.

Local checks are not all rendered into GitHub Actions: some symbol checks
and expected-failure verification are, but local pre/postcondition closures
and the full agreement record are not. The remaining backend work belongs to
[check_evaluation.md](../check_evaluation.md).

## 4. Making a row decide

Use the overview to choose an unimplemented or undecided claim and read its
blocker. If the specification is missing, state the claim and falsifier
first. If the method exists, inspect `canary checks <project>` and
`canary emit <project> --stage realize`: the chosen world needs both a firing
action and the inspections that method reads, ordered before the reader.

Run with the deciding step uncached, inspect `--observed`, introduce a
controlled counterexample, then restore the good case. A landing needs the
same real-project check to flip between `holds` and `violated`. Fixtures
alone cannot show that the project's evidence reaches the comparator.

`make canary-refresh PROJECT=<project>` refreshes probes, binding builds,
and staging. Fetches and library builds stay warm, so changing evidence
produced there requires rerunning that producer too. `--strict` is useful
for debugging. Update the registry blocker when resolved; fresh runs supply
the overview's observed outcomes.
