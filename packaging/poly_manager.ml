open Package

(* (C : Manager.CONFIG) *)

module type PKGM_CONFIG = sig
  val t : Store.Store_spec.config
end

module Make
    (P : PACKAGE)
    (V : Versioning.Version_logic.V_str)
(* : Manager.S with module P = P *) =
struct
  module P = P
  module VL = Versioning.Version_logic.Make (P) (V)
  module Pkg_store = Store_v2.Poly_file_store_make (P)

  type t = {
    config : Store.Store_spec.config;
    local_store : Pkg_store.t;
    remote_stores : Pkg_store.t list;
  }

  (* init *)
  let init (pkgm_config : Store.Store_spec.config) =
    {
      config = pkgm_config;
      local_store =
        Pkg_store.init pkgm_config.local_store pkgm_config.pkgm_id
          pkgm_config.meta_file;
      remote_stores =
        List.map
          (fun (store : Store.Store_spec.store_detail) ->
            Pkg_store.init store pkgm_config.pkgm_id pkgm_config.meta_file)
          pkgm_config.remote_stores;
    }

  (* local api *)
  let install state pid pkg =
    Pkg_store.save_pkg ~remove_first:true state.local_store pid pkg

  let uninstall state pid = Pkg_store.remove_pkg state.local_store pid
  let lookup state pid = Pkg_store.lookup state.local_store pid
  let lookup_pname state pname = Pkg_store.lookup_pname state.local_store pname

  let info state =
    Fmt.(
      str "--local--@.%s@.--remote--@.%a@."
        (Pkg_store.info state.local_store)
        (list ~sep:sp string)
        (List.mapi
           (fun k store -> Pkg_store.info ~i:(k + 1) store)
           state.remote_stores))

  (* remote api *)
  (* let publish pid pkg = Remote_store.save_pkg ~remove_first:true pid pkg
     let unpublish pid = Remote_store.remove_pkg pid

     let fetch pid =
       let pkg_content = Remote_store.load_pkg pid in
       Local_store.save_pkg pid pkg_content

     let remote_info () = Remote_store.info () *)
end
