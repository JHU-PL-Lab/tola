open Base
open Lang_yelu

let ycs_to_s = function
  | Ycs_file s | Ycs_dir s | Ycs_name s | Ycs_val s | Ycs_cmake s -> s

let ycvar s = Ycvar s
let ytarget s = Ytarget s
let ytruthy arg = Ytruthy arg
let ystrequal a b = Ystrequal (a, b)
let ystrless a b = Ystrless (a, b)
let ystrgreater a b = Ystrgreater (a, b)
let ystrless_equal a b = Ystrless_equal (a, b)
let ystrgreater_equal a b = Ystrgreater_equal (a, b)
let yequal a b = Yequal (a, b)
let yless a b = Yless (a, b)
let ygreater a b = Ygreater (a, b)
let yless_equal a b = Yless_equal (a, b)
let ygreater_equal a b = Ygreater_equal (a, b)
let yin_list value listvar = Yin_list (value, listvar)
let ymatches value regex = Ymatches (value, regex)
let yexists path = Yexists path
let yis_directory path = Yis_directory path
let yis_absolute path = Yis_absolute path
let yversion_less a b = Yversion_less (a, b)
let yversion_greater a b = Yversion_greater (a, b)
let yversion_equal a b = Yversion_equal (a, b)
let yversion_less_equal a b = Yversion_less_equal (a, b)
let yversion_greater_equal a b = Yversion_greater_equal (a, b)
let yvar s = Yarg_var (Yvar s)
let ylet name value = Ylet { var = Yvar name; value }
let ycstr s = Yarg_cvar (Ycvar s)
let ytval s = Yarg_target (Ytarget s)
let yfile s = Yarg_string (Ycs_file s)
let ydir s = Yarg_string (Ycs_dir s)
let ystr s = Yarg_string (Ycs_val s)
let ystr_raw s = Yarg_string (Ycs_cmake s)
let ybool b = Yarg_bool b

(* cmake variable reference — erases to ${NAME} for cmake runtime expansion *)
let ycref s = ystr_raw (Fmt.str "${%s}" s)
let ycref_path s suffix = ystr_raw (Fmt.str "${%s}/%s" s suffix)

(* cmake directory constants — friendly keys for well-known cmake dir variables *)
let source_root = "PROJECT_SOURCE_DIR"
let output_root = "PROJECT_BINARY_DIR"
let source_this = "CMAKE_CURRENT_SOURCE_DIR"
let output_this = "CMAKE_CURRENT_BINARY_DIR"
let list_this = "CMAKE_CURRENT_LIST_DIR"

(* directory accessors *)
let dir d = ycref d
let dir_concat d suffix = ycref_path d suffix

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

let yc_set ?(parent_scope = false) (cvar : yelu_cvar) values =
  Yc_set { cvar; values; parent_scope }

let add_exe ?(sources = []) name =
  Yc_add_executable { name; sources }

let add_lib ?(exclude_from_all = false) ?type_ ?(sources = []) name =
  Yc_add_library { name; type_; exclude_from_all; sources }

let add_lib_imported ?(global = false) ?lib_type name =
  Yc_add_library_imported { name; lib_type; global }

let include_dirs target items =
  Yc_target_include_directories { target; items }

let link_lib targets items =
  Yc_target_link_libraries { targets; items }

let compile_defs target items =
  Yc_target_compile_definitions { target; items }

let compile_feats target features =
  Yc_target_compile_features { target; features }

let compile_opts ?(before = false) target items =
  Yc_target_compile_options { target; before; items }

let yc_configure_file ~input output = Yc_configure_file { input; output }
let gen_file = yc_configure_file
let yc_add_subdirectory source_dir = Yc_add_subdirectory { source_dir }

let yc_option ?(value = ybool false) ~msg (cvar : yelu_cvar) = Yc_option { cvar; msg; value }

let yite cond then_ ?else_ () =
  match else_ with
  | None -> Yif { cond; then_; else_ = None }
  | Some else_ -> Yif { cond; then_; else_ = Some else_ }

let yifthen cond then_ = yite cond then_ ()
let yif cond then_ else_ = yite cond then_ ~else_ ()

(* scripting *)
let yc_include ?(optional = false) file = Yc_include { file; optional }
let yc_function name args body = Yc_function { name; args; body }
let yc_macro name ?(args = []) body = Yc_macro { name; args; body }
let yc_apply name args = Yc_apply { name; args }
let yc_set_env var value = Yc_set_env { var; value }
let yc_unset_env var = Yc_unset_env { var }

let yc_set_cache ?(force = false) ?(cache_type = Lang_cmake.Ct_string) ?(docstring = "") (cvar : yelu_cvar) values =
  Yc_set_cache { cvar; values; cache_type; docstring; force }

let yc_unset_cache (cvar : yelu_cvar) = Yc_unset_cache { cvar }
let yc_file_relative_path ~var ~base file = Yc_file_relative_path { var; base; file }
let yc_quote_cmd s = Yc_quote_cmd s
let yc_list_append (cvar : yelu_cvar) values = Yc_list_append { cvar; values }

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

let yc_set_global_property properties =
  Yc_set_global_property { properties }

let yc_get_filename_component ~mode var filename =
  Yc_get_filename_component { var; filename; mode }

let yc_get_global_property ~property var =
  Yc_get_global_property { var; property }

let yc_include_guard scope = Yc_include_guard { scope }
let yc_separate_arguments ?(input) ~mode (cvar : yelu_cvar) = Yc_separate_arguments { cvar; mode; input }
let yc_separate_arguments_plain (cvar : yelu_cvar) = Yc_separate_arguments { cvar; mode = Lang_cmake.Sa_plain; input = None }
let yc_target_link_options ?(before = false) target items =
  Yc_target_link_options { target; before; items }
let yc_target_sources target items = Yc_target_sources { target; items }

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

(* Tier 1: find_var commands *)
let yc_find_library ?(names = []) ?(paths = []) ?(hints = [])
    ?(no_default_path = false) ?(no_cmake_environment_path = false)
    ?(no_system_environment_path = false) ?(required = false) cvar =
  Yc_find_library { cvar; names; paths; hints; no_default_path;
                    no_cmake_environment_path; no_system_environment_path;
                    required }

let yc_find_path ?(names = []) ?(paths = []) ?(hints = [])
    ?(no_default_path = false) ?(no_cmake_environment_path = false)
    ?(no_system_environment_path = false) ?(required = false) cvar =
  Yc_find_path { cvar; names; paths; hints; no_default_path;
                 no_cmake_environment_path; no_system_environment_path;
                 required }

let yc_find_program ?(names = []) ?(paths = []) ?(hints = [])
    ?(no_default_path = false) ?(no_cmake_environment_path = false)
    ?(no_system_environment_path = false) ?(required = false) cvar =
  Yc_find_program { cvar; names; paths; hints; no_default_path;
                    no_cmake_environment_path; no_system_environment_path;
                    required }

let yc_find_file ?(names = []) ?(paths = []) ?(hints = [])
    ?(no_default_path = false) ?(no_cmake_environment_path = false)
    ?(no_system_environment_path = false) ?(required = false) cvar =
  Yc_find_file { cvar; names; paths; hints; no_default_path;
                 no_cmake_environment_path; no_system_environment_path;
                 required }

let yc_message ?(mode = Lang_cmake.Mm_status) texts = Yc_message { mode; texts }

(* Tier 2: iteration *)
let yc_foreach ?(items = []) (loop_var : yelu_cvar) commands =
  Yc_foreach { loop_var; items; commands }

let yc_foreach_range ?start ?step ~stop (loop_var : yelu_cvar) commands =
  Yc_foreach_range { loop_var; start; stop; step; commands }

let yc_foreach_in ?(lists = []) ?(items = []) (loop_var : yelu_cvar) commands =
  Yc_foreach_in { loop_var; lists; items; commands }

let yc_foreach_zip (loop_vars : yelu_cvar list) (lists : yelu_cvar list) commands =
  Yc_foreach_zip { loop_vars; lists; commands }

let yc_while cond commands = Yc_while { cond; commands }
let yc_break = Yc_break
let yc_continue = Yc_continue
let yc_return ?(propogate_vars = []) () = Yc_return { propogate_vars }

(* Tier 2: list commands *)
let yc_list_length (cvar : yelu_cvar) (out : yelu_cvar) = Yc_list_length { cvar; out }
let yc_list_get ?(indices = []) (cvar : yelu_cvar) (out : yelu_cvar) = Yc_list_get { cvar; indices; out }
let yc_list_remove_item (cvar : yelu_cvar) values = Yc_list_remove_item { cvar; values }
let yc_list_remove_duplicates (cvar : yelu_cvar) = Yc_list_remove_duplicates { cvar }
let yc_list_reverse (cvar : yelu_cvar) = Yc_list_reverse { cvar }

let yc_list_sort ?order ?compare ?case (cvar : yelu_cvar) =
  Yc_list_sort { cvar; order; compare; case }

let yc_list_filter mode regex (cvar : yelu_cvar) =
  Yc_list_filter { cvar; mode; regex }

let yc_list_join (cvar : yelu_cvar) glue (out : yelu_cvar) = Yc_list_join { cvar; glue; out }
let yc_list_sublist (cvar : yelu_cvar) begin_ length (out : yelu_cvar) = Yc_list_sublist { cvar; begin_; length; out }
let yc_list_find (cvar : yelu_cvar) value (out : yelu_cvar) = Yc_list_find { cvar; value; out }
let yc_list_prepend (cvar : yelu_cvar) values = Yc_list_prepend { cvar; values }
let yc_list_insert (cvar : yelu_cvar) index values = Yc_list_insert { cvar; index; values }
let yc_list_remove_at (cvar : yelu_cvar) indices = Yc_list_remove_at { cvar; indices }
let yc_list_pop_back ?(out_vars = []) (cvar : yelu_cvar) = Yc_list_pop_back { cvar; out_vars }
let yc_list_pop_front ?(out_vars = []) (cvar : yelu_cvar) = Yc_list_pop_front { cvar; out_vars }

let yc_list_transform ?(selector) ?(output : yelu_cvar option) (cvar : yelu_cvar) action =
  Yc_list_transform { cvar; action; selector; output }

(* Tier 2: string commands *)
let yc_string_toupper string (out : yelu_cvar) = Yc_string_toupper { string; out }
let yc_string_tolower string (out : yelu_cvar) = Yc_string_tolower { string; out }
let yc_string_length string (out : yelu_cvar) = Yc_string_length { string; out }
let yc_string_strip string (out : yelu_cvar) = Yc_string_strip { string; out }
let yc_string_concat (out : yelu_cvar) inputs = Yc_string_concat { out; inputs }

let yc_string_replace match_string replace_string (out : yelu_cvar) inputs =
  Yc_string_replace { match_string; replace_string; out; inputs }

let yc_string_regex_match regex (out : yelu_cvar) inputs =
  Yc_string_regex_match { regex; out; inputs }
let yc_string_regex_matchall regex (out : yelu_cvar) inputs =
  Yc_string_regex_matchall { regex; out; inputs }

let yc_string_regex_replace regex replace (out : yelu_cvar) inputs =
  Yc_string_regex_replace { regex; replace; out; inputs }

let yc_string_append (cvar : yelu_cvar) inputs = Yc_string_append { cvar; inputs }
let yc_string_prepend (cvar : yelu_cvar) inputs = Yc_string_prepend { cvar; inputs }
let yc_string_join glue (out : yelu_cvar) inputs = Yc_string_join { glue; out; inputs }
let yc_string_find ?(reverse = false) string substring (out : yelu_cvar) =
  Yc_string_find { string; substring; out; reverse }
let yc_string_substring string begin_ ?length (out : yelu_cvar) =
  Yc_string_substring { string; begin_; length; out }
let yc_string_repeat string count (out : yelu_cvar) = Yc_string_repeat { string; count; out }
let yc_string_genex_strip string (out : yelu_cvar) = Yc_string_genex_strip { string; out }

let yc_string_compare op string1 string2 (out : yelu_cvar) =
  Yc_string_compare { op; string1; string2; out }

let yc_string_make_c_identifier string (out : yelu_cvar) =
  Yc_string_make_c_identifier { string; out }

let yc_string_timestamp ?(utc = false) ?format (out : yelu_cvar) =
  Yc_string_timestamp { out; format; utc }

let yc_string_hex string (out : yelu_cvar) = Yc_string_hex { string; out }

let yc_string_uuid ?(upper = false) ~namespace ~name ~type_ (out : yelu_cvar) =
  Yc_string_uuid { out; namespace; name; type_; upper }

let yc_string_json_get ?(error_var : yelu_cvar option) ?(path = []) ~(out : yelu_cvar) json =
  Yc_string_json { out; error_var; op = Yjop_get { json; path } }

let yc_string_json_get_raw ?(error_var : yelu_cvar option) ?(path = []) ~(out : yelu_cvar) json =
  Yc_string_json { out; error_var; op = Yjop_get_raw { json; path } }

let yc_string_json_type ?(error_var : yelu_cvar option) ?(path = []) ~(out : yelu_cvar) json =
  Yc_string_json { out; error_var; op = Yjop_type { json; path } }

let yc_string_json_length ?(error_var : yelu_cvar option) ?(path = []) ~(out : yelu_cvar) json =
  Yc_string_json { out; error_var; op = Yjop_length { json; path } }

let yc_string_json_member ?(error_var : yelu_cvar option) ?(path = []) ~(out : yelu_cvar) json =
  Yc_string_json { out; error_var; op = Yjop_member { json; path } }

let yc_string_json_remove ?(error_var : yelu_cvar option) ?(path = []) ~(out : yelu_cvar) json =
  Yc_string_json { out; error_var; op = Yjop_remove { json; path } }

let yc_string_json_set ?(error_var : yelu_cvar option) ?(path = []) ~(out : yelu_cvar) ~value json =
  Yc_string_json { out; error_var; op = Yjop_set { json; path; value } }

let yc_string_json_equal ~(out : yelu_cvar) json1 json2 =
  Yc_string_json { out; error_var = None; op = Yjop_equal { json1; json2 } }

let yc_string_json_string_encode ~(out : yelu_cvar) value =
  Yc_string_json { out; error_var = None; op = Yjop_string_encode { value } }

(* math *)
let yc_math ?(output_format = Lang_cmake.Decical) exp (out : yelu_cvar) =
  Yc_math { exp; out; output_format }
