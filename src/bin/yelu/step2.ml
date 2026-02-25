open Langs.Lang_yelu_utils
open Step_common

let cmd =
  ycmd_of_list
    (project_preamble
    @ cxx_standard_11
    @ [
        ylet "tut" (ytval "Tutorial");
        configure_tutorial_header;
        yc_add_subdirectory (ydir "MathFunctions");
        yc_add_executable ~sources:[ yfile "tutorial.cxx" ] (yvar "tut");
        yc_target_link_libraries
          [ yvar "tut" ]
          [ ytarget_def [ ytval "MathFunctions" ] ];
        yc_target_include_directories (yvar "tut")
          [
            ytarget_def
              [
                yraw "${PROJECT_BINARY_DIR}";
                yraw "${PROJECT_SOURCE_DIR}/MathFunctions";
              ];
          ];
      ])

let () = print_cmake cmd
