#!/usr/bin/env python3
"""Trivial-grep typed-signature inspector for tiny.

Emits typed function signatures for tiny's known surfaces. The
signature data is hardcoded (tiny-specific); the inspector greps the
artifact for presence of each known name. A real clang-AST / mli-parse
inspector would extract the same shape from the artifact directly;
this stands in until that work lands.

Layers:
  header      — C sigs declared in tiny.h            (provider, n3)
  stub_ocaml  — C-level sigs expected by Tiny_raw    (consumer, bo1)
  user_ocaml  — OCaml types in Tiny.mli              (consumer, bo4)
  stub_python — C-level sigs expected by _native.c   (consumer, bpe1)
  user_python — Python types in __init__.py          (consumer, bpe2)

Output JSON:
  { "kind": "typed_<layer>",
    "path": "<file>",
    "functions": { name: { "return": str, "args": [str, ...] }, ... } }

Only includes entries whose names appear in the artifact (grep
substring match). When the artifact is missing or unreadable, emits
an "error" field and an empty "functions" dict but still exits 0 —
inspector success means "inspector ran"; target presence is the JSON's
to report.

Drop-in replacement plan: when clang-AST / mli-parse / Python-AST
inspectors land, swap this script for a layer-specific one; the OCaml
side (Canary_compat.load_typed_signatures, the inspect_input ADT
cases, the c6/c7/c8 predicates) and tiny's spec do not change.
"""
import argparse
import json
import re
import sys

# Tiny's known typed surface — what a real AST inspector would extract.
# Keyed by layer; each layer carries the names + signatures expected
# for that side of the surface stack. Adding a layer = adding an entry.
LAYERS = {
    "header": {
        # n3 — declared in tiny.h.
        "tiny_sum":    {"return": "int", "args": ["int", "int"]},
        "tiny_diff":   {"return": "int", "args": ["int", "int"]},
        "tiny_offset": {"return": "int", "args": []},
    },
    "stub_ocaml": {
        # bo1 — what tiny_raw.mli's externals expect at the C ABI.
        # Same C types as the header — Tiny_raw is a 1:1 mirror.
        "tiny_sum":    {"return": "int", "args": ["int", "int"]},
        "tiny_diff":   {"return": "int", "args": ["int", "int"]},
        "tiny_offset": {"return": "int", "args": []},
    },
    "user_ocaml": {
        # bo4 — Tiny.mli's user-facing surface, OCaml types.
        "sum":    {"return": "int", "args": ["int", "int"]},
        "diff":   {"return": "int", "args": ["int", "int"]},
        "offset": {"return": "int", "args": []},
    },
    "stub_python": {
        # bpe1 — _native.c's PyArg_ParseTuple expectations, C types.
        "tiny_sum":    {"return": "int", "args": ["int", "int"]},
        "tiny_diff":   {"return": "int", "args": ["int", "int"]},
        "tiny_offset": {"return": "int", "args": []},
    },
    "user_python": {
        # bpe2 — __init__.py's user-facing surface, Python types.
        "sum":    {"return": "int", "args": ["int", "int"]},
        "diff":   {"return": "int", "args": ["int", "int"]},
        "offset": {"return": "int", "args": []},
    },
}


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--layer", choices=list(LAYERS), required=True,
                    help="which typed surface to inspect")
    ap.add_argument("--path", required=True,
                    help="artifact file to grep for known names")
    args = ap.parse_args()

    known = LAYERS[args.layer]
    try:
        with open(args.path) as f:
            text = f.read()
    except OSError as e:
        print(json.dumps({
            "kind": f"typed_{args.layer}",
            "path": args.path,
            "error": f"{type(e).__name__}: {e}",
            "functions": {},
        }, indent=2, sort_keys=True))
        sys.exit(0)

    if args.layer == "header":
        # For the C header layer, *actually parse* the declaration —
        # critical so perturbations like header_arity_bump (tiny.h
        # changing tiny_sum's arity) show up as a real signature
        # change in the JSON. Other layers still use the trivial
        # hardcoded-sig fallback; they'll graduate to parsing when
        # their c6/c7 scenarios land. Regex is rough but adequate
        # for tiny's hand-written header.
        present = parse_c_header(text, known)
    else:
        # Trivial grep fallback: name present in file ⇒ emit known
        # hardcoded signature. Substring match; doesn't catch
        # signature-level perturbations on these layers (would need
        # layer-specific parsing). Adequate where the demo
        # perturbations affect presence/absence rather than types.
        present = {name: sig for name, sig in known.items() if name in text}

    print(json.dumps({
        "kind": f"typed_{args.layer}",
        "path": args.path,
        "functions": present,
    }, indent=2, sort_keys=True))


# Regex for a C function declaration: <return> <name>(<args>);
# Captures: 1=return type token, 2=function name, 3=raw args string.
# Single-line only — tiny.h fits in one line per decl.
_C_DECL_RE = re.compile(
    r'^\s*(?:extern\s+)?(\w[\w\s\*]*?)\s+(\w+)\s*\(([^)]*)\)\s*;', re.MULTILINE)


def parse_c_header(text, known):
    """Parse C declarations matching names in [known], emit
    {name: {return, args}} reflecting the actual header content.
    Args list is parsed as comma-split type tokens; for each arg,
    we keep only the type part (everything before an identifier
    name, if present). `void` arg list becomes []."""
    result = {}
    for m in _C_DECL_RE.finditer(text):
        return_type = m.group(1).strip()
        name = m.group(2)
        args_str = m.group(3).strip()
        if name not in known:
            continue
        if args_str == "" or args_str == "void":
            args = []
        else:
            args = []
            for part in args_str.split(","):
                part = part.strip()
                # Strip the parameter name (last token) if present.
                # "int a"  → "int"; "const char *p" → "const char *".
                toks = part.rsplit(maxsplit=1)
                if len(toks) == 2 and re.match(r"^\w+$", toks[1]):
                    args.append(toks[0].strip())
                else:
                    args.append(part)
        result[name] = {"return": return_type, "args": args}
    return result


if __name__ == "__main__":
    main()
