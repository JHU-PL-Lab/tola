open Base
(* Name resolution
   Double resolution, or the same times as the stages.

   Design space for resolution
   A is B.
   A_name is a B_resource.
   A binds to B.

   Def A is B
   Use A is to find B and use B.

   Both A and B are symbols so they need a concrete site (world) to instantiate.

   Given a world,
   Def A is B
   Find B
   Replace A to B
   Ship B to the new world

   Given a world,
   Def A is B
   Find B
   Record A is B
   Ship (A is B) to the new world

   Given a world,
   Def A is B
*)

(*
   The current lang is only specifying how to resolve binding, a.k.a.
   either from the lexical scope variable or from the dynamic scope variable.

   The current lang uses freeze-later-thaw pattern to wrap an open term. Can I just use a contagious open term.

   However, now we need an open term with no binding.

   The point is we need a straightforward way to present open terms and also make the reduction consistent. If we know a term is open, we don't need to rebind it because it has no binding at all.
   We can also simplify the env concatenating steps since everything is standard. We just cannot resolve a open variable. We also shouldn't do that.

   Another point is the term is not totally open. It's open but bounded. It means we cannot provide arbitrary open terms. It can be either defined at the lang level or at the interpreter level. The checking for valid open terms can be post-stage. It means we just need a simple lambda calculus that respect open terms, and a standlone separate step to check open variables.
*)

(* not unsed
        (* string *)
        | Str of string
        | Cat of exp * exp
   | Sad of Id.t * exp
        | Bind_later of exp
      | Bind_now of exp


     let str s = Str s
     let cat e1 e2 = Cat (e1, e2)

     let later e = Bind_later e
     let now e = Bind_now e
*)

(* 
OB1: records is a named group of let-clauses

A environment is a list/collection of bindings.
Interpreter keeps a dynamic environment every step, that aligns with the call stacks
Lexical-scoped environment points to one dynamic environment.

When evaluating a function, the bindings used in the function body is the lexical-scoped environment. However, the bindings doesn't need to be resolved immediately.

We now need a design to represent progress of the binding-resolving process, which should be controlled from both the caller and the callee sides,
which means the variable and the place.

 *)

module Id = Tola_std.Std.Id

(* If we need to make a _value_ for this language
   only `Int` and `Record` are normal values.

   The rest can be open terms except for `Input` and `Fun`.
*)

(* 
let x = 1 in
let x = y in

let* {
   x = 1;
   y = x;
}

- map and map concat
- resolve eager and lazy
- binding immutable or rebond
- open and closed
- (one and multiple-staged)

*)

type ('k, 'n, 'v) bindings =
  | Empty
  | Binds of {
      (* this pair *)
      key : 'k;
      value : 'v;
      (* bind_kind : bind_kind; *)
      (* next pair *)
      next : ('k, 'n, 'v) next;
    }

(*and bind_kind = 
   { is_recursive : bool } *)
and ('k, 'n, 'v) next =
  | Deferred_key of 'k
  | Deferred_name of 'n
  | Eager of ('k, 'n, 'v) bindings
[@@deriving equal, show { with_path = false }]

let rec lookup bds key =
  match bds with
  | Empty -> None
  | Binds { key = k; value = v; next; _ } -> (
      if Id.equal key k then Some v
      else
        match next with
        | Deferred_key _k' -> None
        | Deferred_name _n -> None
        | Eager next_bds -> lookup next_bds key)

let lookup_exn bds key = Option.value_exn (lookup bds key)

let lookup_last bds key =
  let rec loop bds acc key =
    match bds with
    | Empty -> None
    | Binds { key = k; value = v; next; _ } -> (
        let acc' = if Id.equal key k then Some v else acc in
        match next with
        | Deferred_key _k' -> acc'
        | Deferred_name _n -> acc'
        | Eager next_bds -> loop next_bds acc' key)
  in
  loop bds None key

type exp =
  | Input
  | Int of int
  | Plus of exp * exp
  | If0 of exp * exp * exp
  | Var of Id.t
  | Fun of Id.t * exp
  | Let of Id.t * exp * exp
  | App of exp * exp
  | App_dyn of exp * exp
  (* Ten thousands faces of records *)
  | Record of (Id.t, unit, exp) bindings
  | Project of { record : exp; field : Id.t }
  | Rcons of Id.t * exp * exp
(* and env = (Id.t, unit, exp) bindings *)
[@@deriving equal, show { with_path = false }]

module Tagless = struct
  let input = Input
  let int n = Int n
  let plus e1 e2 = Plus (e1, e2)
  let if0 e1 e2 e3 = If0 (e1, e2, e3)
  let var x = Var (Id x)
  let v_ = var
  let fun_ x e = Fun (Id x, e)
  let let_ x e1 e2 = Let (Id x, e1, e2)
  let app e1 e2 = App (e1, e2)
  let app_dyn e1 e2 = App_dyn (e1, e2)
  let ( @. ) record field = Project { record; field }

  let of_list bindings =
    let rec loop acc = function
      | [] -> acc
      | (k, v) :: rest ->
          let next =
            match acc with Empty -> Deferred_key k | Binds { next; _ } -> next
          in
          loop (Binds { key = k; value = v; next }) rest
    in
    loop Empty bindings

  let node k v = Binds { key = k; value = v; next = Eager Empty }
  let ( @-> ) k v = node k v
  let bcons k v bds = Binds { key = k; value = v; next = Eager bds }

  let rec bconcat bds1 bds2 =
    match bds1 with
    | Empty -> bds2
    | Binds { key; value; next = Eager bds1' } ->
        Binds { key; value; next = Eager (bconcat bds1' bds2) }
    | _ -> failwith "bconcat: not an eager bindings"

  let record bds = Record bds
end

let id_of_var = function Var x -> x | _ -> failwith "Not a variable"

let value_bds_exn = function
  | Eager bds -> bds
  | _ -> failwith "Not an eager bindings"
