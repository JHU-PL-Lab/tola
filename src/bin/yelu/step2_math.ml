open Langs.Lang_yelu
open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yc_add_library ~sources:[ ybare "MathFunctions.cxx" ] (ytarget "MathFunctions");
      yc_option ~value:(ybool true)
        ~msg:"Use tutorial provided math implementation" (ycvar "USE_MYMATH");
      yifthen (Ycond_cvar (ycvar "USE_MYMATH"))
        (ycmd_of_list
           [
             yc_target_compile_definitions (ytarget "MathFunctions")
               [ ytarget_def ~kind:Private [ yraw "USE_MYMATH" ] ];
             yc_add_library ~type_:Lib_static ~sources:[ ybare "mysqrt.cxx" ]
               (ytarget "SqrtLibrary");
             yc_target_link_libraries [ ytarget "MathFunctions" ]
               [ ytarget_def ~kind:Private [ ytval "SqrtLibrary" ] ];
           ]);
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
