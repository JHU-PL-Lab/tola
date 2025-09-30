open Langs
open Dd

module With_closure = struct
  type t = Int of int | Closure of env * Id.t * exp
  and env = (Id.t * (t * call_stack)) list [@@deriving eq, ord]

  let rec pp oc = function
    | Int i -> Fmt.int oc i
    | Closure (env, x, e) ->
        Fmt.pf oc "(clo %a -> %a) @@ %a." Id.pp x pp_exp e pp_env env

  and pp_env oc =
    Fmt.(brackets (list ~sep:sp (pair ~sep:(any "=") Id.pp (pair pp nop)))) oc

  let show = Fmt.to_to_string pp

  let pp_compact oc = function
    | Int i -> Fmt.int oc i
    | Closure (_env, x, _e) -> Fmt.pf oc "(fun %a -> ...)" Id.pp x

  let binop_ints op e1 e2 =
    match (e1, e2) with
    | Int i1, Int i2 -> Int (op i1 i2)
    | _ -> failwith "must be on ints"

  let cond_int cond e =
    match e with Int i -> cond i | _ -> failwith "must be on int"
end

module With_callstack = struct
  type t = Int of int | Fun_with_cs of (Id.t * exp * call_stack)
  [@@deriving eq, ord]

  let pp oc = function
    | Int i -> Fmt.int oc i
    | Fun_with_cs (x, e, cs) ->
        Fmt.pf oc "(Fun %a -> %a) @@ %a." Id.pp x pp_exp e pp_cs cs

  let pp_compact oc = function
    | Int i -> Fmt.int oc i
    | Fun_with_cs (x, _, _) -> Fmt.pf oc "(fun %a ...)" Id.pp x

  let binop_ints op e1 e2 =
    match (e1, e2) with
    | Int i1, Int i2 -> Int (op i1 i2)
    | _ -> failwith "must be on ints"

  let cond_int cond e =
    match e with Int i -> cond i | _ -> failwith "must be on int"
end
