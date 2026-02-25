open Langs.Lang_yelu_utils
open Step_common

let cmd =
  ycmd_of_list
    (project_preamble
    @ cxx_standard_11
    @ [
        ylet "tut" (ytval "Tutorial");
        configure_tutorial_header;
        yc_add_executable ~sources:[ yfile "tutorial.cxx" ] (yvar "tut");
        yc_target_include_directories (yvar "tut")
          [ ytarget_def [ yraw "${PROJECT_BINARY_DIR}" ] ];
      ])

let () = print_cmake cmd
