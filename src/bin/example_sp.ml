[@@@warning "-32"]
[@@@warning "-33"]
[@@@warning "-26"]

open Base
open Langs.Lang_sandpiper
open Tola_std
open OpamStd.Sys
open With_OCaml_switch
open With_OCaml_dune
open With_shell
open With_filesystem
open Binding
open Binding.Fs

(* file and dir examples *)
let file_a = the_file "a.txt"
let dir_a = the_dir "a_dir"

let file_example =
  List
    [
      hrt "files";
      Have (File file_a);
      touch_file file_a;
      Have (File file_a);
      remove_file file_a;
    ]

let dir_example =
  List
    [
      hrt "directory";
      Have (Dir dir_a);
      touch_dir dir_a;
      Have (Dir dir_a);
      remove_dir dir_a;
    ]

(* ocaml_prj 
 dune build ocaml_prj : input ocaml_prj, output findlib_library + dot_opam_spec

let project = ocaml_prj in
let build_result = Build_dune project in
let _ = check build_result

*)

(* pay attention of abstract

dryrun

ocamlmklib -custom -dynamic
*)
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
      Have (File (File.v working_dir add_c));
      Have (File (Dir.cons_file abs_build add_so));
      compile ~srcs:[ add_c ] ~out:add_so ~flags:"-shared";
      compile ~srcs:[ sum_c ] ~out:sum_so ~flags:"-shared";
      Have (File (Dir.cons_file abs_build add_so));
      (* for gnu/ld: -Wl,-verbose; for mold: -Wl,--trace *)
      compile ~srcs:[ main_c ] ~out:main_exe
        ~flags:"-Lbuild/libadd -ladd -Lbuild/libsum -lsum";
      cmd (Dir.s abs_build $/ main_exe);
    ]

let opam_example =
  List
    [
      Have (File (File.v "." "example.txt"));
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

let opam_switch_example =
  let _create = "opam switch create _out/ocaml_local 5.4.0" in
  let _apply = "opam env --switch=/home/ex/code/tola/_out/ocaml_local" in
  (* print and also run the real env var binding
    It's short for `opam config env --switch=<switch>`
    *)
  List
    [
      hrt "OCaml switch example";
      hrt "opam switch cmds";
      cmd "opam switch show";
      cmd "opam switch 5.3.0";
      cmd "opam switch show";
      cmd "opam switch 5.4.0";
      cmd "opam switch show";
      hrt "OPAMSWITCH env cmds";
      cmd ~env:[ ("OPAMSWITCH", "5.3.0") ] "opam switch show";
      cmd ~env:[ ("OPAMSWITCH", "5.3.0") ] "opam var prefix";
      cmd ~env:[ ("OPAMSWITCH", "5.4.0") ] "opam switch show";
    ]

let z3_opam_pkg_example =
  let z3_pkg =
    Package.
      {
        name = "z3";
        version = "dev";
        kind = Opam { switch = "5.4.0"; prefix = Opam.prefix "5.4.0" };
      }
  in
  List
    [
      hrt "z3 example 1";
      Have (Package z3_pkg);
      Inspect (Package z3_pkg);
      hrt "All Succeed";
    ]

let z3_src_path = "/home/ex/code/ocaml-build-examples/vendor/z3"

let z3_source_project =
  let open Binding.Structures in
  Project
    {
      path = z3_src_path;
      name = "z3_src";
      platform = None;
      primary_lang = Cpp;
      build_system = CMake;
    }

let z3_c_api_raw = File (File.v z3_src_path "src/api/c")
(* let open Binding.Structures in
  C_API { header_path = z3_src_path $/ "src/api/c"; source = ""; defs = [] } *)

let z3_c_json = C_Json (File.v "." "_out/z3_h.json")

let z3_src_example =
  List
    [
      hrt "z3 build";
      Have z3_source_project;
      Inspect z3_source_project;
      Have z3_c_json;
      Inspect z3_c_json;
    ]

let () =
  Fmt.set_style_renderer Fmt.stdout `Ansi_tty;
  let example =
    match Stdlib.Sys.argv.(1) with
    | "z3_1" -> z3_opam_pkg_example
    | "z3_src" -> z3_src_example
    | "switch" -> opam_switch_example
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
