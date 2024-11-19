open Std.File_infix

module File_store_make
    (P : Package.PACKAGE)
    (C : Manager.CONFIG)
    (PC : Manager.PKG_FILE_CONFIG) =
struct
  (* The table is the cached view of the store.
      We may not need this. *)
  module Table = Hashtbl.Make (struct
    type t = P.pid

    let equal = Std.fn_lift2 String.equal P.pid_to_str
    let hash = Hashtbl.hash
  end)

  (* let delete_pkg pkg_path =  *)

  let path_of_pid pid = C.local_root $/ P.pid_to_str pid
  let remote_path_of_pid pid_s = C.remote_root $/ pid_s

  let save_pkg_content pkg_path pkg =
    if not (Sys.file_exists pkg_path) then Sys.mkdir pkg_path 0o755;
    Std.write_file_all (pkg_path $/ PC.file_name) (P.pkg_to_str pkg)

  let load_pkg_content pkg_path = Std.read_file_all (pkg_path $/ PC.file_name)

  let remove_pkg pid =
    let pkg_path = path_of_pid pid in
    Std.remove_dir pkg_path

  let load_store pkgm_root =
    let pid_and_pkgs =
      Sys.readdir pkgm_root |> Array.to_list
      |> List.filter_map (fun pid_s ->
             let pkg_path = path_of_pid (P.str_to_pid pid_s) in
             if Sys.is_directory pkg_path then
               let pkg_content = load_pkg_content pkg_path in
               Some (P.str_to_pid pid_s, P.str_to_pkg pkg_content)
             else None)
    in
    pid_and_pkgs |> List.to_seq
end

(*open Std.File_infix

   module Pkg_table = Hashtbl.Make (struct
     type t = string

     let equal = String.equal
     let hash = Hashtbl.hash
   end)

   module File_system_store (P : Package.PACKAGE) (C : Manager.CONFIG) = struct
     module Table = Hashtbl.Make (struct
       type t = string

       let equal = String.equal
       let hash = Hashtbl.hash
     end)

     (* table for store : A table is just a cache for the directory status *)
     let local_table : P.pkg Table.t ref = ref (Table.create 64)
     (* let remote_table = ref (Table.create 64) *)

     (* local store *)
     let save_pkg_content pkg_path pkg =
       if not (Sys.file_exists pkg_path) then Sys.mkdir pkg_path 0o755;
       Std.write_file_all (pkg_path $/ C.store_name) (P.pkg_to_str pkg)

     let load_pkg_content pkg_path = Std.read_file_all (pkg_path $/ C.store_name)
     let set_store table = local_table := table
     let path_of_pid_s pid_s = C.local_root $/ pid_s

     let load_store pkgm_root =
       let pid_and_pkgs =
         Sys.readdir pkgm_root |> Array.to_list
         |> List.filter_map (fun pid_s ->
                let pkg_path = path_of_pid_s pid_s in
                if Sys.is_directory pkg_path then
                  let pkg_content = load_pkg_content pkg_path in
                  Some (pid_s, P.str_to_pkg pkg_content)
                else None)
       in
       pid_and_pkgs |> List.to_seq |> Table.of_seq

     let info_of_table table =
       (* let pp_pid = Fmt.using P.pid_to_str Fmt.string in *)
       Fmt.str "#pkg = %d@." (Table.length table)
       ^ Fmt.str "%a" (Std.pp_std_table Table.iter Fmt.string Fmt.nop) table
     (* remote store *)
   end

   module type S = sig
     module P : Package.PACKAGE

     val save_pkg_content : string -> P.pkg -> unit
   end *)
