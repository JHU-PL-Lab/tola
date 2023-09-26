open Std.Cool_strict

module type S = sig
  type t

  val compare : t -> t -> cool
  val of_str : string -> t
  val to_str : t -> string
end

module Total_ordering : S = struct
  type t = int

  let compare t1 t2 = if t1 > t2 then Gt else if t1 = t2 then Eq else Lt
  let of_str = int_of_string
  let to_str = string_of_int
end
