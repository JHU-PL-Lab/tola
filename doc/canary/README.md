# Canary documentation

Directory map for `doc/canary/`. Files grouped by intent.

**Start with `design/index.md` for the design narrative.** See `CLAUDE.md`
(project root) for live status, gaps, and current gotchas.

## design/ — what canary models

The unified design narrative. Active surface; updated as the model evolves.

| File | Topic |
|---|---|
| [index.md](design/index.md) | Unified design: vision, identity, action graph, spec_shape & scan stage, workflow |
| [interface.md](design/interface.md) | Interface contract (provides ⊆ requires; L1a–L5 layering; failure taxonomy) + `canary_artifact_api` types + `summary.json` schema |

## trackers/ — implementation status & coverage plans

Time-bound trackers for ongoing implementation efforts and target coverage.
Each file should declare a deletion trigger so the directory doesn't grow
unbounded.

| File | Topic |
|---|---|
| [python_binding.md](trackers/python_binding.md) | Stage 1 Python binding integration — A–D done + CI green; remaining items |
| [pytorch.md](trackers/pytorch.md) | PyTorch as multi-PM target (queued; depends on Python primitives) |
| [batch_candidates.md](trackers/batch_candidates.md) | Two-tier portfolio: core (z3/llvm/torch) + extended (zarith/ssl/cvc5/…) |

## surveys/ — background research

Pre-code survey data. Source of truth for `trackers/batch_candidates.md`
choices and the `design/interface.md` failure taxonomy.

| File | Topic |
|---|---|
| [opam.md](surveys/opam.md) | Survey of 4460 opam packages: pattern A/B/C/D/E classification, revdep rankings |
| [conf_packages.md](surveys/conf_packages.md) | Classification of all 333 `conf-*` packages by build complexity |
| [packaging_study.md](surveys/packaging_study.md) | Older packaging study (pre-rearchitecture) |

## ops/ — operational notes & gotchas

Pre-code summaries and gotchas. Durable. Kept for both human and AI
retrieval to avoid re-discovering the same friction.

| File | Topic |
|---|---|
| [ci_gh.md](ops/ci_gh.md) | GH Actions backend implementation, Z3 quirks, sccache + opam sandbox |
| [llvm_build.md](ops/llvm_build.md) | LLVM source build steps, smoke test, opam install notes |
| [install_targets.md](ops/install_targets.md) | Z3 vs LLVM cmake install patterns |
| [opam_packaging.md](ops/opam_packaging.md) | opam packaging patterns for canary |
| [python_binding_gotchas.md](ops/python_binding_gotchas.md) | Lessons from sqlite/z3/llvm Python integration (pip env, version axes, deprecated APIs, etc.) |

## Top-level

| File | Topic |
|---|---|
| [backlog.md](backlog.md) | Lower-priority TODOs (numbered #N like GH issues) |
| [worklog/](worklog/) | Meeting notes + monthly worklogs |
