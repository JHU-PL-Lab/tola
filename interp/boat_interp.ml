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
        | _ -> Plus (v1, v2))
    | _ -> Int 42
  in
  loop empty_env e

let pp = pp_exp
