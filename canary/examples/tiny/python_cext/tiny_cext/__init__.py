"""User-facing layer for the static (C-extension) tiny binding.

Re-packs ``_native`` (the compiled CPython extension module) into
idiomatic Python. Mirrors OCaml's Tiny and Python ctypes' tiny_ctypes.
"""

from . import _native


def sum(a: int, b: int) -> int:
    return _native.sum(a, b)


def diff(a: int, b: int) -> int:
    return _native.diff(a, b)


def offset() -> int:
    """Query the C global ``tiny_offset`` on each call."""
    return _native.get_offset()
