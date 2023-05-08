open Sigs

module Short_id = struct
  type t = X | Y | Z | W

  let show = function X -> "x" | Y -> "y" | Z -> "z" | W -> "w"
  let pp = Fmt.of_to_string show
  let domain = [ X; Y; Z; W ]
end

(* module Short_lang_maker (Id : ID) : LANG = struct *)
module Short_lang_maker (Id : FIN_ID) = struct
  let depth = 3

  type t = Var of Id.t | Lam of (Id.t * t) | App of (t * t)

  let rec pp oc = function
    | Var x -> Id.pp oc x
    | Lam (x, e) -> Fmt.pf oc "(%a -> %a)" Id.pp x pp e
    | App (e1, e2) -> Fmt.pf oc "%a %a" pp e1 pp e2

  let show = Fmt.to_to_string pp
end

module Short_lang = Short_lang_maker (Short_id)

module Examples = struct
  let x = Short_id.X

  open Short_lang

  let e = Var X
end
