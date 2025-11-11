open! Core

let pp_b = Fmt.(using (function true -> "t" | false -> "f") string)
let pp_bo = Fmt.(using (function true -> "#t" | false -> "#f") string)

let pp_set pp_val oc =
  let set_iter f set = Set.iter set ~f in
  Fmt.pf oc "{%a}" Fmt.(iter ~sep:(any ",") set_iter pp_val)

let dump_list s pp = Fmt.pr "@.@[<v>%a@]@;@." (Fmt.list pp) s

let dump_list domain pp =
  Fmt.(pr "@.%d@.@[<v>%a@]@;@." (List.length domain) (list pp) domain)

(* let pp_set ?(name = "set") pp_elem oc s =
     let pp_name oc _ = Fmt.string oc name in
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

let pp_tuple3 pp_a pp_b pp_c oc (a, b, c) =
  Fmt.pf oc "(%a, %a, %a)" pp_a a pp_b b pp_c c

let string_of_opt_int_list ?(none = "-") inputs =
  String.concat ~sep:","
  @@ List.map ~f:(function Some i -> Int.to_string i | None -> none) inputs

let iter_core_set f set = Set.iter set ~f

let iteri_core_map f map =
  let core_f ~key ~data = f key data in
  Core.Map.iteri map ~f:core_f

let iteri_core_hashtbl f map =
  let core_f ~key ~data = f key data in
  Core.Hashtbl.iteri map ~f:core_f
