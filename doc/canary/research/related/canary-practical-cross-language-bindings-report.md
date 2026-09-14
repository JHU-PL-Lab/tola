# Beyond ABI Checking: Practical Correctness of Cross-Language Bindings

**Practice-side related-work report for Canary**  
**Date:** 2026-09-03

## Executive summary

A survey of practical tooling changes the most defensible statement of the Canary problem.

There is already substantial prior work on **checking a concrete artifact once the artifacts to compare have been selected**. Examples include Libabigail's `abicompat`, `abidiff`, `abi3audit`, `auditwheel`, distribution QA such as Debian's symbols machinery and Fedora/openSUSE ABI checks, and the new 2026 `abicheck` tool. There is also a long line of work on **language-specific FFI correctness**, including Jinn and TurboJet for JNI/Python-C constraints, static analyses of the Python/C API, and FFIChecker for Rust/C memory-management errors.

The remaining practical gap is broader and more compositional:

> **Cross-language software is constructed by several partially independent languages, package managers, build systems, generators, linkers, installers, and runtime resolvers. Existing tools check many local properties, but there is little support for systematically constructing the realized cross-ecosystem worlds that users actually obtain, applying the right checks to the right artifacts, and attributing a failure back to the declaration, provider choice, toolchain step, or cross-language agreement that produced it.**

This report therefore recommends centering Canary around three operations:

\[
\boxed{\text{Enumerate}} \rightarrow
\boxed{\text{Realize}} \rightarrow
\boxed{\text{Attribute}}
\]

with existing ABI/API/FFI tools reused as **agreement-checking backends** where appropriate.

The strongest research opportunities appear to be:

1. **Cross-language agreement checking** beyond binary ABI: types, layouts, ownership, lifetime, exceptions, callbacks, runtime rules, and generated declarations.
2. **Cross-package-manager interaction**, especially language-package-manager ↔ system-package-manager relations.
3. **Practical world construction** across provenance, versions, build modes, headers, libraries, and runtime resolution.
4. **Agreement-aware localization and blame**, based on the derivation of a realized world rather than a single build/test exit code.
5. **Closing the loop from resolution to realization and back**: use observed incompatibilities to refine cross-ecosystem dependency constraints.

Cross-ecosystem version resolution itself is now much less open than it was a few years ago. HyperRes (2025) and *Package Managers à la Carte* / the Package Calculus (ICFP 2026) directly address dependency resolution across package ecosystems. Their separation of **resolution** from **deployment/build realization**, however, leaves a useful interface for Canary.

---

## 1. Scope and revised research question

The original practical question can be phrased as:

> Is this language binding compatible with this native library as the user will actually obtain both?

Taken literally, this is too broad as a novelty claim. Tools such as Libabigail's `abicompat` already check whether a concrete application remains compatible with a replacement shared library, and `abicheck` now accepts packaged artifacts and FFI consumers.

A more precise research question is:

> **Given a cross-language binding, what materially distinct deployment worlds can real package managers and toolchains construct for it, which cross-language agreements hold in each world, and which declaration or transition is responsible when an agreement fails?**

This formulation moves the center of gravity from a single checker to the composition of several independently reasonable systems.

A useful abstraction is:

\[
W =
(P_B, V_B, P_L, V_L, T, H, G, I, R, E, \ldots)
\]

where, for example:

- \(P_B\): binding provenance;
- \(V_B\): binding version;
- \(P_L\): native-library provenance;
- \(V_L\): native-library version;
- \(T\): compiler/build toolchain;
- \(H\): headers or interface description observed during build;
- \(G\): generated binding/stub state;
- \(I\): installed artifacts and package transforms;
- \(R\): runtime resolution result;
- \(E\): relevant environment state.

Then Canary can be described by:

\[
\operatorname{Realize}(W) \rightarrow A
\]

where \(A\) is a set of concrete artifacts plus provenance/derivation evidence, followed by:

\[
\operatorname{Check}(A,\Gamma)
\rightarrow
\{\text{agreement verdicts}\}
\]

for a set of agreements \(\Gamma\), and finally:

\[
\operatorname{Attribute}(W,A,\text{violations})
\rightarrow
\text{responsible declarations / transitions / components}.
\]

This scope deliberately keeps detailed loader and name-resolution semantics behind interfaces when possible. The practical concern is which artifacts were actually selected and how that choice interacts with the binding.

---

## 2. Why existing ABI checking is necessary but insufficient

Several mature tools already establish that concrete binary compatibility can be checked directly.

### Libabigail `abicompat`

Libabigail's `abicompat` explicitly checks whether an application linked against one version of a shared library remains ABI-compatible with a subsequent version, and reports the incompatibility when it finds one.

Source: [Libabigail `abicompat` documentation](https://snapshots.sourceware.org/libabigail/html-doc/2025-05-05_20-47_1746478021/manuals/abicompat.html).

This is strong prior art for **consumer-relative compatibility**:

\[
\text{consumer} + L_{\text{old}} + L_{\text{new}}
\rightarrow
\text{compatibility verdict}.
\]

### `abicheck`

The 2026 `abicheck` project goes further. Its documentation explicitly targets distribution/package-index/binding-author use cases. It can treat RPM, Debian, conda, wheel, tarball, or directory artifacts as operands and can scope a verdict to a concrete consumer. Its FFI documentation discusses Rust `extern "C"`, Go cgo, and Python `ctypes` as consumers whose declarations may be copied from a C interface.

Source: [`abicheck`: Packages and Consumers](https://abicheck.github.io/abicheck/learn/packages-and-consumers/).

This significantly reduces the novelty of building another standalone ABI comparator. It also suggests a useful design principle for Canary:

> **Checker implementations should be replaceable backends. Canary's contribution should not depend on reimplementing every existing ABI/API analysis.**

The more stable distinction is that these tools generally receive **already-selected artifacts**. They do not, by themselves, answer why those artifacts coexist on a user's system, which alternative provisioning paths should have been explored, or which package declaration should be blamed for constructing an incompatible world.

---

## 3. Cross-language binding correctness is larger than ABI

The existence of mature ABI tooling does not remove the broader FFI problem. A binding must satisfy agreements that are only partially visible in ELF, debug information, or headers.

A useful taxonomy is:

```text
Cross-language binding agreements
├── naming / symbol agreement
├── type agreement
├── representation / layout agreement
├── calling-convention agreement
├── ownership agreement
├── lifetime agreement
├── allocation / deallocation pairing
├── nullability agreement
├── error / exception translation
├── callback and reentrancy agreement
├── threading / runtime-state agreement
├── generated-declaration correspondence
├── version / feature agreement
└── packaging / provenance agreement
```

Different language pairs expose different subsets.

### Python ↔ C

Typical Python/C contracts include:

- reference ownership and reference-counting discipline;
- exception indicator discipline;
- GIL requirements;
- borrowed-reference lifetime;
- object layout/API stability;
- initialization/finalization protocol;
- buffer/string conversion;
- allocator pairing;
- Stable ABI / Limited API promises.

Hu et al. performed an empirical study of Python/C API evolution and bug patterns and reported nine recurring bug-pattern classes. Their static-analysis tooling found 48 bugs in Pillow, 19 previously undiscovered.

Source: Hu et al., *An empirical study of the Python/C API on evolution and bug patterns*, Journal of Software: Evolution and Process, 2023. [DOI 10.1002/smr.2507](https://doi.org/10.1002/smr.2507).

A 2026 community-scale analysis further reported hundreds of confirmed bugs across dozens of mature Python C extensions, including problems in exception handling, reference management, and GIL discipline. This is useful empirical motivation, although the primary evidence is currently a Python.org technical discussion rather than a peer-reviewed paper.

Source: [Systematically finding bugs in Python C extensions (575+ confirmed so far)](https://discuss.python.org/t/systematically-finding-bugs-in-python-c-extensions-575-confirmed-so-far/106875).

`abi3audit` provides another instructive example. The Python wheel ecosystem can claim that an extension uses the Stable ABI through an `abi3` tag, while ordinary installation does not itself enforce that the binary satisfies the claim. `abi3audit` checks the binary artifact against that packaging promise.

Source: [PyPA `abi3audit`](https://github.com/pypa/abi3audit).

This is exactly the kind of pattern Canary can generalize:

\[
\text{declared promise}
\quad\overset{\text{check}}\longleftrightarrow\quad
\text{artifact evidence}.
\]

### OCaml ↔ C

OCaml/C bindings add a different family of obligations:

- OCaml value representation;
- GC rooting;
- callbacks into OCaml;
- custom blocks and finalizers;
- blocking sections and runtime lock discipline;
- C pointer lifetime;
- generated C stubs versus dynamic FFI declarations;
- structure/constant layout correspondence.

`ocaml-ctypes` already provides mechanisms to reduce some representation errors, including generated stubs and mechanisms for determining C structure layouts. This is useful prior art for **constructing reliable individual agreements**, but it does not construct or validate arbitrary cross-package-manager deployment worlds.

Source: [`ocaml-ctypes`](https://github.com/yallop/ocaml-ctypes).

### JNI, Rust/C, and broader FFI work

The general observation that composing languages creates its own rules has substantial prior work.

**Jinn** synthesizes dynamic bug detectors from state machines describing FFI constraints and targets thousands of JNI and Python/C FFI rules.

Source: Lee et al., *Jinn: Synthesizing Dynamic Bug Detectors for Foreign Language Interfaces*, PLDI 2010. [DOI 10.1145/1806596.1806601](https://doi.org/10.1145/1806596.1806601).

**TurboJet** performs exception analysis across Java and native code, checking inconsistent exception declarations and mishandled JNI exceptions.

Source: Li and Tan, *Exception analysis in the Java Native Interface*, Science of Computer Programming 89, 2014. [DOI 10.1016/j.scico.2014.01.018](https://doi.org/10.1016/j.scico.2014.01.018).

**FFIChecker** statically analyzes Rust/C FFI memory-management behavior. Its evaluation analyzed 987 Rust packages and reported 34 bugs across 12 packages.

Source: Li et al., *Detecting Cross-language Memory Management Issues in Rust*, ESORICS 2022. [DOI 10.1007/978-3-031-17143-7_33](https://doi.org/10.1007/978-3-031-17143-7_33).

These works rule out the claim that cross-language FFI checking is unexplored. The remaining gap is better expressed as:

> Existing FFI analyses are largely **language-pair- and invariant-specific**. There is room for a practical framework in which heterogeneous checks are represented as named agreements and applied to the artifacts of systematically realized package/toolchain worlds.

---

## 4. Cross-package-manager interaction is still immature

A major source of practical binding failures is that the language package and the native library may belong to different dependency universes.

### OCaml/opam and system package managers

For an OCaml binding:

```text
opam package
   |
   +-- OCaml dependencies resolved by opam
   |
   +-- depexts
         |
         +-- apt / dnf / pacman / brew / ...
```

The opam manual defines `depexts` as dependencies on packages external to the opam ecosystem. opam uses knowledge of the host system package manager to determine availability and install those packages.

Source: [opam package format manual: `depexts`](https://opam.ocaml.org/doc/Manual.html).

This establishes a bridge of the form:

\[
\text{opam package}
\rightarrow
\text{system-package identifier}.
\]

But that bridge does not by itself encode or verify the complete relation:

\[
\text{binding version}
\leftrightarrow
\text{native API/ABI/behavioral range}.
\]

Nor does it guarantee that:

\[
\text{header provider used at build time}
=
\text{DSO provider selected at runtime}.
\]

This creates a characteristic failure mode where every local component reports success:

```text
opam solver:        success
system PM:          success
configure/pkgconf:  success
compiler:           success
linker:             success
loader:             success

binding/library agreement: false
```

### Python external dependencies: PEP 725 and PEP 804

Python packaging currently provides unusually strong evidence that this layer remains an active systems problem.

**PEP 725**, *Specifying external dependencies in pyproject.toml*, proposes standardized build/host/runtime metadata for dependencies outside the Python package ecosystem. As of 2026-09-03 its status is still **Draft**.

Source: [PEP 725](https://peps.python.org/pep-0725/).

The PEP explicitly states that it does not specify how external dependencies should be used, and it does not itself define package-name mappings into other ecosystems.

That mapping problem is delegated to **PEP 804**, *An external dependency registry and name mapping mechanism*, also **Draft** as of 2026-09-03.

Source: [PEP 804](https://peps.python.org/pep-0804/).

PEP 804 is particularly relevant because its examples map a generic dependency such as zlib into ecosystem-specific package identifiers for Debian/Ubuntu, Fedora, Arch, Homebrew, and conda-forge, and its reference tooling can generate installation commands for the selected ecosystem.

This is direct evidence that even basic cross-ecosystem questions such as:

\[
\text{logical native dependency}
\rightarrow
\text{package(s) providing it in ecosystem } E
\]

are only now receiving standard metadata and tooling in Python.

### Implication for Canary

Canary should treat the package-manager bridge as an observable component rather than a mere installation convenience.

A realized edge can carry evidence such as:

```text
binding package:          foo-python 3.2
declared native dep:      dep:generic/libfoo >= 4
mapping selected:         ubuntu+24.04
mapped packages:          libfoo4, libfoo-dev
actual header provider:   libfoo-dev 4.8
actual runtime provider:  /opt/conda/lib/libfoo.so.5
```

The failure may lie in any of these transitions even when each package manager independently behaved correctly.

---

## 5. Cross-ecosystem version resolution now has strong prior art

Cross-language or cross-package-manager resolution should not be claimed as an empty research area.

### HyperRes

Gibb et al. introduced **HyperRes** in 2025, a hypergraph-based formal system for versioned dependency resolution across package ecosystems. It translates metadata from many package managers and supports solving across ecosystem boundaries while specializing the solution to a deployment environment.

Source: Gibb et al., *Solving Package Management via Hypergraph Dependency Resolution*, 2025. [arXiv:2506.10803](https://arxiv.org/abs/2506.10803).

### Package Managers à la Carte / Package Calculus

The follow-up **Package Managers à la Carte: A Formal Model of Dependency Resolution** was published at ICFP 2026. It introduces the Package Calculus, a common core for diverse dependency-resolution semantics, supports translation between package managers, and enables cross-ecosystem resolution.

Source: Gibb et al., *Package Managers à la Carte: A Formal Model of Dependency Resolution*, PACMPL 10 (ICFP), 2026. [DOI 10.1145/3828699](https://doi.org/10.1145/3828699).

This work is especially important because it draws a useful boundary for Canary. The paper explicitly separates **resolution** from **deployment**:

- resolution chooses packages satisfying dependency constraints;
- deployment builds/unpacks/places them and is orthogonal to the resolution formalism;
- the formalism is deliberately independent of underlying build systems;
- the paper identifies composable build-system/package-manager theory as future work.

This gives a clean interface:

\[
\text{Package Calculus / HyperRes}
:
\text{dependency declarations}
\rightarrow
\text{resolution}
\]

followed by a Canary-like layer:

\[
\text{Canary}
:
\text{resolution + provisioning policy}
\rightarrow
\text{realized artifacts}
\rightarrow
\text{observed agreements}.
\]

A particularly promising extension is a feedback loop:

\[
\boxed{
\text{resolve}
\rightarrow
\text{realize}
\rightarrow
\text{check}
\rightarrow
\text{refine constraints}
}
\]

For example, package metadata may initially state:

```text
libfoo >= 4
```

while practical checking reveals:

```text
binding B:
  passes 4.8 ... 4.12
  fails 4.13+
```

The observed result can be turned into a candidate dependency repair:

```text
libfoo >= 4.8, < 4.13
```

This is a different research problem from inventing another solver.

---

## 6. The central gap: practical world construction

The most distinctive practical problem may be deciding **which configurations are worth realizing**.

A Python native extension can depend on:

```text
Python version
× extension version
× wheel / sdist / distro package
× build backend
× compiler / linker
× native headers
× native library provider
    bundled
    apt/dnf
    conda
    Homebrew
    source
    staged prefix
× native library version
× wheel repair/vendor transform
× runtime loader outcome
```

An OCaml binding can depend on:

```text
OCaml compiler
× opam switch
× binding version
× ctypes / generated-stub mode
× conf-* package results
× depext mapping
× pkg-config result
× C headers
× compile-time DSO
× installed artifacts
× runtime DSO
```

Traditional CI frequently enumerates only a small projection:

```text
OS × language version × architecture
```

or:

```text
ecosystem transition × reverse dependents
```

Those matrices are useful, but they do not necessarily vary the dimensions most likely to expose cross-ecosystem binding errors.

### Provenance as an experimental variable

A key proposal is to treat provenance itself as a first-class test axis:

\[
P_L \in
\{
\text{apt},
\text{conda},
\text{source},
\text{staged},
\text{bundled}
\}.
\]

The interesting question is not only whether `libfoo 4.12` works. It is whether these materially different realizations of "libfoo 4.12" expose the same contracts to the binding.

### Avoiding a naive Cartesian explosion

The full cross product is usually too large:

\[
|W|
=
\prod_i |D_i|.
\]

Therefore world construction itself can become a research problem:

> **Which provisioning differences are observationally distinct with respect to the agreements a binding can observe?**

Let \(\Gamma\) be a set of agreements. Two worlds may be considered equivalent for a particular test objective if they expose the same relevant observations:

\[
W_1 \equiv_\Gamma W_2
\quad\text{iff}\quad
\operatorname{Obs}_\Gamma(W_1)
=
\operatorname{Obs}_\Gamma(W_2).
\]

This suggests several practical reductions:

- collapse worlds with identical header/API surfaces;
- collapse worlds with identical relevant binary export/type evidence;
- preserve worlds with different provenance even at the same version when packaging transforms differ;
- select representatives by agreement coverage;
- add deliberately mismatched worlds to test whether declared constraints are actually protective;
- prioritize boundaries where a package mapping, SONAME, generated declaration, feature flag, or toolchain path changes.

This is related to combinatorial testing, but the axes and equivalence relation are derived from **package/toolchain observations**, not manually supplied feature flags alone.

---

## 7. Realization should preserve the derivation, not only the final artifact

A practical software stack is produced by a pipeline such as:

\[
\begin{aligned}
&\text{package declaration}\\
\rightarrow&\text{dependency resolution}\\
\rightarrow&\text{external-dependency mapping}\\
\rightarrow&\text{provider selection}\\
\rightarrow&\text{build-system detection}\\
\rightarrow&\text{header selection}\\
\rightarrow&\text{binding/stub generation}\\
\rightarrow&\text{compile}\\
\rightarrow&\text{link}\\
\rightarrow&\text{package transform}\\
\rightarrow&\text{install}\\
\rightarrow&\text{runtime artifact selection}.
\end{aligned}
\]

Most compatibility tools inspect some artifact near the end.

For blame and debugging, Canary should retain:

\[
\boxed{\text{artifact} + \text{derivation evidence}}.
\]

Example evidence records might include:

```yaml
binding:
  ecosystem: opam
  package: z3
  version: 4.12.4
  source_hash: ...

native_dependency:
  logical_name: z3
  declared_by: depext
  mapped_ecosystem: debian
  mapped_package: libz3-dev
  resolved_version: 4.8.12

build:
  pkg_config: /usr/lib/pkgconfig/z3.pc
  header: /usr/include/z3.h
  linked_library: /usr/lib/x86_64-linux-gnu/libz3.so

runtime:
  resolved_library: /opt/conda/lib/libz3.so
```

The exact schema is an implementation question. The important research point is that the path from declaration to runtime artifact remains available for later attribution.

---

## 8. Agreement-aware localization and blame

A build failure is often a poor oracle:

```text
exit 1
```

A runtime crash is even further from the cause.

Instead, a failure can be represented as a violated agreement with its evidence chain.

### Example 1: representation mismatch

```text
Claim:
  binding B supports libfoo >= 2

Declared by:
  package metadata

World:
  B = 3.1 from opam
  libfoo = 2.4 from apt

Binding expectation:
  sizeof(foo_context) = 72

Observed library/header world:
  sizeof(foo_context) = 80

Violation:
  representation agreement

Candidate blame:
  binding compatibility declaration is too broad
```

### Example 2: build/runtime provider mismatch

```text
Claim:
  the library observed while building the binding
  corresponds to the library used at runtime

Build evidence:
  pkg-config -> /usr/lib/libfoo.so

Runtime evidence:
  loader result -> /opt/conda/lib/libfoo.so

Violation:
  artifact-correspondence agreement

Candidate blame:
  environment/provisioning interaction
```

### Example 3: copied FFI declaration

```text
Claim:
  ctypes declaration matches the selected native API

Binding evidence:
  foo(int, char *)

Header evidence:
  foo(size_t, const char *)

Runtime symbol:
  present

Violation:
  cross-language type/signature agreement

Candidate blame:
  stale binding declaration
```

The important abstraction is:

\[
\text{claim}
\rightarrow
\text{issuer}
\rightarrow
\text{evidence}
\rightarrow
\text{realization}
\rightarrow
\text{falsifier}.
\]

This leads to **blame by violated agreement**.

Possible blame targets include:

- binding author;
- language-package maintainer;
- system-package mapping;
- version constraint;
- build-system detection;
- generated binding;
- packaging transform;
- environment contamination;
- runtime provider selection;
- native library compatibility promise.

The initial goal need not be probabilistic root-cause diagnosis. A smaller and more defensible objective is:

> Report the smallest observed declaration/transition whose recorded claim is falsified by the realized artifacts.

That output is substantially more useful than "ABI incompatible" or "test failed."

---

## 9. Relationship to existing checkers

Canary should explicitly embrace existing tools as components.

A possible checker architecture is:

```text
Agreement
├── exported symbol
│   └── ELF inspection / nm / readelf / abicheck
├── consumer-relative ABI
│   └── abicompat / abicheck
├── Python Stable ABI promise
│   └── abi3audit
├── wheel external-library policy
│   └── auditwheel
├── structure/layout correspondence
│   └── compiler probe / ctypes stub generation / DWARF tool
├── Python/C runtime protocol
│   └── specialized static/dynamic analysis
├── Rust/C ownership
│   └── FFIChecker-like analysis
├── package mapping
│   └── opam depext / PEP 804 data
└── provenance correspondence
    └── Canary-specific evidence comparison
```

The research contribution is therefore compatible with an extensible checker interface:

\[
\operatorname{checker}_i
:
(A,E_i)
\rightarrow
\{\text{pass},\text{fail},\text{unknown}\} + \text{evidence}.
\]

`unknown` matters. A missing debug-information channel, unavailable header, or unobservable ownership property should not silently become `pass`.

---

## 10. A revised comparison with ecosystem rebuild infrastructure

The earlier distinction "ecosystem rebuild infrastructure trusts build/test exit status; Canary uses artifact-level checks" is too strong. Modern ecosystems already embed artifact-level checks.

A safer comparison is:

| Dimension | Ecosystem rebuild / QA infrastructure | Canary target |
|---|---|---|
| Unit of exploration | Usually one package ecosystem or curated package universe | Cross-ecosystem realized world |
| Main variation | Ecosystem versions, transitions, platforms, reverse dependents | Provenance + version + toolchain + binding/native combinations |
| External dependencies | Often normalized or mapped into the ecosystem's own package model | Heterogeneous providers remain first-class |
| Oracle | Builds/tests plus some artifact-level checks | Composable named agreements; existing checkers may be reused |
| Consumer awareness | Often reverse-dependency or application-aware | Binding-specific contract and artifact correspondence |
| Provenance | Often recorded, but usually within one packaging model | Deliberate cross-provider experimental axis |
| Diagnostic target | Package/rebuild/linkage/ABI failure | Violated agreement plus responsible declaration/transition |
| Resolution relation | Uses ecosystem resolver | May consume cross-ecosystem resolution and validate its realization |

This makes the novelty less vulnerable to obvious counterexamples such as `rpminspect`, Homebrew linkage checks, `auditwheel`, Debian `adequate`, or `abicompat`.

---

## 11. Research questions

The following questions appear sufficiently distinct from a standalone ABI checker.

### RQ1. Agreement model

**Can practical cross-language binding correctness be represented as a composable set of named agreements with explicit evidence and falsifiers?**

Examples:

- name/symbol;
- signature/type;
- representation/layout;
- ownership/lifetime;
- exception/error;
- callback/threading;
- version/feature;
- artifact correspondence;
- package/provenance.

Evaluation:

- coverage of real OCaml/Python binding bugs;
- proportion expressible by one or more agreements;
- precision of reported violations;
- usefulness of `unknown` versus `pass/fail`.

### RQ2. World discovery and reduction

**Can the materially distinct deployment worlds of a binding be derived automatically from package metadata, build behavior, and provisioning choices without enumerating the full Cartesian product?**

Evaluation:

- discovered worlds versus manually curated worlds;
- reduction ratio;
- bug coverage retained after reduction;
- ability to include deliberately adversarial/mismatched worlds.

### RQ3. Cross-ecosystem interaction

**How often do language-package-manager declarations fail to capture the constraints imposed by externally provisioned native libraries?**

Possible comparison:

- opam/depext bindings;
- Python packages with system/native dependencies;
- PyPI wheel versus sdist;
- conda and distro repackaging.

### RQ4. Localization and blame

**Does preserving the derivation of a realized world allow failures to be localized to a smaller and more actionable cause than build/test failure or ABI differencing alone?**

Metrics:

- localization accuracy against known fixes;
- size of candidate blame set;
- distance from reported cause to fixing commit/metadata change;
- maintainer usefulness.

### RQ5. Resolution feedback

**Can observed compatibility failures be translated into dependency constraints that improve future cross-ecosystem resolutions?**

Pipeline:

\[
\text{declared constraints}
\rightarrow
\text{resolution}
\rightarrow
\text{realization}
\rightarrow
\text{counterexample}
\rightarrow
\text{constraint refinement}.
\]

---

## 12. Suggested empirical evaluation

OCaml and Python are a useful pair because they expose different packaging and FFI styles while both interact heavily with native libraries.

### Corpus

Construct a corpus with:

1. OCaml/opam C bindings using:
   - `ctypes`;
   - generated C stubs;
   - `conf-*` packages;
   - `depexts`;
   - pkg-config/CMake/autoconf discovery.

2. Python bindings using:
   - CPython C API;
   - CFFI;
   - ctypes;
   - pybind11;
   - Cython;
   - wheels with vendored libraries;
   - wheels with system-library dependencies;
   - sdists that build against host libraries.

### Sources of failures

Prefer bugs with a known repair so blame can be evaluated:

- issue trackers;
- version-bound fixes;
- package metadata changes;
- CI failures;
- wheel repair changes;
- header/library mismatch bugs;
- runtime provider conflicts;
- stale copied declarations;
- missing or over-broad native dependency constraints.

### World axes

For each case, derive a bounded matrix:

```text
binding source:
  language PM / distro repackaging / source

native source:
  distro / conda / source / bundled / staged

version relation:
  intended / boundary / deliberately mismatched

build observation:
  header provider / pkg-config provider / CMake provider

runtime observation:
  same provider / different visible provider
```

### Baselines

Compare against:

- ordinary upstream CI;
- language package-manager solver result;
- system package-manager installability;
- build/test exit status;
- `abicompat` / `abicheck` where applicable;
- ecosystem-native artifact QA where applicable.

### Primary outcomes

1. bugs detected that upstream CI misses;
2. additional worlds needed to expose each bug;
3. agreements that first falsify each bug;
4. blame/localization accuracy;
5. world-reduction efficiency;
6. fraction of checks delegated to existing tools;
7. fraction requiring new cross-language or provenance-specific checkers.

---

## 13. Threats to novelty

Several claims should be avoided.

### Avoid: "No tool checks a consumer against a library"

Counterexamples: `abicompat`, `abicheck`.

### Avoid: "FFI correctness has not been systematically checked"

Counterexamples: Jinn, TurboJet, Python/C static analyses, FFIChecker.

### Avoid: "Package ecosystems only trust build/test exit status"

Counterexamples include numerous artifact-level QA systems.

### Avoid: "Cross-ecosystem dependency resolution is missing"

Counterexamples: HyperRes and Package Managers à la Carte.

### Stronger claim

A more defensible claim is:

> **Existing systems provide many pieces of cross-language reliability: dependency solvers, ecosystem mappings, FFI analyses, ABI checkers, and rebuild infrastructure. We find no existing system that systematically connects these pieces by constructing cross-ecosystem provisioning worlds for a binding and its native dependencies, preserving how each world was realized, applying composable agreement checks to the resulting artifacts, and attributing violations back to the declaration or transition that produced them.**

This claim should still be treated as empirical and revisited as the implementation survey expands.

---

## 14. Three likely reviewer objections

### Objection 1: "Isn't this `abicheck`?"

**Answer.** `abicheck` is very close to the artifact-checking layer and should be treated as strong prior art or a backend. The proposed distinction is world construction and derivation-aware attribution: determining which cross-ecosystem artifacts should be compared, realizing those combinations, and tying a failure back to packaging/toolchain decisions.

If Canary only compares already-selected binaries, this objection is strong enough to threaten novelty.

### Objection 2: "Isn't this Package Managers à la Carte / HyperRes?"

**Answer.** Those systems directly address cross-ecosystem dependency resolution. The Package Calculus explicitly separates resolution from deployment/build-system realization. Canary can begin from a resolution and test whether the concrete artifacts produced by heterogeneous deployment steps satisfy the agreements that the resolution metadata only approximates.

The strongest extension is the feedback loop from realized counterexamples back to dependency constraints.

### Objection 3: "FFI checkers already detect cross-language bugs"

**Answer.** Correct. Jinn, TurboJet, FFIChecker, and Python/C analyses show that many individual FFI protocols can be checked. Canary should not claim a new general theory of FFI bugs. Its contribution can instead be a **common practical agreement interface** that runs such checks in systematically constructed deployment worlds and combines their evidence with package/toolchain provenance for blame.

---

## 15. Recommended project decomposition

A clean implementation/research decomposition is:

### Layer A — World model

Represents candidate deployment worlds:

```text
logical component
× version
× provenance
× build/toolchain choices
× environment
```

### Layer B — Realizers

Adapters for:

- opam;
- apt/dpkg;
- pip/PyPI;
- conda;
- source build;
- staged prefix;
- eventually Homebrew/RPM ecosystems.

A realizer records the derivation, not only success/failure.

### Layer C — Artifact record

A normalized record of:

- concrete files;
- package identities;
- hashes;
- headers;
- linked objects;
- runtime-selected objects;
- generated bindings;
- package metadata;
- environment/tool outputs.

### Layer D — Agreement checkers

Small checkers with:

```text
claim
issuer
required evidence
falsifier
verdict
diagnostic
```

They may call existing tools.

### Layer E — Attribution

Maps a violated agreement back through the derivation graph.

### Layer F — Experiment engine

Selects/reduces worlds, injects mismatches, compares outcomes, and produces a report.

This architecture keeps detailed resolution mechanisms external where possible while still recording the resolved outcome as evidence.

---

## 16. A possible paper-level thesis

A concise thesis is:

> **The practical correctness problem for language bindings is compositional. Individual languages, package managers, build systems, and ABI tools each enforce local invariants, yet users execute artifacts produced by their interaction. We model these interactions as realized worlds, systematically vary cross-ecosystem provenance, check named cross-language agreements on the resulting artifacts, and use the world's derivation to localize violated assumptions.**

An even shorter positioning statement is:

> **Package managers decide what may coexist; compatibility tools inspect what they are given. Canary connects the two across ecosystems by constructing what users can actually get, checking the resulting binding/library agreements, and explaining which assumption failed.**

---

## 17. Conceptual summary

The project becomes easier to distinguish if the layers are kept separate:

```text
Dependency declarations
        |
        v
Cross-ecosystem resolution
(HyperRes / Package Calculus territory)
        |
        v
Provisioning choices
        |
        v
World construction
        |
        v
Build / package / install / runtime realization
        |
        v
Concrete artifacts + derivation
        |
        +-------------------------------+
        |                               |
        v                               v
Existing checkers                 New binding-specific
(abicompat, abicheck,             agreement checks
abi3audit, auditwheel, ...)
        |                               |
        +---------------+---------------+
                        |
                        v
               Agreement verdicts
                        |
                        v
               Localization / blame
                        |
                        v
         Optional constraint refinement
                        |
                        +----> resolver
```

The central research object is therefore not a binary ABI and not a package-manager solver. It is the **realized cross-language world** and the chain of assumptions that makes that world acceptable.

---

## References

1. Libabigail Project. **`abicompat` documentation.**  
   https://snapshots.sourceware.org/libabigail/html-doc/2025-05-05_20-47_1746478021/manuals/abicompat.html

2. **abicheck — Packages and Consumers.**  
   https://abicheck.github.io/abicheck/learn/packages-and-consumers/

3. PyPA. **abi3audit: Scans Python packages for abi3 violations and inconsistencies.**  
   https://github.com/pypa/abi3audit

4. Hu et al. **An empirical study of the Python/C API on evolution and bug patterns.** *Journal of Software: Evolution and Process*, 2023.  
   https://doi.org/10.1002/smr.2507

5. Diniz, D. **Systematically finding bugs in Python C extensions (575+ confirmed so far).** Python.org Discussions, 2026.  
   https://discuss.python.org/t/systematically-finding-bugs-in-python-c-extensions-575-confirmed-so-far/106875

6. Lee et al. **Jinn: Synthesizing Dynamic Bug Detectors for Foreign Language Interfaces.** PLDI 2010.  
   https://doi.org/10.1145/1806596.1806601

7. Li, S.; Tan, G. **Exception analysis in the Java Native Interface.** *Science of Computer Programming* 89, 2014.  
   https://doi.org/10.1016/j.scico.2014.01.018

8. Li et al. **Detecting Cross-language Memory Management Issues in Rust.** ESORICS 2022.  
   https://doi.org/10.1007/978-3-031-17143-7_33

9. Yallop et al. **ocaml-ctypes.**  
   https://github.com/yallop/ocaml-ctypes

10. opam. **Package format manual (`depexts`).**  
    https://opam.ocaml.org/doc/Manual.html

11. Python Packaging Authority. **PEP 725 — Specifying external dependencies in pyproject.toml.** Draft as of 2026-09-03.  
    https://peps.python.org/pep-0725/

12. Python Packaging Authority. **PEP 804 — An external dependency registry and name mapping mechanism.** Draft as of 2026-09-03.  
    https://peps.python.org/pep-0804/

13. Gibb et al. **Solving Package Management via Hypergraph Dependency Resolution.** 2025.  
    https://arxiv.org/abs/2506.10803

14. Gibb et al. **Package Managers à la Carte: A Formal Model of Dependency Resolution.** *Proceedings of the ACM on Programming Languages* 10 (ICFP), 2026.  
    https://doi.org/10.1145/3828699

15. Macho, C.; Oraze, F.; Pinzger, M. **DValidator: An approach for validating dependencies in build configurations.** *Journal of Systems and Software* 209, 2024.  
    https://doi.org/10.1016/j.jss.2023.111916

---

## Bottom line

The practice-side survey changes the project from:

> "build a better ABI checker for bindings"

to:

> **"make the heterogeneous construction of bindings testable."**

The existing ecosystem already contains good solvers, ABI tools, FFI analyses, package mappings, and rebuild systems. The unsolved practical problem is their composition: **which world was constructed, which assumptions made it appear valid, which cross-language agreements actually hold in the resulting artifacts, and which earlier decision should change when they do not.**
