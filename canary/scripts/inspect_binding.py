#!/usr/bin/env python3
"""Summarize binding interface files.

Two modes (--kind):

  mli   Parse OCaml .mli interface file(s). Extracts vals, type constructors,
        and module names with full dotted qualification (e.g. Opcode.UncondBr).
        Grep-based, no compiler needed. One file per invocation; run once per
        .mli and aggregate, or pass --dir to walk a directory.

  stub  Parse C stub archive (.a). Runs nm and collects undefined symbols —
        these are the C symbols the binding requires from the native lib.
        Optionally filtered by --prefix (e.g. Z3_, LLVM).

Output (both modes):
  kind, path, counts, watchlist.{present, missing}

mli-specific:  vals, constructors, modules
stub-specific: requires

Usage:
  summarize_binding.py --kind mli  --path src/api/ml/z3.mli \\
      --watchlist Z3.Solver.add,Z3.Expr.mk_app
  summarize_binding.py --kind mli  --dir src/api/ml \\
      --watchlist Z3.Solver.add
  summarize_binding.py --kind stub --path build/src/api/ml/libz3ml.a \\
      --prefix Z3_ --watchlist Z3_mk_solver,Z3_mk_context
"""

import argparse
import json
import os
import re
import subprocess
import sys


# ── .mli parser ──────────────────────────────────────────────────────────────

def parse_mli_lines(lines):
    """Extract vals, constructors, and modules with dotted module qualification.

    Tracks module nesting via a stack. Each entry is a module name; the stack
    forms the current dotted prefix. Handles nested modules and anonymous sig
    blocks (functor arguments, etc.) via a separate anon_depth counter so that
    a lone `end` for an anonymous sig doesn't pop a named module.

    Supports two-line module declarations (z3 style):
      module Log :    ← line 1: sets pending_module
      sig             ← line 2: pushes pending_module onto module_path

    Also handles `module rec Foo :` and `and Foo :` (mutually recursive modules).

    Limitations (acceptable for a quick-pass summary):
    - Inline anonymous sigs on one line (e.g. functor params) may confuse
      anon_depth if they don't have a matching end on their own line.
    - `end` on the same line as the next declaration is not handled.
    - module aliases (`module Foo = Bar`) produce no vals/constructors.
    """
    vals = []
    externals = []     # `external name : ty = "C_symbol"` decls — stub-facing
                       # (s3 surface). Distinct from vals (s4 surface) because
                       # externals bind directly to C symbols; the corresponding
                       # user-facing vals live in a different .mli on the same
                       # binding's repack layer.
    constructors = []
    modules = []
    module_path = []   # current module nesting, e.g. ["Opcode"]
    anon_depth = 0     # anonymous sig/struct depth inside the current module
    pending_module = None  # name awaiting its sig/struct on the next line

    for raw in lines:
        line = raw.strip()
        if not line or line.startswith("(*"):
            continue

        # Named module with sig on same line:
        # "module Foo : sig", "module rec Foo : sig", "module type Foo = sig",
        # "module Foo : functor ... -> sig"
        m = re.match(r'(?:module\s+(?:type\s+|rec\s+)?)([A-Z]\w*)[^=]*\b(sig|struct)\b', line)
        if m:
            name = m.group(1)
            module_path.append(name)
            modules.append('.'.join(module_path))
            # Extra anonymous sigs on same line (e.g. functor arg: "module Foo : functor (S : sig")
            extra = len(re.findall(r'\b(?:sig|struct)\b', line)) - 1
            anon_depth += max(extra, 0)
            pending_module = None
            continue

        # Named module without sig on same line — two-line form:
        # "module Foo :", "module rec Foo :", "module type Foo =",
        # "and Foo :" (mutually recursive sibling)
        m = re.match(r'(?:module\s+(?:type\s+|rec\s+)?|and\s+)([A-Z]\w*)\b', line)
        if m and not re.search(r'\b(?:sig|struct)\b', line):
            pending_module = m.group(1)
            continue

        # Standalone sig/struct (not part of a module/and declaration on this line)
        if re.search(r'\b(?:sig|struct)\b', line) and not re.match(r'(?:module|and)\s', line):
            if pending_module is not None:
                module_path.append(pending_module)
                modules.append('.'.join(module_path))
                pending_module = None
                extra = len(re.findall(r'\b(?:sig|struct)\b', line)) - 1
                anon_depth += max(extra, 0)
            else:
                anon_depth += len(re.findall(r'\b(?:sig|struct)\b', line))
                anon_depth -= line.count('end')
            continue

        # `end` on its own line
        if re.match(r'end\b', line):
            pending_module = None
            if anon_depth > 0:
                anon_depth -= 1
            elif module_path:
                module_path.pop()
            continue

        # external declaration (any indentation) — s3 stub-facing surface.
        # Matched BEFORE val so `external` doesn't accidentally fall through
        # to a `val` match on a hypothetical future grammar overlap.
        m = re.match(r'external\s+(\w+)', line)
        if m:
            prefix = '.'.join(module_path) + '.' if module_path else ''
            externals.append(prefix + m.group(1))
            continue

        # val declaration (any indentation) — s4 user-facing surface.
        m = re.match(r'val\s+(\w+)', line)
        if m:
            prefix = '.'.join(module_path) + '.' if module_path else ''
            vals.append(prefix + m.group(1))
            continue

        # type constructor: "| Name" or "| Name of ..."
        m = re.match(r'\|\s*([A-Z]\w*)', line)
        if m:
            prefix = '.'.join(module_path) + '.' if module_path else ''
            constructors.append(prefix + m.group(1))

    return vals, externals, constructors, modules


def summarize_mli(paths, watchlist, prefix_by_filename=False):
    """Parse each .mli file and aggregate.

    When `prefix_by_filename` is True (set for --dir mode by default), each
    file's contents are prefixed by its filename-derived module name (OCaml
    package convention: `llvm.mli` is the body of module `Llvm`). The module
    itself is also added to the modules list.
    """
    all_vals, all_externals, all_constructors, all_modules = [], [], [], []
    for p in paths:
        with open(p) as f:
            v, e, c, m = parse_mli_lines(f.readlines())
        if prefix_by_filename:
            stem = os.path.splitext(os.path.basename(p))[0]
            mod = stem[:1].upper() + stem[1:]
            v = [f"{mod}.{x}" for x in v]
            e = [f"{mod}.{x}" for x in e]
            c = [f"{mod}.{x}" for x in c]
            m = [f"{mod}.{x}" for x in m]
            all_modules.append(mod)
        all_vals.extend(v)
        all_externals.extend(e)
        all_constructors.extend(c)
        all_modules.extend(m)

    # Deduplicate preserving order
    def dedup(xs):
        seen = set()
        return [x for x in xs if not (x in seen or seen.add(x))]

    vals = dedup(all_vals)
    externals = dedup(all_externals)
    constructors = dedup(all_constructors)
    modules = dedup(all_modules)
    # Watchlist resolves against the union of all four sets so a single
    # inspect can be used on either an s3 (externals-bearing) or s4
    # (vals-bearing) .mli without the caller needing to know which.
    all_names = set(vals) | set(externals) | set(constructors) | set(modules)
    present = [w for w in watchlist if w in all_names]
    missing = [w for w in watchlist if w not in all_names]

    source = paths[0] if len(paths) == 1 else os.path.commonpath(paths)
    return {
        "kind": "ocaml_mli",
        "path": source,
        "counts": {
            "vals": len(vals),
            "externals": len(externals),
            "constructors": len(constructors),
            "modules": len(modules),
        },
        "vals": vals,
        "externals": externals,
        "constructors": constructors,
        "modules": modules,
        "watchlist": {"present": present, "missing": missing},
    }


# ── .a stub archive parser ────────────────────────────────────────────────────

def parse_stub_a(path, prefix):
    """Run nm on a static archive; collect undefined symbols (what binding requires)."""
    cmd = ["nm", path]
    proc = subprocess.run(cmd, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=False)
    if proc.returncode != 0:
        raise RuntimeError(f"nm {path} failed: {proc.stderr.strip()}")

    required = set()
    for line in proc.stdout.splitlines():
        parts = line.strip().split()
        if len(parts) < 2:
            continue
        kind = parts[-2] if len(parts) >= 2 else ""
        sym = parts[-1].split("@")[0]  # strip ELF @@VER suffix
        if kind == "U" and (not prefix or sym.startswith(prefix)):
            required.add(sym)
    return sorted(required)


def summarize_stub(path, prefix, watchlist):
    requires = parse_stub_a(path, prefix)
    names_set = set(requires)
    present = [w for w in watchlist if w in names_set]
    missing = [w for w in watchlist if w not in names_set]
    return {
        "kind": "c_stub",
        "path": path,
        "counts": {"required": len(requires)},
        "requires": requires,
        "watchlist": {"present": present, "missing": missing},
    }


# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--kind", choices=["mli", "stub"], required=True)
    ap.add_argument("--path", help="single file path")
    ap.add_argument("--dir", help="mli mode: directory; walk for all .mli files")
    ap.add_argument("--watchlist", default="",
                    help="comma-separated names to presence-check")
    ap.add_argument("--prefix", default="",
                    help="stub mode: filter undefined symbols by this prefix")
    args = ap.parse_args()

    watchlist = [w for w in args.watchlist.split(",") if w]

    if args.kind == "mli":
        if args.dir:
            paths = sorted(
                os.path.join(args.dir, f)
                for f in os.listdir(args.dir)
                if f.endswith(".mli")
            )
            if not paths:
                print(f"No .mli files found in {args.dir}", file=sys.stderr)
                sys.exit(1)
            # In --dir mode, treat each `foo.mli` as the body of module `Foo`
            # (OCaml package convention) so vals/constructors get a top-level
            # module prefix matching how clients reference them.
            summary = summarize_mli(paths, watchlist, prefix_by_filename=True)
        elif args.path:
            paths = [args.path]
            summary = summarize_mli(paths, watchlist)
        else:
            ap.error("--kind mli requires --path or --dir")

    else:  # stub
        if not args.path:
            ap.error("--kind stub requires --path")
        summary = summarize_stub(args.path, args.prefix, watchlist)

    json.dump(summary, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
