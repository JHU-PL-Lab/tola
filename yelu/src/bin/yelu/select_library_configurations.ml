open Yelu_langs.Lang_yelu
open Yelu_langs.Lang_yelu_utils
open Yelu_langs.Lang_cmake
open Step_common

(* cmake Tests/CMakeOnly/SelectLibraryConfigurations/CMakeLists.txt *)

(* macro(check_slc basename expect) *)
let check_slc_macro =
  yc_macro (ystr "check_slc") ~args:[ "basename"; "expect" ]
    [
      yc_message ~mode:Mm_status
        [ "checking select_library_configurations(${basename})" ];
      yc_apply (ystr "select_library_configurations") [ ystr "${basename}" ];
      yifthen
        (Ynot (ystrequal (ystr_raw "${${basename}_LIBRARY}") (ystr_raw "${expect}")))
        (yc_message ~mode:Mm_send_error
           [
             "select_library_configurations(${basename}) returned \
              '${${basename}_LIBRARY}' but '${expect}' was expected";
           ]);
      yifthen
        (Ynot
           (ystrequal
              (ystr_raw "${${basename}_LIBRARY}")
              (ystr_raw "${${basename}_LIBRARIES}")))
        (yc_message ~mode:Mm_send_error
           [
             "select_library_configurations(${basename}) LIBRARY: \
              '${${basename}_LIBRARY}' LIBRARIES: '${${basename}_LIBRARIES}'";
           ]);
    ]

let notype_block =
  ycmd_of_list
    [
      yc_set (ycstr "NOTYPE_RELONLY_LIBRARY_RELEASE") [ ystr "opt" ];
      yc_apply (ystr "check_slc") [ ystr "NOTYPE_RELONLY"; ystr_raw "opt" ];
      yc_set (ycstr "NOTYPE_DBGONLY_LIBRARY_DEBUG") [ ystr "dbg" ];
      yc_apply (ystr "check_slc") [ ystr "NOTYPE_DBGONLY"; ystr_raw "dbg" ];
      yc_set (ycstr "NOTYPE_RELDBG_LIBRARY_RELEASE") [ ystr "opt" ];
      yc_set (ycstr "NOTYPE_RELDBG_LIBRARY_DEBUG") [ ystr "dbg" ];
      yc_apply (ystr "check_slc") [ ystr "NOTYPE_RELDBG"; ystr_raw "opt" ];
      yc_set (ycstr "CMAKE_BUILD_TYPE") [ ystr "Debug" ];
    ]

let cmd =
  ycmd_of_list
    [
      yc_minimum_required_s "3.10.";
      yc_project ~languages:[ Lang_none ] "SelectLibraryConfigurations";
      yc_include (ycref_path "CMAKE_ROOT" "Modules/SelectLibraryConfigurations.cmake");
      check_slc_macro;
      yc_get_global_property ~property:"GENERATOR_IS_MULTI_CONFIG"
        (ycstr "_isMultiConfig");
      yifthen
        (Yand
           ( Ynot (Ytruthy (ycstr "_isMultiConfig")),
             Ynot (Ytruthy (ycstr "CMAKE_BUILD_TYPE")) ))
        notype_block;
      yc_apply (ystr "check_slc") [ ystr "empty"; ystr_raw "empty_LIBRARY-NOTFOUND" ];
      yc_set (ycstr "OPTONLY_LIBRARY_RELEASE") [ ystr "opt" ];
      yc_apply (ystr "check_slc") [ ystr "OPTONLY"; ystr_raw "opt" ];
      yc_set (ycstr "DBGONLY_LIBRARY_RELEASE") [ ystr "dbg" ];
      yc_apply (ystr "check_slc") [ ystr "DBGONLY"; ystr_raw "dbg" ];
      yc_set (ycstr "SAME_LIBRARY_RELEASE") [ ystr "same" ];
      yc_set (ycstr "SAME_LIBRARY_DEBUG") [ ystr "same" ];
      yc_apply (ystr "check_slc") [ ystr "SAME"; ystr_raw "same" ];
      yc_set (ycstr "OPTONLYLIST_LIBRARY_RELEASE") [ ystr "opt1;opt2" ];
      yc_apply (ystr "check_slc") [ ystr "OPTONLYLIST"; ystr_raw "opt1;opt2" ];
      yc_set (ycstr "DBGONLYLIST_LIBRARY_RELEASE") [ ystr "dbg1;dbg2" ];
      yc_apply (ystr "check_slc") [ ystr "DBGONLYLIST"; ystr_raw "dbg1;dbg2" ];
      yc_set (ycstr "OPT1DBG1_LIBRARY_RELEASE") [ ystr "opt" ];
      yc_set (ycstr "OPT1DBG1_LIBRARY_DEBUG") [ ystr "dbg" ];
      yc_apply (ystr "check_slc")
        [ ystr "OPT1DBG1"; ystr_raw "optimized;opt;debug;dbg" ];
      yc_set (ycstr "OPT1DBG2_LIBRARY_RELEASE") [ ystr "opt" ];
      yc_set (ycstr "OPT1DBG2_LIBRARY_DEBUG") [ ystr "dbg1;dbg2" ];
      yc_apply (ystr "check_slc")
        [ ystr "OPT1DBG2"; ystr_raw "optimized;opt;debug;dbg1;debug;dbg2" ];
      yc_set (ycstr "OPT2DBG1_LIBRARY_RELEASE") [ ystr "opt1;opt2" ];
      yc_set (ycstr "OPT2DBG1_LIBRARY_DEBUG") [ ystr "dbg" ];
      yc_apply (ystr "check_slc")
        [ ystr "OPT2DBG1"; ystr_raw "optimized;opt1;optimized;opt2;debug;dbg" ];
      yc_set (ycstr "OPT2DBG2_LIBRARY_RELEASE") [ ystr "opt1;opt2" ];
      yc_set (ycstr "OPT2DBG2_LIBRARY_DEBUG") [ ystr "dbg1;dbg2" ];
      yc_apply (ystr "check_slc")
        [
          ystr "OPT2DBG2";
          ystr_raw "optimized;opt1;optimized;opt2;debug;dbg1;debug;dbg2";
        ];
    ]

let () = print_cmake cmd
