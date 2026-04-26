# Plan: PyTorch as a multi-language, multi-PM canary target

**Status:** queued — batch-2 target. Depends on Python binding primitives
(`../design/python_binding.md`) being in place first.

**Delete this file** when PyTorch is wired in with at least one working
pip-torch + opam-torch interop probe and symbol/module summaries.

## Why PyTorch

PyTorch stresses canary's model in ways Z3/LLVM don't:

1. **Same native library, many PMs**: `libtorch.so` ships via pip wheel, conda,
   homebrew, debian apt, and manual pytorch.org downloads — each distributes
   nominally-the-same-version with potentially different build flags (CPU vs
   CUDA, compiler, glibc floor).
2. **Binary-only distribution**: Unlike Z3 (source-built) or SQLite
   (apt-installable), libtorch is typically a huge binary blob (~2 GB for CUDA
   variants). Builds-from-source are rare and painful. Canary's "Pattern C
   self-building" doesn't apply; it's all "Pattern A with exotic locators".
3. **Python-first ecosystem**: PyTorch is fundamentally a Python library with
   a C++ backend. OCaml, Rust, Julia bindings exist but are all downstream of
   the Python-side conventions.
4. **Strict version pinning in bindings**: opam `torch` has
   `conflicts: libtorch { < 2.1.0 | >= 2.2.0 }` — demonstrates the
   "we support exactly this one version range" pattern. pip's default will
   typically be outside that range → classic cross-PM mismatch.
5. **Multiple library binaries, not just one**: `libtorch_cpu.so`,
   `libtorch_cuda.so`, `libc10.so`, `libc10_cuda.so`, `libtorchcpp.so` —
   summary needs to cover the set.

## Ecosystem map

```
                 PyTorch source (C++/CUDA)
                          │
                ┌─────────┼─────────────────┐
                ▼         ▼                 ▼
            pip wheel   conda pkg        homebrew
         (torch-2.x)   (pytorch)        (pytorch)
                │         │                 │
                └─────────┼─────────────────┘
                          ▼
                    libtorch.so, libc10.so, ...
                          │
        ┌─────────────────┼─────────────┬────────────┐
        ▼                 ▼             ▼            ▼
   Python `torch`   OCaml `torch`   Rust `tch-rs`   Julia PyCall.torch
   (same pip pkg)   (opam torch)    (crates.io)     (JuliaDiffEq)
```

## Multi-PM interop cases canary can expose

| Case | Setup | Question canary answers |
|------|-------|-------------------------|
| **pip-torch, try OCaml torch** | `pip install torch==2.5` + `opam install torch` | opam torch's libtorch range `[2.1, 2.2)` conflicts with pip's 2.5 — expect pack-time failure. Canary records this as Expect_failure with version_info. |
| **pip-torch CPU, OCaml torch wants same** | pip install CPU-only wheel, set `LIBTORCH` to wheel's lib dir | Does OCaml torch find and load libtorch? Does native symbol watchlist survive? |
| **apt libtorch-dev, OCaml torch** | `apt install libtorch-dev` (Debian old version), `opam install torch` | Debian's libtorch ≈ 1.8; way outside OCaml's range. Expected failure. |
| **Symbol drift 2.1 → 2.5** | Summarize libtorch 2.1 vs libtorch 2.5, diff | How many ATen symbols changed? Which namespaces grew? |
| **Python-side drift** | `dir(torch)` on 2.1 vs 2.5 | Python API stability across the OCaml-supported range |

## Target scope (batch-2 initial)

Start minimal. **Defer** CUDA, macOS MPS, conda, homebrew, manual downloads.

### Variant 1: pip-torch probe (Python-only)
- Install: `pip install torch --index-url https://download.pytorch.org/whl/cpu`
  (CPU wheel, ~200MB instead of 2GB CUDA wheel)
- Probe: `python3 -c "import torch; x = torch.tensor([1.,2.]); print(x.sum())"`
- Summary (Python): `dir(torch)` top-level, watchlist `{tensor, nn, optim, autograd, cuda}`
- Summary (native): run `summarize_native.py` on the installed wheel's
  `site-packages/torch/lib/libtorch_cpu.so`, watchlist C symbols for ATen
  ops that are stability bellwethers

### Variant 2: opam torch + pip torch interop
- Install pip torch first, then attempt `opam install torch`
- Capture expected failure: opam torch rejects due to libtorch version constraint
- Record as `Expect_failure { contains_any = ["libtorch"; "conflicts"]; version_info = ... }`
- This documents the mismatch rather than claiming it's a bug

### Variant 3: opam torch + compatible libtorch (happy path)
- Install libtorch 2.1.x manually (via opam-depext or pin via URL)
- `opam install torch`
- Probe: `canary/examples/torch/torch_example.ml` (compile + run a small tensor op)
- Native summary on libtorch_cpu.so, OCaml summary on `torch` module, watchlist cross-check

## Watchlist seeds

### Native (libtorch_cpu.so) — ATen and c10 symbols
- Widely-used: `at::Tensor::sum`, `at::empty`, `at::ones`, `at::zeros`,
  `c10::Device`, `c10::ScalarType`
- Stability bellwethers (renamed or removed across 2.x):
  `at::native::_cudnn_*` (CUDA-specific), `at::quantized::*`
- Expect large `versioned_req` map — libtorch is linked against modern libstdc++, glibc

### Python (`torch`)
- Public API top-level: `tensor`, `nn`, `optim`, `autograd`, `cuda`, `backends`,
  `jit`, `onnx`, `distributed`
- Version marker: `torch.__version__`, `torch.version.cuda` (None on CPU wheel)
- Submodules to spot-check: `torch.nn.Linear`, `torch.optim.Adam`

### OCaml (opam torch)
- Top-level modules: `Torch`, `Torch_core`, `Torch_vision` (if depopt installed)
- Constructor-level: skip (compiled probe catches changes)

## Implementation steps

Assumes Python binding primitives exist (per `../design/python_binding.md`).

### Step 1 — Sqlite-first prototype (prerequisite, part of python plan)
Validate Python summary pipeline end-to-end on stdlib `sqlite3` (no install,
no CUDA, no drama). Confirms `canary/scripts/summarize_python.py` and
`Canary_artifact_python.summary_cmd` work.

### Step 2 — PyTorch CPU variant (Variant 1 above)
1. Add project spec `canary_project_torch.ml`:
   - `pack_binding` step: `pip install torch --index-url ..../cpu`
   - `probe_binding_pip` step: the python -c one-liner
   - Python summary on the installed package
   - Native summary on the wheel's libtorch_cpu.so — path discovered at runtime
     from `python3 -c "import torch, os; print(os.path.dirname(torch.__file__))"`
2. Watchlists declared as constants in the project spec
3. Run `canary action torch` locally; expect summary.json on both sides

### Step 3 — opam torch interop (Variants 2 + 3)
1. Add `probe_binding_opam` step: tries `opam install torch` against whatever
   libtorch is available
2. Variant 2: expect conflict-failure when libtorch version is outside range
3. Variant 3: pin a compatible libtorch (2.1.x), expect happy path
4. Compile probe: `canary/examples/torch/torch_example.ml` using OCaml torch API

### Step 4 — Multi-PM sweep (the interesting part for this plan)
Cross-product table the plan is really aiming at:

| libtorch source | Python torch | OCaml torch | Expected result |
|-----------------|--------------|-------------|-----------------|
| pip 2.5 (default) | ✓ same wheel | fail | ocaml conflicts 2.5 > 2.2 |
| pip 2.1.2 | ✓ | ✓ | happy path |
| pip CUDA wheel | ✓ (on GPU) | depends on ABI | libtorch_cpu.so vs libtorch_cuda.so |
| apt libtorch-dev | Debian's old torch | fail | debian version way too old |
| manual download 2.1 | none (no Python installed) | ✓ | OCaml-only probe |

Each row is one canary action variant. Captures the full "which combinations
work" map.

## Open questions (decide during implementation)

- **Wheel size in CI**: CPU wheel is ~200MB, tolerable. CUDA wheel is ~2GB —
  likely skip in CI, run locally only. Gate via distro/runner check.
- **`LIBTORCH` env var handling**: opam torch reads `LIBTORCH` to find the
  native lib. Multi-PM variants need to set it correctly per source. Canary's
  probe shell must export it before invoking opam.
- **Cache strategy for pip**: `~/.cache/pip` can be large; consider
  `actions/cache@v4` similar to sccache. Per-variant cache keys needed.
- **OCaml torch depopts**: `torchvision` is a depopt. Test with and without.
- **Python venv vs system pip**: isolate per variant with a venv to avoid
  cross-contamination. `Canary_pm_pip.ml` needs venv awareness (already a
  noted gap in the python_binding_plan).

## Why this plan is a high-leverage next step

- Forces the Python summary pipeline out of its "sqlite3 toy" comfort zone
- Exposes multi-PM interop modelling needs before we over-abstract a template
- Yields a concrete "here's a mismatch canary detected" story for the
  research narrative (version-range conflicts across PMs)
- Surfaces LD_LIBRARY_PATH / LIBTORCH env-injection patterns that will recur
  for other C++ libraries (tensorflow, onnxruntime, etc.) — PyTorch is the
  cheapest way to work through the pattern

## Scope estimate

~250 lines of project spec + ~30 lines of Python examples + ~50 lines of
updates to Canary_artifact_python for venv handling. Heavier than a typical
project (z3 is ~600 lines, llvm ~470) but PyTorch pulls its weight as a
multi-PM case.
