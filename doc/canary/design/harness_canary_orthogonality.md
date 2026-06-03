# Harness vs. canary: store/runner orthogonality

**Status:** working design framing. Initial draft 2026-06-02 alongside
Phase 14e; rewritten 2026-06-03 to lead with the orthogonal vision
rather than the leaks.

## The orthogonal factoring

There are three concerns that today's tiny example tangles together
inside the standalone harness. Pulling them apart is what canary's
workspace model is converging on:

- **Stores** — *what artifacts are available*. A directory or package
  containing source, lib, binding, app. Self-describing, no state of
  its own beyond "here are some files." Provides the artifact-kind
  surfaces (`source`, `lib_dir`, `python_cext_root`, `lib_filename`,
  ...) that canary's spec consumes.

- **Runners** — *what computation is performed*. A sequence of
  build / probe / inspect steps that read from stores and emit
  artifacts / logs into a separate, shared output dir. canary's
  `run_project_multi` is the runner; the project spec
  (`canary_project_tiny.ml`) declares how to drive it.

- **Producers** — *how stores are populated*. For tiny that's the
  perturbation harness in `scenarios.py` ("apply this patch, build,
  snapshot"). For real projects it's the package manager
  ("opam install z3.4.13" produces one store; "opam install z3.dev"
  produces another).

Under this factoring:

| Concern | Today on tiny | Today on real projects (z3/llvm) | Where the running result goes |
|---|---|---|---|
| Producer | `scenarios.py apply` + harness build | `opam install` / `pip install` / `apt install` | — (producer outputs feed the store) |
| Store | `_cache/<scenario>/workspace/` | opam switch / pip env / apt-installed prefix | — |
| Runner | canary's per-variant pipeline | canary's per-version pipeline | `_out/canary/projects/<project>/<step>/` |

The synthetic-vs-natural axis maps cleanly: tiny's perturbations
*mimic* the divergences that arise naturally between real-world
package versions. Synthetic stores (perturbed-tiny caches) and
natural stores (different package installs) feed the same runner
through the same store-shaped interface. **If canary catches the
synthetic divergences on tiny, the same checks catch real-world
divergences on llvm/z3 — no contract logic changes between them.**

## Why orthogonality matters

The standalone harness ties producer + runner together: its
`apply()` mutates the live tree, then runs the verification, then
reverts. State is ambient. That's *fine for tiny's standalone
testing* — it's a small example with one well-defined live tree —
but it doesn't generalize.

For real projects there's no "apply / revert" cycle to mimic. The
producer (opam, pip, apt) just *exists* as system state. Multiple
producers coexist (opam switches, pip envs, apt packages). canary
has to consume their outputs without orchestrating them. That
requires the runner to be agnostic about how stores were populated.

Pushing the live-tree workflow toward the orthogonal factoring also
clarifies design questions the current tiny setup mostly papers
over:

- **Output dir parameterization.** If the harness's apply() / build()
  can write to any output dir (not just `c/build/` in the live tree),
  then synthetic and natural producers look the same to canary: each
  hands canary a fully-formed store at some path. No special-case
  workspace materialization needed.
- **Store boundaries.** Each artifact kind (source, lib, binding,
  app) gets a store boundary. Today `tiny_stores` has four fields
  (`source`, `lib_dir`, `lib_filename`, `python_cext_root`); for
  real projects the fields map to opam switch prefix, pip site-
  packages, apt install paths, etc.
- **Where running results live.** Always in canary's `_out/` — never
  in a store. Stores are read-only inputs.

## The remaining ties

Today's tiny harness still mixes producer + runner concerns in two
specific places (these are the "leaks" the initial Phase 14e doc
described — keeping them documented here so we don't forget what
needs untangling, but framed now as "where producer/runner aren't
yet separated" rather than as workarounds).

### 1. cext's `DT_RUNPATH` baked at producer time, used at runner time

[python_cext/setup.py](../../canary/examples/tiny/python_cext/setup.py)
builds the cext with `runtime_library_dirs=[C_BUILD]`. `C_BUILD` is
resolved at *producer time* from setup.py's location, so the
absolute path of the live tree's `c/build/` gets baked into the
cached `_native.cpython-*.so` as `DT_RUNPATH`. At *runner time* dyld
honors that RUNPATH and can find the live tree's libtiny — even
when canary's `LD_LIBRARY_PATH` points at a different store.

In the orthogonal picture: the producer is encoding runner-time
assumptions about where the library will live. That's a layering
violation. Fixes (in increasing order of structural correctness):

- **Workspace materialization strips it** (current). Patch the
  cached cext to remove RUNPATH; runner controls path via env vars.
  Works, but the fixup lives in the producer (`scenarios.py`).
- **Producer doesn't bake RUNPATH** at all. `setup.py` drops
  `runtime_library_dirs`; runners always set `LD_LIBRARY_PATH`
  explicitly. Cleaner; matches the orthogonal vision.
- **Per-runner producer rebuild.** Rebuild the cext fresh into each
  store with that store's c/build path. Most expressive but most
  expensive — only worth it if a contract genuinely needs the
  rebuild (e.g. a future "RUNPATH integrity" check).

### 2. `abi_soname_bump` relies on the consumer side's cache

The harness's `apply_abi_soname_bump` deletes the plain `libtiny.so`
symlink. In the standalone flow that's harmless because dune's
incremental build from `_build/` doesn't re-link. In canary's flow,
each variant gets a fresh workspace with no `_build/` cache, so
fresh dune builds need a usable `libtiny.so`.

In the orthogonal picture: the producer is leaving the store in a
state that's only valid for *cached* consumers. A self-describing
store should be usable for *fresh* consumers too. Fixes:

- **Workspace materialization synthesizes the symlink** (current).
  After capturing the perturbed lib, the materializer adds back the
  plain `libtiny.so` symlink pointing at the highest-versioned
  file. Works, in `scenarios.py`.
- **Producer always emits a usable store.** The apply rule keeps
  the plain symlink (pointing at the bumped file). The runtime
  mismatch still surfaces on consumers whose cached NEEDED predates
  the bump.

## Implications for the unique-harness pass

The above are working today, so this isn't a blocker. The next
unique-harness refactor (Phase 16-ish, once the contract matrix is
complete on tiny) probably wants:

1. **Parameterize `scenarios.py`'s output destination.** Today
   apply() writes into the live tree's `c/build/`. If apply()
   accepted an output dir, synthetic producers would look the same
   as natural producers from canary's perspective: a path where the
   store materializes.

2. **Lift workspace fixups out of `scenarios.py` into a
   canary-owned "store sanitiser."** The RUNPATH-strip and
   libtiny.so-synthesis logic is about *making a store usable by
   canary's runner*, not about *implementing tiny's perturbations*.
   It belongs on the runner side.

3. **Express real-project package-manager outputs as canary
   stores.** opam's per-switch artifact tree, pip's site-packages,
   apt's `/usr/lib`/`/usr/include` — each is already store-shaped.
   What canary needs is a way to point its stores at those paths
   without the workspace materialization shim.

None of this is paper-critical for the surface-theory work — the
contracts already fire honestly through the workarounds. It's
cleanup that makes the bridge from synthetic tiny to natural
real-project stores trivial instead of bespoke.

## Cross-references

- Commit log Phase 14b…14g for the workspace model's evolution.
- [research/plan.md](../research/plan.md) Phase 15 for the
  contract-completion sequence (c5/c6/c7/c8 on tiny via hardcoded
  inspectors) that precedes the harness refactor.
- [research/surface_theory.md §2.7](../research/surface_theory.md)
  for the comparator catalogue.
