---
name: gotcha-caml-ld-shadow
description: OCaml bytecode dll search — CAML_LD_LIBRARY_PATH beats -dllpath; opam stublibs can shadow a freshly built dll and fake a "broken upstream" finding
metadata:
  type: feedback
---

When a build step runs an OCaml **bytecode** self-check (e.g. z3's
`build_z3_ocaml_bindings` POST_BUILD runs `ocamlrun ml_example.byte`),
the dll that loads is NOT necessarily the one just built:
`CAML_LD_LIBRARY_PATH` (which `eval $(opam env)` always sets to the
switch's stublibs) **beats the bytecode's embedded `-dllpath`** in the
search. If the opam switch holds an older copy of the same stublib
(e.g. a pinned `z3.4.16.0` while the build produces a newer
`dllz3ml.so`), the stale dll shadows the fresh one and any NEW OCaml
external in the fresh `.ml` dies with `Fatal error: unknown C primitive
'<name>'` at bytecode startup — masquerading as an upstream source
break. This cost a full wrong "z3 official HEAD is broken" finding
(2026-08-12 → retracted 2026-08-13).

**Why:** the shared-store hazard class in a BUILD step's self-check, not
a probe; opam stublibs is a global store the check reads silently.

**How to apply:** any canary build step that runs OCaml bytecode/native
self-checks against freshly built stubs needs an env guard — prefix the
build dir to `CAML_LD_LIBRARY_PATH` (bytecode dll) and set
`LD_LIBRARY_PATH=<build>` (native DT_NEEDED; `DYLD_LIBRARY_PATH` in
z3's CMakeLists is a macOS no-op on Linux). Implemented as the optional
`env_guard` param on the `ninja_build_binding` action-table primitive
(z3's dev row). **The guard paths must be ABSOLUTE** (`$(pwd)/<build>`):
ninja's POST_BUILD self-check runs from `<build>/src/api/ml`, so a
relative entry resolves against the wrong cwd and the stale dll wins
again (hit this exact trap once).

**Link-level variant**: a built cmxa can embed `-L<stublibs> -L<build>
-lz3` — the store's stale lib wins the `-lz3` search at CONSUMER link
time. Symptom: undefined symbols for the newest API (z3 finite-set at
official HEAD) even though `nm -D <build>/libz3.so` exports them; in
the fork era the probe silently linked the store lib instead of the
built one. Fix: `-cclib "<build>/libz3.so"` (full path) on the probe
link. Related: [[project-canary-ci]], the upstream z3 PR candidate in
`doc/canary/project/status_project.md`.
