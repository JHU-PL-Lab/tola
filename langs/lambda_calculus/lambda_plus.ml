type exp =
  | Input
  | Int of int
  | Plus of exp * exp
  | If0 of exp * exp * exp
  | Var of Id.t
  | Fun of Id.t * exp
  | App of exp * exp
[@@deriving eq, show { with_path = false }]
