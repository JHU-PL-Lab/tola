open Langs.Lang_yelu
open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      ylet "math" (ytval "MathFunctions");
      ylet "sqrt" (ytval "SqrtLibrary");
      yc_add_library ~sources:[ ybare "MathFunctions.cxx" ] (yvar "math");
      yc_option ~value:(ybool true)
        ~msg:"Use tutorial provided math implementation" (ycvar "USE_MYMATH");
      yifthen (Ycond_cvar (ycvar "USE_MYMATH"))
        (ycmd_of_list
           [
             yc_target_compile_definitions (yvar "math")
               [ ytarget_def ~kind:Private [ yraw "USE_MYMATH" ] ];
             yc_add_library ~type_:Lib_static ~sources:[ ybare "mysqrt.cxx" ]
               (yvar "sqrt");
             yc_target_link_libraries [ yvar "math" ]
               [ ytarget_def ~kind:Private [ yvar "sqrt" ] ];
           ]);
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
