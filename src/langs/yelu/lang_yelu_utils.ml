open Base
open Lang_yelu

let ycvar s = Ycvar s
let ytarget s = Ytarget s
let yvar s = Yarg_var (Yvar s)
let ylet name value = Ylet { var = Yvar name; value }
let ycstr s = Yarg_cvar (Ycvar s)
let ytval s = Yarg_target (Ytarget s)
let ybare s = Yarg_bare s
let yraw s = Yarg_raw s
let ybool b = Yarg_bool b

(* Extern declarations *)
let yc_extern_cvar s = Yc_extern_cvar (Ycvar s)
let yc_extern_target s = Yc_extern_target (Ytarget s)
let ytarget_def ?(kind = Public) items : yelu_items_with_kind = { kind; items }
let ytarget_feature ?(kind = Public) feature : yelu_target_feature =
  { kind; feature }
let ycmd_of_list cmds = Yexp_list cmds
let custom_command command args : Lang_cmake.custom_command = { command; args }

let yc_minimum_required_s ?max min =
  Yc_minimum_required
    {
      min = Lang_cmake_utils.version_of_string min;
      max = Option.map ~f:Lang_cmake_utils.version_of_string max;
    }

let yc_project ?version ?(languages = []) name =
  Yc_project { name; version; languages }

let yc_set ?(parent_scope = false) cvar values =
  Yc_set { cvar; values; parent_scope }

let yc_add_executable ?(sources = []) name =
  Yc_add_executable { name; sources }

let yc_add_library ?(exclude_from_all = false) ?type_ ?(sources = []) name =
  Yc_add_library { name; type_; exclude_from_all; sources }

let yc_target_include_directories target items =
  Yc_target_include_directories { target; items }

let yc_target_link_libraries targets items =
  Yc_target_link_libraries { targets; items }

let yc_target_compile_definitions target items =
  Yc_target_compile_definitions { target; items }

let yc_target_compile_features target features =
  Yc_target_compile_features { target; features }

let yc_target_compile_options ?(before = false) target items =
  Yc_target_compile_options { target; before; items }

let yc_configure_file ~input output = Yc_configure_file { input; output }
let yc_add_subdirectory source_dir = Yc_add_subdirectory { source_dir }

let yc_option ?(value = ybool false) ~msg cvar = Yc_option { cvar; msg; value }

let yite cond then_ ?else_ () =
  match else_ with
  | None -> Yif { cond; then_; else_ = None }
  | Some else_ -> Yif { cond; then_; else_ = Some else_ }

let yifthen cond then_ = yite cond then_ ()
let yif cond then_ else_ = yite cond then_ ~else_ ()

(* scripting *)
let yc_include ?(optional = false) file = Yc_include { file; optional }
let yc_function name args body = Yc_function { name; args; body }
let yc_apply name args = Yc_apply { name; args }
let yc_quote_cmd s = Yc_quote_cmd s
let yc_list_append cvar values = Yc_list_append { cvar; values }

(* testing *)
let yc_enable_testing = Yc_enable_testing
let yc_add_test name command args = Yc_add_test { name; command; args }
let yc_set_tests_properties tests properties =
  Yc_set_tests_properties { tests; properties }

(* target properties *)
let yc_set_target_properties target properties =
  Yc_set_target_properties { target; properties }

let yc_set_property ~targets properties =
  Yc_set_property { targets; properties }

(* install *)
let yc_install_targets ?export targets destination =
  Yc_install_targets { targets; destination; export }

let yc_install_files files destination =
  Yc_install_files { files; destination }

let yc_install_export ?file export destination =
  Yc_install_export { file; export; destination }

(* export *)
let yc_export_export ?file name = Yc_export_export { name; file }

(* module commands *)
let yc_configure_package_config_file ?(no_set_and_check_macro = false)
    ?(no_check_required_components_macro = false) install_dest input output =
  Yc_configure_package_config_file
    { install_dest; input; output; no_set_and_check_macro;
      no_check_required_components_macro }

let yc_write_basic_package_version_file ~compatibility ?version file =
  Yc_write_basic_package_version_file { file; version; compatibility }

(* custom commands *)
let yc_add_custom_command ~outputs ?(depends = []) commands =
  Yc_add_custom_command { outputs; commands; depends }
