open Sigs

module Short_id = struct
  type t = X | Y | Z | W [@@deriving eq, ord]

  let show = function X -> "x" | Y -> "y" | Z -> "z" | W -> "w"
  let pp = Fmt.of_to_string show
  let domain = [ X; Y; Z; W ]
  let dump_domain () = Std.dump_list domain pp
end

module De_bruijin_id_maker (N : N) = struct
  type t = int [@@deriving eq, ord]

  let show = function
    | 0 -> "x"
    | 1 -> "y"
    | 2 -> "z"
    | 3 -> "w"
    | n -> "a" ^ string_of_int n

  let pp = Fmt.of_to_string show
  let domain = List.init N.n (fun i -> i)
  let dump_domain () = Std.dump_list domain pp
  let x = 1
end

(* module Short_lang_maker (Id : ID) : LANG = struct *)
module Short_lang_maker (Id : FIN_ID) = struct
  let max_depth = 4

  type t = Var of Id.t | Lam of (Id.t * t) | App of (t * t)
  [@@deriving eq, ord]

  let rec pp oc = function
    | Var x -> Id.pp oc x
    | Lam (x, e) -> Fmt.pf oc "(%a -> %a)" Id.pp x pp e
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

  let gen () =
    let rec loop d fvs bvs : t list =
      let group_var = List.map (fun x -> Var x) bvs in
      if d <= 1 then group_var
      else
        let group_lam : t list =
          if List.length fvs > 0 then
            let bv = List.hd fvs in
            let f_bodies = loop (d - 1) (List.tl fvs) (bvs @ [ bv ]) in
            List.map (fun e -> Lam (bv, e)) f_bodies
          else []
        in
        let group_app : t list =
          let two_parts = Std.list_split fvs in
          List.concat_map
            (fun (fvs1, fvs2) ->
              let es1 : t list = loop (d - 1) fvs1 bvs in
              let es2 : t list = loop (d - 1) fvs2 bvs in
              List.concat_map
                (fun e2 -> List.map (fun e1 -> App (e1, e2)) es1)
                es2)
            two_parts
        in
        group_var @ group_lam @ group_app
    in
    loop max_depth Id.domain []

  let domain = gen ()
  let dump_domain () = Std.dump_list domain pp
end

module Short4_id = De_bruijin_id_maker (struct
  let n = 4
end)

module Short_lang = Short_lang_maker (Short4_id)

module Examples = struct
  let x = Short4_id.x

  open Short_lang

  let e = Var x
end
