#!/usr/bin/env python3
"""Extract ELF ABI metadata via readelf -d.

Output (JSON):
  {
    "kind": "elf",
    "path": "<path>",
    "soname": "libfoo.so.1" | null,
    "needed": ["libbar.so.1", ...],
    "rpath": ["/usr/lib/foo", ...],
    "runpath": ["$ORIGIN/../lib", ...]
  }
"""

import argparse
import json
import os
import re
import subprocess
import sys


def parse_readelf(path):
    """Run readelf -d and extract SONAME, NEEDED, RPATH, RUNPATH."""
    if not os.path.exists(path):
        print(f"inspect_elf: file not found: {path}", file=sys.stderr)
        return None

    try:
        out = subprocess.check_output(
            ["readelf", "-d", path],
            stderr=subprocess.STDOUT,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError) as e:
        print(f"inspect_elf: readelf failed: {e}", file=sys.stderr)
        return None

    soname = None
    needed = []
    rpath = []
    runpath = []

    # readelf -d output lines look like:
    #   0x000000000000000e (SONAME)    Library soname: [libz3.so.4.15]
    #   0x0000000000000001 (NEEDED)    Shared library: [libstdc++.so.6]
    #   0x000000000000001d (RUNPATH)   Library runpath: [$ORIGIN/../lib]
    #   0x000000000000000f (RPATH)     Library rpath: [/usr/lib/foo]

    soname_re = re.compile(r"\(SONAME\)\s+Library soname:\s+\[(.+)\]")
    needed_re = re.compile(r"\(NEEDED\)\s+Shared library:\s+\[(.+)\]")
    rpath_re = re.compile(r"\(RPATH\)\s+Library rpath:\s+\[(.+)\]")
    runpath_re = re.compile(r"\(RUNPATH\)\s+Library runpath:\s+\[(.+)\]")

    for line in out.splitlines():
        m = soname_re.search(line)
        if m:
            soname = m.group(1)
            continue
        m = needed_re.search(line)
        if m:
            needed.append(m.group(1))
            continue
        m = rpath_re.search(line)
        if m:
            rpath.append(m.group(1))
            continue
        m = runpath_re.search(line)
        if m:
            runpath.append(m.group(1))

    return {
        "soname": soname,
        "needed": needed,
        "rpath": rpath,
        "runpath": runpath,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Extract ELF ABI metadata via readelf -d")
    parser.add_argument("--path", required=True, help="Path to .so file")
    args = parser.parse_args()

    elf = parse_readelf(args.path)

    result = {
        "kind": "elf",
        "path": args.path,
        "soname": elf["soname"] if elf else None,
        "needed": elf["needed"] if elf else [],
        "rpath": elf["rpath"] if elf else [],
        "runpath": elf["runpath"] if elf else [],
    }

    json.dump(result, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
