open Langs.Text.With_string_pkg

let rec interp e =
  match e with
  | Lit s -> s
  | Pid pid -> Langs.Text.Pkgm_marshal.lookup pid
  | Con (e1, e2) -> interp e1 ^ interp e2
