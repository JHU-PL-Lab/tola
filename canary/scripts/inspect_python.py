#!/usr/bin/env python3
"""Summarize a Python package artifact.

Imports the package and emits a compact JSON summary of its top-level
interface:
- counts.attrs: number of public attributes
- attrs: sorted list of public attribute names (no dunders)
- version: __version__ if defined, else null
- extra: module-specific facts (e.g., sqlite3.sqlite_version)
- watchlist.{present,missing}: presence check against a fixed name list
  (the EXPECTED-PRESENT role: missing = drift, alarming)
- expected_missing.{confirmed,violated}: the EXPECTED-MISSING role
  (watchlist roles, status.md section B): names DECLARED absent — e.g.
  sqlite3's binding-lag markers, canonical wrappers for modern C APIs the
  stdlib binding does not wrap. confirmed = still absent (the lag holds,
  an xfail-style pass); violated = the name APPEARED (binding caught up —
  the declaration is stale, alarming).

Public attrs filter: excludes dunder names (`__*__`) by default. Single-
underscore private names (`_foo`) are also excluded. Override via
--include-private.

Usage: summarize_python.py --pkg sqlite3 \\
         --watchlist connect,version_info,sqlite_version_info \\
         --expect-missing get_clientdata,error_offset \\
         [--include-private]
"""
import argparse
import importlib
import json
import sys


def public_attrs(mod, include_private=False):
    names = dir(mod)
    if include_private:
        return sorted(names)
    return sorted(n for n in names if not n.startswith("_"))


def module_version(mod):
    v = getattr(mod, "__version__", None)
    if isinstance(v, str):
        return v
    return None


def extras_for(pkg, mod):
    """Module-specific extra facts worth surfacing in summaries."""
    extra = {}
    if pkg == "sqlite3":
        # Python's sqlite3 is stdlib-bundled; the underlying libsqlite
        # version is a drift axis independent of Python version.
        if hasattr(mod, "sqlite_version"):
            extra["sqlite_version"] = mod.sqlite_version
        if hasattr(mod, "sqlite_version_info"):
            extra["sqlite_version_info"] = list(mod.sqlite_version_info)
    return extra


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pkg", required=True, help="python package / module name to import")
    ap.add_argument("--watchlist", default="", help="comma-separated attribute names to check")
    ap.add_argument("--expect-missing", default="",
                    help="comma-separated attribute names DECLARED absent "
                         "(expected-missing role: confirmed if still absent, "
                         "violated if present)")
    ap.add_argument("--include-private", action="store_true",
                    help="include underscore-prefixed names in attrs")
    args = ap.parse_args()

    try:
        mod = importlib.import_module(args.pkg)
    except Exception as e:
        # Emit a structured failure summary so callers can detect absence
        # via the JSON "error" field. Exit 0 so the inspect step itself
        # succeeds — the inspector did its job (recorded that the import
        # failed); whether {b the target} is healthy is a separate
        # question carried by the JSON content.
        summary = {
            "kind": "python",
            "path": args.pkg,
            "error": f"{type(e).__name__}: {e}",
        }
        json.dump(summary, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
        sys.exit(0)

    attrs = public_attrs(mod, include_private=args.include_private)
    watchlist = [w for w in args.watchlist.split(",") if w]
    aset = set(attrs) | (set(dir(mod)) if args.include_private else set(attrs))
    present = [w for w in watchlist if w in aset]
    missing = [w for w in watchlist if w not in aset]
    expect_missing = [w for w in args.expect_missing.split(",") if w]
    lag_confirmed = [w for w in expect_missing if w not in aset]
    lag_violated = [w for w in expect_missing if w in aset]

    summary = {
        "kind": "python",
        "path": args.pkg,
        "counts": {"attrs": len(attrs)},
        "attrs": attrs,
        "version": module_version(mod),
        "extra": extras_for(args.pkg, mod),
        "watchlist": {"present": present, "missing": missing},
        "expected_missing": {"confirmed": lag_confirmed,
                             "violated": lag_violated},
    }
    json.dump(summary, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
