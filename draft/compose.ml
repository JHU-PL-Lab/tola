module Id = struct
  type t = string
end

module Lambda = struct
  type e = Var of Id.t | Lam of Id.t * e | App of e * e

  let lem x e = Lam (x, e)
  let app e1 e2 = App (e1, e2)
end

module Int = struct
  type e = Int of int | Plus of e * e

  let int n = Int n
  let plus e1 e2 = Plus (e1, e2)
end

module Bool = struct
  type e = Bool of bool | And of e * e | Or of e * e | Not of e

  let bool b = Bool b
  let and_ e1 e2 = And (e1, e2)
  let or_ e1 e2 = Or (e1, e2)
  let not_ e = Not e
end

let () = ()
