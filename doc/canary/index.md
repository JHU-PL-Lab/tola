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

A note lands here when it states a principle for the GENERAL algorithm;
a per-project consequence of one belongs in
[`project/issues.md`](project/issues.md).

**Every design doc declares its KIND on line 3**, because the directory
otherwise cannot tell you whether a paragraph describes the code or
proposes changing it (audit 2026-08-23):

- **reference** — the vocabulary. Not an argument and not a to-do.
- **rationale** — why the built thing works this way. Everything it
  describes exists.
- **proposal** — design for work not done. A proposal also states its
  **falsifier** — the one thing that would be true in the code if it had
  landed — so it can be checked against reality instead of trusted.

Most of the directory is rationale; that is the healthy shape. Open work
belongs to a tracker ([`status.md`](status.md), [`backlog.md`](backlog.md),
[`project/status_project.md`](project/status_project.md)) even when a
design doc explains it at length.

### Reference

| File | Topic |
| ---- | ----- |
| [ssot.md](design/ssot.md) | **Single source of truth for IDs** — the canonical Ar/Sf/Ag/Sc/scenario/action tables bridging manuscript ↔ code |
| [scenario.md](design/scenario.md) | The naming scheme — four senses of "scenario" (scenario / pattern / stage / path pattern) |

### Rationale — how the built thing works

| File | Topic |
| ---- | ----- |
| [index.md](design/index.md) | **The design narrative** (not the doc map): vision, identity & versioning, action graph, spec/scan/compat stages, workflow, design principles |
| [algorithm_explainer.md](design/algorithm_explainer.md) | **How canary works** — the pipeline walkthrough (declaration → catalogue → chains → assignments → execution), the run cache (§9), store pins (§10) |
| [action_playbook.md](design/action_playbook.md) | *How-to*: adding an action, with Publish as the worked example |
| [matrix.md](design/matrix.md) | The result matrix — what a row is and what names it |
| [diagram.md](design/diagram.md) | The diagram pipeline and the design ideas its output implements |
| [tiny.md](design/tiny.md) | Tiny — how the witness works. Carries a stale reframing banner; read it first |
| [mechanism_payload.md](design/mechanism_payload.md) | The typed binding declaration (steps 1–4, 6 landed; step 5 partial) |
| [repo_model.md](design/repo_model.md) | The repo model — the 3-way repos, the channel pair, the fork's separate role. Roadmap A/B/C1–C3 all landed |
| [store_switching.md](design/store_switching.md) | Shared-store version switching — one version per package per switch, the pin as an exclusive LOCK, the three tiers of pin cost. Design A landed; the A-vs-B choice for tier 2/3 is open |
| [wrapper_packages.md](design/wrapper_packages.md) | Wrapper / conf-free packages, the fork layering, prebuilt-shadows-source, the Publish generalization. §3.1 is an open decision brief |
| [staged_parity.md](design/staged_parity.md) | Build tree vs install prefix as a checking principle — completeness, integrity, parity, isolation. §4's four boxes are open |
| [mechanism.md](design/mechanism.md) | The mechanism catalogue (shipped) + the open research direction behind it |
| [versioning.md](design/versioning.md) | Version as artifact identity — what landed (the type, the placement, the provider's version list, the typed source repo) and the one item left |

### Proposal — design for work not done

| File | Falsifier — it landed when … |
| ---- | ---------------------------- |
| [artifact_cache.md](design/artifact_cache.md) | … a step's cache key includes the identity of its INPUT artifacts, not only its own cmd/expectation fingerprint |
| [multi_lib.md](design/multi_lib.md) | … `Canary_basic.artifact_kind.Lib` carries a name, so a project can declare more than one C lib |
| [testing_plan.md](design/testing_plan.md) | … `canary pipeline-test` runs sqlite-thin through the real pipeline and asserts on the verdict table |
| [run_model_revisit.md](design/run_model_revisit.md) | … its ordered change list is worked through; items land individually and are marked in place |
| [agreement_registry_audit.md](design/agreement_registry_audit.md) | … every agreement in the catalogue resolves to a check that can ground it. The producer landed (`surface/canary_contract_registry.ml`); the rungs did not. Absorbed `contract_registry.md` 2026-08-21 |

### Retired

| File | |
| ---- | --- |
| ~~api_surface.md~~ | Theory + implementation pointers folded into `research/surface_draft/`; packaging deferred to a future `package_theory.md` |
| ~~contract_registry.md~~ | Merged into `agreement_registry_audit.md` (2026-08-21) |
| ~~dynamic_enumeration.md~~ | Absorbed into `algorithm_explainer.md` |
| ~~scenario_terms.md~~ | Replaced by `scenario.md` |

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
