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

See [`phase4.md`](phase4.md) for the term-alignment tracker that
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
      the CLI; new tooling can import.
- [ ] Decide naming for the new inspectors targeting `bo1` (OCaml
      `external` parse), `bpc1` (ctypes argtypes parse), `bpe1`
      (cext `PyMethodDef` parse), and `n3` (C header parse).
- [ ] Discuss scenario naming consistency
      (`api_faithful` / `api_complete` describe the *property*, not
      the *violation* — separate small pass).

### Step 4 — Implementation

Order by gap-shape (comparator-only first, since the JSON already
exists) then by likely effort. Each item is also a row in the M2
or M3 milestone above.

- [ ] **c4 `cmp_abi`.** Reads `n4` + `bo6`/`bo7` (or `bpe3`)
      outputs; verifies every NEEDED entry resolves to some library
      exporting that SONAME. Diagnostic today; promote to a
      comparator. (Comparator-only.)
- [ ] **c5 `cmp_sym_version`.** Reads `n4`'s `versioned_exports`
      and consumer-side `versioned_req` fields; verifies every
      `@VER` requirement is satisfied by some `@@VER` export.
      (Comparator-only.)
- [ ] **Inspector for `bo1`** (OCaml `external` decls). Add
      `^external` matching to `inspect_binding.py` (one-line regex
      change). Unblocks s3 stub-facing for OCaml.
- [ ] **Inspector for `n3`** (C header parser). New parser for C
      function signatures from `.h`. tree-sitter-c or libclang.
      Substantial.
- [ ] **c6 `cmp_type` (OCaml first).** Once `n3` and `bo1`
      inspectors land; compare signatures by name.
- [ ] **Inspectors for `bpc1`** (ctypes argtypes parse) and
      **`bpe1`** (cext `PyMethodDef` parse). Python AST parse for
      ctypes; C parse for cext.
- [ ] **c7 `cmp_api_repack` (OCaml first).** Compare `bo1` vs
      `bo4`; verify every user-facing name corresponds to a
      stub-facing name with compatible types.
- [ ] **c8 `cmp_api_faithfulness`.** Pure composition once c1, c6,
      c7 exist.
- [x] **`canary_project_tiny.ml`** (2026-05-28 / expanded 2026-05-29):
      `canary action tiny` runs the full 12-step pipeline (6 main +
      6 inspect) using the aligned vocabulary. JSON shapes
      byte-equivalent to `make scenarios-cached`. Phase 4 milestone
      check passed — see [`phase4.md`](phase4.md).

### Step 4b — Phase 4: canary code-side term alignment

Tracked in detail in [`phase4.md`](phase4.md). Brief: canary OCaml
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
