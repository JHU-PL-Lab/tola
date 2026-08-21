# Tool-Grounded Agreement Catalogue for Cross-Language Binding Checks

## Status and Purpose

This document is an intermediate design note for consolidating the checking logic scattered across the cross-language binding project.

The project already enumerates many possible **provider × binding × consumer worlds**, including different provider provisions, binding implementations, direct applications, and applications using an additional wrapper layer. Those worlds then exercise ordinary lifecycle actions such as fetch, build, publish, fetch-from-package, install/stage, and use/probe.

The purpose of this document is narrower:

> **Systematically catalogue the agreements that can be checked around those actions, and define the principles by which those agreements are observed.**

This document is therefore about the **checking model**, not the enumeration engine and not the cache implementation.

The existing project already has a contract registry, firing rules, fixtures, and an action-centred belief matrix. The current registry is intended to make the checking belief explicit and printable rather than leaving it scattered across project-specific tables and helper code.

The work here sits one level above that implementation. Its goal is to establish a more systematic catalogue from which concrete registry rows can later be derived.

**Merged 2026-08-21.** This is now the single doc: the former
`contract_registry.md` was folded in and deleted. Its material landed in
three places — the confirmed sections below absorbed what belongs to
them (§0.3/§0.4 falsification and the ladder, §1 the implemented
presence/identification instances, §2.1 the surface-role table);
the **implemented module** moved to Appendices A–C; and catalogue
drafts whose home is a section still under review wait in **Appendix
D**, tagged with their intended destination. Nothing was inserted into
an unconfirmed section — the outline stays the review spine.

---

# Progress Outline

* [x] **0. Scope and checking philosophy**
* [x] **1. Resource presence and identification**
* [ ] **2. Artifact surfaces and surface correspondence**

  * [x] 2.1 Syntactic versus realized/semantical surface
  * [ ] 2.2 Surface projections
  * [ ] 2.3 Provider-side surface chain
  * [ ] 2.4 OCaml C-stub surface chain
  * [ ] 2.5 Python C-extension surface chain
  * [ ] 2.6 Python ctypes surface chain
  * [ ] 2.7 Cross-surface agreements
  * [ ] 2.8 Static observation and later dynamic confirmation
* [ ] **3. Representation and marshalling agreements**
* [ ] **4. Lifetime and ownership agreements**
* [ ] **5. Resolution agreements**
* [ ] **6. Dependency-closure agreements**
* [ ] **7. Transformation and packaging preservation**
* [ ] **8. Behavioral agreements**
* [ ] **9. Project- and version-derived agreement discovery**
* [ ] **10. Blame and result interpretation**
* [ ] **11. Mapping the catalogue back to actions and the registry**

Current discussion should resume from **§2: Artifact surfaces**.

---

# 0. Scope and Checking Philosophy

## 0.1 Current binding mechanisms in scope

For now, the catalogue only needs to support three concrete binding mechanisms:

### OCaml through C stubs

```text
C provider
→ C header
→ OCaml C stub source
→ compiled stub artifacts
→ OCaml implementation/interface
→ compiled OCaml artifacts
→ OCaml consumer
```

### Python through a CPython C extension

```text
C provider
→ C header
→ extension C source
→ compiled extension module
→ Python package/module
→ Python consumer
```

### Python through ctypes

```text
C provider
→ C header
→ ctypes declarations
→ Python module
→ Python consumer
```

Other mechanisms such as Rust FFI, JNI, P/Invoke, CFFI, and OCaml Dynlink may be added later, but they should not complicate the current design.

---

## 0.2 Tool-grounded rather than fully formal

The checking model does not attempt to formalize the complete semantics of the compiler, linker, loader, package manager, or language runtime.

Instead, the project treats these systems as externally observable mechanisms and consumes results that developers can inspect directly.

Typical evidence includes:

```text
source inspection
binary inspection
compiler success/failure
linker success/failure
language compiler metadata
package-manager queries
loader behavior
import/load behavior
runtime output
```

The general principle is:

> Prefer an observable tool result over reconstructing the full semantics of the tool that produced it.

For example, a compiler is not modeled operationally. If the relevant question is whether a generated stub conforms to a header, the compiler's result can serve as one confirmation of that agreement.

Likewise, the existing design already follows the principle that successful execution of a tool is insufficient by itself when the produced artifact can be inspected. The product should be inspected and compared with the declared expectation.

---

## 0.3 Agreements are falsifiable observations

The checking system should remain explicitly falsification-oriented.

A successful check means:

> no counterexample was found using this observation.

It does not imply complete compatibility.

The existing registry already adopts this stance: a symbol check can falsify compatibility when a required symbol is missing, while successful symbol inspection cannot prove that no other runtime requirement exists.

This principle should remain global across the expanded catalogue.

Three consequences carried over from the registry design:

* **Phrase each claim as its falsifier.** An agreement's one-line
  statement should name what a counterexample looks like — "every
  symbol the binding declares is exported by the lib", not "the binding
  needs exactly the lib's symbols". The row text is then directly
  testable.
* **The declared watchlists are the falsifier's ammunition.** What a
  check can catch is bounded by what the project declared
  (`c_api.functions`, the surface watchlists): a richer declaration is
  a stronger disprover, and an empty one silently checks nothing.
* **Instrumentation narrows blindness without creating proof.** An
  interposition recorder can show what a consumer actually requested in
  a given run; requests beyond the declaration are counterexamples, but
  "nothing beyond" holds only for the runs observed.

---

## 0.4 Earliest observation, later confirmation

An agreement may be observable at several stages.

For example:

```text
header declaration
      ↓
binary inspection
      ↓
link
      ↓
load
      ↓
run
```

If a mismatch can already be detected through static artifact inspection, that is generally the preferred detector.

A later compile, link, load, or execution result can then provide additional confirmation of the same underlying agreement.

This corresponds to the existing regression-driven ladder:

1. inspect one artifact,
2. compare two surfaces statically,
3. check an action postcondition,
4. exercise the meeting,
5. execute the program.

The project already states that failures should be caught at the earliest practical rung because later runtime failures are slower and provide weaker blame information.

Two rules follow, and both are worth keeping explicit:

* **Escalate only when forced.** An agreement observable at rung 1 must
  not be left to rung 5; a run-time failure is slower, flakier, and
  blames less precisely.
* **A rung-5-only failure is a finding about the FRAMEWORK**, not only
  about the project under test. It names a surface we do not yet
  inspect, and is therefore the main generator of new catalogue
  entries.

A useful interpretation is therefore:

```text
static observation
      ↓
static meeting
      ↓
dynamic meeting
      ↓
runtime confirmation
```

These are observation depths, not separate agreement families.

---

## 0.5 Cache behavior is outside the agreement model

The project is intentionally cache-friendly.

Many enumerated worlds may share the same provider artifact, binding artifact, inspection result, or action result. Idempotent actions can therefore be cached and reused.

However:

> **Caching is an execution-layer property, not an invariant or agreement.**

The agreement catalogue should not depend on how checks are memoized or reused.

It should only describe:

```text
what should hold
what evidence is relevant
where it becomes observable
what later observation may confirm it
```

The execution engine is separately responsible for avoiding duplicated work.

---

# 1. Resource Presence and Identification

The first two candidate families, existence and identity, are better treated as a single lower-level capability.

They are foundational observations used repeatedly by higher-level agreements such as resolution, dependency closure, packaging, and version compatibility.

The core abstraction is:

```text
resource reference
       ↓
resource substrate
       ↓
presence + identification
```

The module answers two basic questions:

### Presence

```text
Can the referenced resource be observed?
```

### Identification

```text
What observable facts identify the resource that was found?
```

This module does not itself decide compatibility.

It provides evidence that later agreements consume.

---

## 1.1 File-system resources

Example:

```text
/path/to/libfoo.so
```

Presence can be checked externally through the file system.

Identification may expose facts such as:

```text
path
file type
metadata
hash
binary format
other inspection-derived facts
```

More specialized binary information can later become part of the artifact's surface.

The important point is that existence of a file and the properties of the file are grounded in observable file-system and inspection results.

---

## 1.2 Web and URI resources

A resource may instead be referenced through:

```text
URL
URI
remote object identifier
```

Presence may mean:

```text
the resource resolves
the resource can be fetched
```

Identification may include:

```text
resolved/final URI
content identity
content hash
returned metadata
```

Again, this is substrate-level evidence.

---

## 1.3 Package-manager resources

Package-level existence cannot always be reduced to file-system existence.

A package manager has its own resource model and commands for answering questions such as:

```text
does package X exist?
is package X installed?
what package/version is installed?
what files belong to this package?
```

Therefore a package-level check should use the package manager's own observable instructions when the resource being discussed is a package.

A check such as:

```text
package X exists
```

is different from:

```text
file Y exists
```

even when package X eventually materializes file Y.

The two can be composed:

```text
package metadata/instruction
        ↓
expected package contents
        ↓
contained resource presence
```

---

## 1.4 Extensible resource substrates

The abstraction should not be tied to file systems or package managers.

Other possible substrates include:

```text
KV store
artifact store
object store
cache
package registry
remote build result store
```

The same pattern applies:

```text
reference
  ↓
lookup
  ↓
present / absent

reference
  ↓
identify
  ↓
observable resource facts
```

This is useful because higher-level checks should not need to care whether a resource was obtained from a local path, package manager, URI, artifact registry, or cache.

---

## 1.5 Relationship to resolution

Presence/identification and resolution should remain separate.

Presence/identification answers:

> What resource is here?

Resolution answers:

> Given a resolution mechanism, which resource was selected?

Resolution can therefore repeatedly invoke the lower-level identification machinery.

For example:

```text
loader chooses resource R
        ↓
identify(R)
        ↓
compare actual resource with intended resource
```

The same idea applies to:

```text
compiler include lookup
linker library lookup
package lookup
language module lookup
dynamic loading
```

Details of paths, ABI compatibility, versions, loader policies, and search order are intentionally deferred to later sections.

---

## 1.6 What canary implements today

The capability already exists in the framework, scattered across the
execution layer rather than named as one module. Its instances:

| instance | substrate | presence | identification |
|---|---|---|---|
| per-action markers (`marker_of_action`: `source.ok`, `build.ok`, `install.ok`, `probe.log`, …) | file system | the action's declared output exists | the file itself; nothing finer |
| pinned-ref freshness | git working tree | the checkout is there | `rev-parse HEAD` equals the declared ref (works for SHAs and tags) |
| PM pin-check | package manager | the package is installed | the installed VERSION equals the declared pin |
| repo-contents invariant | git tree | the tree is there | it contains what its declared row says it provides |
| staged completeness (`assert_staged`) | file system, install prefix | the staged file exists | (currently a hand list; deriving it from the declared surface is a to-do) |

Two observations from that table:

* Most instances today check **presence** and only some check
  **identification** — markers in particular prove that a file appeared,
  never that it is the right one. That asymmetry is exactly why the
  execution layer had to add a separate spec-fingerprint gate: presence
  alone cannot tell a current artifact from a stale one.
* The instances live as action postconditions, which is the right
  execution shape, but they are not yet reachable as a *capability*
  that higher agreements can invoke — §1's abstraction is what would
  make resolution (§5) and dependency closure (§6) able to reuse them.

---

# 2. Artifact Surfaces

This is the current active section.

The term **surface** already exists in the project design. The original registry used `Surface`, `Meeting`, and `Execution` as descriptive roles, where `Surface` asks what one artifact presents at its boundary.

The term is useful and should be retained, but the current discussion makes a more detailed distinction inside the surface category.

---

## 2.1 Syntactic surface and realized surface

The project distinguishes two broad kinds of artifact surface.

### Syntactic surface

A **syntactic surface** is information directly visible in source-level artifacts.

Examples include:

```text
C header declarations
C stub source
OCaml .ml source
OCaml .mli source
Python extension source
Python ctypes declarations
Python source modules
```

The syntactic surface captures what the source claims or explicitly expresses.

---

### Realized / semantical surface

A compiled or otherwise realized artifact also exposes an observable surface.

Examples include:

```text
C shared-library exports
undefined references
symbol versions
binary metadata
compiled OCaml interface metadata
compiled OCaml module metadata
compiled extension metadata
runtime-loadable entry points
```

These facts usually require platform or language-specific inspection tools.

Internally, this has been described as the **semantical surface** because it represents the interface that actually survived realization rather than the one merely visible in source syntax.

However, the word `semantic` can also imply full program semantics in PL terminology.

A clearer public name may therefore be:

```text
syntactic surface
realized surface
```

If `semantical surface` is retained internally, the document should explicitly define it as:

> the realized, tool-observable interface of an artifact, not the full behavioral semantics of the program.

### The five named surface roles

The manuscript already names five surfaces along exactly this axis
(presence: syntactic/realized) plus a side (native/binding). They are
the vocabulary the checking code writes against, so the catalogue
should reuse the identifiers rather than invent parallel ones:

| id | name | side | kind | what it is |
|---|---|---|---|---|
| Sf.1 | `native_header` | native | syntactic | declared C interface — signatures, structs, macros |
| Sf.2 | `native_lib` | native | realized | the compiled `.so`/`.dylib` — defined symbols, `@@VER`, SONAME, NEEDED |
| Sf.3 | `binding_stub` | binding | syntactic | the stub-facing declarations — `external`, `argtypes`, `PyMethodDef` |
| Sf.4 | `binding_header` | binding | syntactic | the user-facing module signature — `.mli` vals, Python module names |
| Sf.5 | `binding_lib` | binding | realized | the compiled binding — `.cmxa` + stub `.a`, the cext `.so` (ctypes: n/a) |

A **runtime observation** (a probe's trace) is deliberately NOT one of
the five: it observes execution, not an artifact's boundary. It is
referred to as `Trace` where a row needs to name it.

### Where the evidence comes from

Each inspect input the checking code consumes maps to exactly one
surface role — this is what grounds a check in an artifact rather than
in a tool:

| inspect input | surface role (side) |
|---|---|
| `C_stub` | Sf.3 (binding) |
| `Native_lib` | Sf.2 (native) |
| `Ocaml_mli` / `Python_attrs` | Sf.4 (binding) |
| `Abi_surface` | Sf.5 (binding) |
| `Versioned_exports` / `Versioned_req` | Sf.2 (native) / Sf.5 (binding) |
| `Typed_header` / `Typed_binding_stub` | Sf.1 (native) / Sf.3 (binding) |
| probe output | `Trace` — a runtime observation, not a surface |

Note that Sf.5 is empty for ctypes (nothing is compiled on the binding
side), which is the structural reason that mechanism loses its
static falsifiers — the point §2.6 develops.

---

## 2.2 Fundamental surface agreement

The first general agreement in this section is:

> **The realized surface produced by a toolchain should correspond to the relevant syntactic surface from which it was produced.**

Conceptually:

```text
syntactic surface
       ↓ realization
realized surface
```

This relationship is more general than an individual symbol or type check.

Different checks simply inspect different projections of the two surfaces.

For example:

```text
header declares foo
       ↓
library exports foo
```

is a **name/symbol projection**.

Likewise:

```text
header declares the signature of foo
       ↓
compiled artifact exposes compatible type information
```

is a **type/signature projection**, when such information is observable.

This suggests that symbol agreements and type agreements belong under a common concept of **surface correspondence** rather than necessarily being independent top-level categories.

---

## 2.3 Provider-side surface chain

The C provider already has at least two important surfaces.

### Source-level provider surface

Typically represented by the C header:

```text
foo.h
```

It may expose:

```text
function names
parameter types
return types
struct declarations
enum declarations
constants/macros where relevant
calling-related annotations
visibility declarations
```

This is the strongest source-level description of the provider API currently available to the binding.

---

### Realized provider surface

The compiled C library:

```text
libfoo.so
```

has a different observable surface.

Depending on available tooling and build information, it may expose:

```text
exported symbols
undefined symbols
symbol kind
symbol versions
dynamic metadata
relocations
debug/type information when available
```

The existing document already exploits this difference. It notes that headers carry type information while compiled artifacts often require tools such as `nm` or DWARF inspection to recover parts of the realized interface.

This naturally creates provider-side correspondence checks:

```text
header
  ↕
compiled C library
```

---

## 2.4 OCaml C-stub binding surfaces

For the OCaml mechanism, the binding itself exposes several different surfaces.

### C stub source

For example:

```text
foo_stubs.c
```

This is simultaneously:

* a consumer of the C provider,
* an implementation of the native side of the OCaml binding.

Its syntactic surface may contain:

```text
native symbol references
C types
marshalling operations
OCaml runtime API use
primitive entry points
```

This surface can be compared directly with the C header.

---

### OCaml interface source

For example:

```text
foo.mli
```

This is the language-facing declared API.

It says what the binding promises to OCaml consumers.

Example:

```ocaml
val foo : int -> string
```

---

### OCaml implementation source

For example:

```text
foo.ml
```

This implements the language-side API.

It may:

```text
declare external primitives
wrap primitives
rename operations
compose several native calls
expose only a subset
add language-side behavior
```

The OCaml compiler already provides an important tool-based agreement:

```text
.ml conforms to .mli
```

The checking framework should consume this result rather than recreate OCaml's own type checker.

---

### Compiled OCaml artifacts

The binding may then produce:

```text
.cmi
.cmo
.cmx
.cma
.cmxa
.cmxs
stub .o
stub .a
stub .so
```

These artifacts still expose substantial observable information.

Existing project tooling already inspects these artifacts using the relevant OCaml and native-object tools.

Therefore the compiled artifacts should be treated as realized surfaces rather than opaque binaries.

This creates potential correspondence edges such as:

```text
.mli
 ↓
.cmi
```

```text
.ml / external declarations
 ↓
compiled module metadata
```

```text
stub source
 ↓
stub object/archive/shared-library references
```

The exact catalogue of projections still needs to be completed.

---

## 2.5 Python C-extension surfaces

The Python C-extension mechanism has a similar but distinct chain:

```text
C header
    ↓
extension C source
    ↓
compiled extension shared object
    ↓
Python-visible module/package
```

Relevant surfaces include:

### Source surface

```text
extension C implementation
Python package/module source
```

### Realized native surface

```text
compiled extension .so
native symbol references
extension initialization entry point
binary dependencies
other inspectable metadata
```

### Runtime Python surface

```text
imported module
visible names/objects
package-level exports
```

This mechanism therefore supports surface correspondence at several points:

```text
header
↔ extension source

extension source
↔ compiled extension

compiled extension
↔ runtime Python module
```

---

## 2.6 Python ctypes surfaces

ctypes has a shorter artifact chain:

```text
C header
    ↓
Python ctypes declarations
    ↓
Python module
    ↓
runtime calls
```

There is no native binding compilation stage.

The consumer-side syntactic surface therefore includes constructs such as:

```text
library name/path declaration
function lookup
argtypes
restype
structure declarations
callback declarations
```

The absence of a binding compilation stage is significant.

For example, a type mismatch may have:

```text
source inspection
        ↓
no compiler confirmation
        ↓
runtime call
```

rather than the:

```text
source inspection
        ↓
C compilation
        ↓
link/load
        ↓
runtime call
```

available to the C-stub mechanisms.

This is an example of mechanism affecting **where an agreement can be observed**, while the underlying agreement remains the same.

---

## 2.7 Surface correspondence as the common model

The general form is:

```text
Artifact A exposes Surface A
Artifact B exposes Surface B

Agreement:
projection(Surface A)
corresponds to
projection(Surface B)
```

Possible projections include:

```text
names / symbols
members / modules
types / signatures
references / requirements
metadata
```

For example:

```text
C header ↔ C library
C header ↔ binding stub
binding source ↔ compiled binding
OCaml .mli ↔ .cmi
binding interface ↔ wrapper interface
compiled binding ↔ runtime-visible module
```

The exact projection catalogue remains the next item to develop.

---

## 2.8 Surface inspection versus resolution

A key boundary should be maintained.

Suppose static inspection finds that an artifact requires symbol or library `X`.

That belongs to **artifact surface inspection**:

```text
artifact says:
    "I require X"
```

A later loader observation answers a different question:

```text
loader resolved X to resource R
```

That belongs to **Resolution**.

Likewise:

```text
compiled artifact records dependency D
```

belongs to the artifact's surface.

```text
runtime loaded /path/to/D
```

belongs to resolution and dependency closure.

The distinction is useful because many later agreements repeatedly consume previously inspected surfaces.

---

# 3. Representation and Marshalling Agreements

**Status: pending.**

This section should cover value preservation across the native/language boundary after the surface correspondence model is stabilized.

Likely subjects include:

```text
integer width and signedness
floating-point values
strings
NULL / option / None
struct and record representation
enum/tag mappings
pointer representation
error representation
callbacks
```

This section should remain distinct from type correspondence because compatible type shapes do not guarantee correct runtime value representation.

---

# 4. Lifetime and Ownership Agreements

**Status: pending.**

Likely subjects include:

```text
borrowed versus owned pointers
returned-object ownership
input lifetime
callback lifetime
GC rooting
Python reference ownership
double free
leaks
use after free
repeat-call stability
```

These agreements are expected to depend more heavily on dynamic probes and instrumentation than the earlier surface agreements.

---

# 5. Resolution Agreements

**Status: pending.**

Resolution should build on the lower-level resource presence/identification capability.

The central question is:

> Given a resolution mechanism, which resource was actually selected?

Potential resolution domains include:

```text
compiler header discovery
link-time library selection
dynamic-loader library selection
OCaml package/module discovery
Python module discovery
ctypes library lookup
```

Path rules, version selection, ABI-related selection, and shadowing should be discussed here rather than inside the basic presence/identity layer.

---

# 6. Dependency-Closure Agreements

**Status: pending.**

This section should distinguish at least:

```text
declared dependencies
artifact-recorded dependencies
runtime-resolved dependencies
```

The existing document already identifies important hidden-dependency cases including transitive `NEEDED`, runtime `dlopen`, symbol interposition, and weak/default symbol resolution.

These should eventually become concrete agreement rows grounded in observable tool results.

---

# 7. Transformation and Packaging Preservation

**Status: pending.**

Any lifecycle transformation such as:

```text
build → stage
stage → package
package → publish
publish → fetch
fetch → install
```

may preserve some properties while changing the carrier.

The existing staged-parity work is already an instance of this broader pattern. The current document explicitly describes staged parity as the same artifact-checking family one lifecycle stage later.

This section should generalize that idea.

---

# 8. Behavioral Agreements

**Status: pending.**

Behavior should remain the deepest observation layer.

Likely categories include:

```text
function reachability
return values
state changes
error behavior
callback behavior
repeat execution
wrapper faithfulness
direct-vs-indirect differential behavior
```

Execution should remain a last resort when earlier artifact or meeting observations can already falsify the relevant agreement.

---

# 9. Project- and Version-Derived Agreement Discovery

**Status: pending.**

Candidate agreements may originate from several sources:

```text
artifact structure
binding mechanism
language/platform tool behavior
project declarations
project code
version information
historical regressions
```

Version differences are particularly useful because they can generate candidate agreements without requiring a full semantic model.

For example:

```text
stable provider exports {a, b, c}
dev provider exports    {a, c}
```

immediately suggests a symbol-surface compatibility question for existing bindings.

Likewise:

```text
header signature changes
SONAME changes
dependency-set changes
binding interface changes
```

can generate candidate checks.

This should later feed the agreement catalogue, while the project-specific declaration remains the oracle for facts that cannot be inferred generically.

---

# 10. Blame and Result Interpretation

**Status: pending review.** Carried over from the registry design,
where it was an open axis; the outline gained a section for it
2026-08-21.

For every check, on every agreement, two questions need an answer that
does not depend on the reader's intuition:

> What does a passing result mean?
> What does a failing result mean, and which artifact is indicted?

## 10.1 A pass means something different at each observation depth

A pass is never "compatible"; it is bounded by what was observed:

```text
one artifact, statically   → this artifact's presented facts cover the
                             declaration. Says NOTHING about the other side.
two surfaces, statically   → these two declarations agree. Says nothing
                             about what the toolchain will actually do.
an action postcondition    → the action produced its declared output.
                             Presence, not correctness.
the meeting                → this pair joined under the conditions
                             exercised — a fact about the RELATION.
the run                    → this execution behaved, bounded by the
                             coverage of the program that ran.
```

Writing the pass meaning next to each agreement is what stops a green
matrix from being read as "verified".

## 10.2 Failure blame is direction-shaped

A single-artifact failure blames that artifact: what it presents
contradicts what it declared.

A failure of a PAIR is ambiguous at the point of detection — the
symbol is missing, but is the provider too old or the consumer too
new? The framework already computes the answer as a scenario property:
`mismatch_direction` (Forward / Backward).

```text
forward  (consumer newer than provider) → the consumer asked for too
                                          much; the binding/app is indicted
backward (provider newer than consumer) → the provider dropped or changed
                                          something; the lib is indicted
```

The rule is worth stating once, globally, rather than per agreement:
**blame = (which artifacts the evidence relates) × (the scenario's
mismatch direction)**.

## 10.3 Instrumented observations shift blame deliberately

Two future instruments invert the usual reading, and each needs its
blame statement fixed in advance:

* a **fake provider** (a planted lib satisfying the declared surface)
  moves blame to the consumer's robustness — or to the declaration the
  plant was built from;
* a **recorder** (interposition that logs what was actually requested
  or resolved) blames nobody: it produces evidence, not a verdict, and
  its output feeds §5 and §6.

## 10.4 Open questions

* Does every agreement row need its own blame field, or does blame
  derive uniformly from (evidence shape × direction)?
* Can a single-artifact failure ever be direction-resolved — e.g. the
  artifact IS the provider in a backward world?
* Where a version skew exists between two evidence sources (headers
  from a source repo, lib from a package), the row must record which
  artifact's version the oracle assumed, or blame lands on the wrong
  side (§2.3, §5).

---

# 11. Mapping Back to Actions and the Registry

**Status: pending.**

Once the agreement catalogue is sufficiently complete, concrete agreements should be mapped back into the existing action-centred framework.

The existing design already models the main checking space as:

```text
agreement/contract × action
```

with mechanism and provision refining where a check applies rather than creating a full Cartesian-product matrix.

Each final agreement row should eventually state something close to:

```text
name
claim                          (phrased as its falsifier, §0.3)
origin
relevant surfaces/artifacts    (Sf.1..Sf.5 / Trace, §2.1)
earliest observation point     (the ladder rung, §0.4)
tool/result used as evidence
later dynamic confirmation
applicable mechanism
applicable provision
minimal falsifier / fixture    (executed ahead of any project run, App. A)
pass meaning + blame           (§10)
current implementation status
```

The registry then becomes the executable projection of this larger catalogue.

---

# Current Working Position

The discussion should continue from **§2: Artifact surfaces**.

The next concrete question is:

> **What projections make up an artifact surface?**

The current candidates are:

```text
names / symbols
members / modules
types / signatures
references / requirements
metadata
```

The next pass should determine:

1. whether these projections are complete;
2. which projections exist on the provider side;
3. which projections exist for OCaml C stubs;
4. which projections exist for Python C extensions;
5. which projections exist for Python ctypes;
6. which pairs of surfaces produce useful concrete agreements.

The inspection tools themselves already exist in the project and have their own tests, so the next step should focus on **what is being observed and compared**, rather than re-cataloguing tool implementations.

---

# Appendix A. The registry module as implemented

> Carried over from `contract_registry.md` (merged 2026-08-21). This is
> the EXECUTABLE projection of the catalogue as it stands today —
> §11 absorbs it when the mapping-back section is worked through.
> Nothing here is a proposal; it is what the code does.

## A.1 — Producer-first, two-agent-safe


The registry is a NEW additive module — `surface/canary_contract_registry.ml` —
that consumes nothing from `project/` or `main/`. It assembles the belief
from theory pieces that already exist:

- comparators + the `contract_check` proto-row (`id/name/layer/status/
  enabled/predict`) — `surface/canary_compat.ml`
- the predict closures + `registered_checks` — `surface/canary_compat_run.ml`
- the input template (`inputs_of_contract ?mechanism contract lang`) — M2
  step 2, same file
- the fault tags — `scenario.md`'s catalogue + `canary_expected_of`

Consumers (the lowering, the per-project binding tables, spec-check, the
tiny oracle) migrate in a SECOND phase, one at a time, each pinned. The
only rendezvous with the other agent is this module's exposed type, fixed
here — so the producer side can land while project work continues.



## A.2 — The row


Extending the existing `contract_check`, one row per contract states the
whole belief:

```ocaml
type role =
  | Surface    (* one artifact: what it presents at its boundary *)
  | Meeting    (* two artifacts: are they compatible where they link/load *)
  | Execution  (* two artifacts running: what the pair's trace shows *)

type source =
  | Inspection      (* inspect JSONs → predict → compat-derived expectation *)
  | Behavior_grep   (* the run's log substring → failure expectation *)
  | Postcondition   (* the action's check_post family: markers, pin-checks,
                       staged-parity at Install_lib, freshness *)
  | Placeholder     (* Expect_success until wired (missing-ness visible) *)

type contract_row = {
  row_check   : Canary_compat.contract_check;
      (* id, name, layer, status, enabled, predict — already exists *)
  invariant   : string;
      (* the one-sentence agreement, phrased as a FALSIFIER (§5); the
         reconciliation point for ssot's Ag.X ↔ C1..C8 drift decision *)
  role        : role;
      (* PROSE tag at most (Surface/Meeting/Execution — the legacy
         evidence vocabulary). Not a typed axis: the action column
         already implies the cell's subject (one artifact vs a pair)
         and its evidence flavor. *)
  inputs      : Canary_mechanism.mechanism -> Canary_lang.lang ->
                Canary_compat.inspect_input list;
      (* the step-2 template — WHAT files the check reads, derived from
         the binding_decl (coupling products, surface_path) *)
  firing      : Canary_mechanism.mechanism -> Canary_lang.lang ->
                Canary_store.provision -> Canary_basic.action list;
      (* WHERE it fires — over the ACTION CATALOGUE
         (Canary_basic.action, the general base vocabulary; SSOT §6.5).
         Contracts are general for ALL artifacts, actions and
         mechanisms — any action kind can carry a check (fetch,
         configure, build, publish, probe, …); today's rows fire at the
         build/probe actions (the wired subset). No new firing type is
         invented; the action layer refines an action into
         Canary_scenario.firing_site (location, loc_filter) in phase 2.
         A row returns [] where nothing fires; the per-project
         enabled/disabled policy is the bypass. *)
  source      : source;
      (* HOW the expectation comes to be — the expectation half of
         the belief, stated per row; the ONE typed axis that survives
         (§8): inspect JSONs → predict (Inspection), grep the run's
         log (Behavior_grep), the action's check_post family
         (Postcondition — staged-parity at Install_lib, pin-checks,
         freshness), or not wired yet (Placeholder). *)
  fault_tags  : string list;
      (* step 9: sym_missing ↔ c1, api_drop ↔ c2, … — the tag ↔ contract
         mapping becomes data on the row, not a synced-by-hand table *)
}

let contract_registry : contract_row list = [ ... c1 .. c8 ... ]
```

`firing` is THE new piece. Everything else is consolidation.

**Provisional naming.** The C1..C8 ids are the OLD index, kept for now
only because the consumers still speak it. With a principled
collection the contracts should be ENUMERATED and NATURALLY NAMED,
following the scenario-naming style (Sc.\<stage\>.\<terminal\>_on_\<deps\>):
once canonical names exist for artifact-surfaces (Sf.1..Sf.5), actions,
and platforms, a contract's name derives from those primitives (user,
2026-08-17). The rename lands with the canonical-naming settle step;
the invariant strings carry the semantics, so the rename is mechanical
— the `id` field is the one rename point.



## A.3 — Provision-gated firing — which checks apply depends on which stages we got


A Fetched artifact (from the internet / a PM) and a Built artifact (from
source) are different WORLDS for checking, because different stages exist:

- **Built**: build sites exist — build-time contracts fire (c6's
  header/stub type match at `build_binding`), then link + probe sites.
- **Installed** (2026-08-18): groups WITH Built — its chain includes the
  real build plus the staging step, so the build-family contracts fire;
  what differs is which concrete artifact the consumer reads (the
  staged prefix). The staging step's own checks are the
  `Install_lib × Postcondition` family (staged parity — see
  [`staged_parity.md`](staged_parity.md)).
- **Fetched / Vendored / Cached**: the product was given, nothing was
  built — build sites do not exist, and build-time contracts have nothing
  to fire on; probe-side checks (c1/c2/c4 at probe) still apply.

So the firing derivation has TWO axes, both already known to the framework:

1. **mechanism** (M2 step 3): Static_c_abi → build + probe sites;
   Dynamic_ffi → probe only.
2. **provision** (the action graph): a Fetched binding has no
   `Build_binding` step at all — the enumeration already prunes it.

`firing mechanism lang provision` states both axes per contract instead
of per-project hand-listing, and the domain is the FULL action
catalogue — not only build/probe: a source-integrity contract could
fire at `Fetch Source`, a publish-verification contract at `Publish
Lib` (the publish work lives with another agent). Today's rows return
the wired subset; extending a row to a new action is a row change, not
a framework change. Per-action expectation can be bypassed through the
per-project enabled/disabled policy. The pre/post conditions to check
become a pure function of `(decl, mechanism, provision)`.



## A.4 — Testing AHEAD of project running — fixtures ride with the rows


Each contract ships its MINIMAL COUNTEREXAMPLE — a `fixture`: synthetic
inspect inputs (file-name references + their JSON bodies) and the
failure substrings a `predict` MUST yield on them. A fixture may carry
its OWN closure (`fx_predict`) instead of the row's — that is how a
per-CELL predict is tested (the lib-only cells' decl-comparison
closures, §13); `None` means "the row's `cr_check.predict`". The layer
tests (`contracts.fixtures_execute`) run every fixture hermetically —
no project run, the framework-test axis (same shape as the
compat-helper tests; the loaders read real files, so the test writes
the bodies and maps names to paths). Two consequences:

- a NEW contract lands WITH its fixture — the producer self-tests
  before any project consumes it;
- a changed predict breaks the pin — the belief cannot drift silently.

The completeness pin (`contracts.fixtures_complete`) states the covered
set visibly: **C1, C2 + C4/C5's lib-only cells** (2026-08-18). C3/C7
are disabled in the registry (`Blocked []` / `Stubbed`); C6 pends its
typed-loader fixture; C4/C5's PAIR cells pend theirs (only their
lib-only halves are covered).



## A.5 — The lib-only cells — the first fills (2026-08-18)


Three cells landed as the first deliberate fill, all on the ONE
artifact (the binary C lib) at `Build_lib`, all sharing one shape:

| cell | falsifier | evidence |
|---|---|---|
| c1 @ build_lib | a declared `c_api` function is missing from the built lib's exports | nm symbols vs the decl |
| c4 @ build_lib | the built lib's elf soname ≠ the declared soname | elf vs the decl |
| c5 @ build_lib | a declared version tag is absent from `versioned_exports` | `@@VER` vs the decl |

Their closures (`c1_decl_predict`, `c4_decl_predict`,
`c5_decl_predict` in `canary_compat_run.ml`) are **decl-comparison**
predicts: they read ONE artifact's inspected surface and compare it
against the project's DECLARED facts (`binding_decl`), with no
consumer involved.

**Why this shape is the general one** (user, 2026-08-18): the language
tools — compilers, linkers, version scripts, install rules — are
BLACK BOXES with no bit-wise operational semantics we can reason
about. A linker may silently drop a version script; a build system may
not re-run; an install may skip a rule. So we do not trust the tool's
exit code beyond its marker postcondition: we inspect the ARTIFACT it
produced and compare against what was declared. Every lifecycle cell
(make / transform / exercise) is an instance of that stance, which is
why `staged_parity.md`'s install checks and these build checks have
the same skeleton — different artifact stage, same "inspect the
product, compare to the declaration".

An observation the fill produced: **c1's lib-only cell is the same
comparison as the status-level watchlist verdict** (`watchlist N/N` /
`⚠ MISSING`). Two views of one belief — one recorded post-hoc in the
status table, one predicted as a cell. The registry is where they
reconcile.



## A.6 — the `role` field is prose, not a typed axis

The code's row still carries a `cr_role` (`Surface` / `Meeting` /
`Execution`). It is a DESCRIPTIVE tag only: the action already implies
a cell's subject (one artifact vs a pair) and its evidence flavour, so
nothing dispatches on it. The typed axis is the expectation mechanics
(`source`: `Inspection` | `Behavior_grep` | `Postcondition` |
`Placeholder`). §2 of this doc re-grounds the word "surface" properly;
the code's tag is kept only until the rename in §11.


---

# Appendix B. The two matrix views

> Carried over from `contract_registry.md`. Both are views of ONE cell
> set; §11 decides which survives as the registry's own rendering.

## B.1 — The general matrix


The belief space is NOT a free product of its axes — most of it is
DERIVED. The matrix that is actually general: **rows = contracts,
columns = ACTIONS**, because an action already determines its
artifacts (the action catalogue's consumes/produces). The mechanism
and provision axes do not add cells — they REFINE them: they decide
which actions exist in a scenario (chain shape × enumeration) and
what the input template yields. So:

```
  cell : (contract × action) → {
    status      : Wired | Declared_empty of reason | Blocked of deps
    inputs      : mechanism -> lang -> inspect_input list
    source      : Inspection | Behavior_grep | Postcondition | Placeholder
    fixture     : the bad-world counterexample (predicted substrings)
    pass_means  : the good-world reading (blame axis, §16)
  }
```

**One typed axis.** The ACTION implies the cell's subject (one artifact
at a lifecycle action vs a pair at a meeting — its consumes/produces
say which artifacts) and its evidence flavor (read / join / run). The
only typed axis that survives is the expectation MECHANICS (`source`):
how the expectation is produced — inspect JSONs → predict
(Inspection), grep the run's log (Behavior_grep), the action's
check_post family (Postcondition — where staged-parity at Install_lib,
pin-checks, and freshness live), or not wired yet (Placeholder).
The legacy roles stay prose (§4).

**The derivation rules** (what the code actually does — the roles are
NOT part of it; they were demoted to prose, §4):

1. each row names a FIRING FUNCTION — `mechanism × lang × provision →
   action list`. Three exist today:
   - `firing_default` — Static ⇒ `[Build_binding l; Probe_binding l]`
     in Built/Installed worlds, `[Probe_binding l]` where nothing is
     built; Dynamic ⇒ `[Probe_binding l]` (no compile stage);
   - `firing_with_build_lib` — the same PLUS `Build_lib` in Built
     worlds: the row also has a lib-only cell (§9);
   - `firing_probe_only` — a run is required, so probe only, in every
     world.
2. the input template (`inputs_of_contract ?mechanism`) says which
   surfaces the cell reads — the mechanism refinement lives there
   (a dynamic binding has no stub to inspect).
3. everything else about a cell (its subject, its evidence flavor) is
   implied by the ACTION, not stored.

A new firing shape is a new small function, not a framework change;
phase 2's per-project overrides land as row-level firing functions,
each pinned equal to today's hand-written tables.

**The marks — and why there is no "un-answered".** The matrix is TOTAL
by construction: the firing function answers for every action, so
every cell has a status. (An earlier draft posited an `✗ Un-answered`
mark; it cannot occur — dropped 2026-08-18.)

| mark | status | meaning |
|---|---|---|
| `✓` | `Wired` | fires here AND ships a counterexample fixture |
| `~` | `Declared` | fires here, predict exists, NO fixture yet — **the fill list** |
| `⊘` | `Blocked` | the contract itself is disabled/blocked on deps |
| `·` | `Empty` | does not fire here — the firing derivation says so; a principled absence, not an omission |

**"Filling the matrix" therefore has a bounded, concrete meaning**:
turn `~` into `✓` — attach a counterexample to a cell that already
fires. The job is finite and enumerable (`fill_list` returns exactly
the `~` cells), not open-ended.

Today's shape under the reference world (Cstubs × OCaml × Built),
read off the firing functions:

| contract | fetch_src | conf | scan | hdrs | fetch_lib | **build_lib** | install | fetch_bind | **build_bind** | pack | probe_lib | **probe_bind** | build_app | probe_app |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| c1 symbol (Sf.3×Sf.2) | · | · | · | · | · | ✓ | · | · | ✓ | · | · | ✓ | · | · |
| c2 api-completeness (Sf.4) | · | · | · | · | · | · | · | · | ✓ | · | · | ✓ | · | · |
| c3 behavior (Trace) | · | · | · | · | · | · | · | · | · | · | · | ⊘ | · | · |
| c4 soname (Sf.2×Sf.5) | · | · | · | · | · | ✓ | · | · | ✓ | · | · | ✓ | · | · |
| c5 sym-version (Sf.2×Sf.5) | · | · | · | · | · | ✓ | · | · | ✓ | · | · | ✓ | · | · |
| c6 type (Sf.1×Sf.3) | · | · | (reads) | · | · | · | · | · | ~ | · | · | ~ | · | · |
| c7 repack (Sf.4) | · | · | · | · | · | · | · | · | · | · | · | ⊘ | · | · |
| c8 faithfulness (Sf.4) | · | · | · | · | · | · | · | · | ⊘ | · | · | ⊘ | · | · |

**This table shows only ONE of the three axes' pairings** — contract ×
action, with the artifact left implicit (the action determines it).
For the per-artifact reading — and for the `Postcondition` families,
which have no contract and therefore no row here at all — see §9.

Reading it: the ✓ cells are the belief that is both stated AND
falsifier-tested; `~` (c6) is the whole current fill list; the `·`
majority is the honest picture — most of the action space carries no
contract yet, and the widenings below name which of those we intend
to populate. The `install_lib` column is where the staged-parity
family lands (`Postcondition` source, not a contract predict).

**Two doc↔code drifts this table exposed** (fix in the code, not by
re-wording):

1. `Stubbed` has no distinct mark — `cell_status_of` maps everything
   that is not `Blocked` to Wired/Declared, so c7/c8 currently render
   as `~` (a fill candidate) when in truth their predicts return `[]`
   by construction. `Stubbed` deserves its own status.
2. c8's registered status is `Stubbed`, while this design and
   `scenario.md` both say it is blocked on c6+c7. Reconcile to
   `Blocked [C6; C7]` so the dependency is data, not prose.

Widenings already designed, not landed: a fetch-side integrity cell
(pinned-ref freshness is its postcondition half, e2b4d27), publish
verification cells (the other agent's work), probe_lib/app cells
beyond the oracle, and the mechanisms/langs beyond the wired three —
their cells answer `[]` = declared-empty, never un-answered.





## B.2 — The artifact-centred view — the same cells, re-projected


Three axes are in play — **artifact, action, contract** — and a single
2-D table cannot show all three. They are not independent, though:
**the action determines the artifact** (the catalogue's
consumes/produces), so `contract × action` loses no information. What
it loses is READABILITY per artifact, and one whole cell kind: the
`Postcondition` families (markers, pin-checks, staged parity,
freshness) never appear in it, because they belong to no contract.

So the belief has TWO views of one cell set:

- **contract × action** (§8) — "where does this belief fire?" The
  contract is the subject; good for seeing a contract's whole reach.
- **artifact × stage** (here) — "what do we believe about THIS
  artifact, end to end?" The artifact is the subject; the actions
  where it is PRODUCED or EXERCISED are its lifecycle stages, and the
  actions where it merely participates are listed as provider rows.
  Both cell kinds appear.

Marks as in §8 (`✓` wired + counterexample, `~` declared/designed, `·`
absent). Reference world: Cstubs × OCaml × Built.

**Source**

| stage | belief | kind | |
|---|---|---|---|
| `Fetch Source` | the tree is there; a pinned ref is AT its pin (`rev-parse HEAD = <ref>^{commit}`, e2b4d27) | Postcondition | ✓ |
| `Scan_sources` | the typed-signature JSONs exist (they are c6's inputs, not a belief about source) | Postcondition | ✓ |
| `Fetch Source` | the tree contains what its repo row declares (the repo-contents invariant, `repo_model.md`) | Postcondition | ✓ |

**A source tree has no standalone property to check** (user,
2026-08-18) — and this is a PRINCIPLED absence, not a gap in the fill
list. Everything one might want to assert about source is really an
assertion about one of its derived artifacts: its API is the HEADERS'
surface, its behaviour is the LIB's. What is left is existence and
provenance — the tree is here, at the ref it claims, containing what it
declared — which is exactly the postcondition family above. Source is
therefore `·` by construction, and the fill list should never chase
it.

**Headers**

| stage | belief | kind | |
|---|---|---|---|
| `Build_headers` / `Fetch Headers` | the declared header set is present | Postcondition | ✓ |
| as provider @ `Build_binding` | c6 — the C types at the header/stub boundary agree | Inspection | ~ |
| as **carried oracle** @ `Probe_binding` | the user-facing surface's types agree with the header's (§12) | Inspection | · designed |
| as **carried oracle** @ `Build_app` / `Probe_app` | an INDIRECT wrapper (helper/app) still agrees with the original C API's types (§12) | Inspection | · designed |

Headers are the only artifact whose value is **syntactic form**: they
carry the API's TYPES, which no compiled artifact does. §12 makes that
the basis of a new cell class.

**Lib** — the richest column, and the one we worked through

| stage | belief | kind | |
|---|---|---|---|
| `Fetch Lib` | the PM package is installed, AT the pinned version | Postcondition | ✓ |
| `Build_lib` | c1 — every declared `c_api` function is exported | Inspection (decl-cmp) | ✓ |
| `Build_lib` | c4 — the elf soname equals the declared soname | Inspection (decl-cmp) | ✓ |
| `Build_lib` | c5 — the declared version tags are exported | Inspection (decl-cmp) | ✓ |
| `Build_lib` | the DWARF signatures of the built lib match the declared header (§12; canary controls `-g` here) | Inspection (decl-cmp) | · designed |
| `Install_lib` | staged parity: completeness / integrity / parity / isolation, incl. no build-tree path in a staged binary | Postcondition | ~ designed |
| `Probe_lib` | the declared prefix's symbols are exported (nm) | Inspection | ✓ project-side |
| `Probe_lib` | it LOADS and each declared function can be entered (the smoke cell) | Behavior_grep | · postponed |
| as provider @ `Build_binding` | c1 / c4 / c5 / c6 against the consumer | Inspection | ✓ / ~ |
| as provider @ `Probe_binding` | c1..c5 at load/run | Inspection | ✓ |

**Binding**

| stage | belief | kind | |
|---|---|---|---|
| `Fetch (Binding l)` | the package is installed, AT the pinned version | Postcondition | ✓ |
| `Build_binding l` | c1 (stub refs vs lib), c2 (user surface), c6 (types) | Inspection | ✓ ✓ ~ |
| `Publish (Binding l)` | the package materialises (publish verification is the other agent's) | Postcondition | ~ |
| `Probe_binding l` | c1..c5 at load/run; c3's trace | Inspection / Behavior_grep | ✓ / ⊘ |
| as provider @ `Build_app` | the app compiles against the binding's surface | — | · |

**App**

| stage | belief | kind | |
|---|---|---|---|
| `Build_app` | the app builds against the binding | Postcondition | ✓ |
| `Probe_app` | c3 — the run's trace matches the expectation | Behavior_grep | ✓ tiny's oracle only |

The Lib rows above cover the SYMBOL family only. Its two other
families — **paths** (loader/embedded/identity/language-side search,
per platform) and **hidden dependencies** (transitive NEEDED, dlopen'd
plugins, interposition) — are catalogued in
§10, together with
the per-MECHANISM lifecycles (cstubs / cext / ctypes / dynlink), which
are where `lang × mechanism` gives each artifact chain its own
agreements.

**What the projection makes obvious** (and §8's table does not): the
Lib is checked at FOUR distinct stages with three different mechanics,
and its weakest stages are the ones where the artifact merely arrives
or is transformed — `Fetch` (identity only) and `Install_lib` (parity
still designed). The Binding is well covered at build/probe and
uncovered at publish. Source and App are nearly bare. That is the
development picture per artifact, which is what "fill the matrix"
should be steered by.




---

# Appendix C. Status, plan, and sequence (as of the merge)

## C.1 — Coverage status and plan


The GOAL: every cell of the belief space has a DEFINED result — the
pre/post-check and the expectation hold for good AND bad intended
results (each wired cell is a disprover with a named counterexample),
so completeness of checking is itself checkable. The space:

    contract (8) × action (12 kinds × langs × app wirings)
    × artifact-kind (5) × mechanism (5) × provision (4)

**Current status — what is defined where.**

1. **Per-action pre/post — TOTAL by construction.** `check_pre` (the
   automatic dep check) and `default_check_post` (the marker table,
   `marker_of_action` — one postcondition per action kind) cover every
   step. The warm-mask fix (e2b4d27) made them SPEC-AWARE: the marker
   v2 fingerprint (cmd + expectation form) means a spec edit
   self-invalidates — pre/post results can no longer silently serve a
   stale world.
2. **Contract firings — the wired subset.** The registry defaults fire
   at `Build_binding l` / `Probe_binding l`, PLUS `Build_lib` for the
   three lib-only cells (§13). Declared but unwired: `Probe_lib` (no row fires there — c1's lib side rides
   inspect attachments on build_lib), `Build_app`/`Probe_app` (the
   firing vocabulary has the sites; no row uses them — tiny's oracle
   covers app firings today), `Scan_sources` (c6's inputs READ its
   JSONs, c6 fires elsewhere), and the fetch/configure/install/publish
   actions (publish belongs to the other agent's work; a fetch-side
   integrity contract is designed, not landed).
3. **Expectation forms.** 5 Inspection, 2 Behavior_grep, 1
   Placeholder (c8) + the `Postcondition` form reserved for the
   check_post families (markers, pin-checks, staged parity). The known
   gaps (c4-OCaml's Placeholder firing, `symbol_orphan`'s
   contract-less build failure) close inside the registry; c8's
   registered status needs the `Blocked [C6; C7]` reconciliation
   (§8's drift 2).
4. **Mechanisms/langs beyond the wired three.** Cffi/Dynlink and the
   Rust/Java/Cpp/CSharp langs are declared in the vocabulary with no
   belief cells yet — the row functions must answer for them too
   (returning [] = declared-empty, distinct from un-answered).

**The plan — make incompleteness visible, then close it.**

1. **The matrix view** — `belief_matrix` / `fill_list` /
   `pp_belief_matrix` (written 2026-08-18): the cells as data, the
   `~` set as an explicit fill list, and a rendered table. The matrix
   is total, so the pin is not "no un-answered cell" (impossible) but
   the fill-list SHAPE: the pin states today's `~` set exactly, so a
   new unfixtured cell shows up as a diff. Two code refinements the
   table exposed are listed in §8.
2. **Per-cell counterexamples.** The fixture harness generalizes from
   per-contract to per-CELL (contract × firing action): each wired
   cell ships the minimal bad-world input + its predicted substrings;
   the good-world result is the cell's pass meaning (blame axis, §7).
   A cell is "complete" only when both hold.
3. **Per-action belief statements.** The marker table gives every
   action a postcondition; the belief side adds its one-line MEANING +
   blame (what does `build.ok` pass/fail say about which artifact —
   e.g. the pinned-ref freshness check_post the other agent added is a
   fetch-side postcondition with a clear fail meaning).
4. **Order.** (a) the matrix view + its fill-list pin → (b) fill
   probe_lib + app cells (tiny's oracle is the reference) → (c)
   fetch/publish cells as their projects land → (d) the new
   mechanisms/langs as their bindings land.

**Decided and deferred** (2026-08-18, user):

- **The C smoke probe** (`Probe_lib` Execution cell — compile a
  minimal program against the lib, load it, enter each declared
  function once). VERDICT: worth it, because it is the only check
  that exercises the LOADER — the lib's own undefined closure, broken
  NEEDED/RPATH, constructor (`.init_array`) failures, load-time
  version resolution. That class is structurally invisible to nm/elf
  tools: a lib can be perfectly formed and still fail to load. The
  program is decl-DERIVED (`c_api.functions`), so it carries no
  hand-written payload. Deeper behavior stays with the App actions.
  POSTPONED — it needs action-layer probe machinery.
- **Where an expectation is declared** (user, 2026-08-18): an
  expectation is project-AGNOSTIC whenever artifact/action/mechanism
  determine it (those live in the registry); when it is genuinely
  project-dependent it belongs in the STATIC project spec as a
  declared field — never hidden inside a realization closure. The
  smoke probe's expected-output patterns are the first case of the
  latter.
- **Checks as actions** (`[Pre; Action; Post]`, recorded in
  `status.md` design directions): would make every matrix cell an
  action in the enumeration, and the coverage pin an enumeration
  invariant. POSTPONED — the IR layer is uniform enough to wait.
- **Staged parity** (`Install_lib × Postcondition`) is the same
  belief family one artifact-stage later; it lives with the other
  agent's brief (`staged_parity.md`) and needs no new vocabulary
  here. Its portability falsifier — a staged binary must contain no
  build-tree path — is the transform-stage analogue of §9's
  decl-comparison.

**Warm-mask ↔ phase 2.** The marker v2 fingerprint covers the step's
cmd + EXPECTATION FORM — so when phase 2 switches the lowering to
registry-derived firings, any expectation drift self-invalidates at
the RUN level (the byte-equal pin becomes runtime-enforced, not just
test-enforced). Phase-2 pins should pin the expectation form too, not
only the cmd strings.



## C.2 — Sequence (each step keeps the suite green)


1. [x] **Land the producer** (2026-08-17/18): `contract_registry` rows
   for c1..c8 (invariant, reads, source, fault tags, input template,
   firing derivation) + the fixture harness + the first fills (§13) +
   the matrix view (§8). Consumers untouched — `registered_checks` and
   the per-project tables keep working; 4 pins green. Still open
   inside this step: the ssot Ag.X ↔ C1..C8 reconciliation (the Ag.8
   decision) and §8's two drifts.
2. Switch `lower_expectation_agnostic` to derive firings from the
   registry; pin the derived firings equal to the hand-written tables
   (tiny first — richest case — then z3/llvm/sqlite).
3. Delete the per-project `*_contract_bindings`; the tiny oracle
   combinator (`expectation_of_entry`) consumes the registry.
4. Close the gaps inside the registry: c4/OCaml's Placeholder
   prediction, `symbol_orphan`'s build failure (a new id), statuses
   → all Wired.
5. Fault-tag sync (step 9) lands as `fault_tags` on the rows.


---

# Appendix D. Carried-over drafts awaiting placement

> These were written before this doc's outline existed. Each belongs to
> a section still under review, so it is parked here rather than
> inserted — pull from it when the destination section is worked
> through. Nothing in Appendix D is confirmed.

| draft | intended destination |
|---|---|
| D.1 the lib's path family | §5 Resolution (search/selection) + §6 Dependency closure (what is recorded vs resolved) |
| D.2 the lib's hidden dependencies | §6 Dependency closure |
| D.3 per-mechanism lifecycles (cstubs / cext / ctypes / dynlink) | §2.4, §2.5, §2.6 — as the artifact chains those sections enumerate |
| D.4 the header as a carried type oracle | §2.3 + §2.7 (a surface-correspondence projection), with the provider-side DWARF note |
| D.5 staged parity | §7 Transformation and packaging preservation |

## D.1–D.2 — The lib — symbols, paths, hidden dependencies


Symbols are the best-developed family; two others are open and
substantial.

#### 10a. Symbols (developed)

Exports vs declared API (c1), versioned symbols (c5), the soname (c4),
and the coarse `readelf -sW` shape. See the registry's §13 lib-only
cells.

#### 10b. Paths — the biggest untouched family

Every stage of a lib's life is mediated by a path mechanism, and they
differ per platform. The inventory (to be developed WITH the user's
pre-existing study, which predates this work and should be brought in
before designing cells):

| kind | Linux/ELF | macOS/Mach-O | where it bites |
|---|---|---|---|
| loader search | `LD_LIBRARY_PATH`, `/etc/ld.so.conf`, `ldconfig` cache | `DYLD_LIBRARY_PATH` (stripped by SIP for protected binaries) | which lib actually loads — a system copy can shadow the built one |
| embedded search | `DT_RPATH` / `DT_RUNPATH` (`-Wl,-rpath`, `LD_RUN_PATH`) | `LC_RPATH` + `@rpath` / `@loader_path` / `@executable_path` | a build-tree path baked into a staged artifact (the portability falsifier) |
| identity | `DT_SONAME` | `LC_ID_DYLIB` / install_name | what dependents record; must be the INSTALLED identity |
| language-side | `CAML_LD_LIBRARY_PATH` (OCaml stublibs), `PYTHONPATH`, `OCAMLPATH` | same | the binding's own artifacts, not the C lib |
| build-time discovery | `PKG_CONFIG_PATH`, `LIBRARY_PATH`, cmake prefix paths | same | which headers/libs the BUILD picked — often not the ones we think |
| tool lookup | `PATH` | `PATH` | which compiler/linker/tool ran at all |

Known trap classes to turn into agreements: `DT_RUNPATH` does NOT
apply to transitive dependencies (unlike `DT_RPATH`) — a lib that
works standalone can fail as a dependency; ordering/shadowing between
a system lib and a built one; `LD_LIBRARY_PATH` ignored for
setuid/setgid; macOS install_name that must be patched AFTER the move.

#### 10c. Hidden dependencies

Things `nm` on the lib does not reveal:

- **transitive `NEEDED`** — a dependency of a dependency that must be
  present at load;
- **`dlopen`'d plugins** — resolved by name at run time, invisible to
  static inspection (this is exactly what the ctypes/cffi mechanisms
  ARE, so the binding side has the same shape);
- **symbol interposition** — another loaded object providing the same
  symbol first (LD_PRELOAD, link order, a system copy);
- **weak symbols and default version resolution** — which definition
  wins when several exist.

These are the natural home for the interposition-shim RECORDER idea
(observe what is actually requested/resolved at load) — see the
§16.



## D.3 — Per-mechanism lifecycles


"The lib" above implicitly means the **C lib**. Once `lang × mechanism`
is in play, each mechanism has its OWN artifact chain and its own
agreements. This is the second group of tables; sketches, to be filled
the same way (from real bugs, up the ladder).

#### 11a. Cstubs (OCaml, `Static_c_abi`)

| stage | artifacts | agreements |
|---|---|---|
| build stub | `*_stubs.c` → `.o` → `lib<pkg>_stubs.a` (+ `dll<pkg>_stubs.so` for bytecode) | the stub compiles against the header (types); the archive's undefined refs ⊆ the lib's exports |
| build OCaml | `.cmi/.cmx/.cmxa/.cma` | the `.mli` surface is what the package claims; module names survive dune's wrapping convention |
| link | linkopts inside the `.cmxa` | the recorded `-L`/`-l` resolve OUTSIDE the build tree (the `$CAMLORIGIN/../..` trap) |
| install | ocamlfind layout, `META` | `directory`/`archive(native)`/`requires` describe the real layout; `dll*_stubs.so` lands in the switch's `stublibs` |
| use | `CAML_LD_LIBRARY_PATH`, RPATH | the stub `.so` that loads is THIS package's (a stale one in the switch shadows it) |

#### 11b. Cext (Python, `Static_c_abi`)

| stage | artifacts | agreements |
|---|---|---|
| build | `_native.c` → `_native.<EXT_SUFFIX>.so` | the `EXT_SUFFIX` matches the interpreter that will import it (ABI tag + version); `PyInit_<name>` exists and matches the module name |
| link | NEEDED + RPATH of the extension | the C lib is resolvable from the extension's own search path |
| package | `__init__.py`, wheel metadata | the user-facing surface is the package's, not the extension's |
| import | the load meeting | no unresolved symbol at import; the right interpreter |

#### 11c. Ctypes / Cffi (Python, `Dynamic_ffi`)

| stage | artifacts | agreements |
|---|---|---|
| (no build) | pure `.py` | — the absence of a build stage is itself the point: no build-time falsifier exists |
| load | `dlopen` by name | the declared soname/path resolves at import |
| call | `argtypes`/`restype` declarations | the DECLARED types match the C signatures — checkable only against the header: this is the prime consumer-side case for the carried type oracle (registry §12) |
| failure mode | per-call resolution | a missing symbol surfaces at FIRST CALL, not at import — so coverage of the declared API determines what is caught at all |

#### 11d. Dynlink (OCaml, `Dynamic_ffi`) — not wired

`.cmxs` plugin loading; the same shape as 3c (load-time resolution, no
build-time falsifier).



## D.4 — The header as a carried type oracle (designed, 2026-08-18)


**The gap in traditional practice.** A header is consulted exactly
once — when the binding is COMPILED. After that it is dropped: using a
binding, or wrapping it indirectly, involves no header at all. That is
fine for building, but it throws away the only artifact that carries
TYPES. A compiled component (`.so`, `.cmxa`, a cext `.so`) is
type-free: `nm` yields names and nothing else. So every stage after
the compile is checked namewise even though the type information
existed a moment earlier.

**The idea** (user, 2026-08-18): let LATER actions refer back to the
header, so a compiled component can be type-checked at stages where it
alone would be untyped — *retrofitting type information onto a compiled
component*. The header stops being a build input and becomes a
**carried oracle**: declared once, inspected once (`Scan_sources` →
`inspect_typed_header.json`), then available as an input to any
downstream cell.

**Why canary can do this cheaply.** The mechanism already exists — the
typed-header JSON is emitted early (deliberately, so c6 can cite it
even when a later build fails) and it persists in the run's output
tree. What is missing is not machinery but CELLS: contracts that read
`Typed_header` at actions other than `Build_binding`.

**The chain it enables.** Types can be followed hop by hop instead of
only at the first hop:

    header (Sf.1, typed)
      → binding stub (Sf.3, typed)        ← c6 today, at build_binding
      → user-facing surface (Sf.4, typed) ← the wrapper's own claim
      → indirect wrapper / helper / app   ← nothing checks this today

Each hop must preserve the API under the declared marshalling. The last
hop is the interesting one: tiny already declares an indirect wiring
(`a_app Via_helper` beside `a_app Direct`), so the "wrapper of a
wrapper" case has a witness ready.

**Cells this yields** (all `Inspection`, all reading `Typed_header`
plus one consumer-side typed surface):

| cell | falsifier |
|---|---|
| header × user surface @ `Probe_binding` | the user-facing signature contradicts the C signature it claims to wrap (arity, direction, ownership) |
| header × wrapper surface @ `Build_app` / `Probe_app` | an indirect wrapper re-exports the API with a changed shape |
| header × consumer usage @ app stages | the app calls the API in a way the header's types forbid |

**The provider side too — with binutils** (user, 2026-08-18). An
earlier draft called the compiled provider untypeable; that
understates the tools. `nm -D` gives names only, but the ELF file can
carry much more:

| tool / data | what it yields | precondition |
|---|---|---|
| `readelf --debug-dump=info` / `objdump --dwarf=info` | **full signatures** — `DW_TAG_subprogram` with return type + formal parameter types, struct layouts, sizes | DWARF is present (`-g`, or a separate `.debug` / debuginfo package). Often absent — use it WHEN APPLICABLE, never assume it |
| `readelf -sW` | symbol TYPE (FUNC/OBJECT) + size — a coarse shape check | always |
| mangled names + `c++filt` | parameter types encoded in the symbol itself | C++ only (C symbols carry nothing) |

So provider-side type retrofit is not impossible — it is
**provision-dependent**, which fits the rest of the matrix:

- **Built worlds**: canary compiles the lib itself, so canary controls
  the flags — building with `-g` GUARANTEES the oracle. The strongest
  form of the idea lands here: compare the header's declared
  signatures against the DWARF of the artifact actually produced. That
  catches header/source skew (the header claims `f(int)`, the object
  was compiled from a source where `f` takes two) — today only caught
  if some consumer compile happens to fail.
- **Fetched worlds**: distro releases are usually stripped, so the
  oracle needs the matching `-dbg`/`debuginfo` package declared as an
  extra. Where it is absent, the cell degrades to the coarse
  `readelf -sW` shape check and the meeting check (the link accepts
  the pairing or does not) — a weaker but still non-empty belief.

**Version skew — a future to-do.** Plainly: the header and the lib can
come from DIFFERENT provisions — headers from the source repo, the lib
from a package manager — and then they may not describe the same
build. A type check pairing them tests the consumer against the
SOURCE's API while the run uses the PACKAGE's lib, so a disagreement
can indict the wrong artifact. The cell must record which artifact's
version the oracle came from; blame then follows §10's direction rule.
Not designed further yet — a future to-do.



## D.5 — staged parity

Lives in its own doc, [`staged_parity.md`](staged_parity.md): the
build→install transform's divergence classes (identity transforms,
content selection, missing rules, relocation failure, platform
invariants, accumulation/isolation) and the four checks
(completeness / integrity / parity / isolation), including the
portability falsifier — a staged binary must contain no concrete
build-tree path. It is the same artifact-checking family one lifecycle
stage later, and is §7's principal input.
