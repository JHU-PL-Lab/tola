# Surface — manuscript-in-progress

> Manuscript. See [`drafting.md`](drafting.md) for materials,
> playbook, and the front-matter-in-waiting.

## §1 — Background & Motivation (BB)

**Goal.** Reader-facing opener. Motivation + approach + principles
preview + a topics preview that names every later topic in a
sentence or two. A reader who only reads §1 should know what
canaries are for, what surface theory claims, what tiny argues,
what canary does on real-world packages, what topics MM gathers,
and that an implementation chapter sits at the back.

### 1.1 Motivation: real-world gaps

- **Ubiquity.** Real-world projects with multi-language bindings
  are critical infrastructure (torch, llvm, z3, …) and
  error-prone in characteristic ways.
- **Why error-prone.** Many tools and layered systems; tools are
  largely unspecified and update frequently; package managers can
  swap random components; many actors (project developer, package
  maintainer, registry admin) each with limited cross-domain
  knowledge; blame attribution across the chain is hard.
- **Concrete contract-drift in practice.** LLVM `Opcode` shift
  between versions, Z3 Python wheel missing `parser_context`,
  glibc/musl symbol-versioning surprises, cross-PM SONAME
  inconsistencies.
- **Why these drifts evade existing testing.** Bindings test
  their own integration; package managers test packaging; but no
  one tests the *contract surface* between provider and consumer.
- **Reader-facing question.** "If a binding compiles and a smoke
  test passes, is the artifact actually consistent with its
  provider?"

### 1.2 Approach: rules and traces

- **Starting observation.** Existing tools are behavior-based;
  actions are chains of involved tools; tools are best-effort, so
  flaws may surface only at late stages. We need a way to test
  the chain's *agreements*, not just each tool's outputs.
- **Surfaces and rules — a spec space.** Surfaces are the
  observable interfaces (declared or extracted) at each artifact
  boundary; tools rely on and use these surfaces. Rules pin pairs
  of surfaces and say what counts as agreement.
- **Worlds and traces.** A configuration of artifacts is a world;
  a trace is an observed verdict — either the rule holds or it
  doesn't. Tiny gives controlled worlds we hand-build; canary
  scales to worlds we don't control, drawn from natural producers.
- **Producer-agnostic by design.** The same rules and the same
  framework apply to synthetic worlds (tiny) and natural worlds
  (opam / pip / apt).
- This subsection promotes the §Backbone framing into a
  reader-facing paragraph; ~150 words.

### 1.3 Principles preview

One-line previews of the working principles. Full discussion in
§5.1 (MM).

- **Test the canary, not (just) the lib.**
- **Comparator + probe as complementary.**
- **Synthetic witness as scaffolding, not contribution.**
- **Producer-agnostic framework.**

### 1.4 Topics preview (roadmap)

Every topic the rest of the writeup touches, in a sentence each.
The reader should leave §1 knowing *what* is coming and *where*.

- **§2 Surface theory (SS).** Rules over surfaces — what counts
  as agreement. The c1..c7 catalogue, the six surface roles, and
  the spec-space framing. The detailed catalogue + older theory
  drafts live in [`surface_draft/`](surface_draft/).
- **§3 Tiny (TT).** A controlled witness — mechanism-complete but
  material-naive — that exercises every rule. The 13-variant
  matrix and per-scenario detail live in [`tiny.md`](tiny.md).
- **§4 Canary (CC).** A producer-agnostic framework that scales
  the witness to natural producers (opam / pip / apt). Includes
  a methodological validation step against tiny's concrete
  traces.
- **§5 Miscellaneous (MM).** Working principles in full;
  packaging as a real-world trace source; versioning as
  cross-cutting; hidden dependencies; related work; calculus
  sketch.
- **§6 Implementation (Impl).** How the theory is realised in
  code: two engines (mutation, combinator), inspectors and check
  mechanisms, code-citation map, harness/canary boundary
  cleanness.

---

## The backbone: rules, traces, worlds

A **rule** says what counts as agreement between two surfaces
(the `c1..c7` catalogue). A **world** is a configuration of
artifacts; a rule is either satisfied or violated in a given
world. A **trace** is an observed verdict — the rule's status on
a particular world.

Two trace shapes do complementary work:

- **Concrete trace.** A specific world we construct by hand:
  tiny + a controlled perturbation. Each rule has at least one
  concrete trace witnessing a violation — a single, reproducible
  failure.
- **Abstract trace.** A world drawn from per-kind candidate sets:
  one artifact per kind, sourced independently. Canary's variant
  matrix is a structured walk over the abstract-trace space; the
  same shape applies to natural producers (opam / pip / apt).

The PL analog:

| Concept             | PL analog                | Canary instantiation                                          |
| ------------------- | ------------------------ | ------------------------------------------------------------- |
| **rule**            | inference rule, property | e.g. "binding's referenced symbols ⊆ lib's exported symbols"  |
| **concrete trace**  | one program execution    | tiny + a perturbation: one observed verdict on a fixed world  |
| **abstract trace**  | the execution space      | a configuration drawn from per-kind stores                    |

A rule is robust when both trace shapes expose it. Concrete
traces give **depth** — controlled, reproducible witnesses;
abstract traces give **breadth** — configurations that arise from
independent producers, beyond what hand-construction can reach.

This maps the §2–§4 arc: §2 names the rules; §3 covers the
concrete-trace witness (tiny); §4 covers the abstract-trace
framework (canary), including a validation step against tiny's
concrete traces along the way. How each shape is mechanically
produced is **§6 Implementation**.

The PL notation scaffold (formal rule / world / trace definitions)
is parked in [`surface_draft/notation.md`](surface_draft/notation.md)
until the theory settles enough to need it.

---

## §2 — Surface theory

**Goal.** Define the conceptual framework. Set up what a "Contract
at a surface boundary" is, why this slicing is useful, and which
Contracts the rest of the paper will reason about.

### 2.1 Framing — what problem this addresses

- 1-paragraph motivation: where contract drift bites in practice
  (binding / library / loader chains).
- The shape of the question: which surfaces agree on what, when.
- **Scoping (instances of the rule schema).** The c-api binding
  mechanism is *one* instance of the rule schema. Other instances
  (ctypes, Rust FFI, JNI, …) fit the same theory but aren't
  covered in depth here.
- **Core vocabulary.** Two axes pair up:
  - **Surfaces (presence axis).** Each surface is either
    *syntactic* (declared — what the developer wrote, or what
    tools recorded at link time) or *semantic* (extracted — what
    the binary actually presents). The s1..s6 roles in §2.2 are
    classified along this axis.
  - **Agreement axis.** A **contract** is the invariant tools
    wish to agree on and hold across two surfaces. **Behavior**
    is the run-time presentation that a contract ultimately
    tests — echoing *behavioral subtyping* (used here as the
    runtime counterpart to declared agreement, not in the full
    Liskov / refinement sense).
  - "**Belief**" appears in §1 BB as softer motivational language
    for contract; not first-class in §2 SS.

### 2.2 The surface roles `s1..s6`

- The six roles (header / lib / stub-facing / user-facing / etc.).
- Diagram + naming convention.

### 2.3 Contracts at boundaries

- Each Contract pins a relationship between two surfaces.
- Brief tour of the contract list (c1..c7 active; c8 disabled).
- The §3.4 status table as a load-bearing artifact.

### 2.4 The static / dynamic axis

- Some Contracts are statically detectable (set diff, type match);
  others manifest only at runtime (probe-assertion refutation).
- This is an *implementation* axis, not a Contract axis.

### 2.5 Contract vs check — the independence axis

- A Contract is the agreement. A check is one possible
  implementation (static comparator, runtime probe, binding-side
  test, compile failure).
- One Contract can be checked by several mechanisms; one
  mechanism can serve several Contracts (c3 probe runner also
  detects c7).
- Attribution lives at the variant declaration, not at the
  detection layer.

### 2.6 Worked examples in prose

- Pick 2–3 representative Contracts (probably c1 Symbol, c4 ABI,
  c7 api_sound_repack) and walk through each: which surfaces it
  binds, what a violation looks like, what check would detect it.

---

## §3 — Tiny: the controlled witness

**Goal.** Show that the theory is non-vacuous. Tiny is a minimal
testbed with a hand-controlled perturbation budget; every active
Contract has a witness scenario.

### 3.1 Why a synthetic witness

- **Tiny's role: pivot.** A *pivot* — canary/smoke testing for
  tools and systems. Aims to be **mechanism-complete but
  material-naive**: every binding mechanism, every relevant tool,
  every layer of the system is exercised; the library content is
  intentionally minimal.
- The methodological case for building tiny rather than starting
  with a real library: control. We can perturb a single surface
  at a time and read off which rule fires.
- **Coverage targets.** Languages, package management tools (a
  known gap in tiny's code today), binding mechanisms,
  compilation, linking, loaders. Running is the ultimate check;
  tiny exists so we can run it deterministically.
- If tiny passes both positive and negative cases, every concrete
  trace aligns with surface theory for the mechanisms tiny covers.

### 3.2 Anatomy of tiny

- C lib + 3 bindings (OCaml cstubs, Python cext, Python ctypes) +
  downstream `tiny_helper`.
- One-paragraph tour; refer reader to `tiny.md` for the full spec.

### 3.3 Perturbations and the 13-variant matrix

- The harness ↔ canary mapping table (13 entries) is the load-
  bearing artifact.
- Each row: which surface is perturbed → which Contract fires →
  which check mechanism caught it.
- Honest split: comparator-driven rows (c1/c2/c4/c5/c6) vs
  probe-runner rows (c3/c7).
- *How* perturbations are mechanically produced is §6.1 (the two
  engines).

### 3.4 What tiny demonstrates and what it doesn't

- **Demonstrates.** Every active rule has at least one fire.
- **Doesn't (mechanism scope).** Real-world ABI complexity (no
  actual glibc); typed inspectors are tiny-specific; cross-binding
  consistency intentionally not pursued; **package management
  tools are not yet wired into tiny's code** — known gap to
  surface and eventually close.
- **Doesn't (material scope, out-of-assumption).** Tiny cannot
  exhaustively cover all compile flags, Linux releases, compiler
  versions, libc variants. These are explicit out-of-assumption
  unless a specific test calls them out. The witness argues the
  *mechanism* is real; the *materials space* is acknowledged as
  out-of-scope.
- Setting honest expectations early serves the paper.

---

## §4 — Canary

**Goal.** Describe canary as a **store / runner / producer**
parameterised framework that consumes per-kind artifact stores.
The contribution is producer-agnosticism: the same framework works
whether stores come from tiny's harness or from natural package
managers (opam / pip / apt). The chapter walks the framework's
design, its methodological validation against tiny's concrete
traces, then its application to natural producers. How the
framework is realised in code (inspectors, check mechanisms,
engine boundary) lives in §6 Implementation.

### 4.1 The three concerns

- **Stores** — content-only abstractions providing artifacts of
  declared kinds. No state of their own beyond "here are some
  files."
- **Runners** — project-spec-driven pipelines that read from
  stores, exercise checks, emit logs into a shared output dir.
- **Producers** — populate stores. Tiny's harness is one
  producer; opam / pip / apt are others.

### 4.2 Per-artifact-kind stores

- `tiny_stores = { source ; lib_dir ; python_cext_root ;
  lib_filename }`.
- Each variant picks a store config; cross-products fall out
  naturally.
- One store per surface kind, not one store per scenario.

### 4.3 The spec model as parameterisation

- `make_*_script_spec ~stores` and `?probe_exe`.
- Variants as parameterised specs, not enum tags.
- The spec is uniform across variants; the producer-specific
  mapping lives outside the spec.

### 4.4 Scan_sources as polymorphic placement

- Source-derived inspects need to run before any build step that
  might fail. `scan_sources_after` lets projects declare placement.
- Matters for real projects (z3-style generated bindings need the
  post-build-lib placement).

### 4.5 Validation against tiny — the credibility bridge

- Canary's variant matrix walks the abstract-trace space generated
  by tiny's per-kind stores.
- The methodological step: if canary reproduces every concrete
  trace tiny declares (and rejects what tiny says should pass),
  the framework is sound for the rules tiny exercises.
- Implementation factoring and known leaks tracked in
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md);
  the manuscript view sits in §6.5.

### 4.6 Application to natural producers

- The bridge sentence: tiny's harness IS a package manager that
  ships perturbed artifacts. opam / pip / apt are the natural
  cases; the framework treats them the same.
- Stores become package-manager artifact trees: opam switch lib
  dirs, pip site-packages, apt install paths.
- Producer-agnosticism falls out by construction.

### 4.7 Real-project case studies

- llvm: the existing `Opcode.UncondBr` demo (c2 OCaml) lifted to
  the post-Phase-15 framework.
- z3: the existing `parser_context` demo (c2 Python) lifted.
- sqlite: candidate for c4 (Homebrew vs apt SONAME differences).
- For each: what perturbation surfaces, which rule fires.

### 4.8 What's needed to write this section honestly

- Lift the existing real-project specs (z3, llvm, sqlite) through
  the post-Phase-15 framework before §4.6 / §4.7 can be honest.
- "Real-project audit" — the work the project paused for.

---

## §5 — Miscellaneous (MM)

**Goal.** A deliberately loose gather for topics that don't fit the
SS / TT / CC spine cleanly. Some live here permanently (working
principles in full, related work, calculus sketch); some are
cross-cutting concerns visible from all three pillars but
canonical-source-of-truth nowhere else (packaging, versioning,
hidden dependencies). The "extensions" pattern from PL papers is
**held in mind** here — we may or may not commit to it as prose
lands.

### 5.1 Principles (full discussion)

- Expand each principle from §1.3 with rationale, alternatives
  considered, prior art.
- Likely additions over §1.3 previews: implementation hygiene
  notes (when they matter for the methodological claim); scoping
  principles (mechanism-complete material-naive).

### 5.2 Packaging as a trace source

- **Reframe.** Packaging isn't an extension of the framework; it's
  what gives natural producers their real-world trace possibility.
  From the rule/trace perspective, packaging is the engine that
  populates abstract-trace stores in practice.
- Co-providers, multi-PM scenarios, pip-wheel-bundling-native-lib
  cases (PyTorch-style).
- A future `package_theory.md` is one home; covering it as a
  section in §5 is another.

### 5.3 Versioning as cross-cutting

- Versioning isn't a single rule — it cuts across c1 Symbol, c4
  ABI, c5 SymbolVersion, and the version-script work.
- Glibc / musl as the canonical example.
- Why this gets its own section: it threads through SS, TT, and
  CC equally.

### 5.4 Hidden dependencies

- Glibc / musl as the hidden C-runtime dep.
- Why hidden deps matter for canaries — they show up only at the
  runtime layer, after every static check has passed.

### 5.5 Extensions [held in mind]

- PL-paper convention: a section enumerating directions of
  generalisation (other binding mechanisms — ctypes / Rust FFI /
  JNI; other ecosystem types; other validation engines).
- **Held in mind only.** Commit to a subsection if prose ends up
  needing it; otherwise the extensions get inlined where
  relevant.

### 5.6 Related work

- Compiler correctness, type-preserving compilation, linking
  calculi, ELF semantics, FFI semantics, ABI tooling.

### 5.7 Calculus sketch

- Speculative formal direction; depth depends on venue.

---

## §6 — Implementation (Impl)

**Goal.** How the theory is realised in code. Two engines
(mutation, combinator), the inspectors and check mechanisms,
where each piece lives in the canary tree, and the boundary
between harness (tiny's producer) and canary (the runner). Skip
this chapter if you only want the conceptual narrative.

### 6.1 The two engines

Where harness and canary plug into the rule/trace framework. The
slots aren't part of the theory; they record how each piece is
realised today.

| Slot                | Mutation engine (harness on tiny)                 | Combinator engine (canary)                                             |
| ------------------- | ------------------------------------------------- | ---------------------------------------------------------------------- |
| **World shape**     | one source tree, all artifacts derived from it    | per-kind stores, independently sourceable                              |
| **World build**     | `scenarios.py apply` / `revert` (mutate in place) | spec-driven cross product (variant matrix in `canary_project_tiny.ml`) |
| **Trace**           | mutation `μ`: patch one surface, rebuild          | configuration `W`: pick one artifact per kind from stores              |
| **Verdict (pred.)** | `confirm_ill.json`                                | `Expect_compat_failure`                                                |
| **Verdict (obs.)**  | `probe.log`                                       | `actions.log`                                                          |
| **Code locus**      | `canary/examples/tiny/scenarios/`                 | `src/canary/projects/canary_project_tiny.ml` + action graph            |

The two engines validate the same rules from opposite directions:
mutation gives depth (controlled, reproducible perturbations);
combinator gives breadth (configurations sourced from independent
producers).

### 6.2 Inspectors and the `inspect_input` ADT

- Comparators consume JSON; agnostic to how the JSON was produced
  (real AST tool, regex grep, `nm` output, …).
- The ADT cases each correspond to a typed view (`C_stub`,
  `Native_lib`, `Typed_header`, …).
- This decoupling is what makes the framework producer-agnostic.

### 6.3 Check mechanisms

- Static comparators: predict failure substrings from cached
  JSONs; runner greps probe.log for them.
- Probe runner: `Expect_failure { contains_any }` matches against
  embedded assertions in the probe binary.
- The two mechanisms are independent; some rules use one, some
  the other, occasionally both.

### 6.4 What's general vs what's framework-private

- General: store model, spec model, scan_sources, inspect ADT,
  comparator / runner layering, producer-agnosticism.
- Framework-private: hardcoded-grep inspectors
  (`inspect_tiny_typed.py`), workspace-materialisation fixups —
  details in
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md).

### 6.5 Engine boundary cleanness

- The mutation engine (harness) and combinator engine (canary)
  must stay operationally separate so the methodological claim
  ("two independent engines validate the same rules") is honest.
- Where the boundary leaks today (e.g. `_snapshot_workspace`'s
  RUNPATH-strip and libtiny.so symlink synthesis) is tracked in
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md).
- Phase 16's refactor goal: close those leaks.

### 6.6 Code-citation map

- Pointers to the OCaml + Python files that realise each piece
  of the framework: `canary_project_tiny.ml`,
  `canary/examples/tiny/scenarios/scenarios.py`,
  `inspect_*.py`, `canary_compat.ml`, etc.
- Mirrors `surface_draft/implementation.md` §2.7 from the
  materials collection; the manuscript version is reader-facing
  and trimmed.
