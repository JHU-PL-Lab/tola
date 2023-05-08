open Core

let pp_set pp_val oc =
  let set_iter f set = Set.iter set ~f in
  Fmt.pf oc "{%a}" Fmt.(iter ~sep:(any ",") set_iter pp_val)

let set_of_bool b = Set.singleton (module Bool) b
let just_true = set_of_bool true
let just_false = set_of_bool false
let true_or_false = Set.of_list (module Bool) [ true; false ]
let rec naive_fix step e = step (naive_fix step) e

(* let pp_of_to_string to_string oc = Fmt.using to_string Fmt.string oc *)

(* let pp_set ?(set_name = "set") pp_elem oc s =
   let pp_name oc _ = Fmt.string oc set_name in
   let set_iter f set = Set.iter set ~f in
   (Fmt.Dump.iter set_iter pp_name pp_elem) oc s *)

(*
   let mk_pp_set name pp_val =
      let pp_name oc _ = Fmt.string oc name in
      let set_iter f set = Set.iter set ~f in
      Fmt.Dump.iter set_iter pp_name pp_val *)

(* let mk_pp_set pp_val =
   let set_iter f set = Set.iter set ~f in
   Fmt.(iter ~sep:(any ",") set_iter pp_val) *)
