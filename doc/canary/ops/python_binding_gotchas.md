# Python binding integration — gotchas (durable lessons)

Lessons retained from the Stage-1 Python-binding integration (sqlite, z3,
llvm). Applies to any future Python binding work. Status info moved into
the milestone log; the gotchas below are durable.

## Step A — framework primitives (sqlite3 validation fixture)

1. **Watchlist mistake in original plan** — the plan listed `version_info`
   for sqlite but only `sqlite_version_info` exists at the top level.
   Before wiring any Python watchlist, confirm names against actual
   `dir(module)` output rather than folk memory.

2. **Stdlib modules usually don't set `__version__`** — `sqlite3` doesn't,
   so `summary.version` is `null`. Version-drift detection for stdlib
   bindings must come from `extras_for(pkg, mod)` (e.g.
   `sqlite_version = "3.50.4"`).

3. **`dir(module)` surface can be large** — sqlite3 = 210 public attrs
   (mostly `SQLITE_*` error codes). Attrs list is kept in the JSON for
   completeness but not useful for raw diff.

4. **Error mode is structured** — `summarize_python.py` on import failure
   emits `{kind, path, error}` JSON + exits 1. Callers can distinguish
   "package missing" (error field) from "summary failed" (non-JSON).

5. **stdlib `String.concat` vs Base `String.concat`** — the Python
   helpers in `tool/canary_artifact_lang.ml` (which absorbed the
   former `canary_artifact_python.ml`) don't `open Base`, so they
   use stdlib `String.concat sep list` (positional). Don't switch
   to Base style without matching the other artifact modules
   consistently.

## Step B — sqlite pip probe

1. **`script_spec.summary` signature needed extension** — previously
   `rule -> ... option`, which couldn't distinguish opam probe from pip
   probe (both are `Probe Binding`). Changed to
   `rule -> location option -> ...`. Three-file mechanical refactor.
   Same lesson applied later to `expectation` (commit `ae05abe`).

2. **Location tag choice** — used `Canary_store.Wild "pip"` rather than
   extend the `location` type. Works; cosmetic gap (a dedicated
   `Lang_pm_pip` constructor would be type-coherent with `Lang_pm`).

3. **`deps_of_split_probe` forces a `fetch_binding`** — pip probe is
   tagged `Pkg` (non-Build_tree), so its deps include `fetch_binding`.
   For sqlite that's the opam sqlite3 fetch — runs fine but isn't
   conceptually required for a stdlib-bundled Python module. Projects
   with Python-only bindings would need a phony opam fetch OR a new
   "stdlib" location tag with no deps. PyTorch's pip probe is a real
   pip install so that case doesn't trip on this.

4. **Multi-probe machinery already produced separate dirs** — previous
   `output_tag` work + `tag_of_probe_location` gave `probe_binding_pkg/`
   and `probe_binding_pip/` as siblings with their own `summary.json`
   each. No new output-dir plumbing needed.

## Step C — z3-solver probe

1. **User's `python3` may be in a uv-managed venv without `pip`** —
   `python3 -m pip` fails (`No module named pip`). Pragmatic fix:
   install-command fallback chain in the probe shell:
   `pip` → `python3 -m pip` → `uv pip` → fail. Works across standard
   CI (pip in PATH), bare venvs, and uv-managed environments. Proper
   long-term fix is multi-PM env orchestration in `Canary_pm_pip`.

2. **`install.log` is 0 bytes when the package is already installed** —
   `uv pip install --quiet` silently no-ops; `pip install --quiet` same.
   Not a failure signal; probe succeeds because `import z3` works.
   Idempotent re-runs of `canary action` don't retrigger installs.

3. **z3 Python module has 1789 public attrs** — massive compared to
   sqlite (210) and llvmlite (119). Watchlist stays at 8 well-known
   names; full-attrs diff would be noisy. Categorising attrs (UPPER
   constants vs CamelCase classes vs lowercase functions) for denser
   diffs is a queued enhancement.

4. **`version: null` for z3** — Python module doesn't expose
   `__version__`. Surface via `extras_for("z3", mod)` calling
   `z3.get_version()` or `z3.get_full_version()`.

5. **Combined install + probe in one step** — was pragmatic but conflated
   install-cost and probe-cost in the step's runtime. Split into a dedicated
   `Fetch (Binding Python)` step in 2026-05 (`pip_install_cmd` /
   `python_probe_only_cmd`); summary now caches before probe runs.
   PyTorch (~200 MB wheel) benefits more from this; see
   [`../design/new_project.md`](../design/new_project.md) §4.

## Step D — llvmlite probe

1. **`llvmlite.binding.initialize()` is deprecated in current llvmlite** —
   raises `RuntimeError("LLVM initialization is now handled automatically")`.
   Probe updated to skip `initialize()` and `initialize_native_target()`.
   Watchlist retained both names so future removal shows as missing → real
   drift signal. Exact kind of deprecation-drift canary should catch;
   manual fix here validated the watchlist approach.

2. **llvmlite Python side vs opam LLVM side can be different versions** —
   current env: `llvmlite.binding.llvm_version_info = (20, 1, 8)`; opam LLVM
   is 19. This is the cross-binding drift the interface model targets:
   native C API at one version, python-side binding at a newer one. Canary
   summary captures both simultaneously. **Key Stage 1 finding** that
   shapes the Stage 3 universal abstraction (per-binding version axes are
   independent when the binding ships its own native lib).

3. **`llvm_version_info` attr is `None` before LLVM init, populated after** —
   after the deprecation fix, `import llvmlite.binding as llvm;
   print(llvm.llvm_version_info)` returns the tuple directly — init is
   implicit in module import now.

4. **119 public attrs on llvmlite.binding** — much smaller than z3's
   1789 or sqlite3's 210. Reflects llvmlite's design (thin FFI wrapper
   vs z3's full high-level API surface). Different shapes per package
   are expected; watchlist size should scale accordingly.

## Cross-cutting

**ocamlfind not always pulled by binding** — opam packages diverge in
whether they pull `ocamlfind` transitively. zarith does (legacy build);
ssl uses dune-configurator and doesn't. The probe template uses
`ocamlfind ocamlopt` directly, so `fetch_binding_cmd` now installs
`ocamlfind` explicitly after the binding (see `action/canary_action.ml`).
Caused exit-127 CI failure in the ssl probe; fix in commit `61b5c97`.

**probe.log dump on failure** — `probe_ocaml_cmd` ends with
`cat probe.log; exit $RC` so CI surfaces the actual error rather than
just the bash exit code (commit `4835865`).
