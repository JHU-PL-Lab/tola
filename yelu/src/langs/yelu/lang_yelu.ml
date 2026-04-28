(** Parametric AST shapes for yelu — full coverage of all groups.

    Functors are used purely as type-level macros: a [LANG_TYPES] module
    parameterizes the variable/argument/target substrate, and each
    functor outputs a concrete sum type whose constructors are
    pattern-matchable directly. No interface abstraction, no
    information hiding.

    Auxiliary enums (target_kind, cache_type, etc.) are referenced
    directly from [Lang_yelu_cmake] / [Lang_cmake]. We only abstract over
    the substrate (var, target, arg); enums are concrete because their
    semantics are cmake-flavored anyway and lifting them adds noise
    without real value at the first cut.

    Source of truth: [Lang_yelu_cmake] instantiates these functors at
    [Cmake_types] via [include], so its group types ARE the parametric
    types applied to cmake substrate (applicative-functor identity).
    Future packs (json, nix, …) would create their own concrete
    instances by instantiating with their own substrate.
*)

module type LANG_TYPES = sig
  (** Runtime variable handle (≅ [yelu_cvar] in cmake-pack). *)
  type var

  (** Value-bearing expression substrate (≅ [yelu_expr] in cmake-pack). *)
  type expr

  (** Target name handle (≅ [yelu_target] in cmake-pack). *)
  type target
end

(* ============================================================
   Shared enums — owned at the parametric layer so functors can
   reference them without depending on Lang_yelu_cmake. Lang_yelu_cmake
   re-exports these via manifest-variant aliases.
   ============================================================ *)

type target_kind = Public | Private | Interface | Plain

type library_type =
  | Lib_static
  | Lib_shared
  | Lib_module
  | Lib_unknown
  | Lib_object
  | Lib_interface
  | Lib_global

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

(* Compile-time variable name (yelu's let-bound names — distinct from
   the target language's runtime variables which live in T.var). *)
type yelu_var = Yvar of string

(* ============================================================
   Universal helper enums

   Owned at the parametric layer because their semantics are
   host-language-agnostic.
   ============================================================ *)

type list_sort_order = Asc | Desc

type list_sort_compare =
  | Cmp_string
  | Cmp_file_basename
  | Cmp_natural

type list_sort_case = Case_sensitive | Case_insensitive
type list_filter_mode = Filter_include | Filter_exclude

type string_compare_op =
  | Streq
  | Strneq
  | Strless
  | Strgreater
  | Strless_eq
  | Strgreater_eq

type math_output_format = Decimal | Hexadecimal

(* ============================================================
   JSON operations (used by string ops as a sub-variant)
   ============================================================ *)

module Make_json_op (T : LANG_TYPES) = struct
  type yelu_json_op =
    | Yjop_get of { json : T.expr; path : string list }
    | Yjop_get_raw of { json : T.expr; path : string list }
    | Yjop_type of { json : T.expr; path : string list }
    | Yjop_length of { json : T.expr; path : string list }
    | Yjop_member of { json : T.expr; path : string list }
    | Yjop_remove of { json : T.expr; path : string list }
    | Yjop_set of { json : T.expr; path : string list; value : T.expr }
    | Yjop_equal of { json1 : T.expr; json2 : T.expr }
    | Yjop_string_encode of { value : T.expr }
end

(* ============================================================
   String operations
   ============================================================ *)

module Make_string_op (T : LANG_TYPES) = struct
  module Json = Make_json_op (T)

  type yelu_string_stmt =
    | Ystr_toupper of { string : T.expr; out : T.var }
    | Ystr_tolower of { string : T.expr; out : T.var }
    | Ystr_length of { string : T.expr; out : T.var }
    | Ystr_strip of { string : T.expr; out : T.var }
    | Ystr_concat of { out : T.var; inputs : T.expr list }
    | Ystr_replace of {
        match_string : T.expr;
        replace_string : T.expr;
        out : T.var;
        inputs : T.expr list;
      }
    | Ystr_regex_match of { regex : string; out : T.var; inputs : T.expr list }
    | Ystr_regex_matchall of { regex : string; out : T.var; inputs : T.expr list }
    | Ystr_regex_replace of {
        regex : string;
        replace : T.expr;
        out : T.var;
        inputs : T.expr list;
      }
    | Ystr_regex_quote of { out : T.var; inputs : T.expr list }
    | Ystr_append of { cvar : T.var; inputs : T.expr list }
    | Ystr_prepend of { cvar : T.var; inputs : T.expr list }
    | Ystr_join of { glue : T.expr; out : T.var; inputs : T.expr list }
    | Ystr_find of {
        string : T.expr;
        substring : T.expr;
        out : T.var;
        reverse : bool;
      }
    | Ystr_substring of {
        string : T.expr;
        begin_ : int;
        length : int option;
        out : T.var;
      }
    | Ystr_repeat of { string : T.expr; count : int; out : T.var }
    | Ystr_genex_strip of { string : T.expr; out : T.var }
    | Ystr_compare of {
        op : Lang_cmake.string_compare_op;
        string1 : T.expr;
        string2 : T.expr;
        out : T.var;
      }
    | Ystr_make_c_identifier of { string : T.expr; out : T.var }
    | Ystr_timestamp of { out : T.var; format : string option; utc : bool }
    | Ystr_hex of { string : T.expr; out : T.var }
    | Ystr_uuid of {
        out : T.var;
        namespace : string;
        name : string;
        type_ : [ `Md5 | `Sha1 ];
        upper : bool;
      }
    | Ystr_json of {
        out : T.var;
        error_var : T.var option;
        op : Json.yelu_json_op;
      }
end

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
    | Ylist_sublist of {
        cvar : T.var;
        begin_ : int;
        length : int;
        out : T.var;
      }
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
    | Ypath_native_path of {
        path_var : T.var;
        normalize : bool;
        out : T.var;
      }
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
  type yelu_items_with_kind = {
    kind : target_kind;
    items : T.expr list;
  }

  type yelu_target_feature = {
    kind : target_kind;
    feature : string;
  }

  type yelu_file_set = {
    kind : target_kind;
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
        type_ : library_type option;
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
    | Ytgt_sources_fs of { target : T.expr; items : yelu_target_sources_item list }
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
    | Ystate_set of {
        cvar : T.var;
        values : T.expr list;
        parent_scope : bool;
      }
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
    | Ystate_set_global_property of {
        properties : (string * T.expr) list;
      }
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
        compatibility : compatibility;
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
        languages : supported_lang list;
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
end

(* ============================================================
   Top-level expression (groups + core constructs + scripting)

   This is the parametric mirror of [Lang_yelu_cmake.yelu_stmt]. Constructor
   names match yelu's so that lowering is mechanical (constructor
   pattern → same-name constructor in Lang_yelu_cmake).
   ============================================================ *)

(* [Make_stmt] is a functor application bundle — it only instantiates
   the per-group functors at a given substrate [T]. The top-level
   [yelu_stmt] sum type (which weaves group statements with cmake-
   specific scripting and control flow) lives in [Lang_yelu_cmake];
   each pack composes its own statement type from these group bundles
   plus its pack-specific scripting vocabulary. *)
module Make_stmt (T : LANG_TYPES) = struct
  module String_op = Make_string_op (T)
  module List_op = Make_list_op (T)
  module File_op = Make_file_op (T)
  module Cond = Make_cond (T)
  module Target_op = Make_target_op (T)
  module Dir_op = Make_dir_op (T)
  module State_op = Make_state_op (T)
  module Find_op = Make_find_op (T)
  module Install_op = Make_install_op (T)
  module Test_op = Make_test_op (T)
  module Try_op = Make_try_op (T)
  module Cmake_op = Make_cmake_op (T)
end
