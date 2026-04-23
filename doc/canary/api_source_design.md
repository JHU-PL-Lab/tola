# Canary: First-class API (binding interface) layer

**Status:** design doc. Not committed to an implementation yet.
Proposes elevating "the API the upstream project exposes" from an implicit
concept (hidden inside per-project `mk_script_spec` shell) into a typed
sub-object of `source_repo`.

This doc has two parts:
1. **Overview analysis** — what's implicit today, why first-class helps.
2. **Proposed code modifications** — concrete refactor once the model settles.

Related:
- [`artifact_summary_design.md`](artifact_summary_design.md) — current summary /
  watchlist model that this proposal would refactor
- [`interface_contract_design.md`](interface_contract_design.md) — broader
  interface-as-object vision; API-source is a concretisation for C/native projects
- [`batch_candidates.md`](batch_candidates.md) — each candidate has an API layer
  to declare once the model exists

## Part 1 — Overview analysis

### The conceptual shape

An upstream project that ships a native library typically has three layers:

```
┌───────────────────────────────────────┐
│  Source repo (z3/, llvm-project/, …)  │  ← Canary: source_repo (modelled)
└────────────────┬──────────────────────┘
                 │
                 ▼
┌───────────────────────────────────────┐
│  API provider                         │  ← Canary: IMPLICIT (not modelled)
│  - C headers (z3_api.h, llvm-c/*.h)   │     — lives inside mk_script_spec
│  - Symbol surface on libz3.so /       │       as hardcoded shell commands
│    libLLVM.so                         │     — watchlist partially represents it
│  - Binding generator (optional)       │
│  - Per-language build targets         │
└────────┬────────────┬─────────────┬───┘
         │            │             │
         ▼            ▼             ▼
    ┌─────────┐  ┌─────────┐  ┌─────────┐
    │ OCaml   │  │ Python  │  │ Rust    │   ← Canary: Binding (modelled)
    │ binding │  │ binding │  │ binding │     — one per language
    └─────────┘  └─────────┘  └─────────┘
```

**The API provider** is a single artifact per `(source, version)`. Every
language binding consumes the same API. In z3, it's the C API defined in
`src/api/*.h` and exposed as the `Z3_*` symbols on `libz3.so`. In LLVM, it's
`llvm/include/llvm-c/*.h` exposed as `LLVM*` symbols on `libLLVM.so`.

### Why it's not modelled today

Canary's `artifact_kind` is `Source | Lib | Binding | App`. The API isn't a
kind — it's smeared across Lib (symbols) and Binding (wrapper) without a
declarative home. Consequences:

| Symptom | Where visible |
|---------|---------------|
| Build target for each binding is hand-written shell in the project spec | `canary_project_z3.ml` has `ninja build_z3_ocaml_bindings` hardcoded; LLVM has `cmake_build_binding` flag threaded through |
| Watchlists mix API-level and consumer-level concerns | `z3_native_watchlist` is actually "stable Z3 C API symbols" (API-level); `z3_ocaml_watchlist` is "OCaml modules that wrap that API" (consumer-level) — no explicit distinction |
| Adding a new language binding duplicates structure | Python z3-solver would need its own `ninja build_z3_python_bindings` shell + its own watchlist + its own probe — nothing factors |
| No way to query "which API version does this binding consume" | The version is implicit in the source's `version_cache_tag`; the *API version* (which can differ if only bindings change) has no carrier |

### What "first-class API" buys us

1. **One declaration per API surface**, not per-binding. The Z3 C API's
   stability watchlist is written once in `z3_source.api_source`, not
   copy-pasted across OCaml/Python/Rust/Java binding specs.
2. **Build-target source of truth**. `ninja build_z3_ocaml_bindings` moves
   from hand-rolled shell into a typed binding_target entry. Adding
   `build_z3_python_bindings` is a data change, not a code change.
3. **Version-dependent API snapshot**. Each `(source_repo, version)` pair
   has a derivable API interface object — feeds directly into the
   `interface_contract_design.md` vision (L1a/L1b symbols, plus header
   definitions if we want them later).
4. **Binding consumers reference an API, not a source**. The OCaml binding
   spec says "I consume z3's v4.13 API" rather than "I know Z3 source
   version 4.13 has a build target named ...".
5. **Cross-binding drift becomes a typed diff**. If Z3's API changes between
   v4.13 → v4.15, canary reports "API changed, these consumers now
   affected" — mechanical rather than ad-hoc.

### What is and isn't API-source

**Is:**
- Public headers in the upstream source tree (canonical declarations)
- Exported symbol prefix(es) (`Z3_`, `LLVM*`, `sqlite3_`)
- Binding generator tool if the project auto-generates stubs (`scripts/mk_make.py`
  in z3; LLVM's `AddOCaml.cmake` ; none for sqlite)
- Per-language build target names (as understood by the upstream's build system)
- Stable-symbol watchlist — the "we claim these should survive version bumps"
  contract

**Isn't:**
- Per-language binding *code* (that's downstream, in the binding consumer)
- Per-language import/compile probes (those test a consumer, not the API)
- Watchlists of what bindings expose in OCaml/Python-land
  (`z3_ocaml_watchlist = ["Z3"]` is a consumer claim about Module structure,
  not an API claim)

### Concrete shape per project

| Project | API headers | Symbol prefix | Binding generator | OCaml build target | Python build target | Rust build target |
|---------|-------------|---------------|-------------------|---------------------|---------------------|-------------------|
| z3 | `src/api/z3_*.h` | `Z3_` | `python3 scripts/mk_make.py --ml` | `ninja build_z3_ocaml_bindings` | `cmake --build ... --target bindings/python` | (via `cxx-bridge`, out of z3's tree) |
| llvm | `llvm/include/llvm-c/*.h` | `LLVM` | none (headers hand-written) | `cmake --build ... --target OCaml_bindings_install` (via `AddOCaml.cmake`) | n/a (llvmlite has its own IR) | n/a (inkwell wraps, same API) |
| sqlite | `sqlite3.h` | `sqlite3_` | none | n/a (upstream has no OCaml binding; opam's `sqlite3` is external) | n/a (CPython bundles sqlite3) | n/a (`rusqlite` is external) |

Observation: sqlite's API is very stable across decades; z3's changes per
release; llvm's breaks often. The API-source object captures this *per project*
rather than leaving it as tribal knowledge in the project spec.

### Relation to existing canary pieces

- **`source_repo`** (`canary_artifact_source.ml`) currently has
  `name, remote, locals, version, ref_, official, has_build_lib,
   has_build_binding, build_sys_deps`. Adding `api_source : api_source option`
  is a minimal extension. The existing `has_build_binding` is a degenerate form
  of "this source knows how to build OCaml bindings" — would subsume into
  `api_source.binding_targets`.
- **`symbol_check` / `symbol_entry`** (`canary_action.ml`) is per-step; its
  watchlist would be seeded from `api_source.stable_symbols` rather than a
  project-spec-local constant.
- **`script_spec.summary`** is per-rule; for `Probe Lib` the watchlist comes
  from `api_source.stable_symbols` (the API-level claim) while for
  `Probe Binding` it comes from the per-binding watchlist (consumer claim).
  Today both are hardcoded in project specs.
- **`derive_steps`** would gain: if `source.api_source.binding_targets` has an
  entry for OCaml, the `build_binding` rule's command is derived from it, not
  supplied by `script_spec.build_binding`.

## Part 2 — Proposed code modifications

### New type sketch

```ocaml
(* In canary_artifact_source.ml or a new canary_api_source.ml *)

(* A language consumer of an API *)
type lang = OCaml | Python | Rust | Cpp | CSharp | Java | Julia

(* How the upstream builds its bindings for a given language *)
type binding_target = {
  target_name : string;                (* "build_z3_ocaml_bindings" *)
  builder : [`Ninja | `Cmake | `Make | `Script of string];
  extra_flags : string list;           (* e.g. -DZ3_BUILD_OCAML_BINDINGS=ON *)
  expected_outputs : string list;      (* relative paths: z3ml.cmxa, libz3ml.a, ... *)
}

(* Optional: how to generate binding stubs from headers *)
type api_generator = {
  tool : string;                       (* "python3 scripts/mk_make.py" *)
  inputs : string list;                (* ["src/api/z3_api.h"; ...] *)
  outputs_by_lang : (lang * string list) list;
}

(* The first-class API layer *)
type api_source = {
  headers_dir : string;                (* relative to source root: "src/api" / "llvm/include/llvm-c" *)
  header_glob : string;                (* "z3_*.h" / "*.h" *)
  symbol_prefixes : string list;       (* ["Z3_"] / ["LLVM"] *)
  stable_symbols : Canary_action.symbol_entry list;  (* the API-level watchlist *)
  generator : api_generator option;    (* Some for z3, None for llvm/sqlite *)
  binding_targets : (lang * binding_target) list;
}
```

Add to `source_repo`:
```ocaml
type source_repo = {
  (* ... existing fields ... *)
  api_source : api_source option;      (* NEW *)
}
```

### Migration plan

**Step A — Introduce the type without wiring** (~30 lines, 0 callers changed):
1. Add types to `canary_artifact_source.ml`.
2. Add `api_source = None` to every `source_repo` literal.
3. Build passes; nothing uses the new field yet.

**Step B — Declare api_source for z3 and llvm** (~60 lines, project specs only):
1. `canary_project_z3.ml` — populate `z3_source_dev.api_source = Some {...}`
   with headers dir `src/api`, prefix `["Z3_"]`, stable_symbols migrated
   from today's `z3_native_watchlist`, generator describing `mk_make.py --ml`,
   binding_targets for OCaml.
2. Same for llvm's two source variants.
3. Still nothing reads the field — but it's now a declarative home.

**Step C — Source watchlists from api_source in summaries** (~20 lines):
1. In each project spec's `summary` function for `Probe Lib`, read
   `source.api_source` to get prefixes + watchlist instead of from module-level
   constants.
2. `z3_native_watchlist` constant disappears (moves into
   `z3_source_dev.api_source.stable_symbols`).
3. Project specs now have LESS code.

**Step D — Derive build commands from binding_targets** (~100 lines, the
bigger refactor):
1. Introduce a helper `build_binding_cmd_of_api_source ~api_source ~lang ~build_dir`
   that consults `binding_targets` and emits the shell command for that language.
2. `canary_project_z3.ml`'s `mk_script_spec` replaces the hardcoded
   `ninja build_z3_ocaml_bindings` with a call to this helper.
3. `cmake_build_binding` flag in llvm is absorbed: it's just "does this
   api_source have a binding_target for OCaml?" — if not, skip build_binding
   step.
4. This is where the real simplification lands for project specs; each
   becomes ~200 lines smaller.

**Step E — New binding language = data only** (validation):
1. Add `binding_targets` entry for Python in `z3_source_dev.api_source`:
   `{ target_name = "build_z3_python_bindings"; ... }`.
2. Add `Probe Binding` variant at `Lang_pm (Pip)` in z3 spec.
3. No new shell hardcoded; the build command is derived.
4. This validates that first-class API actually compresses the add-a-language path.

### Open questions for implementation

- **api_source versioning**: Does each version of z3 potentially have a
  different api_source shape (different generator, different targets)?
  Probably yes for z3 (API changes per release). Model by making
  `api_source` part of `source_repo` (per-version) rather than a shared
  per-project constant. Currently z3 has multiple `source_repo`s
  (`z3_source_dev`, `z3_source_stable`), each can declare its own.
- **Relation to `has_build_binding`**: Today's bool subsumes into
  `api_source.binding_targets <> []`. Either keep the bool for back-compat
  or remove it in Step D.
- **Symbol_entry in api_source vs per-rule**: `symbol_check` is per-step on
  `action_step`; `stable_symbols` on api_source is per-source. `Probe Lib`
  pulls from api_source; a `symbol_check` on a specific step can still add
  step-local entries. Keep both, they compose.
- **Header parsing**: Do we ever parse the headers to extract declarations?
  Not initially — treat `stable_symbols` as a human-written claim (same as
  today's watchlists). If later we want `api_extracted_symbols` (derived
  from parsing `z3_api.h`), that's a separate field. Separates
  "what we claim" from "what's actually there".
- **Non-C APIs**: Does api_source make sense for projects whose API is
  Python-first (PyTorch) or Rust-first? Probably yes — `headers_dir` could
  be `torch/csrc/api/include` for libtorch; for Rust-first projects the
  "API" might be the `pub` surface of a crate. Punt until a non-C case
  forces the model to stretch.

### Estimated scope

| Step | Lines | Files touched | Risk |
|------|-------|---------------|------|
| A (type + None) | ~30 | `canary_artifact_source.ml`, 2 project specs | Low |
| B (declare) | ~60 | 2 project specs | Low |
| C (summaries read it) | ~20 | 2 project specs | Low |
| D (derive builds) | ~100 | 2 project specs, maybe `canary_action.ml` | Medium (builds-from-source are hot path) |
| E (add python to validate) | ~40 | 1 project spec | Low (validation only) |

Total: ~250 lines net change, roughly −300 / +250 (project specs get
smaller, new module grows). Prerequisite: Python binding plan's Step A
(Python primitives) — Step E here validates with Python, so it's a natural
rendezvous with `python_binding_plan.md`.

### When to execute

Not now. Order of operations for maximum clarity:

1. Finish the Python binding primitives (`python_binding_plan.md`) — gives
   us a second language consumer to model.
2. Land one Pattern A candidate from `batch_candidates.md` (zarith or ssl)
   — another data point to validate that api_source generalises beyond
   z3/llvm's self-builds.
3. **Then** do Steps A–E above, using the three+ data points.

The risk of refactoring now is over-fitting to z3/llvm. With Python
primitives + one Pattern A live, we'd have at least four data points (z3,
llvm, zarith, and z3-as-python-consumer) which is enough to extract the
right abstractions.
