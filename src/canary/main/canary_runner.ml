(* ── THE runner half of the project pipeline (2026-08-14, the main-library
   split) ──

   [Canary_project_run] (src/canary/project, the project-datatype layer)
   owns the project_run TYPE + pure spec helpers; this module owns the
   EXECUTION: enumerate → runner_spec → derive_steps → run, producing
   per-scenario results. It lives in the main library — the RUNNING layer
   shared by the cmd, the layer tests, and the batch runner
   ([Canary_batch]) — which takes a concrete [project_run] and (via the
   runner) reaches the project modules' realizations. *)

open Canary_project_run

(** One scenario's run result — the structured output of
    [run_project_spec] that both CLI display and test assertions
    consume. *)
type scenario_run_result = {
  r_result_assignment : Canary_artifact.assignment;
  r_result_key : string;
  r_result_is_bad : bool;
  r_result_verdict : string;         (** "PASS" or "FAIL" *)
  r_result_culprits : string list;   (** failed step tags, empty on PASS *)
  r_result_xfails : (string * string list) list;
      (** [(step_tag, [contract_id])] for confirmed expected failures *)
}

(** Run a project through the full pipeline: enumerate → runner_spec →
    derive_steps → execute. Returns per-scenario results. The shared
    payload — both [canary action] (CLI) and project tests call this;
    display and assertions are the caller's job. *)
let run_project_spec ?policy (pr : project_run) ~root
    ~failfast : scenario_run_result list =
  let module SM = Canary_step_model in
  let module BH = Base.Hashtbl in
  let all_good = assignment_is_all_good in
  (* RUN order, not enumeration order (2026-08-21,
     design/enumeration/stage4_order.md §3):
     scenarios needing the same single-valued store state run
     consecutively, so a pinned package is installed once per distinct pin
     instead of once per row. Stable, so the enumeration's order survives
     inside each group. *)
  let scenarios = Canary_pipeline.ordered ?policy pr in
  let baseline =
    try List.find all_good scenarios
    with Not_found -> (match scenarios with a :: _ -> a | [] -> [])
  in
  let seen = Hashtbl.create 16 in
  let results = ref [] in
  List.iter
    (fun a ->
      let ctx = Canary_pipeline.ctx_of pr a in
      let ws = ctx.Canary_pipeline.sc_workspace in
      if Hashtbl.mem seen ws then ()
      else begin
        Hashtbl.add seen ws ();
        let is_bad = not (all_good a) in
        let project = ctx.Canary_pipeline.sc_project in
        let steps = Canary_pipeline.steps_of ~root pr ~ctx a in
        let status =
          Canary_run_info.run_project ~failfast
            ~run_info:
              (Canary_run_info.mk_run_info ~project:pr.pr_name
                 ~version:"scenario" ~ref_:"" ~source:"prebuilt" ~extra:[] steps)
            ~root ~project steps
        in
        let not_done =
          List.filter_map
            (fun (s : SM.step) ->
              let tag = s.SM.tag in
              let st = try Some (BH.find_exn status tag) with _ -> None in
              match st with
              | Some SM.Step_done | Some SM.Step_done_xfail -> None
              | Some SM.Step_failed -> Some (tag ^ ":failed")
              | Some SM.Step_skipped -> Some (tag ^ ":skipped")
              | None -> Some (tag ^ ":not_run"))
            steps
        in
        let xfails =
          List.filter_map
            (fun (s : SM.step) ->
              let st = try Some (BH.find_exn status s.SM.tag) with _ -> None in
              match st with
              | Some SM.Step_done_xfail ->
                  let ids = Canary_local_runner.step_xfail_contracts s in
                  Some (s.SM.tag, ids)
              | _ -> None)
            steps
        in
        let verdict = if not_done = [] then "PASS" else "FAIL" in
        let key =
          let deltas =
            List.filter_map
              (fun (id, pl) ->
                let s = Canary_enumerate.string_of_assignment [ (id, pl) ] in
                match Canary_enumerate.placement_of baseline id with
                | Some bl ->
                    if
                      String.equal s
                        (Canary_enumerate.string_of_assignment [ (id, bl) ])
                    then None
                    else Some (Canary_artifact.pretty_id id ^ "=" ^ s)
                | None -> None)
              a
          in
          match deltas with [] -> "(baseline)" | _ -> String.concat "  " deltas
        in
        results :=
          { r_result_assignment = a; r_result_key = key;
            r_result_is_bad = is_bad; r_result_verdict = verdict;
            r_result_culprits = not_done; r_result_xfails = xfails }
          :: !results
      end)
    scenarios;
  List.rev !results
