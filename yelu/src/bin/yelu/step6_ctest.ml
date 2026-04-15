open Yelu_langs.Lang_yelu_utils
open Step_common

let cmd =
  ycmd_of_list
    [
      yc_set (ycstr "CTEST_PROJECT_NAME") [ yraw "CMakeTutorial" ];
      yc_set (ycstr "CTEST_NIGHTLY_START_TIME") [ yraw "00:00:00 EST" ];
      yc_set (ycstr "CTEST_DROP_METHOD") [ yraw "http" ];
      yc_set (ycstr "CTEST_DROP_SITE") [ yraw "my.cdash.org" ];
      yc_set (ycstr "CTEST_DROP_LOCATION")
        [ yraw "/submit.php?project=CMakeTutorial" ];
      yc_set (ycstr "CTEST_DROP_SITE_CDASH") [ ystr "TRUE" ];
    ]

let () = print_cmake cmd
