module Id = Tola_std.Std.Id

type exp = Var of Id.t | Fun of Id.t * exp | App of exp * exp
[@@deriving show { with_path = false }]
