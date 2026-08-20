# Tool-Grounded Agreement Catalogue for Cross-Language Binding Checks

## Status and Purpose

This document is an intermediate design note for consolidating the checking logic scattered across the cross-language binding project.

The project already enumerates many possible **provider × binding × consumer worlds**, including different provider provisions, binding implementations, direct applications, and applications using an additional wrapper layer. Those worlds then exercise ordinary lifecycle actions such as fetch, build, publish, fetch-from-package, install/stage, and use/probe.

The purpose of this document is narrower:

> **Systematically catalogue the agreements that can be checked around those actions, and define the principles by which those agreements are observed.**

This document is therefore about the **checking model**, not the enumeration engine and not the cache implementation.

The existing project already has a contract registry, firing rules, fixtures, and an action-centred belief matrix. The current registry is intended to make the checking belief explicit and printable rather than leaving it scattered across project-specific tables and helper code.

The work here sits one level above that implementation. Its goal is to establish a more systematic catalogue from which concrete registry rows can later be derived.

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
* [ ] **10. Mapping the catalogue back to actions and the registry**

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

# 10. Mapping Back to Actions and the Registry

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
claim
origin
relevant surfaces/artifacts
earliest observation point
tool/result used as evidence
later dynamic confirmation
applicable mechanism
applicable provision
minimal falsifier / fixture
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
