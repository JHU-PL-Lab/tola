(* An AST of cmake-command

   When the block() is inside a foreach() or while() command, the break() and continue() commands can be used inside the block.
   https://cmake.org/cmake/help/latest/command/block.html
*)

type permissions = string list
type directory = string
type path = string
type id = string
type include_guard_scope = Ig_directory | Ig_global

(* Argument Caveats *)
type pseudo_var = Argn | Argc | Argv | Argv0
type math_output_format = Decical | Hexdecimal
type message_mode = Mm_fatal_error | Mm_verbose
type message_reporting_state = Mr_check_start | Mr_check_pass | Mr_check_fail

type cmake_var =
  | Get_os_release_fallback_scripts
  | Get_os_release_fallback_result_of of var
  | Get_os_release_fallback_result

type policy = Policy
type var = Var of string
type var_name = Var_name of string
type value = Value
type version = Version

type variable_watch_access =
  | Vw_read_access
  | Vm_unknown_read_access
  | Vm_unknown_modified_access
  | Vm_removed_access

type separate_arguments_mode =
  | Sa_unix_command
  | Sa_windows_command
  | Sa_native_command
  | Sa_program
  | Sa_args

(* TODO: https://cmake.org/cmake/help/latest/command/cmake_host_system_information.html *)
type host_system_information_windows_reg_view =
  | Wr_view_64
  | Wr_view_32
  | Wr_view_64_32
  | Wr_view_32_64
  | Wr_view_host
  | Wr_view_target
  | Wr_view_both

type configure_file_permission =
  | No_source_permission
  | Use_source_permission
  | File_permission

type newline_style =
  | Newline_unix
  | Newline_dos
  | Newline_win32
  | Newline_lf
  | Newline_crlf

type dep_provider_cmd = Dp_find_package | Dp_fetch_content
type scope = Function_scope | Directory_scope

type query_key =
  | Number_logical_cores
  | Number_physical_cores
  | Hostname
  | FQDN (* Fully qualified domain name *)
  | Total_virtual_memory
  | Available_virtual_memory
  | Total_physical_memory
  | Available_physical_memory
  | Is_64bit
  | Has_fpu
  | Has_mmx
  | Has_mmx_plus
  | Has_sse
  | Has_sse2
  | Has_sse_fp
  | Has_sse_mmx
  | Has_amd_3dnow
  | Has_amd_3dnow_plus
  | Has_ia64
  | Has_serial_number
  | Proceessor_name
  | Processor_description
  | Os_name
  | Os_release
  | Os_version
  | Os_platform
  | Msystem_prefix
  | Distrib_info
  | Distrib_name of string

type cond_check =
  (* Existence Checks *)
  | Exist_command of var
  | Exist_policy of var
  | Exist_target of var
  | Exist_test of var
  | Exist_defined of var

(* Scripting Commands *)
type scripting_cmd = exp

type exp =
  (* Constant and basic *)
  | Int of int
  | Bool of bool
  | String of string
  | Not of exp
  | And of exp * exp
  | Or of exp * exp
  (* Expansion *)
  | Dollar of exp
  (* Structure *)
  | Block of block_exp (* endblock *)
  | While of { cond : exp; commands : exp } (* endwhile *)
  | Break
  | Continue
  | Return of { propogate_vars : var list }
  | Function of { name : var } (* endfunction *)
  | Macro of { name : var; args : var list; commands : exp } (* endmacro *)
  | If of { then_ : exp; else_ : exp option }
  (* elseif *)
  (* endif *)
  | Foreach of { loop_var : var }
  | Foreach_range of {
      loop_var : var;
      start : var option;
      stop : var;
      step : var option;
    }
  | Foreach_in of { loop_var : var; lists : var list; step : var option }
  (* endforeach *)
  | Exp_list of exp list
  | Include of {
      optional : bool;
      result_var : var option;
      no_policy_scope : scope;
    }
  | Include_guard of { scope : include_guard_scope }
  (* State *)
  | Get_cmake_property of { var : var; property : string }
  | Get_directory_property of {
      var : var;
      directory : directory;
      property : string;
    }
  | Get_filename_component of {
      var : var;
      filename : path;
      mode : bool;
      cache : bool;
    }
  | Get_property
  | Set of { var_value_pairs : (var_name * value) list; parent_scope : scope }
  | Set_cache of {
      var_value_pairs : (var_name * value) list;
      parent_scope : scope;
    }
  | Set_env of { var : var; value : value }
  | Set_directory_properties of { prop_value_pairs : (var * value) list }
  (* https://cmake.org/cmake/help/latest/command/set_property.html *)
  | Set_property
  | Unset of { var : var; cache : bool; parent_scope : scope }
  | Unset_env of { var : var }
  (* Info and debug *)
  | Site_name of { var : var }
  | Variable_watch of {
      var : var;
      access : variable_watch_access;
      value : exp option;
      current_list_file : path option;
      stack : path list;
    }
  (* API *)
  | Execute_process
  | File
  | Find_file
  | Find_library
  | Find_package
  | Find_path
  | Find_program
  | Cmake_cmd of cmake_cmd
  | List_lib
  | String_lib
  | Mark_as_advanced of { clear : bool; force : bool; vars : var list }
  | Math_lib of { var : var; exp : exp; output_format : math_output_format }
  | Message of {
      mode : message_mode;
      state : message_reporting_state;
      texts : string list;
    }
  | Message_config_log of { texts : string list }
  | Option of { var : var; help_text : string list; value : exp }
  | Separete_arguments of { var : var; mode : separate_arguments_mode }

(* File Operations *)
and cmd = exp

and block_exp = {
  scope_policy : policy list;
  scope_var : var list;
  propagate : var_name;
}

and cmake_cmd =
  | Host_system_information of { result : var; query : query_key }
  | Host_system_information_windows_reg of {
      result : var;
      query : query_key;
      view : host_system_information_windows_reg_view option;
      separator : string option;
      error_var : var option;
    }
  | Cmake_meta_lang of cmake_meta_lang
  | Cmake_minimum_required of { min : version; max : version }
  | Cmake_parse_argument of {
      prefix : string;
      one_keyword : string list;
      multi_keyword : string list;
      args : string list;
    }
  | Cmake_parse_argument_argv of {
      n : int;
      prefix : string;
      one_keyword : string list;
      multi_keyword : string list;
    }
  (* https://cmake.org/cmake/help/latest/command/cmake_path.html *)
  | Cmake_path_get of { path_var : var; out_var : var }
  | Cmake_policy_version of { min : version; max : version }
  | Cmake_policy_set of { nnnn : bool }
  | Cmake_policy_get of { var : var }
  | Cmake_policy_push
  | Cmake_policy_pop
  | Configure_file of {
      input : path;
      output : path;
      permission_level : configure_file_permission;
      permissions : permissions;
      copy_only : bool;
      escape_quotes : bool;
      only : bool;
      newline_style : newline_style;
    }

and cmake_meta_lang =
  | Meta_call of { cmd : cmd; arg : exp list }
  | Meta_eval of { code : code }
  | Meta_defer_call of { dir : directory; id : id; var : var }
  | Meta_defer_call_ids of { dir : directory; var : var }
  | Meta_defer_cancel of { dir : directory; id : id }
  | Meta_set_dep_provider of { var : var; dp_cmd : dep_provider_cmd }
  | Meta_get_msg_log_level of { var : var }
  | Meta_exit of { exit_code : int }

and code = string

type project_cmd =
  (* Property *)
  | Get_source_file_property
  | Get_target_property
  | Get_test_property
  | Set_source_files_properties
  | Set_target_properties
  | Set_tests_properties
  (* Adding *)
  | Add_compile_definitions
  | Add_compile_options
  | Add_custom_command
  | Add_custom_target
  | Add_definitions
  | Add_dependencies
  | Add_executable
  | Add_library
  | Add_link_options
  | Add_subdirectory
  | Add_test
  (* Target *)
  | Target_compile_definitions
  | Target_compile_features
  | Target_compile_options
  | Target_include_directories
  | Target_link_directories
  | Target_link_libraries
  | Target_link_options
  | Target_precompile_headers
  | Target_sources
  (* Include *)
  | Include_directories
  | Include_external_msproject
  | Include_regular_expression
  (* Link *)
  | Link_directories
  | Link_libraries
  (*  *)
  | Aux_source_directory
  | Build_command
  | Cmake_file_api
  | Create_test_sourcelist
  | Define_property
  | Enable_language
  | Enable_testing
  | Export
  | Fltk_wrap_ui
  | Install
  | Load_cache
  | Project
  | Remove_definitions
  | Source_group
  | Try_compile
  | Try_run
(* Project Commands *)

(* CTest Commands *)
(* Deprecated Commands *)
