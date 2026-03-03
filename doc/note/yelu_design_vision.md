# Yelu Design Vision

## Positioning

yelu is NOT:
- a better template language
- cmake syntax sugar
- a build system

yelu IS:
- a **programmable configuration shell language** providing universal programmability + static checking for target languages
- designed for both human and LLM program synthesis

## Two-Layer Architecture

1. **Core layer** (language-agnostic): bindings, composition, sequencing, optional types
2. **Language pack layer** (per-target): cmake / json / yaml packs providing safe abstractions, checks, lowering

yelu programs target one pack at a time — it doesn't mix languages, only hosts them.

## Syntax and Semantics

Surface syntax is Python-like:
```
x = expr
x: T = expr
def f(a, b) = expr
def f(a: A, b: B): R = expr
(expr : T)
```

But semantically a **staged configuration language** with hard boundaries:
1. `=` is **binding, not mutation** (single assignment)
2. No runtime IO
3. Primitives **construct AST**, not execute commands
4. Types/constraints are **compile-time contracts**
5. All errors fail before emit

## Build System Relationship

yelu sits above cmake, not inside it. Three real layers in build systems:
1. **conf/analysis** — describe targets, dependencies, command shapes
2. **generation** — generate backend (Makefile / Ninja / IDE)
3. **execution** — parallel scheduling, incremental builds, runtime dep discovery

CMake mainly covers 1 + 2. Ninja / Bazel are the execution layer.

Evolution path:
- **Short term**: yelu → cmake AST → Make/Ninja (verify compatibility)
- **Medium term**: introduce abstract action graph IR
- **Long term**: possibly direct Ninja generation or own executor

Key insight: the conf layer's real optimization is not "faster" but **earlier, more structured failure**, leaving parallel work to the execution layer.

## LLM Design Goals (First-Class)

CMake is hostile to LLMs: irregular syntax, implicit semantics, late/vague errors. yelu is designed to be LLM-friendly through:

- Regular, stable syntax (Python-like for training distribution match)
- Explicit primitive API
- Strong static checking = automatic oracle for LLM feedback loops
- Early, local, explainable errors
- Compile step erases complex target-language semantics

## Research Angle

The key research question is not "yelu is better than cmake" but:

> Which language properties improve LLM program synthesis?

This requires controlled-variable experiments (factorial design):
- Syntax regularity
- Single-assignment binding
- Error exposure stage
- AST stability

Metrics:
- First-pass correctness
- Repair convergence steps
- Error locality
- Semantic edit distance
- Prompt robustness

Target: PL × synthesis × LLM intersection.
