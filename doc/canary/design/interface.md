# Canary — Interface Contract & Artifact Summaries

Companion to [index.md §5](index.md). Contains the full interface model
(provides ⊆ requires, layered observability, failure taxonomy) plus the
concrete `summary.json` realisation for L1a/L1b/L3.

## 1. Motivation: failure taxonomy

Canary detects compatibility failures empirically. Observed failure modes:

| Failure kind | Example | Detection |
|---|---|---|
| Missing symbol (binary) | Z3 OCaml stub requires `Z3_mk_solver`, lib has it | `nm` + `assert_binary_symbols.py` |
| Type mismatch (OCaml API) | `llvm.19-shared` missing `Opcode.UncondBr` | `Expect_failure { contains_any }` |
| Linking mode change | ELF versioned symbols `Z3_foo@@Z3_4.15` vs plain `Z3_foo` | `nm -D` regex with `@@` suffix |
| ABI/soname change | shared vs static, soname mismatch | (not yet modelled) |
| Semantic/invariant failure | behavior change without API break | (not yet modelled, likely undetectable statically) |

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

| Level | Granularity | Detection method |
|---|---|---|
| **L1a** Symbol | binary exported names (`Z3_mk_solver`) | `nm -D` |
| **L1b** Versioned symbol | runtime version requirement (`malloc@@GLIBC_2.31`) | `nm -D` `@@` annotations |
| **L2** Type signature | OCaml type of exported value | `ocamlobjinfo`, `.cmi` digest |
| **L3** API shape | constructor set, module structure | compile probe |
| **L4** ABI/runtime | C runtime implementation + version, C++ ABI, soname | `readelf -d`, `ldd` |
| **L5** Behavioral contract | pre/post conditions | (research territory) |

Canary today covers L1a (`Expect_symbols`, summary watchlists) and L3
(`Expect_failure` compile probes). L1b is partially handled —
`assert_binary_symbols.py` allows `@@` suffixes in `nm` output but doesn't
treat the version part as a constraint yet. L2 is partially covered — `.cmi`
digests are checked implicitly by `ocamlfind`.

The glibc/musl example lives at **L1b + L4**: the `@@GLIBC_2.31` annotation
is an L1b versioned-symbol requirement; "which C runtime implementation" is
an L4 property. Both fold into the same unified model.

## 4. Concrete examples

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

## 5. Expanded failure taxonomy

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

## 6. Concrete realisation: artifact summaries

Each scan produces a compact `summary.json` that captures the L1a/L1b/L3
observations without storing a full symbol list.

### "Symbol" per artifact kind

| Artifact | Symbol analog | Tool |
|---|---|---|
| Native `.so`/`.dylib` | C exports | `nm -D` (Linux), `nm -g` (macOS) |
| Native `.so`/`.dylib` | Versioned deps (L1b) | `nm -D` `@@` suffixes |
| OCaml `.cmxa`/`.cma` | Modules + top-level constructors/vals | `ocamlobjinfo` |
| OCaml opam pkg | Same, walked via `ocamlfind query` | `ocamlobjinfo` |
| Python pkg | `dir(module)` attributes | `python3 -c "import x; print(dir(x))"` |
| Source repo | Public header names, commit SHA | `find`, `git log` (extensible to FFI surfaces across languages — many provide C-ABI) |

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

## 7. Watchlists

Watchlists are *human-curated* canaries: "we expect these names to remain
stable." The model splits two concerns:

- **API-level watchlist** — what the upstream project promises. Sits on
  `api_source.stable_symbols` (per [index.md §4](index.md)).
- **Binding-level watchlist** — what a specific consumer expects. Sits on
  the binding declaration (`ocaml_module_watchlist`, `python_attr_watchlist`).

Today these are mixed in project specs (`z3_native_watchlist` is API-level;
`z3_ocaml_watchlist` is binding-level). The Stage 3 abstraction pulls them
apart cleanly.

Embedded drift signals (intentional placeholders that double as demos):

- `Z3_mk_optimize_assert_soft` in `z3_native_watchlist` — function was renamed
  upstream; missing entry validates drift detection.
- `initialize`, `initialize_native_target` in `llvm_python_watchlist` —
  llvmlite deprecated these; future removal will surface as missing.

## 8. Storage

- **Per-probe** (today): each probe step writes `summary.json` to its
  output dir alongside `probe.log`.
- **Per-scan** (Stage 3 target, see [index.md §4](index.md)): scan stage
  writes one `scan_result.json` per artifact, multiple probes share it.
- **Committed index** (future): `summary-sync` subcommand promotes selected
  summaries into a committed index keyed by `{artifact_kind, name, fingerprint}`.
  Small files (~1KB each), safe to commit. Cross-machine drift visibility.

## 9. Drift detection: summary-diff

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

## 10. Bridge to version_logic

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

## 11. Roadmap

### Step 1 — unified summary primitives ✅

Per-artifact summary commands (`Canary_artifact_native.summary_cmd`,
`Canary_artifact_ocaml.summary_cmd`, `Canary_artifact_python.summary_cmd`).
Watchlists declared per project. Summary attached to probe steps via
`script_spec.summary` field. Done; CI green.

### Step 2 — interface diff across versions

Today: `summary-diff` works on per-probe summaries. Next: scan stage produces
authoritative `scan_result.json` per artifact (per [index.md §4](index.md));
summary-diff operates on those. Diffs become per-version, not per-probe.

### Step 3 — interface ↔ version_logic

Represent `requires ⊆ provides` as a constraint solvable in `Version_logic`.
Cross-references the pkgm formalism. Research-paper material.

### Step 4 — semantic contracts (L5)

Behavioral probes (probe_app level) as interface at L5. Property-based
testing against a declared behavioral interface. Research territory.

## 12. Open implementation questions

- **L1b as a constraint, not just a count.** Today `versioned_req` is a
  count map. Becoming a real glibc-version-floor calculation needs the
  highest-required-version computation per dependency.
- **Header parsing for L2/L3.** Currently human-claimed. Mechanical
  extraction (libclang for C, ocamlc for OCaml signatures) is a separate
  add-on, not a replacement. Keep "claimed" and "extracted" distinct.
- **L4 (ABI/runtime).** soname tracking, libc/libstdc++ implementation
  tag, per-binary `readelf -d` capture. Out of scope for Stage 3; Stage 4+.
- **L5 behavioral.** Out of scope; research add-on.
