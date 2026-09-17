# The agreements — what there is, and what is left

**Kind: reference + status.** What canary checks today, what it cannot
check yet, and how a run gets from a step to a verdict.

## The answer, before the detail

**Canary has 13 implemented agreements. 8 of them are LANDED** — a real
project's run has decided them `holds` or `violated`, which is the only
evidence that a check works. The other 5 are implemented and have not
yet decided anything, for three different reasons:

| not landed | why | what would land it |
| --- | --- | --- |
| `signatures_agree` | reports `unavailable` on all seven projects that reach it: it needs the source-scanning inspectors, which no project wires | wire one project's header and stub scans |
| `declared_versions_exported` | reports `vacuous` — the libraries it reaches carry no symbol versioning, so there is nothing of that kind to compare | a project whose library uses a version script |
| `behavior_matches`, `repack_preserves_api`, `repack_complete` | **no evaluator, and no tool's rule to recover.** Nothing in a toolchain enforces that a function returns what a project expected | somebody to STATE a specification — not wiring |

That last row is worth reading twice. The three unimplemented agreements
are exactly the three with no `ag_rooted_in`, and it is not a
coincidence: an agreement re-checks a rule some tool once enforced, so
where no tool enforced anything there is nothing to re-derive. Prefer
landing a tool-rooted one.

**Beyond the 13 there are 8 proposals with no implementation at all**,
and they are not eight of a kind — four are held up by a schema field,
one has never been filed, one is not an agreement, and two are outside
the model entirely. §3 groups them by which.

Live answers, because this file is prose and those are computed:

```sh
canary checks --landing          # the table above, live
canary checks --firing           # the agreement overview, one screen
canary checks <p> --observed     # what one project's LAST run decided
canary checks --agreement NAME   # one agreement, complete
```

## How to read the rest

§1 is the model — what a claim is, and the eight outcomes an evaluation
can return. Read it if a word in §2 is unfamiliar; skip it otherwise.

**§2 and §3 are GENERATED** from the registry by `make
agreement-catalogue`, between the `<!-- BEGIN/END GENERATED -->`
markers, and pinned by `agreements.catalogue_doc_is_generated`. §2 is
every implemented agreement's complete record; §3 is everything with no
record. Edit the OCaml, never the region.

§4 walks one project end to end — the eight points where a run consults
the registry, each with the failure mode that shows up there. §5 is the
remaining work.

**This document and the agreement overview say the same thing at two
sizes.** The overview (`canary checks --firing`, `make view` table 1,
drawn per [`../matrix.md`](../matrix.md)) is one screen: same
agreements, same order — §2's n'th record is the table's n'th row — with
each claim's target artifacts, the action whose rule it recovers, and
where it actually fires. Where the two disagree the table is right; it
is generated and most of this is not.

| you want | read |
| --- | --- |
| **why** there is anything to check at all | [`theory.md`](theory.md) — the action walk |
| **why** one agreement exists | [`components.md`](components.md) — the component walk, at the anchor its registry row carries |
| **when** a check fires | [`../enumeration/stage6_realize_steps.md`](../enumeration/stage6_realize_steps.md) §2b — the occasion is the enumeration's, not this layer's |
| why a claim is `not_applicable` here | [`mechanism.md`](mechanism.md) §2 — the three facts that gate it |

---

## 1. What a claim is

### 1.1 Tool-grounded observations

Canary consumes observable facts from source parsers, binary inspectors,
compilers, linkers, loaders, package managers and probes. It does not reproduce
their semantics. A tool's successful exit establishes that the invocation
succeeded; inspecting its product checks additional claims, such as whether a
declared symbol was actually exported. Both observations can be useful.

### 1.2 Agreements are falsifiable

An **agreement** is a claim about artifacts or an execution. A **check** is an
observation that can refute that claim. State both the claim and its falsifier:
“declared exports are present” is refuted by a missing declared export.

A pass means no counterexample was found within the inspected properties or exercised run.
It does not establish general compatibility. Watchlists bound coverage; an
empty declaration or missing evidence must not be interpreted as successful
coverage.

#### 1.2.1 Evaluation outcomes

Evaluating one checking method produces exactly one of eight outcomes. They
exist because the previous API returned a list of predicted failure
substrings, and an empty list meant all of these at once.

| Outcome           | Meaning                                                            | Typical cause                                                                            |
| ----------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| `holds`           | No counterexample within this method's stated scope                | The comparison ran and agreed                                                            |
| `violated`        | A counterexample, carried as the names or messages that witness it | The comparison ran and disagreed                                                         |
| `unavailable`     | The method applies here, but required evidence was not produced    | No inspector ran, or its output is missing                                               |
| `inconclusive`    | Evidence is present and the comparison cannot decide               | An empty watchlist; a library with no symbol versioning                                  |
| `not_implemented` | A declared method with no evaluator, reported with the reason      | The claim has no agreed scope, or its expectation is not stated anywhere canary can read |
| `not_applicable`  | This mechanism or world offers no such claim                       | A static archive records no dependency, so identity checks have nothing to read          |
| `disabled`        | Switched off for this run                                          | `--disable-agreement`, or a project's opt-out                                            |
| `error`           | The evaluation itself failed                                       | A malformed summary, an unreadable file                                                  |

`holds` is bounded by the method's own scope, recorded as its `m_limits`
string and printed by `canary checks --catalogue`. It never means the pairing
is compatible.

Two consequences are load-bearing. A placeholder never reports success: a
method with no evaluator returns `not_implemented` carrying the reason, and
the registry pin rejects an empty reason. And `not_applicable` is distinct
from `unavailable` — collapsing them is how a missing inspector reads as a
passing check.

A `violated` outcome always carries a witness. Everything downstream assumes
it — the diagnostics a failing run is greppable for, the confirmation split in
§1.2.2, and the acceptance policy that requires a step to fail *with that
signature*. A finding list that was empty would strengthen a step's requirement
while supplying nothing to check it against, so `normalize_outcome` maps that
case to `inconclusive` and every path to an outcome goes through it.

Predicting the text a failing log will contain is a separate step from
evaluating the agreement. A method's evaluator produces the outcome; its
`m_diagnostics` turns a `violated` outcome into the substrings a run's output
is expected to carry. They differ where a tool spells a name its own way: the
watchlist agreement's finding is `Llvm.Opcode.UncondBr`, and its diagnostics
are that plus the shorter forms a compiler actually prints.

#### 1.2.2 A disagreement and an expected-failure test are different facts

An agreement is violated by the **artifacts**. A step is accepted or rejected
by **this run**. Either can happen without the other, and a checking tool that
let one stand for the other would be unable to say which it had observed.

|                                | The artifacts disagree                                                                              | The artifacts agree                     |
| ------------------------------ | --------------------------------------------------------------------------------------------------- | --------------------------------------- |
| **This run's output shows it** | `confirmed` — the expected-failure test observed the disagreement; this is what the verdict records | not reachable: there is nothing to show |
| **This run's output does not** | `unconfirmed` — the finding stands, this action was simply not where it surfaces                    | the ordinary passing step               |

A step can also pass as an expected failure with nothing confirmed: the command
failed, no agreement predicted it, and a fallback accepted the failure anyway.
That is recorded as an unattributed expected failure rather than credited to an
agreement.

The consequence for acceptance is that a detected disagreement does not by
itself decide a step. An `Expect_success` step whose artifacts disagree still
passes on its own postcondition, and the disagreement is reported as
`unconfirmed`. Changing that would change what every existing project's steps
accept, and is a scope decision, not a consequence of the model.

### 1.3 Earliest observation, later confirmation

Observe an agreement as early as its evidence permits:

```text
inspect an artifact → compare requirements → compile/link/load → run a probe
```

These can be observations of the same agreement, with different coverage and
cost. A runtime failure missed by earlier checks can expose a missing static
observation, but some behavioural properties require execution.

### 1.4 Caching is outside the agreement model

The agreement specifies the claim and evidence. Reusing an observation is an
execution concern; a stale cached verdict is an execution bug. Evidence still
needs artifact and world provenance so that the check compares the intended
inputs.

### 1.5 A claim is separate from its checking methods

An agreement states a claim. A **checking method** is one way to observe it.
The two are separate records because one agreement can have several methods
with different evidence, different scope and different implementation status,
and a single status field could not say which of them was working.

A method declares four things: what it compares (`m_kind`), what it compares
against (`m_reference`), where its evidence becomes available (`m_firing`,
over the action catalogue) and what it reads there (`m_inputs`). It then
either carries an evaluator or says why it does not (`m_planned`), and states
what a pass does not establish (`m_limits`).

| Method kind   | What it does                                 | What a pass establishes                        |
| ------------- | -------------------------------------------- | ---------------------------------------------- |
| `inspect`     | Reads one artifact's properties or presence  | The observed facts satisfy that claim          |
| `compare`     | Inspects several artifacts and compares them | The compared facts satisfy the stated relation |
| `run-tool`    | Compiles, links or loads                     | The exercised operation accepted these inputs  |
| `run-program` | Runs a probe and inspects its result         | This execution met its expectation             |

Comparing two artifacts is different from actually linking or loading them.
Likewise, inspecting a Python module with `dir()` requires importing it: its
target is the module’s available names, but obtaining the evidence involves execution.

The reference is the other half. Comparing an artifact with the project's
declaration and comparing it with a consumer's own recorded requirement are
different findings with different attribution, even when the comparison is the
same set difference.

| Reference       | The observation is held against                    |
| --------------- | -------------------------------------------------- |
| `artifact`      | The artifact's own format rule; no second party    |
| `declaration`   | What the project declared                          |
| `peer`          | The other artifact in this world                   |
| `sibling-world` | Corresponding evidence retained from another world |
| `test-suite`    | An upstream or translated suite's expected results |

### 1.6 Source of the claim and attribution

Every check needs an authority against which an observation can disagree. Each
agreement records which kind of authority, as its `ag_basis`: a
`toolchain-rule` holds of every project using the format; a
`project-declaration` is something this project said; a
`compatibility-policy` is a stated preservation rule between versions or
worlds; a `behavioral-spec` is an expectation about what running it produces.

| Source                  | Example claim                                  | Available when                                      | Attribution on failure                                       |
| ----------------------- | ---------------------------------------------- | --------------------------------------------------- | ------------------------------------------------------------ |
| Self / format           | The artifact has the declared format           | A resource is observable                            | Artifact or inspector                                        |
| Project declaration     | The library exports a watchlisted name         | The declaration exists                              | Artifact or declaration; state which is trusted              |
| Peer artifact           | A consumer's requirements are provided         | Both required observations are available            | The pairing; use version and packaging evidence to narrow it |
| Sibling world           | Two provisions preserve a specified property   | Corresponding evidence from both worlds is retained | Provisioning or the declared preservation rule               |
| Prior version           | A promised interface is preserved              | A baseline and preservation policy exist            | The change relative to that policy                           |
| Upstream statement      | The artifact meets upstream's manifest or test | That statement is available                         | Artifact, statement or its interpretation                    |
| Behavioural expectation | A probe returns the expected result            | The probe can run                                   | The exercised world; further evidence may localize the fault |

The design calls for checks wherever the claim and required evidence are
available. Availability is not guaranteed merely because a family exists.
In particular, a 2×2 matrix contains **separate worlds**: an individual
assignment selects one placement per artifact. Comparing sibling worlds needs
an explicit correspondence and retained evidence from both.

### 1.7 Names, and where the catalogue lives

Agreements are identified by a descriptive name. The numbered `c1`..`c9`
identifiers were retired on 2026-09-12: they said nothing, could not be read
in a log, and — worse — made two different claims share one identity whenever
a family checked an artifact both against a declaration and against a peer.
Those were called the "solo" and "pair" cells, and calling them cells hid that
they have different references, different evidence and different attribution.
They are separate agreements now. **Solo and pair are not part of an
agreement's identity; distinct claims get distinct names.**

Names are load-bearing rather than cosmetic. They appear in `actions.log`, in
the verdict markers that persist an expected failure's attribution across
runs, in `--disable-agreement`, and here. The retired spellings deliberately
do not parse, so a stale marker or an old command line fails visibly instead
of resolving to something.

The repacking pair keeps **provisional** names: what "preserves" and "loses
nothing" permit is undecided ([`components.md`](components.md) §6.3.1), and a name should not settle a claim
the catalogue has not.

Proposed agreements have no method at all: `denotation_stable_across_worlds`
needs an observable correspondence between implementations;
`no_duplicate_implementation` needs an identity/containment policy;
`interposition_binds_build_target` needs a resolution trace and expected target.

Framework checks and future checking methods are not all registered yet.
Their existing and planned observations belong with the component
discussions in [`components.md`](components.md), rather than in a second
catalogue organized by different criteria.

**The catalogue itself is not here.** It is
§2 below, generated by `make agreement-catalogue`
and pinned by `agreements.catalogue_doc_is_generated`, and it carries
every agreement with its subject, claim, obligation basis, the tool's
rule it recovers, each method's kind, reference, firing sites, scope
limits and worked examples. A hand-written summary of it used to sit in
this section; it is gone for the reason at the top of this file.


### 1.8 Where the next agreement comes from

Two generative frames, on different axes, and a candidate is worth
checking against both.

- **By action** — [`theory.md`](theory.md) §5–§6. For each action, which
  earlier action produced this input, which projection of it survives,
  is the pairing witnessed, and is the loss identity or relation. It
  re-derives two known holes from first principles, which is the reason
  to trust it on new ground.
- **By component** — [`components.md`](components.md). What kind of
  thing is in front of you, and what has ever been claimed about that
  kind.

Version diffs, upstream manifests, historical failures and translated
tests propose candidates from outside either frame. A changed export set
alone is a difference; it becomes a failure when a consumer requirement
or a preservation claim contradicts it. A native test translated through
a binding provides an expected result: if the native test passes and the
translation disagrees under corresponding inputs, investigate the
binding, the translation and the marshalling assumptions. A direct and a
helper-mediated translation can also be compared.

Whichever frame produced it, the promotion workflow is §4.9.6.

---


<!-- BEGIN GENERATED — do not edit between these markers.
     Written by `make agreement-catalogue` from the registry. -->

## 2. What there is — every agreement, one by one

**GENERATED from the registry**, so it cannot drift from the code that implements it. The records are in the AGREEMENT OVERVIEW's order — earliest firing action first, then language, then mechanism — so reading down this section walks that table top to bottom. It is not one-to-one: a claim whose firing differs between mechanisms has several rows there and one record here, and it appears at its first row's position.

**What this does NOT show is what actually RAN.** That is a fact about run logs, and a generated file that read logs would change whenever anything ran — so `canary checks --landing` is the live answer to *which are landed*, and this answers *what each one is and what is in its way*.

Evidence paths are shown for a BUILT world. The world decides where a binding's inspection sits — a Fetched binding's is at its fetch step — so the same method reads different paths in different worlds.

The model these fields belong to is §1 above; why each agreement exists is [`components.md`](components.md), at the anchor its row carries, and [`theory.md`](theory.md) for why there is anything to check at all; how to land one is §4 and §5 below.

### What is done, and what is left

8 of 13 agreements are implemented with nothing known in their way. The other 5 are blocked, and this is on what. Whether an unblocked one has actually been DECIDED by a real run is `canary checks --landing`'s question, not this file's.

| agreement | status | waiting on |
| --- | --- | --- |
| [`behavior_matches`](#behavior_matches) | planned | somebody to state a spec. This is one row standing for a CATEGORY — derived compatibility tests, the project's own suite, a provider/consumer round trip — and it needs both an expectation and a comparison. Introduce one test-suite reuse case, then one C/binding differential case: the first supplies the expectation, the second the comparison |
| [`declared_versions_exported`](#declared_versions_exported) | evaluated | a project that BUILDS a library carrying a version script. sqlite builds without one, so there are no version nodes and `vacuous` is the truth rather than a gap; openssl has one and canary fetches its lib, so build_lib never fires there |
| [`signatures_agree`](#signatures_agree) | evaluated | the source-scanning inspectors, which no project wires. Also a real signature extractor in place of the fixed binding-signature table, so the check compares what the binding DECLARES rather than what the inspector was told to assume |
| [`repack_preserves_api`](#repack_preserves_api) | planned | a statement of what "preserves" permits — a rename, a merge, a deliberate omission (components.md §6.3.1). The claim has to be scoped before it can be named properly, let alone checked |
| [`repack_complete`](#repack_complete) | planned | the same scoping as repack_preserves_api, plus the two agreements it composes. A composition cannot be better rooted than its weakest part |

The `planned` rows are exactly the agreements no tool's rule roots (see the second table below). That is not a coincidence: no toolchain enforced the relation, so there is nothing to re-derive and they wait on somebody to STATE a specification rather than on wiring. **Prefer landing a tool-rooted one.**

### What each agreement recovers

Every row is one action's rule, re-derived from what survived it. **Action** is where the rule ran — not where the check fires, which is wherever the evidence lands and is usually later. **Tool** is what applied it; **artifact** is what it ranged over.

A `code-set` action is one THIS graph contains, so the row can be read against `canary paths`. A plain-prose one is not: the link that built a consumer ran in a world this graph never modelled, and "the link" is several actions depending on who is linking. Naming those in the action type would be a lie in both directions; drawing them needs the action-unit view, which is deferred in [`backlog.md`](../../backlog.md) §51.

| code | agreement | action | tool | artifact | checked at | status |
| --- | --- | --- | --- | --- | --- | --- |
| `dse` | [`declared_symbols_exported`](#declared_symbols_exported) | `build_lib` | compiler + linker | the library's exported symbols | `build_lib_post` | evaluated |
| `smd` | [`soname_matches_declaration`](#soname_matches_declaration) | `build_lib` | linker (-Wl,-soname) | the library's SONAME record | `build_lib_post` | evaluated |
| `dve` | [`declared_versions_exported`](#declared_versions_exported) | `build_lib` | linker (version script) | the library's symbol-version nodes | `build_lib_post` | evaluated |
| `sip` | [`staged_interface_preserved`](#staged_interface_preserved) | `install_lib` | the install tool | the staged copy of the library | `install_lib_post` | evaluated |
| `rse` | [`required_symbols_exported`](#required_symbols_exported) | `build_binding_ocaml` | linker | the stub archive's undefined references. The link that made them ran in whatever world built the consumer, which this graph need not contain — so where the binding is fetched rather than built, the check falls to the probe | `build_binding_ocaml_pre → probe_binding_ocaml_pre` | evaluated |
| `smr` | [`soname_matches_requirement`](#soname_matches_requirement) | `build_binding_ocaml` | linker | the consumer's NEEDED record. The link that wrote it ran in whatever world built that consumer, which this graph need not contain | `build_binding_ocaml_pre → probe_binding_ocaml_pre` | evaluated |
| `rve` | [`required_versions_exported`](#required_versions_exported) | `build_binding_ocaml` | linker | the consumer's versioned symbol references, written by the link that produced it — in whatever world that was | `build_binding_ocaml_pre → probe_binding_ocaml_pre` | evaluated |
| `sa` | [`signatures_agree`](#signatures_agree) | `build_binding_ocaml` | the C compiler | the stub's calls against the header's declarations | `build_binding_ocaml_pre → probe_binding_ocaml_pre` | evaluated |
| `dp` | [`dependencies_provided`](#dependencies_provided) | `probe_binding_ocaml` | linker, then the dynamic loader | the consumer's NEEDED list. The linker wrote it and the LOADER re-checks it at every load, which is why the probe is the action named here rather than the link | `build_binding_ocaml_pre → probe_binding_ocaml_pre` | evaluated |
| `anp` | [`api_names_present`](#api_names_present) | `build_app_ocaml` | the language compiler | the binding's user-facing interface. Most projects declare no app, so the rule's own action is absent and the check falls to the binding probe | `build_app_ocaml_pre → probe_binding_ocaml_pre` | evaluated |

### Rooted in no action's rule

These 3 are not checks waiting on evidence. No toolchain enforces them, so there is no relation to recover — only one to state. They are exactly the rows with no evaluator, which is what tells "nobody implemented this" apart from "nobody has said what it means".

| code | agreement | why there is no rule | status |
| --- | --- | --- | --- |
| `bm` | [`behavior_matches`](#behavior_matches) | no toolchain enforces that a function returns what a project expected — a compiler checks types, a linker checks names, and neither has an opinion about results. There is no relation here to recover, only one to STATE, which is why this is unimplemented in a different sense from an agreement that merely lacks evidence | planned |
| `rpa` | [`repack_preserves_api`](#repack_preserves_api) | a binding's two layers are both written by the author, and nothing compiles one against the other in a way that could reject a rename, a merge or a deliberate omission. This is a claim about INTENT, and it needs stating before it can be checked | planned |
| `rc` | [`repack_complete`](#repack_complete) | unrooted TWICE OVER: it composes one agreement that has a rule (the linker's) with two that do not. A composition cannot be better rooted than its weakest part | planned |

### The records

### declared_symbols_exported

| | |
| --- | --- |
| subject | symbols |
| about | structural — artifacts and their fit |
| obligation | project-declaration |
| status | evaluated |
| fault tag | sym_missing |
| why it exists | components.md §2.2 |

#### Claim


**Says:** every function the project declares in c_api is exported by the built lib

**Held against:** the project's declared c_api export set; a name in the declaration that the built library does not export is the falsifier

**Recovers:** build_lib — compiler + linker, over the library's exported symbols. the compiler and linker turned declarations into definitions and exported them. The declaration this checks against is the project's rather than the header's, so it recovers a WEAKER rule than the compiler's own: it asks whether what the project said it ships is there, not whether every declaration agreed with its definition

**Checked at:** ocaml: build_lib_post; python: build_lib_post

#### Method: declared_exports_vs_library

| | |
| --- | --- |
| how | inspects several artifacts and compares them |
| against | declaration |
| implemented | yes |
| ocaml/cstubs@built | fires at build_lib |
|   reads | native summary build_lib/inspect.json \| probe_lib/inspect.json |
| python/cext@built | fires at build_lib |
|   reads | native summary build_lib/inspect.json \| probe_lib/inspect.json |
| limits | only declared names are covered; signatures, versions and behaviour are not. A name present says nothing about what it does. |

**Examples**

**1. reports `violated`** — finding: `tiny_offset`

reads: `DECLARED exports (3 name(s))`, `native summary lib.json`

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_diff"]}
```

**2. reports `undeclared`**

reads: `native summary lib.json`

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_diff"]}
```

**3. reports `inconclusive`**

reads: `DECLARED exports (3 name(s))`, `native summary lib.json`

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "counts": {"total": 40},
    "symbols": ["tiny_sum", "tiny_diff"]}
```


### declared_versions_exported

| | |
| --- | --- |
| subject | symbol-versions |
| about | structural — artifacts and their fit |
| obligation | project-declaration |
| status | evaluated |
| fault tag | sym_version |
| why it exists | components.md §2.2 |
| waiting on | a project that BUILDS a library carrying a version script. sqlite builds without one, so there are no version nodes and `vacuous` is the truth rather than a gap; openssl has one and canary fetches its lib, so build_lib never fires there |

#### Claim


**Says:** every version tag the project declares appears among the built lib's versioned exports

**Held against:** the project's declared version-script tags. The version script's application is the black box; the artifact's export annotations are the evidence

**Recovers:** build_lib — linker (version script), over the library's symbol-version nodes. a version script is what attaches version nodes to exported symbols. As with the soname, the tool is a black box and the annotations it wrote are the evidence

**Checked at:** ocaml: build_lib_post; python: build_lib_post

#### Method: declared_tags_vs_library_exports

| | |
| --- | --- |
| how | inspects several artifacts and compares them |
| against | declaration |
| implemented | yes |
| ocaml/cstubs@built | fires at build_lib |
|   reads | provider version tags build_lib/inspect.json \| probe_lib/inspect.json |
| python/cext@built | fires at build_lib |
|   reads | provider version tags build_lib/inspect.json \| probe_lib/inspect.json |
| limits | presence of a tag says nothing about the symbols inside it, nor about compatibility beyond the declared tags. |

**Examples**

**1. reports `violated`** — finding: `version TINY_2.0 not exported`

reads: `DECLARED version tags (1)`, `provider version tags lib.json`

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "versioned_exports": {"tiny_sum": "TINY_1.0"}}
```

**2. reports `vacuous`**

reads: `provider version tags lib.json`

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "versioned_exports": {"tiny_sum": "TINY_1.0"}}
```


### soname_matches_declaration

| | |
| --- | --- |
| subject | identity |
| about | structural — artifacts and their fit |
| obligation | project-declaration |
| status | evaluated |
| fault tag | abi_soname |
| why it exists | components.md §2.2 |

#### Claim


**Says:** the built lib's recorded identity is the soname the project declared

**Held against:** the project's declared soname. The linker's -Wl,-soname application is the black box; the artifact's own record is the evidence

**Recovers:** build_lib — linker (-Wl,-soname), over the library's SONAME record. the -soname flag is the only thing that puts an identity into the object. The linker is a black box here: it either recorded what was asked for or it did not, and the artifact is the evidence

**Checked at:** ocaml: build_lib_post; python: build_lib_post

#### Method: declared_soname_vs_library

| | |
| --- | --- |
| how | inspects several artifacts and compares them |
| against | declaration |
| implemented | yes |
| ocaml/cstubs@built | fires at build_lib |
|   reads | native summary build_lib/inspect.json \| probe_lib/inspect.json |
| python/cext@built | fires at build_lib |
|   reads | native summary build_lib/inspect.json \| probe_lib/inspect.json |
| limits | matching a name does not identify a unique implementation: two objects can advertise one soname and mean different things (the ncurses case). |

**Examples**

**1. reports `violated`** — finding: `soname libtiny.so.2 != declared libtiny.so.1`

reads: `DECLARED soname libtiny.so.1`, `native summary lib.json`

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum"],
    "elf": {"soname": "libtiny.so.2", "needed": []}}
```

**2. reports `undeclared`**

reads: `native summary lib.json`

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "elf": {"soname": "libtiny.so.1", "needed": []}}
```


### api_names_present

| | |
| --- | --- |
| subject | api-names |
| about | structural — artifacts and their fit |
| obligation | project-declaration |
| status | evaluated |
| fault tag | api_drop |
| why it exists | components.md §3.1.1 |

#### Claim


**Says:** every watchlisted name is present on the binding's user-facing surface

**Held against:** the project's watchlist for this binding; a watched name absent from the inspected surface is the falsifier. An empty watchlist asks nothing and is reported as inconclusive, never as a pass

**Recovers:** build_app_ocaml — the language compiler, over the binding's user-facing interface. Most projects declare no app, so the rule's own action is absent and the check falls to the binding probe. the compiler's rule is that every name a consumer uses resolves on the interface it compiles against. The watchlist stands in for the application's actual uses, which makes this a hand-written APPROXIMATION of a real rule rather than a derivation of it

**Checked at:** ocaml: build_app_ocaml_pre → probe_binding_ocaml_pre; python: build_app_python_pre → probe_binding_python_pre

#### Method: watchlist_vs_user_surface

| | |
| --- | --- |
| how | reads one artifact's properties or presence |
| against | declaration |
| implemented | yes |
| ocaml/cstubs@built | fires at build_binding_ocaml, probe_binding_ocaml |
|   reads | OCaml surface build_binding_ocaml/inspect.json \| build_binding_ocaml/inspect_mli.json |
| python/cext@built | fires at build_binding_python, probe_binding_python |
|   reads | Python surface build_binding_python/inspect.json \| build_binding_python/inspect_attrs.json |
| limits | coverage is bounded by the watchlist: names outside it are not checked, and a name being present says nothing about the signature or behaviour behind it. Obtaining the Python surface already imports the module. |

**Examples**

**1. reports `violated`** — finding: `Llvm.Opcode.UncondBr`, `Opcode.UncondBr`, `UncondBr`

reads: `OCaml surface mli.json`

`mli.json`:

```json
{"kind": "ocaml_mli", "path": "fx",
    "watchlist": {"present": [], "missing": ["Llvm.Opcode.UncondBr"]}}
```

**2. reports `violated`** — finding: `Solver.add`, `add`, `BitVec`

reads: `Python surface py.json`

`py.json`:

```json
{"kind": "python", "path": "fx",
    "watchlist": {"present": [], "missing": ["Solver.add", "BitVec"]}}
```

**3. reports `inconclusive`**

reads: `OCaml surface empty.json`

`empty.json`:

```json
{"kind": "ocaml_mli", "path": "fx",
    "watchlist": {"present": [], "missing": []}}
```


### dependencies_provided

| | |
| --- | --- |
| subject | dependencies |
| about | structural — artifacts and their fit |
| obligation | toolchain-rule |
| status | evaluated |
| fault tag | needed_unprovided |
| why it exists | components.md §5.6 |

#### Claim


**Says:** every library name the consumer records as NEEDED has a provider in this world

**Held against:** this world's modeled provider plus the family's fixed ambient-runtime list. A recorded name answered by neither is the falsifier — which is what a consumer linked where an implementation was split out, and deployed where it is folded in, produces

**Recovers:** probe_binding_ocaml — linker, then the dynamic loader, over the consumer's NEEDED list. The linker wrote it and the LOADER re-checks it at every load, which is why the probe is the action named here rather than the link. the linker recorded a set of dependency names, and the loader's rule is that each resolves to an object. This recovers the LOADER'S rule statically, for the names recorded, against the providers this world models

**Checked at:** ocaml: build_binding_ocaml_pre → probe_binding_ocaml_pre; python: build_binding_python_pre → probe_binding_python_pre

#### Method: recorded_dependencies_vs_world_providers

| | |
| --- | --- |
| how | inspects several artifacts and compares them |
| against | peer |
| implemented | yes |
| ocaml/cstubs@built | fires at build_binding_ocaml, probe_binding_ocaml |
|   reads | native summary build_lib/inspect.json \| probe_lib/inspect.json |
|   reads | consumer identity + NEEDED probe_binding_ocaml/inspect_abi.json \| build_binding_ocaml/inspect.json |
| python/cext@built | fires at build_binding_python, probe_binding_python |
|   reads | native summary build_lib/inspect.json \| probe_lib/inspect.json |
|   reads | consumer identity + NEEDED probe_binding_python/inspect_abi.json \| build_binding_python/inspect.json |
| limits | ONE modeled provider, direct dependencies only, and an ambient list that is code rather than a per-world policy. It does not enumerate every provider, traverse transitive dependencies, verify the ambient libraries exist, or run a loader — so a name supplied by a second unmodeled library is reported unprovided. |

**Examples**

**1. reports `violated`** — finding: `libtinfo.so.6`

reads: `native summary lib.json`, `consumer identity + NEEDED consumer.json`

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "elf": {"soname": "libncursesw.so.6", "needed": []}}
```

`consumer.json`:

```json
{"kind": "native", "path": "fx",
    "elf": {"soname": null,
            "needed": ["libncursesw.so.6", "libtinfo.so.6", "libc.so.6"]}}
```


### required_symbols_exported

| | |
| --- | --- |
| subject | symbols |
| about | structural — artifacts and their fit |
| obligation | toolchain-rule |
| status | evaluated |
| fault tag | sym_missing |
| why it exists | components.md §3.1.2 |

#### Claim


**Says:** every symbol the binding's stub references is exported by the lib

**Held against:** the consumer's own recorded requirements: the undefined references in its compiled stub. A required symbol the provider does not export is the falsifier, and the linker or loader would say the same

**Recovers:** build_binding_ocaml — linker, over the stub archive's undefined references. The link that made them ran in whatever world built the consumer, which this graph need not contain — so where the binding is fetched rather than built, the check falls to the probe. the linker's rule is that every referenced symbol has a definition. It ran once, when the binding was built against some library; this re-derives it, for names, against whichever library THIS world actually holds

**Checked at:** ocaml: build_binding_ocaml_pre → probe_binding_ocaml_pre; python: build_binding_python_pre → probe_binding_python_pre

#### Method: stub_requirements_vs_library_exports

| | |
| --- | --- |
| how | inspects several artifacts and compares them |
| against | peer |
| implemented | yes |
| ocaml/cstubs@built | fires at build_binding_ocaml, probe_binding_ocaml |
|   reads | compiled-stub summary build_binding_ocaml/inspect_stub.json \| build_binding_ocaml/inspect.json |
|   reads | native summary build_lib/inspect.json \| probe_lib/inspect.json |
| python/cext@built | fires at build_binding_python, probe_binding_python |
|   reads | compiled-stub summary build_binding_python/inspect_stub.json \| build_binding_python/inspect.json |
|   reads | native summary build_lib/inspect.json \| probe_lib/inspect.json |
| limits | set inclusion only: it does not check signatures, symbol versions, or which definition the loader will actually bind. Inclusion over a very small requirement set may also mean the binding is stale rather than deliberately narrow. |

**Examples**

**1. reports `violated`** — finding: `tiny_offset`

reads: `compiled-stub summary stub.json`, `native summary lib.json`

`stub.json`:

```json
{"kind": "c_stub", "path": "fx",
    "requires": ["tiny_sum", "tiny_offset"]}
```

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_diff"]}
```

**2. reports `holds`**

reads: `compiled-stub summary stub.json`, `native summary lib.json`

`stub.json`:

```json
{"kind": "c_stub", "path": "fx",
    "requires": ["tiny_sum", "tiny_diff"]}
```

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_diff"]}
```

**3. reports `unavailable`**

reads: `compiled-stub summary stub.json`, `native summary absent.json`

`stub.json`:

```json
{"kind": "c_stub", "path": "fx",
    "requires": ["tiny_sum"]}
```


### required_versions_exported

| | |
| --- | --- |
| subject | symbol-versions |
| about | structural — artifacts and their fit |
| obligation | toolchain-rule |
| status | evaluated |
| fault tag | sym_version |
| why it exists | components.md §4.1 |

#### Claim


**Says:** the provider exports every version node the consumer requires

**Held against:** the consumer's own recorded version requirements. A required tag the provider does not export is what the loader reports as "version `X' not found"

**Recovers:** build_binding_ocaml — linker, over the consumer's versioned symbol references, written by the link that produced it — in whatever world that was. the linker's rule is that a versioned reference binds to a version node the provider exports. The LOADER re-checks it at every load, and says so verbatim when it fails — which is why this agreement can predict its diagnostic text

**Checked at:** ocaml: build_binding_ocaml_pre → probe_binding_ocaml_pre; python: build_binding_python_pre → probe_binding_python_pre

#### Method: required_tags_vs_provider_exports

| | |
| --- | --- |
| how | inspects several artifacts and compares them |
| against | peer |
| implemented | yes |
| ocaml/cstubs@built | fires at build_binding_ocaml, probe_binding_ocaml |
|   reads | provider version tags build_lib/inspect.json \| probe_lib/inspect.json |
|   reads | consumer version tags probe_binding_ocaml/inspect_abi.json \| build_binding_ocaml/inspect.json |
| python/cext@built | fires at build_binding_python, probe_binding_python |
|   reads | provider version tags build_lib/inspect.json \| probe_lib/inspect.json |
|   reads | consumer version tags probe_binding_python/inspect_abi.json \| build_binding_python/inspect.json |
| limits | exact tag match, direct requirements only. It does not model version ordering, and a world without symbol versioning is inconclusive rather than compatible. |

**Examples**

**1. reports `violated`** — finding: `GLIBC_2.31`

reads: `provider version tags prov.json`, `consumer version tags cons.json`

`prov.json`:

```json
{"kind": "native", "path": "fx",
    "versioned_exports": {"malloc": "GLIBC_2.17", "memcpy": "GLIBC_2.17"}}
```

`cons.json`:

```json
{"kind": "native", "path": "fx",
    "versioned_req": {"GLIBC_2.31": 3, "GLIBC_2.17": 5}}
```

**2. reports `holds`**

reads: `provider version tags prov.json`, `consumer version tags ok.json`

`prov.json`:

```json
{"kind": "native", "path": "fx",
    "versioned_exports": {"malloc": "GLIBC_2.17", "memcpy": "GLIBC_2.17"}}
```

`ok.json`:

```json
{"kind": "native", "path": "fx",
    "versioned_req": {"GLIBC_2.17": 5}}
```

**3. reports `inconclusive`**

reads: `provider version tags prov.json`, `consumer version tags bare.json`

`prov.json`:

```json
{"kind": "native", "path": "fx",
    "versioned_exports": {"malloc": "GLIBC_2.17"}}
```

`bare.json`:

```json
{"kind": "native", "path": "fx"}
```


### signatures_agree

| | |
| --- | --- |
| subject | signatures |
| about | structural — artifacts and their fit |
| obligation | toolchain-rule |
| status | evaluated |
| fault tag | type_arity |
| why it exists | components.md §3.1.2 |
| waiting on | the source-scanning inspectors, which no project wires. Also a real signature extractor in place of the fixed binding-signature table, so the check compares what the binding DECLARES rather than what the inspector was told to assume |

#### Claim


**Says:** the types a stub declares agree with the header it wraps

**Held against:** the provider's header signatures, for the function names the binding also declares. A disagreeing return type or argument list is what the C compiler would reject if it saw both

**Recovers:** build_binding_ocaml — the C compiler, over the stub's calls against the header's declarations. the compiler's rule is that a call agrees with the declaration in scope. It ran when the stub was compiled against some header; this re-derives it from signature summaries, TEXTUALLY, for the names both sides mention

**Checked at:** ocaml: build_binding_ocaml_pre → probe_binding_ocaml_pre; python: build_binding_python_pre → probe_binding_python_pre

#### Method: header_vs_stub_signature_summaries

| | |
| --- | --- |
| how | inspects several artifacts and compares them |
| against | peer |
| implemented | yes |
| ocaml/cstubs@built | fires at build_binding_ocaml, probe_binding_ocaml |
|   reads | header signatures scan_sources/inspect_typed_header.json |
|   reads | stub signatures scan_sources/inspect_typed_binding_stub_ocaml.json |
| python/cext@built | not applicable — this mechanism declares its types as values rather than at a compiled boundary, so there are no stub signatures to read |
| limits | textual comparison of type SPELLINGS, not semantic type equivalence, representation or ownership. Names on only one side are skipped. The current extractor parses known C header declarations and supplies fixed binding signatures where their names occur in the binding source — general binding-signature extraction is the next step. |

**Examples**

**1. reports `violated`** — finding: `tiny_sum`

reads: `header signatures hdr.json`, `stub signatures stub.json`

`hdr.json`:

```json
{"kind": "typed_header", "path": "fx",
    "functions": {"tiny_sum": {"return": "int", "args": ["int", "int"]}}}
```

`stub.json`:

```json
{"kind": "typed_stub_ocaml", "path": "fx",
    "functions": {"tiny_sum": {"return": "int", "args": ["int"]}}}
```

**2. reports `holds`**

reads: `header signatures hdr.json`, `stub signatures agree.json`

`hdr.json`:

```json
{"kind": "typed_header", "path": "fx",
    "functions": {"tiny_sum": {"return": "int", "args": ["int", "int"]}}}
```

`agree.json`:

```json
{"kind": "typed_stub_ocaml", "path": "fx",
    "functions": {"tiny_sum": {"return": "int", "args": ["int", "int"]}}}
```


### soname_matches_requirement

| | |
| --- | --- |
| subject | identity |
| about | structural — artifacts and their fit |
| obligation | toolchain-rule |
| status | evaluated |
| fault tag | abi_soname |
| why it exists | components.md §4.1 |

#### Claim


**Says:** the lib's soname is the one the consumer recorded it needs

**Held against:** the consumer's own recorded dependency list. A provider advertising a name the consumer never recorded will not be selected for it

**Recovers:** build_binding_ocaml — linker, over the consumer's NEEDED record. The link that wrote it ran in whatever world built that consumer, which this graph need not contain. the linker's rule is that a recorded dependency names something it resolved against. It ran in whatever world built that consumer; this asks whether the name it wrote down is the one THIS world's provider answers to

**Checked at:** ocaml: build_binding_ocaml_pre → probe_binding_ocaml_pre; python: build_binding_python_pre → probe_binding_python_pre

#### Method: library_identity_vs_consumer_record

| | |
| --- | --- |
| how | inspects several artifacts and compares them |
| against | peer |
| implemented | yes |
| ocaml/cstubs@built | fires at build_binding_ocaml, probe_binding_ocaml |
|   reads | native summary build_lib/inspect.json \| probe_lib/inspect.json |
|   reads | consumer identity + NEEDED probe_binding_ocaml/inspect_abi.json \| build_binding_ocaml/inspect.json |
| python/cext@built | fires at build_binding_python, probe_binding_python |
|   reads | native summary build_lib/inspect.json \| probe_lib/inspect.json |
|   reads | consumer identity + NEEDED probe_binding_python/inspect_abi.json \| build_binding_python/inspect.json |
| limits | name equality only. It does not establish which object the loader will select, nor that the selected object means the same thing as the one linked against. |

**Examples**

**1. reports `violated`** — finding: `libtiny.so.1`

reads: `native summary lib.json`, `consumer identity + NEEDED consumer.json`

`lib.json`:

```json
{"kind": "native", "path": "fx",
    "elf": {"soname": "libtiny.so.2", "needed": []}}
```

`consumer.json`:

```json
{"kind": "native", "path": "fx",
    "elf": {"soname": null, "needed": ["libtiny.so.1", "libc.so.6"]}}
```


### staged_interface_preserved

| | |
| --- | --- |
| subject | staging |
| about | structural — artifacts and their fit |
| obligation | toolchain-rule |
| status | evaluated |
| fault tag | staged_drift |
| why it exists | components.md §6.1 |

#### Claim


**Says:** the staged library presents the same interface as the build tree's

**Held against:** the build-tree copy of the same library, which is still present. A relocation is allowed to move files and rewrite embedded paths; it is not allowed to change what the object exports, what it calls itself, or what it depends on

**Recovers:** install_lib — the install tool, over the staged copy of the library. the install tool's rule is that staging relocates without altering the interface. Unusually, it can be checked almost as strongly as it was applied: both copies are still on disk, so nothing had to be inferred from a projection

**Checked at:** ocaml: install_lib_post; python: install_lib_post

#### Method: staged_vs_build_tree_summary

| | |
| --- | --- |
| how | inspects several artifacts and compares them |
| against | peer |
| implemented | yes |
| ocaml/cstubs@built | does not fire |
| python/cext@built | does not fire |
| limits | it compares the summary fields an inspector records — export count, recorded identity, dependencies, embedded search paths. It does not compare the exported NAMES one by one, the contents of the objects, or any file other than the library itself, so a staging that drops a header or a data file passes. |

**Examples**

**1. reports `violated`** — finding: `soname libtiny.so.1→libtiny.so.2`

reads: `native summary bt.json`, `staged native summary st.json`

`bt.json`:

```json
{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}
```

`st.json`:

```json
{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.2", "needed": ["libc.so.6"]}}
```

**2. reports `violated`** — finding: `symbols 12→9`

reads: `native summary bt.json`, `staged native summary thin.json`

`bt.json`:

```json
{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}
```

`thin.json`:

```json
{"kind": "native", "path": "fx", "counts": {"total": 9},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}
```

**3. reports `holds`**

reads: `native summary bt.json`, `staged native summary same.json`

`bt.json`:

```json
{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}
```

`same.json`:

```json
{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}
```

**4. reports `unavailable`**

reads: `native summary bt.json`, `staged native summary absent.json`

`bt.json`:

```json
{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": []}}
```


### repack_complete

| | |
| --- | --- |
| subject | repacking |
| about | behavioral — what running it does |
| obligation | behavioral-spec |
| status | planned |
| fault tag | api_add |
| why it exists | components.md §6.3.1 |
| waiting on | the same scoping as repack_preserves_api, plus the two agreements it composes. A composition cannot be better rooted than its weakest part |

#### Claim


**Says:** the repack loses nothing the original had

**Held against:** a statement of what the binding is allowed to omit. Without one there is no reference: a binding that deliberately wraps a subset is indistinguishable from one that dropped something

**Recovers:** NO ACTION'S RULE. unrooted TWICE OVER: it composes one agreement that has a rule (the linker's) with two that do not. A composition cannot be better rooted than its weakest part

**Checked at:** ocaml: build_binding_ocaml_post → probe_binding_ocaml_post; python: build_binding_python_post → probe_binding_python_post

#### Method: composed_faithfulness

| | |
| --- | --- |
| how | runs a probe and inspects its result |
| against | declaration |
| implemented | no — planned |
| why not | the claim's scope is unsettled ("loses nothing" needs an allowed-omission policy), and two of the three agreements it composes — repacking and behaviour — have no evaluator either. check_api_faithfulness composes three verdicts and is ready for the day they exist |
| ocaml/cstubs@built | fires at build_binding_ocaml, probe_binding_ocaml |
| python/cext@built | fires at build_binding_python, probe_binding_python |
| limits | not evaluated. The composition function exists and is pure; what it would mean is the open decision. |
| counterexamples | none — nothing shows it can fail |

### behavior_matches

| | |
| --- | --- |
| subject | behavior |
| about | behavioral — what running it does |
| obligation | behavioral-spec |
| status | planned |
| fault tag | behavior |
| why it exists | components.md §6.3.2 |
| waiting on | somebody to state a spec. This is one row standing for a CATEGORY — derived compatibility tests, the project's own suite, a provider/consumer round trip — and it needs both an expectation and a comparison. Introduce one test-suite reuse case, then one C/binding differential case: the first supplies the expectation, the second the comparison |

#### Claim


**Says:** the probe's trace matches what was recorded for it

**Held against:** the probe's own embedded assertions. There is no project-independent statement of what a binding should compute, so the expectation is whatever the probe asserts — which bounds this agreement to the inputs that probe exercises

**Recovers:** NO ACTION'S RULE. no toolchain enforces that a function returns what a project expected — a compiler checks types, a linker checks names, and neither has an opinion about results. There is no relation here to recover, only one to STATE, which is why this is unimplemented in a different sense from an agreement that merely lacks evidence

**Checked at:** ocaml: probe_binding_ocaml_post; python: probe_binding_python_post

#### Method: probe_assertions

| | |
| --- | --- |
| how | runs a probe and inspects its result |
| against | declaration |
| implemented | no — planned |
| why not | the expected values live inside the probe's source as embedded assertions, and the observation is the probe's own exit code; the registry has no evaluator that could read them. Wiring one means giving the project a place to state expected results outside the probe. NOTE (2026-09-15, user) that this is ONE ROW standing for a CATEGORY, and the category has at least three members that want different machinery: tests DERIVED from a version-compatibility claim (canary generates them), the project's OWN test suite (canary runs what upstream wrote), and ROUND-TRIP tests across the provider and consumer sides of a binding (canary composes them). Wiring this row without deciding which of the three it is would fix the narrowest one by accident |
| ocaml/cstubs@built | fires at probe_binding_ocaml |
| python/cext@built | fires at probe_binding_python |
| limits | not evaluated here. The probe's assertions cover the inputs that probe runs and nothing else. |
| counterexamples | none — nothing shows it can fail |

### repack_preserves_api

| | |
| --- | --- |
| subject | repacking |
| about | behavioral — what running it does |
| obligation | behavioral-spec |
| status | planned |
| fault tag | api_repack |
| why it exists | components.md §6.3.1 |
| waiting on | a statement of what "preserves" permits — a rename, a merge, a deliberate omission (components.md §6.3.1). The claim has to be scoped before it can be named properly, let alone checked |

#### Claim


**Says:** the user-facing layer is a sound repacking of the stub-facing one

**Held against:** an explicit statement of which transformations a wrapper may make. Until the project supplies one, there is no reference to compare against: a wrapper may rename, combine, restrict or extend, and none of those is refuted by a name comparison

**Recovers:** NO ACTION'S RULE. a binding's two layers are both written by the author, and nothing compiles one against the other in a way that could reject a rename, a merge or a deliberate omission. This is a claim about INTENT, and it needs stating before it can be checked

**Checked at:** ocaml: build_binding_ocaml_post → probe_binding_ocaml_post; python: build_binding_python_post → probe_binding_python_post

#### Method: declared_repacking_relation

| | |
| --- | --- |
| how | runs a probe and inspects its result |
| against | declaration |
| implemented | no — planned |
| why not | the repacking relation is not specified: "preserves" has no agreed scope, so there is nothing to compare a binding against. check_api_repack compares names and declared renames, which refutes a stub-side orphan but not a wrapper whose implementation drifted; the probe's own assertions carry that case today |
| ocaml/cstubs@built | fires at probe_binding_ocaml |
| python/cext@built | fires at probe_binding_python |
| limits | not evaluated. The name-based helper, when it is connected, will refute orphaned externals only. |
| counterexamples | none — nothing shows it can fail |

---

## 3. What has no record yet — out of the table

The [agreement overview](../matrix.md) shows the 13 implemented agreements of §2. These 12 have no row on it. The reason is carried on each proposal (`prop_frame`) and this grouping is generated from it, so the four kinds of work stay apart without anyone maintaining a list.

### Held up by a schema field (8)

The per-action frame REACHES these. What is missing is that a proposal carries no rooting and no target list, so there is nothing to put in the overview's `R` and ▣ columns. Adding those two fields would put each of these on the grid with its origin marked and no `D` anywhere — which is worth seeing, since it says where the information was lost for a claim nobody checks yet. It costs the row's meaning: `lag`, decided and blame are undefined without a firing.

#### exports_accounted_for

**Claim:** every symbol the library exports on its declared surface is accounted for by the project's declaration — the CONVERSE of declared_symbols_exported, which together with it makes the pair an equality rather than an inclusion

**Needs:** A DECLARATION KIND THAT DOES NOT EXIST YET. Filed 2026-09-15 as the cheapest proposal — 'both sides are already in hand' — and that was wrong. The two sides are not the same KIND of claim: [native_api.stable_symbols] is a WATCHLIST ('these modern-API symbols must be present', a probe for version drift), not a manifest. sqlite declares 5 and its library exports 272, so the converse would report 267 orphans on the project where declared_symbols_exported is landed. A prefix filter does not save it: all 272 share the prefix. What this needs is for a project to be able to say 'this list is EXHAUSTIVE for this surface', which is a different declaration from the one every project writes today — so this is a spec change, not a free comparator


#### package_contains_declared_files

**Claim:** the staged package contains every file the recipe said it installs — and the consumer's side of it: what the prefix holds is what a consumer reading the prefix will find

**Needs:** a manifest of what the install actually staged, recorded as evidence. z3 asserts exactly this today with a hand-listed `assert_staged` and two shell guards, and declares the pre-#10549 failure as two hand-written substrings; all four retire when the claim has a row


#### signatures_match_debug_info

**Claim:** the signatures the header declares are the ones the compiled library was built with — the strongest available answer to the type question, since it reads what the compiler recorded rather than what the header says now

**Needs:** a DWARF inspector and libraries built with -g. Strictly stronger than signatures_agree, which compares two TEXTS and cannot see a changed struct layout behind an unchanged spelling


#### no_build_paths_in_installed_library

**Claim:** a library that is installed records no path into the tree it was built in — no RUNPATH, RPATH or embedded reference that resolves only on the machine that produced it. It is wrong ON ITS OWN TERMS: against no declaration and no peer, whatever it is later paired with

**Needs:** NOTHING NEW TO RECORD — `inspect_native.py` already emits `runpath` and `rpath`, and canary already knows a world's build directory, which is the other half of the comparison. What it needs is the POLICY: which paths are legitimate in an installed artifact ($ORIGIN and @loader_path are, an absolute build path is not, a system prefix is arguably fine) and whether a relocatable-but-absolute prefix counts. Cheapest candidate on this list, and the first of its kind


#### compatibility_version_satisfied

**Claim:** on Mach-O, the provider's `compatibility_version` is at least what the consumer recorded — dyld's own gate, which has no ELF counterpart

**Needs:** nothing recorded and nothing derived: `inspect_native.py` has extracted `compatibility_version` and `current_version` from LC_ID_DYLIB since the macOS port and NO agreement reads either. Written evidence with no reader. What blocks it is REPORTING, not evidence — `canary checks --landing` is platform-blind, so an agreement landed only on macOS would read as landed everywhere (platform.md §6)


#### correspondence_holds_across_the_binding

**Claim:** an operation performed through the binding agrees with the same operation performed directly against the C library — including over SEQUENCES, where state makes the interesting cases

**Needs:** a GENERATOR and a new action, not a comparator. Distinct from `behavior_matches` in the one way that matters: it needs no project-supplied expectation, because the C side IS the oracle and canary already builds it. The generator is per-framework (`c_api.functions` is the pairing, the positional convention the argument mapping); a translation of a project's own suite is per-project and can come later. See directions.md §2


#### discovery_matches_link

**Claim:** the object a discovery mechanism ACCEPTED is the object the link resolved, and the object the loader finds. Three resolvers — `pkg-config` at solve time, the linker's search at build time, RUNPATH at run time — and nothing checks that they agreed

**Needs:** the first resolver's answer RECORDED; nothing captures what a conf-* check accepted. Its falsifier already exists as a written-up finding — the ncurses/libtinfo report, where identical sonames, symbols and version nodes segfaulted because two prefixes answered differently. ⚠ Open question it raises: it roots in no toolchain's rule (nothing ENFORCES the three agreeing) yet it has an oracle (run both resolvers and compare), so it asks whether `rooted` should mean a tool ENFORCED it or a tool ANSWERED it. See directions.md §1


#### interposition_binds_build_target

**Claim:** the definition that wins for a shared symbol is the one the consumer was built against

**Needs:** a resolved binding trace and an expected-target policy; the recorder supplies evidence, the comparison a verdict (components.md §5.6)


### Not filed either way (1)

`theory.md` §7.1's filter — *whose* rule is being recovered — has never been applied here. Listed separately so it does not sit among the answered ones looking like a peer.

#### build_tree_configured_for_source

**Claim:** the build tree was configured for THIS source tree and these options — a warm tree configured from another ref answers every later question about the wrong world

**Why no row:** theory.md §7.1's filter has never been applied to this one, and it looks like it falls the same way as source_is_declared_ref: "was the tree configured for the source we said" has the same shape as "is the tree at the commit we said". If so it is a world assertion too. Nobody has decided, so it is not filed as either

**Needs:** an inspector over the configure cache (CMakeCache.txt, config.status, dune's env) reducing it to the source path, the ref and the option set


### Not an agreement (1)

`theory.md` §7.1. An agreement is a claim about the project's artifacts. These recover CANARY'S OWN rule, which makes them world assertions: a violated agreement is a finding about the software, a failed world assertion means this run tested something other than what it says and every verdict in it is suspect. Kept here rather than deleted, because the CHECK is worth having and only its register is wrong.

#### source_is_declared_ref

**Claim:** the source tree a build read is the ref the project declared — an IDENTITY claim, so unlike the relation ones it closes exactly rather than converging

**Why no row:** it recovers CANARY'S OWN rule, not a toolchain's. "Is the tree at the commit we said" is not a claim about the project's artifacts; it is a claim about whether this run realized the world it says it tested — which fails differently and is read by different people. Canary already has a vocabulary for it: the world assertions. The CHECK is worth having; the row is in the wrong register

**Needs:** the resolved commit RECORDED after the fetch. The check itself already runs as a shell assertion in a check_post, which is precisely why it has no row: there is no evidence file to read


### Outside the per-action frame (2)

`theory.md` §7. The model reasons per edge, and these are not per-edge. §6's procedure will never find them, so they need their own reasoning rather than more wiring.

#### denotation_stable_across_worlds

**Claim:** a recorded library identity denotes the SAME implementation in the deploy world as in the build world

**Why no row:** a CROSS-WORLD property. It compares two worlds, so there is no single action whose relation it recovers — it is a claim about two runs of one action, and the per-action model has no vocabulary for that

**Needs:** retain corresponding build/deploy evidence across worlds and define an observable denotation criterion (components.md §5.5.1)


#### no_duplicate_implementation

**Claim:** the resolved set contains no two identities that are one implementation (alternative spelling), and none that statically absorbs another (containment)

**Why no row:** a SET property. It is about the whole resolved set rather than about any one pairing, and nothing in the per-action model speaks about sets

**Needs:** the shipped objects' evidence plus an identity/containment policy; symbol overlap alone is a discovery heuristic (components.md §5.5.3)

<!-- END GENERATED -->

---


## 4. How a run reaches a verdict — one project, end to end

### The shape, in one picture

```text
  the project's own words              the enumeration                the registry
  ┌─────────────────────┐        ┌──────────────────────────┐   ┌──────────────────┐
  │ pr_artifacts        │──1────▶│ pass 1  declare          │   │ the agreements   │
  │ pr_binding_decls    │        │ pass 2  ANALYSE ─────────┼─2▶│ each with        │
  │ pr_runner_spec      │        │   which claims THIS      │   │ methods          │
  └─────────┬───────────┘        │   project can carry      │   └────────┬─────────┘
            │                    │ passes 3-5 → a WORLD     │            │
            │ 4                  │   (one assignment)       │            │
            │                    └────────────┬─────────────┘            │
            │                                 │ 3                        │
            │                                 ▼                          │
            │                    ┌──────────────────────────┐            │
            └───────────────────▶│ pass 6  realize          │            │
                                 │  step + agreement_ctx    │            │
                                 └────────────┬─────────────┘            │
                                              │ 5                        │
                                              ▼                          │
                                 ┌──────────────────────────┐   6        │
                                 │ run_step                 │◀───────────┘
                                 │  evaluate_step           │
                                 └────────────┬─────────────┘
                                              │ 7
                                              ▼
                                 actions.log: agreement_outcome
                                              │ 8
                                              ▼
                                 canary checks <p> --observed
```

Eight numbered points. Only two of them are in the agreement layer; the
other six are where a project usually goes wrong.

> **This diagram was wrong until 2026-09-17** (user: *"the pipeline in
> agreement doesn't look correct, given the use of project spec
> analyzed"*). It read `passes 1-5 → a WORLD` and routed the project's
> declarations straight into `derive_steps`, which left **pass 2
> invisible** — and pass 2 is the one that matters most to this layer.
> APPLICABILITY, *can this project carry this claim at all*, is
> `(mechanism, lang, declaration)` with no world in it, so it is decided
> there and not at the step. `pr_binding_decls` reaches the registry via
> pass 2, which is the edge the picture was missing; a reader following
> the old one would have looked for applicability at point 4 or 5 and
> found nothing.

### 4.1 The project declares facts, never an agreement

sqlite's `pr_artifacts` says its lib can be Fetched, Built or Installed and
its OCaml binding is Fetched from opam at one of two pins. Its
`pr_binding_decls` says that binding is `Cstubs`. That is all the registry
needs, and it is deliberately all the project gets to say: **no project
names an agreement.** Which checks those facts imply is the framework's
knowledge (`agreements_for`, `evaluate_in_context`).

What a project *does* choose is where its evidence comes from — the
inspector closures on its `runner_spec`. That choice is point 3, and it is
the one that decides whether any agreement can reach anything.

### 4.2 Pass 2 decides which claims this project can carry

**This is the point the old picture was missing**, and it is the one
that decides whether an agreement is even in play for a project.

APPLICABILITY is `(mechanism, lang, declaration)` — no world in it — so
it is answered from the spec alone, at
[pass 2](../enumeration/stage2_analyse_spec.md). sqlite says its Python
binding is `Cext`; z3 says its is `Ctypes`. Ctypes compiles no stub and
records no dependency, so `required_symbols_exported`,
`dependencies_provided`, `soname_matches_requirement`,
`required_versions_exported` and `signatures_agree` cannot be carried
there at all — five of thirteen, decided before any world exists.

See it:

```sh
canary emit z3 --stage analyse     # "claims this project can carry", per language
```

Two consequences for landing:

- **If a claim is not carried here, no amount of wiring will land it.**
  `canary checks <p>` reports such rows as `no evaluator` or omits them;
  the answer is the mechanism, not the evidence.
- **It used to be re-answered per step**, and logged — sqlite emitted
  the same six `not_applicable` sentences on each of ten scenarios,
  sixty lines restating one static fact about cstubs. A
  `not_applicable` in a log now means the log PREDATES 2026-09-14:
  `make canary-refresh PROJECT=<p>`.

### 4.3 The enumeration produces a world

Passes 1–5 ([`../enumeration/README.md`](../enumeration/README.md)) turn the
artifact table into an `assignment`: one placement per artifact. For one
sqlite scenario:

```text
source=fetched@stable  lib=built@stable  binding-ocaml-cstubs=fetched-5.4.1
```

This matters to agreements for one reason: **the world decides where a
binding's evidence lives.** `binding_evidence_tag` reads the binding's
provision — `Fetched` means the inspection sits at the step that fetches
and installs it, `Built` means the step that builds it. Get the world
wrong and every path is wrong.

The derivation itself, and why it is the enumeration's rather than this
layer's, is
[`../enumeration/stage6_realize_steps.md`](../enumeration/stage6_realize_steps.md) §2b.

### 4.4 `derive_steps` attaches the action context

Pass 6 attaches an `agreement_ctx` — mechanism, language, world — to the
steps that have binding facts; the mechanics are
[`../enumeration/stage6_realize_steps.md`](../enumeration/stage6_realize_steps.md) §2b.
What matters to a project author is the next paragraph.

**This is also where the inspector steps are attached.** `attach_inspect`
consults `spec.inspect action loc` first, then falls back to
`auto_binding_summaries` (which needs `api_source` *and*
`binding_user_facing_pkg`). Whatever those produce is the only evidence any
agreement will ever see.

> **Failure mode 1 — the spec the run uses is not the spec you wrote.**
> sqlite declared `api_source` and inspector closures on a `base_spec` that
> its `realize` never passed to `realize_from_rows`. The default is
> `empty_runner_spec`, so the run produced *no inspection JSON at all* and
> every agreement reported `unavailable`. The declarations were reviewed,
> documented — and unreachable. Check `canary emit <p> --stage realize`:
> if you do not see `*_inspect` steps, nothing downstream can work.

### 4.5 The step runs

`run_step` resolves each declared relative path against the world's output
tree (`resolve_input`: `"fetch_binding_ocaml/inspect.json"` becomes
`<project_dir>/fetch_binding/ocaml/inspect_<variant>.json`, applying the
step-dir mapping and the variant key).

> **Failure mode 2 — the filename convention.** The framework's binding
> summaries land in `inspect.json` and its compiled-stub summary in
> `inspect_stub.json`; tiny writes its stub to `inspect.json` and its
> surface to `inspect_mli.json`. The derived paths originally spelled
> tiny's names only, so they resolved on tiny and on nothing else. A
> surface input now carries both spellings and the reader selects by the
> `kind` the inspector declared — see point 5.

> **Failure mode 3 — the step.** sqlite inspected its binding at the *probe*
> step while the derivation names the step that *installs* it. Both work as
> commands; only one is where anything looks. Installing is also the earliest
> point the evidence exists, which is what §1.3 asks for.

### The dummy action

Failure mode 3 has a variant with no obvious fix: **what if there is no
install step?** CPython's `sqlite3` is part of the interpreter. Nothing is
fetched, nothing is installed, and the step the derivation names does not
exist — so the binding's surface has nowhere to be inspected from.

Two ways out. Teach every consumer that an ambient binding is the exception,
or give the graph a place to hang things. Canary does the second:

```ocaml
fetch_binding = [ (Python, Canary_step_builder.Dummy
                     "CPython ships sqlite3 in the standard library — the \
                      interpreter already provides this binding, so there \
                      is nothing to fetch or install") ]
```

A **dummy action** occupies its place in the graph, performs no work, and
carries the reason it is empty. It still writes its marker, so "nothing to
do" stays distinguishable from "did not run"; it logs a `dummy` event, so a
reader scanning for real work can tell without reading the command; and an
inspector attached to it is *not* a dummy — running the inspector is the
entire reason the step exists.

It is **not** a stub, a skip, or an unwritten command. It asserts something
true and worth asserting: *no action provisions this artifact.* If that stops
being true — a venv, a pip build of `pysqlite3` — the dummy is wrong and
should become a real fetch.

They are countable, which is the point of marking rather than inferring
them:

```sh
canary checks --dummies          # every dummy across the registry, with its reason
```

One caveat this exposed: a binding with no consumer is dropped by
`drop_unread_fetches`, so a dummy install alone is not enough. sqlite's
Python side was entirely decorative — a watchlist, an expect-missing list and
a provider, with no `probe_binding` entry, so no Python step existed at all
and the chain was pruned. The dummy needed a probe beside it before anything
downstream could run.

### 4.6 `evaluate_step` — the only agreement-layer entry point a run uses

One call, one record (§4.9.1):

- **selection** — every method whose `m_firing` contains this step's action,
  under this mechanism/language/world;
- **applicability** — a mechanism that cannot carry the claim reports
  `not_applicable` and is not confused with missing evidence;
- **evidence** — each method's own `m_inputs`, resolved, and picked by
  declared `kind` rather than by first-path-wins;
- **evaluation** — one `outcome` per method.

A compat expectation may also hand over an input list; that route is merged
into the same record, preferring whichever side actually decided.

### 4.7 The log is the interface

The runner writes one `agreement_outcome` event per selected method,
including the ones with no evaluator. Reading a real one:

```text
probe_binding_ocaml  agreement_outcome  (api_names_present/watchlist_vs_user_surface: holds)
probe_binding_ocaml  agreement_outcome  (required_symbols_exported/…: unavailable: no compiled-stub inspection in this world)
probe_binding_ocaml  agreement_outcome  (soname_matches_requirement/…: not_applicable: this binding mechanism produces no artifact carrying a dependency record…)
probe_binding_ocaml  agreement_outcome  (behavior_matches/probe_assertions: not_implemented: the expected values live inside the probe's source…)
```

Different reasons, different fixes — and since 2026-09-15 the outcome
*word* tells them apart rather than leaving it to the reason string:

| outcome | mark in `canary result` | what to do about it |
| --- | --- | --- |
| `holds` / `violated` | `✓` / `✗` | nothing — this agreement is decided here |
| `unavailable` | `no-evid` | produce the evidence (points 3–4). A WIRING gap: nothing wrote the inspection, or the reader runs before the writer |
| `undeclared` | `no-decl` | the artifact is readable and the PROJECT declared nothing to hold it against. A spec to-do |
| `vacuous` | `none` | nothing — both sides were reachable and there is genuinely nothing of this kind in this world (a library with no symbol versioning, for instance) |
| `inconclusive` | `no-ref` | evidence read, nothing to compare against |
| `not_applicable` | `stale` | **re-run.** Applicability became a static property of the project (2026-09-14), so in a fresh run the selection drops such a method before it evaluates. A `not_applicable` in a log therefore means the log predates that: `make canary-refresh PROJECT=<p>` |
| `not_implemented` | `planned` | the agreement has no evaluator; that is a catalogue decision, not a wiring one |

> The first three were ONE outcome until 2026-09-15. `Unavailable` carried
> a free-text reason that the evaluators wrote and the type discarded, so a
> cell that needed nothing read exactly like one waiting on an inspector —
> and `canary result`'s blame column had to guess between them.
> `unavailable_cause` is `Missing_evidence | Missing_declaration |
> Nothing_to_check`, and `Missing_evidence` kept the old word so nothing
> that matched `unavailable` changed meaning.

### 4.8 Read it back

```sh
canary checks sqlite --observed     # what the LAST run evaluated
canary checks --landing             # planned vs effective, all agreements
```

> **Failure mode 4 — a warm run reports nothing.** A step whose verdict
> marker is trusted is skipped, and a skipped step re-checks nothing. Its
> old outcomes are not re-emitted, so an agreement can be missing from a log
> for no reason except caching. `--observed` prints the skip count for
> exactly this reason. To force a real re-read:
>
> ```sh
> make canary-refresh PROJECT=sqlite
> ```
>
> It drops the markers of the steps that DECIDE — probes, binding builds,
> staging — and re-runs; fetches and the library build stay warm, because
> the point is to re-run the step that reads the evidence, not to rebuild
> the world. (It was a hand-written `rm -f` of one project's probe markers
> until 2026-09-15; the target exists because clearing `stale` is a thing
> you do repeatedly, and because guessing which markers matter is how you
> end up deleting an output tree.)


### 4.9 The same eight points, at the level of the code

§4.1–§4.8 are what a project author sees. This section is the same path
in the registry's own terms — which call happens where, what it returns,
and the three places a result can be misread. Read it when you are
changing the layer rather than landing a check on it.

#### 4.9.1 From action context to checking methods

The registry maps agreements to inputs and firing sites. The remaining work is
not “map the catalogue later”; it is to make that mapping complete and its
limitations explicit.

**The completed path.** A step carries an `agreement_ctx` — the binding
mechanism, the language, and the world the enumeration assigned — set by
`derive_steps` from the scenario's own assignment. The runner calls
`evaluate_in_context` with those three facts and the step's own action. The
registry selects every checking method that fires there, resolves what each
reads against the world's output tree, evaluates it, and the runner logs one
`agreement_outcome` event per method. No project names an agreement and no
caller supplies an input list.

```text
step.action + step.agreement_ctx
  → evaluate_in_context       (selection: firing site, then applicability)
  → m_inputs, resolved        (evidence)
  → m_eval                    (evaluation → outcome)
  → agreement_outcome event   (reported)
```

Every selected method is reported, including the ones with no evaluator. A
step whose log showed only the checks that found something would read as full
coverage of that action.

`required_symbols_exported` is verified through this path for an OCaml
compiled-stub context, by `agreements.action_path_reports_outcomes`: matching
requirements and exports report `holds`, a deliberately missing required
symbol reports `violated` naming it, and absent library evidence reports
`unavailable`. The same test asserts that an applicable method with no
evaluator (`behavior_matches`) is visible as `not_implemented` with its
reason, and that a mechanism which cannot carry the claim
(`soname_matches_requirement` under a compiled-stub archive) is visible as
`not_applicable`. Fixture success alone does not establish this; the fixtures
in each family establish the comparisons, and this test establishes the
connection.

**The second evidence route.** Some layouts name their evidence themselves —
LLVM packs its built binding into opam and inspects the published package,
where the derivation says `build_binding_ocaml`. A compat expectation therefore
carries an input list, evaluated without the firing rules and without
consulting applicability: naming the evidence is the project's statement that
the check applies. That is deliberate rather than forgotten. Migrating the
remaining consumers is the backlog's agreement section (`../../backlog.md`).

**One record, two consumers.** Both routes answer the same question with the
same evaluators, so a step evaluates them once, into one record:

| Field            | What reads it                                                   |
| ---------------- | --------------------------------------------------------------- |
| `sv_all`         | reporting — one `agreement_outcome` event per selected method   |
| `sv_violations`  | the detected disagreements (§1.2.2)                             |
| `sv_diagnostics` | the acceptance policy, as the text a failing run must carry     |
| `sv_inputs`      | the evidence consulted, for questions about the evidence itself |

Until this landed, a compat step ran the context path to report and the input
path to decide, re-running the same comparators over the same files — which is
how a log comes to say one thing while a verdict says another.

The merge of the two routes is ordered so that it cannot lose a finding:
`violated` outranks `holds`, and any decided outcome outranks an undecided one.
The second case is ordinary — the declared route exists to reach evidence the
derivation cannot find. The first is the one worth stating: when the two input
sets point at different objects and disagree, the disagreement survives,
because a checking tool that preferred the good news would be the wrong kind of
tool.

**What the acceptance policy is, and is not.** The policy belongs to the
expectation, not to the agreement: the oracle form requires a failure whatever
the record found, and the agnostic form follows the record's polarity. Both now
read `sv_diagnostics` rather than computing their own. What neither does is
turn a detected disagreement into a step failure on its own — see §1.2.2.

`agreements_for` remains the facts-in-checks-out query for callers that want
the selection without evaluating it (the checking index, the layer tests).

**Warm runs report nothing.** A step whose verdict marker is trusted is
skipped, so it emits no `agreement_outcome` events. The verdict and its
attribution survive — the marker records both, and `canary status` reads them —
but the per-method record does not. That follows from §1.4: the cached thing is
the verdict, and re-deriving the report would mean re-running the step. It also
means a stale report is easy to mistake for a current one, which is why the
reader below counts skipped steps alongside the outcomes.

#### 4.9.2 The round trip: what a real run actually checked

Everything above describes what WOULD be checked. The registry lists the
methods, the firing table says where they apply, the checking index reports
what a project's actions select. None of it is evidence that a check ran.

`canary checks <project> --observed` reads the other direction: it parses the
project's own `actions.log` — scoped to the last `run_start` marker, since the
log is append-only across invocations — and reports, per agreement, the
outcomes the last run actually reached. **An agreement is concretely landed
when a real project's log shows it `holds` or `violated`.** Anything else,
including a green test suite and a full catalogue, is a declaration.

Pointing this at sqlite for the first time is how the following was found:

| | |
| --- | --- |
| Symptom | ten agreements, every one `unavailable`, at every step of every scenario |
| Cause | sqlite's `realize` built its spec with the template default instead of the project's own `base_spec`, so the `api_source` and inspector closures it declared were reachable only from the CI renderer. The run produced no inspection JSON at all. |
| Second cause | the derived evidence paths spelled tiny's filenames. The framework's binding summaries land in `inspect.json` and its compiled-stub summary in `inspect_stub.json`; tiny writes its stub to `inspect.json` and its surface to `inspect_mli.json`. The derivation asked for tiny's spellings, so it resolved nothing on any other project. |
| Third | sqlite inspected its binding at the probe step, while the derivation names the step that installs it — which is also the earliest point the evidence exists (§1.3). |

All three are fixed, and `api_names_present` now reaches `holds` on all six
scenarios of a real sqlite run. It was falsified the way any check should be:
adding a name that does not exist to sqlite's OCaml watchlist flips the same
run to `violated`, and removing it flips it back.

A surface input now carries both filename conventions, which is safe only
because the reader selects evidence by the `kind` the inspector declared rather
than by the first path that happens to exist — otherwise, on tiny, the compiled
stub summary would be read as a user surface.

`make canary-agreement-roundtrip` is this assertion as a gate, and it runs
inside `make canary-post-check`. §4 walks the eight
points a run passes through and what each undecided outcome means — since
2026-09-15 the outcome WORD carries that (`unavailable` / `undeclared` /
`vacuous`) rather than a reason string a reader had to interpret;
§5 tracks which agreements have made it.

An agreement may eventually have several checking methods, including external
checkers. Such a method needs explicit prerequisites, evidence and result
coverage. Integration as a checking method and use as an experimental baseline
are separate roles. The related-report discussion is in
[the practical-bindings report](../../research/related/canary-practical-cross-language-bindings-report.md).

**Backend boundary:** local pre/postconditions are closures. The GH renderer
does not render those closures, although it does render some symbol checks and
expected-failure verification. A green CI job therefore does not establish
parity with local Canary checks; saying it means only “every command exited 0”
would also be inaccurate.

The proposed direction is explicit check actions (`[Pre; Action; Post]`) from
one definition. Whether they carry a command or a check identity plus inputs
remains open. [check_evaluation.md](../check_evaluation.md) owns that proposal;
its historical CI summary should be read with the qualification above.

#### 4.9.3 Result interpretation and attribution

#### 4.9.4 Evidence coverage must accompany a result

The pass meanings are in §1.5; the eight outcomes that carry them are in
§1.2.1. This was a design requirement and is now the result type: a method's
evaluation returns one outcome, and a step logs every selected method's
outcome, so its record says which checks ran, which found nothing, which had no
evidence, and which are not implemented. One record supplies both that report
and the step's acceptance (§4.9.1), so a run's pass/fail and its agreement
coverage are no longer two independent derivations.

What this does **not** yet establish. A malformed inspection now raises and
becomes an `error` outcome for the method that read it, rather than being
swallowed into "no watchlist" — but the loaders still emit kind-mismatch
warnings to stderr and continue, so a diagnostic on the way to a `holds` is not
yet part of the record. The GH backend renders none of this. And a warm step
reports nothing at all, by construction.

#### 4.9.5 Attribution needs a trusted claim

A declaration mismatch identifies a disagreement between artifact and declaration.
Use the authority stated in §1.6 before blaming either. For a versioned pair,
Forward/Backward direction describes which side is newer and can help explain
a missing requirement. It does not by itself establish a violated promise or
exclude a packaging/environment fault. Packaging disagreements may implicate
the cooperation, as in [`components.md`](components.md) §5.5.2.

#### 4.9.6 From candidate to check

For a candidate generated from a diff, manifest or failure:

1. Name the claim, its authority and a concrete falsifier.
2. Identify the input artifacts, their provenance and the earliest observation site.
3. Specify the relation and its applicability, including allowed transformations.
4. Build a minimal counterexample and a corresponding non-failing case.
5. Add the family implementation and registry row, or record a proposal with
   the missing evidence. Verify its effect in a representative world.

A heuristic sweep generates candidates. It must not silently become the oracle
that judges them. Keep project measurements and remediation in project reports.

---


## 5. What is left

### 5.1 The checklist

Landing an agreement on a project, in order:

1. `canary checks <p>` — does it fire at any of this project's actions?
   If not, the world or the mechanism is the answer and no wiring will
   help; [pass 2](../enumeration/stage2_analyse_spec.md) decided it.
2. `canary emit <p> --stage realize` — is there an inspector step for the
   evidence it needs, at the step the derivation names? If you do not see
   `*_inspect` steps, nothing downstream can work.
3. Run it, with the deciding steps COLD. A warm step re-checks nothing
   and emits no `agreement_outcome`, so a cached verdict reads as an
   empty report: `make canary-refresh PROJECT=<p>`.
4. `canary checks <p> --observed` — did it decide?
5. **Falsify it.** Break the declaration it is held against and confirm
   the same run flips to `violated`. A check that has only ever said
   `holds` has not been shown to be a check.
6. If it had an `ag_waiting_on`, clear it. Nothing else to record — the
   catalogue's table is generated, and the landed/not split is
   `canary checks --landing`'s to state.

### 5.2 Four states, four kinds of work

Telling them apart is most of the value of asking.

| the log says | it means | the work |
| --- | --- | --- |
| `unavailable` | the evidence was not produced | WIRING — an inspector is missing, or the reader runs before the writer |
| `undeclared` | the artifact was read; the project declared nothing to hold it against | the SPEC |
| `vacuous` | both sides read, nothing of this kind exists here | nobody's — this is a correct answer |
| `not_implemented` | no evaluator | a CATALOGUE decision: state the claim's scope first |

`not_applicable` in a log means something else again: applicability
became a static property of the project on 2026-09-14, so a fresh run
drops such a method before it evaluates. Seeing it means the log
predates that — `make canary-refresh PROJECT=<p>` and read it again.

### 5.3 What a landing has cost, so far

Every landing so far has turned out to need something other than the
comparator, and it has been the same something four times:
**the producer picks a step, the consumer derives one, and nothing makes
them agree.** tiny's filenames; sqlite's binding inspected at the probe
while the derivation names the install; `lib_evidence_tags` naming only
the build-tree probe's tag; the opam-binding template inspecting at
`Probe_binding` rather than where a binding is provisioned. Four
instances, each fixed individually, none fixing the class.

The walkthrough above positions each failure mode at the point in a run
where you meet it; [`../../backlog.md`](../../backlog.md) §50 is the general fix and
[`../action_model.md`](../action_model.md) §6 says what it needs.

Two more that are worth knowing and are not that class:

- **A check that passes only on a warm tree is not a check.**
  `probe_binding` did not depend on `probe_lib`, so where the check
  decided it decided by reading a file a PREVIOUS run had left behind.
  The round-trip gate clears the lib probes' output too.
- **A derived package earns the STUB inspection only.** Merging the two
  channels generated an mli scan beside each project's own, and zarith's
  `Zarith_version` and libffi's `Ctypes_foreign_basis` ship with no
  `.mli` — so the generated summary reported missing what ocamlobjinfo
  lists, turning a holding agreement into a false `violated`.
  `binding_store_pkg` and `binding_user_facing_pkg` are separate fields
  for exactly this reason.

**The universality answer is good news:** `required_symbols_exported`
landed on cairo, libffi, ssl and zarith *with no per-project change*,
once the two facts a project already declares reached the runner — its
`api_source` and the package its binding is
(`Canary_pipeline.with_declared_facts`). Both had been read only by
`spec-check` and the CI renderer.

### 5.4 The distance-0 backlog

[`theory.md`](theory.md) §5 lists, per action, the full-information
agreement the real tool established and what post-fact checking can
recover. Walking that against the registry gives a second backlog,
ordered by **how far apart the two sides of the comparison are** rather
than by subject.

| distance | both sides are… | example |
| --- | --- | --- |
| **0** | available at the one action — an artifact and something we still hold | the build tree beside the staged tree; a library beside its declaration; a ref we can re-resolve |
| **1** | from adjacent actions; established by the toolchain only if same-origin | a stub's undefined references against a library's exports |
| **≥2** | from different worlds, or needing a runtime trace | denotation across worlds, interposition |

⚠ **This is not the `lag` column in the recovery grid**
(`canary checks --firing`, and table 2 of `make view`). DISTANCE is
between the two SIDES OF A COMPARISON — how much was lost between the
things being compared. LAG is between WHERE THE RULE RAN and WHERE WE
CHECK — how far the surviving evidence travelled before anyone read it.
`required_symbols_exported` is distance-1 (stub and library come from
adjacent actions) and lag-0 (it fires at the very link that created the
requirement). A row can be cheap on one axis and expensive on the
other, which is why both exist.

Distance 0 is where the least was lost, so it is where checking is
cheapest and strongest. **One registered agreement is distance 0** —
`staged_interface_preserved`, which compares two copies of one library
while both are still present; the rest are distance 1 or planned. (This
sentence said *"every registered agreement is distance 1 or planned"*
until 2026-09-17, contradicting the paragraph below it that records
lifting exactly that one.)

**The distance-0 checks with no row are the first five proposals** —
`canary checks --catalogue`, or the *Proposed* section of
§3 above, which prints each one's claim and what
it needs. They came first in that list precisely because distance 0 is
the cheap end.

> A table of those five stood here until 2026-09-17 and it had already
> drifted, which is why it is a pointer now. It described
> `exports_accounted_for` as *"the converse of
> `declared_symbols_exported`; together they make an equality rather
> than an inclusion"* — the framing the registry itself records as
> **wrong** since 2026-09-15: `native_api.stable_symbols` is a
> WATCHLIST, not a manifest, so on sqlite the converse would report 267
> orphans, and what it actually needs is a declaration kind no project
> can write today. The generated entry said so; the copy still sold the
> item as a free comparator. Fourth instance of the hand-copy class, and
> the same direction as the other three: the copy makes the work look
> more done, or cheaper, than it is.

**"Already runs" is not "already produces evidence",** and the
distinction is why this list shrank rather than landing. It first
claimed the top three needed only a registry row. Only one did —
`staged_interface_preserved`, lifted from a comparator that was sitting
in the status reporter (`Canary_status.install_diff_note`). §5.1 and
§5.7 are shell assertions *inside commands*: a `git rev-parse` in a
postcondition, `test -f` lines in a packaging step. They check something
real, but there is no evidence file for an evaluator to read, so
registering them means recording the fact first — the inspector tier,
not the free one.

Two preconditions that were on this list are **done**: `lib_evidence_tag`
(2026-09-12, world-aware at last) and routing the declarations
(2026-09-13, `with_declared_facts`), which is what let the three
declaration agreements decide at all.

### 5.5 `--strict` — while you are landing one

By default a detected disagreement does **not** fail the step. That is
deliberate and it stays: an `Expect_success` step's acceptance policy is
"the command succeeded and its postcondition holds", and a violated
agreement there is a finding about *artifacts* that the action was never
asked to fail on. ssl's `dependencies_provided: violated libcrypto.so.3`
is a real finding about a real spec gap, and it must not turn ssl red.

The cost of that default shows up exactly while an agreement is being
landed: `canary result` prints `✗` in the check column and the scenario
line says `PASS`, so the two views of one run disagree and you have to
read the log to learn which is right.

```sh
canary action sqlite --thin --strict     # CANARY_STRICT=1 for Makefile targets
```

Under `--strict` a violation fails the step that read the evidence, so
the two views agree and the run stops at the action that saw the problem
rather than three actions later. It adds no evaluation — the violations
are the same ones already reported; it only decides what they mean. The
failure is logged as `strict_violation` with the `slug/method: outcome`
of each, and the run header says `agreements: strict`.

It rides the step fingerprint, so a verdict earned permissively is never
served to a strict run. The permissive digest is unchanged, so turning
strict *off* again costs nothing — but a strict run is always cold.
Pinned by `strict.acceptance_policy`.

Note what this means on a project with declared mismatch cells: sqlite's
built-Stable lib is 3.43.2, chosen as the last release *before* 3.44.0
added `sqlite3_get_clientdata`, so `--strict` fails `build_lib` in those
four scenarios on the first run. That is the agreement being right about
a world the project built to be wrong. `--strict` is a debugging mode for
one landing, not a gate to put in CI.


### 5.6 Keeping this honest

- `agreements.planned_says_what_it_waits_on` — an agreement with no
  evaluator must declare `ag_waiting_on`, so a new planned row cannot be
  registered without saying what is in its way. It replaces
  `agreements.landing_doc_lists_every_agreement`, which pinned that this
  file had a row per agreement; the catalogue is generated from the
  registry and covers every agreement by construction, so that pin was
  asserting what the generator guarantees.
- `make canary-agreement-roundtrip` gates the landed rows against a real
  sqlite run, inside `make canary-post-check`.

### 5.7 Decided: `theory.md` and `components.md` stay apart

*(2026-09-17. Asked for in the same breath as this file's merge, then
investigated by reading both documents rather than their outlines.)*

**They should not merge, and the reason is not the section numbering.**
The numbering collision is real — both number their sections from one
to seven — but it is the shallow objection. The real one is that the two documents are
**orthogonal walks over one space, and each defines itself against the
other.**

- [`theory.md`](theory.md) walks **actions**: for each build step, the
  relation its tool enforced, what survived, and what post-fact checking
  can recover. Its last part is a procedure for finding the next
  agreement by following that axis.
- [`components.md`](components.md) walks **components**: for each kind
  of thing in a binding world, what could be claimed about it, what
  observation is available, and what that observation does not
  establish.

`components.md` says so itself, under *What this is not*: "It is not the
procedure for finding the next agreement. That is theory.md's, which
walks ACTIONS … This walks COMPONENTS … The two are complementary axes
over one space; a candidate found on either should be checked against
the other."

Merging them would put one sequence where there are two axes, and the
cross-check that sentence describes — find a candidate on one axis,
verify it on the other — would stop being expressible. Two documents is
the correct shape, and their separation is load-bearing rather than
accidental.

What WAS worth fixing, and is fixed: both had been left citing this
file's absorbed halves twice over after the merge sweep.

---


### 5.8 Ordered next work on the table

*(2026-09-17, from the user across one message — arranged here rather
than answered in a reply, because they are four different sizes.)*

**1. Three claims declare the wrong kind, and the `kind` column is what
showed it.** `behavior_matches`, `repack_preserves_api` and
`repack_complete` all pass `~reference:Declared_facts` — explicitly, not
by default — and for all three it looks wrong:

| claim | declares | arguably is | why |
| --- | --- | --- | --- |
| `behavior_matches` | `Declared_facts` | `Test_suite` | its stated blocker is that *"the expected values live inside the probe's source"* — there is no declaration canary can read, which is the definition of not being a declaration comparison. [`../directions.md`](../directions.md) §2 argues the oracle is the other side of the binding, or a suite |
| `repack_preserves_api` | `Declared_facts` | `Peer_artifact` | "preserves" is a comparison against the PRE-repack surface, which is a peer, not a declaration |
| `repack_complete` | `Declared_facts` | — | it composes three verdicts; whether a composition has a reference at all is the open part |

All three are the unimplemented ones, so nothing evaluates today and
nothing is wrong at run time. But `m_reference` feeds the diagnostics'
`implicates` split — *this artifact is wrong* versus *these two
disagree* — so it will matter the moment one gets an evaluator. Decide
per claim; it is three small decisions, not one.

**1b. Is `peer` one kind or two?** It is defined as *the second side is
another artifact, both present in the world under test* —
`required_symbols_exported` compares a stub archive's undefined
references against the library's exports, two real files and neither a
declaration. But `staged_interface_preserved` is also `peer`, and its
two sides are **two copies of one artifact**: a build tree and the
staged copy of itself. Those are different situations. Comparing a
consumer against a provider asks *do these two agree*; comparing a thing
against its own copy asks *did moving it change it*, which is a
preservation claim and cannot be violated by any disagreement between
distinct components. The registry already notes this asymmetry at the
staging evaluator, which names both sides positionally because
`lib_evidence_paths` would have compared the staged copy against itself.
Worth deciding whether that is a sixth kind (`Copy_of_itself`, or
`Relocation`) before a second preservation claim lands and inherits the
ambiguity.

**2. The standalone kind has no agreement, and the user named the first
one.** `Artifact_itself` is in the type and used by nothing: a claim
about one artifact against the format's own rule, with no second party.
The instance:

> *"a native binary shouldn't contain local path if it's to installed"*

An installed library that records a RUNPATH into the build tree it was
made in is wrong **on its own terms** — against no declaration and no
peer. It is a good first `Artifact_itself` for four reasons: the
evidence already exists (`inspect_native.py` records `runpath` and
`rpath`), it is distance 0, it is rooted in a real tool's rule (the
install step is supposed to rewrite those paths), and the falsifier is
one line — install a library and look. It also has an off-the-shelf
cross-check, which is item 4.

**3. A second table for the DIRECTIONS.** The un-implemented claims now
sort to the bottom of the overview, which answers half of *"put the
un-landed agreement at the bottom rows of this table, or in a separate
table"*. The other half is the work in [`../directions.md`](../directions.md)
— versioning, cross-API correspondence, multiple package managers —
which has no registry row at all and so cannot sort anywhere. Those are
named, and their kind is known, and there is no implementation idea yet:

| direction | kind it would be | what it needs |
| --- | --- | --- |
| Mach-O `compatibility_version` | `declaration` or `peer` | nothing new — the evidence is extracted and unread |
| cross-API correspondence | `test-suite` | a generator, and a new action |
| cross-package-manager discovery | `peer` | a resolver trace nothing records |

They want a table of their own beside the overview, with the same
vocabulary, because the overview's shape is only defined for a
registered agreement.

**4. An ALTERNATIVE-TOOL column, for differential comparison.** The
user's: *"an alternative column so that we can fill into the related
tool, who can be exactly call at the same moment to call our checking,
then we can compare with it."*

This is `rt_tool`'s sibling and NOT the same thing. `rt_tool` names the
tool whose rule the agreement recovers — the linker, the C compiler, the
install step — and that tool ran in the past, possibly in another world.
The new column names a tool that could be **run right now, at the same
step, to answer the same question independently**:

| claim | could be cross-checked with |
| --- | --- |
| `declared_symbols_exported`, `required_symbols_exported` | `abidiff` (libabigail), `abi-compliance-checker` |
| `soname_matches_declaration` | `patchelf --print-soname`, `otool -D` |
| `declared_versions_exported` | `readelf --version-info`, `abidiff` |
| `dependencies_provided` | `ldd -r`, `auditwheel show`, `delocate-listdeps` |
| `staged_interface_preserved`, and item 2's path claim | `auditwheel` / `delocate` — they exist to check exactly staging and relocation |
| `signatures_agree` | `abidiff` over DWARF, which is strictly stronger |

The value is that a disagreement is a finding **either way**: if
`abidiff` says compatible where we say violated, one of us is wrong, and
finding out which is worth more than either answer alone. It is also the
cheapest available evidence that canary's comparators are right at all —
today nothing external confirms them.

Two things to settle before building it. It is a field per agreement
(*ag_cross_check*) if the tool answers the whole claim, or per method if
it answers one comparison; and a column is worth having even while the
tool is never RUN, because naming it is what makes the gap visible —
which is the same argument as `implemented at`.

---

## Appendix A. Implementation map

### A.1 Ownership

| Module                                                    | Owns                                                                                                                                                                  |
| --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `canary_agreement_common.ml`                              | The agreement and checking-method types, the outcome type and `evaluate_method`, inspect inputs, agreement names, firing helpers, the cache epoch and JSON primitives |
| `canary_agreement_ocaml.ml`, `canary_agreement_cstubs.ml` | Language/mechanism evidence facts; no check-family list                                                                                                               |
| `canary_agreement_<topic>.ml`                             | Symbols, API surface, identity, types and behaviour families: claims, loaders, comparators, evaluators, agreements and counterexamples                                |
| `canary_agreement_composed.ml`                            | Composition of other families' verdicts                                                                                                                               |
| `canary_agreement.ml`                                     | Rows (name, doc anchor, enabled), selection and evaluation, and the derived views                                                                                     |
| `canary_agreement_report.ml`                              | On-demand compat/verify reports and their output-tree navigation                                                                                                      |

A family publishes `checks` — its `(agreement_id * agreement)` pairs — and no
`composes`; it refers to shared facts and types rather than sibling families.
The composition module declares its sibling dependencies. The registry gathers
agreements instead of copying their claims, and the union of the families'
declarations is pinned to cover every name exactly once.

The three entry points, in the order a reader meets them:

```ocaml
Canary_agreement.evaluate_in_context ?disabled ~mechanism ~lang ~world ~action ~resolve ()
Canary_agreement.evaluate_over_inputs ?disabled ~resolve inputs
Canary_agreement.agreements_for ~mechanism ~lang ~world ?action ()
```

The first is the production path (§4.9.1). The second is the project-supplied
input path the compat expectations use, and it deliberately skips
applicability. The third selects without evaluating, for the checking index.
`inputs_of_agreement` remains the explicit per-name lookup.

### A.2 Derived views and their limits

```ocaml
Canary_agreement.pp_agreements ()
Canary_agreement.pp_catalogue ()
Canary_agreement.pp_firing_table ?mechanism ?lang ?provision ()
Canary_agreement.pp_agreement_overview ?provision ()
Canary_agreement.fill_list ?mechanism ?lang ?provision ()
```

`canary checks` prints the first, `canary checks --catalogue` the second, and
`canary checks --firing` prints the third and fourth. The catalogue is the
generated form of §1.7's prose: every agreement with its reference expectation
and each method's kind, reference, implementation status, firing sites and
scope limits. The overview is also `make view` table 1, and its rendering is
documented in [`../matrix.md`](../matrix.md).

The firing table uses a uniform-provision world for its convenience view.
Its marks are derived as follows:

| Mark | Calculation                                                           |
| ---- | --------------------------------------------------------------------- |
| `·`  | No method of this agreement fires at this action                      |
| `×`  | The row is switched off in the registry                               |
| `∅`  | Every firing method is inapplicable under this mechanism and world    |
| `⊘`  | Every applicable firing method is planned (no evaluator)              |
| `✓`  | Some applicable firing method is evaluated and ships a counterexample |
| `~`  | Applicable and evaluated, no counterexample yet — the fill list       |

`cell_status_of` consults the enabled flag and each method's applicability;
what it still does not test is whether the evidence a method names actually
exists in a given run, which is a fact about a run rather than about the
registry. Fixture presence is checked per agreement, not per mechanism/action
cell, so one fixture can mark several cells `✓`. This view is structurally
total, not evidence of complete semantic or execution coverage.

#### A.2.1 What the overview does NOT reach

*(2026-09-17, from the user: "check if the agreement table can represent
the existing and planned agreement … record any drifts [that] cannot be
trivially handled. e.g. I think the current table doesn't mention
versioning-related test generation, cross package manager experiments,
and cross-api testing".)*

The overview iterates `agreement_registry` — the **13 implemented
agreements, as 25 rows** (one per distinct firing pattern). Everything
else is absent from it, in four classes that need four different
answers. Only the first is a table problem.

**(a) and (b) — the eight proposals — are collected in ONE GENERATED
PLACE:** *Out of the table* — §3 above, or
`canary checks --catalogue`. Each proposal carries a `prop_frame` saying
why it has no row, and the section groups by it, so the four kinds of
work stay apart without anyone maintaining a list:

| group | what it means | count |
| --- | --- | --- |
| held up by a schema field | the per-action frame REACHES it; `proposed` carries no rooting and no target list, so there is nothing for the `R` and ▣ columns. A schema change, and it costs the row's meaning — `lag`, decided and blame are undefined without a firing | 4 |
| not filed either way | [`theory.md`](theory.md) §7.1's filter has never been applied | 1 |
| not an agreement | theory.md §7.1 — it recovers canary's OWN rule, so it is a world assertion | 1 |
| outside the per-action frame | theory.md §7 — set properties and cross-world properties are not per-edge | 2 |

Two things worth stating that the generated section does not.

**The overview's blind spots coincide exactly with the model's.** The
claims it cannot show are the ones [`theory.md`](theory.md) §7 says the
per-action frame does not explain. That is reassuring rather than a
defect: the view and the model fail at the same place, so the table is
not hiding anything the theory believes it can reach. The coincidence is
pinned — `agreements.theory_names_the_frame_exclusions` requires the
registry's classification and the prose of theory.md §7 and §7.1 to name
the same proposals, in both directions.

**The counts above are transcribed and the groups are not.** If they
disagree with the generated section, the generated section is right.

**(c) One target the columns cannot name: the PACKAGE.** The leading ▣
columns range over `Canary_basic.artifact_kind` — Source, Headers, Lib,
Binding, Binding_source, App. A package is none of them, and three
claims want it as their target: `package_contains_declared_files`, the
third version layer of [`../directions.md`](../directions.md) §3
(*package_version_names_the_library*), and the depext claim of
[`../directions.md`](../directions.md) §1. This is a `base/` vocabulary
question, not a table one, and it is the one gap here that no amount of
work on the view would close.

**(d) Two of the user's three examples are not agreements at all** — and
the table's silence is the [seam](README.md#what-is-not-here--the-seam)
working, *agreement/ owns the CLAIM, enumeration/ owns the OCCASION*.
What was missing is anything that says so, which is why their absence
read as a gap:

Names in *italics* below are PROPOSED and have no definition in `src/`
yet, which is why they are not backticked — in this directory a
backticked identifier means the code has it.

| direction | the agreement half — fits the frame | the half that is NOT an agreement |
| --- | --- | --- |
| cross-package-manager | *discovery\_matches\_link* (target: Lib; open question whether `pkg-config` ANSWERING counts as rooting when nothing ENFORCES) | combining a binding with a lib from another PM is an **enumeration axis** — `store_config`, passes 1 and 3 |
| cross-api / correspondence | a new row, distinct from `behavior_matches` because the C side is the oracle | the **generator** produces cases, not claims: a new action plus generated drivers |
| versioning | *compatibility\_version\_satisfied*, `install_name` normalisation | *(none — this direction is agreements all the way down)* |

**The versioning one is the row to want**, and the overview is already
shaped for it: `fmt` exists precisely to say a claim ranges over one
object format, and today it only ever prints `E·`
(`declared_versions_exported`, `required_versions_exported`). A Mach-O
`compatibility_version` claim would be the first `·M`, which is the
column earning its keep rather than annotating a constant. Its blocker
is not the frame — `canary checks --landing` is platform-blind, so an
agreement landed only on macOS would report as landed everywhere
([`../platform.md`](../platform.md) §6).

### A.3 Existing evidence names

The Sf.1–Sf.5 labels are gone from the agreements (2026-09-12). They were a
second, coarser description of what each check reads, they had drifted from
the inputs they described — the compiled consumer was labelled Sf.3 in one
place and Sf.5 in another — and the concrete input list was always the clearer
statement. The input constructors below are the vocabulary that remains.

| Input                                                            | Actual evidence                                                                       |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `Native_lib` / `C_stub`                                          | Library exports / compiled consumer's undefined references                            |
| `Ocaml_mli` / `Python_attrs`                                     | Names inspected from an OCaml interface / imported Python module                      |
| `Abi_surface`                                                    | Compiled consumer's identity and dependency metadata                                  |
| `Versioned_exports` / `Versioned_req`                            | Provider's exported / consumer's required symbol-version tags                         |
| `Typed_header` / `Typed_binding_stub`                            | Header / binding signature summaries used for textual return/argument-type comparison |
| `Declared_exports` / `Declared_soname` / `Declared_version_tags` | What the PROJECT declared — evidence that does not come from a file the run produced  |

The `Declared_*` constructors exist so a declaration comparison has the same
evaluator shape as a peer comparison, instead of being reachable only through a
partially applied closure in a fixture.

They are supplied now, which is worth recording because this paragraph
said the opposite for months. `Canary_pipeline.with_declared_facts`
routes a project's `api_source` and its binding's package into the
runner spec (2026-09-13); before it, every project ran with
`api_source = None`, the declaration reached only `spec-check` and the
CI renderer, and the three declaration agreements reported `unavailable`
by construction. `declared_symbols_exported` decides on sqlite today —
and its violation is the project's own forward cell, a stable-channel
build at 3.43.2 missing `sqlite3_get_clientdata`, not a synthetic
break.

## Appendix B. Doc/code bridge

Registry entries carry their canonical name and a numbered document anchor.
`all_agreements` combines registered entries and proposals. Existing layer tests
check:

| Pin                                                     | Property                                                                                                                                                                                                                                                                                  |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `agreements.registry_complete`                          | Every name has exactly one row; every row states a claim, a reference expectation, a fault tag and at least one method; every method states its scope limits and, if it has no evaluator, why; names round-trip and the retired numbered spellings do not parse                           |
| `agreements.families_declare_the_catalogue`             | The union of the families' declarations covers every name exactly once, and the split claims differ                                                                                                                                                                                       |
| `agreements.firing_defaults`                            | Where each method fires, per mechanism and world — including that a declaration comparison fires only where the library was produced                                                                                                                                                      |
| `agreements.fixtures_execute`                           | Every counterexample reaches its stated outcome with its stated diagnostics, through the method the registry holds                                                                                                                                                                        |
| `agreements.fixtures_complete`                          | Which agreements have a counterexample, as an explicit set                                                                                                                                                                                                                                |
| `agreements.action_path_reports_outcomes`               | The production path: a step's context selects, resolves, evaluates and reports — holds, violated, unavailable, a planned method as `not_implemented`, and a violation at a passing step as `unconfirmed`                                                                                  |
| `agreements.one_record_serves_reporting_and_acceptance` | The same record drives the verdict: a confirmed disagreement accepts the step and is persisted as its attribution, a predicted failure that does not happen rejects it, the declared route reaches evidence the derived one cannot, and a merge keeps the finding when both routes decide |
| `agreement.violation_carries_a_witness`                 | A `violated` with no findings is normalized to `inconclusive`, so nothing downstream can require a failure it cannot recognize                                                                                                                                                            |
| `agreements.slugs_unique_and_named`                     | Entries have unique nonempty names, claims, reference expectations and numbered anchors, and no numbered identifiers                                                                                                                                                                      |
| `agreements.every_agreement_has_an_entry`               | Registered and proposed entries appear in the combined view                                                                                                                                                                                                                               |
| `agreements.doc_names_live_code`                        | Recognized code names in this document have definitions                                                                                                                                                                                                                                   |
| `agreements.doc_anchors_exist`                          | Each entry's numbered section exists here                                                                                                                                                                                                                                                 |
| `agreements.doc_cross_refs_resolve`                     | Recognized internal numbered references resolve                                                                                                                                                                                                                                           |
| `runner.marker_stale_on_spec_change`                    | Includes the agreement cache epoch: the two compat expectations carry it and nothing else does                                                                                                                                                                                            |

These pins check names, structure and the one integrated path. They do not
establish that a section accurately explains a claim, that every prose
candidate has a registry row, or that proposal requirements are current.
Review those semantically when changing the catalogue.

**The cache and the agreements.** Agreement names are persisted: a verdict
marker records which agreements confirmed an expected failure. A change to the
names, or to what a step's acceptance computes, therefore invalidates exactly
those verdicts — through the existing step fingerprint, with the
`evaluation_schema` epoch mixed into `expectation_form` for the two compat
expectations and nothing else. Builds, fetches and hand-written expected
failures stay warm and no output tree is deleted. Readers of a marker also drop
names that no longer parse, so a marker written before a rename cannot
attribute a verdict to an agreement that no longer exists.

The rule for where the epoch goes: **an expectation carries it iff its
acceptance consults an agreement.** The context evaluation runs at more steps
than those two, but only reports there, and invalidating an `Expect_success`
step's verdict would discard something the change says nothing about. Bump the
epoch when evaluation semantics change, not when a comparator's internals do.
Two bumps so far: `named-agreements-1` for the names the markers record, and
`named-agreements-2` for the merged record, which can give a step a prediction
it did not have before and so flip an agnostic expectation's polarity.
