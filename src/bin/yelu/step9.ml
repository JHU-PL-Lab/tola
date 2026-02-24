open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      ylet "tut" (ytval "Tutorial");
      ylet "flags" (ytval "tutorial_compiler_flags");
      yc_minimum_required_s ~max:"3.20." "3.20.";
      yc_project ~version:(Langs.Lang_cmake_utils.version_of_string "1.0.") "Tutorial";
      yc_add_library ~type_:Lib_interface (yvar "flags");
      yc_target_compile_features (yvar "flags")
        [ ytarget_feature ~kind:Interface "cxx_std_11" ];
      yc_set (ycvar "gcc_like_cxx")
        [ yraw "$<COMPILE_LANG_AND_ID:CXX,ARMClang,AppleClang,Clang,GNU,LCC>" ];
      yc_set (ycvar "msvc_cxx") [ yraw "$<COMPILE_LANG_AND_ID:CXX,MSVC>" ];
      yc_target_compile_options (yvar "flags")
        [
          ytarget_def ~kind:Interface
            [
              yraw
                "$<${gcc_like_cxx}:-Wall;-Wextra;-Wshadow;-Wformat=2;-Wunused>";
              yraw "$<${msvc_cxx}:-W3>";
            ];
        ];
      yc_target_compile_options (yvar "flags")
        [
          ytarget_def ~kind:Interface
            [
              yraw
                "$<${gcc_like_cxx}:$<BUILD_INTERFACE:-Wall;-Wextra;-Wshadow;-Wformat=2;-Wunused>>";
              yraw "$<${msvc_cxx}:$<BUILD_INTERFACE:-W3>>";
            ];
        ];
      yc_configure_file ~input:(ybare "TutorialConfig.h.in") (ybare "TutorialConfig.h");
      yc_add_subdirectory (ybare "MathFunctions");
      yc_add_executable ~sources:[ ybare "tutorial.cxx" ] (yvar "tut");
      yc_target_link_libraries [ yvar "tut" ]
        [ ytarget_def [ ytval "MathFunctions"; yvar "flags" ] ];
      yc_target_include_directories (yvar "tut")
        [ ytarget_def [ yraw "${PROJECT_BINARY_DIR}" ] ];
      yc_install_targets [ yvar "tut" ] (ybare "bin");
      yc_install_files
        [ yraw "${PROJECT_BINARY_DIR}/TutorialConfig.h" ]
        (ybare "include");
      yc_include (ybare "CTest");
      yc_add_test (ybare "Runs") (ybare "Tutorial") [ ybare "25" ];
      yc_add_test (ybare "Usage") (ybare "Tutorial") [];
      yc_set_tests_properties [ ybare "Usage" ]
        [ ("PASS_REGULAR_EXPRESSION", yraw "Usage:.*number") ];
      yc_add_test (ybare "StandardUse") (ybare "Tutorial") [ ybare "4" ];
      yc_set_tests_properties [ ybare "Usage" ]
        [ ("PASS_REGULAR_EXPRESSION", yraw "4 is 2") ];
      yc_function (ycvar "do_test")
        [ "target"; "arg"; "result" ]
        [
          yc_add_test (ybare "Comp${arg}") (ybare "${target}") [ ybare "${arg}" ];
          yc_set_tests_properties [ ybare "Comp${arg}" ]
            [ ("PASS_REGULAR_EXPRESSION", ybare "${result}") ];
        ];
      yc_apply (ycvar "do_test") [ yvar "tut"; ybare "4"; yraw "4 is 2" ];
      yc_apply (ycvar "do_test") [ yvar "tut"; ybare "9"; yraw "9 is 3" ];
      yc_apply (ycvar "do_test") [ yvar "tut"; ybare "5"; yraw "5 is 2.236" ];
      yc_apply (ycvar "do_test") [ yvar "tut"; ybare "7"; yraw "7 is 2.645" ];
      yc_apply (ycvar "do_test") [ yvar "tut"; ybare "25"; yraw "25 is 5" ];
      yc_apply (ycvar "do_test")
        [ yvar "tut"; ybare "-25"; yraw "-25 is (-nan|nan|0)" ];
      yc_apply (ycvar "do_test")
        [ yvar "tut"; ybare "0.0001"; yraw "0.0001 is 0.01" ];
      yc_include (ybare "InstallRequiredSystemLibraries");
      yc_set (ycvar "CPACK_RESOURCE_FILE_LICENSE")
        [ yraw "${CMAKE_CURRENT_SOURCE_DIR}/License.txt" ];
      yc_set (ycvar "CPACK_PACKAGE_VERSION_MAJOR")
        [ yraw "${Tutorial_VERSION_MAJOR}" ];
      yc_set (ycvar "CPACK_PACKAGE_VERSION_MINOR")
        [ yraw "${Tutorial_VERSION_MINOR}" ];
      yc_set (ycvar "CPACK_GENERATOR") [ yraw "TGZ" ];
      yc_set (ycvar "CPACK_SOURCE_GENERATOR") [ yraw "TGZ" ];
      yc_include (ybare "CPack");
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
