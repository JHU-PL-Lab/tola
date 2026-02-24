open Langs.Lang_cmake
open Langs.Lang_cmake_utils
open Langs.Lang_cmake_pp

(* Print a single AST node to string (no trailing newline) *)
let pp_to_string ast = Fmt.str "%a" pp ast

(* Print via vbox (for Exp_list / multi-statement) *)
let pp_vbox_to_string ast = Fmt.str "%a" (Fmt.vbox pp) ast

let check name expected ast =
  Alcotest.test_case name `Quick (fun () ->
      Alcotest.(check string) name expected (pp_to_string ast))

let check_vbox name expected ast =
  Alcotest.test_case name `Quick (fun () ->
      Alcotest.(check string) name expected (pp_vbox_to_string ast))

(* --- Test groups --- *)

let primitives =
  ( "primitives",
    [
      check "set var" "set(FOO bar )" (set "FOO" [ str_ "bar" ]);
      check "set quoted"
        "set(FOO \"hello\" )"
        (set "FOO" [ quote "hello" ]);
      check "set bool"
        "set(FOO ON )"
        (set "FOO" [ bool_ true ]);
      (* Fmt.sp break hints break at top level (no enclosing box);
         in vbox context (real usage), these also break onto separate lines *)
      check "set multiple"
        "set(SRCS a.cpp\nb.cpp )"
        (set "SRCS" [ str_ "a.cpp"; str_ "b.cpp" ]);
      check "set parent_scope"
        "set(X val PARENT_SCOPE)"
        (set ~parent_scope:true "X" [ str_ "val" ]);
      check "include"
        "include(CheckCXXSourceCompiles)"
        (include_ (str_ "CheckCXXSourceCompiles"));
      check "include optional"
        "include(foo OPTIONAL )"
        (include_ ~optional:true (str_ "foo"));
    ] )

let conditions =
  ( "conditions",
    [
      check "if cond_var"
        "if (USE_MYMATH)\n  set(X 1 )\nelse()\n  \nendif()\n"
        (ifthen [ "USE_MYMATH" ] (set "X" [ str_ "1" ]));
      check "if with else"
        "if (USE_MYMATH)\n  set(X 1 )\nelse()\n  set(X 0 )\nendif()\n"
        (if_ [ "USE_MYMATH" ]
           (set "X" [ str_ "1" ])
           (set "X" [ str_ "0" ]));
      check "if and"
        "if (HAVE_LOG AND HAVE_EXP)\n  break()\nelse()\n  \nendif()\n"
        (ifthen [ "HAVE_LOG"; "AND"; "HAVE_EXP" ] Break);
      check "if not"
        "if (NOT DEFINED)\n  break()\nelse()\n  \nendif()\n"
        (ifthen [ "NOT"; "DEFINED" ] Break);
      check "if or"
        "if (A OR B)\n  break()\nelse()\n  \nendif()\n"
        (ifthen [ "A"; "OR"; "B" ] Break);
      check "is_target"
        "if (TARGET SqrtLibrary)\n  break()\nelse()\n  \nendif()\n"
        (ifthen [ "TARGET"; "SqrtLibrary" ] Break);
      check "is_defined"
        "if (DEFINED MY_VAR)\n  break()\nelse()\n  \nendif()\n"
        (ifthen [ "DEFINED"; "MY_VAR" ] Break);
      check "in_list"
        "if (x IN_LIST mylist)\n  break()\nelse()\n  \nendif()\n"
        (ifthen [ "x"; "IN_LIST"; "mylist" ] Break);
    ] )

let control_flow =
  ( "control_flow",
    [
      check "break" "break()" Break;
      check "continue" "continue()" Continue;
      check "return empty" "return()" (Return { propogate_vars = [] });
      check "return propagate"
        "return(PROPAGATE X\nY )"
        (Return { propogate_vars = [ "X"; "Y" ] });
      check "while"
        "while(X)\n  break()\nendwhile()"
        (While { cond = [ "X" ]; commands = Break });
      check "foreach empty"
        "foreach(item)\nendforeach()"
        (Foreach { loop_var = "item" });
      check "foreach_range"
        "foreach(i RANGE  0 10)\nendforeach()"
        (Foreach_range
           {
             loop_var = "i";
             start = Some "0";
             stop = "10";
             step = None;
           });
      check "foreach_in"
        "foreach(f IN LISTS FILES)\nendforeach()"
        (Foreach_in
           {
             loop_var = "f";
             lists = [ "FILES" ];
             step = None;
           });
    ] )

let functions_macros =
  ( "functions_macros",
    [
      check "function"
        "function(do_test target arg\nresult)\n  break()\nendfunction()\n"
        (function_ "do_test" [ "target"; "arg"; "result" ] [ Break ]);
      check "apply"
        "do_test(Tutorial 4\n\"4 is 2\")\n"
        (apply "do_test"
           [ str_ "Tutorial"; str_ "4"; quote "4 is 2" ]);
      check "macro"
        "macro(my_macro A\nB)\n  break()\nendmacro()\n"
        (Macro
           {
             name = "my_macro";
             args = [ "A"; "B" ];
             commands = Break;
           });
      check "list_append"
        "list(APPEND my_list a\nb)\n"
        (list_append "my_list" [ str_ "a"; str_ "b" ]);
    ] )

let targets =
  ( "targets",
    [
      check "add_library"
        "add_library(MathFunctions  MathFunctions.cxx)"
        (add_library "MathFunctions" ~sources:[ "MathFunctions.cxx" ]);
      check "add_library static"
        "add_library(SqrtLibrary STATIC mysqrt.cxx)"
        (add_library "SqrtLibrary" ~type_:"STATIC"
           ~sources:[ "mysqrt.cxx" ]);
      check "add_library interface"
        "add_library(flags INTERFACE )"
        (add_library "flags" ~type_:"INTERFACE");
      check "add_executable"
        "add_executable(Tutorial tutorial.cxx)"
        (add_executable ~sources:[ "tutorial.cxx" ] "Tutorial");
      check "target_link_libraries"
        "target_link_libraries(Tutorial PUBLIC MathFunctions)"
        (target_link_libraries [ "Tutorial" ]
           [ target_def [ str_ "MathFunctions" ] ]);
      check "target_link_libraries private"
        "target_link_libraries(MathFunctions PRIVATE SqrtLibrary)"
        (target_link_libraries [ "MathFunctions" ]
           [ target_def ~kind:"PRIVATE" [ str_ "SqrtLibrary" ] ]);
      check "target_compile_definitions"
        "target_compile_definitions(MathFunctions PRIVATE \"USE_MYMATH\")"
        (target_compile_definitions "MathFunctions"
           [ target_def ~kind:"PRIVATE" [ quote "USE_MYMATH" ] ]);
      check "target_include_directories"
        "target_include_directories(Tutorial PUBLIC \"${PROJECT_BINARY_DIR}\")"
        (target_include_directories "Tutorial"
           [ target_def [ quote "${PROJECT_BINARY_DIR}" ] ]);
      check "target_compile_features"
        "target_compile_features(flags INTERFACE cxx_std_11)"
        (target_compile_features "flags"
           [ target_feature ~kind:"INTERFACE" "cxx_std_11" ]);
    ] )

let install =
  ( "install",
    [
      check "install_targets"
        "install(TARGETS Tutorial  DESTINATION bin)"
        (install_targets [ "Tutorial" ] (str_ "bin"));
      check "install_files"
        "install(FILES \"MathFunctions.h\" DESTINATION include)"
        (install_files [ quote "MathFunctions.h" ] (str_ "include"));
    ] )

let project_level =
  ( "project_level",
    [
      check "cmake_minimum_required"
        "cmake_minimum_required(VERSION 3.20)"
        (minimum_required_s "3.20.");
      check "project"
        "project(Tutorial VERSION 1.0)"
        (project ~version:(version_of_string "1.0.") "Tutorial");
      check "project no version"
        "project(MyApp )"
        (project "MyApp");
      check "configure_file"
        "configure_file(TutorialConfig.h.in TutorialConfig.h)"
        (configure_file ~input:"TutorialConfig.h.in" "TutorialConfig.h");
      check "add_subdirectory"
        "add_subdirectory(MathFunctions)"
        (add_subdirectory "MathFunctions");
      check "add_test"
        "add_test(NAME Runs COMMAND Tutorial 25)"
        (add_test "Runs" "Tutorial" [ "25" ]);
      check "enable_testing" "enable_testing()" enable_testing;
    ] )

let composition =
  ( "composition",
    [
      check_vbox "exp_list two stmts"
        "set(X 1 )\nset(Y 2 )"
        (cmd_of_list
           [ set "X" [ str_ "1" ]; set "Y" [ str_ "2" ] ]);
      check_vbox "minimal project"
        "cmake_minimum_required(VERSION 3.20)\n\
         project(Hello )\n\
         add_executable(Hello hello.cxx)"
        (cmd_of_list
           [
             minimum_required_s "3.20.";
             project "Hello";
             add_executable ~sources:[ "hello.cxx" ] "Hello";
           ]);
    ] )

let () =
  Alcotest.run "CMake PP"
    [
      primitives;
      conditions;
      control_flow;
      functions_macros;
      targets;
      install;
      project_level;
      composition;
    ]
