# Canary: Layered Model for Package-Manager Cooperation and Agreement Chains

## Status of this document

This document records a conceptual model under active development for Canary.

The goal is not yet to define the final agreement taxonomy or verdict system. The immediate goal is to describe, in a package-agnostic way:

1. what mechanisms an individual package-management ecosystem provides;
2. what mechanisms belong to the artifact/binding layer independently of package management; and
3. how two package-management ecosystems compose into a longer agreement chain.

The tables below should eventually be usable both as documentation and as structured input for Canary's evidence and agreement machinery.

A concrete package may override, bypass, or augment the default topology described for its package manager. Those package-specific irregularities are intentionally treated as a later layer rather than being baked into the package-manager-level tables.

---

# 1. Motivation: a chain of heterogeneous reasoning systems

A conventional programming-language presentation often has one reasoning system applied compositionally to a complex program.

The software packaging and binding problem has a different shape.

A real binding installation may involve:

* a package solver,
* package metadata,
* a system package manager,
* source packaging,
* native artifacts,
* artifact metadata,
* discovery tools,
* a compiler,
* a linker,
* a language-specific compiler,
* a binding generator or handwritten FFI,
* a dynamic loader,
* and another package manager.

These components do not share one semantic system. Each enforces a different local relation.

Examples include:

* a package solver deciding whether package constraints are satisfiable;
* a compiler deciding whether source and declarations typecheck;
* a linker deciding whether required symbols can be resolved;
* a loader resolving runtime dependencies;
* `pkg-config` answering a capability/discovery query;
* a package manager asserting that a package of a certain version is installed;
* a binding build producing a language artifact from a native interface.

Canary therefore deals with a **heterogeneous agreement chain**:

$$
R_1 ; R_2 ; \cdots ; R_n
$$

where each \(R_i\) is rooted in a different tool, representation, or package-management mechanism.

Some actions preserve enough information for later inspection. Others are lossy. After a lossy action such as compilation, linking, packaging, or installation, Canary often cannot replay the original relation from the surviving artifact alone. It instead reconstructs necessary conditions and tests **admissibility** from surviving evidence.

This motivates separating three views:

1. **PM solo**: one package-management ecosystem and its relationship to its packages and managed artifacts;
2. **artifact/binding chain**: the package-manager-independent native-to-language binding mechanisms;
3. **PM cooperation**: how two PM/package stacks connect.

---

# 2. The layered stack

The working abstraction has three layers:

1. **PM layer**
2. **package layer**
3. **artifact layer**

The binding sits horizontally in the artifact layer.

A generic composition looks like this:

```text
                ┌─────────────────────────────────────────────┐
                │                Artifact layer               │
                │                                             │
                │  Artifact_sys <-> Binding <-> Artifact_lang │
                │                                             │
                └─────────────────────────────────────────────┘
                           ^                         ^
                           |                         |
                           |                         |
                ┌─────────────────────────────────────────────┐
                │                 Package layer               │
                │                                             │
                │      pkg_sys <-> bridge <-> pkg_lang        │
                │                                             │
                └─────────────────────────────────────────────┘
                           ^                         ^
                           |                         |
                           |                         |
                ┌─────────────────────────────────────────────┐
                │                   PM layer                  │
                │                                             │
                │       pm_sys                    pm_lang      │
                │                                             │
                └─────────────────────────────────────────────┘
```

The names `sys` and `lang` describe roles in one composition. They are not intrinsic categories of package managers.

For example, native libraries may be supplied by:

* apt/dpkg,
* Fedora/RPM,
* Homebrew,
* Conda,
* Nix,
* vcpkg,
* or a hypothetical future package system.

Likewise, a package ecosystem may manage both native and language artifacts.

---

## 2.1 Why keep the package layer separate?

A package mostly inherits its basic structural model from its package manager, but individual packages can contain substantial ad-hoc behavior.

A package can:

* perform custom discovery;
* execute arbitrary build scripts;
* vendor native source;
* bundle native binaries;
* download prebuilt artifacts;
* bypass an external provider package entirely;
* add stronger version checks than the PM normally provides;
* suppress or bypass PM checks;
* introduce its own bridge mechanism.

For example, a normal Python source build may discover and consume an externally installed native library, while a binary wheel such as a large scientific package may bundle the relevant native artifacts and bypass that external chain.

Thus the package layer provides a natural place for package-specific irregularity.

---

## 2.2 Horizontal and vertical relations

The layered model contains two structurally different classes of relation.

### Horizontal relations

These connect objects within approximately the same abstraction layer.

Examples:

```text
Artifact_sys <-> Binding <-> Artifact_lang
```

and:

```text
pkg_sys <-> bridge <-> pkg_lang
```

The first describes actual binding/interface relations.

The second describes symbolic package-level coordination.

### Vertical relations

These connect package-management representations to artifact reality:

```text
pm
 |
pkg
 |
artifact
```

For example:

```text
Debian package
      |
      | install / packaging realization
      v
ELF + headers + .pc files
```

or:

```text
opam package
     |
     | build / install
     v
.cmi / .cmx / .cmxs / native stubs
```

The package version and the artifact's own identity/versioning mechanisms belong to different layers.

For example:

```text
Debian package version
        |
        | possible packaging relation
        v
ELF SONAME / symbol versions / ABI
```

A Debian package version, an upstream release version, an ELF SONAME, and an ELF symbol-version namespace are not one versioning system with several fields. They are independently governed identities whose relationships may or may not be explicitly represented.

---

## 2.3 Diagonal edges

Real systems also contain cross-layer edges.

A particularly important example is discovery:

```text
pkg_lang
    \
     \
      ---- probe/discovery ----> Artifact_sys
```

Examples include:

* `pkg-config`;
* CMake package discovery;
* `*-config`;
* compile probes;
* link probes;
* custom `build.rs`;
* Ruby `mkmf`;
* opam `conf-*` build predicates.

Thus a layered graph is generally more accurate than a simple linear pipeline.

---

# 3. Example layered topologies

## 3.1 opam `conf-*` / depext with apt

```text
                ┌─────────────────────────────────────────────┐
                │                Artifact layer               │
                │                                             │
                │ ELF/headers/.pc <-> FFI/stubs <-> OCaml artifacts
                │                                             │
                └─────────────────────────────────────────────┘
                       ^                           ^
                       |                           |
                       |                           |
                ┌─────────────────────────────────────────────┐
                │                 Package layer               │
                │                                             │
                │ Debian pkg <-> depext/conf-pkg <-> opam pkg
                │                    \
                │                     \
                │                      +--> pkg-config /
                │                           compile probe /
                │                           other artifact check
                │                                             │
                └─────────────────────────────────────────────┘
                       ^                           ^
                       |                           |
                       |                           |
                ┌─────────────────────────────────────────────┐
                │                   PM layer                  │
                │                                             │
                │        apt/dpkg                   opam       │
                │                                             │
                └─────────────────────────────────────────────┘
```

This topology has two distinct paths between the package ecosystems.

A symbolic package-level path:

```text
opam pkg
   ->
conf-pkg
   ->
depext mapping
   ->
Debian pkg
```

and an artifact-facing path:

```text
conf-pkg
   ->
pkg-config / compile probe
   ->
actual installed native capability
```

Therefore this topology can be characterized as:

> **explicit package bridge + artifact validation**

These two paths can disagree, which creates particularly useful Canary checks.

---

## 3.2 Cargo `*-sys` with apt

```text
                ┌─────────────────────────────────────────────┐
                │                Artifact layer               │
                │                                             │
                │ ELF/headers/.pc <-> FFI/build.rs <-> Rust artifacts
                │                                             │
                └─────────────────────────────────────────────┘
                       ^                               ^
                       |                               |
                       |                               |
                ┌─────────────────────────────────────────────┐
                │                 Package layer               │
                │                                             │
                │ Debian pkg                 Cargo/*-sys pkg   │
                │                                  \          │
                │                                   \         │
                │                                    +--> pkg-config /
                │                                         CMake /
                │                                         custom probe
                │                                             │
                └─────────────────────────────────────────────┘
                       ^                               ^
                       |                               |
                       |                               |
                ┌─────────────────────────────────────────────┐
                │                   PM layer                  │
                │                                             │
                │        apt/dpkg                   Cargo      │
                │                                             │
                └─────────────────────────────────────────────┘
```

There is normally no Cargo-level mapping such as:

```text
native capability X -> Debian package Y
```

Instead the language-side package discovers the artifact itself.

This is an example of:

> **artifact-centric composition with package-custom discovery**

Here "artifact-centric" does not mean that metadata is absent. `.pc` files, CMake configuration, headers, SONAMEs, and other artifact-adjacent metadata may be central.

The important point is that the cross-ecosystem coordination does not require an additional package-identity mapping.

---

## 3.3 Cabal with apt

```text
                ┌─────────────────────────────────────────────┐
                │                Artifact layer               │
                │                                             │
                │ native lib/.pc <-> FFI/build <-> Haskell artifact
                │                                             │
                └─────────────────────────────────────────────┘
                       ^                            ^
                       |                            |
                       |                            |
                ┌─────────────────────────────────────────────┐
                │                 Package layer               │
                │                                             │
                │ Debian pkg              Cabal package        │
                │                              |              │
                │                        pkgconfig-depends      │
                │                              |              │
                │                              +--> pkg-config │
                │                                             │
                └─────────────────────────────────────────────┘
                       ^                            ^
                       |                            |
                ┌─────────────────────────────────────────────┐
                │                   PM layer                  │
                │                                             │
                │        apt/dpkg             cabal-install   │
                │                                             │
                └─────────────────────────────────────────────┘
```

Cabal provides a declarative external capability relation such as:

```text
pkgconfig-depends: foo >= X
```

but this does not identify the apt package providing `foo`.

Thus the package system reaches a capability/version namespace, not necessarily another PM's package namespace.

This is:

> **declarative capability-mediated composition**

---

## 3.4 Conda native package with Conda language package

```text
                ┌─────────────────────────────────────────────┐
                │                Artifact layer               │
                │                                             │
                │ native artifacts <-> Binding <-> lang artifacts
                │                                             │
                └─────────────────────────────────────────────┘
                       ^                          ^
                       |                          |
                ┌─────────────────────────────────────────────┐
                │                 Package layer               │
                │                                             │
                │ provider package <----------> consumer package
                │                                             │
                └─────────────────────────────────────────────┘
                                ^
                                |
                ┌─────────────────────────────────────────────┐
                │                   PM layer                  │
                │                                             │
                │              conda / solver                 │
                │                                             │
                └─────────────────────────────────────────────┘
```

The provider and consumer are in a common package universe.

This weakens the distinction between a "system PM" and a "language PM":

> **unified package-universe composition**

---

# 4. Table 1 — PM solo

This table describes one package-management ecosystem considered by itself.

It is intentionally **not** restricted to pure package-manager semantics.

A row may include:

* PM semantics;
* package structure;
* package-level dependency/version mechanisms;
* expectations placed on managed artifacts;
* vertical package-to-artifact mechanisms;
* bridge or discovery support;
* package-specific customization surfaces.

This combined view is deliberate. For example, Debian packaging has meaningful relationships to ELF libraries, while opam is strongly coupled to OCaml build artifacts. Artificially removing all artifact-related behavior from the PM table would obscure useful structure.

| PM / ecosystem                       | Package model                                                                                                                   | Package and external constraints                                                                              | Artifact-related coupling / requirements                                                                                                                                                                               | Versioning structure                                                                                                                                            | Bridge / discovery mechanisms                                                                                                         | Package customization / bypass surface                                                                                                           |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| **apt / dpkg / Debian packaging**    | Binary and source packages; dependencies, provides/conflicts, architecture, file ownership, runtime/dev/debug package splitting | Package dependencies and version constraints live in Debian's package namespace                               | Managed payload may include ELF shared/static libraries, headers, executables, `.pc` files, CMake metadata, etc.; Debian also has ELF-facing dependency-generation mechanisms and shared-library packaging conventions | Debian package version is distinct from upstream version, ELF SONAME, symbol versions, or ABI identity                                                          | No generic cross-language-PM bridge; installed artifact metadata can be consumed by outside discovery mechanisms                      | Maintainer scripts, package splitting, patches, generated metadata, relocation and other distro packaging behavior                               |
| **Fedora / RPM ecosystem**           | RPM packages/specs, dependency/capability model, package splitting                                                              | RPM package dependencies and capabilities; provider relationships may be expressed through RPM-level metadata | Native ELF libraries, headers, executables and development metadata are packaged according to RPM/Fedora conventions                                                                                                   | RPM package version/release and ELF/upstream/ABI identities are distinct domains                                                                                | No generic language-PM bridge; artifact/capability metadata may be consumed externally                                                | Spec files, macros, subpackages, generated dependency metadata, distro-specific transformations                                                  |
| **Homebrew**                         | Formula/Bottle model; package dependencies and prefix/keg organization                                                          | Formula-level dependency relations                                                                            | Strong relationship to prefix-installed dylibs, static libraries, headers, tools, `.pc` and CMake metadata                                                                                                             | Formula version/revision is distinct from Mach-O install name, compatibility version, current version, or upstream ABI identity                                 | No generic language-PM bridge; prefix, `pkg-config`, CMake and related discovery commonly expose artifacts                            | Formula is programmable and permits substantial custom build/install logic                                                                       |
| **opam**                             | `depends`, conflicts, filters, switches, `conf-*`, `depexts`, build/install recipes                                             | opam package constraints plus optional external dependency declarations                                       | Strong coupling to OCaml artifacts and build tools; packages may also compile native stubs or consume external native libraries                                                                                        | opam package version and external native-library version are different domains; the version of a `conf-*` package need not represent the native library version | `conf-*`, `depexts`, package build checks, `pkg-config`, compile probes and custom detection                                          | Package recipes can vendor/build native libraries, perform custom discovery, strengthen or bypass gates, or otherwise alter the default topology |
| **Cargo**                            | `Cargo.toml`, dependencies, features, build dependencies, `links`, build scripts                                                | Cargo package/SemVer constraints and Rust dependency graph                                                    | Rust artifacts can link native artifacts; `*-sys` crates often represent the native-facing boundary                                                                                                                    | Crate version and native-library API/ABI/version identities are independent unless package logic relates them                                                   | `build.rs`, `pkg-config`, CMake, vcpkg and custom discovery; no general mapping to apt/Homebrew/etc. package identities               | `build.rs` is a large package-local customization surface; packages may discover, build, vendor or otherwise obtain native dependencies          |
| **Cabal**                            | `.cabal` packages/components/dependencies                                                                                       | Haskell dependency constraints plus declarative external capability requirements such as `pkgconfig-depends`  | Native capability discovery can feed GHC/native compilation and linking                                                                                                                                                | Haskell package version and external native version are separate; an external pkg-config capability may itself carry a version constraint                       | PM-general `pkg-config` integration; normally no mapping to a specific system PM package name                                         | Custom setup/build logic can extend or bypass the standard path                                                                                  |
| **RubyGems / Bundler**               | Gem/package dependency metadata                                                                                                 | Gem-level dependencies; limited standardized representation of arbitrary system-native dependencies           | Native gems commonly build C extensions and probe headers/functions/libraries                                                                                                                                          | Gem version and native artifact version are separate                                                                                                            | `extconf.rb`, `mkmf`, compile/link probes and package-specific detection                                                              | `extconf.rb` is a strong package-specific executable customization point                                                                         |
| **Python packaging / pip ecosystem** | wheels, sdists, `pyproject.toml`, Core Metadata, build backends                                                                 | Python distribution dependencies; standardized external-native dependency semantics remain relatively weak    | Source distributions may build against external native artifacts; wheels may contain prebuilt language/native artifacts                                                                                                | Python distribution version may be unrelated to embedded/external native library version or ABI identity                                                        | Backend/project-selected `pkg-config`, CMake, Meson, custom probes, environment variables, etc.                                       | Very large bypass surface: binary wheels, bundled native libraries, vendored source, custom build backends, downloaded binaries                  |
| **Conda**                            | Unified package universe containing native libraries, runtimes and language packages                                            | Solver handles dependencies across those package categories                                                   | Native and language artifacts are installed into a coordinated prefix/environment                                                                                                                                      | Conda package version/build identity remains distinct from intrinsic artifact ABI/version identities                                                            | Common solver/package universe reduces the need for a separate sys↔lang bridge; package metadata can propagate downstream constraints | Recipes, outputs, vendoring, package splitting and build scripts still permit package-specific topology                                          |
| **Nix**                              | Derivations, inputs, outputs and immutable store objects                                                                        | Build dependency graph is expressed through derivation inputs and store identities                            | Artifact realization is comparatively explicit: derivations describe builders, inputs and outputs                                                                                                                      | Human-readable package version and derivation/store identity are separate notions                                                                               | Coordination often occurs directly through derivation/store references rather than translating external package namespaces            | Builders remain programmable, although declared input/output boundaries are comparatively explicit                                               |

### Interpretation

The PM-solo table should describe **default ecosystem mechanisms**, not individual package behavior.

A concrete package is an instance of that ecosystem and may perform a graph rewrite over the default chain.

Possible rewrites include:

```text
bypass(discovery)
bundle(native_artifact)
vendor(native_source)
add(custom_probe)
add(custom_bridge)
replace(external_provider, internal_build)
download(prebuilt_binary)
```

---

# 5. Table 2 — Artifact / binding chain

This table describes:

$$
Artifact_{sys} \leftrightarrow Binding \leftrightarrow Artifact_{lang}
$$

independently of package management.

Canary already contains more detailed work on these relations, so this table is intentionally only a methodological overview.

| Binding topology             | `Artifact_sys`                                                  | Binding mechanism                                                                                | `Artifact_lang`                                                  | Root reasoning/actions                                                                    | Typical surviving evidence                                                                          |
| ---------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **Direct native FFI**        | Headers plus native shared/static library                       | Language foreign declarations directly model native interface                                    | Compiled language module/library                                 | parser/typechecker, native compiler, language compiler, linker, loader                    | source declarations, headers, imported/exported symbols, relocation/link/load metadata              |
| **C stub / shim**            | Native API/ABI                                                  | Handwritten or generated C shim mediates calling convention or representation                    | Language artifact plus native stub object/library                | C compiler, language compiler, linker, optional generator                                 | stub source/object, symbol imports/exports, retained type/layout information                        |
| **Native extension module**  | Native library/API plus language runtime extension API          | Runtime-specific extension ABI and initialization entry point                                    | Loadable extension module                                        | native compiler, linker, dynamic loader, runtime extension protocol                       | extension binary, loader dependencies, initialization exports, imported symbols                     |
| **Generated binding**        | Headers, IDL, schema or another native interface representation | Generator transforms one interface representation into another                                   | Generated source and compiled language artifact                  | generator followed by normal compilation/linking                                          | generator inputs/version, generated source, compiled outputs                                        |
| **Runtime / dynamic FFI**    | Runtime-loadable native library                                 | Dynamic lookup plus runtime type/signature declarations                                          | Runtime handles/objects, possibly little static binding artifact | FFI runtime, loader, symbol resolver                                                      | loaded object identity/path, runtime declarations, resolved symbols                                 |
| **Bundled native component** | Native artifact incorporated into a language-side distribution  | Normal FFI/ABI rules still apply, but provider provenance moves inside the consumer distribution | Language artifact/distribution containing native payload         | build/link/load actions remain; external provider PM may disappear from the realized path | bundled libraries, extension modules, search paths, RPATH/install-name metadata, package provenance |

The important conceptual point is that these relations remain meaningful even with no package manager present.

---

# 6. Table 3 — PM cooperation

A PM-cooperation row describes a **composition topology**, not a concrete package.

It asks how two PM/package stacks connect and where information crosses between them.

Important join types include:

* PM-level coordination;
* package-level symbolic joins;
* package-to-artifact diagonal probes;
* artifact-level joins;
* version/constraint transport.

| Composition                                 | PM-level relation                                                                   | Package-layer join                                                               | Cross-layer / artifact join                                                                                                             | Version and constraint transport                                                                                                                                           | Topology character                                |
| ------------------------------------------- | ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| **opam `conf`/depext ↔ apt**                | opam may invoke external dependency machinery; apt does not need to understand opam | `opam pkg -> conf-pkg -> depext mapping -> Debian pkg`                           | `conf` predicate may probe `.pc`, headers, compiler-visible capabilities, etc.; binding build ultimately consumes apt-managed artifacts | Several independent domains exist: opam package version, `conf-*` package version, Debian package version, upstream/native/ABI version; transport may stop at any boundary | **symbolic package bridge + artifact validation** |
| **opam `conf`/depext ↔ Homebrew**           | Similar external-PM relationship                                                    | `opam pkg -> conf-pkg -> depext mapping -> Formula`                              | Probe/discovery reaches Homebrew prefix/keg artifacts and metadata                                                                      | Formula/conf/native version domains remain distinct                                                                                                                        | **symbolic package bridge + artifact validation** |
| **Cargo `*-sys` ↔ apt**                     | PMs normally do not directly coordinate                                             | No generic Cargo→apt package mapping                                             | `build.rs`, `pkg-config`, CMake or custom discovery reaches apt-realized native artifacts; rustc/linker consumes them                   | Native version requirement is generally encoded/interpreted by package/build logic rather than automatically transported into an apt package constraint                    | **artifact-centric + package-custom discovery**   |
| **Cabal ↔ apt**                             | PMs do not directly coordinate                                                      | No apt package-name mapping; language package can name a pkg-config capability   | `pkgconfig-depends -> pkg-config -> installed native capability/artifact`                                                               | Constraint can reach the pkg-config capability/version domain without necessarily reaching the apt package-version domain                                                  | **declarative capability-mediated**               |
| **RubyGems ↔ apt**                          | PMs do not directly coordinate                                                      | Usually no package-identity join                                                 | `extconf.rb` / `mkmf` probes headers/functions/libraries directly                                                                       | Transport is package-specific                                                                                                                                              | **executable probe / artifact-mediated**          |
| **pip source build ↔ apt**                  | PMs normally do not directly coordinate                                             | No strong standardized installer-level apt mapping in the ordinary current model | Build backend/project-specific discovery reaches installed native artifacts                                                             | Native constraint semantics depend heavily on project/backend logic                                                                                                        | **backend-custom artifact-mediated**              |
| **Conda provider pkg ↔ Conda consumer pkg** | Same PM/solver universe                                                             | Direct package dependency in a common namespace                                  | Consumer build/runtime uses artifacts from the same environment                                                                         | Solver and package metadata can transport constraints directly through one package universe                                                                                | **unified package universe**                      |
| **Nix derivation ↔ Nix derivation**         | Same evaluator/store universe                                                       | Derivation dependency/input relation                                             | Consumer build references explicit store outputs                                                                                        | Dependency identity is strongly tied to derivation/store identity; human-readable versions play a different role                                                           | **derivation-identity-mediated**                  |

---

# 7. Artifact-centric versus bridge-mediated composition

The layered model gives a more precise meaning to **artifact-centric**.

Artifact-centric coordination does not mean "there is no metadata."

Artifact-level interface metadata may include:

* `.pc` files;
* CMake package configurations;
* SONAMEs;
* Mach-O load/install metadata;
* headers;
* exported symbols;
* `*-config` executables;
* compiler-visible feature macros.

The distinguishing property is:

> Cross-ecosystem coordination does not require an additional package-level symbolic correspondence between the two package namespaces.

Schematically:

```text
pkg_lang
   |
   | discovery policy
   v
Artifact_sys
```

rather than:

```text
pkg_lang
   |
   v
bridge
   |
   v
pkg_sys
   |
   v
Artifact_sys
```

Thus:

$$
\text{artifact-centric}
$$

and:

$$
\text{bridge-mediated}
$$

describe different composition topologies.

They are not mutually exclusive.

opam `conf-*` commonly uses both:

```text
pkg_lang -> conf/depext -> pkg_sys
```

and:

```text
conf predicate -> Artifact_sys
```

That dual path is particularly interesting because Canary can compare whether the symbolic path and the realized artifact path agree.

---

# 8. Versioning is layered, not global

A major consequence of the model is that "version" should not be treated as one field propagated through the whole chain.

Consider:

```text
PM/package layer:
    package version

artifact layer:
    upstream version
    SONAME / install name
    ABI generation
    symbol versions
    API feature version
```

These are different domains.

For example:

$$
V_{\mathrm{pkg}}
\neq
V_{\mathrm{upstream}}
\neq
V_{\mathrm{SONAME}}
\neq
V_{\mathrm{symbol}}
$$

A useful Canary question is therefore not:

> What is the version?

but:

> What version domain is this claim in, and what relation, if any, transports that claim into another layer?

This becomes especially important in PM cooperation.

A package-level bridge may successfully map identities:

$$
pkg_{lang} \leftrightarrow pkg_{sys}
$$

while carrying no meaningful relation between:

$$
V_{lang}
$$

and:

$$
V_{native/ABI}
$$

That is a structurally different situation from a bridge that transports both identity and a native capability/version constraint.

---

# 9. Internal versus external agreement revisited

Earlier Canary discussion distinguished **internal** and **external** agreement.

The layered model can subsume that distinction without discarding it.

Artifact/binding relations are typically rooted in direct software actions:

* compilation;
* typechecking;
* linking;
* loading;
* generation;
* runtime FFI resolution.

These correspond closely to what we previously called **internal agreements**.

Package and PM relations more often express symbolic claims about external objects:

* package identity;
* version constraints;
* virtual capabilities;
* package mappings;
* dependency declarations;
* provider selection.

These correspond closely to **external agreements**.

The especially interesting relations are the **vertical edges**:

```text
package-level claim
        |
        v
artifact-level reality
```

These ask whether an external symbolic representation is actually supported by internal artifact reality.

Many practical dependency failures can be understood as:

$$
\text{package-level claim}
\not\Rightarrow
\text{artifact-level property actually required}
$$

The layered terminology is preferable because it states the structural location of the relation rather than relying only on an internal/external label.

---

# 10. Package-specific realization as graph rewriting

The three methodology tables describe defaults.

A concrete package should be modeled as a realization or override of that default topology.

Let:

$$
C_{PM}
$$

be the default chain supplied by a package-management ecosystem.

A particular package \(P\) produces:

$$
C_{PM,P}
=
\operatorname{override}(C_{PM},P)
$$

Possible overrides include:

### Bypassing discovery

```text
pkg_lang
   |
 bundled native payload
   v
Artifact_lang[Artifact_sys]
```

### Vendoring native source

```text
pkg_lang
   |
   v
vendored src_sys
   |
 native build
   v
Artifact_sys
   |
 Binding
```

### Downloading a binary during the package build

```text
pkg_lang
   |
 custom script
   v
remote prebuilt Artifact_sys
```

### Adding a package-specific external bridge

```text
pkg_lang
   |
 custom mapping
   v
pkg_sys
```

### Strengthening the external gate

```text
default PM capability check
        +
package-local native version/feature check
```

This means a package such as a bundled Python wheel should not force us to invent a new type of package manager. It is a package-specific graph rewrite over the Python packaging topology.

---

# 11. Relationship to Canary agreements and evidence

The current tables intentionally stop before verdicts.

The expected future flow is:

```text
PM solo topology
        +
PM cooperation topology
        +
package-specific overrides
        +
artifact/binding topology
        |
        v
applicable agreement relations
        |
        v
required evidence
        |
        v
observed evidence
        |
        v
admissibility / holds / violated / unknown
```

This preserves a useful separation:

### Methodology/topology

What mechanisms and relations can exist?

### Agreement taxonomy

What claim can be made over a node, edge, or path?

### Evidence

What surviving observations can decide the claim?

### Verdict

What does a concrete world show?

---

# 12. Agreements may compose over paths

A future goal is to reason about agreement composition across this layered graph.

For example, in the opam/apt topology there may be two paths to the same native capability.

Symbolic path:

```text
opam pkg
   ->
conf-pkg
   ->
depext mapping
   ->
Debian pkg
   ->
realized native artifact
```

Artifact-facing path:

```text
opam/conf package
   ->
pkg-config / compile probe
   ->
native artifact
```

Canary can ask whether those paths converge on compatible identities and properties.

More generally, for a path:

$$
x_0
\xrightarrow{R_1}
x_1
\xrightarrow{R_2}
\cdots
\xrightarrow{R_n}
x_n
$$

the end-to-end relation is a composition:

$$
R_1 ; R_2 ; \cdots ; R_n
$$

but evidence may survive only at selected nodes.

This is where Canary's post-hoc admissibility model becomes important.

The framework does not need to reproduce every tool's semantics. Instead it recovers decidable necessary conditions from surviving evidence.

---

# 13. Working conceptual vocabulary

The following terminology appears useful at the current stage.

### PM solo

The default PM/package/artifact-facing mechanism supplied by one ecosystem.

### PM cooperation

The topology produced by composing two PM/package stacks.

### Artifact/binding chain

The package-manager-independent:

$$
Artifact_{sys}
\leftrightarrow
Binding
\leftrightarrow
Artifact_{lang}
$$

relation.

### Package bridge

An explicit symbolic relation between package-level namespaces or dependency representations.

### Artifact-centric composition

A composition where cross-ecosystem coordination can occur below package identity, through artifacts or artifact-interface metadata, without requiring a package-name bridge.

### Vertical relation

A relation between PM/package representations and artifact reality.

### Discovery

An action that recovers an artifact/capability from an environment or artifact-facing metadata.

### Package-specific override

An ad-hoc package mechanism that changes the ecosystem's default topology.

### Admissibility

A post-hoc judgment that a candidate combination satisfies a necessary relation originally established or required by some real action/tool.

---

# 14. Current scope

At this stage, the model should remain deliberately structural.

In particular:

* do not turn detailed ELF symbol resolution into a separate Canary research topic;
* do not require every artifact format to have an exhaustive semantic model;
* do not assume package version and artifact version should be identical;
* do not assume all PM cooperation involves a direct package-to-package bridge;
* do not treat a concrete package's custom behavior as intrinsic PM semantics;
* do not add verdicts directly to the methodology tables yet.

The immediate purpose of these tables is to let Canary and its agents determine:

1. what topology applies;
2. what package-specific rewrites occur;
3. what agreements are meaningful at each edge/path;
4. what evidence should be collected.

---

# 15. Current three-table structure

The current methodology therefore consists of exactly three complementary views:

## Table 1 — PM solo

> What mechanisms does one package ecosystem provide, including its package model, artifact-facing requirements, bridge/discovery mechanisms, and customization surface?

## Table 2 — Artifact / binding chain

> Independently of package management, what relations connect the native artifact, the binding, and the language artifact?

## Table 3 — PM cooperation

> When two package ecosystems are composed, at which layers do they connect, and how do package identities, constraints, discovery and artifacts cross the boundary?

Together they provide the static structural model from which Canary can later derive evidence requirements and agreement/verdict composition.
