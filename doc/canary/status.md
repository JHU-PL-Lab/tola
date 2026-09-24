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
only evidence a check works. Plus **13 candidates**: named, classified,
no evaluator. The live answers are `canary checks --landing` and
`canary checks --firing`; the docs maintain no second catalogue.

**The Agreement overview is the reference** (2026-09-17, user). One row
per (agreement × firing pattern), carrying the claim's kind, where its
code is, the languages and mechanisms that carry it, the object format
it ranges over, its target artifacts, and the action grid marking where
the rule RAN against where the check FIRES. It is the template of the
result matrix, and since 2026-09-23 it lives on the overview page
(`canary overview`, `docs/canary/overview.html`; `make view` renders
both), not above the matrix. Layout and row order:
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

**Tests: 163 project + 113 artifact + 14 PM = 290.** `make canary-test`
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

Seven items, in the order they are worth doing. §2.6 is the plan for
merging the overview page into the framework (terminology settled,
derivations next); §2.7 draws recorded runs on its diagrams — phases A
to D landed, and E1 drives and records the first bridge (conf-gmp on
zarith). §2.5 is the forward look
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

### 2.6 Merging the overview page into the framework — step 0 done; step 1 awaits confirmation

*(2026-09-23. The user is on the manuscript; this is the plan for the
spare time, to be taken slowly and confirmed step by step.)*

**The goal** (user): place the framework's actions and agreements on the
layered diagram of `docs/canary/overview.html` (`canary overview`), sync
the terminology, and replace the page's placeholders with code —
**bottom-up**, so neither side's ideas get invented to fit the other's.

**What the page rests on today.** Derived: the cooperation topologies
(from declared provisions and gates), the mechanism variants (from the
mechanism catalogue), the agreement overview (registry plus recorded
runs). **Hand-written placeholders** in `canary_topology.ml`: 16 nodes,
21 edges, 26 claim sites, and 5 case labels in `canary_overview_page.ml`.
Pins hold the claim sites to the registry; nothing yet computes them.

**Found before proposing anything: three of the page's concepts already
exist in canary under other names.**

1. **A topology row is projects.md §1's dimension triple** —
   native-lib origin × lib discovery × binding origin. That triple is a
   doc table with no type, so `Canary_topology.t` is its first typed
   form, under different names and with values the doc cannot express:
   torch's library comes from opam, which the doc's `System` does not
   cover; the doc has no `pip`; and its `Locator` mixes how the
   *ecosystem* discovers the library with how *canary* locates it.
2. **The artifact layer is `Canary_action.artifact_node`** — a graph
   whose `built_from` edges are derived from the action catalogue, built
   for the M2 graph merge and read today only by two tests.
3. **An edge is an action's `consumes_of_action → produces_of_action`**
   over `artifact_kind`. The page's edges are hand-drawn projections of
   exactly that relation.

**Mismatches a derivation will have to resolve — decisions, not fixes:**

- *Granularity.* The catalogue has one `Binding lang` kind; the page
  splits it into stub / module / surface. The native side already has a
  component list (`api_component`: Headers · Runtime_lib · Link_lib ·
  Pc_file); the binding side has none.
- *The consumer program.* The catalogue says probes produce nothing;
  the page draws the program as the probe's product. canary has three
  words for it — `App` (A_app, Build_app, Probe_app), the probe's
  `example`, and the page's "consumer program".
- *Missing steps.* `fetch_source` and `fetch_binding_source` have no
  edge, so the source nodes have no producer; `Configure`,
  `Scan_sources`, `Build_app` and `Probe_app` are not on the page.
  Adding the first two needs a decision: canary's `provider = Repo`
  sits beside `Sys_pkg` and `Lang_pkg`, which would make a source
  repository a PACKAGE-layer node.
- *"Implemented" on the census means "is a registry row".* Three of
  those thirteen have no evaluator, which the overview colours red two
  sections later.

**Step 0 — terminology. DONE 2026-09-23** (user's decisions; renames
landed in `canary_topology.ml` and `canary_overview_page.ml`):

| term | decision | what changed |
| --- | --- | --- |
| **claim site** | adopted — where on the layered graph a claim sits, a SET of edges | was *placement*, which is base vocabulary for an artifact's provision and version; the test file had used both senses a few hundred lines apart. `claim_site`, `claim_sites`, `cs_*` fields |
| **layer** | kept, collision with the code layers accepted | none; recorded on the type |
| **edge** | kept, meaning left OPEN — the backbone meaning is an action, but an edge only has to point from components to a component | none; recorded on the type. `same_program` is the case that needs the openness: no tool establishes it |
| **consumer program** | adopted — the thing that uses the package, and its counterpart that uses the artifacts; `App` and `example` are too concrete | node ids `app_*` → `consumer_artifact` / `consumer_package` |
| **topology** | kept; examined for the paper below | none |
| **linking lift** | adopted | none yet |

Also removed while there: `L_oracle`, a layer that existed only for the
declaration node — which stopped being a node.

**"Topology" as a paper term — examined (user asked).** The manuscript
does not use the word yet, and it has no order theory for the word to
collide with; its established structural word is *chain*. The sense we
want is standard in systems and networking — the arrangement of
components and their connections — and networking already uses it for a
KIND ("a star topology"), which is exactly how the rows are used ("a
conf-bridged topology"). The risk is the venue: a PL reader's first
meaning is the mathematical one (open sets; the Scott topology of domain
theory), so unqualified *topology* in an OOPSLA/PLDI paper invites the
objection that the word is being used loosely, and would become a real
clash if the paper ever formalizes worlds as an order. **Recommendation:
keep it, never unqualified.** Define it once as the triple — who supplies
the native side, what joins, who supplies the language side — and avoid
topological vocabulary near it (open, continuous, neighbourhood). For
the qualifier, *composition topology* reads better to a PL reviewer than
*cooperation topology*: the draft already says *composition*, and it
describes what happens (someone composes two stacks) instead of
crediting package managers with agency. *PM cooperation* stays fine as
the informal name of the view. Checked and rejected: *configuration*
(build configuration, `./configure`), *wiring* (canary's `app_wiring`),
*pattern* (retired — Pattern A–F), *shape* (already the draft's
informal word, too weak for a defined term).

**Then, one placeholder at a time**, keeping the hand-written version as
the check until the derivation agrees with it:

1. **Actions onto edges.** Type each edge's action as the real
   `Canary_basic.action` family instead of a string, and COMPUTE which
   actions have no edge from the catalogue — the missing-steps list
   above, derived rather than asserted.
2. **Edges from the catalogue.** Generate the artifact-layer edges from
   consumes → produces and diff them against the hand edges. Each
   disagreement is a page error or a catalogue gap, and deciding which
   is the work.
3. **Claim sites from rooting.** Derive each claim's edges from
   `ag_rooted_in.rt_action` and the artifacts it reads, and diff against
   the hand sites. After this the overview's R column and the diagram's
   badges come from one source.
4. **One typed triple.** Reconcile `Canary_topology.t` with projects.md
   §1, in whichever direction step 0 chose.
5. **The linking lift.** Derive the package-linked probe from the
   artifact-linked one — mechanism plus static project facts, with the
   two kinds of customization kept apart (a *name* is static
   information; a *resolution* the package failed to provide is a
   finding) — and give `package_resolution_suffices` an evaluator. The
   first step that changes what a run does.
6. **Recorded run results on the case diagrams** — brought forward by
   the user on 2026-09-23 and planned as §2.7.

### 2.7 Run results on the overview diagrams — A to D landed; E1 landed (conf-gmp on zarith); chains per world, and §1 as a join

*(2026-09-23, user: "the cases in section 2 are generated from
hardcoded code, not from the running result. I wish a feature to
retrofit the concrete running result to that diagram… a bottom-up way
to enhance the overview, which is also guided by the overview.")*

**The goal.** A concrete case on the overview page comes from a recorded
run, not from hand-written labels: the run's result is exported in a
machine-readable form, and the page loads it and draws it on the layered
diagram. The work runs in both directions — the diagram shows which
edges canary records nothing at, and closing those means canary learns
to record what each package-manager BRIDGE actually did.

**What already exists — checked before planning:**

- `canary result --json` already exports, per project × scenario, a
  verdict per action that ran (`fetch_lib: ✓`), an outcome per claim
  column (`build_binding_ocaml_pre:rse: ✓`, `…_pre:dp: no-evid`), an
  artifact summary per `=` column, and the provisioned settings (`lib:
  apt libgmp-dev.2:6.3.0+dfsg`). An action that did not run in a world
  has NO cell, so a world's dead edges come for free, and whether
  `fetch_binding` or `pack_binding` ran settles the direction of the one
  edge that runs both ways.
- The run log carries a `platform` and an `opam_switch` event per step.
- The package-manager drivers already have the queries a bridge record
  needs: opam `list_depexts_cmd` / `version_of_cmd` / `is_installed`,
  apt and brew `installed_version_cmd`, brew `prefix_cmd`.

**Found while checking — each shapes a phase:**

1. `canary result --json` prints `Wrote …matrix.html` on stdout AFTER
   the JSON, so its output does not parse. Any consumer breaks.
2. The installed system-package version on the result page is asked of
   the machine RENDERING the page, at render time
   (`Canary_matrix.sys_pkg_version`, "the matrix's one runtime read") —
   the run never recorded it. It can be newer than what the run saw, and
   a mac run rendered on WSL would show WSL's version. A record of a run
   must carry what the run saw. Same shape as §2.1's platform-blind
   landing report.
3. The JSON flattens typed columns into strings; the typed column
   (action · claim code · artifact) exists inside `Canary_matrix` and is
   what the join should read.
4. A browser blocks `fetch()` on `file://`, so a page loading
   `runs.json` would work on GitHub Pages and show nothing when opened
   locally. Emit the record as `overview_runs.js` setting a global,
   loaded with a `<script src>` — that works in both.

**Phases — each visible on the page, each with a guard:**

- **A. The record.** A run export per (project, scenario): action →
  status (ran ✓ / ✗ / xfail, warm-skipped, did not run), claim → outcome,
  platform, when. Reuse `matrix_of`; fix finding 1. *Guard:* the export
  parses, and its cells equal the matrix's.
- **B1. Every step in the record** (split out after A). A world's steps
  are more than its action columns — sibling probes at other locations,
  the package-linked probe, the inspections — and the matrix reads only
  the columns. The record lists every step the realize pass derives for
  the world, with its tag, its typed action, where it probes and what it
  inspects, and the log's state and time for that tag. *Guard:* each
  row's steps are exactly the realize pass's, typed as the builder typed
  them, each in the state its log line says.
- **B2. The join** (this is §2.6 step 1). Type each edge's action; map
  each step to its edges by its action, its location and the world's
  provision. An edge's status is the statuses of the steps realizing it;
  a claim site's is the outcomes of its claims. *Guard:* every step of
  every recorded world maps to an edge, or is listed as having none.
- **C. The overlay.** The generic diagram is the template and a run is
  drawn on it: edges coloured by status, claim badges by outcome, dead
  edges greyed, node labels from the row's settings. A selector over
  project × scenario; delivered per finding 4. *Guard:* every edge id the
  overlay names exists in the template. At this point the artifact layer
  and the probes light up from real runs, and the package-manager and
  bridge edges say "nothing recorded" — honestly.
- **D. Derived case labels.** Replace the five hand-written case renames
  with labels read from each world's declarations and settings, so the
  cases become real worlds.
- **E. The bridges, one at a time.** For each bridge edge, a
  package-manager-side inspection that RECORDS, at run time, what the
  bridge did in this world (finding 2):
  `resolve_sys` — the installed version, recorded by the run;
  `depends` — the binding package's declared depends;
  `depext` / `conf_probe` — whether the conf package is installed, and
  its depexts; `discover` — what pkg-config answers (`--modversion`,
  `--variable=libdir`); `realize_cap` — the `.pc` file the system package
  ships. **Start with ONE bridge on ONE project — conf-gmp on zarith —
  and generalize only after it lights up.** This is also the evidence the
  claims in [`design/package_gates.md`](design/package_gates.md) need, so
  phase E is the groundwork for `gate_admits_the_world` and
  `discovery_matches_link`.

  *More than recording* (user, 2026-09-23, to consider later): the
  bridges should also be MODELED in the tool layer, not only recorded.
  `tool/` has a driver per package manager — installed, version,
  depexts — and nothing that answers a question about a bridge: the conf
  package's check is never asked, and pkg-config appears only inline in
  commands. A bridge is its own kind of thing (package content that
  exists for cooperation), declared twice already — the binding's
  `pm_gate` and `Canary_topology.bridge` — and queried nowhere. When E
  starts, the recording should be the first consumer of that model, not
  shell written into steps; and a model is also what would let canary
  DRIVE a bridge, e.g. run a conf check against the library a world
  built rather than the system's, which is the built case's point.

  *The model, as decided* (user, 2026-09-23, after reviewing the layered
  PM model in their uncommitted draft `doc/audit/multi_pm.md`):

  1. **A bridge is a thing, and each package manager defines its own
     kinds of it** — opam's conf package and depext field, a Cargo
     `*-sys` crate. It exists for cooperation BETWEEN package managers,
     so it is modeled apart from what every PM has (install, query a
     version) rather than inside one PM's driver. It follows that four of
     `pm_gate`'s six cases describe the `depends` edge TO a bridge — the
     constraint — with the bridge the thing at the other end; the other
     two, `Package_builds_lib` and `Bundled`, are rewrites in the sense
     of decision 3.
  2. **A capability file belongs to the package that ships it, and is a
     source of claims rather than a bridge.** `gmp.pc` is `libgmp-dev`'s;
     an OCaml `META` is the binding package's. Both face the artifacts:
     they record what building against them takes (flags, required
     libraries), which is what a claim can hold them to. The page already
     drew the node in the package layer, but `Canary_topology` treated
     the file as a bridge in three places — the `Capability_file`
     constructor, `join_of` appending it to the bridge list, and
     `character`, which said "+ artifact validation" only when a `.pc`
     was declared, although conf-gmp's own predicate (`pkg-config
     --exists gmp || cc -c test.c`) IS that validation. Fixed in E1
     (below).
  3. **A composition is a template built from the tools, then
     instantiated per project.** The page has both halves already — the
     generic diagram and the recorded worlds. The template should be
     assembled from each package manager's part plus the bridge that
     joins them, and a project instantiates it with its own details,
     including what the draft calls package-specific rewrites: a bundled
     library, a package that builds its own library, a pinned depext, no
     package manager between.
  4. **An edge is an action when the package manager dispatches a
     separate, observable action.** opam builds a conf package as a
     package of its own, so `conf_probe` is an action edge; zarith's
     configure finding GMP runs inside zarith's build and stays
     information. The catch: opam runs the predicate only when it
     installs the conf package, so a switch that already holds conf-gmp
     dispatches nothing in this world. To observe it per world, canary
     has to dispatch it — the tool model's first job.

  Left for later, since neither blocks conf-gmp: *version transport* —
  which version domain a bridge carries across. Today that is one bool
  (`tracks_lib` on the gate, `reaches_lib` on the bridge) and conf-gmp
  carries none; the first bridge that carries one is llvm's
  `conf-llvm-shared {= 19}`. *Topology names* — the draft names a
  composition and `character` names an instance, which is why zarith
  reads "unvalidated against artifacts" where the draft says "+ artifact
  validation". Under decision 3 the template carries the name and the
  instance carries its rewrites and its missing evidence; this needs
  settling when a second template exists.

**Order:** A → B → C gives a working overlay for everything canary
already runs; E then adds bridges one at a time; D can go alongside.
Stop for the user after each phase. The record carries the platform from
the first phase, so the macOS session's runs can be drawn too.

**Phase A landed 2026-09-23: `canary result --json` is the record.**
Per column, its `kind` (action, check, artifact) and the `action`
itself, plus for a check its `stage`, `agreement` and `code`. Per action
cell, the step's `state` — `ran`, `warm`, `blocked` or `unrecorded` —
and for the first two its `verdict` (`pass`, `fail`, `xfail`, with the
confirming `agreements`). Per check cell, the `outcome` label, `null`
when no run evaluated it. `at` on every cell the log dated, and
`recorded_on` on every row: the platform the run logged. The mark stays
in every cell, and a cell missing from a row is an action outside that
world's chain.

It is one reading of the log, not two. The typed state is
`Canary_status.step_state`, and `mark` now renders it, so the page's
glyph and the record's state cannot disagree; `project_matrix` became a
projection of the new `project_log`. Finding 1 turned out to be half the
problem: besides printing after the JSON, the command rewrote the
tracked page, and `result zarith --json` had replaced `matrix.html` with
a two-row table. `--json` now prints the JSON and writes nothing. The
text and markdown views still refresh the page, and with a project
argument they still write a one-project table to the tracked file —
unchanged; whether they should is the user's call.

The guard is `matrix.record_export_is_the_matrix`. It writes a log in
the runner's own line shape over zarith's real scenarios — one script
per step state plus a re-run, a platform that is not this machine's, two
claim outcomes and an inspection — and requires the matrix to read each
back typed and dated, and the printed text to parse and decode to the
same columns and cells. Four deliberate breaks each turned it red: warm
spelled as ran, the renderer's platform, a dropped timestamp, dropped
artifact cells.

One visible change on the result page: a check cell's tooltip names the
step that supplied its outcome, and that is now the most recent step
reporting it rather than the first in list order, so that the step and
the new `at` describe the same line. 69 of 618 tooltips moved; nothing
else on the page did.

The record already says what the table could not. On zarith's built
row, three of the six actions were warm in the last run, and the
`build_binding_ocaml_pre` outcomes date from four hours before it: the
step was warm, and a warm step evaluates nothing. Over all 28 rows on
the day it landed, 67 action cells were warm passes and 73 were passes
that ran — the same ✓ on the page.

**Found during A, for the later phases:**

1. *The matrix never reads the sibling steps.* The logs carry
   `probe_lib_apt` and `probe_lib_staged` (sqlite, llvm, z3),
   `probe_binding_ocaml_opam` (z3 — the step that realizes
   `run_packaged`) and every `…_inspect`, but an action cell is looked up
   by the canonical tag, so the record has none of them. Phase B's
   tag → action map must read them from `project_log`, which keeps them.
2. *`action_of_string` does not invert `string_of_action`* for
   `fetch_binding_source_<lang>` — a zarith column — nor for
   `pack_source`, `pack_headers`, `pack_app` and
   `pack_binding_source_<lang>`. The OCaml half of the join does not
   need it, since `typed_columns` carries the actions, but step tags are
   strings.
3. *An unreached step logs nothing.* When a dependency fails the runner
   marks the dependents skipped in memory only, so the record cannot
   tell "blocked upstream" from "never attempted"; both read
   `unrecorded`. `blocked` means a failed precondition, and no current
   log contains one.
4. *Timestamps have no zone.* They order one machine's lines and say
   nothing across two, which matters the day the mac's records are
   drawn beside WSL's.
5. *Six rows have no platform.* llvm's `latest` world never ran; the
   other five last ran before 2026-08-26, when the event was added.
   Honest, but a re-run is the only fix.
6. *Finding 2 stands.* A system package's version inside a setting is
   still asked of the rendering machine unless the spec pins it; the
   record carries it unchanged, and the encoder's comment says so.

**The plan after A** (the user confirmed the B1/B2 split, 2026-09-23).
Every step already carries a typed action out of the realize pass —
`build_lib_inspect` is `build_lib`, `probe_lib_apt` is `probe_lib` — so
the join parses no tags, and the `action_of_string` gap (item 2 above)
does not matter to it. Three rules shape B2:

- *A probe's edge is its LOCATION.* zarith's fetched-binding worlds
  compile the consumer with `-package zarith` and its built worlds with
  `-I <build tree>`, under one tag, `probe_binding_ocaml`. The
  opam-binding template declares the first `Pm (Lang_pm opam)` and the
  second `Build_tree`, so the typed location already says which consumer
  program each is — `run_packaged` or `run`. It is invisible only
  because a single probe entry keeps the canonical tag, and the step
  record kept the tag and dropped the location. (First read the other
  way round, from the tag, and reported so; corrected on reading the
  template.)
- *An inspection records evidence; it realizes no relation.* It carries
  its parent's action, so without a rule it would colour the parent's
  edge. It feeds claim badges instead.
- *Siblings can land on no edge.* `probe_lib_staged` observes the staged
  copy, which has no observation edge on the page; B2's guard lists it.

Two decisions were open, and the user took both (2026-09-23). **How an
edge names its action:** a small action-family type in `base/`, the
names placeholders to settle later — and more than that, *"the edge in
the diagram can be used to annotate either action, or agreement, or
customized information"*, so an edge's annotation is one of the three
rather than an optional action. **z3:** stays muted; the record reads
the active projects, and the other projects carry enough special cases.

For C: the `.js` record is a per-machine file like `matrix.html` — the
same `_mac` suffix, and a `--platform` render never writes the tracked
copy. The overview page loads whichever exist; the record never goes
inside `overview.html`.

Seen on the way, and for the overlay to show rather than fix: zarith's
built world packs its binding and never probes the package, so
`run_packaged` has no step there — the gap z3 closed with its `_opam`
probe, and the concrete case for §2.6 step 5.

**Phase B1 landed 2026-09-23: every step is in the record.** Each row
now carries `steps`, every step the realize pass derives for the world
and in its order: the `tag`, the `action`, the `location` a probe reads
(`build_tree`, `staged`, `sys_pm:apt`, `ocaml:opam`, `python:pip`), the
step an inspection `inspects`, and the same state, verdict and `at`
fields an action cell has. Over the 28 rows that is 262 steps, 88 of
them inspections.

The step had to learn two things. `Canary_step_model.step` gained
`location` and `inspects`, which the builder sets where it already knew
them: a probe entry's declared location, an inspection's parent. No run
behaves differently, and no warm verdict was invalidated, because the
fingerprint hashes the command, the expectation, the switch, the
platform and the strict flag, and none of those moved.

**The result table had been deriving a different step list from the
runner's.** Its chain came from `Canary_pipeline.actions_of`, which
re-derived from the bare runner spec and skipped `with_declared_facts` —
and the declared binding package is what earns a fetched binding its
stub inspection. The action set came out the same, since an inspection
carries its parent's action, so no table could show the difference. The
first version of this record inherited it — one step short in every
such world — and its write-up called the missing tag history. The
display now goes through the runner's own `steps_of` over a throwaway
workspace (`display_steps_of`), which added the 27 stub inspections the
runs really perform. That path also brought the runner's spec warning
into `canary result`; `derive_steps ~warn:false` keeps a display quiet,
and the run and spec-check still report it.

The record lists today's steps, not the log's tags. A tag the log holds
and no current step has is history and is left out — zarith's
`probe_binding_ocaml_inspect`, from before the template moved its
inspection to the steps that provision the binding (2026-09-15), and
the opam-binding projects' `fetch_source`, from before unread fetches
were pruned. A current step that no run has logged reads `unrecorded`.

The guard is `matrix.record_carries_every_step`, over zarith and sqlite.
Each row's steps must be exactly the ones the RUNNER derives — through
its own call, `steps_of` over the scenario's real context, because a pin
that compared the record with `display_steps_of` compared it with
itself and could not see the gap above — typed as the builder typed
them (a probe's tag is the one derived from its location, an inspection
names a step with its action), each in its own log line's state and
time, with the printed JSON decoding to the same. Five breaks turned it
red: the builder dropping a probe's location, the matrix leaving
inspections out, the encoder garbling a location, the builder not
marking an inspection, and the display derivation skipping the declared
facts again. The phase A pin now shares its fixture
(`Record_fixture`), so the two cannot disagree about what a state is.

**What the typed locations already say, for B2:**

- *The consumer program is readable.* Across the active projects,
  `probe_binding_ocaml` sits at `ocaml:opam` in every world whose
  binding is fetched, and at `build_tree` in every world whose binding
  is built (llvm, zarith) or vendored (tiny-full) — the `run_packaged`
  and `run` edges.
- *torch probes its library at `ocaml:opam`* — the unified case, where
  the language PM supplies the native side. `tag_of_probe_lib_location`
  rejects that location with a `failwith`; torch escapes only because
  it has one lib probe, which keeps the canonical tag. A second entry
  would stop `derive_steps`.
- *sqlite's stdlib Python probe is typed `python:pip`*, while the module
  comes with the interpreter — the page's "no package manager between
  them" case. Its edge is a decision, not a lookup.
- *Two steps have no edge on the page:* ssl's `probe_app_ocaml`, which
  carries no location, and `probe_lib_staged` (sqlite, llvm), which
  observes the staged copy. B2's guard will list both.

**Phase B2 landed 2026-09-23** — B2a in one commit, B2b and B2c in the
next.

*B2a — an edge carries an action family, a claim, or information.*
`Canary_action_family` (`base/`) is an action with its language erased;
the names are placeholders. `eg_action : string option` became a typed
annotation. Sixteen edges carry an `Action`; `same_program` carries an
`Agreement`, the end-to-end candidate `package_resolution_suffices`,
drawn by its code `prs`; the four edges we run nothing at carry `Info`
and say, in italics, what does establish them — packager, depext table,
conf predicate, pkg-config. The page's "Not yet every step" note is now
computed from the catalogue: 10 of its 19 action families have no edge,
where the note used to name two. `topology.graph_matches_the_registry`
now holds what its comment had long claimed, action coverage: every
annotation well-formed, all three kinds in use, a family spelled as its
actions minus the language, and the families without an edge listed.
A headless render showed two of the longer labels clipped by node boxes;
those two now start at their edge's midpoint.

*B2b — every step has a place.* `Canary_topology.place_step`: a step
realizes the edges annotated with its family, narrowed by what the step
and the world say. A binding probe goes to `run_packaged` or `run` by
its location. A lib probe of the staged copy, or of a system copy the
world does not use, has no edge; nor does a library fetched through a
language PM (torch). A binding fetch realizes `depends` only where a
symbolic bridge — a conf package, or a depext bound — is declared. An
inspection is evidence for its parent, and a dummy performs nothing.
Only an `Action` annotation can be realized: an `Info` edge names
someone else's rule, which our step may set off but does not perform.
Every unplaced step carries a typed reason, and
`topology.every_step_has_a_place` lists them over every world the runner
derives, with no log read: configure, fetch_source, scan_sources,
fetch_binding_source and probe_app have no edge; sqlite's stdlib fetch
is a dummy; torch's library fetch comes from a language PM; lib probes
of a staged copy or an unused system copy. It also requires every action
edge on the page to be realized in some world, and both consumer edges
and both `depends` outcomes to occur.

*B2c — the join's result is in the record.* Each row now carries
`edges` — every edge its world realizes, with the steps realizing it —
and `claims`, every placed claim with its check columns' outcomes, so
the overlay draws and computes nothing. zarith's built world realizes
`run` and not `run_packaged`: the unprobed published package, as an
absent edge. Guard: `matrix.record_joins_edges_and_claims`, which
recomputes the edges from the steps and checks each claim against its
cell.

Each of the three guards turned red under deliberate breaks, and the
text and markdown views of `canary result` are still byte-identical to
before phase A.

**Found during B2:**

1. *A declaration that contradicts its command.* The opam-binding
   template's vendored-library world (cairo, libffi, zlib, zstd) keeps
   its lib probe at `Pm (Sys_pm apt)`, while the command probes the
   prebuilt copy. No rule over typed facts can tell that from a
   legitimate probe of an unused system copy — sqlite's `probe_lib_apt`
   in its built worlds is one — so those four read as
   `unused_system_copy`, and the pin's comment says so. The fix is a
   decision: `Canary_store.location` has no constructor for a supplied
   copy at a path, so either `base/` gains one or the prebuilt is
   declared a build tree.
2. *A vendored world still fetches the system package.* The same worlds
   run `apt-get install libzstd-dev` beside the prebuilt they use, so
   the system package's edges are realized there too. The rule follows
   what the fetch asked — its provider — not where the world's library
   came from; the first cut read the world's provision and called the
   fetch a supplied copy.

**Phase C landed 2026-09-23: the page draws recorded worlds.** The user
asked to keep the hand-drawn cases and to show the recorded ones with
separate buttons, so the running worlds can be compared with the
proposed ones by switching — not literally side by side. §2.1 of the
overview now has a button for each case that has a recorded counterpart,
a menu of every recorded world, and one template diagram the script
paints: each edge by what the steps placed on it did (ran, warm,
expected failure, failed, blocked, never logged), an action edge the
world does not realize faint, someone else's rule dotted, each claim
badge by its claims' outcomes, and the world's placements under the node
names. A link of the form `overview.html#rec=<view>` opens a world.

Nothing is decided in the page. `Canary_overview_runs` computes a view
per world and binding language — 39 on this machine — and writes them to
`docs/canary/overview_runs.js`, one file per machine (`_mac` on macOS);
the page loads each machine's file with a plain script tag and applies
the words. A `--platform` render writes the file under `_out/` instead.
The page holds no run state of its own, and its lede and footer now say
where the one exception comes from.

The counterparts, found by typed predicates over each project's worlds:
conf → zarith's fetched world; built → sqlite's built-library world;
unified → torch; none → sqlite's Python side. Two things the comparison
already shows:

- *The built case's recorded world is sqlite, not the llvm its text
  names* — no llvm world builds the library under a fetched, gated
  binding. The shape is the same (conf-sqlite3 checks the system copy
  while the world uses its own build); the case's text may want updating.
- *The wheel case has no counterpart* while z3 is muted, so its button is
  not drawn.

Guards: `overview.recorded_runs_are_an_overlay` — the file parses as the
script expects; every view names every template edge with a known word,
and only template nodes; each case resolves to a view of its project in
its language; the facts the cases are about hold (the conf world's
consumer is package-linked, torch has no system side, the built world
builds its library and still resolves the bridge, sqlite's Python view
is not painted by its OCaml fetch); the page carries the template, the
buttons and the script tags; a hypothetical render stays out of `docs/`.
And `overview.overlay_words_rank_worst_first` for the words themselves.
Both turned red under deliberate breaks. Checked in a headless render:
the conf, torch and sqlite-Python views draw as described.

What C does not do yet: node labels are the result table's placement
strings (`B:d`, `apt libgmp-dev.2:6.3.0+dfsg`), not the case diagrams'
names — that is phase D; and the four bridge edges stay dotted until
phase E records what each bridge did.

**Phase D landed 2026-09-23: a recorded world is named, and set beside
its case.** The plan said D would *replace* the hand-written case
labels; the user asked to keep the hand-drawn cases until they have
compared, so D names the RECORDED views instead and leaves §2 as it was
— its five panels are byte-identical to before.

Each view now names its nodes from two sources, and says which: what the
run RECORDED — the inspections its own steps wrote, so the library by
its soname, the stub by its archive, the binding by its modules — and,
failing that, what the project DECLARES — the platform's system PM, the
providers' package names, the package gate (with its constraint:
`conf-llvm-shared {= 19}`, `depext: libtorch >= 2.1.0 & < 2.2.0`), the
binding declaration's soname, headers, archive and surface file, and the
source repositories. Declared names are drawn in italics. A node no
realized edge touches and no evidence names is dimmed — and every node a
hand-drawn case hides is dimmed in its recorded counterpart. Under the
diagram, a table sets the case's hand-drawn names beside the recorded
ones, node by node. The case records became data (`ca_names`,
`ca_hidden`, …) rather than closures, so a comparison could read them.

**What the comparison says**, one line per kind of difference — for the
user to judge, not for canary to fix:

- *A drawing looks out of date.* zarith's stub is drawn
  `zarith_stubs.a`; the declaration and the recorded inspection both say
  `libzarith.a`. torch's binding source is drawn `ocaml-torch.git`; the
  repository is `torch.git` now.
- *A declaration looks worth reviewing.* sqlite declares its system
  package as `sqlite3` — on Debian the command-line tool — where the
  drawing says `libsqlite3-0`; and its stdlib binding is declared through
  a pip provider (glossed "stdlib, pip no-op") where the drawing says
  "the interpreter build". The drawing and the declaration also disagree
  on which Python node is the file and which is `dir(sqlite3)`.
- *Only the format differs.* The depext bound; `zarith.cmxa` against
  `zarith (4 modules)`; torch's library drawn as `libtorch.so`, recorded
  as its soname `libtorch_cpu.so`.
- *The built case is another project* (llvm drawn, sqlite recorded), so
  it agrees on one node.

Guard: `overview.recorded_views_are_named` — every name is on a template
node and says its source; what a case hides its counterpart dims, what a
case greys its counterpart does not realize; and the agreements are a
RATCHET — the 14 (case, node) pairs where the derived name equals the
drawn one today (17 on Linux, with the system package names), which may
grow when a drawing or a derivation is corrected and must not quietly
shrink. Red under a garbled bridge label and under disabled dimming.
Still generic: the consumer programs and the capability file, which
nothing declares by name.

**Phase E1 landed 2026-09-23: conf-gmp on zarith — the bridge modeled,
driven, and recorded.** One bridge on one project, as planned, in three
commits that each carry their own guards.

*A bridge is a thing in base* (decisions 1 and 2). `Canary_bridge.t` is a
variant per package manager — opam's conf package and depext field —
kept apart from the drivers' common components, and `of_gate` derives
the bridge a package gate names, so nothing restates it. The topology's
own bridge type is gone: a join carries the bridge plus whether its
constraint reaches the library (the version-transport question, deferred
and kept where it was), and a declared capability file rides beside the
join rather than inside it. The three places the decision note named are
fixed, and the visible effect is one column: zarith, ssl, llvm and sqlite
now read "symbolic package bridge + artifact validation", which is the
name the draft gives this composition, because the validation is the
bridge's own check.

*The bridge is driven* (decision 4). `Canary_bridge_driver` in `tool/`
is the model: which questions a conf package answers, and how to
dispatch its check in this world. It runs the predicate's own pkg-config
invocation, chosen for this platform by evaluating the predicate's opam
filters against `opam var` — conf-zlib puts Windows-only `--personality`
flags after `pkg-config`, and a parse that ignored filters would have run
them. `canary/scripts/inspect_bridge.py` writes the record and exits with
the verdict: 0 the check holds, 1 it does not, 3 canary cannot dispatch
it (conf-llvm-shared's predicate is a script, and is recorded as such,
never as holding). Every package-manager question is a template from the
drivers; opam's `show_field_cmd` and `var_cmd` and apt's and brew's
`owner_of_file_cmd` are new. A step carries the bridge it drives
(`step.bridge`), and `runner_spec.bridges` asks for one beside the
install of a fetched binding; it takes the install's action and none of
its claims. zarith is the one project wired, from the gate it already
declares: its fetched world gains `fetch_binding_ocaml_bridge`, and its
zarith-no-conf world, which bypasses the bridge, gains nothing.
`conf_probe` is an action edge now, realized by that step alone.

*The overview reads the record.* It names the bridge, the system package
and the capability file from what the run recorded, puts a short line
under each, and says in one sentence per edge what was seen. The
relations canary does not perform — the depext table, the packager's
file, pkg-config's answer — read `observed` where a run recorded them and
`not_ours` where none did.

What the real run recorded (WSL): conf-gmp 5 is installed and maps to
libgmp-dev, installed at 2:6.3.0+dfsg-2ubuntu6.1; zarith's depends names
conf-gmp; `pkg-config --print-errors --exists gmp` holds; `gmp.pc` (gmp
6.3.0, libdir `/usr/lib/x86_64-linux-gnu`) is shipped by libgmp-dev. The
conf case's capability file is now named by the run, and the name agrees
with the drawing. Checked in a headless render.

Guards: `steps.bridge_step_drives_the_declared_bridge` (the derivation,
the bypass, and the rollout as a list — today `zarith conf-gmp`);
`topology.every_step_has_a_place` (`conf_probe` is the bridge step's and
no install's); `matrix.record_carries_every_step` (the `bridge` field);
`overview.bridge_record_is_read` (the reader, on a fixture with exactly
the fields the framework test holds the script to write); the overlay pin
(the new word, only on someone else's relation, always with a sentence);
six artifact-test cases on fixtures — a fixture `.pc` on an isolated
pkg-config path, so they do not depend on what a machine has installed;
three pm-test cases that check answers rather than exit codes. Each new
pin was turned red by a deliberate break before it was trusted.

Open, found on the way — none of them fixed here:

- *The record is evidence nothing reads yet.* It carries both sides of
  four claims: the check held in this world (`gate_admits_the_world`);
  pkg-config's libdir against the library the binding links
  (`discovery_matches_link`); the depext against the system package the
  world provisions; the package's declared depends against the gate the
  project declares (`package_gates.md` §7.2). The first agreement on
  bridge evidence is the natural E2.
- *The system package's version comes from the run only on the
  overview*, and only where a bridge is recorded. The result page still
  asks the rendering machine (finding 2).
- *A bypassed bridge was still named* — FIXED the same day (user: "looks
  a bug"). A declaration names a node only in a world that uses what it
  declares: the gate and the binding row's package describe the upstream
  package, which a world installs only when it fetches the binding. So
  zarith's built world names no bridge and names its package
  `zarith-no-conf`, the one it publishes; llvm's built worlds name
  neither. The sibling was the package node, wrong the same way. Pinned
  in `overview.recorded_views_are_named`, which went red with the fix
  reverted.
- *Driving against the world's own library* — running the check with
  `PKG_CONFIG_PATH` at a library the world built — is what the built
  case is about, and it is not done: its counterpart, sqlite, has no
  bridge wired.
- *Not run on macOS*: brew's owner query and its pm-test case; the
  predicate parse was checked with macOS variables fixed by hand only.
- *Generalizing needs a routing fix first.* cairo, libffi, zlib and zstd
  still keep their gates on the template's record (`project/issues.md`
  §2). sqlite and ssl route theirs and use pkg-config predicates.
  llvm's would exit 3, because its predicate is a script, and torch's
  depext has no check.

*After E1 — the user's direction (2026-09-23).*

- **To-do, once enough bridges are modeled: the bridge check becomes an
  action of its own**, run as a PRECURSOR — before the binding is fetched
  or built, asking whether this world admits the gate — instead of a
  sibling after the install that carries the install's action. That opam
  also runs the check while installing is not a problem.
- **The pipeline is: canary runs → records → the reading side parses →
  the layered diagram renders.** Canary triggers the package-manager
  actions, bridge ones included, so canary records them — in the action
  log or in a log of their own — and the page is drawn from what was
  recorded, never from anything else. Where zarith stands: the bridge
  step writes its record, and the overview parses it and renders it (the
  dotted accent edges, and the sentences under the diagram). The gaps,
  which are one gap seen three ways:
  (a) a bridge is recorded only where a project asks for it (zarith),
  not wherever canary performs a package-manager action that goes
  through one — which is why generalizing looked like per-project
  routing;
  (b) what the package manager does INSIDE an install is not recorded —
  `opam install zarith` prints `∗ installed conf-gmp.5` when it built the
  bridge and ran its check in this run, and nothing reads that output;
  (c) no agreement reads the record.
- **The layered diagram is the structure** for the artifact and package
  layers and for the logged results; the agreement registry is
  discussed against it.

*Placeholders — the method (user, 2026-09-23).* Bottom-up: take the
checking components that are easy to record, and mark the ones canary
cannot retrieve. A registry can carry placeholders, and so can the
action graph. Both are drawn as a special marker, in the detailed log
and on the diagram, so "not implemented yet" is visible rather than
blank.

- **Placeholder REGISTRY — done the same day.** Of the four bridge
  checks, only `discovery_matches_link` was in the registry's candidate
  table. `package_gates.md` §6 had proposed three more and never entered
  them. They are candidates now — `gate_admits_the_world`,
  `declared_gate_matches_package`, `gate_bounds_the_library` — along
  with the new `depext_names_the_provided_package`, with claim sites on
  the bridge edges. `discovery_matches_link`'s "needs" now says that
  pkg-config's answer is recorded where a bridge is. `components.md`
  §5.7 explains why the bridge's claims exist. On the diagram, an edge
  whose claims are all placeholders gets a hollow, dashed badge, and the
  census reads 30 claims (13 implemented, 17 candidates). The bridge box
  moved left, so its `depends` edge, which was 22px long with the badge
  under the boxes, can be read. Pinned by
  `overview.placeholders_are_drawn_as_such`.
- **Placeholder ACTIONS — landed the same day** (user: "I like the
  placeholder steps"). `Canary_pm_action` in `base/` says, per package
  manager, what goes unrecorded inside an install. The pipeline derives
  it for every project from the providers the artifact table names — it
  is knowledge about the package manager, not about a project — and
  `derive_steps` adds one placeholder step per piece beside each
  non-dummy fetch (`fetch_lib_apt_policy`,
  `fetch_binding_ocaml_opam_{plan,solver,build}`). A placeholder does
  no work, writes its marker, and logs a `placeholder` event saying what
  it stands for and why — `not_yet` (and how it could be recorded) or
  `out_of_reach` (and why not). The run record carries it, and it sits
  on the edges it stands for. On the overview it shows as a marker:
  accent while it could be recorded, grey when it is out of reach. An
  action edge nothing of canary's performs, but a package manager did
  inside one of our actions, reads `inside` rather than `absent`. That
  is new information: in a world that fetches its binding, opam compiled
  the stub and linked the module, and the diagram used to say those
  relations did not exist. Not a dummy — a dummy says there is nothing
  to do. Pinned by `steps.placeholders_stand_for_what_pms_do` (red with
  the not-beside-a-dummy guard removed) and the overlay pin. The
  inventory it was built from, as the user saw it before the pick:

  | edge | what the package manager does | can canary record it? |
  | --- | --- | --- |
  | `resolve_sys` | apt picks a candidate version (pins, priorities) | yes, easily: `apt-cache policy` |
  | `resolve_lang` | opam's solver picks every version | the plan, easily (opam prints it); the reasoning, no — opam reports a solution, not why |
  | `depends` / `conf_probe` | opam builds the bridge in this run, running its check | yes, easily: the install prints `∗ installed conf-gmp.5` |
  | `depext` | opam would install the system package | not exercised: `--assume-depexts` |
  | `realize_cap` | what the capability file declares | yes, easily: `pkg-config --cflags --libs` |
  | `discover` | pkg-config inside the package's own build | no, as things stand: it happens inside opam's build, whose log opam deletes on success |
  | `install_lang` | the binding's compile inside the install | same as `discover` |

  The `depext` row got no placeholder — the mapping is recorded where a
  bridge is, and opam never installs a depext here. The easy rows are the
  next increments: each becomes a real record, and its placeholder leaves
  the catalogue in the same change.
- **Canary's own three tables, drawn on the overview — landed the same
  day** (user: "the whole chain needs two rows (two pm) from the PM-solo
  table, and one binding table … a pm-solo table, pm-coop table which
  canary covers … you can refer the doc, and make our own tables").
  §5 of the overview is now four derived tables. **5.1 PM solo**
  (`Canary_pm_solo`, `tool/`): one row per package manager canary has a
  driver for. Scope and store are read from the drivers' `properties`,
  which had no reader before; bridge kinds come from
  `Canary_bridge.kinds_of_pm` and the unseen pieces from
  `Canary_pm_action`, with three prose columns written against the
  draft's Table 1. **5.2 Binding mechanisms**: the mechanism catalogue,
  row for row, with the projects that bind through each by pass 2.
  **5.3 Cooperation**: `Canary_topology.coop` is a typed kind with a
  catalogue whose columns follow the draft's Table 3, and `character`
  now reads it, so the names and the rows cannot disagree. Only
  instantiated kinds are drawn; the other five are listed as classified
  and not yet covered. **5.4 The chains canary runs**: one row per
  project, language and native provision, naming the one mechanism, the
  two sides and the cooperation — the user's composition, made visible.
  It replaced the per-shape topology table. Pinned by
  `overview.tables_list_what_canary_covers`, red with the pip row
  relabelled. Two findings the tables make visible rather than hide:
  libffi reads `cstubs` because its declared `Ctypes` is not routed
  (`project/issues.md` §2), and sqlite's CPython stdlib binding reads
  "pip ↔ apt" because its provider is declared as pip.
- **Cooperation per world, in the record, in applicability, and on the
  diagram — landed the same day** (user: "yes, please go ahead", to the
  four items the tables left open). Cooperation is now derived per
  WORLD, not per project, and beside firing rather than in pass 2,
  because it needs a world (the membership rule).
  `Canary_topology.topology_of_world` reads both sides from the world's
  own placements, and the declared gate only where the world installs
  the package that declares it — so zarith's built world reads
  "artifact-centric, no bridge" and llvm's dev worlds read "local". The
  run record carries it: each row has one chain per binding language
  (mechanism, both sides, cooperation), plus what that chain does not
  have (`gone`) and which placed claims apply to it
  (`applicable_claims`). Claim applicability reads the chain: a claim
  applies where one of its edges exists (`claim_applies`). So the four
  bridge claims apply to zarith's fetched world and not to its built
  one, and the recorded view stops drawing what a chain lacks. That is
  a different mark from dimming: a dimmed node exists and the run did
  not touch it, while a node that is not drawn does not exist in that
  chain. §1 now draws the chain as a JOIN — one diagram, with a
  mechanism bar for the artifact band and a cooperation bar for the
  package band, and a line saying which projects canary runs the pair
  for. It replaces five per-mechanism panels, which could only ever
  show one band.

  The package band is one rule per node over a topology (`band_hidden`,
  `band_dead`), and a kind's band is what none of its worlds has
  (`coop_bands`). Two rules in the first draft were wrong, and a guard
  caught each one before anyone read the result. The binding's source
  existed only where canary builds the binding — but the hand-drawn conf
  case draws Zarith.git, because opam compiles it inside the install.
  The staged copy existed only where the library is Installed — but
  llvm's recorded Built worlds stage it. Where the declaration cannot
  decide, the band does not hide: a join canary cannot read keeps its
  bridge, and a vendored side keeps its source. A placeholder stands
  only on edges the chain has — torch's opam build finds libtorch
  through opam, not through a capability file — while a step that ran
  is never filtered. `publishes_of_world` (the wrapper declaration) is
  now the one answer to "does this world publish its binding", and a
  pin holds it to the pack steps. The "built" case's recorded
  counterpart is now sqlite's installed world, which has the staged copy
  the drawing shows.

  Pinned by `overview.package_band_is_one_cooperation` (the rules
  reproduce all five hand-drawn cases exactly on the band's nodes),
  `overview.chain_absence_is_never_recorded` (over every recorded view,
  nothing a chain lacks was realized, observed, placeheld or badged, and
  no decided claim was dropped) and
  `matrix.record_carries_each_worlds_chain`. Each was falsified before
  it was trusted.

  Left open that day: a kind's band is an intersection over its worlds,
  and those worlds can differ by package manager. "Absorbed" covers an
  opam package that builds from source and pip wheels that do not, so
  the pair (ctypes, absorbed) drew a binding source that no wheel has.
  The package managers became a choice the next day (below), which
  closes it.
- **The chain chosen from its parts — landed 2026-09-24** (user: "can
  we also make the pm itself as the choice? … all are shown as buttons
  in one place. If we click a binding mechanism, the dependent pms are
  also shown as clicked. if we click a concrete package case, the pms
  and binding-mechanism it uses are also shown as clicked", with the
  concrete name under a node "in the next line in a different font").
  §1 now has one panel of buttons above its one diagram: the native
  side's package managers (the system ones, by the drivers' own scope),
  the language side's, the binding mechanisms, the cooperation kinds,
  and the 28 chains canary runs. Those chains are the rows of §5.4, which
  is now rendered from the same list and links each row to its chain in
  §1. A mechanism also chooses the package manager that ships its
  language's bindings — opam for OCaml, pip for Python, read from the
  chains rather than written down. A concrete chain chooses its two
  package managers, its mechanism and its cooperation, and writes under
  each generic label what its project declares the node is: libgmp-dev,
  conf-gmp, Zarith.git, libzarith.a. A package manager chosen on its own
  names only its own node.

  Choosing package managers NARROWS a cooperation's band to the chains
  that have them (`Canary_topology.band_over`), so absorbed over pip has
  no binding source and ctypes + absorbed now draws the wheel. A choice
  that no chain has falls back to the nearest one that some chain has —
  the native side's package manager is let go first — and the page says
  what it let go. Everything a choice draws is computed in
  `Canary_overview_join` and embedded as data; the page's script keeps
  the state and looks the answers up. The names come from declarations,
  never from a run: §1 is what can exist and what canary runs, and a
  recorded world is §2.1's.

  Pinned by `overview.chain_choices_draw_one_chain` (the chains are
  §5.4's rows and their own worlds; the dependent package managers; the
  narrowing; every chain picked out by the four choices it lights; the
  page's buttons, name slots, embedded data and default drawing).
  Falsified by a band that ignores the language side's package manager
  and by dependent package managers that ignore the language. The click
  behaviour itself was checked with a scripted sequence in headless
  Chromium, which is not a pin.
- **§1 absorbs §2 and §2.1 — landed the same day** (user: "Given the
  section 1 includes both the generic chain and the concrete examples,
  shall we remove the diagrams in ss2 and ss 2.1. Some legends and notes
  for diagrams in ss 2 and 2.1 are nice, so please merged them into the
  ss 1's diagram rather than just deleting them"; with four smaller asks
  in the same message). The page now has ONE diagram. The hand-drawn
  cases of §2 are no longer drawn: each one's prose, and what it said
  about single nodes, is the note on the cooperation it illustrates
  (`ca_coop`, which a pin holds to its counterpart world's cooperation).
  Their names, hidden nodes and greyed edges stay in the page module as
  the ORACLE the pins still hold the derivations to. §2.1's recorded
  comparison became part of choosing a package: §1 draws that package's
  recorded run, with a selector where it has several recorded worlds,
  and brings §2.1's key and its lists (what the run recorded around the
  bridge, what the package managers did unseen, the claims, the steps
  with no edge) under the diagram. A name under a node is upright where
  the run recorded it and italic where only the project declares it, and
  a third line gives where the run placed the artifact. Each recorded
  view now carries the id of the package it realizes (`vw_case`, spelled
  by `Canary_topology.chain_id`), which is how a package finds its
  worlds. `#rec=<view>` still links a world. The hand-versus-recorded
  table went — the user had compared. The sections are renumbered:
  agreement overview §2, census §3, the tables §4.

  The four smaller asks: the mechanisms are grouped by language, so
  cstubs and dynlink sit together (in §4.2 too); each cooperation button
  names its package managers ("opam ↔ apt", "opam · pip", "no PM"); the
  concrete row is "package in canary"; and clicking any button but a
  package's outlines the package nodes it is about — a native-side PM its
  native package, a language-side PM its binding package (and, for opam,
  the bridge package, since a conf package is an opam package), a
  mechanism the binding package, a cooperation the package nodes its band
  keeps (`Canary_overview_join.related`).

  Pinned by `overview.chain_choices_draw_one_chain`, extended for all of
  it — falsified by the catalogue order, by dropping the merged notes and
  by opam losing its bridge. `overview.recorded_runs_are_an_overlay` now
  also holds every recorded view to a package in §1.
- **The package layer says the package managers' terms, and is layered
  — landed the same day** (user: "we shall show the terms in that pm in
  the next line for `capability file` or `bridge package`, whether they
  can be `.pc` or `conf-pkg` or `depext`", and "if they are on the same
  abstraction layers, they can stay on the same horizontal line"). Where
  no name is known, the capability file shows the term for what the
  native side's package manager ships (".pc file" for apt and brew — a
  new typed column in the PM-solo table, §4.1), and the bridge package
  shows the kinds of bridge the chosen chains join through ("conf-*
  package", "depext field" — `Canary_bridge.kind_term`, and a new column
  in the cooperation table, §4.3). A term is drawn muted, so it does not
  read as a name. The two nodes are not on the same layer, though both
  are extra to a package's standard content (user, the same day, after
  a first cut that set them on one row): a BRIDGE PACKAGE IS A PACKAGE —
  conf-gmp is an opam package — so it sits on the package row with the
  two packages it joins, right of centre, since the language ecosystem
  writes it; a CAPABILITY FILE IS CONTENT inside a package — gmp.pc
  ships in libgmp-dev — so it sits a level below, off the native
  package's lower-right. A second line too long for its box is squeezed
  to fit (torch's depext bound). Pinned in the same pin: the terms match
  their tables, every bridge's term is one its manager defines, nodes of
  one layer share a row and no two boxes overlap — falsified by the
  one-row position and by a term opam does not define.
- **Every package in canary carries a cooperation, known before any run
  — landed the same day** (user: "Does any `package in canary` must
  carry a cooperation mode? … can we statically detect this … when we
  click any button for package_in_canary, it shall also show one
  cooperation button in clicked"). A package's cooperation is DERIVED,
  not recorded as a declaration: from its world's two placements and its
  binding package's declared gate (`Canary_topology.topology_of_world` →
  `coop_of`). It needs a world, so it is computed beside firing rather
  than in pass 2, but it needs no run — nothing in it is created while
  running. Where it is carried: the run record (`canary result --json`,
  `rows[].chains[].cooperation`), §1's package data (`cases[].k`) and
  §4.3's instances. Choosing a package already lit its cooperation — for
  20 of the 28. The other 8 (cairo, libffi, zlib, zstd) classified as
  "undeclared": the opam-binding template kept their gate on its own
  record, which nothing read. The template now routes the gate alone
  (`pr_pm_gates`; the mechanism stays unrouted, project/issues.md §2),
  so their apt worlds are "conf package" and their vendored worlds
  "bridge still gates, against a system this world does not use" — the
  conf check probes apt's library while the world links the conda-forge
  prebuilt. That cooperation's button label became "gated, local
  library", since its library is now built, staged or vendored. Pinned:
  every package's cooperation has a button and the page lights it, and
  where a project states its gate twice the two agree; the joins pin
  moved these four to bridged deliberately (it was written to fail
  here), and an un-routed copy of cairo keeps the undeclared and
  no-bridge branches exercised. Falsified by the template not routing
  its gate.
- **Every line under a node label says where it came from — landed the
  same day** (user: "Can I confirm all the data in diagrams, for both
  generic and the real-packages, are coming from either code or logs? …
  you can show the relavent code path in some place in the page. you can
  demonstrate one and we can ask another session to finish or audit the
  rest workflows"). The workflow demonstrated is the lines §1 writes
  under its node labels: a package's declared names, a recorded world's
  names and placements, and the package managers' terms. Each value
  carries a source (`Canary_overview_runs.source`: code, run or render,
  what was read, and the function that read it), produced by the same
  list as the value. Under the diagram, the page lists every line with
  its source. It found one render read: the installed version of a
  system package fetched with no pinned version, in 12 placements across
  7 projects. That is finding 2 above, visible on the page now. Pinned
  by `overview.every_drawn_line_has_a_source`, whose render clause
  replaces the rendering machine's answers with a sentinel instead of
  restating the condition. Falsified three ways. Everything else §1
  draws is inventoried, with the procedure, for the session that audits
  it: [`design/overview_provenance.md`](design/overview_provenance.md).
- **The badges on the edges count what applies — landed the same day**
  (user asked what the edges and their numbers are, then: "the claims
  are just agreements … you should fix them if feasible, otherwise leave
  some notes in the status.md"). An edge's label names who makes the
  relation true: an action of ours, someone else's rule, or, once, a
  claim. Its number counted the agreements placed on it. Four things
  were wrong with that number:
  - **Two edges said "checked" where nothing checks.** `pack` and `run`
    drew filled badges because `claim_sites` carried a hand-written
    `cs_implemented` flag that said yes for `behavior_matches`,
    `repack_preserves_api` and `repack_complete`. The registry lists all
    three as planned. The flag is gone: `Canary_topology.implemented`
    asks the registry. The census moved from 13 implemented / 17
    candidates to 10 / 20.
  - **One number mixed checked agreements with placeholders**, and
    nothing said which were which. Now each edge has two badges, filled
    for the agreements canary checks and hollow for those only named.
    Hovering lists each agreement by name.
  - **The number never followed the drawing.** It counted every
    mechanism's agreements, while a recorded run coloured the badge from
    fewer. Now both badges count `Canary_topology.edge_claims` for the
    mechanism drawn. Whether an agreement is checked there is pass 2's
    answer (`carried_slugs`). A recorded world counts the same list, and
    its filled badge is coloured from exactly those agreements. A checked
    agreement with no recorded outcome reads `unevaluated` instead of
    dropping out.
  - **A badge sat on an edge the world never realizes.** A built-library
    sqlite world drew the library agreements' red badge on the system
    package's edge too, because those agreements sit on both of the
    library's producers. A recorded world now badges only the edges it
    realizes, and a generic drawing hides the badges of the edges it
    greys.

  Pinned by `overview.placeholders_are_drawn_as_such`, which now reads
  the registry directly and names `pack` and `run`, and by the new
  `overview.badges_count_what_applies`: §1's count per mechanism equals
  pass 2's `carried_slugs`; a recorded view counts §1's list less its
  missing and unrealized edges; and its colour comes from exactly its
  checked agreements. Falsified three ways: counting every registry row
  as checked, dropping the unrealized-edge rule, and giving the view the
  wrong mechanism. Checked in headless Chromium for the default drawing,
  ctypes, zarith and sqlite's built world, which is not a pin.

  **Left open, because each needs more than the page:**
  - *An agreement placed on several edges is counted on each.* That is
    `package_resolution_suffices` (three edges), and the four library
    agreements on both producer edges. Hovering now shows "also on …".
    A recorded world realizes one producer, so it no longer shows the
    verdict twice. But a generic drawing that keeps both producer edges
    counts the agreement on each, and an end-to-end agreement has no
    single edge to sit on. Deciding whether such an agreement gets one
    badge over its whole span is a question about what a badge is.
  - *The registry's "inapplicable" means two things.* `signatures_agree`
    for a Python C extension says "no signature extractor for this
    language's stub surface yet — a gap in canary, not in the mechanism".
    That is recorded as `Inapplicable`, exactly like a mechanism that
    compiles no stub. The badges follow pass 2, so on a cext chain this
    agreement drops out of the count instead of showing hollow. Telling
    the two apart needs a typed cause on inapplicability, the way
    `Unavailable` got one on 2026-09-15. That is a change to the
    agreement layer, and pass 2, the result table and the check index
    all read it.
  - *A candidate states no applicability*, so it is counted wherever its
    edge is drawn. `compatibility_version_satisfied` is a Mach-O
    agreement, and it shows as a placeholder on ELF chains too. It stays
    that way until the proposal record carries the formats it applies
    to, as a registry row does (`ag_formats`).
- **A source sits beside its package's column — landed the same day**
  (user: "the source is not in the package which usually contains the
  library or module, so it's acturally above the edge … move the naitve
  source … to the left … The same for binding source, which we move it
  to the right. Both source are still in the same height"). A package's
  column now holds only what the package ships: headers, library and
  staged copy under the native package, stub, module and surface under
  the binding package. The package's edges run straight down that
  column. Each source sits outside its column on the source row, the
  native one to the left and the binding one to the right, in a
  narrower box (the names under a source are short). The two columns
  moved inward to make room, and the artifact rows moved 16px lower so
  the native source's two build edges have space for their labels. The
  headers stayed in the column, because the native package ships them
  (`realize_hdr`); in a built chain the build edge reaches them from the
  source beside the column.

  Moving the sources exposed marks that had been hidden all along. An
  edge's label and badges can now sit anywhere along the edge
  (`label_at`) instead of only at its midpoint:
  - `build_lib`'s label and badges had been behind the headers box.
  - The two package-probe labels were cut by the stub box and by the
    staged copy.
  - `install_lang` and `pack` join the same two nodes, so their marks
    had shared one spot.

  The band labels are centred and drawn over the edges, with a halo.
  Before, the PM band's label was hidden behind the system PM box, and a
  `fetch_lib` label ran through the artifact band's.

  Pinned by `overview.chain_choices_draw_one_chain`, which now checks
  each box at its own width and that each source is off its column's
  line. The new `overview.edge_marks_clear_the_boxes` checks three
  things. No edge runs under a source unless the source is one of its
  ends. No label or badge lies under a box, under another edge's label
  or badge, or under a band label. Measured against the old layout,
  those checks fail 24 times. Falsified three ways: the binding source
  put back in its column, `build_lib`'s placement removed, and
  `install_lang`'s placement removed. Checked by rendering the default
  drawing and sqlite's staged world in headless Chromium, which is not a
  pin.
- **The bridge sits with the language side, the sides are captioned, and
  every visual hint is in one list — landed the same day** (user: "The
  bridge package should be near to the binding_package, since it belongs
  to the language PM's side"; "shall we use some virtual hints so that we
  can see the left part and right part for the system and language
  division?"; "shall we keep all our visual hints in a place, so we can
  always check for them all and you won't be forget the old ones, and we
  can detect if there are conflicts").
  - *The bridge* moved from x=620 to 670, as close to the binding
    package as its `depends` edge allows: one step further and that
    edge's badge slides under the binding package. The layout pin now
    requires the bridge to be nearer its binding package than the
    native package.
  - *The sides* are captioned "SYSTEM SIDE" and "LANGUAGE SIDE" over
    their columns, in the margin above the bands. A dividing line was
    considered and not drawn: every edge that would cross it is a
    cooperation between the sides, and the bridge's check on the
    capability file would have carried its label on the line.
  - *The visual vocabulary* is `Canary_overview_page.visual_hints`: 40
    hints, each naming the stylesheet rules that give it its look, the
    drawings it can show in (always, generic or recorded), its exclusive
    group (an edge has one state), and its key sample and words. Both
    keys are rendered from the list. The new pin
    `overview.visual_vocabulary_is_one_list` checks four things:
    - every §1 rule of the stylesheet belongs to exactly one hint, or to
      the nine base rules;
    - every hint's classes are applied by the page;
    - every hint is explained, and no two key entries share a sample;
    - no two hints that can show on one kind of element at once look
      alike, comparing colour, dash, width, opacity, slant, weight and
      display the way a reader sees them.

    Its first run found two conflicts. In a recorded run, "in the chain,
    never logged" and "happened inside a package manager's action" drew
    the same grey dots under the same key sample; "inside" is dash-dot
    now. And the key gave "failed" and "blocked" one sample. It also
    found six rules nothing applied any more, left over from the
    hand-drawn cases, which went together with the drawing parameters
    that could still have emitted them. The keys also gained entries
    they had lacked: the greyed edge, the outlined node, the muted term,
    the placement line, the claim edge, the badge outcomes and the two
    button states. The `?` mark is explained in §3's own table header,
    since it is not part of the drawing.

    Falsified four ways: the two states given one look again, an
    unregistered style added, "blocked" given "failed"'s sample again,
    and a hint whose class nothing applies. The comparison sees only a
    hint's own rules, not a look it inherits, so the muted term's rule
    now states its italics.

*Alignment with the layered-model draft* (`doc/audit/multi_pm.md`, the
user's, uncommitted — this is where canary and the draft are compared;
the draft itself is not edited here):

| draft | canary |
| --- | --- |
| PM · package · artifact layers | the same three, plus a PROGRAM band for the two consumer programs |
| package bridge — "an explicit symbolic relation" (§13) | a THING, a variant per package manager: `Canary_bridge.t` (decision 1). The draft's definition still says relation |
| `.pc` among artifact-level interface metadata (§7), drawn in the artifact layer (§3.1) | package layer, owned by the package that ships it, a source of claims, not a bridge (decision 2) |
| topology character (Table 3) | `Canary_topology.character`: the conf rows now read the draft's "symbolic package bridge + artifact validation"; the canary-only situations (a built side still gated) stay canary's |
| discovery as an action (§13) | an edge is an action when the package manager dispatches it separately and observably (decision 4): `conf_probe` is one; pkg-config inside zarith's configure is information |
| package-specific override as graph rewriting (§10) | `Package_builds_lib` / `Bundled` gates, and canary's own zarith-no-conf bypass; template + instance (decision 3) not built yet |
| version domains (§8) | one bool per bridge (`gb_reaches_lib` ← `tracks_lib`); deferred |
| topology → agreements → evidence → verdict (§11) | the bridge record is the evidence; the agreements are next |

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
