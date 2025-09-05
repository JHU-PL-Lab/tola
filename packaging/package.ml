open Base
open Ppx_yojson_conv_lib.Yojson_conv

module Legacy_string_pkg = struct
  type pid = string [@@deriving yojson]
  type payload = string [@@deriving yojson]
  type meta = string list [@@deriving yojson]
  type pkg = { payload : payload; meta : meta } [@@deriving yojson]

  let pid_to_str s = s
  let str_to_pid s = s
  let payload_of_pkg { payload; _ } = payload
  let meta_of_pkg { meta; _ } = meta
  let pkg_to_str pkg = Yojson.Safe.to_string (yojson_of_pkg pkg)
  let str_to_pkg raw = pkg_of_yojson (Yojson.Safe.from_string raw)
end

(* module type PID = sig
  type pid [@@deriving yojson]

  val compare_pid : pid -> pid -> int
  val pid_to_str : pid -> string
  val str_to_pid : string -> pid
end *)

(* module String_pid : PID with type pid = string = struct
  type pid = string [@@deriving yojson]

  let compare_pid = String.compare
  let pid_to_str s = s
  let str_to_pid s = s
end *)

module type PNAME = sig
  type t [@@deriving yojson]

  val compare : t -> t -> int
  val t_to_str : t -> string
  val str_to_t : string -> t
end

module String_pname : PNAME with type t = string = struct
  type t = string [@@deriving yojson]

  let compare = String.compare
  let t_to_str s = s
  let str_to_t s = s
end

module type PAYLOAD = sig
  type payload

  val payload_of_yojson : Yojson.Safe.t -> payload
  val yojson_of_payload : payload -> Yojson.Safe.t
end

module String_payload = struct
  type payload = string

  let payload_of_yojson json =
    json |> Yojson.Safe.to_basic |> Yojson.Basic.Util.to_string

  let yojson_of_payload s = `String s
end

module type PACKAGE = sig
  type pid [@@deriving yojson]
  type payload
  type meta
  type pkg = { payload : payload; meta : meta }

  module PN : PNAME
  module VL : Versioning.Version_logic.S

  (* serialization and de-serialization *)

  val pid_to_str : pid -> string
  val str_to_pid : string -> pid
  val payload_of_pkg : pkg -> payload
  val meta_of_pkg : pkg -> meta
  val pkg_to_str : pkg -> string
  val str_to_pkg : string -> pkg
  val pname_of_pid : pid -> PN.t
  val version_of_pid : pid -> VL.lit
end

(* A versioned package needs a VL to make its pid *)
module Make
    (PN : PNAME)
    (V : Versioning.Version_logic.V_str)
    (Payload : PAYLOAD) =
struct
  module PN = PN

  module VL =
    Versioning.Version_logic.Make
      (struct
        type pname = PN.t [@@deriving yojson]

        let pname_to_str = PN.t_to_str
        let str_to_pname = PN.str_to_t
        let compare = PN.compare
      end)
      (V)

  include Payload
  open Ppx_yojson_conv_lib.Yojson_conv.Primitives

  type pid = { name : PN.t; version : VL.lit } [@@deriving yojson]
  type deps = VL.dependencies

  let deps_of_yojson = VL.exp_of_yojson
  let yojson_of_deps = VL.yojson_of_exp

  type meta = deps list [@@deriving yojson]
  type pkg = { payload : payload; meta : meta }

  let pkg_of_yojson json =
    let open Yojson.Safe in
    {
      payload = json |> Util.member "payload" |> payload_of_yojson;
      meta =
        json |> Util.member "meta" |> Util.to_list
        |> List.map ~f:(fun dep_json ->
               dep_json |> Util.to_string |> Sexplib.Sexp.of_string
               |> VL.exp_of_sexp);
    }

  let yojson_of_pkg pkg =
    `Assoc
      [
        ("payload", pkg.payload |> yojson_of_payload);
        ("meta", `List (List.map ~f:yojson_of_deps pkg.meta));
      ]

  let pid_to_str pid =
    Fmt.str "%s-%s" (PN.t_to_str pid.name) (VL.V.to_str pid.version)

  let str_to_pid s =
    let ss = String.split_on_chars ~on:[ '-' ] s in
    (* Fmt.pr "%s %d %d %s %s" s (String.length s) (List.length ss) (List.nth ss 0)
       "--\n"; *)
    match ss with
    | [ ns; vs ] -> { name = PN.str_to_t ns; version = VL.V.of_str vs }
    | _ -> failwith "broken pid string"

  (* Scanf.sscanf s "%s-%s" (fun ns vs ->
      { name = P0.str_to_pid ns; version = V.of_str vs }) *)

  let payload_of_pkg pkg = pkg.payload
  let meta_of_pkg pkg = pkg.meta
  let pkg_to_str pkg = Yojson.Safe.to_string (yojson_of_pkg pkg)
  let str_to_pkg s = pkg_of_yojson (Yojson.Safe.from_string s)
  let pname_of_pid pid = pid.name
  let version_of_pid pid = pid.version
end

(* 
module type META = sig
  type meta [@@deriving yojson]
end

module Meta = struct
  open Ppx_yojson_conv_lib.Yojson_conv.Primitives

  type meta = string list [@@deriving yojson]
end

module Make_string (PID : PID) (Meta : META) (Payload : PAYLOAD) = struct
  include PID
  include Payload
  include Meta

  type pkg = { payload : payload; meta : meta } [@@deriving yojson]

  let payload_of_pkg pkg = pkg.payload
  let meta_of_pkg pkg = pkg.meta
  let pkg_to_str pkg = Yojson.Safe.to_string (yojson_of_pkg pkg)
  let str_to_pkg raw = pkg_of_yojson (Yojson.Safe.from_string raw)
end *)
