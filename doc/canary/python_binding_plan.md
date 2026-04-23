# Plan: Python bindings for canary projects

**Status (2026-04-23):** Steps A–D landed locally. Framework primitives
wired; sqlite/z3/llvm all have pip probe + python summary; framework tests
20/20 green.

- ✅ A — `summarize_python.py`, `Canary_artifact_python.summary_cmd`,
      `artifact-summary --kind python`
- ✅ B — sqlite: `Probe Binding` at `Wild "pip"`, stdlib-bundled, watchlist
      `connect / sqlite_version / sqlite_version_info / Connection / Cursor`
- ✅ C — z3: pip-install fallback chain (pip / python3 -m pip / uv pip),
      probe runs a real SAT, 8-name watchlist on z3 (`Solver`, `BitVec`, …)
- ✅ D — llvm: same pattern, llvmlite.binding, `llvm_version_info` surfaced
      (caught `initialize()` deprecation as a probe gotcha)

**Delete this file** after CI has validated the three projects pass with
pip probes on GH runners, and the multi-PM env concern below has a home
(resolved here, or migrated to its own plan doc / CLAUDE.md entry).
Gotchas below stay with the file until retirement.

Related downstream plan: [`pytorch_plan.md`](pytorch_plan.md) — depends on
these primitives being in place.

## Remaining work (NOT done)

Ordered by urgency.

### 1. CI validation on GH runners — near-term

The three pip probes work locally in a uv-managed environment via the
fallback chain. GH runners have `pip` in PATH so they should take the first
branch of the chain. Needs a CI push + verify. If something differs
(pip behind `python3 -m pip` only, write-permission issues, version pin
quirks), fix lands here before CI is called "validated."

Acceptance: CI run completes green on a commit that touches nothing but
a whitespace change, showing `probe_binding_pip` + `probe_binding_pip_summary`
steps green in the sqlite, z3, and llvm jobs. Install duration noted.

### 2. Multi-PM env orchestration — medium-term

Today each pip probe's shell tries `pip`, then `python3 -m pip`, then
`uv pip`. This is pragmatic but duplicates across every project spec. The
right shape is a proper `Canary_pm_pip.ml` (currently declarative-only)
that knows how to install/verify/remove a pip package across system-pip /
venv / uv contexts, mirroring `Canary_pm_opam.ml`'s structure. This becomes
load-bearing when PyTorch lands (heavier install, per-variant env isolation
needed). Flagged in [`pytorch_plan.md`](pytorch_plan.md) Open Questions.

Acceptance: fallback shell chain in project specs reduces to a single call
into `Canary_pm_pip.install_cmd ~pkg`, with the PM module picking the right
backend based on what's available.

### 3. Module-specific version extras — low-urgency

`summary.version` is `null` for z3 and llvmlite (neither module sets
`__version__`). The `extras_for(pkg, mod)` hook in `summarize_python.py`
already surfaces `sqlite_version` for sqlite3; same hook should add:

- z3: `z3.get_version()` → e.g. `(4, 15, 3, 0)` (4-tuple)
- llvmlite: already surfaces `llvm_version_info` implicitly via probe.log;
  could mirror it into `extras.llvm_version_info` for consistency with other
  summaries

Acceptance: summary-diff of two z3 runs across version bumps shows a
`version` delta that's mechanically detectable.

### 4. Attrs categorisation for denser diffs — low-urgency

`dir(module)` sizes: sqlite3 = 210, z3 = 1789, llvmlite.binding = 119. Full
`attrs` list goes into summary.json but is noisy for diffs. Group by:

- `UPPER_CASE` → constants (`SQLITE_*` codes, etc.)
- `CamelCase` → classes (`Connection`, `Solver`, `Tensor`)
- `lowercase` → functions/modules

`summarize_python.py` produces the grouped counts as separate fields; the
unfiltered `attrs` list stays for completeness but diffs render the grouped
view by default. Cheap to add, meaningful for Z3's large surface.

Acceptance: a `summary-diff` of two z3 pip probes (different z3-solver
versions) shows deltas grouped `{UPPER,Camel,lower}` with per-group counts,
not a 1789-line attr diff.

### 5. Dedicated `Pip` location tag — cosmetic

Current probes use `Canary_store.Wild "pip"` which produces step tag
`probe_binding_pip`. Fine, but a dedicated constructor `Lang_pm_pip`
would be type-level coherent with `Lang_pm` (opam). Bikeshedding territory;
revisit only if pip coverage expands to ≥5 projects or someone trips over
the distinction.

Acceptance: `location` type has `Lang_pm_pip` constructor;
`tag_of_probe_location` maps it to `"probe_binding_pip"` (unchanged); all
project specs switch from `Wild "pip"` to `Lang_pm_pip`; nothing
functionally changes.

## Gotchas (lessons retained for future Python work)

### Step A — framework primitives (sqlite3 validation fixture)

1. **Watchlist mistake in original plan**: the plan listed `version_info`
   for sqlite but only `sqlite_version_info` exists at the top level.
   Before wiring any Python watchlist, confirm names against actual
   `dir(module)` output rather than folk memory.
2. **Stdlib modules usually don't set `__version__`** — `sqlite3`
   doesn't, so `summary.version` is `null`. Version-drift detection for
   stdlib bindings must come from `extras_for(pkg, mod)` (e.g.
   `sqlite_version = "3.50.4"`).
3. **`dir(module)` surface can be large**: sqlite3 = 210 public attrs
   (mostly `SQLITE_*` error codes). Attrs list is kept in the JSON for
   completeness but not useful for raw diff. See Remaining Work #4.
4. **Error mode is structured**: `summarize_python.py` on import failure
   emits `{kind, path, error}` JSON + exits 1. Callers can distinguish
   "package missing" (error field) from "summary failed" (non-JSON).
5. **stdlib `String.concat` vs Base `String.concat`**:
   `canary_artifact_python.ml` doesn't `open Base`, so uses stdlib
   `String.concat sep list` (positional). Don't switch to Base style
   without matching the other artifact modules consistently.

### Step B — sqlite pip probe

1. **`script_spec.summary` signature needed extension**: previously
   `rule -> ... option`, which couldn't distinguish opam probe from pip
   probe (both are `Probe Binding`). Changed to
   `rule -> location option -> ...`. Three-file mechanical refactor.
2. **Location tag choice**: used `Canary_store.Wild "pip"` rather than
   extend the `location` type. Works; see Remaining Work #5.
3. **`deps_of_split_probe` forces a `fetch_binding`**: pip probe is
   tagged `Pkg` (non-Build_tree), so its deps include `fetch_binding`.
   For sqlite that's the opam sqlite3 fetch — runs fine but isn't
   conceptually required for a stdlib-bundled Python module. Projects
   with Python-only bindings would need a phony opam fetch OR a new
   "stdlib" location tag that has no deps. PyTorch's pip probe is a
   real pip install so that case doesn't trip on this.
4. **Multi-probe machinery already produced separate dirs**: previous
   `output_tag` work + `tag_of_probe_location` gave `probe_binding_pkg/`
   and `probe_binding_pip/` as siblings with their own `summary.json`
   each. No new output-dir plumbing needed.

### Step C — z3-solver probe

1. **User's `python3` is in a uv-managed venv without `pip`** —
   `python3 -m pip` fails (`No module named pip`). Pragmatic fix:
   install-command fallback chain in the probe shell:
   `pip` → `python3 -m pip` → `uv pip` → fail. Works across standard
   CI (pip in PATH), bare venvs, and uv-managed environments. Proper
   long-term fix in Remaining Work #2.
2. **`install.log` is 0 bytes when the package is already installed** —
   `uv pip install --quiet` silently no-ops; `pip install --quiet` same.
   Not a failure signal; probe succeeds because `import z3` works.
   Idempotent re-runs of `canary action` don't retrigger installs.
3. **z3 Python module has 1789 public attrs** — massive compared to
   sqlite (210) and llvmlite (119). Watchlist stays at 8 well-known
   names; full-attrs diff would be noisy (see Remaining Work #4).
4. **`version: null` for z3** — Python module doesn't expose
   `__version__`. See Remaining Work #3.
5. **Combined install + probe in one step** — pragmatic but conflates
   install-cost and probe-cost in the step's runtime. For PyTorch
   (~200 MB wheel), split into a dedicated `fetch_binding` variant for
   Pip. Flagged in `pytorch_plan.md`.

### Step D — llvmlite probe

1. **`llvmlite.binding.initialize()` is deprecated in current llvmlite**
   — raises `RuntimeError("LLVM initialization is now handled
   automatically")`. Probe updated to skip `initialize()` and
   `initialize_native_target()`. Watchlist retained both names so future
   removal shows as missing → real drift signal. Exact kind of
   deprecation-drift canary should catch; manual fix here validates the
   watchlist approach.
2. **llvmlite Python side vs opam LLVM side can be different versions**
   — current env: `llvmlite.binding.llvm_version_info = (20, 1, 8)`;
   opam LLVM is 19. This is the cross-binding drift the interface
   model targets: native C API at one version, python-side binding at
   a newer one. Canary summary captures both simultaneously.
3. **`llvm_version_info` attr is `None` before LLVM init, populated
   after** — after the deprecation fix, `import llvmlite.binding as
   llvm; print(llvm.llvm_version_info)` returns the tuple directly —
   init is implicit in module import now.
4. **119 public attrs on llvmlite.binding** — much smaller than z3's
   1789 or even sqlite3's 210. Reflects llvmlite's design (thin FFI
   wrapper vs z3's full high-level API surface). Different shapes per
   package are expected; watchlist size should scale accordingly.
