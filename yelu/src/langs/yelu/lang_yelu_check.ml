open Base
open Lang_yelu_type

(* Per-theory type checkers. Each Make_xxx_check mirrors its Make_xxx counterpart
   in lang_yelu.ml — same functor parameter, adds a check function.
   The integrated cmake-pack checker composes these. *)

let rec compatible expected got =
  match expected, got with
  | Ty_any, _ | _, Ty_any -> true
  | Ty_list a, Ty_list b -> compatible a b
  | e, g -> equal_yelu_type e g

let check_compat ~context expected got =
  if compatible expected got then []
  else [ Type_mismatch { expected; got; context } ]

(* ============================================================
   Cond checker
   ============================================================ *)

module Make_cond_check (T : Lang_yelu.LANG_TYPES) = struct
  include Lang_yelu.Make_cond (T)

  let rec check ~(type_of : T.expr -> yelu_type) = function
    | Ytruthy e ->
      check_compat ~context:"truthy" Ty_string (type_of e)
    | Ynot c -> check ~type_of c
    | Yand (c1, c2) | Yor (c1, c2) ->
      check ~type_of c1 @ check ~type_of c2
    | Yis_target e ->
      check_compat ~context:"if(TARGET)" Ty_string (type_of e)
    | Yis_defined e ->
      check_compat ~context:"if(DEFINED)" Ty_string (type_of e)
    | Ystrequal (e1, e2) | Ystrless (e1, e2) | Ystrgreater (e1, e2)
    | Ystrless_equal (e1, e2) | Ystrgreater_equal (e1, e2) ->
      check_compat ~context:"str_cmp" Ty_string (type_of e1)
      @ check_compat ~context:"str_cmp" Ty_string (type_of e2)
    | Yequal (e1, e2) | Yless (e1, e2) | Ygreater (e1, e2)
    | Yless_equal (e1, e2) | Ygreater_equal (e1, e2) ->
      check_compat ~context:"num_cmp" Ty_int (type_of e1)
      @ check_compat ~context:"num_cmp" Ty_int (type_of e2)
    | Yin_list (e, lst) ->
      let lst_err = match type_of lst with
        | Ty_list _ | Ty_any -> []
        | got -> [ Type_mismatch { expected = Ty_list Ty_any; got; context = "IN_LIST list" } ]
      in
      check_compat ~context:"IN_LIST item" Ty_string (type_of e) @ lst_err
    | Ymatches (e, _) ->
      check_compat ~context:"MATCHES" Ty_string (type_of e)
    | Yexists e | Yis_directory e | Yis_absolute e ->
      check_compat ~context:"path_check" Ty_path (type_of e)
    | Ypolicy_defined _ -> []
    | Yversion_less (e1, e2) | Yversion_greater (e1, e2)
    | Yversion_equal (e1, e2) | Yversion_less_equal (e1, e2)
    | Yversion_greater_equal (e1, e2) ->
      check_compat ~context:"version_cmp" Ty_version (type_of e1)
      @ check_compat ~context:"version_cmp" Ty_version (type_of e2)
end
