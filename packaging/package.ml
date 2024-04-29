module type PACKAGE = sig
  type pid
  type payload
  type meta
  type pkg = { payload : payload; meta : meta }

  (* serialization and de-serialization *)

  val pid_to_str : pid -> string
  val str_to_pid : string -> pid
  val payload_of_pkg : pkg -> payload
  val meta_of_pkg : pkg -> meta
  val pkg_to_str : pkg -> string
  val str_to_pkg : string -> pkg
end

module Naive_pkg = struct
  type pid = string
  type payload = string
  type meta = unit
  type pkg = { payload : payload; meta : meta }

  let pid_to_str s = s
  let str_to_pid s = s
  let payload_of_pkg { payload; _ } = payload
  let meta_of_pkg { meta; _ } = meta
  let pkg_to_str { payload; _ } = payload
  let str_to_pkg payload = { payload; meta = () }
end

open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module Basic_pkg = struct
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

module V = Versioning.Multi_part

module Extend_version (P0 : PACKAGE) = struct
  type pid = { name : P0.pid; version : V.t }
  type payload = P0.payload
  type meta = P0.meta
  type pkg = P0.pkg = { payload : payload; meta : meta }

  let pid_to_str pid =
    Fmt.str "%s-%s" (P0.pid_to_str pid.name) (V.to_str pid.version)

  let str_to_pid s =
    let ss = String.split_on_char '-' s in
    (* Fmt.pr "%s %d %d %s %s" s (String.length s) (List.length ss) (List.nth ss 0)
       "--\n"; *)
    match ss with
    | [ ns; vs ] -> { name = P0.str_to_pid ns; version = V.of_str vs }
    | _ -> failwith "broken pid string"

  (* Scanf.sscanf s "%s-%s" (fun ns vs ->
      { name = P0.str_to_pid ns; version = V.of_str vs }) *)

  let payload_of_pkg = P0.payload_of_pkg
  let meta_of_pkg = P0.meta_of_pkg
  let pkg_to_str = P0.pkg_to_str
  let str_to_pkg = P0.str_to_pkg
end
