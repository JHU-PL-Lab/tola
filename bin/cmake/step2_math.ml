open Langs.Lang_cmake
open Langs.Lang_cmake_utils
open Langs.Lang_cmake_pp

let cmd =
  cmd_of_list
    [
      add_library "MathFunctions" ~sources:[ "MathFunctions.cxx" ];
      option_ ~value:(bool_ true)
        ~msg:"Use tutorial provided math implementation" (Var "USE_MYMATH");
      If
        {
          cond = Var_exp "USE_MYMATH";
          then_ =
            cmd_of_list
              [
                target_compile_definitions (Target "MathFunctions")
                  [ target_def ~kind:Private [ istr "USE_MYMATH" ] ];
                add_library "SqrtLibrary" ~type_:Lib_static
                  ~sources:[ "mysqrt.cxx" ];
                target_link_libraries [ Target "MathFunctions" ]
                  [ target_def ~kind:Private [ ivar "SqrtLibrary" ] ];
              ];
          else_ = None;
        };
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) cmd
