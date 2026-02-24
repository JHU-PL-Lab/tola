open Langs.Lang_yelu_utils
open Step_common

let cmd =
  ycmd_of_list
    ([
       ylet "tut" (ytval "Tutorial");
       ylet "flags" (ytval "tutorial_compiler_flags");
       ylet "do_test" (ycstr "do_test");
     ]
    @ project_preamble
    @ shared_libs_output_dirs
    @ [ yc_set (ycstr "CMAKE_DEBUG_POSTFIX") [ yraw "d" ] ]
    @ compiler_flags_lib
    @ compiler_warning_options
    @ [
        configure_tutorial_header;
        yc_add_subdirectory (ybare "MathFunctions");
        yc_add_executable ~sources:[ ybare "tutorial.cxx" ] (yvar "tut");
        yc_set_target_properties (yvar "tut")
          [ ("DEBUG_POSTFIX", ybare "${CMAKE_DEBUG_POSTFIX}") ];
        yc_target_link_libraries
          [ yvar "tut" ]
          [ ytarget_def [ ytval "MathFunctions"; yvar "flags" ] ];
        yc_target_include_directories (yvar "tut")
          [ ytarget_def [ yraw "${PROJECT_BINARY_DIR}" ] ];
      ]
    @ install_tutorial
    @ test_suite ~ctest:true
    @ cpack_basic
    @ [
        yc_install_export
          ~file:(ybare "MathFunctionsTargets.cmake")
          (ybare "MathFunctionsTargets")
          (ybare "lib/cmake/MathFunctions");
        yc_include (ybare "CMakePackageConfigHelpers");
        yc_configure_package_config_file ~no_set_and_check_macro:true
          ~no_check_required_components_macro:true
          (yraw "lib/cmake/MathFunctions")
          (ybare "${CMAKE_CURRENT_SOURCE_DIR}/Config.cmake.in")
          (yraw "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfig.cmake");
        yc_write_basic_package_version_file ~compatibility:Any_newer_version
          ~version:(yraw "${Tutorial_VERSION_MAJOR}.${Tutorial_VERSION_MINOR}")
          (yraw "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfigVersion.cmake");
        yc_install_files
          [
            ybare "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfig.cmake";
            ybare "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsConfigVersion.cmake";
          ]
          (ybare "lib/cmake/MathFunctions");
        yc_install_export
          ~file:(ybare "MathFunctionsTargets.cmake")
          (ybare "MathFunctionsTargets")
          (ybare "lib/cmake/MathFunctions");
        yc_export_export
          (ybare "MathFunctionsTargets")
          ~file:(yraw "${CMAKE_CURRENT_BINARY_DIR}/MathFunctionsTargets.cmake");
      ])

let () = print_cmake cmd
