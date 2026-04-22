# Canary: Version, Interface, and Contract Design

## Motivation

Canary already detects compatibility failures empirically — run the build, check
the symbols, compile the probe. The current failure modes we can observe:

| Failure kind | Example in canary | Detection |
|---|---|---|
| Missing symbol (binary) | Z3 OCaml stub requires `Z3_mk_solver`, lib has it | `nm` + `assert_binary_symbols.py` → `Expect_symbols` |
| Type mismatch (OCaml API) | `llvm.19-shared` missing `Opcode.UncondBr` | `Expect_failure { contains_any }` |
| Linking mode change | ELF versioned symbols `Z3_foo@@Z3_4.15` vs plain `Z3_foo` | `nm -D` regex must allow `@@` suffix |
| ABI/soname change | shared vs static, soname mismatch | (not yet modelled) |
| Semantic/invariant failure | behavior change without API break | (not yet modelled, likely undetectable statically) |

The question is: can we give these failures a **unified abstract representation**
rather than scattered ad-hoc checks? And can we lift version numbers into the
picture so that "apt has z3 4.8, but the binding was built against z3 4.12" is
a first-class analysis result, not just an observed runtime crash?

## Background connection

The pkgm paper models packages as version-constraint systems (see
`/home/red/code/write/doc-pkgm`). The formalism handles `version ≥ x`, `~>`,
SAT/UNSAT over dependency graphs. What it currently lacks is a semantic model
of **what changes across versions** — the interface the package exposes and
how that interface evolves.

Tola's `src/versioning/` has `Version_logic.Make` which can already solve
multi-package version constraints. This doc is about adding the layer above:
what does a version of a package *provide* and *require*, not just its number.

## Vision: Interface as First-Class Object

A library artifact has two roles:

```
artifact.provides : interface    (* what it exports *)
artifact.requires : interface    (* what it depends on *)
```

**Compatibility** = `consumer.requires ⊆ provider.provides`

This is a subtyping / Liskov-style contract:
- Provider must be at least as capable as consumer expects.
- Extra symbols/types in provider are fine (covariant in output).
- Missing symbols/types in provider → incompatibility (the current failure case).

An **interface** is a named set of observable facts about an artifact. Currently
we think of it as symbols, but the levels are:

| Level | Granularity | Detection method |
|---|---|---|
| L1 Symbol | binary exported names (`Z3_mk_solver`) | `nm -D` |
| L2 Type signature | OCaml type of exported value | `ocamlobjinfo`, `.cmi` digest |
| L3 API shape | constructor set, module structure | compile probe |
| L4 ABI/calling convention | struct layout, calling convention | (hard; DWARF/clang-ast) |
| L5 Behavioral contract | pre/post conditions | (research territory) |

Canary today covers L1 (Expect_symbols) and L3 (Expect_failure probe compile).
L2 is partially covered — `.cmi` digests are checked implicitly by `ocamlfind`.

## Concrete Example: Z3 dev vs apt stable

```
z3_dev.provides  = { symbols: {Z3_*}, ocaml_api: {Z3.Solver, Z3.Expr, ...} }
z3_apt.provides  = { symbols: {Z3_*}, ocaml_api: {Z3.Solver, Z3.Expr, ...} }
                                         ↑ same names, but different types/arity
z3_binding_dev.requires = { symbols: {Z3_*}, ocaml_api: {Z3.Solver.add_clause} }
```

The mismatch: `z3_binding_dev` was compiled against `z3_dev`'s `.cmi` files;
linking it against `z3_apt`'s `libz3.so` may succeed at the symbol level (L1 ✓)
but fail at type level (L3 ✗) or silently misbehave (L5 ✗).

The `z3/stable` probe in canary demonstrates this by compiling the dev example
against the stable system lib — the compile succeeds but the example may
behave differently or link against mismatched ABI.

## Concrete Example: LLVM 19 vs dev binding

```
llvm_19.provides  = { ocaml_api: { Opcode.Br } }    (* no UncondBr *)
llvm_dev.provides = { ocaml_api: { Opcode.Br, Opcode.UncondBr, ... } }

binding_dev.requires = { ocaml_api: { Opcode.UncondBr } }
```

`binding_dev.requires ⊄ llvm_19.provides` → expected compile failure.
This is already detected and **expected** in canary (Expect_failure).
With a first-class interface model it becomes a checked contract, not
just a grep on an error string.

## Failure Taxonomy (expanded)

Beyond symbol-missing:

**Additive change (safe)**: provider gains new symbols. Consumer unaffected.
```
z3_4.13.provides ⊇ z3_4.12.provides   →   any consumer of 4.12 works with 4.13
```

**Subtractive change (breaking)**: provider loses symbols.
```
llvm_19.provides ⊄ llvm_dev.provides   →   consumer of dev fails against 19
```
Already detected by Expect_failure in canary.

**Mutating change (subtle breaking)**: same symbol name, different signature.
```
Z3_mk_solver: v4.12 returns `Z3_solver`, v4.15 returns `Z3_solver*`
```
L1 check (symbol present) passes; L2/L3 check fails. Not yet detected.

**Linking mode change**: symbol versioning (`Z3_foo@@Z3_4.15`), soname change,
shared-vs-static switch. May cause dlopen failure or silent symbol resolution
to wrong version.
Already partially handled: `assert_binary_symbols.py` regex allows `@@` suffix.

**Semantic / invariant change**: API unchanged but behavior differs (e.g., a
solver tactic removed, a default changed). Undetectable without behavioral tests.
Out of scope for static analysis; could be a canary probe_app pattern.

## First Step: Unified Symbol/Interface Term per Artifact

Rather than ad-hoc checks scattered across probe steps, give each artifact an
`interface` value:

```ocaml
type symbol_name = string   (* e.g. "Z3_mk_solver" *)
type type_id = string       (* e.g. "Z3.Solver.t -> Z3.expr list -> unit" *)

type interface_level =
  | Symbols of symbol_name list           (* L1: nm-visible exports *)
  | Ocaml_types of type_id list           (* L2: .cmi-level types *)
  | Compile_probe of string               (* L3: compile a small program *)

type interface = {
  provides : interface_level list;
  requires : interface_level list;
}
```

Each canary `source_repo` can declare its interface. The `probe_*` steps
become **compatibility checks**: does `artifact.provides ⊇ consumer.requires`?

This unifies:
- `Expect_symbols` (L1 check: does provided_lib have the required symbols?)
- `Expect_failure` for compile probes (L3 check: does the OCaml API include what the probe needs?)
- Future ABI checks (L4)

And makes the checks **declarative**: the project spec declares what it provides
and what it requires; `derive_steps` generates the right probe steps from that.

## Connection to Version Logic

With interface as a first-class object, a version is no longer just a number —
it carries an interface snapshot:

```ocaml
type versioned_artifact = {
  version : Version.t;
  interface : interface;
}
```

Version constraint solving (already in `Version_logic`) then becomes:
"find a version of Z3 such that `z3_binding_dev.requires ⊆ z3_v.provides`."

This is the bridge between the pkgm paper (version constraint SAT) and the
interface model (what changes across versions). The combined system can answer:

- "Which apt version of Z3 is compatible with this OCaml binding?"
- "At which Z3 version did `Z3_mk_optimize_assert_soft` first appear?"
- "What is the minimal LLVM version that provides `Opcode.UncondBr`?"

## Roadmap

### Step 1 (now): Unify symbol checks with an abstract interface term
- Define `interface` type in canary (covering L1 symbols + L3 compile probes)
- Annotate each `source_repo` with `interface` (provides + requires)
- Have `derive_steps` generate probe steps from interface declarations
- Replace scattered `Expect_symbols` and `Expect_failure` patterns with
  `check_compatibility ~provider ~consumer`

### Step 2: Interface diff across versions
- Record the interface for each probed artifact version
- Compute the diff: `interface_v2 \ interface_v1` (added) and
  `interface_v1 \ interface_v2` (removed)
- Output: per-artifact interface changelog

### Step 3: Connect to version constraint solving
- Represent interface compatibility as a constraint: `v ≥ min_version_with_api`
- Integrate with `Version_logic.Make` to answer "which version satisfies X?"
- Bridge to the pkgm formalism: version constraints + interface requirements

### Step 4 (research): Semantic contracts
- Behavioral probes (probe_app level) as interface at L5
- Property-based testing against a declared behavioral interface
