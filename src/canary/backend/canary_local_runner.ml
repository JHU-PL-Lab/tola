(** [Canary_local_runner] — the local execution backend.

    Consumes an [action_step list] (built by {!Canary_step_builder}'s
    [derive_steps]) and {i executes} the steps' shell commands directly,
    in-process. Sibling of:
    - {!Canary_gh} — emits GitHub Actions YAML for the same step list.
    - {!Canary_html} — renders the result viewer.
    - {!Canary_diagram} — renders Mermaid + the view machinery.

    Where the YAML/HTML/Mermaid backends produce a file for someone else
    to consume, this backend produces a [run_status] table by actually
    running the commands and recording each step's verdict
    (Done/Failed/Skipped) plus log lines into [actions.log].

    Split from [Canary_runner] on 2026-06-01: the execute-half functions
    moved here ({!run_step}, {!run_graph}, {!exec_step},
    {!run_cmd_logged}, {!output_contains_any}, {!merge_step_statuses}),
    keeping the build-half (script_spec + derive_steps + shared command
    templates + check_post compositors + defaults + dep helpers) in
    {!Canary_step_builder}.

    Communicates with the build half through the closure firewall on
    [action_step]: this module only invokes [step.cmd] / [step.check_pre]
    / [step.check_post] and never reads [script_spec] directly.
    Symmetric design with the other backends. *)

open Base
open Canary_step_model

(* ── Cross-run cache (inlined from canary_step_cache.ml on 2026-06-01,
   Phase 10b) ─────────────────────────────────────────────────────────
   Maps cache_key → entry, where cache_key = "<project>:<step_tag>"
   (e.g. "sqlite:fetch_lib", "llvm-19:probe_binding_pkg"). Populated by
   the `cache-sync` CLI subcommand reading GH CI results back into a
   local JSON; consulted by run_step below to skip steps a previous CI
   run has already certified as successful.

   FUTURE: if the GH backend grows its own cache (e.g. CI-side artifact
   caching with a different schema), revisit and extract a shared
   cache abstraction. For now this lives next to its only consumer
   (run_step's `?global_cache`). *)

type cache_entry = {
  status : string;   (* "success" or "failure" *)
  run_id : int;      (* GH Actions run database ID; 0 = local *)
  at : string;       (* date recorded, e.g. "2026-04-22" *)
}

type step_cache = (string, cache_entry) Hashtbl.t

let make_cache () : step_cache = Hashtbl.create (module String)

let cache_entry_of_json fields =
  let get_s name =
    match List.Assoc.find fields ~equal:String.equal name with
    | Some (`String s) -> s
    | _ -> ""
  in
  let get_i name =
    match List.Assoc.find fields ~equal:String.equal name with
    | Some (`Int i) -> i
    | _ -> 0
  in
  { status = get_s "status"; run_id = get_i "run_id"; at = get_s "at" }

let cache_of_json (json : Yojson.Basic.t) : step_cache =
  let tbl = make_cache () in
  (match json with
   | `Assoc pairs ->
     List.iter pairs ~f:(fun (key, v) ->
         match v with
         | `Assoc fields -> Hashtbl.set tbl ~key ~data:(cache_entry_of_json fields)
         | _ -> ())
   | _ -> ());
  tbl

let cache_to_json (tbl : step_cache) : Yojson.Basic.t =
  let pairs =
    Hashtbl.to_alist tbl
    |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)
    |> List.map ~f:(fun (key, e) ->
           ( key,
             `Assoc
               [ ("status", `String e.status);
                 ("run_id", `Int e.run_id);
                 ("at", `String e.at) ] ))
  in
  `Assoc pairs

let load_cache ~path : step_cache =
  if Stdlib.Sys.file_exists path then
    (try Yojson.Basic.from_file path |> cache_of_json
     with _ -> make_cache ())
  else make_cache ()

let save_cache ~path (tbl : step_cache) =
  let oc = Stdlib.open_out path in
  Yojson.Basic.pretty_to_channel oc (cache_to_json tbl);
  Stdlib.output_char oc '\n';
  Stdlib.close_out oc

let cache_record (tbl : step_cache) ~key (e : cache_entry) =
  Hashtbl.set tbl ~key ~data:e

let cache_is_success tbl ~key =
  match Hashtbl.find tbl key with
  | Some { status = "success"; _ } -> true
  | _ -> false

(* ── Execution ─────────────────────────────────────────────────────── *)

(* Run one shell command, log it, return whether it exit-zeroed. *)
let run_cmd_logged logger ~tag cmd =
  logger.log ~tag ~event:"cmd" ~detail:(Some cmd);
  let rc = Stdlib.Sys.command cmd in
  if rc <> 0 then
    logger.log ~tag ~event:"cmd_fail" ~detail:(Some [%string "exit %{Int.to_string rc}"]);
  rc = 0

(* Execute a step's shell command, ensuring output_dir exists. *)
let exec_step logger ~tag ~output_dir (step : action_step) =
  ignore (Stdlib.Sys.command [%string "mkdir -p \"%{output_dir}\""] : int);
  let shell_cmd = step.cmd ~output_dir ~variant_key:step.variant_id in
  run_cmd_logged logger ~tag shell_cmd

(* Check if any file in output_dir contains any of the expected strings.
   Used by Expect_failure / Expect_compat_failure expectation evaluation. *)
let output_contains_any ~output_dir strings =
  try
    let files = Stdlib.Sys.readdir output_dir in
    Array.exists files ~f:(fun f ->
        let path = output_dir ^ "/" ^ f in
        try
          let ic = Stdlib.open_in path in
          let content = Stdlib.really_input_string ic (Stdlib.in_channel_length ic) in
          Stdlib.close_in ic;
          List.exists strings ~f:(fun s -> String.is_substring content ~substring:s)
        with _ -> false)
  with _ -> false

(* Run a single action step.
   Skip priority: (1) global cache hit, (2) local postcondition already passes. *)
let run_step logger ~root:_ ~project:_ ?global_cache (step : action_step) =
  let tag = step.tag in
  let out = step.output_dir in
  let log = logger.log ~tag in
  (* Global cache: skip if a previous CI run recorded success for this key *)
  let global_hit = match global_cache with
    | Some cache -> cache_is_success cache ~key:step.cache_key
    | None -> false
  in
  if global_hit then (
    log ~event:"skip" ~detail:(Some [%string "global cache hit (%{step.cache_key})"]);
    true)
  (* Local cache: if postcondition already passes, skip *)
  else if Stdlib.Sys.file_exists out && step.check_post ~output_dir:out ~variant_key:step.variant_id then (
    log ~event:"skip" ~detail:(Some "postcondition ok");
    true)
  else (
    let pre_ok = step.check_pre () in
    log ~event:"check_pre" ~detail:(Some (if pre_ok then "pass" else "FAIL"));
    if not pre_ok then (
      log ~event:"blocked" ~detail:(Some "precondition failed");
      false)
    else
      try
        let cmd_ok = exec_step logger ~tag ~output_dir:out step in
        let expectation_ok = match step.expectation with
          | Expect_success ->
              let ok = cmd_ok && step.check_post ~output_dir:out ~variant_key:step.variant_id in
              log ~event:"check_post" ~detail:(Some (if ok then "pass" else "FAIL"));
              log ~event:(if ok then "done" else "failed")
                ~detail:(if ok then None else Some "postcondition failed");
              ok
          | Expect_failure { contains_any; version_info } ->
              if cmd_ok then (
                log ~event:"unexpected_success"
                  ~detail:(Some "expected failure but command succeeded");
                false)
              else
                let found = output_contains_any ~output_dir:out contains_any in
                let confirmed_msg = match version_info with
                  | None -> "expected failure confirmed"
                  | Some vi ->
                      let since = Option.value_map vi.since ~default:"" ~f:(fun s -> Printf.sprintf ", added in %s" s) in
                      Printf.sprintf "expected failure confirmed: %s predates %s%s"
                        vi.provider_version vi.consumer_requires since
                in
                log ~event:(if found then "done" else "failed")
                  ~detail:(Some (if found then confirmed_msg
                    else "command failed but output didn't match expected strings"));
                found
          | Expect_compat_failure { inputs; version_info } ->
              if cmd_ok then (
                log ~event:"unexpected_success"
                  ~detail:(Some "expected failure (derived) but command succeeded");
                false)
              else
                (* Resolve each declared relative path (e.g.
                   "pack_binding_ocaml/inspect_stub.json") to its
                   project-dir-absolute form, applying v3 layout's
                   step_dir mapping and variant-key suffix. The
                   comparator runner picks the first existing path
                   per input. *)
                let resolve rel =
                  match String.lsplit2 rel ~on:'/' with
                  | Some (step_tag, file) ->
                      let step_dir = Canary_basic.step_dir_of_tag step_tag in
                      let vk_file = Canary_basic.variant_file
                          ~variant_key:step.variant_id file in
                      step.project_dir ^ "/" ^ step_dir ^ "/" ^ vk_file
                  | None ->
                      let vk_rel = Canary_basic.variant_file
                          ~variant_key:step.variant_id rel in
                      step.project_dir ^ "/" ^ vk_rel
                in
                let derived =
                  Canary_compat_run.predicted_contains_any_v2
                    ~disabled:step.disabled_contracts ~resolve inputs
                in
                log ~event:"compat_predicted"
                  ~detail:(Some (Printf.sprintf "%d substring(s)"
                                   (List.length derived)));
                let found =
                  if List.is_empty derived then
                    (* No prediction available — fall back to "any failure
                       with non-empty probe.log is acceptable". *)
                    Stdlib.Sys.file_exists (out ^ "/probe.log")
                  else output_contains_any ~output_dir:out derived
                in
                let confirmed_msg = match version_info with
                  | None -> "expected failure confirmed (derived)"
                  | Some vi ->
                      let since = Option.value_map vi.since ~default:""
                          ~f:(fun s -> Printf.sprintf ", added in %s" s) in
                      Printf.sprintf
                        "expected failure confirmed (derived): %s predates %s%s"
                        vi.provider_version vi.consumer_requires since
                in
                log ~event:(if found then "done" else "failed")
                  ~detail:(Some (if found then confirmed_msg
                    else "command failed but output didn't match derived predictions"));
                found
        in
        (* Symbol check runs independently after command expectation is met. *)
        let symbol_ok = match step.symbol_check with
          | None -> true
          | Some sc ->
              let check_sym syms expect_found =
                List.for_all syms ~f:(fun entry ->
                    let pattern = match entry.sym_version with
                      | None -> entry.sym_name
                      | Some v -> [%string "%{entry.sym_name}@@%{v}"]
                    in
                    let rc = Stdlib.Sys.command
                      (Printf.sprintf "nm -D %s 2>/dev/null | grep -qF '%s'" sc.provided_lib pattern) in
                    let found = (rc = 0) in
                    if Bool.( <> ) found expect_found then
                      log ~event:"symbol_mismatch"
                        ~detail:(Some (Printf.sprintf "%s: %s, expected %s" pattern
                            (if found then "found" else "missing")
                            (if expect_found then "found" else "missing")));
                    Bool.equal found expect_found)
              in
              let ok = check_sym sc.required true && check_sym sc.missing false in
              log ~event:(if ok then "symbols_ok" else "symbols_failed")
                ~detail:(Some (if ok then "symbol check passed" else "symbol mismatch"));
              ok
        in
        expectation_ok && symbol_ok
      with exn ->
        let msg = Exn.to_string exn in
        log ~event:"error" ~detail:(Some msg);
        false)

(* Merge multiple per-variant status tables. Done > Failed > Skipped. *)
let merge_step_statuses (all : (string, step_status) Hashtbl.t list)
    : (string, step_status) Hashtbl.t =
  let priority = function Step_done -> 3 | Step_failed -> 2 | Step_skipped -> 1 in
  let out = Hashtbl.create (module String) in
  List.iter all ~f:(fun tbl ->
      Hashtbl.iteri tbl ~f:(fun ~key ~data ->
          Hashtbl.update out key ~f:(function
            | None -> data
            | Some prev -> if priority data > priority prev then data else prev)));
  out

(* Run all steps in dependency order. Returns status per tag.
   ~failfast:true stops on the first failure (useful for debugging). *)
let run_graph ?(failfast = false) ?global_cache logger ~project ~root (steps : action_step list) =
  logger.log ~tag:"*" ~event:"graph_start"
    ~detail:(Some [%string "%{Int.to_string (List.length steps)} steps"]);
  let status = Hashtbl.create (module String) in
  (* Seed with already-done steps (postcondition passes) *)
  List.iter steps ~f:(fun s ->
      let out = s.output_dir in
      if Stdlib.Sys.file_exists out && s.check_post ~output_dir:out ~variant_key:s.variant_id then
        Hashtbl.set status ~key:s.tag ~data:Step_done);
  (* Iterate until no progress (or first failure in failfast mode) *)
  let changed = ref true in
  let aborted = ref false in
  while !changed && not !aborted do
    changed := false;
    List.iter steps ~f:(fun s ->
        if (not !aborted) && not (Hashtbl.mem status s.tag) then
          let deps_ok =
            List.for_all s.deps ~f:(fun dep ->
                match Hashtbl.find status dep with
                | Some Step_done -> true
                | _ -> false)
          in
          if deps_ok then (
            let ok = run_step logger ~project ~root ?global_cache s in
            Hashtbl.set status ~key:s.tag
              ~data:(if ok then Step_done else Step_failed);
            if ok then changed := true
            else if failfast then (
              logger.log ~tag:"*" ~event:"failfast"
                ~detail:(Some [%string "stopped after %{s.tag}"]);
              aborted := true)))
  done;
  if failfast && !aborted then (
    logger.close ();
    Stdlib.exit 1);
  (* Mark unreached as skipped *)
  List.iter steps ~f:(fun s ->
      if not (Hashtbl.mem status s.tag) then
        Hashtbl.set status ~key:s.tag ~data:Step_skipped);
  (* Report *)
  let total = List.length steps in
  let done_count =
    Hashtbl.count status ~f:(fun v -> Poly.equal v Step_done)
  in
  logger.log ~tag:"*" ~event:"graph_end"
    ~detail:(Some [%string "%{Int.to_string done_count}/%{Int.to_string total} completed"]);
  if done_count < total then
    List.iter steps ~f:(fun s ->
        match Hashtbl.find status s.tag with
        | Some Step_failed ->
            logger.log ~tag:s.tag ~event:"failed" ~detail:None
        | Some Step_skipped ->
            logger.log ~tag:s.tag ~event:"skipped" ~detail:None
        | _ -> ());
  status
