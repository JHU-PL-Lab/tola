open Langs.Arith

let interp eval e =
  match e with
  | Input -> 42
  | Int i -> i
  | Plus (e1, e2) -> eval e1 + eval e2
  | If0 (e0, e1, e2) -> if eval e0 = 0 then eval e1 else eval e2
