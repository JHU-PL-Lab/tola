(* Yelu AST — typed surface language compiling to CMake.
   Type discipline lives here; cmake_ast stays stringly-typed. *)

(* A cmake name — string key in cmake namespaces (TARGET, Variable, COMMAND, TEST, ...) *)
type cmake_name = string

(* String content classification — what role a string plays *)
type yc_string =
  | Ycs_file of string (* file path: source, config, header, cmake module *)
  | Ycs_dir of string (* directory path: source dir, install destination *)
  | Ycs_name of
      cmake_name (* generic cmake name, not typed to a specific namespace *)
  | Ycs_val of string (* plain value: numbers, property values *)
  | Ycs_cmake of string (* cmake expression, opaque pass-through *)

(* Typed wrappers — each pins a cmake_name to a specific namespace *)
type yelu_cvar =
  | Ycvar of cmake_name (* cmake Variable namespace: set(), ${}, if(DEFINED) *)

type yelu_target =
  | Ytarget of cmake_name (* cmake Target namespace: add_library, if(TARGET) *)

type yelu_var = Yvar of string (* compile-time variable *)

(* Type aliases — placeholders for future typed variants *)
type project_name = string
type feature_name = string
type property_key = string

(* Shared structural types *)
type version = Lang_cmake.version

(* Manifest-variant aliases — bring Lang_cmake enum constructors into
   scope unqualified (Public, Private, Lib_static, …). *)
type library_type = Lang_cmake.library_type =
  | Lib_static
  | Lib_shared
  | Lib_module
  | Lib_unknown
  | Lib_object
  | Lib_interface
  | Lib_global

type target_kind = Lang_cmake.target_kind =
  | Public
  | Private
  | Interface
  | Plain

type supported_lang = Lang_cmake.supported_lang =
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

type compatibility = Lang_cmake.compatibility =
  | Any_newer_version
  | Same_major_version
  | Same_minor_version
  | Exact_version

include Lang_yelu_genex

type yelu_expr =
  | Yexpr_cvar of yelu_cvar
  | Yexpr_target of yelu_target
  | Yexpr_string of yc_string (* file, dir, name, value, or raw cmake expr *)
  | Yexpr_bool of bool
  | Yexpr_var of yelu_var (* compile-time variable reference *)

(* cmake-pack substrate for Lang_yelu functors *)
module Cmake_types = struct
  type var = yelu_cvar
  type expr = yelu_expr
  type target = yelu_target
end

(* All group statement types and constructors at top-level namespace via
   a single bundle include. yelu_json_op + Yjop_* also surface here
   because Make_string_op includes Make_json_op. *)
include Lang_yelu.Make_stmt (Cmake_types)

(* ============================================================
   Top-level statement — cmake-pack-specific.

   Group statements come from the per-group includes above (yelu_*_stmt
   types are at top level). The cmake-specific scripting and control
   flow (include / function / macro / apply / foreach / message / ...)
   live here directly — these are part of the cmake-pack vocabulary,
   not the parametric core. A future pack (json/nix/...) would compose
   its own yelu_stmt with its own scripting constructors.
   ============================================================ *)

type yelu_stmt =
  | Ys_string of yelu_string_stmt
  | Ys_list of yelu_list_stmt
  | Ys_file of yelu_file_stmt
  | Ys_target of yelu_target_stmt
  | Ys_dir of yelu_dir_stmt
  | Ys_state of yelu_state_stmt
  | Ys_find of yelu_find_stmt
  | Ys_install of yelu_install_stmt
  | Ys_test of yelu_test_stmt
  | Ys_try of yelu_try_stmt
  | Ys_cmake of yelu_cmake_stmt
  (* core *)
  | Ylet of { var : yelu_var; value : yelu_expr }
  | Yif of { cond : yelu_cond; then_ : yelu_stmt; else_ : yelu_stmt option }
  | Ystmt_list of yelu_stmt list
  (* cmake-specific scripting *)
  | Yc_include of { file : yelu_expr; optional : bool }
  | Yc_function of {
      name : yelu_expr;
      args : string list;
      body : yelu_stmt list;
    }
  | Yc_macro of { name : yelu_expr; args : string list; body : yelu_stmt list }
  | Yc_apply of { name : yelu_expr; args : yelu_expr list }
  | Yc_separate_arguments of {
      cvar : yelu_cvar;
      mode : Lang_cmake.separate_arguments_mode;
      input : yelu_expr option;
    }
  | Yc_extern_cvar of yelu_cvar
  | Yc_extern_target of yelu_target
  (* cmake-specific control flow *)
  | Yc_foreach of {
      loop_var : yelu_cvar;
      items : yelu_expr list;
      commands : yelu_stmt;
    }
  | Yc_foreach_range of {
      loop_var : yelu_cvar;
      start : int option;
      stop : int;
      step : int option;
      commands : yelu_stmt;
    }
  | Yc_foreach_in of {
      loop_var : yelu_cvar;
      lists : yelu_cvar list;
      items : yelu_expr list;
      commands : yelu_stmt;
    }
  | Yc_foreach_zip of {
      loop_vars : yelu_cvar list;
      lists : yelu_cvar list;
      commands : yelu_stmt;
    }
  | Yc_while of { cond : yelu_cond; commands : yelu_stmt }
  | Yc_break
  | Yc_continue
  | Yc_return of { propogate_vars : string list }
  | Yc_block of {
      scope_vars : yelu_cvar list;
      propagate : string;
      body : yelu_stmt list;
    }

(* ============================================================
   Cmake-pack type checker
   ============================================================ *)

module Cmake_check = struct
  open Base
  open Lang_yelu_type

  module Cond_check = Lang_yelu_cond.Make_cond_check (Cmake_types)
  module Str_check = Lang_yelu_string.Make_string_check (Cmake_types)
  module Dir_check = Lang_yelu_dir.Make_dir_check (Cmake_types)
  module Install_check = Lang_yelu_install.Make_install_check (Cmake_types)
  module Test_check = Lang_yelu_test.Make_test_check (Cmake_types)
  module Try_check = Lang_yelu_try.Make_try_check (Cmake_types)

  type env = yelu_type Map.M(String).t

  let empty_env = Map.empty (module String)

  let type_of (env : env) = function
    | Yexpr_bool _ -> Ty_bool
    | Yexpr_string (Ycs_file _ | Ycs_dir _) -> Ty_path
    | Yexpr_string _ -> Ty_string
    | Yexpr_target _ -> Ty_target
    | Yexpr_cvar (Ycvar name) | Yexpr_var (Yvar name) ->
      Map.find env name |> Option.value ~default:Ty_any

  let bind env name ty = Map.set env ~key:name ~data:ty

  let rec check_stmt (env : env) : yelu_stmt -> env * type_error list = function
    | Ylet { var = Yvar name; value } ->
      (bind env name (type_of env value), [])
    | Ys_string s ->
      let (errs, outputs) = Str_check.check ~type_of:(type_of env) s in
      let env' = List.fold outputs ~init:env
        ~f:(fun e (Ycvar n, ty) -> bind e n ty) in
      (env', errs)
    | Ys_dir s -> (env, Dir_check.check ~type_of:(type_of env) s)
    | Ys_install s -> (env, Install_check.check ~type_of:(type_of env) s)
    | Ys_test s -> (env, Test_check.check ~type_of:(type_of env) s)
    | Ys_try s ->
      let (errs, outputs) = Try_check.check ~type_of:(type_of env) s in
      let env' = List.fold outputs ~init:env
        ~f:(fun e (Ycvar n, ty) -> bind e n ty) in
      (env', errs)
    | Yif { cond; then_; else_ } ->
      let cond_errs = Cond_check.check ~type_of:(type_of env) cond in
      let (env1, then_errs) = check_stmt env then_ in
      let (_, else_errs) = Option.value_map else_
        ~default:(env, []) ~f:(check_stmt env) in
      (env1, cond_errs @ then_errs @ else_errs)
    | Ystmt_list stmts -> check_stmts env stmts
    | _ -> (env, [])

  and check_stmts env stmts =
    List.fold stmts ~init:(env, []) ~f:(fun (e, errs) s ->
      let (e', new_errs) = check_stmt e s in
      (e', errs @ new_errs))
end
