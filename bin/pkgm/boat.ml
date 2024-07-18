module P = Interp.Boat_with_pkgm.Static_dep_pkgm
module I = Interp.Boat_with_pkgm.Static_dep_interp

let main () =
  P.init ();

  In_channel.input_all In_channel.stdin
  |> Boat_parse.of_string_no_eol_opt |> Option.get |> I.interp
  |> Fmt.pr "%a@." Langs.Lang_boat.pp_exp

let () = main ()
