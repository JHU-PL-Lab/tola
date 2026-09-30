# Agreements

**Start with the agreement table, section 2 of the overview page
(`make view`).** It is the reference for which claims exist, their
targets and originating rules, where they are checked, what is
implemented, and what runs decided; sections 2.1 and 2.2 also place the
candidates, the claims proposed with no evaluator. We do not maintain
another catalogue or status list in these docs.

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

This document explains what the table cannot, in two parts. §1–§4 are
for using it: what a row means, reading a result, where results come
from, and making a row decide. §5–§8 are where agreements come from: why
there is anything to check, what each action establishes and what
survives it, how to find the next agreement, and what this frame does
not explain. [components.md](components.md) walks the same ground
component by component — why particular evidence is useful, where it
stops, and what each binding mechanism can supply.

## 1. What a row means

An **agreement** is a falsifiable claim about artifacts or an execution.
A **method** is a way of checking it from available evidence. One agreement
can have several methods and occupy several rows of the table when firing
differs by mechanism. A pass covers only that method's stated scope;
matching symbol names does not establish correct types or behaviour.

Keep three questions separate. `ag_kind` says **what the claim
asserts**; `m_reference` says **what a method compares against** — an
artifact, declaration, peer, sibling world, or test suite; `ag_rooted_in`
names **the tool's original rule and action**. They are independent:
`api_names_present` is a PAIRING claim whose method uses a declared
watchlist to approximate an application's uses, so its kind and its
reference disagree and both are right.

`ag_kind` is the table's `kind` column. Its legend defines the six
values beside the data, and `canary checks --agreement NAME` prints one
row's `asserts` with the rest of its record.

Authority matters when interpreting a violation. A declaration mismatch
implicates the artifact only if the declaration is trusted; a peer mismatch
initially implicates the pairing. Version direction helps explain a failure
but does not exclude packaging or environment faults.

## 2. Reading a result

The key under the agreement table lists every label a log records, its
mark in the result table, and the blame it can carry; the note above the
table says how a finding differs from a failed step and from a failed
world assertion. Only `holds` and `violated` are decided comparisons.
The ten labels come from eight outcome constructors: `Unavailable` has
three typed causes.

### Auditing a row

Every cell of the table is derived, so most of it can be wrong in a
way no build error catches: a kind that disagrees with the row's
targets, an `implemented at` naming a function that moved, an object
cell that narrows nothing and says so anyway.

The laws each row must satisfy are **data**, in
`Canary_agreement.row_rules` — a name, the law in one sentence, and the
complaint when a row breaks it. The page lists them under the agreement
table's verdict line; `canary checks --firing` prints them with any
violation; `agreements.rows_obey_their_own_laws` fails the build on one.
The list is meant to grow: a rule added there is enforced without
touching a test, and it is not copied here, so it cannot go stale.

A law relates **two cells of one row**. Single-cell facts (does this
function exist, does this anchor resolve) are ordinary pins, and so are
facts across rows (is a claim's target count the same under every
mechanism).

**Saturation — is anything unwatched?** The row laws ask whether a row
is self-consistent. `canary checks --firing` also prints the question no
row can ask, because the table is organised by claim and an absence
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
missing is a claim that uses what only Mach-O has — the candidate
`compatibility_version_satisfied`.

**Why an `admissibility` claim can show one target.** Such a claim is
about a TUPLE, and the ▣ columns count artifact TARGETS, so a member of
the tuple that is a DECLARATION contributes none. Five of the six show
two artifacts; `api_names_present` shows one because its other member is
the watchlist, standing in for the application's uses. The law encodes
exactly that exception — one target is honest only when some method
references a declaration — so a future one-target admissibility claim
without one is a complaint rather than a precedent.

### The short code, and why rows repeat it

The code (`dse`, `rse`) names the AGREEMENT; a row of the table is a
(language, mechanism) PATTERN, so one claim can occupy several rows and
they all carry the same code. That is safe because **nothing downstream
keys on the code** — it is a display label. In the log, the step tag
tells two patterns apart: a line is
`<tag> agreement_outcome (<slug>/<method>: <label>)`, and the tag carries
the language. In the result table (section 1.2) a row is one chain in
one language, so a check cell holds one pattern. And neither the code
nor the agreement enters a step fingerprint: verdict markers are per
step, and two patterns are two steps.

⚠ **The mechanism is recoverable, not recorded.** Nothing writes it
down: the log gives a language and the reader infers the mechanism from
the project's spec. That inference is sound only while a project
declares one mechanism per language, and **tiny-full already declares
two for Python** (`Cext` and `Ctypes`, deliberately — it is the witness
project). `Probe_binding` carries a language and no mechanism, so both
realize ONE `probe_binding_python` step: one log tag, one result cell,
and `mechanism_for` returns the first, so pass 2 never asks about the
second. The artifact axis distinguishes them and the action axis does
not. `analysis.one_mechanism_per_language` names tiny-full as the known
case and fails on a second one.

An expected-failure test can confirm a finding by observing its predicted
diagnostic. Under `--strict`, intentional mismatch worlds fail correctly,
and strict and permissive verdicts have different cache fingerprints.

The table's implementation and observed-result columns are also separate:
an evaluator can exist without ever reaching useful evidence. A cached step
does not re-evaluate methods or emit fresh outcomes. Inspect a last run with
`canary checks <project> --observed`; its skip count explains coverage lost
to warm steps. The keys beside the result table and the agreement table
explain the cells.

## 3. Where results come from

Project analysis determines which claims a mechanism can carry. Realization
places inspections and attaches a world, language, and mechanism to steps.
The runner's `evaluate_step` selects firing, suitable methods, resolves their
evidence, and merges results into one record used by reporting and acceptance.
The log records `agreement_outcome` events, from which the result table on the
overview page is read (`canary overview --json` prints the record it draws).
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

Use the table to choose an unimplemented or undecided claim and read its
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
the table's observed outcomes.

## 5. Where agreements come from

Why there is anything to check at all, and what an agreement *is* in
terms of the actions that build software. This part does not describe
what canary runs. It describes the thing canary is an implementation of,
so that a reader who never sees the code can tell whether the
implementation is looking in the right places.

### 5.1 Nothing to check, in an ideal world

Take a project where every file has exactly one copy and every artifact is
rebuilt from source in dependency order. The header the library was compiled
against *is* the header on disk. The binding was compiled against *that*
library. The application was compiled against *that* binding. For the
relations those tools actually enforce, no recombination has invalidated
the build's evidence. This does not rule out bugs or unspecified behaviour.

Real worlds are not like that, for reasons that have nothing to do with
carelessness. A library arrives prebuilt from a distribution. A binding
arrives from a language package manager that compiled it, months ago, on
another machine, against a library nobody here has. Headers come from a
`-dev` package whose version is chosen by a solver. Each of these is a
reasonable thing to do, and each one replaces a file that a build *produced*
with a file that merely *resembles* it.

**Checking exists because artifacts are recombined across the boundaries of
the builds that made them.**

### 5.2 What an action establishes

Model a build step as a function

```text
A : I₁ × … × Iₙ  →  O
```

Its implementation — a compiler, a linker, an archiver — embodies a relation
`R_A ⊆ I₁ × … × Iₙ`: the input tuples its rules accept. A C compiler rejects a
call that disagrees with a declaration; a linker rejects an undefined
reference. These rejections *are* `R_A`.

> **Running `A` on a tuple is a witness that the tuple is in `R_A`. Nothing
> else is.**

That witness is the full-information agreement of §6: at the moment the
action ran, the relation held over the actual files, checked by the actual
tool, with every input in hand.

Then the tuple is thrown away. What is kept is `O`, which carries the implicit
fact *some tuple in `R_A` produced me* without carrying the tuple. What
survives of the inputs is a **projection**: exported symbol names, a recorded
identity, version tags, sometimes debug information. Everything else — the
source, the declarations, the options — is gone.

### 5.3 What a check is

Recombination takes an `O` produced from tuple `t` and pairs it with an input
drawn from a different tuple `t′`. The hybrid may or may not be in `R_A`, and
`A` cannot be re-run to find out: the sources are gone, and in the next step
the output is an *input* (a `.so` is produced by the linker and consumed by the
next link).

So the question a checking tool faces is: **decide membership in `R_A` from
the projections that survived.** Hence:

> An **agreement** is a necessary condition for membership in some action's
> input relation, decidable from the artifacts' surviving evidence.

Three consequences, and they are the ones the catalogue keeps running into:

- **Necessary, not sufficient.** A pass cannot mean "compatible"; it means no
  counterexample within one projection. That is not a caveat about
  immaturity — it follows from the definition.
- **The agreement is rooted where the action ran, and detected later.** The
  pairing `(lib₁.so, v₂.h)` may compile perfectly at `build_binding`; it is
  wrong because no `build_lib` ever ran on `(v₂.h, …) → lib₁.so`. The action
  that owns the claim and the action where evidence is available are different
  actions.
- **One edge carries several agreements**, one per surviving projection, and
  each agreement admits several methods of observing it. Three levels:

```text
edge        (action, input → output)
  agreement   one per projection of the input that survives in the output
    method      one per way of observing it (read the artifact, run a tool, …)
```

### 5.4 Two kinds of loss

The information lost at an action divides in two, and the halves behave
differently enough to be worth separating.

|              | what is lost                       | remedy                                                       | ceiling                                                                                      |
| ------------ | ---------------------------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| **Identity** | *which* tuple produced this output | record it — hash, build id, soname, version tag, package pin | can be made **complete**: with enough recorded, you compare identities and need no inference |
| **Relation** | *what `R_A` required* of the tuple | re-implement a fragment of the tool's rule                   | only ever **partial**: completeness means re-implementing the compiler                       |

The distinction predicts which gaps are worth what. An identity gap is a
*recording* problem — it closes by writing more down, and it closes exactly. A
relation gap is a *checker* problem — it closes by degrees and never fully.
When a proposal is stuck, it is usually worth asking which of the two it is;
`denotation_stable_across_worlds` is stuck because it needs an identity
criterion, not a better comparator.

## 6. The full-information agreements, action by action

For each action in Canary's catalogue: the relation the real tool established
when it ran, what survives of it afterwards, and what post-fact checking can
recover. These are accounts of the tools' relations, not a landing-status
table; `canary checks --landing` reports what real runs have decided.

### 6.1 `fetch_source` — a resolver picks a tree

|                 |                                                                                                                                                                                          |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | git, or a package manager                                                                                                                                                                |
| **Established** | this tree is what that ref names, at that moment                                                                                                                                         |
| **Survives**    | the tree; the commit, *if* recorded                                                                                                                                                      |
| **Loss**        | identity                                                                                                                                                                                 |
| **Post-fact**   | re-resolve the ref and compare. Canary does this (`source_fetch_pinned_ref_check_post`), and because it is identity, it is **exact** — the rare case where checking is not approximation |

### 6.2 `configure` — a build system fixes a configuration

|                 |                                                                                                                                                                                                                                           |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | cmake, autoconf                                                                                                                                                                                                                           |
| **Established** | this build tree is configured for *these* sources, *this* toolchain, *these* options                                                                                                                                                      |
| **Survives**    | the build tree and its cache; the options, in a form nobody reads back                                                                                                                                                                    |
| **Loss**        | identity (which sources) and relation (which options the result assumes)                                                                                                                                                                  |
| **Post-fact**   | **not checked.** A build tree configured for source A and reused with source B is a recombination Canary does not currently look at. Its analogue is well known in practice — a stale `CMakeCache.txt` — and it is the candidate `build_tree_configured_for_source` |

### 6.3 `build_lib` — the compiler and linker

The central action, and the one with the richest surviving projection.

|                 |                                                                                                                                                                                                                                                                     |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | a C compiler, then a linker                                                                                                                                                                                                                                         |
| **Established** | (a) every call agrees with a visible declaration; (b) every referenced symbol is defined; (c) the output records the requested identity and the requested dependency list                                                                                           |
| **Survives**    | exported symbol names; version tags; the recorded soname; `NEEDED`; debug information, sometimes                                                                                                                                                                    |
| **Loss**        | relation, mostly — the declarations are gone and the definitions are compiled                                                                                                                                                                                       |
| **Post-fact**   | *names*: `declared_symbols_exported`. *types*: the DWARF comparison (the candidate `signatures_match_debug_info`; [`components.md`](components.md) §2.2) — the only route back to (a), and it depends on debug information being present. *identity of the output*: `soname_matches_declaration`, `declared_versions_exported` |

One projection is unclaimed: symbols the library exports that appear in
**neither** the headers nor this project's declaration. They came from
somewhere — a statically linked archive, a vendored copy — and no registered
agreement says so. Tiny already produces the fault (`symbol_orphan`), and the
candidate `exports_accounted_for` names it.

### 6.4 `install_lib` — staging

|                 |                                                                                                                                                                                                                                                                                                                                                                         |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | `cmake --install` and friends                                                                                                                                                                                                                                                                                                                                           |
| **Established** | the staged tree is a relocation of the build tree preserving the declared interface                                                                                                                                                                                                                                                                                     |
| **Survives**    | **both sides** — the build tree and the staged tree exist at once                                                                                                                                                                                                                                                                                                       |
| **Loss**        | almost none, while the run lasts                                                                                                                                                                                                                                                                                                                                        |
| **Post-fact**   | comparison is nearly complete *because nothing was lost yet*. Canary's `staged_interface_preserved` compares symbol counts, soname, RPATH/RUNPATH and NEEDED across the two; the fuller model is [`staged_parity.md`](../staged_parity.md). This is the one action where a checker can be almost as strong as the tool, and it is worth noticing why: the inputs are still there |

### 6.5 `build_binding` — the foreign-call boundary

|                 |                                                                                                                                                                                                                                         |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | the host compiler for the stubs, plus the language's archiver                                                                                                                                                                           |
| **Established** | the stub's `external` declarations agree with the header; the stub objects' undefined references name things the library is expected to define; the archive is internally consistent                                                    |
| **Survives**    | the stub archive's undefined references; the installed interface; for a shared-object binding, `NEEDED` and version requirements                                                                                                        |
| **Loss**        | relation                                                                                                                                                                                                                                |
| **Post-fact**   | `signatures_agree` (header ↔ stub types, from source scanning — the compiler's rule, re-implemented shallowly); `required_symbols_exported` (stub references ⊆ library exports — the linker's rule, re-implemented exactly *for names*) |

### 6.6 `fetch_binding` — the load-bearing one

|                 |                                                                                                                                    |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | opam, pip — and, earlier and elsewhere, a `build_binding` nobody here witnessed                                                    |
| **Established** | *in another world.* Some `build_binding` ran against some library, on some machine, at some version                                |
| **Survives**    | the installed artifacts and the package metadata — and **none of the other world's inputs**                                        |
| **Loss**        | both, maximally                                                                                                                    |
| **Post-fact**   | everything the catalogue has. This is where recombination actually happens in practice, and where the checks are most load-bearing |

Worth stating plainly, because it reorders priorities: in a world that builds
its library and fetches its binding, **the library↔binding edge is the only
one no toolchain ever established.** The source↔library edge was established
here; the binding↔application edge is established by the compiler that builds
the probe. One edge out of three, and it is the one whose checks are hardest
to supply evidence for.

### 6.7 `pack` / `publish` — packaging

|                 |                                                                                                                      |
| --------------- | -------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | opam, a wheel builder, a distribution's packaging                                                                    |
| **Established** | the package contains the artifacts the recipe named                                                                  |
| **Survives**    | the package                                                                                                          |
| **Loss**        | identity (which build tree) and relation (what the recipe required)                                                  |
| **Post-fact**   | completeness against a declared file list — the candidate `package_contains_declared_files`; Canary's staged-file checks are still hand-listed |

### 6.8 `build_app` — the consumer

|                 |                                                                                                                                                                                                                                                                          |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Tool**        | the language's compiler and linker                                                                                                                                                                                                                                       |
| **Established** | every name the application uses resolves on the binding's surface; the link succeeds                                                                                                                                                                                     |
| **Survives**    | the executable; its recorded dependencies                                                                                                                                                                                                                                |
| **Loss**        | relation                                                                                                                                                                                                                                                                 |
| **Post-fact**   | the application's used names ⊆ the binding's surface. Canary approximates this with a hand-written watchlist rather than the application's actual uses — an approximation worth revisiting, since the requirement could be derived from the source the way the stub's is |

### 6.9 `probe_*` — execution

|                 |                                                                                                                                                                                                                                                                                                                                                         |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tool**        | the dynamic loader, then the program                                                                                                                                                                                                                                                                                                                    |
| **Established** | every recorded dependency resolved to some object; every symbol bound to some definition; the program produced this output                                                                                                                                                                                                                              |
| **Survives**    | the output and the exit status. The *resolutions* — which object, which definition — survive only with instrumentation                                                                                                                                                                                                                                  |
| **Loss**        | relation, and identity of what was actually selected                                                                                                                                                                                                                                                                                                    |
| **Post-fact**   | behavioural expectations (`behavior_matches`, unimplemented — the expected values live inside the probe). The resolution half is where `dependencies_provided` stops and where `interposition_binds_build_target` and `denotation_stable_across_worlds` would begin; all three need a recorded resolution trace, which is the identity half of this row |

### 6.10 Reading the table

Three patterns fall out, and none was designed in:

1. **The strongest checks are where the least was lost.** `install_lib` can be
   checked nearly completely because both sides are still present.
   `fetch_binding` can be checked least well because nothing but the artifact
   survived.
2. **Identity rows close; relation rows converge.** `fetch_source` is *done* —
   re-resolving the ref settles it. `build_lib`'s type agreement will never be
   done, only deepened.
3. **Origin and observation site are separate.** A fetched consumer can be
   checked at a probe against a provider its original linker never saw.
   A producer-declaration check can instead run at `build_lib` itself.
   Recovering a rule does not require every check to have a later observation site.

### 6.11 Target and origin — a decomposition the table made visible

The agreement table (section 2 of the overview page, and
`canary checks --firing`) marks target artifact kinds with ▣ and rule
origins with R. Ask whether the originating action produces or consumes
the target:

Count the ▣ in a row and the claims fall into three groups — one
target, two targets, none — and the groups are worth reading off the
live table rather than listed here. Within the one-target group,
`build_lib` produces the library for the promise checks, `install_lib`
produces a copy for preservation, and application compilation consumes
the binding surface for `api_names_present`, so the second question
separates claims the first would have merged.

This decomposition helps find candidates, but it does not determine
`ag_kind` or `m_reference`. The promise and preservation examples both
show one artifact kind produced by an action, yet one compares against a
declaration and the other against a build-tree copy. The watchlist example
uses a declaration as evidence for a pairing. §1 defines those
independent axes.

Count instances separately from displayed kinds: a staging comparison has
two library instances and one kind column. Similarly, an absent target mark
on a planned row means its target has not been represented; it does not
establish that the intended claim has no subject. An empty grid cell is a
reason to investigate a relation, not proof that the relation is missing.

## 7. Finding the next agreement

§6's table is not only a summary — it is how to find the next agreement.
For each action, for each input, ask:

1. **Which earlier action produced this input?** That action's `R` is the
   relation at risk.
2. **Which projection of the input survives into the artifact I hold?** That
   projection bounds what any check can see.
3. **Is the pairing witnessed?** If the input and the artifact came from the
   same run, the tool already checked it and there is nothing to add. If they
   came from different runs, the pairing is asserted and unchecked.
4. **Is the loss identity or relation?** Identity gaps close by recording;
   relation gaps close by re-implementing a fragment of the rule.
5. **State the falsifier.** If you cannot say what observation would refute
   the claim, it is not yet an agreement.

Two checks that the procedure is sound before trusting it on new ground: run
on Canary's own chain, it re-derives the application-uses-⊆-binding-surface
claim that the watchlist currently approximates, and it re-finds the
orphan-export projection at `build_lib`, which the candidate
`exports_accounted_for` names. A procedure that re-finds known holes from first
principles is one worth pointing at unknown ones.

## 8. What this does not explain

Two things in the catalogue are not per-edge and do not fall out of this
model:

- **Set properties.** `no_duplicate_implementation` is about the whole
  resolved set, not about any one pairing. Nothing in §5.2 speaks about sets.
- **Cross-world properties.** `denotation_stable_across_worlds` compares two
  worlds. There is no single action whose relation it recovers; it is a claim
  about two runs of the same action, which this model has no vocabulary for.

Both are real and both are in the registry as proposals. The honest statement
is that the per-action frame covers most of the catalogue and that these sit
outside it — which is itself worth knowing, because it says they will not be
found by the procedure in §7 and need their own reasoning.

### 8.1 And one the procedure finds that is NOT an agreement

§7 run over `fetch_source` produces "the source tree is the ref the project
declared" (§6.1), and it looks like a textbook identity gap: recordable,
cheap, closes exactly. It is in the registry as the proposal
`source_is_declared_ref`.

It is the wrong category. An agreement is a claim about
**the project's artifacts** — what the library exports, what the stub
requires, what the package contains. "Is the tree at the commit we said" is a
claim about **whether canary realized the world it claims to be testing**.
That is harness self-verification, and canary already has a vocabulary for
it: the world assertions (`Canary_world.Log_names`, `Opam_pin`,
`pin_check_post`, z3's `SYSTEM LIB MISSING`) which assert that a scenario's
declared world was actually established.

The distinction matters because the two fail differently and are read by
different people. A violated agreement is a finding **about the software**;
a failed world assertion means **this run tested something other than what it
says**, and every verdict in it is suspect. Filing the second as the first
would put "our harness misconfigured itself" on the same list as "this
library dropped a symbol".

So §7 needs a filter it does not currently state: *whose* rule is being
recovered. `ag_rooted_in` already asks that question of every registered
agreement — and for §6.1 the honest answer is "canary's own", which is
exactly the signal that it belongs elsewhere.

Left in the registry as a proposal rather than deleted, with this note,
because the CHECK is worth having and the reasoning about where it lives is
the part that was missing.
