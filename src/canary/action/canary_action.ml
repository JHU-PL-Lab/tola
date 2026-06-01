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
  build_binding : (Canary_lang.lang * (output_dir:string -> variant_key:string -> string)) list;
  install_lib : (output_dir:string -> variant_key:string -> string) option;
  build_app : (output_dir:string -> variant_key:string -> string) option;
  fetch_lib : (output_dir:string -> variant_key:string -> string) option;
  fetch_binding : (Canary_lang.lang * (output_dir:string -> variant_key:string -> string)) list;
  fetch_app : (output_dir:string -> variant_key:string -> string) option;
  pack_lib : (output_dir:string -> variant_key:string -> string) option;
  pack_binding : (Canary_lang.lang * (output_dir:string -> variant_key:string -> string)) list;
  pack_app : (output_dir:string -> variant_key:string -> string) option;
  probe_lib : (location * (output_dir:string -> variant_key:string -> string)) list;
  probe_binding : (Canary_lang.lang * location * (output_dir:string -> variant_key:string -> string)) list;
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
  (** Per-language user-facing package name(s) carrying the
      {i s4 user_binding} surface for this project. Used by
      [derive_steps] to auto-generate an inspector step after each
      Probe (Binding lang) step:
      - OCaml  → [mli_inspect_opam_pkg_cmd ~pkg ~watchlist:(binding_api[lang].module_watchlist)]
                 (produces the {i bo4 user_binding_ocaml.mli} JSON)
      - Python → [python_inspect_cmd ~pkg ~watchlist:(binding_api[lang].module_watchlist)]
                 (produces the {i bpe2 user_binding_cext.py} or
                 {i bpc2 user_binding_ctypes.py} JSON depending on
                 which mechanism the package ships as)

      Example: z3 sets [[(OCaml, "z3"); (Python, "z3")]]; llvm sets
      [[(OCaml, "llvm"); (Python, "llvmlite.binding")]]. Typical
      projects set this and omit binding arms from [summary].

      Renamed 2026-05-28 (Phase 4 Pass 2) from [binding_summary] —
      the old name reflected the pre-Phase-2 "summary" terminology
      that became "inspect" everywhere else. *)
  binding_user_facing_pkg : (Canary_lang.lang * string) list;
  (* Optional note prepended to auto-generated binding summaries (shell echo).
     Used by stable-fetch specs to warn that watchlists were declared for the
     dev version. Ignored when the explicit [summary] override is used. *)
  inspect_note : string option;
  (* Explicit per-rule inspect override. Wins over auto-generation.
     Use for native probe summaries (lib path is always project-specific)
     or any case needing custom logic beyond what api_source provides.
     loc is Some _ for per-location probe variants, None for single-location rules.
     See doc/canary/design/api_surface.md. *)
  inspect : rule -> location option -> (output_dir:string -> variant_key:string -> string) option;
  (* Human-readable artifact name per kind for diagram labels. *)
  artifact_name : artifact_kind -> string option;
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
  binding_user_facing_pkg = [];
  inspect_note = None;
  inspect = (fun _ _ -> None);
  artifact_name = (fun _ -> None);
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


(* ── Logging (plain text file + console) ── *)




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
  let step_dir = Canary_output_path.step_dir_of_tag tag in
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
                   Path format: "step_tag/file.json" (e.g. "pack_binding_ocaml/inspect_stub.json").
                   v3 layout: step_tag is mapped through step_dir_of_tag for action-first dirs,
                   and the filename is variant-key-qualified (_19.json for variant "19"). *)
                let pick_first_existing rels =
                  List.find_map rels ~f:(fun rel ->
                      let p = match String.lsplit2 rel ~on:'/' with
                        | Some (step_tag, file) ->
                            let step_dir = Canary_output_path.step_dir_of_tag step_tag in
                            let vk_file = Canary_output_path.variant_file
                                ~variant_key:step.variant_id file in
                            step.project_dir ^ "/" ^ step_dir ^ "/" ^ vk_file
                        | None ->
                            let vk_rel = Canary_output_path.variant_file
                                ~variant_key:step.variant_id rel in
                            step.project_dir ^ "/" ^ vk_rel
                      in
                      if Stdlib.Sys.file_exists p then Some p else None)
                in
                let typed_inputs =
                  List.filter_map inputs ~f:(function
                    | C_stub { paths } ->
                        Option.map (pick_first_existing paths) ~f:(fun p ->
                          Canary_compat_run.C_stub p)
                    | Native_lib { paths } ->
                        Option.map (pick_first_existing paths) ~f:(fun p ->
                          Canary_compat_run.Native_lib p)
                    | Ocaml_mli { paths } ->
                        Option.map (pick_first_existing paths) ~f:(fun p ->
                          Canary_compat_run.Ocaml_mli p)
                    | Python_attrs { paths } ->
                        Option.map (pick_first_existing paths) ~f:(fun p ->
                          Canary_compat_run.Python_attrs p)
                    | Versioned_symbols { paths } ->
                        Option.map (pick_first_existing paths) ~f:(fun p ->
                          Canary_compat_run.Versioned_symbols p)
                    | Abi_surface { paths } ->
                        Option.map (pick_first_existing paths) ~f:(fun p ->
                          Canary_compat_run.Abi_surface p))
                in
                let derived =
                  Canary_compat_run.predicted_contains_any_v2 typed_inputs
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


(* ── Shared command templates ──
   These generate shell commands for common action patterns.
   Project specs use these instead of writing raw shell strings. *)

(* fetch_lib: install a system package and write marker *)
let fetch_lib_cmd pm (spec : Canary_store.system_package_spec) ~output_dir ~variant_key =
  let lib_ok = Canary_output_path.variant_file ~variant_key "lib.ok" in
  [%string "%{Canary_store.system_install_cmd pm spec} && echo 'installed' > %{output_dir}/%{lib_ok}"]

(* fetch_binding: install an opam package + ocamlfind, then write marker.
   We add ocamlfind explicitly because some bindings (e.g. ssl, dune-only
   pkgs) don't pull it transitively, but probe_ocaml_cmd uses
   `ocamlfind ocamlopt` to compile probes. Bindings that DO pull ocamlfind
   (e.g. zarith) treat the second install as a no-op. *)
let fetch_binding_cmd (spec : Canary_toolchain.opam_package_spec) ~output_dir ~variant_key =
  let binding_ok = Canary_output_path.variant_file ~variant_key "binding.ok" in
  [%string "%{Canary_toolchain.opam_install_cmd spec} && eval $(opam env) && opam install -y ocamlfind && echo 'installed' > %{output_dir}/%{binding_ok}"]

(* probe_binding (simple): compile and run an OCaml example against an opam package *)
let probe_ocaml_cmd ~binding_lib ~example ~target ~output_dir ~variant_key =
  (* On failure (compile or run), dump probe.log to stdout and re-raise the
     original exit code. Without this, CI step failures show only "exit 127"
     with no context — the actual ocamlfind / dynamic-link error is hidden in
     the file. Successful runs print probe.log too (cheap, useful confirmation). *)
  let probe_log = Canary_output_path.variant_file ~variant_key "probe.log" in
  [%string {|eval $(opam env)
ocamlfind ocamlopt -package %{binding_lib} -linkpkg %{example} -o %{output_dir}/%{target} > %{output_dir}/%{probe_log} 2>&1 && %{output_dir}/%{target} >> %{output_dir}/%{probe_log} 2>&1
RC=$?
cat %{output_dir}/%{probe_log}
exit $RC|}]

(* ── Convenience helpers for building steps ── *)


let has_file ~output_dir name =
  Stdlib.Sys.file_exists [%string "%{output_dir}/%{name}"]

(* ── check_post compositors ──
   Thin functions for common check_post patterns used by project specs.
   Each returns a bool; project specs wire them into [script_spec.check_post]. *)

(** Marker file present AND a native .so/.dylib exists at [lib_path]. *)
let check_build_lib ~marker ~lib_path ~output_dir ~variant_key =
  has_file ~output_dir (Canary_output_path.variant_file ~variant_key marker)
  && Canary_artifact_native.exists_native_lib_or_dylib lib_path

(** Marker file present AND an OCaml archive exists at [archive_path]. *)
let check_build_binding ~marker ~archive_path ~output_dir ~variant_key =
  has_file ~output_dir (Canary_output_path.variant_file ~variant_key marker)
  && Canary_artifact_lang.exists_ocaml_archive archive_path

(** All listed marker files exist in [output_dir]. *)
let check_markers markers ~output_dir ~variant_key =
  List.for_all markers ~f:(fun m ->
    has_file ~output_dir (Canary_output_path.variant_file ~variant_key m))

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
  has_file ~output_dir (Canary_output_path.variant_file ~variant_key (marker_of_rule rule))

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

let derive_steps ~root ~project ?(cache_project = project) ?(langs = Canary_lang.[ OCaml ]) (spec : script_spec) : action_step list =
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
     creating a separate <parent>_inspect/ directory. Depends on parent;
     check_post verifies the named file exists in that shared dir.
     [tag_suffix] is appended to parent_tag (e.g. "_inspect", "_stub_inspect");
     [filename] is the basename written by [inspect_cmd] (e.g. "inspect.json",
     "stub_inspect.json"). The cmd is responsible for redirecting to that file. *)
  let mk_inspect ~parent_tag ~rule ~tag_suffix ~base_name ~inspect_cmd =
    let tag = parent_tag ^ tag_suffix in
    (* base_name is the variant-independent base (e.g. "inspect", "inspect_stub").
       The actual filename is base_name + "_" + variant_key + ".json" at run time. *)
    let check_post ~output_dir ~variant_key =
      has_file ~output_dir (Canary_output_path.filename ~variant_key ~base:base_name ~ext:"json")
    in
    mk_step ~root ~project ~cache_project ~tag
      ~output_tag:parent_tag ~rule
      ~deps:[ parent_tag ]
      ~cmd:inspect_cmd ~check_post ~expectation:Expect_success
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
       "inspect"      → summary.json / summary_19.json
       "inspect_stub" → inspect_stub.json / inspect_stub_19.json   (type-first) *)
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
            Canary_artifact_api.binding_watchlist_exn api Canary_lang.OCaml
          in
          let mli =
            prepend_note spec.inspect_note (fun ~output_dir ~variant_key ->
              Canary_artifact_lang.mli_inspect_opam_pkg_cmd
                ~pkg ~watchlist:wl ~output_dir ~variant_key ())
          in
          let prefix =
            match api.native_api.symbol_prefixes with
            | p :: _ -> p
            | [] -> ""
          in
          let stub =
            prepend_note spec.inspect_note (fun ~output_dir ~variant_key ->
              Canary_artifact_lang.stub_inspect_opam_pkg_cmd
                ~pkg ~prefix ~watchlist:[] ~output_dir ~variant_key ())
          in
          [ ("_inspect", "inspect", mli);
            ("_stub_inspect", "inspect_stub", stub) ]
        in
        let python_install_inspect pkg =
          (* Python summary attaches at Fetch (Binding Python) — the install
             step — so the cached summary.json is available before
             Probe (Binding Python) evaluates its (possibly compat-derived)
             expectation. Mirrors the OCaml mli/stub placement. *)
          let wl =
            Canary_artifact_api.binding_watchlist_exn api
              Canary_lang.Python
          in
          let py =
            prepend_note spec.inspect_note (fun ~output_dir ~variant_key ->
              Canary_artifact_lang.python_inspect_cmd
                ~pkg ~watchlist:wl ~output_dir ~variant_key ())
          in
          [ ("_inspect", "inspect", py) ]
        in
        match rule with
        | Fetch (Binding OCaml) | Publish (Binding OCaml) ->
            (match List.Assoc.find spec.binding_user_facing_pkg
                     ~equal:Poly.equal Canary_lang.OCaml with
             | None -> []
             | Some pkg -> ocaml_install_summaries pkg)
        | Fetch (Binding Python) ->
            (match List.Assoc.find spec.binding_user_facing_pkg
                     ~equal:Poly.equal Canary_lang.Python with
             | None -> []
             | Some pkg -> python_install_inspect pkg)
        | _ -> []
  in
  (* spec.inspect is the explicit override (legacy, single-summary). When
     present, it wins and we skip auto generation entirely. *)
  let attach_inspect ~parent_tag ~rule ?loc base_step =
    match spec.inspect rule loc with
    | Some c ->
        [ base_step;
          mk_inspect ~parent_tag ~rule ~tag_suffix:"_inspect"
            ~base_name:"inspect" ~inspect_cmd:c ]
    | None ->
        let summaries = auto_binding_summaries rule in
        if List.is_empty summaries then [ base_step ]
        else
          base_step ::
          List.map summaries ~f:(fun (tag_suffix, base_name, inspect_cmd) ->
              mk_inspect ~parent_tag ~rule ~tag_suffix ~base_name ~inspect_cmd)
  in
  (* scan_source: verifies api_source header/binding claims post-fetch.
     Shares fetch_source's output dir; configure/build depend on it. *)
  let mk_scan_source ~fetch_tag scan_cmd =
    let check_post ~output_dir ~variant_key =
      has_file ~output_dir (Canary_output_path.variant_file ~variant_key "scan.ok")
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
                        (Canary_output_path.variant_file ~variant_key "probe.log")
                in
                let expectation = spec.expectation rule (Some loc) in
                let symbol_check = spec.symbol_check rule in
                let base = mk_step ~root ~project ~cache_project ~tag:ptag ~rule
                  ~deps ~cmd ~check_post ~expectation ~symbol_check () in
                attach_inspect ~parent_tag:ptag ~rule ~loc base)
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
                        (Canary_output_path.variant_file ~variant_key "probe.log")
                in
                let expectation = spec.expectation rule (Some loc) in
                let symbol_check = spec.symbol_check rule in
                let base = mk_step ~root ~project ~cache_project ~tag:ptag ~rule
                  ~deps ~cmd ~check_post ~expectation ~symbol_check () in
                attach_inspect ~parent_tag:ptag ~rule ~loc base)
        | _ ->
            match script_of_rule spec rule with
            | None -> []
            | Some cmd ->
                Hashtbl.set seen ~key:tag ~data:true;
                let base = mk_one ~tag ~rule ~deps:(deps_of_rule spec rule) ~cmd in
                let steps = attach_inspect ~parent_tag:tag ~rule base in
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


(* ── Run-state serialisation ──
   Saves the full step+status snapshot so `canary view` can regenerate
   diagrams/HTML without re-running any build or probe steps. *)

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
