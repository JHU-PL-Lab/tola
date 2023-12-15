module type S = sig
  type t

  val compare : t -> t -> Std.Ordering.t
  val of_str : string -> t
  val to_str : t -> string
end

module Total_ordering : S = struct
  type t = int

  let compare t1 t2 =
    let open Std.Ordering in
    if t1 > t2 then Greater else if t1 = t2 then Equal else Less

  let of_str = int_of_string
  let to_str = string_of_int
end
