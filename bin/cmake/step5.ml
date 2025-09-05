open Langs.Lang_cmake
open Langs.Lang_cmake_utils
open Langs.Lang_cmake_pp

let cmd =
  cmd_of_list
    [
      minimum_required_s ~max:"3.20." "3.20.";
      project ~version:(version_of_string "1.0.") "Tutorial";
      add_library "tutorial_compiler_flags" ~type_:Lib_interface;
      target_compile_features (Target "tutorial_compiler_flags")
        [ target_feature ~kind:Interface (Feature "cxx_std_11") ];
      set (Var "gcc_like_cxx")
        [ quote "$<COMPILE_LANG_AND_ID:CXX,ARMClang,AppleClang,Clang,GNU,LCC>" ];
      set (Var "msvc_cxx") [ quote "$<COMPILE_LANG_AND_ID:CXX,MSVC>" ];
      target_compile_options (Target "tutorial_compiler_flags")
        [
          target_def ~kind:Interface
            [
              istr
                "$<${gcc_like_cxx}:-Wall;-Wextra;-Wshadow;-Wformat=2;-Wunused>";
              istr "$<${msvc_cxx}:-W3>";
            ];
        ];
      target_compile_options (Target "tutorial_compiler_flags")
        [
          target_def ~kind:Interface
            [
              istr
                "$<${gcc_like_cxx}:$<BUILD_INTERFACE:-Wall;-Wextra;-Wshadow;-Wformat=2;-Wunused>>";
              istr "$<${msvc_cxx}:$<BUILD_INTERFACE:-W3>>";
            ];
        ];
      configure_file ~input:"TutorialConfig.h.in" "TutorialConfig.h";
      add_subdirectory "MathFunctions";
      add_executable ~sources:[ "tutorial.cxx" ] "Tutorial";
      target_link_libraries [ Target "Tutorial" ]
        [ target_def [ ivar "MathFunctions"; ivar "tutorial_compiler_flags" ] ];
      target_include_directories (Target "Tutorial")
        [ target_def [ istr "${PROJECT_BINARY_DIR}" ] ];
      install_targets [ Target "Tutorial" ] (ivar "bin");
      install_files
        [ istr "${PROJECT_BINARY_DIR}/TutorialConfig.h" ]
        (ivar "include");
      enable_testing;
      add_test "Runs" "Tutorial" [ "25" ];
      add_test "Usage" "Tutorial" [];
      set_tests_properties [ "Usage" ]
        [ ("PASS_REGULAR_EXPRESSION", quote "Usage:.*number") ];
      add_test "StandardUse" "Tutorial" [ "4" ];
      set_tests_properties [ "Usage" ]
        [ ("PASS_REGULAR_EXPRESSION", quote "4 is 2") ];
      function_ (Var "do_test")
        [ "target"; "arg"; "result" ]
        [
          add_test "Comp${arg}" "${target}" [ "${arg}" ];
          set_tests_properties [ "Comp${arg}" ]
            [ ("PASS_REGULAR_EXPRESSION", str_ "${result}") ];
        ];
      apply (Var "do_test") [ str_ "Tutorial"; str_ "4"; quote "4 is 2" ];
      apply (Var "do_test") [ str_ "Tutorial"; str_ "9"; quote "9 is 3" ];
      apply (Var "do_test") [ str_ "Tutorial"; str_ "5"; quote "5 is 2.236" ];
      apply (Var "do_test") [ str_ "Tutorial"; str_ "7"; quote "7 is 2.645" ];
      apply (Var "do_test") [ str_ "Tutorial"; str_ "25"; quote "25 is 5" ];
      apply (Var "do_test")
        [ str_ "Tutorial"; str_ "-25"; quote "-25 is (-nan|nan|0)" ];
      apply (Var "do_test")
        [ str_ "Tutorial"; str_ "0.0001"; quote "0.0001 is 0.01" ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) cmd
