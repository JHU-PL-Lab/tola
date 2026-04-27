# Python binding integration — tracker

**Status (2026-04-24):** Steps A–D landed locally **and validated in CI**.
Framework primitives wired; sqlite/z3/llvm all have pip probe + python
summary; framework tests 20/20 green.

- ✅ A — `summarize_python.py`, `Canary_artifact_python.summary_cmd`,
      `artifact-summary --kind python`
- ✅ B — sqlite: `Probe Binding` at `Wild "pip"`, stdlib-bundled, watchlist
      `connect / sqlite_version / sqlite_version_info / Connection / Cursor`
- ✅ C — z3: pip-install fallback chain (pip / python3 -m pip / uv pip),
      probe runs a real SAT, 8-name watchlist on z3
- ✅ D — llvm: same pattern, llvmlite.binding, `llvm_version_info` surfaced;
      caught `initialize()` deprecation as a probe gotcha

**Delete this file** once the multi-PM env concern is resolved or migrated
to its own tracker, and the version-extras enhancement (#3 below) lands or
is closed as won't-do.

Lessons from the implementation pass live in
[`../ops/python_binding_gotchas.md`](../ops/python_binding_gotchas.md).
Downstream coverage plan: [`pytorch.md`](pytorch.md) — depends on these
primitives being in place.

## Remaining work (NOT done)

Ordered by urgency.

### 1. CI validation on GH runners — ✅ done (2026-04-24)

CI run 24875490174 went green with all `probe_binding_pip` and
`probe_binding_pip_summary` steps in sqlite, z3, and llvm jobs.

Two retrofits surfaced before this closed:
- An earlier commit shipped the pip probes but forgot to regenerate
  `canary_ci.yml`, so CI was green-but-not-actually-testing-pip.
- The `expectation` accessor needed extension to take `location option`
  (mirror of the earlier `summary` fix). Without it, LLVM's
  `Expect_failure { Opcode.UncondBr }` applied to the pip probe too
  and produced spurious `unexpected_success` markers.

Both fixes in commit `ae05abe`.

### 2. Multi-PM env orchestration — medium-term

Today each pip probe's shell tries `pip`, then `python3 -m pip`, then
`uv pip`. This is pragmatic but duplicates across every project spec. The
right shape is a proper `Canary_pm_pip.ml` (currently declarative-only)
that knows how to install / verify / remove a pip package across system-pip /
venv / uv contexts, mirroring `Canary_pm_opam.ml`'s structure. Becomes
load-bearing when PyTorch lands (heavier install, per-variant env isolation
needed). Flagged in [`pytorch.md`](pytorch.md) Open Questions.

Acceptance: fallback shell chain in project specs reduces to a single call
into `Canary_pm_pip.install_cmd ~pkg`, with the PM module picking the right
backend based on what's available.

### 3. Module-specific version extras — low-urgency

`summary.version` is `null` for z3 and llvmlite (neither module sets
`__version__`). The `extras_for(pkg, mod)` hook in `summarize_python.py`
already surfaces `sqlite_version` for sqlite3; same hook should add:

- z3: `z3.get_version()` → e.g. `(4, 15, 3, 0)` (4-tuple)
- llvmlite: already surfaces `llvm_version_info` implicitly via probe.log;
  could mirror it into `extras.llvm_version_info` for consistency

Acceptance: `summary-diff` of two z3 runs across version bumps shows a
`version` delta that's mechanically detectable.

### 4. Attrs categorisation for denser diffs — low-urgency

`dir(module)` sizes: sqlite3 = 210, z3 = 1789, llvmlite.binding = 119.
Full `attrs` list goes into summary.json but is noisy for diffs. Group by:

- `UPPER_CASE` → constants (`SQLITE_*` codes, etc.)
- `CamelCase` → classes (`Connection`, `Solver`, `Tensor`)
- `lowercase` → functions/modules

`summarize_python.py` produces grouped counts as separate fields; the
unfiltered `attrs` list stays for completeness but diffs render the grouped
view by default.

Acceptance: `summary-diff` of two z3 pip probes (different z3-solver
versions) shows deltas grouped `{UPPER, Camel, lower}` with per-group counts,
not a 1789-line attr diff.

### 5. Dedicated `Pip` location tag — cosmetic

Current probes use `Canary_store.Wild "pip"` which produces step tag
`probe_binding_pip`. Fine, but a dedicated constructor `Lang_pm_pip` would
be type-coherent with `Lang_pm` (opam). Bikeshedding territory; revisit only
if pip coverage expands to ≥5 projects or someone trips over the distinction.

Acceptance: `location` type has `Lang_pm_pip` constructor;
`tag_of_probe_location` maps it to `"probe_binding_pip"` (unchanged); all
project specs switch from `Wild "pip"` to `Lang_pm_pip`; nothing functionally
changes.
