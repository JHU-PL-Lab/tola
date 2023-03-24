type exp =
  | Input
  | Int of int
  | Plus of exp * exp
  | If0 of exp * exp * exp
  | Fun of exp * exp
  | App of exp * exp
[@@deriving eq, show { with_path = false }]
