# Claude Code — Project Guide

## Build & Run

```sh
dune build                                                   # build everything
dune exec src/bin/canary_main.exe -- paths                   # print 15-row action pattern table
dune exec src/bin/canary_main.exe -- paths-md                # same, markdown output
dune exec src/bin/canary_main.exe -- graph                   # write docs/canary/graph/action_graph.mmd
dune exec src/bin/canary_main.exe -- action sqlite            # 10 scenarios (2026-08-19, the first full 2x2): the lib's 5 placements (F:apt + Built 3.45.1/3.46.1 + Installed 3.45.1/3.46.1) x the OCaml binding's 2 opam pins (5.1.0/5.4.1). Installed worlds stage the built lib into <ws>/install (copy-out) and probe the STAGED lib; Built worlds probe the build tree. Each pin gets a pinned fetch + pin_check_post + a world assertion on the probe (the switch is shared state). All cells green by construction — the lib pair exports identical symbol sets; widening to a <=3.43 amalgamation is what makes the forward cell real
dune exec src/bin/canary_main.exe -- action z3               # THE MISMATCH MATRIX (2026-08-19): 16 scenarios = per dev ref (latest/arbipher/pre-10549) five cells — dev baseline (lib B x binding B), BACKWARD (lib B x binding F:4.16.0), FORWARD (lib F:apt x binding B), and the staged face of each lib-built cell — plus ONE both-released baseline (ref-INDEPENDENT: nothing is built from the source there, so the unread-source collapse keeps only the canonical ref). Installed worlds run cmake --install into <build>/../install-<ref> (per-ref, never shared) and probe the STAGED lib + OCaml package. The FORWARD cell fails today and it is a real finding: the HEAD-built binding requires 791 Z3_ symbols, apt's libz3 4.8.12 provides 705 (100 missing) — to be declared as a derived xfail. The BACKWARD cell passes against a HEAD-built libz3 5.1.0. parser_context xfail fires in every world. --thin = stable chain only; --refs latest,pre-10549 = the #10549 regression pair
dune exec src/bin/canary_main.exe -- action llvm             # 3 scenarios (2026-08-19): 2 dev build chains + ONE both-released baseline (was 5 — its three all-Fetched worlds differed only in an unread source ref). Opcode.UncondBr xfail in the released-binding world. No Installed axis and no cross cells yet: apt ships llvm-18/19/23-dev and opam ships llvm.18-shared/19-shared, so its 2x2 needs NO source build — only the two cross-cell probe realizations z3 grew
dune exec src/bin/canary_main.exe -- action tiny-full        # tiny-full PROJECT (peer of z3). ⚠ RUNS 1 SCENARIO, not the 6 this line claimed until 2026-08-25: its artifact table declares every row Vendored@Stable, so the product is 1 by construction. The spec declaring lib Built@{Stable,Dev} + the dev ocaml binding is `tiny_full_general_spec`, reachable only via `general_spec` — which NOTHING READS. Unreachable downstream: dispatch's Built_lib/Dev_binding cases and the OCaml @Dev Forward mismatch probe (the forward tiny_scale xfail that was tiny-full's whole point). Open decision — restore the axes or delete the dead code: doc/canary/project/issues.md §1
dune exec src/bin/canary_main.exe -- action tiny-full --thin # thin = version Subset [Stable] policy: 2 scenarios (drops both dev axes)
dune exec src/bin/canary_main.exe -- action @all           # THE batch: every registry project under the default config — Heavy (z3/llvm) THIN (bypasses the source-built Dev chains), Light FULL; --thin forces thin everywhere; --refs A,B = only the source-repo refs with those pinned ids (any project; the batch never sets it); single-project runs always full
dune exec src/bin/canary_main.exe -- emit sqlite --stage order  # ONE PIPELINE PASS (2026-08-24, renumbered 2026-09-16). SIX passes (reporting is a consumer of actions.log, not a pass), each answering to a NAME or an index: 1 declare (the project_spec), 2 analyse (what canary UNDERSTANDS of it — the chains the spec admits, the mechanism each language binds through, which claims it can carry; world-free by definition), 3 enumerate (the worlds the project HAS — invocation-independent), 4 select (what THIS run asked for: z3 has 16, thin asks for 1), 5 order (the run order, grouped by the store state each scenario locks — not the same order as 4 since 2026-08-21), 6 realize (one scenario's steps). --json = one encoder per pass (diffable; keys canonical); --raw = the derived `show` form; --thin/--refs as elsewhere; reads the CATALOGUE so a muted project can still be dumped. Goes through `Canary_pipeline`, never a re-derivation. Design: doc/canary/design/enumeration/README.md
dune exec src/bin/canary_main.exe -- spec tiny-full          # DRY-RUN snapshot: grouped artifacts + enumerated scenarios (no execution). ALL of tiny-full/sqlite/z3/llvm are project_run now (the raw variant view retired with A5 phase 5)
dune exec src/bin/canary_main.exe -- spec-check @all         # STATIC spec-maturity audit, 12 checks (✓/✗/⚠ per project, --json for web status, exit 1 on errors; tiny-full github/opam n/a). Reads only the declared artifact table — and the CATALOGUE since 2026-08-25, so a MUTED project (z3) is still auditable. `lib pair`/`binding pair` (2026-08-25) are the 2x2 lower bound: they count admissible (provision, version) POINTS per row and warn below two — points, not universe cells or channels, because ssl's and sqlite's binding pairs are two opam store PINS inside one Fetched@stable cell. EVERY lib must be paired, AT LEAST ONE binding must be. A warn prints the row's ~rationale, which is what tells a permanent thin axis (zarith: apt already ships GMP's newest) from an undeclared one (ssl: apt 3.0.13 vs conda-forge 4.0.1, obtainable and unlanded)
dune exec src/bin/canary_main.exe -- tiny run                # tiny1: run every single-scenario tiny project (the factory/harness)
dune exec src/bin/canary_main.exe -- artifact-test           # framework self-tests (native, ocaml, python, compat helpers)
dune exec src/bin/canary_main.exe -- pm-test                 # PM module self-tests
dune exec src/bin/canary_main.exe -- cache-test              # run-cache soundness (failed step must not cache as success — bug B) (apt/brew/opam/pip)
dune exec src/bin/canary_main.exe -- artifact-summary --kind native --path X  # ad-hoc summary dump
dune exec src/bin/canary_main.exe -- inspect-diff --old A --new B            # diff two inspect.json files
dune exec src/bin/canary_main.exe -- compat <project> [<variant>]            # static C-symbol cross-check
dune exec src/bin/canary_main.exe -- verify <project> [<variant>]            # cross-reference prediction vs probe.log
dune exec src/bin/canary_main.exe -- stages <project|@all>                # store-lifecycle coverage matrix (✓/-/⊘ + legend)
dune exec src/bin/canary_main.exe -- scenarios <project> --engine            # render variants as enumeration-algorithm provision assignments (ssot §4.2)
dune exec src/bin/canary_main.exe -- tiny engine                             # render tiny's scenarios as enumeration-algorithm mutation-axis projection
dune exec src/bin/canary_main.exe -- tiny assemble-check --id lib Bs.4       # P3 step 2: emit+assemble a vendored resource onto the witness base (needs `tiny prepare-all`)
dune exec src/bin/canary_main.exe -- status <project|@all> [-v]              # per-scenario last-run verdict matrix (xfail/✓/✗/·)
dune exec src/bin/canary_main.exe -- overview --json [<project>]  # THE RUN RECORD the page is drawn from, on stdout, writing nothing. ONE RESULTS COMMAND since 2026-09-28 (user): `canary result` folded in here, and its text/md tables retired (they drew the old layout). Per row: cells typed (step state ran/warm/blocked/unrecorded + verdict; check outcome; `at`), `recorded_on`, `steps` (each with `location`, `inspects`, `place` on the overview's graph), `edges`, `claims`, `checks` (per language: §1.2's check cells, outcome + blame, which §2 counts), `chains`, `steps_from` (run = the run's manifest, code = re-derived). Pinned by matrix.record_export_is_the_matrix + matrix.record_carries_every_step + matrix.record_joins_edges_and_claims + matrix.record_carries_each_worlds_chain + overview.agreement_counts_are_the_tables + topology.every_step_has_a_place
dune exec src/bin/canary_main.exe -- overview                # THE PAGE, and since 2026-09-28 the only results page: docs/canary/overview.html — §0 the outline, the terms and how the page is made (a figure from the code and a run to each section, marking what pins hold and which files agents do not read whole, and each subject's code and running layers, and every test `canary project-test` runs with the claim it holds — `canary overview --flow` prints it, with every section's template slots and modules); §1 a chain, layer by layer (package managers → packages → artifacts → programs), chosen from its parts, with a recorded run painted on it; §1.2 the result table (a row per chain and machine, frames as columns); §2 the agreements on the same columns, with §2.2 every edge and its claims; §3 the model (package managers, mechanisms, cooperations, and the chains canary runs). Also writes docs/canary/overview_runs.js (per machine, `_mac` on macOS; a --platform render goes to _out/), the pointers at the retired result page's addresses, and each figure and table on its own, captionless, to doc/canary/research/exhibits/ for the manuscript (`Canary_overview_export`; `--exhibits DIR` writes only those, and with `--chain ID [--world W]` or `--mechanism/--coop/--native/--lang` only Figure 2 and the lines table, drawn for the chain the buttons would draw; ids and titles in `Canary_overview_exhibits`). What a choice draws is computed once in OCaml (`Canary_overview_draw`, over `Canary_overview_join.resolve`); the page's script only looks it up. §1.2's cells likewise (`Canary_overview_results`): computed when a machine writes its runs file, carried there filed by column, and laid out by the page's script and by the export, whose Table 4 reads every machine's runs file. The page explains itself, and its §0.4 lists the tests; the code behind each part, the decisions and the plan are doc/canary/design/overview.md, its history doc/canary/worklog/worklog_2026_09.md. Its prose, stylesheets and scripts are files in canary/overview/ (page.html is a template whose {{slots}} `Canary_overview_page.render` fills); a new slot must be claimed by a section in `Canary_overview_flow.sections`, or overview.flow_is_the_page fails. A new look must be registered in `Canary_overview_looks.visual_hints` and a new placement rule in `layout_rules`, or overview.visual_vocabulary_is_one_list / overview.layout_rules_hold fail; every line under a node label carries its source (overview.every_drawn_line_has_a_source)
make view                                                    # = `canary overview`
dune exec src/bin/canary_main.exe -- checks --frames         # THE COLUMN MODEL of both tables on the page (`Canary_frames`): one frame per action as the diagram draws it — what it consumes, checks on that, its pieces, what it produces, checks on that — by side, then flow. Pinned by frames.derive_the_confirmed_layout (prototype A, user 2026-09-28)
dune exec src/bin/canary_main.exe -- project-test                            # project-definition layer tests (pure; catalogue/surface/enumerate/mechanism)
dune exec src/bin/canary_main.exe -- mutation-test                           # artifact-mutation self-tests
dune exec src/bin/canary_main.exe -- action zlib --switch=default  # OVERRIDE the switch (see below); --switch= means the AMBIENT one
dune exec src/bin/canary_main.exe -- --platform=macos overview --json zlib  # RENDER AS the other platform (macos|wsl); see doc/canary/design/platform.md
make canary                                                  # run canary via Makefile shorthand
	make canary-test                                             # post-change verification (project-test + artifact-test + pm-test)

**Canary runs in its OWN opam switch** (`canary`, created 2026-08-26, OCaml
5.4.1 — the same compiler `default` runs, so package resolution matches the
measurements taken there). Canary installs/uninstalls opam packages as it
runs, and a binding channel pair is realized by FLIPPING A PIN, which for
zstd removes `ocaml-compiler` and recompiles 157 packages — not something to
do to a working switch. Mechanism: every canary command already begins with
`eval $(opam env)`, and `opam env` honours `OPAMSWITCH`, so the switch is
exported once in `run_cmd_logged` (the single point every step's command
goes through) rather than threaded through all 48 templates. **There are TWO
such points, not one** (2026-08-26): canary also shells out from OCaml,
outside any step — `pin_check_post` and `Canary_pm_opam.is_installed` ask a
store what it holds, and `run_info` records what the run was. Those go
through `Canary_store.sh_in_switch`; as bare `Sys.command` they inherited a
process env with no `OPAMSWITCH` and answered about the AMBIENT switch,
which turned five sqlite scenarios red and passed the other five for the
same wrong reason. If you add an OCaml-side shell-out that asks about a
STORE, it goes through `sh_in_switch`. It is also part
of the step FINGERPRINT, so a verdict earned in one switch is never served
to another. Select with `--switch=NAME` (any subcommand — the flag is
stripped from argv before cmdliner, which would otherwise reject it),
`--switch=` for the ambient switch, or `CANARY_SWITCH=NAME`. Every run
prints `opam switch: <name>` and logs an `opam_switch` event to actions.log.
The framework tests (`artifact-test`/`pm-test`) go through the same prologue via `Canary_pm_test.run_test`, so both axes test the same switch. An unknown switch name is REFUSED at startup (exit 2) — without that check `eval $(opam env)` no-ops and the run silently continues in the ambient switch. Pinned by `switch.selection`.

**The PLATFORM is one value, carried not sniffed** (2026-08-26).
`Canary_store.platform ()` is THE answer — detected once, overridable
with `--platform=macos|wsl` (any subcommand; stripped from argv before
cmdliner) or `CANARY_PLATFORM`, carried on `run_config.platform`, printed
in the run header, logged per command, and part of the step fingerprint.
The system PM is DERIVED from it (`system_pm_of_platform`), which is what
stops a Linux box with Linuxbrew from picking macOS package names. Passes
1–5 of the enumeration never see it; only pass 6 (realize) and the tool
wrappers do. The override lets one machine render the other's view —
`canary --platform=macos overview --json` on WSL is the cheapest way to
review mac work. **Read [`doc/canary/design/platform.md`](doc/canary/design/platform.md)
before adding anything platform-dependent** — it has the tool sibling
table, what a project spec may declare per platform (pairs, never
branches), and the three consumption modes.

**`--strict` — a run-wide FAIL-FAST for agreement work** (2026-09-15,
user: "it's good during the development that the running shall fail fast
for better debugging for ourself, rather than expected fails (xf)").
Third flag of the same shape as `--switch`/`--platform`: stripped from
argv before cmdliner, applies to every subcommand, also
`CANARY_STRICT=1`. By DEFAULT a detected disagreement does not fail its
step — the acceptance policy is "the command succeeded and its
postcondition holds", and a violated agreement there is a finding about
ARTIFACTS the action was never asked to fail on (ssl's
`dependencies_provided: violated libcrypto.so.3` is real and must not
turn ssl red). The cost of that default is that the result table shows ✗
in a check cell while the scenario says PASS. `--strict` makes the
two views agree: the step that READ the disagreeing evidence fails, at
that step. It adds no evaluation — same violations, different meaning —
logs each as `strict_violation`, and rides the step fingerprint so a
permissive verdict is never served to a strict run (the permissive digest
is unchanged, so turning it off costs nothing; a strict run is always
cold). It is a debugging mode for ONE landing, not a CI gate: sqlite's
built-Stable lib is 3.43.2, deliberately pre-3.44.0, so `--strict` fails
`build_lib` in four scenarios on the first run — the agreement being
right about a world the project built to be wrong. Flag lives at
`Canary_agreement_common.strict_mode`; pinned by
`strict.acceptance_policy`; written up in
[`agreement/README.md`](doc/canary/design/agreement/README.md).

**macOS status** (2026-08-26). Canary runs on macOS: `make canary-test`
is 113 + 109 + 14 green there, `canary mutation-test` 46/46 (that suite is
NOT in `make canary-test` — run it separately, it had never been run on
mac and hid two failures). `spec` / `spec-check` / `result` / `emit` /
`prebuilt` all work; all four conda-forge prebuilts have osx-arm64
archives at the same version + build number as linux-64. Four classes of
Linux assumption were fixed and every one FAILED SILENTLY: `sed -i -E`
(BSD reads `-E` as the backup suffix → the mutation no-ops and exits 0),
`dpkg-query` in the matrix (versions vanish), `readelf -d` (the L4 record
goes absent, which reads as "no constraint"), `nm -D` + a bare-prefix
grep (Mach-O underscores every C symbol). NOT yet running on mac: **tiny**
(`canary tiny run`, tiny-full's vendored artifacts) — its C lib links now
but `libtiny.so.1` is spelled out in ~40 declarations; and **z3**,
deliberately. The to-do is `doc/canary/design/platform.md` §7.

**Post-change verification.** After every edit that touches `src/canary/`, run
`make canary-test`. This catches regressions in enumeration, compat theory,
tool assumptions (nm/ocamlobjinfo/python3), and PM presence — pure and
shell tests, about 20 s (the count is in `doc/canary/status.md` §1). The shared `Canary_runner.run_project_spec`
means both CLI and tests exercise the same pipeline. Before committing or
ending a session, also run `make canary-post-check` (sqlite, the agreement
round trip and the tiny1 bridge; about 40 s when warm).
```

### Working on the enumeration — what to read, in order

**Start at
[`doc/canary/design/enumeration/README.md`](doc/canary/design/enumeration/README.md)**
and follow its *How to read this, if you are new* (four steps, ~45 min,
stoppable after any of them). That file is the MAP — which doc answers
which question, the seam with `agreement/`, the alignment rule. **The
dataflow itself is
[`pipeline.md`](doc/canary/design/enumeration/pipeline.md)** (split out
2026-09-17): the IRs, the pass table, and the pins that arbitrate when a
doc and the code disagree.

The short version, so a session knows what it is looking at before
opening anything. **Four IRs, six passes** — and the counts do not
match, because three passes consume and produce the IR they were handed:

```
artifact_row list  (surface)
  ▼ 1 declare      → stage1_declare_spec.md
project_spec       IR: spec
  ▼ 2 analyse      → stage2_analyse_spec.md     enriches, does not lower
analysis           IR: analysis — what canary UNDERSTANDS (chains it
                   admits, mechanisms, which claims it can carry). Carries
                   the spec, so pass 3 reads what pass 1 wrote
  ▼ 3 enumerate    → stage3_enumerate_worlds.md
assignment list    IR: worlds   ┐ passes 4 and 5 do not lower:
  ▼ 4 select       → stage4_select_worlds.md    they narrow and
assignment list    IR: worlds   │ resequence a fixed IR
  ▼ 5 order        → stage5_order_worlds.md
assignment list    IR: worlds   ┘
  ▼ 6 realize      → stage6_realize_steps.md
step list          IR: steps — the object code, consumed by THREE backends
                   (run_graph executes, render_gh_step, mermaid_of_steps;
                    the fourth, render_steps_data, went with the per-run
                    page on 2026-09-28); executing is one of them, not a
                    stage above them
```

Doc filenames are `stage<N>_<verb>_<IR out>.md`, so the directory listing
carries the reading order, the verb, and where the IR lowers.
`stage0_naming.md` is vocabulary, not a pass — read it when a word stops
being obvious ("scenario" has four senses, all in use).

**RENUMBERED 2026-09-16** — analyse(2) was inserted and everything after
it moved up one. Pass 2 absorbed `chain_applicable`, which used to be an
unnumbered *(branch)* row in the pass table and which the README listed
among the accidents it wanted redrawn. The user approved the rename cost:
*"a clean model for pass as well as action / project is more worthy"*.
**PIN NAMES WERE NOT RENUMBERED** — `select.is_a_subset_of_stage2` still
says `stage2`, and a `stageN` inside a pin name is a historical label,
not a claim about today's table.

**The membership rule for pass 2 is the absence of a world.**
Applicability (`mechanism → lang → declared`) is knowable from the spec,
so it is pass 2's; FIRING (`mechanism → lang → world`) needs a world and
stays at realize. That line is what the 2026-09-15 Python bug crossed in
three files at once.

**Which doc for which job:**

| you are… | read |
| --- | --- |
| landing a project | pass 1 only — it is what you will actually write |
| asking what canary makes of a spec | pass 2 (`emit <p> --stage analyse`) |
| wondering why a world is missing | pass 3 (the five constraints) then pass 4 (was it selected?) |
| debugging run order / an opam pin dance | pass 5 |
| adding an action or a command template | pass 6, then `../action_playbook.md` |
| unsure what a word means | `stage0_naming.md` |

**See it rather than read it** — every pass prints:
`canary emit <project> --stage <name|1..6> [--json]`. `emit sqlite
--stage enumerate` then `--stage order` shows the same ten scenarios in
two different orders, which is the fastest way to understand pass 5.

Current state and open items in
[`doc/canary/status.md`](doc/canary/status.md); per-project findings in
[`doc/canary/project/issues.md`](doc/canary/project/issues.md).

**tiny-factory / tiny1 / tiny-full** (ssot §4.2.5, status §1a — the
2026-08-02 arc). Three named things: **tiny-factory** = the machinery
(scenario specs + workspace materializer + vendored-resource emitter/
assembler); **tiny1** = the single-scenario projects, each a hand-written
good/bad case = the ground-truth *oracle* (`canary tiny run`); **tiny-full**
= *one* project (peer of sqlite/z3) that declares static artifact
**resources** and lets **canary** compute detection/expectation/collapse
(`canary action tiny-full`, NOT a `tiny` subcommand). Design principle
(**mutation-agnostic**): the runner knows nothing about mutations — a bad
artifact is a build at a **bad-quality version** (`build_id = {channel;
quality=Good|Bad tag}` in `canary_enumerate`), the `tag` opaque to the
runner; only the materializer knows a tag → a fault. Artifacts are
**vendored** — scenarios are *assembled* from pre-built variant resources
(overlay, no rebuild), so combinations are just more overlays and a
binding-over-bad-lib is a free deploy mismatch. Key symbols:
`Canary_enumerate.{quality,build_id,good}`;
`Canary_scenario.lower_expectation_agnostic` — THE one framework lowering
since A7 (derives the expectation by inspection); the ORACLE is a
tiny-factory combinator over it (`expectation_of_entry`: restrict to the
recipe's violated contracts + gate on manifestation + strengthen
Derived→must-fail); `Canary_tiny_scenario.{tiny_full_spec,
tiny_full_assignments,run_tiny_full}`; `Canary_tiny_workspace.{emit_resource,
assemble,assemble_check}` (P3 step 2, vendored emit+assemble).

Output layout (gitignored via `_*`):
- `_out/canary/projects/<project>/<step>/` — per-project action runs
  (z3/llvm write per-SCENARIO dirs since A5, e.g.
   `projects/z3/lib-built-dev_python_binding-fetched_source-fetched/`;
   pre-A5 `dev_<hash>/`/`stable/`/`19/` dirs may linger from old runs —
   `compat`/`verify` still glob those old names, a pending reconciliation)
- `_out/canary/test/{artifact-test,pm-test,artifact-summary}/` — framework
  self-tests and ad-hoc dumps
- `_out/canary/graph/action_graph.mmd` — universal schema diagram from `canary graph`

`docs/canary/` is tracked in git and is the GitHub Pages site: the overview
page, the per-machine runs files (`overview_runs.js`, `_mac` on macOS) and,
under `projects/`, three pointers at the retired result page's addresses.
Nothing a run writes is copied there any more (2026-09-28, user: one page;
the per-run pages retired) — run outputs stay in `_out/`, untracked.

## Active Work: Canary

Canary is a dependency-testing framework that enumerates all possible
build/probe actions for a C library project (with OCaml + Python bindings
today; Rust/Java/etc. plug in as data) and runs them locally, with GH CI
support.

### Layered layout

After the 2026-06-01 refactor (commits `5c0438f` → `0139e07`),
`src/canary/` is organised into 8 subdirs with a documented layer
order (also in [`src/canary/dune`](src/canary/dune)):

```
base/      vocabulary — types every other layer uses (incl. API-surface
           claim types and output-tree naming conventions)
agreement/ THE AGREEMENT LAYER (was surface/, 2026-09-01) — the agreement
           registry + the 14 NAMED agreements' comparators/evaluators
           (descriptive names since 2026-09-12; the c1..c9 ids are gone and
           deliberately do not parse); a check is an agreement beyond a
           tool's direct result, so tool wrappers stay in tool/
tool/      real-world wrappers — PM drivers, inspector drivers, build cmds,
           toolchain config (incl. per-language probe specs)
action/    action graph — rules, step model, step builder, paths
backend/   step-list consumers — local runner (executes), GH YAML, HTML,
           Mermaid, run_info orchestrator
test/      framework self-tests
project/   THE PROJECT layer (canary_project library, 2026-08-14): the
           project DATATYPE + definition utils ([Canary_project_run]:
           project_run, policies, run_config, spec helpers;
           [Canary_opam_binding]: the definition template) PLUS the
           concrete instantiation (the 8 specs + tiny's factory + the
           entry modules that NAME projects: registry, CI jobs)
main/      the RUNNING layer (canary_main library, 2026-08-14):
           Canary_pipeline (2026-08-24: THE pipeline as named passes —
           spec_of/enumerated/ordered/ctx_of/steps_of; the runner and
           the matrix both route through it so there is one assembly),
           Canary_runner (run_project_spec + scenario_run_result),
           batch runner, spec-check, the layer test suite — the shared
           functions the cmd, the tests, and the batch runner consume;
           takes project_run VALUES / project lists (the bin injects
           Canary_registry.all_projects); references concrete projects
           in TEST code only
```

`base/`→`agreement/`→`tool/`→`action/`→`backend/` is the dependency
order; `project/`, `main/` and `test/` consume the upper layers.
Dependency direction: canary_lib ← canary_project ← canary_main
(never the reverse).
(The retired `legacy/` sub-library was moved to
`doc/_legacy_code/` in commit `302f1b3`; the retired Python
tiny harness lives at `doc/_legacy_code/tiny_python_harness/`
per Phase E of the tiny migration.)

⚠ **"Pattern A".."Pattern F" ARE NOT CANARY CATEGORIES** — do not use
them to describe a project. They come from
[`doc/canary/surveys/opam.md`](doc/canary/surveys/opam.md) §2, which
surveys what opam packages look like IN THE WILD, and hybrids already
break the letters (bitwuzla is "A for discovery + C for building").
Canary describes a project by ORTHOGONAL DIMENSIONS — native-lib origin
× lib discovery × binding origin — carried as data in `store_config`
(`doc/canary/project/projects.md` §1, ssot §6.1). **A project is not IN a
pattern; it HAS dimension values**, and nothing branches on a letter. The
module once called `canary_pattern_a.ml` is `Canary_opam_binding`, a
TEMPLATE that fills a common combination. Say "the opam-binding
template" or name the projects (cairo, libffi, zarith, zstd, ssl, zlib).
This line exists because the term outlived its retirement in this very
file and got copied into fresh docs from here (2026-09-16, user).

**Read `src/canary/base/` before writing code that introduces a type.**
`base/` is the shared vocabulary every layer reuses; a new vocabulary
type belongs there (in `canary_basic`/`canary_store`/`canary_lang`/
`canary_mechanism`/`canary_surface`/`canary_artifact_api`), not invented
in an upper layer — and check base/ for an existing type before adding
one. The base vocabulary types:

| module | types |
| --- | --- |
| `base/canary_lang.ml` | `lang` |
| `base/canary_basic.ml` | `artifact_kind` (what the scenario enumeration ranges over), `action`, `channel` (`Dev`/`Stable` release role) + concrete `version` record, `runner_os`, `probe_action`, `compile_mode`, output-tree naming (`filename`, `variant_file`) |
| `base/canary_store.ml` | `location`, `artifact_status` (lifecycle state), `provision` (provenance axis — ssot §4.2), `package_manager`, `pm_info`, `system_package_spec`, `distro`, `source_repo` |
| `base/canary_artifact_api.ml` | `native_api`, `binding_api` (provider/consumer claims) |
| `base/canary_mechanism.ml` | `discipline`, `mechanism` (binding identity — ssot §4.2.1b) |
| `base/canary_surface.ml` | `native_surface`, `binding_surface`, `surface` (checking-point view) |
| `base/canary_action_family.ml` | `t` — an action with its LANGUAGE erased (`Probe_binding OCaml` → `Probe_binding`); `of_action` (total), `of_catalogue`. What the overview's language-free edges name (2026-09-23; names are placeholders, user) |
| `base/canary_pm_action.ml` | WHAT A PACKAGE MANAGER DOES INSIDE ONE OF OUR ACTIONS (2026-09-23): `does` (`Resolve` \| `Build_package`), `unseen` (`Not_yet how` \| `Out_of_reach why`), `placeholder`, and `inside_install pm ~of_binding` — per PM, the pieces canary does not record. The pipeline derives PLACEHOLDER STEPS from it for every non-dummy fetch (`fetch_lib_apt_policy`, `fetch_binding_ocaml_opam_{plan,solver,build}`): no work, a marker, a `placeholder` log event, `step.placeholder`, placed `Placeholder_for` edges; the overview draws a marker and reads an unperformed action edge as `inside`. Not a dummy. The seed of a PM-solo catalogue (status.md §2.7) |
| `base/canary_bridge.ml` | `t` — A BRIDGE IS A THING (user, 2026-09-23): package content that exists for cooperation between two package managers, a variant PER PM (`Opam (Conf_package _ \| Depext_field _)`), kept apart from the PM drivers' common components. `of_gate` derives the bridge a `pm_dep_gate` names (the constraint stays on the gate — the depends edge); `has_check`. A capability file (`.pc`, META) is NOT a bridge — it is package-layer, owned by the package that ships it, a source of claims. status.md §2.7 E |

Example of the trap this prevents: `provision` and a redundant `slot`
subset type were first defined in `action/canary_enumerate.ml`; `provision`
is base vocabulary (now in `canary_store`), and `slot` was dropped
entirely — the enumeration ranges over the existing `canary_basic.artifact_kind`
(re-exported by `canary_enumerate` as `artifact`). `canary_store.artifact_status`
likewise already existed as a related provenance/state type — worth
reconciling with, not duplicating.

### Key source files

| File                                                | Purpose                                                                                                |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `src/bin/canary_main.ml`                            | CLI: `action`, `paths`, `graph`, `compat`, `verify`, `inspect-diff`, `artifact-test`, `pm-test`, …     |
| `src/canary/base/canary_lang.ml`                    | `type lang = OCaml \| Python \| …`; sibling file so `canary_basic` + `canary_store` can both use it    |
| `src/canary/base/canary_basic.ml`                   | `artifact_kind`, `kind_order`, `action` (constructor type; was `rule` pre-2026-07-21), `string_of_action`/`action_of_string`, `step_body` (legacy shell carrier), `version`, `filename`, `variant_file` — live vocabulary including output-tree naming |
| `src/canary/base/canary_store.ml`                   | `location`, `package_manager`, `source_repo`, `distro`, `pm_properties` types (was canary_pm_types)    |
| `src/canary/base/canary_artifact.ml`                | Artifact IDENTITY: `artifact_info` (a SUM since 2026-08-24 — `A_binding of lang * mechanism`, `A_app of app_wiring`, …; was a `{ kind; ext }` record whose pairing was convention-only), `A_lib of string option` since 2026-08-25 — `None` = "this project has one lib", still printing plain `lib` so no id moved; `Some n` names one of several, step 1 of multi_lib §3a), `kind_of` projecting the coarse `artifact_kind`, `mechanism_of`/`wiring_of`/`lib_name_of` for the refinements (`artifact_ext`/`ext_of` retired the same day — every consumer wanted something narrower), the `a_*` smart constructors, `artifact_axes`, `project_spec`, `placement`, `assignment` |
| `src/canary/base/canary_artifact_api.ml`            | Declarative `native_api` / `binding_api` types (provider/consumer claims, watchlists) — facts about library APIs |
| `src/canary/base/canary_mechanism.ml`               | Binding `discipline` (`Static_c_abi`\|`Dynamic_ffi`) + `mechanism` (`Cstubs`/`Cext`/`Ctypes`/`Cffi`/`Dynlink`) + `discipline_of_mechanism` + `default_mechanism_of_lang` (ssot §4.2.1b). Round 1 wires only Static. |
| `src/canary/base/canary_surface.ml`                 | `native_surface` / `binding_surface` / `surface` + `surface_of_api` — checking-point view (watchlists), provenance dropped (S1 of the detection-first redesign) |
| `src/canary/agreement/canary_agreement.ml`           | **TIER 3 — THE LIST AND THE VIEWS** (was `canary_agreement_registry.ml`, renamed 2026-09-02 for reading: it names the thing, not the shape of it, and sorts ahead of the families). A row is a NAME + doc anchor + enabled flag; the agreement itself comes from the family. Everything else is derived — `evaluate_in_context` (THE production path: action + mechanism + lang + world → selected methods → resolved evidence → `outcome`), `evaluate_over_inputs` / `predicted_by_agreement` / `predicted_contains_any` (the project-supplied-input path the compat expectations still use), `inputs_of_agreement`, `agreement_fixtures`, the firing table + fill list, `proposed_agreements`, `all_agreements`/`pp_agreements`/`pp_catalogue`, `agreements_for`. Holds NO per-agreement description of any kind. Design: `doc/canary/design/agreement/README.md` |
| `src/canary/agreement/canary_agreement_common.ml`     | **TIER 1 — what every family needs** (was `canary_agreement.ml`): the descriptive types an agreement uses to describe itself (`subject`, `claim`, `basis`, and the `agreement` record), the `checking_method` record (kind · reference · applicability · firing · inputs · evaluator-or-planned-reason · diagnostics · limits · counterexamples) and `evaluate_method`, the `outcome` type (holds/violated/unavailable/inconclusive/not_implemented/not_applicable/disabled/error), the `inspect_input` ADT that NAMES evidence — including the `Declared_*` constructors that make a declaration comparison the same shape as a peer comparison — `agreement_id` (12 descriptive constructors), the `evaluation_schema` cache epoch, the shared firing derivations + `binding_evidence_tag` + `uniform_world`, and the JSON primitives. Membership rule: a family owns what is only about its topic; this owns what more than one family needs |
| `src/canary/agreement/canary_agreement_<topic>.ml`   | **TIER 2 — ONE MODULE PER CHECK FAMILY** (was `canary_chk_*`, renamed 2026-09-02: the FILE names the agreement, the FUNCTION names the act — it had been backwards on both sides). symbols · api_surface · identity · types · behaviour · staging · bridge, each referring only to tier 1. One shape, top to bottom: the EVIDENCE it reads (records + loaders) → the COMPARATORS → the EVALUATORS → the AGREEMENTS it hands the registry, gathered last as `checks : (agreement_id * agreement) list`. A family holds every agreement about its topic, INCLUDING what used to be a second "cell" of one id: an artifact-vs-declaration claim and an artifact-vs-peer claim are two agreements with two names (2026-09-12). `canary_agreement_composed.ml` is NOT a family: it declares `composes` and reads other families' verdicts (`repack_complete` = `signatures_agree` ∧ `required_symbols_exported` ∧ `repack_preserves_api`, and reports `not_implemented` until they exist). **A family is DEFINED as a module publishing `checks` and no `composes`** — a property, not a filename, so renames cannot blind the pins: `agreements.families_do_not_reach_sideways` + `agreements.families_share_one_shape` + `agreements.families_declare_the_catalogue` |
| `src/canary/agreement/canary_agreement_ocaml.ml`     | **TIER 1, per LANGUAGE** (2026-09-03, the first of these): what every OCaml binding has whatever its mechanism — `user_surface` (the installed `.mli` → `inspect_mli.json`). Read by a family, so it sits below them and publishes no `checks` — not a family. A family states the CLAIM (neutral); the language states its SURFACE |
| `src/canary/agreement/canary_agreement_cstubs.ml`    | **TIER 1, per MECHANISM**: everything about the compiled consumer artifact — `produces_a_compiled_stub`, `records_needed_in_a_readable_artifact = false` (a `.a` archive carries no NEEDED/SONAME; those appear at link time), `typed_stub_surface` (the `external` decls, scanned from SOURCE). The axis is the MECHANISM, not the language: OCaml's cstubs and dynlink share no artifact, and cstubs has more in common with Python's cext. The four `is_dynamic` guards in the families approximate that table with one bit; a gathering module is the natural next step when a second mechanism lands. Both files pinned by `agreements.surface_facts_live_with_their_owner` |
| `src/canary/main/canary_agreement_report.ml`        | `canary compat` / `canary verify` — the two on-demand reports, plus the output-tree navigation they alone use (which is canary's LAYOUT convention, not agreement material). Moved out of the agreement layer 2026-09-02 (was `canary_compat_run.ml`): cached-summary lookup + the family comparators it prints (`load_stub`/`load_native`/`check_c_compat`, the watchlist loader) + CLI run/verify. The TABLE and its iterators moved to the registry 2026-09-01, so this file holds no agreement list |
| `src/canary/tool/canary_toolchain.ml`               | OCaml toolchain types, opam packaging helpers, `pip_install_cmd` / `python_probe_only_cmd`             |
| `src/canary/tool/canary_build_cmd.ml`               | Generic build-tool primitives: `cmake_configure_cmd`, `ninja_build_cmd`, `dune_build_cmd`, `with_marker` |
| `src/canary/tool/canary_store_config.ml`            | `provision_spec` — ONE origin per admissible provision (`Fetched of provider` \| `Built_from of artifact_info` \| `Installed` \| `Vendored_at` \| `Absent`; 2026-08-25, replacing the coarse-universe + separate-provider pair) + `provision_of_spec` / `producing_action_of` / `fetch_provider_of`; `provider` (the fetch origins) + `store_config` + `binding_store` / `lib_store` + `binding_pm` |
| `src/canary/tool/canary_artifact_native.ml`         | nm-based native lib summaries; `--emit-symbols` for compat cross-check                                 |
| `src/canary/tool/canary_artifact_lang.ml`           | OCaml + Python summary helpers (mli, stub, ocamlobjinfo, `dir()`)                                      |
| `src/canary/tool/canary_artifact_source.ml`         | Source artifact helpers; `scan_source` post-fetch verification                                         |
| `src/canary/tool/canary_inspect_diff.ml`            | `canary inspect-diff` — counts/modules/watchlist/versioned_req drift                                   |
| `src/canary/tool/canary_pm_{apt,brew,opam,pip}.ml`  | Per-PM presence checks + install commands; `canary_pm_test.ml` runs the suite                          |
| `src/canary/tool/canary_pm_solo.ml`                 | THE PM-SOLO TABLE CANARY COVERS (2026-09-23): one row per package manager with a driver (apt, brew, opam, pip). Scope/store READ from the drivers' `properties` (`Canary_pm.properties`, their first reader), bridge kinds from `Canary_bridge.kinds_of_pm`, unseen pieces from `Canary_pm_action`; three prose columns written against the draft's Table 1. With the mechanism catalogue (binding table) and `Canary_topology.coop` / `coop_catalogue` (cooperation table), it is overview §5 — a chain = one mechanism + two PM-solo rows + one cooperation. Pinned by `overview.tables_list_what_canary_covers` |
| `src/canary/tool/canary_bridge_driver.ml`           | THE BRIDGE'S TOOL-LAYER MODEL (2026-09-23, status.md §2.7 E1): what a conf package answers (installed version, depexts, predicate) and how canary DISPATCHES its check in a world — the predicate's own pkg-config invocation, filters evaluated against `opam var`. `record_cmd` → `canary/scripts/inspect_bridge.py` (record into the step's `inspect.json`, kind `bridge`; the SCRIPT exits 0 holds / 1 does not / 3 not dispatchable, but since 2026-09-27 the STEP passes whenever the record is written — the verdict is `gate_admits_the_world`'s, `canary_agreement_bridge.ml`, read at the binding's probe, which depends on the bridge step; tag shared through `Canary_agreement_common.bridge_record_tag`, pinned by `steps.gate_is_read_after_its_bridge_runs`). Every PM question is a driver template (`questions`); `record_fields` = what readers may rely on, asserted by artifact-test. A step that drives a bridge carries it in `step.bridge`, the install's action, no agreement context, and sits on `conf_probe`; `runner_spec.bridges` asks for one (zarith only today) |
| `src/canary/action/canary.ml`                       | 27-line `include` shim (Canary_action + Canary_step_model + Canary_path_table); still consumed by `canary_project_llvm.ml` + `canary_diagram.ml` via `open Canary`. |
| `src/canary/action/canary_action.ml`                | `action_graph` (was `action_rule` pre-2026-07-21), `store_actions`, `make_action_graph`, `nodes_of_action_graph`, `node_status`, `artifacts_of_action` (colocated 2026-07-22) — the action-graph schema + per-action consumes/produces (SSOT §6.5) |
| `src/canary/action/canary_step_model.ml`            | `step_expectation` (incl. `Expect_compat_failure`), `step` (was `action_step` pre-2026-07-21), `logger`, `version_info`, `symbol_*` |
| `src/canary/action/canary_path_table.ml`            | 15-pattern table + `pp_job_path_table` / `pp_job_path_table_md` (CLI `paths` / `paths-md`)             |
| `src/canary/action/canary_binding_templates.ml`     | M2 step 4 realization: `binding_decl` × ctx → build_binding/probe_binding/probe_lib/user_facing_pkg cmd builders (tiny consumes it; pinned byte-equal to the former hand-written literals) |
| `src/canary/action/canary_step_builder.ml`          | `runner_spec` (was `project_spec` pre-2026-07-21), `derive_steps`, shared command templates, check_post compositors — the step list builder |
| `src/canary/action/canary_scenario.ml`              | `scenario` type + Sc.1..Sc.6 patterns (`good_scenarios`); mutation vocab (`mutation_kind`, `origin`); contract binding vocab (`firing_site`, `loc_filter`, `expectation_source`, `firing`, `agreement_binding`); `lower_expectation_agnostic` — THE one expectation lowering since A7 (the oracle variant retired; tiny1 composes it as a factory combinator); `derive_scenarios`; `related_artifacts_of_actions`. |
| ~~`canary_scenario_util.ml`~~ (deleted 2026-08-05)  | Folded back into `canary_tiny_scenario.ml` — the "project-agnostic scenario helpers" never gained a second consumer. |
| `src/canary/action/canary_scenario_coverage.ml`     | Store-lifecycle **abstract-stage** catalogue + per-project coverage marks (`Covered`/`Unspecified`/`Disabled` → `✓`/`-`/`⊘`). `run_app` realized by `Probe_app`\|`Probe_binding`; `build_binding` gated on `is_static_binding_lang`. Drives `canary scenarios`. |
| `src/canary/action/canary_enumerate.ml`             | The `(provision × version × mutation)` enumeration algorithm (ssot §4.2) — pure product-then-filter, polymorphic in the mutation. Ranges over `artifact` (= `Canary_basic.artifact_kind`); `placement` (per-artifact provision + version), `run_config`/`level`/`config`, `tiny_slice`/`general_slice`, `provision_of_actions`. Folds into `canary_scenario.ml` when the convergence's replacement lands. |
| ~~`canary_project.ml`~~ (deleted 2026-08-05, A6)    | The `Canary_project.project` bundle was never read by anything — `Canary_project_run.project_run` IS the project identity (§6.1 top) for generic projects; contract bindings live where consumed (`*_agreement_bindings` → expectation lowering). |
| `src/canary/backend/canary_local_runner.ml`         | `run_step`, `run_graph`, `merge_step_statuses` + the cross-run cache (`load_cache`, `cache_is_success`, …) — executes the step list locally (in-process backend) |
| `src/canary/backend/canary_run_info.ml`              | `run_info` + `run_project` / `run_project_multi` orchestrators + `save_run_state` / `view_project`     |
| `src/canary/backend/canary_gh.ml`           | GitHub Actions YAML rendering; resolves `Expect_compat_failure` predictions at gen time                |
| `src/canary/backend/canary_detect.ml`               | Forecast-agnostic detection (S5a): `finding` (`tag`/`errored`/`output_present`) + `simple_finding` — classify a step by its raw outcome, independent of any expectation/contract |
| `src/canary/backend/canary_status.ml`               | `canary status` — per-scenario last-run verdict matrix (`xfail`/`✓`/`✗`/`·`) + `-v` witness lines (tails result files); `projects_with_runs` for `@all` |
| `src/canary/backend/canary_diagram.ml`              | Mermaid diagram + view machinery (2283 LOC; biggest single file)                                       |
| `src/canary/test/canary_artifact_test.ml`           | Framework self-tests (native, OCaml, Python, compat helpers — pure + shell)                            |
| `src/canary/test/canary_pm_test.ml`                 | PM module self-tests                                                                                   |
| `src/canary/test/canary_project_test.ml`            | Project-definition layer tests (`canary project-test`) — pure: action consumes/produces catalogue, surface split, store-config derive, detect, coverage abstract stages, mechanism defaults, enumerate two-projections |
| `src/canary/main/canary_test_<subject>.ml`          | The rest of `canary project-test`, one file per subject: `projects`, `pipeline`, `record`, `overview`, `env`, with shared fixtures in `canary_test_fixtures.ml`. `canary_tests.ml` joins their `tests` lists. A new pin goes in its subject's list, or `tests.every_written_pin_runs` fails, and states its claim in one sentence, `holds`, which the overview page lists (`tests.every_pin_says_what_it_holds`) |
| `src/canary/project/canary_project_sqlite.ml`      | sqlite3 project spec; OCaml + Python (stdlib) probes                                                   |
| `src/canary/project/canary_project_ssl.ml`         | OpenSSL/`ssl` project; variant matrix (`variants` = 0.6.0/0.7.0 × core/native-lib-version) via `mk_variant`; folded native probe. All fetch-origin (Level A). |
| `src/canary/project/canary_project_cairo.ml`       | cairo project via `Canary_opam_binding` (conf-* + opam binding); Level A                                  |
| `src/canary/project/canary_project_zarith.ml`      | zarith project via `Canary_opam_binding` (conf-* + opam binding); Level A                                 |
| `src/canary/project/canary_project_torch.ml`       | torch project (2026-08-30). NOT the opam-binding template — the registry's first lib whose stable point is **opam** (`libtorch.2.1.2+linux-x86_64`, an unzipped upstream binary), first `Cpp_api`, and first mangled-C++ surface (87,877 symbols; prefixes must be Itanium-spelled — `_ZN2at`, not `at::`). 2 scenarios = the binding's two PACKAGINGS at one version: stock `torch.v0.17.0` (a declared build xfail — it does not build with dune 3.23.1) and the canary-local `v0.17.0-canary1` carrying the one-line upstream fix. The version axis genuinely has one point (on OCaml 5.4.1, v0.16 and the 0.x series need `base/core < v0.17`). The lib's 2.2.1 point is named and unrealized |
| `src/canary/project/canary_project_llvm.ml`        | LLVM spec, a `project_run` (its worlds are in Build & Run). The released-binding world's OCaml probe expects the `Opcode.UncondBr` compat failure, derived through `Canary_scenario.lower_expectation_agnostic` over `llvm_stable_agreement_bindings`. |
| `src/canary/project/canary_project_z3.ml`          | z3 spec, a `project_run` (its worlds are in Build & Run). Its Python probe expects the `z3.parser_context` compat failure, derived through `lower_expectation_agnostic` over `z3_agreement_bindings`. |
| `src/canary/project/canary_tiny_scenario.ml`       | Tiny's whole scenario engine + factory: scenario_spec type, all_scenario_specs (15 hand + 7 derived = 22), tiny_agreement_bindings, recipe_of_derived_cell, make_base_runner_spec, project_spec_of_entry, tiny_project bundle. See `doc/canary/worklog/tiny_migration.md`. |
| `src/canary/project/canary_tiny_baseline.ml`       | `canary tiny baseline` — direct-compile clean tree + 7 inspectors + workspace materialization. |
| `src/canary/project/canary_tiny_prepare.ml`        | `canary tiny prepare[-all]` + `confirm` — sandbox-build model (live tree never mutated); surface_delta mirrors retired Python `_surface_delta`. |
| `src/canary/project/canary_tiny_workspace.ml`      | Workspace materialization for tiny scenarios: mutation dispatch (Source / Native / Binding via `canary_artifact_mutation.ml`), RUNPATH strip on cached cext, `libtiny.so` symlink synthesis. Framework infra — do NOT copy per-project (see `enumeration/stage6_realize_steps.md` §2). |
| `src/canary/main/canary_overview_runs.ml`           | **THE OVERVIEW'S RECORDED RUNS**: one `view` per recorded world × binding language, written to `docs/canary/overview_runs.js` (per machine; a `--platform` render goes to `_out/`) — each edge's state from the steps `Canary_topology.place_step` put there (worst first), badges from its claims' outcomes, node names (recorded inspections first, through `Canary_matrix.reading_of_inspection`, declarations second, each with its `source`), §1.2's counts and outcomes, what the chain lacks (`gone`), the nodes to dim, and a bridge step's record around the bridge. The page's script only applies these words; every rule is here, where the pins hold it. See design/overview.md §2–§4 |
| `src/canary/main/canary_overview_join.ml`           | **§1'S CHOICES, AS DATA** (2026-09-24, status.md §2.7): the package managers per side (`pms`, split by the drivers' scope), the concrete chains (`cases_of` — §5.4's rows, ONE list both render; each with its own band over its worlds and its project's DECLARED node names, never a run's), `dependent_pms` (the PM shipping a mechanism's LANGUAGE's bindings, read from the chains), every (cooperation, native PM, language PM) choice some chain has with its narrowed band (`jn_bands`, keys `kind\|pm\|pm` with `*`), the chains each choice picks out (`jn_runs`), the default choice and its drawing, and `json` — what the page embeds and its script only looks up. Pinned by overview.chain_choices_draw_one_chain |
| `src/canary/project/canary_topology.ml`             | **THE COOPERATION MODEL** (2026-09-22/23): who supplies each side and what joins them (`t`, `joining`, `gated`); the cooperation catalogue (`coop`, `coop_catalogue` — §5.3's rows); per WORLD `topology_of_world` / `coop_of_world` (world-level, so beside firing, not pass 2); the layered graph (`nodes`, `edges` — hand-written) and `place_step` (a step's edges; a placeholder stands only on edges its chain has); the two bands — `artifact_variant_of` per mechanism, `band_hidden` / `band_dead` per topology (one rule per node; unknown is not absent), `band_instances` + `band_over ?native ?lang` (a kind's band = what none of its worlds with the chosen PMs has; `coop_bands` = over all), `native_pm_of` / `lang_pm_of` (a chain's two PM nodes); `chain_gone` / `world_gone` (what a chain lacks) and `claim_applies` (a claim applies where one of its edges exists); `claim_sites` — WHERE each agreement sits, and nothing else: whether it is checked is the REGISTRY's answer (`implemented`; per mechanism `claim_state` = pass 2's `carried_slugs`; `edge_claims` = what an edge's two badges count), since a hand-written `cs_implemented` flag called three planned agreements implemented (2026-09-24). Pinned by overview.package_band_is_one_cooperation (the rules reproduce every hand-drawn case) and overview.badges_count_what_applies |
| `src/canary/main/canary_manifest.ml`                | **WHAT A RUN REALIZED** (2026-09-28, design/overview.md §6.4 step 6): the runner writes, per world it runs, its realized steps to `_out/canary/projects/<p>/-run/manifest/<world>.json` (tag, action, location, inspects, dummy, bridge, placeholder, deps + machine and switch); `Canary_matrix.matrix_of` reads it and re-derives from today's code only where no run wrote one — `row.steps_from` = `run` / `code` (exported). Codec total over the types (`Canary_basic.all_actions` enumerates the action type, and `action_of_string` reads a name back against it). Pinned by manifest.records_what_a_run_realized. Not yet: typed log events, inspection summaries logged once |
| `src/canary/project/canary_frames.ml`               | **THE TABLES' COLUMN MODEL** (2026-09-28, design/overview.md §6.4, prototype A confirmed by the user): `frames` — one frame per connected group of an action family's edges on the overview's graph, sibling edges (same inputs, products in one layer) merged into one PIECE, pieces in flow order, frames by side (system · binding · language · program) then flow; per frame the `Node` columns it consumes and produces (repeating across frames where consumed), its `Piece`s, and a `Check` per agreement with an evaluator at each of its site edges — a verdict after the site's products, a requirement before the piece making the frame's artifacts (or after the site's products when a later action needs it). Header of the result table once the matrix joins the overview page, and of §2. `canary checks --frames`; pinned by frames.derive_the_confirmed_layout |
| `src/canary/project/canary_project_analysis.ml`     | **PASS 2 — ANALYSE** (2026-09-16): `project_run -> t`. Pure, world-free. `an_spec` (pass 1's, carried), `an_chains` (which of the 38 universal chains this spec admits — was the pass table's unnumbered *(branch)*), `an_declared`, `an_mechanisms`, `an_unsuited`, **`an_touches`** (THE JOIN: per action, which DECLARED artifacts it consumes/produces, in refined identities and as LISTS), `an_carries`. Ask it: `carries`/`suits` (applicability — ONE answer, both the result table and the check index route here), `mechanism_for`, `langs`, `touches`/`produced_at`/`producers_of` (the hook's questions). MEMBERSHIP RULE: a fact belongs here iff it needs NO WORLD — applicability does, FIRING does not and stays at realize. Dump: `canary emit <p> --stage analyse` |
| `src/canary/project/canary_opam_binding.ml`           | THE OPAM-BINDING TEMPLATE (conf-* + opam binding); consumed by zarith + ssl + cairo + libffi specs. ⚠ NOT "Pattern A" — the survey's letters are an ECOSYSTEM taxonomy, not canary's categories; see the note under "Key source files" |
| `src/canary/project/canary_registry.ml`            | `all_projects` — THE single source of truth for project names (`Project` | `Multi`); `project_of` lookup. One entry per project; `action`/`spec`/`scenarios` dispatch through it. |
| `src/canary/project/canary_run.ml`                 | GH CI job specs (`ci_jobs`); z3/llvm source-build CI steps + opam-binding smoke jobs                     |
| `canary/examples/llvm/llvm_example.ml`         | LLVM 16+ example (create_context)                                                                      |
| `canary/examples/llvm/llvm_example_dev.ml`     | LLVM 21+ example (Opcode.UncondBr); fails against llvm.19-shared                                       |
| `canary/examples/llvm/llvm_example_19.ml`      | LLVM ≤20 example (Opcode.Br); fails against dev binding                                                |
| `canary/examples/llvm/llvm_example_15.ml`      | LLVM ≤15 example (global_context); fails against LLVM 16+                                              |
| `canary/templates/opam-local-repo/`            | Local opam packages: z3.dev, llvm.dev-shared, llvm.19-shared, llvm.19-static, conf-llvm-shared.dev/19  |
| `canary/scripts/inspect_native.py`           | nm parser → `kind: native` summary (counts, by_prefix, versioned_req, optional symbol list)            |
| `canary/scripts/inspect_binding.py`          | mli + stub `.a` parser → `ocaml_mli` / `c_stub` summaries; consumer-side L0/L3 surface                 |
| `canary/scripts/inspect_ocaml.py`            | ocamlobjinfo parser → `ocaml` summary (module list)                                                    |
| `canary/scripts/inspect_python.py`           | Python `dir()` parser → `python` summary (attrs + watchlist + extras)                                  |
| `canary/scripts/inspect_bridge.py`           | Bridge recorder → `bridge` record (what a conf package is, what its check answered here); runs only the templates it is handed plus the predicate's own pkg-config. `--parse-predicate` for tests |
| `doc/canary/index.md`                          | **THE doc index** — every file under `doc/canary/`, grouped by intent. A new doc gets its row there; the rows below are only the ones a coding session hits constantly |
| `doc/canary/design/index.md`                   | Design narrative: vision, action graph, store model, workflow stages, design principles               |
| `doc/canary/design/enumeration/stage6_realize_steps.md` | **Pass 6, realize** (`world → steps`) — the action catalogue, `realize ∘ dispatch` → `derive_steps` → verdicts, the TWO dependency relations and their drift, the run cache and its blind spot (input-artifact identity), deploy-mismatch, pre-run ≡ post-run. **§2b THE OCCASION** (2026-09-16) — when a check fires: the three gates (applicability at pass 2, firing here, evidence at run time), what realize attaches, why evaluation is not a further pass, where the evidence address comes from. Absorbed `algorithm_explainer.md` |
| `doc/canary/design/enumeration/stage2_analyse_spec.md` | **Pass 2, analyse** (`spec → spec, enriched`) — what canary DERIVES before any world. The membership rule (no world ⇒ here), why it is a pass and not a second branch, the three-views-two-answers bug it closed, §5 the join, §8 ⚠ the mechanism declaration it does NOT read |
| `doc/canary/design/action_model.md` | **What an action IS, and what `_post` means** (2026-09-16) — a hook is a MOMENT, not a specification of what runs at it; the join a hook needs; `probe_lib` as three roles (existence · inspection · execution — nothing ever `dlopen`s a lib); the THREE locator vocabularies that block deriving an inspection; §6 the ordered remainder |
| `doc/canary/design/ssot.md`                    | Project-wide SSOT — canonical ID tables (Ar/Sf/Ag/Sc/scenarios/actions) bridging manuscript ↔ code    |
| `doc/canary/design/enumeration/stage0_naming.md` | **Vocabulary, not a pass** — naming & classification — the four senses (scenario / pattern / stage / path pattern). Replaces the retired `scenario_terms.md` |
| `doc/canary/design/enumeration/stage5_order_worlds.md` | **Pass 5, order** (`worlds → worlds`) — scenario identity + dedup (ambient vs identity-bearing), the GENERAL exclusive-resource principle (**partition a place, serialize a state**; opam switch / install prefix / build tree / findlib namespace), and run order grouped by required state |
| `doc/canary/project/opam_exclusive_store_issue.md` | opam's one-version-per-switch problem — ONE instance of pass 4's principle: what a pin costs, the per-version-switch measurement (`ocaml-system` = ~5 s), and the two open questions (which switch model; what a collateral rebuild is FOR) |
| `doc/canary/design/staged_parity.md` | Build tree vs install prefix as a CHECKING principle — completeness, integrity, parity, isolation (the isolation half generalized into pass 4) |
| `doc/canary/design/enumeration/README.md`       | **THE map** for the enumeration — the reading path, the pipeline (3 IRs / 5 passes), and ONE pass table giving each pass its doc, code and pins. Read before changing how scenarios are produced |
| `doc/canary/design/enumeration/stage4_select_worlds.md` | **Pass 4, select** (`worlds → worlds`) — what THIS run asked for: the selection type, `--thin` / `--refs` as a pass rather than a filter, and why "not running" now has two distinct answers (does not exist vs was not asked for) |
| `doc/canary/design/enumeration/stage3_enumerate_worlds.md` | **Pass 3, enumerate** (`spec → worlds`) — the five constraints that prune the product (`assignment_ok`, `ax_follows`, `binding_couples`, `source_ref_ok`, `shadow_filter`, `ref_filter`) and the over-generation each was written against |
| `doc/canary/design/enumeration/stage1_declare_spec.md` | **Pass 1, declare** (`surface → spec`) — what a project declares: rows, artifact identity, the provision × version universe, providers and the four things derived from them, versions (ambient vs identity-bearing), repo lifecycle, the channel pair, what cannot be declared. Absorbed the purged `repo_model.md` + `versioning.md` |
| `doc/canary/project/projects.md`               | **The project roster** — what exists: dimension model, per-project lib/binding axes + 2×2 status, landing history, candidates |
| `doc/canary/project/status_project.md`         | **The project layer's SOLO to-do tracker** — the ordered plan, general to-dos, the report milestone |
| `doc/canary/project/issues.md`                 | OPEN per-project findings, declaration gaps, chores — the standalone worklist |
| `doc/canary/project/landing.md`                | How to land a project: workflow, data structures, the testing harness that verifies each step |
| `doc/canary/research/draft.md`                 | **Manuscript-in-progress** (was `surface.md`, renamed 2026-08). Confirmed-content writeup; five-part spine (BB / SS / TT / CC / MM); backbone (rules / traces / worlds), PL notation, implementation slots. **Authoritative** for current framing. |
| `doc/canary/research/surface_draft/`           | **Materials collection** (split 2026-06-04, surface_theory.md removed). Older drafts split across `main.md`, `surface.md`, `principle.md`, `implementation.md` (§2.7 pointers, may be stale), `package.md`, `versioning.md`, `notation.md`. Mine for content; not authoritative. |
| `doc/canary/research/tiny.md`                  | Witness (current): minimal C lib + 3 bindings + 13-variant canary matrix + harness scenario table + findings |
| `doc/canary/research/plan.md`                  | Paper venues + milestones + **§4 the delivery pipeline** (theory → checker → world → finding → merged PR; status + owner per stage) + the open roadmap. Rewritten 2026-08-26: POPL purged, roadmap steps 1-7 compressed to their open items |
| `doc/canary/ops/install_targets.md`            | What `cmake --install` does per project — discovery patterns, rpath/layout coupling, failure modes (TODO #25/#40 both DONE) |
| `doc/canary/ops/llvm_build.md`                 | The MANUAL LLVM build that seeds canary's build tree — same dir, different configure                   |
| `doc/canary/backlog.md`                        | Lower-priority TODOs; api-compat group + new project spec group (see line below for current set)       |

### Architecture in one paragraph

`store_actions ~langs` and `artifacts_of_action` in
`action/canary_action.ml` define the universal action catalogue (SSOT
§6.5): what actions run + what artifacts each touches, per kind (Source
→ Headers → Lib → Binding → App, per language). `pattern_rows_of_paths`
in `action/canary_path_table.ml` enumerates 15 structural patterns
like `fetch_source → build_lib → build_binding`. A project provides a
`runner_spec` (`action/canary_step_builder.ml` — shell commands per
action) plus an `api_source` (declarative provider/consumer surface
— header paths, symbol prefixes, watchlists) plus (optionally) a
`<project>_agreement_bindings` list feeding
`Canary_scenario.lower_expectation` for per-firing failure predictions.
`derive_steps` walks the catalogue, filters by project capabilities,
attaches per-artifact summaries (mli, stub, native, python), and emits
a `step list`. Three sibling backends consume it:
`backend/canary_local_runner.ml` executes; `backend/canary_gh.ml`
renders GH Actions YAML; `backend/canary_diagram.ml` renders Mermaid
(a fourth, `canary_html.ml`, rendered the per-run result page and
retired with it on 2026-09-28 — a run is read on the overview page,
from the record). `run_graph` executes with
`check_pre`/`check_post` filesystem checks and appends to
`actions.log`. Probe expectations come from `Expect_success` |
`Expect_failure { contains_any }` | `Expect_compat_failure { inputs;
version_info }` — the compat-failure inputs are read at runtime by
`agreement/canary_agreement.ml`'s `predicted_contains_any ~resolve`
which evaluates the registered agreements over the inputs bag and turns
each violation into its predicted failure substrings. That is the
INPUT-DRIVEN path. Since 2026-09-12 a step also carries an
`agreement_ctx` (mechanism, lang, world) and the runner calls
`evaluate_in_context`, which SELECTS by action + applicability, resolves
each method's own evidence, evaluates, and logs one `agreement_outcome`
per method — including the planned ones, as `not_implemented` with their
reason. The top-level project identity is `Canary_project_run.project_run`
for generic projects (A6 2026-08-05: the never-read `Canary_project.project`
bundle was deleted); each project's module owns its scenarios directly
(tiny1 has 22 via factory). `run_project_multi`'s last consumer is ssl
(4 hand-listed variants); tiny's factory (`canary_tiny_scenario.ml`)
restricts each `runner_spec` to one scenario's world. **The project
registry** (`Canary_registry.all_projects`, 2026-08-12) is THE single
source of truth for project names — `action`/`spec`/`scenarios` each do
one `List.assoc_opt` lookup; adding a project = adding one entry
(`Project pr` runs via `run_project_run`, `Multi (name, variants)` via
`run_project_multi` — ssl only). Opam-binding projects wrap their
`runner_spec` via `Canary_project_run.simple`. **The generic
path** (tiny-full + sqlite + z3 + llvm since A5, 2026-08-05)
is `run_project_run` over a `Canary_project_run.project_run`
(`pr_spec → scenarios_of (the general enumerate; ?policy, --thin =
thin_policy) → pr_runner_spec → derive_steps → run`): a project declares
only DATA — `pr_spec` is ONE fused table (`ps_universe : artifact ×
(provision × versions) list`; old accessor names are functions over it),
`pr_artifacts` THE artifact table (`artifact_decl` rows: identity +
provider — the old separate `pr_provenance` assoc merged in 2026-08-06;
`provenance_of`/`artifact_infos` read it),
`pr_mismatch_probes` a design-intent table (which consumer variants are
designed forward/backward probes; per-scenario direction is COMPUTED via
`mismatch_direction_of`). `pr_runner_spec` must be `realize ∘ dispatch`
(pure project-local `scenario_case` data reading only
`Canary_enumerate.{provision_of,channel_of,provided,bad_placements}`;
`realize` holds the command templates — the only functions left). xfail
(`Step_done_xfail`, persisted in verdict-marker content) + watchlist
verdicts surface in `action`/`spec`/`status` (status rows show
`watchlist N/N` / `⚠ MISSING …`; sqlite's python watchlist carries
declared binding-lag markers). There is NO per-project enumeration
closure (`pr_enumerate` retired 2026-08-05); the runner
computes `scenario_dir_of a` (a born-safe per-scenario dir = output
path + dedup key; a `Fetched` artifact is version-ambient so its
declared version is NOT part of scenario identity — two `Fetched@v`
scenarios dedup). There is **no** `pr_materialize`/pre-place field:
tiny-full assembles its vendored tree INSIDE its `pr_runner_spec`
(the `materialize` symbol lives only in tiny-factory,
`canary_tiny_workspace`); a real project builds/fetches into the
runner-given dir. See SSOT §6.1 for the taxonomy
(project → scenario ≡ variant → runner_spec → step → action) and
`design/enumeration/stage6_realize_steps.md` §2 for what is data vs code.

### Two testing axes

Canary's test surface has two independent axes — both are kept alive because
either can silently break first:

| Axis                | Subcommand                               | Fails when …                                                                                                                                         |
| ------------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Project tests**   | `canary action <project>`                | The project under test drifts (new Z3 renames a symbol, LLVM adds Opcode)                                                                            |
| **Framework tests** | `canary artifact-test`, `canary pm-test` | Canary's own tool assumptions drift (`nm`/`ocamlobjinfo`/`ocamlfind`/`python3` change output format, `dir(sys)` loses an attr, shell pipe semantics) |

A green project run is meaningless if `nm` silently started emitting an
extra column and our parser discarded every symbol. Framework tests fix
known-stable fixtures (sqlite3.so, fmt.cmxa, Python sys/sqlite3) that
exercise every primitive canary depends on. Especially useful when
expanding to macOS (different `nm` flags, Mach-O format, keg-only paths)
or upgrading the OCaml / Python / distro runtime — framework tests
diagnose environment drift early.

Current framework tests cover "command runs, rc matches, JSON parses"
plus pure helper tests (compat helpers exercise `predicted_contains_any_v2`
against synthetic Ocaml_mli / Python_attrs fixtures). Stronger
content-shape invariants (e.g. `counts.total > 0` on libsqlite3.so,
`modules ≥ 1` on fmt.cmxa) are a candidate hardening step.

### Multi-version probe design

`canary action llvm` runs two sequential sub-runs sharing one opam switch:

| Sub-run   | Source                | Lib                 | Binding                    | Example               | Expected                           |
| --------- | --------------------- | ------------------- | -------------------------- | --------------------- | ---------------------------------- |
| `llvm`    | dev (ninja)           | dev libLLVM.so      | `llvm.dev-shared` (packed) | `llvm_example_dev.ml` | pass                               |
| `llvm/19` | local path (no build) | `llvm-19-dev` (apt) | `llvm.19-shared` (opam)    | `llvm_example_dev.ml` | **fail — Opcode.UncondBr unbound** |

`llvm_example_dev.ml` uses `Opcode.UncondBr` (added in LLVM 21, March 2026
commit #186176 — `br` split into `uncondbr+condbr`). Against `llvm.19-shared`
it fails to compile, demonstrating API mismatch. Sequential execution avoids
opam switch conflicts.

The expected-failure substring is no longer hand-written: llvm's
stable-variant `expectation` returns `Expect_compat_failure` and the runner
derives `Opcode.UncondBr` from the cached `fetch_ocaml_binding/inspect.json`
watchlist. z3's stable variant has a parallel Python case (`z3.parser_context`
missing from the z3-solver pip wheel) using
`Expect_compat_failure { inputs = Canary_compat.[ Python_attrs […] ]; … }`
(list-of-string-list syntax since the 2026-06-01 Phase 4 ADT unification).
See `surface_draft/implementation.md` §2.7.

### Current state

The live picture is [`doc/canary/status.md`](doc/canary/status.md): §1
where things stand, §2 what is open. Results are read on the overview
page (`make view`, `docs/canary/overview.html`); its plan and open items
are [`doc/canary/design/overview.md`](doc/canary/design/overview.md) §6.
An agent does not read `overview.html` or `overview_runs.js` whole (about
100 k and 190 k tokens): it queries `canary overview --json`, the runs
file's JSON, or `canary checks`.
Per-project findings are in
[`doc/canary/project/issues.md`](doc/canary/project/issues.md),
lower-priority items in [`doc/canary/backlog.md`](doc/canary/backlog.md),
and history in [`doc/canary/worklog/`](doc/canary/worklog/). The
agreement layer's September history, which this section carried until
2026-09-29, is
[`worklog_2026_09_agreements.md`](doc/canary/worklog/worklog_2026_09_agreements.md).

**Where the work is** (2026-09-29). The overview page is the one results
page. §1.2 has a row per chain (one world in one binding language) and
the diagram's frames as columns; §2 counts the same cells
(`Canary_matrix.chain_checks`), and §1's badges colour from them. Next is
phase E, the rest of the bridges (`design/overview.md` §6.1).

**Rules that history set, still in force:**

- **An agreement is landed** when a real project's run decides it
  (`holds` or `violated`), not when a fixture passes.
  `make canary-agreement-roundtrip`, inside `canary-post-check`, fails
  if sqlite's run stops deciding one of the landed ones.
- **Docs hold only what the page cannot say** (user, 2026-09-28), and a
  table a tool generates gets no hand copy: three did, and all three went
  stale the same way (2026-09-17).
- **The agreement docs are two files** in `design/agreement/` (user,
  2026-09-30): README (using the agreement table, then where agreements
  come from — the former theory.md) and components (the evidence,
  component by component, with the binding mechanisms — the former
  mechanism.md). The overview page's §2 is the catalogue. Do not
  recreate `theory.md`, `mechanism.md`, `agreements.md`, `model.md`,
  `runtime.md` or `landing.md` there. In these docs a `§` resolves
  against the file's own headings (a pin checks it), so name the
  overview page's sections in words.
- **A pin whose input vanishes is worse than no pin**, because it reports
  success. `agreements.pinned_docs_exist` holds every document a pin
  reads.
- **agreement/ owns the claim; enumeration/ owns the occasion.** When a
  check fires is `design/enumeration/stage6_realize_steps.md` §2b.

**Reading agreement state** (`canary` = `dune exec src/bin/canary_main.exe --`):

```sh
canary checks --agreement NAME      # one agreement, complete, and what recorded runs decided
canary checks --landing             # every agreement: landed or not
canary checks --firing              # where each rule ran (R) and where its check fires (D)
canary checks <project>             # what each action could decide, and the gaps by kind
canary checks <project> --observed  # what the project's last run evaluated, and to what
canary checks --dummies             # the steps that hold a place and do no work
make canary-refresh PROJECT=<p>     # re-run the deciding steps, clearing outcomes the registry outgrew
```

## Other Work: Yelu

Yelu is now a standalone project at `/home/red/code/research/yelu` with its own CLAUDE.md, build system, and opam package. It was extracted from `yelu/` on 2026-05-04. If you need to work on yelu, switch to that repo.

## Gotchas

- **Diagram connectivity invariant is MUTED by default** (2026-08-05): the
  diagram self-check "does the drawn `.mmd` reproduce every `step.deps` edge?"
  fails for **all four** projects (z3/llvm/sqlite/tiny-full) — the diagram's
  hand-built edge topology (`canary_diagram.ml`) and the runner's `step.deps` are
  two separate dependency relations that drifted. It is NOT a run bug (every step
  `check_pre` enforces its real deps; execution is sound) — only the picture
  under-connects. Gated behind `CANARY_DIAGRAM_CONN=1` (default off) so runs don't
  print "connectivity errors … SOME FAILED"; the coverage invariant still runs.
  Real fix = reconcile `step.deps` with the typed node graph into one relation
  (status §A "Merge cleanup"); diagram work is on hold.
- **`Fetched` is version-ambient in scenario identity**: `scenario_dir_of`
  (`canary_main.ml`) drops a `Fetched` placement's declared version from the
  scenario id (the PM picks the actual version), so `Fetched@Stable ≡ Fetched@Dev`
  dedup to one run; `Built`/`Vendored` versions ARE identity. Since the
  per-provision version axis (2026-08-05) specs no longer declare versions a
  Fetched artifact can't pin (sqlite declares 3, runs 3 — no dedup needed);
  the identity rule stays as the generic backstop. A project that pins a
  Fetched version would override via its provider (`pr_artifacts` row) — not wired yet.
- **Run-cache stale hit looks like a real PASS**: a step is skipped when its
  `.ok` marker exists and `check_post` passes (local cache), keyed by
  `variant_id` (the part after `/` in `project`, e.g. `tiny/<name>`). Re-running
  a *different* workspace under the **same** `variant_id` (e.g. a source-only
  Built tree reusing a name previously run Vendored) serves the stale marker —
  no build runs, but status reads PASS. Force a fresh run with `rm -rf
  _out/canary/projects/<name>` or a distinct `variant_id`. To coexist (Built vs
  Vendored, dev vs stable) put those axes in `variant_id`. See
  [`doc/canary/design/enumeration/stage6_realize_steps.md`](doc/canary/design/enumeration/stage6_realize_steps.md) §4.
- **OCaml LSP stale diagnostics**: Cross-module edits show false errors
  until dune rebuilds. ocamllsp reads compiled `.cmi` files; no
  in-memory cross-module resolution. Ignore during multi-file refactors,
  verify with `dune build` at the end.
- **`open Base` shadows stdlib**: `result`, `prefix`, `id`, `append`
  are shadowed — rename in pattern matches.
- **`open Base` shadows `=`/`<>` as INT-only comparisons**:
  `Int_replace_polymorphic_compare` (import0.ml) redefines `=`/`<>`/`<`/
  `>`/`<=`/`>=` as `int -> int -> bool` externals. `a = b` on strings or
  lists under `open Base` is a TYPE ERROR ("expected of type int/2").
  Use `Poly.equal` / `Poly.(<>)` for polymorphic equality, or
  `List.is_empty`/`Bool.equal` per the codebase idiom.
- **Mermaid v11+**: User's renderer supports `@{ shape: docs }` syntax.
  Safe to use modern Mermaid features in `.mmd` files.
- **Mermaid v11+**: User's renderer supports `@{ shape: docs }` syntax.
  Safe to use modern Mermaid features in `.mmd` files.
- **`opam config subst`**: expects `foo.in` → `foo`. The template must
  be named `.in`; the command is relative to cwd, not absolute.
- **z3 git submodule leftover**: if z3 source has a `.git` file (not
  dir) pointing to `../../.git/modules/z3`, cmake fails with "could
  not find commondir". Fix: convert to standalone repo (`rm .git`,
  `git clone --bare ... .git`, `git config core.bare false`).
- **Build tree vs opam-installed binding conflict**: `-package z3 -I
  build/src/api/ml` causes "inconsistent assumptions" because
  ocamlfind loads the opam version while `-I` adds build tree `.cmi`
  files. For build tree probes, use `-package zarith` (dep only) +
  explicit `z3ml.cmxa`, not `-package z3`.
- **`opam switch create` SETS the new switch as current.** Creating the
  canary switch silently made it ambient, and the next `dune build` failed
  with "Library core not found" — dune was looking for tola's own deps in a
  switch that had four packages. Not a canary bug and not obvious from the
  error. Use `--no-switch`, or `opam switch set default` right after.
- **opam sandbox is active on WSL**: `wrap-build-commands` is set
  globally to `[sandbox.sh "build"]` even on WSL — bwrap IS active.
  The switch-level `opam option wrap-build-commands` returns `[]` but
  that is the switch override (empty = inherit global), not a disable.
  bwrap mounts the home directory **read-only**: external paths like
  `CANARY_BUILD_DIR` are readable but not writable. Fix: guard cmake
  invocations with `test -f <artifact> || cmake ...` so cmake is skipped
  when artifacts already exist (canary has built them). CI also works:
  no `CANARY_BUILD_DIR` set, so `B=build` (local to sandbox), cmake
  runs fresh in a writable local dir.
- **ELF symbol versioning in nm output**: Linux shared libs (e.g., LLVM)
  use versioned symbols — `nm -D` outputs `LLVMAddAlias2@@LLVM_19.1`,
  not `LLVMAddAlias2`, so a parser anchored on a bare name (`\w+$`)
  silently matches nothing. `canary/scripts/inspect_native.py` splits the
  suffix: `@@VER` on a defined symbol is a versioned export, `@VER` on an
  undefined one a versioned requirement.
- **`find_llvm_config_cmd` composability**: it's a multi-line `if/elif/fi`
  shell expression. Cannot be safely nested inside `$()` as a sub-argument
  (e.g., `$(find_llvm_config_cmd --libdir)` is wrong). Always assign to a
  variable first: `LLVM_CONFIG=$(find_llvm_config_cmd)` then use `$LLVM_CONFIG`.
- **`$CAMLORIGIN/../..` breaks in opam flat layout**: LLVM's `llvm.cmxa`
  embeds `-L$CAMLORIGIN/../..` pointing to `libLLVM.so`. In the build tree
  (`build/lib/ocaml/llvm/`) this resolves to `build/lib/` ✓. After
  `ocamlfind install` to `lib/llvm/`, it resolves to the switch root ✗.
  Fix: append `linkopts = "-cclib -L<BUILD>/lib -cclib -Wl,-rpath,<BUILD>/lib"`
  to META. Proper fix (TODO #25): run `cmake --install` which regenerates cmxa.
- **`mktemp` in opam sandbox uses `/opam-tmp`, not `/tmp`**: bwrap sets
  `TMPDIR=/opam-tmp` (a tmpfs), so `mktemp` goes there. `/tmp` itself IS
  mounted rw (`--bind /tmp /tmp`), so explicit `/tmp/foo` paths work. Use
  `./name` (current dir = opam build dir, also rw) for simplicity.
- **`build_z3_ocaml_bindings` is a cmake PHONY target**: `add_custom_target`
  in cmake always generates a PHONY ninja target — ninja never considers it
  up-to-date and always reruns it. Deleting the canary `_out/` cache causes
  canary to re-run `configure` (cmake), which updates `CMakeFiles/` timestamps,
  which triggers a full z3 rebuild (~863 steps). Fix: TODO #26 artifact
  pre-check (`test -f z3ml.cmxa || ninja ...`). LLVM's `LLVM` target builds
  a concrete file (libLLVM.so) so ninja correctly skips it.
- **META.llvm `directory = "llvm"`**: OCaml archives are in a `llvm/`
  subdirectory of the build tree. Set `OCAMLPATH` to the parent
  (`build/lib/ocaml/`), not `build/lib/ocaml/llvm/`. Strip `directory`
  field when doing flat opam install.
- **cmake ANSI color codes corrupt hex pattern tests**: cmake adds `\x1b[0m`
  escape sequences to stderr when it detects a TTY. The `message/newline`
  compat test hex-encodes subprocess stderr — ANSI codes corrupt it. Fix:
  `cmake_runner.ml`'s `make_env` always injects `NO_COLOR=1`; never call
  `Unix.open_process_full` with `Unix.environment ()` directly in the runner.
- **The canary-local opam repo at rank 1 can shadow an official package**
  (salvaged 2026-08-30 from the retired `ops/ci_gh.md`, still live — the
  CI composite action registers that repo in every job). If a package
  directory under `canary/templates/opam-local-repo/` contains a
  materialised `opam` file rather than only the `opam.in` template, then
  `opam install <pkg>` resolves to the LOCAL package instead of the
  official one. Keep only `opam.in` in the repo; the `opam` file is
  generated by `opam config subst` at pack time.
- **opam colour breaks the world assertion — invisible until CI**
  (2026-08-27). `ocaml/setup-ocaml@v3` exports `OPAMCOLOR=always`, so
  `opam list --columns=version` answers `^[[01;35m5.1.0^[[0m` and the pin
  check compares that against `5.1.0` forever: *"WORLD MISMATCH: switch
  has sqlite3 5.1.0, scenario declares sqlite3 5.1.0"*. Fixed with
  `--color=never` in BOTH twins of that query — `Canary_world`'s
  `Opam_pin` shell and `Canary_pm_opam.version_of_cmd` (what
  `pin_check_post` compares). General rule, and the second instance of it
  in this file: **an assertion that compares tool OUTPUT must state the
  format it wants**, because the environment will otherwise choose one.
  Nothing sets `OPAMCOLOR` locally, so only CI could find this.
- **`.ml` / `.mli` are edited with `Edit` or `Write`, and with nothing else.**
  Stated as a whitelist on purpose: the old wording named sed and python, and
  the ways round it are endless — a `python3` heredoc doing an index-based
  block replace is not "python line-number editing", a `perl -0pi` is not
  "sed", `cat > file` is not "an edit". All of them are the same act and all
  of them are prohibited. Reading is unrestricted: `cat`, `sed -n`, `grep`,
  `python3` over a `.json` are all fine. The line is WRITING to OCaml source.

  Why the rule is absolute rather than a preference: a text tool cannot see
  match-case scope, `let`/`in` boundaries, or which `| _ -> None` is the
  intended anchor. It matches in several places when you meant one, it drifts
  after an earlier edit moved the lines, and a bad deletion takes adjacent
  code silently — the build may still pass. `git checkout` recovery costs
  hours. Real damage in this repo: a `_summary→_inspect` sed corrupted
  `binding_summary`; python line-number removals cut into `_counts_from_log`
  and `save_run_state`.

  `Edit` fails loudly instead: a stale or ambiguous anchor is an error, not a
  silent half-edit. When a change feels too big for `Edit`, that is a signal
  to split it, not to reach for a script. Edit → build → diff → commit after
  each working tier.
- **A DOCUMENT IS WRITTEN, NEVER ASSEMBLED** (2026-09-17, after a bad
  one). A script may MOVE a doc, RENAME it, or sweep a reference across
  the tree. It may not produce prose. When a task says merge, split,
  absorb or unify two documents, the deliverable is a document someone
  reads start to finish — not the union of the inputs with new headers
  over it.

  What went wrong, so the shape is recognisable: `model.md` +
  `landing.md` + `catalogue.md` were "merged" by a python script that
  sliced line ranges and glued them under new part numbers. Every
  sentence survived. The result told the same pipeline twice at two
  zooms, answered its own title only on page fifteen, carried three
  competing routing tables, numbered a section §4.9.1 because that is
  where the third file's §2.1 happened to land, and came to 2200 lines —
  longer than the three files it replaced.

  Three failures worth naming separately, because each is tempting on
  its own:
  - **Framing it as a file operation.** "Merge three files" invites a
    script; "write the document these three were trying to be" does not.
    The task is the second one even when the request says the first.
  - **Making "lose no content" the success criterion.** Slicing exact
    line ranges is provably lossless, which is why it feels safe. It is
    the wrong objective: concatenation preserves every sentence and
    destroys the document. Losing a paragraph that had stopped earning
    its place is the CHEAP error; the expensive one is shipping prose
    nobody can read.
  - **Letting the cost of the method choose the method.** Writing 2000
    lines through `Edit` is expensive and a script is one call. That is
    a fact about effort, not about the right deliverable.

  **And the pins cannot catch it.** `doc_names_live_code`,
  `doc_cross_refs_resolve`, `doc_anchors_exist`,
  `catalogue_doc_is_generated` all check mechanical properties —
  identifiers exist, `§` references resolve, generated regions match the
  registry. None of them can see that a document says the same thing
  twice. **Green pins on a doc change mean nothing about the document.**
  Read the result before claiming it is done; that read is the only
  check there is.
- **Catch-all ordering in `match`**: `| _ -> ...` or `| e -> ...` must come
  LAST.  Putting it first makes all patterns below unreachable.  The
  compiler warns `redundant-case` but doesn't error — the match silently
  ignores later patterns.
- **`python3-config` not universally available**: standard on
  systems with `python3-dev` (apt) / `python3-devel` (dnf) but
  venvs deliberately omit the `-config` wrapper, and some
  container distros strip `-dev` packages entirely. Use
  `python3 -c 'import sysconfig; print(sysconfig.get_paths()["include"])'`
  and `sysconfig.get_config_var("EXT_SUFFIX")` instead of shelling
  to `python3-config --includes`. Sysconfig is stdlib, works
  everywhere. See `canary_tiny_baseline.ml:build_python_cext`.
- **OCaml module name mangling: dune wrapping vs direct
  ocamlopt**: dune's default library-wrapping convention produces
  module names like `Tiny__` / `Tiny__Tiny_raw` / `Tiny` in a
  `.cmxa` (a wrapper module + submodules with underscore-doubled
  prefix). Direct `ocamlfind ocamlopt -a` without wrapping
  produces plain top-level modules `[Tiny_raw; Tiny]`. `bo6`
  inspection (`ocamlobjinfo`) reports the difference; any consumer
  that hardcodes specific mangled names (e.g. `Tiny__Foo`) will
  break under a direct-compile path. Watchlists that reference
  only the top-level module (`Tiny`, `Tiny.sum`) work either way.
  See `canary_tiny_baseline.ml:build_ocaml_binding` comment.

- **Artifact ids use `-` not `:` — born-safe for `$PATH`-like env vars.**
  `string_of_id` outputs `binding-ocaml-cstubs`, safe for `PYTHONPATH` /
  `LD_LIBRARY_PATH` which are `:`-separated. Never reintroduce `:` in ids.
- **A cached artifact must carry SOURCE, not just the built output** (Fix A):
  `subdirs_of_artifact` returns the built subdir **plus** the source the compat
  inspectors read (mli/headers/py). Overlaying only the built subdir left the
  base's good `.mli`/header in place, so source-manifested drift (a dropped val =
  C2) was invisible and the real failure read as *unexpected*. Terminology: the
  vendored bundle is a **cached artifact** (`cache_artifact`/`cached_artifact_dir`
  in `canary_tiny_workspace.ml`), NOT a "resource" — ssot uses artifact /
  artifact_kind.
- **Types shared by multiple `action/` modules belong in `base/`.**
  `canary_action.ml` once depended on `canary_enumerate.ml` for `build_id`,
  `assignment` — moved to `Canary_basic`/`Canary_artifact` (base/).
  Rule: put every type-like thing in `base/` unless only one module consumes it.
- **When moving types between modules, record fields and functions stay behind.**
  `type t = NewModule.t` creates an alias, but record fields belong to the module
  where the type is DEFINED (`pl.Canary_artifact.provision`, not
  `pl.Canary_enumerate.provision`). Functions on the type (`placement_of`, etc.)
  also stay in the original module unless explicitly moved. And `open Module`
  does not re-export — aliased types are not accessible through `EN.xxx`.

## Conventions

- `cc` = Claude Code (user shorthand)
- Allowed bash: `make *` and `dune *` only
- **Comments state the concluded design, briefly** (user, 2026-09-29):
  the sections, terms and workflows as they are now. The reasoning
  happens in the chat; the history belongs in the worklog and the commit
  messages. A later agent follows the conclusion; it does not need the
  argument that reached it. Much of today's code still carries long
  dated comments: shorten them when you move or change that code.

## Concurrent agents (worktrees)

Two agents work on this repo: a code session (this tree, `ds-workflow`)
and a project agent (`tola-m3`, branch `m3-agent`). Setup, 2026-08-14:

- **Commit first** — a new worktree bases off HEAD, so commit the
  working tree before `git worktree add` (the dune-scan fix and tiny
  cache relocation live in the tree, not at HEAD).
- `git worktree add /home/red/code/research/tola-m3 -b m3-agent`
- **Shared `_out`** — `tola-m3/_out` is a symlink to `../tola/_out`
  (cross-run cache + run outputs shared; the tiny factory cache lives
  there too, `_out/canary/tiny/`). Each tree's root `dune` excludes
  `_out` from the walk.
- **VSCode entry** — `tola/vendor/tola-m3` symlink → `../../tola-m3`
  (gitignored; `vendor` is dune `data_only_dirs` so no recursion).
  Add it as a workspace folder.
- **Sync on demand, not per commit** (2026-08-17, user) — each tree
  works independently; commits on one branch don't touch the other
  until a merge. The main→worktree `ff-only` sync happens only when
  the worktree agent resumes work or at merge-back time — no ritual
  after every commit. Conflicts (if any) surface at merge time and
  the merging side resolves them.
- **Merge back** — normal git: commit on `m3-agent`, then
  `git merge m3-agent` from `ds-workflow`; `git worktree remove
  tola-m3` and `git branch -d m3-agent` after. `_out` is gitignored
  and shared, so merges carry source only.
- **Overlap warning** (2026-08-17, user) — two streams touching the
  same shared-core files (project_run, specs, spec_check) was tried
  and judged a bad idea: parallel checkouts don't give parallel
  development. Shared-core changes happen in the MAIN tree
  (commit-first); the worktree is for genuinely disjoint chunks
  (new-project landings that mostly add files). The m3 agent is
  PAUSED (2026-08-17); its uncommitted leftovers may sit in either
  tree.
- Worktree caveats: cold dune build per tree (~minutes, done once);
  dune-scan fix inherited only if the base commit is recent; the
  tool-routing ratchet baselines are shared — resolve at merge time.

## Handoff Workflow

This file is the serialization layer for cross-machine continuity.
Local memory and chat context are ephemeral; CLAUDE.md is the durable
snapshot any fresh session on any machine can reconstruct from.

**Latest pickup note:
[`doc/canary/worklog/handoff_2026_08_26.md`](doc/canary/worklog/handoff_2026_08_26.md)**
(mac → WSL). The paper-plan half of the handoff: what the 2026-08-26
session changed, the ordered plan split into prose (author) / delivery
(agent-ownable), and the decisions waiting on the user. The macOS port
has its own checklist in
[`doc/canary/design/platform.md`](doc/canary/design/platform.md) §6–7.
A dated pickup note is the right form when work MOVES machines; this
file stays the durable snapshot.

**Before ending a session**, update this file with current state:

```
Update CLAUDE.md for handoff. Include these sections:
1. Build & Run — commands to build, test, run
2. Key Files — table of important files and their purpose
3. Architecture — one-paragraph summary of how things fit together
4. Current TODO — prioritized next steps
5. Gotchas — behavioral traps, things that wasted time, workarounds
   (include *why* for each)
6. Feedback — corrections or preferences I gave you during our sessions
   that should carry forward
7. Conventions — shorthand, naming patterns, style preferences
Check your memory files for gotchas and feedback material.
Commit the result.
```

**When starting on a new machine**, load context:

```
Read CLAUDE.md and familiarize yourself with the project. Save any
gotchas and feedback items to your local memory so they persist across
conversations on this machine.
```
