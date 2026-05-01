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
     See doc/canary/design/interface.md §13. *)
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
  fetch_source : (output_dir:string -> string) option;
  (* Declarative API spec for this source version. When present, derive_steps
     checks consistency: binding_api.source_dir = Some _ ↔ build_binding = Some _. *)
  api_source : Canary_artifact_api.t option;
  (* Scan step: verifies api_source header/binding claims against the fetched
     source tree. Emitted after fetch_source; configure/build depend on it.
     None when no source build (stable fetch-only sources). *)
  scan_source : (output_dir:string -> string) option;
  configure : (output_dir:string -> string) option;
  (* Headers: public C API headers consumed by build_binding.
     build_headers: headers from the source/build tree (after configure).
     fetch_headers: headers from a system -dev package (e.g. apt install libz3-dev). *)
  build_headers : (output_dir:string -> string) option;
  fetch_headers : (output_dir:string -> string) option;
  build_lib : (output_dir:string -> string) option;
  build_binding : (Canary_artifact_api.lang * (output_dir:string -> string)) list;
  install_lib : (output_dir:string -> string) option;
  build_app : (output_dir:string -> string) option;
  fetch_lib : (output_dir:string -> string) option;
  fetch_binding : (Canary_artifact_api.lang * (output_dir:string -> string)) list;
  fetch_app : (output_dir:string -> string) option;
  pack_lib : (output_dir:string -> string) option;
  pack_binding : (Canary_artifact_api.lang * (output_dir:string -> string)) list;
  pack_app : (output_dir:string -> string) option;
  probe_lib : (location * (output_dir:string -> string)) list;
  probe_binding : (Canary_artifact_api.lang * location * (output_dir:string -> string)) list;
  probe_app : (output_dir:string -> string) option;
  (* Optional per-rule check_post override. None = use default (non-empty dir). *)
  check_post : (rule -> (output_dir:string -> bool) option);
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
     See doc/canary/design/interface.md. *)
  summary : rule -> location option -> (output_dir:string -> string) option;
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
  output_dir : string;               (* absolute path = root/canary/projects/project/output_tag *)
  rule : rule;
  deps : string list;                (* tags of upstream steps *)
  cmd : output_dir:string -> string; (* shell command to execute *)
  check_pre : unit -> bool;          (* inputs available? *)
  check_post : output_dir:string -> bool; (* output valid? *)
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

let output_dir_for ~root ~project ~tag =
  let base = [%string "%{root}/canary/projects/%{project}/%{tag}"] in
  if Stdlib.Filename.is_relative base then
    Stdlib.Filename.concat (Unix.getcwd ()) base
  else base

(* Execute a step's shell command, ensuring output_dir exists. *)
let exec_step logger ~tag ~output_dir (step : action_step) =
  ignore (Stdlib.Sys.command [%string "mkdir -p %{output_dir}"] : int);
  let shell_cmd = step.cmd ~output_dir in
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
  else if Stdlib.Sys.file_exists out && step.check_post ~output_dir:out then (
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
              let ok = cmd_ok && step.check_post ~output_dir:out in
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
                let run_dir = Stdlib.Filename.dirname out in
                let pick_first_existing rels =
                  List.find_map rels ~f:(fun rel ->
                      let p = run_dir ^ "/" ^ rel in
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

(* Run all steps in dependency order. Returns status per tag.
   ~failfast:true stops on the first failure (useful for debugging). *)
let run_graph ?(failfast = false) ?global_cache logger ~project ~root (steps : action_step list) =
  logger.log ~tag:"*" ~event:"graph_start"
    ~detail:(Some [%string "%{Int.to_string (List.length steps)} steps"]);
  let status = Hashtbl.create (module String) in
  (* Seed with already-done steps (postcondition passes) *)
  List.iter steps ~f:(fun s ->
      let out = s.output_dir in
      if Stdlib.Sys.file_exists out && s.check_post ~output_dir:out then
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
    | Some Failed -> (match ns with Done -> Done | _ -> Failed)
  in
  List.iter steps ~f:(fun s ->
      let ns = match Hashtbl.find run_status s.tag with
        | Some Step_done -> Done
        | Some Step_failed -> Failed
        | Some Step_skipped -> Skipped
        | None -> Skipped
      in
      Hashtbl.set tbl ~key:s.tag ~data:ns;
      let canonical = string_of_rule s.rule in
      if not (String.equal s.tag canonical) then
        Hashtbl.update tbl canonical ~f:(fun prev -> merge_status prev ns));
  tbl

(* ── Shared command templates ──
   These generate shell commands for common action patterns.
   Project specs use these instead of writing raw shell strings. *)

(* fetch_lib: install a system package and write marker *)
let fetch_lib_cmd pm (spec : Canary_store.system_package_spec) ~output_dir =
  [%string "%{Canary_store.system_install_cmd pm spec} && echo 'installed' > %{output_dir}/lib.ok"]

(* fetch_binding: install an opam package + ocamlfind, then write marker.
   We add ocamlfind explicitly because some bindings (e.g. ssl, dune-only
   pkgs) don't pull it transitively, but probe_ocaml_cmd uses
   `ocamlfind ocamlopt` to compile probes. Bindings that DO pull ocamlfind
   (e.g. zarith) treat the second install as a no-op. *)
let fetch_binding_cmd (spec : Canary_toolchain.opam_package_spec) ~output_dir =
  [%string "%{Canary_toolchain.opam_install_cmd spec} && eval $(opam env) && opam install -y ocamlfind && echo 'installed' > %{output_dir}/binding.ok"]

(* probe_binding (simple): compile and run an OCaml example against an opam package *)
let probe_ocaml_cmd ~binding_lib ~example ~target ~output_dir =
  (* On failure (compile or run), dump probe.log to stdout and re-raise the
     original exit code. Without this, CI step failures show only "exit 127"
     with no context — the actual ocamlfind / dynamic-link error is hidden in
     the file. Successful runs print probe.log too (cheap, useful confirmation). *)
  [%string {|eval $(opam env)
ocamlfind ocamlopt -package %{binding_lib} -linkpkg %{example} -o %{output_dir}/%{target} > %{output_dir}/probe.log 2>&1 && %{output_dir}/%{target} >> %{output_dir}/probe.log 2>&1
RC=$?
cat %{output_dir}/probe.log
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

let default_check_post rule ~output_dir =
  has_file ~output_dir (marker_of_rule rule)

let out_of ~root ~project ~tag =
  output_dir_for ~root ~project ~tag

let mk_step ~root ~project ~cache_project ~tag ?output_tag ~rule ~deps ~cmd
    ?(expectation = Expect_success) ?(symbol_check = None) ~check_post () =
  let output_tag = Option.value output_tag ~default:tag in
  let output_dir = output_dir_for ~root ~project ~tag:output_tag in
  { tag;
    cache_key = cache_project ^ ":" ^ tag;
    output_tag;
    output_dir;
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
  let mk_summary ~parent_tag ~rule ~tag_suffix ~filename ~summary_cmd =
    let tag = parent_tag ^ tag_suffix in
    let check_post ~output_dir = has_file ~output_dir filename in
    mk_step ~root ~project ~cache_project ~tag
      ~output_tag:parent_tag ~rule
      ~deps:[ parent_tag ]
      ~cmd:summary_cmd ~check_post ~expectation:Expect_success
      ~symbol_check:None ()
  in
  (* A summary attached to a parent step: (tag suffix, filename, command).
     OCaml bindings get two: mli (semantic) and stub (C-symbol consumer). *)
  let prepend_note (note : string option) (cmd : output_dir:string -> string) =
    match note with
    | None -> cmd
    | Some n -> fun ~output_dir -> [%string "%{n}\n%{cmd ~output_dir}"]
  in
  let auto_binding_summaries rule
      : (string * string * (output_dir:string -> string)) list =
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
            prepend_note spec.summary_note (fun ~output_dir ->
              Canary_artifact_lang.mli_summary_opam_pkg_cmd
                ~pkg ~watchlist:wl ~output_dir ())
          in
          let prefix =
            match api.native_api.symbol_prefixes with
            | p :: _ -> p
            | [] -> ""
          in
          let stub =
            prepend_note spec.summary_note (fun ~output_dir ->
              Canary_artifact_lang.stub_summary_opam_pkg_cmd
                ~pkg ~prefix ~watchlist:[] ~output_dir ())
          in
          [ ("_summary", "summary.json", mli);
            ("_stub_summary", "stub_summary.json", stub) ]
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
            prepend_note spec.summary_note (fun ~output_dir ->
              Canary_artifact_lang.python_summary_cmd
                ~pkg ~watchlist:wl ~output_dir ())
          in
          [ ("_summary", "summary.json", py) ]
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
            ~filename:"summary.json" ~summary_cmd:c ]
    | None ->
        let summaries = auto_binding_summaries rule in
        if List.is_empty summaries then [ base_step ]
        else
          base_step ::
          List.map summaries ~f:(fun (tag_suffix, filename, summary_cmd) ->
              mk_summary ~parent_tag ~rule ~tag_suffix ~filename ~summary_cmd)
  in
  (* scan_source: verifies api_source header/binding claims post-fetch.
     Shares fetch_source's output dir; configure/build depend on it. *)
  let mk_scan_source ~fetch_tag scan_cmd =
    let check_post ~output_dir = has_file ~output_dir "scan.ok" in
    mk_step ~root ~project ~cache_project ~tag:"scan_source"
      ~output_tag:fetch_tag ~rule:(Fetch Source)
      ~deps:[ fetch_tag ]
      ~cmd:scan_cmd ~check_post ~expectation:Expect_success
      ~symbol_check:None ()
  in
  List.concat_map (store_rules ~langs) ~f:(fun rule ->
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
                  | None -> fun ~output_dir -> has_file ~output_dir "probe.log"
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
                  | None -> fun ~output_dir -> has_file ~output_dir "probe.log"
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

let dump_run_info ~dir (info : run_info) =
  let path = dir ^ "/run_info.json" in
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

let run_project ?(failfast = false) ?run_info ?cache_path ~root ~project steps =
  let dir = [%string "%{root}/canary/projects/%{project}"] in
  ensure_dir dir;
  (* Dump project spec if provided *)
  (match run_info with
   | Some info ->
       let path = dump_run_info ~dir info in
       Fmt.pr "[run_info] %s@." path
   | None -> ());
  let global_cache = Option.map cache_path ~f:(fun p -> Canary_step_cache.load ~path:p) in
  let log_path = [%string "%{dir}/actions.log"] in
  let logger = create_logger ~log_path in
  let status = run_graph ~failfast ?global_cache logger ~project ~root steps in
  (* Write result diagram — same schema as action_rule.mmd, colored by status *)
  let mmd_path = [%string "%{dir}/result.mmd"] in
  let node_status = result_status_of_run steps status in
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
    List.filter_map steps ~f:(fun s ->
        if String.is_suffix s.tag ~suffix:"_summary" then Some s.rule else None)
    |> List.dedup_and_sort ~compare:Poly.compare
  in
  let oc = Stdlib.open_out mmd_path in
  Stdlib.output_string oc
    (Canary.mermaid_of_action_rule_schema ~status:node_status ~has_scan
       ~summary_rules (store_rules ~langs));
  Stdlib.close_out oc;
  logger.log ~tag:"*" ~event:"diagram" ~detail:(Some mmd_path);
  logger.close ()
