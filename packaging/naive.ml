(* A naive pkgm is with local store only *)

module type NAIVE_MANAGER = sig
  type t
  type pid
  type pkg

  module P : Package.PACKAGE with type pid = pid and type pkg = pkg

  val init : unit -> unit
  val reset : unit -> unit
  val install : pid -> pkg -> unit
  val uninstall : pid -> unit
  val lookup : pid -> pkg
  val info : unit -> string
end

module type NAIVE_CONFIG = sig
  val pkgm_id : string
  val super_root : string
end
