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

let prov_short : Canary_enumerate.provision -> string = function
  | Canary_enumerate.Vendored -> "V"
  | Canary_enumerate.Built -> "B"
  | Canary_enumerate.Fetched -> "F"
  | Canary_enumerate.Absent -> "A"

let placement_str (pl : Canary_enumerate.placement) =
  Printf.sprintf "%s:%s" (prov_short pl.provision)
    (Canary_enumerate.string_of_build_id pl.version)

(* The all-good baseline of an enumerated scenario set (the assignment every
   delta is measured against). *)
let baseline_of (scenarios : Canary_enumerate.assignment list) =
  try List.find Canary_tiny_scenario.assignment_is_all_good scenarios
  with Not_found -> ( match scenarios with a :: _ -> a | [] -> [])

(* The delta-from-baseline label for a scenario — the JOIN KEY between the pre
   view (`spec`) and the persisted post view (the run summary). Same string in
   both so a scenario can be looked up across pre/post. *)
let scenario_label ~baseline (a : Canary_enumerate.assignment) : string =
  let baseline_str id =
    match Canary_enumerate.placement_of baseline id with
    | Some pl -> placement_str pl
    | None -> "\xE2\x80\x94"
  in
  let deltas =
    List.filter_map
      (fun (id, pl) ->
        let s = placement_str pl in
        if String.equal (baseline_str id) s then None
        else Some (Printf.sprintf "%s=%s" (Canary_enumerate.pretty_id id) s))
      a
  in
  match deltas with [] -> "(baseline)" | _ -> String.concat "  " deltas

(* Per-scenario run summary (F1): one line per scenario, TAB-separated
   [verdict \t good|bad \t label]. Written by [run_project_run], read by
   [print_spec] to annotate the pre view with post verdicts. Sibling of
   run_state.json (which is per-step and overwritten per scenario). *)
let scenario_summary_path_of ~project =
  [%string "_out/canary/projects/%{project}/-run/scenarios.tsv"]

(* A born-safe per-SCENARIO directory: the identity of ONE assignment (one
   placement per artifact). It is what the runner uses for the scenario's output
   dir AND its dedup key — computed generically here, no longer a project field.

   IDENTITY RULE (general, from provision semantics): a [Fetched] artifact is
   version-AMBIENT — the PM decides the concrete version — so its declared
   version is dropped from the id; [Built]/[Vendored] versions ARE identity
   (canary produces/supplies exactly that version). Two scenarios with the same
   id are the same real world → they dedup to one run. (A project that pins a
   Fetched version would override via its provider [pr_provenance]; not needed
   yet — see status §A.) *)
let scenario_dir_of ~pr_name (a : Canary_enumerate.assignment) : string =
  let chan_s = function
    | Canary_basic.Stable -> "stable"
    | Canary_basic.Dev -> "dev"
  in
  let part (id, (pl : Canary_enumerate.placement)) =
    let k =
      String.map (function ':' -> '-' | c -> c)
        (Canary_basic.string_of_artifact_kind (Canary_enumerate.kind_of id))
    in
    match pl.Canary_enumerate.provision with
    | Canary_store.Fetched -> Printf.sprintf "%s-fetched" k
    | prov ->
        Printf.sprintf "%s-%s-%s" k
          (Canary_store.string_of_provision prov)
          (chan_s pl.Canary_enumerate.version.Canary_enumerate.channel)
  in
  (* sort_uniq → a CANONICAL id: identical parts (same-kind artifacts at the
     same placement — e.g. two app wirings both vendored) collapse, and order is
     stable. Uniqueness is preserved (differing placements keep distinct parts). *)
  Printf.sprintf "_out/canary/scenarios/%s/%s" pr_name
    (String.concat "_" (List.sort_uniq compare (List.map part a)))

(* The GENERIC project runner (convergence step 2). Consumes a [project_run]
   and does the SAME loop for any project: enumerate → runner_spec → run →
   report. All project-specific logic lives in the closures (a real project's
   runner_spec build/fetches; tiny-full's runner_spec assembles its vendored
   tree internally — the tiny-factory concern, invisible here). Additive —
   z3/llvm keep their raw-script [run_project_multi]; this drives tiny-full and
   simple projects. Dedup + output dir keyed by [scenario_dir_of] (several
   assignments can share one scenario identity — e.g. Fetched across versions). *)
let run_project_run ?policy (pr : Canary_project_run.project_run) ~root
    ~failfast : unit =
  Fmt.pr "@.%s — generic project run (enumerate → runner_spec → run)@."
    pr.Canary_project_run.pr_name;
  (* THE general algorithm: the runner enumerates the project's declared
     [pr_spec] under the exploration [policy] (full by default; `--thin` =
     [Canary_project_run.thin_policy]). Projects hand over no scenario list. *)
  let scenarios = Canary_project_run.scenarios_of ?policy pr in
  let baseline = baseline_of scenarios in
  let seen = ref [] in
  (* (key, verdict, is_bad, xfail-step tags) — key = scenario_label. The
     xfail list is where a world DETECTED a mismatch: steps that passed via a
     confirmed expected failure ([Step_done_xfail]). *)
  let results = ref [] in
  List.iter
    (fun a ->
      let ws = scenario_dir_of ~pr_name:pr.Canary_project_run.pr_name a in
      if List.mem ws !seen then ()
      else begin
          seen := ws :: !seen;
          let is_bad = not (Canary_tiny_scenario.assignment_is_all_good a) in
          let key = scenario_label ~baseline a in
          (* [scenario_dir_of] is already born-safe; keep the map defensively. *)
          let safe =
            String.map
              (function ':' | '#' | '+' -> '-' | c -> c)
              (Filename.basename ws)
          in
          let project = pr.Canary_project_run.pr_name ^ "/" ^ safe in
          let spec = pr.Canary_project_run.pr_runner_spec a ~workspace:ws in
          let steps =
            Canary_step_builder.derive_steps ~root ~project
              ~langs:Canary_lang.[ OCaml; Python ] spec
          in
          (* verdict from the RETURNED status table — robust against the shared
             run_state.json being overwritten by the next scenario. On FAIL,
             name the non-done steps (diagnostic); on PASS, name the steps
             that passed via a CONFIRMED expected failure ([Step_done_xfail]
             — where the world DETECTED a mismatch). *)
          let verdict, culprits, xfails =
            try
              let status =
                run_with_info_status ~failfast ~cache_path:None ~root ~project
                  steps
                  (prebuilt_run_info ~project:pr.Canary_project_run.pr_name
                     ~version:"scenario" ~extra:[] steps)
              in
              let not_done =
                List.filter_map
                  (fun (s : Canary_step_model.step) ->
                    match Base.Hashtbl.find status s.tag with
                    | Some (Canary_step_model.Step_done
                           | Canary_step_model.Step_done_xfail) -> None
                    | Some Canary_step_model.Step_failed -> Some (s.tag ^ ":failed")
                    | Some Canary_step_model.Step_skipped -> Some (s.tag ^ ":skipped")
                    | None -> Some (s.tag ^ ":not_run"))
                  steps
              in
              let xfails =
                List.filter_map
                  (fun (s : Canary_step_model.step) ->
                    match Base.Hashtbl.find status s.tag with
                    | Some Canary_step_model.Step_done_xfail -> Some s.tag
                    | _ -> None)
                  steps
              in
              if not_done = [] then ("PASS", "", xfails)
              else ("FAIL", String.concat " " not_done, xfails)
            with _ -> ("FAIL", "exn", [])
          in
          Fmt.pr "  [%-44s] %-6s %s%s%s@." safe verdict
            (if is_bad then "(bad)" else "(good)")
            (match xfails with
             | [] -> ""
             | xs -> "  xfail: " ^ String.concat "," xs)
            (if String.equal verdict "FAIL" && not (String.equal culprits "")
             then "  <- " ^ culprits else "");
          results := (key, verdict, is_bad, xfails) :: !results
      end)
    scenarios;
  let bads = List.filter (fun (_, _, b, _) -> b) !results in
  let detected =
    List.length (List.filter (fun (_, v, _, _) -> String.equal v "PASS") bads)
  in
  Fmt.pr "@.  coverage: %d/%d bad scenarios detected (generic runner)@."
    detected (List.length bads);
  (let n_xfail_worlds =
     List.length (List.filter (fun (_, _, _, xs) -> xs <> []) !results)
   in
   if n_xfail_worlds > 0 then
     Fmt.pr "  mismatch scenarios: %d passed via confirmed expected failure (xfail)@."
       n_xfail_worlds);
  (* F1: persist the per-scenario verdicts so a post view can annotate the
     `spec` (pre) listing. One TAB-separated line per scenario that RAN
     (deduped workspaces are omitted → shown "·" in the post view). Format:
     verdict TAB good|bad TAB xfail-steps(comma, "-" if none) TAB label —
     label LAST so older 3-field files still parse (see load_scenario_post). *)
  (let path = scenario_summary_path_of ~project:pr.Canary_project_run.pr_name in
   try
     let oc = open_out path in
     List.iter
       (fun (key, verdict, is_bad, xfails) ->
         Printf.fprintf oc "%s\t%s\t%s\t%s\n" verdict
           (if is_bad then "bad" else "good")
           (match xfails with [] -> "-" | xs -> String.concat "," xs)
           key)
       (List.rev !results);
     close_out oc
   with Sys_error _ -> () (* run dir may not exist on a no-op run; non-fatal *))

(* Coarse artifact GROUP for the spec listing (ssot §4.2 kinds). *)
let group_of_kind : Canary_basic.artifact_kind -> string = function
  | Canary_basic.Source -> "source"
  | Canary_basic.Headers | Canary_basic.Lib -> "native"
  | Canary_basic.Binding _ -> "bindings"
  | Canary_basic.App -> "app"

let group_order = [ "source"; "native"; "bindings"; "app" ]

(* Load the persisted per-scenario run summary (F1) as a [label -> (verdict,
   is_bad, xfail_steps)] map — the POST view joined to the pre listing by
   [scenario_label]. [xfail_steps] = comma-joined step tags that passed via a
   confirmed expected failure ("" if none). [] when no run has happened. *)
let load_scenario_post ~project : (string * (string * bool * string)) list =
  let path = scenario_summary_path_of ~project in
  if not (Sys.file_exists path) then []
  else
    let ic = open_in path in
    let rec loop acc =
      match input_line ic with
      | line -> (
          match String.split_on_char '\t' line with
          | verdict :: bad :: xf :: rest when rest <> [] ->
              (* current 4-field format: label LAST (no tabs in labels; be
                 defensive and rejoin) *)
              let label = String.concat "\t" rest in
              let xf = if String.equal xf "-" then "" else xf in
              loop ((label, (verdict, String.equal bad "bad", xf)) :: acc)
          | verdict :: bad :: [ label ] ->
              (* legacy 3-field format (pre-xfail column) *)
              loop ((label, (verdict, String.equal bad "bad", "")) :: acc)
          | _ -> loop acc)
      | exception End_of_file ->
          close_in ic;
          acc
    in
    loop []

(* POST view of a scenario's built-lib NATIVE WATCHLIST (the per-version
   symbol watchlist): read the build_lib inspect JSON the run produced for
   this scenario's variant key, and summarize present/missing. None = no
   inspect ran (no run yet, or the project attaches none). *)
let lib_watchlist_post ~pr_name (a : Canary_enumerate.assignment) :
    (int * string list) option =
  let safe =
    String.map
      (function ':' | '#' | '+' -> '-' | c -> c)
      (Filename.basename (scenario_dir_of ~pr_name a))
  in
  let path =
    Printf.sprintf "_out/canary/projects/%s/build_lib/inspect_%s.json" pr_name
      safe
  in
  if not (Sys.file_exists path) then None
  else
    try
      let j = Yojson.Basic.from_file path in
      let open Yojson.Basic.Util in
      let w = j |> member "watchlist" in
      let strs k = w |> member k |> to_list |> List.map to_string in
      Some (List.length (strs "present"), strs "missing")
    with _ -> None

(* The binding languages a project's artifacts span. *)
let langs_of arts =
  List.filter_map
    (fun a ->
      match Canary_enumerate.kind_of a with
      | Canary_basic.Binding l -> Some l
      | _ -> None)
    arts
  |> List.sort_uniq compare

(* What an artifact KIND can be USED TO BUILD — from the action catalogue:
   the products of every Build action that CONSUMES this kind. *)
let builds_of_kind ~langs k =
  (Canary_basic.[ Build_lib; Build_headers ]
  @ List.concat_map
      (fun l -> Canary_basic.[ Build_binding l; Build_app { lang = l } ])
      langs)
  |> List.concat_map (fun act ->
         if List.mem k (Canary_action.consumes_of_action act) then
           Canary_action.produces_of_action act
         else [])
  |> List.sort_uniq compare

let builds_of ~langs a = builds_of_kind ~langs (Canary_enumerate.kind_of a)

let langs_of_kinds kinds =
  List.filter_map
    (function Canary_basic.Binding l -> Some l | _ -> None)
    kinds
  |> List.sort_uniq compare

let kinds_string ks =
  String.concat ", " (List.map Canary_basic.string_of_artifact_kind ks)

(* Snapshot of a [project_run]: declared artifacts (grouped, each with its
   baseline provision@version) + the enumerated scenarios as deltas from that
   baseline. PRE (dry-run — no [pr_runner_spec]/run is invoked). If a run summary
   exists, each scenario is also annotated with its last-run verdict (POST):
   good ✓/✗REGRESSED, bad ✓detected/✗missed, · = not run (deduped workspace). *)
let print_spec ?policy (pr : Canary_project_run.project_run) : unit =
  let module E = Canary_enumerate in
  let scenarios = Canary_project_run.scenarios_of ?policy pr in
  let all_good = Canary_tiny_scenario.assignment_is_all_good in
  let baseline = baseline_of scenarios in
  let baseline_str id =
    match E.placement_of baseline id with
    | Some pl -> placement_str pl
    | None -> "\xE2\x80\x94" (* em dash *)
  in
  let post = load_scenario_post ~project:pr.Canary_project_run.pr_name in
  Fmt.pr "@.spec: %s — %s@." pr.Canary_project_run.pr_name
    (if post = [] then "enumeration (no run yet)"
     else "enumeration + last-run verdicts");
  (* artifacts, grouped, each with its baseline provision@version, the
     project-declared provenance detail, and what it can BUILD (derived from the
     action catalogue: which Build actions consume this kind → what they produce). *)
  let arts = pr.Canary_project_run.pr_artifacts in
  let langs = langs_of arts in
  let builds_of a = builds_of ~langs a in
  Fmt.pr "@.artifacts (%d), by group [baseline provision@@version + provenance]:@."
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
          (fun a ->
            Fmt.pr "    %-26s %s@." (E.pretty_id a) (baseline_str a);
            (match Canary_project_run.provenance_of pr a with
             | Some p ->
                 (* drift check: the provider's coarse provision must equal the
                    baseline's — if not, the declared detail contradicts the
                    axis. Skipped for an artifact the enumeration doesn't
                    place (baseline "—"): a display-only artifact (e.g. the
                    source behind a self-contained Built lib) has no axis to
                    contradict. *)
                 let drift =
                   match E.placement_of baseline a with
                   | None -> ""
                   | Some _ ->
                       if
                         Canary_store.equal_provision
                           (Canary_store_config.provision_of_provider p)
                           (E.provision_of baseline a)
                       then ""
                       else "   ⚠ provider≠baseline provision"
                 in
                 Fmt.pr "        provider: %s%s@."
                   (Canary_store_config.string_of_provider p) drift
             | None ->
                 Fmt.pr "        provider: (undeclared — spec carries no detail)@.");
            List.iter
              (fun (id, ch, dir) ->
                if E.equal_artifact_id id a then
                  Fmt.pr "        mismatch probe: %s variant designed to reveal %s mismatch@."
                    (match ch with
                     | Canary_basic.Dev -> "dev"
                     | Canary_basic.Stable -> "stable")
                    (E.string_of_mismatch_direction dir))
              pr.Canary_project_run.pr_mismatch_probes;
            match builds_of a with
            | [] -> ()
            | ks ->
                Fmt.pr "        builds → %s@."
                  (String.concat ", "
                     (List.map Canary_basic.string_of_artifact_kind ks)))
          in_grp
      end)
    group_order;
  (* The WORLDS, each in FULL flat form (the assignment the run walks): one
     placement per artifact identity — this is the enumerated object itself,
     not a delta. Cross-instance combinations (two libs in one world = the
     build-lib ≠ run-lib mismatch) are NOT expressible here — that is the
     node-graph enumeration (`construct`, close_deps). Annotated with the
     last-run verdict where a run summary exists (join by [scenario_label]). *)
  let ngood = List.length (List.filter all_good scenarios) in
  let total = List.length scenarios in
  Fmt.pr
    "@.scenarios — %d enumerated (%d good, %d bad); ONE placement per artifact \
     (the flat assignment the run walks):@."
    total ngood (total - ngood);
  Fmt.pr
    "  key: F=fetched (a PM provides the consumable artifact — apt ships a \
     binary, opam BUILDS the package source at install; version ambient, the \
     PM picks)@.       B=built (canary builds it — version IS identity)  \
     V=vendored (supplied local artifact — version IS identity)@.";
  List.iter
    (fun a ->
      let label = scenario_label ~baseline a in
      let is_bad = not (all_good a) in
      let mark =
        match List.assoc_opt label post with
        | Some ("PASS", _, xf) when not (String.equal xf "") ->
            (* the world PASSED via a confirmed expected failure — a
               DETECTED mismatch (the xfail steps name where) *)
            "✓ xfail"
        | Some ("PASS", _, _) -> if is_bad then "✓ detected" else "✓"
        | Some (_, _, _) -> if is_bad then "✗ missed" else "✗ REGRESSED"
        | None -> if post = [] then " " else "·"
      in
      let world =
        String.concat "  "
          (List.map
             (fun (id, pl) ->
               Printf.sprintf "%s=%s" (E.pretty_id id) (placement_str pl))
             a)
      in
      (* designed-probe mark: a declared (consumer, channel, direction) probe
         is ACTIVE in this scenario when the consumer is placed at that
         channel AND the computed consumer↔lib pairing direction matches. *)
      let probe_marks =
        List.filter_map
          (fun (id, ch, dir) ->
            let placed =
              match E.placement_of a id with
              | Some pl -> pl.E.version.E.channel = ch
              | None -> false
            in
            if
              placed
              && E.mismatch_direction_of a ~consumer:id ~provider:E.a_lib
                 = Some dir
            then Some (E.string_of_mismatch_direction dir)
            else None)
          pr.Canary_project_run.pr_mismatch_probes
      in
      let watchlist_note =
        match lib_watchlist_post ~pr_name:pr.Canary_project_run.pr_name a with
        | None -> ""
        | Some (npresent, []) ->
            Printf.sprintf "   [lib watchlist: %d/%d]" npresent npresent
        | Some (npresent, missing) ->
            Printf.sprintf "   [lib watchlist: %d present, missing %s]"
              npresent (String.concat "," missing)
      in
      Fmt.pr "  %-10s %s%s%s%s@." mark world
        (match probe_marks with
         | [] -> ""
         | ms -> "   [" ^ String.concat "+" ms ^ "-mismatch probe]")
        watchlist_note
        (if String.equal label "(baseline)" then "   (baseline)" else ""))
    scenarios;
  (if post <> [] then begin
     let bads = List.filter (fun (_, (_, b, _)) -> b) post in
     let detected =
       List.length
         (List.filter (fun (_, (v, _, _)) -> String.equal v "PASS") bads)
     in
     let xfail_worlds =
       List.filter (fun (_, (_, _, xf)) -> not (String.equal xf "")) post
     in
     Fmt.pr "  last run (`action %s`): %d/%d bad detected · %d scenario(s) ran.@."
       pr.Canary_project_run.pr_name detected (List.length bads)
       (List.length post);
     List.iter
       (fun (label, (_, _, xf)) ->
         Fmt.pr "    xfail %s — %s@." xf
           (if String.equal label "(baseline)" then "(baseline)" else label))
       xfail_worlds
   end);
  Fmt.pr
    "@.  note: this is the DECLARED artifact set + the scenarios the general \
     algorithm (enumerate over `pr_spec`) \
     produces. The run executes exactly these (each via derive_steps → the full \
     source→lib→binding→probe chain); `construct %s` shows the wider applicable \
     graph these are drawn from. Use `spec %s --by-artifact` for the per-artifact \
     cut.@."
    pr.Canary_project_run.pr_name pr.Canary_project_run.pr_name

(* Is artifact [id] DIRECTLY mutated (Bad quality) in scenario [a]? *)
let artifact_bad_in (a : Canary_enumerate.assignment)
    (id : Canary_enumerate.artifact_id) : bool =
  match Canary_enumerate.placement_of a id with
  | Some { version = { quality = Canary_enumerate.Bad _; _ }; _ } -> true
  | _ -> false

(* F3 — the ARTIFACT-centric dual of [print_spec]: for each artifact, the
   scenarios that directly mutate it (with post verdict + a per-artifact
   detection rate), then a compact count of scenarios that mutate an UPSTREAM
   artifact (this one is downstream-affected). Same pre/post join by
   [scenario_label]. Rows = artifacts, whereas [print_spec]'s rows = scenarios. *)
let print_artifacts ?policy (pr : Canary_project_run.project_run) : unit =
  let module E = Canary_enumerate in
  let scenarios = Canary_project_run.scenarios_of ?policy pr in
  let baseline = baseline_of scenarios in
  let post = load_scenario_post ~project:pr.Canary_project_run.pr_name in
  let verdict a = List.assoc_opt (scenario_label ~baseline a) post in
  let is_detected a =
    match verdict a with Some ("PASS", _, _) -> true | _ -> false
  in
  let bads =
    List.filter
      (fun a -> not (Canary_tiny_scenario.assignment_is_all_good a))
      scenarios
  in
  Fmt.pr "@.artifacts: %s — %s (scenarios that touch each)@."
    pr.Canary_project_run.pr_name
    (if post = [] then "enumeration (no run yet)"
     else "enumeration + last-run verdicts");
  List.iter
    (fun grp ->
      let in_grp =
        List.filter
          (fun id -> String.equal (group_of_kind (E.kind_of id)) grp)
          pr.Canary_project_run.pr_artifacts
      in
      if in_grp <> [] then begin
        Fmt.pr "  %s:@." grp;
        List.iter
          (fun id ->
            let ord = Canary_basic.kind_order (E.kind_of id) in
            let direct = List.filter (fun a -> artifact_bad_in a id) bads in
            let upstream =
              List.filter
                (fun a ->
                  List.exists
                    (fun (other, (pl : E.placement)) ->
                      Canary_basic.kind_order other.E.kind < ord
                      && match pl.version.quality with E.Bad _ -> true | _ -> false)
                    a)
                bads
            in
            let rate =
              if post = [] then ""
              else
                Printf.sprintf " · %d/%d detected"
                  (List.length (List.filter is_detected direct))
                  (List.length direct)
            in
            let up =
              if upstream = [] then ""
              else Printf.sprintf " · +%d upstream" (List.length upstream)
            in
            Fmt.pr "    %-26s %d mutated%s%s@." (E.pretty_id id)
              (List.length direct) rate up;
            List.iter
              (fun a ->
                let mark =
                  match verdict a with
                  | None -> if post = [] then "" else "·"
                  | Some ("PASS", _, _) -> "✓ detected"
                  | Some _ -> "✗ missed"
                in
                Fmt.pr "      %-46s %s@." (scenario_label ~baseline a) mark)
              direct)
          in_grp
      end)
    group_order;
  Fmt.pr
    "@.  legend: N mutated = scenarios with THIS artifact at a Bad version; \
     +M upstream = scenarios mutating an upstream artifact (downstream-affected); \
     ✓ detected / ✗ missed / · not run.@."

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

(* Machine-readable `spec --json`: the same artifacts × scenarios, parseable.
   Reuses the exact pre/post data print_spec renders (same [scenario_label] join,
   same catalogue [builds_of], same typed provider) — a second projection, not a
   second source of truth. *)
let spec_json_t ?policy (pr : Canary_project_run.project_run) : Yojson.Basic.t =
  let module E = Canary_enumerate in
  let scenarios = Canary_project_run.scenarios_of ?policy pr in
  let baseline = baseline_of scenarios in
  let all_good = Canary_tiny_scenario.assignment_is_all_good in
  let post = load_scenario_post ~project:pr.Canary_project_run.pr_name in
  let langs = langs_of pr.Canary_project_run.pr_artifacts in
  let verdict a = List.assoc_opt (scenario_label ~baseline a) post in
  let artifact_json a =
    `Assoc
      [ ("id", `String (E.pretty_id a));
        ("group", `String (group_of_kind (E.kind_of a)));
        ( "provision",
          `String
            (Canary_store.string_of_provision (E.provision_of baseline a)) );
        ("version", `String (E.string_of_build_id (E.version_of baseline a)));
        ( "provider",
          match Canary_project_run.provenance_of pr a with
          | Some p -> `String (Canary_store_config.string_of_provider p)
          | None -> `Null );
        ( "builds",
          `List
            (List.map
               (fun k -> `String (Canary_basic.string_of_artifact_kind k))
               (builds_of ~langs a)) ) ]
  in
  let scenario_json a =
    let good = all_good a in
    let fields =
      [ ("good", `Bool good); ("label", `String (scenario_label ~baseline a)) ]
      @
      match verdict a with
      | None -> []
      | Some (v, _, xf) ->
          ("verdict", `String v)
          :: (if String.equal xf "" then []
              else [ ("xfail", `String xf) ])
          @ (if good then [] else [ ("detected", `Bool (String.equal v "PASS")) ])
    in
    `Assoc fields
  in
  `Assoc
    [ ("project", `String pr.Canary_project_run.pr_name);
      ("kind", `String "project_run");
      ( "artifacts",
        `List (List.map artifact_json pr.Canary_project_run.pr_artifacts) );
      ("scenarios", `List (List.map scenario_json scenarios)) ]

(* All artifact kinds any variant provisions, group-ordered (dedup, first seen). *)
let variant_kinds variants =
  List.fold_left
    (fun acc (_, _, rs) ->
      List.fold_left
        (fun acc (k, _) -> if List.mem k acc then acc else acc @ [ k ])
        acc
        (provisions_of_runner_spec rs))
    [] variants

(* A source artifact = a configured repo: what it BUILDS (has_build_* flags). *)
let source_repo_builds (src : Canary_artifact_source.source_repo) : string list =
  (if src.Canary_artifact_source.has_build_lib then [ "lib" ] else [])
  @ (if src.Canary_artifact_source.has_build_binding then [ "binding" ] else [])

let source_repo_url (src : Canary_artifact_source.source_repo) : string =
  let (Canary_artifact_source.Git_remote url) = src.Canary_artifact_source.remote in
  url

(* Variant view for projects that expose raw [runner_spec]s per source variant
   (z3/llvm) instead of a [project_run] — now UNIFORM with print_spec: a source
   artifact is shown as a configured repo (+ what it builds), and each artifact
   shows its provision per variant + what it can build (action catalogue). The
   runner is untouched — this only READS the source_repo + runner_spec. (The
   deeper unification — a `Source_repo` provider variant so z3/llvm expose
   `pr_provenance` like project_run — is a to-do; status §F.) *)
let print_spec_variants ~(name : string)
    ~(variants :
       (string * Canary_artifact_source.source_repo
       * Canary_step_builder.runner_spec)
       list) : unit =
  let module E = Canary_enumerate in
  let vnames = List.map (fun (v, _, _) -> v) variants in
  Fmt.pr
    "@.spec: %s — scenario view (raw runner_spec, not project_run; %d source \
     configs: %s)@."
    name (List.length variants) (String.concat ", " vnames);
  (* artifacts — grouped, per-variant provision + builds. The SOURCE artifact
     shows its configured repo per variant (a source artifact = a repo), so
     source appears as one artifact group — uniform with print_spec. *)
  let all_kinds = variant_kinds variants in
  let langs = langs_of_kinds all_kinds in
  Fmt.pr "@.artifacts (%d), by group [provision per scenario: %s]:@."
    (List.length all_kinds) (String.concat "|" vnames);
  List.iter
    (fun grp ->
      let in_grp =
        List.filter (fun k -> String.equal (group_of_kind k) grp) all_kinds
      in
      if in_grp <> [] then begin
        Fmt.pr "  %s:@." grp;
        List.iter
          (fun k ->
            let cells =
              List.map
                (fun (_, _, rs) ->
                  match List.assoc_opt k (provisions_of_runner_spec rs) with
                  | Some p -> prov_short p
                  | None -> "·")
                variants
            in
            let builds = builds_of_kind ~langs k in
            Fmt.pr "    %-22s %s%s@." (E.pretty_artifact k)
              (String.concat "|" cells)
              (match builds with
               | [] -> ""
               | bs -> "     builds → " ^ kinds_string bs);
            match k with
            | Canary_basic.Source ->
                List.iter
                  (fun (vname, src, _) ->
                    Fmt.pr "        [%-6s] provider: source repo: %s%s@." vname
                      (Canary_store_config.string_of_source_repo src)
                      (match source_repo_builds src with
                       | [] -> "  (fetches lib+binding)"
                       | bs -> "  builds " ^ String.concat ", " bs))
                  variants
            | _ -> ())
          in_grp
      end)
    group_order;
  Fmt.pr
    "@.  legend: V=vendored B=built F=fetched A=absent · = not in that scenario \
     · columns = %s@."
    (String.concat "|" vnames);
  Fmt.pr
    "  note: the version-mismatch these projects test lives in the probe \
     EXPECTATION (not shown); fetched-artifact package detail is in shell \
     closures (coarse here).@."

(* JSON form of the variant view (z3/llvm) — for `spec @all --json`. *)
let spec_variants_json_t ~(name : string)
    ~(variants :
       (string * Canary_artifact_source.source_repo
       * Canary_step_builder.runner_spec)
       list) : Yojson.Basic.t =
  let module E = Canary_enumerate in
  let all_kinds = variant_kinds variants in
  let langs = langs_of_kinds all_kinds in
  `Assoc
    [ ("project", `String name);
      ("kind", `String "variants");
      ( "source_repos",
        `List
          (List.map
             (fun (vname, src, _) ->
               `Assoc
                 [ ("variant", `String vname);
                   ("name", `String src.Canary_artifact_source.name);
                   ("version", `String src.Canary_artifact_source.version);
                   ("ref", `String src.Canary_artifact_source.ref_);
                   ("remote", `String (source_repo_url src));
                   ( "builds",
                     `List
                       (List.map (fun s -> `String s) (source_repo_builds src))
                   ) ])
             variants) );
      ( "artifacts",
        `List
          (List.map
             (fun k ->
               `Assoc
                 [ ("id", `String (E.pretty_artifact k));
                   ("group", `String (group_of_kind k));
                   ( "builds",
                     `List
                       (List.map
                          (fun bk ->
                            `String (Canary_basic.string_of_artifact_kind bk))
                          (builds_of_kind ~langs k)) ) ])
             all_kinds) );
      ( "variants",
        `List
          (List.map
             (fun (vname, _, rs) ->
               `Assoc
                 [ ("name", `String vname);
                   ( "provisions",
                     `List
                       (List.map
                          (fun (k, p) ->
                            `Assoc
                              [ ("artifact", `String (E.pretty_artifact k));
                                ( "provision",
                                  `String (Canary_store.string_of_provision p)
                                ) ])
                          (provisions_of_runner_spec rs)) ) ])
             variants) ) ]

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
  (* run_z3 (raw-script run_project_multi over 2 hand-derived variants)
     retired 2026-08-05, A5 phase 2 — `action z3` now goes through the
     generic [run_project_run] over [Canary_project_z3.z3_run] (enumerate →
     dispatch/realize → derive_steps → run). Casualties of the migration:
     the z3-only `--quick` (no_source) and `--cache-path`/`--disable-contract`
     plumbing, which the generic path doesn't carry (same as sqlite). *)
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
  (* [_quick] (skip source fetch) was consumed only by the retired run_z3;
     the flag stays parsed so existing invocations don't break. *)
  let run project _quick failfast cache_path disable_contract_csv thin () =
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
    | Some "z3" ->
        (* z3 on the generic path (A5 phase 2): enumerate z3_spec →
           dispatch/realize → run. --thin = the runner's Subset[Stable]
           policy (drops the dev chain), free on any project_run. *)
        if thin then
          run_project_run
            ~policy:(Canary_project_run.thin_policy ())
            (Canary_project_z3.z3_run distro) ~root ~failfast
        else run_project_run (Canary_project_z3.z3_run distro) ~root ~failfast
    | Some "llvm" -> run_llvm ~root ~failfast ~cache_path ~cli_disabled distro
    | Some "tiny-full" ->
        (* the generic project runner drives tiny-full (convergence step 2);
           --thin = the RUNNER's thin_policy over the same declared spec
           (plus the thin-named run for cache separation) *)
        if thin then
          run_project_run
            ~policy:(Canary_project_run.thin_policy ())
            Canary_project_tiny.tiny_full_thin_run ~root ~failfast
        else begin
          Canary_project_tiny.print_view ();
          run_project_run Canary_project_tiny.tiny_full_run ~root ~failfast
        end
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
        run_project_run (Canary_project_z3.z3_run distro) ~root ~failfast;
        run_llvm ~root ~failfast ~cache_path ~cli_disabled distro
    | Some p ->
        Fmt.pr
          "Unknown project: %s (available: sqlite, zarith, ssl, cairo, z3, llvm, tiny-full, tiny/<scenario>)@." p
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
      & info [] ~docv:"PROJECT"
          ~doc:"Project to snapshot: @all (default) | tiny-full | sqlite | z3 | llvm")
  in
  let thin =
    Arg.(value & flag & info [ "thin" ] ~doc:"project_run projects (tiny-full, z3): the thin Subset[Stable] enumeration.")
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
            "Emit JSON (machine-readable; supersedes --by-artifact). With @all, \
             one object keyed by project — the refactor cross-check.")
  in
  let run proj thin by_artifact json () =
    let d = lazy (detect_distro ()) in
    (* each variant carries its source_repo (a source artifact = a configured
       repo) so the viewer can show it uniformly; the runner is unchanged.
       (z3 left this view 2026-08-05, A5 phase 2 — it is a project_run now;
       llvm follows in phase 5, then print_spec_variants retires.) *)
    let llvm_variants () =
      let d = Lazy.force d in
      let mk s = (s.Canary_artifact_source.version, s, Canary_project_llvm.mk_runner_spec ~source:s d) in
      [ mk Canary_project_llvm.llvm_source_dev; mk Canary_project_llvm.llvm_source_stable ]
    in
    let show ?policy pr =
      if json then
        print_string
          (Yojson.Basic.pretty_to_string (spec_json_t ?policy pr) ^ "\n")
      else if by_artifact then print_artifacts ?policy pr
      else print_spec ?policy pr
    in
    let show_variants name variants =
      if json then
        print_string
          (Yojson.Basic.pretty_to_string (spec_variants_json_t ~name ~variants)
          ^ "\n")
      else print_spec_variants ~name ~variants
    in
    match proj with
    | Some "tiny-full" ->
        if thin then
          show
            ~policy:(Canary_project_run.thin_policy ())
            Canary_project_tiny.tiny_full_thin_run
        else show Canary_project_tiny.tiny_full_run
    | Some "sqlite" -> show Canary_project_sqlite.sqlite_run
    | Some "z3" ->
        (* the generic project_run view (A5 phase 2); --thin works here as
           on any project_run *)
        if thin then
          show
            ~policy:(Canary_project_run.thin_policy ())
            (Canary_project_z3.z3_run (Lazy.force d))
        else show (Canary_project_z3.z3_run (Lazy.force d))
    | Some "llvm" -> show_variants "llvm" (llvm_variants ())
    | Some "@all" | None ->
        (* every project's spec in one command — the refactor cross-check *)
        let prs =
          [ Canary_project_tiny.tiny_full_run; Canary_project_sqlite.sqlite_run;
            Canary_project_z3.z3_run (Lazy.force d) ]
        in
        let vs = [ ("llvm", llvm_variants ()) ] in
        if json then
          let projects =
            List.map (fun pr -> spec_json_t pr) prs
            @ List.map (fun (n, v) -> spec_variants_json_t ~name:n ~variants:v) vs
          in
          print_string
            (Yojson.Basic.pretty_to_string (`Assoc [ ("projects", `List projects) ])
            ^ "\n")
        else begin
          List.iter show prs;
          List.iter (fun (n, v) -> print_spec_variants ~name:n ~variants:v) vs
        end
    | _ ->
        Fmt.epr "usage: canary spec <@@all|tiny-full|sqlite|z3|llvm>@.";
        Stdlib.exit 2
  in
  Cmd.v
    (Cmd.info "spec"
       ~doc:"Dry-run snapshot: declared artifacts (grouped) + enumerated \
             scenarios (project_run: tiny-full/sqlite) or per-scenario \
             provisions (raw runner_spec: z3/llvm). No execution.")
    Term.(const run $ project $ thin $ by_artifact $ json $ const ())

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
                ( Printf.sprintf "union of %d scenario(s)"
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
                match pt.mutations with [] -> Some pt.assignment | _ -> None)
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
       ~doc:"Test project-definition layers (action consumes/produces, \
             detection inventory) + live project-spec pins (z3) — pure, \
             hermetic, no PM/build.")
    (term_of (fun () ->
         let ok =
           Canary_project_test.run_tests ~extra:Canary_projects_test.tests ()
         in
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
  Fmt.pr "@.graph construction: %s (source versions: %s; app runtime = %s)@." name
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
                      rl.CA.version) -> "   ⚠ DEPLOY MISMATCH"
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
  let total = List.fold_left (fun acc (_, ns) -> acc + List.length ns) 0 g.CA.pools in
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
      value & pos 0 (some string) None
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
  let prov_of_spec (spec : Canary_enumerate.project_spec)
      (k : Canary_basic.artifact_kind) : Canary_store.provision list =
    match
      List.find_opt
        (fun aid -> Canary_enumerate.kind_of aid = k)
        (Canary_enumerate.ps_artifacts spec)
    with
    | Some aid -> Canary_enumerate.ps_provisions_of spec aid
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
