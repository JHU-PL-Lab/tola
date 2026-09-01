# How an OCaml package says WHICH native library to use

> 2026-09-01, prompted by torch (user: *"we need to figure out how to
> specify which system package to use for an ocaml package"*). Sibling of
> [`conf_mechanism.md`](conf_mechanism.md), which explains the conf-\*
> route and states the position on it. This doc is the COMPARISON:
> conf-\* is one mechanism, and torch uses a different one that the
> registry had not met before. Everything below was measured on
> 2026-09-01 unless dated otherwise.

## 1. The question

A binding needs a C library. Two things must happen: the library must be
PRESENT, and the build must be told WHICH one when more than one could
answer. opam's conf-\* packages address the first and mostly punt on the
second. Whoever wants the second has to read what the binding's own build
does.

## 2. Mechanism A — conf-\*, opam-mediated

Nine of the eleven registry projects. `zarith` depends on `conf-gmp`;
opam resolves the virtual package, whose `build:` runs a presence test
and whose `depexts:` maps to per-distro system packages. Details in
[`conf_mechanism.md`](conf_mechanism.md).

### 2a. Is a conf-\* package necessarily virtual? — no, but nearly

`flags: conf` is a MARKER, not an enforcement. What opam's manual gives
it is packaging semantics: a conf package is understood to test for an
external dependency rather than to install OCaml code, and tools treat it
as such. It does not forbid an `install:` field. Measured:

| package | `flags: conf` | installs anything? |
| --- | --- | --- |
| `conf-gmp` | yes | no — `build:` is the test, `depexts:` the map |
| `conf-zlib` | yes | no — `pkg-config` presence test only |
| `conf-libssl` | yes | **YES**, conditionally: `install: ["sh" "-ex" "./homebrew.sh" "install" lib] {os-distribution = "homebrew"}` |

So the honest statement is: a conf package **declares** an external
dependency and normally installs nothing, but `conf-libssl` shows one
running an install script on Homebrew. Treat "virtual" as the convention,
not the definition.

**Is it a conversion?** Yes, and that is the useful way to see it. A
conf-\* package converts *"this opam package needs library L"* into
*"this OS needs system package P"*, via `depexts:` keyed on
`os-family` / `os-distribution`. The conversion is one-way and lossy: it
carries presence and a distro package NAME, but not a version and not a
choice. That is precisely why it cannot answer §1's second question.

## 3. Mechanism B — the binding's own configurator, driven by env

torch. There is no conf package for libtorch at all (searched: opam has
`libtorch` and `torch`, no `conf-torch`, no `conf-libtorch`).
`src/config/discover.ml` is a `dune-configurator` program that runs at
build time and tries FOUR routes in order, taking the first that answers:

| # | route | trigger | resolves to |
| --- | --- | --- | --- |
| 1 | **explicit directory** | `LIBTORCH=<dir>` | `<dir>/include`, `<dir>/lib` |
| 2 | **system** | `LIBTORCH_USE_SYSTEM=1` | bare `-lc10 -ltorch_cpu -ltorch`, no `-L`/`-isystem` |
| 3 | **conda / wheel** | `CONDA_PREFIX` set | `$CONDA_PREFIX/lib/python*/site-packages/torch` |
| 4 | **opam** | `OPAM_SWITCH_PREFIX` (always set) | `$prefix/lib/libtorch` |

Route 1 emits `-Wl,-rpath,<lib_dir> -L<lib_dir>`, so the choice is baked
into the built binding rather than left to the loader.
`LIBTORCH_CXX11_ABI` (default `1`) selects the ABI independently.

Three consequences:

- **Route 4 is the LAST fallback and the only one that fires with no
  environment set.** Canary landed on opam's libtorch by absence of a
  choice, not by making one.
- **Selection is by ENV AT BUILD TIME, not by a dependency.** opam is
  never told which library was used and `opam list` cannot report it. The
  only record is inside the built artifact — which is why torch's probe
  prints the mapped path and `build-version` rather than trusting a
  declaration.
- **The bound is enforced somewhere else entirely.** torch's opam file
  carries `conflicts: ["libtorch" {< X | >= Y}]`, checked by the SOLVER
  at resolution time — but only against the opam *package*. A libtorch
  supplied by route 1, 2 or 3 is invisible to it. You can satisfy the
  solver and build against a library it never approved.

## 4. Who actually provides libtorch

The user's question — why is there no apt package, and what about brew
and other distros. Measured:

| channel | provides it? | newest | note |
| --- | --- | --- | --- |
| **apt (Ubuntu)** | **no** | — | no `libtorch`/`libtorch-dev`/`libtorch2`; `python3-torch` has no candidate |
| **Homebrew** | **yes**, as `pytorch` | **2.13.0** | builds from source, then symlinks `include/`, `lib/`, `share/cmake` into the prefix |
| **Arch** | **yes**, as `python-pytorch` (extra) | **2.13.0** | |
| **conda-forge `libtorch`** | yes | **2.13.0** | see §4a |
| **pip `torch` wheel** | yes, bundles its own | **2.13.0** | co-provider, §6 |
| **download.pytorch.org** | yes, authoritative | **2.13.0** | Linux x86_64 + macOS arm64 |
| **opam `libtorch`** | yes, but see §5 | **2.2.1** | eleven releases behind |

So "no system package" was a Debian/Ubuntu fact, not a general one.
Homebrew and Arch both ship it, both current — and Homebrew's layout
(headers + libs + cmake config in the prefix) is exactly what discover.ml
route 1 or 2 expects, so **macOS has a working system route that Ubuntu
does not**. That inverts the usual asymmetry, where Linux is the
well-served platform.

Naming trap, measured: the official Linux archive was renamed. Old is
`libtorch-cxx11-abi-shared-with-deps-<V>+cpu.zip`; from ~2.9 it is
`libtorch-shared-with-deps-<V>+cpu.zip` — the `cxx11-abi-` infix went
away when the pre-C++11 ABI was retired. 2.3.1 exists only under the old
name, 2.9.1 only under the new. macOS keeps `libtorch-macos-arm64-<V>.zip`
throughout. Both have a `-latest.zip`.

### 4a. conda-forge variants

The version matches upstream (2.13.0), but conda-forge splits it into
BUILD variants that the official zips do not have:

| subdir | builds at 2.13.0 | example build strings |
| --- | ---: | --- |
| linux-64 | 18 | `cpu_generic_h192dfd4_0`, `cpu_mkl_…` |
| linux-aarch64 | 12 | `cpu_generic_h79c006f_0` |
| osx-64 | 6 | `cpu_generic_h8f53a83_2` |
| osx-arm64 | 3 | `cpu_generic_h1a3d9a1_0` |
| win-64 | 9 | `cpu_mkl_hb008cf6_102` |

The build string encodes the compute backend (`generic` vs `mkl`) and a
build number. Two things follow: conda-forge covers **linux-aarch64**,
which the official Linux zip does not; and it is the only channel where
"same version, different build" is a real axis — which is exactly the
shape [`../project/landing.md`](../project/landing.md) §3 warns about
when it says to record the build number, not just the version.

## 5. opam's `libtorch` is a vendored binary wearing a package

Its whole definition:

```
extra-source "libtorch-linux.zip" {
  src: "https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-2.2.1%2Bcpu.zip" }
install: ["sh" "-c"
  "test -d %{lib}%/libtorch/lib/libtorch.so || ( unzip libtorch-linux.zip && mv -f libtorch %{lib}%/ )"]
```

It is the SAME archive canary downloads for a `Vendored` world, moved
into the switch and given an opam version label. That is why it is not a
good stable point: it is not a system package, it tracks nothing, and its
newest is 2.2.1 while upstream is 2.13.0.

It is not alone. opam carries a small family of `lib<pkg>` packages that
ship prebuilt binaries rather than build from source —
`libtorch`, `libwasmer`, `libwasmtime` on inspection; `libtensorflow`,
`libbinaryen`, `libsvm`, `liblinear`, `libnlopt`, `libbpf` build from
source instead. The prebuilt ones are worth knowing as a pattern: an
opam package whose provision is really `Vendored`, which canary's
`provider` vocabulary currently records as `Lang_pkg`.

### 5a. The torch × libtorch table, and a mechanism change

| torch | how it names libtorch | window |
| --- | --- | --- |
| 0.9 | `depends` | `= 1.5.0` |
| 0.10 | `depends` | `= 1.6.0` |
| 0.11 … 0.15 | `depends` | successive `1.x` ranges |
| 0.16, 0.17 | `depends` | `>= 1.12.0 < 1.13.0` / `>= 1.13.0 < 1.14.0` |
| v0.16.0 | `depends` | `>= 1.13.0 < 1.14.0` |
| **v0.17.0** | **`depopts` + `conflicts`** | `< 2.1.0 \| >= 2.2.0` forbidden |
| our fork | `depopts` + `conflicts` | `< 2.3.0 \| >= 2.4.0` forbidden |

The mechanism CHANGED at v0.17.0. Up to v0.16.0, libtorch was a hard
`depends` with a range: opam had to install a matching one, and the
guarantee was opam's. From v0.17.0 it is `depopts` plus a `conflicts`
clause: opam installs nothing and only forbids a wrong one **if present**.
The newer packaging is strictly WEAKER — it moved the guarantee out of
the package manager and into the environment, which is what makes §3's
last bullet possible.

Against the installable libtorch versions (`1.13.0+linux-x86_64`,
`2.0.0`, `2.1.2`, `2.2.1` for linux; macOS stops at `2.0.0+macos-x86_64`,
**no arm64 at any version**), only `torch.0.17` / `v0.16.0` (1.13.x) and
`torch.v0.17.0` (2.1.2) can be satisfied through opam at all.

## 6. Co-providers — what canary supports today

A co-provider is one package that delivers BOTH the native library and
the binding: the pip `torch` wheel, `z3-solver`, llvmlite. Canary
declares it and derives one consequence from it:

- **Declaration**: `Canary_store_config.Lang_pkg { self_contained : bool }`.
  Live on sqlite's python row, z3's, llvm's.
- **Derivation**: `dep_mode_of_provider` maps `self_contained = true` to
  `Some (Ambient "bundled lib (<pkg>)")` — the runtime edge is declared
  AMBIENT, i.e. the run provider is outside the enumeration entirely.
- **A second vocabulary** says the same thing on the gate side:
  `Canary_binding_decl.Bundled` (llvm uses `Bundled "llvmlite wheel's
  bundled libLLVM"`).
- **Measured effect**: z3's `parser_context` xfail fires identically in
  both lib chains, because the wheel's bundled libz3 never varies with the
  lib axis. That scenario-invariance IS the co-provider behaviour, and it
  is observed rather than asserted.

What is NOT supported (backlog #45, still open): the diagram draws a
`lib -.->|runtime|` edge into the python nodes that a co-provider does not
have, and `derive_steps` still models python bindings as depending on the
native lib. Both are the same fix — read `dep_mode` instead of assuming.

For torch specifically the pip wheel would be route 3, and it is the one
route where the co-provider and the selection question coincide: setting
`CONDA_PREFIX` points the OCaml binding at the *Python* package's bundled
library, so one artifact serves two ecosystems. That is worth a scenario
and is not one yet.

## 7. What this means for the model

`Canary_store_config.provider` records WHERE an artifact comes from
(`Sys_pkg` / `Lang_pkg` / `Vendored`). torch shows a second, independent
question: **how is the consumer told**. Under mechanism A it is implicit
(the distro's linker path); under mechanism B it is an env variable the
realization must set, and the four routes map almost one-to-one onto
provisions:

| discover.ml route | canary provision | who supplies it |
| --- | --- | --- |
| `LIBTORCH=<dir>` | `Vendored` | upstream zip, conda-forge archive |
| `LIBTORCH_USE_SYSTEM=1` | `Fetched` (system PM) | brew `pytorch`, Arch `python-pytorch` |
| `CONDA_PREFIX` | `Fetched` (pip/conda) | the wheel — co-provider, §6 |
| `OPAM_SWITCH_PREFIX` | `Fetched` (opam) | opam `libtorch` — §5, and stale |

This is a strong hint that "how the consumer is pointed" belongs in the
declaration rather than hand-written per project. ONE specimen is not
enough to design against, so it is recorded and not built. The second
specimen to look for is any binding whose `dune-configurator` reads an
env var — llvm's `LLVM_CONFIG` is close but is a locator BINARY, not a
directory.

## 8. Practical answers, for torch

- **Choose the library**: `LIBTORCH=<dir>` before `opam install torch`,
  and keep opam's `libtorch` uninstalled (route 4 is unreachable anyway,
  but its `conflicts:` can still block the solver).
- **Use the system's**: `LIBTORCH_USE_SYSTEM=1` — viable on macOS/brew
  and Arch, not on Ubuntu.
- **Neither is recorded by opam**, so verify against the built artifact
  (the mapped path and `build-version`), never against the switch.
