open Packaging
open Langs
open Langs.Lang_boat
open Std.File_infix
open Boat_interp

module Make_interp (PM : Manager.S with type P.payload = Lang_boat.exp) = struct
  let lookup_pkg_payload pid =
    pid |> PM.P.str_to_pid |> PM.lookup |> PM.P.payload_of_pkg

  let interp e =
    let rec loop env e =
      match e with
      | Input -> Int 42
      | Int n -> Int n
      | Plus (e1, e2) -> (
          let v1 = loop env e1 in
          let v2 = loop env e2 in
          match (v1, v2) with
          | Int n1, Int n2 -> Int (n1 + n2)
          | Clopen _, _ | _, Clopen _ -> failwith "clopen cannot be int"
          | _ -> Plus (v1, v2))
      | If0 (e1, e2, e3) -> (
          let v1 = loop env e1 in
          match v1 with
          | Int 0 -> loop env e2
          | Int _ -> loop env e3
          | Clopen _ -> failwith "clopen cannot be int"
          | _ -> If0 (v1, e2, e3))
      | Var x -> (
          match Id.Map.find_opt x env with
          (* if x is bounded locally, retrieve it *)
          | Some v -> v
          | None -> (
              (* if x is bounded package-wise, lookup it *)
              try lookup_pkg_payload (Id.str_of x)
              with (* if x is free, leave it *)
              | Not_found -> Var x))
      | Fun (x, e) -> Clopen (env, x, e)
      | Let (x, e1, e2) -> (
          let v1 = loop env e1 in
          match v1 with
          | Int _ | Clopen _ -> loop (Id.Map.add x v1 env) e2
          | _ -> Let (x, v1, e2))
      | App (e1, e2) -> (
          let v1 = loop env e1 in
          match v1 with
          | Clopen (env', x, e) -> loop (Id.Map.add x (loop env e2) env') e
          | Int _ -> failwith "clopen cannot be int"
          | _ -> App (v1, e2))
      | Clopen _ -> failwith "clopen cannot be re-evaluated"
    in
    loop empty_env e
end

open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module Boat_pkg = struct
  type pid = string [@@deriving yojson]

  let exp_of_yojson json =
    json |> Yojson.Safe.to_basic
    |> Yojson.Basic.Util.member "src"
    |> Yojson.Basic.Util.to_string |> Boat_parse.of_string_no_eol_opt
    |> Option.get

  let payload_of_yojson = exp_of_yojson

  let yojson_of_exp exp =
    `Assoc [ ("src", `String (Fmt.to_to_string Lang_boat.pp_exp exp)) ]

  let yojson_of_payload = yojson_of_exp

  type payload = exp
  type meta = string list [@@deriving yojson]
  type pkg = { payload : payload; meta : meta } [@@deriving yojson]

  let pid_to_str s = s
  let str_to_pid s = s
  let payload_of_pkg { payload; _ } = payload
  let meta_of_pkg { meta; _ } = meta
  let pkg_to_str pkg = Yojson.Safe.to_string (yojson_of_pkg pkg)
  let str_to_pkg raw = pkg_of_yojson (Yojson.Safe.from_string raw)
end

module Static_dep_config : Manager.CONFIG = struct
  let pkgm_id = "boat_one_ver"
  let local_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_local"
  let remote_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_remote"
end

module Static_dep_pkgm =
  Basic_manager.Make (Boat_pkg) (Versioning.Version_logic.Singleton_version)
    (Static_dep_config)
    (Manager.Pkg_in_json)

module Static_dep_interp = Make_interp (Static_dep_pkgm)

module Multipart_config = struct
  let pkgm_id = "boat_multipart"
  let local_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_local"
  let remote_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_remote"
end

module Boat_versioned_pkg = Package.Extend_version (Boat_pkg)
module With_string_versioned_pkg = Langs.Lang_text.Make (Boat_versioned_pkg)
