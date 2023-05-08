open Langs
open Dd
open Id

let n0 = Int 0
let n1 = Int 1
let n2 = Int 2
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

open Tagless

let sum_3 = app sum n3
let sum_3_4 = app (app sum n3) n4
let sum_3_x = app (app sum n3) Input
let aid e = app id e
let id1 = app (app (aid sum) n3) n4
let id2 = app (app (aid sum) n3) (aid n4)
let id3 = app (aid (app (aid sum) (aid n3))) (aid n4)
let ap_f = fun_ "f" (fun_ "e" (app (var "f") (var "e")))
let ap e1 e2 = (app (app (var "ap") e1)) e2
let with_ap e = app (fun_ "ap" e) ap_f
let e7 = with_ap (ap id n0)

let count =
  fun_ "f"
    (fun_ "n"
       (if0 (var "n") n0
          (plus n1 (app (app (var "f") (var "f")) (minus (var "n") n1)))))

let countcount0 = app (app count count) n0
let countcount1 = app (app count count) n1
let countcount2 = app (app count count) n2
let countcount3 = app (app count count) n3

(* 
   
*)
let all_e = [ e1; e2; e3; e4; e5; e6 ]
let all_f = [ id; const; sum ]
let all_apps = [ sum_3; sum_3_4; sum_3_x ]
let all = all_e @ all_f @ all_apps
let dump () = Fmt.(pr "@[<v>%a@]@;@." (list Dd.pp_exp) all)
