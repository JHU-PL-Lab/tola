open Package

module type S = sig
  type t

  module P : PACKAGE

  (* for local *)
  val init : unit -> unit
  val reset : unit -> unit
  val install : P.pid -> P.pkg -> unit (* system_state may be changed *)
  val uninstall : P.pid -> unit
  val lookup : P.pid -> P.pkg
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
