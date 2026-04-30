# Canary — Interface Contract & Artifact Summaries

Companion to [index.md §5](index.md). Contains the full interface model
(provides ⊆ requires, layered observability, failure taxonomy) plus the
concrete `summary.json` realisation for L1a/L1b/L3.

## 1. Motivation: failure taxonomy

Canary detects compatibility failures empirically. Observed failure modes:

| Failure kind               | Example                                                   | Detection                                          |
| -------------------------- | --------------------------------------------------------- | -------------------------------------------------- |
| Missing symbol (binary)    | Z3 OCaml stub requires `Z3_mk_solver`, lib has it         | `nm` + `assert_binary_symbols.py`                  |
| Type mismatch (OCaml API)  | `llvm.19-shared` missing `Opcode.UncondBr`                | `Expect_failure { contains_any }`                  |
| Linking mode change        | ELF versioned symbols `Z3_foo@@Z3_4.15` vs plain `Z3_foo` | `nm -D` regex with `@@` suffix                     |
| ABI/soname change          | shared vs static, soname mismatch                         | (not yet modelled)                                 |
| Semantic/invariant failure | behavior change without API break                         | (not yet modelled, likely undetectable statically) |

Goal: a **unified abstract representation** rather than scattered ad-hoc checks.
Lift version numbers into the picture so "apt has z3 4.8, but the binding was
built against z3 4.12" is a first-class analysis result.

## 2. Interface as a first-class object

A library artifact has two roles:

```
artifact.provides : interface    (* what it exports *)
artifact.requires : interface    (* what it depends on *)
```

**Compatibility** = `consumer.requires ⊆ provider.provides`

This is a Liskov-style subtyping contract:

- Provider must be at least as capable as consumer expects.
- Extra symbols/types in provider are fine (covariant in output).
- Missing symbols/types in provider → incompatibility.

## 3. Six-level layering

An **interface** is a named set of observable facts about an artifact.
Layered by granularity:

| Level                      | Granularity                                         | Detection method              |
| -------------------------- | --------------------------------------------------- | ----------------------------- |
| **L1a** Symbol             | binary exported names (`Z3_mk_solver`)              | `nm -D`                       |
| **L1b** Versioned symbol   | runtime version requirement (`malloc@@GLIBC_2.31`)  | `nm -D` `@@` annotations      |
| **L2** Type signature      | OCaml type of exported value                        | `ocamlobjinfo`, `.cmi` digest |
| **L3** API shape           | constructor set, module structure                   | compile probe                 |
| **L4** ABI/runtime         | C runtime implementation + version, C++ ABI, soname | `readelf -d`, `ldd`           |
| **L5** Behavioral contract | pre/post conditions                                 | (research territory)          |

Canary today covers L1a (`Expect_symbols`, summary watchlists) and L3
(`Expect_failure` compile probes). L1b is partially handled —
`assert_binary_symbols.py` allows `@@` suffixes in `nm` output but doesn't
treat the version part as a constraint yet. L2 is partially covered — `.cmi`
digests are checked implicitly by `ocamlfind`.

The glibc/musl example lives at **L1b + L4**: the `@@GLIBC_2.31` annotation
is an L1b versioned-symbol requirement; "which C runtime implementation" is
an L4 property. Both fold into the same unified model.

## 4. API source layer (`canary_artifact_api`)

An upstream project that ships a native library has three layers. All three
are now modelled:

```
┌───────────────────────────────────────┐
│  Source repo (z3/, llvm-project/, …)  │  source_repo
└────────────────┬──────────────────────┘
                 │ api_source : Canary_artifact_api.t option
                 ▼
┌───────────────────────────────────────┐
│  native_api                           │  C/native API surface (L1a provider)
│  - components : api_component list    │  Headers | Runtime_lib | Link_stub | Pc_file
│  - headers : headers_spec option      │  path detail for the Headers component
│  - symbol_prefixes, stable_symbols    │
└────────┬────────────┬─────────────────┘
         │            │
         ▼            ▼
    ┌─────────┐  ┌─────────┐
    │ OCaml   │  │ Python  │  …   binding_api (one per language; L3 consumer)
    │ binding │  │ binding │      source_dir + deps + module_watchlist
    └─────────┘  └─────────┘
```

### Types (`canary_artifact_api.ml`)

```ocaml
type lang = OCaml | Python | Rust | Cpp | CSharp | Java

(* Pure enum — shared by provider (native_api.components) and consumer (binding_api.deps).
   No path payload; paths live in native_api.headers. *)
type api_component =
  | Headers      (* C/C++ public headers *)
  | Runtime_lib  (* versioned .so/.dylib *)
  | Link_stub    (* unversioned .so symlink — for -l at build time *)
  | Pc_file      (* pkg-config file *)

(* Path detail for the Headers component — only present on the provider side *)
type headers_spec = { dir : string; files : string list }

type native_api = {
  kind            : native_api_kind;      (* C | Cpp_api *)
  components      : api_component list;   (* what this source/package exposes *)
  headers         : headers_spec option;  (* path detail when Headers ∈ components *)
  symbol_prefixes : string list;          (* e.g. ["Z3_"] or ["LLVM"] *)
  stable_symbols  : string list;          (* L1a watchlist: claim these survive version bumps *)
}

type binding_api = {
  lang             : lang;
  source_dir       : string option;       (* relative to source root; None = out-of-tree *)
  deps             : api_component list;  (* which components from native_api this binding needs *)
  module_watchlist : string list;         (* L3 watchlist; dotted paths ok: "Llvm.Opcode.UncondBr" *)
}

type t = {
  native_api   : native_api;
  binding_apis : binding_api list;
}
```

`source_repo.api_source : t option` — `None` means not yet declared.

Key accessors: `native_watchlist`, `binding_watchlist_exn`, `stable_reuse_warning`,
`scan_source_cmd`.

Convenience values:
- `deps_all = [Headers; Link_stub; Runtime_lib]` — OCaml, Rust (compile C stubs at install time)
- `deps_runtime_only = [Runtime_lib]` — Python pre-compiled wheels (no C compilation at user-install time)

### What belongs here vs elsewhere

**In `api_source`:** component kinds, header paths and file list, symbol prefixes,
native stable-symbol watchlist, per-language binding source dirs and deps,
per-language module watchlists.

**Not in `api_source`:** build targets, generators, build commands — those stay
in `action_step`/`script_spec`. `api_source` is a declarative artifact
description, not a build recipe.

`native_api.components` is a **provider declaration**: which component kinds
this source or package exposes. `binding_api.deps` is a **consumer declaration**:
which of those components the binding needs. `api_component` is shared by both —
the same enum drives provider enumeration and consumer dependency checks.

`native_api.stable_symbols` is a **provider claim** (what the C API promises).
`binding_api.module_watchlist` is a **consumer claim** (what the binding exposes
in its own language). Both are hand-written; scan/summary confirm them
post-build.

### Scan confirmation step

`script_spec.scan_source` carries the generated check command (from
`scan_source_cmd`). `derive_steps` emits it as a `scan_source` step after
`fetch_source`, sharing `fetch_source`'s output dir and writing `scan.ok`.
`Configure`, `Build_lib`, and `Build_binding` depend on `scan_source` when it
is wired — a spec-drift failure (header claim wrong, binding dir missing) blocks
the build chain.

Only source-build runs carry a scan step. Stable fetch-only sources
(`has_build_lib = false`, `has_build_binding = false`) have `scan_source = None`.

### Concrete instances

| Project | `headers.dir`         | `symbol_prefixes` | `binding_apis`                                                                      |
| ------- | --------------------- | ----------------- | ----------------------------------------------------------------------------------- |
| z3      | `src/api`             | `["Z3_"]`         | OCaml (`deps_all`, in-tree `src/api/ml`), Python (`deps_runtime_only`, in-tree `src/api/python/z3`) |
| llvm    | `llvm/include/llvm-c` | `["LLVM"]`        | OCaml (`deps_all`, in-tree `llvm/bindings/ocaml`), Python (`deps_runtime_only`, out-of-tree llvmlite) |

`source_dir = None` on llvm's Python entry: scan skips the `test -d` check;
the `module_watchlist` still drives the pip summary.

Stable sources (`z3_source_stable`, `llvm_source_stable`) share the dev
`api_source`. When `has_build_binding = false`, the summary closure prepends:
```
NOTE: api_source is the dev spec reused for stable source z3/4.15.2; watchlist may drift
```

## 5. Package provider model *(sketch — to be detailed later)*

### 5.1 Actions and artifacts are abstract; packages are concrete providers

The canary action graph operates on **abstract artifact kinds** (Source, Headers,
Lib, Binding, App). These are slots, not packages. A package is a *provider* that
satisfies one or more slots simultaneously. The same slot can be satisfied by
different providers on different paths.

Examples for z3:

| Provider | Slots satisfied |
|----------|----------------|
| `libz3-dev` (apt) | `Headers`, `Pc_file`, `Link_stub`, `Runtime_lib` |
| `z3-solver` (pip) | `Binding(Python)` + `Runtime_lib` (bundled, co-provided) |
| `z3` (opam) | `Binding(OCaml)` (implicitly includes source artifacts) |
| source build | `Source`, `Headers`, `Lib`, `Binding(OCaml)`, `Binding(Python)` |

The diagram shows artifact kinds and action nodes at this abstract level. It does
not show which package fills each slot — that is the action list's job.

### 5.2 Version as identity

The core assumption: **a versioned artifact is the same regardless of provider**.
`libz3@4.15.2` from apt, from the pip wheel, and from a source build at that tag
should all expose the same C ABI, the same symbol set, the same module surface.

Canary's verification work therefore reduces to two questions:
1. **What version does each provider give?** (detect: `pip show`, `apt-cache
   policy`, `z3.get_version()`, `nm` symbol prefix scan, …)
2. **Does that version satisfy the expected interface?** (confirm: symbol
   watchlist check, functional probe, module surface diff)

If both checks pass, the provider is interchangeable with any other provider of
the same version. If they diverge, the provider lied about its version or
distributions diverged — both are real mismatch signals.

### 5.3 Bundled co-provider (pip-bundled lib case)

`z3-solver` is a *co-provider*: it satisfies `Binding(Python)` and `Runtime_lib`
in one package. The binding's runtime dep on `libz3.so` is resolved internally
inside the wheel. No external `Lib` slot needs to be filled separately.

Implication for the action graph: `probe_python_pip` for a bundled-lib package
has **no external `lib_node` runtime dependency**. The current diagram draws
`lib_node -.->|runtime| probe_python_pip`, which is correct only when the Python
binding links against an external system lib (non-bundled case). For co-providers
the edge should be absent.

The `binding_api.deps` field (#35) is the right hook to express this: a binding
that lists `deps_runtime_only = [Runtime_lib]` and whose provider is a co-provider
pip wheel does not require the lib slot to be filled from a sibling action — the
runtime dep is internal to the provider.

The confirmation task for a bundled co-provider is the same two questions from
§5.2 applied twice:
- Python module version: `z3.get_version()` → compare against pip metadata version
- Bundled lib version: `nm site-packages/z3/lib/libz3.so` → same symbol check as
  done on the system lib; diff against a known-good summary for that version

### 5.4 Scope of the diagram

The diagram operates at the abstract kind level intentionally: it shapes action
generation and shows action status without over-specifying provider details. When
the HTML viewer (TODO #37) lands, provider-level details (which package filled
which slot, bundled vs external, version detected) can be surfaced as a drill-down
layer, keeping the diagram itself at the middle concept level.

## 6. Concrete examples

### C runtime mismatch (glibc vs musl)

A library compiled against glibc 2.31 carries versioned symbol requirements:

```
$ nm -D libz3.so | grep malloc
  malloc@@GLIBC_2.17
  __cxa_throw@@GLIBC_2.3.4
```

A system running glibc 2.17 or musl libc cannot satisfy `@@GLIBC_2.31`:

```
/lib/x86_64-linux-gnu/libz3.so: /lib/x86_64-linux-gnu/libc.so.6: version
  `GLIBC_2.31' not found
```

In the unified model:

```
libz3.requires.c_runtime    = { implementation = Glibc; version = >= 2.31 }
ubuntu_20_04.provides       = { implementation = Glibc; version = 2.31 }
alpine_3_18.provides        = { implementation = Musl;  version = 1.2.3 }
```

Compatibility check: `artifact.requires ≤ environment.provides`. Alpine fails;
Ubuntu 20.04 exactly satisfies. Same subtyping as the API-level checks — C
runtime is just another versioned interface, one level below the library's
own API.

### Z3 dev vs apt stable

```
z3_dev.provides         = { symbols: {Z3_*}, ocaml_api: {Z3.Solver, Z3.Expr, ...} }
z3_apt.provides         = { symbols: {Z3_*}, ocaml_api: {Z3.Solver, Z3.Expr, ...} }
                                                ↑ same names, different types/arity
z3_binding_dev.requires = { symbols: {Z3_*}, ocaml_api: {Z3.Solver.add_clause} }
```

Linking against `z3_apt`'s `libz3.so` may succeed at L1 ✓ but fail at L2/L3 ✗
or silently misbehave at L5 ✗. The `z3/stable` probe in canary demonstrates
this.

### LLVM 19 vs dev binding

```
llvm_19.provides       = { ocaml_api: { Opcode.Br } }    (* no UncondBr *)
llvm_dev.provides      = { ocaml_api: { Opcode.Br, Opcode.UncondBr, ... } }
binding_dev.requires   = { ocaml_api: { Opcode.UncondBr } }
```

`binding_dev.requires ⊄ llvm_19.provides` → expected compile failure. Already
detected and **expected** in canary (`Expect_failure`). With first-class
interface it becomes a checked contract, not a grep on an error string.

## 7. Expanded failure taxonomy

Beyond symbol-missing:

- **Additive (safe)** — provider gains symbols. Consumer unaffected.
  ```
  z3_4.13.provides ⊇ z3_4.12.provides   →   any consumer of 4.12 works with 4.13
  ```

- **Subtractive (breaking)** — provider loses symbols.
  ```
  llvm_19.provides ⊄ llvm_dev.provides   →   consumer of dev fails against 19
  ```
  Already detected by `Expect_failure`.

- **Mutating (subtle breaking)** — same name, different signature.
  ```
  Z3_mk_solver: v4.12 returns Z3_solver, v4.15 returns Z3_solver*
  ```
  L1 check passes, L2/L3 fails. Not yet detected.

- **Linking-mode change** — symbol versioning (`Z3_foo@@Z3_4.15`), soname change,
  shared-vs-static. Causes dlopen failure or silent symbol resolution to wrong
  version. Partially handled (`@@` suffix tolerated in regex).

- **Semantic / invariant change** — API unchanged, behavior differs (solver
  tactic removed, default changed). Undetectable without behavioral tests.
  L5 territory; could be a `probe_app` pattern.

## 8. Concrete realisation: artifact summaries

Each scan produces a compact `summary.json` that captures the L1a/L1b/L3
observations without storing a full symbol list.

### "Symbol" per artifact kind

| Artifact              | Symbol analog                         | Tool                                   |
| --------------------- | ------------------------------------- | -------------------------------------- |
| Native `.so`/`.dylib` | C exports                             | `nm -D` (Linux), `nm -g` (macOS)       |
| Native `.so`/`.dylib` | Versioned deps (L1b)                  | `nm -D` `@@` suffixes                  |
| OCaml `.cmxa`/`.cma`  | Modules + top-level constructors/vals | `ocamlobjinfo`                         |
| OCaml opam pkg        | Same, walked via `ocamlfind query`    | `ocamlobjinfo`                         |
| Python pkg            | `dir(module)` attributes              | `python3 -c "import x; print(dir(x))"` |
| Source repo           | Public header names, commit SHA       | `find`, `git log`                      |

Note: OCaml tools (outside the compiler) don't have a nice programmable API,
but `ocamlobjinfo` is well-implemented and shell-friendly. `tola/binding/`
has reference implementations (Objinfo via compiler libs) — flagged in
CLAUDE.md as a future migration. Today: shell + small Python parsers.

### `summary.json` schema

```json
{
  "kind": "native",
  "path": "/usr/lib/.../libz3.so",
  "fingerprint": "sha256:abc123" or "git:HEAD",
  "counts": {
    "total": 1426,
    "by_prefix": { "Z3_": 890, "Z3_mk_": 120 }
  },
  "versioned_req": { "GLIBC_2.17": 1, "GLIBC_2.28": 3 },
  "watchlist": {
    "present": ["Z3_mk_solver", "Z3_mk_optimize_assert_soft"],
    "missing": ["Z3_mk_fpa_to_ieee_bv_legacy"]
  },
  "extra": { "build_date": "2026-04-22", "size_kb": 28456 }
}
```

Three signal types:

1. **Totals** — `total` + `by_prefix`. Stable under minor changes; diffs say
   "API grew/shrank" without listing every symbol.
2. **Versioned deps** (native) — the `@@GLIBC_*` map directly answers "will
   this run on musl or old glibc."
3. **Watchlist** — hardcoded *interesting* names per project. "Names known to
   break" (Z3 famously-renamed `Z3_mk_optimize_assert_soft`, llvmlite
   deprecated `initialize`, …). Can grow from failure logs.

Per-language extras: Python summaries also surface module-specific facts via
`extras_for(pkg, mod)` — e.g. `sqlite3.sqlite_version` captures the bundled
libsqlite version, independent of CPython's own version.

## 9. Watchlists

Watchlists are *human-curated* canaries: "we expect these names to remain
stable." Two concerns, now cleanly split:

- **Provider watchlist** (`native_api.stable_symbols`) — what the upstream
  C API promises. Sits on `api_source.native_api` per §4.
- **Consumer watchlist** (`binding_api.module_watchlist`) — what a specific
  language binding expects. Sits on its `binding_api` entry per §4.

The split is implemented: `z3_native_watchlist` and `z3_ocaml_watchlist`
are gone as top-level constants; their lists live inside `z3_api_source`.
Summary closures read them via `native_watchlist api` and
`binding_watchlist_exn api lang`.

Embedded drift signals (intentional placeholders that double as demos):

- `Z3_mk_optimize_assert_soft` in z3's `stable_symbols` — function was renamed
  upstream; missing entry validates drift detection.
- `initialize`, `initialize_native_target` in llvmlite's `module_watchlist` —
  llvmlite deprecated these; future removal will surface as missing.

## 10. Storage

- **Per-probe** (today): each probe step writes `summary.json` to its
  output dir alongside `probe.log`. Scan writes `scan.ok` alongside `source.ok`
  in the `fetch_source` output dir.
- **Committed index** (future): `summary-sync` subcommand promotes selected
  summaries into a committed index keyed by `{artifact_kind, name, fingerprint}`.
  Small files (~1KB each), safe to commit. Cross-machine drift visibility.

## 11. Drift detection: summary-diff

Given two summaries `(old, new)`:

- counts deltas (total ± , by_prefix ± per prefix)
- versioned_req deltas (NEW / GONE / CHG entries)
- watchlist deltas: `present` set diff, `missing` set diff, **regressions**
  (was present in old, is missing in new)

`canary summary-diff --old A.json --new B.json` already implements this.
Real-world demo: libLLVM 19 vs libLLVM dev = `total: 43813 → 34176` (-9637),
plus a clean GLIBCXX/CXXABI/GLIBC requirement-floor delta. See
[trackers/python_binding.md](../trackers/python_binding.md) for the
in-flight examples.

## 12. Bridge to version_logic

With interface as a first-class object, a version is no longer just a number —
it carries an interface snapshot:

```ocaml
type versioned_artifact = {
  version : Version.t;
  interface : interface;
}
```

Version constraint solving (`src/versioning/Version_logic.Make`) becomes:
"find a version of Z3 such that `z3_binding_dev.requires ⊆ z3_v.provides`."

Canonical questions the combined system can answer:

- Which apt version of Z3 is compatible with this OCaml binding?
- At which Z3 version did `Z3_mk_optimize_assert_soft` first appear?
- What is the minimal LLVM version that provides `Opcode.UncondBr`?

Bridges canary (concrete tests) to the pkgm formalism (abstract version
constraint SAT).

## 13. Roadmap

### Step 1 — unified summary primitives ✅

Per-artifact summary commands (`Canary_artifact_native.summary_cmd`,
`Canary_artifact_ocaml.summary_cmd`, `Canary_artifact_python.summary_cmd`).
Watchlists declared per project. Summary attached to probe steps via
`script_spec.summary`. Done; CI green.

### Step 2 — API source layer + scan ✅

`canary_artifact_api.ml` types the three-layer structure (source →
native_api → binding_api per language). Watchlists split into provider
(`stable_symbols`) and consumer (`module_watchlist`) levels. `scan_source`
step verifies header/binding-dir claims post-fetch, blocking builds on
spec drift.

### Step 3 — interface diff across versions

`summary-diff` works on per-probe summaries today. Next: scan stage
produces an authoritative per-artifact summary usable across versions;
diffs become per-version, not per-probe. Gated on committed summary index.

### Step 4 — interface ↔ version_logic

Represent `requires ⊆ provides` as a constraint solvable in `Version_logic`.
Cross-references the pkgm formalism. Research-paper material.

### Step 5 — semantic contracts (L5)

Behavioral probes (probe_app level) as interface at L5. Property-based
testing against a declared behavioral interface. Research territory.

## 14. Open implementation questions

- **L1b as a constraint, not just a count.** Today `versioned_req` is a
  count map. Becoming a real glibc-version-floor calculation needs the
  highest-required-version computation per dependency.
- **`nm`-based symbol scan step.** `stable_symbols` are confirmed by the
  existing `probe_lib` summary via `nm -D`; no dedicated post-build scan
  step for them yet. The `scan_source` step only checks file existence.
- **Header parsing for L2/L3.** Currently human-claimed. Mechanical
  extraction (libclang for C, ocamlc for OCaml signatures) is a separate
  add-on, not a replacement. Keep "claimed" and "extracted" distinct.
- **L4 (ABI/runtime).** soname tracking, libc/libstdc++ implementation
  tag, per-binary `readelf -d` capture. Out of scope; Stage 4+.
- **L5 behavioral.** Out of scope; research add-on.
