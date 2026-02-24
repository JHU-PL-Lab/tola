open Base
open Lang_yelu

let yvar s = Yvar s
let ytarget s = Ytarget s
let ystr s = Yarg_var (Yvar s)
let ytval s = Yarg_target (Ytarget s)
let ybare s = Yarg_bare s
let yraw s = Yarg_raw s
let ybool b = Yarg_bool b

(* Extern declarations *)
let yextern_var s = Yextern_var (Yvar s)
let yextern_target s = Yextern_target (Ytarget s)
let ytarget_def ?(kind = Public) items : yelu_items_with_kind = { kind; items }
let ytarget_feature ?(kind = Public) feature : yelu_target_feature =
  { kind; feature }
let ycmd_of_list cmds = Yexp_list cmds
let custom_command command args : Lang_cmake.custom_command = { command; args }

let yminimum_required_s ?max min =
  Ycmake_minimum_required
    {
      min = Lang_cmake_utils.version_of_string min;
      max = Option.map ~f:Lang_cmake_utils.version_of_string max;
    }

let yproject ?version ?(languages = []) name =
  Yproject { name; version; languages }

let yset ?(parent_scope = false) var values =
  Yset { var; values; parent_scope }

let yadd_executable ?(sources = []) name =
  Yadd_executable { name; sources }

let yadd_library ?(exclude_from_all = false) ?type_ ?(sources = []) name =
  Yadd_library { name; type_; exclude_from_all; sources }

let ytarget_include_directories target items =
  Ytarget_include_directories { target; items }

let ytarget_link_libraries targets items =
  Ytarget_link_libraries { targets; items }

let ytarget_compile_definitions target items =
  Ytarget_compile_definitions { target; items }

let ytarget_compile_features target features =
  Ytarget_compile_features { target; features }

let ytarget_compile_options ?(before = false) target items =
  Ytarget_compile_options { target; before; items }

let yconfigure_file ~input output = Yconfigure_file { input; output }
let yadd_subdirectory source_dir = Yadd_subdirectory { source_dir }

let yoption ?(value = ybool false) ~msg var = Yoption { var; msg; value }

let yite cond then_ ?else_ () =
  match else_ with
  | None -> Yif { cond; then_; else_ = None }
  | Some else_ -> Yif { cond; then_; else_ = Some else_ }

let yifthen cond then_ = yite cond then_ ()
let yif cond then_ else_ = yite cond then_ ~else_ ()

(* scripting *)
let yinclude ?(optional = false) file = Yinclude { file; optional }
let yfunction name args body = Yfunction { name; args; body }
let yapply name args = Yapply { name; args }
let yquote_cmd s = Yquote_cmd s
let ylist_append var values = Ylist_append { var; values }

(* testing *)
let yenable_testing = Yenable_testing
let yadd_test name command args = Yadd_test { name; command; args }
let yset_tests_properties tests properties =
  Yset_tests_properties { tests; properties }

(* target properties *)
let yset_target_properties target properties =
  Yset_target_properties { target; properties }

let yset_property ~targets properties =
  Yset_property { targets; properties }

(* install *)
let yinstall_targets ?export targets destination =
  Yinstall_targets { targets; destination; export }

let yinstall_files files destination =
  Yinstall_files { files; destination }

let yinstall_export ?file export destination =
  Yinstall_export { file; export; destination }

(* export *)
let yexport_export ?file name = Yexport_export { name; file }

(* module commands *)
let yconfigure_package_config_file ?(no_set_and_check_macro = false)
    ?(no_check_required_components_macro = false) install_dest input output =
  Yconfigure_package_config_file
    { install_dest; input; output; no_set_and_check_macro;
      no_check_required_components_macro }

let ywrite_basic_package_version_file ~compatibility ?version file =
  Ywrite_basic_package_version_file { file; version; compatibility }

(* custom commands *)
let yadd_custom_command ~outputs ?(depends = []) commands =
  Yadd_custom_command { outputs; commands; depends }
