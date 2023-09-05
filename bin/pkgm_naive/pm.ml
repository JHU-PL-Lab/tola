module PM_cmd = Packaging.Cmd.Make (Interp.Text_with_pkgm.Pkgm)

let () = PM_cmd.main ()
