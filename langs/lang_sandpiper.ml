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

module Target_triple = struct
  type os = Linux | MacOS | Windows | BSD | Other_os of string

  type distro =
    | Debian
    | Ubuntu
    | Fedora
    | Arch
    | Alpine
    | MacOS_Brew
    | MacOS_Macports
    | Windows_MSYS
    | Windows_Mingw
    | Windows_Msvc
    | Unknown_distro of string

  type arch = X86_64 | Aarch64 | Armv7 | Riscv64 | Other_arch of string
  type t = { os : os; distro : distro; arch : arch }
end

let this_machine = Target_triple.{ os = Linux; distro = Ubuntu; arch = X86_64 }

(* language essentials *)
type language = OCaml | Binary | Placeholder_fs

(* language optionals *)
type project = {
  path : path;
  name : name;
  language : language;
  triple : Target_triple.t option;
}

open Resolve

type library = {
  path : path;
  name : name;
  version : version;
  language : language;
  triple : Target_triple.t option;
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
  triple : Target_triple.t option;
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

let cmd ?(env = []) ?(capture = true) cmd_str = Cmd { cmd_str; env; capture }
let cmd0 ?(env = []) cmd_str = cmd ~env ~capture:false cmd_str

(* Check if the opam root is uninitialized *)

let is_uninitialized_opamroot (path : string) : bool =
  not (Sys_unix.file_exists_exn (path $/ "config"))
