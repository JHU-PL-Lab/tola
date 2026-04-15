open Yelu_langs.Lang_yelu_utils
open Step_common

let cmd =
  ycmd_of_list
    [
      yc_include (yraw "release/CPackConfig.cmake");
      yc_set (ycstr "CPACK_INSTALL_CMAKE_PROJECTS")
        [ yraw "debug;Tutorial;ALL;/"; yraw "release;Tutorial;ALL;/" ];
    ]

let () = print_cmake cmd
