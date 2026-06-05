The problem: a C library (e.g. Z3, LLVM) ships through multiple package
managers (apt, opam, pip) at multiple versions, with bindings for multiple
languages (OCaml, Python, …). When any component drifts, the binding breaks.
We want to (i) predict failures statically, (ii) detect them at runtime,
(iii) blame the root cause to a specific *layer* of the interface.

This document develops the theory. §2.7 (Implementation pointers)
maps each contract and inspector to its location in the canary code;
[`tiny.md`](tiny.md) is the concrete witness; [`plan.md`](plan.md)
holds venues, milestones, and the working roadmap for closing
remaining gaps.

The theory serves two purposes: (i) it **justifies** the implementation —
every design choice in Canary should be derivable from a principle stated
here; (ii) it **predicts** — a new library, language, or package manager
should fit into the model without ad-hoc extension.

## Part A — Motivation & empirics

*What ecosystem tools (gcc, ld, ocamlopt, pip, apt) actually check, the
implicit models each one carries, and the empirical motivation for the
syntactic/semantic split that drives the rest of the theory.*

### Why surface?

Real-world build systems, compilers, linkers, and package managers were not
built from verified rules. They evolved organically: `gcc` checks that
headers exist but not that the symbols they declare match the `.so`; `ld`
resolves symbols by name but ignores version annotations unless configured
otherwise; `pip` installs a wheel but cannot tell you whether the bundled
`.so` is compatible with the system `libstdc++`.

Each tool has its own implicit model of what an artifact *is* — a set of
symbols, a collection of headers, a directory tree. These models are
partial, overlapping, and sometimes contradictory. No existing tool
provides a unified answer to "is this binding compatible with this
library?"

**Surface** is the answer: a typed contract for artifacts. It models what
ecosystem tools actually consume and produce, lifted from implicit
convention to explicit structure. A surface declares, for each layer of
granularity, what an artifact provides and what it requires. The layers are
not arbitrary — they are derived from what the tools *actually* check:

**Table — Tool surfaces.** Sample of what ecosystem tools consume vs. produce; the empirical motivation for the syntactic / semantic split in §0.

| Tool          | Consumes (syntactic)   | Produces (semantic)              |
| ------------- | ---------------------- | -------------------------------- |
| `gcc`/`clang` | `.h` headers           | `.o` with undefined symbols      |
| `ld`          | `.o` undefined symbols | ELF with NEEDED, SONAME          |
| `ocamlopt`    | `.mli` interfaces      | `.cmi` digests, `.cmxa` archives |
| `pip install` | wheel metadata         | site-packages directory          |
| `apt install` | package dependencies   | filesystem paths                 |

The surface makes these relationships explicit and checkable. It is
descriptive — derived from what the tools do — not prescriptive — dictating
what they should do. This is both its strength and its limitation:

- **Strength**: the model works with real tools, today, without changing
  them. Every property in a surface is extractable by running the same
  commands (`nm`, `readelf`, `ocamlobjinfo`) that the tools themselves rely
  on.
- **Limitation**: the model inherits the gaps in those tools. If `nm`
  cannot see a symbol version, neither can we. If a linker silently ignores
  a type mismatch, our surface won't catch it.

This limitation is not a flaw in the theory — it is the theory's job to
make it visible. By formalising what tools *do* check, we also reveal what
they *don't*. The gaps between layers (Type, Behavior) are not holes in the model;
they are holes in the ecosystem, and the model pinpoints them.

## Part B — Theory primitives

*The vocabulary the rest of the theory uses: what a surface is
(syntactic vs semantic), how artifacts are recorded, the six
surface roles each binding scenario presents (s1..s6), the
language-side internal structure that makes the binding side
non-monolithic, and the static/dynamic axis orthogonal to the
roles.*

### 0. What is a surface?

A **surface** is the set of observable properties an artifact presents at
its boundary. Every artifact has both a *syntactic* (explicit) surface and a
*semantic* (implicit) surface.

#### Syntactic surface

The syntactic surface is what the developer writes. It is declarative,
human-readable, and consumed by language tools at build time:

- C headers (`.h`) — function prototypes, struct definitions, macros
- OCaml interfaces (`.mli`) — module signatures, type declarations
- Python type stubs (`.pyi`) — function signatures, class shapes
- pkg-config files (`.pc`) — compiler/linker flags, version constraints

Language tools **consume** syntactic surfaces: `gcc` reads `.h`, `ocamlopt`
reads `.mli`, `mypy` reads `.pyi`. These surfaces are *trusted but not
verified* — the build succeeds if the header exists, regardless of whether
the binary actually provides what the header declares.

#### Semantic surface

The semantic surface is what the artifact actually provides. It is extracted
by inspection, not declared by the developer:

- ELF symbol table (`nm -D`) — defined symbols, `@@VER` annotations
- ELF dynamic section (`readelf -d`) — SONAME, NEEDED, RPATH
- OCaml compiled interface (`.cmi` digest) — structural hash
- Python runtime attributes (`dir()`) — actual module contents

Canary's inspection tools **extract** semantic surfaces: `nm`, `readelf`,
`ocamlobjinfo`, `dir()`. These surfaces are *ground truth* — what the
artifact actually exports, not what was intended.

#### The gap

Syntactic and semantic surfaces can diverge:

- A header declares `void foo(int)` but the `.so` exports `foo@@V2` taking
  `long` (Type: same name, different type)
- An `.mli` declares `val solve` but a dependent module recompilation
  changed the `.cmi` digest (Type: implicit drift)
- A header is present in the `-dev` package, but the runtime library was
  built from a different source version (Symbol: missing symbols)

The pipeline from source to binding crosses this gap twice:

```
source → [build] → native .so     (syntactic .h in, semantic ELF out)
native + .h → [compile] → binding (syntactic .h in, semantic .cmi out)
binding → [link/load] → app       (pure semantic: symbols, SONAME)
```

At each step, syntactic surfaces are consumed but only semantic surfaces
survive into the next artifact. By link/load time, the syntactic surface is
gone — only symbols and ABI metadata remain.

#### Why both matter

- **Syntactic surface** detects *intent drift*: did the developer change
  the declared interface? Examples: the Type contract checks the C header
  against the binding's stub-facing decls; the API-completeness contract
  checks the binding's user-facing `.mli` (or Python `dir()`) against the
  application's expectations.
- **Semantic surface** detects *build divergence*: did the same source
  produce a different binary? Examples: the Symbol contract checks
  libso's symbol table against the binding's link-time references; the
  ABI contract checks SONAME against NEEDED.

Contracts that need source or `-dev` packages (Type, API-repacking,
API-completeness) work on syntactic surfaces. Contracts that work on
installed artifacts alone (Symbol, ABI) work on semantic surfaces. The
runtime contract (Behavior) needs both — running the artifact against
the syntactic claim.

§2 introduces the contracts above and the per-side surface table they
operate on.

### 1. Artifact records

An **artifact** is anything that can be identified, versioned, and inspected.
Each artifact carries a **record**: a typed set of observable properties
extracted by lightweight static inspection.

```
Kind a  ∋  Source | Native | Binding(L) | Package(PM) | App

Record : Kind → Type
Record Source      = { version : V; files : Path list; api : Surface }
Record Native      = { symbols : Symbol set; versioned : Symbol → V;
                       elf : { soname : V option; needed : V list; … } }
Record Binding(L)  = { modules : Module set; requires : Symbol set;
                       watchlist : Name list }
Record Package(PM) = { name : Name; version : V; provides : Record list }
Record App         = { imports : Module list; link_deps : Name list }
```

Records are **observational**: they capture what `nm`, `readelf`,
`ocamlobjinfo`, and `dir()` can see without executing the artifact.

### 2.1 Per-side surfaces — the six surface roles

Each side (native and binding) presents two surfaces: a
**syntactic** surface (declarative, what the developer wrote) and a
**semantic** surface (extracted, what the binary actually contains).
The binding side further splits its syntactic surface into a
**stub** layer (close to the C side, s3) and a **header** layer
(user-facing, s4); see §2.2.

This gives **six surface roles** — `s1..s6`. The friendly names use a
`<side>_<kind>` convention: `native_header` and `binding_header` are
the outward-facing syntactic decls on each side, `native_lib` and
`binding_lib` are the corresponding compiled artifacts. The formal
`Σ_*` notation is reserved for the paper.

**Table — Surface roles.** Six rows, one per surface; the definitional view of *what surfaces exist*.

| id     | friendly name    | formal | side    | kind      | what it is                                                                 |
| ------ | ---------------- | ------ | ------- | --------- | -------------------------------------------------------------------------- |
| **s1** | `native_header`  | Σ_NH   | native  | syntactic | declared C interface — function signatures, structs, macros                |
| **s2** | `native_lib`     | Σ_NL   | native  | semantic  | compiled `.so`/`.dylib` — defined symbols, `@@VER`, SONAME, NEEDED         |
| **s3** | `binding_stub`   | Σ_BS   | binding | syntactic | binding stub-facing decls — `external` / `argtypes` / `PyMethodDef`        |
| **s4** | `binding_header` | Σ_BH   | binding | syntactic | binding user-facing module signature — `.mli` `val`s, Python module funcs  |
| **s5** | `binding_lib`    | Σ_BL   | binding | semantic  | compiled binding artifact — `.cmxa` + stubs `.a`, cext `.so`, ctypes (n/a) |
| **s6** | `runtime_trace`  | Σ_RT   | runtime | semantic  | observable call trace at runtime — probe input/output behaviour            |

#### Z3 instantiation

Concrete artifacts for the same six roles, for Z3 with one OCaml
binding (`ocaml-z3`) and one Python binding (`z3-solver` pip wheel —
a co-provider that bundles its own `libz3.so` inside the wheel).
This grounds the abstract roles in a real project.

**Table — Surface instantiation in Z3.** Six rows × three binding columns; the *example* view of "Table — Surface roles".

| id     | role             | Z3 native (s1+s2) / runtime (s6)                          | Z3 / OCaml binding                    | Z3 / Python binding (z3-solver pip wheel)                  |
| ------ | ---------------- | --------------------------------------------------------- | ------------------------------------- | ---------------------------------------------------------- |
| **s1** | `native_header`  | `z3.h`                                                    | —                                     | —                                                          |
| **s2** | `native_lib`     | `libz3.so` (system or bundled)                            | —                                     | —                                                          |
| **s3** | `binding_stub`   | —                                                         | `z3.mli` externals + cstubs `.c`      | ctypes type descs inside `z3-solver`'s `z3core.py`         |
| **s4** | `binding_header` | —                                                         | `z3.mli` `val` decls (`Z3.Solver`, …) | `z3` package's user-facing attrs (`Solver`, `Optimize`, …) |
| **s5** | `binding_lib`    | —                                                         | `z3.cmxa` + `libz3ml_stubs.a`         | bundled `libz3.so` inside the wheel (co-provider §3.1)     |
| **s6** | `runtime_trace`  | `z3_example.ml` / `probe.py` execution against `libz3.so` | (same)                                | (same)                                                     |

For the concrete `tiny` instantiation of each role across all three
bindings, see [`tiny.md`](tiny.md).

### 2.2 The language side has internal structure

The language side is not one surface — it has at least two syntactic
layers and one semantic layer. They matter because each is a place
belief can drift from the native side.

1. **Stub-facing layer.** Closest to the C side. With stub-based
   bindings: `external` decls plus generated stub C glue, each
   mapping 1-to-1 with a single C function. With ctypes-style
   bindings: `foreign "Z3_mk_int" (int @-> returning int)`
   value-level descriptions. The decls are written by the binding
   author by inspecting the C header.
2. **Repacking layer(s).** Idiomatic re-presentation of the
   stub-facing layer: named arguments, abstract types, exceptions
   instead of return codes, related calls grouped into modules.
   Owned by the binding author. *May span multiple packages* — a thin
   raw binding plus one or more downstream wrapper libraries are
   common, and each is its own repacking step where belief can drift.
3. **Compiled artifact.** Semantic ground truth. Every syntactic
   decision from layers (1) and (2) propagates here: stub decls
   become undefined ELF refs (static) or runtime `dlsym` requests
   (dynamic); user-facing modules become OCaml-visible symbols and
   `.cmi` digests; the link line becomes NEEDED entries. The artifact
   is the canonical bearer of the language-side belief because the
   artifact is what gets shipped and loaded.

> **Why the compiled artifact is the natural check-target.** Every
> syntactic decision the binding source made propagates into a
> concrete property of the artifact. If a stub-facing decl has the
> wrong C type, the compiled stub will have a wrong unboxing. If the
> user-facing module forgets to export a wrapper, the compiled `.cmxa`
> will be missing that OCaml symbol. So inspecting the artifact
> subsumes inspecting the source — at the cost of running later in the
> pipeline.

### 2.3 Binding-mechanism axis: static vs. dynamic

Independent of how many layers the language side has, the stub-facing
layer can be materialized **statically** (binding-build time generates
C glue baked into the artifact, with ELF undefined refs resolved at
process link/load) or **dynamically** (binding-runtime constructs
calls via libffi or equivalent, with symbol lookup via `dlsym`).

**Table — Binding mechanism.** Three rows × resolution phase columns; orthogonal to the surface roles (every mechanism has the same `s1..s6`, only the materialisation timing differs).

| Mechanism                     | Stub-facing materialized at | Link-time C refs in artifact | Symbol-resolution phase    |
| ----------------------------- | --------------------------- | ---------------------------- | -------------------------- |
| Static (cstubs, hand stubs)   | binding-build time          | yes                          | process link + load        |
| Dynamic (ctypes, cffi, ffi.h) | binding-runtime             | no                           | runtime `dlopen` + `dlsym` |
| Hybrid (JIT'd stubs)          | varies                      | varies                       | varies                     |

The Symbol contract still applies in both modes; its check-point
differs (linker error at build / load vs. `dlsym` returning NULL at
runtime).

### 2.9 Satisfaction

A surface is **satisfied** for a set of contracts `𝓒` if every
contract in `𝓒`, together with every refinement (e.g. SymbolVersion
refining Symbol), passes:

```
Satisfies(r_provider, r_consumer, 𝓒) ⇔
  ∀c ∈ 𝓒. ∀c' ⊑ c. check_c'(r_provider, r_consumer) = Pass
```

The check is conjunctive: contracts can be parallel (e.g. Symbol and
ABI are orthogonal) or refinement-related (SymbolVersion ⊑ Symbol);
the satisfaction predicate doesn't care, it just requires all of
them.

## Part C — Contracts & derivations

A **surface** is the interface an artifact presents at its boundary
(see §0). A **contract** is a predicate pinning one surface of the
native side to one surface of the language side and asserting they
must agree. Surface theory's job is to enumerate the contracts, say
*which* pair of surfaces each one aligns, and provide a mechanical
check. The running concrete witness is `tiny` ([`tiny.md`](tiny.md));
the Z3 instantiation in §2.1 grounds the abstract roles in a
real-world target.

*This Part: the contract catalogue (§2.4), one derived contract
(§2.5), versioning as a cross-cutting concern over six sites
(§2.8), and the satisfaction predicate closing the loop (§2.9).*

### 2.4 The contracts

Six contracts cover the foundational picture. Each pins one surface
of the native side to one surface of the language side (or, for the
two intra-language contracts, two surfaces of the language side).

**Table — Contract definitions.** Six rows, one per contract; the definitional view of *what contracts exist* and *which surfaces each pins*.

| Contract             | Provider surface                               | Consumer surface                                                    | Kind                                    | Where it fires                                 |
| -------------------- | ---------------------------------------------- | ------------------------------------------------------------------- | --------------------------------------- | ---------------------------------------------- |
| **Type**             | **s1** `native_header` — C signature           | **s3** `binding_stub` — `external` / `argtypes` / `PyMethodDef`     | syntactic ↔ syntactic                   | binding build                                  |
| **Symbol**           | **s2** `native_lib` — defined symbols          | **s5** `binding_lib` — link-time refs (static) or `dlsym` (dynamic) | semantic ↔ semantic                     | process link (static) / process load (dynamic) |
| **ABI**              | **s2** `native_lib` — SONAME, version-needed   | **s5** `binding_lib` — NEEDED entries                               | semantic ↔ semantic                     | process load                                   |
| **API-repacking**    | **s3** `binding_stub`                          | **s4** `binding_header` — module signature                          | syntactic ↔ syntactic (intra-binding)   | binding-author time (no automated check yet)   |
| **API-completeness** | **s4** `binding_header`                        | app expectations (watchlist or imports)                             | syntactic ↔ syntactic (within language) | app build / probe                              |
| **Behavior**         | **s6** `runtime_trace` (provider's invocation) | **s6** `runtime_trace` (consumer's wrapper)                         | semantic ↔ semantic                     | runtime                                        |


**Table — Contract status.** Eight rows (six foundational contracts +
SymbolVersion + derived API-faithfulness) × four pillars (tiny /
inspectors / comparator / canary status). For the provider↔consumer
surface of each row, read across to "Table — Contract definitions" above.

> Since 2026-06-02 (Phase 12), the canary-status column derives from
> the contract registry in
> `src/canary/surface/canary_compat_run.ml`'s `registered_checks`
> binding. Each entry's `status` field (`Wired` /
> `Inspect_only` / `Comparator_only` / `Blocked _` / `Stubbed`) is the
> authoritative source for this row's last column. The table below is
> the human-readable rendering; if they drift, the registry wins.

| Contract             | Tiny scenario(s)                                                                                                                                       | Inspectors needed                | Comparator id + name          | Canary status                                                                |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------- | ----------------------------- | ---------------------------------------------------------------------------- |
| **Type**             | [e3 `type_wrong`](tiny.md#e3-type_wrong--type-contract-manifests-as-behavior) (body, c3 fires); canary-added `header_arity_bump` (static c6)           | n3 + bo1 (inspect_tiny_typed.py) | **c6** `cmp_type`             | ✓ static comparator over `Typed_header` + `Typed_binding_stub` (Phase 15.5b) |
| **Symbol**           | [e1 `symbol_missing`](tiny.md#e1-symbol_missing--symbol-contract), [e8 `symbol_orphan`](tiny.md#e8-symbol_orphan--symbol-contract-binding-side-orphan) | n4 + bo7                         | **c1** `cmp_symbol`           | ✓ `check_c_compat` — comparator over `C_stub` + `Native_lib`                 |
| **SymbolVersion**    | `symbol_version_floor` (canary-added, e9)                                                                                                              | n4                               | **c5** `cmp_sym_version`      | ✓ static comparator over `Versioned_exports` + `Versioned_req` (Phase 15.4)  |
| **ABI**              | [e2 `abi_soname_bump`](tiny.md#e2-abi_soname_bump--abi-contract)                                                                                       | n4 + bo6 (or bo7)                | **c4** `cmp_abi`              | ✓ comparator over `Native_lib` + `Abi_surface` (Phase 14e)                   |
| **API-sound-repack** | [e5 `api_repack`](tiny.md#e5-api_repack--intra-binding-repacking-ocaml-only) (OCaml), e10 `api_repack_python` (Python)                                 | binding-side test                | **c7** `api_sound_repack`     | ✓ probe runner + `Expect_failure` (binding-side refutation; Phase 15.6)      |
| **API-completeness** | [e6 `api_complete`](tiny.md#e6-api_complete--api-completeness-ocaml-only) (OCaml), e11 `api_complete_python` (Python parallel)                         | bo4 or bpc2 / bpe2               | **c2** `cmp_api_completeness` | ✓ watchlist inside `Expect_compat_failure { Ocaml_mli, Python_attrs }`       |
| ~~API-faithfulness~~ | (no Contract — each binding is independent; cross-binding consistency isn't a canary-side agreement)                                                   | n/a                              | ~~c8~~                        | disabled 2026-06-03; candidate for removal                                   |
| **Behavior**         | [e7 `behavior_silent`](tiny.md#e7-behavior_silent--behavior-contract) + every other scenario's probe                                                   | probe + reference                | **c3** `cmp_behavior`         | ✓ probe runner + `Expect_success` / `Expect_failure`                         |

This is the **plan-and-status table** for roadmap step 3 (compare
theory/tiny/canary) and step 4 (close the ✗ rows). Each ✗ in the last
column corresponds to a step-4 work item in
[`plan.md`](plan.md) §6. The inspector and comparator implementation
detail lives in §2.7.

Two notes on the contracts table above:
- Two contracts (API-repacking, API-completeness) are *entirely
  within the language side*; the other four cross between native and
  language sides.
- **SymbolVersion** appears only in the status table, not in
  contract-definitions — it is a sibling comparator of Symbol
  (`SymbolVersion ⊑ Symbol` in the refinement lattice, independent
  comparator). See §2.5's "refinement lattice vs. comparator flat"
  discussion.

**Currently active vs. deferred.** With path-checking (n3, bo1,
bpc1, bpe1 inspectors and the dependent c6 Type / c7 API-repacking
comparators) and c5 SymbolVersion deferred, the live remaining work
shrinks to: c4 ABI comparator, plus the app-chain coverage (e12, e13
— see [`tiny.md`](tiny.md)) that exercises repacking under a
downstream helper library.

### 4. Hidden dependencies

Not all dependencies appear in the syntactic surface (s1
`native_header`). Some are injected by the build system or the
binding's implementation strategy, visible only in the semantic
surface (s2 `native_lib`):

```
LLVM 19 binding NEEDED:  libffi.so.8, libedit.so.2, libzstd.so.1
LLVM dev binding NEEDED: (none of these)
```

These three libraries are not declared in any LLVM header, CMake
file, or opam dependency. They are pulled in by the 19 build's
specific configuration — libffi for the OCaml binding's runtime,
libedit for the debugger, libzstd for compression. The dev build,
configured differently, doesn't need them.

#### 4.1 Why hidden dependencies matter

A binding author writing a probe expects to link against
`libLLVM.so`. They don't expect the probe to fail because
`libffi.so.8` is missing — they never asked for it. Yet the NEEDED
section of the 19 build's ELF tells a different story: the probe
will not load without it.

This is a **hidden dependency** — a semantic requirement with no
syntactic declaration. The surface model makes it visible because
the semantic extractor (`inspect_native.py` on `n4` `lib_native.so`,
via `readelf -d`) captures NEEDED unconditionally, regardless of
whether any human documented the dependency.

#### 4.2 Hidden C-runtime dependency: glibc vs. musl

The libffi case is about a *named* hidden dependency that appears in
NEEDED. There is a subtler version: the **C runtime** itself. A
library compiled against glibc 2.31 carries versioned symbol
requirements:

```
$ nm -D libz3.so | grep -E 'malloc|cxa_throw'
  U malloc@GLIBC_2.17
  U __cxa_throw@GLIBC_2.3.4
```

A system running glibc 2.17, or running musl libc (which doesn't
implement `@GLIBC_*` versioning at all), cannot satisfy
`malloc@GLIBC_2.31`. In our model this is a **SymbolVersion**
contract violation (§2.4); it's also an **ABI** identity question
(which libc is loaded). The information is present in the artifacts
the whole time — `@@VER` annotations on the libc, `@VER`
requirements on the consumer.

This case is *especially silent at build time*: a binary built on
Ubuntu 20.04 compiles, links, and tests fine; it only fails when
shipped to a host with an older or different libc. A wired `c5
cmp_sym_version` plus libc identification on the host would catch
this class end-to-end. Today canary has the inspector half (the
`versioned_req` / `versioned_exports` fields emitted by
`inspect_native.py` on `n4`) but not the comparator — see §2.7's
comparator-only-gap group.