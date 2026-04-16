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
  | Ycs_raw of string         (* cmake expression, opaque pass-through *)

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

type yelu_exp =
  | Yc_minimum_required of { min : version; max : version option }
  | Yc_project of {
      name : project_name;
      version : version option;
      languages : supported_lang list;
    }
  | Yc_set of { cvar : yarg; values : yarg list; parent_scope : bool }
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
  | Yc_option of { cvar : yarg; msg : string; value : yarg }
  | Ylet of { var : yelu_var; value : yarg }
  | Yif of { cond : yelu_cond; then_ : yelu_exp; else_ : yelu_exp option }
  | Yexp_list of yelu_exp list
  (* scripting *)
  | Yc_include of { file : yarg; optional : bool }
  | Yc_function of { name : yarg; args : string list; body : yelu_exp list }
  | Yc_macro of { name : yarg; args : string list; body : yelu_exp list }
  | Yc_apply of { name : yarg; args : yarg list }
  | Yc_unset_cache of { cvar : yarg }
  | Yc_file_relative_path of { var : yarg; base : yarg; file : yarg }
  | Yc_quote_cmd of string
  | Yc_list_append of { cvar : yarg; values : yarg list }
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
      cvar : yarg;
      names : yarg list;
      paths : yarg list;
      hints : yarg list;
      no_default_path : bool;
      no_cmake_environment_path : bool;
      no_system_environment_path : bool;
      required : bool;
    }
  | Yc_find_path of {
      cvar : yarg;
      names : yarg list;
      paths : yarg list;
      hints : yarg list;
      no_default_path : bool;
      no_cmake_environment_path : bool;
      no_system_environment_path : bool;
      required : bool;
    }
  | Yc_find_program of {
      cvar : yarg;
      names : yarg list;
      paths : yarg list;
      hints : yarg list;
      no_default_path : bool;
      no_cmake_environment_path : bool;
      no_system_environment_path : bool;
      required : bool;
    }
  | Yc_find_file of {
      cvar : yarg;
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
      loop_var : string;      (* cmake variable name for loop var *)
      items : yarg list;      (* items to iterate over *)
      commands : yelu_exp;
    }
  | Yc_foreach_range of {
      loop_var : string;
      start : int option;
      stop : int;
      step : int option;
      commands : yelu_exp;
    }
  | Yc_foreach_in of {
      loop_var : string;
      lists : yarg list;     (* cmake vars holding lists *)
      items : yarg list;     (* direct items *)
      commands : yelu_exp;
    }
  | Yc_while of { cond : yelu_cond; commands : yelu_exp }
  | Yc_break
  | Yc_continue
  | Yc_return of { propogate_vars : string list }
  (* Tier 2: list commands *)
  | Yc_list_length of { cvar : yarg; out : string }
  | Yc_list_get of { cvar : yarg; indices : int list; out : string }
  | Yc_list_remove_item of { cvar : yarg; values : yarg list }
  | Yc_list_remove_duplicates of { cvar : yarg }
  | Yc_list_reverse of { cvar : yarg }
  | Yc_list_sort of {
      cvar : yarg;
      order : Lang_cmake.list_sort_order option;
      compare : Lang_cmake.list_sort_compare option;
      case : Lang_cmake.list_sort_case option;
    }
  | Yc_list_filter of { cvar : yarg; mode : Lang_cmake.list_filter_mode; regex : string }
  (* Tier 2: string commands *)
  | Yc_string_toupper of { string : yarg; out : string }
  | Yc_string_tolower of { string : yarg; out : string }
  | Yc_string_length of { string : yarg; out : string }
  | Yc_string_strip of { string : yarg; out : string }
  | Yc_string_concat of { out : string; inputs : yarg list }
  | Yc_string_replace of {
      match_string : yarg;
      replace_string : yarg;
      out : string;
      inputs : yarg list;
    }
  | Yc_string_regex_match of { regex : string; out : string; inputs : yarg list }
  | Yc_string_regex_replace of { regex : string; replace : yarg; out : string; inputs : yarg list }
