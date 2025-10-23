open Base
open Tola_std
open Tola_std.Std.File_infix
(* open Store *)

module Table_make (P : Package.PACKAGE) = Stdlib.Hashtbl.Make (struct
  type t = P.pid

  let equal = Std.fn_lift2 String.equal P.pid_to_str
  let hash = Hashtbl.hash
end)

module File_store_make (P : Package.PACKAGE) = struct
  (* The table is the cached view of the store. We may not need this. *)
  (* (Table : Hashtbl.S with type key = P.pid) *)
  module Table = Table_make (P)

  type t = {
    (* state *)
    table : P.pkg Table.t ref;
    (* config *)
    spec : Spec.store_spec;
    root : string;
    meta_file : string;
  }

  let add_table state pid pkg = Table.add !(state.table) pid pkg
  let remove_table state pid = Table.remove !(state.table) pid
  let lookup state pid = Table.find !(state.table) pid

  let lookup_pname state pname =
    (* Fmt.pr "pname %s" pname; *)
    let matching_pids =
      Table.fold
        (fun pid _ pids ->
          if String.is_prefix ~prefix:pname (P.pid_to_str pid) then pid :: pids
          else pids)
        !(state.table) []
    in
    (* Fmt.pr "can %d" (List.length pids); *)
    match List.hd matching_pids with
    | Some pid -> (
        match Table.find_opt !(state.table) pid with
        | Some pkg -> pkg
        | None -> failwith (Fmt.str "no package with id %s" (P.pid_to_str pid)))
    | None -> failwith (Fmt.str "no package id with name %s" pname)

  let info ?(i = 0) state =
    let pp_pid = Fmt.using P.pid_to_str Fmt.string in
    let name = state.spec.root in
    Fmt.str "[%d] #pkg = %d @@ %s@." i (Table.length !(state.table)) name
    ^ Fmt.str "%a" (Std.pp_std_table Table.iter pp_pid Fmt.nop) !(state.table)

  let path_of_pid state pid = state.root $/ P.pid_to_str pid

  let remove_pkg state pid =
    let pkg_path = path_of_pid state pid in
    Std.remove_dir pkg_path;
    remove_table state pid

  let save_pkg ?(remove_first = false) state pid pkg =
    if remove_first then remove_pkg state pid;
    let pkg_path = path_of_pid state pid in
    if not (Stdlib.Sys.file_exists pkg_path) then
      Stdlib.Sys.mkdir pkg_path 0o755;
    Std.write_file_all (pkg_path $/ state.meta_file) (P.pkg_to_str pkg);
    add_table state pid pkg

  let load_pkg state pid =
    let pkg_path = path_of_pid state pid in
    let pkg_raw = Std.read_file_all (pkg_path $/ state.meta_file) in
    P.str_to_pkg pkg_raw

  let load_pkg_content state pkg_path =
    Std.read_file_all (pkg_path $/ state.meta_file)

  let reset state = Std.remove_dir state.root

  let load_directory_store state =
    let pid_and_pkgs =
      Stdlib.Sys.readdir state.root
      |> Array.to_list
      |> List.filter_map ~f:(fun pid_s ->
             (* Fmt.pr "pid_s %s@." pid_s; *)
             let pkg_path = path_of_pid state (P.str_to_pid pid_s) in
             if Stdlib.Sys.is_directory pkg_path then
               let pkg_content = load_pkg_content state pkg_path in
               Some (P.str_to_pid pid_s, P.str_to_pkg pkg_content)
             else None)
    in
    pid_and_pkgs |> Stdlib.List.to_seq |> Table.of_seq

  let init_directory_state (store_spec : Spec.store_spec) meta_file =
    let state =
      {
        table = ref (Table.create 64);
        spec = store_spec;
        root = store_spec.root;
        meta_file;
      }
    in
    if Stdlib.Sys.file_exists state.root then
      state.table := load_directory_store state
    else Stdlib.Sys.mkdir state.root 0o755;
    state

  let init_repository_state (cfg : Spec.config) (store_spec : Spec.store_spec) =
    let repo_url = store_spec.root in
    let dest_dir = cfg.cache_path $/ store_spec.name in

    let exist =
      Stdlib.Sys.file_exists dest_dir && Stdlib.Sys.is_directory dest_dir
    in
    (if not exist then Sys_utils.(complete (clone_repo repo_url dest_dir)));

    let root = dest_dir $/ cfg.lang_id in
    let state =
      {
        table = ref (Table.create 64);
        spec = store_spec;
        root;
        meta_file = cfg.meta_file;
      }
    in
    (* Fmt.pr "debug %s" root; *)
    if Stdlib.Sys.file_exists state.root then
      state.table := load_directory_store state;
    state

  let init (cfg : Spec.config) (store_spec : Spec.store_spec) =
    match store_spec with
    | { kind = Directory; position = Local; _ } ->
        init_directory_state store_spec cfg.meta_file
    | { kind = Directory; position = Remote; _ } ->
        init_directory_state store_spec cfg.meta_file
    | { kind = Git_repo; position = Remote; _ } ->
        init_repository_state cfg store_spec
    | _ -> failwith "store not implemented"
end
