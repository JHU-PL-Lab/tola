open Base
open Lang_cmake

let version_of_string s =
  Stdlib.Scanf.sscanf s "%d.%d.%s" (fun major minor patch ->
      { major; minor; patch })

let string_of_version ver =
  let str_patch = if String.length ver.patch = 0 then "" else "." ^ ver.patch in
  Fmt.str "%d.%d%s" ver.major ver.minor str_patch

let str_ s = Bare s
let quote s = Quoted s
let bool_ b = str_ (if b then "ON" else "OFF")
let target_def ?(kind = "PUBLIC") items = { kind; items }
let target_feature ?(kind = "PUBLIC") feature = { kind; feature }
let cmd_of_list cmds = Exp_list cmds

let include_ ?(optional = false) ?result_var ?no_policy_scope file =
  Include { file; optional; result_var; no_policy_scope }

let ite cond then_ ?else_ () =
  match else_ with
  | None -> If { cond; then_; else_ = None }
  | Some else_ -> If { cond; then_; else_ = Some else_ }

let ifthen cond then_ = ite cond then_ ()
let if_ cond then_ else_ = ite cond then_ ~else_ ()
let function_ name args cmds = Function { name; args; cmds }
let apply name args = Apply { name; args }
let custom_command command args : Lang_cmake.custom_command = { command; args }
let list_append var values = List_append { var; values }

let minimum_required_s ?max min =
  Cmake_cmd
    (Cmake_minimum_required
       {
         min = version_of_string min;
         max = Option.map ~f:version_of_string max;
       })

let project ?version ?description ?homepage_url ?(languages = []) name =
  Project_cmd (Project { name; version; description; homepage_url; languages })

let option_ ?(value = bool_ false) ~msg var = Cmake_option { var; msg; value }
let export_targets targets = Project_cmd (Export_targets { targets })
let export_export ?file name = Project_cmd (Export_export { file; name })
let export_package name = Project_cmd (Export_package { name })
let export_setup name = Project_cmd (Export_setup { name })
let quote_cmd s = Quote s

let add_library ?(exclude_from_all = false) ?type_ ?(sources = []) name =
  Project_cmd (Add_library { name; type_; exclude_from_all; sources })

let add_executable ?(options = []) ?(sources = []) name =
  Project_cmd (Add_executable { name; options; sources })

let configure_file ?(permissions = []) ?permission_level ?copy_only
    ?escape_quotes ?only ?newline_style ~input output =
  Cmake_cmd
    (Configure_file
       {
         input;
         output;
         permission_level;
         permissions;
         copy_only;
         escape_quotes;
         only;
         newline_style;
       })

let set ?(parent_scope = false) var values = Set { var; values; parent_scope }

let add_subdirectory ?binary_dir ?(exclude_from_all = false) ?(system = false)
    source_dir =
  Project_cmd
    (Add_subdirectory { source_dir; binary_dir; exclude_from_all; system })

let add_custom_command ~outputs ?main_dependency ?(depends = [])
    ?(byproducts = []) ?(implicit_depends = []) ?working_directory ?comment
    ?depfile ?job_pool ?(job_server_aware = false) ?(verbatim = false)
    ?(append = false) ?(uses_terminal = false) ?(codegen = false)
    ?(command_expand_list = []) ?(depends_explicit_only = false) commands =
  Project_cmd
    (Add_custom_command
       {
         outputs;
         commands;
         main_dependency;
         depends;
         byproducts;
         implicit_depends;
         working_directory;
         comment;
         depfile;
         job_pool;
         job_server_aware;
         verbatim;
         append;
         uses_terminal;
         codegen;
         command_expand_list;
         depends_explicit_only;
       })

let target_compile_definitions target items =
  Project_cmd (Target_compile_definitions { target; items })

let target_compile_features target features =
  Project_cmd (Target_compile_features { target; features })

let target_compile_options ?(before = false) target items =
  Project_cmd (Target_compile_options { target; before; items })

let target_include_directories ?system ?before_or_after target items =
  Project_cmd
    (Target_include_directories { target; system; before_or_after; items })

let target_link_libraries targets items =
  Project_cmd (Target_link_libraries { targets; items })

let install_targets ?component ?rename ?export ?(permissions = []) targets
    destination =
  Project_cmd
    (Install_targets
       { targets; destination; permissions; component; rename; export })

let install_export ?file ?component ?rename ?(permissions = []) export
    destination =
  Project_cmd
    (Install_export
       { file; destination; permissions; component; rename; export })

let install_files ?component ?rename ?(permissions = []) files destination =
  Project_cmd
    (Install_files { files; destination; permissions; component; rename })

(* testing *)
let enable_testing = Project_cmd Enable_testing

let add_test ?dir name command args =
  Project_cmd (Add_test { name; command; args; dir })

let set_property ?(global = false) ?(directory = []) ?(targets = [])
    ?(sources = []) ?(source_directories = []) ?(source_target_directories = [])
    ?(installs = []) ?(tests = []) ?(test_directories = []) ?(caches = [])
    ?(append = false) ?(append_string = false) prop_value_pairs =
  let properties =
    List.map ~f:(fun (prop, value) -> { prop; value }) prop_value_pairs
  in
  Set_property
    {
      global;
      directory;
      targets;
      sources;
      source_directories;
      source_target_directories;
      installs;
      tests;
      test_directories;
      caches;
      append;
      append_string;
      properties;
    }

let set_target_properties target prop_value_pairs =
  let properties =
    List.map ~f:(fun (prop, value) -> { prop; value }) prop_value_pairs
  in
  Project_cmd (Set_target_properties { target; properties })

let set_tests_properties ?dir tests prop_value_pairs =
  let properties =
    List.map ~f:(fun (prop, value) -> { prop; value }) prop_value_pairs
  in
  Project_cmd (Set_tests_properties { tests; dir; properties })

let configure_package_config_file ?(path_vars = [])
    ?(no_set_and_check_macro = false)
    ?(no_check_required_components_macro = false) install_dest input output =
  Module_cmd
    (Configure_package_config_file
       {
         input;
         output;
         install_dest;
         path_vars;
         no_set_and_check_macro;
         no_check_required_components_macro;
       })

let write_basic_package_version_file ~compatibility ?(arch_independent = false)
    ?version file =
  Module_cmd
    (Write_basic_package_version_file
       { file; version; compatibility; arch_independent })
