# Canary documentation

Directory map for `doc/canary/`. Files grouped by intent.

**Start with [`research/draft.md`](research/draft.md)** for the
confirmed-content writeup-in-progress (manuscript), or
[`research/tiny.md`](research/tiny.md) to read alongside the code.
[`research/surface_draft/`](research/surface_draft/) is the older
materials collection (split across `main.md`, `surface.md`,
`principle.md`, `implementation.md`, `package.md`,
`versioning.md`) — mine for content, but `surface.md` (the
manuscript) is authoritative for current framing.
`design/index.md` is the older project narrative;
`project/projects.md` is the project roster — coverage, landing
history and the candidate portfolio. See
`CLAUDE.md` (project root) for live status, gaps, and current
gotchas.

## research/ — surface theory, tiny witness, plan

The work is organised around four aligned views of the same problem:

| #   | Pillar       | Question it answers                                                                          | Lives in                                                      |
| --- | ------------ | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| 1   | **Theory**   | What are the surfaces, contracts, and what counts as a violation?                            | [`draft.md`](research/draft.md) §1 + materials in `surface_draft/` |
| 2   | **Witness**  | Is there a minimal artifact that instantiates every surface and every contract reproducibly? | [`tiny.md`](research/tiny.md)                                          |
| 3   | **Coverage** | Which contracts does canary check, with which inspector + comparator?                        | [`surface_draft/implementation.md`](research/surface_draft/implementation.md) §2.7 |
| 4   | **Plan**     | What changes — to canary, to tiny, to docs — close the remaining coverage gaps?              | [`plan.md`](research/plan.md)                                          |

The alignment is *load-bearing*: every contract named in Theory
appears in Witness as at least one scenario, in Coverage as a row
in the inspector/comparator tables, and in Plan as a step toward
closing its gap.

| File                                                  | Topic                                                                                                                                                                                                                |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [draft.md](research/draft.md)                     | **Manuscript-in-progress.** Confirmed-content writeup; five-part spine (BB / SS / TT / CC / MM). Backbone framing (**rules / traces / worlds**), PL notation, implementation slots. The authoritative current framing.                                                                                                       |
| [surface_draft/](research/surface_draft/)             | **Materials collection** (split 2026-06-04). `main.md` (header + §5 related work + §6 calculus + appendix); `surface.md` (Parts A, B, §2.4 contracts, §4 hidden deps); `principle.md` (P1–P6); `implementation.md` (§2.7 + §2.5 + §2.6); `package.md` (§3); `versioning.md` (§2.8). Mine for content; not authoritative.       |
| [tiny.md](research/tiny.md)                           | Witness. Minimal C lib + 3 bindings + downstream helper; 13-variant matrix exercising every active contract. The doc to read alongside the code.                                                                     |
| [plan.md](research/plan.md)                           | Venues + milestones + roadmap. OOPSLA primary; PLDI / POPL optional. Open `[ ]` items only; chronicled work lives in `worklog/`.                                                                                     |
| [literature.md](research/literature.md)               | Companion bibliography. Compiler correctness, type-preserving compilation, linking calculi, ELF semantics, FFI semantics, ABI tooling — each entry with an "Inherits / Departs" note tying it back to surface theory. |

Packaging lives in [`surface_draft/package.md`](research/surface_draft/package.md)
in the materials collection; the manuscript covers it in §4.2.

## design/ — what canary models

The unified design narrative + supporting design docs. Active surface;
updated as the model evolves.

| File                                    | Topic                                                                                                                                                                      |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [index.md](design/index.md)             | Vision, identity & versioning, action graph, spec/scan/compat stages, workflow, design principles                                                                          |
| ~~[api_surface.md](design/api_surface.md)~~ | **Retired.** Theory + implementation pointers folded into the surface theory materials at [`research/surface_draft/`](research/surface_draft/); packaging sections deferred to a future `package_theory.md`.       |
| [diagram.md](design/diagram.md)         | Diagram pipeline + design ideas as built (multi-view per project, HTML viewer); remaining hardening tracked as #37                                                         |

## project/ — live projects, their status, and how to land one

The project layer's home since the 2026-08-12 reorganization (was the
top-level `projects.md` + `design/package_bug.md`). Shrunk 2026-08-21 to
five files: `index.md` + `coverage.md` merged into `projects.md`;
`store_switching.md` and `wrapper_packages.md` moved to `design/`
(they are design principles for the general algorithm); `conf_survey.md`
moved to `surveys/` as `conf_mechanism.md`.

| File                                           | Topic                                                                                                     |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| [projects.md](project/projects.md)             | **The roster** — the dimension model, per-project coverage + 2×2 status, landing history, candidate portfolio |
| [status_project.md](project/status_project.md) | **THE to-do tracker** for this layer — the ordered plan, general to-dos, the mismatch-matrix report milestone |
| [issues.md](project/issues.md)                 | OPEN per-project issues — a standalone worklist (unresolved findings, declaration gaps, per-project chores)   |
| [landing.md](project/landing.md)               | **How to land a project** — workflow, data structures, testing harness (the future skill's base)             |
| [project_pytorch.md](project/project_pytorch.md) | PyTorch multi-PM case study — pre-implementation plan for candidate #4                                     |

Read alongside: [surveys/conda_forge.md](surveys/conda_forge.md)
(the prebuilt-binary channel, with measured dependency closures),
[design/store_switching.md](design/store_switching.md) (shared-store
version switching), [design/wrapper_packages.md](design/wrapper_packages.md)
(conf-free wrapper packages), [design/multi_lib.md](design/multi_lib.md),
[design/artifact_cache.md](design/artifact_cache.md) and
[design/run_model_revisit.md](design/run_model_revisit.md).

## surveys/ — background research

Pre-code survey data. Source of truth for `project/projects.md` §4
candidate selection and the failure taxonomy now in
`research/draft.md` (and materials in `research/surface_draft/`).

| File                                             | Topic                                                                           |
| ------------------------------------------------ | ------------------------------------------------------------------------------- |
| [opam.md](surveys/opam.md)                       | Survey of 4460 opam packages: pattern A/B/C/D/E classification, revdep rankings |
| [conf_packages.md](surveys/conf_packages.md)     | Classification of all 333 `conf-*` packages by build complexity; §G is the MEASURED landing ranking |
| [conf_mechanism.md](surveys/conf_mechanism.md)   | How a `conf-*` package works (the live `conf-gmp.5`) + the position that opam should drop them |
| [conda_forge.md](surveys/conda_forge.md)         | conda-forge as a prebuilt-binary channel — feature/issue/experience + measured dependency closures |
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
| [backlog.md](backlog.md) | Lower-priority TODOs (numbered #N like GH issues)  |
| [worklog/](worklog/)     | Meeting notes + monthly worklogs                   |
