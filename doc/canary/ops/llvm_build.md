# Building LLVM from source — the recipe that seeds canary's build tree

Written 2026-04-15, re-verified 2026-08-30. This is the **manual** build,
run by hand before `canary action llvm` touches a cold tree.

## Why a manual recipe still exists

Canary and this recipe write to the **same build directory**. llvm's spec
declares `mk_locals "contrib/llvm-all/llvm-project"`, whose default
`build_dir = "../build"` resolves to `<machine root>/contrib/llvm-all/build`
— the path below.

They do not configure it the same way. Canary's `Cmake_configure` row
passes four flags and nothing else:

```
-G Ninja -DLLVM_ENABLE_BINDINGS=ON -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_TARGETS_TO_BUILD=X86
```

No compiler choice, no linker, no compiler launcher. On a **warm** tree
that is harmless — cmake keeps the cached `CMAKE_C_COMPILER`,
`LLVM_USE_LINKER` and `CMAKE_*_COMPILER_LAUNCHER` entries this recipe put
there, and canary's four flags agree with the ones below. On a **cold**
tree canary configures with the default compiler, the default linker and
no cache, and the ~8 minute build time measured here does not apply.

So: run this once per machine to establish the build dir; canary inherits
it. Tracked as a declaration gap in
[`../project/issues.md`](../project/issues.md).

## Prerequisites

`clang-23`, `mold`, `sccache`. mold installs itself as `mold`, but
`-fuse-ld=mold` looks for `ld.mold` on PATH, so one-time:

```sh
sudo ln -sf /usr/local/bin/mold /usr/local/bin/ld.mold
```

## Configure

```sh
cd ~/code/contrib/llvm-all
mkdir -p build
eval $(opam env)          # so cmake finds ocamlfind for the bindings

cmake -S llvm-project/llvm -B build -G Ninja \
  -DCMAKE_C_COMPILER=clang-23 -DCMAKE_CXX_COMPILER=clang++-23 \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_TARGETS_TO_BUILD="X86" \
  -DLLVM_ENABLE_PROJECTS="" -DLLVM_ENABLE_RUNTIMES="" \
  -DLLVM_ENABLE_BINDINGS=ON \
  -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON \
  -DLLVM_USE_LINKER=mold -DLLVM_OPTIMIZED_TABLEGEN=ON \
  -DLLVM_PARALLEL_LINK_JOBS=8 \
  -DCMAKE_C_COMPILER_LAUNCHER=sccache -DCMAKE_CXX_COMPILER_LAUNCHER=sccache \
  -DLLVM_BUILD_TOOLS=OFF -DLLVM_BUILD_EXAMPLES=OFF \
  -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_DOCS=OFF -DLLVM_BUILD_RUNTIME=OFF \
  -DLLVM_ENABLE_ASSERTIONS=OFF
```

The choices that carry the time, in order of effect:
`TARGETS_TO_BUILD="X86"` (all other backends are ~60% of compile time),
`ENABLE_PROJECTS=""` (no clang — doubles the build), `USE_LINKER=mold`
(5–10× on LLVM-scale linking), the two `COMPILER_LAUNCHER=sccache`
entries, and `PARALLEL_LINK_JOBS=8` (~2–4 GB per link, so 8 is safe at
32 GB). `BUILD_LLVM_DYLIB=ON` is not optional — `libLLVM.so` is what the
symbol check reads.

Configure takes ~2 min and must print `-- Found OCaml` / `-- Found
ocamlfind`; if it does not, `eval $(opam env)` did not run first and no
bindings will be built.

## Build

```sh
ninja -C ~/code/contrib/llvm-all/build LLVM        # ~8 min, 32 cores warm
eval $(opam env)
ninja -C ~/code/contrib/llvm-all/build ocaml_all   # seconds
```

`ninja LLVM` builds only the dylib — `build/bin/llvm-config` is never
produced, which is why llvm's probe row points at the build libdir
directly instead of shelling to `llvm-config`.

Output lands in `build/lib/ocaml/`: the `META.*` files appear at configure
time, the `llvm/` subdirectory (`llvm.cmxa`, `.cmi`, `libllvm*.a`) only
after `ocaml_all`. `META.llvm` has `directory = "llvm"`, so `OCAMLPATH`
must point at the **parent** `build/lib/ocaml/`, never at the subdirectory.

## The opam package: `llvm.dev-shared` and why it needs `linkopts`

`llvm.cmxa` embeds `-L$CAMLORIGIN/../.. -Wl,-rpath,$CAMLORIGIN/../..`,
where `$CAMLORIGIN` is the directory holding the `.cmxa`. In the build
tree that resolves to `build/lib/` ✓. After `ocamlfind install` into
opam's flat `lib/llvm/` it resolves to the switch root ✗.

The official `llvm.19-*` packages avoid this by re-running cmake on just
`llvm/bindings/ocaml/`, producing a cmxa whose path is right for the
destination. `llvm.dev-shared` reuses the pre-built artifacts instead and
compensates in META:

```
linkopts = "-cclib -L<BUILD>/lib -cclib -Wl,-rpath,<BUILD>/lib"
```

Install it from the canary-local repo (registered at rank 1) with
`CANARY_LLVM_BUILD=~/code/contrib/llvm-all/build opam install
llvm.dev-shared -y`. Note the rank-1 shadowing gotcha in CLAUDE.md: keep
only `opam.in` in the repo, never a materialised `opam`.

Install-layout background: [`install_targets.md`](install_targets.md).

## CI

Runners cannot build LLVM from source in acceptable time, so CI takes the
prebuilt path: `canary_min.yml` runs llvm's all-fetched world only (apt
`llvm-19-dev` + opam `llvm.19-shared`), and no source-build scenario. The
alternatives, if that ever needs to change: a paid 16-core runner with
sccache + a GHA cache and `PARALLEL_LINK_JOBS=2`, or a pre-baked image in
GHCR.
