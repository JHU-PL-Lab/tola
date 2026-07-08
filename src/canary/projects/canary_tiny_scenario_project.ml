(** A2-with-factory prototype (Task 1.6, P1 path).

    Given a {!Canary_tiny_scenario.entry} and its perturbed
    stores, produce a {!Canary_step_builder.script_spec} that
    canary can run as its own project — one scenario, one
    project spec, no multi-variant fanning.

    MVP dispatches on scenario name to the existing
    [make_*_script_spec] helpers in {!Canary_project_tiny}.
    That's the "naive mapping" hypothesis — if a name-keyed
    switch is sufficient for all 15 entries, we can promote
    it to derived construction (from [perturbation] +
    [recipe.violates] shape) as a follow-up. See [doc/canary/
    worklog/worklog_2026_07.md] for the arc.

    Not yet doing:
    - baseline store synthesis (relies on [tiny-scenarios
      prepare] outputs, as today);
    - expected-result derivation (each helper hand-codes its
      [Expect_compat_failure]); still tracked as postponed
      axis.
*)

let script_spec_of_entry
    ~(perturbed_stores : Canary_project_tiny.tiny_stores)
    (entry : Canary_tiny_scenario.entry)
  : Canary_step_builder.script_spec
  =
  let name = entry.scenario.name in
  match name with
  | "symbol_missing" ->
    Canary_project_tiny.make_lib_broken_script_spec
      ~stores:perturbed_stores ()
  | _ ->
    Stdlib.failwith
      (Printf.sprintf
         "Canary_tiny_scenario_project: no factory dispatch \
          yet for scenario %S (MVP covers symbol_missing only)"
         name)

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
