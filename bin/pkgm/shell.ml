module P = Interp.Bash_with_pkgm.Basic_pkgm
module I = Interp.Bash_with_pkgm.Basic_interp

let main () = 
  P.init ();

  In_channel.input_all In_channel.stdin
  |> Interp.Bash_with_pkgm.parse |> I.expander |> Fmt.pr "%s@."

let () = main ()
