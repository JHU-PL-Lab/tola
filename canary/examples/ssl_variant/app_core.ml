(* ssl variant matrix — the CONTROL app. Uses only core ssl API
   (init + TLS context) present in both 0.6.0 and 0.7.0. Should compile
   and run against BOTH binding versions — it proves the binding itself
   loads/links, isolating app_nlv's failure to the missing symbol. *)

let () =
  Ssl.init ();
  let ctx = Ssl.create_context Ssl.TLSv1_2 Ssl.Client_context in
  let _ = ctx in
  print_endline "ssl core ok"
