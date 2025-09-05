(* open Langs.Lang_cmake *)
open Langs.Lang_cmake_utils
open Langs.Lang_cmake_pp

let cmd =
  cmd_of_list
    [
      quote_cmd "@PACKAGE_INIT@";
      include_ (istr "${CMAKE_CURRENT_LIST_DIR}/MathFunctionsTargets.cmake");
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) cmd
