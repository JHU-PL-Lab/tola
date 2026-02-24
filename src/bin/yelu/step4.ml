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
      ytarget_link_libraries [ ytarget "Tutorial" ]
        [ ytarget_def [ yivar "MathFunctions"; yivar "tutorial_compiler_flags" ] ];
      ytarget_include_directories (ytarget "Tutorial")
        [ ytarget_def [ yistr "${PROJECT_BINARY_DIR}" ] ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile cmd)
