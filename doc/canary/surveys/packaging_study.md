# Native Library Binding Packaging Study

Study of how C/C++ libraries with language bindings are packaged across
Debian/apt, Homebrew, opam, and pip. Goal: inform the canary system's phase
model and understand patterns beyond the Z3/SQLite cases.

Status: **Phase 1** (apt, brew, opam, pip). Later phases: vcpkg, cargo, npm.

---

## 1. Package Manager Philosophies

Each PM has a fundamentally different stance on native library ownership:

| PM           | Philosophy                                                                                                                                           | Who owns the C lib?               |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| **apt**      | Everything prebuilt. Separate `-dev` packages for headers. Binding packages per language built from same or separate source.                         | The distro.                       |
| **Homebrew** | Build from source (cached as bottles). Single formula per library. Keg-only for macOS-conflicting libs. Language bindings delegated to language PMs. | Homebrew (but keg-only friction). |
| **opam**     | Link to system libraries. `conf-*` + `depexts` bridge to OS PM. Build bindings from source.                                                          | The system PM.                    |
| **pip**      | Bundle everything into the wheel. Self-contained, reproducible. auditwheel/delocate to achieve this.                                                 | The Python package.               |

Key insight: **opam delegates library ownership to the system PM; pip internalizes it.**
This creates different failure modes the canary must test.

## 2. The opam Three-Layer Pattern

```
conf-sqlite3          (virtual: runs pkg-config, declares depexts)
    |
    v
sqlite3               (OCaml binding: builds stubs, links to system lib)
    |
    v
caqti-driver-sqlite3  (higher-level abstraction)
```

- `conf-*` packages: install nothing, just verify the C lib is present
- `depexts` field maps `{os-family, os-distribution}` to system package names
- opam 2.1+ can auto-invoke apt/brew to install missing system deps
- Binding packages build OCaml stubs from source, linking dynamically

**Exception**: opam `z3` breaks this pattern -- builds the *entire* C++ solver
from source alongside OCaml bindings (no `conf-z3` exists).

## 3. The pip Bundling Spectrum

From most self-contained to most system-dependent:

1. **Static-link into wheel**: `cryptography` (OpenSSL), `gmpy2` (GMP)
2. **Bundle shared lib in wheel**: `z3-solver`, `pygit2` (libgit2), `PyNaCl` (libsodium)
3. **Link to system lib**: `cffi` (libffi on Linux/macOS; bundles on Windows)
4. **Part of CPython stdlib**: `sqlite3`, `ctypes`, `_ssl`
5. **Source-only fallback**: any package on unsupported platforms

The **manylinux standard** drives this: its allowlist is minimal (libc, libm,
libpthread, libdl, librt). Anything else must be bundled. **auditwheel** copies
`.so` files into wheels and patches RPATH.

## 4. Library-by-Library Findings

### Z3 (SMT Solver)

| PM   | Package(s)                           | Binding bundled?                                  | Source/Prebuilt                       | Discovery                | Version coupling                            |
| ---- | ------------------------------------ | ------------------------------------------------- | ------------------------------------- | ------------------------ | ------------------------------------------- |
| apt  | `libz3-4`, `libz3-dev`, `python3-z3` | Separate pkgs, same source                        | Prebuilt                              | Standard paths           | Locked within Debian release; lags upstream |
| brew | `z3`                                 | Single formula (lib+CLI+Python)                   | Bottles                               | pkg-config, prefix paths | Tracks upstream closely                     |
| opam | `z3`                                 | Builds entire solver + OCaml bindings from source | Source                                | N/A (vendored build)     | Exact: opam version = Z3 version            |
| pip  | `z3-solver`                          | Bundled in wheel                                  | Prebuilt wheels (all major platforms) | N/A (self-contained)     | Exact: pip version = Z3 version             |

**Canary implications**: Z3 is the most complex case. The opam package is unusual
in building from source. The canary already models this well with its
`Source` vs `Prebuilt` origin and `Install_local` phase.

### SQLite

| PM   | Package(s)                       | Binding bundled?                   | Source/Prebuilt                        | Discovery                        | Version coupling                      |
| ---- | -------------------------------- | ---------------------------------- | -------------------------------------- | -------------------------------- | ------------------------------------- |
| apt  | `libsqlite3-0`, `libsqlite3-dev` | Python `sqlite3` is CPython stdlib | Prebuilt                               | pkg-config                       | Locked at Python build time           |
| brew | `sqlite` (keg-only)              | N/A                                | Bottles                                | pkg-config (needs explicit path) | Independent of system SQLite          |
| opam | `conf-sqlite3` + `sqlite3`       | Separate                           | Bindings from source, links system lib | pkg-config                       | Loose (works with range)              |
| pip  | stdlib / `apsw`                  | apsw bundles SQLite in wheel       | apsw: prebuilt                         | N/A for stdlib                   | apsw: exact; stdlib: at CPython build |

**Canary implications**: Clean example of the `conf-*` pattern. Keg-only on
macOS requires `PKG_CONFIG_PATH` setup -- a pattern the canary should model.

### libffi

| PM   | Package(s)                       | Binding bundled?                          | Source/Prebuilt       | Discovery                        | Version coupling |
| ---- | -------------------------------- | ----------------------------------------- | --------------------- | -------------------------------- | ---------------- |
| apt  | `libffi8`, `libffi-dev`          | N/A                                       | Prebuilt              | pkg-config                       | N/A              |
| brew | `libffi` (keg-only)              | N/A                                       | Bottles               | pkg-config (needs explicit path) | N/A              |
| opam | `conf-libffi` + `ctypes-foreign` | Separate                                  | Bindings from source  | pkg-config                       | Loose            |
| pip  | `cffi`                           | Bundles on Windows; system on Linux/macOS | Wheels via auditwheel | pkg-config when from source      | Loose            |

### libgit2

| PM   | Package(s)                           | Binding bundled?         | Source/Prebuilt | Discovery                   | Version coupling                       |
| ---- | ------------------------------------ | ------------------------ | --------------- | --------------------------- | -------------------------------------- |
| apt  | `libgit2-X`, `libgit2-dev`           | N/A                      | Prebuilt        | pkg-config, cmake           | N/A                                    |
| brew | `libgit2` (versioned formulae exist) | N/A                      | Bottles         | pkg-config, cmake           | N/A                                    |
| opam | `git` (pure OCaml reimpl, MirageOS)  | N/A (no C dep)           | Pure OCaml      | N/A                         | N/A                                    |
| pip  | `pygit2`                             | Bundles libgit2 in wheel | Prebuilt wheels | cmake, env vars from source | **Very tight**: major.minor must match |

**Interesting**: OCaml ecosystem chose pure reimplementation over C bindings.
pygit2's tight coupling is a known pain point.

### OpenSSL / LibreSSL

| PM   | Package(s)                                        | Binding bundled?             | Source/Prebuilt      | Discovery                        | Version coupling                          |
| ---- | ------------------------------------------------- | ---------------------------- | -------------------- | -------------------------------- | ----------------------------------------- |
| apt  | `libssl3`, `libssl-dev`                           | N/A                          | Prebuilt             | pkg-config                       | N/A                                       |
| brew | `openssl@3` (keg-only; macOS ships LibreSSL)      | N/A                          | Bottles              | pkg-config (needs explicit path) | N/A                                       |
| opam | `conf-libssl` + `ssl`; pure alt: `tls` (MirageOS) | Separate                     | Bindings from source | pkg-config                       | Loose; `conf-libssl` has version variants |
| pip  | `cryptography`                                    | **Statically links OpenSSL** | Wheels               | env vars, pkg-config from source | Pinned at wheel build time                |

**Key pattern**: macOS ships LibreSSL, brew ships OpenSSL, creating confusion.
The canary should test this divergence. `cryptography` statically linking
OpenSSL is the extreme of pip's "own everything" philosophy.

### GMP

| PM   | Package(s)               | Binding bundled?                   | Source/Prebuilt      | Discovery                                      | Version coupling |
| ---- | ------------------------ | ---------------------------------- | -------------------- | ---------------------------------------------- | ---------------- |
| apt  | `libgmp10`, `libgmp-dev` | N/A                                | Prebuilt             | pkg-config (sometimes), `-lgmp`                | N/A              |
| brew | `gmp`                    | N/A                                | Bottles              | Standard paths, pkg-config                     | N/A              |
| opam | `conf-gmp` + `zarith`    | Separate                           | Bindings from source | Custom check (GMP lacks .pc on some platforms) | Loose (GMP 5.x+) |
| pip  | `gmpy2`                  | Static-links GMP/MPFR/MPC in wheel | Prebuilt wheels      | N/A bundled; system from source                | Loose (GMP 5.1+) |

**Note**: GMP's lack of universal pkg-config support makes it a good edge case
for the canary's discovery testing.

### PCRE2 and libsodium

Both follow the standard patterns:

- apt: prebuilt with `-dev` split, pkg-config
- brew: bottles, pkg-config
- opam: `conf-*` + binding package, pkg-config
- pip: `PyNaCl` bundles libsodium by default; PCRE2 niche in Python

## 5. Cross-Cutting Patterns

### pkg-config: The Universal Glue

The single most important discovery mechanism across all ecosystems:

- opam `conf-*` packages almost universally use `pkg-config <lib>` as their check
- pip source builds use pkg-config via setup.py/meson/cmake
- brew installs `.pc` files for all formulae (but keg-only complicates PATH)
- apt `-dev` packages install `.pc` files to arch-qualified paths

**`PKG_CONFIG_PATH` is the #1 source of build failures across all ecosystems.**
The canary should explicitly test pkg-config discovery.

### Keg-Only (Homebrew-Specific)

Libraries that conflict with macOS system versions (sqlite, libffi, openssl)
are keg-only: not symlinked into `/opt/homebrew`. Requires explicit:

```
PKG_CONFIG_PATH="$(brew --prefix openssl@3)/lib/pkgconfig"
```

This is a recurring failure pattern the canary should cover.

### Pure Language Reimplementations

Some ecosystems avoid the binding problem entirely by reimplementing C
libraries in the host language (e.g., `ocaml-git`, `ocaml-tls` in OCaml/
MirageOS). These projects are outside the canary's scope since they have no
C API boundary to test.

### Canary-Like Tools and Binary Compatibility Checkers

Several tools across ecosystems address the same problem space as the canary
— verifying that binaries, packages, or bindings are compatible with their
runtime environment.

**Python wheel compliance:**

- **manylinux** (PEP 600): A compatibility standard for Linux wheels.
  Defines a minimal allowlist of system libraries a wheel may depend on
  (libc, libm, libpthread, libdl, librt, libgcc_s). Anything else must be
  bundled. The standard is tiered: `manylinux2014` (CentOS 7 baseline),
  `manylinux_2_28` (AlmaLinux 8), etc.
  *Usage*: **De facto required** for PyPI uploads of native-extension
  wheels. PyPI rejects Linux wheels that don't declare a manylinux tag.
  Nearly all major native-extension packages (numpy, cryptography, etc.)
  comply. Enforced by PyPI infrastructure, not optional.

- **auditwheel**: Inspects a Linux wheel's shared library dependencies,
  checks manylinux compliance, and can repair non-compliant wheels by
  copying `.so` files into the wheel and patching RPATH/RUNPATH.
  `auditwheel show` is a diagnostic tool; `auditwheel repair` is the fixer.
  *Usage*: **Widely used, standard practice.** Part of the official PyPA
  toolchain (maintained under pypa/auditwheel). Typically run in CI
  (e.g., cibuildwheel integrates it automatically). Any project publishing
  native Linux wheels uses it.

- **delocate**: macOS equivalent of auditwheel. Copies dylibs into wheels,
  rewrites `@rpath`/`@loader_path` references. Handles the macOS-specific
  `install_name` mechanism.
  *Usage*: **Widely used for macOS wheels.** Also integrated into
  cibuildwheel. Less universal than auditwheel (macOS-only), but standard
  for any project shipping macOS native wheels.

- **repairwheel**: Cross-platform wheel repair tool (Linux + macOS + Windows).
  Newer alternative that unifies auditwheel/delocate functionality.
  *Usage*: **Emerging, not yet standard.** Newer project, gaining adoption
  but auditwheel/delocate remain dominant.

These tools are **post-build verifiers** — they check whether a built
artifact is portable. The canary is a **pre-deployment tester** — it checks
whether a binding works in a target environment. They are complementary:
auditwheel ensures the wheel is self-contained; the canary ensures the
binding actually produces correct results.

**System package managers:**

- **lintian** (Debian/apt): Static checker for `.deb` packages. Verifies
  policy compliance, dependency correctness, shared library metadata
  (`shlibs`), symbol files. The `symbols` file mechanism is particularly
  relevant — it tracks which symbols each library version provides, enabling
  precise dependency versioning.
  *Usage*: **Enforced by Debian infrastructure.** Required for official
  Debian archive uploads (lintian errors block acceptance). Run by Debian
  buildd infrastructure and by maintainers in CI. Not optional for official
  packages; widely used outside Debian for .deb quality checking.

- **autopkgtest** (Debian): Runs functional tests on installed packages in
  a clean environment. Closest analog to canary's integration testing
  approach, but scoped to a single package manager.
  *Usage*: **Enforced by Debian CI.** Tests are defined in
  `debian/tests/control` and run automatically by Debian CI infrastructure
  on every upload. Increasingly required — packages with autopkgtests get
  migration priority. Ubuntu also runs them. Adopted by ~30-40% of Debian
  source packages.

- **rpmlint** (RPM/Fedora): Similar to lintian for RPM packages.
  *Usage*: **Required by Fedora.** Run in Fedora's Koji build system.
  Errors block package review for new packages. Standard practice in the
  RPM ecosystem (openSUSE, RHEL, etc.).

- **abipkgdiff** / **libabigail** (Red Hat): Compares the ABI of shared
  libraries across package versions. Detects symbol removals, type changes,
  vtable layout shifts. This is the most directly relevant tool for the
  canary's C API entity concept (../design/index.md step 2).
  *Usage*: **Used by Fedora/RHEL infrastructure, niche elsewhere.** Run
  by Fedora's `abicheck` CI job on library packages. Also used by some
  upstream projects (e.g., systemd, elfutils) in their own CI. Not widely
  adopted outside the Red Hat ecosystem. Powerful but specialized.

**Homebrew:**

- **`brew audit`**: Checks formula style and correctness.
  *Usage*: **Enforced by Homebrew CI.** Required to pass for all PRs to
  homebrew-core. Run automatically in Homebrew's GitHub Actions CI.

- **`brew test`**: Runs formula-defined tests after installation. Each
  formula can define a `test do` block — typically a minimal compile-and-run
  check, similar to canary's compile/run steps.
  *Usage*: **Required for homebrew-core formulas.** All formulas must have
  a `test do` block. Run in Homebrew's CI after installation. Tests are
  typically minimal (compile a hello-world, run `--version`, import a
  library). Coverage varies in quality but the mechanism is universal.

**Language-specific:**

- **`opam depext`**: Not a compatibility checker per se, but the mechanism
  that bridges opam packages to system package requirements. Uses `depexts`
  metadata to auto-install system dependencies.
  *Usage*: **Built into opam 2.1+.** Automatic — `opam install` triggers
  system package installation when depexts are declared. Widely adopted
  by opam packages that need C libraries. Not a separate tool anymore,
  integrated into the opam workflow.

- **`cargo-deny`**: Checks Rust dependency graphs for license, advisory,
  and source issues. Less relevant since Rust statically links.
  *Usage*: **Optional, popular in enterprise Rust.** Used by Mozilla,
  Google, many open-source Rust projects. Not enforced by crates.io.

- **`node-gyp`** / **`prebuildify`**: Node.js native addon build/prebuild
  tools. `prebuildify` pre-compiles native modules for multiple platforms,
  similar to Python wheels. No equivalent to auditwheel for verification.
  *Usage*: **node-gyp is the default** native addon build tool (used by
  thousands of npm packages). `prebuildify` is optional but increasingly
  popular for avoiding end-user compilation (used by leveldown, sharp,
  etc.). No enforced verification — binary compatibility issues are a
  known pain point in the Node.js native module ecosystem.

**Key insight for the canary**: The Debian `symbols` file mechanism and
Red Hat's `libabigail` are the closest existing tools to what the canary's
C API entity (../design/index.md step 2) aims to model. They track which symbols
a library provides at which version, enabling precise compatibility
reasoning. The canary could learn from their approach:

- Debian `symbols`: per-symbol minimum version tracking
- libabigail: full ABI diff between library versions
- canary (planned): expected symbol sets derived from binding build version
  vs installed library version

## 6. Implications for the Canary Phase Model

### Current phases map well to the opam pattern

| Phase                    | What it models                                 |
| ------------------------ | ---------------------------------------------- |
| `Install_pkg(System_pm)` | apt/brew install of the C library              |
| `Install_pkg(Lang_pm)`   | opam install of `conf-*` + binding package     |
| `Install_local`          | Local opam repo with custom package            |
| `Configure_build`        | CMake/make for source builds                   |
| `Test_binding`           | Compile + run OCaml examples                   |
| `Run_command`            | Ad-hoc commands (Python import, symbol checks) |

### Gaps to consider for future expansion

1. **pkg-config verification phase**: Explicit step to verify pkg-config
   resolves correctly before building. Many failures trace to this.

2. **Keg-only path setup**: macOS-specific phase for setting `PKG_CONFIG_PATH`,
   `LDFLAGS`, `CFLAGS` for brew keg-only libraries. Currently implicit in
   env var setup; could be an explicit discovery phase.

3. **Pip wheel testing**: Different failure modes than opam. A pip test phase
   would need:
   - Install from wheel (bundled lib, should always work)
   - Install from sdist (needs system lib, mirrors opam pattern)
   - Test import + basic usage

4. **Version matrix**: The `binding/canary.ml` enumeration model (Old/Dev
   version pairs) aligns with real-world coupling. Z3 and pygit2 need exact
   version matching; SQLite and libffi are loose. The canary could parameterize
   version strictness.

5. **Discovery method as first-class concept**: Libraries use different
   discovery: pkg-config, cmake `find_package`, env vars (`Z3_PREFIX`),
   vendored builds. Making this explicit in the phase model would help
   diagnose failures.

## 7. Local PyPI Mirror (devpi)

For testing pip-based canaries locally, **devpi** is the recommended tool
(analogous to a local opam repo fork):

```bash
pip install devpi-server devpi-client
devpi-server --init && devpi-server &
devpi use http://localhost:3141
devpi login root --password ''
devpi index -c root/dev bases=root/pypi   # overlay index
devpi use root/dev
```

Key properties:

- **Index inheritance**: `root/dev` overlays `root/pypi` (caching proxy to
  real PyPI). Your custom packages shadow upstream -- exactly like opam repo
  layering.
- **On-demand caching**: First `pip install` fetches from PyPI and caches.
  No pre-population needed.
- **Pure Python**: Works on macOS, no Docker required.
- **Disk**: Only stores what you install (typically 1-5 GB for dev workloads).

Simpler alternative for one-off testing (no server):

```bash
mkdir ~/local-pypi
pip download -d ~/local-pypi some-package
pip install --no-index --find-links=~/local-pypi some-package
```

## 8. Summary Tables

### Version Coupling

| Library   | opam coupling                               | pip coupling                     |
| --------- | ------------------------------------------- | -------------------------------- |
| Z3        | Exact (builds matching version from source) | Exact (pip version = Z3 version) |
| SQLite    | Loose (works with range)                    | N/A (stdlib) or Exact (apsw)     |
| libffi    | Loose                                       | Loose                            |
| libgit2   | N/A (pure OCaml)                            | Tight (major.minor must match)   |
| OpenSSL   | Loose                                       | Pinned at build time             |
| GMP       | Loose (GMP 5.x+)                            | Loose (GMP 5.1+)                 |
| libsodium | Moderate (>= 1.0.9)                         | Pinned (bundled)                 |

### Discovery Methods

| Library   | pkg-config            | cmake find_package | env vars               | Notes                                       |
| --------- | --------------------- | ------------------ | ---------------------- | ------------------------------------------- |
| Z3        | Yes (.pc)             | Yes                | `Z3_PREFIX`, `Z3_ROOT` | opam builds from source, bypasses discovery |
| SQLite    | Yes (`sqlite3.pc`)    | No                 | N/A                    | Keg-only on macOS                           |
| libffi    | Yes (`libffi.pc`)     | No                 | N/A                    | Keg-only on macOS                           |
| libgit2   | Yes (`libgit2.pc`)    | Yes                | `LIBGIT2`              | Versioned formulae in brew                  |
| OpenSSL   | Yes (`openssl.pc`)    | Yes                | `OPENSSL_DIR`          | Keg-only; macOS LibreSSL confusion          |
| GMP       | Sometimes             | No                 | `CFLAGS`/`LDFLAGS`     | No .pc on all platforms; edge case          |
| PCRE2     | Yes (`libpcre2-8.pc`) | Yes                | N/A                    | Clean pkg-config story                      |
| libsodium | Yes (`libsodium.pc`)  | No                 | `SODIUM_INSTALL`       | PyNaCl bundles by default                   |

## 9. Large-Scale PyPI Study (Future Reference)

If we ever want to study packaging patterns across all of PyPI (not just
specific packages), there are metadata-only approaches that avoid mirroring
30+ TB of wheels:

- **Google BigQuery** (`bigquery-public-data.pypi`): Public dataset with
  metadata for every package/release. Query for things like "how many packages
  ship manylinux wheels?" or "what fraction use cffi vs ctypes?" — free within
  quota, no local storage needed.
- **PyPI JSON API**: `https://pypi.org/pypi/<package>/json` per package.
  Scriptable for targeted surveys (e.g., top 1000 native-extension packages).
  Rate-limited but sufficient for focused studies.
- **bandersnatch**: Official PyPI mirror tool. Supports filtering by package
  name, platform, Python version — useful for a targeted subset mirror
  (~50-200 GB for native-extension packages on one platform).

Full PyPI mirror is 30+ TB and impractical on a laptop. Metadata-only
approaches are the right tool for broad packaging studies.

---

*Phase 1 complete. Next: vcpkg, cargo, npm; deeper dive into depexts
mechanics; canary phase model refinements.*
