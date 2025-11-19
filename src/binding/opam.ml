open Base
open Tola_std

(* 
you may have (see https://github.com/ocaml/opam/blob/d28ead42027b332799e682ff8169b8c057ca4ab6/src/client/opamListCommand.ml#L684)
$ opam show --list-files z3
/home/ex/.opam/5.3.0/lib/z3/z3native.cmi (modified since)
/home/ex/.opam/5.3.0/lib/z3/z3native.cmo
*)

type switch_info = { switch : string; prefix : string }

let parse_opam_list_file (line : string) : string =
  match String.index line ' ' with
  | None -> line
  | Some idx -> String.sub line ~pos:0 ~len:idx

(* 
c++ project
--> lib 

-> findlib library, ...opam (package not installed)
...(...opam install ...from file)
opam package (installed)


*)

(* let this_prefix = "opam var prefix" |> Tola_cmd.run_s *)

(* let this_prefix = Sys.getenv_exn "OPAMSWITCH"
let () = Fmt.pr "Current opam switch: %s@." this_prefix *)

let files_of_package pname =
  Fmt.str "opam show --list-files --color=never %s" pname
  |> Tola_cmd.run_ss
  |> List.map ~f:parse_opam_list_file

let exists pname =
  Fmt.str "opam show --field=package %s" pname |> Tola_cmd.run_b

let prefix switch =
  Fmt.str "opam var prefix --switch=%s" switch |> Tola_cmd.run_s

(* TODO: opam version related *)
let internal_build_path (info : switch_info) =
  info.prefix $/ ".opam-switch" $/ "build"

(* let switch_cmd name =
  Fmt.str "opam switch %s && eval $(opam env --switch=%s)" name name *)

(* let install_cmd pname =
  Fmt.str "opam install -y %s" pname *)
