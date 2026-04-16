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
        (yc_set (ycstr "FOO") [ ystr_raw "hello" ]);
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
           [ ytarget_def ~kind:Private [ ystr_raw "USE_MYMATH" ] ]);
      check "target_include_directories"
        "target_include_directories(Tutorial PUBLIC \"${PROJECT_BINARY_DIR}\")"
        (include_dirs (ytval "Tutorial")
           [ ytarget_def [ ystr_raw "${PROJECT_BINARY_DIR}" ] ]);
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
      check "list_join"
        "list(JOIN MY_LIST , OUT)\n"
        (yc_list_join (ycstr "MY_LIST") (ystr ",") "OUT");
      check "list_sublist"
        "list(SUBLIST MY_LIST 1 2 OUT)\n"
        (yc_list_sublist (ycstr "MY_LIST") 1 2 "OUT");
      check "list_find"
        "list(FIND MY_LIST val OUT)\n"
        (yc_list_find (ycstr "MY_LIST") (ystr "val") "OUT");
      check "list_prepend"
        "list(PREPEND MY_LIST a b)\n"
        (yc_list_prepend (ycstr "MY_LIST") [ ystr "a"; ystr "b" ]);
      check "list_insert"
        "list(INSERT MY_LIST 0 x)\n"
        (yc_list_insert (ycstr "MY_LIST") 0 [ ystr "x" ]);
      check "list_remove_at"
        "list(REMOVE_AT MY_LIST 0 2)\n"
        (yc_list_remove_at (ycstr "MY_LIST") [ 0; 2 ]);
      check "list_pop_back no out"
        "list(POP_BACK MY_LIST)\n"
        (yc_list_pop_back (ycstr "MY_LIST"));
      check "list_pop_front with out"
        "list(POP_FRONT MY_LIST X)\n"
        (yc_list_pop_front ~out_vars:[ "X" ] (ycstr "MY_LIST"));
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
      check "string_append"
        "string(APPEND VAR a b)"
        (yc_string_append (ycstr "VAR") [ ystr "a"; ystr "b" ]);
      check "string_prepend"
        "string(PREPEND VAR pfx)"
        (yc_string_prepend (ycstr "VAR") [ ystr "pfx" ]);
      check "string_join"
        "string(JOIN , OUT a b)"
        (yc_string_join (ystr ",") "OUT" [ ystr "a"; ystr "b" ]);
      check "string_find"
        "string(FIND hello ell OUT)"
        (yc_string_find (ystr "hello") (ystr "ell") "OUT");
      check "string_find reverse"
        "string(FIND hello ell OUT REVERSE)"
        (yc_string_find ~reverse:true (ystr "hello") (ystr "ell") "OUT");
      check "string_substring"
        "string(SUBSTRING hello 1 3 OUT)"
        (yc_string_substring (ystr "hello") 1 ~length:3 "OUT");
      check "string_repeat"
        "string(REPEAT abc 3 OUT)"
        (yc_string_repeat (ystr "abc") 3 "OUT");
      check "string_genex_strip"
        "string(GENEX_STRIP src OUT)"
        (yc_string_genex_strip (ystr "src") "OUT");
      check "string_compare equal"
        "string(COMPARE EQUAL a b OUT)"
        (yc_string_compare Sco_equal (ystr "a") (ystr "b") "OUT");
      check "string_compare less"
        "string(COMPARE LESS a b OUT)"
        (yc_string_compare Sco_less (ystr "a") (ystr "b") "OUT");
      check "string_make_c_identifier"
        "string(MAKE_C_IDENTIFIER hello OUT)"
        (yc_string_make_c_identifier (ystr "hello") "OUT");
      check "string_timestamp plain"
        "string(TIMESTAMP OUT)"
        (yc_string_timestamp "OUT");
      check "string_timestamp utc format"
        "string(TIMESTAMP OUT \"%Y-%m-%d\" UTC)"
        (yc_string_timestamp ~utc:true ~format:"%Y-%m-%d" "OUT");
    ] )

let scripting_ext =
  ( "scripting_ext",
    [
      check "get_filename_component name"
        "get_filename_component(OUT myfile.txt NAME)"
        (yc_get_filename_component ~mode:"NAME" (ycstr "OUT") (ystr "myfile.txt"));
      check "get_filename_component path"
        "get_filename_component(OUT /a/b/c.txt PATH)"
        (yc_get_filename_component ~mode:"PATH" (ycstr "OUT") (ystr "/a/b/c.txt"));
      check "include_guard directory"
        "include_guard(DIRECTORY)"
        (yc_include_guard Ig_directory);
      check "include_guard global"
        "include_guard(GLOBAL)"
        (yc_include_guard Ig_global);
      check "separate_arguments unix"
        "separate_arguments(VAR UNIX_COMMAND)"
        (yc_separate_arguments ~mode:Sa_unix_command (ycstr "VAR"));
      check "target_link_options"
        "target_link_options(mytarget PUBLIC -Wl,--gc-sections)"
        (yc_target_link_options (ytval "mytarget")
           [ ytarget_def ~kind:Public [ ystr "-Wl,--gc-sections" ] ]);
      check "target_link_options before"
        "target_link_options(mytarget BEFORE PRIVATE -flag)"
        (yc_target_link_options ~before:true (ytval "mytarget")
           [ ytarget_def ~kind:Private [ ystr "-flag" ] ]);
      check "target_sources"
        "target_sources(mytarget PRIVATE src/a.cpp)"
        (yc_target_sources (ytval "mytarget")
           [ ytarget_def ~kind:Private [ yfile "src/a.cpp" ] ]);
    ] )

let () =
  Alcotest.run "Yelu Compile"
    [ primitives; conditions; targets; project_level; composition; let_bindings;
      iteration; loop_control; list_ops; string_ops; scripting_ext ]
