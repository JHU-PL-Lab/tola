# Paper plan & working roadmap

Venue strategy, milestones, OOPSLA punch list, and the five-step
alignment roadmap. One doc; cross-referenced. Replaces the earlier
split `plan.md` + `roadmap.md` (2026-05-19).

Companion to [`surface_theory.md`](surface_theory.md) (theory) and
[`tiny.md`](tiny.md) (witness); see [`README.md`](README.md) for the
four-pillar map.

## Quick map

- **§1 Strategy** — venue priorities, what's non-negotiable.
- **§2 Target conferences** — deadlines and fallback timing.
- **§3 Milestones (M1–M4)** — what's true of the paper + tool by each
  deadline.
- **§4 OOPSLA punch list** — what reviewers will look for; the
  status-of-the-paper view.
- **§5 Optional venue gaps** — PLDI / POPL specifics if we target them.
- **§6 Working roadmap** — five-step alignment of theory / tiny /
  canary, with status checkboxes.
- **§7 Operating rules** — short.

## 1. Strategy

- **Primary venue: OOPSLA** — applied-PL framing, surface calculus
  + working multi-PM compatibility tool.
- **Optional stretch venues: PLDI, then POPL** — use their gaps as
  guidance, not as required scope. Current lean is PLDI over POPL
  (empirical/algorithmic story is closer to landing than the
  formal-calculus story).
- **Non-negotiable:** the tool stays practical and working. Theory
  grows from the implementation, not ahead of it.
- **Theory aspiration:** abstractions (surface roles, contracts,
  static/runtime refinement) should stand on their own, not as
  description of one prototype.

## 2. Target conferences

| Venue           | Edition   | Role     | Deadline (next round)                                    | Link                                                                                      |
| --------------- | --------- | -------- | -------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **OOPSLA 2027** | SPLASH'27 | **Main** | Round 1: ~**mid-Oct 2026** (TBA); Round 2: ~mid-Mar 2027 | [SPLASH series](https://www.sigplan.org/Conferences/SPLASH/)                              |
| PLDI 2027       | -         | Optional | Submission: ~**mid-Nov 2026** (TBA)                      | [PLDI series](https://pldi27.sigplan.org/)                                                |
| POPL 2027       | -         | Optional | Submission: **Thu 9 Jul 2026** (AoE); notification 5 Oct | [popl27 research papers](https://popl27.sigplan.org/track/POPL-2027-popl-research-papers) |

OOPSLA/PLDI 2027 dates are estimates based on prior years; replace
with official ones once each CFP is posted. POPL 2027 dates are
confirmed from the official CFP.

### 2.1 POPL 2027 full schedule

- Submission: **Thu 9 Jul 2026** (AoE)
- Author response: Mon 7 – Thu 10 Sep 2026
- **Author notification: Mon 5 Oct 2026**
- Revision deadline (conditional accepts): Mon 26 Oct 2026
- Final acceptance notification: Mon 9 Nov 2026
- Camera-ready: Fri 20 Nov 2026
- Conference: 10–16 Jan 2027, Mexico City

### 2.2 Fallback timing if POPL doesn't land

- POPL **rejects** on 5 Oct → free to redirect to PLDI 2027 (~mid-Nov).
  ~5 weeks for empirical/algorithmic rework. Tight but feasible.
- POPL **conditionally accepts** on 5 Oct → committed through 9 Nov;
  no parallel submission to PLDI possible.
- OOPSLA 2027 R1 is likely ~mid-Oct 2026 (TBA). If it lands within
  ~10 days of the POPL notification, that's not enough rewrite time —
  treat OOPSLA R1 as the *primary* track regardless and only fall
  back to OOPSLA R2 (~Mar 2027) if POPL conditional-accept work eats
  the R1 window.

## 3. Milestones

Each milestone is a deadline-driven checkpoint. Items pull from the
TODO list in CLAUDE.md (numbers are stable, never renumbered) and
the §4 punch list. Milestones are timeline-ordered; M1 is the
earliest deadline regardless of venue preference. Items are
cross-linked to §6 (working roadmap) where they correspond to a
specific step.

### M1 — POPL 2027 (9 Jul 2026) — **stretch, ~2 months**

Realistic only if we want to push the formal track. Drop if it
pulls effort away from M2.

- [ ] Define transformer calculus syntax + typing rules (extends
      `surface_theory.md` §6).
- [ ] Subtyping algorithm + decidability sketch.
- [ ] Soundness theorem statement; proof sketch acceptable.
- [ ] Type closed for at least one language (OCaml `.cmi` digest is
      the most tractable) — see §6 step 4 (c6 `cmp_type`).
- [ ] TODO #15b — unit-test harness for compat/inspect logic (lets
      us iterate on the calculus without full integration runs).

### M2 — OOPSLA 2027 Round 1 (~mid-Oct 2026) — **PRIMARY, ~5 months**

This is the one to plan around. Everything else is opportunistic.

Theory / writing:
- [ ] Full draft of `surface_theory.md` plus intro, related work,
      evaluation, and conclusion as a single OOPSLA submission.
- [ ] `surface_theory.md` §6 (typed calculus) formalised to "applied
      PL paper" level (not full POPL, but more than a sketch).
- [ ] Coverage / blame story (§2.7) lifted into a contribution, not
      just a status table.
- [ ] Related work section against linking calculi, manifest
      contracts, ABI tooling (see [`literature.md`](literature.md)).

Tool / empirical:
- [ ] At least 2 more libraries beyond Z3/LLVM/sqlite. PyTorch
      (queued) is the obvious next; pick one more from the Tier-1
      candidate queue.
- [ ] Comparator coverage closures — see §6 step 4 (c4 `cmp_abi`,
      c5 `cmp_sym_version` at minimum; c6 if time).
- [ ] TODO #18 — audit project specs for hardcoded shell commands.
- [ ] TODO #19 — LLVM cross-version C symbol check.
- [ ] TODO #40 — real `cmake --install` instead of fake `cp`.
- [ ] macOS local testing green (scope 2 of the macOS plan) — at
      least `canary artifact-test` on a Mac.
- [ ] TODO #15b — compat/inspect unit-test harness (also serves M1).

### M3 — PLDI 2027 (~mid-Nov 2026) — **stretch (preferred optional), ~6 months**

Use as fallback if OOPSLA R1 misses, or as a complementary
submission if the empirical story matures fast.

- [ ] Benchmark corpus: 30+ packages mined across apt/opam/pip
      with known breakages.
- [ ] Concrete static-inference algorithm with complexity statement.
- [ ] Baseline comparisons: `abigail`, `abi-compliance-checker`,
      opam `lint`.
- [ ] At least 3 real regressions caught that baselines miss.
- [ ] Performance numbers on the corpus.

### M4 — OOPSLA 2027 Round 2 (~mid-Mar 2027) — **backup, ~10 months**

If M2 misses, R2 is the safety net. Carry forward all M2 items;
expand empirical scope; incorporate R1 reviewer feedback if any.

## 4. OOPSLA punch list — status

Unified view of what has landed (`[x]`) and what's still open
(`[ ]`) for the OOPSLA submission. Open items are what a reviewer
will look for.

### Theory

- [x] Surface-contract model defined in
      [`surface_theory.md`](surface_theory.md) §2: per-side
      syntactic / semantic surfaces, six primitive contracts (Type,
      Symbol, ABI, API-repacking, API-completeness, Behavior),
      derived API-faithfulness. Language-side internal structure
      (stub-facing / repacking / compiled artifact); binding
      mechanism on a static-vs-dynamic axis.
- [x] §2.7 coverage view: inspectors keyed by artifact aliases
      (`n*` / `b<lang><mech?>*`), comparators `c1..c8`, status in
      canary core, link to tiny scenarios.
- [x] **Single source of truth** established (2026-05-19): theory,
      witness, plan in three aligned docs; entry point at
      [`README.md`](README.md); legacy `api_surface.md` retired.
- [x] **`tiny` example** — minimal C lib + 3 bindings (OCaml
      cstubs, Python cext, Python ctypes) + downstream `tiny_helper`
      lib + 12 scenarios (10 perturbations + 2 positive-coverage)
      all passing against the harness; both points of the §2.3
      static/dynamic axis instantiated; coverage matrix in
      [`tiny.md`](tiny.md).
- [x] **`prepare` + `confirm_ill` flow** (Phase 3, 2026-05-28).
      Each scenario's `violates` claim is now a machine-checkable
      assertion — `prepare` computes the surface delta vs cached
      baseline JSONs and writes it to
      `_cache/<name>/confirm_ill.json`. Phase 3b adds artifact +
      source snapshots for cached replay (`make scenarios-cached`,
      ~1.6× faster than `make scenarios` on tiny; scales with build
      cost on larger projects). See [`tiny.md`](tiny.md) "Phase 3a"
      and "Phase 3b" subsections.
- [ ] **Calculus story sharper.** `surface_theory.md` §6 is a
      sketch; make it a contribution — transformer signatures,
      surface subtyping, and the static/runtime refinement loop as
      the headline.
- [ ] **Coverage / blame story lifted.** §2.7 should land as a
      reusable framing (which contract a failure is blamed to),
      not just a status table.
- [ ] **Type contract at least convincingly framed.** Doesn't have
      to be fully checked, but must be more than "not checked." See
      §6 step 4 (c6).

### Implementation

- [x] `canary action {z3,llvm,sqlite}` end-to-end, both dev and
      stable variants, on Linux/WSL + GH CI.
- [x] Compat cross-check shipped: `canary compat`, `canary verify`,
      `Expect_compat_failure` derives predictions from cached
      summaries.
- [x] Live demos: llvm/19 OCaml `Opcode.UncondBr`, z3/stable Python
      `parser_context`.
- [x] Artifact summaries (native, mli, c_stub, ocaml, python) typed
      and serialised; `inspect-diff` available locally.
- [x] Two-axis test surface: project tests + framework tests
      (`artifact-test`, `pm-test`).
- [ ] **Empirical breadth.** Move from 3 libraries to 5–8 across
      PMs; at minimum land PyTorch (queued), pick one more from the
      Tier-1 candidate queue.
- [ ] **Comparator closures** — see §6 step 4 for the c4/c5/c6/c7/c8
      sequencing.

### Paper positioning

- [ ] **Related work.** Position against linking calculi
      (Cardelli's units, Flatt–Felleisen, MixML), manifest
      contracts, ABI compatibility tools (`abigail`,
      `abi-compliance-checker`), and SemVer literature. Notes in
      [`literature.md`](literature.md).
- [ ] **Full paper draft.** `surface_theory.md` + intro, related
      work, evaluation, and conclusion as a single OOPSLA
      submission.

## 5. Optional venue gaps

### PLDI (preferred optional)

1. Static-inference algorithm stated explicitly with complexity
   bounds.
2. SymbolVersion wired end-to-end on a real version-drift case
   (TODO #16b; corresponds to §6 step 4 / c5).
3. Benchmark suite: 30+ packages across apt/opam/pip with a
   quantified breakage corpus (mining study).
4. Baselines: comparison to `abigail`, `abi-compliance-checker`,
   opam `lint`, Debian symbols files.
5. Measured bug-finding power: real regressions caught that
   existing tools miss, with reproducers.
6. Performance numbers (inference time, false-positive rate vs.
   runtime canary).

### POPL (second optional)

1. Formal calculus: explicit syntax, typing judgments, reduction
   rules (extending `surface_theory.md` §6).
2. Algorithmic subtyping with decidability argument.
3. Soundness theorem with proof (subject reduction / progress
   flavour).
4. Type contract closed — currently the most interesting layer is
   "not checked", which is the first thing a POPL reviewer will
   flag.
5. (Optional but increasingly expected) Mechanization in Rocq / Lean.

## 6. Working roadmap — alignment of theory / tiny / canary

Five steps for keeping the theory, the witness, and the canary
implementation in lockstep. Step 4 carries the implementation work
that M2/M3 milestones depend on; the other steps are doc / harness
hygiene that unblock and verify the implementation work.

We do these steps **one at a time, with a discussion / clarification
pause between each**. Not aggressive.

Naming convention used in the docs and code (final scheme):

- **Theory-side indices**: `s1..s6` (surface roles), `c1..c8`
  (contracts / comparators), `e1..e13` (scenarios). Project-invariant.
- **Project-side artifact aliases**: `n*` native, `bo*` ocaml binding,
  `bpc*` python ctypes binding, `bpe*` python cext binding. Sequential
  per binding, file-keyed.
- **Canonical artifact names**: `<role>_<side>[_<lang>][_<mech>].<form>`
  (e.g. `lib_native.so`, `compiled_binding_ocaml.stub-a`,
  `user_binding_cext.py`). Pan-universal; the prose form in code.
- **Usage**: canonical names in OCaml code (self-documenting), IDs in
  tables / log lines / JSON keys / status displays (column-fits).
- **Formal `Σ_*` notation**: reserved for the paper.

See [`phase4_2026_05.md`](../worklog/phase4_2026_05.md) for the term-alignment tracker that
applies this scheme to canary's OCaml code.

### Step 1 — Establish unified terms  ✓ **DONE** (2026-05-15)

Goal: every doc and every code symbol references the same set of
surface roles, inspectors, comparators, and scenarios by the same
name. Pure doc + light code-rename work; no behaviour changes.

Glossary tables landed in `surface_theory.md` §2.1 (six surface
roles `s1..s6`), §2.4 (eight contracts / comparators `c1..c8`),
§2.7 (inspectors keyed by artifact alias), and `tiny.md` (twelve
scenarios `e1..e13`). The artifact alias scheme (`n*` native,
`b<lang><mech?>*` per-language binding) was introduced 2026-05-20 —
it replaces the per-inspector `i*` index that earlier turns used.

### Step 2 — Defer packaging cleanly  ✓ **DONE** (2026-05-19)

Per the latest direction: packaging stays *as a section inside*
`surface_theory.md` (now §3 "Packaging and co-providers"), not a
separate file. No `package_theory.md` needed unless that section
grows large.

- [x] Move §6/§7 from old structure into a single §3 in the
      tightened `surface_theory.md`.
- [x] `tiny` stays packaging-free — no apt / opam / pip variants
      modeled here.

### Step 3 — Compare theory, tiny, canary; plan shared utilities

Goal: use the precision of step 1's vocabulary to plan
implementation gaps *and* the shared tooling that both `canary
action` and tiny's harness should consume.

- [x] §2.7 inspector table indexed by artifact aliases (`n*` / `b<lang><mech?>*`); surfaces `s1..s6` are a column.
- [x] **§2.7 alignment table** — single canonical view joining
      contracts × tiny scenarios × inspectors needed × comparators
      × canary status across all four pillars. Replaces the separate
      comparator-coverage table and the contract→scenario lookup;
      now the load-bearing guide for steps 3 and 4.
- [ ] **Shared utilities.** Design a small Python package
      `canary_inspectors/` exposing every inspector as a CLI
      (preserves current behaviour) and an importable API. Both
      `canary action`'s OCaml runner and tiny's harness keep using
      the CLI; new tooling can import. Foundational for Step 3b.
- [ ] Decide naming for the new inspectors targeting `bo1` (OCaml
      `external` parse), `bpc1` (ctypes argtypes parse), `bpe1`
      (cext `PyMethodDef` parse), and `n3` (C header parse).
- [ ] Discuss scenario naming consistency
      (`api_faithful` / `api_complete` describe the *property*, not
      the *violation* — separate small pass).

### Step 3b — Unit-test layer for primitives (absorbs **#15b**)

Goal: a fast, fixture-driven test harness that exercises
comparators and inspectors against synthetic JSON inputs, so we can
iterate on primitives without paying the integration-test cost
(`canary action z3` is ~10s; full pipeline with opam installs is
minutes).

Today's testing coverage:

| layer                              | tool                                | covers                                                          |
| ---------------------------------- | ----------------------------------- | --------------------------------------------------------------- |
| Pure unit (data shape)             | `test/canary_artifact_test.ml` pure      | watchlist matchers, JSON parsing, compat helpers — 13/13        |
| Shell integration (primitive runs) | `test/canary_artifact_test.ml` shell     | `nm` / `ocamlobjinfo` / inspect_*.py on fixed fixtures — 15/15  |
| Per-PM                             | `canary_pm_test.ml`                 | apt/brew/opam/pip install + verify + remove lifecycle — 14/14   |
| Integration (heavy)                | `canary action <project>`           | full pipeline, ~10s–5min per project                            |

**Missing**: the layer between "primitive runs against a real fixture"
and "full project pipeline." Fixture-driven unit tests for each
comparator + inspector that take canned JSONs and assert
predicate outcomes.

- [x] **Seed fixtures + runner** (2026-05-29) — in-memory OCaml
      fixtures in `test/canary_artifact_test.ml`:
      - `cmp_symbol_pure_tests` (5 cases): Compatible / Missing one
        / Missing multiple / Unknown-empty-requires /
        Unknown-empty-symbols. Reciprocal coverage on c1.
      - `c2_prediction_pure_tests` (2 cases): JSONs whose
        `watchlist.missing` is `[]` produce no prediction strings —
        the positive complement to the existing
        `compat.mli_dotted_expansion` test.
      - artifact-test pure suite 13 → 20, total 28 → 35.
- [ ] **`canary_test/cmp_fixtures/`** — on-disk JSON fixture set
      (shareable with tiny's harness). Lands when the
      `canary_inspectors/` shared package does, so the Python and
      OCaml sides can read the same fixtures.
- [ ] **Reciprocal coverage** — extend the seed set as new
      comparators land: every c4..c8 ⇒ at least one positive
      fixture (accept) + one negative (reject).
- [ ] Once `canary_inspectors/` package exists (Step 3 shared
      utilities), share the fixture set as Python-importable test
      data so tiny's harness and canary core run the *same* test
      matrix.

Seed landed before Step 4 begins so every new primitive has
fast-feedback test coverage from the moment it's written.

### Step 4 — Comparator and inspector buildout (principled shape)

Steps 1–3 (and Phase 4 inside step 3) were **vocabulary** work —
unify terms, align docs and code, build the tiny witness so
canary spec matches the standalone harness. Step 4 is the
**substance** work: close the static-check gaps the tiny scenarios
reveal.

Two threads, interleaved:

**(a) Implement what's missing.** c4..c8 don't exist; n3 / bo1 /
bpc1 / bpe1 inspectors don't exist. The tiny scenarios show what
each ought to detect — e.g. e6 api_complete needs bo4 mli inspector
+ c2 (both wired today); e3 type_wrong needs n3 + bo1 inspectors +
c6 cmp_type (all missing). For each gap row in `surface_theory.md`
§2.4's contract status table, build the inspector(s) and
comparator that closes it.

**(b) Retrofit to the principled shape.** Tiny's comparators
(`_harness/comparators/cmp_*.py`) are standalone CLI scripts: take
two JSONs, return a verdict. Canary's existing comparators are
{i embedded} — `check_c_compat` lives inside `surface/canary_compat.ml` and
runs as part of the action graph; the c2 watchlist check is
buried inside the `Expect_compat_failure` step expectation runner.
That's pragmatic but not principled — it conflates "comparator
logic" with "where canary invokes it." Step 4's new comparators
should follow tiny's standalone-script pattern (the [Step 3]
"shared utilities `canary_inspectors/` Python package" item) and
the existing c1/c2/c3 can be retrofit when convenient.

Order: comparator-only gaps first (JSONs exist; just need the
diff logic), then inspector-and-comparator gaps. Each item is a
row in the M2 / M3 milestones above.

**Comparator-only gaps:**

- [x] **c4 `cmp_abi`** (2026-05-29, commit `2426099`). Function
      `check_abi ~provider_soname ~consumer_needed` in
      `surface/canary_compat.ml`; dedicated `abi_result` type
      (`Abi_compatible` / `Abi_mismatch` / `Abi_unknown`). 5 unit
      tests in `cmp_abi_pure_tests` covering the e2-shape negative
      case plus Unknown branches. Wiring into the action pipeline
      (Expect_compat_failure prediction / per-step verdict) is a
      follow-up.
- [x] **c5 `cmp_sym_version`** (2026-05-29). Function
      `check_sym_version ~provider_versioned_exports
      ~consumer_required_versions` in `surface/canary_compat.ml`; dedicated
      `sym_version_result` type. 6 unit tests in
      `cmp_sym_version_pure_tests` covering exact-match,
      subset-match, glibc/musl version-drift, missing-multiple, and
      both Unknown branches. Today's check is exact-match on the
      version tag string; floor-comparison is a future refinement.
      Wiring into the action pipeline is a follow-up.

**Inspector-and-comparator gaps:**

- [x] **Inspector for `bo1`** (2026-05-29). `^external` parse added
      to `inspect_binding.py`; emits a new `externals` field
      alongside `vals` so a single `--kind mli` run on either a
      stub-facing `.mli` ({i bo1}) or user-facing `.mli` ({i bo4})
      cleanly separates the two surfaces. Watchlist resolves against
      both. 3 fixture-driven OCaml tests (`bo1_external_inspect_pure_tests`)
      assert the externals-vs-vals split on stub-only, user-only, and
      mixed `.mli` inputs. Unblocks {i s3 stub-facing} for OCaml; c7
      cmp_api_repack can now compare `bo1.externals` ↔ `bo4.vals`.
- [x] **Inspector for `n3`** (2026-05-29). New
      `canary/scripts/inspect_header.py` — regex-based C header
      parser. Emits `{kind: c_header, functions: [{name, return_type,
      arg_types}], extern_vars: [{name, type}]}`. Scoped to tiny.h-
      shape headers (flat, no preprocessor macros / typedefs).
      Real-world z3.h / llvm-c/*.h need libclang or tree-sitter —
      followup. 4 fixture-driven OCaml tests
      (`n3_header_inspect_pure_tests`) cover tiny-like, 3-arg
      bumped, void-args.
- [x] **`bo1` enhanced** (2026-05-29). `inspect_binding.py --kind
      mli` now emits an additional `externals_detail` field per
      external: `{name, sig, c_symbol, arity}`. Arity is the number
      of OCaml argument positions (count of `->` in the signature).
      Backward-compatible: existing `externals` array unchanged.
- [x] **c6 `cmp_type` (OCaml first)** (2026-05-29). Function
      `check_type ~header_functions ~binding_externals ~name_mapping`
      in `surface/canary_compat.ml`; dedicated `type_result` type
      (`Type_compatible` / `Type_arity_mismatch` / `Type_unmapped`
      / `Type_unknown`). MVP is arity-only after applying a
      project-declared name mapping (binding externals → header
      function names; e.g. tiny passes
      `[("sum", "tiny_sum"); ("diff", "tiny_diff")]`,
      excluding `get_offset` which maps to an extern var).
      Full C ↔ OCaml type-equivalence comparison is a later
      refinement. 7 unit tests in `cmp_type_pure_tests`.

      **Note on the regression scenario**: my earlier plan claim
      "tiny's e3 type_wrong scenario flips ✗ → ✓ when this lands"
      was wrong. e3 patches `c/src/tiny.c` (body); the header and
      external signatures stay aligned. c6 sees no drift; e3 is
      c3 Behavior's territory. A future tiny scenario `e15
      cmp_type_header_drift` would patch tiny.h to bump tiny_sum
      to 3 args while the binding stays at 2 — the regression
      shape c6 actually catches. Deferred (analogous to c4/c5
      having unit-test-only coverage today, no live tiny
      scenario).
- [ ] **Inspectors for `bpc1`** (ctypes argtypes parse) and
      **`bpe1`** (cext `PyMethodDef` parse). Python AST parse for
      ctypes; C parse for cext.
- [x] **c7 `cmp_api_repack` (OCaml first)** (2026-05-29). Function
      `check_api_repack ~stub_externals ~user_vals ~renames` in
      `surface/canary_compat.ml`; dedicated `repack_result` type
      (`Repack_compatible` / `Repack_stub_orphan` /
      `Repack_user_phantom` / `Repack_unknown`). Renames are
      explicit (project specs declare allowed (external, val)
      pairs); empty list for default strict match. 6 unit tests in
      `cmp_api_repack_pure_tests` covering exact-match,
      compatible-with-rename (tiny's `get_offset → offset`),
      stub_orphan with and without renames, user_phantom, and
      unknown. **Regression scenario**: new tiny scenario
      **e14 `api_repack_stub_orphan`** — patch adds
      `external alias_sum` to Tiny_raw.mli (with matching C wrapper)
      but Tiny.mli doesn't surface it. Today's standard harness
      records it as all-pass because c7 isn't wired into
      `run.sh`; the unit-test layer covers the verdict shape.
      **Note**: my earlier plan incorrectly named e5 as the c7
      regression test. e5 patches `.ml` (implementation, swaps
      diff args); .mli signatures unchanged → c7 sees no drift.
      e5 is c3 Behavior's territory, not c7's.

**Derived (free once c1/c6/c7 exist):**

- [x] **c8 `cmp_api_faithfulness`** (2026-05-29). Function
      `check_api_faithfulness ~type_verdict ~symbol_verdict
      ~repack_verdict` in `surface/canary_compat.ml`; dedicated
      `faithfulness_result` type (`Faithful` / `Unfaithful` /
      `Faithfulness_unknown`). Pure composition of the three
      constituent verdicts; `Unfaithful` carries optional per-
      constituent issues so callers can attribute blame.
      7 unit tests in `cmp_api_faithfulness_pure_tests`
      covering all-compatible, each constituent's drift in
      isolation, multiple-issue, all-unknown, and partial-unknown
      (which is still Faithful). When wired into the action
      pipeline alongside c1/c6/c7, e4 api_faithful flips ✗ → ✓
      (today silent at the c1/c2/c3 level).

**Project-spec command decoupling — thread (b) cleanup (absorbs **#18, #25, #26, #40**):**

The z3 / llvm specs have ~40-line `Printf.sprintf` blocks for
cmake / dune / ninja invocations. Each new comparator that lands
auto-fires for these projects via `api_source` (no spec edit
needed), but the build / configure / install commands they wrap
remain inline shell. Peeling these into reusable primitives is
the (b) thread's project-side work.

- [ ] **`Canary_toolchain` cmake/dune/ninja primitives**
      (absorbs **#18**) — extract:
      - `cmake_configure_cmd ~src ~build ~flags ~marker`
      - `cmake_build_cmd ~build ~target ~marker`
      - `ninja_build_cmd ~build ~target ~marker`
      - `dune_build_cmd ~target ~env_extra ~marker`
      - `mark_step_complete ~output_dir ~marker` helper (replaces
        every command's trailing `&& echo 'ok' > ...`).
      Touches z3 / llvm specs uniformly. Each spec file shrinks
      ~40 lines.
- [ ] **Real `cmake --install`** (absorbs **#25, #40**) —
      z3 / llvm `install_lib` scripts currently `cp` files (fake
      install). Replace with `cmake --install --prefix $PREFIX` so
      canary exercises cmake's install-time transformations: RPATH
      rewriting, versioned symlink creation, pkg-config / FindPackage
      config file generation. The `Probe Lib Staged` step then
      tests an actually-installed artifact rather than a hand-copied
      one. See `doc/canary/ops/install_targets.md` for z3 vs LLVM
      patterns.
- [ ] **z3 cmake build_z3_ocaml_bindings PHONY guard** (absorbs
      **#26**) — `add_custom_target` always reruns; gate with
      `test -f z3ml.cmxa || ninja ...` so re-running canary
      doesn't trigger a full z3 rebuild on cache rebuild.

**Live demos to strengthen (absorbs **#19**):**

- [ ] **LLVM cross-version C-symbol check** — `llvm/19` probe today
      demonstrates OCaml API mismatch (`Opcode.UncondBr` compile
      error via c2 watchlist). After c1 cmp_symbol cross-compare
      wires up, *also* surface as a C-symbol-set mismatch between
      libLLVM-dev's exports and libLLVM-19's exports. Belt-and-
      suspenders for the same drift case. Requires no new
      inspectors; just an Expect_compat_failure with a Native_lib
      cross-check input.

**Milestone (closed):**

- [x] **`canary_project_tiny.ml`** (2026-05-28 / expanded 2026-05-29):
      `canary action tiny` runs the full 12-step pipeline (6 main +
      6 inspect) using the aligned vocabulary. JSON shapes
      byte-equivalent to `make scenarios-cached`. Phase 4 milestone
      check passed — see [`phase4_2026_05.md`](../worklog/phase4_2026_05.md).

**Sequencing note**: comparator-only gaps (c4, c5) first — they have
the lowest cost and fastest feedback. Inspector-and-comparator
gaps (n3 + bo1 → c6 → c7 → c8) second. Project-spec command
decoupling can run in parallel as it touches different files.
Step 3b's unit-test fixtures should land before any comparator
work begins (or in lockstep with the first one) so iterations are
fast.

### Step 4b — Phase 4: canary code-side term alignment

Tracked in detail in [`phase4_2026_05.md`](../worklog/phase4_2026_05.md). Brief: canary OCaml
code currently uses a pre-Phase-2 vocabulary (`artifact_kind`,
`binding_summary`, language-flavoured ad-hoc names). Phase 4
aligns it to the unified scheme (canonical names + `n*`/`b*`
aliases) so the docs, tiny, and canary speak the same language.
No semantics change; mostly comments, renames, and a small typed
mapping. Milestone check: `canary_project_tiny.ml` + `canary
action tiny` runs every scenario through the production pipeline.

### Step 5 — Update docs after each implementation milestone

Standard "tests green, docs follow" pass. Cumulative.

- [ ] After each c\* lands: flip the corresponding ✓/✗ in §2.7
      comparator table; update tiny scenario expected outcomes if
      the scenario's outcomes change.
- [ ] After c8 lands: tiny's `e4 api_faithful` scenario flips one
      outcome to `fail`; it becomes the regression test for the
      newly-detected violation.
- [x] Retire `api_surface.md`. Implementation pointers folded into
      `surface_theory.md` §2.7; glibc/musl case into §4.2; packaging
      kept as §3 of the same doc.
- [x] Phase 3 (2026-05-28): tiny harness extended with prepare /
      confirm_ill (3a) and cached restore-driven runs (3b).
      `tiny.md` Phase-3a / Phase-3b subsections document the new
      flow; Makefile + scenarios.py expose the commands.

### Step 6 — Lift contracts to a per-contract registry (2026-06-02)

**Motivation.** Today's `predicted_contains_any_v2` in
`surface/canary_compat_run.ml` is already structured as four
implicit "layers" (L0, L1b, L3, L4), each implementing one
contract:

| Layer | Contract | Status |
|---|---|---|
| L0 | c1 cmp_symbol | ✓ wired |
| L1b | c5 cmp_sym_version | ⚠ JSON read but no diff |
| L3 | c2 cmp_api_completeness | ✓ wired |
| L4 | c4 cmp_abi | 🗑 stub returns `[]` |

The mapping is correct (every existing check IS a c\* row) but
implicit. New comparators get added by editing one growing function
with inline `match`-on-input dispatch, the §2.4 status table can
silently drift from the code, and there's no way to disable a
single contract without code changes.

**Refactor (no new features).** Make each contract a registered
record:

```ocaml
type contract_id = C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8
type contract_status =
  | Wired | Inspect_only | Comparator_only
  | Blocked of contract_id list | Stubbed

type contract_check = {
  id       : contract_id;
  name     : string;          (* "cmp_symbol", … *)
  layer    : string;          (* "L0", "L1b", "L3", "L4" *)
  status   : contract_status;
  enabled  : bool;
  predict  : resolve:(string -> string) -> inspect_input list -> string list;
}

let registered_checks : contract_check list = [
  { id = C1; status = Wired;        enabled = true;  predict = c1_predict };
  { id = C2; status = Wired;        enabled = true;  predict = c2_predict };
  { id = C4; status = Stubbed;      enabled = false; predict = c4_stub    };
  { id = C5; status = Inspect_only; enabled = true;  predict = c5_predict };
  { id = C6; status = Blocked [];    enabled = false; predict = c6_stub    };
  { id = C7; status = Blocked [C6];  enabled = false; predict = c7_stub    };
  { id = C8; status = Blocked [C6;C7]; enabled = false; predict = c8_stub  };
]
```

`predicted_contains_any_v2` becomes a 4-line iterator over the
registry. The L0/L1b/L3/L4 sections of today's function each
become one `c?_predict` closure.

**What this gives us:**

1. **§2.4 becomes derivable.** The status table prints from
   the registry; the doc table is regenerated from code rather
   than maintained by hand.
2. **Per-project / per-CLI toggles.** A project spec can
   override `enabled` per contract (e.g. disable c5 for projects
   where versioned-symbol noise is intractable). A CLI flag can
   disable a contract globally for triaging.
3. **Adding a new c\* becomes data.** One new registry entry +
   one predict closure. The runner doesn't need editing.
4. **Honest blocked declarations.** `Blocked [C6]` self-documents
   that c8 can't run until c6 lands.

**No behavior change.** Byte-for-byte identical output today;
every regression stays green; the matrix of inputs/outputs is
unchanged. Pure lifting.

**Tracked as Phase 12 in the refactor sequence**
(`doc/canary/audit_post_refactor_2026_06_01.md`).

### Step 6b — Per-project / per-CLI contract toggles ✓ **DONE** (2026-06-02)

Once the registry exists, the two consumer paths landed as Phase 13:

- ✓ `script_spec.disabled_contracts : Canary_compat.contract_id list`
  — projects opt out of specific contracts. Default `[]`. Threaded
  through `mk_step` so every `action_step.disabled_contracts` carries
  the project's list.
- ✓ `--disable-contract c5,c4` CLI flag on `canary action`. Parsed
  by `Canary_compat.contract_ids_of_csv`; layered on top of each
  project's per-spec list. Logs `[disable-contract] skipping: c5, c4`
  on activation.

`predicted_contains_any_v2 ?disabled` consumes both, skipping any
contract whose id appears in the per-call disabled list. Backwards-
compatible — the parameter is optional and defaults to `[]`.

### Step 6c — Surface-aware actions.log (deferred — after features land)

The runtime log line emitted by `Canary_local_runner.run_step` for
`Expect_compat_failure` collapses all contracts into one count:

```
[…] probe_binding_ocaml      compat_predicted  (3 substring(s))
```

It doesn't say which c\* fired or how many substrings each one
contributed. After the registry exists, the same predicted list is
trivially attributable per-contract — we can produce:

```
[…] probe_binding_ocaml      c1 cmp_symbol             (3 symbols)
[…] probe_binding_ocaml      c2 cmp_api_completeness   (1 module variant)
[…] probe_binding_ocaml      c5 cmp_sym_version        (skipped: Stubbed)
```

Concretely:
- Expose a `predicted_contains_any_v2_detailed` (or similar) that
  returns `(contract_id * string list) list` instead of a flat
  string list.
- Have `run_step` log one event per contract row.
- Add `contract_skipped` events when a contract is filtered out
  (registry `enabled = false`, in `Stubbed` / `Blocked`, or in the
  `disabled` list).

Deferred to after Step 7 (perturbation fixtures) — the surface-aware
log becomes most useful when there's a populated matrix of which
contracts fire on which projects. Tracked here so it doesn't get
lost.

### Step 7 — Matrix coverage on real projects via store-provided artifacts

**Motivation.** Tiny's full matrix coverage (12 scenarios × every
implemented c\*) is the witness that canary's machinery is sound.
Real projects (llvm, z3, sqlite) currently demonstrate ONE
perturbation each — natural version-mismatch flavour
(`Opcode.UncondBr`, `parser_context`). That's a thin demo: it
shows the machinery WORKS but not that it COVERS.

**Design principle (revised 2026-06-02): perturbations are artifacts,
not a separate concept.** Earlier this section proposed a
`canary/perturbations/` directory and a `--perturbation` flag.
Replacing that with a cleaner framing:

- **The canary action knows nothing about scenarios or
  perturbations.** It only sees artifacts at locations a store
  provides. (Today the store types are `Build_tree`, `Staged`,
  `Pm { … }`; a local-path store variant for "artifact at this
  filesystem path" is a natural extension.)
- **An external harness prepares each perturbed artifact** at some
  location — tiny's `scenarios.py` is the prototype. The harness
  knows scenarios; canary runs its checks on whatever the harness
  provides.
- **Each scenario becomes a project variant.** Tiny becomes
  multi-variant (`tiny/baseline`, `tiny/e1`, `tiny/e6`, …). The
  variant's `script_spec` declares the expected outcome
  (`Expect_compat_failure { inputs = …; … }` for scenarios that
  should fire c\*; `Expect_success` for the baseline). Running
  `canary action tiny/e1` invokes the existing variant-routing
  infrastructure — no new flag needed.
- **Result matches the standalone tiny harness.** For every
  scenario the harness defines, running the corresponding canary
  variant should fire the same contract(s) the standalone
  comparator does. Drift between the two implementations is the
  bug signal.

**It's OK if canary can't catch some scenarios today.** Some
scenarios may need infrastructure canary doesn't yet have — e.g. a
"fake / local-path store" type, per-artifact overrides, or
inspectors for an unimplemented `n*` / `b*` artifact alias. Each
gap is a TODO item with a clear shape. Start with what works; close
gaps as we go.

**Variant naming — canary vocabulary, not scenario vocabulary.**
canary's tiny spec stays ignorant of harness scenarios. Each variant
is a named `script_spec` value whose name describes **what canary
expects to fire**, not **what the harness did to produce the
artifact**:

```ocaml
(* canary_project_tiny.ml *)

let base_script_spec = { ... ; expectation = (fun _ _ -> Expect_success) }

(* "At probe_binding_ocaml, expect c1 cmp_symbol to fire." *)
let lib_broken_script_spec = { base_script_spec with
  expectation = fun rule _ -> match rule with
    | Probe (Binding OCaml) ->
        Expect_compat_failure { inputs = [ C_stub …; Native_lib … ]; … }
    | _ -> Expect_success
}

(* "At probe_binding_ocaml, expect c2 cmp_api_completeness to fire." *)
let binding_mli_broken_script_spec = { base_script_spec with
  expectation = fun rule _ -> match rule with
    | Probe (Binding OCaml) ->
        Expect_compat_failure { inputs = [ Ocaml_mli … ]; … }
    | _ -> Expect_success
}

let script_spec = base_script_spec  (* convenience binding *)
```

No scenario enum. The variant `lib_broken` doesn't know it
corresponds to harness scenario `e1 symbol_missing`. The
harness↔canary mapping table lives in tiny.md (or a wrapper
script), not in canary's spec.

**CLI routing — default runs the matrix; selective routing for
debug.**
- `canary action tiny` (no suffix) → runs every implemented variant
  via `run_project_multi` (parallel to today's `canary action z3`
  running dev + stable). After 14a: baseline + lib_broken. As more
  variants land, the set grows.
- `canary action tiny/<variant>` → runs only that variant.
  Permanently useful for development and debug (fast feedback on
  one specific contract's pipeline) but not the default user path.

**Order of attack — Phase 14 sub-steps:**

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

**14a follow-up — c2 OCaml (binding_mli_broken) shipped.** Maps
canary against harness scenario e6 (`api_complete` removes `val sum`
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
   produces `inspect.json` (stub side, c1) {b and} `inspect_mli.json`
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

**14b (coexistence — shipped 2026-06-02).**
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

**14b' (per-artifact-kind stores — shipped 2026-06-02).**
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

**14c (cross-products and broader scenario coverage — shipped
2026-06-02).** Two pieces landed together:

- `binding_python_attrs_broken_script_spec`: c2
  cmp_api_completeness on the Python side. Maps to harness scenario
  [e11 api_complete_python] (drops `sum` from
  `python_cext/tiny_cext/__init__.py`). Probe (Binding Python)
  imports tiny_cext, calls `tiny_cext.sum`, raises AttributeError.
  c2's Python_attrs input cites `build_binding_python/
  inspect_attrs.json`, produced by Build (Binding Python)'s now
  {b two-file} inspect (cext native symbols + dir(tiny_cext) attrs).
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

**Phase 14d (honest c1 Python — shipped 2026-06-02).** The
`lib_broken` and `hybrid_lib_broken` Python expectations dropped the
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

Beyond two stores: e2 abi_change × e6 api_complete combinations
(different perturbations on different artifact kinds) are still
parked — the cross-product door is wide open now, but the
interesting compositions aren't paper-critical until c4/c7/c8 wire
up.

**Phase 14e (c4 cmp_abi — shipped 2026-06-02).** Wires c4 end-to-end
against harness scenario `abi_soname_bump` (libtiny.so.1 → libtiny.so.2
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

| Variant | OCaml probe | Python probe |
|---|---|---|
| baseline | done | done |
| lib_broken | c1 (1× tiny_sum) | c1 (1× tiny_sum) |
| binding_mli_broken | c2 (2× Tiny.sum) | done |
| binding_python_attrs_broken | done | c2 (1× sum) |
| hybrid_lib_broken | c1 (1× tiny_sum) | c1 (1× tiny_sum) |
| lib_soname_bumped | done | **c4 (1× libtiny.so.1)** |

Contracts honestly firing: c1 OCaml, c1 Python, c2 OCaml, c2 Python,
**c4 (Python)**. Next on the docket: c3 cmp_behavior.

**Phase 14f (c3 cmp_behavior — shipped 2026-06-02).** Adds
`lib_behavior_broken` variant mapping to harness scenario
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
{b predict} side being a no-op, which is accurate. Coverage is via
the probe runner, documented in the registry comment.

Smoke (`canary action tiny`): both OCaml and Python probes for
lib_behavior_broken `cmd_fail (exit 1)` → `done (expected failure
confirmed)`. probe.log contains literally
`FAIL Tiny.sum 2 3: expected 47, got -43` (and analogous Python),
exactly the perturbation's math (2 - 3 - 42 = -43).

Contracts honestly firing across the seven-variant matrix: c1
OCaml, c1 Python, c2 OCaml, c2 Python, c3 (both), c4 Python. The
remaining surface-theory contracts (c5 sym_version, c6 type, c7
api_repack, c8 api_faithfulness) are still parked per their
registry status — each needs more inspector work or a paired
deferred scenario.

Possible future restructure: turning the `C1..C8` contract IDs from
enum cases into richer index objects with metadata (layer, status,
applicable surfaces, dynamic-vs-static, predict closure). The
`contract_check` record already carries most of this; the IDs
themselves could move to values. Worth its own pass when revisiting
the registry.

**Phase 14g (c1 orphan direction — shipped 2026-06-03).** Adds
`binding_overdeclares_stubs` variant mapping to harness scenario
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

Tiny variant matrix (eight):

| Variant | Scenario | Fires |
|---|---|---|
| baseline | — | — |
| lib_broken | symbol_missing | c1 OCaml + c1 Python |
| binding_mli_broken | api_complete | c2 OCaml |
| binding_python_attrs_broken | api_complete_python | c2 Python |
| hybrid_lib_broken | (cross-product) | c1 OCaml + c1 Python |
| lib_soname_bumped | abi_soname_bump | c4 Python |
| lib_behavior_broken | behavior_silent | c3 OCaml + c3 Python |
| binding_overdeclares_stubs | symbol_orphan | c1 OCaml (orphan) |

Honest contracts firing: c1 OCaml (both directions), c1 Python,
c2 OCaml, c2 Python, c3 (both), c4 Python.

Remaining harness scenarios not yet wired into canary tiny:
- `api_repack` / `api_repack_python` (e5/e10) → c7 — blocked on
  typed binding inspectors (bo1/bpc1/bpe1).
- `api_repack_stub_orphan` — variant of repack.
- `type_wrong` (e3) → c6 — blocked on typed header inspector (n3).
- `api_faithful` (e4) → c8 — blocked on c6+c7.
- `app_over_binding_ocaml` / `app_over_helper_ocaml` — app-chain
  coverage; no new contract, just an extra layer.

Not in harness yet:
- `e9 symbol_version_floor` → c5 — would need `.symver` annotations
  on tiny + new harness scenario. Could be added before pivoting to
  real projects.

**Phase 15 — finish the tiny contract matrix via hardcoded
inspectors (planned 2026-06-03).** Goal: get c5/c6/c7/c8 wired and
firing on tiny *without* committing to the heavy clang-AST inspector
work first. The contract logic (comparators in `canary_compat.ml`)
already exists or is minor; what's missing is just the inspector
JSONs feeding them. Since canary's comparators consume JSON without
caring how it was produced, we can ship checked-in *constant
inspector* JSONs per scenario for the contracts that need typed
data, demo the contracts end-to-end, and defer the real (clang-AST,
mli-AST, ctypes-introspection) inspectors until they're motivated by
a real project.

This isn't a contract shortcut — the comparator runs the same set-
diff / type-match logic regardless of where the JSON came from.
What's "synthetic" is the inspector plumbing; the contract
semantics are unchanged.

Order of work:

1. **Doc + plan refresh.** Rewrite
   [design/harness_canary_orthogonality.md](../design/harness_canary_orthogonality.md)
   to lead with the store/runner/producer orthogonal framing.
   Update plan.md (this file) with the Phase-15 sequence.
2. **`app_over_*` variants.** Validates that the model propagates
   through the tiny_helper chain. ~1 commit per variant (or one
   covering both). No new contract; exercises an extra layer.
3. **Hardcoded-inspector infrastructure.** One generic mechanism
   in tiny's spec: per-scenario constant JSONs live under
   `canary/examples/tiny/scenarios/constants/<scenario>/<artifact>.json`,
   and the harness's workspace materializer copies them into the
   workspace's inspect-output locations so canary's spec can
   reference them via the existing `inspect_input` ADT
   (`Versioned_symbols`, a new `Typed_header` / `Typed_stub` /
   `Typed_binding`, etc.). The hardcoded JSONs replace what a real
   `inspect_*.py` (clang-AST, ctypes-aware) would have produced.
4. **c5 cmp_sym_version wired.** Real comparator
   (`check_sym_version`) already exists; predicate currently
   inspect-only. Implement `c5_predict` to diff consumer
   `versioned_req` against provider `versioned_exports`. Add new
   harness scenario `symbol_version_floor` with constant
   `versioned_*` JSONs. Tiny variant
   `lib_symbol_version_broken_script_spec`.
5. **c6 cmp_type wired.** Implement `c6_predict` over a new
   `Typed_header` / `Typed_stub` input pair. Constants encode the
   `tiny_sum / tiny_diff / tiny_offset` signatures for baseline +
   `type_wrong` (`tiny_sum: (double, double) -> int`). Tiny variant
   `lib_type_wrong_script_spec`.
6. **c7 cmp_api_repack wired.** Implement `c7_predict` over
   `Typed_binding` inputs (binding's user-facing types vs binding's
   stub-facing types). Constants encode repack relationships.
   Variants `binding_repack_broken_script_spec` (OCaml) and
   Python counterpart, mapping to harness `api_repack` /
   `api_repack_python`.
7. **c8 cmp_api_faithfulness wired.** Derived from c6 + c7 outputs;
   no new inspector. Variant `binding_unfaithful_script_spec` to
   harness `api_faithful`.
8. **Full matrix complete.** All eight surface-theory contracts
   demoed honestly on tiny. Hand off to the unique-harness pass
   (Phase 16) then real projects (Phase 17+).

What this defers and why:

- **Real (clang-AST) inspectors.** Hardcoded JSONs are tiny-specific
  by design. Long-term we'd replace them with general inspectors
  using libclang, ocaml's compiler-libs (for mli parsing), and Python
  introspection. That work is ~2-3 days for n3 + bo1 alone, paper-
  worthy as engineering but not paper-blocking.
- **Real symbol versioning** (`.symver` / version scripts on tiny's
  build). Same story — c5 fires honestly on glibc-linked code in
  the real world; tiny just gets to test the comparator without
  adopting the linker mechanism.

**Phase 16 — unique-harness refactor (sketched).** Once Phase 15
lands, lift workspace fixups (`patchelf --remove-rpath`,
`libtiny.so` symlink synthesis) out of `scenarios.py` into a
canary-owned store sanitiser. Parameterize `scenarios.py`'s output
destination so synthetic and natural producers look the same to
canary. See
[design/harness_canary_orthogonality.md](../design/harness_canary_orthogonality.md)
for the full sketch.

**Phase 17+ — real projects** (llvm, z3, sqlite). Apply the
Phase-14/15 spec + matrix model to natural divergences from real
package managers. No synthetic perturbations needed; the producers
are opam / pip / apt. c5 demos for free against glibc-linked code.
Typed inspectors (c6/c7/c8) graduate from constant JSONs to real
implementations when motivated by a real divergence the team wants
to catch.

**Phase 15.6 — c7 reframed as api_sound_repack, c8 disabled
(shipped 2026-06-03).** Earlier framing treated c7 / c8 as static
comparators awaiting clang-AST-class inspectors. The cleaner
position lands here:

- **Contract vs comparator/check.** A Contract is the theoretical
  agreement at a surface boundary. A check is one possible
  implementation. The same Contract can be checked by multiple
  mechanisms (static comparator, runtime probe, binding-side test,
  compile failure). Folding c7's runtime symptoms into c3's
  comparator banner conflates the two.

- **c7 renamed [api_sound_repack].** The Contract is "the binding's
  user-facing layer is a sound repacking of its stub-facing layer."
  The check shape (probe-assertion refutation) is identical to c3's,
  but the Contract differs: c3 attributes failure to the native
  lib's behavior; c7 attributes to the binding's repack. Variant
  declarations (which surface was perturbed) determine attribution —
  canary doesn't disambiguate at the detection layer. Dropped the
  `cmp_` prefix since the Contract isn't comparator-implemented.

- **c8 disabled (candidate for removal).** No Contract for canary
  to maintain. Each binding is independent; cross-binding
  consistency isn't a canary-side agreement to check. Probes happen
  to assert the same constants across languages by project
  convention, not by a Contract canary enforces.

- **New tiny variant `binding_repack_broken`** maps to harness
  scenario `api_repack` (e5: `Tiny.diff a b = Tiny_raw.diff b a` —
  silent argument reversal). `Expect_failure { contains_any =
  ["FAIL "] }` at Probe (Binding OCaml). Python side unaffected
  (api_repack perturbs only ocaml/tiny.ml).

End-to-end smoke (`canary action tiny`):
- probe_binding_ocaml cmd_fail (exit 1).
- probe.log: `FAIL Tiny.diff 5 2: expected 3, got -3`.
- done (expected failure confirmed).

Twelve variants now ride `canary action tiny`. Contracts honestly
firing (with attribution): c1 OCaml (missing + orphan), c1 Python,
c2 OCaml, c2 Python, c3 (both), c4 Python, c5 Python, c6 OCaml,
c7 OCaml. c8 dormant.

**14c-deferred (further cross-products).**
- The coexistence model naturally permits "e1 lib + e6 binding"
  combinations canary's machinery would handle even though the
  standalone harness doesn't model them. Whether to enumerate
  crosses is a later decision; the *infrastructure* supports it
  because each store holds every variant.
- Probably not paper-critical. Park.

**14d+ (real projects).** Apply the same model to llvm / z3 /
sqlite. These have natural perturbations (version-mismatch builds)
instead of patched fakes, so the "store" providing the perturbed
artifact is just a different opam / pip / apt version.

**Justification for the paper.** Tiny becomes a fully-populated
project × contract matrix run by canary, byte-equivalent to the
standalone harness. The story shifts from "canary catches version
drift in two real projects" to "canary's surface-check coverage is
complete on every project we test, with both tiny (controlled) and
llvm/z3/sqlite (production-shaped) inputs hitting every implemented
c\*."

**Per-project pre-existing demos** (kept here as reference for when
the work moves to real projects after tiny):

| Project | Easy wins (c\* and natural perturbation source) |
|---|---|
| llvm | c1 + c2 OCaml already wired (Opcode.UncondBr); add Python (llvmlite version-floor); investigate c4 (LLVM SONAME bumps across majors); investigate c5 (libLLVM.so versioned symbols). |
| z3 | c2 Python already wired (parser_context); re-enable `has_build_binding=true` on z3-stable to add c1 (parallel to llvm); investigate c4. |
| sqlite | Most plumbed but no live demo. apt's `libsqlite3.so.0` vs Homebrew's `libsqlite.so.0` SONAME may differ — natural c4 candidate. |

## 7. Operating rules

- Every code change should also move the paper forward, or vice
  versa. Theory-only refactors that don't land in code, and feature
  work that doesn't simplify or strengthen the surface model, are
  deferred.
- Keep the tool runnable end-to-end on every milestone. A green
  `canary action {z3,llvm,sqlite}` + `canary artifact-test` is the
  baseline check before any paper-side claim.
- Update this doc when deadlines firm up or scope changes. Don't
  silently re-plan — write it down here.
- One roadmap step at a time. After each, pause and discuss before
  committing the next.
- Friendly names: surface roles `s1..s6` (theory-side), artifact
  aliases `n*` / `b<lang><mech?>*` (project-side, file-keyed),
  comparator ids `c1..c8`, scenario ids `e1..e13`. Canonical
  artifact names (`stub_binding_ocaml.mli`, etc.) for prose and
  cross-project lookup. Formal `Σ_*` notation reserved for the paper.
