open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yc_minimum_required_s ~max:"3.20." "3.20.";
      yc_project ~version:(Langs.Lang_cmake_utils.version_of_string "1.0.") "Tutorial";
      yc_add_library ~type_:Lib_interface (ytarget "tutorial_compiler_flags");
      yc_target_compile_features (ytarget "tutorial_compiler_flags")
        [ ytarget_feature ~kind:Interface "cxx_std_11" ];
      yc_set (ycvar "CMAKE_CXX_STANDARD") [ ybare "11" ];
      yc_set (ycvar "CMAKE_CXX_STANDARD_REQUIRED") [ ybool true ];
      yc_configure_file ~input:(ybare "TutorialConfig.h.in") (ybare "TutorialConfig.h");
      yc_add_subdirectory (ybare "MathFunctions");
      yc_add_executable ~sources:[ ybare "tutorial.cxx" ] (ytarget "Tutorial");
      yc_target_link_libraries [ ytarget "Tutorial" ]
        [ ytarget_def [ ytval "MathFunctions"; ytval "tutorial_compiler_flags" ] ];
      yc_target_include_directories (ytarget "Tutorial")
        [ ytarget_def [ yraw "${PROJECT_BINARY_DIR}" ] ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
