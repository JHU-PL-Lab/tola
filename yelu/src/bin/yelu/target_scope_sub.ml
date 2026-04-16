open Yelu_langs.Lang_yelu
open Yelu_langs.Lang_yelu_utils
open Step_common

(* Generates: Tests/CMakeOnly/TargetScope/Sub/CMakeLists.txt *)
let cmd =
  ycmd_of_list
    [
      add_lib_imported ~lib_type:"UNKNOWN" (Yarg_target (ytarget "SubLibLocal"));
      add_lib_imported ~lib_type:"UNKNOWN" ~global:true (Yarg_target (ytarget "SubLibGlobal"));
      yc_add_subdirectory (ystr "Sub");
      yifthen
        (Ynot (Yis_target (Yarg_target (ytarget "SubLibLocal"))))
        (ycmd_of_list
           [ yc_message ~mode:Mm_fatal_error [ "SubLibLocal not visible in own directory" ] ]);
      yifthen
        (Ynot (Yis_target (Yarg_target (ytarget "SubLibGlobal"))))
        (ycmd_of_list
           [ yc_message ~mode:Mm_fatal_error [ "SubLibGlobal not visible in own directory" ] ]);
    ]

let () = print_cmake cmd
