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
    let dev_tag =
      Canary_store.version_cache_tag distro Canary_project_z3.z3_source_dev
    in
    let steps = Canary_project_z3.action_steps ~quick ~root ~project:[%string "z3/%{dev_tag}"] distro in
    run_with_info ~failfast ~root ~project:[%string "z3/%{dev_tag}"] steps
      (Canary_project_z3.run_info distro steps);
    let steps_stable =
      Canary_project_z3.action_steps ~source:Canary_project_z3.z3_source_stable
        ~root ~project:"z3/stable" distro
    in
    run_with_info ~failfast ~root ~project:"z3/stable" steps_stable
      (Canary_project_z3.run_info ~source:Canary_project_z3.z3_source_stable
         distro steps_stable)
  in
  let run_sqlite ~root ~failfast =
    let steps = Canary_project_sqlite.action_steps ~root ~project:"sqlite" in
    run_with_info ~failfast ~root ~project:"sqlite" steps
      (Canary_project_sqlite.run_info steps)
  in
  let run_llvm ~root ~failfast distro =
    let dev_tag =
      Canary_store.version_cache_tag distro Canary_project_llvm.llvm_source_dev
    in
    let steps = Canary_project_llvm.action_steps ~root ~project:[%string "llvm/%{dev_tag}"] distro in
    run_with_info ~failfast ~root ~project:[%string "llvm/%{dev_tag}"] steps
      (Canary_project_llvm.run_info steps);
    let steps_19 =
      Canary_project_llvm.action_steps ~source:Canary_project_llvm.llvm_source_stable
        ~root ~project:"llvm/19" distro
    in
    run_with_info ~failfast ~root ~project:"llvm/19" steps_19
      (Canary_project_llvm.run_info
         ~source_repo:Canary_project_llvm.llvm_source_stable steps_19)
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

let write_workflow out name yaml =
  ignore (Stdlib.Sys.command (Fmt.str "mkdir -p %s" out));
  let path = out ^ "/" ^ name in
  let oc = Stdlib.open_out path in
  Stdlib.output_string oc yaml;
  Stdlib.close_out oc;
  Fmt.pr "Wrote %s@." path

let ci_cmd =
  let out =
    Arg.(value & opt string ".github/workflows" & info [ "out"; "o" ]
           ~docv:"DIR" ~doc:"Output directory for generated YAML (default: .github/workflows)")
  in
  let run out () =
    let distro = detect_distro () in
    Canary_project_z3.render_opam_in ~tola_root:".";
    write_workflow out "canary_ci.yml" (Canary_run.render_ci ~root:"_out" distro)
  in
  Cmd.v (Cmd.info "ci" ~doc:"Generate GH Actions workflow YAML")
    Term.(const run $ out $ const ())

let debug_ci_cmd =
  let out =
    Arg.(value & opt string ".github/workflows" & info [ "out"; "o" ]
           ~docv:"DIR" ~doc:"Output directory for generated YAML (default: .github/workflows)")
  in
  let run out () =
    let distro = detect_distro () in
    write_workflow out "debug.yml" (Canary_run.render_debug_ci ~root:"_out" distro)
  in
  Cmd.v (Cmd.info "debug-ci" ~doc:"Generate debug workflow YAML (workflow_dispatch, SQLite only)")
    Term.(const run $ out $ const ())

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
    ci_cmd;
    debug_ci_cmd;
    pm_test_cmd;
    run_cmd;
  ] in
  Stdlib.exit (Cmd.eval cmd)
