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
