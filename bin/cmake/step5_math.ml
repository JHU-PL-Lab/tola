open Langs.Lang_cmake
open Langs.Lang_cmake_utils
open Langs.Lang_cmake_pp

let cmd =
  cmd_of_list
    [
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
               ~sources:[ "mysqrt.cxx" ];
             target_link_libraries [ Target "SqrtLibrary" ]
               [ target_def ~kind:Public [ ivar "tutorial_compiler_flags" ] ];
             target_link_libraries [ Target "MathFunctions" ]
               [ target_def ~kind:Private [ ivar "SqrtLibrary" ] ];
           ]);
      target_link_libraries [ Target "MathFunctions" ]
        [ target_def ~kind:Public [ ivar "tutorial_compiler_flags" ] ];
      set (Var "installable_libs")
        [ str_ "MathFunctions"; str_ "tutorial_compiler_flags" ];
      ifthen (Is_target "SqrtLibrary") (cmd_of_list []);
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) cmd

(*
   if (TARGET SqrtLibrary)
     list(APPEND installable_libs SqrtLibrary)
   endif()
   install(TARGETS ${installable_libs} DESTINATION lib)

   # TODO 2: Install the library headers to the include folder.
   # Hint: Use the FILES and DESTINATION parameters
   install(FILES MathFunctions.h DESTINATION include)
*)
