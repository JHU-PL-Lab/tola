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

One-line previews of the working principles. Three align with the
backbone (rules / concrete traces / abstract traces, introduced
below); one is orthogonal. Full discussion in §5.1 (MM).

- **Comparator + probe as complementary** — the rules-vs-traces
  duality: comparators check rules statically; probes observe
  traces at runtime.
- **Synthetic witness as scaffolding, not contribution** — the
  concrete-trace principle: tiny exists to witness each rule
  reproducibly, not to be the result.
- **Producer-agnostic framework** — the abstract-trace principle:
  a rule's robustness is measured across configurations drawn from
  natural producers (opam / pip / apt), not only hand-built ones.
- **Test the canary, not (just) the lib** — orthogonal to the
  backbone: an attitude about *what* we measure (the canary's
  response to the lib, not the lib in isolation).

### 1.4 Topics preview (roadmap)

Every topic the rest of the writeup touches, in a sentence each.
The reader should leave §1 knowing *what* is coming and *where*.

- **§2 Surface theory (SS).** **Artifact → surface → contract**
  along an explicit spine. The `s1..s6` surface roles and `c1..c7`
  contract catalogue with universal naming; the framework's
  openness to new checking targets (hidden deps, symbol versions,
  paths). The detailed catalogue + older drafts live in
  [`surface_draft/`](surface_draft/).
- **§3 Tiny (TT).** A controlled witness — mechanism-complete but
  material-naive — that exercises every rule. The 13-variant
  matrix and per-scenario detail live in [`tiny.md`](tiny.md).
- **§4 Canary (CC).** A producer-agnostic framework that scales
  the witness to natural producers (opam / pip / apt). Includes
  a methodological validation step against tiny's concrete
  traces.
- **§5 Miscellaneous (MM).** Working principles in full;
  packaging as a real-world trace source; versioning as
  cross-cutting; related work; calculus sketch.
- **§6 Implementation (Impl).** How the theory is realised in
  code: two engines (mutation, combinator), inspectors and check
  mechanisms, code-citation map, harness/canary boundary
  cleanness.

### 1.5 Organising grid

The writeup is organised along the **artifact → surface →
contract** spine (columns) crossed with the three pillars
(rows). Each cell names what that pillar contributes about that
concept; the table doubles as a reader's at-a-glance map and a
writer's gap-check.

**Table — Organising grid.** Three pillars × three spine
concepts; cell entries name what the pillar contributes.

|                  | **artifact**                                                                | **surface**                                                              | **contract**                                                                |
| ---------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| **theory** (§2)  | §2.1 — four kinds (Source/Lib/Binding/App); boundary as the only check site | §2.2–2.3 — presence axis (syntactic/semantic); six roles `s1..s6`        | §2.4 — `c1..c7` catalogue; contract = pinned pair of surfaces               |
| **tiny** (§3)    | §3.2 — concrete artifacts (libtiny.so, 3 bindings, helper)                  | §3.2 — each artifact populates `s1..s6` (full detail in tiny.md)         | §3.3 — 13-variant matrix: each perturbation breaks one rule                 |
| **canary** (§4)  | §4.1–4.2 stores abstraction; §4.6 natural producers                         | §4.4 — scan_sources places extraction in the pipeline (mechanism §6.2)   | §4.5 validation against tiny; §4.7 lifts real projects                      |

The spine has a clean PL parallel: artifact ↔ *expression*,
surface ↔ *type*, contract ↔ *run-time invariant / assertion* —
positioning surface theory as "a type system for binding
interfaces" (hook for §5.6 calculus sketch). A complementary
internal vocabulary names **rules** (the `c1..c7` catalogue —
agreements between surfaces) and the **traces** that observe
them in particular **worlds** (configurations of artifacts):
**concrete traces** are tiny + a controlled perturbation (single
reproducible witness, §3), **abstract traces** are worlds drawn
from per-kind stores (independent-producer combinations, §4); §6
covers how each shape is mechanically produced. The formal
scaffold (rule / world / trace definitions) is parked in
[`surface_draft/notation.md`](surface_draft/notation.md) until
the theory settles enough to need it.

---

## §2 — Surface theory

**Goal.** Develop the theory along the **artifact → surface →
contract** spine. Each piece gets a defined role, named
explicitly, before any commentary on the theory's properties.
The `s*` / `c*` universal naming is first-class. The framework's
openness to new checking targets closes the section.

### 2.1 Artifacts and the boundary

- Artifact kinds (Source, Lib, Binding, App).
- The boundary as the only thing tools see — every check happens
  at one.
- Tools rely on *implicit* assumptions about what's at the
  boundary; surface theory makes these assumptions **explicit**.
  (One sentence in place of the tool-surfaces table.)

### 2.2 What a surface is

- Definition: the observable properties an artifact presents at
  its boundary.
- **Presence axis** of the core vocabulary: a surface is either
  *syntactic* (declared — what the developer wrote or what tools
  recorded at link time) or *semantic* (extracted — what the
  binary actually presents).
- The gap (declared ≠ extracted) — what tools should catch but
  don't. Briefly; surface theory's job is to make these gaps
  visible.

### 2.3 The six surface roles

The boundary on each side splits into surfaces by *presence
axis* (syntactic / semantic) and, on the binding side, by
*layer* (stub-facing / user-facing). Six roles cover the binding
scenario:

**Table — Surface roles.** Six rows, one per surface — the
definitional view of *what surfaces exist*, with the universal
`s*` ids and formal `Σ_*` notation.

| id     | friendly name    | formal | side    | kind      | what it is                                                                 |
| ------ | ---------------- | ------ | ------- | --------- | -------------------------------------------------------------------------- |
| **s1** | `native_header`  | Σ_NH   | native  | syntactic | declared C interface — function signatures, structs, macros                |
| **s2** | `native_lib`     | Σ_NL   | native  | semantic  | compiled `.so` / `.dylib` — defined symbols, `@@VER`, SONAME, NEEDED       |
| **s3** | `binding_stub`   | Σ_BS   | binding | syntactic | binding stub-facing decls — `external` / `argtypes` / `PyMethodDef`        |
| **s4** | `binding_header` | Σ_BH   | binding | syntactic | binding user-facing module signature — `.mli` `val`s, Python module funcs  |
| **s5** | `binding_lib`    | Σ_BL   | binding | semantic  | compiled binding artifact — `.cmxa` + stubs `.a`, cext `.so`, ctypes (n/a) |
| **s6** | `runtime_trace`  | Σ_RT   | runtime | semantic  | observable call trace at runtime — probe input/output behaviour            |

- **Naming convention is load-bearing.** The `s*` identifiers
  (and the formal `Σ_*` notation for paper prose) are universal
  vocabulary across theory, tiny, and the canary code. Same names
  everywhere.
- **Language-side internal structure.** The binding side isn't
  one surface but several layers where *belief* can drift:
  stub-facing (s3) → repacking (one or more user-facing layers,
  surfacing as s4) → compiled artifact (s5). The compiled
  artifact is the natural check-target because every syntactic
  decision propagates into it.
- **Binding-mechanism axis** (orthogonal to the surface roles):

  **Table — Binding mechanism.** Three rows × resolution-phase
  columns. The surface roles are unchanged across mechanisms;
  only the materialisation timing differs.

  | Mechanism                     | Stub-facing materialized at | Link-time C refs in artifact | Symbol-resolution phase    |
  | ----------------------------- | --------------------------- | ---------------------------- | -------------------------- |
  | Static (cstubs, hand stubs)   | binding-build time          | yes                          | process link + load        |
  | Dynamic (ctypes, cffi, ffi.h) | binding-runtime             | no                           | runtime `dlopen` + `dlsym` |
  | Hybrid (JIT'd stubs)          | varies                      | varies                       | varies                     |

  Every mechanism has the same `s1..s6`; only the materialisation
  timing differs.
- **Scoping.** The c-api binding mechanism is *one* instance of
  the rule schema. Other instances (ctypes, Rust FFI, JNI, …)
  fit the same theory but aren't covered in depth here.

### 2.4 Contracts

An **explicit contract** is an agreement pinning two surfaces.
This is the *agreement axis* of the core vocabulary; paired with
**behavior** as the runtime presentation a contract ultimately
tests (echoing *behavioral subtyping*, used here as the runtime
counterpart to declared agreement).

Seven contracts cover the foundational picture. The catalogue is
**one canonical table** — surface pairs, kind, and where each
fires:

**Table — Contract catalogue.** Seven rows × five columns
(contract, provider surface, consumer surface, kind, where it
fires). The universal `c*` ids are the cross-cutting names used
in theory, tiny scenarios, and canary code.

| Contract                | Provider surface                                | Consumer surface                                            | Kind                                  | Where it fires                                 |
| ----------------------- | ----------------------------------------------- | ----------------------------------------------------------- | ------------------------------------- | ---------------------------------------------- |
| **c1 Symbol**           | **s2** `native_lib` — defined symbols           | **s5** `binding_lib` — link-time refs / `dlsym`             | semantic ↔ semantic                   | process link (static) / process load (dynamic) |
| **c2 API-completeness** | **s4** `binding_header`                         | app expectations (watchlist or imports)                     | syntactic ↔ syntactic (within lang)   | app build / probe                              |
| **c3 Behavior**         | **s6** `runtime_trace` (provider's invocation)  | **s6** `runtime_trace` (consumer's wrapper)                 | semantic ↔ semantic                   | runtime                                        |
| **c4 ABI**              | **s2** `native_lib` — SONAME, version-needed    | **s5** `binding_lib` — NEEDED entries                       | semantic ↔ semantic                   | process load                                   |
| **c5 SymbolVersion**    | **s2** `native_lib` — `@@VER` annotations       | **s5** `binding_lib` — `@VER` requirements                  | semantic ↔ semantic                   | process load                                   |
| **c6 Type**             | **s1** `native_header` — C signature            | **s3** `binding_stub` — `external` / `argtypes` / decl      | syntactic ↔ syntactic                 | binding build                                  |
| **c7 API-repacking**    | **s3** `binding_stub`                           | **s4** `binding_header` — module signature                  | syntactic ↔ syntactic (intra-binding) | binding-author time (probe-checked today)      |

- **Universal naming.** `c*` identifiers used in theory, tiny
  scenarios, and canary code — same names everywhere.
- Two contracts (c2 API-completeness, c7 API-repacking) are
  *entirely within the language side*; the other five cross the
  native ↔ binding boundary.
- **API-repacking (c7) and API-completeness (c2) are checked via
  probe today; static check is future work.** Their entries in
  the catalogue exist; their static comparators don't yet (c7
  for stub-facing layers across all binding mechanisms; c2
  partly covered by watchlist + `Expect_compat_failure`).
- ~~c8 API-faithfulness~~ was retired (2026-06-03) as a contract
  because each binding is independent; cross-binding consistency
  isn't a canary-side agreement.

### 2.5 Extending the framework

- The `(surface, contract)` machinery is **open** — new checking
  targets slot in without changing the framework.
- Concrete extension targets:
  - **Hidden dependencies** (glibc / musl as the canonical case):
    a surface requirement not declared in headers but present in
    NEEDED / `@@VER`. Caught by the same comparator pattern as
    declared symbols. (Absorbs former §5.4.)
  - **Symbol versions**: already extensively checked (c5).
  - **Path resolution**: to-do — the loader's filename →
    artifact resolution is another surface to make explicit.
- **Completeness-by-construction.** The framework is complete
  with respect to "is this binding compatible with this library?"
  precisely because new failure modes slot in as new
  (surface, contract) pairs. The list of targets above is
  illustrative, not exhaustive.

### 2.6 Properties of the theory

(Comments on the theory, presented after the theory itself has
something to refer to.)

- **Contract-vs-check independence.** A contract is the
  agreement; a check is one possible implementation (static
  comparator, runtime probe, binding-side test, compile
  failure). One contract can be checked by several mechanisms;
  one mechanism can serve several contracts (c3 probe runner
  also detects c7). Attribution lives at the variant
  declaration, not the detection layer. Cross-reference from
  §6.3 (the implementation realises both mechanisms cleanly).
- **Static / dynamic axis.** Some contracts are statically
  detectable (set diff, type match); others manifest only at
  runtime (probe-assertion refutation). This is an
  *implementation* axis, not a contract axis.
- **Refinement lattice.** Contracts have an order
  (`SymbolVersion ⊑ Symbol`; API-faithfulness derives from
  Type ∧ Symbol ∧ API-repacking). Operationally, comparators
  are a *flat* implementation of selected lattice points.
- **Satisfaction.** A configuration satisfies a contract set
  conjunctively: every contract must pass for every refinement.

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
canonical-source-of-truth nowhere else (packaging, versioning).
Hidden dependencies, originally slated here, moved to §2.5 as an
example of the framework's extension targets. The "extensions"
pattern from PL papers is **held in mind** here — we may or may
not commit to it as prose lands.

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
- Glibc / musl as one canonical example.
- Why this gets its own section: it threads through SS, TT, and
  CC equally. (Hidden dependencies, which are also cross-cutting,
  moved to §2.5 as an example of the framework's extension
  targets.)

### 5.4 Extensions [held in mind]

- PL-paper convention: a section enumerating directions of
  generalisation (other binding mechanisms — ctypes / Rust FFI /
  JNI; other ecosystem types; other validation engines).
- **Held in mind only.** Commit to a subsection if prose ends up
  needing it; otherwise the extensions get inlined where
  relevant.

### 5.5 Related work

- Compiler correctness, type-preserving compilation, linking
  calculi, ELF semantics, FFI semantics, ABI tooling.

### 5.6 Calculus sketch

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
