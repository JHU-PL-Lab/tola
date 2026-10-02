---
name: gotcha-caml-ld-shadow
description: A build step's OCaml self-check can load the switch's stale stublib instead of the fresh one — guard CAML_LD_LIBRARY_PATH with absolute paths
metadata:
  type: project
---

When a build step runs an OCaml bytecode self-check (z3's
`build_z3_ocaml_bindings` runs `ocamlrun ml_example.byte` after the
build), `CAML_LD_LIBRARY_PATH`, which `eval $(opam env)` sets to the
switch's stublibs, beats the bytecode's own `-dllpath`. An older copy of
the stublib in the switch then shadows the fresh one, and a new OCaml
external dies with `unknown C primitive '<name>'`, which looks like an
upstream break: it once produced a wrong "z3 HEAD is broken" finding.

**How to apply:** a build step that runs such a self-check takes the
`env_guard` parameter of `ninja_build_binding`: prefix the build
directory to `CAML_LD_LIBRARY_PATH`, and set `LD_LIBRARY_PATH` for native
code. The paths must be absolute (`$(pwd)/<build>`): ninja runs the check
from `<build>/src/api/ml`, so a relative path resolves wrongly and the
stale dll wins again.

The link-time variant: a cmxa that embeds `-L<stublibs> -L<build> -lz3`
links the switch's library, not the built one. Link the probe with the
full path, `-cclib "<build>/libz3.so"`.
