open Base
open Tola_std

type package_kind = Opam of Opam.switch_info | Tola_ml | Placeholder_fs

type t = {
  name : string;
  version : string;
  (* platform : Platform.t option; *)
  kind : package_kind;
}

let exists p = match p.kind with Opam _ -> Opam.exists p.name | _ -> false

let inspect ?(verbose = false) p =
  match p.kind with
  | Placeholder_fs -> Sys_unix.file_exists_exn p.name
  | Opam info ->
      let open Ocaml_files in
      let files = Opam.files_of_package p.name in
      let file_infos =
        List.map
          ~f:(inspect_file ~inspect_config:Config.ocamlmklib_inspect_config)
          files
      in
      let rs =
        List.map
          ~f:(fun fi ->
            Ocaml_files.check_no_internal_path
              [ Opam.internal_build_path info ]
              fi.content)
          file_infos
      in
      let pp_fi fmt (file, fi) =
        match fi.content with
        | Unknown ->
            Fmt.pf fmt "%a %s" Fmt.(styled `Red Fmt.string) "[Ignore]" file
        | _ -> pp_file_info_short fmt fi
      in
      if verbose then
        Fmt.(pr "%a@." (pp_indexed_list pp_fi) (List.zip_exn files file_infos))
      else (
        Fmt.(
          pr "%d files in package %s:%s@." (List.length files) p.name
            (dots_of_results rs));
        List.iter (List.zip_exn files rs) ~f:(function
          | _, Ok _ -> ()
          | file, Error paths ->
              Fmt.pr "Internal build path found in %a: %a@." Fmt.string file
                (Fmt.Dump.list Fmt.string) paths));

      true
  | Tola_ml -> Sys_unix.file_exists_exn p.name
