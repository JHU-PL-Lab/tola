open Package

(* The PACKAGE is a bundled abstract definition for pid, payload, and meta.
   It doesn't say anything about versioning.

   Who needs a version-equipped package definition?
   Who needs a no-version pre-package? No one unless for programming flexibility.

   A Manager.S should provided a version-equipped package. All the managers op are also based on the version-equipped package.
*)

(* id = {name, version} *)

module type S = sig
  type t

  module P : PACKAGE

  (* for local *)
  val init : unit -> unit
  val reset : unit -> unit
  val install : P.pid -> P.pkg -> unit (* system_state may be changed *)
  val uninstall : P.pid -> unit
  val lookup : P.pid -> P.pkg
  val lookup_pname : string -> P.pkg
  val info : unit -> string

  (* for remote *)
  val publish : P.pid -> P.pkg -> unit
  val unpublish : P.pid -> unit
  val fetch : P.pid -> unit
  val remote_info : unit -> string
end

module type CONFIG = sig
  val pkgm_id : string
  val local_root : string
  val remote_root : string
end

module type PKG_FILE_CONFIG = sig
  val file_name : string
end

module Pkg_in_json = struct
  let file_name = "main.json"
end
