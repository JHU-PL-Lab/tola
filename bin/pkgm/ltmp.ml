module P = Interp.Text_with_pkgm.Versioned_pkgm
module I = Interp.Text_with_pkgm.Dyn_interp

let main () =
  P.init ();
  In_channel.input_all In_channel.stdin
  |> Parser.Text_with_pkg.parse |> I.interp |> Fmt.pr "%s@."

let () = main ()
