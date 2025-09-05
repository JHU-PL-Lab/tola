[@@@warning "-37"]

open Base
open Tola_std

module type P_str = sig
  type pname [@@deriving yojson]

  val pname_to_str : pname -> string
  val str_to_pname : string -> pname
  val compare : pname -> pname -> int
end

module type V_str = sig
  type version [@@deriving yojson]

  val of_str : string -> version
  val to_str : version -> string
  val compare_full : version -> version -> Ordering.t * int
  val equal : version -> version -> bool
end

module type S = sig
  module P : P_str
  module V : V_str

  type lit [@@deriving yojson] (* package name *)
  type var [@@deriving yojson] (* version *)
  type answer = (var * lit) list [@@deriving yojson] (* assignment *)

  (* logic expression *)
  type exp =
    | Eq of var * lit
    | Lt of var * lit
    | Le of var * lit
    | Gt of var * lit
    | Ge of var * lit
    | Same_depth of var * lit * int
    | In of var * lit list
    | Or of exp list
    | And of exp list
    | Imply of exp * exp
    | Exist of var
    | True
  [@@deriving yojson]

  type dependencies = exp

  type dep_config = {
    pkgs : (var * lit * exp) list;
    local_pkgs : (var * lit) list;
    remote_pkgs : (var * lit) list;
    to_install : (var * lit) list;
  }

  type answer_type =
    (* perfect install *)
    | Exact of answer
    (* upgrade install *)
    | Upgrade_local of answer
    | Downgrade_local of answer
    (* relaxed install *)
    | Relaxed_install of answer
    | Unsat

  val sexp_of_exp : exp -> Sexp.t
  val exp_of_sexp : Sexp.t -> exp
  val str_of_exp : exp -> string
  val exp_of_str : string -> exp
  val solve : ?opt:bool -> dependencies -> answer option
  val solve_dep_config : dep_config -> answer_type

  (* val solve_exn : dependencies -> answer *)
  val pp_answer : answer Fmt.t
  val equal_answer : answer -> answer -> bool
end

module Make (P : P_str) (V : V_str) :
  S
    with module P = P
     and module V = V
     and type var = P.pname
     and type lit = V.version = struct
  module P = P
  module V = V

  type var = P.pname [@@deriving yojson]
  type lit = V.version [@@deriving yojson]

  open P
  open Ppx_yojson_conv_lib.Yojson_conv.Primitives

  type exp =
    | Eq of var * lit
    | Lt of var * lit
    | Le of var * lit
    | Gt of var * lit
    | Ge of var * lit
    | Same_depth of var * lit * int
    | In of var * lit list
    (* the following is necessary or helpful to solve but they don't have to be a surface constraint
    Another overlooked point is a package can be not selected, or selected as a version Top. *)
    | Or of exp list
    | And of exp list
    | Imply of exp * exp
    | Exist of var
    | True
  [@@deriving yojson]

  type dep_config = {
    pkgs : (var * lit * exp) list;
    local_pkgs : (var * lit) list;
    remote_pkgs : (var * lit) list;
    to_install : (var * lit) list;
  }

  type answer = (var * lit) list [@@deriving yojson]

  type answer_type =
    | Exact of answer
    | Upgrade_local of answer
    | Downgrade_local of answer
    | Relaxed_install of answer
    | Unsat

  let pp_answer fmt answer =
    Fmt.pf fmt "%a"
      Fmt.Dump.(
        list @@ pair (Fmt.of_to_string pname_to_str) (Fmt.of_to_string V.to_str))
      answer

  let equal_answer a1 a2 =
    Fmt.pr "equal_answer %a %a@." pp_answer a1 pp_answer a2;
    if List.length a1 <> List.length a2 then false
    else
      List.equal
        (fun (v1, l1) (v2, l2) -> P.compare v1 v2 = 0 && V.equal l1 l2)
        a1 a2

  type dependencies = exp
  type ops = Eq_op | Lt_op | Le_op | Gt_op | Ge_op | Same_depth_op | In_op

  let op_to_str = function
    | Eq_op -> "="
    | Lt_op -> "<"
    | Le_op -> "<="
    | Gt_op -> ">"
    | Ge_op -> ">="
    | Same_depth_op -> "~>"
    | In_op -> "in"

  let str_to_op = function
    | "=" -> Eq_op
    | "<" -> Lt_op
    | "<=" -> Le_op
    | ">" -> Gt_op
    | ">=" -> Ge_op
    | "~>" -> Same_depth_op
    | "in" -> In_op
    | _ -> failwith "not op"

  let rec sexp_of_exp exp : Sexp.t =
    let open Sexp in
    match exp with
    | Eq (pname, ver) ->
        List [ Atom "="; Atom (pname_to_str pname); Atom (V.to_str ver) ]
    | Lt (pname, ver) ->
        List [ Atom "<"; Atom (pname_to_str pname); Atom (V.to_str ver) ]
    | Le (pname, ver) ->
        List [ Atom "<="; Atom (pname_to_str pname); Atom (V.to_str ver) ]
    | Gt (pname, ver) ->
        List [ Atom ">"; Atom (pname_to_str pname); Atom (V.to_str ver) ]
    | Ge (pname, ver) ->
        List [ Atom ">="; Atom (pname_to_str pname); Atom (V.to_str ver) ]
    | Same_depth (pname, ver, d) ->
        List
          [
            Atom "~>";
            Atom (pname_to_str pname);
            Atom (V.to_str ver);
            Int.sexp_of_t d;
          ]
    | In (pname, vers) ->
        List
          [
            Atom "in";
            Atom (pname_to_str pname);
            List.sexp_of_t (fun ver -> Atom (V.to_str ver)) vers;
          ]
    | Or es -> List ([ Atom "or" ] @ List.map ~f:sexp_of_exp es)
    | And es -> List ([ Atom "and" ] @ List.map ~f:sexp_of_exp es)
    | Imply (e1, e2) -> List [ Atom "imply"; sexp_of_exp e1; sexp_of_exp e2 ]
    | Exist pname -> List [ Atom "exist"; Atom (pname_to_str pname) ]
    | True -> Atom "true"

  let rec exp_of_sexp sexp : exp =
    let open Sexp in
    match sexp with
    (* compare *)
    | List (Atom "or" :: es) -> Or (List.map ~f:exp_of_sexp es)
    | List (Atom "and" :: es) -> And (List.map ~f:exp_of_sexp es)
    | List [ Atom op; Atom pname_s; Atom op2_s ] -> (
        match op with
        | "=" -> Eq (str_to_pname pname_s, V.of_str op2_s)
        | "<" -> Lt (str_to_pname pname_s, V.of_str op2_s)
        | "<=" -> Le (str_to_pname pname_s, V.of_str op2_s)
        | ">" -> Gt (str_to_pname pname_s, V.of_str op2_s)
        | ">=" -> Ge (str_to_pname pname_s, V.of_str op2_s)
        | _ -> failwith "incorrect compare op")
    | List [ Atom op; Atom pname_s; List vers ] -> (
        match op with
        | "in" ->
            In
              ( str_to_pname pname_s,
                List.map
                  ~f:(function
                    | Atom ver_s -> V.of_str ver_s | _ -> failwith "not ver")
                  vers )
        | _ -> failwith "incorrect op")
    (* ternary *)
    | List [ Atom op; Atom pname_s; Atom op2_s; Atom d_s ] -> (
        match op with
        | "~>" ->
            Same_depth (str_to_pname pname_s, V.of_str op2_s, Int.of_string d_s)
        | _ -> failwith "incorrect ternary op")
    | _ -> failwith "sexp"

  let str_of_exp v = v |> sexp_of_exp |> Sexp.to_string_hum
  let exp_of_str s = s |> Sexplib.Sexp.of_string |> exp_of_sexp

  (* let parse_exp s =
     let segs = String.split_on_chars s ~on:[ '='; '<'; '>'; '~' ] in
     let pname = List.hd_exn segs in
     let version = List.last_exn segs |> V.of_str in
     let op = segs |> List.tl_exn |> List.drop_last_exn |> String.concat in
     (pname, version, op) *)

  let compare_std v1 v2 = V.compare_full v1 v2 |> fst
  let compare_gt v1 v2 = -Base.Ordering.to_int (compare_std v1 v2)

  include Std.Make_compares (struct
    type nonrec t = lit

    let compare = compare_std
  end)

  let rec eval answer exp =
    let lookup pname =
      List.Assoc.find_exn answer ~equal:String.equal (P.pname_to_str pname)
    in
    let map_or_false vo f = match vo with Some x -> f x | None -> false in
    match exp with
    | Eq (pname, ver) -> map_or_false (lookup pname) (fun v -> V.equal v ver)
    | Lt (pname, ver) ->
        map_or_false (lookup pname) (fun v ->
            Std.Ordering.(equal (compare_std v ver) Less))
    | Gt (pname, ver) ->
        map_or_false (lookup pname) (fun v ->
            Std.Ordering.(equal (compare_std v ver) Greater))
    | Le (pname, ver) ->
        map_or_false (lookup pname) (fun v ->
            Std.Ordering.(
              equal (compare_std v ver) Less || equal (compare_std v ver) Equal))
    | Ge (pname, ver) ->
        map_or_false (lookup pname) (fun v ->
            Std.Ordering.(
              equal (compare_std v ver) Greater
              || equal (compare_std v ver) Equal))
    | Same_depth (pname, ver, d) ->
        map_or_false (lookup pname) (fun v -> snd (V.compare_full v ver) >= d)
    | In (pname, vers) ->
        map_or_false (lookup pname) (fun v -> List.mem vers v ~equal:V.equal)
    | Or es -> List.exists ~f:(eval answer) es
    | And es -> List.for_all ~f:(eval answer) es
    | Imply (e1, e2) -> (not (eval answer e1)) || eval answer e2
    | Exist pname -> map_or_false (lookup pname) (fun _ -> true)
    | True -> true

  let cartesian_product_of_lists list_of_lists =
    match list_of_lists with
    | [] -> [ [] ]
    | first_list :: rest_lists ->
        List.fold_left rest_lists
          ~init:(List.map first_list ~f:(fun x -> [ x ]))
          ~f:(fun acc list ->
            List.cartesian_product acc list
            |> List.map ~f:(fun (xs, x) -> xs @ [ x ]))

  (* a more practical solution is to use soft constraints or opt to solve *)
  let solve ?(opt = false) exp =
    (* generate possible version assignment *)
    let pkg_ver_table = Hashtbl.create (module String) in
    let add_ver pname ver =
      let vers = Hashtbl.find_multi pkg_ver_table (pname_to_str pname) in
      if List.mem vers ver ~equal:V.equal then ()
      else Hashtbl.add_multi pkg_ver_table ~key:(pname_to_str pname) ~data:ver
    in
    let rec add_vers exp =
      match exp with
      | Eq (pname, ver) -> add_ver pname ver
      | Lt (pname, ver) -> add_ver pname ver
      | Le (pname, ver) -> add_ver pname ver
      | Gt (pname, ver) -> add_ver pname ver
      | Ge (pname, ver) -> add_ver pname ver
      | Same_depth _ -> ()
      | In (pname, vers) -> List.iter ~f:(fun ver -> add_ver pname ver) vers
      | Or es -> List.iter ~f:add_vers es
      | And es -> List.iter ~f:add_vers es
      | Imply (e1, e2) ->
          add_vers e1;
          add_vers e2
      | Exist _pname -> ()
      | True -> ()
    in
    add_vers exp;
    (* enumerate version assignment *)
    let pkgs, verss =
      let pkgs = Hashtbl.keys pkg_ver_table in
      let pkg_vers =
        List.map
          ~f:(fun pkg ->
            let vers = Hashtbl.find_exn pkg_ver_table pkg in
            let vers_opt =
              List.sort ~compare:compare_gt vers |> List.map ~f:Option.some
            in
            None :: vers_opt)
          pkgs
      in
      let verss = cartesian_product_of_lists pkg_vers in
      (pkgs, verss)
    in
    (* check if the assignment satisfies the constraints *)

    let _ = opt in

    List.find_map verss ~f:(fun vers ->
        let answer_for_eval = List.zip_exn pkgs vers in
        if eval answer_for_eval exp then
          Some
            (let t =
               answer_for_eval
               |> List.filter_map ~f:(fun (pkg, ver) ->
                      match ver with Some v -> Some (pkg, v) | None -> None)
             in
             t
             |> List.sort ~compare:(Std.fn_lift2 String.compare fst)
             |> List.map ~f:(fun (pname, ver) -> (P.str_to_pname pname, ver)))
        else None)

  let solve_dep_config dc =
    let find_trio (pn0, pv0) =
      let _, _, dep =
        List.find_exn dc.pkgs ~f:(fun (pn, pv, _) ->
            P.compare pn pn0 = 0 && V.equal pv pv0)
      in
      dep
    in
    let deps_of_pkg pname_and_pkgs =
      List.concat_map
        ~f:(fun (pn, pv) ->
          let pkg_dep = find_trio (pn, pv) in
          [ Imply (Eq (pn, pv), pkg_dep) ])
        pname_and_pkgs
    in
    let perfect_install =
      List.map ~f:(fun (pn, pv) -> Eq (pn, pv)) dc.to_install
    in
    let perfect_local =
      List.map ~f:(fun (pn, pv) -> Eq (pn, pv)) dc.local_pkgs
    in
    let pkg_deps = deps_of_pkg (dc.local_pkgs @ dc.remote_pkgs) in
    let constraints = And (pkg_deps @ perfect_install @ perfect_local) in
    (* Fmt.pr "[Exact] constraints: %s@." (str_of_exp constraints); *)
    match solve constraints with
    | Some answer -> Exact answer
    | None -> (
        let upgrade_install =
          List.map ~f:(fun (pn, pv) -> Ge (pn, pv)) dc.to_install
        in
        let upgrade_local =
          List.map ~f:(fun (pn, pv) -> Ge (pn, pv)) dc.local_pkgs
        in
        let constraints = And (pkg_deps @ upgrade_install @ upgrade_local) in
        (* Fmt.pr "[Upgrade_local] constraints: %s@." (str_of_exp constraints); *)
        match solve constraints with
        | Some answer -> Upgrade_local answer
        | None -> (
            let constraints = And (pkg_deps @ upgrade_install) in
            (* Fmt.pr "[Downgrade_local] constraints: %s@."
              (str_of_exp constraints); *)
            match solve constraints with
            | Some answer -> Downgrade_local answer
            | None -> (
                let exist_install =
                  List.map ~f:(fun (pn, _pv) -> Exist pn) dc.to_install
                in
                let constraints = And (pkg_deps @ exist_install) in
                (* Fmt.pr "[Anyway] constraints: %s@." (str_of_exp constraints); *)
                match solve constraints with
                | Some answer -> Relaxed_install answer
                | None -> Unsat)))

  let resolve _local _remote _deps = None

  (* if opt then
      let answers =
        List.filter_map verss ~f:(fun vers ->
            let answer = List.zip_exn pkgs vers in
            if eval answer exp then
              Some
                (List.map answer ~f:(fun (pname, ver) ->
                     (P.str_to_pname pname, ver)))
            else None)
      in
      match answers with [] -> None | x :: _xs -> Some x
    else *)
  (* let pname_vers_alist, exps =
      List.partition_map
        ~f:(function
          | In (pname, vers) -> Either.First (pname, vers)
          | exp -> Either.Second exp)
        exps
    in
    let pnames = List.map ~f:fst pname_vers_alist in
    let vers = List.map ~f:snd pname_vers_alist in
    let ver_choices = List.all vers in *)
  (* let sat_ver_choice =
      List.find ver_choices ~f:(fun choice ->
          let pname_ver = List.zip_exn pnames choice in
          let lookup pname =
            List.Assoc.find_exn pname_ver
              ~equal:(Std.fn_lift2 String.equal pname_to_str)
              pname
          in
          List.for_all exps ~f:(function
            | Eq (pname, ver) -> eq (lookup pname) ver
            | Lt (pname, ver) -> lt (lookup pname) ver
            | Le (pname, ver) -> le (lookup pname) ver
            | Gt (pname, ver) -> gt (lookup pname) ver
            | Ge (pname, ver) -> ge (lookup pname) ver
            | Same_depth (_pname, _ver, _d) -> true
            | _ -> true))
    in
    Option.map sat_ver_choice ~f:(fun ver_choice ->
        List.zip_exn pnames ver_choice) *)
end

(* What can be a version theory, or version invariant?

   It should be similar to subtyping on functions and records
*)

module Version_int : Algebra.S_tot = struct
  type t = int
  type ordering = Std.Ordering.t

  let compare t1 t2 =
    let open Std.Ordering in
    if t1 > t2 then Greater else if t1 = t2 then Equal else Less

  let of_str = Int.of_string
  let to_str = Int.to_string
end

module Singleton_version = struct
  open Ppx_yojson_conv_lib.Yojson_conv.Primitives

  type t = unit [@@deriving yojson]
  type version = t [@@deriving yojson]

  let of_str = function "" -> () | _ -> failwith "of_str"
  let to_str () = ""
  let compare () () = (Std.Ordering.Equal, 0)
end
