open Langs.Lang_yelu_utils
open Step_common

let cmd =
  ycmd_of_list
    ([
       ylet "tut" (ytval "Tutorial");
       ylet "flags" (ytval "tutorial_compiler_flags");
       ylet "do_test" (ycstr "do_test");
       yc_minimum_required_s ~max:"3.20." "3.20.";
       yc_project ~version:(Langs.Lang_cmake_utils.version_of_string "1.0.") "Tutorial";
     ]
    @ compiler_flags_lib
    @ compiler_warning_options
    @ [
        configure_tutorial_header;
        yc_add_subdirectory (ybare "MathFunctions");
        yc_add_executable ~sources:[ ybare "tutorial.cxx" ] (yvar "tut");
        yc_target_link_libraries [ yvar "tut" ]
          [ ytarget_def [ ytval "MathFunctions"; yvar "flags" ] ];
        yc_target_include_directories (yvar "tut")
          [ ytarget_def [ yraw "${PROJECT_BINARY_DIR}" ] ];
      ]
    @ install_tutorial
    @ test_suite ~ctest:true
    @ cpack_basic)

let () = print_cmake cmd
