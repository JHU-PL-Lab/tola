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
  let disable_agreement_arg =
    Arg.(
      value & opt string ""
      & info [ "disable-agreement"; "disable-contract" ] ~docv:"CSV"
          ~doc:
            "Comma-separated agreements to skip for this run, by their \
             canonical names, e.g. \
             \"soname_matches_requirement,required_versions_exported\" \
             (`canary checks` lists them; the retired c1..c9 ids no \
             longer parse and are reported as unknown). Layered on top \
             of each project's runner_spec.disabled_agreements and the \
             registry's enabled flag. [--disable-contract] is kept as \
             an alias.")
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
  let run project _quick failfast disable_agreement_csv thin refs () =
    let root = "_out" in
    let cli_disabled, unknown_agreements =
      Canary_agreement_common.agreement_ids_of_csv disable_agreement_csv
    in
    (* an unrecognised name is REPORTED (2026-09-12). The old parser
       dropped it silently, so a run asking to skip "c5" skipped
       nothing and said nothing — and after the rename every old name
       is unrecognised. *)
    if unknown_agreements <> [] then
      Fmt.epr "[disable-agreement] unknown agreement(s): %s (see `canary checks`)@."
        (String.concat ", " unknown_agreements);
    if cli_disabled <> [] then
      Fmt.pr "[disable-agreement] skipping: %s@."
        (String.concat ", "
           (List.map Canary_agreement_common.string_of_agreement_id cli_disabled));
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
        { Canary_project_run.platform = Canary_store.platform ();
          policy = Canary_project_run.Thin;
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
        Canary_project_tiny.run_tiny_scenario ~root ~failfast
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
      const run $ project $ quick $ failfast
      $ disable_agreement_arg $ thin_arg $ refs_arg
      $ const ())

(* ── `canary emit` — one dump per pipeline pass (2026-08-24) ──
   design/enumeration/stage3_enumerate_worlds.md Attribution. THE rule: --stage N prints the value
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
             project_spec), 2 analyse (what canary understands of it — \
             the chains the spec admits, the mechanism each language \
             binds through, and which claims the project can carry), 3 \
             enumerate (the worlds the project HAS — \
             invocation-independent, --thin and --refs do not affect it), \
             4 select (the worlds this RUN asked for), 5 order (the run \
             order — 4 grouped by the store state each scenario locks; \
             since 2026-08-21 not the same order as 4), 6 realize (one \
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
            "--stage realize only: which scenario to realize (its \
             directory basename). Defaults to the first in run order.")
  in
  let run project stage json raw thin refs scenario () =
    let module P = Canary_pipeline in
    let module EN = Canary_enumerate in
    (* the CATALOGUE, not the active set: muting suppresses RUNNING, not
       inspecting, and a dump of a muted project is exactly when you want
       one (z3 is muted and is the richest spec we have). *)
    match List.assoc_opt project Canary_registry.all_specs with
    | None ->
        Fmt.epr "usage: canary emit <%s> --stage <1..6|name>@."
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
          | "2" | "analyse" | "analyze" -> `Analyse
          | "3" | "enumerate" -> `Enumerate
          | "4" | "select" -> `Select
          | "5" | "order" -> `Order
          | "6" | "realize" -> `Realize
          | other -> `Unknown other
        in
        let out j = print_string (Yojson.Basic.pretty_to_string j ^ "\n") in
        (match pass with
        | `Declare when json -> out (P.json_declare pr)
        | `Analyse when json -> out (P.json_analyse pr)
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
        | `Analyse ->
            let module A = Canary_project_analysis in
            let an = P.analysed_of pr in
            Fmt.pr "%s — 2 analyse: what canary understands@." project;
            (* the CHAINS first: this is the derivation that had no home
               until pass 2, and `canary paths` prints only the
               unfiltered 38 *)
            Fmt.pr "@.  chains admitted by the spec — %d of %d universal@."
              (List.length an.A.an_chains)
              (List.length Canary_enumerate.universal_chains);
            List.iter
              (fun c ->
                Fmt.pr "    %s@."
                  (String.concat " → "
                     (List.map
                        (fun (a : Canary_basic.action_sig) ->
                          Canary_basic.string_of_action a.Canary_basic.as_action)
                        c)))
              an.A.an_chains;
            (* THE JOIN — what each action touches, in this project's
               own artifact ids. `>` produces, `<` consumes, and the
               asymmetry is the point: a hook at `<action>_post` reads
               the `>` side, a precondition the `<` side. *)
            Fmt.pr "@.  actions × declared artifacts — %d in this \
                    project's vocabulary@."
              (List.length an.A.an_touches);
            List.iter
              (fun (act, (tc : A.touch)) ->
                let ids l =
                  match l with
                  | [] -> "-"
                  | xs ->
                      String.concat ","
                        (List.map Canary_artifact.string_of_id xs)
                in
                Fmt.pr "    %-24s < %-38s > %s@."
                  (Canary_basic.string_of_action act)
                  (ids tc.A.tc_consumes) (ids tc.A.tc_produces))
              an.A.an_touches;
            Fmt.pr "@.  bindings declared@.";
            List.iter
              (fun (l, m) ->
                Fmt.pr "    %-8s %s@." (Canary_lang.string_of_lang l)
                  (Canary_mechanism.string_of_mechanism m))
              an.A.an_mechanisms;
            Fmt.pr "@.  declared api: %s@."
              (match an.A.an_declared with None -> "none" | Some _ -> "yes");
            Fmt.pr "@.  claims this project can carry@.";
            List.iter
              (fun (l, slugs) ->
                Fmt.pr "    %-8s %d: %s@." (Canary_lang.string_of_lang l)
                  (List.length slugs)
                  (String.concat ", " slugs))
              an.A.an_carries;
            if not (List.is_empty an.A.an_unsuited) then begin
              Fmt.pr "@.  and what it cannot — %d@."
                (List.length an.A.an_unsuited);
              List.iter
                (fun (u : Canary_agreement.unsuited) ->
                  Fmt.pr "    %-28s %-8s %s@." u.Canary_agreement.us_slug
                    (Canary_lang.string_of_lang u.Canary_agreement.us_lang)
                    u.Canary_agreement.us_why)
                an.A.an_unsuited
            end
        | `Enumerate ->
            pp_assignments
              (project ^ " — 3 enumerate: worlds the project HAS")
              (P.worlds pr)
        | `Select ->
            let all = List.length (P.worlds pr) in
            let sel = P.enumerated ?policy pr in
            Fmt.pr "%s — 4 select: asked for %d of %d@." project
              (List.length sel) all;
            List.iter
              (fun a ->
                if raw then Fmt.pr "%s@." (Canary_artifact.show_assignment a)
                else Fmt.pr "  %s@." (EN.string_of_assignment a))
              sel
        | `Order ->
            let ordered = P.ordered ?policy pr in
            Fmt.pr "%s — 5 order: run order — %d@." project
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
                 Fmt.epr "no such scenario; run `canary emit %s --stage order`@."
                   project;
                 Stdlib.exit 2
             | Some a ->
                 let ctx = P.ctx_of pr a in
                 Fmt.pr "%s — 6 realize: steps@.  scenario %s@." project
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
               declare, 2 analyse, 3 enumerate, 4 select, 5 order, 6 \
               realize.@."
              n;
            Stdlib.exit 2)
  in
  Cmd.v
    (Cmd.info "emit"
       ~doc:
         "Print one pipeline pass's output (the value it hands the next \
          pass). See design/enumeration/stage3_enumerate_worlds.md Attribution.")
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
(* The checking index (2026-09-02): what a project checks, and where
   each check comes from — the sync point between the registry and a
   run. Static: no run needed. *)
let checks_cmd =
  let project =
    Arg.(value & pos 0 (some string) None & info [] ~docv:"PROJECT")
  in
  let firing =
    Arg.(value & flag & info [ "firing" ]
           ~doc:
             "Print the agreement × action FIRING TABLE instead of the \
              index — where each agreement takes effect, and whether \
              that cell ships a counterexample.")
  in
  let agreement =
    Arg.(value & opt (some string) None
         & info [ "agreement" ] ~docv:"NAME"
             ~doc:
               "The COMPLETE record of one agreement: what it claims, what \
                it is held against, where it looks in each world, what \
                falsifies it, what a pass does not establish, and whether \
                a real run has ever decided it. One place, generated from \
                the registry.")
  in
  let md =
    Arg.(value & flag & info [ "md" ]
           ~doc:"Emit markdown (with --catalogue: the generated catalogue file).")
  in
  let dummies =
    Arg.(value & flag & info [ "dummies" ]
           ~doc:
             "List every DUMMY ACTION across the registry's projects — a \
              step that holds a place in the action graph and performs \
              no work, with the reason it is empty. A dummy exists so \
              that evidence has somewhere to attach when an artifact \
              needs no installing; this is how they stay countable as \
              they accumulate.")
  in
  let landing =
    Arg.(value & flag & info [ "landing" ]
           ~doc:
             "The LANDING TRACKER: every agreement with its PLANNED \
              status (from the registry — does it have an evaluator, does \
              it ship a counterexample) beside its EFFECTIVE status (from \
              run logs — has a real project ever decided it). The two are \
              answered from different places and neither is derived from \
              the other.")
  in
  let observed =
    Arg.(value & flag & info [ "observed" ]
           ~doc:
             "Read the project's LAST RUN back: which agreements it \
              actually evaluated, and to what outcome. The index and the \
              firing table say what WOULD be checked; this says what did. \
              An agreement is concretely landed when a real run shows it \
              holds or violated.")
  in
  let catalogue =
    Arg.(value & flag & info [ "catalogue" ]
           ~doc:
             "Print the full CATALOGUE instead of the one-line table: \
              every agreement with its claim, the reference expectation \
              it is held against, and each checking method — what it \
              compares, where its evidence appears, whether it is \
              implemented, and what a pass does not establish.")
  in
  let frames =
    Arg.(value & flag & info [ "frames" ]
           ~doc:
             "Print the COLUMN MODEL the result table and the agreement \
              overview share (design/overview.md §6.4): one frame per \
              action as the overview's diagram draws it — what it \
              consumes, the checks on that input, the action's pieces, \
              what it produces, the checks on that — by side, then flow.")
  in
  (* `--topology` was DELETED 2026-09-23 (user): it printed the topology
     table the overview page already carries. The topologies are on
     `canary overview` §5. *)
  let run project firing catalogue observed landing dummies agreement md
      frames () =
    match (project, firing, catalogue) with
    | _, _, _ when frames -> Fmt.pr "%s@." (Canary_frames.pp ())
    | _, _, _ when Option.is_some agreement -> (
        let name = Option.get agreement in
        match Canary_agreement.agreement_named name with
        | None ->
            Fmt.epr "unknown agreement: %s@.known:@." name;
            List.iter
              (fun (r : Canary_agreement.agreement_row) ->
                Fmt.epr "  %s@." r.Canary_agreement.ag_slug)
              Canary_agreement.agreement_registry;
            Stdlib.exit 2
        | Some r ->
            Fmt.pr "%s@." (Canary_agreement.pp_agreement ~markdown:md r);
            (* the one thing the registry cannot know: what ran *)
            Fmt.pr "%s@."
              (Canary_status.pp_agreement_effective ~root:"_out" ~name))
    | _, _, true when md ->
        Fmt.pr "%s" (Canary_agreement.pp_catalogue_md ())
    | _, _, _ when dummies ->
        let names =
          match project with
          | Some p -> [ p ]
          | None -> List.map fst Canary_registry.all_projects
        in
        let rows =
          List.concat_map
            (fun name ->
              match List.assoc_opt name Canary_registry.all_projects with
              | None -> []
              | Some pr -> (
                  try
                    List.concat_map
                      (fun a ->
                        let ctx = Canary_pipeline.ctx_of pr a in
                        Canary_pipeline.steps_of ~root:"_out" pr ~ctx a
                        |> List.filter_map (fun (s : Canary_step_model.step) ->
                               match s.Canary_step_model.dummy with
                               | Some why ->
                                   Some (name, s.Canary_step_model.tag, why)
                               | None -> None))
                      (Canary_pipeline.ordered pr)
                  with _ -> []))
            names
          |> List.sort_uniq compare
        in
        if rows = [] then Fmt.pr "no dummy actions declared@."
        else begin
          Fmt.pr "DUMMY ACTIONS — a place in the graph with nothing to do@.";
          List.iter
            (fun (p, tag, why) -> Fmt.pr "  %-14s %-28s %s@." p tag why)
            rows;
          Fmt.pr "@.  %d dummy step(s).@." (List.length rows);
          Fmt.pr
            "  Each asserts there is genuinely nothing to do here, not that a \
             command is unwritten.@."
        end
    | _, _, _ when landing ->
        let projects =
          match project with Some p -> Some [ p ] | None -> None
        in
        Fmt.pr "%s@." (Canary_status.pp_landing ?projects ~root:"_out" ())
    | Some name, _, _ when observed ->
        Fmt.pr "%s@." (Canary_status.pp_observed ~root:"_out" ~project:name);
        (* the STATIC half: what this project cannot carry at all,
           derived from its spec rather than from the log, so a reader
           of "what ran" is never left thinking that was everything *)
        (match List.assoc_opt name Canary_registry.all_specs with
         | Some pr -> (
             match Canary_pipeline.unsuited_of pr with
             | [] -> ()
             | us ->
                 Fmt.pr
                   "@.  %d claim(s) this project cannot carry at all \
                    (from its spec, not from the run):@."
                   (List.length us);
                 List.iter
                   (fun (u : Canary_agreement.unsuited) ->
                     Fmt.pr "    %-28s [%s] %s@." u.Canary_agreement.us_slug
                       (Canary_lang.string_of_lang u.Canary_agreement.us_lang)
                       u.Canary_agreement.us_why)
                   us)
         | None -> ())
    | None, _, _ when observed ->
        List.iter
          (fun p ->
            Fmt.pr "%s@.@."
              (Canary_status.pp_observed ~root:"_out" ~project:p))
          (Canary_status.projects_with_runs ~root:"_out")
    | _, false, true -> Fmt.pr "%s@." (Canary_agreement.pp_catalogue ())
    | _, true, _ ->
        (* Appendix A.2 tells the reader to read this from the code
           rather than from a transcribed table; this is where. *)
        Fmt.pr "%s@." (Canary_agreement.pp_firing_table ());
        (* THE SAME GRID, ROOTED (2026-09-17, user). The firing table
           says where a check is DETECTED; this one puts the action
           whose rule was LOST on the same row, so the distance between
           them is visual rather than a column to look up. *)
        (* THE VERDICT FIRST (2026-09-21, user asked where the harness's
           checking result was). The audit and the saturation grid print
           their detail below; this says in one line whether the table
           passed its own laws, so a reader does not have to scroll past
           the data to find out. *)
        Fmt.pr "@.%s@." (Canary_agreement.overview_verdict ());
        Fmt.pr "@.%s@." (Canary_agreement.pp_agreement_overview ());
        (* THE CANDIDATES, in their own table (2026-09-17, user): they
           have no methods, so every column the overview derives would
           be blank. Name, kind, and what is in the way. *)
        Fmt.pr "@.%s@." (Canary_agreement.pp_candidate_table ());
        (* WHERE EVERY AGREEMENT SITS ON THE CHAIN (2026-09-27, user),
           candidates included — with how many some recorded run decided,
           read from the same logs as the result table *)
        Fmt.pr "@.%s@."
          (Canary_agreement_overview.pp_sittings
             (Canary_matrix.matrix_of Canary_registry.all_projects));
        (* THE SAME TOOLS THE `_ext` ROWS NAME, TRANSPOSED (2026-09-21,
           user: "It's also a good way to understand their roles"). The
           table reads by claim; this reads by tool, and carries what
           each does BEYOND the claim it is filed under. *)
        Fmt.pr "@.%s@." (Canary_agreement.pp_external_tools ());
        (* THE ROW AUDIT (2026-09-17, user: "I wish we can make a
           harness somewhere so you can check on your own"). Printed
           BESIDE the table it audits, because a reader checking a row
           is looking at the row; the same laws fail the build through
           `agreements.rows_obey_their_own_laws`. *)
        Fmt.pr "@.%s@." (Canary_agreement.pp_row_audit ());
        (* SATURATION — the question no ROW can ask: is any part of the
           modelled world unwatched? The overview is organised by claim,
           so an absence has no row to appear in. *)
        Fmt.pr "@.%s@." (Canary_agreement.pp_saturation ());
        let fill = Canary_agreement.fill_list () in
        Fmt.pr "@.fill list (%d cell(s) fire without a counterexample):@."
          (List.length fill);
        List.iter
          (fun (id, a) ->
            Fmt.pr "  %s @@ %s@."
              (Canary_agreement_common.string_of_agreement_id id)
              (Canary_basic.string_of_action a))
          fill
    | None, false, false ->
        (* no project: the registry itself *)
        Fmt.pr "%s@." (Canary_agreement.pp_agreements ())
    | Some name, false, false -> (
        (* THE CATALOGUE, NOT THE ACTIVE LIST (2026-09-15). A muted
           project is muted because a RUN of it is expensive, which says
           nothing about whether its checking should be readable —
           `spec-check` and `emit` both made that distinction already
           and this one had not. It mattered: z3 is the project with the
           most hand-written checking in the registry and `canary checks
           z3` answered "unknown project", so the one coverage report
           that would have said so could not be pointed at it. Its index
           is static anyway; the run-log column is simply empty until
           somebody unmutes it. *)
        match List.assoc_opt name Canary_registry.all_specs with
        | Some pr ->
            let idx = Canary_check_index.of_project pr in
            Fmt.pr "%s@." (Canary_check_index.pp pr idx);
            if not (Canary_registry.is_active name) then
              Fmt.pr
                "  NOTE: %s is MUTED out of the run set, so the decided \
                 column reads its last recorded run (if any) and not a \
                 current one.@."
                name
        | None ->
            Fmt.epr "usage: canary checks [<%s>]@."
              (String.concat "|" (List.map fst Canary_registry.all_specs));
            Stdlib.exit 2)
  in
  Cmd.v
    (Cmd.info "checks"
       ~doc:
         "The checking index: with no argument, every agreement the \
          registry declares; with --catalogue, each one's reference \
          expectation and checking methods in full; with a project, the \
          checks that apply to each of its actions, where each comes \
          from, and what the recorded runs decided there — ending in a \
          COULD DECIDE vs DID DECIDE summary whose gap rows are the work \
          queue. No execution.")
    Term.(const run $ project $ firing $ catalogue $ observed $ landing
          $ dummies $ agreement $ md $ frames $ const ())

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
    (* the CATALOGUE, not the active list (2026-08-25): spec-check is a
       CHECKING command and muting a project removes it from the RUN set,
       not from the audit — the same rule [spec_check.ratchet_current]
       already states and `emit` already follows. Before this, `spec-check
       z3` answered "usage:" while the pin happily audited z3, so the
       project with the richest matrix was the one a human could not
       dump. *)
    match proj with
    | Some "@all" | None ->
        let reports =
          List.map (fun (_n, pr) -> Canary_spec_check.check pr)
            Canary_registry.all_specs
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
        match List.assoc_opt name Canary_registry.all_specs with
        | Some pr ->
            let r = Canary_spec_check.check pr in
            show r;
            if has_errors r then Stdlib.exit 1
        | None ->
            Fmt.epr "usage: canary spec-check <@all|%s>@."
              (String.concat "|" (List.map fst Canary_registry.all_specs));
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
                   let m = Canary_mechanism.mechanism_of_lang_exn l in
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
       ~doc:"Regenerate a run's diagrams from its saved run_state.json")
    Term.(const run $ project $ const ())

let write_workflow out name yaml =
  ignore (Stdlib.Sys.command (Fmt.str "mkdir -p %s" out));
  let path = out ^ "/" ^ name in
  let oc = Stdlib.open_out path in
  Stdlib.output_string oc yaml;
  Stdlib.close_out oc;
  Fmt.pr "Wrote %s@." path

(* `cache-sync` LIVED HERE and was deleted 2026-09-16 (user). It read a
   GH Actions run's per-step conclusions into a JSON keyed
   "<cache_project>:<step_name>", which [run_step] consulted to skip
   work CI had certified. It could not produce a hit — the keys it wrote
   came from the CI job specs, the only callers that override
   [cache_project], while a local run uses the per-scenario default — so
   the two key spaces had been disjoint since A5 (2026-08-05). See the
   header comment in [Canary_local_runner] for the other three findings
   and for what a cross-machine cache would have to be instead. *)

let ci_cmd =
  let out =
    Arg.(
      value
      & opt string ".github/workflows"
      & info [ "out"; "o" ] ~docv:"DIR"
          ~doc:
            "Output directory for generated YAML (default: .github/workflows)")
  in
  (* THE MINIMAL UBUNTU WORKFLOW (2026-08-27) — the recovery starts here.
     Rendered from the LIVE pipeline (Canary_ci) rather than from the
     legacy per-project *_ci_spec values, which is what let the sqlite job
     lose its binding half unnoticed. Separate file, so recovering CI
     cannot clobber the 5-job canary_ci.yml while it is still the record
     of what once passed. *)
  let min_flag =
    Arg.(
      value & flag
      & info [ "min" ]
          ~doc:
            "Write canary_min.yml instead: the minimal ubuntu workflow \
             (sqlite + cairo, all-Fetched world each), rendered from the \
             live pipeline.")
  in
  let run out min () =
    if min then
      let pick n =
        match List.assoc_opt n Canary_registry.all_specs with
        | Some pr -> [ (n, pr) ]
        | None -> Fmt.epr "canary ci --min: unknown project %s@." n; []
      in
      (* THE PIPELINE-RENDERED SET (2026-08-28). Started as sqlite +
         cairo to prove the shape; now every project whose cheapest world
         is reachable on a runner, which is what retires the pre-A5
         canary_ci.yml one job at a time.

         z3 is OUT deliberately: it is muted locally because a full run
         rebuilds libz3 on every binding pin flip (~30 min), and a CI job
         would do the same on a cold runner. llvm is IN — its all-Fetched
         world is apt llvm-19-dev plus an opam binding, no source build. *)
      let yaml, shells =
        Canary_ci.render_minimal
          (pick "sqlite" @ pick "cairo" @ pick "zarith" @ pick "libffi"
         @ pick "zlib" @ pick "zstd" @ pick "ssl" @ pick "llvm")
      in
      write_workflow out "canary_min.yml" yaml;
      (* the shell twins live in _out (generated, gitignored): they are a
         debugging aid for running a CI job locally, not a tracked
         artifact. *)
      let sh_dir = "_out/canary/ci" in
      ignore (Stdlib.Sys.command (Fmt.str "mkdir -p %s" sh_dir) : int);
      List.iter
        (fun (id, body) ->
          let path = sh_dir ^ "/" ^ id ^ ".sh" in
          let oc = Stdlib.open_out path in
          Stdlib.output_string oc body;
          Stdlib.close_out oc;
          ignore (Stdlib.Sys.command (Fmt.str "chmod +x %s" path) : int);
          Fmt.pr "Wrote %s@." path)
        shells
    else begin
      let distro = detect_distro () in
      Canary_project_z3.render_opam_in ~tola_root:".";
      write_workflow out "canary_ci.yml"
        (Canary_run.render_ci ~root:"_out" distro)
    end
  in
  Cmd.v
    (Cmd.info "ci" ~doc:"Generate GH Actions workflow YAML")
    Term.(const run $ out $ min_flag $ const ())

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
       _out/canary/projects/<project>/<variant>/.
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
      | Some s, Some l -> Canary_agreement_report.run ~stub_path:s ~lib_path:l
      | _ -> (
          match project with
          | None ->
              Fmt.epr
                "compat: pass either <project> [<variant>] or both --stub and \
                 --lib@.";
              2
          | Some p ->
              let root = Stdlib.Sys.getcwd () in
              Canary_agreement_report.run_for_project ~root ~project:p ~variant)
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
    Stdlib.exit (Canary_agreement_report.verify_for_project ~root ~project ~variant)
  in
  Cmd.v
    (Cmd.info "verify"
       ~doc:
         "Cross-reference cached compat predictions against probe.log \
          outcomes. Reports per-layer prediction-vs-observation alignment.")
    Term.(const run $ project $ variant $ const ())

(* THE OVERVIEW PAGE (2026-09-23, user: "the page contains more material
   than `canary checks --topology` suggests"). It holds the layered chain,
   the concrete cases, the agreement overview, the claim census and the
   cooperation topologies — so it gets a command named for the page, and
   the file is named for it too (docs/canary/overview.html; was
   model.html). `checks --topology` printed the topology table again and
   was deleted the same day; its two footnotes moved onto the page.

   Named `overview` rather than `theory`: `agreement/theory.md` already
   owns that word for the argument about what an agreement recovers, and
   this page is a map generated from code — the next thing it is meant to
   carry is recorded run results, which is the opposite of theory.

   ⚠ TWO PROJECT LISTS, deliberately. The agreement overview's `decided`
   and `blame` columns are counted from recorded runs, and they were
   counted over the ACTIVE list when the table lived on the result page,
   so they still are — reading the catalogue would have added muted z3's
   stale logs to every count and changed a table this move was meant to
   leave alone. The topologies read DECLARATIONS, where muting must not
   hide a project, so they use the catalogue.

   THE ONE RESULTS COMMAND (2026-09-28, user: "can we keep use one
   command e.g. overview"). `canary result` folded in here: its `--json`
   is this command's, and its text and markdown tables went. They drew
   the result matrix's old layout — a world per row, a check at its slot
   — so keeping them meant a second table to keep in step with §1.2,
   which is why the matrix's page retired. *)
let overview_cmd =
  let project =
    Arg.(
      value
      & pos 0 (some string) None
      & info [] ~docv:"PROJECT"
          ~doc:
            "With --json, the project to restrict the record to (default: \
             every registry project). The page always covers them all.")
  in
  let json =
    Arg.(
      value & flag
      & info [ "json" ]
          ~doc:
            "Print the RUN RECORD as JSON instead of writing the page: \
             typed columns, and per cell the step's state (ran/warm/\
             blocked/unrecorded), the agreement outcome, and when the log \
             recorded it; per row the platform the run logged, its steps, \
             edges, claims and chains. Stdout carries the JSON and nothing \
             else, and nothing is written.")
  in
  let flow =
    Arg.(
      value & flag
      & info [ "flow" ]
          ~doc:
            "Print §5 of the page instead of writing it: the figure's boxes \
             and arrows, each subject's code and running layers with the \
             sections that show them, and the page's sections with the \
             template slots and modules behind each.")
  in
  let run project json flow () =
    if flow then print_string (Canary_overview_flow.text ())
    else if json then begin
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
      (* THE RUN RECORD (2026-09-23, status.md §2.7 phase A): the JSON
         and nothing else on stdout — the page notice used to follow it,
         so no consumer could parse the output (finding 1). *)
      print_string
        (Canary_matrix.json_export (Canary_matrix.matrix_of projects))
    end
    else begin
      (match project with
       | Some p ->
           Fmt.epr
             "canary overview: the page covers every project; a project \
              (%s) narrows only --json@."
             p;
           Stdlib.exit 2
       | None -> ());
      let now =
        let tm = Unix.localtime (Unix.gettimeofday ()) in
        Printf.sprintf "%04d-%02d-%02d %02d:%02d" (tm.tm_year + 1900)
          (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min
      in
      let m = Canary_matrix.matrix_of Canary_registry.all_projects in
      let overview = Canary_agreement_overview.render m in
      Canary_overview_page.write Canary_registry.all_specs ~overview
        ~generated_at:now;
      Fmt.pr "wrote %s@." Canary_overview_page.docs_path;
      Fmt.pr "wrote %s/{%s} (pointers to its §1.2)@."
        Canary_overview_page.pointer_dir
        (String.concat "," Canary_overview_page.pointer_files);
      (* the recorded worlds, beside the page and never inside it
         (status.md §2.7 phase C) — the tracked copy only when this
         machine is rendering itself *)
      Fmt.pr "wrote %s@." (Canary_overview_runs.write m ~generated_at:now)
    end
  in
  Cmd.v
    (Cmd.info "overview"
       ~doc:
         "Render the OVERVIEW page (docs/canary/overview.html): the layered \
          chain from the package managers down to the running program, \
          the result table (§1.2), the agreement overview, where every \
          claim sits and which relations carry none, and the cooperation \
          topologies. Also writes this machine's recorded worlds \
          (docs/canary/overview_runs.js, _mac on macOS), which §1 and §1.2 \
          draw, and the pointers that keep the retired result page's \
          addresses (docs/canary/projects/) landing on §1.2. With --json, \
          prints the run record instead and writes nothing; with --flow, \
          prints §5, how the page is made. Runs nothing.")
    Term.(const run $ project $ json $ flow $ const ())

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
           ~cli_disabled:[] ~name:sc.name ()
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

(* THE SWITCH OVERRIDE (2026-08-26). Canary defaults to its own opam
   switch (Canary_store.opam_switch) so that a pin flip cannot damage the
   switch a person works in. The selection applies to EVERY subcommand,
   so it is handled before cmdliner dispatches rather than declared on
   each of the ~28 commands:

     --switch NAME | --switch=NAME   run in NAME
     --switch=                       run in the ambient switch (pre-2026-08-26)
     CANARY_SWITCH=NAME              same, for Makefile targets

   The flag is REMOVED from argv before cmdliner sees it — cmdliner
   rejects unknown options, so a pre-scan alone is not enough (it sets
   the ref and then the run dies on "unknown option"). An unknown NAME is
   an opam error at the first command, never a silent fallback to the
   wrong store. *)
let set_switch v =
  Canary_store.opam_switch := (if String.equal v "" then None else Some v)

(* THE PLATFORM OVERRIDE (2026-08-26, user: "the canary config should
   carry the platform argument"). Same shape as [--switch], and for the
   same reason: it applies to EVERY subcommand, so it is consumed before
   cmdliner dispatches rather than declared on each of the ~28 commands.

     --platform NAME | --platform=NAME   run AS this platform
     CANARY_PLATFORM=NAME                same, for Makefile targets

   NAME is macos | wsl (with the obvious aliases). What it is FOR is not
   pretending to be another machine — the tools do not change — but
   making the platform an argument the run states rather than a fact it
   sniffs: dumps (`spec`, `emit`, `spec-check`) can then be rendered for
   EITHER platform from one machine, which is how a WSL reviewer checks
   what the mac will do without owning a mac. A bad name is a hard error
   rather than a silent fall back to detection. *)
let set_platform v =
  match Canary_store.platform_of_string (String.lowercase_ascii v) with
  | Some d -> Canary_store.set_platform d
  | None ->
      Fmt.epr "canary: unknown --platform %s (want: macos | wsl)@." v;
      Stdlib.exit 2

(* STRICT MODE (2026-09-15). Third flag of the same shape, and for the
   same reason: it is a property of the INVOCATION, not of a project or
   a subcommand, and a run that dumps (`emit`, `overview --json`) should report
   the same mode the run that executed was in.

     --strict              a detected disagreement fails the step
     CANARY_STRICT=1       same, for Makefile targets

   The policy it changes is documented where the flag lives
   (Canary_agreement_common.strict_mode). It is off by default on
   purpose — see there. *)
let set_strict v =
  match String.lowercase_ascii v with
  | "" | "1" | "true" | "yes" | "on" -> Canary_agreement_common.set_strict true
  | "0" | "false" | "no" | "off" -> Canary_agreement_common.set_strict false
  | other ->
      Fmt.epr "canary: unknown --strict %s (want: 1 | 0)@." other;
      Stdlib.exit 2

let switch_argv () : string array =
  (match Stdlib.Sys.getenv_opt "CANARY_SWITCH" with
   | Some v -> set_switch v
   | None -> ());
  (match Stdlib.Sys.getenv_opt "CANARY_PLATFORM" with
   | Some v -> set_platform v
   | None -> ());
  (match Stdlib.Sys.getenv_opt "CANARY_STRICT" with
   | Some v -> set_strict v
   | None -> ());
  let argv = Stdlib.Sys.argv in
  let n = Array.length argv in
  let keep = ref [] in
  let i = ref 0 in
  let starts_with a p =
    String.length a >= String.length p
    && String.equal (String.sub a 0 (String.length p)) p
  in
  while !i < n do
    let a = argv.(!i) in
    let is_eq = starts_with a "--switch=" in
    let is_plat_eq = starts_with a "--platform=" in
    let is_strict_eq = starts_with a "--strict=" in
    if String.equal a "--strict" then (
      (* a BARE flag, unlike the other two: [--strict] takes no value,
         so the next argv word must not be eaten (`--strict sqlite`). *)
      set_strict "";
      Stdlib.incr i)
    else if is_strict_eq then (
      set_strict (String.sub a 9 (String.length a - 9));
      Stdlib.incr i)
    else if String.equal a "--switch" && !i + 1 < n then (
      set_switch argv.(!i + 1);
      i := !i + 2)
    else if is_eq then (
      set_switch (String.sub a 9 (String.length a - 9));
      Stdlib.incr i)
    else if String.equal a "--platform" && !i + 1 < n then (
      set_platform argv.(!i + 1);
      i := !i + 2)
    else if is_plat_eq then (
      set_platform (String.sub a 11 (String.length a - 11));
      Stdlib.incr i)
    else (
      keep := a :: !keep;
      Stdlib.incr i)
  done;
  Array.of_list (List.rev !keep)

(* VALIDATE THE SWITCH ONCE, AT STARTUP (2026-08-26).

   The prologue alone is not enough, and a falsification run showed why:
   with a bad name, `eval $(opam env)` gets empty stdout (opam writes the
   error to stderr and exits non-zero), `eval ""` SUCCEEDS, PATH is left
   ambient — and the command runs happily in whatever switch was already
   active. The error is printed but nothing stops, so `artifact-test
   --switch=no-such-switch` reported "zarith found" and 30/30 PASS while
   testing the wrong toolchain. That is the "a check that did not check"
   class of landing.md §4, arriving in the switch mechanism itself.

   One check here turns a typo into a refusal instead of a silent
   fallback, and it costs a single `opam var` per invocation. *)
let validate_switch () =
  match !Canary_store.opam_switch with
  | None -> ()
  | Some name ->
      (* `opam env --switch=X` exits 2 on an unknown switch. NOT
         `opam var --switch=X prefix`, which merely COMPUTES a path and
         returns 0 for any name at all — measured while writing this. *)
      let rc =
        Stdlib.Sys.command
          (Printf.sprintf "opam env --switch=%s > /dev/null 2>&1"
             (Stdlib.Filename.quote name))
      in
      if rc <> 0 then (
        Fmt.epr "canary: opam switch %S does not exist.@." name;
        Fmt.epr
          "  create it:                 opam switch create %s \
           ocaml-base-compiler.5.4.1 --no-switch@."
          name;
        Fmt.epr "  or pick another:           --switch=NAME@.";
        Fmt.epr "  or use the ambient one:    --switch=@.";
        Stdlib.exit 2)

(* THE MACHINES (2026-08-26, user: "this can be almost hardcoded in the
   entry side once as the config value choice for two of my machines. It
   shouldn't be hardcoded any more").

   The two boxes canary runs on, and the ONE place their roots are
   written. Everything below a machine root is relative and derived:
   [contrib_root] is [<root>/contrib], a source checkout is
   [<contrib_root>/<project>-all/<repo>], and a [local_path] row carries
   only its relative part until someone asks for a string.

   BOTH rows are declared, not just this machine's, because
   [--platform=macos] renders the mac's paths from the WSL box — a root
   read from [$HOME] could only answer for the box you are sitting at.
   Adding a third machine is one row here.

   Set FIRST, before argv is even scanned: nothing resolves a root at
   module-initialization time any more, but the flags parsed on the next
   line can select which machine we answer as. *)
let machines : (Canary_store.distro * string) list =
  [ (Canary_store.Wsl, "/home/red/code");
    (Canary_store.MacOS_local, "/Users/ex/code") ]

let () =
  Canary_store.set_machine_roots machines;
  let argv = switch_argv () in
  validate_switch ();
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
        pm_test_cmd;
        artifact_test_cmd;
        project_test_cmd;
        cache_test_cmd;
        emit_cmd;
        spec_cmd;
        checks_cmd;
        spec_check_cmd;
        mutation_test_cmd;
        artifact_inspect_cmd;
        summary_diff_cmd;
        tiny_scenarios_cmd;
        compat_cmd;
        verify_cmd;
        overview_cmd;
        prebuilt_cmd;
      ]
  in
  Stdlib.exit (Cmd.eval ~argv cmd)
