# Canary GH CI Backend Design

## Goal

Run canary action steps as GitHub Actions jobs so each step gets an independent
status check visible in the PR UI (pass/fail per `probe_binding llvm/19`, etc.)
rather than a single monolithic job result.

## Job Granularity Options

### Option A — One job per project variant

```
job: llvm-dev          (fetch_source → build_lib → build_binding → probe_binding → pack_binding)
job: llvm-19           (fetch_lib → fetch_binding → probe_binding)
job: z3-dev            (...)
job: z3-stable         (...)
```

- Steps run sequentially within a job on a shared filesystem.
- No artifact passing between jobs.
- `actions/cache` keyed on source git hash covers the heavy build.
- **GH UI**: one status per variant, not per action step.
- Matches the current shell runner model exactly.

### Option B — One job per action step (maximum granularity)

```
job: fetch_source_llvm
job: build_lib_llvm          needs: [fetch_source_llvm]
job: build_binding_llvm      needs: [build_lib_llvm]
job: probe_binding_llvm_dev  needs: [build_binding_llvm]
job: probe_binding_llvm_19   needs: [fetch_lib_llvm, fetch_binding_llvm_19]
...
```

- Best GH UI: each action step = one status badge.
- Requires `upload-artifact` / `download-artifact` for the built lib (~500 MB).
- Artifact upload/download: ~1–2 min vs build: 20–60 min (50–100× faster).
- **Complication**: llvm/dev and llvm/19 share one opam switch today
  (sequential to avoid switch conflicts). Cross-job sharing of an opam switch
  is impractical; the switch must be rebuilt or the sequencing constraint must
  be lifted.

### Option C — Hybrid (recommended starting point)

```
job: build_lib_llvm          (fetch_source → configure → build_lib)
job: pack_binding_llvm       needs: [build_lib_llvm]   (build_binding → pack_binding)
job: probe_binding_llvm_dev  needs: [pack_binding_llvm]
job: probe_binding_llvm_19   (independent: fetch_lib + fetch_binding)
```

- Heavy build isolated → cached or uploaded once.
- Probe jobs run in parallel after the build.
- GH UI shows probe results individually.
- Artifact: upload `build/lib/libLLVM.so` + `build/lib/ocaml/llvm/` (~200 MB
  stripped) rather than the full build tree.

## Cache vs Artifact Passing

| Mechanism          | Restore time (500 MB) | Retention | Best for |
|--------------------|----------------------|-----------|----------|
| `actions/cache`    | 10–30 s              | 7 days    | Build outputs keyed on source hash |
| `upload-artifact`  | 60–120 s upload + 30 s download | 90 days | Cross-job artifact passing |
| Rebuild            | 20–60 min (LLVM)     | —         | First run only |

Strategy: use `actions/cache` for the source build output (key = source git
hash + OS + compiler version). On cache miss, build and save. Probe jobs
restore the cache; if the key misses they fail fast rather than silently
rebuilding (unexpected miss = CI config problem).

## opam Switch Sharing Between Variants

Current shell runner runs llvm/dev then llvm/19 sequentially sharing one opam
switch. In GH CI, options:

1. **Keep sequential in one job**: llvm/dev and llvm/19 steps in a single
   job, in order. Simpler but single job result for both variants.
2. **Separate switches per job**: each job installs its own opam switch.
   Switch creation is fast (~2 min); binding install from local opam repo is
   fast. Cached separately. Enables true parallelism.
3. **Pre-built switch as artifact**: pack the switch directory, upload, restore.
   Fragile (absolute paths in switch).

Option 2 is the clean path for GH CI. The sequencing constraint was a local
optimization (avoid rebuilding the switch) that doesn't apply when each job
gets a fresh runner.

## Local Debugging with `act`

[nektos/act](https://github.com/nektos/act) runs GH Actions workflows locally
using Docker.

- `act` on Linux or Mac runs **Linux containers** — tests the Ubuntu path.
  A local Mac running `act` does NOT test macOS CI; it runs a Linux image.
- Start with `ubuntu-latest` mapped to the official `ubuntu:22.04` image or
  the `catthehacker/ubuntu:act-22.04` image (has more pre-installed tools).
- GH macOS runners are real VMs (paid minutes). For macOS-specific testing,
  use actual GH runners or invoke `canary action <project>` directly on a
  macOS host (the local runner in `backend/canary_local_runner.ml`
  executes the same `script_spec` that `backend/canary_gh.ml` renders
  into YAML — both are sibling backends consuming the step list built by
  `action/canary_step_builder.ml`).

Workflow for iteration:
```sh
act push -j probe_binding_llvm_dev   # run a single job
act push --dry-run                   # validate workflow structure
```

Custom image to pre-install opam + apt-LLVM avoids re-installing on every
`act` run. Dockerfile lives at `canary/docker/ubuntu.Dockerfile`.

## Mapping from `step` to GH Job

Each `step` has:
- `tag`: unique identifier (e.g., `fetch_source`, `probe_binding.dev`)
- `deps`: list of upstream step tags
- `cmd`: shell command string
- `check_post`: filesystem predicate (maps to job output check)
- `expectation`: `Expect_success | Expect_failure {...}`

GH YAML generation from `derive_steps`:
- One workflow job per `step` (Option B/C).
- `needs:` = `List.map step.deps ~f:tag_to_job_id`.
- Step body = `cmd` wrapped in `|| exit 1`.
- `continue-on-error: true` + explicit exit-code check for `Expect_failure`
  steps (job must succeed even though the command fails; the log must contain
  the expected string).
- Cache restore/save wraps `build_lib` and `build_binding` jobs.

## Implementation (2026-04-22) — Option A chosen

One GH job per project variant; each `step` becomes one GH step within
the job. Steps share the runner filesystem — no artifact passing needed.

### Chosen per-project CI strategy

| Project | Strategy | Rationale |
|---------|----------|-----------|
| LLVM 19 | `no_source`: apt lib + opam binding | Source build too slow (~60 min) |
| Z3 dev  | `pack_binding` (opam remote fetch) | No prebuilt OCaml binding in opam |
| SQLite  | `no_source`: apt lib + opam binding | No source build needed |

**Z3 special case**: `cmake_build_binding=false` in CI. `pack_binding` substitutes
`CANARY_Z3_SRC` with a remote git URL; opam clones and runs cmake+ninja internally.
CI never runs configure/build_lib/build_binding as visible steps — they're opaque
inside the opam sandbox. `probe_binding_build` is also skipped (no cmake build tree).

### Expect_failure rendering

`Expect_failure { contains_any }` maps to two GH steps:
1. `continue-on-error: true` + `id:` on the run step.
2. A verify step checks `steps.<id>.outcome` ≠ success, then greps the log for
   the expected message. Used for LLVM 19 probe_binding (API mismatch detection).

### preamble_steps

`job_spec.preamble_steps : string list` holds raw YAML step blocks inserted
after `setup-ocaml` and before `sys_deps`. Used to add `mozilla-actions/sccache-action`
to the Z3 job. The `triggers` parameter on `render_workflow` controls the `on:` block.

### debug.yml

`dune exec -- debug-ci` generates `.github/workflows/debug.yml`:
- Trigger: `workflow_dispatch` only (never runs automatically).
- Jobs: SQLite only (~2 min).
- Use when iterating on CI plumbing without waiting for the 33-min Z3 build.

## Action Coverage: Local vs CI

The 15-pattern table (`dune exec -- paths`) shows all structural patterns.

| Pattern | Local Z3 | Local LLVM | Local SQLite | CI Z3 | CI LLVM | CI SQLite |
|---------|----------|------------|--------------|-------|---------|-----------|
| 1 fetch_source | ✓ dev | ✓ dev | — | — | — | — |
| 2 fetch_lib | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3 fetch_source→build_lib | ✓ dev | ✓ dev | — | (inside opam) | — | — |
| 4 fetch_binding | ✓ stable | ✓ 19 | ✓ | — | ✓ | ✓ |
| 6 fetch_source→build_lib→build_binding | ✓ dev | ✓ dev | — | (inside opam) | — | — |
| pack_binding | ✓ dev | ✓ dev | — | ✓ (opam) | — | — |
| probe_binding_build | ✓ dev | ✓ dev | — | — | — | — |
| probe_binding_pkg | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 7–15 app layer | — | — | — | — | — | — |

Key gap: CI hides Z3's cmake build inside opam — configure/build_lib/build_binding
are never direct CI steps. LLVM source build is absent from CI entirely.

## Single Source of Truth for cmake Flags

`z3_cmake_build_flags : string list` in `canary_project_z3.ml` is the one definition.

- `mk_script_spec` configure step: uses `z3_cmake_build_flags_str ~indent`
- `opam.in`: generated from `opam.in.tpl` with `%%Z3_CMAKE_BUILD_FLAGS%%` substituted
  by `render_opam_in ~tola_root` (called by `dune exec -- ci`)
- `opam.in.tpl` is the static source; `opam.in` is committed as a generated file

## Answered: Open Questions

**Expect_failure steps**: two GH steps (continue-on-error + verify), not a shell wrapper.
`|| exit 1` alone doesn't work because GH uses `set -e` and the verify logic needs
`steps.<id>.outcome` which is only available as a GH expression.

**pack_binding in CI**: yes, but via opam remote fetch. The `CANARY_Z3_SRC` variable
is substituted with `git+https://...` so opam clones and builds from the remote tag.

**Matrix strategy**: not used. Separate job definitions give cleaner failure isolation
and avoid matrix-imposed constraints on step structure.

## Gotchas

**LLVM probe_binding shows orange warning in GH UI**: The `probe_binding` step for LLVM 19
uses `continue-on-error: true` (it intentionally fails — Opcode.UncondBr not in LLVM 19).
GH shows `Error: Process completed with exit code 1` with an orange icon. This is correct;
the `probe_binding (verify)` step confirms the expected failure. Not a bug.

**OCaml 5.2 quotes constructor names in errors**: `Unbound constructor "Opcode.UncondBr"`
(with quotes), not `Opcode.UncondBr`. `Expect_failure.contains_any` must include both
forms for backwards compatibility.

**canary-local opam repo at rank 1 conflicts with `opam install z3`**: if `z3.dev/opam`
exists in the local repo (with a `git+file://` URL), `opam install z3` resolves to z3.dev
instead of the official package. Fix: keep only `opam.in` in the repo (no `opam` file);
the `opam` file is generated by `opam config subst` at pack-binding time.

**opam sandbox + remote fetch path**: when opam fetches Z3 from a remote URL, the source
lands in opam's build dir (`S=.`, `B=build`). If `CANARY_SRC_DIR`/`CANARY_BUILD_DIR` are
set to local paths (e.g., `_out/canary/_local/z3/...`), cmake gets a `src:` path that
doesn't exist in opam's sandbox. Fix: `install_env` in `pack_binding` is empty (`""`)
when `local = None` (remote fetch); opam defaults `S=. B=build` work correctly.

**sccache GH cache backend blocked by opam bwrap**: `sccache-action` sets
`SCCACHE_GHA_ENABLED=true` but opam's bwrap sandbox drops the GH Actions env vars
(`ACTIONS_CACHE_URL`, `ACTIONS_RUNTIME_TOKEN`). Result: sccache runs but uses local disk
(`~/.cache/sccache`), getting 0 cache hits across fresh runners. Fix: add `actions/cache@v4`
as a preamble step to save/restore `~/.cache/sccache` explicitly. The cache key hashes
`opam.in` so it invalidates when the Z3 build config changes.

**cmake_build_binding flag**: decouples the OCaml binding cmake build from the opam
packaging step. When `cmake_build_binding=false`, configure uses `-DZ3_BUILD_OCAML_BINDINGS=OFF`
(skips FindOCaml.cmake issues), build_binding is skipped, and pack_binding uses the
opam-fetch flow instead of the local build tree.
