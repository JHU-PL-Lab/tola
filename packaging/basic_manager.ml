(* A basic pkgm is with a local store and a remote store.
   The store is a json-file based package as `<pid>.json`.

   Now the question is using a file system and the structure of the file system is not bundled. The structure of a package and the structure of a store should be able in configurated.
*)
open Package
open Std.File_infix

(* (Table : Hashtbl.S with type key = P.pid) *)
(* type t = P.pkg Table.t and *)

module Make
    (P : PACKAGE)
    (V : Versioning.Version_logic.V_str)
    (C : Manager.CONFIG)
    (PC : Manager.PKG_FILE_CONFIG) : Manager.S with module P = P = struct
  module P = P
  module VL = Versioning.Version_logic.Make (P) (V)

  module Table = Hashtbl.Make (struct
    type t = P.pid

    let equal = Std.fn_lift2 String.equal P.pid_to_str
    let hash = Hashtbl.hash
  end)

  let info_of_table table =
    let pp_pid = Fmt.using P.pid_to_str Fmt.string in

    Fmt.str "#pkg = %d@." (Table.length table)
    ^ Fmt.str "%a" (Std.pp_std_table Table.iter pp_pid Fmt.nop) table

  type t = P.pkg Table.t

  module Pkg_file = struct
    let save_pkg_content pkg_path pkg =
      if not (Sys.file_exists pkg_path) then Sys.mkdir pkg_path 0o755;
      Std.write_file_all (pkg_path $/ PC.file_name) (P.pkg_to_str pkg)

    let load_pkg_content pkg_path = Std.read_file_all (pkg_path $/ PC.file_name)
  end

  let path_of_pid pid = C.local_root $/ P.pid_to_str pid
  let path_of_pid_s pid_s = C.local_root $/ pid_s
  let remote_path_of_pid pid = C.remote_root $/ P.pid_to_str pid

  (* A table is just a cache for the directory status *)
  let local_table = ref (Table.create 64)
  let remote_table = ref (Table.create 64)

  (* utilities *)
  let set_store table' = local_table := table'

  let load_store pkgm_root =
    let pid_and_pkgs =
      Sys.readdir pkgm_root |> Array.to_list
      |> List.filter_map (fun pid_s ->
             let pkg_path = path_of_pid_s pid_s in
             if Sys.is_directory pkg_path then
               let pkg_content = Pkg_file.load_pkg_content pkg_path in
               Some (P.str_to_pid pid_s, P.str_to_pkg pkg_content)
             else None)
    in
    pid_and_pkgs |> List.to_seq |> Table.of_seq

  (* local api *)
  let install pid pkg =
    Table.add !local_table pid pkg;
    let pkg_path = path_of_pid pid in
    Std.remove_dir pkg_path;

    Pkg_file.save_pkg_content pkg_path pkg

  let uninstall pid =
    Table.remove !local_table pid;
    let pkg_path = path_of_pid pid in
    Std.remove_dir pkg_path

  let reset () = Std.remove_dir C.local_root
  let lookup pid = Table.find !local_table pid

  let lookup_pname pname =
    let matching_pids =
      Table.fold
        (fun pid _ pids ->
          if String.starts_with ~prefix:pname (P.pid_to_str pid) then
            pid :: pids
          else pids)
        !local_table []
    in
    (* Fmt.pr "can %d" (List.length pids); *)
    let pid = List.hd matching_pids in
    match Table.find_opt !local_table pid with
    | Some pkg -> pkg
    | None -> failwith "not found"

  let info () = info_of_table !local_table

  (* remote api *)
  let publish pid pkg =
    let pkg_path = remote_path_of_pid pid in
    Std.remove_dir pkg_path;
    Pkg_file.save_pkg_content pkg_path pkg

  let unpublish pid =
    let pkg_path = remote_path_of_pid pid in
    Std.remove_dir pkg_path

  let fetch pid =
    let remote_pkg_path = remote_path_of_pid pid in
    let pkg_content = Pkg_file.load_pkg_content remote_pkg_path in
    let pkg_path = path_of_pid pid in
    Pkg_file.save_pkg_content pkg_path (P.str_to_pkg pkg_content)

  let remote_info () = info_of_table !remote_table

  let init () =
    if Sys.file_exists C.local_root then
      let table = load_store C.local_root in
      set_store table
    else Sys.mkdir C.local_root 0o755;

    if not (Sys.file_exists C.remote_root) then Sys.mkdir C.remote_root 0o755
end
