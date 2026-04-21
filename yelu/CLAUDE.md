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
make cmake-check       # structural equivalence check (requires gersemi)
make coverage          # all checks: test + cmake-check + runcmake + cmake-commands + file-api
make runcmake-compat   # RunCMake positive-test compat suite (61 tests)
make runcmake-yelu     # yelu-generated scripts vs reference (script-pair)
make cmake-commands    # cmake_commands build-level tests
make file-api-test     # file-api step pairs (configure + inspect)
make step1             # generate + cmake configure + build + run step1
make step2             # etc.
```

## Key Source Files

| File                                       | Purpose                                                                            |
| ------------------------------------------ | ---------------------------------------------------------------------------------- |
| `yelu/src/langs/cmake/lang_cmake.ml`       | CMake AST (stringly-typed, mirrors real CMake)                                     |
| `yelu/src/langs/cmake/lang_cmake_pp.ml`    | CMake pretty printer (AST → CMake text)                                            |
| `yelu/src/langs/cmake/lang_cmake_utils.ml` | Ergonomic AST constructors                                                         |
| `yelu/src/langs/yelu/lang_yelu.ml`         | Yelu AST (typed surface language)                                                  |
| `yelu/src/langs/yelu/lang_yelu_compile.ml` | Yelu → CMake compiler (type erasure)                                               |
| `yelu/src/langs/yelu/lang_yelu_utils.ml`   | Yelu AST utilities                                                                 |
| `yelu/src/bin/cmake/step{1-12}*.ml`        | CMake tutorial reference generators                                                |
| `yelu/src/bin/yelu/step{1-12}*.ml`         | Yelu tutorial generators (test cases + syntax experiments)                         |
| `yelu/src/bin/yelu/common/step_common.ml`  | Shared step utilities                                                              |
| `yelu/test/test-cmake/test_cmake_pp.ml`    | CMake pretty-printer unit tests (Alcotest)                                         |
| `yelu/test/test-yelu/test_yelu_compile.ml` | Yelu compiler unit tests (Alcotest)                                                |
| `yelu/test/test-cmake-semantics/probes.ml` | CMake namespace probe programs                                                     |
| `yelu/doc/cmake_comparison.md`             | CMake language properties, PL vocabulary, equivalence levels, test harness mapping |
| `yelu/doc/yelu_infra_test.md`              | Test infrastructure: harness code, dune aliases, gotchas, blockers                 |
| `yelu/doc/cmake_equiv_research.md`         | Research prompt: e-graphs / Z3 for cmake equivalence                               |
| `yelu/doc/yelu_lang_coverage.md`           | Coverage table, CMakeOnly tractability, 4-tier roadmap                             |
| `yelu/doc/yelu_lang_design.md`             | Language design decisions: staging, types, surface syntax                          |
| `yelu/doc/cmake_policy.md`                 | cmake policy system, CMP* history, scope mechanics                                 |
| `yelu/doc/cmake_genex.md`                  | Generator expressions: build-time vs configure-time, encoding                      |
| `yelu/doc/cmake_script.md`                 | cmake -P script mode vs configure mode differences                                 |
| `yelu/vendor/cmake`                        | Symlink → `/home/red/code/contrib/cmake-all/cmake` (cmake 4.3 dev, 133 commands)   |

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
patchwork character — each decade added a layer (scripting → modules → generator
expressions → presets → policy stack) without cleaning up what came before. The result:
irregular syntax (commands and keywords are both bare strings, indistinguishable to the
parser), implicit namespace collisions (variables, targets, cache, and properties shadow
each other silently), late errors (a typo in a variable name silently produces `""`, the
fault surfaces three calls later), and accumulated workarounds (`CMP*` policies coexist
both old and new behavior forever). cmake is mature and widely adopted — important
enough that results transfer — yet maximally hostile to automated reasoning.

**LLM design goals (first-class)**: cmake's patchwork properties are exactly what make
LLM synthesis unreliable: the model generates plausible-looking cmake that silently
misbehaves at configure time. yelu's typed, regular API provides locally checkable
primitives — an LLM mistake produces an early, local error rather than a distant cmake
runtime failure. The research question is not "yelu vs cmake" but: *do language
properties (regularity, explicitness, early errors) measurably improve LLM first-pass
correctness and repair convergence?* cmake is the controlled variable — yelu holds
semantics fixed while changing the surface language. Measurement plan: cross-compare
LLM performance (code generation, bug detection, repair convergence) on equivalent
cmake vs yelu tasks; equivalence checking is the semantic oracle.

**Ergonomics in the LLM era**: traditional language ergonomics optimizes for human
readability and writability. LLM ergonomics is a different axis: does the language's
structure (regularity, error locality, typed namespaces, unambiguous parse) make it
easier for a model to generate *correct* programs on the first try and *locate* errors
during repair? A language can be humanly ergonomic but LLM-hostile (cmake: irregular,
late errors, implicit namespaces) or humanly verbose but LLM-friendly (yelu: typed,
early errors, explicit namespaces). This distinction is not obvious a priori —
yelu is designed to explore it empirically. The AI era also opens a second question:
can AI-assisted synthesis be used to generate test coverage that manual testing cannot
reach (e.g. compiler combinations, platform variants, option-space enumeration)?

**Generalization beyond cmake**: cmake is the specimen, not the thesis. The patchwork
pattern recurs across modern config targets: Dockerfile, Terraform HCL, k8s YAML, Nix.
The yelu-core / pack architecture (unified metalanguage + target-specific object language)
is designed to generalize: a json-pack or nix-pack would reuse yelu-core while targeting
different semantics. This architecture also connects to the broader question in
`doc/yelu_beyond.md`: AI-designed language stacks converge on "shared metalanguage,
distinct object languages" — yelu is an early concrete instance of that pattern. The
long-term direction is multi-pack yelu, with cmake-pack as the first validated specimen.

## Architecture

The cmake layer (`yelu_langs` library) provides a stringly-typed AST that
mirrors CMake's real structure — all commands take `arg list`, no semantic
types. The yelu layer sits on top: `lang_yelu.ml` defines typed constructs
(`Ycvar`, `Ytarget`, `Ylet`, typed conditions), and `lang_yelu_compile.ml`
erases types down to the cmake AST. The step files (`src/bin/yelu/step*.ml`)
are both test cases and syntax design experiments — they define yelu programs
as OCaml DSL expressions and print the generated CMakeLists.txt. The cmake
step files (`src/bin/cmake/`) are reference generators for comparison.

Active equivalence checking: `src` (gersemi structural diff via `make cmake-check`),
`interp/script` (script-pair: yelu vs cmake stdout match), `interp/file-api`
(codemodel-v2 JSON diff for steps 1–12), and `interp/script` via RunCMake compat
(61 positive-test scripts from cmake's own test suite). See `doc/cmake_comparison.md`
for the full semantic framework.

## Current TODO

Numbers are stable (never renumbered).

### Equivalence checking

**Y2. Enumerate option combinations** — for steps with `option()` flags (step4+),
run cmake for all 2^n boolean combinations and assert File API outputs match.
This gives full equivalence for finite boolean inputs without symbolic methods.

**Y3. Z3 symbolic equivalence (research)** — symbolic interpreter for cmake; prove
equivalence for all boolean-option inputs. See `doc/cmake_equiv_research.md`.

**Y4. E-graph investigation (research)** — equality saturation over state-transformer
encodings; prove independent `set()` reorderings equivalent. See `doc/cmake_equiv_research.md`.

### Language coverage


**Y5. File API comparison as semantic oracle** — currently `cmake_file_api_cmp.py`
compares codemodel-v2 JSON. Extend to also diff cache-v2 (cache variables) and
confirm target property coverage is sufficient for step1–12.

**Y6. cmake semantics hardest to preserve** — identify which cmake semantics are
most likely to diverge under yelu transformation: generator expressions `$<...>`
(build-time, not configure-time), `cmake_policy` stack, `find_package` search order.
Document which are in scope for equivalence checking vs. opaque stubs.

### Language design

**Y8. Multi-stage core — same language across levels (research)** — unify compile-time
and configure-time constructs via explicit staging annotations. See `doc/yelu_lang_design.md`
Tier 7 for the full design (quote/splice, `@stage cmake/@stage build`, connection to
Tier 5 cache types and Tier 6 conf/build collapse). Not urgent.

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

**Y11. Policy-aware compiler/printer (design)** — constructs that require specific cmake
policies (e.g. `return(PROPAGATE ...)` needs CMP0140 NEW) should declare their policy
requirements; the compiler emits the preamble automatically. Design questions: (a) where
do requirements live — per-construct metadata or registry; (b) output form —
`cmake_minimum_required(VERSION x)` or individual `cmake_policy(SET CMPxxxx NEW)`;
(c) subdirectory inclusion (parent's policy stack is external, preamble doesn't compose).
See `doc/yelu_lang_design.md` policy section for full background. Design pass needed
before touching code.

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

Y1, Y9, Y10 — see `doc/worklog_2026_04.md`.

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
- **cmake vs shell string semantics**: cmake lists are semicolon-joined strings
  (`set(x a b c)` = `"a;b;c"`); shell uses space-separated arrays. cmake quoting
  only has `"..."` (expands variables); shell also has `'...'` (literal). cmake
  `if(FOO)` implicitly dereferences the variable FOO — a footgun yelu should
  compile away. Keep `;`-list conflation as a compiler-internal detail; never
  expose it in yelu surface syntax.
- **`function()` vs `macro()` semantics**: `macro()` is textual substitution with
  no scope (like C `#define`). `function()` creates a new variable scope; args are
  local; `PARENT_SCOPE` exports back; creates a COMMAND entry, not a target or
  variable. Yelu step files are OCaml programs — OCaml already provides
  parameterization and recursion, so emitting cmake `function()` is only needed
  when generated cmake must be consumed or extended by downstream projects.
- **Tutorial v1 vs v2**: `vendor/cmake-tutorial/step{1-12}/` is v1 (CMake 3.20) —
  what the OCaml step files target. `vendor/cmake/Help/guide/tutorial/` is v2
  (CMake 3.23+, Kitware rewrite) with a completely different curriculum
  (`target_sources FILE_SET`, presets, OBJECT libs, multi-project, cxx_std_20).
  Step numbering does NOT map 1:1. Do not confuse them when reading the upstream
  tutorial source.
- **cmake ANSI codes in script output**: dune injects `CLICOLOR_FORCE=1` for
  test alias runs; cmake inherits it and emits `\x1b[0m` around `message()` output.
  `cmake_runner.ml`'s `cmake_env` overrides with `CLICOLOR_FORCE=0` for all cmake
  subprocesses. The `message/newline` RunCMake compat test remains blocked — the
  override is insufficient on some configurations; see `doc/yelu_infra_test.md` blockers.
- **cmake runtime matches vendor source**: Both are cmake 4.3.1 (`/usr/bin/cmake`,
  Kitware apt). Previously 3.28.3; upgrading unblocked `cmake_path GET`,
  `message/newline`, `string/RegexEmptyMatch`, and `get_filename_component KnownComponents`.

## Handoff Workflow

Same pattern as `../CLAUDE.md`. Before ending a session, update this file:

```
Update yelu/CLAUDE.md for handoff. Include: Build & Run, Key Files,
Architecture, Gotchas, Conventions. Check memory files for new gotchas.
Commit the result.
```
