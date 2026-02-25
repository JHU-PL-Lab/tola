open Langs.Lang_yelu
open Langs.Lang_yelu_utils
open Step_common

let cmd =
  ycmd_of_list
    [
      ylet "math" (ytval "MathFunctions");
      ylet "sqrt" (ytval "SqrtLibrary");
      ylet "use_mymath" (ycstr "USE_MYMATH");
      yc_add_library ~sources:[ yfile "MathFunctions.cxx" ] (yvar "math");
      yc_option ~value:(ybool true)
        ~msg:"Use tutorial provided math implementation" (yvar "use_mymath");
      yifthen (Ytruthy (yvar "use_mymath"))
        (ycmd_of_list
           [
             yc_target_compile_definitions (yvar "math")
               [ ytarget_def ~kind:Private [ yraw "USE_MYMATH" ] ];
             yc_add_library ~type_:Lib_static ~sources:[ yfile "mysqrt.cxx" ]
               (yvar "sqrt");
             yc_target_link_libraries [ yvar "math" ]
               [ ytarget_def ~kind:Private [ yvar "sqrt" ] ];
           ]);
    ]

let () = print_cmake cmd
