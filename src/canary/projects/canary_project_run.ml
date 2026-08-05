(** [project_run] — the interface a generic cross-project runner consumes
    (ssot §4.2.5 / the convergence). A project DECLARES these; the generic
    runner ([canary_main.run_project_run]) does the uniform
    enumerate → runner_spec → run for any project:

    - [pr_enumerate] — the scenario space as [Canary_enumerate.assignment]s
      (per-artifact provision × version [× quality for tiny]).
    - [pr_runner_spec] — the runner_spec for one scenario (assignment), given
      the assignment (so version/provision-parameterized actions read the
      per-artifact placement) and a runner-chosen [workspace] dir
      ([canary_main.scenario_dir_of] — the scenario's output + identity dir).
      A project builds/fetches into that dir (sqlite); a project that needs a
      pre-assembled tree (tiny-full) assembles it INSIDE its own runner_spec
      closure — the "assemble/materialize" concern stays in tiny-factory
      ([canary_tiny_workspace]) and never appears in this general interface.
      `Built`/`Fetched` artifacts are NOT pre-placed — they are canary *actions*
      (build_lib / fetch_lib) the runner runs and observes.
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
  pr_runner_spec :
    Canary_enumerate.assignment -> workspace:string ->
    Canary_step_builder.runner_spec;
  pr_provenance :
    Canary_enumerate.artifact_id -> Canary_store_config.provider option;
}
