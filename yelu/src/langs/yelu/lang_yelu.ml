(* Yelu AST — typed surface language compiling to CMake.
   Type discipline lives here; cmake_ast stays stringly-typed. *)

(* A cmake name — string key in cmake namespaces (TARGET, Variable, COMMAND, TEST, ...) *)
type cmake_name = string

(* String content classification — what role a string plays *)
type yc_string =
  | Ycs_file of string        (* file path: source, config, header, cmake module *)
  | Ycs_dir of string         (* directory path: source dir, install destination *)
  | Ycs_name of cmake_name    (* generic cmake name, not typed to a specific namespace *)
  | Ycs_val of string         (* plain value: numbers, property values *)
  | Ycs_cmake of string         (* cmake expression, opaque pass-through *)

(* Typed wrappers — each pins a cmake_name to a specific namespace *)
type yelu_cvar = Ycvar of cmake_name    (* cmake Variable namespace: set(), ${}, if(DEFINED) *)
type yelu_target = Ytarget of cmake_name  (* cmake Target namespace: add_library, if(TARGET) *)
type yelu_var = Yvar of string    (* compile-time variable *)

(* Type aliases — placeholders for future typed variants *)
type project_name = string
type feature_name = string
type property_key = string

(* Shared structural types *)
type version = Lang_cmake.version

(* Typed enums — owned by yelu, erased to strings for cmake *)
type library_type =
  | Lib_static
  | Lib_shared
  | Lib_module
  | Lib_unknown
  | Lib_object
  | Lib_interface
  | Lib_global

type target_kind = Public | Private | Interface | Plain

type supported_lang =
  | Lang_none
  | Lang_c
  | Lang_cxx
  | Lang_csharp
  | Lang_cuda
  | Lang_objc
  | Lang_objcxx
  | Lang_fortran
  | Lang_hipy
  | Lang_ispc
  | Lang_swift
  | Lang_asm
  | Lang_asm_nasm
  | Lang_asm_marmasm
  | Lang_asm_masm
  | Lang_asm_att

type compatibility =
  | Any_newer_version
  | Same_major_version
  | Same_minor_version
  | Exact_version

(* Generator expressions — typed wrappers that compile to $<...> strings *)
type yelu_genex =
  (* logical *)
  | Yge_config of string                         (* $<CONFIG:cfg> *)
  | Yge_not of yelu_genex                        (* $<NOT:g> *)
  | Yge_and of yelu_genex list                   (* $<AND:g1,g2,...> *)
  | Yge_or of yelu_genex list                    (* $<OR:g1,g2,...> *)
  | Yge_if of yelu_genex * yelu_genex * yelu_genex  (* $<IF:cond,t,f> *)
  | Yge_bool of string                           (* $<BOOL:s> *)
  (* target *)
  | Yge_target_file of string                    (* $<TARGET_FILE:tgt> *)
  | Yge_target_file_dir of string                (* $<TARGET_FILE_DIR:tgt> *)
  | Yge_target_property of string * string       (* $<TARGET_PROPERTY:tgt,prop> *)
  (* interface *)
  | Yge_install_interface of yelu_genex          (* $<INSTALL_INTERFACE:...> *)
  | Yge_build_interface of yelu_genex            (* $<BUILD_INTERFACE:...> *)
  (* string ops *)
  | Yge_strequal of string * string              (* $<STREQUAL:a,b> *)
  | Yge_lower_case of yelu_genex                 (* $<LOWER_CASE:...> *)
  | Yge_upper_case of yelu_genex                 (* $<UPPER_CASE:...> *)
  (* platform / language *)
  | Yge_compile_language of string               (* $<COMPILE_LANGUAGE:lang> *)
  | Yge_platform_id of string                    (* $<PLATFORM_ID:id> *)
  (* escape hatch *)
  | Yge_raw of string                            (* $<raw> — user supplies full inner content *)

(* Unified arg type — replaces old yelu_value + yelu_item *)
type yarg =
  | Yarg_cvar of yelu_cvar
  | Yarg_target of yelu_target
  | Yarg_string of yc_string  (* file, dir, name, value, or raw cmake expr *)
  | Yarg_bool of bool
  | Yarg_var of yelu_var  (* compile-time variable reference *)

type yelu_items_with_kind = { kind : target_kind; items : yarg list }
type yelu_target_feature = { kind : target_kind; feature : feature_name }

type yelu_file_set = {
  kind : target_kind;
  type_ : Lang_cmake.file_set_type;
  base_dirs : yarg list;
  files : yarg list;
}

type yelu_target_sources_item =
  | Ytsi_plain of yelu_items_with_kind
  | Ytsi_file_set of yelu_file_set

type yelu_cond =
  | Ytruthy of yarg
  | Ynot of yelu_cond
  | Yand of yelu_cond * yelu_cond
  | Yor of yelu_cond * yelu_cond
  | Yis_target of yarg
  | Yis_defined of yarg
  | Ystrequal of yarg * yarg
  | Ystrless of yarg * yarg
  | Ystrgreater of yarg * yarg
  | Ystrless_equal of yarg * yarg
  | Ystrgreater_equal of yarg * yarg
  | Yequal of yarg * yarg          (* numeric EQUAL *)
  | Yless of yarg * yarg           (* numeric LESS *)
  | Ygreater of yarg * yarg        (* numeric GREATER *)
  | Yless_equal of yarg * yarg     (* numeric LESS_EQUAL *)
  | Ygreater_equal of yarg * yarg  (* numeric GREATER_EQUAL *)
  | Yin_list of yarg * yarg        (* value IN_LIST listvar *)
  | Ymatches of yarg * string      (* value MATCHES regex *)
  | Yexists of yarg                (* EXISTS path *)
  | Yis_directory of yarg          (* IS_DIRECTORY path *)
  | Yis_absolute of yarg           (* IS_ABSOLUTE path *)
  | Ypolicy_defined of string      (* POLICY CMPxxxx *)
  | Yversion_less of yarg * yarg
  | Yversion_greater of yarg * yarg
  | Yversion_equal of yarg * yarg
  | Yversion_less_equal of yarg * yarg
  | Yversion_greater_equal of yarg * yarg

type yelu_json_op =
  | Yjop_get of { json : yarg; path : string list }
  | Yjop_get_raw of { json : yarg; path : string list }
  | Yjop_type of { json : yarg; path : string list }
  | Yjop_length of { json : yarg; path : string list }
  | Yjop_member of { json : yarg; path : string list }
  | Yjop_remove of { json : yarg; path : string list }
  | Yjop_set of { json : yarg; path : string list; value : yarg }
  | Yjop_equal of { json1 : yarg; json2 : yarg }
  | Yjop_string_encode of { value : yarg }

type yelu_file_exp =
  (* file() IO *)
  | Yfile_read of { out : yelu_cvar; file : yarg; offset : int option; limit : int option; hex : bool }
  | Yfile_write of { file : yarg; append : bool; content : yarg list }
  | Yfile_strings of { out : yelu_cvar; file : yarg; regex : string option; encoding : string option; limit_count : int option }
  (* file() filesystem *)
  | Yfile_touch of { files : yarg list; nocreate : bool }
  | Yfile_make_directory of { dirs : yarg list }
  | Yfile_rename of { old_ : yarg; new_ : yarg; result : yelu_cvar option; no_replace : bool }
  | Yfile_remove of { files : yarg list; recurse : bool }
  | Yfile_copy of { input : yarg; output : yarg; result : yelu_cvar option; only_if_different : bool }
  (* file() path queries *)
  | Yfile_real_path of { out : yelu_cvar; path : yarg; base_dir : yarg option; expand_tilde : bool }
  | Yfile_size of { out : yelu_cvar; file : yarg }
  | Yfile_read_symlink of { out : yelu_cvar; link : yarg }
  | Yfile_timestamp of { out : yelu_cvar; file : yarg; format : string option; utc : bool }
  | Yfile_relative_path of { var : yarg; base : yarg; file : yarg }
  | Yfile_glob of { out : yelu_cvar; recurse : bool; relative : yarg option; configure_depends : bool; patterns : yarg list }
  | Yfile_configure of { input : yarg; output : yarg }
  (* cmake_path *)
  | Ypath_get of { path_var : yelu_cvar; field : Lang_cmake.cmake_path_get_field; out : yelu_cvar }
  | Ypath_has of { path_var : yelu_cvar; field : Lang_cmake.cmake_path_has_field; out : yelu_cvar }
  | Ypath_is_absolute of { path_var : yelu_cvar; out : yelu_cvar }
  | Ypath_is_relative of { path_var : yelu_cvar; out : yelu_cvar }
  | Ypath_is_prefix of { path_var : yelu_cvar; input : yarg; normalize : bool; out : yelu_cvar }
  | Ypath_compare of { input1 : yarg; op : Lang_cmake.cmake_path_compare_op; input2 : yarg; out : yelu_cvar }
  | Ypath_set of { path_var : yelu_cvar; input : yarg; normalize : bool }
  | Ypath_append of { path_var : yelu_cvar; inputs : yarg list; out : yelu_cvar option }
  | Ypath_append_string of { path_var : yelu_cvar; inputs : yarg list; out : yelu_cvar option }
  | Ypath_remove_filename of { path_var : yelu_cvar; out : yelu_cvar option }
  | Ypath_replace_filename of { path_var : yelu_cvar; input : yarg; out : yelu_cvar option }
  | Ypath_remove_extension of { path_var : yelu_cvar; last_only : bool; out : yelu_cvar option }
  | Ypath_replace_extension of { path_var : yelu_cvar; last_only : bool; input : yarg; out : yelu_cvar option }
  | Ypath_normal_path of { path_var : yelu_cvar; out : yelu_cvar option }
  | Ypath_relative_path of { path_var : yelu_cvar; base_dir : yarg option; out : yelu_cvar option }
  | Ypath_absolute_path of { path_var : yelu_cvar; base_dir : yarg option; normalize : bool; out : yelu_cvar option }
  | Ypath_native_path of { path_var : yelu_cvar; normalize : bool; out : yelu_cvar }
  | Ypath_convert_to_cmake of { input : yarg; normalize : bool; out : yelu_cvar }
  | Ypath_convert_to_native of { input : yarg; normalize : bool; out : yelu_cvar }
  | Ypath_hash of { path_var : yelu_cvar; out : yelu_cvar }
  | Ypath_get_filename_component of { var : yelu_cvar; filename : yarg; mode : string }

type yelu_target_exp =
  | Ytgt_add_executable of { name : yarg; exclude_from_all : bool; sources : yarg list }
  | Ytgt_add_library of {
      name : yarg;
      type_ : library_type option;
      exclude_from_all : bool;
      sources : yarg list;
    }
  | Ytgt_add_library_imported of { name : yarg; lib_type : string option; global : bool }
  | Ytgt_add_library_alias of { name : string; target : string }
  | Ytgt_add_executable_alias of { name : string; target : string }
  | Ytgt_include_directories of {
      target : yarg;
      before : bool;
      system : bool;
      items : yelu_items_with_kind list;
    }
  | Ytgt_link_libraries of {
      targets : yarg list;
      items : yelu_items_with_kind list;
    }
  | Ytgt_compile_definitions of {
      target : yarg;
      items : yelu_items_with_kind list;
    }
  | Ytgt_compile_features of {
      target : yarg;
      features : yelu_target_feature list;
    }
  | Ytgt_compile_options of {
      target : yarg;
      before : bool;
      items : yelu_items_with_kind list;
    }
  | Ytgt_link_options of { target : yarg; before : bool; items : yelu_items_with_kind list }
  | Ytgt_link_directories of { target : yarg; before : bool; items : yelu_items_with_kind list }
  | Ytgt_sources of { target : yarg; items : yelu_items_with_kind list }
  | Ytgt_sources_fs of { target : yarg; items : yelu_target_sources_item list }
  | Ytgt_precompile_headers of { target : yarg; items : yelu_items_with_kind list }
  | Ytgt_add_custom_command of {
      outputs : yarg list;
      commands : Lang_cmake.custom_command list;
      depends : yarg list;
      verbatim : bool;
      comment : string option;
    }
  | Ytgt_add_custom_command_target of {
      target : string;
      when_ : Lang_cmake.custom_when;
      commands : Lang_cmake.custom_command list;
      comment : string option;
      verbatim : bool;
    }
  | Ytgt_add_custom_target of {
      name : string;
      all : bool;
      commands : Lang_cmake.custom_command list;
      depends : yarg list;
      comment : string option;
    }
  | Ytgt_add_dependencies of { target : string; dep : string }

type yelu_install_exp =
  | Yinstall_targets of {
      targets : yarg list;
      destination : yarg;
      export : yarg option;
    }
  | Yinstall_files of { files : yarg list; destination : yarg }
  | Yinstall_export of {
      file : yarg option;
      export : yarg;
      destination : yarg;
      namespace : string option;
    }
  | Yinstall_export_export of { name : yarg; file : yarg option }
  | Yinstall_configure_package_config_file of {
      install_dest : yarg;
      input : yarg;
      output : yarg;
      no_set_and_check_macro : bool;
      no_check_required_components_macro : bool;
    }
  | Yinstall_write_basic_package_version_file of {
      file : yarg;
      version : yarg option;
      compatibility : compatibility;
      arch_independent : bool;
    }

type yelu_cmake_exp =
  | Ycmake_minimum_required of { min : version; max : version option }
  | Ycmake_project of {
      name : project_name;
      version : version option;
      languages : supported_lang list;
    }
  | Ycmake_enable_language of { langs : string list; optional : bool }
  | Ycmake_policy_set of { id : string; new_ : bool }
  | Ycmake_language_call of { cmd : string; args : yarg list }
  | Ycmake_language_eval of { code : string }
  | Ycmake_language_get_log_level of { out : yelu_cvar }
  | Ycmake_math of {
      exp : string;
      out : yelu_cvar;
      output_format : Lang_cmake.math_output_format;
    }
  | Ycmake_variable_watch of { var : yelu_cvar; command : string option }

type yelu_test_exp =
  | Ytest_enable_testing
  | Ytest_add_test of { name : yarg; command : yarg; args : yarg list }

type yelu_try_exp =
  | Ytry_compile of {
      result_var : yelu_cvar;
      sources : yarg list;
      compile_definitions : yarg list;
      link_libraries : yarg list;
      link_options : yarg list;
      output_variable : yelu_cvar option;
      no_cache : bool;
      c_standard : string option;
      cxx_standard : string option;
    }
  | Ytry_run of {
      run_result_var : yelu_cvar;
      compile_result_var : yelu_cvar;
      sources : yarg list;
      compile_definitions : yarg list;
      link_libraries : yarg list;
      compile_output_variable : yelu_cvar option;
      run_output_variable : yelu_cvar option;
      args : yarg list;
    }

type yelu_dir_exp =
  | Ydir_include_directories of { dirs : yarg list; before : bool; system : bool }
  | Ydir_add_compile_definitions of { defs : yarg list }
  | Ydir_add_compile_options of { options : yarg list }
  | Ydir_add_link_options of { options : yarg list }
  | Ydir_add_definitions of { defs : yarg list }
  | Ydir_link_directories of { before : bool; dirs : yarg list }
  | Ydir_add_subdirectory of { source_dir : yarg }
  | Ydir_link_libraries of { items : yarg list }

type yelu_find_exp =
  | Yfind_library of {
      cvar : yelu_cvar;
      names : yarg list;
      paths : yarg list;
      hints : yarg list;
      no_default_path : bool;
      no_cmake_environment_path : bool;
      no_system_environment_path : bool;
      required : bool;
    }
  | Yfind_path of {
      cvar : yelu_cvar;
      names : yarg list;
      paths : yarg list;
      hints : yarg list;
      no_default_path : bool;
      no_cmake_environment_path : bool;
      no_system_environment_path : bool;
      required : bool;
    }
  | Yfind_program of {
      cvar : yelu_cvar;
      names : yarg list;
      paths : yarg list;
      hints : yarg list;
      no_default_path : bool;
      no_cmake_environment_path : bool;
      no_system_environment_path : bool;
      required : bool;
    }
  | Yfind_file of {
      cvar : yelu_cvar;
      names : yarg list;
      paths : yarg list;
      hints : yarg list;
      no_default_path : bool;
      no_cmake_environment_path : bool;
      no_system_environment_path : bool;
      required : bool;
    }
  | Yfind_package of {
      name : string;
      version : string option;
      exact : bool;
      quiet : bool;
      config_mode : bool;
      required : bool;
      components : string list;
      optional_components : string list;
    }

type yelu_state_exp =
  (* plain variables *)
  | Ystate_set of { cvar : yelu_cvar; values : yarg list; parent_scope : bool }
  (* cache *)
  | Ystate_option of { cvar : yelu_cvar; msg : string; value : yarg }
  | Ystate_set_cache of {
      cvar : yelu_cvar;
      values : yarg list;
      cache_type : Lang_cmake.cache_type;
      docstring : string;
      force : bool;
    }
  | Ystate_unset_cache of { cvar : yelu_cvar }
  (* env *)
  | Ystate_set_env of { var : string; value : yarg }
  | Ystate_unset_env of { var : string }
  (* property — scoped getters/setters *)
  | Ystate_get_property of {
      var : yelu_cvar;
      target : yarg;
      property : string;
      set : bool;
    }
  | Ystate_get_directory_property of { var : yelu_cvar; property : string }
  | Ystate_set_directory_property of { property : string; append : bool; values : yarg list }
  | Ystate_set_tests_properties of {
      tests : yarg list;
      properties : (property_key * yarg) list;
    }
  | Ystate_set_target_properties of {
      target : yarg;
      properties : (property_key * yarg) list;
    }
  | Ystate_set_property of {
      targets : yarg list;
      append : bool;
      properties : (property_key * yarg) list;
    }
  | Ystate_set_source_property of {
      file : yarg;
      property : string;
      values : yarg list;
    }
  | Ystate_set_global_property of { properties : (property_key * yarg) list }
  | Ystate_get_global_property of { var : yelu_cvar; property : string }
  | Ystate_get_target_property of {
      var : yelu_cvar;
      target : string;
      property : string;
    }
  | Ystate_define_property of {
      mode : Lang_cmake.define_property_mode;
      property_name : string;
      inherited : bool;
      brief_docs : string list;
      full_docs : string list;
      initialize_from : string option;
    }

type yelu_list_exp =
  | Ylist_append of { cvar : yelu_cvar; values : yarg list }
  | Ylist_length of { cvar : yelu_cvar; out : yelu_cvar }
  | Ylist_get of { cvar : yelu_cvar; indices : int list; out : yelu_cvar }
  | Ylist_remove_item of { cvar : yelu_cvar; values : yarg list }
  | Ylist_remove_duplicates of { cvar : yelu_cvar }
  | Ylist_reverse of { cvar : yelu_cvar }
  | Ylist_sort of {
      cvar : yelu_cvar;
      order : Lang_cmake.list_sort_order option;
      compare : Lang_cmake.list_sort_compare option;
      case : Lang_cmake.list_sort_case option;
    }
  | Ylist_filter of { cvar : yelu_cvar; mode : Lang_cmake.list_filter_mode; regex : string }
  | Ylist_join of { cvar : yelu_cvar; glue : yarg; out : yelu_cvar }
  | Ylist_sublist of { cvar : yelu_cvar; begin_ : int; length : int; out : yelu_cvar }
  | Ylist_find of { cvar : yelu_cvar; value : yarg; out : yelu_cvar }
  | Ylist_prepend of { cvar : yelu_cvar; values : yarg list }
  | Ylist_insert of { cvar : yelu_cvar; index : int; values : yarg list }
  | Ylist_remove_at of { cvar : yelu_cvar; indices : int list }
  | Ylist_pop_back of { cvar : yelu_cvar; out_vars : yelu_cvar list }
  | Ylist_pop_front of { cvar : yelu_cvar; out_vars : yelu_cvar list }
  | Ylist_transform of {
      cvar : yelu_cvar;
      action : Lang_cmake.list_transform_action;
      selector : Lang_cmake.list_transform_selector option;
      output : yelu_cvar option;
    }

type yelu_string_exp =
  | Ystr_toupper of { string : yarg; out : yelu_cvar }
  | Ystr_tolower of { string : yarg; out : yelu_cvar }
  | Ystr_length of { string : yarg; out : yelu_cvar }
  | Ystr_strip of { string : yarg; out : yelu_cvar }
  | Ystr_concat of { out : yelu_cvar; inputs : yarg list }
  | Ystr_replace of { match_string : yarg; replace_string : yarg; out : yelu_cvar; inputs : yarg list }
  | Ystr_regex_match of { regex : string; out : yelu_cvar; inputs : yarg list }
  | Ystr_regex_matchall of { regex : string; out : yelu_cvar; inputs : yarg list }
  | Ystr_regex_replace of { regex : string; replace : yarg; out : yelu_cvar; inputs : yarg list }
  | Ystr_regex_quote of { out : yelu_cvar; inputs : yarg list }
  | Ystr_append of { cvar : yelu_cvar; inputs : yarg list }
  | Ystr_prepend of { cvar : yelu_cvar; inputs : yarg list }
  | Ystr_join of { glue : yarg; out : yelu_cvar; inputs : yarg list }
  | Ystr_find of { string : yarg; substring : yarg; out : yelu_cvar; reverse : bool }
  | Ystr_substring of { string : yarg; begin_ : int; length : int option; out : yelu_cvar }
  | Ystr_repeat of { string : yarg; count : int; out : yelu_cvar }
  | Ystr_genex_strip of { string : yarg; out : yelu_cvar }
  | Ystr_compare of { op : Lang_cmake.string_compare_op; string1 : yarg; string2 : yarg; out : yelu_cvar }
  | Ystr_make_c_identifier of { string : yarg; out : yelu_cvar }
  | Ystr_timestamp of { out : yelu_cvar; format : string option; utc : bool }
  | Ystr_hex of { string : yarg; out : yelu_cvar }
  | Ystr_uuid of { out : yelu_cvar; namespace : string; name : string; type_ : [ `Md5 | `Sha1 ]; upper : bool }
  | Ystr_json of { out : yelu_cvar; error_var : yelu_cvar option; op : yelu_json_op }

type yelu_exp =
  | Ye_cmake of yelu_cmake_exp
  | Ye_test of yelu_test_exp
  | Ye_try of yelu_try_exp
  | Ye_state of yelu_state_exp
  | Ye_target of yelu_target_exp
  | Ye_dir of yelu_dir_exp
  | Ye_file of yelu_file_exp
  | Ylet of { var : yelu_var; value : yarg }
  | Yif of { cond : yelu_cond; then_ : yelu_exp; else_ : yelu_exp option }
  | Yexp_list of yelu_exp list
  (* scripting *)
  | Yc_include of { file : yarg; optional : bool }
  | Yc_function of { name : yarg; args : string list; body : yelu_exp list }
  | Yc_macro of { name : yarg; args : string list; body : yelu_exp list }
  | Yc_apply of { name : yarg; args : yarg list }
  | Yc_execute_process of {
      commands : yarg list list;
      working_directory : yarg option;
      timeout : float option;
      result_variable : yelu_cvar option;
      output_variable : yelu_cvar option;
      error_variable : yelu_cvar option;
      input_file : yarg option;
      output_file : yarg option;
      error_file : yarg option;
      output_quiet : bool;
      error_quiet : bool;
      output_strip_trailing_whitespace : bool;
      error_strip_trailing_whitespace : bool;
      command_error_is_fatal : string option;
    }
  | Yc_quote_cmd of string   (* retired: compile case raises — add typed nodes instead *)
  | Yc_at_var of string   (* cmake configure substitution marker: @KEY@ — used in configure_file templates *)
  | Ye_list of yelu_list_exp
  (* language *)
  | Yc_include_guard of { scope : Lang_cmake.include_guard_scope }
  | Yc_separate_arguments of { cvar : yelu_cvar; mode : Lang_cmake.separate_arguments_mode; input : yarg option }
  | Ye_install of yelu_install_exp
  (* extern declarations — register in env without emitting cmake *)
  | Yc_extern_cvar of yelu_cvar
  | Yc_extern_target of yelu_target
  (* Tier 1: find_var commands *)
  | Ye_find of yelu_find_exp
  | Yc_message of { mode : Lang_cmake.message_mode; texts : string list }
  (* Tier 2: iteration and control flow *)
  | Yc_foreach of {
      loop_var : yelu_cvar;  (* cmake variable name for loop var *)
      items : yarg list;     (* items to iterate over *)
      commands : yelu_exp;
    }
  | Yc_foreach_range of {
      loop_var : yelu_cvar;
      start : int option;
      stop : int;
      step : int option;
      commands : yelu_exp;
    }
  | Yc_foreach_in of {
      loop_var : yelu_cvar;
      lists : yelu_cvar list; (* cmake vars holding lists *)
      items : yarg list;      (* direct items *)
      commands : yelu_exp;
    }
  | Yc_foreach_zip of {
      loop_vars : yelu_cvar list;
      lists : yelu_cvar list;
      commands : yelu_exp;
    }
  | Yc_while of { cond : yelu_cond; commands : yelu_exp }
  | Yc_break
  | Yc_continue
  | Yc_return of { propogate_vars : string list }
  | Ye_string of yelu_string_exp
  (* math *)
  (* block() / endblock() — variable scope isolation *)
  | Yc_block of { scope_vars : yelu_cvar list; propagate : string; body : yelu_exp list }
