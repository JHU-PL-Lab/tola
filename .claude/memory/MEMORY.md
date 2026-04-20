# Tola Project Memory

Detailed notes: `yelu-vision.md`, `cmake.md`, `string-target-design.md`, `yelu_lang_decisions.md`

## Quick Reference
- **Main research**: Package management (PL perspective) + canary testing
- **yelu-lang**: programmable config shell language; compiles to cmake (and future targets)
- CMake AST: `src/langs/cmake/lang_cmake.ml`, PP: `lang_cmake_pp.ml`, Utils: `lang_cmake_utils.ml`
- Yelu AST: `src/langs/yelu/lang_yelu.ml`, Compile: `lang_yelu_compile.ml`, Utils: `lang_yelu_utils.ml`
- Build cmake only: `dune build src/langs/ src/bin/cmake/`
- Build yelu only: `dune build src/langs/ src/bin/yelu/`
- `open Base` shadows `result`, `prefix`, `id`, `append` — rename in patterns
- "cc" = Claude Code; remind user before touching code outside cmake dirs

## Yelu Type System
- `yelu_cvar` / `Ycvar` = cmake runtime variable (erases to cmake set/${})
- `yelu_target` / `Ytarget` = cmake target name
- `yelu_var` / `Yvar` = yelu compile-time variable, resolved during compilation
- `Ylet` = compile-time binding, immutable single-assignment
- `yarg` = unified arg type with semantic string variants: `Yarg_file`, `Yarg_dir`, `Yarg_str`
- See `string-target-design.md` for cmake string/target internals + yc_string proposal

## yelu Language Design (settled)
- [Core design decisions](yelu_lang_decisions.md) — FP flavor, monomorphic typed lists, zip not ZIP_LISTS

## Feedback
- [No eval $(opam env)](feedback_shell_env.md) — dune/opam already on PATH in CC env
- [dune sandbox + promote](feedback_dune_sandbox.md) — alias deps force build order but don't expose files in sandbox; use glob_files + promote instead

## User Preferences
- "cc" means Claude Code (this CLI tool)
- When working on cmake scope, remind user before touching code outside cmake dirs
- User reads Chinese; project comments may reference Chinese terms
