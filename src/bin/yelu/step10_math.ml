open Langs.Lang_yelu
open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yc_extern_target "tutorial_compiler_flags";
      yc_include (ybare "MakeTable.cmake");
      yc_add_library ~sources:[ ybare "MathFunctions.cxx" ] (ytarget "MathFunctions");
      yc_target_include_directories (ytarget "MathFunctions")
        [ ytarget_def ~kind:Interface [ ybare "${CMAKE_CURRENT_SOURCE_DIR}" ] ];
      yc_option ~value:(ybool true)
        ~msg:"Use tutorial provided math implementation" (ycvar "USE_MYMATH");
      yifthen (Ycond_cvar (ycvar "USE_MYMATH"))
        (ycmd_of_list
           [
             yc_target_compile_definitions (ytarget "MathFunctions")
               [ ytarget_def ~kind:Private [ yraw "USE_MYMATH" ] ];
             yc_add_library ~type_:Lib_static
               ~sources:[ ybare "mysqrt.cxx"; ybare "${CMAKE_CURRENT_BINARY_DIR}/Table.h" ]
               (ytarget "SqrtLibrary");
             yc_target_include_directories (ytarget "SqrtLibrary")
               [
                 ytarget_def ~kind:Private [ ybare "${CMAKE_CURRENT_BINARY_DIR}" ];
               ];
             yc_set_target_properties (ytarget "SqrtLibrary")
               [ ("POSITION_INDEPENDENT_CODE", ybare "${BUILD_SHARED_LIBS}") ];
             yc_target_link_libraries [ ytarget "SqrtLibrary" ]
               [ ytarget_def ~kind:Public [ ytval "tutorial_compiler_flags" ] ];
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
               (yc_target_compile_definitions (ytarget "SqrtLibrary")
                  [
                    ytarget_def ~kind:Private
                      [ yraw "HAVE_LOG"; yraw "HAVE_EXP" ];
                  ]);
             yc_target_link_libraries [ ytarget "MathFunctions" ]
               [ ytarget_def ~kind:Private [ ytval "SqrtLibrary" ] ];
             yc_target_compile_definitions (ytarget "MathFunctions")
               [ ytarget_def ~kind:Private [ yraw "EXPORTING_MYMATH" ] ];
           ]);
      yc_target_link_libraries [ ytarget "MathFunctions" ]
        [ ytarget_def ~kind:Public [ ytval "tutorial_compiler_flags" ] ];
      yc_set (ycvar "installable_libs")
        [ ytval "MathFunctions"; ytval "tutorial_compiler_flags" ];
      yifthen (Yis_target (ytarget "SqrtLibrary"))
        (ycmd_of_list
           [ yc_list_append (ycvar "installable_libs") [ ytval "SqrtLibrary" ] ]);
      yc_install_targets [ ytarget "${installable_libs}" ] (ybare "lib");
      yc_install_files [ yraw "MathFunctions.h" ] (ybare "include");
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
