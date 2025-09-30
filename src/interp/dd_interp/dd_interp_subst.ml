open Langs
open Dd

let rec subst e x e' =
  match e with
  | Input -> e
  | Int _ -> e
  | Var y -> if Id.equal y x then e' else e
  | Fun (y, e) -> if Id.equal y x then e else Fun (y, subst e x e')
  | App (e1, e2, lab) -> App (subst e1 x e', subst e2 x e', lab)
  | Plus (e1, e2) -> Plus (subst e1 x e', subst e2 x e')
  | Minus (e1, e2) -> Minus (subst e1 x e', subst e2 x e')
  | If0 (e0, e1, e2) -> If0 (subst e0 x e', subst e1 x e', subst e2 x e')
  | Shadow (e, y, cs) -> Shadow (subst e x e', y, cs)

let rec interp e =
  match e with
  | Input -> Int 42
  | Int i -> Int i
  | Var _ -> failwith "should be substituted"
  | Fun (y, e) -> Fun (y, e)
  | App (e1, e2, _) -> (
      match interp e1 with
      | Fun (x, e) ->
          let v2 = interp e2 in
          interp (subst e x v2)
      | _ -> failwith "must be fun")
  | Plus (e1, e2) -> binop_ints ( + ) (interp e1) (interp e2)
  | Minus (e1, e2) -> binop_ints ( - ) (interp e1) (interp e2)
  | If0 (e0, e1, e2) ->
      if cond_int (fun i -> i = 0) (interp e0) then interp e1 else interp e2
  | Shadow (e, _, _) -> interp e
