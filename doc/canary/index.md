# Canary documentation — the index

THE doc index for `doc/canary/`: every file, grouped by intent. Adding a
doc means adding its row here — a doc nobody can find from this page is
a doc nobody reads.

**Where to start.** [`research/draft.md`](research/draft.md) is the
manuscript-in-progress and is authoritative for current framing.
[`design/enumeration/README.md`](design/enumeration/README.md) walks
the pipeline end to end; the vocabulary lives in
[`design/enumeration/stage0_naming.md`](design/enumeration/stage0_naming.md);
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
| 2   | **Witness**  | Is there a minimal artifact that instantiates every surface and every contract reproducibly? | [`tiny.md`](research/surface_draft/tiny.md)                                          |
| 3   | **Coverage** | Which contracts does canary check, with which inspector + comparator?                        | [`surface_draft/implementation.md`](research/surface_draft/implementation.md) §2.7 |
| 4   | **Plan**     | What changes — to canary, to tiny, to docs — close the remaining coverage gaps?              | [`plan.md`](plan.md)                                          |

The alignment is *load-bearing*: every contract named in Theory
appears in Witness as at least one scenario, in Coverage as a row
in the inspector/comparator tables, and in Plan as a step toward
closing its gap.

| File                                                  | Topic                                                                                                                                                                                                                |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [draft.md](research/draft.md)                     | **Manuscript-in-progress.** Confirmed-content writeup; five-part spine (BB / SS / TT / CC / MM). Backbone framing (**rules / traces / worlds**), PL notation, implementation slots. The authoritative current framing.                                                                                                       |
| [draft_commemt.md](research/draft_commemt.md) | Holding material moved out of the working manuscript. Grammar suggestions were absorbed and their companion file removed. |
| [surface_draft/](research/surface_draft/)             | **Materials collection** (split 2026-06-04; roster refreshed 2026-08-27). `surface.md` (theory primitives, syntactic/semantic, the gap); `surface_why.md` (what tools check, descriptive-not-prescriptive); `principle.md` (P1–P6); `versioning.md` (intrinsic vs extrinsic); `hidden_dep.md` (undeclared NEEDED, glibc/musl); `package.md` (provider matrix, co-providers); `on_agreement_contract_boundary.md` (why *agreement*; boundary ≠ surface); `notation.md` + `future_impl.md` (parked PL scaffold + typed calculus); `implementation.md` (§2.7 inspector coverage); `ids.md` (the retired ssot's tables); `tiny.md` (the witness). Mine for content; not authoritative. Fates per file are recorded in `draft.md`'s header |
| [tiny.md](research/surface_draft/tiny.md)                           | Witness. Minimal C lib + 3 bindings + downstream helper; 13-variant matrix exercising every active contract. The doc to read alongside the code.                                                                     |
| [plan.md](plan.md)                           | Venues + milestones + roadmap, and **§4 the delivery pipeline** (theory → checker → world → finding → merged PR, with a status and an owner per stage). OOPSLA primary, PLDI optional; POPL purged 2026-08-26. Open `[ ]` items only; chronicled work lives in `worklog/`. |
| [literature.md](research/related/literature.md)               | Companion bibliography. Compiler correctness, type-preserving compilation, linking calculi, ELF semantics, FFI semantics, ABI tooling — each entry with an "Inherits / Departs" note tying it back to surface theory. |

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

### enumeration/ — how scenarios are produced

The biggest cluster, given its own subdirectory 2026-08-23 because nine
docs all described the enumeration from the *occasion* that produced
them rather than from a *stage* of the pipeline. **Start at
[enumeration/README.md](design/enumeration/README.md)** — the stage map:
stage → the types → the functions → the pins that guard it. Being
consolidated into one standalone doc per stage, gradually; stage 1 is
done.

| File | Stage / topic |
| ---- | ------------- |
| [README.md](design/enumeration/README.md) | **The stage map.** Read first; also records the known drift (two dependency relations; mechanism/app-wiring are not config axes) |
| [stage0_naming.md](design/enumeration/stage0_naming.md) | **Stage 0** — the four senses of "scenario", the canonical naming scheme, short names, fault tags, the agreement catalogue |
| [stage1_declare_spec.md](design/enumeration/stage1_declare_spec.md) | **Pass 1, declare** — what a project declares: rows, artifact identity, the provision × version universe, providers and what is derived from them, versions, repo lifecycle, the channel pair, what cannot be declared |
| [stage2_analyse_spec.md](design/enumeration/stage2_analyse_spec.md) | **Pass 2, analyse** — what canary DERIVES from a spec before any world: the chains it admits, the mechanism each language binds through, which claims it can carry. The membership rule is the absence of a world (applicability is here, firing is at realize) |
| [stage3_enumerate_worlds.md](design/enumeration/stage3_enumerate_worlds.md) | **Pass 3, enumerate** — the product and the five constraints that prune it, with the over-generation each was written against. Ends with *Attribution*, the `--why` per-candidate-ledger **proposal** (absorbed from `why_ledger.md`) |
| [stage4_select_worlds.md](design/enumeration/stage4_select_worlds.md) | **Pass 4, select** — what a RUN asked for. Settles where config/policy sit: model constraints, SELECTION, and run configuration are three different things |
| [stage5_order_worlds.md](design/enumeration/stage5_order_worlds.md) | **Pass 5, order** — identity and dedup, the GENERAL exclusive-resource principle (partition a place, serialize a state), run order |
| [stage6_realize_steps.md](design/enumeration/stage6_realize_steps.md) | **Pass 6, realize** — the action catalogue, `realize ∘ dispatch` → steps → verdicts, the two dependency relations and their drift, the run cache and its blind spot, deploy-mismatch, pre-run ≡ post-run |
| [multi_lib.md](design/enumeration/multi_lib.md) | *Proposal* — a second C lib: naming landed 2026-08-25, `rp_build` + a per-slot action role remain; three options with costs |
| [resolve_placements.md](design/enumeration/resolve_placements.md) | *Proposal* — resolve a placement to a concrete location: why `Installed` carries no path, the three overlapping types (one dead), and the `Vendored`-borrows-`Build_tree` lie |

All six stages now have a standalone doc.

### Reference

| File | Topic |
| ---- | ----- |
| [ssot.md](design/ssot.md) | **Retired 2026-08-27 — redirect stub only.** It was a third hand-maintained copy of facts owned elsewhere, so every row drifted; the measurement that ended it found the drift was the file's own. The stub maps each old section to its new home, because the source cites it in 33 places |

### Rationale — how the built thing works

| File | Topic |
| ---- | ----- |
| [index.md](design/index.md) | **The design narrative** (not the doc map): vision, identity & versioning, action graph, spec/scan/compat stages, workflow, design principles |
| [action_model.md](design/action_model.md) | **What an action IS, and what `_post` means** (2026-09-16) — a hook is a MOMENT, not a specification of what runs at it; the action × declaration join that a hook needs (landed, pass 2); `probe_lib` as three roles wearing one name; the three locator vocabularies that block deriving an inspection |
| [action_playbook.md](design/action_playbook.md) | *How-to*: **adding an action** — the fork (new action vs new artifact kind on an existing one), the ten touch points, the lighter extension checklist, and what two worked examples taught. The model it realizes is `action_model.md`; its refactoring plan moved to `backlog.md` §52 |
| [matrix.md](design/matrix.md) | The result matrix — what a row is and what names it, plus why a `·` cell is not neutral. NOT an enumeration pass: `canary result` reads `actions.log` after a run |
| [staged_parity.md](design/staged_parity.md) | Build tree vs install prefix as a CHECKING principle — completeness, integrity, parity, isolation. Moved out of `enumeration/` 2026-08-24: not a stage |
| [platform.md](design/platform.md) | **The platform** (2026-08-26) — where it enters (only pass 6, realize, and the tool wrappers; passes 1–5 must stay blind to it), the three consumption modes, the Linux↔macOS tool sibling table, what a project spec may declare per platform, and how the WSL side should re-check this branch |
| [project/report_ncurses_libtinfo.md](project/report_ncurses_libtinfo.md) | **The first bug report** (2026-08-25) — `libtinfo.so.6` denotes the WIDE terminfo ABI on Debian and the NARROW one on conda-forge, so a Debian-built consumer segfaults on a conda prefix with identical sonames, symbols and version nodes. Mechanism, reproducer, backtrace, verified fix, remediation per party. The generalization lives in [agreement/components.md](design/agreement/components.md) §5.5 |
| [diagram.md](design/diagram.md) | The diagram pipeline and the design ideas its output implements |
| [tiny.md](design/tiny.md) | Tiny — how the witness works. Carries a stale reframing banner; read it first |
| [mechanism_payload.md](design/mechanism_payload.md) | The typed binding declaration (steps 1–4, 6 landed; step 5 partial) |
| [mechanism.md](design/mechanism.md) | The mechanism catalogue (shipped) + the open research direction behind it |
| [wrapper_packages.md](design/wrapper_packages.md) | Wrapper / conf-free packages, the fork layering, prebuilt-shadows-source (an unconditional filter since 2026-08-19, not a policy), the Publish generalization |

### Proposal — design for work not done

| File | Falsifier — it landed when … |
| ---- | ---------------------------- |
| [artifact_cache.md](design/artifact_cache.md) | … a step's cache key includes the identity of its INPUT artifacts, not only its own cmd/expectation fingerprint |
| [check_evaluation.md](design/check_evaluation.md) | … `canary_gh.ml` holds no verdict logic — a check is an action the runner interprets and every backend merely renders. Records the live finding that CI evaluates NO `check_pre`/`check_post`, so a green job means only "every command exited 0" |
| [step_identity.md](design/step_identity.md) | … a step tag is (action × location KIND) alone — `tag_of_probe_lib_location` called unconditionally, and no tag anywhere containing a PM name |
| [testing_plan.md](design/testing_plan.md) | … `canary pipeline-test` runs sqlite-thin through the real pipeline and asserts on the verdict table |
| [agreement/README.md](design/agreement/README.md) | **The agreement map** — what an agreement is in twenty lines, the seam with `enumeration/` (claim vs occasion), then which of the six files for which job. Start here. |
| [agreement/theory.md](design/agreement/theory.md) | **Where agreements come from** — an action embodies a relation over its inputs and running it is the only witness; the tuple is discarded and a projection survives, so an agreement is a necessary condition decidable from what survived. §5 gives, per action in the catalogue, the full-information agreement the real tool established and what post-fact checking recovers; §6 is a procedure for finding the next one. Paper material. |
| [agreement/catalogue.md](design/agreement/catalogue.md) | **One agreement, everything** — GENERATED per-agreement records: claim, obligation, where it fires and what it READS in each world, what falsifies it, what a pass does not establish. `make agreement-catalogue` rewrites it; a pin fails if it drifts. |
| [agreement/pipeline.md](design/agreement/pipeline.md) | **A project end to end** — the seven points where a run touches the registry, the four failure modes behind an `unavailable`, and the checklist for landing an agreement on a project. Since the seam was drawn (2026-09-16) it is the PROJECT-FACING walkthrough; the mechanics of when a check fires live in `enumeration/stage6_realize_steps.md` §2b. |
| [agreement/landing.md](design/agreement/landing.md) | **What is left** — per agreement, what it is waiting on; the four undecided states and the four kinds of work they mean; the distance-0 backlog; the landing procedure. It carries NO landed/not table: `canary checks --landing` is that, and the hand copy that used to sit here went stale and contradicted itself. |
| [agreement/model.md](design/agreement/model.md) | **The model** (2026-09-17, from the retired `registry.md`) — what an agreement is, claim vs checking method, the eight outcomes and why eight, a disagreement vs an expected-failure test; then §2, how a running step gets from its own action to a set of outcomes, and the round trip that says whether anything actually ran. |
| [agreement/components.md](design/agreement/components.md) | **Why each agreement exists** (2026-09-17, the other half of `registry.md`) — a walk over artifacts, bindings, versions, packaging and deployment, saying per kind what could be claimed, what observation is available and what it does not establish. Every registry row's `ag_doc` anchor points here, so its §-numbering is pinned. Paper material. |

### Retired

| File | |
| ---- | --- |
| ~~api_surface.md~~ | Theory + implementation pointers folded into `research/surface_draft/`; packaging deferred to a future `package_theory.md` |
| ~~contract_model.md~~ | Merged into `agreement/registry.md` (2026-08-21), which itself split into `agreement/model.md` + `agreement/components.md` on 2026-09-17 |
| ~~dynamic_enumeration.md~~ | Absorbed into `algorithm_explainer.md`, itself absorbed into `enumeration/stage6_realize_steps.md` (2026-08-24) |
| ~~enumeration/algorithm_explainer.md~~ | Purged 2026-08-24 — the walkthrough that predated the stage map; its sections went to the stage docs they belonged to |
| ~~enumeration/run_model_revisit.md~~ | Purged 2026-08-24 — findings to `matrix.md` §7 and `artifact_cache.md` §6, to-dos to `project/status_project.md` |
| ~~scenario_terms.md~~ | Replaced by `enumeration/stage0_naming.md` |
| ~~enumeration/repo_model.md~~ | Purged 2026-08-23 — live content absorbed into `enumeration/stage1_declare_spec.md` §4, open decisions to `project/status_project.md` §2 |
| ~~enumeration/versioning.md~~ | Purged 2026-08-23 — same; the version model is `stage1_declare_spec.md` §5 + `enumeration/stage1_declare_spec.md` |
| ~~ssot.md~~ | Retired 2026-08-27 — §4.2.x to `enumeration/`, §6.1 to `enumeration/stage0_naming.md`, §6.5/§6.6 to the action catalogue + `stage5`, the Ar/Sf/Ag/Sc/Bs tables to `research/surface_draft/ids.md`. A redirect stub remains for the 33 code citations |

## project/ — live projects, their status, and how to land one

One question each. The layer's home since the 2026-08-12 reorganization;
shrunk to this shape 2026-08-21, when `index.md` + `coverage.md` merged
into `projects.md`, `store_switching.md` and `wrapper_packages.md` moved
to `design/` and `conf_survey.md` to `surveys/`. The store-switching half
came BACK on 2026-08-24 as `opam_exclusive_store_issue.md`: once the
general principle was extracted into `design/enumeration/stage5_order_worlds.md`
§2, what remained was one package manager's problem, which is a project
concern.

| File                                           | Topic                                                                                                     |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| [projects.md](project/projects.md)             | **The roster** — the dimension model, per-project coverage + 2×2 status, landing history, candidate portfolio |
| [status_project.md](project/status_project.md) | **THE to-do tracker** for this layer — the ordered plan, general to-dos, the mismatch-matrix report milestone |
| [issues.md](project/issues.md)                 | OPEN per-project issues — a standalone worklist (unresolved findings, declaration gaps, per-project chores)   |
| [issues_torch.md](project/issues_torch.md)               | **torch's findings** — four problems of four kinds (packaging / provisioning / drift / caching), plus THE RECIPE: `Declarations.yaml` from a pip wheel via `torchgen`, no PyTorch source build |
| [landing.md](project/landing.md)               | **How to land a project** — workflow, data structures, testing harness (the future skill's base)             |
| [opam_exclusive_store_issue.md](project/opam_exclusive_store_issue.md) | opam's one-version-per-switch problem — what a pin costs, the per-version-switch measurement, and the two open questions |
| [project_pytorch.md](project/project_pytorch.md) | PyTorch multi-PM case study — pre-implementation plan for candidate #4                                     |

Landing a project also reaches into `surveys/` (which library, which
version pair) and `design/` (`enumeration/stage1_declare_spec.md` for the
declaration, `wrapper_packages.md` for a conf-free package,
`enumeration/multi_lib.md` for a second C lib) — see those tables
above.

## surveys/ — background research

Pre-code survey data. Source of truth for `project/projects.md` §4
candidate selection and the failure taxonomy now in
`research/draft.md` (and materials in `research/surface_draft/`).

| File                                             | Topic                                                                           |
| ------------------------------------------------ | ------------------------------------------------------------------------------- |
| [opam.md](surveys/opam.md)                       | Survey of 4460 opam packages: pattern A/B/C/D/E classification, revdep rankings |
| [conf_packages.md](surveys/conf_packages.md)     | Classification of all 333 `conf-*` packages by build complexity; §G is the MEASURED landing ranking |
| [lib_selection.md](surveys/lib_selection.md)               | **How an OCaml package says WHICH native library to use** — conf-* (a lossy conversion to a distro package name) vs torch's env-driven configurator chain; who actually ships libtorch per channel; the torch×libtorch constraint table and the depends→depopts weakening; co-provider support today |
| [conf_mechanism.md](surveys/conf_mechanism.md)   | How a `conf-*` package works (the live `conf-gmp.5`) + the position that opam should drop them |
| [conda_forge.md](surveys/conda_forge.md)         | conda-forge as a prebuilt-binary channel — feature/issue/experience + measured dependency closures |
| [packaging_study.md](surveys/packaging_study.md) | Older packaging study (pre-rearchitecture)                                      |

## ops/ — operational notes & gotchas

Pre-code summaries and gotchas. Durable. Kept for both human and AI
retrieval to avoid re-discovering the same friction.

| File                                                       | Topic                                                                                         |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| [llvm_build.md](ops/llvm_build.md)                         | The MANUAL LLVM build that seeds canary's build tree (they share a dir, and configure differently) |
| [install_targets.md](ops/install_targets.md)               | What a project's `cmake --install` does — discovery patterns, the rpath/layout coupling, failure modes |
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
