open Yelu_langs.Lang_yelu
open Yelu_langs.Lang_yelu_utils
open Step_common

(* Generates: Tests/CMakeOnly/TargetScope/Sib/CMakeLists.txt *)
let cmd =
  ycmd_of_list
    [
      yifthen
        (Yis_target (Yarg_target (ytarget "SubLibLocal")))
        (ycmd_of_list
           [ yc_message ~mode:Mm_fatal_error [ "SubLibLocal visible in sibling directory" ] ]);
      yifthen
        (Ynot (Yis_target (Yarg_target (ytarget "SubLibGlobal"))))
        (ycmd_of_list
           [ yc_message ~mode:Mm_fatal_error [ "SubLibGlobal not visible in sibling directory" ] ]);
    ]

let () = print_cmake cmd
