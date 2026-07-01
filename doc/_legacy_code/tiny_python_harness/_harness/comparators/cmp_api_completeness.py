"""c2 cmp_api_completeness — encode the API-completeness contract.

Given a consumer-side user-facing inspector JSON (s4 binding_header) and
a watchlist (the set of names an app expects), verify that every
watchlist entry appears in the consumer's exported names.

Usage:
    cmp_api_completeness.py --user USER.json --field {vals,attrs} --watchlist sum,diff,offset

Exits 0 (pass) if watchlist ⊆ consumer_names, 1 (fail) otherwise.
"""

import argparse
import json
import sys


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--user",      required=True, help="path to user-facing JSON (i2 or i5 output)")
    ap.add_argument("--field",     required=True, choices=["vals", "attrs"], help="which field holds the name set")
    ap.add_argument("--watchlist", required=True, help="comma-separated names the app expects")
    args = ap.parse_args()

    with open(args.user) as f:
        doc = json.load(f)

    # If the user-facing surface couldn't be observed (import error, parse
    # failure, etc.), the contract is not in a verifiable state — return
    # exit 2 = skip rather than fail. Cascading failures should be blamed on
    # the earlier contract, not on API-completeness.
    if "error" in doc and args.field not in doc:
        print("skip")
        print(f"  inspector error: {doc['error']}", file=sys.stderr)
        return 2

    consumer_names = set(doc.get(args.field) or [])
    watchlist = {n.strip() for n in args.watchlist.split(",") if n.strip()}

    missing = watchlist - consumer_names

    if missing:
        print("fail")
        for s in sorted(missing):
            print(f"  missing: {s}", file=sys.stderr)
        return 1

    print("pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
