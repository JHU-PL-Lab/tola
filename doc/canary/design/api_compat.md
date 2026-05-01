# API compatibility model — milestone plan

Companion to [interface.md](interface.md). That doc covers the theoretical
model (L1–L5 layers, `provides ⊆ requires`, failure taxonomy). This doc
tracks the concrete implementation steps toward a **first-class compatibility
type** — an OCaml value that captures what an artifact exposes and requires,
and a checker that compares them.

**Milestone goal:** given two artifact summaries (e.g. z3 4.13 lib vs z3 4.15
binding), compute statically whether they are compatible and which specific
things are missing — without running a probe.

---

## Current state (done)

- ✅ Per-probe `summary.json` — native (nm counts + watchlist), OCaml
  (module list), Python (dir() attrs). `summary-diff` works locally.
- ✅ `api_source` — declarative three-layer structure (source → native_api →
  binding_api). Provider and consumer watchlists split. `scan_source` step
  verifies claims post-fetch.
- ✅ `Expect_failure` probes — L3 mismatch detected at compile time (LLVM 19
  vs dev binding, `Opcode.UncondBr`). Runtime-confirmed but not statically
  predicted.

---

## Step A — Clean up `binding_api.deps` (#35)

**What:** `api_component` is shared by `native_api.components` (provider side)
and `binding_api.deps` (consumer side), conflating two distinct concerns:

- **Provenance** (build-time inputs): headers + link stub. What the binding
  was compiled against.
- **Runtime contract**: the versioned `.so` the built artifact needs at load
  time.

`Link_stub` (the unversioned symlink in `-dev` packages) is a Linux packaging
detail, not a language-level concept. It should not appear in a binding spec.

**Direction:** give the consumer side its own vocabulary:

```ocaml
type build_dep = Build_headers | Build_link
type runtime_dep = Runtime_lib

type binding_api = {
  lang             : lang;
  source_dir       : string option;
  build_deps       : build_dep list;    (* what was consumed at compile time *)
  runtime_deps     : runtime_dep list;  (* what the artifact needs at load time *)
  module_watchlist : string list;
}
```

The mapping from `build_dep`/`runtime_dep` to concrete `api_component` (e.g.
which `.so` symlink to use) is a resolver concern, not part of the binding
spec. This also correctly models bundled-lib pip wheels (§5.3 in
interface.md): a co-provider that bundles its own lib has `runtime_deps = []`
at the binding level — the runtime dep is internal to the wheel.

**Value:** enables correct diagram edges for the pip co-provider case; makes
the binding spec self-documenting about what it actually needs.

## Step B — Python summary enhancements (#41, #42)

Low-effort, concrete, independent of A.

**#41 — Module-specific version extras:** `summary.version` is null for z3
and llvmlite. Add to the `extras_for(pkg, mod)` hook in
`summarize_python.py`:
- z3: `z3.get_version()` → 4-tuple in `extras.z3_version`
- llvmlite: mirror `llvm_version_info` → `extras.llvm_version`

Makes `summary-diff` across z3-solver bumps show a mechanically detectable
version delta, not just a count change.

**#42 — Attrs categorisation:** group `dir(module)` output by naming
convention (`UPPER_CASE` → constants, `CamelCase` → classes, `lower` →
functions/modules). z3 has 1789 attrs — raw attr diffs are unreadable.
Grouped counts make diffs tractable.

## Step C — Declarative C API surface from artifacts (#31)

Today `Expect_symbols { required; missing }` is hand-written per probe step.
The goal is to make expected mismatches **derivable** rather than hand-written:

```ocaml
type api_surface = {
  symbols  : string list;         (* nm output, stripped of @@ version tags *)
  versions : (string * string) list;  (* L1b: symbol → version requirement *)
}

val compare_surfaces : api_surface -> api_surface -> compat_result
```

`Expect_symbols` entries would be generated from `compare_surfaces old new`
rather than typed by hand. The summary watchlist stays as a human-curated
layer on top (names "known to be interesting" that may not appear in a diff).

This step splits naturally into two independent halves:

### Step C1 — Consumer/provider cross-check (ready now)

**Depends on:** nothing new — the building blocks already exist.

The consumer side of the C API surface — *what symbols a binding requires
from the native lib* — is given by `summarize_binding.py --kind stub` (run
`nm` on the binding's stub `.a`, collect undefined `Z3_*`/`LLVM*` symbols).
The provider side — *what symbols a `.so` exports* — is given by the
existing `summarize_native.py` via `nm -D`. With both summaries in hand,
`check_compat` reduces to set inclusion:

```
binding.requires (from stub .a) ⊆ lib.provides (from .so)
```

Concretely: predict whether `llvm.dev` binding works against `libLLVM-19.so`
by intersecting `summarize_binding.py --kind stub libllvm.a` with
`summarize_native.py libLLVM-19.so`. Missing symbols → predicted failure;
the probe then confirms.

The OCaml-level analogue is `summarize_binding.py --kind mli` against two
`.mli` snapshots — already demonstrated for `Opcode.UncondBr` vs `Opcode.Br`.

### Step C2 — Provider-vs-provider delta (#20)

**Depends on:** #20 (`assert_binary_symbols.py --provided-lib-old/new`).

Diff two `.so` files of the same project (e.g. `libLLVM-19.so` vs
`libLLVM-21.so`) to extract the *delta* — symbols added, removed, or
version-bumped. This is what feeds Step D (mismatch prediction across
project versions). Useful but not on the critical path for the basic
`check_compat`; C1 already gets us the cross-side check.

## Step D — Mismatch prediction (#16)

**Depends on:** C1 (cross-check) for the basic case; C2 (#20) for
multi-version provider deltas.

Given version metadata (two artifact versions + their `api_surface` snapshots),
predict expected failures before running probes:

```
z3 4.15 binding requires { Z3_mk_solver, Z3_mk_optimize_assert_soft, ... }
z3 4.13 lib provides     { Z3_mk_solver, ... }   (* missing: Z3_mk_optimize_assert_soft *)
→ Expect_failure { contains_any ["Z3_mk_optimize_assert_soft"] }
```

The prediction is the output of `compare_surfaces` applied to committed
`summary.json` snapshots for the two versions. Probes confirm or contradict
the prediction. Contradictions (probe passes when prediction says fail) are
a regression signal.

This closes the loop between the static model and the empirical probes.

---

## Ordering

| Step | Depends on | Value |
|------|-----------|-------|
| A (#35) | nothing | type hygiene, correct pip diagram |
| B (#41, #42) | nothing | denser diffs for Python |
| C1 (#31, partial) | `summarize_binding.py` (done) + `summarize_native.py` (done) | consumer/provider cross-check; enables basic D |
| C2 (#20) | #20 (nm-diff between `.so`s) | provider-vs-provider delta; enables multi-version D |
| D (#16) | C1 for basic; C2 for multi-version | mismatch prediction |

A and B are independent and can land in any order. C1 is unblocked by
`summarize_binding.py` and can ship now. C2 still needs #20. The natural
sequence is A → B → C1 → D-basic → C2 → D-multi-version.

---

## The first-class `interface` type

The end state: an `interface` type that makes `provides ⊆ requires` checkable
in OCaml code, not just conceptually:

```ocaml
type interface = {
  native  : api_surface option;           (* L1a/L1b: C symbols + version reqs *)
  ocaml   : string list option;           (* L3: OCaml module names *)
  python  : string list option;           (* L3: Python attr names *)
}

type compat_result =
  | Compatible
  | Missing of { symbols : string list; modules : string list }
  | Unknown  (* surface not yet captured for one side *)

val check_compat : provides:interface -> requires:interface -> compat_result
```

Today the equivalent is done empirically (compile probe → Expect_failure) or
manually (hand-written Expect_symbols). With this type:
- `check_compat` is a pure function testable without running any build
- Prediction (D) is `check_compat` applied to stored summaries
- Probe outcomes confirm or contradict the prediction
- Version constraint solving (§12 in interface.md) becomes: find versions
  where `check_compat` returns `Compatible`

---

## Execution plan

Concrete next steps to land Step C1 → Step D-basic.

### Phase 1 — Wire `summarize_binding.py` into project specs

1. **Extend `summary_cmd` helpers** to invoke `summarize_binding.py`. Two
   new `kind` values in `summary.json`: `ocaml_mli` (parse a binding's
   installed `.mli`) and `c_stub` (parse a binding's stub `.a` for
   undefined symbols).
2. **Project spec wiring** — z3 and llvm:
   - z3: stub summary on `libz3ml.a` (watchlist:
     `Z3_mk_solver`, `Z3_mk_optimize_assert_soft`, `Z3_solver_solve_for`);
     mli summary on `z3.mli` (watchlist: `Solver.add`, `Optimize.minimize`).
   - llvm: stub summary on `libllvm.a` (watchlist: a few core `LLVM*`
     symbols); mli summary on `llvm.mli` (watchlist: `Opcode.UncondBr`,
     `Opcode.Br`).
3. **Framework test** in `canary_artifact_test.ml` exercising both new
   kinds against fixed local fixtures, asserting non-zero counts and
   expected watchlist behavior.

### Phase 2 — Step C1: consumer/provider cross-check

1. **Type** in `canary_artifact_api.ml`:
   ```ocaml
   type compat_result =
     | Compatible
     | Missing of { symbols : string list }
     | Unknown   (* one side not summarized *)
   val check_c_compat :
     binding_stub:summary -> native_lib:summary -> compat_result
   ```
2. **Pure function** loading both `summary.json`s and computing set-diff.
3. **CLI subcommand** `canary compat <project> <variant>` that runs the
   check on the most recent `_out/canary/projects/<p>/<v>/` summaries.

First demo: `canary compat llvm 19` predicts the dev binding's stub
requires symbols absent from `libLLVM-19.so`, before any probe runs.

### Phase 3 — Step D-basic: derived `Expect_failure`

Two sub-steps with different invasiveness.

**Phase 3a — `canary verify` (out-of-band cross-reference, shipped).**
Read cached predictions (mli watchlist + compat result) and probe.log;
report per-layer prediction-vs-observation alignment. No pipeline change
— `step_expectation` stays hand-written; the verifier just confirms the
predictions independently. Produces a regression signal when a probe
fails for a layer where the static check predicted compatible (or vice
versa). Reachable via `canary verify <project> <variant>`.

Demo (live):
- `canary verify llvm 19` — L3 predicts FAIL on `Llvm.Opcode.UncondBr`,
  L0 predicts COMPATIBLE; probe.log confirms L3 ("Unbound constructor
  Opcode.UncondBr"); L0 has nothing to confirm/contradict.
- `canary verify llvm dev` — both layers predict COMPATIBLE; probe.log
  shows successful LLVM IR output. Both confirmed.

**Phase 3b — derived `step_expectation` (next, not yet built).**
Replace the hand-written `Expect_failure { contains_any = [...] }` with a
value derived from compat at run time. Needs:
1. The stub summary to be available *before* `probe_ocaml_binding` runs
   (move its summary step from a child of `probe_binding` to a child of
   `fetch_binding`/`pack_binding`).
2. The `expectation` field on `script_spec` to take a closure that can
   read cached summaries (`rule -> location option -> output_dir:string ->
   step_expectation`), or the runner to compute expectations after
   pre-probe summaries land.
3. A small adapter in each project spec that returns
   `Expect_failure { contains_any = compat.missing; ... }` instead of a
   hand-written list.

Once 3b lands, hand-written expectations become a fallback, used only
where compat can't decide (Python, behavioural mismatches, etc.).

### Deferred

- **Step A (#35)** — non-blocking; pick up once D-basic is in anger.
- **Step B (#41, #42)** — independent track.
- **Step C2 (#20)** — provider-vs-provider delta; orthogonal to C1.
- **Co-implementation (OCaml-native parsers).** Today the
  `summarize_*.py` scripts are invoked via shell from `canary_action`,
  with `summary.json` as the wire format. A future direction is a
  co-implementation: native OCaml parsers (probably leveraging the
  existing `src/binding/` modules — `Objinfo`, `shared_library.ml`,
  `macho.ml`) callable as functions, with the JSON form retained for
  cache/transport but bypassed during in-process analysis. Lets
  `check_compat` and follow-on analyses run without subprocess
  fan-out, and lets richer queries (typed signatures, ABI versions)
  use compiler-quality data structures instead of grep heuristics.
