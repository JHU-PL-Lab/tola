# Harness vs. canary: store/runner orthogonality

**Status:** open design tension, working around it for now. Written
2026-06-02 alongside Phase 14e.

## The two models

The tiny example exists in two parallel forms:

- **Standalone harness** ([canary/examples/tiny/scenarios/](../../canary/examples/tiny/scenarios/)).
  Mutates the live tree in place: `apply()` runs `patchelf` /
  `cp` / file renames on `canary/examples/tiny/` itself, then runs
  builds and probes, then `revert()` restores baseline. State is
  ambient — whatever the live tree looks like at any moment IS the
  state the test sees.

- **Canary** ([src/canary/projects/canary_project_tiny.ml](../../src/canary/projects/canary_project_tiny.ml)
  via [src/bin/canary_main.ml:run_tiny](../../src/bin/canary_main.ml)).
  Each variant points at a self-contained materialized workspace
  under `_cache/<scenario>/workspace/`. Source, lib, and cext live
  there. canary's per-kind stores (`tiny_stores = { source; lib_dir;
  python_cext_root; lib_filename }`) declare which workspace dir
  serves each artifact kind. State is explicit and per-variant.

Both run against the same source and produce the same contract
outcomes when configured right, but they organise responsibility
differently.

## The ideal: one form of truth, orthogonal components

Conceptually we'd want a clean factoring:

- **Stores** (= "what artifacts are available"): a directory or
  package containing source, lib, binding, app. No state of its own
  beyond "here are some files."
- **Runners** (= "what computation is performed"): a sequence of
  build / probe / inspect steps that read from stores and emit
  artifacts/logs.
- **Harness** (= "how stores are populated"): a producer that
  perturbs / patches / builds to fill a store.

Under this factoring:
- The standalone harness is a *producer + runner* fused. It
  perturbs the live tree, runs the verification, reverts.
- canary is a *runner* over named *stores*. It doesn't perturb
  anything; the harness pre-populated the stores.

Today's canary already moves halfway here: the harness produces
materialized workspaces (`_cache/<scenario>/workspace/`) and canary
consumes them. The remaining tension is that the harness's
**perturbation logic** is still partially co-designed with the
live-tree state, leaking that coupling into what ends up in the
store.

## The leaks (and the current workarounds)

Two leaks surfaced during Phase 14e when wiring c4 cmp_abi against
`abi_soname_bump`. Both are about implicit dependencies on the live
tree that hold for the harness but break for canary's workspace
consumers.

### Leak 1: cext's `DT_RUNPATH` points at the live tree

[python_cext/setup.py](../../canary/examples/tiny/python_cext/setup.py)
builds with `runtime_library_dirs=[C_BUILD]` where `C_BUILD` is
resolved at build time from setup.py's location. The resulting
`_native.cpython-*.so` carries an **absolute** RUNPATH pointing at
the live tree's `c/build/`.

Dyld searches: `LD_LIBRARY_PATH` → `DT_RUNPATH` → ld.so cache →
defaults. For literal NEEDED filenames.

- *Harness*: live tree IS the perturbed tree. RUNPATH lookup finds
  the perturbed lib. Mismatch surfaces.
- *Canary*: live tree is unperturbed (the whole point of workspaces).
  `LD_LIBRARY_PATH` is set to the workspace's lib_dir. If that doesn't
  have the cached cext's NEEDED filename (e.g. `libtiny.so.1` when
  the bumped workspace has `libtiny.so.2`), dyld falls back to
  RUNPATH and finds the unperturbed lib in the live tree. Mismatch
  hidden.

**Current workaround** ([scenarios.py:_snapshot_workspace](../../canary/examples/tiny/scenarios/scenarios.py)):
strip RUNPATH from cached `_native.cpython-*.so` files via
`patchelf --remove-rpath` at workspace materialization time. Dyld is
now forced to consult only `LD_LIBRARY_PATH`, and the workspace's
lib_dir is authoritative.

**Ideal fix.** The cext build should produce a RUNPATH-free
artifact, and runners should always set the path explicitly. Or:
build the cext fresh into the workspace at the right time, with the
workspace's `c/build/` baked in. The current single-build-then-cache
flow makes RUNPATH a baked-in lie about where the lib is.

### Leak 2: `abi_soname_bump` deletes `libtiny.so`

[scenarios.py:apply_abi_soname_bump](../../canary/examples/tiny/scenarios/scenarios.py)
bumps SONAME to `libtiny.so.2`, renames the file to `libtiny.so.2.0`,
creates `libtiny.so.2` symlink, and **deletes** `libtiny.so.1` and
`libtiny.so` symlinks. No plain `libtiny.so` exists post-apply.

The linker (`-ltiny`) looks for exactly `libtiny.so` (or
`libtiny.a`); no versioned fallback. Without `libtiny.so`, fresh
links fail with `library not found: tiny`.

- *Harness*: live tree's `_build/` cache from the prior baseline
  build still contains a working `tiny.cmxa`. dune's incremental
  build sees no source changes, reuses the cache, never re-runs the
  linker. `ocaml_build: ok` succeeds because the link doesn't
  happen.
- *Canary*: fresh per-variant workspace has no `_build/` cache.
  dune builds from scratch. Linker fails. Build halts. Downstream
  probes never run.

**Current workaround** ([scenarios.py:_snapshot_workspace](../../canary/examples/tiny/scenarios/scenarios.py)):
at workspace materialization, if `c/build/libtiny.so` is missing,
synthesize a symlink pointing at the highest-versioned
`libtiny.so.N` present. For abi_soname_bump: `libtiny.so →
libtiny.so.2.0`. Fresh dune builds succeed; the OCaml binding's
NEEDED tracks the current SONAME (libtiny.so.2). Runtime mismatch
is preserved only on the Python side because the cached cext
carries the **old** NEEDED (libtiny.so.1) from before the bump.

**Ideal fix.** The store should be self-describing: "this dir
provides libtiny via this filename." A perturbation that breaks
fresh linking should be expressed as "this store has no usable
libtiny for fresh linking" — not silently hidden by a stale cache.
Or: the harness should always emit a store that's complete for
fresh use, and rely on a separate "frozen pre-built artifact" store
for the cases where re-linking would mask the perturbation.

## Where this lands

The current fixes work and don't change the standalone harness's
behavior — they only add fixups inside `_snapshot_workspace`. They
sit at exactly the producer/consumer boundary where the leak
matters.

Longer term, the right move is probably:

1. **Make `setup.py`'s RUNPATH conditional** (or build the cext
   into the workspace fresh). RUNPATH-pointing-at-the-build-path is
   a runtime-deployment shortcut that should be opt-in, not baked
   into every produced artifact.

2. **Make the harness produce stores that are complete for fresh
   use.** If `abi_soname_bump` should test "consumer's cached
   NEEDED doesn't match provider's SONAME," the store should
   include a cached binding artifact (with the old NEEDED) *and* a
   usable lib_dir (with `libtiny.so` symlink) — split explicitly,
   not implicitly via "we don't re-link because the cache is
   there."

3. **Lift the workspace materializer's special-case logic out of
   the harness** into a generic "store sanitiser" canary owns.
   Right now `_snapshot_workspace` lives in `scenarios.py`; if the
   responsibility is "canary's store layout must be self-contained,"
   the fixups belong on canary's side.

None of this is paper-critical for the contracts work — c1, c2, c4
all fire honestly today. Worth doing when revisiting the harness
for the next round of contract coverage (c3, c5+).

## Pointer

See git commit log around Phase 14e (`canary: Phase 14e — c4 cmp_abi
wired, demoed on lib_soname_bumped`) and the surrounding 14b /
14b' / 14c / 14d commits for the workspace model's evolution.
