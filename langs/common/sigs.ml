(* Concrete definitions *)

module type N = sig
  val n : int
end

module type SHOW = sig
  type t

  val show : t -> string
  val pp : t Fmt.t
end

module type ORD = sig
  type t

  val equal : t -> t -> bool
  val compare : t -> t -> int
end

module type FINITE = sig
  type t

  val domain : t list
  val dump_domain : unit -> unit
end

(* Module signatures *)

module type LANG = sig
  type t

  include ORD with type t := t
  include SHOW with type t := t
end

module type ID = sig
  type t

  include ORD with type t := t
  include SHOW with type t := t
end

module type FIN_LANG = sig
  include LANG
  include FINITE with type t := t
end

module type FIN_ID = sig
  include ID
  include FINITE with type t := t
end
