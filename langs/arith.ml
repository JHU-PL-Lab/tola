type exp = Input | Int of int | Plus of exp * exp | If0 of exp * exp * exp
[@@deriving eq]

let pp oc e =
  let open Fmt in
  let rec loop ?(inner = true) oc e =
    let lift fmt = if inner then "(" ^^ fmt ^^ ")" else fmt in
    let pp = loop ~inner:true in
    match e with
    | Input -> string oc "in"
    | Int x -> if x >= 0 then int oc x else (parens int) oc x
    | Plus (e1, e2) -> Fmt.pf oc (lift "%a + %a") pp e1 pp e2
    | If0 (e0, e1, e2) ->
        Fmt.pf oc (lift "if (%a == 0) then %a else %a") pp e0 pp e1 pp e2
  in
  loop ~inner:false oc e

module Exp_hashed = struct
  type t = exp

  let equal = equal_exp
  let hash = Hashtbl.hash
end

module Fixed = Fixed.Make (Exp_hashed)
