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
      ifthen (Var_exp "USE_MYMATH")
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
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) cmd

(*
   # create the MathFunctions library
   add_library(MathFunctions MathFunctions.cxx)

   # state that anybody linking to us needs to include the current source dir
   # to find MathFunctions.h, while we don't.
   target_include_directories(MathFunctions
                              INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}
                              )

   # should we use our own math functions
   option(USE_MYMATH "Use tutorial provided math implementation" ON)
   if (USE_MYMATH)
     target_compile_definitions(MathFunctions PRIVATE "USE_MYMATH")

     # library that just does sqrt
     add_library(SqrtLibrary STATIC
                 mysqrt.cxx
                 )

     # link SqrtLibrary to tutorial_compiler_flags
     target_link_libraries(SqrtLibrary PUBLIC tutorial_compiler_flags)

     target_link_libraries(MathFunctions PRIVATE SqrtLibrary)
   endif()

   # link MathFunctions to tutorial_compiler_flags
   target_link_libraries(MathFunctions PUBLIC tutorial_compiler_flags)
*)
