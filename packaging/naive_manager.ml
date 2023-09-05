open Package
open Naive

module Make
    (P : PACKAGE)
    (Table : Hashtbl.S with type key = P.pid)
    (C : NAIVE_CONFIG) :
  NAIVE_MANAGER
    with type pid = P.pid
     and type pkg = P.pkg
     and type t = P.pkg Table.t = struct
  type pid = P.pid
  type pkg = P.pkg
  type t = pkg Table.t

  module P = P

  let pkgm_root = C.pkgm_root
  let text_pkgm_root = pkgm_root ^ "/" ^ C.pkgm_id
  let path_of_pid pid = Filename.concat text_pkgm_root (P.pid_to_str pid)
  let path_of_pid_s pid_s = Filename.concat text_pkgm_root pid_s

  let load_pkg_content pkg_path =
    In_channel.with_open_text
      (Filename.concat pkg_path "main.md")
      In_channel.input_all

  let save_pkg_content pkg_path pkg =
    Std.remove_dir pkg_path;
    Out_channel.with_open_text pkg_path (fun c ->
        Out_channel.output_string c (P.pkg_to_str pkg))

  let table = ref (Table.create 64)
  let set_store table' = table := table'
  let get_store () = !table

  let load_store () =
    let pid_and_pkgs =
      Sys.readdir text_pkgm_root |> Array.to_list
      |> List.filter_map (fun pid_s ->
             let pkg_path = path_of_pid_s pid_s in
             if Sys.is_directory pkg_path then
               let pkg_content = load_pkg_content pkg_path in
               Some (P.str_to_pid pid_s, P.str_to_pkg pkg_content)
             else None)
    in
    let table = pid_and_pkgs |> List.to_seq |> Table.of_seq in
    set_store table

  let install pid pkg =
    Table.add !table pid pkg;
    let pkg_path = path_of_pid pid in
    save_pkg_content pkg_path pkg

  let reset () = ()
  let uninstall _pig = ()
  let lookup pid = Table.find !table pid
  let set_store _ = ()

  let info () =
    let pp_pid = Fmt.using P.pid_to_str Fmt.string in

    Fmt.str "#pkg = %d@." (Table.length !table)
    ^ Fmt.str "%a" (Std.pp_std_table Table.iter pp_pid Fmt.nop) !table

  let init () =
    if not (Sys.file_exists pkgm_root) then Sys.mkdir pkgm_root 0o755;
    if not (Sys.file_exists text_pkgm_root) then Sys.mkdir text_pkgm_root 0o755;
    load_store ()

  let () = init ()
end
