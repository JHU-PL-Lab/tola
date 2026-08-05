# New project landing — portfolio, mechanics, case study

How canary expands its target coverage: which projects we're queueing,
how a project lands mechanically today, and what the future auto-generation
shape looks like. Companion to [../research/surface.md](../research/surface.md) (manuscript) and
[../research/surface_draft/](../research/surface_draft/) (materials) for the interface
model the candidates collectively stress-test, and the
[opam survey](../surveys/opam.md) (data behind tier picks).

---

## 0. How canary describes a project — dimensions, not letters

canary describes each project by a few **orthogonal dimensions**, carried
as data in `store_config` (taxonomy in [`ssot.md`](ssot.md) §6.1). The opam-survey
**"Pattern A–F"** ([opam survey](../surveys/opam.md) §2) are an
**ecosystem taxonomy** — what packages look like *in the wild* — **not**
canary's internal categories. They're just named points in this space,
and hybrids (e.g. bitwuzla = "A for discovery + C for building") already
break the letters. So below and in [projects.md](../projects.md) we say
what dimensions a project *has*, and reserve A–F for describing opam.

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
  the ecosystem's conf-* maintainers do. (ssl is the natural first case:
  `sys` alongside `src-<ver>` variants.) How this determines *which
  scenarios* each project/variant covers — and marks the rest N/A — is
  [`scenario_coverage.md`](scenario_coverage.md).

---

## 1. Portfolio — two-tier framework

Picked from the opam survey §3 (revdep rankings) and §2 (pattern hot spots).

### Tier 1 — Famous libraries

Native library is the primary artifact; the OCaml binding is one of several
language consumers. Canary's value here is multi-language and multi-PM
interop coverage.

|    # | Library       | OCaml binding                         | Pattern         | Why interesting                                                                                   |
| ---: | ------------- | ------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------- |
|    1 | **Z3** ✓      | `z3`                                  | C (self-build)  | SMT solver, source-built, OCaml + Python + C# + Java bindings.                                    |
|    2 | **LLVM** ✓    | `llvm.{19,dev}-shared`                | A+C hybrid      | `conf-llvm-static` discovery + source build. `Opcode.UncondBr` drift demo.                        |
|    3 | **SQLite** ✓  | `sqlite3`                             | A               | Simplest Pattern A. Python `sqlite3` is stdlib-bundled (cross-PM edge case).                      |
|    4 | **PyTorch**   | `torch` (opam) + `torch` (pip)        | A (binary-only) | pip × opam × apt libtorch matrix. Version range `[2.1, 2.2)` is a real mismatch case. See §4.     |
|    5 | **OpenSSL** ✓ | `ssl` via `conf-libssl`               | A               | OpenSSL 1.x → 3.x API breakage; macOS keg-only paths. Classic "C library that breaks everything." |
|    6 | **FFmpeg**    | `ffmpeg-{avcodec,avformat,swscale,…}` | A (multi-pkg)   | One `conf-ffmpeg` drives a family of binding packages. Tests "one conf, many binding artifacts."  |

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
|   12 | **cairo**           | `cairo2` via `conf-cairo`     | A + optional   | `freetype` is a depopt; same optional-dep pattern as lwt/libev but in graphics, choice changes runtime glyph rendering. |

### Sequencing recommendation

Each addition should compound into the natural template shape without
committing to the template up-front:

1. ✓ Finish batch-1 Python side — sqlite stdlib, z3-solver, llvmlite.
2. ✓ Add **zarith (#7)** — first new-from-survey Pattern A.
3. ✓ Add **ssl (#5)** — second Pattern A datapoint.
4. ✓ Extract **Pattern A template** (`canary_pattern_a.ml`) from zarith + ssl.
5. Add **lwt** with depopt **libev (#8)** — stresses the template with optional-dep.
6. Add **cvc5 (#9)** — Pattern C second datapoint; sibling to z3.
7. **PyTorch (#4)** — highest-leverage multi-PM case (see §4).
8. Remaining — bitwuzla, mariadb, ffmpeg family — each adds one new trick.

### Intentional non-targets

- **`conf-zlib` / `camlzip`** (18 revdeps) — popular but pure Pattern A
  with no interesting wrinkles. Good "10th follower" once template is solid.
- **`conf-ncurses` / `curses`** (4 revdeps) — well-covered pattern, low research interest.
- **Pattern D (invisible C stubs)** — `mirage-crypto`, `bigstringaf` etc. (43 packages).
  No leverage until source-inspection is in the toolkit.
- **`owl` / `conf-openblas`** — multiple BLAS variants (OpenBLAS / MKL / Accelerate)
  push it to Tier 2.5. Natural follower after PyTorch.

### Done

| #   | Project              | Landed     | Notes                                                                                                                                                                                        |
| --- | -------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | z3                   | 2026-03    | Pattern C self-build; local + CI                                                                                                                                                             |
| 2   | llvm                 | 2026-03    | A+C hybrid; local + CI                                                                                                                                                                       |
| 3   | sqlite               | 2026-03    | Pattern A; local + CI                                                                                                                                                                        |
| —   | python primitives    | 2026-04-23 | Sqlite/z3/llvm pip probes, both local + CI                                                                                                                                                   |
| 7   | zarith               | 2026-04-25 | Pattern A. Surfaced `inspect_native.py` GMP `__gmp*` stripping bug                                                                                                                           |
| 5   | ssl                  | 2026-04-25 | Pattern A second datapoint. `Ssl.get_version` doesn't exist in v0.7.0                                                                                                                        |
| —   | Pattern A template   | 2026-04-25 | `canary_pattern_a.ml` 135 lines compresses each spec to ~40 lines                                                                                                                            |
| —   | api-compat milestone | 2026-05-01 | `Expect_compat_failure` derived expectations for OCaml + Python; see [../research/surface_draft/implementation.md §2.7](../research/surface_draft/implementation.md)                         |
| 12  | cairo                | 2026-07-23 | Pattern A. First project onboarded on the post-redesign machinery (`Derived` fetch_lib via `store_config`; S5a detection runs). `cairo2` 0.6.5, 420 `cairo_` symbols; probe green first try. |
| —   | tiny-full            | 2026-08-02 | tiny-full becomes a PROJECT (peer of z3/sqlite), not a `tiny` subcommand. 6 spec-derived scenarios; forward API mismatch derived as `xfail[c1]`.                                              |
| 3   | sqlite → generic     | 2026-08-05 | sqlite gains a `Built` provision (canary compiles libsqlite3 from two amalgamation versions) and moves to `project_run`. 3 scenarios; Built worlds assert the runtime version.               |
| 1,2 | z3 + llvm → generic  | 2026-08-05 | A5: both move off raw `run_project_multi` onto `project_run` (`pr_spec` + `realize ∘ dispatch`). 2 scenarios each; their xfails are now *derived* and contract-attributed.                   |

---

## 2. Mechanics — adding a new project today

Each project lives in `src/canary/projects/canary_project_<name>.ml` and is
wired in `src/bin/canary_main.ml` and `src/canary/projects/canary_run.ml`.
There are three shapes, cheapest first:

- **Pattern A** (system lib + opam binding, no source build) — the
  `canary_pattern_a.ml` template brings each spec down to ~40 lines
  (`runner_spec` + `api_source`). zarith, cairo.
- **Raw `runner_spec`** — a hand-written spec per variant, run by
  `run_project_multi`. ssl only; not the shape to copy for new work.
- **`project_run`** (the generic path, and where new projects should
  land) — the project declares DATA: a `pr_spec` universe table
  (artifact × (provision × versions)), a `pr_provenance` provider table,
  and `pr_runner_spec = realize ∘ dispatch`. The general enumeration
  computes the scenario list; `run_project_run` executes it. tiny-full,
  sqlite, z3, llvm. See [`ssot.md`](ssot.md) §6.1 and
  [`dynamic_enumeration.md`](dynamic_enumeration.md).

Source-built projects are still the expensive ones — z3 ~600 lines, llvm
~470 — and A5 made their *shape* identical without yet sharing their
command templates (`status.md` §1c #6).

Per-project plan checklist (write this BEFORE implementation):

1. **Which native library + which binding(s)** — explicit about artifact kinds.
2. **Install paths** per PM (apt / brew / opam / pip / conda).
3. **Watchlists** — native symbols, OCaml modules, Python attrs.
4. **Probe examples** — a small program that exercises the binding.
5. **Expected drift / failure cases** — what `Expect_failure` (or
   `Expect_compat_failure`) catches.
6. **Open questions** that only surface during implementation.

After landing: move from the queue table to "Done" above and update
`CLAUDE.md`.

---

## 2.5 Scenario coverage — three levels, pick one

New projects choose *how much* scenario coverage they want.
Tiny is not the reference to copy; it's the framework's
own regression suite. Pick the level that matches the
project's purpose:

| Level                                    | What you write                                                                                                                             | Example                                                                                                                                              | When it's right                                                                                                                                                                 |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A. Positive-only**                     | `runner_spec` + `api_source` + probe examples that must build/run. No `Expect_compat_failure`.                                             | sqlite (system lib works; probe compiles)                                                                                                            | The project is a demo that a canary session terminates cleanly on a known-good setup. No version-mismatch or breakage story.                                                    |
| **B. A derived failure prediction**      | Level A + enough declared **evidence** (watchlists / `api_source`) for the shared lowering to find the break itself. Since A7 you do *not* hand-write the substring. | z3 (`parser_context` missing from the wheel → `xfail[c2]`), llvm (`Opcode.UncondBr` → `xfail[c2]`), ssl (`060_nlv` → `xfail[c2]`)                     | You want to demonstrate a real version drift on this project. Cheapest way to say "here's an API break canary *computed*".                                                       |
| **C. Scenario matrix**                   | Level B + a `pr_spec` universe declaring the provision/version axes; the general enumeration produces the scenarios.                       | tiny-full (6), sqlite (3), z3 / llvm (2 each)                                                                                                         | You want *systematic* coverage across an artifact's provision/version axes. No longer exotic — it is the default shape for a `project_run` project.                             |

**Do not copy tiny's workspace/prepare/baseline files.**
`canary_tiny_workspace.ml` + `_prepare.ml` + `_baseline.ml`
are framework infrastructure for driving tiny1's 22-scenario
mutation **oracle** through sandboxed builds — a *test harness* for the
framework itself, not a template. No level needs them: a Level C project
declares axes in its `pr_spec` and the general enumeration does the rest
(tiny-full, the project, is itself a `project_run` peer of sqlite — it
does not fork the factory).

**Effort ballpark** (per level, per project):

- **A**: ~40 LOC via `canary_pattern_a.ml` (Pattern A: system lib + opam binding), ~600 LOC hand-written for a source-built project (z3/llvm shape).
- **B**: A + the watchlist/`api_source` entries that carry the evidence — usually ~10-20 LOC, no expectation code.
- **C**: B + the `pr_spec` universe table + `realize ∘ dispatch` (sqlite: ~300 LOC including the from-source build; z3/llvm: the bulk is their build commands, not the scenario machinery).

For scenario mechanics + the derived-vs-hand principle see
[`dynamic_enumeration.md`](dynamic_enumeration.md).

---

## 3. Auto-generation plan (#29, ~~#30~~ shipped, #32)

Trigger: worth doing when project count reaches ~10. At 8 projects
(2026-08-05) the hand-written approach still holds, but #30 has since
shipped on its own and the `project_run` data-spec shape (§2) already
moved most of what §Step 3 wanted from code into declared tables — so
re-scope this section before acting on it.

The three pieces needed:

**Step 1 — `package_locator` as first-class type (#29).** Locator logic
(`llvm-config`, `pkg-config`, `brew --prefix`) is currently embedded as
ad-hoc shell in each project's `probe_lib`. Factor into:

```ocaml
type discovery_method =
  | Pkg_config of string          (* pkg-config --variable=libdir <name> *)
  | Llvm_config of string         (* llvm-config-N --libdir *)
  | Brew_prefix of string         (* $(brew --prefix <name>)/lib *)
  | Glob of string                (* ls /usr/lib/.../lib<name>.so* *)

type package_locator = {
  linux : discovery_method;
  macos : discovery_method;
}
```

`probe_lib` shell becomes derivable. `lib_locator` in
`canary_pattern_a.ml` is the prototype.

**Step 2 — `store_config` type (#30). ✅ SHIPPED** (S3, 2026-07-23;
`tool/canary_store_config.ml`). Artifact provenance is a typed `provider`
(`Sys_pkg` / `Lang_pkg` / `Source_repo` / `Vendored` / `Cached`), and
`fetch_lib` resolves as `Derived` from it instead of a hand-written
closure — adopted by sqlite + `pattern_a`, which lifted zarith/ssl/cairo
at once (S4a). z3/llvm/tiny keep `Raw` closures. The remaining half is
`fetch_binding`: `Derived` can't yet reproduce opam `install_args`
(`--assume-depexts`).

**Step 3 — auto-generated `runner_spec` (#32).** Given a sketch +
locator + store_config, generate the full `runner_spec`:

```ocaml
val mk_runner_spec_from_sketch :
  name:string ->
  locator:package_locator ->
  stores:store_config ->
  api_source:Canary_artifact_api.t ->
  source:source_repo ->
  unit -> runner_spec
```

Covers the Pattern A case. Source-build projects (z3, llvm) stay
hand-written but adopted `store_config` for their provider tables in A8.

---

## 4. Case study — PyTorch

PyTorch stresses canary's model in ways z3 / llvm don't:

1. **Same native library, many PMs.** `libtorch.so` ships via pip wheel,
   conda, homebrew, debian apt — each distributes nominally-the-same-
   version with potentially different build flags (CPU vs CUDA, compiler,
   glibc floor).
2. **Binary-only distribution.** Builds-from-source are rare and painful
   (~2 GB CUDA wheels). It's all "Pattern A with exotic locators."
3. **Strict version pinning.** opam `torch` declares
   `conflicts: libtorch { < 2.1.0 | >= 2.2.0 }`. pip's default is
   typically outside that range → classic cross-PM mismatch.
4. **Multiple library binaries.** `libtorch_cpu.so`, `libtorch_cuda.so`,
   `libc10.so`, `libc10_cuda.so` — surface needs to cover the set.

### Multi-PM matrix canary will exercise

| libtorch source     | Python torch | OCaml torch    | Expected result               |
| ------------------- | ------------ | -------------- | ----------------------------- |
| pip 2.5 (default)   | ✓ same wheel | fail           | ocaml conflicts 2.5 > 2.2     |
| pip 2.1.2           | ✓            | ✓              | happy path                    |
| pip CUDA wheel      | ✓ (on GPU)   | depends on ABI | libtorch_cpu vs libtorch_cuda |
| apt libtorch-dev    | Debian's old | fail           | debian version way too old    |
| manual download 2.1 | none         | ✓              | OCaml-only probe              |

Each row is one canary action variant; together they capture the full
"which combinations work" map.

### Watchlist seeds

- **Native (libtorch_cpu.so):** widely-used `at::Tensor::sum`, `at::empty`,
  `at::ones`, `c10::Device`, `c10::ScalarType`. Stability bellwethers
  (renamed/removed across 2.x): `at::native::_cudnn_*`, `at::quantized::*`.
  Expect a large `versioned_req` map (modern libstdc++, glibc).
- **Python (`torch`):** top-level `tensor`, `nn`, `optim`, `autograd`,
  `cuda`, `backends`, `jit`, `onnx`, `distributed`. Version markers:
  `torch.__version__`, `torch.version.cuda` (None on CPU wheel).
- **OCaml (opam `torch`):** top-level `Torch`, `Torch_core`,
  `Torch_vision` (depopt). Constructor-level skipped — compiled probe
  catches changes.

### Implementation order

1. **Variant 1** — pip-torch (Python-only, CPU wheel ~200 MB):
   `pip install torch --index-url …/cpu` → `import torch; …` probe.
   Native inspect on `site-packages/torch/lib/libtorch_cpu.so`,
   path discovered at runtime.
2. **Variant 2** — opam torch + pip torch interop: pip-install first,
   then `opam install torch`. Capture conflict-failure as
   `Expect_failure` with `version_info`.
3. **Variant 3** — opam torch + compatible libtorch: pin libtorch 2.1.x
   (opam-depext / URL pin), then `opam install torch`. Probe with a
   small `torch_example.ml` tensor op. Native + OCaml summaries.
4. **Multi-PM sweep** — execute the matrix above as the prize.

### Open questions (decide during implementation)

- **Wheel size in CI.** CPU wheel ~200 MB tolerable; CUDA ~2 GB → skip
  in CI, run locally.
- **`LIBTORCH` env var.** opam `torch` reads `LIBTORCH` to find the
  native lib. Probe shell must export it correctly per source.
- **Pip cache.** `~/.cache/pip` can be large; consider
  `actions/cache@v4` similar to sccache. Per-variant cache keys.
- **OCaml `torch` depopts.** `torchvision` is a depopt — test with and
  without.
- **Python venv vs system pip.** Isolate per variant with a venv to
  avoid cross-contamination. `Canary_pm_pip.ml` needs venv awareness
  (already a noted gap).

### Why high-leverage

- Forces the Python inspect pipeline beyond its "sqlite3 toy" comfort zone.
- Exposes multi-PM interop modelling needs before we over-abstract a template.
- Yields a concrete "here's a mismatch canary detected" story for the
  research narrative (version-range conflicts across PMs).
- Surfaces `LD_LIBRARY_PATH` / `LIBTORCH` env-injection patterns that
  recur for tensorflow, onnxruntime, etc. — PyTorch is the cheapest way
  to work through the pattern.

Scope estimate: ~250 lines of project spec + ~30 lines of Python
example + ~50 lines of `Canary_artifact_lang` updates for venv.
Heavier than typical (z3 ~600, llvm ~470) but PyTorch pulls its weight
as a multi-PM case.
