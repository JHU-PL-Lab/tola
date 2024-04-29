module P = Interp.Text_with_pkgm.Versioned_pkgm
module PM_cmd = Packaging.Cmd.Make (P)

let () =
  P.init ();
  PM_cmd.main ()
