# `tiny`

Foundational example for surface theory: a minimal C library + three
language bindings (OCaml cstubs, Python CPython C extension, Python
ctypes) + eight deliberately-broken scenarios.

**Documentation lives at
[`../../../doc/canary/research/tiny.md`](../../../doc/canary/research/tiny.md).**
Design rationale, file-level spec, build instructions, per-scenario
detail, coverage, and findings all live there.

Quick reference for impatient readers:

```sh
make all           # build C lib + OCaml binding + Python cext binding
make probe         # run the baseline probes (all three should print "all checks passed")
make scenarios     # run all eight scenarios
make scenario-<n>  # run a single scenario (e.g. make scenario-symbol_missing)
make inspect       # run canary inspectors on every surface
make clean
```

See `surface_theory.md` for the abstract framework `tiny` instantiates.
