open Base

(* Static compatibility check between a binding's stub archive (consumer side:
   "what C symbols this binding requires from the native lib") and a native
   library's defined-symbols summary (provider side: "what this .so exports").

   Inputs are summary.json files produced by summarize_binding.py --kind stub
   and summarize_native.py --emit-symbols, respectively. Output is a verdict
   on `requires ⊆ provides`.

   This is the C-level half of Step C1 in doc/canary/design/api_compat.md.
   The OCaml-level half is already covered by the mli summary's watchlist
   (e.g. Llvm.Opcode.UncondBr present/missing). Together they form the
   set-inclusion necessary-condition layer (L0/L1) of the compatibility
   lattice from interface.md §15. *)

(* ── Summary loaders ── *)

let load path : Yojson.Basic.t =
  if not (Stdlib.Sys.file_exists path) then (
    Fmt.epr "compat: %s not found@." path;
    Stdlib.exit 2);
  Yojson.Basic.from_file path

let field (j : Yojson.Basic.t) name =
  match j with
  | `Assoc fields -> List.Assoc.find fields ~equal:String.equal name
  | _ -> None

let get_string j name =
  match field j name with Some (`String s) -> s | _ -> ""

let get_string_list j name =
  match field j name with
  | Some (`List xs) ->
      List.filter_map xs ~f:(function `String s -> Some s | _ -> None)
  | _ -> []

(* ── Typed views ── *)

type stub_summary = {
  path : string;
  requires : string list;
}

type native_summary = {
  path : string;
  symbols : string list;  (* defined exports, prefix-filtered if emitted that way *)
}

let load_stub path =
  let j = load path in
  let kind = get_string j "kind" in
  if not (String.equal kind "c_stub") then
    Fmt.epr "compat: warning — expected kind=c_stub, got %s (%s)@." kind path;
  { path = get_string j "path"; requires = get_string_list j "requires" }

let load_native path =
  let j = load path in
  let kind = get_string j "kind" in
  if not (String.equal kind "native") then
    Fmt.epr "compat: warning — expected kind=native, got %s (%s)@." kind path;
  let symbols = get_string_list j "symbols" in
  if List.is_empty symbols then
    Fmt.epr "compat: warning — native summary has no 'symbols' field; was \
             it produced with --emit-symbols? (%s)@." path;
  { path = get_string j "path"; symbols }

(* ── Cross-check ── *)

type compat_result =
  | Compatible
  | Missing of { symbols : string list }
  | Unknown   (* one side lacks the data needed to decide *)

let check_c_compat ~(binding_stub : stub_summary) ~(native_lib : native_summary)
    : compat_result =
  if List.is_empty binding_stub.requires then Unknown
  else if List.is_empty native_lib.symbols then Unknown
  else
    let provided = Set.of_list (module String) native_lib.symbols in
    let missing = List.filter binding_stub.requires
        ~f:(fun s -> not (Set.mem provided s)) in
    if List.is_empty missing then Compatible
    else Missing { symbols = missing }

(* ── Reporting ── *)

let print_result ~(stub : stub_summary) ~(lib : native_summary) result =
  Fmt.pr "stub:     %s (%d required symbols)@."
    stub.path (List.length stub.requires);
  Fmt.pr "lib:      %s (%d defined symbols)@.@."
    lib.path (List.length lib.symbols);
  match result with
  | Compatible ->
      Fmt.pr "PREDICTION: COMPATIBLE — every required symbol is provided.@."
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
  | Compatible | Unknown -> 0
  | Missing _ -> 1

(* ── Convenience: locate cached summaries for a (project, variant) pair ── *)

(* Resolve a variant arg to an actual directory name. If [variant] exists
   under projects/<proj>/, return it; otherwise try to expand "<variant>_*"
   (so "dev" matches "dev_ab43cb8"). Picks the most-recent match by mtime. *)
let resolve_variant_dir ~root ~project variant =
  let base = root ^ "/" ^"_out/canary/projects" ^ "/" ^project in
  let exact = base ^ "/" ^variant in
  if Stdlib.Sys.file_exists exact && Stdlib.Sys.is_directory exact then
    Some exact
  else if Stdlib.Sys.file_exists base && Stdlib.Sys.is_directory base then
    let prefix = variant ^ "_" in
    let candidates =
      Stdlib.Sys.readdir base
      |> Array.to_list
      |> List.filter ~f:(String.is_prefix ~prefix)
      |> List.map ~f:(fun d -> base ^ "/" ^d)
      |> List.filter ~f:(fun p -> Stdlib.Sys.is_directory p)
    in
    match candidates with
    | [] -> None
    | xs ->
        let with_mtime =
          List.map xs ~f:(fun p ->
              let m = (Unix.stat p).st_mtime in
              (p, m))
        in
        let sorted =
          List.sort with_mtime ~compare:(fun (_, a) (_, b) -> Float.compare b a)
        in
        Some (fst (List.hd_exn sorted))
  else None

(* Pick the first existing probe_lib*/summary.json under a variant dir. *)
let find_lib_summary variant_dir =
  let candidates = [
    "probe_lib/summary.json";
    "probe_lib_apt/summary.json";
    "probe_lib_brew/summary.json";
    "probe_lib_staged/summary.json";
  ] in
  List.find_map candidates ~f:(fun rel ->
      let p = variant_dir ^ "/" ^rel in
      if Stdlib.Sys.file_exists p then Some p else None)

(* OCaml binding summaries (mli + stub) are written by the install step —
   either Fetch (Binding OCaml) → fetch_ocaml_binding/, or
   Publish (Binding OCaml) → pack_ocaml_binding/. Try both. *)
let find_ocaml_install_dir variant_dir =
  let candidates = [ "pack_ocaml_binding"; "fetch_ocaml_binding" ] in
  List.find_map candidates ~f:(fun rel ->
      let p = variant_dir ^ "/" ^ rel in
      if Stdlib.Sys.file_exists p && Stdlib.Sys.is_directory p
      then Some p else None)

let find_stub_summary variant_dir =
  Option.bind (find_ocaml_install_dir variant_dir) ~f:(fun dir ->
      let p = dir ^ "/stub_summary.json" in
      if Stdlib.Sys.file_exists p then Some p else None)

let find_mli_summary variant_dir =
  Option.bind (find_ocaml_install_dir variant_dir) ~f:(fun dir ->
      let p = dir ^ "/summary.json" in
      if Stdlib.Sys.file_exists p then Some p else None)

let run_for_project ~root ~project ~variant =
  match resolve_variant_dir ~root ~project variant with
  | None ->
      Fmt.epr "compat: no run dir for %s/%s under _out/canary/projects/@."
        project variant;
      2
  | Some dir ->
      let stub_path = find_stub_summary dir in
      let lib_path = find_lib_summary dir in
      (match stub_path, lib_path with
       | None, _ ->
           Fmt.epr "compat: no stub_summary.json under %s/probe_ocaml_binding/@." dir;
           Fmt.epr "  (run `canary action %s` first to populate the cache)@." project;
           2
       | _, None ->
           Fmt.epr "compat: no probe_lib*/summary.json under %s@." dir;
           2
       | Some stub_p, Some lib_p ->
           Fmt.pr "(using cached summaries under %s)@." dir;
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

let load_mli_missing variant_dir =
  match find_mli_summary variant_dir with
  | None -> []
  | Some p ->
      let j = Yojson.Basic.from_file p in
      match field j "watchlist" with
      | Some wl -> get_string_list wl "missing"
      | None -> []

(* Predict the set of substrings that would appear in a failed probe.log,
   given paths to cached summaries. This is the consumer-facing entry point
   for Expect_compat_failure: pass paths to install-dir summaries and the
   probe_lib summary; get back the contains_any list to grep probe.log for.
   Variants of dotted names (full path, suffix without top-level prefix,
   last component) are emitted so the substring search matches OCaml-level
   "Unbound constructor X.Y" patterns regardless of how X.Y is qualified. *)
let predicted_contains_any
    ?stub_summary_path ?lib_summary_path ?mli_summary_path () =
  let l3 = match mli_summary_path with
    | None -> []
    | Some p when not (Stdlib.Sys.file_exists p) -> []
    | Some p ->
        let j = Yojson.Basic.from_file p in
        match field j "watchlist" with
        | Some wl -> get_string_list wl "missing"
        | None -> []
  in
  let l3_variants =
    List.concat_map l3 ~f:(fun e ->
        let parts = String.split e ~on:'.' in
        let suffix_no_top = match parts with
          | _ :: (_ :: _ as rest) -> [ String.concat ~sep:"." rest ]
          | _ -> []
        in
        let last = match List.last parts with Some l -> [ l ] | None -> [] in
        e :: suffix_no_top @ last)
    |> List.dedup_and_sort ~compare:String.compare
  in
  let l0 = match stub_summary_path, lib_summary_path with
    | Some s, Some l
      when Stdlib.Sys.file_exists s && Stdlib.Sys.file_exists l ->
        let stub = load_stub s in
        let lib = load_native l in
        (match check_c_compat ~binding_stub:stub ~native_lib:lib with
         | Missing { symbols } -> symbols
         | Compatible | Unknown -> [])
    | _ -> []
  in
  l3_variants @ l0
  |> List.dedup_and_sort ~compare:String.compare

(* Best-effort: ".ok" marker file alongside cmd success implies probe step
   succeeded. probe.log non-empty + no .ok marker implies cmd failed (which
   for Expect_failure cases is the GOAL — see step_expectation in
   canary_action.ml). We're not re-implementing the runner's verdict; just
   distinguishing "log has compile error text" from "log shows runtime ok". *)
let probe_log_summary log =
  let lines = String.split_lines log in
  let line_count = List.length lines in
  let head = List.take lines 4 |> String.concat ~sep:"\n" in
  (line_count, head)

let verify_for_project ~root ~project ~variant =
  match resolve_variant_dir ~root ~project variant with
  | None ->
      Fmt.epr "verify: no run dir for %s/%s under _out/canary/projects/@."
        project variant;
      2
  | Some dir ->
      Fmt.pr "=== Compat verification: %s/%s ===@.@." project variant;
      Fmt.pr "Run dir: %s@.@." dir;

      (* L3 (OCaml mli) prediction *)
      let mli_missing = load_mli_missing dir in
      Fmt.pr "L3 (OCaml mli) prediction:@.";
      if List.is_empty mli_missing then
        Fmt.pr "  watchlist missing: (none) — predicts SUCCESS at OCaml level@."
      else (
        Fmt.pr "  watchlist missing: %d entry/entries@."
          (List.length mli_missing);
        List.iter mli_missing ~f:(fun e -> Fmt.pr "    - %s@." e);
        Fmt.pr "  → predicts FAIL referencing one of these names@.");

      (* L0 (C symbols) prediction *)
      let stub_path = find_stub_summary dir in
      let lib_path = find_lib_summary dir in
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
      let log_path = dir ^ "/probe_ocaml_binding/probe.log" in
      let log = read_file_or_empty log_path in
      let line_count, head = probe_log_summary log in
      Fmt.pr "@.probe.log analysis (%d lines):@." line_count;
      if String.is_empty log then Fmt.pr "  (empty or missing)@."
      else (
        Fmt.pr "  head:@.";
        List.iter (String.split_lines head) ~f:(fun l ->
            Fmt.pr "    | %s@." l));

      (* Cross-reference predictions vs log *)
      Fmt.pr "@.Verdict:@.";
      let l3_confirmed =
        List.filter_map mli_missing ~f:(fun e ->
            Option.map (match_in_log ~log e) ~f:(fun m -> (e, m)))
      in
      let l3_unconfirmed =
        List.filter mli_missing ~f:(fun e ->
            Option.is_none (match_in_log ~log e))
      in
      let l0_confirmed =
        List.filter c_missing ~f:(fun s ->
            String.is_substring log ~substring:s)
      in
      let l0_unconfirmed =
        List.filter c_missing ~f:(fun s ->
            not (String.is_substring log ~substring:s))
      in

      let print_verdict_layer layer ~predicted ~confirmed ~unconfirmed =
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
      print_verdict_layer "L3 (OCaml)"
        ~predicted:mli_missing ~confirmed:(List.map l3_confirmed ~f:fst)
        ~unconfirmed:l3_unconfirmed;
      print_verdict_layer "L0 (C ABI)"
        ~predicted:c_missing ~confirmed:l0_confirmed
        ~unconfirmed:l0_unconfirmed;
      List.iter l3_confirmed ~f:(fun (entry, matched) ->
          if not (String.equal entry matched) then
            Fmt.pr "    note: '%s' matched as substring '%s'@." entry matched);
      0
