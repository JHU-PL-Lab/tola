open Cmdliner

let detect_distro () = Canary_basic.detect_distro ()
let term_of f = Term.(const f $ const ())

(* ── Shared run helpers — file-level so both `action` and `tiny run`
   can invoke them uniformly ────────────────────────────────────── *)

(* Runs the graph and RETURNS the per-step status table (for callers that need
   the verdict directly, without re-reading the shared run_state.json). *)

let run_project_run ?config (pr : Canary_project_run.project_run) ~root
    ~failfast : unit =
  let results = Canary_batch.run_one ?config pr ~root ~failfast in
  let bads =
    List.filter (fun r -> r.Canary_runner.r_result_is_bad) results
  in
  let detected =
    List.length
      (List.filter
         (fun r -> String.equal r.Canary_runner.r_result_verdict "PASS")
         bads)
  in
  Fmt.pr "@.  coverage: %d/%d bad scenarios detected (generic runner)@."
    detected (List.length bads);
  (let n_xfail =
     List.length
       (List.filter
          (fun r -> r.Canary_runner.r_result_xfails <> [])
          results)
   in
   if n_xfail > 0 then
     Fmt.pr
       "  mismatch scenarios: %d passed via confirmed expected failure \
        (xfail)@."
       n_xfail);
  let path =
    Canary_project_run.scenario_summary_path_of
      ~project:pr.Canary_project_run.pr_name
  in
  try
    let oc = open_out path in
    List.iter
      (fun (r : Canary_runner.scenario_run_result) ->
        Printf.fprintf oc "%s\t%s\t%s\t%s\n"
          r.Canary_runner.r_result_verdict
          (if r.Canary_runner.r_result_is_bad then "bad" else "good")
          (match r.Canary_runner.r_result_xfails with
          | [] -> "-"
          | xs -> String.concat "," (List.map fst xs))
          r.Canary_runner.r_result_key)
      results;
    close_out oc
  with Sys_error _ -> ()

(* ── `canary prebuilt` — PREPARE the vendored prebuilt libs ──
   The lib pair's latest point is a downloaded prebuilt (landing.md §3's
   sourcing rule). It is prepared BEFORE any run, deliberately: a
   scenario must not depend on the network, and every world must see the
   same bytes. Idempotent and version-stamped, so re-running is free and
   a changed declaration re-prepares. *)
let prebuilt_cmd =
  let project =
    Arg.(
      value
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT"
          ~doc:"Project whose prebuilt libs to prepare (default: all).")
  in
  let run proj () =
    let distro = Canary_basic.detect_distro () in
    let all = Canary_registry.declared_prebuilts () in
    let wanted =
      match proj with
      | None -> all
      | Some p -> List.filter (fun (n, _) -> String.equal n p) all
    in
    if wanted = [] then
      Fmt.pr "no declared prebuilt for %s (the lib axis has one point — \
              see the spec's rationale)@."
        (match proj with Some p -> p | None -> "any project")
    else
      List.iter
        (fun (n, (pb : Canary_prebuilt.t)) ->
          let path = Canary_prebuilt.path_of pb distro in
          if Canary_prebuilt.is_prepared pb distro then
            Fmt.pr "[prebuilt] %s: %s already prepared (%s)@." n
              pb.Canary_prebuilt.tag path
          else begin
            Fmt.pr "[prebuilt] %s: preparing %s -> %s@." n
              pb.Canary_prebuilt.tag path;
            let cmd = Canary_prebuilt.prepare_cmd pb distro in
            let rc = Stdlib.Sys.command cmd in
            if rc = 0 && Canary_prebuilt.is_prepared pb distro then
              Fmt.pr "[prebuilt] %s: ok (%s)@." n pb.Canary_prebuilt.note
            else Fmt.pr "[prebuilt] %s: FAILED (rc=%d)@." n rc
          end)
        wanted
  in
  Cmd.v
    (Cmd.info "prebuilt"
       ~doc:
         "Prepare the declared prebuilt (Vendored) native libs — the lib \
          pair's LATEST point, downloaded from the project's own release \
          or conda-forge. Idempotent; run before `action`.")
    Term.(const run $ project $ const ())

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
          ~doc:
            "Project to run: sqlite, z3, llvm, … (default: @all — the batch: \
             heavy projects thin, light full)")
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
      value & opt string ""
      & info [ "disable-contract" ] ~docv:"CSV"
          ~doc:
            "Comma-separated surface-theory contracts to skip for this run, \
             e.g. \"c4,c5\". Layered on top of each project's \
             runner_spec.disabled_contracts and the registry's enabled flag.")
  in
  let thin_arg =
    Arg.(
      value & flag
      & info [ "thin" ]
          ~doc:
            "Run the thin Subset[Stable] enumeration (drops every Dev world). \
             With @all: forces thin everywhere (the batch default already \
             runs heavy projects thin).")
  in
  (* [--audit-lib] (2026-08-17) removed 2026-08-19, user: it materialized
     the shadowed source-built placements for a blame-driven audit pass.
     Prebuilt-shadows-source is unconditional now; a project that wants
     its source-built lib as a world declares it as a distinct version. *)
  let refs_arg =
    Arg.(
      value & opt (some string) None
      & info [ "refs" ] ~docv:"A,B"
          ~doc:
            "Enumerate only the source-repo REFS with these pinned ids \
             (comma-separated), e.g. \"latest,pre-10549\" — the bugfix-commit \
             regression pair. The project declares the full repo family \
             ([stable, latest, ref-before-issue, fork, …]); this narrows the \
             run to a subset. Inert on projects without repo pins.")
  in
  (* [--installed] (2026-08-18) retired 2026-08-19: the installed consumer
     is an ENUMERATION axis now (a project declares an [Installed] lib
     universe and the staged world is its own scenario), so there is no
     realization policy left to flip. *)
  (* Project registry (2026-08-11; plain [project_run]s since 2026-08-12 —
     the [Multi] entry kind retired with ssl's store-pin migration). *)
  (* Tiny runs via the A2-with-factory path
     ({!Canary_tiny_scenario}); see [Canary_project_tiny.run_tiny_scenario]
     and [run_tiny_scenario_all] below. The old multi-variant
     run_tiny was retired 2026-07-08 — 13 hand-wired variants
     replaced by 15 factory-derived scenarios matched to the
     tiny list. *)
  (* Run one tiny scenario as its own project via
     Canary_tiny_scenario's factory. project_name = "tiny/<name>"
     — one derive_steps + run_graph, no multi-variant. *)
  (* [_quick] (skip source fetch) was consumed only by the retired run_z3;
     the flag stays parsed so existing invocations don't break. *)
  let run project _quick failfast cache_path disable_contract_csv thin refs () =
    let root = "_out" in
    let cli_disabled = Canary_compat.contract_ids_of_csv disable_contract_csv in
    if cli_disabled <> [] then
      Fmt.pr "[disable-contract] skipping: %s@."
        (String.concat ", "
           (List.map Canary_compat.string_of_contract_id cli_disabled));
    (* the run config: --thin sets the policy variant, --refs
       narrows the source-repo set (orthogonal; the batch sets its own
       per-project config tier-based inside [Canary_batch.run]). *)
    let refs_level =
      match refs with
      | None -> Canary_enumerate.All_refs
      | Some csv ->
          Canary_enumerate.Refs
            (String.split_on_char ',' csv |> List.map String.trim)
    in
    let config =
      if thin then
        { Canary_project_run.policy = Canary_project_run.Thin;
          refs = refs_level }
      else { Canary_project_run.default_config with refs = refs_level }
    in
    let run_pr pr = run_project_run ~config pr ~root ~failfast in
    match project with
    | Some p when String.length p > 6 && String.sub p 0 6 = "tiny1/" ->
        (* tiny1 scenario through the GENERAL project_run pipeline:
           convert → enumerate → derive_steps → run (agnostic expectation).
           The mutation is baked into the pre-built workspace; canary's
           project spec knows nothing about it. *)
        let name = String.sub p 6 (String.length p - 6) in
        let pr = Canary_project_tiny.project_run_of_tiny1 ~name in
        run_project_run pr ~root ~failfast
    | Some "tiny" ->
        Fmt.epr
          "`canary action tiny` (bare) retired 2026-07-09 — use `canary tiny \
           run` instead (runs all + collects results).@.";
        Stdlib.exit 2
    | Some p when String.length p > 5 && String.sub p 0 5 = "tiny/" ->
        let name = String.sub p 5 (String.length p - 5) in
        Canary_project_tiny.run_tiny_scenario ~root ~failfast ~cache_path
          ~cli_disabled ~name ()
    | Some "@all" | None ->
        (* THE batch (2026-08-14): [Canary_batch.run] over the registry —
           the default config is tier-based (Heavy thin, Light full);
           --thin forces thin everywhere; a single-project run always
           uses the full policy. *)
        Canary_batch.run ~force_thin:thin ~root
          ~failfast Canary_registry.all_projects
    | Some name -> (
        match List.assoc_opt name Canary_registry.all_projects with
        | Some pr -> run_pr pr
        | None ->
            let available =
              List.map fst Canary_registry.all_projects
              @ [ "tiny/<scenario>"; "tiny1/<scenario>" ]
              |> String.concat ", "
            in
            Fmt.pr "Unknown project: %s (available: %s)@." name available)
  in
  Cmd.v
    (Cmd.info "action" ~doc:"Run the action graph")
    Term.(
      const run $ project $ quick $ failfast $ cache_path_arg
      $ disable_contract_arg $ thin_arg $ refs_arg
      $ const ())

(* ── `canary emit` — one dump per pipeline pass (2026-08-24) ──
   design/enumeration/emit_stages.md. THE rule: --stage N prints the value
   stage N hands to stage N+1 — not a rendering of it, and not a join with
   a neighbouring stage. That is what separates this from `spec`, which is
   deliberately a joined human snapshot.

   Every dump goes through [Canary_pipeline], never a re-derivation, so a
   dump cannot agree with itself while disagreeing with what runs. *)
let emit_cmd =
  let project =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT" ~doc:"Project to dump a pass of.")
  in
  let stage =
    Arg.(
      value & opt string "enumerate"
      & info [ "stage" ] ~docv:"PASS"
          ~doc:
            "Which pass to print, by NAME or by index: 1 declare (the \
             project_spec), 2 enumerate (the worlds the project HAS — \
             invocation-independent, --thin and --refs do not affect it), \
             3 select (the worlds this RUN asked for), 4 order (the run \
             order — 3 grouped by the store state each scenario locks; \
             since 2026-08-21 not the same order as 3), 5 realize (one \
             scenario's steps).")
  in
  let json =
    Arg.(
      value & flag
      & info [ "json" ]
          ~doc:
            "Emit the pass as JSON — one encoder per pass, so a dump can \
             be diffed between runs. Keys are canonical.")
  in
  let raw =
    Arg.(
      value & flag
      & info [ "raw" ]
          ~doc:
            "Print the derived [show] form — faithful and diffable, rather \
             than the compact reading form.")
  in
  let thin =
    Arg.(value & flag & info [ "thin" ] ~doc:"Thin enumeration policy.")
  in
  let refs =
    Arg.(
      value & opt (some string) None
      & info [ "refs" ] ~docv:"A,B"
          ~doc:"Only the source refs with these pinned ids.")
  in
  let scenario =
    Arg.(
      value & opt (some string) None
      & info [ "scenario" ] ~docv:"NAME"
          ~doc:
            "--stage 4 only: which scenario to realize (its directory \
             basename). Defaults to the first in run order.")
  in
  let run project stage json raw thin refs scenario () =
    let module P = Canary_pipeline in
    let module EN = Canary_enumerate in
    (* the CATALOGUE, not the active set: muting suppresses RUNNING, not
       inspecting, and a dump of a muted project is exactly when you want
       one (z3 is muted and is the richest spec we have). *)
    match List.assoc_opt project Canary_registry.all_specs with
    | None ->
        Fmt.epr "usage: canary emit <%s> --stage <1|2|2.5|3|4>@."
          (String.concat "|" (List.map fst Canary_registry.all_specs));
        Stdlib.exit 2
    | Some pr ->
        let policy =
          let base =
            if thin then Some (Canary_project_run.thin_policy ())
            else if Option.is_some refs then Some (EN.full_policy ()) else None
          in
          match (base, refs) with
          | Some p, Some csv ->
              Some
                { p with
                  EN.config =
                    { p.EN.config with
                      EN.refs =
                        EN.Refs
                          (String.split_on_char ',' csv |> List.map String.trim)
                    } }
          | b, _ -> b
        in
        let pp_assignments label (asgs : Canary_artifact.assignment list) =
          Fmt.pr "@[<v>%s — %d@,@]" label (List.length asgs);
          List.iter
            (fun a ->
              if raw then
                Fmt.pr "%s@." (Canary_artifact.show_assignment a)
              else
                Fmt.pr "  %s@." (EN.string_of_assignment a))
            asgs
        in
        (* NAME or index — the passes have both (2026-08-24, user: "use a
           more memorable name and an integer pass index"). *)
        let pass =
          match String.lowercase_ascii stage with
          | "1" | "declare" -> `Declare
          | "2" | "enumerate" -> `Enumerate
          | "3" | "select" -> `Select
          | "4" | "order" -> `Order
          | "5" | "realize" -> `Realize
          | other -> `Unknown other
        in
        let out j = print_string (Yojson.Basic.pretty_to_string j ^ "\n") in
        (match pass with
        | `Declare when json -> out (P.json_declare pr)
        | `Enumerate when json ->
            out (P.json_assignments ~pass:"enumerate" pr (P.worlds pr))
        | `Select when json ->
            out
              (P.json_assignments ~pass:"select"
                 ~of_total:(List.length (P.worlds pr))
                 pr (P.enumerated ?policy pr))
        | `Order when json -> out (P.json_order ?policy pr)
        | `Realize when json -> (
            match P.ordered ?policy pr with
            | a :: _ -> out (P.json_realize ~root:"_out" pr a)
            | [] -> Fmt.epr "no scenarios@.")
        | `Declare ->
            let spec = P.spec_of pr in
            if raw then
              Fmt.pr "%s@." (Canary_artifact.show_project_spec spec)
            else begin
              Fmt.pr "%s — declaration (%d artifacts)@." project
                (List.length spec.Canary_artifact.ps_universe);
              List.iter
                (fun (id, (ax : Canary_artifact.artifact_axes)) ->
                  let universe =
                    List.map
                      (fun (pv, chs) ->
                        Printf.sprintf "%s@[%s]"
                          (Canary_artifact.string_of_provision pv)
                          (String.concat ","
                             (List.map Canary_basic.string_of_channel chs)))
                      ax.Canary_artifact.ax_universe
                    |> String.concat " "
                  in
                  let pins =
                    match ax.Canary_artifact.ax_pins with
                    | [] -> ""
                    | ps ->
                        "  pins=["
                        ^ String.concat ","
                            (List.map Canary_basic.string_of_build_id ps)
                        ^ "]"
                  in
                  let follows =
                    match ax.Canary_artifact.ax_follows with
                    | None -> ""
                    | Some f -> "  follows=" ^ Canary_artifact.pretty_id f
                  in
                  let runtime =
                    match ax.Canary_artifact.ax_runtime with
                    | None -> ""
                    | Some Canary_store.Lockstep -> "  runtime=lockstep"
                    | Some Canary_store.Independent -> "  runtime=independent"
                    | Some (Canary_store.Ambient why) ->
                        "  runtime=ambient(" ^ why ^ ")"
                  in
                  Fmt.pr "  %-26s %s%s%s%s@." (Canary_artifact.pretty_id id)
                    universe pins follows runtime)
                spec.Canary_artifact.ps_universe
            end
        | `Enumerate ->
            pp_assignments
              (project ^ " — 2 enumerate: worlds the project HAS")
              (P.worlds pr)
        | `Select ->
            let all = List.length (P.worlds pr) in
            let sel = P.enumerated ?policy pr in
            Fmt.pr "%s — 3 select: asked for %d of %d@." project
              (List.length sel) all;
            List.iter
              (fun a ->
                if raw then Fmt.pr "%s@." (Canary_artifact.show_assignment a)
                else Fmt.pr "  %s@." (EN.string_of_assignment a))
              sel
        | `Order ->
            let ordered = P.ordered ?policy pr in
            Fmt.pr "%s — 4 order: run order — %d@." project
              (List.length ordered);
            let last = ref None in
            List.iter
              (fun a ->
                let key = Canary_project_run.store_state_key pr a in
                let shown =
                  match key with
                  | [] -> "(locks nothing)"
                  | ps ->
                      String.concat " "
                        (List.map (fun (p, v) -> p ^ "=" ^ v) ps)
                in
                if not (Option.equal String.equal (Some shown) !last) then begin
                  Fmt.pr "  ── store state: %s@." shown;
                  last := Some shown
                end;
                if raw then
                  Fmt.pr "%s@." (Canary_artifact.show_assignment a)
                else Fmt.pr "    %s@." (EN.string_of_assignment a))
              ordered
        | `Realize ->
            let ordered = P.ordered ?policy pr in
            let pick =
              match scenario with
              | None -> (match ordered with a :: _ -> Some a | [] -> None)
              | Some name ->
                  List.find_opt
                    (fun a ->
                      String.equal name
                        (Filename.basename
                           (Canary_project_run.scenario_dir_of
                              ~pr_name:pr.pr_name a)))
                    ordered
            in
            (match pick with
             | None ->
                 Fmt.epr "no such scenario; run `canary emit %s --stage 3`@."
                   project;
                 Stdlib.exit 2
             | Some a ->
                 let ctx = P.ctx_of pr a in
                 Fmt.pr "%s — 5 realize: steps@.  scenario %s@." project
                   (Filename.basename ctx.P.sc_workspace);
                 Fmt.pr
                   "  (deriving steps APPLIES pr_runner_spec — for \
                    tiny-full that materializes a tree)@.@.";
                 let steps = P.steps_of ~root:"_out" pr ~ctx a in
                 List.iter
                   (fun (s : Canary_step_model.step) ->
                     Fmt.pr "  %-26s deps=[%s]@." s.Canary_step_model.tag
                       (String.concat "," s.Canary_step_model.deps))
                   steps)
        | `Unknown n ->
            Fmt.epr
              "canary emit: %s is not a pass. Use a name or an index: 1 \
               declare, 2 enumerate, 3 select, 4 order, 5 realize.@."
              n;
            Stdlib.exit 2)
  in
  Cmd.v
    (Cmd.info "emit"
       ~doc:
         "Print one pipeline pass's output (the value it hands the next \
          pass). See design/enumeration/emit_stages.md.")
    Term.(
      const run $ project $ stage $ json $ raw $ thin $ refs $ scenario
      $ const ())

let spec_cmd =
  let project =
    Arg.(
      value
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT"
          ~doc:
            "Project to snapshot: @all (default) | tiny-full | sqlite | z3 | \
             llvm")
  in
  let thin =
    Arg.(
      value & flag
      & info [ "thin" ]
          ~doc:
            "project_run projects (tiny-full, sqlite, z3, llvm): the thin \
             Subset[Stable] enumeration.")
  in
  let refs =
    Arg.(
      value & opt (some string) None
      & info [ "refs" ] ~docv:"A,B"
          ~doc:
            "Enumerate only the source-repo REFS with these pinned ids \
             (comma-separated), e.g. \"latest,pre-10549\". DRY-RUN view; \
             mirror of the action flag.")
  in
  let by_artifact =
    Arg.(
      value & flag
      & info [ "by-artifact" ]
          ~doc:
            "Artifact-centric view (which scenarios touch each artifact + \
             detection rate) instead of the scenario-centric listing.")
  in
  let json =
    Arg.(
      value & flag
      & info [ "json" ]
          ~doc:
            "Emit JSON (machine-readable; supersedes --by-artifact). With \
             @all, one object keyed by project — the refactor cross-check.")
  in
  let run proj thin refs by_artifact json () =
    (* Every project is a [project_run] now; the registry is the single
       source of truth. ssl is a [Multi] — no spec view yet. *)
    let show ?policy pr =
      if json then
        print_string
          (Yojson.Basic.pretty_to_string
             (Canary_project_run.spec_json_t ?policy pr)
          ^ "\n")
      else if by_artifact then Canary_project_run.print_artifacts ?policy pr
      else Canary_project_run.print_spec ?policy pr
    in
    (* --thin is a runner policy, valid on any project_run
       (audit wins, mirroring [action]'s precedence); --refs narrows the
       source-repo set on top *)
    let inject_refs (p : unit Canary_enumerate.policy) :
        unit Canary_enumerate.policy =
      match refs with
      | None -> p
      | Some csv ->
          { p with
            Canary_enumerate.config =
              { p.Canary_enumerate.config with
                Canary_enumerate.refs =
                  Canary_enumerate.Refs
                    (String.split_on_char ',' csv |> List.map String.trim) } }
    in
    let show_enum pr =
      if thin then
        show ~policy:(inject_refs (Canary_project_run.thin_policy ())) pr
      else if Option.is_some refs then
        show ~policy:(inject_refs (Canary_enumerate.full_policy ())) pr
      else show pr
    in
    match proj with
    | Some p when String.length p > 6 && String.sub p 0 6 = "tiny1/" ->
        let name = String.sub p 6 (String.length p - 6) in
        show (Canary_project_tiny.project_run_of_tiny1 ~name)
    | Some "@all" | None -> (
        (* every registry project's spec — the refactor cross-check *)
        let prs =
          List.map snd Canary_registry.all_projects
        in
        if json then
          let projects =
            List.map (fun pr -> Canary_project_run.spec_json_t pr) prs
          in
          print_string
            (Yojson.Basic.pretty_to_string
               (`Assoc [ ("projects", `List projects) ])
            ^ "\n")
        else List.iter show prs)
    | Some name -> (
        match List.assoc_opt name Canary_registry.all_projects with
        | Some pr -> show_enum pr
        | None ->
            Fmt.epr
              "usage: canary spec <@all|%s|tiny1/<name>>@."
              (String.concat "|" (List.map fst Canary_registry.all_projects));
            Stdlib.exit 2)
  in
  Cmd.v
    (Cmd.info "spec"
       ~doc:
         "Dry-run snapshot: declared artifacts (grouped) + enumerated \
          scenarios (project_run: tiny-full/sqlite) or per-scenario provisions \
          (raw runner_spec: z3/llvm). No execution.")
    Term.(const run $ project $ thin $ refs $ by_artifact $ json $ const ())

(* Static spec-maturity audit (2026-08-13): reads ONLY the declared
   [project_run] (artifact rows + wrapper pkgs) — no enumeration, no
   realization. Exit 1 when any project has errors (a gate). *)
let spec_check_cmd =
  let project =
    Arg.(
      value
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT"
          ~doc:
            "Project to audit: @all (default) | sqlite | z3 | llvm | tiny-full \
             | zarith | cairo | libffi | ssl")
  in
  let json =
    Arg.(
      value & flag
      & info [ "json" ]
          ~doc:
            "Emit JSON (machine-readable; for the web status page). With \
             @all, an array of reports; a single project, one report object.")
  in
  let run proj json () =
    let has_errors r = not (List.is_empty (Canary_spec_check.errors_of r)) in
    let show r =
      if json then
        print_string
          (Yojson.Safe.pretty_to_string (Canary_spec_check.report_to_json r)
          ^ "\n")
      else Fmt.pr "%s@." (Canary_spec_check.pp_report r)
    in
    match proj with
    | Some "@all" | None ->
        let reports =
          List.map (fun (_n, pr) -> Canary_spec_check.check pr)
            Canary_registry.all_projects
        in
        if json then
          print_string
            (Yojson.Safe.pretty_to_string
               (`List (List.map Canary_spec_check.report_to_json reports))
            ^ "\n")
        else (
          Fmt.pr "%s@." Canary_spec_check.legend;
          List.iter
            (fun r -> Fmt.pr "%s@.@." (Canary_spec_check.pp_report r))
            reports;
          let bad = List.length (List.filter has_errors reports) in
          Fmt.pr "overall: %d project(s) with errors@." bad);
        let bad = List.length (List.filter has_errors reports) in
        if bad > 0 then Stdlib.exit 1
    | Some name -> (
        match List.assoc_opt name Canary_registry.all_projects with
        | Some pr ->
            let r = Canary_spec_check.check pr in
            show r;
            if has_errors r then Stdlib.exit 1
        | None ->
            Fmt.epr "usage: canary spec-check <@all|%s>@."
              (String.concat "|" (List.map fst Canary_registry.all_projects));
            Stdlib.exit 2)
  in
  Cmd.v
    (Cmd.info "spec-check"
       ~doc:
         "Static spec-maturity audit against the mismatch-matrix \
          readiness checklist (✓/✗/⚠): does the project declare enough to \
          run the checks — a channel pair per artifact (stable + latest), \
          a C API, providers, binding declarations. No execution.")
    Term.(const run $ project $ json $ const ())

(* Per-project scenario-disable config — the "canary config" part of a
   project's spec: stages applicable by definition but turned off when
   fulfilling the spec. (`scenarios --disable` adds to this per invocation.)

   NOTE: z3/llvm are NOT listed. They genuinely build the lib (their dev
   variant compiles the newest source — that build IS the point, and its
   demo needs the freshly-built lib), so `build_lib` is Covered, not
   disabled. "Skip the slow build" for them is a *variant/origin* choice
   (run the fetch/stable variant, or `--quick`), not a stage disable. *)
let disabled_scenarios_of_project = function _ -> []

let scenarios_cmd =
  let project =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT"
          ~doc:
            "Project (or @all): sqlite, z3, llvm, tiny-full, tiny, zarith, \
             ssl, cairo")
  in
  let disable =
    Arg.(
      value & opt_all string []
      & info [ "disable" ] ~docv:"ACTION"
          ~doc:
            "Mark a stage disabled (config N/A), e.g. --disable build_lib \
             (repeatable)")
  in
  let engine =
    Arg.(
      value & flag
      & info [ "engine" ]
          ~doc:
            "Render each variant as a provision assignment \
             (engine                 projection, ssot §4.2) instead of the \
             coverage matrix")
  in
  let run engine_mode disabled project () =
    (* F5 (2026-08-10) + registry (2026-08-12): every project derives
       coverage from the enumeration engine ([covered_actions_of]). *)
    let covered_of p : (string * Canary_basic.action list) option =
      match p with
      | "tiny" ->
          Some
            ( "designed scenarios",
              List.concat_map
                (fun (s : Canary_scenario.scenario) -> s.actions)
                Canary_scenario.good_scenarios )
      | _ -> (
          match List.assoc_opt p Canary_registry.all_projects with
          | Some pr ->
              Some
                ( "enumerated scenarios",
                  Canary_project_run.covered_actions_of pr )
          | None -> None)
    in
    let show p =
      match covered_of p with
      | None ->
          Printf.printf
            "Unknown project %s (available: sqlite, z3, llvm, tiny-full, tiny, \
             zarith, ssl, cairo).\n"
            p
      | Some (source_desc, covered0) ->
          let covered = List.sort_uniq Stdlib.compare covered0 in
          let langs = Canary_scenario_coverage.langs_of_actions covered in
          let all_disabled = disabled_scenarios_of_project p @ disabled in
          let rows =
            Canary_scenario_coverage.coverage ~langs ~covered
              ~disabled:all_disabled
          in
          Printf.printf "\n%s — scenario coverage (%s)\n%s\n" p source_desc
            (Canary_scenario_coverage.pp_rows rows)
    in
    let show_engine p =
      match covered_of p with
      | None -> Printf.printf "%s: no variants to render.\n" p
      | Some (_, covered0) ->
          let covered = List.sort_uniq Stdlib.compare covered0 in
          let langs = Canary_scenario_coverage.langs_of_actions covered in
          let artifacts =
            Canary_artifact.a_source :: Canary_enumerate.a_lib
            :: List.map
                 (fun l ->
                   let m =
                     Option.value
                       (Canary_mechanism.default_mechanism_of_lang l)
                       ~default:Canary_mechanism.Cstubs
                   in
                   Canary_artifact.a_binding l m)
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
                match pt.mutations with [] -> Some pt.assignment | _ -> None)
              slice
          in
          Printf.printf
            "\n%s — engine projection (general_slice: provision axis)\n" p;
          Printf.printf "  artifacts: %s\n"
            (String.concat ", "
               (List.map Canary_artifact.string_of_id artifacts));
          Printf.printf "  general_slice: %d valid assignments\n"
            (List.length slice_assignments)
    in
    if not engine_mode then Printf.printf "%s\n" Canary_scenario_coverage.legend;
    let render = if engine_mode then show_engine else show in
    match project with
    | "@all" | "all" ->
        List.iter render
          (List.map fst Canary_registry.all_projects @ [ "tiny" ])
    | _ -> render project
  in
  Cmd.v
    (Cmd.info "scenarios"
       ~doc:
         "Print store-lifecycle scenario coverage (Covered / unspec / disabled)")
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
          ~doc:
            "Per action, show the witness output file(s) and, for xfail/✗, the \
             concrete failure")
  in
  let run verbose project () =
    let show p =
      Canary_status.print_status ~verbose ~root:"_out" ~project:p ()
    in
    match project with
    | "@all" | "all" -> (
        match Canary_status.projects_with_runs ~root:"_out" with
        | [] -> Printf.printf "No projects with runs under _out yet.\n"
        | ps -> List.iter show ps)
    | _ -> show project
  in
  Cmd.v
    (Cmd.info "status"
       ~doc:"Print the per-scenario × per-step verdict matrix from actions.log")
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
       ~doc:
         "Test project-definition layers (action consumes/produces, detection \
          inventory) + live project-spec pins (z3) — pure, hermetic, no \
          PM/build.")
    (term_of (fun () ->
         let ok =
           Canary_project_test.run_tests ~extra:Canary_projects_test.tests ()
         in
         if not ok then Stdlib.exit 1))

let cache_test_cmd =
  Cmd.v
    (Cmd.info "cache-test"
       ~doc:
         "Run-cache soundness: a failed step must not be served as a cached \
          success on rerun (bug B / cache.md).")
    (term_of (fun () ->
         let ok = Canary_cache_test.run_tests () in
         if not ok then Stdlib.exit 1))

let mutation_test_cmd =
  Cmd.v
    (Cmd.info "mutation-test"
       ~doc:
         "Test artifact mutation primitives (apply_patch_cmd, \
          apply_soname_bump_cmds) using tiny's real .patch fixtures.")
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

(* ── the result table (2026-08-17) ── *)
let result_cmd =
  let project =
    Arg.(
      value
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT"
          ~doc:
            "Project to restrict the matrix to (default @all — every \
             registry project).")
  in
  let md =
    Arg.(
      value & flag
      & info [ "md" ]
          ~doc:
            "Render as markdown tables (per-project sections) instead of \
             the aligned text view.")
  in
  let json =
    Arg.(
      value & flag
      & info [ "json" ]
          ~doc:"Emit JSON (machine-readable) instead of the text view.")
  in
  let run project md json () =
    let projects =
      match project with
      | Some p -> (
          match List.assoc_opt p Canary_registry.all_projects with
          | Some pr -> [ (p, pr) ]
          | None ->
              Fmt.epr "Unknown project: %s@." p;
              Stdlib.exit 2)
      | None -> Canary_registry.all_projects
    in
    let m = Canary_matrix.matrix_of projects in
    if json then
      print_string
        (Yojson.Basic.pretty_to_string (Canary_matrix.to_json m) ^ "\n")
    else if md then Canary_matrix.pp_md m
    else Canary_matrix.pp_text m;
    (* the web page refresh rides the pure read (the [canary index]
       precedent — web copies live in docs/canary for GH Pages) *)
    let now =
      let t = Unix.gettimeofday () in
      let tm = Unix.localtime t in
      Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d" (tm.tm_year + 1900)
        (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
    in
    Canary_matrix.write_web ~projects_root:"_out/canary/projects" m
      ~generated_at:now
  in
  Cmd.v
    (Cmd.info "result"
       ~doc:
         "The result table: rows = project × scenario (the enumerated \
          worlds), columns = actions, cells = last-run verdicts \
          (✓/✗/xfail[cN]/·/⊘). Pure read of the run artifacts; also \
          refreshes the web page (docs/canary/projects/matrix.html).")
    Term.(const run $ project $ md $ json $ const ())

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
    Term.(
      const (fun n () -> Canary_tiny_scenario.print_expected n)
      $ name $ const ())

let tiny_scenarios_expected_all_cmd =
  Cmd.v
    (Cmd.info "expected-all"
       ~doc:
         "Print all 22 scenarios with canary expected outcomes (shared \
          reference)")
    (term_of (fun () -> Canary_tiny_scenario.print_expected_table ()))

let tiny_scenarios_scenario_cmd =
  Cmd.v
    (Cmd.info "scenario"
       ~doc:"Print old→canonical name mapping for all 22 scenarios")
    (term_of (fun () -> Canary_tiny_scenario.print_canonical_names ()))

let tiny_scenarios_baseline_cmd =
  Cmd.v
    (Cmd.info "baseline"
       ~doc:
         "Build clean + run every inspector + materialize workspace under \
          _cache/baseline/.")
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
       ~doc:
         "Apply scenario mutation in a sandbox, build, inspect, compute \
          surface delta vs baseline, materialize workspace.")
    Term.(
      const (fun n () -> Canary_tiny_workspace.run_prepare ~name:n)
      $ name $ const ())

let tiny_scenarios_prepare_all_cmd =
  Cmd.v
    (Cmd.info "prepare-all"
       ~doc:
         "Run `prepare` for every scenario sequentially. Auto-runs baseline \
          first if missing.")
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
       ~doc:
         "Print the cached confirm_ill.json for <name> (surface delta vs \
          baseline; produced by `prepare`).")
    Term.(
      const (fun n () -> Canary_tiny_workspace.confirm ~name:n)
      $ name $ const ())

let tiny_scenarios_assemble_cmd =
  let id =
    Arg.(
      value & opt string ""
      & info [ "id" ] ~docv:"ID"
          ~doc:
            "Resource id (auto-derived from TAG when omitted): lib | \
             binding:ocaml:cstubs | binding:python:cext")
  in
  let tag =
    Arg.(
      value
      & pos 0 (some string) None
      & info [] ~docv:"TAG"
          ~doc:
            "Bad-variant tag = a scenario id (see `tiny list`), e.g. Bs.4 \
             (lib), Bs.8 (ocaml binding), Bs.11 (python cext). Omit to LIST \
             all assemblable resources.")
  in
  Cmd.v
    (Cmd.info "assemble-check"
       ~doc:
         "P3 step 2 (cached-artifact assembler): with no TAG, list all \
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
       ~doc:
         "P3 step 2: assemble the vendored tree for <TAG> (bad resource \
          overlaid on the witness base) and RUN canary over it; a PASS means \
          canary detected the failure from the assembled tree. Run `tiny \
          prepare-all` first.")
    Term.(
      const (fun tag () ->
          Canary_project_tiny.run_assembled ~root:"_out" ~failfast:true ~tag)
      $ tag $ const ())

let tiny_scenarios_built_check_cmd =
  Cmd.v
    (Cmd.info "built-check"
       ~doc:
         "Provision = Built demo: materialize a source-only-lib tree (no \
          pre-built libtiny.so) and run canary — its build_lib COMPILES the \
          lib from c/src (observable) then probes. PASS = built + green. Run \
          `tiny prepare-all` first.")
    (term_of (fun () -> Canary_project_tiny.run_built_lib ~root:"_out"))

let tiny_scenarios_assemble_combo_cmd =
  let tags =
    Arg.(
      value & pos_all string []
      & info [] ~docv:"TAG..."
          ~doc:
            "Two or more bad-variant tags to assemble TOGETHER (a \
             combination), e.g. Bs.1 Bs.8. Runs with the agnostic expectation; \
             PASS = canary computed the collapse.")
  in
  Cmd.v
    (Cmd.info "assemble-combo"
       ~doc:
         "P3: assemble a MULTI-bad resource-set (the scenarios beyond tiny1) \
          and run canary over it; the fail-fast collapse is emergent. Run \
          `tiny prepare-all` first.")
    Term.(
      const (fun tags () ->
          Canary_project_tiny.run_assembled_combo ~root:"_out" ~tags)
      $ tags $ const ())

(* ── tiny run / tiny status ─────────────────────────────────────
   Shared iteration via Canary_tiny_scenario.iter_scenario_specs so
   the ordering is identical to `tiny list` (and any future
   enumeration). PASS/FAIL derived from the actions.log of the
   most recent run of each scenario. Results persist at
   _out/canary/projects/tiny/results.json. *)

let tiny_results_path = "_out/canary/projects/tiny/results.json"

let save_tiny_results (results : (string * string) list) : unit =
  let json =
    `List
      (List.map
         (fun (name, status) ->
           `Assoc [ ("name", `String name); ("status", `String status) ])
         results)
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
        List.filter_map
          (function
            | `Assoc a -> (
                match (List.assoc_opt "name" a, List.assoc_opt "status" a) with
                | Some (`String n), Some (`String s) -> Some (n, s)
                | _ -> None)
            | _ -> None)
          xs
    | _ -> []

let run_tiny_all_and_collect () : unit =
  let root = "_out" in
  let results = ref [] in
  let n_total = List.length Canary_tiny_scenario.scenario_specs in
  let n_bad =
    List.length
      (List.filter
         (fun (e : Canary_tiny_scenario.scenario_spec) ->
           Option.is_some e.scenario.origin)
         Canary_tiny_scenario.scenario_specs)
  in
  let n_good = n_total - n_bad in
  Fmt.pr
    "Running %d tiny scenarios: %d bad (Bs.N, all Mutation-origin today — \
     canary should catch each) + %d good (Sc.N runs — canary should stay \
     quiet).@.@."
    n_total n_bad n_good;
  Canary_tiny_scenario.iter_scenario_specs
    ~f:(fun ~index ~total ~(spec : Canary_tiny_scenario.scenario_spec) ->
      let sc = spec.scenario in
      Fmt.pr "[%d/%d] %-11s %-30s ... @?" index total sc.id sc.name;
      (try
         Canary_project_tiny.run_tiny_scenario ~root ~failfast:false
           ~cache_path:None ~cli_disabled:[] ~name:sc.name ()
       with _ -> ());
      let status = Canary_project_run.scenario_status_of_run_state () in
      Fmt.pr "%s@." status;
      results := (sc.name, status) :: !results);
  let results = List.rev !results in
  save_tiny_results results;
  Fmt.pr "@.Results saved to %s@." tiny_results_path;
  let n_pass = List.length (List.filter (fun (_, s) -> s = "PASS") results) in
  let n_fail = List.length (List.filter (fun (_, s) -> s = "FAIL") results) in
  Fmt.pr "Total: %d PASS, %d FAIL@." n_pass n_fail

let show_tiny_status () : unit =
  let results = load_tiny_results () in
  if results = [] then Fmt.pr "No results yet. Run `canary tiny run` first.@."
  else begin
    Fmt.pr "Tiny scenario status (from %s):@.@." tiny_results_path;
    let status_of name =
      match List.assoc_opt name results with
      | Some s -> Some s
      | None -> Some "(not run)"
    in
    Canary_tiny_scenario.print_list ~status_of ();
    let n_pass = List.length (List.filter (fun (_, s) -> s = "PASS") results) in
    let n_fail = List.length (List.filter (fun (_, s) -> s = "FAIL") results) in
    Fmt.pr "Total: %d PASS, %d FAIL@." n_pass n_fail
  end

let tiny_scenarios_run_cmd =
  Cmd.v
    (Cmd.info "run"
       ~doc:
         "Run tiny1 — every single-scenario tiny project from the factory — \
          collect PASS/FAIL, save to _out/canary/projects/tiny/results.json. \
          (status.md §1a.)")
    (term_of (fun () -> run_tiny_all_and_collect ()))

let tiny_scenarios_status_cmd =
  Cmd.v
    (Cmd.info "status"
       ~doc:
         "Show the last-run status for every tiny scenario. Reads \
          _out/canary/projects/tiny/results.json. Run `tiny run` first to \
          populate it.")
    (term_of (fun () -> show_tiny_status ()))

let tiny_scenarios_engine_cmd =
  Cmd.v
    (Cmd.info "engine"
       ~doc:
         "Render tiny's scenarios as a projection of the shared enumeration \
          engine (all Built × mutation axis); reports the tiny↔engine \
          correspondence. See ssot §4.2.")
    (term_of (fun () -> Canary_tiny_scenario.print_engine_render ()))

let tiny_scenarios_cmd =
  Cmd.group
    (Cmd.info "tiny"
       ~doc:
         "Tiny scenario helpers — list, expected, baseline, prepare, \
          prepare-all, confirm, engine. See doc/canary/design/tiny.md.")
    [
      tiny_scenarios_list_cmd;
      tiny_scenarios_run_cmd;
      tiny_scenarios_engine_cmd;
      tiny_scenarios_status_cmd;
      tiny_scenarios_expected_cmd;
      tiny_scenarios_expected_all_cmd;
      tiny_scenarios_scenario_cmd;
      tiny_scenarios_baseline_cmd;
      tiny_scenarios_prepare_cmd;
      tiny_scenarios_prepare_all_cmd;
      tiny_scenarios_confirm_cmd;
      tiny_scenarios_assemble_cmd;
      tiny_scenarios_assemble_run_cmd;
      tiny_scenarios_assemble_combo_cmd;
      tiny_scenarios_built_check_cmd;
    ]

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

(* ── `construct <pj>` — the forward graph construction, made visible ──
   Artifacts are NODES; build/fetch actions are EDGES that generate new nodes
   (with variants). Drives [make_action_graph] (already the forward-construction
   engine, used only for the diagram today) over a project's source versions and
   prints the generated node set — incl. the deploy MISMATCH (an App whose
   build-lib ≠ runtime-lib). No run; validates the node set before the run learns
   to walk it. *)
let chan_str = function
  | Canary_basic.Dev -> "dev"
  | Canary_basic.Stable -> "stable"

let print_construction ~(name : string) ~(app_mode : Canary_action.dep_mode)
    ~(provisions_of_kind :
       Canary_basic.artifact_kind -> Canary_store.provision list)
    ~(versions : Canary_basic.channel list) : unit =
  let module CA = Canary_action in
  let bid = Canary_enumerate.string_of_build_id in
  let g =
    CA.make_action_graph
      ~actions:(CA.store_actions ~langs:Canary_lang.[ OCaml; Python ])
      ~versions ~name ~source:Canary_store.store ~app_mode ~vendored:true ()
  in
  let applicable = CA.node_applicable ~provisions_of_kind in
  Fmt.pr "@.graph construction: %s (source versions: %s; app runtime = %s)@."
    name
    (String.concat ", " (List.map chan_str versions))
    (match app_mode with
    | CA.Lockstep -> "Lockstep (matched chain)"
    | CA.Independent -> "Independent (mismatch cartesian)"
    | CA.Ambient _ -> "Ambient");
  Fmt.pr
    "  UNIVERSAL graph (make_action_graph), marked by the project's \
     ps_provisions_of — APPLICABLE nodes = the project's real scenarios; the \
     rest are n/a.@.";
  let node_line (n : CA.artifact_node) =
    let prov = Canary_store.string_of_provision n.CA.provision in
    let edge =
      match n.CA.built_from with
      | Some b ->
          Printf.sprintf " ← %s@%s"
            (Canary_basic.string_of_artifact_kind b.CA.a_kind)
            (bid b.CA.version)
      | None -> ""
    in
    let rt =
      match n.CA.runtime_dep with
      | Some r -> Printf.sprintf "  [runtime: lib@%s]" (bid r.CA.version)
      | None -> ""
    in
    let mism =
      match (n.CA.built_from, n.CA.runtime_dep) with
      | Some bind, Some rl -> (
          match bind.CA.built_from with
          | Some build_lib
            when not
                   (Canary_enumerate.equal_version build_lib.CA.version
                      rl.CA.version) ->
              "   ⚠ DEPLOY MISMATCH"
          | _ -> "")
      | _ -> ""
    in
    Printf.sprintf "@%s (%s)%s%s%s" (bid n.CA.version) prov edge rt mism
  in
  List.iter
    (fun (kind, nodes) ->
      if nodes <> [] then begin
        let app_nodes = List.filter applicable nodes in
        let na = List.length nodes - List.length app_nodes in
        Fmt.pr "@.  %s — %d applicable / %d total%s:@."
          (Canary_basic.string_of_artifact_kind kind)
          (List.length app_nodes) (List.length nodes)
          (if na > 0 then Printf.sprintf " (%d n/a)" na else "");
        List.iter (fun n -> Fmt.pr "    %s@." (node_line n)) app_nodes
      end)
    (* dependency (execution) order: source → headers → lib → binding → app,
       so the applicable listing reads as the trace the run would follow. *)
    (List.sort
       (fun (k1, _) (k2, _) ->
         compare (Canary_basic.kind_order k1) (Canary_basic.kind_order k2))
       g.CA.pools);
  let total_app =
    List.fold_left
      (fun acc (_, nodes) -> acc + List.length (List.filter applicable nodes))
      0 g.CA.pools
  in
  let total =
    List.fold_left (fun acc (_, ns) -> acc + List.length ns) 0 g.CA.pools
  in
  Fmt.pr
    "@.  execution set: %d applicable / %d total nodes (deduped by node_tag). \
     The run walks the APPLICABLE nodes in the order above; the %d-node \
     universal is generation only, never executed.@."
    total_app total total;
  Fmt.pr
    "@.  note: n/a = a (kind, provision) the project doesn't declare (its \
     ps_provisions_of) or whose deps are n/a — the mark cascades along edges. \
     make_action_graph stays universal; the project filters after.@.";
  (* EXECUTION PLAN: the applicable DAG flattened into the run's walk order.
     Each line is one node = one edge (action) the run executes, with the
     upstream it consumes and its per-node cache key (node_tag). This is what
     the graph-walking run will follow. *)
  let plan = CA.execution_plan ~provisions_of_kind g in
  Fmt.pr "@.  execution plan (topo order — the run walks these edges):@.";
  List.iteri
    (fun i n ->
      let dep =
        match n.CA.built_from with
        | Some b ->
            Printf.sprintf " ← %s@%s"
              (Canary_basic.string_of_artifact_kind b.CA.a_kind)
              (bid b.CA.version)
        | None -> ""
      in
      let edge =
        match CA.producing_action_of_node n with
        | Some _ -> CA.edge_label_of_node n
        | None -> CA.edge_label_of_node n ^ " (initial — supplied, no build)"
      in
      Fmt.pr "    %2d. %-32s %s@%s%s@." (i + 1) edge
        (Canary_basic.string_of_artifact_kind n.CA.a_kind)
        (bid n.CA.version) dep)
    plan

let construct_cmd =
  let project =
    Arg.(
      value
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT" ~doc:"tiny-full | sqlite")
  in
  let matched =
    Arg.(
      value & flag
      & info [ "matched" ]
          ~doc:
            "Lockstep App runtime (matched chain, no mismatch) instead of the \
             default Independent (mismatch cartesian).")
  in
  (* the project's capability = its ps_provisions_of, keyed by kind (the mark). *)
  let prov_of_spec (spec : Canary_artifact.project_spec)
      (k : Canary_basic.artifact_kind) : Canary_store.provision list =
    match
      List.find_opt
        (fun aid -> Canary_artifact.kind_of aid = k)
        (Canary_artifact.ps_artifacts spec)
    with
    | Some aid -> Canary_artifact.ps_provisions_of spec aid
    | None -> []
  in
  (* tiny-full's real capability (its spec's ps_provisions_of is Vendored-only;
     the lib is also Built via the hand-built variants). *)
  let tiny_prov = function
    | Canary_basic.Lib -> Canary_enumerate.[ Vendored; Built ]
    | _ -> Canary_enumerate.[ Vendored ]
  in
  let run proj matched () =
    let vs = Canary_basic.[ Stable; Dev ] in
    let app_mode =
      if matched then Canary_action.Lockstep else Canary_action.Independent
    in
    match proj with
    | Some "sqlite" ->
        print_construction ~name:"sqlite" ~app_mode
          ~provisions_of_kind:(prov_of_spec Canary_project_sqlite.sqlite_spec)
          ~versions:vs
    | Some "tiny-full" ->
        print_construction ~name:"tiny-full" ~app_mode
          ~provisions_of_kind:tiny_prov ~versions:vs
    | _ ->
        Fmt.epr "usage: canary construct <tiny-full|sqlite> [--matched]@.";
        Stdlib.exit 2
  in
  Cmd.v
    (Cmd.info "construct"
       ~doc:
         "Show the forward graph construction: nodes generated by build/fetch \
          action-edges. Default shows the deploy-mismatch cartesian; --matched \
          shows the Lockstep chain. No run.")
    Term.(const run $ project $ matched $ const ())

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
        construct_cmd;
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
        emit_cmd;
        spec_cmd;
        spec_check_cmd;
        mutation_test_cmd;
        artifact_inspect_cmd;
        summary_diff_cmd;
        tiny_scenarios_cmd;
        compat_cmd;
        verify_cmd;
        index_cmd;
        result_cmd;
        prebuilt_cmd;
      ]
  in
  Stdlib.exit (Cmd.eval cmd)
