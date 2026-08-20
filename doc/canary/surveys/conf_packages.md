# conf-* Package Build Complexity Analysis

Companion to [opam.md](opam.md). Classifies all 333
`conf-*` packages by what their `build:` section does, including
extra-source files fetched at install time.

Source: opam-repository at `/home/red/code/contrib/opam-all/opam-repository`,
extra-source files at `/home/red/code/contrib/opam-all/opam-source-archives`.

## Summary

| Category           | Count | %   | Eliminable?                               |
| ------------------ | ----- | --- | ----------------------------------------- |
| pkg-config check   | 208   | 62% | Yes — `pkg-config <name>`                 |
| Version/help check | 59    | 18% | Yes — `<tool> --version` or `<tool> -V`   |
| Compile test       | 34    | 10% | Mostly — `cc -c test.c` with known header |
| No build           | 18    | 5%  | Yes — just depexts declaration            |
| Which/path check   | 9     | 3%  | Yes — `which <tool>` or `command -v`      |
| Custom logic       | 19    | 6%  | No — project-specific discovery           |

**~314 out of 333 (94%) are mechanical.** They follow a formulaic
pattern that could be dynamically generated from a declaration. Only
~19 packages (6%) have genuinely custom discovery logic.

69 conf packages fetch extra-source files (test.c, configure.sh,
OCaml/Python scripts). These were inspected and factored into the
classification above.

## Category details

### pkg-config check (208 packages)

The dominant pattern. Build section is just:
```
build: ["pkg-config" "--print-errors" "--exists" "<libname>"]
```
Plus OS-specific variants for Windows (pkgconf with personality flags).
Some also have a `test.c` compile fallback (e.g., conf-gmp tries
pkg-config first, falls back to `cc -c test.c`).

Examples: conf-sqlite3, conf-zlib, conf-libssl, conf-gmp,
conf-cairo, conf-ffmpeg, conf-ncurses, conf-libffi.

Eliminable with:
```ocaml
{ check = Pkg_config "sqlite3"; depexts = [("debian", "libsqlite3-dev"); ...] }
```

### Version/help check (59 packages)

Runs the tool with `--version`, `-V`, `--help`, or similar:
```
build: ["cmake" "--version"]
build: ["dot" "-V"]
build: ["zig" "version"]
build: ["autoconf" "-V"]
```

Includes: conf-autoconf, conf-diffutils, conf-graphviz, conf-lz4,
conf-openssl, conf-scdoc, conf-zig, conf-neko, conf-openjdk,
conf-texlive, conf-assimp, conf-lld, conf-pandoc, conf-findutils.

Eliminable with:
```ocaml
{ check = Command_exists "cmake"; depexts = [("debian", "cmake"); ...] }
```

### Compile test (34 packages)

Compiles a small C file to verify headers/libraries are available:
```
build: ["cc" "-c" "test.c"]
build: ["cc" "-lrocksdb" "main.c"]
```

The `test.c` files are fetched via `extra-source` and are formulaic
(`#include <header.h>`, call one function, exit). Examples:
conf-gmp, conf-bluetooth, conf-dbm, conf-pam, conf-rocksdb.

Eliminable with:
```ocaml
{ check = Compile_test { header = "gmp.h"; lib = Some "gmp" }; ... }
```

### No build (18 packages)

Empty or trivial build section. Package exists purely for its
`depexts:` declaration.

### Which/path check (9 packages)

`which <tool>` or `command -v`. Same as version check but without
version verification.

### Python import checks (4 packages)

```
build: ["python3" "-c" "import yaml"]
build: ["python3" "test.py"]
```
conf-python3-pyparsing, conf-python3-tomli, conf-python3-yaml,
conf-python-2-7.

### Locator-tool checks (3 packages)

Uses a project-specific config tool:
```
build: ["curl-config" "--libs"]     — conf-libcurl
build: ["mysql_config" "--include"] — conf-mysql
build: ["wx-config" "--libs"]       — conf-wxwidgets
```

### Custom logic (19 packages) — NOT eliminable

These have project-specific discovery logic: multi-path search,
version negotiation, platform-specific fallbacks.

**Custom shell scripts (9):**

| Package                   | Script       | What it does                                                             |
| ------------------------- | ------------ | ------------------------------------------------------------------------ |
| conf-llvm                 | configure.sh | Tries 10+ llvm-config name variants, validates version, checks link mode |
| conf-llvm-static          | configure.sh | Same as conf-llvm but checks `--link-static` support                     |
| conf-llvm-shared          | configure.sh | Same but checks `--link-shared`                                          |
| conf-libclang             | configure.sh | Similar to llvm — multi-path versioned search                            |
| conf-cmake                | configure.sh | Version parsing and minimum version enforcement                          |
| conf-qt                   | configure.sh | Qt-specific discovery (qmake, pkg-config fallback)                       |
| conf-libev                | build.sh     | Custom header/library search with OS-specific paths                      |
| conf-libssl               | homebrew.sh  | macOS keg-only openssl path resolution                                   |
| conf-dkml-cross-toolchain | —            | DKML-specific cross-compilation setup                                    |

**OCaml discovery scripts (5):**

| Package       | Script              | What it does                |
| ------------- | ------------------- | --------------------------- |
| conf-bap-llvm | find-llvm.ml.in     | Custom LLVM path search     |
| conf-binutils | find-binutils.ml.in | Custom binutils path search |
| conf-ida      | find-ida.ml.in      | Searches IDA Pro paths      |
| conf-radare2  | find-radare2.ml.in  | Custom radare2 search       |
| conf-libev    | discover.ml         | Multi-strategy discovery    |

**Other custom (5):**

| Package          | Logic                                    |
| ---------------- | ---------------------------------------- |
| conf-cuda-config | Searches multiple CUDA install paths     |
| conf-msvc32/64   | Windows MSVC detection                   |
| conf-env-travis  | Reads Travis CI environment              |
| conf-pic-switch  | Checks OCaml compiler PIC flag           |
| conf-rust-wasm   | Checks Rust target list for wasm support |

## Extra-source files (full listing)

69 conf packages fetch files via `extra-source`. The table below
lists every file with its local path for inspection.

| Package             | File                                   | Type   | Local path                                      |
| ------------------- | -------------------------------------- | ------ | ----------------------------------------------- |
| conf-bap-llvm       | configure                              | sh     | `patches/conf-bap-llvm/configure`               |
| conf-bap-llvm       | find-llvm.ml.in (8 versions)           | ml     | `patches/conf-bap-llvm/find-llvm.ml.in.1.*`     |
| conf-binutils       | find-binutils.ml.in (3 versions)       | ml     | `patches/conf-binutils/find-binutils.ml.in.0.*` |
| conf-blas           | test.c, test-win.sh                    | c, sh  | `patches/conf-blas/test.c`                      |
| conf-bluetooth      | test-unix.c                            | c      | `patches/conf-bluetooth/test-unix.c`            |
| conf-bmake          | detect_program.sh                      | sh     | `patches/conf-bmake/detect_program.sh`          |
| conf-cmake          | configure.sh                           | sh     | `patches/conf-cmake/configure.sh`               |
| conf-dbm            | test_gdbm.c, test_ndbm.c               | c      | `patches/conf-dbm/test_gdbm.c`                  |
| conf-env-travis     | configure                              | sh     | `patches/conf-env-travis/configure`             |
| conf-fswatch        | test.c                                 | c      | `patches/conf-fswatch/test.c`                   |
| conf-fts            | test.c                                 | c      | `patches/conf-fts/test.c`                       |
| conf-gmp            | test.c (4 versions)                    | c      | `patches/conf-gmp/test.c.4`                     |
| conf-gmp-paths      | test-gmp.c                             | c      | `patches/conf-gmp-paths/test-gmp.c`             |
| conf-gmp-powm-sec   | test.c (3 versions)                    | c      | `patches/conf-gmp-powm-sec/test.c.3`            |
| conf-ida            | find-ida.ml.in (3 versions)            | ml     | `patches/conf-ida/find-ida.ml.in.0.*`           |
| conf-lapack         | test.c, test-win.sh                    | c, sh  | `patches/conf-lapack/test.c`                    |
| conf-leveldb        | test.cc                                | cc     | `patches/conf-leveldb/test.cc`                  |
| conf-libclang       | configure.sh (8 versions)              | sh     | `patches/conf-libclang/configure.sh.*`          |
| conf-libev          | build.sh, discover.ml (3 versions)     | sh, ml | `patches/conf-libev/build.sh`                   |
| conf-libportmidi    | check.sh                               | sh     | `patches/conf-libportmidi/check.sh`             |
| conf-libssl         | homebrew.sh (2 versions), osx-build.sh | sh     | `patches/conf-libssl/homebrew.sh.4`             |
| conf-libsvm         | test.c                                 | c      | `patches/conf-libsvm/test.c`                    |
| conf-llvm           | configure.sh (14 versions)             | sh     | `patches/conf-llvm/configure.sh.18`             |
| conf-mbedtls        | test.c                                 | c      | `patches/conf-mbedtls/test.c`                   |
| conf-mecab          | test.c                                 | c      | `patches/conf-mecab/test.c`                     |
| conf-mpfr           | test.c                                 | c      | `patches/conf-mpfr/test.c`                      |
| conf-mpfr-paths     | test-mpfr.c                            | c      | `patches/conf-mpfr-paths/test-mpfr.c`           |
| conf-mpi            | configure                              | sh     | `patches/conf-mpi/configure`                    |
| conf-netsnmp        | test.c                                 | c      | `patches/conf-netsnmp/test.c`                   |
| conf-openblas       | test.c (4 versions), centos_install.sh | c, sh  | `patches/conf-openblas/test.c.0.2.2`            |
| conf-opencc0        | test.c                                 | c      | `patches/conf-opencc0/test.c`                   |
| conf-opencc1        | test.c                                 | c      | `patches/conf-opencc1/test.c`                   |
| conf-opencc1_1      | test.c                                 | c      | `patches/conf-opencc1_1/test.c`                 |
| conf-openimageio    | test.cpp                               | cpp    | `patches/conf-openimageio/test.cpp`             |
| conf-pam            | main.c                                 | c      | `patches/conf-pam/main.c`                       |
| conf-pic-switch     | check.sh                               | sh     | `patches/conf-pic-switch/check.sh`              |
| conf-ppl            | test.c                                 | c      | `patches/conf-ppl/test.c`                       |
| conf-python-2-7     | test.py                                | py     | `patches/conf-python-2-7/test.py`               |
| conf-python-2-7-dev | test.c                                 | c      | `patches/conf-python-2-7-dev/test.c`            |
| conf-python-3       | test.py                                | py     | `patches/conf-python-3/test.py`                 |
| conf-python-3-7     | configure.sh, test.py                  | sh, py | `patches/conf-python-3-7/configure.sh`          |
| conf-python-3-dev   | Makefile, test.c                       | c      | `patches/conf-python-3-dev/test.c`              |
| conf-qt             | configure.sh                           | sh     | `patches/conf-qt/configure.sh`                  |
| conf-r              | check.r                                | r      | `patches/conf-r/check.r`                        |
| conf-radare2        | find-radare2.ml.in                     | ml     | `patches/conf-radare2/find-radare2.ml.in`       |
| conf-rdkit          | test.cpp                               | cpp    | `patches/conf-rdkit/test.cpp`                   |
| conf-rocksdb        | main.c                                 | c      | `patches/conf-rocksdb/main.c`                   |
| conf-rust-2018      | test.rs                                | rs     | `patches/conf-rust-2018/test.rs`                |
| conf-rust-2021      | test.rs                                | rs     | `patches/conf-rust-2021/test.rs`                |
| conf-snappy         | test.cpp                               | cpp    | `patches/conf-snappy/test.cpp`                  |
| conf-sundials       | test.c                                 | c      | `patches/conf-sundials/test.c`                  |
| conf-tcl            | check.sh, compiletest.c                | sh, c  | `patches/conf-tcl/check.sh`                     |
| conf-tidy           | test.c                                 | c      | `patches/conf-tidy/test.c`                      |
| conf-tk             | check.sh, compiletest.c                | sh, c  | `patches/conf-tk/check.sh`                      |
| conf-trexio         | test.c                                 | c      | `patches/conf-trexio/test.c`                    |
| conf-xen            | test.c                                 | c      | `patches/conf-xen/test.c`                       |
| conf-zmq            | test.c                                 | c      | `patches/conf-zmq/test.c`                       |

All paths are relative to `/home/red/code/contrib/opam-all/opam-source-archives`.
For versioned files (e.g., `test.c.4`), the latest version is listed.

To inspect any file:
```bash
cat /home/red/code/contrib/opam-all/opam-source-archives/patches/<package>/<file>
```

### Extra-source file type summary

| File type     | Count | Purpose                                      |
| ------------- | ----- | -------------------------------------------- |
| `.c` / `.cc`  | 34    | Compile test (include header, call function) |
| `.sh`         | 10    | Custom discovery / platform workarounds      |
| `.ml` / `.in` | 5     | OCaml path search scripts                    |
| `.py`         | 4     | Python version/import checks                 |
| `.cpp`        | 3     | C++ compile tests                            |
| `.rs`         | 3     | Rust compile tests                           |
| Other         | 3     | Makefile, configure, .com                    |

## Could conf-* be replaced?

**For ~314 packages (94%): yes.** Their entire logic fits one of:
- `Pkg_config of string` (208)
- `Command_exists of string` (59)
- `Compile_test of { header; lib }` (34)
- `Python_import of string` (4)
- `Config_tool of { cmd; args }` (3)
- No check needed (18)

opam could have a built-in `conf` mechanism:
```
x-system-check: ["pkg-config" "sqlite3"]
```
or a typed declaration that replaces the need for a separate package.

**For ~19 packages (6%): no.** These have real search logic (multiple
paths, version negotiation, fallback strategies). They need either:
- Custom scripts (what they have now)
- A richer declarative language for discovery (version ranges,
  path search lists, per-platform overrides)

**The LLVM family is the poster child for "not eliminable":**
conf-llvm-static.19's `configure.sh` tries 10+ binary names
(`llvm-config-19`, `llvm-config19`, `llvm-config-19.0`,
`llvm-config-mp-19`, `llvm19-config`, etc.) plus brew cellar
paths. This search logic is LLVM-specific and can't be expressed
as a simple declaration.

## Implications for canary

1. **Canary can generate dynamic conf checks** for the 94% that are
   mechanical — no need to install a conf-* package to verify system
   deps are present. This is what `canary_basic_apt.verify_installed_cmd`
   and `canary_basic_opam.check_available_cmd` are building toward.

2. **The 6% custom cases are where version mismatches actually happen.**
   LLVM, Qt, CUDA, libclang, etc. These are the packages canary should
   focus on for version resolution chain testing.

3. **A `canary query <project>` command** could run the appropriate
   check (pkg-config / version / compile) without going through
   opam install, giving immediate feedback on system readiness.

## Follow-up (2026-08-20) — landing plan for the version-free conf projects

> Requested by the user after the conda-forge study: *"landing ocaml
> projects with a conf-pkg which doesn't specify a system package version
> are the best to start"*. This section says why that is the right
> criterion, what work a landing costs now that we have done four of
> them, and which packages to take first. Companion reading:
> [`conda_forge.md`](conda_forge.md) (where the latest lib comes from),
> [`../project/landing.md` §3–4](../project/landing.md) (the sourcing
> rule + the bug classes), [`opam.md` §3](opam.md) (revdep counts).

### F1. Why "no version constraint" is the cheap-landing criterion

A project's 2×2 needs a lib PAIR. What decides whether we can even build
that pair is the package-manager gate — how the binding's opam package
declares its dependency on the C lib (`Canary_binding_decl.pm_dep_gate`,
measured per project):

| gate | forcing a lib version costs | example |
| --- | --- | --- |
| `Free_with_conf` — conf-* present, **no version** | **nothing**: any obtainable version is installable | zarith/conf-gmp, cairo2/conf-cairo, ssl/conf-libssl, sqlite3/conf-sqlite3 |
| `Bounded_with_conf` — a range on the CONF package | nothing inside the bound | ctypes-foreign/`conf-libffi {>= "2.0.0"}` |
| `Fixed_with_conf` — an exact pin | a wrapper package that drops the conf dep | llvm/`conf-llvm-shared {= "19"}` |
| `Package_builds_lib` / `Bundled` | no pairing exists | opam z3; the z3-solver & llvmlite wheels |

The survey's dominant category IS the cheap one: **208 of 333 conf
packages (62%) are a bare `pkg-config --exists <lib>` presence check** —
no version anywhere. So the criterion selects most of the ecosystem, and
it selects it for a principled reason: with no gate, the lib axis is limited
only by what we can OBTAIN, which the conda-forge route now answers.

**One caveat the criterion does not cover** (measured in
[`conda_forge.md` §4](conda_forge.md)): a free gate lets opam INSTALL the
binding against any lib, but a **soname bump** still stops the binding
from LOADING the new lib — its own `DT_NEEDED` names the old soname. A
version-free conf package plus a soname bump (openssl 3→4) means the
consumer must be rebuilt, not re-pointed. So the criterion picks cheap
landings; the soname check picks which of them are *point-at-it* cheap.

### F2. What a landing costs, now that we have done four

The per-project checklist, in the order that avoids rework (each step's
"why" is a bug we actually hit):

1. **Declare the artifact table** — rows + universes + providers, with
   `ar_rationale` on the lib row saying where each point came from *and
   why the axis stops there* (a one-point axis is usually a fact about the
   world; without the note a reader cannot tell it from an omission).
2. **Declare the binding** — `binding_decl` (mechanism, c_api, native,
   coupling, surface_path) **plus `pm_gate` measured from
   `opam show <pkg> --field=depends`**, not guessed. Our guess about ssl
   was wrong; the metadata was right.
3. **Source the lib pair** — system PM = stable; official prebuilt if one
   exists (none of our libs publish Linux binaries); else conda-forge's
   newest, declared `Vendored` at `contrib/<p>-all/prebuilt/<tag>/`.
4. **Check the closure BEFORE trusting it** — `readelf -d` (NEEDED +
   RPATH), `ldd -r` (undefined symbols), `dlopen(RTLD_NOW)`. A one-entry
   closure (zlib, libffi) is trivially safe; a thirteen-entry one (cairo)
   works only because the system happens to satisfy it.
5. **Compare sonames across the pair.** Same soname → `LD_LIBRARY_PATH`
   suffices. Different → the consumer needs a rebuild; schedule it as
   wrapper work, not as a declaration.
6. **Point the CONSUMER at the world's lib.** The probe must carry the
   world's libdir; otherwise the vendored world silently re-tests the
   system lib and passes for the wrong reason.
7. **Pin it**: the enumeration count, and — the one with teeth — that the
   two worlds' realized commands NAME DIFFERENT FILES. cairo proves why:
   its two versions export identical symbol counts, so a silent fallback
   is invisible in the verdict.
8. **Run and verify each world holds its declared version** (a runtime
   version line, asserted where canary controls the version; observed
   where it does not).

Roughly: steps 1–3 are declaration (~40 lines for a template project),
4–5 are measurement (minutes), 6–8 are the parts that were bugs the first
four times.

### F3. The ranking — measured, not guessed

Data gathered 2026-08-20: the conf constraint from
`opam show <binding> --field=depends`, apt versions from `apt-cache
madison`, conda-forge from `api.anaconda.org`.

| # | lib / binding | conf gate | apt (stable) | conda-forge (latest) | pair? | why this rank |
| --- | --- | --- | --- | --- | --- | --- |
| **1** | **zlib / camlzip** | `conf-zlib`, no constraint | 1.3 | **1.3.2** | ✓ | Highest uncovered revdeps (18). Tiny closure (libc only, zlib's shape). Same soname → point-at-it. Cstubs. The cheapest complete landing available |
| **2** | **zstd / zstandard** | `conf-zstd`, no constraint | 1.5.5 | **1.5.7** | ✓ | Same shape as zlib, small closure, and it is one of `bytesrw`'s five optional backends — landing it standalone first de-risks the optional-dep work later |
| **3** | **mpfr / mlgmpidl** | `conf-mpfr-paths` + `conf-gmp-paths` | (mpfr 4.x) | to measure | ? | The first STACKED dependency (mpfr needs gmp, which we cover). Note the gate is the `-paths` conf FAMILY, not plain `conf-mpfr` — a different conf style worth studying on its own |
| **4** | **libev / lwt** | `conf-libev` as a **depopt** | 4.33 (single) | to measure | — | The optional-dependency axis (`Absent` provision), which we deferred: needs the per-artifact "mandatory vs optional" rule plus a combination policy |
| **5** | **python3-dev / pyml** | `conf-python-3-dev` only `{with-test}` | 3.12 only here | n/a | — | pyml links libpython directly rather than through a conf gate, and this box has one python3-dev. Interesting but not a version-pair candidate without a PPA |
| — | ncurses, libseccomp, ffmpeg, rdkit, boost | — | — | — | — | No clean OCaml binding measured, or a heavy closure. Revisit after 1–2 |

**Take 1 and 2 first.** Both are `Free_with_conf` with a real pair, both
have small dependency closures, and both are same-soname, so the entire
landing is declaration + the checklist — no wrapper, no rebuild, no model
change. They also each add something: zlib brings the highest uncovered
revdep count, zstd is a bytesrw backend.

**3 and 4 each need a model piece first** — the stacked lib (named lib
artifacts) and the optional dep (`Absent` in a universe + a combination
policy). They are the honest next arc, not the next landing.

### F4. What this plan does NOT cover

- The `Fixed_with_conf` family (llvm's shape) — needs the no-conf wrapper
  to move a lib version at all. Different work, tracked with the wrapper.
- The 6% custom-logic conf packages (§ "Custom logic"): the survey's own
  observation is that they are where version mismatches actually happen.
  They are the highest-yield targets and the most expensive; they belong
  after the cheap landings have proven the pipeline end to end.
- Optional-dep combinations (bytesrw's five backends) — see
  [`../design/multi_lib.md` §2](../design/multi_lib.md).

---

*Analysis based on opam-repository at `/home/red/code/contrib/opam-all/opam-repository`
and opam-source-archives at `/home/red/code/contrib/opam-all/opam-source-archives`.
Classification by grep heuristics on build sections + extra-source file
inspection. Scripts: `doc/canary/raw/classify_conf.sh`,
`doc/canary/raw/conf_revdeps.sh`.*
