(** Lower [Lang_yelu_param] expressions (instantiated with cmake substrate)
    to [Lang_yelu] expressions.

    The lowering is mechanical: every parametric constructor maps to the
    same-named constructor in [Lang_yelu]. Because field names also match,
    most cases are pure pattern-rebuilds.

    Naming:
      [P]  = parametric module ([Lang_yelu_param])
      [L]  = concrete cmake-pack module ([Lang_yelu])
      [PE] = parametric expression instantiated with cmake substrate
*)

module P = Lang_yelu_param
module L = Lang_yelu

(* Cmake substrate instantiation *)
module Cmake_types = struct
  type var = L.yelu_cvar
  type arg = L.yelu_arg
  type target = L.yelu_target
end

(* Full parametric expression at cmake substrate *)
module PE = P.Make_exp (Cmake_types)

(* ------------------------------------------------------------
   String ops
   ------------------------------------------------------------ *)
let lower_json_op (op : PE.String_op.Json.op) : L.yelu_json_op =
  match op with
  | Yjop_get { json; path } -> Yjop_get { json; path }
  | Yjop_get_raw { json; path } -> Yjop_get_raw { json; path }
  | Yjop_type { json; path } -> Yjop_type { json; path }
  | Yjop_length { json; path } -> Yjop_length { json; path }
  | Yjop_member { json; path } -> Yjop_member { json; path }
  | Yjop_remove { json; path } -> Yjop_remove { json; path }
  | Yjop_set { json; path; value } -> Yjop_set { json; path; value }
  | Yjop_equal { json1; json2 } -> Yjop_equal { json1; json2 }
  | Yjop_string_encode { value } -> Yjop_string_encode { value }

let lower_string_op (s : PE.String_op.t) : L.yelu_string_exp =
  match s with
  | Ystr_toupper { string; out } -> Ystr_toupper { string; out }
  | Ystr_tolower { string; out } -> Ystr_tolower { string; out }
  | Ystr_length { string; out } -> Ystr_length { string; out }
  | Ystr_strip { string; out } -> Ystr_strip { string; out }
  | Ystr_concat { out; inputs } -> Ystr_concat { out; inputs }
  | Ystr_replace { match_string; replace_string; out; inputs } ->
      Ystr_replace { match_string; replace_string; out; inputs }
  | Ystr_regex_match { regex; out; inputs } ->
      Ystr_regex_match { regex; out; inputs }
  | Ystr_regex_matchall { regex; out; inputs } ->
      Ystr_regex_matchall { regex; out; inputs }
  | Ystr_regex_replace { regex; replace; out; inputs } ->
      Ystr_regex_replace { regex; replace; out; inputs }
  | Ystr_regex_quote { out; inputs } -> Ystr_regex_quote { out; inputs }
  | Ystr_append { cvar; inputs } -> Ystr_append { cvar; inputs }
  | Ystr_prepend { cvar; inputs } -> Ystr_prepend { cvar; inputs }
  | Ystr_join { glue; out; inputs } -> Ystr_join { glue; out; inputs }
  | Ystr_find { string; substring; out; reverse } ->
      Ystr_find { string; substring; out; reverse }
  | Ystr_substring { string; begin_; length; out } ->
      Ystr_substring { string; begin_; length; out }
  | Ystr_repeat { string; count; out } ->
      Ystr_repeat { string; count; out }
  | Ystr_genex_strip { string; out } -> Ystr_genex_strip { string; out }
  | Ystr_compare { op; string1; string2; out } ->
      Ystr_compare { op; string1; string2; out }
  | Ystr_make_c_identifier { string; out } ->
      Ystr_make_c_identifier { string; out }
  | Ystr_timestamp { out; format; utc } ->
      Ystr_timestamp { out; format; utc }
  | Ystr_hex { string; out } -> Ystr_hex { string; out }
  | Ystr_uuid { out; namespace; name; type_; upper } ->
      Ystr_uuid { out; namespace; name; type_; upper }
  | Ystr_json { out; error_var; op } ->
      Ystr_json { out; error_var; op = lower_json_op op }

(* ------------------------------------------------------------
   List ops
   ------------------------------------------------------------ *)
let lower_list_op (l : PE.List_op.t) : L.yelu_list_exp =
  match l with
  | Ylist_append { cvar; values } -> Ylist_append { cvar; values }
  | Ylist_length { cvar; out } -> Ylist_length { cvar; out }
  | Ylist_get { cvar; indices; out } -> Ylist_get { cvar; indices; out }
  | Ylist_remove_item { cvar; values } -> Ylist_remove_item { cvar; values }
  | Ylist_remove_duplicates { cvar } -> Ylist_remove_duplicates { cvar }
  | Ylist_reverse { cvar } -> Ylist_reverse { cvar }
  | Ylist_sort { cvar; order; compare; case } ->
      Ylist_sort { cvar; order; compare; case }
  | Ylist_filter { cvar; mode; regex } ->
      Ylist_filter { cvar; mode; regex }
  | Ylist_join { cvar; glue; out } -> Ylist_join { cvar; glue; out }
  | Ylist_sublist { cvar; begin_; length; out } ->
      Ylist_sublist { cvar; begin_; length; out }
  | Ylist_find { cvar; value; out } -> Ylist_find { cvar; value; out }
  | Ylist_prepend { cvar; values } -> Ylist_prepend { cvar; values }
  | Ylist_insert { cvar; index; values } ->
      Ylist_insert { cvar; index; values }
  | Ylist_remove_at { cvar; indices } -> Ylist_remove_at { cvar; indices }
  | Ylist_pop_back { cvar; out_vars } -> Ylist_pop_back { cvar; out_vars }
  | Ylist_pop_front { cvar; out_vars } -> Ylist_pop_front { cvar; out_vars }
  | Ylist_transform { cvar; action; selector; output } ->
      Ylist_transform { cvar; action; selector; output }

(* ------------------------------------------------------------
   File ops
   ------------------------------------------------------------ *)
let lower_file_op (f : PE.File_op.t) : L.yelu_file_exp =
  match f with
  (* file IO *)
  | Yfile_read { out; file; offset; limit; hex } ->
      Yfile_read { out; file; offset; limit; hex }
  | Yfile_write { file; append; content } ->
      Yfile_write { file; append; content }
  | Yfile_strings { out; file; regex; encoding; limit_count } ->
      Yfile_strings { out; file; regex; encoding; limit_count }
  (* file filesystem *)
  | Yfile_touch { files; nocreate } -> Yfile_touch { files; nocreate }
  | Yfile_make_directory { dirs } -> Yfile_make_directory { dirs }
  | Yfile_rename { old_; new_; result; no_replace } ->
      Yfile_rename { old_; new_; result; no_replace }
  | Yfile_remove { files; recurse } -> Yfile_remove { files; recurse }
  | Yfile_copy { input; output; result; only_if_different } ->
      Yfile_copy { input; output; result; only_if_different }
  (* file path queries *)
  | Yfile_real_path { out; path; base_dir; expand_tilde } ->
      Yfile_real_path { out; path; base_dir; expand_tilde }
  | Yfile_size { out; file } -> Yfile_size { out; file }
  | Yfile_read_symlink { out; link } -> Yfile_read_symlink { out; link }
  | Yfile_timestamp { out; file; format; utc } ->
      Yfile_timestamp { out; file; format; utc }
  | Yfile_relative_path { var; base; file } ->
      Yfile_relative_path { var; base; file }
  | Yfile_glob { out; recurse; relative; configure_depends; patterns } ->
      Yfile_glob { out; recurse; relative; configure_depends; patterns }
  | Yfile_configure { input; output } -> Yfile_configure { input; output }
  (* cmake_path *)
  | Ypath_get { path_var; field; out } -> Ypath_get { path_var; field; out }
  | Ypath_has { path_var; field; out } -> Ypath_has { path_var; field; out }
  | Ypath_is_absolute { path_var; out } -> Ypath_is_absolute { path_var; out }
  | Ypath_is_relative { path_var; out } -> Ypath_is_relative { path_var; out }
  | Ypath_is_prefix { path_var; input; normalize; out } ->
      Ypath_is_prefix { path_var; input; normalize; out }
  | Ypath_compare { input1; op; input2; out } ->
      Ypath_compare { input1; op; input2; out }
  | Ypath_set { path_var; input; normalize } ->
      Ypath_set { path_var; input; normalize }
  | Ypath_append { path_var; inputs; out } ->
      Ypath_append { path_var; inputs; out }
  | Ypath_append_string { path_var; inputs; out } ->
      Ypath_append_string { path_var; inputs; out }
  | Ypath_remove_filename { path_var; out } ->
      Ypath_remove_filename { path_var; out }
  | Ypath_replace_filename { path_var; input; out } ->
      Ypath_replace_filename { path_var; input; out }
  | Ypath_remove_extension { path_var; last_only; out } ->
      Ypath_remove_extension { path_var; last_only; out }
  | Ypath_replace_extension { path_var; last_only; input; out } ->
      Ypath_replace_extension { path_var; last_only; input; out }
  | Ypath_normal_path { path_var; out } -> Ypath_normal_path { path_var; out }
  | Ypath_relative_path { path_var; base_dir; out } ->
      Ypath_relative_path { path_var; base_dir; out }
  | Ypath_absolute_path { path_var; base_dir; normalize; out } ->
      Ypath_absolute_path { path_var; base_dir; normalize; out }
  | Ypath_native_path { path_var; normalize; out } ->
      Ypath_native_path { path_var; normalize; out }
  | Ypath_convert_to_cmake { input; normalize; out } ->
      Ypath_convert_to_cmake { input; normalize; out }
  | Ypath_convert_to_native { input; normalize; out } ->
      Ypath_convert_to_native { input; normalize; out }
  | Ypath_hash { path_var; out } -> Ypath_hash { path_var; out }
  | Ypath_get_filename_component { var; filename; mode } ->
      Ypath_get_filename_component { var; filename; mode }

(* ------------------------------------------------------------
   Conditional
   ------------------------------------------------------------ *)
let rec lower_cond (c : PE.Cond.t) : L.yelu_cond =
  match c with
  | Ytruthy a -> Ytruthy a
  | Ynot c -> Ynot (lower_cond c)
  | Yand (a, b) -> Yand (lower_cond a, lower_cond b)
  | Yor (a, b) -> Yor (lower_cond a, lower_cond b)
  | Yis_target a -> Yis_target a
  | Yis_defined a -> Yis_defined a
  | Ystrequal (a, b) -> Ystrequal (a, b)
  | Ystrless (a, b) -> Ystrless (a, b)
  | Ystrgreater (a, b) -> Ystrgreater (a, b)
  | Ystrless_equal (a, b) -> Ystrless_equal (a, b)
  | Ystrgreater_equal (a, b) -> Ystrgreater_equal (a, b)
  | Yequal (a, b) -> Yequal (a, b)
  | Yless (a, b) -> Yless (a, b)
  | Ygreater (a, b) -> Ygreater (a, b)
  | Yless_equal (a, b) -> Yless_equal (a, b)
  | Ygreater_equal (a, b) -> Ygreater_equal (a, b)
  | Yin_list (a, b) -> Yin_list (a, b)
  | Ymatches (a, s) -> Ymatches (a, s)
  | Yexists a -> Yexists a
  | Yis_directory a -> Yis_directory a
  | Yis_absolute a -> Yis_absolute a
  | Ypolicy_defined s -> Ypolicy_defined s
  | Yversion_less (a, b) -> Yversion_less (a, b)
  | Yversion_greater (a, b) -> Yversion_greater (a, b)
  | Yversion_equal (a, b) -> Yversion_equal (a, b)
  | Yversion_less_equal (a, b) -> Yversion_less_equal (a, b)
  | Yversion_greater_equal (a, b) -> Yversion_greater_equal (a, b)

(* ------------------------------------------------------------
   Target ops — including auxiliary types (items_with_kind, etc.)
   ------------------------------------------------------------ *)
let lower_items_with_kind (iwk : PE.Target_op.items_with_kind) :
    L.yelu_items_with_kind =
  { kind = iwk.kind; items = iwk.items }

let lower_target_feature (tf : PE.Target_op.target_feature) :
    L.yelu_target_feature =
  { kind = tf.kind; feature = tf.feature }

let lower_file_set (fs : PE.Target_op.file_set) : L.yelu_file_set =
  { kind = fs.kind; type_ = fs.type_;
    base_dirs = fs.base_dirs; files = fs.files }

let lower_target_sources_item (tsi : PE.Target_op.target_sources_item) :
    L.yelu_target_sources_item =
  match tsi with
  | Ytsi_plain iwk -> Ytsi_plain (lower_items_with_kind iwk)
  | Ytsi_file_set fs -> Ytsi_file_set (lower_file_set fs)

let lower_target_op (t : PE.Target_op.t) : L.yelu_target_exp =
  match t with
  | Ytgt_add_executable { name; exclude_from_all; sources } ->
      Ytgt_add_executable { name; exclude_from_all; sources }
  | Ytgt_add_library { name; type_; exclude_from_all; sources } ->
      Ytgt_add_library { name; type_; exclude_from_all; sources }
  | Ytgt_add_library_imported { name; lib_type; global } ->
      Ytgt_add_library_imported { name; lib_type; global }
  | Ytgt_add_library_alias { name; target } ->
      Ytgt_add_library_alias { name; target }
  | Ytgt_add_executable_alias { name; target } ->
      Ytgt_add_executable_alias { name; target }
  | Ytgt_include_directories { target; before; system; items } ->
      Ytgt_include_directories
        { target; before; system; items = List.map lower_items_with_kind items }
  | Ytgt_link_libraries { targets; items } ->
      Ytgt_link_libraries
        { targets; items = List.map lower_items_with_kind items }
  | Ytgt_compile_definitions { target; items } ->
      Ytgt_compile_definitions
        { target; items = List.map lower_items_with_kind items }
  | Ytgt_compile_features { target; features } ->
      Ytgt_compile_features
        { target; features = List.map lower_target_feature features }
  | Ytgt_compile_options { target; before; items } ->
      Ytgt_compile_options
        { target; before; items = List.map lower_items_with_kind items }
  | Ytgt_link_options { target; before; items } ->
      Ytgt_link_options
        { target; before; items = List.map lower_items_with_kind items }
  | Ytgt_link_directories { target; before; items } ->
      Ytgt_link_directories
        { target; before; items = List.map lower_items_with_kind items }
  | Ytgt_sources { target; items } ->
      Ytgt_sources { target; items = List.map lower_items_with_kind items }
  | Ytgt_sources_fs { target; items } ->
      Ytgt_sources_fs
        { target; items = List.map lower_target_sources_item items }
  | Ytgt_precompile_headers { target; items } ->
      Ytgt_precompile_headers
        { target; items = List.map lower_items_with_kind items }
  | Ytgt_add_custom_command { outputs; commands; depends; verbatim; comment } ->
      Ytgt_add_custom_command
        { outputs; commands; depends; verbatim; comment }
  | Ytgt_add_custom_command_target
      { target; when_; commands; comment; verbatim } ->
      Ytgt_add_custom_command_target
        { target; when_; commands; comment; verbatim }
  | Ytgt_add_custom_target { name; all; commands; depends; comment } ->
      Ytgt_add_custom_target { name; all; commands; depends; comment }
  | Ytgt_add_dependencies { target; dep } ->
      Ytgt_add_dependencies { target; dep }

(* ------------------------------------------------------------
   Directory-scope ops
   ------------------------------------------------------------ *)
let lower_dir_op (d : PE.Dir_op.t) : L.yelu_dir_exp =
  match d with
  | Ydir_include_directories { dirs; before; system } ->
      Ydir_include_directories { dirs; before; system }
  | Ydir_add_compile_definitions { defs } ->
      Ydir_add_compile_definitions { defs }
  | Ydir_add_compile_options { options } ->
      Ydir_add_compile_options { options }
  | Ydir_add_link_options { options } -> Ydir_add_link_options { options }
  | Ydir_add_definitions { defs } -> Ydir_add_definitions { defs }
  | Ydir_link_directories { before; dirs } ->
      Ydir_link_directories { before; dirs }
  | Ydir_add_subdirectory { source_dir } ->
      Ydir_add_subdirectory { source_dir }
  | Ydir_link_libraries { items } -> Ydir_link_libraries { items }

(* ------------------------------------------------------------
   State ops
   ------------------------------------------------------------ *)
let lower_state_op (s : PE.State_op.t) : L.yelu_state_exp =
  match s with
  | Ystate_set { cvar; values; parent_scope } ->
      Ystate_set { cvar; values; parent_scope }
  | Ystate_option { cvar; msg; value } ->
      Ystate_option { cvar; msg; value }
  | Ystate_set_cache { cvar; values; cache_type; docstring; force } ->
      Ystate_set_cache { cvar; values; cache_type; docstring; force }
  | Ystate_unset_cache { cvar } -> Ystate_unset_cache { cvar }
  | Ystate_set_env { var; value } -> Ystate_set_env { var; value }
  | Ystate_unset_env { var } -> Ystate_unset_env { var }
  | Ystate_get_property { var; target; property; set } ->
      Ystate_get_property { var; target; property; set }
  | Ystate_get_directory_property { var; property } ->
      Ystate_get_directory_property { var; property }
  | Ystate_set_directory_property { property; append; values } ->
      Ystate_set_directory_property { property; append; values }
  | Ystate_set_tests_properties { tests; properties } ->
      Ystate_set_tests_properties { tests; properties }
  | Ystate_set_target_properties { target; properties } ->
      Ystate_set_target_properties { target; properties }
  | Ystate_set_property { targets; append; properties } ->
      Ystate_set_property { targets; append; properties }
  | Ystate_set_source_property { file; property; values } ->
      Ystate_set_source_property { file; property; values }
  | Ystate_set_global_property { properties } ->
      Ystate_set_global_property { properties }
  | Ystate_get_global_property { var; property } ->
      Ystate_get_global_property { var; property }
  | Ystate_get_target_property { var; target; property } ->
      Ystate_get_target_property { var; target; property }
  | Ystate_define_property
      { mode; property_name; inherited; brief_docs; full_docs; initialize_from } ->
      Ystate_define_property
        { mode; property_name; inherited; brief_docs; full_docs; initialize_from }

(* ------------------------------------------------------------
   Find ops
   ------------------------------------------------------------ *)
let lower_find_op (f : PE.Find_op.t) : L.yelu_find_exp =
  match f with
  | Yfind_library
      { cvar; names; paths; hints; no_default_path;
        no_cmake_environment_path; no_system_environment_path; required } ->
      Yfind_library
        { cvar; names; paths; hints; no_default_path;
          no_cmake_environment_path; no_system_environment_path; required }
  | Yfind_path
      { cvar; names; paths; hints; no_default_path;
        no_cmake_environment_path; no_system_environment_path; required } ->
      Yfind_path
        { cvar; names; paths; hints; no_default_path;
          no_cmake_environment_path; no_system_environment_path; required }
  | Yfind_program
      { cvar; names; paths; hints; no_default_path;
        no_cmake_environment_path; no_system_environment_path; required } ->
      Yfind_program
        { cvar; names; paths; hints; no_default_path;
          no_cmake_environment_path; no_system_environment_path; required }
  | Yfind_file
      { cvar; names; paths; hints; no_default_path;
        no_cmake_environment_path; no_system_environment_path; required } ->
      Yfind_file
        { cvar; names; paths; hints; no_default_path;
          no_cmake_environment_path; no_system_environment_path; required }
  | Yfind_package
      { name; version; exact; quiet; config_mode; required;
        components; optional_components } ->
      Yfind_package
        { name; version; exact; quiet; config_mode; required;
          components; optional_components }

(* ------------------------------------------------------------
   Install ops
   ------------------------------------------------------------ *)
let lower_install_op (i : PE.Install_op.t) : L.yelu_install_exp =
  match i with
  | Yinstall_targets { targets; destination; export } ->
      Yinstall_targets { targets; destination; export }
  | Yinstall_files { files; destination } ->
      Yinstall_files { files; destination }
  | Yinstall_export { file; export; destination; namespace } ->
      Yinstall_export { file; export; destination; namespace }
  | Yinstall_export_export { name; file } ->
      Yinstall_export_export { name; file }
  | Yinstall_configure_package_config_file
      { install_dest; input; output;
        no_set_and_check_macro; no_check_required_components_macro } ->
      Yinstall_configure_package_config_file
        { install_dest; input; output;
          no_set_and_check_macro; no_check_required_components_macro }
  | Yinstall_write_basic_package_version_file
      { file; version; compatibility; arch_independent } ->
      Yinstall_write_basic_package_version_file
        { file; version; compatibility; arch_independent }

(* ------------------------------------------------------------
   Test ops
   ------------------------------------------------------------ *)
let lower_test_op (t : PE.Test_op.t) : L.yelu_test_exp =
  match t with
  | Ytest_enable_testing -> Ytest_enable_testing
  | Ytest_add_test { name; command; args } ->
      Ytest_add_test { name; command; args }

(* ------------------------------------------------------------
   Try ops
   ------------------------------------------------------------ *)
let lower_try_op (t : PE.Try_op.t) : L.yelu_try_exp =
  match t with
  | Ytry_compile
      { result_var; sources; compile_definitions; link_libraries;
        link_options; output_variable; no_cache; c_standard; cxx_standard } ->
      Ytry_compile
        { result_var; sources; compile_definitions; link_libraries;
          link_options; output_variable; no_cache; c_standard; cxx_standard }
  | Ytry_run
      { run_result_var; compile_result_var; sources; compile_definitions;
        link_libraries; compile_output_variable; run_output_variable; args } ->
      Ytry_run
        { run_result_var; compile_result_var; sources; compile_definitions;
          link_libraries; compile_output_variable; run_output_variable; args }

(* ------------------------------------------------------------
   Cmake meta ops
   ------------------------------------------------------------ *)
let lower_cmake_op (c : PE.Cmake_op.t) : L.yelu_cmake_exp =
  match c with
  | Ycmake_minimum_required { min; max } ->
      Ycmake_minimum_required { min; max }
  | Ycmake_project { name; version; languages } ->
      Ycmake_project { name; version; languages }
  | Ycmake_enable_language { langs; optional } ->
      Ycmake_enable_language { langs; optional }
  | Ycmake_policy_set { id; new_ } -> Ycmake_policy_set { id; new_ }
  | Ycmake_language_call { cmd; args } -> Ycmake_language_call { cmd; args }
  | Ycmake_language_eval { code } -> Ycmake_language_eval { code }
  | Ycmake_language_get_log_level { out } ->
      Ycmake_language_get_log_level { out }
  | Ycmake_math { exp; out; output_format } ->
      Ycmake_math { exp; out; output_format }
  | Ycmake_variable_watch { var; command } ->
      Ycmake_variable_watch { var; command }

(* ------------------------------------------------------------
   Top-level expression
   ------------------------------------------------------------ *)
let rec lower_exp (e : PE.t) : L.yelu_exp =
  match e with
  | Ye_string s -> Ye_string (lower_string_op s)
  | Ye_list l -> Ye_list (lower_list_op l)
  | Ye_file f -> Ye_file (lower_file_op f)
  | Ye_target t -> Ye_target (lower_target_op t)
  | Ye_dir d -> Ye_dir (lower_dir_op d)
  | Ye_state s -> Ye_state (lower_state_op s)
  | Ye_find f -> Ye_find (lower_find_op f)
  | Ye_install i -> Ye_install (lower_install_op i)
  | Ye_test t -> Ye_test (lower_test_op t)
  | Ye_try t -> Ye_try (lower_try_op t)
  | Ye_cmake c -> Ye_cmake (lower_cmake_op c)
  | Ylet { name; value } -> Ylet { var = Yvar name; value }
  | Yif { cond; then_; else_ } ->
      Yif
        { cond = lower_cond cond;
          then_ = lower_exp then_;
          else_ = Option.map lower_exp else_ }
  | Yexp_list es -> Yexp_list (List.map lower_exp es)
  | Yc_include { file; optional } -> Yc_include { file; optional }
  | Yc_function { name; args; body } ->
      Yc_function { name; args; body = List.map lower_exp body }
  | Yc_macro { name; args; body } ->
      Yc_macro { name; args; body = List.map lower_exp body }
  | Yc_apply { name; args } -> Yc_apply { name; args }
  | Yc_execute_process
      { commands; working_directory; timeout;
        result_variable; output_variable; error_variable;
        input_file; output_file; error_file;
        output_quiet; error_quiet;
        output_strip_trailing_whitespace; error_strip_trailing_whitespace;
        command_error_is_fatal } ->
      Yc_execute_process
        { commands; working_directory; timeout;
          result_variable; output_variable; error_variable;
          input_file; output_file; error_file;
          output_quiet; error_quiet;
          output_strip_trailing_whitespace; error_strip_trailing_whitespace;
          command_error_is_fatal }
  | Yc_quote_cmd s -> Yc_quote_cmd s
  | Yc_at_var s -> Yc_at_var s
  | Yc_include_guard { scope } -> Yc_include_guard { scope }
  | Yc_separate_arguments { cvar; mode; input } ->
      Yc_separate_arguments { cvar; mode; input }
  | Yc_extern_cvar v -> Yc_extern_cvar v
  | Yc_extern_target t -> Yc_extern_target t
  | Yc_message { mode; texts } -> Yc_message { mode; texts }
  | Yc_foreach { loop_var; items; commands } ->
      Yc_foreach { loop_var; items; commands = lower_exp commands }
  | Yc_foreach_range { loop_var; start; stop; step; commands } ->
      Yc_foreach_range
        { loop_var; start; stop; step; commands = lower_exp commands }
  | Yc_foreach_in { loop_var; lists; items; commands } ->
      Yc_foreach_in
        { loop_var; lists; items; commands = lower_exp commands }
  | Yc_foreach_zip { loop_vars; lists; commands } ->
      Yc_foreach_zip { loop_vars; lists; commands = lower_exp commands }
  | Yc_while { cond; commands } ->
      Yc_while { cond = lower_cond cond; commands = lower_exp commands }
  | Yc_break -> Yc_break
  | Yc_continue -> Yc_continue
  | Yc_return { propogate_vars } -> Yc_return { propogate_vars }
  | Yc_block { scope_vars; propagate; body } ->
      Yc_block { scope_vars; propagate; body = List.map lower_exp body }
