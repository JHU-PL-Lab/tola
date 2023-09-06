(* A naive pkgm maintains pkg with local marshalled store.
   It's language-agnostic.
*)

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

  let super_root = C.super_root
  let text_pkgm_root = Filename.concat super_root C.pkgm_id
  let text_pkgm_store = Filename.concat text_pkgm_root "data"
  let table = ref (Table.create 64)
  let set_store table' = table := table'

  let reset () =
    if Sys.file_exists text_pkgm_store then Sys.remove text_pkgm_store

  let load_store () =
    let (table : t) = Std.read_marshal text_pkgm_store in
    set_store table

  let save_store () = Std.write_marshal text_pkgm_store !table

  let init () =
    if not (Sys.file_exists super_root) then Sys.mkdir super_root 0o755;
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
    let pp_pid = Fmt.using P.pid_to_str Fmt.string in

    Fmt.str "#pkg = %d@." (Table.length !table)
    ^ Fmt.str "%a" (Std.pp_std_table Table.iter pp_pid Fmt.nop) !table

  let () = init ()
end
