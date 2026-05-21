/* CPython C extension — the static (stub-based) Python binding for tiny.
 *
 * This is the Python parallel of OCaml's tiny_stubs.c: each wrapper
 * unboxes its Python args, calls the underlying C function from tiny.h,
 * and re-boxes the result. Compiled at binding-build time into
 * tiny_cext/_native.cpython-*.so with NEEDED libtiny.so.1 baked in.
 *
 * Compare to tiny_ctypes/_raw.py, which describes the same C signatures
 * but defers everything to libffi at runtime. Same surface, different
 * mechanism — points 1 and 2 on the §2.3 static/dynamic axis.
 */
#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include "tiny.h"

static PyObject *tiny_sum_wrap(PyObject *self, PyObject *args) {
    int a, b;
    if (!PyArg_ParseTuple(args, "ii", &a, &b)) return NULL;
    return PyLong_FromLong((long)tiny_sum(a, b));
}

static PyObject *tiny_diff_wrap(PyObject *self, PyObject *args) {
    int a, b;
    if (!PyArg_ParseTuple(args, "ii", &a, &b)) return NULL;
    return PyLong_FromLong((long)tiny_diff(a, b));
}

static PyObject *tiny_get_offset_wrap(PyObject *self, PyObject *Py_UNUSED(ignored)) {
    return PyLong_FromLong((long)tiny_offset);
}

static PyMethodDef Methods[] = {
    {"sum",        tiny_sum_wrap,        METH_VARARGS, "tiny_sum(a, b) -> int"},
    {"diff",       tiny_diff_wrap,       METH_VARARGS, "tiny_diff(a, b) -> int"},
    {"get_offset", tiny_get_offset_wrap, METH_NOARGS,  "value of tiny_offset"},
    {NULL, NULL, 0, NULL}
};

static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,
    "_native",
    "Native bindings for tiny",
    -1,
    Methods,
};

PyMODINIT_FUNC PyInit__native(void) {
    return PyModule_Create(&moduledef);
}
