# Install Target Survey: Z3 and LLVM

Last updated: 2026-04-16. Informs TODO #25 (model `cmake --install` as canary action slot).

## Three canonical patterns

| Pattern | Representative | Discovery tool | OCaml install | Rpath |
|---------|---------------|----------------|---------------|-------|
| **pkg-config** | Z3 | `z3.pc` + `Z3Config.cmake` | Manual (`ocamlfind`) | Build-time `$ORIGIN` |
| **llvm-config** | LLVM | `llvm-config` binary | cmake `install()` automated | `$CAMLORIGIN/../..` (relocatable) |
| **cmake config only** | many C++ libs | `*Config.cmake` only | N/A | Standard cmake rpath |

---

## Z3

### cmake install output
- `libz3.so` → `$PREFIX/lib/`
- `z3.h`, `z3_api.h`, ... → `$PREFIX/include/`
- `z3.pc` → `$PREFIX/lib/pkgconfig/`
- `Z3Config.cmake`, `Z3ConfigVersion.cmake` → `$PREFIX/lib/cmake/z3/`

Discovery: **dual** — pkg-config + CMake config module. No llvm-config-style tool.

### OCaml binding — NOT cmake-installed
`src/api/ml/CMakeLists.txt` has no `install()` calls. cmake builds:
- `z3ml.{cma,cmxa,cmxs}`, `libz3ml.a`, `dllz3ml.so`, `META`

but does not install them. The PM or user must run `ocamlfind install z3 META ...`.

Rpath in `dllz3ml.so`: set at build via `-dllpath "$ORIGIN/../libz3.so"` (hardcoded
relative to the stub's location at build time — breaks if moved).

### Canary implication
`install_lib` = `cmake --install --prefix $PREFIX`
`install_binding` = separate `ocamlfind install z3` step (not cmake)

---

## LLVM

### cmake install output
- `libLLVM.so` → `$PREFIX/lib/`
- Headers → `$PREFIX/include/llvm/`
- `LLVMConfig.cmake` → `$PREFIX/lib/cmake/llvm/`
- OCaml bindings → `$LLVM_OCAML_INSTALL_PATH/llvm/` (default: `$(ocamlfind query destdir)/llvm/`)
- OCaml META → `$LLVM_OCAML_INSTALL_PATH/META.llvm`
- `llvm-config` binary → `$PREFIX/bin/`

Discovery: **llvm-config** + CMake config. No pkg-config.

The `conf-llvm-{static,shared}` opam packages run `configure.sh` which probes
`llvm-config-N` / `llvm-config` and stores the path as the `config` variable.

### OCaml binding — cmake-automated
`bindings/ocaml/CMakeLists.txt` uses `add_ocaml_library()` which calls `install()`.
`LLVM_OCAML_INSTALL_PATH` defaults to `${OCAML_STDLIB_PATH}` (from `ocamlfind query destdir`).

Rpath in `llvm.cmxa` (embedded as Extra C options):
```
-L$CAMLORIGIN/../.. -Wl,-rpath,$CAMLORIGIN/../..
```
`$CAMLORIGIN` = directory of the `.cmxa` at link time. In the build tree
(`build/lib/ocaml/llvm/`), `$CAMLORIGIN/../..` = `build/lib/` ✓. After
`cmake --install` to a system prefix (`/usr/lib/llvm-19/`):
`/usr/lib/llvm-19/lib/ocaml/llvm/` → `$CAMLORIGIN/../..` = `/usr/lib/llvm-19/lib/` ✓.

**The rpath works correctly only when the install layout matches:
`$PREFIX/lib/ocaml/llvm/` for the cmxa + `$PREFIX/lib/` for libLLVM.so.**

Our `llvm.dev-shared` bypasses `cmake --install` and copies artifacts into opam's
flat `lib/llvm/` layout, breaking the `$CAMLORIGIN/../..` path → requires `linkopts`
workaround in META.

### Canary implication
`install_lib` + `install_binding` = single `cmake --install --prefix $PREFIX`
(LLVM cmake install handles both together)

The `$PREFIX` must satisfy `$PREFIX/lib/ocaml/llvm/` for the cmxa for rpath to work.
Setting `LLVM_OCAML_INSTALL_PATH` explicitly overrides the default if needed.

---

## Candidate choices for canary project spec

```ocaml
type install_strategy =
  | Cmake_install of { prefix : string; components : string list option }
    (* Single cmake --install handles lib + binding (LLVM) *)
  | Cmake_install_lib_then_ocamlfind of { prefix : string; pkg : string }
    (* cmake --install for lib; separate ocamlfind install for binding (Z3) *)
  | Ocamlfind_install_only of { pkg : string }
    (* No cmake install; direct ocamlfind from build tree (current llvm.dev-shared) *)
```

The `Cmake_install` path requires the prefix layout to match what the project's
cmake expects (LLVM: `$PREFIX/lib/ocaml/<name>/`). The `Cmake_install_lib_then_ocamlfind`
path is more portable but requires knowing the binding file list.

---

## Common failure modes at the install boundary

1. **Wrong prefix** — cmake installs to `/usr/local/` but conf-* probes `/usr/lib/llvm-N/`
2. **Rpath baked to build tree** — `$ORIGIN`/`$CAMLORIGIN` paths correct at build,
   wrong after install if layout changes (Z3 stub, LLVM in opam flat layout)
3. **OCaml binding not installed by cmake** (Z3) — PM must know to run `ocamlfind install`
4. **`llvm-config` not on PATH** — conf-llvm probes fail silently, falls back to wrong version
5. **META `directory` field** — if cmake installs a META with `directory = "subdir"`,
   ocamlfind expects archives in that subdirectory (must match actual install layout)
