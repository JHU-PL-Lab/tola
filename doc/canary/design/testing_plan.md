# Testing plan — general structure and algorithm behavior

> Written 2026-08-07. Covers what to test beyond the existing
> `project-test` (53 pure) and `artifact-test` (107 pure+shell).

## Current test coverage

| Suite | What it covers | Gap |
|---|---|---|
| `project-test` | Pure checks: consumes/produces, enumeration shapes, dispatch, provisions, pins | No execution — doesn't run the pipeline |
| `artifact-test` | Tool primitives (nm, ocamlobjinfo, python import, mutation apply) | No project integration |
| `pm-test` | PM presence checks | Narrow scope |
| Actual runs | `canary action sqlite` etc. | Manual, not automated in CI |

## Missing: pipeline integration tests

A new test suite that runs a **hermetic, fast project** through the full
pipeline and asserts on the output. The ideal test project is **sqlite** with
the `--thin` policy — 1 scenario, no builds (Fetched only), ~10 steps, runs
in seconds.

### Phase 1: Hermetic pipeline test (1 session)

Add `canary pipeline-test` subcommand:

```
dune exec src/bin/canary_main.exe -- pipeline-test
```

Runs sqlite-thin through `run_project_run` (the same path as `action sqlite
--thin`), captures the verdict table, and asserts:
- N scenarios enumerated (1 under thin)
- Every step verdict is `Step_done` or `Step_done_xfail`
- The scenario.tsv file is written and parseable
- Ambient step dedup is exercised (python probe runs once)
- The table mechanism is exercised (sqlite_rows → realize_from_rows)

This is the "does the pipeline work end-to-end" smoke test. It catches:
- A broken `derive_steps` that silently drops steps
- A broken cache that serves stale success
- A broken table template that fails to instantiate
- A regression in the enumeration that changes scenario count

### Phase 2: Table mechanism tests (1 session)

Pure tests that verify the action-variant table produces correct
runner_specs:

- `table.all_templates_defined`: every template name used in any project's
  rows resolves in the dispatcher (no runtime "unknown template" errors)
- `table.sqlite_rows_produce_valid_spec`: `realize_from_rows` on sqlite's
  Fetched rows produces a spec with non-empty fetch_lib, fetch_binding,
  probe_binding
- `table.z3_rows_produce_valid_spec`: same for z3's Dev_chain rows —
  build_lib, configure, probe_lib are non-empty
- `table.roundtrip`: derive_steps on a table-produced spec succeeds (no
  crashes, no missing deps)

### Phase 3: Cache and dedup tests (1 session)

- `cache.ambient_dedup`: two scenarios sharing an Ambient probe step — the
  second run skips the step via verdict marker
- `cache.fetched_dedup`: two Fetched scenarios with different declared
  versions dedup to one run
- `cache.cold_equals_warm`: running the same scenario twice produces the
  same verdicts (second run is all cache hits)

### Phase 4: Enumeration edge-case tests (existing suite + additions)

Extend `project-test` with:
- `enumerate.empty_policy`: a project with no matching provisions returns []
- `enumerate.all_fetched_dedup`: two Fetched artifacts at different channels
  produce 1 scenario, not 2
- `enumerate.follows_prunes_mismatch`: with `ax_follows`, cross-channel pairs
  are pruned (already covered by `binding_follows_chain` pins)

## What stays manual

Full `canary action z3` and `canary action llvm` are expensive (cmake,
ninja, ~30 min). They stay manual. The hermetic tests use sqlite-thin
(fetch-only, ~10s) and pure table tests.

## Priority

Phase 1 (pipeline smoke test) gives the most confidence per effort. Phases
2-3 can follow as the table mechanism and cache logic evolve. Phase 4 is
incremental additions to the existing suite.
