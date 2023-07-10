open Package.Naive
open Package_manager.Naive

module Pkg : PACKAGE with type pid = string and type pkg = string = struct
  type pid = string
  type pkg = string
end

module Pkg_table = Hashtbl.Make (struct
  type t = string

  let equal = String.equal
  let hash = Hashtbl.hash
end)

(* simple pkmg without persistency *)

module Pkgm_ephemeral :
  PACKAGE_MANAGER
    with type pid = Pkg.pid
     and type pkg = Pkg.pkg
     and type t = Pkg.pkg Pkg_table.t = struct
  type pid = Pkg.pid
  type pkg = Pkg.pkg
  type t = pkg Pkg_table.t

  let table = ref (Pkg_table.create 64)
  let init () = ()
  let reset () = table := Pkg_table.create 64
  let set_store table' = table := table'
  let get_store () = !table
  let install pid pkg = Pkg_table.add !table pid pkg
  let uninstall pid = Pkg_table.remove !table pid
  let lookup pid = Pkg_table.find !table pid
  let info () = ""
end

(* simple pkmg with persistency *)

module Pkgm_persisted :
  PACKAGE_MANAGER
    with type pid = Pkg.pid
     and type pkg = Pkg.pkg
     and type t = Pkg.pkg Pkg_table.t = struct
  type pid = Pkg.pid
  type pkg = Pkg.pkg
  type t = pkg Pkg_table.t

  let home = Sys.getenv "HOME"
  let pkgm_root = home ^ "/.pkgm"
  let text_pkgm_id = "text"
  let text_pkgm_root = pkgm_root ^ "/" ^ text_pkgm_id
  let text_pkgm_store = text_pkgm_root ^ "/" ^ "data"
  let table = ref (Pkg_table.create 64)

  let reset () =
    if Sys.file_exists text_pkgm_store then Sys.remove text_pkgm_store

  let set_store table' = table := table'
  let get_store () = !table

  let load_store () =
    let (table : t) = Std.read_marshal text_pkgm_store in
    set_store table

  let save_store () = Std.write_marshal text_pkgm_store !table

  let init () =
    if not (Sys.file_exists pkgm_root) then Sys.mkdir pkgm_root 0o755;
    if not (Sys.file_exists text_pkgm_root) then Sys.mkdir text_pkgm_root 0o755;
    if Sys.file_exists text_pkgm_store then load_store () else save_store ();
    ()

  let install pid pkg =
    Pkg_table.add !table pid pkg;
    save_store ()

  let uninstall pid =
    Pkg_table.remove !table pid;
    save_store ()

  let lookup pid = Pkg_table.find !table pid

  let info () =
    Fmt.str "#pkg = %d@." (Pkg_table.length !table)
    ^ Fmt.str "%a" (Std.pp_table Pkg_table.iter Fmt.nop) !table

  (* ;
     Fmt.(pr "" list ~sep:cut  ) *)

  let () = init ()
end
