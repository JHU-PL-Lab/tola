module Interp = Interp.Text_with_pkgm.Interp

let main () =
  In_channel.input_all In_channel.stdin
  |> Parser.Text_with_pkg.parse |> Interp.interp |> Fmt.pr "%s@."

let () = main ()
