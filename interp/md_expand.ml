open Langs
open Packaging
open Std.File_infix

let expand e : Lang_md.t = e

module Config = struct
  let pkgm_id = "_static_md"
  let local_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_local"
  let remote_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_remote"
  let store_name = "main.json"
end

module Pkgm =
  Basic_manager.Make (Package.String_static_dep_pkg) (Store.Pkg_table) (Config)

module Make (PM : Manager.S with type P.payload = string) = struct
  open Cmarkit

  let get_string_payload pid =
    pid |> PM.P.str_to_pid |> PM.lookup |> PM.P.payload_of_pkg

  let get_import_pid s =
    let de_br = String.sub s 1 (String.length s - 2) in
    let ts = String.split_on_char ' ' de_br in
    match ts with [ "import"; pid ] -> Some pid | _ -> None

  let rec map_block_import _ node =
    match node with
    | Block.Html_block (bs, _mb) ->
        if List.length bs = 1 then
          let b, _m = List.hd bs in
          let b' =
            match get_import_pid b with
            | Some pid -> get_string_payload pid
            | _ -> b
          in
          let db = Doc.block (parse b') in
          Mapper.ret db
        else Mapper.default
    | _ -> Mapper.default

  and parse s =
    let doc = Doc.of_string ~strict:true s in
    let mapper = Mapper.make ~block:map_block_import () in
    let doc' = Mapper.map_doc mapper doc in
    doc'

  let expand e =
    let doc = parse e in
    let html = Cmarkit_html.of_doc ~safe:false doc in
    html
end

module Expand = Make (Pkgm)
