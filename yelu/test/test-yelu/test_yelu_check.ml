open Base
open Yelu_langs.Lang_yelu_cmake
open Yelu_langs.Lang_yelu_utils

let no_errors name stmts =
  Alcotest.test_case name `Quick (fun () ->
    let (_, errs) = Cmake_check.check_stmts Cmake_check.empty_env stmts in
    Alcotest.(check int) name 0 (List.length errs))

let has_errors name stmts =
  Alcotest.test_case name `Quick (fun () ->
    let (_, errs) = Cmake_check.check_stmts Cmake_check.empty_env stmts in
    Alcotest.(check bool) name true (not (List.is_empty errs)))

(* helpers *)
let str_lit s = ystr s           (* Yexpr_string (Ycs_val s) *)
let bool_lit b = Yexpr_bool b
let cvar_expr s = Yexpr_cvar (ycvar s)
let yvar_expr s = Yexpr_var (Yvar s)
let out = ycvar "OUT"

(* ============================================================
   Positive — no type errors expected
   ============================================================ *)

let positive = ("string_check_positive", [

  no_errors "toupper string literal"
    [ Ys_string (Ystr_toupper { string = str_lit "hello"; out }) ];

  no_errors "tolower string literal"
    [ Ys_string (Ystr_tolower { string = str_lit "HELLO"; out }) ];

  no_errors "length of string literal"
    [ Ys_string (Ystr_length { string = str_lit "hi"; out }) ];

  no_errors "concat two strings"
    [ Ys_string (Ystr_concat { out; inputs = [str_lit "a"; str_lit "b"] }) ];

  no_errors "join strings"
    [ Ys_string (Ystr_join { glue = str_lit ";"; out; inputs = [str_lit "x"; str_lit "y"] }) ];

  no_errors "untyped cvar passes through (Ty_any)"
    [ Ys_string (Ystr_toupper { string = cvar_expr "UNTYPED"; out }) ];

  (* env flow: Ylet binds a string, subsequent op sees Ty_string *)
  no_errors "ylet string then toupper"
    [ Ylet { var = Yvar "msg"; value = str_lit "world" };
      Ys_string (Ystr_toupper { string = yvar_expr "msg"; out }) ];

  no_errors "ylet string then length"
    [ Ylet { var = Yvar "msg"; value = str_lit "world" };
      Ys_string (Ystr_length { string = yvar_expr "msg"; out }) ];

  (* output binding propagates type forward *)
  no_errors "string op output reused"
    [ Ys_string (Ystr_toupper { string = str_lit "hi"; out = ycvar "TMP" });
      Ys_string (Ystr_length { string = cvar_expr "TMP"; out }) ];

  no_errors "cond strequal two strings"
    [ Yif { cond = Ystrequal (str_lit "a", str_lit "b");
            then_ = Ystmt_list []; else_ = None } ];
])

(* ============================================================
   Negative — at least one type error expected
   ============================================================ *)

let negative = ("string_check_negative", [

  has_errors "bool where string expected (toupper)"
    [ Ys_string (Ystr_toupper { string = bool_lit true; out }) ];

  has_errors "bool in concat inputs"
    [ Ys_string (Ystr_concat { out; inputs = [str_lit "ok"; bool_lit false] }) ];

  has_errors "bool in join glue"
    [ Ys_string (Ystr_join { glue = bool_lit true; out; inputs = [str_lit "x"] }) ];

  has_errors "bool in join item"
    [ Ys_string (Ystr_join { glue = str_lit ","; out; inputs = [bool_lit false] }) ];

  (* env flow: Ylet binds a bool, subsequent string op catches it *)
  has_errors "ylet bool then toupper"
    [ Ylet { var = Yvar "flag"; value = bool_lit true };
      Ys_string (Ystr_toupper { string = yvar_expr "flag"; out }) ];

  has_errors "ylet bool then length"
    [ Ylet { var = Yvar "flag"; value = bool_lit true };
      Ys_string (Ystr_length { string = yvar_expr "flag"; out }) ];

  has_errors "cond strequal bool and string"
    [ Yif { cond = Ystrequal (bool_lit true, str_lit "b");
            then_ = Ystmt_list []; else_ = None } ];
])

let () = Alcotest.run "Yelu Check" [ positive; negative ]
