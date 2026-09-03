(** [Canary_evidence] — where a check's inputs are found and loaded.

    A check takes what it needs; FINDING it is the caller's business
    (user, 2026-09-02), and this is where that business lives: turning a
    project / variant / step into the cached inspector JSON on disk, and
    the small loaders several check families share.

    No checks and no commands live here. The checks are one per family in
    [canary_chk_*.ml]; the table that collects them is
    [Canary_agreement_registry]; the two on-demand report commands moved
    to [main/] where the other reporting lives. *)



open Base
open Canary_agreement


(* ── Reporting ── *)

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

