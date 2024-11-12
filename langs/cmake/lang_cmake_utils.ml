open Lang_cmake

let version_of_string s =
  Scanf.sscanf s "%d.%d.%s" (fun major minor patch -> { major; minor; patch })

let string_of_version ver =
  let str_patch = if String.length ver.patch = 0 then "" else "." ^ ver.patch in
  Fmt.str "%d.%d%s" ver.major ver.minor str_patch

let str_ s = Val_var s
let quote s = Val_str s
let bool_ b = Val_bool b
let ivar v = Item_var v
let istr s = Item_str s
let target_def ?(kind = Public) items = { kind; items }
let target_feature ?(kind = Public) feature = { kind; feature }
let cmd_of_list cmds = Exp_list cmds

let ite cond then_ ?else_ () =
  match else_ with
  | None -> If { cond; then_; else_ = None }
  | Some else_ -> If { cond; then_; else_ = Some else_ }

let ifthen cond then_ = ite cond then_ ()
let if_ cond then_ else_ = ite cond then_ ~else_ ()
let function_ name args cmds = Function { name; args; cmds }
let apply name args = Apply { name; args }

let minimum_required_s ?max min =
  Cmake_cmd
    (Cmake_minimum_required
       { min = version_of_string min; max = Option.map version_of_string max })

let project ?version ?description ?homepage_url ?(languages = []) name =
  Project_cmd (Project { name; version; description; homepage_url; languages })

let option_ ?(value = bool_ false) ~msg var = Cmake_option { var; msg; value }

let add_library ?(exclude_from_all = false) ?type_ ?(sources = []) name =
  Project_cmd (Add_library { name; type_; exclude_from_all; sources })

let add_executable ?(options = []) ?(sources = []) name =
  Project_cmd (Add_executable { name; options; sources })

let configure_file ?(permissions = []) ?permission_level ?copy_only
    ?escape_quotes ?only ?newline_style ~input output =
  Cmake_cmd
    (Configure_file
       {
         input;
         output;
         permission_level;
         permissions;
         copy_only;
         escape_quotes;
         only;
         newline_style;
       })

let set ?(parent_scope = false) var values = Set { var; values; parent_scope }

let add_subdirectory ?binary_dir ?(exclude_from_all = false) ?(system = false)
    source_dir =
  Project_cmd
    (Add_subdirectory { source_dir; binary_dir; exclude_from_all; system })

let target_compile_definitions target items =
  Project_cmd (Target_compile_definitions { target; items })

let target_compile_features target features =
  Project_cmd (Target_compile_features { target; features })

let target_compile_options ?(before = false) target items =
  Project_cmd (Target_compile_options { target; before; items })

let target_include_directories ?system ?before_or_after target items =
  Project_cmd
    (Target_include_directories { target; system; before_or_after; items })

let target_link_libraries targets items =
  Project_cmd (Target_link_libraries { targets; items })

let install_targets ?component ?rename ?export_name ?(permissions = []) targets
    destination =
  Project_cmd
    (Install_targets
       { targets; destination; permissions; component; rename; export_name })

let install_files ?component ?rename ?(permissions = []) files destination =
  Project_cmd
    (Install_files { files; destination; permissions; component; rename })

(* testing *)
let enable_testing = Project_cmd Enable_testing

let add_test ?dir name command args =
  Project_cmd (Add_test { name; command; args; dir })

let set_tests_properties ?dir tests prop_value_pairs =
  let properties =
    List.map (fun (prop, value) -> { prop; value }) prop_value_pairs
  in
  Project_cmd (Set_tests_properties { tests; dir; properties })
