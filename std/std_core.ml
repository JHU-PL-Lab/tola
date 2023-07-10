open Core

module Printing = struct
  let pp_set pp_val oc =
    let set_iter f set = Set.iter set ~f in
    Fmt.pf oc "{%a}" Fmt.(iter ~sep:(any ",") set_iter pp_val)

  let dump_list s pp = Fmt.pr "@.@[<v>%a@]@;@." (Fmt.list pp) s

  let dump_list domain pp =
    Fmt.(pr "@.%d@.@[<v>%a@]@;@." (List.length domain) (list pp) domain)

  let list_split es =
    let rec loop p1 p2 =
      match p2 with
      | [] -> []
      | e :: es ->
          let p1' = p1 @ [ e ] in
          let p2' = es in
          (p1', p2') :: loop p1' p2'
    in
    ([], es) :: loop [] es

  (* let pp_of_to_string to_string oc = Fmt.using to_string Fmt.string oc *)

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
end

include Printing

module File_util = struct
  open Stdlib

  let write_marshal file v =
    let oc = open_out file in
    Marshal.to_channel oc v [];
    close_out oc

  let read_marshal file =
    let ic = open_in file in
    let v = Marshal.from_channel ic in
    close_in ic;
    v
end

include File_util

module More_bool = struct
  let set_of_bool b = Set.singleton (module Bool) b
  let just_true = set_of_bool true
  let just_false = set_of_bool false
  let true_or_false = Set.of_list (module Bool) [ true; false ]
end

include More_bool

module More_list = struct
  let list_split lst =
    let rec loop part1 part2 =
      match part2 with
      | [] -> []
      | e :: es ->
          let part1' = part1 @ [ e ] in
          let part2' = es in
          (part1', part2') :: loop part1' part2'
    in
    ([], lst) :: loop [] lst
end

include More_list

let rec naive_fix step e = step (naive_fix step) e
