(** [project_run] — the interface a generic cross-project runner consumes
    (ssot §4.2.5 / the convergence). A project DECLARES four things; the
    generic runner ([canary_main.run_project_run]) does the uniform
    enumerate → materialize → runner_spec → run for any project:

    - [pr_enumerate] — the scenario space as [Canary_enumerate.assignment]s
      (per-artifact provision × version [× quality for tiny]).
    - [pr_materialize] — place whatever must exist *before* the run (a
      source tree, cached artifacts); returns the runnable workspace path.
      `Built`/`Fetched` are NOT placed here — they are canary *actions*
      (build_lib / fetch_lib) the runner runs and observes. A pure-Fetched
      project (sqlite) barely materializes anything.
    - [pr_runner_spec] — the runner_spec for a materialized scenario, given the
      assignment (so version/provision-parameterized actions can read the
      per-artifact placement) and the workspace.
    - [pr_provenance] — STATIC, per-artifact provider for `spec` (no execution):
      the typed [Canary_store_config.provider] backing the abstract [artifact_id]
      + [placement] can't carry — a vendored PATH, a source_repo to build from, or
      a PM + PACKAGE. [None] = undeclared. A project DECLARES this; `spec` displays
      it (and cross-checks [provision_of_provider] against the baseline provision,
      so the two can't drift) — the artifact list is verifiably spec-sourced.

    tiny-full and sqlite both fill this; z3/llvm stay on the raw-script
    [run_project_multi] until/unless they adopt it (copy-modify). *)
type project_run = {
  pr_name : string;
  pr_artifacts : Canary_enumerate.artifact_id list;
  pr_enumerate : unit -> Canary_enumerate.assignment list;
  pr_materialize : Canary_enumerate.assignment -> string option;
  pr_runner_spec :
    Canary_enumerate.assignment -> workspace:string ->
    Canary_step_builder.runner_spec;
  pr_provenance :
    Canary_enumerate.artifact_id -> Canary_store_config.provider option;
}
