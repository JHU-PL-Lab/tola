(* A basic pkgm is with a local store and a remote store.
   The store is a json-file based package as `<pid>.json`.

   Now the question is using a file system and the structure of the file system is not bundled. The structure of a package and the structure of a store should be able in configurated.
*)
open Package

(* (Table : Hashtbl.S with type key = P.pid) *)
(* type t = P.pkg Table.t and *)

module Make
    (P : PACKAGE)
    (V : Versioning.Version_logic.V_str)
    (C : Manager.CONFIG)
    (PC : Manager.PKG_FILE_CONFIG) : Manager.S with module P = P = struct
  module P = P
  module VL = Versioning.Version_logic.Make (P) (V)
  module Pkg_store = Store.File_store_make (P) (C) (PC)
  module Table = Pkg_store.Table

  let info_of_table table =
    let pp_pid = Fmt.using P.pid_to_str Fmt.string in

    Fmt.str "#pkg = %d@." (Table.length table)
    ^ Fmt.str "%a" (Std.pp_std_table Table.iter pp_pid Fmt.nop) table

  type t = P.pkg Table.t

  (* A table is just a cache for the directory status *)
  let local_table = ref (Table.create 64)
  let remote_table = ref (Table.create 64)

  (* utilities *)
  let set_local_store table' = local_table := table'

  (* local api *)
  let install pid pkg =
    Table.add !local_table pid pkg;
    Pkg_store.remove_pkg pid;
    let pkg_path = Pkg_store.path_of_pid pid in
    Pkg_store.save_pkg_content pkg_path pkg

  let uninstall pid =
    Table.remove !local_table pid;
    Pkg_store.remove_pkg pid

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
    let pkg_path = Pkg_store.remote_path_of_pid (P.pid_to_str pid) in
    Std.remove_dir pkg_path;
    Pkg_store.save_pkg_content pkg_path pkg

  let unpublish pid =
    let pkg_path = Pkg_store.remote_path_of_pid (P.pid_to_str pid) in
    Std.remove_dir pkg_path

  let fetch pid =
    let remote_pkg_path = Pkg_store.remote_path_of_pid (P.pid_to_str pid) in
    let pkg_content = Pkg_store.load_pkg_content remote_pkg_path in
    let pkg_path = Pkg_store.path_of_pid pid in
    Pkg_store.save_pkg_content pkg_path (P.str_to_pkg pkg_content)

  let remote_info () = info_of_table !remote_table

  let init () =
    if Sys.file_exists C.local_root then
      let table = Pkg_store.load_store C.local_root |> Table.of_seq in
      set_local_store table
    else Sys.mkdir C.local_root 0o755;

    if not (Sys.file_exists C.remote_root) then Sys.mkdir C.remote_root 0o755
end
