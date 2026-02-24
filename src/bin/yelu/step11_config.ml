open Langs.Lang_yelu_utils
open Step_common

let cmd =
  ycmd_of_list
    [
      yc_quote_cmd "@PACKAGE_INIT@";
      yc_include (yraw "${CMAKE_CURRENT_LIST_DIR}/MathFunctionsTargets.cmake");
    ]

let () = print_cmake cmd
