# Yelu Typed AST — Design Space

> Status: **Deferred, design settled.** AST has stabilized (group
> restructuring complete, April 2026). Preferred direction: first-class
> types as AST data, gradual static→dynamic spectrum, per-theory
> isolation before integration. Implementation begins when a concrete
> research question requires it.

## Why deferred

The AST-level restructuring (11 nested variant groups) is recent and may
still see revisions. Every pre-stabilization refactor of `yelu_exp`
would double the work if a typed layer is already built on top.

Typing is an additive concern: the current untyped AST already supports
the research program (LLM correctness on yelu vs. raw cmake). Types
sharpen the edges but aren't prerequisites.

## Rejected options

**(a) Typed smart constructors only** — helpers in `lang_yelu_utils.ml`
carry rich OCaml types, AST stays untyped. The constraint dies at the
helper boundary; downstream consumers of `yelu_exp` can't tell what a
node was supposed to be. Useful as a tactical addition; not a type
system.

**(b) GADT-encoded AST with OCaml-level type parameters** — e.g.
`('a yexpr)` where `'a` is the cmake value type. Hard to get right
first time; whole-codebase lock-in. More importantly, cmake's type
lattice has constraints OCaml's type system can't express (external
probes, directory-level policies, cache-sensitivity, etc.) — forcing
them into GADTs leaves the interesting half outside the type system.

**(c) Full GADT with dependent-style encoding** — ambitious, research-
grade. Same objection as (b), amplified.

## Preferred direction

**First-class types as AST data, with gradual static→dynamic
enforcement.** Types are OCaml values that annotate the AST, not OCaml
phantom types that constrain it. Enforcement is a separable checker
pass; strictness is pluggable per project or per pack.

This matches gradual/soft typing (Typed Racket, TypeScript) rather than
strong static ML-style typing. The right model because:

- cmake's constraints are heterogeneous: some purely structural (bool
  vs. string), others semantic (scope, cache-sensitivity), others
  external (path exists, symbol present in library). First-class types
  accommodate all three under one vocabulary.
- A checker pass decouples type enforcement from AST construction.
  Iteration on the type system doesn't require rewriting code that
  builds the AST.
- Gradual = incremental adoption. Untyped code still works; annotated
  code gets checked. Natural A/B comparison for research.

## Design axes to explore

### 1. What dimensions to type (beyond value shape)

Value shape is the obvious axis: `Ty_bool | Ty_int | Ty_string | Ty_path
| Ty_target | Ty_list of t | ...`. But cmake has real distinct
dimensions that are all type-worthy:

- **Scope** — target / directory / source / test / global / cache / env.
  A property setter's type should encode which scope it operates on.
- **Phase / stage** — compile-time / configure-time / build-time /
  install-time. Ties directly to Y8 (multi-stage core). A cvar known at
  configure-time has a different type than one only available at
  build-time (generator-expression territory).
- **Effect / cache-sensitivity** — ties to Y7. `CMAKE_C_COMPILER` is
  cache-breaking; `CMAKE_BUILD_PARALLEL_LEVEL` isn't. The *effect* of a
  statement is as typeable as its value shape.
- **Pack provenance** — `Ty_cmake_only` vs. `Ty_core`. Makes the
  yelu-core / pack boundary legible in the type system.

Typing multiple dimensions simultaneously (shape × scope × phase ×
effect) turns the checker into a general policy engine, not just a
well-formedness checker.

### 2. Evidence-bearing types (canary convergence)

A type like `Ty_path_that_exists` has two interpretations:

- Static annotation: the author claims it exists; the checker takes
  their word.
- Evidence-bearing: the value *carries* a probe result proving it
  exists.

Richer design:

```ocaml
type 'a with_evidence = { value : 'a; evidence : proof option }
```

where `proof` is a canary-style probe result. This unifies static +
dynamic + external-check vocabulary under one machinery, and ties
yelu's type system directly to canary's probe/check framework (the same
proof objects).

### 3. Bidirectional typing

Some positions **synthesize** a type (literals, helper returns), others
**check** against an expected type (RHS of a typed cvar, arg of a typed
command). Picking bidirectional explicitly gives better ergonomics than
full inference — annotations go only where the author wants them.

### 4. Types as LLM substrate

Standard type-system design optimizes for human safety + compiler
efficiency. Yelu's research frame adds a third goal: types are the
structure an LLM queries and completes against. Implications:

- Types should be **searchable** (given a type, enumerate helpers
  producing/consuming it).
- Type errors should carry **why** (declared here, inferred from X,
  required by Y) — repair-oriented, not just diagnostic.
- Consider dumping typed-AST summaries into LLM prompts as structured
  context. The type system becomes a serialization format for "what
  this program does" at multiple granularities.

### 5. Type holes and strictness pragmas

- `?` (hole) — "infer this, I don't know or want to say." Useful for
  interactive development; compiler returns the inferred type.
- `?T` (trust-me annotation) — "treat this as T without checking."
  Escape hatch when the checker is too weak, reviewable over time.

### 6. Pack-parametric typing

Yelu-core types (bool, int, string, list) are pack-independent.
Cmake-specific types (`Ty_target`, `Ty_cache_entry`) are modular. The
typed layer should mirror the core+pack architecture: `module type
YELU_TYPES` for core, extended per pack. Gives future json-pack /
nix-pack clean extension points.

## Load-bearing priorities

Of the six axes above, (1) multi-dimensional typing and (2) evidence-
bearing types are the ones that most justify building a type system at
all. They connect directly to existing backlog items (Y7, Y8) and to
canary. The other four are refinements that matter once (1) and (2)
exist.

## Concrete starting sketch (when we start)

Minimal change to existing AST:

1. Add `yelu_type` + `yelu_probe` as a **data module** (new file,
   doesn't touch `yelu_exp`).
2. Prototype a **checker pass**: takes `yelu_exp`, walks it, returns
   `(error list, inferred_types)`.
3. Attach types to `yelu_cvar` and `yelu_target` as **optional fields**.
   These are the highest-leverage nodes.
4. Leave everything else untyped; tighten opportunistically.

If the checker needs structure the current AST can't carry, revisit
whether to clone the AST or add fields. Most likely the optional-field
approach is enough for a long time.

## When to actually start

Build the typed layer when at least one of these becomes true:

1. The AST has stabilized — no group-level refactors for 3+ months.
2. We're ready to measure a concrete research question that requires
   types (e.g. "does typing improve LLM first-pass correctness?").
3. A specific downstream feature (canary integration, staging
   enforcement, policy checking) requires type info at the AST level
   that smart-constructor-enforced typing can't provide.

Until then, the untyped AST + OCaml-level constraints in helpers are
sufficient.

## Theory-composition architecture

Yelu's `lang_yelu.ml` is a collection of **theories over a shared substrate**
in the lambda-calculus sense. Each `Make_xxx` functor is one theory; `Make_stmt`
bundles them into an integrated system; the cmake-pack is the integration point.

### Pure core

- `LANG_TYPES` — substrate signature (var, expr, target)
- `Make_cond` — boolean theory
- `Ylet / Yif / Ystmt_list` in `yelu_stmt` — binding and control flow

### Theories

| Theory | Functor | cmake-specific? |
|---|---|---|
| JSON | `Make_json_op` | no — pack-agnostic |
| String | `Make_string_op` | mostly |
| List | `Make_list_op` | yes |
| File/path | `Make_file_op` | yes |
| State/variable | `Make_state_op` | yes |
| Target | `Make_target_op` | cmake-specific |
| Directory | `Make_dir_op` | cmake-specific |
| Find | `Make_find_op` | cmake-specific |
| Install | `Make_install_op` | cmake-specific |
| Test | `Make_test_op` | cmake-specific |
| Try | `Make_try_op` | cmake-specific |
| Cmake meta | `Make_cmake_op` | cmake-specific |

### Typing implication

Each theory carries its own `yelu_type` fragment — what types its constructors
produce and consume — and its own checker. The integrated cmake-pack checker
is the composition of per-theory checkers.

This matches the lambda-calculus analogy: `int-theory`, `let-with-int-theory`,
`type-for-int-theory`, `let-typed-with-int-theory`. For yelu:

- `string-theory` — syntax (`Make_string_op`) + type fragment + checker
- `let-typed-with-string-theory` — integrated cmake-pack with string checker wired in

Each theory is testable in isolation before integration. The functor boundary
already provides the isolation; the type + checker layer is what needs to be
added per functor module.

### Recommended entry point

JSON (`Make_json_op`) or string (`Make_string_op`) — both are relatively
self-contained. JSON is the most pack-agnostic. Implement type fragment +
checker for one theory standalone, then wire into the cmake-pack integrated
checker.

### typed_yelu_cmake vs yelu_cmake

A second pack instantiation (`typed_yelu_cmake`) uses `yelu_typed_expr` as
the substrate (`T.expr`). All functor-generated statement types are shared by
construction — no duplication. The typed pack opt-in is a substrate choice, not
a code fork.

## Open questions (deferred to implementation time)

- Checker as pure pass (functional), constraint-based (collect +
  solve), or online (during compilation)?
- Polymorphism and subtyping: how much of each does the cmake-pack
  actually need? (`yarg` already has an implicit hierarchy.)
- Type inference strategy: local bidirectional, or
  Hindley-Milner-style? Bidirectional probably right for DSL.
- Integration with canary probes: shared data types, or separate with
  coercions?
- How much of the type system is part of yelu-core vs. per-pack?
