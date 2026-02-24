open Base
open Lang_yelu

(* Type erasure: yelu_ast -> cmake_ast *)

let erase_var (Yvar s) = s
let erase_target (Ytarget s) = s

let erase_value = function
  | Yval_var (Yvar s) -> Lang_cmake.Bare s
  | Yval_str s -> Lang_cmake.Quoted s
  | Yval_bool b -> Lang_cmake.Bare (if b then "ON" else "OFF")

let erase_item = function
  | Yitem_var (Yvar s) -> Lang_cmake.Bare s
  | Yitem_str s -> Lang_cmake.Quoted s

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
  { kind = string_of_kind kind; items = List.map ~f:erase_item items }

let erase_target_feature ({ kind; feature } : yelu_target_feature)
    : Lang_cmake.target_feature =
  { kind = string_of_kind kind; feature }

let rec erase_cond : yelu_cond -> string list = function
  | Ycond_var (Yvar s) -> [ s ]
  | Ynot c -> "NOT" :: erase_cond c
  | Yand (a, b) -> erase_cond a @ [ "AND" ] @ erase_cond b
  | Yor (a, b) -> erase_cond a @ [ "OR" ] @ erase_cond b
  | Yis_target (Ytarget s) -> [ "TARGET"; s ]
  | Yis_defined (Yvar s) -> [ "DEFINED"; s ]

let erase_property (prop, value) : Lang_cmake.property =
  { prop; value = erase_value value }

let rec compile : yelu_exp -> Lang_cmake.exp = function
  | Ycmake_minimum_required { min; max } ->
      Cmake_cmd (Cmake_minimum_required { min; max })
  | Yproject { name; version; languages } ->
      let languages = List.map ~f:string_of_supported_lang languages in
      Project_cmd
        (Project
           { name; version; description = None; homepage_url = None; languages })
  | Yset { var; values; parent_scope } ->
      Set
        {
          var = erase_var var;
          values = List.map ~f:erase_value values;
          parent_scope;
        }
  | Yadd_executable { name; sources } ->
      Project_cmd
        (Add_executable { name = erase_target name; options = []; sources })
  | Yadd_library { name; type_; exclude_from_all; sources } ->
      Project_cmd
        (Add_library
           {
             name = erase_target name;
             type_ = Option.map ~f:string_of_library_type type_;
             exclude_from_all;
             sources;
           })
  | Ytarget_include_directories { target; items } ->
      Project_cmd
        (Target_include_directories
           {
             target = erase_target target;
             system = None;
             before_or_after = None;
             items = List.map ~f:erase_items_with_kind items;
           })
  | Ytarget_link_libraries { targets; items } ->
      Project_cmd
        (Target_link_libraries
           {
             targets =
               List.map
                 ~f:(fun t -> erase_target t)
                 targets;
             items = List.map ~f:erase_items_with_kind items;
           })
  | Ytarget_compile_definitions { target; items } ->
      Project_cmd
        (Target_compile_definitions
           {
             target = erase_target target;
             items = List.map ~f:erase_items_with_kind items;
           })
  | Ytarget_compile_features { target; features } ->
      Project_cmd
        (Target_compile_features
           {
             target = erase_target target;
             features = List.map ~f:erase_target_feature features;
           })
  | Ytarget_compile_options { target; before; items } ->
      Project_cmd
        (Target_compile_options
           {
             target = erase_target target;
             before;
             items = List.map ~f:erase_items_with_kind items;
           })
  | Yconfigure_file { input; output } ->
      Cmake_cmd
        (Configure_file
           {
             input;
             output;
             permission_level = None;
             permissions = [];
             copy_only = None;
             escape_quotes = None;
             only = None;
             newline_style = None;
           })
  | Yadd_subdirectory { source_dir } ->
      Project_cmd
        (Add_subdirectory
           {
             source_dir;
             binary_dir = None;
             exclude_from_all = false;
             system = false;
           })
  | Yoption { var; msg; value } ->
      Cmake_option { var = erase_var var; msg; value = erase_value value }
  | Yif { cond; then_; else_ } ->
      If
        {
          cond = erase_cond cond;
          then_ = compile then_;
          else_ = Option.map ~f:compile else_;
        }
  | Yexp_list exps -> Exp_list (List.map ~f:compile exps)
  (* scripting *)
  | Yinclude { file; optional } ->
      Include
        { file = erase_item file; optional; result_var = None; no_policy_scope = None }
  | Yfunction { name; args; body } ->
      Function
        { name = erase_var name; args; cmds = List.map ~f:compile_cmd body }
  | Yapply { name; args } ->
      Apply { name = erase_var name; args = List.map ~f:erase_value args }
  | Yquote_cmd s -> Quote s
  | Ylist_append { var; values } ->
      List_append { var = erase_var var; values = List.map ~f:erase_value values }
  (* testing *)
  | Yenable_testing -> Project_cmd Enable_testing
  | Yadd_test { name; command; args } ->
      Project_cmd (Add_test { name; command; args; dir = None })
  | Yset_tests_properties { tests; properties } ->
      Project_cmd
        (Set_tests_properties
           {
             tests;
             dir = None;
             properties = List.map ~f:erase_property properties;
           })
  (* target properties *)
  | Yset_target_properties { target; properties } ->
      Project_cmd
        (Set_target_properties
           {
             target = erase_target target;
             properties = List.map ~f:erase_property properties;
           })
  | Yset_property { targets; properties } ->
      Set_property
        {
          global = false;
          directory = [];
          targets =
            List.map ~f:(fun t -> erase_target t) targets;
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
        }
  (* install *)
  | Yinstall_targets { targets; destination; export } ->
      Project_cmd
        (Install_targets
           {
             targets =
               List.map
                 ~f:(fun t -> erase_target t)
                 targets;
             destination = erase_item destination;
             permissions = [];
             component = None;
             rename = None;
             export;
           })
  | Yinstall_files { files; destination } ->
      Project_cmd
        (Install_files
           {
             files = List.map ~f:erase_item files;
             destination = erase_item destination;
             permissions = [];
             component = None;
             rename = None;
           })
  | Yinstall_export { file; export; destination } ->
      Project_cmd
        (Install_export
           {
             file = Option.map ~f:erase_item file;
             export = erase_item export;
             destination = erase_item destination;
             permissions = [];
             component = None;
             rename = None;
           })
  (* export *)
  | Yexport_export { name; file } ->
      Project_cmd
        (Export_export { name; file = Option.map ~f:erase_item file })
  (* module commands *)
  | Yconfigure_package_config_file
      { install_dest; input; output; no_set_and_check_macro;
        no_check_required_components_macro } ->
      Module_cmd
        (Configure_package_config_file
           {
             input = erase_item input;
             output = erase_item output;
             install_dest = erase_item install_dest;
             path_vars = [];
             no_set_and_check_macro;
             no_check_required_components_macro;
           })
  | Ywrite_basic_package_version_file { file; version; compatibility } ->
      Module_cmd
        (Write_basic_package_version_file
           {
             file = erase_item file;
             version = Option.map ~f:erase_item version;
             compatibility = string_of_compatibility compatibility;
             arch_independent = false;
           })
  (* custom commands *)
  | Yadd_custom_command { outputs; commands; depends } ->
      Project_cmd
        (Add_custom_command
           {
             outputs;
             commands;
             main_dependency = None;
             depends;
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
           })

and compile_cmd (yelu_exp : yelu_exp) : Lang_cmake.cmd = compile yelu_exp
