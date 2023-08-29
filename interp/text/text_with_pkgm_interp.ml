open Langs.Text.With_string_pkg
open Langs.Naive_pkgm

let rec interp e =
  match e with
  | Lit s -> s
  | Pid pid -> Pkgm_persisted.lookup pid
  | Con (e1, e2) -> interp e1 ^ interp e2
