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

> maybe we need an user text observation or movitation to refer

<!-- **Ubiquity.** --> Real-world projects with multi-language 
bindings are critical infrastructure (torch, llvm, z3, …) and 
error-prone in characteristic ways.

<!-- **Why error-prone.** --> Many tools and layered systems; tools 
are largely unspecified and update frequently; package managers 
can swap random components; many actors (project developer, package 
maintainer, registry admin) each with limited cross-domain knowledge; 
blame attribution across the chain is hard.

<!-- **Versatile Agreements.**Starting observation.** --> We observe
these tools follows some 
agreements, however, there are far from formal and even explicit spefication. 
It's also infeasible since some agreement is behavior-determined, so 
we may have to live with them. LLVM `Opcode` shift between versions,
Z3 Python wheel missing `parser_context`, glibc/musl symbol-versioning 
surprises, cross-PM SONAME inconsistencies.

<!-- **Why these drifts evade existing testing.** --> Bindings test
their own integration; package managers test packaging; but no
widely and principly tests for the full-chains between provider 
and consumer. **Reader-facing question.** "If a binding compiles and a smoke
  test passes, is the artifact actually consistent with its
  provider?" Existing tools are behavior-based;
actions are chains of involved tools; tools are best-effort, so flaws 
may surface only at late stages. We need a way to test the chain's *agreements*
, not just each tool's outputs.

**The pipeline runs on courtesy.** Real-world package management
doesn't ship with strict specifications. Some boundary errors get
rejected by tools (a missing symbol fails the link); others are
tolerated (a missing dependency that isn't exercised at load time
looks healthy until it isn't). The tolerated errors become
critical only at later stages, once usage finally touches them.
The whole binding pipeline runs on mutual *courtesy* — each tool
relies on conventions it can't enforce. Our research detects and
confirms the conventions tools depend on (usually tool
*behaviours* rather than written specs), establishes them as
**rules**, and constructs the **smallest-but-representative**
scenarios that try to be complete with respect to the rule
catalogue.

For the artifacts in the binding chains, we observe the no things come
and go for free (without a source), and we also observe that there
is already extra tools that we can use to inspect into the things,
no matter whether its source code or native binary.

### 1.2 Approach

> **sw** up to §2, we don't discuss the necessary and effective of
> why using surface checking; thought the idea is very simple, a 
> failing bug can often by find by a simpler check based on the 
> belief(agreement) on surface
> **sw** maybe we should also discuss the category of bugs

Our approach is guided by two movitations that common used in testing:
(1) to find a smallest example
(2) to find an easier check
For (1) the smallest example mean, if our work can a bug appearing 
on a complex project is caused by the mechanism of any stage for the binding
scernario, rathan than the project itself, oue work must be first
find the same bug that appearing in a synthesis naive project
(2) if a bug occurs in a step of a compound task e.g. building a project,
or running a test, it should be also detect via an easy approach.

We propose a surface theory which address the issues in real-world 
via a PL-perspective modeling and reasoning. Informally, we would 
treat all the related _artifacts_ and tools are records or tools on 
records.

An artifact natually carries a _surface_. For source-code like 
artifact, e.g. C file with a header file, the header file is a 
syntactical surface. For the compiled object getting from the same 
C file, it has a binary surface where a binary tool can inspect.

We argue that a majority of real-world bugs can be detect on the 
surface level inspectation. For example, a missing symbol in 
compiling, API mismatch on binding language, should all imply
some _agreements_ on the surface are violated.

### 1.3 Organising grid

**Table — Organising grid.** Three pillars × three spine
concepts; cell entries name what the pillar contributes.

|                  | **artifact**                                   | **surface**                                                  | **invariant**                                                |
| ---------------- | ---------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| **theory** (§3)  | §3.1 — artifact and its boundary               | §3.2–3.3 — surface and the role catalogue                    | §3.4 — agreement between two surfaces                        |
| **tiny** (§2+§4) | §2 + §4 — controllable instantiation           | §2 touchstone; §4 expands binding-mechanism diversity        | §4.2 — every agreement perturbed and broken, one at a time   |
| **canary** (§5)  | §5.1–5.2 stores; §5.6 natural-producer sources | §5.4 — extraction from real-world artifacts (mechanism §7.2) | §5.5 validated against tiny; §5.7 exercised on real projects |

**TODO**: maybe I don't need S4. We can go over all the examples of tiny in S2.

The motif(rationale) from artifact, surface, agreement is like the PL 
analogy of _expression_, _type_, and _constraint_. Since they are across 
multiple languages toolchains and have to use platform tools, we can 
hardly have a soundness tool; instead, we target a complete checking, 
that is like testing.

We also organize the whole writeup as a repeating motif that on a 
theory layer, where we estabilish our definitions, rules, and assumption.
The framework provides a complete but small example _tiny_. It's a 
demonstrative summation code from C to language bingings we covered.
The canary testing covers the scenarios from the creation, delivery 
and usage for the upstream, binding, packaging and user site. We covered
the common mechanism via static C API binding, however, it's full extensible
to support any mechanism like dynamic ctypes. A quick glance and a fully
explanation for tiny will be illustated in §2 and §4 respectively 
for writing purpose.

Unlike many research which is established on theretical truth, the canary is 
based on beliefs on a set of designed behaviors (generalized testing) of
tool operations. We will first comprehensively run all the interested 
scanarioe steps to ensure the expected results. Then we mutates all 
the artifacts on purpose to emulator possible errors that can occur in 
real-world, and we will use the tools to inspect and detect these bugs.
All these positive and negative established a set of ground truth, that this
set of tools can empirically justify the tools we will conduct on
other real-world examples.


**sw**: a bit distrated for the last two sentences. Maybe can move to later places
The work focuses on things around upstream projects and their bindings in
different languages, and we maximize the combinations in those components; 
however, we cannot emunerate any possible combinations of versions and
configurations for C compilers, system loaders and linkers, binary utilies 
on different systems. If the tools can detect our dedicated perturbated
error in tiny e.g. one mismatch between binding and stub APIs, we assumes that
it should also be able to find the real-world project having the 
same case; however, we cannot assume the tools we have to use it reliable.

### 1.5 Topics preview (roadmap)

Every topic the rest of the writeup touches, in a sentence each
— a prose elaboration of the grid above. The reader should leave
§1 knowing *what* is coming and *where*.

- **§2 Tiny-tiny: running example.** The minimal touchstone — one
  C library, one OCaml binding, one const + one function — with
  six snippets (Sn.1…Sn.6) the rest of the writeup refers to by
  id. Built so §3's theory tables have a concrete anchor.
- **§3 Surface theory (SS).** **Artifact → surface → contract**
  along an explicit spine. The surface roles and contract
  catalogue with universal naming; the framework's openness to
  new checking targets (hidden deps, symbol versions, paths).
  The detailed catalogue + older drafts live in
  [`surface_draft/`](surface_draft/).
- **§4 Tiny-complete (TT).** The full witness — three binding
  mechanisms (OCaml cstubs + Python cext + Python ctypes), a
  downstream `tiny_helper` app, and packaging considerations.
  Includes the 13-variant perturbation matrix; per-scenario
  detail in [`tiny.md`](tiny.md).
- **§5 Canary (CC).** A producer-agnostic framework that scales
  the witness to natural producers (opam / pip / apt). Includes
  a methodological validation step against tiny's concrete
  traces.
- **§6 Miscellaneous (MM).** Working principles in full;
  packaging as a real-world trace source; versioning as
  cross-cutting; related work; calculus sketch.
- **§7 Implementation (Impl).** How the theory is realised in
  code: two engines (mutation, combinator), inspectors and check
  mechanisms, code-citation map, harness/canary boundary
  cleanness.

---

## §2 — Tiny-tiny: a running example

The motivation of tiny example is to provide a comprehensive 
artifacts with their surfaces, and possible scenarios that other
projects may encounter. The backbone of a working tiny example
is very simple: a C library and language bindings. In the examples,
we will go through all the artifacts, surfaces and agreements,
while in the next sections we will discuss them abstractly. Packaging
brings another layer of indirection freedom, and we will discuss them 
after going through the workflow without packages.

<!-- upstream side -->

**sw** we need a per-side artifact, surface, and agreement summary
also to emphasize the record-like structures.

**Sn.0 — `tiny.c`** (a1 native_source, syntactic).

```c
/* tiny.c */
#include "tiny.h"

int tiny_offset = 42;

int tiny_sum(int a, int b) {
    return a + b + tiny_offset;
}
```

**Sn.1 — `tiny.h`** (s1 native_header, syntactic).

```c
/* tiny.h */
extern int tiny_offset;
int tiny_sum(int a, int b); 
```

Tiny as a upstream project provides implementation and header files.
Compiling to native library correctly will generate a shared native library. For concise we assume it's on linux, so that we use `.so` file for this kind of library interactively.

When looking closely, even for the step up to now can reveal the 
error patterns that real-world project may encounter. e.g. upgraded 
but mismatched `tiny.h`, unspecified hidden dependented libraries, mis-used compiler flags. Real-world package managers usually have 
the flexibitility to put arbitrary files in a package, so every file 
can be wrongly placed and used.

The native library is in ELF format on common linux machine, and other binary format on other platforms. Despite its details, there 
are usually dedicated binary utilities we can inspect them.

**Sn.2 — `libtiny.so.1` inspected** (s2 native_lib, semantic).

```console
$ nm -D libtiny.so.1
00001234 D tiny_offset       (OBJECT)
00005678 T tiny_sum          (FUNC)

$ readelf -d libtiny.so.1 | grep SONAME
 (SONAME)   Library soname: [libtiny.so.1]
```

We can observe that we can see the symbols and other information, 
and we can also find the symbols appearly forms a record-like structure 
which is alike the C header file `{tiny_offset : OBJECT; tiny_sum: FUNC}`.

The artifact includes _native\_source_ (a1/s1), _native\_header_ (a2/s2), and 
compiled _native\_lib_ (a3/s3).
For source-like artifact, their surface is in text format, while for binary artifact, 
the surface is constructed from the inspectors' result.

**sw** the id are global indexing in both writeup and code. The n-th artifact 
and the coresponding n-th surface.

When the actual building step succeed, their surfaces must agree with 
each other. Some agreement are interal to a language with its compiler, 
usually when a language is typed. If they broken, the toolchain complains
immediately. Some agreement involves tools from multiple languages or
systems. If they broken, they may be realized later or never, and they 
may not have written constraints. Compilers check the validity of native 
source against the native header, and generate a native lib which should
have an aligned native lib. In a successful compiling step, the agreement
between these artifacts is naturally satisfied, otherwise the compilers
complains. (**sw: a bit verbose**). We explicit name these agreements:
- type agreement: bewteen s1 and s2
- source-native agreement: between s2 and s3

In the real-world, not all native lib are created on the fly. Whether such 
agreements are kept or broken, will be discuss in the next subsection.

**sw** tiny can be more complex when it contains multiple libs

<!-- binding create side -->

**need a term for binding mechanism**

Binding language sites have several mechanism to use the C binding. 
It can be miscellenous on whether using a static or dynamic shared 
library, need a separate compiling stub, or load the binding. While 
understanding their core mechanisms are fun to explore, our framework 
chooses the behavir approach, that we observes the tools in the pipeline 
for the binding and identifier the tools and relevent artifacts.

Let's demonstrate with one common practice for OCaml's method via 
static built stub. In this mechanism, OCaml side needs a stub C file 
which wraps the C interface and gives an OCaml interface:

**Sn.? — OCaml stub (s? native_stub, syntactic).

```c
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include "tiny.h"

CAMLprim value caml_tiny_sum(value a, value b) {
    CAMLparam2(a, b);
    CAMLreturn(Val_int(tiny_sum(Int_val(a), Int_val(b))));
}
```

**Sn.3 — OCaml stub-facing decls** (s3 binding_stub, syntactic).

```ocaml
(* in the binding's stub layer *)
external _sum    : int -> int -> int = "caml_tiny_sum"
external _offset : unit -> int       = "caml_tiny_get_offset"
```

Via this stub, the OCaml side code can invoke the C side code provided by 
external native library. 

**Sn.4 — OCaml user-facing `.mli`** (s4 binding_header, syntactic).

```ocaml
(* tiny.mli — user-facing module signature *)
val sum    : int -> int -> int 
val offset : unit -> int
```

Some library may repack the stub layer again to provide more user-friendly 
interface. The code is pure beyond the binding mechanism, however, 
it makes our narrative more complete. It's possible that real-world 
projects have mismatching in this layer, so we need to assign a stage 
in our framework.

The creation of the ocaml binding need to take both the tiny native library,
the tiny C header from the upstream, and the stub ocaml, the stub-facing 
OCaml code, and maybe user-facing OCaml code from the binding side.

This stage introduces three new artifacts: native stub source (s?), binding
stub-facing source (s3) and binding user-facing signature (s4). Each languages
have its own term for type-level siganature like header, interface, signature.
Here we treat them syntactical surface, since they are source code.

The building of an OCaml binding takes the native header, native library, and 
the stub files and other code in the binding language. A successful building 
at least means these parts agree on some interface. We explicit name these 
agreements:
- native-lib-stub agreement between s2 and s?
- stub-native-binding-lang-agreement s? and s3
- stub-vs-user-facing: s3 and s4

The binding in a language of an upstream project can be either in the project's 
source tree of out of them, so it's common that both software evolves standalone.
Due to the complexity of the binding, even s3 and s4 are usually in one repo, they
may be mismatched.

<!-- binding use side -->



### Scenarios for tiny

<!-- python scenarios.py list -->
symbol_missing
header_arity_bump
symbol_version_floor
abi_soname_bump
type_wrong
api_faithful
api_repack
api_complete
behavior_silent
symbol_orphan
api_repack_python
api_complete_python
app_over_binding_ocaml
app_over_helper_ocaml
api_repack_stub_orphan

--

**Goal.** Introduce a minimal concrete example — a C library and
one binding consumer — that §3 (Surface theory) refers to by name
and by snippet id. Six snippets follow, one per surface role,
arranged so **syntactic** surfaces show source and **semantic**
surfaces show inspector output.

**Presentation convention.** For each artifact, we show *the
code* when the surface is **syntactic** (declared by the
developer) or *an inspector's output* when the surface is
**semantic** (extracted from a compiled artifact). Semantic
surfaces need an inspector to be visible at all. **Sn.6 is
different** — it shows a probe input → expected output (a
runtime observation, not an artifact's surface; see §3.3).


One binding mechanism shown here (OCaml cstubs); the other two
(Python cext, Python ctypes) follow the same shape and appear in §4.
Six snippets follow, one per surface role.

**Sn.5 — OCaml stub `.a` inspected** (s5 binding_lib, semantic).

```
$ nm tiny_stubs.a | grep -E 'tiny_|caml_tiny'
                U tiny_offset
                U tiny_sum
T caml_tiny_sum
T caml_tiny_get_offset
```

**Sn.6 — Runtime probe** (s6 runtime_trace, semantic).

```
input:    set tiny_offset = 42
          call tiny_sum(2, 3)
expected: 47          (i.e. 2 + 3 + 42)
```

---

## §3 — Surface theory

**Goal.** Develop the theory along the **artifact → surface →
contract** spine. Each piece gets a defined role, named
explicitly, before any commentary on the theory's properties.
Universal naming is first-class. The framework's openness to new
checking targets closes the section.

**Naming convention is load-bearing.** The identifiers
(and their formal notation, reserved for paper prose) are
universal vocabulary across theory, tiny, and the canary code.
Same names everywhere.

### 3.1 Artifacts and the boundary

- Artifact kinds (Source, Lib, Binding, App).
- The boundary as the only thing tools see — every check happens
  at one.
- Tools rely on *implicit* assumptions about what's at the
  boundary; surface theory makes these assumptions **explicit**.
  (One sentence in place of the tool-surfaces table.)

### 3.2 What a surface is

- Definition: the observable properties an artifact presents at
  its boundary.
- **Presence axis** of the core vocabulary: a surface is either
  *syntactic* (declared — what the developer wrote or what tools
  recorded at link time) or *semantic* (extracted — what the
  binary actually presents).
- The gap (declared ≠ extracted) — what tools should catch but
  don't. Briefly; surface theory's job is to make these gaps
  visible.

### 3.3 The five surface roles

A surface is the observable properties an artifact presents at
its **boundary**. The boundary on each side splits into surfaces
by *presence axis* (syntactic / semantic) and, on the binding
side, by *layer* (stub-facing / user-facing). Five roles cover
the binding scenario:

**Table — Surface roles.** Five rows, one per surface — the
definitional view of *what surfaces exist*, with the universal
identifiers and the formal notation column.

| id     | friendly name    | formal | side    | kind      | what it is                                                                 |
| ------ | ---------------- | ------ | ------- | --------- | -------------------------------------------------------------------------- |
| **s1** | `native_header`  | Σ_NH   | native  | syntactic | declared C interface — function signatures, structs, macros                |
| **s2** | `native_lib`     | Σ_NL   | native  | semantic  | compiled `.so` / `.dylib` — defined symbols, `@@VER`, SONAME, NEEDED       |
| **s3** | `binding_stub`   | Σ_BS   | binding | syntactic | binding stub-facing decls — `external` / `argtypes` / `PyMethodDef`        |
| **s4** | `binding_header` | Σ_BH   | binding | syntactic | binding user-facing module signature — `.mli` `val`s, Python module funcs  |
| **s5** | `binding_lib`    | Σ_BL   | binding | semantic  | compiled binding artifact — `.cmxa` + stubs `.a`, cext `.so`, ctypes (n/a) |

**Runtime observation is not a surface.** Sn.6 in §2 — the probe
input → expected output — is *not* an artifact's boundary; it is
an observation of *execution*. We refer to it as a **runtime
observation** (or *behavioral trace*), distinct from the five
surfaces. It plays a role in the contract catalogue (§3.4
c3 Behavior) and in the framework's extensibility argument (§3.5),
but theorems about surface alignment (s1..s5) do not transfer
directly to it.

**Table — Tiny touchstone.** Maps each surface role (by friendly
name) to a snippet id from §2; reads as the concrete
instantiation of the abstract roles in the table above. (Sn.6 is
listed separately — runtime observation, not a surface.)

| friendly name    | side    | snippet  | what it shows                                       |
| ---------------- | ------- | -------- | --------------------------------------------------- |
| `native_header`  | native  | **Sn.1** | `tiny.h` source (syntactic)                         |
| `native_lib`     | native  | **Sn.2** | `nm -D libtiny.so.1` + SONAME (semantic, inspected) |
| `binding_stub`   | binding | **Sn.3** | OCaml stub-facing `external` decls (syntactic)      |
| `binding_header` | binding | **Sn.4** | OCaml user-facing `.mli` decls (syntactic)          |
| `binding_lib`    | binding | **Sn.5** | `nm` on OCaml stub `.a` (semantic, inspected)       |

*Runtime observation* — `Sn.6` — probe input (`set tiny_offset =
42; call tiny_sum(2, 3)`) → expected output (`47`). Used by c3
Behavior (§3.4) as an *action expectation*; not a surface.

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

  Every mechanism has the same surface roles; only the
  materialisation timing differs.
- **Scoping.** The c-api binding mechanism is *one* instance of
  the rule schema. Other instances (ctypes, Rust FFI, JNI, …)
  fit the same theory but aren't covered in depth here.

### 3.4 Contracts (Agreement)

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
fires). The universal contract identifiers are the cross-cutting
names used in theory, tiny scenarios, and canary code.

| Contract                | Provider surface                             | Consumer surface                                       | Kind                                       | Where it fires                                 |
| ----------------------- | -------------------------------------------- | ------------------------------------------------------ | ------------------------------------------ | ---------------------------------------------- |
| **c1 Symbol**           | **s2** `native_lib` — defined symbols        | **s5** `binding_lib` — link-time refs / `dlsym`        | semantic ↔ semantic                        | process link (static) / process load (dynamic) |
| **c2 API-completeness** | **s4** `binding_header`                      | app expectations (watchlist or imports)                | syntactic ↔ syntactic (within lang)        | app build / probe                              |
| **c3 Behavior** †       | provider's invocation (runtime observation)  | consumer's wrapper (runtime observation)               | action expectation (not surface ↔ surface) | runtime                                        |
| **c4 ABI**              | **s2** `native_lib` — SONAME, version-needed | **s5** `binding_lib` — NEEDED entries                  | semantic ↔ semantic                        | process load                                   |
| **c5 SymbolVersion**    | **s2** `native_lib` — `@@VER` annotations    | **s5** `binding_lib` — `@VER` requirements             | semantic ↔ semantic                        | process load                                   |
| **c6 Type**             | **s1** `native_header` — C signature         | **s3** `binding_stub` — `external` / `argtypes` / decl | syntactic ↔ syntactic                      | binding build                                  |
| **c7 API-repacking**    | **s3** `binding_stub`                        | **s4** `binding_header` — module signature             | syntactic ↔ syntactic (intra-binding)      | binding-author time (probe-checked today)      |

- **Universal naming.** Contract identifiers used in theory, tiny
  scenarios, and canary code — same names everywhere.
- Two contracts (c2 API-completeness, c7 API-repacking) are
  *entirely within the language side*; the other five cross the
  native ↔ binding boundary.
- **† c3 Behavior is an action expectation, not a surface
  alignment.** The other six contracts pin two *distinct*
  surfaces and ask whether they agree. c3 instead asks whether
  running the binding produces the expected output — a
  trace-vs-expected-trace check (see §3.3 "Runtime observation
  is not a surface"). The framework's surface theorems
  (covariance, refinement) apply to the surface contracts; c3
  sits alongside as a complementary mode.
- **API-repacking (c7) and API-completeness (c2) are checked via
  probe today; static check is future work.** Their entries in
  the catalogue exist; their static comparators don't yet (c7
  for stub-facing layers across all binding mechanisms; c2
  partly covered by watchlist + `Expect_compat_failure`).
- ~~c8 API-faithfulness~~ was retired (2026-06-03) as a contract
  because each binding is independent; cross-binding consistency
  isn't a canary-side agreement.

### 3.5 Extending the framework

- The `(surface, contract)` machinery is **open** — new checking
  targets slot in without changing the framework.
- Concrete extension targets:
  - **Hidden dependencies** (glibc / musl as the canonical case):
    a surface requirement not declared in headers but present in
    NEEDED / `@@VER`. Caught by the same comparator pattern as
    declared symbols. (Absorbs the former MM Hidden dependencies
    subsection that was removed in the restructure.)
  - **Symbol versions**: already extensively checked (c5).
  - **Path resolution**: to-do — the loader's filename →
    artifact resolution is another surface to make explicit.
- **Completeness-by-construction.** The framework is complete
  with respect to "is this binding compatible with this library?"
  precisely because new failure modes slot in as new
  (surface, contract) pairs. The list of targets above is
  illustrative, not exhaustive.
- **Two extension modes.** The `(surface, contract)` machinery
  covers *static agreements* (the five surfaces, six surface
  contracts). Runtime behavioral checks (c3-style action
  expectations) sit alongside as a compatible but separate mode.
  Adding a new behavioral check adds an action-expectation
  channel; adding a new static check adds a new
  (surface, contract) pair. The framework supports both.

### 3.6 Properties of the theory

(Comments on the theory, presented after the theory itself has
something to refer to.)

- **Contract-vs-check independence.** A contract is the
  agreement; a check is one possible implementation (static
  comparator, runtime probe, binding-side test, compile
  failure). One contract can be checked by several mechanisms;
  one mechanism can serve several contracts (c3 probe runner
  also detects c7). Attribution lives at the variant
  declaration, not the detection layer. Cross-reference from
  §7.3 (the implementation realises both mechanisms cleanly).
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

## §4 — Tiny-complete: the controlled witness

**Goal.** Show that the theory is non-vacuous. Tiny is a minimal
testbed with a hand-controlled perturbation budget; every active
Contract has a witness scenario.

§2 (Tiny-tiny) introduced **tiny in miniature** — one C library,
one OCaml binding, one const + one function — as the touchstone
for §3's theory tables. This chapter develops the **full tiny**:
three binding mechanisms (OCaml cstubs, Python cext, Python
ctypes), a downstream `tiny_helper` application, and packaging
considerations that surface gaps in the canary implementation
itself. Tiny-as-object is presupposed (§2); this chapter is about
tiny-as-evidence.

### 4.1 Why a synthetic witness

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
- **What §4 adds beyond §2's touchstone**: the two Python
  binding mechanisms (cext + ctypes) alongside OCaml, the
  downstream `tiny_helper` app exercising the full user-side
  chain, and packaging considerations (apt / opam / pip) — the
  last of which is a known gap in canary's implementation today.

### 4.2 The perturbation matrix

- The harness ↔ canary mapping table (13 entries) is the load-
  bearing artifact.
- Each row: which surface is perturbed → which Contract fires →
  which check mechanism caught it.
- Honest split: comparator-driven rows (c1/c2/c4/c5/c6) vs
  probe-runner rows (c3/c7).
- *How* perturbations are mechanically produced is §7.1 (the two
  engines).

### 4.3 What tiny demonstrates and what it doesn't

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

## §5 — Canary

**Goal.** Describe canary as a **store / runner / producer**
parameterised framework that consumes per-kind artifact stores.
The contribution is producer-agnosticism: the same framework works
whether stores come from tiny's harness or from natural package
managers (opam / pip / apt). The chapter walks the framework's
design, its methodological validation against tiny's concrete
traces, then its application to natural producers. How the
framework is realised in code (inspectors, check mechanisms,
engine boundary) lives in §7 Implementation.

### 5.1 The three concerns

- **Stores** — content-only abstractions providing artifacts of
  declared kinds. No state of their own beyond "here are some
  files."
- **Runners** — project-spec-driven pipelines that read from
  stores, exercise checks, emit logs into a shared output dir.
- **Producers** — populate stores. Tiny's harness is one
  producer; opam / pip / apt are others.

### 5.2 Per-artifact-kind stores

- `tiny_stores = { source ; lib_dir ; python_cext_root ;
  lib_filename }`.
- Each variant picks a store config; cross-products fall out
  naturally.
- One store per surface kind, not one store per scenario.

### 5.3 The spec model as parameterisation

- `make_*_script_spec ~stores` and `?probe_exe`.
- Variants as parameterised specs, not enum tags.
- The spec is uniform across variants; the producer-specific
  mapping lives outside the spec.

### 5.4 Scan_sources as polymorphic placement

- Source-derived inspects need to run before any build step that
  might fail. `scan_sources_after` lets projects declare placement.
- Matters for real projects (z3-style generated bindings need the
  post-build-lib placement).

### 5.5 Validation against tiny — the credibility bridge

- Canary's variant matrix walks the abstract-trace space generated
  by tiny's per-kind stores.
- The methodological step: if canary reproduces every concrete
  trace tiny declares (and rejects what tiny says should pass),
  the framework is sound for the rules tiny exercises.
- Implementation factoring and known leaks tracked in
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md);
  the manuscript view sits in §7.5.

### 5.6 Application to natural producers

- The bridge sentence: tiny's harness IS a package manager that
  ships perturbed artifacts. opam / pip / apt are the natural
  cases; the framework treats them the same.
- Stores become package-manager artifact trees: opam switch lib
  dirs, pip site-packages, apt install paths.
- Producer-agnosticism falls out by construction.

### 5.7 Real-project case studies

- llvm: the existing `Opcode.UncondBr` demo (c2 OCaml) lifted to
  the post-Phase-15 framework.
- z3: the existing `parser_context` demo (c2 Python) lifted.
- sqlite: candidate for c4 (Homebrew vs apt SONAME differences).
- For each: what perturbation surfaces, which rule fires.

### 5.8 What's needed to write this section honestly

- Lift the existing real-project specs (z3, llvm, sqlite) through
  the post-Phase-15 framework before §5.6 / §5.7 can be honest.
- "Real-project audit" — the work the project paused for.

---

## §6 — Miscellaneous (MM)

**Goal.** A deliberately loose gather for topics that don't fit the
SS / TT / CC spine cleanly. Some live here permanently (working
principles in full, related work, calculus sketch); some are
cross-cutting concerns visible from all three pillars but
canonical-source-of-truth nowhere else (packaging, versioning).
Hidden dependencies, originally slated here, moved to §3.5 as an
example of the framework's extension targets. The "extensions"
pattern from PL papers is **held in mind** here — we may or may
not commit to it as prose lands.

### 6.1 Principles (full discussion)

- Expand each principle from §1.3 with rationale, alternatives
  considered, prior art.
- Likely additions over §1.3 previews: implementation hygiene
  notes (when they matter for the methodological claim); scoping
  principles (mechanism-complete material-naive).

### 6.2 Packaging as a trace source

- **Reframe.** Packaging isn't an extension of the framework; it's
  what gives natural producers their real-world trace possibility.
  From the rule/trace perspective, packaging is the engine that
  populates abstract-trace stores in practice.
- Co-providers, multi-PM scenarios, pip-wheel-bundling-native-lib
  cases (PyTorch-style).
- A future `package_theory.md` is one home; covering it as a
  section in §6 is another.

### 6.3 Versioning as cross-cutting

- Versioning isn't a single rule — it cuts across c1 Symbol, c4
  ABI, c5 SymbolVersion, and the version-script work.
- Glibc / musl as one canonical example.
- Why this gets its own section: it threads through SS, TT, and
  CC equally. (Hidden dependencies, which are also cross-cutting,
  moved to §3.5 as an example of the framework's extension
  targets.)

### 6.4 Extensions [held in mind]

- PL-paper convention: a section enumerating directions of
  generalisation (other binding mechanisms — ctypes / Rust FFI /
  JNI; other ecosystem types; other validation engines).
- **Held in mind only.** Commit to a subsection if prose ends up
  needing it; otherwise the extensions get inlined where
  relevant.

### 6.5 Related work

- Compiler correctness, type-preserving compilation, linking
  calculi, ELF semantics, FFI semantics, ABI tooling.

### 6.6 Calculus sketch

- Speculative formal direction; depth depends on venue.

---

## §7 — Implementation (Impl)

**Goal.** How the theory is realised in code. Two engines
(mutation, combinator), the inspectors and check mechanisms,
where each piece lives in the canary tree, and the boundary
between harness (tiny's producer) and canary (the runner). Skip
this chapter if you only want the conceptual narrative.

### 7.1 The two engines

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

### 7.2 Inspectors and the `inspect_input` ADT

- Comparators consume JSON; agnostic to how the JSON was produced
  (real AST tool, regex grep, `nm` output, …).
- The ADT cases each correspond to a typed view (`C_stub`,
  `Native_lib`, `Typed_header`, …).
- This decoupling is what makes the framework producer-agnostic.

### 7.3 Check mechanisms

- Static comparators: predict failure substrings from cached
  JSONs; runner greps probe.log for them.
- Probe runner: `Expect_failure { contains_any }` matches against
  embedded assertions in the probe binary.
- The two mechanisms are independent; some rules use one, some
  the other, occasionally both.

### 7.4 What's general vs what's framework-private

- General: store model, spec model, scan_sources, inspect ADT,
  comparator / runner layering, producer-agnosticism.
- Framework-private: hardcoded-grep inspectors
  (`inspect_tiny_typed.py`), workspace-materialisation fixups —
  details in
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md).

### 7.5 Engine boundary cleanness

- The mutation engine (harness) and combinator engine (canary)
  must stay operationally separate so the methodological claim
  ("two independent engines validate the same rules") is honest.
- Where the boundary leaks today (e.g. `_snapshot_workspace`'s
  RUNPATH-strip and libtiny.so symlink synthesis) is tracked in
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md).
- Phase 16's refactor goal: close those leaks.

### 7.6 Code-citation map

- Pointers to the OCaml + Python files that realise each piece
  of the framework: `canary_project_tiny.ml`,
  `canary/examples/tiny/scenarios/scenarios.py`,
  `inspect_*.py`, `canary_compat.ml`, etc.
- Mirrors `surface_draft/implementation.md` §2.7 from the
  materials collection; the manuscript version is reader-facing
  and trimmed.
