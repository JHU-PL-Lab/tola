open Langs.Lang_cmake
open Langs.Lang_cmake_utils
open Langs.Lang_cmake_pp

let cmd =
  cmd_of_list
    [
      include_ (ivar "MakeTable.cmake");
      add_library "MathFunctions" ~sources:[ "MathFunctions.cxx" ];
      target_include_directories (Target "MathFunctions")
        [ target_def ~kind:Interface [ ivar "${CMAKE_CURRENT_SOURCE_DIR}" ] ];
      option_ ~value:(bool_ true)
        ~msg:"Use tutorial provided math implementation" (Var "USE_MYMATH");
      ifthen (Cond_var "USE_MYMATH")
        (cmd_of_list
           [
             target_compile_definitions (Target "MathFunctions")
               [ target_def ~kind:Private [ istr "USE_MYMATH" ] ];
             add_library "SqrtLibrary" ~type_:Lib_static
               ~sources:[ "mysqrt.cxx"; "${CMAKE_CURRENT_BINARY_DIR}/Table.h" ];
             target_include_directories (Target "SqrtLibrary")
               [
                 target_def ~kind:Private [ ivar "${CMAKE_CURRENT_BINARY_DIR}" ];
               ];
             target_link_libraries [ Target "SqrtLibrary" ]
               [ target_def ~kind:Public [ ivar "tutorial_compiler_flags" ] ];
             include_ (ivar "CheckCXXSourceCompiles");
             apply (Var "check_cxx_source_compiles")
               [
                 quote
                   "\n\
                   \  #include <cmath>\n\
                   \  int main() {\n\
                   \    std::log(1.0);\n\
                   \    return 0;\n\
                   \  }";
                 str_ "HAVE_LOG";
               ];
             apply (Var "check_cxx_source_compiles")
               [
                 quote
                   "\n\
                   \  #include <cmath>\n\
                   \  int main() {\n\
                   \    std::exp(1.0);\n\
                   \    return 0;\n\
                   \  }";
                 str_ "HAVE_EXP";
               ];
             ifthen
               (And (Cond_var "HAVE_LOG", Cond_var "HAVE_EXP"))
               (target_compile_definitions (Target "SqrtLibrary")
                  [
                    target_def ~kind:Private
                      [ istr "HAVE_LOG"; istr "HAVE_EXP" ];
                  ]);
             target_link_libraries [ Target "MathFunctions" ]
               [ target_def ~kind:Private [ ivar "SqrtLibrary" ] ];
           ]);
      target_link_libraries [ Target "MathFunctions" ]
        [ target_def ~kind:Public [ ivar "tutorial_compiler_flags" ] ];
      set (Var "installable_libs")
        [ str_ "MathFunctions"; str_ "tutorial_compiler_flags" ];
      ifthen (Is_target "SqrtLibrary")
        (cmd_of_list
           [ list_append (Var "installable_libs") [ str_ "SqrtLibrary" ] ]);
      install_targets [ Target "${installable_libs}" ] (ivar "lib");
      install_files [ istr "MathFunctions.h" ] (ivar "include");
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) cmd
