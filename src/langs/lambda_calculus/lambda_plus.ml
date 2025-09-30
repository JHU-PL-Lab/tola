open Base
module Id = Tola_std.Std.Id

type exp =
  | Input
  | Int of int
  | Plus of exp * exp
  | If0 of exp * exp * exp
  | Var of Id.t
  | Fun of Id.t * exp
  | App of exp * exp
[@@deriving equal, show { with_path = false }]
