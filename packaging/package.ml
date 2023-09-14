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

module String_no_dep_pkg = struct
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

module String_static_dep_pkg = struct
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
