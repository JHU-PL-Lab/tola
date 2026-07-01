# Tiny harness Python → OCaml migration (Phase A inventory)

**Scope.** Inventory what `canary/examples/tiny/scenarios/scenarios.py`
(1276 LOC) owns today so the OCaml port preserves the contract this
file has with its consumers. The OCaml replacement doesn't have to be
byte-identical — trivial differences (whitespace, JSON formatting,
log line shapes) are allowed; the **structural contract** below is
what must be preserved until parity is reached.

Counterpart strategic plan: `ssot.md` §9.1, §9.2.

## 1. CLI surface

### 1a. Current (Python `scenarios.py`)

Ten subcommands, invoked as `scenarios.py <cmd> [<name>]`. Listed
here for reference; not all are preserved (see §1b).

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

### 1b. OCaml port — revised verb set (six)

**Design choice — sandbox-build prepare (2026-06-26).** Each
scenario builds into its own hermetic sandbox directory under
`_cache/<name>/` by copying live sources first, then patching the
copy. The live tree is never mutated; `revert` becomes structurally
unnecessary, `prepare-all` parallelises trivially, and Ctrl-C is
harmless.

**Design choice — direct compiler invocation for tiny (2026-06-26).**
Iterated three times to reach the current position:

1. First cut: shelled out to `cmake --build`, `dune build`, and
   `make python_cext` from inside `baseline`. Failed with a
   dune-in-dune lock (parent `dune exec` holds the workspace),
   fixed by `env -u INSIDE_DUNE`.
2. Second cut: baseline became **verifies-only**; orchestration
   moved to a `make canary-tiny-baseline` target that chained
   cmake + dune + make. Cleaner separation but split the
   workflow across shell and OCaml.
3. **Current** — direct compiler invocation. For artifacts *canary
   owns* (tiny is designed by canary, not upstream), the "owner
   decides the build" principle picks `gcc` / `ocamlfind
   ocamlopt` / `ar` over cmake/dune/make. Baseline is
   self-contained again, and the dune-in-dune / build-system
   mismatch problems dissolve — there's no external build system
   invoked at all.

Concrete build steps (~11 compiler calls):

- **C lib**: `gcc -c -fPIC` for `tiny.c` → `.o`, `gcc -shared
  -Wl,-soname,libtiny.so.1 -Wl,--version-script=c/tiny.map` for
  `.o` → `libtiny.so.1.0`, `ln -sf` for the two symlinks.
- **OCaml binding**: `ocamlfind ocamlopt -c` for each of the
  four `.mli`/`.ml`; `gcc -c -fPIC -I$(ocamlc -where)` for
  `tiny_stubs.c`; `ar rcs libtiny_stubs.a tiny_stubs.o`;
  `ocamlfind ocamlopt -a -cclib -ltiny -cclib -ltiny_stubs`
  archives the `.cmx` list into `tiny.cmxa`.
- **Python cext**: `gcc -shared -fPIC -I$(sysconfig include)
  -L<c_build> -Wl,-rpath,<c_build> _native.c -ltiny -o
  _native<ext_suffix>`.

Output paths preserved at previous cmake/dune/make locations to
avoid rippling into canary's tiny-variant sandbox
(`canary_project_tiny.ml` still uses the sandbox-dune model for
probe binaries; that's a separate scope). The
`_build/default/canary/examples/tiny/ocaml/*` paths are now
misleading (no dune produces them) but functionally fine.

**Design principle codified**: canary-owned artifacts use direct
compilers; upstream-owned artifacts (z3, llvm, sqlite) shell out
to their native build systems because canary is a guest there.

The `make canary-tiny-baseline` chain from the previous
iteration was retired — baseline owns its build again.

That collapses the CLI surface from ten verbs to six:

| Verb            | Args     | Notes                                                                                            |
| --------------- | -------- | ------------------------------------------------------------------------------------------------ |
| `list`          | —        | unchanged                                                                                        |
| `baseline`      | —        | builds clean → `_cache/baseline/`; same shape as today                                           |
| `prepare`       | `<name>` | copy source → sandbox → apply patch → build → snapshot → done. No live-tree mutation, no revert. |
| `prepare-all`   | —        | sequential; safe to parallelise later                                                            |
| `expected`      | `<name>` | unchanged                                                                                        |
| `confirm`       | `<name>` | unchanged                                                                                        |

**Retired verbs and their disposition:**

- `apply` / `revert` — used only by `_harness/run.sh` (the legacy
  live-rebuild path). Become *private OCaml helpers inside
  `prepare`*; not exposed as canary subcommands. The Python harness
  keeps its `apply`/`revert` for as long as `run.sh` lives. The
  *only* meaningful remaining use of `revert` is as an optional
  property check (proving `apply` is reversible); not workflow.
- `restore` / `restore-baseline` — exist only so `run.sh` /
  `run_cached.py` can materialise an ill state onto the live tree
  without rebuilding. Sandbox prepare already produces the snapshot
  *as* the cache directory, so canary's existing read path
  (`cache_workspace_of`) consumes it directly. No restore needed.

Implication: `_harness/run.sh` and `_harness/run_cached.py` become
Python-only legacy until Phase E retires them with the rest of the
Python harness. Canary's runtime path through `_cache/<scenario>/`
is unaffected by the verb drop.

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

## 9. Progress log

- [x] **Phase A** — inventory (this doc). Commit `16ad960`.
- [x] **Phase B** — `scenario_spec` type + 15 scenarios as data +
      `canary tiny-scenarios list`. Byte-parity with
      `python3 scenarios.py list`. Commit `1227426`.
- [x] **Phase C.5** — `canary tiny-scenarios expected <name>`.
      Outcomes-parity with `scenarios.py expected` (15/15;
      description text shortened, harmless to `check.py`).
      Commit `e2f1e36`.
- [x] **Phase C.3** — `canary tiny-scenarios baseline`. Iterated
      three times (see §1b): shell-out dune → verify-only + make
      chain → direct compiler invocation. Landed direct-compile.
      7/7 inspect JSONs + 33/33 workspace files match Python's
      output. Commits `b7ecea6`, `a64c4b4`, `2fac694`.
- [x] **Phase C.4** — `prepare <name>`. Sandbox-build per §1b:
      rsync live sources into `_cache/<name>/sandbox/`, install
      baseline cext (so NEEDED entries stay frozen for
      `symbol_version_floor`), apply patch (source-side) OR
      apply SONAME bump (post-build binary surgery), direct-compile
      C lib + OCaml binding in sandbox, run 7 inspectors, compute
      surface delta vs baseline via `surface_delta` (mirrors
      Python `_surface_delta`; diffs `symbols/requires/vals/attrs/
      modules/soname/needed`), write `confirm_ill.json`,
      materialize workspace. All 15 scenarios produce correct-shape
      output. `confirm_ill.json` byte-shape matches Python for
      `symbol_missing`. Sandbox model means live tree stays clean
      across scenarios — Python's `apply → build → revert` chain
      is prone to leaving the tree dirty on cmake failures; ours
      isn't. Commit TBD.
- [ ] **Phase C.4b** — `prepare-all`. Trivial loop; parallelises
      free once C.4 lands (scenarios are hermetic).
- [ ] **Phase C.6** — `confirm <name>`. Prints
      `_cache/<name>/confirm_ill.json`. One file-read + stdout.
- [ ] **Phase D** — canary integration. Replace
      `canary_project_tiny.ml`'s harness-shell-out with direct
      `scenario_spec` reads. `variant_key` becomes
      `scenario_spec.name`; `Expect_compat_failure` predicates
      derive from `scenario_spec.expected` + `violates`.
- [ ] **Phase E** — delete `scenarios.py` and `_harness/`. Update
      `tiny/Makefile`, tiny README, CLAUDE.md, `ssot.md` §5 Flow.

### Retired verbs (per §1b)

`apply` / `revert` / `restore` / `restore-baseline` — remain
Python-only in `scenarios.py` for as long as `_harness/run.sh`
lives. No OCaml port; they retire with the whole Python harness
at Phase E.
