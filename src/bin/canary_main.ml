open Cmdliner

let detect_distro () = Canary_basic.detect_distro ()

let term_of f = Term.(const f $ const ())

(* ── Subcommands ── *)

let paths_cmd =
  Cmd.v (Cmd.info "paths" ~doc:"Print action pattern table (plain text)")
    (term_of (fun () -> Canary_run.dump_job_paths ()))

let paths_md_cmd =
  Cmd.v (Cmd.info "paths-md" ~doc:"Print action pattern table (markdown)")
    (term_of (fun () -> Canary_run.dump_job_paths_md ()))

let graph_cmd =
  Cmd.v (Cmd.info "graph" ~doc:"Generate mermaid diagrams")
    (term_of (fun () -> Canary_run.dump_graph (detect_distro ())))

let run_cmd =
  Cmd.v (Cmd.info "run" ~doc:"Generate YAML and shell backends (legacy)")
    (term_of (fun () -> Canary_run.run (detect_distro ())))

let action_cmd =
  let project =
    Arg.(value & pos 0 (some string) None & info [] ~docv:"PROJECT"
           ~doc:"Project to run: sqlite, z3 (default: all)")
  in
  let quick =
    Arg.(value & flag & info [ "quick" ]
           ~doc:"Skip build-from-source actions")
  in
  let run_z3 ~root ~quick distro =
    Canary_action.run_project ~root ~project:"z3"
      (Canary_project_z3.action_steps ~quick ~root ~project:"z3" distro)
  in
  let run project quick () =
    let root = "_out" in
    let distro = detect_distro () in
    match project with
    | Some "sqlite" ->
        Canary_action.run_project ~root ~project:"sqlite"
          (Canary_project_sqlite.action_steps ~root ~project:"sqlite")
    | Some "z3" ->
        run_z3 ~root ~quick distro
    | None ->
        Canary_action.run_project ~root ~project:"sqlite"
          (Canary_project_sqlite.action_steps ~root ~project:"sqlite");
        run_z3 ~root ~quick distro
    | Some p ->
        Fmt.pr "Unknown project: %s (available: sqlite, z3)@." p
  in
  Cmd.v (Cmd.info "action" ~doc:"Run the action graph")
    Term.(const run $ project $ quick $ const ())

(* ── Main ── *)

let () =
  let doc = "Canary compatibility testing" in
  let info = Cmd.info "canary" ~doc in
  let cmd = Cmd.group info [
    paths_cmd;
    paths_md_cmd;
    graph_cmd;
    action_cmd;
    run_cmd;
  ] in
  Stdlib.exit (Cmd.eval cmd)
