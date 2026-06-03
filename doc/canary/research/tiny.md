# `tiny` — the foundational example for surface theory

A minimal C library (two functions, one global) with hand-written
OCaml and Python bindings. Designed to instantiate every contract in
§2.4 of [`surface_theory.md`](surface_theory.md) on the smallest
possible target, and to give twelve deliberately-broken (or
positive-coverage) variants so each failure mode is reproducible in
isolation. The Phase 3 `prepare` flow makes each variant's
contract-violation claim a machine-checkable assertion — see the
"Phase 3a" subsection.

The whole point is that the reader (and we) can hold the entire
example in working memory and trace every surface and every contract
by eye. Z3/LLVM/sqlite are too big for that; `tiny` is not.

This doc is the single source of truth for the example — design
rationale, file-level spec, build instructions, per-scenario detail,
and coverage. For the abstract surface-role / contract framework,
read [`surface_theory.md`](surface_theory.md). For the contract-by-
contract status (canary core vs. tiny), see `surface_theory.md` §2.7.

## Spec — the native side

### `tiny.h` (syntactic surface — `s1 native_header`)

```c
#ifndef TINY_H
#define TINY_H

extern int tiny_offset;            /* read-only global, initial value 42 */

int tiny_sum(int a, int b);        /* returns a + b + tiny_offset */
int tiny_diff(int a, int b);       /* returns a - b */

#endif
```

### `libtiny.so.1` (semantic surface — `s2 native_lib`)

| Property                  | Value                                                  |
| ------------------------- | ------------------------------------------------------ |
| Defined symbols           | `tiny_offset` (OBJECT), `tiny_sum`, `tiny_diff` (FUNC) |
| SONAME                    | `libtiny.so.1`                                         |
| NEEDED                    | `libc.so.6`                                            |
| Runtime: `tiny_sum(2, 3)` | `47` (i.e. `2 + 3 + tiny_offset`)                      |
| Runtime: `tiny_diff(5, 2)`| `3`                                                    |

## Spec — the OCaml binding (stub-based, static)

### Stub-facing layer: `Tiny_raw.mli` (syntactic, part of `s3 binding_stub`)

```ocaml
external sum        : int -> int -> int = "caml_tiny_sum"
external diff       : int -> int -> int = "caml_tiny_diff"
external get_offset : unit -> int       = "caml_tiny_get_offset"
```

### Stub C glue: `tiny_stubs.c` (syntactic, also part of `s3 binding_stub`)

```c
#include <caml/mlvalues.h>
#include "tiny.h"

CAMLprim value caml_tiny_sum(value a, value b) {
    return Val_int(tiny_sum(Int_val(a), Int_val(b)));
}
CAMLprim value caml_tiny_diff(value a, value b) {
    return Val_int(tiny_diff(Int_val(a), Int_val(b)));
}
CAMLprim value caml_tiny_get_offset(value unit) {
    (void)unit;
    return Val_int(tiny_offset);
}
```

### User-facing layer: `Tiny.mli` (syntactic — `s4 binding_header`)

```ocaml
val sum    : int -> int -> int
val diff   : int -> int -> int
val offset : unit -> int       (* queries C global each call *)
```

### User-facing layer: `Tiny.ml` (syntactic, repacks `Tiny_raw`)

```ocaml
let sum    = Tiny_raw.sum
let diff   = Tiny_raw.diff
let offset = Tiny_raw.get_offset
```

### Compiled artifact (semantic — `s5 binding_lib`)

| Property                          | Value                                                      |
| --------------------------------- | ---------------------------------------------------------- |
| Exported OCaml modules            | `Tiny`, `Tiny_raw`                                         |
| `Tiny_raw` `.cmi` digest          | covers three `external` decls                              |
| `Tiny` `.cmi` digest              | covers three vals                                          |
| Undefined ELF refs in stubs       | `tiny_offset`, `tiny_sum`, `tiny_diff`, OCaml runtime syms |
| NEEDED in linked example          | `libtiny.so.1`, `libc.so.6`                                |

### Downstream library: `tiny_helper` (consumer of `Tiny`)

A second OCaml library sits on top of the `Tiny` binding to exercise
the longest-interesting chain. `tiny_helper.mli` declares
`val sum_doubled`, `val diff_doubled` returning a small record;
`tiny_helper.ml` calls `Tiny.sum` / `Tiny.diff` and post-processes.
It does *not* talk to libtiny.so directly — it consumes the
user-facing `Tiny` module. Together with two apps:

- `app_binding.exe` — links against `Tiny`; this is the e12 fixture
- `app_helper.exe` — links against `tiny_helper`; the chain
  `app → tiny_helper → Tiny → libtiny.so` is the e13 fixture

Both apps live under `ocaml/examples/` and are exercised by every
scenario through the harness's `ocaml_app_binding` and
`ocaml_app_helper` outcome slots.

## Spec — the Python side, two parallel bindings

Two Python bindings ship side by side to instantiate both points on
the §2.3 static/dynamic axis: `tiny_cext` (static, CPython C
extension) and `tiny_ctypes` (dynamic, runtime FFI via ctypes). Both
expose the same `(sum, diff, offset)` surface; they differ only in
mechanism.

### Static binding: `tiny_cext` (CPython C extension)

The stub-facing layer is a compiled C extension module
(`tiny_cext/_native.cpython-*.so`) built from
`tiny_cext/_native.c`. Each wrapper unboxes Python args via
`PyArg_ParseTuple`, calls the underlying `tiny_*` from `tiny.h`, and
boxes the result via `PyLong_FromLong`. The user-facing module is
`tiny_cext/__init__.py`, a thin idiomatic repack of `_native`.

This is the direct Python parallel of OCaml's `tiny_stubs.c` —
static, stub-based, with link refs baked into a compiled artifact.
NumPy and `cryptography` are real-world examples of this pattern.

### Dynamic binding: `tiny_ctypes` (runtime FFI)

The stub-facing layer is `tiny_ctypes/_raw.py`: pure Python,
declaring C signatures as ctypes type descriptions
(`_lib.tiny_sum.argtypes = [c_int, c_int]`, etc.). At runtime, ctypes
uses `libffi` to construct each call. The user-facing module is
`tiny_ctypes/__init__.py`, mirroring `tiny_cext`'s surface.

`z3-solver` (pip) is a real-world example. `llvmlite` is a hybrid —
its own compiled C++ shim wrapped by ctypes, a third point on the
spectrum we haven't yet built out.

### Semantic surfaces of the two

| Property                          | `tiny_cext` (static)                                       | `tiny_ctypes` (dynamic)         |
| --------------------------------- | ---------------------------------------------------------- | ------------------------------- |
| Compiled artifact                 | `_native.cpython-*.so`                                     | none (pure Python)              |
| Baked-in ELF refs                 | `tiny_sum`, `tiny_diff`, `tiny_offset` (undefined)         | none                            |
| NEEDED                            | `libtiny.so.1` (linker recorded at build)                  | none                            |
| Symbol resolution phase           | process load (linker resolves at first `import`)           | runtime per `dlsym`             |
| Failure mode for `symbol_missing` | `import` raises `ImportError: undefined symbol`            | `AttributeError` on first call  |
| Failure mode for `abi_soname_bump`| `import` raises `ImportError: cannot open shared object`   | `OSError` at `CDLL(...)`        |

## Directory layout (as built)

```
canary/examples/tiny/
  Makefile                           # c → ocaml/cext → probe → inspect → scenarios
  c/
    include/tiny.h
    src/tiny.c
    CMakeLists.txt                   # libtiny.so.1 with SOVERSION 1
  ocaml/                             # static cstubs binding
    tiny_stubs.c
    tiny_raw.{ml,mli}                # stub-facing layer
    tiny.{ml,mli}                    # user-facing layer
    dune                             # foreign_stubs + libtiny link
    tiny_helper/                     # downstream library (consumes Tiny)
      tiny_helper.{ml,mli}, dune
    examples/probe_baseline.ml       # harness behaviour probe
    examples/app_binding.ml          # e12 fixture: app → Tiny
    examples/app_helper.ml           # e13 fixture: app → tiny_helper → Tiny
    examples/dune                    # all three executables
  python_cext/                       # static CPython C-extension binding
    tiny_cext/_native.c              # CPython C extension (stub-facing)
    tiny_cext/__init__.py            # user-facing layer
    setup.py                         # canonical setuptools build script
    pyproject.toml                   # [build-system] requires setuptools>=77
    examples/probe_baseline.py
  python_ctypes/                     # dynamic ctypes binding
    tiny_ctypes/_raw.py              # stub-facing layer (ctypes type descs)
    tiny_ctypes/__init__.py          # user-facing layer
    pyproject.toml
    examples/probe_baseline.py
  scenarios/                         # 12 variants (10 perturbations + 2 positive-coverage) + harness
    scenarios.py                     # apply/revert/expected + Phase 3 baseline/prepare/restore (single source of truth)
    patches/                         # .patch files for source-edit scenarios
    _harness/run.sh, run_cached.py, check.py, comparators/cmp_*.py
    _cache/                          # (gitignored) baseline + per-scenario artifacts + JSONs, populated by `make prepare-all`
```

**OCaml directory is flat** because dune's `foreign_stubs` needs the
stub C file in the same directory as the dune file. The two layers
(stub-facing `tiny_raw` and user-facing `tiny`) live as separate
`.ml` files in the same directory. The OCaml binding uses dune as
part of the parent `tola` workspace (no inner `dune-project`); the
Makefile sets `LIBRARY_PATH` and `LD_RUN_PATH` to absolute paths so
the linker finds `libtiny` and bakes a matching rpath into the
binding.

**Python cext is built via PEP 517** with the setuptools backend
declared in `pyproject.toml` (`[build-system].requires =
["setuptools>=77"]`). The Makefile invokes `uv build --wheel` from
`python_cext/`; uv brings setuptools into a temporary build
environment, runs `setup.py build_ext` under the hood, and produces a
wheel containing the compiled `_native.cpython-*.so`. The Makefile
then copies the `.so` back next to `__init__.py` for in-place imports
(`PYTHONPATH=python_cext python3 ...`). This matches mainstream
Python C-extension practice (NumPy, cryptography, lxml) and works on
a project Python that doesn't itself ship `setuptools` or `pip`.

## Build & probe

```sh
make c                       # builds libtiny.so.1 in c/build/
make ocaml                   # builds OCaml binding (depends on c)
make python_cext             # compiles tiny_cext/_native.so via uv build (depends on c)
make python_ctypes           # no-op (pure Python; depends on c at runtime)
make probe                   # runs all three baseline probes
make inspect                 # runs canary inspectors on every surface

# Scenarios (apply / build / inspect / probe / revert per run; original flow)
make scenarios               # runs all 12 scenarios
make scenario-<name>         # runs a single scenario

# Phase 3 — prepare populates _cache/ with per-scenario inspector JSONs +
# artifact snapshots; scenarios-cached replays them via file copies.
make baseline                # build + inspect baseline, snapshot to _cache/baseline/
make prepare-<name>          # apply + build + inspect + snapshot + confirm-ill + revert
make prepare-all             # all 12 scenarios (~8s wall clock)
make scenario-cached-<name>  # replay a single scenario from cache (skips apply / build / inspect)
make scenarios-cached        # replay all 12 from cache (~6s, vs ~10s for `make scenarios`)
make clean
```

The Makefile sets `LD_LIBRARY_PATH` to find `c/build/libtiny.so.1` for
every probe; no system install needed.

A successful baseline probe prints three identically-shaped outputs:

```
OK   Tiny.offset () = 42        |   OK   tiny.offset() = 42       (cext + ctypes)
OK   Tiny.sum 2 3 = 47          |   OK   tiny.sum(2, 3) = 47
OK   Tiny.diff 5 2 = 3          |   OK   tiny.diff(5, 2) = 3
OK   Tiny.diff 2 5 = -3         |   OK   tiny.diff(2, 5) = -3
all checks passed
```

`make inspect` produces JSON for every surface canary can currently
parse. First-pass results on the healthy baseline:

| Artifact (alias)              | Inspector                                     | Output summary                                                                       | Contract this feeds  |
| ----------------------------- | --------------------------------------------- | ------------------------------------------------------------------------------------ | -------------------- |
| `n4` `lib_native.so` (s2)     | `inspect_native.py` + `nm -D`                 | symbols `{tiny_diff, tiny_offset, tiny_sum}`, SONAME `libtiny.so.1`, NEEDED `libc.so.6` | Symbol, ABI         |
| `bo4` `user_binding_ocaml.mli` (s4) | `inspect_binding.py --kind mli`        | vals `{sum, diff, offset}`                                                            | API-completeness     |
| `bo1` `stub_binding_ocaml.mli` (s3) | `inspect_binding.py --kind mli` (same script) | **vals []** — `external` decls not parsed (inspector gap; see "Findings" below)  | Type (intended)      |
| `bo7` `compiled_binding_ocaml.stub-a` (s5) | `inspect_binding.py --kind stub`  | undefined refs `{tiny_diff, tiny_offset, tiny_sum}`                                    | Symbol (consumer)    |
| `bo6` `compiled_binding_ocaml.cmxa` (s5)  | `inspect_ocaml.py`                  | OCaml modules `{Tiny, Tiny_raw}`                                                       | (informational)      |
| `bpe3` `compiled_binding_cext.so` (s5) | `inspect_native.py` (cext is ELF)     | undefined refs `{tiny_sum, tiny_diff, tiny_offset}`                                    | Symbol (consumer)    |
| `bpe2` `user_binding_cext.py` (s4)   | `inspect_python.py --pkg tiny_cext`     | attrs `{sum, diff, offset}`                                                            | API-completeness     |
| `bpc2` `user_binding_ctypes.py` (s4) | `inspect_python.py --pkg tiny_ctypes`   | attrs `{sum, diff, offset}`                                                            | API-completeness     |

The stub-side Symbol contract is already cleanly checkable: every
binding artifact requires exactly the three symbols the native lib
exports — a set-inclusion check on the JSON outputs is the
Symbol-contract verdict (`c1 cmp_symbol` wired in the harness).

## Artifact inventory — aliases & canonical names

Every concrete artifact in the tiny tree has a **canonical name**
(pan-universal, of the form `<role>_<side>[_<lang>][_<mech>].<form>`)
and a **compact alias** (project-local: `n*` native, `b<lang><mech?><i>`
binding). The alias is sequential by file; the canonical name encodes
role + side + language + mechanism + file form.

**Alias prefixes used in tiny:**

| prefix | side       | language | mechanism |
| ------ | ---------- | -------- | --------- |
| `n*`   | native     | (C)      | —         |
| `bo*`  | binding    | OCaml    | cstubs (only one in tiny) |
| `bpc*` | binding    | Python   | ctypes    |
| `bpe*` | binding    | Python   | cext (CPython C extension) |

**Table — Artifact inventory.** Every perturbable / inspectable
file in tiny, keyed by alias. The `surface` column tags the s-role
the artifact carries (`—` for impl files and build inputs that have
no surface of their own).

| alias  | canonical name                  | file path                                          | surface |
| ------ | ------------------------------- | -------------------------------------------------- | ------- |
| n1     | `source_native.c`               | `c/src/tiny.c`                                     | —       |
| n2     | `source_native.cmake`           | `c/CMakeLists.txt`                                 | —       |
| n3     | `header_native.h`               | `c/include/tiny.h`                                 | s1      |
| n4     | `lib_native.so`                 | `c/build/libtiny.so.1`                             | s2      |
| bo1    | `stub_binding_ocaml.mli`        | `ocaml/tiny_raw.mli`                               | s3      |
| bo2    | `stub_binding_ocaml.ml`         | `ocaml/tiny_raw.ml`                                | —       |
| bo3    | `stub_binding_ocaml.c`          | `ocaml/tiny_stubs.c`                               | s3      |
| bo4    | `user_binding_ocaml.mli`        | `ocaml/tiny.mli`                                   | s4      |
| bo5    | `user_binding_ocaml.ml`         | `ocaml/tiny.ml`                                    | —       |
| bo6    | `compiled_binding_ocaml.cmxa`   | `_build/.../tiny.cmxa`                             | s5      |
| bo7    | `compiled_binding_ocaml.stub-a` | `_build/.../libtiny_stubs.a`                       | s5      |
| bo8    | `user_helper_ocaml.mli`         | `ocaml/tiny_helper/tiny_helper.mli`                | s4'     |
| bo9    | `user_helper_ocaml.ml`          | `ocaml/tiny_helper/tiny_helper.ml`                 | —       |
| bo10   | `compiled_helper_ocaml.cmxa`    | `_build/.../tiny_helper.cmxa`                      | s5'     |
| bpc1   | `stub_binding_ctypes.py`        | `python_ctypes/tiny_ctypes/_raw.py`                | s3      |
| bpc2   | `user_binding_ctypes.py`        | `python_ctypes/tiny_ctypes/__init__.py`            | s4      |
| bpe1   | `stub_binding_cext.c`           | `python_cext/tiny_cext/_native.c`                  | s3      |
| bpe2   | `user_binding_cext.py`          | `python_cext/tiny_cext/__init__.py`                | s4      |
| bpe3   | `compiled_binding_cext.so`      | `python_cext/tiny_cext/_native.cpython-*.so`       | s5      |
| —      | runtime trace                   | probe stdout + exit code                           | s6      |

**Reading the index:** the integer in an alias is sequential by file
along the build chain. Groups cluster by integer range (e.g.
`stub_binding_ocaml.*` = bo1..bo3, `user_binding_ocaml.*` = bo4..bo5,
`compiled_binding_ocaml.*` = bo6..bo7). The canonical name identifies
the group; the alias addresses individual files. Group references in
prose use the canonical-name prefix (e.g. "the stub stage" or
`stub_binding_ocaml.*`).

**Surface-role population** (`s1..s6` from `surface_theory.md` §2.1):

| role / binding   | Native | OCaml binding (`bo*`) | Python cext (`bpe*`) | Python ctypes (`bpc*`) | notes                                            |
| ---------------- | ------ | --------------------- | -------------------- | ---------------------- | ------------------------------------------------ |
| s1 `header_native` | n3   | n/a                   | n/a                  | n/a                    | one header serves all bindings                   |
| s2 `lib_native`    | n4   | n/a                   | n/a                  | n/a                    | one library serves all bindings                  |
| s3 `stub_binding`  | n/a  | bo1, bo3              | bpe1                 | bpc1                   | per-language stub-facing layer                   |
| s4 `user_binding`  | n/a  | bo4                   | bpe2                 | bpc2                   | user-facing decls                                |
| s5 `compiled_binding` | n/a | bo6, bo7            | bpe3                 | **—**                  | absent for ctypes by design (pure-Python dynamic) |
| s6 `runtime_trace` | (probe) | (probe)             | (probe)              | (probe)                | runtime behaviour via `probe_baseline.{ml,py}`   |

The only structurally missing cell is `s5 × ctypes` — the mark of
the dynamic-binding column on §2.3's static/dynamic axis. All other
s-roles are populated for every binding.

## Contract check matrix (baseline — everything healthy)

For each contract in `surface_theory.md` §2.4, what is checked on
the unmodified baseline:

| Contract             | OCaml side                                                                                          | Python side                                                                          |
| -------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| **Type**             | `Tiny_raw.mli` external signatures vs. `tiny.h` C signatures → match (no static check today)         | `_lib.tiny_sum.argtypes/restype` vs. `tiny.h` → match (no static check today)         |
| **Symbol**           | linked stub's undefined refs `{tiny_sum, tiny_diff, tiny_offset}` ⊆ libso exports → ✓ (c1 wired)     | `dlsym` of `{tiny_sum, tiny_diff, tiny_offset}` succeeds against libso → ✓            |
| **ABI**              | binding's NEEDED `libtiny.so.1` matches libso SONAME `libtiny.so.1` → ✓                              | `find_library("tiny")` finds `libtiny.so.1` → ✓                                       |
| **API-repacking**    | `Tiny.mli` vals correspond 1-to-1 to `Tiny_raw.mli` externals (renamed `get_offset` → `offset`) → ✓ | `tiny.py` functions correspond 1-to-1 to `_lib` attrs → ✓                            |
| **API-completeness** | `Tiny.mli` exposes `{sum, diff, offset}` → ✓ (c2 wired)                                              | `dir(tiny) ⊇ {sum, diff, offset}` → ✓                                                |
| **Behavior**         | `Tiny.sum 2 3 = 47` matches direct C call → ✓ (c3 wired via probe)                                   | `tiny.sum(2, 3) == 47` matches direct C call → ✓                                     |

## Scenarios — thirteen variants (eleven perturbations + two positive coverage)

Each *perturbation* scenario violates one (or more) contracts from
§2.4. The two positive-coverage scenarios (e12, e13) apply no
perturbation; they assert that the longest-interesting build/link
chains stay wired in baseline. One scenario (e14) is a
{i statically-detectable-but-runtime-silent} regression test for
{c7 cmp_api_repack} — the standard harness records it as
all-pass because c7 isn't wired into [`run.sh`](../../canary/examples/tiny/scenarios/_harness/run.sh);
the unit-test layer covers the verdict shape.

### Harness ↔ canary variant mapping (Phase 14a, 2026-06-02)

The standalone tiny harness names scenarios by what the
*perturbation* is (`symbol_missing`, `api_complete`, …). canary's
`canary_project_tiny.ml` names variants by what canary *expects to
fire* on the resulting artifact, in surface-theory vocabulary
(`lib_broken`, `binding_mli_broken`, …). The mapping is conventional
and lives here:

| Harness scenario        | canary variant                | Contract that fires                |
|---|---|---|
| `baseline` / e12 / e13  | (no suffix; `base_script_spec`) | none (Expect_success everywhere)   |
| `symbol_missing` / e1   | `lib_broken`                  | c1 cmp_symbol @ probe_binding_ocaml |

Workflow (Phase 14a, using the restore-based scaffolding —
superseded by cache-pointing in 14b):

```sh
cd canary/examples/tiny/scenarios
./scenarios.py restore symbol_missing
cd ../../../..
canary action tiny/lib_broken         # c1 fires; expected failure confirmed
./scenarios.py restore-baseline       # back to clean tree
canary action tiny                    # both variants run; baseline passes, lib_broken
                                      #   reports unexpected_success (intended for 14b)
```

Adding more scenarios = one new `<name>_script_spec` value in
`canary_project_tiny.ml` + one new row in this table. Each new spec
encodes its expectation in (contract, stage) terms, not in scenario
terms. canary never sees `e1` / `e6` / …; only the harness side does.

Two harnesses run the scenarios. Both are kept; either should
match the other's PASS set, so divergence between them is a
regression signal:

- **`scenarios/_harness/run.sh`** (original) — applies via
  `scenarios.py apply <name>`, rebuilds, runs inspectors + static
  comparators + runtime probes, compares observed outcomes against
  `scenarios.py`'s `expected` dict, and reverts (always, via
  `trap`). Invoked by `make scenarios`.
- **`scenarios/_harness/run_cached.py`** (Phase 3b) — `restore`s
  the perturbed state from `_cache/<name>/` (file copies, no
  rebuild), runs the probes against restored exes, runs comparators
  against the cached inspect JSONs, then `restore-baseline`s.
  Invoked by `make scenarios-cached`. See "Phase 3b" below.

| id      | name                    | construction                                                              | contract(s)               | OCaml probe                  | cext probe         | ctypes probe       |
| ------- | ----------------------- | ------------------------------------------------------------------------- | ------------------------- | ---------------------------- | ------------------ | ------------------ |
| **e1**  | `symbol_missing`        | source patch `c/src/tiny.c` (rename)                                      | Symbol                    | fail (load)                  | fail (import)      | fail (dlsym)       |
| **e2**  | `abi_soname_bump`       | binary surgery: SONAME byte-swap + symlink rewire                         | ABI                       | fail (load)                  | fail (import)      | fail (open)        |
| **e3**  | `type_wrong`            | source patch `c/src/tiny.c` (int → double)                                | Type, Behavior            | fail (wrong value)           | fail (wrong value) | fail (wrong value) |
| **e4**  | `api_faithful`          | source patch C: add `tiny_max`                                            | API-faithfulness          | ok (silent — undetected)     | ok (silent)        | ok (silent)        |
| **e5**  | `api_repack`            | source patch `ocaml/tiny.ml` (reverse args)                               | API-repacking, Behavior   | fail (wrong value)           | ok                 | ok                 |
| **e6**  | `api_complete`          | source patch `ocaml/tiny.mli` (drop `val sum`)                            | API-completeness          | fail (build)                 | ok                 | ok                 |
| **e7**  | `behavior_silent`       | source patch `c/src/tiny.c` (wrong arithmetic)                            | Behavior                  | fail (wrong value)           | fail (wrong value) | fail (wrong value) |
| **e8**  | `symbol_orphan`         | source patch adds OCaml stub referencing C `tiny_extra` (never defined)   | Symbol (orphan)           | fail (build, modern linker)  | ok                 | ok                 |
| **e10** | `api_repack_python`     | source patch both Python user-facing `__init__.py` (reverse `diff` args)  | API-repacking, Behavior   | ok                           | fail (wrong value) | fail (wrong value) |
| **e11** | `api_complete_python`   | source patch both Python user-facing `__init__.py` (drop `sum`)           | API-completeness          | ok                           | fail (AttributeError) | fail (AttributeError) |
| **e12** | `app_over_binding_ocaml` | no-op apply; asserts `app_binding.exe` (Tiny-using app) builds and runs | (positive coverage — c1 dyn, c2, c3) | ok                | ok                 | ok                 |
| **e13** | `app_over_helper_ocaml`  | no-op apply; asserts `app_helper.exe` (uses `tiny_helper` which uses `Tiny`) builds and runs | (positive coverage — repack composes across layers) | ok | ok | ok |
| **e14** | `api_repack_stub_orphan` | source patch adds `external alias_sum` to Tiny_raw.mli + caml_tiny_alias_sum wrapper, but Tiny.mli doesn't surface it | API-repacking (s3↔s4 orphan) | ok (silent — c7 catches statically) | ok (silent) | ok (silent) |

Thirteen variants now cover the contract grid in both OCaml and Python
directions (e5/e6 = OCaml; e10/e11 = Python parallels) plus the
longest-interesting chain (e12 = app → Tiny binding; e13 = app →
tiny_helper → Tiny binding). `e9 symbol_version_floor` is reserved
for the SymbolVersion contract — the slot is held but implementation
is deferred (see below).

Nine of the ten perturbations produce a runtime / build-time signal
the harness detects. One (`e4 api_faithful`) is *silent* — every
contract that can be probed passes, even though API-faithfulness is
violated. The two positive-coverage scenarios (e12, e13) are
ok-everywhere by design; they exist so that any future regression in
the app-over-binding or app-over-helper chains surfaces as a scenario
failure rather than silently breaking only the apps.

### Chain coverage — perturbable artifacts

The build/link chain from C source down to a running app is a
sequence of *perturbable artifacts*. Each artifact is a place where
tiny can inject a fault and observe how the failure propagates. The
[`canary action`](../design/index.md) story is the dual: it
enumerates the real-world physical choices at each artifact (apt vs.
opam, version A vs. B, system lib vs. wheel-bundled). `tiny` is the
*ideal-coverage* counterpart — it enumerates the possible breakages
at each artifact so canary action's coverage can be measured against
a known map.

**Perturbation is a surface-modifying action**: it takes a baseline
artifact and produces a deliberately ill-formed one whose surface
differs from baseline in a controlled way. For *syntactic surfaces*
(s1, s3, s4) perturbation is source-level; for *semantic surfaces*
(s2, s5) perturbation has two flavors — source-driven (patch
upstream, rebuild) or artifact-direct (binary surgery).

Each scenario records the concrete file paths it perturbs via the
`perturbs` field in
[`scenarios.py`](../../canary/examples/tiny/scenarios/scenarios.py).

**Table — Chain perturbation sites.** Rows are artifact aliases (see
[Artifact inventory](#artifact-inventory--aliases--canonical-names)
for path + canonical name). The `primitive` column says how tiny
modifies it; the right column lists scenarios that touch it. Empty
`scenarios` cells = coverage gaps.

| alias | canonical (artifact)            | perturbation primitive       | scenarios                                                              |
| ----- | ------------------------------- | ---------------------------- | ---------------------------------------------------------------------- |
| n1    | `source_native.c`               | source patch + cmake rebuild | e1 symbol_missing, e3 type_wrong, e4 api_faithful, e7 behavior_silent  |
| n3    | `header_native.h`               | source patch + cmake rebuild | e4 api_faithful                                                        |
| n4    | `lib_native.so` (post-build)    | patchelf or byte surgery     | e2 abi_soname_bump (e9 deferred — SymbolVersion via `.symver`)         |
| bo1   | `stub_binding_ocaml.mli`        | source patch + dune rebuild  | e8 symbol_orphan                                                       |
| bo2   | `stub_binding_ocaml.ml`         | source patch + dune rebuild  | e8 symbol_orphan                                                       |
| bo3   | `stub_binding_ocaml.c`          | source patch + dune rebuild  | e8 symbol_orphan                                                       |
| bo4   | `user_binding_ocaml.mli`        | source patch + dune rebuild  | e6 api_complete                                                        |
| bo5   | `user_binding_ocaml.ml`         | source patch + dune rebuild  | e5 api_repack                                                          |
| bo6   | `compiled_binding_ocaml.cmxa` (post-build) | binary surgery   | —                                                                      |
| bo7   | `compiled_binding_ocaml.stub-a` (post-build) | binary surgery | —                                                                      |
| bo8   | `user_helper_ocaml.mli`         | source patch + dune rebuild  | —                                                                      |
| bo9   | `user_helper_ocaml.ml`          | source patch + dune rebuild  | —                                                                      |
| bo10  | `compiled_helper_ocaml.cmxa` (post-build) | binary surgery     | —                                                                      |
| bpc1  | `stub_binding_ctypes.py`        | source patch                 | —                                                                      |
| bpc2  | `user_binding_ctypes.py`        | source patch                 | e10 api_repack_python, e11 api_complete_python                         |
| bpe1  | `stub_binding_cext.c`           | source patch + uv rebuild    | —                                                                      |
| bpe2  | `user_binding_cext.py`          | source patch                 | e10 api_repack_python, e11 api_complete_python                         |
| bpe3  | `compiled_binding_cext.so` (post-build) | binary surgery       | —                                                                      |
| (app) | `app_{binding,helper}.ml`       | source patch                 | —                                                                      |

**Coverage gaps the chain view surfaces:**

- **Compiled-binding artifacts (bo6, bo7, bo10, bpe3) unperturbed** —
  no scenario edits the *compiled binding* (`.cmxa`, cext `.so`)
  directly. Source-level breakage of bo1..bo5 / bpc* / bpe1..bpe2 is
  well covered, but a post-build binary surgery would test the gap
  between source-level claims and artifact-level reality. Candidate
  scenario: strip a symbol from `bpe3` post-build.
- **Helper artifacts (bo8, bo9, bo10) unperturbed** — the downstream
  library is a new chain link (added with e12/e13), but no scenario
  perturbs it yet. Candidate scenarios: drop `sum_doubled` from `bo8`
  (API-completeness across helper layer); reverse args in `bo9`
  (API-repacking across helper layer). Either would directly test
  that repacking *composition* is detectable.
- **Python stub layers (bpc1, bpe1) unperturbed** — only the OCaml
  stub layer has a scenario (e8 touches bo1, bo2, bo3). A Python-side
  stub perturbation (wrong `argtypes` in `bpc1`, wrong `PyMethodDef`
  in `bpe1`) would balance the coverage.
- **App-level perturbation** is low priority — perturbing the app
  tests the app, not the binding.

The helper-layer gap is the closest follow-up to e12/e13. The
compiled-binding gap is now structurally easy to fill — Phase 3b's
`prepare` step already produces a post-build perturbation cache
entry per scenario, so a scenario that does binary surgery on
`bpe3` directly (rather than driving the perturbation via source +
rebuild) just needs a new `apply_*` function and a new entry in
`SCENARIOS`.

### Phase 3a — `prepare` and `confirm_ill`

A second flow alongside the existing `apply` / `revert` runner:
`scenarios.py prepare <name>` applies the perturbation, rebuilds
affected artifacts (skipping rebuild for artifact-direct
perturbations like e2 so the surgery survives), runs every
inspector, computes the surface delta against a cached **baseline**,
and writes `scenarios/_cache/<name>/confirm_ill.json`. The delta is
the machine-checkable form of "this perturbation does what its
`violates` claim says it does."

CLI:

```sh
make baseline                       # build + cache baseline JSONs (once)
make prepare-<scenario>             # prepare a single scenario
make prepare-all                    # all 12 in one pass (~8s)
python3 scenarios/scenarios.py confirm <name>   # show the cached delta
```

What we see today across the 12 scenarios, grouped by the shape of
the observed delta:

| shape                                        | scenarios                                                | confirm_ill shows                                                  |
| -------------------------------------------- | -------------------------------------------------------- | ------------------------------------------------------------------ |
| **n4 symbol delta**                          | e1 symbol_missing, e4 api_faithful                       | `n4.symbols.{added,removed}`                                       |
| **n4 ABI delta**                             | e2 abi_soname_bump                                       | `n4.soname.{baseline,perturbed}`                                   |
| **bo4 val delta**                            | e6 api_complete                                          | `bo4.vals.removed`                                                 |
| **bo7 undef-ref delta**                      | e8 symbol_orphan                                         | `bo7.requires.added`                                               |
| **bpc2 + bpe2 attr delta**                   | e11 api_complete_python                                  | `bpc2.attrs.removed`, `bpe2.attrs.removed`                         |
| **no static delta — intentionally invisible** | e5 api_repack, e7 behavior_silent, e10 api_repack_python | confirms `c3 cmp_behavior` / `c7 cmp_api_repack` are non-redundant |
| **no static delta — inspector gap**          | e3 type_wrong                                            | WARN — `n3` + `bo1` inspectors missing, c6 would catch this        |
| **no perturbation**                          | e12, e13                                                 | empty deltas (positive coverage)                                   |

The `intentionally invisible` row is the empirical evidence that
runtime probes (Behavior) subsidise contracts the static layer
can't yet see — exactly the gap §2.7 calls out.

### Phase 3b — cached artifacts and `restore`-driven runs

`prepare` now also snapshots the perturbed *artifacts* (libtiny.so
chain, cext `.so`, the three OCaml `.exe`s) and any patched source
files into `_cache/<name>/{artifacts, source}/`. A symmetric baseline
snapshot lives under `_cache/baseline/`. Two new commands move state
between live tree and cache:

```sh
python3 scenarios/scenarios.py restore-baseline    # _cache/baseline/* -> live
python3 scenarios/scenarios.py restore <name>      # baseline + scenario delta -> live
```

`restore <name>` first applies baseline (so files the scenario did
*not* perturb are clean), then overlays the scenario's cached
artifacts + source on top. Pure file copy; no rebuild, no
inspector runs.

A second harness — `scenarios/_harness/run_cached.py` — uses these
to skip the slow apply/build/inspect path:

```
restore <name>      → ill state on disk
[probes]            → run against restored exes
[comparators]       → consume cached _cache/<name>/inspect/*.json
[check.py]          → same outcome diff as the original harness
restore-baseline    → live tree clean for next iteration
```

The `make scenarios-cached` target runs the cached harness over all
12 scenarios (assumes `make prepare-all` was run once first).

**Measured timing** (WSL Linux, baseline + caches already populated):

| flow                                                                    | time | speedup |
| ----------------------------------------------------------------------- | ---- | ------- |
| `make scenarios` (apply / dune-build / inspect / probe / revert per run) | 9.9s |   1.0×  |
| `make scenarios-cached` (restore / probe / cached comparators per run)   | 6.3s |   1.6×  |

The wall-clock gain on tiny is modest because the baseline `make
scenarios` is already cheap (dune is incremental, the C lib is
tiny). The win scales with build cost — projects whose binding
takes minutes (Z3, LLVM) would see proportionally larger speedups.
The structural value is also independent of the speed: `prepare`
asserts "this perturbation does what we claim it does" *once*, then
many `run`s replay that recorded ill state deterministically.

**Cache layout** (per scenario, populated by `prepare`):

```
scenarios/_cache/baseline/
  artifacts/c_build/{libtiny.so, libtiny.so.1, libtiny.so.1.0}
  artifacts/cext/_native.cpython-*.so
  artifacts/ocaml/examples/{probe_baseline,app_binding,app_helper}.exe
  source/{c,ocaml,python_cext,python_ctypes}/...  (13 perturbable files)
  inspect/{n4,bo4,bo6,bo7,bpc2,bpe2,bpe3}.json

scenarios/_cache/<scenario>/
  manifest.json              # build status + captured artifact list
  confirm_ill.json           # surface delta vs baseline (Phase 3a)
  inspect/<alias>.json       # perturbed inspector outputs (Phase 3a)
  artifacts/                 # only files that differ from baseline
  source/                    # only files patched by the scenario
```

The full `_cache/` tree is gitignored.

### e9 — reserved slot for SymbolVersion

The SymbolVersion contract (`c5 cmp_sym_version`) is the only one in
§2.4 without a tiny witness. The natural scenario would carry a
`tiny_sum@@TINY_2.0` annotation on the library and a
`tiny_sum@TINY_FUTURE_99.0` requirement on the binding; the load
would fail with `version 'TINY_FUTURE_99.0' not found`. Implementation
needs `.symver` linker directives on **both sides** (library and at
least one binding's stubs.c / _native.c), which is more setup than
the other scenarios. Deferred to roadmap step 4 when `c5
cmp_sym_version` is being implemented — building e9 and c5 together
keeps them coupled as regression test ↔ comparator.

### cext vs. ctypes is visible in the failure mode

Looking down the Symbol- and ABI-class rows, the cext and ctypes
bindings both fail, but at *different phases*:

- **cext** fails at `import` time (the loader resolves all undefined
  refs eagerly when the `.so` is loaded into the Python interpreter).
- **ctypes** fails at first-call time for `symbol_missing` (`dlsym`
  returning NULL becomes `AttributeError` only when you touch the
  attribute) or at `CDLL(...)` time for `abi_soname_bump` (the file
  itself is missing — caught at open).

For Type and Behavior scenarios, the runtime mismatch surfaces
identically because the call site type-mismatch is unaffected by
mechanism. This is exactly what §2.3's static/dynamic axis predicts.

### e1 `symbol_missing` — Symbol contract

**Construction.** Rename `tiny_sum` to `tiny_total` in
`c/src/tiny.c` only; rebuild the C library. The header is **not**
edited, so anyone compiling against it still sees `tiny_sum`
declared — the binding's already-built stub artifacts have a
baked-in link requirement to `tiny_sum`, which the rebuilt library
no longer exports.

We can't construct this via `objcopy --redefine-sym` alone, because
on the local binutils that flag touches only `.symtab`, not the
`.dynsym` the loader actually reads.

**Stage where the break manifests, per binding:**

| binding              | stage                                                | exact error                                                            |
| -------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------- |
| OCaml (static)       | probe load — ld.so resolving NEEDED .so              | `probe_baseline.exe: symbol lookup error: undefined symbol: tiny_sum`   |
| `tiny_cext` (static) | Python `import tiny_cext` (dlopen of `_native.so`)    | `ImportError: undefined symbol: tiny_sum`                              |
| `tiny_ctypes` (dyn.) | Python `import tiny_ctypes` triggering `_raw.py`'s first `_lib.tiny_sum` access | `AttributeError: ... undefined symbol: tiny_sum` |

All three fail at the first launch / first lookup. Static bindings
resolve eagerly at load; ctypes resolves lazily but the `argtypes`
assignment in `_raw.py` triggers the first dlsym at import time.

**c1 catches this statically** — `libtiny_stubs.a` (OCaml) and
`_native.cpython-*.so` (cext) both have undef refs to `tiny_sum`;
libtiny's exports no longer contain it; set inclusion fails.

### e2 `abi_soname_bump` — ABI contract

**Construction.** Pure binary surgery (no rebuild):

1. Change SONAME from `libtiny.so.1` to `libtiny.so.2`. Uses
   `patchelf --set-soname` if installed, otherwise a same-length
   byte swap in `.dynstr`.
2. Rename `libtiny.so.1.0` → `libtiny.so.2.0`; rewire
   `libtiny.so.2` → new file; **delete `libtiny.so.1` and
   `libtiny.so` symlinks** so nothing on disk answers to the name
   the bindings expect.

Binding `NEEDED` entries still say `libtiny.so.1` — no matching file
anymore. ld.so can't find the library; Python ctypes can't open it.

**Outcomes:** all probes fail with "cannot open shared object";
static `c1 cmp_symbol` passes (the symbols on the renamed library
are unchanged); `c4 cmp_abi` would catch it but doesn't exist yet.

### e3 `type_wrong` — Type contract (manifests as Behavior)

**Construction.** Edit `c/src/tiny.c` so `tiny_sum` takes
`(double, double)`; leave `tiny.h` declaring `(int, int)`. The patch
removes `#include "tiny.h"` from tiny.c so gcc doesn't error on
"conflicting types"; the rest of the library is unchanged.

On x86-64 SysV ABI, ints and doubles live in *different register
classes* (`%edi`/`%esi` vs. `%xmm0`/`%xmm1`). The binding stub
passes ints; the function reads xmm registers (uninitialised on
entry — zero in this build). Result: `Tiny.sum 2 3 = 42` (i.e.
`(int)(0.0 + 0.0 + tiny_offset)`), not `47`. Garbage-but-deterministic.

**Why this is silent at the static level:** the linker and loader
work at *name* granularity, not signature granularity. No existing
comparator (c1 through c5) notices. A future `c6 cmp_type` would
catch it via header parse vs stub-facing decl comparison.

### e4 `api_faithful` — API-faithfulness contract (fully silent)

**Construction.** Add `int tiny_max(int a, int b)` to
`c/include/tiny.h` and `c/src/tiny.c`; rebuild C. **Bindings are
not updated** — neither the OCaml stub layer nor either Python
binding wraps `tiny_max`.

**This scenario is fully silent in the current harness.** Build and
probe all succeed because nothing in the existing surface changed;
no comparator catches the gap because `c8 cmp_api_faithfulness`
doesn't exist yet. The expectation is `all ok / all pass`. When `c8`
lands, this scenario's `expected` flips one outcome to `fail` and
`api_faithful` becomes the regression test for the new comparator.

The canonical "comparator-missing" scenario — different in
character from `symbol_orphan`, where the comparator catches the
violation but the build also rejects it.

### e5 `api_repack` — Intra-binding repacking (OCaml only)

**Construction.** OCaml `tiny.ml`:

```ocaml
- let diff   = Tiny_raw.diff
+ let diff a b = Tiny_raw.diff b a   (* silent argument reversal *)
```

Stub-facing layer is correct; C-side is correct; the bug lives
entirely inside the binding's user-facing repack.

**Outcomes:** OCaml probe fails (`Tiny.diff 5 2 = -3` not `3`);
Python bindings untouched (`tiny_cext` and `tiny_ctypes` probes
pass); no static comparator catches it (`c7 cmp_api_repack` doesn't
exist yet).

### e6 `api_complete` — API-completeness (OCaml only)

**Construction.** Drop `val sum` from `ocaml/tiny.mli`. The library
still defines `Tiny.sum` internally (since `tiny.ml` is unchanged),
but the `.mli` no longer exposes it. Any code calling `Tiny.sum`
from outside fails to compile.

**Outcomes:** dune build of the probe fails (`Unbound value
Tiny.sum`); `c2 cmp_api_completeness` statically catches it before
the build runs — the watchlist `{sum, diff, offset}` is no longer
satisfied by `tiny.mli`'s exported vals.

This is the only scenario where a static comparator **and** a build
failure agree, with the static signal *preceding* the build signal.

### e7 `behavior_silent` — Behavior contract

**Construction.** `c/src/tiny.c`: `tiny_sum` returns
`a - b - tiny_offset` instead of `a + b + tiny_offset`. Symbol
table, SONAME, header, every binding artifact — all unchanged. The
bug is purely a semantic regression in the implementation.

**The canonical "Behavior is non-redundant" demonstration.** Every
static contract still holds; the only way to catch this class of
failure is to *run* the code and compare against a reference. The
probe in `examples/probe_baseline.{ml,py}` is that runtime canary.

### e8 `symbol_orphan` — Symbol contract (binding-side orphan)

The dual of `symbol_missing`. There, the C side dropped a symbol the
binding still uses; here, the binding has a stub that references a
C symbol the C side never had. Both are violations of the same
Symbol contract; the directions are different.

**Construction.** Add `external extra : int -> int -> int = "caml_tiny_extra"`
to OCaml's stub-facing layer, plus a matching `caml_tiny_extra` C
wrapper in `tiny_stubs.c` that calls a `tiny_extra` it
forward-declares but `libtiny` never defines. The user-facing
`tiny.{mli,ml}` is **not** touched, and `examples/probe_baseline.ml`
doesn't reference the new entry. Python bindings untouched.

**Linker behaviour.** Modern linkers (mold, ld.bfd, ld.gold, ld.lld)
**all reject undefined symbols in executable links against shared
libs by default**. So the moment dune tries to link the probe
executable, the link refuses because `caml_tiny_extra` references
`tiny_extra` which no NEEDED library exports. `ocaml_build` fails.
The orphan would only be runtime-silent under explicit
`-Wl,--unresolved-symbols=ignore-in-shared-libs` or with a *dynamic*
FFI (ctypes-style) that defers symbol lookup to `dlsym`. Neither is
the case for a static cstubs binding, so on any real-world toolchain
this orphan is caught at link.

**Crucially, `libtiny_stubs.a` is built before the executable link
step** — so the static `c1 cmp_symbol` observes the orphan undef ref
even when the build fails downstream. c1's signal arrives *before*
the linker's, which is the right shape for a static comparator:
actionable diagnostics earlier in the pipeline than the toolchain's
own error.

**Dual symmetry with `symbol_missing`:**

| scenario          | direction                                     | caught at                                       |
| ----------------- | --------------------------------------------- | ----------------------------------------------- |
| `symbol_missing`  | C dropped a symbol the binding still uses     | load (lazy) + c1 (statically)                   |
| `symbol_orphan`   | binding references a symbol C never provided  | link (eager, modern linkers) + c1 (statically)  |

Both flip `cmp_symbol_ocaml` to `fail`. The runtime/build signals
differ by direction and linker policy.

## What `tiny` covers — and what it doesn't

Companion view to `surface_theory.md` §2.7. Records explicitly which
surfaces, inspectors, comparators, and scenarios `tiny` exercises
today.

### Inspector coverage by artifact

Surface-role population is up in the [Artifact inventory](#artifact-inventory--aliases--canonical-names);
this view is "for each artifact, what inspector parses it today."

**Table — Inspector coverage by artifact.** Rows are artifact
aliases. An empty `inspector` cell = no parser exists yet (a
canary-side gap).

| alias  | canonical name                  | inspector tool                                    | status              |
| ------ | ------------------------------- | ------------------------------------------------- | ------------------- |
| n3     | `header_native.h`               | — (`scan_source` presence check only)             | ✗ inspector missing |
| n4     | `lib_native.so`                 | `inspect_native.py` via `nm -D` + `readelf -d`    | ✓ wired             |
| bo1    | `stub_binding_ocaml.mli`        | — (mli inspector matches `^val`, not `external`)  | ✗ inspector missing |
| bo3    | `stub_binding_ocaml.c`          | — (no parser yet)                                 | ✗ inspector missing |
| bo4    | `user_binding_ocaml.mli`        | `inspect_binding.py --kind mli`                   | ✓ wired             |
| bo6    | `compiled_binding_ocaml.cmxa`   | `inspect_ocaml.py` via `ocamlobjinfo`             | ✓ wired             |
| bo7    | `compiled_binding_ocaml.stub-a` | `inspect_binding.py --kind stub` via `nm`         | ✓ wired             |
| bpc1   | `stub_binding_ctypes.py`        | — (no ctypes-decl parser)                         | ✗ inspector missing |
| bpc2   | `user_binding_ctypes.py`        | `inspect_python.py --pkg tiny_ctypes`             | ✓ wired             |
| bpe1   | `stub_binding_cext.c`           | — (no Py C API parser)                            | ✗ inspector missing |
| bpe2   | `user_binding_cext.py`          | `inspect_python.py --pkg tiny_cext`               | ✓ wired             |
| bpe3   | `compiled_binding_cext.so`      | `inspect_native.py` (same tool, on a binding ELF) | ✓ wired             |
| —      | runtime probe                   | probe binary + reference expected values          | ✓ implicit          |

Compact reading: `n4` (native lib, s2) and `b*2` (user-facing
syntactic, s4) are well covered. `n3` (s1) and the `s3` stub-facing
layer across every binding mechanism (`bo1`, `bpc1`, `bpe1`) are the
parsing gaps.

### Comparator invocations from the scenario harness

| comparator                       | exists in canary | invoked against `tiny` JSONs | status                            |
| -------------------------------- | ---------------- | ----------------------------- | --------------------------------- |
| c1 `cmp_symbol`                  | ✓                | ✓ ocaml stub + cext .so       | wired                             |
| c2 `cmp_api_completeness`        | ✓                | ✓ ocaml + cext + ctypes       | wired                             |
| c3 `cmp_behavior`                | ✓ (probes)       | ✓ every scenario              | wired                             |
| c4 `cmp_abi`                     | ✗ (not built)    | n/a                          | comparator missing                |
| c5 `cmp_sym_version`             | ✗ (not built)    | n/a                          | comparator missing                |
| c6 `cmp_type`                    | ✗ (not built)    | n/a                          | comparator missing                |
| c7 `cmp_api_repack`              | ✗ (not built)    | n/a                          | comparator missing                |
| c8 `cmp_api_faithfulness`        | ✗ (not built)    | n/a                          | comparator missing                |

Every existing comparator (c1, c2, c3) now produces a verdict in
each scenario run. For Symbol- and API-completeness-violating
scenarios, the harness records both a *static comparator verdict*
and the *runtime probe verdict*; when they disagree, that's a
regression signal. The harness implementations of c1 and c2 live as
small Python scripts under `scenarios/_harness/comparators/`; when
canary grows a CLI wrapper around its OCaml `check_c_compat` and
watchlist code, these scripts can swap to calling that wrapper.

### Summary of recorded gaps

| gap class                                    | items                                            | next step                                                                |
| -------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------ |
| By-design                                    | s5 × ctypes                                       | none — keep as demonstration                                              |
| Canary inspector missing (also in §2.7)      | n3, bo1, bpc1, bpe1                              | roadmap step 4                                                            |
| Canary comparator missing (also in §2.7)     | c4, c5, c6, c7, c8                                | roadmap step 4                                                            |
| Tiny wiring                                  | (closed) — bpe3 reuses `inspect_native.py`; bo6, c1, c2 all wired | done                                                  |

## Findings from building the scenarios

Documented here because each is a real fact about the tool chain that
the paper can cite, not folklore.

### Binutils `--redefine-sym` only touches `.symtab`, not `.dynsym`

Original plan had `symbol_missing` as a pure `objcopy --redefine-sym`
surgery (no source edit). Confirmed empirically: the rename lands in
the static symbol table, but `.dynsym` (what the dynamic loader
actually reads) is preserved. `patchelf` would have a path; not
installed locally. `pyelftools` either. A source patch + rebuild is
the practical minimum to break `.dynsym`.

For the paper: "pure binary surgery" stories are partly folklore —
the toolchain doesn't always cooperate, so the realistic answer for
Symbol-class breakage is "edit one source line and rebuild that
side." ABI-class breakage (SONAME) *is* genuinely surgical — see
`abi_soname_bump`.

### `mv` preserves mtime; cmake silently skips rebuild

A revert script that does `mv $BAK $SRC` moves the backup file
(with its old mtime) onto the source. cmake compares mtimes: source
older than `.o` → "nothing to do." The library stays in the apply
state, silently. Caught by the post-suite baseline probe failing.
Fix: `touch $SRC` after `mv`. Same pitfall threatens any tool that
does mtime-based dependency tracking — worth a note in the paper
alongside the Symbol/Type/Behavior discussion (it's why `make`
looks at *timestamps*, and why timestamps aren't enough for
semantic builds).

### Type-mismatch tries to be a Behavior bug deterministically

For `type_wrong`, the C source defines `tiny_sum(double, double)`
while the header still says `int`. On x86-64 SysV the caller passes
ints in `%edi`/`%esi`; the callee reads `%xmm0`/`%xmm1`. In
practice xmm regs at call time are zero (no xmm code ran in the
stub prelude), so the function deterministically returns
`(int)(0.0 + 0.0 + 42) = 42`. The probe expects `47` and fails
cleanly. The Type bug *appears* to manifest as a deterministic
Behavior bug — which is exactly how surface-theory frames it: Type
violations are caught by Behavior because no static checker exists
in canary today.

### `inspect_binding.py` doesn't parse `external`

The inspector matches `^val` not `^external`, so the stub-facing
`.mli` is invisible. Doesn't block the scenarios (which rely on
probes or the `.o`/`.so` inspections), but means no contract verdict
is being computed from the stub-facing surface yet. One-line regex
extension fixes it; deferred until we decide whether to generalise
the inspector to first-class stub-facing / user-facing distinction.

### Modern linkers default to `--no-undefined` for executables

All four modern linkers (mold, ld.bfd, ld.gold, ld.lld) reject
undefined symbols in executable links against shared libs *by
default*. The runtime-silent orphan case (`symbol_orphan`) is the
opt-in (`-Wl,--unresolved-symbols=ignore-in-shared-libs`), not the
default. On any modern toolchain `symbol_orphan` is caught at link;
the runtime-only flavour requires deliberate linker-flag opt-out
or a dynamic FFI binding.

### setuptools + PEP 517 via uv decouples build from runtime Python

The CPython C extension's canonical build path is `setup.py
build_ext` driven by setuptools. The local Python (3.14 from a uv
venv) doesn't ship setuptools or pip. `uv build --wheel` reads
`[build-system]` from `pyproject.toml`, brings setuptools into a
temporary build environment, produces a wheel, and exits cleanly —
no pollution of the project Python. This is exactly the kind of
decoupling the surface model rewards: the binding's *build* is its
own concern; what the binding artifact *is* is the contract.

## What `tiny` will earn the paper

1. **§1 motivating example.** Replace the multi-page Z3/LLVM
   walkthrough with one page showing `tiny`'s artifacts across three
   bindings and the twelve scenarios side by side.
2. **§2 worked instantiation.** The §2 contract table becomes a
   *checkable* claim: for `tiny`, here are the specific surfaces and
   the contract verdict for each scenario. The Phase 3a
   `confirm_ill.json` per scenario is the machine-verified form of
   that claim.
3. **§3 (subtyping) made concrete.** Subtyping relations can be
   exhibited on `tiny` records directly.
4. **§5 evaluation.** The scenario matrix is a clean "does canary
   detect this failure?" benchmark, with binary outcomes per contract
   per binding. Twelve scenarios × ~10 probe/comparator outcomes
   ≈ 120 data points from one library.
5. **Reproducibility.** Anyone reading the paper can clone, run, and
   reproduce every figure in under five minutes. With Z3/LLVM that's
   a day-plus of cmake.

## Not yet wired

- ✓ **`tiny` project spec** (2026-05-28 / expanded 2026-05-29).
  `src/canary/projects/canary_project_tiny.ml` exists and
  `canary action tiny` runs the same pipeline as `canary action
  z3` — 12 steps (6 main + 6 inspect) producing JSON shapes
  byte-equivalent to what `make scenarios-cached` produces for
  every artifact (n4, bo4, bo7, bpe2, bpe3). See [`phase4_2026_05.md`](../worklog/phase4_2026_05.md).
- **Rust binding.** Open question — worth including for the
  cross-binding agreement sub-component (§2.2). Deferred until the
  OCaml + Python scenario set has been reviewed.
- **`external` parsing in `inspect_binding.py`** (one-line regex).
- **API-faithfulness diff checker** — both inspector halves exist;
  needs only the comparator. `api_faithful` is the waiting
  regression test.
- **Comparator-only gaps** in §2.7: c4 cmp_abi and c5 cmp_sym_version
  could be wired without new inspectors. Pure plumbing.

## Decisions deferred

- **Scenarios as patches vs. branches.** Patches keep diffs minimal
  and reviewable; branches let you `canary action tiny --variant
  type_wrong` more cleanly. Default to patches; revisit if friction.
- **Behavior-contract mechanization.** The `behavior_silent` scenario
  needs a *probe* that compares against a reference. The probes
  already exist at `ocaml/examples/probe_baseline.ml` and the two
  Python `examples/probe_baseline.py` files; each exits non-zero on
  first mismatch, which is enough for the scenario harness.
