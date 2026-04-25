(* Small probe: exercise the OCaml ssl binding against system libssl/libcrypto.
   No network I/O — just verifies the binding loads, links, and a TLS context
   can be constructed. Catches API drift like OpenSSL 1 → 3 changes that hide
   or remove specific construction functions. *)

let () =
  Ssl.init ();
  let ctx = Ssl.create_context Ssl.TLSv1_2 Ssl.Client_context in
  (* Don't actually connect; the context's existence proves the binding
     loads, libssl/libcrypto link, and TLS_method (or equivalent) is
     callable. Drift like OpenSSL 1 → 3 hiding TLSv1.0/1.1 protocol
     constants would surface here as a compile error. *)
  let _ = ctx in
  print_endline "ssl ok"
