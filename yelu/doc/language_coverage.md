# Yelu Language Coverage Plan

## Coverage at a Glance

Two independent metrics — don't conflate them:

| Metric | What it measures | Current status |
| ------ | ---------------- | -------------- |
| **Command coverage** (table below) | How many cmake commands have a full yelu pipeline (AST + utils + yelu layer + tests) | ~50 commands fully implemented; ~5 AST-only; ~5 stubs |
| **Showcase test coverage** (`make cmake-only-check`) | How many official cmake test programs have a yelu equivalent that passes gersemi equivalence | 8 / 20 CMakeOnly suites (Tier 1+2 complete); 0 / 431 RunCMake suites |

Command coverage is the **language completeness** axis — it determines what yelu programs can be written.
Showcase test coverage is the **validation** axis — it confirms the language produces correct cmake for real programs.
High command coverage with low showcase coverage means: the language can express it, but we haven't written the programs yet.

Coverage layers:
- **cmake AST** — typed constructor in `src/langs/cmake/lang_cmake.ml`
- **utils** — ergonomic constructor in `src/langs/cmake/lang_cmake_utils.ml`
- **yelu AST** — typed node in `src/langs/yelu/lang_yelu.ml` + compiler support

## Coverage Table Legend

The pipeline from yelu source to cmake text has four checkpoints:

| Column        | File                                        | What "✓" means                                               |
| ------------- | ------------------------------------------- | ------------------------------------------------------------ |
| **cmake AST** | `lang_cmake.ml`                             | Typed constructor exists with all fields (not a stub)        |
| **utils**     | `lang_cmake_utils.ml`                       | Ergonomic constructor with optional-argument defaults        |
| **yelu AST**  | `lang_yelu.ml` + `lang_yelu_compile.ml`     | Typed yelu node + type-erasing compile case                  |
| **tests**     | `test_cmake_pp.ml` / `test_yelu_compile.ml` | Alcotest coverage (PP = printer test, Y = yelu compile test) |

Abbreviations: `✓` = complete, `~` = partial/in-progress, `stub` = bare constructor no fields, `—` = absent.

## Current Coverage

| Command / Feature                          | cmake AST | utils | yelu AST | tests       |
| ------------------------------------------ | --------- | ----- | -------- | ----------- |
| **Tutorial steps (steps 1–12)**            |           |       |          |             |
| `cmake_minimum_required`                   | ✓         | ✓     | ✓        | PP + Y      |
| `project`                                  | ✓         | ✓     | ✓        | PP + Y      |
| `set`                                      | ✓         | ✓     | ✓        | PP + Y      |
| `option`                                   | ✓         | ✓     | ✓        | PP + Y      |
| `if/else/endif`                            | ✓         | ✓     | ✓        | PP + Y      |
| `include`                                  | ✓         | ✓     | ✓        | PP + Y      |
| `configure_file`                           | ✓         | ✓     | ✓        | PP + Y      |
| `add_executable`                           | ✓         | ✓     | ✓        | PP + Y      |
| `add_library`                              | ✓         | ✓     | ✓        | PP + Y      |
| `add_subdirectory`                         | ✓         | ✓     | ✓        | PP + Y      |
| `target_include_directories`               | ✓         | ✓     | ✓        | PP + Y      |
| `target_link_libraries`                    | ✓         | ✓     | ✓        | PP + Y      |
| `target_compile_definitions`               | ✓         | ✓     | ✓        | PP + Y      |
| `target_compile_features`                  | ✓         | ✓     | ✓        | PP + Y      |
| `target_compile_options`                   | ✓         | ✓     | ✓        | PP + Y      |
| `add_custom_command`                       | ✓         | ✓     | ✓        | cmake-check |
| `enable_testing` / `add_test`              | ✓         | ✓     | ✓        | PP + Y      |
| `set_tests_properties`                     | ✓         | ✓     | ✓        | PP + Y      |
| `set_target_properties`                    | ✓         | ✓     | ✓        | PP          |
| `set_property` (TARGET + GLOBAL scopes)    | ✓         | ✓     | ✓        | —           |
| `get_property` (GLOBAL scope)              | ✓         | ✓     | ~        | —           |
| `unset` / `unset(CACHE)`                  | ✓         | ✓     | ✓        | —           |
| `add_library(IMPORTED [GLOBAL])`           | ✓         | ✓     | ✓        | cmake-check |
| `file(RELATIVE_PATH …)`                    | ✓         | ✓     | ✓        | cmake-check |
| `get_filename_component`                   | ✓         | ✓     | ✓        | —           |
| `install` (targets/files/export)           | ✓         | ✓     | ✓        | PP + Y      |
| `export`                                   | ✓         | ✓     | ✓        | cmake-check |
| `configure_package_config_file`            | ✓         | ✓     | ✓        | cmake-check |
| `write_basic_package_version_file`         | ✓         | ✓     | ✓        | cmake-check |
| **Scripting — Tier 1 done**                |           |       |          |             |
| `function` / `macro` / `apply`             | ✓         | ✓     | ✓        | PP + Y      |
| `message` (14 modes)                       | ✓         | ✓     | ✓        | PP + Y      |
| `math`                                     | ✓         | ✓     | ✓        | PP + Y      |
| `find_library`                             | ✓         | ✓     | ✓        | PP + Y      |
| `find_path` / `find_file` / `find_program` | ✓         | ✓     | ✓        | PP + Y      |
| **Scripting — Tier 2 done**                |           |       |          |             |
| `foreach` (items/range/in)                 | ✓         | ✓     | ✓        | PP + Y      |
| `while` / `break` / `continue`             | ✓         | ✓     | ✓        | PP + Y      |
| `return`                                   | ✓         | ✓     | ✓        | PP + Y      |
| `list` (16/16 sub-commands; TRANSFORM absent) | ✓      | ✓     | ✓        | PP + Y      |
| `string` (18/18 cmake-AST sub-commands; JSON/UUID absent from cmake AST) | ✓ | ✓ | ✓ | PP + Y |
| **Scripting — AST only, no utils/yelu**    |           |       |          |             |
| `cmake_policy`                             | ~         | —     | —        | —           |
| `target_link_options`                      | ✓         | —     | —        | —           |
| `target_sources`                           | ✓         | —     | —        | —           |
| `target_precompile_headers`                | ✓         | —     | —        | —           |
| `add_custom_target`                        | ✓         | —     | —        | —           |
| `add_dependencies`                         | ✓         | —     | —        | —           |
| `variable_watch`                           | ✓         | —     | —        | PP partial  |
| `separate_arguments`                       | ✓         | —     | —        | —           |
| `include_guard`                            | ✓         | ✓     | ✓        | Y           |
| `separate_arguments`                       | ✓         | ✓     | ✓        | Y           |
| `target_link_options`                      | ✓         | ✓     | ✓        | Y           |
| `target_sources`                           | ✓         | ✓     | ✓        | Y           |
| `define_property`                          | ✓         | —     | —        | —           |
| **Tier 3 — stubs or absent**               |           |       |          |             |
| `find_package`                             | stub      | —     | —        | —           |
| `execute_process`                          | stub      | —     | —        | —           |
| `file` (READ/WRITE/GLOB/…)                 | stub      | —     | —        | —           |
| `try_compile` / `try_run`                  | stub      | —     | —        | —           |
| `FetchContent`                             | —         | —     | —        | —           |
| Generator expressions `$<…>`               | —         | —     | —        | —           |
| `cmake_pkg_config` (4.x)                   | —         | —     | —        | —           |

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

| Test                                         | Commands needed                     | Tractable       | Status    |
| -------------------------------------------- | ----------------------------------- | --------------- | --------- |
| `find_library`                               | `find_library`, `message`           | **Tier 1**      | ✓ done    |
| `find_path`                                  | `find_path`, `message`              | **Tier 1**      | ✓ done    |
| `TargetScope` (×4 files)                     | `target_link_libraries` scope modes | **Tier 1**      | ✓ done    |
| `LinkInterfaceLoop`                          | `target_link_libraries` circular    | **Tier 1**      | ✓ done    |
| `SelectLibraryConfigurations`                | `list(GET)`, module include         | Tier 2          | ✓ done    |
| `MajorVersionSelection`                      | `if`, `string(REGEX)`, `find_package` | Tier 2/3      | blocked   |
| `CheckSymbolExists` / `CheckCXXCompilerFlag` | `include`, check modules            | not tractable   | blocked   |
| `ProjectInclude*`                            | `cmake_language` meta               | Tier 3          | —         |
| `AllFindModules`                             | full `find_package`                 | Tier 3          | —         |

## RunCMake Tests — Coverage Benchmark

`Tests/RunCMake/<command>/` — one directory per command, each `.cmake` script
exercises one behavior. All use `project(${RunCMake_TEST} NONE)`. Tractability
mirrors our tier plan.

### Directory Index

**+tests** = positive (non-error-case) `.cmake` scripts in the directory.
Most RunCMake scripts test error conditions; the `+tests` count is what would
map to yelu showcase programs.

Filter key: `—` = no constraint · `CMP*` = cmake policy compatibility
tests · `env` = exercises PATH/env search · `compiler` = C/C++ toolchain
required · `platform` = Windows/macOS-specific · `fp` = requires
`find_package`

| Directory                    | Commands tested                                | +tests | Filter       | Yelu              |
| ---------------------------- | ---------------------------------------------- | ------ | ------------ | ----------------- |
| **Scripting — pure**         |                                                |        |              |                   |
| `foreach`                    | foreach IN LISTS/ITEMS/RANGE, ZIP_LISTS        | 5      | —            | ~ (ZIP_LISTS gap) |
| `while`                      | while, break, continue                         | 4      | CMP*         | ✓                 |
| `return`                     | return, PROPAGATE                              | 5      | CMP*         | ✓                 |
| `math`                       | math EXPR, DECIMAL/HEX output                  | 3      | —            | ✓                 |
| `function`                   | function, macro, ARGN/ARGC/ARGV                | 2      | —            | ✓                 |
| `message`                    | 14 modes, log levels, CHECK_*, context         | 12     | —            | ✓                 |
| `set`                        | set, unset, cache modes                        | 6      | env          | ✓                 |
| `option`                     | option                                         | 4      | CMP*         | ✓                 |
| `include`                    | include, OPTIONAL, NO_POLICY_SCOPE             | 22     | CMP*         | ✓                 |
| `if`                         | all condition forms: IN_LIST, MATCHES, VERSION_* | 10   | —            | ~ (some cond forms not in yelu) |
| `list`                       | 16 subcommands + TRANSFORM                     | 22     | —            | ~ (yelu: 16/16 ✓; TRANSFORM absent from cmake AST) |
| `string`                     | 20 subcommands incl. JSON, UUID, TIMESTAMP     | 19     | —            | ~ (yelu: 18/18 ✓ all cmake-AST subcommands; JSON/UUID absent from cmake AST) |
| **Scripting — file/args**    |                                                |        |              |                   |
| `separate_arguments`         | separate_arguments UNIX/WINDOWS/NATIVE         | 7      | —            | ✓                 |
| `include_guard`              | include_guard DIRECTORY/GLOBAL                 | 3      | —            | ✓                 |
| `get_filename_component`     | DIR, NAME, EXT, NAME_WE, REALPATH              | 1      | —            | ✓                 |
| **Property commands**        |                                                |        |              |                   |
| `set_property`               | set_property all scopes                        | 13     | —            | ✓ (TARGET+GLOBAL) |
| `get_property`               | get_property all scopes                        | 10     | —            | ~ (GLOBAL ✓, others AST only) |
| `define_property`            | define_property, INHERITED, INITIALIZE_FROM_VARIABLE | 3 | —         | AST               |
| **Find commands**            |                                                |        |              |                   |
| `find_library`               | find_library, NAMES/PATHS/HINTS/NO_* flags     | 18     | env          | ✓                 |
| `find_path`                  | find_path                                      | 11     | env          | ✓                 |
| `find_file`                  | find_file                                      | 10     | env          | ✓                 |
| `find_program`               | find_program                                   | 18     | env/platform | ✓                 |
| `find_package`               | basic, CONFIG, COMPONENTS, version             | 123    | fp           | stub              |
| **Project / configure**      |                                                |        |              |                   |
| `cmake_minimum_required`     | cmake_minimum_required                         | 9      | CMP*         | ✓                 |
| `configure_file`             | configure_file                                 | 10     | —            | ✓                 |
| `project`                    | project, LANGUAGES, VERSION, HOMEPAGE_URL      | 43     | CMP*         | ~                 |
| **Target commands**          |                                                |        |              |                   |
| `target_link_libraries`      | target_link_libraries, scope modes             | 15     | compiler     | ✓ yelu            |
| `target_link_options`        | target_link_options, BEFORE, LINKER: prefix    | 47     | compiler     | ✓ yelu            |
| `target_sources`             | target_sources, FILE_SET HEADERS               | 23     | compiler     | ✓ yelu            |
| `target_compile_definitions` | PUBLIC/PRIVATE/INTERFACE                       | 3      | compiler     | ✓ yelu            |
| `target_compile_features`    | cxx_std_* features                             | 2      | compiler     | ✓ yelu            |
| `target_compile_options`     | flags with scope                               | 4      | compiler     | ✓ yelu            |
| `target_include_directories` | SYSTEM, BEFORE, scope                          | 4      | compiler     | ✓ yelu            |
| **Install / export**         |                                                |        |              |                   |
| `install`                    | targets / files / export                       | 129    | compiler     | ✓ yelu            |
| `export`                     | targets, config, package                       | 23     | —            | ✓ yelu            |

**Not listed** (431 total RunCMake directories): CMP* policy dirs (~80),
toolchain/compiler dirs (VS, Ninja, Clang, CUDA, Swift, …), platform dirs
(Android, Apple, Windows, …), CMake-infra dirs (ExternalData, FetchContent,
GenEx-*, …). None of these are tractable as scripting-only yelu showcases.

### Tier 1 — covered or recently expanded

| RunCMake test                 | Commands exercised                                          | Yelu coverage                  |
| ----------------------------- | ----------------------------------------------------------- | ------------------------------ |
| `set`                         | `set`, `unset`, cache modes, `PARENT_SCOPE`                 | ✓                              |
| `option`                      | `option`                                                    | ✓                              |
| `if`                          | all condition forms incl. `IN_LIST`, `MATCHES`, `VERSION_*` | ✓ partial — good gap benchmark |
| `include`                     | `include` with/without `OPTIONAL`, `NO_POLICY_SCOPE`        | ✓                              |
| `function`                    | `function`, `ARGN`/`ARGC`/`ARGV`, `PARENT_SCOPE`            | ✓                              |
| `message`                     | all 14 modes, log levels, `CHECK_*`, context                | ✓ (Tier 1 done)                |
| `math`                        | `EXPR`, `OUTPUT_FORMAT DECIMAL/HEXADECIMAL`, overflow       | ✓ (Tier 1 done)                |
| `find_library`                | NAMES, PATHS, HINTS, NO_* flags, debug mode                 | ✓ (Tier 1 done)                |
| `find_path`                   | same shape as find_library                                  | ✓ (Tier 1 done)                |
| `find_file`                   | same shape                                                  | ✓ (Tier 1 done)                |
| `find_program`                | same shape                                                  | ✓ (Tier 1 done)                |
| `target_compile_definitions`  | PUBLIC/PRIVATE/INTERFACE, generator exprs                   | ✓                              |
| `target_compile_features`     | cxx_std_* features                                          | ✓                              |
| `target_compile_options`      | flags with scope                                            | ✓                              |
| `target_include_directories`  | SYSTEM, BEFORE, scope                                       | ✓                              |
| `target_link_libraries`       | all scope modes                                             | ✓                              |
| `target_link_libraries-ALIAS` | alias target TLL                                            | ✓                              |
| `export`                      | targets, config, package                                    | ✓                              |
| `install`                     | targets, files, export                                      | ✓                              |
| `set_property`                | GLOBAL/TARGET/TEST/SOURCE/DIRECTORY                         | ✓                              |
| `define_property`             | INHERITED, BRIEF_DOCS                                       | ✓ AST                          |
| `get_property`                | all scopes                                                  | ✓ AST                          |

### Tier 2 — scripting + list/string ops

| RunCMake test            | Commands exercised                                                                        | Yelu coverage                             |
| ------------------------ | ----------------------------------------------------------------------------------------- | ----------------------------------------- |
| `list`                   | LENGTH, GET, APPEND, REMOVE_*, INSERT, SORT, REVERSE, FIND, JOIN, FILTER, SUBLIST, POP_*, PREPEND, REMOVE_AT | ✓ (16/16 subcommands; TRANSFORM absent from cmake AST) |
| `string`                 | REGEX, REPLACE, LENGTH, SUBSTRING, UPPER/LOWER, STRIP, FIND, CONCAT, JOIN, APPEND, PREPEND, REPEAT, GENEX_STRIP, COMPARE, MAKE_C_IDENTIFIER, TIMESTAMP | ✓ (18/18 cmake-AST subcommands; JSON/UUID absent from cmake AST entirely) |
| `foreach`                | IN LISTS/ITEMS/RANGE, ZIP_LISTS, multiple iter vars                                       | ~ (full pipeline for LISTS/ITEMS/RANGE; ZIP_LISTS yelu gap)         |
| `while`                  | while/break/continue                                                                      | ✓ (full pipeline)                                   |
| `return`                 | `return()`, `PROPAGATE`                                                                   | ✓ (full pipeline)                                   |
| `separate_arguments`     | UNIX/WINDOWS/NATIVE_COMMAND                                                               | ✓ (full pipeline)                         |
| `include_guard`          | DIRECTORY, GLOBAL                                                                         | ✓ (full pipeline)                         |
| `get_filename_component` | DIR, NAME, EXT, NAME_WE, REALPATH                                                         | ✓ (full pipeline)                         |
| `target_link_options`    | scope, BEFORE, LINKER: prefix                                                             | ✓ (full pipeline)                         |
| `target_sources`         | FILE_SET HEADERS, PRIVATE/PUBLIC                                                          | ✓ (full pipeline)                         |
| `set_tests_properties`   | PASS_REGULAR_EXPRESSION, TIMEOUT                                                          | ✓                                         |
| `variable_watch`         | variable_watch access types                                                               | ✓ AST only                                |

### Tier 3 — find_package + external deps

| RunCMake test     | Commands exercised                 | Yelu coverage |
| ----------------- | ---------------------------------- | ------------- |
| `find_package`    | basic, CONFIG, COMPONENTS, version | stub          |
| `find_dependency` | `find_dependency` module wrapper   | absent        |
| `load_cache`      | cache loading                      | absent        |

### Not tractable (require compiler or runtime exec)

| RunCMake test                       | Why not tractable                       |
| ----------------------------------- | --------------------------------------- |
| `try_compile`                       | invokes C/C++ compiler                  |
| `try_run`                           | invokes compiler + runs binary          |
| `execute_process`                   | runs external process at configure time |
| `file` (DOWNLOAD, GET_RUNTIME_DEPS) | network/filesystem runtime              |
| `file` (STRINGS, READ, WRITE, GLOB) | filesystem ops — partial tractability   |
| `CompileFeatures`                   | queries compiler feature database       |

## Roadmap

### Tier 1 — Expand stubs + unblock CMakeOnly tests ✓ (AST/utils/yelu layer done)

**Goal**: expand find_* stubs to full `find_var_args` records; add `message` (14 modes)
and `math` utils; unblock `TargetScope` and `LinkInterfaceLoop` CMakeOnly tests.

| Item                | Status | What was done                                                             |
| ------------------- | ------ | ------------------------------------------------------------------------- |
| `find_library`      | ✓ done | `find_var_args` record, pp, utils, `Yc_find_library`, compile             |
| `find_path`         | ✓ done | same shape                                                                |
| `find_program`      | ✓ done | same shape                                                                |
| `find_file`         | ✓ done | same shape                                                                |
| `message`           | ✓ done | 14-variant `message_mode`, `Mm_none`…`Mm_deprecation`; `message` utils fn |
| `math`              | ✓ done | `math` utils fn wrapping `Math_lib`                                       |
| `TargetScope` test (×4 files) | ✓ done | `add_library_imported`, `Plain` target_kind, `Lang_none` — cmake-only-check OK |
| `LinkInterfaceLoop` test      | ✓ done | imported shared libs + circular dep via set_target_properties — cmake-only-check OK |
| `find_path` test              | ✓ done | macro, unset_cache, ARGN splat, file(RELATIVE_PATH), if/elseif, STREQUAL — cmake-only-check OK |
| `find_library` test           | ✓ done | + get_filename_component, string(REGEX REPLACE), set_property GLOBAL, foreach — cmake-only-check OK |
| New features (unlocked above) | ✓ done | `Yc_macro`, `Yc_unset_cache`, `Yc_file_relative_path`, `Ystrequal`, `elseif` PP, `Yc_set_global_property`, `Yc_get_filename_component` |

### Tier 2 — List/string ops + foreach + Check modules ✓ (full pipeline done)

**Goal**: cover the remaining pure-scripting language features needed by real projects.

**Done** (cmake AST + utils + yelu AST + compile + tests):

| Item                                      | Status | What was done                                                                     |
| ----------------------------------------- | ------ | --------------------------------------------------------------------------------- |
| `foreach` (all 3 forms)                   | ✓ done | `commands` body field added; utils + yelu AST + compile + 6 yelu tests            |
| `list` (16 sub-commands)                  | ✓ done | `List_cmd of list_cmd`; full utils + yelu AST + compile + 7 yelu tests            |
| `string` (20 sub-commands)                | ✓ done | `String_cmd of string_cmd`; full utils + yelu AST + compile + 8 yelu tests        |
| `while` / `break` / `continue` / `return` | ✓ done | utils + yelu AST + compile + 5 yelu tests (return PROPAGATE uses list_sp newline) |

**CMakeOnly showcases**:

| Item                               | Status   | Notes                                                                       |
| ---------------------------------- | -------- | --------------------------------------------------------------------------- |
| `SelectLibraryConfigurations` test | ✓ done   | `get_property GLOBAL`, macro, double-expansion `${${basename}_LIBRARY}` — cmake-only-check OK |
| `MajorVersionSelection` test       | blocked  | Requires `find_package` (Tier 3)                                            |
| `CheckSymbolExists` test           | blocked  | Requires C compiler at runtime — not tractable as structural check          |
| `CheckCXXCompilerFlag` test        | blocked  | Requires CXX compiler + `execute_process`                                   |

### Tier 3 — find_package + FetchContent

**Goal**: make yelu usable for real C++ projects with external dependencies.

| Item                         | What to do                                                                                                                   |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `find_package` (basic)       | `find_package(Foo [version] [REQUIRED] [COMPONENTS …])` — covers 90% of usage. Expand stub.                                  |
| `find_package` (config mode) | `find_package(Foo CONFIG)` — needed for cmake-exported packages.                                                             |
| `FetchContent`               | `FetchContent_Declare` + `FetchContent_MakeAvailable`. Pure module calls, no AST nodes needed — add via `apply` + `include`. |
| `AllFindModules` test        | Write yelu equivalent once find_package is covered.                                                                          |

### Tier 4 — Generator expressions

**Goal**: handle `$<…>` expressions that appear in target properties.

| Item                                              | What to do                                                                |
| ------------------------------------------------- | ------------------------------------------------------------------------- |
| `$<CONFIG:…>`                                     | Build-type conditional — most common. Add typed `Yge_config` variant.     |
| `$<TARGET_FILE:tgt>`                              | File path of a target — common in custom commands. Add `Yge_target_file`. |
| `$<INSTALL_INTERFACE:…>` / `$<BUILD_INTERFACE:…>` | Install/build path switching — needed for install rules.                  |
| General `$<…>`                                    | Opaque pass-through via `Ycs_raw` as fallback (already works).            |

### Tier 5 — Explicit variable lifecycle types (research)

**Goal**: make cmake's implicit multi-run state model explicit in yelu's type system,
so both humans and LLMs can reason about what survives a reconfigure vs what is
recomputed fresh.

**Background**: cmake has two fundamentally different write semantics:

| Semantics            | cmake mechanism                            | Analogue                                            |
| -------------------- | ------------------------------------------ | --------------------------------------------------- |
| **Last-write-wins**  | Normal variables (`set(VAR val)`)          | Standard assignment in most languages               |
| **First-write-wins** | Cache variables (`set(VAR val CACHE ...)`) | Make `?=`, NixOS `mkDefault`, Ansible role defaults |

The first-write-wins behavior is documented in `set.rst` as: *"Since cache entries are
meant to provide user-settable values this does not overwrite existing cache entries by
default. Use the `FORCE` option to overwrite existing entries."*  The `option()` docs
state it even more bluntly: *"If `<variable>` is already set, then the command does
nothing."*

cmake also has a priority stack above first-write-wins:
```
-DVAR=val (command line)           highest — sticks across all reconfigures
set(VAR val CACHE ... FORCE)       always overwrites
set(VAR val CACHE ...)             only writes if no cache entry exists yet
                                   ← the "first-write-wins" level
```
Normal variables shadow cache variables locally, adding another layer of confusion.

**Proposed Tier 5 type system** — replace the single `Ycvar` with typed variants:

| cmake concept                | Current yelu | Tier 5 yelu                                                                       |
| ---------------------------- | ------------ | --------------------------------------------------------------------------------- |
| Normal variable              | `Ycvar`      | `Ycvar_normal` — ephemeral, last-write-wins, scope-tracked                        |
| `option()` / `CACHE BOOL`    | `Ycvar`      | `Ycvar_bool` — persistent, first-write-wins, user-overridable                     |
| `CACHE STRING/PATH/FILEPATH` | `Ycvar`      | `Ycvar_string / _path / _filepath` — same, type constrains `-D` input             |
| `CACHE INTERNAL`             | `Ycvar`      | `Ycvar_internal` — persistent, not shown in cmake-gui, implies FORCE              |
| `set(... FORCE)`             | `Ycvar`      | explicit `~force:true` annotation — documents "this intentionally overrides user" |
| `find_library` result        | `Ycvar`      | `Ycvar_path` — makes it obvious why the result is cached across reconfigures      |

**Benefits**: a compile-time error if a `Ycvar_bool` is used where a path is expected;
explicit reasoning about which variables survive a reconfigure; LLMs can correctly
predict "this default will be ignored on re-conf if the user set a value before."

**Research connection**: the first-write-wins vs last-write-wins confusion is a known
LLM failure mode for cmake — models generate `set(VAR val CACHE ...)` expecting it to
always take effect, not realizing the cache already has a user value. A typed yelu
surface makes this class of error statically impossible.

### Tier 6 — Collapse the configure/build boundary (research)

**Goal**: users should think declaratively about *targets*, not about cmake's internal
conf/build staging. The conf/build split is an implementation artifact of cmake, not a
concept a user of a higher-level tool needs to be exposed to.

**Observation**: modern build tools hide this entirely:
- `cargo build` — no separate configure step; Cargo manages incremental state internally
- `bazel build //foo:bar` — hermetic, no configure/build distinction visible to user
- `buck2 build :foo` — same

cmake's split is visible because cmake *generates* a build system (Make, Ninja) as an
intermediate — conf produces `build.ninja`, build runs it. yelu currently inherits this
split because it targets cmake as its backend.

**What Tier 6 looks like**: a yelu execution model where the user declares targets and
yelu manages the full pipeline invisibly:

```
# user writes:
yelu build MathFunctions

# yelu does:
#   1. generate CMakeLists.txt (compile yelu program)
#   2. cmake -S . -B _build (configure)
#   3. cmake --build _build --target MathFunctions (build)
#   with incremental state managed by yelu, not exposed as CMakeCache.txt
```

**Relation to Tier 5**: if yelu owns the state model (Tier 5 typed cache vars), it can
also own the persistence — replacing CMakeCache.txt with its own store. That removes
the first-write-wins confusion entirely: yelu knows what changed in the program and
invalidates the right cache entries, rather than silently ignoring `set()` calls
because a stale entry exists.

**Evolution path** (from design vision):
- Short term: yelu generates cmake text, user runs cmake manually
- Medium term (Tier 6 entry): yelu drives conf+build as a unit via a `yelu build` CLI
- Long term: yelu generates Ninja directly, cmake is no longer in the loop

**Why this matters for LLMs**: a user or LLM writing a yelu program would describe
*what to build*, not *how cmake should be configured*. The cache variable lifecycle
question (Tier 5) becomes an internal implementation detail of yelu's incremental
engine, not something the programmer ever writes down.

### Tier 7 — Multi-stage core: same language across levels (research)

**Goal**: the same language constructs (`let`, `for`, `if`, function application) should
be usable at every level of the compilation pipeline. The difference between levels is
only *when interpretation happens*, not *what the language looks like*.

**Observation from compilation pipelines**: C → asm pipelines have textual
meta-programming at both levels (C preprocessor, asm macros). These tools exist because
the surface languages are different — if the language were unified, a single meta facility
would work across levels. The same pattern appears in `let/loop + high-level primitives`
compiling to `let/loop + low-level primitives`: the structural language is the same; only
the primitive set and its interpreter differ.

**Applied to yelu**: currently there are two distinct constructs for the same concept:

| Concept       | Compile-time (OCaml)    | Configure-time (cmake)   |
| ------------- | ----------------------- | ------------------------ |
| Binding       | `Ylet { var; value }`   | `Ycvar` + `set()`        |
| Iteration     | OCaml `for` loop        | `Yc_foreach`             |
| Conditional   | OCaml `if`              | `Yc_if`                  |
| Function call | OCaml function call     | `Yc_apply` (cmake macro) |

The multi-stage vision unifies these into **one construct per concept** with a staging
annotation that decides which level it executes at:

```
let x = "Tutorial"         -- compile-time: resolved before any cmake emitted
@stage cmake
let y = "libm"             -- configure-time: emitted as set(y "libm")
@stage build
let z = target_file(foo)   -- build-time: $<TARGET_FILE:foo>
```

**Meta-programming follows naturally**: quote/splice across stages gives the same
structural capability as preprocessor + inline macro tools — but typed and composable:

```
-- compile-time: construct a configure-time expression and splice it in
let name = if flag then "Debug" else "Release"
@cmake splice (set_var "BUILD_TYPE" name)
```

**Key property**: a user (or LLM) needs to learn one syntax, one set of constructs.
Staging annotations are explicit and local, not implicit (unlike cmake where `${}`,
`$<>`, and `$ENV{}` silently happen at different evaluation times with no surface
distinction).

**Relation to existing tiers**:
- Tier 5's `Ycvar_bool`/`Ycvar_normal` distinction becomes a *stage annotation* on a
  single `let` form: `@cmake let x = ...` vs `@cmake cache let x = ...`
- Tier 6's conf/build boundary collapse is a consequence: if the language owns staging,
  the conf/build split is an implementation detail of the cmake-pack lowering, not
  something the user writes down
- The cmake-pack provides stage-specific primitives; yelu-core provides the staging
  mechanism itself

**Design questions** (open):
- Is staging syntactic (annotation) or semantic (type-level `Code<T>` as in MetaML)?
- Can stages be user-defined, or are they fixed (compile / configure / build)?
- What is the quotation/splice API? Minimal: `quote : expr → code` + `splice : code → expr`
- Does the core need a tower of three stages (compile → configure → build) or is two
  stages (now vs later) sufficient, composable into towers?

**Not like Lisp**: homoiconicity (code-as-data) is not required. The key property is
*structural uniformity* — the same grammar and constructs at every level. Quote/splice
is a mechanism for crossing levels, not a requirement that all levels share a runtime
representation.

## Language Architecture — Core vs Pack

**Motivation**: as yelu grows beyond cmake, the language-agnostic parts should be
separable from the cmake-specific parts. A user targeting JSON, Nix, or Dockerfile
should reuse the same core and import only the relevant pack.

```
yelu-core                      cmake-pack
──────────────────────         ─────────────────────────────────────
bool, int, string              target, cmake_list, cmake_cvar
list<T>, dict<K,V>             Ycvar_bool / _string / _path / _internal
option<T>, result<T,E>         find_library, find_package
let, if, for, match            foreach (configure-time)
fun, module, import            generator expression $<...>
                               compile_to_cmake : program → cmake_ast
```

The cmake-pack is imported as a module: `import cmake_pack as cmake`. A `yelu-json`
pack would expose a different API — same core language, different primitives and
lowering target.

**Analogy to existing languages**:

| Language       | Core                    | Pack/Library                    |
| -------------- | ----------------------- | ------------------------------- |
| Nix            | nix expression language | nixpkgs (package collection)    |
| OCaml          | core language + Stdlib  | opam libraries                  |
| Haskell        | Prelude + base          | hackage packages                |
| yelu (planned) | yelu-core               | cmake-pack, json-pack, nix-pack |

### Primitive Types — Planned yelu-core Types

These are *compile-time* types (known to yelu before cmake runs). They correspond
to what cmake arguments ultimately carry, but with semantic distinctions cmake
collapses into untyped strings.

| yelu type   | Meaning                             | cmake lowering                          |
| ----------- | ----------------------------------- | --------------------------------------- |
| `bool`      | true/false                          | `ON`/`OFF`                              |
| `int`       | integer                             | bare string                             |
| `string`    | generic string                      | quoted/bare arg                         |
| `file`      | file path                           | quoted arg (cmake expects path)         |
| `dir`       | directory path                      | quoted arg                              |
| `name`      | cmake name (variable, target, test) | bare arg — context determines namespace |
| `list<T>`   | compile-time typed sequence         | `arg list` → unrolled or `"a;b;c"`      |
| `option<T>` | present or absent                   | `Some` → arg, `None` → omitted          |
| `dict<K,V>` | key-value map                       | property pairs, cmake cache             |

**Open questions for yelu-core**:
- Should `list<T>` allow mixed-type lists? (cmake's lists are untyped strings)
- Should `dict` be ordered? cmake property lists are ordered; cmake cache is not.
- Is `dag<T>` needed, or is it a derived type over `list<(T, list<T>)>`?
  cmake's target dependency graph is effectively a DAG — expressing it as a typed
  collection enables static cycle detection (a known cmake footgun).

### Configure-time Types — cmake-pack Additions

These types exist only in the cmake-pack and correspond to entities that survive
compile time and exist at cmake configure time:

| cmake-pack type  | Meaning                                                | Tier                                   |
| ---------------- | ------------------------------------------------------ | -------------------------------------- |
| `target`         | cmake target handle (exe / lib / interface)            | already in yelu as `Ytarget`           |
| `cmake_list`     | cmake Variable holding a `;`-joined list               | Tier 2 — needed for `foreach IN LISTS` |
| `Ycvar_normal`   | last-write-wins normal variable                        | Tier 5                                 |
| `Ycvar_bool`     | option() / CACHE BOOL — first-write-wins               | Tier 5                                 |
| `Ycvar_path`     | CACHE PATH — find_* result, cached across reconfigures | Tier 5                                 |
| `Ycvar_internal` | CACHE INTERNAL — not shown in cmake-gui                | Tier 5                                 |

### Settled Design Decisions (2026-04-14)

These are resolved — do not re-open without new evidence.

**1. Multi-variable iteration (`ZIP_LISTS`) → derived from `zip`**

cmake's `foreach(x y IN ZIP_LISTS l1 l2)` is not a special construct; it is
`zip(l1, l2)` with tuple destructuring in `for`. yelu-core provides:

```
zip : list<A> -> list<B> -> list<(A, B)>

for (x, y) in zip(sources, headers) do ...
```

The cmake-pack lowering targets `Foreach_in` with `ZIP_LISTS`. No new syntax in
yelu-core needed — multi-var iteration is a library function, not a keyword.

**2. Monomorphic typed lists as the first type system**

Full polymorphism (`list<T>` with type variables) is deferred. The first step is
a fixed set of monomorphic list types: `string_list`, `file_list`, `dir_list`,
`target_list`, `name_list`. Each is a distinct type in the compiler; cross-use
(`link_lib [a_file]`) is a type error. Target count: ≤12 cases, one per `yarg`
variant. This is enough to catch the most common cmake namespace confusion mistakes.

**3. FP-flavored core — no `return` keyword in yelu-core**

yelu-core is expression-oriented:
- Every construct (let, if/else, function body) is an expression that produces a value
- Functions return the value of their last expression — no explicit `return`
- `while` is absent from yelu-core (compile-time looping uses OCaml; configure-time
  uses the cmake-pack's `Yc_while`)

`Yc_return`, `Yc_break`, `Yc_continue` are **cmake-pack primitives** — they emit
cmake `return()` / `break()` / `continue()` into the generated CMakeLists.txt.
They are NOT yelu-core control flow. A yelu-core function exits by evaluating to
its last expression; cmake-pack uses `yc_return` when the generated cmake code
needs to return from a cmake function or cmake macro.

Implication: `while` in the core type system is an open question and likely
unnecessary. The interesting control-flow question is whether `for` over a
`list<T>` should be permitted to produce a value (expression) or only emit AST
(statement). The FP direction says: yes, `for` produces `list<U>` (it is `map`),
and side-effecting `for` (emitting cmake nodes) is a special case where `U = unit`.

### From cmake examples to core types — the inductive approach

Each real cmake project we translate through yelu reveals which core types are
missing or which cmake patterns don't have clean yelu equivalents. The current
step1–12 translations already show:

- `list(APPEND VAR items)` → mutating a `cmake_list` (configure-time mutation)
- `foreach(x IN LISTS VAR)` → iterating a `cmake_list` — needs `for x in (cmake_list)`
- `set(VAR val CACHE BOOL "doc")` → `Ycvar_bool` with a doc string
- `if(TARGET x)` → predicate over `target` — already expressible via `Yis_target`

The RunCMake tests (`Tests/RunCMake/<cmd>/`) are the primary source for discovering
what patterns remain unexpressed. Adding more real projects (beyond the tutorial) as
showcase targets will reveal the gaps in core types faster.

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
