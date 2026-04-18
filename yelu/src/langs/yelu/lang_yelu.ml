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

(* Unified arg type — replaces old yelu_value + yelu_item *)
type yarg =
  | Yarg_cvar of yelu_cvar
  | Yarg_target of yelu_target
  | Yarg_string of yc_string  (* file, dir, name, value, or raw cmake expr *)
  | Yarg_bool of bool
  | Yarg_var of yelu_var  (* compile-time variable reference *)

type yelu_items_with_kind = { kind : target_kind; items : yarg list }
type yelu_target_feature = { kind : target_kind; feature : feature_name }

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

type yelu_exp =
  | Yc_minimum_required of { min : version; max : version option }
  | Yc_project of {
      name : project_name;
      version : version option;
      languages : supported_lang list;
    }
  | Yc_set of { cvar : yelu_cvar; values : yarg list; parent_scope : bool }
  | Yc_add_executable of { name : yarg; sources : yarg list }
  | Yc_add_library of {
      name : yarg;
      type_ : library_type option;
      exclude_from_all : bool;
      sources : yarg list;
    }
  | Yc_add_library_imported of { name : yarg; lib_type : string option; global : bool }
  | Yc_target_include_directories of {
      target : yarg;
      items : yelu_items_with_kind list;
    }
  | Yc_target_link_libraries of {
      targets : yarg list;
      items : yelu_items_with_kind list;
    }
  | Yc_target_compile_definitions of {
      target : yarg;
      items : yelu_items_with_kind list;
    }
  | Yc_target_compile_features of {
      target : yarg;
      features : yelu_target_feature list;
    }
  | Yc_target_compile_options of {
      target : yarg;
      before : bool;
      items : yelu_items_with_kind list;
    }
  | Yc_configure_file of { input : yarg; output : yarg }
  | Yc_add_subdirectory of { source_dir : yarg }
  | Yc_option of { cvar : yelu_cvar; msg : string; value : yarg }
  | Ylet of { var : yelu_var; value : yarg }
  | Yif of { cond : yelu_cond; then_ : yelu_exp; else_ : yelu_exp option }
  | Yexp_list of yelu_exp list
  (* scripting *)
  | Yc_include of { file : yarg; optional : bool }
  | Yc_function of { name : yarg; args : string list; body : yelu_exp list }
  | Yc_macro of { name : yarg; args : string list; body : yelu_exp list }
  | Yc_apply of { name : yarg; args : yarg list }
  | Yc_set_env of { var : string; value : yarg }
  | Yc_unset_env of { var : string }
  | Yc_set_cache of {
      cvar : yelu_cvar;
      values : yarg list;
      cache_type : Lang_cmake.cache_type;
      docstring : string;
      force : bool;
    }
  | Yc_unset_cache of { cvar : yelu_cvar }
  | Yc_file_relative_path of { var : yarg; base : yarg; file : yarg }
  | Yc_quote_cmd of string
  | Yc_list_append of { cvar : yelu_cvar; values : yarg list }
  (* testing *)
  | Yc_enable_testing
  | Yc_add_test of { name : yarg; command : yarg; args : yarg list }
  | Yc_set_tests_properties of {
      tests : yarg list;
      properties : (property_key * yarg) list;
    }
  (* target properties *)
  | Yc_set_target_properties of {
      target : yarg;
      properties : (property_key * yarg) list;
    }
  | Yc_set_property of {
      targets : yarg list;
      properties : (property_key * yarg) list;
    }
  | Yc_set_global_property of { properties : (property_key * yarg) list }
  | Yc_get_filename_component of { var : yelu_cvar; filename : yarg; mode : string }
  | Yc_get_global_property of { var : yelu_cvar; property : string }
  | Yc_include_guard of { scope : Lang_cmake.include_guard_scope }
  | Yc_separate_arguments of { cvar : yelu_cvar; mode : Lang_cmake.separate_arguments_mode; input : yarg option }
  | Yc_target_link_options of { target : yarg; before : bool; items : yelu_items_with_kind list }
  | Yc_target_sources of { target : yarg; items : yelu_items_with_kind list }
  (* install *)
  | Yc_install_targets of {
      targets : yarg list;
      destination : yarg;
      export : yarg option;
    }
  | Yc_install_files of { files : yarg list; destination : yarg }
  | Yc_install_export of {
      file : yarg option;
      export : yarg;
      destination : yarg;
    }
  (* export *)
  | Yc_export_export of { name : yarg; file : yarg option }
  (* module commands *)
  | Yc_configure_package_config_file of {
      install_dest : yarg;
      input : yarg;
      output : yarg;
      no_set_and_check_macro : bool;
      no_check_required_components_macro : bool;
    }
  | Yc_write_basic_package_version_file of {
      file : yarg;
      version : yarg option;
      compatibility : compatibility;
    }
  (* custom commands *)
  | Yc_add_custom_command of {
      outputs : yarg list;
      commands : Lang_cmake.custom_command list;
      depends : yarg list;
    }
  (* extern declarations — register in env without emitting cmake *)
  | Yc_extern_cvar of yelu_cvar
  | Yc_extern_target of yelu_target
  (* Tier 1: find_var commands *)
  | Yc_find_library of {
      cvar : yelu_cvar;
      names : yarg list;
      paths : yarg list;
      hints : yarg list;
      no_default_path : bool;
      no_cmake_environment_path : bool;
      no_system_environment_path : bool;
      required : bool;
    }
  | Yc_find_path of {
      cvar : yelu_cvar;
      names : yarg list;
      paths : yarg list;
      hints : yarg list;
      no_default_path : bool;
      no_cmake_environment_path : bool;
      no_system_environment_path : bool;
      required : bool;
    }
  | Yc_find_program of {
      cvar : yelu_cvar;
      names : yarg list;
      paths : yarg list;
      hints : yarg list;
      no_default_path : bool;
      no_cmake_environment_path : bool;
      no_system_environment_path : bool;
      required : bool;
    }
  | Yc_find_file of {
      cvar : yelu_cvar;
      names : yarg list;
      paths : yarg list;
      hints : yarg list;
      no_default_path : bool;
      no_cmake_environment_path : bool;
      no_system_environment_path : bool;
      required : bool;
    }
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
  (* Tier 2: list commands *)
  | Yc_list_length of { cvar : yelu_cvar; out : yelu_cvar }
  | Yc_list_get of { cvar : yelu_cvar; indices : int list; out : yelu_cvar }
  | Yc_list_remove_item of { cvar : yelu_cvar; values : yarg list }
  | Yc_list_remove_duplicates of { cvar : yelu_cvar }
  | Yc_list_reverse of { cvar : yelu_cvar }
  | Yc_list_sort of {
      cvar : yelu_cvar;
      order : Lang_cmake.list_sort_order option;
      compare : Lang_cmake.list_sort_compare option;
      case : Lang_cmake.list_sort_case option;
    }
  | Yc_list_filter of { cvar : yelu_cvar; mode : Lang_cmake.list_filter_mode; regex : string }
  | Yc_list_join of { cvar : yelu_cvar; glue : yarg; out : yelu_cvar }
  | Yc_list_sublist of { cvar : yelu_cvar; begin_ : int; length : int; out : yelu_cvar }
  | Yc_list_find of { cvar : yelu_cvar; value : yarg; out : yelu_cvar }
  | Yc_list_prepend of { cvar : yelu_cvar; values : yarg list }
  | Yc_list_insert of { cvar : yelu_cvar; index : int; values : yarg list }
  | Yc_list_remove_at of { cvar : yelu_cvar; indices : int list }
  | Yc_list_pop_back of { cvar : yelu_cvar; out_vars : yelu_cvar list }
  | Yc_list_pop_front of { cvar : yelu_cvar; out_vars : yelu_cvar list }
  | Yc_list_transform of {
      cvar : yelu_cvar;
      action : Lang_cmake.list_transform_action;
      selector : Lang_cmake.list_transform_selector option;
      output : yelu_cvar option;
    }
  (* Tier 2: string commands *)
  | Yc_string_toupper of { string : yarg; out : yelu_cvar }
  | Yc_string_tolower of { string : yarg; out : yelu_cvar }
  | Yc_string_length of { string : yarg; out : yelu_cvar }
  | Yc_string_strip of { string : yarg; out : yelu_cvar }
  | Yc_string_concat of { out : yelu_cvar; inputs : yarg list }
  | Yc_string_replace of {
      match_string : yarg;
      replace_string : yarg;
      out : yelu_cvar;
      inputs : yarg list;
    }
  | Yc_string_regex_match of { regex : string; out : yelu_cvar; inputs : yarg list }
  | Yc_string_regex_matchall of { regex : string; out : yelu_cvar; inputs : yarg list }
  | Yc_string_regex_replace of { regex : string; replace : yarg; out : yelu_cvar; inputs : yarg list }
  | Yc_string_append of { cvar : yelu_cvar; inputs : yarg list }
  | Yc_string_prepend of { cvar : yelu_cvar; inputs : yarg list }
  | Yc_string_join of { glue : yarg; out : yelu_cvar; inputs : yarg list }
  | Yc_string_find of { string : yarg; substring : yarg; out : yelu_cvar; reverse : bool }
  | Yc_string_substring of { string : yarg; begin_ : int; length : int option; out : yelu_cvar }
  | Yc_string_repeat of { string : yarg; count : int; out : yelu_cvar }
  | Yc_string_genex_strip of { string : yarg; out : yelu_cvar }
  | Yc_string_compare of {
      op : Lang_cmake.string_compare_op;
      string1 : yarg;
      string2 : yarg;
      out : yelu_cvar;
    }
  | Yc_string_make_c_identifier of { string : yarg; out : yelu_cvar }
  | Yc_string_timestamp of { out : yelu_cvar; format : string option; utc : bool }
  | Yc_string_hex of { string : yarg; out : yelu_cvar }
  | Yc_string_uuid of {
      out : yelu_cvar;
      namespace : string;
      name : string;
      type_ : [ `Md5 | `Sha1 ];
      upper : bool;
    }
  | Yc_string_json of {
      out : yelu_cvar;
      error_var : yelu_cvar option;
      op : yelu_json_op;
    }
  (* math *)
  | Yc_math of {
      exp : string;
      out : yelu_cvar;
      output_format : Lang_cmake.math_output_format;
    }
