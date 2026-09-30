# Why these artifacts need checking

The agreement table, section 2 of the overview page, owns the claims,
methods, and implementation status.
This document explains the evidence behind them and what it cannot prove.
Use `canary checks --agreement NAME` for the exact comparison and examples.
[theory.md](theory.md) follows actions; this follows the artifacts those
actions connect. Registry rationale links use the numbered sections below.

## 2. Common artifact foundation

Before comparing anything, establish which artifacts were observed and where
they came from. Evidence about a different file can be internally consistent
and still answer the wrong question.

### 2.1 Resource presence and identification

A package being installed does not imply that a consumer found its files.
A file being present does not establish its origin or freshness. Paths,
hashes, package identities, and resolved commits identify observations;
world assertions check that they match the intended scenario.

### 2.2 Native provider agreements

A producer's declaration and its binary are different evidence. Compilation
and linking can succeed while the exported surface differs from what the
project promised, so declarations must be checked against the product.

A watchlist covers selected names. It cannot justify treating every other
export as an orphan: that needs an exhaustive manifest. Names also say
nothing about signatures or behaviour. Comparing header signatures with
binary debug information would recover more, but requires appropriate debug
evidence and a way to identify the corresponding header.

#### 2.2.1 Recorded dependency metadata and its limits

A binary records dependency identities, not a complete account of runtime
selection. ELF NEEDED entries and Mach-O load commands can identify direct
dependencies; lookup paths and platform rules determine which objects answer
those identities. Dynamic lookup introduces dependencies not necessarily
present in the static record. Normalized inspector fields do not make ELF
and Mach-O resolution semantics identical; see [platform.md](../platform.md).

### 2.3 Recorded requirements and actual resolution

“Requires X” and “selected this object for X” are different facts. Static
comparison can reject a pairing without executing it. Matching the recorded
names cannot establish which implementation the loader will choose.

## 3. Language bindings

A binding connects a language-facing surface to a native provider. Each
boundary preserves different evidence, so one successful observation cannot
stand in for the whole chain.

### 3.1 OCaml: interfaces and foreign calls

The OCaml compiler checks language interfaces; the foreign-call path adds
native requirements and runtime selection to that relation.

#### 3.1.1 OCaml interface and archive agreements

An `.mli` describes names users can compile against. Archive metadata records
compiled modules, whose names can differ with wrapping conventions. A watched
name being present establishes availability within that watchlist, not the
behaviour of its value. An empty watchlist establishes no coverage.

#### 3.1.2 Compiled C stubs

Undefined references in a stub archive expose what it needs from the native
provider. Export inclusion checks those names, but not types, ownership, or
the implementation ultimately selected. A static archive carries no dynamic
dependency section; the linked probe executable does. Canary can therefore
inspect that later artifact for identity and version requirements.

The signature method compares textual return and argument types for names
present on both sides. Equal spellings need not mean equal representations;
names present on only one side are skipped. Tiny's fixed binding-signature
table also limits what its evidence can demonstrate about actual source.

#### 3.1.3 Dynamic mechanisms

Loading an OCaml plugin and looking up a native library are different
operations. Runtime loading of a plugin does not erase the build-time
evidence inside it. [mechanism.md](mechanism.md) separates the modeled facts
from the unwired cases.

#### 3.1.4 User-facing wrappers

A wrapper may rename, combine, restrict, or extend native operations. Its
interface does not specify which transformations are intended. That needs
the preservation or behavioural expectation discussed in §6.3.

### 3.2 Python: imports and foreign calls

Importing a module observes a runtime surface and can execute initialization.
Distribution metadata alone does not identify the module that was imported.

#### 3.2.1 Python module agreements

Source names and imported attributes need not coincide. Attribute inspection
can answer whether a watched API is available after import; import success
alone cannot. Neither observation establishes function behaviour.

#### 3.2.2 Compiled C extensions

An extension's shared object can carry both undefined references and recorded
dependencies. Those support distinct comparisons even when read from one
file. Interpreter/module identity and the extension entry point are further
claims, not consequences of native symbol inclusion.

#### 3.2.3 ctypes and runtime foreign calls

There is no compiled binding stub to supply a requirement set. Library lookup,
function lookup, and calls are separate observations. A type-declaration
comparison would need its own inspector and mapping; a missing symbol can
surface during import or later lookup, without waiting for its first call.

#### 3.2.4 CFFI

CFFI's ABI and compiled API modes produce different evidence. Canary's coarse
dynamic classification does not describe both modes completely; develop their
artifacts separately before assigning checking sites.

#### 3.2.5 User-facing wrappers

Python wrappers can transform arguments, results, errors, and state. Attribute
presence says nothing about whether those transformations meet an expectation.

## 4. Versions and replacement

Replacing one participant can invalidate a relation witnessed by its original
build. A version label describes identity or policy, not all requirements.

### 4.1 Artifact-level versions

A soname is a lookup identity, not a unique implementation. ELF symbol-version
tags refine requirements but do not establish equivalent behaviour. Mach-O
library versions and install names encode different information; treating
them as ELF tags loses that distinction. [directions.md](../directions.md) §3
develops the versioning work.

### 4.2 External version claims

A package version need not name the version of the native library it supplies.
Solver constraints and installed pins concern package selection; the binary's
own metadata concerns the artifact. Keep those observations separate.

### 4.3 Replacement and preservation expectations

A removed export matters when a consumer needs it or a preservation policy
promises it. A diff alone is not a violation. Likewise, comparing a header
with a replacement library requires retaining the header's version and origin.

## 5. Packaging and provenance

Package managers choose and supply artifacts; successful selection does not
establish every relation between artifacts built by different suppliers.

### 5.1 OCaml packages: opam and installed layout

The chosen opam package and the findlib artifacts a consumer locates are
separate identities. A package can supply stub evidence without supplying
the user-facing interface. Conflating the two produces false missing-name
findings; installation and lookup must retain their own evidence.

### 5.2 Python distributions and environments

An installed distribution can be shadowed by another module on the import
path. Record the interpreter and imported origin before attributing its
surface to the selected package.

### 5.3 Native providers and constructible pairings

Presence-only dependency gates permit more independent pairings than bounded
gates; a package that builds or bundles its own library may expose no separate
provider choice. This constrains which experiment can be constructed, not
whether its resulting artifacts agree. Store isolation and scheduling belong
to [world ordering](../enumeration/stage5_order_worlds.md).

### 5.4 Dependencies across packaging boundaries

Keep declared, recorded, and resolved dependencies distinct: package metadata
states a requirement, a binary records a build's requirement, and a concrete
lookup selects an object. Discovery, linking, and loading can answer with
different prefixes. [directions.md](../directions.md) §1 develops that gap.

### 5.5 The ncurses counterexample

A Debian-built consumer paired with conda-forge's ncurses passed symbol,
soname, and version checks, then segfaulted. Debian's `libtinfo.so.6` supplies
the wide ABI; conda-forge splits narrow and wide implementations between
`libtinfo.so.6` and `libtinfow.so.6`. The same recorded name selected a
different implementation, alongside the wide one loaded transitively.

The [ncurses report](../../project/report_ncurses_libtinfo.md) contains the
measurements and reproducer. This is why more matching names cannot by
themselves complete the compatibility argument.

#### 5.5.1 What static evidence can establish

Exports, version namespaces, and types expose interface differences. They
do not define when two objects count as the same implementation. A denotation
comparison needs corresponding worlds' evidence and an explicit criterion;
a 2×2 enumeration supplies neither automatically.

#### 5.5.2 Attribution in the ncurses case

The same binaries ran after correcting name resolution. That supports blame
on the pairing of packaging conventions, rather than version direction alone.
It does not establish general compatibility between those releases.

#### 5.5.3 Discovery is not an identity oracle

Symbol overlap can suggest alternative implementations or static containment.
It is a discovery heuristic, not a failure rule. Two names for one object can
be harmless; two loaded implementations with separate state may not be.

### 5.6 Dependency agreements

A recorded name being provided does not establish what that name denotes or
which definition wins. The current dependency comparison has a particularly
important boundary: one modeled provider plus a fixed ambient list. It does
not traverse transitive dependencies or verify that every ambient library
exists. A second unmodeled provider can therefore look missing.

Interposition needs both a resolution trace and an allowed-target policy.
A recorder supplies facts; the comparison with that policy supplies blame.

### 5.7 Bridges between package managers

A bridge is package content that exists so one package manager can reach
another. opam's `conf-gmp` makes three statements: the binding package
depends on it (with or without a bound), its depexts name the system package
that provides GMP (`libgmp-dev` on Debian), and its build is a check that
asks the system whether GMP is there (`pkg-config --exists gmp`, falling
back to compiling against `gmp.h`). None of the three is re-established per
world. canary installs with `--assume-depexts`, and opam runs a conf
package's check only when it first installs the package.

A run records all three where a bridge is modeled (only zarith's is):
the package's depends, the depext mapping, and the check's verdict in this
world, beside what pkg-config found and which package ships the capability
file. The claims that read that record are `gate_admits_the_world`,
`declared_gate_matches_package`, `gate_bounds_the_library` and
`depext_names_the_provided_package`. A version bound on a bridge often
bounds only the bridge's own packaging, which is what the third one is
about. The capability file the check reads is not a bridge: it belongs to
the package that ships it. It is why `discovery_matches_link` sits with
them.

`gate_admits_the_world` is the first of them checked. Its evidence is
unusual: not a projection the rule left behind, but the rule run again —
canary dispatches the bridge's own query in the world and reads the
answer. That makes its limit sharp. A predicate may fall back when its
query fails, as conf-gmp's compiles against `gmp.h`, and canary runs only
the query; so a query that holds decides the claim, and one that fails
decides it only for a predicate with no fallback. The rest is recorded as
unavailable, naming the fallback, because the evidence that would decide
it was not produced.

## 6. Deployment and execution

Deployment can change paths and contents; execution chooses resources and
exercises behaviour. These introduce observations beyond the build's evidence.

### 6.1 Staging and relocation

Preservation compares two copies of one artifact under allowed transformations.
Moving files and rewriting lookup paths can be legitimate. Matching export
counts cannot detect substitution of one exported name for another, and a
library-only comparison cannot detect omitted headers or data files.

A build path in runtime lookup can defeat relocation; the same path in debug
information is not itself a runtime dependency. State the deployment policy
before treating every embedded path as a failure. The broader design is
[staged_parity.md](../staged_parity.md).

### 6.2 Resolution and selection

Record which header, library, language package, or symbol definition a lookup
selected. Presence and recorded identity are inputs to that question, not
answers. Search-path precedence and environment can change the result.

#### 6.2.1 Further dependency evidence

Transitive dependencies, plugins, and weak/default symbol selection require
more than a direct dependency list. Static records expose possible relations;
runtime recording exposes the exercised resolutions.

### 6.3 Behavioural expectations and observations

Structural checks leave questions about values, errors, ownership, callbacks,
and state. An execution can answer only for its exercised cases and oracle.

#### 6.3.1 User API and repacking

“Preserves the API” needs a definition of permitted renaming, merging, and
omission. A binding intentionally exposing a subset is not necessarily wrong.
The provisional repacking claims cannot be settled by name equality, and
composing their verdicts cannot compensate for an unspecified relation.

#### 6.3.2 Behavioural observations

A probe's assertions supply expectations for its particular inputs. A
cross-API comparison uses a different oracle: the corresponding direct C
operation in the same world. It still needs a mapping of operations, arguments,
and results. Reordering arguments is wrong only relative to that mapping.
Stateful behaviour needs sequences of calls, not just isolated invocations.
The generation design is in [directions.md](../directions.md) §2.

#### 6.3.3 Instrumentation

A fake provider can test a consumer against a declared requirement. A failure
may implicate the consumer, the requirement, or the fake's fidelity. Retain
that distinction when translating instrumentation into a verdict.

## 7. Outside this walk

Current structural observations do not establish marshalling, lifetime,
ownership, GC rooting, or callback safety. New languages and formats may
need new evidence rather than another instance of an existing comparator.
The per-action theory's separate limits—set and cross-world properties—are
in [theory.md](theory.md) §7.
