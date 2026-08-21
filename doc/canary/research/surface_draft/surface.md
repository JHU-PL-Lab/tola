## Part B — Theory primitives

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

### 2.1 Per-side surfaces — the six surface roles

Each side (native and binding) presents two surfaces: a
**syntactic** surface (declarative, what the developer wrote) and a
**semantic** surface (extracted, what the binary actually contains).
The binding side further splits its syntactic surface into a
**stub** layer (close to the C side, s3) and a **header** layer
(user-facing, s4); see §2.2.


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
bindings, see [`tiny.md`](../tiny.md).

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

## Part C — Contracts & derivations

A **surface** is the interface an artifact presents at its boundary
(see §0). A **contract** is a predicate pinning one surface of the
native side to one surface of the language side and asserting they
must agree. Surface theory's job is to enumerate the contracts, say
*which* pair of surfaces each one aligns, and provide a mechanical
check. The running concrete witness is `tiny` ([`tiny.md`](../tiny.md));
the Z3 instantiation in §2.1 grounds the abstract roles in a
real-world target.