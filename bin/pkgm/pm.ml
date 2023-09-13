module PM_cmd = Packaging.Cmd.Make (Interp.Text_with_pkgm.Basic_pkgm)

let () = PM_cmd.main ()
