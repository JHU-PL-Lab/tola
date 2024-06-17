(* An AST of cmake-command

   When the block() is inside a foreach() or while() command, the break() and continue() commands can be used inside the block.
   https://cmake.org/cmake/help/latest/command/block.html
*)

type permissions = string list
type directory = string
type path = string
type file = path
type id = string
type version = { major : int; minor : int; patch : string }

(* source *)
type source = string
type test = Test
type policy = Policy
type var = Var of string
type output = string
type var_name = Var_name of string
type value = Value
type cache_entry = Cache_entry
type before_or_after = Before | After
type depend = string
type comment = string
type doc = string
type option_ = string
type job_pool = string list

(* target *)
type target = Target of string
type feature = Feature of string
type target_kind = Interface | Public | Private
type target_definition = { kind : target_kind; item : string }
type target_option = { kind : target_kind; item : option_ }
type target_feature = { kind : target_kind; feature : feature }
type set = Set
type file_set_type = Fs_headers | Fs_cxxmodules

type target_file_set = {
  kind : target_kind;
  file_set : set;
  type_ : file_set_type;
  base_dirs : directory list;
  files : file list;
}

type link_library_kind = Ll_debug | Ll_optimized | Ll_general

type link_library_group = {
  item : string;
  items : string list;
  kind : link_library_kind;
}

type land_dep = { lang : string; depend : depend }
type definition = Def_var of var | Def_var_kv of { var : var; value : value }
type property = { prop : string; value : value }
type include_guard_scope = Ig_directory | Ig_global
type set_property_mode = Sp_set | Sp_defined | Sp_brief_doc | Sp_full_doc
type add_executable_option = Ae_win32 | Ae_macos_bundle | Ae_exclude_from_all
type add_library_type = Al_static | Al_shared | Al_module

type custom_command =
  | Custom_command of { command : string; args : string list }

(* Argument Caveats *)
type pseudo_var = Argn | Argc | Argv | Argv0
type math_output_format = Decical | Hexdecimal
type message_mode = Mm_fatal_error | Mm_verbose
type message_reporting_state = Mr_check_start | Mr_check_pass | Mr_check_fail

type define_property_mode =
  | Dp_global
  | Dp_directory
  | Dp_target
  | Dp_source
  | Dp_test
  | Dp_variable
  | Dp_cached_variable

type cmake_var =
  | Get_os_release_fallback_scripts
  | Get_os_release_fallback_result_of of var
  | Get_os_release_fallback_result

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

type code = string
type gs_directory = Gs_directory of directory | Gs_target_directory of target

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

type scripting_cmd = exp

and exp =
  (* Scripting Commands *)
  (* *)
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
  | Set of { var_value_pairs : (var_name * value) list; parent_scope : scope }
  | Set_cache of {
      var_value_pairs : (var_name * value) list;
      parent_scope : scope;
    }
  | Set_env of { var : var; value : value }
  | Set_directory_properties of { prop_value_pairs : (var * value) list }
    (* https://cmake.org/cmake/help/latest/command/set_property.html *)
  | Unset of { var : var; cache : bool; parent_scope : scope }
  | Unset_env of { var : var }
  (* property *)
  | Get_property of {
      var : var;
      global : bool;
      directory : directory;
      source : source;
      source_directory : directory;
      source_target_directory : target;
      install : file;
      test : test;
      test_directory : directory;
      variable : bool;
      property_name : string;
      set : bool;
    }
  | Set_property of {
      global : bool;
      directory : directory list;
      target : target list;
      source : source list;
      source_directory : directory list;
      source_target_directory : target list;
      install : file list;
      test : test list;
      test_directory : directory list;
      cache : cache_entry list;
      append : bool;
      append_string : string;
      property : property list;
    }
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
  | Project_cmd of project_cmd

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
  | Cmake_minimum_required of { min : version; max : version option }
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

and project_cmd =
  (* Project Commands *)
  (* Property *)
  | Get_source_file_property of { var : var; file : file; property : property }
  | Set_source_files_properties of {
      files : file list;
      directories : directory list;
      target_directories : target list;
    }
  | Get_target_property of { var : var; target : target; property : property }
  | Set_target_properties of {
      targets : target list;
      properties : property list;
    }
  | Get_test_property of {
      test : test;
      property : property;
      directory : directory option;
      var : var;
    }
  | Set_tests_properties of {
      tests : test list;
      directory : directory option;
      properties : property list;
    }
  | Define_property of {
      mode : define_property_mode;
      property_name : string;
      inherited : bool;
      brief_docs : doc list;
      full_docs : doc list;
      initialize_from : var;
    }
  | Add_compile_definitions of { defs : definition list }
  (* Any leading -D on an item will be removed *)
  | Target_compile_definitions of {
      target : target;
      target_definitions : target_definition list;
    }
  | Add_compile_options of { options_ : option_ list }
  | Add_definitions of { defs : definition list }
  | Remove_definitions of { defs : definition list }
  | Add_dependencies of { target : target; dep : depend }
  | Add_executable of {
      name : string;
      options : add_executable_option list;
      sources : source list;
    }
  | Add_executable_imported of { name : string; global : bool }
  | Add_executable_alias of { name : string; target : target }
  | Add_library of {
      name : string;
      exclude_from_all : bool;
      sources : file list;
    }
  | Add_library_object of { name : string; sources : file list }
  | Add_library_interface of { name : string }
  | Add_library_alias of { name : string; target : target }
  | Add_link_options of { options : option_ list }
  | Add_subdirectory of {
      source_dir : directory;
      binary_dir : directory option;
      exclude_from_all : bool;
      system : bool;
    }
  | Add_test
  (* Target *)
  | Target_compile_features of {
      target : target;
      features : target_feature list;
    }
  | Target_compile_options of {
      target : target;
      before : bool;
      items : target_definition list;
    }
  | Target_include_directories of {
      target : target;
      system : bool;
      before_or_after : before_or_after;
      items : target_definition list;
    }
  | Target_link_directories of {
      target : target;
      before : bool;
      items : target_definition list;
    }
  | Target_link_libraries
      (* https://cmake.org/cmake/help/latest/command/target_link_libraries.html *) of {
      targets : target list;
      item : string;
    }
  | Target_link_options of {
      target : target;
      before : bool;
      items : target_option list;
    }
  | Target_precompile_headers of { target : target; items : target_option list }
  | Target_sources of { target : target; items : target_definition list }
  | Target_sources_file_set of {
      target : target;
      items : target_definition list;
    }
  (* custom *)
  | Add_custom_command of {
      output : string list;
      custom_commands : custom_command list;
      main_dependency : depend option;
      depends : depend list;
      byproducts : file list;
      implicit_depends : land_dep list;
      working_directory : directory option;
      comment : comment option;
      depfile : file option;
      job_pool : job_pool;
      job_server_aware : bool;
      verbatim : bool;
      append : bool;
      uses_terminal : bool;
      command_expand_list : string list;
      depends_explicit_only : bool;
    }
  | Add_custom_target of {
      all : bool;
      commands : custom_command list;
      depends : depend list;
      byproducts : file list;
      working_directory : directory option;
      comment : comment option;
      job_pool : job_pool;
      job_server_aware : bool;
      verbatim : bool;
      uses_terminal : bool;
      command_expand_list : string list;
      sources : file list;
    }
  (* Include *)
  | Include_directories of {
      before_or_after : before_or_after;
      system : bool;
      dir : directory;
      dirs : directory list;
    }
  | Include_external_msproject of {
      projectname : string;
      location : directory;
      type_ : string option;
      guid : string option;
      platform : string option;
      deps : depend list;
    }
  | Include_regular_expression of {
      regex_match : string;
      regex_complain : string option;
    }
  (* Link *)
  | Link_directories of {
      before_or_after : before_or_after;
      directory : directory;
      directories : directory list;
    }
  | Link_libraries of { groups : link_library_group list }
  (*  *)
  | Aux_source_directory of { dir : directory; var : var }
  | Build_command of {
      var : var;
      configuration : string option;
      parallel_level : int option;
      target : target option;
      project_name : string option;
    }
  | Cmake_file_api of { api_version : version; code_model : version list }
  | Create_test_sourcelist of {
      name : string;
      drive_name : string;
      tests : test list;
      options : option_ list;
      extra_include : string;
      function_ : string;
    }
  | Enable_language of { langs : supported_lang list; optional : bool }
  | Enable_testing
  | Export of { name : string }
  | Export_target of { targets : target list }
  | Export_package of { name : string }
  | Export_setup of { name : string }
  | Fltk_wrap_ui of { resulting_library_name : string; sources : source list }
  | Install (* https://cmake.org/cmake/help/latest/command/install.html *)
  | Load_cache_read of {
      directory : directory;
      prefix : string;
      entries : string list;
    }
  | Load_cache of {
      directory : directory;
      exclude : string list;
      include_internals : string list;
    }
  | Project of {
      name : string;
      version : version option;
      description : string option;
      homepage_url : string option;
      languages : string list;
    }
  | Source_group of { name : string; files : string list; regular_exp : string }
  | Source_group_tree of { root : string; prefix : string; files : file list }
  | Try_compile
  | Try_run

(* CTest Commands *)
(* Deprecated Commands *)

type special_dir = {
  source_dir : directory; (* for source code and CMakeLists files*)
  binary_dir : directory; (* also build directory *)
}
