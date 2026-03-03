# CMake Output Comparison Strategies

When reordering or transforming yelu programs, we need to verify the generated
cmake is semantically equivalent. There are multiple comparison levels:

## Level 0: Source text (what we have now)
- Pretty-print cmake AST, string diff
- Strict: any whitespace or ordering change breaks it
- Good for: regression guard during refactors that shouldn't change output
- Limitation: rejects semantically equivalent cmake with different statement order

## Level 1: AST structural equality
- Compare `Lang_cmake.exp` values using OCaml `[@@deriving equal]`
- Ignores formatting differences
- Still order-sensitive (same AST structure required)
- Good for: comparing after pretty-printer changes

## Level 2: cmake file API (syntactic analysis)
- Run `cmake` with file-based API queries (`codemodel-v2`, `cache-v2`)
- cmake parses CMakeLists.txt and dumps JSON: targets, sources, deps, cache vars
- Deterministic for same inputs + toolchain
- Order-independent for most things (targets are a set, not a list)
- Requires: cmake installed, a valid project structure (sources, toolchain)
- Good for: verifying reordered statements produce same project structure

## Level 3: Build system output (configure-time runtime)
- Actually run cmake configure: `cmake -S . -B build`
- Compare generated Makefiles/ninja.build
- Tests the full cmake evaluation including generator expressions, find_package, etc.
- Heavyweight, platform-dependent, path-dependent
- Good for: end-to-end integration testing

## Level 4: Build + test results
- Build the project and run tests
- Ultimate correctness check
- Extremely heavyweight, requires full toolchain + sources
- Good for: CI validation of real projects

## Known issues

### `@.` in cmake PP resets the formatter
Several command format strings in `lang_cmake_pp.ml` use `@.` (e.g. `If`, `Function`,
`Apply`, `List_append`). In OCaml Format, `@.` calls `pp_print_newline` which **resets
the entire formatter** — closing all open boxes. After that, `Fmt.cut` separators in
`Exp_list` become conditional breaks instead of forced newlines. Short consecutive
commands can end up on the same line.

Workaround (current): `list_br` uses `Stdlib.Format.pp_force_newline` instead of `Fmt.cut`.

Proper fix (TODO): replace all `@.` with `@,` (cut hint) in command printers, so
the outer vbox is never destroyed. Then `list_br` can go back to `Fmt.cut`.

## Current status
- Using Level 0 (string diff) for all yelu compile tests
- Level 2 (file API) is the sweet spot for reordering validation:
  lightweight enough for tests, semantic enough to ignore safe reorderings

## cmake file API usage
```
mkdir -p build/.cmake/api/v1/query
touch build/.cmake/api/v1/query/codemodel-v2
touch build/.cmake/api/v1/query/cache-v2
cmake -S . -B build
# replies appear in build/.cmake/api/v1/reply/
# codemodel JSON: targets, source groups, compile info, link deps
# cache JSON: all cache variables with types and values
```
