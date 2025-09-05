open Base
open Tola_std

(* module Multi_part : Algebra.S = struct *)
open Ppx_yojson_conv_lib.Yojson_conv

type part = P_int of int | P_str of string [@@deriving yojson]
type t = part list [@@deriving yojson]
type version = t [@@deriving yojson]
type diff = Ordering.t * int (* the first non-equal part and its depth *)

let compose_compare r1 th2 =
  match r1 with
  | Ordering.Less, _ | Ordering.Greater, _ -> r1
  | Equal, _ -> th2 ()

let rec compare_ d p1 p2 =
  match (p1, p2) with
  | [], [] -> (Ordering.Equal, d)
  | P_int i :: p1', P_int i' :: p2' ->
      compose_compare
        (Int.compare i i' |> Std.Ordering.of_int, d)
        (fun () -> compare_ (d + 1) p1' p2')
  | P_str s :: p1', P_str s' :: p2' ->
      compose_compare
        (String.compare s s' |> Std.Ordering.of_int, d)
        (fun () -> compare_ (d + 1) p1' p2')
  | _ -> failwith "mismatch case"

let compare_std p1 p2 = compare_ 0 p1 p2 |> fst
let compare_full p1 p2 = compare_ 0 p1 p2

let equal p1 p2 =
  match compare_full p1 p2 with Ordering.Equal, _ -> true | _ -> false

let of_str s =
  let part_of_string s =
    match Int.of_string_opt s with Some i -> P_int i | None -> P_str s
  in
  List.map ~f:part_of_string (String.split_on_chars ~on:[ '-' ] s)

let to_str t =
  List.map ~f:(function P_int i -> Int.to_string i | P_str s -> s) t
  |> String.concat ~sep:"."
