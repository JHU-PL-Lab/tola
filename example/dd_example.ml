open Lang
open Dd
open Id
(*
   type exp =
     Input | Int of int | Plus of exp * exp | If0 of exp * exp * exp
     | Fun of exp * exp | App of exp * exp
     [@@deriving eq, show { with_path = false }]
*)

let n0 = Int 0
let n3 = Int 3
let n4 = Int 4
let ne3 = Int (-3)
let ne4 = Int (-4)
let i = Input
let e1 = Plus (n3, n4)
let e2 = Minus (ne3, n4)
let e3 = If0 (n0, n3, n4)
let e4 = If0 (n0, n3, ne3)
let e5 = If0 (i, If0 (i, n3, n0), ne3)
let e6 = If0 (i, n4, ne4)
let x = Ident "x"
let y = Ident "y"
let z = Ident "z"
let id = Fun (x, Var x)
let const = Fun (x, Fun (y, Var x))
let sum = Fun (x, Fun (y, Plus (Var x, Var y)))
let sum_3 = App (sum, n3)
let sum_3_4 = App (App (sum, n3), n4)
let sum_3_x = App (App (sum, n3), Input)
let all_e = [ e1; e2; e3; e4; e5; e6 ]
let all_f = [ id; const; sum ]
let all_apps = [ sum_3; sum_3_4; sum_3_x ]
let all = all_e @ all_f @ all_apps
let dump () = Fmt.(pr "@[<v>%a@]@;@." (list Dd.pp_exp) all)
