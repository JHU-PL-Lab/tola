# Canary projects — index

The project layer's home. Split 2026-08-12:

| file                                     | what it holds                                                                              |
| ---------------------------------------- | ------------------------------------------------------------------------------------------ |
| `index.md` (this)                        | the conceptual model (§1) + the candidate portfolio (§2)                                    |
| [`coverage.md`](coverage.md)             | **current coverage status** — per-project matrix + notes + landing history                  |
| [`landing.md`](landing.md)               | **how to land a project** — the workflow, data structures, and testing harness              |
| [`status_project.md`](status_project.md) | project **bugs, issues, and todo** — moved out of [`../status.md`](../status.md) §M3        |
| [`store_switching.md`](store_switching.md) | shared-store version switching — the opam survey + sequentialization plan                   |
| [`project_pytorch.md`](project_pytorch.md) | PyTorch multi-PM case study — pre-implementation plan for candidate #4                    |

Companion to [`../research/draft.md`](../research/draft.md) (manuscript) and
[`../research/surface_draft/`](../research/surface_draft/) (materials) for the
interface model the candidates collectively stress-test, and to the
[opam survey](../surveys/opam.md) (data behind the tier picks). The
**spec auto-generation plan** (#29/#32) is in
[`../backlog.md`](../backlog.md).

---

## 1. How canary describes a project — dimensions, not letters

canary describes each project by a few **orthogonal dimensions**, carried
as data in `store_config` (taxonomy in [`design/ssot.md`](../design/ssot.md)
§6.1). The opam-survey **"Pattern A–F"** ([opam survey](../surveys/opam.md)
§2) are an **ecosystem taxonomy** — what packages look like *in the wild*
— **not** canary's internal categories. They're just named points in this
space, and hybrids (e.g. bitwuzla = "A for discovery + C for building")
already break the letters. So throughout this doc we say what dimensions a
project *has*, and reserve A–F for describing opam.

| dimension             | values                                                                                                                  |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **native-lib origin** | `System` (distro pkg) · `Built` (canary compiles from source) · `Vendored` (inside the binding) · `Absent` (pure OCaml) |
| **lib discovery**     | `Conf` (conf-* / pkg-config) · `Depext` (direct depexts) · `Locator` (pkg-config/llvm-config/glob) · `n/a`              |
| **binding origin**    | `Opam` · `Built` (from the lib's source tree)                                                                           |

The survey letters are just points in this space:

| survey label           | dimensions                    |
| ---------------------- | ----------------------------- |
| A `conf-*` indirection | `{System, Conf, Opam}`        |
| B direct depexts       | `{System, Depext, Opam}`      |
| C self-building        | `{Built, n/a, Opam \| Built}` |
| D invisible C stubs    | `{Vendored, n/a, Opam}`       |
| E `clib:` tag          | `{System, clib, Opam}`        |
| F pure OCaml           | `{Absent, n/a, Opam}`         |

Two consequences:

- **A project isn't *in* a pattern; it *has* dimension values.** Pattern
  constructors (the former `canary_pattern_a`) are just sugar that fill a
  common combination — not categories anything branches on. B vs A is a
  single field value (`Depext` vs `Conf`) that barely changes how canary
  tests.
- **Provenance is a variant dimension.** The same library can run a
  `System` variant (conf-*) *and* a `Built` variant where canary fetches
  the source, compiles it, and generates its own conf-package pinned per
  version — letting canary check API compatibility more rigorously than
  the ecosystem's conf-* maintainers do. sqlite is the shipped case
  (`Fetched` alongside `Built@{3.45.1, 3.46.1}`); ssl is the natural next
  one. How this determines *which scenarios* each project covers — and
  marks the rest N/A — is part of the open "scenario" terminology
  question (tracked in [`../status.md`](../status.md) M2 "Canonical naming
  settle").

---

## 2. Portfolio — two-tier candidate framework

Picked from the opam survey §3 (revdep rankings) and §2 (pattern hot spots).

### Tier 1 — Famous libraries

Native library is the primary artifact; the OCaml binding is one of several
language consumers. Canary's value here is multi-language and multi-PM
interop coverage.

|    # | Library       | OCaml binding                         | Pattern         | Why interesting                                                                                                                         |
| ---: | ------------- | ------------------------------------- | --------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
|    1 | **Z3** ✓      | `z3`                                  | C (self-build)  | SMT solver, source-built, OCaml + Python + C# + Java bindings.                                                                          |
|    2 | **LLVM** ✓    | `llvm.{19,dev}-shared`                | A+C hybrid      | `conf-llvm-static` discovery + source build. `Opcode.UncondBr` drift demo.                                                              |
|    3 | **SQLite** ✓  | `sqlite3`                             | A (+ now Built) | Simplest Pattern A. Python `sqlite3` is stdlib-bundled (cross-PM edge case).                                                            |
|    4 | **PyTorch**   | `torch` (opam) + `torch` (pip)        | A (binary-only) | pip × opam × apt libtorch matrix. Version range `[2.1, 2.2)` is a real mismatch case. Plan: [`project_pytorch.md`](project_pytorch.md). |
|    5 | **OpenSSL** ✓ | `ssl` via `conf-libssl`               | A               | OpenSSL 1.x → 3.x API breakage; macOS keg-only paths. Classic "C library that breaks everything."                                       |
|    6 | **FFmpeg**    | `ffmpeg-{avcodec,avformat,swscale,…}` | A (multi-pkg)   | One `conf-ffmpeg` drives a family of binding packages. Tests "one conf, many binding artifacts."                                        |

### Tier 2 — Tricky OCaml bindings

Library isn't necessarily a household name, but the packaging exposes
structural cases canary should model.

|    # | Library             | OCaml binding                 | Pattern        | Tricky-factor                                                                                                           |
| ---: | ------------------- | ----------------------------- | -------------- | ----------------------------------------------------------------------------------------------------------------------- |
|    7 | **GMP** ✓           | `zarith` via `conf-gmp`       | A              | 25 revdeps — most-used Pattern A. Template-worthy.                                                                      |
|    8 | **libev**           | `lwt` (optional `conf-libev`) | A + optional   | `depopts: conf-libev` + `%{conf-libev:installed}%`. First real test of optional-C-dep modelling.                        |
|    9 | **cvc5**            | `cvc5`                        | C (self-build) | SMT solver sibling of z3. Richer conf-set (`conf-cmake` + `conf-g++` + `conf-gmp`).                                     |
|   10 | **bitwuzla**        | `bitwuzla-c` + `-cxx`         | C + A hybrid   | Vendors the solver but links system GMP via `conf-gmp`. The hybrid case neither pure A nor pure C covers.               |
|   11 | **MariaDB / MySQL** | `mariadb` via `conf-mariadb`  | A+C hybrid     | Database client; conf discovery + source build; cross-PM (apt vs brew). Sibling to SQLite, very different shape.        |
|   12 | **cairo** ✓         | `cairo2` via `conf-cairo`     | A + optional   | `freetype` is a depopt; same optional-dep pattern as lwt/libev but in graphics, choice changes runtime glyph rendering. |

### Sequencing recommendation

Each addition should compound into the natural template shape without
committing to the template up-front:

1. ✓ Finish batch-1 Python side — sqlite stdlib, z3-solver, llvmlite.
2. ✓ Add **zarith (#7)** — first new-from-survey Pattern A.
3. ✓ Add **ssl (#5)** — second Pattern A datapoint.
4. ✓ Extract **Pattern A template** (`canary_pattern_a.ml`) from zarith + ssl.
5. Add **lwt** with depopt **libev (#8)** — stresses the template with optional-dep.
6. Add **cvc5 (#9)** — Pattern C second datapoint; sibling to z3.
7. **PyTorch (#4)** — highest-leverage multi-PM case
   ([`project_pytorch.md`](project_pytorch.md)).
8. Remaining — bitwuzla, mariadb, ffmpeg family — each adds one new trick.

### Intentional non-targets

- **`conf-zlib` / `camlzip`** (18 revdeps) — popular but pure Pattern A
  with no interesting wrinkles. Good "10th follower" once template is solid.
- **`conf-ncurses` / `curses`** (4 revdeps) — well-covered pattern, low research interest.
- **Pattern D (invisible C stubs)** — `mirage-crypto`, `bigstringaf` etc. (43 packages).
  No leverage until source-inspection is in the toolkit.
- **`owl` / `conf-openblas`** — multiple BLAS variants (OpenBLAS / MKL / Accelerate)
  push it to Tier 2.5. Natural follower after PyTorch.


