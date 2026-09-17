# The agreement model — what a claim IS, and how a run reaches a verdict

**Kind: reference.** The model: what an agreement is, what separates a
claim from the methods that check it, what an evaluation can return, and
how a running step gets from its own action to a set of outcomes.

> Split out of `registry.md` on 2026-09-17, which was 1,376 lines and
> two documents. The per-component walk — and every `ag_doc` anchor the
> code carries — is [`components.md`](components.md); this half is the
> model and the integration.

**One rule governs this directory, and it is the one the split
enforced:** a table the tool generates does not get a hand copy. Three
such copies existed, and all three had gone stale — `registry.md` §1.7,
`registry.md` §7.4.1 and `landing.md`'s effective table each still said
`declared_symbols_exported` reports `unavailable` for want of a
declaration, months after it began deciding on sqlite and catching a
real forward-cell violation. Read the live ones:

```sh
canary checks --catalogue        # what every agreement IS      (= catalogue.md)
canary checks --landing          # planned vs effective          (= landing.md's subject)
canary checks <p>                # one project's coverage, per action
canary checks <p> --observed     # what its LAST run decided
canary checks --agreement NAME   # one agreement, complete
```

## Where else to look

| you want | read |
| --- | --- |
| why there is anything to check at all | [`theory.md`](theory.md) |
| what could be claimed about a kind of thing | [`components.md`](components.md) |
| what one agreement IS | [`catalogue.md`](catalogue.md) (generated) |
| landing one on a project | [`landing.md`](landing.md) |
| what has actually been decided | [`landing.md`](landing.md) |
| **when** a check fires | [`../enumeration/stage6_realize_steps.md`](../enumeration/stage6_realize_steps.md) §2b — the occasion is not this directory's |

## 1. The agreement model

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
[`catalogue.md`](catalogue.md), generated by `make agreement-catalogue`
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

Whichever frame produced it, the promotion workflow is §2.3.

## 2. Registry integration — from a step to an outcome

The component discussions identify useful claims and observations. The registry
connects those observations to actions over concrete worlds. This section
separates the intended interface, current execution and remaining coverage.

### 2.1 From action context to checking methods

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

#### 2.1.1 The round trip: what a real run actually checked

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
inside `make canary-post-check`. [`landing.md`](landing.md) walks the eight
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

### 2.2 Result interpretation and attribution

#### 2.2.1 Evidence coverage must accompany a result

The pass meanings are in §1.5; the eight outcomes that carry them are in
§1.2.1. This was a design requirement and is now the result type: a method's
evaluation returns one outcome, and a step logs every selected method's
outcome, so its record says which checks ran, which found nothing, which had no
evidence, and which are not implemented. One record supplies both that report
and the step's acceptance (§2.1), so a run's pass/fail and its agreement
coverage are no longer two independent derivations.

What this does **not** yet establish. A malformed inspection now raises and
becomes an `error` outcome for the method that read it, rather than being
swallowed into "no watchlist" — but the loaders still emit kind-mismatch
warnings to stderr and continue, so a diagnostic on the way to a `holds` is not
yet part of the record. The GH backend renders none of this. And a warm step
reports nothing at all, by construction.

#### 2.2.2 Attribution needs a trusted claim

A declaration mismatch identifies a disagreement between artifact and declaration.
Use the authority stated in §1.6 before blaming either. For a versioned pair,
Forward/Backward direction describes which side is newer and can help explain
a missing requirement. It does not by itself establish a violated promise or
exclude a packaging/environment fault. Packaging disagreements may implicate
the cooperation, as in [`components.md`](components.md) §5.5.2.

### 2.3 From candidate to check

For a candidate generated from a diff, manifest or failure:

1. Name the claim, its authority and a concrete falsifier.
2. Identify the input artifacts, their provenance and the earliest observation site.
3. Specify the relation and its applicability, including allowed transformations.
4. Build a minimal counterexample and a corresponding non-failing case.
5. Add the family implementation and registry row, or record a proposal with
   the missing evidence. Verify its effect in a representative world.

A heuristic sweep generates candidates. It must not silently become the oracle
that judges them. Keep project measurements and remediation in project reports.

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

The first is the production path (§2.1). The second is the project-supplied
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
PLACE:** *Out of the table* in [`catalogue.md`](catalogue.md), or
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

