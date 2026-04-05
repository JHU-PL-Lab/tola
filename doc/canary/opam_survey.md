# opam Repository Survey: Native Library Binding Packages

Deep survey of the opam-repository (local clone) examining how packages handle
C/native library dependencies. Companion to [packaging_study.md](packaging_study.md).

Source: `/Users/ex/code/opam-all/opam-repository` (latest version per package only).

---

## 1. Scale

| Category                    | Count | Description                                |
| --------------------------- | ----- | ------------------------------------------ |
| Total package families      | 4460  | All top-level directories in `packages/`   |
| `conf-*` packages           | 333   | Virtual indirection packages               |
| `conf-*` for C libraries    | 205   | depexts mention `-dev` or `lib*` packages  |
| `conf-*` for tools          | 128   | Build tools, compilers, interpreters, etc. |
| `conf-*` using pkg-config   | 180   | Run `pkg-config <lib>` as their check      |
| C-involved packages (total) | 929   | Union of all categories below              |
| Presumed pure OCaml         | 3531  | No detectable C dependency                 |

### C-involvement breakdown (non-overlapping)

| Category                           | Count | How detected                                     |
| ---------------------------------- | ----- | ------------------------------------------------ |
| `conf-*` packages                  | 333   | Package name prefix                              |
| Depends on `conf-*` for C libs     | ~350  | `depends:` field (excluding tool-only conf deps) |
| Depends on `conf-*` for tools only | ~100  | `conf-c++`, `conf-cmake`, etc. but no C lib conf |
| Direct depexts (no `conf-*`)       | 91    | Has `depexts:` but no `conf-*` in `depends:`     |
| `clib:` tags (no `conf-*`)         | 18    | Has `clib:` tag but no conf dependency           |
| `dune-configurator` only           | 43    | Uses dune-configurator but no conf/depexts/clib  |

Note: some overlap exists (e.g., a package can have both `clib:` tags and
direct depexts). The 929 total is the deduplicated union.

## 2. Packaging Patterns

### Pattern A: `conf-*` indirection (standard)

The canonical opam pattern for C library bindings:

```
conf-sqlite3            ← virtual: runs pkg-config sqlite3, declares depexts
    ↓
sqlite3                 ← OCaml binding: builds C stubs, links to system lib
    ↓
caqti-driver-sqlite3    ← higher-level OCaml library
```

**How `conf-*` works** (e.g., `conf-sqlite3`):
- `build:` runs `pkg-config sqlite3` (or `pkgconf` on Windows)
- `depends:` on `conf-pkg-config`
- `depexts:` maps OS families to system package names:
  - `["libsqlite3-dev"] {os-family = "debian"}`
  - `["sqlite"] {os = "macos" & os-distribution = "homebrew"}`
  - `["sqlite-dev"] {os-distribution = "alpine"}`
  - ...etc for fedora, suse, nixos, freebsd, macports, cygwin
- `flags: conf`
- Installs nothing. Just verifies the system library is present.

**Examples of conf → binding pairs:**

| `conf-*` package  | Binding package(s)     | Library   | Reverse deps |
| ----------------- | ---------------------- | --------- | ------------ |
| `conf-gmp`        | `zarith`               | GMP       | 25           |
| `conf-zlib`       | `camlzip`, `zlib`      | zlib      | 18           |
| `conf-libev`      | `lwt` (optional)       | libev     | 9            |
| `conf-libssl`     | `ssl`                  | OpenSSL   | 3            |
| `conf-sqlite3`    | `sqlite3`              | SQLite3   | 3            |
| `conf-libffi`     | `ctypes-foreign`       | libffi    | 2            |
| `conf-libsodium`  | `sodium`               | libsodium | 1            |
| `conf-libpcre2-8` | `pcre2`                | PCRE2     | 1            |
| `conf-cairo`      | `cairo2`               | cairo     | 4            |
| `conf-gtk3`       | `lablgtk3`             | GTK+3     | 2            |
| `conf-ffmpeg`     | `ffmpeg-avcodec`, etc. | FFmpeg    | 7            |
| `conf-ncurses`    | `curses`               | ncurses   | 4            |
| `conf-openblas`   | `owl`                  | OpenBLAS  | 1            |
| `conf-boost`      | various                | Boost     | 4            |

**Binding package structure** (e.g., `sqlite3.5.3.1`):
- `depends:` on `conf-sqlite3 {build}`, `dune-configurator`
- `tags:` `["clib:sqlite3" "clib:pthread"]` — declares C lib requirements
- Builds OCaml stubs with `dune`, linking to system library
- Uses `dune-configurator` for compile flags (often via pkg-config)

### Pattern B: Direct depexts, no `conf-*` (~91 packages)

Packages that declare `depexts` directly without going through a `conf-*`
package. Less modular — the binding and the system dependency check are in
one package.

**B1. Binding with inline depexts** (~55 packages with C bindings):
- `lmdb` — bindings to LMDB, depexts for `liblmdb-dev`
- `argon2` — bindings to libargon2
- `geoip`, `glpk`, `libssh`, `kyotocabinet`, `magic`, `uring`, `yara`, `zbar`

These are typically smaller/niche libraries where nobody created a separate
`conf-*` package. The depexts coverage is often incomplete (e.g., only
Debian, missing Homebrew).

**B2. npm depexts** (Melange/Reason bindings to JS packages):
- `reason-react` — depexts: `react {npm-version = ^18.0.0}`
- `melange-jest` — depexts: `jest {npm-version = ^26.5.2}`
- `heroicons-reason-react` — depexts: `@heroicons/react {npm-version = ^2.2.0}`

These use the `npm-version` filter in depexts — a different dimension of the
cross-PM bridging problem. opam cannot auto-install these.

### Pattern C: Self-building / vendored C code (~30 packages)

Packages that build C/C++ code from their own source tarball. These depend
on build-tool conf packages (`conf-c++`, `conf-cmake`, `conf-gcc`, `conf-g++`)
but NOT on a C library conf package for the native library itself. The C
library source is either included in their tarball or fetched during build.

**This is how the `z3` opam package works.** It does NOT have a `conf-z3`.
Instead it depends on `conf-c++` and `conf-python-3` (build tools), downloads
the Z3 source, and builds the entire C++ solver + OCaml bindings from source.

**Full list of self-building packages (30 found):**

| Package           | conf deps (tools)                             | conf deps (C libs)                   | What it builds                         |
| ----------------- | --------------------------------------------- | ------------------------------------ | -------------------------------------- |
| `z3`              | conf-c++, conf-python-3                       | —                                    | Z3 SMT solver + OCaml bindings         |
| `z3_tptp`         | conf-g++                                      | —                                    | Z3 TPTP front end                      |
| `cvc5`            | conf-cmake, conf-g++, conf-gcc, conf-python-3 | conf-gmp                             | cvc5 SMT solver + OCaml bindings       |
| `bitwuzla-c`      | conf-g++, conf-gcc, conf-git                  | conf-gmp                             | Bitwuzla SMT solver (C API)            |
| `bitwuzla-cxx`    | conf-g++, conf-gcc, conf-git                  | —                                    | Bitwuzla SMT solver (C++ API)          |
| `bitwuzla-bin`    | conf-cmake, conf-g++, conf-gcc, conf-git      | conf-gmp                             | Bitwuzla executable                    |
| `llvm`            | conf-cmake                                    | conf-llvm-static                     | LLVM OCaml bindings (from LLVM source) |
| `binaryen-bin`    | conf-c++, conf-cmake, conf-ninja              | —                                    | Binaryen (WebAssembly)                 |
| `libbinaryen`     | conf-cmake                                    | —                                    | Binaryen library                       |
| `hacl-star-raw`   | conf-cmake, conf-which                        | —                                    | HACL*/EverCrypt bindings               |
| `gappa`           | conf-autoconf, ..., conf-g++                  | conf-gmp, conf-mpfr                  | Gappa theorem prover                   |
| `gmp-ecm`         | conf-autoconf, ..., conf-g++                  | conf-gmp                             | GMP-ECM library                        |
| `imguiml`         | conf-cmake                                    | conf-glew, conf-glfw3                | Dear ImGui bindings                    |
| `farmhash`        | conf-c++                                      | —                                    | Google FarmHash bindings               |
| `re2`             | conf-g++                                      | —                                    | Google RE2 bindings                    |
| `eprover`         | conf-gcc                                      | —                                    | E Theorem Prover                       |
| `liblinear`       | conf-g++, conf-gcc                            | —                                    | liblinear (vendored)                   |
| `libnlopt`        | conf-cmake                                    | —                                    | NLopt optimization library             |
| `mccs`            | conf-c++                                      | —                                    | MCCS (CUDF solver)                     |
| `batsat`          | conf-rust-2018                                | —                                    | BatSat SAT solver (Rust)               |
| `csdp`            | conf-gcc                                      | conf-lapack, conf-openblas           | CSDP SDP solver                        |
| `oranger`         | conf-cmake, conf-gnuplot                      | —                                    | Ranger random forests                  |
| `hdr_histogram`   | conf-cmake, conf-pkg-config                   | conf-zlib                            | HDR Histogram bindings                 |
| `class_group_vdf` | conf-g++, conf-gmp, conf-pkg-config           | —                                    | VDF bindings                           |
| `mariadb`         | conf-gcc                                      | conf-mariadb                         | MariaDB OCaml bindings                 |
| `ocsfml`          | conf-boost, conf-cmake                        | conf-sfml2                           | SFML game library bindings             |
| `unisim_archisec` | conf-g++, conf-gcc                            | —                                    | UNISIM-VP DBA decoder                  |
| `frama-clang`     | conf-cmake                                    | conf-clang, conf-libclang, conf-llvm | Frama-C Clang plugin                   |
| `goblint`         | conf-gcc                                      | conf-gmp, conf-ruby                  | Static analysis for C                  |
| `goblint-cil`     | conf-gcc, conf-perl                           | —                                    | CIL (C Intermediate Language)          |

**Key observations:**
- SMT solvers cluster here: z3, cvc5, bitwuzla all build from source
- Some are **hybrid**: use `conf-*` for one C lib (e.g., GMP) but vendor another
  (e.g., bitwuzla-c vendors bitwuzla but links to system GMP via conf-gmp)
- Some are **Rust** builds (batsat uses conf-rust-2018)

### Pattern D: Invisible C stubs (dune-configurator, no markers)

43 packages use `dune-configurator` (C compilation helper) but have no `conf-*`
deps, no depexts, and no `clib:` tags. These split into:

**D1. Vendored C bindings** (external C library compiled in-repo):
- `binaryen` — OCaml bindings for Binaryen (WebAssembly)
- `eigen` — Owl's OCaml interface to Eigen3 C++
- `llama-cpp-ocaml` — Ctypes bindings to llama.cpp
- `crlibm` — Binding to CRlibm
- `raygui` — OCaml bindings for raygui
- `extunix` — Collection of thin POSIX bindings
- `iomux` — IO Multiplexer bindings
- `posix-getopt` — Bindings for POSIX getopt

**D2. Internal C stubs** (own C code for performance, not binding external lib):
- `bigstringaf` — Bigstring intrinsics (memcpy/memmove stubs)
- `mirage-crypto`, `mirage-crypto-ec` — Crypto primitives in C
- `checkseum` — CRC/Adler32 implementations in C and OCaml
- `base` — Jane Street stdlib replacement (small C stubs)
- `parmap` — Multicore parallelism (fork/wait stubs)
- `multicont` — Multi-shot continuations (C runtime stubs)

D1 packages are invisible to any automated scan — they look like pure OCaml
packages from their opam metadata. Only reading their source reveals the
vendored C code.

### Pattern E: `clib:` tags without `conf-*` (18 packages)

Packages that declare C library requirements via `clib:` tags but don't
depend on a `conf-*` package. A halfway declaration — the tag documents the
C dependency but doesn't enforce it at install time.

Examples: `lmdb` (clib:lmdb), `jemalloc` (clib:jemalloc), `hdfs` (clib:hdfs),
`qbf` (clib:quantor, clib:qdpll, clib:picosat)

### Pattern F: Pure OCaml reimplementation (no C dependency)

Some packages avoid C bindings entirely:
- `tls` — pure OCaml TLS (replaces OpenSSL), uses `mirage-crypto`
- `git` (ocaml-git) — pure OCaml Git implementation (replaces libgit2)
- `digestif` — hash functions in pure OCaml
- `decompress` — zlib-compatible compression in pure OCaml

Primarily from MirageOS. Not relevant to canary C-binding testing.

## 3. Most-Depended `conf-*` Packages

### C library conf packages (by reverse dependency count)

| Rank | Package               | Rev deps | Library                   | pkg-config? |
| ---- | --------------------- | -------- | ------------------------- | ----------- |
| 1    | `conf-gmp`            | 25       | GMP (arbitrary precision) | Yes         |
| 2    | `conf-zlib`           | 18       | zlib (compression)        | Yes         |
| 3    | `conf-libev`          | 9        | libev (event loop)        | Yes         |
| 4    | `conf-python-3-dev`   | 8        | Python dev headers        | No          |
| 5    | `conf-linux-libc-dev` | 7        | Linux kernel headers      | No          |
| 6    | `conf-libseccomp`     | 7        | seccomp (sandboxing)      | Yes         |
| 7    | `conf-ffmpeg`         | 7        | FFmpeg (multimedia)       | Yes         |
| 8    | `conf-rdkit`          | 5        | RDKit (chemistry)         | No          |
| 9    | `conf-mpfr`           | 5        | MPFR (float precision)    | Yes         |
| 10   | `conf-ncurses`        | 4        | ncurses (terminal UI)     | Yes         |
| 11   | `conf-cairo`          | 4        | cairo (2D graphics)       | Yes         |
| 12   | `conf-boost`          | 4        | Boost C++                 | No          |
| 13   | `conf-sqlite3`        | 3        | SQLite3                   | Yes         |
| 14   | `conf-libssl`         | 3        | OpenSSL                   | Yes         |
| 15   | `conf-zstd`           | 3        | Zstandard (compression)   | Yes         |

### Tool conf packages (by reverse dependency count)

| Rank | Package           | Rev deps | Tool               |
| ---- | ----------------- | -------- | ------------------ |
| 1    | `conf-pkg-config` | 95       | pkg-config itself  |
| 2    | `conf-npm`        | 20       | npm (Node.js PM)   |
| 3    | `conf-perl`       | 19       | Perl               |
| 4    | `conf-autoconf`   | 19       | GNU autoconf       |
| 5    | `conf-which`      | 16       | which(1)           |
| 6    | `conf-gnuplot`    | 15       | gnuplot            |
| 7    | `conf-python-3`   | 14       | Python 3           |
| 8    | `conf-m4`         | 14       | m4 macro processor |
| 9    | `conf-gcc`        | 12       | GCC                |
| 10   | `conf-g++`        | 12       | G++                |
| 11   | `conf-cmake`      | 12       | CMake              |

**Key observation**: `conf-pkg-config` has 95 reverse deps — most
depended-upon conf package by far, confirming pkg-config's centrality.

## 4. Notable Case Studies

### Z3: Self-building (Pattern C)

The `z3` opam package (v4.14.1):
- No `conf-z3` exists
- `build:` runs `python3 scripts/mk_make.py --ml` then `make -C build`
- Downloads Z3 source and builds the entire C++ solver + OCaml bindings
- `depends:` on `zarith`, `conf-python-3`, `conf-c++` (build tools, not a C lib)
- `depexts:` only `python3-distutils` (build dep, not the library itself)
- `install:` manually copies `.cma`/`.cmxa` + `libz3.*` via ocamlfind

This is the heaviest build in the opam repo (compiles a full C++ project).
It depends on `conf-*` packages for build tools (`conf-c++`, `conf-python-3`)
but NOT for the C library it provides. This makes it invisible to a scan
that classifies packages by their `conf-*` dependencies.

### Bitwuzla: Hybrid self-building

`bitwuzla-c` (v1.0.5):
- Vendors the bitwuzla C++ solver (builds from source in its tarball)
- But also depends on `conf-gmp` for system GMP (doesn't vendor GMP)
- `conf-gcc`, `conf-g++`, `conf-git` for build tools
- Restricted `available:` — only Linux and macOS+Homebrew

This hybrid pattern is common among SMT solvers: vendor the solver, link
to system math libraries.

### LLVM: conf for discovery, source for building

The `llvm` opam package (v18-static):
- Depends on `conf-llvm-static` which checks for system LLVM installation
- But then builds OCaml bindings from the LLVM **source tarball** (downloads
  entire llvm-project source, uses CMake)
- Uses custom `install.sh` with `--llvm-config` from the conf package
- Patches `AddOCaml.cmake` for OCaml binding generation

Pattern A for discovery + Pattern C for building.

### torch: Optional native dep

The `torch` opam package (v0.17.0):
- `depopts:` `libtorch` (optional dependency, not required)
- `conflicts:` `libtorch {< "2.1.0" | >= "2.2.0"}` (strict version range)
- `post-messages:` on failure, explains how to install libtorch
- Uses `dune-configurator` + `ctypes-foreign` for FFI

Pattern where the C library is optional at opam level but required at runtime.

### mirage-crypto: Invisible C stubs (Pattern D2)

`mirage-crypto` (v2.0.0):
- Uses `dune-configurator`, no `conf-*`, no `depexts`, no `clib:` tags
- Contains vendored C implementations of crypto primitives
- From opam metadata alone, looks like a pure OCaml package
- Only visible as "has C code" by reading the source

### Melange/npm: Cross-ecosystem bridging

Packages like `reason-react`, `melange-jest` use npm depexts:
```
depexts: [ ["react"] {npm-version = ^18.0.0} ]
```
Extends depexts beyond system PMs to language PMs. opam cannot auto-install
these — they serve as documentation only.

## 5. Distinguishing Binding conf vs Tool conf

### The problem

A package depending on `conf-gmp` is binding to a C library.
A package depending on `conf-python-3` is using a build tool.
Both may appear with `{build}` — can we tell them apart?

### `{build}` does NOT distinguish them

`conf-sqlite3 {build}` (C library) and `conf-python-3 {build}` (tool) both
use `{build}`. This flag means "only needed during opam's build step" — which
is true for ALL conf packages since they install nothing. Even
`conf-gmp {build}` in cvc5 is for *linking* to GMP, not just a build tool.

### What does distinguish them

Classification must come from the **conf package's own metadata**, not from
how it is referenced in the depending package:

| Signal        | C library conf                                 | Tool conf                            |
| ------------- | ---------------------------------------------- | ------------------------------------ |
| Check method  | `pkg-config <lib>` or compile a test `.c` file | `which python3` or run a test script |
| depexts names | `libfoo-dev`, `foo-devel`                      | `python3`, `cmake`, `gcc`            |
| Synopsis      | "relying on ... lib"                           | "relying on ... installation"        |

Examples:
- `conf-gmp` compiles a `test.c` that `#include <gmp.h>` → C library
- `conf-python-3` runs `python3 test.py` → tool
- `conf-sqlite3` runs `pkg-config sqlite3` → C library
- `conf-cmake` runs `cmake --version` → tool

Our `conf_clib.txt` / `conf_tools.txt` split (matching `-dev`/`lib` in depexts)
is the right approach for automated classification. To determine if a binding
package uses a conf for linking vs tooling, cross-reference against those lists.

## 6. Optional Dependencies (`depopts`) and C Libraries

Only **23 packages** use `conf-*` in `depopts`. The mechanism is:

```
depopts: ["conf-libev"]
build: [
  ... "--use-libev" "%{conf-libev:installed}%" ...
]
```

The `%{conf-libev:installed}%` interpolation resolves to `true` or `false` at
build time. The build script conditionally enables/disables the C library
binding.

**Key examples:**

| Package      | Optional conf deps                                                      | Effect                                                               |
| ------------ | ----------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `lwt`        | `conf-libev`                                                            | Uses libev event loop if available, fallback to select/poll          |
| `bytesrw`    | `conf-xxhash`, `conf-zlib`, `conf-zstd`, `conf-libmd`, `conf-libblake3` | Each compression/hash backend is optional                            |
| `camlimages` | `conf-libpng`, `conf-libjpeg`, `conf-freetype`, `conf-libgif`           | Each image format is optional                                        |
| `cairo2`     | `conf-freetype`                                                         | Freetype text rendering is optional                                  |
| `torch`      | `libtorch` (not conf-*)                                                 | PyTorch backend; `conflicts:` constrains version to `[2.1.0, 2.2.0)` |
| `frama-c`    | `conf-gtksourceview3`                                                   | GUI is optional                                                      |
| `ocamlsdl`   | `conf-sdl-gfx`, `conf-sdl-image`, `conf-sdl-mixer`, `conf-sdl-ttf`      | Each SDL sub-library is optional                                     |

**Canary implication**: The same package can be installed with or without a
C library, producing different functionality. For canary testing, both
configurations should be tested (with and without the optional C dep).

## 7. Methodology and Reproducibility

**All categorization in this document is reproducible via script.**

The survey data is generated by [`doc/canary/raw/survey.sh`](raw/survey.sh), a
~275-line bash script that runs grep/awk heuristics over the opam-repository.
No LLM inference is used for any counts or categorizations.

To reproduce:
```bash
./doc/canary/raw/survey.sh /path/to/opam-repository doc/canary/raw
```

Each of the 9 steps in the script has inline `METHODOLOGY` and `KNOWN LIMITATIONS`
comments explaining the exact grep patterns used and their edge cases.

**What is scripted** (fully reproducible):
- Steps 1–9: all counts, all TSV/TXT data files, all package lists
- Pattern classification (A through F assignment) based on grep heuristics
- conf C-lib vs tool split (matching `-dev`/`-devel`/`lib` in depexts)

**What is editorial** (human-written, not scripted):
- Pattern D1 vs D2 sub-classification (vendored-binding vs internal-stubs) —
  requires reading package source code, not derivable from opam metadata
- The "Notable Case Studies" section (§4) — hand-selected examples
- The "Implications for the Canary" section (§9) — analysis and recommendations
- Prose descriptions and table annotations throughout

## 8. Discovery Method Distribution

| Method                  | Count (approx)            | Examples                                  |
| ----------------------- | ------------------------- | ----------------------------------------- |
| pkg-config              | ~180 conf + many bindings | conf-sqlite3, conf-libffi, conf-gmp       |
| Custom configure script | ~30                       | zarith (checks GMP paths directly)        |
| CMake find_package      | ~12                       | llvm, z3 (indirectly via mk_make.py)      |
| `which`/path check      | ~50                       | conf-which, conf-git, conf-cmake          |
| Header file check       | ~20                       | conf-fts, conf-linux-libc-dev             |
| Compiler test           | ~10                       | conf-c++, conf-gcc (compile test program) |
| None (vendored)         | ~30+                      | z3, binaryen, eigen, mirage-crypto        |

## 9. depexts Coverage Patterns

Most complete coverage (typical for well-maintained conf packages):

```
depexts: [
  ["libfoo-dev"]     {os-family = "debian"}    # Debian/Ubuntu
  ["libfoo-devel"]   {os-distribution = "fedora"}  # Fedora/RHEL
  ["libfoo-dev"]     {os-distribution = "alpine"}  # Alpine
  ["foo-devel"]      {os-family = "suse"}      # openSUSE
  ["foo"]            {os = "freebsd"}          # FreeBSD
  ["foo"]            {os = "macos" & os-distribution = "homebrew"}
  ["foo"]            {os = "macos" & os-distribution = "macports"}
  ["foo"]            {os = "win32" & os-distribution = "cygwinports"}
]
```

Incomplete coverage (common in Pattern B packages):
- Many only specify Debian
- Some only specify Alpine (common for Docker-oriented packages)
- Homebrew coverage varies — many packages omit it
- Windows/cygwin coverage is rare

## 10. Implications for the Canary

### What the canary already covers well
- Pattern A (conf + binding) for Z3 and SQLite
- System PM installation (apt/brew)
- Source builds (Z3's build-from-source pattern)

### Gaps identified

1. **Pattern C packages** (self-building): 30 packages vendor C/C++ code.
   The canary should test these — their build depends on system compilers
   and build tools, not on system C library versions.

2. **Pattern D packages** (invisible C stubs): 43 packages have C code that
   is invisible from opam metadata. These can break when compiler/OS ABI
   changes. Currently undetectable without source inspection.

3. **pkg-config as explicit test step**: 180 conf packages rely on pkg-config.
   The canary could add a pkg-config verification phase.

4. **Keg-only library resolution**: Many conf packages don't handle Homebrew
   keg-only paths. The canary should test whether `PKG_CONFIG_PATH` is
   correctly set for keg-only deps (sqlite, libffi, openssl).

5. **Version constraint patterns**: Some packages (torch, llvm) have strict
   version ranges on their C deps. The canary's version matrix should capture
   this.

6. **npm depexts**: The Melange/Reason ecosystem introduces cross-PM deps
   to npm. Not urgent but an interesting future direction.

7. **94% of conf-* packages are eliminable**: Build complexity analysis
   ([conf_package_analysis.md](conf_package_analysis.md)) shows that
   314 out of 333 conf packages are mechanical wrappers (pkg-config,
   version check, compile test, or empty). Only 19 have custom logic.
   A canary-native `conf-sysdep` mechanism could replace most conf
   packages with typed declarations, reducing the dependency on the
   opam-repository for system dep verification.

8. **Reverse dep distribution is heavily skewed**: 41% of conf packages
   have 0 or 1 reverse dep (median = 2, mean = 10.9). One-to-one
   conf→binding pairs could inline their check. The most complex conf
   packages (custom_script) have the highest mean reverse deps (25.3)
   — they're both the hardest to replace and the most impactful.
   See [raw/conf_revdeps_classified.md](raw/conf_revdeps_classified.md).

9. **Version resolution chain**: The seam between system PM, locator
   tool (pkg-config/llvm-config), conf package, and lang binding is
   where mismatches happen. See "Version Resolution Chain" in
   [design.md](design.md). Canary should test each seam independently.

## 11. Data Files

Raw survey data saved in `doc/canary/raw/`:

| File                       | Contents                                                |
| -------------------------- | ------------------------------------------------------- |
| `conf_survey.tsv`          | All 333 conf-* packages with pkg-config/depexts flags   |
| `conf_clib.txt`            | 205 C library conf package names                        |
| `conf_tools.txt`           | 128 tool conf package names                             |
| `conf_clib_detail.tsv`     | C lib conf packages with debian/brew depext names       |
| `binding_packages.tsv`     | 452 packages depending on conf-*, with their conf deps  |
| `direct_depexts.tsv`       | 91 packages with depexts but no conf-* dependency       |
| `builds_c_from_source.tsv` | 30 packages using C/C++ build-tool confs                |
| `dune_conf_no_markers.tsv` | 43 packages with dune-configurator but no other markers |
| `clib_no_conf.tsv`         | 18 packages with clib: tags but no conf-* dependency    |
| `conf_revdeps_classified.tsv` | All 370 conf-* packages: revdep count, category      |
| `conf_revdeps_classified.md`  | Same as above, formatted as markdown table            |

### Scripts

| Script                     | Purpose                                                 |
| -------------------------- | ------------------------------------------------------- |
| `survey.sh`                | Main survey: counts, TSV data files, package lists      |
| `classify_conf.sh`         | Classify conf-* by build complexity (pkg-config, version check, compile test, custom script, etc.) |
| `conf_revdeps.sh`          | Count reverse deps per conf-* package, merge with classification |

To reproduce:
```bash
# Main survey (from original mac repo or local clone)
./doc/canary/raw/survey.sh /path/to/opam-repository doc/canary/raw

# Build complexity classification
bash doc/canary/raw/classify_conf.sh /path/to/opam-repository/packages

# Reverse deps + classification merge
bash doc/canary/raw/conf_revdeps.sh /path/to/opam-repository/packages
```

See also: [`conf_package_analysis.md`](conf_package_analysis.md) for the
detailed analysis of build complexity and eliminability.

---

*Survey based on opam-repository at `/home/red/code/contrib/opam-repository`
(restored from git). Only latest version per package examined. Counts are
approximate due to heuristic categorization (matching `-dev`/`lib` in
depexts for C lib detection, grep patterns on build sections).*
