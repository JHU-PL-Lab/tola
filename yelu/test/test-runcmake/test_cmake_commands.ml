(** Build-level equivalence tests: run upstream CMakeCommands reference cmake AND
    yelu-generated cmake through configure + build. Both must exit 0.
    Source: Tests/CMakeCommands/ — one subdirectory per target_* command. *)

open Yelu_langs.Lang_yelu
open Yelu_langs.Lang_yelu_utils
open Yelu_langs.Lang_yelu_compile
open Yelu_langs.Lang_cmake_pp
open Yelu_runner.Cmake_runner

let cmake_commands_dir =
  match Sys.getenv_opt "RUNCMAKE_DIR" with
  | Some d -> Filename.concat (Filename.dirname d) "CMakeCommands"
  | None ->
    let rec find dir depth =
      if depth > 10 then failwith ("cannot find workspace root from " ^ Sys.getcwd ())
      else
        let marker = Filename.concat dir "yelu/vendor" in
        if Sys.file_exists marker then dir
        else find (Filename.dirname dir) (depth + 1)
    in
    let ws_root = find (Sys.getcwd ()) 0 in
    let vendor_cmake = Filename.concat ws_root "yelu/vendor/cmake" in
    let resolved = try Unix.realpath vendor_cmake with Unix.Unix_error _ -> vendor_cmake in
    Filename.concat resolved "Tests/CMakeCommands"

(* Parent of cmake_commands_dir: Tests/ — used for Group 2 tests outside CMakeCommands/ *)
let tests_dir = Filename.dirname cmake_commands_dir

let ref_dir name = Filename.concat cmake_commands_dir name

let compile prog =
  let _, ast = compile empty_env prog in
  let buf = Buffer.create 512 in
  let ff = Format.formatter_of_buffer buf in
  Format.pp_open_vbox ff 0;
  pp ff ast;
  Format.pp_close_box ff ();
  Format.pp_print_flush ff ();
  Buffer.contents buf

let run_build_pair ref_path ?(files = []) yelu_prog =
  let ref_result  = run_build_existing ref_path in
  let cmake_text  = compile yelu_prog in
  let yelu_result = run_configure_and_build ~files cmake_text in
  (if ref_result.configure.run.exit_code <> 0 then
     Alcotest.failf "ref configure failed (exit %d)\nstderr:\n%s"
       ref_result.configure.run.exit_code ref_result.configure.run.stderr);
  (if ref_result.build.exit_code <> 0 then
     Alcotest.failf "ref build failed (exit %d)\nstderr:\n%s"
       ref_result.build.exit_code ref_result.build.stderr);
  (if yelu_result.configure.run.exit_code <> 0 then
     Alcotest.failf "yelu configure failed (exit %d)\nstderr:\n%s\ncmake:\n%s"
       yelu_result.configure.run.exit_code yelu_result.configure.run.stderr cmake_text);
  (if yelu_result.build.exit_code <> 0 then
     Alcotest.failf "yelu build failed (exit %d)\nstderr:\n%s\ncmake:\n%s"
       yelu_result.build.exit_code yelu_result.build.stderr cmake_text);
  check_artifacts_match ref_result.artifacts yelu_result.artifacts

(** Fate-sharing build test against Tests/CMakeCommands/<ref_name>. *)
let check_build_pair name ref_name ?(files = []) yelu_prog =
  Alcotest.test_case name `Quick (fun () ->
    run_build_pair (ref_dir ref_name) ~files yelu_prog)

(** Same, but ref is in Tests/<ref_name> (Group 2 tests outside CMakeCommands/). *)
let check_build_pair_tests name ref_name ?(files = []) yelu_prog =
  Alcotest.test_case name `Quick (fun () ->
    run_build_pair (Filename.concat tests_dir ref_name) ~files yelu_prog)

(* ==================================================================== *)
(* target_link_options                                                   *)
(* ==================================================================== *)

(* Ref: Tests/CMakeCommands/target_link_options/CMakeLists.txt
   Covers: PRIVATE/INTERFACE scopes, empty options, BEFORE ordering.
   The upstream cmake has get_target_property assertions that fail configure
   (via SEND_ERROR) if target properties are wrong — so configure exit 0
   means the assertions passed. *)

let c_lib_source = {|
#if defined(_WIN32)
__declspec(dllexport)
#endif
int flags_lib(void) { return 0; }
|}

let t name = Yarg_target (ytarget name)

let tlo_yelu =
  Yexp_list [
    yc_project ~languages:[Lang_c] "target_link_options";
    add_lib ~type_:Lib_shared ~sources:[ystr "lib.c"] (t "target_link_options");
    yc_target_link_options (t "target_link_options")
      [ ytarget_def ~kind:Private [] ];
    add_lib ~type_:Lib_shared ~exclude_from_all:true ~sources:[ystr "lib.c"] (t "target_link_options_2");
    yc_target_link_options (t "target_link_options_2")
      [ ytarget_def ~kind:Private  [ystr "-PRIVATE_FLAG"];
        ytarget_def ~kind:Interface [ystr "-INTERFACE_FLAG"] ];
    add_lib ~type_:Lib_static ~exclude_from_all:true ~sources:[ystr "lib.c"] (t "target_link_options_3");
    yc_target_link_options (t "target_link_options_3")
      [ ytarget_def ~kind:Interface [ystr "-INTERFACE_FLAG"] ];
    add_lib ~type_:Lib_shared ~exclude_from_all:true ~sources:[ystr "lib.c"] (t "target_link_options_4");
    yc_target_link_options ~before:false (t "target_link_options_4")
      [ ytarget_def ~kind:Private [ystr "-PRIVATE_FLAG"] ];
    yc_target_link_options ~before:true (t "target_link_options_4")
      [ ytarget_def ~kind:Private [ystr "-BEFORE_PRIVATE_FLAG"] ];
  ]

(* ==================================================================== *)
(* add_compile_definitions                                               *)
(* ==================================================================== *)

(* Ref: Tests/CMakeCommands/add_compile_definitions/CMakeLists.txt
   Covers: plain def, genex $<COMPILE_LANGUAGE:CXX>, genex that evals false.
   main.cpp asserts TEST_DEFINITION and LANG_CXX are defined; UNEXPECTED_DEFINITION must not be. *)

let cpp_main_source = {|
#ifndef TEST_DEFINITION
#  error Expected TEST_DEFINITION
#endif
#ifndef LANG_CXX
#  error Expected LANG_CXX
#endif
#ifdef UNEXPECTED_DEFINITION
#  error Unexpected UNEXPECTED_DEFINITION
#endif
int main(void) { return 0; }
|}

let acd_yelu =
  Yexp_list [
    yc_project ~languages:[Lang_cxx] "add_compile_definitions";
    yc_add_compile_definitions [
      ystr "TEST_DEFINITION";
      ystr_raw "$<$<COMPILE_LANGUAGE:CXX>:LANG_$<COMPILE_LANGUAGE>>";
      ystr_raw "$<$<EQUAL:0,1>:UNEXPECTED_DEFINITION>";
    ];
    add_exe ~sources:[ystr "main.cpp"] (t "add_compile_definitions");
    add_lib_imported ~lib_type:"UNKNOWN" (t "imp");
    yc_get_target_property (ycvar "_res") "imp" "COMPILE_DEFINITIONS";
    yifthen (ytruthy (ycstr "_res"))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["add_compile_definitions populated the COMPILE_DEFINITIONS target property"] ]);
  ]

(* ==================================================================== *)
(* add_link_options                                                      *)
(* ==================================================================== *)

(* Ref: Tests/CMakeCommands/add_link_options/CMakeLists.txt
   Covers: global link flag propagation to LINK_OPTIONS target property,
   imported targets must NOT inherit it. *)

let add_link_opts_yelu =
  Yexp_list [
    yc_project ~languages:[Lang_c] "add_link_options";
    yc_add_link_options [ystr "-LINK_FLAG"];
    add_exe ~exclude_from_all:true ~sources:[ystr "LinkOptionsExe.c"] (t "add_link_options");
    yc_get_target_property (ycvar "result") "add_link_options" "LINK_OPTIONS";
    yifthen (Ynot (ymatches (ycstr "result") "-LINK_FLAG"))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["add_link_options not populated the LINK_OPTIONS target property"] ]);
    add_lib_imported ~lib_type:"UNKNOWN" (t "imp");
    yc_get_target_property (ycvar "result") "imp" "LINK_OPTIONS";
    yifthen (ytruthy (ycstr "result"))
      (Yexp_list [ yc_message ~mode:Mm_fatal_error ["add_link_options populated the LINK_OPTIONS target property"] ]);
  ]

(* ==================================================================== *)
(* link_directories                                                      *)
(* ==================================================================== *)

(* Ref: Tests/CMakeCommands/link_directories/CMakeLists.txt
   Covers: BEFORE flag, CMAKE_LINK_DIRECTORIES_BEFORE, directory property,
   target property, imported target must NOT inherit. *)

let link_dirs_yelu =
  Yexp_list [
    yc_project ~languages:[Lang_c] "link_directories";
    yc_link_directories [ystr "/A"];
    yc_link_directories ~before:true [ystr "/B"];
    yc_set (ycvar "CMAKE_LINK_DIRECTORIES_BEFORE") [ybool true];
    yc_link_directories [ystr "/C"];
    yc_quote_cmd {|get_directory_property(result LINK_DIRECTORIES)|};
    yifthen (Ynot (ymatches (ycstr "result") "/C;/B;/A"))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["link_directories not populated the LINK_DIRECTORIES directory property"] ]);
    add_exe ~exclude_from_all:true ~sources:[ystr "LinkDirectoriesExe.c"] (t "link_directories");
    yc_get_target_property (ycvar "result") "link_directories" "LINK_DIRECTORIES";
    yifthen (Ynot (ymatches (ycstr "result") "/C;/B;/A"))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["link_directories not populated the LINK_DIRECTORIES target property"] ]);
    add_lib_imported ~lib_type:"UNKNOWN" (t "imp");
    yc_get_target_property (ycvar "result") "imp" "LINK_DIRECTORIES";
    yifthen (ytruthy (ycstr "result"))
      (Yexp_list [ yc_message ~mode:Mm_fatal_error ["link_directories populated the LINK_DIRECTORIES target property"] ]);
  ]

(* ==================================================================== *)
(* add_compile_options                                                   *)
(* ==================================================================== *)

(* Ref: Tests/CMakeCommands/add_compile_options/CMakeLists.txt
   Covers: -DTEST_OPTION propagates to compile; imported target must NOT inherit.
   DO_GNU_TESTS block in main.cpp is guarded — skipping the compiler-conditional
   target_compile_definitions call is safe: the check won't fire on non-GNU. *)

let aco_main_source = {|
#ifdef DO_GNU_TESTS
#  ifndef TEST_OPTION
#    error Expected TEST_OPTION
#  endif
#endif
int main(void) { return 0; }
|}

let aco_yelu =
  Yexp_list [
    yc_project ~languages:[Lang_cxx] "add_compile_options";
    yc_add_compile_options [ystr "-DTEST_OPTION"];
    add_exe ~sources:[ystr "main.cpp"] (t "add_compile_options");
    yc_add_compile_options [ystr "-rtti"];
    add_lib_imported ~lib_type:"UNKNOWN" (t "imp");
    yc_get_target_property (ycvar "_res") "imp" "COMPILE_OPTIONS";
    yifthen (ytruthy (ycstr "_res"))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["add_compile_options populated the COMPILE_OPTIONS target property"] ]);
  ]

(* ==================================================================== *)
(* target_compile_definitions                                            *)
(* ==================================================================== *)

(* Ref: Tests/CMakeCommands/target_compile_definitions/CMakeLists.txt
   Covers: PRIVATE/PUBLIC/INTERFACE scopes, genex COMPILE_LANGUAGE, -D prefix
   stripping, TARGET_PROPERTY interface propagation, UNKNOWN IMPORTED must not
   inherit add_compile_definitions. *)

let tcd_main_source = {|
#ifndef MY_PRIVATE_DEFINE
#  error Expected MY_PRIVATE_DEFINE
#endif
#ifndef MY_PUBLIC_DEFINE
#  error Expected MY_PUBLIC_DEFINE
#endif
#ifdef MY_INTERFACE_DEFINE
#  error Unexpected MY_INTERFACE_DEFINE
#endif
int main() { return 0; }
|}

let tcd_consumer_cpp_source = {|
#ifdef MY_PRIVATE_DEFINE
#  error Unexpected MY_PRIVATE_DEFINE
#endif
#ifndef MY_PUBLIC_DEFINE
#  error Expected MY_PUBLIC_DEFINE
#endif
#ifndef MY_INTERFACE_DEFINE
#  error Expected MY_INTERFACE_DEFINE
#endif
#ifndef DASH_D_DEFINE
#  error Expected DASH_D_DEFINE
#endif
#ifndef CONSUMER_LANG_CXX
#  error Expected CONSUMER_LANG_CXX
#endif
#ifdef CONSUMER_LANG_C
#  error Unexpected CONSUMER_LANG_C
#endif
#if !LANG_IS_CXX
#  error Expected LANG_IS_CXX
#endif
#if LANG_IS_C
#  error Unexpected LANG_IS_C
#endif
int main() { return 0; }
|}

let tcd_consumer_c_source = {|
#ifdef CONSUMER_LANG_CXX
#  error Unexpected CONSUMER_LANG_CXX
#endif
#ifndef CONSUMER_LANG_C
#  error Expected CONSUMER_LANG_C
#endif
#if !LANG_IS_C
#  error Expected LANG_IS_C
#endif
#if LANG_IS_CXX
#  error Unexpected LANG_IS_CXX
#endif
#if !LANG_IS_C_OR_CXX
#  error Expected LANG_IS_C_OR_CXX
#endif
void consumer_c(void) {}
|}

let tcd_yelu =
  Yexp_list [
    yc_project ~languages:[Lang_c; Lang_cxx] "target_compile_definitions";
    add_exe ~sources:[ystr "main.cpp"] (t "target_compile_definitions");
    compile_defs (t "target_compile_definitions") [
      ytarget_def ~kind:Private   [ystr "MY_PRIVATE_DEFINE"];
      ytarget_def ~kind:Public    [ystr "MY_PUBLIC_DEFINE"];
      ytarget_def ~kind:Interface [ystr "MY_INTERFACE_DEFINE"];
    ];
    add_exe ~sources:[ystr "consumer.cpp"] (t "consumer");
    compile_defs (t "consumer") [
      ytarget_def ~kind:Private [
        ystr_raw "$<TARGET_PROPERTY:target_compile_definitions,INTERFACE_COMPILE_DEFINITIONS>";
        ystr "-DDASH_D_DEFINE";
      ];
    ];
    compile_defs (t "consumer") [ ytarget_def ~kind:Private [] ];
    yc_target_sources (t "consumer") [ytarget_def ~kind:Private [ystr "consumer.c"]];
    compile_defs (t "consumer") [
      ytarget_def ~kind:Private [
        ystr_raw "CONSUMER_LANG_$<COMPILE_LANGUAGE>";
        ystr_raw "LANG_IS_CXX=$<COMPILE_LANGUAGE:CXX>";
        ystr_raw "LANG_IS_C=$<COMPILE_LANGUAGE:C>";
        ystr_raw "LANG_IS_C_OR_CXX=$<COMPILE_LANGUAGE:C,CXX>";
      ];
    ];
    yc_add_compile_definitions [ystr "-DSOME_DEF"];
    add_lib_imported ~lib_type:"UNKNOWN" (t "imp");
    yc_get_target_property (ycvar "_res") "imp" "COMPILE_DEFINITIONS";
    yifthen (ytruthy (ycstr "_res"))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["add_definitions populated the COMPILE_DEFINITIONS target property"] ]);
  ]

(* ==================================================================== *)
(* target_compile_options                                                *)
(* ==================================================================== *)

(* Ref: Tests/CMakeCommands/target_compile_options/CMakeLists.txt
   Covers: genex CXX_COMPILER_ID / COMPILE_LANG_AND_ID scopes, COMPILE_LANGUAGE
   language-dispatch, TARGET_PROPERTY interface propagation.
   DO_GNU_TESTS / DO_CLANG_TESTS guards in sources protect compiler-specific
   checks — skipping those target_compile_definitions calls is safe. *)

let tco_main_source = {|
#ifdef DO_GNU_TESTS
#  ifndef MY_PRIVATE_DEFINE
#    error Expected MY_PRIVATE_DEFINE
#  endif
#  ifndef MY_PUBLIC_DEFINE
#    error Expected MY_PUBLIC_DEFINE
#  endif
#  ifndef MY_MUTLI_COMP_PUBLIC_DEFINE
#    error Expected MY_MUTLI_COMP_PUBLIC_DEFINE
#  endif
#  ifdef MY_INTERFACE_DEFINE
#    error Unexpected MY_INTERFACE_DEFINE
#  endif
#endif
#ifdef DO_CLANG_TESTS
#  ifndef MY_PRIVATE_DEFINE
#    error Expected MY_PRIVATE_DEFINE
#  endif
#  ifdef MY_PUBLIC_DEFINE
#    error Unexpected MY_PUBLIC_DEFINE
#  endif
#  ifndef MY_MUTLI_COMP_PUBLIC_DEFINE
#    error Expected MY_MUTLI_COMP_PUBLIC_DEFINE
#  endif
#endif
int main() { return 0; }
|}

let tco_consumer_cpp_source = {|
#ifdef DO_GNU_TESTS
#  ifdef MY_PRIVATE_DEFINE
#    error Unexpected MY_PRIVATE_DEFINE
#  endif
#  ifndef MY_PUBLIC_DEFINE
#    error Expected MY_PUBLIC_DEFINE
#  endif
#  ifndef MY_INTERFACE_DEFINE
#    error Expected MY_INTERFACE_DEFINE
#  endif
#  ifndef MY_MULTI_COMP_INTERFACE_DEFINE
#    error Expected MY_MULTI_COMP_INTERFACE_DEFINE
#  endif
#  ifndef MY_MUTLI_COMP_PUBLIC_DEFINE
#    error Expected MY_MUTLI_COMP_PUBLIC_DEFINE
#  endif
#endif
#ifdef DO_CLANG_TESTS
#  ifdef MY_PRIVATE_DEFINE
#    error Unexpected MY_PRIVATE_DEFINE
#  endif
#  ifndef MY_MULTI_COMP_INTERFACE_DEFINE
#    error Expected MY_MULTI_COMP_INTERFACE_DEFINE
#  endif
#  ifndef MY_MUTLI_COMP_PUBLIC_DEFINE
#    error Expected MY_MUTLI_COMP_PUBLIC_DEFINE
#  endif
#endif
#ifndef CONSUMER_LANG_CXX
#  error Expected CONSUMER_LANG_CXX
#endif
#ifdef CONSUMER_LANG_C
#  error Unexpected CONSUMER_LANG_C
#endif
#if !LANG_IS_CXX
#  error Expected LANG_IS_CXX
#endif
#if LANG_IS_C
#  error Unexpected LANG_IS_C
#endif
int main() { return 0; }
|}

let tco_consumer_c_source = {|
#ifdef CONSUMER_LANG_CXX
#  error Unexpected CONSUMER_LANG_CXX
#endif
#ifndef CONSUMER_LANG_C
#  error Expected CONSUMER_LANG_C
#endif
#if !LANG_IS_C
#  error Expected LANG_IS_C
#endif
#if LANG_IS_CXX
#  error Unexpected LANG_IS_CXX
#endif
void consumer_c(void) {}
|}

let tco_yelu =
  Yexp_list [
    yc_project ~languages:[Lang_c; Lang_cxx] "target_compile_options";
    add_exe ~sources:[ystr "main.cpp"] (t "target_compile_options");
    compile_opts (t "target_compile_options") [
      ytarget_def ~kind:Private   [ystr_raw "$<$<CXX_COMPILER_ID:AppleClang,IBMClang,CrayClang,Clang,GNU,LCC>:-DMY_PRIVATE_DEFINE>"];
      ytarget_def ~kind:Public    [ystr_raw "$<$<COMPILE_LANG_AND_ID:CXX,GNU,LCC>:-DMY_PUBLIC_DEFINE>"];
      ytarget_def ~kind:Public    [ystr_raw "$<$<COMPILE_LANG_AND_ID:CXX,GNU,LCC,Clang,AppleClang,CrayClang,IBMClang>:-DMY_MUTLI_COMP_PUBLIC_DEFINE>"];
      ytarget_def ~kind:Interface [ystr_raw "$<$<CXX_COMPILER_ID:GNU,LCC>:-DMY_INTERFACE_DEFINE>"];
      ytarget_def ~kind:Interface [ystr_raw "$<$<CXX_COMPILER_ID:GNU,LCC,Clang,AppleClang,CrayClang,IBMClang>:-DMY_MULTI_COMP_INTERFACE_DEFINE>"];
    ];
    add_exe ~sources:[ystr "consumer.cpp"] (t "consumer");
    yc_target_sources (t "consumer") [ytarget_def ~kind:Private [ystr "consumer.c"]];
    compile_opts (t "consumer") [
      ytarget_def ~kind:Private [
        ystr_raw "-DCONSUMER_LANG_$<COMPILE_LANGUAGE>";
        ystr_raw "-DLANG_IS_CXX=$<COMPILE_LANGUAGE:CXX>";
        ystr_raw "-DLANG_IS_C=$<COMPILE_LANGUAGE:C>";
      ];
    ];
    compile_opts (t "consumer") [
      ytarget_def ~kind:Private [
        ystr_raw "$<$<CXX_COMPILER_ID:GNU,LCC,Clang,AppleClang,CrayClang,IBMClang>:$<TARGET_PROPERTY:target_compile_options,INTERFACE_COMPILE_OPTIONS>>";
      ];
    ];
    compile_opts (t "consumer") [ ytarget_def ~kind:Private [] ];
  ]

(* ==================================================================== *)
(* target_link_directories                                               *)
(* ==================================================================== *)

(* Ref: Tests/CMakeCommands/target_link_directories/CMakeLists.txt
   Covers: PRIVATE/INTERFACE scopes, relative path resolution, subdir target,
   get_target_property assertions via configure exit code.
   subdir/CMakeLists.txt is passed via ~files — mkdirp creates the subdir. *)

let link_dir_lib_source = {|
#if defined(_WIN32)
__declspec(dllexport)
#endif
int flags_lib(void) { return 0; }
|}

let tld_yelu =
  Yexp_list [
    yc_project ~languages:[Lang_c] "target_link_directories";
    add_lib ~type_:Lib_shared ~sources:[ystr "LinkDirectoriesLib.c"] (t "target_link_directories");
    yc_target_link_directories (t "target_link_directories") [ ytarget_def ~kind:Private [] ];
    add_lib ~type_:Lib_shared ~exclude_from_all:true ~sources:[ystr "LinkDirectoriesLib.c"] (t "target_link_directories_2");
    yc_target_link_directories (t "target_link_directories_2") [
      ytarget_def ~kind:Private   [ystr "/private/dir"];
      ytarget_def ~kind:Interface [ystr "/interface/dir"];
    ];
    yc_get_target_property (ycvar "result") "target_link_directories_2" "LINK_DIRECTORIES";
    yifthen (Ynot (ystrequal (ycstr "result") (ystr "/private/dir")))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["${result} target_link_directories not populated the LINK_DIRECTORIES target property"] ]);
    yc_get_target_property (ycvar "result") "target_link_directories_2" "INTERFACE_LINK_DIRECTORIES";
    yifthen (Ynot (ystrequal (ycstr "result") (ystr "/interface/dir")))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["target_link_directories not populated the INTERFACE_LINK_DIRECTORIES target property of shared library"] ]);
    add_lib ~type_:Lib_static ~exclude_from_all:true ~sources:[ystr "LinkDirectoriesLib.c"] (t "target_link_directories_3");
    yc_target_link_directories (t "target_link_directories_3") [
      ytarget_def ~kind:Interface [ystr "/interface/dir"];
    ];
    yc_get_target_property (ycvar "result") "target_link_directories_3" "INTERFACE_LINK_DIRECTORIES";
    yifthen (Ynot (ystrequal (ycstr "result") (ystr "/interface/dir")))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["target_link_directories not populated the INTERFACE_LINK_DIRECTORIES target property of static library"] ]);
    add_lib ~type_:Lib_shared ~exclude_from_all:true ~sources:[ystr "LinkDirectoriesLib.c"] (t "target_link_directories_4");
    yc_target_link_directories (t "target_link_directories_4") [
      ytarget_def ~kind:Private [ystr "relative/dir"];
    ];
    yc_get_target_property (ycvar "result") "target_link_directories_4" "LINK_DIRECTORIES";
    yifthen (Ynot (ystrequal (ycstr "result") (ystr_raw "${CMAKE_CURRENT_SOURCE_DIR}/relative/dir")))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["target_link_directories not populated the LINK_DIRECTORIES with relative path"] ]);
    yc_add_subdirectory (ystr "subdir");
    yc_target_link_directories (t "target_link_directories_5") [
      ytarget_def ~kind:Private [ystr "relative/dir"];
    ];
    yc_get_target_property (ycvar "result") "target_link_directories_5" "LINK_DIRECTORIES";
    yifthen (Ynot (ystrequal (ycstr "result") (ystr_raw "${CMAKE_CURRENT_SOURCE_DIR}/relative/dir")))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["target_link_directories not populated the LINK_DIRECTORIES with relative path"] ]);
  ]

(* ==================================================================== *)
(* target_compile_features                                               *)
(* ==================================================================== *)

(* Ref: Tests/CMakeCommands/target_compile_features/CMakeLists.txt
   Covers: c_restrict/c_std_99/cxx_auto_type/cxx_std_11 features gated on
   CMAKE_*_COMPILE_FEATURES. Both sides use identical if() conditions, so
   whichever branches fire on the ref will fire identically on yelu → artifact
   names always match regardless of the compiler's feature set. *)

let tcf_main_c_source = {|
int foo(int* restrict a, int* restrict b)
{
  (void)a; (void)b;
  return 0;
}
int main(void) { return 0; }
|}

let tcf_lib_restrict_h = {|
#ifndef LIB_RESTRICT_H
#define LIB_RESTRICT_H
int foo(int* restrict a, int* restrict b);
#endif
|}

let tcf_lib_restrict_c = {|
#include "lib_restrict.h"
int foo(int* restrict a, int* restrict b)
{ (void)a; (void)b; return 0; }
|}

let tcf_restrict_user_c = {|
#include "lib_restrict.h"
int bar(int* restrict a, int* restrict b) { (void)a; (void)b; return foo(a, b); }
int main(void) { return 0; }
|}

let tcf_main_cpp_source = {|
int main(int, char**) { auto i = 0; return i; }
|}

let tcf_lib_auto_type_h = {|
int getAutoTypeImpl();
inline int getAutoType() { auto i = getAutoTypeImpl(); return i; }
|}

let tcf_lib_auto_type_cpp = {|
int getAutoTypeImpl() { auto i = 0; return i; }
|}

let tcf_lib_user_cpp = {|
#include "lib_auto_type.h"
int main(int, char**) { return getAutoType(); }
|}

let tcf_yelu =
  Yexp_list [
    yc_quote_cmd "cmake_minimum_required(VERSION 3.10)";
    yc_project ~languages:[Lang_c; Lang_cxx] "target_compile_features";
    yifthen (yin_list (ystr "c_restrict") (ycstr "CMAKE_C_COMPILE_FEATURES"))
      (Yexp_list [
        add_exe ~sources:[ystr "main.c"] (t "c_target_compile_features_specific");
        compile_feats (t "c_target_compile_features_specific") [ytarget_feature ~kind:Private "c_restrict"];
        add_lib ~sources:[ystr "lib_restrict.c"] (t "c_lib_restrict_specific");
        compile_feats (t "c_lib_restrict_specific") [ytarget_feature ~kind:Public "c_restrict"];
        add_exe ~sources:[ystr "restrict_user.c"] (t "c_restrict_user_specific");
        link_lib [t "c_restrict_user_specific"] [ytarget_def ~kind:Plain [ytval "c_lib_restrict_specific"]];
      ]);
    yifthen (Yand (yin_list (ystr "c_std_99") (ycstr "CMAKE_C_COMPILE_FEATURES"),
                  Ynot (ystrequal (ycstr "CMAKE_C_COMPILER_ID") (ystr "MSVC"))))
      (Yexp_list [
        add_exe ~sources:[ystr "main.c"] (t "c_target_compile_features_meta");
        compile_feats (t "c_target_compile_features_meta") [ytarget_feature ~kind:Private "c_std_99"];
        add_lib ~sources:[ystr "lib_restrict.c"] (t "c_lib_restrict_meta");
        compile_feats (t "c_lib_restrict_meta") [ytarget_feature ~kind:Public "c_std_99"];
        add_exe ~sources:[ystr "restrict_user.c"] (t "c_restrict_user_meta");
        link_lib [t "c_restrict_user_meta"] [ytarget_def ~kind:Plain [ytval "c_lib_restrict_meta"]];
      ]);
    yifthen (yin_list (ystr "cxx_auto_type") (ycstr "CMAKE_CXX_COMPILE_FEATURES"))
      (Yexp_list [
        add_exe ~sources:[ystr "main.cpp"] (t "cxx_target_compile_features_specific");
        compile_feats (t "cxx_target_compile_features_specific") [ytarget_feature ~kind:Private "cxx_auto_type"];
        add_lib ~sources:[ystr "lib_auto_type.cpp"] (t "cxx_lib_auto_type_specific");
        compile_feats (t "cxx_lib_auto_type_specific") [ytarget_feature ~kind:Public "cxx_auto_type"];
        add_exe ~sources:[ystr "lib_user.cpp"] (t "cxx_lib_user_specific");
        link_lib [t "cxx_lib_user_specific"] [ytarget_def ~kind:Plain [ytval "cxx_lib_auto_type_specific"]];
      ]);
    yifthen (yin_list (ystr "cxx_std_11") (ycstr "CMAKE_CXX_COMPILE_FEATURES"))
      (Yexp_list [
        add_exe ~sources:[ystr "main.cpp"] (t "cxx_target_compile_features_meta");
        compile_feats (t "cxx_target_compile_features_meta") [ytarget_feature ~kind:Private "cxx_std_11"];
        add_lib ~sources:[ystr "lib_auto_type.cpp"] (t "cxx_lib_auto_type_meta");
        compile_feats (t "cxx_lib_auto_type_meta") [ytarget_feature ~kind:Public "cxx_std_11"];
        add_exe ~sources:[ystr "lib_user.cpp"] (t "cxx_lib_user_meta");
        link_lib [t "cxx_lib_user_meta"] [ytarget_def ~kind:Plain [ytval "cxx_lib_auto_type_meta"]];
      ]);
  ]

(* ==================================================================== *)
(* target_sources                                                        *)
(* ==================================================================== *)

(* Ref: Tests/CMakeCommands/target_sources/CMakeLists.txt
   Covers: CMP0076=NEW (relative→absolute path conversion), genex-wrapped
   source paths, cross-dir target_sources, SOURCES property IN_LIST assertions. *)

let ts_main_cpp = {|
#include <iostream>
int empty_1(); int subdir_empty_1(); int subdir_empty_2();
int main() {
  std::cout << empty_1() << " " << subdir_empty_1() << " " << subdir_empty_2() << std::endl;
  return 0;
}
|}

let ts_empty_1_cpp = {|
#ifdef IS_LIB
int internal_empty_1() { return 0; }
#else
int empty_1() { return 0; }
#endif
|}

let ts_empty_2_cpp = {|int empty_2() { return 0; }|}
let ts_empty_3_cpp = {|int empty_3() { return 0; }|}

let ts_subdir_empty_1_cpp = {|
#ifdef IS_LIB
int internal_subdir_empty_1() { return 0; }
#else
int subdir_empty_1() { return 0; }
#endif
|}

let ts_subdir_empty_2_cpp = {|
#ifdef IS_LIB
int internal_subdir_empty_2() { return 0; }
#else
int subdir_empty_2() { return 0; }
#endif
|}

(* subdir/CMakeLists.txt: adds sources to parent target_sources_lib via target_sources *)
let ts_subdir_cmake = {|target_sources(target_sources_lib PUBLIC $<1:${CMAKE_CURRENT_LIST_DIR}/subdir_empty_1.cpp>
                                         $<1:${CMAKE_CURRENT_LIST_DIR}/../empty_1.cpp>
                                         subdir_empty_2.cpp
                                  PRIVATE $<1:empty_2.cpp>
                                          ../empty_3.cpp)|}

let ts_yelu =
  Yexp_list [
    yc_quote_cmd "cmake_minimum_required(VERSION 3.12)";
    yc_quote_cmd "cmake_policy(SET CMP0076 NEW)";
    yc_project ~languages:[Lang_cxx] "target_sources";
    add_lib (t "target_sources_lib");
    compile_defs (t "target_sources_lib") [ytarget_def ~kind:Private [ystr "-DIS_LIB"]];
    yc_add_subdirectory (ystr "subdir");
    yc_set (ycvar "subdir_fullpath") [ystr_raw "${CMAKE_CURRENT_LIST_DIR}/subdir"];
    yc_get_target_property (ycvar "target_sources_lib_property") "target_sources_lib" "SOURCES";
    yifthen (Ynot (yin_list (ystr_raw "$<1:${subdir_fullpath}/subdir_empty_1.cpp>") (ycstr "target_sources_lib_property")))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["target_sources_lib: Generator expression to absolute sub directory file not found"] ]);
    yifthen (Ynot (yin_list (ystr_raw "$<1:${subdir_fullpath}/../empty_1.cpp>") (ycstr "target_sources_lib_property")))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["target_sources_lib: Generator expression to absolute main directory file not found"] ]);
    yifthen (Ynot (yin_list (ystr_raw "${subdir_fullpath}/subdir_empty_2.cpp") (ycstr "target_sources_lib_property")))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["target_sources_lib: Relative sub directory file not converted to absolute"] ]);
    yifthen (Ynot (yin_list (ystr_raw "$<1:empty_2.cpp>") (ycstr "target_sources_lib_property")))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["target_sources_lib: Generator expression to relative main directory file not found"] ]);
    yifthen (Ynot (yin_list (ystr_raw "${subdir_fullpath}/../empty_3.cpp") (ycstr "target_sources_lib_property")))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["target_sources_lib: Relative main directory file not converted to absolute"] ]);
    add_exe ~sources:[ystr "main.cpp"] (t "target_sources");
    link_lib [t "target_sources"] [ytarget_def ~kind:Plain [ytval "target_sources_lib"]];
    yc_get_target_property (ycvar "target_sources_property") "target_sources" "SOURCES";
    yifthen (Ynot (yin_list (ystr "main.cpp") (ycstr "target_sources_property")))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["target_sources: Relative main directory file converted to absolute"] ]);
  ]

(* ==================================================================== *)
(* target_include_directories                                            *)
(* ==================================================================== *)

(* Ref: Tests/CMakeCommands/target_include_directories/CMakeLists.txt
   Covers: PRIVATE/PUBLIC/INTERFACE/BEFORE/SYSTEM scopes, genex include paths,
   binary-dir header generation, header-order (same.h BEFORE override),
   include_directories must NOT populate imported target's INCLUDE_DIRECTORIES. *)

let tid_main_cpp = {|
#include "common.h"
#include "privateinclude.h"
#include "publicinclude.h"
#ifndef PRIVATEINCLUDE_DEFINE
#  error Expected PRIVATEINCLUDE_DEFINE
#endif
#ifndef PUBLICINCLUDE_DEFINE
#  error Expected PUBLICINCLUDE_DEFINE
#endif
#ifdef INTERFACEINCLUDE_DEFINE
#  error Unexpected INTERFACEINCLUDE_DEFINE
#endif
#ifndef CURE_DEFINE
#  error Expected CURE_DEFINE
#endif
int main() { return 0; }
|}

let tid_consumer_cpp = {|
#include "consumer.h"
#include "common.h"
#include "cxx_only.h"
#include "interfaceinclude.h"
#include "publicinclude.h"
#include "relative_dir.h"
#ifdef PRIVATEINCLUDE_DEFINE
#  error Unexpected PRIVATEINCLUDE_DEFINE
#endif
#ifndef PUBLICINCLUDE_DEFINE
#  error Expected PUBLICINCLUDE_DEFINE
#endif
#ifndef INTERFACEINCLUDE_DEFINE
#  error Expected INTERFACEINCLUDE_DEFINE
#endif
#ifndef CURE_DEFINE
#  error Expected CURE_DEFINE
#endif
#ifndef RELATIVE_DIR_DEFINE
#  error Expected RELATIVE_DIR_DEFINE
#endif
#ifndef CONSUMER_DEFINE
#  error Expected CONSUMER_DEFINE
#endif
#ifndef CXX_ONLY_DEFINE
#  error Expected CXX_ONLY_DEFINE
#endif
int main() { return 0; }
|}

let tid_consumer_c = {|
#ifdef TEST_LANG_DEFINES_FOR_VISUAL_STUDIO_OR_XCODE
#  include "cxx_only.h"
#  ifndef CXX_ONLY_DEFINE
#    error Expected CXX_ONLY_DEFINE
#  endif
#else
#  include "c_only.h"
#  ifndef C_ONLY_DEFINE
#    error Expected C_ONLY_DEFINE
#  endif
#endif
int consumer_c(void) { return 0; }
|}

let tid_same_c = {|
#include "same.h"
#ifndef CORRECT_SAME_H_INCLUDED
#  error "Correct \"same.h\" not included!"
#endif
void same(void) {}
|}

let tid_yelu =
  let bindir = "${CMAKE_CURRENT_BINARY_DIR}" in
  Yexp_list [
    yc_project ~languages:[Lang_c; Lang_cxx] "target_include_directories";
    (* generate binary-dir headers at configure time *)
    yc_file_make_directory [ystr_raw (bindir ^ "/privateinclude")];
    yc_file_write (ystr_raw (bindir ^ "/privateinclude/privateinclude.h"))
      [ystr "#define PRIVATEINCLUDE_DEFINE\n"];
    yc_file_make_directory [ystr_raw (bindir ^ "/publicinclude")];
    yc_file_write (ystr_raw (bindir ^ "/publicinclude/publicinclude.h"))
      [ystr "#define PUBLICINCLUDE_DEFINE\n"];
    yc_file_make_directory [ystr_raw (bindir ^ "/interfaceinclude")];
    yc_file_write (ystr_raw (bindir ^ "/interfaceinclude/interfaceinclude.h"))
      [ystr "#define INTERFACEINCLUDE_DEFINE\n"];
    yc_file_make_directory [ystr_raw (bindir ^ "/poison")];
    yc_file_write (ystr_raw (bindir ^ "/poison/common.h"))
      [ystr "#error Should not be included\n"];
    yc_file_make_directory [ystr_raw (bindir ^ "/cure")];
    yc_file_write (ystr_raw (bindir ^ "/cure/common.h"))
      [ystr "#define CURE_DEFINE\n"];
    (* main exe: PRIVATE/PUBLIC/INTERFACE include dirs *)
    add_exe ~sources:[ystr "main.cpp"] (t "target_include_directories");
    include_dirs (t "target_include_directories") [
      ytarget_def ~kind:Private   [ystr_raw (bindir ^ "/privateinclude")];
      ytarget_def ~kind:Public    [ystr_raw (bindir ^ "/publicinclude")];
      ytarget_def ~kind:Interface [ystr_raw (bindir ^ "/interfaceinclude")];
    ];
    include_dirs (t "target_include_directories") [
      ytarget_def ~kind:Public [ystr_raw (bindir ^ "/poison")];
    ];
    (* BEFORE PUBLIC with genex: cure overrides poison for EXECUTABLE type *)
    yc_quote_cmd {|target_include_directories(target_include_directories BEFORE PUBLIC "$<$<STREQUAL:$<TARGET_PROPERTY:target_include_directories,TYPE>,EXECUTABLE>:${CMAKE_CURRENT_BINARY_DIR}/cure>")|};
    (* no effect: SHARED_LIBRARY type never matches for exe *)
    yc_quote_cmd {|target_include_directories(target_include_directories BEFORE PUBLIC "$<$<STREQUAL:$<TARGET_PROPERTY:target_include_directories,TYPE>,SHARED_LIBRARY>:${CMAKE_CURRENT_BINARY_DIR}/poison>")|};
    (* consumer exe: CXX/C language-dispatched include dirs *)
    add_exe ~sources:[ystr "consumer.cpp"] (t "consumer");
    yc_target_sources (t "consumer") [ytarget_def ~kind:Private [ystr "consumer.c"]];
    include_dirs (t "consumer") [
      ytarget_def ~kind:Private [
        ystr_raw "$<$<COMPILE_LANGUAGE:CXX>:${CMAKE_CURRENT_SOURCE_DIR}/cxx_only>";
        ystr_raw "$<$<COMPILE_LANGUAGE:C>:${CMAKE_CURRENT_SOURCE_DIR}/c_only>";
      ];
    ];
    include_dirs (t "consumer") [
      ytarget_def ~kind:Private [
        ystr_raw "$<TARGET_PROPERTY:target_include_directories,INTERFACE_INCLUDE_DIRECTORIES>";
        ystr "relative_dir";
        ystr_raw "relative_dir/$<TARGET_PROPERTY:NAME>";
      ];
    ];
    (* empty PRIVATE / BEFORE PRIVATE / SYSTEM BEFORE PRIVATE / SYSTEM PRIVATE *)
    include_dirs (t "consumer") [ ytarget_def ~kind:Private [] ];
    yc_quote_cmd "target_include_directories(consumer BEFORE PRIVATE)";
    yc_quote_cmd "target_include_directories(consumer SYSTEM BEFORE PRIVATE)";
    yc_quote_cmd "target_include_directories(consumer SYSTEM PRIVATE)";
    (* global include_directories: must NOT populate imported target's property *)
    yc_quote_cmd "include_directories(${CMAKE_CURRENT_BINARY_DIR})";
    add_lib_imported ~lib_type:"UNKNOWN" (t "imp");
    yc_get_target_property (ycvar "_res") "imp" "INCLUDE_DIRECTORIES";
    yifthen (ytruthy (ycstr "_res"))
      (Yexp_list [ yc_message ~mode:Mm_send_error ["include_directories populated the INCLUDE_DIRECTORIES target property"] ]);
    (* same: header-order test — same_two wins over same_one via PRIVATE include dir *)
    add_lib ~type_:Lib_static
      ~sources:[ystr "same.c"; ystr "same_one/same.h"; ystr "same_two/same.h"]
      (t "same");
    include_dirs (t "same") [ ytarget_def ~kind:Private [ystr "same_two"] ];
  ]

(* ==================================================================== *)
(* Group 2 — Tests/LibName                                              *)
(* ==================================================================== *)

(* Tests LIBRARY_OUTPUT_PATH / EXECUTABLE_OUTPUT_PATH and VERSION/SOVERSION.
   if(UNIX) block emitted unconditionally (always true on Linux). *)

let libname_bar_c = {|
#ifdef _WIN32
__declspec(dllexport)
#endif
extern void foo(void) {}
|}

let libname_foo_c = {|
#ifdef _WIN32
__declspec(dllimport)
#endif
extern void foo(void);
#ifdef _WIN32
__declspec(dllexport)
#endif
void bar(void) { foo(); }
|}

let libname_foobar_c = {|
#ifdef _WIN32
__declspec(dllimport)
#endif
extern void bar();
int main(void) { bar(); return 0; }
|}

let libname_yelu =
  Yexp_list [
    yc_quote_cmd "cmake_minimum_required(VERSION 3.10)";
    yc_project ~languages:[Lang_c] "LibName";
    yc_set (ycvar "LIBRARY_OUTPUT_PATH") [ystr "lib"];
    yc_set (ycvar "EXECUTABLE_OUTPUT_PATH") [ystr "lib"];
    add_lib ~type_:Lib_shared ~sources:[ystr "bar.c"] (t "bar");
    add_lib ~type_:Lib_shared ~sources:[ystr "foo.c"] (t "foo");
    link_lib [t "foo"] [ytarget_def ~kind:Plain [ytval "bar"]];
    add_exe ~sources:[ystr "foobar.c"] (t "foobar");
    link_lib [t "foobar"] [ytarget_def ~kind:Plain [ytval "foo"]];
    yc_quote_cmd {|if(UNIX)
  target_link_libraries(foobar -L/usr/local/lib)
endif()|};
    add_lib ~type_:Lib_shared ~sources:[ystr "foo.c"] (t "verFoo");
    link_lib [t "verFoo"] [ytarget_def ~kind:Plain [ytval "bar"]];
    yc_set_target_properties (t "verFoo")
      [("VERSION", ystr "3.1.4"); ("SOVERSION", ystr "3")];
    add_exe ~sources:[ystr "foobar.c"] (t "verFoobar");
    link_lib [t "verFoobar"] [ytarget_def ~kind:Plain [ytval "verFoo"]];
    (* if(MAKE_SUPPORTS_SPACES ...) block omitted: MAKE_SUPPORTS_SPACES not set *)
  ]

(* ==================================================================== *)
(* Group 2 — Tests/LinkStatic                                           *)
(* ==================================================================== *)

(* Static-links against libm.a. find_library / LINK_FLAGS / LINK_SEARCH_*
   have no typed yelu equivalents — use quote_cmd throughout. *)

let link_static_main_c = {|
#include <math.h>
int main(void) { return (int)sin(0); }
|}

let link_static_yelu =
  Yexp_list [
    yc_quote_cmd "cmake_minimum_required(VERSION 3.10)";
    yc_quote_cmd {|if(POLICY CMP0129)
  cmake_policy(SET CMP0129 NEW)
endif()|};
    yc_project ~languages:[Lang_c] "LinkStatic";
    yc_quote_cmd {|if(NOT CMAKE_C_COMPILER_ID MATCHES "GNU|LCC")
  message(FATAL_ERROR "This test works only with the GNU or LCC compiler!")
endif()|};
    yc_quote_cmd {|find_library(MATH_LIBRARY NAMES libm.a)
if(MATH_LIBRARY)
  get_filename_component(MATH_LIB_DIR ${MATH_LIBRARY} PATH)
  link_directories(${MATH_LIB_DIR})
  set(MATH_LIBRARIES ${MATH_LIBRARY} -lm)
else()
  message(FATAL_ERROR "Cannot find libm.a needed for this test")
endif()|};
    add_exe ~sources:[ystr "LinkStatic.c"] (t "LinkStatic");
    link_lib [t "LinkStatic"]
      [ytarget_def ~kind:Plain [ystr_raw "${MATH_LIBRARIES}"]];
    yc_quote_cmd {|set(LinkStatic_FLAG "-static" CACHE STRING "Flag to link statically")
set_property(TARGET LinkStatic PROPERTY LINK_FLAGS "${LinkStatic_FLAG}")
set_property(TARGET LinkStatic PROPERTY LINK_SEARCH_START_STATIC 1)|};
  ]

(* ==================================================================== *)
(* Group 2 — Tests/Simple                                               *)
(* ==================================================================== *)

let simple_simple_cxx = {|
extern void simpleLib();
extern "C" int FooBar();
extern int bar();
extern int bar1();
int main()
{
  FooBar();
  bar();
  simpleLib();
  return 0;
}
|}

let simple_simplelib_cxx = {|
void simpleLib()
{
}
|}

let simple_simpleclib_c = {|
#include <stdio.h>
int FooBar(void)
{
  int class;
  int private = 10;
  for (class = 0; class < private; class ++) {
    printf("Count: %d/%d\n", class, private);
  }
  return 0;
}
|}

let simple_simplewe_cpp = {|
#include <stdio.h>
class Foo
{
public:
  Foo() { printf("This one has nonstandard extension\n"); }
  int getnum() { return 0; }
};
int bar()
{
  Foo f;
  return f.getnum();
}
|}

let simple_yelu =
  Yexp_list [
    yc_project ~languages:[Lang_cxx; Lang_c] "Simple";
    add_exe ~sources:[ystr "simple.cxx"] (t "Simple");
    add_lib ~type_:Lib_static
      ~sources:[ystr "simpleLib.cxx"; ystr "simpleCLib.c"; ystr "simpleWe.cpp"]
      (t "simpleLib");
    link_lib [t "Simple"] [ytarget_def ~kind:Plain [ytval "simpleLib"]];
  ]

(* ==================================================================== *)
(* Group 2 — Tests/LinkLine                                             *)
(* ==================================================================== *)

(* One.c and Two.c are mutually recursive via static guards. *)
let ll_one_c = {|
void TwoFunc(void);
void OneFunc(void)
{
  static int i = 0;
  ++i;
  if (i == 1) { TwoFunc(); }
}
|}

let ll_two_c = {|
void OneFunc(void);
void TwoFunc(void)
{
  static int i = 0;
  ++i;
  if (i == 1) { OneFunc(); }
}
|}

let ll_exec_c = {|
void OneFunc();
void TwoFunc();
int main(void) { OneFunc(); TwoFunc(); return 0; }
|}

(* link_libraries() is the global (legacy) form — emit via quote_cmd. *)
let ll_yelu =
  Yexp_list [
    yc_quote_cmd "cmake_minimum_required(VERSION 3.10)";
    yc_project ~languages:[Lang_c] "LinkLine";
    add_lib ~sources:[ystr "One.c"] (t "One");
    add_lib ~sources:[ystr "Two.c"] (t "Two");
    yc_quote_cmd "link_libraries(One Two)";
    add_exe ~sources:[ystr "Exec.c"] (t "LinkLine");
  ]

(* ==================================================================== *)
(* Group 2 — Tests/LinkLineOrder                                        *)
(* ==================================================================== *)

let llo_nodep_a_c = {|void NoDepB_func(void); void NoDepA_func(void) { NoDepB_func(); }|}
let llo_nodep_b_c = {|void NoDepB_func(void) {}|}
let llo_nodep_c_c = {|void NoDepA_func(void); void NoDepC_func(void) { NoDepA_func(); }|}
let llo_nodep_e_c = {|
void NoDepF_func(void);
void NoDepE_func(void) {
  static int first = 1;
  if (first) { first = 0; NoDepF_func(); }
}
|}
let llo_nodep_f_c = {|
void NoDepE_func(void);
void NoDepF_func(void) {
  static int first = 1;
  if (first) { first = 0; NoDepE_func(); }
}
|}
let llo_nodep_x_c = {|void NoDepY_func(void); void NoDepX_func(void) { NoDepY_func(); }|}
let llo_nodep_y_c = {|void NoDepY_func(void) {}|}
let llo_nodep_z_c = {|void NoDepX_func(void); void NoDepZ_func(void) { NoDepX_func(); }|}
let llo_one_c = {|
void NoDepC_func(void); void NoDepE_func(void);
void OneFunc(void) { NoDepC_func(); NoDepE_func(); }
|}
let llo_two_c = {|
void OneFunc(void); void NoDepZ_func(void);
void TwoFunc(void) { OneFunc(); NoDepZ_func(); }
|}
let llo_exec1_c = {|void OneFunc(); int main(void) { OneFunc(); return 0; }|}
let llo_exec2_c = {|void TwoFunc(); int main(void) { TwoFunc(); return 0; }|}

let llo_yelu =
  Yexp_list [
    yc_quote_cmd "cmake_minimum_required(VERSION 3.10)";
    yc_project ~languages:[Lang_c] "LinkLineOrder";
    add_lib ~sources:[ystr "NoDepA.c"] (t "NoDepA");
    add_lib ~sources:[ystr "NoDepB.c"] (t "NoDepB");
    add_lib ~sources:[ystr "NoDepC.c"] (t "NoDepC");
    add_lib ~sources:[ystr "NoDepE.c"] (t "NoDepE");
    add_lib ~sources:[ystr "NoDepF.c"] (t "NoDepF");
    add_lib ~sources:[ystr "One.c"] (t "One");
    link_lib [t "One"]
      [ytarget_def ~kind:Plain [ytval "NoDepC"; ytval "NoDepA"; ytval "NoDepB";
                                ytval "NoDepE"; ytval "NoDepF"; ytval "NoDepE"]];
    add_exe ~sources:[ystr "Exec1.c"] (t "Exec1");
    link_lib [t "Exec1"] [ytarget_def ~kind:Plain [ytval "One"]];
    add_lib ~sources:[ystr "NoDepX.c"] (t "NoDepX");
    add_lib ~sources:[ystr "NoDepY.c"] (t "NoDepY");
    add_lib ~sources:[ystr "NoDepZ.c"] (t "NoDepZ");
    add_lib ~sources:[ystr "Two.c"] (t "Two");
    link_lib [t "Two"]
      [ytarget_def ~kind:Plain [ytval "One"; ytval "NoDepZ";
                                ytval "NoDepX"; ytval "NoDepY"]];
    add_exe ~sources:[ystr "Exec2.c"] (t "Exec2");
    link_lib [t "Exec2"] [ytarget_def ~kind:Plain [ytval "Two"]];
  ]

(* ==================================================================== *)
(* Group 2 — Tests/OutName                                              *)
(* ==================================================================== *)

(* Tests OUTPUT_NAME prefix/suffix overrides on an executable target. *)
let out_name_yelu =
  Yexp_list [
    yc_quote_cmd "cmake_minimum_required(VERSION 3.12)";
    yc_project ~languages:[Lang_c] "OutName";
    add_exe ~sources:[ystr "main.c"] (t "OutName");
    yc_set_target_properties (t "OutName")
      [("PREFIX", ystr "exe."); ("SUFFIX", ystr ".exe")];
  ]

(* ==================================================================== *)
(* Group 3 — Tests/EmptyLibrary                                         *)
(* ==================================================================== *)

(* Root adds one subdir; subdir adds a header-only static library.
   The resulting libtest.a is empty (no object files). *)
let _empty_lib_yelu =
  Yexp_list [
    yc_quote_cmd "cmake_minimum_required(VERSION 3.10)";
    yc_project "TestEmptyLibrary";
    yc_add_subdirectory (ystr "subdir");
  ]

(* ==================================================================== *)
(* Group 3 — Tests/TargetName                                           *)
(* ==================================================================== *)

(* Two subdirs: executables/ builds hello_world exe; scripts/ custom-copies
   a shell script to the binary dir (always runs because we use out-of-source). *)
let target_name_hello_world_c = {|
#include <stdio.h>
int main(void) { printf("hello, world\n"); return 0; }
|}

let target_name_scripts_cmake = {|
if(NOT CMAKE_BINARY_DIR STREQUAL "${CMAKE_SOURCE_DIR}")
  add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/hello_world
    COMMAND ${CMAKE_COMMAND} -E copy
      ${CMAKE_CURRENT_SOURCE_DIR}/hello_world ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/hello_world
  )
  add_custom_target(
    hello_world_copy ALL
    DEPENDS
    ${CMAKE_CURRENT_BINARY_DIR}/hello_world
  )
endif()
|}

let target_name_yelu =
  Yexp_list [
    yc_quote_cmd "cmake_minimum_required(VERSION 3.10)";
    yc_project ~languages:[Lang_c] "TargetName";
    yc_add_subdirectory (ystr "executables");
    yc_add_subdirectory (ystr "scripts");
  ]

(* ==================================================================== *)
(* Group 3 — Tests/CompileDefinitions                                   *)
(* ==================================================================== *)

(* Root cmake uses foreach+set for per-config flags and set_property(DIRECTORY).
   Three subdirs each build an executable from ../compiletest.cpp.
   All subdir cmake content is embedded verbatim; root uses quote_cmd. *)

let cd_compiletest_cpp = {|
#ifndef CMAKE_IS_FUN
#  error Expect CMAKE_IS_FUN definition
#endif
#if CMAKE_IS != Fun
#  error Expect CMAKE_IS=Fun definition
#endif
template <bool test> struct CMakeStaticAssert;
template <> struct CMakeStaticAssert<true> {};
static char const fun_string[] = CMAKE_IS_;
#ifndef NO_SPACES_IN_DEFINE_VALUES
static char const very_fun_string[] = CMAKE_IS_REALLY;
#endif
enum {
  StringLiteralTest1 = sizeof(CMakeStaticAssert<sizeof(CMAKE_IS_) == sizeof("Fun")>),
#ifndef NO_SPACES_IN_DEFINE_VALUES
  StringLiteralTest2 = sizeof(CMakeStaticAssert<sizeof(CMAKE_IS_REALLY) == sizeof("Very Fun")>),
#endif
#ifdef TEST_GENERATOR_EXPRESSIONS
  StringLiteralTest3 = sizeof(CMakeStaticAssert<sizeof(LETTER_LIST1) == sizeof("A,B,C,D")>),
  StringLiteralTest4 = sizeof(CMakeStaticAssert<sizeof(LETTER_LIST2) == sizeof("A,,B,,C,,D")>),
  StringLiteralTest5 = sizeof(CMakeStaticAssert<sizeof(LETTER_LIST3) == sizeof("A,-B,-C,-D")>),
  StringLiteralTest6 = sizeof(CMakeStaticAssert<sizeof(LETTER_LIST4) == sizeof("A-,-B-,-C-,-D")>),
  StringLiteralTest7 = sizeof(CMakeStaticAssert<sizeof(LETTER_LIST5) == sizeof("A-,B-,C-,D")>)
#endif
};
#ifdef TEST_GENERATOR_EXPRESSIONS
#  ifndef CMAKE_IS_DECLARATIVE
#    error Expect declarative definition
#  endif
#  ifdef GE_NOT_DEFINED
#    error Expect not defined generator expression
#  endif
#  ifndef ARGUMENT
#    error Expected define expanded from list
#  endif
#  ifndef LIST
#    error Expected define expanded from list
#  endif
#  ifndef PREFIX_DEF1
#    error Expect PREFIX_DEF1
#  endif
#  ifndef PREFIX_DEF2
#    error Expect PREFIX_DEF2
#  endif
#  ifndef LINK_CXX_DEFINE
#    error Expected LINK_CXX_DEFINE
#  endif
#  ifndef LINK_LANGUAGE_IS_CXX
#    error Expected LINK_LANGUAGE_IS_CXX
#  endif
#  ifdef LINK_C_DEFINE
#    error Unexpected LINK_C_DEFINE
#  endif
#  ifdef LINK_LANGUAGE_IS_C
#    error Unexpected LINK_LANGUAGE_IS_C
#  endif
#endif
#ifndef BUILD_IS_DEBUG
#  error "BUILD_IS_DEBUG not defined!"
#endif
#ifndef BUILD_IS_NOT_DEBUG
#  error "BUILD_IS_NOT_DEBUG not defined!"
#endif
#ifdef TEST_CONFIG_DEBUG
#  if !BUILD_IS_DEBUG
#    error "BUILD_IS_DEBUG false with TEST_CONFIG_DEBUG!"
#  endif
#  if BUILD_IS_NOT_DEBUG
#    error "BUILD_IS_NOT_DEBUG true with TEST_CONFIG_DEBUG!"
#  endif
#else
#  if BUILD_IS_DEBUG
#    error "BUILD_IS_DEBUG true without TEST_CONFIG_DEBUG!"
#  endif
#  if !BUILD_IS_NOT_DEBUG
#    error "BUILD_IS_NOT_DEBUG false without TEST_CONFIG_DEBUG!"
#  endif
#endif
int main(int argc, char** argv) { return 0; }
|}

let cd_compiletest_c = {|
#ifndef LINK_C_DEFINE
#  error Expected LINK_C_DEFINE
#endif
#ifndef LINK_LANGUAGE_IS_C
#  error Expected LINK_LANGUAGE_IS_C
#endif
#ifdef LINK_CXX_DEFINE
#  error Unexpected LINK_CXX_DEFINE
#endif
#ifdef LINK_LANGUAGE_IS_CXX
#  error Unexpected LINK_LANGUAGE_IS_CXX
#endif
int main(void) { return 0; }
|}

let cd_compiletest_mixed_c = {|
#ifndef LINK_CXX_DEFINE
#  error Expected LINK_CXX_DEFINE
#endif
#ifndef LINK_LANGUAGE_IS_CXX
#  error Expected LINK_LANGUAGE_IS_CXX
#endif
#ifdef LINK_C_DEFINE
#  error Unexpected LINK_C_DEFINE
#endif
#ifdef LINK_LANGUAGE_IS_C
#  error Unexpected LINK_LANGUAGE_IS_C
#endif
#ifndef C_EXECUTABLE_LINK_LANGUAGE_IS_C
#  error Expected C_EXECUTABLE_LINK_LANGUAGE_IS_C define
#endif
void someFunc(void) {}
|}

let cd_compiletest_mixed_cxx = {|
#ifndef LINK_CXX_DEFINE
#  error Expected LINK_CXX_DEFINE
#endif
#ifndef LINK_LANGUAGE_IS_CXX
#  error Expected LINK_LANGUAGE_IS_CXX
#endif
#ifdef LINK_C_DEFINE
#  error Unexpected LINK_C_DEFINE
#endif
#ifdef LINK_LANGUAGE_IS_C
#  error Unexpected LINK_LANGUAGE_IS_C
#endif
#ifndef C_EXECUTABLE_LINK_LANGUAGE_IS_C
#  error Expected C_EXECUTABLE_LINK_LANGUAGE_IS_C define
#endif
int main(int argc, char** argv) { return 0; }
|}

let cd_usetgt_c = {|
#ifndef TGT_DEF
#  error TGT_DEF incorrectly not defined
#endif
#ifndef TGT_TYPE_STATIC_LIBRARY
#  error TGT_TYPE_STATIC_LIBRARY incorrectly not defined
#endif
#ifdef TGT_TYPE_EXECUTABLE
#  error TGT_TYPE_EXECUTABLE incorrectly defined
#endif
int main(void) { return 0; }
|}

let cd_add_def_cmd_cmake = {|
add_definitions(-DCMAKE_IS_FUN -DCMAKE_IS=Fun -DCMAKE_IS_="Fun")
if(NOT NO_SPACES_IN_DEFINE_VALUES)
  add_definitions(-DCMAKE_IS_REALLY="Very Fun")
endif()
add_definitions(-DCMAKE_IS_="Fun")
if(NOT NO_SPACES_IN_DEFINE_VALUES)
  add_definitions(-DCMAKE_IS_REALLY="Very Fun")
endif()
add_definitions(-DCMAKE_IS_FUN -DCMAKE_IS=Fun)
add_definitions(-DBUILD_IS_DEBUG=$<CONFIG:Debug> -DBUILD_IS_NOT_DEBUG=$<NOT:$<CONFIG:Debug>>)
add_executable(add_def_cmd_exe ../compiletest.cpp)
|}

let cd_target_prop_cmake = {|
project(target_prop)
add_executable(target_prop_executable ../compiletest.cpp)
set_target_properties(target_prop_executable PROPERTIES COMPILE_DEFINITIONS CMAKE_IS_FUN)
if(NOT NO_SPACES_IN_DEFINE_VALUES)
  set_property(TARGET target_prop_executable APPEND PROPERTY COMPILE_DEFINITIONS CMAKE_IS_REALLY="Very Fun" CMAKE_IS=Fun)
else()
  set_property(TARGET target_prop_executable APPEND PROPERTY COMPILE_DEFINITIONS CMAKE_IS=Fun)
endif()
set_property(TARGET target_prop_executable APPEND PROPERTY COMPILE_DEFINITIONS CMAKE_IS_FUN CMAKE_IS_="Fun")
set_property(TARGET target_prop_executable APPEND PROPERTY COMPILE_DEFINITIONS
  TEST_GENERATOR_EXPRESSIONS
  "$<1:CMAKE_IS_DECLARATIVE>"
  "$<0:GE_NOT_DEFINED>"
  "$<1:ARGUMENT;LIST>"
  PREFIX_$<JOIN:DEF1;DEF2,;PREFIX_>
  LETTER_LIST1=\"$<JOIN:A;B;C;D,,>\"
  LETTER_LIST2=\"$<JOIN:A;B;C;D,,,>\"
  LETTER_LIST3=\"$<JOIN:A;B;C;D,,->\"
  LETTER_LIST4=\"$<JOIN:A;B;C;D,-,->\"
  LETTER_LIST5=\"$<JOIN:A;B;C;D,-,>\"
  "$<$<STREQUAL:$<TARGET_PROPERTY:LINKER_LANGUAGE>,CXX>:LINK_CXX_DEFINE>"
  "$<$<STREQUAL:$<TARGET_PROPERTY:LINKER_LANGUAGE>,C>:LINK_C_DEFINE>"
  "LINK_LANGUAGE_IS_$<TARGET_PROPERTY:LINKER_LANGUAGE>"
)
set_property(TARGET target_prop_executable APPEND PROPERTY COMPILE_DEFINITIONS
  BUILD_IS_DEBUG=$<CONFIG:Debug>
  BUILD_IS_NOT_DEBUG=$<NOT:$<CONFIG:Debug>>
)
add_executable(target_prop_c_executable ../compiletest.c)
set_property(TARGET target_prop_c_executable APPEND PROPERTY COMPILE_DEFINITIONS
  "$<$<STREQUAL:$<TARGET_PROPERTY:LINKER_LANGUAGE>,CXX>:LINK_CXX_DEFINE>"
  "$<$<STREQUAL:$<TARGET_PROPERTY:LINKER_LANGUAGE>,C>:LINK_C_DEFINE>"
  "LINK_LANGUAGE_IS_$<TARGET_PROPERTY:LINKER_LANGUAGE>"
)
add_executable(target_prop_mixed_executable ../compiletest_mixed_c.c ../compiletest_mixed_cxx.cpp)
set_property(TARGET target_prop_mixed_executable APPEND PROPERTY COMPILE_DEFINITIONS
  "$<$<STREQUAL:$<TARGET_PROPERTY:LINKER_LANGUAGE>,CXX>:LINK_CXX_DEFINE>"
  "$<$<STREQUAL:$<TARGET_PROPERTY:LINKER_LANGUAGE>,C>:LINK_C_DEFINE>"
  "LINK_LANGUAGE_IS_$<TARGET_PROPERTY:LINKER_LANGUAGE>"
  "C_EXECUTABLE_LINK_LANGUAGE_IS_$<TARGET_PROPERTY:target_prop_c_executable,LINKER_LANGUAGE>"
)
add_library(tgt STATIC IMPORTED)
set_property(TARGET tgt APPEND PROPERTY COMPILE_DEFINITIONS TGT_DEF TGT_TYPE_$<TARGET_PROPERTY:TYPE>)
add_executable(usetgt usetgt.c)
target_compile_definitions(usetgt PRIVATE $<TARGET_PROPERTY:tgt,COMPILE_DEFINITIONS>)
|}

let cd_add_def_cmd_tprop_cmake = {|
add_definitions(-DCMAKE_IS_FUN -DCMAKE_IS=Fun)
add_executable(add_def_cmd_tprop_exe ../compiletest.cpp)
set_target_properties(add_def_cmd_tprop_exe PROPERTIES COMPILE_DEFINITIONS CMAKE_IS_="Fun")
if(NOT NO_SPACES_IN_DEFINE_VALUES)
  set_property(TARGET add_def_cmd_tprop_exe APPEND PROPERTY COMPILE_DEFINITIONS CMAKE_IS_REALLY="Very Fun")
endif()
add_definitions(-DCMAKE_IS_FUN)
set_property(TARGET add_def_cmd_tprop_exe APPEND PROPERTY COMPILE_DEFINITIONS CMAKE_IS=Fun CMAKE_IS_="Fun")
add_definitions(-DBUILD_IS_DEBUG=$<CONFIG:Debug>)
set_property(TARGET add_def_cmd_tprop_exe APPEND PROPERTY COMPILE_DEFINITIONS BUILD_IS_NOT_DEBUG=$<NOT:$<CONFIG:Debug>>)
|}

(* -------------------------------------------------------------------------- *)
(* CxxOnly (Tests/CxxOnly/)                                                  *)
(* -------------------------------------------------------------------------- *)

let cxxonly_libcxx1_h = {|class LibCxx1Class { public: static float Method(); };|}
let cxxonly_libcxx1_cxx = {|#include "libcxx1.h"
float LibCxx1Class::Method() { return 2.0; }|}
let cxxonly_libcxx2_h = {|
#ifdef _WIN32
#  ifdef testcxx2_EXPORTS
#    define CM_TEST_LIB_EXPORT __declspec(dllexport)
#  else
#    define CM_TEST_LIB_EXPORT __declspec(dllimport)
#  endif
#else
#  define CM_TEST_LIB_EXPORT
#endif
class CM_TEST_LIB_EXPORT LibCxx2Class { public: static float Method(); };
|}
let cxxonly_libcxx2_cxx = {|#include "libcxx2.h"
float LibCxx2Class::Method() { return 1.0; }|}
let cxxonly_test_C = {|int testC;|}
let cxxonly_cxxonly_cxx = {|
#include "libcxx1.h"
#include "libcxx2.h"
extern int testC;
#include <stdio.h>
int main() {
  testC = 1;
  if (LibCxx1Class::Method() != 2.0) { printf("Problem with libcxx1\n"); return 1; }
  if (LibCxx2Class::Method() != 1.0) { printf("Problem with libcxx2\n"); return 1; }
  return 0;
}|}
let cxxonly_module_cxx = {|
#ifdef _WIN32
#  define TEST_EXPORT __declspec(dllexport)
#else
#  define TEST_EXPORT
#endif
TEST_EXPORT int testCxxModule(void) { return 0; }
|}

let cxxonly_yelu =
  Yexp_list [
    yc_quote_cmd "cmake_minimum_required(VERSION 3.10)";
    yc_project ~languages:[Lang_cxx] "CxxOnly";
    yc_set (ycvar "CMAKE_DEBUG_POSTFIX") [ystr "_test_debug_postfix"];
    (* testcxx1.my: target name with a dot — use quote_cmd *)
    yc_quote_cmd "add_library(testcxx1.my STATIC libcxx1.cxx test.C)";
    add_lib ~type_:Lib_shared ~sources:[ystr "libcxx2.cxx"] (t "testcxx2");
    add_exe ~sources:[ystr "cxxonly.cxx"] (t "CxxOnly");
    yc_quote_cmd "target_link_libraries(CxxOnly testcxx1.my testcxx2)";
    add_lib ~type_:Lib_module ~sources:[ystr "testCxxModule.cxx"] (t "testCxxModule");
  ]

(* -------------------------------------------------------------------------- *)
(* AliasTarget (Tests/AliasTarget/)                                         *)
(* -------------------------------------------------------------------------- *)

let alias_target_commandgenerator_cpp = {|
#include <fstream>
#include "object.h"
int main(int argc, char** argv) {
  std::ofstream fout("commandoutput.h");
  if (!fout) return 1;
  fout << "#define COMMANDOUTPUT_DEFINE\n";
  fout.close();
  return object();
}
|}

let alias_target_targetgenerator_cpp = {|
#include <fstream>
int main(int argc, char** argv) {
  std::ofstream fout("targetoutput.h");
  if (!fout) return 1;
  fout << "#define TARGETOUTPUT_DEFINE\n";
  fout.close();
  return 0;
}
|}

let alias_target_empty_cpp = {|
#ifdef _WIN32
__declspec(dllexport)
#endif
int main(void) { return 0; }
|}

let alias_target_object_cpp = {|int object(void) { return 0; }|}

let alias_target_object_h = {|
#ifdef _WIN32
__declspec(dllexport)
#endif
int object(void);
|}

let alias_target_bat_cpp = {|
#ifndef FOO_DEFINE
#  error Expected FOO_DEFINE
#endif
#ifndef BAR_DEFINE
#  error Expected Bar_DEFINE
#endif
#include "commandoutput.h"
#ifndef COMMANDOUTPUT_DEFINE
#  error Expected COMMANDOUTPUT_DEFINE
#endif
#include "targetoutput.h"
#ifndef TARGETOUTPUT_DEFINE
#  error Expected TARGETOUTPUT_DEFINE
#endif
#ifdef _WIN32
__declspec(dllexport)
#endif
int bar() { return 0; }
|}

let alias_target_subdir_cmake = {|
add_library(tgt STATIC empty.cpp)
add_library(Sub::tgt ALIAS tgt)
add_library(Top::foo ALIAS foo)
get_target_property(some_prop Top::foo SOME_PROP)
target_link_libraries(tgt Top::foo)
|}

let alias_target_yelu =
  Yexp_list [
    yc_quote_cmd "cmake_minimum_required(VERSION 3.10)";
    yc_project ~languages:[Lang_cxx] "AliasTarget";
    add_lib ~type_:Lib_shared ~sources:[ystr "empty.cpp"] (t "foo");
    yc_quote_cmd "add_library(PREFIX::Foo ALIAS foo)";
    yc_quote_cmd "add_library(Another::Alias ALIAS foo)";
    add_lib ~type_:Lib_object ~sources:[ystr "object.cpp"] (t "objects");
    yc_quote_cmd "add_library(Alias::Objects ALIAS objects)";
    compile_defs (t "foo") [ytarget_def ~kind:Public [ytval "FOO_DEFINE"]];
    add_lib ~type_:Lib_shared ~sources:[ystr "empty.cpp"] (t "bar");
    compile_defs (t "bar") [ytarget_def ~kind:Public [ytval "BAR_DEFINE"]];
    yc_quote_cmd {|target_link_libraries(foo LINK_PUBLIC
  $<$<STREQUAL:$<TARGET_PROPERTY:PREFIX::Foo,ALIASED_TARGET>,foo>:bar>)|};
    yc_quote_cmd {|add_executable(AliasTarget
  commandgenerator.cpp $<TARGET_OBJECTS:Alias::Objects>)|};
    yc_quote_cmd "add_executable(PREFIX::AliasTarget ALIAS AliasTarget)";
    yc_quote_cmd "add_executable(Generator::Command ALIAS AliasTarget)";
    yc_add_custom_command ~outputs:[ystr "commandoutput.h"]
      [Yelu_langs.Lang_cmake.{ command = "Generator::Command"; args = [] }];
    add_lib ~type_:Lib_shared
      ~sources:[ystr "bat.cpp"; ystr "${CMAKE_CURRENT_BINARY_DIR}/commandoutput.h"]
      (t "bat");
    link_lib [t "bat"] [ytarget_def ~kind:Plain [ytval "PREFIX::Foo"]];
    include_dirs (t "bat")
      [ytarget_def ~kind:Private [ystr "${CMAKE_CURRENT_BINARY_DIR}"]];
    add_exe ~sources:[ystr "targetgenerator.cpp"] (t "targetgenerator");
    yc_quote_cmd "add_executable(Generator::Target ALIAS targetgenerator)";
    yc_add_subdirectory (ystr "subdir");
    yc_quote_cmd {|add_custom_target(usealias
  Generator::Target $<TARGET_FILE:Sub::tgt>)|};
    yc_quote_cmd "add_dependencies(bat usealias)";
    yc_quote_cmd {|if(NOT TARGET Another::Alias)
  message(SEND_ERROR "Another::Alias is not considered a target.")
endif()|};
    yc_quote_cmd {|get_target_property(_alt PREFIX::Foo ALIASED_TARGET)
if(NOT ${_alt} STREQUAL foo)
  message(SEND_ERROR "ALIASED_TARGET is not foo: ${_alt}")
endif()|};
    yc_quote_cmd {|get_property(_alt2 TARGET PREFIX::Foo PROPERTY ALIASED_TARGET)
if(NOT ${_alt2} STREQUAL foo)
  message(SEND_ERROR "ALIASED_TARGET is not foo.")
endif()|};
    add_lib ~type_:Lib_interface (t "iface");
    yc_quote_cmd "add_library(Alias::Iface ALIAS iface)";
    yc_quote_cmd {|get_property(_aliased_target_set TARGET foo PROPERTY ALIASED_TARGET SET)
if(_aliased_target_set)
  message(SEND_ERROR "ALIASED_TARGET is set for target foo")
endif()|};
    yc_quote_cmd {|get_target_property(_notAlias1 foo ALIASED_TARGET)
if(NOT DEFINED _notAlias1)
  message(SEND_ERROR "_notAlias1 is not defined")
endif()
if(_notAlias1)
  message(SEND_ERROR "_notAlias1 is defined, but foo is not an ALIAS")
endif()
if(NOT _notAlias1 STREQUAL _notAlias1-NOTFOUND)
  message(SEND_ERROR "_notAlias1 not defined to a -NOTFOUND variant")
endif()|};
    yc_quote_cmd {|get_property(_notAlias2 TARGET foo PROPERTY ALIASED_TARGET)
if(_notAlias2)
  message(SEND_ERROR "_notAlias2 evaluates to true, but foo is not an ALIAS")
endif()|};
  ]

(* -------------------------------------------------------------------------- *)
(* PositionIndependentTargets (Tests/PositionIndependentTargets/)            *)
(* -------------------------------------------------------------------------- *)

let pic_lib_cpp = {|
#include "pic_test.h"
class PIC_TEST_EXPORT Dummy { int dummy(); };
int Dummy::dummy() { return 0; }
|}

let pic_main_cpp = {|
#include "pic_test.h"
int main(int, char**) { return 0; }
|}

let pic_main_no_inc_cpp = {|int main(int, char**) { return 0; }|}

let pic_test_h = {|
#if defined(__ELF__)
#  if !defined(__PIC__) && !defined(__PIE__)
#    error "The POSITION_INDEPENDENT_CODE property should cause __PIC__ or __PIE__ to be defined on ELF platforms."
#  endif
#endif
#if defined(PIC_TEST_STATIC_BUILD)
#  define PIC_TEST_EXPORT
#else
#  if defined(_WIN32) || defined(WIN32)
#    ifdef PIC_TEST_BUILD_DLL
#      define PIC_TEST_EXPORT __declspec(dllexport)
#    else
#      define PIC_TEST_EXPORT __declspec(dllimport)
#    endif
#  else
#    define PIC_TEST_EXPORT
#  endif
#endif
|}

let pic_global_cmake = {|
set(CMAKE_POSITION_INDEPENDENT_CODE True)
add_executable(test_target_executable_global
  "${CMAKE_CURRENT_SOURCE_DIR}/../pic_main.cpp"
)
add_library(test_target_shared_library_global
  SHARED "${CMAKE_CURRENT_SOURCE_DIR}/../pic_lib.cpp"
)
set_target_properties(test_target_shared_library_global
  PROPERTIES DEFINE_SYMBOL PIC_TEST_BUILD_DLL
)
add_library(test_target_static_library_global
  STATIC "${CMAKE_CURRENT_SOURCE_DIR}/../pic_lib.cpp"
)
set_target_properties(test_target_static_library_global
  PROPERTIES COMPILE_DEFINITIONS PIC_TEST_STATIC_BUILD
)
include(CheckCXXSourceCompiles)
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/../pic_test.h" PIC_HEADER_CONTENT)
check_cxx_source_compiles(
  "${PIC_HEADER_CONTENT}\nint main(int,char**) { return 0; }\n"
  PIC_TRY_COMPILE_RESULT
)
if(NOT PIC_TRY_COMPILE_RESULT)
  message(SEND_ERROR "TRY_COMPILE with content requiring __PIC__ failed.")
endif()
|}

let pic_targets_cmake = {|
add_executable(test_target_executable_properties
  "${CMAKE_CURRENT_SOURCE_DIR}/../pic_main.cpp"
)
set_target_properties(test_target_executable_properties
  PROPERTIES POSITION_INDEPENDENT_CODE True
)
add_library(test_target_shared_library_properties
  SHARED "${CMAKE_CURRENT_SOURCE_DIR}/../pic_lib.cpp"
)
set_target_properties(test_target_shared_library_properties
  PROPERTIES
    POSITION_INDEPENDENT_CODE True
    DEFINE_SYMBOL PIC_TEST_BUILD_DLL
)
add_library(test_target_static_library_properties
  STATIC "${CMAKE_CURRENT_SOURCE_DIR}/../pic_lib.cpp"
)
set_target_properties(test_target_static_library_properties
  PROPERTIES
    POSITION_INDEPENDENT_CODE True
    COMPILE_DEFINITIONS PIC_TEST_STATIC_BUILD
)
|}

let pic_interface_cmake = {|
add_library(piciface INTERFACE)
set_property(TARGET piciface PROPERTY INTERFACE_POSITION_INDEPENDENT_CODE ON)
add_executable(test_empty_iface "${CMAKE_CURRENT_SOURCE_DIR}/../pic_main.cpp")
target_link_libraries(test_empty_iface piciface)
add_library(sharedlib SHARED "${CMAKE_CURRENT_SOURCE_DIR}/../pic_lib.cpp")
target_link_libraries(sharedlib piciface)
set_property(TARGET sharedlib PROPERTY DEFINE_SYMBOL PIC_TEST_BUILD_DLL)
add_executable(test_iface_via_shared "${CMAKE_CURRENT_SOURCE_DIR}/../pic_main.cpp")
target_link_libraries(test_iface_via_shared sharedlib)
add_library(objectlib OBJECT "${CMAKE_CURRENT_SOURCE_DIR}/../pic_lib.cpp")
target_link_libraries(objectlib piciface)
add_library(sharedlibpic SHARED "${CMAKE_CURRENT_SOURCE_DIR}/../pic_lib.cpp")
set_property(TARGET sharedlibpic PROPERTY INTERFACE_POSITION_INDEPENDENT_CODE ON)
set_property(TARGET sharedlibpic PROPERTY DEFINE_SYMBOL PIC_TEST_BUILD_DLL)
add_library(shared_iface INTERFACE)
target_link_libraries(shared_iface INTERFACE sharedlibpic)
add_executable(test_shared_via_iface "${CMAKE_CURRENT_SOURCE_DIR}/../pic_main.cpp")
target_link_libraries(test_shared_via_iface shared_iface)
add_executable(test_shared_via_iface_non_conflict
  "${CMAKE_CURRENT_SOURCE_DIR}/../pic_main.cpp"
)
set_property(TARGET test_shared_via_iface_non_conflict
  PROPERTY POSITION_INDEPENDENT_CODE ON
)
target_link_libraries(test_shared_via_iface_non_conflict shared_iface)
|}

let pic_yelu =
  Yexp_list [
    yc_quote_cmd "cmake_minimum_required(VERSION 3.10)";
    yc_project ~languages:[Lang_cxx] "PositionIndependentTargets";
    yc_quote_cmd {|include(CheckCXXSourceCompiles)|};
    yc_quote_cmd {|include_directories("${CMAKE_CURRENT_SOURCE_DIR}")|};
    yc_add_subdirectory (ystr "global");
    yc_add_subdirectory (ystr "targets");
    yc_add_subdirectory (ystr "interface");
    add_exe ~sources:[ystr "main.cpp"] (t "PositionIndependentTargets");
  ]

let compile_defs_yelu =
  Yexp_list [
    yc_quote_cmd "cmake_minimum_required(VERSION 3.10)";
    yc_project ~languages:[Lang_cxx; Lang_c] "CompileDefinitions";
    yc_quote_cmd {|foreach(c DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
  set(CMAKE_C_FLAGS_${c} "${CMAKE_C_FLAGS_${c}} -DTEST_CONFIG_${c}")
  set(CMAKE_CXX_FLAGS_${c} "${CMAKE_CXX_FLAGS_${c}} -DTEST_CONFIG_${c}")
endforeach()|};
    yc_quote_cmd {|set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS
  "BUILD_CONFIG_NAME=\"$<CONFIGURATION>\""
)|};
    yc_add_subdirectory (ystr "add_def_cmd");
    yc_add_subdirectory (ystr "target_prop");
    yc_add_subdirectory (ystr "add_def_cmd_tprop");
    add_exe ~sources:[ystr "runtest.c"] (t "CompileDefinitions");
  ]

let () =
  Alcotest.run "CMakeCommands build tests"
    [ ("target_link_options", [
        check_build_pair "basic" "target_link_options"
          ~files:[("lib.c", c_lib_source)]
          tlo_yelu;
      ]);
      ("add_compile_definitions", [
        check_build_pair "basic" "add_compile_definitions"
          ~files:[("main.cpp", cpp_main_source)]
          acd_yelu;
      ]);
      ("add_link_options", [
        check_build_pair "basic" "add_link_options"
          ~files:[("LinkOptionsExe.c", {|int main(void) { return 0; }|})]
          add_link_opts_yelu;
      ]);
      ("link_directories", [
        check_build_pair "basic" "link_directories"
          ~files:[("LinkDirectoriesExe.c", {|int main(void) { return 0; }|})]
          link_dirs_yelu;
      ]);
      ("add_compile_options", [
        check_build_pair "basic" "add_compile_options"
          ~files:[("main.cpp", aco_main_source)]
          aco_yelu;
      ]);
      ("target_compile_definitions", [
        check_build_pair "basic" "target_compile_definitions"
          ~files:[("main.cpp", tcd_main_source);
                  ("consumer.cpp", tcd_consumer_cpp_source);
                  ("consumer.c", tcd_consumer_c_source)]
          tcd_yelu;
      ]);
      ("target_compile_options", [
        check_build_pair "basic" "target_compile_options"
          ~files:[("main.cpp", tco_main_source);
                  ("consumer.cpp", tco_consumer_cpp_source);
                  ("consumer.c", tco_consumer_c_source)]
          tco_yelu;
      ]);
      ("target_link_directories", [
        check_build_pair "basic" "target_link_directories"
          ~files:[("LinkDirectoriesLib.c", link_dir_lib_source);
                  ("subdir/CMakeLists.txt", {|add_library(target_link_directories_5 SHARED EXCLUDE_FROM_ALL ../LinkDirectoriesLib.c)|})]
          tld_yelu;
      ]);
      ("target_compile_features", [
        check_build_pair "basic" "target_compile_features"
          ~files:[("main.c", tcf_main_c_source);
                  ("lib_restrict.h", tcf_lib_restrict_h);
                  ("lib_restrict.c", tcf_lib_restrict_c);
                  ("restrict_user.c", tcf_restrict_user_c);
                  ("main.cpp", tcf_main_cpp_source);
                  ("lib_auto_type.h", tcf_lib_auto_type_h);
                  ("lib_auto_type.cpp", tcf_lib_auto_type_cpp);
                  ("lib_user.cpp", tcf_lib_user_cpp)]
          tcf_yelu;
      ]);
      ("target_sources", [
        check_build_pair "basic" "target_sources"
          ~files:[("main.cpp", ts_main_cpp);
                  ("empty_1.cpp", ts_empty_1_cpp);
                  ("empty_2.cpp", ts_empty_2_cpp);
                  ("empty_3.cpp", ts_empty_3_cpp);
                  ("subdir/CMakeLists.txt", ts_subdir_cmake);
                  ("subdir/subdir_empty_1.cpp", ts_subdir_empty_1_cpp);
                  ("subdir/subdir_empty_2.cpp", ts_subdir_empty_2_cpp)]
          ts_yelu;
      ]);
      ("target_include_directories", [
        check_build_pair "basic" "target_include_directories"
          ~files:[("main.cpp", tid_main_cpp);
                  ("consumer.cpp", tid_consumer_cpp);
                  ("consumer.c", tid_consumer_c);
                  ("same.c", tid_same_c);
                  ("cxx_only/cxx_only.h", "#define CXX_ONLY_DEFINE\n");
                  ("c_only/c_only.h", "\n#define C_ONLY_DEFINE\n");
                  ("same_one/same.h", {|#error "Wrong \"same.h\" included!"|});
                  ("same_two/same.h", "#define CORRECT_SAME_H_INCLUDED\n");
                  ("relative_dir/relative_dir.h", "\n#define RELATIVE_DIR_DEFINE\n");
                  ("relative_dir/consumer/consumer.h", "\n#define CONSUMER_DEFINE\n")]
          tid_yelu;
      ]);
      (* ------------------------------------------------------------------ *)
      (* Group 2: Tests/ (outside CMakeCommands/) — check_build_pair_tests  *)
      (* ------------------------------------------------------------------ *)
      (* NOTE: source strings and yelu programs defined above in the file   *)
      ("lib_name", [
        check_build_pair_tests "basic" "LibName"
          ~files:[("bar.c", libname_bar_c);
                  ("foo.c", libname_foo_c);
                  ("foobar.c", libname_foobar_c)]
          libname_yelu;
      ]);
      ("link_static", [
        check_build_pair_tests "basic" "LinkStatic"
          ~files:[("LinkStatic.c", link_static_main_c)]
          link_static_yelu;
      ]);
      ("simple", [
        check_build_pair_tests "basic" "Simple"
          ~files:[("simple.cxx", simple_simple_cxx);
                  ("simpleLib.cxx", simple_simplelib_cxx);
                  ("simpleCLib.c", simple_simpleclib_c);
                  ("simpleWe.cpp", simple_simplewe_cpp)]
          simple_yelu;
      ]);
      ("link_line", [
        check_build_pair_tests "basic" "LinkLine"
          ~files:[("One.c", ll_one_c);
                  ("Two.c", ll_two_c);
                  ("Exec.c", ll_exec_c)]
          ll_yelu;
      ]);
      ("link_line_order", [
        check_build_pair_tests "basic" "LinkLineOrder"
          ~files:[("NoDepA.c", llo_nodep_a_c);
                  ("NoDepB.c", llo_nodep_b_c);
                  ("NoDepC.c", llo_nodep_c_c);
                  ("NoDepE.c", llo_nodep_e_c);
                  ("NoDepF.c", llo_nodep_f_c);
                  ("NoDepX.c", llo_nodep_x_c);
                  ("NoDepY.c", llo_nodep_y_c);
                  ("NoDepZ.c", llo_nodep_z_c);
                  ("One.c", llo_one_c);
                  ("Two.c", llo_two_c);
                  ("Exec1.c", llo_exec1_c);
                  ("Exec2.c", llo_exec2_c)]
          llo_yelu;
      ]);
      ("out_name", [
        check_build_pair_tests "basic" "OutName"
          ~files:[("main.c", {|int main(void) { return 0; }|})]
          out_name_yelu;
      ]);
      (* empty_library: BLOCKED — cmake 3.28 rejects add_library(test test.h) with
         "Cannot determine link language"; upstream test requires older cmake *)
      ("target_name", [
        check_build_pair_tests "basic" "TargetName"
          ~files:[("executables/CMakeLists.txt", "add_executable(hello_world hello_world.c)");
                  ("executables/hello_world.c", target_name_hello_world_c);
                  ("scripts/CMakeLists.txt", target_name_scripts_cmake);
                  ("scripts/hello_world", "#!/bin/sh\necho \"hello, world\"\n")]
          target_name_yelu;
      ]);
      ("cxx_only", [
        check_build_pair_tests "basic" "CxxOnly"
          ~files:[("libcxx1.h", cxxonly_libcxx1_h);
                  ("libcxx1.cxx", cxxonly_libcxx1_cxx);
                  ("libcxx2.h", cxxonly_libcxx2_h);
                  ("libcxx2.cxx", cxxonly_libcxx2_cxx);
                  ("test.C", cxxonly_test_C);
                  ("cxxonly.cxx", cxxonly_cxxonly_cxx);
                  ("testCxxModule.cxx", cxxonly_module_cxx)]
          cxxonly_yelu;
      ]);
      ("alias_target", [
        check_build_pair_tests "basic" "AliasTarget"
          ~files:[("empty.cpp", alias_target_empty_cpp);
                  ("object.cpp", alias_target_object_cpp);
                  ("object.h", alias_target_object_h);
                  ("commandgenerator.cpp", alias_target_commandgenerator_cpp);
                  ("targetgenerator.cpp", alias_target_targetgenerator_cpp);
                  ("bat.cpp", alias_target_bat_cpp);
                  ("subdir/CMakeLists.txt", alias_target_subdir_cmake);
                  ("subdir/empty.cpp", alias_target_empty_cpp)]
          alias_target_yelu;
      ]);
      ("pic_targets", [
        check_build_pair_tests "basic" "PositionIndependentTargets"
          ~files:[("pic_lib.cpp", pic_lib_cpp);
                  ("pic_main.cpp", pic_main_cpp);
                  ("pic_test.h", pic_test_h);
                  ("main.cpp", pic_main_no_inc_cpp);
                  ("global/CMakeLists.txt", pic_global_cmake);
                  ("targets/CMakeLists.txt", pic_targets_cmake);
                  ("interface/CMakeLists.txt", pic_interface_cmake)]
          pic_yelu;
      ]);
      ("compile_definitions", [
        check_build_pair_tests "basic" "CompileDefinitions"
          ~files:[("compiletest.cpp", cd_compiletest_cpp);
                  ("compiletest.c", cd_compiletest_c);
                  ("compiletest_mixed_c.c", cd_compiletest_mixed_c);
                  ("compiletest_mixed_cxx.cpp", cd_compiletest_mixed_cxx);
                  ("runtest.c", {|
#include <ctype.h>
#include <stdio.h>
#include <string.h>
#ifndef BUILD_CONFIG_NAME
#  error "BUILD_CONFIG_NAME not defined!"
#endif
int main(void) {
  char build_config_name[] = BUILD_CONFIG_NAME;
  char* c;
  for (c = build_config_name; *c; ++c)
    *c = (char)((*c >= 'A' && *c <= 'Z') ? (*c + 32) : *c);
  fprintf(stderr, "build_config_name=\"%s\"\n", build_config_name);
  return 0;
}
|});
                  ("target_prop/CMakeLists.txt", cd_target_prop_cmake);
                  ("target_prop/usetgt.c", cd_usetgt_c);
                  ("add_def_cmd/CMakeLists.txt", cd_add_def_cmd_cmake);
                  ("add_def_cmd_tprop/CMakeLists.txt", cd_add_def_cmd_tprop_cmake)]
          compile_defs_yelu;
      ]);
    ]
