# Canary: Artifact Summary / Interface Dump

## Motivation

Given a built artifact (native `.so`, OCaml `.cmxa`, python pkg, source repo),
dump a compact, structured summary of its "symbol-like interface" — enough
signal to detect version drift, populate `version_info` for expectations,
and diff across builds, without storing a full symbol list.

This connects to `doc/canary/interface_contract_design.md` (interface as
first-class object) and to the `step_expectation` / `symbol_check` model
in `canary_action.ml`.

## What counts as a "symbol" per artifact

| Artifact             | Symbol analog                          | Tool                                 |
| -------------------- | -------------------------------------- | ------------------------------------ |
| Native `.so`/`.dylib`| C exports                              | `nm -D` (Linux), `nm -g` (macOS)     |
| Native `.so`/`.dylib`| Versioned deps (L1b)                   | `nm -D` `@@` suffixes                |
| OCaml `.cmxa`/`.cma` | Modules + top-level constructors/vals  | `ocamlobjinfo`                       |
| OCaml opam pkg       | Same, walked via `ocamlfind query`     | `ocamlobjinfo`                       |
| Python pkg           | `dir(module)` attributes               | `python3 -c "import x; print(dir(x))"` |
| Source repo (future) | Public header names, commit SHA        | `find`, `git log` — extensible to FFI surfaces across languages (many provide C-ABI) |

Note: OCaml tools (outside the compiler itself) don't have a nice programmable
API, but `ocamlobjinfo` is well-implemented and shell-friendly. `tola/binding`
has relevant reference implementations; we keep our approach as shell
invocations returning structured output, parsed into JSON.

## Compact summary schema

```json
{
  "kind": "native",
  "path": "/usr/lib/.../libz3.so",
  "fingerprint": "sha256:abc123" or "git:HEAD",
  "counts": {
    "total": 1426,
    "by_prefix": { "Z3_": 890, "Z3_mk_": 120 }
  },
  "versioned": { "GLIBC_2.17": 1, "GLIBC_2.28": 3 },
  "watchlist": {
    "present": ["Z3_mk_solver", "Z3_mk_optimize_assert_soft"],
    "missing": ["Z3_mk_fpa_to_ieee_bv_legacy"]
  },
  "meta": { "build_date": "2026-04-22", "size_kb": 28456 }
}
```

Three dump levels:

1. **Totals** — `total` + `by_prefix` map. Invariant under minor changes;
   a diff tells you "API grew/shrank" without listing every symbol.
2. **Versioned deps** (native only) — the `@@GLIBC_*` map is tiny and
   directly answers "will this run on musl or old glibc."
3. **Watchlist** — a hardcoded set of *interesting* names per project.
   Starts as "names known to break" (Z3 famously-renamed functions,
   `Opcode.UncondBr` in LLVM). Can grow from failure logs: if
   `Expect_failure.contains_any` matched a name, consider adding it
   to the watchlist.

## Storage

- **Per-probe**: each probe step writes `summary.json` to its output dir
  alongside `probe.log`. Same shape as above.
- **Committed index**: a `summary-sync` subcommand (sibling of
  `cache-sync`) promotes selected summaries into a committed
  `doc/canary/artifact_summary.json`, keyed by
  `{artifact_kind, name, fingerprint}`. Small files (~1KB each), safe
  to commit.

## Feedback into expectations

1. Local probe writes `summary.json` with `watchlist.{present,missing}`.
2. On the next probe for the same artifact, the runner can compare against
   the committed index — any drift logs `interface_changed` with specifics
   (`"Z3_mk_optimize_assert_soft: present(abc) → missing(def)"`).
3. `version_info` in `Expect_failure` / `symbol_check` can cite the summary:
   `"expected failure confirmed: llvm 19 watchlist missing Opcode.UncondBr
   (summary sha=xyz)"`.

## Roadmap

### Step 1 (now): Summary generators per artifact

- `Canary_artifact_native.summary_cmd ~lib ~prefixes ~watchlist ~output_dir`
  emits `summary.json` via shell (nm + grep + jq or small python). Totals,
  by-prefix counts, versioned-dep map, watchlist present/missing.
- `Canary_artifact_ocaml.summary_cmd ~archive_or_pkg ~watchlist ~output_dir`
  emits `summary.json` via `ocamlobjinfo`. Module count, per-module
  constructor count, watchlist presence.
- `Canary_artifact_python.summary_cmd ~pkg ~watchlist ~output_dir` emits
  `summary.json` via `python3 -c dir()`.
- CLI: `dune exec -- canary artifact-summary --kind native --lib /.../libz3.so
  --prefix Z3_ --watchlist Z3_mk_solver,Z3_mk_optimize`.

### Step 2: Watchlist declarations per project

Project specs declare:

```ocaml
let z3_watchlist = [ "Z3_mk_solver"; "Z3_mk_optimize_assert_soft"; ... ]
let llvm_watchlist = [ "LLVMModuleCreateWithName"; ... ]
let llvm_ocaml_watchlist = [ "Opcode.UncondBr"; "Opcode.Br"; ... ]
```

and `derive_steps` attaches a post-probe summary generation step.

### Step 3: Committed index + summary-sync

- Promote per-probe summaries into `doc/canary/artifact_summary.json`.
- `summary-sync` reads from `_out/canary/_local/*/*/summary.json` and
  merges; optionally also pulls from CI artifacts via `gh`.
- Runner uses the committed index to log interface drift.

### Step 4: FFI surface for source artifacts

Source-repo summaries start as header-file counts, extend to parsed
public API surfaces across C-ABI-providing languages (Rust `#[no_mangle]`
exports, Go `//export`, etc.). This is the bridge to treating source
itself as an interface-bearing artifact.

### Step 5: Auto-derived expectations

Given two summaries (old_version, new_version), compute the diff and
auto-generate `Expect_failure.version_info` bodies. At that point the
probe result's `summary.json` IS the interface claim, and the probe
itself validates the claim.
