## 3. Model of Package Managers for Language Bindings

### 3.1 Overview

@import "exhibits/fig-components.svg"

In this section, we will present our modeling for package managers around language bindings. We want to point our the dichotomy for the artifact part and the management part. 

(artifact vs package) Artifact-parts are created and consumed by the language tools. How source-code or language-platform dependent artifacts including bytecode or native are consumed, are determined. It's not a tautology 
(or nonsense) to emphasize that language tools don't know about packages. Languages usually have their own _module_ concept like `module` or `class`, and has its mapping between files and modules. 
Package-parts reuse the language concepts to give the language tools an appearance that every artifacts stay locals.

(split out package content) We move out the handling for package content from the package 
management, for several considerations. All managed material are not determined and coupled by one 
package manager. Differnt package managers can handle same materials. The integrity that package 
content shall obey can stay isolated to package managers, e.g. how ELF-format files should comply to 
their specifications. We all notice different package managers can have its own conversions for some 
managed material, like how paths should be stated. We don't treat it as the standard that some ELF 
files have to satisfy, but an agreement which the management side can require. 

For the functionality, package managers target to solve package resolution that including 
identifying, selection, and delivery. Either package manager side's versioning, or other constraints 
like platform or tool requirements are for this. The managed artifact can have itw own versioning 
like in ELF or just code in different formats like in many languages. However, none of any 
versioning schemes can guarantee its declared compatibilities. The widely use semantic-versioning 
 (really a misleading name) has some guidance on package content, but it's coarse and never 
 enforced. We still respect the management-side, and just to put the faithful checking explicitly into the artifact-layer.

### 3.2 Package Managers up to Packaging

@import "exhibits/tab-pm.html"

Package managers are softwares to maintain mapping storages from package names 
with versions to packages. A package can be in a designed formatted directory, and can be in local or remote places.

The package side can resolve to a required package and to fetch the package material. The most safety we expects are _resolvability_. It includes the naive package resolution, payload related resolution e.g. path in ELF, which needs discussion in 3.2, and cross package managers resolution, in 3.3. When a package manager resolves to a package at a version for satisfying somme dependencies, we tend to believe it solves dependecy constraints syntactically.

### 3.3 Package Payload Integrity

We observed and discussed that there is no coupling between packaging and payload. We can see many examples for different payload kind in some package 
managers. For example, we can have native libraries, source file and headers, or even OCaml modules in Debian apt, and we can also have native libraires at packages in opam and pip. We think that package payload shall comply to some rules are payload-denpdent. The good news is package payload kind is usually 
staightforward to find.

### 3.4 Package Manager Cooperations

@import "exhibits/tab-cooperation.html"

### 3.5 Binding Mechanisms

@import "exhibits/tab-mechanisms.html"

- The part lists both sides of a binding mechanism. Both sides keep its own integrity
- The part is package-free

Initially introduce _admissible substitution_: practically, one cannot rebuild everything from the source, and the outer resolution side can provide an arbitrary artifact.

### 2.2 Layered View for Actions

<!-- 
@import "exhibits/tab-pm.html"
 -->

![Figure 1. Layered Actions across Bindings](exhibits/fig-chain.svg)

We are seeking a principled framework that helps to understand, reason, and explain 
the issues around packages for language bindings. We propose to split the workflow
into package managers without package content, cooperations of package managers, certain package customization, 
creatation of package content, binding mechanism across two languages or file formats. 
_sw: rewrite the part_
Roughly, we ascribe some to the resolution of resource to package managers, and some to 
the producing and consumptions of artifacts. The perspective helps to reason the ubiquitous 
iregularites of package usage in a uniformed generic framework.

We propose a layered model, showned in the diagram. The diagram depicts the package managers, 
pacakges, and artifacts from system and from language in each side. The diagram also shows 
the layers for package managers, packages and artifacts, and programs. The model as well as 
the digram has benefit to show iregularity packages. To run a complete binding, there must be 
artifact in the system side. If that artifact is not managed by system package manager directly, 
we can still see the artifact as its designed place. It can cover cases e.g. bundled in 
same language side package, provided by another language side package, or provided by a virtual 
package, etc. The model also places the aligned parts in each side horizontally, thus we 
can see the matching packages, source code, interface files, and compiled artifact if having. 

*sw: some words for an example from the diagram here*

*artifacts have itw own rules.* No matter for system package managers who maintains 
native libraries, or language package managers who maintains language packages, we can find 
any artifact understand managed, including ELF-format object, or OCaml or Python modules, 
are agnostic by package managers. Creation, usage, and inspection of these artifacts are 
provided by binary or language tools, rather than any package managers.

*package managers are not coupled.* Different linux distro can have separate package managers,
for example, we can have Debian's apt and Fedora's rpm. We see new package managers for Python 
or JavaScript invented from time to time. Even for OCaml where opam is the official standard 
package managers, we can have _dune pakcage management_. Regardly of whether being official 
or de-facto software, from the design space, a package manager is external to the artifact 
being packed and managed. _Familiarity is not true knowledge_.

*package can almost customize anything*. Some artifacts in a package may need a complex 
and subtle dependency and environments. The package manager may not have features, or the 
package registry is not satisfiable, or they are not working well at that moment when that 
package is published or maintained.
The good thing is package managers often let a package 
resuce itself with shell script, patches, external resource fetch, however, it may also bring
complexity at the same time. _Extraordinary dependencie require extraordinary custmization_.

### 2.3 Canary Overall

**Thesis**: a project declares only what it is; the framework derives the
worlds, realizes them, and keeps the record of how each was realized.
The deployed set is a product, and a product is derivable — which is
what makes provenance an experimental variable rather than a fixed
assumption.

This work present the Canary framework. Canary enumerates practical operations 
, from a project manifest containing the necessary project-specific commands for
building, installing and delivering the project, together with declaration of
artifacts such as source code, packages and releases for upstream libraries or binding.
Each enumerated scenario contains a sequence of possible action that may span 
several stages. A scenarion can run locally through a OCaml driver program, or 
as a continuous integration workflow. Scenarion enumeration provides covers 
situations in which artifacts of interest may be used, in situations that library
developers or package maintainers may not anticipate and that library users
may not encounter exhaustively.

Besides enumerating scenario combinations, we also enhance each scenario's
action chain with checks dispatched from the agreement registry for the involved 
artifacts. For example, consider a project `tiny`, in which an OCaml module uses a 
binding to a C library
Its source files include the header file `tiny.h`, C source `tiny.c`, 
OCaml C stub `tiny_stub.c`, OCaml binding `tiny.ml` and an OCaml signautre `tiny.mli`.
Building OCaml binding `dlltiny.so` and others needs C header and the compiled 
library `libtiny.so` (assume ELF format in Linux). Compliing and running the OCaml 
binding locally needs linker and loader to treat `dlltiny.so`. With the binding,
a user can use it directly, but a library develop may publish `tiny_help`
library which declares this dependency, and let the user fetch that files.
Both system and language-specific package managers help deliver and resolve artifacts.
However, they also complicates the situations on how artifacts are declared, which artifact to use,
whether they fit together, and more broadly, how the package managers cooperate.
