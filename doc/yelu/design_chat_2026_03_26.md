# Yelu Design Chat — 2026-03-26

Session context for continuation. Covers three connected design threads.

---

## 1. cmake function/macro Semantics & Yelu Implications

**Finding:** Both `function()` and `macro()` are pure configure-time constructs.
- `macro()` = textual substitution (no scope, like C `#define`)
- `function()` = new variable scope, args are local, `PARENT_SCOPE` to export

**Implication for yelu:** A yelu-level function mechanism (compile-time expansion) covers the same ground. Since yelu step files are OCaml programs, parameterized blocks, looping, and recursion are already available via OCaml functions — strictly more powerful than cmake's `function()`.

The only reason to *emit* cmake `function()` definitions would be if the generated CMakeLists.txt needs to be consumed/extended by downstream projects.

---

## 2. Surface Syntax: Namespace-as-Type

**Question:** Can namespace membership (target vs cvar vs file vs dir) and target kind (exe/lib) be static types in yelu's surface syntax?

**Answer:** Yes. cmake's namespaces are statically distinguishable at definition sites:
- Target kind (exe/lib/interface/imported) is fixed at `add_*` call, never changes
- Cache var type (BOOL/STRING/PATH) is fixed at `set(... CACHE)`
- Normal variables are untyped strings

**Proposed syntax direction:**
```
let tut = exe "Tutorial" [sources: "tutorial.cxx"]
let math = lib "MathFunctions" [sources: "MathFunctions.cxx"]
let flags = interface_lib "compiler_flags"
tut.link [math; flags]
tut.include [output_root]
```

**Design decision:** Erase target kind after definition (option 1). A single `target` type suffices since kind-sensitive operations are rare in cmake. The big win is **namespace separation** — making it impossible to write `link_lib [a_file]` or `include_dirs [a_target]`. The namespace IS the useful type; sub-kind within a namespace is mostly cosmetic.

Currently `yarg` lumps targets, cvars, files, dirs, and strings together. A typed surface syntax would prevent cross-namespace misuse at compile time.

---

## 3. cmake vs Shell String Semantics

Key differences for language design:

| | cmake | shell |
|---|---|---|
| List separator | `;` semicolon | IFS (space/tab/newline) |
| Lists ARE strings | `set(x a b c)` = `"a;b;c"` | arrays are separate type |
| Quoting | only `"..."` | `'...'` literal, `"..."` expand |
| Implicit deref | `if(FOO)` reads variable FOO | `[ FOO ]` tests string |
| String ops | `string()` command only | rich inline `${var%pat}` etc. |

**Biggest gap:** cmake's `;`-list conflation (data format = list format). Yelu should keep this as compiler-internal detail, never expose in surface syntax.

**Implicit dereference** in `if()` is exactly the kind of footgun yelu should compile away.

---

## 4. Program Equivalence for Build Configurations

**Problem:** Proving yelu-generated cmake is equivalent to reference cmake for ALL variable assignments, not just one configuration point.

**Key insight:** cmake's File API captures only one concrete configure run — dead branches are pruned. So diffing File API output proves equivalence for one point in config space only.

**cmake's config language is a decidable fragment:** straight-line code with boolean conditionals and string assignments, no unbounded loops, no higher-order functions. This makes equivalence tractable.

### Approaches ranked by practicality:

| Stage | Method | Proves |
|-------|--------|--------|
| Now | File API diff, 1 config | point equivalence |
| Next | Enumerate all option combos | full equivalence for finite booleans |
| Later | Symbolic — encode as SMT, check with Z3 | equivalence for all inputs |

### Research techniques (SOTA):
1. **SMT-based equivalence** — encode both programs as formulas, assert they differ, check SAT. UNSAT = equivalent. **Alive2** (LLVM) is closest in spirit.
2. **Translation validation** (Pnueli et al. 1998) — verify each compilation output matches input, don't prove compiler correct in general.
3. **Symbolic execution / Rosette** (Torlak & Bodik) — write reference semantics + implementation, solver finds discrepancies.
4. **Content-addressed derivations** (Nix/Guix) — hash the derivation, compare hashes. Side-steps program equivalence.

**Z3 connection:** The symbolic approach would encode cmake conditionals as Z3 `ite` expressions — each `if(USE_MYMATH)` becomes a symbolic branch. Assert outputs differ, check SAT. Z3 is already in the repo.

### Complex cmake benchmarks for testing:
- **LLVM/Clang** — cmake metaprogramming (`llvm_add_library`), cross-compilation
- **Qt** — massive generated cmake, custom install logic
- **KDE/ECM** — essentially a cmake framework
- **Z3** — mid-complexity, already in workspace, good practical target
- **OpenCV** — dozens of optional deps, huge platform matrix

---

## Open Threads / Next Steps

- Design yelu surface syntax with namespace-as-type (separate from current OCaml DSL AST)
- Extend test harness to enumerate option combinations (2 options = 4 configs per step)
- Explore Z3-based symbolic equivalence checking for cmake programs
- Consider whether yelu functions should emit cmake `function()` for downstream consumption
