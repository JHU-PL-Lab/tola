(** Parametric AST shapes for yelu — aggregates all theory groups.

    [LANG_TYPES] lives in [Lang_yelu_sig]. Cond and string theories live in
    [Lang_yelu_cond] and [Lang_yelu_string] respectively, each colocated with
    their checkers. Remaining theories are defined here until they gain
    checkers and are split out.

    [Make_stmt] bundles all theories at a given substrate; packs instantiate
    it once with [include Lang_yelu.Make_stmt (My_types)]. *)

module type LANG_TYPES = Lang_yelu_type.LANG_TYPES

(* ============================================================
   List operations
   ============================================================ *)

module Make_list_op (T : LANG_TYPES) = struct
  type yelu_list_stmt =
    | Ylist_append of { cvar : T.var; values : T.expr list }
    | Ylist_length of { cvar : T.var; out : T.var }
    | Ylist_get of { cvar : T.var; indices : int list; out : T.var }
    | Ylist_remove_item of { cvar : T.var; values : T.expr list }
    | Ylist_remove_duplicates of { cvar : T.var }
    | Ylist_reverse of { cvar : T.var }
    | Ylist_sort of {
        cvar : T.var;
        order : Lang_cmake.list_sort_order option;
        compare : Lang_cmake.list_sort_compare option;
        case : Lang_cmake.list_sort_case option;
      }
    | Ylist_filter of {
        cvar : T.var;
        mode : Lang_cmake.list_filter_mode;
        regex : string;
      }
    | Ylist_join of { cvar : T.var; glue : T.expr; out : T.var }
    | Ylist_sublist of { cvar : T.var; begin_ : int; length : int; out : T.var }
    | Ylist_find of { cvar : T.var; value : T.expr; out : T.var }
    | Ylist_prepend of { cvar : T.var; values : T.expr list }
    | Ylist_insert of { cvar : T.var; index : int; values : T.expr list }
    | Ylist_remove_at of { cvar : T.var; indices : int list }
    | Ylist_pop_back of { cvar : T.var; out_vars : T.var list }
    | Ylist_pop_front of { cvar : T.var; out_vars : T.var list }
    | Ylist_transform of {
        cvar : T.var;
        action : Lang_cmake.list_transform_action;
        selector : Lang_cmake.list_transform_selector option;
        output : T.var option;
      }
end

(* ============================================================
   File operations (file IO + cmake_path)
   ============================================================ *)

module Make_file_op (T : LANG_TYPES) = struct
  type yelu_file_stmt =
    (* file() IO *)
    | Yfile_read of {
        out : T.var;
        file : T.expr;
        offset : int option;
        limit : int option;
        hex : bool;
      }
    | Yfile_write of { file : T.expr; append : bool; content : T.expr list }
    | Yfile_strings of {
        out : T.var;
        file : T.expr;
        regex : string option;
        encoding : string option;
        limit_count : int option;
      }
    (* file() filesystem *)
    | Yfile_touch of { files : T.expr list; nocreate : bool }
    | Yfile_make_directory of { dirs : T.expr list }
    | Yfile_rename of {
        old_ : T.expr;
        new_ : T.expr;
        result : T.var option;
        no_replace : bool;
      }
    | Yfile_remove of { files : T.expr list; recurse : bool }
    | Yfile_copy of {
        input : T.expr;
        output : T.expr;
        result : T.var option;
        only_if_different : bool;
      }
    (* file() path queries *)
    | Yfile_real_path of {
        out : T.var;
        path : T.expr;
        base_dir : T.expr option;
        expand_tilde : bool;
      }
    | Yfile_size of { out : T.var; file : T.expr }
    | Yfile_read_symlink of { out : T.var; link : T.expr }
    | Yfile_timestamp of {
        out : T.var;
        file : T.expr;
        format : string option;
        utc : bool;
      }
    | Yfile_relative_path of { var : T.expr; base : T.expr; file : T.expr }
    | Yfile_glob of {
        out : T.var;
        recurse : bool;
        relative : T.expr option;
        configure_depends : bool;
        patterns : T.expr list;
      }
    | Yfile_configure of { input : T.expr; output : T.expr }
    (* cmake_path *)
    | Ypath_get of {
        path_var : T.var;
        field : Lang_cmake.cmake_path_get_field;
        out : T.var;
      }
    | Ypath_has of {
        path_var : T.var;
        field : Lang_cmake.cmake_path_has_field;
        out : T.var;
      }
    | Ypath_is_absolute of { path_var : T.var; out : T.var }
    | Ypath_is_relative of { path_var : T.var; out : T.var }
    | Ypath_is_prefix of {
        path_var : T.var;
        input : T.expr;
        normalize : bool;
        out : T.var;
      }
    | Ypath_compare of {
        input1 : T.expr;
        op : Lang_cmake.cmake_path_compare_op;
        input2 : T.expr;
        out : T.var;
      }
    | Ypath_set of { path_var : T.var; input : T.expr; normalize : bool }
    | Ypath_append of {
        path_var : T.var;
        inputs : T.expr list;
        out : T.var option;
      }
    | Ypath_append_string of {
        path_var : T.var;
        inputs : T.expr list;
        out : T.var option;
      }
    | Ypath_remove_filename of { path_var : T.var; out : T.var option }
    | Ypath_replace_filename of {
        path_var : T.var;
        input : T.expr;
        out : T.var option;
      }
    | Ypath_remove_extension of {
        path_var : T.var;
        last_only : bool;
        out : T.var option;
      }
    | Ypath_replace_extension of {
        path_var : T.var;
        last_only : bool;
        input : T.expr;
        out : T.var option;
      }
    | Ypath_normal_path of { path_var : T.var; out : T.var option }
    | Ypath_relative_path of {
        path_var : T.var;
        base_dir : T.expr option;
        out : T.var option;
      }
    | Ypath_absolute_path of {
        path_var : T.var;
        base_dir : T.expr option;
        normalize : bool;
        out : T.var option;
      }
    | Ypath_native_path of { path_var : T.var; normalize : bool; out : T.var }
    | Ypath_convert_to_cmake of {
        input : T.expr;
        normalize : bool;
        out : T.var;
      }
    | Ypath_convert_to_native of {
        input : T.expr;
        normalize : bool;
        out : T.var;
      }
    | Ypath_hash of { path_var : T.var; out : T.var }
    | Ypath_get_filename_component of {
        var : T.var;
        filename : T.expr;
        mode : string;
      }
end

(* ============================================================
   Conditional / boolean expressions
   ============================================================ *)

module Make_cond (T : LANG_TYPES) = struct
  type yelu_cond =
    | Ytruthy of T.expr
    | Ynot of yelu_cond
    | Yand of yelu_cond * yelu_cond
    | Yor of yelu_cond * yelu_cond
    | Yis_target of T.expr
    | Yis_defined of T.expr
    | Ystrequal of T.expr * T.expr
    | Ystrless of T.expr * T.expr
    | Ystrgreater of T.expr * T.expr
    | Ystrless_equal of T.expr * T.expr
    | Ystrgreater_equal of T.expr * T.expr
    | Yequal of T.expr * T.expr
    | Yless of T.expr * T.expr
    | Ygreater of T.expr * T.expr
    | Yless_equal of T.expr * T.expr
    | Ygreater_equal of T.expr * T.expr
    | Yin_list of T.expr * T.expr
    | Ymatches of T.expr * string
    | Yexists of T.expr
    | Yis_directory of T.expr
    | Yis_absolute of T.expr
    | Ypolicy_defined of string
    | Yversion_less of T.expr * T.expr
    | Yversion_greater of T.expr * T.expr
    | Yversion_equal of T.expr * T.expr
    | Yversion_less_equal of T.expr * T.expr
    | Yversion_greater_equal of T.expr * T.expr
end

(* ============================================================
   Target operations

   target_kind, items_with_kind, target_feature, file_set,
   target_sources_item are defined inside the functor since they
   depend on T.expr.
   ============================================================ *)

module Make_target_op (T : LANG_TYPES) = struct
  type yelu_items_with_kind = { kind : Lang_cmake.target_kind; items : T.expr list }
  type yelu_target_feature = { kind : Lang_cmake.target_kind; feature : string }

  type yelu_file_set = {
    kind : Lang_cmake.target_kind;
    type_ : Lang_cmake.file_set_type;
    base_dirs : T.expr list;
    files : T.expr list;
  }

  type yelu_target_sources_item =
    | Ytsi_plain of yelu_items_with_kind
    | Ytsi_file_set of yelu_file_set

  type yelu_target_stmt =
    | Ytgt_add_executable of {
        name : T.expr;
        exclude_from_all : bool;
        sources : T.expr list;
      }
    | Ytgt_add_library of {
        name : T.expr;
        type_ : Lang_cmake.library_type option;
        exclude_from_all : bool;
        sources : T.expr list;
      }
    | Ytgt_add_library_imported of {
        name : T.expr;
        lib_type : string option;
        global : bool;
      }
    | Ytgt_add_library_alias of { name : string; target : string }
    | Ytgt_add_executable_alias of { name : string; target : string }
    | Ytgt_include_directories of {
        target : T.expr;
        before : bool;
        system : bool;
        items : yelu_items_with_kind list;
      }
    | Ytgt_link_libraries of {
        targets : T.expr list;
        items : yelu_items_with_kind list;
      }
    | Ytgt_compile_definitions of {
        target : T.expr;
        items : yelu_items_with_kind list;
      }
    | Ytgt_compile_features of {
        target : T.expr;
        features : yelu_target_feature list;
      }
    | Ytgt_compile_options of {
        target : T.expr;
        before : bool;
        items : yelu_items_with_kind list;
      }
    | Ytgt_link_options of {
        target : T.expr;
        before : bool;
        items : yelu_items_with_kind list;
      }
    | Ytgt_link_directories of {
        target : T.expr;
        before : bool;
        items : yelu_items_with_kind list;
      }
    | Ytgt_sources of { target : T.expr; items : yelu_items_with_kind list }
    | Ytgt_sources_fs of {
        target : T.expr;
        items : yelu_target_sources_item list;
      }
    | Ytgt_precompile_headers of {
        target : T.expr;
        items : yelu_items_with_kind list;
      }
    | Ytgt_add_custom_command of {
        outputs : T.expr list;
        commands : Lang_cmake.custom_command list;
        depends : T.expr list;
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
        depends : T.expr list;
        comment : string option;
      }
    | Ytgt_add_dependencies of { target : string; dep : string }
end

(* ============================================================
   Directory-scope operations
   ============================================================ *)

module Make_dir_op (T : LANG_TYPES) = struct
  type yelu_dir_stmt =
    | Ydir_include_directories of {
        dirs : T.expr list;
        before : bool;
        system : bool;
      }
    | Ydir_add_compile_definitions of { defs : T.expr list }
    | Ydir_add_compile_options of { options : T.expr list }
    | Ydir_add_link_options of { options : T.expr list }
    | Ydir_add_definitions of { defs : T.expr list }
    | Ydir_link_directories of { before : bool; dirs : T.expr list }
    | Ydir_add_subdirectory of { source_dir : T.expr }
    | Ydir_link_libraries of { items : T.expr list }
end

(* ============================================================
   State operations (variable / cache / env / property)
   ============================================================ *)

module Make_state_op (T : LANG_TYPES) = struct
  type yelu_state_stmt =
    (* plain variables *)
    | Ystate_set of { cvar : T.var; values : T.expr list; parent_scope : bool }
    (* cache *)
    | Ystate_option of { cvar : T.var; msg : string; value : T.expr }
    | Ystate_set_cache of {
        cvar : T.var;
        values : T.expr list;
        cache_type : Lang_cmake.cache_type;
        docstring : string;
        force : bool;
      }
    | Ystate_unset_cache of { cvar : T.var }
    (* env *)
    | Ystate_set_env of { var : string; value : T.expr }
    | Ystate_unset_env of { var : string }
    (* property *)
    | Ystate_get_property of {
        var : T.var;
        target : T.expr;
        property : string;
        set : bool;
      }
    | Ystate_get_directory_property of { var : T.var; property : string }
    | Ystate_set_directory_property of {
        property : string;
        append : bool;
        values : T.expr list;
      }
    | Ystate_set_tests_properties of {
        tests : T.expr list;
        properties : (string * T.expr) list;
      }
    | Ystate_set_target_properties of {
        target : T.expr;
        properties : (string * T.expr) list;
      }
    | Ystate_set_property of {
        targets : T.expr list;
        append : bool;
        properties : (string * T.expr) list;
      }
    | Ystate_set_source_property of {
        file : T.expr;
        property : string;
        values : T.expr list;
      }
    | Ystate_set_global_property of { properties : (string * T.expr) list }
    | Ystate_get_global_property of { var : T.var; property : string }
    | Ystate_get_target_property of {
        var : T.var;
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
end

(* ============================================================
   Find operations
   ============================================================ *)

module Make_find_op (T : LANG_TYPES) = struct
  type yelu_find_stmt =
    | Yfind_library of {
        cvar : T.var;
        names : T.expr list;
        paths : T.expr list;
        hints : T.expr list;
        no_default_path : bool;
        no_cmake_environment_path : bool;
        no_system_environment_path : bool;
        required : bool;
      }
    | Yfind_path of {
        cvar : T.var;
        names : T.expr list;
        paths : T.expr list;
        hints : T.expr list;
        no_default_path : bool;
        no_cmake_environment_path : bool;
        no_system_environment_path : bool;
        required : bool;
      }
    | Yfind_program of {
        cvar : T.var;
        names : T.expr list;
        paths : T.expr list;
        hints : T.expr list;
        no_default_path : bool;
        no_cmake_environment_path : bool;
        no_system_environment_path : bool;
        required : bool;
      }
    | Yfind_file of {
        cvar : T.var;
        names : T.expr list;
        paths : T.expr list;
        hints : T.expr list;
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
end

(* ============================================================
   Install operations
   ============================================================ *)

module Make_install_op (T : LANG_TYPES) = struct
  type yelu_install_stmt =
    | Yinstall_targets of {
        targets : T.expr list;
        destination : T.expr;
        export : T.expr option;
      }
    | Yinstall_files of { files : T.expr list; destination : T.expr }
    | Yinstall_export of {
        file : T.expr option;
        export : T.expr;
        destination : T.expr;
        namespace : string option;
      }
    | Yinstall_export_export of { name : T.expr; file : T.expr option }
    | Yinstall_configure_package_config_file of {
        install_dest : T.expr;
        input : T.expr;
        output : T.expr;
        no_set_and_check_macro : bool;
        no_check_required_components_macro : bool;
      }
    | Yinstall_write_basic_package_version_file of {
        file : T.expr;
        version : T.expr option;
        compatibility : Lang_cmake.compatibility;
        arch_independent : bool;
      }
end

(* ============================================================
   Test operations
   ============================================================ *)

module Make_test_op (T : LANG_TYPES) = struct
  type yelu_test_stmt =
    | Ytest_enable_testing
    | Ytest_add_test of { name : T.expr; command : T.expr; args : T.expr list }
end

(* ============================================================
   Try operations (try_compile / try_run)
   ============================================================ *)

module Make_try_op (T : LANG_TYPES) = struct
  type yelu_try_stmt =
    | Ytry_compile of {
        result_var : T.var;
        sources : T.expr list;
        compile_definitions : T.expr list;
        link_libraries : T.expr list;
        link_options : T.expr list;
        output_variable : T.var option;
        no_cache : bool;
        c_standard : string option;
        cxx_standard : string option;
      }
    | Ytry_run of {
        run_result_var : T.var;
        compile_result_var : T.var;
        sources : T.expr list;
        compile_definitions : T.expr list;
        link_libraries : T.expr list;
        compile_output_variable : T.var option;
        run_output_variable : T.var option;
        args : T.expr list;
      }
end

(* ============================================================
   Cmake meta operations
   ============================================================ *)

module Make_cmake_op (T : LANG_TYPES) = struct
  type yelu_cmake_stmt =
    | Ycmake_minimum_required of {
        min : Lang_cmake.version;
        max : Lang_cmake.version option;
      }
    | Ycmake_project of {
        name : string;
        version : Lang_cmake.version option;
        languages : Lang_cmake.supported_lang list;
      }
    | Ycmake_enable_language of { langs : string list; optional : bool }
    | Ycmake_policy_set of { id : string; new_ : bool }
    | Ycmake_language_call of { cmd : string; args : T.expr list }
    | Ycmake_language_eval of { code : string }
    | Ycmake_language_get_log_level of { out : T.var }
    | Ycmake_math of {
        exp : string;
        out : T.var;
        output_format : Lang_cmake.math_output_format;
      }
    | Ycmake_variable_watch of { var : T.var; command : string option }
    | Ycmake_execute_process of {
        commands : T.expr list list;
        working_directory : T.expr option;
        timeout : float option;
        result_variable : T.var option;
        output_variable : T.var option;
        error_variable : T.var option;
        input_file : T.expr option;
        output_file : T.expr option;
        error_file : T.expr option;
        output_quiet : bool;
        error_quiet : bool;
        output_strip_trailing_whitespace : bool;
        error_strip_trailing_whitespace : bool;
        command_error_is_fatal : string option;
      }
    | Ycmake_include_guard of { scope : Lang_cmake.include_guard_scope }
    | Ycmake_message of { mode : Lang_cmake.message_mode; texts : string list }
    (* cmake escape hatches — raw injection, outside the typed language *)
    | Ycmake_quote_cmd of string
    | Ycmake_at_var of string
end

(* [Make_stmt] is a functor application bundle — it [include]s every
   per-group functor at a given substrate [T] so a pack can pull all
   group types and constructors into its top-level namespace with one
   [include Lang_yelu.Make_stmt (My_types)].

   The top-level [yelu_stmt] sum type (which weaves group statements
   with cmake-specific scripting and control flow) does NOT live here —
   each pack composes its own statement type from these group bundles
   plus its pack-specific scripting vocabulary. *)
module Make_stmt (T : LANG_TYPES) = struct
  include Lang_yelu_cond.Make_cond (T)
  include Lang_yelu_string.Make_string_op (T)
  include Make_target_op (T)
  include Make_file_op (T)
  include Make_list_op (T)
  include Make_state_op (T)
  include Make_find_op (T)
  include Make_install_op (T)
  include Make_test_op (T)
  include Make_try_op (T)
  include Make_dir_op (T)
  include Make_cmake_op (T)
end
