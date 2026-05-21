# Canary documentation

Directory map for `doc/canary/`. Files grouped by intent.

**Start with `research/README.md`** for the surface-theory entry
point (theory + `tiny` witness + roadmap, three aligned docs).
`design/index.md` is the older project narrative;
`design/new_project.md` covers the expansion roadmap. See `CLAUDE.md`
(project root) for live status, gaps, and current gotchas.

## design/ — what canary models

The unified design narrative + supporting design docs. Active surface;
updated as the model evolves.

| File                                    | Topic                                                                                                                                                                      |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [index.md](design/index.md)             | Vision, identity & versioning, action graph, spec/scan/compat stages, workflow, design principles                                                                          |
| ~~[api_surface.md](design/api_surface.md)~~ | **Retired.** Theory + implementation pointers folded into [`research/surface_theory.md`](research/surface_theory.md); packaging sections deferred to a future `package_theory.md`. See [`research/README.md`](research/README.md) for the live entry point. |
| [new_project.md](design/new_project.md) | Expansion portfolio (two-tier candidate framework), mechanics for adding a project, auto-generation plan (#29/#30/#32), PyTorch case study                                 |
| [diagram.md](design/diagram.md)         | Diagram improvements plan: summary node fidelity (#36), multi-view per project, HTML viewer (#37)                                                                          |

## surveys/ — background research

Pre-code survey data. Source of truth for `design/new_project.md`
candidate selection and the failure taxonomy now in
`research/surface_theory.md`.

| File                                             | Topic                                                                           |
| ------------------------------------------------ | ------------------------------------------------------------------------------- |
| [opam.md](surveys/opam.md)                       | Survey of 4460 opam packages: pattern A/B/C/D/E classification, revdep rankings |
| [conf_packages.md](surveys/conf_packages.md)     | Classification of all 333 `conf-*` packages by build complexity                 |
| [packaging_study.md](surveys/packaging_study.md) | Older packaging study (pre-rearchitecture)                                      |

## ops/ — operational notes & gotchas

Pre-code summaries and gotchas. Durable. Kept for both human and AI
retrieval to avoid re-discovering the same friction.

| File                                                       | Topic                                                                                         |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| [ci_gh.md](ops/ci_gh.md)                                   | GH Actions backend implementation, Z3 quirks, sccache + opam sandbox                          |
| [llvm_build.md](ops/llvm_build.md)                         | LLVM source build steps, smoke test, opam install notes                                       |
| [install_targets.md](ops/install_targets.md)               | Z3 vs LLVM cmake install patterns                                                             |
| [opam_packaging.md](ops/opam_packaging.md)                 | opam packaging patterns for canary                                                            |
| [python_binding_gotchas.md](ops/python_binding_gotchas.md) | Lessons from sqlite/z3/llvm Python integration (pip env, version axes, deprecated APIs, etc.) |

## Top-level

| File                     | Topic                                             |
| ------------------------ | ------------------------------------------------- |
| [backlog.md](backlog.md) | Lower-priority TODOs (numbered #N like GH issues) |
| [worklog/](worklog/)     | Meeting notes + monthly worklogs                  |
