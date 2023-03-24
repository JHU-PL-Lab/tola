[@@@warning "-38"]

module Id = struct
  type t = string

  let pp = Fmt.string
end

type e = ..

module Fuse_lambda = struct
  type e += Var of Id.t | Lam of Id.t * e | App of e * e

  let var_ x = Var x
  let lam x e = Lam (x, e)
  let app e1 e2 = App (e1, e2)

  let show = function
    | Var _ -> "var"
    | Lam _ -> "lam"
    | App _ -> "app"
    | _ -> "_ in Fuse_lambda"

  let rec pp oc = function
    | Var x -> Fmt.string oc x
    | Lam (x, e) -> Fmt.pf oc "(%a -> %a)" Id.pp x pp e
    | App (e1, e2) -> Fmt.pf oc "%a %a" pp e1 pp e2
    | _ -> ()
end

module Fuse_int = struct
  type e += Int of int | Plus of e * e

  let int i = Int i
  let plus e1 e2 = Plus (e1, e2)

  let rec pp oc = function
    | Int x -> Fmt.int oc x
    | Plus (e1, e2) -> Fmt.pf oc "%a + %a" pp e1 pp e2
    | _ -> ()
end

module Fuse_lambda_and_int = struct
  include Fuse_lambda
  include Fuse_int

  (* let pp oc = function _ -> Fmt.string oc "interesting" *)
end

let e1 =
  let open Fuse_lambda in
  let x = var_ "x" in
  let same_x = lam "x" x in
  app same_x x

let e2 =
  let open Fuse_int in
  let i3 = int 3 in
  let i4 = int 4 in
  plus i3 i4

let e3 =
  let open Fuse_lambda_and_int in
  let x = var_ "x" in
  let plus_x_x = plus x x in
  let double = lam "x" plus_x_x in
  app double x

let () =
  Fmt.pr "@.";
  Fmt.pr "%a@." Fuse_lambda.pp e1

let () = Fmt.pr "%a@." Fuse_int.pp e2
let () = Fmt.pr "%a@." Fuse_lambda_and_int.pp e3

(* TODO: solve this by effects? *)
