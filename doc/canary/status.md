# Canary Status

**What is true now, and what is open.** Sections 1–2 are the live
picture; 3–6 are the standing work, oldest commitments last.

Elsewhere: the project roster and per-project work are
[`project/status_project.md`](project/status_project.md) and
[`project/projects.md`](project/projects.md); open per-project findings
are [`project/issues.md`](project/issues.md); lower-priority items are
[`backlog.md`](backlog.md); history is [`worklog/`](worklog/).

Milestones: **M1** (framework hardening) completed 2026-08-16, chronicled
in [`worklog/worklog_2026_08.md`](worklog/worklog_2026_08.md). **M3**
(grow projects) moved to `project/status_project.md` in the 2026-08-12
reorganization. **M2** is §3 below and is the one still running.

---

## 1. Where things stand

**The pipeline is six passes and linear** (2026-09-16): declare ·
analyse · enumerate · select · order · realize. Applicability is
answered once, at pass 2, from the spec alone — the rule being that a
fact needing no world belongs there. `canary emit <p> --stage <name>`
prints any of them. Map:
[`design/enumeration/README.md`](design/enumeration/README.md).

**The agreement layer: 14 agreements, 9 landed** (2026-09-29) — landed
meaning a real project's run decided `holds` or `violated`, which is the
only evidence a check works. Plus **16 candidates**: named, classified,
no evaluator. The live answers are `canary checks --landing` and
`canary checks --firing`; the docs maintain no second catalogue.

**The Agreement overview is the reference** (2026-09-17, user). One row
per (agreement × firing pattern), carrying the claim's kind, where its
code is, the languages and mechanisms that carry it, the object format
it ranges over, its target artifacts, and the action grid marking where
the rule RAN against where the check FIRES. It is the template of the
result matrix, and since 2026-09-23 it lives on the overview page
(`canary overview`, `docs/canary/overview.html`; `make view`), not above
the matrix. Layout and row order:
[`design/matrix.md`](design/matrix.md).

**Three axes describe a claim, and they are independent** — `ag_kind`
(what it asserts: admissibility · promise · quality · preservation · behaviour
· composition), `m_reference` (what the second side is), `ag_rooted_in`
(whose rule, at which action). Two of them shared a field until
2026-09-17. `api_names_present` is the case that forces them apart: an
admissibility claim one of whose members is a declaration.

**Two harnesses check the table itself, and the table says so**
(2026-09-17, surfaced 2026-09-21). `row_rules` holds the laws relating
two cells of one row — six today, as data, enforced by
`agreements.rows_obey_their_own_laws`, so a rule added to the list needs
no test edit. Beside it, the saturation grid asks what no row can: is
any (mechanism × object format) cell unwatched?

The result is carried as a one-line verdict above the table in BOTH
views (it used to print only in the terminal, so the page the table is
read in never said whether it had been checked). It reads, today — and
the count moves whenever a law is added, so read it from `canary checks
--firing` rather than from here:

> `checked: 6 laws, every row obeys them · no unwatched mechanism × format cell`

The verdict is pinned to the page and pinned to AGREE with what the
audit computes — a page claiming the laws hold beside a failing audit
would be worse than no line at all.

**Tests: 193 project + 120 artifact + 17 PM = 330** (2026-09-29). `make canary-test`
after every edit under `src/canary/`; `make canary-post-check` before
committing.

**GH CI is alive** (2026-08-27, extended 08-28). `canary_min.yml` runs
eight projects green on `ubuntu-latest` — sqlite, cairo, zarith, libffi,
zlib, zstd, ssl, llvm, the cheapest world of each, 45–199s per job —
rendered from the LIVE pipeline (`Canary_ci` over
`Canary_pipeline.steps_of`) rather than the per-project `*_ci_spec`
values that had drifted. Two red cells reproduce there: llvm's
`Opcode.UncondBr` and ssl's `api_names_present` on `probe_app_ocaml`.
The pre-A5 `canary_ci.yml` is `workflow_dispatch`-only until its jobs
migrate ([`project/issues.md`](project/issues.md) §2).

**Structural facts worth not rediscovering.** `Canary_registry.all_projects`
is the single source of truth for project names.
`Canary_runner.run_project_spec` is the one entry both the CLI and the
tests use. `artifacts_of_action` derives consumes/produces from the typed
action catalogue. The mechanism vocabulary lives in `base/`, as working
code the lowering reads.

---

## 2. Open now

Seven items, in the order they are worth doing. The overview page's two
are short here: §2.7 draws recorded runs on its diagram and continues
with phase E, and §2.6 then derives the page's hand-written parts from
the framework. Both are planned in
[`design/overview.md`](design/overview.md) §6. §2.5 is the forward look
— what the unlanded claims would take — and is where the manuscript's
plan material comes from.

**One question came back and is answered** (2026-09-21): §6's
distinction 1 — does a named check's failure fail its step? — was
flagged, not decided, and the agent who would own step 7 asked the
agreement side to settle it, since we own `outcome` and the acceptance
policy. Decided in `action_model.md` §6: **a named check's failure fails
its step iff the check is a POSTCONDITION, never because it carries an
agreement's name.** There are three registers, not two — postcondition,
world assertion, agreement.

⚠ **Step 2 was to have separated the first two in code, and it was
WITHDRAWN on 2026-09-21** (§9, argued in §5): a register says what a
failure MEANS, and the missing axis is the OCCASION, which says what it
does. `check_post` is evaluated at three — graph start, warm gate, after
the command — and at the first two a failing world assertion invalidates
a marker rather than failing anything. So the pin half cannot become a
`Canary_world` prelude, because a skipped step runs no command. The
decision above is unaffected; what moved is where the code change
happens, which is now step 6. It also inherits a duplication: the
still-valid half is written twice, in `run_step` and `run_graph`.

⚠ **Before dispatching an agent at the ACTION MODEL** (the §9 plan in
[`design/action_model.md`](design/action_model.md)): that document now
carries, under §6, what the agreement layer READS from the action model
— five couplings, the pin that catches each, and the acceptance gate for
its step 5. Steps 5, 7 and 8 all touch code the agreement work depends
on, and step 5 can turn every landed claim into a silent `unavailable`,
which is not a test failure but a check that stopped checking.

### 2.1 macOS is unwatched, and the host/runner question behind it

**The narrow gap:** no claim is specific to Mach-O, although Mach-O has
a version gate with no ELF counterpart — `compatibility_version` in
`LC_ID_DYLIB`, which `inspect_native.py` has extracted since the macOS
port and **no agreement reads**. Written evidence with no reader, rooted
in dyld's own rule, cheap falsifier. It is in the candidate table as
`compatibility_version_satisfied`, and both the saturation report and
the candidate table now point at it.

⚠ **Its blocker is reporting, not evidence.** `canary checks --landing`
is platform-blind, so an agreement landed only on macOS would read as
landed everywhere. Settle that first —
[`design/platform.md`](design/platform.md) §6 asks the same question of
the cross-platform viewer.

**And that blocker is smaller than this section assumed** (measured
2026-09-21, with a macOS session starting). The platform is ALREADY in
the log, per step, on the same tag as the outcomes it would qualify:

```
build_lib  opam_switch  (canary)
build_lib  platform     (wsl_ubuntu)
build_lib  agreement_outcome  (soname_matches_declaration/…: holds)
```

`Canary_store.string_of_platform` writes it and `platform_of_string`
parses it back, so the vocabulary round-trips and no new evidence has to
be collected or transported. What is missing is only that
`Canary_status.observe_lines` drops the `platform` line on the floor: it
folds over a run's lines already, keys its table on `(agreement,
method)`, and would have to carry the last-seen platform into that key.
Three places change — the fold, `landing_row`, and `pp_landing`'s
`decided in <projects>`, which becomes `decided in <project>@<platform>`.

**Do it BEFORE the mac's results arrive, not after.** The report does not
fail when a macOS outcome lands in it; it silently widens a claim's
scope, which is the same shape as the pins that went vacuous when
`agreements.md` was deleted. There is nothing to un-report if it is in
place first, and the change is cheap enough that waiting buys nothing.

⚠ **A file collision to sequence, not a conflict to resolve.**
[`design/platform.md`](design/platform.md) §7 item 4 — tiny's Mach-O
naming port, `libtiny.so.1` spelled out in ~40 declarations — lands in
`project/canary_tiny_workspace.ml` (32 occurrences) and
`project/canary_tiny_scenario.ml` (38). Those are exactly the two files
§2.5's first direction needs: the first is the mutation dispatch, the
second holds `all_scenario_specs`. Either order works; doing them
concurrently does not. The naming port is mechanical and wide, the
correspondence probe is narrow and additive, so the cheaper sequence is
the port first — but it is the mac session's call, and whoever goes
second rebases rather than merges.

**The larger question** (user, 2026-09-21): the mac is reachable over
ssh, and each machine has so far run standalone against its own fork.
Could this machine be the HOST and the mac a runner?

It fits the architecture better than it might sound, because **the step
list is already the boundary**. Passes 1–6 are pure and platform-blind
until realize; the `step list` they produce is object code consumed by
four backends — `run_graph` executes, plus the GH YAML, Mermaid and HTML
renderers. **A remote runner is a fifth backend**, beside
`backend/canary_local_runner.ml`, not a new pipeline.

What would have to change, in order:

1. **The two shell-out points become one transport.** CLAUDE.md already
   names them: `run_cmd_logged` (every step's command) and
   `Canary_store.sh_in_switch` (the OCaml-side store queries —
   `pin_check_post`, `Canary_pm_opam.is_installed`). Both must run on the
   mac, because both ask about the mac's opam switch and filesystem.
2. ⚠ **`check_pre` and `check_post` are CLOSURES, and that is the real
   blocker.** `check_pre : unit -> bool` and
   `check_post : output_dir:string -> variant_key:string -> bool` close
   over the local filesystem, so they would run on the host while the
   files sit on the mac. This is the SAME boundary
   [`design/action_model.md`](design/action_model.md) §§4–5 records for
   the GH backend, where a closure cannot cross into rendered YAML and a
   green CI job therefore means only "every command exited 0". **One fix
   serves both**, and it is smaller than it looks: `check_pre` carries no
   project logic at all, and every project-supplied `check_post` is the
   one `pin_check_post` compositor, which splits into a postcondition and
   a world assertion. The ordered plan is that doc's §9. `inspect` is
   already on the right side — it returns a command string, which crosses
   fine.
3. **Evidence has to come back.** The evaluators read `inspect.json` from
   local paths, so either the project's `_out` subtree syncs after the
   steps that write evidence, or `resolve_input` learns a remote
   transport. The sync is the cheap first version.
4. **Paths and the switch are per-machine** — `CANARY_BUILD_DIR`, the
   opam switch name, the contrib tree. These are already values rather
   than constants, which is what makes this tractable.
5. **Nothing needs to change about identity.** The platform is carried,
   not sniffed, and both the platform and the switch already ride the
   step fingerprint — so a verdict earned on the mac is never served to a
   Linux run, and vice versa. That was built for `--platform` rendering
   and pays off here unchanged.

**Cheapest honest first step**, if this is wanted: run the mac
standalone as today, but have it publish its `actions.log` back, so
`canary checks --landing` can be made platform-aware before any
transport work. That unblocks 2.1's narrow gap without the closure
refactor.

### 2.2 tiny-full declares two Python mechanisms, and one step serves both

`Cext` and `Ctypes`, deliberately — it is the witness project. But
`Probe_binding` carries a language and no mechanism, so both realize ONE
`probe_binding_python` step: one log tag, one matrix column, and
`mechanism_for` returns the first, so pass 2 computes applicability for
`Cext` alone. The artifact axis distinguishes them; the action axis does
not.

Ratcheted by `analysis.one_mechanism_per_language`, which names
tiny-full as the known case and fails on a second. The fix is a
mechanism in the action vocabulary — a `base/` change touching the step
model, log tags and matrix columns. Not worth it for one witness
project; worth knowing before a second wants it. Written up in
[`project/issues.md`](project/issues.md) §2, beside the sibling gap (a
mechanism declared in two places, one of them read).

### 2.3 The `agreement/` docs — paused, user-owned

Restructured to four files on 2026-09-17 (`README.md` · `theory.md` ·
`components.md` · `mechanism.md`) with the overview as the entry point.
The OCaml half of that change landed after it — three pins had gone
silently vacuous when `agreements.md` was deleted, and
`agreements.pinned_docs_exist` now fails when a document a pin reads
disappears. **The user is doing the remaining cleanup by hand**
(2026-09-21); leave these files alone.

### 2.4 The kind vocabulary — `admissibility` landed, the rest open

`admissibility` · `promise` · `quality` · `preservation` · `behaviour` ·
`composition`.

**`pairing` became `admissibility` on 2026-09-21** (user: "if one action
uses to establish the connection between several inputs and outputs,
when here is doing to try to recover/recall the post factum. Do we have
a precise term"). The answer has two halves. The RECOVERY cannot be in
the name, because it is what an agreement IS — [`theory.md`](design/agreement/theory.md)
§3 defines one as a necessary condition recovered from surviving
evidence, so every kind is post factum and that is the genus, not the
difference. What differs is WHICH relation, and theory.md §2 already
names this one: `R_A ⊆ I₁×…×Iₙ`, the tuples an action's rules accept.
The word for belonging to it is **admissible**.

Three rejected, each for a reason worth keeping: `compatibility` is what
a reader reaches for and theory.md forbids it (a pass is necessary,
never sufficient, and "compatible" promises sufficiency);
`correspondence` is already claimed by the cross-API direction, so it
would be ambiguous inside canary; `realizability` collides with pass 6.
And `pairing` itself baked in an arity the model does not have — `R_A`
is n-ary, so a three-input action's claim is not a pair.

**Still open: the register.** The six are nouns, which suits the column
header `kind` — "what kind of claim is this". The alternative is
participles describing the thing (`admissible` · `promised` ·
`well-formed` · `preserved` · …), which would suit the per-agreement
record's header `asserts` better. Both registers are internally
coherent; mixing them is the only real error, so `promised` alone would
be wrong. Nouns degrade more gracefully — `quality` and `composition`
have no good participle — which is why they stayed. Cheap to revisit:
each name is one constructor and one display string, and
`agreements.kind_partitions_the_catalogue` holds the partition
regardless of spelling.

### 2.5 The three unlanded directions — how close each is to working code

*(2026-09-21. Assessed against the code rather than the plan; the
manuscript can lead with these as rationale, but a plan is only credible
if each names its falsifier — [`design/agreement/theory.md`](design/agreement/theory.md)
§6 step 5.)*

**Take them 1 → 2 → 3.** The order is by external blocker, not by value.

**1. Cross-API correspondence — closest, and tiny is already shaped for
it.** `canary/examples/tiny/c/src/tiny.c` gives two properties that make
it a near-perfect witness:

```c
int tiny_offset = 42;
int tiny_sum(int a, int b)  { return a + b + tiny_offset; }
int tiny_diff(int a, int b) { return a - b; }
```

`tiny_diff` is NON-COMMUTATIVE, so an argument-order fault is detectable
(`3-4` against `1`). `tiny_sum` reads a GLOBAL, so a binding that
reimplements the arithmetic instead of calling the library returns 7
where the library returns 49 — and **no symbol check, type check or ABI
tool can see that**, `abidiff` included. That is the clearest evidence
this claim is not a subset of anything in the `_ext` rows.

No new evidence plumbing, no platform blocker, no external tool, all
in-tree; the falsifier costs one line. It would land `behaviour`, which
is 0/1 and has no external answerer. **First increment is the MUTATION,
not the generator** — make the conversion fault, confirm the table stays
green while the code is wrong, then write one hand-written
correspondence probe. Generate only after one case has caught something
([`design/directions.md`](design/directions.md) §2).

**2. Cross-package-manager `discovery_matches_link` — one recorded fact
away, and we have already lived the failure.** Both halves are one shell
command and one already exists: `Native_lib_probe` holds the resolved
library path, and `canary_toolchain.ml` already emits
`pkg-config --variable=libdir`. What is missing is recording
pkg-config's answer as EVIDENCE at the `conf-*` step, then comparing.

**Reviewed against the specs 2026-09-21, and the conf hop turned out to
be the richer half.** Eight of ten projects gate their binding on a
`conf-*` package and **six of those eight have no effective version
gate** — `opam install` succeeding establishes that a header was present.
Three findings about our own instrumentation came with it: `pm_gate` is a
typed declaration NOTHING reads (the twin of `compatibility_version`,
which is evidence nothing reads); every opam install canary issues
carries `--assume-depexts`, so we surveyed 370 conf packages and have
never once exercised the mechanism; and five specs hand-transcribe
`opam show --field=depends` output into comments, which is the hand-copy
gotcha at spec level. Four claims look recoverable, and the one with a
live falsifier on this box is **the gate admits the world** — llvm's gate
pins generation 19 while this machine carries llvm-18, llvm-19 and
llvm-24 side by side. Written up for outside discussion, with five open
questions, in [`design/package_gates.md`](design/package_gates.md).

⚠ The falsifier is in our own history. z3's `Probe_lib` override
resolved the library with `pkg-config --variable=libdir z3` — the SYSTEM
one — in **every world, including those that build their own**. We
treated it as a canary bug and fixed it by deleting the override. It is
exactly the phenomenon this claim names: a discovery mechanism answering
differently from what the world intends. We had the failure and did not
have the claim. Applies to cairo/libffi/zarith today; the ncurses report
is the stronger falsifier but needs a conda prefix.

**3. Versioning `compatibility_version_satisfied` — cheapest evidence,
furthest from running.** Half of what §2.1 says: `inspect_native.py`
captures `compatibility_version` only under `LC_ID_DYLIB`, so we have
the PROVIDER's promise and not the CONSUMER's requirement, which lives
on `LC_LOAD_DYLIB`. The pairing claim needs a one-line inspector change.

A cheaper first step needs no new evidence at all: a PROMISE claim — the
library's `compatibility_version` is what the project declared — is
decidable from what is already extracted. But both are Mach-O only and
`canary checks --landing` is platform-blind, so landing either would
report dishonestly on Linux. That is §2.1's reporting question rather
than this claim's, and it is why this one is third despite being the
cheapest to evaluate.

### 2.6 Merging the overview page into the framework

Part of the overview task's one list since 2026-09-29: the steps are
[`design/overview.md`](design/overview.md) §6.2, and §6's list says
where they fall in the order.

### 2.7 The overview page — its status is `design/overview.md` §6

The overview task keeps its status in one place,
[`design/overview.md`](design/overview.md) §6 (user, 2026-09-29): a list
grouped by what each item needs, with decisions first, then work that
adds no action, work that adds an action (held), and what is parked.
Where it stands on 2026-09-29: the page is the one results page; phases A
to D, E1 and E2 are done; the result table has joined the page, and §2's
counts and §1's badges read §1.2's cells.

The history, with the user's words and every falsified pin, is
[`worklog/worklog_2026_09.md`](worklog/worklog_2026_09.md), under the
same headings this section had. Code comments cite it by those names:

| cited as | now |
| --- | --- |
| `status.md §2.7 phase A` … `phase D`, `phase B1`, `phase B2`, `E1` | the worklog, same heading |
| `status.md §2.7 E` (the bridge model, decisions 1–4) | `design/overview.md` §3; the original text in the worklog |
| `status.md §2.7 finding 2` (the rendering machine's answer) | `design/overview.md` §4 |
| `status.md §2.7 finding 1`, `finding 3`, `finding 4` | the worklog, "Found while checking" |
| `status.md §2.6 step N` | `design/overview.md` §6.2 (steps 0 and 1 done) |
| `status.md §2.7` (anything else) | `design/overview.md`, then the worklog |


---

## 3. M2 — invariants and contracts

Formalize artifact invariants, contracts, expectations, and mechanism, so
current checks and future bindings (Java, Rust, …) are consistent.

**Centralization target** (agreed 2026-08-12; mechanism moved to `base/`
2026-08-14, user-directed): the mechanism vocabulary — identity,
catalogue, `binding_decl` payload — lives in `base/` as working code the
lowering reads, while what each claim checks stays with the agreement
layer. A project declares its mechanism per binding; the lowering derives
the concrete checking from claim × mechanism.

**Constraint**: M2 is structural reorganization and dispatch. The
existing checking and tests must stay green throughout — the
hand-written per-project binding tables produce the same firings as the
templated ones.

Steps 1–3 are done (mechanism vocabulary reunited in `base/`, the input
template, mechanism as a derivation axis — each pinned; details in
[`worklog/worklog_2026_08.md`](worklog/worklog_2026_08.md)). The rest:

4. [ ] **Typed mechanism payload — the DECLARATION**
   ([`design/agreement/mechanism.md`](design/agreement/mechanism.md)).
   A project declares its binding as ONE flat typed record —
   `binding_decl = { mechanism; c_api; native; coupling; surface_path }`.
   Universal and mandatory: it is what claim selection reads, so every
   project declares it regardless of how it builds. tiny declares
   (2026-08-13). **Remaining**: sqlite/z3/llvm declare theirs, and the
   wiring — `pr_binding_decls` on `project_run`.
   ⚠ Related open bug: a project can declare its mechanism in TWO places
   and pass 2 reads one ([`project/issues.md`](project/issues.md) §2).
5. [ ] **Build as a separate stage** (split from the payload 2026-08-15,
   user) — how to build is its own datatype:
   `Canary_binding_templates.build_recipe`
   (`Dune_targets` / `Verify_product` / `Raw`), derived by
   `recipe_of_decl`. `Raw` = the project's own command, respected as-is;
   translating external raw commands into templates is DEFERRED, not a
   to-do. tiny done 2026-08-15, byte-equal to the former literals.
   **Remaining**: the raw-override warning; delete `mi_artifact_shape`
   prose.
6. [ ] **Claim registry unification** — one statement per claim
   (invariant as a FALSIFIER, tool-based inputs, evidence kind, firing
   derived from mechanism × provision); the per-project binding tables
   converge onto it and get deleted.
   **Not descopable for the paper** (user, 2026-08-26): the runner side
   works and landing a project is cheap, but what a landing *checks* is
   still per-project tables, and no PR has been driven off a checker.
   Growing the roster without this adds rows, not claims. Stage 2 of
   [`plan.md` §4](plan.md)'s delivery pipeline.
   **Coverage** (2026-09-02, and see §1 for today's counts): claims fire
   at `Build_binding` / `Probe_binding`, plus `Build_lib` for the
   declaration comparisons. Declared but unwired: `Probe_lib`,
   `Build_app`/`Probe_app`, `Scan_sources`, and the
   fetch/configure/install/publish actions. Cffi and Dynlink, and the
   Rust/Java/Cpp/CSharp languages, have no cells yet.
7. [ ] **Agreement wiring gaps** — `soname_matches_requirement` under
   OCaml is unpredicted in tiny (the same fact the claim reports as
   `not_applicable` for a compiled-stub archive); `symbol_orphan`'s build
   failure has no claim. Closes inside step 6.
8. [ ] **Richer inspectors** — L1b/L2/L4 fields declared, no inspectors.
   Each needs: inspector → predict closure → binding rows.
9. [ ] **Fault tags ↔ claims sync** — `sym_missing`, `api_drop`,
   `behavior`, `abi_soname`, `sym_version`, `type_arity`, `api_repack`,
   `api_add`. Sync with SSOT when stable.
10. [ ] **Canonical naming settle** — tentative scheme → final; clean
    `Sc.`-prefixed IDs; provision-aware names for real projects.
11. [ ] **Pre/post-checking picture** (user 2026-08-12; moved from M1).
    The original ask was pre + post checking for ALL actions in slow
    mode. Today: `check_pre` is the automatic dependency check,
    `check_post` the per-action postcondition (`default_check_post` via
    `marker_of_action`, overridable), and `pin_check_post` is a
    `check_post` OVERRIDE rather than a new mechanism. **To confirm**:
    whether slow mode needs anything beyond today's default-marker table
    plus per-action overrides.
    ⚠ This is the same closure boundary §2.1 and
    [`design/action_model.md`](design/action_model.md) §§4–5 describe.
12. [ ] **Attribution — from "which check failed" to "who is to blame"**
    (2026-09-03). What EXISTS: which claim confirmed a failure is
    persisted in the verdict marker (pinned by
    `compat.by_agreement_attribution`), and `mismatch_direction_of`
    computes Forward/Backward per scenario. What does NOT: any mapping
    from a failure to a responsible PARTY. `Canary_detect.finding` is
    still `errored? / output_present?`. Two steps, in order:
    - **(a)** `Canary_detect.finding` carries what the registry already
      knows — the claim, its category, its source. A record change plus
      filling it from the row; the transport and call site exist.
    - **(b)** type the sources beside `Intrinsic | Added`, with the
      blamed party a function of the source.

    **Scope guard** (user, 2026-09-03): this is NOT a general fault
    localizer. The merit claimed is integration — carrying a world's
    derivation far enough to name a party — not per-artifact strictness,
    where existing checkers are already stronger. A per-artifact
    localizer puts us back in competition with the FFI checkers, which is
    a different paper.

**Deferred, not M2**: `ax_follows` derived from the action catalogue
(`Build_binding` consumes `Lib`, so a binding naturally follows the
lib's version — derive from `Follows_input`); build-config as an axis
(`as_config` placeholder on `action_sig`).

---

## 4. Source provisioning — what is still open

Built behaviour is [pass 1](design/enumeration/stage1_declare_spec.md)
(what a declared repo becomes, why not submodules, partial vs shallow)
and [pass 6](design/enumeration/stage6_realize_steps.md) §3b–3c (an
unread fetch is not realized; a fetch prepares once and ensures per
world). Not done:

- **Pass 6 receives commands, not the world.** `derive_steps` takes a
  `runner_spec`, so a step cannot be gated on a provision — which is why
  "don't realize a fetch nothing consumes" is decided from the step list
  a pass after `source_is_read` already asked the same question during
  enumeration. Threading the assignment through is what demand-driven
  derivation needs, and it is the same missing thread as the two
  dependency relations. Measured costs: the scenario id is the cache key,
  so renamed worlds re-run cold (the cheap all-`Fetched` ones), and
  `z3.dispatch_reads_source_placement` asserts over every assignment
  including the non-building baseline.
- **`prepare` as a dispatched action** rather than a guard inside the
  fetch command — the structural half of the same gap.
- **Caching opam on CI** — the measured dominant cost of a job
  ([`project/issues.md`](project/issues.md) §2). Caching the contrib tree
  is a distant second and should be keyed by repository, not (repo, ref).
- **Validating a declared source ref without fetching it** —
  `git ls-remote`, 1.1s, filed beside `spec-check --probe-pm` in
  [`design/platform.md`](design/platform.md) §7.

---

## 5. Design directions (pending more cases)

- **Checks as actions — `[Pre; Action; Post]`** (user, 2026-08-18,
  compiler perspective): promote the pre/post checks from step payloads
  to FIRST-CLASS ACTIONS, so the enumeration emits triples and the runner
  interprets checks exactly as commands, uniform warm-mask fingerprinting
  included. Payoff: the firing table becomes a property of the
  enumeration — every cell IS an action in the graph, and the coverage
  pin becomes an enumeration invariant.
  **This is the same closure boundary as §2.1 and step 11**, and
  [`design/action_model.md`](design/action_model.md) records what is cheap
  (`check_post` is already file tests plus one shell command) versus what
  is not (expectation evaluation parses `inspect.json` and drives the
  comparators), plus the one constraint: a check's predicate and its
  rendering must come from the SAME constructor, never two hand-written
  forms. That doc's §7 also argues this item and the `probe_lib` umbrella
  are ONE design rather than two, and its §9 sequences both behind a
  single locator vocabulary.
- **Action/artifact property unification** — `build_deps_of`,
  `ax_follows`, `ax_runtime`, `c_runtime`/`cxx_abi` and probe location
  all sit at the action↔artifact boundary.
- **Enumeration ↔ configuration split — config as dependency resolving**
  (user, 2026-08-16): raw enumeration = the full product over
  artifact-kind universes with only uniform kind-level dependency rules
  (Built-lib↔source channel coupling, binding↔lib, app↔binding),
  repo-agnostic. Configurability = the CONSTRAINT layer: express today's
  hardwired matchers as declared per-project constraints and
  config-selected constraint sets over (artifact × provision × version ×
  repo) placements, with `version_mode` growing from
  Lockstep/Independent into a matcher parameter — so canary's config
  becomes a special case of general dependency resolving, and future
  complex dependencies (ranges, conflicts, multi-repo sources) plug into
  the same machinery instead of new filter code. Enabling step:
  multi-source artifact identity, `status_project.md` §3.

---

## 6. Docs

- [ ] **Regenerate `tiny.md`** — the current doc is tiny1-era; rewrite
  for the tiny-factory / tiny1 / tiny-full split with canonical naming.
- [ ] **`backlog.md` audit** — cross-reference with this file; retire
  closed items.
