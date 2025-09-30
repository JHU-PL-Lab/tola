open Langs
open Dd

type node = {
  mutable succs : node list;
  mutable prev : node;
  x : Id.t;
  e : exp;
}

type t = { root : node }
