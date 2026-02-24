open Base
open Lang_yelu

(* Type erasure: yelu_ast -> cmake_ast, with scope checking *)

(* --- Environment --- *)

type env = {
  cvars : Set.M(String).t;
  targets : Set.M(String).t;
  bindings : yarg Map.M(String).t;
}

let empty_env =
  {
    cvars = Set.empty (module String);
    targets = Set.empty (module String);
    bindings = Map.empty (module String);
  }

let is_builtin_cvar s =
  String.is_prefix s ~prefix:"CMAKE_"
  || String.is_prefix s ~prefix:"PROJECT_"
  || String.is_prefix s ~prefix:"CPACK_"
  || String.is_prefix s ~prefix:"CTEST_"
  || String.is_prefix s ~prefix:"BUILD_"

let warn_undeclared_cvar env (Ycvar s) =
  if not (Set.mem env.cvars s || is_builtin_cvar s) then
    Fmt.epr "Warning: undeclared variable '%s'@." s

let warn_undeclared_target env (Ytarget s) =
  if not (Set.mem env.targets s) then
    Fmt.epr "Warning: undeclared target '%s'@." s

let declare_cvar env (Ycvar s) = { env with cvars = Set.add env.cvars s }

let declare_target env (Ytarget s) =
  { env with targets = Set.add env.targets s }

(* --- Variable resolution --- *)

let rec resolve_arg env = function
  | Yarg_var (Yvar name) ->
      (match Map.find env.bindings name with
       | Some v -> resolve_arg env v
       | None -> Fmt.epr "Warning: unbound variable '%s'@." name; Yarg_bare name)
  | other -> other

let try_declare_target env arg =
  match resolve_arg env arg with
  | Yarg_target t -> declare_target env t
  | _ -> env

let try_declare_cvar env arg =
  match resolve_arg env arg with
  | Yarg_cvar v -> declare_cvar env v
  | _ -> env

(* --- Erasure helpers --- *)

let erase_cvar (Ycvar s) = s

let rec erase_arg env = function
  | Yarg_var (Yvar name) ->
      (match Map.find env.bindings name with
       | Some v -> erase_arg env v
       | None -> Lang_cmake.Bare name)
  | Yarg_cvar (Ycvar s) -> Lang_cmake.Bare s
  | Yarg_target (Ytarget s) -> Lang_cmake.Bare s
  | Yarg_bare s -> Lang_cmake.Bare s
  | Yarg_raw s -> Lang_cmake.Quoted s
  | Yarg_bool b -> Lang_cmake.Bare (if b then "ON" else "OFF")

(* For cmake fields that expect plain string, not arg *)
let rec erase_arg_s env = function
  | Yarg_var (Yvar name) ->
      (match Map.find env.bindings name with
       | Some v -> erase_arg_s env v
       | None -> name)
  | Yarg_cvar (Ycvar s) | Yarg_target (Ytarget s) | Yarg_bare s | Yarg_raw s ->
      s
  | Yarg_bool b -> if b then "ON" else "OFF"

let string_of_kind = function
  | Interface -> "INTERFACE"
  | Public -> "PUBLIC"
  | Private -> "PRIVATE"

let string_of_library_type = function
  | Lib_static -> "STATIC"
  | Lib_shared -> "SHARED"
  | Lib_module -> "MODULE"
  | Lib_unknown -> "UNKNOWN"
  | Lib_object -> "OBJECT"
  | Lib_interface -> "INTERFACE"
  | Lib_global -> "GLOBAL"

let string_of_supported_lang = function
  | Lang_c -> "C"
  | Lang_cxx -> "CXX"
  | Lang_csharp -> "CSharp"
  | Lang_cuda -> "CUDA"
  | Lang_objc -> "OBJC"
  | Lang_objcxx -> "OBJCXX"
  | Lang_fortran -> "Fortran"
  | Lang_hipy -> "HIP"
  | Lang_ispc -> "ISPC"
  | Lang_swift -> "Swift"
  | Lang_asm -> "ASM"
  | Lang_asm_nasm -> "ASM_NASM"
  | Lang_asm_marmasm -> "ASM_MARMASM"
  | Lang_asm_masm -> "ASM_MASM"
  | Lang_asm_att -> "ASM-ATT"

let string_of_compatibility = function
  | Any_newer_version -> "AnyNewerVersion"
  | Same_major_version -> "SameMajorVersion"
  | Same_minor_version -> "SameMinorVersion"
  | Exact_version -> "ExactVersion"

let erase_items_with_kind env { kind; items } : Lang_cmake.items_with_kind =
  { kind = string_of_kind kind; items = List.map ~f:(erase_arg env) items }

let erase_target_feature ({ kind; feature } : yelu_target_feature) :
    Lang_cmake.target_feature =
  { kind = string_of_kind kind; feature }

let rec erase_cond env : yelu_cond -> string list = function
  | Ytruthy arg -> [ erase_arg_s env arg ]
  | Ynot c -> "NOT" :: erase_cond env c
  | Yand (a, b) -> erase_cond env a @ [ "AND" ] @ erase_cond env b
  | Yor (a, b) -> erase_cond env a @ [ "OR" ] @ erase_cond env b
  | Yis_target arg -> [ "TARGET"; erase_arg_s env arg ]
  | Yis_defined arg -> [ "DEFINED"; erase_arg_s env arg ]

let erase_property env (prop, value) : Lang_cmake.property =
  { prop; value = erase_arg env value }

(* --- Scope checking --- *)

let rec check_arg env = function
  | Yarg_var (Yvar name) ->
      (match Map.find env.bindings name with
       | Some v -> check_arg env v
       | None -> Fmt.epr "Warning: unbound variable '%s'@." name)
  | Yarg_cvar v -> warn_undeclared_cvar env v
  | Yarg_target t -> warn_undeclared_target env t
  | Yarg_bare _ | Yarg_raw _ | Yarg_bool _ -> ()

let rec check_cond env = function
  | Ytruthy arg -> check_arg env arg
  | Ynot c -> check_cond env c
  | Yand (a, b) ->
      check_cond env a;
      check_cond env b
  | Yor (a, b) ->
      check_cond env a;
      check_cond env b
  | Yis_target arg -> check_arg env arg
  | Yis_defined _ -> () (* DEFINED checks existence, no warning *)

let check_items_with_kind env { kind = _; items } =
  List.iter items ~f:(check_arg env)

(* --- Compile with env threading --- *)

let rec compile env : yelu_exp -> env * Lang_cmake.exp = function
  | Yc_minimum_required { min; max } ->
      (env, Cmake_cmd (Cmake_minimum_required { min; max }))
  | Yc_project { name; version; languages } ->
      let languages = List.map ~f:string_of_supported_lang languages in
      ( env,
        Project_cmd
          (Project
             {
               name;
               version;
               description = None;
               homepage_url = None;
               languages;
             }) )
  | Yc_set { cvar; values; parent_scope } ->
      List.iter values ~f:(check_arg env);
      let env = if parent_scope then env else try_declare_cvar env cvar in
      ( env,
        Set
          {
            var = erase_arg_s env cvar;
            values = List.map ~f:(erase_arg env) values;
            parent_scope;
          } )
  | Yc_add_executable { name; sources } ->
      let env = try_declare_target env name in
      ( env,
        Project_cmd
          (Add_executable
             {
               name = erase_arg_s env name;
               options = [];
               sources = List.map ~f:(erase_arg_s env) sources;
             }) )
  | Yc_add_library { name; type_; exclude_from_all; sources } ->
      let env = try_declare_target env name in
      ( env,
        Project_cmd
          (Add_library
             {
               name = erase_arg_s env name;
               type_ = Option.map ~f:string_of_library_type type_;
               exclude_from_all;
               sources = List.map ~f:(erase_arg_s env) sources;
             }) )
  | Yc_target_include_directories { target; items } ->
      check_arg env target;
      List.iter items ~f:(check_items_with_kind env);
      ( env,
        Project_cmd
          (Target_include_directories
             {
               target = erase_arg_s env target;
               system = None;
               before_or_after = None;
               items = List.map ~f:(erase_items_with_kind env) items;
             }) )
  | Yc_target_link_libraries { targets; items } ->
      List.iter targets ~f:(check_arg env);
      List.iter items ~f:(check_items_with_kind env);
      ( env,
        Project_cmd
          (Target_link_libraries
             {
               targets = List.map ~f:(erase_arg_s env) targets;
               items = List.map ~f:(erase_items_with_kind env) items;
             }) )
  | Yc_target_compile_definitions { target; items } ->
      check_arg env target;
      List.iter items ~f:(check_items_with_kind env);
      ( env,
        Project_cmd
          (Target_compile_definitions
             {
               target = erase_arg_s env target;
               items = List.map ~f:(erase_items_with_kind env) items;
             }) )
  | Yc_target_compile_features { target; features } ->
      check_arg env target;
      ( env,
        Project_cmd
          (Target_compile_features
             {
               target = erase_arg_s env target;
               features = List.map ~f:erase_target_feature features;
             }) )
  | Yc_target_compile_options { target; before; items } ->
      check_arg env target;
      List.iter items ~f:(check_items_with_kind env);
      ( env,
        Project_cmd
          (Target_compile_options
             {
               target = erase_arg_s env target;
               before;
               items = List.map ~f:(erase_items_with_kind env) items;
             }) )
  | Yc_configure_file { input; output } ->
      ( env,
        Cmake_cmd
          (Configure_file
             {
               input = erase_arg_s env input;
               output = erase_arg_s env output;
               permission_level = None;
               permissions = [];
               copy_only = None;
               escape_quotes = None;
               only = None;
               newline_style = None;
             }) )
  | Yc_add_subdirectory { source_dir } ->
      ( env,
        Project_cmd
          (Add_subdirectory
             {
               source_dir = erase_arg_s env source_dir;
               binary_dir = None;
               exclude_from_all = false;
               system = false;
             }) )
  | Yc_option { cvar; msg; value } ->
      check_arg env value;
      let env = try_declare_cvar env cvar in
      (env, Cmake_option { var = erase_arg_s env cvar; msg; value = erase_arg env value })
  | Ylet { var = Yvar name; value } ->
      check_arg env value;
      let resolved = resolve_arg env value in
      let env = { env with bindings = Map.set env.bindings ~key:name ~data:resolved } in
      (env, Exp_list [])
  | Yif { cond; then_; else_ } ->
      check_cond env cond;
      let then_env, then_cmake = compile env then_ in
      let else_env, else_cmake =
        match else_ with
        | None -> (env, None)
        | Some e ->
            let env', e' = compile env e in
            (env', Some e')
      in
      (* Union: anything declared in either branch is available after *)
      let env =
        {
          cvars = Set.union then_env.cvars else_env.cvars;
          targets = Set.union then_env.targets else_env.targets;
          bindings = env.bindings;
        }
      in
      ( env,
        If { cond = erase_cond env cond; then_ = then_cmake; else_ = else_cmake } )
  | Yexp_list exps ->
      let env, rev_cmds =
        List.fold exps ~init:(env, []) ~f:(fun (env, acc) exp ->
            let env, cmd = compile env exp in
            match cmd with
            | Exp_list [] -> (env, acc) (* drop empty nodes from externs/ylet *)
            | _ -> (env, cmd :: acc))
      in
      (env, Exp_list (List.rev rev_cmds))
  (* scripting *)
  | Yc_include { file; optional } ->
      check_arg env file;
      ( env,
        Include
          {
            file = erase_arg env file;
            optional;
            result_var = None;
            no_policy_scope = None;
          } )
  | Yc_function { name; args; body } ->
      let env = try_declare_cvar env name in
      let body_env =
        List.fold args ~init:env ~f:(fun env arg ->
            { env with cvars = Set.add env.cvars arg })
      in
      let _body_env, body_cmds = compile_list body_env body in
      (env, Function { name = erase_arg_s env name; args; cmds = body_cmds })
  | Yc_apply { name; args } ->
      check_arg env name;
      List.iter args ~f:(check_arg env);
      (env, Apply { name = erase_arg_s env name; args = List.map ~f:(erase_arg env) args })
  | Yc_quote_cmd s -> (env, Quote s)
  | Yc_list_append { cvar; values } ->
      check_arg env cvar;
      List.iter values ~f:(check_arg env);
      ( env,
        List_append
          { var = erase_arg_s env cvar; values = List.map ~f:(erase_arg env) values } )
  (* testing *)
  | Yc_enable_testing -> (env, Project_cmd Enable_testing)
  | Yc_add_test { name; command; args } ->
      ( env,
        Project_cmd
          (Add_test
             {
               name = erase_arg_s env name;
               command = erase_arg_s env command;
               args = List.map ~f:(erase_arg_s env) args;
               dir = None;
             }) )
  | Yc_set_tests_properties { tests; properties } ->
      List.iter properties ~f:(fun (_, v) -> check_arg env v);
      ( env,
        Project_cmd
          (Set_tests_properties
             {
               tests = List.map ~f:(erase_arg_s env) tests;
               dir = None;
               properties = List.map ~f:(erase_property env) properties;
             }) )
  (* target properties *)
  | Yc_set_target_properties { target; properties } ->
      check_arg env target;
      List.iter properties ~f:(fun (_, v) -> check_arg env v);
      ( env,
        Project_cmd
          (Set_target_properties
             {
               target = erase_arg_s env target;
               properties = List.map ~f:(erase_property env) properties;
             }) )
  | Yc_set_property { targets; properties } ->
      List.iter targets ~f:(check_arg env);
      List.iter properties ~f:(fun (_, v) -> check_arg env v);
      ( env,
        Set_property
          {
            global = false;
            directory = [];
            targets = List.map ~f:(erase_arg_s env) targets;
            sources = [];
            source_directories = [];
            source_target_directories = [];
            installs = [];
            tests = [];
            test_directories = [];
            caches = [];
            append = false;
            append_string = false;
            properties = List.map ~f:(erase_property env) properties;
          } )
  (* install *)
  | Yc_install_targets { targets; destination; export } ->
      List.iter targets ~f:(check_arg env);
      check_arg env destination;
      ( env,
        Project_cmd
          (Install_targets
             {
               targets = List.map ~f:(erase_arg_s env) targets;
               destination = erase_arg env destination;
               permissions = [];
               component = None;
               rename = None;
               export = Option.map ~f:(erase_arg_s env) export;
             }) )
  | Yc_install_files { files; destination } ->
      List.iter files ~f:(check_arg env);
      check_arg env destination;
      ( env,
        Project_cmd
          (Install_files
             {
               files = List.map ~f:(erase_arg env) files;
               destination = erase_arg env destination;
               permissions = [];
               component = None;
               rename = None;
             }) )
  | Yc_install_export { file; export; destination } ->
      Option.iter file ~f:(check_arg env);
      check_arg env export;
      check_arg env destination;
      ( env,
        Project_cmd
          (Install_export
             {
               file = Option.map ~f:(erase_arg env) file;
               export = erase_arg env export;
               destination = erase_arg env destination;
               permissions = [];
               component = None;
               rename = None;
             }) )
  (* export *)
  | Yc_export_export { name; file } ->
      Option.iter file ~f:(check_arg env);
      ( env,
        Project_cmd
          (Export_export
             { name = erase_arg_s env name; file = Option.map ~f:(erase_arg env) file })
      )
  (* module commands *)
  | Yc_configure_package_config_file
      {
        install_dest;
        input;
        output;
        no_set_and_check_macro;
        no_check_required_components_macro;
      } ->
      check_arg env install_dest;
      check_arg env input;
      check_arg env output;
      ( env,
        Module_cmd
          (Configure_package_config_file
             {
               input = erase_arg env input;
               output = erase_arg env output;
               install_dest = erase_arg env install_dest;
               path_vars = [];
               no_set_and_check_macro;
               no_check_required_components_macro;
             }) )
  | Yc_write_basic_package_version_file { file; version; compatibility } ->
      check_arg env file;
      Option.iter version ~f:(check_arg env);
      ( env,
        Module_cmd
          (Write_basic_package_version_file
             {
               file = erase_arg env file;
               version = Option.map ~f:(erase_arg env) version;
               compatibility = string_of_compatibility compatibility;
               arch_independent = false;
             }) )
  (* custom commands *)
  | Yc_add_custom_command { outputs; commands; depends } ->
      ( env,
        Project_cmd
          (Add_custom_command
             {
               outputs = List.map ~f:(erase_arg_s env) outputs;
               commands;
               main_dependency = None;
               depends = List.map ~f:(erase_arg_s env) depends;
               byproducts = [];
               implicit_depends = [];
               working_directory = None;
               comment = None;
               depfile = None;
               job_pool = None;
               job_server_aware = false;
               verbatim = false;
               append = false;
               uses_terminal = false;
               codegen = false;
               command_expand_list = [];
               depends_explicit_only = false;
             }) )
  (* extern declarations — register in env, emit nothing *)
  | Yc_extern_cvar v -> (declare_cvar env v, Exp_list [])
  | Yc_extern_target t -> (declare_target env t, Exp_list [])

and compile_list env exps =
  let env, rev_cmds =
    List.fold exps ~init:(env, []) ~f:(fun (env, acc) exp ->
        let env, cmd = compile env exp in
        (env, cmd :: acc))
  in
  (env, List.rev rev_cmds)

and compile_cmd env (yelu_exp : yelu_exp) : env * Lang_cmake.cmd =
  compile env yelu_exp
