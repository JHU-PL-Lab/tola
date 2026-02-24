open Langs.Lang_yelu_utils
open Langs.Lang_yelu_compile
open Langs.Lang_cmake_pp

let cmd =
  ycmd_of_list
    [
      yc_extern_target "tutorial_compiler_flags";
      yc_add_executable ~sources:[ ybare "MakeTable.cxx" ] (ytarget "MakeTable");
      yc_target_link_libraries [ ytarget "MakeTable" ]
        [ ytarget_def ~kind:Private [ ytval "tutorial_compiler_flags" ] ];
      yc_add_custom_command
        ~outputs:[ ybare "${CMAKE_CURRENT_BINARY_DIR}/Table.h" ]
        ~depends:[ ybare "MakeTable" ]
        [ custom_command "MakeTable" [ "${CMAKE_CURRENT_BINARY_DIR}/Table.h" ] ];
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) (compile empty_env cmd |> snd)
