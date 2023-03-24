open Lang
open Dd

module Value = struct
  type value = Int of int | Closure of env * Id.t * exp
  and env = (Id.t * value) list [@@deriving eq]

  let rec pp_value oc = function
    | Int i -> Fmt.int oc i
    | Closure (env, x, e) ->
        Fmt.pf oc "(clo %a -> %a) @@ %a." Id.pp x pp_exp e pp_env env

  and pp_env oc = Fmt.(list ~sep:sp (pair ~sep:(any "=") Id.pp pp_value)) oc

  let binop_ints op e1 e2 =
    match (e1, e2) with
    | Int i1, Int i2 -> Int (op i1 i2)
    | _ -> failwith "must be on ints"

  let cond_int cond e =
    match e with Int i -> cond i | _ -> failwith "must be on int"
end

let empty_env = []

let concrete_interp (env, e) eval : Value.value =
  let eval' e = eval (env, e) in
  match e with
  | Input -> Int 0
  | Int i -> Int i
  | Plus (e1, e2) -> Value.binop_ints ( + ) (eval' e1) (eval' e2)
  | Minus (e1, e2) -> Value.binop_ints ( - ) (eval' e1) (eval' e2)
  | If0 (e0, e1, e2) ->
      if Value.cond_int (fun x -> x = 0) (eval' e0) then eval' e1 else eval' e2
  | Var x -> List.assoc x env
  | Fun (x, body) -> Value.Closure (env, x, body)
  | App (e1, e2) -> (
      match eval' e1 with
      | Value.Closure (env, x, body) ->
          let v2 = eval' e2 in
          let env' = (x, v2) :: env in
          eval (env', body)
      | _ -> failwith "must be fun")
