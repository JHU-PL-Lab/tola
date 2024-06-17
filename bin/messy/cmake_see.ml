open Langs.Lang_cmake
open Langs.Lang_cmake_utils

let e1 =
  cmd_of_list
    [
      Cmake_cmd
        (Cmake_minimum_required { min = version_of_string "3.20."; max = None });
      Project_cmd (project "Hello");
      Project_cmd (add_executable ~sources:[ "Hello.c" ] "Hello");
    ]

let () = Fmt.pr "%a" (Fmt.vbox pp) e1
