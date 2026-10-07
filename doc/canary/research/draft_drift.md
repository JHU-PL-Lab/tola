# Draft drift: what draft.md does not say yet

<!-- Material to mine: draft_old.md,
     draft_comment_old.md, surface_draft/ (incl. tiny.md), and design/.
-->

## 0. The framing: a binding is a heterogeneous join

### 0.1 One stack: management over artifacts

- A package manager does not handle artifacts directly. It manages
  packages: names, versions, dependency constraints, and a solver that
  picks a consistent set. The artifacts carry their own facts: exported
  symbols, sonames, symbol versions, interfaces.
- So even one stack has two levels, management over artifacts, and the
  explanation can start there, before any binding. The PM touches
  versioning and resolution for the artifacts' provision and
  compatibility, but a solved version set stands in for compatibility;
  it does not guarantee that the symbols agree.
- Within one stack, some ecosystems derive management metadata from
  artifact facts, which narrows the gap (to verify before citing): RPM
  generates requirements from the sonames and symbol versions a binary
  needs; Debian's symbols files record the package version that
  introduced each symbol, and `dpkg-shlibdeps` turns the symbols a binary
  uses into dependencies.

### 0.2 Two stacks: what a binding brings

- A binding joins two ecosystems, a native library and a program in
  another language, so it brings two stacks, each with its own package
  manager: PM_sys over Art_sys, PM_lang over Art_lang.
- The stacks are joined at both levels:
  - at the artifact level by the **binding**: a stub or extension that
    calls the native library, linked or loaded against it;
  - at the management level by the **cooperation** of the two package
    managers (PM_coop): a bridge package (opam's conf-*), a depext naming
    a system package, a capability file (`.pc`), or nothing.
- The cooperation exists only because there are two stacks; one stack
  needs none. The program sits on top and reaches both through the
  binding.
- Canary's model is this square with the program on top: Figure 2's
  nodes and edges, the seven layers of the page's Table 6, and eleven
  cooperation kinds (unified, absorbed, conf, depext, capability,
  artifacts only, and others).

### 0.3 The two joins are not coupled

- PL's paired notions are coupled by construction: an expression and its
  type, a term and its value, are related by a judgment the language
  defines.
- The binding and the cooperation have no such relation. The cooperation
  concerns the artifacts on the two sides (the system's library is
  present, at some version), not the binding. It does not know the
  binding's mechanism: compiled stubs need headers and a library at
  build time, ctypes only a library at load time. Nor does it know the
  symbols, soname or ABI the binding needs.
- So the square need not commute: what the cooperation admits at the
  management level is not, by construction, what the binding needs at
  the artifact level. A world both package managers accept can still fail
  at link or load time.
- The agreements across the square's diagonal are commutation checks:
  `gate_bounds_the_library` (the bridge's bound against the library's
  version) and `discovery_matches_link` (pkg-config's answer against what
  the binding links). Both are candidates. No agreement yet checks that
  the gate admits only libraries exporting what the binding requires;
  that would be a composition of `gate_admits_the_world` and
  `required_symbols_exported`.

### 0.4 The tensions, side by side

- **Artifact-facing** (management over artifacts, in each stack): the PM
  resolves versions for provision and compatibility, but a version
  stands in for the artifact. It cannot guarantee that symbols, sonames or
  interfaces agree; canary's agreements check what it cannot.
- **Binding-facing** (the cooperation): it is not aligned with the binding
  mechanism and carries too little metadata, names and version bounds,
  rarely an artifact fact.
- **The design question:** could the cooperation's metadata be derived
  from the artifacts the binding needs, so that the solvers' yes implies
  the linker's and the loader's? Within one stack RPM and Debian do part
  of this (0.1). Across stacks the nearest is manylinux: a wheel's tag
  bounds the glibc symbol versions it needs from the system, and
  `auditwheel` bundles every other native library into the wheel (to
  verify).

### 0.5 The design space

Each axis, with points canary has met or models (cooperation kinds in
brackets):
- **Who supplies the native artifact:** the system PM (apt, brew); the
  binding's package, bundling or building it (absorbed: wheels, and z3's
  opam package, which ships its own libz3); one PM for both stacks
  (unified: opam's libtorch beside the torch binding; Nix, Guix and
  conda, to verify); the binding's own source tree (local).
- **What crosses the management join:** nothing (artifacts only); a
  capability file (capability: `.pc`, and Cargo's `*-sys` crates, to
  verify); a package name (depext); a predicate checked against the
  system (conf: opam's conf-*); version bounds on it; artifact facts
  (manylinux, 0.4).
- **How the binding joins the artifacts:** statically, through compiled
  stubs or extensions (link time: headers and a library), or dynamically,
  through an FFI (load or call time: a library only). The mechanism
  decides which artifact facts matter, and when.
- **Who checks what:** the solvers check metadata; each tool checks its
  own rule at its action (compiler, linker, loader); canary checks
  agreements over the artifacts that survive, in every world the package
  managers admit, and places a failure at a layer or a join.

### 0.6 A PL perspective: the heterogeneous join

- PL work on multi-language systems studies the artifact join (FFI
  typing and checking) for a fixed build; work on dependency solving
  studies one management level. A binding deployed through two package
  managers is both at once: two independent dependency systems and a
  cross-language join, with no judgment relating the two joins. Survey
  this before claiming it is new.
- The paper's framing: the system is a heterogeneous join; actions are
  how its components make and use each other's parts; agreements are
  what must hold within a component and across a join; bugs are failures
  placed at one of them.

### 0.7 Where today's material lands

- **Understanding:** 0.1–0.4; the layers (the page's Table 6); actions
  as the edges of Figure 2; the agreements' kinds and bases (§4 below).
- **Handling:** enumerating the worlds the components admit (§3 below),
  running and checking them (§4), attributing a failure to a layer or a
  join (§5).
- **The bugs, by location:** the findings in §7 below, each placed at its
  layer or join. A table of them is the page's next addition.

## 1. Terms to settle first

- **The model's name, to decide.** The model is a square: two stacks
  (system, language), each management over artifacts, joined at the
  management level by the cooperation and at the artifact level by the
  binding, with the program on top. Candidates:
  - *the binding square*: names the shape and asks 0.3's question,
    whether it commutes; recommended;
  - *the two-stack model*: plain, but silent on the joins;
  - *the heterogeneous join*: better as the thesis than as the diagram's
    name.

  The layer names stay as the page has them: PM_sys, PM_lang, PM_coop,
  Art_sys, Art_lang, Binding, Program; "management" and "artifact" for
  the two levels; "join" for PM_coop and Binding.

- **"Artifact-to-package lift"** is the page's linking lift, **planned**.
  What exists: the two consumer programs, artifact-linked and
  package-linked, are nodes of the model, and z3 has both probes wired.
  The package-linked one is blocked by a publish bug (project
  issues.md §1). The claim between them, `package_resolution_suffices`,
  is a candidate with no evaluator. The design, which keeps a name apart
  from a resolution the package failed to provide, is overview.md §6.2
  step 5.

- **"NEED AN EXAMPLE"**: candidates, each drawn on the page (§3.4):
  - zarith: the conf-gmp bridge, whose own check a bridge step records,
    decided by `gate_admits_the_world`;
  - sqlite: a staged copy beside the build tree, and a Python binding
    included with the language;
  - llvm: `Opcode.UncondBr` — the released binding (LLVM 19) lacks what
    its example uses (LLVM 21 and later).

## 2. Material by the draft's sections

Each block keeps the draft's section number; §0.7 says where it lands
under the framing.

### §3 Practical enumeration

- **The pipeline** has six passes over four IRs (read
  `enumeration/pipeline.md`; `canary emit` prints each):
  1. declare, to the spec;
  2. analyse, to the analysis: which chains the spec admits, each
     language's mechanism, and which claims it can carry, all before any
     world exists;
  3. enumerate, to every world the project has;
  4. select, to what this run asked for (`--thin`, `--refs`);
  5. order, grouping worlds by the store state each one locks, since
     opam holds one version of a package per switch;
  6. realize, to the steps.

  §3.4's "collection pass" is passes 1–2. §3.5's uninstall-and-install
  cost is what pass 5 orders around.
- **Realize adds steps the project never wrote:** inspection steps that
  record evidence, placeholders, included steps and bridge steps. A
  run's record is its manifests (what each world realized), its
  `actions.log` and its inspections. The page's §1.2 shows one row per
  chain.

--

### §4 Principled checking

- **Categorizing agreements by layer is built.** Every agreement and
  candidate names the parts of the chain it relates, layer by layer, and
  the edges it sits on. The page's §2 opens with them by layer (Table 6),
  with the object formats each applies to; §2.1 shows where each is
  checked; §2.2 lists them edge by edge, with the four edges that carry
  no claim: `resolve_sys`, `realize_hdr`, `realize_cap`, `build_hdr`.
- **What is claimed: six kinds.**
  - admissibility: would one action have accepted these inputs together?
  - promise: is this artifact what its producer said it would be?
  - quality: is it sound on its own terms? (no agreement yet)
  - preservation: is it still the same after a transformation?
  - behaviour: does running it produce what was specified?
  - composition: a verdict over other verdicts.
- **Whose rule: four bases.** A toolchain rule, a project declaration, a
  compatibility policy, or a behavioural spec. §4.2's "what do we check
  against — t.b.c." is answered by the basis plus the evidence each
  method reads: a peer artifact, a declaration, or a staged copy.
- **Rooting and firing** are the R and D marks of page §2: where the
  tool's rule ran, and where the check runs. §4.1's "search of the lost
  agreement" is this: the rule runs at one action, and the evidence
  survives to a later one.
- **Landed, to cite in §4.3–4.4:**
  - symbols: `required_symbols_exported`, `declared_symbols_exported`;
  - library identity: `soname_matches_declaration`,
    `soname_matches_requirement`, `required_versions_exported`;
  - linking: `dependencies_provided`;
  - the staged copy: `staged_interface_preserved`;
  - the binding's surface: `api_names_present`;
  - the bridge: `gate_admits_the_world`, the first package-layer
    agreement, decided on zarith.
- **Not landed:**
  - `declared_versions_exported`: vacuous where nothing is declared;
  - `signatures_agree`: evaluated, no evidence yet;
  - `behavior_matches`, `repack_preserves_api`, `repack_complete`: no
    evaluator.
- **§4.3's "no local paths under the install profile"** is the candidate
  `no_build_paths_in_installed_library`, not yet registered.
- **§4.4:** OCaml has two mechanisms in the catalogue (cstubs, dynlink),
  and Python three (cext, ctypes, cffi). The draft says OCaml binds only
  through compiled C stubs. The mechanism decides which claims apply: a
  ctypes binding has no stub, so no stub claim.
- **§4.5–4.7's materials** point to `design/agreement/`, which is due a
  cleanup. Page §2 and `canary checks --agreement NAME` are current.

### §5 Attribution and blame

- **The word collision** in §1 of this doc.
- **"§4's seven sources"** predates the registry, which now has four
  bases and six kinds. Remap the bullets onto them.
- **What exists.** The draft's claim still holds: party-level blame is
  not implemented, and direction (forward, backward) is computed per
  world. New since then:
  - a check that cannot decide says why (the page's blame words);
  - an unavailable outcome carries a typed cause;
  - `--strict` fails the step that read a violation.
- **The cooperation as the blamed party** (the ncurses specimen) is the
  page's cooperation: a failure in the join, not in either artifact.

### §6 Implementation (empty)

- Page §0.2 is the architecture figure.
- The code's layers: base, agreement, tool, action, backend, then
  project and main.
- The checks (their counts: `canary overview --status`): the model tests
  (`project-test`); the framework tests (artifact, package-manager,
  mutation, cache); a round-trip gate that fails if a landed agreement
  stops deciding on sqlite; and the agents' harness, which holds the
  repository's own text to the code.
- Canary runs in its own opam switch, and the platform is carried, not
  sniffed.

### §7 Evaluation (plan)

- **Scale** (`canary overview --json` and the page):
  - 10 projects with runs, plus z3, muted and run separately;
  - 28 worlds and 42 chains;
  - 4 package managers with drivers, and 5 binding mechanisms;
  - 11 cooperation kinds, 7 with worlds;
  - a model of 16 nodes and 21 edges;
  - 14 registered agreements (9 landed) and 16 candidates.
- **Findings to verify before citing**, each with the layer or join it
  sits at (0.7):
  - Binding × Art_sys: z3's forward cell, symbols a HEAD binding requires
    that apt's libz3 lacks.
  - PM_coop: z3's both-released world, where the opam package ships its
    own libz3, so the declared apt library is never loaded; the actual
    join (absorbed) is not the declared one.
  - Binding × Art_sys: ssl, `dependencies_provided` violated on
    `libcrypto.so.3`.
  - Art_sys against its declaration: sqlite, where the built 3.43.2
    violates its own declared exports because the declaration cannot say
    "from 3.44"; the blame falls on the declaration.
  - PM_coop × PM_sys: zarith's conf-gmp gate, recorded (it holds).
  - PM_lang: torch, whose stock package does not build with dune 3.23.1;
    canary carries the one-line fix.
  - Binding × Art_sys, blamed on the cooperation (§5): ncurses. apt 6.4
    and conda-forge 6.6 agree on the soname, on all 463 exported symbols
    and on all ten version nodes, yet the vendored world segfaults. The
    binding's link line was frozen in Debian's shape (`-lncursesw
    -ltinfo`, pkg-config's answer there), and conda-forge splits tinfo
    into a narrow and a wide object, so ncurses' globals load twice. The
    candidate `no_duplicate_implementation` states it (project
    issues.md, 2026-08-25).
  - PM_coop: zstd. Its binding declares a bare `conf-zstd`, whose own
    build checks `pkg-config --atleast-version=1.3.8`, a floor that
    `opam show --field=depends` cannot see. The candidates
    `declared_gate_matches_package` and `gate_bounds_the_library` state
    it (project projects.md, 2026-08-20).
  - Art_sys: zstd again. Two packagings of libzstd export 177 and 297
    `ZSTD_` symbols with nothing removed, so a symbol count is packager
    policy, not API (projects.md).
  - Binding × Art_sys: sundials 6→7. The binding compiles its 6.x path
    against a 7.x library, because `configure` accepts the version
    syntactically and no 7.x guard exists: a real upstream bug, and the
    costliest to run, at 177 apt packages (plan.md).

  The 09-03 snapshot said zero upstream PRs; check.

### §8 Related work

- **Bridges across ecosystems:** opam's conf-* and depexts; Cargo's
  `*-sys` crates, with a capability file and no bridge.
- **The network analogy**, removed from the page. In a network stack
  both hosts run the same protocol at each layer, so a per-layer and an
  end-to-end invariant both have a contract to check against. Here the
  package layer's horizontal relation is a bridge someone wrote, or
  nothing, and a bridge may carry identity while dropping version: it
  forwards the address and drops the checksum. That is why the
  end-to-end claims are the ones missing.

## 3. Prose the page dropped that the paper may want

The restructure of 2026-09-29 cut comparisons and history from the
page's asides:
- the Cargo contrast;
- the network analogy;
- "a binding-level view cannot see a bridge, which is why the layered
  model exists".

Recover the earlier text with
`git show 36714267:canary/overview/page.html`.

## 4. Refreshing this doc

`canary checks --landing`, `canary overview --json`,
`canary overview --flow`, `make view`, `canary spec-check @all`.


### 5.4 Language bindings and their mechanisms

#### 5.4.1 Agreements for OCaml and its binding mechanism

OCaml has source code files for implementation and interfaces, as well as 
compiled modules for bytecode and native-code format.The OCaml toolchain 
provides tools for inspecting bytecode files. Platform tools can inspect native binaries.

OCaml binding mechanism to use native library is via compiled C stubs. A binding
module is compiled statically and can then be used like an ordinary module, either when
compiling a program or when loading it dynamically into a toplevel.

The official OCaml manual includes a section on creating bindings. However, how to 
ensure that a binding is constructed correctly, and which agreements are observed, is 
not explicitly stated, especially considering when considering different
ways of producing and consuming the native binary

Agreements within pure OCaml code are usually maintained because the relevant
files are shipped together in a common OCaml package. However, agreements
between the native C side and the OCaml side are usually maintained implicitly.

<!-- 
When an OCaml binding is created, agreements are established among the native
binary, the C header file and the OCaml C stub. When the binding is subsequently
used locally or delivered to users, static use requires agreement between the
binding and the C header and native binary that can be located.
 -->

#### 4.4.1 Agreements for Python

*Material: [component agreements](../design/agreement/components.md), §3.2.*

### 4.5 Versions, packaging and provenance

*Material: [component agreements](../design/agreement/components.md), §§4–5.*

### 4.6 Deployment and behavioural evidence

*Material: [component agreements](../design/agreement/components.md), §6.*

### 4.7 Registry integration and coverage

*Material: [agreement guide](../design/agreement/README.md), §§3–4;
[checker integration discussion](related/canary-practical-cross-language-bindings-report.md),
section 9; `src/canary/agreement/`.*


--- (should be in other doc)

**Aside: variants of (lambda) calculus**. In PL, there are variants of languages, e.g. pure
 lambda calculus, and lambda calculus with support or dissupport of natural numbers, integer,
 booleans, and any operations in and between them. Some entities and their operations are 
 algebraic and exist ahead of the computational model. We can also have other computational 
 devices for example, first-class language. The opens a perspective to see a concrete language
  is consisting of the computational side but not doing algebraic operations, and the algebraic
  (logic) side. The formar provides the variables, substitution, resolution, closures, which 
  all assitant to computational, and can be cmoposed to latters. This is an analogy of the 
  package management side, and the artifact inside of a package.

-- old 2.1 to check and delete

### 2.1 Rationale: perspectives and solutions

Given many involved artifacts and tools are real-world ad-hoc usage and solutions, 
we are lean to the practical analysis, which starts from the _actions_ in real-world, 
and identify the _agreements_ people wish to obey, and confirm or blame as 
experirenced programmers. We don't start from the specification of tools or artifacts, 
and we also don't target to provide any formal definitions or semantics.

We choose the practical approach, that experienced programmers may use to trigger 
real-world bugs, that is to consturct sanity check programming and run tools or commands. 
When treating it as a test generation issue, two questions are how to generate tests, 
and how to expect the results.

Seek for expectation is challenging for this herotegenous configurations. If 
a user encounters an misaligned function, who shall it blame, himself, the binding package, the system 
package, etc? We establish the perspective, which is also a theoretical model to understand the combination
for those components. Aside, this perspective also carry a diagram template to show both the generic 
workflow and any concrete running logs.