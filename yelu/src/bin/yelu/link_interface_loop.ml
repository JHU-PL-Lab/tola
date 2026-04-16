open Yelu_langs.Lang_yelu
open Yelu_langs.Lang_yelu_utils
open Step_common

(* Generates: Tests/CMakeOnly/LinkInterfaceLoop/CMakeLists.txt
   Tests cmake's handling of cyclic IMPORTED target link interfaces. *)
let cmd =
  ycmd_of_list
    [
      yc_minimum_required_s "3.10.";
      yc_project ~languages:[ Lang_c ] "LinkInterfaceLoop";
      (* A: SHARED IMPORTED that names itself as a link dependency — cycle *)
      add_lib_imported ~lib_type:"SHARED" (Yarg_target (ytarget "A"));
      yc_set_target_properties
        (Yarg_target (ytarget "A"))
        [
          ("IMPORTED_LINK_DEPENDENT_LIBRARIES", Yarg_target (ytarget "A"));
          ("IMPORTED_LOCATION", ystr_raw "${CMAKE_CURRENT_BINARY_DIR}/dirA/A");
        ];
      (* B: SHARED IMPORTED that names itself in its link interface — cycle *)
      add_lib_imported ~lib_type:"SHARED" (Yarg_target (ytarget "B"));
      yc_set_target_properties
        (Yarg_target (ytarget "B"))
        [
          ("IMPORTED_LINK_INTERFACE_LIBRARIES", Yarg_target (ytarget "B"));
          ("IMPORTED_LOCATION", ystr_raw "${CMAKE_CURRENT_BINARY_DIR}/dirB/B");
        ];
      (* C: SHARED library with empty link interface, depends on B and A *)
      add_lib ~type_:Lib_shared ~sources:[ yfile "lib.c" ] (Yarg_target (ytarget "C"));
      yc_set_property
        ~targets:[ Yarg_target (ytarget "C") ]
        [ ("LINK_INTERFACE_LIBRARIES", ystr_raw "") ];
      link_lib
        [ Yarg_target (ytarget "C") ]
        [ ytarget_def ~kind:Plain [ Yarg_target (ytarget "B"); Yarg_target (ytarget "A") ] ];
      add_exe ~sources:[ yfile "main.c" ] (Yarg_target (ytarget "main"));
      link_lib
        [ Yarg_target (ytarget "main") ]
        [ ytarget_def ~kind:Plain [ Yarg_target (ytarget "C") ] ];
    ]

let () = print_cmake cmd
