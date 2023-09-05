module PM_cmd = Packaging.Cmd.Make (Interp.Text_with_pkgm.Pkgm)

(* let () = print_endline @@ Sys.getcwd () *)
let () = PM_cmd.main ()
