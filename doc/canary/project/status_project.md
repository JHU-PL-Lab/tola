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

## 2. Bugs & issues

### Fixed — libffi binding declared Cstubs (M2 step 3 finding)

> 2026-08-12 surfaced, fixed 2026-08-13 with the spec-check fulfillment.

`Canary_project_run.simple` hardcoded the binding as `Cstubs`
(Static_c_abi) — but ctypes-foreign is genuinely Dynamic_ffi (resolves
and calls C functions at RUNTIME via libffi; no compiled stub links
against libffi). Fixed by retiring `simple` entirely: Pattern A now
declares typed rows via `Canary_pattern_a.artifacts`/`run`, with a
`binding_mechanism` field on `Canary_pattern_a.t` — libffi declares
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

> 2026-08-12 observed, 2026-08-13 re-checked.

The 08-12 observation (the `latest_HEAD` clone "lacks the `llvm/` subdir
and CMakeLists at the clone root") does **not** reproduce: official HEAD
has `llvm/` (GitHub API), a fresh depth-1 clone of
`llvm/llvm-project.git` checks out the full monorepo fine, and the
stable chain clones the same official repo every run. The 08-12 state
was a transient/partial clone. Dev stays on the arbipher fork for its
local checkout + warm build tree until `source_fetch` honors locals
(filed to-do) — then Dev can point at official with a local checkout.

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

## 3. Todo (moved from status.md §M3)

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
- [ ] **Fetched provision for tiny** — the one provision tiny still lacks.
- [ ] **Location sub-axis** — probe locations (build-tree/staged/pm)
  unmodeled as a first-class scenario axis. First slice landed: PM probe
  resolution is per-project action-table config (dpkg/ldconfig params +
  `probe_lib_needs`). Full enumeration (location in `assignment` →
  separate scenarios per location; location-aware `scenario_dir_of`;
  display + test pins) waits on a project where build_tree vs staged
  probes produce materially different results — the forcing case.
- [ ] **Flavor 2 (deploy-mismatch)** — `close_deps`/`dep_mode =
  Independent` built, not yet wired to a live run through
  `run_project_spec`.
- [ ] **Web results page** — extend `canary_html.ml` with per-project bug
  reports and fixed-PR links (the `docs/canary/projects/` mirror exists;
  content is per-run artifacts, not reports).
- [ ] **Real-world PRs** — find a bug with canary, fix it, submit
  upstream PR, link from the results page.
- [ ] **New project candidates** — OpenSSL/libressl, protobuf, grpc,
  jq/oniguruma, lwt+libev, cvc5, PyTorch (plan in
  [`project_pytorch.md`](project_pytorch.md)). Queue + sequencing in
  [`index.md` §2](index.md).
- [ ] **`source_fetch` primitive honor locals** — the table primitive
  always clones from the remote URL (a wasteful ~1-2 GB llvm-project
  clone into `_out` on every fresh dev-chain run) even when the row's
  `local` checkout exists and the build uses it. The old
  `source_fetch_cmd distro source` skipped the clone for locals — the
  primitive should too (an optional `local` param). Functional today;
  pure waste.
- [ ] **Upstream z3 PR — POST_BUILD self-check env isolation**
  (2026-08-13) — z3's ml CMake self-check resolves dlls ambiently (see
  the Fixed entry in §2); a 2-line CMake patch pins the built artifacts.
  Pushing needs an arbipher/z3 branch + PR to Z3Prover/z3 (confirm the
  fork is ours to push). PR/report is a core motivation of the project
  — revisit with the three-version report.
- [ ] **Fetched-source version id in the run-cache key** (2026-08-13) —
  the fork↔official z3 flip changed the scenario dir but warm-skipped
  every step over stale markers (see the Found entry in §2). The
  assignment string must carry the Fetched source's version id — a
  three-version-report blocker (official vs forked dev collide).
- [ ] **Build-step store-hazard audit** — the z3 self-check shadowing is
  a CLASS: build steps that run OCaml bytecode/native self-checks read
  the global store (stublibs/apt) unless guarded. Audit other projects'
  build_binding steps (llvm's `ocaml_all` has no bytecode self-check —
  believed clean); consider generalizing the `env_guard` param or
  documenting the pattern in the action-table.
- [ ] **Docs-mirror cp noise** — copying fetched clones into
  `docs/canary/projects/` fails on the read-only `.git` pack files
  (Permission denied, non-fatal). Cosmetic: skip `.git` in the mirror
  copy.
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
