open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yset (yvar "CTEST_PROJECT_NAME") [ yraw "CMakeTutorial" ];
      yset (yvar "CTEST_NIGHTLY_START_TIME") [ yraw "00:00:00 EST" ];
      yset (yvar "CTEST_DROP_METHOD") [ yraw "http" ];
      yset (yvar "CTEST_DROP_SITE") [ yraw "my.cdash.org" ];
      yset (yvar "CTEST_DROP_LOCATION")
        [ yraw "/submit.php?project=CMakeTutorial" ];
      yset (yvar "CTEST_DROP_SITE_CDASH") [ ybare "TRUE" ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
