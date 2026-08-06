# Issue — committed CI workflow calls scripts that no longer exist

**Status**: open, not urgent (deferred 2026-08-05 by user request)
**Found**: 2026-08-05, while tracing who calls `canary/scripts/inspect_python.py`
**Fix**: probably one command (`canary ci`) — but the diff needs eyeballing, see §5

---

## 1. The bug

`.github/workflows/canary_ci.yml` invokes `canary/scripts/summarize_native.py`,
`summarize_ocaml.py` and `summarize_python.py` — **12 call sites**. None of
those files exist. They were renamed to `inspect_*.py` in `59821a5`
(2026-05-06, an `R100` pure rename).

The workflow was last regenerated in `3eead52` (**2026-05-03**) — three days
*before* the rename. It has been stale ever since.

| script | call sites | exists? |
| --- | ---: | --- |
| `summarize_native.py` | 4 | ✗ (now `inspect_native.py`) |
| `summarize_ocaml.py` | 5 | ✗ (now `inspect_ocaml.py`) |
| `summarize_python.py` | 3 | ✗ (now `inspect_python.py`) |

Affected jobs: `llvm-19`, `z3-dev`, `sqlite`, `zarith`, `ssl`. Example
(line 122):

```yaml
- name: probe_binding_pip_summary
  run: |
    python3 canary/scripts/summarize_python.py --pkg 'llvmlite.binding' \
      --watchlist '…' > $GITHUB_WORKSPACE/…/probe_binding_pip/summary.json
```

`python3 <missing file>` exits 2. The only `continue-on-error: true` in the
whole workflow is on `probe_binding_pkg` (line 66), **not** on any of these,
so each of these steps fails its job.

## 2. Second defect in the same file: cairo has no CI job

The committed workflow defines 5 jobs. `projects/canary_run.ml`'s `ci_jobs`
defines **6** — `cairo` (landed 2026-07-23) is missing from the YAML entirely,
because the YAML predates it.

`doc/canary/projects.md` records cairo as `✓ / —` (local only, "CI job wired
in `canary_run.ml` but not yet exercised on a runner"), which is accurate but
undersells the cause: it is not *pending exercise*, it is *not in the
generated file*.

## 3. Why this stayed invisible

- **Path filter.** The workflow triggers only on `canary/**`, `src/canary/**`,
  `src/bin/canary_main.ml`, and itself (`3eead52` narrowed it deliberately).
- **The status doc claimed green.** `projects.md` had every project at
  `✓ / ✓` local/CI — a claim written before the rename and never rechecked.
  (De-staled 2026-08-05 in `3a37ed5`, which corrected the tiny rows and added
  the "CI runs the pre-A5 shape" note — but did not catch this.)
- **Nothing cross-checks generated output against the generator.** The YAML is
  a build product committed to the repo, with no test that it is up to date.

## 4. Background: why the Python scripts exist at all

Worth recording, because the instinct that prompted the search was "didn't we
retire these?" — and the answer is no, for a reason that matters here.

**The scripts were never retired.** `inspect_python.py` has four commits, all
authored by the repo owner, continuous since 2026-04-23:

| commit | date | what |
| --- | --- | --- |
| `f52c096` | 2026-04-23 | added as `summarize_python.py` |
| `59821a5` | 2026-05-06 | renamed `summarize_*` → `inspect_*` (R100) |
| `08b16ef` | 2026-06-02 | Phase 14b cache-coexistence |
| `07e81f1` | 2026-08-05 | watchlist roles (`--expect-missing`) |

`git log --all --diff-filter=D` over both names is empty; the file is present
in every one of those trees. There is no delete-then-resurrect.

**What actually got retired** — two adjacent things that are easy to conflate:

- `1a141bb` (2026-04-23) *"retire yaml/shell backends"* — that same commit
  **added** `summarize_native.py` + `summarize_ocaml.py`. The Python
  inspectors arrived as *part of* the shell-backend replacement, not as a
  casualty of it.
- The Python **tiny harness** (`run.sh` + `scenarios.py`) is the genuine
  Python→OCaml retirement (Phase E of the tiny migration), now parked at
  `doc/_legacy_code/tiny_python_harness/`.

**Why they can't simply become OCaml.** A GH runner has no canary binary to
call — the backend emits *shell* into a workflow file, so inspection has to be
a standalone, shell-invocable script. That is exactly why this class of
breakage is possible: the script name is a string in generated YAML, not a
symbol the compiler checks. Migrating `src/binding/`'s ~1880 lines of
compiler-libs inspectors (a CLAUDE.md Known Gap) would fix the local path but
**not** the CI path, which would still need a shell entry point.

## 5. The fix, and why it is not a one-liner in practice

The generator is healthy: `backend/canary_gh.ml` hardcodes no script paths —
each summary command comes from the step's `inspect` closure via
`tool/canary_artifact_lang.ml`, which names `inspect_python.py` correctly. So
a fresh generation emits the right names.

```sh
dune exec src/bin/canary_main.exe -- ci      # rewrites .github/workflows/canary_ci.yml
```

**Caveat**: that regenerates against ~3 months of backend drift, so the diff
will carry much more than the rename — the cairo job appears, and whatever
A5/A7 changed about step derivation lands too. Review the diff rather than
committing blind. Consider also whether CI should move to the generic
`project_run` path at the same time (`ci_jobs` still builds from the legacy
`runner_spec` / `mk_runner_spec` values, so CI exercises one chain per project
rather than the enumerated scenario set — A5 residue, `status.md` §A).

## 6. Follow-ups worth considering

- **Guard against recurrence**: a check that `canary ci` output matches the
  committed file (a CI step that regenerates and `git diff --exit-code`s, or a
  framework self-test). This is the actual root cause — a committed build
  product with no freshness check.
- **Related, same shape**: three call sites bypass the
  `Canary_artifact_lang` wrappers and name the script in raw shell —
  `canary_tiny_scenario.ml:2179` and `:2205` (which is what TODO #18 is
  about), plus `canary/examples/tiny/Makefile:105,108`. All three currently
  name `inspect_python.py` correctly, so they did get carried through the
  rename — but they carry the same string-not-symbol fragility and nothing
  checks them.
- **Verify on a runner** once regenerated — nobody has seen these jobs pass
  since 2026-05-03.
