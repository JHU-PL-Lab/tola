# Tiny harness Python → OCaml migration (Phase A inventory)

**Scope.** Inventory what `canary/examples/tiny/scenarios/scenarios.py`
(1276 LOC) owns today so the OCaml port preserves the contract this
file has with its consumers. The OCaml replacement doesn't have to be
byte-identical — trivial differences (whitespace, JSON formatting,
log line shapes) are allowed; the **structural contract** below is
what must be preserved until parity is reached.

Counterpart strategic plan: `ssot.md` §9.1, §9.2.

## 1. CLI surface (must preserve)

Eight subcommands, invoked as `scenarios.py <cmd> [<name>]`:

| Verb              | Args            | What it does                                                                                     | Used by                                  |
| ----------------- | --------------- | ------------------------------------------------------------------------------------------------ | ---------------------------------------- |
| `list`            | —               | print scenario names, one per line                                                               | Makefile (`tiny/Makefile:23,98`), SSOT §5 |
| `apply`           | `<name>`        | mutate live tree per scenario (patch or binary surgery)                                          | `_harness/run.sh`                        |
| `revert`          | `<name>`        | undo apply (idempotent, called via trap)                                                         | `_harness/run.sh`                        |
| `baseline`        | —               | build clean, snapshot inspector JSONs + artifacts to `_cache/baseline/`                          | `tiny/Makefile:103`                      |
| `prepare`         | `<name>`        | apply → build → inspect → snapshot artifacts + sources to `_cache/<name>/` → revert              | `tiny/Makefile:106`                      |
| `prepare-all`     | —               | run `prepare` for every scenario sequentially                                                    | `tiny/Makefile:109`                      |
| `restore-baseline`| —               | copy `_cache/baseline/` artifacts/sources back onto live tree (no build, no apply)               | `_harness/run_cached.py`                 |
| `restore`         | `<name>`        | overlay `_cache/baseline/` + `_cache/<name>/` snapshots onto live tree → ill state at file speed | `_harness/run_cached.py`                 |
| `expected`        | `<name>`        | print scenario's per-step expected outcomes as JSON                                              | `_harness/check.py`                      |
| `confirm`         | `<name>`        | print cached `_cache/<name>/confirm_ill.json` (surface delta vs baseline)                        | ad-hoc inspection                        |

Exit code: 0 on success; non-zero on failure. JSON output goes to
stdout, logs to stderr.

## 2. Scenario record shape (must preserve as data; encoding free)

The `SCENARIOS` dict (L183-495) has 15 entries. Each entry is a
record with these fields:

```python
{
  "description": str,                      # one-line human summary
  "violates": list[str],                   # informational contract names (Symbol, Type, ABI, ...)
  "perturbs": list[str],                   # file paths relative to tiny/
  "apply":  callable () -> None,           # patch or binary surgery
  "revert": callable () -> None,           # undo
  "expected": dict[step_name -> outcome],  # per-step expected status
}
```

Two apply mechanisms exist:

1. **Patch + rebuild.** `apply_patch(name)` runs `patch -p1 <
   scenarios/patches/<name>.patch`; revert is `patch -R`. Followed
   by `rebuild_c()` for source changes that affect the C library.
   Used by 12 scenarios.
2. **Inline binary surgery.** `apply_abi_soname_bump` /
   `revert_abi_soname_bump` rename `libtiny.so.1` →
   `libtiny.so.2.0` and rewrite the SONAME (patchelf or byte
   surgery). Used only by `abi_soname_bump`.

**`expected` step names** (the keys vary across scenarios, but the
total set today is):

- `ocaml_build`, `ocaml_probe`, `ocaml_app_binding`, `ocaml_app_helper`
- `python_cext_probe`, `python_ctypes_probe`
- `cmp_symbol_ocaml`, `cmp_symbol_cext`
- `cmp_api_complete_ocaml`, `cmp_api_complete_cext`, `cmp_api_complete_ctypes`

**`expected` outcome values**: `"ok"` | `"fail"` | `"pass"` | `"skip"`.

## 3. Cache layout (must preserve)

```
canary/examples/tiny/scenarios/_cache/
├── baseline/
│   ├── inspect/<alias>.json        # clean inspector outputs (n4, bo4, bo6, bo7, bpe2, bpe3, bpc2)
│   ├── artifacts/                  # snapshot of live build outputs
│   │   ├── c_build/libtiny.so*
│   │   ├── cext/_native.cpython-*.so
│   │   └── ocaml/examples/{probe_baseline.exe, app_binding.exe, app_helper.exe}
│   └── source/                     # snapshot of PERTURBABLE_SOURCES (15 files)
└── <scenario>/
    ├── manifest.json               # scenario metadata + build status
    ├── inspect/<alias>.json        # perturbed inspector outputs
    ├── confirm_ill.json            # surface delta vs baseline (Phase 3a)
    ├── artifacts/                  # snapshot of perturbed build outputs (same shape as baseline)
    ├── source/                     # snapshot of perturbed PERTURBABLE_SOURCES (only those that changed)
    └── workspace/                  # full materialized workspace (consumed by canary)
```

Inspector aliases (`<alias>.json`): `n4` (native lib), `bo4`
(OCaml mli), `bo6` (cmxa), `bo7` (cstub .a), `bpe2` (cext dir()),
`bpe3` (cext .so undef refs), `bpc2` (ctypes dir()).

**Canary's consumption point** (`canary_project_tiny.ml:823`):

```ocaml
let cache_workspace_of ~scenario =
  [%string "%{tiny_root}/scenarios/_cache/%{scenario}/workspace"]
```

Canary reads `workspace/` directly; it doesn't shell out to
scenarios.py at runtime. The handshake is **filesystem-only**:
scenarios.py populates `_cache/`, canary reads from it. This makes
the OCaml port simpler — it just has to produce the same directory
shape.

## 4. PERTURBABLE_SOURCES (closed universe)

15 source paths the harness may perturb (`scenarios.py:675`):

```
c/src/tiny.c
c/include/tiny.h
c/tiny.map
ocaml/{tiny.ml, tiny.mli, tiny_raw.ml, tiny_raw.mli, tiny_stubs.c,
       tiny_helper/tiny_helper.ml, tiny_helper/tiny_helper.mli}
python_cext/tiny_cext/{__init__.py, _native.c}
python_ctypes/tiny_ctypes/{__init__.py, _raw.py}
```

Used both for the `perturbs` field's allowed-values and for
baseline source snapshotting.

## 5. External consumers (preservation contract)

What calls into `scenarios.py` today; every entry below must keep
working after the OCaml port (or migrate in lockstep).

| Caller                                              | Verbs used                          | Notes                                                              |
| --------------------------------------------------- | ----------------------------------- | ------------------------------------------------------------------ |
| `canary/examples/tiny/Makefile`                     | `list`, `baseline`, `prepare`, `prepare-all` | Used by `make scenarios-cached`, `make prepare/baseline`, etc.     |
| `canary/examples/tiny/scenarios/_harness/run.sh`    | `apply`, `revert`                   | The legacy live-rebuild harness; runs apply → build → probe → revert |
| `canary/examples/tiny/scenarios/_harness/run_cached.py` | `restore`, `restore-baseline`   | The fast cached harness; reads `_cache/` snapshots                 |
| `canary/examples/tiny/scenarios/_harness/check.py`  | `expected`                          | Outcome comparator; reads expected JSON                            |
| `src/canary/projects/canary_project_tiny.ml`        | (none directly — reads `_cache/`)   | Consumes the cache filesystem, not the script                      |

## 6. Subprocess dependencies

Tools `scenarios.py` shells out to (must remain available; OCaml
port wraps the same):

- `patch` (apply/revert source patches)
- `patchelf` (SONAME bump; optional — falls back to byte surgery)
- `cmake --build <c/build>` (rebuild native after patch)
- `dune build tiny.cmxa libtiny_stubs.a` (try-build OCaml binding)
- `make python_cext` (rebuild cext)
- `nm -D` / `nm -u` (symbol extraction; piped into inspect_*.py)
- `python3 canary/scripts/inspect_*.py` (the inspector scripts —
  staying Python for now; the OCaml port just shells out to them).

## 7. What is allowed to drift in the OCaml port

Trivial differences not part of the contract:

- JSON formatting (key order, indentation): the consumers parse JSON,
  not text-diff it.
- Log line wording, ANSI colour, stderr vs stdout for diagnostics.
- File mode of cached artifacts beyond rwx semantics.
- Internal helper naming, module factoring.
- Source-snapshot timestamps (`shutil.copy2` preserves mtime; OCaml
  doesn't need to match exactly).

What is **not** allowed to drift until parity is declared:

- Subcommand names + argument shape (§1)
- Scenario names (§2's 15 names, used as `list` output and cache keys)
- `expected` outcome vocabulary (`ok | fail | pass | skip`) and the
  per-step keys (§2)
- Cache directory layout (§3) — canary reads it directly
- JSON shape of cached `inspect/<alias>.json` (consumed by
  comparators) and `expected <name>` output (consumed by `check.py`)

## 8. Phase boundary (what Phase A intentionally leaves open)

Phase A is inventory only. Decisions deferred to Phase B:

- Exact OCaml type for `scenario_spec` (the §9.2 one-time spec).
  Draft sketched in `ssot.md` §9.2; refine when porting begins.
- Whether `cmd_apply`/`cmd_revert` become canary subcommands
  (`canary tiny apply <name>`) or stay behind a wrapper script.
  Recommendation: canary subcommands — removes the need for a
  separate entry point.
- Migration of `_harness/check.py` and `run_cached.py` (Python
  outside scenarios.py). These call scenarios.py through the CLI
  surface above; once that surface is OCaml-served, they continue
  working unchanged. Porting them is **out of scope for §9.1**.
- Where the `scenario_spec` list lives. Candidates:
  `src/canary/projects/canary_tiny_scenario.ml` (sibling of
  `canary_project_tiny.ml`); or
  `src/canary/projects/canary_project_tiny_scenarios.ml`. The
  shorter `canary_tiny_scenario.ml` reads better.

## 9. Phase B kickoff checklist

When Phase B starts:

- [ ] Create `src/canary/projects/canary_tiny_scenario.ml` with
      `scenario_spec` type + the 15 scenarios as data.
- [ ] Add `canary tiny-scenarios list` subcommand; assert output
      matches `python3 scenarios.py list` byte-for-byte (it should —
      same name list, same order).
- [ ] Wire `canary_project_tiny.ml`'s `tiny_ocaml_module_watchlist`
      and the `violates` contract IDs through `scenario_spec` rather
      than free-floating constants.
- [ ] Decision: which Phase C verbs land first. Recommendation:
      `list` → `apply`/`revert` → `expected` → `baseline` →
      `prepare` → `restore`/`restore-baseline` → `confirm`. Ordered
      by external-consumer dependency (Makefile uses list +
      baseline + prepare first; cached harness needs restore last).
