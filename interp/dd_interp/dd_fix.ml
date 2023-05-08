open Langs
open Dd
module V = Dd_val.With_closure

module IntSet = Set.Make (struct
  type t = int

  let compare = Int.compare
end)

module Exp_as_key = struct
  type t = exp

  let equal = Dd.equal_exp
  let hash = Hashtbl.hash
end

module Exp_and_env_as_key = struct
  type t = V.env * exp

  let equal (env1, e1) (env2, e2) = equal_exp e1 e2 && V.equal_env env1 env2
  let hash = Hashtbl.hash
end

module Value_as_prop = struct
  type property = V.t

  let bottom = V.Int 0
  let equal = V.equal
  let is_maximal _v = false
end

(*
   module Abs_value_prop = struct
     open Abs_value

     type property = value

     let bottom = AInt Zero
     let equal = Abs_value.equal
     let is_maximal _v = false
   end
*)

module F = Fix.Fix.ForHashedType (Exp_as_key) (Value_as_prop)
