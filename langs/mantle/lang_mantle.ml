module Naive_binding = struct
  module Variable = struct
    type name = string
    type value = string
  end

  open Variable

  type binding = name * value
  type bindings = binding list

  let array_of_bindings (bds : bindings) : string array =
    Array.of_list @@ List.map (fun (k, v) -> Printf.sprintf "%s=%s" k v) bds

  let dump_bindings (bds : bindings) : unit =
    Printf.printf "[Binding]:\n";
    List.iter (fun (k, v) -> Printf.printf "  %s = %s\n" k v) bds

  let string_of_bindings (bds : bindings) : string =
    List.map (fun (k, v) -> Printf.sprintf "%s=%s" k v) bds |> String.concat " "
end

module Variable = struct
  type name = string
  type value = string
  type namevalue = name * value
  type namevalue_list = (name * value) list

  let dump_namevalue_list (nv_list : namevalue_list) : unit =
    Printf.printf "[NameValue]:\n";
    List.iter (fun (k, v) -> Printf.printf "  %s = %s\n" k v) nv_list
end

include Variable

module Two_scoped_binding = struct
  type scoping = Controlled | Exported
  type binding = { name : name; value : value; scoping : scoping }
  type bindings = binding list

  let get (name : name) (bds : bindings) : binding option =
    List.find_opt (fun bd -> String.equal name bd.name) bds

  let set name value scoping (bds : bindings) : bindings =
    match get name bds with
    | Some _ ->
        List.map
          (fun bd ->
            if String.equal name bd.name then { bd with value } else bd)
          bds
    | None -> { name; value; scoping } :: bds

  let binding_controlled name value = { name; value; scoping = Controlled }
  let binding_exported name value = { name; value; scoping = Exported }
  let is_exported (bd : binding) = bd.scoping = Exported

  let is_visible exported_only (bd : binding) =
    (* every var is is_visible unless this option is set *)
    (not exported_only)
    ||
    (* when this option is set, only exported is visible *)
    is_exported bd

  let from_namevalue_list (nvs : namevalue_list) scoping : bindings =
    List.map (fun (name, value) -> { name; value; scoping }) nvs

  let filter_visible exported_only (bds : bindings) : bindings =
    List.filter (is_visible exported_only) bds

  let array_of_variables ?(exported_only = false) (bds : bindings) :
      string array =
    bds
    |> filter_visible exported_only
    |> List.map (fun bd -> Printf.sprintf "%s=%s" bd.name bd.value)
    |> Array.of_list

  let string_of_bindings ?(exported_only = false) (bds : bindings) : string =
    bds
    |> filter_visible exported_only
    |> List.map (fun bd -> Printf.sprintf "%s=%s" bd.name bd.value)
    |> String.concat " "

  let dump_bindings (bds : bindings) : unit =
    Printf.printf "[Binding]:\n";
    List.iter
      (fun bd ->
        Printf.printf "  %s = %s %s\n" bd.name bd.value
          (match bd.scoping with Controlled -> "" | Exported -> "E"))
      bds
end

type external_cmd = string

(* Inherit is the normal lexical scoping
    Custom is like the dynamic scoping but with an explicit rebinding
  *)
type binding_option = Inherit | Custom of namevalue_list

(* The language seems a subset of a full lambda calculus as there is no lambda abstraction 
  a.k.a making a reusable function.
  It's like `App (Fun, ())`, a first-order

  letfun f1 = ... in
  f1 () ...

  *)
type exp =
  (* Value *)
  | Unit
  | Str of string
  (* Directive - Variable *)
  | Set of namevalue
  | Get of name
  | Export of namevalue
  (* Directive - Run *)
  | RunExp of binding_option * exp
  | RunProcess of binding_option * external_cmd
  (* Structure *)
  | ExpList of exp list

let str_of_exp = function Unit -> "()" | Str s -> s | _ -> ""
