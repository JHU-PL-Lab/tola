open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yadd_executable ~sources:[ "MakeTable.cxx" ] (ytarget "MakeTable");
      ytarget_link_libraries [ ytarget "MakeTable" ]
        [ ytarget_def ~kind:Private [ yivar "tutorial_compiler_flags" ] ];
      yadd_custom_command
        ~outputs:[ "${CMAKE_CURRENT_BINARY_DIR}/Table.h" ]
        ~depends:[ "MakeTable" ]
        [ custom_command "MakeTable" [ "${CMAKE_CURRENT_BINARY_DIR}/Table.h" ] ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile cmd)
