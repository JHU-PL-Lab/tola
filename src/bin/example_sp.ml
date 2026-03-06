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
let dune_example = List []

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
    Binding.Package.
      {
        name = "z3";
        version = "dev";
        kind = Opam { switch = "5.4.0"; prefix = Binding.Opam.prefix "5.4.0" };
      }
  in
  List
    [
      hrt "z3 example 1";
      Have (Package z3_pkg);
      Inspect (Package z3_pkg);
      hrt "All Succeed";
    ]

(* Z3 notes
The previous release has no corresponding tag
745087e is the commit for Z3 4.8.15 release

git -c advice.detachedHead=false checkout 745087e

*)

[@@@warning "-69"]

open Canary_basic
open Canary_project_z3

let mk_z3_src_example () =
  let distro = detect_distro () in
  let z3_dev_instance = z3_dev_instance_of_distro distro in
  let z3_dev_spec = z3_dev_spec distro in
  let open Canary_basic_ocaml in
  let z3_binding_project =
    let open Binding.Structures in
    Project
      {
        path = z3_dev_instance.root;
        name = "z3_" ^ z3_dev_spec.version;
        platform = None;
        primary_lang = Cpp;
        build_system = CMake;
      }
  in
  let z3_c_json = File.v "." (out_h_json z3_dev_spec.version) in
  let cmd_c_header_to_json =
    clang_header_parse (z3_dev_instance.root $/ "src/api") (File.s z3_c_json)
  in
  let lib_built = File.abs (lib_so_path z3_dev_instance.root) in
  [
    hrt @@ "z3 source for " ^ z3_dev_spec.version;
    Have z3_binding_project;
    Inspect z3_binding_project;
    Ensure_file (z3_c_json, cmd_c_header_to_json);
    Have (C_Json z3_c_json);
    Inspect (C_Json z3_c_json);
    Have (File lib_built);
    hrt @@ "build output";
    Cmd
      (cmd_from_str
         (Fmt.str "cd %s && %s" z3_dev_instance.root binding_buildgen));
    Cmd
      (cmd_from_str (Fmt.str "cd %s && %s" z3_dev_instance.root binding_build));
  ]

let z3_src_example () = List (mk_z3_src_example ())

let mk_z3_pkg_example () =
  let distro = detect_distro () in
  let z3_dev_instance = z3_dev_instance_of_distro distro in
  let z3_dev_spec = z3_dev_spec distro in
  let z3_binding_project =
    let open Binding.Structures in
    Project
      {
        path = z3_dev_instance.root;
        name = "z3_" ^ z3_dev_spec.version;
        platform = None;
        primary_lang = Cpp;
        build_system = CMake;
      }
  in
  [
    hrt "Z3 pkg example";
    Have z3_binding_project;
    Inspect z3_binding_project;
    Cmd
      (cmd_from_str
         (Fmt.str "cd %s && %s" z3_dev_instance.root
            (binding_buildgen_use_external z3_dev_instance.external_libz3)));
    Cmd
      (cmd_from_str (Fmt.str "cd %s && %s" z3_dev_instance.root binding_build));
  ]

let z3_pkg_example () = List (mk_z3_pkg_example ())

let () =
  Fmt.set_style_renderer Fmt.stdout `Ansi_tty;
  match Stdlib.Sys.argv.(1) with
  | "canary" -> Canary_run.run (Canary_basic.detect_distro ())
  | "canary_local" -> Canary_run.run_local (detect_distro ())
  | "canary_dump" -> Canary_run.dump (detect_distro ())
  | "z3_1" -> interp z3_opam_pkg_example
  | "z3_src" -> interp (z3_src_example ())
  | "z3_pkg" -> interp (z3_pkg_example ())
  | "switch" -> interp opam_switch_example
  | "file" -> interp file_example
  | "dir" -> interp dir_example
  | "link" -> interp link_example
  | "opam" -> interp opam_example
  | "dune" -> interp dune_example
  | "br" -> interp br
  | _ ->
      Fmt.pr "No example selected.@.";
      interp dummy
