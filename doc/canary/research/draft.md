# Practical Principles and Bug-Finding for Language Bindings across Package Managers

## 1. The problem

t.b.c

## 2. Our solution
<!-- , and why it wins -->

### 2.0 Rationale & Outline

(essential complexity) The bugs around cross-language bindings are tricky. The trickness comes from the essencial 
complexity in the problem setting. It's involved two stacks, the language and the system, 
ranging from the files to the packages, and also the interaction between both the language 
tools but also the package managers. What's more, concrete case also depends on the 
specific package manifest and the running environments.

_sw: diagram-one-stack * 2_
_sw: diagram-binding-mechanism_
_sw: diagram-coop_

$$
PM_{lang} \rightarrow Package_{lang} \leftrightarrow 
Artifact_{lang} \leftrightarrow Binding \leftrightarrow Artifact_{sys} 
\leftrightarrow Package_{sys} \leftarrow PM_{sys}
$$
<!-- _sw: update color to align with diagram, also fold one-line as layers_ -->

_sw: this formula is not good, since pm-coop is not here_

(this work)  Our target is to study the workflow a.k.a real-world actions around the 
language bindings. It doesn't only cover immediately on how an binding is 
created and used, but also cover all the lifecycle for the dependent artifacts, 
tools including package managers, and systems where they are working on. 
Before delving into what build, deploy and runtime tests we can do, and how to establish 
the expectation and blaming, we first introduce on how we see these issues, and how this work (canary frame) 
targets to handle these issues. We propose a perspective **modeling** to treat the whole chain as separate components as:

- $M_{lang}$ and $P_{lang}$. Package managers for a language for only the management part
- $M_{sys}$. Package managers for system for only the management part
- $A_{lang}$. Language artifacts and related tools including compilers, interpreters, inspectors
- $A_{sys}$. System artifacts and related tools.
- $B_{mech}$. Binding mechanism that a language and a system cooperates
- $Co_{op}$. The cooperation between two package managers.

At the artifact-layer, we treat binding mechanism as first-class variant to study, while
at the package-layer, we also treat package managers' cooperations explicitly. This split 
also helps to split normal managements on naming, versioning, resolution, dependencies, 
and also give the cooperations a dedicated study, that interaction based on package content, 
and via special constructs e.g. virtual packages. We can see here naturally residents a M*N 
problem essentially, and it cannot always be solved by the courtesy from some good packages.

The motivation to treat the real-world pm with bindings as a combination of several components 
in ragged formality.

A real-world project using cross-language bindings, along with its deployment in package managers, 
have to declare and experience actions in such components. These information may be provided by 
different people. _sw: stating what they can provide._

However, not all the components are specified, especially for _irregular_ package. For example, a 
pip package has bundled native library artifact, or an opam package who builts a native library from 
source. Our modeling treats they misses one-side of management.

We use the practice enumerations for interesting **actions** during any above commponents. The 
enumeration will cover useful combinations for artifacts appeared in each components (and staged). 
Those actions may fail or generate outputs that the framework treats them as failure signals that 
we try to trace and blame. Given the miscellerous systems themselves and cooperations may never 
have invariants or inferences, and some standards are just conventions. We would call them **agreements**.

(existing studies) Traditional PL topics concern one component, e.g. one language, and declared strictness can 
range from fully verification, type-checked, to untyped. There are also studies and tools on 
some across boundaries studies, including FFI; there is also studies on PM, which respects the 
complexity of full chains and focus on the resolutions.

(exisiting works in PL abstract) Common PL tools are concerning one set of rules,
and the combination of applying them on joinable components, e.g. interpretation, typecheck,
 static analysis, etc. Package managers under our discussion, is the real-world application, to 
 combine a group of different set of rules, that covers multiple package managers, multiple 
 package content, and the cooperations between them. Some sets of rules can be typechecker, e.g.
 the provider or consumer of the bindings can be in a typed language, but it's just some cases.
 They also don't always start with the original input, say even with the full language tools, 
 we cannot re-compile and re-build everyting from scratch. The problem extended to ensure the 
 artitrary artifacts

(expect for users) With the above theoretical and framework preparation, the users are expected 
to provide a project manifest including only two parts of information: (1) the source code which 
is for the system library, for the binding, or both, (2) arbitrary resource declaration including 
code repo, package provision, etc. The canary framework will generates enough testcases, then 
detect bugs and blame coresponding components.

The whole paper follows the outline. They are:

- SS 3. Modeling for bindings, packages, and package managers
- SS 4. Actions
- SS 5. Agreements
- SS 6. Case study for Bug and Fix
- SS 6. Evaluations
- SS 7. Implementation

@import "draft_ss3.md"


## 4. Practical enumeration

### 4.1 RATIONALE — why enumerate at all

The movitation for enumeration is straightforward:
**to dry-run possible scenarion and encounter the error before users do**. 
Some errors or bugs only occur in particular scenarios.
For example, a build script may set a incorrect linker flag in creating
the release version of a library, and the bug may survive the subsequent
binding building. Detecting such bugs before users report them can reduce 
their impact on users and the maintenance burden. The problem comes down 
to **what** to enumerate and **how** to enumerate it.

Canary's enumeration is a **practice choice**. It is neither intended to
explore every possibility exhaustively nor limited to combinatorial testing
over fixed constants. Canary intends to permutate the important artifacts,
including official source code, building artifacts and packages in official 
registries. As a heuristic, we try at least two versions of 
each artifacts: the latest stable version and a development version at the 
time of checking.

One way that canary handles real-world version irregularity is by
**bypassing existing restriction and anticipating combinations**
Real-world projects often have uneven release schedules. Development may
 be active while releases in package registries lag behind. Tensions
 between dependencies are intristic, regardless of the software or 
 versioning scheme used. If the dependency remain fixed to old components,
 old bugs can never be repaired; if the dependency is not kept,  
 compatibility can never be guaranteed. 
 <!-- It's the real cases for packages
 that don't provide development version, or kept a restriced or relaxed
 dependencies. -->

To realize these version combinations, Canary provides customized package 
manifest file for each package manager, and makes a local package storage.
This allows us to provide packages for development versions even before an upstream
package is released. We also modify the existing 
 manifest files of packages to allow dependencies on development versions.
It's a radical modification but often works, because many packages for 
bindings usually just boost their dependency then encounter the same
situation needing fix as we can encounter with this modification.

Real-world packages often bundle its dependency, especially for artifact 
not managed by the same package manager, e.g. pip's `z3-solver` bundles
a `libz3` in the Python package. `opam` also have packages named `lib<pkg>`.
It's a fragiled but common practice. Canary handle real-world provisioning 
irregularities by supporting ad-hoc package _co-providers_ to specify them 
in our project specification.

### 4.2 Action, the basic operation and enumeration unit

Canary uses actions to describe project operations, including _build-library_,
_build-binding_, _install-library_, _publish-package_, etc. An action's 
input and output components are statically known. Some action outputs become
the input to other actions, e.g. both _build-library_ from source 
and _fetch-library_ from a package manager can provide a library consumed by _build-binding_.

The actions form a directed acyclic graph (DAG), with nodes representing actions, 
and edges representing there are artifacts passed between them. Duplicate
actions can be represented by the same node. Dependency
resolution for action enumeration is simpler than resolution in
build systems or package managers, because the graph can be constructed 
statically. It does not require dynamic decisions about which binding or mechanism to use.

Action enumeration has two parts: the action shape, 
in which the provenance, version, platform and other choices are not yet specified,
and the concrete choices for those parameters. It's quite like enumerating 
arithematic expressions of a given length: expression shapes (choices of operators) 
and numbers (choices of operands) belong to different categories.

Action-chain shapes can be enumerated independently of the concrete projects
being tested.. It also reflects the common structure of project workflows. 
The project-independent enumeration can be shared, while only project-specfic 
information needs to be declared in a dedicated data structure.

### 4.3 Project Manifest

(SW: _spec_ may not be a good name. The intention looks like a project _manifest_)

In the Canary framework, a project such as `z3`, `llvm` or `torch` is described
by a project specification. The specfication declares the project-specific commands
that actions may need,such as commands for building, installing and
testing. Most of this information can be collectec from the project's official documentation.
It's one of the few places of Canary that requires human effect to audit.

A project specification also declare an arbitrary numbers of resource as 
artifact providers. Canary provides utilities for fetching from common package
managers, remote resources and local vendored sources. 
The specification is a static declaration, and a following collection
pass gather providers for each artifact. For example, the providers of 
native library z3 include official project source, which needs to build, 
the latest stable packages in the platform of interest, and the python 
package `z3-solver`.

### 4.4 Running Actions

An action is instantiated using information from a project manifest. 
For instance, the _build-project_ action for project z3 gets the building command and
the path to the source code artifact. Canary also prepares the output path required
by the build command.

Canary supports running the actions on a local machine for quick execution, and 
on CI backends, such as GitHub CI, for a persistent and reliable records. 
Supporting both local machine running Ubuntu or MacOS and backend which 
primarily takes a YAML file involves subtle design considerations.

The local execution target is an OCaml program that invokes external tools and
shell scripts. Actions and artifacts have unique identifiers, 
helping minimize unnecessary repetition. Actions whose inputs and outputs 
consist only of files can be cached naturally. For package managers
 that do not allow multiple versions of the same package name to coexist, action 
 requiring different versions need fully _uninstall_ one version
 then _install_ another, or use separate package
environments, which are currently often expensive for OCaml.

Targeting GitHub CI YAML files involves additional design considerations. A YAML
can contain multiple jobs, and each running on an isolated machine. Jobs  
natually share nothing. We assign each job to hold a list of action (a path in
the action diagram), so later actions can reuse the earlier result.
Currenly, some actions are duplicated across jobs. The advantage is that,
as in common usage of GitHub CI usage, a job's status reflects the status of a
complete scenario, e.g. _fetch-project-v1_, _build-project-v1_, 
_building-a-binding-vb2-with-v1_, _pack-vb2-as-a-package_, _fetch-package_,
_run-app-using-package_.

### 4.5 Compiling to Actions

Canary implememtation approaches is like a compiler which takes static surface 
information as the inintial IR, to runnable steps on concrete backends end terminal IR. 
This design helps to clearly inspect information in each stage, reduce duplicated work 
on configurations, and only fulfill complete commands until the platform-dependent 
instructions are necessary.

_sw: t-b-c The necessarity and benefit is mainly for engineering, a.k.a practical usage._

## 5. Principled checking

### 5.1 Rationale

PL researches usually concern one set of rules or semantics, and it applies on 
multiple components compositionally. Real-world package managers across language 
bindings contain naturally heretogenous parts, while some steps can be typechecked 
if one side of binding uses a language supporting it. Thus, it may combinate multiple
systems on integrating good virtue of each involved components that people wish to have.

The complete pipeline for a consumer program of using a binding can be split 
into three parts, resolving the binding side module, resolving the native side module,
and invoking the binding mechanism. The real order of these parts can vary and differ, 
but we can see the different layers for the artifacts that around the bindings, and
the peripheral structures and steps that helps to find thoe artifacts.

The **artifact layer** is dictated by the language and binary tools. The agreement between 
the inputs and the outputs is introduced by the tools, and indirectly by any specification 
if that tools obey. For example, a compiler compiles a source code `src` to an output `obj`.
We can inspect the `obj` to find the evident that it should be aligned with the `src`:
if it's the case that C code compiles to an ELF object, we can inspect the symbols, functions, 
etc; if it's the OCaml compiles to code to a bytecode, we can using ocaml's objdump 
to inspect. The observation here is the artifact creation carries some agreements from 
the tools and the creation is unavoidably to lose information. These agreements is a _search of the 
lost agreement_ for arbitrary given artifacts, that the package managers might provide. 
With this perspective, for any existing actions in the artifact layer, we can seek  
some direct agreements.

Considering the binding mechanism, we can also find agreements that spans several actions.
For example, the binding usually provides similar interfaces in different sides. For example, 
the native library can provide math operations in its syntax, while the binding library 
has coresponding operations. These agreements depends on which binding mechanism you are using. 
for example, whether requiring C stubs, whether involving separate compiled steps, or whether 
pure dynamically. Beyond the binding mechanism, both the presense and invarants on one side 
shall be kept conventionally on the other side. The agreement can be detected and checked 
via either the static inspection, or dynamic runtime tests

The remaining pipeline are in **package layer**, which concerns how to declare and locate 
the artifacts as package payloads. Our would like to view one package manager from the 
package payload side and the management side, because they don't have to be coupled. For 
example, we usually describe Debian apt as a system package manager, and it uses to manage 
system packages, some of which are native binary libraries. We can see ELF has its own 
specification, versioning, convertions, which are not determined by the package managers.
The same is also true for Mach-O and homebrew. However, the package manager side can 
enforces some conventions for the managed material, e.g. how to set its rpath. We 
treat the package management side and payload side separately, and it helps us to understand 
and propose agreements better.

The artifacts for a binding can be provided by separate package managers. Multiple 
package managers have different cooperation patterns. A package manager can be aware and 
even specify another package manager. For example, opam once uses `depext` to
 speicfy the external dependencies and now prefer to use virtual conf-package which directs 
 depending on system packages managers. If a package manager itself is agnostic about 
 other package managers, the task is either left to packages or to users, so that the 
 solution (or the fact) are various. For example, opam's `z3` package currently has 
 to build a `libz3` within the opam package. For pip's `z3-solver`, it ships 
 a prebuilt `libz3` in the package.

The above disussion forms perspectives to treat the actions as the join from two package
managers including their management parts and payload parts, and the binding mechanism parts. 
The four components at three layers helps to category the agreements.

### 5.1 Rationale (Old, Shall be absorbed)

There are several motivations for principled checking. (1)
we want to make explicit which checks are performed and what they mean. 
For individual artifacts, such as a native binary, may contain 
dangling symbols, hardcoded path,
mismatched functions that do not match a binding's expectations. Whether 
these properties are tolerable, resolved later, blame itself or the binding
side, may depend variously on ABI specification, other tools, 
binding mechanism and conventions practice used by package managers. 
Enforcing every agreement is not practical task for a checking framework, 
but making the agreements explicit is feasible. (2) registering checks as 
pre-action or post-action hooks, or as special actions,
allows them to be invoked uniformly to be invoked uniformly without 
relying on developers to remember to run them.

Information loss is intrinsic. For example, C the source code, 
including header file, is compiled to a native library. Later actions may use 
different versions of the headers and the native library, whose compatibility must then
be checked externally. In ELF, linking records the linked library's name in
the binary's `NEEDED` entries. the loader later searches for the library using
that name to find an alternative, but whether the work as previous is unclear.

Any involved artifact can be published through a package manager,  and a later
action may use a different artifact fetched somewhere else.
Whether a different artifact, such as a header file or library, is compatible 
with the previous one is a undecidable quesiton. No versioning scheme can
encodes all the invariants.

Given that most of the checks are not strict requirements, we 
use _agreement_ to describe the expectations that an artifact or an
action should satisfy but can fail.  We avoid stronger terms such as _invariant_
because software can often still work even when an agreement is violated.

Canary centralizes the agreements in a module named agreement registry.
When an action touches a particular artifact, or involves a binding mechanism or
tool, it will look up the agreement it should check. Each agreement provides 
a command template, so that the corresponding can perform alongside with the action.

### 5.2 Agreement at a Glance

Agreements can be on one or several artifact. Artifacts can be checked by  
inspecting artifacts with tools or running tests.
We use _bind mechanism_ to denote the method by which a binding becomes
available. Considering the common situation in which an upstream project provides
C code that can be compiled into a native lib, and OCaml or Python code
needs to use it. Both languages
offer several mechanisms for using native libraries, including compiled C stubs
and dynamic loading. The artifacts involved can be 
fetched from package managers or online resource, and users often rely on constrains
like versions to select the appropriate artifacts. We would like to go a step 
beyond these common scenarios, which Canary can already enumerate, and ask which 
agreements we can expect and check.


**what do we check against**. t.b.c

**how do we check**. The checking follows our practical rationale, as experienced 
developers, we only use existing tools to inspect artifacts including 
system binary utilities and language own toolset.
<!-- here we also have project-agnostic and project-dependent -->

**what do we check**.
<!-- 1. check native lib, against C header, for symbol exported: warning if symbol missing
2. check native lib, for recorded resolution path: 
  - if build profile is install, none of local building path should appear -->

### 5.3 Native Binary Artifact

Many upstream project provides C libraries, and other languages can access 
through the system ABI. Compiling a C library requires header files that may
also be used later in building (but not using) language bindings.

Agreement between a header file and native binary is established during compilation.
Given an arbitrary header and binary, however, that agreement must
be recovered and established again. Violating it does not always cause a
runtime error. A missing declaration may be tolerated if it is never needed.

Native binaries acquire information as they are compiled and linked. 
When native library is built for delivery using the *install* build profile, 
the agreement is that the binaries should not contain local path information. The 
violation may be tolerated if other conventional search paths compensate for
it.

We use compiler toolset and platform binary utils to inspect the artifacts.

## 5. Attribution and Blame

*Thesis: a red cell says something broke; a finding says who is
answerable. The step between them is not a heuristic — the blamed
party is read off the source of the claim, and the derivation kept
during realization is what makes that reading possible.*

- **The blamed party is read off the source of the claim**, not off
  the artifact that happened to fail. Each of §4's seven sources
  carries one: a self/format failure indicts the artifact; a
  declaration failure indicts *either* the artifact or a stale
  declaration, and the row must say which side it treats as
  authoritative; a peer failure indicts a side; a sibling-world
  failure indicts neither artifact but the **provisioning**.
- **A failing check means the artifact or the claim is wrong.** A row
  that does not name which it trusts produces an unattributable
  finding — which is a bug report nobody can act on.
- **Direction is a tiebreaker, not the rule.** It resolves a peer
  failure only when the two sides differ by *version*: forward, the
  consumer asked for too much; backward, the provider dropped
  something. When they differ by *packaging* — both artifacts correct,
  the versions drop-in compatible, the conventions disagreeing about
  how one implementation is named and divided — no direction exists,
  and the blamed party is the **cooperation**. ncurses is the specimen
  that forced this amendment.
- **Blame is an output, not a narrative**: the check names the surface,
  the surface names the actor, and the world's derivation names which
  decision put that artifact there.

<!-- what is claimed, and what is not -->

- **What exists today, stated plainly.** Which *agreement* confirmed a
  failure is recorded per step and survives into the run record;
  direction is computed per scenario and displayed. Party-level blame
  is **not implemented** — the detection pass still reports only
  whether a step errored and whether its output appeared. The claim is
  therefore a *model with two working instances*, never a localizer.
- **The merit claimed is integration, not per-artifact strictness.**
  The specialist checkers are more rigorous about a single artifact
  than we intend to be. What none of them does is carry a world's
  derivation far enough to name a responsible party.

## 6. Implementation

## 7. Evaluation and Result

*Thesis (plan): 
- We applies the canary on dozens of real-world projects 
and detect those bugs. Some of admiited and solved as PRs.
- We proposed several new bindings that are more confirmative than 
their counterparts.

## 8. Related work

*Thesis: §1 already met this work component by component; here it is
grouped by what each line contributes, and by whether it is a
neighbour, a backend, or a rival.*

- **Artifact-level checking** — libabigail (`abidiff`, `abicompat`),
  `abicheck`, `abi3audit`, `auditwheel`, distribution ABI QA. The
  closest work, and the natural **backends**: they answer a pairing we
  hand them.
- **Cross-language FFI analysis** — Jinn, TurboJet, FFIChecker,
  Python/C static analyses. Per-language protocols, deeper than
  anything here on their own ground; we claim no new theory of FFI
  faults and would run them as backends too.
- **Dependency resolution** — the ecosystem resolvers, dose3, and the
  cross-ecosystem work: HyperRes, Package Managers à la Carte / the
  Package Calculus. They decide what *may* be combined, and stop
  before realization, deliberately.
- **Provenance and supply chain** — SBOM formats, SLSA, reproducible
  builds. Complementary: they record how an artifact arose, a record
  this work also needs and puts to a different use.
- **Ecosystem rebuild and QA infrastructure** — autopkgtest,
  conda-forge migrators, opam bulk builds, `cibuildwheel`,
  `rpminspect`. The nearest in *shape*; the difference is the unit of
  exploration, not oracle strength.
- **The theory side** — verified and type-preserving compilation,
  linking calculi, ELF and FFI semantics. Inherited: a behaviour check
  as refinement of an observable trace. Departed: those systems own
  every pass, and we own none of them.
- **Adoption is itself a finding.** These lines divide sharply —
  package, build, binary-policy and ABI tooling reached production
  infrastructure, while cross-language and cross-ecosystem analyses
  remain prototypes or emerging standards. The composition gap is not
  only conceptual but deployed.

*Material: related/literature.md (theory, 12 sections);
related/canary-practical-cross-language-bindings-report.md (practice);
related/adoption-in-practice.md (adoption). §2 carries the four
objections; this section carries the map.*
