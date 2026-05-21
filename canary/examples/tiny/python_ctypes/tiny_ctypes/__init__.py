"""User-facing layer for the tiny binding.

Re-packs ``_raw`` into idiomatic Python: plain functions instead of
ctypes attribute calls, and a function for the global offset rather
than exposing the ``ctypes.c_int`` directly. Mirrors OCaml's Tiny.
"""

from . import _raw


def sum(a: int, b: int) -> int:
    return _raw._lib.tiny_sum(a, b)


def diff(a: int, b: int) -> int:
    return _raw._lib.tiny_diff(a, b)


def offset() -> int:
    """Query the C global ``tiny_offset`` on each call."""
    return _raw.tiny_offset.value
