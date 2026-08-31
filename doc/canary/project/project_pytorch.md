# PyTorch — the plan (candidate #4)

**Kind: plan, PARTLY LANDED.** The candidate-queue entry is
[`projects.md`](projects.md) §4 Tier 1 #4. Split out of
`design/new_project.md` 2026-08-05; moved here in the 2026-08-12
`doc/canary/project/` reorganization. Re-measured 2026-08-26, and again
2026-08-30 while landing it.

## Landed 2026-08-30 — step 1, and what it cost the plan

`canary action torch` runs two green-and-xfail scenarios;
`canary_project_torch.ml` carries the full record. Read that file's
header before this document — where they disagree, the code was measured
and this was not. In brief:

- **§0's "1 package" was measured in the DEFAULT switch, by dry-run.** In
  the canary switch `opam install torch` is **70 packages** (the Jane
  Street v0.17 stack is not there).
- **Step 1's binding pair is impossible, not expensive.** The plan said
  "measure the flip; if it is tier 3, declare the lib axis only". The
  flip does not exist: on OCaml 5.4.1, `torch.v0.16.0` and the whole 0.x
  series need `base/core < v0.17` → `ocaml < 4.12.0`, and opam answers
  *No solution found*. The lib axis is declared alone, per the plan's own
  instruction.
- **§0b's solver gate is real and harder than written** — on 5.4.1 opam
  cannot even back off to an older torch, so `opam install torch
  libtorch.2.2.1` is a flat refusal.
- **§0c's demangling call was right.** 87,877 mangled symbols inspected
  with no demangler; what it cost was mangled PREFIXES (`_ZN2at`, not
  `at::`) and a watchlist of argument-free entry points, since a mangled
  name encodes the signature.
- **A finding the plan could not have predicted**: `torch.v0.17.0` does
  not build with dune 3.23.1 (a one-line `extra_deps` fix, PR-ready — see
  [`issues.md`](issues.md) §3). The binding row therefore carries the
  stock package as a declared build xfail beside a canary-local patched
  package.
- **macOS, for whoever ports it**: opam's `libtorch` has **no arm64
  package at all** (macOS stops at `2.0.0+macos-x86_64`), while upstream
  publishes `libtorch-macos-arm64-2.2.1.zip` (55 MB) and no arm64 2.1.2.
  So on Apple Silicon the `Fetched@2.1.2` world cannot exist and only the
  Vendored 2.2.1 world can — a platform-dependent *universe*, which pass 1
  cannot express today.

**Still open**: step 2 (the Vendored 2.2.1 cell — the project's real
point), then steps 3–4 (pip, the multi-PM sweep). Step 2 needs `.zip`
support in `Canary_prebuilt` and a binding REBUILD between lib worlds
rather than a repoint, because torch compiles its shim against whichever
libtorch is present.

---

## 0. What the measurement changed (2026-08-26)

This doc was written expecting "~2 GB CUDA wheels" and a painful
source build. Measured on this box, none of that is true, and the lib
axis turns out to be the best in the registry.

| | expected | **measured** |
| --- | --- | --- |
| `opam install torch` | Jane Street stack churn | **1 package** — base/core/ppx_jane v0.17 are already in the switch |
| `opam install libtorch` | build or huge wheel | **1 package** — it unzips an official upstream binary |
| libtorch download | ~2 GB (CUDA) | **174 MB** (2.2.1 CPU) / **163 MB** (2.1.2 CPU) |
| switch damage | feared | **none** |

### 0a. The lib axis is the registry's best, and it uses §3 step 2

opam carries `libtorch` as **four versioned packages** —
`1.13.0+linux-x86_64`, `2.0.0`, `2.1.2`, `2.2.1` — each of which just
downloads an official binary from `download.pytorch.org`. That makes
PyTorch the **first project where [`landing.md`](landing.md) §3 *step 2*
applies**: the upstream project publishes a Linux prebuilt, so we take it
instead of falling through to conda-forge.

### 0b. A NEW GATE CLASS: the bound is enforced by the SOLVER

`torch` declares `conflicts: [ "libtorch" {< "2.1.0" | >= "2.2.0"} ]`, and
unlike every gate we have measured so far it bites at *resolution* time:

```
$ opam install --dry-run torch libtorch          → picks libtorch 2.1.2 (backs off from 2.2.1)
$ opam install --dry-run torch libtorch.2.2.1    → [ERROR] Package conflict! No solution found
```

Compare the ladder we have:

| gate kind | checked when | specimen |
| --- | --- | --- |
| conf presence | conf build | zlib, cairo |
| pkg-config version predicate | conf build | zstd (`--atleast-version=1.3.8`) |
| self-check in the binding's build | binding build | sundialsml, mlmpfr |
| **solver conflict** | **dependency resolution** | **torch** ← new |

The consequence for the enumeration is the interesting part: **opam will
not let the mismatch world exist.** To test a binding built for 2.1.x
against 2.2.1, the 2.2.1 lib has to be placed *outside* opam — which is
exactly `Vendored` + `Canary_prebuilt` (already downloads and unpacks
archives; the conda `.conda` path generalizes to a `.zip`). So the pair is:

- **lib `Fetched@2.1.2`** — opam `libtorch`, the world the solver allows;
- **lib `Vendored@2.2.1`** — the official zip, the world the solver forbids.

That is a deploy-mismatch cell with a *declared, upstream-authored*
reason, which is what makes it worth running.

### 0c. C++ does NOT block this — demangling is readability, not correctness

The earlier worry was that libtorch is C++ and every canary inspector is
C-symbol based. Two measurements retire it.

**First, "C++ library" has never meant "needs demangling" here.** Both C++
libraries already in the registry export a pure C ABI:

| landed C++ lib | C symbols | mangled symbols |
| --- | --- | --- |
| z3 (apt 4.8.12) | 705 `Z3_*` | **0** |
| llvm 19 | 3801 `LLVM*` | — |

That is the normal shape for a library that wants cross-language
bindings; opam even carries `bitwuzla-c` and `bitwuzla-cxx` as separate
packages for the two surfaces.

**Second, libtorch is the other case — and it still works.** libtorch has
no stable C API for what the binding needs, so `ocaml-torch` ships its own
2600-line `extern "C"` shim (`src/wrapper/torch_api.{h,cpp}`,
`torch_api_generated.*`) that is compiled *into the binding* and calls
`at::`, `c10::`, `torch::`. So the binding↔lib boundary really is mangled.
Run against a C++ library, the existing inspector handles it unchanged:

```
$ nm -D /usr/lib/x86_64-linux-gnu/libstdc++.so.6 | python3 canary/scripts/inspect_native.py \
    --path … --prefixes _ZNSt,_ZN10__cxxabiv1
  counts.total 2930 · by_prefix { _ZNSt: 1445, _ZN10__cxxabiv1: 30 }
  versioned_exports { …: "GLIBCXX_3.4.22", …: "CXXABI_1.3.10" }
```

c1's set comparison, prefix counting and symbol versioning are all string
operations, and a mangled name is just a longer string. **What demangling
buys is legibility**, not a check we cannot otherwise run — with one real
usability catch: Itanium substitution means `std::` encodes as `St`, not
`3std`, so `_ZN3std` counts **0** while `_ZNSt` counts 1445. Hand-writing
mangled prefixes needs the mangling rules, so a `nm -C` demangling option
is a comfort feature to schedule, not a prerequisite.

### 0d. The one open modelling question — multi-lib

libtorch ships `libtorch.so`, `libtorch_cpu.so`, `libc10.so` and friends.
That *looks* like D4 (named lib artifacts), and it is the same question
sundials raised. sundials settled it one way: many `.so` files from ONE
package at ONE version is **one artifact**, not several — D4 is for libs
with *independent* version axes (mpfr + gmp). libtorch is the sundials
shape, so it can land as one artifact.

Worth doing before landing, because it is cheap and the machinery exists:
run [`../raw/closure_shape_sweep.sh`](../raw/closure_shape_sweep.sh) over
the unpacked libtorch. sundials scored 82 containments; if libtorch does
too, the deploy cell has a second, independent reason to be interesting.

---

## Why PyTorch

PyTorch stresses canary's model in ways z3 / llvm don't:

1. **Same native library, many PMs.** `libtorch.so` ships via pip wheel,
   conda, homebrew, debian apt — each distributes nominally-the-same-
   version with potentially different build flags (CPU vs CUDA, compiler,
   glibc floor).
2. **Binary-only distribution.** Builds-from-source are rare and painful
   (~2 GB CUDA wheels). It's all "Pattern A with exotic locators."
3. **Strict version pinning.** opam `torch` declares
   `conflicts: libtorch { < 2.1.0 | >= 2.2.0 }`. pip's default is
   typically outside that range → classic cross-PM mismatch.
4. **Multiple library binaries.** `libtorch_cpu.so`, `libtorch_cuda.so`,
   `libc10.so`, `libc10_cuda.so` — surface needs to cover the set.

## Multi-PM matrix canary will exercise

| libtorch source     | Python torch | OCaml torch    | Expected result               |
| ------------------- | ------------ | -------------- | ----------------------------- |
| pip 2.5 (default)   | ✓ same wheel | fail           | ocaml conflicts 2.5 > 2.2     |
| pip 2.1.2           | ✓            | ✓              | happy path                    |
| pip CUDA wheel      | ✓ (on GPU)   | depends on ABI | libtorch_cpu vs libtorch_cuda |
| apt libtorch-dev    | Debian's old | fail           | debian version way too old    |
| manual download 2.1 | none         | ✓              | OCaml-only probe              |

Each row is one canary action variant; together they capture the full
"which combinations work" map.

## Watchlist seeds

- **Native (libtorch_cpu.so):** widely-used `at::Tensor::sum`, `at::empty`,
  `at::ones`, `c10::Device`, `c10::ScalarType`. Stability bellwethers
  (renamed/removed across 2.x): `at::native::_cudnn_*`, `at::quantized::*`.
  Expect a large `versioned_req` map (modern libstdc++, glibc).
- **Python (`torch`):** top-level `tensor`, `nn`, `optim`, `autograd`,
  `cuda`, `backends`, `jit`, `onnx`, `distributed`. Version markers:
  `torch.__version__`, `torch.version.cuda` (None on CPU wheel).
- **OCaml (opam `torch`):** top-level `Torch`, `Torch_core`,
  `Torch_vision` (depopt). Constructor-level skipped — compiled probe
  catches changes.

## Implementation order (revised 2026-08-26)

Ordered so each step is runnable and checkable on its own, cheapest
first. Steps 1-2 are a complete Level-B project; 3-4 are the multi-PM
prize the doc was written for.

1. **The OCaml 2x2, opam-only.** lib `Fetched@2.1.2` x binding
   `torch v0.16 / v0.17`, probe = a small `torch_example.ml` tensor op.
   Costs two downloads and no new machinery. NOTE the binding axis is
   the expensive one: `torch` pins the Jane Street stack
   (`{>= "v0.17" & < "v0.18~"}`), so flipping to v0.16 rebuilds core —
   the tier-3 shape from
   [`opam_exclusive_store_issue.md`](opam_exclusive_store_issue.md) §3-5.
   **Measure that flip before declaring the binding pair**; if it is
   tier 3, declare the lib axis only and record why.
2. **The Vendored 2.2.1 cell** — the world opam refuses. `Canary_prebuilt`
   entry for the official zip, `probe_names_lib = true` so the world is
   asserted and not merely pointed (§3c). This is the finding: a
   deploy mismatch the package manager declares and the loader permits.
3. **Python `torch` via pip**, CPU index. Native inspect on
   `site-packages/torch/lib/libtorch_cpu.so`. Needs the venv awareness
   `Canary_pm_pip` is already missing.
4. **The multi-PM sweep** — pip x opam x apt, the matrix above.

## Open questions (decide during implementation)

- **Wheel size in CI.** CPU wheel ~200 MB tolerable; CUDA ~2 GB → skip
  in CI, run locally.
- **`LIBTORCH` env var.** opam `torch` reads `LIBTORCH` to find the
  native lib. Probe shell must export it correctly per source.
- **Pip cache.** `~/.cache/pip` can be large; consider
  `actions/cache@v4` similar to sccache. Per-variant cache keys.
- **OCaml `torch` depopts.** `torchvision` is a depopt — test with and
  without.
- **Python venv vs system pip.** Isolate per variant with a venv to
  avoid cross-contamination. `Canary_pm_pip.ml` needs venv awareness
  (already a noted gap).

## Why high-leverage

- Forces the Python inspect pipeline beyond its "sqlite3 toy" comfort zone.
- Exposes multi-PM interop modelling needs before we over-abstract a template.
- Yields a concrete "here's a mismatch canary detected" story for the
  research narrative (version-range conflicts across PMs).
- Surfaces `LD_LIBRARY_PATH` / `LIBTORCH` env-injection patterns that
  recur for tensorflow, onnxruntime, etc. — PyTorch is the cheapest way
  to work through the pattern.

Scope estimate: ~250 lines of project spec + ~30 lines of Python
example + ~50 lines of `Canary_artifact_lang` updates for venv.
Heavier than typical (z3 ~600, llvm ~470) but PyTorch pulls its weight
as a multi-PM case.
