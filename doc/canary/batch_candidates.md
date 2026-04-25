# Plan: Canary target expansion candidates (2-tier dozen)

**Status:** living plan — tracks the expansion queue beyond the current
z3 / llvm / sqlite trio. Companion to [`opam_survey.md`](opam_survey.md)
(survey data) and [`pytorch_plan.md`](pytorch_plan.md), [`python_binding_plan.md`](python_binding_plan.md)
(per-target plans).

**Do not delete this file wholesale** — as candidates land, move them to a
"Done" section at the bottom (or delete individual rows); the file is the
queue view. Rewrite or retire entirely only when the two-tier framing is
superseded (e.g., by a proper template + config-driven catalog).

## Two-tier rationale

- **Tier 1 — Famous libraries with OCaml bindings.** Known far outside OCaml;
  the native library is the primary artifact, the OCaml binding is one of
  several language consumers. Canary's value here is multi-language and
  multi-PM interop.
- **Tier 2 — Widely-used OCaml bindings with tricky packaging.** The library
  isn't necessarily a household name, but the packaging (Pattern A/C, optional
  C deps, hybrid build) exposes structural cases canary should model well.

Picked from [`opam_survey.md`](opam_survey.md) §3 (revdep rankings) and §2
(pattern-complexity hot spots).

## Tier 1 — Famous libraries

| # | Library | OCaml binding | Pattern | Why it's interesting |
|---|---------|--------------|---------|---------------------|
| 1 | **Z3** ✓ | `z3` | C (self-build) | Done. SMT solver, source-built, OCaml + Python + C# + Java bindings. |
| 2 | **LLVM** ✓ | `llvm.19-shared` / `llvm.dev-shared` | A+C hybrid | Done. `conf-llvm-static` discovery + source build. `Opcode.UncondBr` drift demo. |
| 3 | **SQLite** ✓ | `sqlite3` | A | Done. Simplest Pattern A. Python `sqlite3` is stdlib-bundled (cross-PM edge case). |
| 4 | **PyTorch** | `torch` (opam) + `torch` (pip) | A (binary-only) | Queued in [`pytorch_plan.md`](pytorch_plan.md). pip × opam × apt libtorch matrix. Version range constraint `[2.1, 2.2)` is a real mismatch case. |
| 5 | **OpenSSL** ✓ | `ssl` via `conf-libssl` | A | Local 2026-04-25. OpenSSL 1.x → 3.x API breakage; macOS keg-only paths; Windows. Classic "C library that breaks everything." 3 revdeps — under-covered relative to real-world importance. CI pending. |
| 6 | **FFmpeg** | `ffmpeg-avcodec`, `ffmpeg-avformat`, `ffmpeg-swscale`, … | A (multi-pkg) | One `conf-ffmpeg` drives a family of binding packages. Tests canary's modelling of "one conf, multiple binding artifacts." 7 revdeps. |

## Tier 2 — Tricky OCaml bindings

| # | Library | OCaml binding | Pattern | Tricky-factor |
|---|---------|--------------|---------|---------------|
| 7 | **GMP** ✓ | `zarith` via `conf-gmp` | A | Local 2026-04-25. 25 revdeps — most-used Pattern A. Every numeric / crypto / verification pkg depends on it transitively. Template-worthy: if anything reveals the "standard" Pattern A shape, zarith does. CI pending validation. |
| 8 | **libev** | `lwt` (optional, via `conf-libev`) | A + optional | `depopts: conf-libev` + `%{conf-libev:installed}%` — canary tests "same binding with vs. without C dep". First real test of optional-C-dep modelling. |
| 9 | **cvc5** | `cvc5` | C (self-build) | SMT solver sibling of z3. Uses `conf-cmake` + `conf-g++` + `conf-gmp` — richer conf-set than z3. Second data point for the self-building template. |
| 10 | **bitwuzla** | `bitwuzla-c` + `bitwuzla-cxx` | C + A hybrid | Vendors the solver (self-build) but links system GMP via `conf-gmp`. Demonstrates the hybrid case that neither pure A nor pure C covers. |
| 11 | **MariaDB / MySQL** | `mariadb` via `conf-mariadb` | A+C hybrid | Database client lib; conf discovery + source build; cross-PM (apt libmariadb-dev vs brew mariadb-connector-c). Sibling to SQLite with a very different shape. |
| 12 | **cairo** | `cairo2` via `conf-cairo` (+ optional `conf-freetype`) | A + optional | 2D graphics; pkg-config discovery; `freetype` is a depopt. Same optional-dep pattern as lwt/libev but in graphics, and the choice changes runtime glyph rendering. |

## Sequencing recommendation

Ordered so that each addition compounds into the natural template shape
without committing to the template up-front:

1. **Finish batch-1 Python side** via [`python_binding_plan.md`](python_binding_plan.md)
   → sqlite stdlib (smallest), then z3-solver, then llvmlite.
2. **Add zarith (#7)** — first new-from-survey Pattern A. Hand-written spec
   ~300 lines, reveals what the Pattern A template needs.
3. **Add ssl or cairo2 (#5 or #12)** — second Pattern A datapoint. One with
   optional depopt, one without.
4. **Extract Pattern A template** from zarith + one-of (ssl, cairo2).
5. **Add lwt with depopt libev (#8)** — stresses the template with
   optional-dep; may require template extension.
6. **Add cvc5 (#9)** — Pattern C second datapoint; sibling to z3. Same
   exercise on the build-from-source side.
7. **PyTorch (#4)** — [`pytorch_plan.md`](pytorch_plan.md). Highest-leverage
   multi-PM case; lands after Python primitives + zarith-style Pattern A
   maturity.
8. **Remaining** — bitwuzla, mariadb, ffmpeg family, openssl — each uses
   template + adds one new trick (hybrid, multi-package, platform-specific).

## Intentional non-targets (for now)

- **`conf-zlib` / `camlzip`** (18 revdeps) — popular but not tricky; pure
  Pattern A with no interesting wrinkles. Good "10th-follower" once the
  template is solid.
- **`conf-ncurses` / `curses`** (4 revdeps) — terminal-UI; pattern is
  well-covered, low research interest.
- **Pattern D (invisible C stubs)** like `mirage-crypto`, `bigstringaf` —
  43 packages but canary has no leverage until source-inspection is in the
  toolkit (and even then, low priority — these rarely break).
- **npm depexts** (`reason-react` etc.) — cross-ecosystem but different
  toolchain; defer until a clear canary story for JS-side exists.
- **`owl` / `conf-openblas`** — interesting but multiple BLAS variants
  (OpenBLAS vs MKL vs Accelerate on macOS) push it to Tier 2.5 complexity;
  natural follower after PyTorch.

## Related plan docs

| Doc | Scope |
|-----|-------|
| [`opam_survey.md`](opam_survey.md) | Full survey of 4460 opam packages; pattern classification; revdep rankings (source of truth for candidate selection). |
| [`python_binding_plan.md`](python_binding_plan.md) | Adds Python-artifact primitives to canary; prereq for PyTorch and for any Python-binding probe in the candidate list. |
| [`pytorch_plan.md`](pytorch_plan.md) | Per-project plan for PyTorch (candidate #4). |
| [`artifact_summary_design.md`](artifact_summary_design.md) | Summary-generation design; every candidate needs watchlists declared here. |
| [`interface_contract_design.md`](interface_contract_design.md) | The interface/version model all candidates collectively stress-test. |

## How to consume this list

Before adding a candidate, write a per-project plan doc (like `pytorch_plan.md`)
covering:

1. **Which native library + which binding(s)** — explicit about artifact kinds.
2. **Install paths** per PM (apt/brew/opam/pip/conda).
3. **Watchlists** (native symbols, OCaml modules, Python attrs if applicable).
4. **Probe examples** — a small program that exercises the binding.
5. **Expected drift / failure cases** — what the `Expect_failure` catches.
6. **Open questions** that only surface during implementation.

After the project lands, move its row from the tier table to a "Done" section
below (or delete the row and update `CLAUDE.md`).

## Done

- #1 z3 — committed 2026-03 (Pattern C self-build; local runs + CI)
- #2 llvm — committed 2026-03 (A+C hybrid; local + CI)
- #3 sqlite — committed 2026-03 (Pattern A; local + CI)
- python primitives + pip probes for sqlite/z3/llvm — committed 2026-04-23/24 (local + CI)
- #7 zarith — committed 2026-04-25 (Pattern A; libgmp summary + zarith opam
  summary; surfaced summarize_native.py bug — was stripping leading `_` on
  Linux ELF too, mangling `__gmp*` GMP symbols. Fixed via
  `--strip-leading-underscore` flag passed only on macOS). CI green.
- #5 ssl — committed 2026-04-25 (Pattern A second datapoint; libssl
  summary + ssl opam summary; gotchas: (a) `Ssl.get_version` doesn't
  exist in opam ssl v0.7.0; example simplified to context construction
  only; (b) ssl doesn't pull ocamlfind transitively (uses dune-configurator)
  — fix landed in `fetch_binding_cmd` to install ocamlfind alongside
  every binding. Limitation: only summarises libssl; libcrypto needs
  probe_lib-as-list extension — noted as multi-native-lib gap). CI green.
- Pattern A template — extracted 2026-04-25 from zarith + ssl as the
  two-data-point validation predicted by step 4 of the sequencing.
  `canary_pattern_a.ml` (135 lines) compresses each Pattern A project
  spec to ~40 lines of declaration. Net: 226 → 86 lines across zarith
  and ssl (140-line reduction). Behavior verified identical pre/post
  refactor; CI YAML changes are cosmetic ($LIB_GMP / $LIB_SSL → unified
  $LIB_NATIVE).
