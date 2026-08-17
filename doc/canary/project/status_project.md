# Project status — bugs, issues, todo

> 2026-08-12. What's wrong, what's fixed, what's next — for the *projects*
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

**Scenario counts** (the enumeration snapshot, re-verified
`spec @all` 2026-08-16, post-C2; full policy unless noted):

| project | scenarios | shape |
| --- | --- | --- |
| z3 / llvm | 5 | 3 all-Fetched source worlds (stable / official latest / arbipher fork) + 2 dev build chains (latest + fork); `--thin` = 1 (stable) |
| sqlite | 3 | system-fetched lib + 2 built amalgamation versions |
| zarith | 3 | per-channel source repos + the FORWARD cell (source-fetched-1.14 / -master × binding built-dev; the lib axis is Fetched-only — prebuilt-shadows-source) |
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

### Fixed — libffi binding declared Cstubs (M2 step 3 finding)

> 2026-08-12 surfaced, fixed 2026-08-13 with the spec-check fulfillment.

`Canary_project_run.simple` hardcoded the binding as `Cstubs`
(Static_c_abi) — but ctypes-foreign is genuinely Dynamic_ffi (resolves
and calls C functions at RUNTIME via libffi; no compiled stub links
against libffi). Fixed by retiring `simple` entirely: Pattern A now
declares typed rows via `Canary_opam_binding.artifacts`/`run`, with a
`binding_mechanism` field on `Canary_opam_binding.t` — libffi declares
`Ctypes`, zarith/cairo `Cstubs`. (The `chain_applicable` build_binding
gating is unaffected: none of them build the binding.)

### Fixed — sqlite PM probe: pkg-config dependency gap

> Documented 2026-08-09, fixed 2026-08-11 (was `design/package_bug.md`,
> folded here in the reorganization).

**Symptom.** `action sqlite` failed on the all-Fetched scenario with
`sqlite3_ symbols exported: 0` → `sh: test: Illegal number: 0` →
`probe_lib:failed`. The scenario had **no PM lib probe at all** until the
fix (the row was commented out).

**Root cause.** The `native_lib_probe` primitive with `location = "pm"`
resolved the lib only via `pkg-config`; sqlite3 (apt `libsqlite3-dev`)
installs no `.pc` file. z3/llvm ship `.pc` files (cmake generates them),
so only sqlite hit it — the classic autotools-package case.

**Fix.** The PM probe primitive gained optional `dpkg_pkg` +
`ldconfig_name` params — resolution chain:
`pkg-config` → `dpkg -L <pkg> | grep <lib>` → `ldconfig -p` → (macOS)
`brew --prefix`. sqlite's action table declares them; the probe finds
`/usr/lib/x86_64-linux-gnu/libsqlite3.so` and counts 287 `sqlite3_`
symbols. Verified: all 3 sqlite scenarios PASS cold.

**Also fixed en route** (the row landed on top of the action-table
plumbing): `merge_list` in `realize_from_rows` was last-row-wins (multiple
probe_lib locations collapsed) → now appends; `probe_lib_needs` filters
build_tree/staged probes to Built-lib scenarios; z3/llvm staged rows were
missing their `location` param (would crash `get "location"`); the Raw
handler didn't dispatch `Build_lib`/`Configure`/`Install_lib` at all.

### Fixed — llvm dev probe: llvm-config indirection on a binary ninja never builds

> 2026-08-13, found by the llvm store-pin verification run.

The dev chain's Raw probe row resolved the built lib via
`build/bin/llvm-config` (`--provided-lib "$($LLVM_CONFIG --libdir)"/libLLVM.so`),
but `ninja LLVM` builds only the dylib — `bin/llvm-config` exists in
neither a cold nor the warm build tree. The `$(...)` substitution expanded
empty, `assert_binary_symbols.py` got `--provided-lib /libLLVM.so`
("ERROR: file not found"), and the probe died before `ocamlopt` (no
probe.log). Fix: probe the build libdir directly
(`--provided-lib <build>/lib/libLLVM.so`), matching the realize
Build_tree row. Verified warm: dev scenario PASS.

### Fixed — z3 official HEAD: "unknown C primitive" was env shadowing, not an upstream break

> 2026-08-12 detected, 2026-08-13 root-caused + fixed.

The 08-12 finding "official z3 HEAD's OCaml binding is broken upstream"
was **wrong**. The real mechanism (reproduced on a fresh official-HEAD
clone, commit 9f184aa8a):

- z3's `build_z3_ocaml_bindings` target runs a POST_BUILD self-check —
  the bytecode example via `ocamlrun` and the native example — both with
  AMBIENT dll search (the CMakeLists sets only `DYLD_LIBRARY_PATH`, a
  macOS no-op).
- The opam switch's stublibs holds a stale `dllz3ml.so` (the pinned
  z3.4.16.0, or a published z3.dev). `CAML_LD_LIBRARY_PATH` beats the
  bytecode's embedded `-dllpath`, so the switch's dll shadows the fresh
  one; its primitive table lacks `n_solver_register_on_clause` (added
  Feb 2026, commit 234913bf5) → `Fatal error: unknown C primitive`.
  Proven by re-running the self-check with the build dir prefixed to
  `CAML_LD_LIBRARY_PATH`: the full bytecode suite passes green.
- The arbipher fork "fixed" it only by predating the new external (its
  self-check had nothing to miss). Same shared-store hazard class as the
  pins — but a BUILD step's self-check reading the store, not a probe.

Fix (canary-side, three layers — the store shadowed THREE times):

1. **Build self-check** — the dev Build_binding row guards the ninja
   step's env (`CAML_LD_LIBRARY_PATH=$(pwd)/<build>/src/api/ml:$CAML_LD_LIBRARY_PATH
   LD_LIBRARY_PATH=$(pwd)/<build>` — new optional `env_guard` param on
   the `ninja_build_binding` primitive; paths must be ABSOLUTE, the
   self-check runs from `<build>/src/api/ml`).
2. **Probe link** — the built cmxa embeds `-L<stublibs> -L<build>
   -lz3`: the STORE's stale libz3.so wins the `-lz3` search, so the
   probe exe linked the pinned 4.16.0 lib and died on the new
   finite-set API (and in the fork era it linked the store lib
   SILENTLY — the dev probe was not probing the built lib at all). The
   probe row now passes `-cclib "$LIB_Z3"` (full path) so the exe
   links the built lib; the probe log now shows `z3 version: 5.0.0.0`.
3. **Publish paths** — the z3.dev package script runs from the opam
   sandbox build dir; relative `CANARY_*` env paths (`_out/...`) don't
   exist there (cmake -S died). The Publish row now absolutizes them
   (`$(pwd)/`).

`z3_source_of Dev` back to the official `z3_source_latest` (the fork
stays declared as the three-version-report candidate). Verified: full
`action z3` PASS on both scenarios (2026-08-13), probe against the
built 5.0.0.0 lib. Upstream angle: z3's POST_BUILD self-check should
pin its own artifacts — PR candidate, needs go-ahead.

### Resolved — llvm official-HEAD clone: transient, not upstream

> 2026-08-12 observed, 2026-08-13 re-checked, **2026-08-16 re-diagnosed (C2)**.

The 08-12 observation (the `latest_HEAD` clone "lacks the `llvm/` subdir
and CMakeLists at the clone root") was a MISDIAGNOSIS on both dates: the
clone was always fine. C2's cold run of the official-latest dev chain
reproduced the configure failure against a COMPLETE monorepo clone and
found the real bug — the table rows probed `root/llvm/CMakeLists.txt` on
the filesystem at REALIZE time, before the fetch step runs, so a fresh
`_out` clone always resolved the cmake source to `root` (the local
checkout passed only because it exists at realize time). Fixed: every
llvm repo is the monorepo, so the cmake source is unconditionally
`root/llvm` (canary_project_llvm.ml).

### Found — spec non-uniformities (2026-08-13, `canary spec-check`)

The static checker audits the artifact table AS DECLARED. The first
report's four non-uniformities: three CLOSED by the 2026-08-13
fulfillment (pattern-A typed rows + sources, sqlite's source row +
api_source, tiny-full's `pr_api_source`); the remaining ones are
recorded here, reported as-is, NOT special-cased in checker code:

- **z3/llvm** source rows carry the STABLE repo's provider; per-channel
  (dev) source providers are the known not-yet-wired provenance
  refinement.
- **tiny-full** declares its api_source on `project_run.pr_api_source`
  (its source row is Vendored, not repo-carried) and is exempt from the
  reporting-oriented checks (in-tree witness).
- **sqlite's source row is declaration-coupled via `~follows:a_lib`**
  (the amalgamation version IS the lib's version) — source-follows-lib
  is a new axis direction, first used here.

### Found — install step died on the missing z3 executable (2026-08-16, C2)

The C2 cold run of z3's official-latest dev chain failed its
`cmake --install`: "file INSTALL cannot find …/build/z3" — the A5 table
migration had dropped `-DZ3_BUILD_EXECUTABLE=OFF` (the canonical
`z3_cmake_build_flags` — still used by the z3.dev opam template) from
the Configure row, so a fresh cmake cache defaults EXECUTABLE=ON and the
install rule includes the never-built shell binary. Masked until C2:
the old scenario dir's warm `.ok` markers skipped the install step, and
the fork's contrib build tree carries a pre-A5 cache with EXECUTABLE=OFF
(cache first-write-wins). FIXED: the Configure row carries the canonical
what-is-built flags (EXECUTABLE/TEST_EXECUTABLES/JAVA/PYTHON = OFF).
General lesson: a scenario-dir rename IS a cold-run audit — warm
markers mask spec drift; the 3-way's per-repo ids re-exercised z3's
install for the first time since A5.

### Found — Fetched-source version id is NOT in the run-cache key (2026-08-13)

Flipping z3's Dev source fork→official changed the scenario DIR
(`dev_HEAD` → `latest_HEAD` — `scenario_dir_of` honors the id) but
warm-skipped EVERY step over the stale fork artifacts: the run-cache key
is the assignment string, which drops the Fetched source's version id
(Fetched-ambient) — and both sources declare `ref_ = "HEAD"`. So a
fork↔official flip is invisible to the cache (a silent PASS for the
wrong source; the step markers must be cleared by hand — done). A
three-version report (official dev vs forked dev) needs the source
version id IN the cache key, or the two scenarios collide on stale
markers.
**RESOLVED (2026-08-16, C1+C2)**: repo pins make every source placement
identity-bearing (see the §3 to-do) — `source-fetched-arbipher` vs
`source-fetched-latest` are distinct scenario dirs with distinct
per-scenario caches; the collision can't recur.

### Investigated — build-config divergence (z3/llvm): NOT a bug

Build-tree vs installed artifact flag differences were investigated as a
possible scenario blocker. **Nothing is blocked.** z3's install is REAL
(`cmake_install_cmd`; prefix carries headers + `z3.pc` + Z3Config +
versioned symlink chain; the staged probe reads "identical" to the
build-tree lib — itself a finding). llvm deliberately NOT migrated: its
`install()` rules auto-install the OCaml binding into the opam switch —
needs component filtering first. "Build config as part of Built identity"
remains an M2 design item (different cmake flags → different artifacts
from same source).

### Open — install inspection gaps

- **`make install` template** — `cmake_install` is the only templated
  install. Autotools (`make DESTDIR=$PREFIX install`), meson, etc. need
  templates. Not yet planned in detail — to be discussed (user,
  2026-08-12).
- **Build-path leakage** — `prefix_layout_inspect_cmd` inventories the
  installed tree but doesn't check for hardcoded build-tree paths (rpath
  → `_out/`, baked `-I` in `.pc` files). A default install inspection
  should verify the installed artifact is relocatable.
- **tiny install scenarios** — tiny1 has no `Install_lib` scenario. A
  `build_install` scenario (built → installed → staged-probe chain)
  would catch install embedding build paths; a `wrong_lib_install` case
  (stale artifact or dev-lib-installed-as-stable) would test install
  identity.
- Prefix safety IS enforced: `test -n "$PREFIX"` in `cmake_install_cmd`
  refuses empty/system paths — canary never global-installs (fetch
  actions are the only intended global-store writes).

### Known — CI runs the pre-A5 shape

`ci_jobs` (`canary_run.ml`) derives steps from legacy `runner_spec`
values — one chain per project, not the enumerated scenario set. Realign
with the registry when CI grows scenario coverage.

## 3. Todo

Split 2026-08-14 (user): GENERAL framework issues first, then
per-project ones.

### General (address first)

- [x] **3-way repos in the project spec** (2026-08-14, user) — per-project
  stable + official-dev + forked-dev repos as first-class spec data.
  Roadmap A+B+C1+C2 ALL LANDED (2026-08-15/16) — the full chronicle
  (contrib layout, worktrees, `Repo` unification, `Repo_axes`, the
  arbipher forks, the cold-audit fixes, the verification) is flushed
  to [`../worklog/worklog_2026_08.md`](../worklog/worklog_2026_08.md)
  §2026-08-16; the design lives in
  [`../design/repo_model.md`](../design/repo_model.md). Living state:
  the per-project scenario counts in §1 above; remaining items below
  (the verdict-matrix pin, the Fetched-source-id resolution note).
  Next: Roadmap D — the web viewer.
- [x] **Repo-provider unification** — LANDED with the 3-way (roadmap A):
  one `Repo of source_repo` variant + `Repo_axes` for per-channel
  families. Remaining half: a repo shipping an ARTIFACT directly (not
  source) has no representation — a future shape.
- [x] **conf-* survey + conf-free prototype** — DONE 2026-08-17: the
  survey is [conf_survey.md](conf_survey.md) (opam-side only); the
  `zarith-no-conf` prototype + the canary-side designs live in
  [wrapper_packages.md](wrapper_packages.md). The live install rides
  the Publish item below.
- [x] **Fetched-source version id in the run-cache key** — RESOLVED BY
  DESIGN (C1+C2): repo pins make every source placement
  identity-bearing; the fork↔official collision can't recur.

**The active plan** (the 2026-08-17 order, user-confirmed):

1. [ ] **Forward-cell expectation** — zarith's instance of the 3-way
   mismatch probes (below). The forward cell (master binding built
   from the worktree, probed against the system lib) passes today;
   a future break must surface as a PREDICTED compat finding (the
   c1 stub↔lib check, tiny-full's precedent) instead of a raw FAIL.
   Steps: a pattern-level contract binding for the built-binding
   probe (forward cell only), the built-binding inspect summary the
   c1 inputs resolve from, a pin that the expectation is
   Expect_compat_derived there and Expect_success elsewhere.
2. [x] **Publish generalization** — LANDED 2026-08-17 (active plan 2):
   the ocaml/opam-binding pattern publishes its wrapper (`zarith-no-conf`
   live-installed over the worktree, pin-checked), the world-check +
   self-heal keeps the store dance in-run, the opam-template renderer +
   the pack primitive live in the tool layer, and the case study
   produced the action playbook (action_playbook.md §3's refactoring
   plan: the typed-catalogue fold-in, the pack-path-table gap, the
   legacy-helper retirement, z3's renderer migration, and the FIXED
   warm-skip gate). Remaining (follow-ups, recorded):
   generalize z3/llvm's legacy Publish so the ocaml/opam-binding
   pattern (and tiny) can publish wrapper packages. Open: a GENERAL
   opam-template (one skeleton parameterized per project — the build
   body is the only variable part) vs per-project files; the renderer
   belongs in the TOOL layer (`canary_pm_opam.ml`'s orbit). Design in
   wrapper_packages.md §4; also settles the build-body question
   (CANARY_* env-style vs copy-into-sandbox — env-style for heavy,
   copy for tiny).
3. [x] **Shadow mechanism — prebuilt first, source-built as a SEPARATE
   AUDIT PASS** — LANDED 2026-08-17 (active plan 3), as an
   enumeration-POLICY item per the user's correction (the spec stays
   clean; the shadow is a config item used in the enumeration part):
   `shadow_policy = Shadow_prebuilt | Materialize_source`; the firing
   condition is identity-bearing same-version (built side's id =
   SOURCE-PRIMARY, both ids non-empty and equal, channels equal);
   `run_policy` gains the `Audit_lib` rung (`--audit-lib` = full +
   Materialize_source; the batch never audits); pinned by
   `enumerate.shadow_policy_drops_same_cell_built` +
   `shadow.policy_ladder`. Design in wrapper_packages.md §3.
4. [x] **binding_decls for zarith** — LANDED 2026-08-17 (active plan 4):
   the Cstubs decl wraps the system GMP with the EMPTY-prefix convention
   (user's call: GMP spans mpz_/mpq_/mpf_/mpn_ — `native.prefix = ""`,
   the FULL 42-symbol stub-required watchlist is the scoping; the
   `prefix` doc comment now allows empty); `zarith_run` carries it,
   pinned by `zarith.binding_decls_match_declared`; spec-check zarith
   1/1 declared (python_binding is the only remaining ⚠ — expected,
   OCaml-only).

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
- [ ] **Multi-source artifact identity + link guards**: extend source
  artifact identity with a repo discriminant (per-repo source rows)
  so a binding from ITS repo against a lib from ANOTHER repo is
  enumerable; then link-guard constraints (which lib channels/repos a
  binding may link), selectable per config.
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

- [ ] **Historical-bug regression field** — known bugs-with-fixes as
  declared expectations; the contract/xfail machinery shows the shape.
- [ ] **Surface-drift expectations** — per-project drift bounds on the
  TOTAL surface (C + OCaml counts); `canary inspect-diff` exists.
- [ ] **Pinned verdict-matrix regression** — pin the per-scenario
  verdict matrix (the C2 5/5 was ad-hoc); markers should record the
  verified ref; a `--cold` audit flag; CI-nightly material.
- [ ] **Build-step store-hazard audit** — the z3 self-check shadowing
  class; audit other build steps' store reads (env_guard
  generalization).

**Pending (user, 2026-08-17 — AFTER active plans 3&4)**:

- [ ] **Opam-templating gotchas as TEST CASES** — the Publish case
  study's live-learned details (the `<name>/<name>.<version>/` dir
  convention; `opam config subst` appends `.in` itself; `%{VAR}%`
  reads the `OPAMVAR_`-prefixed env var; the warm-skip gate) belong in
  the framework self-test axis (pm-test/artifact-test) — they are
  shell + tooling knowledge that generalizes to other package managers
  (pip etc.). A DEDICATED standalone opam switch (the user offered to
  prepare one) keeps the tests from mutating the main switch — tests
  would target it explicitly.
- [ ] **Extend tiny with the Publish** — the wrapper decl + primitive
  give tiny an opam-visible artifact when it wants one.

**Housekeeping**:

- [ ] **`source_fetch` primitive honor locals** — the table primitive
  always clones (~1-2 GB llvm-project) even when the row's `local`
  checkout exists. Pure waste; functional today.
- [ ] **Docs-mirror cp noise** — skip `.git` in the mirror copy.
- [ ] **Fetched provision for tiny** — the one provision tiny lacks.
- [ ] **Location sub-axis** — probe locations as a first-class axis;
  waits on a forcing case.
- [ ] **Flavor 2 (deploy-mismatch)** — `close_deps`/`dep_mode`
  built, not yet wired to a live run.
- [ ] **Web results page** — per-project bug reports + fixed-PR links
  in `canary_html.ml`.
- [ ] **Upstream z3 PR** — POST_BUILD self-check env isolation
  (2-line CMake patch); per user, AFTER the 3-way repo work.

### Per-project

- [ ] **spec-check warns fulfillment** — the ratchet-tracked ⚠ set:
  llvm's missing Publish row (`llvm.dev-shared`); the pattern-A trio +
  ssl's wrapper/python/built-binding gaps; sqlite/tiny-full's binding
  dev-source.
- [ ] **Real-world PRs** — find a bug with canary, fix it, submit
  upstream PR, link from the results page (the z3 PR above is the first
  candidate).
- [ ] **New project candidates** — OpenSSL/libressl, protobuf, grpc,
  jq/oniguruma, lwt+libev, cvc5, PyTorch (plan in
  [`project_pytorch.md`](project_pytorch.md)). Queue + sequencing in
  [`index.md` §2](index.md).

### Done (2026-08-12 → 14)

- [x] **ssl → enumerated scenarios, `Multi` deleted** (2026-08-12) — the
  store-pin mechanism landed (`Lang_pkg.versions` → pin axis → identity;
  pin-checked fetch; world assertions). 2 scenarios (0.6.0/0.7.0), each
  probing both apps as different actions; the 2×2's red cell survives as
  scenario@0.6.0's `probe_app_ocaml` xfail[c2]. Survey + design in
  [`store_switching.md`](store_switching.md).
- [x] **Shared-store pins for llvm** (2026-08-13) — stable binding pins
  "19-shared" (the standard install name `llvm.19-shared` fits — no
  `install_name` escape needed); pinned fetch + `pin_check_post` + world
  assertion on the stable probe; the Opcode.UncondBr xfail fires against
  the pinned binding. Verified warm: both scenarios PASS (dev probe
  green, stable PASS + derived xfail). En route fix: the dev probe row's
  llvm-config indirection (see the Fixed entry above). z3 DONE earlier
  the same round (2026-08-12: stable pin "4.16.0" + pinned fetch +
  pin-checked Publish + world assertions). See
  [`store_switching.md`](store_switching.md) §4 item 7.
- [x] **Spec-maturity checker** (2026-08-13, user) — `canary spec-check
  [PROJECT|@all]` (landed 2026-08-13): 8 static checks per project over
  the declared artifact table (`Canary_spec_check`, no realization/run),
  ✓/✗/⚠ + n/a (tiny-full witness exemption), `--json` for the web
  status page, exit 1 on errors; ratchet pins in
  `spec_check.{every_project_reports,ratchet_current}`. First report:
  6/8 projects with errors (see §2 "Spec non-uniformities").
- [x] **Fulfill spec-check gaps — the ERRORS** (2026-08-13): all 8
  projects error-free. sqlite (source row via `~follows:a_lib` +
  api_source + dead `sqlite_spec`/duplicate table removed), ssl
  (openssl@3.0.13 source + api_source + fetch_source), tiny-full
  (`pr_api_source`), zarith/cairo/libffi (typed pattern-A rows +
  sources + api_source; `simple` retired; libffi's honest `Ctypes`;
  github rule softened to public forge — cairo's canonical gitlab
  passes). Remaining WARNS (ratchet-tracked): llvm's missing Publish
  row, and the pattern-A trio + ssl + sqlite + tiny-full's
  wrapper/python/built-binding gaps.

## 4. Planned milestone — the three-version report (discuss later)

> 2026-08-12, user. Overall milestone; not scheduled.

Prettify the checking output into a user-friendly report: what we check
per project, what failed, and how we may help fix it. Shape: **three
versions per project** — a stable to test against, a current official
dev/latest, and a forked dev with the issue fixed. The report then tells
the maintainer "your HEAD broke X against your stable; our fork with the
fix passes". This changes `canary_html.ml`'s output from run-artifact
dumps to a maintained narrative — full design discussion deferred.
