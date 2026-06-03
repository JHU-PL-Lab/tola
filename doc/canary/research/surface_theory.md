# Surface theory — artifact records and compatibility

think about the title and the scope of the paper

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

## 0. What is a surface?

A **surface** is the set of observable properties an artifact presents at
its boundary. Every artifact has both a *syntactic* (explicit) surface and a
*semantic* (implicit) surface.

### Syntactic surface

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

### Semantic surface

The semantic surface is what the artifact actually provides. It is extracted
by inspection, not declared by the developer:

- ELF symbol table (`nm -D`) — defined symbols, `@@VER` annotations
- ELF dynamic section (`readelf -d`) — SONAME, NEEDED, RPATH
- OCaml compiled interface (`.cmi` digest) — structural hash
- Python runtime attributes (`dir()`) — actual module contents

Canary's inspection tools **extract** semantic surfaces: `nm`, `readelf`,
`ocamlobjinfo`, `dir()`. These surfaces are *ground truth* — what the
artifact actually exports, not what was intended.

### The gap

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

### Why both matter

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

## 1. Artifact records

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

## 2. Surface contracts

A **surface** is the interface an artifact presents at its boundary
(see §0). A **contract** is a predicate pinning one surface of the
native side to one surface of the language side and asserting they
must agree. Surface theory's job is to enumerate the contracts, say
*which* pair of surfaces each one aligns, and provide a mechanical
check. The running concrete witness is `tiny` ([`tiny.md`](tiny.md));
the Z3 instantiation in §2.1 grounds the abstract roles in a
real-world target. See [`lifecycle.mmd`](lifecycle.mmd) for the
pipeline diagram.

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

#### Alignment with tiny and canary status

The same contracts again, joined with: which `tiny` scenario(s)
witness each, which inspectors and comparators canary needs, and
what's wired today. This is the **go-to status view** — open it when
you want to see all four pillars (theory ↔ tiny ↔ coverage ↔
currently) on one row.

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

| Contract             | Tiny scenario(s)                                                                                                                                       | Inspectors needed                 | Comparator id + name          | Canary status                                                                |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------- | ----------------------------- | ---------------------------------------------------------------------------- |
| **Type**             | [e3 `type_wrong`](tiny.md#e3-type_wrong--type-contract-manifests-as-behavior) (body, c3 fires); canary-added `header_arity_bump` (static c6)            | n3 + bo1 (inspect_tiny_typed.py)  | **c6** `cmp_type`             | ✓ static comparator over `Typed_header` + `Typed_binding_stub` (Phase 15.5b) |
| **Symbol**           | [e1 `symbol_missing`](tiny.md#e1-symbol_missing--symbol-contract), [e8 `symbol_orphan`](tiny.md#e8-symbol_orphan--symbol-contract-binding-side-orphan) | n4 + bo7                          | **c1** `cmp_symbol`           | ✓ `check_c_compat` — comparator over `C_stub` + `Native_lib`                 |
| **SymbolVersion**    | `symbol_version_floor` (canary-added, e9)                                                                                                              | n4                                | **c5** `cmp_sym_version`      | ✓ static comparator over `Versioned_exports` + `Versioned_req` (Phase 15.4)  |
| **ABI**              | [e2 `abi_soname_bump`](tiny.md#e2-abi_soname_bump--abi-contract)                                                                                       | n4 + bo6 (or bo7)                 | **c4** `cmp_abi`              | ✓ comparator over `Native_lib` + `Abi_surface` (Phase 14e)                   |
| **API-sound-repack** | [e5 `api_repack`](tiny.md#e5-api_repack--intra-binding-repacking-ocaml-only) (OCaml), e10 `api_repack_python` (Python)                                 | binding-side test                 | **c7** `api_sound_repack`     | ✓ probe runner + `Expect_failure` (binding-side refutation; Phase 15.6)      |
| **API-completeness** | [e6 `api_complete`](tiny.md#e6-api_complete--api-completeness-ocaml-only) (OCaml), e11 `api_complete_python` (Python parallel)                         | bo4 or bpc2 / bpe2                | **c2** `cmp_api_completeness` | ✓ watchlist inside `Expect_compat_failure { Ocaml_mli, Python_attrs }`       |
| ~~API-faithfulness~~ | (no Contract — each binding is independent; cross-binding consistency isn't a canary-side agreement)                                                   | n/a                               | ~~c8~~                        | disabled 2026-06-03; candidate for removal                                   |
| **Behavior**         | [e7 `behavior_silent`](tiny.md#e7-behavior_silent--behavior-contract) + every other scenario's probe                                                   | probe + reference                 | **c3** `cmp_behavior`         | ✓ probe runner + `Expect_success` / `Expect_failure`                         |

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

#### Categories of invariants (cross-cutting)

Contracts differ in *which surfaces they pin* (the alignment table
above). An orthogonal question is *what kind of invariant the
pinning enforces*. These categories cross-cut contracts:

- **Presence** — does the provider export what the consumer
  expects? Surfaces at Symbol (link-level names) and
  API-completeness (high-level names). Checked: s2→s5 (stub.a undef
  refs), s5→app (probe).
- **Version-match** — is the provider's version at least what the
  consumer requires? Surfaces at SymbolVersion (`@@VER`) and ABI
  (SONAME). Plumbed, not wired.
- **Type-match** — does the provider's type signature match the
  consumer's? Surfaces at Type (`.cmi` digest, header parse). Not
  checked end-to-end.
- **Shape-match** — does the consumer's API shape match
  expectations? Surfaces at API-completeness (watchlists, `dir()`)
  and API-repacking (intra-binding). Partly checked.
- **Identity** — is this the artifact we think it is? Surfaces at
  ABI (SONAME, NEEDED). Diagnostic only.
- **Behavior-match** — same input → same output? Surfaces at
  Behavior. Research.

### 2.5 API-faithfulness is derived, not primitive

A reasonable reader will ask: shouldn't there be a contract
"user-facing OCaml API faithfully mirrors the C API"? Yes — but it is
*derived*, not primitive. It decomposes:

```
API-faithfulness   ⇐   Type   ∧   Symbol   ∧   API-repacking
```

The C-side ↔ stub-facing alignment (Type + Symbol) plus the
stub-facing ↔ user-facing alignment (API-repacking) compose to give
C-side ↔ user-facing alignment. So we do not list API-faithfulness in
the primary table — checking its three constituents implies it.

This decomposition is *why* the language side's internal structure
matters. The thing a user notices when a binding misbehaves
("`Z3.Solver.mk` is missing", "argument order is wrong") is an
API-faithfulness failure. But there is no direct check for it.
Verification routes through three separate links of the chain.

#### Refinement lattice vs. comparator flat

A general principle hides in §2.5 and in the SymbolVersion case:
**contracts form a refinement lattice; comparators are a flat
implementation of selected lattice points.**

Logically, contracts have an order. SymbolVersion refines Symbol
(`SymbolVersion ⊑ Symbol` — checking the version annotation
presupposes the symbol name is present at all). API-faithfulness
derives from Type ∧ Symbol ∧ API-repacking. Behavior is the
finest, refining everything below it. The lattice expresses what
*entails* what.

Operationally, the alignment table (§2.7) treats each contract as a
**sibling row with its own comparator id**, even when the contracts
are refinement-ordered. So c1 `cmp_symbol` and c5 `cmp_sym_version`
are independent rows with independent comparators, even though c5
⊑ c1 in the lattice. This is because the comparators have *distinct
implementations* (set inclusion of names vs. version-tag
satisfaction), *distinct failure modes* (`undefined symbol` vs.
`version 'TINY_2.0' not found`), and *distinct status today* (c1 ✓
wired, c5 ✗ comparator missing).

The principle: when two refinement-ordered contracts have
independent failure modes and need independent comparator code, they
get peer rows in the implementation. The refinement order is
recorded in §2.9's satisfaction predicate and in the lattice prose,
but doesn't collapse the comparator grid.

### 2.6 Actions and phases

Surfaces and contracts are *what we model*. Actions are *what we
actually run* — concrete pipeline steps (canary or tiny) that produce
surfaces and exercise contracts. Many actions touch multiple
contracts at once (e.g. `build_binding_static` triggers Type at
compile-time and Symbol-static at link-time), which is why they
deserve their own grid alongside the contract tables.

#### 2.6.1 Action grid

**Table — Action grid.** Rows are pipeline actions, grouped by category.
Inputs (surfaces consumed) and outputs (surfaces produced) name `s*`
roles from §2.1; the "Contracts checked" column names the `c*`
contracts from §2.4. This is the *operational* view — what each step
does to the surface/contract picture.

| Action                   | Canary step / tiny artifact                                                                | Inputs (consumed)    | Contracts checked                                                                                        | Outputs (produced)          | Status                                           |
| ------------------------ | ------------------------------------------------------------------------------------------ | -------------------- | -------------------------------------------------------------------------------------------------------- | --------------------------- | ------------------------------------------------ |
| **build_native_lib**     | `build_lib` (cmake/ninja → `libtiny.so.1`, `libz3.so`)                                     | C source + `s1`      | (defines provider; no cross-check)                                                                       | `s2`                        | ✓                                                |
| **build_binding_static** | `build_binding_ocaml`, python cext `setup.py build_ext`; tiny `ocaml/dune`, `python_cext/` | `s1`, `s2`, `s3`     | **c6** Type (compile-time), **c1** Symbol-static (link-time)                                             | `s5`                        | ✓ pipeline; c6 post-hoc inspector ✗              |
| **install_binding**      | `pack_binding_ocaml`, `pip install`; tiny `Makefile install`                               | `s5`                 | **c4** ABI (NEEDED resolution at install)                                                                | (installed binding on disk) | partial — c4 surfaces only as load failure today |
| **probe_binding**        | `probe_binding_ocaml`, `probe_binding_python`; tiny `examples/probe_baseline.{ml,py}`      | `s5` + `s2`          | **c1** Symbol-dynamic (`dlsym`), **c4** ABI (load), **c2** API-completeness (watchlist), **c3** Behavior | `s6` (runtime trace)        | ✓ probe runs; c4 implicit; c3 vs reference       |
| **apply / revert patch** | tiny `scenarios/scenarios.py` (no canary analogue)                                         | source tree          | (perturbation — no check itself; sets up subsequent actions)                                             | mutated source tree         | ✓                                                |
| **inspect_\***           | `canary/scripts/inspect_*.py`                                                              | one artifact (n*/b*) | (extraction only — feeds comparators)                                                                    | JSON record                 | per artifact; see §2.7 inspector-coverage table  |
| **cmp_\*** (c1..c8)      | `surface/canary_compat.ml`, tiny `_harness/comparators/`                                   | two JSON records     | exactly one contract (c1..c8)                                                                            | pass/fail verdict           | per c*; see contract-status table (§2.4)         |

A key reading: the **multi-contract pipeline rows** are
`build_binding_static` and `probe_binding` — these are the actions
where a single failure could be caused by drift in several different
contracts, and where a cleaner separation of static checks (the
inspect/cmp rows below) lets us blame the root cause more precisely
than the failure mode of the pipeline action alone.

Inspect and cmp actions are 1-to-1 with their `i*` / `c*` ids — the
single-purpose rows are folded into pointers to §2.4 and §2.7 rather
than re-tabulated row-by-row.

#### 2.6.2 Phase mapping

A coarser, phase-level view of the action grid. When each contract is
checkable depends on what inputs are available at that point in the
pipeline; the phase axis collapses the action grid into four
lifecycle windows.

**Table — Phase mapping.** Four rows (lifecycle phases) × the contracts that become checkable at each. Compresses the action grid above by collapsing per-language differences.

| Phase         | Inputs available                        | Contracts checked at this phase                             |
| ------------- | --------------------------------------- | ----------------------------------------------------------- |
| Binding build | binding source + native {header, libso} | Type, Symbol (static only), API-repacking, API-completeness |
| App build     | binding artifact + app source           | API-completeness (app side)                                 |
| Process load  | binding artifact + native libso         | Symbol (dynamic), ABI, SymbolVersion                        |
| Process run   | running process + inputs                | Behavior                                                    |

A structural feature of the binding scenario surfaces here: the
header (`z3.h`) is needed at binding build but *not at process load*.
After the binding ships, the header is gone from the dependency
graph; the language-side belief about C signatures is **snapshotted**
at binding-build time. The native side can drift afterwards. This is
the **snapshot-vs-now** asymmetry — surface theory's role is to
re-inspect both sides at the *current* moment, not trust the original
snapshot.

### 2.7 Inspector coverage and implementation pointers

The contract-status view lives in §2.4's alignment table. This
section provides the supporting detail: per-inspector status,
implementation file pointers, and the interpretive prose about how
the gaps decay.

#### Inspector vs. comparator

A static check has two roles:

- An **inspector** takes *one artifact* and produces *one structured
  surface description* (a JSON record). Side-agnostic and
  contract-agnostic; it just extracts what the artifact presents.
  Canary's inspectors today: `inspect_native.py` (ELF),
  `inspect_binding.py --kind stub` (stub `.a` undef refs),
  `inspect_binding.py --kind mli` (OCaml `.mli` parse),
  `inspect_ocaml.py` (`.cmxa` modules), `inspect_python.py`
  (`dir()`), `scan_source` (header file presence).
- A **comparator** takes *two surface JSONs* (provider + consumer),
  plus the contract identity, and computes a Pass/Fail verdict —
  ideally with the disagreement set attached. Contract-specific,
  inspector-agnostic (works on any pair of JSONs with the right
  shape). Canary's comparators today: `check_c_compat` (encodes
  Symbol via `native.symbols ⊇ stub.requires`) and the watchlist
  check inside `Expect_compat_failure` (encodes API-completeness
  via set inclusion on `.mli` vals or Python attrs).

A contract has full static-check coverage *iff* both the relevant
inspectors and the comparator that consumes them exist. The
inspector side is tracked below; the comparator side is in the
§2.4 alignment table.

#### Inspector coverage (per artifact)

Rows are *artifact aliases* (file-keyed, project-local). The `n*` /
`b<lang><mech?>*` naming and the full canonical-name dictionary live
in [`tiny.md` § Artifact inventory](tiny.md#artifact-inventory--aliases--canonical-names);
this section uses the aliases as compact handles. Surface tags
(`s1..s6`) refer back to §2.1.

**Table — Inspector coverage.** One row per inspectable artifact in
`tiny`. The *implementation* view — what extracts each surface, and
what's wired today.

| alias | canonical name (artifact)       | surface | inspector tool                                    | status     |
| ----- | ------------------------------- | ------- | ------------------------------------------------- | ---------- |
| n4    | `lib_native.so`                 | s2      | `inspect_native.py` via `nm -D` + `readelf -d`    | ✓          |
| bo4   | `user_binding_ocaml.mli`        | s4      | `inspect_binding.py --kind mli`                   | ✓          |
| bo7   | `compiled_binding_ocaml.stub-a` | s5      | `inspect_binding.py --kind stub` via `nm`         | ✓          |
| bo6   | `compiled_binding_ocaml.cmxa`   | s5      | `inspect_ocaml.py` via `ocamlobjinfo`             | ✓          |
| bpc2  | `user_binding_ctypes.py`        | s4      | `inspect_python.py --pkg tiny_ctypes`             | ✓          |
| bpe2  | `user_binding_cext.py`          | s4      | `inspect_python.py --pkg tiny_cext`               | ✓          |
| bpe3  | `compiled_binding_cext.so`      | s5      | `inspect_native.py` (same tool, on a binding ELF) | ✓          |
| n3    | `header_native.h`               | s1      | — (no parser; `scan_source` presence check only)  | ✗          |
| bo1   | `stub_binding_ocaml.mli`        | s3      | — (mli inspector matches `^val`, not `external`)  | ✗          |
| bpc1  | `stub_binding_ctypes.py`        | s3      | — (no ctypes-decl parser)                         | ✗          |
| bpe1  | `stub_binding_cext.c`           | s3      | — (no Py C API parser)                            | ✗          |
| —     | runtime probe                   | s6      | probe binary + reference expected values          | ✓ implicit |

Compact reading: the native semantic surface (s2 / `n4`) and the
language user-facing surface (s4 / `bo4`, `bpc2`, `bpe2`) are well
covered. The native syntactic header (s1 / `n3`) and the stub-facing
layer across every binding mechanism (s3 / `bo1`, `bpc1`, `bpe1`)
are the parsing gaps.

#### Where `tiny` fits (prose gloss on the alignment table)

The tiny-scenario column of the alignment table groups into three
detection patterns worth naming explicitly:

- **Statically-detectable** (comparator catches it before runtime):
  Symbol (`e1 symbol_missing`, `e8 symbol_orphan` — c1 catches),
  API-completeness (`e6 api_complete` — c2 catches).
- **Behavior-detected** (only the runtime probe catches the
  downstream effect): Type (`e3 type_wrong`), API-repacking
  (`e5 api_repack`), Behavior itself (`e7 behavior_silent`),
  API-faithfulness (`e4 api_faithful` — even Behavior misses this
  one; it's silent, the regression test for c8).
- **Load-detected** (the OS dynamic loader is the comparator at
  process load): ABI (`e2 abi_soname_bump`). Canary observes the
  failure mode but `c4 cmp_abi` would surface it statically.

#### How the gaps decay

The ✗ rows in the alignment table split into three classes that
need different work:

- **Comparator-only gaps** (c4 ABI, c5 SymbolVersion): inspectors ✓
  (`n4` `lib_native.so` is enough for both, with `bo6` / `bo7` on
  the consumer side); just needs a small diff step on existing
  JSON. Pure plumbing.
- **Inspector-and-comparator gaps** (c6 Type, c7 API-repacking):
  inspectors ✗ on `n3` `header_native.h` and on the stub-facing
  layer across every binding mechanism (`bo1` for OCaml `external`,
  `bpc1` for ctypes `argtypes`, `bpe1` for cext `PyMethodDef`).
  Each comparator needs its inspectors built first.
- **Derived gap** (c8 API-faithfulness): blocked behind c6 and c7 via
  the §2.5 derivation.

The right way to interpret this for the paper: **canary's runtime
probe (Behavior) currently subsidises four contracts** (Type,
API-repacking, API-faithfulness, and any SymbolVersion drift) by
catching their downstream effects. The static-check side is
incomplete in two distinct ways — comparator-only and
inspector-plus-comparator — and `tiny` makes each gap *visible and
reproducible* per contract, which is the prerequisite for closing
them one at a time.

#### Implementation pointers — where each piece lives in the canary tree

For readers who want to trace the contracts to running code rather
than to the inspector/comparator IDs. Phase 4 (2026-05-28/29) added
doc-comments on the cited types and functions naming the canonical
artifacts they handle (e.g. `compat_inspect_input`'s constructors
each carry their `n*`/`bo*`/`bpe*` alias mapping inline) — so a
reader following these pointers will find the alignment table
restated in code as well.

**Table — Implementation pointers.** Per-component file references; maps the abstract `i*` / `c*` IDs to concrete files in the canary tree.

| Component                         | File / artifact                                                                                                       | Notes                                                                                    |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Inspectors (CLI scripts)          | `canary/scripts/inspect_native.py`, `inspect_binding.py`, `inspect_ocaml.py`, `inspect_python.py`                     | One per surface kind; each emits a JSON `inspect.json` with a `kind` field               |
| Comparator (pure, c1..c8)         | `src/canary/surface/canary_compat.ml` → `check_c_compat`, `check_abi`, `check_sym_version`, `check_type`, …           | Pure theory: input types + result ADTs + comparator functions; ~460 lines                |
| Comparator runner / CLI           | `src/canary/surface/canary_compat_run.ml` → `predicted_contains_any_v2`, `run_for_project`, `verify_for_project`      | Drives cached-summary lookup + the `compat` / `verify` CLI subcommands                   |
| Comparator (API-completeness, c2) | `src/canary/action/canary_step_model.ml` → `Expect_compat_failure { inputs; ... }` (uses `Canary_compat.inspect_input`) | Watchlist check inside the step-expectation runner                                       |
| Surface records (typed)           | `src/canary/surface/canary_artifact_api.ml`                                                                           | `native_api` (provider) and `binding_api` (consumer) types; survives the `Σ_*` rename    |
| Per-language inspect glue         | `src/canary/tool/canary_artifact_native.ml`, `canary_artifact_lang.ml`                                                | Shell out to the Python scripts; cache JSONs under per-step output dirs                  |
| Step expectation                  | `src/canary/action/canary_step_model.ml` → `step_expectation`                                                         | `Expect_compat_failure { inputs; version_info }` resolves cached summaries vs. probe.log |
| Inspect-diff (drift)              | `src/canary/tool/canary_inspect_diff.ml`                                                                              | Compares two `inspect.json`s; currently informational, not a comparator                  |
| Pure tests (fixtures)             | `src/canary/test/canary_artifact_test.ml` → `compat.*`                                                                | Synthetic fixtures exercise the comparator logic without integration runs                |

The JSONs produced by the inspectors are the load-bearing data
format. Their schema is shared across `canary action` (which feeds
them into the comparators above) and `tiny`'s scenario harness
(which runs the same comparators against tiny's artifacts via small
Python wrappers under `canary/examples/tiny/scenarios/_harness/comparators/`).

### 2.8 Versioning is cross-cutting

Versioning is not a single contract — versions appear at multiple
*sites*, asserted by different agents, and consumed by different
checks. A holistic project-versioning model that ties them together
is still TODO; this subsection enumerates the sites and where each
fits in the surface model.

#### Intrinsic vs. extrinsic versioning

A version assertion is **intrinsic** if the artifact carries it
(the version is part of the artifact's surface), or **extrinsic**
if some external authority records it (the artifact doesn't know
it; you have to ask elsewhere).

**Table — Versioning sites.** Six sites where a version can be asserted; intrinsic ones (visible on the artifact surface) are checkable by surface theory, extrinsic ones belong to packaging theory.

| Site                         | Example                                               | Asserted at  | Read by                               | Kind                                                     |
| ---------------------------- | ----------------------------------------------------- | ------------ | ------------------------------------- | -------------------------------------------------------- |
| Source-repo tag              | `git tag v4.15.0`                                     | repo time    | release engineer, package maintainer  | **extrinsic**                                            |
| Package manifest             | opam `version: "4.15.0"`, pip `Metadata-Version: 2.1` | package time | PM resolver (apt, opam, pip)          | **extrinsic**                                            |
| Filesystem name              | `libz3.so.4.15.0` + symlink chain                     | install time | OS loader (ld.so), `find_library`     | **extrinsic**                                            |
| Artifact metadata (SONAME)   | `DT_SONAME = libz3.so.4`                              | link time    | OS loader (identity check)            | **intrinsic** (c4 ABI)                                   |
| Artifact symbol annotations  | `tiny_sum@@TINY_2.0`, `malloc@@GLIBC_2.31`            | link time    | OS loader (symbol-version resolution) | **intrinsic** (c5 SymbolVersion)                         |
| Artifact contents (constant) | embedded `Z3_VERSION = "4.15.0"`                      | build time   | application code at runtime           | **intrinsic** (c2 API-completeness — name + value in s4) |

The intrinsic / extrinsic line is also the **surface theory /
packaging theory** line.

- **Intrinsic versioning is what surface theory checks.** SONAME,
  `@@VER`, and embedded version constants are part of an artifact's
  surface. Disagreements between provider and consumer at the
  intrinsic level are contract violations (c4 ABI, c5
  SymbolVersion, c2 watchlist on a version constant).
- **Extrinsic versioning is what packaging theory checks.** Filename
  resolution, package-manifest constraints, source-tag selection —
  these decide *which artifact fills s2*, not whether the artifact
  itself is well-formed.

#### Reflecting extrinsic versioning through wrong-artifact loading

Even though tiny doesn't model packaging directly (§3), it
*demonstrates the effect* of extrinsic-versioning failures by
hacking the wrong artifact into the file resolution path. The
canonical example is **e2 `abi_soname_bump`**: we rename
`libtiny.so.1` → `libtiny.so.2.0` so that ld.so can't find the
file the binding asks for. That's an *extrinsic* (filesystem) layer
problem made visible as a load failure. The same pattern would
apply to apt downgrading a package, opam pinning to an old version,
or a pip wheel shadowing a system library.

This indirection is the right level of abstraction for the
foundational paper: surface theory doesn't need to model the
package manager's resolver, only the *artifact mismatch* that
results from a wrong resolution.

#### Belief-vs-reality warnings

Programmers and users often hold beliefs about extrinsic versions
that are wrong:

- "I'm running `libz3 4.15.0`" — but `4.15.0` is the package
  manifest version. The installed `libz3.so` has its own SONAME
  (intrinsic c4) and `Z3_VERSION` constant (intrinsic in s4) that
  may disagree if the build was patched.
- "My pip install of z3-solver is up to date" — but pip's metadata
  version doesn't speak to the bundled `libz3.so`'s `@@VER`
  annotations, which the actual runtime resolution uses.
- "The opam package says it depends on z3 ≥ 4.13" — but opam's
  constraint is purely extrinsic; the binding's *baked-in NEEDED
  + `@VER` requirements* are the real runtime gate.

Each of these is a place where a future canary mode could *alert on
disagreement* between an extrinsic claim and the corresponding
intrinsic surface. Not a contract violation per se, but a
diagnostic worth emitting. Deferred to the packaging-theory layer.

#### Where each versioning site sits in the contract grid

**Table — Versioning sites × contracts.** Same six sites as above, joined with the contract that compares each.

| Site               | Contract that compares it (if any)          | Status                                         |
| ------------------ | ------------------------------------------- | ---------------------------------------------- |
| Source-repo tag    | (none directly — drives provider selection) | extrinsic; out of scope                        |
| Package manifest   | (none directly — drives provider selection) | extrinsic; out of scope                        |
| Filesystem name    | (none directly — drives loader resolution)  | extrinsic; indirectly visible via load failure |
| SONAME             | c4 ABI                                      | intrinsic; comparator gap                      |
| Symbol annotations | c5 SymbolVersion                            | intrinsic; comparator gap                      |
| Embedded constants | c2 API-completeness (when watchlisted)      | intrinsic; partly checked                      |

A project's "version" is a tuple over these sites; canary today
checks the intrinsic c4 and c5 entries via inspectors but doesn't
yet have the comparators wired (see §2.7).

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

## Principles

These are not axioms in a formal system but design constraints the theory
must satisfy. They are falsifiable: if the implementation violates one, the
theory needs revision or the implementation needs fixing.

### P1. Observational

Every property in an artifact record must be extractable by a
deterministic, read-only inspection of the artifact on disk. No property may
require execution, network access, or knowledge of how the artifact was
produced. This is what makes static inference sound: two inspectors looking
at the same artifact see the same record.

### P2. Decomposed into contracts

Compatibility is decomposed into independent contracts (§2.4), each
pinning a specific pair of surfaces. Contracts may be
refinement-ordered (e.g. SymbolVersion ⊑ Symbol) or parallel (e.g.
Symbol and ABI are orthogonal). A contract failure pinpoints which
surface pair disagrees; in general it does *not* imply failure of
other contracts. This makes blame precise: "the SONAME is wrong" is a
different diagnosis from "a symbol is missing," and neither says
anything about whether the user-facing API was correctly repacked.

### P3. Black-box

Build systems, compilers, and package managers are treated as black boxes.
The theory models their *input/output relation* on artifact records, not
their internal logic. This makes the model portable across toolchains: cmake
and bazel are different black boxes but the record types are the same.

### P4. Covariant providers, contravariant consumers

A provider with *more* symbols, *higher* version tags, or *more*
modules is always substitutable for one with fewer. A consumer that
*needs* fewer symbols or *tolerates* more versions is compatible
with more providers. The §2.4 contracts encode this directly: each
comparator's set-inclusion direction (e.g. `c1 cmp_symbol` checks
`consumer.requires ⊆ provider.symbols`) is the
covariance/contravariance dial for one contract.

### P5. Surface preservation

A syntactic surface that cannot be verified against a semantic
surface is a documentation claim, not a checkable property. Every
syntactic claim the theory tracks must have a corresponding semantic
extractor (or a clear argument for why one cannot exist). This is the
closure that makes blame possible: if a failure occurs and no
contract predicted it, the contract list is incomplete.

### P6. PM uniformity

The record types are independent of how the artifact was obtained.
`nm -D` produces the same record structure whether the `.so` came
from `apt`, `cmake --build`, or a pip wheel. This is what enables
the provider matrix (§3): the same library from different PMs can
be compared at the record level.

## 3. Packaging and co-providers

The surface model's six roles (§2.1) describe what an artifact
*presents*; they say nothing about *which* artifact populates a
role. Packaging is the sibling concern that picks the concrete
artifact: apt vs. opam vs. pip vs. source-build, system vs.
vendored, one version vs. another. Because P6 holds (record
uniformity across PMs), the contracts in §2.4 compare cleanly across
cells of a **provider matrix** indexed by `(PM, version, binding
language)`.

The compatibility matrix for a library is:

```
Compat(Lib) = { ((pm, v), (l, r_prov, r_cons)) |
                (pm, r_prov) ∈ Providers(Lib, v),
                r_cons ∈ Consumers(Lib, l),
                contracts in §2.4 all satisfied between r_prov and r_cons }
```

Each cell is a canary action: fetch provider, fetch binding,
compile, run, check contracts.

### 3.1 Co-providers

Some packages **bundle** their own copy of the native library — the
canonical examples are `llvmlite` (bundles libLLVM) and the
`z3-solver` pip wheel (bundles libz3). The outer package is a
**co-provider**: it carries a Native record (s2 `native_lib`)
*inside* a Package record. The bundled native is inspectable just
like a system-provided one; if `libz3.so` from `apt` and the bundled
`libz3.so` from the pip wheel present different surfaces, a binding
may work against one but not the other.

The §2.3 static/dynamic axis interacts with co-providers: a dynamic
binding (`tiny_ctypes`-style) would normally rely on a system
libtiny, but a co-provider model would bundle libtiny inside the
Python wheel. `tiny` deliberately *doesn't* exercise co-providers —
packaging is sibling, not foundational, and we want the witness to
isolate the surface contracts (see [`tiny.md`](tiny.md) on why
packaging stays out of scope).

### 3.2 Status

The provider-matrix angle is deferred work — the model is sketched
above but not used in canary's per-action checks today. See
[`plan.md`](plan.md) (roadmap step 2) for the rationale and the
deferral plan.

## 4. Hidden dependencies

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

### 4.1 Why hidden dependencies matter

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

### 4.2 Hidden C-runtime dependency: glibc vs. musl

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

## 5. Relationship to other theories

- **SemVer and version constraints.** Version numbers are coarse
  proxies for surface compatibility. The surface model refines them:
  two artifacts with the same version number may present different
  surfaces (different PMs, build configs); two artifacts with
  different version numbers may be surface-compatible (symbol
  subset unchanged).
- **Type systems for linking.** Surface theory plays the role of a
  *gradual type system* for binary interfaces: Symbol is untyped
  name matching; Type adds structural typing (via `.cmi` digest /
  header parse); Behavior would be full behavioral specification.
  The progression is gradual in granularity, not a single linear
  chain.
- **Nix / reproducible builds.** Nix ensures the *same* artifact is
  produced from the same inputs. Surface theory checks whether
  *different* artifacts (same library, different PM/version) are
  compatible. Complementary guarantees.

A fuller bibliography lives at [`literature.md`](literature.md),
covering verified compilation (CompCert, CakeML), type-preserving
compilation (TIL, TAL, GHC Core), linking calculi (Cardelli,
Flatt-Felleisen, MixML), Java dynamic-linking semantics
(Drossopoulou-Wragg-Eisenbach), ELF semantics (Kell), FFI semantics
(Furr-Foster, Patterson-Garg-Ahmed), and ABI tooling (libabigail).

## 6. Toward a typed calculus

The long-term goal is a **typed calculus of artifact composition**.
Artifact records (§1) are values; surface roles (§2.1) are types;
the build / compile / link / pack / install operations canary
already wraps are typed transformers:

```
fetch   : Package(PM) → Source
build   : Source → Native × Headers
compile : Native × Headers → Binding(L)
pack    : Binding(L) → Package(PM')
link    : Binding(L) × Native → App
install : Package(PM) → Path

Γ ⊢ compile(native, headers, strategy) : Binding_record(L)
  where strategy ∈ {stub, ffi, jit, bindgen}
```

Transformers are *partial*: `build` fails if the source is
misconfigured; `compile` fails if the native interface doesn't
satisfy the binding's expectations; `link` fails if symbols are
missing or SONAME mismatches. Canary today wraps each transformer
with pre/post inspections; the formal version would type-check the
composition statically.

The syntactic surface is the **declared type** — what the developer
wrote. The semantic surface is the **inferred type** — what the
inspector extracts. A well-behaved build pipeline satisfies:

```
inferred_type(artifact) <: declared_type(artifact)
```

When this fails — the inferred type is *weaker* than the declared
type — there is a gap that either the toolchain or the theory must
explain. The verification angle: if each transformer has a type
signature (pre-surface → post-surface), the composition can be
checked *before* running a full build. A mismatch (e.g. a libffi
dependency that won't be satisfied at load time) becomes a type
error at the artifact level rather than a probe failure at runtime.

This is the direction roadmap step 4 starts to enable: as
inspectors and comparators land (c4..c8), the contract checks
become real predicates over typed surface roles, and per-transformer
type-checking becomes a tractable static analysis.
