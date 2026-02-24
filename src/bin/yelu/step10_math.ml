open Langs.Lang_yelu
open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yextern_target "tutorial_compiler_flags";
      yinclude (ybare "MakeTable.cmake");
      yadd_library ~sources:[ ybare "MathFunctions.cxx" ] (ytarget "MathFunctions");
      ytarget_include_directories (ytarget "MathFunctions")
        [ ytarget_def ~kind:Interface [ ybare "${CMAKE_CURRENT_SOURCE_DIR}" ] ];
      yoption ~value:(ybool true)
        ~msg:"Use tutorial provided math implementation" (ycvar "USE_MYMATH");
      yifthen (Ycond_cvar (ycvar "USE_MYMATH"))
        (ycmd_of_list
           [
             ytarget_compile_definitions (ytarget "MathFunctions")
               [ ytarget_def ~kind:Private [ yraw "USE_MYMATH" ] ];
             yadd_library ~type_:Lib_static
               ~sources:[ ybare "mysqrt.cxx"; ybare "${CMAKE_CURRENT_BINARY_DIR}/Table.h" ]
               (ytarget "SqrtLibrary");
             ytarget_include_directories (ytarget "SqrtLibrary")
               [
                 ytarget_def ~kind:Private [ ybare "${CMAKE_CURRENT_BINARY_DIR}" ];
               ];
             yset_target_properties (ytarget "SqrtLibrary")
               [ ("POSITION_INDEPENDENT_CODE", ybare "${BUILD_SHARED_LIBS}") ];
             ytarget_link_libraries [ ytarget "SqrtLibrary" ]
               [ ytarget_def ~kind:Public [ ytval "tutorial_compiler_flags" ] ];
             yinclude (ybare "CheckCXXSourceCompiles");
             yapply (ycvar "check_cxx_source_compiles")
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
             yapply (ycvar "check_cxx_source_compiles")
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
               (ytarget_compile_definitions (ytarget "SqrtLibrary")
                  [
                    ytarget_def ~kind:Private
                      [ yraw "HAVE_LOG"; yraw "HAVE_EXP" ];
                  ]);
             ytarget_link_libraries [ ytarget "MathFunctions" ]
               [ ytarget_def ~kind:Private [ ytval "SqrtLibrary" ] ];
             ytarget_compile_definitions (ytarget "MathFunctions")
               [ ytarget_def ~kind:Private [ yraw "EXPORTING_MYMATH" ] ];
           ]);
      ytarget_link_libraries [ ytarget "MathFunctions" ]
        [ ytarget_def ~kind:Public [ ytval "tutorial_compiler_flags" ] ];
      yset (ycvar "installable_libs")
        [ ytval "MathFunctions"; ytval "tutorial_compiler_flags" ];
      yifthen (Yis_target (ytarget "SqrtLibrary"))
        (ycmd_of_list
           [ ylist_append (ycvar "installable_libs") [ ytval "SqrtLibrary" ] ]);
      yinstall_targets [ ytarget "${installable_libs}" ] (ybare "lib");
      yinstall_files [ yraw "MathFunctions.h" ] (ybare "include");
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
