(** [Canary] — thin compatibility shim re-exporting the three action-graph
    sub-modules.

    The original [Canary] held five distinct topics in one 648-line file
    (project_config legacy + action_graph + step model + path table +
    mermaid helpers). On 2026-06-01 (Phase 5 of the post-audit refactor):
    - dead [project_config] / [verify_of_phase] / [steps_of_phase] moved
      to [doc/_legacy_code/canary_yaml_backend.ml];
    - the remaining four topics split into:
      - {!Canary_action} — actions, pools, store_actions, make_action_graph,
        nodes_of_action_graph, node_status (the action-graph schema).
      - {!Canary_step_model} — version_info, symbol_*, step_expectation,
        step, logger, step_status, ensure_dir, now, create_logger.
      - {!Canary_path_table} — path_origin, path_annotation, job_path,
        action_path_of_node, node_depth, annotate_path,
        job_paths_of_action_graph, pattern_row, pattern_rows_of_paths,
        pp_job_path_table, pp_job_path_table_md.

    The runner half (runner_spec, derive_steps, run_step, run_graph)
    lives in {!Canary_runner}.

    This shim [include]s each so existing [open Canary] keeps working.
    Callers can also open individual modules for precision. *)

include Canary_action
include Canary_step_model
include Canary_path_table
