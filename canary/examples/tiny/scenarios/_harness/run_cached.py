#!/usr/bin/env python3
"""Phase 3b: run a single scenario against the prepared cache.

Drops all the slow steps from run.sh (no apply, no dune build, no
inspector invocations). Instead:
  1. `scenarios.py restore <name>` overlays the cached ill state
     onto the live tree (file copies, ~ms).
  2. Probes run against the restored artifacts.
  3. Comparators consume the cached inspect JSONs.
  4. Build outcomes are read from the cached manifest.
  5. `scenarios.py restore-baseline` resets the tree.

Usage:  run_cached.py <scenario-name>

Output matches run.sh: per-scenario outcomes, then PASS/FAIL summary.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

HARNESS_DIR = Path(__file__).resolve().parent
SCENARIOS_DIR = HARNESS_DIR.parent
TINY = SCENARIOS_DIR.parent
PROJ_ROOT = TINY.parent.parent.parent
CACHE = SCENARIOS_DIR / "_cache"

LIBPATH = TINY / "c" / "build"
OCAML_BUILD_DIR = PROJ_ROOT / "_build" / "default" / "canary" / "examples" / "tiny" / "ocaml"
WATCHLIST = "sum,diff,offset"

CMP_DIR = HARNESS_DIR / "comparators"


def run_probe(exe: Path, env_extra: dict | None = None) -> str:
    """Run an executable / Python probe; return 'ok' / 'fail' / 'skip'."""
    if not exe.exists():
        return "skip"
    env = os.environ.copy()
    env["LD_LIBRARY_PATH"] = f"{LIBPATH}:{env.get('LD_LIBRARY_PATH', '')}"
    if env_extra:
        env.update(env_extra)
    try:
        r = subprocess.run([str(exe)], cwd=TINY, env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
        return "ok" if r.returncode == 0 else "fail"
    except subprocess.TimeoutExpired:
        return "fail"


def run_python_probe(pkg: str) -> str:
    """Run a probe_baseline.py under PYTHONPATH=python_<pkg>."""
    env = os.environ.copy()
    env["LD_LIBRARY_PATH"] = f"{LIBPATH}:{env.get('LD_LIBRARY_PATH', '')}"
    env["PYTHONPATH"] = str(TINY / f"python_{pkg}")
    script = TINY / f"python_{pkg}" / "examples" / "probe_baseline.py"
    if not script.exists():
        return "skip"
    try:
        r = subprocess.run(["python3", str(script)], cwd=TINY, env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
        return "ok" if r.returncode == 0 else "fail"
    except subprocess.TimeoutExpired:
        return "fail"


def run_cmp(*cmd) -> str:
    """Run a comparator; map exit codes: 0 pass, 2 skip, else fail."""
    try:
        r = subprocess.run(list(cmd), stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=10)
    except subprocess.TimeoutExpired:
        return "fail"
    if r.returncode == 0:
        return "pass"
    if r.returncode == 2:
        return "skip"
    return "fail"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: run_cached.py <scenario-name>", file=sys.stderr)
        return 2
    name = sys.argv[1]
    scen_cache = CACHE / name
    if not scen_cache.exists():
        print(f"run_cached: no cache for {name!r}; run `scenarios.py prepare {name}` first", file=sys.stderr)
        return 2

    # Pull expected outcomes
    expected_raw = subprocess.check_output(
        ["python3", str(SCENARIOS_DIR / "scenarios.py"), "expected", name])
    expected_doc = json.loads(expected_raw)

    print(f"==> scenario: {name}  (cached)")

    # Restore the perturbed state
    subprocess.run(
        ["python3", str(SCENARIOS_DIR / "scenarios.py"), "restore", name],
        check=True, stderr=subprocess.DEVNULL)

    try:
        # OCaml build outcome from the cached manifest
        manifest = json.loads((scen_cache / "manifest.json").read_text())
        ocaml_build = "ok" if manifest["build"]["ocaml"] else "fail"
        print(f"--- ocaml build (from cache) -> {ocaml_build}")

        # Comparators against cached JSONs
        print("--- comparators (cached)")
        inspect = scen_cache / "inspect"
        n4   = inspect / "n4.json"
        bo7  = inspect / "bo7.json"
        bo4  = inspect / "bo4.json"
        bpc2 = inspect / "bpc2.json"
        bpe2 = inspect / "bpe2.json"
        bpe3 = inspect / "bpe3.json"

        # c1 cmp_symbol — OCaml stub vs native
        if n4.exists() and bo7.exists():
            cmp_symbol_ocaml = run_cmp(
                "python3", str(CMP_DIR / "cmp_symbol.py"),
                "--native", str(n4), "--consumer", str(bo7), "--prefix", "tiny_")
        else:
            cmp_symbol_ocaml = "skip"
        print(f"    c1 cmp_symbol (ocaml)  -> {cmp_symbol_ocaml}")

        # c1 cmp_symbol — cext .so vs native
        if n4.exists() and bpe3.exists():
            cmp_symbol_cext = run_cmp(
                "python3", str(CMP_DIR / "cmp_symbol.py"),
                "--native", str(n4), "--consumer", str(bpe3), "--prefix", "tiny_")
        else:
            cmp_symbol_cext = "skip"
        print(f"    c1 cmp_symbol (cext)   -> {cmp_symbol_cext}")

        # c2 cmp_api_completeness — OCaml mli
        cmp_api_ocaml = (run_cmp(
            "python3", str(CMP_DIR / "cmp_api_completeness.py"),
            "--user", str(bo4), "--field", "vals", "--watchlist", WATCHLIST)
            if bo4.exists() else "skip")
        print(f"    c2 cmp_api_complete (ocaml)  -> {cmp_api_ocaml}")

        cmp_api_cext = (run_cmp(
            "python3", str(CMP_DIR / "cmp_api_completeness.py"),
            "--user", str(bpe2), "--field", "attrs", "--watchlist", WATCHLIST)
            if bpe2.exists() else "skip")
        print(f"    c2 cmp_api_complete (cext)   -> {cmp_api_cext}")

        cmp_api_ctypes = (run_cmp(
            "python3", str(CMP_DIR / "cmp_api_completeness.py"),
            "--user", str(bpc2), "--field", "attrs", "--watchlist", WATCHLIST)
            if bpc2.exists() else "skip")
        print(f"    c2 cmp_api_complete (ctypes) -> {cmp_api_ctypes}")

        # Probes against restored artifacts
        print("--- probes")
        ocaml_probe_run = run_probe(OCAML_BUILD_DIR / "examples" / "probe_baseline.exe") if ocaml_build == "ok" else "skip"
        ocaml_app_binding = run_probe(OCAML_BUILD_DIR / "examples" / "app_binding.exe") if ocaml_build == "ok" else "skip"
        ocaml_app_helper = run_probe(OCAML_BUILD_DIR / "examples" / "app_helper.exe") if ocaml_build == "ok" else "skip"
        python_cext_probe = run_python_probe("cext")
        python_ctypes_probe = run_python_probe("ctypes")
        print(f"    ocaml probe       -> {ocaml_probe_run}")
        print(f"    ocaml app_binding -> {ocaml_app_binding}")
        print(f"    ocaml app_helper  -> {ocaml_app_helper}")
        print(f"    cext probe        -> {python_cext_probe}")
        print(f"    ctypes probe      -> {python_ctypes_probe}")

        # Compare via check.py — same flag set as run.sh
        print("--- compare")
        expected_path = scen_cache / "_expected_for_check.json"
        expected_path.write_text(json.dumps(expected_doc))
        r = subprocess.run([
            "python3", str(HARNESS_DIR / "check.py"), str(expected_path),
            "--ocaml-build", ocaml_build,
            "--ocaml-probe", ocaml_probe_run,
            "--ocaml-app-binding", ocaml_app_binding,
            "--ocaml-app-helper", ocaml_app_helper,
            "--python-cext-probe", python_cext_probe,
            "--python-ctypes-probe", python_ctypes_probe,
            "--cmp-symbol-ocaml", cmp_symbol_ocaml,
            "--cmp-symbol-cext", cmp_symbol_cext,
            "--cmp-api-complete-ocaml", cmp_api_ocaml,
            "--cmp-api-complete-cext", cmp_api_cext,
            "--cmp-api-complete-ctypes", cmp_api_ctypes,
        ])
        expected_path.unlink(missing_ok=True)
        return r.returncode

    finally:
        # Reset to baseline so the next scenario starts clean.
        subprocess.run(
            ["python3", str(SCENARIOS_DIR / "scenarios.py"), "restore-baseline"],
            check=False, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    sys.exit(main())
