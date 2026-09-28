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

| kind           | asserts                                                                                                                                |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `admissibility` | are these artifacts an ADMISSIBLE input tuple for some action — would the tool have accepted them together?                           |
| `promise`      | is this ONE artifact what its own producer said it would be? Nothing is matched                                                        |
| `quality`      | is it sound on its own terms, whatever it is paired with? No second side at all                                                        |
| `preservation` | still the same thing after a transformation? Two COPIES of one artifact, so no disagreement between distinct components can violate it |
| `behaviour`    | does running it produce what was specified? The only kind whose evidence is an execution                                               |
| `composition`  | a verdict over other verdicts, asserting nothing of its own                                                                            |

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

### Auditing a row

Every cell of the overview is derived, so most of it can be wrong in a
way no build error catches: a kind that disagrees with the row's
targets, an `implemented at` naming a function that moved, an object
cell that narrows nothing and says so anyway.

The laws each row must satisfy are **data**, in
`Canary_agreement.row_rules` — a name, the law in one sentence, and the
complaint when a row breaks it. `canary checks --firing` prints them
beside the table with any violation;
`agreements.rows_obey_their_own_laws` fails the build on one. The list
is meant to grow: a rule added there is enforced without touching a
test, and it is not copied here, so it cannot go stale.

A law relates **two cells of one row**. Single-cell facts (does this
function exist, does this anchor resolve) are ordinary pins, and so are
facts across rows (is a claim's target count the same under every
mechanism).

**Saturation — is anything unwatched?** The row laws ask whether a row
is self-consistent. `canary checks --firing` also prints the question no
row can ask, because the overview is organised by claim and an absence
has no row to appear in: the modelled world is the product of the
catalogue's five mechanisms and the two object formats, and a cell
nothing covers is a combination canary can enumerate, build and run
while checking nothing about it.

Coverage counts an unimplemented claim — an absent one means nobody has
looked, a planned one means somebody has. Every cell is covered today;
`agreements.every_mechanism_format_cell_is_watched` fails on the first
that is not, which is what makes adding a sixth mechanism say so.

⚠ **The grid cannot see a finer asymmetry**, so the report names it
underneath: two claims are specific to ELF and **none is specific to
Mach-O**, although Mach-O has a version gate with no ELF counterpart —
`compatibility_version` in `LC_ID_DYLIB`, which `inspect_native.py` has
extracted since the macOS port and no agreement reads. Every cell looks
covered because the format-neutral claims cover them all; what is
missing is a claim that uses what only Mach-O has. It is in the
candidate table.

**Why an `admissibility` claim can show one target.** Such a claim is
about a TUPLE, and the ▣ columns count artifact TARGETS, so a member of
the tuple that is a DECLARATION contributes none. Five of the six show
two artifacts; `api_names_present` shows one because its other member is
the watchlist, standing in for the application's uses. The law encodes
exactly that exception — one target is honest only when some method
references a declaration — so a future one-target admissibility claim
without one is a complaint rather than a precedent.

### The short code, and why rows repeat it

The code (`dse`, `rse`) names the AGREEMENT; an overview row is a
(language, mechanism) PATTERN, so one claim can occupy several rows and
they all carry the same code. That is safe because **nothing downstream
keys on the code** — it is a display label, and the thing that
disambiguates is always the step or the column:

| | what tells two patterns apart |
| --- | --- |
| the log | the step tag. A line is `<tag> agreement_outcome (<slug>/<method>: <label>)`, and the tag carries the language |
| the result matrix | the column, which is (action, stage, code); the action carries the language, so `build_binding_ocaml_pre:rse` and `probe_binding_python_pre:rse` are different columns. The worst-wins merge happens only WITHIN one |
| the cache | nothing — neither the code nor the agreement enters a step fingerprint. Verdict markers are per step, and two patterns are two steps |

⚠ **The mechanism is recoverable, not recorded.** Nothing writes it
down: the log gives a language and the reader infers the mechanism from
the project's spec. That inference is sound only while a project
declares one mechanism per language, and **tiny-full already declares
two for Python** (`Cext` and `Ctypes`, deliberately — it is the witness
project). `Probe_binding` carries a language and no mechanism, so both
realize ONE `probe_binding_python` step: one log tag, one matrix column,
and `mechanism_for` returns the first, so pass 2 never asks about the
second. The artifact axis distinguishes them and the action axis does
not. `analysis.one_mechanism_per_language` names tiny-full as the known
case and fails on a second one.

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
The log records `agreement_outcome` events, from which the result table is read
(`canary result`, and the result table on the overview page).
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
[action_model.md](../action_model.md), whose §6 states this seam from the
other side and names the one place it is crossed in code —
`binding_evidence_tag` / `lib_evidence_tags`, which live here and are
occasion facts awaiting derivation, not relocation.

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
