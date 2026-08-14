(* ── THE batch runner (2026-08-14) ──

   Runs a list of projects under the tier-based default config — a
   callable, customizable, testable function; the CLI stays a thin
   dispatcher. [run] iterates the given projects; [run_one] is the
   per-project unit (also the single-project CLI path, so both paths
   share the display). The default config is
   [Canary_project_run.batch_config] ([Heavy] → Thin, bypassing the
   source-built Dev chains; [Light] → Full); [force_thin] overrides
   thin everywhere (the CLI's [--thin]).

   The config is [Canary_project_run.run_config] — the runner SETS
   [config.policy] (the run_policy variant); consumers match the
   variant (the batch's per-project display is exhaustive over it). *)

let verdict_lines (pr : Canary_project_run.project_run)
    (r : Canary_runner.scenario_run_result) : string =
  let safe =
    String.map
      (function ':' | '#' | '+' -> '-' | c -> c)
      (Filename.basename
         (Canary_project_run.scenario_dir_of ~pr_name:pr.Canary_project_run.pr_name
            r.Canary_runner.r_result_assignment))
  in
  let xfail_strs =
    List.map
      (fun (tag, ids) ->
        tag
        ^ match ids with [] -> "" | _ -> "[" ^ String.concat "," ids ^ "]")
      r.Canary_runner.r_result_xfails
  in
  Printf.sprintf "  [%-44s] %-6s %s%s%s" safe
    r.Canary_runner.r_result_verdict
    (if r.Canary_runner.r_result_is_bad then "(bad)" else "(good)")
    (match xfail_strs with
    | [] -> ""
    | xs -> "  xfail: " ^ String.concat "," xs)
    (if
       String.equal r.Canary_runner.r_result_verdict "FAIL"
       && r.Canary_runner.r_result_culprits <> []
     then "  <- " ^ String.concat " " r.Canary_runner.r_result_culprits
     else "")

(** One project: header + run + verdicts. [?config] = the run config
    (defaults to [Canary_project_run.default_config] = Full). Returns the
    per-scenario results (callers needing the coverage summary reuse them
    — no double run). *)
let run_one ?(config = Canary_project_run.default_config)
    (pr : Canary_project_run.project_run) ~root ~failfast :
    Canary_runner.scenario_run_result list =
  Fmt.pr "@.%s — generic project run (enumerate → runner_spec → run)@."
    pr.Canary_project_run.pr_name;
  let results =
    Canary_runner.run_project_spec
      ?policy:(Canary_project_run.enumeration_policy_of config)
      pr ~root ~failfast
  in
  List.iter (fun r -> Fmt.pr "%s@." (verdict_lines pr r)) results;
  results

(** The batch: every project under the default config — [Heavy] thin,
    [Light] full; [force_thin] (the CLI's [--thin]) overrides everywhere.
    The project list is an ARGUMENT (the CLI passes the registry), so
    callers can batch any subset. *)
let run ?(force_thin = false) ~root ~failfast
    (projects : (string * Canary_project_run.project_run) list) : unit =
  List.iter
    (fun (name, pr) ->
      let config =
        if force_thin then { Canary_project_run.policy = Canary_project_run.Thin }
        else Canary_project_run.batch_config pr
      in
      Fmt.pr "[batch] %s: %s policy@." name
        (match config.Canary_project_run.policy with
        | Canary_project_run.Full -> "full"
        | Canary_project_run.Thin -> "thin (heavy tier)");
      ignore (run_one ~config pr ~root ~failfast))
    projects
