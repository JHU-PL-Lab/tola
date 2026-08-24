# Canary documentation — the index

THE doc index for `doc/canary/`: every file, grouped by intent. Adding a
doc means adding its row here — a doc nobody can find from this page is
a doc nobody reads.

**Where to start.** [`research/draft.md`](research/draft.md) is the
manuscript-in-progress and is authoritative for current framing.
[`design/algorithm_explainer.md`](design/algorithm_explainer.md) walks
the pipeline end to end; [`design/ssot.md`](design/ssot.md) is the ID
dictionary bridging manuscript ↔ code;
[`project/projects.md`](project/projects.md) is the project roster.
Live status, gaps and gotchas are in `CLAUDE.md` at the repo root.

**One question per file** is the arrangement this tree aims at, and the
`project/` subtree is where it was worked out (2026-08-21): the roster
says what EXISTS, the tracker says what's NEXT, issues holds per-project
findings, landing holds the how-to. Design *principles* live in
`design/` even when one project provoked them; survey DATA lives in
`surveys/`; anything already fixed is history and lives in `worklog/`.

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

The design narrative + the supporting design notes. Active surface,
updated as the model evolves. A note lands here when it states a
principle for the GENERAL algorithm; a per-project consequence of one
belongs in [`project/issues.md`](project/issues.md).

| File | Topic |
| ---- | ----- |
| [index.md](design/index.md) | **The design narrative** (not this map): vision, identity & versioning, action graph, spec/scan/compat stages, workflow, design principles |
| [ssot.md](design/ssot.md) | **Single source of truth for IDs** — the canonical Ar/Sf/Ag/Sc/scenario/action tables bridging manuscript ↔ code |
| [algorithm_explainer.md](design/algorithm_explainer.md) | **How canary works** — the pipeline walkthrough (declaration → catalogue → chains → assignments → execution), plus the two-engines factoring |
| [scenario.md](design/scenario.md) | Scenario naming & classification; the still-open overloading of "scenario" |
| [matrix.md](design/matrix.md) | The result matrix — what a row is and what names it |
| [versioning.md](design/versioning.md) | Versioning unification — typed `version` as artifact identity across enumeration/store/cache |
| [repo_model.md](design/repo_model.md) | The repo model — requirements for the 3-way repos in a project spec; the channel pair |
| [multi_lib.md](design/multi_lib.md) | Enumerating a project's DEPENDENCIES — more than one C lib, and the Vendored-prebuilt route |
| [store_switching.md](design/store_switching.md) | Shared-store version switching — one version per package per switch, the pin-as-lock, the three tiers of pin cost |
| [wrapper_packages.md](design/wrapper_packages.md) | Wrapper / conf-free packages, the fork layering, prebuilt-shadows-source, the Publish generalization |
| [mechanism.md](design/mechanism.md) | Mechanism as a first-class object — the catalogue + the research question |
| [mechanism_payload.md](design/mechanism_payload.md) | Mechanism payload — the typed binding declaration |
| [agreement_registry_audit.md](design/agreement_registry_audit.md) | The tool-grounded agreement catalogue (absorbed `contract_registry.md` 2026-08-21) — what each check can actually ground |
| [artifact_cache.md](design/artifact_cache.md) | The artifact cache — keying on what was MADE (identity + input identity) so a new action doesn't force rebuilds |
| [staged_parity.md](design/staged_parity.md) | Build tree vs install prefix as a checking principle — completeness, integrity, parity, isolation |
| [action_playbook.md](design/action_playbook.md) | How an action flows through canary, with the Publish case study |
| [run_model_revisit.md](design/run_model_revisit.md) | What the 2026-08-20 reruns taught the model — `·` is not a neutral cell; cost is an unnamed scenario property; two caches agreed about a wrong artifact |
| [testing_plan.md](design/testing_plan.md) | Testing plan — the general structure and the algorithm's own behavior |
| [tiny.md](design/tiny.md) | Tiny — how the witness works today and how we want it to work |
| [diagram.md](design/diagram.md) | Diagram pipeline + design ideas as built (multi-view per project, HTML viewer); hardening tracked as #37 |
| ~~[api_surface.md](design/api_surface.md)~~ | **Retired.** Theory + implementation pointers folded into `research/surface_draft/`; packaging deferred to a future `package_theory.md` |

## project/ — live projects, their status, and how to land one

Five files, one question each. The layer's home since the 2026-08-12
reorganization; shrunk to this shape 2026-08-21, when `index.md` +
`coverage.md` merged into `projects.md`, `store_switching.md` and
`wrapper_packages.md` moved to `design/` (design principles, not project
records) and `conf_survey.md` moved to `surveys/` as `conf_mechanism.md`.

| File                                           | Topic                                                                                                     |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| [projects.md](project/projects.md)             | **The roster** — the dimension model, per-project coverage + 2×2 status, landing history, candidate portfolio |
| [status_project.md](project/status_project.md) | **THE to-do tracker** for this layer — the ordered plan, general to-dos, the mismatch-matrix report milestone |
| [issues.md](project/issues.md)                 | OPEN per-project issues — a standalone worklist (unresolved findings, declaration gaps, per-project chores)   |
| [landing.md](project/landing.md)               | **How to land a project** — workflow, data structures, testing harness (the future skill's base)             |
| [project_pytorch.md](project/project_pytorch.md) | PyTorch multi-PM case study — pre-implementation plan for candidate #4                                     |

Landing a project also reaches into `surveys/` (which library, which
version pair) and `design/` (store_switching for the pin cost,
wrapper_packages for a conf-free package, multi_lib for a second C lib)
— see those tables above.

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

## Top-level and the rest

| File / dir | Topic |
| ---------- | ----- |
| [status.md](status.md) | **Framework status** — current state, the M2 milestone, open items. Project-level status is `project/status_project.md` |
| [backlog.md](backlog.md) | Lower-priority TODOs, numbered `#N` like GH issues |
| [worklog/](worklog/) | The chronicle: monthly worklogs + meeting notes. Anything FIXED moves here — a closed item is history, not status |
| [raw/](raw/) | Survey raw data + the scripts that regenerate it (`.tsv`, `.sh`, `.py`) — the evidence behind `surveys/` |
| [reference/](reference/) | Outside material kept verbatim for reference |
