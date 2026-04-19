# Yelu Language Coverage Plan

## Current Focus

193 unit tests + 23 configure tests passing.

**Active next steps:**
- CMakeOnly showcases — expand from 8/12 tractable; `ProjectInclude*` unblocked
- Y1 — wire RunCMake configure pipeline into dune tests

---

## Known Gaps and Dropped Test Cases

### Structurally blocked

These require features or infrastructure not yet in yelu. No workaround exists.

| Blocked item | What it unlocks | Tracking |
|---|---|---|
| `cmake_policy` (Y11) | REGEX zero-length matches (CMP0186), `return(PROPAGATE)` (CMP0140), `foreach` variable scoping (CMP0124), `try_compile` policy variants | Y11 — design pass needed; see `language_design.md` policy section |
| Build-time test harness | Generator expression value verification, `try_run` run-result, PCH actual compilation | Needs `cmake --build` runner; no harness yet |

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

| Test file                    | Case dropped                                                                      | Missing yelu feature                                                                | Notes                                  |
| ---------------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | -------------------------------------- |
| `test_foreach2.ml`           | `ZIP_LISTS` CMP0124 loop-variable scoping (NEW vs OLD behaviour after loop exits) | `cmake_policy(SET CMP0124 NEW)` not in yelu                                         | Y11                                    |
| `test_foreach.ml`            | CMP0124 loop variable scoping (NEW vs OLD)                                        | `cmake_policy` not in yelu                                                          | Y11; loop var scoping after loop exits |
| `test_return.ml`             | `return(PROPAGATE …)`                                                             | `cmake_policy(SET CMP0140 NEW)` not in yelu                                         | Y11 design TODO                        |
| `test_return.ml`             | `return()` inside `block()` / `add_subdirectory()` scope                          | `block()` done; subdirectory scope not in yelu                                      | subdirectory scope                     |
| `test_separate_arguments.ml` | `WINDOWS_COMMAND`, `PROGRAM`/`PROGRAM_ARGS` modes                                 | Platform-specific; not representable portably                                       | Would need a Windows CI target         |
| `test_message2.ml`           | `CMAKE_MESSAGE_CONTEXT` nested push/pop via functions                             | Low value for scripting-only tests                                                  | Skip                                   |
| `test_function.ml`           | `CMAKE_CURRENT_FUNCTION_LINE`                                                     | Not populated in cmake `-P` script mode (cmake 3.28, verified; configure mode only) | Revisit if configure-mode tests added  |
| `test_string_uuid.ml`        | `string(UUID …)` GET_RAW, STRING_ENCODE sub-commands                              | cmake 4.3+ features; we're on 3.28                                                  | —                                      |
| —                            | `string` UTF-16/32 encoding                                                       | Absent from cmake AST; niche                                                        | Low — skip for now                     |
| —                            | `include_guard` DIRECTORY/GLOBAL conf-run                                         | Requires `include()` + multiple files                                               | Out of scope for `-P` script tests     |
| `test_configure.ml`          | `try_compile` old project form (`<bindir> <srcdir>`)                              | Legacy interface; not in yelu API by design                                         | 20 RunCMake old-form tests skipped     |
| `test_configure.ml`          | `try_compile` CMP0056/0066/0067/0128/0137/0210 policy variants                   | `cmake_policy` not in yelu                                                          | Y11                                    |
| `test_configure.ml`          | `try_compile` CUDA / ISPC language tests                                          | Exotic compilers not available                                                      | Skip                                   |
| `test_configure.ml`          | `try_compile` ConfigureLog / ProjectVars / TopIncludes                            | Test cmake internals (`CMAKE_TRY_COMPILE_PLATFORM_VARIABLES`, top-level includes) not exposed in yelu | Ignore |
| `test_configure.ml`          | `try_run` configure+run tests                                                     | Run result is machine-dependent binary exit code                                    | Compile half tested via `try_compile`  |

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
| `test_configure.ml` (try_compile)                                               | pass/fail source; OUTPUT_VARIABLE; C_STANDARD; CXX_STANDARD (6 configure tests)                                                                                                           | LINK_OPTIONS/COPY_FILE (in AST, not conf-run tested); old project form (skipped by design); CUDA/ISPC (exotic compilers)                         | Main new-form cases covered            |

---

## Coverage at a Glance

Two independent metrics — don't conflate them:

| Metric                                               | What it measures                                                                             | Current status                                                       |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| **Command coverage** (table below)                   | How many cmake commands have a full yelu pipeline (AST + utils + yelu layer + tests)         | ~50 commands fully implemented; ~5 AST-only; ~5 stubs                |
| **Showcase test coverage** (`make cmake-only-check`) | How many official cmake test programs have a yelu equivalent that passes gersemi equivalence | 8 / 12 tractable CMakeOnly suites; 4 remaining are ProjectInclude* (unblocked) |

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

**Testing levels** — each level implies the ones below it:

| Level       | Mechanism                | What it checks                                      | Test location                               |
| ----------- | ------------------------ | --------------------------------------------------- | ------------------------------------------- |
| `text`      | OCaml Alcotest unit test | Emitted cmake string is correct (PP and/or Y)       | `test_cmake_pp.ml` / `test_yelu_compile.ml` |
| `script`    | `cmake -P script.cmake`  | cmake script interpreter accepts and executes it    | `test/test-runcmake/`                       |
| `configure` | `cmake -S . -B _build`   | cmake configure accepts it; file API / artifacts OK | `make cmake-check` showcase tests           |

Notes:
- `text` = text generation verified but cmake never invoked. Structural correctness only.
- `script` = `cmake -P` executes it. Works for pure scripting commands; does not exercise filesystem search, package resolution, or configure-tree state.
- `configure` = full cmake configure run. Required for target commands, install, find_package behavior.
- `—` in tests = no tests at any level.

Abbreviations: `✓` = complete, `~` = partial/in-progress, `stub` = bare constructor no fields, `—` = absent.

## Current Coverage

### By command group

| Group | Commands | Highest test level |
|-------|----------|--------------------|
| Tutorial (steps 1–12) | `cmake_minimum_required`, `project`, `set`/`unset`, `option`, `if`, `include`, `configure_file`, `add_executable`, `add_library`, `add_subdirectory`, `target_include_directories`, `target_link_libraries`, `target_compile_definitions`/`features`/`options`, `add_custom_command`, `enable_testing`/`add_test`, `set_tests_properties`, `set_target_properties` | text / configure |
| Properties | `set_property`, `get_property`/`get_target_property`, `set_target_properties`, `define_property`, `add_custom_target`, `add_dependencies`, `target_precompile_headers` | configure |
| Scripting | `function`/`macro`, `message`, `math`, `foreach`, `while`/`break`/`continue`, `return`, `list`, `string`, `separate_arguments`, `include_guard`, `get_filename_component` | script |
| Find / package | `find_library`, `find_path`/`file`/`program`, `find_package`, `FetchContent` | text / configure |
| File / process | `file` (15 subcommands), `execute_process`, `configure_package_config_file`, `write_basic_package_version_file` | text / configure |
| Install / export | `install`, `export`, `add_library(IMPORTED)` | configure |
| Compile | `try_compile` (new source form), `try_run` | configure / text |
| Target extras | `target_link_options`, `target_sources`, `target_compile_features` | text |
| Expressions | Generator expressions `$<…>` (`yelu_genex` + `yge`) | text |

### By testing level

| Level | Commands |
|-------|----------|
| `configure` | `add_custom_command`, `set_property`, `get_property`, `define_property`, `add_custom_target`, `add_dependencies`, `target_precompile_headers`, `try_compile`, `file(RELATIVE_PATH)`, `export`, `configure_package_config_file`, `write_basic_package_version_file`, `add_library(IMPORTED)`, `FetchContent` |
| `script` | `set`/`unset`, `if`, `function`/`macro`, `message`, `math`, `foreach`, `while`/`break`/`continue`, `return`, `list`, `string`, `separate_arguments` |
| `text` | `cmake_minimum_required`, `project`, `option`, `include`, `configure_file`, `add_executable`, `add_library`, `target_*`, `find_*`, `install`, `file` (ops), `execute_process`, `try_run`, `cmake_language`, `block`, `cmake_path`, `include_guard`, generator expressions |

### Incomplete

| Command | State | Blocker |
|---------|-------|---------|
| `cmake_language` / `block` / `cmake_path` | AST + PP + text tests; no yelu layer | design — next step |
| `variable_watch` | AST only; no utils/yelu/tests | next step |
| `cmake_policy` | partial AST stub | Y11 — design blocked |
| `cmake_pkg_config` | not started | cmake 4.x only |

## cmake Test Suite Taxonomy

> **Tier labels are shared across this file**: Roadmap Tier N = implement the
> commands required to cover Tier N tests. CMakeOnly and RunCMake tractability
> columns use the same tier numbers to indicate which roadmap tier unlocks them.

`yelu/vendor/cmake/Tests/` contains ~313 test directories. Most require a
real compiler (`project(X C)` or `project(X CXX)`). The compiler-free subset
is the useful benchmark pool:

| Directory               | Compiler needed | Structure                           | Useful for yelu                       |
| ----------------------- | --------------- | ----------------------------------- | ------------------------------------- |
| `Tests/CMakeOnly/`      | No (NONE)       | Full CMakeLists.txt programs        | Yes — complex configure scripts       |
| `Tests/RunCMake/`       | No (NONE)       | Per-command small `.cmake` snippets | **Best** — maps 1:1 to coverage table |
| `Tests/CMakeCommands/`  | Yes (C/CXX)     | target_* with real builds           | No                                    |
| `Tests/PolicyScope/`    | Yes (C)         | cmake_policy stack                  | No                                    |
| `Tests/StringFileTest/` | Yes (CXX)       | string/file with real build         | No                                    |
| `Tests/TryCompile/`     | Yes             | try_compile/try_run                 | No                                    |
| `Tests/VariableUsage/`  | No              | Single `message()` line             | Trivial                               |

**RunCMake** is the primary benchmark source: each sub-directory corresponds to one
cmake command, contains small focused `.cmake` scripts, runs as `project(X NONE)`,
and provides expected stdout/stderr files for validation. Direct mapping to the
coverage table above.

## CMakeOnly Tests — Tractability

`Tests/CMakeOnly/` in the cmake source (`yelu/vendor/cmake`) are pure
configure-time tests (no compiler needed for most). Used as coverage benchmarks:
write yelu equivalents, validate with File API comparison.

| Test                                         | Commands needed                                  | Tractable     | Status                                                                               |
| -------------------------------------------- | ------------------------------------------------ | ------------- | ------------------------------------------------------------------------------------ |
| `find_library`                               | `find_library`, `message`                        | **Tier 1**    | ✓ done                                                                               |
| `find_path`                                  | `find_path`, `message`                           | **Tier 1**    | ✓ done                                                                               |
| `TargetScope` (×4 files)                     | `target_link_libraries` scope modes              | **Tier 1**    | ✓ done                                                                               |
| `LinkInterfaceLoop`                          | `target_link_libraries` circular                 | **Tier 1**    | ✓ done                                                                               |
| `SelectLibraryConfigurations`                | `list(GET)`, module include                      | Tier 2        | ✓ done                                                                               |
| `MajorVersionSelection`                      | `if`, `string(TOUPPER)`, `find_package`, `math`  | Tier 2/3      | ✓ configure (concrete instantiation; reference is parameterized so no gersemi check) |
| `CheckSymbolExists` / `CheckCXXCompilerFlag` | `include`, check modules                         | not tractable | blocked                                                                              |
| `ProjectInclude*`                            | `cmake_language` meta                            | done          | `cmake_language(CALL/EVAL)` now in yelu                                              |
| `AllFindModules`                             | `find_package`, `macro`, `foreach`, `file(GLOB)` | Tier 3        | ✓ configure (full glob enumeration; `cmake -S -B` passes)                            |

## RunCMake Tests — Coverage Benchmark

`Tests/RunCMake/<command>/` — one directory per command, each `.cmake` script
exercises one behavior. All use `project(${RunCMake_TEST} NONE)`. Tractability
mirrors our tier plan.

Of 431 total directories: ~80 are `CMP*` policy compat dirs, ~100+ are
toolchain/compiler/platform-specific (VS, Ninja, CUDA, Android, …), and ~100+ are
cmake-infra dirs (ExternalData, GenEx-*, FetchContent, …). The tractable subset is
~30 scripting-only command dirs — all ✓ at the yelu level (Tiers 1–3) except these
gaps:

| Directory | Gap                                                                    |
| --------- | ---------------------------------------------------------------------- |
| `foreach` | `ZIP_LISTS` not in yelu yet                                             |
| `if`      | some condition forms partial (`IN_LIST`, `MATCHES`, `VERSION_*` subset) |
| `project` | `HOMEPAGE_URL`, `DESCRIPTION` flags not in yelu                        |

Full directory listing: `yelu/vendor/cmake/Tests/RunCMake/`.

### Tiers 1–3 — all ✓ (see `doc/worklog_2026_04.md` for details)

Summary coverage across RunCMake directories (compiler-free subset):

| Tier | RunCMake commands covered                                                                                                                                                              | Status |
| ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| 1    | `set`, `option`, `if`, `include`, `function`, `message`, `math`, `find_*`, `target_*`, `export`, `install`, `set_property`, `define_property`, `get_property`                          | ✓ all  |
| 2    | `list` (17/17), `string` (19/19+HEX+JSON+UUID), `foreach`, `while`, `return`, `separate_arguments`, `include_guard`, `get_filename_component`, `target_link_options`, `target_sources` | ✓ all  |
| 3    | `find_package` (basic+CONFIG), `file` (all subcommands), `execute_process`                                                                                                             | ✓ all  |

Gaps remaining: `find_dependency` (absent), `load_cache` (absent). `cmake_language` done (text tests); `block` done (text tests).

### Not tractable as RunCMake benchmarks

Yelu implementation status is independent — these commands may be implemented in yelu
but their RunCMake test scripts cannot serve as automated equivalence benchmarks.

| RunCMake test                       | Why                                                       |
| ----------------------------------- | --------------------------------------------------------- |
| `try_run`                           | run-result is a binary exit code — machine-dependent      |
| `execute_process`                   | output is process-dependent                               |
| `file` (DOWNLOAD, GET_RUNTIME_DEPS) | network / filesystem runtime                              |
| `file` (STRINGS, READ, WRITE, etc.) | assertions depend on file contents, not cmake semantics   |
| `CompileFeatures`                   | queries compiler feature database                         |

## Roadmap


### Near-term (non-blocking)

| Item | What to do |
|---|---|
| CMakeOnly showcases | Expand from 8/12; `ProjectInclude*` unblocked by `cmake_language` |
| Y1 — RunCMake configure pipeline | Wire cmake configure + output check into dune tests |

### Blocked — `cmake_policy` (Y11)

Unlocks CMP0186 / CMP0140 / CMP0124; design pass needed first. See `language_design.md`.

### Tier 5 and beyond — see `doc/language_design.md`

Typed variable lifecycle (Tier 5), conf/build boundary collapse (Tier 6), multi-stage
core (Tier 7), language architecture, and settled design decisions are all in
`doc/language_design.md`.

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
