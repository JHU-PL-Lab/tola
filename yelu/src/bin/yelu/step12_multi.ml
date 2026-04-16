open Yelu_langs.Lang_yelu_utils
open Step_common

let cmd =
  ycmd_of_list
    [
      yc_include (ystr_raw "release/CPackConfig.cmake");
      yc_set (ycstr "CPACK_INSTALL_CMAKE_PROJECTS")
        [ ystr_raw "debug;Tutorial;ALL;/"; ystr_raw "release;Tutorial;ALL;/" ];
    ]

let () = print_cmake cmd
