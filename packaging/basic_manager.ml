(* A basic pkgm is with a local store and a remote store.
   The store is a toml-file based package as `<pid>.toml`.
*)

open Package

module type STORE = sig
  type t
  type pid
  type pkg
end

module type LOCAL_STORE = sig
  type t
  type pid
  type pkg
  type store
end

module type REMOTE_STORE = sig
  type t
  type pid
  type pkg
  type store
end

module type BASIC_MANAGER = sig
  type t
  type pid
  type pkg

  module P : Package.PACKAGE with type pid = pid and type pkg = pkg

  (* for local *)
  val init : unit -> unit
  val reset : unit -> unit
  val install : pid -> pkg -> unit (* system_state may be changed *)

  (* val install : pid * system_state -> system_state *)
  val uninstall : pid -> unit
  val lookup : pid -> pkg
  val info : unit -> string

  (* for remote *)
  val publish : pid -> pkg -> unit
  val unpublish : pid -> unit
  val fetch : pid -> unit
  val remote_info : unit -> string
end

module type BASIC_CONFIG = sig
  val pkgm_id : string
  val local_root : string
  val remote_root : string
end

module Make
    (P : PACKAGE)
    (Table : Hashtbl.S with type key = P.pid)
    (C : BASIC_CONFIG) :
  BASIC_MANAGER
    with type pid = P.pid
     and type pkg = P.pkg
     and type t = P.pkg Table.t = struct
  type pid = P.pid
  type pkg = P.pkg
  type t = pkg Table.t

  module P = P

  let path_of_pid pid = Filename.concat C.local_root (P.pid_to_str pid)
  let remote_path_of_pid pid = Filename.concat C.remote_root (P.pid_to_str pid)
  let path_of_pid_s pid_s = Filename.concat C.local_root pid_s

  let load_pkg_content pkg_path =
    In_channel.with_open_text
      (Filename.concat pkg_path "main.md")
      In_channel.input_all

  let save_pkg_content pkg_path pkg =
    if not (Sys.file_exists pkg_path) then Sys.mkdir pkg_path 0o755;
    let pkg_content_path = Filename.concat pkg_path "main.md" in

    Out_channel.with_open_text pkg_content_path (fun c ->
        Out_channel.output_string c (P.pkg_to_str pkg))

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
               let pkg_content = load_pkg_content pkg_path in
               Some (P.str_to_pid pid_s, P.str_to_pkg pkg_content)
             else None)
    in
    pid_and_pkgs |> List.to_seq |> Table.of_seq

  let info_of_table table =
    let pp_pid = Fmt.using P.pid_to_str Fmt.string in

    Fmt.str "#pkg = %d@." (Table.length table)
    ^ Fmt.str "%a" (Std.pp_std_table Table.iter pp_pid Fmt.nop) table

  (* local api *)
  let install pid pkg =
    Table.add !local_table pid pkg;
    let pkg_path = path_of_pid pid in
    Std.remove_dir pkg_path;

    save_pkg_content pkg_path pkg

  let uninstall pid =
    Table.remove !local_table pid;
    let pkg_path = path_of_pid pid in
    Std.remove_dir pkg_path

  let reset () = Std.remove_dir C.local_root
  let lookup pid = Table.find !local_table pid
  let info () = info_of_table !local_table

  (* remote api *)
  let publish pid pkg =
    let pkg_path = remote_path_of_pid pid in
    Std.remove_dir pkg_path;
    save_pkg_content pkg_path pkg

  let unpublish pid =
    let pkg_path = remote_path_of_pid pid in
    Std.remove_dir pkg_path

  let fetch pid =
    let remote_pkg_path = remote_path_of_pid pid in
    let pkg_content = load_pkg_content remote_pkg_path in
    let pkg_path = path_of_pid pid in
    save_pkg_content pkg_path (P.str_to_pkg pkg_content)

  let remote_info () = info_of_table !remote_table

  let init () =
    if Sys.file_exists C.local_root then
      let table = load_store C.local_root in
      set_store table
    else Sys.mkdir C.local_root 0o755;

    if not (Sys.file_exists C.remote_root) then Sys.mkdir C.remote_root 0o755

  let () = init ()
end
