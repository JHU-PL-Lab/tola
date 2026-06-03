#!/usr/bin/env python3
"""Tiny scenario harness — consolidated apply / revert / expected.

Single source of truth for the deliberately-broken variants. Each scenario:
  - description       — one-line summary
  - violates          — informational list of contracts the scenario breaks
  - perturbs          — artifact paths the scenario perturbs (relative to
                        canary/examples/tiny/). Source paths get a rebuild;
                        artifact paths (compiled .so etc.) are mutated
                        post-build. Empty for positive-coverage scenarios
                        (e12, e13). See "Chain coverage" in
                        doc/canary/research/tiny.md.
  - apply()/revert()  — produce / undo the broken state
  - expected          — per-step outcomes the harness comparator should observe

Patches for source-level edits live under `scenarios/patches/`; binary
surgery is implemented inline. The harness (`_harness/run.sh`) calls this
script as `scenarios.py apply <name>`, runs probes + comparators, then
`scenarios.py revert <name>` (always, via trap).

CLI:
    scenarios.py list
    scenarios.py apply <name>
    scenarios.py revert <name>
    scenarios.py expected <name>           # prints JSON for check.py
    scenarios.py baseline                  # build + inspect baseline, cache JSONs + artifacts
    scenarios.py prepare <name>            # apply + build + inspect + cache artifacts + revert
    scenarios.py prepare-all               # prepare every scenario sequentially
    scenarios.py confirm <name>            # show cached confirm_ill.json for <name>
    scenarios.py restore-baseline          # copy baseline cache -> live tree
    scenarios.py restore <name>            # copy baseline + scenario cache -> live tree (ill)

Phase 3a: prepare runs the scenario, captures the perturbed surface
JSONs, computes the surface delta vs the baseline cache, and writes
`_cache/<name>/confirm_ill.json` asserting "this perturbation
actually changes the claimed surfaces."

Phase 3b: prepare also snapshots perturbed artifacts (compiled .so /
.cmxa / .exe) and patched source files into the per-scenario cache.
`restore <name>` overlays them onto the live tree without running
apply/build, letting the harness run probes + comparators against
the ill state at file-copy speed. `restore-baseline` is the inverse.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent      # tiny/scenarios/
TINY = HERE.parent                          # tiny/
PATCHES = HERE / "patches"
C_BUILD = TINY / "c" / "build"

# Phase 3a cache layout (gitignored; see _cache/.gitignore):
#   _cache/baseline/inspect/<alias>.json   — clean baseline inspector outputs
#   _cache/<scenario>/manifest.json        — scenario metadata + build status
#   _cache/<scenario>/inspect/<alias>.json — perturbed inspector outputs
#   _cache/<scenario>/confirm_ill.json     — surface delta vs baseline
CACHE = HERE / "_cache"
BASELINE_CACHE = CACHE / "baseline"

# canary/scripts/ (inspector tools)
PROJ_ROOT = TINY.parent.parent.parent       # tola/
SCRIPTS = PROJ_ROOT / "canary" / "scripts"
OCAML_BUILD_DIR = PROJ_ROOT / "_build" / "default" / "canary" / "examples" / "tiny" / "ocaml"


# ----- generic helpers ---------------------------------------------------

def _run(*args, **kw):
    return subprocess.run(list(args), cwd=TINY, check=True, **kw)


def apply_patch(name: str) -> None:
    p = PATCHES / f"{name}.patch"
    if not p.exists():
        sys.exit(f"missing patch: {p}")
    _run("patch", "-p1", input=p.read_bytes())


def revert_patch(name: str) -> None:
    p = PATCHES / f"{name}.patch"
    if not p.exists():
        sys.exit(f"missing patch: {p}")
    _run("patch", "-R", "-p1", input=p.read_bytes())


def rebuild_c() -> None:
    _run("cmake", "--build", str(C_BUILD), stdout=subprocess.DEVNULL)


# ----- abi_soname_bump (binary surgery) ----------------------------------

def _have_patchelf() -> bool:
    return shutil.which("patchelf") is not None


def _bak(path: Path, tag: str) -> Path:
    return Path(str(path) + f".bak.{tag}")


def apply_abi_soname_bump() -> None:
    """Bump SONAME and rename file so the binding's NEEDED libtiny.so.1 has
    nothing to resolve against. Prefers `patchelf` when present; otherwise
    falls back to a same-length byte swap of the SONAME string in .dynstr."""
    tag = "abi_soname_bump"
    so_real = C_BUILD / "libtiny.so.1.0"
    so_1 = C_BUILD / "libtiny.so.1"
    so_no = C_BUILD / "libtiny.so"

    if _bak(so_real, tag).exists():
        sys.exit("already applied? backup exists")

    # Backups (preserve symlink-ness with cp -P).
    shutil.copy(so_real, _bak(so_real, tag))
    _run("cp", "-P", str(so_1), str(_bak(so_1, tag)))
    _run("cp", "-P", str(so_no), str(_bak(so_no, tag)))

    # Change SONAME.
    if _have_patchelf():
        _run("patchelf", "--set-soname", "libtiny.so.2", str(so_real))
        method = "patchelf"
    else:
        data = so_real.read_bytes()
        new = data.replace(b"libtiny.so.1\0", b"libtiny.so.2\0", 1)
        if new == data:
            sys.exit("SONAME string not found in .dynstr — was the lib already modified?")
        so_real.write_bytes(new)
        method = "byte-replace (no patchelf available)"

    # Rename file + rewire symlinks so libtiny.so.1 no longer exists.
    so_real.rename(C_BUILD / "libtiny.so.2.0")
    so_1.unlink()
    so_no.unlink()
    (C_BUILD / "libtiny.so.2").symlink_to("libtiny.so.2.0")

    print(f"apply abi_soname_bump: SONAME via {method}; libtiny.so.1 removed", file=sys.stderr)


def revert_abi_soname_bump() -> None:
    tag = "abi_soname_bump"
    so_real = C_BUILD / "libtiny.so.1.0"
    so_1 = C_BUILD / "libtiny.so.1"
    so_no = C_BUILD / "libtiny.so"

    if not _bak(so_real, tag).exists():
        return  # already reverted

    (C_BUILD / "libtiny.so.2.0").unlink(missing_ok=True)
    (C_BUILD / "libtiny.so.2").unlink(missing_ok=True)

    _bak(so_real, tag).rename(so_real)
    _bak(so_1, tag).rename(so_1)
    _bak(so_no, tag).rename(so_no)


# ----- patch-based scenarios ---------------------------------------------

# Each scenario that's just "patch + (maybe) rebuild" is a thin wrapper.
# C-side patches rebuild C; OCaml-side patches let the harness's dune build
# pick up the change.

def _c_patch_apply(name):  return lambda: (apply_patch(name), rebuild_c())
def _c_patch_revert(name): return lambda: (revert_patch(name), rebuild_c())
def _ml_patch_apply(name):  return lambda: apply_patch(name)
def _ml_patch_revert(name): return lambda: revert_patch(name)

def _noop() -> None:
    """For positive-coverage scenarios that exercise a baseline chain
    (e12, e13) — no perturbation is applied; the scenario asserts the
    chain is already wired correctly."""
    return None


# ----- scenarios table ---------------------------------------------------

SCENARIOS = {
    "symbol_missing": {
        "description": "Source patch renames tiny_sum -> tiny_total in C only; binding artifacts still expect tiny_sum.",
        "violates": ["Symbol"],
        "perturbs": ["c/src/tiny.c"],  # [s2 via rebuild]
        "apply":  _c_patch_apply("symbol_missing"),
        "revert": _c_patch_revert("symbol_missing"),
        "expected": {
            "ocaml_build":             "ok",
            "ocaml_probe":             "fail",
            "ocaml_app_binding":       "fail",
            "ocaml_app_helper":        "fail",
            "python_cext_probe":       "fail",
            "python_ctypes_probe":     "fail",
            "cmp_symbol_ocaml":        "fail",
            "cmp_symbol_cext":         "fail",
            "cmp_api_complete_ocaml":  "pass",
            "cmp_api_complete_cext":   "skip",
            "cmp_api_complete_ctypes": "skip",
        },
    },
    "abi_soname_bump": {
        "description": "SONAME bumped libtiny.so.1 -> libtiny.so.2 and file renamed; binding NEEDED libtiny.so.1 has nothing to resolve against. Symbols themselves unchanged.",
        "violates": ["ABI"],
        "perturbs": ["c/build/libtiny.so.1"],  # [s2 post-build, patchelf/byte surgery]
        "apply":  apply_abi_soname_bump,
        "revert": revert_abi_soname_bump,
        "expected": {
            "ocaml_build":             "ok",
            "ocaml_probe":             "fail",
            "ocaml_app_binding":       "fail",
            "ocaml_app_helper":        "fail",
            "python_cext_probe":       "fail",
            "python_ctypes_probe":     "fail",
            "cmp_symbol_ocaml":        "pass",
            "cmp_symbol_cext":         "pass",
            "cmp_api_complete_ocaml":  "pass",
            "cmp_api_complete_cext":   "skip",
            "cmp_api_complete_ctypes": "skip",
        },
    },
    "type_wrong": {
        "description": "tiny_sum body takes (double, double); header still says (int, int). Symbol names unchanged; no static comparator catches this today.",
        "violates": ["Type", "Behavior"],
        "perturbs": ["c/src/tiny.c"],  # [s2 via rebuild]
        "apply":  _c_patch_apply("type_wrong"),
        "revert": _c_patch_revert("type_wrong"),
        "expected": {
            "ocaml_build":             "ok",
            "ocaml_probe":             "fail",
            "ocaml_app_binding":       "fail",
            "ocaml_app_helper":        "fail",
            "python_cext_probe":       "fail",
            "python_ctypes_probe":     "fail",
            "cmp_symbol_ocaml":        "pass",
            "cmp_symbol_cext":         "pass",
            "cmp_api_complete_ocaml":  "pass",
            "cmp_api_complete_cext":   "pass",
            "cmp_api_complete_ctypes": "pass",
        },
    },
    "api_faithful": {
        "description": "C adds tiny_max; bindings don't wrap it. Build and probe all succeed; no static comparator catches the missing wrapper (c8 cmp_api_faithfulness doesn't exist yet).",
        "violates": ["API-faithfulness"],
        "perturbs": ["c/include/tiny.h", "c/src/tiny.c"],  # [s1 + s2 via rebuild]
        "apply":  _c_patch_apply("api_faithful"),
        "revert": _c_patch_revert("api_faithful"),
        "expected": {
            "ocaml_build":             "ok",
            "ocaml_probe":             "ok",
            "ocaml_app_binding":       "ok",
            "ocaml_app_helper":        "ok",
            "python_cext_probe":       "ok",
            "python_ctypes_probe":     "ok",
            "cmp_symbol_ocaml":        "pass",
            "cmp_symbol_cext":         "pass",
            "cmp_api_complete_ocaml":  "pass",
            "cmp_api_complete_cext":   "pass",
            "cmp_api_complete_ctypes": "pass",
        },
    },
    "api_repack": {
        "description": "OCaml user-facing Tiny.diff reverses arguments before delegating. Stub-facing layer correct; intra-binding repack wrong; c7 cmp_api_repack doesn't exist yet.",
        "violates": ["API-repacking", "Behavior"],
        "perturbs": ["ocaml/tiny.ml"],  # [s4 OCaml]
        "apply":  _ml_patch_apply("api_repack"),
        "revert": _ml_patch_revert("api_repack"),
        "expected": {
            "ocaml_build":             "ok",
            "ocaml_probe":             "fail",
            "ocaml_app_binding":       "fail",
            "ocaml_app_helper":        "fail",
            "python_cext_probe":       "ok",
            "python_ctypes_probe":     "ok",
            "cmp_symbol_ocaml":        "pass",
            "cmp_symbol_cext":         "pass",
            "cmp_api_complete_ocaml":  "pass",
            "cmp_api_complete_cext":   "pass",
            "cmp_api_complete_ctypes": "pass",
        },
    },
    "api_complete": {
        "description": "OCaml user-facing Tiny.mli drops 'val sum'. Library still defines Tiny.sum internally; the library compiles cleanly (tiny's dune sets -w -32 so 'unused value' is not promoted to an error — see ocaml/dune for why), but every consumer that references Tiny.sum fails at compile time (probe_baseline, app_binding directly; app_helper transitively via tiny_helper). c2 cmp_api_completeness statically catches the missing val on the OCaml side; Python bindings untouched.",
        "violates": ["API-completeness"],
        "perturbs": ["ocaml/tiny.mli"],  # [s4 OCaml]
        "apply":  _ml_patch_apply("api_complete"),
        "revert": _ml_patch_revert("api_complete"),
        "expected": {
            "ocaml_build":             "ok",
            "ocaml_probe":             "fail",
            "ocaml_app_binding":       "fail",
            "ocaml_app_helper":        "fail",
            "python_cext_probe":       "ok",
            "python_ctypes_probe":     "ok",
            "cmp_symbol_ocaml":        "pass",
            "cmp_symbol_cext":         "pass",
            "cmp_api_complete_ocaml":  "fail",
            "cmp_api_complete_cext":   "pass",
            "cmp_api_complete_ctypes": "pass",
        },
    },
    "behavior_silent": {
        "description": "tiny_sum body computes a-b-tiny_offset instead of a+b+tiny_offset. Every static contract still holds; only the running probe notices. The canonical demonstration that c3 cmp_behavior is non-redundant.",
        "violates": ["Behavior"],
        "perturbs": ["c/src/tiny.c"],  # [s2 via rebuild]
        "apply":  _c_patch_apply("behavior_silent"),
        "revert": _c_patch_revert("behavior_silent"),
        "expected": {
            "ocaml_build":             "ok",
            "ocaml_probe":             "fail",
            "ocaml_app_binding":       "fail",
            "ocaml_app_helper":        "fail",
            "python_cext_probe":       "fail",
            "python_ctypes_probe":     "fail",
            "cmp_symbol_ocaml":        "pass",
            "cmp_symbol_cext":         "pass",
            "cmp_api_complete_ocaml":  "pass",
            "cmp_api_complete_cext":   "pass",
            "cmp_api_complete_ctypes": "pass",
        },
    },
    "symbol_orphan": {
        "description": "OCaml stub introduces a `caml_tiny_extra` wrapper that calls `tiny_extra`; the C side never had `tiny_extra`. Dual of symbol_missing — there the C side dropped a needed symbol; here the binding has an unnecessary reference. On strict linkers (mold / `--no-undefined`) the executable link refuses the undef ref so `ocaml_build` fails; libtiny_stubs.a is built before that step, so c1 cmp_symbol still observes the orphan. On permissive linkers the build would succeed and only c1 would catch the violation.",
        "violates": ["Symbol"],
        "perturbs": ["ocaml/tiny_raw.ml", "ocaml/tiny_raw.mli", "ocaml/tiny_stubs.c"],  # [s3 OCaml]
        "apply":  _ml_patch_apply("symbol_orphan"),
        "revert": _ml_patch_revert("symbol_orphan"),
        "expected": {
            "ocaml_build":             "fail",
            "ocaml_probe":             "skip",
            "ocaml_app_binding":       "skip",
            "ocaml_app_helper":        "skip",
            "python_cext_probe":       "ok",
            "python_ctypes_probe":     "ok",
            "cmp_symbol_ocaml":        "fail",
            "cmp_symbol_cext":         "pass",
            "cmp_api_complete_ocaml":  "pass",
            "cmp_api_complete_cext":   "pass",
            "cmp_api_complete_ctypes": "pass",
        },
    },
    "api_repack_python": {
        "description": "Python user-facing layer (both cext and ctypes __init__.py) reverses arguments on `diff` before delegating. Stub-facing layer correct; intra-binding repack wrong; the same shape as e5 api_repack but on the Python side. OCaml binding untouched.",
        "violates": ["API-repacking", "Behavior"],
        "perturbs": ["python_cext/tiny_cext/__init__.py", "python_ctypes/tiny_ctypes/__init__.py"],  # [s4 Python]
        "apply":  _ml_patch_apply("api_repack_python"),
        "revert": _ml_patch_revert("api_repack_python"),
        "expected": {
            "ocaml_build":             "ok",
            "ocaml_probe":             "ok",
            "ocaml_app_binding":       "ok",
            "ocaml_app_helper":        "ok",
            "python_cext_probe":       "fail",
            "python_ctypes_probe":     "fail",
            "cmp_symbol_ocaml":        "pass",
            "cmp_symbol_cext":         "pass",
            "cmp_api_complete_ocaml":  "pass",
            "cmp_api_complete_cext":   "pass",
            "cmp_api_complete_ctypes": "pass",
        },
    },
    "api_complete_python": {
        "description": "Python user-facing layer (both cext and ctypes __init__.py) drops the `sum` function. The probes call `tiny.sum(...)` and raise AttributeError at runtime; c2 cmp_api_completeness catches it statically because the watchlist {sum, diff, offset} is no longer satisfied. OCaml binding untouched. Python-side parallel of e6 api_complete.",
        "violates": ["API-completeness"],
        "perturbs": ["python_cext/tiny_cext/__init__.py", "python_ctypes/tiny_ctypes/__init__.py"],  # [s4 Python]
        "apply":  _ml_patch_apply("api_complete_python"),
        "revert": _ml_patch_revert("api_complete_python"),
        "expected": {
            "ocaml_build":             "ok",
            "ocaml_probe":             "ok",
            "ocaml_app_binding":       "ok",
            "ocaml_app_helper":        "ok",
            "python_cext_probe":       "fail",
            "python_ctypes_probe":     "fail",
            "cmp_symbol_ocaml":        "pass",
            "cmp_symbol_cext":         "pass",
            "cmp_api_complete_ocaml":  "pass",
            "cmp_api_complete_cext":   "fail",
            "cmp_api_complete_ctypes": "fail",
        },
    },
    "app_over_binding_ocaml": {
        "description": "e12 positive-coverage: an app linking directly against the Tiny OCaml binding builds and runs; transitive dependency on libtiny.so resolves. No perturbation — the chain must already be wired.",
        "violates": [],
        "perturbs": [],
        "apply":  _noop,
        "revert": _noop,
        "expected": {
            "ocaml_build":             "ok",
            "ocaml_probe":             "ok",
            "ocaml_app_binding":       "ok",
            "ocaml_app_helper":        "ok",
            "python_cext_probe":       "ok",
            "python_ctypes_probe":     "ok",
            "cmp_symbol_ocaml":        "pass",
            "cmp_symbol_cext":         "pass",
            "cmp_api_complete_ocaml":  "pass",
            "cmp_api_complete_cext":   "pass",
            "cmp_api_complete_ctypes": "pass",
        },
    },
    "app_over_helper_ocaml": {
        "description": "e13 positive-coverage: longest-interesting chain — app -> tiny_helper -> Tiny binding -> libtiny.so. Confirms intra-binding repacking composes across a downstream library layer. No perturbation.",
        "violates": [],
        "perturbs": [],
        "apply":  _noop,
        "revert": _noop,
        "expected": {
            "ocaml_build":             "ok",
            "ocaml_probe":             "ok",
            "ocaml_app_binding":       "ok",
            "ocaml_app_helper":        "ok",
            "python_cext_probe":       "ok",
            "python_ctypes_probe":     "ok",
            "cmp_symbol_ocaml":        "pass",
            "cmp_symbol_cext":         "pass",
            "cmp_api_complete_ocaml":  "pass",
            "cmp_api_complete_cext":   "pass",
            "cmp_api_complete_ctypes": "pass",
        },
    },
    "api_repack_stub_orphan": {
        "description": "e14 stub-side orphan: Tiny_raw.mli (bo1) adds `external alias_sum` with a matching caml_tiny_alias_sum C wrapper, but Tiny.mli (bo4) doesn't surface it. The binding compiles + links + probes pass; c1 cmp_symbol passes (no new tiny_* undef refs — caml_tiny_alias_sum internally calls tiny_sum which is already exported); c2 cmp_api_completeness passes (bo4.vals still ⊇ watchlist). The orphan is invisible to today's standard harness; c7 cmp_api_repack catches it via bo1.externals \\ bo4.vals (minus declared renames).",
        "violates": ["API-repacking"],
        "perturbs": ["ocaml/tiny_raw.ml", "ocaml/tiny_raw.mli", "ocaml/tiny_stubs.c"],  # [s3 OCaml extension; orphan at s3↔s4]
        "apply":  _ml_patch_apply("api_repack_stub_orphan"),
        "revert": _ml_patch_revert("api_repack_stub_orphan"),
        "expected": {
            "ocaml_build":             "ok",
            "ocaml_probe":             "ok",
            "ocaml_app_binding":       "ok",
            "ocaml_app_helper":        "ok",
            "python_cext_probe":       "ok",
            "python_ctypes_probe":     "ok",
            "cmp_symbol_ocaml":        "pass",
            "cmp_symbol_cext":         "pass",
            "cmp_api_complete_ocaml":  "pass",
            "cmp_api_complete_cext":   "pass",
            "cmp_api_complete_ctypes": "pass",
        },
    },
}


# ----- Phase 3a: prepare / confirm-ill -----------------------------------

# Inspector registry. Each entry is (alias) -> callable returning the
# parsed JSON for that artifact, or None if the artifact is absent
# (e.g. build failed). Mirrors the inspector chain in
# _harness/run.sh; will be the shared source for both once 3b lands.

_LIBPATH = str(C_BUILD)


def _sh_json(cmd: str, **env_extra) -> dict | None:
    """Run a shell pipeline; parse stdout as JSON. Returns None on failure."""
    env = os.environ.copy()
    env.update(env_extra)
    try:
        out = subprocess.check_output(cmd, shell=True, cwd=TINY, text=True, env=env, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        return None
    if not out.strip():
        return None
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return None


def inspect_n4() -> dict | None:
    """n4 lib_native.so via inspect_native.py."""
    so = C_BUILD / "libtiny.so.1"
    if not so.exists():
        # SONAME-bumped variant?
        candidates = sorted(C_BUILD.glob("libtiny.so.*.0"))
        if not candidates:
            return None
        so = candidates[0]
    return _sh_json(
        f"nm -D '{so}' | python3 '{SCRIPTS}/inspect_native.py' "
        f"--path '{so}' --prefixes tiny_ --elf --emit-symbols"
    )


def inspect_bo4() -> dict | None:
    """bo4 user_binding_ocaml.mli."""
    mli = TINY / "ocaml" / "tiny.mli"
    if not mli.exists():
        return None
    return _sh_json(
        f"python3 '{SCRIPTS}/inspect_binding.py' --kind mli --path '{mli}'"
    )


def inspect_bo7() -> dict | None:
    """bo7 compiled_binding_ocaml.stub-a (undef refs)."""
    stub_a = next(iter(OCAML_BUILD_DIR.rglob("libtiny_stubs*.a")), None)
    if stub_a is None:
        return None
    return _sh_json(
        f"python3 '{SCRIPTS}/inspect_binding.py' --kind stub "
        f"--path '{stub_a}' --prefix tiny_"
    )


def inspect_bo6() -> dict | None:
    """bo6 compiled_binding_ocaml.cmxa (modules)."""
    cmxa = next(iter(OCAML_BUILD_DIR.rglob("tiny.cmxa")), None)
    if cmxa is None:
        return None
    return _sh_json(
        f"python3 '{SCRIPTS}/inspect_ocaml.py' --path '{cmxa}'"
    )


def inspect_bpe2() -> dict | None:
    """bpe2 user_binding_cext.py (dir(tiny_cext))."""
    return _sh_json(
        f"python3 '{SCRIPTS}/inspect_python.py' --pkg tiny_cext",
        PYTHONPATH=str(TINY / "python_cext"),
        LD_LIBRARY_PATH=_LIBPATH,
    )


def inspect_bpc2() -> dict | None:
    """bpc2 user_binding_ctypes.py (dir(tiny_ctypes))."""
    return _sh_json(
        f"python3 '{SCRIPTS}/inspect_python.py' --pkg tiny_ctypes",
        PYTHONPATH=str(TINY / "python_ctypes"),
        LD_LIBRARY_PATH=_LIBPATH,
    )


def inspect_bpe3() -> dict | None:
    """bpe3 compiled_binding_cext.so (undef refs — same shape as bo7)."""
    so = next(iter((TINY / "python_cext" / "tiny_cext").glob("_native.cpython-*.so")), None)
    if so is None:
        return None
    # nm -u + shape-coerce to c_stub form (matches run.sh)
    return _sh_json(
        f"nm -u '{so}' | awk '/^[[:space:]]*U /{{print $NF}}' | sort -u | "
        f"python3 -c \"import json,sys; "
        f"syms=[l.strip() for l in sys.stdin if l.strip() and l.strip().startswith('tiny_')]; "
        f"json.dump({{'kind':'c_stub','path':'{so}','counts':{{'required':len(syms)}},"
        f"'requires':sorted(syms)}},sys.stdout)\""
    )


INSPECTORS = {
    "n4":   inspect_n4,
    "bo4":  inspect_bo4,
    "bo6":  inspect_bo6,
    "bo7":  inspect_bo7,
    "bpc2": inspect_bpc2,
    "bpe2": inspect_bpe2,
    "bpe3": inspect_bpe3,
}


def _ensure_cache_dirs(scenario: str | None = None) -> None:
    CACHE.mkdir(exist_ok=True)
    (BASELINE_CACHE / "inspect").mkdir(parents=True, exist_ok=True)
    if scenario is not None:
        (CACHE / scenario / "inspect").mkdir(parents=True, exist_ok=True)


def _try_build_ocaml() -> bool:
    """Build the tiny OCaml {b library} (tiny.cmxa + libtiny_stubs.a),
    {i not} the consumer-side examples. The "ocaml_build" outcome should
    reflect "does the binding library compile?" — mli-narrowing
    perturbations (e.g. e6 api_complete drops val sum) leave the library
    intact (per OCaml's "ml may expose more than mli" semantics; tiny's
    dune sets -w -32 so unused-value isn't an error) but break consumers
    that reference the narrowed-away symbol. Those consumer failures
    surface in the dedicated ocaml_probe / ocaml_app_binding /
    ocaml_app_helper keys, not here."""
    env = os.environ.copy()
    env["LIBRARY_PATH"] = _LIBPATH + ":" + env.get("LIBRARY_PATH", "")
    env["LD_RUN_PATH"] = _LIBPATH + ":" + env.get("LD_RUN_PATH", "")
    r = subprocess.run(
        ["dune", "build", "tiny.cmxa", "libtiny_stubs.a"],
        cwd=TINY / "ocaml",
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return r.returncode == 0


def _build_native() -> bool:
    """Rebuild the C library. Returns success."""
    r = subprocess.run(
        ["cmake", "--build", str(C_BUILD)],
        cwd=TINY,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return r.returncode == 0


def _build_python_cext() -> bool:
    """Rebuild the CPython C extension via uv. Returns success."""
    r = subprocess.run(
        ["make", "python_cext"],
        cwd=TINY,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return r.returncode == 0


def _save_json(path: Path, obj: dict | None) -> None:
    if obj is None:
        return
    path.write_text(json.dumps(obj, indent=2, sort_keys=True))


def _load_json(path: Path) -> dict | None:
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return None


# ----- Phase 3b: artifact snapshot / restore -----------------------------

# Source files that any tiny scenario might perturb. Used for baseline
# snapshot (so restore-baseline can reset any of them) and as a closed
# universe for the perturbs field.
PERTURBABLE_SOURCES = [
    "c/src/tiny.c",
    "c/include/tiny.h",
    "ocaml/tiny.ml",
    "ocaml/tiny.mli",
    "ocaml/tiny_raw.ml",
    "ocaml/tiny_raw.mli",
    "ocaml/tiny_stubs.c",
    "ocaml/tiny_helper/tiny_helper.ml",
    "ocaml/tiny_helper/tiny_helper.mli",
    "python_cext/tiny_cext/__init__.py",
    "python_cext/tiny_cext/_native.c",
    "python_ctypes/tiny_ctypes/__init__.py",
    "python_ctypes/tiny_ctypes/_raw.py",
]


def _force_copy(src: Path, dst: Path) -> None:
    """copy2 that unlinks dst first (handles dune's read-only .exe outputs)
    and preserves the source's mode."""
    if dst.exists() or dst.is_symlink():
        try:
            dst.chmod(0o644)
        except OSError:
            pass
        dst.unlink()
    shutil.copy2(src, dst)


def _ocaml_exe(name: str) -> Path:
    return OCAML_BUILD_DIR / "examples" / name


OCAML_EXES = ("probe_baseline.exe", "app_binding.exe", "app_helper.exe")


def _cext_so_path() -> Path | None:
    return next(iter((TINY / "python_cext" / "tiny_cext").glob("_native.cpython-*.so")), None)


def _snapshot_artifacts(target_dir: Path) -> dict:
    """Copy live build outputs into target_dir/artifacts/. Returns a
    manifest of what was captured."""
    art = target_dir / "artifacts"
    art.mkdir(parents=True, exist_ok=True)
    captured = {"native": [], "cext": [], "ocaml_exes": []}

    # Native — c/build/libtiny.so*. Preserve symlinks.
    native_dir = art / "c_build"
    if native_dir.exists():
        shutil.rmtree(native_dir)
    native_dir.mkdir()
    if C_BUILD.exists():
        for f in C_BUILD.glob("libtiny.so*"):
            # Skip apply-time backups (e.g. libtiny.so.1.0.bak.abi_soname_bump)
            if ".bak." in f.name:
                continue
            dst = native_dir / f.name
            if f.is_symlink():
                dst.symlink_to(os.readlink(f))
            elif f.is_file():
                _force_copy(f, dst)
            captured["native"].append(f.name)

    # cext .so
    cext_dir = art / "cext"
    cext_dir.mkdir(exist_ok=True)
    cext_so = _cext_so_path()
    if cext_so is not None and cext_so.is_file():
        _force_copy(cext_so, cext_dir / cext_so.name)
        captured["cext"].append(cext_so.name)

    # OCaml .exe files
    ocaml_dir = art / "ocaml" / "examples"
    ocaml_dir.mkdir(parents=True, exist_ok=True)
    for exe in OCAML_EXES:
        src = _ocaml_exe(exe)
        if src.is_file():
            _force_copy(src, ocaml_dir / exe)
            captured["ocaml_exes"].append(exe)

    return captured


def _snapshot_sources(target_dir: Path, rel_paths: list[str]) -> list[str]:
    """Copy live source files (paths relative to TINY) into
    target_dir/source/. Returns the captured paths."""
    src_dir = target_dir / "source"
    if src_dir.exists():
        shutil.rmtree(src_dir)
    captured = []
    for rel in rel_paths:
        live = TINY / rel
        if not live.exists():
            continue
        dst = src_dir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        _force_copy(live, dst)
        captured.append(rel)
    return captured


# Top-level entries under TINY/ that should be excluded when materializing
# a workspace snapshot. The workspace is consumed by canary (Phase 14b) as
# a self-contained dune workspace; it doesn't need the harness's own
# state, the python build cache, dune's build dir, or the in-tree
# tests/docs.
_WORKSPACE_EXCLUDED_TOP = {
    "scenarios",          # harness state / patches / this script's cache
    "test",               # standalone harness tests
    "README.md",
    "Makefile",           # tiny's top-level Makefile (canary drives builds itself)
}
# Sub-tree fragments to skip during rglob (matched as any path segment):
# dune's build dir, bytecode caches. NOT "build" bare — c/build/ holds
# libtiny.so etc which canary needs.
_WORKSPACE_EXCLUDED_FRAGMENTS = {
    "_build",
    "__pycache__",
}
# Relative-to-TINY path prefixes to skip. Catches python_cext/build
# (uv wheel output, transient) without losing c/build (the live C
# library build dir). Also drops cmake's bookkeeping: the cached
# CMakeCache.txt encodes the {b live tree's} absolute source dir, so
# any cmake invocation against the materialized workspace would fail
# with "current cache directory ≠ source used to generate cache."
# We keep the {i artifacts} under c/build (libtiny.so* + symlinks);
# canary's tiny spec treats configure / build_lib as cached-artifact
# verification rather than re-cmaking.
_WORKSPACE_EXCLUDED_PREFIXES = (
    "python_cext/build/",
    "python_cext/tiny_cext.egg-info/",
    "c/build/CMakeFiles/",
    "c/build/CMakeCache.txt",
    "c/build/cmake_install.cmake",
    "c/build/Makefile",
)


def _snapshot_workspace(target_dir: Path) -> int:
    """Materialize a complete self-contained dune workspace at
    target_dir/workspace/. Called from cmd_prepare AFTER apply() so the
    perturbed sources are captured in place, and BEFORE revert().

    The workspace contains the full live tiny tree (minus harness state
    + dune/python build dirs) plus a minimal dune-project at the root so
    dune treats it as its own workspace (canary invokes `dune build
    --root <workspace>`). c/build/ is preserved so canary doesn't need
    to rebuild libtiny.so; python_cext/tiny_cext/_native.*.so likewise.

    Returns the number of files copied. The single-store workspace
    model (one path per variant) is a stepping stone toward the
    per-artifact-kind store model in canary's spec (14b').
    """
    ws_dir = target_dir / "workspace"
    if ws_dir.exists():
        shutil.rmtree(ws_dir)
    ws_dir.mkdir(parents=True)

    count = 0
    for entry in TINY.iterdir():
        if entry.name in _WORKSPACE_EXCLUDED_TOP:
            continue
        for src in entry.rglob("*"):
            if any(part in _WORKSPACE_EXCLUDED_FRAGMENTS for part in src.parts):
                continue
            if not src.is_file() and not src.is_symlink():
                continue
            rel = src.relative_to(TINY)
            rel_str = str(rel).replace(os.sep, "/")
            if any(rel_str.startswith(pfx) for pfx in _WORKSPACE_EXCLUDED_PREFIXES):
                continue
            dst = ws_dir / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            if src.is_symlink():
                link_target = os.readlink(src)
                if dst.exists() or dst.is_symlink():
                    dst.unlink()
                dst.symlink_to(link_target)
            else:
                _force_copy(src, dst)
            count += 1

    # Minimal standalone dune-project so dune treats this dir as a
    # workspace root (its presence stops dune from climbing up to the
    # tola workspace; `dune build --root` makes the choice explicit
    # but the file is needed for the workspace to be valid at all).
    (ws_dir / "dune-project").write_text("(lang dune 3.10)\n")
    count += 1
    return count


def _restore_native(cache_dir: Path) -> bool:
    """Replace c/build/libtiny.so* with the cached set. Returns True if
    any cache was applied."""
    native_cache = cache_dir / "artifacts" / "c_build"
    if not native_cache.exists():
        return False
    # Wipe existing libtiny.so* (regular + symlinks), skipping any
    # apply-time backups so revert still finds them if needed.
    for f in C_BUILD.glob("libtiny.so*"):
        if ".bak." in f.name:
            continue
        if f.is_symlink() or f.is_file():
            f.unlink()
    # Lay down cached files (preserving symlinks)
    for f in native_cache.glob("libtiny.so*"):
        if ".bak." in f.name:
            continue
        dst = C_BUILD / f.name
        if f.is_symlink():
            dst.symlink_to(os.readlink(f))
        else:
            _force_copy(f, dst)
    return True


def _restore_cext(cache_dir: Path) -> bool:
    cext_cache = cache_dir / "artifacts" / "cext"
    if not cext_cache.exists():
        return False
    cext_dst_dir = TINY / "python_cext" / "tiny_cext"
    for f in cext_cache.glob("_native.cpython-*.so"):
        _force_copy(f, cext_dst_dir / f.name)
    return True


def _restore_ocaml_exes(cache_dir: Path) -> bool:
    ocaml_cache = cache_dir / "artifacts" / "ocaml" / "examples"
    if not ocaml_cache.exists():
        return False
    dst_dir = OCAML_BUILD_DIR / "examples"
    if not dst_dir.exists():
        return False
    for exe in OCAML_EXES:
        src = ocaml_cache / exe
        if src.is_file():
            _force_copy(src, dst_dir / exe)
    return True


def _restore_sources(cache_dir: Path) -> list[str]:
    """Copy cached source files back to live locations. Returns the
    list of files restored."""
    src_dir = cache_dir / "source"
    if not src_dir.exists():
        return []
    restored = []
    for src in src_dir.rglob("*"):
        if not src.is_file():
            continue
        rel = src.relative_to(src_dir)
        dst = TINY / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        _force_copy(src, dst)
        restored.append(str(rel))
    return restored


def cmd_baseline() -> int:
    """Build everything clean, run every inspector, save JSONs under
    _cache/baseline/inspect/. Used as the comparison point for
    `prepare`."""
    _ensure_cache_dirs()
    print("baseline: ensuring native + bindings are built", file=sys.stderr)
    if not _build_native():
        sys.exit("baseline: C build failed")
    if not _try_build_ocaml():
        sys.exit("baseline: OCaml build failed")
    if not _build_python_cext():
        sys.exit("baseline: Python cext build failed")
    inspect_dir = BASELINE_CACHE / "inspect"
    for alias, fn in INSPECTORS.items():
        result = fn()
        if result is None:
            print(f"baseline: WARN {alias} produced no JSON", file=sys.stderr)
            continue
        _save_json(inspect_dir / f"{alias}.json", result)
        print(f"baseline: {alias} -> {inspect_dir / (alias + '.json')}", file=sys.stderr)
    # Phase 3b: snapshot baseline artifacts + sources so restore-baseline
    # can reset the live tree to clean state at file-copy speed.
    art_manifest = _snapshot_artifacts(BASELINE_CACHE)
    src_captured = _snapshot_sources(BASELINE_CACHE, PERTURBABLE_SOURCES)
    print(f"baseline: snapshot artifacts {art_manifest}", file=sys.stderr)
    print(f"baseline: snapshot {len(src_captured)} source files", file=sys.stderr)
    # Phase 14b: materialize the baseline workspace so canary's baseline
    # variant has the same {workspace}/{dune-project at root} shape as
    # every perturbed variant. (canary could equivalently point at the
    # live tree for baseline, but routing every variant through
    # _cache/<name>/workspace keeps the spec uniform.)
    ws_count = _snapshot_workspace(BASELINE_CACHE)
    print(f"baseline: snapshot workspace ({ws_count} files)", file=sys.stderr)
    return 0


def _surface_delta(baseline: dict | None, perturbed: dict | None) -> dict:
    """Compute a compact diff between two inspector JSONs. Surfaces
    the *changed* keys we care about: symbol sets, val/attr/module
    lists, SONAME, NEEDED. Returns {} on no change."""
    if baseline is None and perturbed is None:
        return {"status": "both_absent"}
    if baseline is None:
        return {"status": "baseline_absent", "perturbed": perturbed}
    if perturbed is None:
        return {"status": "perturbed_absent"}
    delta: dict = {}
    # Set-valued fields worth diffing
    for field in ("symbols", "requires", "vals", "attrs", "modules"):
        b = baseline.get(field)
        p = perturbed.get(field)
        if b is None and p is None:
            continue
        b_set = set(b or [])
        p_set = set(p or [])
        if b_set != p_set:
            delta[field] = {
                "added":   sorted(p_set - b_set),
                "removed": sorted(b_set - p_set),
            }
    # ELF fields (native lib inspector nests these under "elf")
    b_elf = baseline.get("elf") or {}
    p_elf = perturbed.get("elf") or {}
    if b_elf.get("soname") != p_elf.get("soname"):
        delta["soname"] = {
            "baseline":  b_elf.get("soname"),
            "perturbed": p_elf.get("soname"),
        }
    b_needed = set(b_elf.get("needed") or [])
    p_needed = set(p_elf.get("needed") or [])
    if b_needed != p_needed:
        delta["needed"] = {
            "added":   sorted(p_needed - b_needed),
            "removed": sorted(b_needed - p_needed),
        }
    return delta


def cmd_prepare(name: str) -> int:
    """Run scenario apply, build, inspect each artifact, diff against
    baseline, save confirm_ill.json. Always reverts at the end."""
    if not (BASELINE_CACHE / "inspect").exists():
        sys.exit("prepare: no baseline cache. Run `scenarios.py baseline` first.")
    if name not in SCENARIOS:
        sys.exit(f"prepare: unknown scenario: {name!r}")
    s = SCENARIOS[name]
    _ensure_cache_dirs(name)
    scen_dir = CACHE / name
    inspect_dir = scen_dir / "inspect"

    # Clean prior cache for this scenario
    for f in inspect_dir.glob("*.json"):
        f.unlink()

    # Decide which rebuilds to skip: artifact-direct perturbations
    # (paths under c/build/ or _build/) must NOT be rebuilt — that would
    # clobber the perturbation. Source-side perturbations need the rebuild
    # to propagate into compiled artifacts.
    perturbs = s.get("perturbs", []) or []
    skip_native_build = any(p.startswith("c/build/") for p in perturbs)
    skip_ocaml_build = any(p.startswith("_build/") for p in perturbs)

    print(f"prepare {name}: apply", file=sys.stderr)
    s["apply"]()

    try:
        # Build pipeline (record per-component success; skip clobbering rebuilds)
        build_status = {
            "native": True if skip_native_build else _build_native(),
            "ocaml":  True if skip_ocaml_build else _try_build_ocaml(),
            # Skip python_cext rebuild here — too slow to do in every prepare;
            # we only re-inspect what's already built. Phase 3b will cache it.
        }
        # Run each inspector, save JSONs
        perturbed = {}
        for alias, fn in INSPECTORS.items():
            result = fn()
            if result is not None:
                _save_json(inspect_dir / f"{alias}.json", result)
            perturbed[alias] = result

        # Compute deltas vs baseline
        baseline = {}
        for alias in INSPECTORS:
            baseline[alias] = _load_json(BASELINE_CACHE / "inspect" / f"{alias}.json")

        deltas: dict = {}
        for alias in INSPECTORS:
            d = _surface_delta(baseline[alias], perturbed[alias])
            if d:
                deltas[alias] = d

        confirm = {
            "scenario":    name,
            "description": s["description"],
            "perturbs":    s.get("perturbs", []),
            "violates":    s["violates"],
            "build":       build_status,
            "deltas":      deltas,
        }
        # Phase 3b: snapshot the perturbed artifacts + patched source so
        # `restore <name>` can reproduce this state without re-running
        # apply + build.
        art_manifest = _snapshot_artifacts(scen_dir)
        # Source snapshot: only the files listed in perturbs that exist
        # as plain source paths (skip post-build artifact paths like
        # c/build/libtiny.so.1 — those are captured under artifacts/).
        source_perturbs = [p for p in perturbs if p in PERTURBABLE_SOURCES]
        src_captured = _snapshot_sources(scen_dir, source_perturbs)
        # Phase 14b: materialize a self-contained dune workspace
        # capturing the full perturbed tree. canary points each variant
        # at its scenario's workspace and invokes `dune build --root`.
        ws_count = _snapshot_workspace(scen_dir)

        _save_json(scen_dir / "confirm_ill.json", confirm)
        _save_json(scen_dir / "manifest.json", {
            "scenario":          name,
            "build":             build_status,
            "inspected_aliases": sorted(perturbed.keys()),
            "snapshot_artifacts": art_manifest,
            "snapshot_sources":  src_captured,
            "snapshot_workspace_files": ws_count,
        })

        # Some scenarios are static-invisible by design: their violation
        # only shows up at runtime (Behavior) or via a not-yet-wired
        # comparator (API-repacking needs c7). Don't WARN on those.
        STATIC_INVISIBLE = {"Behavior", "API-faithfulness", "API-repacking"}
        violations = set(s.get("violates", []))
        intentionally_invisible = violations and violations.issubset(STATIC_INVISIBLE)
        confirm["intentionally_static_invisible"] = intentionally_invisible

        # WARN only if perturbs is non-empty, build succeeded, no deltas,
        # AND the scenario claims something statically detectable.
        if (not deltas
                and build_status["ocaml"]
                and s.get("perturbs")
                and not intentionally_invisible):
            print(f"prepare {name}: WARN — perturbs={s['perturbs']} but no surface delta observed",
                  file=sys.stderr)

        # Summary line
        affected = sorted(deltas.keys())
        build_summary = "/".join(f"{k}={'ok' if v else 'fail'}" for k, v in build_status.items())
        print(f"prepare {name}: build {build_summary}; surface deltas on {affected or '(none)'}",
              file=sys.stderr)

    finally:
        print(f"prepare {name}: revert", file=sys.stderr)
        s["revert"]()
        # Restore baseline build state so the next scenario starts clean
        _build_native()
        _try_build_ocaml()

    return 0


def cmd_prepare_all() -> int:
    if not (BASELINE_CACHE / "inspect").exists():
        cmd_baseline()
    fail = 0
    for name in SCENARIOS:
        try:
            cmd_prepare(name)
        except SystemExit as e:
            print(f"prepare-all: {name} FAILED ({e})", file=sys.stderr)
            fail += 1
    return 0 if fail == 0 else 1


def cmd_confirm(name: str) -> int:
    p = CACHE / name / "confirm_ill.json"
    if not p.exists():
        sys.exit(f"confirm: no cache for {name!r}; run `scenarios.py prepare {name}` first")
    sys.stdout.write(p.read_text())
    sys.stdout.write("\n")
    return 0


def cmd_restore_baseline() -> int:
    """File-copy baseline cache into the live tree. Resets every
    perturbable source file and every build output to clean state."""
    if not BASELINE_CACHE.exists():
        sys.exit("restore-baseline: no baseline cache; run `scenarios.py baseline` first")
    _restore_native(BASELINE_CACHE)
    _restore_cext(BASELINE_CACHE)
    _restore_ocaml_exes(BASELINE_CACHE)
    restored = _restore_sources(BASELINE_CACHE)
    print(f"restore-baseline: restored {len(restored)} sources + artifacts", file=sys.stderr)
    return 0


def cmd_restore(name: str) -> int:
    """Overlay the perturbed cache for <name> onto the live tree.
    Restores baseline first so files the scenario did NOT perturb are
    clean. Returns 1 if no cache exists for <name>."""
    if name not in SCENARIOS:
        sys.exit(f"restore: unknown scenario: {name!r}")
    scen_dir = CACHE / name
    if not scen_dir.exists():
        sys.exit(f"restore: no cache for {name!r}; run `scenarios.py prepare {name}` first")
    # Reset to baseline first so non-perturbed files match clean state.
    cmd_restore_baseline()
    _restore_native(scen_dir)
    _restore_cext(scen_dir)
    _restore_ocaml_exes(scen_dir)
    restored = _restore_sources(scen_dir)
    print(f"restore {name}: overlay {len(restored)} sources + artifacts", file=sys.stderr)
    return 0


# ----- CLI ---------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=[
        "list", "apply", "revert", "expected",
        "baseline", "prepare", "prepare-all", "confirm",
        "restore-baseline", "restore",
    ])
    ap.add_argument("name", nargs="?")
    args = ap.parse_args()

    if args.cmd == "list":
        for n in SCENARIOS:
            print(n)
        return 0
    if args.cmd == "baseline":
        return cmd_baseline()
    if args.cmd == "prepare-all":
        return cmd_prepare_all()
    if args.cmd == "restore-baseline":
        return cmd_restore_baseline()

    if args.cmd in ("prepare", "confirm", "restore"):
        if not args.name:
            sys.exit(f"{args.cmd}: missing scenario name")
        if args.cmd == "prepare":
            return cmd_prepare(args.name)
        if args.cmd == "confirm":
            return cmd_confirm(args.name)
        return cmd_restore(args.name)

    if not args.name or args.name not in SCENARIOS:
        sys.exit(f"unknown scenario: {args.name!r}; try `list`")

    s = SCENARIOS[args.name]
    if args.cmd == "apply":
        s["apply"]()
    elif args.cmd == "revert":
        s["revert"]()
    elif args.cmd == "expected":
        json.dump({
            "scenario":    args.name,
            "description": s["description"],
            "violates":    s["violates"],
            "perturbs":    s.get("perturbs", []),
            "outcomes":    s["expected"],
        }, sys.stdout, indent=2)
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
