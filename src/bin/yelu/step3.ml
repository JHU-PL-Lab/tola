open Langs.Lang_yelu_utils
open Step_common

let cmd =
  ycmd_of_list
    (project_preamble
    @ [
        ylet "tut" (ytval "Tutorial");
        ylet "flags" (ytval "tutorial_compiler_flags");
      ]
    @ compiler_flags_lib @ cxx_standard_11
    @ [
        configure_tutorial_header;
        yc_add_subdirectory (ydir "MathFunctions");
        yc_add_executable ~sources:[ yfile "tutorial.cxx" ] (yvar "tut");
        yc_target_link_libraries
          [ yvar "tut" ]
          [ ytarget_def [ ytval "MathFunctions"; yvar "flags" ] ];
        yc_target_include_directories (yvar "tut")
          [ ytarget_def [ yraw "${PROJECT_BINARY_DIR}" ] ];
      ])

let () = print_cmake cmd
