open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yc_quote_cmd "@PACKAGE_INIT@";
      yc_include (yraw "${CMAKE_CURRENT_LIST_DIR}/MathFunctionsTargets.cmake");
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
