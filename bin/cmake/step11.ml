open Langs.Lang_cmake
open Langs.Lang_cmake_utils
open Langs.Lang_cmake_pp

let cmd =
  cmd_of_list
    [
      minimum_required_s ~max:"3.20." "3.20.";
      project ~version:(version_of_string "1.0.") "Tutorial";
      set (Var "CMAKE_ARCHIVE_OUTPUT_DIRECTORY")
        [ quote "${PROJECT_BINARY_DIR}" ];
      set (Var "CMAKE_LIBRARY_OUTPUT_DIRECTORY")
        [ quote "${PROJECT_BINARY_DIR}" ];
      set (Var "CMAKE_RUNTIME_OUTPUT_DIRECTORY")
        [ quote "${PROJECT_BINARY_DIR}" ];
      option_ ~value:(bool_ true) ~msg:"Build using shared libraries"
        (Var "BUILD_SHARED_LIBS");
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
      include_ (ivar "CTest");
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
      include_ (ivar "InstallRequiredSystemLibraries");
      set (Var "CPACK_RESOURCE_FILE_LICENSE")
        [ quote "${CMAKE_CURRENT_SOURCE_DIR}/License.txt" ];
      set (Var "CPACK_PACKAGE_VERSION_MAJOR")
        [ quote "${Tutorial_VERSION_MAJOR}" ];
      set (Var "CPACK_PACKAGE_VERSION_MINOR")
        [ quote "${Tutorial_VERSION_MINOR}" ];
      set (Var "CPACK_GENERATOR") [ quote "TGZ" ];
      set (Var "CPACK_SOURCE_GENERATOR") [ quote "TGZ" ];
      include_ (ivar "CPack");
      install_export
        ~file:(ivar "MathFunctionsTargets.cmake")
        (ivar "MathFunctionsTargets")
        (ivar "lib/cmake/MathFunctions");
      include_ (ivar "CMakePackageConfigHelpers");
      configure_package_config_file ~no_set_and_check_macro:true
        ~no_check_required_components_macro:true
        (istr "lib/cmake/MathFunctions")
        (ivar "${CMAKE_CURRENT_SOURCE_DIR}/Config.cmake.in")
        (istr "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfig.cmake");
      write_basic_package_version_file ~compatibility:Any_newer_version
        ~version:(istr "${Tutorial_VERSION_MAJOR}.${Tutorial_VERSION_MINOR}")
        (istr "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfigVersion.cmake");
      install_files
        [
          ivar "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfig.cmake";
          ivar "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfigVersion.cmake";
        ]
        (ivar "lib/cmake/MathFunctions");
      install_export
        ~file:(ivar "MathFunctionsTargets.cmake")
        (ivar "MathFunctionsTargets")
        (ivar "lib/cmake/MathFunctions");
      export_export "MathFunctionsTargets"
        ~file:(istr "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsTargets.cmake");
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) cmd
