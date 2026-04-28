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

## Checking stages

Yelu programs pass through multiple stages before runtime. Each stage can
detect a different class of errors; earlier is cheaper. This table maps the
full spectrum for yelu/cmake and notes what is currently implemented.

| Stage                   | Runner                       | Detects                                                                                                        | Status                                                                                 |
| ----------------------- | ---------------------------- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| **S0 Syntactic local**  | Yelu checker (per-stmt)      | Type mismatches within a statement; bool where string expected                                                 | ✅ `Make_cond_check`, `Make_string_check`, `Cmake_check`                                |
| **S1 Syntactic global** | Yelu checker (whole-program) | Use-before-define, undefined target reference, duplicate names, unused bindings                                | ⏳ not started; needs a second pass over the program graph                              |
| **S2 Semantic / scope** | Yelu checker (scope-aware)   | Operation outside valid cmake scope (e.g. `target_*` in script mode); cache variable set after first configure | ⏳ requires a scope dimension in `yelu_type`                                            |
| **S3 Emit-time**        | Yelu compiler                | Structural errors during AST → cmake lowering                                                                  | ⚠️ partial — compiler panics on malformed input but has no systematic pass              |
| **S4 Conf-time**        | cmake itself                 | `REQUIRED` find_package fails, `math(EXPR)` malformed, policy violations                                       | ✅ covered by `make runcmake-compat` and `make file-api-test` (observed, not predicted) |
| **S5 Conf-result**      | File API / canary            | Target shapes, cache entries, property attachments — the *output* of configuration                             | ✅ `make file-api-test` diffs codemodel-v2 JSON                                         |
| **S6 Build-time**       | Compiler / linker            | C/OCaml type errors, missing link symbols                                                                      | outside yelu scope                                                                     |
| **S7 Post-build**       | Canary artifact checks       | Symbol compatibility, OCaml module surface, ABI version, watchlists                                            | ✅ canary `probe_lib` + `summary`                                                       |
| **S8 Runtime**          | Program execution            | Generator expression values (`$<CONFIG:...>`), runtime path lookups                                            | outside yelu scope                                                                     |

**Overlaps with existing test layers**: `test_yelu_compile.ml` exercises S3;
`test_yelu_check.ml` exercises S0; RunCMake compat and file-api tests observe
S4/S5. S1 has no tests yet.

**Priority sequence**: S0 per-theory (current work) → S1 global (needs program
graph) → S2 scope (needs type dimension) → S3 systematic emit pass.
S4/S5 are already covered via cmake execution; the yelu value is collapsing
their failures into S0/S1.

Future direction: concretise S0–S2 as typed checker passes that produce
structured diagnostics (not just `type_error list`), compatible with the
evidence-bearing types design (§Evidence-bearing types above).

## Theory-composition architecture

Yelu's `lang_yelu.ml` is a collection of **theories over a shared substrate**
in the lambda-calculus sense. Each `Make_xxx` functor is one theory; `Make_stmt`
bundles them into an integrated system; the cmake-pack is the integration point.

### Pure core

- `LANG_TYPES` — substrate signature (var, expr, target)
- `Make_cond` — boolean theory
- `Ylet / Yif / Ystmt_list` in `yelu_stmt` — binding and control flow

### Theories

`✅` = in `fragments/`, has checker. `⏳` = AST in `lang_yelu.ml`, checker pending.
Complexity estimates are for adding an S0 local type checker.
Planned functor splits (file I/O / path ops; state var / cache-env-property) are
noted in the `lang_yelu.ml` header; the table uses current functor names.

| Theory | Functor | Checker | Complexity |
|--------|---------|---------|------------|
| Cond | `Make_cond` | ✅ `Make_cond_check` | — |
| JSON | `Make_json_op` | ✅ (via string) | — |
| String | `Make_string_op` | ✅ `Make_string_check` | — |
| List | `Make_list_op` | ⏳ | Medium — `Ty_list` input constraint, 16 constructors |
| File / path | `Make_file_op` | ⏳ | Med-high — large; planned split into I/O + path-manip |
| State | `Make_state_op` | ⏳ | High — property types dynamic; planned split into var + cache/env/property |
| Target | `Make_target_op` | ⏳ | Med-high — `Ty_target` interactions, nested kinds |
| Directory | `Make_dir_op` | ⏳ | Low — void effects, path/string inputs |
| Find | `Make_find_op` | ⏳ | Medium — output `Ty_path`; `find_package` sets many implicit vars |
| Install | `Make_install_op` | ⏳ | Low — no output vars, path/string inputs |
| Test | `Make_test_op` | ⏳ | Low — 2 constructors |
| Try | `Make_try_op` | ⏳ | Low-med — `result_var → Ty_bool`, optional outputs → `Ty_string` |
| Cmake meta | `Make_cmake_op` | ⏳ | Low-med — `math → Ty_int`, escape hatches stay untyped |

### Abstraction levels within cmake-specific theories

The cmake-specific theories are not uniform in kind — there are at least three
distinct levels, which will matter when deciding how to type and eventually
refactor them:

**Level 1 — Domain operations** (Target, Directory, Find, Install, Test, Try):
These abstract over cmake's build-model concepts — targets, properties,
packages, tests. They are the "what" of a cmake project. A future typed layer
here encodes domain constraints: a target must be declared before it is used;
a `find_library` output is either a path or `<NAME>-NOTFOUND`.

**Level 2 — Cmake meta / scripting primitives** (`Make_cmake_op`):
These are cmake's own evaluation and control machinery — `execute_process`,
`cmake_language(CALL)`, `math(EXPR)`, `message`, policy management. They
are more like a scripting runtime than a build-model. The typed layer here is
closer to S0 value-shape typing (`math → Ty_int`); deeper semantics are mostly
opaque. May be refactored when we work through it — `execute_process` is
arguably closer to Level 1 than to `message`/`include_guard`.

**Level 3 — Generator expressions** (`yelu_genex` in `lang_yelu_cmake`):
Generator expressions are cmake's embedded *functional* sublanguage — composed
at configure-time, evaluated lazily at build-time. They are structurally
different from both Level 1 and Level 2: pure, applicative, no side effects,
different evaluation phase. Currently typed as `Yexpr_genex` in `yelu_expr`.

The long-term framing: cmake has an **imperative layer** (statements, variable
mutation, cmake meta) and a **functional layer** (generator expressions,
`string(JSON ...)`, pure path manipulation). The current pack conflates both.
A future split into `imperative_cmake` and `fp_cmake` packs could share the
same theories at different evaluation models — the theories (list, string, cond)
are evaluation-model-agnostic; the core language configures which style is
primary. `yelu_genex` is the seed of the fp layer already present in the pack.
Not an immediate task, but the theory isolation we have now is the foundation.

### Typing implication

Each theory carries its own `yelu_type` fragment and its own checker. The
integrated cmake-pack checker (`Cmake_check`) composes them. The lambda-calculus
analogy: `string-theory` + `let-with-string-theory` + `type-for-string-theory` →
`let-typed-with-string-theory`. Each theory is testable in isolation; the
functor boundary is the isolation mechanism.

### typed_yelu_cmake vs yelu_cmake

A second pack instantiation (`typed_yelu_cmake`) uses `yelu_typed_expr` as
`T.expr`. All functor-generated statement types are shared — the typed pack is
a substrate choice, not a code fork.

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
