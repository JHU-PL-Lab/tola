let main () =
  In_channel.input_all In_channel.stdin
  |> Parser.Text_with_pkg.parse |> Interp.Text_with_pkgm_interp.interp
  |> Fmt.pr "%s@."

let () = main ()
