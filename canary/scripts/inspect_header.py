#!/usr/bin/env python3
"""n3 native_header inspector — minimal regex-based C header parser.

Reads a C header (.h) and emits a JSON summary of function declarations
and `extern` variable declarations. Output shape:

    {
      "kind": "c_header",
      "path": "...",
      "counts": {"functions": N, "extern_vars": N},
      "functions": [
        {"name": "tiny_sum", "return_type": "int", "arg_types": ["int", "int"]},
        ...
      ],
      "extern_vars": [
        {"name": "tiny_offset", "type": "int"},
        ...
      ],
      "watchlist": {"present": [...], "missing": [...]}
    }

Scope: this is a {i regex-based} parser deliberately scoped to the
shape of tiny.h (and similarly flat C headers). It handles:

  * `<type> <name>(<arg-list>);` function declarations on one line
  * `extern <type> <name>;` variable declarations on one line
  * /* ... */ and // comments (stripped before parsing)
  * preprocessor lines (#ifdef/#define/#endif/#include — skipped)

It does NOT handle:

  * function pointers (`int (*foo)(int)`) — out-of-scope for tiny.h
  * typedef'd return / arg types (resolved only by their textual
    name; no transitive resolution to underlying primitives)
  * multi-line declarations
  * macros that expand into declarations
  * struct / union / enum types
  * trailing attributes (`__attribute__((...))`)

For real-world headers (z3.h, llvm-c/*.h) the regex parser will miss
declarations or extract garbage. The plan there is to migrate to
tree-sitter-c or libclang; see plan.md §6 Step 4 (a). For tiny
(the canary unit-test target) the regex parser is sufficient and
faster to ship.

Usage:
    inspect_header.py --path c/include/tiny.h [--watchlist sum,diff]
"""

import argparse
import json
import os
import re
import sys


# Strip /* ... */ and // comments. C99 allows // anywhere.
_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
_LINE_COMMENT = re.compile(r"//[^\n]*")


def strip_comments(text: str) -> str:
    text = _BLOCK_COMMENT.sub("", text)
    text = _LINE_COMMENT.sub("", text)
    return text


# Skip preprocessor directives.
_PREPROC = re.compile(r"^\s*#")


# Function declaration: <return> <name>(<args>);
# return = one or more identifier/qualifier tokens, possibly with `*`s
# args = anything (handled later via split-on-comma)
_FUNC_DECL = re.compile(
    r"""
    ^\s*
    (?P<ret>(?:const\s+|unsigned\s+|signed\s+|struct\s+|long\s+|short\s+)*
            [A-Za-z_][\w\s\*]*?)         # return type (greedy enough for `unsigned long *`)
    \s+
    (?P<name>[A-Za-z_]\w*)               # function name
    \s*
    \(
    (?P<args>[^()]*)                     # arg list (no nested parens)
    \)
    \s*;\s*$
    """,
    re.VERBOSE | re.MULTILINE,
)

# Extern variable: extern <type> <name>;
_EXTERN_VAR = re.compile(
    r"""
    ^\s*
    extern\s+
    (?P<type>(?:const\s+|unsigned\s+|signed\s+|struct\s+|long\s+|short\s+)*
             [A-Za-z_][\w\s\*]*?)         # type (greedy)
    \s+
    (?P<name>[A-Za-z_]\w*)               # var name
    \s*
    (?:\[\s*[^\]]*\s*\])?                # optional array size
    \s*;\s*$
    """,
    re.VERBOSE | re.MULTILINE,
)


def parse_arg_list(args: str) -> list[str]:
    """Split a C function arg list into the argument {i types} only.

    For `int a, const char *p`, returns `["int", "const char *"]`.
    For `void`, returns `[]` (canonical "no args").
    For `` (empty), returns `[]` — C treats `f()` as unspecified args
    but for parsed signatures we conservatively treat this as 0 args.
    """
    args = args.strip()
    if not args or args == "void":
        return []
    out = []
    for part in args.split(","):
        part = part.strip()
        # Strip the parameter name (last identifier). If only one token,
        # it's a bare type with no name.
        tokens = part.split()
        if len(tokens) == 1:
            out.append(tokens[0])
        else:
            # Drop the trailing identifier if it looks like a name and
            # isn't a type keyword.
            last = tokens[-1].lstrip("*")
            if last.isidentifier() and last not in (
                "int", "char", "long", "short", "void", "float", "double",
                "signed", "unsigned", "const",
            ):
                out.append(" ".join(tokens[:-1]).rstrip("*").rstrip())
                # Re-attach pointer stars if the name had them prefixed.
                pointer_count = tokens[-1].count("*")
                if pointer_count:
                    out[-1] = out[-1] + " " + "*" * pointer_count
                out[-1] = " ".join(out[-1].split())  # normalize whitespace
            else:
                out.append(part)
    return out


def normalize_type(t: str) -> str:
    """Collapse whitespace, normalize pointer placement."""
    t = " ".join(t.split())
    # Move `*` to the type side: `int *` → `int*`
    # (Keep this off for readability; the c6 comparator handles both.)
    return t


def parse_header(text: str) -> tuple[list[dict], list[dict]]:
    text = strip_comments(text)
    # Strip preprocessor lines line-by-line (regex MULTILINE is enough).
    text = "\n".join(
        line for line in text.splitlines() if not _PREPROC.match(line)
    )

    functions = []
    seen_func = set()
    for m in _FUNC_DECL.finditer(text):
        name = m.group("name")
        # Avoid duplicates if the same header is double-included via #include guards.
        if name in seen_func:
            continue
        ret = normalize_type(m.group("ret"))
        args = [normalize_type(a) for a in parse_arg_list(m.group("args"))]
        functions.append({"name": name, "return_type": ret, "arg_types": args})
        seen_func.add(name)

    extern_vars = []
    seen_var = set()
    for m in _EXTERN_VAR.finditer(text):
        name = m.group("name")
        if name in seen_var:
            continue
        ty = normalize_type(m.group("type"))
        extern_vars.append({"name": name, "type": ty})
        seen_var.add(name)

    return functions, extern_vars


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--path", required=True, help="path to .h header file")
    ap.add_argument("--watchlist", default="",
                    help="comma-separated names to verify presence of")
    args = ap.parse_args(argv)

    with open(args.path) as f:
        text = f.read()
    functions, extern_vars = parse_header(text)

    all_names = (
        {f["name"] for f in functions} | {v["name"] for v in extern_vars}
    )
    watchlist = [w.strip() for w in args.watchlist.split(",") if w.strip()]
    present = [w for w in watchlist if w in all_names]
    missing = [w for w in watchlist if w not in all_names]

    out = {
        "kind": "c_header",
        "path": os.path.relpath(args.path) if os.path.isabs(args.path) else args.path,
        "counts": {
            "functions": len(functions),
            "extern_vars": len(extern_vars),
        },
        "functions": functions,
        "extern_vars": extern_vars,
        "watchlist": {"present": present, "missing": missing},
    }
    json.dump(out, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
