open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yinclude (yistr "release/CPackConfig.cmake");
      yset (yvar "CPACK_INSTALL_CMAKE_PROJECTS")
        [ yquote "debug;Tutorial;ALL;/"; yquote "release;Tutorial;ALL;/" ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile cmd)
