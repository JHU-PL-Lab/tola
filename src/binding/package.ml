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
      Fmt.(pr "%a@." (Dump.list string)) (Opam.files_of_package p.name);
      true
  | Tola_ml -> Sys_unix.file_exists_exn p.name
