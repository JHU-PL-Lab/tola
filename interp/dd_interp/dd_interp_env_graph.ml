open Langs.Dd
module V = Dd_val.With_closure
open Dd_graph

let interp e =
  let g = G.create () in
  let interp_step eval cs env e : V.t =
    let open V in
    (* Fmt.pr "%a; %a@." pp_exp e pp_env env; *)
    let eval' e = eval cs env e in
    match e with
    | Input -> Int 42
    | Int i -> Int i
    | Plus (e1, e2) -> binop_ints ( + ) (eval' e1) (eval' e2)
    | Minus (e1, e2) -> binop_ints ( - ) (eval' e1) (eval' e2)
    | If0 (e0, e1, e2) ->
        if cond_int (fun x -> x = 0) (eval' e0) then eval' e1 else eval' e2
    | Var x ->
        let v, cs' = List.assoc x env in
        if not (equal_call_stack cs cs') then
          G.add_edge g (Node.Use (x, cs)) (Node.Def (x, cs'));
        v
    | Fun (x, body) -> Closure (env, x, body)
    | App (e1, e2, lab) -> (
        match eval' e1 with
        | Closure (env_c, x, body) ->
            let v2 = eval cs env e2 in
            let cs' = lab :: cs in
            G.add_edge g (Node.Cs cs') (Node.Cs cs);
            G.add_edge g (Node.Def (x, cs')) (Node.V_clo (v2, cs));
            let env' = (x, (v2, cs')) :: env_c in
            eval cs' env' body
        | _ -> failwith "must be fun")
    | _ -> failwith "shadow"
  in
  let v = (Std.naive_fix interp_step) [] [] e in
  (g, v)
