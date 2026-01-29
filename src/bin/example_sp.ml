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

(* Z3 notes
The previous release has no corresponding tag
745087e is the commit for Z3 4.8.15 release

git -c advice.detachedHead=false checkout 745087e

*)

[@@@warning "-69"]

type src_info = {
  root : string;
  c_header_path : string;
  version : string;
  commit : string;
}

(* clang -fsyntax-only -Xclang -ast-dump=json -I/home/ex/code/ocaml-build-examples/vendor/z3/src/api /home/ex/code/ocaml-build-exa
mples/vendor/z3/src/api/z3.h > _out/z3_h_dd.json *)

(* 
clang -E -dI -P -I/home/ex/code/ocaml-build-examples/vendor/z3/src/api /home/ex/code/ocaml-build-examples/vendor/z3/src/api/z3_api.h > _out/z3_api_h.i
clang -E -dI -P -I/home/ex/code/ocaml-build-examples/vendor/z3/src/api /home/ex/code/ocaml-build-examples/vendor/z3/src/api/z3.h > _out/z3_h.i

clang -fsyntax-only -Xclang -ast-dump=json -I/home/ex/code/ocaml-build-examples/vendor/z3/src/api /home/ex/code/ocaml-build-examples/vendor/z3/src/api/z3_api.h -include z3_macros.h > _out/z3_api_h.json
clang -fsyntax-only -Xclang -ast-dump=json -I/home/ex/code/ocaml-build-examples/vendor/z3/src/api /home/ex/code/ocaml-build-examples/vendor/z3/src/api/z3.h > _out/z3_h.json

clang -fsyntax-only -Xclang -ast-dump=json -Xclang -ast-dump-filter=Z3_ -I/home/ex/code/ocaml-build-examples/vendor/z3/src/api /home/ex/code/ocaml-build-examples/vendor/z3/src/api/z3.h > _out/z3_h_z3.json
*)

open Z3_config

(* let open Binding.Structures in
  C_API { header_path = z3_src_path $/ "src/api/c"; source = ""; defs = [] } *)

let mk_info ~root ~version ~commit =
  { root; c_header_path = root $/ "src/api"; version; commit }

let z3_src_dev = mk_info ~version:"dev" ~commit:"HEAD" ~root:path_dev

(* let z3_src_stable =
  mk_info ~version:"4.8.15" ~commit:"745087e" ~root:path_stable *)

let mk_z3_src_example info =
  let z3_project =
    let open Binding.Structures in
    Project
      {
        path = info.root;
        name = "z3_" ^ info.version;
        platform = None;
        primary_lang = Cpp;
        build_system = CMake;
      }
  in
  let z3_c_json = File.v "." (out_h_json info.version) in
  let cmd_c_header_to_json =
    clang_header_parse info.c_header_path (File.s z3_c_json)
  in
  let lib_built = File.abs (lib_so_path info.root) in
  [
    hrt @@ "z3 source for " ^ info.version;
    Have z3_project;
    Inspect z3_project;
    Ensure_file (z3_c_json, cmd_c_header_to_json);
    Have (C_Json z3_c_json);
    Inspect (C_Json z3_c_json);
    Have (File lib_built);
    hrt @@ "build output";
    Cmd (cmd_from_src (Fmt.str "cd %s && %s" info.root binding_ocaml_buildgen));
    Cmd (cmd_from_src (Fmt.str "cd %s && %s" info.root binding_ocaml_build));
  ]

let z3_src_example = List (mk_z3_src_example z3_src_dev)
(* List (mk_z3_src_example z3_src_dev @ mk_z3_src_example z3_src_stable) *)

let ensure_trailing_newline (s : string) =
  if String.is_suffix s ~suffix:"\n" then s else s ^ "\n"

let rec replace_value (node : Yaml.yaml) ~(from : string) ~(to_ : string) :
    Yaml.yaml =
  match node with
  | `Alias _ -> node
  | `Scalar sc ->
      if String.equal sc.value from then
        let to_ = ensure_trailing_newline to_ in
        `Scalar
          {
            value = to_;
            style = `Literal;
            tag = None;
            anchor = None;
            plain_implicit = true;
            quoted_implicit = true;
          }
      else node
  | `A seq ->
      `A
        {
          seq with
          s_members =
            List.map seq.s_members ~f:(fun n -> replace_value n ~from ~to_);
        }
  | `O map ->
      `O
        {
          map with
          m_members =
            List.map map.m_members ~f:(fun (k, v) ->
                (replace_value k ~from ~to_, replace_value v ~from ~to_));
        }

let get_rresult_exn = function Ok v -> v | Error (`Msg m) -> failwith m

let mk_yaml_example info =
  let _yaml_path = ocaml_ci info.root in
  let yaml_path = "vendor/canary/canary.yml" in
  [
    hrt "YAML for OCaml CI";
    (* Have (File (File.abs yaml_path)); *)
    Have (File (File.v "." yaml_path));
    ML
      (fun () ->
        let yaml =
          read_file yaml_path |> Yaml.yaml_of_string |> get_rresult_exn
        in
        (* Fmt.pr "YAML content:@.@.%a@." Yaml.pp yaml; *)
        let rec find_replaced : Yaml.yaml -> unit = function
          | `Scalar sc when String.is_prefix sc.value ~prefix:"mkdir -p build"
            ->
              Fmt.pr "AFTER: tag=%s style=%s\n"
                (Option.value sc.tag ~default:"<none>")
                (match sc.style with
                | `Literal -> "Literal"
                | `Plain -> "Plain"
                | `Single_quoted -> "Single_quoted"
                | `Double_quoted -> "Double_quoted"
                | `Folded -> "Folded"
                | `Any -> "Any")
          | `A seq -> List.iter seq.s_members ~f:find_replaced
          | `O map ->
              List.iter map.m_members ~f:(fun (k, v) ->
                  find_replaced k;
                  find_replaced v)
          | _ -> ()
        in
        find_replaced yaml;

        let yaml' =
          replace_value yaml ~from:"__OCAML_BINDING_BUILDGEN__"
            ~to_:binding_ocaml_buildgen
        in
        find_replaced yaml';
        (* Fmt.pr "YAML content:@.@.%a@." Yaml.pp yaml'; *)
        let yaml'_s =
          Yaml.yaml_to_string ~scalar_style:`Any ~layout_style:`Block yaml'
          |> get_rresult_exn
        in
        write_file "_out/canary_ocaml_ci.yml" yaml'_s);
  ]

let yaml_example = List (mk_yaml_example z3_src_dev)

let () =
  Fmt.set_style_renderer Fmt.stdout `Ansi_tty;
  let example =
    match Stdlib.Sys.argv.(1) with
    | "z3_1" -> z3_opam_pkg_example
    | "z3_src" -> z3_src_example
    | "yaml" -> yaml_example
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
