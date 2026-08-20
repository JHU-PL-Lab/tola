# Shared-store version switching — survey + plan

> 2026-08-12. The opam-switch version-swap problem, generalized beyond ssl.
> Companion to [`status_project.md`](status_project.md) (ssl holdout item) and
> [`coverage.md`](coverage.md) (who suffers from it).

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
   official `z3_source_latest` (see status_project.md).
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
   (see status_project.md "Fixed — llvm dev probe").

Tracked in [`status_project.md`](status_project.md) §3 ("ssl → per-variant
project_runs", "shared-store sequentialization").

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

The immediate blocker is small: ssl declares its axis by hand as
`SC.Lang_pkg { versions = Some [pins] }`, while
`Canary_opam_binding` hardcodes `versions = None`, so no template project
can carry one. That is a field and some threading.

### 5b. The real blocker: an opam pin is not project-local

The lib axis and the binding axis are not the same KIND of axis, and the
prebuilt work hid the difference. A Vendored `.so` lives under
`contrib/<p>-all/prebuilt/` and is read by one project; adding it changes
nothing for anyone else. An opam pin lives in the ONE switch all ten
projects share.

Measured cost of installing the older half of each candidate pair
(`opam install <pkg>.<v> --show-actions --dry-run`, 2026-08-20):

| project | pair | what the pin does to the switch |
| --- | --- | --- |
| zlib / camlzip | 1.13 → 1.14 | downgrade **1** package |
| cairo / cairo2 | 0.6.4 → 0.6.5 | downgrade **1** package |
| libffi / ctypes-foreign | 0.23.0 → 0.24.0 | downgrades `ctypes` too, and **recompiles `llvm.19-shared`, `yaml`, `zstd`** |
| zstd / zstd | 0.3 → 0.4 | **removes `ocaml-compiler` 5.4.1**, `base-effects`, `ocaml-index`; **downgrades 37 packages** (zstd 0.3 wants `ctypes` 0.20.2) |

Two of the four are single-package downgrades — design A's implicit
assumption, and the reason ssl and sqlite have worked. The other two
break it:

- **libffi's pin recompiles another project's binding.** `zstd` is a
  `ctypes` consumer, so pinning ctypes-foreign for libffi's backward cell
  rebuilds zstd's binding underneath it. The two projects' binding axes
  are coupled through a shared dependency neither declares.
- **zstd's pin removes the compiler.** A scenario that downgrades
  `ocaml-compiler` invalidates every other project's build in the switch,
  and the recovery is a full reinstall.

Design A's mitigation is a world assertion — the probe checks the switch
holds its declared pin and fails loudly otherwise. That catches *crossing*
(scenario X running under scenario Y's pin). It does not help here: the
switch would be correct for zstd@0.3 and unusable for everything else.

### 5c. What this does to §4's recommendation

§4 said "**A now, B documented as the fallback**", with B (per-version
lightweight switches) becoming attractive "only if we want scenario
parallelism or find the world assertions too fragile". Neither condition
fired — a third one did: **A only works while pins are self-contained,
and that is a property of the dependency graph, not of our design.** It
held for the four projects that have a binding axis today and fails for
two of the four that want one next.

Revised reading, not yet a decision:

1. **A remains right for self-contained pins.** zlib and cairo could take
   their binding axis today, in the shared switch, with the existing
   `pin_check_post` + world assertion. That is two more full 2×2s for a
   field on the template.
2. **B (or one dedicated canary switch) is now REQUIRED, not optional**,
   for any project whose pin is not self-contained — and self-containment
   is measurable up front with the dry-run above, so it can be a landing
   check rather than a discovery.
3. **The cheap middle** is one canary-owned switch rather than one per
   version: it removes the "some other tool's switch" hazard and lets a
   destructive pin be destructive in a switch nothing else needs, without
   paying B's per-scenario switch cost. It does not give parallelism.

Whichever is chosen, the landing rule gains a step: **before declaring a
binding pair, dry-run the older pin and record what it moves.** A pair
that removes the compiler is not a pair, it is a switch requirement.

### 5d. Open items this leaves

- [ ] `Canary_opam_binding` cannot express a binding version axis
  (`versions = None`, hardcoded) — the field plus threading, small.
- [ ] Decide A-for-safe-pins vs one canary switch vs B (§5c). The binding
  axis on zstd and libffi is blocked until then.
- [ ] Add the dry-run self-containment check to the landing checklist
  (`landing.md` §3b is where the other measured gate checks live).
- [ ] zarith's and ssl's lib axes are single-point for stated reasons; if
  either gains a prebuilt they become full 2×2s with no new machinery.
