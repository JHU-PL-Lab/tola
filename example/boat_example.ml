open Langs
open Lang_boat
open Tagless

let n1 = int 1
let n2 = int 2
let n3 = int 3
let n4 = int 4
let n5 = int 5
let n6 = int 6
let p12 = plus n1 n2
let id_x = fun_ "x" (var "x")
let ap_x = app id_x n1
let freeze e = fun_ "_" e
let thaw t = app t (int 0)
let dyn_ap_x = let_ "x" n2 ap_x
let plus_x_y = fun_ "x" (fun_ "y" (plus (var "x") (var "y")))
let plus_1_2 = app (app plus_x_y n1) n2

(* let plus_dyn_err_1_2 = app (app (later plus_x_y) n1) n2 *)
let plus_dyn_err_1_2 = app (app plus_x_y n1) n2

(* let x = 2 in (\x -> \y -> later (x+y)) 1 x *)
let outer_let_x = let_ "x" n2 (app (app plus_x_y n1) (var "x"))
(* let outer_let_x = let_ "x" n2 (app (app (later plus_x_y) n1) (var "x")) *)

let open_x = var "x"
let use_open_x = let_ "x" n1 open_x

(*
   let f = (\x -> \y -> later (x+y)) 1 in
   let x = 2 in
   f x
*)
(* let post_let_x =
   let_ "f" (freeze id_x) (let_ "x" n2 (app (var "f") (var "x"))) *)

(*
  let lib = \x -> \() -> x in lib 0
*)
let get_x_1 = let_ "lib" (let_ "x" n1 (freeze (var "x"))) (thaw (var "lib"))

(*
  let lib = \x -> \() -> x in 
    later let x = 2 in lib 0
*)

let rebind_x_2 =
  let_ "lib" (let_ "x" n1 (freeze (var "x"))) (let_ "x" n2 (thaw (var "lib")))
(* (later (let_ "x" n2 (thaw (var "lib")))) *)
(*

   let lib_host = ... in
     let pkg1_v1_0 = { ... } in
     let lib_foo =
       fun () -> fun x -> pkg_v1_0.foo x
       in
   let user_case1 =
     let pkg1_v1_0 = { ... } in
     dynamic_scope lib_foo (* load above `pkg_v1_0` to shadow lexical-scoped `pkg1_v1_0` *)
     in
   let user_case2 =
     let pkg1_v1_1 = { ... } in
     dynamic_scope_rebind lib_foo (* rebind lexical-scoped `pkg1_v1_0` to `pkg1_v1_1` *)
   in
   ... *)
