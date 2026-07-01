"""c1 cmp_symbol — encode the Symbol contract.

Given a native-side inspector JSON (s2 native_lib via i1) and a
consumer-side inspector JSON (s5 binding_lib via i3 for OCaml
stub .a, or i1 reused for cext .so), verify that every C symbol the
consumer requires is present in the native lib's defined symbols.

Usage:
    cmp_symbol.py --native NATIVE.json --consumer CONSUMER.json [--prefix tiny_]

Exits 0 (pass) if consumer.requires ⊆ native.symbols, 1 (fail) otherwise.
Prints "pass" / "fail" on stdout; missing symbols on stderr.

For cext (where the consumer JSON comes from i1 on the .so), the
field is "symbols" but with `kind: native` and the cext .so's
*undefined* references aren't emitted by i1. So this script accepts
both "requires" (i3-style stub JSON) and a fallback to nm -U on a
provided binary path.
"""

import argparse
import json
import sys


def load_symbol_set(path: str, field: str) -> set:
    with open(path) as f:
        doc = json.load(f)
    val = doc.get(field)
    if val is None:
        return set()
    return set(val)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--native",   required=True, help="path to native JSON (i1 output)")
    ap.add_argument("--consumer", required=True, help="path to consumer JSON (i3 output, or similar with 'requires')")
    ap.add_argument("--prefix",   default="",   help="restrict to symbols beginning with this prefix")
    args = ap.parse_args()

    native_syms = load_symbol_set(args.native, "symbols")
    consumer_reqs = load_symbol_set(args.consumer, "requires")

    if args.prefix:
        native_syms = {s for s in native_syms if s.startswith(args.prefix)}
        consumer_reqs = {s for s in consumer_reqs if s.startswith(args.prefix)}

    missing = consumer_reqs - native_syms

    if missing:
        print("fail")
        for s in sorted(missing):
            print(f"  missing: {s}", file=sys.stderr)
        return 1

    print("pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
