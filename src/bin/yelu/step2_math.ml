open Langs.Lang_yelu
open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yadd_library ~sources:[ "MathFunctions.cxx" ] (ytarget "MathFunctions");
      yoption ~value:(ybool true)
        ~msg:"Use tutorial provided math implementation" (yvar "USE_MYMATH");
      yifthen (Ycond_var (yvar "USE_MYMATH"))
        (ycmd_of_list
           [
             ytarget_compile_definitions (ytarget "MathFunctions")
               [ ytarget_def ~kind:Private [ yistr "USE_MYMATH" ] ];
             yadd_library ~type_:Lib_static ~sources:[ "mysqrt.cxx" ]
               (ytarget "SqrtLibrary");
             ytarget_link_libraries [ ytarget "MathFunctions" ]
               [ ytarget_def ~kind:Private [ yivar "SqrtLibrary" ] ];
           ]);
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile cmd)
