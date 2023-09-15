module PM_cmd = Packaging.Cmd.Make (Interp.Text_with_pkgm.Static_dep_pkgm)

let () = PM_cmd.main ()
