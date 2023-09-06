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
