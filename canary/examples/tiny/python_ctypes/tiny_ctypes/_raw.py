"""Stub-facing layer for the tiny binding.

Pure ctypes type descriptions, 1-to-1 with tiny.h. Belief about the C
side is concentrated here. Mirrors OCaml's Tiny_raw.

The library is opened via ``find_library`` with a fallback to the
canonical SONAME (``libtiny.so.1``) so the binding works whether the
library has been installed system-wide or just placed on
``LD_LIBRARY_PATH``.
"""

import ctypes
import ctypes.util

_lib_path = ctypes.util.find_library("tiny") or "libtiny.so.1"
_lib = ctypes.CDLL(_lib_path)

# tiny_sum(int, int) -> int
_lib.tiny_sum.argtypes = [ctypes.c_int, ctypes.c_int]
_lib.tiny_sum.restype = ctypes.c_int

# tiny_diff(int, int) -> int
_lib.tiny_diff.argtypes = [ctypes.c_int, ctypes.c_int]
_lib.tiny_diff.restype = ctypes.c_int

# tiny_offset: extern int
tiny_offset = ctypes.c_int.in_dll(_lib, "tiny_offset")
