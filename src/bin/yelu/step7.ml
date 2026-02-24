open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yminimum_required_s ~max:"3.20." "3.20.";
      yproject ~version:(Langs.Lang_cmake_utils.version_of_string "1.0.") "Tutorial";
      yadd_library ~type_:Lib_interface (ytarget "tutorial_compiler_flags");
      ytarget_compile_features (ytarget "tutorial_compiler_flags")
        [ ytarget_feature ~kind:Interface "cxx_std_11" ];
      yset (yvar "gcc_like_cxx")
        [ yraw "$<COMPILE_LANG_AND_ID:CXX,ARMClang,AppleClang,Clang,GNU,LCC>" ];
      yset (yvar "msvc_cxx") [ yraw "$<COMPILE_LANG_AND_ID:CXX,MSVC>" ];
      ytarget_compile_options (ytarget "tutorial_compiler_flags")
        [
          ytarget_def ~kind:Interface
            [
              yraw
                "$<${gcc_like_cxx}:-Wall;-Wextra;-Wshadow;-Wformat=2;-Wunused>";
              yraw "$<${msvc_cxx}:-W3>";
            ];
        ];
      ytarget_compile_options (ytarget "tutorial_compiler_flags")
        [
          ytarget_def ~kind:Interface
            [
              yraw
                "$<${gcc_like_cxx}:$<BUILD_INTERFACE:-Wall;-Wextra;-Wshadow;-Wformat=2;-Wunused>>";
              yraw "$<${msvc_cxx}:$<BUILD_INTERFACE:-W3>>";
            ];
        ];
      yconfigure_file ~input:"TutorialConfig.h.in" "TutorialConfig.h";
      yadd_subdirectory "MathFunctions";
      yadd_executable ~sources:[ "tutorial.cxx" ] (ytarget "Tutorial");
      ytarget_link_libraries [ ytarget "Tutorial" ]
        [ ytarget_def [ ytval "MathFunctions"; ytval "tutorial_compiler_flags" ] ];
      ytarget_include_directories (ytarget "Tutorial")
        [ ytarget_def [ yraw "${PROJECT_BINARY_DIR}" ] ];
      yinstall_targets [ ytarget "Tutorial" ] (ybare "bin");
      yinstall_files
        [ yraw "${PROJECT_BINARY_DIR}/TutorialConfig.h" ]
        (ybare "include");
      yinclude (ybare "CTest");
      yadd_test "Runs" "Tutorial" [ "25" ];
      yadd_test "Usage" "Tutorial" [];
      yset_tests_properties [ "Usage" ]
        [ ("PASS_REGULAR_EXPRESSION", yraw "Usage:.*number") ];
      yadd_test "StandardUse" "Tutorial" [ "4" ];
      yset_tests_properties [ "Usage" ]
        [ ("PASS_REGULAR_EXPRESSION", yraw "4 is 2") ];
      yfunction (yvar "do_test")
        [ "target"; "arg"; "result" ]
        [
          yadd_test "Comp${arg}" "${target}" [ "${arg}" ];
          yset_tests_properties [ "Comp${arg}" ]
            [ ("PASS_REGULAR_EXPRESSION", ybare "${result}") ];
        ];
      yapply (yvar "do_test") [ ytval "Tutorial"; ybare "4"; yraw "4 is 2" ];
      yapply (yvar "do_test") [ ytval "Tutorial"; ybare "9"; yraw "9 is 3" ];
      yapply (yvar "do_test") [ ytval "Tutorial"; ybare "5"; yraw "5 is 2.236" ];
      yapply (yvar "do_test") [ ytval "Tutorial"; ybare "7"; yraw "7 is 2.645" ];
      yapply (yvar "do_test") [ ytval "Tutorial"; ybare "25"; yraw "25 is 5" ];
      yapply (yvar "do_test")
        [ ytval "Tutorial"; ybare "-25"; yraw "-25 is (-nan|nan|0)" ];
      yapply (yvar "do_test")
        [ ytval "Tutorial"; ybare "0.0001"; yraw "0.0001 is 0.01" ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
