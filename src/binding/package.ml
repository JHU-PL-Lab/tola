open Base
open Tola_std

type package_kind = Opam | Tola_ml | Placeholder_fs

type t = {
  name : string;
  version : string;
  platform : Platform.t option;
  kind : package_kind;
}

let exists p =
  match p.kind with
  | Placeholder_fs -> Sys_unix.file_exists_exn p.name
  | Opam ->
      let files = Opam.files_of_package p.name in
      let file_infos = List.map ~f:Common.inspect_file files in
      let file_with_infos = List.zip_exn files file_infos in
      let pp_fi fmt (file, fi) =
        match fi.Common.content with
        | Common.Unknown ->
            Fmt.pf fmt "%a %s" Fmt.(styled `Red Fmt.string) "[Ignore]" file
        | _ -> Common.pp_file_info_short fmt fi
      in
      Fmt.(pr "%a@." (pp_indexed_list pp_fi) file_with_infos);
      true
  | Tola_ml -> Sys_unix.file_exists_exn p.name
