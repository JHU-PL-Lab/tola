# Canary Status

> 2026-08-16. Current state, the M2 milestone (M1 completed — see the
> worklog), and open items.
> Project-level status (M3) moved to [`project/status_project.md`](project/status_project.md)
> in the 2026-08-12 doc reorganization; the project index is
> [`project/projects.md`](project/projects.md). Historical context in
> [`worklog_2026_08.md`](worklog/worklog_2026_08.md).

## Current state

- **Pattern-based enumeration** — `patterns_of` primary path (18 universal chains from
  action catalogue). Per-project scenario counts are PROJECT status —
  the current snapshot lives in
  [`project/projects.md` §2](project/projects.md).
- **Project registry** — `Canary_registry.all_projects` is THE single source of truth
  for project names; `action`/`spec`/`scenarios` each do one `List.assoc_opt` lookup
  (2026-08-12).
- **Shared `run_project_spec`** — in `canary_runner.ml` (main/; moved with the
  project-layer reorganization, 0c6d5b8). CLI (`canary action`) and
  project tests call the same function. Returns `scenario_run_result` records. Display
  stays in bin layer.
- **tiny1 via general path** — `project_run_of_tiny1` converts any tiny1 scenario into a
  `project_run`. `canary action tiny1/<name>` runs through the general pipeline (agnostic
  expectation). All 22 scenarios pass (re-verified `tiny run`: 22 PASS, 0 FAIL,
  2026-08-16). Behavioral detection (c3/c7) fixed via probe.log
  fallback in `Expect_compat_derived` runtime resolution.
- **Canonical scenario naming** — `canonical_name_of` in `canary_tiny_scenario.ml`.
  Format: `Sc.<stage>.<terminal-action>_on_<deps>[.<fault>_on_<artifact>]`. `canary tiny
  scenario` prints the tentative table. `canary tiny expected-all` prints canary expected
  outcomes (shared SSOT between oracle and agnostic).
- **`action_sig` merged** — `consumes_of_action`/`produces_of_action` derived from the
  typed action catalogue. `artifacts_of_action` = `consumes @ produces` (except
  `Build_app` which omits transitive `Lib`). One source of truth per action.
- **Module layout** — `Canary_artifact` / `Canary_binding_decl` (base/),
  `Canary_project_spec` / `Canary_enumerate` / `Canary_binding_templates` (action/),
  `Canary_project_run` + `Canary_registry` (projects/).
  No circular deps (the registry lives in its own module — dune rejects the
  project_modules ↔ project_run cycle).
- **Binding declaration + realization** (M2 steps 4-5) —
  `Canary_binding_decl.binding_decl` (base/, flat record: mechanism +
  c_api + native + coupling + surface_path — no "facts" suffix,
  2026-08-16) declares WHAT a binding is; `Canary_binding_templates`
  (action/) derives the build recipe (`build_recipe` — mechanism model
  `recipe_of_decl`) + the command builders. tiny's runner_spec derives
  from its three decls (byte-equal to the former literals, pinned +
  actions.log-diffed). External projects: declaration universal, build
  commands respected as-is (Raw) — see M2 step 5.
- **Honest binding mechanisms** (2026-08-17) — z3/llvm's wheel-bundled
  Python bindings re-declared Ctypes (were Cext — no compiled extension
  exists); the artifact tables + scenario identities follow the truth.
- **Tests** — 95 project + 109 artifact + 14 PM = 218 total (2026-08-19). Post-check convention in
  CLAUDE.md: `make canary-test` after every edit, `make canary-post-check` before commit.
- **Docs** — the `design/enumeration/` stage docs are current. `stage0_naming.md` (canonical naming +
  contract catalogue). Project docs reorganized under `project/` (index + status +
  pytorch plan). Dead code cleared (`nodes_of_action_graph`, `path_id_of_node`,
  `string_of_firing_site` are comment-only).

- **GH CI is alive again** (2026-08-27, extended 08-28). It had not run
  successfully since April and was failing every push. `canary_min.yml`
  now runs **eight projects green on `ubuntu-latest`** — sqlite, cairo,
  zarith, libffi, zlib, zstd, ssl, llvm, the cheapest world of each,
  45–199s per job — rendered from the LIVE pipeline (`Canary_ci` over
  `Canary_pipeline.steps_of`) rather than from the per-project
  `*_ci_spec` values that had drifted. Two red cells reproduce there:
  llvm's `Opcode.UncondBr` and ssl's c2 on `probe_app_ocaml`. A `.github/actions/canary-setup`
  composite action carries the shared setup, and each job also renders as
  a shell twin under `_out/canary/ci/<job>.sh` so a CI job can be
  debugged without pushing. The pre-A5 `canary_ci.yml` (5 jobs, all red
  at their `*_summary` step) is `workflow_dispatch`-only until its jobs
  are migrated — [`project/issues.md`](project/issues.md) §2.

## Milestone directions

### M1 — Framework hardening → COMPLETED (2026-08-16)

All twelve items done; chronicled in
[`worklog/worklog_2026_08.md`](worklog/worklog_2026_08.md) §2026-08-16.
The one item that outlived the milestone (pre/post-checking picture)
moved to M2 step 10.

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
                       - the binding_decl payload (flat record; the build
                         HOW is a separate stage — action/ build_recipe)
  surface/             contract × layer = WHAT to check (abstract) +
                       inputs_of_contract (the contract×mechanism bridge)
  project/             declares binding lang → mechanism (already in
                       artifact_id's Ext_mechanism) + the binding_decl
  action/              decl → build_recipe (mechanism model) → commands
  lowering/            contract × mechanism → concrete firing + inputs
```

**Constraint**: M2 is structural reorg + dispatch. The existing checking
and tests (67 project + 107 artifact, tiny1 22/22, sqlite/z3/llvm) must
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
   [`mechanism_payload.md`](design/mechanism_payload.md), 2026-08-12; split
   from the command derivation 2026-08-15, user). A project declares
   its binding as ONE flat typed record
   (`binding_decl = { mechanism; c_api; native; coupling; surface_path }`
   — the build field REMOVED entirely 2026-08-16, it belongs to step
   5's stage; no "facts" suffix — the payload is fact-level by
   construction). This is UNIVERSAL and mandatory — the payload spec
   should be obvious; it is what checker/contract selection reads, so
   every project declares it regardless of how it builds. Mechanism
   name stays artifact identity; payload rides as declaration data.
   tiny declares (2026-08-13). Remaining: sqlite/z3/llvm declare
   their decls, and the wiring — `pr_binding_decls` on `project_run` (the
   spec-audit sub-object; unblocked now that the repo-model refactor
   committed, e40c73e).
5. [ ] **Build as a separate stage** (split from the payload 2026-08-15,
   user) — how to build is its OWN datatype, not part of the
   declaration: `Canary_binding_templates.build_recipe`
   (`Dune_targets` / `Verify_product` / `Raw`), derived by the
   mechanism model `recipe_of_decl` from the decl's facts; `Raw` =
   the project's own command (external projects — respected as-is,
   tricky commandline details bypassed). tiny: done (2026-08-15 —
   build_binding / probe_binding / probe_lib /
   binding_user_facing_pkg derive from the three decls; byte-equal
   to the former hand-written literals, pinned +
   actions.log-diffed). Note the model's cstubs ⇒ Dune_targets is
   TINY's convention — z3's cstubs builds via a cmake target, so when
   z3 declares its decl its recipe is Raw / a project override.
   Everywhere else commands stay Raw — external
   projects' original commands are respected as-is (tricky commandline
   details bypassed in the beginning). Translating external raw
   commands into templates is DEFERRED, not a to-do (user,
   2026-08-15). Remaining: the raw-override warning; delete
   `mi_artifact_shape` prose.
6. [ ] **Contract registry unification** — design in
   [`agreement_registry_audit.md`](design/agreement_registry.md)
   (2026-08-17, merged 2026-08-21): one
   statement per contract (invariant as a FALSIFIER, tool-based inputs,
   evidence kind, firing derived from mechanism × provision); the
   per-project binding tables converge onto it and get deleted.
   **Not descopable for the paper** (user, 2026-08-26): the runner side
   is working — landing a project is cheap — but what a landing
   *checks* is still per-project tables, and no PR has been driven off a
   checker. Growing the roster without this adds rows, not claims. It is
   stage 2 of [`research/plan.md` §4](plan.md)'s delivery
   pipeline; the catalogue itself is 3 of 20 sections confirmed and
   resumes at its §2 *Artifact surfaces*.
7. [ ] **Contract wiring gaps** — c4/OCaml is Placeholder (abi_soname_bump
   OCaml probe not predicted); `symbol_orphan`'s build failure has no
   contract. Known in `canary_expected_of` table. (Closes inside
   step 6 — these rows land on the typed ground.)
8. [ ] **Richer inspectors** — L1b/L2/L4 fields declared but no inspectors.
   Each needs: inspector → predict closure → binding rows.
9. [ ] **Fault tags ↔ contracts sync** — `sym_missing`, `api_drop`,
   `behavior`, `abi_soname`, `sym_version`, `type_arity`, `api_repack`,
   `api_add`. Sync with SSOT when stable.
10. [ ] **Canonical naming settle** — tentative scheme → final. Clean
   `Sc.`-prefixed IDs. Provision-aware names for real projects.
10. [ ] **Pre/post-checking picture** (user 2026-08-12; moved from M1
   2026-08-16 — the mechanism issue is now solid). The user originally
   wanted pre + post checking for ALL actions in slow mode. Current
   state: `check_pre` is the AUTOMATIC dependency check ("every dep
   tag's output_dir contains…" — canary_step_builder.ml ~L911-930,
   re-bound per step); `check_post` is the per-action postcondition
   (`default_check_post` via `marker_of_action`, overridable via
   `runner_spec.check_post`); `pin_check_post` (2026-08-12) is a
   `check_post` OVERRIDE, not a new mechanism. To confirm: whether the
   original slow-mode idea needs anything beyond today's
   default-marker table + per-action overrides (e.g. deeper artifact
   verification on a slow-mode flag).

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
reorganization; the roster + landing mechanics in
[`project/projects.md`](project/projects.md) + [`project/landing.md`](project/landing.md).

### Source provisioning — what is still open (2026-08-28)

The built behaviour is [pass 1](design/enumeration/stage1_declare_spec.md)
(what a declared repo becomes, why not submodules, partial-vs-shallow)
and [pass 5](design/enumeration/stage5_realize_steps.md) §3b–3c (an
unread fetch is not realized; a fetch prepares once and ensures per
world). What is NOT done:

- **Pass 5 receives commands, not the world.** `derive_steps` takes a
  `runner_spec`, so a step cannot be gated on a provision — which is why
  "don't realize a fetch nothing consumes" is decided from the step list
  a pass after `source_is_read` already asks the same question at
  enumeration. Threading the assignment through is what demand-driven
  derivation needs, and it is the same missing thread as the two
  dependency relations above. Costs, measured: the scenario id is the
  cache key, so renamed worlds re-run cold (happily the cheap
  all-`Fetched` ones), and `z3.dispatch_reads_source_placement` asserts
  over every assignment including the non-building baseline. Recorded in
  [`design/enumeration/README.md`](design/enumeration/README.md) *Known
  drift*.
- **`prepare` as a dispatched action** rather than a guard inside the
  fetch command — the structural half of the same gap, and what
  `worktree_ensure_cmd`'s comment has always said it should be.
- **Caching opam on CI** — the measured dominant cost of a job
  ([`project/issues.md`](project/issues.md) §2). Caching the contrib tree
  is a distant second and should be keyed by repository, not (repo, ref).
- **Validating a declared source ref without fetching it** —
  `git ls-remote`, 1.1s, filed beside `spec-check --probe-pm` in
  [`design/platform.md`](design/platform.md) §7.

### Design directions (pending more cases)

- **Checks as actions — `[Pre; Action; Post]`** (user, 2026-08-18,
  compiler perspective): promote the pre/post checks from step payloads
  (check_pre/check_post closures) to FIRST-CLASS ACTIONS — the
  enumeration emits `[Pre; Action; Post]` triples and the runner
  interprets checks exactly as commands (uniform warm-mask
  fingerprinting included). Payoff: the belief matrix (contract
  registry) becomes a property of the enumeration — every cell IS an
  action in the graph, and the coverage pin becomes an enumeration
  invariant. The smoke probe / staged-parity / decl-comparison cells
  are the natural first Check actions.

  **Why this also matters to CI** (2026-08-30):
  [`design/check_evaluation.md`](design/check_evaluation.md). The GH
  backend renders `check_pre`/`check_post` ZERO times, because a closure
  cannot cross the compiler/interpreter boundary — so a green CI job means
  only "every command exited 0", and the sqlite pin failure (command
  succeeds, `check_post` fails) would be invisible there. That doc also
  records what is cheap (`check_post` is already file tests plus one shell
  command) versus what is not (expectation evaluation parses `inspect.json`
  and drives the comparators), and the one constraint on doing it: a
  check's predicate and its rendering must come from the SAME constructor,
  never two hand-written forms.


- **Action/artifact property unification** — `build_deps_of`, `ax_follows`, `ax_runtime`,
  `c_runtime`/`cxx_abi`, probe location all sit at the action↔artifact boundary.
- **`(kind × ext)` → enriched `artifact_kind`** — fold identity pair into one type.
- **Enumeration ↔ configuration split — config as dependency resolving**
  (user, 2026-08-16): raw enumeration = the full product over
  artifact-kind universes with ONLY uniform kind-level dependency rules
  (Built-lib↔source CHANNEL coupling, binding↔lib, app↔binding) —
  repo-agnostic, as C2 confirmed. Configurability = the CONSTRAINT
  layer: the channel-coupling + `ax_follows` are today's hardwired
  matchers; the path is to express them as declared per-project
  constraints + config-selected constraint sets over (artifact ×
  provision × version × repo) placements, with `version_mode` growing
  from Lockstep/Independent into a matcher parameter — so canary's
  config becomes a special case of GENERAL dependency resolving (the
  same constraint vocabulary a package solver reasons over), and
  future complex dependencies (ranges, conflicts, multi-repo sources)
  plug into the same machinery instead of new filter code. Enabling
  step (project layer): multi-source artifact identity — see
  status_project.md §3.

## Docs

- [ ] **Regenerate `tiny.md`** — current doc is tiny1-era; rewrite for tiny-factory /
  tiny1 / tiny-full split with canonical naming.
- [ ] **`backlog.md` audit** — cross-reference with this file; retire closed items.
