# Paper plan & working roadmap

Venue strategy, milestones, OOPSLA punch list, and the five-step
alignment roadmap. One doc; cross-referenced. Replaces the earlier
split `plan.md` + `roadmap.md` (2026-05-19).

Companion to [`surface.md`](draft.md) (manuscript) +
[`surface_draft/`](surface_draft/) (materials) for theory, and
[`tiny.md`](tiny.md) (witness); see [`../README.md`](../README.md) for the
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
      `surface_draft/main.md` §6 / manuscript §5.7).
- [ ] Subtyping algorithm + decidability sketch.
- [ ] Soundness theorem statement; proof sketch acceptable.
- [ ] Type closed for at least one language (OCaml `.cmi` digest is
      the most tractable) — see §6 step 4 (c6 `cmp_type`).

### M2 — OOPSLA 2027 Round 1 (~mid-Oct 2026) — **PRIMARY, ~5 months**

This is the one to plan around. Everything else is opportunistic.

Theory / writing:
- [ ] Full draft of `surface.md` (manuscript) plus intro, related work,
      evaluation, and conclusion as a single OOPSLA submission.
- [ ] Manuscript §5.7 / materials `surface_draft/main.md` §6 (typed calculus) formalised to "applied
      PL paper" level (not full POPL, but more than a sketch).
- [ ] Coverage / blame story (§6 Impl / materials `surface_draft/implementation.md` §2.7) lifted into a contribution, not
      just a status table.
- [ ] Related work section against linking calculi, manifest
      contracts, ABI tooling (see [`literature.md`](literature.md)).

Tool / empirical:
- [ ] At least 2 more libraries beyond Z3/LLVM/sqlite. PyTorch
      (queued) is the obvious next; pick one more from the Tier-1
      candidate queue.
- [ ] TODO #18 — audit project specs for hardcoded shell commands
      (build-primitive extraction done; final sweep for leftover
      `Printf.sprintf` shell verbs pending).
- [ ] TODO #19 — LLVM cross-version C symbol check.
- [ ] TODO #40 — real `cmake --install` instead of fake `cp`.
- [ ] macOS local testing green (scope 2 of the macOS plan) — at
      least `canary artifact-test` on a Mac.

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

Foundational theory + tiny witness + prepare/confirm_ill flow all
landed pre-June 2026 — see [`worklog_2026_05.md`](../worklog/worklog_2026_05.md)
Session 8 for the chronicle. Surface-theory model lives in
[`surface.md`](draft.md) (manuscript) + [`surface_draft/`](surface_draft/)
(materials); tiny witness in [`tiny.md`](tiny.md). Remaining open
items for the paper:

- [ ] **Calculus story sharper.** Manuscript §5.7 / materials
      `surface_draft/main.md` §6 is a
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

`canary action {z3,llvm,sqlite}` end-to-end (both dev + stable
variants) and the tiny matrix (13 variants, contracts c1..c7 firing)
both demoed on Linux/WSL + GH CI. Live demos: llvm/19 OCaml
`Opcode.UncondBr`, z3/stable Python `parser_context`, plus every
tiny variant. Two-axis test surface (`artifact-test`, `pm-test`)
green. Remaining open items for the paper:

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
- [ ] **Full paper draft.** `surface.md` (manuscript) + intro, related
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
   rules (extending `surface_draft/main.md` §6 / manuscript §5.7).
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

Glossary tables in `surface_draft/` + `tiny.md`. Artifact alias
scheme (`n*` native, `b<lang><mech?>*` per-language binding)
introduced 2026-05-20. See worklog Session 8 for detail.

### Step 2 — Defer packaging cleanly  ✓ **DONE** (2026-05-19)

Packaging stays as a section inside `surface_draft/package.md`.
No `package_theory.md` needed.

### Step 3 — Compare theory, tiny, canary; plan shared utilities

Goal: use the precision of step 1's vocabulary to plan
implementation gaps *and* the shared tooling that both `canary
action` and tiny's harness should consume.

§2.7 alignment table landed and remains the load-bearing
contracts × scenarios × inspectors × comparators × status grid.
Remaining open items:

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

| layer                              | tool                                 | covers                                                         |
| ---------------------------------- | ------------------------------------ | -------------------------------------------------------------- |
| Pure unit (data shape)             | `test/canary_artifact_test.ml` pure  | watchlist matchers, JSON parsing, compat helpers — 13/13       |
| Shell integration (primitive runs) | `test/canary_artifact_test.ml` shell | `nm` / `ocamlobjinfo` / inspect_*.py on fixed fixtures — 15/15 |
| Per-PM                             | `canary_pm_test.ml`                  | apt/brew/opam/pip install + verify + remove lifecycle — 14/14  |
| Integration (heavy)                | `canary action <project>`            | full pipeline, ~10s–5min per project                           |

Seed fixtures + runner landed 2026-05-29; per-contract case lists
accumulated through Phase 14/15 (64 cases total at end of June; see
worklog_2026_06.md "Unit-test harness closure" + worklog_2026_05.md
Session 8). Remaining open items:

- [ ] **`canary_test/cmp_fixtures/`** — on-disk JSON fixture set
      (shareable with tiny's harness). Lands when the
      `canary_inspectors/` shared package does, so the Python and
      OCaml sides can read the same fixtures.
- [ ] Once `canary_inspectors/` package exists (Step 3 shared
      utilities), share the fixture set as Python-importable test
      data so tiny's harness and canary core run the *same* test
      matrix.

### Step 4 — Comparator and inspector buildout (principled shape)

> **Status note (2026-06-03):** Step 4's listed gaps (c4, c5, c6, c7,
> c8) are now superseded by **Phases 14e / 15.4 / 15.5b / 15.6**. c4,
> c5, c6 are wired as static comparators. c7 reframed as
> `api_sound_repack` (probe-runner mechanism, like c3). c8 disabled
> (no Contract). The 13-variant tiny matrix demonstrates each. The
> text below is preserved for historical context — read it as the
> "intent that drove Phase 15" rather than as live TODOs.

Step 4's original framing — close the c4..c8 inspector + comparator
gaps revealed by tiny — is delivered. Detailed implementation
history is in
[`worklog_2026_05.md`](../worklog/worklog_2026_05.md) Session 8
(late-May scaffolding) and
[`worklog_2026_06.md`](../worklog/worklog_2026_06.md) (Phase 14/15
pipeline wiring). Remaining open items from Step 4's original
scope:

- [ ] **Inspectors for `bpc1`** (ctypes argtypes parse) and
      **`bpe1`** (cext `PyMethodDef` parse). Python AST parse for
      ctypes; C parse for cext. Currently hardcoded-grep stand-ins
      (`inspect_tiny_typed.py` `stub_python` / `user_python`
      layers); real AST inspectors are the upgrade path.
- [ ] **Project-spec command decoupling — `Canary_toolchain`
      primitives** (absorbs **#18**). cmake / dune / ninja wrappers
      now live in `tool/canary_build_cmd.ml` (commits `952498e`,
      `800108d`); z3 / llvm / tiny use them. Remaining sweep: any
      project still doing raw `Printf.sprintf` of shell verbs that
      should route through a named primitive.
- [ ] **Real `cmake --install`** (absorbs **#25, #40**) —
      z3 / llvm `install_lib` scripts currently `cp` files (fake
      install). Replace with `cmake --install --prefix $PREFIX` so
      canary exercises cmake's install-time transformations.
      See `doc/canary/ops/install_targets.md` for patterns.
- [ ] **z3 cmake `build_z3_ocaml_bindings` PHONY guard** (absorbs
      **#26**) — `add_custom_target` always reruns; gate with
      `test -f z3ml.cmxa || ninja ...` so re-running canary
      doesn't trigger a full z3 rebuild on cache rebuild.
- [ ] **LLVM cross-version C-symbol check** (absorbs **#19**) —
      `llvm/19` probe today demonstrates OCaml API mismatch
      (`Opcode.UncondBr` compile error via c2 watchlist). Also
      surface as a C-symbol-set mismatch between libLLVM-dev's
      exports and libLLVM-19's exports via c1. Belt-and-suspenders
      for the same drift case.

### Step 4b — Phase 4: canary code-side term alignment ✓ **DONE** (2026-05-29)

Canary OCaml code aligned to the unified scheme (canonical names +
`n*`/`b*` aliases) so docs, tiny, and canary speak the same
language. See [`phase4_2026_05.md`](../worklog/phase4_2026_05.md).

### Step 5 — Update docs after each implementation milestone

Standard "tests green, docs follow" pass. Cumulative. Open items:

- [ ] After each remaining c\* / Contract update: flip the
      corresponding ✓/✗ in `surface_draft/surface.md` §2.4 and update tiny
      scenario expected outcomes if they change.

### Step 6 — Per-contract registry ✓ **DONE** (2026-06-02)

`registered_checks : contract_check list` in
`surface/canary_compat_run.ml`. `predicted_contains_any_v2` is now a
4-line iterator over the registry; each contract is one entry with
`id`, `name`, `layer`, `status`, `enabled`, `predict`.

### Step 6b — Per-project / per-CLI contract toggles ✓ **DONE** (2026-06-02)

`script_spec.disabled_contracts` (project-side) + `--disable-contract
c5,c4` (CLI flag) both consumed by `predicted_contains_any_v2
?disabled`. Tracked as Phase 13 in the audit doc.

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

**Order of attack — Phase 14/15 (shipped 2026-06).** Phase 14 wired
the tiny matrix mechanics (per-variant materialized workspaces,
per-artifact-kind stores, c1 / c2 / c3 / c4 demoed); Phase 15
finished the matrix (c5 / c6 / c7 + the Contract-vs-check reframing).
At end of June 2026, `canary action tiny` runs 13 variants
end-to-end, with the following active Contracts firing (attribution
in parentheses, mechanism in italics):

| Variant                      | Contract                       | mechanism                   |
| ---------------------------- | ------------------------------ | --------------------------- |
| baseline                     | —                              | every step done             |
| lib_broken                   | c1 (both langs)                | *static comparator*         |
| binding_mli_broken           | c2 OCaml                       | *static comparator*         |
| binding_python_attrs_broken  | c2 Python                      | *static comparator*         |
| hybrid_lib_broken            | c1 (both langs, cross-product) | *static comparator*         |
| lib_soname_bumped            | c4 Python                      | *static comparator*         |
| lib_behavior_broken          | c3 (both langs)                | *probe runner*              |
| binding_overdeclares_stubs   | c1 OCaml (orphan)              | *static comparator*         |
| app_helper_lib_broken        | c1 (both langs, chain)         | *static comparator*         |
| lib_symbol_version_broken    | c5 Python                      | *static comparator*         |
| binding_type_broken          | c6 OCaml                       | *static comparator*         |
| binding_repack_broken        | c7 OCaml                       | *probe runner (refutation)* |
| binding_python_repack_broken | c7 Python                      | *probe runner (refutation)* |

c8 dormant — no Contract (each binding is independent;
cross-binding consistency isn't a canary-side agreement).

**The chronicle of how this landed (Phases 14a..15.7) lives in the
worklog: [worklog_2026_06.md](../worklog/worklog_2026_06.md).** That
file is the canonical record for what changed when. plan.md keeps
only the forward-looking sections below.

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

| Project | Easy wins (c\* and natural perturbation source)                                                                                                                                      |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| llvm    | c1 + c2 OCaml already wired (Opcode.UncondBr); add Python (llvmlite version-floor); investigate c4 (LLVM SONAME bumps across majors); investigate c5 (libLLVM.so versioned symbols). |
| z3      | c2 Python already wired (parser_context); re-enable `has_build_binding=true` on z3-stable to add c1 (parallel to llvm); investigate c4.                                              |
| sqlite  | Most plumbed but no live demo. apt's `libsqlite3.so.0` vs Homebrew's `libsqlite.so.0` SONAME may differ — natural c4 candidate.                                                      |

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
