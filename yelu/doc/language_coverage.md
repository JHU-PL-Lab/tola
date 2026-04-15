# Yelu Language Coverage Plan

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
| `set_property`                             | ✓         | ✓     | ✓        | —           |
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
| `list` (full: 16 sub-commands)             | ✓         | ✓     | ✓        | PP + Y      |
| `string` (full: 20 sub-commands)           | ✓         | ✓     | ✓        | PP + Y      |
| **Scripting — AST only, no utils/yelu**    |           |       |          |             |
| `cmake_policy`                             | ~         | —     | —        | —           |
| `target_link_options`                      | ✓         | —     | —        | —           |
| `target_sources`                           | ✓         | —     | —        | —           |
| `target_precompile_headers`                | ✓         | —     | —        | —           |
| `add_custom_target`                        | ✓         | —     | —        | —           |
| `add_dependencies`                         | ✓         | —     | —        | —           |
| `variable_watch`                           | ✓         | —     | —        | PP partial  |
| `separate_arguments`                       | ✓         | —     | —        | —           |
| `get_property` / `define_property`         | ✓         | —     | —        | —           |
| `include_guard`                            | ✓         | —     | —        | —           |
| `get_filename_component`                   | ✓         | —     | —        | —           |
| **Tier 3 — stubs or absent**               |           |       |          |             |
| `find_package`                             | stub      | —     | —        | —           |
| `execute_process`                          | stub      | —     | —        | —           |
| `file` (READ/WRITE/GLOB/…)                 | stub      | —     | —        | —           |
| `try_compile` / `try_run`                  | stub      | —     | —        | —           |
| `FetchContent`                             | —         | —     | —        | —           |
| Generator expressions `$<…>`               | —         | —     | —        | —           |
| `cmake_pkg_config` (4.x)                   | —         | —     | —        | —           |

## cmake Test Suite Taxonomy

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

| Test                                         | Commands needed                     | Tractable  |
| -------------------------------------------- | ----------------------------------- | ---------- |
| `find_library`                               | `find_library`, `message`           | **Tier 1** |
| `find_path`                                  | `find_path`, `message`              | **Tier 1** |
| `TargetScope`                                | `target_link_libraries` scope modes | **Tier 1** |
| `LinkInterfaceLoop`                          | `target_link_libraries` circular    | **Tier 1** |
| `SelectLibraryConfigurations`                | `list(GET)`, module include         | Tier 2     |
| `MajorVersionSelection`                      | `if`, `string(REGEX)`               | Tier 2     |
| `CheckSymbolExists` / `CheckCXXCompilerFlag` | `include`, check modules            | Tier 2     |
| `ProjectInclude*`                            | `cmake_language` meta               | Tier 3     |
| `AllFindModules`                             | full `find_package`                 | Tier 3     |

## RunCMake Tests — Coverage Benchmark

`Tests/RunCMake/<command>/` — one directory per command, each `.cmake` script
exercises one behavior. All use `project(${RunCMake_TEST} NONE)`. Tractability
mirrors our tier plan. Listed by tier:

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
| `list`                   | LENGTH, GET, APPEND, REMOVE_*, INSERT, SORT, REVERSE, FIND, JOIN, FILTER, SUBLIST         | ✓ (full pipeline: cmake AST + utils + yelu + tests) |
| `string`                 | REGEX, REPLACE, LENGTH, SUBSTRING, UPPER/LOWER, STRIP, FIND, CONCAT, JOIN, HEX, CONFIGURE | ✓ (full pipeline)                                   |
| `foreach`                | IN LISTS/ITEMS/RANGE, ZIP_LISTS, multiple iter vars                                       | ✓ (full pipeline; ZIP_LISTS via `zip` library fn)   |
| `while`                  | while/break/continue                                                                      | ✓ (full pipeline)                                   |
| `return`                 | `return()`, `PROPAGATE`                                                                   | ✓ (full pipeline)                                   |
| `separate_arguments`     | UNIX/WINDOWS/NATIVE_COMMAND                                                               | ✓ AST only                                |
| `include_guard`          | DIRECTORY, GLOBAL                                                                         | absent                                    |
| `get_filename_component` | DIR, NAME, EXT, NAME_WE, REALPATH                                                         | absent                                    |
| `target_link_options`    | scope, BEFORE, LINKER: prefix                                                             | ✓ AST only                                |
| `target_sources`         | FILE_SET HEADERS, PRIVATE/PUBLIC                                                          | ✓ AST only                                |
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
| `TargetScope` test  | TODO   | Write yelu equivalent of `Tests/CMakeOnly/TargetScope/`                   |
| `find_library` test | TODO   | Write yelu equivalent, validate with File API                             |
| `find_path` test    | TODO   | Write yelu equivalent, validate with File API                             |

### Tier 2 — List/string ops + foreach + Check modules ✓ (full pipeline done)

**Goal**: cover the remaining pure-scripting language features needed by real projects.

**Done** (cmake AST + utils + yelu AST + compile + tests):

| Item                                      | Status | What was done                                                                     |
| ----------------------------------------- | ------ | --------------------------------------------------------------------------------- |
| `foreach` (all 3 forms)                   | ✓ done | `commands` body field added; utils + yelu AST + compile + 6 yelu tests            |
| `list` (16 sub-commands)                  | ✓ done | `List_cmd of list_cmd`; full utils + yelu AST + compile + 7 yelu tests            |
| `string` (20 sub-commands)                | ✓ done | `String_cmd of string_cmd`; full utils + yelu AST + compile + 8 yelu tests        |
| `while` / `break` / `continue` / `return` | ✓ done | utils + yelu AST + compile + 5 yelu tests (return PROPAGATE uses list_sp newline) |

**Remaining showcase tests** (language covered, no yelu programs written yet):

| Item                               | What to do                                                          |
| ---------------------------------- | ------------------------------------------------------------------- |
| `SelectLibraryConfigurations` test | Write yelu equivalent (uses `list(GET)` + conditional)              |
| `MajorVersionSelection` test       | Write yelu equivalent (uses `string(REGEX)`)                        |
| Check module tests                 | `CheckSymbolExists`, `CheckCXXCompilerFlag` via `apply` + `include` |

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
