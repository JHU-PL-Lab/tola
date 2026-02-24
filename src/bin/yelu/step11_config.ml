open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yquote_cmd "@PACKAGE_INIT@";
      yinclude (yistr "${CMAKE_CURRENT_LIST_DIR}/MathFunctionsTargets.cmake");
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile cmd)
