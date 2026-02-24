open Langs.Lang_yelu
open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yextern_target "tutorial_compiler_flags";
      yadd_library ~sources:[ "MathFunctions.cxx" ] (ytarget "MathFunctions");
      ytarget_include_directories (ytarget "MathFunctions")
        [ ytarget_def ~kind:Interface [ ybare "${CMAKE_CURRENT_SOURCE_DIR}" ] ];
      yoption ~value:(ybool true)
        ~msg:"Use tutorial provided math implementation" (yvar "USE_MYMATH");
      yifthen (Ycond_var (yvar "USE_MYMATH"))
        (ycmd_of_list
           [
             ytarget_compile_definitions (ytarget "MathFunctions")
               [ ytarget_def ~kind:Private [ yraw "USE_MYMATH" ] ];
             yadd_library ~type_:Lib_static ~sources:[ "mysqrt.cxx" ]
               (ytarget "SqrtLibrary");
             ytarget_link_libraries [ ytarget "SqrtLibrary" ]
               [ ytarget_def ~kind:Public [ ytval "tutorial_compiler_flags" ] ];
             ytarget_link_libraries [ ytarget "MathFunctions" ]
               [ ytarget_def ~kind:Private [ ytval "SqrtLibrary" ] ];
           ]);
      ytarget_link_libraries [ ytarget "MathFunctions" ]
        [ ytarget_def ~kind:Public [ ytval "tutorial_compiler_flags" ] ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
