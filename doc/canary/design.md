# Canary Design and Plan

## Goal

Canary is a high-level testing generator for projects with:

- one upstream native/core library (C/C++)
- multiple language bindings
- bindings delivered through different package managers

These projects are fragile because a binding may be built, packaged, or
published against different versions of the upstream library. Canary makes
these compatibility combinations explicit and tests them before end users
discover breakage.

## Current Architecture

### Module Layering

```
canary_basic          Core types, step constructors, backend utilities
    |
canary_basic_ocaml    OCaml toolchain types, command generation
    |
canary                project_config, resolve_phase, make_job
    |
canary_project_*      Per-project configs (z3, sqlite)
    |
canary_run            Runner: dump, render, deploy
```

### Pipeline

```
project_config
  -> job_spec (with step_phase list)
  -> make_job (resolve_phase + apply_expectation)
  -> string job (fully resolved steps)     <-- canary_dump inspects here
  -> resolve_backend_scripts (template var substitution)
  -> render (YAML or shell backend)
```

### Current Type Model

**`step_phase`**: A declarative phase in a job. Fields: `kind`, `action`,
`location`, `requires`, `produces`, `expectation`.

**`phase_kind`**: What the phase does:

| Phase kind       | Nature    | `resolve_phase` behavior            |
| ---------------- | --------- | ----------------------------------- |
| `Install_pkg`    | Primitive | Resolves to system/lang PM commands |
| `Install_local`  | Primitive | Resolves to local opam install      |
| `Run_command`    | Primitive | Wraps command in `run_step`         |
| `Configure_build`| Compound  | Passthrough (pre-built steps)       |
| `Test_binding`   | Compound  | Expands via `mk_ocaml_test_steps`   |

**`ocaml_tool_config`**: Per-project OCaml config:
`{ toolchain : opam_spec; ocaml : ocaml_binding; prebuilt : prebuilt_info option }`

**Key enumerations**:
- `origin = Source | Prebuilt`
- `location = Build_tree | System_pm | Lang_pm | Wild of string`
- `compile_mode = Native | Bytecode`
- `code_step = Compile | Run`
- `all_cc_and_modes`: cartesian product of modes and code steps

### Current Examples

- **z3**: Source build, external library use, local opam packaging, expected
  symbol failures, Python binding test. Three jobs: build-and-test,
  download-and-test, packaging-from-prebuilt.
- **sqlite3**: Prebuilt system library, opam package install, all-success
  test. One job: download-and-test.

## Design Principles

1. **Configuration is primary, backends are derived.** The main product is a
   structured compatibility model, not the generated YAML/shell.

2. **Gradual abstraction.** Extract patterns from concrete jobs. Every
   abstraction must be validated by at least two examples.

3. **Explicit boundaries.** Make compatibility boundaries visible: upstream
   library, binding, package manager, artifact, environment.

## Next Steps

### 1. Principled Step Primitives

**Problem**: `Test_binding` wraps legacy code. `Configure_build` is a
meaningless passthrough. There is no clear distinction between primitive
phases (resolved by `resolve_phase`) and compound phases (carrying
pre-built steps).

**Goal**: Every `phase_kind` should be a meaningful primitive whose
resolution is determined by its attributes (`action`, `location`, `origin`).
Compound steps should be explicit compositions of primitives.

**Approach**:
- Use `canary_dump` to study what `Test_binding` and `Configure_build`
  expand to in both projects
- Identify which step attributes (action, location, origin, mode) are
  sufficient to derive the shell command
- Design new primitives that can express the same steps declaratively
- Eliminate `Test_binding` as a special case; its expansion should be
  derivable from the phase's attributes + project config

### 2. First-Class C API Entity

**Problem**: The canary currently has no model of what the upstream project
provides at the C API level, or what the binding expects from it. Success
and failure expectations are manually specified.

**Goal**: Model the C API surface so the system can reason about
compatibility:

- **Upstream provides**: a set of symbols/functions in the shared library,
  at a specific version
- **Binding expects**: a set of symbols/functions it calls, built against a
  specific version
- **Compatibility check**: if the binding was built against the same version
  as the installed library, expect success. If the system library lags
  behind the binding's build version, expect specific missing symbols.

**Approach**:
- Define a type for C API surface (symbol sets, version info)
- Allow the project config to declare the expected API surface
- Derive expectations automatically: same-version = success,
  version-mismatch = expected symbol failures
- Use build artifacts (e.g., clang AST dump, nm output) to validate the
  declared API surface against reality

### 3. Auto-Generated Project Configs

**Problem**: Project configs (job specs, phase lists) are manually
constructed. For a real-world project, given its layout and packaging, the
canary should be able to generate the full testing matrix.

**Goal**: Given a project sketch (library name, binding languages, package
manager presence, source repo layout), generate a complete `project_config`
including which test jobs to run.

**Approach**:
- Define a high-level project sketch type (simpler than `project_config`)
- Derive the job matrix from the sketch: for each (origin, location,
  binding) combination, generate the appropriate phases
- Use the C API entity (step 2) to derive expectations
- Keep manual override capability for edge cases

### 4. First-Class Package Locator and Real-World Coverage

**Problem**: Libraries are discovered differently across package managers
(pkg-config, cmake find_package, env vars, vendored builds). The canary
has no explicit model for discovery. See `packaging_study.md` for patterns.

**Goal**: Model package location and discovery as first-class constructs:

- **Package locator**: how to find a library on a given platform
  (pkg-config name, brew prefix, env var, cmake target)
- **Keg-only handling**: explicit phase for macOS `PKG_CONFIG_PATH` setup
- **Version resolution**: how to determine the installed version
- **depexts bridge**: model the opam `conf-*` pattern explicitly

**Approach**:
- Study `packaging_study.md` patterns: pkg-config as universal glue,
  keg-only friction, pip bundling spectrum
- Define a `package_locator` type that covers the discovery methods in
  the study
- Ensure the modeling covers real-world scenarios: Z3 (cmake + env vars),
  SQLite (pkg-config, keg-only), libffi (keg-only), OpenSSL (keg-only +
  LibreSSL confusion), GMP (no universal pkg-config)
- Test the model against the library-by-library findings in the study

## References

- `doc/canary/packaging_study.md`: Real-world packaging patterns across
  apt, brew, opam, pip for Z3, SQLite, libffi, libgit2, OpenSSL, GMP,
  libsodium, PCRE2
- `canary_dump` command: inspect fully resolved jobs before rendering
