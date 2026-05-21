"""Compare an observed scenario run against the expected outcomes.

Outcomes tracked (each "ok" / "fail" / "skip" / "pass" depending on kind):
- ocaml_build              dune build success
- ocaml_probe              OCaml probe_baseline exit
- ocaml_app_binding        e12 app over Tiny binding exit
- ocaml_app_helper         e13 app over tiny_helper over Tiny exit
- python_cext_probe        cext probe exit
- python_ctypes_probe      ctypes probe exit
- cmp_symbol_ocaml         c1 against OCaml stub .a vs native lib
- cmp_symbol_cext          c1 against cext .so vs native lib
- cmp_api_complete_ocaml   c2 against tiny.mli vs watchlist
- cmp_api_complete_cext    c2 against dir(tiny_cext) vs watchlist
- cmp_api_complete_ctypes  c2 against dir(tiny_ctypes) vs watchlist

Defaults if not present in expected.json:
  build / probe outcomes default to "ok"
  comparator outcomes default to "pass"

Exits 0 if all observed outcomes match expected (mismatch on a missing
key is impossible because of the defaults above). Exits 1 on any
mismatch and prints the comparison table.
"""

import argparse
import json
import sys

DEFAULTS = {
    "ocaml_build":             "ok",
    "ocaml_probe":             "ok",
    "ocaml_app_binding":       "ok",
    "ocaml_app_helper":        "ok",
    "python_cext_probe":       "ok",
    "python_ctypes_probe":     "ok",
    "cmp_symbol_ocaml":        "pass",
    "cmp_symbol_cext":         "pass",
    "cmp_api_complete_ocaml":  "pass",
    "cmp_api_complete_cext":   "pass",
    "cmp_api_complete_ctypes": "pass",
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("expected", help="path to expected.json")
    ap.add_argument("--ocaml-build",              required=True)
    ap.add_argument("--ocaml-probe",              required=True)
    ap.add_argument("--ocaml-app-binding",        required=True)
    ap.add_argument("--ocaml-app-helper",         required=True)
    ap.add_argument("--python-cext-probe",        required=True)
    ap.add_argument("--python-ctypes-probe",      required=True)
    ap.add_argument("--cmp-symbol-ocaml",         required=True)
    ap.add_argument("--cmp-symbol-cext",          required=True)
    ap.add_argument("--cmp-api-complete-ocaml",   required=True)
    ap.add_argument("--cmp-api-complete-cext",    required=True)
    ap.add_argument("--cmp-api-complete-ctypes",  required=True)
    args = ap.parse_args()

    with open(args.expected) as f:
        expected_doc = json.load(f)

    expected = expected_doc.get("outcomes", {})
    observed = {
        "ocaml_build":             args.ocaml_build,
        "ocaml_probe":             args.ocaml_probe,
        "ocaml_app_binding":       args.ocaml_app_binding,
        "ocaml_app_helper":        args.ocaml_app_helper,
        "python_cext_probe":       args.python_cext_probe,
        "python_ctypes_probe":     args.python_ctypes_probe,
        "cmp_symbol_ocaml":        args.cmp_symbol_ocaml,
        "cmp_symbol_cext":         args.cmp_symbol_cext,
        "cmp_api_complete_ocaml":  args.cmp_api_complete_ocaml,
        "cmp_api_complete_cext":   args.cmp_api_complete_cext,
        "cmp_api_complete_ctypes": args.cmp_api_complete_ctypes,
    }

    keys = list(DEFAULTS.keys())
    rows = []
    mismatches = 0
    for key in keys:
        exp = expected.get(key, DEFAULTS[key])
        obs = observed[key]
        if exp == obs:
            rows.append((key, exp, obs, "match"))
        else:
            rows.append((key, exp, obs, "MISMATCH"))
            mismatches += 1

    name = expected_doc.get("scenario", args.expected)
    print(f"--- result: {name}")
    width = max(len(k) for k in keys)
    for key, exp, obs, status in rows:
        print(f"    {key:<{width}}  expected={exp:<6}  observed={obs:<6}  {status}")

    if mismatches:
        print(f"FAIL: {mismatches} mismatched outcome(s)")
        return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
