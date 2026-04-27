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
type yelu_var = Lang_yelu.yelu_var = Yvar of string    (* compile-time variable *)

(* Type aliases — placeholders for future typed variants *)
type project_name = string
type feature_name = string
type property_key = string

(* Shared structural types *)
type version = Lang_cmake.version

(* Typed enums — defined in Lang_yelu (the parametric base) and
   re-exported here as manifest-variant aliases so existing code using
   bare constructor names (Public, Private, Lib_static, ...) continues
   to work. *)
type library_type = Lang_yelu.library_type =
  | Lib_static
  | Lib_shared
  | Lib_module
  | Lib_unknown
  | Lib_object
  | Lib_interface
  | Lib_global

type target_kind = Lang_yelu.target_kind =
  | Public | Private | Interface | Plain

type supported_lang = Lang_yelu.supported_lang =
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

type compatibility = Lang_yelu.compatibility =
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
type yelu_expr =
  | Yexpr_cvar of yelu_cvar
  | Yexpr_target of yelu_target
  | Yexpr_string of yc_string  (* file, dir, name, value, or raw cmake expr *)
  | Yexpr_bool of bool
  | Yexpr_var of yelu_var  (* compile-time variable reference *)

(* cmake-pack substrate for Lang_yelu functors *)
module Cmake_types = struct
  type var = yelu_cvar
  type expr = yelu_expr
  type target = yelu_target
end


(* ============================================================
   Group ASTs imported from Lang_yelu via include.

   Each Make_<group> functor outputs a structure containing a
   yelu_<group>_exp type (and any auxiliary types). Including the
   functor result here brings those types and constructors into
   Lang_yelu_cmake's top-level namespace, exactly as if defined locally.

   yelu_<group>_exp values are pattern-matchable with bare
   constructor names (e.g. Ystr_concat) — module-prefix free.

   Sub-modules introduced as a side-effect (e.g. Make_string_op
   nests Json = Make_json_op (T)) are accessible at top-level
   (e.g. Lang_yelu_cmake.Json).
   ============================================================ *)

(* Cond first — referenced by Yif/Yc_while via Make_stmt *)
include Lang_yelu.Make_cond (Cmake_types)

(* Target — also brings yelu_items_with_kind, yelu_target_feature,
   yelu_file_set, yelu_target_sources_item *)
include Lang_yelu.Make_target_op (Cmake_types)

include Lang_yelu.Make_file_op (Cmake_types)
include Lang_yelu.Make_string_op (Cmake_types)  (* + Json sub-module *)
include Lang_yelu.Make_list_op (Cmake_types)
include Lang_yelu.Make_state_op (Cmake_types)
include Lang_yelu.Make_find_op (Cmake_types)
include Lang_yelu.Make_install_op (Cmake_types)
include Lang_yelu.Make_test_op (Cmake_types)
include Lang_yelu.Make_try_op (Cmake_types)
include Lang_yelu.Make_dir_op (Cmake_types)
include Lang_yelu.Make_cmake_op (Cmake_types)

(* Hoist Json sub-module's yelu_json_op + Yjop_* constructors to top level *)
include Json

(* Top-level expression — brings yelu_stmt + Cond/String_op/etc.
   sub-modules (same applicative results as the includes above). *)
include Lang_yelu.Make_stmt (Cmake_types)
