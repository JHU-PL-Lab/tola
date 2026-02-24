open Base
open Lang_yelu

(* Type erasure: yelu_ast -> cmake_ast, with scope checking *)

(* --- Environment --- *)

type env = { vars : Set.M(String).t; targets : Set.M(String).t }

let empty_env =
  { vars = Set.empty (module String); targets = Set.empty (module String) }

let is_builtin_var s =
  String.is_prefix s ~prefix:"CMAKE_"
  || String.is_prefix s ~prefix:"PROJECT_"
  || String.is_prefix s ~prefix:"CPACK_"
  || String.is_prefix s ~prefix:"CTEST_"
  || String.is_prefix s ~prefix:"BUILD_"

let warn_undeclared_var env (Yvar s) =
  if not (Set.mem env.vars s || is_builtin_var s) then
    Fmt.epr "Warning: undeclared variable '%s'@." s

let warn_undeclared_target env (Ytarget s) =
  if not (Set.mem env.targets s) then
    Fmt.epr "Warning: undeclared target '%s'@." s

let declare_var env (Yvar s) = { env with vars = Set.add env.vars s }

let declare_target env (Ytarget s) =
  { env with targets = Set.add env.targets s }

(* --- Erasure helpers --- *)

let erase_var (Yvar s) = s
let erase_target (Ytarget s) = s

let erase_arg = function
  | Yarg_var (Yvar s) -> Lang_cmake.Bare s
  | Yarg_target (Ytarget s) -> Lang_cmake.Bare s
  | Yarg_bare s -> Lang_cmake.Bare s
  | Yarg_raw s -> Lang_cmake.Quoted s
  | Yarg_bool b -> Lang_cmake.Bare (if b then "ON" else "OFF")

(* For cmake fields that expect plain string, not arg *)
let erase_arg_s = function
  | Yarg_var (Yvar s) | Yarg_target (Ytarget s) | Yarg_bare s | Yarg_raw s ->
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

let erase_items_with_kind { kind; items } : Lang_cmake.items_with_kind =
  { kind = string_of_kind kind; items = List.map ~f:erase_arg items }

let erase_target_feature ({ kind; feature } : yelu_target_feature) :
    Lang_cmake.target_feature =
  { kind = string_of_kind kind; feature }

let rec erase_cond : yelu_cond -> string list = function
  | Ycond_var (Yvar s) -> [ s ]
  | Ynot c -> "NOT" :: erase_cond c
  | Yand (a, b) -> erase_cond a @ [ "AND" ] @ erase_cond b
  | Yor (a, b) -> erase_cond a @ [ "OR" ] @ erase_cond b
  | Yis_target (Ytarget s) -> [ "TARGET"; s ]
  | Yis_defined (Yvar s) -> [ "DEFINED"; s ]

let erase_property (prop, value) : Lang_cmake.property =
  { prop; value = erase_arg value }

(* --- Scope checking --- *)

let rec check_cond env = function
  | Ycond_var v -> warn_undeclared_var env v
  | Ynot c -> check_cond env c
  | Yand (a, b) ->
      check_cond env a;
      check_cond env b
  | Yor (a, b) ->
      check_cond env a;
      check_cond env b
  | Yis_target t -> warn_undeclared_target env t
  | Yis_defined _ -> () (* DEFINED checks existence, no warning *)

let check_arg env = function
  | Yarg_var v -> warn_undeclared_var env v
  | Yarg_target t -> warn_undeclared_target env t
  | Yarg_bare _ | Yarg_raw _ | Yarg_bool _ -> ()

let check_items_with_kind env { kind = _; items } =
  List.iter items ~f:(check_arg env)

(* --- Compile with env threading --- *)

let rec compile env : yelu_exp -> env * Lang_cmake.exp = function
  | Ycmake_minimum_required { min; max } ->
      (env, Cmake_cmd (Cmake_minimum_required { min; max }))
  | Yproject { name; version; languages } ->
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
  | Yset { var; values; parent_scope } ->
      List.iter values ~f:(check_arg env);
      let env = if parent_scope then env else declare_var env var in
      ( env,
        Set
          {
            var = erase_var var;
            values = List.map ~f:erase_arg values;
            parent_scope;
          } )
  | Yadd_executable { name; sources } ->
      let env = declare_target env name in
      ( env,
        Project_cmd
          (Add_executable
             {
               name = erase_target name;
               options = [];
               sources = List.map ~f:erase_arg_s sources;
             }) )
  | Yadd_library { name; type_; exclude_from_all; sources } ->
      let env = declare_target env name in
      ( env,
        Project_cmd
          (Add_library
             {
               name = erase_target name;
               type_ = Option.map ~f:string_of_library_type type_;
               exclude_from_all;
               sources = List.map ~f:erase_arg_s sources;
             }) )
  | Ytarget_include_directories { target; items } ->
      warn_undeclared_target env target;
      List.iter items ~f:(check_items_with_kind env);
      ( env,
        Project_cmd
          (Target_include_directories
             {
               target = erase_target target;
               system = None;
               before_or_after = None;
               items = List.map ~f:erase_items_with_kind items;
             }) )
  | Ytarget_link_libraries { targets; items } ->
      List.iter targets ~f:(warn_undeclared_target env);
      List.iter items ~f:(check_items_with_kind env);
      ( env,
        Project_cmd
          (Target_link_libraries
             {
               targets = List.map ~f:erase_target targets;
               items = List.map ~f:erase_items_with_kind items;
             }) )
  | Ytarget_compile_definitions { target; items } ->
      warn_undeclared_target env target;
      List.iter items ~f:(check_items_with_kind env);
      ( env,
        Project_cmd
          (Target_compile_definitions
             {
               target = erase_target target;
               items = List.map ~f:erase_items_with_kind items;
             }) )
  | Ytarget_compile_features { target; features } ->
      warn_undeclared_target env target;
      ( env,
        Project_cmd
          (Target_compile_features
             {
               target = erase_target target;
               features = List.map ~f:erase_target_feature features;
             }) )
  | Ytarget_compile_options { target; before; items } ->
      warn_undeclared_target env target;
      List.iter items ~f:(check_items_with_kind env);
      ( env,
        Project_cmd
          (Target_compile_options
             {
               target = erase_target target;
               before;
               items = List.map ~f:erase_items_with_kind items;
             }) )
  | Yconfigure_file { input; output } ->
      ( env,
        Cmake_cmd
          (Configure_file
             {
               input = erase_arg_s input;
               output = erase_arg_s output;
               permission_level = None;
               permissions = [];
               copy_only = None;
               escape_quotes = None;
               only = None;
               newline_style = None;
             }) )
  | Yadd_subdirectory { source_dir } ->
      ( env,
        Project_cmd
          (Add_subdirectory
             {
               source_dir = erase_arg_s source_dir;
               binary_dir = None;
               exclude_from_all = false;
               system = false;
             }) )
  | Yoption { var; msg; value } ->
      check_arg env value;
      let env = declare_var env var in
      (env, Cmake_option { var = erase_var var; msg; value = erase_arg value })
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
          vars = Set.union then_env.vars else_env.vars;
          targets = Set.union then_env.targets else_env.targets;
        }
      in
      ( env,
        If { cond = erase_cond cond; then_ = then_cmake; else_ = else_cmake } )
  | Yexp_list exps ->
      let env, rev_cmds =
        List.fold exps ~init:(env, []) ~f:(fun (env, acc) exp ->
            let env, cmd = compile env exp in
            match cmd with
            | Exp_list [] -> (env, acc) (* drop empty nodes from externs *)
            | _ -> (env, cmd :: acc))
      in
      (env, Exp_list (List.rev rev_cmds))
  (* scripting *)
  | Yinclude { file; optional } ->
      check_arg env file;
      ( env,
        Include
          {
            file = erase_arg file;
            optional;
            result_var = None;
            no_policy_scope = None;
          } )
  | Yfunction { name; args; body } ->
      let env = declare_var env name in
      let body_env =
        List.fold args ~init:env ~f:(fun env arg ->
            { env with vars = Set.add env.vars arg })
      in
      let _body_env, body_cmds = compile_list body_env body in
      (env, Function { name = erase_var name; args; cmds = body_cmds })
  | Yapply { name; args } ->
      warn_undeclared_var env name;
      List.iter args ~f:(check_arg env);
      (env, Apply { name = erase_var name; args = List.map ~f:erase_arg args })
  | Yquote_cmd s -> (env, Quote s)
  | Ylist_append { var; values } ->
      warn_undeclared_var env var;
      List.iter values ~f:(check_arg env);
      ( env,
        List_append
          { var = erase_var var; values = List.map ~f:erase_arg values } )
  (* testing *)
  | Yenable_testing -> (env, Project_cmd Enable_testing)
  | Yadd_test { name; command; args } ->
      ( env,
        Project_cmd
          (Add_test
             {
               name = erase_arg_s name;
               command = erase_arg_s command;
               args = List.map ~f:erase_arg_s args;
               dir = None;
             }) )
  | Yset_tests_properties { tests; properties } ->
      List.iter properties ~f:(fun (_, v) -> check_arg env v);
      ( env,
        Project_cmd
          (Set_tests_properties
             {
               tests = List.map ~f:erase_arg_s tests;
               dir = None;
               properties = List.map ~f:erase_property properties;
             }) )
  (* target properties *)
  | Yset_target_properties { target; properties } ->
      warn_undeclared_target env target;
      List.iter properties ~f:(fun (_, v) -> check_arg env v);
      ( env,
        Project_cmd
          (Set_target_properties
             {
               target = erase_target target;
               properties = List.map ~f:erase_property properties;
             }) )
  | Yset_property { targets; properties } ->
      List.iter targets ~f:(warn_undeclared_target env);
      List.iter properties ~f:(fun (_, v) -> check_arg env v);
      ( env,
        Set_property
          {
            global = false;
            directory = [];
            targets = List.map ~f:erase_target targets;
            sources = [];
            source_directories = [];
            source_target_directories = [];
            installs = [];
            tests = [];
            test_directories = [];
            caches = [];
            append = false;
            append_string = false;
            properties = List.map ~f:erase_property properties;
          } )
  (* install *)
  | Yinstall_targets { targets; destination; export } ->
      List.iter targets ~f:(warn_undeclared_target env);
      check_arg env destination;
      ( env,
        Project_cmd
          (Install_targets
             {
               targets = List.map ~f:erase_target targets;
               destination = erase_arg destination;
               permissions = [];
               component = None;
               rename = None;
               export = Option.map ~f:erase_arg_s export;
             }) )
  | Yinstall_files { files; destination } ->
      List.iter files ~f:(check_arg env);
      check_arg env destination;
      ( env,
        Project_cmd
          (Install_files
             {
               files = List.map ~f:erase_arg files;
               destination = erase_arg destination;
               permissions = [];
               component = None;
               rename = None;
             }) )
  | Yinstall_export { file; export; destination } ->
      Option.iter file ~f:(check_arg env);
      check_arg env export;
      check_arg env destination;
      ( env,
        Project_cmd
          (Install_export
             {
               file = Option.map ~f:erase_arg file;
               export = erase_arg export;
               destination = erase_arg destination;
               permissions = [];
               component = None;
               rename = None;
             }) )
  (* export *)
  | Yexport_export { name; file } ->
      Option.iter file ~f:(check_arg env);
      ( env,
        Project_cmd
          (Export_export { name = erase_arg_s name; file = Option.map ~f:erase_arg file }) )
  (* module commands *)
  | Yconfigure_package_config_file
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
               input = erase_arg input;
               output = erase_arg output;
               install_dest = erase_arg install_dest;
               path_vars = [];
               no_set_and_check_macro;
               no_check_required_components_macro;
             }) )
  | Ywrite_basic_package_version_file { file; version; compatibility } ->
      check_arg env file;
      Option.iter version ~f:(check_arg env);
      ( env,
        Module_cmd
          (Write_basic_package_version_file
             {
               file = erase_arg file;
               version = Option.map ~f:erase_arg version;
               compatibility = string_of_compatibility compatibility;
               arch_independent = false;
             }) )
  (* custom commands *)
  | Yadd_custom_command { outputs; commands; depends } ->
      ( env,
        Project_cmd
          (Add_custom_command
             {
               outputs = List.map ~f:erase_arg_s outputs;
               commands;
               main_dependency = None;
               depends = List.map ~f:erase_arg_s depends;
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
  | Yextern_var v -> (declare_var env v, Exp_list [])
  | Yextern_target t -> (declare_target env t, Exp_list [])

and compile_list env exps =
  let env, rev_cmds =
    List.fold exps ~init:(env, []) ~f:(fun (env, acc) exp ->
        let env, cmd = compile env exp in
        (env, cmd :: acc))
  in
  (env, List.rev rev_cmds)

and compile_cmd env (yelu_exp : yelu_exp) : env * Lang_cmake.cmd =
  compile env yelu_exp
