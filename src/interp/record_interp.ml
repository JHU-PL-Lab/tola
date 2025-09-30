open Base
open Langs
open Lang_record
open Tagless

let push_fun env x e =
  Record
    (Binds
       {
         key = Id.str "fvar";
         value = Var x;
         next = Eager (Binds { key = Id.str "fbody"; value = e; next = env });
       })

let pop_fun bds =
  match bds with
  | Binds
      {
        key = fvar;
        value = Var x;
        next = Eager (Binds { key = fbody; value = e; next });
      }
    when Id.equal fvar (Id.str "fvar") && Id.equal fbody (Id.str "fbody") ->
      (next, x, e)
  | _ -> failwith "pop_fun: not a fun-record"

let rec loop_bindings f env bds =
  match bds with
  | Empty -> Empty
  | Binds { key; value = exp; next } ->
      let v = f env exp in
      let next' =
        match next with
        | Deferred_key k -> Deferred_key k
        | Deferred_name n -> Deferred_name n
        | Eager bds' -> Eager (loop_bindings f env bds')
      in
      Binds { key; value = v; next = next' }

let rec loop env e =
  (* Fmt.pr "Evaluating %a@." pp_exp e; *)
  match e with
  | Input -> Int 42
  | Int n -> Int n
  | Plus (e1, e2) -> (
      let v1 = loop env e1 in
      let v2 = loop env e2 in
      match (v1, v2) with Int n1, Int n2 -> Int (n1 + n2) | _ -> Plus (v1, v2))
  | If0 (e1, e2, e3) -> (
      let v1 = loop env e1 in
      match v1 with
      | Int 0 -> loop env e2
      | Int _ -> loop env e3
      | _ -> If0 (v1, e2, e3))
  | Var x -> lookup_exn env x
  | Fun (x, e) -> push_fun (Eager env) x e
  | Let (x, e1, e2) -> (
      let v1 = loop env e1 in
      match v1 with Int _ -> loop (bcons x v1 env) e2 | _ -> Let (x, v1, e2))
  | App (e1, e2) -> (
      match loop env e1 with
      | Record bds ->
          let v2 = loop env e2 in
          let fenv_raw, fvar, fbody = pop_fun bds in
          let fenv = value_bds_exn fenv_raw in
          let env' = bcons fvar v2 fenv in
          loop env' fbody
      | _ -> failwith "Not a fun-record to apply")
  | App_dyn (e1, e2) -> (
      match loop env e1 with
      | Record bds ->
          let v2 = loop env e2 in
          let fenv_raw, fvar, fbody = pop_fun bds in
          let fenv = bconcat env (value_bds_exn fenv_raw) in
          let env' = bcons fvar v2 fenv in
          loop env' fbody
      | _ -> failwith "Not a fun-record to apply")
  | Record bds -> Record (loop_bindings loop env bds)
  | Project { record; field } -> (
      let v = loop env record in
      match v with
      | Record bds -> lookup_exn bds field
      | _ -> failwith "No such field")
  | Rcons (k, ev, er) -> (
      let v = loop env ev in
      let r = loop env er in
      match r with
      | Record bds -> Record (bcons k v bds)
      | _ -> failwith "Rcons: not a record")

let interp e = loop Empty e
