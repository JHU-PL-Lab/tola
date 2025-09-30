open Langs.Lang_cmake
open Langs.Lang_cmake_utils
open Langs.Lang_cmake_pp

let cmd =
  cmd_of_list
    [
      include_ (istr "release/CPackConfig.cmake");
      set (Var "CPACK_INSTALL_CMAKE_PROJECTS")
        [ quote "debug;Tutorial;ALL;/"; quote "release;Tutorial;ALL;/" ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) cmd
