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

  (** Argument / value substrate (≅ [yelu_expr] in cmake-pack). *)
  type arg

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
    | Yjop_get of { json : T.arg; path : string list }
    | Yjop_get_raw of { json : T.arg; path : string list }
    | Yjop_type of { json : T.arg; path : string list }
    | Yjop_length of { json : T.arg; path : string list }
    | Yjop_member of { json : T.arg; path : string list }
    | Yjop_remove of { json : T.arg; path : string list }
    | Yjop_set of { json : T.arg; path : string list; value : T.arg }
    | Yjop_equal of { json1 : T.arg; json2 : T.arg }
    | Yjop_string_encode of { value : T.arg }
end

(* ============================================================
   String operations
   ============================================================ *)

module Make_string_op (T : LANG_TYPES) = struct
  module Json = Make_json_op (T)

  type yelu_string_exp =
    | Ystr_toupper of { string : T.arg; out : T.var }
    | Ystr_tolower of { string : T.arg; out : T.var }
    | Ystr_length of { string : T.arg; out : T.var }
    | Ystr_strip of { string : T.arg; out : T.var }
    | Ystr_concat of { out : T.var; inputs : T.arg list }
    | Ystr_replace of {
        match_string : T.arg;
        replace_string : T.arg;
        out : T.var;
        inputs : T.arg list;
      }
    | Ystr_regex_match of { regex : string; out : T.var; inputs : T.arg list }
    | Ystr_regex_matchall of { regex : string; out : T.var; inputs : T.arg list }
    | Ystr_regex_replace of {
        regex : string;
        replace : T.arg;
        out : T.var;
        inputs : T.arg list;
      }
    | Ystr_regex_quote of { out : T.var; inputs : T.arg list }
    | Ystr_append of { cvar : T.var; inputs : T.arg list }
    | Ystr_prepend of { cvar : T.var; inputs : T.arg list }
    | Ystr_join of { glue : T.arg; out : T.var; inputs : T.arg list }
    | Ystr_find of {
        string : T.arg;
        substring : T.arg;
        out : T.var;
        reverse : bool;
      }
    | Ystr_substring of {
        string : T.arg;
        begin_ : int;
        length : int option;
        out : T.var;
      }
    | Ystr_repeat of { string : T.arg; count : int; out : T.var }
    | Ystr_genex_strip of { string : T.arg; out : T.var }
    | Ystr_compare of {
        op : Lang_cmake.string_compare_op;
        string1 : T.arg;
        string2 : T.arg;
        out : T.var;
      }
    | Ystr_make_c_identifier of { string : T.arg; out : T.var }
    | Ystr_timestamp of { out : T.var; format : string option; utc : bool }
    | Ystr_hex of { string : T.arg; out : T.var }
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
  type yelu_list_exp =
    | Ylist_append of { cvar : T.var; values : T.arg list }
    | Ylist_length of { cvar : T.var; out : T.var }
    | Ylist_get of { cvar : T.var; indices : int list; out : T.var }
    | Ylist_remove_item of { cvar : T.var; values : T.arg list }
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
    | Ylist_join of { cvar : T.var; glue : T.arg; out : T.var }
    | Ylist_sublist of {
        cvar : T.var;
        begin_ : int;
        length : int;
        out : T.var;
      }
    | Ylist_find of { cvar : T.var; value : T.arg; out : T.var }
    | Ylist_prepend of { cvar : T.var; values : T.arg list }
    | Ylist_insert of { cvar : T.var; index : int; values : T.arg list }
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
  type yelu_file_exp =
    (* file() IO *)
    | Yfile_read of {
        out : T.var;
        file : T.arg;
        offset : int option;
        limit : int option;
        hex : bool;
      }
    | Yfile_write of { file : T.arg; append : bool; content : T.arg list }
    | Yfile_strings of {
        out : T.var;
        file : T.arg;
        regex : string option;
        encoding : string option;
        limit_count : int option;
      }
    (* file() filesystem *)
    | Yfile_touch of { files : T.arg list; nocreate : bool }
    | Yfile_make_directory of { dirs : T.arg list }
    | Yfile_rename of {
        old_ : T.arg;
        new_ : T.arg;
        result : T.var option;
        no_replace : bool;
      }
    | Yfile_remove of { files : T.arg list; recurse : bool }
    | Yfile_copy of {
        input : T.arg;
        output : T.arg;
        result : T.var option;
        only_if_different : bool;
      }
    (* file() path queries *)
    | Yfile_real_path of {
        out : T.var;
        path : T.arg;
        base_dir : T.arg option;
        expand_tilde : bool;
      }
    | Yfile_size of { out : T.var; file : T.arg }
    | Yfile_read_symlink of { out : T.var; link : T.arg }
    | Yfile_timestamp of {
        out : T.var;
        file : T.arg;
        format : string option;
        utc : bool;
      }
    | Yfile_relative_path of { var : T.arg; base : T.arg; file : T.arg }
    | Yfile_glob of {
        out : T.var;
        recurse : bool;
        relative : T.arg option;
        configure_depends : bool;
        patterns : T.arg list;
      }
    | Yfile_configure of { input : T.arg; output : T.arg }
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
        input : T.arg;
        normalize : bool;
        out : T.var;
      }
    | Ypath_compare of {
        input1 : T.arg;
        op : Lang_cmake.cmake_path_compare_op;
        input2 : T.arg;
        out : T.var;
      }
    | Ypath_set of { path_var : T.var; input : T.arg; normalize : bool }
    | Ypath_append of {
        path_var : T.var;
        inputs : T.arg list;
        out : T.var option;
      }
    | Ypath_append_string of {
        path_var : T.var;
        inputs : T.arg list;
        out : T.var option;
      }
    | Ypath_remove_filename of { path_var : T.var; out : T.var option }
    | Ypath_replace_filename of {
        path_var : T.var;
        input : T.arg;
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
        input : T.arg;
        out : T.var option;
      }
    | Ypath_normal_path of { path_var : T.var; out : T.var option }
    | Ypath_relative_path of {
        path_var : T.var;
        base_dir : T.arg option;
        out : T.var option;
      }
    | Ypath_absolute_path of {
        path_var : T.var;
        base_dir : T.arg option;
        normalize : bool;
        out : T.var option;
      }
    | Ypath_native_path of {
        path_var : T.var;
        normalize : bool;
        out : T.var;
      }
    | Ypath_convert_to_cmake of {
        input : T.arg;
        normalize : bool;
        out : T.var;
      }
    | Ypath_convert_to_native of {
        input : T.arg;
        normalize : bool;
        out : T.var;
      }
    | Ypath_hash of { path_var : T.var; out : T.var }
    | Ypath_get_filename_component of {
        var : T.var;
        filename : T.arg;
        mode : string;
      }
end

(* ============================================================
   Conditional / boolean expressions
   ============================================================ *)

module Make_cond (T : LANG_TYPES) = struct
  type yelu_cond =
    | Ytruthy of T.arg
    | Ynot of yelu_cond
    | Yand of yelu_cond * yelu_cond
    | Yor of yelu_cond * yelu_cond
    | Yis_target of T.arg
    | Yis_defined of T.arg
    | Ystrequal of T.arg * T.arg
    | Ystrless of T.arg * T.arg
    | Ystrgreater of T.arg * T.arg
    | Ystrless_equal of T.arg * T.arg
    | Ystrgreater_equal of T.arg * T.arg
    | Yequal of T.arg * T.arg
    | Yless of T.arg * T.arg
    | Ygreater of T.arg * T.arg
    | Yless_equal of T.arg * T.arg
    | Ygreater_equal of T.arg * T.arg
    | Yin_list of T.arg * T.arg
    | Ymatches of T.arg * string
    | Yexists of T.arg
    | Yis_directory of T.arg
    | Yis_absolute of T.arg
    | Ypolicy_defined of string
    | Yversion_less of T.arg * T.arg
    | Yversion_greater of T.arg * T.arg
    | Yversion_equal of T.arg * T.arg
    | Yversion_less_equal of T.arg * T.arg
    | Yversion_greater_equal of T.arg * T.arg
end

(* ============================================================
   Target operations

   target_kind, items_with_kind, target_feature, file_set,
   target_sources_item are defined inside the functor since they
   depend on T.arg.
   ============================================================ *)

module Make_target_op (T : LANG_TYPES) = struct
  type yelu_items_with_kind = {
    kind : target_kind;
    items : T.arg list;
  }

  type yelu_target_feature = {
    kind : target_kind;
    feature : string;
  }

  type yelu_file_set = {
    kind : target_kind;
    type_ : Lang_cmake.file_set_type;
    base_dirs : T.arg list;
    files : T.arg list;
  }

  type yelu_target_sources_item =
    | Ytsi_plain of yelu_items_with_kind
    | Ytsi_file_set of yelu_file_set

  type yelu_target_exp =
    | Ytgt_add_executable of {
        name : T.arg;
        exclude_from_all : bool;
        sources : T.arg list;
      }
    | Ytgt_add_library of {
        name : T.arg;
        type_ : library_type option;
        exclude_from_all : bool;
        sources : T.arg list;
      }
    | Ytgt_add_library_imported of {
        name : T.arg;
        lib_type : string option;
        global : bool;
      }
    | Ytgt_add_library_alias of { name : string; target : string }
    | Ytgt_add_executable_alias of { name : string; target : string }
    | Ytgt_include_directories of {
        target : T.arg;
        before : bool;
        system : bool;
        items : yelu_items_with_kind list;
      }
    | Ytgt_link_libraries of {
        targets : T.arg list;
        items : yelu_items_with_kind list;
      }
    | Ytgt_compile_definitions of {
        target : T.arg;
        items : yelu_items_with_kind list;
      }
    | Ytgt_compile_features of {
        target : T.arg;
        features : yelu_target_feature list;
      }
    | Ytgt_compile_options of {
        target : T.arg;
        before : bool;
        items : yelu_items_with_kind list;
      }
    | Ytgt_link_options of {
        target : T.arg;
        before : bool;
        items : yelu_items_with_kind list;
      }
    | Ytgt_link_directories of {
        target : T.arg;
        before : bool;
        items : yelu_items_with_kind list;
      }
    | Ytgt_sources of { target : T.arg; items : yelu_items_with_kind list }
    | Ytgt_sources_fs of { target : T.arg; items : yelu_target_sources_item list }
    | Ytgt_precompile_headers of {
        target : T.arg;
        items : yelu_items_with_kind list;
      }
    | Ytgt_add_custom_command of {
        outputs : T.arg list;
        commands : Lang_cmake.custom_command list;
        depends : T.arg list;
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
        depends : T.arg list;
        comment : string option;
      }
    | Ytgt_add_dependencies of { target : string; dep : string }
end

(* ============================================================
   Directory-scope operations
   ============================================================ *)

module Make_dir_op (T : LANG_TYPES) = struct
  type yelu_dir_exp =
    | Ydir_include_directories of {
        dirs : T.arg list;
        before : bool;
        system : bool;
      }
    | Ydir_add_compile_definitions of { defs : T.arg list }
    | Ydir_add_compile_options of { options : T.arg list }
    | Ydir_add_link_options of { options : T.arg list }
    | Ydir_add_definitions of { defs : T.arg list }
    | Ydir_link_directories of { before : bool; dirs : T.arg list }
    | Ydir_add_subdirectory of { source_dir : T.arg }
    | Ydir_link_libraries of { items : T.arg list }
end

(* ============================================================
   State operations (variable / cache / env / property)
   ============================================================ *)

module Make_state_op (T : LANG_TYPES) = struct
  type yelu_state_exp =
    (* plain variables *)
    | Ystate_set of {
        cvar : T.var;
        values : T.arg list;
        parent_scope : bool;
      }
    (* cache *)
    | Ystate_option of { cvar : T.var; msg : string; value : T.arg }
    | Ystate_set_cache of {
        cvar : T.var;
        values : T.arg list;
        cache_type : Lang_cmake.cache_type;
        docstring : string;
        force : bool;
      }
    | Ystate_unset_cache of { cvar : T.var }
    (* env *)
    | Ystate_set_env of { var : string; value : T.arg }
    | Ystate_unset_env of { var : string }
    (* property *)
    | Ystate_get_property of {
        var : T.var;
        target : T.arg;
        property : string;
        set : bool;
      }
    | Ystate_get_directory_property of { var : T.var; property : string }
    | Ystate_set_directory_property of {
        property : string;
        append : bool;
        values : T.arg list;
      }
    | Ystate_set_tests_properties of {
        tests : T.arg list;
        properties : (string * T.arg) list;
      }
    | Ystate_set_target_properties of {
        target : T.arg;
        properties : (string * T.arg) list;
      }
    | Ystate_set_property of {
        targets : T.arg list;
        append : bool;
        properties : (string * T.arg) list;
      }
    | Ystate_set_source_property of {
        file : T.arg;
        property : string;
        values : T.arg list;
      }
    | Ystate_set_global_property of {
        properties : (string * T.arg) list;
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
  type yelu_find_exp =
    | Yfind_library of {
        cvar : T.var;
        names : T.arg list;
        paths : T.arg list;
        hints : T.arg list;
        no_default_path : bool;
        no_cmake_environment_path : bool;
        no_system_environment_path : bool;
        required : bool;
      }
    | Yfind_path of {
        cvar : T.var;
        names : T.arg list;
        paths : T.arg list;
        hints : T.arg list;
        no_default_path : bool;
        no_cmake_environment_path : bool;
        no_system_environment_path : bool;
        required : bool;
      }
    | Yfind_program of {
        cvar : T.var;
        names : T.arg list;
        paths : T.arg list;
        hints : T.arg list;
        no_default_path : bool;
        no_cmake_environment_path : bool;
        no_system_environment_path : bool;
        required : bool;
      }
    | Yfind_file of {
        cvar : T.var;
        names : T.arg list;
        paths : T.arg list;
        hints : T.arg list;
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
  type yelu_install_exp =
    | Yinstall_targets of {
        targets : T.arg list;
        destination : T.arg;
        export : T.arg option;
      }
    | Yinstall_files of { files : T.arg list; destination : T.arg }
    | Yinstall_export of {
        file : T.arg option;
        export : T.arg;
        destination : T.arg;
        namespace : string option;
      }
    | Yinstall_export_export of { name : T.arg; file : T.arg option }
    | Yinstall_configure_package_config_file of {
        install_dest : T.arg;
        input : T.arg;
        output : T.arg;
        no_set_and_check_macro : bool;
        no_check_required_components_macro : bool;
      }
    | Yinstall_write_basic_package_version_file of {
        file : T.arg;
        version : T.arg option;
        compatibility : compatibility;
        arch_independent : bool;
      }
end

(* ============================================================
   Test operations
   ============================================================ *)

module Make_test_op (T : LANG_TYPES) = struct
  type yelu_test_exp =
    | Ytest_enable_testing
    | Ytest_add_test of { name : T.arg; command : T.arg; args : T.arg list }
end

(* ============================================================
   Try operations (try_compile / try_run)
   ============================================================ *)

module Make_try_op (T : LANG_TYPES) = struct
  type yelu_try_exp =
    | Ytry_compile of {
        result_var : T.var;
        sources : T.arg list;
        compile_definitions : T.arg list;
        link_libraries : T.arg list;
        link_options : T.arg list;
        output_variable : T.var option;
        no_cache : bool;
        c_standard : string option;
        cxx_standard : string option;
      }
    | Ytry_run of {
        run_result_var : T.var;
        compile_result_var : T.var;
        sources : T.arg list;
        compile_definitions : T.arg list;
        link_libraries : T.arg list;
        compile_output_variable : T.var option;
        run_output_variable : T.var option;
        args : T.arg list;
      }
end

(* ============================================================
   Cmake meta operations
   ============================================================ *)

module Make_cmake_op (T : LANG_TYPES) = struct
  type yelu_cmake_exp =
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
    | Ycmake_language_call of { cmd : string; args : T.arg list }
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

   This is the parametric mirror of [Lang_yelu_cmake.yelu_exp]. Constructor
   names match yelu's so that lowering is mechanical (constructor
   pattern → same-name constructor in Lang_yelu_cmake).
   ============================================================ *)

module Make_exp (T : LANG_TYPES) = struct
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

  type yelu_exp =
    | Ye_string of String_op.yelu_string_exp
    | Ye_list of List_op.yelu_list_exp
    | Ye_file of File_op.yelu_file_exp
    | Ye_target of Target_op.yelu_target_exp
    | Ye_dir of Dir_op.yelu_dir_exp
    | Ye_state of State_op.yelu_state_exp
    | Ye_find of Find_op.yelu_find_exp
    | Ye_install of Install_op.yelu_install_exp
    | Ye_test of Test_op.yelu_test_exp
    | Ye_try of Try_op.yelu_try_exp
    | Ye_cmake of Cmake_op.yelu_cmake_exp
    (* core *)
    | Ylet of { var : yelu_var; value : T.arg }
    | Yif of { cond : Cond.yelu_cond; then_ : yelu_exp; else_ : yelu_exp option }
    | Yexp_list of yelu_exp list
    (* scripting *)
    | Yc_include of { file : T.arg; optional : bool }
    | Yc_function of { name : T.arg; args : string list; body : yelu_exp list }
    | Yc_macro of { name : T.arg; args : string list; body : yelu_exp list }
    | Yc_apply of { name : T.arg; args : T.arg list }
    | Yc_execute_process of {
        commands : T.arg list list;
        working_directory : T.arg option;
        timeout : float option;
        result_variable : T.var option;
        output_variable : T.var option;
        error_variable : T.var option;
        input_file : T.arg option;
        output_file : T.arg option;
        error_file : T.arg option;
        output_quiet : bool;
        error_quiet : bool;
        output_strip_trailing_whitespace : bool;
        error_strip_trailing_whitespace : bool;
        command_error_is_fatal : string option;
      }
    | Yc_quote_cmd of string
    | Yc_at_var of string
    | Yc_include_guard of { scope : Lang_cmake.include_guard_scope }
    | Yc_separate_arguments of {
        cvar : T.var;
        mode : Lang_cmake.separate_arguments_mode;
        input : T.arg option;
      }
    | Yc_extern_cvar of T.var
    | Yc_extern_target of T.target
    | Yc_message of { mode : Lang_cmake.message_mode; texts : string list }
    (* control flow *)
    | Yc_foreach of { loop_var : T.var; items : T.arg list; commands : yelu_exp }
    | Yc_foreach_range of {
        loop_var : T.var;
        start : int option;
        stop : int;
        step : int option;
        commands : yelu_exp;
      }
    | Yc_foreach_in of {
        loop_var : T.var;
        lists : T.var list;
        items : T.arg list;
        commands : yelu_exp;
      }
    | Yc_foreach_zip of {
        loop_vars : T.var list;
        lists : T.var list;
        commands : yelu_exp;
      }
    | Yc_while of { cond : Cond.yelu_cond; commands : yelu_exp }
    | Yc_break
    | Yc_continue
    | Yc_return of { propogate_vars : string list }
    | Yc_block of {
        scope_vars : T.var list;
        propagate : string;
        body : yelu_exp list;
      }
end
