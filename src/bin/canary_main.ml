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
  let cache_path_arg =
    Arg.(value & opt (some string) None
           & info [ "cache" ] ~docv:"FILE"
               ~doc:"Path to step cache JSON for global skip (e.g. doc/canary/step_cache.json)")
  in
  let run_with_info ~failfast ~cache_path ~root ~project steps run_info =
    Canary_action.run_project ~failfast ~run_info ?cache_path ~root ~project steps
  in
  let source_run_info ~project distro (repo : Canary_artifact_source.source_repo) steps =
    let (Canary_artifact_source.Git_remote url) = repo.remote in
    Canary_action.mk_run_info ~project ~version:repo.version ~ref_:repo.ref_
      ~source:(Canary_artifact_source.source_desc distro repo)
      ~extra:[
        ("official", if repo.official then "true" else "false");
        ("remote", url);
      ]
      steps
  in
  let run_z3 ~root ~quick ~failfast ~cache_path distro =
    let dev_tag =
      Canary_artifact_source.version_cache_tag distro Canary_project_z3.z3_source_dev
    in
    let src = Canary_project_z3.z3_source_dev in
    let spec = Canary_project_z3.mk_script_spec ~source:src distro in
    let spec = if quick then Canary_action.no_source spec else spec in
    let steps = Canary_action.derive_steps ~root ~project:[%string "z3/%{dev_tag}"]
        ~langs:Canary_artifact_api.[ OCaml; Python ] spec in
    let src_stable = Canary_project_z3.z3_source_stable in
    let spec_stable = Canary_project_z3.mk_script_spec ~source:src_stable distro in
    let steps_stable = Canary_action.derive_steps ~root ~project:"z3/stable"
        ~langs:Canary_artifact_api.[ OCaml; Python ] spec_stable in
    Canary_action.run_project_multi ~failfast ?cache_path ~root ~project_name:"z3"
      ~variants:[
        (dev_tag, steps, Some (source_run_info ~project:"z3" distro src steps));
        ("stable", steps_stable, Some (source_run_info ~project:"z3" distro src_stable steps_stable));
      ] ()
  in
  let prebuilt_run_info ~project ~version ~extra steps =
    Canary_action.mk_run_info ~project ~version ~ref_:"" ~source:"prebuilt" ~extra steps
  in
  let run_sqlite ~root ~failfast ~cache_path =
    let steps = Canary_action.derive_steps ~root ~project:"sqlite"
        ~langs:Canary_artifact_api.[ OCaml; Python ]
        Canary_project_sqlite.script_spec in
    run_with_info ~failfast ~cache_path ~root ~project:"sqlite" steps
      (prebuilt_run_info ~project:"sqlite" ~version:"system" ~extra:[] steps)
  in
  let run_zarith ~root ~failfast ~cache_path =
    let steps = Canary_action.derive_steps ~root ~project:"zarith"
        Canary_project_zarith.script_spec in
    run_with_info ~failfast ~cache_path ~root ~project:"zarith" steps
      (prebuilt_run_info ~project:"zarith" ~version:"system" ~extra:[] steps)
  in
  let run_ssl ~root ~failfast ~cache_path =
    let steps = Canary_action.derive_steps ~root ~project:"ssl"
        Canary_project_ssl.script_spec in
    run_with_info ~failfast ~cache_path ~root ~project:"ssl" steps
      (prebuilt_run_info ~project:"ssl" ~version:"system" ~extra:[] steps)
  in
  let run_llvm ~root ~failfast ~cache_path distro =
    let dev_tag =
      Canary_artifact_source.version_cache_tag distro Canary_project_llvm.llvm_source_dev
    in
    let spec = Canary_project_llvm.mk_script_spec ~source:Canary_project_llvm.llvm_source_dev distro in
    let steps = Canary_action.derive_steps ~root ~project:[%string "llvm/%{dev_tag}"]
        ~langs:Canary_artifact_api.[ OCaml; Python ] spec in
    let pb = Canary_project_llvm.prebuilt in
    let ver = Option.value pb.system_package.version_tag ~default:"system" in
    let dev_run_info =
      prebuilt_run_info ~project:"llvm" ~version:ver
        ~extra:[("system_package", pb.system_package_linux); ("opam_package", pb.opam_package)]
        steps
    in
    let src_19 = Canary_project_llvm.llvm_source_stable in
    let spec_19 = Canary_project_llvm.mk_script_spec ~source:src_19 distro in
    let steps_19 = Canary_action.derive_steps ~root ~project:"llvm/19"
        ~langs:Canary_artifact_api.[ OCaml; Python ] spec_19 in
    Canary_action.run_project_multi ~failfast ?cache_path ~root ~project_name:"llvm"
      ~variants:[
        (dev_tag, steps, Some dev_run_info);
        ("19", steps_19, Some (source_run_info ~project:"llvm" distro src_19 steps_19));
      ] ()
  in
  let run project quick failfast cache_path () =
    let root = "_out" in
    let distro = detect_distro () in
    match project with
    | Some "sqlite" -> run_sqlite ~root ~failfast ~cache_path
    | Some "zarith" -> run_zarith ~root ~failfast ~cache_path
    | Some "ssl" -> run_ssl ~root ~failfast ~cache_path
    | Some "z3" -> run_z3 ~root ~quick ~failfast ~cache_path distro
    | Some "llvm" -> run_llvm ~root ~failfast ~cache_path distro
    | None ->
        run_sqlite ~root ~failfast ~cache_path;
        run_zarith ~root ~failfast ~cache_path;
        run_ssl ~root ~failfast ~cache_path;
        run_z3 ~root ~quick ~failfast ~cache_path distro;
        run_llvm ~root ~failfast ~cache_path distro
    | Some p ->
        Fmt.pr "Unknown project: %s (available: sqlite, zarith, ssl, z3, llvm)@." p
  in
  Cmd.v (Cmd.info "action" ~doc:"Run the action graph")
    Term.(const run $ project $ quick $ failfast $ cache_path_arg $ const ())

let write_workflow out name yaml =
  ignore (Stdlib.Sys.command (Fmt.str "mkdir -p %s" out));
  let path = out ^ "/" ^ name in
  let oc = Stdlib.open_out path in
  Stdlib.output_string oc yaml;
  Stdlib.close_out oc;
  Fmt.pr "Wrote %s@." path

(* Read a command's stdout into a string. Returns None on error. *)
let read_cmd cmd =
  let ic = Unix.open_process_in cmd in
  let buf = Buffer.create 256 in
  (try
     while true do
       Buffer.add_channel buf ic 1
     done
   with End_of_file -> ());
  match Unix.close_process_in ic with
  | Unix.WEXITED 0 -> Some (Buffer.contents buf)
  | _ -> None

(* Map GH job names used in canary_ci.yml to stable cache_project ids. *)
let job_name_to_cache_project = [
  ("LLVM 19 — fetch + probe",           "llvm-19");
  ("Z3 dev — build from source + probe","z3-dev");
  ("SQLite — fetch + probe",            "sqlite");
]

(* Sync step results from a GH Actions run into the local cache file.
   Algorithm:
   1. Find run ID: use --run-id if given, else latest successful canary_ci.yml run.
   2. gh run view <id> --json jobs  → parse jobs/steps.
   3. For each job step with conclusion=success, record cache entry.
   4. Save updated cache. *)
let cache_sync_cmd =
  let cache_path =
    Arg.(value & opt string "doc/canary/step_cache.json"
           & info [ "cache" ] ~docv:"FILE"
               ~doc:"Path to step cache JSON (default: doc/canary/step_cache.json)")
  in
  let run_id_arg =
    Arg.(value & opt (some int) None
           & info [ "run-id" ] ~docv:"ID"
               ~doc:"GH Actions run database ID (default: latest successful canary_ci.yml run)")
  in
  let run cache_path run_id_opt () =
    (* Step 1: resolve run ID *)
    let run_id = match run_id_opt with
      | Some id -> id
      | None ->
          let cmd = {|gh run list --workflow=canary_ci.yml --json databaseId,conclusion --limit 20|} in
          (match read_cmd cmd with
           | None ->
               Fmt.epr "cache-sync: gh run list failed (is gh installed and authenticated?)@.";
               Stdlib.exit 1
           | Some json_str ->
               let json = Yojson.Basic.from_string json_str in
               let runs = match json with `List xs -> xs | _ -> [] in
               let success_run = List.find_opt (fun r ->
                   match r with
                   | `Assoc fields ->
                       (match List.assoc_opt "conclusion" fields with
                        | Some (`String "success") -> true
                        | _ -> false)
                   | _ -> false) runs
               in
               match success_run with
               | None ->
                   Fmt.epr "cache-sync: no successful canary_ci.yml run found@.";
                   Stdlib.exit 1
               | Some (`Assoc fields) ->
                   (match List.assoc_opt "databaseId" fields with
                    | Some (`Int id) -> id
                    | _ ->
                        Fmt.epr "cache-sync: could not parse databaseId@.";
                        Stdlib.exit 1)
               | Some _ -> Stdlib.exit 1)
    in
    Fmt.pr "cache-sync: reading run %d@." run_id;
    (* Step 2: fetch jobs for this run *)
    let jobs_json = match read_cmd (Fmt.str "gh run view %d --json jobs" run_id) with
      | None ->
          Fmt.epr "cache-sync: gh run view failed@.";
          Stdlib.exit 1
      | Some s -> Yojson.Basic.from_string s
    in
    (* Step 3: parse and record *)
    let cache = Canary_step_cache.load ~path:cache_path in
    let today = let t = Unix.localtime (Unix.gettimeofday ()) in
                Fmt.str "%04d-%02d-%02d" (t.tm_year+1900) (t.tm_mon+1) t.tm_mday in
    let jobs = match jobs_json with
      | `Assoc fields -> (match List.assoc_opt "jobs" fields with
          | Some (`List xs) -> xs | _ -> [])
      | _ -> []
    in
    let recorded = ref 0 in
    List.iter (fun job ->
        match job with
        | `Assoc fields ->
            let job_name = (match List.assoc_opt "name" fields with
                | Some (`String s) -> s | _ -> "") in
            let cache_project = List.assoc_opt job_name job_name_to_cache_project in
            (match cache_project with
             | None ->
                 Fmt.pr "  skipping unknown job: %s@." job_name
             | Some cp ->
                 let steps = match List.assoc_opt "steps" fields with
                   | Some (`List xs) -> xs | _ -> [] in
                 List.iter (fun step ->
                     match step with
                     | `Assoc sf ->
                         let name = (match List.assoc_opt "name" sf with
                             | Some (`String s) -> s | _ -> "") in
                         let conclusion = (match List.assoc_opt "conclusion" sf with
                             | Some (`String s) -> s | _ -> "") in
                         (* Only record base step names (skip "(verify)" suffix steps) *)
                         if not (String.length name > 9 &&
                                 String.sub name (String.length name - 9) 9 = "(verify)") then (
                           let key = cp ^ ":" ^ name in
                           let entry = Canary_step_cache.{ status = conclusion; run_id; at = today } in
                           Canary_step_cache.record cache ~key entry;
                           Fmt.pr "  %s  →  %s@." key conclusion;
                           incr recorded)
                     | _ -> ()) steps)
        | _ -> ()) jobs;
    Canary_step_cache.save ~path:cache_path cache;
    Fmt.pr "cache-sync: recorded %d entries → %s@." !recorded cache_path
  in
  Cmd.v (Cmd.info "cache-sync"
           ~doc:"Sync step results from latest GH CI run into the local cache file")
    Term.(const run $ cache_path $ run_id_arg $ const ())

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

let artifact_test_cmd =
  Cmd.v (Cmd.info "artifact-test" ~doc:"Test artifact primitives (native/ocaml/python)")
    (term_of (fun () ->
       let ok = Canary_artifact_test.run_tests () in
       if not ok then Stdlib.exit 1))

let artifact_summary_cmd =
  let kind =
    Arg.(required & opt (some string) None & info [ "kind" ] ~docv:"KIND"
           ~doc:"Artifact kind: native | ocaml | opam")
  in
  let path =
    Arg.(required & opt (some string) None & info [ "path" ] ~docv:"PATH"
           ~doc:"For native: path to .so/.dylib. For ocaml: path to .cmxa/.cma. For opam: package name.")
  in
  let prefixes =
    Arg.(value & opt (list string) [] & info [ "prefixes" ] ~docv:"CSV"
           ~doc:"Comma-separated symbol prefixes (native only)")
  in
  let watchlist =
    Arg.(value & opt (list string) [] & info [ "watchlist" ] ~docv:"CSV"
           ~doc:"Comma-separated watchlist of names to check presence/absence")
  in
  let out_dir =
    Arg.(value & opt string "_out/canary/test/artifact-summary"
           & info [ "out" ] ~docv:"DIR"
               ~doc:"Output directory for summary.json")
  in
  let run kind path prefixes watchlist out_dir () =
    ignore (Stdlib.Sys.command (Fmt.str "mkdir -p %s" out_dir));
    let cmd = match kind with
      | "native" ->
          Canary_artifact_native.summary_cmd ~lib:path ~prefixes ~watchlist ~output_dir:out_dir ~variant_key:"" ()
      | "ocaml" ->
          Canary_artifact_lang.summary_cmd ~archive:path ~watchlist ~output_dir:out_dir ~variant_key:"" ()
      | "opam" ->
          Canary_artifact_lang.summary_opam_pkg_cmd ~pkg:path ~watchlist ~output_dir:out_dir ~variant_key:"" ()
      | "python" ->
          Canary_artifact_lang.python_summary_cmd ~pkg:path ~watchlist ~output_dir:out_dir ~variant_key:"" ()
      | k ->
          Fmt.epr "Unknown kind: %s (expected: native | ocaml | opam | python)@." k;
          Stdlib.exit 2
    in
    let rc = Stdlib.Sys.command cmd in
    if rc <> 0 then (
      Fmt.epr "artifact-summary: command failed (rc=%d)@." rc;
      Stdlib.exit 1);
    Fmt.pr "Wrote %s/summary.json@." out_dir
  in
  Cmd.v (Cmd.info "artifact-summary"
           ~doc:"Dump compact artifact interface summary to summary.json")
    Term.(const run $ kind $ path $ prefixes $ watchlist $ out_dir $ const ())

let compat_cmd =
  (* Two modes:
     - Positional <project> [<variant>] uses cached summaries under
       _out/canary/projects/<project>/<variant>/.
     - Explicit --stub PATH --lib PATH uses raw summary.json paths. *)
  let project =
    Arg.(value & pos 0 (some string) None & info [] ~docv:"PROJECT"
           ~doc:"Project name (e.g. llvm, z3) — uses cached summaries.")
  in
  let variant =
    Arg.(value & pos 1 string "dev" & info [] ~docv:"VARIANT"
           ~doc:"Variant name (e.g. 19, dev, stable). \"dev\" matches \
                 the most recent dev_* dir.")
  in
  let stub =
    Arg.(value & opt (some string) None & info [ "stub" ] ~docv:"PATH"
           ~doc:"Path to a c_stub summary.json (overrides project/variant lookup).")
  in
  let lib =
    Arg.(value & opt (some string) None & info [ "lib" ] ~docv:"PATH"
           ~doc:"Path to a native summary.json with --emit-symbols.")
  in
  let run project variant stub_path lib_path () =
    let rc = match stub_path, lib_path with
      | Some s, Some l -> Canary_compat.run ~stub_path:s ~lib_path:l
      | _ ->
          (match project with
           | None ->
               Fmt.epr "compat: pass either <project> [<variant>] or both \
                        --stub and --lib@.";
               2
           | Some p ->
               let root = Stdlib.Sys.getcwd () in
               Canary_compat.run_for_project ~root ~project:p ~variant)
    in
    Stdlib.exit rc
  in
  Cmd.v (Cmd.info "compat"
           ~doc:"Static C-symbol cross-check: predict whether a binding's required \
                 symbols are all provided by a native lib. See api_interface.md §13.")
    Term.(const run $ project $ variant $ stub $ lib $ const ())

let verify_cmd =
  let project =
    Arg.(required & pos 0 (some string) None & info [] ~docv:"PROJECT"
           ~doc:"Project name (e.g. llvm, z3)")
  in
  let variant =
    Arg.(value & pos 1 string "dev" & info [] ~docv:"VARIANT"
           ~doc:"Variant (e.g. 19, dev, stable). \"dev\" matches dev_*.")
  in
  let run project variant () =
    let root = Stdlib.Sys.getcwd () in
    Stdlib.exit (Canary_compat.verify_for_project ~root ~project ~variant)
  in
  Cmd.v (Cmd.info "verify"
           ~doc:"Cross-reference cached compat predictions against probe.log \
                 outcomes. Reports per-layer \
                 prediction-vs-observation alignment.")
    Term.(const run $ project $ variant $ const ())

let index_cmd =
  let run () =
    let projects_root = "_out/canary/projects" in
    let entries = Canary_action.scan_index_entries ~projects_root in
    let now =
      let t = Unix.gettimeofday () in
      let tm = Unix.localtime t in
      Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d"
        (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday
        tm.tm_hour tm.tm_min tm.tm_sec
    in
    let html =
      Canary_backend_html.render_index ~entries ~generated_at:now
    in
    let path = projects_root ^ "/index.html" in
    let oc = Stdlib.open_out path in
    Stdlib.output_string oc html;
    Stdlib.close_out oc;
    Fmt.pr "Wrote %s (%d runs)@." path (List.length entries)
  in
  Cmd.v (Cmd.info "index"
           ~doc:"Refresh the top-level index.html listing every (project, variant) \
                 run found under _out/canary/projects/.")
    Term.(const run $ const ())

let summary_diff_cmd =
  let old_ =
    Arg.(required & opt (some string) None & info [ "old" ] ~docv:"PATH"
           ~doc:"Path to the older summary.json")
  in
  let new_ =
    Arg.(required & opt (some string) None & info [ "new" ] ~docv:"PATH"
           ~doc:"Path to the newer summary.json")
  in
  let run old_path new_path () =
    Canary_summary_diff.diff ~old_path ~new_path
  in
  Cmd.v (Cmd.info "summary-diff"
           ~doc:"Diff two artifact summary.json files (counts, modules, watchlist, versioned_req)")
    Term.(const run $ old_ $ new_ $ const ())

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
    cache_sync_cmd;
    pm_test_cmd;
    artifact_test_cmd;
    artifact_summary_cmd;
    summary_diff_cmd;
    compat_cmd;
    verify_cmd;
    index_cmd;
  ] in
  Stdlib.exit (Cmd.eval cmd)
