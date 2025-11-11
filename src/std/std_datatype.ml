open! Core
module Ordering = Core.Ordering

module Naive_binding = struct
  module Variable = struct
    type name = string
    type value = string
  end

  open Variable

  type binding = name * value
  type bindings = binding list

  let array_of_bindings (bds : bindings) : string array =
    Array.of_list @@ List.map ~f:(fun (k, v) -> Printf.sprintf "%s=%s" k v) bds

  let dump_bindings (bds : bindings) : unit =
    Stdio.printf "[Binding]:\n";
    List.iter ~f:(fun (k, v) -> Stdio.printf "  %s = %s\n" k v) bds

  let string_of_bindings (bds : bindings) : string =
    List.map ~f:(fun (k, v) -> Printf.sprintf "%s=%s" k v) bds
    |> String.concat ~sep:" "
end

let list_sum = List.sum (module Int) ~f:Fn.id

module PartialOrdering = struct
  type t = Less | Equal | Greater | Unknown
end

let compose_compare r1 th2 =
  match r1 with Less | Greater -> r1 | Equal -> th2 ()

module BoolSet = struct
  (*
  type ternary = True | False | Unknown
  [@@deriving equal, show { with_path = false }]
     let bool_of_ternary_exn = function
       | True -> true
       | False -> false
       | Unknown -> failwith "ternary unknown"
  
     let bool_of_ternary = function
       | True -> Some true
       | False -> Some false
       | Unknown -> None
  
     let t_and tb1 tb2 =
       match (tb1, tb2) with
       | False, _ | _, False -> False
       | True, True -> True
       | _, _ -> Unknown
  
     let t_or tb1 tb2 =
       match (tb1, tb2) with
       | True, _ | _, True -> True
       | False, False -> False
       | _, _ -> Unknown
  *)

  let set_of_bool b = Set.singleton (module Bool) b
  let just_true = set_of_bool true
  let just_false = set_of_bool false
  let true_or_false = Set.of_list (module Bool) [ true; false ]
end

(* let list_split lst =
    let rec loop part1 part2 =
      match part2 with
      | [] -> []
      | e :: es ->
          let part1' = part1 @ [ e ] in
          let part2' = es in
          (part1', part2') :: loop part1' part2'
    in
    ([], lst) :: loop [] lst *)
