open Yelu_langs.Lang_cmake
open Yelu_langs.Lang_yelu
open Yelu_langs.Lang_yelu_utils
open Yelu_langs.Lang_yelu_compile
open Yelu_langs.Lang_cmake_pp

let pp_to_string ast = Fmt.str "%a" pp ast
let pp_vbox_to_string ast = Fmt.str "%a" (Fmt.vbox pp) ast

let check name expected yelu_ast =
  Alcotest.test_case name `Quick (fun () ->
      let cmake_ast = compile empty_env yelu_ast |> snd in
      Alcotest.(check string) name expected (pp_to_string cmake_ast))

let check_vbox name expected yelu_ast =
  Alcotest.test_case name `Quick (fun () ->
      let cmake_ast = compile empty_env yelu_ast |> snd in
      Alcotest.(check string) name expected (pp_vbox_to_string cmake_ast))

(* --- Test groups --- *)

let primitives =
  ( "primitives",
    [
      check "set var" "set(FOO bar )"
        (yc_set (ycstr "FOO") [ ystr "bar" ]);
      check "set quoted" "set(FOO \"hello\" )"
        (yc_set (ycstr "FOO") [ yraw "hello" ]);
      check "set bool" "set(FOO ON )"
        (yc_set (ycstr "FOO") [ ybool true ]);
      check "set multiple" "set(SRCS a.cpp\nb.cpp )"
        (yc_set (ycstr "SRCS") [ yfile "a.cpp"; yfile "b.cpp" ]);
      check "set parent_scope" "set(X val PARENT_SCOPE)"
        (yc_set ~parent_scope:true (ycstr "X") [ ystr "val" ]);
    ] )

let conditions =
  ( "conditions",
    [
      check "if cond_var"
        "if (USE_MYMATH)\n  set(X 1 )\nendif()\n"
        (yifthen (Ytruthy (ycstr "USE_MYMATH"))
           (yc_set (ycstr "X") [ ystr "1" ]));
      check "if with else"
        "if (USE_MYMATH)\n  set(X 1 )\nelse()\n  set(X 0 )\nendif()\n"
        (yif (Ytruthy (ycstr "USE_MYMATH"))
           (yc_set (ycstr "X") [ ystr "1" ])
           (yc_set (ycstr "X") [ ystr "0" ]));
      check "if and"
        "if (HAVE_LOG AND HAVE_EXP)\n  \nendif()\n"
        (yifthen
           (Yand (Ytruthy (ycstr "HAVE_LOG"), Ytruthy (ycstr "HAVE_EXP")))
           (Yexp_list []));
      check "is_target"
        "if (TARGET SqrtLibrary)\n  \nendif()\n"
        (yifthen (Yis_target (ytval "SqrtLibrary")) (Yexp_list []));
      check "is_defined"
        "if (DEFINED MY_VAR)\n  \nendif()\n"
        (yifthen (Yis_defined (ycstr "MY_VAR")) (Yexp_list []));
    ] )

let targets =
  ( "targets",
    [
      check "add_library"
        "add_library(MathFunctions  MathFunctions.cxx)"
        (add_lib ~sources:[ yfile "MathFunctions.cxx" ] (ytval "MathFunctions"));
      check "add_library interface"
        "add_library(flags INTERFACE )"
        (add_lib ~type_:Lib_interface (ytval "flags"));
      check "add_executable"
        "add_executable(Tutorial tutorial.cxx)"
        (add_exe ~sources:[ yfile "tutorial.cxx" ] (ytval "Tutorial"));
      check "target_link_libraries"
        "target_link_libraries(Tutorial PUBLIC MathFunctions)"
        (link_lib [ ytval "Tutorial" ]
           [ ytarget_def [ ytval "MathFunctions" ] ]);
      check "target_compile_definitions"
        "target_compile_definitions(MathFunctions PRIVATE \"USE_MYMATH\")"
        (compile_defs (ytval "MathFunctions")
           [ ytarget_def ~kind:Private [ yraw "USE_MYMATH" ] ]);
      check "target_include_directories"
        "target_include_directories(Tutorial PUBLIC \"${PROJECT_BINARY_DIR}\")"
        (include_dirs (ytval "Tutorial")
           [ ytarget_def [ yraw "${PROJECT_BINARY_DIR}" ] ]);
    ] )

let project_level =
  ( "project_level",
    [
      check "cmake_minimum_required"
        "cmake_minimum_required(VERSION 3.20)"
        (yc_minimum_required_s "3.20.");
      check "project"
        "project(Tutorial VERSION 1.0)"
        (yc_project ~version:(Yelu_langs.Lang_cmake_utils.version_of_string "1.0.") "Tutorial");
      check "project no version"
        "project(MyApp )"
        (yc_project "MyApp");
      check "configure_file"
        "configure_file(TutorialConfig.h.in TutorialConfig.h)"
        (gen_file ~input:(yfile "TutorialConfig.h.in") (yfile "TutorialConfig.h"));
      check "add_subdirectory"
        "add_subdirectory(MathFunctions)"
        (yc_add_subdirectory (ydir "MathFunctions"));
    ] )

let composition =
  ( "composition",
    [
      check_vbox "exp_list two stmts"
        "set(X 1 )\nset(Y 2 )"
        (ycmd_of_list
           [ yc_set (ycstr "X") [ ystr "1" ]; yc_set (ycstr "Y") [ ystr "2" ] ]);
    ] )

let let_bindings =
  ( "let_bindings",
    [
      check "ylet basic"
        "add_executable(Tutorial tutorial.cxx)"
        (ycmd_of_list
           [
             ylet "tut" (ytval "Tutorial");
             add_exe ~sources:[ yfile "tutorial.cxx" ] (yvar "tut");
           ]);
      check_vbox "ylet reuse"
        "add_library(mylib  src.cxx)\ntarget_link_libraries(mylib PUBLIC dep)"
        (ycmd_of_list
           [
             ylet "lib" (ytval "mylib");
             add_lib ~sources:[ yfile "src.cxx" ] (yvar "lib");
             link_lib [ yvar "lib" ]
               [ ytarget_def [ ystr "dep" ] ];
           ]);
      check "ylet chain"
        "add_executable(App main.cxx)"
        (ycmd_of_list
           [
             ylet "name" (ytval "App");
             ylet "alias" (yvar "name");
             add_exe ~sources:[ yfile "main.cxx" ] (yvar "alias");
           ]);
      check "ylet in target list"
        "target_link_libraries(main PUBLIC mylib)"
        (ycmd_of_list
           [
             ylet "t" (ytval "main");
             ylet "l" (ytval "mylib");
             link_lib [ yvar "t" ]
               [ ytarget_def [ yvar "l" ] ];
           ]);
      check "ylet bare string in target pos"
        "add_executable(App main.cxx)"
        (ycmd_of_list
           [
             ylet "name" (ystr "App");
             add_exe ~sources:[ yfile "main.cxx" ] (yvar "name");
           ]);
    ] )

let iteration =
  ( "iteration",
    [
      check "foreach items no body"
        "foreach(x a b)\nendforeach()"
        (yc_foreach ~items:[ ystr "a"; ystr "b" ] "x" (Yexp_list []));
      check "foreach items with body"
        "foreach(x a b)\n  set(FOO bar )\nendforeach()"
        (yc_foreach ~items:[ ystr "a"; ystr "b" ] "x"
           (yc_set (ycstr "FOO") [ ystr "bar" ]));
      check "foreach_range stop only"
        "foreach(i RANGE 10)\nendforeach()"
        (yc_foreach_range ~stop:10 "i" (Yexp_list []));
      check "foreach_range start stop"
        "foreach(i RANGE  0 10)\nendforeach()"
        (yc_foreach_range ~start:0 ~stop:10 "i" (Yexp_list []));
      check "foreach_in lists"
        "foreach(f IN LISTS MY_LIST)\nendforeach()"
        (yc_foreach_in ~lists:[ ycstr "MY_LIST" ] "f" (Yexp_list []));
      check "foreach_in items"
        "foreach(f IN ITEMS a b)\nendforeach()"
        (yc_foreach_in ~items:[ ystr "a"; ystr "b" ] "f" (Yexp_list []));
    ] )

let loop_control =
  ( "loop_control",
    [
      check "while empty body"
        "while(FLAG)\n  \nendwhile()"
        (yc_while (Ytruthy (ycstr "FLAG")) (Yexp_list []));
      check "break" "break()" yc_break;
      check "continue" "continue()" yc_continue;
      check "return empty" "return()" (yc_return ());
      check "return propagate"
        "return(PROPAGATE FOO\nBAR )"
        (yc_return ~propogate_vars:[ "FOO"; "BAR" ] ());
    ] )

let list_ops =
  ( "list_ops",
    [
      check "list_length"
        "list(LENGTH MY_LIST OUT)\n"
        (yc_list_length (ycstr "MY_LIST") "OUT");
      check "list_get"
        "list(GET MY_LIST 0 OUT)\n"
        (yc_list_get ~indices:[ 0 ] (ycstr "MY_LIST") "OUT");
      check "list_remove_item"
        "list(REMOVE_ITEM MY_LIST a b)\n"
        (yc_list_remove_item (ycstr "MY_LIST") [ ystr "a"; ystr "b" ]);
      check "list_remove_duplicates"
        "list(REMOVE_DUPLICATES MY_LIST)\n"
        (yc_list_remove_duplicates (ycstr "MY_LIST"));
      check "list_reverse"
        "list(REVERSE MY_LIST)\n"
        (yc_list_reverse (ycstr "MY_LIST"));
      check "list_sort default"
        "list(SORT MY_LIST)\n"
        (yc_list_sort (ycstr "MY_LIST"));
      check "list_filter include"
        "list(FILTER MY_LIST INCLUDE REGEX \".*\\.h\")\n"
        (yc_list_filter Lf_include ".*\\.h" (ycstr "MY_LIST"));
    ] )

let string_ops =
  ( "string_ops",
    [
      check "string_toupper"
        "string(TOUPPER hello OUT)"
        (yc_string_toupper (ystr "hello") "OUT");
      check "string_tolower"
        "string(TOLOWER hello OUT)"
        (yc_string_tolower (ystr "hello") "OUT");
      check "string_length"
        "string(LENGTH hello OUT)"
        (yc_string_length (ystr "hello") "OUT");
      check "string_strip"
        "string(STRIP hello OUT)"
        (yc_string_strip (ystr "hello") "OUT");
      check "string_concat"
        "string(CONCAT OUT a b)"
        (yc_string_concat "OUT" [ ystr "a"; ystr "b" ]);
      check "string_replace"
        "string(REPLACE foo bar OUT input)"
        (yc_string_replace (ystr "foo") (ystr "bar") "OUT" [ ystr "input" ]);
      check "string_regex_match"
        "string(REGEX MATCH \"[0-9]+\" OUT src)"
        (yc_string_regex_match "[0-9]+" "OUT" [ ystr "src" ]);
      check "string_regex_replace"
        "string(REGEX REPLACE \"[0-9]+\" X OUT src)"
        (yc_string_regex_replace "[0-9]+" (ystr "X") "OUT" [ ystr "src" ]);
    ] )

let () =
  Alcotest.run "Yelu Compile"
    [ primitives; conditions; targets; project_level; composition; let_bindings;
      iteration; loop_control; list_ops; string_ops ]
