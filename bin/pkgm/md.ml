module P = Interp.Md_expand.Pkgm
module E = Interp.Md_expand.Expand

let main () =
  P.init ();

  In_channel.input_all In_channel.stdin |> E.expand |> Fmt.pr "%s@."

let () = main ()
