open Base

(* Diff two artifact summary.json files.
   Reports deltas in counts, module lists, versioned requirements, and
   watchlist presence. Plain-text output; no external deps beyond yojson. *)

let load path : Yojson.Basic.t =
  if not (Stdlib.Sys.file_exists path) then (
    Fmt.epr "summary-diff: %s not found@." path;
    Stdlib.exit 2);
  Yojson.Basic.from_file path

let field (j : Yojson.Basic.t) name =
  match j with
  | `Assoc fields -> List.Assoc.find fields ~equal:String.equal name
  | _ -> None

let get_int j name =
  match field j name with Some (`Int i) -> i | _ -> 0

let get_string j name =
  match field j name with Some (`String s) -> s | _ -> ""

let get_assoc_int_map j name =
  match field j name with
  | Some (`Assoc fields) ->
      List.filter_map fields ~f:(fun (k, v) ->
          match v with `Int i -> Some (k, i) | _ -> None)
  | _ -> []

let get_string_list j name =
  match field j name with
  | Some (`List xs) ->
      List.filter_map xs ~f:(function `String s -> Some s | _ -> None)
  | _ -> []

(* ── Diff helpers ── *)

let fmt_delta d = if d >= 0 then [%string "+%{Int.to_string d}"] else Int.to_string d

let print_count_delta label old_v new_v =
  if old_v <> new_v then
    Fmt.pr "  %-24s %d → %d  (%s)@." label old_v new_v (fmt_delta (new_v - old_v))

let print_map_delta label old_map new_map =
  let keys =
    List.map old_map ~f:fst @ List.map new_map ~f:fst
    |> List.dedup_and_sort ~compare:String.compare
  in
  let changed = List.filter_map keys ~f:(fun k ->
      let o = List.Assoc.find old_map ~equal:String.equal k |> Option.value ~default:0 in
      let n = List.Assoc.find new_map ~equal:String.equal k |> Option.value ~default:0 in
      if o = n then None else Some (k, o, n))
  in
  if not (List.is_empty changed) then (
    Fmt.pr "  %s:@." label;
    List.iter changed ~f:(fun (k, o, n) ->
        let tag = if o = 0 then "NEW" else if n = 0 then "GONE" else "CHG" in
        Fmt.pr "    [%-4s] %-32s %d → %d  (%s)@." tag k o n (fmt_delta (n - o))))

let print_set_delta label old_l new_l =
  let oset = Set.of_list (module String) old_l in
  let nset = Set.of_list (module String) new_l in
  let added = Set.diff nset oset |> Set.to_list in
  let removed = Set.diff oset nset |> Set.to_list in
  if not (List.is_empty added) then (
    Fmt.pr "  %s added (%d):@." label (List.length added);
    List.iter added ~f:(fun s -> Fmt.pr "    + %s@." s));
  if not (List.is_empty removed) then (
    Fmt.pr "  %s removed (%d):@." label (List.length removed);
    List.iter removed ~f:(fun s -> Fmt.pr "    - %s@." s))

(* ── Main diff ── *)

let diff ~old_path ~new_path =
  let o = load old_path in
  let n = load new_path in
  let kind_o = get_string o "kind" in
  let kind_n = get_string n "kind" in
  let path_o = get_string o "path" in
  let path_n = get_string n "path" in
  Fmt.pr "--- old: %s (%s)@." path_o kind_o;
  Fmt.pr "+++ new: %s (%s)@.@." path_n kind_n;
  if not (String.equal kind_o kind_n) then
    Fmt.pr "!! kinds differ: %s vs %s — diff fields may not align@.@." kind_o kind_n;

  (* Counts *)
  let counts_o = Option.value (field o "counts") ~default:(`Assoc []) in
  let counts_n = Option.value (field n "counts") ~default:(`Assoc []) in
  Fmt.pr "counts:@.";
  print_count_delta "total" (get_int counts_o "total") (get_int counts_n "total");
  print_count_delta "modules" (get_int counts_o "modules") (get_int counts_n "modules");
  print_count_delta "imports" (get_int counts_o "imports") (get_int counts_n "imports");
  print_map_delta "by_prefix"
    (get_assoc_int_map counts_o "by_prefix") (get_assoc_int_map counts_n "by_prefix");
  Fmt.pr "@.";

  (* Versioned requirements (native only) *)
  let vr_o = get_assoc_int_map o "versioned_req" in
  let vr_n = get_assoc_int_map n "versioned_req" in
  if not (List.is_empty vr_o && List.is_empty vr_n) then (
    Fmt.pr "versioned_req:@.";
    print_map_delta "@@" vr_o vr_n;
    Fmt.pr "@.");

  (* Module list (ocaml) *)
  let mods_o = get_string_list o "modules" in
  let mods_n = get_string_list n "modules" in
  if not (List.is_empty mods_o && List.is_empty mods_n) then (
    Fmt.pr "modules:@.";
    print_set_delta "modules" mods_o mods_n;
    Fmt.pr "@.");

  (* Watchlist drift *)
  let wl_o = Option.value (field o "watchlist") ~default:(`Assoc []) in
  let wl_n = Option.value (field n "watchlist") ~default:(`Assoc []) in
  let pres_o = get_string_list wl_o "present" in
  let pres_n = get_string_list wl_n "present" in
  let miss_o = get_string_list wl_o "missing" in
  let miss_n = get_string_list wl_n "missing" in
  Fmt.pr "watchlist:@.";
  print_set_delta "present" pres_o pres_n;
  print_set_delta "missing" miss_o miss_n;
  (* Regressions: names that were present in old but missing in new *)
  let pres_oset = Set.of_list (module String) pres_o in
  let miss_nset = Set.of_list (module String) miss_n in
  let regressions = Set.inter pres_oset miss_nset |> Set.to_list in
  if not (List.is_empty regressions) then (
    Fmt.pr "  REGRESSIONS (present → missing): %d@." (List.length regressions);
    List.iter regressions ~f:(fun s -> Fmt.pr "    ! %s@." s))
