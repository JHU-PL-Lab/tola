open Base
open Tola_std

(* 
you may have (see https://github.com/ocaml/opam/blob/d28ead42027b332799e682ff8169b8c057ca4ab6/src/client/opamListCommand.ml#L684)
$ opam show --list-files z3
/home/ex/.opam/5.3.0/lib/z3/z3native.cmi (modified since)
/home/ex/.opam/5.3.0/lib/z3/z3native.cmo
*)

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

let files_of_package pname =
  Fmt.str "opam show --list-files --color=never %s" pname
  |> Tola_cmd.run_ss
  |> List.map ~f:parse_opam_list_file

let exists pname =
  (* opam show --field=package *)
  Fmt.str "opam show --field=package %s" pname |> Tola_cmd.run_b
