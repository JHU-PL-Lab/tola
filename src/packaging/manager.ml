open Base
open Package
open Tola_std
open Tola_std.Std.File_infix

(* The PACKAGE is a bundled abstract definition for pid, payload, and meta.
   It doesn't say anything about versioning.

   Who needs a version-equipped package definition?
   Who needs a no-version pre-package? No one unless for programming flexibility.

   A Manager.S should provided a version-equipped package. All the managers op are also based on the version-equipped package.
*)

(* id = {name, version} *)

(* module type CONFIG = sig
  val pkgm_id : string
  val local_root : string
  val remote_root : string
  val file_name : string
end *)

module type OPTIONS = sig
  val use_pname : bool
end

module Default_options : OPTIONS = struct
  let use_pname = true
end

module type S = sig
  type t

  module P : PACKAGE
  module VL : Versioning.Version_logic.S

  type deps
  (* init *)

  (* for local *)

  val init : Spec.config -> t
  val config : t -> Spec.config
  val reset : t -> unit
  val install : t -> P.pid -> P.pkg -> unit
  val uninstall : t -> P.pid -> unit
  val lookup : t -> P.pid -> P.pkg
  val lookup_local : t -> string -> P.pkg
  val info : t -> string

  (* for remote *)
  val publish : t -> P.pid -> P.pkg -> unit
  val unpublish : t -> P.pid -> unit
  val fetch : t -> P.pid -> unit
end

module type One = sig
  type t

  val manager : t
end

open Package

(* A manager module is to provide interface for the users.
   A store is to implement the functionalities.

   A basic pkgm is with a local store and a remote store.
   The store is a json-file based package as `<pid>.json`.

   Now the question is using a file system and the structure of the file system
   is not bundled. The structure of a package and the structure of a store should
   be able in configurated.
*)

module Make (P : PACKAGE) : S with module P = P and module VL = P.VL
(* and module VL = Versioning.Version_logic.Make(P)(V) *) = struct
  module P = P

  (* type payload = P.payload *)

  (* module VL =
    Versioning.Version_logic.Make
      (struct
        type pname = P.PN.t [@@deriving yojson]

        let pname_to_str = P.PN.t_to_str
        let str_to_pname = P.PN.str_to_t
      end)
      (V) *)

  module VL = P.VL

  type deps = VL.exp

  module Pkg_store = Store.File_store_make (P)

  type t = {
    config : Spec.config;
    local_store : Pkg_store.t;
    remote_stores : Pkg_store.t list;
  }

  let save_config (cfg : Spec.config) =
    Std.write_file_all
      (cfg.root $/ cfg.pkgm_id $/ "config.json")
      (cfg |> Spec.yojson_of_config |> Yojson.Safe.pretty_to_string)

  (* init *)
  let init (pkgm_config : Spec.config) =
    save_config pkgm_config;
    {
      config = pkgm_config;
      local_store = Pkg_store.init pkgm_config pkgm_config.local_store;
      remote_stores =
        List.map
          ~f:(fun (store : Spec.store_spec) -> Pkg_store.init pkgm_config store)
          pkgm_config.remote_stores;
    }

  let config state = state.config

  (* local api *)
  let install state pid pkg =
    Pkg_store.save_pkg ~remove_first:true state.local_store pid pkg

  let uninstall state pid = Pkg_store.remove_pkg state.local_store pid
  let lookup state pid = Pkg_store.lookup state.local_store pid
  let lookup_local state pname = Pkg_store.lookup_pname state.local_store pname

  let info state =
    Fmt.(
      str "--local--@.%s@.--remote--@.%a@."
        (Pkg_store.info state.local_store)
        (list ~sep:sp string)
        (List.mapi
           ~f:(fun k store -> Pkg_store.info ~i:(k + 1) store)
           state.remote_stores))

  (* remote api *)
  (* let publish pid pkg = Remote_store.save_pkg ~remove_first:true pid pkg
     let unpublish pid = Remote_store.remove_pkg pid

     let fetch pid =
       let pkg_content = Remote_store.load_pkg pid in
       Local_store.save_pkg pid pkg_content

     let remote_info () = Remote_store.info () *)

  let reset state = Pkg_store.reset state.local_store

  let publish state pid pkg =
    Pkg_store.save_pkg
      (List.hd_exn state.remote_stores)
      ~remove_first:true pid pkg

  let unpublish state pid =
    Pkg_store.remove_pkg (List.hd_exn state.remote_stores) pid

  let fetch _pid = failwith "not implemented!"
  (*
      let pkg_content = Remote_store.load_pkg pid in
      Local_store.save_pkg pid pkg_content *)
end
