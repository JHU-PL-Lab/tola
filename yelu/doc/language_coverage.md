# Yelu Language Coverage Plan

## Current State

193 unit tests + 23 configure tests + 62 RunCMake compat + 50 RunCMake yelu pairs + 12/12 CMakeOnly showcases + 22 build-level passing: 11 CMakeCommands (`target_link_*`, `add_compile_*`, `link_directories`, `target_sources`, `target_include_directories`) + 11 Group 2/3 (Simple, LinkLine, LinkLineOrder, OutName, LibName, LinkStatic, CompileDefinitions, TargetName, PositionIndependentTargets, AliasTarget, CxxOnly). SubDir/SubDirSpaces blocked (hardcoded CTest path assertion). Next: ObjectLibrary (Group 2, 6 subdirs)..

## Remaining in CMakeCommands

`target_link_libraries` deferred: 182 lines, 5 subdirs, uses `GenerateExportHeader` + `cmake_policy(PUSH/POP)` — same blocker as Group 4 above.

## Remaining RunCMake gaps

| Gap                             | Detail                                                                                                             | Status  |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ------- |
| `include` CMP0146/CMP0148 pairs | These test deprecated FindCUDA/FindPython module behavior under policy — require real cmake modules + policy state | Blocked |
| `include` ParentVariable*       | Tests `CMAKE_PARENT_LIST_FILE` tracking through include chains — needs multi-file test fixture infra               | Blocked |
| `foreach-all-test` pair         | Upstream uses ITEMS-before-LISTS ordering; PP always emits LISTS-first; needs PP extension or remain compat-only   | Blocked |

Realistic ceiling: ~65 tractable scripts from ~15 dirs.

---

## Known Gaps and Dropped Test Cases

### Structurally blocked

These require features or infrastructure not yet in yelu. No workaround exists.

| Blocked item            | What it unlocks                                                                                                                         | Tracking                                                                                       |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `cmake_policy` (Y11)    | REGEX zero-length matches (CMP0186), `return(PROPAGATE)` (CMP0140), `foreach` variable scoping (CMP0124), `try_compile` policy variants | Y11 — design pass needed; see `language_design.md` policy section                              |
| Build-time test harness | Generator expression value verification, `try_run` run-result, PCH actual compilation; `Tests/TryCompile/` + `Tests/StringFileTest/`    | `run_configure_and_build` + `check_build_pair` done; expanding `Tests/CMakeCommands/` coverage |

This section tracks every case that was explicitly dropped or narrowed in the
conf-run test suite (`yelu/test/test-runcmake/`), with the reason.  The goal
is to make coverage claims honest: "✓" in the table above means the command
pipeline exists and the happy path passes, **not** that every cmake edge case
is exercised.

Three categories:

- **Undefined / implementation-defined** — cmake does not specify the behavior;
  we do not test it (but may add a flag or separate yelu semantics later).
- **Yelu feature gap** — the feature exists in cmake but is absent from yelu
  (usually a deferred design decision).
- **Partial coverage** — we tested the main cases but not all boundary conditions.

### Undefined / implementation-defined

| Test file         | Case dropped                                             | Reason                                                                                                                                                      |
| ----------------- | -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `test_string2.ml` | `STRING(REPLACE "" …)` — empty literal match-string      | No positive RunCMake test exists for this case; cmake docs do not specify it                                                                                |
| `test_while.ml`   | RunCMake/while positive tests (all CMP0130 policy tests) | Those tests validate policy stack behavior, not loop semantics; not a useful yelu target                                                                    |
| `test_list3.ml`   | `SORT COMPARE NUMBER/NUMERIC`                            | **False feature** — fixed: `Ls_numeric` removed from `lang_cmake.ml` and PP. cmake `list(SORT)` only supports `COMPARE STRING`, `FILE_BASENAME`, `NATURAL`. |

### Defined behavior — not yet tested

These were initially labeled "undefined" but cmake does test them; behavior is specified.

| Test file         | Case not tested                                                         | Actual cmake behavior                                                                                                                                                                     | What's needed to test                                                                                      |
| ----------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `test_math.ml`    | Integer overflow / underflow                                            | ✓ covered in `overflow` test case. Values wrap with 64-bit signed semantics. Note: cmake emits `CMake Warning (dev)` in configure mode but NOT in `-P` script mode — warning not checked. | —                                                                                                          |
| `test_string2.ml` | `REGEX REPLACE` with zero-length match (empty pattern, `^`, `a*`, etc.) | Fully specified under `CMP0186 NEW`; tested in `RunCMake/string/RegexEmptyMatch.cmake`                                                                                                    | Needs `yc_minimum_required` preamble + policy set for CMP0186; blocked until cmake_policy is in yelu (Y11) |

### Yelu feature gap

| Test file                    | Case dropped                                                                      | Missing yelu feature                                                                                  | Notes                                  |
| ---------------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | -------------------------------------- |
| `test_foreach2.ml`           | `ZIP_LISTS` CMP0124 loop-variable scoping (NEW vs OLD behaviour after loop exits) | `cmake_policy(SET CMP0124 NEW)` not in yelu                                                           | Y11                                    |
| `test_foreach.ml`            | CMP0124 loop variable scoping (NEW vs OLD)                                        | `cmake_policy` not in yelu                                                                            | Y11; loop var scoping after loop exits |
| `test_return.ml`             | `return(PROPAGATE …)`                                                             | `cmake_policy(SET CMP0140 NEW)` not in yelu                                                           | Y11 design TODO                        |
| `test_return.ml`             | `return()` inside `block()` / `add_subdirectory()` scope                          | `block()` done; subdirectory scope not in yelu                                                        | subdirectory scope                     |
| `test_separate_arguments.ml` | `WINDOWS_COMMAND`, `PROGRAM`/`PROGRAM_ARGS` modes                                 | Platform-specific; not representable portably                                                         | Would need a Windows CI target         |
| `test_message2.ml`           | `CMAKE_MESSAGE_CONTEXT` nested push/pop via functions                             | Low value for scripting-only tests                                                                    | Skip                                   |
| `test_function.ml`           | `CMAKE_CURRENT_FUNCTION_LINE`                                                     | Not populated in cmake `-P` script mode (cmake 3.28, verified; configure mode only)                   | Revisit if configure-mode tests added  |
| `test_string_uuid.ml`        | `string(UUID …)` GET_RAW, STRING_ENCODE sub-commands                              | cmake 4.3+ features; we're on 3.28                                                                    | —                                      |
| —                            | `string` UTF-16/32 encoding                                                       | Absent from cmake AST; niche                                                                          | Low — skip for now                     |
| —                            | `include_guard` DIRECTORY/GLOBAL conf-run                                         | Requires `include()` + multiple files                                                                 | Out of scope for `-P` script tests     |
| `test_configure.ml`          | `try_compile` old project form (`<bindir> <srcdir>`)                              | Legacy interface; not in yelu API by design                                                           | 20 RunCMake old-form tests skipped     |
| `test_configure.ml`          | `try_compile` CMP0056/0066/0067/0128/0137/0210 policy variants                    | `cmake_policy` not in yelu                                                                            | Y11                                    |
| `test_configure.ml`          | `try_compile` CUDA / ISPC language tests                                          | Exotic compilers not available                                                                        | Skip                                   |
| `test_configure.ml`          | `try_compile` ConfigureLog / ProjectVars / TopIncludes                            | Test cmake internals (`CMAKE_TRY_COMPILE_PLATFORM_VARIABLES`, top-level includes) not exposed in yelu | Ignore                                 |
| `test_configure.ml`          | `try_run` configure+run tests                                                     | Run result is machine-dependent binary exit code                                                      | Compile half tested via `try_compile`  |

### Partial coverage

| Test file                                                                       | What is tested                                                                                                                                                                             | What is not tested                                                                                                                                | Priority                               |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| `test_string.ml` + `test_string2.ml` + `test_string3.ml` + `test_string_hex.ml` | APPEND, JOIN, CONCAT, REPEAT, GENEX_STRIP; FIND, SUBSTRING, STRIP, REPLACE, REGEX REPLACE, REGEX MATCH, REGEX MATCHALL; TOUPPER, TOLOWER, LENGTH, PREPEND, COMPARE, MAKE_C_IDENTIFIER, HEX | Bracket-string args to APPEND; REGEX REPLACE multiple capture groups; SUBSTRING begin > length; TIMESTAMP (time-dependent); UTF-8 case conversion | Low — all main subcommands now covered |
| `test_math.ml`                                                                  | `*` `/` `%` `&` `\|` `^` `<<` `>>` `~`; DECIMAL/HEX output; overflow wrap; tolerated syntax                                                                                                | operator precedence edge cases                                                                                                                    | Low — all operators covered            |
| `test_list.ml` + `test_list2.ml` + `test_list3.ml` + `test_list4.ml`            | JOIN, SUBLIST, PREPEND, POP_BACK/POP_FRONT, SORT, FILTER, LENGTH, GET, APPEND, FIND, REMOVE_ITEM, REMOVE_AT, REVERSE, INSERT; TRANSFORM (7 actions × 3 selectors)                          | SORT full option matrix (CASE × ORDER × COMPARE combinations); TRANSFORM GENEX_STRIP; TRANSFORM FOR with step                                     | Low — all subcommands now covered      |
| `test_set.ml`                                                                   | Normal set/unset; PARENT_SCOPE; CACHE first-write-wins; FORCE; PATH, BOOL, STRING types; unset(CACHE)                                                                                      | CACHE types FILEPATH, INTERNAL; recursive PARENT_SCOPE; cache type coercion                                                                       | Low — main types covered               |
| `test_if.ml`                                                                    | IN_LIST, MATCHES, VERSION_*; AND/OR compound; NOT(AND); numeric/string comparisons; EXISTS/IS_DIRECTORY/IS_ABSOLUTE                                                                        | DEFINED in if context; IS_NEWER_THAN, IS_SYMLINK; file permission tests                                                                           | Low — main forms covered               |
| `test_separate_arguments.ml`                                                    | UNIX_COMMAND (simple/quoted/empty); NATIVE_COMMAND (simple); old-style plain                                                                                                               | Complex shell quoting (backslash escapes, nested quotes)                                                                                          | Low                                    |
| `test_set_env.ml`                                                               | Read pre-set env var; set(ENV{}) + read back; unset(ENV{})                                                                                                                                 | Undefined env var reads as empty; env var with `=` in value                                                                                       | Low                                    |
| `test_message.ml` + `test_message2.ml`                                          | STATUS; CHECK_START/PASS/FAIL; FATAL_ERROR; WARNING; NOTICE; AUTHOR_WARNING; SEND_ERROR; VERBOSE; DEBUG; TRACE; DEPRECATION; CONTEXT (--log-context); INDENT                               | nested CONTEXT push/pop via functions                                                                                                             | All 14 modes + context/indent covered  |
| `test_configure.ml` (try_compile)                                               | pass/fail source; OUTPUT_VARIABLE; C_STANDARD; CXX_STANDARD (6 configure tests)                                                                                                            | LINK_OPTIONS/COPY_FILE (in AST, not conf-run tested); old project form (skipped by design); CUDA/ISPC (exotic compilers)                          | Main new-form cases covered            |

---

## Coverage at a Glance

Two independent metrics — don't conflate them:

| Metric                                               | What it measures                                                                             | Current status                                        |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| **Command coverage** (table below)                   | How many cmake commands have a full yelu pipeline (AST + utils + yelu layer + tests)         | ~50 commands fully implemented; ~5 AST-only; ~5 stubs |
| **Showcase test coverage** (`make cmake-only-check`) | How many official cmake test programs have a yelu equivalent that passes gersemi equivalence | 12 / 12 tractable CMakeOnly suites ✓                  |

Command coverage is the **language completeness** axis — it determines what yelu programs can be written.
Showcase test coverage is the **validation** axis — it confirms the language produces correct cmake for real programs.
High command coverage with low showcase coverage means: the language can express it, but we haven't written the programs yet.

Coverage layers:
- **cmake AST** — typed constructor in `src/langs/cmake/lang_cmake.ml`
- **utils** — ergonomic constructor in `src/langs/cmake/lang_cmake_utils.ml`
- **yelu AST** — typed node in `src/langs/yelu/lang_yelu.ml` + compiler support

## Coverage Table Legend

The pipeline from yelu source to cmake text has four checkpoints:

| Column        | File                                    | What "✓" means                                        |
| ------------- | --------------------------------------- | ----------------------------------------------------- |
| **cmake AST** | `lang_cmake.ml`                         | Typed constructor exists with all fields (not a stub) |
| **utils**     | `lang_cmake_utils.ml`                   | Ergonomic constructor with optional-argument defaults |
| **yelu AST**  | `lang_yelu.ml` + `lang_yelu_compile.ml` | Typed yelu node + type-erasing compile case           |
| **tests**     | see level key below                     | Highest testing level reached (see below)             |

**Testing levels** — defined in [`test_infra.md`](test_infra.md). Each level implies the ones below it:

| Level         | PL term          | One-line summary                                                      |
| ------------- | ---------------- | --------------------------------------------------------------------- |
| `text`        | `src`            | Emitted cmake source text correct; cmake never invoked                |
| `script`      | `interp-result`  | Interpreter accepts it; exit 0; stdout matches                        |
| `script-pair` | `interp-pair`    | Ref cmake and yelu cmake observationally equivalent under interpreter |
| `configure`   | `compile`        | cmake compiles CMakeLists.txt into build system; cache bindings ok    |
| `build`       | `run`            | Running the build system produces identical artifacts                 |
| `file-api`    | `interp-binding` | Full binding environment (targets, flags, deps) identical             |

`—` in tests = no tests at any level.

Abbreviations: `✓` = complete, `~` = partial/in-progress, `stub` = bare constructor no fields, `—` = absent.

## Current Coverage

### By command group

| Group                 | Commands                                                                                                                                                                                                                                                                                                                                                           | Highest test level       |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------ |
| Tutorial (steps 1–12) | `cmake_minimum_required`, `project`, `set`/`unset`, `option`, `if`, `include`, `configure_file`, `add_executable`, `add_library`, `add_subdirectory`, `target_include_directories`, `target_link_libraries`, `target_compile_definitions`/`features`/`options`, `add_custom_command`, `enable_testing`/`add_test`, `set_tests_properties`, `set_target_properties` | `text` / `file-api`      |
| Properties            | `set_property`, `get_property`/`get_target_property`, `set_target_properties`, `define_property`, `add_custom_target`, `add_dependencies`, `target_precompile_headers`                                                                                                                                                                                             | `configure`              |
| Scripting             | `function`/`macro`, `message`, `math`, `foreach`, `while`/`break`/`continue`, `return`, `list`, `string`, `separate_arguments`, `include_guard`, `get_filename_component`                                                                                                                                                                                          | `script` / `script-pair` |
| Find / package        | `find_library`, `find_path`/`file`/`program`, `find_package`, `FetchContent`                                                                                                                                                                                                                                                                                       | `text` / `configure`     |
| File / process        | `file` (15 subcommands), `execute_process`, `configure_package_config_file`, `write_basic_package_version_file`                                                                                                                                                                                                                                                    | `text` / `configure`     |
| Install / export      | `install`, `export`, `add_library(IMPORTED)`                                                                                                                                                                                                                                                                                                                       | `configure`              |
| Compile               | `try_compile` (new source form), `try_run`                                                                                                                                                                                                                                                                                                                         | `configure` / `text`     |
| Directory commands    | `add_compile_definitions`, `add_compile_options`, `add_link_options`, `link_directories`                                                                                                                                                                                                                                                                           | `build`                  |
| Target commands       | `target_link_options`, `target_compile_definitions`, `target_compile_options`, `target_link_directories`, `target_compile_features`, `target_sources`, `target_include_directories`                                                                                                                                                                                | `build`                  |
| Expressions           | Generator expressions `$<…>` (`yelu_genex` + `yge`)                                                                                                                                                                                                                                                                                                                | `text`                   |

### By testing level

| Level         | Commands                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `build`       | `add_compile_definitions`, `add_compile_options`, `add_link_options`, `link_directories`, `target_link_options`, `target_compile_definitions`, `target_compile_options`, `target_link_directories`, `target_compile_features`, `target_sources`, `target_include_directories` (via `Tests/CMakeCommands/`, 11/12; `target_link_libraries` deferred); also `POSITION_INDEPENDENT_CODE`, ALIAS targets, OBJECT/MODULE/INTERFACE libs, `add_custom_command` (via Group 2/3 tests: PositionIndependentTargets, AliasTarget, CxxOnly, CompileDefinitions, TargetName, Simple, LinkLine, LinkLineOrder, OutName, LibName, LinkStatic) |
| `configure`   | `add_custom_command`, `set_property`, `get_property`, `define_property`, `add_custom_target`, `add_dependencies`, `target_precompile_headers`, `try_compile`, `file(RELATIVE_PATH)`, `export`, `configure_package_config_file`, `write_basic_package_version_file`, `add_library(IMPORTED)`, `FetchContent`                                                                                                                                                                                                                                                                                                                     |
| `script-pair` | `set`/`unset`, `if`, `function`/`macro`, `message`, `math`, `foreach`, `while`/`break`/`continue`, `return`, `list`, `string`, `separate_arguments`, `variable_watch`, `cmake_path`, `cmake_language`                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `script`      | `include` (negative-path variants with stderr check)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `file-api`    | `cmake_minimum_required`, `project`, `add_executable`, `add_library`, `target_include_directories`, `target_link_libraries`, `target_compile_definitions`/`features`/`options`, `add_custom_command`, `add_subdirectory` (steps 1–12)                                                                                                                                                                                                                                                                                                                                                                                           |
| `text`        | `cmake_minimum_required`, `project`, `option`, `include`, `configure_file`, `add_executable`, `add_library`, `target_*`, `find_*`, `install`, `file` (ops), `execute_process`, `try_run`, `block`, `cmake_path`, `include_guard`, generator expressions                                                                                                                                                                                                                                                                                                                                                                         |

### Incomplete

| Command                                   | State                                | Blocker              |
| ----------------------------------------- | ------------------------------------ | -------------------- |
| `cmake_language` / `block` / `cmake_path` | AST + PP + text tests; no yelu layer | design — next step   |
| `variable_watch`                          | AST only; no utils/yelu/tests        | next step            |
| `cmake_policy`                            | partial AST stub                     | Y11 — design blocked |
| `cmake_pkg_config`                        | not started                          | cmake 4.x only       |

## cmake Test Suite Taxonomy

> **Tier labels are shared across this file**: Roadmap Tier N = implement the
> commands required to cover Tier N tests. CMakeOnly and RunCMake tractability
> columns use the same tier numbers to indicate which roadmap tier unlocks them.

`yelu/vendor/cmake/Tests/` contains ~313 test directories. The full survey below
groups them by tractability for `check_build_pair` coverage.

### Group 1 — Done

| Directory              | Structure                           | Status                                         |
| ---------------------- | ----------------------------------- | ---------------------------------------------- |
| `Tests/CMakeOnly/`     | Full CMakeLists.txt, NONE compiler  | ✓ 12/12 done (`file-api`)                      |
| `Tests/RunCMake/`      | Per-command `.cmake` snippets, NONE | ✓ 62 compat + 50 pairs done                    |
| `Tests/CMakeCommands/` | 12 subdirs, one command each, ~50 L | ✓ 11/12 done; `target_link_libraries` deferred |

### Group 2 — New tractable (small, focused, C/CXX)

One CMakeLists.txt, ≤100 lines, no cmake module dependencies. Each could become a
`check_build_pair` test.

| Directory                    | Lines | Primary feature                                                             | Note                                        |
| ---------------------------- | ----- | --------------------------------------------------------------------------- | ------------------------------------------- |
| `Simple`                     | 17    | basic exe + static lib                                                      | ✓ done                                      |
| `LinkLine`                   | 13    | link order preservation                                                     | ✓ done (`link_libraries` via quote_cmd)     |
| `LinkLineOrder`              | 37    | deep link order without dep info                                            | ✓ done                                      |
| `OutName`                    | 6     | `OUTPUT_NAME`, `PREFIX`, `SUFFIX` properties                                | ✓ done                                      |
| `LibName`                    | 35    | `LIBRARY_OUTPUT_PATH` / `EXECUTABLE_OUTPUT_PATH`                            | ✓ done (`if(UNIX)` emitted unconditionally) |
| `AliasTarget`                | 72    | `add_library(X ALIAS Y)`, `::` namespacing, `add_custom_command` from alias | ✓ done                                      |
| `ObjectLibrary`              | 81    | `OBJECT` library + `$<TARGET_OBJECTS:...>`                                  | next — 6 subdirs                            |
| `CompileDefinitions`         | ~80   | per-config compile definitions                                              | ✓ done (subdir cmake embedded verbatim)     |
| `Visibility`                 | 64    | `C_VISIBILITY_PRESET`, `VISIBILITY_INLINES_HIDDEN`                          | POST_BUILD nm checks, skip for now          |
| `LinkStatic`                 | 30    | static lib + `LINK_SEARCH_*` properties                                     | ✓ done (mostly quote_cmd; libm.a available) |
| `PositionIndependentTargets` | 14    | `POSITION_INDEPENDENT_CODE` property                                        | ✓ done (3 subdirs, INTERFACE/OBJECT libs)   |

### Group 3 — Subdirectory tests (multi-file, C/CXX)

Root CMakeLists.txt is small but delegates to subdirectories.

| Directory      | Lines (root) | Note                                                      |
| -------------- | ------------ | --------------------------------------------------------- |
| `EmptyLibrary` | 4            | `add_subdirectory` to an empty library subdir             | BLOCKED — cmake 3.28 rejects `add_library(test test.h)` (no linker language)                                                                         |
| `TargetName`   | 5            | two subdirs: executables + scripts                        | ✓ done                                                                                                                                               |
| `CxxOnly`      | 14           | MODULE lib, dot-in-target-name, mixed `.C`/`.cxx` sources | ✓ done                                                                                                                                               |
| `SubDir`       | 50           | deprecated `subdirs()`, `aux_source_directory()`          | BLOCKED — `Executable/CMakeLists.txt` hardcodes `string(FIND ... "SubDir/Executable" ...)` path assertion; only passes under CTest build tree naming |
| `SubDirSpaces` | 76           | path-with-spaces RPATH; `subdirs()` with paren paths      | shares SubDir blocker                                                                                                                                |

### Group 4 — Needs `GenerateExportHeader` cmake module

Same blocker as `target_link_libraries`: `include(GenerateExportHeader)` +
`generate_export_header()` calls throughout.

| Directory             | Lines | Note                               |
| --------------------- | ----- | ---------------------------------- |
| `CompatibleInterface` | 243   | interface property compatibility   |
| `ExportImport`        | 105   | also uses nested cmake invocations |

### Group 5 — Large / complex (C/CXX)

Monolithic tests mixing many features; high `yc_quote_cmd` fraction expected.

| Directory             | Lines | Primary feature                       | Blocker                            |
| --------------------- | ----- | ------------------------------------- | ---------------------------------- |
| `InterfaceLibrary`    | 87    | INTERFACE libraries                   | `GENERATOR_IS_MULTI_CONFIG` guards |
| `CompileOptions`      | 108   | compile options + policy guards       | CMP0092/CMP0129 + multi-config     |
| `CompileFeatures`     | 445   | `target_compile_features` + standards |                                    |
| `GeneratorExpression` | 504   | comprehensive genex testing           |                                    |
| `CustomCommand`       | 609   | `add_custom_command` full coverage    |                                    |
| `Complex`             | 416   | multi-feature integration test        |                                    |

### Group 6 — Blocked

| Directory        | Blocker                                                  |
| ---------------- | -------------------------------------------------------- |
| `PolicyScope`    | `cmake_policy(PUSH/POP/SET)` — Y11 design blocked        |
| `StringFileTest` | `string(REGEX QUOTE)` requires cmake ≥3.29; we have 3.28 |
| `TryCompile`     | `try_compile` needs compiler at configure time           |

### Group 7 — cmake infrastructure (different domain)

Testing cmake's own CTest/CPack/ExternalProject machinery — not the cmake language.
`ExternalProject`, `CTestTest*` (~35 dirs), `CPackComponents*` (~12 dirs),
`ExternalProjectLocal`, `ExternalProjectSubdir`, etc.

### Group 8 — Language-specific (special compilers needed)

Not available locally without installation:
`Fortran*`, `CUDA*`, `CSharp*`, `Swift*`, `Rust*`, `HIP`, `ISPC`, `Java*`,
`ObjC`, `ObjCXX`, `Assembler`, `NasmOnly`, `FortranOnly`, etc.

### Group 9 — Find* modules (~70 dirs)

Each needs the corresponding package installed:
`FindBoost`, `FindOpenSSL`, `FindCURL`, `FindMPI`, `FindProtobuf`, … — skip.

### Group 10 — Platform / generator specific

Non-Linux or non-Makefile/Ninja generators:
`VS*` (~20 dirs), `CFBundle*`, `XCTest`, `iOSNavApp`, `Framework`, `GhsMulti`,
`MFC`, `MSManifest`, `BundleTest`, `BundleGeneratorTest`, etc.

### Group 11 — Trivial / skip

| Directory       | Reason                                        |
| --------------- | --------------------------------------------- |
| `VariableUsage` | 1-line `message()` — no assertions            |
| `EmptyDepends`  | build-system dep tracking, not cmake language |
| `EmptyProperty` | empty property handling, ~10L                 |

## CMakeOnly Tests — Tractability

`Tests/CMakeOnly/` in the cmake source (`yelu/vendor/cmake`) are pure
configure-time tests (no compiler needed for most). Used as coverage benchmarks:
write yelu equivalents, validate with File API comparison.

All 8 tractable suites pass `make cmake-only-check` (12/12 including Before/Any variants):
`find_library`, `find_path`, `TargetScope` (×4), `LinkInterfaceLoop`,
`SelectLibraryConfigurations`, `MajorVersionSelection`, `ProjectInclude*`, `AllFindModules`.

| Test                                         | Note                                                                          |
| -------------------------------------------- | ----------------------------------------------------------------------------- |
| `MajorVersionSelection`                      | Concrete instantiation; reference is parameterized so no gersemi string check |
| `CheckSymbolExists` / `CheckCXXCompilerFlag` | Not tractable — require C compiler at configure time                          |

## RunCMake Tests — Coverage Benchmark

`Tests/RunCMake/<command>/` — one directory per command, each `.cmake` script
exercises one behavior. All use `project(${RunCMake_TEST} NONE)`. Tractability
mirrors our tier plan.

Of 431 total directories: ~80 are `CMP*` policy compat dirs, ~100+ are
toolchain/compiler/platform-specific (VS, Ninja, CUDA, Android, …), and ~100+ are
cmake-infra dirs (ExternalData, GenEx-*, FetchContent, …). The tractable subset is
~30 scripting-only command dirs — all ✓ at the yelu level (Tiers 1–3) except these
gaps:

| Directory | Gap                                                                     |
| --------- | ----------------------------------------------------------------------- |
| `foreach` | `ZIP_LISTS` not in yelu yet                                             |
| `if`      | some condition forms partial (`IN_LIST`, `MATCHES`, `VERSION_*` subset) |
| `project` | `HOMEPAGE_URL`, `DESCRIPTION` flags not in yelu                         |

Full directory listing: `yelu/vendor/cmake/Tests/RunCMake/`.

### Tiers 1–3 — all ✓ (62 compat + 50 pairs; see `doc/worklog_2026_04.md` for details)

| Tier | RunCMake commands covered                                                                                                                                                              | Status |
| ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| 1    | `set`, `option`, `if`, `include`, `function`, `message`, `math`, `find_*`, `target_*`, `export`, `install`, `set_property`, `define_property`, `get_property`                          | ✓ all  |
| 2    | `list` (17/17), `string` (19/19+HEX+JSON+UUID), `foreach`, `while`, `return`, `separate_arguments`, `include_guard`, `get_filename_component`, `target_link_options`, `target_sources` | ✓ all  |
| 3    | `find_package` (basic+CONFIG), `file` (all subcommands), `execute_process`                                                                                                             | ✓ all  |

Gaps remaining: `find_dependency` (absent), `load_cache` (absent). `cmake_language` done (text tests); `block` done (text tests).

### Not tractable as RunCMake benchmarks

Yelu implementation status is independent — these commands may be implemented in yelu
but their RunCMake test scripts cannot serve as automated equivalence benchmarks.

| RunCMake test                       | Yelu impl     | Why not a RunCMake benchmark                                 |
| ----------------------------------- | ------------- | ------------------------------------------------------------ |
| `try_run`                           | ✓             | run-result is a binary exit code — machine-dependent         |
| `execute_process`                   | ✓             | output is process-dependent                                  |
| `file` (DOWNLOAD, GET_RUNTIME_DEPS) | ✓             | network / filesystem runtime                                 |
| `file` (STRINGS, READ, WRITE, etc.) | ✓             | assertions depend on file contents, not cmake semantics      |
| `CompileFeatures`                   | ✓             | queries compiler feature database                            |
| `list/SUBLIST`, `string/JSON/UUID`  | ✓ (own tests) | RunCMake scripts written for cmake 4.3; fail on 3.28 runtime |
| `string/UTF-*`                      | —             | require cmake test fixture files, not standalone scripts     |
| `CMP*` dirs, `string/RegexEmpty*`   | —             | policy-version-specific behavior, always blocked             |
| `string/RegexClear`                 | —             | uses `add_subdirectory` — configure-mode only                |

## Roadmap

### RunCMake Script-Mode — All tractable dirs (62 compat + 50 pairs, ✓ done)

| Dir                            | Compat scripts                                                                                                                                                                                                                    | Yelu pairs                       | Notes                                                                              |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- | ---------------------------------------------------------------------------------- |
| `variable_watch`               | ModifiedAccess, ModifyWatchInCallback, NoWatcher, RaiseInParentScope, WatchTwice                                                                                                                                                  | all 5                            | ✓                                                                                  |
| `cmake_path`                   | ABSOLUTE_PATH, APPEND, APPEND_STRING, COMPARE, CONVERT, HASH, HAS_ITEM, IS_ABSOLUTE, IS_PREFIX, IS_RELATIVE, NATIVE_PATH, NORMAL_PATH, RELATIVE_PATH, REMOVE_EXTENSION, REMOVE_FILENAME, REPLACE_EXTENSION, REPLACE_FILENAME, SET | all 18                           | ✓; needs `-DRunCMake_SOURCE_DIR=dir`; GET blocked (STEM("..")="." differs on 3.28) |
| `while`                        | CMP0130-OLD, CMP0130-WARN, CMP0130-common, EndMismatch                                                                                                                                                                            | counter + break                  | ✓; OLD/-WARN use `check_from_dir`                                                  |
| `return`                       | CMP0140-NEW, CMP0140-OLD, PropagateNothing                                                                                                                                                                                        | early + propagate                | ✓; PropagateFromFunction/Directory blocked                                         |
| `option`                       | CMP0077-NEW, CMP0077-OLD, CMP0077-SECOND-PASS, CMP0077-WARN                                                                                                                                                                       | default + respects_var           | ✓                                                                                  |
| `set`                          | Env, ExtraEnvValue, ParentPulling, ParentPullingRecursive                                                                                                                                                                         | ParentPulling + env inline       | ✓                                                                                  |
| `include`                      | EmptyString, EmptyStringOptional, CMP0146-OLD/-WARN, CMP0148-Interp-OLD/-WARN, CMP0148-Libs-OLD/-WARN                                                                                                                             | EmptyString, EmptyStringOptional | ✓; pairs use `check_pair_text_stderr`; CMP0146/0148 blocked (policy+module)        |
| `math`                         | MATH, Overflow                                                                                                                                                                                                                    | ops + Overflow                   | ✓                                                                                  |
| `list`                         | JOIN, SORT, POP_BACK, POP_FRONT, PREPEND                                                                                                                                                                                          | all 5                            | ✓                                                                                  |
| `string`                       | Concat, Append, Join, Hex, Uuid, Repeat                                                                                                                                                                                           | all 6                            | ✓                                                                                  |
| `foreach`                      | foreach-all-test                                                                                                                                                                                                                  | range + in                       | ✓; upstream ITEMS-before-LISTS → pairs use inline cmake                            |
| `message`                      | newline, message-indent                                                                                                                                                                                                           | newline + indent                 | ✓                                                                                  |
| `function`                     | —                                                                                                                                                                                                                                 | —                                | Blocked: CMAKE_CURRENT_FUNCTION uses `list(SUBLIST)` (cmake 4.3+)                  |
| `include_guard`                | —                                                                                                                                                                                                                                 | —                                | Blocked: all scripts use `add_subdirectory`                                        |
| `get_filename_component`       | —                                                                                                                                                                                                                                 | —                                | Blocked: KnownComponents uses `IN_LIST` (CMP0057 OLD on 3.28)                      |
| `include/ParentVariableScript` | —                                                                                                                                                                                                                                 | —                                | Blocked: `CMAKE_PARENT_LIST_FILE` chain — needs multi-file fixture infra           |

Also fixed: `{`/`}` in stdout patterns (e.g. `ENV{VAR}`) cause `Re.Pcre` parse errors — `escape_braces` in `cmake_runner.ml` escapes them before regex compilation.

Realistic ceiling: ~65 tractable scripts from ~15 dirs (currently 62).

**Remaining open gaps:**

| Gap                       | Detail                                                                                                                                        |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `include` CMP0146/CMP0148 | 6 compat tests, 0 pairs — deprecated Find module behavior under policy; blocked                                                               |
| `foreach-all-test` pair   | Upstream uses ITEMS-before-LISTS; PP emits LISTS-first — needs PP extension to do a direct `check_pair`; simplified inline pair already added |

**Permanently blocked dirs:**

| Category           | Examples                                    | Reason                               |
| ------------------ | ------------------------------------------- | ------------------------------------ |
| CTest dirs         | `ctest_build`, `ctest_configure`, etc.      | Require live CTest environment       |
| Configure-only     | `target_*`, `ExportImport`, `FileAPI`, etc. | Need `cmake -S -B` + compiler        |
| `CMP*` dirs (60+)  | all                                         | Policy/compat tests, error-case only |
| cmake 4.3+ scripts | SUBLIST, JSON GET_RAW                       | cmake 3.28 runtime                   |
| External tools     | `ClangTidy`, `Cppcheck`, `Autogen_*`        | Non-cmake binaries required          |

**Gotcha — `include(relative.cmake)` resolution in script mode:**

`include(filename.cmake)` (without `${CMAKE_CURRENT_LIST_DIR}/`) resolves relative
to the process CWD, not the script's directory. CTest sets CWD to the script dir
automatically; plain `cmake -P` does not.

Fix used: `check_from_dir` in `test_runcmake_compat.ml` prefixes the command with
`cd <script-dir> &&`, matching CTest's behavior. Applies to any script that uses bare
`include(relative.cmake)` — identifiable by checking whether a sibling `.cmake` file
is included without `${CMAKE_CURRENT_LIST_DIR}/`.

Alternative (naive): copy the included file(s) to the temp dir or to CWD before
running, then run without `check_from_dir`. More portable but requires per-script
copy logic. Current `check_from_dir` approach is sufficient for read-only vendor files.

### Near-term (non-blocking)

| Item                     | Status                                                                                                                           |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| CMakeOnly showcases      | ✓ Done — 12/12 tractable suites passing `make cmake-only-check`                                                                  |
| Y1 — File API test alias | ✓ Done — `dune build @yelu/test/test-file-api/file-api-test`; 12/12 steps pass; yelu exes promoted via `(promote (until-clean))` |
| RunCMake yelu pairs      | ✓ Done — 50 pairs across 12 groups; remaining gaps all blocked (see above)                                                       |

### Blocked — `cmake_policy` (Y11)

Unlocks CMP0186 / CMP0140 / CMP0124; design pass needed first. See `language_design.md`.

### Tier 5 and beyond — see `doc/language_design.md`

Typed variable lifecycle (Tier 5), conf/build boundary collapse (Tier 6), multi-stage
core (Tier 7), language architecture, and settled design decisions are all in
`doc/language_design.md`.

## Coverage Scorecard

Five independent axes. Each row is a different question about how well yelu is covered.

| Axis                      | Metric                                     | Done               | Ceiling   | Notes                                                                                    |
| ------------------------- | ------------------------------------------ | ------------------ | --------- | ---------------------------------------------------------------------------------------- |
| **Test depth**            | build-level tests (22)                     | 22 / ~30 tractable | ~30       | 11 CMakeCommands + 11 Group 2/3; `target_link_libraries` + SubDir/SubDirSpaces blocked   |
| **Test depth**            | file-api tests (steps 1–12)                | 12 / 12            | 12        | Full codemodel-v2 binding match ✓                                                        |
| **Test depth**            | configure tests                            | 23                 | ~30       | Properties, try_compile, FetchContent, export                                            |
| **Test depth**            | script-pair tests                          | 50 / ~65           | ~65       | 12 command groups; remaining 3 dirs all blocked                                          |
| **Test depth**            | script compat tests                        | 62 / ~65           | ~65       | ceiling is ~65 tractable from ~15 dirs                                                   |
| **Test depth**            | text unit tests                            | ~193               | unbounded | PP + compiler correctness                                                                |
| **Command breadth**       | commands at `build` level                  | ~15                | ~20       | all `target_*` + `add_compile_*`; ALIAS/OBJECT/MODULE libs; gap: `target_link_libraries` |
| **Command breadth**       | commands at `script-pair` level            | ~15                | ~20       | all scripting core; gap: `cmake_policy` (Y11)                                            |
| **Command breadth**       | commands with any test                     | ~60                | ~70       | `text`-only commands: `find_*`, `install`, `file`, genex                                 |
| **Benchmark suites**      | `Tests/CMakeOnly/`                         | 12 / 12 ✓          | 12        | all tractable dirs done                                                                  |
| **Benchmark suites**      | `Tests/CMakeCommands/`                     | 11 / 12            | 12        | `target_link_libraries` deferred                                                         |
| **Benchmark suites**      | `Tests/RunCMake/` compat                   | 62 / ~65           | ~65       | realistic ceiling reached                                                                |
| **Benchmark suites**      | `Tests/RunCMake/` pairs                    | 50 / ~65           | ~65       | all tractable dirs done                                                                  |
| **Benchmark suites**      | `Tests/` Group 2/3 build                   | 11 / ~18 tractable | ~18       | next: ObjectLibrary (6 subdirs)                                                          |
| **Language completeness** | commands fully pipelined (AST→yelu→tested) | ~50                | ~70       | gaps: `cmake_policy`, `cmake_language`/`block` yelu layer                                |
| **Language completeness** | commands AST-only or stubs                 | ~5                 | —         | `cmake_policy` partial stub; `cmake_pkg_config` not started                              |

### Summary

The strongest axes are **benchmark suite coverage** (CMakeOnly and RunCMake both near ceiling) and **scripting depth** (script-pair tests cover all tractable command dirs). The weakest axis is **build-level breadth**: 22 tests cover the common patterns but Groups 2–5 of `Tests/` still have ~7 tractable directories to add. The single biggest unlocker is `cmake_policy` (Y11) — it unblocks CMP0140 (`return(PROPAGATE)`), CMP0124 (`foreach` scoping), CMP0186 (regex empty match), and several blocked RunCMake dirs.

## Test Harness for CMakeOnly Coverage

Each CMakeOnly test gets a yelu equivalent under `test/test-cmake-only/`:

```
test/test-cmake-only/
  find_library/
    ref/CMakeLists.txt   ← copy from Tests/CMakeOnly/find_library/
    yelu.ml              ← yelu program producing equivalent cmake
  find_path/
    ...
```

Validation: `make file-api-test` extended to include these tests, comparing
`Tests/CMakeOnly/<test>/CMakeLists.txt` (reference) against yelu-generated cmake.
