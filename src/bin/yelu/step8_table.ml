open Langs.Lang_yelu_utils
open Step_common

let cmd =
  ycmd_of_list
    [
      yc_extern_target "tutorial_compiler_flags";
      yc_add_executable ~sources:[ yfile "MakeTable.cxx" ] (ytval "MakeTable");
      yc_target_link_libraries [ ytval "MakeTable" ]
        [ ytarget_def ~kind:Private [ ytval "tutorial_compiler_flags" ] ];
      yc_add_custom_command
        ~outputs:[ yfile "${CMAKE_CURRENT_BINARY_DIR}/Table.h" ]
        ~depends:[ ystr "MakeTable" ]
        [ custom_command "MakeTable" [ "${CMAKE_CURRENT_BINARY_DIR}/Table.h" ] ];
    ]

let () = print_cmake cmd
