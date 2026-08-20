# Project status — bugs, issues, todo

> 2026-08-19. What's wrong, what's fixed, what's next — for the *projects*
> layer only. Framework status stays in [`../status.md`](../status.md);
> what projects exist and how they land is
> [`coverage.md`](coverage.md) + [`landing.md`](landing.md); historical context in
> [`../worklog/`](../worklog/).

## 1. Live projects

8 projects on the registry (`Canary_registry.all_projects`) — all plain
`project_run`s since 2026-08-12 (ssl's `Multi` entry retired with the
store-pin migration); tiny1 rides the factory. Full matrix in
[`coverage.md` §1](coverage.md). The `registry.entries_enumerate` pin
(`canary_projects_test.ml`) fails if any entry's enumeration is empty,
the name list drifts, or ssl's pinned binding stops enumerating 2
distinct scenarios.

**Scenario counts** (the enumeration snapshot, re-verified 2026-08-19
after the mismatch matrix; full policy unless noted). The total is
pinned: `matrix.registry_shape` asserts 36 rows across the registry, so
this table cannot drift silently.

| project | scenarios | shape |
| --- | --- | --- |
| z3 | 16 | **the mismatch matrix** (2026-08-19): per dev ref (latest / arbipher / pre-10549) the 2×2's three ref-dependent cells — dev baseline (lib B × binding B), BACKWARD (lib B × binding F:4.16.0), FORWARD (lib F:apt × binding B) — plus the staged face of each lib-built cell, and ONE both-released baseline (ref-independent, since nothing is built from the source there). `--thin` = 1 |
| llvm | 3 | 2 dev build chains + ONE both-released baseline. Was 5: its three all-Fetched worlds differed only in an unread source ref, folded by the collapse rule. No Installed axis and no cross cells yet — opening its 2×2 needs the same two probe realizations z3 grew |
| sqlite | 10 | the lib's 5 placements (system-fetched + 2 built amalgamation versions + their 2 staged faces) × the binding's 2 opam pins (5.1.0 / 5.4.1) — the first full 2×2, all cells green by construction |
| zarith | 2 | the FORWARD cell (binding built from master over apt libgmp) + the both-released baseline. Was 3: the third had an opam binding beside an unread master worktree. The lib axis is Fetched-only — prebuilt-shadows-source |
| ssl | 2 | one per binding store pin (0.6.0 / 0.7.0) |
| tiny-full | 1 | all-Vendored stable world |
| cairo / libffi | 1 | source + system lib + opam binding, Fetched@Stable |

**The batch runner + run config + the main-library split** (2026-08-14,
user): `canary action @all` runs every registry project under the
default config — `pr_tier` groups the runs (`Heavy` = z3/llvm's
source-built chains → THIN, bypassing the Dev builds; `Light` → full).
The run layer has `run_config = { policy : run_policy }` (Full | Thin,
the open mode ladder: fetch → smoke → thin → full) — the CLI/batch SET
`config.policy`, consumers match the variant; `enumeration_policy_of`
is the one mapping to the enumeration policy. `--thin` forces thin
everywhere; explicit single-project runs ignore the tier. Pinned by
`registry.batch_tiers`. The layer split (same day, user-directed):
`src/canary/project/` (library `canary_project`) holds the project
DATATYPE + definition utils (`Canary_project_run`,
`Canary_opam_binding`) plus the concrete instantiation (specs, tiny
factory, registry, CI); `src/canary/main/` (library `canary_main`) is
the RUNNING layer (runner, batch, spec-check, layer tests) that the
cmd/tests/batch share — it depends on canary_project for the datatype,
never the reverse. `canary_project_run` no longer references tiny's
factory — `assignment_is_all_good` moved to the datatype layer.

## 2. Bugs & issues

**Flushed 2026-08-19.** Everything that was FIXED, LANDED or RESOLVED
moved to the chronicle,
[`../worklog/worklog_2026_08.md`](../worklog/worklog_2026_08.md) — a
closed bug is history, not status. Everything still OPEN and tied to a
particular project moved to [`issues.md`](issues.md), which is a
standalone worklist another agent can own.

What stays here: the layer's own current state (§1), the ordered plan
(§3), the framework-level to-dos, and the milestone (§4).

## 3. Todo

GENERAL framework issues live here; per-project ones live in
[`issues.md`](issues.md).

### THE ORDERED PLAN (2026-08-19, user asked for the action list)

Everything below is agreed; the order is what matters. A–C are small and
unblock the rest; D is a real arc.

**A. Make a finding readable from the run log** — the requirement behind
"the project report must also be produced from the running log, so next
time you can identify the same issue". Today the z3 forward cell's
evidence (`required(791) provided(705) missing(100)` plus the names) sits
in `symbols_<variant>.log`, which nothing reads: `actions.log` records
only `probe_binding_ocaml check_post (FAIL)`. The precedent to copy is the
inspect note — `probe_lib_staged_inspect` already surfaces
"install-diff vs build-tree: identical" through a log EVENT, so
`status`/`result`/the HTML page all carry it.

- [ ] **A1. The symbol assert emits a note event** — counts always, plus
  the first N missing names on failure, so the finding lands in
  `actions.log` → the matrix cell's detail → the report. Whether it
  passes or fails: "provided ⊇ required" is evidence too.
- [ ] **A2. The cross cells ASSERT their world, not just observe it.** The
  backward cell's `z3 version: 5.1.0.0` line proves the dev lib answered,
  but nothing fails if the ambient lib does instead — it is evidence, not
  enforcement. sqlite already asserts its version line via `asserts`; give
  the forward and backward cells the same, so a shadowing regression is a
  failure rather than a footnote.
- [ ] **A3. Witness lines for a plain failure** — `status -v` tails
  markers today; on a FAIL it should tail the step's own log, so the
  reason is one command away without knowing which file to open.

**B. Declare the z3 forward mismatch as an xfail** (user: "we shall fix it
as xfail"). It is explained, reproducible and c1-shaped. Derived, not
hardcoded: the predicted substrings come from the symbol evidence, not a
literal in the spec. The condition is WORLD-shaped (lib Fetched × binding
Built), which `contract_binding`'s `loc_filter` cannot express — so either
it rides z3's expectation closure (like the pre-10549 xfails) or `firing`
grows a world predicate. Prefer the closure first, and record the
`firing`-predicate idea as the generalization if a second project wants it.

**C. Run the additive refs' new cells** — `arbipher` and `pre-10549` have
never run their forward/backward cells. Per the user (2026-08-19) the 2×2
is the LOWER BOUND for any project; a regression ref is an ADDITIVE any
project may have, and a fix fork is an additive when we have one. So these
are not optional extras of z3 — they are the additives z3 happens to
carry, and their cross cells are as meaningful as latest's. Expect the
same forward finding on both (same HEAD-ish binding vs apt's 4.8.12); the
fork's staged world keeps its known ✗ (user: leave it).

**D. More projects, and the dependency question** — design note in
[`../design/multi_lib.md`](../design/multi_lib.md); the candidate ranking
is now MEASURED, not guessed — see
[`../surveys/conf_packages.md` §G](../surveys/conf_packages.md) (2026-08-20:
all six category groups sampled, gates read from opam metadata AND from
the conf packages' own build sections, libs cross-checked against apt and
conda-forge). Short version: one C lib per project is baked into
`artifact_kind` (`Lib` carries no name), so:

- [ ] **D1. zlib / camlzip** — lands now; the cheapest real lib channel
  pair in the registry (apt vs a source build measured in seconds), so the
  third project with a 2×2 and the first where both sides are cheap.
  Confirmed by the survey sampling (2026-08-20): highest uncovered revdep
  count (56), a bare `"conf-zlib"` gate, apt 1.3 → conda-forge 1.3.2, and
  a libc-only closure. `zlib` (2 opam versions) is an alternative binding
  to `camlzip` (4) if a smaller surface is wanted.
- [ ] **D2. zstd / zstandard** — promoted to second by the survey: same
  shape as zlib (bare `"conf-zstd"`, apt 1.5.5 → conda-forge 1.5.7, small
  closure), and it is one of `bytesrw`'s five optional backends, so
  landing it standalone de-risks D5.
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

**Also queued, unchanged**: llvm's 2×2 (needs the same two probe
realizations z3 grew, complicated by llvm-config indirection); widening
sqlite's lib pair to a ≤3.43 amalgamation so its forward cell becomes a
real question; migrating z3/llvm/ssl/the opam template to the shared
`opam_world_check`.

### General (address first)

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
  (gmp prebuilt-shadows-source, active plan 3's policy) and the
  source-building bypass (z3's Heavy→Thin tier) are two instances of
  "which special case keeps/omits which world". Prefer ONE general
  config/policy mechanism over per-case machinery; the audit-rung
  decision is part of this (see the decision brief,
  wrapper_packages.md §3.1).
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
## 4. Planned milestone — the mismatch-matrix report (discuss later)

> 2026-08-12, user; reframed 2026-08-19, user.

Prettify the checking output into a user-friendly report: what we check
per project, what failed, and how we may help fix it.

**The shape, corrected.** It was written as "three versions per project"
(stable, official dev/latest, forked dev with the fix). That counted
three repos as three points on one axis, which they are not. The right
shape (see [`../design/repo_model.md`](../design/repo_model.md), "The
channel pair"):

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

**Where the registry stands against this shape** (2026-08-19, after the
first two landings):

- **sqlite — full 2×2, all green.** Two opam pins (5.1.0 / 5.4.1) × two
  built amalgamation versions. Green by construction: the lib pair is
  narrow (3.45.1 and 3.46.1 export identical symbol sets), so this is the
  machinery proof. Widening the lib side to a ≤3.43 amalgamation, which
  lacks the modern watchlist APIs, is what makes its forward cell a real
  question.
- **z3 — full 2×2 per dev ref, on real artifacts.** The binding's
  `~follows:a_lib` is gone, so the cross cells enumerate: FORWARD (a
  binding built from HEAD linked against apt's libz3) and BACKWARD (the
  released opam binding run against a HEAD-built libz3). Both needed new
  probe realizations to be honest — see the Landed entry in §2.
- **llvm — collapse only.** 5 → 3 (phantoms gone); it keeps its binding
  `follows`, so no cross cells. Opening them needs the same two probe
  realizations, complicated by its llvm-config indirection.
- **zarith — 1×2 (the forward cell) + baseline**, and no second lib
  choice by policy (prebuilt-shadows-source: apt ships one GMP).
- **ssl — 1×2** via two store pins on the binding; no second lib choice.
- **cairo, libffi — 1×1.** Both axes single.

What the two landings cost in machinery, worth knowing before opening
more: a channel pair on a *fetched* artifact needs the store-pin trio
(pinned fetch + `pin_check_post` + a world assertion on the probe), or
the scenarios silently share one installed version; a channel pair that
CROSSES needs a probe realization per cell, or the cell tests a world it
does not name.
