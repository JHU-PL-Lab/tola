open Tola_std

(* Filesystem *)

module Dir = struct
  type rel_path = string
  type t = { rel_path : string; abs_path : rel_path; kind : [ `Dir_raw ] }

  let make root rel_path =
    let abs_path = root $/ rel_path in
    { rel_path; abs_path; kind = `Dir_raw }

  let pp fmt dir =
    Fmt.pf fmt "Dir: rel_path=%s abs_path=%s kind=%s" dir.rel_path dir.abs_path
      "Dir_raw"

  let info dir = Fmt.str "%a" pp dir
end

module Dirs = struct
  type t = Dir.t list

  let info dirs = Fmt.str "Dirs:@.%a" Fmt.(list ~sep:(any "@.") Dir.pp) dirs
end
