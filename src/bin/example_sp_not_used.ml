(* Archived commented-out snippets moved from src/bin/example_sp.ml *)

(* pay attention of abstract

dryrun

ocamlmklib -custom -dynamic
*)

(* clang -fsyntax-only -Xclang -ast-dump=json -I/home/ex/code/ocaml-build-examples/vendor/z3/src/api /home/ex/code/ocaml-build-exa
mples/vendor/z3/src/api/z3.h > _out/z3_h_dd.json *)

(* 
clang -E -dI -P -I/home/ex/code/ocaml-build-examples/vendor/z3/src/api /home/ex/code/ocaml-build-examples/vendor/z3/src/api/z3_api.h > _out/z3_api_h.i
clang -E -dI -P -I/home/ex/code/ocaml-build-examples/vendor/z3/src/api /home/ex/code/ocaml-build-examples/vendor/z3/src/api/z3.h > _out/z3_h.i

clang -fsyntax-only -Xclang -ast-dump=json -I/home/ex/code/ocaml-build-examples/vendor/z3/src/api /home/ex/code/ocaml-build-examples/vendor/z3/src/api/z3_api.h -include z3_macros.h > _out/z3_api_h.json
clang -fsyntax-only -Xclang -ast-dump=json -I/home/ex/code/ocaml-build-examples/vendor/z3/src/api /home/ex/code/ocaml-build-examples/vendor/z3/src/api/z3.h > _out/z3_h.json

clang -fsyntax-only -Xclang -ast-dump=json -Xclang -ast-dump-filter=Z3_ -I/home/ex/code/ocaml-build-examples/vendor/z3/src/api /home/ex/code/ocaml-build-examples/vendor/z3/src/api/z3.h > _out/z3_h_z3.json
*)

(* ocaml_prj
   dune build ocaml_prj : input ocaml_prj, output findlib_library + dot_opam_spec

let project = ocaml_prj in
let build_result = Build_dune project in
let _ = check build_result
*)

(* let z3_opam_example1 = List []
let z3_opam_example2 = List []
let z3_each_for_ocaml_example = List []
let z3_system_ocaml_example = List [] *)

(* cmd ~env:[ ("OCAMLPATH", abs_project_path) ] (echo "OCAMLPATH");
         cmd (build_project "song_std_1_0"); *)
(*cmd (build_project "song_std_2_0"); *)
(* cmd (build_project "song_foo_1_0_nobound"); *)
(* cmd (build_project "song_foo_1_0_vendored"); *)
(* cmd (build_project "song_foo_1_0_workspace"); *)

(* let open Binding.Structures in
  C_API { header_path = z3_src_path $/ "src/api/c"; source = ""; defs = [] } *)

(* let z3_src_stable =
  mk_info ~version:"4.8.15" ~commit:"745087e" ~root:path_stable *)

(* List (mk_z3_src_example z3_src_dev @ mk_z3_src_example z3_src_stable) *)

(* Have (File (File.abs yaml_path)); *)

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
