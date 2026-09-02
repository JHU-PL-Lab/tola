(** [Canary_agreement_run] — where the EVIDENCE is found, and the
    on-demand commands that report on it.

    After the per-check split (2026-09-02) this module holds no checks.
    Its three jobs:

    - **locating evidence** — [resolve_variant], [step_path],
      [find_lib_inspect] and friends turn a project/variant/step into the
      cached inspector JSON on disk. This is the CALLER's side of a
      check: a check takes what it needs, and finding it is not its
      business;
    - **shared loading helpers** — [pick_existing],
      [load_watchlist_missing], [name_variants], used by several check
      families;
    - **the on-demand commands** — [run_for_project] (`canary compat`)
      and [verify_for_project] (`canary verify`), which report outside a
      run.

    The checks themselves live one per family in [canary_chk_*.ml], each
    stating its category, its standing and its falsifier; the table that
    collects them is [Canary_agreement_registry]. *)

open Base
open Canary_agreement


(* ── Reporting ── *)

let print_result ~(stub : stub_inspect) ~(lib : native_inspect) result =
  Fmt.pr "stub:     %s (%d required symbols)@."
    stub.path (List.length stub.requires);
  Fmt.pr "lib:      %s (%d defined symbols)@.@."
    lib.path (List.length lib.symbols);
  match result with
  | Compatible ->
      Fmt.pr "PREDICTION: COMPATIBLE — every required symbol is provided.@."
  | Compatible_lag { required; provided } ->
      Fmt.pr
        "PREDICTION: COMPATIBLE — every required symbol is provided, BUT the\n\
        \  consumer covers only %d/%d — POSSIBLY OUT-OF-DATE (a small consumer\n\
        \  surface may be by design or lag; warning only, not a failure).@."
        required provided
  | Missing { symbols } ->
      Fmt.pr "PREDICTION: INCOMPATIBLE — %d required symbol(s) missing:@."
        (List.length symbols);
      List.iter symbols ~f:(fun s -> Fmt.pr "  - %s@." s)
  | Unknown ->
      Fmt.pr "PREDICTION: UNKNOWN — one side has no usable symbol data.@.";
      Fmt.pr "  stub.requires: %d, lib.symbols: %d@."
        (List.length stub.requires) (List.length lib.symbols)

let run ~stub_path ~lib_path =
  let stub = load_stub stub_path in
  let lib = load_native lib_path in
  let result = check_c_compat ~binding_stub:stub ~native_lib:lib in
  print_result ~stub ~lib result;
  match result with
  | Compatible | Compatible_lag _ | Unknown -> 0
  | Missing _ -> 1

(* ── Convenience: locate cached summaries for a (project, variant) pair ── *)

(* v3 layout: projects/{project}/{step_dir}/file_{variant_id}.ext
   step_dir = Canary_basic.step_dir_of_tag (e.g. "pack_binding/ocaml").
   variant_id is a filename suffix, not a subdir.
   For single-variant projects (variant_id = ""), filenames have no suffix.

   Resolve a variant arg to (project_dir, resolved_variant_id).
   Expands prefix matches: "dev" → "dev_ab43cb8" (most-recent by mtime)
   by scanning for variant-suffixed summary files in known step dirs.
   Returns None only when project_dir does not exist. *)
let resolve_variant ~root ~project variant =
  let project_dir = [%string "%{root}/_out/canary/projects/%{project}"] in
  if not (Stdlib.Sys.file_exists project_dir && Stdlib.Sys.is_directory project_dir)
  then None
  else if String.is_empty variant then
    Some (project_dir, "")
  else begin
    let find_variant_in_step step_dir_name =
      let step_dir = [%string "%{project_dir}/%{step_dir_name}"] in
      if not (Stdlib.Sys.file_exists step_dir && Stdlib.Sys.is_directory step_dir)
      then None
      else begin
        let exact_file = [%string "summary_%{variant}.json"] in
        if Stdlib.Sys.file_exists [%string "%{step_dir}/%{exact_file}"] then
          Some variant
        else begin
          let prefix = [%string "summary_%{variant}_"] in
          let candidates =
            Stdlib.Sys.readdir step_dir
            |> Array.to_list
            |> List.filter_map ~f:(fun f ->
                if String.is_prefix f ~prefix && String.is_suffix f ~suffix:".json" then
                  let tail = String.chop_prefix_exn f ~prefix in
                  let id_part = String.chop_suffix_exn tail ~suffix:".json" in
                  Some ([%string "%{step_dir}/%{f}"], [%string "%{variant}_%{id_part}"])
                else None)
            |> List.filter ~f:(fun (p, _) -> Stdlib.Sys.file_exists p)
          in
          match candidates with
          | [] -> None
          | xs ->
              let with_mtime = List.map xs ~f:(fun (p, d) ->
                  ((Unix.stat p).st_mtime, d))
              in
              let sorted = List.sort with_mtime
                  ~compare:(fun (a, _) (b, _) -> Float.compare b a) in
              Some (snd (List.hd_exn sorted))
        end
      end
    in
    let step_candidates = [
      "build_lib"; "probe_lib";
      "pack_binding/ocaml"; "fetch_binding/ocaml"; "build_binding/ocaml";
      "fetch_binding/python"; "build_binding/python";
      "probe_binding/ocaml"; "probe_binding/python";
    ] in
    (* A5 layout (2026-08-05): generic-runner variant_ids are SCENARIO ids
       (e.g. "lib-built-dev_python_binding-fetched_source-fetched"), so the
       legacy prefix rule above ("dev" → "dev_<hash>") finds nothing in a
       post-A5 cache. Second pass: collect every variant id embedded in the
       step dirs' JSON names (known base prefixes stripped) and pick the
       newest id CONTAINING the requested token — with the fetch-chain
       aliases ("stable"/"19" name a chain whose id says "lib-fetched":
       a Fetched artifact is version-ambient, so its channel never appears
       in the scenario id). "dev" matches "lib-built-dev…" by substring. *)
    let scenario_needle =
      match variant with
      | "stable" | "19" | "fetched" -> "lib-fetched"
      | v -> v
    in
    let scenario_ids_in_step step_dir_name =
      let step_dir = [%string "%{project_dir}/%{step_dir_name}"] in
      match Stdlib.Sys.readdir step_dir with
      | exception _ -> []
      | files ->
          let bases =
            [ "summary_stub_"; "summary_"; "inspect_mli_"; "inspect_stub_";
              "inspect_cmi_"; "inspect_" ]
          in
          Array.to_list files
          |> List.filter_map ~f:(fun f ->
                 if not (String.is_suffix f ~suffix:".json") then None
                 else
                   List.find_map bases ~f:(fun b ->
                       match String.chop_prefix f ~prefix:b with
                       | Some rest ->
                           let id = String.chop_suffix_exn rest ~suffix:".json" in
                           if String.is_substring id ~substring:scenario_needle
                           then
                             Some
                               ( (Unix.stat [%string "%{step_dir}/%{f}"]).st_mtime,
                                 id )
                           else None
                       | None -> None))
    in
    let resolved =
      match List.find_map step_candidates ~f:find_variant_in_step with
      | Some v -> Some v
      | None -> (
          match List.concat_map step_candidates ~f:scenario_ids_in_step with
          | [] -> None
          | ids ->
              List.sort ids ~compare:(fun (a, _) (b, _) -> Float.compare b a)
              |> List.hd
              |> Option.map ~f:snd)
    in
    Some (project_dir, Option.value resolved ~default:variant)
  end

(* Build a step-output path in the v3 layout.
   step_dir_of_tag converts e.g. "probe_binding_ocaml" → "probe_binding/ocaml".
   variant_id is encoded as a filename suffix (e.g. "probe_19.log"). *)
let step_path ~project_dir ~variant_id step rel =
  let step_d = Canary_basic.step_dir_of_tag step in
  let rel_vk = Canary_basic.variant_file ~variant_key:variant_id rel in
  [%string "%{project_dir}/%{step_d}/%{rel_vk}"]

let step_dir ~project_dir step =
  let step_d = Canary_basic.step_dir_of_tag step in
  [%string "%{project_dir}/%{step_d}"]

(* Pick the first existing probe_lib*/summary.json. *)
let find_lib_inspect ~project_dir ~variant_id =
  let candidates = [
    "build_lib";  (* tiny: lib inspect lives here (Phase 14d onward) *)
    "probe_lib"; "probe_lib_apt"; "probe_lib_brew"; "probe_lib_staged"
  ] in
  List.find_map candidates ~f:(fun step ->
      let d = step_dir ~project_dir step in
      let fname = Canary_basic.filename ~variant_key:variant_id ~base:"inspect" ~ext:"json" in
      let p = d ^ "/" ^ fname in
      if Stdlib.Sys.file_exists p then Some p else None)

(* OCaml binding summaries (mli + stub) are written by the install step —
   either Fetch (Binding OCaml) → fetch_binding/ocaml/, or
   Publish (Binding OCaml) → pack_binding/ocaml/. Try both. *)
let find_ocaml_install_dir ~project_dir =
  let candidates = [ "pack_binding_ocaml"; "fetch_binding_ocaml" ] in
  List.find_map candidates ~f:(fun step ->
      let p = step_dir ~project_dir step in
      if Stdlib.Sys.file_exists p && Stdlib.Sys.is_directory p
      then Some p else None)

(* Python binding summary is at fetch_binding/python/summary_{vk}.json. *)
let find_python_inspect ~project_dir ~variant_id =
  let d = step_dir ~project_dir "fetch_binding_python" in
  let fname = Canary_basic.filename ~variant_key:variant_id ~base:"inspect" ~ext:"json" in
  let p = d ^ "/" ^ fname in
  if Stdlib.Sys.file_exists p then Some p else None

let find_stub_inspect ~project_dir ~variant_id =
  Option.bind (find_ocaml_install_dir ~project_dir) ~f:(fun dir ->
      let fname = Canary_basic.filename ~variant_key:variant_id ~base:"inspect_stub" ~ext:"json" in
      let p = dir ^ "/" ^ fname in
      if Stdlib.Sys.file_exists p then Some p else None)

let find_mli_inspect ~project_dir ~variant_id =
  Option.bind (find_ocaml_install_dir ~project_dir) ~f:(fun dir ->
      let fname = Canary_basic.filename ~variant_key:variant_id ~base:"inspect" ~ext:"json" in
      let p = dir ^ "/" ^ fname in
      if Stdlib.Sys.file_exists p then Some p else None)

let run_for_project ~root ~project ~variant =
  match resolve_variant ~root ~project variant with
  | None ->
      Fmt.epr "compat: no project dir for %s under _out/canary/projects/@." project;
      2
  | Some (project_dir, variant_id) ->
      let stub_path = find_stub_inspect ~project_dir ~variant_id in
      let lib_path = find_lib_inspect ~project_dir ~variant_id in
      (match stub_path, lib_path with
       | None, _ ->
           Fmt.epr "compat: no inspect_stub.json under %s/pack_binding/ocaml/@."
             project_dir;
           Fmt.epr "  (run `canary action %s` first to populate the cache)@." project;
           2
       | _, None ->
           Fmt.epr "compat: no probe_lib*/summary.json under %s/@." project_dir;
           2
       | Some stub_p, Some lib_p ->
           Fmt.pr "(using cached summaries for %s/%s)@." project variant_id;
           run ~stub_path:stub_p ~lib_path:lib_p)

(* ── Verification: prediction vs probe outcome ── *)

(* Match a watchlist-missing entry against a probe.log. Tries the full path,
   the path without the top-level package component, and the last component.
   Returns the matched substring (if any). *)
let match_in_log ~log entry =
  let parts = String.split entry ~on:'.' in
  let candidates =
    entry ::
    (match parts with
     | _ :: rest when List.length rest >= 1 ->
         [ String.concat ~sep:"." rest ]
     | _ -> [])
    @ (match List.last parts with Some last -> [ last ] | None -> [])
  in
  List.find candidates ~f:(fun c -> String.is_substring log ~substring:c)

let read_file_or_empty path =
  if Stdlib.Sys.file_exists path
  then Stdlib.In_channel.with_open_text path Stdlib.In_channel.input_all
  else ""

let load_mli_missing ~project_dir ~variant_id =
  match find_mli_inspect ~project_dir ~variant_id with
  | None -> []
  | Some p ->
      let j = Yojson.Basic.from_file p in
      match field j "watchlist" with
      | Some wl -> get_string_list wl "missing"
      | None -> []

(* Variants of a dotted name suitable for substring matching against a
   probe.log: full path, suffix without top-level package prefix, last
   component. Same logic for OCaml ("Llvm.Opcode.UncondBr" → also
   "Opcode.UncondBr" and "UncondBr") and Python ("z3.Solver" → also
   "Solver"). *)
let name_variants e =
  let parts = String.split e ~on:'.' in
  let suffix_no_top = match parts with
    | _ :: (_ :: _ as rest) -> [ String.concat ~sep:"." rest ]
    | _ -> []
  in
  let last = match List.last parts with Some l -> [ l ] | None -> [] in
  e :: suffix_no_top @ last

let load_watchlist_missing path =
  if not (Stdlib.Sys.file_exists path) then []
  else
    let j = Yojson.Basic.from_file path in
    match field j "watchlist" with
    | Some wl -> get_string_list wl "missing"
    | None -> []

let pick_existing ~resolve paths =
  List.find_map paths ~f:(fun rel ->
    let abs = resolve rel in
    if Stdlib.Sys.file_exists abs then Some abs else None)

let probe_log_inspect log =
  let lines = String.split_lines log in
  let line_count = List.length lines in
  let head = List.take lines 4 |> String.concat ~sep:"\n" in
  (line_count, head)

let verify_for_project ~root ~project ~variant =
  match resolve_variant ~root ~project variant with
  | None ->
      Fmt.epr "verify: no project dir for %s under _out/canary/projects/@." project;
      2
  | Some (project_dir, variant_id) ->
      Fmt.pr "=== Compat verification: %s/%s ===@.@." project variant_id;
      Fmt.pr "Project dir: %s  variant: %s@.@." project_dir
        (if String.is_empty variant_id then "(single-variant)" else variant_id);

      (* L3 (OCaml mli) prediction *)
      let mli_missing = load_mli_missing ~project_dir ~variant_id in
      Fmt.pr "L3 (OCaml mli) prediction:@.";
      if List.is_empty mli_missing then
        Fmt.pr "  watchlist missing: (none) — predicts SUCCESS at OCaml level@."
      else (
        Fmt.pr "  watchlist missing: %d entry/entries@."
          (List.length mli_missing);
        List.iter mli_missing ~f:(fun e -> Fmt.pr "    - %s@." e);
        Fmt.pr "  → predicts FAIL referencing one of these names@.");

      (* L3 (Python attrs) prediction *)
      let py_missing =
        match find_python_inspect ~project_dir ~variant_id with
        | None -> []
        | Some p -> load_watchlist_missing p
      in
      Fmt.pr "@.L3 (Python attrs) prediction:@.";
      (match find_python_inspect ~project_dir ~variant_id with
       | None -> Fmt.pr "  (no Python summary cached at fetch_binding_python/)@."
       | Some _ ->
           if List.is_empty py_missing then
             Fmt.pr "  watchlist missing: (none) — predicts SUCCESS at Python level@."
           else (
             Fmt.pr "  watchlist missing: %d entry/entries@."
               (List.length py_missing);
             List.iter py_missing ~f:(fun e -> Fmt.pr "    - %s@." e);
             Fmt.pr "  → predicts FAIL referencing one of these names@."));

      (* L0 (C symbols) prediction *)
      let stub_path = find_stub_inspect ~project_dir ~variant_id in
      let lib_path = find_lib_inspect ~project_dir ~variant_id in
      let c_result = match stub_path, lib_path with
        | Some s, Some l ->
            let stub = load_stub s in
            let lib = load_native l in
            Some (stub, lib, check_c_compat ~binding_stub:stub ~native_lib:lib)
        | _ -> None
      in
      Fmt.pr "@.L0 (C symbols) prediction:@.";
      let c_missing = match c_result with
        | None -> Fmt.pr "  (summaries unavailable)@."; []
        | Some (stub, lib, Compatible) ->
            Fmt.pr "  binding requires %d symbols, lib provides %d@."
              (List.length stub.requires) (List.length lib.symbols);
            Fmt.pr "  → predicts COMPATIBLE at C ABI level@.";
            []
        | Some (_stub, _lib, Compatible_lag { required; provided }) ->
            Fmt.pr "  binding requires %d symbols, lib provides %d@."
              required provided;
            Fmt.pr
              "  → predicts COMPATIBLE, but POSSIBLY OUT-OF-DATE (consumer\n\
               \     covers only %d/%d — by design or lag; warning only)@."
              required provided;
            []
        | Some (stub, lib, Missing { symbols }) ->
            Fmt.pr "  binding requires %d symbols, lib provides %d@."
              (List.length stub.requires) (List.length lib.symbols);
            Fmt.pr "  missing: %d C symbol(s)@." (List.length symbols);
            List.iter symbols ~f:(fun s -> Fmt.pr "    - %s@." s);
            Fmt.pr "  → predicts FAIL referencing one of these symbols@.";
            symbols
        | Some (_, _, Unknown) ->
            Fmt.pr "  (UNKNOWN — one side has no usable symbol data)@.";
            []
      in

      (* Probe.log analysis *)
      let read_log step =
        read_file_or_empty (step_path ~project_dir ~variant_id step "probe.log")
      in
      let ocaml_log = read_log "probe_binding_ocaml" in
      let python_log = read_log "probe_binding_python" in
      let print_log_section name log =
        let line_count, head = probe_log_inspect log in
        Fmt.pr "@.%s probe.log analysis (%d lines):@." name line_count;
        if String.is_empty log then Fmt.pr "  (empty or missing)@."
        else (
          Fmt.pr "  head:@.";
          List.iter (String.split_lines head) ~f:(fun l ->
              Fmt.pr "    | %s@." l))
      in
      print_log_section "OCaml" ocaml_log;
      if not (String.is_empty python_log) then
        print_log_section "Python" python_log;

      (* Cross-reference predictions vs log *)
      Fmt.pr "@.Verdict:@.";
      let confirmed_in log entries =
        List.filter_map entries ~f:(fun e ->
            Option.map (match_in_log ~log e) ~f:(fun m -> (e, m)))
      in
      let unconfirmed_in log entries =
        List.filter entries ~f:(fun e ->
            Option.is_none (match_in_log ~log e))
      in
      let l3_ocaml_confirmed = confirmed_in ocaml_log mli_missing in
      let l3_ocaml_unconfirmed = unconfirmed_in ocaml_log mli_missing in
      let l3_python_confirmed = confirmed_in python_log py_missing in
      let l3_python_unconfirmed = unconfirmed_in python_log py_missing in
      let l0_confirmed =
        List.filter c_missing ~f:(fun s ->
            String.is_substring ocaml_log ~substring:s)
      in
      let l0_unconfirmed =
        List.filter c_missing ~f:(fun s ->
            not (String.is_substring ocaml_log ~substring:s))
      in

      let print_verdict_layer layer ~log ~predicted ~confirmed ~unconfirmed =
        match predicted, confirmed, unconfirmed with
        | [], _, _ ->
            Fmt.pr "  %s: predicted COMPATIBLE — %s@." layer
              (if String.is_empty log then "(no probe log to verify against)"
               else "no failure expected at this layer")
        | _, [], _ ->
            Fmt.pr "  %s: prediction NOT visible in log — probe may have \
                    failed for a different reason, or didn't reach this layer@." layer
        | _, _, [] ->
            Fmt.pr "  %s: CONFIRMED — all predicted entries appear in probe.log@." layer
        | _ ->
            Fmt.pr "  %s: PARTIAL — %d/%d predicted entries confirmed@."
              layer (List.length confirmed)
              (List.length predicted)
      in
      print_verdict_layer "L3 (OCaml)" ~log:ocaml_log
        ~predicted:mli_missing ~confirmed:(List.map l3_ocaml_confirmed ~f:fst)
        ~unconfirmed:l3_ocaml_unconfirmed;
      print_verdict_layer "L3 (Python)" ~log:python_log
        ~predicted:py_missing ~confirmed:(List.map l3_python_confirmed ~f:fst)
        ~unconfirmed:l3_python_unconfirmed;
      print_verdict_layer "L0 (C ABI)" ~log:ocaml_log
        ~predicted:c_missing ~confirmed:l0_confirmed
        ~unconfirmed:l0_unconfirmed;
      List.iter (l3_ocaml_confirmed @ l3_python_confirmed) ~f:(fun (entry, matched) ->
          if not (String.equal entry matched) then
            Fmt.pr "    note: '%s' matched as substring '%s'@." entry matched);
      0

(* ── M2 step 2+3: the contract×lang×mechanism input template ──
   WHAT each contract's predict closure reads (input KINDS), with the
   STANDARD inspect-file paths per language (tiny's convention: inspect
   attached to build_binding/build_lib, files inspect.json /
   inspect_mli.json / inspect_attrs.json). A project whose layout
   deviates (z3's fetch-step attrs inspect, llvm's summary_stub.json +
   location-suffixed probe_lib) keeps hand-writing those rows — the
   template covers the common case, not every case.

   Mechanism refinement (dynamic bindings have no stub input) comes
   with the mechanism axis (M2 step 3). *)

