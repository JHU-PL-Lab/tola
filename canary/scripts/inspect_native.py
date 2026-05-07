#!/usr/bin/env python3
"""Summarize a native library artifact (.so/.dylib/.a).

Reads `nm` output from stdin; emits compact JSON summary:
- counts.total: defined non-weak symbols
- counts.by_prefix: per-prefix counts
- versioned_req: map of {GLIBC_2.17: 3} from undefined @VER requirements (L1b)
- watchlist.{present,missing}: presence check against a fixed name list
- elf (when --elf): SONAME, NEEDED, RPATH, RUNPATH from readelf -d (L4)

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
import os
import re
import subprocess
import sys


def parse_elf(path):
    """Run readelf -d and extract SONAME, NEEDED, RPATH, RUNPATH (L4)."""
    if not os.path.exists(path):
        return None
    try:
        out = subprocess.check_output(
            ["readelf", "-d", path],
            stderr=subprocess.STDOUT,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return None

    soname = None
    needed = []
    rpath = []
    runpath = []

    soname_re = re.compile(r"\(SONAME\)\s+Library soname:\s+\[(.+)\]")
    needed_re = re.compile(r"\(NEEDED\)\s+Shared library:\s+\[(.+)\]")
    rpath_re = re.compile(r"\(RPATH\)\s+Library rpath:\s+\[(.+)\]")
    runpath_re = re.compile(r"\(RUNPATH\)\s+Library runpath:\s+\[(.+)\]")

    for line in out.splitlines():
        m = soname_re.search(line)
        if m: soname = m.group(1); continue
        m = needed_re.search(line)
        if m: needed.append(m.group(1)); continue
        m = rpath_re.search(line)
        if m: rpath.append(m.group(1)); continue
        m = runpath_re.search(line)
        if m: runpath.append(m.group(1))

    return {"soname": soname, "needed": needed, "rpath": rpath, "runpath": runpath}


def parse_nm(lines, strip_leading_underscore=False):
    defined = []
    versioned_req = {}
    versioned_exports = {}  # L1b provider side: {symbol_name: version_tag}
    for line in lines:
        parts = line.rstrip("\n").split()
        if len(parts) < 2:
            continue
        # Last token is always the symbol; second-to-last is kind.
        sym = parts[-1]
        kind = parts[-2] if len(parts) >= 2 else ""
        if kind == "U":
            # Undefined — if it carries @VER that's a versioned requirement
            # (L1b consumer side: what the binary needs)
            if "@" in sym and "@@" not in sym:
                _, ver = sym.split("@", 1)
                versioned_req[ver] = versioned_req.get(ver, 0) + 1
        elif kind == "w" or kind == "W":
            # Weak — skip for counts (they're optional)
            pass
        else:
            # Defined.  Keep @@VER annotations for provider-side L1b.
            if "@@" in sym:
                base, ver = sym.split("@@", 1)
                versioned_exports[base] = ver
            else:
                base = sym.split("@")[0]
            # macOS Mach-O nm prefixes every C symbol with `_` (e.g. C
            # `malloc` → `_malloc`). Strip on macOS only. On Linux ELF
            # the symbol name IS the C ABI name (`malloc`, `__gmpz_init`)
            # — stripping would mangle GMP-style `__gmp*` symbols.
            if strip_leading_underscore and base.startswith("_"):
                base = base[1:]
            defined.append(base)
    return defined, versioned_req, versioned_exports


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--path", required=True, help="artifact path (for the record)")
    ap.add_argument("--prefixes", default="", help="comma-separated prefix list")
    ap.add_argument("--watchlist", default="", help="comma-separated watchlist names")
    ap.add_argument("--strip-leading-underscore", action="store_true",
                    help="strip one leading _ from each defined symbol "
                         "(macOS Mach-O convention; do NOT use on Linux ELF)")
    ap.add_argument("--emit-symbols", action="store_true",
                    help="include the list of defined symbols (filtered by "
                         "--prefixes) in the output. Required for compat "
                         "cross-checks against a binding's stub.requires.")
    ap.add_argument("--elf", action="store_true",
                    help="also run readelf -d and include ELF ABI metadata "
                         "(soname, needed, rpath, runpath) in the output (L4)")
    args = ap.parse_args()

    defined, versioned_req, versioned_exports = parse_nm(
        sys.stdin, strip_leading_underscore=args.strip_leading_underscore)
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
        "versioned_exports": versioned_exports,  # L1b provider side
        "watchlist": {"present": present, "missing": missing},
    }
    if args.emit_symbols:
        # Filter by any prefix; if no prefix given, emit all.
        if prefixes:
            kept = sorted(s for s in dset
                          if any(s.startswith(p) for p in prefixes))
        else:
            kept = sorted(dset)
        summary["symbols"] = kept
    if args.elf:
        elf = parse_elf(args.path)
        if elf:
            summary["elf"] = elf
    json.dump(summary, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
