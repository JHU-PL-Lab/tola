# PyTorch — multi-PM case study (candidate #4)

Pre-implementation plan for the highest-leverage queued target. Split out
of `design/new_project.md` on 2026-08-05 when that doc merged into the
project index; the candidate queue entry lives at
[`index.md`](index.md) §2 Tier 1 #4. (Moved here from `design/` in the
2026-08-12 `doc/canary/project/` reorganization.)

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

## Implementation order

1. **Variant 1** — pip-torch (Python-only, CPU wheel ~200 MB):
   `pip install torch --index-url …/cpu` → `import torch; …` probe.
   Native inspect on `site-packages/torch/lib/libtorch_cpu.so`,
   path discovered at runtime.
2. **Variant 2** — opam torch + pip torch interop: pip-install first,
   then `opam install torch`. Capture the conflict-failure. (Written
   pre-A7 as a hand-authored `Expect_failure`; post-A7 the prediction
   should be *derived* from declared evidence like every other project —
   see [`landing.md`](landing.md) §2 level B.)
3. **Variant 3** — opam torch + compatible libtorch: pin libtorch 2.1.x
   (opam-depext / URL pin), then `opam install torch`. Probe with a
   small `torch_example.ml` tensor op. Native + OCaml summaries.
4. **Multi-PM sweep** — execute the matrix above as the prize.

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
