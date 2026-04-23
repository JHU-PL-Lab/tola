#!/usr/bin/env python3
"""Summarize an OCaml archive artifact (.cmxa/.cma) or opam package.

Reads `ocamlobjinfo` output from stdin; emits compact JSON summary.
OCaml tools don't expose constructor-level APIs programmatically in a
clean way, so this is module-level only. Constructor-level drift is
detected via compile probes (Expect_failure).

Output schema:
- counts.modules: number of compilation units in the archive
- modules: list of module names
- imports: count of imported module interfaces (dependency surface)
- watchlist.{present,missing}: presence at module level

Usage: ocamlobjinfo lib.cmxa | summarize_ocaml.py --path lib.cmxa \\
         --watchlist Fmt,Fmt_tty
"""
import argparse
import json
import re
import sys


def parse_ocamlobjinfo(lines):
    modules = []
    imports = 0
    in_imports = False
    for line in lines:
        line = line.rstrip("\n")
        # "Name: Fmt" identifies a compilation unit in the archive
        m = re.match(r"Name: (\S+)", line)
        if m:
            modules.append(m.group(1))
            in_imports = False
            continue
        if line.startswith("Interfaces imported:"):
            in_imports = True
            continue
        if line.startswith("Implementations imported:") or line.startswith("Name:"):
            in_imports = False
            continue
        if in_imports and line.strip() and line.startswith("\t"):
            imports += 1
    return modules, imports


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--path", required=True)
    ap.add_argument("--watchlist", default="")
    args = ap.parse_args()

    modules, imports = parse_ocamlobjinfo(sys.stdin)
    watchlist = [w for w in args.watchlist.split(",") if w]
    mset = set(modules)
    present = [w for w in watchlist if w in mset]
    missing = [w for w in watchlist if w not in mset]

    summary = {
        "kind": "ocaml",
        "path": args.path,
        "counts": {"modules": len(modules), "imports": imports},
        "modules": modules,
        "watchlist": {"present": present, "missing": missing},
    }
    json.dump(summary, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
