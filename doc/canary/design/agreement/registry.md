# Tool-Grounded Agreement Catalogue for Cross-Language Binding Checks

**Status:** design with a partial implementation. Reviewed against the working
tree on 2026-09-12, after the naming migration and the first completed
production path. Agreements now carry descriptive names and explicit
evaluation outcomes, and one symbol agreement runs end to end from an action's
context. Evidence routing for the remaining agreements, coverage across
backends, and the repacking and dependency-identity claims remain open;
§7.4 tracks them.

This document defines what Canary checks around provider × binding × consumer
worlds, what evidence supports each claim, and what the result means. It is
the MODEL and the CATALOGUE; its siblings are
[`README.md`](README.md) (the map), [`pipeline.md`](pipeline.md) (a project
end to end — where a run touches this registry and what to do when an
agreement reports `unavailable`) and [`landing.md`](landing.md) (planned vs
effective, per agreement). World enumeration belongs to
[the pipeline design](../enumeration/README.md); execution and caching belong
to [realization](../enumeration/stage5_realize_steps.md).

The exposition starts with **fixed artifacts, already available at known
locations**. It introduces their inspectable properties and language-specific mechanisms
before varying versions, provenance and deployment. Version-bearing metadata
can appear in the initial artifact description; replacement and external
selection are later questions. This keeps core language features distinct from
the facilities used to distribute them.

Read §1 for the agreement model, §2–§3 for the artifacts and bindings, §4–§6
for replacement, packaging and deployment, and §7 for registry integration and
coverage. Appendix A maps the implementation; Appendix B describes the doc/code
checks. The same order can guide the paper while planned observations and
working checks remain explicitly distinguished.

## 1. Agreement model and catalogue

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

### 1.7 The catalogue

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
nothing" permit is undecided (§6.3.1), and a name should not settle a claim
the catalogue has not.

The table below separates the comparison, the evidence, and whether an action
actually reaches it. Read `canary checks --catalogue` for the same content
generated from the code, with each method's scope limits.

| Agreement                            | Comparison                                                         | Evidence                                                | Reached from an action                                                                     |
| ------------------------------------ | ------------------------------------------------------------------ | ------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `declared_symbols_exported`          | Declared exports minus actual exports                              | Native summary plus a supplied `Declared_exports`       | Fires at `build_lib`; no action supplies the declaration, so it reports `unavailable`      |
| `required_symbols_exported`          | Consumer requirements minus provider exports                       | Inspected stub and native library                       | **Yes** — selected from the action context, evaluated and reported (§7.1)                  |
| `api_names_present`                  | Missing watchlist names computed by the inspectors                 | OCaml interface and Python attribute summaries          | Yes, through both the context path and project prediction paths                            |
| `behavior_matches`                   | None; the probe's own assertions are the observation               | Running program and embedded expectations               | Selected at every probe; reports `not_implemented`                                         |
| `soname_matches_declaration`         | Declared name against the recorded provider name                   | Native identity plus a supplied `Declared_soname`       | Fires at `build_lib`; declaration not supplied, so `unavailable`                           |
| `soname_matches_requirement`         | Provider name against consumer requirements, filtered by name stem | Provider identity and consumer dependency metadata      | Fires where a consumer records dependencies; `not_applicable` under compiled-stub archives |
| `declared_versions_exported`         | Declared tags minus exported tags                                  | ELF export tags plus a supplied `Declared_version_tags` | Fires at `build_lib`; declaration not supplied, so `unavailable`                           |
| `required_versions_exported`         | Required tags minus exported tags                                  | ELF provider/consumer version summaries                 | Same applicability as the soname pair; no counterexample fixture yet                       |
| `signatures_agree`                   | Return and argument-type strings for names on both sides           | Header and binding signature summaries                  | Yes; evidence depends on the source-scanning inspectors                                    |
| `dependencies_provided`              | Direct dependencies against one provider and a fixed ambient list  | Provider identity and consumer dependency metadata      | Same applicability as the soname pair; limits in §5.6                                      |
| `repack_preserves_api` (provisional) | None registered; a name-based helper exists                        | Helper takes names and a rename mapping                 | Selected at every probe; reports `not_implemented`                                         |
| `repack_complete` (provisional)      | None registered; a verdict composition exists                      | Component verdicts                                      | Selected; reports `not_implemented`                                                        |

Proposed agreements have no method at all: `denotation_stable_across_worlds`
needs an observable correspondence between implementations;
`no_duplicate_implementation` needs an identity/containment policy;
`interposition_binds_build_target` needs a resolution trace and expected target.

Framework checks and future checking methods are not all registered yet.
Their existing and planned observations belong with the component discussions
below, rather than in a second catalogue organized by different criteria.

### 1.8 Sources that generate candidates

Version diffs, upstream manifests, historical failures and translated tests
can propose new checks. A changed export set alone is a difference; it becomes
a failure when a consumer requirement or preservation claim contradicts it.

A native test translated through a binding provides an expected result. If the
native test passes and the translation disagrees under corresponding inputs,
investigate the binding, translation and marshalling assumptions. A direct and
a helper-mediated translation can also be compared. The promotion workflow is
in §7.3.

### 1.9 From the catalogue to the components

Languages provide tools and artifacts; mechanisms determine how foreign
calls reach a provider. Families consult those facts when choosing inputs and
firing sites. The body explains those facts in the following order:

| Section                              | Question and material                                                                 |
| ------------------------------------ | ------------------------------------------------------------------------------------- |
| §2 Common artifact foundation        | Presence, identity, declared exports and recorded dependencies of the native provider |
| §3 Language bindings                 | OCaml artifacts and concrete checks per mechanism; Python in the same order           |
| §4 Versions and replacement          | What changes when a header, library or binding is replaced?                           |
| §5 Packaging and provenance          | How are those artifacts selected and supplied? Per-manager details and interactions   |
| §6 Deployment and execution          | What is staged, selected, loaded and exercised?                                       |
| §7 Registry integration and coverage | How do actions obtain checks, and how are evidence and results reported?              |

These sections expand the checking context, not a mandatory execution sequence.
Each language's mechanisms stay together. Packaging sections reuse that language's
artifact vocabulary and add external selection and installation claims. A new
language adds a language subsection; a new mechanism extends it; a new package
manager extends the packaging discussion without redefining language features.

Within each discussion, state the intended claim independently of implementation
status, then explain the available observation and its limits. Section 2 gives
the recurring authoring questions.

## 2. Common artifact foundation

Begin with resources and their observable interfaces, then the native provider
shared by the language examples. Assume the intended artifacts can already be
located. How they are selected and distributed is introduced later.

For each agreement, name the claim, its reference expectation, the artifacts
and exact comparison, and the action where its evidence becomes available.
State the current implementation and what its result does not establish.
The language and mechanism sections apply this pattern to concrete checks.

### 2.1 Resource presence and identification

Presence asks whether a reference yields a resource. Identification records
what was found. These provide evidence for agreements; they do not decide
compatibility themselves.

| Substrate                    | Presence                       | Identification evidence                                            |
| ---------------------------- | ------------------------------ | ------------------------------------------------------------------ |
| File system / artifact store | Referenced object exists       | Path, kind, hash, binary metadata                                  |
| Git checkout                 | Tree exists                    | Resolved commit and declared contents                              |
| URI / remote store           | Resource can be fetched        | Final URI, content hash, returned metadata                         |
| Package manager              | Package exists or is installed | Version, package identity and owned files from the manager's query |

Package presence and file presence are different claims even when the package
should produce that file. Compose the checks where both matter. Action markers,
pin checks, ref checks and staged-file checks implement parts of this model
today; there is no unified resource-evidence capability yet.

Resolution builds on identification: it asks which candidate a particular
lookup selected (§6.2). A marker's existence alone does not identify the selected
artifact or establish its freshness.

### 2.2 Native provider agreements

The provider has source declarations and a realized object. Inspectable
properties include exports, undefined references, symbol kind, version tags,
identity, dependencies and available debug information. Producing language and
object format vary independently: a C ABI can be produced by several languages,
and torch already exercises a mangled C++ boundary. ELF and Mach-O are in use;
PE/COFF is untried. Platform details belong to [platform.md](../platform.md).

Three agreements compare what the project declares with what the produced
library actually records. All three fire at `build_lib` only — a declaration
comparison has evidence exactly where the library was produced, and nowhere
else. Their firing consults neither the language nor the binding mechanism:
whether the built library exports what the project declared is the same
question under ctypes as under compiled stubs. (Until 2026-09-12 they shared a
firing derivation with their peer counterparts, which carried both an extra
`build_lib` cell for the peer checks — where no consumer record exists yet — and
a static-mechanism guard that would have left a ctypes-only project with no
declaration check on its own library.)

| Agreement                    | Evidence and comparison                                                 | Current limit                                                             |
| ---------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `declared_symbols_exported`  | Inspect exported symbols and subtract them from the declared export set | Only declared names are covered; signatures and behaviour are not checked |
| `soname_matches_declaration` | Read the binary's own identity and compare it with the declaration      | Matching a name does not identify a unique implementation                 |
| `declared_versions_exported` | Compare declared tags with exported ELF symbol-version evidence         | Does not establish compatibility beyond those tags                        |

The declaration each needs is an explicit evidence input — `Declared_exports`,
`Declared_soname`, `Declared_version_tags` — carried in the same list as the
inspector outputs, so a declaration comparison has the same evaluator shape as
a peer comparison. No action supplies one today. That gap is therefore visible
at run time as `unavailable` with its reason, rather than as a comparator
nobody calls (§7.4). A tool's exit status and output presence are additional
observations, not replacements for these comparisons.

**Proposed:** compare header signatures with matching DWARF debug information
from the produced library. Ordinary C symbol tables do not carry full function
signatures, and requesting debug information does not guarantee every required
type is observable. Record the header and binary identities before comparing
them. This is a separate check requiring additional evidence.

#### 2.2.1 Recorded dependency metadata and its limits

ELF `DT_NEEDED` records dynamic dependency names chosen at link time. Entries
are commonly sonames, but can be pathnames. Linker options affect the list:
`--as-needed` retains libraries according to link-time reference rules; the
record is not a list of every dependency used during execution. See the
[GNU linker options](https://sourceware.org/binutils/docs/ld/Options.html).

On Linux, a dependency containing a slash is treated as a pathname. Otherwise
loader search includes RPATH/RUNPATH, environment paths, the cache and defaults,
subject to loader rules. RUNPATH applies to direct dependencies, not their
children; secure execution can ignore environment settings. See
[ld.so](https://www.man7.org/linux/man-pages/man8/ld.so.8.html).

| Property            | ELF                       | Mach-O                                                   |
| ------------------- | ------------------------- | -------------------------------------------------------- |
| Recorded dependency | `DT_NEEDED`               | `LC_LOAD_DYLIB` install name                             |
| Own identity        | `DT_SONAME`               | `LC_ID_DYLIB`                                            |
| Embedded lookup     | `DT_RPATH` / `DT_RUNPATH` | `LC_RPATH` and loader-relative names                     |
| Inspector           | `readelf`                 | `otool`                                                  |
| Version evidence    | ELF symbol-version tags   | Library compatibility version; not ELF symbol versioning |

Canary's native inspector normalizes dependency data for both formats, but
normalizing fields does not make their resolution semantics identical.
Dynamic `dlopen` requests do not add a `DT_NEEDED` record to the caller; source
declarations and runtime recording are separate possible evidence.

### 2.3 Recorded requirements and actual resolution

“This artifact requires X” is a recorded requirement. “This execution selected resource
R for X” is a resolution fact. Static comparison can reject some pairings
without running a loader, but matching recorded names does not establish which
object or symbol definition will actually be used.

## 3. Language bindings

For each language, introduce its tools and artifacts before its
foreign-call interface and mechanisms. This section assumes fixed, available
artifacts. It checks concrete API declarations and available names; behavioural
preservation of wrappers needs an explicit expectation, developed through
concrete examples rather than a universal repacking stage.

Use the authoring questions in §2 to connect each mechanism's artifacts to its
agreements. Only the OCaml and Python cases are developed here; additional
languages and mechanisms can follow the same organization.

### 3.1 OCaml: language first, then foreign calls

#### 3.1.1 OCaml interface and archive agreements

Introduce OCaml's implementation/interface distinction, compilation and archive
artifacts before foreign calls. The compiler checks implementation/interface
agreement; Canary inspects `.mli` declarations and uses `ocamlobjinfo` for
archive metadata. Names and signatures can be inspected even when their
behaviour has no generic specification.

The detailed account should follow source declarations → compiled interfaces
and modules → archives → consumer compile/link. Archive module names can depend
on wrapping conventions. Findlib's package layout is relevant to locating these
artifacts; opam's choice and installation of packages is the later §5 pass.

Current observation: `api_names_present` checks a declared watchlist against
the inspected interface. An empty watchlist is reported `inconclusive`, not as
a pass. Candidate: compare declared package contents with actual archive
modules and files. Neither establishes the behaviour of the values named.

The compiler checks implementation/interface agreement during compilation.
`api_names_present` instead asks whether the interface obtained in this world
contains the names the project expects. These checks have different reference
expectations, even when they concern the same module.

#### 3.1.2 Compiled C stubs

Introduce the foreign-call boundary through `external` declarations and native
stub code, then follow stub compilation, OCaml archives and consumer linking.
The inspected static stub archive carries undefined native references but no
dynamic dependency section. That supports `required_symbols_exported`'s
provider/consumer symbol comparison; `signatures_agree` compares header and
binding signature summaries for shared function names. These are current
checks, with the limits stated in §1.7.

| Agreement                   | Exact comparison                                                                    | Evidence needed                           |
| --------------------------- | ----------------------------------------------------------------------------------- | ----------------------------------------- |
| `required_symbols_exported` | Required symbols minus exported symbols; a nonempty difference is a finding         | Inspected stub archive and native library |
| `signatures_agree`          | Compare return-type strings and argument-type lists for names present on both sides | Header and binding signature summaries    |

`required_symbols_exported` in this context is the completed production path:
§7.1 records what runs, and §7.4 what it establishes.

`signatures_agree`'s registered method compares textual signatures, not
semantic type equivalence, representations or ownership. Tiny's inspector
parses known C header declarations, but supplies fixed binding signatures when
their names occur in the binding source. General binding-signature extraction
remains planned. The separate `check_type` helper compares mapped arities
under a declared name mapping; it answers a different question and is
deliberately not the registered method. Names present on only one side are
skipped.

Successful compilation/linking supplies another observation, with its own
coverage. The archive has no dynamic dependency section, so the identity and
dependency agreements have no consumer evidence here at all — which they
report as `not_applicable`, a mechanism fact rather than missing evidence.

**Proposed:** retain the header evidence emitted by source scanning for later
wrapper and app checks. Each would need its own name mapping and expected
argument/result conversion. Record the header's version and origin: a source
checkout's header may not describe the fetched library used by the consumer.

`canary_agreement_ocaml.ml` owns the shared interface evidence;
`canary_agreement_cstubs.ml` owns the mechanism-specific evidence. Link options,
staged paths and the stub actually loaded require later deployment observations.

#### 3.1.3 Dynamic mechanisms: material to develop

Distinguish foreign-library lookup from dynamic loading of OCaml code. The
current `Dynlink` constructor is not a complete account of dynamic foreign
calls. Dynlink loads compiled bytecode objects or native plugins, so runtime
loading does not imply the absence of build-time evidence. Its registry
integration is not wired. See the
[OCaml Dynlink manual](https://ocaml.org/manual/5.2/libdynlink.html).

The next detailed pass should identify the intended dynamic foreign-call
mechanisms, their declarations and artifacts, and then determine which existing
checks apply. Avoid deriving all of those facts from a single static/dynamic
classification.

#### 3.1.4 User-facing wrappers: material to develop

Follow an external declaration into the OCaml functions that expose or wrap it.
The `.mli` names and signatures can be checked, but a wrapper may add
behaviour or combine native operations. Develop the direct and helper-mediated
examples using their particular expectations; do not infer behavioural
preservation from name or arity agreement. The common limits of the two repacking
agreements are in §6.3.1. Package selection and installed layout return in §5.1.

### 3.2 Python: language first, then foreign calls

#### 3.2.1 Python module agreements

Introduce modules, packages and import before the native interface. Source
names and the names exposed after import are different observations. Canary
uses imported attribute evidence for `api_names_present`; obtaining it
already executes module
initialization. The package's backing implementation may be Python code, a
compiled extension or runtime foreign calls.

The detailed account should follow module/package source → interpreter import
→ observable attributes. Distribution metadata alone does not establish which
module was imported. The packaging pass (§5) introduces installation choices;
the deployment pass (§6.2) checks actual origins and shadowing.

The current `api_names_present` observation compares the imported module's names with the
project's watchlist. An absent watched name is the falsifier. Import success
alone does not answer that question, and finding the name does not establish
the behaviour of the corresponding function.

#### 3.2.2 Compiled C extensions

Follow header and extension source → compiled shared object → Python module
import and calls. The shared object can carry undefined references and native
dependency metadata, supplying evidence for the compiled-consumer checks.
This mechanism is wired. Further component-specific candidates include the
extension entry point and its correspondence to the intended interpreter and
module name; available module names and runtime behaviour remain separate claims.

The compiled-consumer agreements use different records from the same object:
`required_symbols_exported` compares undefined references with provider
exports; `soname_matches_requirement` compares the recorded dependency name
with the provider identity; `required_versions_exported` compares required and
exported ELF version tags; `dependencies_provided` checks the remaining direct
names against its modeled provider and ambient list. All four are applicable
here — unlike under a compiled-stub archive, where they report
`not_applicable`. Their evidence routing remains part of the audit in §7.4,
and `dependencies_provided`'s limit is described in §5.6.

#### 3.2.3 ctypes and runtime foreign calls

Follow library/type declarations → library and function lookup → calls.
This mechanism is used by tiny and z3. There is no compiled binding stub;
header/declaration comparison remains a possible observation, while actual
resolution requires runtime evidence. A missing symbol can fail when its
function is looked up, during import or later, rather than necessarily at first
call. See the [ctypes documentation](https://docs.python.org/3/library/ctypes.html).

Concrete candidate: compare declared argument and result types with the C header
under an explicit mapping. This requires a declaration inspector and comparison
appropriate to ctypes; it is not supplied merely by having the compiled-stub
predictors. Runtime lookup can separately refute the expectation that a named
library or function is available. A later call can test a particular behavioural
expectation. Keep those three observations distinct.

#### 3.2.4 CFFI: material to develop

CFFI supports ABI and compiled API modes. Canary currently classifies `Cffi`
as `Dynamic_ffi` and does not wire it. Develop the modes' artifacts and evidence
separately before deciding their checking sites; the mechanism name alone does
not imply a pure-source binding. See the
[CFFI overview](https://cffi.readthedocs.io/en/stable/overview.html).

#### 3.2.5 User-facing wrappers: material to develop

Follow the extension or foreign-call declarations into the Python module that
users import. Attribute presence is observable, but wrappers may transform
arguments, results or errors. State the expectation for each example before
choosing a behavioural test. These examples inform §6.3.1; distribution and
environment choices return in §5.2.

## 4. Versions and replacement

The preceding sections held the participants fixed. Now replace a header,
library or binding and ask which earlier claims still hold. A version label
is evidence about identity or policy; it does not contain every requirement of
an artifact. Separate artifact-carried metadata from external naming and
selection facilities.

### 4.1 Artifact-level versions

A soname is a lookup identity, often containing an ABI-generation convention;
it is not a unique implementation identifier. ELF symbol-version requirements
provide an additional matching mechanism. `soname_matches_requirement` and
`required_versions_exported` observe parts of these claims, but equal names and
tags do not establish equivalent implementations.

### 4.2 External version claims

Package constraints, solver choices and installed pins are distinct from the
library's own version evidence. Canary enumerates declared choices and checks
pins; it does not model package-manager solving. A packaging version must not
be assumed to name the native library version (§5).

### 4.3 Replacement and preservation expectations

Compare versions through a stated requirement or preservation policy. A removed
export matters to a consumer that requires it; a changed signature matters to a
binding declaration that still assumes the previous shape. Inspection diffs
can generate candidates, but a difference alone is not a violated agreement.

Header, provider and binding versions can vary independently. The carried
oracle in §3.1.2 must retain its source identity so that a check does not silently
use one version's header to judge another version's library. The detailed
version-pair observations remain to be developed; existing comparisons and
limits are listed in §1.7. Package-manager selection of these versions is the
next section's subject.

## 5. Packaging and provenance

Package managers contribute resource identity (§2.1), selection constraints and
store exclusivity. Canary wraps apt/brew, opam and pip; it also consumes native
prebuilt artifacts such as conda-forge packages. “System” and “language” are
useful roles, not strict ownership categories: opam can provide a native library.


This section revisits the language artifacts through the facilities that supply
them. The manager and language boundaries need not coincide. Different managers
can supply the same artifact, and one manager can supply several kinds.
The detailed per-manager accounts below remain planned beyond existing pins,
gates and project examples.

### 5.1 OCaml packages: opam and installed layout

Starting from §3.1, develop opam package selection, declared dependencies and
native dependency gates, then the installed findlib layout and package pin.
Findlib's role in locating/linking OCaml artifacts was introduced with the
language; this section asks which package supplies that layout and whether
installation satisfies its claims.

Distinguish the package chosen from the artifacts a subsequent consumer uses.
Reuse the artifact descriptions rather than reintroducing OCaml compilation.
The generic gate model is in §5.3; actual lookup and shadowing are in §6.2.

### 5.2 Python distributions and environments

Starting from §3.2, develop distribution metadata, installed package contents
and interpreter environments. Relate a distribution to its modules and native
dependencies without treating installation as proof of import origin.

Canary currently uses pip. Other packaging facilities can extend this account
without changing the Python artifact or foreign-call model. Package presence
and pin checks supply part of the evidence; detailed distribution/module
correspondence checks remain candidates. Actual import selection is in §6.2.

### 5.3 Native providers and constructible pairings

`Canary_binding_decl.pm_dep_gate` and `combination_freedom_of` describe how
packaging constrains an independent provider/binding pairing:

| Gate                                    | Derived freedom  | Meaning                                                    |
| --------------------------------------- | ---------------- | ---------------------------------------------------------- |
| Presence-only conf package              | `Any_version`    | Gate does not constrain the native version                 |
| Range-constrained conf package          | `Within_bound`   | Pairing is allowed within the bound                        |
| Exact/bounded gate requiring adaptation | `Wrapper_needed` | A wrapper is needed to construct the desired pairing       |
| Library built or bundled by the package | `No_pairing`     | That packaging does not expose an independent library axis |

A package query establishes the installed pin; it does not establish what the
runtime loads. Conflicting pins also require separate stores or serialized
worlds. Those scheduling rules belong to [world ordering](../enumeration/stage4_order_worlds.md).

### 5.4 Dependencies across packaging boundaries

| View     | Meaning                                                 | Example evidence                                    |
| -------- | ------------------------------------------------------- | --------------------------------------------------- |
| Declared | Packaging or source says a dependency is needed         | Manifest, pkg-config flags, dependency gate         |
| Recorded | A distributed artifact carries a dependency requirement | Native dynamic metadata, OCaml archive link options |
| Resolved | A concrete lookup selects a resource or definition      | Module origin, loader object/binding trace          |

The distinction repeats along app → helper → binding → native library. A
packaging declaration can be copied into a distributed manifest without becoming
an observation of linking. Each hop may have been built on another machine;
successful resolution there does not establish deployment resolution.

### 5.5 The ncurses counterexample

The recorded experiment paired a Debian-built consumer with conda-forge's
ncurses. Symbol, soname and version checks passed, but the probe segfaulted.
Debian's `libtinfo.so.6` supplies the wide ABI; conda-forge divides narrow and
wide implementations between `libtinfo.so.6` and `libtinfow.so.6`. The consumer's
recorded name therefore selected the wrong implementation, alongside the wide
one brought in transitively.

Every required name could resolve. The fault was a disagreement in what that
name denoted across packaging conventions. Evidence, measurements, reproducer
and remediation remain in the [ncurses report](../../project/report_ncurses_libtinfo.md).

#### 5.5.1 What static evidence can establish

Sonames identify the names the objects advertise. Exports, version namespaces
and debug/header types can reveal differences between their interfaces. None
alone establishes that two objects are alternative realizations of one
implementation, or that a difference is incompatible.

The proposed denotation check needs both worlds' evidence **and** a criterion
for comparing the implementations behind a name. A 2×2 enumeration makes
corresponding worlds available; it does not itself supply that criterion or
retain every build-time dependency of a fetched consumer.

#### 5.5.2 Attribution in the ncurses case

The demonstrated failure concerns the cooperation between packaging conventions.
Version direction alone does not explain it: the same binaries ran after the
name resolution was corrected. That observation supports attribution to the
pairing, without claiming general compatibility between the releases (§7.2).

#### 5.5.3 Discovery is not an identity oracle

The earlier symbol-overlap sweep found candidates for alternative implementations
and containment (a larger object incorporating a smaller one). It also produced
a misleading candidate with a coarser rule. Overlap thresholds are discovery
heuristics, not sufficient grounds for a failure verdict. Two names aliasing
one object can be benign; distinct loaded objects duplicating state may not be.

### 5.6 Dependency agreements

The four stable slugs and statuses are listed once in §1.7. Their distinguishing
questions are: is a recorded name provided (`dependencies_provided`), does it
preserve its denotation across worlds, are prohibited duplicate
implementations loaded, and does a symbol bind to its permitted target?

**Current `dependencies_provided` boundary:** it reads one `Native_lib` summary
and one consumer `Abi_surface`. It compares each direct consumer dependency
with that provider's soname and the family's fixed `ambient_runtime` list.
It does not enumerate all providers, traverse transitive dependencies, verify
the ambient libraries' presence, or run a loader. A dependency supplied by a
second unmodeled library can therefore be reported as unprovided. The ambient
list is currently code, not a per-world policy parameter.

`soname_matches_requirement` asks whether the selected provider's name matches
the consumer requirement; `dependencies_provided` asks about additional names
in the same consumer record. Neither detects
the ncurses denotation fault simply by checking name equality.

The interposition proposal must separate its two parts: a recorder produces
facts without blame; a comparison against an expected build target produces
a verdict. Intentional interposition needs an allowed-target policy.

## 6. Deployment and execution

The intended artifacts have now been described, varied and supplied. This
section asks whether staging preserves the required properties, which resources
are actually selected, and what an execution establishes. These observations
can confirm or contradict the earlier claims.

### 6.1 Staging and relocation

Build → stage → package → fetch/install can change paths, metadata and selected
contents. A preservation check must declare what transformations are allowed.
The detailed design is [staged_parity.md](../staged_parity.md): completeness,
integrity, parity and isolation. Hand-listed staged-file checks and selected
per-world isolation exist; a general implementation is open.

Portability means the staged artifact works under its declared deployment
conditions. A build-tree path is suspicious when execution depends on it;
its mere presence in debug information is not a relocation failure. Data-file
lookup also matters, as the ncurses terminfo case demonstrates.

### 6.2 Resolution and selection

Resolution asks which candidate was selected under a mechanism and environment.
Presence, recorded identity and required exports are inputs to that question.
The general resolution checker remains proposed.

| Lookup                     | Evidence to retain                              | Candidate falsifier                                       |
| -------------------------- | ----------------------------------------------- | --------------------------------------------------------- |
| Compiler / build discovery | Selected headers, pkg-config result, tool paths | Build used inputs outside the declared world              |
| Linker                     | Selected objects and recorded link options      | Consumer linked against an unintended provider            |
| Native loader              | Resolved objects and symbol bindings            | Runtime selected an unintended object or definition       |
| OCaml / Python lookup      | Actual package/module origin                    | An ambient or stale package shadowed the intended binding |

Search paths, embedded paths and precedence vary by platform. The parked path
inventory is consolidated here: tool lookup (`PATH`), build discovery
(pkg-config/CMake paths), language lookup (OCaml/Python paths), and native loader
lookup (ELF RPATH/RUNPATH or Mach-O install names and rpaths). Incorporate the
user's existing path study before designing detailed resolution cells.

#### 6.2.1 Further dependency evidence

Transitive dependencies, dynamic plugins, weak/default symbol selection and
interposition require evidence beyond one object's export set. Static records
can expose part of this structure; runtime recording supplies the resolved view.
General resolution and the remaining identity checks are still proposed.

### 6.3 Behavioural expectations and observations

The language examples introduce wrappers and their user-facing APIs.
Here their explicit behavioural expectations determine what execution can check.
This is not an assumption that all bindings implement the same repacking
relation.

#### 6.3.1 User API and repacking

The language discussion introduces the user-facing API and checks such as name
presence. Repacking asks a harder question: what relationship should hold
between native operations, foreign-call wrappers and the API offered to users?
A wrapper may rename, combine, restrict or extend operations. Its correctness
cannot generally be stated as equality of names or signatures.

The material should first describe those transformations in the OCaml and
Python examples, then identify project-supplied behavioural expectations and
possible observations. `repack_preserves_api` is the preservation agreement;
`repack_complete` composes it with `signatures_agree` and
`required_symbols_exported`. The composition function exists; neither
agreement has a registered evaluator, so both report `not_implemented` with
their reason wherever they are selected.
“Loses nothing” needs an explicit scope, since a binding may intentionally
expose only part of a provider. A general repacking relation remains open;
concrete tests can still check particular expectations.

Both names are PROVISIONAL, and deliberately so: "preserves" and "loses
nothing" have no agreed scope, since a binding may intentionally expose only
part of a provider. Settling the claim precedes naming it and precedes
presenting it as a general implemented property. The open implementation
decisions are in §7.4.

#### 6.3.2 Behavioural observations

Behavioural checks cover the residue left by structural observations: returned
values, errors, callbacks, repeated execution and wrapper behaviour. Ordinary
probes already assert behaviour; `behavior_matches` and `repack_preserves_api`
have no registered evaluator and report `not_implemented`.

Prefer earlier evidence when it can refute the same claim. Keep runtime checks
where necessary, and state their input and execution coverage. Translated and
differential tests are candidate evidence sources (§1.8), not proof that the
entire binding preserves native behaviour.

#### 6.3.3 Instrumentation

A fake provider can exercise consumer robustness against declared requirements;
failure can implicate the consumer, the declaration or the fake's fidelity.
A recorder only reports requests and resolutions. Attribution begins when a
check compares that record against a claim.

## 7. Registry integration and coverage

The component discussions identify useful claims and observations. The registry
connects those observations to actions over concrete worlds. This section
separates the intended interface, current execution and remaining coverage.

### 7.1 From action context to checking methods

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
remaining consumers is §7.4.2 item 1.

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

#### 7.1.1 The round trip: what a real run actually checked

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
inside `make canary-post-check`. [`pipeline.md`](pipeline.md) walks the seven
points a run passes through and what each undecided outcome means — since
2026-09-15 the outcome WORD carries that (`unavailable` / `undeclared` /
`vacuous`) rather than a reason string a reader had to interpret;
[`landing.md`](landing.md) tracks which agreements have made it.

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

### 7.2 Result interpretation and attribution

#### 7.2.1 Evidence coverage must accompany a result

The pass meanings are in §1.5; the eight outcomes that carry them are in
§1.2.1. This was a design requirement and is now the result type: a method's
evaluation returns one outcome, and a step logs every selected method's
outcome, so its record says which checks ran, which found nothing, which had no
evidence, and which are not implemented. One record supplies both that report
and the step's acceptance (§7.1), so a run's pass/fail and its agreement
coverage are no longer two independent derivations.

What this does **not** yet establish. A malformed inspection now raises and
becomes an `error` outcome for the method that read it, rather than being
swallowed into "no watchlist" — but the loaders still emit kind-mismatch
warnings to stderr and continue, so a diagnostic on the way to a `holds` is not
yet part of the record. The GH backend renders none of this. And a warm step
reports nothing at all, by construction.

#### 7.2.2 Attribution needs a trusted claim

A declaration mismatch identifies a disagreement between artifact and declaration.
Use the authority stated in §1.6 before blaming either. For a versioned pair,
Forward/Backward direction describes which side is newer and can help explain
a missing requirement. It does not by itself establish a violated promise or
exclude a packaging/environment fault. Packaging disagreements may implicate
the cooperation, as in §5.5.2.

### 7.3 From candidate to check

For a candidate generated from a diff, manifest or failure:

1. Name the claim, its authority and a concrete falsifier.
2. Identify the input artifacts, their provenance and the earliest observation site.
3. Specify the relation and its applicability, including allowed transformations.
4. Build a minimal counterexample and a corresponding non-failing case.
5. Add the family implementation and registry row, or record a proposal with
   the missing evidence. Verify its effect in a representative world.

A heuristic sweep generates candidates. It must not silently become the oracle
that judges them. Keep project measurements and remediation in project reports.

### 7.4 Implementation gaps and decisions

The immediate goal is a **traceable working subset**, not implementation of
every proposed agreement. The doc should describe each existing check accurately
enough to follow it from a claim through its inputs and comparator to an actual
action result. A proposal can remain open without weakening that account.

For a check to be described as integrated, show its action caller, the evidence
produced in that world, a failing example and a corresponding non-failing
example. Comparator fixtures establish the comparison; an action-level test
establishes the connection. Neither replaces the other.

#### 7.4.1 Where each agreement stands

Per agreement, per method, in the OCaml compiled-stub context unless noted.
"Comparison" is whether an evaluator exists; "evidence" whether an action
produces what it reads; "integrated" whether the context path reaches it with
that evidence; "counterexample" whether a fixture falsifies it hermetically.

| Agreement                    | Comparison | Evidence                                     | Integrated                                              | Counterexample                       | Remaining limitation                                                                           |
| ---------------------------- | ---------- | -------------------------------------------- | ------------------------------------------------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------- |
| `required_symbols_exported`  | yes        | yes                                          | **yes, verified**                                       | yes (violated, holds, unavailable)   | set inclusion only; says nothing about signatures, versions or which definition binds          |
| `api_names_present` | yes | yes | **yes — `holds` on a real sqlite run (OCaml), falsified to `violated`** | yes (OCaml, Python, empty watchlist) | coverage bounded by the watchlist; Python evidence requires importing the module. sqlite's Python surface is still inspected at the probe step, where the derivation does not look, so that half stays `unavailable` |
| `signatures_agree`           | yes        | only where source scanning ran               | selected; reports `unavailable` otherwise               | yes (violated, holds)                | textual spellings, not type equivalence; binding signatures partly supplied from a fixed table |
| `declared_symbols_exported`  | yes        | no — no action supplies the declaration      | selected; reports `unavailable`                         | yes (violated, unavailable)          | needs a declaration input on the `build_lib` step                                              |
| `soname_matches_declaration` | yes        | no — same                                    | selected; reports `unavailable`                         | yes (violated, unavailable)          | same; and a matching name does not identify an implementation                                  |
| `declared_versions_exported` | yes        | no — same                                    | selected; reports `unavailable`                         | yes (violated, unavailable)          | same                                                                                           |
| `soname_matches_requirement` | yes        | only where the consumer records dependencies | selected; `not_applicable` under compiled-stub archives | yes (violated)                       | name equality; does not establish what the loader selects                                      |
| `required_versions_exported` | yes        | same                                         | same                                                    | yes (violated, holds, inconclusive)  | exact tag match, direct requirements only                                                      |
| `dependencies_provided`      | yes        | same                                         | same                                                    | yes (the ncurses shape)              | one modeled provider, direct dependencies, ambient list is code not policy (§5.6)              |
| `behavior_matches`           | no         | —                                            | selected; reports `not_implemented`                     | —                                    | expectations live inside probe sources; nothing to read                                        |
| `repack_preserves_api`       | no         | —                                            | selected; reports `not_implemented`                     | —                                    | the relation is unspecified (§6.3.1)                                                           |
| `repack_complete`            | no         | —                                            | selected; reports `not_implemented`                     | —                                    | claim scope unsettled; composes two unevaluated agreements                                     |

The ordering below now has a precondition that §7.1.1 supplies: an item is
done when a real project's log shows the agreement decided, not when its
comparator passes a fixture. Take them one at a time, and read the log after
each.

#### 7.4.2 Ordered backlog

1. **Land the remaining methods on a real project, one at a time.**
   `api_names_present` is done for OCaml (§7.1.1). The next three, in the
   order their evidence is cheapest to produce:

   - **`api_names_present` for Python.** sqlite's Python surface is inspected
     at the probe step and the derivation looks at the binding's install step.
     Python's sqlite3 is stdlib, so there is no install step to attach it to —
     which means either the derivation learns that an ambient binding is
     inspected where it is used, or such a binding declares a step. Decide
     that before moving the call.
   - **`required_symbols_exported`.** Needs two inspections sqlite does not
     produce: a compiled-stub summary of the opam binding
     (`stub_inspect_opam_pkg_cmd` exists and `auto_binding_summaries` would
     emit it from `binding_user_facing_pkg`) and a native summary of the
     built library. Both are one wiring change each; the agreement's
     comparator needs nothing.
   - **`signatures_agree`.** Needs the source-scanning inspectors to run,
     which sqlite does not wire at all.

   Then migrate the compat expectations off the declared-input route for the
   projects whose layout the derivation already reproduces, keeping LLVM's
   packed-binding case explicit until the publication step is declarable. The
   merge makes that incremental: a derived and a declared evaluation of the
   same method collapse into one entry, so a project can move one expectation
   at a time.
2. **Improve signature extraction.** Replace the fixed binding-signature table
   with a real extractor, so `signatures_agree` compares what the binding
   declares rather than what the inspector was told to assume. Decide what the
   arity helper is for once the extractor exists.
3. **Connect the declaration-based agreements.** Route `Declared_exports`,
   `Declared_soname` and `Declared_version_tags` from the project's artifact
   declaration into the `build_lib` step's evidence. All three comparators and
   their counterexamples are ready; they report `unavailable` until this lands,
   which is the honest state and not a substitute for it.
4. **Introduce one test-suite reuse case**, then **one C/binding differential
   case.** §1.8 describes the candidate sources; the point of doing them in
   that order is that a reused upstream suite supplies an expectation, while a
   differential case supplies a comparison, and `behavior_matches` needs both
   before it can have an evaluator.
5. **Extend to dynamic bindings, dependency policies and repacking.** Each
   needs a decision before code: which artifacts a ctypes or CFFI binding can
   actually supply; how `dependencies_provided` enumerates providers and takes
   an ambient policy per world rather than from a constant; and what the
   repacking claim permits. Specify each before implementing it; do not label
   one working because a comparator or constructor exists.

Cross-cutting, and deliberately not numbered above because it is a property of
the evaluation rather than of any agreement: the GH backend still renders
neither the outcomes nor the closures (§7.1's backend boundary), and it decides
a derived step's polarity with its own "did every input resolve" flag rather
than from outcomes. That flag answers a narrower question than the record does
— *did the evidence I named exist* — so replacing it means giving the renderer
`sv_inputs`, not just swapping the predicate.

The unresolved scope decisions remain: what the repacking claims permit; how
`dependencies_provided` obtains all intended providers and an explicit ambient
policy; what establishes denotation or containment across worlds; and which
artifacts each additional mechanism can actually supply.

#### 7.4.3 Finish `mechanism_info`, and stop defaulting the language map

Two to-dos from a survey of every site that consults a `mechanism`
(2026-09-14, user: "let's also do a collection on other code which needs
checking on `mechanism` and think about if they can also benefit"). Both
were found by looking rather than predicted, and the first is half-built
already.

**(a) The record exists; the facts are elsewhere.**
`base/canary_mechanism.ml` already defines `mechanism_info`, a five-entry
catalogue covering every mechanism, a total `info_of_mechanism`, and pins for
totality and discipline-consistency. Its own header says the intent outright:
*"Making each one a structured record turns the design space into data canary
can range over."* But the record carries `mi_lang`, `mi_discipline`,
`mi_lib_coupling` (prose), `mi_check_points` (prose) and `mi_wired` — none of
the facts anything dispatches on. Those live as loose constants in
`canary_agreement_cstubs.ml`, which is why only cstubs has them and why the
families approximate the table with one bit (`is_dynamic`).

So the move is not tag → record. It is **finish the record**: add the
decidable fields — does this mechanism compile a stub archive, does its
consumer artifact record `NEEDED` and symbol versions, does it expose typed
stub declarations — and point the predicates at `info_of_mechanism`.

**Who benefits, measured rather than assumed.** ~110 sites mention a
mechanism; ~90 of them only NAME one (project specs, test worlds) and
dispatch on nothing.

| group | sites | benefit |
| --- | --- | --- |
| agreement layer (`is_dynamic`, `consumer_records_needed`) | 5 files | **direct** — each becomes a field lookup, and a new mechanism is a catalogue row rather than edits in four families |
| enumeration (`Build_binding` stage exists?) | `canary_enumerate.ml` ×2 | **none** — `discipline` already answers it, and that is what discipline is for |
| coverage (`is_static_binding_lang`) | 1 | **none**, same reason |
| specs and tests naming a mechanism | ~90 | inert |

The point of the table is the second and third rows: "everywhere that touches
`mechanism`" looks like 25 files and is really 5. Folding the enumeration in
would be churn.

**(b) `default_mechanism_of_lang` returns an option nobody wants.** All nine
call sites — the bin, the step builder, the registry, the matrix (×3), the
pipeline, tiny — immediately write `Option.value ~default:Cstubs`. A Rust or
Java binding would therefore be treated silently as OCaml cstubs rather than
refused or reported. Same class as the `merge_inspect` proxy that made
`Inspect_native_build` unusable for a year: a defaulting rule restated at
every call site instead of being decided once. Independent of (a) and
cheaper — one total answer, or a deliberate error.

#### 7.4.4 The action-unit perspective — LANDED, and what is left

Raised 2026-09-13 as deferred. Answered 2026-09-14/15. Kept rather than
deleted because the *reasoning* about why it looked blocked is worth having
when the remaining piece comes up.

**The question was:** `canary result`'s column headers are a list of actions.
Could the same header row carry a discussion of agreements *between* actions?

**It does now.** The table interleaves check columns with action columns in
the order `pre → action → artifact → post`:

```
| build_lib | build_lib=lib | build_lib_post:dse | build_lib_post:dve | install_lib | … |
```

One agreement per cell, a short code as the column's only name, columns
grouped per action with a rule down the left edge, and an always-visible key
mapping code → agreement. A cell is that agreement's outcome at that slot;
`✓`/`✗` are verdicts and everything else is a word (`no-evid`, `no-ref`,
`stale`, `none`, `no-decl`) with a counted **blame** underneath.

**All three stated blockers are gone:**

| the 2026-09-13 claim | today |
| --- | --- |
| "nothing records where an agreement is **rooted**" | `ag_rooted_in` is a `rooting` record; `rt_action` must parse as an action, pinned by `agreements.rooting_names_an_action` |
| "`ag_rooted_in` is prose, not an action reference" | it is both — `rt_action` is the reference, `rt_note` the prose |
| "`compare_column` lives in `main/`, the firing table in `agreement/` below it" | `compare_column` moved to `base/canary_basic.ml`; `main/` aliases it |

**What is actually left**, and it is the part that was right all along: *an
edge is not a set of cells*. The table gives each agreement one column at one
slot, chosen by `ag_slot`. An agreement whose rule spans two actions still
renders as one cell plus a `recovers` column in the key — which reads, but
does not draw the relation. An agreement with two roots has nowhere to say
which pair is one relation.

Two known consequences, both filed in
[`../../project/issues.md`](../../project/issues.md) §1:

- a column can exist that no world can fill (llvm's `install_lib_post:sip` —
  the slot resolves against the chain, the firing never does);
- a verdict can be invisible (zarith's `dependencies_provided` holds in a
  world whose chain lacks the action its slot chose).

Both are the same shape: the column set is derived once per project from
`covered_actions_of`, while each cell re-resolves its slot against its own
row's chain. That is the remaining model question, not the rendering one.

### 7.5 Outside current coverage

Representation and marshalling correctness, lifetime/ownership, GC rooting and
callback safety are not established by the current checks. Richer
instrumentation and declarations would be needed. Rust FFI, JNI, P/Invoke and
PE/COFF are additional unimplemented instantiations. A new language or format
may require new evidence and applicability rules, not merely another name.

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

The first is the production path (§7.1). The second is the project-supplied
input path the compat expectations use, and it deliberately skips
applicability. The third selects without evaluating, for the checking index.
`inputs_of_agreement` remains the explicit per-name lookup.

### A.2 Derived views and their limits

```ocaml
Canary_agreement.pp_agreements ()
Canary_agreement.pp_catalogue ()
Canary_agreement.pp_firing_table ?mechanism ?lang ?provision ()
Canary_agreement.fill_list ?mechanism ?lang ?provision ()
```

`canary checks` prints the first, `canary checks --catalogue` the second and
`canary checks --firing` the third. The catalogue is the generated form of
§1.7: every agreement with its reference expectation and each method's kind,
reference, implementation status, firing sites and scope limits.

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
partially applied closure in a fixture. No action supplies one yet (§7.4.2
item 3), which is why those agreements report `unavailable` rather than
holding vacuously.

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

## Appendix C. Coverage goal

### C.1 Goal and status ownership

The target is a defined result for each applicable agreement/action/world,
supported by evidence and counterexamples. Since 2026-09-12 every selected
method DOES produce a defined result — that is what the outcome type is for
(§1.2.1) — so what is left of the goal is the quality of those results: how
many are `holds` or `violated` rather than `unavailable` or
`not_implemented`, and whether a `holds` rests on evidence a real action
produced. Total firing functions and total outcomes are two parts of that
target; the limitations in §7.2.1 and Appendix A still matter, and §7.4.1
records where each agreement stands.

Current priorities belong to [status](../../status.md), the
[project tracker](../../project/status_project.md) and
[project issues](../../project/issues.md). This document keeps the checking model
and the unresolved decisions in §7.4, rather than another chronological plan.
