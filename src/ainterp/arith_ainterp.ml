open Langs

let ainterp eval e =
  let open Arith in
  let open Just_sign in
  match e with
  | Input -> all
  | Int x -> just_of_int x
  | Plus (e1, e2) -> binop plus (eval e1) (eval e2)
  | If0 (e0, e1, e2) ->
      let if_op v0 = match v0 with Zero -> eval e1 | _ -> eval e2 in
      fold if_op (eval e0)
