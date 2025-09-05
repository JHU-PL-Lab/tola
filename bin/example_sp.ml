[@@@warning "-32"]
[@@@warning "-33"]
[@@@warning "-26"]

open Base
open Langs.Lang_sandpiper
open Tola_std
open Tola_std.Std.File_infix

let opam_root_str = "OPAMROOT=_pm_root/opam_root"
let _ = "opam switch create _pm_root/ocaml_local ocaml-base-compiler.5.3.0"

let local_switch_env =
  "opam env --switch=/home/ex/code/tola/_pm_root/ocaml_local"

(* dune *)

(* 
OPAMSWITCH=/home/ex/code/tola/_pm_root/ocaml_local opam install ansi

eval $(opam env --switch=/home/ex/code/tola/_pm_root/ocaml_local) && ocamlc -where

[lint]
opam lint --strict _pm_root/ocaml_remote/repo

[[remote]]
opam remote = opam repository 
[list]
opam remote --switch=_pm_root/ocaml_local list
opam remote --all list

[add/remove]

opam remote add --short --switch=_pm_root/ocaml_local --kind=local opam_local_store _pm_root/ocaml_remote
opam remote remove --short --switch=_pm_root/ocaml_local opam_local_store
opam remote remove --short --all opam_local_store
*)

module With_switch = struct
  let abs_switch_path = "/home/ex/code/tola/_pm_root/ocaml_local"
  let abs_project_path = "/home/ex/code/tola/_pm_root/ocaml_projects"
  let switch_path = "_pm_root/ocaml_local"
  let compiler_version = "ocaml-base-compiler.5.3.0"
  let temp = "_out"
  let temp_json = temp $/ "solution.json"
  let prefix = Fmt.str "OPAMSWITCH=%s opam var prefix" abs_switch_path
  let prefix = Fmt.str "opam var prefix --switch=%s" abs_switch_path

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
      pname temp_json

  let exec cmd = Fmt.str "opam exec --switch=%s -- %s" switch_path cmd

  let jq_dryrun_json =
    Fmt.str
      "jq -r '[.solution[] | select(.install) | .install] | sort_by(.name)[] | \
       \"\\(.name) \\(.version)\"' %s"
      temp_json
end

open With_switch

module With_dune = struct
  let project_root = "_pm_root/ocaml_projects"
  let build_project pid = Fmt.str "dune build --root %s/%s" project_root pid
  let check_project_library pid =
    Fmt.str "test %s/%s/_build/default/META.*" project_root pid
end

open With_dune

module With_shell = struct
  let echo var_str = Fmt.str "echo $%s" var_str
end

open With_shell

module With_filesystem = struct
  let working_dir = "_pm_root/fs"
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

open With_filesystem

module With_compiler = struct
  (* or CC or gcc or clang *)
  let cc = "cc"
  let ld = "ld"
  let working_dir = "_pm_root/linkings"
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

let file_a = the_file "a.txt"
let dir_a = the_dir "a_dir"
let hr = ML (fun () -> Fmt.pr "------------------------------------@.")

let hrt sec =
  ML (fun () -> Fmt.pr "------------------%s------------------@." sec)

(* let () =
  interp
    (List
       [
         hrt "files";
         Check_exists (File file_a);
         touch_file file_a;
         Check_exists (File file_a);
         remove_dir file_a;
       ])

let () =
  interp
    (List
       [
         hrt "directory";
         Check_exists (Directory dir_a);
         touch_dir dir_a;
         Check_exists (Directory dir_a);
         remove_dir dir_a;
       ]) *)

let () =
  let open With_compiler in
  let add_c = "libadd/libadd.c" in
  let add_so = c_to_so add_c in
  let sum_c = "libsum/libsum.c" in
  let sum_so = c_to_so sum_c in
  let main_c = "bin/main.c" in
  let main_exe = c_to_exe main_c in
  interp
    (List
       [
         hrt "linking";
         remove_dir abs_build;
         touch_dir abs_build;
         Check_file (working_dir $/ add_c);
         Check_file (abs_build $/ add_so);
         compile ~srcs:[ add_c ] ~out:add_so ~flags:"-shared";
         compile ~srcs:[ sum_c ] ~out:sum_so ~flags:"-shared";
         Check_file (abs_build $/ add_so);
         (* for gnu/ld: -Wl,-verbose; for mold: -Wl,--trace *)
         compile ~srcs:[ main_c ] ~out:main_exe
           ~flags:"-Lbuild/libadd -ladd -Lbuild/libsum -lsum";
         cmd (abs_build $/ main_exe);
       ])

let () =
  (* interp
    (List
       [
         cmd "echo $0";
         Check_file "example.txt";
         (* cmd0 "ls -l"; *)
         cmd "opam var prefix";
         cmd prefix;
         (* cmd (install_dryrun_json "irmin"); *)
         (* cmd jq_dryrun_json; *)
         cmd_nonempty (is_installed "hashcons");

         cmd_nonempty (is_installed "hashcons");
         cmd (uninstall "hashcons");
         cmd_nonempty (is_installed "hashcons");
       ]) *)
  ()

(* cmd (create_local_switch switch_path); *)

(* let () =
  interp
    (List
       [
         cmd "opam var prefix";
         cmd prefix;
         cmd (install "hashcons");
         cmd (exec "ocamlc -where");
       ]) *)

(* cmd ~env:[ ("OCAMLPATH", abs_project_path) ] (echo "OCAMLPATH");
         cmd (build_project "song_std_1_0"); *)
(*cmd (build_project "song_std_2_0"); *)
(* cmd (build_project "song_foo_1_0_nobound"); *)
(* cmd (build_project "song_foo_1_0_vendored"); *)
(* cmd (build_project "song_foo_1_0_workspace"); *)
