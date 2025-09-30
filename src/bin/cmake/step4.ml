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
      (* set (Var "CMAKE_CXX_STANDARD") [ str_ "11" ];
         set (Var "CMAKE_CXX_STANDARD_REQUIRED") [ bool_ true ]; *)
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
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) cmd
