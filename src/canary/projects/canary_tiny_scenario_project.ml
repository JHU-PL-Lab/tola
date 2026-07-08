(** A2-with-factory prototype (Task 1.6, P1 path).

    Given a {!Canary_tiny_scenario.entry} and its perturbed
    stores, produce a {!Canary_step_builder.script_spec} that
    canary can run as its own project — one scenario, one
    project spec, no multi-variant fanning.

    Now attempting structural derivation: the [expectation]
    field is computed from [recipe.violates] instead of
    dispatched from a hand-coded helper. Base spec still
    comes from {!Canary_project_tiny.make_base_script_spec};
    only the expectation gets replaced.

    Coverage today (structural):
    - c1 (Contract 1, cmp_symbol): Probe (Binding lang) fires
      [Expect_compat_failure] with C_stub + Native_lib inputs.

    Falls back to hand-coded helper for scenarios whose
    contracts aren't derived yet (currently: everything
    except c1-only recipes). Grows one contract at a time.

    Not yet doing:
    - baseline store synthesis (relies on [tiny-scenarios
      prepare] outputs, as today).
*)

(** Derive an [expectation] function from the scenario's
    [recipe.violates] contract list.

    Each contract has its own inputs shape; this dispatches
    per contract. MVP handles c1 only. Contracts not covered
    fall through to [Expect_success]. *)
let expectation_of_recipe (recipe : Canary_tiny_scenario.tiny_recipe)
  : Canary_basic.rule -> Canary_store.location option ->
    Canary_step_model.step_expectation
  =
  let module CC = Canary_compat in
  let violates_c1 =
    Base.List.mem recipe.violates CC.C1 ~equal:Base.Poly.equal in
  fun rule _loc ->
    match rule with
    | Canary_basic.Probe (Binding lang) when violates_c1 ->
      let lang_dir = Canary_lang.string_of_lang lang in
      Expect_compat_failure {
        inputs = CC.[
          C_stub
            [ Printf.sprintf "build_binding_%s/inspect.json" lang_dir ];
          Native_lib [ "build_lib/inspect.json" ];
        ];
        version_info = None;
      }
    | _ -> Expect_success

(** Is a recipe covered by the structural derivation today?

    Returns [true] when every contract in [recipe.violates]
    has a case in {!expectation_of_recipe}. Used by
    {!script_spec_of_entry} to decide whether to derive or
    fall back to the hand-coded helper. *)
let recipe_is_derivable (recipe : Canary_tiny_scenario.tiny_recipe) : bool =
  let module CC = Canary_compat in
  let covered = function CC.C1 -> true | _ -> false in
  (not (Base.List.is_empty recipe.violates))
  && Base.List.for_all recipe.violates ~f:covered

let script_spec_of_entry
    ~(perturbed_stores : Canary_project_tiny.tiny_stores)
    (entry : Canary_tiny_scenario.entry)
  : Canary_step_builder.script_spec
  =
  if recipe_is_derivable entry.recipe then
    { (Canary_project_tiny.make_base_script_spec
         ~stores:perturbed_stores ())
      with
      expectation = expectation_of_recipe entry.recipe;
    }
  else
    (* Fall back to the hand-coded helper by name until each
       contract's derivation lands. Cases here should shrink
       as [expectation_of_recipe] grows. *)
    match entry.scenario.name with
    | _ ->
      Stdlib.failwith
        (Printf.sprintf
           "Canary_tiny_scenario_project: recipe for %S \
            uses contracts not yet derivable and no \
            fallback dispatch exists"
           entry.scenario.name)

(** Convenience: look up the entry by scenario name and build
    the spec. Raises via [name_of_string] on unknown names. *)
let script_spec_of_name
    ~(perturbed_stores : Canary_project_tiny.tiny_stores)
    (name : string)
  : Canary_step_builder.script_spec
  =
  let name = Canary_tiny_scenario.name_of_string name in
  match Canary_tiny_scenario.find_by_name name with
  | Some entry -> script_spec_of_entry ~perturbed_stores entry
  | None ->
    Stdlib.failwith
      (Printf.sprintf
         "Canary_tiny_scenario_project: no entry with name %S" name)
