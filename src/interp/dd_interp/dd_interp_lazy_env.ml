open Langs
open Dd
open Dd_graph
module V = Dd_val.With_callstack

type binding_map = (call_stack * (exp * Id.t * call_stack)) list

let add_binding bmap cs0 (e, x, cs) =
  (* Fmt.pr "@[<h>Add %a @ %a@]@." pp_cs cs0 Id.pp x; *)
  bmap := (cs0, (e, x, cs)) :: !bmap

let rec get_binding bmap cs x =
  (* Fmt.pr "Try %a@." pp_cs cs; *)
  let e', x', cs' = List.assoc cs !bmap in
  if Id.equal x' x then (cs', e') else get_binding bmap (List.tl cs) x

let interp e =
  let g = G.create () in
  let open V in
  let bmap = ref [] in
  let add_binding = add_binding bmap in
  let get_binding = get_binding bmap in

  let rec interp' cs e : V.t =
    Fmt.pr "@[<h>%a@]@." pp_exp e;
    ignore @@ read_line ();
    let interp e = interp' cs e in
    match e with
    | Input -> Int 42
    | Int i -> Int i
    | Var x ->
        let cs', e' = get_binding cs x in
        (* G.add_edge g (Node.Id (x, cs)) (Node.Exp (e, cs')); *)
        interp' cs' e'
    | Fun (y, e) -> Fun_with_cs (y, e, cs)
    | App (e1, e2, lab) -> (
        match interp e1 with
        | Fun_with_cs (x, body, cs_body) ->
            let cs' = lab :: cs_body in
            (* G.add_edge g (Node.Cs cs) (Node.Cs cs');
               G.add_edge g (Node.Cs cs) (Node.Exp (e2, cs));

               G.add_edge g (Node.Id (x, cs')) (Node.Exp (e2, cs)); *)
            G.add_edge g (Node.Cs cs') (Node.Def (x, cs'));
            add_binding cs' (e2, x, cs);
            interp' cs' body
        | _ -> failwith "must be fun")
    | Plus (e1, e2) -> binop_ints ( + ) (interp e1) (interp e2)
    | Minus (e1, e2) -> binop_ints ( - ) (interp e1) (interp e2)
    | If0 (e0, e1, e2) ->
        if cond_int (fun i -> i = 0) (interp e0) then interp e1 else interp e2
    | Shadow (e, _, _) -> interp e
  in
  let v = interp' [] e in
  (g, v)
