open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yminimum_required_s ~max:"3.20." "3.20.";
      yproject ~version:(Langs.Lang_cmake_utils.version_of_string "1.0.") "Tutorial";
      yset (ycvar "CMAKE_ARCHIVE_OUTPUT_DIRECTORY")
        [ yraw "${PROJECT_BINARY_DIR}" ];
      yset (ycvar "CMAKE_LIBRARY_OUTPUT_DIRECTORY")
        [ yraw "${PROJECT_BINARY_DIR}" ];
      yset (ycvar "CMAKE_RUNTIME_OUTPUT_DIRECTORY")
        [ yraw "${PROJECT_BINARY_DIR}" ];
      yoption ~value:(ybool true) ~msg:"Build using shared libraries"
        (ycvar "BUILD_SHARED_LIBS");
      yadd_library ~type_:Lib_interface (ytarget "tutorial_compiler_flags");
      ytarget_compile_features (ytarget "tutorial_compiler_flags")
        [ ytarget_feature ~kind:Interface "cxx_std_11" ];
      yset (ycvar "gcc_like_cxx")
        [ yraw "$<COMPILE_LANG_AND_ID:CXX,ARMClang,AppleClang,Clang,GNU,LCC>" ];
      yset (ycvar "msvc_cxx") [ yraw "$<COMPILE_LANG_AND_ID:CXX,MSVC>" ];
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
      yconfigure_file ~input:(ybare "TutorialConfig.h.in") (ybare "TutorialConfig.h");
      yadd_subdirectory (ybare "MathFunctions");
      yadd_executable ~sources:[ ybare "tutorial.cxx" ] (ytarget "Tutorial");
      ytarget_link_libraries [ ytarget "Tutorial" ]
        [ ytarget_def [ ytval "MathFunctions"; ytval "tutorial_compiler_flags" ] ];
      ytarget_include_directories (ytarget "Tutorial")
        [ ytarget_def [ yraw "${PROJECT_BINARY_DIR}" ] ];
      yinstall_targets [ ytarget "Tutorial" ] (ybare "bin");
      yinstall_files
        [ yraw "${PROJECT_BINARY_DIR}/TutorialConfig.h" ]
        (ybare "include");
      yinclude (ybare "CTest");
      yadd_test (ybare "Runs") (ybare "Tutorial") [ ybare "25" ];
      yadd_test (ybare "Usage") (ybare "Tutorial") [];
      yset_tests_properties [ ybare "Usage" ]
        [ ("PASS_REGULAR_EXPRESSION", yraw "Usage:.*number") ];
      yadd_test (ybare "StandardUse") (ybare "Tutorial") [ ybare "4" ];
      yset_tests_properties [ ybare "Usage" ]
        [ ("PASS_REGULAR_EXPRESSION", yraw "4 is 2") ];
      yfunction (ycvar "do_test")
        [ "target"; "arg"; "result" ]
        [
          yadd_test (ybare "Comp${arg}") (ybare "${target}") [ ybare "${arg}" ];
          yset_tests_properties [ ybare "Comp${arg}" ]
            [ ("PASS_REGULAR_EXPRESSION", ybare "${result}") ];
        ];
      yapply (ycvar "do_test") [ ytval "Tutorial"; ybare "4"; yraw "4 is 2" ];
      yapply (ycvar "do_test") [ ytval "Tutorial"; ybare "9"; yraw "9 is 3" ];
      yapply (ycvar "do_test") [ ytval "Tutorial"; ybare "5"; yraw "5 is 2.236" ];
      yapply (ycvar "do_test") [ ytval "Tutorial"; ybare "7"; yraw "7 is 2.645" ];
      yapply (ycvar "do_test") [ ytval "Tutorial"; ybare "25"; yraw "25 is 5" ];
      yapply (ycvar "do_test")
        [ ytval "Tutorial"; ybare "-25"; yraw "-25 is (-nan|nan|0)" ];
      yapply (ycvar "do_test")
        [ ytval "Tutorial"; ybare "0.0001"; yraw "0.0001 is 0.01" ];
      yinclude (ybare "InstallRequiredSystemLibraries");
      yset (ycvar "CPACK_RESOURCE_FILE_LICENSE")
        [ yraw "${CMAKE_CURRENT_SOURCE_DIR}/License.txt" ];
      yset (ycvar "CPACK_PACKAGE_VERSION_MAJOR")
        [ yraw "${Tutorial_VERSION_MAJOR}" ];
      yset (ycvar "CPACK_PACKAGE_VERSION_MINOR")
        [ yraw "${Tutorial_VERSION_MINOR}" ];
      yset (ycvar "CPACK_GENERATOR") [ yraw "TGZ" ];
      yset (ycvar "CPACK_SOURCE_GENERATOR") [ yraw "TGZ" ];
      yinclude (ybare "CPack");
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
