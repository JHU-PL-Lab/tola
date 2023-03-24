open Core

module Just_sign_M = struct
  module T = struct
    type t = Pos | Zero | Neg [@@deriving equal, compare, hash, sexp]
  end

  include T
  include Comparator.Make (T)
end

include Just_sign_M

let of_int x = if x > 0 then Pos else if x = 0 then Zero else Neg
let to_string = function Pos -> "+" | Zero -> "0" | Neg -> "-"
let pp_sign = Fmt.of_to_string to_string

type set = Set.M(Just_sign_M).t

let pp_set : set Fmt.t = Std.pp_set pp_sign

module Element_ops = struct
  let all_in_list = [ Pos; Zero; Neg ]
  let all = Set.of_list (module Just_sign_M) all_in_list
  let just_pos = Set.singleton (module Just_sign_M) Pos
  let just_neg = Set.singleton (module Just_sign_M) Neg
  let just_elem x = Set.singleton (module Just_sign_M) x
  let just_of_int x = x |> of_int |> just_elem
end

include Element_ops

module Arith_ops = struct
  let negate = function Pos -> Neg | Neg -> Pos | Zero -> Zero

  let plus x1 x2 =
    match (x1, x2) with
    | Pos, Pos -> just_pos
    | Neg, Neg -> just_neg
    | Pos, Neg | Neg, Pos -> all
    | x, Zero | Zero, x -> just_elem x

  let minus x1 x2 = plus x1 (negate x2)

  let eq x1 x2 =
    match (x1, x2) with
    | Pos, Pos -> Set.of_list (module Bool) [ true; false ]
    | Neg, Neg -> Set.of_list (module Bool) [ true; false ]
    | Zero, Zero -> Set.singleton (module Bool) true
    | _, _ -> Set.singleton (module Bool) false
end

include Arith_ops

module Foldable = struct
  let binop binop s1 s2 =
    Set.fold
      ~init:(Set.empty (module Just_sign_M))
      ~f:(fun acc v1 ->
        Set.fold ~init:acc ~f:(fun acc v2 -> Set.union (binop v1 v2) acc) s2)
      s1

  let binop_s binop s1 s2 =
    Set.fold
      ~init:(Set.empty (module Just_sign_M))
      ~f:(fun acc v1 ->
        Set.fold ~init:acc ~f:(fun acc v2 -> Set.union (binop v1 v2) acc) s2)
      s1

  let fold op s1 =
    Set.fold
      ~init:(Set.empty (module Just_sign_M))
      ~f:(fun acc v1 -> Set.union (op v1) acc)
      s1
end

include Foldable
