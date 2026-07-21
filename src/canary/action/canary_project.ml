(** [Canary_project] — the [project] bundle at the top of the
    operational taxonomy (SSOT §6.1).

    A project semantically owns its scenarios (Model A per user
    2026-07-21). The concrete scenario_spec types are project-specific
    (tiny_recipe for tiny; z3/llvm will introduce their own once
    variants are recast) and live in [projects/] where each project's
    module exports them alongside its own [<name>_project : project]
    value. This module sits in [action/] and only holds the fields
    every project can share concretely.

    Fields today (concrete, monomorphic — per user 2026-07-21
    preference "concrete over polymorphic"):

    - [name] — CLI subcommand identifier + output-tree root.
    - [contract_bindings] — per-(contract, lang) firing table
      consumed by {!Canary_scenario.lower_expectation}. Empty for
      positive-only projects.

    Deliberately NOT fields here:
    - [scenarios] — each project's own module owns them
      concretely ([Canary_tiny_scenario.all_scenario_specs], z3/llvm
      variants). A [scenarios] field on this type would need either
      polymorphism (rejected by user), a variant enum (needs
      concrete project types visible → module would move to
      [projects/]), or an opaque/GADT wrapper (overkill). Revisit if
      a generic cross-project runner needs uniform iteration —
      likely alongside the {b variant} case added for adapting to
      old [Canary_step_builder.runner_spec] when Task 3 rename
      lands.
    - [api_source] — [Canary_artifact_source.source_repo] lives in
      the [tool/] layer; would create a downward dependency.
      Callers look it up per-project.

    {b Naming distinction} — do not confuse with
    [Canary_step_builder.runner_spec]. The two live on different
    levels of the SSOT §6.1 taxonomy:

    - [project] (this type) sits at the {b top} — one per system
      under test (tiny, z3, llvm, sqlite).
    - [runner_spec] sits at the {b bottom} — the runner-facing
      handoff, one per (project × scenario / variant) instance,
      carrying the concrete [expectation : rule -> loc -> step_expectation]
      + build/probe/inspect commands. Task 3 renames it to
      [runner_spec] / [variant_spec] once this [project] type is
      settled.

    See [doc/canary/design/ssot.md] §6.1 for the full taxonomy row. *)

type project = {
  name : string;
  contract_bindings : Canary_scenario.contract_binding list;
}
