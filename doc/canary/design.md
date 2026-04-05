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

```text
canary_basic_store    Store types: package_manager, location
    |
canary_basic          Core types, step constructors, backend utilities
    |
canary_basic_ocaml    OCaml toolchain types, command generation
    |
canary                project_config, resolve_phase, make_job, action_rule
    |
canary_project_*      Per-project configs (z3, sqlite)
    |
canary_run            Runner: dump, render, deploy
```

### Pipeline

```text
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

**`phase_kind`**: What the phase does. Each variant is a declarative
primitive — `resolve_phase` is the only place that converts them into
concrete `string step` lists.

| Phase kind         | Semantics                     | `resolve_phase` behavior                                        |
| ------------------ | ----------------------------- | --------------------------------------------------------------- |
| `Pm_install`       | Install via system or lang PM | Dispatches on `location` (System_pm → apt/brew, Lang_pm → opam) |
| `Pm_install_local` | Install from local PM repo    | Takes explicit `package_manager` arg                            |
| `Cmake_buildgen`   | CMake configure / build-gen   | Passthrough (carries a `string step`)                           |
| `Cmake_build`      | CMake build                   | Passthrough (carries a `string step`)                           |
| `Probe_test`       | Smoke-test a language binding | OCaml: compile×run matrix; Python: import-and-print             |
| `Run_command`      | Run an arbitrary command      | Wraps in `run_step`                                             |

**`ocaml_tool_config`**: Per-project OCaml config:
`{ toolchain : opam_spec; ocaml : ocaml_binding; prebuilt : prebuilt_info option }`

**Key enumerations**:

- `location = Build_tree | System_pm | Lang_pm | Wild of string`
- `compile_mode = Native | Bytecode`
- `probe_action = Compile_example | Run_example`
- `all_cc_and_modes`: cartesian product of modes and probe actions

**Artifact graph types** (in `canary_basic.ml`):

```ocaml
type artifact_node = {
  a_kind : artifact_kind;     (* Lib | Binding | App | ... *)
  a_name : string;
  origin : location;          (* where it was made *)
  a_location : location;      (* where it is now *)
  built_from : artifact_node option;  (* compile-time dependency *)
  runtime_dep : artifact_node option; (* runtime dependency, differs from built_from *)
}

type artifact_op = Compile | Fetch | Pack | Test
```

Node identity includes the full `built_from` chain: `binding@build_tree(lib@system_pm)`
is a different artifact from `binding@build_tree(lib@build_tree)`.

**Graph derivation** (in `canary.ml`):

- `graph_of_job_specs`: walks job spec phases, converts `produces`/`requires`
  artifacts into `artifact_node`s with `built_from` threading, deduplicates
  across jobs by `node_tag`.
- `edges_of_nodes`: derives edges from node properties — `origin ≠ location` →
  Pack, source origin → Compile, otherwise → Fetch. Lib/Binding/App kinds
  also get Test edges.

### Current Status

- **z3**: `source-source` (P1, disabled), `prebuilt-source` (P2),
  `prebuilt-packaged` (P4). Missing: `source-packaged` (P3),
  `prebuilt-prebuilt` (P5).
- **sqlite3**: `prebuilt-prebuilt` (P5) only.

## Job Space

A **job = pattern × input**. Patterns are structural skeletons; inputs
are versioned artifacts. We describe the space using introduction and
elimination forms.

### Artifacts (sorts)

| Sort      | Properties                            | Notes                                         |
| --------- | ------------------------------------- | --------------------------------------------- |
| `Source`  | name, version                         | Project source tree. Always local.            |
| `Lib`     | name, version, origin, location       | Native/C library (`.so`/`.dylib`/`.a`).       |
| `Binding` | name, version, origin, location, lang | Language-specific wrapper over a `Lib`.       |
| `App`     | name, version, origin, location       | App pairing a `Binding` with a runtime `Lib`. |

Every artifact carries **version**, **origin** (where it was made), and
**location** (where it is now). `Source` is always at `Build_tree`.

**Package managers** (PM) provide artifacts from stores. The content inside
a package can be a `Lib`, `Binding`, or `App` — e.g. `libsqlite3-dev` (apt)
and `sqlite3` (opam) both deliver a `Lib`, but through different PMs.
System PMs (apt, brew) typically package `Lib`s; language PMs (opam, pip)
typically package `Binding`s or `App`s, though the boundary is blurry.

### Operations (typed)

Each operation has typed inputs and outputs. A job is any well-typed
composition of operations that produces a `Result`. The type signatures
constrain which compositions are valid.

```text
build_lib       : Source(lib)             → Lib@bt
build_binding   : Source(stub) × Lib      → Binding@bt
build_app       : Binding × Lib(runtime)  → App
fetch           : Store × name × version  → Lib@store | Binding@store | App@store
probe           : Lib | Binding | App     → Result
```

Notes:

- `build_lib` and `build_binding` are logically distinct even when the
  build system (e.g. cmake) executes them in one invocation.
- Source splits into `src-lib` (native library source) and `src-stub`
  (binding glue: C API headers + language-specific stubs).
- `fetch` output sort depends on what the store provides — system PMs
  typically yield `Lib`, lang PMs yield `Binding` or `App`.
- `build_app` takes two inputs: a binding (compile-time) and a runtime lib.
  The runtime lib may differ from the lib used to compile the binding.
- `Source` is always available (axiom). Conceptually, `SRC` is just
  another store (`git clone` = fetch).
- `probe` tests each artifact kind independently: `probe_lib` validates
  the built library, `probe_binding` the binding, `probe_app` the app.

### Action Rule Model

The job space is described by an **action rule**: a list of typed rules
processed in order, building artifact pools incrementally. Each rule either
produces artifacts (adding to a pool) or consumes them (probe).

```ocaml
type rule =
  | Build_lib                  (* Source(lib) → Lib pool *)
  | Build_binding              (* Source(stub) × Lib pool → Binding pool *)
  | Build_app                  (* Binding pool × Lib pool(runtime) → App pool *)
  | Fetch of artifact_kind     (* Store → pool of that kind *)
  | Probe of artifact_kind     (* pool → Result *)
```

A **store** abstracts all external artifact sources (system PM, lang PM,
source repo). `SRC` is conceptually a store too (`git clone` = fetch).
All stores are unified — the diagram can toggle store visibility since
it's universal.

**Pool construction**: Rules fold left over an accumulator of
`(artifact_kind * artifact_node list) list`. Each `Build_*` or `Fetch`
rule reads upstream pools and adds to its output pool. `Build_app` crosses
the binding pool with the lib pool (runtime dep ≠ compile-time dep).
`Probe` consumes but doesn't produce.

**Version as control variable**: Each artifact carries a version
(`Dev`, `Stable`, ...). The same rule list with `[Dev]` vs
`[Dev; Stable]` produces different pool sizes — the combinatorics
are handled by pool construction, not by listing traces manually.

**Standard rule lists**:

```ocaml
(* With build_app *)
store_rules = [
  Build_lib; Fetch Lib; Build_binding; Fetch Binding;
  Build_app; Fetch App;
  Probe Lib; Probe Binding; Probe App;
]

(* Without build_app *)
store_rules_no_pack = [
  Build_lib; Fetch Lib; Build_binding; Fetch Binding;
  Fetch App;
  Probe Lib; Probe Binding; Probe App;
]
```

**Equivalence with expression enumeration**: The action rule model
produces the same deduped artifact sets as the previous expression-based
enumeration (T1–T9 traces), verified across all 4 configurations
(single/two versions × with/without pack). The expression code has been
removed; see `doc/canary/expression_sharing_note.md` for background on
the DAG/tree duality between shared pools (action rule) and unfolded
expressions.

**Compositionality**: `rule list` is the free monoid — sequential
composition via `@`. This is sufficient for the current linear pipeline.
Recursive `action_rule` would only be needed for parallel branches or
conditionals, which we don't have.

### Not yet covered

- **Downstream dependencies**: package B depends on package A (chained
  fetch within the lang PM).
- **Multi-lib inputs**: `compile_binding` takes multiple `Lib`s.
- **Lib packaging**: `pack(Lib)` for redistribution (`.deb`/`.rpm`).

### Action Rule → Job Derivation (gap)

**Current state**: Two parallel paths exist for job enumeration:

1. **Action rule** (`make_action_rule`): folds `rule list` over pools,
   producing `artifact_node` sets. Used for diagram rendering and
   counting. This matches the diagram.
2. **Manual job specs** (`canary_project_*.ml`): hand-written
   `step_phase` lists in each project config. Used for actual job
   generation via `make_job`.

These are disconnected — the action rule enumerates *what* artifacts
exist, but doesn't drive *which jobs* get generated. Job specs are
written independently and may drift from the action rule model.

**Goal**: Three equivalent representations of the job space, each
serving a different purpose:

1. **Table** (reference): The universal maximum enumeration of all
   structurally possible job paths from a rule list. Can be generated
   once and annotated with metadata — whether a case is common or
   rare, feasible or meaningless in practice, covered by existing
   tests or not. The table is checkable before any project spec.
2. **Algorithm** (`make_action_rule`): Derives the same set
   programmatically by folding rules over pools. Must produce results
   equivalent to the table — verifiable by comparison.
3. **Diagram** (`mermaid_of_action_rule_schema`): Visual rendering of
   the same structure. Already data-driven from the rule list.

**Table structure**: Each row is a structural action pattern — the
unique chain of build/fetch operations to produce one artifact kind.
Columns:

- `d` — depth (number of actions)
- `action_path` — full chain of actions from source to target
  (`rt:` prefix marks runtime dependencies that differ from the
  build chain)
- `freq` — `common` or `important` (version mismatch cases)
- `versions` — how many version combinations instantiate this
  pattern (shown for 2 versions; with N versions the counts scale
  by version dimensions per artifact kind)

Rows sorted by target kind, then depth. Two universal endings
apply to every artifact row:

Terminal actions (apply to every artifact, not separate rows):

- **pack**: action_path → pack\_\<kind\> (depth = d+1) —
  packages the artifact for a store.
- **probe**: action_path → probe\_\<kind\> (depth = d+1) —
  tests the artifact. `probe_binding` and `probe_app` also
  take a runtime lib (can differ from the link-time lib) —
  this catches version mismatch bugs early at the binding
  level before they surface in the full app.

15 structural patterns, 58 total artifacts (with 2 versions).

**Source of truth** — generated from `store_rules` by the code in
`canary.ml` (`pattern_rows_of_paths`, `pp_job_path_table_md`).
Regenerate with:

```bash
canary paths      # plain text
canary paths-md   # markdown table
```

| id  | d   | origin | target  | action_path                                                                       | description                                             | freq      | versions |
| --- | --- | ------ | ------- | --------------------------------------------------------------------------------- | ------------------------------------------------------- | --------- | -------- |
| 1   | 1   | store  | source  | fetch_source                                                                      |                                                         | tbd       | 2        |
| 2   | 1   | store  | lib     | fetch_lib                                                                         | lib from package manager                                | common    | 2        |
| 3   | 2   | build  | lib     | fetch_source → build_lib                                                          | build lib from source                                   | common    | 2        |
| 4   | 1   | store  | binding | fetch_binding                                                                     | binding from package manager                            | common    | 2        |
| 5   | 2   | build  | binding | fetch_lib → build_binding                                                         | build binding, lib from store                           | common    | 4        |
| 6   | 3   | build  | binding | fetch_source → build_lib → build_binding                                          | build binding, lib from build                           | common    | 4        |
| 7   | 1   | store  | app     | fetch_app                                                                         | pre-built app from package manager                      | common    | 2        |
| 8   | 3   | build  | app     | fetch_binding, rt:fetch_lib → build_app                                           | app: bind(store) + rt(store), version mismatch possible | important | 4        |
| 9   | 3   | build  | app     | fetch_lib → build_binding → build_app                                             | app: bind(build) + same rt lib                          | common    | 4        |
| 10  | 4   | build  | app     | fetch_binding, rt:fetch_source → build_lib → build_app                            | app: bind(store) + rt(build), version mismatch possible | important | 4        |
| 11  | 4   | build  | app     | fetch_lib → build_binding, rt:fetch_lib → build_app                               | app: bind(build) + rt(store), version mismatch possible | important | 4        |
| 12  | 4   | build  | app     | fetch_source → build_lib → build_binding → build_app                              | app: bind(build) + same rt lib                          | common    | 4        |
| 13  | 5   | build  | app     | fetch_lib → build_binding, rt:fetch_source → build_lib → build_app                | app: bind(build) + rt(build), version mismatch possible | important | 8        |
| 14  | 5   | build  | app     | fetch_source → build_lib → build_binding, rt:fetch_lib → build_app                | app: bind(build) + rt(store), version mismatch possible | important | 8        |
| 15  | 6   | build  | app     | fetch_source → build_lib → build_binding, rt:fetch_source → build_lib → build_app | app: bind(build) + rt(build), version mismatch possible | important | 4        |

**Annotations** (per row or per group):

- `common` — same version flows through build and runtime
- `important` — version mismatch between build-time and runtime lib
- `feasible` / `infeasible` — whether the combination is meaningful
- `covered` / `uncovered` — whether existing project specs exercise it

**Instantiation**: The 14 structural patterns are universal. A
concrete job set is produced by multiplying patterns with
**instantiation dimensions** — all of which are project-level
configuration, not structural:

1. **Versions** — how many version variants to test (1, 2, …).
   Already modelled: the `versions` column shows counts for 2.
2. **Store config** — which `(artifact_kind, package_manager)`
   pairs exist for this project. Determines which `fetch_*` and
   `pack_*` actions are concretized.
3. **Project capabilities** — has source? can build? which
   binding languages? Filters which patterns are applicable.

```text
pattern table     ──select──→    applicable    ──instantiate──→  job_specs
(14 universal)     (project:      patterns       (project:
                    caps,                          versions,
                    store_config)                   pkg names,
                                                   flags)
```

### Store Model

The fundamental unit is a **store** — a place where artifacts live.
A **fetch** is always a transport between two stores: a remote store
and a local store. What differs across package managers and source
is the level of indirection above the stores.

```
PM world:     remote_store ──[manager]──→ local_store ──[install]──→ artifact
Source world:  origin       ──[manual]───→ local_copy  ────────────→ artifact
```

**Package managers** (apt, brew, opam) are really two stores — a
remote index and a local cache — with a **manager** mediating
between them. `apt install` is shorthand for "fetch from remote
store → install to local store." The manager is the interface; the
stores are the reality underneath. The manager provides a collection
view: `apt list`, `opam list` — you query the manager, not
individual packages.

**Source/git** has the same two stores — a remote origin (GitHub
repo, tarball URL, local path) and a local checkout — but **no
manager**. Each source is fetched independently and directly. There
is no registry, no index, no collection view. Nobody "tracks" that
there is a z3 source or a sqlite source.

The manager is a property of how stores are **connected**, not a
property of the stores themselves. This means:

- `package_manager` (Apt, Brew, Opam) describes the remote store
  type + managed transport for packages.
- `source_method` (Local_path, Git_tag, Archive) describes the
  remote store type + ad-hoc transport for source.

Both produce the same thing: a local artifact ready for the next
action. The pattern table doesn't care which — `fetch_source` and
`fetch_lib` are structurally identical actions.

**Implementation**: `pm_install_cmd` and `source_fetch_cmd` in
`canary_basic_store.ml` generate the concrete shell commands for
each transport type. Project specs declare what they need (a PM
package name, or a source entry), and the store layer handles how.

### Version Resolution Chain

When a lang PM package (e.g. opam `llvm.19-static`) depends on a
system library (e.g. `llvm-19-dev`), the version must be resolved
across multiple layers. Each layer has its own discovery mechanism:

```
System PM        Locator           Conf package      Lang binding
─────────────    ─────────────     ──────────────    ──────────────
apt install      llvm-config-19    conf-llvm.19      llvm.19-static
  llvm-19-dev      --version         configure.sh      (opam)
                   → "19.1.7"        → finds locator
                                     → validates ver
```

**Four layers, three seams:**

| Layer | Responsibility | Discovery mechanism |
|-------|---------------|---------------------|
| System PM | Install files to disk | `dpkg -s`, `brew list` |
| Locator | Report version + paths | `llvm-config`, `pkg-config`, `brew --prefix` |
| Conf package | Validate system dep for lang PM | `configure.sh`, opam `depexts` |
| Lang binding | Compile + link against lib | `ocamlfind`, `-package` |

The **locator** is the pivot point — it sits between the system PM
and the lang PM. Everything upstream of the locator is system PM's
responsibility; everything downstream trusts what the locator reports.

**Common locator patterns:**

| Locator | Used by | Reports |
|---------|---------|---------|
| `pkg-config` | Most C libs (gmp, sqlite, zlib) | `--modversion`, `--cflags`, `--libs` |
| `llvm-config` | LLVM | `--version`, `--prefix`, `--ldflags` |
| `brew --prefix <pkg>` | brew-installed libs on macOS | install path |
| cmake `find_package` | cmake projects (z3) | sets cmake variables |
| `ocamlfind query` | OCaml packages | install path |

**Where version mismatches happen (the seams):**

1. **System PM → Locator**: Multiple versions installed, wrong one
   found. E.g., `llvm-config` points to v23 but `llvm-19-dev` is
   installed. Fix: use versioned locator (`llvm-config-19`).

2. **Locator → Conf**: Conf package searches for locator with
   hardcoded search order. E.g., `conf-llvm-static.19/configure.sh`
   tries `llvm-config-19`, `llvm-config19`, etc. If none match,
   falls back to `llvm-config` and checks version. The search
   logic is in the conf package, not controlled by the user.

3. **Conf → Binding**: Conf passes version info to binding via opam
   variables. If conf finds the wrong version (seam 2), the binding
   compiles against wrong headers/libs. May succeed but produce
   runtime errors.

**Who controls the version?**

No single layer decides. The system PM installs files, the project
decides how to find them (locator choice), the lang PM wraps the
discovery (conf package). Canary's role is to test each seam:

- Does the locator resolve to the expected version?
- Does the conf package find the right locator?
- Does the binding compile and link correctly?

**Easy escape via locator**: If the locator can be explicitly
specified (e.g., `LLVM_CONFIG=/usr/bin/llvm-config-19`), the
downstream layers follow. But this only works if the conf package
respects the env var — many don't (they have their own search
logic). This is a design opportunity: canary could standardize
locator overrides across projects.

**Implementation status**: `canary_basic_apt.ml`,
`canary_basic_brew.ml`, `canary_basic_opam.ml` have the primitive
commands for querying installed versions. The locator layer is
project-specific (not yet factored into the framework). The PM
primitive test script (`canary/scripts/test_pm_primitives.sh`)
validates the system PM and opam layers. Locator testing is next.

### Store Config (design choice)

Package format is **not** a structural dimension — it belongs to
the instantiation step. The pattern table says "fetch_lib" without
specifying which store. The store config maps that to concrete
stores:

```ocaml
type store_entry = {
  pm : package_manager;
  pkg_name : string;               (* e.g., "z3", "libz3-dev" *)
  primary : artifact_kind;         (* what you're fetching for *)
  provides : artifact_kind list;   (* all artifacts this produces *)
  locate : artifact_kind -> string option;
    (* how to find a side-effect artifact after install *)
}

type store_config = store_entry list
(* e.g., z3:
   [ { pm = Brew; pkg_name = "z3"; primary = Lib;
       provides = [Lib];
       locate = fun Lib -> Some "$(brew --prefix z3)/lib"
              | _ -> None };
     { pm = Apt; pkg_name = "libz3-dev"; primary = Lib;
       provides = [Lib];
       locate = fun _ -> None };
     { pm = Opam; pkg_name = "z3"; primary = Binding;
       provides = [Binding; Lib];
       locate = fun Lib -> Some "$(opam var z3:lib)" | _ -> None };
     { pm = Pip; pkg_name = "z3-solver"; primary = Binding;
       provides = [Binding; Lib];
       locate = fun Lib -> Some "<bundled>" | _ -> None };
   ] *)
```

A single `opam install z3` serves as both `fetch_binding` and
`fetch_lib`. The runner deduplicates: the command runs once, and
both `fetch_binding` and `fetch_lib` share the cached result
(same output_dir or cross-referenced). The `locate` function
tells downstream steps where to find side-effect artifacts.

**Key insight**: a single `fetch_lib` pattern row can produce
multiple concrete jobs — one per store entry for Lib. Similarly,
`pack_lib` produces one job per target store. The packing step
is store-specific (dpkg vs opam vs pip produce different
artifacts), but the structural pattern is the same.

**Combinatorics at instantiation**:

- Pattern row × versions × store entries for that kind
- Example: pattern #5 (`fetch_source → build_lib`) with 2
  versions and `Lib` packable to {apt, brew, opam} produces
  2 × 3 = 6 pack jobs (but still 2 build jobs — pack
  multiplies only the pack/fetch actions, not the build chain)

**Package as property, not kind**: The packed artifact wraps
the original (e.g., dpkg adds metadata, file layout, dependency
declarations). This is modelled as a property on the artifact
node (`packaged : (package_manager * string) option`), not as a
separate artifact kind. The store config determines which
packaging methods are tested.

**Action vs transport**: `pack` and `probe` are interesting
actions (can fail, worth testing). `fetch` and `publish` are
transport — moving artifacts between pools and stores. In the
diagram, `pack_*` and `probe_*` are action nodes; `fetch` and
`publish` are edge labels.

**Probing pack**: `pack_lib(opam)` can be probed by publishing
the pack, fetching it back, and testing — the round-trip test:
`build → pack(opam) → publish → fetch(opam) → probe`.
The store config determines which round-trips exist.

### Execution Model

The action graph is the execution plan — not the pattern table.
Each action runs once per unique input, and its output is shared
by all downstream consumers.

**Graph vs matrix**: The pattern table (14 rows) enumerates all
structural paths for verification. But execution doesn't run 14
independent jobs — it runs the ~9 distinct actions (per version
combo), each exactly once, with results cached and reused.

**Backend interface**: The graph needs one abstraction —
artifact sharing between action steps:

```text
graph (actions + deps)  ──backend──→  execution
                          │
                          ├─ local shell: filesystem cache
                          │   action outputs → directory per (action, version)
                          │   downstream steps read from cache
                          │
                          └─ GH CI: job DAG with artifact sharing
                              action → job, deps → needs:, outputs → upload/download
```

**Implementation plan**:

1. **Local runner** — execute the action graph directly.
   Each action step writes output to
   `_out/_canary/<project>/<action_tag>/`.
   Downstream steps read from upstream output dirs.
2. **Backend interface** — abstract artifact sharing:
   `run_action`, `store_output`, `load_input`. Local runner
   uses filesystem; GH CI maps to `upload/download-artifact`
   and `needs:` in generated YAML.
3. **Phantom project** — a mock project where every action is
   trivial (copy/rename). Tests the execution framework without
   real compilers or package managers.

### Action Step Protocol

Each action step has three parts:

1. **Precondition** (`check_pre`) — are inputs available?
   For given artifacts (source, packages from project spec),
   check they exist as-is. For generated artifacts, check the
   upstream output dir exists and is valid.
2. **Execute** (`run`) — perform the action. Output goes to
   `_out/_canary/<project>/<action_tag>/`.
3. **Postcondition** (`check_post`) — did it succeed?
   Check output dir has expected contents.

Given vs generated:

- **Given**: source code, system packages, prebuilt libs —
  declared in project spec, used as-is from their current
  location. Precondition = existence check.
- **Generated**: build outputs, packed artifacts — produced by
  action steps, stored in `_out/_canary/`. Precondition =
  upstream step completed.

State tracking (SQLite):

```sql
CREATE TABLE action_run (
  project    TEXT NOT NULL,
  action_tag TEXT NOT NULL,   -- e.g. "build_lib/v1"
  status     TEXT NOT NULL,   -- pending | running | done | failed
  output_dir TEXT,
  started_at TEXT,
  finished_at TEXT,
  PRIMARY KEY (project, action_tag)
);
```

A step runs only if its `action_run` row is missing or not
`done`. This gives caching for free — re-running the graph
skips completed steps.

### Phantom Project

A mock project where all actions succeed trivially:

- `fetch_source` → copy a template dir
- `build_lib` → copy source to `lib/` output
- `build_binding` → combine lib + source into `binding/`
- `build_app` → combine binding + lib into `app/`
- `pack_lib` → tar the lib dir
- `probe_lib` → check lib files exist

Purpose: test the execution framework, action graph traversal,
caching, and backend interface without external dependencies.
All actions are file copies/renames — deterministic and fast.

## Design Principles

1. **Configuration is primary, backends are derived.** The main product is a
   structured compatibility model, not the generated YAML/shell.

2. **Gradual abstraction.** Extract patterns from concrete jobs. Every
   abstraction must be validated by at least two examples.

3. **Explicit boundaries.** Make compatibility boundaries visible: upstream
   library, binding, package manager, artifact, environment.

## Completed

### Orthogonal Step Primitives (done)

**Problem**: The old `phase_kind` mixed abstraction levels.
`Configure_build of string step list` was a meaningless passthrough.
`Test_binding` was a magic expander hiding a cartesian product.
`Install_local` lacked a package manager argument.

**What changed**:

- `Install_pkg` / `Install_local` → `Pm_install of system_pkg option` +
  `Pm_install_local of package_manager`. Registry install and local install
  are semantically distinct; local now takes an explicit PM argument.
- `Configure_build of string step list` → two flat primitives:
  `Cmake_buildgen of string step` and `Cmake_build of string step`. Each
  Z3 job spec now lists separate phases for cmake configure and build, with
  `run_step` called inline at the usage site. No intermediate record type
  or helper function needed.
- `Test_binding` → `Test of { lang : binding_lang }`. The resolver dispatches
  on `lang` (currently OCaml via `mk_ocaml_test_steps`; Python is stubbed).
- `Run_command` unchanged.

**Design rationale**: We chose flat primitives over a structured
`build_system` type (Cmake/Dune/Make) because only cmake is currently used.
When a second build system appears, we can introduce a shared abstraction
validated by two examples. The flat approach keeps `resolve_phase` trivial —
`Cmake_buildgen` and `Cmake_build` are simple passthroughs.

### Probe Test and Name Derivation (done)

- Renamed `Test` → `Probe_test` — honest about scope (smoke test, not a
  test suite). OCaml expands to compile×run × bytecode×native. Python
  expands to a single import-and-print.
- Promoted Z3's Python `Run_command` to `Probe_test { lang = Python }`.
  The resolver derives the import command from `binding_lib_name`.
  `Run_command` remains as an escape hatch (currently unused).
- Added `name_of_phase : step_phase -> string` — derives step names from
  phase kind + location instead of hardcoding them at each call site.
  `install_system_dep_steps`, `install_opam_package_step`, and the
  `Pm_install_local`/`Probe_test` arms all use the derived name.

### Local Runner and Install Verification (done)

**Local runner**: `canary_exec` and `canary_exec:<project>` generate shell
scripts and execute them locally. The shell backend's `$GITHUB_ENV`
simulation and guard filtering (macOS vs Linux) work correctly. On macOS,
only macOS-guarded steps run.

**Phase verification** (`verify_of_phase`): Each phase kind can derive
verification steps from its semantics — the action's actor confirms its
own effect. `resolve_phase` calls `verify_of_phase` after the action steps
and appends any verification steps automatically.

Verification inherits the phase's `expectation`: if the install is expected
to succeed, the verification expects the package to be present. If the
install is expected to fail, the verification expects it to be absent.

Currently implemented for PM install phases:

- `Pm_install` at `System_pm`: `dpkg -s <pkg>` (Linux), `brew list <pkg>` (macOS)
- `Pm_install` at `Lang_pm`: `opam list <pkg> --short`
- `Pm_install_local Opam`: `opam list <pkg> --short`

Remaining phase kinds return `[]` (no verification yet). Future candidates:

- `Cmake_build`: check build artifact exists (`test -f <path>`)
- `Cmake_buildgen`: check build system files generated
- `Probe_test` / `Run_command`: self-verifying, no additional verification needed

### Artifact Graph from Job Specs (done)

- `graph_of_job_specs` derives artifact graphs from job spec `produces`/`requires`
  fields, replacing the need for manual `build_graph` construction.
- `edges_of_nodes` extracted as reusable edge derivation: `origin ≠ location` →
  Pack, source origin → Compile, otherwise → Fetch. Lib/Binding/App get Test edges.
- Tightened `produces`/`requires` in z3 and sqlite job specs for precise
  dependency tracking.
- Hardcoded `build_graph` kept as `<project>_reference.mmd` for comparison;
  derived graphs saved as `<project>.mmd`.

## Next Steps

### 1. Decouple Hardcoded Packages (partial)

**Problem**: Shared code contains project-specific details.

**Done**:

- Z3-specific specs (`z3_dev_spec`, `z3_stable_spec`, distro roots)
  moved from `canary_basic.ml` to `canary_project_z3.ml`.
- Opam paths parameterized: `mk_canary_config ~pkg_name ~versioned_name`
  replaces hardcoded `/opam-local-repo/packages/z3/z3.dev/opam`.
- Store-related types extracted to `canary_basic_store.ml`.

**Remaining**:

- Python probe hardcodes `PYTHONPATH="build/python"` (cmake-specific)
- `ocaml_cc_with_obj` hardcodes `-package zarith` (z3-specific)
- `install_and_prefix_cmds` assumes pkg-config/brew patterns

These need fields in `ocaml_tool_config` or a new `python_tool_config`.

### 2. First-Class Package Locator

**Problem**: Package discovery is scattered across project configs. Z3 uses
cmake find_package + env vars. SQLite uses pkg-config (implicitly, via
conf-sqlite3). Homebrew keg-only libraries need explicit `PKG_CONFIG_PATH`.
The survey (`packaging_study.md`) confirms pkg-config is the #1 failure point
and keg-only handling is the #1 macOS friction.

**Goal**: Model package discovery as a first-class entity, reusing existing
canary types. A locator is not a new abstraction layer — it's a tool that
`Pm_install` and `Cmake_buildgen` phases use to find libraries.

**Design — reuse existing types**:

The locator produces artifacts consumed by later phases. It maps to our
existing `location` and `package_manager` types:

```ocaml
type discovery_method =
  | Pkg_config of string              (* pkg-config <name> *)
  | Brew_prefix of string             (* brew --prefix <formula> *)
  | Cmake_find of string              (* find_package(<Name>) *)
  | Env_var of string                 (* $FOO_PREFIX already set *)
  | Compile_test of string            (* compile a test .c file *)

type package_locator = {
  name : string;                      (* human label: "sqlite3", "z3" *)
  system_pkg : system_pkg;            (* reuses existing type *)
  discovery : (runner_os * discovery_method) list;
  version_cmd : string option;
  keg_only : bool;                    (* macOS: needs PKG_CONFIG_PATH *)
}
```

`system_pkg` already exists (`{ linux_pkg; macos_pkg }`). The locator adds
*how to find it after install*. On macOS with `keg_only = true`, the resolver
emits `PKG_CONFIG_PATH=$(brew --prefix <formula>)/lib/pkgconfig` before
downstream phases.

**How it plugs in**:

- `Pm_install` gains an optional `locator` field (replaces bare `system_pkg`)
- `resolve_phase` for Pm_install: install via system PM, then run discovery
  method to set PREFIX/LIBDIR env vars
- Current `install_and_prefix_cmds` logic moves into locator resolution

**Examples**:

```ocaml
(* SQLite: simple pkg-config, keg-only on macOS *)
let sqlite_locator = {
  name = "sqlite3";
  system_pkg = { linux_pkg = "libsqlite3-dev"; macos_pkg = "sqlite" };
  discovery = [
    (Ubuntu, Pkg_config "sqlite3");
    (MacOS,  Brew_prefix "sqlite");     (* keg-only *)
  ];
  version_cmd = Some "pkg-config --modversion sqlite3";
  keg_only = true;
}

(* Z3: cmake-based, not in system PM for source builds *)
let z3_locator = {
  name = "z3";
  system_pkg = { linux_pkg = "z3"; macos_pkg = "z3" };
  discovery = [
    (Ubuntu, Pkg_config "z3");
    (MacOS,  Brew_prefix "z3");
  ];
  version_cmd = Some "z3 --version";
  keg_only = false;
}
```

**Validation**: sqlite's keg-only handling should generate the same
`PKG_CONFIG_PATH` setup currently hardcoded in z3's cmake flags. Z3's
env-var-based discovery should match current `install_and_prefix_cmds` output.

### 3. C API Surface Model

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

### 4. Auto-Generated Project Configs

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

## Priority Order

1. **Decouple hardcoded packages** — remove project-specific details from shared code
2. **Package locator** — models real-world discovery, plugs into Pm_install
3. **C API surface** — makes expectations derivable
4. **Auto-generated configs** — end goal, requires 1–3

## References

- `doc/canary/packaging_study.md`: Real-world packaging patterns across
  apt, brew, opam, pip for Z3, SQLite, libffi, libgit2, OpenSSL, GMP,
  libsodium, PCRE2
- `doc/canary/opam_survey.md`: Deep survey of 4460 opam packages, 6 native
  library patterns (A–F), reproducible via `raw/survey.sh`
- `canary_dump` command: inspect fully resolved jobs before rendering
