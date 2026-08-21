# Shared-store version switching — survey + plan

> 2026-08-12. The opam-switch version-swap problem, generalized beyond ssl.
> Companion to [`../project/projects.md`](../project/projects.md) (who
> suffers from it) and [`../project/status_project.md`](../project/status_project.md)
> (the to-dos it leaves).
>
> Moved here from `project/` 2026-08-21: this is a design principle for
> the general algorithm, not a per-project record. Per-project
> consequences live in [`../project/issues.md`](../project/issues.md).

## 1. The problem, generalized

opam does not allow two versions of one package in one switch — the solver
assumes one version per package per switch. A scenario that needs
`ssl.0.6.0` and another that needs `ssl.0.7.0` therefore cannot coexist in
one switch: switching requires uninstall + reinstall (recompile).

This is **not ssl-specific**. Every project whose scenarios pin different
versions of the same opam package suffers:

| project | package | versions across scenarios |
| --- | --- | --- |
| ssl | `ssl` | 0.6.0 vs 0.7.0 (hand-swapped per variant) |
| z3 | `z3` | opam `z3` (stable probe) vs `z3.dev` (dev chain Publish) |
| llvm | `llvm.19-shared` vs `llvm.dev-shared` + `conf-llvm-shared.dev` | stable chain vs dev chain |

Current handling per project:

- **ssl** — the honest one: variants run sequentially in one
  `run_project_multi` invocation; each fetch pins its version; the probe
  carries a WORLD-IDENTITY ASSERTION (`test "$INSTALLED_SSL" = "<v>"`)
  that fails loudly if the switch holds the wrong version.
- **z3/llvm** — no pin, no assertion. Their probes compile against
  *whatever the switch happens to hold* (`-package z3`, `-package llvm`).
  Safe today only by scenario ORDER (stable-baseline-first means the
  stable probe runs before the dev Publish mutates the switch). The
  crossing was observed once already (worklog 2026-08-05, A7 finding
  (a): warm-skipped fetch/pack + live probe → `unexpected_success`) and
  is silent when it happens.

The current runner is fully sequential (`run_project_spec` iterates
scenarios), so "sequentialization" is not a parallelism cost — the
missing piece is *correctness under the shared store*: pins as
enumeration data, and a general world assertion instead of ssl's
hand-written one.

## 2. Opam survey (2026-08-12, opam 2.5.0)

- **No multi-version co-installation.** One version per package per
  switch is a core solver invariant; no escape hatch in 2.5.x.
- **Lightweight switches ARE cheap — the assumption was wrong.** The
  expensive part of `opam switch create` is compiling
  `ocaml-base-compiler`. The escape is **`ocaml-system`**: the compiler
  variant that wires the system-installed OCaml instead of building one.
  Measured on this machine:

  | step | time |
  | --- | --- |
  | `opam switch create --empty X` | 0.3 s |
  | `opam install ocaml-system` (in X) | 4.4 s |
  | switch disk footprint before packages | 244 KB |

  So a python-venv-style isolated switch costs ~5 s and no compilation —
  a real, viable escape if per-version isolation is ever wanted.
- **`opam-0install` exists** (experimental solver backend, solves
  per-build without global consistency). Not useful for probes: canary's
  probes run `ocamlfind ocamlopt` against one consistent switch
  environment; 0install relaxes exactly what the probes need enforced.
- **Local/dir switches** (`opam switch link DIR`) + `ocaml-system` give
  per-directory auto-switching at the same ~5 s cost.
- **WSL caveat for `ocaml-system`** (2026-08-12): it wires a *distro-
  installed* OCaml — on this machine `which ocaml` is
  `/home/red/.opam/default/bin/ocaml`, i.e. the only OCaml is opam's own.
  `apt install ocaml` on Ubuntu/WSL would be needed first. Recorded as a
  candidate solution (Option B below), not yet decided — needs that
  install + a study of per-switch cache-sharing costs.

## 3. The two designs

### A. Sequentialization with pins (generalizes ssl's pattern)

Make the shared store explicit enumeration data:

1. **Store pin** — a Fetched artifact row can pin its version via its
   provider (`pr_artifacts` row refinement, already noted in CLAUDE.md
   as not-yet-wired). `Fetched@0.6.0` becomes scenario identity (today
   Fetched is version-ambient in `scenario_dir_of`).
2. **Store signature** — each scenario carries
   `{(store, package, version)}` for its pinning fetches. Two scenarios
   conflict when their signatures assign different versions to the same
   (store, package).
3. **Scheduler pass** — the runner orders scenario groups to minimize
   switches (sort by signature), which today's sequential runner does
   naturally (the enumerated list IS the run order); the exclusivity
   marking exists so a future parallel runner knows NOT to run
   conflicting scenarios concurrently.
4. **Pin-check fetch** — a fetch step for a pinned artifact never
   warm-cache-skips when the installed version differs; its check_post
   verifies the pin (ssl's hand-written world assertion, generalized
   into the framework).

Cost: small — the runner is already sequential; the pieces are data +
  one scheduling/verification pass. This is the direct generalization of
  what ssl already does by hand.

### A.1 Cache safety — the current cache, precisely (2026-08-12)

Two artifact classes behave differently under the step cache (skip iff
verdict-marker exists AND `check_post` passes, keyed by scenario dir):

- **Scenario-scoped immutable artifacts** (source fetch, build outputs,
  vendored overlays): **safe today**. Their dirs ARE scenario identity
  (`Built@Dev` ≠ `Built@Stable`); a valid marker means "this dir's
  content was produced and verified". Store mutation doesn't affect
  them; nothing else writes their dirs.
- **Store-mutating fetches** (opam/pip/apt installs): **NOT safe today**.
  `fetch_binding_cmd` writes `binding.ok` when the install succeeded
  ONCE; a warm skip means "this scenario's install ran before", not
  "the store currently holds this version". Another scenario (or a
  prior run's last scenario) may have switched the store since — the
  warm skip then serves a probe against the wrong world. ssl's world
  assertion makes that loud; z3/llvm have no assertion — silent.

The user's orthogonality observation is the right frame (2026-08-12):
the source fetch/build half is content, per-scenario-cached and safe;
the opam package version is **store status, not content**. Plan A must
encode that split:

- scenario identity = the immutable half (unchanged machinery);
- the binding version = a **store pin**, whose "fetch" is really a
  *store-pin operation*: verify-or-set the store to the pinned version.
  Its `check_post` = pin-check (installed version == pin). The ONLY
  cache-skippable fact is "the store is provably in the pinned state"
  — which is exactly the state that matters, so the warm path is safe
  by construction, and re-running a previous scenario's pin re-pins
  (correct, ~one recompile when the switch actually differs).
- probes consuming a pinned artifact carry the generalized world
  assertion — the loud backstop if anything else still drifts.

### A.2 The naive-spec harness

Most projects will check against two binding versions — a one-version
spec should be visible as such, not silently assumed. Proposed guards
(pure project-tests, same family as the arrow pin):

- **Pin-presence invariant**: a Fetched binding on a `Stateful_global`
  store (opam) whose declared universe has ≥2 versions must pin each;
  a pinned fetch must have a pin-checked check_post; a probe consuming
  a pinned artifact must carry the world assertion. (Derivable from
  provider store behaviors + version axes — no new annotations.)
- **Version-axis coverage**: when a project declares ≥2 versions
  anywhere, `spec` flags binding rows that don't span the same axis —
  the versions the harness can't actually test. One-version specs get
  an explicit "single-version" mark rather than looking identical to
  an under-declared one.

### B. Per-version lightweight switches (python-venv analogue)

One `--empty` + `ocaml-system` switch per version (~5 s, §2). Each
scenario's fetch installs into its OWN switch; probes run under
`eval $(opam env --switch=X)`.

- **Pros**: real isolation — the shared-store hazard class disappears
  entirely; no ordering constraints; parallel-safe by construction.
- **Cons**: per-switch dependency reinstall (each switch compiles its own
  copies — no shared build cache across switches); switch count grows
  with scenarios; a new per-step env discipline; disk.

## 4. Recommendation

**A now, B documented as the fallback.** A is the smaller change, matches
the current sequential runner, generalizes ssl's proven pattern, and its
data (store pins + signatures) survives into B unchanged — if we later
switch to per-version switches, the pin becomes "which switch to use".
B stays on the table because the survey showed it's cheap enough to be
real (the ~5 s ocaml-system switch kills the old objection); it becomes
attractive only if we want scenario parallelism or find the world
assertions too fragile.

Implementation status (updated 2026-08-12):

1. [x] **Pinned Fetched version via provider** — `Lang_pkg.versions :
   opam_pin list option` declares the installable versions; each
   `opam_pin = { pin_version; install_name option }` — the standard form
   is `<package>.<pin_version>`, the `install_name` field is the escape
   for irregular package names (declaration data; the enumeration just
   ranges over the pins). `artifact_row` projects them into the axes
   (mirror of `dep_mode_of_provider` → runtime). `build_id` gained an
   `id`; a pinned placement is identity-bearing (`scenario_dir_of` +
   `ambient_key` + assignment dedup). The pin-check verifies the OPAM
   package version (`opam list --columns=version` — the store's own
   record; robust where the findlib META version differs from the opam
   version, e.g. z3.dev's META carries the source version).
2. [x] **Run order as the contract** — the enumerated list IS the run
   order (sequential runner); no explicit signature machinery needed yet.
3. [x] **Store-pin fetch + world assertion** — `SB.pin_check_post`
   (`Canary_pm_opam.holds_pin_cmd` shell): warm-skip only when the switch
   provably holds the pin; otherwise the fetch re-pins. Probes carry the
   pin world-check pre-compile (loud mismatch).
4. [ ] The naive-spec harness (§A.2) as pure project-tests (deferred —
   user: "no hurry").
5. [x] **ssl migrated, `Multi` deleted** — 2 enumerated scenarios
   (0.6.0/0.7.0 pins); each runs BOTH apps as different probe actions
   (core = Probe_binding, nlv = Probe_app); the red cell survives as
   scenario@0.6.0's `probe_app_ocaml` xfail[c2]. The registry is plain
   `(string * project_run) list`. Also fixed en route: the spec's
   pre/post label join (delta scenarios rendered `·` though they ran —
   the scenario-count mismatch) and the lang-blind `probe_app` slot
   (now a per-lang list).
6. [x] **z3 migrated** (2026-08-12) — the stable binding pins the
   opam-repo version (explicit pinned fetch + `pin_check_post` + world
   assertion on the stable probe); the dev chain's Publish carries its
   own pin-check ("dev"). En route fixes the first real dev-chain run
   exposed: the action-table fold dropped configure/scan/headers/
   install/build_binding/publish fields (the fold now merges them all);
   build-chain rows (Configure/Scan/Build_headers) now require a Built
   lib (an all-Fetched chain no longer inherits them); probe rows are
   provision-filtered (opam probes → Fetched binding, build-tree Raw
   probes → Built); `-G Ninja` restored on the cmake rows. FINDING
   (retracted 2026-08-13): the official z3 HEAD's OCaml binding is NOT
   broken upstream — "unknown C primitive
   'n_solver_register_on_clause'" was the opam switch's stale
   `dllz3ml.so` shadowing the fresh one in z3's POST_BUILD self-check
   (`CAML_LD_LIBRARY_PATH` beats the bytecode's `-dllpath`) — a store
   hazard in a BUILD step's self-check, not a probe. Fixed with an
   `env_guard` on the dev Build_binding row; Dev is back on the
   official `z3_source_latest` (see ../project/status_project.md).
7. [x] **llvm migrated** (2026-08-12) — the stable binding pins
   "19-shared" (the standard install name `llvm.19-shared` fits — no
   `install_name` escape needed); pin-checked fetch + world-checked
   stable probe (the Opcode.UncondBr xfail fires against the pinned
   binding); the dev binding probes the build tree (no store read) and
   the table-era dev chain has no Publish row (noted as an omission —
   the pre-table era published `llvm.dev-shared` + `conf-llvm-shared.dev`).
   FINDING: the official llvm-project HEAD's _out clone lacks the
   llvm/ subdir (cmake dies at configure) — the arbipher fork restored
   as the Dev source, same shape as z3's finding. Verified 2026-08-13:
   both scenarios PASS warm (dev probe green, stable PASS + derived
   xfail). En route fix: the dev probe row's `$($LLVM_CONFIG --libdir)`
   indirection pointed at `build/bin/llvm-config`, which `ninja LLVM`
   never builds — the row now probes `<build>/lib/libLLVM.so` directly
   (see ../worklog/worklog_2026_08.md, "llvm dev probe").

Tracked in [`../project/status_project.md`](../project/status_project.md).

---

## 5. The binding axis makes the A-vs-B choice concrete (2026-08-20)

> Opened by the user reading the result matrix: *"for rows 33-40 I can see
> two versions of the c lib, but shall it contain two versions of ocaml
> binding, or just one ocaml binding against two c libs?"* — the answer is
> that it should be two, and finding out why it is not produced the first
> hard number for §4's open choice.

### 5a. Every template project is half a 2×2, and ssl is the other half

The 2×2 lower bound needs a pair on BOTH axes (lib × binding). Measured
across the registry as it stands:

| project | lib axis | binding axis | rows | which half |
| --- | --- | --- | --- | --- |
| cairo, libffi, zlib, zstd | apt vs conda-forge prebuilt | **one** | 2 | lib only |
| ssl | apt only | 0.6.0 vs 0.7.0 | 2 | binding only |
| zarith | apt only (apt ships upstream's newest) | opam vs built worktree | 2 | binding only |
| sqlite | 5 placements | 5.1.0 vs 5.4.1 | 10 | **both** |
| z3 | built vs apt | built vs 4.16.0 | 16 | **both** |

So the four Vendored-lib projects have exactly the axis the prebuilt work
gave them, and none of the axis ssl has. The two halves have never been
combined on the same project outside sqlite and z3.

**Terminology, since "template project" and "by hand" are doing work
here.** The *template* is `Canary_opam_binding` — the module its own
header calls "the ocaml/opam binding pattern" (renamed from "Pattern A"
2026-08-17). A *template project* is one whose `project_run` comes from
`Canary_opam_binding.run decl`, i.e. it declares a `Canary_opam_binding.t`
record and the template builds its artifact table, runner_spec and steps.
There are exactly five: **zarith, cairo, libffi, zlib, zstd**.

Everyone else builds their own `Canary_project_spec.artifact_row` list in
their own module — sqlite, z3, llvm, tiny-full, and **ssl**. That is what
"by hand" means: ssl never calls `Canary_opam_binding.run` at all (it
borrows only the `lib_locator` / `lib_resolve` helpers, two references),
and writes its own binding row:

```ocaml
(* canary_project_ssl.ml — ssl's own artifact table *)
Canary_project_spec.artifact_row ~artifact:ssl_binding_art
  ~universe:[ (Fetched, [ Stable ]) ]
  ~provider:(SC.Lang_pkg
     { lang = OCaml; pm = Opam; package = "ssl"; self_contained = false;
       versions = Some [ { pin_version = "0.6.0"; install_name = None };
                         { pin_version = "0.7.0"; install_name = None } ] })
```

The template builds the same row internally and fixes the last field:

```ocaml
(* canary_opam_binding.ml:655 — every template project's binding row *)
~provider:(Canary_store_config.Lang_pkg
   { lang = OCaml; pm = Opam; package = d.opam_pkg;
     self_contained = false; versions = None })   (* <- no axis possible *)
```

So yes — the two snippets are the whole mechanical story. A template
project cannot declare pins because the template does not accept them;
the fix is a field on `Canary_opam_binding.t` threaded to that call site.

### 5b. The real blocker: an opam pin is not project-local

The lib axis and the binding axis are not the same KIND of axis, and the
prebuilt work hid the difference. A Vendored `.so` lives under
`contrib/<p>-all/prebuilt/` and is read by one project; adding it changes
nothing for anyone else. An opam pin lives in the ONE switch all ten
projects share.

Measured cost of installing the older half of each candidate pair
(`opam install <pkg>.<v> --show-actions --dry-run`, 2026-08-20):

| project | pair | remove | downgrade | recompile | what it actually is |
| --- | --- | --- | --- | --- | --- |
| zlib / camlzip | 1.13 → 1.14 | 0 | **1** | 0 | the package, alone |
| cairo / cairo2 | 0.6.4 → 0.6.5 | 0 | **1** | 0 | the package, alone |
| libffi / ctypes-foreign | 0.23.0 → 0.24.0 | 0 | 2 | **3** | drags `ctypes` 0.24.0→0.23.0, then rebuilds its consumers: `llvm.19-shared`, `yaml`, **`zstd`** |
| zstd / zstd | 0.3 → 0.4 | **3** | **37** | **157** | a whole-switch compiler downgrade |

The zstd row needs spelling out, because "37 downgrades" undersells it.
`zstd 0.3` requires `ctypes 0.20.2`, which caps the compiler:

```
↘ ocaml                5.4.1 → 5.1.1   [required by zstd]
↘ ocaml-base-compiler  5.4.1 → 5.1.1   [required by ocaml]
⊘ ocaml-compiler       5.4.1           (removed: 5.1.1 predates the split)
⊘ base-effects, ocaml-index            (conflict with the older ocaml)
↻ 157 packages                          (everything, rebuilt against 5.1.1
                                         — cairo2 and camlzip included)
```

That is not a pin. It is the entire switch moved back three compiler
minor versions and rebuilt, to run one scenario of one project.

### 5c. Three tiers, and only the outer two are obvious

The user's reading of the table (2026-08-20), which is what the plan
should follow:

**Tier 1 — the package alone (zlib, cairo): acceptable.** *"I am ok to
downgrade 1 package since we are experimenting and the two versions of
one package cannot co-exist in opam."* The swap is not a cost we chose,
it is what opam's one-version-per-switch rule makes unavoidable (§1); a
pin that moves only its own package is design A working exactly as
intended.

**Tier 3 — the compiler (zstd): out.** *"Deleting `ocaml-compiler` is a
dangerous op since it should be required for the ocaml."* Correct, and
the full action list above is worse than the summary was: the compiler
goes back to 5.1.1 and 157 packages rebuild. Nothing about zstd's
binding axis is worth that, and the recovery is a switch reinstall.

**Tier 2 — collateral rebuilds (libffi): genuinely both.** The user:
*"recompiling llvm is not a good idea and not a bad idea — in a clean
testing for libffi/ctypes, we would want it can install and uninstall
alone; however, in an extreme testing consideration, the dependent
packages are another form of testing."*

Both halves are right, and they are about different experiments:

- *As contamination.* If the question is "does ctypes-foreign 0.23.0 work
  over libffi 3.4.6", then rebuilding `llvm.19-shared` and `yaml` is
  noise: it lengthens the run, it mutates two other projects' worlds, and
  a failure in the collateral rebuild aborts a scenario that was not
  about them. A clean per-project axis wants the pin to install and
  uninstall alone.
- *As coverage.* But look at what the collateral rebuild is: opam
  recompiling `llvm.19-shared` against `ctypes 0.23.0` **is** a
  consumer-over-provider compatibility test — the same question canary
  asks, on the same shape (OCaml source surface, so c2-flavoured), for
  free. And it is one we could not enumerate ourselves today, because it
  crosses projects: it pairs llvm's binding with libffi's binding's
  dependency.

Which means design A's hazard and a coverage opportunity are the same
event, and the difference is only whether we OBSERVE it. See §5e.

Design A's existing mitigation does not settle any of this. The world
assertion checks the switch holds the scenario's declared pin and fails
loudly otherwise — that catches *crossing* (scenario X running under
scenario Y's pin). It says nothing about tier 2 (the switch is correct
for libffi and quietly different for llvm) or tier 3 (the switch is
correct for zstd@0.3 and unusable for everything else).

### 5d. What this does to §4's recommendation

§4 said "**A now, B documented as the fallback**", with B (per-version
lightweight switches) becoming attractive "only if we want scenario
parallelism or find the world assertions too fragile". Neither condition
fired — a third one did: **A only works while pins are self-contained,
and that is a property of the dependency graph, not of our design.** It
held for the four projects that have a binding axis today and fails for
two of the four that want one next.

Revised reading, not yet a decision, following §5c's three tiers:

1. **A remains right for tier 1.** zlib and cairo could take their binding
   axis today, in the shared switch, with the existing `pin_check_post` +
   world assertion. Two more full 2×2s for a field on the template.
2. **Tier 3 needs an isolated switch, and that is now a requirement
   rather than a preference.** Not B's per-version fleet necessarily —
   one canary-owned switch is enough, and it is the cheap middle: it lets
   a destructive pin be destructive where nothing else lives, without
   paying per-scenario switch cost. (It does not give parallelism; B
   still does.)
3. **Tier 2 is a design question, not a switch question.** Isolation
   makes the collateral rebuild go away, which is the right answer if it
   is contamination and the wrong one if it is coverage (§5c). Decide
   what we want from it BEFORE isolating it away by default — see §5e.

Whichever is chosen, the landing rule gains a step: **before declaring a
binding pair, dry-run the older pin and record which tier it is in.**
`opam install <pkg>.<v> --show-actions --dry-run` costs seconds and
answers it exactly. A pair that moves the compiler is not a pair, it is a
switch requirement.

### 5e. The collateral rebuild is an uninstrumented experiment (2026-08-20)

Following the user's tier-2 reading. When pinning `ctypes-foreign 0.23.0`
makes opam recompile `llvm.19-shared`, `yaml` and `zstd`, opam is running
the experiment canary exists to run — *does this consumer still build
against this version of its provider?* — on three consumers at once, and
then throwing the answer away. We see a longer run; we do not see a
result.

What is actually available there, and cheaply:

- **A verdict per collateral rebuild.** Each `↻` either compiles or does
  not, and a failure is a genuine finding (a consumer that cannot build
  against a version its constraints permit). Today a failure surfaces as
  "opam install failed" attributed to the scenario that triggered it —
  the wrong project gets the blame.
- **A scenario we cannot enumerate.** `llvm.19-shared` × `ctypes 0.23.0`
  crosses two projects: llvm's binding against the dependency of libffi's
  binding. Our enumeration ranges over ONE project's artifacts, so this
  pair is not in any project's universe. The solver reaches it for free.
- **A different contract than our probes test.** These are *source*
  rebuilds — they answer the c2-shaped question (does the OCaml surface
  still satisfy its consumers) rather than the c1-shaped one our native
  probes answer. We have few of those.

Three ways to treat it, in increasing ambition:

1. **Record it.** Parse `--show-actions` before the install and log the
   `↻` set as an event on the step, so the run says which other projects'
   packages this scenario rebuilt. Cheap, and it makes the blame
   attribution correct.
2. **Verdict it.** Treat each collateral rebuild as an outcome of the
   scenario — a rebuilt-consumer list with per-item pass/fail. Still no
   new enumeration; it is reporting what already happened.
3. **Enumerate it.** Admit cross-project consumer/provider pairs as a
   scenario kind of their own. That is a model change (our universes are
   per-project) and it is what §5c's "extreme testing" reading points
   at. Not now, but it is the reason not to reflexively isolate tier 2
   away: isolation would delete the signal along with the hazard.

Note the interaction with §5d item 2: a dedicated canary switch makes the
collateral set SMALLER and more meaningful (only canary's own packages
are in it), rather than removing it. That is an argument for the
one-canary-switch middle over B's per-version fleet, which removes it
entirely.

### 5f. Open items this leaves

- [ ] `Canary_opam_binding` cannot express a binding version axis
  (`versions = None`, hardcoded) — the field plus threading, small.
- [ ] Decide A-for-safe-pins vs one canary switch vs B (§5d). The binding
  axis on zstd and libffi is blocked until then.
- [ ] Add the dry-run TIER check to the landing checklist (`../project/landing.md`
  §3b is where the other measured gate checks live): tier 1 lands now,
  tier 2 lands with a decision on §5e, tier 3 blocks on the switch.
- [ ] Decide what tier-2 collateral rebuilds are FOR (§5e) before
  isolating them away — record / verdict / enumerate.
- [ ] zarith's and ssl's lib axes are single-point for stated reasons; if
  either gains a prebuilt they become full 2×2s with no new machinery.
- [x] **Order scenarios by stateful-store state** (§5g) — LANDED
  2026-08-21. `scenarios_in_run_order` + `store_state_key`; sqlite's real
  pin swaps went 9 → 2. The binding axis (§5a) can now land without
  multiplying flips.

### 5g. The pin is a LOCK, so group scenarios by the state they need
### (2026-08-20, user) — **LANDED 2026-08-21**

The user's framing, which is the right one and was already half in the
model: opam is `Isolated_store "switch"`
(`Canary_store.store_behavior_of_pm`) — isolated from the system, and
internally SINGLE-VALUED. So a scenario's version pin is not a
preference, it is an **exclusive lock on that store's state** for the
step's duration. `Canary_world.Opam_pin` is the verification half of that
lock; §1's "opam does not allow two versions of one package in one
switch" is the same fact stated as a constraint.

> **What §4 already solved, and what it did not.** Item 2 ("Run order as
> the contract", `[x]`) decided *how* the order is chosen — "the
> enumerated list IS the run order" — i.e. deliberately no scheduler. It
> did not claim to minimise anything. Item 3 (`pin_check_post`, `[x]`)
> solved the **hazard**: a fetch re-pins when the pin is not held, and a
> warm skip fires only when the switch provably holds it, so no scenario
> ever runs on the wrong pin. What follows is therefore a **cost**
> finding, not a correctness one — the hazard has been closed since
> 2026-08-12.

What follows is a scheduling property nothing exploits yet. **Scenarios
that need the same state should run together.** Measured on the sqlite
run of 2026-08-20:

```
opam install sqlite3.5.1.0     scenario 1   lib B:d
opam install sqlite3.5.4.1     scenario 2   lib B:d
opam install sqlite3.5.1.0     scenario 3   lib I:d
opam install sqlite3.5.4.1     scenario 4   lib I:d
…                              (alternating every row)
→ TEN pin operations for ten scenarios
```

The binding pin alternates on every row, because the enumeration's
product ranges over the lib axis outermost and the binding axis
innermost, and **the enumerated list IS the run order** (design A, §4
item 2 — "no explicit signature machinery needed yet"). Grouping by pin
would perform **two** pin operations instead of ten. Each one is an
uninstall + reinstall, so for a binding heavier than sqlite3 that is a
recompile per row.

**z3 is the same finding at its worst — and it is why z3 feels slow.**
Measured on the full 16-scenario run of 2026-08-20, the binding placement
alternates:

```
fetched, built, fetched, built, built, fetched, built, fetched,
built, built, fetched, built, fetched, built, built, fetched
```

Six of the sixteen rows place the binding `Fetched@4.16.0`, and each one
runs `opam install z3.4.16.0`. The opam `z3` package is
`Package_builds_lib` — it compiles libz3 from source — so every flip pays
a full C++ build. `fetch_binding_ocaml` accumulated **344 s** in a single
sampled window, and the heavy scenarios cost ~173 s each against ~2 s for
a zlib/zstd scenario.

Grouping the six Fetched rows together would pay that build ONCE. So the
scheduling item is not a micro-optimisation for z3: it is most of z3's
wall clock, and therefore most of the cost of every framework change that
has to be verified against z3.

Three things to note before implementing it:

1. **It is an ORDERING, not a new axis.** The scenario set is unchanged;
   only the sequence differs. That keeps it out of the enumeration's
   semantics — a sort key, derived from each assignment's stateful-store
   placements.
2. **Reordering is already safe; the assertion is the backstop.**
   `pin_check_post` re-pins whenever the pin is not held, so grouping
   cannot make a scenario inherit a neighbour's state — the correctness
   does not depend on the ordering. `Opam_pin` is a runtime confirmation
   on top of that, and per the user (2026-08-20) it is redundant in
   principle: the result is known at dispatch because canary itself
   performed the pin. It earns its place only against dispatch bugs and
   against mutation from OUTSIDE canary — which happened the same day,
   when a stray interrupted batch left the switch on `sqlite3.5.1.0`.
3. **It composes with the tier work (§5c).** Tier 1 pins (single-package
   downgrades) get cheaper by exactly this factor. Tier 3 pins do not
   become acceptable — grouping does not make a compiler downgrade
   affordable, it just performs it once.

Sequencing note: this is worth doing BEFORE the binding axis lands on the
template projects (§5a), because that change multiplies the number of
pinned scenarios and therefore the number of flips.

#### What landed (2026-08-21)

`Canary_project_run.store_state_key` derives the (artifact, pinned
version) pairs an assignment locks — artifacts whose PROVIDER declares
store pins and which the assignment places at a concrete version.
`scenarios_in_run_order` is `scenarios_of` put through a
`List.stable_sort` on that key, and the runner iterates it instead of the
raw enumeration. Stable, so the enumeration's order (baseline world
first) survives inside each state group; `scenarios_of` itself is
untouched, so `spec` and every pure test still see enumeration order.

Measured on sqlite, ten scenarios:

| | pin operations | of which REAL swaps |
| --- | --- | --- |
| before | 10 | 9 — alternating every row |
| after | 10 | **2** — one per group boundary |

The command still runs per scenario (the fetch step is per-scenario);
what changes is that eight of them are now `already installed` no-ops.
Wall clock on sqlite moved only 57.4 s → 53.6 s, because reinstalling
`sqlite3` is cheap — **the saving is proportional to the package's
install cost**, which is exactly why z3 is the case that motivated it: a
flip there recompiles libz3 from source.

Pinned as `run_order.groups_by_store_state` over every catalogued
project, muted ones included, asserting both halves — the ordering is a
permutation of the enumeration (a sort, not a policy) and each distinct
key occupies one contiguous run. Falsified by dropping the sort and by
making it drop a scenario.
