open Tola_std

(* TODO:
Recall the difference between rel and abs are leading "/"
Rel path can be created with a root
Abs path is with root "/"

*)

type rel_path = string
type abs_path = string

type path_info = {
  (*ctx*) root : string;
  path : string;
  full_path : string;
  kind : [ `File_raw | `Dir_raw ];
}

let v root rel_path kind =
  { root; path = rel_path; full_path = root $/ rel_path; kind }

let abs path kind =
  if not (Filename.is_relative path) then
    { root = "/"; path; full_path = path; kind }
  else failwith "File.abs: path is not absolute"

let s r = r.full_path
let dirname r = Filename.dirname r.full_path

(* Sys_unix.file_exists_exn path *)
let exists r = Sys.file_exists r.full_path

module File = struct
  type t = path_info

  let v root rel_path = v root rel_path `File_raw
  let abs path = abs path `File_raw
  let s r = s r
  let dirname r = dirname r
  let exists r = exists r
end

module Dir = struct
  type t = path_info

  (* TODO: no guarantee the root is rel_path *)
  let v root rel_path = v root rel_path `Dir_raw
  let abs path = abs path `Dir_raw
  let s r = s r
  let dirname r = dirname r
  let cons_file r sub = File.v r.full_path sub
  let exists r = exists r

  let pp fmt dir =
    Fmt.pf fmt "Dir: path=%s abs_path=%s kind=%s" dir.path dir.full_path
      "Dir_raw"

  let info dir = Fmt.str "%a" pp dir
end

module Dirs = struct
  type t = Dir.t list

  let info dirs = Fmt.str "Dirs:@.%a" Fmt.(list ~sep:(any "@.") Dir.pp) dirs
end
