type typ = Nat | TArrow of typ * typ [@@deriving show { with_path = false }]

type exp =
  | Var of Id.t
  | Z
  | S of exp
  | If_zero of exp * Id.t * exp * exp
  | Fun of Id.t * typ * exp
  | App of exp * exp
[@@deriving show { with_path = false }]