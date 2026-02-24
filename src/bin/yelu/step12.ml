open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yminimum_required_s ~max:"3.20." "3.20.";
      yproject ~version:(Langs.Lang_cmake_utils.version_of_string "1.0.") "Tutorial";
      yset (yvar "CMAKE_ARCHIVE_OUTPUT_DIRECTORY")
        [ yquote "${PROJECT_BINARY_DIR}" ];
      yset (yvar "CMAKE_LIBRARY_OUTPUT_DIRECTORY")
        [ yquote "${PROJECT_BINARY_DIR}" ];
      yset (yvar "CMAKE_RUNTIME_OUTPUT_DIRECTORY")
        [ yquote "${PROJECT_BINARY_DIR}" ];
      yoption ~value:(ybool true) ~msg:"Build using shared libraries"
        (yvar "BUILD_SHARED_LIBS");
      yset (yvar "CMAKE_DEBUG_POSTFIX") [ yquote "d" ];
      yadd_library ~type_:Lib_interface (ytarget "tutorial_compiler_flags");
      ytarget_compile_features (ytarget "tutorial_compiler_flags")
        [ ytarget_feature ~kind:Interface "cxx_std_11" ];
      yset (yvar "gcc_like_cxx")
        [ yquote "$<COMPILE_LANG_AND_ID:CXX,ARMClang,AppleClang,Clang,GNU,LCC>" ];
      yset (yvar "msvc_cxx") [ yquote "$<COMPILE_LANG_AND_ID:CXX,MSVC>" ];
      ytarget_compile_options (ytarget "tutorial_compiler_flags")
        [
          ytarget_def ~kind:Interface
            [
              yistr
                "$<${gcc_like_cxx}:-Wall;-Wextra;-Wshadow;-Wformat=2;-Wunused>";
              yistr "$<${msvc_cxx}:-W3>";
            ];
        ];
      ytarget_compile_options (ytarget "tutorial_compiler_flags")
        [
          ytarget_def ~kind:Interface
            [
              yistr
                "$<${gcc_like_cxx}:$<BUILD_INTERFACE:-Wall;-Wextra;-Wshadow;-Wformat=2;-Wunused>>";
              yistr "$<${msvc_cxx}:$<BUILD_INTERFACE:-W3>>";
            ];
        ];
      yconfigure_file ~input:"TutorialConfig.h.in" "TutorialConfig.h";
      yadd_subdirectory "MathFunctions";
      yadd_executable ~sources:[ "tutorial.cxx" ] (ytarget "Tutorial");
      yset_target_properties (ytarget "Tutorial")
        [ ("DEBUG_POSTFIX", ystr "${CMAKE_DEBUG_POSTFIX}") ];
      ytarget_link_libraries [ ytarget "Tutorial" ]
        [ ytarget_def [ yivar "MathFunctions"; yivar "tutorial_compiler_flags" ] ];
      ytarget_include_directories (ytarget "Tutorial")
        [ ytarget_def [ yistr "${PROJECT_BINARY_DIR}" ] ];
      yinstall_targets [ ytarget "Tutorial" ] (yivar "bin");
      yinstall_files
        [ yistr "${PROJECT_BINARY_DIR}/TutorialConfig.h" ]
        (yivar "include");
      yinclude (yivar "CTest");
      yadd_test "Runs" "Tutorial" [ "25" ];
      yadd_test "Usage" "Tutorial" [];
      yset_tests_properties [ "Usage" ]
        [ ("PASS_REGULAR_EXPRESSION", yquote "Usage:.*number") ];
      yadd_test "StandardUse" "Tutorial" [ "4" ];
      yset_tests_properties [ "Usage" ]
        [ ("PASS_REGULAR_EXPRESSION", yquote "4 is 2") ];
      yfunction (yvar "do_test")
        [ "target"; "arg"; "result" ]
        [
          yadd_test "Comp${arg}" "${target}" [ "${arg}" ];
          yset_tests_properties [ "Comp${arg}" ]
            [ ("PASS_REGULAR_EXPRESSION", ystr "${result}") ];
        ];
      yapply (yvar "do_test") [ ystr "Tutorial"; ystr "4"; yquote "4 is 2" ];
      yapply (yvar "do_test") [ ystr "Tutorial"; ystr "9"; yquote "9 is 3" ];
      yapply (yvar "do_test") [ ystr "Tutorial"; ystr "5"; yquote "5 is 2.236" ];
      yapply (yvar "do_test") [ ystr "Tutorial"; ystr "7"; yquote "7 is 2.645" ];
      yapply (yvar "do_test") [ ystr "Tutorial"; ystr "25"; yquote "25 is 5" ];
      yapply (yvar "do_test")
        [ ystr "Tutorial"; ystr "-25"; yquote "-25 is (-nan|nan|0)" ];
      yapply (yvar "do_test")
        [ ystr "Tutorial"; ystr "0.0001"; yquote "0.0001 is 0.01" ];
      yinclude (yivar "InstallRequiredSystemLibraries");
      yset (yvar "CPACK_RESOURCE_FILE_LICENSE")
        [ yquote "${CMAKE_CURRENT_SOURCE_DIR}/License.txt" ];
      yset (yvar "CPACK_PACKAGE_VERSION_MAJOR")
        [ yquote "${Tutorial_VERSION_MAJOR}" ];
      yset (yvar "CPACK_PACKAGE_VERSION_MINOR")
        [ yquote "${Tutorial_VERSION_MINOR}" ];
      yset (yvar "CPACK_GENERATOR") [ yquote "TGZ" ];
      yset (yvar "CPACK_SOURCE_GENERATOR") [ yquote "TGZ" ];
      yinclude (yivar "CPack");
      yinstall_export
        ~file:(yivar "MathFunctionsTargets.cmake")
        (yivar "MathFunctionsTargets")
        (yivar "lib/cmake/MathFunctions");
      yinclude (yivar "CMakePackageConfigHelpers");
      yconfigure_package_config_file ~no_set_and_check_macro:true
        ~no_check_required_components_macro:true
        (yistr "lib/cmake/MathFunctions")
        (yivar "${CMAKE_CURRENT_SOURCE_DIR}/Config.cmake.in")
        (yistr "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfig.cmake");
      ywrite_basic_package_version_file ~compatibility:Any_newer_version
        ~version:(yistr "${Tutorial_VERSION_MAJOR}.${Tutorial_VERSION_MINOR}")
        (yistr "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfigVersion.cmake");
      yinstall_files
        [
          yivar "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfig.cmake";
          yivar "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfigVersion.cmake";
        ]
        (yivar "lib/cmake/MathFunctions");
      yinstall_export
        ~file:(yivar "MathFunctionsTargets.cmake")
        (yivar "MathFunctionsTargets")
        (yivar "lib/cmake/MathFunctions");
      yexport_export "MathFunctionsTargets"
        ~file:(yistr "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsTargets.cmake");
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile cmd)
