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

## The shape we ended up with: a typing rule

What landed as Phases 1–3b is, in retrospect, a small typing system for
artifact compatibility:

| Implementation piece                       | Type-system analogue                        |
|--------------------------------------------|---------------------------------------------|
| `summarize_binding.py`                     | extract a consumer's required interface     |
| `summarize_native.py --emit-symbols`       | extract a provider's offered interface      |
| `Canary_compat.check_c_compat`             | the subtyping judgment `requires ⊆ provides`|
| `Expect_compat_failure`                    | a type-error report derived from a failed judgment |
| `Compatible / Missing { symbols } / Unknown` | well-typed / ill-typed-with-witness / decidability-failure |
| L0 (C) ⊑ L1b (versioned) ⊑ L3 (modules) ⊑ L5 (behaviour) | a refinement chain on interface types |

The "forward analysis and rejection" pattern of the `verify` and
`compat` commands is the artifact of treating compatibility as a
typing judgment instead of an empirical observation. `predicted_
contains_any` is the witness produced by a failed judgment — exactly
the shape of a type-error message.

Today the judgment lives at L0 (set inclusion of names). The next
theoretical step is lifting it to typed signatures: contravariance on
argument types, covariance on results, refinement on value domains.
At that point the lattice from interface.md §15 becomes the literal
subtyping order on artifact interfaces, and `check_compat` is a real
decision procedure rather than a set diff.

This framing is mostly retrospective rationale; the code can keep
calling them "compat checks" and the doc can keep talking about
"prediction." But the analogy is exact, and it suggests where the
design points: subtyping with refinement, decidable-but-conservative,
backed by empirical probes for the layers that aren't yet typed.

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

**Phase 3b — derived `step_expectation` (shipped).**
Replaces the hand-written `Expect_failure { contains_any = [...] }` with
a new variant `Expect_compat_failure { stub_summary; lib_summary;
mli_summary; version_info }` whose contents are *derived at evaluation
time* from cached compat summaries.

Implementation:
1. **Auto-summary moved.** `auto_binding_summaries` now emits both mli
   and stub summaries on `Fetch (Binding OCaml)` / `Publish (Binding
   OCaml)` (the install step) instead of `Probe (Binding _)`. The
   summaries are cached in `<run_dir>/fetch_ocaml_binding/` or
   `<run_dir>/pack_ocaml_binding/` *before* `probe_binding` runs.
2. **New step_expectation variant** carries a list of candidate relative
   paths for each summary kind (so the same expectation works for both
   `fetch_*` and `pack_*` variants). The runner picks the first existing.
3. **Runner derives contains_any** by calling
   `Canary_compat.predicted_contains_any` with the resolved paths. Empty
   derived list ⇒ falls back to "any failure with non-empty probe.log".
4. **Project spec adapter** — LLVM's stable-variant probe expectation now
   reads:
   ```ocaml
   Expect_compat_failure {
     stub_summary = [ "pack_ocaml_binding/stub_summary.json";
                      "fetch_ocaml_binding/stub_summary.json" ];
     lib_summary  = [ "probe_lib/summary.json"; "probe_lib_apt/summary.json"; ... ];
     mli_summary  = [ "pack_ocaml_binding/summary.json";
                      "fetch_ocaml_binding/summary.json" ];
     version_info = Some { ... };
   }
   ```
   No hand-written `contains_any`.

Live demo:
```
[probe_ocaml_binding] cmd_fail (exit 1)
[probe_ocaml_binding] compat_predicted (3 substring(s))
[probe_ocaml_binding] done (expected failure confirmed (derived):
                           llvm 19 predates Opcode.UncondBr,
                           added in LLVM 21 (dev, commit #186176))
```

Hand-written `Expect_failure` remains for cases compat can't decide.
Two distinct sub-cases worth separating:

- **Not yet wired (3c candidate).** Python summary already exists
  (`summarize_python.py` produces `dir()` attrs + L3 watchlist). The
  L3-driven `Expect_compat_failure` for Python is implementable today
  by extending `predicted_contains_any` to consume Python attr
  summaries; just hasn't been wired. Note Python typically has no L0
  cross-check (pip wheels bundle their own native lib — co-provider
  case from §5.3) so it would be L3-only.

- **Inherently behavioural.** Failures that no static summary can
  predict — version-string mismatches in import logs, functions that
  exist but return wrong results, runtime initialization order. These
  legitimately remain hand-written; they require an actual probe run.

**Phase 3c — typed compat inputs (shipped).**
The `Expect_compat_failure` variant is now language-agnostic:

```ocaml
type compat_summary_input =
  | C_stub      of { paths : string list }
  | Native_lib  of { paths : string list }
  | Ocaml_mli   of { paths : string list }
  | Python_attrs of { paths : string list }

| Expect_compat_failure of {
    inputs       : compat_summary_input list;
    version_info : version_info option;
  }
```

`Canary_compat.predicted_contains_any_v2` consumes the list, picks the
first existing path per input (resolved against the run dir), and
unions the predictions: L0 set diff for `C_stub` ∩ `Native_lib`, L3
watchlist-missing (with name-variant expansion) for `Ocaml_mli` and
`Python_attrs`. Each language contributes whichever layers apply.

LLVM's spec now uses the new shape:
```ocaml
Expect_compat_failure {
  inputs = [
    C_stub      { paths = [ "pack_ocaml_binding/stub_summary.json"; ... ] };
    Native_lib  { paths = [ "probe_lib/summary.json"; "probe_lib_apt/summary.json"; ... ] };
    Ocaml_mli   { paths = [ "pack_ocaml_binding/summary.json"; ... ] };
  ];
  version_info = ...;
}
```

Unit tests in `canary_artifact_test.ml` (`compat.mli_dotted_expansion`,
`compat.python_attr_expansion`, `compat.mixed_inputs_union`,
`compat.empty_inputs`) exercise the helper directly without a real
probe, demonstrating that `Python_attrs` works correctly.

**Phase 3d — Python pip probe split (shipped).**
The pip flow is now split into install + probe:

- `Canary_toolchain.pip_install_cmd` does just `pip install` (+ writes
  `binding.ok` marker). Wired in as a `Fetch (Binding Python)` entry on
  z3, llvm, sqlite project specs.
- `Canary_toolchain.python_probe_only_cmd` does just `python -c …` —
  the import-and-test snippet, no install.
- `auto_binding_summaries` emits `summarize_python.py` on
  `Fetch (Binding Python)` instead of `Probe (Binding Python)`.
- `Canary_compat.find_python_install_dir` /
  `find_python_summary` look in `fetch_python_binding/`.
- The `pip_probe_cmd` shim is retained (composes the two halves) for
  backward compatibility.

`derive_steps` callers in `canary_main.ml` now pass
`~langs:[OCaml; Python]` for action targets that have Python probes;
without that, `store_rules` filters Python rules out at graph
generation.

After a fresh `canary action z3` run, the layout is:
```
_out/canary/projects/z3/<variant>/
├── fetch_ocaml_binding/{summary.json, stub_summary.json}
├── fetch_python_binding/{binding.ok, install.log, summary.json}
├── probe_ocaml_binding/probe.log
└── probe_python_binding/probe.log
```

`probe_python_binding` evaluates AFTER `fetch_python_binding_summary`
has cached `summary.json`, so an `Expect_compat_failure { inputs = [
Python_attrs { paths = ["fetch_python_binding/summary.json"] }; … ] }`
on the probe step resolves correctly.

**Phase 3e — Python derived expectation in production (shipped).**
The z3-solver pip wheel (4.16.0 as of 2026-05-01) doesn't export
`parser_context` from the `z3` namespace, even though it's defined in
the Z3 4.15+ Python source. Z3's project spec exploits this real
forward-incompat for the demo:

- `python_binding.module_watchlist` includes `parser_context`. The
  cached `fetch_python_binding/summary.json` reports it as missing.
- The probe snippet references `z3.parser_context` (causes a clean
  `AttributeError`).
- z3's `expectation` field returns `Expect_compat_failure { inputs =
  [Python_attrs { paths = ["fetch_python_binding/summary.json"] }];
  ... }` for the Python pip probe.

Live demo (canary action z3, stable variant):
```
[probe_python_binding] cmd_fail (exit 1)
[probe_python_binding] compat_predicted (1 substring(s))
[probe_python_binding] done (expected failure confirmed (derived):
                             z3-solver pip wheel predates z3.parser_context,
                             added in Z3 4.15+ Python source ...)
```

`canary verify z3 stable` now reports three layers — L3 OCaml,
L3 Python, L0 C ABI — each with its own probe.log analysis and
verdict.

**Future directions (in backlog).**

- **L1b — versioned symbol requirements (#43).** Lift `check_c_compat`
  from name-level set inclusion to versioned matching (`@@GLIBC_2.31`
  floors etc.). Data already in `summarize_native.py`'s
  `versioned_req`; just needs to flow into the check.
- **L2 — typed signatures (#44).** Move from name set inclusion to a
  real subtyping system: types via clang AST for C, ocamlc signatures
  for OCaml, Python type-stub equivalents. Catches "same name, wrong
  signature" version drift that name-level checks miss. See
  interface.md §15 and the typing-rule observation above.

**Inherently behavioural failures** (version-string mismatches in
import logs, functions that exist but return wrong results, runtime
init-order issues) legitimately remain hand-written `Expect_failure`;
they require an actual probe run.

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
