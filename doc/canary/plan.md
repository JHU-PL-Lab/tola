# Paper plan & working roadmap

**Kind: plan.** Venues, milestones, and the open roadmap. Open `[ ]`
items only — everything chronicled lives in [`../worklog/`](worklog/).

> **Rewritten 2026-08-26.** Two changes. (1) **POPL is purged** — its
> 9 Jul 2026 deadline passed without a submission, so the formal-calculus
> milestone (former M1) and the POPL venue-gap list are history; they are
> chronicled in [`worklog_2026_08.md`](worklog/worklog_2026_08.md).
> (2) The rest is re-stated against **project status** rather than against
> the April milestones: the empirical count that M2 asked for is met, the
> gaps that remain are *depth*, *concrete checking*, and *delivery*.
> §6's shipped design prose (steps 1–7, written before the A5 generic
> path) was compressed to its open items for the same reason.

Companion to [`draft.md`](research/draft.md) (manuscript) +
[`surface_draft/`](research/surface_draft/) (materials) for theory,
[`tiny.md`](research/surface_draft/tiny.md) (witness), and
[`../project/status_project.md`](project/status_project.md) (the
project layer's tracker — the empirical half of everything below).

## Quick map

- **§1 Strategy** — venue priorities, and the shape of the contribution.
- **§2 Target conferences** — deadlines and the time actually left.
- **§3 Milestones (M2–M4)** — what must be true by each deadline.
- **§4 The delivery pipeline** — theory → checker → world → finding →
  merged PR; the five stages, their status, and who owns each.
- **§5 Punch list** — what a reviewer looks for, with status.
- **§6 PLDI gaps** — the optional venue's specifics.
- **§7 Working roadmap** — open items only.
- **§8 Operating rules** — short.

## 1. Strategy

- **Primary venue: OOPSLA** — applied-PL framing, surface calculus plus
  a working multi-PM compatibility tool.
- **Optional stretch venue: PLDI** — empirical/algorithmic story; use its
  gaps as guidance, not as required scope.
- **Non-negotiable:** the tool stays practical and working. Theory grows
  from the implementation, not ahead of it.

**The contribution is the whole pipeline, both ends load-bearing**
(user, 2026-08-26). The claim is not "we have a surface theory" and not
"we found a bug"; it is that a theory of surfaces and agreements lowers
to *concrete checks*, that those checks run on *natural producers*, and
that what they find lands as an *accepted fix*. Each end without the
other is a weaker paper:

- a checker with no landed fix is a demo;
- a fix with no theory behind it is a bug report.

§4 makes that pipeline explicit as five stages, because the project's
strength is uneven across them — the middle is built, the ends are not.

**Division of labour** (user, 2026-08-26): the author writes prose;
**delivery and evaluation are agent-ownable** and run in parallel. §4's
owner column is what that means concretely — the stages that need
judgement about *framing* stay with the author, the stages that need
runs, tables, and reproductions do not.

## 2. Target conferences

| Venue | Edition | Role | Deadline | Left from 2026-08-26 |
| --- | --- | --- | --- | --- |
| **OOPSLA 2027** | SPLASH'27 | **Main** | R1: ~**mid-Oct 2026** (TBA) | **~7 weeks** |
| OOPSLA 2027 | SPLASH'27 | Backup | R2: ~mid-Mar 2027 | ~6.5 months |
| PLDI 2027 | — | Optional | ~mid-Nov 2026 (TBA) | ~11 weeks |

> **Confirm the R1 date before planning against it.** Both OOPSLA and
> PLDI rows are *estimates from prior years* — no CFP has been read.
> Everything in §3 is scheduled off that estimate, so a two-week error
> is a two-week error in the plan. First to-do in §7.

**Fallback shape.** R1 → R2 is the natural slip (carry everything
forward, add reviewer feedback). PLDI sits ~4 weeks after R1: if R1 is
made, PLDI is a different paper's worth of rework (§6) and should not be
attempted on the same material; if R1 is missed, PLDI is a fallback only
if the empirical story (§4 stages 4–5) matured in the meantime.

## 3. Milestones

Deadline-driven checkpoints. **M1 was POPL 2027 and is purged**
(2026-08-26) — milestone numbers are not reused, so the list starts at
M2. Items cross-link to §4 (pipeline stage) and §7 (roadmap).

### M2 — OOPSLA 2027 Round 1 (~mid-Oct 2026) — **PRIMARY, ~7 weeks**

The one to plan around. Everything else is opportunistic.

Theory / writing (**author**):
- [ ] Full draft of [`draft.md`](research/draft.md) plus intro, related work,
      evaluation, and conclusion as a single OOPSLA submission. The
      spine exists; §5 (CC) and §7 (Impl) are still roadmap bullets, and
      §5.6's own note says the real-project sections cannot be written
      honestly until the specs are lifted through the post-A5 framework.
- [ ] Related work against linking calculi, manifest contracts, and ABI
      tooling. Notes in [`literature.md`](research/literature.md).
- [ ] Coverage / blame story (§4 stage 4) lifted into a contribution
      rather than a status table.
- [ ] Manuscript §5.7 (typed calculus) formalised to "applied PL paper"
      level — a sketch is acceptable at OOPSLA, absent is not.
- [ ] **SSOT pipeline decision** — the ID dictionary is the
      manuscript↔code bridge and is currently also carrying enumeration
      design and open decisions. Settle its role before the prose pass
      leans on it; proposal in §7.

Tool / empirical (**agent-ownable**):
- [ ] **Concrete checking** — the agreement registry (§4 stage 2). The
      runner side lands projects fine; what a landing *checks* is still
      per-project tables plus c1..c8. This is
      [`../status.md`](status.md) M2 step 6 and its catalogue is
      [`agreement_registry_audit.md`](design/agreement_registry.md)
      (3 of 20 outline sections confirmed; resume at §2 *Artifact
      surfaces*). **Not descopable** (user, 2026-08-26).
- [ ] **Depth, not count** — the library count M2 originally asked for
      (3 → 5–8) is **met**: ten registry projects plus tiny1. The honest
      gap is the 2×2: two projects have the full matrix (sqlite —
      narrow; z3), one is collapse-only, six are half.
      [`../project/projects.md` §2](project/projects.md).
- [ ] **At least one merged or filed upstream PR** (§4 stage 5). Zero
      today. This is the single largest hole in the pipeline claim.
- [ ] macOS local testing green — at minimum `canary artifact-test` on a
      Mac. Note the repo now lives on one (`/Users/…`), while the run
      history and CLAUDE.md's paths are still the Linux/WSL box.
- [ ] CI runs the post-A5 shape (today it runs one chain per project,
      not the enumerated set) — [`../project/issues.md`](project/issues.md).

### M3 — PLDI 2027 (~mid-Nov 2026) — **stretch, ~11 weeks**

Fallback if R1 misses, or a complementary submission if the empirical
story matures fast. Scope in §6.

- [ ] Benchmark corpus: 30+ packages mined across apt/opam/pip with
      known breakages. The measured conf-* survey
      ([`../surveys/conf_packages.md`](surveys/conf_packages.md) §G)
      is the mining machinery — it already ranks candidates from opam
      metadata, apt, and conda-forge.
- [ ] Concrete static-inference algorithm with a complexity statement.
- [ ] Baseline comparisons: `abigail`, `abi-compliance-checker`, opam
      `lint`, Debian symbols files.
- [ ] At least 3 real regressions caught that baselines miss.
- [ ] Performance numbers on the corpus.

### M4 — OOPSLA 2027 Round 2 (~mid-Mar 2027) — **backup, ~6.5 months**

Carry forward all M2 items; expand empirical scope; incorporate R1
reviewer feedback if any.

## 4. The delivery pipeline

> New section, 2026-08-26, from the user's framing: *"the pipeline from
> the theory to the product (accepted fix or merged PR) are both
> important"*.

Five stages. The middle is the built part; the ends are the paper's
weak points. **Owner** is the split from §1 — `author` needs a framing
judgement, `agent` needs runs and tables.

| # | Stage | What it produces | Status | Owner |
| --- | --- | --- | --- | --- |
| 1 | **Theory** — surfaces + agreements | what *can* be violated | model landed; catalogue **3/20** | author |
| 2 | **Checker** — a contract with a tool-grounded falsifier | what a run *observes* | c1..c8 wired (c8 dormant); per-project tables not yet converged onto the registry | agent |
| 3 | **World** — the project's 2×2 | where a violation *can appear* | **the working part** — 10 projects, 42 scenarios, 41 run | agent |
| 4 | **Finding** — a red cell with readable evidence | what we *claim* | evidence is readable from `actions.log` (A0–A3, 2026-08-20); blame framing not lifted | both |
| 5 | **Fix** — upstream PR + our fork proving the check passes | the *product* | **not started — 0 PRs** | agent |

**Where the gaps actually are.**

- **Stage 2 is the bottleneck the user named.** Landing a project is
  cheap now (declare an artifact table; the runner does the rest), which
  makes it tempting to read the roster as progress. But a landed project
  runs the checks its own spec happens to name — the catalogue that says
  *which agreements a world of this shape admits* is 3/20. Growing the
  roster without growing stage 2 adds rows, not claims.
- **Stage 5 has candidates already.** The findings exist and are
  reproducible; none has been taken upstream. Ranked by how close each
  is to a filed PR:
  1. **ncurses / `conf-ncurses`** — `["lib64ncurses-dev"] {os-family = "ubuntu"}`
     can never fire, because opam reports `os-family = debian` on
     Ubuntu. A one-line opam-repository fix with a measured
     justification. The cheapest first PR in the registry.
  2. **z3 #10549 regression** — the installed OCaml package did not
     exist before that PR; canary's `pre-10549` ref reproduces it as
     two `install_lib` xfails plus a staged-probe xfail. The fix is
     upstream *already*, which makes this the cleanest "our check
     agrees with a real repair" narrative even without a new PR.
  3. **z3 forward cell** — HEAD-built binding needs 791 `Z3_` symbols,
     apt's 4.8.12 provides 705. Real, ref-independent, and the report's
     worked example; the upstream ask is a declared floor, not a code
     change.
  4. **sundials 6→7** — the binding compiles a 6.x path against a 7.x
     library because `configure` accepts the version syntactically and
     no 7.x guard exists. A genuine upstream bug; the most valuable and
     the most expensive (177 apt packages to run it).
- **Stage 4 is what the report milestone is for** —
  [`../project/status_project.md` §3](project/status_project.md).
  A narrative over the matrix ("your HEAD binding broke against your
  released lib; here is the failing check; here is the fork with the
  fix passing it"), not a dump of run artifacts.

**The agent-ownable track, concretely** (what can proceed while prose is
being written): stage 5's PR #1 and #2, the §5 evaluation tables (run
coverage and age, the verdict matrix, the per-project 2×2 column), the
CI post-A5 shape, and the macOS green run. Stage 2's catalogue needs the
author for *what a section claims* but not for the registry rows that
follow from it.

## 5. Punch list — status

What has landed (`[x]`) and what a reviewer will look for (`[ ]`).

### Theory

Foundational theory, tiny witness, and the prepare/confirm flow landed
pre-June 2026 — chronicled in
[`worklog_2026_05.md`](worklog/worklog_2026_05.md) Session 8. The
model lives in [`draft.md`](research/draft.md) + [`surface_draft/`](research/surface_draft/);
the witness in [`tiny.md`](research/surface_draft/tiny.md).

- [x] Surface roles, contract catalogue c1..c8, tiny as the witness that
      each fires.
- [ ] **Agreement catalogue systematised** — §4 stage 1. The registry
      producer exists; the catalogue that grounds each agreement in a
      tool is 3/20 sections.
- [ ] **Calculus story sharper** — transformer signatures, surface
      subtyping, the static/runtime refinement loop as the headline.
- [ ] **Coverage / blame story lifted** — which contract a failure is
      blamed to, as a reusable framing.
- [ ] **Type contract convincingly framed** — c6 is wired as a static
      comparator; the prose has to say what it does and does not close.

### Implementation

- [x] **The generic path** — every registry project is a `project_run`;
      the five-pass pipeline (declare / enumerate / select / order /
      realize) is one assembly, dumpable per pass with
      `canary emit <p> --stage <n>` (2026-08-24).
- [x] **Ten projects + tiny1**, 42 scenarios, 41 run; every prediction
      derived through one lowering and contract-attributed.
- [x] **Two-axis test surface** green (~220 cases across project /
      artifact / PM suites); canary runs in its own opam switch
      (2026-08-26).
- [x] **Evidence is readable from the run log** — `cmd_log` / `cmd_out` /
      `note` events; `status -v` renders the log's own witness lines.
- [ ] **Empirical depth** — the 2×2 on more than two projects (§3 M2).
- [ ] **Detection coverage** — tiny1 is 22/22 PASS but detects 12/24;
      the undetected half is watchlist-blind (c5/c6/abi) and needs
      richer inspectors, not plumbing.
- [ ] **tiny-full's declared axes** — it advertises six worlds and
      enumerates one; the Built-lib and Dev-binding axes are in dead
      code. Restore or delete —
      [`../project/issues.md`](project/issues.md) §1. As the
      witness-scaled-to-a-project, it is cited by the paper.
- [ ] **Comparator closures** — see §7.

### Paper positioning

- [ ] **Related work** — linking calculi (Cardelli's units,
      Flatt–Felleisen, MixML), manifest contracts, ABI tools
      (`abigail`, `abi-compliance-checker`), SemVer literature. Notes in
      [`literature.md`](research/literature.md).
- [ ] **Evaluation section** — the matrix as evidence: what was checked,
      what fired, what was fixed. Depends on §4 stages 4–5.
- [ ] **Full paper draft.**

## 6. PLDI gaps (optional venue)

1. Static-inference algorithm stated explicitly with complexity bounds.
2. SymbolVersion wired end-to-end on a real version-drift case. Partly
   there: c5 fires on tiny's `lib_symbol_version_broken`, and zlib
   1.3.2's `ZLIB_1.3.1.2` / `ZLIB_1.3.2` nodes are the measured natural
   case ([`../surveys/conda_forge.md`](surveys/conda_forge.md)) —
   unlanded.
3. Benchmark suite: 30+ packages across apt/opam/pip with a quantified
   breakage corpus.
4. Baselines: `abigail`, `abi-compliance-checker`, opam `lint`, Debian
   symbols files.
5. Measured bug-finding power: real regressions caught that existing
   tools miss, with reproducers.
6. Performance numbers (inference time, false-positive rate vs. the
   runtime canary).

## 7. Working roadmap

**Steps 1–7 are done and chronicled.** Terms unified (2026-05-15),
packaging deferred cleanly (2026-05-19), the unit-test layer seeded
(2026-05-29), comparator/inspector buildout delivered as Phases 14/15
(2026-06), the per-contract registry and its toggles landed
(2026-06-02), and the matrix-coverage design (former step 7) shipped and
was then superseded by the A5 generic path — its prose described
`script_spec` / `run_project_multi` / `canary_project_tiny.ml`, none of
which exist now. History:
[`worklog_2026_05.md`](worklog/worklog_2026_05.md) Session 8,
[`worklog_2026_06.md`](worklog/worklog_2026_06.md),
[`phase4_2026_05.md`](worklog/phase4_2026_05.md).

**Naming convention** (live — the code and docs follow it):

- **Theory-side indices**: `s1..s6` (surface roles), `c1..c8`
  (contracts / comparators), `e1..e13` (scenarios). Project-invariant.
- **Project-side artifact aliases**: `n*` native, `bo*` OCaml binding,
  `bpc*` Python ctypes, `bpe*` Python cext. Sequential per binding,
  file-keyed.
- **Canonical artifact names**: `<role>_<side>[_<lang>][_<mech>].<form>`
  (`lib_native.so`, `compiled_binding_ocaml.stub-a`). Prose form in code.
- **Usage**: canonical names in OCaml code, IDs in tables / log lines /
  JSON keys / status displays.
- **Formal `Σ_*` notation**: reserved for the paper.

### Open items

**Scheduling**

- [ ] **Confirm the OOPSLA 2027 R1 and PLDI 2027 dates from the CFPs.**
      §2 is scheduled off prior-year estimates. Do this first; rewrite
      §2–3 if either moves.

**The SSOT pipeline** (M2, author decision — proposed 2026-08-26,
awaiting confirmation)

[`ssot.md`](design/ssot.md) is 1209 lines doing three jobs: the ID
dictionary (§1–3, §6.1), enumeration *design* (§4.2.x), and an
open-decision list (the `drift` rows). The second job now has its own
tree — [`design/enumeration/`](design/enumeration/) with a doc per
pass — so the design half is duplicated, and a prose session pays for
all three. Proposed shape:

- [ ] **Narrow it to the bridge.** Keep §1–3 (Ar / Sf / Ag), §6.1
      (term ↔ code), §8 (downstream usage in `draft.md`). Replace
      §4.2.x with pointers to the pass docs that own that material, and
      move §5's mutation shapes to tiny's doc. Target ~300 lines — a
      size a prose session can hold.
- [ ] **Let the prose decide the drift rows.** The open decisions
      (`Ar.0..Ar.3` vs code's five kinds incl. `Headers`; Sf.k ↔ Ar.k
      alignment) are exactly the ones writing §2/§3 forces. Decide them
      *while* prosing, one per section, rather than in a separate pass.
- [ ] **Ratchet it with a check, don't maintain it by hand** — a test
      that every `Ar.\d` / `Sf.\d` / `Ag.\d` / `c\d` / `Sc.\d` id cited
      in `draft.md` resolves in `ssot.md`, and that every code symbol in
      an ssot code column exists in the source. Cheap, agent-ownable,
      and it converts "drift" from a label someone types into a failure
      someone gets. The tables the code already emits (`paths`, `graph`,
      the scenario lists) stay generated rather than transcribed.

**Checking (§4 stage 2)**

- [ ] **Agreement catalogue** — resume at
      [`agreement_registry_audit.md`](design/agreement_registry.md)
      §2 *Artifact surfaces*; 17 of 20 sections open. The per-project
      contract-binding tables converge onto it and get deleted
      ([`../status.md`](status.md) M2 steps 6–7).
- [ ] **Closure-shape contract** — no c1..c8 states it, and ncurses is
      the specimen: two packagers agree on every symbol, soname and ELF
      version node and still segfault.
      [`closure_shape.md`](design/closure_shape.md). First contract
      addition since the registry landed.
- [ ] **Real AST inspectors for `bpc1` / `bpe1`** — ctypes `argtypes`
      parse and cext `PyMethodDef` parse; today's stand-ins are grep.
- [ ] **Surface-aware `actions.log`** — one event per contract
      (`c1 cmp_symbol (3 symbols)`) instead of one collapsed
      `compat_predicted (3 substring(s))` count, plus `contract_skipped`
      events. Deferred since 2026-06; the registry that makes it trivial
      now exists, and it is what makes stage 4's evidence per-contract.

**Delivery (§4 stages 4–5)**

- [ ] **First upstream PR** — the `conf-ncurses` `os-family` line.
- [ ] **The report** — the narrative over the matrix
      ([`../project/status_project.md` §3](project/status_project.md)).
- [ ] **Run coverage and age** printed by `result` / `status`, so
      `41/42` is accounted rather than reconstructed by hand.

**Project-spec hygiene** (long-standing, absorbs the old #18/#19/#25/#26/#40)

- [ ] Real `cmake --install` instead of the `cp` fake in z3 / llvm
      `install_lib` — see [`../ops/install_targets.md`](ops/install_targets.md).
- [ ] z3's `build_z3_ocaml_bindings` PHONY guard
      (`test -f z3ml.cmxa || ninja …`) so a cache rebuild doesn't
      trigger a full z3 rebuild.
- [ ] LLVM cross-version C-symbol check — surface the `Opcode.UncondBr`
      drift as a c1 symbol-set mismatch too.
- [ ] Final sweep for raw `Printf.sprintf` shell verbs that should route
      through a named `canary_build_cmd` primitive.

**Docs**

- [ ] Regenerate [`tiny.md`](research/surface_draft/tiny.md) — it is tiny1-era; rewrite for the
      tiny-factory / tiny1 / tiny-full split with canonical naming. The
      paper cites it as the witness.
- [ ] After each c\* / contract change, flip the corresponding ✓/✗ in
      `surface_draft/surface.md` §2.4.

## 8. Operating rules

- Every code change should also move the paper forward, or vice versa.
  Theory-only refactors that don't land in code, and feature work that
  doesn't simplify or strengthen the surface model, are deferred.
- Keep the tool runnable end-to-end at every milestone. Green
  `canary action @all` + `make canary-test` is the baseline before any
  paper-side claim.
- **Prose and delivery run in parallel** (2026-08-26). The author owns
  framing; runs, tables, reproductions and PRs are delegable. §4's owner
  column is the split.
- Update this doc when deadlines firm up or scope changes. Don't
  silently re-plan — write it down here.
- One roadmap step at a time. After each, pause and discuss before
  committing the next.
