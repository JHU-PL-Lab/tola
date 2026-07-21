(** [Canary_project] — the [project] bundle at the top of the
    operational taxonomy (SSOT §6.1).

    A project owns its concrete scenarios and the per-project data the
    runner needs to lower any of those scenarios to a runner-facing
    step list:

    - [scenarios] — the project's concrete scenario_spec values (tiny:
      15 hand + 7 derived = 22; z3/llvm: variants, once recast; sqlite:
      empty by design).
    - [contract_bindings] — per-(contract, lang) firing table consumed
      by {!Canary_scenario.lower_expectation}. Empty for positive-only
      projects.

    [api_source] (the native lib + surface claims) is intentionally
    NOT a field here: [source_repo] lives in the [tool/] layer and
    would create a downward dependency. Callers who need it look it
    up per-project (via each project's own module — e.g.
    [Canary_project_llvm.llvm_source_dev]). Revisit if a real
    generic consumer needs it.

    Parametric on [scenario_spec] because each project has its own
    concrete recipe/mutation representation (tiny_recipe for tiny; z3
    and llvm will introduce their own once variants are recast as
    scenarios). Callers that need to work across projects instantiate
    the type parameter at the call site or hide it behind their own
    dispatch.

    {b Naming distinction} — do not confuse with
    [Canary_step_builder.project_spec]. The two live on different
    layers of the SSOT §6.1 taxonomy:

    - [project] (this type) sits at the {b top} — one per system
      under test (tiny, z3, llvm, sqlite); owns scenarios + bindings.
    - [project_spec] sits at the {b bottom} — the runner-facing
      handoff, one per (project × variant / scenario) instance,
      carrying the concrete [expectation : rule -> loc -> step_expectation]
      + build/probe/inspect commands. Task 3 renames it to
      [runner_spec] / [variant_spec] once this [project] type is
      settled.

    See [doc/canary/design/ssot.md] §6.1 for the full taxonomy row. *)

type 'scenario_spec project = {
  name : string;
    (** Stable identifier matching the CLI subcommand ([action tiny],
        [action z3], ...). Also used as the output-tree root
        ([_out/canary/projects/<name>/]). *)

  scenarios : 'scenario_spec list;
    (** Concrete scenarios this project runs. Empty is legit
        (positive-only projects, or projects whose variants haven't
        been recast as scenarios yet). *)

  contract_bindings : Canary_scenario.contract_binding list;
    (** Per-(contract, lang) failure-observation table. Consumed by
        {!Canary_scenario.lower_expectation} at scenario-run time. *)
}
