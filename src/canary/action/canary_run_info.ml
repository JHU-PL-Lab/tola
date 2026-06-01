(** [Canary_run_info] — run metadata, run-state persistence, and the
    high-level [run_project] / [run_project_multi] orchestrators.

    Split from [Canary_action] on 2026-06-01 (Phase 6 of the post-audit
    refactor). The low-level runner — [run_step], [run_graph],
    [merge_step_statuses] — stays in [Canary_action] because it is the
    runtime primitive used by everything; this module sits one layer up
    and packages "execute the steps + dump info + save state + render
    HTML+Mermaid + close logger" into the single entry point project
    drivers actually call.

    What lives here:
    - [type run_info]: project metadata (version, ref, env) dumped at
      run start.
    - [detect_env], [mk_run_info], [dump_run_info], [dump_run_info_multi]:
      construction + serialisation of [run_info].
    - [save_run_state], [load_run_state]: round-trip the per-step
      success/failure verdict to [run_state.json] so [view_project]
      can regenerate diagrams without re-executing.
    - [view_project]: rebuild outputs from saved state.
    - [run_project], [run_project_multi]: top-level orchestrators
      callers in [canary_main.ml] invoke. *)

open Base
open Canary_basic
open Canary_step_model
open Canary_local_runner

(* ── Run info: project metadata dumped at start of run ── *)

type run_info = {
  project : string;
  version : string;
  ref_ : string;
  source : string;       (* "local:<path>" or "git:<url>" or "prebuilt" *)
  distro : string;
  system_pm : string;
  opam_switch : string;
  ocaml_version : string;
  actions : string list;  (* tags of enabled action steps *)
  extra : (string * string) list;  (* project-specific key-value pairs *)
}

let detect_env () =
  let chomp s = String.rstrip s in
  let cmd_output cmd =
    try
      let ic = Unix.open_process_in cmd in
      let s = Stdlib.input_line ic in
      ignore (Unix.close_process_in ic);
      chomp s
    with _ -> ""
  in
  let distro = match Stdlib.Sys.command "uname -s 2>/dev/null | grep -q Darwin" with
    | 0 -> "macos"
    | _ -> "linux"
  in
  let system_pm = Canary_store.string_of_pm (Canary_store.detect_pm ())
  in
  let opam_switch = cmd_output "opam switch show 2>/dev/null" in
  let ocaml_version = cmd_output "ocamlopt -version 2>/dev/null" in
  (distro, system_pm, opam_switch, ocaml_version)

let mk_run_info ~project ~version ~ref_ ~source ?(extra = []) (steps : action_step list) =
  let distro, system_pm, opam_switch, ocaml_version = detect_env () in
  { project; version; ref_; source;
    distro; system_pm; opam_switch; ocaml_version;
    actions = List.map steps ~f:(fun s -> s.tag);
    extra;
  }

let dump_run_info ?(filename = "run_info") ~dir (info : run_info) =
  let path = [%string "%{dir}/%{filename}.json"] in
  let oc = Stdlib.open_out path in
  let q s = Stdlib.Printf.sprintf "\"%s\"" s in
  let list_json items =
    List.map items ~f:q |> String.concat ~sep:", "
  in
  let extra_json =
    List.map info.extra ~f:(fun (k, v) ->
        Stdlib.Printf.sprintf "    %s: %s" (q k) (q v))
    |> String.concat ~sep:",\n"
  in
  Stdlib.Printf.fprintf oc
    "{\n\
    \  \"project\": %s,\n\
    \  \"version\": %s,\n\
    \  \"ref\": %s,\n\
    \  \"source\": %s,\n\
    \  \"distro\": %s,\n\
    \  \"system_pm\": %s,\n\
    \  \"opam_switch\": %s,\n\
    \  \"ocaml_version\": %s,\n\
    \  \"timestamp\": %s,\n\
    \  \"actions\": [%s]%s\n\
     }\n"
    (q info.project) (q info.version) (q info.ref_)
    (q info.source) (q info.distro) (q info.system_pm)
    (q info.opam_switch) (q info.ocaml_version)
    (q (now ())) (list_json info.actions)
    (if List.is_empty info.extra then ""
     else Stdlib.Printf.sprintf ",\n  \"extra\": {\n%s\n  }" extra_json);
  Stdlib.close_out oc;
  path

(* ── Run-state serialisation ──
   Saves per-step verdicts so [view_project] can rebuild diagrams +
   HTML without re-executing. The runtime closures ([cmd], [check_pre],
   [check_post]) aren't serialised; on load they default to stubs that
   refuse to run. *)

let save_run_state ~dir ~project_name steps
    ?(artifact_name : (artifact_kind -> string option) = fun _ -> None)
    (run_status : (string, step_status) Hashtbl.t) =
  let path = [%string "%{dir}/run_state.json"] in
  let step_json (s : action_step) =
    let expect_str = match s.expectation with
      | Expect_success          -> "success"
      | Expect_failure _        -> "failure"
      | Expect_compat_failure _ -> "compat_failure"
    in
    let status_str = match Hashtbl.find run_status s.tag with
      | Some Step_done    -> "done"
      | Some Step_failed  -> "failed"
      | Some Step_skipped -> "skipped"
      | None              -> "not_run"
    in
    `Assoc [
      ("tag",        `String s.tag);
      ("output_tag", `String s.output_tag);
      ("rule",       `String (string_of_rule s.rule));
      ("variant_id", `String s.variant_id);
      ("expect",     `String expect_str);
      ("status",     `String status_str);
    ]
  in
  let kind_name k = string_of_artifact_kind k in
  let artifact_names_json =
    [ Lib; Binding Canary_lang.OCaml; Binding Canary_lang.Python ]
    |> List.filter_map ~f:(fun k ->
        match artifact_name k with
        | Some n -> Some (`Assoc [("kind", `String (kind_name k)); ("name", `String n)])
        | None -> None)
  in
  let json = `Assoc [
    ("project_name",    `String project_name);
    ("steps",           `List (List.map steps ~f:step_json));
    ("artifact_names",  `List artifact_names_json);
  ] in
  let oc = Stdlib.open_out path in
  Yojson.Basic.pretty_to_channel oc json;
  Stdlib.output_char oc '\n';
  Stdlib.close_out oc

let load_run_state ~dir =
  let path = [%string "%{dir}/run_state.json"] in
  let j = Yojson.Basic.from_file path in
  let open Yojson.Basic.Util in
  let project_name = j |> member "project_name" |> to_string in
  let step_of_json sj =
    let str k = sj |> member k |> to_string in
    let tag        = str "tag" in
    let output_tag = str "output_tag" in
    let rule_str   = str "rule" in
    let variant_id = str "variant_id" in
    let expect_str = str "expect" in
    let status_str = str "status" in
    let rule = match Canary_basic.rule_of_string rule_str with
      | Some r -> r
      | None   -> failwith [%string "load_run_state: unknown rule %{rule_str}"]
    in
    let expectation = match expect_str with
      | "success"        -> Expect_success
      | "failure"        -> Expect_failure { contains_any = []; version_info = None }
      | "compat_failure" ->
          Expect_compat_failure { inputs = []; version_info = None }
      | s -> failwith [%string "load_run_state: unknown expect %{s}"]
    in
    let output_dir =
      [%string "%{dir}/%{Canary_output_path.step_dir_of_tag output_tag}"]
    in
    let step : action_step = {
      tag; cache_key = ""; output_tag; output_dir;
      project_dir = dir; variant_id; rule; deps = [];
      cmd          = (fun ~output_dir:_ ~variant_key:_ -> "");
      check_pre    = (fun () -> false);
      check_post   = (fun ~output_dir:_ ~variant_key:_ -> false);
      expectation; symbol_check = None;
    } in
    (step, status_str)
  in
  let pairs = j |> member "steps" |> to_list |> List.map ~f:step_of_json in
  let steps = List.map pairs ~f:fst in
  let run_status = Hashtbl.create (module String) in
  List.iter pairs ~f:(fun (s, st) ->
      match st with
      | "done"    -> Hashtbl.set run_status ~key:s.tag ~data:Step_done
      | "failed"  -> Hashtbl.set run_status ~key:s.tag ~data:Step_failed
      | "skipped" -> Hashtbl.set run_status ~key:s.tag ~data:Step_skipped
      | _         -> ());
  let artifact_names =
    try
      let an_json = j |> member "artifact_names" |> to_list in
      let pairs = List.filter_map an_json ~f:(fun a ->
          let kind_str = a |> member "kind" |> to_string in
          let name = a |> member "name" |> to_string in
          match kind_str with
          | "lib" -> Some (Canary_basic.Lib, name)
          | "ocaml_binding" -> Some (Canary_basic.Binding Canary_lang.OCaml, name)
          | "python_binding" -> Some (Canary_basic.Binding Canary_lang.Python, name)
          | _ -> None)
      in
      fun k -> List.Assoc.find pairs ~equal:Poly.equal k
    with _ -> fun _ -> None
  in
  (project_name, steps, run_status, artifact_names)

(* Regenerate diagrams/ and result.html from a saved run_state.json without
   re-running any steps. Equivalent to the tail of run_project/run_project_multi. *)
let view_project ~root ~project () =
  let (project_name, _variant) =
    match String.rsplit2 project ~on:'/' with
    | Some (n, v) -> (n, v)
    | None        -> (project, "")
  in
  let dir = [%string "%{root}/canary/projects/%{project_name}"] in
  let run_dir = [%string "%{dir}/-run"] in
  let (_, steps, run_status, artifact_names) = load_run_state ~dir:run_dir in
  let log_path = [%string "%{run_dir}/actions.log"] in
  let logger = create_logger ~log_path in
  Canary_diagram.write_project_output ~dir ~project_name ~variant:"" ~steps ~run_status
    ~artifact_names ~root logger;
  logger.close ()

let run_project ?(failfast = false) ?run_info ?cache_path
    ?(artifact_names : artifact_kind -> string option = fun _ -> None)
    ~root ~project steps =
  let (project_name, variant_id) =
    match String.rsplit2 project ~on:'/' with
    | Some (name, vid) -> (name, vid)
    | None -> (project, "")
  in
  let dir = [%string "%{root}/canary/projects/%{project_name}"] in
  ensure_dir dir;
  let run_dir = [%string "%{dir}/-run"] in
  ensure_dir run_dir;
  Option.iter run_info ~f:(fun info ->
      let path = dump_run_info ~dir:run_dir info in
      Fmt.pr "[run_info] %s@." path);
  let global_cache = Option.map cache_path ~f:(fun p -> Canary_step_cache.load ~path:p) in
  let log_path = [%string "%{run_dir}/actions.log"] in
  let logger = create_logger ~log_path in
  let status = run_graph ~failfast ?global_cache logger ~project ~root steps in
  Canary_diagram.write_project_output ~dir ~project_name ~variant:variant_id ~steps
    ~run_status:status ~artifact_names ~root logger;
  save_run_state ~dir:run_dir ~project_name steps ~artifact_name:artifact_names status;
  logger.close ()

(* Write a single run_info.json covering all variants of a multi-variant run.
   Format: { "project": ..., "variants": [ { "id": ..., <run_info fields> }, ... ] } *)
let dump_run_info_multi ~dir ~project_name
    (variant_infos : (string * run_info) list) =
  let path = [%string "%{dir}/run_info.json"] in
  let oc = Stdlib.open_out path in
  let q s = Stdlib.Printf.sprintf "\"%s\"" s in
  let variant_json (id, info) =
    let list_json items = List.map items ~f:q |> String.concat ~sep:", " in
    let extra_json =
      List.map info.extra ~f:(fun (k, v) ->
          Stdlib.Printf.sprintf "      %s: %s" (q k) (q v))
      |> String.concat ~sep:",\n"
    in
    Stdlib.Printf.sprintf
      "    {\n\
      \      \"id\": %s,\n\
      \      \"version\": %s,\n\
      \      \"ref\": %s,\n\
      \      \"source\": %s,\n\
      \      \"distro\": %s,\n\
      \      \"system_pm\": %s,\n\
      \      \"opam_switch\": %s,\n\
      \      \"ocaml_version\": %s,\n\
      \      \"timestamp\": %s,\n\
      \      \"actions\": [%s]%s\n\
      \    }"
      (q id) (q info.version) (q info.ref_) (q info.source)
      (q info.distro) (q info.system_pm) (q info.opam_switch)
      (q info.ocaml_version) (q (now ())) (list_json info.actions)
      (if List.is_empty info.extra then ""
       else Stdlib.Printf.sprintf ",\n      \"extra\": {\n%s\n      }" extra_json)
  in
  let variants_str =
    List.map variant_infos ~f:variant_json |> String.concat ~sep:",\n"
  in
  Stdlib.Printf.fprintf oc "{\n  \"project\": %s,\n  \"variants\": [\n%s\n  ]\n}\n"
    (q project_name) variants_str;
  Stdlib.close_out oc;
  Fmt.pr "[run_info] %s@." path

(* Run multiple variants of a project sharing one log, one result.html, one
   diagrams/ directory. Steps from all variants share the flat projects/<name>/
   step dirs; only filenames are variant-keyed (e.g. probe_stable.log). *)
let run_project_multi ?(failfast = false) ?cache_path ~project_name ~root
    ?(artifact_names : artifact_kind -> string option = fun _ -> None)
    ~(variants : (string * action_step list * run_info option) list)
    () =
  let dir = [%string "%{root}/canary/projects/%{project_name}"] in
  ensure_dir dir;
  let run_dir = [%string "%{dir}/-run"] in
  ensure_dir run_dir;
  let log_path = [%string "%{run_dir}/actions.log"] in
  let logger = create_logger ~log_path in
  let all_results =
    List.map variants ~f:(fun (variant_id, steps, _run_info) ->
        let global_cache = Option.map cache_path ~f:(fun p -> Canary_step_cache.load ~path:p) in
        let project = if String.is_empty variant_id then project_name
                      else [%string "%{project_name}/%{variant_id}"] in
        logger.log ~tag:"*" ~event:"variant_start" ~detail:(Some variant_id);
        let status = run_graph ~failfast ?global_cache logger ~project ~root steps in
        (steps, status))
  in
  (* Single unified run_info.json covering all variants. *)
  let variant_infos = List.filter_map variants ~f:(fun (id, _, ri) ->
      Option.map ri ~f:(fun info -> (id, info))) in
  if not (List.is_empty variant_infos) then
    dump_run_info_multi ~dir:run_dir ~project_name variant_infos;
  (* Combine step lists: dedup by tag (first variant that defines a tag wins).
     Merge status tables: Done > Failed > Skipped. *)
  let seen_tags = Hashtbl.create (module String) in
  let all_steps = List.concat_map all_results ~f:fst
                  |> List.filter ~f:(fun s ->
                      if Hashtbl.mem seen_tags s.tag then false
                      else (Hashtbl.set seen_tags ~key:s.tag ~data:(); true)) in
  let merged_status = merge_step_statuses (List.map all_results ~f:snd) in
  Canary_diagram.write_project_output ~dir ~project_name ~variant:"" ~steps:all_steps
    ~run_status:merged_status ~artifact_names ~root logger;
  save_run_state ~dir:run_dir ~project_name all_steps ~artifact_name:artifact_names merged_status;
  logger.close ()
