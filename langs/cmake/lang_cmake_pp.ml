open Lang_cmake
open Lang_cmake_utils

let list_sp pp = Fmt.list ~sep:Fmt.sp pp
let list_br pp = Fmt.list ~sep:Fmt.cut pp
let quoted s = "\"" ^ s ^ "\""
let pp_quoted = Fmt.using quoted Fmt.string

let pp_with_key key pp_ele ff = function
  | None -> ()
  | Some ele -> Fmt.pf ff "%s %a " key pp_ele ele

let pp_version_opt ff = function
  | None -> ()
  | Some ver -> Fmt.pf ff "VERSION %s" (string_of_version ver)

let pp_cond ff = function
  | Cond_var s -> Fmt.string ff s
  | Cond_str s -> pp_quoted ff s
  | Is_target t -> Fmt.pf ff "TARGET %a" Fmt.string t
  | _ -> Fmt.string ff "not yet (cond)"

let pp_target ff (Target s) = Fmt.string ff s
let pp_source ff s = Fmt.string ff s
let pp_var ff (Var s) = Fmt.string ff s
let pp_string_quoted ff msg = Fmt.string ff (quoted msg)
let pp_message = pp_string_quoted

let pp_item ff = function
  | Item_var var -> Fmt.string ff var
  | Item_str s -> pp_string_quoted ff s

let string_of_value = function
  | Val_var s -> s
  | Val_str s -> quoted s
  | Val_bool true -> "True"
  | Val_bool false -> "False"

let pp_val = Fmt.using string_of_value Fmt.string

let string_on_of_value = function
  | Val_var s -> s
  | Val_str s -> quoted s
  | Val_bool true -> "ON"
  | Val_bool false -> "OFF"

let pp_val_on = Fmt.using string_on_of_value Fmt.string

let pp_property ff { prop; value } =
  Fmt.(pf ff "%a %a" string prop pp_val value)

let string_of_library_type = function
  | Lib_shared -> "SHARED"
  | Lib_static -> "STATIC"
  | Lib_module -> "MODULE"
  | Lib_unknown -> "UNKNOWN"
  | Lib_object -> "OBJECT"
  | Lib_interface -> "INTERFACE"
  | Lib_global -> "GLOBAL"

let pp_lib_type = Fmt.using string_of_library_type Fmt.string

let pp_parent_scope =
  Fmt.using (fun ps -> if ps then "PARENT_SCOPE" else "") Fmt.string

let string_of_kind = function
  | Interface -> "INTERFACE"
  | Public -> "PUBLIC"
  | Private -> "PRIVATE"

let pp_target_kind = Fmt.using string_of_kind Fmt.string

let pp_items_with_kind ff ({ kind; items } : items_with_kind) =
  Fmt.pf ff "%a %a" pp_target_kind kind (list_sp pp_item) items

let pp_feature ff (Feature s) = Fmt.string ff s

let pp_target_feature ff ({ kind; feature } : target_feature) =
  Fmt.pf ff "%a %a" pp_target_kind kind pp_feature feature

let rec pp ff e =
  match e with
  (* syntactic *)
  | Int i -> Fmt.int ff i
  | Var_exp s -> Fmt.string ff s
  | Exp_list exps -> (list_sp pp) ff exps
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
  | Apply { name; args } ->
      Fmt.(pf ff "%a(%a)@." pp_var name (list_sp pp_val) args)
  (* cmake commands *)
  (* primitives *)
  | Cmake_option { var; msg; value } ->
      Fmt.(pf ff "option(%a %a %a)" pp_var var pp_message msg pp_val_on value)
  | Set { var; values; parent_scope } ->
      Fmt.(
        pf ff "set(%a %a %a)" pp_var var (list_sp pp_val) values pp_parent_scope
          parent_scope)
  | Cmake_cmd cmd -> (Fmt.box pp_cmake_cmd) ff cmd
  | Project_cmd cmd -> (Fmt.box pp_project_cmd) ff cmd
  | _ -> Fmt.string ff "// not yet@."

and pp_cmake_cmd ff cmd =
  match cmd with
  | Cmake_minimum_required { min; max = _ } ->
      Fmt.pf ff "cmake_minimum_required(VERSION %s)" (string_of_version min)
  | Configure_file { input; output; _ } ->
      Fmt.pf ff "configure_file(%a %a)" Fmt.string input Fmt.string output
  | _ -> Fmt.string ff "// not yet@."

and pp_project_cmd ff cmd =
  match cmd with
  | Project { name; version; _ } ->
      Fmt.pf ff "project(%a %a)" Fmt.string name pp_version_opt version
  | Add_executable { name; options = _; sources } ->
      Fmt.(
        pf ff "add_executable(%a %a)" string name (list_sp pp_source) sources)
  | Add_subdirectory { source_dir; _ } ->
      Fmt.pf ff "add_subdirectory(%a)" Fmt.string source_dir
  | Add_library { name; sources; type_; _ } ->
      Fmt.(
        pf ff "add_library(%a %a %a)" string name (option pp_lib_type) type_
          (list_sp pp_source) sources)
  | Target_compile_definitions { target; items } ->
      Fmt.(
        pf ff "target_compile_definitions(%a %a)" pp_target target
          (list_sp pp_items_with_kind)
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
          (list_sp pp_items_with_kind)
          items)
  | Target_link_libraries { targets; items } ->
      Fmt.(
        pf ff "target_link_libraries(%a %a)" (list_sp pp_target) targets
          (list_sp pp_items_with_kind)
          items)
  | Target_include_directories { target; items; _ } ->
      Fmt.(
        pf ff "target_include_directories(%a @[<2>%a@])" pp_target target
          (list_sp pp_items_with_kind)
          items)
  | Enable_testing -> Fmt.(pf ff "enable_testing()")
  | Add_test { name; command; args; dir } ->
      Fmt.(
        pf ff "add_test(NAME %a COMMAND %a %a%a)" string name string command
          (list_sp string) args
          (pp_with_key "WORKING_DIRECTORY" string)
          dir)
  | Set_tests_properties { tests; dir; properties } ->
      Fmt.(
        pf ff "set_tests_properties(%a%a PROPERTIES %a)" (list_sp string) tests
          (pp_with_key "WORKING_DIRECTORY" string)
          dir (list_sp pp_property) properties)
  | Install_targets { targets; destination; _ } ->
      Fmt.(
        pf ff "install(TARGETS %a@[<2>@;DESTINATION %a@])" (list_sp pp_target)
          targets pp_item destination)
  | Install_files { files; destination; _ } ->
      Fmt.(
        pf ff "install(FILES %a@[<2>@;DESTINATION %a@])" (list_sp pp_item) files
          pp_item destination)
  | _ -> Fmt.string ff "// not yet@."
