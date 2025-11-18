open Base

(* open Tola_std *)
open Resolve

type name = string
type version = string
type path = string
type instance = { path : path; platform : Platform.t }

(* Binary is a language/system format *)
type binary_exe = Binary_executable of path
type binary_lib = Binary_library of { path : path; shared : bool }

(* language optionals *)
type project = { path : path; name : name; platform : Platform.t option }

type library = {
  path : path;
  name : name;
  version : version;
  platform : Platform.t option;
  bind_spec : Resolve_strategy.t;
}

(* belong to which language 

(* language essentials *)
type language = OCaml | Binary | Placeholder_fs

*)

(* 
  how to diffierentiate a package and a package at a place?
  A package should have an interal property and external presences.
  Saying we have two copies package with separate physical entities. What they share is the internal property, and what they differ is the physical presence.

  How to differentiate a package at a path freely, or a package inside of a pkgm?
*)

(* three models
1. Placeholder files
2. OCaml (containing opam package and tola-ml-package)
3. Binary
*)

(* envir...entity *)
(* 
  | Upstream_project
  | C_binding of library

FFI...
  z3_lib c++ (datatype)
  header_c (api_datatype) (v1, v2, v3)
  ocaml_binding(ocaml code) , python_binding(), java_binding

  symbol exist or not
*)

(* EDSL *)

(* owl ... macOS ...

pkgconfig .... homebrew ... ..-fopenmp
clang in apple, doesn't support -fopenmp

let pkg_openblas = Pkgm_brew.get in
(* post_condition/pre_condtion *)
let result = check_compatilibity pkg_openblas ~os:mac in

(* support_flags_list = {
 mac_os_ 'clang':

} *)

*)
