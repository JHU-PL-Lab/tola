(* ── THE batch runner (2026-08-14) ──

   Runs a list of projects under the tier-based default config — a
   callable, customizable, testable function; the CLI stays a thin
   dispatcher. [run] iterates the given projects; [run_one] is the
   per-project unit (also the single-project CLI path, so both paths
   share the display). The default config is
   [Canary_project_run.batch_policy] ([Heavy] → thin, bypassing the
   source-built Dev chains; [Light] → full); [force_thin] overrides
   thin everywhere (the CLI's [--thin]). *)

let verdict_lines (pr : Canary_project_run.project_run)
    (r : Canary_project_run.scenario_run_result) : string =
  let safe =
    String.map
      (function ':' | '#' | '+' -> '-' | c -> c)
      (Filename.basename
         (Canary_project_run.scenario_dir_of ~pr_name:pr.Canary_project_run.pr_name
            r.Canary_project_run.r_result_assignment))
  in
  let xfail_strs =
    List.map
      (fun (tag, ids) ->
        tag
        ^ match ids with [] -> "" | _ -> "[" ^ String.concat "," ids ^ "]")
      r.Canary_project_run.r_result_xfails
  in
  Printf.sprintf "  [%-44s] %-6s %s%s%s" safe
    r.Canary_project_run.r_result_verdict
    (if r.Canary_project_run.r_result_is_bad then "(bad)" else "(good)")
    (match xfail_strs with
    | [] -> ""
    | xs -> "  xfail: " ^ String.concat "," xs)
    (if
       String.equal r.Canary_project_run.r_result_verdict "FAIL"
       && r.Canary_project_run.r_result_culprits <> []
     then "  <- " ^ String.concat " " r.Canary_project_run.r_result_culprits
     else "")

(** One project: header + run + verdicts. [?policy] = the enumeration
    policy (None = the full default). Returns the per-scenario results
    (callers needing the coverage summary reuse them — no double run). *)
let run_one ?policy (pr : Canary_project_run.project_run) ~root ~failfast :
    Canary_project_run.scenario_run_result list =
  Fmt.pr "@.%s — generic project run (enumerate → runner_spec → run)@."
    pr.Canary_project_run.pr_name;
  let results =
    Canary_project_run.run_project_spec ?policy pr ~root ~failfast
  in
  List.iter (fun r -> Fmt.pr "%s@." (verdict_lines pr r)) results;
  results

(** The batch: every project under the default config — [Heavy] thin,
    [Light] full; [?force_thin] (the CLI's [--thin]) overrides everywhere.
    The project list is an ARGUMENT (the CLI passes the registry), so
    callers can batch any subset. *)
let run ?(force_thin = false) ~root ~failfast
    (projects : (string * Canary_project_run.project_run) list) : unit =
  List.iter
    (fun (name, pr) ->
      let policy =
        if force_thin then Some (Canary_project_run.thin_policy ())
        else Canary_project_run.batch_policy pr
      in
      Fmt.pr "[batch] %s: %s policy@." name
        (match policy with
        | Some _ -> "thin (heavy tier)"
        | None -> "full");
      ignore (run_one ?policy pr ~root ~failfast))
    projects
