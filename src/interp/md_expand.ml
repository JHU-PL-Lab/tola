open Base
open Langs
open Packaging

let expand e : Lang_md.t = e

module Make
    (PM : Manager.S with type P.payload = string)
    (M : Manager.One with type t = PM.t) =
struct
  open Cmarkit

  let lookup_pkg_payload pname =
    pname |> PM.lookup_local M.manager |> PM.P.payload_of_pkg

  let get_import_pname s =
    let de_br = String.sub s ~pos:1 ~len:(String.length s - 2) in
    let ts = String.split_on_chars ~on:[ ' ' ] de_br in
    match ts with [ "import"; pid ] -> Some pid | _ -> None

  let rec map_block_import _ node =
    match node with
    | Block.Html_block (bs, _mb) ->
        if List.length bs = 1 then
          let b, _m = List.hd_exn bs in
          let b' =
            match get_import_pname b with
            | Some pname -> lookup_pkg_payload pname
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
