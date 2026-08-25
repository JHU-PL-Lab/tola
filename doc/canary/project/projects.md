# Canary projects — the roster

What exists, what each project covers, and what is queued next. Merged
2026-08-21 from the former `index.md` (model + candidates) and
`coverage.md` (status matrix + landing history), which said the same
things about the same projects in two places.

Siblings: [`status_project.md`](status_project.md) is THE to-do tracker
for this layer (nothing here is a to-do); [`landing.md`](landing.md) is
how to land one; [`issues.md`](issues.md) is the open per-project
worklist. Data behind the candidate picks: the
[opam survey](../surveys/opam.md) and the measured
[conf-* survey](../surveys/conf_packages.md) §G.

---

## 1. How canary describes a project — dimensions, not letters

Each project is described by **orthogonal dimensions**, carried as data
in `store_config` (taxonomy in [`design/ssot.md`](../design/ssot.md)
§6.1). The opam survey's **"Pattern A–F"** are an *ecosystem* taxonomy —
what packages look like in the wild — **not** canary's internal
categories; hybrids (bitwuzla = "A for discovery + C for building")
already break the letters.

| dimension             | values                                                                                                                  |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **native-lib origin** | `System` (distro pkg) · `Vendored` (a prebuilt we place) · `Built` (canary compiles from source) · `Absent` (pure OCaml) |
| **lib discovery**     | `Conf` (conf-* / pkg-config) · `Depext` (direct depexts) · `Locator` (pkg-config/llvm-config/glob) · `n/a`              |
| **binding origin**    | `Opam` · `Built` (from the lib's source tree, or from the binding's own repo)                                           |

Two consequences:

- **A project isn't *in* a pattern; it *has* dimension values.** The
  ocaml/opam-binding template (`Canary_opam_binding`, the former
  "Pattern A") is sugar that fills a common combination — not a category
  anything branches on. B vs A is one field value (`Depext` vs `Conf`).
- **Provenance is an axis, not a fact.** The same library runs as
  `System` in one scenario and `Vendored`/`Built` in another — that axis
  IS the 2×2's lib side (§2).

---

## 2. The roster

Ten projects on the registry (`Canary_registry.all_specs`), plus tiny1's
factory. `2×2` is the coverage lower bound the user set (2026-08-19): a
channel pair on BOTH the lib and the binding, giving two baselines plus
the FORWARD (new binding, old lib) and BACKWARD (new lib, old binding)
cells. Most projects have one axis and are therefore *half* a 2×2.

Scenario counts are pinned by `matrix.registry_shape`
(`canary_projects_test.ml`) — a changed count anywhere fails the pin and
the failure names the project, so this table cannot drift silently.

| project | lib axis | binding axis | scen. | 2×2 status | local / CI |
| --- | --- | --- | ---: | --- | --- |
| **sqlite** | apt (Conf) + Built 3.45.1/3.46.1 + their staged installs = 5 | opam pins 5.1.0 / 5.4.1 | 10 | **full** — green by construction; the pair is narrow (identical symbol sets) | ✓ / ✓ |
| **z3** | Built (3 dev refs) vs apt 4.8.12 | Built vs opam 4.16.0 | 16 | **full, per dev ref** — the forward cell is a real ✗ (791 required, 705 provided). **Muted** in the run set | ✓ / ✓ |
| **llvm** | Built vs apt llvm-19 | opam `llvm.19-shared` (binding `follows` the lib) | 3 | **collapse only** — no cross cells until it grows z3's two probe realizations | ✓ / ✓ |
| **ssl** | apt only | opam pins 0.6.0 / 0.7.0 | 2 | binding half; the red cell is `probe_app_ocaml` xfail[c2] | ✓ / ✓ |
| **zarith** | apt only (prebuilt-shadows-source: apt ships upstream's newest) | opam 1.14 vs Built from the master worktree | 2 | binding half — baseline + the FORWARD cell | ✓ / ✓ |
| **cairo** | apt + conda-forge prebuilt | one | 2 | lib half. Vendored world is **pointed but not checked** ([issues.md](issues.md)) | ✓ / — |
| **libffi** | apt + conda-forge prebuilt | one | 2 | lib half; same gap. First `Dynamic_ffi` project | ✓ / ✓ |
| **zlib** | apt 1.3 + conda-forge 1.3.2 | one | 2 | lib half; the probe NAMES which libz answered | ✓ / — |
| **zstd** | apt 1.5.5 + conda-forge 1.5.7 | one | 2 | lib half; two world witnesses (runtime call + mapped path) | ✓ / — |
| **tiny-full** | Vendored + Built (assembled, no rebuild) | Vendored stable / dev | 1 | the factory's project face — the spec-derived world | ✓ / — |
| **tiny1** | Built (own C) | 3 bindings | 22 | not a 2×2 — the hand-written mutation **oracle**, 22/22 PASS | ✓ / — |

**Machinery, uniform unless noted.** Every registry entry is a plain
`project_run` (ssl's `Multi` retired 2026-08-12 with the store-pin
migration); adding a project = adding one entry. zarith/cairo/libffi/
zlib/zstd ride `Canary_opam_binding` (the template); sqlite/z3/llvm/
tiny-full/ssl build their own artifact table. Every prediction is
*derived* through the one lowering (`lower_expectation_agnostic`) and
contract-attributed — a project never hand-writes a failure substring.
S5a detection runs on every executed step.

`canary action @all` runs the active set under the default config, with
`pr_tier` grouping the runs: `Heavy` (z3, llvm — source-built chains)
goes THIN, bypassing the Dev builds; `Light` goes full. `--thin` forces
thin everywhere; an explicit single-project run ignores the tier. Pinned
by `registry.batch_tiers`.

**Per-project notes worth carrying:**

- **z3 is muted** (`canary_registry.ml`, commented out of
  `all_projects`): its opam package is `Package_builds_lib`, so every
  binding pin flip recompiles libz3 from source (~30 min a run). Muting
  suppresses *running*, not checking — `all_specs` still carries it and
  every pin still reads it.
- **sqlite's Built scenarios probe the BUILT lib** (soname symlink +
  `LD_LIBRARY_PATH` repoint) and assert the runtime version. Python's
  runtime sqlite is **Ambient** (uv's python statically bundles its own);
  OCaml's is **Independent**.
- **tiny1 ≠ tiny-full.** tiny1 (`canary tiny run`) is the ground-truth
  oracle: 22 hand-written scenarios, 22/22 PASS, detection coverage
  12/24 (the undetected 12 are watchlist-blind — c5/c6/abi — and need
  richer inspectors, not plumbing). tiny-full (`canary action tiny-full`)
  is a *project* peer of z3/sqlite whose scenarios are spec-derived, and
  it assembles vendored artifacts inside its own `pr_runner_spec`. That
  assemble step is tiny-factory machinery — **not** a template to copy.
- **`surface` is unpopulated on the template projects**: their
  watchlists still ride explicit `inspect` closures. Moving them to
  `Canary_surface` waits on the detector grow (S5) that reads it.
- **cairo's CI job is wired but never exercised on a runner**; CI as a
  whole still runs the pre-A5 shape (one chain per project, not the
  enumerated set) — tracked in [`issues.md`](issues.md).
- **Re-runs are cache-powered and safe**: a step skips only when its
  output exists, `check_post` passes, AND its verdict marker is present.
  Details in [`design/enumeration/stage5_realize_steps.md`](../design/enumeration/stage5_realize_steps.md)
  §8 and [`design/artifact_cache.md`](../design/artifact_cache.md).
- **Source-build path convention** (z3/llvm only): source at
  `~/code/contrib/<p>-all/<p>`, build at
  `~/code/contrib/<p>-all/build/<tag>`.

---

## 3. Landing history

| #   | Project              | Landed     | What it added                                                                                                                                                                          |
| --- | -------------------- | ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | z3                   | 2026-03    | Self-building pattern; local + CI                                                                                                                                                       |
| 2   | llvm                 | 2026-03    | Conf-discovery + source build; local + CI                                                                                                                                               |
| 3   | sqlite               | 2026-03    | The simplest conf-* shape; local + CI                                                                                                                                                   |
| —   | python primitives    | 2026-04-23 | sqlite/z3/llvm pip probes, local + CI                                                                                                                                                   |
| 7   | zarith               | 2026-04-25 | Most-used conf-* shape. Surfaced `inspect_native.py`'s GMP `__gmp*` stripping bug                                                                                                        |
| 5   | ssl                  | 2026-04-25 | Second datapoint. `Ssl.get_version` doesn't exist in 0.7.0                                                                                                                              |
| —   | the opam template    | 2026-04-25 | `canary_opam_binding.ml` — 135 lines compressing each spec to ~40                                                                                                                        |
| —   | api-compat milestone | 2026-05-01 | `Expect_compat_failure` derived expectations for OCaml + Python                                                                                                                         |
| 12  | cairo                | 2026-07-23 | First project onboarded post-redesign (`Derived` fetch_lib, S5a detection). Green first try                                                                                             |
| —   | tiny-full            | 2026-08-02 | tiny-full becomes a PROJECT (peer of z3/sqlite), not a `tiny` subcommand. Forward mismatch derived as `xfail[c1]`                                                                        |
| 3   | sqlite → generic     | 2026-08-05 | sqlite gains a `Built` provision and moves to `project_run`; Built worlds assert the runtime version                                                                                     |
| 1,2 | z3 + llvm → generic  | 2026-08-05 | A5: both move onto `project_run` (`pr_spec` + `realize ∘ dispatch`); their xfails become derived and contract-attributed                                                                 |
| —   | libffi               | 2026-08-11 | First `Dynamic_ffi` project (ctypes-foreign resolves libffi at runtime). Green first try                                                                                                 |
| —   | registry             | 2026-08-12 | `Canary_registry.all_projects` becomes the single source of truth; the template projects migrate to `project_run`                                                                        |
| —   | ssl store pins       | 2026-08-12 | ssl migrates off `Multi`: pins → 2 enumerated scenarios, pin-checked fetch + world assertions; the red cell derives                                                                      |
| —   | prebuilt lib axis    | 2026-08-19 | cairo + libffi gain their conda-forge Vendored point — the lib pair with no source build                                                                                                 |
| —   | z3 mismatch matrix   | 2026-08-19 | The first full 2×2 on real artifacts, per dev ref. Both cross cells needed a new probe realization to be honest                                                                          |
| —   | zlib                 | 2026-08-20 | First landing chosen by the MEASURED survey ranking (§G5) rather than by hand. Introduces `probe_names_lib`: the probe reads `/proc/self/maps` and the vendored world ASSERTS which libz answered — closing the "pointed but not checked" gap |
| —   | zstd                 | 2026-08-20 | Survey #2. First `Bounded_with_conf { tracks_lib = true }`: the binding declares a bare `conf-zstd`, but conf-zstd's own build runs `pkg-config --atleast-version=1.3.8` — a floor invisible to `opam show --field=depends`. Also the specimen showing exported-symbol COUNTS are packager policy, not API (177 vs 297 `ZSTD_`, nothing removed) |

---

## 4. Candidates

Two tiers, picked from the opam survey §3 (revdep rankings) and §2
(pattern hot spots); the current queue and its ordering live in
[`status_project.md` §3 D](status_project.md). Landed rows are dropped
from these tables — §2 is the roster.

### Tier 1 — famous libraries

The native library is the primary artifact and the OCaml binding is one
of several language consumers; canary's value is multi-language,
multi-PM interop coverage.

|    # | Library      | OCaml binding                         | Why interesting                                                                                            |
| ---: | ------------ | ------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
|    4 | **PyTorch**  | `torch` (opam) + `torch` (pip)        | pip × opam × apt libtorch matrix; the version range `[2.1, 2.2)` is a real mismatch case. Plan: [`project_pytorch.md`](project_pytorch.md) |
|    6 | **FFmpeg**   | `ffmpeg-{avcodec,avformat,swscale,…}` | One `conf-ffmpeg` drives a family of binding packages — "one conf, many binding artifacts"                   |

### Tier 2 — tricky bindings

Not household names, but the packaging exposes structural cases.

|    # | Library             | OCaml binding                 | Tricky-factor                                                                                             |
| ---: | ------------------- | ----------------------------- | ----------------------------------------------------------------------------------------------------------- |
|    8 | **libev**           | `lwt` (optional `conf-libev`) | `depopts: conf-libev` + `%{conf-libev:installed}%` — the first real test of optional-C-dep modelling         |
|    9 | **cvc5**            | `cvc5`                        | SMT sibling of z3; richer conf-set (`conf-cmake` + `conf-g++` + `conf-gmp`)                                 |
|   10 | **bitwuzla**        | `bitwuzla-c` + `-cxx`         | Vendors the solver but links system GMP via `conf-gmp` — the hybrid neither shape covers                    |
|   11 | **MariaDB / MySQL** | `mariadb` via `conf-mariadb`  | Conf discovery + source build + cross-PM (apt vs brew); sibling to sqlite, very different shape             |
|  13 | **lmdb**            | `lmdb`                        | Direct depexts + a `clib:` tag, **no conf-\*** — the no-indirection style. Its pair comes from opam pins    |
|  14 | **sundials**        | `sundialsml`                  | The row that PROVES the §G1a finding: `conf-sundials {>= "2"}` looks bounded but the version never reaches the check — apt 6.4.1 → conda-forge 7.8.0, the widest free pair measured |
|  15 | **mpfr**            | `mlmpfr` / `mlgmpidl`         | `mlmpfr`'s gate lives in its OWN build (`Self_check_in_build`, which `pm_dep_gate` cannot express) — a naturally-occurring xfail. `mlgmpidl` uses the `conf-*-paths` conf FAMILY |
|   16 | **ncurses**         | `curses`                      | `Free_with_conf`, apt 6.4 → conda-forge 6.6, binding install is a clean 2-package add. Carries an upstream finding: `conf-ncurses` declares `["lib64ncurses-dev"] {os-family = "ubuntu"}`, but opam reports `os-family = debian` on Ubuntu, so that line can never fire |

### Not queued

Deliberately, each for its own reason:

- **Pattern D (invisible C stubs)** — `mirage-crypto`, `bigstringaf`,
  43 packages. No leverage until source inspection is in the toolkit.
- **`owl` / `conf-openblas`** — multiple BLAS variants (OpenBLAS / MKL /
  Accelerate). A natural follower after PyTorch.
- **`bytesrw`** — wants named lib artifacts (D4) *plus* optional deps as
  `Absent` placements *plus* a combination policy. Blocked on both.
- **Unmeasured** — libressl (an OpenSSL sibling, so a DIFFERENT library
  rather than a second version), protobuf, grpc, jq/oniguruma. Named in
  passing, never measured against the survey gates.
