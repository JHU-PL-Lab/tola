### 2.7 Inspector coverage and implementation pointers

The contract-status view lives in §2.4's alignment table. This
section provides the supporting detail: per-inspector status,
implementation file pointers, and the interpretive prose about how
the gaps decay.

#### Inspector vs. comparator

A static check has two roles:

- An **inspector** takes *one artifact* and produces *one structured
  surface description* (a JSON record). Side-agnostic and
  contract-agnostic; it just extracts what the artifact presents.
  Canary's inspectors today: `inspect_native.py` (ELF),
  `inspect_binding.py --kind stub` (stub `.a` undef refs),
  `inspect_binding.py --kind mli` (OCaml `.mli` parse),
  `inspect_ocaml.py` (`.cmxa` modules), `inspect_python.py`
  (`dir()`), `scan_source` (header file presence).
- A **comparator** takes *two surface JSONs* (provider + consumer),
  plus the contract identity, and computes a Pass/Fail verdict —
  ideally with the disagreement set attached. Contract-specific,
  inspector-agnostic (works on any pair of JSONs with the right
  shape). Canary's comparators today: `check_c_compat` (encodes
  Symbol via `native.symbols ⊇ stub.requires`) and the watchlist
  check inside `Expect_compat_failure` (encodes API-completeness
  via set inclusion on `.mli` vals or Python attrs).

A contract has full static-check coverage *iff* both the relevant
inspectors and the comparator that consumes them exist. The
inspector side is tracked below; the comparator side is in the
§2.4 alignment table.

#### Inspector coverage (per artifact)

Rows are *artifact aliases* (file-keyed, project-local). The `n*` /
`b<lang><mech?>*` naming and the full canonical-name dictionary live
in [`tiny.md` § Artifact inventory](tiny.md#artifact-inventory--aliases--canonical-names);
this section uses the aliases as compact handles. Surface tags
(`s1..s6`) refer back to §2.1.

**Table — Inspector coverage.** One row per inspectable artifact in
`tiny`. The *implementation* view — what extracts each surface, and
what's wired today.

| alias | canonical name (artifact)       | surface | inspector tool                                    | status     |
| ----- | ------------------------------- | ------- | ------------------------------------------------- | ---------- |
| n4    | `lib_native.so`                 | s2      | `inspect_native.py` via `nm -D` + `readelf -d`    | ✓          |
| bo4   | `user_binding_ocaml.mli`        | s4      | `inspect_binding.py --kind mli`                   | ✓          |
| bo7   | `compiled_binding_ocaml.stub-a` | s5      | `inspect_binding.py --kind stub` via `nm`         | ✓          |
| bo6   | `compiled_binding_ocaml.cmxa`   | s5      | `inspect_ocaml.py` via `ocamlobjinfo`             | ✓          |
| bpc2  | `user_binding_ctypes.py`        | s4      | `inspect_python.py --pkg tiny_ctypes`             | ✓          |
| bpe2  | `user_binding_cext.py`          | s4      | `inspect_python.py --pkg tiny_cext`               | ✓          |
| bpe3  | `compiled_binding_cext.so`      | s5      | `inspect_native.py` (same tool, on a binding ELF) | ✓          |
| n3    | `header_native.h`               | s1      | — (no parser; `scan_source` presence check only)  | ✗          |
| bo1   | `stub_binding_ocaml.mli`        | s3      | — (mli inspector matches `^val`, not `external`)  | ✗          |
| bpc1  | `stub_binding_ctypes.py`        | s3      | — (no ctypes-decl parser)                         | ✗          |
| bpe1  | `stub_binding_cext.c`           | s3      | — (no Py C API parser)                            | ✗          |
| —     | runtime probe                   | s6      | probe binary + reference expected values          | ✓ implicit |

Compact reading: the native semantic surface (s2 / `n4`) and the
language user-facing surface (s4 / `bo4`, `bpc2`, `bpe2`) are well
covered. The native syntactic header (s1 / `n3`) and the stub-facing
layer across every binding mechanism (s3 / `bo1`, `bpc1`, `bpe1`)
are the parsing gaps.

#### Alignment with tiny and canary status

The same contracts again, joined with: which `tiny` scenario(s)
witness each, which inspectors and comparators canary needs, and
what's wired today. This is the **go-to status view** — open it when
you want to see all four pillars (theory ↔ tiny ↔ coverage ↔
currently) on one row.


#### Categories of invariants (cross-cutting)

Contracts differ in *which surfaces they pin* (the alignment table
above). An orthogonal question is *what kind of invariant the
pinning enforces*. These categories cross-cut contracts:

- **Presence** — does the provider export what the consumer
  expects? Surfaces at Symbol (link-level names) and
  API-completeness (high-level names). Checked: s2→s5 (stub.a undef
  refs), s5→app (probe).
- **Version-match** — is the provider's version at least what the
  consumer requires? Surfaces at SymbolVersion (`@@VER`) and ABI
  (SONAME). Plumbed, not wired.
- **Type-match** — does the provider's type signature match the
  consumer's? Surfaces at Type (`.cmi` digest, header parse). Not
  checked end-to-end.
- **Shape-match** — does the consumer's API shape match
  expectations? Surfaces at API-completeness (watchlists, `dir()`)
  and API-repacking (intra-binding). Partly checked.
- **Identity** — is this the artifact we think it is? Surfaces at
  ABI (SONAME, NEEDED). Diagnostic only.
- **Behavior-match** — same input → same output? Surfaces at
  Behavior. Research.

### 2.5 API-faithfulness is derived, not primitive

A reasonable reader will ask: shouldn't there be a contract
"user-facing OCaml API faithfully mirrors the C API"? Yes — but it is
*derived*, not primitive. It decomposes:

```
API-faithfulness   ⇐   Type   ∧   Symbol   ∧   API-repacking
```

The C-side ↔ stub-facing alignment (Type + Symbol) plus the
stub-facing ↔ user-facing alignment (API-repacking) compose to give
C-side ↔ user-facing alignment. So we do not list API-faithfulness in
the primary table — checking its three constituents implies it.

This decomposition is *why* the language side's internal structure
matters. The thing a user notices when a binding misbehaves
("`Z3.Solver.mk` is missing", "argument order is wrong") is an
API-faithfulness failure. But there is no direct check for it.
Verification routes through three separate links of the chain.

#### Refinement lattice vs. comparator flat

A general principle hides in §2.5 and in the SymbolVersion case:
**contracts form a refinement lattice; comparators are a flat
implementation of selected lattice points.**

Logically, contracts have an order. SymbolVersion refines Symbol
(`SymbolVersion ⊑ Symbol` — checking the version annotation
presupposes the symbol name is present at all). API-faithfulness
derives from Type ∧ Symbol ∧ API-repacking. Behavior is the
finest, refining everything below it. The lattice expresses what
*entails* what.

Operationally, the alignment table (§2.7) treats each contract as a
**sibling row with its own comparator id**, even when the contracts
are refinement-ordered. So c1 `cmp_symbol` and c5 `cmp_sym_version`
are independent rows with independent comparators, even though c5
⊑ c1 in the lattice. This is because the comparators have *distinct
implementations* (set inclusion of names vs. version-tag
satisfaction), *distinct failure modes* (`undefined symbol` vs.
`version 'TINY_2.0' not found`), and *distinct status today* (c1 ✓
wired, c5 ✗ comparator missing).

The principle: when two refinement-ordered contracts have
independent failure modes and need independent comparator code, they
get peer rows in the implementation. The refinement order is
recorded in §2.9's satisfaction predicate and in the lattice prose,
but doesn't collapse the comparator grid.

### 2.6 Actions and phases

Surfaces and contracts are *what we model*. Actions are *what we
actually run* — concrete pipeline steps (canary or tiny) that produce
surfaces and exercise contracts. Many actions touch multiple
contracts at once (e.g. `build_binding_static` triggers Type at
compile-time and Symbol-static at link-time), which is why they
deserve their own grid alongside the contract tables.

#### 2.6.1 Action grid

**Table — Action grid.** Rows are pipeline actions, grouped by category.
Inputs (surfaces consumed) and outputs (surfaces produced) name `s*`
roles from §2.1; the "Contracts checked" column names the `c*`
contracts from §2.4. This is the *operational* view — what each step
does to the surface/contract picture.

| Action                   | Canary step / tiny artifact                                                                | Inputs (consumed)    | Contracts checked                                                                                        | Outputs (produced)          | Status                                           |
| ------------------------ | ------------------------------------------------------------------------------------------ | -------------------- | -------------------------------------------------------------------------------------------------------- | --------------------------- | ------------------------------------------------ |
| **build_native_lib**     | `build_lib` (cmake/ninja → `libtiny.so.1`, `libz3.so`)                                     | C source + `s1`      | (defines provider; no cross-check)                                                                       | `s2`                        | ✓                                                |
| **build_binding_static** | `build_binding_ocaml`, python cext `setup.py build_ext`; tiny `ocaml/dune`, `python_cext/` | `s1`, `s2`, `s3`     | **c6** Type (compile-time), **c1** Symbol-static (link-time)                                             | `s5`                        | ✓ pipeline; c6 post-hoc inspector ✗              |
| **install_binding**      | `pack_binding_ocaml`, `pip install`; tiny `Makefile install`                               | `s5`                 | **c4** ABI (NEEDED resolution at install)                                                                | (installed binding on disk) | partial — c4 surfaces only as load failure today |
| **probe_binding**        | `probe_binding_ocaml`, `probe_binding_python`; tiny `examples/probe_baseline.{ml,py}`      | `s5` + `s2`          | **c1** Symbol-dynamic (`dlsym`), **c4** ABI (load), **c2** API-completeness (watchlist), **c3** Behavior | `s6` (runtime trace)        | ✓ probe runs; c4 implicit; c3 vs reference       |
| **apply / revert patch** | tiny `scenarios/scenarios.py` (no canary analogue)                                         | source tree          | (perturbation — no check itself; sets up subsequent actions)                                             | mutated source tree         | ✓                                                |
| **inspect_\***           | `canary/scripts/inspect_*.py`                                                              | one artifact (n*/b*) | (extraction only — feeds comparators)                                                                    | JSON record                 | per artifact; see §2.7 inspector-coverage table  |
| **cmp_\*** (c1..c8)      | `surface/canary_compat.ml`, tiny `_harness/comparators/`                                   | two JSON records     | exactly one contract (c1..c8)                                                                            | pass/fail verdict           | per c*; see contract-status table (§2.4)         |

A key reading: the **multi-contract pipeline rows** are
`build_binding_static` and `probe_binding` — these are the actions
where a single failure could be caused by drift in several different
contracts, and where a cleaner separation of static checks (the
inspect/cmp rows below) lets us blame the root cause more precisely
than the failure mode of the pipeline action alone.

Inspect and cmp actions are 1-to-1 with their `i*` / `c*` ids — the
single-purpose rows are folded into pointers to §2.4 and §2.7 rather
than re-tabulated row-by-row.

#### 2.6.2 Phase mapping

A coarser, phase-level view of the action grid. When each contract is
checkable depends on what inputs are available at that point in the
pipeline; the phase axis collapses the action grid into four
lifecycle windows.

**Table — Phase mapping.** Four rows (lifecycle phases) × the contracts that become checkable at each. Compresses the action grid above by collapsing per-language differences.

| Phase         | Inputs available                        | Contracts checked at this phase                             |
| ------------- | --------------------------------------- | ----------------------------------------------------------- |
| Binding build | binding source + native {header, libso} | Type, Symbol (static only), API-repacking, API-completeness |
| App build     | binding artifact + app source           | API-completeness (app side)                                 |
| Process load  | binding artifact + native libso         | Symbol (dynamic), ABI, SymbolVersion                        |
| Process run   | running process + inputs                | Behavior                                                    |

A structural feature of the binding scenario surfaces here: the
header (`z3.h`) is needed at binding build but *not at process load*.
After the binding ships, the header is gone from the dependency
graph; the language-side belief about C signatures is **snapshotted**
at binding-build time. The native side can drift afterwards. This is
the **snapshot-vs-now** asymmetry — surface theory's role is to
re-inspect both sides at the *current* moment, not trust the original
snapshot.

#### Where `tiny` fits (prose gloss on the alignment table)

The tiny-scenario column of the alignment table groups into three
detection patterns worth naming explicitly:

- **Statically-detectable** (comparator catches it before runtime):
  Symbol (`e1 symbol_missing`, `e8 symbol_orphan` — c1 catches),
  API-completeness (`e6 api_complete` — c2 catches).
- **Behavior-detected** (only the runtime probe catches the
  downstream effect): Type (`e3 type_wrong`), API-repacking
  (`e5 api_repack`), Behavior itself (`e7 behavior_silent`),
  API-faithfulness (`e4 api_faithful` — even Behavior misses this
  one; it's silent, the regression test for c8).
- **Load-detected** (the OS dynamic loader is the comparator at
  process load): ABI (`e2 abi_soname_bump`). Canary observes the
  failure mode but `c4 cmp_abi` would surface it statically.

#### How the gaps decay

The ✗ rows in the alignment table split into three classes that
need different work:

- **Comparator-only gaps** (c4 ABI, c5 SymbolVersion): inspectors ✓
  (`n4` `lib_native.so` is enough for both, with `bo6` / `bo7` on
  the consumer side); just needs a small diff step on existing
  JSON. Pure plumbing.
- **Inspector-and-comparator gaps** (c6 Type, c7 API-repacking):
  inspectors ✗ on `n3` `header_native.h` and on the stub-facing
  layer across every binding mechanism (`bo1` for OCaml `external`,
  `bpc1` for ctypes `argtypes`, `bpe1` for cext `PyMethodDef`).
  Each comparator needs its inspectors built first.
- **Derived gap** (c8 API-faithfulness): blocked behind c6 and c7 via
  the §2.5 derivation.

The right way to interpret this for the paper: **canary's runtime
probe (Behavior) currently subsidises four contracts** (Type,
API-repacking, API-faithfulness, and any SymbolVersion drift) by
catching their downstream effects. The static-check side is
incomplete in two distinct ways — comparator-only and
inspector-plus-comparator — and `tiny` makes each gap *visible and
reproducible* per contract, which is the prerequisite for closing
them one at a time.

#### Implementation pointers — where each piece lives in the canary tree

For readers who want to trace the contracts to running code rather
than to the inspector/comparator IDs. Phase 4 (2026-05-28/29) added
doc-comments on the cited types and functions naming the canonical
artifacts they handle (e.g. `compat_inspect_input`'s constructors
each carry their `n*`/`bo*`/`bpe*` alias mapping inline) — so a
reader following these pointers will find the alignment table
restated in code as well.

**Table — Implementation pointers.** Per-component file references; maps the abstract `i*` / `c*` IDs to concrete files in the canary tree.

| Component                         | File / artifact                                                                                                         | Notes                                                                                    |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Inspectors (CLI scripts)          | `canary/scripts/inspect_native.py`, `inspect_binding.py`, `inspect_ocaml.py`, `inspect_python.py`                       | One per surface kind; each emits a JSON `inspect.json` with a `kind` field               |
| Comparator (pure, c1..c8)         | `src/canary/surface/canary_compat.ml` → `check_c_compat`, `check_abi`, `check_sym_version`, `check_type`, …             | Pure theory: input types + result ADTs + comparator functions; ~460 lines                |
| Comparator runner / CLI           | `src/canary/surface/canary_compat_run.ml` → `predicted_contains_any_v2`, `run_for_project`, `verify_for_project`        | Drives cached-summary lookup + the `compat` / `verify` CLI subcommands                   |
| Comparator (API-completeness, c2) | `src/canary/action/canary_step_model.ml` → `Expect_compat_failure { inputs; ... }` (uses `Canary_compat.inspect_input`) | Watchlist check inside the step-expectation runner                                       |
| Surface records (typed)           | `src/canary/surface/canary_artifact_api.ml`                                                                             | `native_api` (provider) and `binding_api` (consumer) types; survives the `Σ_*` rename    |
| Per-language inspect glue         | `src/canary/tool/canary_artifact_native.ml`, `canary_artifact_lang.ml`                                                  | Shell out to the Python scripts; cache JSONs under per-step output dirs                  |
| Step expectation                  | `src/canary/action/canary_step_model.ml` → `step_expectation`                                                           | `Expect_compat_failure { inputs; version_info }` resolves cached summaries vs. probe.log |
| Inspect-diff (drift)              | `src/canary/tool/canary_inspect_diff.ml`                                                                                | Compares two `inspect.json`s; currently informational, not a comparator                  |
| Pure tests (fixtures)             | `src/canary/test/canary_artifact_test.ml` → `compat.*`                                                                  | Synthetic fixtures exercise the comparator logic without integration runs                |

The JSONs produced by the inspectors are the load-bearing data
format. Their schema is shared across `canary action` (which feeds
them into the comparators above) and `tiny`'s scenario harness
(which runs the same comparators against tiny's artifacts via small
Python wrappers under `canary/examples/tiny/scenarios/_harness/comparators/`).

### 6. Toward a typed calculus

The long-term goal is a **typed calculus of artifact composition**.
Artifact records (§1) are values; surface roles (§2.1) are types;
the build / compile / link / pack / install operations canary
already wraps are typed transformers:

```
fetch   : Package(PM) → Source
build   : Source → Native × Headers
compile : Native × Headers → Binding(L)
pack    : Binding(L) → Package(PM')
link    : Binding(L) × Native → App
install : Package(PM) → Path

Γ ⊢ compile(native, headers, strategy) : Binding_record(L)
  where strategy ∈ {stub, ffi, jit, bindgen}
```

Transformers are *partial*: `build` fails if the source is
misconfigured; `compile` fails if the native interface doesn't
satisfy the binding's expectations; `link` fails if symbols are
missing or SONAME mismatches. Canary today wraps each transformer
with pre/post inspections; the formal version would type-check the
composition statically.

The syntactic surface is the **declared type** — what the developer
wrote. The semantic surface is the **inferred type** — what the
inspector extracts. A well-behaved build pipeline satisfies:

```
inferred_type(artifact) <: declared_type(artifact)
```

When this fails — the inferred type is *weaker* than the declared
type — there is a gap that either the toolchain or the theory must
explain. The verification angle: if each transformer has a type
signature (pre-surface → post-surface), the composition can be
checked *before* running a full build. A mismatch (e.g. a libffi
dependency that won't be satisfied at load time) becomes a type
error at the artifact level rather than a probe failure at runtime.

This is the direction roadmap step 4 starts to enable: as
inspectors and comparators land (c4..c8), the contract checks
become real predicates over typed surface roles, and per-transformer
type-checking becomes a tractable static analysis.