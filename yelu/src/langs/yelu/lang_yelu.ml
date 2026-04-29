(** Parametric AST shapes for yelu — aggregates all theory groups.

    [LANG_TYPES] and the type universe live in [Lang_yelu_type].
    All theory groups except [Make_target_op] have been split to [fragments/],
    each paired with its S0 type checker.
    [Make_stmt] bundles all theories at a given substrate; packs instantiate
    it once with [include Lang_yelu.Make_stmt (My_types)]. *)

module type LANG_TYPES = Lang_yelu_type.LANG_TYPES

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
  include Lang_yelu_file.Make_file_io_op (T)
  include Lang_yelu_path.Make_path_op (T)
  include Lang_yelu_list.Make_list_op (T)
  include Lang_yelu_state.Make_state_op (T)
  include Lang_yelu_find.Make_find_op (T)
  include Lang_yelu_install.Make_install_op (T)
  include Lang_yelu_test.Make_test_op (T)
  include Lang_yelu_try.Make_try_op (T)
  include Lang_yelu_dir.Make_dir_op (T)
  include Lang_yelu_cmake_op.Make_cmake_op (T)
end
