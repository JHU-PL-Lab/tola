open Base

(* open Tola_std *)
open Ppx_yojson_conv_lib.Yojson_conv

(* type c_api_spec = {
  header_path : path;
  source : string; (*c string*)
  defs : (string * string) list; (*list of c definitions *)
} *)

type c_api_simple = { enums : string list; functions : string list }
[@@deriving show { with_path = false }, yojson]

let pp_short_k k fmt api =
  let short_api =
    { enums = List.take api.enums k; functions = List.take api.functions k }
  in
  Fmt.pf fmt "[#enums: %d][#functions: %d]@.%a" (List.length api.enums)
    (List.length api.functions)
    pp_c_api_simple short_api

let pp_short = pp_short_k 5
let starts_with_z3 (s : string) = String.is_prefix s ~prefix:"Z3_"

let assoc_string (key : string) (fields : (string * Yojson.Safe.t) list) :
    string option =
  match List.Assoc.find fields ~equal:String.equal key with
  | Some (`String s) -> Some s
  | _ -> None

let type_qual_type (fields : (string * Yojson.Safe.t) list) : string option =
  match List.Assoc.find fields ~equal:String.equal "type" with
  | Some (`Assoc type_fields) -> (
      match List.Assoc.find type_fields ~equal:String.equal "qualType" with
      | Some (`String s) -> Some s
      | _ -> (
          match
            List.Assoc.find type_fields ~equal:String.equal "desugaredQualType"
          with
          | Some (`String s) -> Some s
          | _ -> None))
  | _ -> None

let is_z3_enum_typedef (fields : (string * Yojson.Safe.t) list) : bool =
  match type_qual_type fields with
  | Some qt -> String.is_prefix qt ~prefix:"enum Z3_"
  | None -> false

let parse_c_api_simple_from_json (json : Yojson.Safe.t) : c_api_simple =
  (* let module S = Set.M (String) in *)
  let empty_set = Set.empty (module String) in
  let rec walk (enums, funcs) = function
    | `Assoc fields ->
        let enums, funcs =
          match assoc_string "kind" fields with
          | Some "FunctionDecl" -> (
              match assoc_string "name" fields with
              | Some name when starts_with_z3 name -> (enums, Set.add funcs name)
              | _ -> (enums, funcs))
          | Some "EnumDecl" -> (
              match assoc_string "name" fields with
              | Some name when starts_with_z3 name -> (Set.add enums name, funcs)
              | _ -> (enums, funcs))
          | Some "TypedefDecl" when is_z3_enum_typedef fields -> (
              match assoc_string "name" fields with
              | Some name -> (Set.add enums name, funcs)
              | None -> (enums, funcs))
          | _ -> (enums, funcs)
        in
        let enums, funcs =
          match List.Assoc.find fields ~equal:String.equal "inner" with
          | Some (`List xs) -> List.fold xs ~init:(enums, funcs) ~f:walk
          | _ -> (enums, funcs)
        in
        (enums, funcs)
    | `List xs -> List.fold xs ~init:(enums, funcs) ~f:walk
    | _ -> (enums, funcs)
  in
  let enums, funcs = walk (empty_set, empty_set) json in
  {
    enums = Set.to_list enums |> List.sort ~compare:String.compare;
    functions = Set.to_list funcs |> List.sort ~compare:String.compare;
  }

let parse_c_api_simple_file (path : string) : c_api_simple =
  Yojson.Safe.from_file path |> parse_c_api_simple_from_json
