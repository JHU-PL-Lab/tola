open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yinclude (yraw "release/CPackConfig.cmake");
      yset (ycvar "CPACK_INSTALL_CMAKE_PROJECTS")
        [ yraw "debug;Tutorial;ALL;/"; yraw "release;Tutorial;ALL;/" ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
