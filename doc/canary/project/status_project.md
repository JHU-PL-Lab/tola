# Project to-dos — the tracker

> The project layer's SOLO to-do list (2026-08-21). Everything the
> project agent owes is here or in [`issues.md`](issues.md); nothing
> else in `project/` carries a to-do.
>
> - **Here**: the ordered plan (§1), general/framework-level to-dos
>   (§2), the reporting milestone (§3).
> - [`issues.md`](issues.md): OPEN items tied to a PARTICULAR project —
>   findings, declaration gaps, per-project chores. A standalone
>   worklist another agent can own.
> - [`projects.md`](projects.md): what EXISTS — the roster, per-project
>   coverage and 2×2 status, landing history, candidates. Facts, not
>   to-dos.
> - [`landing.md`](landing.md): how to land one.
> - Framework status is [`../status.md`](../status.md); anything FIXED
>   is history and lives in [`../worklog/`](../worklog/).

## 1. The ordered plan

(2026-08-19, user asked for the action list.) Everything below is
agreed; the order is what matters. A–C are small and unblock the rest;
D is a real arc.

> **Model revisit (2026-08-20)** — the reruns that filled z3's
> `pre-10549` cells produced an ordered change list, absorbed 2026-08-24
> when `run_model_revisit.md` was purged. Item 1 (build steps redirect to
> a log; the detect event names it) LANDED as plan item A. The findings
> went to the docs that own them —
> [`../design/enumeration/stage6_report.md`](../design/enumeration/stage6_report.md)
> §7 (a `·` is not neutral; a ref is a perturbation and 96% of its cells
> restate the baseline) and
> [`../design/artifact_cache.md`](../design/artifact_cache.md) §6 (two
> caches agreed about a wrong artifact). The remaining to-dos are here:

- [ ] **Run coverage and age, per project** (revisit §1) — rows run /
  rows enumerated, plus the oldest run timestamp, printed by `result` and
  `status`. Turns `·` from decoration into accounted debt. Pin the ratio
  so it cannot fall silently. Today the number is 41/42 and a person has
  to reconstruct it.
- [ ] **A post-`build_binding` soname assertion** (revisit §3, the cheap
  instance) — every `NEEDED` entry naming the project's lib must match
  the soname the tree's lib exports. Catches the stale-artifact class at
  the step that produced it, without waiting for the artifact store.
- [ ] **Warm/cold marks on Built and Installed placements** (revisit §2)
  — cost is a property of a scenario and the model has no word for it.
  Deciding what to run meant `ls`-ing `contrib/z3-all/` to see which
  build trees existed; `action llvm` would have cloned and built LLVM
  from scratch while `action llvm --refs 19,arbipher` was the right
  command, and nothing in the tool suggested it. Derivable data, not
  code: each Built/Installed placement already names a tree, so `warm |
  cold` is "does its product exist". Surface in `spec` and `status`.
- [ ] **Input-artifact identity in the step fingerprint** — the real fix
  for the two-caches finding, and the prerequisite for the artifact
  store. [`../design/artifact_cache.md`](../design/artifact_cache.md) §5
  step 2. The arc, not a day.
- [ ] **A baseline-relative view of ref rows** (revisit §5) —
  presentation first: mark cells identical to the baseline ref. Consider
  an enumeration-level rule only if the row count actually becomes a
  problem; wait for a fourth ref to prove the need.

**A. Make a finding readable from the run log** — the requirement behind
"the project report must also be produced from the running log, so next
time you can identify the same issue". Today the z3 forward cell's
evidence (`required(791) provided(705) missing(100)` plus the names) sits
in `symbols_<variant>.log`, which nothing reads: `actions.log` records
only `probe_binding_ocaml check_post (FAIL)`. The precedent to copy is the
inspect note — `probe_lib_staged_inspect` already surfaces
"install-diff vs build-tree: identical" through a log EVENT, so
`status`/`result`/the HTML page all carry it.

**DONE 2026-08-20.** The root cause was upstream of all three items:
`run_cmd_logged` used a bare `Sys.command`, so every step's stdout and
stderr went to the terminal and nowhere else. On failure `actions.log`
recorded `cmd_fail (exit 1)` and the reason vanished with the scrollback.

- [x] **A0 (the enabler). Every step's output is captured.** The command
  is wrapped `{ ( cmd ) ; echo $? > RC ; } 2>&1 | tee LOG ; exit $(cat RC)`
  — streams to the terminal AND lands on disk. The inner parentheses are
  load-bearing: many probes end in `exit $RC`, and without a nested
  subshell that exits the group before the status is recorded (found
  within the hour by running zstd — the same trap `with_world_asserts`
  hit on 2026-08-19). A `cmd_log` event names the file; on failure the
  last 25 lines are emitted as `cmd_out` events, one per line, so the
  `[ts] tag event detail` shape survives and `grep cmd_out` gives a
  reader the failure directly.
- [x] **A1. The symbol assert emits a note event** — generalised beyond
  z3: a step prints `CANARY-NOTE: …` and the runner lifts it into
  `actions.log` as a `note` event, pass or fail, capped at 12 per step.
  z3's forward cell now logs `symbols required(791), provided(705),
  missing(100)` plus the first five missing names — the evidence that
  used to sit unread in `symbols_<variant>.log`.
- [x] **A2. The cross cells ASSERT their world.** `z3_example` now prints
  `z3 resolved: <path>` from /proc/self/maps (the same convention zlib
  and zstd use), and the Built / Installed worlds assert their own libdir
  through `Canary_world.Log_names`. Pinned as
  `z3.cross_cells_assert_world`: the two worlds must name DIFFERENT
  directories and no asserted path may carry a `..` segment — the probe
  reports what the loader RESOLVED, so an unnormalised path never
  matches, which turned all five cells red on the first attempt.
  Falsified both ways.
- [x] **A3. Witness lines for a plain failure** — `status -v` renders the
  log's own evidence FIRST: `● note` lines on any verdict, the `│`
  failure tail only when the step is red. Reading from actions.log rather
  than from files on disk is deliberate — the log is what gets attached
  to an issue. Evidence resets per variant visit, so a fixed run's output
  does not linger from the append-only history.

**B. Declare the z3 forward mismatch as an xfail** (user: "we shall fix it
as xfail"). It is explained, reproducible and c1-shaped. Derived, not
hardcoded: the predicted substrings come from the symbol evidence, not a
literal in the spec. The condition is WORLD-shaped (lib Fetched × binding
Built), which `contract_binding`'s `loc_filter` cannot express — so either
it rides z3's expectation closure (like the pre-10549 xfails) or `firing`
grows a world predicate. Prefer the closure first, and record the
`firing`-predicate idea as the generalization if a second project wants it.

**C. Run the additive refs' new cells** — `pre-10549` DONE 2026-08-20
(rows #22–26, all five). It mirrors `latest` exactly except where it
should differ: the two `install_lib` xfails (the #10549 regression — the
installed OCaml package did not exist before that PR) plus the staged
probe's xfail, and the same forward-cell ✗. Two bugs had to be fixed to
get there, both recorded in [`issues.md`](issues.md): z3's `env_guard`
had been pointing at a nonexistent path since the per-ref build dirs
landed, and the pre-10549 build tree carried a stale `dllz3ml.so` linked
against a libz3 soname the tree no longer produces (ninja will not
relink for a dependency's SONAME bump). `arbipher` DONE the same day (cold
build, rows #17–21). z3 is now 16/16.

**What the complete set shows.** Taking `latest` as the baseline, the two
additive refs differ in FOUR cells out of ~105: arbipher's #19
`probe_binding_ocaml` ✗ (the fork cannot serve a staged consumer — the
deliberate red in [`issues.md`](issues.md) §1), and pre-10549's three
xfails. All three forward cells (#16/#21/#26) are ✗ for one reason that
involves no ref at all — apt's libz3 4.8.12 exports 705 `Z3_` symbols
where a HEAD-built binding needs 791 — so three rows carry one finding.
That is plan item B's target, and the ref sweep confirms it is
ref-independent.

**llvm**: #27 (released, xfail `Opcode.UncondBr`) and #29 (arbipher dev,
warm tree) ran 2026-08-20 via `action llvm --refs 19,arbipher`. #28
(`latest`) is deliberately deferred: its source declares `locals = []`, so
running it clones llvm-project and builds libLLVM from scratch. It is the
ONLY unrun row in the registry (41/42). Per the user (2026-08-19) the 2×2
is the LOWER BOUND for any project; a regression ref is an ADDITIVE any
project may have, and a fix fork is an additive when we have one. So these
are not optional extras of z3 — they are the additives z3 happens to
carry, and their cross cells are as meaningful as latest's. Expect the
same forward finding on both (same HEAD-ish binding vs apt's 4.8.12); the
fork's staged world keeps its known ✗ (user: leave it).

**D. More projects, and the dependency question** — design note in
[`../design/enumeration/multi_lib.md`](../design/enumeration/multi_lib.md); the candidate ranking
is now MEASURED, not guessed — see
[`../surveys/conf_packages.md` §G](../surveys/conf_packages.md) (2026-08-20:
all six category groups sampled, gates read from opam metadata AND from
the conf packages' own build sections, libs cross-checked against apt and
conda-forge). Short version: one C lib per project is baked into
`artifact_kind` (`Lib` carries no name), so:

- [x] **D1. zlib / camlzip — LANDED 2026-08-20.** 2 scenarios, both
  green: lib `F:stable` (apt 1.3) and `V:dev` (conda-forge 1.3.2), the
  first project whose lib pair needed no build at all. The probe reads
  `/proc/self/maps` and prints which libz answered, and the vendored
  world ASSERTS it (`probe_names_lib`) — pinned by
  `vendored.probe_names_the_world`, falsified two ways (drop the
  repoint; keep the repoint but drop the assert). Measured evidence the
  two worlds are really two: 15 vs 17 exported `deflate*` symbols.
  Follow-on available: zlib 1.3.2 adds ELF version nodes `ZLIB_1.3.1.2`
  / `ZLIB_1.3.2`, so a probe calling `deflateUsed` xfails against apt's
  1.3 at LOAD time — the cheapest natural forward cell in the registry
  (measured in `surveys/conda_forge.md`).
- [x] **D2. zstd — LANDED 2026-08-20** (user installed `libzstd-dev`,
  which was the only blocker). 2 scenarios green: apt 1.5.5 →
  conda-forge 1.5.7, same soname, libc+libpthread closure. Binding =
  `zstd` (ctypes stub-gen, light), NOT `zstandard` (which pulls the
  whole Jane Street core stack). Three firsts: the first
  `tracks_lib = true` gate in the registry (conf-zstd enforces
  `--atleast-version=1.3.8` even though the BINDING declares a bare
  dependency — metadata alone would have called it Free); the first
  probe with TWO world witnesses (`Zstd.version ()` is a runtime
  `ZSTD_versionNumber()` call, alongside the loader's mapped path); and
  the first measured demonstration that exported-symbol COUNTS are not
  comparable across packagers — 177 vs 297 `ZSTD_` symbols with nothing
  removed, because Debian hides zstd's internals and conda-forge does
  not. Still a `bytesrw` backend, so D5 is de-risked.
- [ ] **D2b. lmdb** — still worth landing; Pattern B1+E (direct depexts +
  a `clib:` tag, no conf-*), so it tests the no-conf-indirection style.
  Its pair comes from the binding's opam pins. `ocurl` is a second
  Pattern-B specimen (measured: **no conf dependency at all**).
- [ ] **D3. sundials / sundialsml** — new, and it is the row that PROVES
  the §G1a finding: its gate reads `conf-sundials {>= "2" & build}`,
  which a naive reading sends to the wrapper queue, while the conf
  package's version never reaches its check — so the gate is free and
  apt 6.4.1 → conda-forge 7.8.0 is the widest pair on the shortlist.
- [ ] **D3b. mpfr** — two routes, both interesting, neither free:
  `mlgmpidl` uses the `conf-*-paths` conf FAMILY (a different style worth
  studying on its own), while `mlmpfr` uses a bare `conf-mpfr` PLUS a
  version test inside its own build — a gate `pm_dep_gate` cannot express
  today (`Self_check_in_build`, recorded in [`issues.md`](issues.md)).
  mlmpfr is the more valuable target: its forward mismatch is rejected by
  a check upstream already ships — a naturally occurring xfail.
- [ ] **D4. Named lib artifacts** (the multi-provider axis) — `Lib` gains
  an identity so a project can declare several C libs with their own
  universes. Wide but mechanical; its own arc, with a pin per invariant it
  touches.
- [ ] **D5. bytesrw** — after D4. Needs D4 plus two more pieces: optional
  deps as `Absent` placements (the provision exists, no project uses it,
  and `assignment_ok`'s "a binding's lib must be provided" has to become
  per-artifact), and a combination POLICY (all-off + each-alone + all-on =
  7 worlds, not 2⁵ = 32).
- [ ] **D6. ncurses** — the cheapest remaining landing and the one the
  ranking puts next: `Free_with_conf`, `libncurses-dev` already
  installed, apt 6.4 → conda-forge 6.6, binding install a clean
  2-package add. Ships one upstream finding for free (`conf-ncurses`'s
  `os-family = "ubuntu"` depext line can never fire — opam reports
  `debian` on Ubuntu, and `lib64ncurses-dev` is not in the archive).

**The rest of the queue** is described in
[`projects.md` §4](projects.md), not duplicated here: lwt/libev
(optional-C-dep modelling), cvc5 (a second self-building project),
PyTorch (the multi-PM case, [`project_pytorch.md`](project_pytorch.md)),
then bitwuzla / mariadb / the ffmpeg family, each adding one trick. None
is ordered ahead of D2b–D6, which need no new machinery.

**E. The binding axis on the template projects** (2026-08-20, from the
user's matrix reading). cairo/libffi/zlib/zstd have a lib pair and NO
binding pair — half a 2×2 each; ssl/zarith are the mirror half. The
template hardcodes `versions = None` so it cannot express the axis, and
the pins are shared state: zlib/cairo are single-package downgrades,
libffi's recompiles zstd's binding, zstd's removes `ocaml-compiler` and
downgrades 37 packages. Recorded, not started — the measurements and the
A-vs-B consequences are in
[`opam_exclusive_store_issue.md` §3–5](opam_exclusive_store_issue.md), the declaration gap in
[`issues.md`](issues.md). Blocks on the canary-switch decision for two
of the four.

**Also queued, unchanged**: llvm's 2×2 (needs the same two probe
realizations z3 grew, complicated by llvm-config indirection); widening
sqlite's lib pair to a ≤3.43 amalgamation so its forward cell becomes a
real question; migrating z3/llvm/ssl/the opam template to the shared
`opam_world_check`.

## 2. General to-dos

Framework-level; per-project ones live in [`issues.md`](issues.md).

### Address first

**Residue of the 2026-08-17 active plan** — items 2-4 (Publish
generalization, the shadow mechanism, zarith's binding_decls) landed and
are chronicled in the worklog; this one is what remains:

1. [ ] **Forward-cell expectation** — zarith's instance of the 3-way
   mismatch probes (below). The forward cell (master binding built
   from the worktree, probed against the system lib) passes today;
   a future break must surface as a PREDICTED compat finding (the
   c1 stub↔lib check, tiny-full's precedent) instead of a raw FAIL.
   Steps: a pattern-level contract binding for the built-binding
   probe (forward cell only), the built-binding inspect summary the
   c1 inputs resolve from, a pin that the expectation is
   Expect_compat_derived there and Expect_success elsewhere.

**Design-stage** (the enumeration/config family — when dependency
complexity arrives; config as dependency resolving, status.md design
directions):

- [ ] **ONE general rule for the enumeration's special cases** (user,
  2026-08-17 — revisit "a bit later", the SAME topic): the shadowing
  (gmp prebuilt-shadows-source) and the source-building bypass (z3's
  Heavy→Thin tier) are two instances of "which special case keeps/omits
  which world". Prefer ONE general config/policy mechanism over per-case
  machinery. (The audit-rung half of this was settled 2026-08-19: the
  rung was removed and the shadow is unconditional — see
  `../design/wrapper_packages.md` §3.)
- [ ] **Repo-model leftovers** (inherited 2026-08-23 when `repo_model.md`
  was purged into `../design/enumeration/stage1_project_spec.md` §4;
  the declared model is built and pinned, these are the decisions it
  left open):
  - the fork's LABEL in output — repo name? owner? (`arbipher` today);
  - the config carrier for the contrib layout — a base-layer setting
    (data in code) vs a run-config policy field; the user allows either,
    pick at implementation;
  - the naming-scheme fallback when a repo has no official name —
    slugify the remote URL's last segment, or project name + variant?
  - official sources with no git at all (archive files, PM-handled
    source): a recognized real case, deferred — every current project
    has a remote.
- [ ] **`version_tag` vs artifact version** (inherited 2026-08-23 from
  `versioning.md`): `system_package_spec.version_tag` is a PM pin, and a
  package version is not an artifact version (ssot §4.2.2). Small,
  unscheduled, and nothing depends on it.
- [ ] **A general SELECTION config** (user, 2026-08-17): the ref
  subset (`--refs`) should fold into ONE selection mechanism — the
  user freely picks which CHOICES to run (channels, refs, scenarios,
  actions, …), policy/config-shaped, instead of one flag per axis.
  The shadow + bypass + refs cases converge here.
- [ ] **Multi-source artifact identity + link guards**: extend source
  artifact identity with a repo discriminant (per-repo source rows)
  so a binding from ITS repo against a lib from ANOTHER repo is
  enumerable; then link-guard constraints (which lib channels/repos a
  binding may link), selectable per config. The first piece LANDED
  (2026-08-18): `artifact_kind.Binding_source lang` + the
  `fetch_binding_source_<lang>` action (its own catalogue row, the
  runner's `fetch_binding_source` slot, the canonical column order's
  per-lang block front). The idempotency: a repo providing BOTH the
  source and the binding source (on-tree bindings) wires the SAME
  fetch — the repo is already there (the Source_fetch local path).
- [ ] **Dependency-declaration field + the two combination checks**:
  record the BINDING→LIB constraint regime (strict → persistent old
  bugs; flexible → broken combinations) as spec data + the two cross
  combinations (old-binding×new-lib deploy / new-binding×old-lib
  forward). Zarith's live data point: no GMP version constraint
  (conf-gmp presence only) — the fully-flexible case, resting on
  GMP's ABI discipline.
- [ ] **Pattern datatype→functions conversion**: `Canary_opam_binding`
  becomes FUNCTIONS over the general types instead of the `t` record;
  the taxonomy should cover ALL opam packages; pip follows the idea.

**Enhancements** (no hurry — recorded, not scheduled):

- [ ] **`string_of_assignment` is not canonical** (found 2026-08-24 while
  splitting the selection pass) — it prints an assignment's pairs in list
  order, and it IS the dedup key in `scenarios_of`. Two enumerators
  (`enumerate` and `enumerate_follows_tree`) produce the same content in
  different orders, so the key can differ for equal worlds.
  `scenario_dir_of` was given a canonical kind order on 2026-08-19 for
  exactly this reason; the dedup key never was. Fix: sort by kind there
  too — then reconcile the two enumerators, which is the larger half.
- [ ] **`canary emit --stage N`** — one dump per pipeline pass, so the
  enumeration debugs like a compiler with `-fdump-*`. Proposal, sized and
  with its test plan:
  [`../design/enumeration/emit_stages.md`](../design/enumeration/emit_stages.md).
  Roughly two days; steps 1–3 alone close the fact that **stage 3's run
  order is verified by a pin but cannot be looked at** (`spec` still
  prints enumeration order, which since 2026-08-21 is not what runs). The
  `--why` half — which of the five constraints dropped a candidate — is
  the debugging payoff and is nearly free, because three of them are
  already predicates.

- [ ] **Scenario-name clarity** (user, 2026-08-17) —
  `source-fetched-1.14_lib-fetched_ocaml_binding-fetched` doesn't say
  WHICH source/lib: the names are born-safe artifact-kind ids
  (a_source/a_lib), not the concrete repos/providers. Consider
  carrying the provider/repo name (or pin) into the display name for
  Fetched artifacts (the z3 dirs already show store pins like
  `fetched-4.16.0`; an unpinned Fetched stays ambient and anonymous —
  zarith's `lib-fetched` = system libgmp via apt). Also a
  `canary scenarios`/`spec` human-readable legend mapping each
  scenario name to its concrete world.
- [ ] **The staged-parity principle** (2026-08-18, user — from the
  experiment's follow-up question "how may a common project have these
  different binaries"): the install is a COPY-TRANSFORM step, not a
  mirror — its divergences (missing install rules = #10549; rpath/
  install_name rewrites; strip/mode changes; install-only generated
  files; baked-in build-tree paths; macOS signing) are the bug class to
  CHECK. Generalize the z3 primitives into a staged-parity checker:
  completeness (every declared consumer-facing build product staged —
  `assert_staged` derived from the declared surface instead of a hand
  list), integrity (platform invariants hold in the staged file:
  SONAME/LC_ID_DYLIB = installed identity, no build-dir paths in
  RPATH/RUNPATH, symlink chain + exec modes), parity (symbol-set
  equality vs the build tree modulo declared transforms), and
  ISOLATION (per-world install prefixes — **done for z3 2026-08-19**,
  and it turned out to be a correctness property, not hygiene: the
  shared `z3-all/install` would have let the fork's staged package
  answer the pre-10549 world's staged probe and silence the regression
  xfail. See the Fixed entry in §2. What remains here is the GENERAL
  form: no project's two worlds may share a staging area — a derived
  check over the install rows rather than z3's hand pin, and the same
  question for any other write-shared location a realization names).
  Taxonomy + the checking principle in
  `doc/canary/design/staged_parity.md` (the cross-agent brief).
- [ ] **Surface-drift expectations** — per-project drift bounds on the
  TOTAL surface (C + OCaml counts); `canary inspect-diff` exists.
- [ ] **Pinned verdict-matrix regression** — pin the per-scenario
  verdict matrix (the C2 5/5 was ad-hoc); markers should record the
  verified ref; a `--cold` audit flag; CI-nightly material. The `--cold`
  flag now has a CONCRETE citation (2026-08-17): the warm-mask fix's
  fingerprint covers spec drift, and the pinned-ref check_post covers
  pinned checkouts — a HEAD-ref upstream that MOVED (latest/fork) is
  the remaining warm-mask case, only detectable by re-fetching
  (network), which `--cold` would force.
- [ ] **Opam-templating gotchas as TEST CASES** — the Publish case
  study's live-learned details (the `<name>/<name>.<version>/` dir
  convention; `opam config subst` appends `.in` itself; `%{VAR}%`
  reads the `OPAMVAR_`-prefixed env var; the warm-skip gate) belong in
  the framework self-test axis (pm-test/artifact-test) — they are
  shell + tooling knowledge that generalizes to other package managers
  (pip etc.). A DEDICATED standalone opam switch (the user offered to
  prepare one) keeps the tests from mutating the main switch — tests
  would target it explicitly.
- [ ] **`source_fetch` primitive honor locals** — the table primitive
  always clones (~1-2 GB llvm-project) even when the row's `local`
  checkout exists. Pure waste; functional today.
- [ ] **Docs-mirror cp noise** — skip `.git` in the mirror copy.
- [ ] **Fetched provision for tiny** — the one provision tiny lacks.
- [ ] **Location sub-axis** — probe locations as a first-class axis.
  **The forcing case arrived (2026-08-19)**: the matrix's single
  `probe_lib` column marks only the step tagged exactly `probe_lib`, so
  an Installed world — whose ONLY lib probe is `probe_lib_staged` —
  renders as "not run" in the column while `canary status` shows it
  passed (live: z3 #3/#7, sqlite's staged rows). Display-only today, but
  the deliverable matrix under-reports a world's actual checking. Two
  ways out: a column per location (the location axis proper), or marking
  the column from any `probe_lib*` step — the latter conflates a
  build-tree pass with a staged fail, which is exactly the distinction
  the Installed worlds exist to draw. So: the axis, not the shortcut.
- [ ] **Flavor 2 (deploy-mismatch)** — `close_deps`/`dep_mode`
  built, not yet wired to a live run.
- [ ] **Web results page** — per-project bug reports + fixed-PR links
  in `canary_html.ml`.

## 3. Planned milestone — the mismatch-matrix report (discuss later)

> 2026-08-12, user; reframed 2026-08-19, user.

Prettify the checking output into a user-friendly report: what we check
per project, what failed, and how we may help fix it.

**The shape, corrected.** It was written as "three versions per project"
(stable, official dev/latest, forked dev with the fix). That counted
three repos as three points on one axis, which they are not. The right
shape (see [`../design/enumeration/stage1_project_spec.md`
§9](../design/enumeration/stage1_project_spec.md), "The channel pair"):

- every artifact — the C lib, and each binding per (lang × mechanism) —
  offers **two** choices, stable and latest;
- so one lib × one binding is a **2×2**: two baselines that must pass,
  plus the FORWARD cell (new binding, old lib) and the BACKWARD cell
  (new lib, old binding). More bindings multiply it further;
- the **fork is not a version** — it is where the fix lives. It sits
  outside the matrix and supplies the report's second half.

The report then tells the maintainer: "your HEAD binding broke against
your released lib (the forward cell); here is the failing check, and here
is our fork with the fix passing it." That is a narrative over the
matrix, not a dump of run artifacts — `canary_html.ml`'s output changes
accordingly. Full design discussion still deferred; what is settled is
the axis vocabulary.

**Where the registry stands against this shape**: the per-project `2×2
status` column in [`projects.md` §2](projects.md) — sqlite and z3 full,
llvm collapse-only, ssl/zarith the binding half, cairo/libffi/zlib/zstd
the lib half.

What the two landings cost in machinery, worth knowing before opening
more: a channel pair on a *fetched* artifact needs the store-pin trio
(pinned fetch + `pin_check_post` + a world assertion on the probe), or
the scenarios silently share one installed version; a channel pair that
CROSSES needs a probe realization per cell, or the cell tests a world it
does not name.
