# Plan: Python bindings for canary projects

**Status:** queued — framework-level Python primitives exist (`canary_artifact_python.ml`,
`canary_pm_pip.ml`), no project has wired them in yet.

**Delete this file when all three projects have a `Probe Binding` + summary
variant at `Lang_pm` (Pip) and the summary watchlists are green.**

## Current state

- ✅ `canary_artifact_python.ml` — `python_importable`, `python_import_cmd`
- ✅ `canary_pm_pip.ml` — PM ops (install / verify / query)
- ✅ `canary_artifact_test.ml:python_shell_tests` — tests the primitives
  against `sys` (pass) and `canary_nonexistent_pkg` (fail)
- ❌ No `canary/scripts/summarize_python.py`
- ❌ No `Canary_artifact_python.summary_cmd`
- ❌ `artifact-summary` CLI has no `--kind python`
- ❌ No project spec uses the Python primitives

## Target bindings

| Library | Python binding | Install | Probe import | Summary seed |
|---------|---------------|---------|--------------|--------------|
| **z3** | `z3-solver` (PyPI, official, ships w/ z3 source) | `pip install z3-solver` | `import z3; z3.Solver()` | `dir(z3)` watchlist: `Solver, BitVec, Optimize, Context, Tactic` |
| **llvm** | `llvmlite` (lightweight FFI) | `pip install llvmlite` | `import llvmlite.binding as llvm; llvm.initialize()` | `dir(llvmlite.binding)` watchlist: `initialize, parse_assembly, create_mcjit_compiler` |
| **sqlite** | `sqlite3` (Python stdlib — bundled, no install) | n/a | `import sqlite3; sqlite3.connect(':memory:')` | `sqlite3.sqlite_version` + `dir(sqlite3)` watchlist: `connect, version_info, sqlite_version_info` |

### sqlite is a special case

Python's `sqlite3` is stdlib-bundled, so "install" is a no-op. Drift comes from
the **CPython version bumping its vendored SQLite**. Summary should include
`sqlite3.sqlite_version` so a version change against a watchlist baseline is
observable. This is the simplest variant to prototype (no pip install step
needed) and exercises every other piece of the pipeline.

## Three-way coverage at probe time (goal)

| Project | Native lib | OCaml binding | Python binding |
|---------|-----------|--------------|----------------|
| z3 | libz3.so via `nm` + `z3_native_watchlist` | `Z3` module + `z3_ocaml_watchlist` | `z3-solver` via `dir(z3)` + `z3_python_watchlist` |
| llvm | libLLVM.so via `nm` + `llvm_native_watchlist` | `Llvm` module + `llvm_ocaml_watchlist` | `llvmlite.binding` via `dir()` + `llvm_python_watchlist` |
| sqlite | libsqlite3.so via `nm` + watchlist | `Sqlite3` module + `sqlite_ocaml_watchlist` | `sqlite3` stdlib + `sqlite.sqlite_version` |

Three-way probes make cross-binding drift observable: if Z3's native lib
changes, we see whether the break shows up in OCaml, in Python, or only at the
native symbol level.

## Implementation steps

### Step A — Framework primitives

1. `canary/scripts/summarize_python.py` — runs `python3 -c "import pkg; json.dump({...}, ...)"`.
   Emits:
   ```json
   {
     "kind": "python",
     "path": "<pkg>",
     "counts": { "attrs": <len(dir(m))> },
     "attrs": [ <dir(m), filtered to public> ],
     "version": "<m.__version__ if any else null>",
     "extra": { "sqlite_version": "..."  (sqlite only) },
     "watchlist": { "present": [...], "missing": [...] }
   }
   ```
2. `Canary_artifact_python.summary_cmd ~pkg ~watchlist ~output_dir ()` —
   shells out to the script, writes `summary.json`.
3. `artifact-summary` CLI: add `--kind python` branch that calls it.

### Step B — Wire into one project (recommend: sqlite — smallest blast radius)

1. Add `sqlite_python_watchlist = [ "connect"; "version_info"; "sqlite_version_info" ]`
2. Extend `canary_project_sqlite.ml:script_spec`:
   - `probe_binding` list gets a new entry at `Lang_pm` (Pip) location running
     `python3 -c "import sqlite3; sqlite3.connect(':memory:'); print('ok')"`
   - `summary` function handles `Probe Binding` at the Pip location, emitting
     `Canary_artifact_python.summary_cmd ~pkg:"sqlite3" ~watchlist:sqlite_python_watchlist`
3. Run `canary action sqlite` locally, confirm:
   - `_out/canary/projects/sqlite/probe_binding_pip/probe.log`
   - `_out/canary/projects/sqlite/probe_binding_pip/summary.json`
4. Regenerate CI; sqlite CI job picks up the new step.

### Step C — z3

1. Add `z3_python_watchlist` and a pip-install pack_binding variant (or do the
   install in the probe step).
2. Decide: is the Python z3-solver install step a new `Fetch Binding` at
   `Lang_pm (Pip)` or baked into `probe_binding_pip`? Mirror how opam binding
   handles it — probably a separate fetch step that runs once.
3. In CI, `pip install z3-solver` works out of the box (no sys deps).

### Step D — llvm

1. `llvmlite` install via `pip install llvmlite`.
2. Note: llvmlite has its own LLVM version compatibility story — LLVM 19 vs
   dev might need different llvmlite versions; pin accordingly or accept drift
   as signal.
3. `Probe Binding` at `Lang_pm (Pip)` runs a minimal initialisation.

## Open questions

- **Pip vs pip + venv**: `Canary_pm_pip.ml` handles pip at system level. For
  CI isolation we may want a per-job venv. Defer until a project actually
  needs it.
- **Pip install gating in CI**: GH runners have Python preinstalled; `pip
  install` inside bwrap (opam sandbox) won't affect the outside. Each job
  installs the Python binding fresh; no cache sharing with opam. Evaluate
  whether `actions/cache` for `~/.cache/pip` is worth it (cheap to add).
- **Python watchlist granularity**: `dir(module)` includes dunders. Filter to
  public names (`not startswith('_')`) in `summarize_python.py`, but keep
  dunder inspection available for special cases (e.g., `__version__`).

## Estimated scope

- `summarize_python.py`: ~40 lines
- `Canary_artifact_python.summary_cmd`: ~10 lines
- `artifact-summary --kind python` wiring: ~5 lines
- Each project spec: ~20 lines (watchlist, probe variant, summary wiring)

Total: ~135 lines to land all three projects, or ~75 lines to land sqlite as a
first-pass validation.
