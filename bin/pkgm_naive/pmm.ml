(* Package manager by marshaling *)

module PM_cmd = Packaging.Cmd.Make (Interp.Text_with_pkgm.Naive_pkgm)

let () = PM_cmd.main ()
