open Lang_cmake

(* constructors *)
let version_of_string s =
  Scanf.sscanf s "%d.%d.%s" (fun major minor patch -> { major; minor; patch })

let cmd_of_list cmds = Exp_list cmds

let project ?version ?description ?homepage_url ?(languages = []) name =
  Project { name; version; description; homepage_url; languages }

let string_of_version ver =
  let str_patch = if String.length ver.patch = 0 then "" else "." ^ ver.patch in
  Fmt.str "%d.%d%s" ver.major ver.minor str_patch

let add_executable ?(options = []) ?(sources = []) name =
  Add_executable { name; options; sources }

(* pretty print *)

let pp_source ff s = Fmt.string ff s

let rec pp ff e =
  match e with
  | Int i -> Fmt.int ff i
  | String s -> Fmt.string ff s
  | Cmake_cmd cmd -> pp_cmake_cmd ff cmd
  | Exp_list exps -> (Fmt.list pp) ff exps
  | Project_cmd cmd -> pp_project_cmd ff cmd
  | _ -> Fmt.string ff "// not yet@."

and pp_cmake_cmd ff cmd =
  match cmd with
  | Cmake_minimum_required { min; max = _ } ->
      Fmt.pf ff "cmake_minimum_required(VERSION %s)" (string_of_version min)
  | _ -> Fmt.string ff "// not yet@."

and pp_project_cmd ff cmd =
  match cmd with
  | Project { name; _ } -> Fmt.pf ff "project(%a)" Fmt.string name
  | Add_executable { name; options = _; sources } ->
      Fmt.(pf ff "add_executable(%a %a)" string name (list pp_source) sources)
  | _ -> Fmt.string ff "// not yet@."
