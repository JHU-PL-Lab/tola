type typ = TBase | TArrow of typ * typ [@@deriving show { with_path = false }]

type exp = Base | Var of Id.t | Fun of Id.t * typ * exp | App of exp * exp
[@@deriving show { with_path = false }]