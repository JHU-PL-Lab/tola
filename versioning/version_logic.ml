[@@@warning "-37"]

open Base

module type P_str = sig
  type pid

  val pid_to_str : pid -> string
  val str_to_pid : string -> pid
end

module type V_str = sig
  type version

  val of_str : string -> version
  val to_str : version -> string
  val compare : version -> version -> Std.Ordering.t * int
end

module type S = sig
  type lit
  type var
  type answer = (var * lit) list (* map *)
  type multi_answer = (var * lit) list (* multimap *)
  type exp
  type dependencies = exp list

  val sexp_of_exp : exp -> Sexp.t
  val exp_of_sexp : Sexp.t -> exp
  val deps_of_sexp : Sexp.t -> dependencies
  val solve : exp list -> answer option
  val solve_exn : exp list -> answer
  val pp_answer : answer Fmt.t
  val resolve : answer -> multi_answer -> dependencies -> answer option
end

module Make (P : P_str) (V : V_str) : S = struct
  open P
  (* open V *)

  type lit = V.version

  type clause =
    | Eq of lit * lit
    | Lt of lit * lit
    | Le of lit * lit
    | Gt of lit * lit
    | Ge of lit * lit
    | Same_depth of lit * lit * int

  type var = pid

  type exp =
    | Eq_dep of var * lit
    | Lt_dep of var * lit
    | Le_dep of var * lit
    | Gt_dep of var * lit
    | Ge_dep of var * lit
    | Same_depth_dep of var * lit * int
    | In of var * lit list

  type answer = (var * lit) list
  type multi_answer = (var * lit) list
  type dependencies = exp list
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

  let sexp_of_exp exp : Sexp.t =
    let open Sexp in
    match exp with
    | Eq_dep (pid, ver) ->
        List [ Atom "="; Atom (pid_to_str pid); Atom (V.to_str ver) ]
    | Lt_dep (pid, ver) ->
        List [ Atom "<"; Atom (pid_to_str pid); Atom (V.to_str ver) ]
    | Le_dep (pid, ver) ->
        List [ Atom "<="; Atom (pid_to_str pid); Atom (V.to_str ver) ]
    | Gt_dep (pid, ver) ->
        List [ Atom ">"; Atom (pid_to_str pid); Atom (V.to_str ver) ]
    | Ge_dep (pid, ver) ->
        List [ Atom ">="; Atom (pid_to_str pid); Atom (V.to_str ver) ]
    | Same_depth_dep (pid, ver, d) ->
        List
          [
            Atom "~>";
            Atom (pid_to_str pid);
            Atom (V.to_str ver);
            Int.sexp_of_t d;
          ]
    | In (pid, vers) ->
        List
          [
            Atom "in";
            Atom (pid_to_str pid);
            List.sexp_of_t (fun ver -> Atom (V.to_str ver)) vers;
          ]

  let exp_of_sexp sexp : exp =
    let open Sexp in
    match sexp with
    (* compare *)
    | List [ Atom op; Atom pid_s; Atom op2_s ] -> (
        match op with
        | "=" -> Eq_dep (str_to_pid pid_s, V.of_str op2_s)
        | "<" -> Lt_dep (str_to_pid pid_s, V.of_str op2_s)
        | "<=" -> Le_dep (str_to_pid pid_s, V.of_str op2_s)
        | ">" -> Gt_dep (str_to_pid pid_s, V.of_str op2_s)
        | ">=" -> Ge_dep (str_to_pid pid_s, V.of_str op2_s)
        | _ -> failwith "incorrect compare op")
    | List [ Atom op; Atom pid_s; List vers ] -> (
        match op with
        | "in" ->
            In
              ( str_to_pid pid_s,
                List.map
                  ~f:(function
                    | Atom ver_s -> V.of_str ver_s | _ -> failwith "not ver")
                  vers )
        | _ -> failwith "incorrect op")
    (* ternary *)
    | List [ Atom op; Atom pid_s; Atom op2_s; Atom d_s ] -> (
        match op with
        | "~>" ->
            Same_depth_dep (str_to_pid pid_s, V.of_str op2_s, Int.of_string d_s)
        | _ -> failwith "incorrect ternary op")
    | _ -> failwith "sexp"

  let deps_of_sexp = List.t_of_sexp exp_of_sexp
  let sexp_of_deps = List.sexp_of_t sexp_of_exp
  (*
       let sexp_of_t (map : t) : Sexp.t =
         map
         |> to_list
         |> List.sexp_of_t My_tuple.sexp_of_t

       let t_of_sexp (sexp : Sexp.t) : t =
         sexp
         |> List.t_of_sexp My_tuple.t_of_sexp
         |> List.fold ~init:empty ~f:(fun acc (id, true_status, false_status) ->
           acc
           |> Map.set ~key:({ branch_ident = Jayil.Ast.Ident id ; direction = Branch.Direction.True_direction}) ~data:true_status
           |> Map.set ~key:({ branch_ident = Jayil.Ast.Ident id ; direction = Branch.Direction.False_direction}) ~data:false_status
         )
  *)

  (* let parse_exp s =
     let segs = String.split_on_chars s ~on:[ '='; '<'; '>'; '~' ] in
     let pid = List.hd_exn segs in
     let version = List.last_exn segs |> V.of_str in
     let op = segs |> List.tl_exn |> List.drop_last_exn |> String.concat in
     (pid, version, op) *)

  let compare_std v1 v2 = V.compare v1 v2 |> fst

  include Std.Make_compares (struct
    type nonrec t = lit

    let compare = compare_std
  end)

  let is_clause_sat = function
    | Eq (v1, v2) -> eq v1 v2
    | Lt (v1, v2) -> lt v1 v2
    | Le (v1, v2) -> le v1 v2
    | Gt (v1, v2) -> gt v1 v2
    | Ge (v1, v2) -> ge v1 v2
    | Same_depth (v1, v2, d) ->
        let _ord, dd = V.compare v1 v2 in
        dd >= d

  let is_deps_sat clauses = List.for_all ~f:is_clause_sat clauses

  let solve exps =
    let pid_vers_alist, exps =
      List.partition_map
        ~f:(function
          | In (pid, vers) -> Either.First (pid, vers)
          | exp -> Either.Second exp)
        exps
    in
    let pids = List.map ~f:fst pid_vers_alist in
    let vers = List.map ~f:snd pid_vers_alist in
    let ver_choices = List.all vers in
    let sat_ver_choice =
      List.find ver_choices ~f:(fun choice ->
          let pid_ver = List.zip_exn pids choice in
          let lookup pid =
            List.Assoc.find_exn pid_ver
              ~equal:(Std.fn_lift2 String.equal pid_to_str)
              pid
          in
          List.for_all exps ~f:(function
            | Eq_dep (pid, ver) -> eq (lookup pid) ver
            | Lt_dep (pid, ver) -> lt (lookup pid) ver
            | Le_dep (pid, ver) -> le (lookup pid) ver
            | Gt_dep (pid, ver) -> gt (lookup pid) ver
            | Ge_dep (pid, ver) -> ge (lookup pid) ver
            | Same_depth_dep (_pid, _ver, _d) -> true
            | _ -> true))
    in
    Option.map sat_ver_choice ~f:(fun ver_choice ->
        List.zip_exn pids ver_choice)

  let solve_exn exps = Option.value_exn (solve exps)
  let resolve _local _remote _deps = None

  let pp_answer fmt answer =
    Fmt.pf fmt "%a"
      Fmt.Dump.(
        list @@ pair (Fmt.of_to_string pid_to_str) (Fmt.of_to_string V.to_str))
      answer
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
  type t = unit
  type version = t

  let of_str = function "" -> () | _ -> failwith "of_str"
  let to_str () = ""
  let compare () () = (Std.Ordering.Equal, 0)
end

module Multi_part_logic =
  Make
    (struct
      type pid = string

      let pid_to_str = Base.Fn.id
      let str_to_pid = Base.Fn.id
    end)
    (struct
      type version = Multi_part.t

      let of_str = Multi_part.of_str
      let to_str = Multi_part.to_str
      let compare = Multi_part.compare
    end)
