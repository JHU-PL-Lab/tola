(* Yelu AST — typed surface language compiling to CMake.
   Type discipline lives here; cmake_ast stays stringly-typed. *)

(* Typed wrappers — the whole point of yelu *)
type yelu_cvar = Ycvar of string  (* cmake runtime variable *)
type yelu_target = Ytarget of string

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

type target_kind = Public | Private | Interface

type supported_lang =
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
  | Yarg_bare of string
  | Yarg_raw of string
  | Yarg_bool of bool

type yelu_items_with_kind = { kind : target_kind; items : yarg list }
type yelu_target_feature = { kind : target_kind; feature : feature_name }

type yelu_cond =
  | Ycond_cvar of yelu_cvar
  | Ynot of yelu_cond
  | Yand of yelu_cond * yelu_cond
  | Yor of yelu_cond * yelu_cond
  | Yis_target of yelu_target
  | Yis_defined of yelu_cvar

type yelu_exp =
  | Ycmake_minimum_required of { min : version; max : version option }
  | Yproject of {
      name : project_name;
      version : version option;
      languages : supported_lang list;
    }
  | Yset of { cvar : yelu_cvar; values : yarg list; parent_scope : bool }
  | Yadd_executable of { name : yelu_target; sources : yarg list }
  | Yadd_library of {
      name : yelu_target;
      type_ : library_type option;
      exclude_from_all : bool;
      sources : yarg list;
    }
  | Ytarget_include_directories of {
      target : yelu_target;
      items : yelu_items_with_kind list;
    }
  | Ytarget_link_libraries of {
      targets : yelu_target list;
      items : yelu_items_with_kind list;
    }
  | Ytarget_compile_definitions of {
      target : yelu_target;
      items : yelu_items_with_kind list;
    }
  | Ytarget_compile_features of {
      target : yelu_target;
      features : yelu_target_feature list;
    }
  | Ytarget_compile_options of {
      target : yelu_target;
      before : bool;
      items : yelu_items_with_kind list;
    }
  | Yconfigure_file of { input : yarg; output : yarg }
  | Yadd_subdirectory of { source_dir : yarg }
  | Yoption of { cvar : yelu_cvar; msg : string; value : yarg }
  | Yif of { cond : yelu_cond; then_ : yelu_exp; else_ : yelu_exp option }
  | Yexp_list of yelu_exp list
  (* scripting *)
  | Yinclude of { file : yarg; optional : bool }
  | Yfunction of { name : yelu_cvar; args : string list; body : yelu_exp list }
  | Yapply of { name : yelu_cvar; args : yarg list }
  | Yquote_cmd of string
  | Ylist_append of { cvar : yelu_cvar; values : yarg list }
  (* testing *)
  | Yenable_testing
  | Yadd_test of { name : yarg; command : yarg; args : yarg list }
  | Yset_tests_properties of {
      tests : yarg list;
      properties : (property_key * yarg) list;
    }
  (* target properties *)
  | Yset_target_properties of {
      target : yelu_target;
      properties : (property_key * yarg) list;
    }
  | Yset_property of {
      targets : yelu_target list;
      properties : (property_key * yarg) list;
    }
  (* install *)
  | Yinstall_targets of {
      targets : yelu_target list;
      destination : yarg;
      export : yarg option;
    }
  | Yinstall_files of { files : yarg list; destination : yarg }
  | Yinstall_export of {
      file : yarg option;
      export : yarg;
      destination : yarg;
    }
  (* export *)
  | Yexport_export of { name : yarg; file : yarg option }
  (* module commands *)
  | Yconfigure_package_config_file of {
      install_dest : yarg;
      input : yarg;
      output : yarg;
      no_set_and_check_macro : bool;
      no_check_required_components_macro : bool;
    }
  | Ywrite_basic_package_version_file of {
      file : yarg;
      version : yarg option;
      compatibility : compatibility;
    }
  (* custom commands *)
  | Yadd_custom_command of {
      outputs : yarg list;
      commands : Lang_cmake.custom_command list;
      depends : yarg list;
    }
  (* extern declarations — register in env without emitting cmake *)
  | Yextern_cvar of yelu_cvar
  | Yextern_target of yelu_target
