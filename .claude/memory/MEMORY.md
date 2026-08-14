# Tola Project Memory

## Canary CI
- [GH CI backend — all 3 jobs green](project_canary_ci.md) — Z3/SQLite/LLVM passing; Z3 uses opam remote fetch (~33 min); debug.yml for fast iteration (~2 min)

## Gotchas
- [CAML_LD_LIBRARY_PATH shadows fresh dlls](gotcha_caml_ld_shadow.md) — bytecode dll search beats -dllpath; opam stublibs can fake an "upstream break" (z3 2026-08-13); env_guard on ninja_build_binding

## Quick Reference
- **Main research**: Package management (PL perspective) + canary testing
- `open Base` shadows `result`, `prefix`, `id`, `append` — rename in patterns
- "cc" = Claude Code

## Feedback
- [No eval $(opam env)](feedback_shell_env.md) — dune/opam already on PATH in CC env
- [dune sandbox + promote](feedback_dune_sandbox.md) — alias deps force build order but don't expose files in sandbox; use glob_files + promote instead
- [Latin letters not Greek](feedback_option_letters.md) — use a/b/c/d or 1/2/3/4 for option lists
- [Protect contrib/ build caches](feedback_protect_contrib_cache.md) — never rm -rf contrib/* (heavy z3/llvm builds)

## User Preferences
- "cc" means Claude Code (this CLI tool)
- User reads Chinese; project comments may reference Chinese terms
- **Yelu is now standalone** at `/home/red/code/research/yelu` — extracted 2026-05-04
