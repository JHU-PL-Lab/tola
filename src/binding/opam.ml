open Tola_std

let files_of_package pname =
  Fmt.str "opam show --list-files %s" pname |> Tola_cmd.run_ss

let exists pname =
  (* opam show --field=package *)
  Fmt.str "opam show --field=package %s" pname |> Tola_cmd.run_b
