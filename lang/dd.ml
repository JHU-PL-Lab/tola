type exp =
  | Input
  | Int of int
  | Plus of exp * exp
  | Minus of exp * exp
  | If0 of exp * exp * exp
  | Var of Id.t
  | Fun of Id.t * exp
  | App of exp * exp
[@@deriving eq]

let rec pp_exp oc e =
  let open Fmt in
  match e with
  | Input -> string oc "<.>"
  | Int i -> int oc i
  | Plus (e1, e2) -> Fmt.pf oc "%a + %a" pp_exp e1 pp_exp e2
  | Minus (e1, e2) -> Fmt.pf oc "%a - %a" pp_exp e1 pp_exp e2
  | If0 (e0, e1, e2) ->
      Fmt.pf oc "if %a then %a else %a" pp_exp e0 pp_exp e1 pp_exp e2
  | Var x -> Id.pp oc x
  | Fun (Ident x, e) -> Fmt.pf oc "fun %s -> %a" x pp_exp e
  | App (e1, e2) -> Fmt.pf oc "(%a) %a" pp_exp e1 pp_exp e2

let show_exp = Fmt.to_to_string pp_exp