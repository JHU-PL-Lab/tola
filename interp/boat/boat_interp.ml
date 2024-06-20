open Langs
open Lang_boat

type lexical_or_dynamic = Lexical_scope | Dynamic_scope

let is_lexical = function Lexical_scope -> true | _ -> false

module Boat_val = struct
  type value =
    | Int of int
    | Str of string
    | Opening of { env : env_forest; arg : Id.t; body : exp }

  and value_set = Id.Set.t
  and env_block = value Id.Map.t

  and env_forest =
    | One_env of env_block
    | Cons_env of { lexical : env_forest; dynamic : env_block }

  and t = value [@@deriving eq]
end

let empty_env_block : Boat_val.env_block = Id.Map.empty
let empty_env : Boat_val.env_forest = One_env empty_env_block
(* { lexcical_env = empty_env_block; dynamic_env = empty_env_block } *)

let local_env_of_env (env : Boat_val.env_forest) =
  match env with One_env env -> env | Cons_env { dynamic; _ } -> dynamic

let add_local_binding x v (env : Boat_val.env_forest) : Boat_val.env_forest =
  match env with
  | One_env env -> One_env (Id.Map.add x v env)
  | Cons_env { lexical; dynamic } ->
      Cons_env { lexical; dynamic = Id.Map.add x v dynamic }

let merge_env scope x v (env : Boat_val.env_forest)
    (local_env : Boat_val.env_forest) : Boat_val.env_forest =
  match scope with
  | Lexical_scope -> add_local_binding x v env
  | Dynamic_scope ->
      Cons_env
        { lexical = env; dynamic = Id.Map.add x v (local_env_of_env local_env) }

(* if to_lexical then { env with lexcical_env = Id.Map.add x v env.lexcical_env }
   else { env with dynamic_env = Id.Map.add x v env.dynamic_env } *)

let rec find_binding _from_lexical x (env : Boat_val.env_forest) =
  match env with
  | One_env env -> Id.Map.find x env
  | Cons_env { lexical; dynamic } -> (
      (* if is_lexical from_lexical then find_binding Dynamic_scope x lexical
         else *)
      match Id.Map.find_opt x dynamic with
      | Some v -> v
      | None -> find_binding Dynamic_scope x lexical)

(* let forest_of_env  *)

let pp oc = function
  | Boat_val.Int i -> Fmt.int oc i
  | _ -> Fmt.string oc "not yet"

let interp e =
  let from_lexical = ref Lexical_scope in
  let rec loop env e =
    match e with
    | Input -> Boat_val.Int 42
    | Int n -> Boat_val.Int n
    | Plus (e1, e2) -> (
        let v1 = loop env e1 in
        let v2 = loop env e2 in
        match (v1, v2) with
        | Boat_val.Int n1, Boat_val.Int n2 -> Boat_val.Int (n1 + n2)
        | _ -> failwith "not ints")
    | Str s -> Boat_val.Str s
    | Cat (e1, e2) -> (
        let v1 = loop env e1 in
        let v2 = loop env e2 in
        match (v1, v2) with
        | Boat_val.Str n1, Boat_val.Str n2 -> Boat_val.Str (n1 ^ n2)
        | _ -> failwith "not strings")
    | If0 (e0, e1, e2) -> (
        match loop env e0 with
        | Boat_val.Int 0 -> loop env e1
        | Boat_val.Int _ -> loop env e2
        | _ -> failwith "not ints")
    | Var x -> find_binding !from_lexical x env
    | Fun (arg, body) -> Opening { env; arg; body }
    (* | Sad (arg, body) -> Opening { env; arg; body } *)
    | Let (x, e1, e2) ->
        let v1 = loop env e1 in
        let env' = add_local_binding x v1 env in
        loop env' e2
    | App (e1, e2) -> (
        let v1 = loop env e1 in
        match v1 with
        | Boat_val.Opening ope ->
            let v2 = loop env e2 in
            let env' = merge_env !from_lexical ope.arg v2 ope.env env in
            loop env' ope.body
        | _ -> failwith "not opening")
    | Bind_now e ->
        from_lexical := Lexical_scope;
        loop env e
    | Bind_later e ->
        from_lexical := Dynamic_scope;
        loop env e
  in
  loop empty_env e
