open Langs
open Dd
open Dd_graph

let rec subst cs_x cs_v x (v : exp) (e : exp) =
  let loop e = subst cs_x cs_v x v e in
  match e with
  | Input -> e
  | Int _ -> e
  | Var y -> if Id.equal y x then Shadow (v, y, cs_x) else e
  | Fun (y, e) -> if Id.equal y x then Fun (y, e) else Fun (y, loop e)
  | App (e1, e2, lab) -> App (loop e1, loop e2, lab)
  | Plus (e1, e2) -> Plus (loop e1, loop e2)
  | Minus (e1, e2) -> Minus (loop e1, loop e2)
  | If0 (e0, e1, e2) -> If0 (loop e0, loop e1, loop e2)
  | Shadow (e, x, cs) -> Shadow (loop e, x, cs)

let rec interp g (cs : call_stack) (e : exp) =
  (* Fmt.pr "@[<h>%a@]@." pp_exp e; *)
  let loop e = interp g cs e in
  match e with
  | Input -> Int 42
  | Int i -> Int i
  | Var _ -> failwith "should be substituted"
  | Fun (y, e) -> Fun (y, e)
  | App (e1, e2, lab) -> (
      match loop e1 with
      | Fun (x, e) ->
          let v2 = loop e2 in
          let cs_x = lab :: cs in
          (* G.add_edge g (Node.Id (x, cs_x)) (Node.Exp (v2, cs)); *)
          interp g cs_x (subst cs_x cs x v2 e)
      | _ -> failwith "must be fun")
  | Plus (e1, e2) -> binop_ints ( + ) (loop e1) (loop e2)
  | Minus (e1, e2) -> binop_ints ( - ) (loop e1) (loop e2)
  | If0 (e0, e1, e2) ->
      if cond_int (fun i -> i = 0) (loop e0) then loop e1 else loop e2
  | Shadow (e, y, cs_v) ->
      let v = loop e in
      if not (equal_call_stack cs cs_v) then
        G.add_edge g (Node.Exp (Var y, cs)) (Node.Exp (Var y, cs_v));
      v

let interp e =
  let g = G.create () in
  let r = interp g [] e in
  (g, r)
