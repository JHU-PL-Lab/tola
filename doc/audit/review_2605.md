# Tola / Canary — Audit Review

- **Date**: 2026-08-05
- **Auditor**: Codex agent session (fresh, no prior repo context)
- **Environment**: OCaml 5.4.1 (opam switch `default`), Linux/WSL, dune 3.10, repo `main` @ `e9997b1`
- **Filename note**: `review_2605.md` = `YY`(26) `DD`(05) per request; rename to `review_260805.md` if YYMMDD was intended.

---

## 1. Executive Summary

The repo is two projects in one tree:

1. **Canary** (`src/canary/`, `canary/`, `src/bin/canary_main.ml`) — the *active* area. A dependency-testing framework that enumerates build/probe scenarios for C libraries with OCaml/Python bindings, runs them locally, and emits GH Actions YAML / HTML / Mermaid / run state. Extensive doc discipline (CLAUDE.md, `doc/canary/design/ssot.md`, worklogs). Last touched today (2026-08-05).
2. **Tola PL framework** (`src/packaging`, `langs`, `interp`, `ainterp`, `std`, `versioning`, `versioned_maps`, `repl`, `tola`, `binding`) — *legacy*; untouched since late 2025 / early 2026, still built and unit-tested, some modules unreferenced.

**Overall health: good** — clean build, all unit + framework tests green **except one reproducible failure** (F1: `mutation-test`). Main non-test concerns: machine-specific absolute paths committed to source (F2), generated run outputs churning the tracked `docs/canary` tree (F3), orphaned `src/binding` (F5), CI not covering the actual test suite (F7).

| Area | Verdict |
| --- | --- |
| Build | ✅ `dune build` clean |
| Unit tests | ✅ 50/50 (`dune runtest --force`) |
| Canary framework tests | ✅ `artifact-test` 107/107, `project-test` 46/46 |
| Canary mutation tests | ❌ 45/46 — `api_faithful.patch` no longer applies (F1) |
| Secrets scan | ✅ no keys/secrets in `src/` or `canary/` |

## 2. Verification Matrix (commands run this session)

| Check | Command | Result |
| --- | --- | --- |
| Build | `eval $(opam env) && dune build` | PASS (incremental) |
| Unit tests | `eval $(opam env) && dune runtest --force` | PASS — Versioning (1), Fix (6), Dd_interp (17), Boat_interp (19), Pkgm (6) |
| Boat alias | `dune build @cur` | PASS (19) — see F8-c |
| Framework self-tests | `dune exec src/bin/canary_main.exe -- artifact-test` | PASS 107/107 (pure 77, shell 30) |
| Project layer | `dune exec src/bin/canary_main.exe -- project-test` | PASS 46/46 |
| Mutation layer | `dune exec src/bin/canary_main.exe -- mutation-test` | **FAIL 1/46** — `all.apply-api_faithful.patch` (rc=1) |
| Run-state view | `dune exec src/bin/canary_main.exe -- status @all` | OK — cairo 1/1 ✓, llvm 4 scenarios incl. expected `xfail` (Opcode.UncondBr binding-lag marker) |
| **Not run** | `pm-test`, `cache-test`, `action z3|llvm|sqlite|tiny-full` | Need network / package-manager installs / long builds — see F7 for CI gap |

## 3. Findings

### F1 — [HIGH, reproducible] `mutation-test` fails: `api_faithful.patch` is stale

- **Evidence**: `canary mutation-test` → `all.apply-api_faithful.patch` FAIL (rc=1), all other 45 pass. Reproduced directly:
  `patch -p1 < canary/examples/tiny/scenarios/patches/api_faithful.patch` against `canary/examples/tiny/c/src/tiny.c` → `Hunk #1 FAILED -- saving rejects to file c/src/tiny.c.rej`. The `tiny.h` hunk only applies via `patch` **fuzz 2 (offset 7)** — silently tolerant today, would break under `patch --fuzz=0`.
- **Root cause**: fixture drift. The patch expects `tiny.c` to end right after `tiny_diff` (3-line context), but the fixture has since gained the `tiny_offset` global (`c/src/tiny.c:3`) and the `TINY_DEV`/`tiny_scale` block (`c/src/tiny.c:13-17`). The hunk context no longer matches.
- **Not tracked**: no mention in `doc/canary/backlog.md`, `status.md`, or `worklog_2026_08.md`.
- **Suggested fix**: regenerate the patch from current fixture (add `tiny_max` to both files, `git diff` it); audit the other patches in `canary/examples/tiny/scenarios/patches/` for fuzz reliance (`patch --dry-run --fuzz=0`); consider a CI assertion that every patch applies cleanly with `--fuzz=0` so drift fails loudly instead of silently.
- **Why it matters**: the mutation suite guards artifact-mutation primitives used by tiny-factory/tiny-full; a stale fixture means mutation recipes can rot without the suite noticing (the fuzzed `tiny.h` hunk is the proof it already started to).

### F2 — [HIGH for portability] Machine-specific absolute paths committed

- `src/canary/base/canary_store.ml:157-158` — `distro_base`: `Wsl → /home/red/code`, `MacOS_local → /Users/ex/code` (known; CLAUDE.md "macOS support" §1 flags the `/Users/ex/code` one).
- `src/langs/lang_sandpiper.ml:168-169` — `_pm` root hardcoded to `/home/ex/code/tola/_pm` / `/Users/ex/code/tola/tola/_pm`.
- `Makefile.misc.mk:4-6` — `CANARY_Z3_PREFIX/SRC/WORKTREE` default to `/home/ex/code/ocaml-build-examples/...`.
- `canary/templates/opam-local-repo/packages/llvm/llvm.dev-shared/opam:19-31` and `conf-llvm-shared.dev/opam:8-14` — default build dir `/home/red/code/contrib/llvm-all/build` (another machine's path than `/home/ex`!).
- `src/binding/ocamls.ml:14-20`, `src/binding/opam.ml:7-8` — `/home/ex/.opam/5.3.0/...` inside comments (dead code — see F5).
- **Suggested fix**: replace with env-var indirection (`TOLA_PM_ROOT`, `CANARY_BUILD_DIR` etc. — the opam templates already honor `CANARY_BUILD_DIR` as override, the *default* is the problem); or centralize per-machine paths in `canary_store_config` / a single env-loaded config module. Blocks the macOS / new-machine onboarding story.

### F3 — [MEDIUM] Generated run outputs are tracked under `docs/canary` → constant churn

- **Evidence**: `git ls-files docs | wc -l` = 379; `du -sh docs/canary` = 54 MB; working tree currently has **76 dirty files** (52 untracked + 24 modified), all under `docs/canary/projects/{llvm,z3,ssl,...}` (per-run JSON/log/HTML).
- `.gitignore` already excludes `docs/canary/projects/{tiny,tiny-full,tiny-full-thin,sqlite}/` — z3/llvm/ssl/cairo still tracked.
- **Suggested fix**: stop tracking per-run artifacts (keep `docs/canary` for Pages via a curated/CI-copied subset, e.g. only `result.html`/`run_info.json` or diagrams); or extend the ignore list to all `docs/canary/projects/*/-run/` + `inspect_*.json`. Every canary run currently dirties the tree and buries real diffs.

### F4 — [MEDIUM] No interface files anywhere (155 `.ml`, 0 `.mli`)

- ~31k LOC of `.ml` with zero `.mli`. Canary's layer discipline (base→surface→tool→action→backend) is enforced only by dune library deps + convention (see `src/canary/dune` header comment).
- `src/canary/dune` uses `(wrapped false)` + `include_subdirs unqualified` → every file is a flat top-level module; name collisions across layers are possible (e.g. `Canary_store` vs `store` vocab).
- **Suggested fix**: incremental — add `.mli` for cross-layer public surfaces (`canary_basic`, `canary_store`, `canary_step_model`, `canary_action`, `canary_compat`) to freeze the vocabulary; revisit `wrapped false` if the flat namespace bites.

### F5 — [MEDIUM] Orphaned `src/binding` (~1880 LOC, 15 modules)

- CLAUDE.md documents it as orphaned ("still building but unreferenced from any live entry point"), but `src/canary/dune` still lists `binding` in its `(libraries ...)` and `src/bin/dune` links it into every executable.
- This session's grep found no live references to `src/binding` modules (`Binding.*` hits in canary are `Canary_artifact_mutation.Binding` / `Canary_basic.Binding` — different modules). The old `canary.ml` (417 LOC, "old canary model") and `shared_library.ml`/`ocamls.ml` overlap with current canary tooling.
- **Suggested fix**: delete `binding` from `canary_lib`/`src/bin` library lists, confirm build stays green, then retire the directory (per CLAUDE.md's own incremental-migration note — migrate anything still valuable like `shared_library.ml` first, then delete). Carries machine-specific comments (F2).

### F6 — [MEDIUM] Dependency hygiene: stale dune-project claims, likely-unused deps

- `dune-project` comment says ocamlgraph / color-brewery are "obviously not related to this project" — **false**: `src/interp/dd_interp/dd_graph.ml:47-49` uses `Graph.Graphviz.Dot` and `Color_brewery`. `cmarkit` is used by `lang_md.ml` / `md_expand.ml`.
- Zero direct references: **`fpath`** (listed in both `src/canary/dune` and `src/bin/dune`; 0 hits in `src/**/*.ml`) and **`logs`/`logs.lwt`** (`src/bin/dune`; 0 hits; `lwt` itself is used by `src/packaging/sys_utils.ml`).
- `dune-project` formatting is mangled (mixed tabs/spaces, stray comment `; pip3 install pyyaml`) and `tola.opam` description is the placeholder "I shall better \nwrite a better description."
- **Suggested fix**: prune `fpath`, `logs`, `logs.lwt`; fix the comment/formatting; write a real opam description. Run `dune build` after each removal to confirm.

### F7 — [MEDIUM] CI does not run the project's own tests

- `.github/workflows/canary_ci.yml` (+ `debug.yml`) are single-purpose: LLVM-19 and SQLite fetch/probe shell pipelines, `ubuntu-latest` only. No `dune build`, no `dune runtest`, no `artifact-test`/`project-test`/`mutation-test` in CI — so **F1 would have been caught only locally**.
- `canary ci` / `canary debug` (`src/bin/canary_main.ml:1531,1545`) generate `canary_ci.yml` / `debug.yml` into `.github/workflows` (default), but the checked-in files carry hand-tuned bits (path filters, `continue-on-error`); drift between generator output and checked-in file is unchecked. `cache-sync` hardcodes `--workflow=canary_ci.yml` (`canary_main.ml:1396`).
- CLAUDE.md "macOS support" tracks the runner matrix as a known gap (`canary_gh.ml:174` renders `runs-on: %{runner_os}`, default `ubuntu-latest`).
- **Suggested fix**: add a `test` job (setup-ocaml → `opam install . --deps-only --with-test` → `dune build` → `dune runtest` → `canary artifact-test` + `project-test` + `mutation-test`) gated on `src/**`+`canary/**`; add a CI check that `canary ci` output is byte-identical to the committed workflow.

### F8 — [LOW/MEDIUM] Tooling nits

- **a. Dead Makefile targets**: `Makefile.misc.mk` `canary.ci.install.cmd/.local`, `canary.ci.native.link.cmd/.local` reference `contrib/canary/opam-local-repo/...` which does not exist (actual: `canary/templates/opam-local-repo/...`). Either fix the paths or delete the targets.
- **b. No formatting enforcement**: `.ocamlformat` is 0 bytes; `ocamlformat` is a dependency but nothing checks format (no CI step). Style drift is already visible (`dune-project`, mixed conventions).
- **c. Redundant test alias**: `test/test-source/dune` has `(rule (alias cur) (action (run ./test_boat.exe)))` but `test_boat` is also in the `(tests ...)` stanza, so it already runs under `dune runtest`. The `cur` alias is dead weight (or its intent — a separate demo run — should be documented).
- **d. `canary/scripts/__pycache__/`** exists in the worktree (ignored only via `*.pyc`); add `__pycache__/` to `.gitignore`.

### F9 — [LOW/MEDIUM] Code-quality patterns

- `assert false` as an impossible-case in real code: `src/canary/projects/canary_project_sqlite.ml:353` (match on `sqlite_python_config`; `Ocaml_config _ -> assert false`). Prefer an explicit `failwith`/error value so a config drift surfaces as a message, not an assertion.
- 43 `Sys.command` call sites in `src/canary`+`src/bin` execute interpolated shell strings (`canary_local_runner.ml:113` is the core one). The born-safe id convention (no `:`/spaces in ids, `canary_enumerate.string_of_id`) is a real mitigation; a typed argv exec helper would remove the remaining quoting risk for paths-with-spaces.
- Error swallowing: `Canary_local_runner.load_cache` (`canary_local_runner.ml:94`) does `try ... with _ -> make_cache ()` — a corrupted cache JSON is silently discarded; log a warning. Same pattern in `cache_of_json` (`canary_local_runner.ml:61`).
- 18 `TODO/FIXME` comments in `src/` — half in legacy `src/binding`/`src/packaging`; several are decade-old open questions (e.g. `src/packaging/spec.ml:25` "should be regex"). Good candidates for a sweep: keep, convert to tracked ids, or delete.

### F10 — [LOW] Documentation drift

- `README.md` still contains a self-labeled "**Below are legacy README. A new one is being written.**" section (the file's first half is current, second half is the old README).
- Two doc trees: `doc/` (source of truth) vs `docs/` (54 MB GitHub Pages mirror, copied by hand per CLAUDE.md). No sync script/check — the mirror is only as fresh as the last manual copy.
- `doc/canary/design/tiny.md` §7 is marked stale in `status.md` ("audit queued, §2") — still stale.
- Root-level `meeting.md` / `meeting_note.md` are worklog-ish notes; consider moving under `doc/` or the worklog dir.
- CLAUDE.md is 58 KB and is the *de facto* full handoff doc (intentional per its own "Handoff Workflow" section) — fine, but the audit doc should link it rather than duplicate.

### F11 — [LOW] Repo hygiene

- **Stale submodule declaration**: `.gitmodules` declares `vendor/multiverse/arbipher` (url `github.com/arbipher/multiverse`), but HEAD tracks it as a *regular tree* (`git ls-tree` = `040000`, no gitlink `160000`) containing only **3 files** (LICENSE + 2 `lt_multipart/*/main.json`); `.git/config` has no submodule registration and `git submodule status` is empty. The worktree also carries a leftover `.git` gitdir-pointer file (auto-ignored). Net: the declaration is inert — fresh clones get a 3-file vendored snapshot, and the `url` is never used. Decide: delete `.gitmodules` + snapshot if unneeded, or restore a real gitlink.
- `_pm/` (package-manager store) is properly ignored via `_*` — good.
- `src/bin/dune` uses `(promote (until-clean))` — promotes executable outputs into the source tree until cleaned; confirm that's intentional (it interacts with `git status` noise).

### F12 — [INFO] Positives worth preserving

- Layered canary architecture with a documented dependency order (`src/canary/dune` header) is real and mostly enforced.
- Framework tests pin environment-drift (`artifact-test` 107/107 against system fixtures) — cheap insurance.
- Python inspectors use `subprocess` with argv lists (no `shell=True`) — clean.
- Run-cache soundness is regression-tested (`cache-test` exists, guards bug B).
- No secrets found in `src/` or `canary/`.

## 4. Recommended Order of Work

1. **F1** — fix the failing mutation test first (it is the only red signal; also harden with `--fuzz=0` patch check).
2. **F7** — add a CI `test` job so F1-class regressions are caught on push; optionally add generator-vs-committed workflow diff check.
3. **F3** — stop tracking per-run canary output (biggest source of repo noise).
4. **F2** — sweep hardcoded absolute paths (also unblocks macOS / second machine).
5. **F5 + F6** — retire `src/binding` from the canary build and prune unused deps (do together; both are "remove and rebuild" tasks).
6. **F8/F9/F10/F11** — triage as convenient; low risk, mostly documentation and small refactors.

## 5. How to Re-Verify

```sh
eval $(opam env)
dune build
dune runtest --force
dune exec src/bin/canary_main.exe -- artifact-test
dune exec src/bin/canary_main.exe -- project-test
dune exec src/bin/canary_main.exe -- mutation-test      # expect F1 fixed: 46/46
dune exec src/bin/canary_main.exe -- status @all
```

Cross-reference for issue numbers: active TODOs #15b, #18, #19, #25/#40, #26 and backlog #5, #9, #11, #13b, #14, #17, #27, #29/#32, #33, #34, #38, #39, #45, #16, #20, #31, #35, #41, #42 live in `CLAUDE.md` ("Current TODO") and `doc/canary/backlog.md`. F2 relates to the macOS-support track in CLAUDE.md; F3 to the `docs/canary` Pages setup.

---

## 6. File-Level Audit (Part B — general file status)

Companion to the dev-focused Part A. Covers file inventory, sizes, tracking state, and hygiene, independent of the code-quality findings.

### 6.1 Repo at a glance

| Metric | Value |
| --- | --- |
| Commits | 693 (`main`, 2025-09-05 → 2026-08-05) |
| Tracked files | 828 |
| Git object store | 3,443 objects; pack 3.93 MiB; `.git` 51 MiB incl. reflogs/loose |
| Files on disk (excl. `.git`) | 129,574 — dominated by ignored build outputs |
| Ignored disk footprint | `_out` 2.2 GB · `_build` 852 MB · `_pm` 423 MB · `src/bin` promoted `.exe` 251 MB · `canary/examples/tiny` build dirs 169 MB |
| Tracked doc trees | `docs/` 379 files (46% of repo) · `doc/` 88 · ~~`docs_ref/`~~ 9 (removed 2026-08-06) |

### 6.2 Tracked files by top-level directory

| Dir | Files | Notes |
| --- | --- | --- |
| `docs/` | 379 | GitHub Pages mirror; **250** are `projects/tiny_scenario/` run outputs |
| `src/` | 175 | 155 `.ml`, bin entrypoints, dune files |
| `doc/` | 88 | source docs: `canary/` 76, `note/` 9, `_legacy_code/` 3 |
| `canary/` | 84 | examples (tiny/llvm/z3/ssl/cairo/zarith), 11 scripts, templates, reference |
| `vendor/` | 55 | fixture projects + pm roots |
| `test/` | 16 | 6 alcotest suites + C linkings fixtures |
| ~~`docs_ref/`~~ | ~~9~~ | removed 2026-08-06 (was: duplicate z3 summaries — FA8 resolved) |
| `.claude/` | 5 | agent memory (intentional, per CLAUDE.md handoff workflow) |
| root + misc | 18 | 13 root files, `.github/` 2 workflows, `.vscode/` 2 |

### 6.3 Tracked files by extension

`json` 252 · `ml` 192 · `log` 110 · `md` 67 · `mmd` 39 · `py` 26 · `patch` 12 · `sh` 11 · `tsv` 10 · `mli` 10 · `html` 8 · `c` 7 · `opam` 6 · `yml` 4 · `txt` 4 · `toml` 2 · `mly`/`mll`/`map` 2 each.

Roughly 46% of tracked files are generated output (json+log+tsv+html+mmd+patch under `docs/`).

### 6.4 File-level findings

- **FA1 — 46% of the repo is generated Pages output; 250 files are one obsolete project's run dump.** `docs/canary/projects/tiny_scenario/` (superseded by tiny-full) contributes 250 tracked files (75 `scan_sources/*.json` + 180 build/probe logs + results). The tracked `docs/` tree is mostly data, not documentation (F3 quantified).
- **FA2 — Compiled binaries and multi-MB JSON are committed.** 4 ELF executables `docs/canary/projects/ssl*/probe_binding/ocaml/ssl_app_{core,nlv}` (3.92 MB each, mode 100755) and 4 LLVM inspect JSONs (3.0–3.6 MB) are the 8 largest tracked files (~27.7 MB) and the largest blobs in git history (3.08 MB + 1.15 MB). Binaries in a Pages tree are churn + repo weight; exclude executables from the copy-to-`docs/` step.
- **FA3 — 22 zero-byte log files are tracked** under `docs/canary/projects/{tiny_scenario,z3,llvm}/` (empty install/probe logs from failed runs). The copy-to-docs step has no non-empty filter.
- **FA4 — `src/bin` promotion pollution (251 MB).** `(promote (until-clean))` in `src/bin/dune` leaves 16 compiled `.exe` files — including retired `example_sp.exe` — in the source tree; hidden by the `*.exe` gitignore but inflating disk/backups. Prefer `_out`-based output or drop `until-clean`.
- **FA5 — `canary/examples/tiny` is 169 MB on disk** from in-tree ninja/cmake `build/` dirs (ignored via the bare `build` gitignore pattern). Fine for a fixture; a clean target would help lean clones.
- **FA6 — Odd tracked root files.** `.codex` (0 bytes, 100644) and `.ocamlformat` (0 bytes **and** executable, 100755 — empty + +x is meaningless; delete or give real content). `.nojekyll` (0 bytes) is legitimate for Pages. `.agents/` exists on disk but is empty and untracked.
- **FA7 — Accidental executable bits.** 34 tracked files are mode 100755, including OCaml sources and a `dune` file (`src/ainterp/arith_ainterp.ml`, `src/ainterp/dune`, `src/ainterp/just_sign.ml`). Harmless; a one-time `git update-index --chmod=-x` sweep is cheap.
- **FA8 — `docs_ref/` was a third doc tree — RESOLVED 2026-08-06 (deleted by user).** It held 9 tracked files (`docs_ref/canary/projects/z3/**` summary copies) duplicating `docs/canary` content with no documented purpose. Deletion is unstaged (` D` in `git status`); commit when ready.
- **FA9 — Half-committed root notes.** `meeting.md` is tracked; `meeting_note.md` (a worklog) is untracked. `doc/audit/review_2605.md` is untracked by design until reviewed.
- **FA10 — `.mli` precision (refines F4).** The 10 tracked `.mli` live only in fixtures: `canary/examples/tiny/ocaml*/` (5) and `vendor/ocaml_projects/song_*/` (5). **Zero** `.mli` in `src/` (155 modules) — F4 stands.
- **FA11 — Vendor state.** `vendor/` = 55 tracked files: `ocaml_projects/` 26 (song_* fixtures), `pm_root/` 19, `multiverse/` 3 (inert submodule, see F11), `tola_pkgm/` 3, `python/` 2, `reference/` 2. `vendor/ir_eg/` exists untracked; `vendor/z3_dev` (a local dev symlink per `.gitignore`) is absent on this machine.
- **FA12 — History weight is healthy.** Largest blobs are the LLVM inspect JSONs (3.08 MB, 1.15 MB) and ssl binaries; total pack is 3.93 MiB over 693 commits. No bloat crisis, but the >1 MB tracked files keep the pack bigger than the code alone deserves.

### 6.5 Ignored on-disk state (this dev machine)

| Path | Size | Contents |
| --- | --- | --- |
| `_out/canary` | 2.2 GB | per-scenario run trees (by design) |
| `_build` | 852 MB | dune build tree |
| `_pm/root` | 423 MB | package-manager store roots |
| `src/bin/*.exe` | 251 MB | promoted executables (FA4) |
| `canary/examples/tiny/*/build` | ~169 MB | fixture build trees (FA5) |

Nothing here needs fixing for correctness; a `clean` target that removes `src/bin/*.exe` and the fixture build dirs would help anyone on a small disk.

**File-level recommended order**: FA2/FA3 (stop committing binaries + empty logs) → FA1 (un-track `tiny_scenario` outputs) → FA4/FA5 (clean target) → FA6–FA9, FA12 (trivial hygiene). These are all low-risk and independent of the Part A dev findings.

---

## 7. File Content & Directory Structure Audit (Part C)

Focus: how the *current* tree is organized — placement, naming, duplication, dead references, ignore-list consistency. (History/blobs covered in §6.4 FA12.)

### 7.1 Naming & layout findings

- **NC1 — Two doc trees with confusable names** (`docs_ref/`, a third, removed 2026-08-06). `doc/` (source docs, 88 files) vs `docs/` (GitHub Pages mirror, 379 files) differ by one letter; they share **zero** filenames — complementary (markdown vs generated run artifacts), not mirrors, which is fine but undocumented.
- **NC2 — `summary_*` vs `inspect_*` rename incomplete.** 8 `summary_*` files remain in `docs/` (the other 8 lived in the now-deleted `docs_ref/`) vs 204 `inspect_*`. `docs/canary/projects/{z3,llvm,ssl}/**` has mixed `summary_*.json` + `inspect_*.json`. CLAUDE.md already chronicles a sed-corruption incident from this same `_summary→_inspect` rename — the leftover names are the visible tail of it.
- **NC3 — Leading-dash directory names.** 56 tracked files live under `docs/canary/projects/*/-run/`. `-run` sorts oddly, breaks naive globs (`*/run/*`), and reads as a flag to shell tooling. Rename to `run/` (or `_run/`) in the copy-to-docs step.
- **NC4 — "examples" means five different things.** `src/example/` (library of language demos), `src/repl/examples/` (repl scripts), `canary/examples/` (canary fixture projects), `test/sample/linkings/` (C linking fixtures used by `lang_sandpiper.ml`), `vendor/ocaml_projects/`+`vendor/pm_root/` (vendored fixture projects for sandpiper). Same word, five roles, no naming convention distinguishing fixtures from demos.
- **NC5 — Code lives inside doc trees.** `doc/_legacy_code/` (12 files incl. a full retired Python harness), `doc/note/` (a grab bag: `modeling.ml`, `sandpiper_demo.ml`, `diagram_dsl.py`, `scan_libz3.log`, `.mmd`, `.png`), and `canary/reference/backend_yaml/` (retired YAML backend templates) + `canary/reference/llvm_configura.sh` (typo in filename). Consider consolidating retired code under `doc/_legacy_code/` and separating raw notes from code.
- **NC6 — Root clutter.** `meeting.md` (stale note with typos, tracked) sits next to untracked `meeting_note.md` (half-committed). `README.md:58-62` has an **empty** section (`# tola Commandline Tool Usage` — no body before `# Glossary (t.b.c.)`) and still contains the self-labeled legacy README block. `CLAUDE.md` (58 KB) is the real project guide — README should say so and shrink.
- **NC7 — Machine-specific `.claude/settings.local.json` is committed.** It carries an absolute-path permission allowlist (`/home/red/...`), personal `curl` probes, and a plugin script path. A "local" settings file should be gitignored or de-personalized (same portability family as F2).
- **NC8 — `src/bin/debug/`** ships 6 tracked debug executables (`arith_fix`, `cmd_demo1/2`, `superego`, `try_fix`) inside the production bin tree.
- **NC9 — Vendor junk.** `vendor/ir_eg/` holds only compiled leftovers (`.cmi/.cmx/.o`, untracked, on disk); `vendor/tola_pkgm/tola_cool/` is a scratch Python package (`foo.py`, `foo2.py`). Both look accidental.
- **NC10 — Broken relative links in a live design doc.** `doc/canary/design/tiny.md` links `../../src/...` (lines 102, 172, 235) which resolves to `doc/src/...` — needs `../../../src/...`. Also links `../../CLAUDE.md` (needs `../../../CLAUDE.md`).
- **NC11 — Doc index points at missing files.** `doc/canary/README.md` (the doc-tree map) says *start with* `research/surface.md` and links `research/drafting.md` — **neither exists**; the manuscript actually lives at `research/surface_draft/surface.md`. Also: `design/index.md` → `../research/surface.md` (missing) and `implementation.md` (missing from `design/`); `status.md` → `enumeration_graph.md` (missing) and `canary_ssot.ml` (no such module); `ops/python_binding_gotchas.md` → `summarize_python.py` + `canary_artifact_python.ml` (old names — now `inspect_python.py`, `canary_artifact_lang.ml`); `projects.md` → `_prepare.ml`, `_baseline.ml` (never in `src/canary/projects/`). Worklog dead refs are expected (chronological); these are in *active* index docs.
- **NC12 — Pages ignore list is inconsistent.** `.gitignore` excludes `docs/canary/projects/{tiny,tiny-full,tiny-full-thin,sqlite}/` but NOT the older sibling `tiny_scenario/` (250 tracked files) — same class of generated output, opposite treatment.

### 7.2 Ignore-list & tracking consistency

| Pattern / dir | State |
| --- | --- |
| `docs/canary/projects/tiny_scenario/` | tracked (250 files) — should be ignored like its siblings (NC12) |
| `*.exe` | ignored — hides `src/bin` promotion pollution (FA4) and would hide the committed `ssl_app_*` binaries if they were not already tracked (FA2) |
| `build` (bare) | ignores any dir named `build` — hides `canary/examples/tiny/*/build` (FA5) |
| `__pycache__/` | not ignored (only `*.pyc`) — `canary/scripts/__pycache__/` and `vendor/tola_pkgm/__pycache__/` exist on disk |
| `_*` | ignores `_out/_build/_pm` etc.; exceptions force-include `doc/_legacy_code/` and `canary/examples/tiny/scenarios/_harness/` — works, but the negation list is where drift hides |

### 7.3 Current-tree map (annotated)

| Path | Role | Health |
| --- | --- | --- |
| `src/canary/` | active framework (7 layers) | good; see Part A |
| `src/{packaging,langs,interp,ainterp,std,versioning,repl,tola}/` | legacy PL layers | builds+tests green; frozen since 2025 |
| `src/binding/` | orphaned 15-module lib | dead weight (F5) |
| `src/bin/` + `src/bin/debug/` | CLI + debug exes | promotion pollution (FA4) |
| `canary/` (top-level) | fixtures, scripts, templates, retired reference | NC5, FA5 |
| `test/` | alcotest suites + C fixtures | healthy, small |
| `vendor/` | fixtures + scratch | NC9, F11 |
| `doc/canary/` | source docs (README map is the index) | NC10, NC11 |
| `doc/note/`, `doc/_legacy_code/` | notes + retired code | NC5 |
| `docs/canary/` | Pages mirror of run artifacts | F3, FA1–FA3, NC2, NC3, NC12 |
| ~~`docs_ref/`~~ | duplicate z3 summaries | removed 2026-08-06 |
| root | CLAUDE.md + README + Makefiles + dune | NC6, FA6 |

**Part C fix order** (all low-risk, docs/tree hygiene): NC11 + NC10 (fix index/links) → NC2/NC3 (unify `inspect_*`, rename `-run/`) → NC12 + FA2/FA3 (ignore policy for generated output) → NC6/NC7/NC9 (root + vendor + settings cleanup) → NC4/NC5/NC8 (consolidate examples/retired-code layout).

---
**Post-audit updates**

- 2026-08-06 — `docs_ref/` deleted by user (FA8 resolved; NC1/NC2 reworded; deletion still unstaged — commit with `git add -A docs_ref && git commit` when ready).
