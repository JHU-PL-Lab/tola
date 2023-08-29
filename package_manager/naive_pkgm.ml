(* A naive pkgm maintains pkg with local marshalled store.
   It's language-agnostic.
*)

open Package
open Naive

(* simple pkgm with persistency *)

module Make (P : PACKAGE) (Table : Hashtbl.S with type key = P.pid) :
  NAIVE_MANAGER
    with type pid = P.pid
     and type pkg = P.pkg
     and type t = P.pkg Table.t = struct
  type pid = P.pid
  type pkg = P.pkg
  type t = pkg Table.t

  let home = Sys.getenv "HOME"
  let pkgm_root = home ^ "/.pkgm"
  let text_pkgm_id = "text"
  let text_pkgm_root = pkgm_root ^ "/" ^ text_pkgm_id
  let text_pkgm_store = text_pkgm_root ^ "/" ^ "data"
  let table = ref (Table.create 64)

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
    Table.add !table pid pkg;
    save_store ()

  let uninstall pid =
    Table.remove !table pid;
    save_store ()

  let lookup pid = Table.find !table pid

  let info () =
    Fmt.str "#pkg = %d@." (Table.length !table)
    ^ Fmt.str "%a" (Std.pp_std_table Table.iter P.pp_pid Fmt.nop) !table

  let () = init ()
end

(* simple pkgm without persistency *)

(* module Pkgm_ephemeral :
     NAIVE_MANAGER
       with type pid = String_pkg.pid
        and type pkg = String_pkg.pkg
        and type t = String_pkg.pkg Pkg_table.t = struct
     type pid = String_pkg.pid
     type pkg = String_pkg.pkg
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
   end *)
