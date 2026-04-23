#!/usr/bin/env python3
"""Summarize a native library artifact (.so/.dylib/.a).

Reads `nm` output from stdin; emits compact JSON summary:
- counts.total: defined non-weak symbols
- counts.by_prefix: per-prefix counts
- versioned_req: map of {GLIBC_2.17: 3} from undefined @VER requirements (L1b)
- watchlist.{present,missing}: presence check against a fixed name list

nm output formats handled:
  Linux (nm -D):  "<addr> T symname"        (defined)
                  "         U sym@VER"      (undefined versioned req)
                  "<addr> T sym@@VER"       (defined versioned export)
  macOS (nm -g):  "<addr> T _symname"       (defined; leading _)

Usage: nm -D libfoo.so | summarize_native.py --path libfoo.so \\
         --prefixes Z3_,Z3_mk_ --watchlist Z3_mk_solver,Z3_mk_optimize
"""
import argparse
import json
import sys


def parse_nm(lines):
    defined = []
    versioned_req = {}
    for line in lines:
        parts = line.rstrip("\n").split()
        if len(parts) < 2:
            continue
        # Last token is always the symbol; second-to-last is kind.
        sym = parts[-1]
        kind = parts[-2] if len(parts) >= 2 else ""
        if kind == "U":
            # Undefined — if it carries @VER that's a versioned requirement (L1b)
            if "@" in sym and "@@" not in sym:
                _, ver = sym.split("@", 1)
                versioned_req[ver] = versioned_req.get(ver, 0) + 1
        elif kind == "w" or kind == "W":
            # Weak — skip for counts (they're optional)
            pass
        else:
            # Defined. Strip any @@VER suffix and leading _ on macOS.
            base = sym.split("@")[0]
            if base.startswith("_"):
                base = base[1:]
            defined.append(base)
    return defined, versioned_req


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--path", required=True, help="artifact path (for the record)")
    ap.add_argument("--prefixes", default="", help="comma-separated prefix list")
    ap.add_argument("--watchlist", default="", help="comma-separated watchlist names")
    args = ap.parse_args()

    defined, versioned_req = parse_nm(sys.stdin)
    prefixes = [p for p in args.prefixes.split(",") if p]
    watchlist = [w for w in args.watchlist.split(",") if w]

    by_prefix = {p: sum(1 for s in defined if s.startswith(p)) for p in prefixes}
    dset = set(defined)
    present = [w for w in watchlist if w in dset]
    missing = [w for w in watchlist if w not in dset]

    summary = {
        "kind": "native",
        "path": args.path,
        "counts": {"total": len(defined), "by_prefix": by_prefix},
        "versioned_req": versioned_req,
        "watchlist": {"present": present, "missing": missing},
    }
    json.dump(summary, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
