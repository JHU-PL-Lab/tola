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

| gate                                              | forcing a lib version costs                        | example                                                                   |
| ------------------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------- |
| `Free_with_conf` — conf-* present, **no version** | **nothing**: any obtainable version is installable | zarith/conf-gmp, cairo2/conf-cairo, ssl/conf-libssl, sqlite3/conf-sqlite3 |
| `Bounded_with_conf` — a range on the CONF package | nothing inside the bound                           | ctypes-foreign/`conf-libffi {>= "2.0.0"}`                                 |
| `Fixed_with_conf` — an exact pin                  | a wrapper package that drops the conf dep          | llvm/`conf-llvm-shared {= "19"}`                                          |
| `Package_builds_lib` / `Bundled`                  | no pairing exists                                  | opam z3; the z3-solver & llvmlite wheels                                  |

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

| #     | lib / binding                             | conf gate                              | apt (stable)   | conda-forge (latest) | pair? | why this rank                                                                                                                                                                      |
| ----- | ----------------------------------------- | -------------------------------------- | -------------- | -------------------- | ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **1** | **zlib / camlzip** — LANDED 2026-08-20 | `conf-zlib`, no constraint | 1.3 | **1.3.2** | ✓ | Landed. See §G5 |
| **2** | **zstd** — LANDED 2026-08-20 | `conf-zstd` — **floor `>= 1.3.8`**, measured at the conf package (§G1a), not visible in the binding's metadata | 1.5.5 | **1.5.7** | ✓ | Landed. See §G5 |
| **3** | **mpfr / mlgmpidl**                       | `conf-mpfr-paths` + `conf-gmp-paths`   | (mpfr 4.x)     | to measure           | ?     | The first STACKED dependency (mpfr needs gmp, which we cover). Note the gate is the `-paths` conf FAMILY, not plain `conf-mpfr` — a different conf style worth studying on its own |
| **4** | **libev / lwt**                           | `conf-libev` as a **depopt**           | 4.33 (single)  | to measure           | —     | The optional-dependency axis (`Absent` provision), which we deferred: needs the per-artifact "mandatory vs optional" rule plus a combination policy                                |
| **5** | **python3-dev / pyml**                    | `conf-python-3-dev` only `{with-test}` | 3.12 only here | n/a                  | —     | pyml links libpython directly rather than through a conf gate, and this box has one python3-dev. Interesting but not a version-pair candidate without a PPA                        |
| —     | ncurses, libseccomp, ffmpeg, rdkit, boost | —                                      | —              | —                    | —     | No clean OCaml binding measured, or a heavy closure. Revisit after 1–2                                                                                                             |

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
  [`../design/enumeration/multi_lib.md` §2](../design/enumeration/multi_lib.md).

---

*Analysis based on opam-repository at `/home/red/code/contrib/opam-all/opam-repository`
and opam-source-archives at `/home/red/code/contrib/opam-all/opam-source-archives`.
Classification by grep heuristics on build sections + extra-source file
inspection. Scripts: `doc/canary/raw/classify_conf.sh`,
`doc/canary/raw/conf_revdeps.sh`.*

---

## G. Sampling the category groups (2026-08-20) — landing suitability, ranked

> Requested by the user: *"we can check 5 project in each group L12-19 in
> `conf_packages` and decide if they worth to land later. I also wish to
> check the category group with our package tag, to confirm they are
> aligned"*, then *"for the pkg-config or the version/help group, you can
> do 10 … you may also lightweight check if they are suitable for our
> landing … rank the package by their popularity, importance or rev-dep
> counts."*
>
> Everything below is MEASURED on 2026-08-20, not read off metadata
> summaries. Commands used per row: `opam list --depends-on <conf>
> --short --all-versions` (who binds it), `opam show <binding>
> --field=depends` (the gate), `opam show <binding> --field=all-versions`
> (is there a binding pair), `apt-cache madison <dev-pkg>` (the stable
> point), `api.anaconda.org/package/conda-forge/<lib>` (the latest point).

### G0. One correction to the raw data first

`doc/canary/raw/binding_packages.tsv` is **incomplete** — it lists 0
bindings for `conf-cairo`, which `cairo2` demonstrably depends on. Do not
rank from it. `opam list --depends-on` is the authoritative query and is
what every number below comes from.

### G1. The alignment check: the category and our gate are DIFFERENT axES

This was the question — *are the survey's category groups the same thing
as our `Canary_binding_decl.pm_dep_gate` tags?* Measured answer: **no, and
the reason is structural.** They sit on opposite sides of the conf package:

```
   binding  ──gate──▶  conf-*  ──category──▶  the system
   (pm_dep_gate:                 (survey category:
    how the BINDING                how the CONF PACKAGE
    constrains the conf)           probes the system)
```

Neither determines the other. The counter-examples are not exotic:

| conf package                        | survey category   | gate declared by its binding                        | agree? |
| ----------------------------------- | ----------------- | --------------------------------------------------- | ------ |
| conf-gmp / cairo / libssl / sqlite3 | pkgconfig         | `Free_with_conf`                                    | ✓      |
| **conf-libffi**                     | **pkgconfig**     | **`Bounded_with_conf {>= 2.0.0}`** (ctypes-foreign) | ✗      |
| conf-blas                           | compile_test      | free-at-build (`lacaml {build}`)                    | ✗      |
| **conf-sundials**                   | **compile_test**  | **`{>= "2" & build}`** (sundialsml)                 | ✗      |
| **conf-readline**                   | **no_build**      | **`{>= "1"}`** (readline)                           | ✗      |
| conf-boost                          | no_build          | free (gappa)                                        | ✗      |
| conf-ppl                            | compile_test      | free (jasmin)                                       | ✗      |
| conf-capnproto                      | version_check     | `{with-test}` — not a build gate at all (capnp)     | ✗      |
| conf-llvm-shared                    | custom_script     | `Fixed_with_conf {= "19"}` (llvm)                   | ✓      |
| **conf-libclang**                   | **custom_script** | **`{< "16"}`** (clangml)                            | ✓      |

The useful statement is therefore not "category = gate" but:

> A binding's version bound on a conf package reaches the LIBRARY only
> when that conf package's own check enforces a version. Measured, 13 of
> 370 do (§G1a); for the other ~357 the bound is over opam packaging and
> the true combination freedom is `Any_version`.

Which category a conf package is in does not answer that question — but it
does predict the SHAPE of the constraint when there is one: `pkgconfig`
carriers enforce floors, `custom_script` carriers enforce generations.

#### G1a. Where a conf package's version really does bound the library

A version bound on a conf package bounds the **C library** only if the
conf package's own check enforces a version. So we measured, across every
conf package's newest revision, which builds carry a version predicate.
**13 of 370 do, by two distinct mechanisms.** Reproduce with
[`../raw/conf_version_carriers.py`](../raw/conf_version_carriers.py)
(`python3 doc/canary/raw/conf_version_carriers.py`), which regenerates the
two tables below and is the answer to §G6 item 4:

**(i) A pkg-config version predicate — 8 packages, all in the
`pkgconfig` category.**

| conf package       | predicate                         | opam version | literal enforced | version corresponds?      |
| ------------------ | --------------------------------- | ------------ | ---------------- | ------------------------- |
| `conf-efl`         | `--atleast-version=1.8`           | 1.8          | 1.8              | ✓                         |
| `conf-gtk3`        | `--atleast-version 3.18`          | 18           | 3.18             | ✓ (the gtk3 minor)        |
| `conf-libblake3`   | `--atleast-version=1.5.1`         | 1.5.1        | 1.5.1            | ✓                         |
| `conf-libmd`       | `--atleast-version=1.0.0`         | 1.0.0        | 1.0.0            | ✓                         |
| `conf-libuv`       | `--atleast-version=1`             | 1            | 1                | ✓                         |
| `conf-taglib_c`    | `--atleast-version 2.0.0`         | 2            | 2.0.0            | ✓                         |
| `conf-zstd`        | `--atleast-version=1.3.8 libzstd` | 1.3.8        | 1.3.8            | ✓                         |
| `conf-openimageio` | `--atleast-version=2`             | **1**        | **2**            | ✗ — the convention breaks |

**(ii) The opam `version` variable passed into a discovery script — 5
packages, all in the `custom_script` category.**

| conf package       | how the version reaches the check                                                                              |
| ------------------ | -------------------------------------------------------------------------------------------------------------- |
| `conf-llvm`        | `["bash" "configure.sh" version]`                                                                              |
| `conf-llvm-shared` | `["bash" "configure.sh" version "shared"]`                                                                     |
| `conf-llvm-static` | `["bash" "configure.sh" version "static"]`                                                                     |
| `conf-libclang`    | `["bash" "-ex" "configure.sh" version]` — the opam file's own comment: *"pass pkg var '21' to test <= 21.0.x"* |
| `conf-qt`          | `["sh" "-ex" "./configure.sh" "%{version}%"]`                                                                  |

(`conf-cuda` matches mechanism (ii) by grep and is a false positive:
escaped quotes inside a heredoc desync a string stripper. Its build is a
plain compile test.)

> **Correction, recorded because the first version of this section was
> wrong.** An earlier pass reported "exactly 5 of 370, all
> `custom_script`" and concluded `custom_script ⟺ version-carrying`. That
> sweep stripped quoted strings before searching — which is right for
> finding the `version` VARIABLE and exactly wrong for finding a
> hardcoded literal, so it discarded all eight of mechanism (i). The
> error surfaced the moment a landing touched one: installing the `zstd`
> binding pulled `conf-zstd.1.3.8`, whose build is
> `pkg-config --atleast-version=1.3.8 libzstd`. A check that strips the
> evidence before looking for it is the same failure class as the landing
> lessons in [`../project/landing.md` §4](../project/landing.md) — the
> check ran, reported cleanly, and had nothing in front of it.

#### G1b. What the corrected measurement says

1. **Version-carrying is rare and bimodal.** 13 of 370 (3.5%) enforce a
   library version at all. The category does not predict *whether* a conf
   package carries a version — but it predicts the **shape**: all 8
   `pkgconfig` carriers are **floors** (`--atleast-version`, "new enough"),
   and all 5 `custom_script` carriers are **exact or bounded generations**
   (the LLVM/Qt family, where the version IS the package identity). Floors
   are almost free for us — every version we would pair is newer than a
   floor set years ago. Generations are the hard gate.
2. **The opam version corresponds to the enforced version in 12 of 13.**
   `conf-openimageio` is the counter-example (package 1, enforces 2), so
   the correspondence is a convention maintainers follow, not an invariant
   the format guarantees. Read the build; do not infer from the version.
3. **Everything else is a bare presence check.** ~197 of the 208
   `pkgconfig` packages run `pkg-config <lib>` with no predicate —
   `conf-zlib` and `conf-libffi` among them. For those, a version bound
   declared by a *binding* is over opam PACKAGING and constrains no
   library: `conf-libffi.2.0.0`'s entire build is `pkg-config libffi`
   while libffi itself is 3.x, so `ctypes-foreign`'s
   `conf-libffi {>= "2.0.0"}` forbids nothing about the C library.

That last point is the one with a consequence in code: our
`combination_freedom_of` answered `Within_bound ">= 2.0.0"` for libffi,
overstating the difficulty of its 2×2. `Bounded_with_conf` now carries
`tracks_lib`, and a packaging-only bound derives `Any_version`. See §G6.

#### G1c. A gate mechanism our datatype does not have

Searching for version logic *outside* the conf packages turned up one
package that gates itself:

```c
/* mlmpfr_compatibility_test.c.4.2.1 — shipped as an extra-source file */
#define MLMPFR_MPFR_VERSION_MAFOR 4
#define MLMPFR_MPFR_VERSION_MINOR 2
#define MLMPFR_MPFR_VERSION_PATCHLEVEL 1
  if (MPFR_VERSION_MAJOR >= … && MINOR >= … && PATCHLEVEL >= …) return 0;
  return 1;
```

```
build: [ ["cc" "mlmpfr_compatibility_test.c" "-lmpfr" "-o" …]
         ["./mlmpfr_compatibility_test"]           ← runs it; nonzero aborts the build
         ["dune" "build" "-p" name "-j" jobs] ]
```

`mlmpfr`'s opam dependency is a bare `"conf-mpfr"` — by metadata alone we
would tag it `Free_with_conf`, and we would be **wrong**: mlmpfr 4.2.1
refuses to build against mpfr 4.2.0. The gate is in the binding's own
build, and its opam version tracks mpfr's (mlmpfr.4.2.1 ↔ mpfr 4.2.1).

Two consequences. (1) `pm_dep_gate` needs a `Self_check_in_build`
constructor before mlmpfr can be declared honestly — recorded in
[`../project/issues.md`](../project/issues.md), not added speculatively
today (no live user yet). (2) mlmpfr becomes an unusually *attractive*
landing: its forward mismatch (new binding, old lib) is rejected by a check
the upstream package already ships, so the xfail is naturally occurring
rather than constructed — the first such case in the registry.

**Counting the mechanisms found so far**: a lib version can be enforced by
the conf package's pkg-config predicate (i), by the conf package's
discovery script (ii), by the binding's opam constraint on the conf
package (only meaningful over (i) or (ii)), or by the binding's own build
(mlmpfr). Four places. `opam show --field=depends` sees exactly one of
them.

### G2. pkg-config group — top 10 C libraries (208 packages, 135 are C libs)

Ranked by conf-package revdeps. `conf-pkg-config` itself (492) is
excluded: it is the tool, not a library.

| #   | conf pkg            | rev | binding (opam versions)                 | gate, measured                             | apt here               | conda-forge    | landing verdict                                                                                                                                                                                   |
| --- | ------------------- | --- | --------------------------------------- | ------------------------------------------ | ---------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | conf-ffmpeg         | 175 | `ffmpeg-avutil` (26) + 6 sibling pkgs   | `{build}` → free                           | libavutil 6.1.1        | 9.0.1          | **Skip for now** — 7 opam packages over one source tree and a large closure; the biggest revdep prize but not a first landing                                                                     |
| 2   | conf-gmp            | 129 | `zarith` — **landed**                   | free                                       | 6.3.0                  | 6.3.0 (7 vers) | calibration row                                                                                                                                                                                   |
| 3   | conf-zlib           | 56  | `camlzip` (4), `zlib` (2), `cryptokit`  | free (bare `"conf-zlib"`)                  | 1.3                    | **1.3.2**      | **Ready** — highest uncovered revdeps, closure is libc only, same soname                                                                                                                          |
| 4   | conf-gtksourceview  | 55  | `lablgtk-extras`, `why3-ide`, `frama-c` | (GTK stack)                                | —                      | —              | **Skip** — the GTK closure is tens of libs; the cairo lesson applies at 10×                                                                                                                       |
| 5   | conf-mpfr           | 49  | `mlmpfr` (11)                           | bare `"conf-mpfr"` **+ self-check (§G1b)** | 4.2.1                  | **4.2.2**      | **Blocked: model** — needs `Self_check_in_build`; then it is the best xfail candidate we have                                                                                                     |
| 6   | conf-gtksourceview3 | 44  | `lablgtk3-sourceview3` (5)              | `{build & >= "0"}` — a vacuous bound       | —                      | —              | **Skip** — same GTK closure                                                                                                                                                                       |
| 7   | conf-ncurses        | 36  | `curses` (9)                            | free                                       | **libncurses-dev** 6.4 | **6.6**        | **Ready\*** — note the conf package's declared deb name (`ncurses-dev`) is **not in this Ubuntu archive**; the real package is `libncurses-dev`. A stale depext is itself a finding worth landing |
| 8   | conf-libpcre        | 34  | `pcre` (22)                             | `{build}` → free                           | 8.39                   | **8.45**       | **Ready\*** — a genuine 8.39↔8.45 pair, but PCRE1 is EOL (8.45 was final, 2021); prefer `pcre2` if a conf exists                                                                                  |
| 9   | conf-sqlite3        | 30  | `sqlite3` — **landed**                  | free                                       | —                      | —              | calibration row                                                                                                                                                                                   |
| 10  | conf-libssl         | 26  | `ssl` — **landed**                      | free                                       | 3.0.13                 | **4.0.1**      | landed; the 3→4 prebuilt pair is the open soname case                                                                                                                                             |

Also in this group and worth naming: **conf-zstd (13)** → `zstandard` (5)
and `zstd` (3), both bare-`conf-zstd` free, apt 1.5.5 vs conda-forge
1.5.7 — the same clean shape as zlib.

### G3. Version/help group — top 10 (46 classified here; only 5 are C libs)

| #   | conf pkg                                                  | rev  | what it gates                          | C library? |
| --- | --------------------------------------------------------- | ---- | -------------------------------------- | ---------- |
| 1   | conf-npm                                                  | 96   | node's npm                             | no         |
| 2   | conf-perl                                                 | 92   | perl                                   | no         |
| 3   | conf-gcc                                                  | 66   | a C compiler                           | no         |
| 4   | conf-gnuplot                                              | 63   | gnuplot                                | no         |
| 5   | conf-g++                                                  | 61   | a C++ compiler                         | no         |
| 6   | conf-c++                                                  | 58   | a C++ compiler                         | no         |
| 7   | conf-git                                                  | 46   | git                                    | no         |
| 8   | conf-mingw-w64-gcc-*                                      | 28×2 | cross toolchains                       | no         |
| 9   | conf-rust-2021                                            | 23   | rustc edition                          | no         |
| 10  | conf-capnproto                                            | 15   | capnp — **the only ranked C lib here** | yes        |
| —   | conf-protoc 14, conf-bison 8, conf-flex 6, conf-libtool 5 |      | build tools that also ship a lib       | marginal   |

**Finding: this group is not a library group.** 41 of its 46 members gate
a *program* — a compiler, an interpreter, a code generator. Their revdep
counts are large because every package that shells out to `perl` or `npm`
declares one, which makes them look important in a ranking and useless as
canary projects: there is no lib artifact, no binding surface, no ABI.

The one real candidate, `conf-capnproto` → `capnp` (6 versions, apt 1.0.1
vs conda-forge 1.5.0), gates the conf package only `{with-test}` — i.e.
capnp does not need capnproto to *build*, only to run its tests. So even
here the lib is not on the binding's critical path. **Verdict for the
whole group: no landings.** Its value to us is diagnostic — it tells us
where the *toolchain* axis lives, which is a different study (`conf-gcc`
at 66 revdeps is the ecosystem's real compiler dependency).

A second finding, from the same measurement: `conf-capnproto`'s build is
`["capnp" "--version"]` — it *invokes* a version flag and then **ignores
the output**. Several members of this category are presence checks wearing
a version check's clothes. The classifier's grep saw `--version` and
grouped by it; that is honest labelling of the command, not of the
semantics.

### G4. The remaining four groups — 5 each

#### G4a. Compile test (28; 24 are C libs)

| conf pkg      | rev | binding                                         | gate                                           | pair available                          | verdict                                                                                                                                                                                           |
| ------------- | --- | ----------------------------------------------- | ---------------------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| conf-rdkit    | 46  | `fasmifra`, `linwrap`, `molenc`, `lbvs_consent` | (C++ cheminformatics)                          | —                                       | **Skip** — C++ template-heavy, no C ABI surface                                                                                                                                                   |
| conf-ppl      | 30  | `jasmin` (21)                                   | free                                           | apt 1.2 / cf 1.2 — **one version only** | **Blocked: no pair**                                                                                                                                                                              |
| conf-lapack   | 23  | `lacaml` (29)                                   | `{build}` → free                               | apt 3.12.0 / cf 3.12.1                  | **Ready\*** — a thin pair (patch-level), and BLAS/LAPACK's real axis is the *implementation* (reference vs OpenBLAS vs MKL), which is a provider axis we do not have. Interesting for that reason |
| conf-blas     | 22  | `lacaml` (shared with lapack)                   | `{build}`                                      | same                                    | see above — **one project, two conf packages**                                                                                                                                                    |
| conf-sundials | 14  | `sundialsml` (14)                               | `{>= "2" & build}` — **packaging-only** (§G1a) | apt 6.4.1 / cf **7.8.0**                | §G1a demonstration CONFIRMED, "Ready" **RETRACTED 2026-08-25**: this row failed §3b **step 3**. sundialsml's own `./configure` reads the lib version, aborts below 2.5.0, and version-adapts 472 C guards whose highest is `>= 600` — there is no 7.x path, and 6→7 breaks `SUNContext_Create`'s signature with no shared soname. A real pair, but a **mismatch** pair, not a green one. See [`../project/status_project.md`](../project/status_project.md) §1 D3 |

#### G4b. No build (18; 13 are C libs)

| conf pkg                            | rev    | binding                      | gate                        | verdict                                                                                           |
| ----------------------------------- | ------ | ---------------------------- | --------------------------- | ------------------------------------------------------------------------------------------------- |
| conf-boost                          | 21     | `gappa` (4), `ocsfml`, `qfs` | free                        | **Skip** — apt 1.83 vs cf 1.85 is a real pair, but Boost is header-heavy C++ with no stable C ABI |
| conf-lame / conf-ladspa / conf-dssi | 3 each | none measured                | —                           | **Skip** — no OCaml binding through the conf                                                      |
| conf-protoc-dev                     | 2      | —                            | —                           | **Skip**                                                                                          |
| conf-readline                       | 1      | `readline` (**1 version**)   | `{>= "1"}` — packaging-only | **Blocked: no pair** — the *binding* has one release ever; the 2×2's binding axis cannot exist    |

**Finding:** "no build" means the conf package is a pure depexts
declaration — it does not check anything at all. That is the weakest
possible guarantee (opam records an intent to have installed a system
package), and unsurprisingly it correlates with tiny revdep counts. As a
landing group it is empty.

#### G4c. Which/path check (9; **0 are C libs**)

`conf-which` (88), `conf-time` (47), `conf-liblinear-tools` (14),
`conf-wget` (4), `conf-sdpa` (4), `conf-libsvm-tools` (4),
`conf-timeout` (3), `conf-csdp` (3), `conf-rust-llvm` (0).

Every member locates an **executable**. Note `conf-liblinear-tools` and
`conf-libsvm-tools` — the *libraries* liblinear and libsvm exist, but what
opam checks for is the command-line drivers. **Verdict: no landings, by
construction.** The group is the tool axis again, and its top two entries
(`which`, `time`) are POSIX utilities, not dependencies in any interesting
sense.

#### G4d. Custom logic (9; 6 are C libs) — the group that actually gates versions

| conf pkg      | rev | binding                                | gate                                     | verdict                                                                                                                                                                                                                         |
| ------------- | --- | -------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| conf-cmake    | 102 | (build tool)                           | —                                        | tool axis                                                                                                                                                                                                                       |
| conf-libev    | 69  | `lwt` and 6 others — **as a `depopt`** | optional                                 | **Blocked: model** — needs the `Absent` provision wired into a universe + a combination policy (`../design/enumeration/multi_lib.md` §2)                                                                                                    |
| conf-llvm     | 26  | `llvm` — **landed**                    | `Fixed_with_conf`                        | calibration row                                                                                                                                                                                                                 |
| conf-libclang | 17  | `clangml` (25)                         | **`{< "16"}` — a REAL lib bound** (§G1a) | **Ready\*\*** — the only measured `Bounded_with_conf` whose bound reaches the library. An upper bound, so the interesting world is *new lib, old binding* — the backward direction, which nothing in the registry exercises yet |
| conf-qt       | 5   | —                                      | version-carrying                         | **Skip** — Qt closure                                                                                                                                                                                                           |

**Finding:** this 6%-of-the-repository group is where the HARD version
semantics live — every conf package that enforces a *generation* rather
than a floor (§G1a mechanism (ii)), both of our hard gates
(`Fixed_with_conf`, real `Bounded_with_conf`), and the optional-dependency
case. Floors also exist, but they live in `pkgconfig` (mechanism (i)) and
are nearly free for us. The survey's original judgement —
*"custom logic … NOT eliminable"* — understated it: these are not merely
unmechanizable, they are **the only conf packages that carry information
we cannot get from anywhere else**.

### G5. The ranked shortlist

Ranked by (uncovered revdeps × landing readiness). Rows already landed are
omitted. "Effective gate" applies §G1a — a packaging-only bound is free.

| rank   | project                                    | conf revdeps   | binding pair            | lib pair (stable → latest)   | effective gate                     | cost                                                                                     |
| ------ | ------------------------------------------ | -------------- | ----------------------- | ---------------------------- | ---------------------------------- | ---------------------------------------------------------------------------------------- |
| **1**  | **zlib / camlzip** — LANDED 2026-08-20 | 56 | camlzip 1.07→1.14 (4) | apt 1.3 → cf **1.3.2** | free | declaration only. Landed with a probe that names the library the loader mapped; the pair also turned out to carry a live ELF symbol-versioning gate (`ZLIB_1.3.1.2`) — see `conda_forge.md` |
| **2**  | **zstd** — LANDED 2026-08-20 | 13 | `zstd` 0.2→0.4 (3) | apt 1.5.5 → cf **1.5.7** | **`>= 1.3.8`, REAL** | declaration only. **Correction the landing forced**: this row read "no constraint" from the BINDING's bare `conf-zstd` dependency, but conf-zstd's own build is `pkg-config --atleast-version=1.3.8 libzstd` (§G1a mechanism (i)). Both points clear the floor, so it does not bite — but the gate is `tracks_lib = true`, not free. Use the `zstd` binding, not `zstandard` (which pulls the Jane Street core stack) |
| **3**  | **sundials / sundialsml**                  | 14             | 2.5.0p0→6.1.1p1 (14)    | apt 6.4.1 → cf **7.8.0**     | free at the CONF gate; **not free at the binding's own build** (§3b step 3, measured 2026-08-25) | declaration + the widest version gap in the table — but the gap crosses a break the binding does not implement, so the cross cells are xfails, and `libsundials-dev` is a 177-package install |
| **4**  | **ncurses / curses**                       | 36             | 1.0.3→1.0.12 (9)        | apt 6.4 → cf **6.6**         | free                               | declaration + a stale-depext finding to report                                           |
| **5**  | **libpcre / pcre**                         | 34             | 7.1.3→8.0.5 (22)        | apt 8.39 → cf **8.45**       | free                               | declaration; EOL lib, so prefer pcre2 if available                                       |
| **6**  | **libclang / clangml**                     | 17             | 0.5.1→4.8.0 (25)        | LLVM family                  | **`< 16` — real**                  | the first genuine lib-version bound; backward-direction world                            |
| **7**  | **mpfr / mlmpfr**                          | 49             | 3.1.6→4.2.1 (11)        | apt 4.2.1 → cf **4.2.2**     | free conf + **self-check**         | needs `Self_check_in_build`; best natural xfail                                          |
| **8**  | **postgresql**                             | 13             | 3.2.1→5.4.0 (24)        | **apt ships 16.2 AND 16.14** | `{build}` → free                   | the only lib whose pair is available *inside apt* — no conda-forge needed                |
| **9**  | **lapack+blas / lacaml**                   | 23+22          | 7.2.1→11.1.1 (29)       | apt 3.12.0 → cf 3.12.1       | free                               | thin pair; its real axis is implementation (reference/OpenBLAS), which we cannot express |
| **10** | **libcurl / ocurl**                        | 22             | 0.7.6→… (7)             | apt 8.5.0 → cf **8.21.0**    | **no conf dep at all** (Pattern B) | a different pattern: the binding finds curl itself                                       |
| —      | libev / lwt                                | 69             | —                       | —                            | depopt                             | blocked on the optional-dep model                                                        |
| —      | ffmpeg, gtksourceview(3), rdkit, boost, qt | 175/55/46/21/5 | —                       | —                            | —                                  | heavy closures / C++ / no C ABI                                                          |
| —      | ppl, glpk                                  | 30 / 6         | —                       | one version each             | free                               | no lib pair exists here                                                                  |
| —      | readline, mysql8                           | 1 / 11         | **one binding release** | —                            | —                                  | no binding pair exists                                                                   |

**Recommendation, unchanged in shape from §F3 but now with the evidence
behind it:** take **zlib** and **zstd** first (both pure declaration),
then **sundials** — because sundials is the row that *proves* §G1a: its
gate reads `{>= "2" & build}` and a naive reading would send us to build a
wrapper, while the measurement says the bound never reaches the library
and apt→conda-forge gives us 6.4.1 → 7.8.0 for free. Landing it converts a
survey claim into a run.

Two of the rows are worth landing for what they *break*, not for their
revdeps: **libclang/clangml** (the only real lib bound; an upper bound, so
it exercises the backward direction) and **mpfr/mlmpfr** (a gate that
lives in the binding's own build). Both need a model piece first, and both
are recorded in [`../project/issues.md`](../project/issues.md).

### G6. What this changes in the code

1. **`Bounded_with_conf` needs to say whether its bound reaches the lib.**
   Measured: only the 13 conf packages that enforce a version themselves
   (§G1a) make a binding's bound meaningful. Without that distinction
   `combination_freedom_of` answers `Within_bound` for libffi, where the
   truth is `Any_version`. → landed as a `tracks_lib` field, with the
   libffi declaration updated and a pin, falsified both ways.
2. **`Self_check_in_build` is missing** (§G1b, mlmpfr). Recorded as an
   issue, not added: no live user until mlmpfr lands.
3. **A version-bearing gate must name a version-carrying conf package.**
   The 13-member list is small and stable enough to hardcode as a
   `project-test` invariant: a declaration that sets `Fixed_with_conf`, or
   `Bounded_with_conf { tracks_lib = true }`, over a conf package outside
   it is a declaration bug. Not yet wired.
4. **The sweep is now re-runnable** —
   [`../raw/conf_version_carriers.py`](../raw/conf_version_carriers.py)
   regenerates the 13-member table from an opam-repository checkout. It
   searches both mechanisms with the OPPOSITE quote handling each needs,
   which is precisely what the first pass got wrong; the two false
   positives it had to learn to reject (a heredoc's escaped quotes, an
   opam comment saying "the CUDA version") are documented in the script
   rather than in anyone's memory.
