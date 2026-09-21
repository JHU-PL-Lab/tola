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

**The agreement layer: 13 implemented claims, 8 landed** — landed
meaning a real project's run decided `holds` or `violated`, which is the
only evidence a check works. Plus **12 candidates**: named, classified,
no evaluator. The live answers are `canary checks --landing` and
`canary checks --firing`; the docs maintain no second catalogue.

**The Agreement overview is the reference** (2026-09-17, user). One row
per (agreement × firing pattern), carrying the claim's kind, where its
code is, the languages and mechanisms that carry it, the object format
it ranges over, its target artifacts, and the action grid marking where
the rule RAN against where the check FIRES. `make view` renders it above
the result matrix, of which it is the template. Layout and row order:
[`design/matrix.md`](design/matrix.md).

**Three axes describe a claim, and they are independent** — `ag_kind`
(what it asserts: admissibility · promise · quality · preservation · behaviour
· composition), `m_reference` (what the second side is), `ag_rooted_in`
(whose rule, at which action). Two of them shared a field until
2026-09-17. `api_names_present` is the case that forces them apart: an
admissibility claim one of whose members is a declaration.

**Two harnesses check the table itself, and the table says so**
(2026-09-17, surfaced 2026-09-21). `row_rules` holds the laws relating
two cells of one row — five today, as data, enforced by
`agreements.rows_obey_their_own_laws`, so a rule added to the list needs
no test edit. Beside it, the saturation grid asks what no row can: is
any (mechanism × object format) cell unwatched?

Current result, carried as a one-line verdict above the table in BOTH
views (it used to print only in the terminal, so the page the table is
read in never said whether it had been checked):

> `checked: 5 laws, every row obeys them · no unwatched mechanism × format cell`

The verdict is pinned to the page and pinned to AGREE with what the
audit computes — a page claiming the laws hold beside a failing audit
would be worse than no line at all.

**Tests: 159 project + 113 artifact + 14 PM = 286.** `make canary-test`
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

Four items, in the order they are worth doing.

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
