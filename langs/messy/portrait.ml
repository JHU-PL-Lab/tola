type exp =
  | Input
  | Int of int
  | Plus of exp * exp
  | If0 of exp * exp * exp
  | Var of Id.t
  | Fun of Id.t * exp
  (* | Sad of Id.t * exp *)
  | Let of Id.t * exp * exp
  | App of exp * exp
  | Dyn_env of exp
  | Sta_env of exp
[@@deriving eq, show { with_path = false }]

module Tagless = struct
  let input = Input
  let int i = Int i
  let plus e1 e2 = Plus (e1, e2)
  let if0 e1 e2 e3 = If0 (e1, e2, e3)
  let var x = Var (Id x)
  let fun_ x e = Fun (Id x, e)
  let let_ x e1 e2 = Let (Id x, e1, e2)
  let app e1 e2 = App (e1, e2)
  let dyn e = Dyn_env e
  let sta e = Sta_env e
end
