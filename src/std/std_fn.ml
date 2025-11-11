open! Core

let rec naive_fix step e = step (naive_fix step) e
let fn_lift2 f fl a b = f (fl a) (fl b)
let nop _ = ()
let nop2 _ _ = ()
let yes _ = true
let no _ = false

(* let chain_compare f1 f2 =
       let r1 = f1 () in
       if r1 = 0 then f2 () else r1

     let just_side_effect = ignore

     let ignore2 _ _ = () *)
