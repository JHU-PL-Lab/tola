open Langs.Lang_yelu
open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

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
        (yset (ycvar "FOO") [ ybare "bar" ]);
      check "set quoted" "set(FOO \"hello\" )"
        (yset (ycvar "FOO") [ yraw "hello" ]);
      check "set bool" "set(FOO ON )"
        (yset (ycvar "FOO") [ ybool true ]);
      check "set multiple" "set(SRCS a.cpp\nb.cpp )"
        (yset (ycvar "SRCS") [ ybare "a.cpp"; ybare "b.cpp" ]);
      check "set parent_scope" "set(X val PARENT_SCOPE)"
        (yset ~parent_scope:true (ycvar "X") [ ybare "val" ]);
    ] )

let conditions =
  ( "conditions",
    [
      check "if cond_var"
        "if (USE_MYMATH)\n  set(X 1 )\nelse()\n  \nendif()\n"
        (yifthen (Ycond_cvar (ycvar "USE_MYMATH"))
           (yset (ycvar "X") [ ybare "1" ]));
      check "if with else"
        "if (USE_MYMATH)\n  set(X 1 )\nelse()\n  set(X 0 )\nendif()\n"
        (yif (Ycond_cvar (ycvar "USE_MYMATH"))
           (yset (ycvar "X") [ ybare "1" ])
           (yset (ycvar "X") [ ybare "0" ]));
      check "if and"
        "if (HAVE_LOG AND HAVE_EXP)\n  \nelse()\n  \nendif()\n"
        (yifthen
           (Yand (Ycond_cvar (ycvar "HAVE_LOG"), Ycond_cvar (ycvar "HAVE_EXP")))
           (Yexp_list []));
      check "is_target"
        "if (TARGET SqrtLibrary)\n  \nelse()\n  \nendif()\n"
        (yifthen (Yis_target (ytarget "SqrtLibrary")) (Yexp_list []));
      check "is_defined"
        "if (DEFINED MY_VAR)\n  \nelse()\n  \nendif()\n"
        (yifthen (Yis_defined (ycvar "MY_VAR")) (Yexp_list []));
    ] )

let targets =
  ( "targets",
    [
      check "add_library"
        "add_library(MathFunctions  MathFunctions.cxx)"
        (yadd_library ~sources:[ ybare "MathFunctions.cxx" ] (ytarget "MathFunctions"));
      check "add_library interface"
        "add_library(flags INTERFACE )"
        (yadd_library ~type_:Lib_interface (ytarget "flags"));
      check "add_executable"
        "add_executable(Tutorial tutorial.cxx)"
        (yadd_executable ~sources:[ ybare "tutorial.cxx" ] (ytarget "Tutorial"));
      check "target_link_libraries"
        "target_link_libraries(Tutorial PUBLIC MathFunctions)"
        (ytarget_link_libraries [ ytarget "Tutorial" ]
           [ ytarget_def [ ytval "MathFunctions" ] ]);
      check "target_compile_definitions"
        "target_compile_definitions(MathFunctions PRIVATE \"USE_MYMATH\")"
        (ytarget_compile_definitions (ytarget "MathFunctions")
           [ ytarget_def ~kind:Private [ yraw "USE_MYMATH" ] ]);
      check "target_include_directories"
        "target_include_directories(Tutorial PUBLIC \"${PROJECT_BINARY_DIR}\")"
        (ytarget_include_directories (ytarget "Tutorial")
           [ ytarget_def [ yraw "${PROJECT_BINARY_DIR}" ] ]);
    ] )

let project_level =
  ( "project_level",
    [
      check "cmake_minimum_required"
        "cmake_minimum_required(VERSION 3.20)"
        (yminimum_required_s "3.20.");
      check "project"
        "project(Tutorial VERSION 1.0)"
        (yproject ~version:(Langs.Lang_cmake_utils.version_of_string "1.0.") "Tutorial");
      check "project no version"
        "project(MyApp )"
        (yproject "MyApp");
      check "configure_file"
        "configure_file(TutorialConfig.h.in TutorialConfig.h)"
        (yconfigure_file ~input:(ybare "TutorialConfig.h.in") (ybare "TutorialConfig.h"));
      check "add_subdirectory"
        "add_subdirectory(MathFunctions)"
        (yadd_subdirectory (ybare "MathFunctions"));
    ] )

let composition =
  ( "composition",
    [
      check_vbox "exp_list two stmts"
        "set(X 1 )\nset(Y 2 )"
        (ycmd_of_list
           [ yset (ycvar "X") [ ybare "1" ]; yset (ycvar "Y") [ ybare "2" ] ]);
    ] )

let () =
  Alcotest.run "Yelu Compile"
    [ primitives; conditions; targets; project_level; composition ]
