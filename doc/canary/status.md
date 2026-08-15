# Canary Status

> 2026-08-12. Current state, two milestone directions (M1/M2), and open items.
> Project-level status (M3) moved to [`project/status_project.md`](project/status_project.md)
> in the 2026-08-12 doc reorganization; the project index is
> [`project/index.md`](project/index.md). Historical context in
> [`worklog_2026_08.md`](worklog/worklog_2026_08.md).

## Current state

- **Pattern-based enumeration** — `patterns_of` primary path (18 universal chains from
  action catalogue). 3 scenarios each for z3/llvm/sqlite, 1 for tiny-full, 1 each for
  zarith/cairo/libffi (registry `simple`).
- **Project registry** — `Canary_registry.all_projects` is THE single source of truth
  for project names; `action`/`spec`/`scenarios` each do one `List.assoc_opt` lookup
  (2026-08-12).
- **Shared `run_project_spec`** — in `canary_project_run.ml`. CLI (`canary action`) and
  project tests call the same function. Returns `scenario_run_result` records. Display
  stays in bin layer.
- **tiny1 via general path** — `project_run_of_tiny1` converts any tiny1 scenario into a
  `project_run`. `canary action tiny1/<name>` runs through the general pipeline (agnostic
  expectation). All 22 scenarios pass. Behavioral detection (c3/c7) fixed via probe.log
  fallback in `Expect_compat_derived` runtime resolution.
- **Canonical scenario naming** — `canonical_name_of` in `canary_tiny_scenario.ml`.
  Format: `Sc.<stage>.<terminal-action>_on_<deps>[.<fault>_on_<artifact>]`. `canary tiny
  scenario` prints the tentative table. `canary tiny expected-all` prints canary expected
  outcomes (shared SSOT between oracle and agnostic).
- **`action_sig` merged** — `consumes_of_action`/`produces_of_action` derived from the
  typed action catalogue. `artifacts_of_action` = `consumes @ produces` (except
  `Build_app` which omits transitive `Lib`). One source of truth per action.
- **Module layout** — `Canary_artifact` (base/), `Canary_project_spec` (action/),
  `Canary_enumerate` (action/), `Canary_project_run` + `Canary_registry` (projects/).
  No circular deps (the registry lives in its own module — dune rejects the
  project_modules ↔ project_run cycle).
- **Tests** — 58 project + 107 artifact + 14 PM = 179 total. Post-check convention in
  CLAUDE.md: `make canary-test` after every edit, `make canary-post-check` before commit.
- **Docs** — `algorithm_explainer.md` current. `scenario.md` (canonical naming +
  contract catalogue). Project docs reorganized under `project/` (index + status +
  pytorch plan). Dead code cleared (`nodes_of_action_graph`, `path_id_of_node`,
  `string_of_firing_site` are comment-only).

## Milestone directions

### M1 — Framework hardening

General code quality: testing coverage, dead-code elimination, refactoring.

- [x] `run_project_spec` extraction — shared between CLI and tests
- [x] `action_sig` merge — `consumes_of_action`/`produces_of_action` derived from catalogue
- [x] Dead code — `nodes_of_action_graph`, `path_id_of_node`, `string_of_firing_site`
- [x] Post-check convention — `make canary-test`, `make canary-post-check`, CLAUDE.md
- [x] `patterns_of` dedup
- [x] **F5: replumb `canary stages` through enumeration** — `covered_actions_of` in
  `canary_project_run.ml` derives the action set from enumerated scenarios via
  `derive_steps`. `canary_scenario_coverage.ml` still provides the stage catalogue
  and display (it was never the problem — only the input source was legacy).
- [x] **Project registry** (2026-08-12) — zarith/cairo/libffi migrate to
  `project_run` (`Canary_project_run.simple` wrapping their Pattern A
  `runner_spec`); `Canary_registry.all_projects` is THE single source of
  truth for project names (dune rejected the registry inside
  `canary_project_run` — a module cycle with the project modules that
  reference its type; hence `canary_registry.ml`). `action`/`spec`/
  `scenarios` each do ONE `List.assoc_opt` lookup. `run_legacy` +
  sqlite's pre-action-table `runner_spec`/`built_spec` deleted.
- [x] **ssl store-pin migration** (2026-08-12) — `Lang_pkg.versions` pins
  → 2 enumerated ssl scenarios; pin-checked fetch + world assertions; the
  registry's `Multi` entry kind deleted (all 8 entries plain
  `project_run`s). Also fixed the spec's pre/post label join (delta
  scenarios rendered `·` though they ran) and the lang-blind `probe_app`
  slot. Details in `project/store_switching.md`.
- [x] **z3 store-pin migration** (2026-08-12) — stable binding pinned
  "4.16.0" (explicit pinned fetch + pin-check + world-checked probe);
  dev Publish pin-checked ("dev"); `opam_pin` gained the `install_name`
  escape + the pin-check verifies the OPAM version. En-route fixes the
  first full dev-chain run exposed: the action-table fold now merges ALL
  action fields (configure/scan/headers/install/build_binding/publish
  were silently dropped); build-chain rows require a Built lib; probe
  rows are provision-filtered; `-G Ninja` restored. FINDING: official z3
  HEAD's OCaml binding is broken upstream — the arbipher fork restored as
  the Dev source (see `project/status_project.md`).
- [x] **Typed template dispatch** (2026-08-14) — `canary_action_table.ml` →
  `canary_action_templates.ml`: the 19 string-keyed primitives became typed
  constructors (project rows name WHAT; tool/ owns HOW; a bad param is a
  compile error). `probe_lib_location` is a typed variant (build_tree lib /
  build_tree glob / staged / pm). All 37 `Primitive` sites in z3/llvm/sqlite
  converted; `templates.source_fetch_local_skips_clone` pins the restored
  locals behavior (M3 item 1 folded in).
- [x] **Module-init side effects** (2026-08-14) — `detect_pm` made
  per-call everywhere (ssl's `pm ()` thunk + templates realize-time call;
  no top-level `let pm =` sites left; the detection itself stays
  memoized). Registry loads touch no PM.
- [ ] **Confirm the general pre/post-checking picture** (user, 2026-08-12) —
  the user originally wanted pre + post checking for ALL actions in slow
  mode. Current state: `check_pre` is the AUTOMATIC dependency check
  ("every dep tag's output_dir contains…" — canary_step_builder.ml
  ~L911-930, re-bound per step), `check_post` is the per-action
  postcondition (`default_check_post` via `marker_of_action`, overridable
  via `runner_spec.check_post`). `pin_check_post` (2026-08-12) is a
  `check_post` OVERRIDE, not a new mechanism — the naming follows the
  existing convention. To confirm: whether the original slow-mode idea
  needs anything beyond today's default-marker table + per-action
  overrides (e.g. deeper artifact verification on a slow-mode flag).

### M2 — Invariants & contracts

Formalize artifact invariants, contracts, expectations, and mechanism. Grow checking
reliability so the current checks and future bindings (Java, Rust, etc.) are consistent.
Flash back and sync with SSOT.

**Centralization target** (agreed 2026-08-12; mechanism moved to base
2026-08-14, user-directed): the mechanism vocabulary (identity +
catalogue + binding_decl payload) lives in base/ as WORKING code the
lowering reads; the contracts (WHAT each contract checks, by layer)
stay in surface/ with the contract×mechanism bridge. A project declares
its mechanism per binding — the lowering derives the concrete checking
from contract × mechanism.

```
  base/                mechanism = HOW it manifests (vocabulary the
                       lowering consumes):
                       - which steps fire (Static: build_binding + probe;
                         Dynamic: probe only — no compile stage)
                       - which inputs (Cstubs → stub .a; Cext → cext .so;
                         Ctypes → dlopen at probe, no static inputs)
                       - the binding_decl payload (typed facts + coupling)
  surface/             contract × layer = WHAT to check (abstract) +
                       inputs_of_contract (the contract×mechanism bridge)
  project/             declares binding lang → mechanism (already in
                       artifact_id's Ext_mechanism)
  lowering/            contract × mechanism → concrete firing + inputs
```

**Constraint**: M2 is structural reorg + dispatch. The existing checking
and tests (55 project + 107 artifact, tiny1 22/22, sqlite/z3/llvm) must
keep working throughout — the hand-written per-project binding tables
produce the same firings as the templated ones.

Steps (each step keeps the suite green before the next):

1. [x] **Mechanism vocabulary reunited in base** (2026-08-12 split,
   2026-08-14 reunited, user-directed) — `canary_mechanism.ml` (base/) now
   holds identity + catalogue + stage-existence predicate, and
   `canary_binding_decl.ml` (the typed payload) moved to base/ beside it:
   mechanism is BASE vocabulary the lowering works with, not display prose.
   The contract×mechanism bridge (`inputs_of_contract`) stays in surface/
   with the contracts it feeds. No behavior change.
2. [x] **Mechanism input template** (2026-08-12) — `inputs_of_contract
   (contract, lang)` in `surface/canary_compat_run.ml` produces the
   input KINDS + standard inspect paths (tiny's convention). tiny's binding
   table now calls it; `inputs_template_pin` locks the template equal to the
   former hand-written rows (no behavior change). Deviating layouts (z3's
   fetch-step attrs, llvm's summary_stub.json) keep hand-written rows —
   the template covers the common case. Mechanism refinement (dynamic =
   no stub input) comes with step 3.
3. [x] **Mechanism as derivation axis** (2026-08-12) — the enumeration reads
   the binding artifact's mechanism key to derive: (a) chain shape —
   `chain_applicable` requires a STATIC binding for any `build_binding`
   action (`has_static_binding`); a Dynamic_ffi binding (ctypes/dynlink)
   gets probe-only chains; (b) template inputs — `inputs_of_contract
   ?mechanism` returns no stub input for dynamic bindings (runtime fallback
   catches failures). `mechanism_chain_shape_pin` locks the derivation.
   No current project's scenario count changes (all have static bindings
   alongside; tiny-full's cext keeps the build chain applicable).
4. [ ] **Typed mechanism payload — the DECLARATION** (design in
   [`mechanism_payload.md`](mechanism_payload.md), 2026-08-12; split
   from the command derivation 2026-08-15, user). A project declares
   its binding as ONE typed record (mechanism + facts). This is
   UNIVERSAL and mandatory — the payload spec should be obvious; it is
   what checker/contract selection reads, so every project declares it
   regardless of how it builds. Mechanism name stays artifact identity;
   payload rides as declaration data. tiny declares (2026-08-13);
   sqlite/z3/llvm facts-declaration remains (open: whether the
   coupling's [build] recipe stays a mandatory field — for external
   projects the build is their raw command's business).
5. [ ] **Command derivation from the payload** — a SEPARATE topic: the
   lowering derives build/probe templates from the decl only where the
   command is mechanism-determined. tiny: done (2026-08-15 —
   `Canary_binding_templates` derives build_binding / probe_binding /
   probe_lib / binding_user_facing_pkg from the three decls; byte-equal
   to the former hand-written literals, pinned +
   actions.log-diffed). Everywhere else commands stay Raw — external
   projects' original commands are respected as-is (tricky commandline
   details bypassed in the beginning). Translating external raw
   commands into templates is DEFERRED, not a to-do (user,
   2026-08-15). Remaining: the raw-override warning; delete
   `mi_artifact_shape` prose.
6. [ ] **Contract wiring gaps** — c4/OCaml is Placeholder (abi_soname_bump
   OCaml probe not predicted); `symbol_orphan`'s build failure has no
   contract. Known in `canary_expected_of` table. (After steps 4–5 —
   these rows land on the typed ground.)
7. [ ] **Richer inspectors** — L1b/L2/L4 fields declared but no inspectors.
   Each needs: inspector → predict closure → binding rows.
8. [ ] **Fault tags ↔ contracts sync** — `sym_missing`, `api_drop`,
   `behavior`, `abi_soname`, `sym_version`, `type_arity`, `api_repack`,
   `api_add`. Sync with SSOT when stable.
9. [ ] **Canonical naming settle** — tentative scheme → final. Clean
   `Sc.`-prefixed IDs. Provision-aware names for real projects.

Deferred (design directions, not M2):

- `ax_follows` derived from action catalogue — `Build_binding` consumes
  `Lib` → binding naturally follows lib's version. Derive from
  `Follows_input`.
- Build-config as an axis — `as_config` on `action_sig` placeholder.

### M3 — Grow projects → moved to [`project/status_project.md`](project/status_project.md)

Extend coverage, find/detect real bugs, fix them with GH PRs. Surface results from
cmd/cache to a web page with checking results and fixed-bug reports. The whole
project-level status (bugs, issues, todo, candidates) lives in
[`project/status_project.md`](project/status_project.md) since the 2026-08-12 doc
reorganization; the project index + landing mechanics in
[`project/index.md`](project/index.md).

### Design directions (pending more cases)

- **Action/artifact property unification** — `build_deps_of`, `ax_follows`, `ax_runtime`,
  `c_runtime`/`cxx_abi`, probe location all sit at the action↔artifact boundary.
- **`(kind × ext)` → enriched `artifact_kind`** — fold identity pair into one type.

## Docs

- [x] **`project/` doc directory** (2026-08-12) — five files: `index.md`
  (conceptual model + portfolio, was `projects.md`), `coverage.md` (status
  matrix + landing history), `landing.md` (workflow + testing harness),
  `status_project.md` (was `design/package_bug.md` + M3),
  `project_pytorch.md` (was `design/`). Cross-references swept; the
  deleted `scenario_terms.md` links now point at M2 "Canonical naming
  settle". The stale `onboard-new-project` skill deleted — its replacement
  will build on `landing.md`.
- [ ] **Regenerate `tiny.md`** — current doc is tiny1-era; rewrite for tiny-factory /
  tiny1 / tiny-full split with canonical naming.
- [ ] **`backlog.md` audit** — cross-reference with this file; retire closed items.
