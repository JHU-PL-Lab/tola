open Tola_std

(* Files  *)

type rel_path = string
type abs_path = string

module File = struct
  type t = { rel_path : rel_path; abs_path : abs_path; kind : [ `File_raw ] }

  let v root rel_path =
    let abs_path = root $/ rel_path in
    { rel_path; abs_path; kind = `File_raw }

  let s r = r.abs_path
  let dirname r = Filename.dirname r.abs_path

  (* Sys_unix.file_exists_exn path *)
  let exists r = Sys.file_exists r.abs_path
end

module Dir = struct
  type t = { rel_path : rel_path; abs_path : abs_path; kind : [ `Dir_raw ] }

  (* TODO: no guarantee the root is rel_path *)
  let v root rel_path =
    let abs_path = root $/ rel_path in
    { rel_path; abs_path; kind = `Dir_raw }

  let s r = r.abs_path
  let cons_file r sub = File.v r.abs_path sub
  let exists r = Sys_unix.is_directory_exn r.abs_path

  let pp fmt dir =
    Fmt.pf fmt "Dir: rel_path=%s abs_path=%s kind=%s" dir.rel_path dir.abs_path
      "Dir_raw"

  let info dir = Fmt.str "%a" pp dir
end

module Dirs = struct
  type t = Dir.t list

  let info dirs = Fmt.str "Dirs:@.%a" Fmt.(list ~sep:(any "@.") Dir.pp) dirs
end
