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
           ~doc:"Project to run: sqlite, z3, llvm (default: all)")
  in
  let quick =
    Arg.(value & flag & info [ "quick" ]
           ~doc:"Skip build-from-source actions")
  in
  let failfast =
    Arg.(value & flag & info [ "failfast"; "ff" ]
           ~doc:"Stop on first failure (useful for debugging)")
  in
  let run_with_info ~failfast ~root ~project steps run_info =
    Canary_action.run_project ~failfast ~run_info ~root ~project steps
  in
  let run_z3 ~root ~quick ~failfast distro =
    let steps = Canary_project_z3.action_steps ~quick ~root ~project:"z3" distro in
    run_with_info ~failfast ~root ~project:"z3" steps
      (Canary_project_z3.run_info distro steps)
  in
  let run_sqlite ~root ~failfast =
    let steps = Canary_project_sqlite.action_steps ~root ~project:"sqlite" in
    run_with_info ~failfast ~root ~project:"sqlite" steps
      (Canary_project_sqlite.run_info steps)
  in
  let run_llvm ~root ~failfast distro =
    let steps = Canary_project_llvm.action_steps ~root ~project:"llvm" distro in
    run_with_info ~failfast ~root ~project:"llvm" steps
      (Canary_project_llvm.run_info steps)
  in
  let run project quick failfast () =
    let root = "_out" in
    let distro = detect_distro () in
    match project with
    | Some "sqlite" -> run_sqlite ~root ~failfast
    | Some "z3" -> run_z3 ~root ~quick ~failfast distro
    | Some "llvm" -> run_llvm ~root ~failfast distro
    | None ->
        run_sqlite ~root ~failfast;
        run_z3 ~root ~quick ~failfast distro;
        run_llvm ~root ~failfast distro
    | Some p ->
        Fmt.pr "Unknown project: %s (available: sqlite, z3, llvm)@." p
  in
  Cmd.v (Cmd.info "action" ~doc:"Run the action graph")
    Term.(const run $ project $ quick $ failfast $ const ())

let pm_test_cmd =
  Cmd.v (Cmd.info "pm-test" ~doc:"Test PM primitive commands (apt/brew/opam)")
    (term_of (fun () ->
       let ok = Canary_pm_test.run_tests () in
       if not ok then Stdlib.exit 1))

(* ── Main ── *)

let () =
  let doc = "Canary compatibility testing" in
  let info = Cmd.info "canary" ~doc in
  let cmd = Cmd.group info [
    paths_cmd;
    paths_md_cmd;
    graph_cmd;
    action_cmd;
    pm_test_cmd;
    run_cmd;
  ] in
  Stdlib.exit (Cmd.eval cmd)
