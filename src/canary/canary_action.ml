open Base
open Canary_basic
open Canary_store
open Canary

(* ── Script spec ──
   A project provides shell commands per action kind.
   None = project doesn't support this action (also determines capabilities).
   Commands are templates that receive output_dir at runtime.

   Scripts for fetch/pack come from the store (uniform per PM).
   Scripts for build/probe come from the project (project-specific). *)

(* probe_binding is the action; each entry is keyed by the location
   of the artifact being probed. Location determines deps and tag:
   - Build_tree: depends on build_binding (raw build artifact)
   - Staged: depends on an installed (cmake --install) artifact
   - Pm { lang; pm }: depends on pack_binding or fetch_binding (PM-installed) *)

(* Tag for a split probe step: probe_<lang>_binding[_<pm>].
   Build_tree/Staged use the rule's lang; Pm entries use the location's lang.
   This matches string_of_rule (Probe (Binding lang)) for the Build_tree base case. *)
let tag_of_probe_lib_location loc =
  let base = string_of_rule (Probe Lib) in
  match loc with
  | Build_tree -> base
  | Staged -> base ^ "_staged"
  | Pm (Sys_pm { pm }) -> [%string "%{base}_%{string_of_pm pm}"]
  | Pm (Lang_pm _) -> failwith "tag_of_probe_lib_location: Lang_pm is not a lib probe location"

let tag_of_probe_location ~lang location =
  let base l = string_of_rule (Probe (Binding l)) in
  match location with
  | Build_tree -> base lang
  | Staged -> base lang ^ "_staged"
  | Pm (Lang_pm { lang = loc_lang; pm }) ->
      [%string "%{base loc_lang}_%{string_of_pm pm}"]
  | Pm (Sys_pm _) -> failwith "tag_of_probe_location: Sys_pm is not a binding probe location"

(* Whether this probe reads from the packed/installed store (vs. raw build tree) *)
let probe_from_store = function
  | Build_tree -> false
  | _ -> true

type version_info = {
  provider_version : string;   (* e.g. "19" for llvm.19-shared *)
  consumer_requires : string;  (* e.g. "Opcode.UncondBr" *)
  since : string option;       (* e.g. "LLVM 21 (dev, commit #186176)" *)
  note : string option;
}

(* A single symbol, optionally carrying its version annotation (L1b: @@GLIBC_2.31). *)
type symbol_entry = {
  sym_name : string;
  sym_version : string option;  (* e.g. "GLIBC_2.31" from nm @@GLIBC_2.31 *)
}

let sym name = { sym_name = name; sym_version = None }
let sym_v name version = { sym_name = name; sym_version = Some version }

(* Declarative check on a binary artifact's symbol table.
   Orthogonal to step_expectation — runs after the command succeeds.
   Any rule may carry a symbol_check; it is not a variant of "did the cmd fail". *)
type symbol_check = {
  provided_lib : string;           (* path to .so to inspect with nm -D *)
  required : symbol_entry list;    (* must be exported *)
  missing : symbol_entry list;     (* must NOT be exported *)
  version_info : version_info option;
}

(* Input to a derived (compat-driven) failure expectation. Each entry is
   a list of CANDIDATE relative paths (relative to the run dir = parent
   of the step's output_dir); the first that exists is used. Languages
   contribute whichever layers apply: OCaml has L0 (stub) + L3 (mli);
   Python typically has only L3 (attrs); native libs are L0 providers. *)
type compat_summary_input =
  | C_stub      of { paths : string list }   (* L0 consumer: binding's required C symbols *)
  | Native_lib  of { paths : string list }   (* L0 provider: native lib's defined C symbols *)
  | Ocaml_mli   of { paths : string list }   (* L3: OCaml mli watchlist *)
  | Python_attrs of { paths : string list }  (* L3: Python dir() watchlist *)

type step_expectation =
  | Expect_success
  | Expect_failure of {
      contains_any : string list;
      version_info : version_info option;
    }
  (* Failure expected; contains_any is *derived* at evaluation time from
     cached compat summaries given by [inputs]. Empty derived list ⇒ the
     check degenerates to "any failure with non-empty probe.log".
     See doc/canary/design/api_interface.md §13. *)
  | Expect_compat_failure of {
      inputs       : compat_summary_input list;
      version_info : version_info option;
    }

(* DESIGN NOTE — adding new per-rule fields to script_spec:
   When a property of an action_step varies per-location for multi-probe
   rules (probe_binding has multiple location entries), the property's
   accessor in script_spec MUST take `location option` from the start.
   Both [expectation] and [summary] originally took only [rule] and had
   to be retrofitted to [rule -> location option -> ...] when their first
   per-location use case appeared (sqlite/z3/llvm pip probes). Mismatch
   between rule and the location entry led to silent miscategorisation
   (pip probes wrapped as Expect_failure). For any future field of shape
   `rule -> X` ask: could two probe_binding variants want different X?
   If yes, take location option upfront. [check_post] and [symbol_check]
   are still rule-only because no current project needs per-location
   variation; revisit when one does. *)
type script_spec = {
  fetch_source : (output_dir:string -> variant_key:string -> string) option;
  (* Declarative API spec for this source version. When present, derive_steps
     checks consistency: binding_api.source_dir = Some _ ↔ build_binding = Some _. *)
  api_source : Canary_artifact_api.t option;
  (* Scan step: verifies api_source header/binding claims against the fetched
     source tree. Emitted after fetch_source; configure/build depend on it.
     None when no source build (stable fetch-only sources). *)
  scan_source : (output_dir:string -> variant_key:string -> string) option;
  configure : (output_dir:string -> variant_key:string -> string) option;
  (* Headers: public C API headers consumed by build_binding.
     build_headers: headers from the source/build tree (after configure).
     fetch_headers: headers from a system -dev package (e.g. apt install libz3-dev). *)
  build_headers : (output_dir:string -> variant_key:string -> string) option;
  fetch_headers : (output_dir:string -> variant_key:string -> string) option;
  build_lib : (output_dir:string -> variant_key:string -> string) option;
  build_binding : (Canary_artifact_api.lang * (output_dir:string -> variant_key:string -> string)) list;
  install_lib : (output_dir:string -> variant_key:string -> string) option;
  build_app : (output_dir:string -> variant_key:string -> string) option;
  fetch_lib : (output_dir:string -> variant_key:string -> string) option;
  fetch_binding : (Canary_artifact_api.lang * (output_dir:string -> variant_key:string -> string)) list;
  fetch_app : (output_dir:string -> variant_key:string -> string) option;
  pack_lib : (output_dir:string -> variant_key:string -> string) option;
  pack_binding : (Canary_artifact_api.lang * (output_dir:string -> variant_key:string -> string)) list;
  pack_app : (output_dir:string -> variant_key:string -> string) option;
  probe_lib : (location * (output_dir:string -> variant_key:string -> string)) list;
  probe_binding : (Canary_artifact_api.lang * location * (output_dir:string -> variant_key:string -> string)) list;
  probe_app : (output_dir:string -> variant_key:string -> string) option;
  (* Optional per-rule check_post override. None = use default (non-empty dir). *)
  check_post : (rule -> (output_dir:string -> variant_key:string -> bool) option);
  (* Per-rule expectation. Default: Expect_success.
     loc carries the per-location variant for multi-probe rules (e.g., a
     Probe Binding that has opam AND pip variants — the opam one may be
     Expect_failure while the pip one is Expect_success). None for
     single-location rules. *)
  expectation : rule -> location option -> step_expectation;
  (* Optional per-rule artifact symbol check. None = no symbol check. *)
  symbol_check : (rule -> symbol_check option);
  (* Auto-summary pkg names for binding probes. When api_source is present and
     a matching lang entry exists here, derive_steps auto-generates a summary
     step after each Probe (Binding lang) step:
       OCaml → mli_summary_opam_pkg_cmd ~pkg ~watchlist:(binding_api[lang].module_watchlist)
       Python → python_summary_cmd ~pkg ~watchlist:(binding_api[lang].module_watchlist)
     Typical projects set this and omit binding arms from [summary]. *)
  binding_summary : (Canary_artifact_api.lang * string) list;
  (* Optional note prepended to auto-generated binding summaries (shell echo).
     Used by stable-fetch specs to warn that watchlists were declared for the
     dev version. Ignored when the explicit [summary] override is used. *)
  summary_note : string option;
  (* Explicit per-rule summary override. Wins over auto-generation.
     Use for native probe summaries (lib path is always project-specific)
     or any case needing custom logic beyond what api_source provides.
     loc is Some _ for per-location probe variants, None for single-location rules.
     See doc/canary/design/api_interface.md. *)
  summary : rule -> location option -> (output_dir:string -> variant_key:string -> string) option;
}

let empty_script_spec = {
  fetch_source = None;
  api_source = None;
  scan_source = None;
  configure = None;
  build_headers = None; fetch_headers = None;
  build_lib = None; build_binding = []; install_lib = None;
  build_app = None;
  fetch_lib = None; fetch_binding = []; fetch_app = None;
  pack_lib = None; pack_binding = []; pack_app = None;
  probe_lib = []; probe_binding = [];
  probe_app = None;
  check_post = (fun _ -> None);
  expectation = (fun _ _ -> Expect_success);
  symbol_check = (fun _ -> None);
  binding_summary = [];
  summary_note = None;
  summary = (fun _ _ -> None);
}

(* Remove build-from-source actions. Keeps fetch + probe only. *)
let no_source spec =
  { spec with fetch_source = None; scan_source = None; configure = None;
    build_headers = None;
    build_lib = None; build_binding = []; install_lib = None;
    build_app = None;
    pack_lib = None; pack_binding = []; pack_app = None;
    probe_lib = List.filter spec.probe_lib ~f:(fun (loc, _) ->
        match loc with Build_tree | Staged -> false | _ -> true) }

(* Look up the script for a rule *)
let script_of_rule spec = function
  | Fetch Source -> spec.fetch_source
  | Configure -> spec.configure
  | Build_headers -> spec.build_headers
  | Fetch Headers -> spec.fetch_headers
  | Fetch Lib -> spec.fetch_lib
  | Fetch (Binding lang) -> List.Assoc.find spec.fetch_binding ~equal:Poly.equal lang
  | Fetch App -> spec.fetch_app
  | Build_lib -> spec.build_lib
  | Build_binding lang -> List.Assoc.find spec.build_binding ~equal:Poly.equal lang
  | Install_lib -> spec.install_lib
  | Build_app -> spec.build_app
  | Publish Lib -> spec.pack_lib
  | Publish (Binding lang) -> List.Assoc.find spec.pack_binding ~equal:Poly.equal lang
  | Publish App -> spec.pack_app
  | Probe Lib ->
      (match spec.probe_lib with [] -> None | (_, cmd) :: _ -> Some cmd)
  | Probe (Binding lang) ->
      (* For has-check purposes: Some _ when any probe entry exists for this lang. *)
      (match List.filter spec.probe_binding ~f:(fun (l, _, _) -> Poly.equal l lang) with
       | [] -> None
       | (_, _, cmd) :: _ -> Some cmd)
  | Probe App -> spec.probe_app
  | Publish Source | Probe Source | Publish Headers | Probe Headers -> None

(* ── Action step protocol ── *)

type action_step = {
  tag : string;                      (* unique id: e.g., "build_lib" *)
  cache_key : string;                (* global cache key: "cache_project:tag" *)
  output_tag : string;               (* tag used for this step's output_dir; usually same as tag,
                                        but summary steps set it to their parent's tag so they
                                        share the parent's directory (no empty _summary dir). *)
  output_dir : string;               (* absolute path = root/canary/projects/project_name/step_dir
                                        step_dir = Canary_step_key.step_dir_of_tag output_tag
                                        NO variant subdir — variants are encoded in file names. *)
  project_dir : string;              (* root/canary/projects/project_name — used for compat lookups *)
  variant_id : string;               (* "" for single-variant projects, else e.g. "stable" or "19" *)
  rule : rule;
  deps : string list;                (* tags of upstream steps *)
  cmd : output_dir:string -> variant_key:string -> string; (* shell command; writes variant-keyed files *)
  check_pre : unit -> bool;          (* inputs available? *)
  check_post : output_dir:string -> variant_key:string -> bool; (* output valid? *)
  expectation : step_expectation;    (* what should this step do? *)
  symbol_check : symbol_check option; (* optional artifact symbol check, runs after cmd succeeds *)
}

(* ── Logging (plain text file + console) ── *)

let now () =
  let t = Unix.gettimeofday () in
  let tm = Unix.localtime t in
  let frac = t -. Float.round_down t in
  Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d.%03d"
    (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday
    tm.tm_hour tm.tm_min tm.tm_sec
    (Float.to_int (frac *. 1000.0))

type logger = {
  log : tag:string -> event:string -> detail:string option -> unit;
  close : unit -> unit;
}

let create_logger ~log_path =
  let oc = Stdlib.open_out_gen
      [Open_creat; Open_append; Open_wronly] 0o644 log_path in
  let log ~tag ~event ~detail =
    let ts = now () in
    let detail_str = match detail with
      | Some d -> [%string "  (%{d})"]
      | None -> ""
    in
    let padded_tag =
      if String.length tag < 25 then
        tag ^ String.make (25 - String.length tag) ' '
      else tag
    in
    let line = [%string "[%{ts}] %{padded_tag}  %{event}%{detail_str}"] in
    Fmt.pr "%s@." line;
    Stdlib.output_string oc (line ^ "\n");
    Stdlib.flush oc
  in
  let close () = Stdlib.close_out oc in
  { log; close }

let run_cmd_logged logger ~tag cmd =
  logger.log ~tag ~event:"cmd" ~detail:(Some cmd);
  let rc = Stdlib.Sys.command cmd in
  if rc <> 0 then
    logger.log ~tag ~event:"cmd_fail" ~detail:(Some [%string "exit %{Int.to_string rc}"]);
  rc = 0

(* ── Runner ── *)

(* project = "z3/stable" → project_name="z3", variant_id="stable"
   project = "sqlite"   → project_name="sqlite", variant_id=""
   Output Layout v3: step_dir uses action-first grouping for binding tags
   ("build_binding_ocaml" → "build_binding/ocaml"); NO variant subdir.
   Variants are encoded as filename suffixes (_19.json, _stable.log).
   All variants of a step share the same output_dir. *)
let output_dir_for ~root ~project ~tag =
  let (project_name, _variant_id) =
    match String.rsplit2 project ~on:'/' with
    | Some (name, vid) -> (name, vid)
    | None -> (project, "")
  in
  let step_dir = Canary_step_key.step_dir_of_tag tag in
  let base = [%string "%{root}/canary/projects/%{project_name}/%{step_dir}"] in
  if Stdlib.Filename.is_relative base then
    Stdlib.Filename.concat (Unix.getcwd ()) base
  else base

let project_dir_of ~root ~project =
  let project_name = match String.rsplit2 project ~on:'/' with
    | Some (name, _) -> name
    | None -> project
  in
  let base = [%string "%{root}/canary/projects/%{project_name}"] in
  if Stdlib.Filename.is_relative base then
    Stdlib.Filename.concat (Unix.getcwd ()) base
  else base

(* Execute a step's shell command, ensuring output_dir exists. *)
let exec_step logger ~tag ~output_dir (step : action_step) =
  ignore (Stdlib.Sys.command [%string "mkdir -p \"%{output_dir}\""] : int);
  let shell_cmd = step.cmd ~output_dir ~variant_key:step.variant_id in
  run_cmd_logged logger ~tag shell_cmd

(* Check if output contains any of the expected strings *)
let output_contains_any ~output_dir strings =
  (* Read all files in output_dir looking for matches *)
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
    | Some cache -> Canary_step_cache.is_success cache ~key:step.cache_key
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
                (* Resolve compat summary paths relative to the project dir.
                   Path format: "step_tag/file.json" (e.g. "pack_binding_ocaml/summary_stub.json").
                   v3 layout: step_tag is mapped through step_dir_of_tag for action-first dirs,
                   and the filename is variant-key-qualified (_19.json for variant "19"). *)
                let pick_first_existing rels =
                  List.find_map rels ~f:(fun rel ->
                      let p = match String.lsplit2 rel ~on:'/' with
                        | Some (step_tag, file) ->
                            let step_dir = Canary_step_key.step_dir_of_tag step_tag in
                            let vk_file = Canary_step_key.variant_file
                                ~variant_key:step.variant_id file in
                            step.project_dir ^ "/" ^ step_dir ^ "/" ^ vk_file
                        | None ->
                            let vk_rel = Canary_step_key.variant_file
                                ~variant_key:step.variant_id rel in
                            step.project_dir ^ "/" ^ vk_rel
                      in
                      if Stdlib.Sys.file_exists p then Some p else None)
                in
                let typed_inputs =
                  List.filter_map inputs ~f:(function
                    | C_stub { paths } ->
                        Option.map (pick_first_existing paths) ~f:(fun p ->
                          Canary_compat.C_stub p)
                    | Native_lib { paths } ->
                        Option.map (pick_first_existing paths) ~f:(fun p ->
                          Canary_compat.Native_lib p)
                    | Ocaml_mli { paths } ->
                        Option.map (pick_first_existing paths) ~f:(fun p ->
                          Canary_compat.Ocaml_mli p)
                    | Python_attrs { paths } ->
                        Option.map (pick_first_existing paths) ~f:(fun p ->
                          Canary_compat.Python_attrs p))
                in
                let derived =
                  Canary_compat.predicted_contains_any_v2 typed_inputs
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

type step_status = Step_done | Step_failed | Step_skipped

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

(* ── Result diagram ──
   Reuses the action_rule schema diagram, colored by run status. *)

let result_status_of_run (steps : action_step list)
    (run_status : (string, step_status) Hashtbl.t) =
  let open Canary in
  let tbl = Hashtbl.create (module String) in
  (* Mark all store_rules actions as Not_in_spec initially.
     Use OCaml as sentinel lang — langs are fully known from steps. *)
  let langs =
    List.filter_map steps ~f:(fun s ->
        match s.rule with
        | Build_binding lang | Fetch (Binding lang)
        | Publish (Binding lang) | Probe (Binding lang) -> Some lang
        | _ -> None)
    |> List.dedup_and_sort ~compare:Poly.compare
    |> fun ls -> if List.is_empty ls then Canary_artifact_api.[ OCaml ] else ls
  in
  List.iter (store_rules ~langs) ~f:(fun r ->
      Hashtbl.set tbl ~key:(string_of_rule r) ~data:Not_in_spec);
  (* Override with actual run results.
     Also update the canonical rule tag for split probes: probe_binding_pkg/pip
     have tag ≠ string_of_rule, so merge them into "probe_binding" using
     Done > Failed > Skipped precedence so the diagram node reflects reality. *)
  let merge_status prev ns =
    let open Canary in
    match prev with
    | None | Some Not_in_spec | Some Skipped -> ns
    | Some Done -> Done
    | Some Done_fail -> (match ns with Done -> Done | Failed -> Failed | _ -> Done_fail)
    | Some Failed -> (match ns with Done -> Done | _ -> Failed)
  in
  List.iter steps ~f:(fun s ->
      let ns = match Hashtbl.find run_status s.tag with
        | Some Step_done ->
            (match s.expectation with
             | Expect_failure _ | Expect_compat_failure _ -> Done_fail
             | Expect_success -> Done)
        | Some Step_failed -> Failed
        | Some Step_skipped -> Skipped
        | None -> Skipped
      in
      Hashtbl.set tbl ~key:s.tag ~data:ns;
      let canonical = string_of_rule s.rule in
      if not (String.equal s.tag canonical) then
        Hashtbl.update tbl canonical ~f:(fun prev -> merge_status prev ns));
  tbl

(* ── Step-based Mermaid renderer (per-view diagrams) ──
   Renders a (possibly filtered) action_step list. Each step becomes a
   node; edges follow step.deps within the rendered subset.
   Caller filters before calling — use [mermaid_of_steps_for_view] for
   the canned view filters defined in this module. *)

let _node_shape_of_rule rule =
  match rule with
  | Probe _                                  -> `Pill
  | Build_lib | Build_binding _ | Build_app
  | Build_headers | Configure | Install_lib
  | Publish _                                -> `Hex
  | Fetch _                                  -> `Box

let mermaid_node_for_step ~id ~is_summary ~is_scan (s : action_step) =
  let nid = "S_" ^ s.tag in
  let label = [%string "%{s.tag} [%{Int.to_string id}]"] in
  let shape =
    if is_summary || is_scan then `Pill
    else _node_shape_of_rule s.rule
  in
  let line = match shape with
    | `Pill -> [%string "    %{nid}([\"%{label}\"])"]
    | `Hex  -> [%string "    %{nid}{{\"%{label}\"}}"]
    | `Box  -> [%string "    %{nid}[\"%{label}\"]"]
  in
  (nid, line)

let _is_summary_step (s : action_step) =
  String.is_suffix s.tag ~suffix:"_summary"
let _is_scan_step (s : action_step) =
  String.equal s.tag "scan_source"

(* Stable per-step index based on execution order (1-based).
   Same id is used across overview and detail views so users can
   cross-reference between diagrams and the action log. *)
let step_id_table (all_steps : action_step list) : (string, int) Hashtbl.t =
  let tbl = Hashtbl.create (module String) in
  List.iteri all_steps ~f:(fun i s ->
      Hashtbl.set tbl ~key:s.tag ~data:(i + 1));
  tbl

(* Render a filtered action_step list as a Mermaid graph. [all_steps]
   gives the full step list (used for stable ID assignment); only the
   subset for which [filter] returns true is rendered. Deps that point
   outside the subset are silently dropped. [status] (optional) maps
   each step.tag to a Canary.node_status to color the nodes. *)
let mermaid_of_steps
    ?(status : (string, Canary.node_status) Hashtbl.t option)
    ?(title : string option)
    ~(all_steps : action_step list)
    ?(filter : (action_step -> bool) option)
    () : string =
  let ids = step_id_table all_steps in
  let id_of s = Hashtbl.find_exn ids s.tag in
  let pred = Option.value filter ~default:(fun _ -> true) in
  let steps = List.filter all_steps ~f:pred in
  let buf = Buffer.create 1024 in
  let add s = Buffer.add_string buf s; Buffer.add_char buf '\n' in
  Option.iter title ~f:(fun t -> add ("%% " ^ t));
  add "graph LR";
  let in_subset = Hash_set.create (module String) in
  List.iter steps ~f:(fun s -> Hash_set.add in_subset s.tag);
  let edge_idx = ref 0 in
  let edge_tags = ref [] in
  let add_edge ~src ~dst ~tag ~dashed =
    let arrow = if dashed then "-.->" else "-->" in
    add [%string "    %{src} %{arrow} %{dst}"];
    edge_tags := (!edge_idx, tag) :: !edge_tags;
    Int.incr edge_idx
  in
  (* Nodes *)
  List.iter steps ~f:(fun s ->
      let is_summary = _is_summary_step s in
      let is_scan = _is_scan_step s in
      let (_, line) =
        mermaid_node_for_step ~id:(id_of s) ~is_summary ~is_scan s
      in
      add line);
  add "";
  (* Edges *)
  List.iter steps ~f:(fun s ->
      let dst = "S_" ^ s.tag in
      let dashed = _is_summary_step s || _is_scan_step s in
      List.iter s.deps ~f:(fun dep ->
          if Hash_set.mem in_subset dep then
            add_edge ~src:("S_" ^ dep) ~dst ~tag:s.tag ~dashed));
  add "";
  (* Styling *)
  add "    classDef st_done fill:#c8e6c9,stroke:#4caf50,stroke-width:3px";
  add "    classDef st_expected_fail fill:#fff9c4,stroke:#f9a825,stroke-width:2px";
  add "    classDef st_failed fill:#ffcdd2,stroke:#c62828,stroke-width:2px";
  add "    classDef st_skipped fill:#f5f5f5,stroke:#9e9e9e,stroke-dasharray:5";
  add "    classDef st_nospec fill:#fafafa,stroke:#bdbdbd,stroke-dasharray:5";
  (match status with
   | None -> ()
   | Some tbl ->
       List.iter steps ~f:(fun s ->
           let cls = match Hashtbl.find tbl s.tag with
             | Some Canary.Done -> "st_done"
             | Some Canary.Done_fail -> "st_expected_fail"
             | Some Canary.Failed -> "st_failed"
             | Some Canary.Skipped -> "st_skipped"
             | Some Canary.Not_in_spec | None -> "st_nospec"
           in
           add [%string "    class S_%{s.tag} %{cls}"]));
  Buffer.contents buf

(* ── Canned view filters ── *)

type view = [
  | `Source
  | `Lib
  | `Binding of Canary_artifact_api.lang
  | `Probes
  | `Pack
  | `Full
]

let view_name : view -> string = function
  | `Source -> "source"
  | `Lib -> "lib"
  | `Binding lang -> "binding_" ^ Canary_artifact_api.string_of_lang lang
  | `Probes -> "probes"
  | `Pack -> "pack"
  | `Full -> "full"

let focal_tag_pred (v : view) (tag : string) : bool =
  match v with
  | `Source ->
      String.equal tag "fetch_source" || String.equal tag "scan_source"
  | `Lib ->
      String.equal tag "fetch_lib"
      || String.equal tag "build_lib"
      || String.equal tag "install_lib"
      || String.is_prefix tag ~prefix:"probe_lib"
  | `Binding lang ->
      let lang_str = Canary_artifact_api.string_of_lang lang in
      String.is_substring tag ~substring:("binding_" ^ lang_str)
  | `Probes -> String.is_prefix tag ~prefix:"probe_"
  | `Pack -> String.is_prefix tag ~prefix:"pack_"
  | `Full -> true

let view_predicate (v : view) (s : action_step) : bool =
  match v with
  | `Source ->
      String.equal s.tag "fetch_source" || String.equal s.tag "scan_source"
  | `Lib ->
      String.equal s.tag "fetch_lib"
      || String.equal s.tag "build_lib"
      || String.equal s.tag "install_lib"
      || String.is_prefix s.tag ~prefix:"probe_lib"
  | `Binding lang ->
      let lang_str = Canary_artifact_api.string_of_lang lang in
      String.is_substring s.tag ~substring:("binding_" ^ lang_str)
  | `Probes ->
      String.is_prefix s.tag ~prefix:"probe_"
  | `Pack ->
      String.is_prefix s.tag ~prefix:"pack_"
  | `Full -> true

(* ── Artifact-aware detail renderers ──
   The basic view filter (mermaid_of_steps + view_predicate) shows step
   nodes only. The detail renderers below add artifact pool nodes per
   variant — e.g. lib(build_tree), lib(staged), lib(apt) — so each
   (artifact, store) instance is its own node and the variant-specific
   action chain is visible. Used for the lib + binding tabs in the HTML
   viewer. *)

let _id_label_for ~ids tag =
  match Hashtbl.find ids tag with
  | Some n -> [%string "%{tag} [%{Int.to_string n}]"]
  | None -> tag

(* Variant tag derived from a probe_<X> step tag.
   - probe_lib              → "default"
   - probe_lib_apt          → "apt"
   - probe_lib_staged       → "staged"
   - probe_lib_build_tree   → "build_tree"
   - probe_binding_ocaml    → "default"
   - probe_binding_ocaml_opam → "opam"
   etc. *)
let _variant_of_probe_tag ~prefix tag =
  if String.equal tag prefix then "default"
  else
    match String.chop_prefix tag ~prefix:(prefix ^ "_") with
    | Some suffix -> suffix
    | None -> "default"

(* Determine the "default" variant alias.
   - If there's a build_<artifact> step → primary is build_tree.
   - Else if there's a fetch step → primary is whatever PM (apt/brew/opam/pip).
   - Else just "default". *)
let _default_variant_alias ~all_steps ~build_tag ~fetch_tag ~variants =
  let has_step t = List.exists all_steps ~f:(fun s -> String.equal s.tag t) in
  if has_step build_tag then "build_tree"
  else if has_step fetch_tag then begin
    (* Pick the PM-like variant if exactly one is present. Otherwise fall
       back to a generic "fetch" alias (better than "default" — at least
       names the producer). *)
    let pm_like = List.filter variants ~f:(fun v ->
        not (String.equal v "default")
        && not (String.equal v "build_tree")
        && not (String.equal v "staged")) in
    match pm_like with
    | [ v ] -> v
    | _ -> "fetch"
  end
  else "default"


(* Compute the expand_probe_kinds parameter for mermaid_of_action_rule_schema.
   Returns per-probe-step (probe_tag, resolved_variant_id, label) triples.
   variant_id matches the variant_id computed by _compute_expand for the same
   artifact kind, so edges route correctly to the expanded artifact nodes. *)
let _compute_probe_expand
    ~(artifact_kind : artifact_kind)
    ~(probe_prefix : string)
    ~(build_tag : string)
    ~(fetch_tag : string)
    ~(step_ids : (string, int) Hashtbl.t)
    (steps : action_step list)
  : (artifact_kind * (string * string * string) list) option =
  let probe_steps = List.filter steps ~f:(fun s ->
      not (String.is_suffix s.tag ~suffix:"_summary")
      && (String.equal s.tag probe_prefix
          || String.is_prefix s.tag ~prefix:(probe_prefix ^ "_")))
  in
  if List.is_empty probe_steps then None
  else begin
    let variants =
      List.map probe_steps ~f:(fun s -> _variant_of_probe_tag ~prefix:probe_prefix s.tag)
      |> List.dedup_and_sort ~compare:String.compare
    in
    let default_alias =
      _default_variant_alias ~all_steps:steps ~build_tag ~fetch_tag ~variants
    in
    let items = List.map probe_steps ~f:(fun s ->
        let raw_vid = _variant_of_probe_tag ~prefix:probe_prefix s.tag in
        let variant_id = if String.equal raw_vid "default" then default_alias else raw_vid in
        let id_part = match Hashtbl.find step_ids s.tag with
          | Some n -> [%string " [%{Int.to_string n}]"]
          | None -> ""
        in
        (* Use the concrete step tag (e.g. probe_lib_apt) not the rule name (probe_lib),
           so each expanded node is uniquely identified by its actual action. *)
        (s.tag, variant_id, s.tag ^ id_part))
    in
    Some (artifact_kind, items)
  end

(* Shared helper: infer PM name from a fetch/pack step tag and its base prefix. *)
let _fetch_pm_of_tag kind tag =
  let base = string_of_rule (Fetch kind) in
  match String.chop_prefix tag ~prefix:(base ^ "_") with
  | Some s -> s
  | None -> (match kind with
      | Source -> "git"
      | Lib -> "apt"
      | Binding Canary_artifact_api.OCaml -> "opam"
      | Binding Canary_artifact_api.Python -> "pip"
      | _ -> "pkg")

(* Shared helper: version string for an (artifact_kind, artifact_variant_id) pair.
   artifact_variant_id is one of "build_tree", "staged", or a PM name ("apt",
   "opam", "pip", …).  variant_infos = [(run_id, version, actions)] from
   run_info.json.  Returns None when no version can be determined. *)
let _art_variant_version ~variant_infos ~steps kind vid =
  let has_step t = List.exists steps ~f:(fun s -> String.equal s.tag t) in
  let version_of_run_id rid =
    match List.find variant_infos ~f:(fun (i, _, _) -> String.equal i rid) with
    | Some (_, v, _) -> Some v | None -> None
  in
  let pm_fetch_version fetch_tag =
    let candidates = List.filter variant_infos ~f:(fun (_, _, acts) ->
        List.mem acts fetch_tag ~equal:String.equal) in
    match List.find candidates ~f:(fun (_, v, _) -> not (String.equal v "dev")) with
    | Some (_, v, _) -> Some v
    | None -> (match candidates with (_, v, _) :: _ -> Some v | [] -> None)
  in
  match vid with
  | "build_tree" ->
      let s = List.find steps ~f:(fun s -> match kind, s.rule with
          | Lib, Build_lib | Headers, Build_headers | App, Build_app -> true
          | Binding l, Build_binding l2 -> Poly.equal l l2
          | _ -> false) in
      Option.bind s ~f:(fun s -> version_of_run_id s.variant_id)
  | "staged" ->
      let s = List.find steps ~f:(fun s ->
          match s.rule with Install_lib -> true | _ -> false) in
      Option.bind s ~f:(fun s -> version_of_run_id s.variant_id)
  | pm ->
      let via_pack = List.find steps ~f:(fun s ->
          (match s.rule with Publish k -> Poly.equal k kind | _ -> false)
          && String.equal (_fetch_pm_of_tag kind s.tag) pm) in
      (match via_pack with
       | Some s -> version_of_run_id s.variant_id
       | None ->
           let fetch_tag = string_of_rule (Fetch kind) in
           let fetch_tag_pm = fetch_tag ^ "_" ^ pm in
           let tag = if has_step fetch_tag_pm then fetch_tag_pm else fetch_tag in
           pm_fetch_version tag)

(* Compute the expand_artifact parameter for mermaid_of_action_rule_schema.
   Derives per-variant (variant_id, label) pairs from the actual probe steps.
   Returns None when no probe steps for the artifact are found.
   Labels use real artifact names and version strings when available. *)
let _compute_expand
    ~(artifact_kind : artifact_kind)
    ~(probe_prefix : string)
    ~(build_tag : string)
    ~(fetch_tag : string)
    ~(artifact_names : artifact_kind -> string option)
    ~(variant_infos : (string * string * string list) list)
    ~(label_kind : string)
    ~(step_ids : (string, int) Hashtbl.t)
    (steps : action_step list)
  : (artifact_kind * (string * string) list) option =
  ignore step_ids;
  let probe_steps = List.filter steps ~f:(fun s ->
      not (String.is_suffix s.tag ~suffix:"_summary")
      && (String.equal s.tag probe_prefix
          || String.is_prefix s.tag ~prefix:(probe_prefix ^ "_")))
  in
  if List.is_empty probe_steps then None
  else begin
    let variants =
      List.map probe_steps ~f:(fun s ->
          _variant_of_probe_tag ~prefix:probe_prefix s.tag)
      |> List.dedup_and_sort ~compare:String.compare
    in
    let default_alias =
      _default_variant_alias ~all_steps:steps ~build_tag ~fetch_tag ~variants
    in
    let base_name = Option.value (artifact_names artifact_kind) ~default:label_kind in
    let multi = List.length variants > 1 in
    let variant_pairs =
      List.map variants ~f:(fun v ->
          let rv = if String.equal v "default" then default_alias else v in
          let ver = _art_variant_version ~variant_infos ~steps artifact_kind rv in
          let label = match ver with
            | Some version -> [%string "%{base_name} (%{version})"]
            | None -> if multi then [%string "%{base_name} (%{rv})"] else base_name
          in
          (rv, label))
    in
    Some (artifact_kind, variant_pairs)
  end

(* ── Full view renderer ────────────────────────────────────────────────────
   Every step is an individual action node.  Artifact kinds are grouped in
   subgraphs; PM-sourced variants get a store cylinder node upstream of the
   fetch action.  Source→configure is chained through scan_source when present
   (chain_scan = true for this view). *)
let mermaid_full
    ?(status : (string, node_status) Hashtbl.t option)
    ?(view_title = "full")
    ~step_ids
    ~has_scan
    ~(summary_rules : (rule * string) list)
    ~(variant_infos : (string * string * string list) list)
    ~(artifact_names : artifact_kind -> string option)
    (steps : action_step list) : string =
  ignore summary_rules;
  let buf = Buffer.create 2048 in
  let add s = Buffer.add_string buf s; Buffer.add_char buf '\n' in
  let has_step t = List.exists steps ~f:(fun s -> String.equal s.tag t) in
  let id_label tag =
    let disp =
      if String.is_suffix tag ~suffix:"_summary"
      then inspect_label_of_tag tag else tag
    in
    match Hashtbl.find step_ids tag with
    | Some n -> [%string "%{disp} [%{Int.to_string n}]"]
    | None -> disp
  in
  (* ── Kind utilities ── *)
  let kind_str k = string_of_artifact_kind k in
  let kind_label = function
    | Source -> "source" | Headers -> "headers" | Lib -> "lib"
    | Binding lang -> Canary_artifact_api.string_of_lang lang ^ " binding"
    | App -> "app"
  in
  (* Artifact docs node id for (kind, variant_id).  Single-variant uses canonical. *)
  let art_nid k vid = [%string "%{kind_str k}_%{vid}_node"] in
  let art_nid_canonical k = [%string "%{kind_str k}_node"] in
  let fetch_pm kind tag = _fetch_pm_of_tag kind tag
  in
  (* For a kind, collect its variants as (variant_id, docs_node_id) pairs and
     the associated fetch steps. Build variants precede fetch variants.
     Single-variant kinds use the canonical node id so edges stay clean. *)
  let kind_variants kind =
    let build_tag = match kind with
      | Lib -> if has_step "build_lib" then Some "build_lib" else None
      | Headers -> if has_step "build_headers" then Some "build_headers" else None
      | Binding lang ->
          let t = "build_binding_" ^ Canary_artifact_api.string_of_lang lang in
          if has_step t then Some t else None
      | App -> if has_step "build_app" then Some "build_app" else None
      | Source -> None
    in
    let install = Poly.equal kind Lib && has_step "install_lib" in
    let fetch_base = string_of_rule (Fetch kind) in
    let fetch_steps = List.filter steps ~f:(fun s ->
        not (String.is_suffix s.tag ~suffix:"_summary")
        && (String.equal s.tag fetch_base
            || String.is_prefix s.tag ~prefix:(fetch_base ^ "_")))
    in
    (* PM variant produced by pack_<kind> step, if any.
       pack produces an opam/pip artifact that is a distinct variant from build_tree. *)
    let pack_pm =
      let pack_t = match kind with
        | Binding lang -> "pack_binding_" ^ Canary_artifact_api.string_of_lang lang
        | Lib -> "pack_lib"
        | _ -> ""
      in
      if (not (String.is_empty pack_t)) && has_step pack_t then
        Some (match kind with
          | Binding Canary_artifact_api.OCaml -> "opam"
          | Binding Canary_artifact_api.Python -> "pip"
          | _ -> fetch_pm kind pack_t)
      else None
    in
    let vs = ref [] in
    Option.iter build_tag ~f:(fun _ -> vs := ("build_tree", ()) :: !vs);
    if install then vs := ("staged", ()) :: !vs;
    List.iter fetch_steps ~f:(fun fs ->
        let pm = fetch_pm kind fs.tag in
        vs := (pm, ()) :: !vs);
    Option.iter pack_pm ~f:(fun pm -> vs := (pm, ()) :: !vs);
    let seen = Hash_set.create (module String) in
    let raw = List.filter_map (List.rev !vs) ~f:(fun (v, ()) ->
        if Hash_set.mem seen v then None
        else (Hash_set.add seen v; Some v))
    in
    (* Resolve final node ids: canonical for single-variant, variant-based for multi *)
    let variants = match raw with
      | [v] -> [(v, art_nid_canonical kind)]
      | _ -> List.map raw ~f:(fun v -> (v, art_nid kind v))
    in
    (variants, fetch_steps, build_tag, install)
  in
  (* Primary node id used for cross-kind runtime/link edges. *)
  let primary_nid kind variants =
    let pref = ["build_tree"; "staged"; "git"] in
    match List.find pref ~f:(fun p -> List.exists variants ~f:(fun (v, _) -> String.equal v p)) with
    | Some v ->
        (* Use canonical for single-variant, variant-based for multi *)
        (match variants with [_] -> art_nid_canonical kind | _ -> art_nid kind v)
    | None -> (match variants with (_, n) :: _ -> n | [] -> art_nid_canonical kind)
  in
  (* Which artifact kinds have any step? *)
  let binding_langs =
    List.filter_map steps ~f:(fun s -> match s.rule with
        | Fetch (Binding l) | Probe (Binding l) | Publish (Binding l)
        | Build_binding l -> Some l | _ -> None)
    |> List.dedup_and_sort ~compare:Poly.compare
  in
  let all_kinds = [Source; Headers; Lib] @ List.map binding_langs ~f:(fun l -> Binding l) @ [App] in
  let kind_has_steps k =
    List.exists steps ~f:(fun s ->
        match s.rule with
        | Fetch k2 | Probe k2 | Publish k2 -> Poly.equal k k2
        | Build_lib -> Poly.equal k Lib | Install_lib -> Poly.equal k Lib
        | Build_headers -> Poly.equal k Headers
        | Build_binding l -> Poly.equal k (Binding l) | Build_app -> Poly.equal k App
        | Configure -> Poly.equal k Source)
  in
  let present_kinds = List.filter all_kinds ~f:kind_has_steps in
  (* Compute variant info for every present kind upfront *)
  let kind_data =
    List.map present_kinds ~f:(fun k -> (k, kind_variants k))
  in
  add [%string "%% view: %{view_title}"];
  add "graph LR";
  let version_of_art_variant kind vid =
    _art_variant_version ~variant_infos ~steps kind vid
  in
  (* Source variant: always annotate with the version of whichever run fetched it. *)
  let source_version = _art_variant_version ~variant_infos ~steps Source "git" in
  (* Variants that are "products" of our build/pack pipeline (not inputs from outside).
     lib: "staged" = output of install_lib.
     binding: packed pm variant = output of pack_binding (opam for OCaml, pip for Python). *)
  let product_vids_of_kind kind =
    match kind with
    | Lib -> if has_step "install_lib" then [ "staged" ] else []
    | Binding lang ->
        let pack_t = "pack_binding_" ^ Canary_artifact_api.string_of_lang lang in
        if has_step pack_t then
          [ (match lang with
             | Canary_artifact_api.OCaml -> "opam"
             | Canary_artifact_api.Python -> "pip"
             | _ -> fetch_pm (Binding lang) pack_t) ]
        else []
    | _ -> []
  in
  (* ── Subgraphs: one or two per artifact kind ──
     When a kind has both input variants (fetched/built) and product variants
     (installed/packed), split into separate subgraphs for clarity. *)
  List.iter kind_data ~f:(fun (kind, (variants, _, _, _)) ->
      let lbl = kind_label kind in
      let product_vids = product_vids_of_kind kind in
      let input_vs = List.filter variants ~f:(fun (v, _) ->
          not (List.mem product_vids v ~equal:String.equal)) in
      let product_vs = List.filter variants ~f:(fun (v, _) ->
          List.mem product_vids v ~equal:String.equal) in
      let has_split = not (List.is_empty product_vs) in
      let multi = List.length variants > 1 || has_split in
      (* Real artifact name (e.g. "libz3.so") when provided; falls back to kind label. *)
      let base_name =
        if Poly.equal kind Source then "source"
        else Option.value (artifact_names kind) ~default:lbl
      in
      (* Emit doc nodes.  Label = base_name (version).  When there is only one
         variant and no split, omit the parenthesised suffix if no version known. *)
      let emit_nodes vs =
        List.iter vs ~f:(fun (vid, n) ->
            let ver = match kind with
              | Source -> source_version
              | _ -> version_of_art_variant kind vid
            in
            let node_lbl = match ver with
              | Some v -> [%string "%{base_name} (%{v})"]
              | None   -> if multi then [%string "%{base_name} (%{vid})"] else base_name
            in
            add [%string "      %{n}@{ shape: doc, label: \"%{node_lbl}\" }"])
      in
      if has_split then begin
        (* Input subgraph: fetched from PM + built from source *)
        let sg_in = [%string "%{kind_str kind}_input_sg"] in
        add [%string "    subgraph %{sg_in} [\"%{lbl}\"]"];
        (if List.is_empty input_vs then
           let n = art_nid_canonical kind in
           add [%string "      %{n}@{ shape: doc, label: \"%{base_name}\" }"]
         else emit_nodes input_vs);
        add "    end";
        (* Product subgraph: output of install_lib or pack_binding *)
        let sg_out = [%string "%{kind_str kind}_product_sg"] in
        let product_lbl = match kind with
          | Lib -> lbl ^ " (product)"
          | _ ->
              let pm = match product_vs with (v, _) :: _ -> v | [] -> "packed" in
              lbl ^ " (" ^ pm ^ ")"
        in
        add [%string "    subgraph %{sg_out} [\"%{product_lbl}\"]"];
        emit_nodes product_vs;
        add "    end"
      end else begin
        let sg = [%string "%{kind_str kind}_sg"] in
        add [%string "    subgraph %{sg} [\"%{lbl}\"]"];
        (match variants with
         | [] ->
             let n = art_nid_canonical kind in
             add [%string "      %{n}@{ shape: doc, label: \"%{base_name}\" }"]
         | _ -> emit_nodes variants);
        add "    end"
      end);
  add "";
  (* ── Store nodes (cylinder): one per unique PM across all fetch steps ── *)
  let stores =
    List.concat_map kind_data ~f:(fun (kind, (_, fsteps, _, _)) ->
        List.map fsteps ~f:(fun fs -> fetch_pm kind fs.tag))
    |> List.dedup_and_sort ~compare:String.compare
  in
  List.iter stores ~f:(fun pm ->
      add [%string "    %{pm}_store@{ shape: cyl, label: \"%{pm}\" }"]);
  if not (List.is_empty stores) then add "";
  (* ── Action nodes ── *)
  (* scan_source *)
  if has_scan then
    add [%string "    A_scan_source{{\"%{id_label \"scan_source\"}\"}}"];
  (* configure *)
  if has_step "configure" then
    add [%string "    A_configure{{\"%{id_label \"configure\"}\"}}"];
  (* Fetch steps as hexagon action nodes *)
  List.iter kind_data ~f:(fun (_, (_, fsteps, _, _)) ->
      List.iter fsteps ~f:(fun fs ->
          add [%string "    A_%{fs.tag}{{\"%{id_label fs.tag}\"}}"] ));
  (* Build / install / pack / probe / summary steps.
     Fetch steps (non-summary) are already emitted above as hexagons; summary
     steps for fetch rules fall through here so they get a pill node. *)
  let is_fetch_or_follow s =
    not (String.is_suffix s.tag ~suffix:"_summary")
    && ((match s.rule with Fetch _ -> true | _ -> false)
        || String.equal s.tag "scan_source"
        || String.equal s.tag "configure")
  in
  List.iter steps ~f:(fun s ->
      if not (is_fetch_or_follow s) then begin
        let nid = "A_" ^ s.tag in
        let lbl = id_label s.tag in
        let line = match s.rule with
          | Probe _ -> [%string "    %{nid}([\"%{lbl}\"])"]
          | _ when String.is_suffix s.tag ~suffix:"_summary" ->
              [%string "    %{nid}([\"%{lbl}\"])"]
          | _ -> [%string "    %{nid}{{\"%{lbl}\"}}"]
        in
        add line
      end);
  add "";
  (* ── Edges ── *)
  let edge_idx = ref 0 in
  let edge_tags = ref [] in
  let add_edge ?tag s =
    add [%string "    %{s}"];
    (match tag with Some t -> edge_tags := (!edge_idx, t) :: !edge_tags | None -> ());
    Int.incr edge_idx
  in
  (* Source fetch → source artifact → scan (annotation) → configure (chain) *)
  let src_variants =
    match List.find kind_data ~f:(fun (k, _) -> Poly.equal k Source) with
    | Some (_, (vs, _, _, _)) -> vs | None -> []
  in
  let src_n = match src_variants with (_, n) :: _ -> n | [] -> art_nid_canonical Source in
  if has_step "fetch_source" then
    add_edge ~tag:"fetch_source" [%string "git_store --> A_fetch_source --> %{src_n}"];
  if has_scan then
    add_edge ~tag:"scan_source" [%string "%{src_n} -.-> A_scan_source"];
  let src_upstream = if has_scan then "A_scan_source" else src_n in
  if has_step "configure" then
    add_edge ~tag:"configure" [%string "%{src_upstream} --> A_configure"];
  (* Per-kind build / install / fetch edges *)
  List.iter kind_data ~f:(fun (kind, (variants, fsteps, build_tag, install)) ->
      if Poly.equal kind Source then ()  (* handled above *)
      else begin
        let primary = primary_nid kind variants in
        let configure_up =
          if has_step "configure" then "A_configure" else
            (match List.find kind_data ~f:(fun (k, _) -> Poly.equal k Source) with
             | Some (_, (vs, _, _, _)) ->
                 (match vs with (_, n) :: _ -> n | [] -> art_nid_canonical Source)
             | None -> art_nid_canonical Source)
        in
        (* Resolve variant id → node id using the pre-computed variants list. *)
        let lookup_nid vid =
          match List.find variants ~f:(fun (v, _) -> String.equal v vid) with
          | Some (_, n) -> n
          | None -> primary
        in
        (* build_<kind> → artifact(build_tree) *)
        Option.iter build_tag ~f:(fun bt ->
            let build_nid = lookup_nid "build_tree" in
            if has_step "configure" then
              add_edge ~tag:bt [%string "A_configure --> A_%{bt}"]
            else
              add_edge ~tag:bt [%string "%{configure_up} --> A_%{bt}"];
            (* Binding builds also need headers + lib link edges *)
            (match kind with
             | Binding _ ->
                 let hdr_n =
                   match List.find kind_data ~f:(fun (k, _) -> Poly.equal k Headers) with
                   | Some (_, (hvs, _, _, _)) ->
                       (match hvs with (_, n) :: _ -> n | [] -> art_nid_canonical Headers)
                   | None -> art_nid_canonical Headers
                 in
                 let lib_n =
                   match List.find kind_data ~f:(fun (k, _) -> Poly.equal k Lib) with
                   | Some (_, (lvs, _, _, _)) -> primary_nid Lib lvs
                   | None -> art_nid_canonical Lib
                 in
                 add_edge ~tag:bt [%string "%{hdr_n} -.->|headers| A_%{bt}"];
                 add_edge ~tag:bt [%string "%{lib_n} -.->|link| A_%{bt}"]
             | _ -> ());
            add_edge ~tag:bt [%string "A_%{bt} --> %{build_nid}"]);
        (* install_lib: build_tree → install_lib → staged *)
        if install then begin
          add_edge ~tag:"install_lib" [%string "%{lookup_nid \"build_tree\"} --> A_install_lib"];
          add_edge ~tag:"install_lib" [%string "A_install_lib --> %{lookup_nid \"staged\"}"]
        end;
        (* store → fetch → artifact *)
        List.iter fsteps ~f:(fun fs ->
            let pm = fetch_pm kind fs.tag in
            let art = lookup_nid pm in
            add_edge ~tag:fs.tag [%string "%{pm}_store --> A_%{fs.tag} --> %{art}"];
            (* Binding fetch: lib runtime dep *)
            (match kind with
             | Binding _ ->
                 let lib_n = match List.find kind_data ~f:(fun (k, _) -> Poly.equal k Lib) with
                   | Some (_, (lvs, _, _, _)) -> primary_nid Lib lvs
                   | None -> art_nid_canonical Lib
                 in
                 add_edge ~tag:fs.tag [%string "%{lib_n} -.->|runtime| A_%{fs.tag}"]
             | _ -> ()));
        (* pack_<kind>: build_tree → pack → pm_variant *)
        let pack_tag = match kind with
          | Lib -> if has_step "pack_lib" then Some "pack_lib" else None
          | Binding lang ->
              let t = "pack_binding_" ^ Canary_artifact_api.string_of_lang lang in
              if has_step t then Some t else None
          | App -> if has_step "pack_app" then Some "pack_app" else None
          | _ -> None
        in
        Option.iter pack_tag ~f:(fun pt ->
            let from_n = lookup_nid "build_tree" in
            add_edge ~tag:pt [%string "%{from_n} --> A_%{pt}"];
            (* Pack produces the pm variant (opam for binding, etc.) *)
            let pm_variant = List.find variants ~f:(fun (v, _) ->
                not (String.equal v "build_tree")
                && not (String.equal v "staged")
                && not (String.equal v "git")
                && not (String.equal v "pkg"))
            in
            Option.iter pm_variant ~f:(fun (_, pn) ->
                add_edge ~tag:pt [%string "A_%{pt} --> %{pn}"]));
        (* probe_<kind>_<variant> → from matching artifact variant *)
        let probe_base = string_of_rule (Probe kind) in
        let probe_steps = List.filter steps ~f:(fun s ->
            not (String.is_suffix s.tag ~suffix:"_summary")
            && (String.equal s.tag probe_base
                || String.is_prefix s.tag ~prefix:(probe_base ^ "_")))
        in
        List.iter probe_steps ~f:(fun ps ->
            let vid = _variant_of_probe_tag ~prefix:probe_base ps.tag in
            let art = lookup_nid vid in
            add_edge ~tag:ps.tag [%string "%{art} -->|test| A_%{ps.tag}"];
            (* Binding + app probes: lib runtime dep *)
            (match kind with
             | Binding _ | App ->
                 let lib_n = match List.find kind_data ~f:(fun (k, _) -> Poly.equal k Lib) with
                   | Some (_, (lvs, _, _, _)) -> primary_nid Lib lvs
                   | None -> art_nid_canonical Lib
                 in
                 add_edge ~tag:ps.tag [%string "%{lib_n} -.->|runtime| A_%{ps.tag}"]
             | _ -> ()));
        (* build_app: from primary ocaml_binding + lib link *)
        if Poly.equal kind App then
          Option.iter build_tag ~f:(fun bt ->
              let ocaml_n = match List.find kind_data ~f:(fun (k, _) ->
                  Poly.equal k (Binding Canary_artifact_api.OCaml)) with
                | Some (_, (bvs, _, _, _)) -> primary_nid (Binding Canary_artifact_api.OCaml) bvs
                | None -> art_nid_canonical (Binding Canary_artifact_api.OCaml)
              in
              let lib_n = match List.find kind_data ~f:(fun (k, _) -> Poly.equal k Lib) with
                | Some (_, (lvs, _, _, _)) -> primary_nid Lib lvs
                | None -> art_nid_canonical Lib
              in
              add_edge ~tag:bt [%string "%{ocaml_n} --> A_%{bt}"];
              add_edge ~tag:bt [%string "%{lib_n} -.->|link| A_%{bt}"])
      end);
  (* Summary follow-up edges (dashed) *)
  List.iter steps ~f:(fun s ->
      if String.is_suffix s.tag ~suffix:"_summary" then begin
        let parent_tag =
          if String.is_suffix s.tag ~suffix:"_stub_summary" then
            String.chop_suffix_exn s.tag ~suffix:"_stub_summary"
          else
            String.chop_suffix_exn s.tag ~suffix:"_summary"
        in
        if has_step parent_tag then
          add_edge ~tag:s.tag [%string "A_%{parent_tag} -.-> A_%{s.tag}"]
      end);
  add "";
  (* ── Styling ── *)
  add "    classDef artifact fill:#fff3e0,stroke:#ff9800,stroke-width:2px";
  add "    classDef store fill:#e8eaf6,stroke:#3f51b5,stroke-width:1.5px";
  add "    classDef st_done fill:#c8e6c9,stroke:#4caf50,stroke-width:3px";
  add "    classDef st_done_ctx fill:#e8f5e9,stroke:#a5d6a7,stroke-width:1.5px";
  add "    classDef st_expected_fail fill:#fff9c4,stroke:#f9a825,stroke-width:2px";
  add "    classDef st_failed fill:#ffcdd2,stroke:#c62828,stroke-width:2px";
  add "    classDef st_skipped fill:#f5f5f5,stroke:#9e9e9e,stroke-dasharray:5";
  add "    classDef st_nospec fill:#fafafa,stroke:#bdbdbd,stroke-dasharray:5";
  (* Artifact class for all variant nodes (nids already resolved in kind_variants) *)
  let all_art_nids =
    List.concat_map kind_data ~f:(fun (_, (variants, _, _, _)) ->
        match variants with [] -> [] | _ -> List.map variants ~f:snd)
  in
  if not (List.is_empty all_art_nids) then
    add [%string "    class %{String.concat all_art_nids ~sep:\",\"} artifact"];
  List.iter stores ~f:(fun pm ->
      add [%string "    class %{pm}_store store"]);
  (* Status classes for action nodes *)
  (match status with
   | None -> ()
   | Some tbl ->
       List.iter steps ~f:(fun s ->
           let nid = "A_" ^ s.tag in
           let cls = match Hashtbl.find tbl s.tag with
             | Some Canary.Done -> "st_done"
             | Some Canary.Done_fail -> "st_expected_fail"
             | Some Canary.Failed -> "st_failed"
             | Some Canary.Skipped -> "st_skipped"
             | Some Canary.Not_in_spec | None -> "st_nospec"
           in
           add [%string "    class %{nid} %{cls}"]));
  (* linkStyle coloring based on downstream step status *)
  let edge_styles =
    List.map (List.rev !edge_tags) ~f:(fun (idx, tag) ->
        let is_done = match status with
          | None -> false
          | Some tbl -> (match Hashtbl.find tbl tag with
              | Some Canary.Done | Some Canary.Done_fail -> true | _ -> false)
        in
        let style = if is_done then
            "stroke:#4caf50,stroke-width:3px"
          else
            "stroke:#bdbdbd,stroke-width:1px,stroke-dasharray:5"
        in
        [%string "    linkStyle %{Int.to_string idx} %{style}"])
  in
  List.iter edge_styles ~f:add;
  Buffer.contents buf

let mermaid_view
    ?(status : (string, node_status) Hashtbl.t option)
    ?(rules : rule list option)
    ?(step_ids : (string, int) Hashtbl.t option)
    ?(steps_by_rule_tag : (string, string list) Hashtbl.t option)
    ?(summary_rules : (rule * string) list option)
    ?(artifact_names : (artifact_kind -> string option) = fun _ -> None)
    ?(variant_infos : (string * string * string list) list = [])
    ?(has_scan = false)
    ~view
    (steps : action_step list)
    : string =
  let title = "view: " ^ view_name view in
  let fp = Some (focal_tag_pred view) in
  let sids = Option.value step_ids ~default:(Hashtbl.create (module String)) in
  let summary_tags_by_canonical =
    match summary_rules with
    | None -> None
    | Some srules ->
        let norm_suffix tail =
          if String.is_suffix tail ~suffix:"_stub_summary" then "_stub_summary"
          else "_summary"
        in
        let tbl = Hashtbl.create (module String) in
        List.iter srules ~f:(fun (rule, suffix) ->
            let canonical = string_of_rule rule ^ suffix in
            let rule_base = string_of_rule rule in
            let concretes = List.filter_map steps ~f:(fun s ->
                if Poly.equal s.rule rule
                && String.is_suffix s.tag ~suffix:"_summary" then
                  match String.chop_prefix s.tag ~prefix:rule_base with
                  | Some tail when String.equal (norm_suffix tail) suffix -> Some s.tag
                  | _ -> None
                else None)
            in
            Hashtbl.set tbl ~key:canonical ~data:concretes);
        Some tbl
  in
  (* Probe parameters (prefix, build_tag, fetch_tag) for a given probe kind. *)
  let probe_params kind =
    match kind with
    | Lib -> "probe_lib", "build_lib", "fetch_lib"
    | Binding lang ->
        let s = Canary_artifact_api.string_of_lang lang in
        "probe_binding_" ^ s, "build_binding_" ^ s, "fetch_binding_" ^ s
    | App -> "probe_app", "build_app", "fetch_app"
    | _ -> "", "", ""
  in
  (* Which probe kinds to expand in this view.
     - Lib view       → only Probe Lib (lib variants are the focus)
     - Binding view   → only Probe (Binding lang) for the focal language
     - Probes view    → all probe kinds (probes are the entire subject)
     - Source / Pack  → none (probes are background context) *)
  let focal_probe_kinds : artifact_kind list option =
    match view with
    | `Lib      -> Some [ Lib ]
    | `Binding lang -> Some [ Binding lang ]
    | `Probes   -> None                     (* None = expand all *)
    | _         -> Some []                  (* expand none *)
  in
  let all_probe_expand =
    List.filter_map steps ~f:(fun s ->
        match s.rule with
        | Canary.Probe k when not (String.is_suffix s.tag ~suffix:"_summary") -> Some k
        | _ -> None)
    |> List.dedup_and_sort ~compare:Poly.compare
    |> (match focal_probe_kinds with
        | None       -> Fn.id
        | Some kinds -> List.filter ~f:(fun k -> List.mem kinds k ~equal:Poly.equal))
    |> List.filter_map ~f:(fun k ->
           let pp, bt, ft = probe_params k in
           if String.is_empty pp then None
           else _compute_probe_expand ~artifact_kind:k ~probe_prefix:pp
                  ~build_tag:bt ~fetch_tag:ft ~step_ids:sids steps)
  in
  match view with
  | `Binding lang ->
      (* Focused binding view: schema graph with the focal binding expanded per-variant.
         All other kinds render as overview-style pool nodes (no subgraphs). *)
      let s_lang = Canary_artifact_api.string_of_lang lang in
      let expand =
        _compute_expand ~artifact_kind:(Binding lang)
          ~probe_prefix:("probe_binding_" ^ s_lang)
          ~build_tag:("build_binding_" ^ s_lang)
          ~fetch_tag:("fetch_binding_" ^ s_lang)
          ~artifact_names ~variant_infos ~label_kind:(s_lang ^ " binding")
          ~step_ids:sids steps
      in
      (match rules, step_ids, steps_by_rule_tag, summary_rules with
       | Some rules, Some sids2, Some sbrt, Some srules ->
           mermaid_of_action_rule_schema ?status ~has_scan:false
             ~summary_rules:srules ~step_ids:sids2 ~steps_by_rule_tag:sbrt
             ?summary_tags_by_canonical
             ?expand_artifact:expand ~expand_probe_kinds:all_probe_expand
             ~view_title:title ?focal_predicate:fp rules
       | _ ->
           mermaid_of_steps ?status ~title ~all_steps:steps
             ~filter:(view_predicate view) ())
  | `Lib ->
      (* Focused lib view: schema graph with lib artifact expanded per-variant. *)
      let expand =
        _compute_expand ~artifact_kind:Lib ~probe_prefix:"probe_lib"
          ~build_tag:"build_lib" ~fetch_tag:"fetch_lib"
          ~artifact_names ~variant_infos ~label_kind:"lib" ~step_ids:sids steps
      in
      (match rules, step_ids, steps_by_rule_tag, summary_rules with
       | Some rules, Some sids2, Some sbrt, Some srules ->
           mermaid_of_action_rule_schema ?status ~has_scan
             ~summary_rules:srules ~step_ids:sids2 ~steps_by_rule_tag:sbrt
             ?summary_tags_by_canonical
             ?expand_artifact:expand ~expand_probe_kinds:all_probe_expand
             ~view_title:title ?focal_predicate:fp rules
       | _ ->
           mermaid_of_steps ?status ~title ~all_steps:steps
             ~filter:(view_predicate view) ())
  | _ ->
      (* Source, Pack, Probes, Full: full schema graph, all probes expanded to concrete nodes.
         Full additionally chains configure through scan_source when present. *)
      let chain_scan = match view with `Full -> true | _ -> false in
      (match rules, step_ids, steps_by_rule_tag, summary_rules with
       | Some rules, Some sids2, Some sbrt, Some srules ->
           mermaid_of_action_rule_schema ?status ~has_scan ~chain_scan
             ~summary_rules:srules ~step_ids:sids2 ~steps_by_rule_tag:sbrt
             ?summary_tags_by_canonical
             ~expand_probe_kinds:all_probe_expand
             ~view_title:title ?focal_predicate:fp rules
       | _ ->
           mermaid_of_steps ?status ~title ~all_steps:steps
             ~filter:(view_predicate view) ())

(* ── Shared command templates ──
   These generate shell commands for common action patterns.
   Project specs use these instead of writing raw shell strings. *)

(* fetch_lib: install a system package and write marker *)
let fetch_lib_cmd pm (spec : Canary_store.system_package_spec) ~output_dir ~variant_key =
  let lib_ok = Canary_step_key.variant_file ~variant_key "lib.ok" in
  [%string "%{Canary_store.system_install_cmd pm spec} && echo 'installed' > %{output_dir}/%{lib_ok}"]

(* fetch_binding: install an opam package + ocamlfind, then write marker.
   We add ocamlfind explicitly because some bindings (e.g. ssl, dune-only
   pkgs) don't pull it transitively, but probe_ocaml_cmd uses
   `ocamlfind ocamlopt` to compile probes. Bindings that DO pull ocamlfind
   (e.g. zarith) treat the second install as a no-op. *)
let fetch_binding_cmd (spec : Canary_toolchain.opam_package_spec) ~output_dir ~variant_key =
  let binding_ok = Canary_step_key.variant_file ~variant_key "binding.ok" in
  [%string "%{Canary_toolchain.opam_install_cmd spec} && eval $(opam env) && opam install -y ocamlfind && echo 'installed' > %{output_dir}/%{binding_ok}"]

(* probe_binding (simple): compile and run an OCaml example against an opam package *)
let probe_ocaml_cmd ~binding_lib ~example ~target ~output_dir ~variant_key =
  (* On failure (compile or run), dump probe.log to stdout and re-raise the
     original exit code. Without this, CI step failures show only "exit 127"
     with no context — the actual ocamlfind / dynamic-link error is hidden in
     the file. Successful runs print probe.log too (cheap, useful confirmation). *)
  let probe_log = Canary_step_key.variant_file ~variant_key "probe.log" in
  [%string {|eval $(opam env)
ocamlfind ocamlopt -package %{binding_lib} -linkpkg %{example} -o %{output_dir}/%{target} > %{output_dir}/%{probe_log} 2>&1 && %{output_dir}/%{target} >> %{output_dir}/%{probe_log} 2>&1
RC=$?
cat %{output_dir}/%{probe_log}
exit $RC|}]

(* ── Convenience helpers for building steps ── *)

let rec ensure_dir path =
  if not (Stdlib.Sys.file_exists path) then (
    ensure_dir (Stdlib.Filename.dirname path);
    Unix.mkdir path 0o755)

let has_file ~output_dir name =
  Stdlib.Sys.file_exists [%string "%{output_dir}/%{name}"]

(* ── Default check_post per rule category ──
   Derived from the rule type. Projects can override via script_spec.check_post.

   | Rule category | Marker file | What it means |
   |---------------|-------------|---------------|
   | Fetch _       | <kind>.ok   | Store op completed, wrote marker |
   | Build_*       | build.ok    | Build command succeeded |
   | Publish _     | pack.ok     | Pack/install completed |
   | Probe _       | probe.log   | Test ran and produced output |
*)

let marker_of_rule = function
  | Fetch Source -> "source.ok"
  | Configure -> "conf.ok"
  | Build_headers | Fetch Headers -> "headers.ok"
  | Fetch Lib -> "lib.ok"
  | Fetch (Binding _) -> "binding.ok"
  | Fetch App -> "app.ok"
  | Build_lib | Build_binding _ | Build_app -> "build.ok"
  | Install_lib -> "install.ok"
  | Publish _ -> "pack.ok"
  | Probe _ -> "probe.log"

let default_check_post rule ~output_dir ~variant_key =
  has_file ~output_dir (Canary_step_key.variant_file ~variant_key (marker_of_rule rule))

let out_of ~root ~project ~tag =
  output_dir_for ~root ~project ~tag

let mk_step ~root ~project ~cache_project ~tag ?output_tag ~rule ~deps ~cmd
    ?(expectation = Expect_success) ?(symbol_check = None) ~check_post () =
  let output_tag = Option.value output_tag ~default:tag in
  let output_dir = output_dir_for ~root ~project ~tag:output_tag in
  let project_dir = project_dir_of ~root ~project in
  let variant_id = match String.rsplit2 project ~on:'/' with
    | Some (_, vid) -> vid
    | None -> ""
  in
  { tag;
    cache_key = cache_project ^ ":" ^ tag;
    output_tag;
    output_dir;
    project_dir;
    variant_id;
    rule; deps;
    expectation; symbol_check;
    check_pre = (fun () ->
      List.for_all deps ~f:(fun dep ->
          let out = output_dir_for ~root ~project ~tag:dep in
          Stdlib.Sys.file_exists out));
    cmd;
    check_post;
  }

(* ── Derive action steps from store_rules + script_spec ── *)

let deps_of_rule spec rule =
  let has r = Option.is_some (script_of_rule spec r) in
  let tag r = string_of_rule r in
  let scan_or_fetch_source () =
    if has (Fetch Source) then
      Some (if Option.is_some spec.scan_source then "scan_source"
            else tag (Fetch Source))
    else None
  in
  match rule with
  | Fetch _ -> []
  | Configure ->
      List.filter_opt [ scan_or_fetch_source () ]
  | Build_headers ->
      (* headers come from configured source; fall back to scan/fetch if no configure *)
      List.filter_opt [
        if has Configure then Some (tag Configure)
        else scan_or_fetch_source ()
      ]
  | Build_lib ->
      List.filter_opt [
        if has Configure then Some (tag Configure)
        else scan_or_fetch_source ()
      ]
  | Install_lib ->
      List.filter_opt [ if has Build_lib then Some (tag Build_lib) else None ]
  | Build_binding _lang ->
      let lib_dep =
        if has Build_lib then Some (tag Build_lib)
        else if has (Fetch Lib) then Some (tag (Fetch Lib))
        else None
      in
      let headers_dep =
        if has Build_headers then Some (tag Build_headers)
        else if has (Fetch Headers) then Some (tag (Fetch Headers))
        else None
      in
      (* configure needed separately when cmake drives the binding build *)
      let configure_dep =
        if has Configure then Some (tag Configure)
        else None
      in
      List.filter_opt [ configure_dep; headers_dep; lib_dep ]
  | Build_app ->
      (* OCaml is the primary binding lang for App by convention.
         TODO: scan all langs when multi-lang App support is needed. *)
      let binding_dep =
        if has (Build_binding OCaml) then Some (tag (Build_binding OCaml))
        else if has (Fetch (Binding OCaml)) then Some (tag (Fetch (Binding OCaml)))
        else None
      in
      let lib_dep =
        if has Build_lib then Some (tag Build_lib)
        else if has (Fetch Lib) then Some (tag (Fetch Lib))
        else None
      in
      List.filter_opt [ binding_dep; lib_dep ]
  | Publish kind | Probe kind ->
      let produce_rule = match kind with
        | Headers -> if has Build_headers then Some Build_headers else Some (Fetch Headers)
        | Lib -> if has Build_lib then Some Build_lib else Some (Fetch Lib)
        | Binding lang ->
            if has (Build_binding lang) then Some (Build_binding lang)
            else Some (Fetch (Binding lang))
        | App -> if has Build_app then Some Build_app else Some (Fetch App)
        | Source -> Some (Fetch Source)
      in
      let produce_dep =
        Option.bind produce_rule ~f:(fun r ->
            if has r then Some (tag r) else None)
      in
      (* probe_binding and probe_app also need a runtime lib *)
      let runtime_lib_dep = match rule with
        | Probe (Binding _) | Probe App ->
            if has (Fetch Lib) then Some (tag (Fetch Lib))
            else if has Build_lib then Some (tag Build_lib)
            else None
        | _ -> None
      in
      List.filter_opt [ produce_dep; runtime_lib_dep ]

(* Deps for a specific probe entry: Build_tree depends on build_binding,
   all other locations depend on pack_binding or fetch_binding. *)
let deps_of_probe_entry spec ~lang loc =
  let has r = Option.is_some (script_of_rule spec r) in
  let tag r = string_of_rule r in
  let produce_dep = match loc with
    | Build_tree ->
        if has (Build_binding lang) then Some (tag (Build_binding lang)) else None
    | _ ->
        if has (Publish (Binding lang)) then Some (tag (Publish (Binding lang)))
        else if has (Fetch (Binding lang)) then Some (tag (Fetch (Binding lang)))
        else None
  in
  let runtime_lib_dep =
    if has (Fetch Lib) then Some (tag (Fetch Lib))
    else if has Build_lib then Some (tag Build_lib)
    else None
  in
  List.filter_opt [ produce_dep; runtime_lib_dep ]

let deps_of_probe_lib_entry spec loc =
  let has r = Option.is_some (script_of_rule spec r) in
  let tag r = string_of_rule r in
  let produce_dep = match loc with
    | Build_tree -> if has Build_lib then Some (tag Build_lib) else None
    | Staged     -> if has Install_lib then Some (tag Install_lib) else None
    | _          -> if has (Fetch Lib) then Some (tag (Fetch Lib)) else None
  in
  List.filter_opt [ produce_dep ]

let check_api_consistency (spec : script_spec) =
  match spec.api_source with
  | None -> ()
  | Some api ->
      (* One-directional: build_binding being wired requires a declared source_dir.
         The reverse is not required — source may exist in the repo but a given
         run configuration may use a prebuilt binding instead of building it. *)
      if not (List.is_empty spec.build_binding) then
        let any_source_dir =
          List.exists api.Canary_artifact_api.binding_apis
            ~f:(fun b -> Option.is_some b.Canary_artifact_api.source_dir)
        in
        if not any_source_dir then
          failwith "api_source: script_spec has build_binding but no binding_api declares source_dir"

let derive_steps ~root ~project ?(cache_project = project) ?(langs = Canary_artifact_api.[ OCaml ]) (spec : script_spec) : action_step list =
  check_api_consistency spec;
  let seen = Hashtbl.create (module String) in
  let mk_one ~tag ~rule ~deps ~cmd =
    let check_post = match spec.check_post rule with
      | Some cp -> cp
      | None -> default_check_post rule
    in
    let expectation = spec.expectation rule None in
    let symbol_check = spec.symbol_check rule in
    mk_step ~root ~project ~cache_project ~tag ~rule ~deps ~cmd ~check_post ~expectation ~symbol_check ()
  in
  (* Optional follow-up step that writes a summary file for an artifact.
     Writes into the PARENT's output_dir (alongside probe.log) rather than
     creating a separate <parent>_summary/ directory. Depends on parent;
     check_post verifies the named file exists in that shared dir.
     [tag_suffix] is appended to parent_tag (e.g. "_summary", "_stub_summary");
     [filename] is the basename written by [summary_cmd] (e.g. "summary.json",
     "stub_summary.json"). The cmd is responsible for redirecting to that file. *)
  let mk_summary ~parent_tag ~rule ~tag_suffix ~base_name ~summary_cmd =
    let tag = parent_tag ^ tag_suffix in
    (* base_name is the variant-independent base (e.g. "summary", "summary_stub").
       The actual filename is base_name + "_" + variant_key + ".json" at run time. *)
    let check_post ~output_dir ~variant_key =
      has_file ~output_dir (Canary_step_key.filename ~variant_key ~base:base_name ~ext:"json")
    in
    mk_step ~root ~project ~cache_project ~tag
      ~output_tag:parent_tag ~rule
      ~deps:[ parent_tag ]
      ~cmd:summary_cmd ~check_post ~expectation:Expect_success
      ~symbol_check:None ()
  in
  (* A summary attached to a parent step: (tag suffix, filename, command).
     OCaml bindings get two: mli (semantic) and stub (C-symbol consumer). *)
  let prepend_note (note : string option)
      (cmd : output_dir:string -> variant_key:string -> string) =
    match note with
    | None -> cmd
    | Some n -> fun ~output_dir ~variant_key ->
        [%string "%{n}\n%{cmd ~output_dir ~variant_key}"]
  in
  (* Tuples: (tag_suffix, base_name, cmd).
     base_name is the variant-independent part of the output filename:
       "summary"      → summary.json / summary_19.json
       "summary_stub" → summary_stub.json / summary_stub_19.json   (type-first) *)
  let auto_binding_summaries rule
      : (string * string * (output_dir:string -> variant_key:string -> string)) list =
    match spec.api_source with
    | None -> []
    | Some api ->
        let ocaml_install_summaries pkg =
          (* mli summary: vals + constructors + module nesting at L3.
             stub summary: C symbols required by the binding at L0/L1.
             Both are functions of the installed binding (independent of
             which probe runs them) — attach to the install step
             (Fetch/Publish Binding) so they're cached *before*
             probe_binding evaluates Expect_compat_failure. *)
          let wl =
            Canary_artifact_api.binding_watchlist_exn api Canary_artifact_api.OCaml
          in
          let mli =
            prepend_note spec.summary_note (fun ~output_dir ~variant_key ->
              Canary_artifact_lang.mli_summary_opam_pkg_cmd
                ~pkg ~watchlist:wl ~output_dir ~variant_key ())
          in
          let prefix =
            match api.native_api.symbol_prefixes with
            | p :: _ -> p
            | [] -> ""
          in
          let stub =
            prepend_note spec.summary_note (fun ~output_dir ~variant_key ->
              Canary_artifact_lang.stub_summary_opam_pkg_cmd
                ~pkg ~prefix ~watchlist:[] ~output_dir ~variant_key ())
          in
          [ ("_summary", "summary", mli);
            ("_stub_summary", "summary_stub", stub) ]
        in
        let python_install_summary pkg =
          (* Python summary attaches at Fetch (Binding Python) — the install
             step — so the cached summary.json is available before
             Probe (Binding Python) evaluates its (possibly compat-derived)
             expectation. Mirrors the OCaml mli/stub placement. *)
          let wl =
            Canary_artifact_api.binding_watchlist_exn api
              Canary_artifact_api.Python
          in
          let py =
            prepend_note spec.summary_note (fun ~output_dir ~variant_key ->
              Canary_artifact_lang.python_summary_cmd
                ~pkg ~watchlist:wl ~output_dir ~variant_key ())
          in
          [ ("_summary", "summary", py) ]
        in
        match rule with
        | Fetch (Binding OCaml) | Publish (Binding OCaml) ->
            (match List.Assoc.find spec.binding_summary
                     ~equal:Poly.equal Canary_artifact_api.OCaml with
             | None -> []
             | Some pkg -> ocaml_install_summaries pkg)
        | Fetch (Binding Python) ->
            (match List.Assoc.find spec.binding_summary
                     ~equal:Poly.equal Canary_artifact_api.Python with
             | None -> []
             | Some pkg -> python_install_summary pkg)
        | _ -> []
  in
  (* spec.summary is the explicit override (legacy, single-summary). When
     present, it wins and we skip auto generation entirely. *)
  let attach_summary ~parent_tag ~rule ?loc base_step =
    match spec.summary rule loc with
    | Some c ->
        [ base_step;
          mk_summary ~parent_tag ~rule ~tag_suffix:"_summary"
            ~base_name:"summary" ~summary_cmd:c ]
    | None ->
        let summaries = auto_binding_summaries rule in
        if List.is_empty summaries then [ base_step ]
        else
          base_step ::
          List.map summaries ~f:(fun (tag_suffix, base_name, summary_cmd) ->
              mk_summary ~parent_tag ~rule ~tag_suffix ~base_name ~summary_cmd)
  in
  (* scan_source: verifies api_source header/binding claims post-fetch.
     Shares fetch_source's output dir; configure/build depend on it. *)
  let mk_scan_source ~fetch_tag scan_cmd =
    let check_post ~output_dir ~variant_key =
      has_file ~output_dir (Canary_step_key.variant_file ~variant_key "scan.ok")
    in
    mk_step ~root ~project ~cache_project ~tag:"scan_source"
      ~output_tag:fetch_tag ~rule:(Fetch Source)
      ~deps:[ fetch_tag ]
      ~cmd:scan_cmd ~check_post ~expectation:Expect_success
      ~symbol_check:None ()
  in
  let raw_steps = List.concat_map (store_rules ~langs) ~f:(fun rule ->
      let tag = string_of_rule rule in
      if Hashtbl.mem seen tag then []
      else
        (* Probe Lib / Probe Binding: expand per-location entries.
           Single entry uses the canonical rule tag; multiple expand to per-location tags. *)
        match rule with
        | Probe Lib ->
            Hashtbl.set seen ~key:tag ~data:true;
            List.concat_map spec.probe_lib ~f:(fun (loc, cmd) ->
                let ptag = if List.length spec.probe_lib = 1 then tag
                           else tag_of_probe_lib_location loc in
                let deps = deps_of_probe_lib_entry spec loc in
                let check_post = match spec.check_post rule with
                  | Some cp -> cp
                  | None -> fun ~output_dir ~variant_key ->
                      has_file ~output_dir
                        (Canary_step_key.variant_file ~variant_key "probe.log")
                in
                let expectation = spec.expectation rule (Some loc) in
                let symbol_check = spec.symbol_check rule in
                let base = mk_step ~root ~project ~cache_project ~tag:ptag ~rule
                  ~deps ~cmd ~check_post ~expectation ~symbol_check () in
                attach_summary ~parent_tag:ptag ~rule ~loc base)
        | Probe (Binding lang) ->
            Hashtbl.set seen ~key:tag ~data:true;
            let entries = List.filter spec.probe_binding
                ~f:(fun (l, _, _) -> Poly.equal l lang) in
            List.concat_map entries ~f:(fun (_, loc, cmd) ->
                let ptag = if List.length entries = 1 then tag
                           else tag_of_probe_location ~lang loc in
                let deps = deps_of_probe_entry spec ~lang loc in
                let check_post = match spec.check_post rule with
                  | Some cp -> cp
                  | None -> fun ~output_dir ~variant_key ->
                      has_file ~output_dir
                        (Canary_step_key.variant_file ~variant_key "probe.log")
                in
                let expectation = spec.expectation rule (Some loc) in
                let symbol_check = spec.symbol_check rule in
                let base = mk_step ~root ~project ~cache_project ~tag:ptag ~rule
                  ~deps ~cmd ~check_post ~expectation ~symbol_check () in
                attach_summary ~parent_tag:ptag ~rule ~loc base)
        | _ ->
            match script_of_rule spec rule with
            | None -> []
            | Some cmd ->
                Hashtbl.set seen ~key:tag ~data:true;
                let base = mk_one ~tag ~rule ~deps:(deps_of_rule spec rule) ~cmd in
                let steps = attach_summary ~parent_tag:tag ~rule base in
                (* Emit scan_source after fetch_source when wired *)
                (match rule, spec.scan_source with
                 | Fetch Source, Some scan_cmd
                   when not (Hashtbl.mem seen "scan_source") ->
                     Hashtbl.set seen ~key:"scan_source" ~data:true;
                     steps @ [ mk_scan_source ~fetch_tag:tag scan_cmd ]
                 | _ -> steps))
  in
  (* Resolve check_pre against actual sibling output_dirs.
     Step constructors set check_pre = "every dep tag's output_dir
     exists", but a dep's output_dir may differ from its tag's directory
     when output_tag is set (e.g. scan_source writes inside fetch_source/).
     Here we have the full step list, so re-bind each check_pre to look up
     deps via a tag → output_dir map. *)
  let by_tag = Hashtbl.create (module String) in
  List.iter raw_steps ~f:(fun s -> Hashtbl.set by_tag ~key:s.tag ~data:s.output_dir);
  List.map raw_steps ~f:(fun s ->
      let check_pre () =
        List.for_all s.deps ~f:(fun dep ->
            match Hashtbl.find by_tag dep with
            | Some out -> Stdlib.Sys.file_exists out
            | None ->
                (* Dep tag not in step list (filtered out by langs/spec).
                   Fall back to the old tag-based path. *)
                Stdlib.Sys.file_exists
                  (output_dir_for ~root ~project ~tag:dep))
      in
      { s with check_pre })

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

(* ── Index scanner ──
   Walks <root>/canary/projects/<project>/<variant>/ and collects metadata
   for every result.html found. Used to regenerate the top-level index
   after each run and by the standalone `canary index` command. *)

let _list_dirs path =
  if not (Stdlib.Sys.file_exists path) then []
  else
    try
      Stdlib.Sys.readdir path
      |> Array.to_list
      |> List.filter ~f:(fun n ->
          let p = path ^ "/" ^ n in
          Stdlib.Sys.file_exists p && Stdlib.Sys.is_directory p)
    with _ -> []

let _read_file_lines path =
  try
    let ic = Stdlib.open_in path in
    let rec loop acc =
      match Stdlib.input_line ic with
      | l -> loop (l :: acc)
      | exception End_of_file -> Stdlib.close_in ic; List.rev acc
    in
    loop []
  with _ -> []

(* Coarse status counts from actions.log: each step emits a "done" or
   "failed" or "skipped" event line. We count distinct step tags. *)
let _counts_from_log ~variant_dir =
  let log = variant_dir ^ "/actions.log" in
  let lines = _read_file_lines log in
  let by_tag = Hashtbl.create (module String) in
  List.iter lines ~f:(fun line ->
      (* Format: "[YYYY-MM-DD HH:MM:SS.SSS] <tag><spaces><event>  ..." *)
      match String.lsplit2 line ~on:']' with
      | None -> ()
      | Some (_, rest) ->
          let rest = String.lstrip rest in
          (match String.split rest ~on:' ' with
           | tag :: rest_tokens ->
               let event = List.find rest_tokens ~f:(fun t ->
                   not (String.is_empty t)) in
               (match event with
                | Some "done" -> Hashtbl.set by_tag ~key:tag ~data:"done"
                | Some "failed" -> Hashtbl.set by_tag ~key:tag ~data:"failed"
                | Some "skipped" ->
                    (* Don't override done/failed *)
                    if not (Hashtbl.mem by_tag tag) then
                      Hashtbl.set by_tag ~key:tag ~data:"skipped"
                | _ -> ())
           | _ -> ()));
  let total = Hashtbl.length by_tag in
  let done_ = Hashtbl.count by_tag ~f:(String.equal "done") in
  let failed = Hashtbl.count by_tag ~f:(String.equal "failed") in
  let skipped = Hashtbl.count by_tag ~f:(String.equal "skipped") in
  (total, done_, failed, skipped)

let _format_mtime (t : float) =
  let tm = Unix.localtime t in
  Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d"
    (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday
    tm.tm_hour tm.tm_min tm.tm_sec

let _source_kind_of_run_info ~variant_dir =
  let p = variant_dir ^ "/run_info.json" in
  if not (Stdlib.Sys.file_exists p) then ""
  else
    let lines = _read_file_lines p in
    (* New multi-variant format: find source inside first "variants" object.
       Old flat format: find top-level "source" key.
       Both cases: first line matching `"source": "..."` wins. *)
    List.find_map lines ~f:(fun l ->
        let l = String.strip l in
        match String.chop_prefix l ~prefix:{|"source": |} with
        | Some s ->
            Some (String.strip ~drop:(fun c ->
                Char.equal c '"' || Char.equal c ','
                || Char.equal c ' ') s)
        | None -> None)
    |> Option.value ~default:""

let _counts_from_run_state ~run_dir =
  let p = run_dir ^ "/run_state.json" in
  if not (Stdlib.Sys.file_exists p) then _counts_from_log ~variant_dir:run_dir
  else
    try
      let j = Yojson.Basic.from_file p in
      let open Yojson.Basic.Util in
      let steps = j |> member "steps" |> to_list in
      let counts = List.fold steps ~init:(0, 0, 0, 0)
          ~f:(fun (t, d, f, s) sj ->
              let st = sj |> member "status" |> to_string in
              match st with
              | "done"    -> (t+1, d+1, f,   s  )
              | "failed"  -> (t+1, d,   f+1, s  )
              | "skipped" -> (t+1, d,   f,   s+1)
              | _         -> (t,   d,   f,   s  ))
      in
      counts
    with _ -> _counts_from_log ~variant_dir:run_dir

let scan_index_entries ~projects_root : Canary_backend_html.index_entry list =
  if not (Stdlib.Sys.file_exists projects_root) then []
  else
    let make_entry ~project ~proj_dir =
      let run_dir = proj_dir ^ "/_run" in
      let html_path = run_dir ^ "/result.html" in
      if not (Stdlib.Sys.file_exists html_path) then None
      else
        let mtime = (Unix.stat html_path).st_mtime in
        let (total, done_, failed, skipped) = _counts_from_run_state ~run_dir in
        let src = _source_kind_of_run_info ~variant_dir:run_dir in
        Some Canary_backend_html.{
          project; variant = "";
          run_at = _format_mtime mtime;
          href = project ^ "/_run/result.html";
          total_steps = total;
          done_steps = done_;
          failed_steps = failed;
          skipped_steps = skipped;
          source_kind = src;
        }
    in
    let projects = _list_dirs projects_root in
    List.filter_map projects ~f:(fun project ->
        make_entry ~project ~proj_dir:(projects_root ^ "/" ^ project))

(* Read run_info.json and return (variant_id, version, actions) triples.
   `actions` is the list of step tags that ran in that variant. *)
let _variant_infos_of_run_info ~run_dir : (string * string * string list) list =
  let p = run_dir ^ "/run_info.json" in
  if not (Stdlib.Sys.file_exists p) then []
  else
    try
      let j = Yojson.Basic.from_file p in
      let open Yojson.Basic.Util in
      let str_list v = v |> to_list |> List.filter_map ~f:to_string_option in
      (match j |> member "variants" with
       | `List vs ->
           List.filter_map vs ~f:(fun v ->
               let id  = v |> member "id"      |> to_string_option in
               let ver = v |> member "version"  |> to_string_option in
               let acts = v |> member "actions" |> str_list in
               match (id, ver) with
               | (Some i, Some v) -> Some (i, v, acts)
               | _ -> None)
       | _ ->
           (* Single-variant flat format: top-level "version" field *)
           let acts = j |> member "actions" |> str_list in
           (match j |> member "version" |> to_string_option with
            | Some v -> [ ("", v, acts) ]
            | _ -> []))
    with _ -> []

(* ── Output generation ──
   Writes diagrams/all.mmd, per-view diagrams, result.html, and refreshes
   index.html. Shared by run_project (single-variant) and run_project_multi. *)

let write_project_output ~dir ~project_name ~variant ~steps
    ~(run_status : (string, step_status) Hashtbl.t)
    ~(artifact_names : artifact_kind -> string option)
    ~root logger =
  let node_status = result_status_of_run steps run_status in
  let langs =
    List.filter_map steps ~f:(fun s ->
        match s.rule with
        | Build_binding lang | Fetch (Binding lang)
        | Publish (Binding lang) | Probe (Binding lang) -> Some lang
        | _ -> None)
    |> List.dedup_and_sort ~compare:Poly.compare
    |> fun ls -> if List.is_empty ls then Canary_artifact_api.[ OCaml ] else ls
  in
  let has_scan = List.exists steps ~f:(fun s -> String.equal s.tag "scan_source") in
  let summary_rules =
    let canonical_parent_tag rule = string_of_rule rule in
    List.filter_map steps ~f:(fun s ->
        if String.is_suffix s.tag ~suffix:"_summary" then
          let parent = canonical_parent_tag s.rule in
          if String.is_prefix s.tag ~prefix:parent then
            let suffix = String.chop_prefix_exn s.tag ~prefix:parent in
            let normalised =
              if String.is_suffix suffix ~suffix:"_stub_summary"
              then "_stub_summary"
              else "_summary"
            in
            Some (s.rule, normalised)
          else None
        else None)
    |> List.dedup_and_sort
         ~compare:(fun (r1, s1) (r2, s2) ->
           match Poly.compare r1 r2 with
           | 0 -> String.compare s1 s2
           | n -> n)
  in
  let step_ids = step_id_table steps in
  (* steps_by_rule_tag: maps rule name → concrete step tags for [N] label embedding.
     Two variants: overview includes scan_source in the source artifact label;
     focused views exclude it (scan gets its own standalone node). *)
  let mk_steps_by_rule_tag ~include_scan =
    let tbl = Hashtbl.create (module String) in
    List.iter steps ~f:(fun s ->
        let skip =
          String.is_suffix s.tag ~suffix:"_summary"
          || (String.equal s.tag "scan_source" && not include_scan)
        in
        if not skip then
          let key = string_of_rule s.rule in
          Hashtbl.update tbl key ~f:(function
            | None -> [ s.tag ]
            | Some xs -> s.tag :: xs));
    tbl
  in
  let steps_by_rule_tag_overview = mk_steps_by_rule_tag ~include_scan:true in
  let steps_by_rule_tag = mk_steps_by_rule_tag ~include_scan:false in
  (* All run metadata (diagrams, HTML, logs, run_info, run_state) go into _run/
     so step output directories remain at the project root level. *)
  let run_dir = [%string "%{dir}/_run"] in
  ensure_dir run_dir;
  (* Overview diagram → _run/diagrams/all.mmd *)
  let view_dir = [%string "%{run_dir}/diagrams"] in
  ensure_dir view_dir;
  (* Maps canonical summary tag → all concrete step tags for that summary kind.
     E.g. "probe_lib_summary" → ["probe_lib_summary";"probe_lib_staged_summary";"probe_lib_apt_summary"]
     Used by the overview to show all concrete IDs in one collapsed summary node. *)
  let summary_tags_by_canonical =
    (* Normalize a tag suffix to "_stub_summary" or "_summary".
       Required because String.is_suffix ~suffix:"_summary" also matches
       "_stub_summary", which would double-count step 11 in both buckets. *)
    let norm_suffix tail =
      if String.is_suffix tail ~suffix:"_stub_summary" then "_stub_summary"
      else "_summary"
    in
    let tbl = Hashtbl.create (module String) in
    List.iter summary_rules ~f:(fun (rule, suffix) ->
        let canonical = string_of_rule rule ^ suffix in
        let rule_base = string_of_rule rule in
        let concretes = List.filter_map steps ~f:(fun s ->
            if Poly.equal s.rule rule
            && String.is_suffix s.tag ~suffix:"_summary" then
              match String.chop_prefix s.tag ~prefix:rule_base with
              | Some tail when String.equal (norm_suffix tail) suffix -> Some s.tag
              | _ -> None
            else None)
        in
        Hashtbl.set tbl ~key:canonical ~data:concretes);
    tbl
  in
  (* Overview: scan merged into source artifact label; no standalone scan node *)
  let overview_mmd =
    Canary.mermaid_of_action_rule_schema ~status:node_status ~has_scan:false
      ~summary_rules ~step_ids ~steps_by_rule_tag:steps_by_rule_tag_overview
      ~summary_tags_by_canonical
      (store_rules ~langs)
  in
  let all_mmd_path = [%string "%{view_dir}/all.mmd"] in
  let oc = Stdlib.open_out all_mmd_path in
  Stdlib.output_string oc overview_mmd;
  Stdlib.close_out oc;
  logger.log ~tag:"*" ~event:"diagram" ~detail:(Some all_mmd_path);
  (* Full diagram: all probes expanded as individual nodes, no focal distinction *)
  let variant_infos = _variant_infos_of_run_info ~run_dir in
  let full_mmd =
    mermaid_full ~status:node_status ~step_ids ~has_scan ~summary_rules
      ~variant_infos ~artifact_names steps
  in
  let full_mmd_path = [%string "%{view_dir}/full.mmd"] in
  let oc = Stdlib.open_out full_mmd_path in
  Stdlib.output_string oc full_mmd;
  Stdlib.close_out oc;
  logger.log ~tag:"*" ~event:"diagram" ~detail:(Some full_mmd_path);
  (* Per-view diagrams *)
  let views : view list =
    [ `Source; `Lib; `Probes ]
    @ List.map langs ~f:(fun l -> `Binding l)
  in
  let emitted_views = ref [] in
  List.iter views ~f:(fun v ->
      let filtered = List.filter steps ~f:(view_predicate v) in
      if not (List.is_empty filtered) then begin
        let path = [%string "%{view_dir}/%{view_name v}.mmd"] in
        let sbrt = match v with
          | `Binding _ -> steps_by_rule_tag_overview
          | _ -> steps_by_rule_tag
        in
        let mmd = mermaid_view ~status:node_status ~view:v
            ~rules:(store_rules ~langs) ~step_ids ~steps_by_rule_tag:sbrt
            ~summary_rules ~has_scan ~artifact_names ~variant_infos steps in
        let oc = Stdlib.open_out path in
        Stdlib.output_string oc mmd;
        Stdlib.close_out oc;
        emitted_views := (v, mmd) :: !emitted_views;
        logger.log ~tag:"*" ~event:"view"
          ~detail:(Some [%string "%{view_name v} (%{Int.to_string (List.length filtered)} steps)"])
      end);
  let html_path = [%string "%{run_dir}/result.html"] in
  let html_views =
    Canary_backend_html.{ name = "overview"; title = "Overview"; mmd = overview_mmd }
    :: Canary_backend_html.{ name = "full"; title = "Full"; mmd = full_mmd }
    :: List.rev_map !emitted_views ~f:(fun (v, mmd) ->
        let n = view_name v in
        let title = match v with
          | `Source -> "Source"
          | `Lib -> "Lib"
          | `Pack -> "Pack"
          | `Probes -> "Probes"
          | `Full -> "Full"
          | `Binding lang ->
              "Binding (" ^ Canary_artifact_api.display_of_lang lang ^ ")"
        in
        Canary_backend_html.{ name = n; title; mmd })
  in
  let html_steps =
    List.map steps ~f:(fun s ->
        let exp_str = match s.expectation with
          | Expect_success -> "Expect_success"
          | Expect_failure _ -> "Expect_failure"
          | Expect_compat_failure _ -> "Expect_compat_failure"
        in
        let status_str = match Hashtbl.find node_status s.tag with
          | Some Canary.Done -> "done"
          | Some Canary.Done_fail -> "expected_fail"
          | Some Canary.Failed -> "failed"
          | Some Canary.Skipped -> "skipped"
          | Some Canary.Not_in_spec | None -> "not_in_spec"
        in
        (* output_rel: path from _run/ to the step dir one level up. *)
        let step_dir = Canary_step_key.step_dir_of_tag s.output_tag in
        Canary_backend_html.{
          id = Hashtbl.find step_ids s.tag;
          tag = s.tag;
          rule = string_of_rule s.rule;
          output_rel = "../" ^ step_dir;
          variant_key = s.variant_id;
          expectation = exp_str;
          status = status_str;
        })
  in
  let run_at =
    let t = Unix.gettimeofday () in
    let tm = Unix.localtime t in
    Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d"
      (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday
      tm.tm_hour tm.tm_min tm.tm_sec
  in
  let html =
    Canary_backend_html.render
      ~project:project_name ~variant
      ~run_at ~index_rel:"../../index.html"
      ~views:html_views
      ~default_view:"overview"
      ~steps:html_steps
  in
  let oc = Stdlib.open_out html_path in
  Stdlib.output_string oc html;
  Stdlib.close_out oc;
  logger.log ~tag:"*" ~event:"html" ~detail:(Some html_path);
  let projects_root = [%string "%{root}/canary/projects"] in
  let index_path = projects_root ^ "/index.html" in
  let entries = scan_index_entries ~projects_root in
  let index_html = Canary_backend_html.render_index ~entries ~generated_at:run_at in
  let oc = Stdlib.open_out index_path in
  Stdlib.output_string oc index_html;
  Stdlib.close_out oc;
  logger.log ~tag:"*" ~event:"index" ~detail:(Some index_path)

(* ── Run-state serialisation ──
   Saves the full step+status snapshot so `canary view` can regenerate
   diagrams/HTML without re-running any build or probe steps. *)

let save_run_state ~dir ~project_name steps
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
  let json = `Assoc [
    ("project_name", `String project_name);
    ("steps",        `List (List.map steps ~f:step_json));
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
    let rule = match Canary.rule_of_string rule_str with
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
      [%string "%{dir}/%{Canary_step_key.step_dir_of_tag output_tag}"]
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
  (project_name, steps, run_status)

(* Regenerate diagrams/ and result.html from a saved run_state.json without
   re-running any steps. Equivalent to the tail of run_project/run_project_multi. *)
let view_project ~root ~project () =
  let (project_name, _variant) =
    match String.rsplit2 project ~on:'/' with
    | Some (n, v) -> (n, v)
    | None        -> (project, "")
  in
  let dir = [%string "%{root}/canary/projects/%{project_name}"] in
  let run_dir = [%string "%{dir}/_run"] in
  let (_, steps, run_status) = load_run_state ~dir:run_dir in
  let log_path = [%string "%{run_dir}/actions.log"] in
  let logger = create_logger ~log_path in
  write_project_output ~dir ~project_name ~variant:"" ~steps ~run_status
    ~artifact_names:(fun _ -> None) ~root logger;
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
  let run_dir = [%string "%{dir}/_run"] in
  ensure_dir run_dir;
  Option.iter run_info ~f:(fun info ->
      let path = dump_run_info ~dir:run_dir info in
      Fmt.pr "[run_info] %s@." path);
  let global_cache = Option.map cache_path ~f:(fun p -> Canary_step_cache.load ~path:p) in
  let log_path = [%string "%{run_dir}/actions.log"] in
  let logger = create_logger ~log_path in
  let status = run_graph ~failfast ?global_cache logger ~project ~root steps in
  write_project_output ~dir ~project_name ~variant:variant_id ~steps
    ~run_status:status ~artifact_names ~root logger;
  save_run_state ~dir:run_dir ~project_name steps status;
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
  let run_dir = [%string "%{dir}/_run"] in
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
  write_project_output ~dir ~project_name ~variant:"" ~steps:all_steps
    ~run_status:merged_status ~artifact_names ~root logger;
  save_run_state ~dir:run_dir ~project_name all_steps merged_status;
  logger.close ()
