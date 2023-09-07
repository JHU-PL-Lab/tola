module PM_cmd = Packaging.Cmd.Make_basic (Interp.Text_with_pkgm.Basic_pkgm)

(* let () = print_endline @@ Sys.getcwd () *)
let () = PM_cmd.main ()
