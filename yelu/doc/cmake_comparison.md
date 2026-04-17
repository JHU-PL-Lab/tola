# CMake Output Comparison: Pipeline, Tooling, and Test Coverage

When generating or transforming CMake from yelu programs, we need to verify
correctness at multiple levels of rigor — from exact text identity to full
build equivalence. This document covers the comparison levels, which ones apply
to each test category, current tooling, and active status.

---

## Comparison levels

The pipeline mirrors a C-with-macros model: cmake's configure-time language is
the "macro" layer, and the build system is the "C runtime" layer.

### src — Source text

- Pretty-print cmake AST → string diff (gersemi-normalized or Alcotest match)
- **Strict**: any whitespace or statement-order change fails
- Good for: regression guard during refactors; bootstrapping new command coverage
- Limitation: rejects semantically equivalent cmake with different statement order

### ast — AST structural equality

- Compare `Lang_cmake.exp` values via OCaml `[@@deriving equal]`
- Ignores formatting differences; still order-sensitive
- Good for: isolating pretty-printer changes from semantic changes
- *Not currently active — internal development tool only*

### conf-run — Configure execution output

- Run `cmake -P script.cmake` (script mode) or `cmake -S . -B build` (project mode)
- Compare stdout/stderr against expected output
- Semantically stronger than `src`: two different cmake texts that produce the
  same output both pass
- Applicable to scripting tests (`cmake -P`) and project configure (`cmake -S -B`)
- RunCMake's own `-stdout.txt` / `-stderr.txt` files are the ground truth for
  the scripting case

### conf-cache — Configure structured output

- Run cmake configure, read file API replies (`codemodel-v2`, `cache-v2`)
- cmake dumps JSON: targets, sources, deps, compile flags, cache variables
- Mostly order-independent (targets are a set, not a list)
- **Key limitation**: captures only one concrete configure run — dead branches pruned
- Only applicable when the project has targets (`add_executable` / `add_library`)
- Good for: verifying reordered statements produce the same project structure

### build — Build artifacts

- Run `cmake --build build` after configure
- Compare artifact sets, check ELF/ar magic bytes
- Tests the full cmake evaluation including generator expressions, `find_package`
- Heavyweight, platform-dependent, path-dependent

---

## Decision matrix: which levels apply where

| Test type | src | conf-run | conf-cache | build |
|---|---|---|---|---|
| **Unit tests** (Alcotest, no cmake) | ✓ active | — | — | — |
| **CMakeOnly showcases** (compile-time, no targets) | ✓ active | — | ✗ N/A | ✗ N/A |
| **RunCMake scripting** (planned) | ✓ active | ✓ planned | ✗ N/A | ✗ N/A |
| **Tutorial steps** (have targets, sources) | ✓ active | ✓ active | ✓ active | ✓ active |

**Why conf-cache and build don't apply to scripting-only tests:**
`conf-cache` (`codemodel-v2`) is a target graph query — it only has content when
`add_executable` / `add_library` commands exist. Pure scripting tests (variable
manipulation, string ops, list ops, `foreach`, `find_library`) produce no targets
and no meaningful codemodel. Without targets there is nothing to build either.

**Why conf-run is the right level for RunCMake scripting tests:**
The RunCMake positive test scripts are small cmake programs that call `message()`
to report results. Running `cmake -P` on the yelu-generated equivalent and
comparing stdout is both sufficient (semantic validation) and cheap (no project
structure needed). Unlike `src`, conf-run tolerates safely reordered statements.

**Why conf-cache is valuable for full projects:**
For steps with targets, `conf-cache` confirms target names, source lists, include
directories, compile flags, and link dependencies are equivalent regardless of
cmake statement order — the best semantic check short of a full build.

---

## Current status

### Active

- **src — cmake-only-check**: `make cmake-check` — gersemi-normalizes each step pair
  and diffs. 24 step pairs, all passing. Also used for CMakeOnly showcases (8 active).
- **src — unit tests**: Alcotest string matching in `dune test yelu/`. Currently
  **82 tests**: cmake PP tests + yelu compile tests across list, string, foreach,
  while, install, export, find_* commands.
- **conf-run — tutorial steps**: cmake configure stdout checked as part of step
  validation.
- **conf-cache — file API**: `make file-api-test` — `run_file_api.py` assembles
  fixture dirs, runs cmake configure, diffs `codemodel-v2` JSON via
  `cmake_file_api_cmp.py`. **Note**: strip `"id"` fields (content hashes that
  differ even for identical cmake text).
- **build — artifact check**: `make build-check` — `run_build_check.py` builds
  both sides, compares artifact sets, checks ELF/ar magic bytes.

### Planned

- **conf-run — RunCMake scripting tests**: Alcotest-style, organized per command
  directory. For each positive RunCMake `.cmake` script: write the yelu equivalent,
  compile to cmake, run `cmake -P`, assert stdout matches. Target dirs: `foreach`,
  `while`, `list`, `string`, `set`, `math`, `find_library`, `find_path`, `find_file`,
  `find_program`, `message`, `include`, `block` (~13 dirs). See
  `doc/language_coverage.md` directory index for the full filter analysis.

---

## Testcase categories

### 1. Unit tests (`yelu/test/`)

OCaml Alcotest tests that exercise the cmake PP and yelu compile pipeline without
running cmake. Each test: write a yelu (or cmake AST) expression, compile/print it,
Alcotest.check `string` against a hardcoded expected string. Comparison level: `src`.

Organized by command group:
- `test_cmake_pp.ml` — cmake AST → text (54 tests)
- `test_yelu_compile.ml` — yelu AST → cmake text (28 tests, covering all list/string
  subcommands, foreach, while, find_*, install, export, ...)

Coverage: every yelu AST node has at least one Alcotest test case.

### 2. CMakeOnly showcases (`yelu/src/bin/yelu/step*.ml`)

Step files that define yelu programs, compile them to CMakeLists.txt, and compare
against a reference cmake step file (`yelu/src/bin/cmake/step*.ml`). These cover
the cmake tutorial (steps 1–12) plus language feature showcases (LinkInterfaceLoop,
TargetScope, SelectLibraryConfigurations, ...).

The `cmake-only-check` target in the Makefile runs gersemi on both sides and diffs
(`src` level). Tutorial steps additionally run `conf-run`, `conf-cache`, and `build`.

### 3. RunCMake benchmark (planned)

cmake's official `Tests/RunCMake/` directory contains ~431 command-specific test dirs.
Most are error-case tests (have `-result.txt` / `-stderr.txt`); positive tests have no
result file counterpart. For our purposes we use the positive test `.cmake` scripts
as reference programs.

Test structure: one Alcotest test module per command directory (e.g., `test_list.ml`,
`test_string.ml`). Each test: write the yelu equivalent, compile to cmake text, run
`cmake -P`, assert stdout matches the RunCMake expected output (`conf-run` level).

Filter constraints (see directory index in `language_coverage.md`):
- `—` no constraint (directly tractable)
- `CMP*` cmake policy tests — tractable, no compiler
- `env` PATH/env search tests — tractable on matching environment
- `compiler` requires C/C++ toolchain — defer
- `platform` Windows/macOS-specific — skip
- `fp` requires `find_package` — defer (Tier 3)

---

## conf-cache: file API usage recipe

```
mkdir -p build/.cmake/api/v1/query
touch build/.cmake/api/v1/query/codemodel-v2
touch build/.cmake/api/v1/query/cache-v2
cmake -S . -B build
# replies appear in build/.cmake/api/v1/reply/
# codemodel JSON: targets, source groups, compile info, link deps
# cache JSON: all cache variables with types and values
```

Key pitfall: `"id"` fields in codemodel replies are content hashes derived from
the build directory path. Strip them before diffing — they differ even when the
two cmake programs are textually identical.

---

## Known issues

### `@.` in cmake PP resets the formatter

Several command format strings in `lang_cmake_pp.ml` use `@.` (e.g., `If`, `Function`,
`Apply`, `List_append`). In OCaml Format, `@.` calls `pp_print_newline` which **resets
the entire formatter** — closing all open boxes. After that, `Fmt.cut` separators in
`Exp_list` become conditional breaks instead of forced newlines. Short consecutive
commands can end up on the same line.

Workaround (current): `list_br` uses `Stdlib.Format.pp_force_newline` instead of
`Fmt.cut`.

Proper fix (TODO): replace all `@.` with `@,` (cut hint) in command printers, so the
outer vbox is never destroyed. Then `list_br` can go back to `Fmt.cut`.
