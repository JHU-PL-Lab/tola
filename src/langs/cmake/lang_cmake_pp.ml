open Base
open Lang_cmake
open Lang_cmake_utils

let list_sp pp = Fmt.list ~sep:Fmt.sp pp
let list_br pp = Fmt.list ~sep:Fmt.cut (* Format.pp_force_newline *) pp
let quoted s = "\"" ^ s ^ "\""
let pp_quoted = Fmt.using quoted Fmt.string

let pp_with_key key pp_ele ff = function
  | None -> ()
  | Some ele -> Fmt.pf ff "%s %a " key pp_ele ele

let pp_list_with_key key pp_ele ff = function
  | [] -> ()
  | xs -> Fmt.pf ff "%s %a " key (list_sp pp_ele) xs

let pp_flag key ff flag = if flag then Fmt.pf ff "@;%s " key else ()

let pp_version_opt ff = function
  | None -> ()
  | Some ver -> Fmt.pf ff "VERSION %s" (string_of_version ver)

let pp_target ff s = Fmt.string ff s
let pp_source ff s = Fmt.string ff s
let pp_var ff s = Fmt.string ff s

let pp_cond ff cond =
  Fmt.string ff (String.concat ~sep:" " cond)
let pp_string_quoted ff msg = Fmt.string ff (quoted msg)
let pp_message = pp_string_quoted

let pp_arg ff = function
  | Bare s -> Fmt.string ff s
  | Quoted s -> pp_string_quoted ff s

let string_of_scope = function
  | Function_scope -> "FUNCTION"
  | Directory_scope -> "DIRECTORY"

let pp_scope = Fmt.using string_of_scope Fmt.string

let pp_property ff { prop; value } =
  Fmt.(pf ff "%a %a" string prop pp_arg value)

let pp_parent_scope =
  Fmt.using (fun ps -> if ps then "PARENT_SCOPE" else "") Fmt.string

let pp_args_with_kind ff ({ kind; items } : items_with_kind) =
  Fmt.pf ff "%s %a" kind (list_sp pp_arg) items

let pp_target_feature ff ({ kind; feature } : target_feature) =
  Fmt.pf ff "%s %s" kind feature

let pp_custom_command ff ({ command; args } : custom_command) =
  Fmt.(pf ff "%a %a" string command (list_sp string) args)

(* New helper printers *)

let string_of_include_guard_scope = function
  | Ig_directory -> "DIRECTORY"
  | Ig_global -> "GLOBAL"

let pp_include_guard_scope =
  Fmt.using string_of_include_guard_scope Fmt.string

let string_of_message_mode = function
  | Mm_fatal_error -> "FATAL_ERROR"
  | Mm_verbose -> "VERBOSE"

let pp_message_mode = Fmt.using string_of_message_mode Fmt.string

let string_of_message_reporting_state = function
  | Mr_check_start -> "CHECK_START"
  | Mr_check_pass -> "CHECK_PASS"
  | Mr_check_fail -> "CHECK_FAIL"

let pp_message_reporting_state =
  Fmt.using string_of_message_reporting_state Fmt.string

let string_of_math_output_format = function
  | Decical -> "DECIMAL"
  | Hexdecimal -> "HEXADECIMAL"

let pp_math_output_format = Fmt.using string_of_math_output_format Fmt.string

let string_of_separate_arguments_mode = function
  | Sa_unix_command -> "UNIX_COMMAND"
  | Sa_windows_command -> "WINDOWS_COMMAND"
  | Sa_native_command -> "NATIVE_COMMAND"
  | Sa_program -> "PROGRAM"
  | Sa_args -> "ARGS"

let pp_separate_arguments_mode =
  Fmt.using string_of_separate_arguments_mode Fmt.string

let string_of_before_or_after = function Before -> "BEFORE" | After -> "AFTER"
let pp_before_or_after = Fmt.using string_of_before_or_after Fmt.string


let string_of_define_property_mode = function
  | Dp_global -> "GLOBAL"
  | Dp_directory -> "DIRECTORY"
  | Dp_target -> "TARGET"
  | Dp_source -> "SOURCE"
  | Dp_test -> "TEST"
  | Dp_variable -> "VARIABLE"
  | Dp_cached_variable -> "CACHED_VARIABLE"

let pp_define_property_mode =
  Fmt.using string_of_define_property_mode Fmt.string

let pp_definition ff = function
  | Def_var var -> pp_var ff var
  | Def_var_kv { var; value } -> Fmt.pf ff "%a=%a" pp_var var pp_arg value

let string_of_add_executable_option = function
  | Ae_win32 -> "WIN32"
  | Ae_macos_bundle -> "MACOSX_BUNDLE"
  | Ae_exclude_from_all -> "EXCLUDE_FROM_ALL"

let pp_add_executable_option =
  Fmt.using string_of_add_executable_option Fmt.string

let string_of_link_library_kind = function
  | Ll_debug -> "debug"
  | Ll_optimized -> "optimized"
  | Ll_general -> "general"

let pp_link_library_kind = Fmt.using string_of_link_library_kind Fmt.string

let pp_link_library_group ff { item; items; kind } =
  Fmt.(
    pf ff "%a %a %a" pp_link_library_kind kind string item (list_sp string)
      items)

let string_of_file_set_type = function
  | Fs_headers -> "HEADERS"
  | Fs_cxxmodules -> "CXX_MODULES"

let pp_file_set_type = Fmt.using string_of_file_set_type Fmt.string

let pp_target_file_set ff { kind; file_set = _; type_; base_dirs; files } =
  Fmt.(
    pf ff "%s TYPE %a%a%a" kind pp_file_set_type type_
      (pp_list_with_key "BASE_DIRS" string)
      base_dirs
      (pp_list_with_key "FILES" string)
      files)

let string_of_dep_provider_cmd = function
  | Dp_find_package -> "FIND_PACKAGE"
  | Dp_fetch_content -> "FETCHCONTENT_MAKEAVAILABLE_SERIAL"

let pp_dep_provider_cmd = Fmt.using string_of_dep_provider_cmd Fmt.string

let string_of_query_key = function
  | Number_logical_cores -> "NUMBER_OF_LOGICAL_CORES"
  | Number_physical_cores -> "NUMBER_OF_PHYSICAL_CORES"
  | Hostname -> "HOSTNAME"
  | FQDN -> "FQDN"
  | Total_virtual_memory -> "TOTAL_VIRTUAL_MEMORY"
  | Available_virtual_memory -> "AVAILABLE_VIRTUAL_MEMORY"
  | Total_physical_memory -> "TOTAL_PHYSICAL_MEMORY"
  | Available_physical_memory -> "AVAILABLE_PHYSICAL_MEMORY"
  | Is_64bit -> "IS_64BIT"
  | Has_fpu -> "HAS_FPU"
  | Has_mmx -> "HAS_MMX"
  | Has_mmx_plus -> "HAS_MMX_PLUS"
  | Has_sse -> "HAS_SSE"
  | Has_sse2 -> "HAS_SSE2"
  | Has_sse_fp -> "HAS_SSE_FP"
  | Has_sse_mmx -> "HAS_SSE_MMX"
  | Has_amd_3dnow -> "HAS_AMD_3DNOW"
  | Has_amd_3dnow_plus -> "HAS_AMD_3DNOW_PLUS"
  | Has_ia64 -> "HAS_IA64"
  | Has_serial_number -> "HAS_SERIAL_NUMBER"
  | Proceessor_name -> "PROCESSOR_NAME"
  | Processor_description -> "PROCESSOR_DESCRIPTION"
  | Os_name -> "OS_NAME"
  | Os_release -> "OS_RELEASE"
  | Os_version -> "OS_VERSION"
  | Os_platform -> "OS_PLATFORM"
  | Msystem_prefix -> "MSYSTEM_PREFIX"
  | Distrib_info -> "DISTRIB_INFO"
  | Distrib_name key -> Fmt.str "DISTRIB_INFO %s" key

let pp_query_key = Fmt.using string_of_query_key Fmt.string

let string_of_windows_reg_view = function
  | Wr_view_64 -> "64"
  | Wr_view_32 -> "32"
  | Wr_view_64_32 -> "64_32"
  | Wr_view_32_64 -> "32_64"
  | Wr_view_host -> "HOST"
  | Wr_view_target -> "TARGET"
  | Wr_view_both -> "BOTH"

let pp_windows_reg_view = Fmt.using string_of_windows_reg_view Fmt.string

let string_of_configure_file_permission = function
  | No_source_permission -> "NO_SOURCE_PERMISSIONS"
  | Use_source_permission -> "USE_SOURCE_PERMISSIONS"
  | File_permission -> "FILE_PERMISSIONS"

let pp_configure_file_permission =
  Fmt.using string_of_configure_file_permission Fmt.string

let string_of_newline_style = function
  | Newline_unix -> "UNIX"
  | Newline_dos -> "DOS"
  | Newline_win32 -> "WIN32"
  | Newline_lf -> "LF"
  | Newline_crlf -> "CRLF"

let pp_newline_style = Fmt.using string_of_newline_style Fmt.string

let string_of_variable_watch_access = function
  | Vw_read_access -> "READ_ACCESS"
  | Vm_unknown_read_access -> "UNKNOWN_READ_ACCESS"
  | Vm_unknown_modified_access -> "UNKNOWN_MODIFIED_ACCESS"
  | Vm_removed_access -> "REMOVED_ACCESS"

let _pp_variable_watch_access =
  Fmt.using string_of_variable_watch_access Fmt.string

(* Main printers *)

let rec pp ff e =
  match e with
  (* syntactic *)
  | Int i -> Fmt.int ff i
  | Bool true -> Fmt.string ff "True"
  | Bool false -> Fmt.string ff "False"
  | Var_exp s -> Fmt.string ff s
  | Dollar e -> Fmt.pf ff "${%a}" pp e
  | Exp_list exps -> (list_br pp) ff exps
  | Quote s -> Fmt.string ff s
  (* control flow *)
  | Block { scope_policy = _; scope_var; propagate } ->
      Fmt.(
        pf ff "block(SCOPE_FOR%a%a)@.endblock()"
          (pp_list_with_key " VARIABLES" pp_var)
          scope_var
          (fun ff v ->
            if String.length v > 0 then pf ff " PROPAGATE %s" v)
          propagate)
  | While { cond; commands } ->
      Fmt.(
        pf ff "while(%a)@.@[<2>  %a@]@.endwhile()" pp_cond cond pp commands)
  | Break -> Fmt.string ff "break()"
  | Continue -> Fmt.string ff "continue()"
  | Return { propogate_vars } ->
      Fmt.(
        pf ff "return(%a)"
          (pp_list_with_key "PROPAGATE" pp_var)
          propogate_vars)
  | If { cond; then_; else_ } ->
      Fmt.(
        pf ff "if (%a)@.@[<2>  %a@]@.else()@.@[<2>  %a@]@.endif()@." pp_cond
          cond pp then_ (option pp) else_)
  | Function { name; args; cmds } ->
      Fmt.(
        pf ff "function(%a %a)@.@[<2>  %a@]@.endfunction()@." pp_var name
          (list_sp string) args
          (list ~sep:(sps 0) pp)
          cmds)
  | Macro { name; args; commands } ->
      Fmt.(
        pf ff "macro(%a %a)@.@[<2>  %a@]@.endmacro()@." pp_var name
          (list_sp pp_var) args pp commands)
  | Apply { name; args } ->
      Fmt.(pf ff "%a(%a)@." pp_var name (list_sp pp_arg) args)
  | Foreach { loop_var } ->
      Fmt.(pf ff "foreach(%a)@.endforeach()" pp_var loop_var)
  | Foreach_range { loop_var; start; stop; step } ->
      Fmt.(
        pf ff "foreach(%a RANGE %a%a%a)@.endforeach()" pp_var loop_var
          (pp_with_key "" pp_var)
          start pp_var stop
          (pp_with_key "" pp_var)
          step)
  | Foreach_in { loop_var; lists; step = _ } ->
      Fmt.(
        pf ff "foreach(%a IN LISTS %a)@.endforeach()" pp_var loop_var
          (list_sp pp_var) lists)
  | Include { file; optional; result_var; no_policy_scope } ->
      Fmt.(
        pf ff "include(%a%s%a%a)" pp_arg file
          (if optional then " OPTIONAL " else "")
          (option pp_var) result_var (option pp_scope) no_policy_scope)
  | Include_guard { scope } ->
      Fmt.pf ff "include_guard(%a)" pp_include_guard_scope scope
  (* state *)
  | Cmake_option { var; msg; value } ->
      Fmt.(pf ff "option(%a %a %a)" pp_var var pp_message msg pp_arg value)
  | Get_cmake_property { var; property } ->
      Fmt.(pf ff "get_cmake_property(%a %a)" pp_var var string property)
  | Get_directory_property { var; directory; property } ->
      Fmt.(
        pf ff "get_directory_property(%a%a %a)" pp_var var
          (fun ff dir ->
            if String.length dir > 0 then pf ff " DIRECTORY %s" dir)
          directory string property)
  | Get_filename_component { var; filename; mode = _; cache } ->
      Fmt.(
        pf ff "get_filename_component(%a %a%a)" pp_var var string filename
          (pp_flag "CACHE")
          cache)
  | Set { var; values; parent_scope } ->
      Fmt.(
        pf ff "set(%a %a %a)" pp_var var (list_sp pp_arg) values pp_parent_scope
          parent_scope)
  | Set_cache { var_value_pairs; parent_scope } ->
      Fmt.(
        pf ff "set(%a CACHE %a)" (list_sp (pair ~sep:sp pp_var pp_arg))
          var_value_pairs pp_parent_scope parent_scope)
  | Set_env { var; value } ->
      Fmt.(pf ff "set(ENV{%a} %a)" pp_var var pp_arg value)
  | Set_directory_properties { prop_value_pairs } ->
      Fmt.(
        pf ff "set_directory_properties(PROPERTIES %a)"
          (list_sp (pair ~sep:sp pp_var pp_arg))
          prop_value_pairs)
  | Unset { var; cache; parent_scope } ->
      Fmt.(
        pf ff "unset(%a%a%a)" pp_var var (pp_flag "CACHE") cache
          (pp_flag "PARENT_SCOPE")
          parent_scope)
  | Unset_env { var } -> Fmt.(pf ff "unset(ENV{%a})" pp_var var)
  (* property *)
  | Get_property
      {
        var;
        global;
        directory;
        source;
        test;
        install;
        variable;
        property_name;
        set;
        _;
      } ->
      Fmt.(
        pf ff "get_property(%a%a%a%a%a%a%a PROPERTY %a%a)" pp_var var
          (pp_flag "GLOBAL") global
          (fun ff dir ->
            if String.length dir > 0 then pf ff " DIRECTORY %s" dir)
          directory
          (fun ff src ->
            if String.length src > 0 then pf ff " SOURCE %s" src)
          source
          (fun ff tst ->
            if String.length tst > 0 then pf ff " TEST %s" tst)
          test
          (fun ff f ->
            if String.length f > 0 then pf ff " INSTALL %s" f)
          install (pp_flag "VARIABLE") variable string property_name
          (pp_flag "SET") set)
  | Set_property { targets; properties; _ } ->
      Fmt.(
        pf ff "set_property(TARGET %a@;PROPERTY %a)" (list_sp pp_target) targets
          (list_sp pp_property) properties)
  (* info and debug *)
  | Site_name { var } -> Fmt.(pf ff "site_name(%a)" pp_var var)
  | Variable_watch { var; access = _; value = _; _ } ->
      Fmt.(pf ff "variable_watch(%a)" pp_var var)
  (* list/string/math lib *)
  | List_append { var; values } ->
      Fmt.(pf ff "list(APPEND %a %a)@." pp_var var (list_sp pp_arg) values)
  | Mark_as_advanced { clear; force; vars } ->
      Fmt.(
        pf ff "mark_as_advanced(%a%a%a)" (pp_flag "CLEAR") clear
          (pp_flag "FORCE") force (list_sp pp_var) vars)
  | Math_lib { var; exp; output_format } ->
      Fmt.(
        pf ff "math(EXPR %a %a OUTPUT_FORMAT %a)" pp_var var pp exp
          pp_math_output_format output_format)
  | Message { mode; state = _; texts } ->
      Fmt.(
        pf ff "message(%a %a)" pp_message_mode mode (list_sp pp_string_quoted)
          texts)
  | Message_config_log { texts } ->
      Fmt.(pf ff "message(CONFIGURE_LOG %a)" (list_sp pp_string_quoted) texts)
  | Option { var; help_text; value } ->
      Fmt.(
        pf ff "option(%a %a %a)" pp_var var
          (list_sp pp_string_quoted)
          help_text pp value)
  | Separete_arguments { var; mode } ->
      Fmt.(
        pf ff "separate_arguments(%a %a)" pp_var var pp_separate_arguments_mode
          mode)
  (* delegated *)
  | Cmake_cmd cmd -> (Fmt.vbox pp_cmake_cmd) ff cmd
  | Project_cmd cmd -> (Fmt.vbox pp_project_cmd) ff cmd
  | Module_cmd cmd -> (Fmt.vbox pp_module_cmd) ff cmd
  (* AST stubs — these constructors carry no fields *)
  | Execute_process -> Fmt.string ff "execute_process()"
  | File -> Fmt.string ff "file()"
  | Find_file -> Fmt.string ff "find_file()"
  | Find_library -> Fmt.string ff "find_library()"
  | Find_package -> Fmt.string ff "find_package()"
  | Find_path -> Fmt.string ff "find_path()"
  | Find_program -> Fmt.string ff "find_program()"
  | String_lib -> Fmt.string ff "string()"

and pp_cmake_cmd ff cmd =
  match cmd with
  | Cmake_minimum_required { min; max = _ } ->
      Fmt.pf ff "cmake_minimum_required(VERSION %s)" (string_of_version min)
  | Configure_file { input; output; permission_level; copy_only; escape_quotes; only; newline_style; _ } ->
      Fmt.(
        pf ff "configure_file(%a %a%a%a%a%a%a)" string input string output
          (pp_with_key "" pp_configure_file_permission)
          permission_level
          (pp_flag "COPYONLY")
          (Option.value ~default:false copy_only)
          (pp_flag "@ONLY")
          (Option.value ~default:false escape_quotes)
          (pp_flag "ESCAPE_QUOTES")
          (Option.value ~default:false only)
          (pp_with_key "NEWLINE_STYLE" pp_newline_style)
          newline_style)
  | Host_system_information { result = res; query } ->
      Fmt.(
        pf ff "cmake_host_system_information(RESULT %a QUERY %a)" pp_var res
          pp_query_key query)
  | Host_system_information_windows_reg
      { result = res; query; view; separator; error_var } ->
      Fmt.(
        pf ff
          "cmake_host_system_information(RESULT %a QUERY %a%a%a%a)" pp_var
          res pp_query_key query
          (pp_with_key "VIEW" pp_windows_reg_view)
          view
          (pp_with_key "SEPARATOR" string)
          separator
          (pp_with_key "ERROR_VARIABLE" pp_var)
          error_var)
  | Cmake_meta_lang meta -> pp_cmake_meta_lang ff meta
  | Cmake_parse_argument { prefix = pfx; one_keyword; multi_keyword; args } ->
      Fmt.(
        pf ff "cmake_parse_arguments(%a %a %a %a)" string pfx
          (pp_string_quoted)
          (String.concat ~sep:";" one_keyword)
          (pp_string_quoted)
          (String.concat ~sep:";" multi_keyword)
          (list_sp string) args)
  | Cmake_parse_argument_argv { n; prefix = pfx; one_keyword; multi_keyword } ->
      Fmt.(
        pf ff "cmake_parse_arguments(PARSE_ARGV %a %a %a %a)" int n string
          pfx
          (pp_string_quoted)
          (String.concat ~sep:";" one_keyword)
          (pp_string_quoted)
          (String.concat ~sep:";" multi_keyword))
  | Cmake_path_get { path_var; out_var } ->
      Fmt.(
        pf ff "cmake_path(GET %a %a)" pp_var path_var pp_var out_var)
  | Cmake_policy_version { min; max } ->
      Fmt.(
        pf ff "cmake_policy(VERSION %a...%a)" string
          (string_of_version min) string (string_of_version max))
  | Cmake_policy_set { nnnn } ->
      Fmt.(pf ff "cmake_policy(SET %a)" string (if nnnn then "NEW" else "OLD"))
  | Cmake_policy_get { var } ->
      Fmt.(pf ff "cmake_policy(GET %a)" pp_var var)
  | Cmake_policy_push -> Fmt.string ff "cmake_policy(PUSH)"
  | Cmake_policy_pop -> Fmt.string ff "cmake_policy(POP)"

and pp_cmake_meta_lang ff = function
  | Meta_call { cmd; arg } ->
      Fmt.(
        pf ff "cmake_language(CALL %a %a)" pp cmd (list_sp pp) arg)
  | Meta_eval { code } ->
      Fmt.(pf ff "cmake_language(EVAL CODE %a)" string code)
  | Meta_defer_call { dir; id = id_; var } ->
      Fmt.(
        pf ff "cmake_language(DEFER%a%a ID_VAR %a)"
          (fun ff d ->
            if String.length d > 0 then pf ff " DIRECTORY %s" d)
          dir
          (fun ff i ->
            if String.length i > 0 then pf ff " ID %s" i)
          id_ pp_var var)
  | Meta_defer_call_ids { dir; var } ->
      Fmt.(
        pf ff "cmake_language(DEFER%a GET_CALL_IDS %a)"
          (fun ff d ->
            if String.length d > 0 then pf ff " DIRECTORY %s" d)
          dir pp_var var)
  | Meta_defer_cancel { dir; id = id_ } ->
      Fmt.(
        pf ff "cmake_language(DEFER%a CANCEL_CALL %a)"
          (fun ff d ->
            if String.length d > 0 then pf ff " DIRECTORY %s" d)
          dir string id_)
  | Meta_set_dep_provider { var; dp_cmd } ->
      Fmt.(
        pf ff "cmake_language(SET_DEPENDENCY_PROVIDER %a SUPPORTED_METHODS %a)"
          pp_var var pp_dep_provider_cmd dp_cmd)
  | Meta_get_msg_log_level { var } ->
      Fmt.(pf ff "cmake_language(GET_MESSAGE_LOG_LEVEL %a)" pp_var var)
  | Meta_exit { exit_code } ->
      Fmt.(pf ff "cmake_language(EXIT %a)" int exit_code)

and pp_project_cmd ff cmd =
  match cmd with
  | Project { name; version; description; homepage_url; languages } ->
      Fmt.(
        pf ff "project(%a %a%a%a%a)" string name pp_version_opt version
          (pp_with_key "DESCRIPTION" pp_string_quoted)
          description
          (pp_with_key "HOMEPAGE_URL" pp_string_quoted)
          homepage_url
          (pp_list_with_key "LANGUAGES" string)
          languages)
  | Add_executable { name; options; sources } ->
      Fmt.(
        pf ff "add_executable(%a %a%a)" string name
          (list_sp pp_add_executable_option)
          options (list_sp pp_source) sources)
  | Add_executable_imported { name; global } ->
      Fmt.(
        pf ff "add_executable(%a IMPORTED%a)" string name (pp_flag "GLOBAL")
          global)
  | Add_executable_alias { name; target } ->
      Fmt.(pf ff "add_executable(%a ALIAS %a)" string name pp_target target)
  | Add_subdirectory { source_dir; binary_dir; exclude_from_all; system } ->
      Fmt.(
        pf ff "add_subdirectory(%a%a%a%a)" string source_dir
          (pp_with_key "" string)
          binary_dir
          (pp_flag "EXCLUDE_FROM_ALL")
          exclude_from_all (pp_flag "SYSTEM") system)
  | Add_library { name; sources; type_; exclude_from_all } ->
      Fmt.(
        pf ff "add_library(%a %a%a %a)" string name (option string) type_
          (pp_flag "EXCLUDE_FROM_ALL")
          exclude_from_all (list_sp pp_source) sources)
  | Add_library_object { name; sources } ->
      Fmt.(
        pf ff "add_library(%a OBJECT %a)" string name (list_sp pp_source)
          sources)
  | Add_library_interface { name } ->
      Fmt.(pf ff "add_library(%a INTERFACE)" string name)
  | Add_library_alias { name; target } ->
      Fmt.(pf ff "add_library(%a ALIAS %a)" string name pp_target target)
  (* target *)
  | Target_compile_definitions { target; items } ->
      Fmt.(
        pf ff "target_compile_definitions(%a %a)" pp_target target
          (list_sp pp_args_with_kind)
          items)
  | Target_compile_features { target; features } ->
      Fmt.(
        pf ff "target_compile_features(%a %a)" pp_target target
          (list_sp pp_target_feature)
          features)
  | Target_compile_options { target; items; before } ->
      Fmt.(
        pf ff "target_compile_options(%a%s@[<2>%a@])" pp_target target
          (if before then "BEFORE" else " ")
          (list_sp pp_args_with_kind)
          items)
  | Target_link_libraries { targets; items } ->
      Fmt.(
        pf ff "target_link_libraries(%a %a)" (list_sp pp_target) targets
          (list_sp pp_args_with_kind)
          items)
  | Target_include_directories { target; items; system; before_or_after } ->
      Fmt.(
        pf ff "target_include_directories(%a%a%a @[<2>%a@])" pp_target target
          (pp_flag "SYSTEM")
          (Option.value ~default:false system)
          (pp_with_key "" pp_before_or_after)
          before_or_after
          (list_sp pp_args_with_kind)
          items)
  | Target_link_directories { target; before; items } ->
      Fmt.(
        pf ff "target_link_directories(%a%s@[<2>%a@])" pp_target target
          (if before then " BEFORE" else "")
          (list_sp pp_args_with_kind)
          items)
  | Target_link_options { target; before; items } ->
      Fmt.(
        pf ff "target_link_options(%a%s@[<2>%a@])" pp_target target
          (if before then " BEFORE" else "")
          (list_sp pp_args_with_kind)
          items)
  | Target_precompile_headers { target; items } ->
      Fmt.(
        pf ff "target_precompile_headers(%a %a)" pp_target target
          (list_sp pp_args_with_kind)
          items)
  | Target_sources { target; items } ->
      Fmt.(
        pf ff "target_sources(%a %a)" pp_target target
          (list_sp pp_args_with_kind)
          items)
  | Target_sources_file_set { target; items } ->
      Fmt.(
        pf ff "target_sources(%a %a)" pp_target target
          (list_sp pp_args_with_kind)
          items)
  (* custom *)
  | Add_custom_command { outputs; commands; depends; main_dependency;
                         working_directory; comment; verbatim;
                         uses_terminal; append = is_append; _ } ->
      Fmt.(
        pf ff "add_custom_command(OUTPUT %a@;COMMAND %a@.%a%a%a%a%a%a%a)@."
          (list_sp string) outputs
          (list_sp pp_custom_command) commands
          (pp_list_with_key "DEPENDS" string) depends
          (pp_with_key "MAIN_DEPENDENCY" string) main_dependency
          (pp_with_key "WORKING_DIRECTORY" string) working_directory
          (pp_with_key "COMMENT" string) comment
          (pp_flag "VERBATIM") verbatim
          (pp_flag "USES_TERMINAL") uses_terminal
          (pp_flag "APPEND") is_append)
  | Add_custom_target
      { all; commands; depends; working_directory; comment;
        verbatim; uses_terminal; sources; _ } ->
      Fmt.(
        pf ff "add_custom_target(%a%a%a%a%a%a%a%a)" (pp_flag "ALL") all
          (list_sp pp_custom_command) commands
          (pp_list_with_key "DEPENDS" string) depends
          (pp_with_key "WORKING_DIRECTORY" string) working_directory
          (pp_with_key "COMMENT" string) comment
          (pp_flag "VERBATIM") verbatim
          (pp_flag "USES_TERMINAL") uses_terminal
          (pp_list_with_key "SOURCES" string) sources)
  (* property *)
  | Get_source_file_property { var; file; property } ->
      Fmt.(
        pf ff "get_source_file_property(%a %a %a)" pp_var var string file
          pp_property property)
  | Set_source_files_properties { files; directories; target_directories } ->
      Fmt.(
        pf ff "set_source_files_properties(%a%a%a)"
          (list_sp string) files
          (pp_list_with_key "DIRECTORY" string) directories
          (pp_list_with_key "TARGET_DIRECTORY" pp_target) target_directories)
  | Get_target_property { var; target; property } ->
      Fmt.(
        pf ff "get_target_property(%a %a %a)" pp_var var pp_target target
          pp_property property)
  | Set_target_properties { target; properties } ->
      Fmt.(
        pf ff "set_target_properties(%a PROPERTIES %a)" pp_target target
          (list_sp pp_property) properties)
  | Enable_testing -> Fmt.(pf ff "enable_testing()")
  | Add_test { name; command; args; dir } ->
      Fmt.(
        pf ff "add_test(NAME %a COMMAND %a %a%a)" string name string command
          (list_sp string) args
          (pp_with_key "WORKING_DIRECTORY" string)
          dir)
  | Get_test_property { test; property; directory; var } ->
      Fmt.(
        pf ff "get_test_property(%a %a%a %a)" string test pp_property property
          (pp_with_key "DIRECTORY" string)
          directory pp_var var)
  | Set_tests_properties { tests; dir; properties } ->
      Fmt.(
        pf ff "set_tests_properties(%a%a PROPERTIES %a)" (list_sp string) tests
          (pp_with_key "WORKING_DIRECTORY" string)
          dir (list_sp pp_property) properties)
  | Define_property
      { mode; property_name; inherited; brief_docs; full_docs; initialize_from }
    ->
      Fmt.(
        pf ff "define_property(%a@;PROPERTY %a%a%a%a%a)" pp_define_property_mode
          mode string property_name (pp_flag "INHERITED") inherited
          (pp_list_with_key "BRIEF_DOCS" pp_string_quoted)
          brief_docs
          (pp_list_with_key "FULL_DOCS" pp_string_quoted)
          full_docs
          (fun ff v ->
            if String.length v > 0 then
              pf ff "@;INITIALIZE_FROM_VARIABLE %s" v)
          initialize_from)
  (* compile/link *)
  | Add_compile_definitions { defs } ->
      Fmt.(pf ff "add_compile_definitions(%a)" (list_sp pp_definition) defs)
  | Add_compile_options { options_ } ->
      Fmt.(pf ff "add_compile_options(%a)" (list_sp string) options_)
  | Add_definitions { defs } ->
      Fmt.(pf ff "add_definitions(%a)" (list_sp pp_definition) defs)
  | Remove_definitions { defs } ->
      Fmt.(pf ff "remove_definitions(%a)" (list_sp pp_definition) defs)
  | Add_dependencies { target; dep } ->
      Fmt.(pf ff "add_dependencies(%a %a)" pp_target target string dep)
  | Add_link_options { options } ->
      Fmt.(pf ff "add_link_options(%a)" (list_sp string) options)
  (* include *)
  | Include_directories { before_or_after; system; dir; dirs } ->
      Fmt.(
        pf ff "include_directories(%a%a %a %a)" pp_before_or_after
          before_or_after (pp_flag "SYSTEM") system string dir
          (list_sp string) dirs)
  | Include_external_msproject
      { projectname; location; type_; guid; platform; deps } ->
      Fmt.(
        pf ff "include_external_msproject(%a %a%a%a%a%a)" string projectname
          string location
          (pp_with_key "TYPE" string)
          type_
          (pp_with_key "GUID" string)
          guid
          (pp_with_key "PLATFORM" string)
          platform
          (pp_list_with_key "" string)
          deps)
  | Include_regular_expression { regex_match; regex_complain } ->
      Fmt.(
        pf ff "include_regular_expression(%a%a)" string regex_match
          (pp_with_key "" string)
          regex_complain)
  (* link *)
  | Link_directories { before_or_after; directory; directories } ->
      Fmt.(
        pf ff "link_directories(%a %a %a)" pp_before_or_after before_or_after
          string directory (list_sp string) directories)
  | Link_libraries { groups } ->
      Fmt.(pf ff "link_libraries(%a)" (list_sp pp_link_library_group) groups)
  (* export *)
  | Export_targets { targets } ->
      Fmt.(pf ff "export(TARGETS %a)" (list_sp pp_target) targets)
  | Export_export { name; file } ->
      Fmt.(
        pf ff "export(EXPORT %a@;%a)" string name
          (pp_with_key "FILE" pp_arg)
          file)
  | Export_package { name } ->
      Fmt.(pf ff "export(PACKAGE %a)" string name)
  | Export_setup { name } ->
      Fmt.(pf ff "export(SETUP %a)" string name)
  (* install *)
  | Install_targets { targets; destination; export; _ } ->
      Fmt.(
        pf ff "install(TARGETS %a@[<2>@;%a@;DESTINATION %a@])"
          (list_sp pp_target) targets
          (pp_with_key "EXPORT" string)
          export pp_arg destination)
  | Install_files { files; destination; _ } ->
      Fmt.(
        pf ff "install(FILES %a@[<2>@;DESTINATION %a@])" (list_sp pp_arg) files
          pp_arg destination)
  | Install_export { file; export; destination; _ } ->
      Fmt.(
        pf ff "install(EXPORT %a@[<2>@;%a@;DESTINATION %a@])" pp_arg export
          (pp_with_key "FILE" pp_arg)
          file pp_arg destination)
  (* misc *)
  | Aux_source_directory { dir; var } ->
      Fmt.(pf ff "aux_source_directory(%a %a)" string dir pp_var var)
  | Build_command { var; configuration; parallel_level; target; project_name } ->
      Fmt.(
        pf ff "build_command(%a%a%a%a%a)" pp_var var
          (pp_with_key "CONFIGURATION" string)
          configuration
          (pp_with_key "PARALLEL_LEVEL" int)
          parallel_level
          (pp_with_key "TARGET" pp_target)
          target
          (pp_with_key "PROJECT_NAME" string)
          project_name)
  | Cmake_file_api { api_version; code_model } ->
      Fmt.(
        pf ff "cmake_file_api(QUERY API_VERSION %a CODEMODEL %a)" string
          (string_of_version api_version)
          (list_sp (Fmt.using string_of_version string))
          code_model)
  | Create_test_sourcelist { name; drive_name; tests; options; extra_include; function_ } ->
      Fmt.(
        pf ff "create_test_sourcelist(%a %a %a%a%a%a)" string name string
          drive_name (list_sp string) tests
          (pp_list_with_key "" string) options
          (fun ff s ->
            if String.length s > 0 then pf ff " EXTRA_INCLUDE %s" s)
          extra_include
          (fun ff s ->
            if String.length s > 0 then pf ff " FUNCTION %s" s)
          function_)
  | Enable_language { langs; optional } ->
      Fmt.(
        pf ff "enable_language(%a%a)" (list_sp string) langs
          (pp_flag "OPTIONAL")
          optional)
  | Fltk_wrap_ui { resulting_library_name; sources } ->
      Fmt.(
        pf ff "fltk_wrap_ui(%a %a)" string resulting_library_name
          (list_sp pp_source) sources)
  | Load_cache_read { directory; prefix = pfx; entries } ->
      Fmt.(
        pf ff "load_cache(%a READ_WITH_PREFIX %a %a)" string directory string
          pfx (list_sp string) entries)
  | Load_cache { directory; exclude; include_internals } ->
      Fmt.(
        pf ff "load_cache(%a%a%a)" string directory
          (pp_list_with_key "EXCLUDE" string)
          exclude
          (pp_list_with_key "INCLUDE_INTERNALS" string)
          include_internals)
  | Source_group { name; files; regular_exp } ->
      Fmt.(
        pf ff "source_group(%a%a%a)" pp_string_quoted name
          (pp_list_with_key "FILES" string) files
          (fun ff s ->
            if String.length s > 0 then pf ff " REGULAR_EXPRESSION %s" s)
          regular_exp)
  | Source_group_tree { root; prefix = pfx; files } ->
      Fmt.(
        pf ff "source_group(TREE %a%a%a)" string root
          (fun ff s ->
            if String.length s > 0 then pf ff " PREFIX %s" s)
          pfx
          (pp_list_with_key "FILES" string)
          files)
  | Try_compile -> Fmt.string ff "try_compile()"
  | Try_run -> Fmt.string ff "try_run()"

and pp_module_cmd ff = function
  | Configure_package_config_file
      {
        input;
        output;
        install_dest;
        path_vars;
        no_set_and_check_macro;
        no_check_required_components_macro;
      } ->
      Fmt.(
        pf ff
          "configure_package_config_file(%a@;%a@;INSTALL_DESTINATION %a%a%a%a)"
          pp_arg input pp_arg output pp_arg install_dest
          (pp_list_with_key "PATH_VARS " pp_var)
          path_vars
          (pp_flag "NO_SET_AND_CHECK_MACRO")
          no_set_and_check_macro
          (pp_flag "NO_CHECK_REQUIRED_COMPONENTS_MACRO")
          no_check_required_components_macro)
  | Write_basic_package_version_file
      { file; version; compatibility; arch_independent } ->
      Fmt.(
        pf ff "write_basic_package_version_file(%a@;%a@;COMPATIBILITY %a@;%a)"
          pp_arg file
          (pp_with_key "VERSION" pp_arg)
          version Fmt.string compatibility
          (pp_flag "ARCH_INDEPENDENT")
          arch_independent)
