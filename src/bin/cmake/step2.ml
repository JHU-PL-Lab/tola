open Langs.Lang_cmake
open Langs.Lang_cmake_utils
open Langs.Lang_cmake_pp

let cmd =
  cmd_of_list
    [
      minimum_required_s ~max:"3.20." "3.20.";
      project ~version:(version_of_string "1.0.") "Tutorial";
      set (Var "CMAKE_CXX_STANDARD") [ str_ "11" ];
      set (Var "CMAKE_CXX_STANDARD_REQUIRED") [ bool_ true ];
      configure_file ~input:"TutorialConfig.h.in" "TutorialConfig.h";
      add_subdirectory "MathFunctions";
      add_executable ~sources:[ "tutorial.cxx" ] "Tutorial";
      target_link_libraries [ Target "Tutorial" ]
        [ target_def [ ivar "MathFunctions" ] ];
      target_include_directories (Target "Tutorial")
        [
          target_def
            [
              istr "${PROJECT_BINARY_DIR}";
              istr "${PROJECT_SOURCE_DIR}/MathFunctions";
            ];
        ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) cmd
