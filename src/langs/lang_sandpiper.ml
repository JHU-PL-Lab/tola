open Base
open Tola_std
open Tola_std.Std.File_infix

type cmd = { cmd_str : string; env : (string * string) list; capture : bool }
type name = string
type version = string

(* Filetree essentials
Usually, a path is an entity usually identified by a string
while its property can be is_file, is_dir, or filetrees
We can also use the reversed concept that a file, a dir, or a filetress locating as a path,
which means they can have other forms.
*)

type path = string

open Binding

let this_machine = Platform.{ os = Linux; distro = Ubuntu; arch = X86_64 }

(* language essentials *)
type language = OCaml | Binary | Placeholder_fs

(* language optionals *)
type project = {
  path : path;
  name : name;
  language : language;
  platform : Platform.t option;
}

open Resolve

type library = {
  path : path;
  name : name;
  version : version;
  language : language;
  platform : Platform.t option;
  bind_spec : Resolve_strategy.t;
}

(* Binary is a language/system format *)
type binary_exe = Binary_executable of path
type binary_lib = Binary_library of { path : path; shared : bool }
type package_kind = Opam | Tola_ml | Placeholder_fs

(* package name *)

(* package managers *)
type package = {
  name : name;
  version : version;
  library : library;
  platform : Platform.t option;
}

(* three models
1. Placeholder files
2. OCaml (containing opam package and tola-ml-package)
3. Binary
*)

type entity =
  (* filesystem *)
  | File of path
  | Directory of path
  | FileTree of path
  (* language eco *)
  | Library of library
  | Project of project
  (* system-or-c-or-abi eco *)
  | BinaryExecutable of binary_exe
  | BinaryLibrary of binary_lib

(* Language constructs *)

type exp =
  (* structural *)
  | List of exp list
  | ML of (unit -> unit)
  (* File *)
  | Check_file of string
  (* Command *)
  | Cmd of cmd
  (* Checking *)
  | Check_exists of entity

let rec interp exp : unit =
  match exp with
  | List exps -> List.iter exps ~f:(fun e -> interp e)
  | ML f -> f ()
  | Check_file path ->
      if Sys_unix.file_exists_exn path then Fmt.pr "File %s exists.\n" path
      else Fmt.pr "File %s does not exist.\n" path
  | Cmd cmd ->
      (* | Cmd_unit cmd -> Std.Sys_util.run ~env:cmd.env cmd.cmd_str *)
      Fmt.pr "[Command] %s\n" cmd.cmd_str;
      let output = Std.Sys_util.run_and_capture ~env:cmd.env cmd.cmd_str in
      Fmt.pr "[Command][Output] [%d]%s\n" (String.length output) output
      (* Fmt.pr "[Command][Result] %B\n" (String.length output <> 0) *)
  | Check_exists entity ->
      let is_existing =
        match entity with
        | File path -> Sys_unix.file_exists_exn path
        | Directory path -> Sys_unix.is_directory_exn path
        | FileTree path -> Sys_unix.is_directory_exn path
        | Library lib -> Sys_unix.file_exists_exn lib.path
        | Project prj -> Sys_unix.file_exists_exn prj.path
        | BinaryExecutable (Binary_executable path) ->
            Sys_unix.file_exists_exn path
        | BinaryLibrary (Binary_library { path; _ }) ->
            Sys_unix.file_exists_exn path
        (* | _ -> failwith "Unsupported entity type for existence check" *)
      in
      Fmt.pr "[Check_exists] %B\n" is_existing

(* helper constructors *)
let hr = ML (fun () -> Fmt.pr "------------------------------------@.")

let hrt sec =
  ML (fun () -> Fmt.pr "------------------%s------------------@." sec)

let dummy = List []
let cmd ?(env = []) ?(capture = true) cmd_str = Cmd { cmd_str; env; capture }
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
  let project_root = "_pm/ocaml_projects"
  let build_project pid = Fmt.str "dune build --root %s/%s" project_root pid

  let check_project_library pid =
    Fmt.str "test %s/%s/_build/default/META.*" project_root pid
end

module With_shell = struct
  let echo var_str = Fmt.str "echo $%s" var_str
end

module With_filesystem = struct
  let working_dir = "_pm/fs"
  let the_file name = working_dir $/ name
  let the_dir name = working_dir $/ name
  (* let touch_file file = cmd0 (Fmt.str "touch %s" file) *)

  let touch_file file =
    let dir = Filename_base.dirname file in
    cmd0 (Fmt.str "mkdir -p %s && touch %s" dir file)

  let touch_dir_for_file file =
    let dir = Filename_base.dirname file in
    cmd0 (Fmt.str "mkdir -p %s" dir)

  let remove_file file = cmd0 (Fmt.str "rm %s" file)
  let remove_dir dir = cmd0 (Fmt.str "rm -r %s" dir)
  let touch_dir dir = cmd0 (Fmt.str "mkdir -p %s" dir)
end

module With_compiler = struct
  (* or CC or gcc or clang *)
  let cc = "cc"
  let ld = "ld"
  let working_dir = "_pm/linkings"
  let build = "build"
  let abs_build = working_dir $/ "build"

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
