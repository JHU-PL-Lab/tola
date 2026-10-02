# The action playbook — how to add one

**Kind: how-to.** The procedure, as a checklist per touch point. The
machinery it describes exists.

**Read [`action_model.md`](action_model.md) first** if you are not sure
what you are adding. It says what an action IS — a moment with a typed
footprint — why `<action>_post` is a moment rather than a specification
of what runs at it, and therefore what should NOT become an action. In
particular: if you were about to add a step whose name ends in
`_inspect`, the answer is that you should not.

Two forks before the checklists:

## 0. New action vs extending an action — the fork in the road

- **A NEW action** (a new `action` constructor) = the ten-touchpoint
  checklist in §1.
- **EXTENDING an existing action with a new ARTIFACT KIND** (e.g.
  `Fetch (Binding_source l)` — the 2026-08-18 off-tree binding source)
  = the lighter checklist in §2. The action constructor, its
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
   tracked in [`../backlog.md`](../backlog.md) §52); `action_requires_provision` (`canary_action_templates.ml`)
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


## 2. The EXTENSION checklist — a new artifact kind on an existing action

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
   gains `Binding_source l`. Two consequences the tests caught:
   - `chains_for` must branch BOTH ways for the new consume —
     WITHOUT the fetch (on-tree specs, the source rides the lib's)
     and WITH it (off-tree specs) — a mandatory consume would break
     every on-tree project's chains (the `mechanism.…` + `derive.Sc.2`
     failures were this).
   - the derivation/inventory tests' expected kind lists shift
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
9. **The kind-ratchet tests** — the catalogue test's expected
   consumes/produces rows, the derivation tests' unions, the tiny
   synthesis counts (`recipe_of_derived_cell`'s Some/None totals —
   a new kind adds None cells until a parametric recipe exists).
10. **The IDEMPOTENCY note** — a repo providing BOTH the source and
    the binding source (on-tree bindings) wires the SAME fetch; the
    repo is already there (the `Source_fetch` local `test -d` path).
    The provider's `artifacts` contents list already declares
    multi-artifact provision.

## 3. What the worked examples taught

Two features went through the checklists, and the durable part is small.
The chronology is in [`../worklog/`](../worklog/); these are the things
that would cost a day again.

**Filling a slot is the cheap way to add a feature.** Publish
(2026-08-17) touched nine of the ten points and needed a new constructor
for none of them: `pack_binding` was already wired end to end — marker
`pack.ok`, deps `build_binding`, provision gate Built. The catalogue
machinery predates most of the features that use it, so check for an
empty slot before adding a constructor.

**Three opam details, each learned by getting it wrong:**

- a wrapper package's directory is `<name>.<version>` **under a name
  dir** — `packages/zarith/zarith-no-conf.dev/`;
- `opam config subst` **appends `.in` itself**, so the target you name
  is the base name, not the template;
- `%{VAR}%` interpolation reads the **`OPAMVAR_`-prefixed** environment
  variable.

**A rendered file that is committed needs a byte-equality test.**
`Canary_opam_template` renders one skeleton with per-project build
bodies; the rendered `opam.in` files stay in the tree, and
`tool.opam_template_render` asserts the renderer still produces them. It
earns its keep: a doc-filename change in a project's `description`
string failed it on 2026-09-16, which is exactly the drift it exists to
catch.

**A warm skip must consult `check_post`.** Found here, fixed here: both
skip sites required only the marker, so a stale marker over a changed
store was a silent PASS for the wrong world. A warm skip fires only when
the store provably still holds the state.

