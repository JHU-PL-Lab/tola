(* A naive pkgm is with local store only *)

module type NAIVE_MANAGER = sig
  type t
  type pid
  type pkg

  val init : unit -> unit
  val reset : unit -> unit
  val set_store : t -> unit
  val get_store : unit -> t
  val install : pid -> pkg -> unit
  val uninstall : pid -> unit
  val lookup : pid -> pkg
  val info : unit -> string
end

module type NAIVE_CONFIG = sig
  val pkgm_root : string
  val pkgm_id : string
end
