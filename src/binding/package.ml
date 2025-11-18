open Base
open Tola_std

type package_kind = Opam | Tola_ml | Placeholder_fs

type t = {
  name : string;
  version : string;
  (* platform : Platform.t option; *)
  kind : package_kind;
}

let exists p = match p.kind with Opam -> Opam.exists p.name | _ -> false

let inspect ?(verbose = false) p =
  match p.kind with
  | Placeholder_fs -> Sys_unix.file_exists_exn p.name
  | Opam ->
      let open Files in
      let files = Opam.files_of_package p.name in
      let file_infos =
        List.map
          ~f:(inspect_file ~inspect_config:Config.ocamlmklib_inspect_config)
          files
      in
      List.iter
        ~f:(fun fi -> ignore @@ Files.check_content fi.content)
        file_infos;
      let file_with_infos = List.zip_exn files file_infos in
      let pp_fi fmt (file, fi) =
        match fi.content with
        | Unknown ->
            Fmt.pf fmt "%a %s" Fmt.(styled `Red Fmt.string) "[Ignore]" file
        | _ -> pp_file_info_short fmt fi
      in
      (if verbose then Fmt.(pr "%a@." (pp_indexed_list pp_fi) file_with_infos)
       else Fmt.(pr "%d files in package %s@." (List.length files) p.name));
      true
  | Tola_ml -> Sys_unix.file_exists_exn p.name
