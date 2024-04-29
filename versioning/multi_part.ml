open Std
(* module Multi_part : Algebra.S = struct *)

type part = P_int of int | P_str of string
type t = part list
type version = t
type diff = Ordering.t * int

let compose_compare r1 th2 =
  match r1 with
  | Ordering.Less, _ | Ordering.Greater, _ -> r1
  | Equal, _ -> th2 ()

let rec compare_ d p1 p2 =
  match (p1, p2) with
  | [], [] -> (Ordering.Equal, d)
  | P_int i :: p1', P_int i' :: p2' ->
      compose_compare
        (Int.compare i i' |> Ordering.of_int, d)
        (fun () -> compare_ (d + 1) p1' p2')
  | P_str s :: p1', P_str s' :: p2' ->
      compose_compare
        (String.compare s s' |> Ordering.of_int, d)
        (fun () -> compare_ (d + 1) p1' p2')
  | _ -> failwith "mismatch case"

let compare_std p1 p2 = compare_ 0 p1 p2 |> fst
let compare p1 p2 = compare_ 0 p1 p2

let of_str s =
  let part_of_string s =
    match int_of_string_opt s with Some i -> P_int i | None -> P_str s
  in
  List.map part_of_string (String.split_on_char '-' s)

let to_str t =
  List.map (function P_int i -> string_of_int i | P_str s -> s) t
  |> String.concat "."
