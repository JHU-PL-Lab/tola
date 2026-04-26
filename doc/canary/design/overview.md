# Canary Design

## Research Vision

### The problem

Popular native libraries — LLVM, Z3, PyTorch, SQLite, and many others — are
consumed through multiple language bindings (OCaml, Python, Java, Rust, ...)
each distributed through a different package manager (opam, pip, maven,
crates.io, ...). The native library itself is also distributed through system
package managers (apt, brew) and often built from source. The result is a
high-dimensional compatibility space:

```
library version × binding version × package manager × language × platform
```

Breakage is endemic because no single actor owns this whole space. The library
team doesn't control how bindings are packaged. The binding author doesn't
control which library version is installed. The PM doesn't know whether a
given (lib version, binding version) pair actually works. Users discover
incompatibilities at install time or worse, at runtime.

### Two-track approach

**Track 1 — Empirical coverage.** Run the full compatibility matrix for real
projects. Current targets: LLVM, Z3, PyTorch (planned). Longer term: all
opam packages that wrap native libraries. The pattern table (14 structural
patterns) and canary's action runner are the machinery for this track.

**Track 2 — Interface theory.** Behind the messy practice lies a clean
abstraction: the *interface* between a library and a binding. If we can
characterize this interface formally, we can:
- *Infer* compatibility results without running every combination
- *Generate* tests that prove compatible pairs work and disprove expected failures
- *Explain* failures in terms of interface mismatches, not just exit codes

These two tracks reinforce each other. Empirical results validate or
contradict inferences; the theory guides which combinations are worth testing.

### The interface

A library and a binding are compatible if the library *provides* what the
binding *requires* at the interface boundary. For C-based libraries, the
interface has multiple layers:

```
Layer               What it contains                Example
─────────────────   ─────────────────────────────   ──────────────────────
C symbol surface    exported symbols, types          nm -D libz3.so
Header API          function signatures, structs     z3.h, llvm-c/Core.h
ABI conventions     calling convention, struct layout  x86-64 SysV ABI
Semantic contract   postconditions, thread safety    documentation
```

Current canary coverage: C symbol surface (via `nm` + `Expect_symbols`),
partial header API (via OCaml compile failure as a proxy). The deeper layers
(ABI, semantic) are out of scope for now.

A *compatibility predicate* for a pair `(lib@v1, binding@v2)` is:

```
provides(lib@v1) ⊇ requires(binding@v2)
```

where `provides` and `requires` are sets of typed interface elements. For
C libraries, this reduces to symbol presence + type compatibility. For richer
interfaces (typed headers, semantic contracts), the predicate becomes richer.

### Inference and test generation

With an interface model, compatibility becomes *computable* from metadata,
not just observable from test runs:

- **API diff** between `lib@v1` and `lib@v2` → which symbols were added,
  removed, or changed in type
- **Binding dependency** `binding@v2` built against `lib@v_build` → which
  symbols it uses (via nm on the binding's object files or DWARF debug info)
- **Compatibility inference**: `lib@v1` is compatible with `binding@v2` iff
  all symbols `binding@v2` uses are present in `lib@v1` at compatible types

The canary then generates targeted tests:
- For *inferred-compatible* pairs: a probe step expected to succeed
- For *inferred-incompatible* pairs: an `Expect_failure` probe with predicted
  missing symbols in `contains_any`

This turns canary from a test runner into a *proof system*: test results
confirm or contradict predictions, and predictions reduce the combinatorial
explosion of what needs to be tested.

### Ecosystem design implications

The interface theory has a prescriptive angle beyond compatibility checking.
Studying where existing package ecosystems fail at the interface seams gives
concrete guidance for new language PMs:

- **What makes a well-designed binding PM?** Semantic versioning aligned with
  the upstream library's API surface; conf packages that expose the locator
  version to downstream; explicit ABI stability policies.
- **Where do existing PMs fail?** opam's conf packages have ad-hoc locator
  search logic; pip bundles the library (avoids the seam but at cost of
  size/duplication); apt/brew have no concept of binding compatibility at all.
- **New language ecosystems** can learn from this empirical record: what
  metadata to track, what invariants to enforce, what the seams between
  native and managed worlds require.

---

## Goal

Canary is a compatibility testing framework for projects with a native C/C++
library, multiple language bindings, and bindings delivered through different
package managers. These projects are fragile because a binding may be built,
packaged, or probed against different versions of the upstream library. Canary
makes all compatibility combinations explicit and tests them systematically.

## Module Layering

```
canary_pm_types        PM enum: Apt | Brew | Opam | Pip | Unsupported
canary_pm_{apt,...}    Per-PM: install_cmd, verify_installed_cmd, is_installed
    |
canary_store           source_repo, local_path (with build_path), mk_locals,
                       version_cache_tag, source_fetch_cmd, source_check_post
    |
canary_basic           artifact_kind, rule, location, project_spec, detect_distro
canary_ocaml           ocaml_tool_config, opam_package_spec, probe generation
    |
canary_action          script_spec, derive_steps, run_graph, action_step
canary_artifact_check  check_build_lib, check_build_binding, check_markers
    |
canary_project_*       Per-project script_spec implementations (z3, llvm, sqlite)
canary_run             Orchestrator; legacy YAML/shell backends
```

`canary.ml` sits alongside `canary_action.ml` and owns the universal rule graph
(`store_rules`, `make_action_rule`, `pattern_rows_of_paths`) and diagram
generation. It also contains the legacy `project_config`/`job_spec` pipeline
used by `canary run` (YAML/shell backends).

## Core Vocabulary

### `artifact_kind`

```ocaml
type artifact_kind = Source | Lib | Binding | App
```

The four artifact sorts. Every action either produces or consumes artifacts
of one of these kinds.

### `rule`

```ocaml
type rule =
  | Fetch of artifact_kind   (* fetch from a store *)
  | Configure                (* cmake configure / build-gen *)
  | Build_lib                (* Source → Lib@build_tree *)
  | Build_binding            (* Source × Lib → Binding@build_tree *)
  | Build_app                (* Binding × Lib(runtime) → App *)
  | Publish of artifact_kind (* pack artifact into a store *)
  | Probe of artifact_kind   (* test an artifact *)
```

`rule` is the universal vocabulary. `store_rules` is the canonical ordered
list from which all action graphs are derived.

### `script_spec`

```ocaml
type script_spec = {
  fetch_source   : (output_dir:string -> string) option;
  configure      : (output_dir:string -> string) option;
  build_lib      : (output_dir:string -> string) option;
  build_binding  : (output_dir:string -> string) option;
  fetch_lib      : (output_dir:string -> string) option;
  fetch_binding  : (output_dir:string -> string) option;
  pack_binding   : (output_dir:string -> string) option;
  probe_binding  : (location * (output_dir:string -> string)) list;
  (* ... other slots ... *)
  check_post     : rule -> (output_dir:string -> bool) option;
}
```

A project's implementation of the rule vocabulary: one shell command per slot,
`None` = slot not supported. `derive_steps` filters `store_rules` by which
slots are filled and wires deps automatically. Projects never write dep graphs
by hand.

## Execution Model

### Data flow

```
canary_main
  └─ run_llvm distro
       ├─ version_cache_tag → "dev_ab43cb8"
       ├─ canary_project_llvm.action_steps ~project:"llvm/dev_ab43cb8"
       │    └─ mk_script_spec ~source distro  →  script_spec
       │    └─ derive_steps                   →  action_step list
       └─ canary_action.run_project
            └─ run_graph
                 └─ run_step (per step, in dep order)
                      ├─ check_post  →  skip if already satisfied
                      ├─ check_pre   →  deps present?
                      ├─ exec cmd    →  writes to _out/canary/_local/<project>/<tag>/
                      └─ check_post  →  verify output
```

`derive_steps` is the bridge between the universal pattern table and actual
execution. It creates `action_step list` from a `script_spec` by:
1. Walking `store_rules` in order
2. Including a step iff the project filled in that slot
3. Computing deps from the filled slots (e.g. `build_binding` deps on
   `configure` if present, else `fetch_source`; also deps on `build_lib`
   or `fetch_lib` whichever is present)

### Step caching

Each step's output lives in `_out/canary/_local/<project>/<tag>/`. A step is
skipped if its `check_post` already passes. `check_post` has two layers:

1. **Default** — marker file in output dir (`build.ok`, `conf.ok`, etc.)
2. **Override** — project-specific external state probe. Examples:
   - `Configure`: `check_markers ["configure.ok"] || Sys.file_exists "<build>/CMakeCache.txt"`
   - `Build_lib/binding`: artifact existence in build tree (`libz3.so`, `z3ml.cmxa`, ...)
   - `Fetch/Publish Binding`: `Canary_pm_opam.is_installed ~pkg`

The override pattern `marker_ok || external_state_ok` means steps are skipped
even when `_out/` is cleared, as long as the external artifact is still valid.

### Step expectations

```ocaml
type step_expectation =
  | Expect_success
  | Expect_failure of { contains_any : string list }
  | Expect_symbols of { provided_lib : string; required : string list; missing : string list }
```

`Expect_failure` is used for probe steps that are expected to fail (e.g.
`llvm/19` probing with a dev example — OCaml API mismatch). `Expect_symbols`
runs `nm -D` on a shared library and checks symbol presence/absence — used
for C-level ABI mismatch detection.

### Multi-version sub-runs

A project runs multiple sequential sub-runs sharing one opam switch.
Example for LLVM:

| Sub-run | Source | Lib | Binding | Example | Expected |
|---------|--------|-----|---------|---------|----------|
| `llvm/dev_ab43cb8` | local checkout | dev libLLVM.so | `llvm.dev-shared` (packed) | `llvm_example_dev.ml` | pass |
| `llvm/19` | none (no source build) | `llvm-19-dev` (apt) | `llvm.19-shared` (opam) | `llvm_example_dev.ml` | **fail — API mismatch** |

Each sub-run has its own `_local/<project>/` directory. Sequential execution
avoids opam switch conflicts.

### `version_cache_tag`

For `ref_="HEAD"` source repos, the cache path tag is `dev_<6-char-hash>`
computed via `git rev-parse --short=6 HEAD`. This makes the cache
content-addressed — two checkouts at different commits get separate dirs.
Stable refs (git tags) use `repo.version` directly.

## Source and Build Spec

```ocaml
type local_path = {
  distro     : distro;
  path       : string;   (* source checkout root *)
  build_path : string;   (* associated build dir — source of truth *)
}

type source_repo = {
  name : string;
  remote : git_remote;
  locals : local_path list;   (* per-distro local checkouts *)
  version : string;
  ref_ : string;
  has_build_lib : bool;
  has_build_binding : bool;
}
```

`build_path` is the single authoritative build dir for a checkout. Default
layout is sibling (`../build` relative to source root), matching LLVM's
convention. Z3 uses the same. `mk_locals ?(build_dir="../build") rel_path`
generates entries for all distros from a relative path.

`CANARY_BUILD_DIR` is the **mechanism** to pass `build_path` into the opam
sandbox boundary; `build_path` is the **source of truth** in the spec.
`CANARY_SRC_DIR` passes the source root for cmake `-S` so configure
re-invocations match the existing cache (opam sandbox mounts external paths
read-only via bwrap, so cmake cannot write to `$CANARY_BUILD_DIR`; the
guard `test -f <artifact> || cmake ...` skips configure when already done).

## Pattern Table

The 14 structural action patterns enumerated from `store_rules`. Universal —
every project is a subset. Generated by `canary paths` / `canary paths-md`.

| id | d | origin | target  | action_path                                                                       | freq      |
|----|---|--------|---------|-----------------------------------------------------------------------------------|-----------|
| 1  | 1 | store  | source  | fetch_source                                                                      | tbd       |
| 2  | 1 | store  | lib     | fetch_lib                                                                         | common    |
| 3  | 2 | build  | lib     | fetch_source → build_lib                                                          | common    |
| 4  | 1 | store  | binding | fetch_binding                                                                     | common    |
| 5  | 2 | build  | binding | fetch_lib → build_binding                                                         | common    |
| 6  | 3 | build  | binding | fetch_source → build_lib → build_binding                                          | common    |
| 7  | 1 | store  | app     | fetch_app                                                                         | common    |
| 8  | 3 | build  | app     | fetch_binding, rt:fetch_lib → build_app                                           | important |
| 9  | 3 | build  | app     | fetch_lib → build_binding → build_app                                             | common    |
| 10 | 4 | build  | app     | fetch_binding, rt:fetch_source → build_lib → build_app                            | important |
| 11 | 4 | build  | app     | fetch_lib → build_binding, rt:fetch_lib → build_app                               | important |
| 12 | 4 | build  | app     | fetch_source → build_lib → build_binding → build_app                              | common    |
| 13 | 5 | build  | app     | fetch_lib → build_binding, rt:fetch_source → build_lib → build_app                | important |
| 14 | 5 | build  | app     | fetch_source → build_lib → build_binding, rt:fetch_lib → build_app                | important |
| 15 | 6 | build  | app     | fetch_source → build_lib → build_binding, rt:fetch_source → build_lib → build_app | important |

`important` = runtime lib version differs from build-time lib (version mismatch
path). `Configure` is a prerequisite for build steps but not a separate row —
it always precedes `build_lib`/`build_binding` when present.

Every pattern has two universal terminals (not separate rows):
- **probe**: `action_path → probe_<kind>` (d+1) — tests the artifact
- **publish**: `action_path → publish_<kind>` (d+1) — packages for a store

## Store Model

A **store** is any place an artifact lives. `fetch` is always transport between
two stores. What differs across PMs and source is the level of indirection.

```
PM world:    remote_index ──[manager]──→ local_cache ──[install]──→ artifact
Source world: remote_origin ──[manual]──→ local_copy  ─────────────→ artifact
```

Package managers (apt, brew, opam) add a **manager** between remote and local
stores — a registry, index, and collection view. Source has no manager: each
repo is fetched directly, no registry tracks what repos exist.

`package_manager` describes the remote store type + managed transport.
`source_repo` describes the remote store type + ad-hoc transport (git clone,
local path). Both produce the same thing: a local artifact for the next action.
The pattern table treats `fetch_source` and `fetch_lib` as structurally identical.

### Opam sandbox

opam's bwrap sandbox (active even on WSL — `wrap-build-commands` is set
globally) mounts the entire filesystem **read-only** except `$PWD` (rw),
`/tmp` (rw bind), ccache and dune cache dirs (rw). `TMPDIR` is redirected
to `/opam-tmp` (tmpfs). External `CANARY_BUILD_DIR` paths are readable but
not writable — cmake configure (which always writes to the build dir) must
be guarded with `test -f <artifact> || cmake ...`.

## Version Resolution Chain

When a lang PM package (e.g. `llvm.19-static`) depends on a system library
(e.g. `llvm-19-dev`), version must be resolved across multiple layers:

```
System PM       Locator            Conf package     Lang binding
────────────    ────────────────   ──────────────   ─────────────
apt install     llvm-config-19     conf-llvm.19     llvm.19-static
  llvm-19-dev     --version          configure.sh     (opam)
                  → "19.1.7"         → finds locator
                                     → validates ver
```

**Four layers, three seams:**

| Layer | Responsibility | Discovery mechanism |
|-------|----------------|---------------------|
| System PM | Install files to disk | `dpkg -s`, `brew list` |
| Locator | Report version + paths | `llvm-config`, `pkg-config`, `brew --prefix` |
| Conf package | Validate system dep for lang PM | `configure.sh`, opam `depexts` |
| Lang binding | Compile + link against lib | `ocamlfind`, `-package` |

The **locator** is the pivot — everything upstream is system PM's
responsibility; everything downstream trusts what the locator reports.

**Common locator patterns:**

| Locator | Used by | Reports |
|---------|---------|---------|
| `pkg-config` | Most C libs (gmp, sqlite, zlib) | `--modversion`, `--cflags`, `--libs` |
| `llvm-config` | LLVM | `--version`, `--prefix`, `--ldflags` |
| `brew --prefix <pkg>` | brew-installed libs on macOS | install path |
| cmake `find_package` | cmake projects (z3) | sets cmake variables |

**Where mismatches happen:**

1. **System PM → Locator**: Multiple versions installed, wrong one found.
   Fix: use versioned locator (`llvm-config-19`).
2. **Locator → Conf**: Conf searches for locator with hardcoded order;
   may fall back to `llvm-config` and find wrong version.
3. **Conf → Binding**: Conf passes wrong version info → binding compiles
   against wrong headers. May succeed but produce runtime failures.

Currently, locator logic is embedded in project shell commands. A first-class
`package_locator` type (see open design) would make this explicit and testable.

## Opam Template Taxonomy

Two patterns for canary local opam packages (in `canary/templates/opam-local-repo/`):

**Build from source** (e.g. `z3.dev`): cmake + ninja in opam build phase.
Used when the official opam package also builds from source and canary needs
a dev/HEAD variant. Guards cmake with `test -f <artifact> || cmake ...` so the
opam sandbox's read-only external path doesn't block reuse of canary's pre-built
artifacts.

**Install pre-built** (e.g. `llvm.dev-shared`): copies pre-built artifacts
from `CANARY_BUILD_DIR` into the opam prefix. No cmake invocation — all
build work done by prior canary steps. Analogous to a binary opam package.

Both patterns share the same `pack_binding` preamble (opam repo add/update,
remove old, install). This preamble is currently inlined in each project's
`pack_binding` shell command; TODO #28 proposes lifting it into
`Canary_ocaml.opam_pack_cmd`.

## Open Design

### Package locator as first-class type (TODO #29)

Locator logic is currently embedded in project shell commands. Factoring it
out would make the System PM → Locator → Conf chain testable and uniform:

```ocaml
type discovery_method =
  | Pkg_config of string      (* pkg-config <name> *)
  | Brew_prefix of string     (* brew --prefix <formula> *)
  | Llvm_config of string     (* llvm-config-<ver> --prefix *)
  | Env_var of string         (* $FOO_PREFIX already set *)

type package_locator = {
  name       : string;
  system_pkg : system_package_spec;
  discovery  : (distro * discovery_method) list;
  version_cmd : string option;
}
```

Plugs into `fetch_lib` / `configure` steps. On macOS, keg-only libraries
need `PKG_CONFIG_PATH` set before downstream phases — the locator captures this.

### Store config type (TODO #30)

A project's store entries are currently hardcoded in `mk_script_spec`. A
first-class `store_config` would make `fetch_*` and `pack_*` slot generation
automatic from declarations:

```ocaml
type store_entry = {
  pm       : package_manager;
  pkg_name : string;
  primary  : artifact_kind;
}
type store_config = store_entry list
```

`derive_steps` could then generate `fetch_lib`, `fetch_binding`, etc. from
`store_config` rather than from the script_spec slots directly.

### C API surface model (TODO #31)

Currently, symbol mismatch expectations (`Expect_symbols { required; missing }`)
are hand-written per probe step. A declarative C API surface model would make
them derivable from version metadata:

```ocaml
type api_surface = {
  version   : string;
  symbols   : string list;   (* from nm -D or clang AST dump *)
}
```

Given two API surfaces (lib version, binding built-against version), the
expected `missing` symbols can be computed automatically. Foundation: TODO #20
(`assert_binary_symbols.py --provided-lib-old/new`).

### Auto-generated project configs (TODO #32)

Given a project sketch (library name, binding languages, package manager
presence, source repo layout), generate the full `script_spec` automatically.
Depends on locator (#29), store config (#30), and C API surface (#31).

## Design Principles

1. **Configuration is primary, backends are derived.** The main product is a
   structured compatibility model, not the generated YAML/shell.

2. **`script_spec` is the only project-specific thing.** The runner, dep
   graph, caching, and logging are project-agnostic. A project is just a
   filled-in `script_spec`.

3. **External state, not a separate database.** `check_post` probes real
   external state (cmake cache, opam package index, build artifacts) rather
   than maintaining a separate tracking database.

4. **Gradual abstraction.** Extract patterns from concrete projects. Every
   abstraction must be validated by at least two examples.

5. **Explicit version boundaries.** Make compatibility seams visible: lib
   version, binding build version, runtime lib version. The pattern table's
   `important` rows are exactly the seams where mismatches happen.
