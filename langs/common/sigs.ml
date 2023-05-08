module type LANG = sig
  type t

  val show : t -> string
  val pp : t Fmt.t
end

module type FIN_LANG = sig
  include LANG

  val domain : t list
end

module type ID = sig
  type t

  val show : t -> string
  val pp : t Fmt.t
end

module type FIN_ID = sig
  include ID

  val domain : t list
end
