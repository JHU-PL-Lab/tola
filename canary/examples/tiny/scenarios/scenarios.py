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
    scenarios.py expected <name>      # prints JSON for check.py
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
        "description": "OCaml user-facing Tiny.mli drops 'val sum'. Library still defines Tiny.sum internally; the probe references Tiny.sum and fails at compile time. c2 cmp_api_completeness statically catches the missing val on the OCaml side; Python bindings untouched.",
        "violates": ["API-completeness"],
        "perturbs": ["ocaml/tiny.mli"],  # [s4 OCaml]
        "apply":  _ml_patch_apply("api_complete"),
        "revert": _ml_patch_revert("api_complete"),
        "expected": {
            "ocaml_build":             "fail",
            "ocaml_probe":             "skip",
            "ocaml_app_binding":       "skip",
            "ocaml_app_helper":        "skip",
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
}


# ----- CLI ---------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["list", "apply", "revert", "expected"])
    ap.add_argument("name", nargs="?")
    args = ap.parse_args()

    if args.cmd == "list":
        for n in SCENARIOS:
            print(n)
        return 0

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
