open Langs.Dd
module V = Dd_val.With_closure
open V

let empty_env = []

let interp_step eval (env, e) : V.t =
  let eval' e : V.t = eval (env, e) in
  match e with
  | Input -> Int 42
  | Int i -> Int i
  | Plus (e1, e2) -> binop_ints ( + ) (eval' e1) (eval' e2)
  | Minus (e1, e2) -> binop_ints ( - ) (eval' e1) (eval' e2)
  | If0 (e0, e1, e2) ->
      if cond_int (fun x -> x = 0) (eval' e0) then eval' e1 else eval' e2
  | Var x -> fst (List.assoc x env)
  | Fun (x, body) -> V.Closure (env, x, body)
  | App (e1, e2, _) -> (
      match eval' e1 with
      | Closure (env, x, body) ->
          let v2 = eval' e2 in
          let env' = (x, (v2, [])) :: env in
          eval (env', body)
      | _ -> failwith "must be fun")
  | _ -> failwith "shadow"

let interp e = (Tola_std.Std.naive_fix interp_step) (empty_env, e)
