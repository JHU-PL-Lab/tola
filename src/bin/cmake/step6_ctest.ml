open Langs.Lang_cmake
open Langs.Lang_cmake_utils
open Langs.Lang_cmake_pp

let cmd =
  cmd_of_list
    [
      set (Var "CTEST_PROJECT_NAME") [ quote "CMakeTutorial" ];
      set (Var "CTEST_NIGHTLY_START_TIME") [ quote "00:00:00 EST" ];
      set (Var "CTEST_DROP_METHOD") [ quote "http" ];
      set (Var "CTEST_DROP_SITE") [ quote "my.cdash.org" ];
      set (Var "CTEST_DROP_LOCATION")
        [ quote "/submit.php?project=CMakeTutorial" ];
      set (Var "CTEST_DROP_SITE_CDASH") [ str_ "TRUE" ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) cmd
