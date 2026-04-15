# Research Prompt: E-graphs / Z3 for CMake Equivalence Checking

I'm exploring two PL/verification techniques — **e-graphs** and **SMT/Z3** — for a specific problem: semantic equivalence checking of CMake programs. I want a realistic assessment of how practical each approach is, and whether there's a natural fit or fundamental mismatch with CMake's semantics.

---

## Background: CMake as a language

CMake's configure-time language (CMakeLists.txt) is a restricted imperative language with these properties:

- **Straight-line code + boolean conditionals** — `if(USE_MYMATH) ... else() ... endif()`
- **String-typed variables** — all values are strings (or semicolon-joined lists, which are also strings)
- **6 independent namespaces** (empirically confirmed via 24 probes): TARGET, Variable, Cache, COMMAND, TEST, POLICY. A name like `foo` can simultaneously exist in all six — they never collide.
- **No unbounded loops** (foreach is over a finite list), no higher-order functions
- **Mutation**: variables are set with `set(VAR value)` and can be overwritten. Scope is per-directory/function.
- **Side effects at configure time**: `find_package`, `execute_process`, `file(READ ...)` — these are not pure.
- **Option variables** (CMake cache): boolean flags like `option(USE_MYMATH "use math lib" ON)` that users configure. These are the "inputs" to a configure run.

The configure-time language (the part we care about) is mostly decidable: you can enumerate all `option()` combinations and run cmake. The build-time part (compiler invocations, linking) is separate and out of scope.

**Key point**: cmake's File API captures only one concrete configure-run — dead branches are pruned. So running `cmake -S . -B build` and inspecting the JSON output only proves point equivalence for one config point.

### Scale of the cmake surface

The canonical cmake source (cmake 4.3 dev) contains:
- 133 commands documented in `Help/command/` (each a `.rst` file)
- 431 target properties in `Help/prop_tgt/`
- 802 variables in `Help/variable/`
- 270 modules in `Help/module/`
- 313 test cases in `Tests/`, each a self-contained cmake project

Notable test subdirectories for our purposes:
- `Tests/CMakeOnly/` — cmake-script-only tests, no compiler needed. Ideal for symbolic encoding benchmarks.
- `Tests/CMakeCommands/` — tests for individual cmake commands.

---

## Background: The yelu project

**Yelu** is a typed, single-assignment configuration language that compiles to CMake. Yelu programs are written as an OCaml EDSL — build specs are OCaml programs using `Yelu_langs` that print CMakeLists.txt to stdout:

```
build_spec.ml (OCaml + Yelu_langs)
  → ocamlopt (dune)
  → build_spec.exe → stdout → CMakeLists.txt
  → cmake → Makefile/Ninja → cc/c++
```

Key source files (all under `yelu/`):
- `src/langs/yelu/lang_yelu.ml` — typed yelu AST (targets, variables, string kinds)
- `src/langs/cmake/lang_cmake.ml` — stringly-typed cmake AST (the IR)
- `src/langs/yelu/lang_yelu_compile.ml` — yelu AST → cmake AST (type erasure)
- `src/langs/cmake/lang_cmake_pp.ml` — cmake AST → printed text

**Design principle**: cmake AST is stringly-typed (mirrors real cmake, no semantic types). Yelu AST owns all typed constructs: `Ycvar` (Variable namespace), `Ytarget` (Target namespace), typed conditions (`yelu_cond`), typed string kinds (`Ycs_file | Ycs_dir | Ycs_name | Ycs_val`). Yelu's compile step erases types down to cmake AST.

The central correctness question is: **is the generated CMake semantically equivalent to a reference CMake program?**

Equivalence levels we care about, roughly ranked:

1. **Text diff** — exact string equality (too strict, breaks on safe reorderings). *Currently used in all yelu compile tests.*
2. **AST structural equality** — same AST, different formatting (still order-sensitive).
3. **File API diff** — run cmake, compare JSON output (targets, deps, cache vars). Order-independent for most things. Tests one config point. *Infrastructure exists (`cmake_file_api_cmp.py`), not yet wired into regular tests.*
4. **Full equivalence** — equivalent for ALL option combinations (2^n configs for n boolean options). This is the research goal.

---

## The research questions

### Question 1: E-graphs for cmake equivalence

E-graphs (as in egg / egglog) are typically used for term rewriting and equality saturation over functional expressions. CMake is not a functional language — it's stateful and order-sensitive. But:

- The pure/functional fragment (pure string expressions, `if`/`else` as `ite`, variable reads as pure lookups in a snapshot) might be encodable as terms.
- We might want to prove that two statement sequences produce the same final environment (variable map + target set + dep graph) for all inputs.
- Could e-graphs model "equivalent cmake statement sequences" — e.g., `set(A foo)` then `set(B bar)` ≡ `set(B bar)` then `set(A foo)` when A ≠ B?

Is there a natural encoding of imperative state transformers into e-graphs that would let equality saturation prove these equivalences? Or does the statefulness fundamentally break the approach?

### Question 2: Z3 for cmake equivalence

The alternative is to encode cmake semantics as a symbolic interpreter and use Z3 to prove equivalence:

- Option variables become Z3 boolean constants (free variables).
- `if(USE_MYMATH)` becomes Z3 `ite(use_mymath, then_env, else_env)`.
- Variable state is a symbolic map (string → Z3 expression).
- The "environment" at the end of two programs is a pair of symbolic maps. Assert they differ (∃ assignment where env1 ≠ env2), check SAT. UNSAT = equivalent.

This feels tractable for the pure fragment. Problems I anticipate:

- Side effects (`find_package`, `execute_process`) are not symbolic — need to be either stubbed or excluded.
- CMake's string operations are complex (regex, list manipulation) — encoding them in Z3 may be painful.
- The environment is a map from string keys to string values — Z3 strings/sequences might handle this but could be slow.

Is Z3's theory of strings (sequences) practical here? What are the known pitfalls?

### Question 3: Comparative assessment

Given the structure of the problem — decidable fragment, finite boolean inputs, string-valued state, mostly pure configure-time code, a few opaque side-effectful commands — which approach is more practical? Is there prior work on:

- Semantic equivalence of Makefile/build-system configurations?
- Symbolic execution of CMake or similar DSLs?
- Using e-graphs for imperative program equivalence (beyond expression-level rewriting)?

I'm also open to entirely different approaches — e.g., abstract interpretation, bisimulation, translation validation.

---

## What I'm looking for

1. A realistic assessment of whether e-graphs fit this problem at all (or if they're fundamentally the wrong tool).
2. A concrete sketch of how Z3 encoding would look for a small cmake fragment (e.g., one `if(USE_MYMATH)` block that sets a variable and conditionally adds a subdirectory).
3. Any prior work I should read.
4. A recommendation on where to start, given limited engineering time — specifically: is `Tests/CMakeOnly/` a good source of benchmark programs for an initial symbolic encoding experiment?
