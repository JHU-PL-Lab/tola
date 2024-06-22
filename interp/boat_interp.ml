open Langs
open Lang_boat

let empty_env : exp Std.Id.Map.t = Id.Map.empty

let interp e =
  let rec loop env e =
    match e with
    | Input -> Int 42
    | Int n -> Int n
    | Plus (e1, e2) -> (
        let v1 = loop env e1 in
        let v2 = loop env e2 in
        match (v1, v2) with
        | Int n1, Int n2 -> Int (n1 + n2)
        | Clopen _, _ | _, Clopen _ -> failwith "clopen cannot be int"
        | _ -> Plus (v1, v2))
    | If0 (e1, e2, e3) -> (
        let v1 = loop env e1 in
        match v1 with
        | Int 0 -> loop env e2
        | Int _ -> loop env e3
        | Clopen _ -> failwith "clopen cannot be int"
        | _ -> If0 (v1, e2, e3))
    | Var x -> ( match Id.Map.find_opt x env with Some v -> v | None -> Var x)
    | Fun (x, e) -> Clopen (env, x, e)
    | Let (x, e1, e2) -> (
        let v1 = loop env e1 in
        match v1 with
        | Int _ | Clopen _ -> loop (Id.Map.add x v1 env) e2
        | _ -> Let (x, v1, e2))
    | App (e1, e2) -> (
        let v1 = loop env e1 in
        match v1 with
        | Clopen (env', x, e) -> loop (Id.Map.add x (loop env e2) env') e
        | Int _ -> failwith "clopen cannot be int"
        | _ -> App (v1, e2))
    | Clopen _ -> failwith "clopen cannot be re-evaluated"
  in
  loop empty_env e

let free_vars e =
  let rec loop bvars e =
    match e with
    | Input -> Id.Set.empty
    | Int _n -> Id.Set.empty
    | Plus (e1, e2) -> Id.Set.union (loop bvars e1) (loop bvars e2)
    | If0 (e1, e2, e3) ->
        Id.Set.union
          (Id.Set.union (loop bvars e1) (loop bvars e2))
          (loop bvars e3)
    | Var x -> if Id.Set.mem x bvars then Id.Set.empty else Id.Set.singleton x
    | Fun (x, e) -> loop (Id.Set.add x bvars) e
    | Let (x, e1, e2) ->
        Id.Set.union (loop bvars e1) (loop (Id.Set.add x bvars) e2)
    | App (e1, e2) -> Id.Set.union (loop bvars e1) (loop bvars e2)
    | Clopen (env, x, e) ->
        loop Id.Set.(add x (union bvars (Id.Map.keys env))) e
  in
  loop Id.Set.empty e

let pp = pp_exp
