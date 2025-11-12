open Tola_std

(* Filesystem 
If we treat file system as a map from paths to files. It's clear that paths theirselves
form a structure. Normally, we treat it as pure string or thin wrapper over strings. However,
we can treat it more seriously and more formally. The key observation is _relative paths_ are
open variables. Since they are open, the interpretation is dynamic scoped.

Path forms a compositional namespace. There is one composition operation: join `/` 
and these operation are associative. The list is given by GPT on this topic.

# References on formal and algebraic models of filesystem paths

- **Ken McMillan et al.**  
  *Formalizing a Hierarchical File System.*  
  ResearchGate, 2014.  
  https://www.researchgate.net/publication/268761573_Formalizing_a_Hierarchical_File_System

- **R. Chen et al.**  
  *A Formally Proved, Complete Algorithm for Path Resolution with Symbolic Links.*  
  Journal of Formalized Reasoning, University of Bologna.  
  https://jfr.unibo.it/article/view/6767/7213

- **M. Sivathanu et al.**  
  *A Logic of File Systems.*  
  USENIX FAST 2005.  
  https://www.usenix.org/event/fast05/tech/full_papers/sivathanu_logic/sivathanu_logic.pdf

- **Zhixuan Yang.**  
  *Modular Models of Monoids with Operations.*  
  2021.  
  https://yangzhixuan.github.io/pdf/mmm.pdf
*)

module type Private_string = sig
  type t = private string

  val s : t -> string
  val v : string -> t
  val pp : Format.formatter -> t -> unit
end

module type REL = sig
  include Private_string
end

module type ABS = sig
  include Private_string

  type rel

  val from_rel : root:string -> rel -> t
end

(* Path as a namespace of keys *)
module Relative : REL = struct
  type t = string

  let v s = s
  let s p = p
  let pp fmt p = Fmt.pf fmt "%s" p
end

module Rel = Relative

module Absolute : ABS = struct
  type t = string
  type rel = Relative.t

  let v s = s
  let s p = p
  let pp fmt p = Fmt.pf fmt "%s" p
  let from_rel ~root p_rel = v (root $/ Relative.s p_rel)
end

module Abs = Absolute
