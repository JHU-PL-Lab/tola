[@@@warning "-38"]

module Id = struct
  type t = string

  let pp = Fmt.string
  let show x = x
end

type e = ..

module Env = struct
  module Ord = struct
    type t = e

    let compare = compare
  end

  module Env_map = Map.Make (Ord)
end

module Exp_var = struct
  type e += Var of Id.t

  let show1 _show e =
    match e with Var s -> Id.show s | _ -> failwith "show var"
end

module Exp_lam = struct
  type e += Lam of Id.t * e

  let show1 show e =
    match e with
    | Lam (x, e) -> "(fun " ^ Id.show x ^ " -> " ^ show e ^ ")"
    | _ -> failwith "show lam"
end

module Exp_app = struct
  type e += App of e * e

  let show1 show e =
    match e with
    | App (e1, e2) -> show e1 ^ " " ^ show e2
    | _ -> failwith "show lam"
end

module Fuse_lambda = struct
  include Exp_var
  include Exp_lam
  include Exp_app

  let rec show e =
    match e with
    | Var _ -> Exp_var.show1 show e
    | Lam (_, _) -> Exp_lam.show1 show e
    | App (_, _) -> Exp_app.show1 show e
    | _ -> failwith "show"
end

open Fuse_lambda

let e = App (Lam ("x", Var "x"), Var "x")

let () =
  Fmt.pr "@.";
  Fmt.pr "%s" @@ show e
