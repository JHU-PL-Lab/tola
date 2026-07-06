(** General scenario type — project-agnostic.

    A [scenario] names a collection of actions over interested
    artifacts. It describes *what happens* in this state of the
    world; the good/bad classification is checker-relative and
    is intentionally NOT part of this type (postponed with the
    contract work — see [doc/canary/design/ssot.md] §9.3).

    Task 1 of the §9.3 remodel introduces this type. The
    project-specific machinery for actually constructing the
    scenario's world (perturbation, patches, etc.) lives in a
    per-project "recipe" layer alongside its scenario values
    (e.g. [Canary_tiny_scenario.tiny_recipe]).

    Term note (per [ssot.md §6]): [actions] uses
    [Canary_basic.rule] which we plan to rename to [action] in a
    later sweep. Constructor names ([Fetch], [Build_lib], …)
    survive the rename. *)

type scenario = {
  name : string;
  description : string;
  actions : Canary_basic.rule list;
  interested_artifacts : Canary_basic.artifact_kind list;
}
