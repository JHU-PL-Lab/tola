# CMake Language Implementation Details

## File Layout (paths relative to tola root)
- `yelu/src/langs/cmake/lang_cmake.ml` — CMake AST
- `yelu/src/langs/cmake/lang_cmake_pp.ml` — Pretty printer (AST → CMake text)
- `yelu/src/langs/cmake/lang_cmake_utils.ml` — Ergonomic constructors
- `yelu/src/bin/cmake/step{1-12}*.ml` — Tutorial reference generators (cmake layer)
- `yelu/src/bin/yelu/step{1-12}*.ml` — Tutorial generators (yelu layer)
- `yelu/test/fixtures/tutorial/` — Stub C++ sources needed for cmake configure
- `yelu/test/test-file-api/` — Level 2 File API semantic equivalence tests
- `yelu/test/test-build/` — Level 3 build artifact checks
- `yelu/Makefile` — `test`, `cmake-check`, `file-api-test`, `build-check`, `test-all`

## CMake's Real AST

From `vendor/cmake/Source/cmListFileCache.h`:

- `cmListFileArgument = { Value: string, Delim: Unquoted|Quoted|Bracket, Line: long }`
- Completely untyped — all commands get `vector<cmListFileArgument>`
- No var, target, value, item, cond, or typed structure at the CMake level
- **Design principle**: cmake_ast = stringly-typed (mirrors real CMake), yelu_ast = typed (our construct)

## CMake's 6 Independent Namespaces

Empirically confirmed by 24 probes (`test/test-cmake-semantics/probes.ml` + `test/test_cmake_probes.py`).

| Namespace | Predicate              | Created by                                           |
| --------- | ---------------------- | ---------------------------------------------------- |
| TARGET    | `if(TARGET x)`         | `add_library`, `add_executable`, `add_custom_target` |
| Variable  | `if(DEFINED x)`        | `set()`, `option()`, function args, loop vars        |
| Cache     | `if(DEFINED CACHE{x})` | `set(... CACHE ...)`, `option()`, `-D` flags         |
| COMMAND   | `if(COMMAND x)`        | built-ins + `function()` / `macro()`                 |
| TEST      | `if(TEST x)`           | `add_test()`                                         |
| POLICY    | `if(POLICY CMPxxxx)`   | cmake version (static)                               |

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
- **Stub AST nodes** (bare constructors, no fields):
  `Execute_process`, `File`, `Find_package`, `String_lib`, `Try_compile`, `Try_run`
- **Tier 1 expanded** (full `find_var_args` record, utils, yelu AST nodes, compile support):
  `Find_library`, `Find_path`, `Find_file`, `Find_program`; `Message` (14 modes); `Math_lib`

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

- Unit tests: `dune test yelu/` (54 cmake PP + 27 yelu compile = 81 tests)
- Level 0 structural: `cd yelu && make cmake-check` (gersemi-normalized diff, 24 steps)
- Level 2 File API: `cd yelu && make file-api-test` (codemodel-v2 JSON diff, strips `"id"` hashes)
- Level 3 build check: `cd yelu && make build-check` (artifact existence + ELF/ar magic)
- CMake namespace probes: `yelu/test/test-cmake-semantics/probes.ml`

## Build Commands

- Build cmake only: `dune build yelu/src/langs/ yelu/src/bin/cmake/`
- Build yelu only: `dune build yelu/src/langs/ yelu/src/bin/yelu/`

## OCaml Gotchas

- `open Base` shadows: `result`, `prefix`, `id`, `append`, `compare`, etc. — rename in patterns
- `Fmt.prefix` is deprecated (use `Fmt.(++)`) — `prefix` field names trigger this
- Dune build: `(promote (until-clean))` on cmake executables — .exe files appear in source dir
- `Fmt.sp` / `Fmt.cut` are break *hints* — behavior depends on enclosing box type (vbox: always break, hovbox: break on overflow, hbox: never break). At top level (no box), hints always break.

## Design Decisions

### cmake function/macro semantics

- `macro()` = textual substitution, no scope (like C `#define`)
- `function()` = new variable scope; args are local, `PARENT_SCOPE` to export; creates a COMMAND, not a target or variable

**Yelu implication**: yelu step files are OCaml programs — OCaml functions already provide parameterization, looping, and recursion, strictly more powerful than cmake's `function()`. The only reason to *emit* cmake `function()` definitions would be if the generated CMakeLists.txt needs to be consumed/extended by downstream projects.

### Namespace-as-type surface syntax direction

cmake's namespaces are statically distinguishable at definition sites: target kind is fixed at `add_*`, cache var type at `set(... CACHE)`, normal variables are untyped strings. A typed surface syntax can enforce this:

```
let tut = exe "Tutorial" [sources: "tutorial.cxx"]
let math = lib "MathFunctions" [sources: "MathFunctions.cxx"]
tut.link [math]
```

**Design decision**: erase target kind after definition — a single `target` type suffices since kind-sensitive operations are rare in cmake. The big win is **namespace separation**: making it a type error to write `link_lib [a_file]` or `include_dirs [a_target]`. Currently `yarg` lumps targets, cvars, files, dirs, and strings together; a typed surface would prevent cross-namespace misuse at compile time.

### cmake vs shell string semantics

| | cmake | shell |
|---|---|---|
| List separator | `;` semicolon | IFS (space/tab/newline) |
| Lists ARE strings | `set(x a b c)` = `"a;b;c"` | arrays are separate type |
| Quoting | only `"..."` | `'...'` literal, `"..."` expand |
| Implicit deref | `if(FOO)` reads variable FOO | `[ FOO ]` tests string |
| String ops | `string()` command only | rich inline `${var%pat}` etc. |

**Yelu design**: keep `;`-list conflation as compiler-internal detail, never expose in surface syntax. Implicit dereference in `if()` is exactly the footgun yelu should compile away.

## Language Coverage Roadmap

See `language_coverage.md` for the full table and tier plan. Summary:
- **Tier 1** (done): `find_library/path/file/program`, `message` (14 modes), `math`
- **Tier 2**: full `list`/`string` ops, `foreach` utils + yelu AST node
- **Tier 3**: `find_package`, `FetchContent`
- **Tier 4**: generator expressions `$<…>`

## Future Directions

1. Cover all CMake features, prove equivalence via `Tests/CMakeOnly/` benchmarks
2. Build yelu-lang parser (new surface syntax) — refine OCaml DSL first, then formalize as grammar
3. Apply PL techniques (Z3 / e-graphs) for semantic equivalence — see `equiv_checking_research_prompt.md`
4. Look for real C++ projects to use as showcase targets
