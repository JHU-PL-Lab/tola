open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yc_set (ycvar "CTEST_PROJECT_NAME") [ yraw "CMakeTutorial" ];
      yc_set (ycvar "CTEST_NIGHTLY_START_TIME") [ yraw "00:00:00 EST" ];
      yc_set (ycvar "CTEST_DROP_METHOD") [ yraw "http" ];
      yc_set (ycvar "CTEST_DROP_SITE") [ yraw "my.cdash.org" ];
      yc_set (ycvar "CTEST_DROP_LOCATION")
        [ yraw "/submit.php?project=CMakeTutorial" ];
      yc_set (ycvar "CTEST_DROP_SITE_CDASH") [ ybare "TRUE" ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
