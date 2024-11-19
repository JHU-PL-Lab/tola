(* A manager module is to provide interface for the users.
   A store is to implement the functionalities.

   A basic pkgm is with a local store and a remote store.
   The store is a json-file based package as `<pid>.json`.

   Now the question is using a file system and the structure of the file system is not bundled. The structure of a package and the structure of a store should be able in configurated.
*)
open Package

module Make
    (P : PACKAGE)
    (V : Versioning.Version_logic.V_str)
    (C : Manager.CONFIG)
    (PC : Manager.PKG_FILE_CONFIG) : Manager.S with module P = P = struct
  module P = P
  module VL = Versioning.Version_logic.Make (P) (V)

  module Local_store =
    Store.File_store_make (P) (PC)
      (struct
        let root = C.local_root
      end)

  module Remote_store =
    Store.File_store_make (P) (PC)
      (struct
        let root = C.remote_root
      end)

  type t = P.pkg Local_store.Table.t

  (* init *)
  let init () = Local_store.init ()

  (* local api *)
  let install pid pkg =
    Local_store.add_table pid pkg;
    Local_store.remove_pkg pid;
    Local_store.save_pkg pid pkg

  let uninstall pid =
    Local_store.remove_table pid;
    Local_store.remove_pkg pid

  let reset () = Local_store.reset ()
  let lookup pid = Local_store.lookup pid
  let lookup_pname pname = Local_store.lookup_pname pname
  let info () = Local_store.info ()

  (* remote api *)
  let publish pid pkg =
    Remote_store.remove_pkg pid;
    Remote_store.save_pkg pid pkg

  let unpublish pid = Remote_store.remove_pkg pid

  let fetch pid =
    let pkg_content = Remote_store.load_pkg pid in
    Local_store.save_pkg pid pkg_content

  let remote_info () = Remote_store.info ()
end
