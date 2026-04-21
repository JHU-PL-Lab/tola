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
  use actual GH runners or a macOS machine running the shell backend directly.

Workflow for iteration:
```sh
act push -j probe_binding_llvm_dev   # run a single job
act push --dry-run                   # validate workflow structure
```

Custom image to pre-install opam + apt-LLVM avoids re-installing on every
`act` run. Dockerfile lives at `canary/docker/ubuntu.Dockerfile`.

## Mapping from `action_step` to GH Job

Each `action_step` has:
- `tag`: unique identifier (e.g., `fetch_source`, `probe_binding.dev`)
- `deps`: list of upstream step tags
- `cmd`: shell command string
- `check_post`: filesystem predicate (maps to job output check)
- `expectation`: `Expect_success | Expect_failure {...}`

GH YAML generation from `derive_steps`:
- One workflow job per `action_step` (Option B/C).
- `needs:` = `List.map step.deps ~f:tag_to_job_id`.
- Step body = `cmd` wrapped in `|| exit 1`.
- `continue-on-error: true` + explicit exit-code check for `Expect_failure`
  steps (job must succeed even though the command fails; the log must contain
  the expected string).
- Cache restore/save wraps `build_lib` and `build_binding` jobs.

## Open Questions

- Do probe steps that `Expect_failure` need a separate "check the log"
  follow-up step, or can a shell wrapper handle it within the same job?
- Should `pack_binding` (opam publish to local repo) run in CI, or skip it
  and install directly from the build tree?
- Matrix strategy: could represent multiple LLVM versions as a matrix job
  (`strategy.matrix.llvm_version: [dev, 19]`) rather than separate job
  definitions. Reduces YAML duplication but ties failure granularity to matrix
  rows.
