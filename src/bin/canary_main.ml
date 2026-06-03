open Cmdliner

let detect_distro () = Canary_basic.detect_distro ()
let term_of f = Term.(const f $ const ())

(* ── Subcommands ── *)

let paths_cmd =
  Cmd.v
    (Cmd.info "paths" ~doc:"Print action pattern table (plain text)")
    (term_of (fun () -> Canary_run.dump_job_paths ()))

let paths_md_cmd =
  Cmd.v
    (Cmd.info "paths-md" ~doc:"Print action pattern table (markdown)")
    (term_of (fun () -> Canary_run.dump_job_paths_md ()))

let graph_cmd =
  Cmd.v
    (Cmd.info "graph" ~doc:"Generate mermaid diagrams")
    (term_of (fun () -> Canary_run.dump_graph (detect_distro ())))

let action_cmd =
  let project =
    Arg.(
      value
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT"
          ~doc:"Project to run: sqlite, z3, llvm (default: all)")
  in
  let quick =
    Arg.(value & flag & info [ "quick" ] ~doc:"Skip build-from-source actions")
  in
  let failfast =
    Arg.(
      value & flag
      & info [ "failfast"; "ff" ]
          ~doc:"Stop on first failure (useful for debugging)")
  in
  let cache_path_arg =
    Arg.(
      value
      & opt (some string) None
      & info [ "cache" ] ~docv:"FILE"
          ~doc:
            "Path to step cache JSON for global skip (e.g. \
             doc/canary/step_cache.json)")
  in
  let disable_contract_arg =
    Arg.(
      value
      & opt string ""
      & info [ "disable-contract" ] ~docv:"CSV"
          ~doc:
            "Comma-separated surface-theory contracts to skip for this \
             run, e.g. \"c4,c5\". Layered on top of each project's \
             script_spec.disabled_contracts and the registry's \
             enabled flag.")
  in
  let run_with_info ?(artifact_names = fun _ -> None) ~failfast ~cache_path
      ~root ~project steps run_info =
    Canary_run_info.run_project ~failfast ~run_info ?cache_path ~artifact_names
      ~root ~project steps
  in
  (* Apply the CLI's --disable-contract list to a project spec by
     appending it to the spec's own disabled_contracts. The runner
     reads the merged list off each action_step.disabled_contracts. *)
  let with_cli_disabled (cli_disabled : Canary_compat.contract_id list)
      (spec : Canary_step_builder.script_spec)
      : Canary_step_builder.script_spec =
    if List.is_empty cli_disabled then spec
    else { spec with
           disabled_contracts = spec.disabled_contracts @ cli_disabled }
  in
  let source_run_info ~project distro
      (repo : Canary_artifact_source.source_repo) steps =
    let (Canary_artifact_source.Git_remote url) = repo.remote in
    Canary_run_info.mk_run_info ~project ~version:repo.version ~ref_:repo.ref_
      ~source:(Canary_artifact_source.source_desc distro repo)
      ~extra:
        [
          ("official", if repo.official then "true" else "false");
          ("remote", url);
        ]
      steps
  in
  let run_z3 ~root ~quick ~failfast ~cache_path ~cli_disabled distro =
    let dev_tag =
      Canary_artifact_source.version_cache_tag distro
        Canary_project_z3.z3_source_dev
    in
    let src = Canary_project_z3.z3_source_dev in
    let spec = Canary_project_z3.mk_script_spec ~source:src distro
               |> with_cli_disabled cli_disabled in
    let spec = if quick then Canary_step_builder.no_source spec else spec in
    let steps =
      Canary_step_builder.derive_steps ~root ~project:[%string "z3/%{dev_tag}"]
        ~langs:Canary_lang.[ OCaml; Python ]
        spec
    in
    let src_stable = Canary_project_z3.z3_source_stable in
    let spec_stable =
      Canary_project_z3.mk_script_spec ~source:src_stable distro
      |> with_cli_disabled cli_disabled
    in
    let steps_stable =
      Canary_step_builder.derive_steps ~root ~project:"z3/stable"
        ~langs:Canary_lang.[ OCaml; Python ]
        spec_stable
    in
    Canary_run_info.run_project_multi ~failfast ?cache_path ~root
      ~project_name:"z3" ~artifact_names:spec.artifact_name
      ~variants:
        [
          (dev_tag, steps, Some (source_run_info ~project:"z3" distro src steps));
          ( "stable",
            steps_stable,
            Some (source_run_info ~project:"z3" distro src_stable steps_stable)
          );
        ]
      ()
  in
  let prebuilt_run_info ~project ~version ~extra steps =
    Canary_run_info.mk_run_info ~project ~version ~ref_:"" ~source:"prebuilt"
      ~extra steps
  in
  let run_sqlite ~root ~failfast ~cache_path ~cli_disabled =
    let spec = with_cli_disabled cli_disabled Canary_project_sqlite.script_spec in
    let steps =
      Canary_step_builder.derive_steps ~root ~project:"sqlite"
        ~langs:Canary_lang.[ OCaml; Python ]
        spec
    in
    run_with_info ~artifact_names:spec.artifact_name
      ~failfast ~cache_path ~root ~project:"sqlite"
      steps
      (prebuilt_run_info ~project:"sqlite" ~version:"system" ~extra:[] steps)
  in
  (* Tiny is multi-variant. Each variant is a named script_spec in
     canary_project_tiny.ml whose expectations describe which surface-
     theory contracts canary expects to fire at which stages. The
     harness↔canary mapping (e.g. "lib_broken matches scenario e1") is
     a documentation concern, not encoded here.

     - variant_filter = None: run all known variants via
       Canary_run_info.run_project_multi.
     - variant_filter = Some "<name>": run only the named variant.
     The CLI dispatches "tiny" → None and "tiny/<name>" → Some name. *)
  let run_tiny ~root ~failfast ~cache_path ~cli_disabled ~variant_filter =
    let mk variant_id spec_raw =
      let spec = with_cli_disabled cli_disabled spec_raw in
      let project =
        if variant_id = "" then "tiny"
        else "tiny/" ^ variant_id
      in
      let steps =
        Canary_step_builder.derive_steps ~root ~project
          ~langs:Canary_lang.[ OCaml; Python ]
          spec
      in
      let info = prebuilt_run_info ~project:"tiny" ~version:"in_tree"
        ~extra:[] steps in
      (variant_id, steps, Some info)
    in
    (* Phase 14b': each variant configures per-artifact-kind stores.
       Today every variant's stores come from a single materialized
       workspace via [stores_of_workspace] (single-store special case
       of the per-kind model). Cross-product variants — e.g. baseline
       source + perturbed lib — would construct stores with paths
       from different workspaces; deferred to Phase 14c. *)
    let ws_stores ?lib_filename scenario =
      Canary_project_tiny.stores_of_workspace
        ?lib_filename
        ~workspace_root:(Canary_project_tiny.cache_workspace_of ~scenario) () in
    (* Cross-product demo: pluck individual artifact-kind paths from
       different scenario workspaces. [hybrid_lib_broken] = baseline
       source/python + perturbed lib (from symbol_missing). The c1
       expectation fires the same way as [lib_broken], but the store
       wiring proves the per-kind model actually mixes — not just the
       API surface. *)
    let symbol_missing_ws =
      Canary_project_tiny.cache_workspace_of ~scenario:"symbol_missing" in
    let baseline_stores = ws_stores "baseline" in
    let hybrid_lib_broken_stores : Canary_project_tiny.tiny_stores = {
      source = baseline_stores.source;
      lib_dir = [%string "%{symbol_missing_ws}/c/build"];
      lib_filename = baseline_stores.lib_filename;
      python_cext_root = baseline_stores.python_cext_root;
    } in
    let all_variants = [
      mk ""
        (Canary_project_tiny.make_base_script_spec
           ~stores:(ws_stores "baseline") ());
      mk "lib_broken"
        (Canary_project_tiny.make_lib_broken_script_spec
           ~stores:(ws_stores "symbol_missing") ());
      mk "binding_mli_broken"
        (Canary_project_tiny.make_binding_mli_broken_script_spec
           ~stores:(ws_stores "api_complete"));
      mk "binding_python_attrs_broken"
        (Canary_project_tiny.make_binding_python_attrs_broken_script_spec
           ~stores:(ws_stores "api_complete_python"));
      mk "hybrid_lib_broken"
        (Canary_project_tiny.make_lib_broken_script_spec
           ~stores:hybrid_lib_broken_stores ());
      mk "lib_soname_bumped"
        (Canary_project_tiny.make_lib_soname_bumped_script_spec
           ~stores:(ws_stores ~lib_filename:"libtiny.so.2" "abi_soname_bump"));
      mk "lib_behavior_broken"
        (Canary_project_tiny.make_lib_behavior_broken_script_spec
           ~stores:(ws_stores "behavior_silent"));
      (* binding_overdeclares_stubs: c1 cmp_symbol from the orphan
         direction. The cstub references tiny_extra the lib never had;
         only OCaml is perturbed, Python cext is untouched. Maps to
         harness scenario e8 symbol_orphan. *)
      mk "binding_overdeclares_stubs"
        (Canary_project_tiny.make_binding_overdeclares_stubs_script_spec
           ~stores:(ws_stores "symbol_orphan"));
      (* app_helper_lib_broken: c1 cmp_symbol fires through the
         tiny_helper chain (app_helper.exe → Tiny_helper.sum_doubled →
         Tiny.sum → libtiny.sym tiny_sum, which is missing under
         symbol_missing). Same store + expectation as lib_broken; only
         the OCaml probe exe differs. Validates the model propagates
         through an extra binding layer (Phase 15, 2026-06-03). *)
      mk "app_helper_lib_broken"
        (Canary_project_tiny.make_lib_broken_script_spec
           ~stores:(ws_stores "symbol_missing")
           ~probe_exe:"ocaml/examples/app_helper.exe" ());
      (* lib_symbol_version_broken: c5 cmp_sym_version fires when the
         lib's exported version tag (TINY_2.0 post-bump) doesn't match
         the cached cext's required tag (TINY_1.0). Maps to harness
         scenario e9 symbol_version_floor. *)
      mk "lib_symbol_version_broken"
        (Canary_project_tiny.make_lib_symbol_version_broken_script_spec
           ~stores:(ws_stores "symbol_version_floor"));
      (* binding_type_broken: c6 cmp_type fires when the perturbed
         header declares a different arity than the binding's stub
         expects. Build (Binding OCaml) fails at C compile; the c6
         predict compares scan_sources/inspect_typed_header.json
         (3-arg) against scan_sources/inspect_typed_binding_stub_ocaml.json
         (2-arg) and returns "tiny_sum" as the predicted substring.
         Maps to harness scenario header_arity_bump. *)
      mk "binding_type_broken"
        (Canary_project_tiny.make_binding_type_broken_script_spec
           ~stores:(ws_stores "header_arity_bump"));
      (* binding_repack_broken: c7 api_sound_repack — refutes the
         binding's repack of its stub layer via probe-assertion
         failure. Same Expect_failure shape as lib_behavior_broken,
         but a different Contract (binding-layer bug vs native-layer
         bug). Maps to harness scenario api_repack (e5: Tiny.diff
         silently reverses args before calling Tiny_raw.diff). *)
      mk "binding_repack_broken"
        (Canary_project_tiny.make_binding_repack_broken_script_spec
           ~stores:(ws_stores "api_repack"));
      (* binding_python_repack_broken: Python parallel — same c7
         attribution, e10 api_repack_python perturbs
         python_cext/tiny_cext/__init__.py's diff. Each binding is
         independent; OCaml unaffected. *)
      mk "binding_python_repack_broken"
        (Canary_project_tiny.make_binding_python_repack_broken_script_spec
           ~stores:(ws_stores "api_repack_python"));
    ] in
    let selected = match variant_filter with
      | None -> all_variants
      | Some name ->
          List.filter (fun (vid, _, _) -> vid = name) all_variants
    in
    match selected with
    | [] ->
        Fmt.epr "Unknown tiny variant: %s (available: baseline (no suffix), lib_broken)@."
          (match variant_filter with Some s -> s | None -> "")
    | variants ->
        Canary_run_info.run_project_multi ~failfast ?cache_path ~root
          ~project_name:"tiny"
          ~artifact_names:Canary_project_tiny.base_script_spec.artifact_name
          ~variants ()
  in
  let run_zarith ~root ~failfast ~cache_path ~cli_disabled =
    let spec = with_cli_disabled cli_disabled Canary_project_zarith.script_spec in
    let steps =
      Canary_step_builder.derive_steps ~root ~project:"zarith" spec
    in
    run_with_info ~failfast ~cache_path ~root ~project:"zarith" steps
      (prebuilt_run_info ~project:"zarith" ~version:"system" ~extra:[] steps)
  in
  let run_ssl ~root ~failfast ~cache_path ~cli_disabled =
    let spec = with_cli_disabled cli_disabled Canary_project_ssl.script_spec in
    let steps =
      Canary_step_builder.derive_steps ~root ~project:"ssl" spec
    in
    run_with_info ~failfast ~cache_path ~root ~project:"ssl" steps
      (prebuilt_run_info ~project:"ssl" ~version:"system" ~extra:[] steps)
  in
  let run_llvm ~root ~failfast ~cache_path ~cli_disabled distro =
    let dev_tag =
      Canary_artifact_source.version_cache_tag distro
        Canary_project_llvm.llvm_source_dev
    in
    let spec =
      Canary_project_llvm.mk_script_spec
        ~source:Canary_project_llvm.llvm_source_dev distro
      |> with_cli_disabled cli_disabled
    in
    let steps =
      Canary_step_builder.derive_steps ~root ~project:[%string "llvm/%{dev_tag}"]
        ~langs:Canary_lang.[ OCaml; Python ]
        spec
    in
    let pb = Canary_project_llvm.prebuilt in
    let ver = Option.value pb.system_package.version_tag ~default:"system" in
    let dev_run_info =
      prebuilt_run_info ~project:"llvm" ~version:ver
        ~extra:
          [
            ("system_package", pb.system_package_linux);
            ("opam_package", pb.opam_package);
          ]
        steps
    in
    let src_19 = Canary_project_llvm.llvm_source_stable in
    let spec_19 = Canary_project_llvm.mk_script_spec ~source:src_19 distro
                  |> with_cli_disabled cli_disabled in
    let steps_19 =
      Canary_step_builder.derive_steps ~root ~project:"llvm/19"
        ~langs:Canary_lang.[ OCaml; Python ]
        spec_19
    in
    Canary_run_info.run_project_multi ~failfast ?cache_path ~root
      ~project_name:"llvm" ~artifact_names:spec.artifact_name
      ~variants:
        [
          (dev_tag, steps, Some dev_run_info);
          ( "19",
            steps_19,
            Some (source_run_info ~project:"llvm" distro src_19 steps_19) );
        ]
      ()
  in
  let run project quick failfast cache_path disable_contract_csv () =
    let root = "_out" in
    let distro = detect_distro () in
    let cli_disabled =
      Canary_compat.contract_ids_of_csv disable_contract_csv
    in
    (if cli_disabled <> [] then
       Fmt.pr "[disable-contract] skipping: %s@."
         (String.concat ", "
            (List.map Canary_compat.string_of_contract_id cli_disabled)));
    match project with
    | Some "sqlite" -> run_sqlite ~root ~failfast ~cache_path ~cli_disabled
    | Some "zarith" -> run_zarith ~root ~failfast ~cache_path ~cli_disabled
    | Some "ssl" -> run_ssl ~root ~failfast ~cache_path ~cli_disabled
    | Some "z3" -> run_z3 ~root ~quick ~failfast ~cache_path ~cli_disabled distro
    | Some "llvm" -> run_llvm ~root ~failfast ~cache_path ~cli_disabled distro
    | Some "tiny" ->
        run_tiny ~root ~failfast ~cache_path ~cli_disabled
          ~variant_filter:None
    | Some p when (String.length p > 5)
                  && (String.sub p 0 5 = "tiny/") ->
        let variant = String.sub p 5 (String.length p - 5) in
        run_tiny ~root ~failfast ~cache_path ~cli_disabled
          ~variant_filter:(Some variant)
    | None ->
        run_sqlite ~root ~failfast ~cache_path ~cli_disabled;
        run_zarith ~root ~failfast ~cache_path ~cli_disabled;
        run_ssl ~root ~failfast ~cache_path ~cli_disabled;
        run_z3 ~root ~quick ~failfast ~cache_path ~cli_disabled distro;
        run_llvm ~root ~failfast ~cache_path ~cli_disabled distro
    | Some p ->
        Fmt.pr
          "Unknown project: %s (available: sqlite, zarith, ssl, z3, llvm, tiny, tiny/<variant>)@." p
  in
  Cmd.v
    (Cmd.info "action" ~doc:"Run the action graph")
    Term.(const run $ project $ quick $ failfast $ cache_path_arg
          $ disable_contract_arg $ const ())

let view_cmd =
  let project =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT" ~doc:"Project to regenerate: sqlite, z3, llvm")
  in
  let run project () =
    let root = "_out" in
    Canary_run_info.view_project ~root ~project ()
  in
  Cmd.v
    (Cmd.info "view"
       ~doc:"Regenerate diagrams and HTML from saved run_state.json")
    Term.(const run $ project $ const ())

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
let job_name_to_cache_project =
  [
    ("LLVM 19 — fetch + probe", "llvm-19");
    ("Z3 dev — build from source + probe", "z3-dev");
    ("SQLite — fetch + probe", "sqlite");
  ]

(* Sync step results from a GH Actions run into the local cache file.
   Algorithm:
   1. Find run ID: use --run-id if given, else latest successful canary_ci.yml run.
   2. gh run view <id> --json jobs  → parse jobs/steps.
   3. For each job step with conclusion=success, record cache entry.
   4. Save updated cache. *)
let cache_sync_cmd =
  let cache_path =
    Arg.(
      value
      & opt string "doc/canary/step_cache.json"
      & info [ "cache" ] ~docv:"FILE"
          ~doc:"Path to step cache JSON (default: doc/canary/step_cache.json)")
  in
  let run_id_arg =
    Arg.(
      value
      & opt (some int) None
      & info [ "run-id" ] ~docv:"ID"
          ~doc:
            "GH Actions run database ID (default: latest successful \
             canary_ci.yml run)")
  in
  let run cache_path run_id_opt () =
    (* Step 1: resolve run ID *)
    let run_id =
      match run_id_opt with
      | Some id -> id
      | None -> (
          let cmd =
            {|gh run list --workflow=canary_ci.yml --json databaseId,conclusion --limit 20|}
          in
          match read_cmd cmd with
          | None ->
              Fmt.epr
                "cache-sync: gh run list failed (is gh installed and \
                 authenticated?)@.";
              Stdlib.exit 1
          | Some json_str -> (
              let json = Yojson.Basic.from_string json_str in
              let runs = match json with `List xs -> xs | _ -> [] in
              let success_run =
                List.find_opt
                  (fun r ->
                    match r with
                    | `Assoc fields -> (
                        match List.assoc_opt "conclusion" fields with
                        | Some (`String "success") -> true
                        | _ -> false)
                    | _ -> false)
                  runs
              in
              match success_run with
              | None ->
                  Fmt.epr "cache-sync: no successful canary_ci.yml run found@.";
                  Stdlib.exit 1
              | Some (`Assoc fields) -> (
                  match List.assoc_opt "databaseId" fields with
                  | Some (`Int id) -> id
                  | _ ->
                      Fmt.epr "cache-sync: could not parse databaseId@.";
                      Stdlib.exit 1)
              | Some _ -> Stdlib.exit 1))
    in
    Fmt.pr "cache-sync: reading run %d@." run_id;
    (* Step 2: fetch jobs for this run *)
    let jobs_json =
      match read_cmd (Fmt.str "gh run view %d --json jobs" run_id) with
      | None ->
          Fmt.epr "cache-sync: gh run view failed@.";
          Stdlib.exit 1
      | Some s -> Yojson.Basic.from_string s
    in
    (* Step 3: parse and record *)
    let cache = Canary_local_runner.load_cache ~path:cache_path in
    let today =
      let t = Unix.localtime (Unix.gettimeofday ()) in
      Fmt.str "%04d-%02d-%02d" (t.tm_year + 1900) (t.tm_mon + 1) t.tm_mday
    in
    let jobs =
      match jobs_json with
      | `Assoc fields -> (
          match List.assoc_opt "jobs" fields with
          | Some (`List xs) -> xs
          | _ -> [])
      | _ -> []
    in
    let recorded = ref 0 in
    List.iter
      (fun job ->
        match job with
        | `Assoc fields -> (
            let job_name =
              match List.assoc_opt "name" fields with
              | Some (`String s) -> s
              | _ -> ""
            in
            let cache_project =
              List.assoc_opt job_name job_name_to_cache_project
            in
            match cache_project with
            | None -> Fmt.pr "  skipping unknown job: %s@." job_name
            | Some cp ->
                let steps =
                  match List.assoc_opt "steps" fields with
                  | Some (`List xs) -> xs
                  | _ -> []
                in
                List.iter
                  (fun step ->
                    match step with
                    | `Assoc sf ->
                        let name =
                          match List.assoc_opt "name" sf with
                          | Some (`String s) -> s
                          | _ -> ""
                        in
                        let conclusion =
                          match List.assoc_opt "conclusion" sf with
                          | Some (`String s) -> s
                          | _ -> ""
                        in
                        (* Only record base step names (skip "(verify)" suffix steps) *)
                        if
                          not
                            (String.length name > 9
                            && String.sub name (String.length name - 9) 9
                               = "(verify)")
                        then (
                          let key = cp ^ ":" ^ name in
                          let entry =
                            Canary_local_runner.
                              { status = conclusion; run_id; at = today }
                          in
                          Canary_local_runner.cache_record cache ~key entry;
                          Fmt.pr "  %s  →  %s@." key conclusion;
                          incr recorded)
                    | _ -> ())
                  steps)
        | _ -> ())
      jobs;
    Canary_local_runner.save_cache ~path:cache_path cache;
    Fmt.pr "cache-sync: recorded %d entries → %s@." !recorded cache_path
  in
  Cmd.v
    (Cmd.info "cache-sync"
       ~doc:"Sync step results from latest GH CI run into the local cache file")
    Term.(const run $ cache_path $ run_id_arg $ const ())

let ci_cmd =
  let out =
    Arg.(
      value
      & opt string ".github/workflows"
      & info [ "out"; "o" ] ~docv:"DIR"
          ~doc:
            "Output directory for generated YAML (default: .github/workflows)")
  in
  let run out () =
    let distro = detect_distro () in
    Canary_project_z3.render_opam_in ~tola_root:".";
    write_workflow out "canary_ci.yml"
      (Canary_run.render_ci ~root:"_out" distro)
  in
  Cmd.v
    (Cmd.info "ci" ~doc:"Generate GH Actions workflow YAML")
    Term.(const run $ out $ const ())

let debug_ci_cmd =
  let out =
    Arg.(
      value
      & opt string ".github/workflows"
      & info [ "out"; "o" ] ~docv:"DIR"
          ~doc:
            "Output directory for generated YAML (default: .github/workflows)")
  in
  let run out () =
    let distro = detect_distro () in
    write_workflow out "debug.yml"
      (Canary_run.render_debug_ci ~root:"_out" distro)
  in
  Cmd.v
    (Cmd.info "debug-ci"
       ~doc:"Generate debug workflow YAML (workflow_dispatch, SQLite only)")
    Term.(const run $ out $ const ())

let pm_test_cmd =
  Cmd.v
    (Cmd.info "pm-test" ~doc:"Test PM primitive commands (apt/brew/opam)")
    (term_of (fun () ->
         let ok = Canary_pm_test.run_tests () in
         if not ok then Stdlib.exit 1))

let artifact_test_cmd =
  Cmd.v
    (Cmd.info "artifact-test"
       ~doc:"Test artifact primitives (native/ocaml/python)")
    (term_of (fun () ->
         let ok = Canary_artifact_test.run_tests () in
         if not ok then Stdlib.exit 1))

let artifact_inspect_cmd =
  let kind =
    Arg.(
      required
      & opt (some string) None
      & info [ "kind" ] ~docv:"KIND" ~doc:"Artifact kind: native | ocaml | opam")
  in
  let path =
    Arg.(
      required
      & opt (some string) None
      & info [ "path" ] ~docv:"PATH"
          ~doc:
            "For native: path to .so/.dylib. For ocaml: path to .cmxa/.cma. \
             For opam: package name.")
  in
  let prefixes =
    Arg.(
      value
      & opt (list string) []
      & info [ "prefixes" ] ~docv:"CSV"
          ~doc:"Comma-separated symbol prefixes (native only)")
  in
  let watchlist =
    Arg.(
      value
      & opt (list string) []
      & info [ "watchlist" ] ~docv:"CSV"
          ~doc:"Comma-separated watchlist of names to check presence/absence")
  in
  let out_dir =
    Arg.(
      value
      & opt string "docs/canary/test/artifact-summary"
      & info [ "out" ] ~docv:"DIR" ~doc:"Output directory for summary.json")
  in
  let run kind path prefixes watchlist out_dir () =
    ignore (Stdlib.Sys.command (Fmt.str "mkdir -p %s" out_dir));
    let cmd =
      match kind with
      | "native" ->
          Canary_artifact_native.inspect_cmd ~lib:path ~prefixes ~watchlist
            ~output_dir:out_dir ~variant_key:"" ()
      | "ocaml" ->
          Canary_artifact_lang.inspect_cmd ~archive:path ~watchlist
            ~output_dir:out_dir ~variant_key:"" ()
      | "opam" ->
          Canary_artifact_lang.inspect_opam_pkg_cmd ~pkg:path ~watchlist
            ~output_dir:out_dir ~variant_key:"" ()
      | "python" ->
          Canary_artifact_lang.python_inspect_cmd ~pkg:path ~watchlist
            ~output_dir:out_dir ~variant_key:"" ()
      | k ->
          Fmt.epr
            "Unknown kind: %s (expected: native | ocaml | opam | python)@." k;
          Stdlib.exit 2
    in
    let rc = Stdlib.Sys.command cmd in
    if rc <> 0 then (
      Fmt.epr "artifact-summary: command failed (rc=%d)@." rc;
      Stdlib.exit 1);
    Fmt.pr "Wrote %s/summary.json@." out_dir
  in
  Cmd.v
    (Cmd.info "artifact-summary"
       ~doc:"Dump compact artifact interface summary to summary.json")
    Term.(const run $ kind $ path $ prefixes $ watchlist $ out_dir $ const ())

let compat_cmd =
  (* Two modes:
     - Positional <project> [<variant>] uses cached summaries under
       docs/canary/projects/<project>/<variant>/.
     - Explicit --stub PATH --lib PATH uses raw summary.json paths. *)
  let project =
    Arg.(
      value
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT"
          ~doc:"Project name (e.g. llvm, z3) — uses cached summaries.")
  in
  let variant =
    Arg.(
      value & pos 1 string "dev"
      & info [] ~docv:"VARIANT"
          ~doc:
            "Variant name (e.g. 19, dev, stable). \"dev\" matches the most \
             recent dev_* dir.")
  in
  let stub =
    Arg.(
      value
      & opt (some string) None
      & info [ "stub" ] ~docv:"PATH"
          ~doc:
            "Path to a c_stub summary.json (overrides project/variant lookup).")
  in
  let lib =
    Arg.(
      value
      & opt (some string) None
      & info [ "lib" ] ~docv:"PATH"
          ~doc:"Path to a native summary.json with --emit-symbols.")
  in
  let run project variant stub_path lib_path () =
    let rc =
      match (stub_path, lib_path) with
      | Some s, Some l -> Canary_compat_run.run ~stub_path:s ~lib_path:l
      | _ -> (
          match project with
          | None ->
              Fmt.epr
                "compat: pass either <project> [<variant>] or both --stub and \
                 --lib@.";
              2
          | Some p ->
              let root = Stdlib.Sys.getcwd () in
              Canary_compat_run.run_for_project ~root ~project:p ~variant)
    in
    Stdlib.exit rc
  in
  Cmd.v
    (Cmd.info "compat"
       ~doc:
         "Static C-symbol cross-check: predict whether a binding's required \
          symbols are all provided by a native lib. See api_surface.md §13.")
    Term.(const run $ project $ variant $ stub $ lib $ const ())

let verify_cmd =
  let project =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT" ~doc:"Project name (e.g. llvm, z3)")
  in
  let variant =
    Arg.(
      value & pos 1 string "dev"
      & info [] ~docv:"VARIANT"
          ~doc:"Variant (e.g. 19, dev, stable). \"dev\" matches dev_*.")
  in
  let run project variant () =
    let root = Stdlib.Sys.getcwd () in
    Stdlib.exit (Canary_compat_run.verify_for_project ~root ~project ~variant)
  in
  Cmd.v
    (Cmd.info "verify"
       ~doc:
         "Cross-reference cached compat predictions against probe.log \
          outcomes. Reports per-layer prediction-vs-observation alignment.")
    Term.(const run $ project $ variant $ const ())

let index_cmd =
  let run () =
    let projects_root = "_out/canary/projects" in
    let entries = Canary_diagram.scan_index_entries ~projects_root in
    let now =
      let t = Unix.gettimeofday () in
      let tm = Unix.localtime t in
      Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d" (tm.tm_year + 1900)
        (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
    in
    let html = Canary_html.render_index ~entries ~generated_at:now in
    let path = projects_root ^ "/index.html" in
    let oc = Stdlib.open_out path in
    Stdlib.output_string oc html;
    Stdlib.close_out oc;
    Fmt.pr "Wrote %s (%d runs)@." path (List.length entries)
  in
  Cmd.v
    (Cmd.info "index"
       ~doc:
         "Refresh the top-level index.html listing every (project, variant) \
          run found under _out/canary/projects/.")
    Term.(const run $ const ())

let summary_diff_cmd =
  let old_ =
    Arg.(
      required
      & opt (some string) None
      & info [ "old" ] ~docv:"PATH" ~doc:"Path to the older summary.json")
  in
  let new_ =
    Arg.(
      required
      & opt (some string) None
      & info [ "new" ] ~docv:"PATH" ~doc:"Path to the newer summary.json")
  in
  let run old_path new_path () = Canary_inspect_diff.diff ~old_path ~new_path in
  Cmd.v
    (Cmd.info "inspect-diff"
       ~doc:
         "Diff two artifact summary.json files (counts, modules, watchlist, \
          versioned_req)")
    Term.(const run $ old_ $ new_ $ const ())

(* ── Main ── *)

let () =
  let doc = "Canary compatibility testing" in
  let info = Cmd.info "canary" ~doc in
  let cmd =
    Cmd.group info
      [
        paths_cmd;
        paths_md_cmd;
        graph_cmd;
        action_cmd;
        view_cmd;
        ci_cmd;
        debug_ci_cmd;
        cache_sync_cmd;
        pm_test_cmd;
        artifact_test_cmd;
        artifact_inspect_cmd;
        summary_diff_cmd;
        compat_cmd;
        verify_cmd;
        index_cmd;
      ]
  in
  Stdlib.exit (Cmd.eval cmd)
