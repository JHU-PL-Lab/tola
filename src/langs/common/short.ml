open Base
open Sigs
open Tola_std

module Short_id_fake = struct
  type t = X | Y | Z | W [@@deriving equal, ord]

  let show = function X -> "x" | Y -> "y" | Z -> "z" | W -> "w"
  let pp = Fmt.of_to_string show
  let domain = [ X; Y; Z; W ]
  let dump_domain () = Std.dump_list domain pp
end

module De_bruijin_id_maker (N : N) = struct
  type t = int [@@deriving equal, ord]

  let size = N.n
  let nth i = i

  let show = function
    | 0 -> "x"
    | 1 -> "y"
    | 2 -> "z"
    | 3 -> "w"
    | n -> "a" ^ Int.to_string (n - 4)

  let pp = Fmt.of_to_string show
  let domain = List.init ~f:(fun i -> i) N.n
  let dump_domain () = Tola_std.Std.dump_list domain pp
  let x = 0
end

module Short_lang_maker (N : N) (Id : FIN_ID) = struct
  let max_depth = N.n

  type t = Var of Id.t | Lam of (Id.t * t) | App of (t * t)
  [@@deriving equal, ord]

  let rec pp oc = function
    | Var x -> Id.pp oc x
    | Lam (x, e) -> Fmt.pf oc "(\\%a. %a)" Id.pp x pp e
    | App (e1, e2) -> Fmt.pf oc "(%a %a)" pp e1 pp e2

  let show = Fmt.to_to_string pp

  let rec fold_post ~bin ~id = function
    | Var x -> id x
    | Lam (x, e) -> bin (id x) (fold_post ~bin ~id e)
    | App (e1, e2) -> bin (fold_post ~bin ~id e1) (fold_post ~bin ~id e2)

  let depth e =
    let id _ = 1 in
    let bin v1 v2 = max v1 v2 + 1 in
    fold_post ~id ~bin e

  let size = 0

  module TriInt = struct
    module T = struct
      type t = int * int * int [@@deriving equal, compare, sexp, hash]
    end

    include T
    include Comparator.Make (T)
  end

  let domain =
    let table =
      Hashtbl.create ~size:(max_depth * Id.size * Id.size) (module TriInt)
    in

    (* let free_vs bv c = List.init (c - bv) (fun i -> i + bv) in *)
    let range a b = List.init ~f:(fun i -> i + a) (b - a) in
    let bound_vs bv = List.init ~f:(fun i -> i) bv in

    let bound_vs' bv = bound_vs bv |> List.map ~f:(fun i -> Var (Id.nth i)) in

    let join e1s e2s =
      List.concat_map
        ~f:(fun e1 -> List.map ~f:(fun e2 -> App (e1, e2)) e2s)
        e1s
      (* Seq.map_product
        (fun e1 e2 -> App (e1, e2))
        (List.to_seq e1s) (List.to_seq e2s)
      |> List.of_seq *)
    in

    (* use better memoization *)
    let rec g d bv c =
      match Hashtbl.find table (d, bv, c) with
      | Some es -> es
      | None ->
          let es =
            if d <= 1 then bound_vs' bv
            else
              (* case lam, height (d-1) *)
              let lams =
                if bv < c then
                  let lam_body = g (d - 1) (bv + 1) c in
                  List.map ~f:(fun e -> Lam (Id.nth bv, e)) lam_body
                else []
              in
              (* case app, one of e1 or e2 is height (d-1) *)
              let apps =
                let e' = g (d - 1) bv c in
                let e1_d_1 =
                  range 1 d
                  |> List.concat_map ~f:(fun d' ->
                         let e2s = g d' bv c in
                         join e' e2s)
                in
                let e2_d_1 =
                  range 1 (d - 1)
                  |> List.concat_map ~f:(fun d' ->
                         let e1s = g d' bv c in
                         join e1s e')
                in
                e1_d_1 @ e2_d_1
              in

              lams @ apps
          in
          Hashtbl.add_exn ~key:(d, bv, c) ~data:es table;
          es
    in

    g max_depth 0 Id.size

  let dump_domain () = Tola_std.Std.dump_list domain pp
end

module Short_id = De_bruijin_id_maker (struct
  let n = 10
end)

module Short_lang =
  Short_lang_maker
    (struct
      let n = 3
    end)
    (Short_id)

module Examples = struct
  let x = Short_id.x

  open Short_lang

  let e = Var x
end
