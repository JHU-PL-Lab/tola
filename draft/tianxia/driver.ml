module type Parsed_tree = sig
  type t

  val one : t
end

module type Ast = sig
  type t
end

module type IR = sig
  type t
end

module type Flow = sig
  type l1_exp
  type l2_exp

  val flow : l1_exp -> l2_exp
end

module type Static_analysis = sig
  type exp
  type state
  type result

  val analyze : exp -> result
  val analyze_with_state : state -> exp -> result
end

module type State = sig
  (* mutable and reentrant *)
  type t
end

module type Config = sig
  (* immutable *)
  type t
end

module type Commandline = sig
  type config

  val arg_parse : unit -> config
end

module type Testable = sig
  type config
  type exp
  type expect

  val testcase : config -> expect -> exp -> bool
end

module type Interp = sig
  type exp
  type val_

  val interp : exp -> val_
end

module type Driver = sig end

let () = ()
