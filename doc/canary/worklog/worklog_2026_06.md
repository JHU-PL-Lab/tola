# Worklog — 2026-06 (Phases 14a through 15.7)

This worklog absorbs the per-phase chronicle that previously lived inline
in [research/plan.md §6 Step 7 / Phase 14 / Phase 15](../plan.md).
Each entry describes what shipped, why, and where it landed. plan.md
itself now keeps only the forward-looking sections (Step 7 framing,
Phase 16 sketch, Phase 17+ sketch) and points here for the chronicle.

The June 2026 work formed two superphases:

- **Phase 14 (a–g)** — tiny matrix mechanics: per-variant workspaces,
  per-artifact-kind stores, store/cache fixups, plus c1 / c2 / c3 / c4
  wired and demoed on tiny variants.
- **Phase 15 (.1–.7)** — finishing the tiny matrix: c5 / c6 / c7 + the
  Contract-vs-check reframing, plus an audit cleanup.

Thirteen tiny variants on `canary action tiny` at the end of June, all
passing. Active Contracts firing (with attribution): c1 OCaml (missing
+ orphan), c1 Python, c2 OCaml, c2 Python, c3 both, c4 Python, c5
Python, c6 OCaml, c7 OCaml + Python. c8 dormant (no Contract).

## Phase 14 — tiny matrix mechanics

### 14a — proof of concept with one perturbed variant (2026-06-01)

**14a (small, today).** Proof of concept with one perturbed variant.
- `base_script_spec` (= today's spec, no behavior change)
- `lib_broken_script_spec` (c1 fires at probe_binding_ocaml)
- Tiny becomes multi-variant — `canary action tiny` switches from
  single-variant (`script_spec` directly) to `run_project_multi`
  over the two variants.
- Workflow: `scenarios.py restore e1 && canary action tiny/lib_broken`
  → c1 fires; `scenarios.py restore-baseline && canary action tiny`
  → both variants pass (after restore-baseline, lib_broken's
  expectation matches "no failure → unexpected_success"; we need to
  document that restore-baseline is incompatible with the
  full-matrix invocation until 14b lands).

### 14a follow-up — c2 OCaml (binding_mli_broken) shipped (2026-06-02)

Maps canary against harness scenario e6 (`api_complete` removes `val sum`
from tiny.mli). The naive attempt revealed that c2 didn't fit tiny's
original step model, so the followup landed four coordinated changes:

1. *Build/Probe split for OCaml.* Build (Binding OCaml) now targets
   only `tiny.cmxa` + `libtiny_stubs.a` — the binding library. Probe
   (Binding OCaml) does `dune build probe_baseline.exe && exec`,
   redirecting both the compile and runtime stages to `probe.log`.
   This puts the c2 violation at Probe, matching how it surfaces on
   real projects (llvm/z3 install the opam-packed binding, then
   compile the consumer at Probe time).

2. *Two-file inspect at Build (Binding OCaml).* Build's inspect step
   produces `inspect.json` (stub side, c1) and `inspect_mli.json`
   (mli side, c2) so both JSONs exist before Probe evaluates its
   expectation.

3. *`-w -32` on tiny's library dune stanza.* dune treats
   unused-value-declaration as an error by default, which conflated
   "the .ml may legitimately expose more than the .mli" (OCaml language
   semantics) with "API-completeness violation" (c2). Relaxing it lets
   the library compile cleanly under mli-narrowing perturbations; the
   c2 violation surfaces at the consumer compile where it conceptually
   belongs. Harness `_try_build_ocaml` was also narrowed to library
   targets, and e6's expected outcomes flipped from `ocaml_build: fail`
   / `ocaml_probe: skip` to `ocaml_build: ok` / `ocaml_probe: fail`.

4. *Inspector `--module-prefix` flag.* `inspect_binding.py --kind mli
   --path` previously matched watchlist entries against bare top-level
   `vals` (so `Tiny.sum` would never match `sum`). Opt-in
   `--module-prefix Tiny` prefixes extracted names so the consumer-side
   qualified watchlist matches honestly. Tiny's spec passes it on both
   mli inspect sites.

End-to-end on e6: Build succeeds (library compiles with sparser mli),
Probe's dune-build fails ("Unbound value Tiny.sum"), c2's
`Ocaml_mli [build_binding_ocaml/inspect_mli.json]` resolves to predicted
substring `Tiny.sum`, the substring is found in probe.log, and the
runner logs `compat_predicted (2 substring(s))` →
`done (expected failure confirmed (derived))`.

### 14b — coexistence via materialized workspaces (2026-06-02)

- Tiny harness gains side-by-side materialized workspaces:
  `scenarios.py baseline` and `prepare <name>` each write a
  self-contained dune workspace at `_cache/<scenario>/workspace/`
  containing the full perturbed source tree + built artifacts
  (libtiny.so*, tiny_cext _native.so) + a minimal `dune-project` at
  the root.
- canary's tiny spec is parameterized: one
  `make_base_script_spec ~workspace_root` consumed by each variant.
  Dune commands use `--root <workspace_root>`. Configure / build_lib
  become artifact-verification (the cache pre-builds them); only
  build_binding_ocaml runs dune.
- `canary_main.ml` wires variants to scenario workspaces:
  baseline → `_cache/baseline/workspace`, lib_broken →
  `_cache/symbol_missing/workspace`, binding_mli_broken →
  `_cache/api_complete/workspace`. The harness↔canary scenario
  mapping lives in this variant table — canary's spec is unaware.
- `canary action tiny` runs the full matrix in one invocation. No
  restore ceremony. Three variants confirm honestly:
    - baseline: every step `done`.
    - lib_broken: `compat_predicted (1 substring(s))` (c1 →
      `tiny_sum`) at probe_binding_ocaml; `Expect_failure` matches
      `tiny_sum` at probe_binding_python (cext ImportError surfaces
      the undefined symbol).
    - binding_mli_broken: `compat_predicted (2 substring(s))` (c2 →
      `Tiny.sum` variants) at probe_binding_ocaml.

  Coordinated side-changes that landed with 14b:
    - `dune_build_cmd ?root` flag (canary_build_cmd.ml).
    - `Build_lib` gets a native inspect attached, so c1's
      `Native_lib` input cites `build_lib/inspect.json` (the lib
      JSON is available before any probe step's expectation evaluates;
      probe_lib can run later in topological order without breaking c1).
    - `inspect_python.py` exits 0 on import error (writes a JSON with
      an `error` field). Exit code now reflects "inspector ran," not
      "target healthy" — target health is a JSON-content question.
    - tiny library's dune stanza already had `-w -32` from Phase 14a.

  Deferred — addressed in Phase 14d (Python c1, 2026-06-02).

### 14b' — per-artifact-kind stores (2026-06-02)

- `tiny_stores = { source; lib_dir; python_cext_root }` in
  `canary_project_tiny.ml`. Each field is a directory serving one
  artifact kind:
    - `source`: tree root containing `c/`, `ocaml/`, `python_cext/`;
      also the dune workspace root (`dune build --root source`).
    - `lib_dir`: directory containing `libtiny.so*` — used as
      `LIBRARY_PATH`, `LD_LIBRARY_PATH`, and inspected by `Build_lib`
      and `Probe Lib`.
    - `python_cext_root`: dir under which `tiny_cext/` lives — used
      as `PYTHONPATH` when running Python probes.
- `make_base_script_spec ~stores` consumes the record; every closure
  reads from `source / lib_dir / python_cext_root` rather than from a
  single workspace path. Same shape for `make_lib_broken_script_spec`
  and `make_binding_mli_broken_script_spec`.
- `stores_of_workspace ~workspace_root` is the single-workspace
  constructor — today's three variants all use it (one
  materialized workspace per variant). The cross-product door is now
  open: a variant could mix `{ source = baseline_ws; lib_dir =
  symbol_missing_ws/c/build; … }` to point at multiple workspaces.
- `canary_main.ml` is unchanged in shape — it just calls
  `stores_of_workspace ~workspace_root:(cache_workspace_of ~scenario)`
  per variant.

Smoke test (`canary action tiny`) is unchanged end-to-end: baseline +
lib_broken (c1 fires, Python fails) + binding_mli_broken (c2 fires)
all honest.

### 14c — cross-products + broader scenario coverage (2026-06-02)

Two pieces landed together:

- `binding_python_attrs_broken_script_spec`: c2
  cmp_api_completeness on the Python side. Maps to harness scenario
  [e11 api_complete_python] (drops `sum` from
  `python_cext/tiny_cext/__init__.py`). Probe (Binding Python)
  imports tiny_cext, calls `tiny_cext.sum`, raises AttributeError.
  c2's Python_attrs input cites `build_binding_python/
  inspect_attrs.json`, produced by Build (Binding Python)'s now
  *two-file* inspect (cext native symbols + dir(tiny_cext) attrs).
  Mirrors the OCaml two-file inspect introduced in 14a. Fires with
  1 substring `sum`.

- `hybrid_lib_broken` variant in canary_main.ml: baseline source +
  symbol_missing lib_dir. Same expectation shape as `lib_broken`
  (c1 fires at probe_binding_ocaml; Python probe substring-matches
  tiny_sum), reached via per-kind store wiring — the source/binding
  artifacts come from `_cache/baseline/workspace`, while the lib
  artifact comes from `_cache/symbol_missing/workspace/c/build`.
  Validates that the per-kind model from 14b' actually delivers
  mix-and-match, not just the API.

Five variants total now ride one `canary action tiny` invocation:
baseline, lib_broken, binding_mli_broken,
binding_python_attrs_broken, hybrid_lib_broken.

### Phase 14d — honest c1 Python (2026-06-02)

The `lib_broken` and `hybrid_lib_broken` Python expectations dropped the
hand-written `Expect_failure { contains_any = ["tiny_sum"] }` for a
proper `Expect_compat_failure` with c1 inputs:

```
Probe (Binding Python) ->
  Expect_compat_failure {
    inputs = [
      C_stub     [ "build_binding_python/inspect.json" ];
      Native_lib [ "build_lib/inspect.json" ];
    ];
    ...
  }
```

The C_stub input is produced by extending `inspect_binding.py --kind
stub` to handle shared libraries (`nm -D` on `.so`/`.dylib`/`.cpython-
*.so` reads the dynamic symbol table). The cext `.so`'s undefined
refs filtered by the `tiny_` prefix are the "stubs" — the Python
analog of `libtiny_stubs.a`. Build (Binding Python)'s inspect was
restructured to a two-file step (stub + attrs), mirroring Build
(Binding OCaml).

Contracts now firing honestly across all five variants:
- c1 cmp_symbol OCaml: lib_broken + hybrid_lib_broken.
- c1 cmp_symbol Python: lib_broken + hybrid_lib_broken (no more
  hand-written substring; the predicted `tiny_sum` flows from the
  registered c1 predicate).
- c2 cmp_api_completeness OCaml: binding_mli_broken.
- c2 cmp_api_completeness Python: binding_python_attrs_broken.

### Phase 14e — c4 cmp_abi wired, demoed on lib_soname_bumped (2026-06-02)

Wires c4 end-to-end against harness scenario `abi_soname_bump` (libtiny.so.1 → libtiny.so.2
SONAME bump). The provider's bumped SONAME doesn't match the cached
cext's NEEDED (libtiny.so.1, recorded at the cext's original build
time); c4 predicts the missing NEEDED entry.

Implementation pieces:
- `inspect_binding.py --kind stub` on shared libs now emits an `elf`
  sub-object (SONAME, NEEDED, RPATH, RUNPATH) via `readelf -d`. The
  same JSON serves both c1 (`requires`) and c4 (`elf.needed`).
- `Canary_compat.load_abi_surface` reads `elf.soname` + `elf.needed`
  from any inspect JSON.
- `c4_predict` is no longer a no-op: it pairs a `Native_lib` input
  (provider's SONAME) with an `Abi_surface` input (consumer's NEEDED),
  runs `check_abi`, and on mismatch returns the consumer NEEDED
  entries that share the provider's family-stem (e.g. `libtiny` from
  `libtiny.so.1`/`libtiny.so.2`) — dyld's runtime error mentions the
  missing NEEDED verbatim.
- Registry flipped C4's status from `Stubbed` → `Wired`.
- `tiny_stores` gained a `lib_filename` field (default
  `libtiny.so.1`); `lib_soname_bumped` variant overrides to
  `libtiny.so.2`. `stores_of_workspace` takes an optional
  `?lib_filename` arg.
- `_snapshot_workspace` strips DT_RUNPATH from cached cext .so files
  (via `patchelf --remove-rpath`) and synthesizes a `libtiny.so`
  symlink in `c/build/` when missing — both unblock c4 demos.
  The first prevents dyld from falling back to the live tree's
  unperturbed libtiny via the cext's baked-in runtime_library_dirs;
  the second lets `dune --root <ws>` link `-ltiny` against the
  bumped lib (canary's fresh workspace has no dune cache to lean on
  the way the standalone harness does).
- `lib_soname_bumped_script_spec` attaches Expect_compat_failure at
  `Probe (Binding Python)` with `Native_lib` + `Abi_surface` inputs.
  OCaml is unaffected because canary's `build_binding` rebuilds the
  OCaml binding fresh against the bumped lib (NEEDED tracks the new
  SONAME, no mismatch); only the Python cext (built earlier and
  cached) carries stale NEEDED.

End-to-end on `canary action tiny`: six variants now ride one
invocation, all pass.

### Phase 14f — c3 cmp_behavior demoed on lib_behavior_broken (2026-06-02)

Adds `lib_behavior_broken` variant mapping to harness scenario
`behavior_silent` (tiny_sum computes `a - b - tiny_offset` instead of
`a + b + tiny_offset`; symbols, SONAME, mli, attrs all unchanged).

c3 is structurally different from c1/c2/c4/c5. Those derive failure
substrings from inspector JSONs via `predict`; c3 is dynamic — the
behavioral truth lives in the running binary, and the expected
values are embedded as assertions in the probe's source
(`if expected <> actual then exit 1`). The comparator IS the probe's
exit-code check, surfaced to canary via `Expect_failure
{ contains_any = ["FAIL "] }` (the tiny probes print `FAIL …` on
mismatch, both OCaml and Python).

So c3 didn't need a `predict` rewrite. The C3 registry entry's
status stays `Blocked []` and `enabled = false` — those reflect the
predict side being a no-op, which is accurate. Coverage is via
the probe runner, documented in the registry comment.

Smoke (`canary action tiny`): both OCaml and Python probes for
lib_behavior_broken `cmd_fail (exit 1)` → `done (expected failure
confirmed)`. probe.log contains literally
`FAIL Tiny.sum 2 3: expected 47, got -43` (and analogous Python),
exactly the perturbation's math (2 - 3 - 42 = -43).

### Phase 14g — c1 orphan direction via binding_overdeclares_stubs (2026-06-03)

Adds `binding_overdeclares_stubs` variant mapping to harness scenario
`symbol_orphan` (e8). The OCaml cstub references `tiny_extra` that
the lib never had — the dual of `lib_broken` (there the lib lost a
symbol; here the binding gained a reference).

c1's `predict` already handles both directions via the set-diff
`stub.requires \ lib.symbols` in `check_c_compat`. The new variant
uses identical c1 inputs to `lib_broken`'s; what differs is the
workspace (`_cache/symbol_orphan/workspace/`) where the cstub's
`requires` includes `tiny_extra` and the lib's symbols don't.

Only OCaml is perturbed in e8 (tiny_raw.ml, tiny_raw.mli,
tiny_stubs.c gain the `tiny_extra` binding). Python cext is
untouched — so the variant's Python probe expectation is
`Expect_success`, not c1. This is why we couldn't reuse
`make_lib_broken_script_spec` (which expects Python to also fail);
needed a dedicated `make_binding_overdeclares_stubs_script_spec`.

Smoke: probe_binding_ocaml `cmd_fail (exit 1)` → `compat_predicted
(1 substring)` → `done (expected failure confirmed (derived))`.
probe.log contains `mold: error: undefined symbol: tiny_extra`,
matching the c1 predicted `tiny_extra` from the cstub-vs-lib diff.

Tiny variant matrix at end of Phase 14: eight variants.

## Phase 15 — finishing the tiny matrix

### Phase 15.1 (doc + plan refresh — 2026-06-03)

Rewrote `design/harness_canary_orthogonality.md` (retired 2026-08; `git show 6e2dfcb^`)
to lead with the orthogonal vision (stores = artifact providers,
runners = canary pipeline, producers = harness apply / package
managers) rather than with the leak workarounds. The synthetic-vs-natural
axis is the key insight: tiny's perturbed stores mimic divergences
that real package versions create naturally; the same runner consumes
both. The leaks become "places where producer + runner aren't
yet separated" rather than ad-hoc workarounds.

plan.md gained a Phase 15 sequence — the steps to finish the tiny
contract matrix via hardcoded-constant inspectors instead of
building clang-AST inspectors up front.

### Phase 15.2 — app_helper_lib_broken validates c1 through helper chain (2026-06-03)

Adds `?probe_exe` optional parameter to `make_base_script_spec` and
`make_lib_broken_script_spec` (default `ocaml/examples/probe_baseline.exe`;
variants can override). The probe step's dune build target threads
through.

New variant `app_helper_lib_broken`: same store + expectation as
`lib_broken` (workspace `_cache/symbol_missing/workspace/`), but the
OCaml probe builds and exec's `ocaml/examples/app_helper.exe` instead
of probe_baseline.exe. dune pulls in tiny_helper.cmxa transitively,
which depends on tiny.cmxa, which depends on libtiny_stubs.a, which
needs tiny_sum from libtiny — the longest-interesting chain.

c1 fires identically: mold's link error mentions tiny_sum (the
missing symbol predicted from stub.requires \ lib.symbols),
substring matches, expectation confirmed (derived). Validates the
contract model propagates through the binding → helper → app
layers without any change to the c1 predicate.

### Phase 15.3 — typed-signature inspector infrastructure (2026-06-03)

Lands the plumbing for c6/c7/c8 to wire against typed function
signatures, without committing to the heavy clang-AST inspector work
up front.

Inspector script (`canary/scripts/inspect_tiny_typed.py`):
Trivial-grep stand-in for a real AST inspector. One file, five
`--layer` flags (header, stub_ocaml, user_ocaml, stub_python,
user_python). Each layer has a hardcoded `{name → typed signature}`
map; the script greps the artifact for each known name and emits
JSON of present-and-known entries. If the artifact perturbs a
declaration away, grep won't find it, so the emitted JSON drops it
— c6/c7/c8 predicates can then detect the divergence honestly.

OCaml side (canary_compat.ml):
- New inspect_input cases: Typed_header, Typed_binding_stub,
  Typed_binding_user.
- New typed_signature record + typed_signatures_inspect view.
- load_typed_signatures reads any "typed_<layer>" JSON and returns
  a list of (name, signature) pairs plus the layer string.

Spec wiring (canary_project_tiny.ml):
- Build_lib's inspect now also produces inspect_typed_header.json
  (greps c/include/tiny.h).
- Build_binding (OCaml)'s inspect now also produces
  inspect_typed_binding_stub.json (greps ocaml/tiny_raw.mli) and
  inspect_typed_binding_user.json (greps ocaml/tiny.mli).
- Build_binding (Python)'s inspect now also produces
  inspect_typed_binding_stub.json (greps _native.c) and
  inspect_typed_binding_user.json (greps __init__.py).

### Phase 15.4 — c5 cmp_sym_version wired, demoed on lib_symbol_version_broken (2026-06-02 / 06-03)

Wires c5 end-to-end against new harness scenario `symbol_version_floor`
(e9). The lib's tiny.map is bumped from TINY_1.0 to TINY_2.0; the
rebuilt libtiny.so exports `tiny_sum@@TINY_2.0` etc.; the cached
cext (built when lib exported @@TINY_1.0) carries `@TINY_1.0` in
its NEEDED. dyld can't satisfy the version tag at load time even
though the lib's filename and bare symbol names are unchanged.

Pieces landed:

- Tiny adopts real ELF symbol versioning. New canary/examples/tiny/
  c/tiny.map (version script) + CMakeLists.txt update with
  target_link_options and LINK_DEPENDS. Bare lib now exports
  `tiny_sum@@TINY_1.0` etc.; consumers (cstubs, cext) record
  `@TINY_1.0` in undefined refs. Same mechanism glibc uses.

- New harness scenario symbol_version_floor — patches c/tiny.map
  flipping TINY_1.0 → TINY_2.0; `_c_patch_apply` rebuilds the lib via
  cmake (LINK_DEPENDS makes the relink happen). PERTURBABLE_SOURCES
  gains c/tiny.map.

- inspect_binding.py --kind stub now also emits versioned_req on .so
  files (parses @VER suffixes from nm's undefined entries).

- canary_compat.ml: new inspect_input cases Versioned_exports
  (provider) + Versioned_req (consumer). New load_versioned_symbols
  loader.

- c5_predict no longer inspect-only: pairs a Versioned_exports input
  (provider's elf.versioned_exports) with a Versioned_req input
  (consumer's elf.versioned_req), runs check_sym_version, on mismatch
  returns the consumer's required version tags that the provider
  doesn't export. C5 registry status flipped Inspect_only → Wired.

- New variant lib_symbol_version_broken with Expect_compat_failure at
  Probe (Binding Python). OCaml side unaffected — canary rebuilds the
  OCaml binding against the bumped lib so its NEEDED tracks @@TINY_2.0
  (no mismatch). Only the cached Python cext carries the stale @TINY_1.0
  reference. Same pattern as lib_soname_bumped.

### Phase 15.5a — Scan_sources rule + scan_sources spec field (2026-06-03)

Adds `Scan_sources` as a first-class rule in the action graph.
Project specs declare WHEN it runs via `scan_sources_after` (default
`Configure`, override for projects with generated bindings):

  scan_sources       : (output_dir → variant_key → cmdline) option
  scan_sources_after : rule option   (default Configure)

For tiny (hand-written binding source), scan_sources runs after
Configure. For z3 (future — binding source generated by cmake),
scan_sources_after = `Some Build_lib` so the inspector sees the
generated source. The pipeline stays uniform; placement is per-spec.

Why: c6/c7/c8's typed-signature inspects need to run BEFORE Build
(Binding _) because that's where their target perturbations cause
compile failure. With the inspect attached to Build_binding as a
follow-up, it gets skipped when Build fails — c6 has no JSON to
read. scan_sources runs early enough to side-step that trap.

Build (Binding OCaml) cmd wraps in a `(...) > build.log 2>&1`
redirect so c6's substring-match has stderr to grep when the
cstub compile fails (header arity mismatch etc.). Marker echo
still chains on dune success.

### Phase 15.5b — c6 cmp_type wired, demoed on binding_type_broken (2026-06-03)

Wires c6 end-to-end against new harness scenario `header_arity_bump`.
tiny.h declares tiny_sum with an extra `(int c)` parameter; tiny.c
matches so the lib still builds. The cstub (tiny_stubs.c) calls
tiny_sum with two args. When canary rebuilds the cstub against the
perturbed header, the C compile fails with `error: too few arguments
to function 'tiny_sum'`. c6 catches the mismatch statically by
diffing the header's parsed signature (3 args) against the binding
stub's signature (2 args).

Pieces:

- inspect_tiny_typed.py extended: the "header" layer now actually
  parses C declarations via regex (`<return> <name>(<args>);`)
  instead of using hardcoded sigs. Other layers stay hardcoded; they
  graduate to parsing when their c6/c7 scenarios land.

- inspect_binding.py made graceful on missing artifacts: when nm
  can't open the input (.a / .so), parse_stub_a returns empty
  required + an error string instead of raising. summarize_stub
  packs the error into the JSON. Exit 0 so the inspect step
  succeeds; the c_stub JSON's "error" field signals "binding not
  built." Lets downstream steps run after expected build failures
  (like binding_type_broken) without cascading.

- canary_compat_run.ml: c6_predict implemented (pairs Typed_header +
  Typed_binding_stub, diffs sigs by name+return+arg list, returns
  mismatching names). Registry status flipped Blocked → Wired,
  enabled = true.

- Harness scenario header_arity_bump in scenarios.py +
  patches/header_arity_bump.patch.

- New variant binding_type_broken_script_spec. Attaches
  Expect_compat_failure with c6 inputs at BOTH Build (Binding OCaml)
  and Probe (Binding OCaml) — Build fires the primary c6, Probe re-
  attempts the same cstub compile via `dune build probe_baseline.exe`
  and hits the same error (same c6 prediction).

### Phase 15.6 — c7 reframed as api_sound_repack; c8 disabled (2026-06-03)

Earlier framing treated c7 / c8 as static comparators awaiting
clang-AST-class inspectors. This commit lands the cleaner position:

Contract vs comparator/check are independent axes. A Contract is the
theoretical agreement at a surface boundary; a check is one possible
implementation (static comparator, runtime probe, binding-side test,
compile failure, ...). Folding c7's runtime symptoms into c3's
comparator banner conflated the two.

c7 renamed `api_sound_repack` (dropped cmp_ prefix). The Contract is
"the binding's user-facing layer is a sound repacking of its stub-
facing layer." The check shape (probe-assertion refutation) is
identical to c3's; the difference is attribution — c3 attributes
failure to native lib behavior, c7 to the binding's repack. The
variant declaration (which surface was perturbed) determines
attribution. predict stays no-op; status Stubbed; layer "dyn".

c8 disabled and renamed status to Stubbed (candidate for future
enum removal). No Contract for canary to maintain — each binding is
independent; cross-binding consistency isn't a canary-side
agreement to check. Probes happen to assert the same constants
across languages by project convention.

New tiny variant `binding_repack_broken` mapping to harness scenario
api_repack (e5: `Tiny.diff a b = Tiny_raw.diff b a`, silent arg
reversal). Same Expect_failure shape as `lib_behavior_broken`; OCaml
side only because api_repack perturbs ocaml/tiny.ml — Python cext
is independent.

### Phase 15.6 followup — c7 Python parallel (2026-06-03)

Adds the Python-side parallel of `binding_repack_broken`. Same c7
(api_sound_repack) Contract; different binding. Maps to harness
scenario `api_repack_python` (e10): python_cext/tiny_cext/__init__.py's
diff silently reverses its arguments before delegating to
_native.diff.

Probe asserts `tiny.diff(5, 2) == 3`; with perturbation it computes
`_native.diff(2, 5) = -3`; assertion fires `FAIL tiny.diff(5, 2)`.
Same Expect_failure shape as `binding_repack_broken` (OCaml side).

Validates that c7 attribution applies symmetrically across
bindings without canary having to disambiguate at the detection
layer. Each binding is independent; OCaml's repack soundness and
Python's repack soundness are separate Contracts at the same
abstraction tier.

### Phase 15.7 — audit cleanup (docs sync, dead code prune; 2026-06-03)

Post-Phase-15 audit found ~10 small staleness / dead-code items.
This commit lands the safe cleanups; no behavior change beyond
prune of one duplicate inspect step. All 13 variants still pass
canary action tiny end-to-end.

Code:
- run_tiny's unknown-variant error message now lists all 13 variants,
  not just "(baseline), lib_broken". Computed from the variant table.
- Dropped the Probe Lib inspect — comment admitted it was redundant
  with build_lib's identical inspect.
- Dropped the deprecated Versioned_symbols ADT case and its fallback
  in c5_predict. Only the split Versioned_exports / Versioned_req
  cases remain.
- Updated canary_compat_run.ml docstring for c3/c7/c8 stubs to
  reflect Phase 15.6 reframing.
- Removed stale "(placeholder until c4 wires up)" comment on the
  soname field of tiny_api_source.
- Removed stale bpc2/ctypes references in the python watchlist
  docstring.
- find_lib_inspect / resolve_variant lookup paths now include
  build_lib and build_binding/<lang> alongside their pack_/fetch_
  predecessors so canary verify / compat CLIs can locate tiny's
  inspect JSONs.

Docs:
- tiny.md: harness↔canary mapping table expanded to all 13 current
  variants. Inspector coverage table updated to reflect
  inspect_tiny_typed.py covering n3/bo1/bpe1/bo4/bpe2 layers.
  Comparator coverage table marks c4/c5/c6 as wired statically, c7
  as wired via probe runner, c8 disabled. e9 section rewritten as
  shipped.
- surface_theory.md §2.4 contract table: c4/c5/c6/c7 flipped from
  ✗ to ✓; c8 row marked disabled.
- plan.md §6 Step 4 prefaced with a status note marking it
  superseded by Phases 14e / 15.4 / 15.5b / 15.6.
- CLAUDE.md: tiny.md description updated (8 scenarios → 13 variants).
  TODOs #43 (c5) and #44 (c6) marked shipped with phase references.

### Unit-test harness closure (TODO #15b, accumulated through Phase 14–15)

`src/canary/test/canary_artifact_test.ml` is the compat/inspect unit-
test harness foreseen as TODO #15b. Phase 4 (worklog
`phase4_2026_05.md`) inspected and renamed it; Phase 14e / 15.4 /
15.5b / 15.6 added the per-contract `cmp_*_pure_tests` sections as
each comparator wired in. End-of-June state: **64 named cases**
across c1 (cmp_symbol), c4 (cmp_abi), c5 (cmp_sym_version),
c6 (cmp_type), c7 (cmp_api_repack), c8 (cmp_api_faithfulness),
plus `native_pure_tests`, `ocaml_pure_tests`, `compat_pure_tests`
exercising the lower-level loaders / primitives. Coverage could
grow (more fixtures per contract), but the harness itself is
complete and exercised on every `make canary` via `canary
artifact-test`. #15b can be considered closed.

## Final state (end of Phase 15.7)

**13 variants on `canary action tiny`, all passing:**

| Variant | Contract attributed | Mechanism |
|---|---|---|
| (baseline) | — | every step done |
| lib_broken | c1 OCaml + c1 Python | static comparator |
| binding_mli_broken | c2 OCaml | static comparator |
| binding_python_attrs_broken | c2 Python | static comparator |
| hybrid_lib_broken | c1 (both langs) | static comparator (cross-product) |
| lib_soname_bumped | c4 Python | static comparator |
| lib_behavior_broken | c3 (both langs) | probe runner |
| binding_overdeclares_stubs | c1 OCaml (orphan) | static comparator |
| app_helper_lib_broken | c1 (both langs) | static comparator (chain) |
| lib_symbol_version_broken | c5 Python | static comparator |
| binding_type_broken | c6 OCaml | static comparator |
| binding_repack_broken | c7 OCaml | probe runner (refutation) |
| binding_python_repack_broken | c7 Python | probe runner (refutation) |

Active Contracts: c1 (missing + orphan, both langs), c2 (both langs),
c3 (both langs), c4 (Python), c5 (Python), c6 (OCaml), c7 (both langs).
c8 dormant — no Contract for canary to maintain.

Tiny matrix is feature-complete relative to the surface theory's
active contracts. Forward-looking work continues in plan.md's Step 7,
Phase 16 (orthogonality refactor), Phase 17+ (real projects).
