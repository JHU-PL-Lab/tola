(* Shared building blocks for yelu step programs.
   Blocks are [yelu_exp list] values, composed with [@] into [ycmd_of_list].
   [ylet] bindings stay in each step file to wire blocks together. *)
open Langs.Lang_yelu
open Langs.Lang_yelu_utils

(* --- Root CMakeLists blocks --- *)

(** cmake_minimum_required(VERSION 3.20) + project(Tutorial VERSION 1.0).
    Steps: 1-12. *)
let project_preamble =
  [
    yc_minimum_required_s ~max:"3.20." "3.20.";
    yc_project
      ~version:(Langs.Lang_cmake_utils.version_of_string "1.0.")
      "Tutorial";
  ]

(** set CMAKE_CXX_STANDARD=11, CMAKE_CXX_STANDARD_REQUIRED=true.
    Steps: 1-3. *)
let cxx_standard_11 =
  [
    yc_set (ycstr "CMAKE_CXX_STANDARD") [ ystr "11" ];
    yc_set (ycstr "CMAKE_CXX_STANDARD_REQUIRED") [ ybool true ];
  ]

(** INTERFACE library + cxx_std_11 compile feature.
    Requires: [yvar "flags"]. Steps: 3-12. *)
let compiler_flags_lib =
  [
    yc_add_library ~type_:Lib_interface (yvar "flags");
    yc_target_compile_features (yvar "flags")
      [ ytarget_feature ~kind:Interface "cxx_std_11" ];
  ]

(** gcc/msvc detection vars + compile warning options.
    Requires: [yvar "flags"]. Steps: 4-12. *)
let compiler_warning_options =
  [
    yc_set (ycstr "gcc_like_cxx")
      [ yraw "$<COMPILE_LANG_AND_ID:CXX,ARMClang,AppleClang,Clang,GNU,LCC>" ];
    yc_set (ycstr "msvc_cxx") [ yraw "$<COMPILE_LANG_AND_ID:CXX,MSVC>" ];
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
  ]

(** configure_file TutorialConfig.h.in -> TutorialConfig.h.
    Steps: 1-12. *)
let configure_tutorial_header =
  yc_configure_file ~input:(yfile "TutorialConfig.h.in") (yfile "TutorialConfig.h")

(** Install Tutorial binary + config header.
    Requires: [yvar "tut"]. Steps: 5-12. *)
let install_tutorial =
  [
    yc_install_targets [ yvar "tut" ] (ydir "bin");
    yc_install_files
      [ yraw "${PROJECT_BINARY_DIR}/TutorialConfig.h" ]
      (ydir "include");
  ]

(** Test suite: testing infrastructure + do_test function + invocations.
    Requires: [yvar "tut"], [yvar "do_test"].
    @param ctest if true uses include(CTest) (step6+), else enable_testing() (step5). *)
let test_suite ~ctest =
  [
    (if ctest then yc_include (yfile "CTest") else yc_enable_testing);
    yc_add_test (ystr "Runs") (ystr "Tutorial") [ ystr "25" ];
    yc_add_test (ystr "Usage") (ystr "Tutorial") [];
    yc_set_tests_properties [ ystr "Usage" ]
      [ ("PASS_REGULAR_EXPRESSION", yraw "Usage:.*number") ];
    yc_add_test (ystr "StandardUse") (ystr "Tutorial") [ ystr "4" ];
    yc_set_tests_properties [ ystr "Usage" ]
      [ ("PASS_REGULAR_EXPRESSION", yraw "4 is 2") ];
    yc_function (yvar "do_test")
      [ "target"; "arg"; "result" ]
      [
        yc_add_test (ystr "Comp${arg}") (ystr "${target}") [ ystr "${arg}" ];
        yc_set_tests_properties [ ystr "Comp${arg}" ]
          [ ("PASS_REGULAR_EXPRESSION", ystr "${result}") ];
      ];
    yc_apply (yvar "do_test") [ yvar "tut"; ystr "4"; yraw "4 is 2" ];
    yc_apply (yvar "do_test") [ yvar "tut"; ystr "9"; yraw "9 is 3" ];
    yc_apply (yvar "do_test") [ yvar "tut"; ystr "5"; yraw "5 is 2.236" ];
    yc_apply (yvar "do_test") [ yvar "tut"; ystr "7"; yraw "7 is 2.645" ];
    yc_apply (yvar "do_test") [ yvar "tut"; ystr "25"; yraw "25 is 5" ];
    yc_apply (yvar "do_test")
      [ yvar "tut"; ystr "-25"; yraw "-25 is (-nan|nan|0)" ];
    yc_apply (yvar "do_test")
      [ yvar "tut"; ystr "0.0001"; yraw "0.0001 is 0.01" ];
  ]

(** CPack configuration.
    Steps: 9-12. *)
let cpack_basic =
  [
    yc_include (yfile "InstallRequiredSystemLibraries");
    yc_set (ycstr "CPACK_RESOURCE_FILE_LICENSE")
      [ yraw "${CMAKE_CURRENT_SOURCE_DIR}/License.txt" ];
    yc_set (ycstr "CPACK_PACKAGE_VERSION_MAJOR")
      [ yraw "${Tutorial_VERSION_MAJOR}" ];
    yc_set (ycstr "CPACK_PACKAGE_VERSION_MINOR")
      [ yraw "${Tutorial_VERSION_MINOR}" ];
    yc_set (ycstr "CPACK_GENERATOR") [ yraw "TGZ" ];
    yc_set (ycstr "CPACK_SOURCE_GENERATOR") [ yraw "TGZ" ];
    yc_include (yfile "CPack");
  ]

(** Output directories + BUILD_SHARED_LIBS option.
    Steps: 10-12. *)
let shared_libs_output_dirs =
  [
    yc_set (ycstr "CMAKE_ARCHIVE_OUTPUT_DIRECTORY")
      [ yraw "${PROJECT_BINARY_DIR}" ];
    yc_set (ycstr "CMAKE_LIBRARY_OUTPUT_DIRECTORY")
      [ yraw "${PROJECT_BINARY_DIR}" ];
    yc_set (ycstr "CMAKE_RUNTIME_OUTPUT_DIRECTORY")
      [ yraw "${PROJECT_BINARY_DIR}" ];
    yc_option ~value:(ybool true) ~msg:"Build using shared libraries"
      (ycstr "BUILD_SHARED_LIBS");
  ]

(* --- MathFunctions blocks --- *)

(** CheckCXXSourceCompiles checks for log/exp + conditional define.
    Requires: [yvar "check_cxx"], [yvar "have_log"], [yvar "have_exp"],
    [yvar "sqrt"]. Steps: 7_math-12_math. *)
let math_check_cxx_features =
  [
    yc_include (yfile "CheckCXXSourceCompiles");
    yc_apply (yvar "check_cxx")
      [
        yraw
          "\n\
          \  #include <cmath>\n\
          \  int main() {\n\
          \    std::log(1.0);\n\
          \    return 0;\n\
          \  }";
        yvar "have_log";
      ];
    yc_apply (yvar "check_cxx")
      [
        yraw
          "\n\
          \  #include <cmath>\n\
          \  int main() {\n\
          \    std::exp(1.0);\n\
          \    return 0;\n\
          \  }";
        yvar "have_exp";
      ];
    yifthen
      (Yand (Ytruthy (yvar "have_log"), Ytruthy (yvar "have_exp")))
      (yc_target_compile_definitions (yvar "sqrt")
         [
           ytarget_def ~kind:Private [ yraw "HAVE_LOG"; yraw "HAVE_EXP" ];
         ]);
  ]

(** installable_libs set + conditional SqrtLibrary append + install.
    Requires: [yvar "inst_libs"], [yvar "math"], [yvar "flags"], [yvar "sqrt"].
    @param export optional export name for install(TARGETS ... EXPORT).
    Steps: 5_math-12_math. *)
let math_install_libs ?export () =
  [
    yc_set (yvar "inst_libs") [ yvar "math"; yvar "flags" ];
    yifthen (Yis_target (ytval "SqrtLibrary"))
      (ycmd_of_list [ yc_list_append (yvar "inst_libs") [ yvar "sqrt" ] ]);
    yc_install_targets ?export [ ytval "${installable_libs}" ] (ydir "lib");
    yc_install_files [ yraw "MathFunctions.h" ] (ydir "include");
  ]

(** Compile and print a yelu command to stdout as cmake. *)
let print_cmake cmd =
  Fmt.pr "%a" (Fmt.vbox Langs.Lang_cmake_pp.pp)
    (Langs.Lang_yelu_compile.compile Langs.Lang_yelu_compile.empty_env cmd
    |> snd)
