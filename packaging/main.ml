open Base

(* smallest concept to make it work *)
module type I = sig
  type exp
  type open_exp
  type value
  type pid
  type pkg
  type version
  type version_exp
  type dep = pid * version_exp
  type deps = dep list
  type dep_answer = pid * version
  type deps_answer = dep_answer list
  type store = Map of (pid * version * pkg)
  type exp_tgt
end

(* Observe
   1. `pid` has a natural shallow embedding in `exp`.
   2. In one `dep`, the `version` for a pid is manually specified externally.
*)

(* Layers of static safety
   Whether a pkg `P1.2` is a subtype of `P1.1` is undecidable, the reason may be outside of the package manage
   and the reason may appear as an oracle.
*)

module type Make_resolve = functor (I : I) -> sig
  open I

  (* perfect resolve *)
  val dep_resolve : deps -> deps_answer

  (* stateful resolve: store can provides _some_ deps answer *)
  val dep_resolve : deps * store -> deps_answer
  val dep_resolve_ : deps * deps_answer -> deps_answer
  val apply_resolve : deps_answer * store -> store

  (* some of the dep are determined by the exp *)
  val must_dep : exp -> deps
end

module type Make_compile = functor (I : I) -> sig
  open I

  (* all-in-one compile *)
  val compile_top : open_exp * deps_answer * store -> exp_tgt

  (* step-by-step compile *)
  val prepare_compile : open_exp * deps_answer * store -> exp
  val compile : exp -> exp_tgt
end

module type Make_interp = functor (I : I) -> sig
  open I

  val interp : open_exp * deps_answer * store -> value
end
