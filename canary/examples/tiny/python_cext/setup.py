"""setup.py for tiny_cext — the canonical CPython C-extension build.

Driven via PEP 517 from pyproject.toml's
    [build-system]
    requires      = ["setuptools>=77"]
    build-backend = "setuptools.build_meta"

The Makefile invokes `uv build --wheel` which runs this script in a
clean build env; the resulting _native.cpython-*.so is then copied
back inplace by `make python_cext` so `PYTHONPATH=python_cext` works.

Direct invocation also works if setuptools is in the local env:
    python3 setup.py build_ext --inplace
"""
import os

from setuptools import setup, Extension

HERE = os.path.dirname(os.path.abspath(__file__))
C_INCLUDE = os.path.normpath(os.path.join(HERE, "..", "c", "include"))
C_BUILD = os.path.normpath(os.path.join(HERE, "..", "c", "build"))

ext = Extension(
    "tiny_cext._native",
    sources=["tiny_cext/_native.c"],
    include_dirs=[C_INCLUDE],
    libraries=["tiny"],
    library_dirs=[C_BUILD],
    runtime_library_dirs=[C_BUILD],
)

setup(
    name="tiny_cext",
    version="0.1.0",
    packages=["tiny_cext"],
    ext_modules=[ext],
)
