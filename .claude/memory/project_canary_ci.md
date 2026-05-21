---
name: Canary GH CI backend — milestone
description: GH Actions CI for canary is working end-to-end (all 3 jobs green as of 2026-04-22)
type: project
---

Canary GH CI backend is fully working as of 2026-04-22 (run 24755992835).

All three jobs pass:
- SQLite: system lib + opam binding + probe (~2 min)
- LLVM 19: system lib + opam binding + probe_binding (expected failure, verified) + probe_app (~5 min)
- Z3 dev: opam fetches from GitHub remote, builds OCaml binding, probe_binding (~33 min)

**Key design decisions:**
- Z3 uses opam to fetch+build from remote (no cmake steps in CI); pack_binding flow via opam.in
- LLVM/SQLite use no_source (system lib + opam binding only)
- probe_binding_build skipped in CI when cmake_build_binding=false (no local build tree)
- install_env omitted when opam fetches remote (let opam use S=./B=build defaults)
- z3_cmake_build_flags list in canary_project_z3.ml is single source of truth; opam.in generated from opam.in.tpl

**Performance tooling added:**
- sccache-action preamble step for Z3 (compiler cache via GH Actions cache)
- mold added to Z3 sys_deps (faster linker)

**debug.yml:** workflow_dispatch-only, SQLite only (~2 min), for fast CI iteration.

**How to apply:** CI is stable; future work can add new projects or probe variants without re-debugging the opam flow.
