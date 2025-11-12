[@@@warning "-32"]
[@@@warning "-33"]
[@@@warning "-26"]

open Base
open Langs.Lang_sandpiper
open Tola_std
open OpamStd.Sys
open Binding.Fs
open With_OCaml_switch
open With_OCaml_dune
open With_shell
open With_filesystem

(* file and dir examples *)
let file_a = the_file "a.txt"
let dir_a = the_dir "a_dir"

let file_example =
  List
    [
      hrt "files";
      Check_exists (File file_a);
      touch_file file_a;
      Check_exists (File file_a);
      remove_file file_a;
    ]

let dir_example =
  List
    [
      hrt "directory";
      Check_exists (Dir dir_a);
      touch_dir dir_a;
      Check_exists (Dir dir_a);
      remove_dir dir_a;
    ]

let link_example =
  let open With_compiler in
  let add_c = "libadd/libadd.c" in
  let add_so = c_to_so add_c in
  let sum_c = "libsum/libsum.c" in
  let sum_so = c_to_so sum_c in
  let main_c = "bin/main.c" in
  let main_exe = c_to_exe main_c in

  let abs_build =
    Dir.v working_dir "build"
    (* (working_dir $/ "build") *)
  in
  List
    [
      hrt "linking";
      remove_dir abs_build;
      touch_dir abs_build;
      Check_exists (File (File.v working_dir add_c));
      Check_exists (File (Dir.cons_file abs_build add_so));
      compile ~srcs:[ add_c ] ~out:add_so ~flags:"-shared";
      compile ~srcs:[ sum_c ] ~out:sum_so ~flags:"-shared";
      Check_exists (File (Dir.cons_file abs_build add_so));
      (* for gnu/ld: -Wl,-verbose; for mold: -Wl,--trace *)
      compile ~srcs:[ main_c ] ~out:main_exe
        ~flags:"-Lbuild/libadd -ladd -Lbuild/libsum -lsum";
      cmd (Dir.s abs_build $/ main_exe);
    ]

(* opam *)

let _ = "opam switch create _out/ocaml_local 5.3.0"
let local_switch_env = "opam env --switch=/home/ex/code/tola/_out/ocaml_local"

let opam_example =
  List
    [
      Check_exists (File (File.v "." "example.txt"));
      cmd "opam var prefix";
      cmd prefix;
      (* cmd (install_dryrun_json "irmin"); *)
      (* cmd jq_dryrun_json; *)
      cmd0 (is_installed "hashcons");
      cmd (uninstall "hashcons");
      cmd0 (is_installed "hashcons");
    ]

let br = List [ hr ]

(* let z3_opam_example1 = List []
let z3_opam_example2 = List []
let z3_each_for_ocaml_example = List []
let z3_system_ocaml_example = List [] *)
let dune_example = List []
(* cmd ~env:[ ("OCAMLPATH", abs_project_path) ] (echo "OCAMLPATH");
         cmd (build_project "song_std_1_0"); *)
(*cmd (build_project "song_std_2_0"); *)
(* cmd (build_project "song_foo_1_0_nobound"); *)
(* cmd (build_project "song_foo_1_0_vendored"); *)
(* cmd (build_project "song_foo_1_0_workspace"); *)

let z3_example1 =
  List
    [ hrt "z3 example 1"; cmd "z3 --version"; cmd "z3 -in <<< '(check-sat)'" ]

let () =
  let example =
    match Stdlib.Sys.argv.(1) with
    | "z3_1" -> z3_example1
    | "file" -> file_example
    | "dir" -> dir_example
    | "link" -> link_example
    | "opam" -> opam_example
    | "dune" -> dune_example
    | "br" -> br
    | _ ->
        Fmt.pr "No example selected.@.";
        dummy
  in
  interp example

(* dune *)

(* 
OPAMSWITCH=/home/ex/code/tola/_out/ocaml_local opam install ansi

eval $(opam env --switch=/home/ex/code/tola/_out/ocaml_local) && ocamlc -where

[lint]
opam lint --strict _out/ocaml_remote/repo

[[remote]]
opam remote = opam repository 
[list]
opam remote --switch=_out/ocaml_local list
opam remote --all list

[add/remove]

opam remote add --short --switch=_out/ocaml_local --kind=local opam_local_store _out/ocaml_remote
opam remote remove --short --switch=_out/ocaml_local opam_local_store
opam remote remove --short --all opam_local_store
*)
