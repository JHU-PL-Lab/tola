"""Baseline probe for the ctypes-based binding (dynamic FFI).

Exercises every wrapper in ``tiny_ctypes`` and checks the results
against the values an unbroken native side should produce. Exits
non-zero on the first mismatch.
"""

import sys
import tiny_ctypes as tiny


def check(name: str, expected: int, actual: int) -> None:
    if expected != actual:
        print(f"FAIL {name}: expected {expected}, got {actual}", file=sys.stderr)
        sys.exit(1)
    print(f"OK   {name} = {actual}")


def main() -> None:
    check("tiny.offset()", 42, tiny.offset())
    check("tiny.sum(2, 3)", 47, tiny.sum(2, 3))      # 2 + 3 + 42
    check("tiny.diff(5, 2)", 3, tiny.diff(5, 2))
    check("tiny.diff(2, 5)", -3, tiny.diff(2, 5))    # asymmetry matters for api_repack
    print("all checks passed")


if __name__ == "__main__":
    main()
