# CMake Language Implementation Details

## File Layout
- `src/langs/cmake/lang_cmake.ml` — Full AST for CMake 3.31.0
- `src/langs/cmake/lang_cmake_pp.ml` — Pretty printer (AST → CMake text)
- `src/langs/cmake/lang_cmake_utils.ml` — Ergonomic constructors for building AST
- `src/bin/cmake/step{1-12}*.ml` — Tutorial examples, OCaml programs that build AST and print CMakeLists.txt
- `vendor/cmake-tutorial/step{1-12}/` — Generated CMake projects with C++ source for validation
- `Makefile.cmake.mk` — Orchestrates: generate → cmake configure → build → test

## CMake's Real AST

From `vendor/cmake/Source/cmListFileCache.h`:

- `cmListFileArgument = { Value: string, Delim: Unquoted|Quoted|Bracket, Line: long }`
- Completely untyped — all commands get `vector<cmListFileArgument>`
- No var, target, value, item, cond, or typed structure at the CMake level
- **Design principle**: cmake_ast = stringly-typed (mirrors real CMake), yelu_ast = typed (our construct)

## CMake's 6 Independent Namespaces

Empirically confirmed by 24 probes (`test/test-cmake-semantics/probes.ml` + `test/test_cmake_probes.py`).

| Namespace | Predicate | Created by |
|---|---|---|
| TARGET | `if(TARGET x)` | `add_library`, `add_executable`, `add_custom_target` |
| Variable | `if(DEFINED x)` | `set()`, `option()`, function args, loop vars |
| Cache | `if(DEFINED CACHE{x})` | `set(... CACHE ...)`, `option()`, `-D` flags |
| COMMAND | `if(COMMAND x)` | built-ins + `function()` / `macro()` |
| TEST | `if(TEST x)` | `add_test()` |
| POLICY | `if(POLICY CMPxxxx)` | cmake version (static) |

Key findings:
- All namespaces are independent — "foo" can simultaneously be a target, variable, and cache entry
- INTERFACE libraries ARE targets (`if(TARGET)` → true) but invisible in File API codemodel-v2
- `set()` without CACHE → DEFINED only; `set(CACHE)` → both DEFINED and CACHE{}
- `function()` creates a COMMAND, not a target or variable
- Test names are NOT targets — independent namespace

## Current AST State

- **CMake AST** (`lang_cmake.ml`): Aligned with CMake's real stringly-typed structure
  - `type arg = Bare of string | Quoted of string` — unified replacement for old `value`/`item` types
  - `type var = string`, `type target = string`, `type feature = string` — flattened wrappers
  - `type cond = string list` — flat keyword list, not structured tree
  - All fields use `string` or `arg` instead of typed enums
- **Yelu AST** (`lang_yelu.ml`): Owns all typed constructs
  - `type cmake_name = string` — semantic alias for cmake namespace keys
  - `Ycvar of cmake_name` — pins to Variable namespace
  - `Ytarget of cmake_name` — pins to Target namespace
  - `Yvar of string` — compile-time variable, can hold any yarg
  - `yc_string`: `Ycs_file | Ycs_dir | Ycs_name | Ycs_val | Ycs_raw` — content classification for `Yarg_string`
  - Typed enums: `library_type`, `target_kind`, `supported_lang`, `compatibility`
  - Typed conditions: `yelu_cond` (recursive, structured) with `Yis_target`, `Yis_defined`
  - Compile (type erasure): `lang_yelu_compile.ml` converts yelu → cmake_ast
- **Stub AST nodes** (bare constructors, no fields — need AST expansion before printer):
  `Execute_process`, `File`, `Find_file`, `Find_library`, `Find_package`, `Find_path`, `Find_program`, `String_lib`, `Try_compile`, `Try_run`

## Tutorial Versions

### v1 (CMake 3.20) — `vendor/cmake-tutorial/step{1-12}/`
- Our current OCaml translation tests target this version
- Topics: configure_file, USE_MYMATH, SqrtLibrary, CDash, CPack, BUILD_SHARED_LIBS, CMAKE_DEBUG_POSTFIX
- 12 steps, flat directory structure per step

### v2 (CMake 3.23+) — `vendor/cmake/Help/guide/tutorial/Step{0-11}/ + Complete/`
- Official Kitware rewrite, completely different curriculum
- New concepts: `target_sources()` + `FILE_SET HEADERS`, `CMakePresets.json`, OBJECT libs, multi-project structure, namespaced exports, `cxx_std_20`, custom test discovery framework
- Step numbering does NOT map 1:1 to v1
- Thematic overlap: system introspection (Step6↔step7), custom commands (Step7↔step8), testing (Step8↔step5), install/export (Step9↔step11)
- Steps with no v1 equivalent: Step0 (hello), Step2 (cmake language exercises), Step3 (presets), Step4-5 (vendor/OBJECT libs), Step10-11 (multi-project find_package)

## Testing

- CMake unit tests: `test/test-cmake/test_cmake_pp.ml` (Alcotest), run with `dune exec test/test-cmake/test_cmake_pp.exe`
- Yelu unit tests: `test/test-yelu/test_yelu_compile.ml` (Alcotest), run with `dune exec test/test-yelu/test_yelu_compile.exe`
- Structural equivalence: `make -f Makefile.cmake.mk cmake-check` (gersemi-normalized diff)
- CMake namespace probes: `test/test-cmake-semantics/probes.ml` + `test/test_cmake_probes.py`

## Build Commands

- Build cmake only: `dune build src/langs/ src/bin/cmake/`
- Build yelu only: `dune build src/langs/ src/bin/yelu/`

## OCaml Gotchas

- `open Base` shadows: `result`, `prefix`, `id`, `append`, `compare`, etc. — rename in patterns
- `Fmt.prefix` is deprecated (use `Fmt.(++)`) — `prefix` field names trigger this
- Dune build: `(promote (until-clean))` on cmake executables — .exe files appear in source dir
- `Fmt.sp` / `Fmt.cut` are break *hints* — behavior depends on enclosing box type (vbox: always break, hovbox: break on overflow, hbox: never break). At top level (no box), hints always break.

## Future Directions

1. Cover all CMake features, prove equivalence via CMake's test suite
2. Build yelu-lang parser (new surface syntax) — refine OCaml DSL first until it looks like the desired surface syntax, then formalize as grammar. step*.ml files = test cases + syntax design experiments
3. May need CMake parser — check for existing OCaml implementations first
4. Apply PL techniques to reject incorrect/dangerous expressions
5. Look for modern books/projects to optimize their CMake as showcase targets
