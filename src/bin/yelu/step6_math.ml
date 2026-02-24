open Langs.Lang_yelu
open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
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
             yadd_library ~type_:Lib_static ~sources:[ "mysqrt.cxx" ]
               (ytarget "SqrtLibrary");
             ytarget_link_libraries [ ytarget "SqrtLibrary" ]
               [ ytarget_def ~kind:Public [ yivar "tutorial_compiler_flags" ] ];
             ytarget_link_libraries [ ytarget "MathFunctions" ]
               [ ytarget_def ~kind:Private [ yivar "SqrtLibrary" ] ];
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
