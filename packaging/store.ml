open Std.File_infix

module Table_make (P : Package.PACKAGE) = Hashtbl.Make (struct
  type t = P.pid

  let equal = Std.fn_lift2 String.equal P.pid_to_str
  let hash = Hashtbl.hash
end)

module type With_root = sig
  val root : string
end

module File_store_make
    (P : Package.PACKAGE)
    (PC : Manager.PKG_FILE_CONFIG)
    (R : With_root) =
struct
  module Table = Table_make (P)

  let table : P.pkg Table.t ref = ref (Table.create 64)
  let set_table table' = table := table'
  let add_table pid pkg = Table.add !table pid pkg
  let remove_table pid = Table.remove !table pid
  let lookup pid = Table.find !table pid

  let lookup_pname pname =
    let matching_pids =
      Table.fold
        (fun pid _ pids ->
          if String.starts_with ~prefix:pname (P.pid_to_str pid) then
            pid :: pids
          else pids)
        !table []
    in
    (* Fmt.pr "can %d" (List.length pids); *)
    let pid = List.hd matching_pids in
    match Table.find_opt !table pid with
    | Some pkg -> pkg
    | None -> failwith "not found"

  let info () =
    let pp_pid = Fmt.using P.pid_to_str Fmt.string in
    Fmt.str "#pkg = %d@." (Table.length !table)
    ^ Fmt.str "%a" (Std.pp_std_table Table.iter pp_pid Fmt.nop) !table

  let path_of_pid pid = R.root $/ P.pid_to_str pid

  let remove_pkg pid =
    let pkg_path = path_of_pid pid in
    Std.remove_dir pkg_path;
    remove_table pid

  let save_pkg ?(remove_first = false) pid pkg =
    if remove_first then remove_pkg pid;
    let pkg_path = path_of_pid pid in
    if not (Sys.file_exists pkg_path) then Sys.mkdir pkg_path 0o755;
    Std.write_file_all (pkg_path $/ PC.file_name) (P.pkg_to_str pkg);
    add_table pid pkg

  let load_pkg pid =
    let pkg_path = path_of_pid pid in
    let pkg_raw = Std.read_file_all (pkg_path $/ PC.file_name) in
    P.str_to_pkg pkg_raw

  let load_pkg_content pkg_path = Std.read_file_all (pkg_path $/ PC.file_name)

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

  let init () =
    if Sys.file_exists R.root then
      let table = load_store R.root |> Table.of_seq in
      set_table table
    else Sys.mkdir R.root 0o755;
    (* if not (Sys.file_exists C.remote_root) then Sys.mkdir C.remote_root 0o755 *)
    ()

  let reset () = Std.remove_dir R.root
end
