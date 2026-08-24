# The action playbook — how an action flows through canary, and the Publish case study

**Kind: how-to.** The procedure for adding an action, with Publish as the worked example. The machinery it describes exists.

> 2026-08-17. Written from the Publish generalization (active plan 2):
> the "how to add an action" checklist (the orthogonality surface), the
> Publish worked example, and the refactoring plan the case study
> surfaced. 2026-08-18: §4 — the lighter EXTENSION checklist (a new
> artifact kind on an existing action), from the off-tree
> binding-source case.

## 0. New action vs extending an action — the fork in the road

- **A NEW action** (a new `action` constructor) = the ten-touchpoint
  checklist below (§1).
- **EXTENDING an existing action with a new ARTIFACT KIND** (e.g.
  `Fetch (Binding_source l)` — the 2026-08-18 off-tree binding source)
  = the lighter checklist in §4. The action constructor, its
  provision gate, its deps/marker defaults, and the execution path
  are inherited; the work is the kind's vocabulary + its typed
  catalogue row + the DEPENDENT actions' consumes (the DAG edge) +
  display slots.

## 1. The checklist — the ten touch points an action passes through

1. **The action variant** — `action` type (`src/canary/base/canary_basic.ml`,
   e.g. `Publish of artifact_kind`), its tag in `string_of_action`/
   `action_of_string` (`pack_binding_<lang>` / `pack_<kind>`), and — for
   binding-shaped actions — `step_dir_of_tag`'s verb mapping
   (`pack_binding_ocaml` → `pack_binding/ocaml`).
2. **The catalogue** — `store_actions` (`src/canary/action/canary_action.ml`)
   says which actions exist per project; `consumes_of_action`/
   `produces_of_action` say what each touches (hand-written cases where
   the typed `action_catalogue` doesn't cover the action — a finding,
   see §3); `action_requires_provision` (`canary_action_templates.ml`)
   gates rows on the target artifact's provision (`Publish _ → Built`).
3. **The path table** — `canary_path_table.ml` enumerates the provenance
   chains for display (`canary paths`). Not every action appears here
   (Publish doesn't) — a display gap, not a correctness one.
4. **The runner_spec slot** — declare the field on `runner_spec`
   (`canary_step_builder.ml`, e.g. `pack_binding`), default it in
   `empty_runner_spec`, dispatch it in `script_of_action`, clear it in
   `no_source`.
5. **Deps + marker + check_post** — `deps_of_action` (what must complete
   first), `marker_of_action`/`default_check_post` (the `.ok` file),
   the per-project `check_post` override hook (pin checks, world
   assertions).
6. **Emission** — `derive_steps` emits one step per wired slot; probe
   steps consume the action via `deps_of_probe_entry` (e.g. a non-
   build-tree probe depends on the Publish when it exists); inspect
   summaries attach to whichever install step exists.
7. **Project rows / realization** — the action-row layer
   (`canary_action_templates.ml`: `action_row`, `Raw` escape,
   `realize_from_rows`' provision-gated filtering and append-merge) or a
   hand-built `runner_spec` closure; the project's `realize` dispatches
   per scenario.
8. **Execution** — `canary_local_runner.ml`: the step's cmd, the
   expectation resolution (incl. the compat-derived predictions), the
   verdict marker, the per-step cache (warm skips).
9. **Declarations** — the static-audit side (`pr_wrapper_pkgs` →
   spec-check's item) so the spec checker sees the feature without
   executing anything.
10. **The repo/template side** — wrapper package files under
    `canary/templates/opam-local-repo/packages/<pkg>/<pkg>.<ver>/opam`
    (+ `.in`/`.in.tpl` for generated ones), the idempotent
    `canary-local` registration, and the renderer that generates them
    (`canary_opam_template.ml`).

## 2. The Publish case study (active plan 2, landed 2026-08-17)

The feature: the ocaml/opam-binding pattern publishes its wrapper
package. What it touched, checklist order:

- **Slot** (existing): `pack_binding` on `runner_spec` — already wired
  end to end (marker `pack.ok`, deps = `build_binding`, provision gate
  Built). Filling a slot is the CHEAP way to add a feature — the
  catalogue machinery predates the pattern.
- **The primitive** (new, tool layer): `Canary_pm_opam.pack_wrapper_cmd`
  — subst the wrapper's `opam.in` (three live-learned opam details: the
  package dir is `<name>.<version>` under a name dir — `packages/zarith/
  zarith-no-conf.dev/`; `opam config subst` APPENDS `.in` itself so the
  target is the base name; the `%{VAR}%` interpolation reads the
  `OPAMVAR_`-prefixed env var), idempotent `canary-local` registration,
  drop the conflicting store packages, install over the scenario's
  source, write the marker. Generalizes the dead `opam_pack_cmd`.
- **The renderer** (new, tool layer): `Canary_opam_template` — one
  skeleton, per-project build bodies (`wrapper_decl`); the rendered
  files stay committed; a pin asserts byte-equality (the M2
  discipline).
- **The pattern wiring** (project layer): `pack_binding` in the
  bind_built scenarios + the pin-checked postcondition (`pin_check_post
  ~pkg ~pin:"dev"` — the store provably holds the published state) +
  the world-check half: the Fetched-binding probe verifies the store
  holds the STOCK package (the stable repo's version id) and
  self-heals by reinstalling it — each scenario lands itself in the
  right world IN-RUN (the pin-switch dance, enumeration/stage3_identity.md
  §10).
- **Declaration**: `pr_wrapper_pkgs` derives from the decl — spec-check
  goes Ok without executing anything.

## 3. The refactoring plan (orthogonality findings)

The case study surfaced six non-orthogonal spots — the follow-up work:

1. **Publish into the typed `action_catalogue`** — its
   consumes/produces are hand-written cases in `canary_action.ml`
   (:374/:388); the typed catalogue (`canary_basic.ml`) covers
   Fetch/Build/Probe only. Fold Publish in so the derivation is
   uniform.
2. **`canary_path_table.ml` has no pack entries** — the 15-pattern
   display omits Publish entirely. Add the pack-pattern rows or state
   explicitly why provenance chains stop at build/fetch (a doc note
   may be the honest answer — Publish doesn't produce new artifact
   identities, it mutates the store).
3. **Retire the legacy pack helpers** — `opam_pack_cmd` and
   `install_local_cmd` (`canary_toolchain.ml`) are now superseded by
   `Canary_pm_opam.pack_wrapper_cmd`; delete them (after confirming
   zero consumers).
4. **`render_opam_in` (z3, project-side) → `Canary_opam_template`** —
   z3.dev's `.tpl` flow is the renderer's second consumer; migrate it
   (the `%%Z3_CMAKE_BUILD_FLAGS%%` substitution = the renderer's first
   parameterized body).
5. **Repo registration for local runs** — previously relied on a
   manually-registered `canary-local`; the primitive now self-registers
   (CI keeps its explicit step).
6. **The warm-skip gate must consult `check_post`** (FIXED in this
   pass, `canary_local_runner.ml`): BOTH skip sites — `run_graph`'s
   verdict-marker seed and `run_step`'s local-cache branch — now
   require `check_post` to still hold. The code had drifted from the
   documented doctrine (a warm skip only fires when the store provably
   holds the state): a stale marker over a changed store was a silent
   PASS for the wrong world (the z3 pin dance had the same latent hole
   — its warm skips now re-verify the pins too).

And the future uses the same shape: tiny's Publish = the same
`wrapper_decl` + primitive when it wants an opam-visible artifact; pip
bindings follow with a pip-side primitive.

## 4. The EXTENSION checklist — a new artifact kind on an existing action

> 2026-08-18, from the off-tree binding-source case (`Fetch
> (Binding_source l)`, commit `f5db302` + its follow-ups): the binding
> may live in a different repo than the lib (zarith vs system gmp).
> The lighter path — no new constructor:

1. **The kind** — `artifact_kind` (`canary_basic.ml` — the base
   vocabulary) + `kind_order` + `string_of_artifact_kind`, and the
   `artifact` alias in `canary_artifact.ml` (it re-lists the
   constructors — keep it IN SYNC, the compiler enforces the match)
   + the `a_<kind>` constructor + `string_of_artifact`.
2. **The action instance's name** — a dedicated `string_of_action`
   case when the generic `fetch_<kind>` spelling isn't the wanted tag
   (`fetch_binding_source_ocaml`, not `fetch_ocaml_binding_source`).
   `step_dir_of_tag` may need a dedicated mapping — the verb loop's
   `fetch_binding_` prefix would misroute the new tag to
   `fetch_binding/source_ocaml`.
3. **The typed catalogue row** (THE DAG decision) —
   `action_catalogue` (`canary_basic.ml`): the new Fetch row
   (consumes [], produces the kind, `Ambient`). This is where
   tree/dag membership is decided — `consumes_of_action`/
   `produces_of_action`, `chains_for`/`universal_chains`,
   `node_of_assignment` all read it.
4. **The dependent actions' consumes — the DAG EDGE**: a binding
   built from an off-tree source consumes it: `Build_binding l`
   gains `Binding_source l`. Two consequences the pins caught:
   - `chains_for` must branch BOTH ways for the new consume —
     WITHOUT the fetch (on-tree specs, the source rides the lib's)
     and WITH it (off-tree specs) — a mandatory consume would break
     every on-tree project's chains (the `mechanism.…` + `derive.Sc.2`
     failures were this).
   - the derivation/inventory pins' expected kind lists shift
     (`related_artifacts_of_actions`, `consumed_artifacts_of_actions`
     — ORDER matters: the consume precedes the produce in the union).
5. **The runner slot + defaults** — the per-lang slot on
   `runner_spec` (empty in `empty_runner_spec`), `script_of_action`,
   `marker_of_action` (`binding_source.ok`), the runner-side dep in
   `deps_of_action` (`Build_binding` waits for the fetch when wired).
6. **The catalogue walk** — `store_actions` gains the fetch at the
   per-language block's front (the scenario chains' anticipation; no
   project wiring it = no step emitted — `derive_steps` skips unwired
   actions).
7. **The display layers** — the path table (kind prefix + the verb),
   the diagram (kind label + probe mapping), the matrix's canonical
   column order (the per-language block's leading slot).
8. **The compiler's exhaustiveness sweep** — every `match` on the
   kind without a wildcard is a checklist item the compiler hands
   you; work through them (enumerate, scenario, store_config,
   tiny_scenario, project_run…).
9. **The kind-ratchet pins** — the catalogue pin's expected
   consumes/produces rows, the derivation pins' unions, the tiny
   synthesis counts (`recipe_of_derived_cell`'s Some/None totals —
   a new kind adds None cells until a parametric recipe exists).
10. **The IDEMPOTENCY note** — a repo providing BOTH the source and
    the binding source (on-tree bindings) wires the SAME fetch; the
    repo is already there (the `Source_fetch` local `test -d` path).
    The provider's `artifacts` contents list already declares
    multi-artifact provision.
