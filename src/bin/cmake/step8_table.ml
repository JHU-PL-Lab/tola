open Langs.Lang_cmake
open Langs.Lang_cmake_utils
open Langs.Lang_cmake_pp

let cmd =
  cmd_of_list
    [
      add_executable ~sources:[ "MakeTable.cxx" ] "MakeTable";
      target_link_libraries [ Target "MakeTable" ]
        [ target_def ~kind:Private [ ivar "tutorial_compiler_flags" ] ];
      add_custom_command
        ~outputs:[ "${CMAKE_CURRENT_BINARY_DIR}/Table.h" ]
        ~depends:[ "MakeTable" ]
        [ custom_command "MakeTable" [ "${CMAKE_CURRENT_BINARY_DIR}/Table.h" ] ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) cmd
