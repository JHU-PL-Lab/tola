# Canary documentation

Top-level navigation for `doc/canary/`. Files grouped by intent.

## design/ — what canary models

How canary represents projects, artifacts, interfaces, and bindings.
Active design surface; updated as the model evolves.

| File | Topic |
|---|---|
| [overview.md](design/overview.md) | Pattern table, store config, execution model — the canonical canary design |
| [interface_contract.md](design/interface_contract.md) | Interface as first-class object; L1a/L1b/L2/L3/L4/L5 layering |
| [artifact_summary.md](design/artifact_summary.md) | Compact artifact summary (`summary.json`) — counts, watchlists, versioned-deps |
| [api_source.md](design/api_source.md) | First-class API-source layer (deferred; revisit after Stage 3 universal binding work) |
| [python_binding.md](design/python_binding.md) | Python binding integration — primitives + per-project wiring |

## coverage/ — which projects canary tests

Plans for adding new target projects to canary. Coverage growth, not model
change.

| File | Topic |
|---|---|
| [pytorch.md](coverage/pytorch.md) | PyTorch as multi-PM target (queued; depends on Python primitives) |
| [batch_candidates.md](coverage/batch_candidates.md) | Two-tier portfolio of expansion targets (core: z3/llvm/torch; extended: zarith/ssl/cvc5/…) |

## surveys/ — background research

Pre-code survey data. Source of truth for `coverage/batch_candidates.md`
choices and the `interface_contract.md` failure taxonomy.

| File | Topic |
|---|---|
| [opam.md](surveys/opam.md) | Survey of 4460 opam packages: pattern A/B/C/D/E classification, revdep rankings |
| [conf_packages.md](surveys/conf_packages.md) | Classification of all 333 `conf-*` packages by build complexity |
| [packaging_study.md](surveys/packaging_study.md) | Older packaging study (pre-rearchitecture) |

## ops/ — operational notes & gotchas

Pre-code summaries and gotchas. Kept for both human and AI retrieval to
avoid re-discovering the same friction.

| File | Topic |
|---|---|
| [ci_gh.md](ops/ci_gh.md) | GH Actions backend implementation, Z3 quirks, sccache + opam sandbox |
| [llvm_build.md](ops/llvm_build.md) | LLVM source build steps, smoke test, opam install notes |
| [install_targets.md](ops/install_targets.md) | Z3 vs LLVM cmake install patterns |
| [opam_packaging.md](ops/opam_packaging.md) | opam packaging patterns for canary |

## Top-level

| File | Topic |
|---|---|
| [backlog.md](backlog.md) | Lower-priority TODOs (numbered #N like GH issues) |
| [expression_sharing_note.md](expression_sharing_note.md) | Side-project idea (DAG enumeration / shared subexpressions). Revisit later. |
| [worklog/](worklog/) | Meeting notes + monthly worklogs |

## Reading order for newcomers

1. **`design/overview.md`** — what canary is and how it works
2. **`design/interface_contract.md`** — the conceptual frame (versioning, drift, layering)
3. **`surveys/opam.md` §1, §2** — what canary is up against
4. **`coverage/batch_candidates.md`** — concrete expansion targets
5. CLAUDE.md (project root) — current status, gaps, gotchas

## Stages of work currently in flight

(See `CLAUDE.md` for live status.)

- **Stage 1 — Python binding for core projects.** `design/python_binding.md`. Done locally + CI; gotchas captured.
- **Stage 2 — Doc reorg.** This file is the deliverable.
- **Stage 3 — Universal binding abstraction.** Pending. `design/api_source.md` is the precursor. Will model: provider (opam/pip/cargo) × language × runtime, with per-binding version axes (key Stage 1 finding).
- **Stage 4 — Cover more projects.** Resumes `coverage/batch_candidates.md` work after Stage 3 abstraction.
