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

module Id = Std.Id

(* If we need to make a _value_ for this language
   only `Int` and `Clopen` are normal values.

   The rest can be open terms except for `Input` and `Fun`.
*)

type exp =
  | Input
  | Int of int
  | Plus of exp * exp
  | If0 of exp * exp * exp
  | Var of Id.t
  | Fun of Id.t * exp
  | Let of Id.t * exp * exp
  | App of exp * exp
  | Clopen of env * Id.t * exp

and env = exp Id.Map.t [@@deriving eq, show { with_path = false }]

module Tagless = struct
  let input = Input
  let int n = Int n
  let plus e1 e2 = Plus (e1, e2)
  let if0 e1 e2 e3 = If0 (e1, e2, e3)
  let var x = Var (Id x)
  let fun_ x e = Fun (Id x, e)
  let let_ x e1 e2 = Let (Id x, e1, e2)
  let app e1 e2 = App (e1, e2)
end
