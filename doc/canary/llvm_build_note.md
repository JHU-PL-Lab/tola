# LLVM Build Notes

Last updated: 2026-04-15. For canary's source-build path on this WSL machine.

## Machine profile (this WSL)

| Resource    | Value                                                        |
| ----------- | ------------------------------------------------------------ |
| CPU         | 32 cores                                                     |
| RAM         | 32 GB (25 GB typically free)                                 |
| mold        | `/usr/local/bin/mold` ✓ (needs `ld.mold` symlink — see below) |
| sccache     | installed ✓                                                  |
| clang-23    | `/usr/bin/clang-23` ✓ (preferred over GCC for LLVM builds)   |
| System LLVM | `llvm-19-dev` → `/usr/lib/llvm-19/` (version 19.1.1)         |
| opam llvm   | `llvm.19-static` installed in default switch                 |
| Source tree | `~/code/contrib/llvm-all/llvm-project` (arbipher fork, HEAD) |
| Build dir   | `~/code/contrib/llvm-all/build` (does not exist yet)         |

---

## Three build paths — know which one you want

| Path                       | What it builds                                                | Time    | Used by                       |
| -------------------------- | ------------------------------------------------------------- | ------- | ----------------------------- |
| **A. opam `install.sh`**   | Only OCaml bindings, using system `llvm-config`               | ~5 min  | `opam install llvm`           |
| **B. Canary prebuilt**     | Nothing — probes existing system `llvm-19-dev` + opam binding | instant | `canary action llvm`          |
| **C. Canary source build** | Full `libLLVM.so` + OCaml bindings from git                   | hours   | `canary action llvm --source` |

Path A is what opam does internally when you `opam install llvm.19-static`. Its
`install.sh` runs cmake on just `llvm/bindings/ocaml/` pointing at the system
`llvm-config`. It never touches the LLVM C++ source itself.

Path C is what canary needs to test version mismatch and source-build scenarios.
The steps below are for **Path C**.

---

## Step 1 — cmake configure

**One-time mold setup** — GCC/clang's `-fuse-ld=mold` looks for `ld.mold` on
PATH. mold installs itself as `mold`, not `ld.mold`, so create the symlink:

```sh
sudo ln -sf /usr/local/bin/mold /usr/local/bin/ld.mold
```

Run from the repo root (`~/code/contrib/llvm-all/`). Source is in `llvm-project/`,
build dir is a sibling `build/`.

```sh
cd ~/code/contrib/llvm-all
mkdir -p build

eval $(opam env)    # needed so cmake finds ocamlfind for bindings

cmake \
  -S llvm-project/llvm \
  -B build \
  -G Ninja \
  -DCMAKE_C_COMPILER=clang-23 \
  -DCMAKE_CXX_COMPILER=clang++-23 \
  -DCMAKE_BUILD_TYPE=Release \
  \
  -DLLVM_TARGETS_TO_BUILD="X86" \
  -DLLVM_ENABLE_PROJECTS="" \
  -DLLVM_ENABLE_RUNTIMES="" \
  \
  -DLLVM_ENABLE_BINDINGS=ON \
  -DLLVM_BUILD_LLVM_DYLIB=ON \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  \
  -DLLVM_USE_LINKER=mold \
  -DLLVM_OPTIMIZED_TABLEGEN=ON \
  -DLLVM_PARALLEL_LINK_JOBS=8 \
  \
  -DCMAKE_C_COMPILER_LAUNCHER=sccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=sccache \
  \
  -DLLVM_BUILD_TOOLS=OFF \
  -DLLVM_BUILD_EXAMPLES=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_BUILD_RUNTIME=OFF \
  -DLLVM_ENABLE_ASSERTIONS=OFF
```

**Flag rationale:**

| Flag                     | Why                                                    |
| ------------------------ | ------------------------------------------------------ |
| `TARGETS_TO_BUILD="X86"` | Eliminate all other backends (~60% of compile time)    |
| `ENABLE_PROJECTS=""`     | No clang/etc — just core LLVM                          |
| `ENABLE_RUNTIMES=""`     | No compiler-rt/libcxx/etc                              |
| `ENABLE_BINDINGS=ON`     | Needed — this is what we want                          |
| `BUILD_LLVM_DYLIB=ON`    | Produces `libLLVM.so` for symbol compat check          |
| `LINK_LLVM_DYLIB=ON`     | Tools link against dylib, not 60+ static libs          |
| `USE_LINKER=mold`        | 5-10x faster than ld for LLVM-scale linking            |
| `OPTIMIZED_TABLEGEN=ON`  | Builds tablegen in Release even if overall is Debug    |
| `PARALLEL_LINK_JOBS=8`   | 32GB / ~2-4GB per link = 8 safe concurrent linkers     |
| `BUILD_TOOLS=OFF`        | No llvm-as, llvm-dis, etc — saves significant time     |
| `BUILD_RUNTIME=OFF`      | No compiler-rt/sanitizers                              |
| `INCLUDE_TESTS=OFF`      | No test infrastructure                                 |
| `ENABLE_ASSERTIONS=OFF`  | Default for Release; explicit avoids surprises         |

**cmake configure should complete in ~2 minutes** and print something like:
```
-- Targeting X86
-- Found OCaml ...
-- Found ocamlfind ...
```
The `Found OCaml` line confirms bindings will be built. If absent, check that
`eval $(opam env)` ran before cmake.

---

## Step 2 — Build libLLVM.so (the dylib)

```sh
ninja -C ~/code/contrib/llvm-all/build LLVM
```

**Observed build time:** ~8 min on 32 cores with clang-23 + mold + sccache
(arbipher fork, HEAD). Estimate was 45–90 min — clang-23 and sccache warm
cache account for the difference.

---

## Step 3 — Build OCaml bindings

```sh
eval $(opam env)
ninja -C ~/code/contrib/llvm-all/build ocaml_all
```

**Observed build time:** seconds (bindings are a small fraction of the LLVM build).

Expected output structure under `build/lib/ocaml/`:
```
META.llvm        ← appears after cmake configure
META.llvm_X86   ← appears after cmake configure
llvm/            ← subdirectory; appears after ninja ocaml_all
  llvm.cma  llvm.cmxa  llvm.mli
  libllvm.a          ← stub archive for core binding
  libllvm_X86.a      ← stub archive for X86 backend binding
  llvm.cmi  llvm.cmx  ...
```

Note: META files appear after cmake configure (cmake finds OCaml early).
The `llvm/` subdirectory with `.cmxa`, `.cmi`, and `lib*.a` only appears after
`ninja ocaml_all`. The `directory = "llvm"` field in `META.llvm` tells ocamlfind
to look in the `llvm/` subdirectory — so always set `OCAMLPATH` to the parent
(`build/lib/ocaml/`), not to `build/lib/ocaml/llvm/`.

---

## Step 4 — Smoke test

The `.cmxa` and `.cmi` files live in `build/lib/ocaml/llvm/` (a subdirectory).
`META.llvm` has `directory = "llvm"`, so set `OCAMLPATH` to the parent and use
`-package llvm`. Do **not** use `-I build/lib/ocaml` + explicit cmxa path — the
cmi files are not there.

Note: `llvm_example.ml` uses `create_context` (not `global_context`, which was
removed in LLVM 16+).

Run from the tola repo root:

```sh
eval $(opam env)
BUILD=~/code/contrib/llvm-all/build
PKG=$BUILD/lib/ocaml/llvm
LLVM_CONFIG=$BUILD/bin/llvm-config \
  ocamlopt -I $PKG $PKG/llvm.cmxa \
  canary/examples/llvm/llvm_example.ml \
  -o /tmp/llvm_test

/tmp/llvm_test
```

Expected output (LLVM IR for an empty module with one declared function):
```
; ModuleID = 'canary_llvm'
source_filename = "canary_llvm"

declare i32 @answer()
```

**Why `-I $PKG` not `-I $BUILD/lib/ocaml`**: `.cmi` files and `.cmxa` are in the
`llvm/` subdirectory (because `META.llvm` has `directory = "llvm"`). The parent
`build/lib/ocaml/` only contains the `META.*` files.

---

## Step 5 — Symbol check (canary's probe_binding)

```sh
STUB=$(ls ~/code/contrib/llvm-all/build/lib/ocaml/llvm/lib*.a | head -1)
PROVIDED=~/code/contrib/llvm-all/build/lib/libLLVM.so

python3 canary/scripts/assert_binary_symbols.py \
  --provided-lib "$PROVIDED" \
  --required-lib "$STUB" \
  --symbol-prefix LLVM
```

Expected: `OK: all N required symbols found`

---

## Step 6 — Install as opam package (llvm.dev-shared)

The local opam repo at `canary/templates/opam-local-repo/` includes `llvm.dev-shared`,
which installs the pre-built OCaml bindings into the opam switch without re-running cmake.

```sh
eval $(opam env)
REPO=$(pwd)/canary/templates/opam-local-repo

# Register the local repo (once per switch)
opam repo add local-llvm "file://$REPO" --rank=1 \
  || opam repo set-url local-llvm "file://$REPO"
opam update local-llvm

# Install (removes any existing llvm package first)
CANARY_LLVM_BUILD=~/code/contrib/llvm-all/build \
  opam install llvm.dev-shared -y

# Verify
ocamlfind query llvm   # → ~/.opam/default/lib/llvm
ocamlfind list | grep llvm

# Smoke test via ocamlfind
ocamlfind ocamlopt -package llvm -linkpkg \
  canary/examples/llvm/llvm_example.ml -o /tmp/llvm_opam_test
/tmp/llvm_opam_test
```

### Why `linkopts` is needed (not in official packages)

`llvm.cmxa` has embedded C options (from cmake) of the form:
```
-L$CAMLORIGIN/../.. -Wl,-rpath,$CAMLORIGIN/../..
```
`$CAMLORIGIN` is the directory containing the `.cmxa` file. In the build tree,
`build/lib/ocaml/llvm/llvm.cmxa` → `$CAMLORIGIN/../..` = `build/lib/` ✓

After `ocamlfind install`, the cmxa moves to `~/.opam/default/lib/llvm/` →
`$CAMLORIGIN/../..` = `~/.opam/default/` ✗ (`libLLVM.so` is not there).

The official `llvm.19-static`/`llvm.19-shared` packages avoid this by running
`install.sh`, which re-runs cmake on just `llvm/bindings/ocaml/` and produces
a fresh `llvm.cmxa` with `$CAMLORIGIN/../..` correct for the install destination.

`llvm.dev-shared` skips that cmake re-run (reusing the pre-built artifacts) and
compensates by appending to META:
```
linkopts = "-cclib -L<BUILD>/lib -cclib -Wl,-rpath,<BUILD>/lib"
```
This overrides the stale cmake-baked path at both link time and runtime.

---

## Makefile target (llvm-all/Makefile update)

Replace the old `ninja:` target with a canary-compatible one:

```makefile
configure:
	eval $$(opam env) && cmake \
	  -S llvm-project/llvm -B build -G Ninja \
	  -DCMAKE_C_COMPILER=clang-23 \
	  -DCMAKE_CXX_COMPILER=clang++-23 \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DLLVM_TARGETS_TO_BUILD="X86" \
	  -DLLVM_ENABLE_PROJECTS="" \
	  -DLLVM_ENABLE_RUNTIMES="" \
	  -DLLVM_ENABLE_BINDINGS=ON \
	  -DLLVM_BUILD_LLVM_DYLIB=ON \
	  -DLLVM_LINK_LLVM_DYLIB=ON \
	  -DLLVM_USE_LINKER=mold \
	  -DLLVM_OPTIMIZED_TABLEGEN=ON \
	  -DLLVM_PARALLEL_LINK_JOBS=8 \
	  -DCMAKE_C_COMPILER_LAUNCHER=sccache \
	  -DCMAKE_CXX_COMPILER_LAUNCHER=sccache \
	  -DLLVM_BUILD_TOOLS=OFF \
	  -DLLVM_BUILD_EXAMPLES=OFF \
	  -DLLVM_INCLUDE_TESTS=OFF \
	  -DLLVM_INCLUDE_BENCHMARKS=OFF \
	  -DLLVM_INCLUDE_DOCS=OFF \
	  -DLLVM_BUILD_RUNTIME=OFF \
	  -DLLVM_ENABLE_ASSERTIONS=OFF

build-dylib:
	ninja -C build LLVM

build-ocaml:
	eval $$(opam env) && ninja -C build ocaml_all

build: configure build-dylib build-ocaml
```

---

## GH CI notes (future)

Standard `ubuntu-latest` runners (2 vCPU, 7 GB) cannot build LLVM from source
in acceptable time. Options:

| Approach                               | Cost           | Notes                                          |
| -------------------------------------- | -------------- | ---------------------------------------------- |
| **Prebuilt `apt install llvm-19-dev`** | free           | Covers prebuilt path; no source mismatch tests |
| **Large runner (16 core)**             | paid           | sccache + GHA cache; `PARALLEL_LINK_JOBS=2`    |
| **Pre-baked Docker image**             | free tier risk | Build image separately, cache in GHCR          |

For large runner, install mold via apt and use `PARALLEL_LINK_JOBS=2`.

---

## Differences from old mac Makefile

| Flag                 | Old mac              | Now    | Reason                                      |
| -------------------- | -------------------- | ------ | ------------------------------------------- |
| `ENABLE_PROJECTS`    | `"clang"`            | `""`   | Clang not needed; doubles build time        |
| `ENABLE_RUNTIMES`    | `"libcxx;libcxxabi"` | `""`   | Not needed for OCaml binding                |
| `BUILD_LLVM_DYLIB`   | absent               | `ON`   | Needed for `libLLVM.so` symbol check        |
| `CCACHE_BUILD`       | `ON`                 | gone   | Deprecated; use `CMAKE_*_COMPILER_LAUNCHER` |
| `ENABLE_ASSERTIONS`  | `ON`                 | `OFF`  | Release build; assertions add cost          |
| `PARALLEL_LINK_JOBS` | absent               | `8`    | WSL has 32GB; safe at 8 parallel links      |
| `BUILD_TOOLS`        | absent               | `OFF`  | Significant time saving                     |
| `BUILD_RUNTIME`      | absent               | `OFF`  | Compiler-rt/sanitizers not needed           |
