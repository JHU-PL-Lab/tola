type exp =
  | Input
  (* | Output of int *)
  | Int of int
  | Plus of exp * exp
  | Minus of exp * exp
  | If0 of exp * exp * exp
  | Var of Id.t
  | Fun of Id.t * exp
  | App of exp * exp * int
  | Let of Id.t * exp
  | Fix of Id.t * exp
