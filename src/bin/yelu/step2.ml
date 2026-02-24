open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yminimum_required_s ~max:"3.20." "3.20.";
      yproject ~version:(Langs.Lang_cmake_utils.version_of_string "1.0.") "Tutorial";
      yset (yvar "CMAKE_CXX_STANDARD") [ ystr "11" ];
      yset (yvar "CMAKE_CXX_STANDARD_REQUIRED") [ ybool true ];
      yconfigure_file ~input:"TutorialConfig.h.in" "TutorialConfig.h";
      yadd_subdirectory "MathFunctions";
      yadd_executable ~sources:[ "tutorial.cxx" ] (ytarget "Tutorial");
      ytarget_link_libraries [ ytarget "Tutorial" ]
        [ ytarget_def [ yivar "MathFunctions" ] ];
      ytarget_include_directories (ytarget "Tutorial")
        [
          ytarget_def
            [
              yistr "${PROJECT_BINARY_DIR}";
              yistr "${PROJECT_SOURCE_DIR}/MathFunctions";
            ];
        ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile cmd)
