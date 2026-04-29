open Base

(* Generic check_post compositors.
   Thin functions for common check_post patterns. Each returns
   (output_dir:string -> bool) suitable for script_spec.check_post.

   Kind-specific logic lives in:
   - canary_artifact_native.ml  (.so/.dylib/.a, nm inspection)
   - canary_artifact_ocaml.ml   (.cmxa/.cma, ocamlobjinfo, opam-pkg)
   - canary_artifact_python.ml  (python import) *)

(* marker + native lib must exist *)
let check_build_lib ~marker ~lib_path ~output_dir =
  Canary_action.has_file ~output_dir marker
  && Canary_artifact_native.exists_native_lib_or_dylib lib_path

(* marker + ocaml archive must exist *)
let check_build_binding ~marker ~archive_path ~output_dir =
  Canary_action.has_file ~output_dir marker
  && Canary_artifact_lang.exists_ocaml_archive archive_path

(* all listed files must exist in output_dir *)
let check_markers markers ~output_dir =
  List.for_all markers ~f:(fun m -> Canary_action.has_file ~output_dir m)
