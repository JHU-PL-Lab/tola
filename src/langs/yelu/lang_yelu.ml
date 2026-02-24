(* Yelu AST — typed surface language compiling to CMake.
   Type discipline lives here; cmake_ast stays stringly-typed. *)

(* Typed wrappers — the whole point of yelu *)
type yelu_var = Yvar of string
type yelu_target = Ytarget of string

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

type yelu_value =
  | Yval_var of yelu_var
  | Yval_str of string
  | Yval_bool of bool

type yelu_item = Yitem_var of yelu_var | Yitem_str of string
type yelu_items_with_kind = { kind : target_kind; items : yelu_item list }
type yelu_target_feature = { kind : target_kind; feature : string }

type yelu_cond =
  | Ycond_var of yelu_var
  | Ynot of yelu_cond
  | Yand of yelu_cond * yelu_cond
  | Yor of yelu_cond * yelu_cond
  | Yis_target of yelu_target
  | Yis_defined of yelu_var

type yelu_exp =
  | Ycmake_minimum_required of { min : version; max : version option }
  | Yproject of {
      name : string;
      version : version option;
      languages : supported_lang list;
    }
  | Yset of { var : yelu_var; values : yelu_value list; parent_scope : bool }
  | Yadd_executable of { name : yelu_target; sources : string list }
  | Yadd_library of {
      name : yelu_target;
      type_ : library_type option;
      exclude_from_all : bool;
      sources : string list;
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
  | Yconfigure_file of { input : string; output : string }
  | Yadd_subdirectory of { source_dir : string }
  | Yoption of { var : yelu_var; msg : string; value : yelu_value }
  | Yif of { cond : yelu_cond; then_ : yelu_exp; else_ : yelu_exp option }
  | Yexp_list of yelu_exp list
  (* scripting *)
  | Yinclude of { file : yelu_item; optional : bool }
  | Yfunction of { name : yelu_var; args : string list; body : yelu_exp list }
  | Yapply of { name : yelu_var; args : yelu_value list }
  | Yquote_cmd of string
  | Ylist_append of { var : yelu_var; values : yelu_value list }
  (* testing *)
  | Yenable_testing
  | Yadd_test of { name : string; command : string; args : string list }
  | Yset_tests_properties of {
      tests : string list;
      properties : (string * yelu_value) list;
    }
  (* target properties *)
  | Yset_target_properties of {
      target : yelu_target;
      properties : (string * yelu_value) list;
    }
  | Yset_property of {
      targets : yelu_target list;
      properties : (string * yelu_value) list;
    }
  (* install *)
  | Yinstall_targets of {
      targets : yelu_target list;
      destination : yelu_item;
      export : string option;
    }
  | Yinstall_files of { files : yelu_item list; destination : yelu_item }
  | Yinstall_export of {
      file : yelu_item option;
      export : yelu_item;
      destination : yelu_item;
    }
  (* export *)
  | Yexport_export of { name : string; file : yelu_item option }
  (* module commands *)
  | Yconfigure_package_config_file of {
      install_dest : yelu_item;
      input : yelu_item;
      output : yelu_item;
      no_set_and_check_macro : bool;
      no_check_required_components_macro : bool;
    }
  | Ywrite_basic_package_version_file of {
      file : yelu_item;
      version : yelu_item option;
      compatibility : compatibility;
    }
  (* custom commands *)
  | Yadd_custom_command of {
      outputs : string list;
      commands : Lang_cmake.custom_command list;
      depends : string list;
    }
