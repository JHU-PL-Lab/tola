# Claude Code — Yelu Project Guide

> **Scope**: This file is only relevant when working on yelu or the cmake
> language layer. If you are working on canary or other tola modules, read
> `../CLAUDE.md` instead and ignore this file.

## Build & Run

Run from the **tola repo root** (where `dune-project` lives):

```sh
dune build yelu/src/langs/ yelu/src/bin/cmake/   # cmake layer only
dune build yelu/src/langs/ yelu/src/bin/yelu/    # yelu layer only
dune build yelu/                                  # everything in yelu/
dune test yelu/                                   # run yelu + cmake tests
```

Run make targets from `yelu/`:

```sh
cd yelu
make cmake-check   # structural equivalence check (requires gersemi)
make step1         # generate + cmake configure + build + run step1
make step2         # etc.
```

## Key Source Files

| File                                         | Purpose                                                                          |
| -------------------------------------------- | -------------------------------------------------------------------------------- |
| `yelu/src/langs/cmake/lang_cmake.ml`         | CMake AST (stringly-typed, mirrors real CMake)                                   |
| `yelu/src/langs/cmake/lang_cmake_pp.ml`      | CMake pretty printer (AST → CMake text)                                          |
| `yelu/src/langs/cmake/lang_cmake_utils.ml`   | Ergonomic AST constructors                                                       |
| `yelu/src/langs/yelu/lang_yelu.ml`           | Yelu AST (typed surface language)                                                |
| `yelu/src/langs/yelu/lang_yelu_compile.ml`   | Yelu → CMake compiler (type erasure)                                             |
| `yelu/src/langs/yelu/lang_yelu_utils.ml`     | Yelu AST utilities                                                               |
| `yelu/src/bin/cmake/step{1-12}*.ml`          | CMake tutorial reference generators                                              |
| `yelu/src/bin/yelu/step{1-12}*.ml`           | Yelu tutorial generators (test cases + syntax experiments)                       |
| `yelu/src/bin/yelu/common/step_common.ml`    | Shared step utilities                                                            |
| `yelu/test/test-cmake/test_cmake_pp.ml`      | CMake pretty-printer unit tests (Alcotest)                                       |
| `yelu/test/test-yelu/test_yelu_compile.ml`   | Yelu compiler unit tests (Alcotest)                                              |
| `yelu/test/test-cmake-semantics/probes.ml`   | CMake namespace probe programs                                                   |
| `yelu/doc/cmake_implementation.md`           | AST design, namespaces, design decisions, tutorial versions                      |
| `yelu/doc/cmake_comparison.md`               | CMake output comparison strategies, equivalence levels                           |
| `yelu/doc/equiv_checking_research_prompt.md` | Research prompt: e-graphs / Z3 for cmake equivalence                             |
| `yelu/doc/language_coverage.md`              | Coverage table, CMakeOnly tractability, 4-tier roadmap                           |
| `yelu/vendor/cmake`                          | Symlink → `/home/red/code/contrib/cmake-all/cmake` (cmake 4.3 dev, 133 commands) |

## Design Vision

**What yelu is not**: a better template language, cmake syntax sugar, or a build system.

**What yelu is**: a programmable configuration shell language — a staged DSL that
provides universal programmability and static checking for target config languages
(currently cmake; json/yaml are future packs).

**Two-layer architecture**:
1. *Core layer* (language-agnostic) — bindings, composition, sequencing, optional types
2. *Language pack layer* (per-target) — cmake pack provides safe abstractions,
   namespace-typed constructs, and lowers to cmake AST

yelu programs target one pack at a time; they host languages, not mix them.

**Semantics** (Python-like surface, very different semantics):
- `=` is binding, not mutation (single assignment)
- No runtime IO; primitives construct AST, not execute commands
- Types/constraints are compile-time contracts; all errors fail before emit

**Why cmake**: cmake is a good specimen for this research precisely because of its
缝缝补补 ("stitched together") character — each decade added a layer (scripting →
modules → generator expressions → presets → policy stack) without cleaning up what
came before. The result: irregular syntax (commands and keywords are both bare strings,
indistinguishable to the parser), implicit namespace collisions (variables, targets,
cache, and properties shadow each other silently), late errors (a typo in a variable
name silently produces `""`, the fault surfaces three calls later), and accumulated
workarounds (`CMP*` policies coexist both old and new behavior forever). cmake is
mature and widely adopted — important enough that results transfer — yet maximally
hostile to automated reasoning.

**LLM design goals (first-class)**: cmake's 缝缝补补 properties are exactly what make
LLM synthesis unreliable: the model generates plausible-looking cmake that silently
misbehaves at configure time. yelu's typed, regular API provides locally checkable
primitives — an LLM mistake produces an early, local error rather than a distant cmake
runtime failure. The research question is not "yelu vs cmake" but: *do language
properties (regularity, explicitness, early errors) measurably improve LLM first-pass
correctness and repair convergence?* Metrics: first-pass correctness, repair steps,
error locality, semantic edit distance. cmake is the controlled variable — yelu holds
semantics fixed while changing the surface language.

## Architecture

The cmake layer (`yelu_langs` library) provides a stringly-typed AST that
mirrors CMake's real structure — all commands take `arg list`, no semantic
types. The yelu layer sits on top: `lang_yelu.ml` defines typed constructs
(`Ycvar`, `Ytarget`, `Ylet`, typed conditions), and `lang_yelu_compile.ml`
erases types down to the cmake AST. The step files (`src/bin/yelu/step*.ml`)
are both test cases and syntax design experiments — they define yelu programs
as OCaml DSL expressions and print the generated CMakeLists.txt. The cmake
step files (`src/bin/cmake/`) are reference generators for comparison. Three
equivalence levels are active: Level 0 (gersemi string diff), Level 2 (cmake
File API codemodel-v2 JSON diff), Level 3 (build artifact existence + ELF magic).

## Current TODO

Numbers are stable (never renumbered).

### Equivalence checking

**Y1. Wire File API into tests** — `cmake_file_api_cmp.py` exists but isn't run by
`dune test`. Add a test target that runs a cmake configure + file API diff for each
step, comparing yelu-generated vs reference cmake. `Tests/CMakeOnly/` in the cmake
source is a good benchmark source (no compiler needed).

**Y2. Enumerate option combinations** — for steps with `option()` flags (step4+),
run cmake for all 2^n boolean combinations and assert File API outputs match.
This gives full equivalence for finite boolean inputs without symbolic methods.

**Y3. Z3 symbolic equivalence (research)** — encode cmake configure-time semantics
as a symbolic interpreter: options → Z3 booleans, `if()` → `ite`, variable state →
symbolic map. Assert two programs differ, check SAT. UNSAT = equivalent for all inputs.
Start with a single `if(USE_MYMATH)` block over `Tests/CMakeOnly/` benchmarks.
See `doc/equiv_checking_research_prompt.md` for the full research framing.

**Y4. E-graph investigation (research)** — assess whether equality saturation over
state-transformer encodings could prove cmake statement reorderings equivalent
(e.g., independent `set()` commands). Likely needs a monad-style encoding.
See `doc/equiv_checking_research_prompt.md`.

### Language coverage

**Y10. ✓ DONE** — `string(JSON …)` and `string(UUID …)` fully implemented:
`Sc_uuid`/`Sc_json`/`json_op` in `lang_cmake.ml`; PP; `yelu_json_op` + yelu layer;
8 UUID tests + 8 JSON tests all pass. `GET_RAW`/`STRING_ENCODE` are cmake 4.3+ (we're
on 3.28); `Jop_get_raw`/`Jop_string_encode` exist in AST but not tested.
Key fix: `Ycs_cmake` compiles to `Bare` (not `Quoted`) so bracket strings pass through.

**Y9. Audit RunCMake positive-test coverage gaps** — the official cmake
`Tests/RunCMake/list/` and `Tests/RunCMake/string/` directories do not have
positive (non-error-case) test scripts for every subcommand. For `list`: no
positive tests for REMOVE_ITEM, REMOVE_AT, REVERSE, FIND, standalone LENGTH/GET.
For `string`: no positive tests for FIND, SUBSTRING, STRIP, REPLACE, LENGTH.
The error-case scripts (`*-result.txt` / `*-stderr.txt`) confirm cmake rejects
bad inputs but don't validate correct output. Determine: (a) is this a gap in
cmake's test suite, or are these covered elsewhere (e.g., `Tests/CMakeCommands/`,
`Tests/StringFileTest/`); (b) whether it matters for yelu — if cmake itself
doesn't test a subcommand's positive behavior, our confidence in the PP output
being correct is lower and a standalone cmake-run test would be more valuable.

**Y5. File API comparison as semantic oracle** — currently `cmake_file_api_cmp.py`
compares codemodel-v2 JSON. Extend to also diff cache-v2 (cache variables) and
confirm target property coverage is sufficient for step1–12.

**Y6. cmake semantics hardest to preserve** — identify which cmake semantics are
most likely to diverge under yelu transformation: generator expressions `$<...>`
(build-time, not configure-time), `cmake_policy` stack, `find_package` search order.
Document which are in scope for equivalence checking vs. opaque stubs.

### Language design

**Y8. Multi-stage core — same language across levels (research)** — currently yelu has
two separate construct families: compile-time (`Ylet`, OCaml `if`/`for`) and
configure-time (`Ycvar`, `Yc_foreach`, `Yc_if`). The research direction: unify these
into one construct per concept with explicit staging annotations (`@stage cmake`,
`@stage build`). Quote/splice across stages replaces preprocessor + macro tooling with
typed, composable meta-programming. See `doc/language_coverage.md` Tier 7 for full
design. Connects to Tier 5 (cache variable types as stage-annotated `let`) and Tier 6
(conf/build boundary collapse). Not urgent — pick up when exploring core language design.

**Y7. Cache-sensitivity annotations on cmake variables (design)** — cmake cache entries
differ in how much they invalidate: `CMAKE_C_COMPILER` forces full reconfigure + rebuild
(nothing can be shared between tasks that differ here), while `CMAKE_BUILD_PARALLEL_LEVEL`
has zero impact on configure output. Idea: add a `cache_sensitivity` refinement to
`Ycvar` in the yelu AST:

```ocaml
type cache_sensitivity =
  | Cache_breaking   (* compiler, toolchain — full reconfigure + rebuild *)
  | Cache_safe       (* parallelism, verbosity — no artifact impact *)
  | Cache_partial    (* build type Debug/Release — breaks some targets *)
```

A yelu program that sets `CMAKE_C_COMPILER` would statically declare the point
cache-breaking, letting a runner (canary or yelu CLI) decide whether two tasks
can share a build directory. Connects to canary TODO #10 (unified build cache scheme).
Not urgent — pick up when exploring yelu-specific language features.

**Y11. Policy-aware compiler/printer (design)** — yelu constructs that require specific
cmake policies (e.g., `return(PROPAGATE ...)` requires CMP0140 NEW) should be declared
as such, and the compiler/printer should emit the correct preamble automatically.
Design questions: (a) where do policy requirements live — per-construct metadata in
`lang_yelu.ml` or a separate registry; (b) output form — `cmake_minimum_required(VERSION x)`
(covers all policies up to x) or individual `cmake_policy(SET CMPxxxx NEW)` calls;
(c) conflict resolution when two constructs require incompatible policies.
Framing: the compiler's correctness contract is "generated cmake behaves as specified
on any supported cmake version" — policy preamble is compiler output, not user boilerplate.

Background context: cmake policies are unlike interpreter versioning in other ecosystems.
In Python/Node/Ruby, a version is a property of the *process* — the whole program runs
under one interpreter, and env tools (pyenv/nvm/rbenv) isolate projects by swapping the
binary. In cmake, `cmake_minimum_required` activates a policy set *within* the running
process, and `cmake_policy(PUSH/POP)` scopes policies to call stacks — so two
subdirectories in the same configure session can operate under different behavioral
versions simultaneously. The "version" is a property of the *scope*, not the process.
This means a yelu construct lowered into a subdirectory may encounter a different policy
context than expected, depending on what the parent project has already set. The
compiler's policy preamble emission only solves the top-level case; for subdirectory
inclusion the problem is harder — the parent's policy stack is external state yelu
cannot control or inspect.

Not urgent — design pass needed before touching code.

**Y12. Cmake-layer tests mirroring yelu tests** — `test_cmake_pp.ml` tests the cmake
PP in isolation. As yelu coverage grows, cmake-layer tests should be kept in sync: for
every command with a yelu test there should be a corresponding cmake PP test exercising
the same cases directly (no yelu compile step). Two reasons: (a) isolates PP bugs from
yelu compiler bugs — a failure in the cmake test points to the PP, a failure only in
the yelu test points to the compiler; (b) the cmake layer is independently usable as a
typed AST builder, so its test coverage should not depend on going through yelu.
Sync rule: when a yelu test is added for a command, check whether a cmake PP test
already exists; if not, add one. Priority: commands recently promoted from AST-only
(`add_custom_target`, `define_property`, `target_precompile_headers`, etc.).

### Done

(none yet — yelu TODO tracking starts 2026-04-13)

---

## Gotchas

- **`open Base` shadows stdlib**: `result`, `prefix`, `id`, `append` are
  shadowed — rename in pattern matches.
- **OCaml LSP stale diagnostics**: Cross-module edits show false errors until
  dune rebuilds. Verify with `dune build` at the end.
- **`Fmt.sp` / `Fmt.cut` box sensitivity**: These are break *hints* whose
  behavior depends on the enclosing box type (vbox: always break, hovbox:
  break on overflow, hbox: never break). At top level (no box), hints always
  break. Poorly documented — test output carefully when changing printers.
- **`@.` resets the formatter**: In `lang_cmake_pp.ml`, any `@.` calls
  `pp_print_newline` which closes all open boxes. Use `pp_force_newline` in
  `list_br` instead of `Fmt.cut` to get reliable newlines after `@.`.
- **`Langs.` → `Yelu_langs.`**: All modules in this directory use the
  `Yelu_langs` library name. The old `Langs.` prefix (from when these files
  lived in `src/langs/`) no longer works.
- **Make must run from `yelu/`**: The Makefile uses `vendor/cmake-tutorial`
  and `_out/cmake` as CWD-relative paths. The `dune exec` calls use
  `yelu/src/bin/cmake/` paths relative to the tola root via `cd ..`.
- **`yelu/vendor/cmake` is a symlink**: Points to `/home/red/code/contrib/cmake-all/cmake`
  (cmake 4.3 dev). Not a submodule — do not re-add it as one.
- **cmake runtime vs vendor source version mismatch**: Installed cmake is 3.28.3
  (`/usr/bin/cmake`, Ubuntu 24.04 apt max). Vendor source is cmake 4.3. All conf-run
  and script-mode tests run against 3.28. Everything currently implemented (cmake_path,
  block, cmake_language) is ≤3.25, so 3.28 covers all active tests. Upgrade needed
  when cmake_policy CMP0186 (4.1) work starts. Upgrade path: Kitware apt repo —
  `curl -fsSL https://apt.kitware.com/kitware-archive.sh | sudo bash && sudo apt install cmake`.

## Conventions

- `cc` = Claude Code (user shorthand)
- Allowed bash: `make *` and `dune *` only
- step*.ml files = test cases AND syntax design experiments — don't over-abstract

## Handoff Workflow

Same pattern as `../CLAUDE.md`. Before ending a session, update this file:

```
Update yelu/CLAUDE.md for handoff. Include: Build & Run, Key Files,
Architecture, Gotchas, Conventions. Check memory files for new gotchas.
Commit the result.
```
