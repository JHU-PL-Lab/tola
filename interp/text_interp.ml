open Langs.Lang_text.Plain

let rec interp e =
  match e with Lit s -> s | Con (e1, e2) -> interp e1 ^ interp e2
