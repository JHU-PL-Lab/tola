# Canary code audit — post-refactor (2026-06-01)

**Purpose.** Snapshot the canary source tree after the 7-phase refactor
that started from [`audit_2026_06_01.md`](audit_2026_06_01.md) (in-house
planning audit) and [`audit_codex_2026-06-01.md`](audit_codex_2026-06-01.md)
(independent second opinion). The original two docs remain as the
"before" snapshots and the rationale for each change; this doc
catalogues the "after" state and surfaces what's still outstanding.

**Inputs:** original audit's §C plan (C.1 dead-code purge, C.2 lift
`lang` to base, C.3 split `canary.ml`, C.4 unify compat ADTs, C.6
extract `run_info`), codex audit's seven findings, plus codex's open
question 1 (whether legacy should be deletable vs. compilable —
chosen: park into `legacy/canary_yaml_backend.ml`).

**What landed**, in commit order:

| Phase | Commit | Effect |
|---|---|---|
| 1 | `5c0438f` | New `base/canary_lang.ml`; eliminates base→surface layer reversal. |
| 2 | `826838b` | Dead YAML plumbing parked in `legacy/canary_yaml_backend.ml`. `canary_basic.ml` 460→238 (-48%); `canary.ml` 648→586. |
| 3 | `800108d` | `tool/canary_build_cmd.ml` extracted from `canary_toolchain.ml`. |
| 4 | `0e0164d` | One `Canary_compat.inspect_input` ADT replaces two duplicated types + 40 lines of manual translation in two callers. |
| 5 | `b5f3006` | `canary.ml` 581 LOC → 24-line `include` shim; new `canary_action` (135), `canary_step_model` (130), `canary_path_table` (288). |
| 6 | `c52d4d7` | `action/canary_run_info.ml` (338) extracted from `canary_action.ml` (1226→912). |
| 7 | `0139e07` | Stale flat paths in active docs refreshed to layered subdir paths. |
| 8 | (follow-up) | Backend filenames lose the `_backend_` prefix (`canary_gh.ml`, `canary_html.ml`); `canary_runner.ml` splits into `action/canary_step_builder.ml` (script_spec + derive_steps) + `backend/canary_local_runner.ml` (run_step + run_graph). Four sibling backends now consume `action_step list`. |

Regression at every commit: `artifact-test 73/73`, `pm-test 14/14`,
`action tiny 12/12`. The pre-existing diagram-connectivity invariant
warning predates this work and is unchanged.

The `pm-test 14/14` figure is **environment-dependent**: the `apt`
test case invokes `sudo apt install` and relies on a working sudo
setup. In sandboxed environments where `/etc/sudo.conf` ownership is
non-root (a common LXC / container artefact), the apt case fails
with `sudo: /etc/sudo.conf is owned by uid 65534, should be 0` and
the suite reports 13/14. This is an environment limitation, not a
canary issue. On a vanilla WSL2 / Ubuntu host the suite passes 14/14
as cataloged.

---

## A. Per-module catalog — post-refactor

In-degree counts qualified references (`Canary_<module>.X`); files
exposed via the `Canary` `include` shim may show 0 because callers
use `Canary.foo` instead of `Canary_action.foo`.

### base/ (5 files, 439 LOC)

| Module | LOC | In | Verdict | Change since 06-01 |
|---|---:|---:|:-:|---|
| `canary_lang.ml` | 22 | 16 | ✅ | **NEW** (Phase 1) — lifted from surface/ |
| `canary_basic.ml` | 238 | 8 | ✅ | was ❌ kitchen sink (460 LOC); dead helpers parked (Phase 2) |
| `canary_store.ml` | 119 | 11 | ✅ | unchanged; uses `Canary_lang.lang` instead of `Canary_artifact_api.lang` |
| `canary_pm_types.ml` | 15 | 4 | ✅ | unchanged |
| `canary_output_path.ml` | 45 | 14 | ✅ | unchanged |

`base/` is now genuinely layer 0: every module here is small, coherent,
and free of references to higher layers. The latent base→surface
reversal that both audits flagged is gone.

### surface/ (3 files, 1142 LOC)

| Module | LOC | In | Verdict | Change since 06-01 |
|---|---:|---:|:-:|---|
| `canary_artifact_api.ml` | 161 | 5 | ✅ | `lang` re-exported as transparent alias; rest unchanged |
| `canary_compat.ml` | 501 | 5 | ✅ | gained `inspect_input` ADT (Phase 4); rest unchanged |
| `canary_compat_run.ml` | 480 | 6 | ✅ | `predicted_contains_any_v2` takes `~resolve`; `typed_input` deleted (Phase 4) |

### tool/ (11 files, 1623 LOC)

| Module | LOC | In | Verdict | Change since 06-01 |
|---|---:|---:|:-:|---|
| `canary_toolchain.ml` | 410 | 5 | ✅ | was ⚠ mixed; build primitives extracted (Phase 3) |
| `canary_build_cmd.ml` | 69 | 3 | ✅ | **NEW** (Phase 3) |
| `canary_artifact_native.ml` | 149 | 7 | ✅ | unchanged |
| `canary_artifact_lang.ml` | 215 | 5 | ✅ | unchanged |
| `canary_artifact_source.ml` | 116 | 4 | ✅ | unchanged |
| `canary_inspect_diff.ml` | 130 | 1 | ✅ | unchanged |
| `canary_pm_apt.ml` | 36 | 2 | ✅ | unchanged |
| `canary_pm_brew.ml` | 33 | 2 | ✅ | unchanged |
| `canary_pm_opam.ml` | 60 | 3 | ✅ | unchanged |
| `canary_pm_pip.ml` | 40 | 2 | ✅ | unchanged |

`canary_toolchain.ml` is now coherently the OCaml+opam+pip toolchain
config and command surface; build-tool generators (cmake/ninja/dune)
moved to their own sibling.

### action/ (7 files, 1898 LOC)

| Module | LOC | In | Verdict | Change since 06-01 |
|---|---:|---:|:-:|---|
| `canary.ml` | 24 | 4 | ✅ | was ❌ kitchen sink (648 LOC); now `include` shim |
| `canary_action.ml` | 135 | 0¹ | ✅ | **NEW** (Phase 5, originally `canary_action_rule`; renamed in the action/runner pass) — the action-graph schema |
| `canary_step_model.ml` | 130 | 0¹ | ✅ | **NEW** (Phase 5) |
| `canary_path_table.ml` | 288 | 0¹ | ✅ | **NEW** (Phase 5) |
| `canary_step_builder.ml` | 708 | 7 | ✅ | was `canary_runner.ml` (912 LOC); execute-half (run_step + run_graph + …) split to `backend/canary_local_runner.ml` (Phase 8); now coherently the step-list builder (script_spec + derive_steps + shared templates + check_post compositors + defaults) |
| `canary_run_info.ml` | 338 | 1 | ✅ | **NEW** (Phase 6) |
| `canary_step_cache.ml` | 71 | 3 | ✅ | unchanged |

¹ The new step-model / action-rule / path-table modules show 0 because
callers reach their contents through `open Canary` (the shim
`include`s all three). Real reach is wider — `step_expectation`,
`action_step`, `action_rule`, etc. are referenced from
`canary_action`, `canary_diagram`, `canary_backend_gh`, project specs,
and tests. The 0-count is an artefact of the shim, not unused code.

### backend/ test/ projects/ legacy/

| Subdir | Files | LOC | Notes |
|---|---:|---:|---|
| `backend/` | 4 | 3300 | Phase 8 dropped `_backend_` prefix → `canary_gh.ml` + `canary_html.ml`, and added `canary_local_runner.ml` (273 LOC, the execute-half of the former canary_runner). Four sibling backends now consume `action_step list`. `canary_diagram.ml` (2283) remains the heaviest single file. `canary_gh.ml` had also been adjusted in Phase 4 for the compat ADT unification. |
| `test/` | 2 | 1036 | unchanged |
| `projects/` | 8 | 1922 | constructors changed from `C_stub { paths = [...] }` to `Canary_compat.C_stub [...]` (Phase 4) |
| `legacy/` | 3 | 962 | gained `canary_yaml_backend.ml` (302 LOC, Phase 2); `canary_dead_code.ml` retargets to it; `example_sp.ml` unchanged |

---

## B. Findings resolved since 2026-06-01

Each row maps an original-audit finding to the commit that resolved it.

| Original finding | Phase | Status |
|---|:-:|---|
| `canary_basic.ml` is a kitchen sink (~13 dead types, ~6 dead helpers, ~50% by LOC) | 2 | ✓ resolved — parked into `legacy/canary_yaml_backend.ml`; canary_basic now 238 LOC of live vocabulary |
| `canary.ml` mixes dead legacy + 4 live topics | 2 + 5 | ✓ resolved — dead front matter parked; remaining 4 topics split into 3 coherent files |
| Latent base→surface layer reversal via `Canary_artifact_api.lang` | 1 | ✓ resolved — `lang` lifted to `base/canary_lang.ml`; `Canary_artifact_api.lang` is a transparent re-export |
| Duplicate ADT `compat_inspect_input` / `typed_input` + 40 lines of manual translation | 4 | ✓ resolved — single `Canary_compat.inspect_input`; runner takes `~resolve` to handle path resolution |
| `canary_toolchain.ml` mixes 3 sub-concerns | 3 | ✓ resolved — build primitives split out; toolchain is now opam+cc+pip only |
| `canary_action.ml` broad (1248 LOC) | 6 | ✓ partial — `run_info` tail extracted; file renamed to `canary_runner.ml` (912 LOC) — now coherently the runner |
| `surface_theory.md` + design/research docs have stale flat paths | 7 | ✓ resolved — paths refreshed across active docs (worklogs kept as historical record) |
| Codex finding 2: `legacy/canary_dead_code` still calls `Canary_basic.mk_canary_config` | 2 | ✓ resolved — dead-code references updated to `Canary_yaml_backend.mk_canary_config`, keeping legacy library compilable |
| Codex finding 8 (warning discipline uneven) | — | not addressed; live code still doesn't declare local warning flags |

---

## C. New observations from the refactored state

### C.1 The `Canary` shim is a compatibility crutch

`action/canary.ml` is now a 24-line file that `include`s
`Canary_action`, `Canary_step_model`, `Canary_path_table`. Every
project spec, backend, and test still says `open Canary` to grab
everything at once. The shim keeps the migration cheap, but it also
hides which module each constructor / type actually lives in. A reader
who sees `Expect_compat_failure` in a project spec has to grep three
files to find it.

Two reasonable futures:
- **Drop the shim**: each caller `open`s the specific module it
  needs. ~8 callers; mechanical but invasive. Pro: complete honesty
  about dependencies. Con: more `open` boilerplate per file.
- **Keep the shim, document its scope**: add a comment listing every
  symbol the shim re-exports, so a reader can use it as a lookup
  index instead of just grep.

Recommend keeping the shim for now and revisiting if it gets in the
way of future work.

### C.2 ~~`canary_runner.ml` is still 912 LOC~~ — resolved (Phase 8)

After Phase 8 split execution into `backend/canary_local_runner.ml`,
the renamed `canary_step_builder.ml` is 708 LOC and the new
`canary_local_runner.ml` is 273 LOC. Both are coherent.

(Original Phase 6 commentary, kept for historical context:)
Even after Phase 6 extracted ~315 LOC of `run_info`, `canary_runner.ml`
remains the largest active file. The remaining content is genuinely
cohesive — `script_spec` + `derive_steps` (the contract) +
`run_step` / `run_graph` (the runner) + shared command templates
(`fetch_lib_cmd`, `probe_ocaml_cmd`) + check_post compositors. None
of these split cleanly without circular dependencies through
`script_spec`.

Verdict: large but coherent. No further split is justified by audit
evidence. Re-examine if a future feature touches just one half.

### C.3 `canary_diagram.ml` is 2283 LOC and unchanged

The heaviest file in the codebase remains untouched by this refactor.
Codex audit noted it as ⚠ ("very large, but coherent"). Splits would
require clear seams between schema diagram / step graph / view
machinery / project index — those seams exist but haven't been
investigated in this pass.

Status: deferred. Document concrete pain points (specific functions
hard to find, specific edits requiring context across the file)
before another split attempt.

### C.4 `legacy/canary_yaml_backend.ml` is 302 LOC of mostly-dead code

The parked module compiles and `canary_dead_code.ml` consumes it,
which keeps it from rotting silently. But nothing in the live
pipeline references it. Future calls:

- If we re-implement the distro × sys-PM × lang-PM enumeration in
  the live pipeline (the design intent it encodes), the parked
  module can be deleted at the same time.
- If after a year there's no clear plan, delete it and rely on the
  CLAUDE.md note ("Retire legacy …") to document the intent.

Not urgent either way. Suggest a 6-month re-evaluation window.

### C.5 `legacy/example_sp.ml` has zero external consumers

It exists as its own executable, consumes `Canary_dead_code`, and is
not called by anything else. If `legacy/canary_dead_code.ml` ever
gets deleted (C.4), `example_sp.ml` goes with it.

### C.6 CLAUDE.md "Key source files" table is stale

The CLAUDE.md table near the top of the file still lists paths like
`src/canary/canary.ml`, `src/canary/canary_compat.ml`, etc. It was
right before any subdir restructuring and was not updated through any
of the recent phases.

This is a separate task per the handoff workflow at the bottom of
CLAUDE.md; flagging it as outstanding rather than fixing it here
since CLAUDE.md is the project's primary handoff doc and warrants
deliberate attention.

---

## D. Quantitative summary

**Active code:**

| Metric | Before (audit_2026_06_01) | After | Δ |
|---|---:|---:|---:|
| `canary_basic.ml` LOC | 460 | 238 | -222 (-48%) |
| `canary.ml` LOC | 648 | 24 | -624 (-96%) |
| `canary_action.ml` → `canary_runner.ml` → `canary_step_builder.ml` + `canary_local_runner.ml` LOC | 1248 | 708 + 273 | step-builder dropped to 708; +273 in a new sibling file |
| `canary_toolchain.ml` LOC | 466 | 410 | -56 (-12%) |
| Module count in `action/` | 3 | 7 | +4 (split, not bloat) |
| Module count in `base/` | 4 | 5 | +1 (new `canary_lang`) |
| Module count in `tool/` | 10 | 11 | +1 (new `canary_build_cmd`) |
| Layer violations (base→surface) | 2 | 0 | -2 |
| Duplicate ADTs (compat_inspect_input ↔ typed_input) | 1 pair | 0 | -1 |
| Manual translation blocks | 2 × ~20 LOC | 0 | -40 LOC |

**Parked code (intentional):**

| Module | LOC | Purpose |
|---|---:|---|
| `legacy/canary_dead_code.ml` | 433 | Pre-canary Z3/Llvm/Sqlite plumbing; consumed only by example_sp |
| `legacy/canary_yaml_backend.ml` | 302 | Retired yaml backend types + helpers (Phase 2 destination) |
| `legacy/example_sp.ml` | 227 | Legacy CLI binary |

---

## E. Outstanding work

Listed in rough priority order. Each line names the source-of-truth
audit point the item came from.

1. **Refresh CLAUDE.md "Key source files" table** to match the
   layered layout. Original audit §C didn't cover this; surfaced
   during Phase 7 doc refresh.
2. **`canary_diagram.ml` (2283 LOC) split investigation** — codex
   noted "very large, but coherent"; original audit §A backend/
   row. Not a hot issue, but worth examining once specific pain
   points emerge.
3. **Warning discipline** — codex finding 8: live canary code
   doesn't declare local warning flags in `src/canary/dune` (legacy
   has `-w -32 -w -37`). Could enable warning 33 (unused-open) in
   the live library and clean up the surfaced cases.
4. **`Canary` shim future** — see C.1. Drop-or-document choice when
   it next gets in the way.
5. **`canary_artifact_test.ml` (915 LOC) split** — flagged by both
   audits as "no hurry". Domain-keyed split (native / lang / compat /
   pm) would yield ~4 files of ~225 LOC each.
6. **Re-evaluate `legacy/`** — see C.4. Suggest 6-month window
   before deciding delete vs. keep.

---

## F. Reading guide refresh

The reading guide in the original audit's E section ([§5 of the first
audit doc](audit_2026_06_01.md)) listed paths as of the pre-refactor
layout. With the splits and renames, a refreshed walk-through:

**Layer 0 — base/** (read first, ~440 LOC)
1. [base/canary_lang.ml](../../src/canary/base/canary_lang.ml) — 22
   lines; the foundational `lang` type used everywhere.
2. [base/canary_basic.ml](../../src/canary/base/canary_basic.ml) —
   `artifact_kind`, `runner_os`, `cmdline`, `rule`, `version`,
   `string_of_*`. Live vocabulary only after Phase 2.
3. [base/canary_store.ml](../../src/canary/base/canary_store.ml) —
   `location`, `package_manager`, `source_repo`, `distro`.
4. [base/canary_pm_types.ml](../../src/canary/base/canary_pm_types.ml)
   + [base/canary_output_path.ml](../../src/canary/base/canary_output_path.ml) —
   tiny utilities.

**Layer 1 — surface/** (theory, ~1140 LOC)
5. [surface/canary_artifact_api.ml](../../src/canary/surface/canary_artifact_api.ml)
   — `native_api`, `binding_api`. Declarative claims about provider +
   consumer surfaces.
6. [surface/canary_compat.ml](../../src/canary/surface/canary_compat.ml)
   — c1..c8 pure comparators plus the unified `inspect_input` ADT.
   Read the header docstring first.
7. [surface/canary_compat_run.ml](../../src/canary/surface/canary_compat_run.ml)
   — drives `Canary_compat` over cached inspector JSONs. CLI `compat`
   / `verify` entries.

**Layer 2 — tool/** (real-world tool wrappers, ~1620 LOC)
8. [tool/canary_toolchain.ml](../../src/canary/tool/canary_toolchain.ml)
   — opam + OCaml + Python toolchain types and command generators.
9. [tool/canary_build_cmd.ml](../../src/canary/tool/canary_build_cmd.ml)
   — cmake / ninja / dune primitives.
10. [tool/canary_artifact_native.ml](../../src/canary/tool/canary_artifact_native.ml)
    — pattern for the artifact_* inspector drivers; one read covers
    canary_artifact_lang and canary_artifact_source.
11. [tool/canary_pm_*.ml](../../src/canary/tool/) — read one (apt),
    skim the rest.

**Layer 3 — action/** (the action graph, ~1900 LOC)
12. [action/canary_step_model.ml](../../src/canary/action/canary_step_model.ml)
    — `step_expectation`, `action_step`, `logger`. The vocabulary the
    runner and renderer share.
13. [action/canary_action.ml](../../src/canary/action/canary_action.ml)
    — `action_rule`, `store_rules`, `make_action_rule`. The
    action-graph schema (what actions exist, what artifacts they
    produce).
14. [action/canary_step_builder.ml](../../src/canary/action/canary_step_builder.ml)
    — `script_spec`, `derive_steps`, shared command templates,
    check_post compositors. Bridges the action-graph schema into a
    project's concrete `action_step list`. Largest file in this
    layer; read in pieces.
14b. [backend/canary_local_runner.ml](../../src/canary/backend/canary_local_runner.ml)
    — `run_step`, `run_graph`, `merge_step_statuses`. Sibling
    backend to canary_gh/html/diagram, but executes the steps
    locally in-process rather than emitting a file.
15. [action/canary_run_info.ml](../../src/canary/action/canary_run_info.ml)
    — `run_project` + state persistence. The user-facing entry the
    CLI calls.
16. [action/canary_path_table.ml](../../src/canary/action/canary_path_table.ml)
    — `paths` / `paths-md` subcommands. Independent of the runner.
17. [action/canary_step_cache.ml](../../src/canary/action/canary_step_cache.ml)
    — small CI-result cache.
18. [action/canary.ml](../../src/canary/action/canary.ml) — the 24-line
    shim that re-exports the above. Useful as a lookup index.

**Layer 4 — backend/, test/, projects/, legacy/** unchanged; read
order matches the original audit's E section.

---

## G. Confidence

This audit was produced inline with the refactor session that
implemented it; per-commit verification (build + 73/14/12 regression)
gives strong assurance that the cataloged state matches what's in
git as of `0139e07`. The "what landed" table at the top is the
authoritative ground truth.

The "Δ" column in §D was computed by reading post-refactor LOCs
directly and comparing to the numbers cataloged in the original
audit. Spot-check welcome.

For an independent second look, the [audit prompt](audit_prompt.md)
can be re-run against this state — point a fresh auditor at this
doc + the original two and ask them to validate / extend / disagree.
