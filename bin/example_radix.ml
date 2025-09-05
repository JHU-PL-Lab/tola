open Versioning.Algebra

(*
   let t0 = Multi_part.root
   let t1 = t0 |> Multi_part.add_next 1 "1" |> Multi_part.add_next 2 "2"
   let () = Fmt.pr "%a" Multi_part.pp t1 *)
open Naive_radix

let t0 = Naive_radix.root

let t1 =
  t0 |> Naive_radix.add_to_layer (K_int 1) |> Naive_radix.add_to_layer (K_int 2)

let t2 =
  t0
  |> Naive_radix.add_to_layer (K_string "a")
  |> Naive_radix.add_to_layer (K_string "b")

let t3 = Naive_radix.subst [ K_int 1 ] t1 t2
let dump t = Fmt.pr "%a@." Naive_radix.pp t

let () =
  dump t1;
  dump t2;
  dump t3

let v1 = Versioning.Multi_part.of_str "1-2-a-3"
let () = Fmt.pr "%s" (Versioning.Multi_part.to_str v1)
