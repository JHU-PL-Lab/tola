# Canary Opam Packaging Notes

## Version-encoded structure convention

Opam package versions encode the structural variant — what the package builds
against and how. This avoids proliferating separate package names for each
combination:

| Opam package | Lib source | Binding source | Notes |
|---|---|---|---|
| `z3.dev-src` | build from source (HEAD) | build from source (HEAD) | full source build |
| `z3.dev-sys` | system PM (`libz3-dev`) | build from source (HEAD) | binding vs system lib |
| `z3.4.15.2` | official opam (builds from source) | same | upstream stable |
| `llvm.dev-shared` | build from source (HEAD), shared | build from source | current canary |
| `llvm.19-shared` | apt `llvm-19-dev` | opam stable | system-backed stable |

The version string after `.` carries semantic meaning:
- `dev-src` = HEAD, entirely built from source (no system deps)
- `dev-sys` = HEAD binding, system-provided lib
- `<N>-shared` = specific major version, shared lib (z3 is always shared, so omit suffix)

`-src` and `-sys` mirror the existing `-shared` convention in the LLVM packages.
z3 always produces a shared library so the shared/static distinction is dropped —
`z3.dev-src` implicitly means shared.

**Current preference**: single package per variant, version encodes structure.
No separate package names (`z3_full`, `z3_sys`, etc.) — the version string
is the differentiator.

## On conf packages

opam's `conf-<pkg>` convention handles the "find a system library" concern
at the opam solver level: a conf package validates that the system dep is
present and exports opam variables (lib path, version) for downstream packages.

**Long-term direction**: avoid conf packages. Reasons:

1. They add an indirection layer that obscures what's actually happening.
   `conf-llvm-shared.19` with its `configure.sh` search logic is harder to
   reason about than a direct `pkg-config`/`llvm-config` call in the binding's
   build script.

2. The conf package's locator search order is opaque to the user and hard
   to override. A binding that calls the locator directly can expose
   `$LLVM_CONFIG` or `$Z3_PREFIX` as a first-class override.

3. Conf packages fragment the version space: `conf-llvm-shared.19`,
   `conf-llvm-shared.dev`, `conf-z3.dev` — each is a separate package with
   its own opam file to maintain.

4. For canary's purposes, the canary build steps (`fetch_lib` / `configure`)
   already establish the correct library path. Passing it via `CANARY_BUILD_DIR`
   / `CANARY_SRC_DIR` env vars is a direct, auditable mechanism that doesn't
   require a conf package at all.

**Practical position**: keep `conf-llvm-shared.*` for now since they're
already present in upstream opam and removing them would break compatibility.
Don't add new conf packages for z3 or future projects — encode the variant
in the version string and pass library paths directly via env vars.

## Stub library coexistence (exploration)

**Problem**: two opam variants of the same package (e.g., `z3.dev` and
`z3.dev-sys`) both install `dllz3ml.so` to the same path:

```
~/.opam/<switch>/lib/stublibs/dllz3ml.so   ← collision
```

`stublibs/` is the global stub search path for OCaml's bytecode runtime
(`ocamlrun`). Only one stub with a given name can exist there.

**Why it matters for bytecode only**: native code links via `libz3ml.a`
(static stub archive) + `-L<path>` linkopts — stub location is irrelevant.
The collision is a bytecode-only problem.

**The `dllpath` mechanism**: OCaml's `ocamlmklib` has a `-dllpath <dir>`
flag that embeds a stub search path directly into the `.cma` file. At
bytecode runtime, `ocamlrun` searches embedded `dllpath` entries in addition
to `stublibs/`. This would allow a variant to install its stub outside
`stublibs/`:

```
~/.opam/<switch>/lib/z3_sys/dllz3ml.so   ← variant-specific dir
```

**Minimal change set** (if coexistence were needed):

1. cmake → `ocamlmklib` invocation: add `-dllpath %{lib}%/z3_sys` when
   building `dllz3ml.so`. Injects the search path into `z3ml.cma`.

2. opam template `install:` section: use `-stublibs %{lib}%/z3_sys` to
   redirect where ocamlfind places the stub (instead of the global stublibs).

3. META: `directory = "z3_sys"` so `-package z3_sys` resolves correctly.

4. Probe invocation: set `CAML_LD_LIBRARY_PATH` as a simpler runtime
   alternative to the embedded `dllpath`:
   ```sh
   CAML_LD_LIBRARY_PATH=~/.opam/<switch>/lib/z3_sys:$CAML_LD_LIBRARY_PATH
   ```

**Verdict**: ~30 lines of changes. Adds fragility (embedded install-time
paths break on switch relocation). **Not needed for canary** — probe steps
are sequential sub-runs that install/uninstall one variant at a time.
Coexistence would only be useful for a single OCaml program that imports
both variants simultaneously, which is not a canary use case.

**Practical approach**: declare `conflicts: ["z3"]` in `z3_full.dev`'s
opam file. opam prevents simultaneous install; canary's sequential sub-runs
(remove old, install new) provide equivalent test coverage.
