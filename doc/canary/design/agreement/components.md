# The components — why each agreement exists

**Kind: reference.** A walk over the five kinds of thing a binding world
is made of, saying for each what could be claimed about it, what
observation is available, and what that observation does not establish.

It is **where an agreement's rationale lives**: every registry row
carries a `ag_doc` anchor (`§2.2`, `§3.1.1`, …) and it points here. The
section numbering is therefore load-bearing —
`agreements.doc_anchors_exist` fails if a cited section stops existing.

> Split out of `registry.md` on 2026-09-17. That file was 1,376 lines and
> two documents: the agreement MODEL (now [`agreements.md`](agreements.md) §1)
> and this walk. Its title was a paper title, it had no `Kind:` line, and
> CLAUDE.md routed "writing the paper" at these sections specifically.
> The numbering is unchanged across the split, so every anchor in the
> code still resolves.

## What this is not

- **It is not the catalogue.** What each agreement IS — its claim,
  whose rule it recovers, its methods, limits and worked examples — is
  [`agreements.md`](agreements.md), generated from the code. Nothing here
  restates it, because the two hand-maintained copies that used to
  (the retired `registry.md`'s §1.7 and §7.4.1) had both gone stale: they still said
  `declared_symbols_exported` reports `unavailable` for want of a
  declaration, months after it began deciding on sqlite and catching a
  real forward-cell violation.
- **It is not the procedure for finding the next agreement.** That is
  [`theory.md`](theory.md) §6, which walks ACTIONS — where a relation
  was established and what survived it. This walks COMPONENTS — what
  kind of thing is in front of you. The two are complementary axes over
  one space; a candidate found on either should be checked against the
  other.

## How to read a section

Each discussion states the intended claim independently of
implementation status, then the available observation and its limits.
Sections expand the checking context; they are not an execution
sequence.

| § | question and material |
| --- | --- |
| [§2](#2-common-artifact-foundation) | presence, identity, declared exports and recorded dependencies of the native provider |
| [§3](#3-language-bindings) | OCaml artifacts and concrete checks per mechanism; Python in the same order |
| [§4](#4-versions-and-replacement) | what changes when a header, library or binding is replaced |
| [§5](#5-packaging-and-provenance) | how those artifacts are selected and supplied |
| [§6](#6-deployment-and-execution) | what is staged, selected, loaded and exercised |

Each language's mechanisms stay together. Packaging reuses that
language's artifact vocabulary and adds external selection and
installation claims. A new language adds a subsection; a new mechanism
extends it; a new package manager extends the packaging discussion
without redefining language features. §2 gives the recurring authoring
questions.

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
a peer comparison.

**They are supplied, since 2026-09-13.** `Canary_pipeline.with_declared_facts`
routes a project's `api_source` into the runner spec; before it, every project
ran with `api_source = None`, the declaration reached only `spec-check` and the
CI renderer, and all three of these reported `unavailable` by construction.
`declared_symbols_exported` and `soname_matches_declaration` decide on sqlite
today, and the first one's violation is the project's own forward cell — a
stable-channel build at 3.43.2 missing `sqlite3_get_clientdata`, not a synthetic
break. `declared_versions_exported` is still `vacuous` there, and that is the
truth rather than a gap: sqlite builds without a version script, so there are no
version nodes to read.

A tool's exit status and output presence are additional
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
checks, with each method's limits generated into [`agreements.md`](agreements.md).

| Agreement                   | Exact comparison                                                                    | Evidence needed                           |
| --------------------------- | ----------------------------------------------------------------------------------- | ----------------------------------------- |
| `required_symbols_exported` | Required symbols minus exported symbols; a nonempty difference is a finding         | Inspected stub archive and native library |
| `signatures_agree`          | Compare return-type strings and argument-type lists for names present on both sides | Header and binding signature summaries    |

`required_symbols_exported` in this context is the completed production path:
[`agreements.md`](agreements.md) §4.9.1 records what runs; [`../../backlog.md`](../../backlog.md) §51 what is left.

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
`not_applicable`. Their evidence routing is tracked in [`../../backlog.md`](../../backlog.md) §51,
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

**Three layers, and canary's agreements live at one.** The layers do not
agree across object formats, and the differences are not cosmetic:

| layer | ELF | Mach-O | who enforces it | canary |
| --- | --- | --- | --- | --- |
| package | `libfoo1 (= 1.2.3-4)` | `foo 1.2.3` | the solver, at install | a version point; `pin_check_post` verifies the store |
| library identity | `SONAME libfoo.so.1` | `install_name` **+ `compatibility_version`** | the loader, at load | `soname_matches_*` — ELF-shaped |
| symbol | version nodes (`GLIBC_2.2.5`) | **none** | the loader, per symbol | `*_versions_exported` — ELF-only by construction |

Three asymmetries follow, each an open decision
([`../directions.md`](../directions.md) §3):

- **Mach-O carries a version FLOOR that ELF does not.**
  `compatibility_version` is a number dyld compares and refuses on; ELF's
  floor is per-symbol instead. The same claim exists on both platforms at
  DIFFERENT RESOLUTIONS, which is a statement about what a surface theory
  must be parametric in. `inspect_native.py` already extracts both
  `compatibility_version` and `current_version`, and no agreement reads
  either — written evidence with no reader.
- **`install_name` is a PATH, not a name.** A name comparison needs a
  basename normalisation on Mach-O that ELF never required, and doing it
  silently would hide a dylib whose recorded path points where it is not.
- **A package version never names the library version.** §4.2 states it;
  the conf survey measures it — only 13 of 370 `conf-*` packages carry a
  real version bound.

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
limits are generated into [`agreements.md`](agreements.md). The ordered
plan for the next three is [`../directions.md`](../directions.md) §3. Package-manager selection of these versions is the
next section's subject.

## 5. Packaging and provenance

> **The `conf-*` hop is the unclaimed part of this section**
> (2026-09-17). A `conf-<lib>` package converts *"needs library L"* into
> *"needs system package P"*, and the conversion is lossy in a NAMED
> way: it drops the version found and the ability to choose. Each
> dropped thing is an agreement candidate at distance 0 or 1 —
> especially *the object the discovery mechanism accepted is the object
> the link resolved*, since `pkg-config` answers at solve time, the
> linker at build time and the loader at run time, and nothing checks
> that the three agreed. The ncurses report is one instance of exactly
> that. Explored in [`../directions.md`](../directions.md) §1; measured
> in [`../../surveys/conf_packages.md`](../../surveys/conf_packages.md) §H.

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
worlds. Those scheduling rules belong to [world ordering](../enumeration/stage5_order_worlds.md).

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
pairing, without claiming general compatibility between the releases ([`agreements.md`](agreements.md) §4.9.3).

#### 5.5.3 Discovery is not an identity oracle

The earlier symbol-overlap sweep found candidates for alternative implementations
and containment (a larger object incorporating a smaller one). It also produced
a misleading candidate with a coarser rule. Overlap thresholds are discovery
heuristics, not sufficient grounds for a failure verdict. Two names aliasing
one object can be benign; distinct loaded objects duplicating state may not be.

### 5.6 Dependency agreements

The four stable slugs and statuses are generated into [`agreements.md`](agreements.md). Their distinguishing
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
decisions are in [`../../backlog.md`](../../backlog.md) §51.

#### 6.3.2 Behavioural observations

Behavioural checks cover the residue left by structural observations: returned
values, errors, callbacks, repeated execution and wrapper behaviour. Ordinary
probes already assert behaviour; `behavior_matches` and `repack_preserves_api`
have no registered evaluator and report `not_implemented`.

**CORRESPONDENCE is a separate claim, and it has an oracle the others do
not** (2026-09-17; the plan is [`../directions.md`](../directions.md)
§2). Running one operation through the C API and through the binding on
the same inputs and comparing the results needs NO project-supplied
expectation: the C side is the expectation, and canary is unusual in
building both in one world. What it recovers is a real projection loss —
the C compiler established that the stub's TYPES agree with the header
and not that the arguments are in the right ORDER, so a stub binding
`tiny_sum(a, b)` to `sum b a` compiles, links, and satisfies every
structural agreement in the catalogue.

That is why it should be its own agreement rather than an evaluator for
`behavior_matches`: the two differ in their oracle, and merging a claim
that HAS one with a claim that does not would repeat the solo/pair
mistake.

⚠ **Argument order is not the fault to look for.** The correspondence is
DEFINED BY the declared mapping, so a binding that binds `tiny_sum(a,b)`
to `sum b a` is a different binding, not a wrong one. The right reading
is the opposite and it is stronger: because a positional convention
holds, the cases are GENERATABLE — pair by name, feed the same arguments
in the same order, compare. What the test catches is everything above
the types: conversions at the boundary, error and exception mapping,
ownership, and state (`push`/`pop`, whose interesting cases are
SEQUENCES rather than calls).

Prefer earlier evidence when it can refute the same claim. Keep runtime checks
where necessary, and state their input and execution coverage. Translated and
differential tests are candidate evidence sources ([`agreements.md`](agreements.md) §1.8), not proof that the
entire binding preserves native behaviour.

#### 6.3.3 Instrumentation

A fake provider can exercise consumer robustness against declared requirements;
failure can implicate the consumer, the declaration or the fake's fidelity.
A recorder only reports requests and resolutions. Attribution begins when a
check compares that record against a claim.


## 7. Outside this walk

Representation and marshalling correctness, lifetime/ownership, GC
rooting and callback safety are not established by the current checks.
Richer instrumentation and declarations would be needed. Rust FFI, JNI,
P/Invoke and PE/COFF are additional unimplemented instantiations. A new
language or format may require new evidence and applicability rules, not
merely another name.

What the frame ITSELF does not cover — set properties, cross-world
properties — is [`theory.md`](theory.md) §7, and it is a different
question: this section lists things not yet done, that one lists things
the model cannot express.
