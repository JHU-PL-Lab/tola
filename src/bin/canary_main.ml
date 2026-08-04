open Cmdliner

let detect_distro () = Canary_basic.detect_distro ()
let term_of f = Term.(const f $ const ())

(* ── Shared run helpers — file-level so both `action` and `tiny run`
   can invoke them uniformly ────────────────────────────────────── *)

(* Runs the graph and RETURNS the per-step status table (for callers that need
   the verdict directly, without re-reading the shared run_state.json). *)
let run_with_info_status ?(artifact_names = fun _ -> None) ~failfast ~cache_path
    ~root ~project steps run_info =
  Canary_run_info.run_project ~failfast ~run_info ?cache_path ~artifact_names
    ~root ~project steps

let run_with_info ?(artifact_names = fun _ -> None) ~failfast ~cache_path
    ~root ~project steps run_info =
  let _ =
    run_with_info_status ~artifact_names ~failfast ~cache_path ~root ~project
      steps run_info
  in
  ()

let with_cli_disabled (cli_disabled : Canary_compat.contract_id list)
    (spec : Canary_step_builder.runner_spec)
    : Canary_step_builder.runner_spec =
  if List.is_empty cli_disabled then spec
  else { spec with
         disabled_contracts = spec.disabled_contracts @ cli_disabled }

let prebuilt_run_info ~project ~version ~extra steps =
  Canary_run_info.mk_run_info ~project ~version ~ref_:"" ~source:"prebuilt"
    ~extra steps

(* [workspace_override], when set, points the run at an already-materialized
   tree (e.g. a tiny-full *assembled* tree) instead of the per-scenario
   workspace — everything downstream (stores, runner_spec, derive_steps, run,
   status) is identical. This is how the vendored assembly reuses the whole
   run path. *)
let run_tiny_scenario ?workspace_override ?(agnostic = false) ~root ~failfast
    ~cache_path ~cli_disabled ~name () =
  let name = Canary_tiny_scenario.name_of_string name in
  let workspace =
    match workspace_override with
    | Some w -> w
    | None ->
        let workspace = Canary_tiny_scenario.cache_workspace_of ~scenario:name in
        if not (Sys.file_exists workspace) then begin
          if not (Sys.file_exists Canary_tiny_workspace.baseline_workspace)
          then begin
            Fmt.pr "[auto-init] preparing baseline workspace...@.";
            Canary_tiny_workspace.run_baseline ()
          end;
          if not (String.equal name "baseline") then begin
            Fmt.pr "[auto-init] preparing scenario workspace for %s...@." name;
            Canary_tiny_workspace.run_prepare ~name
          end
        end;
        workspace
  in
  let mutated_stores =
    Canary_tiny_scenario.stores_of_workspace
      ~workspace_root:workspace
      ()
  in
  let spec =
    Canary_tiny_scenario.runner_spec_of_name
      ~mutated_stores name
    |> with_cli_disabled cli_disabled
  in
  (* Agnostic mode (tiny-full): replace the oracle expectation with the
     inspection-derived one — canary decides per step whether to expect a
     failure, rather than being told by the scenario's recipe. *)
  let spec =
    if agnostic then
      { spec with
        Canary_step_builder.expectation =
          Canary_project_tiny.expectation_agnostic }
    else spec
  in
  let project = "tiny/" ^ name in
  let steps =
    Canary_step_builder.derive_steps ~root ~project
      ~langs:Canary_lang.[ OCaml; Python ]
      spec
  in
  run_with_info ~failfast ~cache_path ~root ~project steps
    (prebuilt_run_info ~project:"tiny" ~version:"in_tree"
       ~extra:[] steps)

let run_state_path_of ~project =
  [%string "_out/canary/projects/%{project}/-run/run_state.json"]

(* PASS iff every step's status is "done" (covers both plain success
   and "expected failure confirmed"). Any status starting with
   "unexpected_" is a FAIL. run_state.json is overwritten per
   scenario by run_project, so we can trust the most recent read.
   [project] MUST match where the run wrote (project_name = the part before
   "/"): "tiny" for the tiny1 / assemble paths, "tiny-full" for the generic
   runner — reading the wrong one serves a stale verdict. *)
let scenario_status_of_run_state ?(project = "tiny") () : string =
  let tiny_run_state_path = run_state_path_of ~project in
  if not (Sys.file_exists tiny_run_state_path) then "N/A"
  else
    match Yojson.Basic.from_file tiny_run_state_path with
    | `Assoc top ->
      (match List.assoc_opt "steps" top with
       | Some (`List steps) ->
         let all_done =
           List.for_all (function
             | `Assoc a ->
               (match List.assoc_opt "status" a with
                | Some (`String "done") -> true
                | _ -> false)
             | _ -> false) steps
         in
         if all_done then "PASS" else "FAIL"
       | _ -> "N/A")
    | _ -> "N/A"
    | exception _ -> "N/A"

(* Run canary over a VENDORED ASSEMBLY (P3 step 2): materialize the assembled
   tree for scenario [tag] (emit its bad resource + overlay on the witness
   base), then drive the whole normal run path over it via
   [run_tiny_scenario ~workspace_override]. A bad scenario's PASS = canary
   *detected* the failure from the assembled (not per-scenario-built) tree —
   the proof the vendored assembly reproduces tiny1's detection. *)
let run_assembled ~root ~failfast ~tag : unit =
  match Canary_tiny_scenario.find_by_id tag with
  | None -> Fmt.pr "unknown tag: %s (see `tiny assemble-check`)@." tag
  | Some s ->
      let key =
        Option.value (Canary_tiny_workspace.artifact_key_of_tag tag) ~default:"lib"
      in
      let label = key ^ "#" ^ tag in
      (match
         Canary_tiny_workspace.materialize_assembled ~overlays:[ (key, tag) ]
           ~label
       with
       | None -> Fmt.pr "assemble failed for %s@." label
       | Some assembled ->
           Fmt.pr "assembled tree: %s@." assembled;
           run_tiny_scenario ~workspace_override:assembled ~root ~failfast
             ~cache_path:None ~cli_disabled:[] ~name:s.scenario.name ();
           Fmt.pr
             "@.tiny-full assembled run [%s %s -> %s]: %s  (bad-scenario PASS \
              = canary detected)@."
             tag s.scenario.name key (scenario_status_of_run_state ()))

(* Provision = Built demo: materialize a source-only-lib tree and run canary
   over it. canary's guarded build_lib COMPILES libtiny.so from c/src (an
   observable action), then probes. PASS = built + green. This is "the good
   lib, built from source" — the Built provision, distinct from Vendored. *)
let run_built_lib ~root : unit =
  match Canary_tiny_workspace.materialize_built_lib ~label:"lib-built-from-src" with
  | None -> Fmt.pr "materialize (source-only lib) failed@."
  | Some ws ->
      Fmt.pr
        "source-only-lib tree: %s@.  (no pre-built libtiny.so — canary must \
         build_lib from c/src)@." ws;
      (try
         run_tiny_scenario ~workspace_override:ws ~agnostic:true ~root
           ~failfast:false ~cache_path:None ~cli_disabled:[]
           ~name:"app_over_binding_ocaml" ()
       with _ -> ());
      Fmt.pr
        "@.tiny-full built-lib (provision=Built): %s  (PASS = canary compiled \
         libtiny.so from source + probed green)@."
        (scenario_status_of_run_state ())

(* Run a COMBINATION: assemble several bad resources onto the witness base and
   run with the AGNOSTIC expectation (a combo has no single oracle scenario).
   Canary's fail-fast run stops at the first failure — the collapse is
   emergent. PASS = canary predicted + confirmed the failure(s) and every step
   matched (the good precedents pass, the bad ones fail as predicted). *)
let run_assembled_combo ~root ~tags : unit =
  let overlays =
    List.filter_map
      (fun tag ->
        match Canary_tiny_workspace.artifact_key_of_tag tag with
        | Some key -> Some (key, tag)
        | None -> None)
      tags
  in
  if List.length overlays = 0 then Fmt.pr "no valid tags (see `tiny assemble-check`)@."
  else
    let label = String.concat "+" (List.map (fun (key, t) -> key ^ "#" ^ t) overlays) in
    (match Canary_tiny_workspace.materialize_assembled ~overlays ~label with
     | None -> Fmt.pr "assemble failed for %s@." label
     | Some assembled ->
         Fmt.pr "combo assembled: %s@." assembled;
         (try
            run_tiny_scenario ~workspace_override:assembled ~agnostic:true ~root
              ~failfast:true ~cache_path:None ~cli_disabled:[]
              ~name:"app_over_binding_ocaml" ()
          with _ -> ());
         Fmt.pr
           "@.tiny-full combo [%s]: %s  (PASS = canary predicted + confirmed \
            the failure and stopped — the collapse, computed not declared)@."
           label (scenario_status_of_run_state ()))

(* The GENERIC project runner (convergence step 2). Consumes a [project_run]
   and does the SAME loop for any project: enumerate → materialize →
   runner_spec → run → report. All project-specific logic lives in the
   closures (tiny-full's materialize = assemble vendored resources; a real
   project's would be build/fetch). Additive — z3/llvm keep their raw-script
   [run_project_multi]; this drives tiny-full and simple projects. Runs dedup
   by materialized workspace (several assignments can map to one tree). *)
let run_project_run (pr : Canary_project_run.project_run) ~root ~failfast :
    unit =
  Fmt.pr "@.%s — generic project run (enumerate → materialize → run)@."
    pr.Canary_project_run.pr_name;
  let seen = ref [] in
  let results = ref [] in (* (label, verdict, is_bad) *)
  List.iter
    (fun a ->
      match pr.Canary_project_run.pr_materialize a with
      | None -> ()
      | Some ws when List.mem ws !seen -> ()
      | Some ws ->
          seen := ws :: !seen;
          let is_bad = not (Canary_tiny_scenario.assignment_is_all_good a) in
          let label = Filename.basename ws in
          (* sanitize for the output path: ':' '#' '+' are ugly / not portable
             (Windows) in a directory name *)
          let safe =
            String.map
              (function ':' | '#' | '+' -> '-' | c -> c)
              label
          in
          let project = pr.Canary_project_run.pr_name ^ "/" ^ safe in
          let spec = pr.Canary_project_run.pr_runner_spec a ~workspace:ws in
          let steps =
            Canary_step_builder.derive_steps ~root ~project
              ~langs:Canary_lang.[ OCaml; Python ] spec
          in
          (* verdict from the RETURNED status table — robust against the shared
             run_state.json being overwritten by the next scenario. On FAIL,
             name the non-done steps (diagnostic). *)
          let verdict, culprits =
            try
              let status =
                run_with_info_status ~failfast ~cache_path:None ~root ~project
                  steps
                  (prebuilt_run_info ~project:pr.Canary_project_run.pr_name
                     ~version:"materialized" ~extra:[] steps)
              in
              let not_done =
                List.filter_map
                  (fun (s : Canary_step_model.step) ->
                    match Base.Hashtbl.find status s.tag with
                    | Some Canary_step_model.Step_done -> None
                    | Some Canary_step_model.Step_failed -> Some (s.tag ^ ":failed")
                    | Some Canary_step_model.Step_skipped -> Some (s.tag ^ ":skipped")
                    | None -> Some (s.tag ^ ":not_run"))
                  steps
              in
              if not_done = [] then ("PASS", "") else ("FAIL", String.concat " " not_done)
            with _ -> ("FAIL", "exn")
          in
          Fmt.pr "  [%-44s] %-6s %s%s@." label verdict
            (if is_bad then "(bad)" else "(good)")
            (if String.equal verdict "FAIL" && not (String.equal culprits "")
             then "  <- " ^ culprits else "");
          results := (label, verdict, is_bad) :: !results)
    (pr.Canary_project_run.pr_enumerate ());
  let bads = List.filter (fun (_, _, b) -> b) !results in
  let detected =
    List.length (List.filter (fun (_, v, _) -> String.equal v "PASS") bads)
  in
  Fmt.pr "@.  coverage: %d/%d bad scenarios detected (generic runner)@."
    detected (List.length bads)

(* Coarse artifact GROUP for the spec listing (ssot §4.2 kinds). *)
let group_of_kind : Canary_basic.artifact_kind -> string = function
  | Canary_basic.Source -> "source"
  | Canary_basic.Headers | Canary_basic.Lib -> "native"
  | Canary_basic.Binding _ -> "bindings"
  | Canary_basic.App -> "app"

let group_order = [ "source"; "native"; "bindings"; "app" ]

let prov_short : Canary_enumerate.provision -> string = function
  | Canary_enumerate.Vendored -> "V"
  | Canary_enumerate.Built -> "B"
  | Canary_enumerate.Fetched -> "F"
  | Canary_enumerate.Absent -> "A"

(* Dry-run snapshot of a [project_run]: declared artifacts (grouped, each with
   its baseline provision@version) + the enumerated scenarios as deltas from
   that baseline. Pure — [pr_materialize] is NOT called (it would build/
   assemble/fetch). A shared view to confirm what canary will enumerate. *)
let print_spec (pr : Canary_project_run.project_run) : unit =
  let module E = Canary_enumerate in
  let placement_str (pl : E.placement) =
    Printf.sprintf "%s:%s" (prov_short pl.provision)
      (E.string_of_build_id pl.version)
  in
  let scenarios = pr.Canary_project_run.pr_enumerate () in
  let all_good = Canary_tiny_scenario.assignment_is_all_good in
  let baseline =
    try List.find all_good scenarios
    with Not_found -> ( match scenarios with a :: _ -> a | [] -> [])
  in
  let baseline_str id =
    match E.placement_of baseline id with
    | Some pl -> placement_str pl
    | None -> "\xE2\x80\x94" (* em dash *)
  in
  Fmt.pr "@.spec: %s — dry-run snapshot (no execution)@."
    pr.Canary_project_run.pr_name;
  (* artifacts, grouped, each with its baseline provision@version *)
  let arts = pr.Canary_project_run.pr_artifacts in
  Fmt.pr "@.artifacts (%d), by group [baseline provision@@version]:@."
    (List.length arts);
  List.iter
    (fun grp ->
      let in_grp =
        List.filter
          (fun a -> String.equal (group_of_kind (E.kind_of a)) grp)
          arts
      in
      if in_grp <> [] then begin
        Fmt.pr "  %s:@." grp;
        List.iter
          (fun a -> Fmt.pr "    %-26s %s@." (E.pretty_id a) (baseline_str a))
          in_grp
      end)
    group_order;
  (* scenarios as deltas from the all-good baseline *)
  let ngood = List.length (List.filter all_good scenarios) in
  let total = List.length scenarios in
  Fmt.pr "@.scenarios (%d: %d good, %d bad) — delta from baseline:@." total ngood
    (total - ngood);
  List.iter
    (fun a ->
      let good = all_good a in
      let deltas =
        List.filter_map
          (fun (id, pl) ->
            let s = placement_str pl in
            if String.equal (baseline_str id) s then None
            else Some (Printf.sprintf "%s=%s" (E.pretty_id id) s))
          a
      in
      let desc =
        match deltas with [] -> "(baseline)" | _ -> String.concat "  " deltas
      in
      Fmt.pr "  [%-4s] %s@." (if good then "good" else "bad") desc)
    scenarios;
  Fmt.pr
    "@.  legend: V=vendored B=built F=fetched A=absent · version=channel[#bad-tag]@.";
  Fmt.pr
    "  note: this is the ENUMERATION; at run time the runner dedups scenarios \
     that materialize to the same workspace, so run coverage counts distinct \
     workspaces (≤ scenarios above).@."

(* Read each artifact's provision from which [runner_spec] closures are set —
   the spec's own declaration, WITHOUT running (build_lib set ⇒ Built, fetch_lib
   ⇒ Fetched, …). Lets `spec` read z3/llvm (raw runner_spec, no project_run)
   without executing or touching their code. build wins over fetch per lang. *)
let provisions_of_runner_spec (rs : Canary_step_builder.runner_spec) :
    (Canary_basic.artifact_kind * Canary_enumerate.provision) list =
  let has = function Some _ -> true | None -> false in
  let src =
    if has rs.fetch_source then [ (Canary_basic.Source, Canary_enumerate.Fetched) ]
    else []
  in
  let lib =
    if has rs.build_lib then [ (Canary_basic.Lib, Canary_enumerate.Built) ]
    else if has rs.fetch_lib then [ (Canary_basic.Lib, Canary_enumerate.Fetched) ]
    else []
  in
  let built_langs = List.map fst rs.build_binding in
  let bind_built =
    List.map
      (fun (l, _) -> (Canary_basic.Binding l, Canary_enumerate.Built))
      rs.build_binding
  in
  let bind_fetched =
    List.filter_map
      (fun (l, _) ->
        if List.mem l built_langs then None
        else Some (Canary_basic.Binding l, Canary_enumerate.Fetched))
      rs.fetch_binding
  in
  src @ lib @ bind_built @ bind_fetched

(* Variant view for projects that expose raw [runner_spec]s per source variant
   (z3/llvm) instead of a [project_run]. Read-only: each variant's runner_spec
   is built from its source record (pure) and its provisions inferred. No
   quality/bad-tag axis — a z3/llvm "defect" is a version-compat EXPECTATION,
   not a mutated artifact, so it doesn't appear as a scenario here. *)
let print_spec_variants ~(name : string)
    ~(variants : (string * Canary_step_builder.runner_spec) list) : unit =
  let module E = Canary_enumerate in
  Fmt.pr
    "@.spec: %s — dry-run snapshot (no execution) [variant view: raw \
     runner_spec, not project_run]@."
    name;
  let all_kinds =
    List.fold_left
      (fun acc (_, rs) ->
        List.fold_left
          (fun acc (k, _) -> if List.mem k acc then acc else acc @ [ k ])
          acc
          (provisions_of_runner_spec rs))
      [] variants
  in
  Fmt.pr "@.artifacts (%d), by group:@." (List.length all_kinds);
  List.iter
    (fun grp ->
      let in_grp =
        List.filter (fun k -> String.equal (group_of_kind k) grp) all_kinds
      in
      if in_grp <> [] then
        Fmt.pr "  %s: %s@." grp
          (String.concat ", " (List.map E.pretty_artifact in_grp)))
    group_order;
  Fmt.pr "@.variants (%d) — per-artifact provision:@." (List.length variants);
  List.iter
    (fun (vname, rs) ->
      let cells =
        List.map
          (fun (k, p) ->
            Printf.sprintf "%s=%s" (E.pretty_artifact k) (prov_short p))
          (provisions_of_runner_spec rs)
      in
      Fmt.pr "  [%-8s] %s@." vname (String.concat "  " cells))
    variants;
  Fmt.pr "@.  legend: V=vendored B=built F=fetched A=absent@.";
  Fmt.pr
    "  note: read-only projection of each variant's runner_spec; the version \
     mismatch these projects test lives in the probe EXPECTATION, not shown \
     here.@."

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
             runner_spec.disabled_contracts and the registry's \
             enabled flag.")
  in
  let thin_arg =
    Arg.(
      value & flag
      & info [ "thin" ]
          ~doc:"tiny-full only: run the thin Subset enumeration (Stable, \
                single-bad, no ctypes/combos).")
  in
  (* run_with_info, with_cli_disabled, prebuilt_run_info, and
     run_tiny_scenario lifted to file top-level 2026-07-09 so
     `tiny run` can reuse them uniformly. *)
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
    let spec = Canary_project_z3.mk_runner_spec ~source:src distro
               |> with_cli_disabled cli_disabled in
    let spec = if quick then Canary_step_builder.no_source spec else spec in
    let steps =
      Canary_step_builder.derive_steps ~root ~project:[%string "z3/%{dev_tag}"]
        ~langs:Canary_lang.[ OCaml; Python ]
        spec
    in
    let src_stable = Canary_project_z3.z3_source_stable in
    let spec_stable =
      Canary_project_z3.mk_runner_spec ~source:src_stable distro
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
  let run_sqlite ~root ~failfast ~cache_path ~cli_disabled =
    let spec = with_cli_disabled cli_disabled Canary_project_sqlite.runner_spec in
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
  (* Tiny runs via the A2-with-factory path
     ({!Canary_tiny_scenario}); see [run_tiny_scenario]
     and [run_tiny_scenario_all] below. The old multi-variant
     run_tiny was retired 2026-07-08 — 13 hand-wired variants
     replaced by 15 factory-derived scenarios matched to the
     tiny list. *)
  (* Run one tiny scenario as its own project via
     Canary_tiny_scenario's factory. project_name = "tiny/<name>"
     — one derive_steps + run_graph, no multi-variant. *)
  let run_zarith ~root ~failfast ~cache_path ~cli_disabled =
    let spec = with_cli_disabled cli_disabled Canary_project_zarith.runner_spec in
    let steps =
      Canary_step_builder.derive_steps ~root ~project:"zarith" spec
    in
    run_with_info ~failfast ~cache_path ~root ~project:"zarith" steps
      (prebuilt_run_info ~project:"zarith" ~version:"system" ~extra:[] steps)
  in
  let run_ssl ~root ~failfast ~cache_path ~cli_disabled =
    (* ssl is a variant project: 2 binding versions × 2 apps + native probe.
       Build each variant's steps, run sequentially (shared switch, ssl
       version swapped per variant). *)
    let variants =
      List.map
        (fun (name, spec) ->
          let spec = with_cli_disabled cli_disabled spec in
          let steps =
            Canary_step_builder.derive_steps ~root
              ~project:[%string "ssl/%{name}"] ~cache_project:"ssl" spec
          in
          (name, steps, None))
        Canary_project_ssl.variants
    in
    Canary_run_info.run_project_multi ~failfast ?cache_path ~root
      ~project_name:"ssl" ~variants ()
  in
  let run_cairo ~root ~failfast ~cache_path ~cli_disabled =
    let spec = with_cli_disabled cli_disabled Canary_project_cairo.runner_spec in
    let steps =
      Canary_step_builder.derive_steps ~root ~project:"cairo" spec
    in
    run_with_info ~failfast ~cache_path ~root ~project:"cairo" steps
      (prebuilt_run_info ~project:"cairo" ~version:"system" ~extra:[] steps)
  in
  let run_llvm ~root ~failfast ~cache_path ~cli_disabled distro =
    let dev_tag =
      Canary_artifact_source.version_cache_tag distro
        Canary_project_llvm.llvm_source_dev
    in
    let spec =
      Canary_project_llvm.mk_runner_spec
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
    let spec_19 = Canary_project_llvm.mk_runner_spec ~source:src_19 distro
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
  let run project quick failfast cache_path disable_contract_csv thin () =
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
    | Some "sqlite" ->
        (* sqlite adopts the generic runner (the real-world project_run) *)
        run_project_run Canary_project_sqlite.sqlite_run ~root ~failfast
    | Some "zarith" -> run_zarith ~root ~failfast ~cache_path ~cli_disabled
    | Some "ssl" -> run_ssl ~root ~failfast ~cache_path ~cli_disabled
    | Some "cairo" -> run_cairo ~root ~failfast ~cache_path ~cli_disabled
    | Some "z3" -> run_z3 ~root ~quick ~failfast ~cache_path ~cli_disabled distro
    | Some "llvm" -> run_llvm ~root ~failfast ~cache_path ~cli_disabled distro
    | Some "tiny-full" ->
        (* the generic project runner drives tiny-full (convergence step 2);
           --thin narrows to the Subset enumeration *)
        let pr =
          if thin then Canary_project_tiny.tiny_full_thin_run
          else (Canary_project_tiny.print_view (); Canary_project_tiny.tiny_full_run)
        in
        run_project_run pr ~root ~failfast
    | Some "tiny" ->
        Fmt.epr "`canary action tiny` (bare) retired 2026-07-09 — use \
                 `canary tiny run` instead (runs all + collects results).@.";
        Stdlib.exit 2
    | Some p when (String.length p > 5)
                  && (String.sub p 0 5 = "tiny/") ->
        let name = String.sub p 5 (String.length p - 5) in
        run_tiny_scenario ~root ~failfast ~cache_path ~cli_disabled ~name ()
    | None ->
        run_sqlite ~root ~failfast ~cache_path ~cli_disabled;
        run_zarith ~root ~failfast ~cache_path ~cli_disabled;
        run_ssl ~root ~failfast ~cache_path ~cli_disabled;
        run_cairo ~root ~failfast ~cache_path ~cli_disabled;
        run_z3 ~root ~quick ~failfast ~cache_path ~cli_disabled distro;
        run_llvm ~root ~failfast ~cache_path ~cli_disabled distro
    | Some p ->
        Fmt.pr
          "Unknown project: %s (available: sqlite, zarith, ssl, cairo, z3, llvm, tiny-full, tiny/<variant>)@." p
  in
  Cmd.v
    (Cmd.info "action" ~doc:"Run the action graph")
    Term.(const run $ project $ quick $ failfast $ cache_path_arg
          $ disable_contract_arg $ thin_arg $ const ())

let spec_cmd =
  let project =
    Arg.(
      value
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT" ~doc:"Project to snapshot: tiny-full | sqlite")
  in
  let thin =
    Arg.(value & flag & info [ "thin" ] ~doc:"tiny-full only: the thin Subset enumeration.")
  in
  let run proj thin () =
    match proj with
    | Some "tiny-full" ->
        print_spec
          (if thin then Canary_project_tiny.tiny_full_thin_run
           else Canary_project_tiny.tiny_full_run)
    | Some "sqlite" -> print_spec Canary_project_sqlite.sqlite_run
    | Some "z3" ->
        let d = detect_distro () in
        print_spec_variants ~name:"z3"
          ~variants:
            [ ( "dev",
                Canary_project_z3.mk_runner_spec
                  ~source:Canary_project_z3.z3_source_dev d );
              ( "stable",
                Canary_project_z3.mk_runner_spec
                  ~source:Canary_project_z3.z3_source_stable d ) ]
    | Some "llvm" ->
        let d = detect_distro () in
        print_spec_variants ~name:"llvm"
          ~variants:
            [ ( "dev",
                Canary_project_llvm.mk_runner_spec
                  ~source:Canary_project_llvm.llvm_source_dev d );
              ( "stable",
                Canary_project_llvm.mk_runner_spec
                  ~source:Canary_project_llvm.llvm_source_stable d ) ]
    | _ ->
        Fmt.epr "usage: canary spec <tiny-full|sqlite|z3|llvm>@.";
        Stdlib.exit 2
  in
  Cmd.v
    (Cmd.info "spec"
       ~doc:"Dry-run snapshot: declared artifacts (grouped) + enumerated \
             scenarios (project_run: tiny-full/sqlite) or per-variant \
             provisions (raw runner_spec: z3/llvm). No execution.")
    Term.(const run $ project $ thin $ const ())

(* Per-project scenario-disable config — the "canary config" part of a
   project's spec: stages applicable by definition but turned off when
   fulfilling the spec. (`scenarios --disable` adds to this per invocation.)

   NOTE: z3/llvm are NOT listed. They genuinely build the lib (their dev
   variant compiles the newest source — that build IS the point, and its
   demo needs the freshly-built lib), so `build_lib` is Covered, not
   disabled. "Skip the slow build" for them is a *variant/origin* choice
   (run the fetch/stable variant, or `--quick`), not a stage disable. *)
let disabled_scenarios_of_project = function
  | _ -> []

let scenarios_cmd =
  let project =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT"
          ~doc:"Project (or @all): sqlite, zarith, ssl, cairo, z3, llvm")
  in
  let disable =
    Arg.(
      value & opt_all string []
      & info [ "disable" ] ~docv:"ACTION"
          ~doc:"Mark a stage disabled (config N/A), e.g. --disable build_lib (repeatable)")
  in
  let engine =
    Arg.(
      value & flag
      & info [ "engine" ]
          ~doc:"Render each variant as a provision assignment (engine \
                projection, ssot §4.2) instead of the coverage matrix")
  in
  let run engine_mode disabled project () =
    let root = "_out" in
    let distro = detect_distro () in
    let all_projects =
      [ "sqlite"; "zarith"; "ssl"; "cairo"; "z3"; "llvm"; "tiny" ]
    in
    (* Every variant of a project (mirrors the `action` dispatch), so
       coverage is the UNION across variants. derive_steps only builds the
       step list — nothing is run. *)
    let variants_of p : (string * Canary_step_builder.runner_spec) list =
      match p with
      | "sqlite" -> [ ("", Canary_project_sqlite.runner_spec) ]
      | "zarith" -> [ ("", Canary_project_zarith.runner_spec) ]
      | "cairo" -> [ ("", Canary_project_cairo.runner_spec) ]
      | "ssl" -> Canary_project_ssl.variants
      | "z3" ->
          [ ("dev",
             Canary_project_z3.mk_runner_spec
               ~source:Canary_project_z3.z3_source_dev distro);
            ("stable",
             Canary_project_z3.mk_runner_spec
               ~source:Canary_project_z3.z3_source_stable distro) ]
      | "llvm" ->
          [ ("dev",
             Canary_project_llvm.mk_runner_spec
               ~source:Canary_project_llvm.llvm_source_dev distro);
            ("19",
             Canary_project_llvm.mk_runner_spec
               ~source:Canary_project_llvm.llvm_source_stable distro) ]
      | _ -> []
    in
    (* The covered action set per project. General projects union their
       variants' derived steps; tiny uses its designed scenarios
       (good_scenarios) — one project space, same engine (ssot §4.2). *)
    let covered_of p : (string * Canary_basic.action list) option =
      match p with
      | "tiny" ->
          Some
            ( "designed scenarios",
              List.concat_map
                (fun (s : Canary_scenario.scenario) -> s.actions)
                Canary_scenario.good_scenarios )
      | _ -> (
          match variants_of p with
          | [] -> None
          | variants ->
              Some
                ( Printf.sprintf "union of %d variant(s)"
                    (List.length variants),
                  List.concat_map
                    (fun (_, spec) ->
                      Canary_step_builder.derive_steps ~root ~project:p
                        ~langs:Canary_lang.[ OCaml; Python ] spec
                      |> List.map (fun (s : Canary_step_model.step) -> s.action))
                    variants ))
    in
    let show p =
      match covered_of p with
      | None ->
          Printf.printf "Unknown project %s (available: @all, %s).\n" p
            (String.concat ", " all_projects)
      | Some (source_desc, covered0) ->
          let covered = List.sort_uniq Stdlib.compare covered0 in
          let langs = Canary_scenario_coverage.langs_of_actions covered in
          (* project's canary config + any --disable from this invocation *)
          let all_disabled = disabled_scenarios_of_project p @ disabled in
          let rows =
            Canary_scenario_coverage.coverage ~langs ~covered
              ~disabled:all_disabled
          in
          Printf.printf "\n%s — scenario coverage (%s)\n%s\n" p source_desc
            (Canary_scenario_coverage.pp_rows rows)
    in
    (* Engine projection (§4.2 provision axis): render each variant as the
       provision assignment its action set implies, and check it is a valid
       engine assignment appearing in general_slice. The general-project
       analogue of `canary tiny engine` (the mutation axis). *)
    let show_engine p =
      match (variants_of p, covered_of p) with
      | [], _ | _, None ->
          Printf.printf
            "%s: no general-project variants to render (tiny's engine \
             projection is `canary tiny engine`).\n" p
      | variants, Some (_, covered0) ->
          let covered = List.sort_uniq Stdlib.compare covered0 in
          let langs = Canary_scenario_coverage.langs_of_actions covered in
          (* general projects: one binding per lang at its default (static)
             mechanism; multiple mechanisms is a tiny-factory concern. *)
          let artifacts =
            Canary_enumerate.a_source :: Canary_enumerate.a_lib
            :: List.map
                 (fun l ->
                   let m =
                     Option.value
                       (Canary_mechanism.default_mechanism_of_lang l)
                       ~default:Canary_mechanism.Cstubs
                   in
                   Canary_enumerate.a_binding l m)
                 langs
          in
          let slice =
            Canary_enumerate.general_slice ~artifacts
              ~provisions:Canary_enumerate.[ Absent; Fetched; Built ]
              ~versions:Canary_basic.two_channels
          in
          let slice_assignments =
            List.filter_map
              (fun (pt : string Canary_enumerate.point) ->
                match pt.mutation with None -> Some pt.assignment | _ -> None)
              slice
          in
          Printf.printf
            "\n%s — engine projection (general_slice: provision axis)\n" p;
          Printf.printf "  artifacts: %s\n"
            (String.concat ", "
               (List.map Canary_enumerate.string_of_id artifacts));
          List.iter
            (fun (vk, spec) ->
              let acts =
                Canary_step_builder.derive_steps ~root ~project:p
                  ~langs:Canary_lang.[ OCaml; Python ] spec
                |> List.map (fun (s : Canary_step_model.step) -> s.action)
              in
              (* a variant picks one version (actions don't encode it);
                 dev-keyed variants = Dev, else Stable. *)
              let version =
                if String.equal vk "dev" then Canary_basic.Dev
                else Canary_basic.Stable
              in
              let a =
                Canary_enumerate.assignment_of_actions ~artifacts ~version acts
              in
              let valid = Canary_enumerate.assignment_ok a in
              let in_slice = List.exists (fun sa -> sa = a) slice_assignments in
              Printf.printf "  [%-6s] %s   (%s, %s)\n"
                (if String.equal vk "" then "-" else vk)
                (Canary_enumerate.string_of_assignment a)
                (if valid then "valid" else "INVALID")
                (if in_slice then "in-slice \xE2\x9C\x93"
                 else "NOT in slice \xE2\x9C\x97"))
            variants;
          Printf.printf
            "  general_slice over {absent,fetched,built}: %d valid assignments\n"
            (List.length slice_assignments)
    in
    if not engine_mode then
      Printf.printf "%s\n" Canary_scenario_coverage.legend;
    let render = if engine_mode then show_engine else show in
    match project with
    | "@all" | "all" -> List.iter render all_projects
    | _ -> render project
  in
  Cmd.v
    (Cmd.info "scenarios"
       ~doc:"Print store-lifecycle scenario coverage (Covered / unspec / disabled)")
    Term.(const run $ engine $ disable $ project $ const ())

let status_cmd =
  let project =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT"
          ~doc:"Project to report (or @all for every project with a run)")
  in
  let verbose =
    Arg.(
      value & flag
      & info [ "v"; "verbose" ]
          ~doc:"Per action, show the witness output file(s) and, for xfail/✗, the concrete failure")
  in
  let run verbose project () =
    let show p = Canary_status.print_status ~verbose ~root:"_out" ~project:p () in
    match project with
    | "@all" | "all" ->
        (match Canary_status.projects_with_runs ~root:"_out" with
         | [] -> Printf.printf "No projects with runs under _out yet.\n"
         | ps -> List.iter show ps)
    | _ -> show project
  in
  Cmd.v
    (Cmd.info "status"
       ~doc:"Print the per-variant × per-step verdict matrix from actions.log")
    Term.(const run $ verbose $ project $ const ())

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

let project_test_cmd =
  Cmd.v
    (Cmd.info "project-test"
       ~doc:"Test project-definition layers (action consumes/produces, \
             detection inventory) — pure, hermetic, no PM/build.")
    (term_of (fun () ->
         let ok = Canary_project_test.run_tests () in
         if not ok then Stdlib.exit 1))

let cache_test_cmd =
  Cmd.v
    (Cmd.info "cache-test"
       ~doc:"Run-cache soundness: a failed step must not be served as a \
             cached success on rerun (bug B / cache.md).")
    (term_of (fun () ->
         let ok = Canary_cache_test.run_tests () in
         if not ok then Stdlib.exit 1))

let mutation_test_cmd =
  Cmd.v
    (Cmd.info "mutation-test"
       ~doc:"Test artifact mutation primitives \
             (apply_patch_cmd, apply_soname_bump_cmds) \
             using tiny's real .patch fixtures.")
    (term_of (fun () ->
         let ok = Canary_artifact_mutation_test.run_tests () in
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

let tiny_scenarios_list_cmd =
  Cmd.v
    (Cmd.info "list" ~doc:"Print scenario names (one per line)")
    (term_of (fun () -> Canary_tiny_scenario.print_list ()))

let tiny_scenarios_expected_cmd =
  let name =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"NAME" ~doc:"Scenario name (see `tiny list`)")
  in
  Cmd.v
    (Cmd.info "expected"
       ~doc:"Print scenario's per-step expected outcomes as JSON")
    Term.(const (fun n () -> Canary_tiny_scenario.print_expected n) $ name $ const ())

let tiny_scenarios_baseline_cmd =
  Cmd.v
    (Cmd.info "baseline"
       ~doc:"Build clean + run every inspector + materialize workspace \
             under _cache/baseline/.")
    (term_of (fun () -> Canary_tiny_workspace.run_baseline ()))

let tiny_scenarios_prepare_cmd =
  let name =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"NAME" ~doc:"Scenario name (see `tiny list`)")
  in
  Cmd.v
    (Cmd.info "prepare"
       ~doc:"Apply scenario mutation in a sandbox, build, inspect, \
             compute surface delta vs baseline, materialize workspace.")
    Term.(const (fun n () -> Canary_tiny_workspace.run_prepare ~name:n) $ name $ const ())

let tiny_scenarios_prepare_all_cmd =
  Cmd.v
    (Cmd.info "prepare-all"
       ~doc:"Run `prepare` for every scenario sequentially. \
             Auto-runs baseline first if missing.")
    (term_of (fun () -> Canary_tiny_workspace.run_prepare_all ()))

let tiny_scenarios_confirm_cmd =
  let name =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"NAME" ~doc:"Scenario name (see `tiny list`)")
  in
  Cmd.v
    (Cmd.info "confirm"
       ~doc:"Print the cached confirm_ill.json for <name> (surface \
             delta vs baseline; produced by `prepare`).")
    Term.(const (fun n () -> Canary_tiny_workspace.confirm ~name:n) $ name $ const ())

let tiny_scenarios_assemble_cmd =
  let id =
    Arg.(
      value & opt string ""
      & info [ "id" ] ~docv:"ID"
          ~doc:"Resource id (auto-derived from TAG when omitted): lib | \
                binding:ocaml:cstubs | binding:python:cext")
  in
  let tag =
    Arg.(
      value
      & pos 0 (some string) None
      & info [] ~docv:"TAG"
          ~doc:"Bad-variant tag = a scenario id (see `tiny list`), e.g. Bs.4 \
                (lib), Bs.8 (ocaml binding), Bs.11 (python cext). Omit to LIST \
                all assemblable resources.")
  in
  Cmd.v
    (Cmd.info "assemble-check"
       ~doc:"P3 step 2 (cached-artifact assembler): with no TAG, list all \
             assemblable cached artifacts; with a TAG, cache the artifact it \
             targets and assemble it onto the witness base. Run `tiny \
             prepare-all` first.")
    Term.(
      const (fun id tag () ->
          match tag with
          | None -> Canary_tiny_workspace.assemble_list ()
          | Some tag -> Canary_tiny_workspace.assemble_check ~key:id ~tag ())
      $ id $ tag $ const ())

let tiny_scenarios_assemble_run_cmd =
  let tag =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"TAG"
          ~doc:"Bad-variant tag (see `tiny assemble-check`), e.g. Bs.1")
  in
  Cmd.v
    (Cmd.info "assemble-run"
       ~doc:"P3 step 2: assemble the vendored tree for <TAG> (bad resource \
             overlaid on the witness base) and RUN canary over it; a PASS \
             means canary detected the failure from the assembled tree. Run \
             `tiny prepare-all` first.")
    Term.(
      const (fun tag () -> run_assembled ~root:"_out" ~failfast:true ~tag)
      $ tag $ const ())

let tiny_scenarios_built_check_cmd =
  Cmd.v
    (Cmd.info "built-check"
       ~doc:"Provision = Built demo: materialize a source-only-lib tree (no \
             pre-built libtiny.so) and run canary — its build_lib COMPILES the \
             lib from c/src (observable) then probes. PASS = built + green. \
             Run `tiny prepare-all` first.")
    (term_of (fun () -> run_built_lib ~root:"_out"))

let tiny_scenarios_assemble_combo_cmd =
  let tags =
    Arg.(
      value & pos_all string []
      & info [] ~docv:"TAG..."
          ~doc:"Two or more bad-variant tags to assemble TOGETHER (a \
                combination), e.g. Bs.1 Bs.8. Runs with the agnostic \
                expectation; PASS = canary computed the collapse.")
  in
  Cmd.v
    (Cmd.info "assemble-combo"
       ~doc:"P3: assemble a MULTI-bad resource-set (the scenarios beyond \
             tiny1) and run canary over it; the fail-fast collapse is \
             emergent. Run `tiny prepare-all` first.")
    Term.(
      const (fun tags () -> run_assembled_combo ~root:"_out" ~tags)
      $ tags $ const ())

(* ── tiny run / tiny status ─────────────────────────────────────
   Shared iteration via Canary_tiny_scenario.iter_scenario_specs so
   the ordering is identical to `tiny list` (and any future
   enumeration). PASS/FAIL derived from the actions.log of the
   most recent run of each scenario. Results persist at
   _out/canary/projects/tiny/results.json. *)

let tiny_results_path =
  "_out/canary/projects/tiny/results.json"

let save_tiny_results (results : (string * string) list) : unit =
  let json =
    `List (List.map (fun (name, status) ->
      `Assoc [
        "name", `String name;
        "status", `String status;
      ]) results)
  in
  let _ = Stdlib.Sys.command "mkdir -p _out/canary/projects/tiny" in
  let oc = Stdlib.open_out tiny_results_path in
  Stdlib.output_string oc (Yojson.Basic.pretty_to_string json);
  Stdlib.output_char oc '\n';
  Stdlib.close_out oc

let load_tiny_results () : (string * string) list =
  if not (Sys.file_exists tiny_results_path) then []
  else
    match Yojson.Basic.from_file tiny_results_path with
    | `List xs ->
      List.filter_map (function
        | `Assoc a ->
          (match List.assoc_opt "name" a, List.assoc_opt "status" a with
           | Some (`String n), Some (`String s) -> Some (n, s)
           | _ -> None)
        | _ -> None) xs
    | _ -> []

let run_tiny_all_and_collect () : unit =
  let root = "_out" in
  let results = ref [] in
  let n_total = List.length Canary_tiny_scenario.scenario_specs in
  let n_bad =
    List.length (List.filter
      (fun (e : Canary_tiny_scenario.scenario_spec) ->
        Option.is_some e.scenario.origin)
      Canary_tiny_scenario.scenario_specs) in
  let n_good = n_total - n_bad in
  Fmt.pr
    "Running %d tiny scenarios: %d bad (Bs.N, all Mutation-origin \
     today — canary should catch each) + %d good (Sc.N runs — \
     canary should stay quiet).@.@."
    n_total n_bad n_good;
  Canary_tiny_scenario.iter_scenario_specs
    ~f:(fun ~index ~total ~(spec : Canary_tiny_scenario.scenario_spec) ->
      let sc = spec.scenario in
      Fmt.pr "[%d/%d] %-11s %-30s ... @?" index total sc.id sc.name;
      (try
         run_tiny_scenario ~root ~failfast:false ~cache_path:None
           ~cli_disabled:[] ~name:sc.name ()
       with _ -> ());
      let status = scenario_status_of_run_state () in
      Fmt.pr "%s@." status;
      results := (sc.name, status) :: !results);
  let results = List.rev !results in
  save_tiny_results results;
  Fmt.pr "@.Results saved to %s@." tiny_results_path;
  let n_pass =
    List.length (List.filter (fun (_, s) -> s = "PASS") results) in
  let n_fail =
    List.length (List.filter (fun (_, s) -> s = "FAIL") results) in
  Fmt.pr "Total: %d PASS, %d FAIL@." n_pass n_fail


let show_tiny_status () : unit =
  let results = load_tiny_results () in
  if results = [] then
    Fmt.pr "No results yet. Run `canary tiny run` first.@."
  else begin
    Fmt.pr "Tiny scenario status (from %s):@.@." tiny_results_path;
    let status_of name =
      match List.assoc_opt name results with
      | Some s -> Some s
      | None -> Some "(not run)"
    in
    Canary_tiny_scenario.print_list ~status_of ();
    let n_pass =
      List.length (List.filter (fun (_, s) -> s = "PASS") results) in
    let n_fail =
      List.length (List.filter (fun (_, s) -> s = "FAIL") results) in
    Fmt.pr "Total: %d PASS, %d FAIL@." n_pass n_fail
  end

let tiny_scenarios_run_cmd =
  Cmd.v
    (Cmd.info "run"
       ~doc:"Run tiny1 — every single-scenario tiny project from the \
             factory — collect PASS/FAIL, save to \
             _out/canary/projects/tiny/results.json. (status.md §1a.)")
    (term_of (fun () -> run_tiny_all_and_collect ()))

let tiny_scenarios_status_cmd =
  Cmd.v
    (Cmd.info "status"
       ~doc:"Show the last-run status for every tiny scenario. Reads \
             _out/canary/projects/tiny/results.json. Run `tiny run` \
             first to populate it.")
    (term_of (fun () -> show_tiny_status ()))


let tiny_scenarios_engine_cmd =
  Cmd.v
    (Cmd.info "engine"
       ~doc:"Render tiny's scenarios as a projection of the shared \
             enumeration engine (all Built × mutation axis); reports the \
             tiny↔engine correspondence. See ssot §4.2.")
    (term_of (fun () -> Canary_tiny_scenario.print_engine_render ()))

let tiny_scenarios_cmd =
  Cmd.group
    (Cmd.info "tiny"
       ~doc:"Tiny scenario helpers — list, expected, baseline, \
             prepare, prepare-all, confirm, engine. See \
             doc/canary/design/tiny.md.")
    [ tiny_scenarios_list_cmd;
      tiny_scenarios_run_cmd;
      tiny_scenarios_engine_cmd;
      tiny_scenarios_status_cmd;
      tiny_scenarios_expected_cmd;
      tiny_scenarios_baseline_cmd;
      tiny_scenarios_prepare_cmd;
      tiny_scenarios_prepare_all_cmd;
      tiny_scenarios_confirm_cmd;
      tiny_scenarios_assemble_cmd;
      tiny_scenarios_assemble_run_cmd;
      tiny_scenarios_assemble_combo_cmd;
      tiny_scenarios_built_check_cmd ]

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
        scenarios_cmd;
        status_cmd;
        view_cmd;
        ci_cmd;
        debug_ci_cmd;
        cache_sync_cmd;
        pm_test_cmd;
        artifact_test_cmd;
        project_test_cmd;
        cache_test_cmd;
        spec_cmd;
        mutation_test_cmd;
        artifact_inspect_cmd;
        summary_diff_cmd;
        tiny_scenarios_cmd;
        compat_cmd;
        verify_cmd;
        index_cmd;
      ]
  in
  Stdlib.exit (Cmd.eval cmd)
