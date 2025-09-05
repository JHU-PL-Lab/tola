[@@@warning "-32"]

open Base
open Interp
open Langs.Lang_record
open Tagless

let i3 = int 3
let i5 = int 5
let i42 = int 42
let e1 = i3
let a = Id.str "a"

(* let b = Id.str "b" *)
let va = v_ "a"
let vb = v_ "b"
let e2 = record (a @-> i3)
let e3 = e2 @. a
let e4 = fun_ "a" (plus va i42)
let e5 = app e4 i3
let e6 = fun_ "a" (fun_ "b" (plus (plus va vb) i42))

(* fun a -> fun b -> a + b + 42 *)
let e7 = app e6 i3

(* (fun a -> fun b -> a + b + 42) 3 *)
let e8 = app e7 i5
(* ((fun a -> fun b -> a + b + 42) 3) 5 *)

let e9 = let_ "a" i42 (app_dyn e7 i5)
(* (a = 42 (fun a -> fun b -> a + b + 42) 3) 5 *)

let () =
  let es = [ e1; e2; e3; e4; e5; e6; e7; e8; e9 ] in
  List.map es ~f:Record_interp.interp
  |> List.iter ~f:(fun v -> Fmt.pr "%a@." pp_exp v);
  ()
