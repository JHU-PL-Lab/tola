(* 
Sandpiper ia a language to describe the essense of entities used in programming 
languages and systems tools. It's a high-level representation for all conceptual
low-level constructs, including files, directories, libraries, executables.

Sandpiper doesn't implement any low-level functionality including compiling a source
file or installing a package. Instead, all functionalities are translated to their real
commands or tool invokings.

real-world thing -> sandpipier -> shell-that-run

*)

open Base
open Tola_std

type cmd = {
  cmd_str : string;
  env : (string * string) list;
  capture : bool;
  expected_ok : bool;
}

open Binding
open Binding.Fs

type binding_lang = Python | OCaml [@@deriving show { with_path = false }]

type entity =
  (* filesystem *)
  | File of File.t
  | Dir of Dir.t
  (* language eco *)
  | Package of Package.t
  (* Pkgm_brew *)
  (* check_compatilibity ... Pkgm_brew ...   *)
  | Library of Structures.library
  | C_Json of File.t
  | C_API of C_utils.c_api_simple
  | Lang_binding of {
      binding_lang : binding_lang;
      pkg : Package.t option;
      ver : string;
    }
  | Project of Structures.project
  (* system-or-c-or-abi eco *)
  | BinaryExecutable of Structures.binary_exe
  | BinaryLibrary of Structures.binary_lib

(* Language constructs *)

type exp =
  (* Primitives *)
  | Have of entity
  | Inspect of entity
  | Ensure_file of File.t * string
  (* structural *)
  | List of exp list
  (* Foreign magic *)
  | ML of (unit -> unit)
  | Cmd of cmd

let print_exists b path =
  if b then Fmt.pr "File %s exists.@." path
  else Fmt.pr "File %s does not exist.@." path

let check_and_return file =
  let b = File.exists file in
  print_exists b file.full_path;
  b

let check_dir_and_return dir =
  let b = Dir.exists dir in
  print_exists b dir.full_path;
  b

let is_existing entity =
  match entity with
  | File file -> check_and_return file
  | C_Json file -> check_and_return file
  | C_API _spec -> failwith "C_API existence check not implemented"
  | Dir dir ->
      let b = Dir.exists dir in
      print_exists b dir.full_path;
      b
  | Package pkg -> Package.exists pkg
  | Library lib -> Sys_unix.file_exists_exn lib.path
  | Project prj ->
      Fmt.pr "Checking project at path: %s@." prj.path;
      Sys_unix.file_exists_exn prj.path
  | BinaryExecutable (Binary_executable path) -> Sys_unix.file_exists_exn path
  | BinaryLibrary (Binary_library { path; _ }) -> Sys_unix.file_exists_exn path
  | Lang_binding { binding_lang; ver; _ } ->
      Fmt.pr "Checking lang binding: %s version %s@."
        (show_binding_lang binding_lang)
        ver;
      true
(* | _ -> failwith "Unsupported entity type for existence check" *)

let inspect entity =
  match entity with
  | Package pkg -> ignore @@ Package.inspect pkg
  | Project prj -> ignore @@ Structures.inspect prj
  | C_Json file ->
      Fmt.pr "Inspecting C JSON file at path: %s@." file.full_path;
      let c_api_info = C_utils.parse_c_api_simple_file file.full_path in
      Fmt.pr "%a" C_utils.pp_short c_api_info;
      write_file "_out/parsed_c_api.json"
        (C_utils.yojson_of_c_api_simple c_api_info |> str_of_yojson);
      ()
  | _ -> ()

let cmd_from_str cmd_str =
  { cmd_str; env = []; capture = true; expected_ok = true }

let rec interp ?(stop_on_error = true) exp : unit =
  match exp with
  | Have entity ->
      let is_existing = is_existing entity in
      Fmt.pr "[Check_exists] %B@." is_existing;
      if stop_on_error && not is_existing then failwith "Entity does not exist."
  | Inspect entity -> inspect entity
  | Ensure_file (file, cmd) ->
      if not (File.exists file) then (
        Fmt.pr "[Ensure_file] Creating file %s@. cmd:%s" file.full_path cmd;
        Tola_cmd.run0 cmd);

      assert (File.exists file)
  | List exps -> List.iter exps ~f:(fun e -> interp e)
  | ML f -> f ()
  | Cmd cmd ->
      (* | Cmd_unit cmd -> Cmd.run0 ~env:cmd.env cmd.cmd_str *)
      Fmt.pr "[Command] %s@." cmd.cmd_str;
      let output, ok = Tola_cmd.run_sb ~env:cmd.env cmd.cmd_str in
      Fmt.pr "[Command][Output]%s@." (* (String.length output) *) output;
      if stop_on_error then
        if Bool.(cmd.expected_ok <> ok) then
          failwith
            (Fmt.str "Command should %B but not: %s" cmd.expected_ok cmd.cmd_str)
(* Fmt.pr "[Command][Result] %B@." (String.length output <> 0) *)

(* helper constructors *)
let hr = ML (fun () -> Fmt.pr "------------------------------------@.")

let hrt sec =
  ML (fun () -> Fmt.pr "------------------%s------------------@." sec)

let dummy = List []

let cmd ?(env = []) ?(capture = true) ?(expected_ok = true) cmd_str =
  Cmd { cmd_str; env; capture; expected_ok }

let cmd0 ?(env = []) cmd_str = cmd ~env ~capture:false cmd_str

(* Check if the opam root is uninitialized *)

let is_uninitialized_opamroot (path : string) : bool =
  not (Sys_unix.file_exists_exn (path $/ "config"))

let with_root root s = Fmt.str "%s/%s" root s

let mk_rt ?root () =
  let root =
    match root with
    | Some r -> r
    | None -> (
        match Std.the_os with
        | Linux -> "/home/ex/code/tola/_pm"
        | Darwin -> "/Users/ex/code/tola/tola/_pm"
        | _ -> failwith "Unsupported OS")
  in
  with_root root

let rt = mk_rt ()

module With_OCaml_switch = struct
  (* let opam_root_str = "OPAMROOT=_pm/opam_root" *)
  let abs_switch_path = rt "ocaml_local"
  let abs_project_path = rt "ocaml_projects"
  let _prefix = Fmt.str "OPAMSWITCH=%s opam var prefix" abs_switch_path
  let prefix = Fmt.str "opam var prefix --switch=%s" abs_switch_path
  let switch_path = "_pm/ocaml_local"
  let compiler_version = "ocaml-base-compiler.5.3.0"
  let out = "_out"
  let out_json = out $/ "solution.json"

  let create_local_switch switch_path =
    Fmt.str "opam switch create %s %s" switch_path compiler_version

  let install_dryrun pname =
    Fmt.str "OPAMSWITCH=%s opam install --dry-run %s" switch_path pname

  let install pname = Fmt.str "opam install --switch=%s -y %s" switch_path pname

  let uninstall pname =
    Fmt.str "opam uninstall --switch=%s -y %s" switch_path pname

  let is_installed pname =
    Fmt.str "opam list --switch=%s --installed --short %s" switch_path pname

  let install_dryrun_json pname =
    Fmt.str "opam install --switch=%s --dry-run -y %s --json=%s" switch_path
      pname out_json

  let exec cmd = Fmt.str "opam exec --switch=%s -- %s" switch_path cmd

  let jq_dryrun_json =
    Fmt.str
      "jq -r '[.solution[] | select(.install) | .install] | sort_by(.name)[] | \
       \"\\(.name) \\(.version)\"' %s"
      out_json
end

module With_OCaml_dune = struct
  let project_root = "_out/ocaml_projects"
  let build_project pid = Fmt.str "dune build --root %s/%s" project_root pid

  let check_project_library pid =
    Fmt.str "test %s/%s/_build/default/META.*" project_root pid
end

module With_shell = struct
  let echo var_str = Fmt.str "echo $%s" var_str
end

module With_filesystem = struct
  let working_dir = "_out/fs"
  let the_file name = File.v working_dir name
  let the_dir name = Dir.v working_dir name

  (* 
  let touch_dir_for_file file =
    let dir = Filename_base.dirname file in
    cmd0 (Fmt.str "mkdir -p %s" dir)
*)

  let touch_file file =
    cmd0 (Fmt.str "mkdir -p %s && touch %s" (File.dirname file) (File.s file))

  let remove_file file = cmd0 (Fmt.str "rm %s" (File.s file))
  let remove_dir dir = cmd0 (Fmt.str "rm -r %s" (Dir.s dir))
  let touch_dir dir = cmd0 (Fmt.str "mkdir -p %s" (Dir.s dir))
end

module With_compiler = struct
  (* or CC or gcc or clang *)
  let cc = "cc"
  let ld = "ld"
  let working_dir = "_out/linkings"
  let build = "build"

  let compile ~srcs ~out ~flags =
    let srcs_str = String.concat ~sep:" " srcs in
    let build_out = build $/ out in
    cmd0
      (Fmt.str "cd %s && mkdir -p %s && %s %s -o %s %s && cd -" working_dir
         (Filename_base.dirname build_out)
         cc flags build_out srcs_str)

  let change_extension file ext =
    let base_name = Filename_base.chop_extension file in
    base_name ^ "." ^ ext

  let c_to_so file = change_extension file "so"
  let c_to_exe file = change_extension file "exe"
end
