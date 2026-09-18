# torch — findings, and the tooling they produced

> 2026-09-01. Split out of [`issues.md`](issues.md) (user: *"torch's issue
> is more complex, so I am good to split them into a separate file"*).
> Everything here is torch-specific and OPEN unless marked; canary-level
> findings that torch merely SURFACED stay in `issues.md` — the `status`
> substring bug is the one currently there. The plan and the measured
> cell matrix live in [`project_pytorch.md`](project_pytorch.md); the
> library-selection mechanism is
> [`../surveys/lib_selection.md`](../surveys/lib_selection.md).

## Why torch earns its own file

Four independent things go wrong at once, and each is a different KIND of
problem — which is what makes the project a good specimen and a bad fit
for a shared list:

| # | what | kind |
| --- | --- | --- |
| 1 | the published package does not build with current dune | packaging |
| 2 | the library is selected by an env chain no package manager records | provisioning |
| 3 | the binding's generated shim goes stale against the library | drift |
| 4 | a warm build tree serves a verdict about a different library | caching |

## 0. THE RECIPE — `Declarations.yaml` without a source build

The unlock for 1 and 3, and the thing to keep even if every finding below
is closed. It currently lives here as prose; **the intent is to migrate
it into the ocaml-torch fork as a script** once the fork is ours to
maintain (user, 2026-09-01: *"finally we shall migrate this automation
into our ocaml-torch fix but now it can stay in canary"*).

```sh
V=<venv>
uv venv "$V" --python 3.12
VIRTUAL_ENV="$V" uv pip install \
  --index-url https://download.pytorch.org/whl/cpu 'torch==<VERSION>' pyyaml
"$V"/bin/python -m torchgen.gen \
  -s "$V"/lib/python3.12/site-packages/torchgen/packaged/ATen \
  --install-dir <out> --generate declarations_yaml
```

Two flag traps, both of which cost an attempt: `-o` is
`--output-dependencies`, NOT the output directory (that is
`--install-dir`), and `-s` must point at `packaged/ATen`, not `packaged`.

Measured for 2.3.1: 5.0 MB, 3096 operators, carrying every field
`gen_bindings/gen.ml` reads — `name`, `operator_name`, `overload_name`,
`deprecated`, `method_of`, `arguments`, `returns`, and per-argument
`dynamic_type` / `type`.

**Which surface canary declares** (decided 2026-09-01, user): the
build-time `Declarations.yaml`, because it is strictly richer than the
shipped `RegistrationDeclarations.h` — it carries `method_of`,
`is_nullable`, defaults and annotations, and those are the fields that
separate "the signature changed" from "the change breaks a caller". The
shipped manifest stays useful as a zero-cost cross-check: two independent
channels agreeing on 3096 operators is itself a c1-shaped assertion.

---

### Found — libtorch SHIPS a typed API manifest, and it predicts both
### observed breaks by name (2026-09-01)

Looking for an alternative to `Descriptions.yaml` turned up something
better. Every libtorch prebuilt contains
`include/ATen/RegistrationDeclarations.h` — a generated header listing
every registered ATen operator with its full C++ signature AND a JSON
blob per line:

```
Tensor _cslt_sparse_mm(const Tensor & compressed_A, …); // {"schema": "aten::_cslt_sparse_mm(Tensor compressed_A, …) -> Tensor", "dispatch": "True", "default": "False"}
```

3066 operators in 2.2.1, 3096 in 2.3.1, 3101 in 2.13.0.

**How well does it actually predict?** Measured properly (the first
write-up of this said "predicts by name", which over-claimed — that was
grep for two functions already known to break). A BLIND diff of the
2.1.2 and 2.2.1 manifests, comparing signatures by operator name:

| stage | candidates |
| --- | ---: |
| `nm -D` over `libtorch_cpu.so` (what torch declares today) | 87,877 mangled symbols |
| manifest diff, signature changed | **68** of 2041 common ops |
| ∩ operators the shim wraps | 62 — barely narrower; the shim wraps 2598 of ~2600 ops, so the consumer side does not discriminate |
| after removing ONE benign widening (`IntArrayRef`→`SymIntArrayRef`, `int64_t`→`c10::SymInt`, both implicit conversions) | **4**, with the real break first |

The 4 are `_cslt_sparse_mm` (the actual failure), `floor_divide_out`
(`const Tensor&` → `const Scalar&`, a genuine change), and
`mkldnn_reorder_conv2d_weight{,_out}` (a third widening spelling the
filter did not cover — `OptionalIntArrayRef`).

So it is a **candidate generator, not a predictor** — but a very good
one: four typed candidates instead of 87,877 opaque strings, and the
right answer among them. Going from 4 to 1 needs real C++
type-compatibility reasoning, which is exactly c6, and exactly what
backlog #44 is about. The finding therefore STRENGTHENS #44 rather than
replacing it: the manifest supplies parsed, typed inputs for free (no
libclang, no preprocessor, no include graph), leaving the subtyping
judgement to run over four signature pairs instead of a translation unit.

**The two failures, as the manifest records them:**

| break | manifest says |
| --- | --- |
| official v0.17.0 × 2.2.1, "argument 4" | `_cslt_sparse_mm` 2.1.2: `(compressed_A, dense_B, bias, transpose_result)` → 2.2.1: `(…, bias, alpha, out_dtype, transpose_result)`. Two parameters INSERTED before the last, so argument 4 went from `bool` to `const optional<Tensor>&` — exactly what gcc complained about |
| fork × 2.13.0, "cannot bind non-const lvalue ref" | `rrelu_with_noise_out` 2.3.1: `const Tensor & noise` → 2.13.0: `at::Tensor & noise` — the const dropped |

**Why this matters beyond torch.** Today torch's compat surface is `nm`
over 87,877 mangled symbols, and its expectation is a hand-written
`Expect_failure` substring. This file makes the same failure *derivable*:
diff two versions' manifests, get a named operator with a typed signature
change, and the expectation becomes `Expect_compat_derived` — computed
from the artifact rather than asserted by a person. That is the c6 (type
contract) shape with real inputs, on a real project.

It also bears on **backlog #44** ("L2 — typed signatures via clang AST"),
which is deprioritized because the proper clang path drags preprocessor
and include handling. For libtorch none of that is needed: the library
ships its own declaration manifest, already parsed and already carrying
the schema. A `RegistrationDeclarations.h` inspector is a much cheaper
route to a typed C surface than libclang, for any library that ships one.

Worth checking whether other C++ libraries do the same before treating
it as torch-specific.

**Not** a route to regenerating the binding, though — see below. The
manifest has names and C++ types but not the `dynamic_type` / `method_of`
fields `gen.ml` reads, so it would need a new parser; and it is a
checking oracle, which is the cheaper and more useful half anyway.

### Found — every ocaml-torch upper bound is REAL, and lifting one is a
### download rather than a build (2026-09-01)

Asked whether the declared libtorch windows are conservative metadata or
measured facts. Both were tested by supplying the library through route 1
(`LIBTORCH=<dir>`), which the solver cannot see, so the *code* answers
rather than the packaging:

| binding | libtorch | result |
| --- | --- | --- |
| official `v0.17.0` (+ our dune fix) | 2.1.2 | ✓ builds, runs |
| official `v0.17.0` (+ our dune fix) | **2.2.1** | ✗ `at::_cslt_sparse_mm` gained a parameter |
| fork `canary` | 2.3.1 | ✓ builds, installs, runs |
| fork `canary` | **2.13.0** | ✗ `at::rrelu_with_noise_out` arg 3 became `Tensor&` |

So **`conflicts: ["libtorch" {< "2.1.0" | >= "2.2.0"}]` is CORRECT**, not
over-tight: 2.2.0 changed `_cslt_sparse_mm`'s signature and v0.17.0's
generated shim passes the wrong argument 4. A "patched package that works
with 2.2.1" therefore cannot be a metadata widening — the generated code
itself is wrong for that library.

**Regeneration is CHEAP, and an earlier version of this entry said the
opposite** (corrected 2026-09-01, same day). The reasoning was: `gen.ml`
consumes *"the Descriptions.yaml file that gets generated when building
PyTorch from source"*, and none of the three prebuilt zips ships any
`.yaml` — therefore a source build. The first half is right and the
conclusion does not follow, because the pip wheel ships **`torchgen`**,
PyTorch's own code generator, together with its input
(`torchgen/packaged/ATen/native/native_functions.yaml`). So the file can
be produced from a wheel in seconds:

```sh
uv venv <v> && VIRTUAL_ENV=<v> uv pip install \
  --index-url https://download.pytorch.org/whl/cpu 'torch==2.3.1' pyyaml
<v>/bin/python -m torchgen.gen \
  -s <v>/lib/python3.12/site-packages/torchgen/packaged/ATen \
  --install-dir <out> --generate declarations_yaml
```

Measured: 5.0 MB, 3096 operators — the same count as the shipped
manifest — carrying every field `gen.ml` reads (`name`, `operator_name`,
`overload_name`, `deprecated`, `method_of`, `arguments`, `returns`, and
per-argument `dynamic_type` / `type`). Two flag traps cost the first two
attempts: `-o` is `--output-dependencies`, not the output directory
(that is `--install-dir`), and `-s` must point at `packaged/ATen`, not
`packaged`.

So lifting a libtorch bound means regenerating the shim from a wheel of
the matching version, which is a download rather than a build. The
lesson to keep: *"only produced by a source build"* was a statement about
where the file appears, and it was read as a statement about what is
required to produce it.

Feeding `gen.ml` the raw `native_functions.yaml` does not work — its
entries are `- func: abs(Tensor self) -> Tensor` with `variants:` /
`dispatch:`, while `gen.ml` reads the DERIVED vocabulary
(`operator_name`, `method_of`, `dynamic_type`, per-argument `type`). But
that is the right INPUT to the wrong tool: PyTorch's `torchgen` performs
exactly that derivation, and it ships in the wheel alongside a bundled
copy of `native_functions.yaml`. See the correction above.

The contrast with the fork's own metadata is worth keeping: upstream's
window is right, while the fork's `[2.3.0, 2.4.0)` is NOT a measured
bound (2.3.1 works; nothing between 2.3.1 and 2.13.0 was tried).

### Found — the ocaml-torch shim does not compile against current
### libtorch, and the boundary is unmeasured (2026-09-01)

The forward-mismatch cell torch was landed for, measured. Our fork at
`canary` (`e6bd980`) builds and runs against libtorch **2.3.1** and fails
against **2.13.0** with a genuine C++ API break, in a fresh opam tree:

```
torch_api_generated.cpp:15695: error: cannot bind non-const lvalue
  reference of type 'at::Tensor&' to an rvalue of type 'at::Tensor'
    torch::rrelu_with_noise_out(out_local, …, tensor_from_ocaml(noise), …)
```

libtorch changed `at::rrelu_with_noise_out` so parameter 3 (`noise`) is a
non-const `at::Tensor&`; the generated shim passes a temporary. It is
attributable to ONE named function, which is what makes it a good
specimen — a c1/c6-shaped break with a name, not a link failure.

Three things follow:

- **"Target the latest" is not a declaration change.** Supporting 2.13.0
  means REGENERATING `torch_api_generated.cpp` from that version's
  `native_functions.yaml` (`src/gen_bindings`), which is the real work
  behind the fork's stated intent.
- **The supported window is unknown.** The fork's opam file claims
  `[2.3.0, 2.4.0)`, which is stale metadata rather than a measured bound:
  2.3.1 works, 2.13.0 does not, and nothing between them has been tried.
  A bisect over the ~10 releases would give the true upper bound and is
  the cheapest way to turn a guess into a declaration.
- **It is a real 2×2 lib axis at last.** Vendored 2.3.1 (works) against
  Vendored 2.13.0 (breaks) is a genuine channel pair from ONE provider
  (upstream's own zips), which is what `spec-check`'s `lib pair` has been
  warning about since the landing.

### Found — a build cache that ignores its selecting ENV variable serves
### a verdict about a different library (2026-09-01, torch)

Generalized into [landing.md](landing.md) §4 as a landing lesson; the
per-project fact is here. torch selects its library by reading `LIBTORCH`
at build time, but the dune rule invoking the configurator depends only
on `discover.exe`. Rebuilding a warm tree with a different `LIBTORCH`
therefore reuses both the computed flags and `torch_api.o`: a build
"against 2.13.0" returned rc=0 while
`_build/default/src/wrapper/cxx_flags.sexp` still named `libtorch-2.3.1`.
The failure above was only visible because opam builds in a fresh tree.

For canary this is a REALIZATION constraint, not just trivia: any torch
scenario that varies the lib must not reuse a working tree, and the
scenario's `LIBTORCH` belongs in the step fingerprint (the same argument
as the opam switch and the platform, CLAUDE.md's two choke points).

## Chores

- [ ] **Upstream torch PR — one line, and it is ready** (2026-08-30, found
  by landing torch). `torch.v0.17.0` does not build with dune 3.23.1:
  `src/wrapper/dune` declares `(foreign_stubs (language cxx) (names
  torch_api))` while `torch_api.cpp:944` does `#include
  "torch_api_generated.cpp"`, and dune stages the listed `.cpp` and every
  `.h` but not the unlisted `.cpp` — verified by listing
  `_build/default/src/wrapper/`, which holds `torch_api.h` and
  `torch_api_generated.h` and not `torch_api_generated.cpp`. The package
  declares `(lang dune 3.11)`. Note opam's post-message blames a missing
  system libtorch, which is a red herring — libtorch 2.1.2 was installed
  and its `-isystem` flags are in the failing command. Fix is
  `(extra_deps torch_api_generated.cpp)`; with it `dune build -p torch`
  exits 0 with an empty log. The patch is already carried verbatim at
  `canary/templates/opam-local-repo/packages/torch/torch.v0.17.0-canary1/
  files/dune-extra-deps.patch`, so the PR is a copy. This is the second
  "Real-world PRs" candidate and the cheaper of the two.
