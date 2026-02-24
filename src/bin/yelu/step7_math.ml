open Langs.Lang_yelu
open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      ylet "flags" (ytval "tutorial_compiler_flags");
      ylet "math" (ytval "MathFunctions");
      ylet "sqrt" (ytval "SqrtLibrary");
      yc_extern_target "tutorial_compiler_flags";
      yc_add_library ~sources:[ ybare "MathFunctions.cxx" ] (yvar "math");
      yc_target_include_directories (yvar "math")
        [ ytarget_def ~kind:Interface [ ybare "${CMAKE_CURRENT_SOURCE_DIR}" ] ];
      yc_option ~value:(ybool true)
        ~msg:"Use tutorial provided math implementation" (ycvar "USE_MYMATH");
      yifthen (Ycond_cvar (ycvar "USE_MYMATH"))
        (ycmd_of_list
           [
             yc_target_compile_definitions (yvar "math")
               [ ytarget_def ~kind:Private [ yraw "USE_MYMATH" ] ];
             yc_add_library ~type_:Lib_static ~sources:[ ybare "mysqrt.cxx" ]
               (yvar "sqrt");
             yc_target_link_libraries [ yvar "sqrt" ]
               [ ytarget_def ~kind:Public [ yvar "flags" ] ];
             yc_include (ybare "CheckCXXSourceCompiles");
             yc_apply (ycvar "check_cxx_source_compiles")
               [
                 yraw
                   "\n\
                   \  #include <cmath>\n\
                   \  int main() {\n\
                   \    std::log(1.0);\n\
                   \    return 0;\n\
                   \  }";
                 ybare "HAVE_LOG";
               ];
             yc_apply (ycvar "check_cxx_source_compiles")
               [
                 yraw
                   "\n\
                   \  #include <cmath>\n\
                   \  int main() {\n\
                   \    std::exp(1.0);\n\
                   \    return 0;\n\
                   \  }";
                 ybare "HAVE_EXP";
               ];
             yifthen
               (Yand (Ycond_cvar (ycvar "HAVE_LOG"), Ycond_cvar (ycvar "HAVE_EXP")))
               (yc_target_compile_definitions (yvar "sqrt")
                  [
                    ytarget_def ~kind:Private
                      [ yraw "HAVE_LOG"; yraw "HAVE_EXP" ];
                  ]);
             yc_target_link_libraries [ yvar "math" ]
               [ ytarget_def ~kind:Private [ yvar "sqrt" ] ];
           ]);
      yc_target_link_libraries [ yvar "math" ]
        [ ytarget_def ~kind:Public [ yvar "flags" ] ];
      yc_set (ycvar "installable_libs")
        [ yvar "math"; yvar "flags" ];
      yifthen (Yis_target (ytarget "SqrtLibrary"))
        (ycmd_of_list
           [ yc_list_append (ycvar "installable_libs") [ yvar "sqrt" ] ]);
      yc_install_targets [ ytval "${installable_libs}" ] (ybare "lib");
      yc_install_files [ yraw "MathFunctions.h" ] (ybare "include");
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
