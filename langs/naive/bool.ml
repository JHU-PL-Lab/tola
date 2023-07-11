type exp =
  | True
  | False
  | And of exp * exp
  | Or of exp * exp
  | Implies of exp * exp
  | Not of exp
[@@deriving show { with_path = false }]