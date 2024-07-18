module P = Interp.Boat_with_pkgm.Static_dep_pkgm
module PM_cmd = Packaging.Cmd.Make (P)

let () =
  P.init ();
  PM_cmd.main ()
