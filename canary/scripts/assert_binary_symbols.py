#!/usr/bin/env python3
"""Assert that required prefixed symbols from required libs are provided."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from typing import Iterable, Set


def is_macos() -> bool:
    return sys.platform == "darwin"


def nm_args(path: str, dynamic: bool) -> list[str]:
    if is_macos():
        # `nm -D` is GNU-specific; macOS `nm` exposes external symbols with `-g`.
        return ["nm", "-g", path]
    cmd = ["nm"]
    if dynamic:
        cmd.append("-D")
    cmd.append(path)
    return cmd


def run_nm(path: str, dynamic: bool) -> str:
    cmd = nm_args(path, dynamic)
    proc = subprocess.run(
        cmd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        msg = proc.stderr.strip() or proc.stdout.strip()
        raise RuntimeError(f"{' '.join(cmd)} failed: {msg}")
    return proc.stdout


def parse_undefined_symbols(nm_output: str, prefix: str) -> Set[str]:
    syms: Set[str] = set()
    pat = re.compile(rf"\bU\s+({re.escape(prefix)}\w+)$")
    for line in nm_output.splitlines():
        m = pat.search(line.strip())
        if m:
            syms.add(m.group(1))
    return syms


def parse_defined_symbols(nm_output: str, prefix: str) -> Set[str]:
    syms: Set[str] = set()
    # Allow optional ELF symbol version suffix (@@VER or @VER) after the name.
    pat = re.compile(rf"^(?:[0-9A-Fa-f]+\s+)?([A-Za-z])\s+({re.escape(prefix)}\w+)(?:@@?\S+)?$")
    for line in nm_output.splitlines():
        m = pat.match(line.strip())
        if not m:
            continue
        kind, sym = m.group(1), m.group(2)
        if kind.upper() == "U":
            continue
        syms.add(sym)
    return syms


def is_dynamic_nm_target(path: str) -> bool:
    base = os.path.basename(path)
    return (
        path.endswith(".so")
        or ".so." in base
        or path.endswith(".dylib")
        or ".dylib." in base
    )


def collect_required(required_libs: Iterable[str], prefix: str) -> Set[str]:
    required: Set[str] = set()
    for lib in required_libs:
        out = run_nm(lib, dynamic=is_dynamic_nm_target(lib))
        required |= parse_undefined_symbols(out, prefix)
    return required


def collect_provided(provided_lib: str, prefix: str) -> Set[str]:
    out = run_nm(provided_lib, dynamic=True)
    return parse_defined_symbols(out, prefix)


def main() -> int:
    p = argparse.ArgumentParser(description="Check binary symbol compatibility.")
    p.add_argument("--required-lib", action="append", default=[], required=True)
    p.add_argument("--provided-lib", required=True)
    p.add_argument("--symbol-prefix", default="Z3_")
    args = p.parse_args()

    for path in [*args.required_lib, args.provided_lib]:
        if not os.path.exists(path):
            print(f"ERROR: file not found: {path}", file=sys.stderr)
            return 2

    required = collect_required(args.required_lib, args.symbol_prefix)
    provided = collect_provided(args.provided_lib, args.symbol_prefix)
    missing = sorted(required - provided)

    print(f"required({len(required)}), provided({len(provided)}), missing({len(missing)})")
    if missing:
        print("Missing symbols:")
        for sym in missing:
            print(sym)
        return 1

    print("OK: all required symbols are provided.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
