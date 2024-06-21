module Id = Std.Id

type exp =
  | Input
  | Int of int
  | Plus of exp * exp
  | Minus of exp * exp
  | If0 of exp * exp * exp
  | Var of Id.t
  | Fun of Id.t * exp
  | App of exp * exp * int
  | Shadow of exp * Id.t * call_stack

and call_stack = int list [@@deriving eq, ord]

let assign_labal e =
  let c = ref (-1) in
  let rec loop e =
    match e with
    | Plus (e1, e2) -> Plus (loop e1, loop e2)
    | Minus (e1, e2) -> Minus (loop e1, loop e2)
    | If0 (e0, e1, e2) -> If0 (loop e0, loop e1, loop e2)
    | Fun (Id x, e) -> Fun (Id x, loop e)
    | App (e1, e2, _) ->
        let e1' = loop e1 in
        let e2' = loop e2 in
        c := !c + 1;
        App (e1', e2', !c)
    | Shadow (e, x, cs) -> Shadow (loop e, x, cs)
    | _ -> e
  in
  loop e

module Tagless = struct
  let input = Input
  let int i = Int i
  let plus e1 e2 = Plus (e1, e2)
  let minus e1 e2 = Minus (e1, e2)
  let if0 e1 e2 e3 = If0 (e1, e2, e3)
  let var x = Var (Id x)
  let fun_ x e = Fun (Id x, e)
  let app e1 e2 = App (e1, e2, 0)
end

let binop_ints op e1 e2 =
  match (e1, e2) with
  | Int i1, Int i2 -> Int (op i1 i2)
  | _ -> failwith "must be on ints"

let cond_int cond e =
  match e with Int i -> cond i | _ -> failwith "must be on int"

let rec pp_exp ~compact oc e =
  let pp_exp = pp_exp ~compact in
  let open Fmt in
  match e with
  | Input -> string oc "<.>"
  | Int i -> int oc i
  | Plus (e1, e2) -> Fmt.pf oc "%a + %a" pp_exp e1 pp_exp e2
  | Minus (e1, e2) -> Fmt.pf oc "%a - %a" pp_exp e1 pp_exp e2
  | If0 (e0, e1, e2) ->
      Fmt.pf oc "if0 %a then %a else %a" pp_exp e0 pp_exp e1 pp_exp e2
  | Var x -> Id.pp oc x
  | Fun (Id x, e) ->
      if compact then Fmt.pf oc "(fun %s -> ...)" x
      else Fmt.pf oc "(fun %s -> %a)" x pp_exp e
  | App (e1, e2, lab) -> Fmt.pf oc "(%a %a)_[%d]" pp_exp e1 pp_exp e2 lab
  | Shadow (e, x, _) -> Fmt.pf oc "(%a) [s:%a]" pp_exp e Id.pp x

let pp_exp_compact = pp_exp ~compact:true
let pp_exp = pp_exp ~compact:false
let show_exp = Fmt.to_to_string pp_exp
let pp_cs = Fmt.brackets @@ Fmt.list ~sep:(Fmt.any "_") Fmt.int
let pp_cs_compact = Fmt.list ~sep:(Fmt.any "_") Fmt.int
