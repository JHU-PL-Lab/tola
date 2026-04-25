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
   - Lang_pm: depends on pack_binding or fetch_binding (PM-installed)
   - System_pm: depends on fetch_lib (system-level probe)
   Other locations can be added as needed. *)

let tag_of_probe_location = function
  | Build_tree -> "probe_binding_build"
  | Lang_pm -> "probe_binding_pkg"
  | System_pm -> "probe_binding_sys"
  | Wild s -> [%string "probe_binding_%{s}"]

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

type step_expectation =
  | Expect_success
  | Expect_failure of {
      contains_any : string list;
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
  configure : (output_dir:string -> string) option;
  build_lib : (output_dir:string -> string) option;
  build_binding : (output_dir:string -> string) option;
  build_app : (output_dir:string -> string) option;
  fetch_lib : (output_dir:string -> string) option;
  fetch_binding : (output_dir:string -> string) option;
  fetch_app : (output_dir:string -> string) option;
  pack_lib : (output_dir:string -> string) option;
  pack_binding : (output_dir:string -> string) option;
  pack_app : (output_dir:string -> string) option;
  probe_lib : (output_dir:string -> string) option;
  probe_binding : (location * (output_dir:string -> string)) list;
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
  (* Optional per-rule artifact summary command. When present, derive_steps
     emits an extra step that runs after the base step and writes summary.json.
     For multi-probe rules (Probe Binding with several locations), the loc
     parameter carries the specific location so callers can return different
     summaries per variant (e.g., opam pkg vs pip pkg). For single-location
     rules, loc is None.
     See doc/canary/artifact_summary_design.md. *)
  summary : rule -> location option -> (output_dir:string -> string) option;
}

let empty_script_spec = {
  fetch_source = None;
  configure = None;
  build_lib = None; build_binding = None; build_app = None;   fetch_lib = None; fetch_binding = None; fetch_app = None;
  pack_lib = None; pack_binding = None; pack_app = None;
  probe_lib = None; probe_binding = [];
  probe_app = None;
  check_post = (fun _ -> None);
  expectation = (fun _ _ -> Expect_success);
  symbol_check = (fun _ -> None);
  summary = (fun _ _ -> None);
}

(* Remove build-from-source actions. Keeps fetch + probe only. *)
let no_source spec =
  { spec with fetch_source = None; configure = None;
    build_lib = None; build_binding = None; build_app = None;     pack_lib = None; pack_binding = None; pack_app = None }

(* Look up the script for a rule *)
let script_of_rule spec = function
  | Fetch Source -> spec.fetch_source
  | Configure -> spec.configure
  | Fetch Lib -> spec.fetch_lib
  | Fetch Binding -> spec.fetch_binding
  | Fetch App -> spec.fetch_app
  | Build_lib -> spec.build_lib
  | Build_binding -> spec.build_binding
  | Build_app -> spec.build_app
  | Publish Lib -> spec.pack_lib
  | Publish Binding -> spec.pack_binding
  | Publish App -> spec.pack_app
  | Probe Lib -> spec.probe_lib
  | Probe Binding ->
      (* Single-probe compat: if exactly one entry, use its cmd.
         Multiple entries are handled by derive_steps expansion. *)
      (match spec.probe_binding with
       | [ (_, cmd) ] -> Some cmd
       | _ -> None)
  | Probe App -> spec.probe_app
  | Publish Source | Probe Source -> None

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
  (* Mark all store_rules actions as Not_in_spec initially *)
  List.iter store_rules ~f:(fun r ->
      Hashtbl.set tbl ~key:(string_of_rule r) ~data:Not_in_spec);
  (* Override with actual run results *)
  List.iter steps ~f:(fun s ->
      let ns = match Hashtbl.find run_status s.tag with
        | Some Step_done -> Done
        | Some Step_failed -> Failed
        | Some Step_skipped -> Skipped
        | None -> Skipped
      in
      Hashtbl.set tbl ~key:s.tag ~data:ns);
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
let fetch_binding_cmd (spec : Canary_toolchain_ocaml.opam_package_spec) ~output_dir =
  [%string "%{Canary_toolchain_ocaml.opam_install_cmd spec} && eval $(opam env) && opam install -y ocamlfind && echo 'installed' > %{output_dir}/binding.ok"]

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
  | Fetch Lib -> "lib.ok"
  | Fetch Binding -> "binding.ok"
  | Fetch App -> "app.ok"
  | Build_lib | Build_binding | Build_app -> "build.ok"
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
  match rule with
  | Fetch _ -> []
  | Configure ->
      List.filter_opt [
        if has (Fetch Source) then Some (tag (Fetch Source)) else None
      ]
  | Build_lib ->
      List.filter_opt [
        (* Prefer Configure if present, else Fetch Source directly *)
        if has Configure then Some (tag Configure)
        else if has (Fetch Source) then Some (tag (Fetch Source))
        else None
      ]
  | Build_binding ->
      let lib_dep =
        if has Build_lib then Some (tag Build_lib)
        else if has (Fetch Lib) then Some (tag (Fetch Lib))
        else None
      in
      List.filter_opt [
        if has Configure then Some (tag Configure)
        else if has (Fetch Source) then Some (tag (Fetch Source))
        else None;
        lib_dep;
      ]
  | Build_app ->
      let binding_dep =
        if has Build_binding then Some (tag Build_binding)
        else if has (Fetch Binding) then Some (tag (Fetch Binding))
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
        | Lib -> if has Build_lib then Some Build_lib else Some (Fetch Lib)
        | Binding -> if has Build_binding then Some Build_binding else Some (Fetch Binding)
        | App -> if has Build_app then Some Build_app else Some (Fetch App)
        | Source -> Some (Fetch Source)
      in
      let produce_dep =
        Option.bind produce_rule ~f:(fun r ->
            if has r then Some (tag r) else None)
      in
      (* probe_binding and probe_app also need a runtime lib *)
      let runtime_lib_dep = match rule with
        | Probe (Binding | App) ->
            if has (Fetch Lib) then Some (tag (Fetch Lib))
            else if has Build_lib then Some (tag Build_lib)
            else None
        | _ -> None
      in
      List.filter_opt [ produce_dep; runtime_lib_dep ]

(* Derive deps for a split probe variant.
   raw depends on build_binding; pkg depends on pack_binding or fetch_binding.
   Both need a runtime lib. *)
let deps_of_split_probe spec variant =
  let has r = Option.is_some (script_of_rule spec r) in
  let tag r = string_of_rule r in
  let produce_dep = match variant with
    | `Raw ->
        if has Build_binding then Some (tag Build_binding) else None
    | `Pkg ->
        if has (Publish Binding) then Some (tag (Publish Binding))
        else if has (Fetch Binding) then Some (tag (Fetch Binding))
        else None
  in
  let runtime_lib_dep =
    if has (Fetch Lib) then Some (tag (Fetch Lib))
    else if has Build_lib then Some (tag Build_lib)
    else None
  in
  List.filter_opt [ produce_dep; runtime_lib_dep ]

let derive_steps ~root ~project ?(cache_project = project) (spec : script_spec) : action_step list =
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
  (* Optional follow-up step that writes summary.json for an artifact.
     Writes into the PARENT's output_dir (alongside probe.log) rather than
     creating a separate <parent>_summary/ directory. Depends on parent;
     check_post just needs summary.json to exist in that shared dir. *)
  let mk_summary ~parent_tag ~rule ~summary_cmd =
    let tag = parent_tag ^ "_summary" in
    let check_post ~output_dir = has_file ~output_dir "summary.json" in
    mk_step ~root ~project ~cache_project ~tag
      ~output_tag:parent_tag ~rule
      ~deps:[ parent_tag ]
      ~cmd:summary_cmd ~check_post ~expectation:Expect_success
      ~symbol_check:None ()
  in
  let attach_summary ~parent_tag ~rule ?loc base_step =
    match spec.summary rule loc with
    | None -> [ base_step ]
    | Some cmd -> [ base_step; mk_summary ~parent_tag ~rule ~summary_cmd:cmd ]
  in
  List.concat_map store_rules ~f:(fun rule ->
      let tag = string_of_rule rule in
      if Hashtbl.mem seen tag then []
      else
        (* Probe Binding with multiple probes: expand into one step per entry *)
        match rule with
        | Probe Binding when List.length spec.probe_binding > 1 ->
            Hashtbl.set seen ~key:tag ~data:true;
            List.concat_map spec.probe_binding ~f:(fun (loc, cmd) ->
                let ptag = tag_of_probe_location loc in
                let deps = deps_of_split_probe spec
                    (match loc with
                     | Build_tree -> `Raw | _ -> `Pkg) in
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
                attach_summary ~parent_tag:tag ~rule base)

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
  let oc = Stdlib.open_out mmd_path in
  Stdlib.output_string oc
    (Canary.mermaid_of_action_rule_schema ~status:node_status store_rules);
  Stdlib.close_out oc;
  logger.log ~tag:"*" ~event:"diagram" ~detail:(Some mmd_path);
  logger.close ()
