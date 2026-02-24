open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yset (yvar "CTEST_PROJECT_NAME") [ yquote "CMakeTutorial" ];
      yset (yvar "CTEST_NIGHTLY_START_TIME") [ yquote "00:00:00 EST" ];
      yset (yvar "CTEST_DROP_METHOD") [ yquote "http" ];
      yset (yvar "CTEST_DROP_SITE") [ yquote "my.cdash.org" ];
      yset (yvar "CTEST_DROP_LOCATION")
        [ yquote "/submit.php?project=CMakeTutorial" ];
      yset (yvar "CTEST_DROP_SITE_CDASH") [ ystr "TRUE" ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile cmd)
