open Langs.Lang_yelu
open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yinclude (yivar "MakeTable.cmake");
      yadd_library ~sources:[ "MathFunctions.cxx" ] (ytarget "MathFunctions");
      ytarget_include_directories (ytarget "MathFunctions")
        [ ytarget_def ~kind:Interface [ yivar "${CMAKE_CURRENT_SOURCE_DIR}" ] ];
      yoption ~value:(ybool true)
        ~msg:"Use tutorial provided math implementation" (yvar "USE_MYMATH");
      yifthen (Ycond_var (yvar "USE_MYMATH"))
        (ycmd_of_list
           [
             ytarget_compile_definitions (ytarget "MathFunctions")
               [ ytarget_def ~kind:Private [ yistr "USE_MYMATH" ] ];
             yadd_library ~type_:Lib_static
               ~sources:[ "mysqrt.cxx"; "${CMAKE_CURRENT_BINARY_DIR}/Table.h" ]
               (ytarget "SqrtLibrary");
             ytarget_include_directories (ytarget "SqrtLibrary")
               [
                 ytarget_def ~kind:Private [ yivar "${CMAKE_CURRENT_BINARY_DIR}" ];
               ];
             yset_target_properties (ytarget "SqrtLibrary")
               [ ("POSITION_INDEPENDENT_CODE", ystr "${BUILD_SHARED_LIBS}") ];
             ytarget_link_libraries [ ytarget "SqrtLibrary" ]
               [ ytarget_def ~kind:Public [ yivar "tutorial_compiler_flags" ] ];
             yinclude (yivar "CheckCXXSourceCompiles");
             yapply (yvar "check_cxx_source_compiles")
               [
                 yquote
                   "\n\
                   \  #include <cmath>\n\
                   \  int main() {\n\
                   \    std::log(1.0);\n\
                   \    return 0;\n\
                   \  }";
                 ystr "HAVE_LOG";
               ];
             yapply (yvar "check_cxx_source_compiles")
               [
                 yquote
                   "\n\
                   \  #include <cmath>\n\
                   \  int main() {\n\
                   \    std::exp(1.0);\n\
                   \    return 0;\n\
                   \  }";
                 ystr "HAVE_EXP";
               ];
             yifthen
               (Yand (Ycond_var (yvar "HAVE_LOG"), Ycond_var (yvar "HAVE_EXP")))
               (ytarget_compile_definitions (ytarget "SqrtLibrary")
                  [
                    ytarget_def ~kind:Private
                      [ yistr "HAVE_LOG"; yistr "HAVE_EXP" ];
                  ]);
             ytarget_link_libraries [ ytarget "MathFunctions" ]
               [ ytarget_def ~kind:Private [ yivar "SqrtLibrary" ] ];
             ytarget_compile_definitions (ytarget "MathFunctions")
               [ ytarget_def ~kind:Private [ yistr "EXPORTING_MYMATH" ] ];
           ]);
      ytarget_link_libraries [ ytarget "MathFunctions" ]
        [ ytarget_def ~kind:Public [ yivar "tutorial_compiler_flags" ] ];
      yset (yvar "installable_libs")
        [ ystr "MathFunctions"; ystr "tutorial_compiler_flags" ];
      yifthen (Yis_target (ytarget "SqrtLibrary"))
        (ycmd_of_list
           [ ylist_append (yvar "installable_libs") [ ystr "SqrtLibrary" ] ]);
      yinstall_targets [ ytarget "${installable_libs}" ] (yivar "lib");
      yinstall_files [ yistr "MathFunctions.h" ] (yivar "include");
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile cmd)
