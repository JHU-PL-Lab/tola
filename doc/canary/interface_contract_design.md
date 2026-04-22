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
| L1a Symbol | binary exported names (`Z3_mk_solver`) | `nm -D` |
| L1b Versioned symbol | runtime version requirement (`malloc@@GLIBC_2.31`) | `nm -D` `@@` annotations |
| L2 Type signature | OCaml type of exported value | `ocamlobjinfo`, `.cmi` digest |
| L3 API shape | constructor set, module structure | compile probe |
| L4 ABI/runtime | C runtime implementation + version, C++ ABI, soname | `readelf -d`, `ldd` |
| L5 Behavioral contract | pre/post conditions | (research territory) |

Canary today covers L1a (Expect_symbols) and L3 (Expect_failure probe compile).
L1b is partially handled — `assert_binary_symbols.py` allows `@@` suffixes in
`nm` output but does not yet treat the version part as a constraint.
L2 is partially covered — `.cmi` digests are checked implicitly by `ocamlfind`.

The glibc/musl example lives at **L1b + L4**: the `@@GLIBC_2.31` annotation
is detectable at L1b, and "which C runtime implementation" is an L4 property.
Both fold into the same unified interface model.

## Concrete Example: C Runtime Mismatch (glibc vs musl)

A library compiled against glibc 2.31 carries versioned symbol requirements
visible in its binary:

```
$ nm -D libz3.so | grep malloc
  malloc@@GLIBC_2.17
  __cxa_throw@@GLIBC_2.3.4
```

A system running glibc 2.17 or musl libc cannot satisfy `@@GLIBC_2.31`.
The failure is a **runtime linker error** — not a missing symbol (both provide
`malloc`), but a missing *versioned* symbol. Users see:

```
/lib/x86_64-linux-gnu/libz3.so: /lib/x86_64-linux-gnu/libc.so.6: version
  `GLIBC_2.31' not found
```

This is detectable from the binary before any runtime is involved. The `@@`
annotations in `nm -D` output encode the required runtime interface exactly.
`assert_binary_symbols.py` already handles `@@` suffixes; the next step is to
treat the version part as a *constraint* rather than ignore it.

The **abstraction**: instead of saying "linked against glibc 2.31" (a toolchain
detail), the artifact's interface declares:

```
libz3.requires.c_runtime = { implementation = Glibc; version = >= 2.31 }
```

The deployment environment provides:

```
ubuntu_20_04.provides.c_runtime = { implementation = Glibc; version = 2.31 }
alpine_3_18.provides.c_runtime  = { implementation = Musl;  version = 1.2.3 }
```

Compatibility check: `artifact.requires.c_runtime ≤ environment.provides.c_runtime`.
Alpine fails; Ubuntu 20.04 exactly satisfies.

This is the same subtyping check as the Z3/LLVM API examples — the C runtime
is just another versioned interface, one level below the library's own API.

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
type symbol_name = string    (* e.g. "Z3_mk_solver" *)
type versioned_symbol = {
  name    : string;          (* e.g. "malloc" *)
  version : string;          (* e.g. "GLIBC_2.31" — from @@ annotation in nm -D *)
}
type type_id = string        (* e.g. "Z3.Solver.t -> Z3.expr list -> unit" *)

type c_runtime = Glibc | Musl | Bionic | Other of string
type cxx_runtime = Libstdcxx | Libcxx | Other of string

type runtime_req =
  | C_runtime   of { impl: c_runtime;   version_min: string }
  | Cxx_runtime of { impl: cxx_runtime; version_min: string }
  | Soname      of { name: string;      version: string option }

type interface_level =
  | Symbols          of symbol_name list           (* L1a: nm -D exports *)
  | Versioned_syms   of versioned_symbol list      (* L1b: @@GLIBC_x.y requirements *)
  | Ocaml_types      of type_id list               (* L2: .cmi-level types *)
  | Compile_probe    of string                     (* L3: compile a small program *)
  | Runtime_reqs     of runtime_req list           (* L4: C/C++ runtime, soname *)

type interface = {
  provides : interface_level list;
  requires : interface_level list;
}
```

`Versioned_syms` and `Runtime_reqs` together capture the glibc/musl case:
a binary's `@@GLIBC_2.31` annotations become `Versioned_syms` in its `requires`;
the deployment environment's glibc version becomes `Runtime_reqs` in its `provides`.
The compatibility check is the same `requires ⊆ provides` relation, now spanning
from OCaml constructor names all the way down to C runtime version symbols.

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
