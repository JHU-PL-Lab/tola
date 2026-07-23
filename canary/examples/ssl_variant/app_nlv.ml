(* ssl variant matrix — the VERSION-SPECIFIC app. References
   [Ssl.native_library_version], which was ADDED in ssl 0.7.0 (#140).
   Compiles against 0.7.0 but FAILS against 0.6.0 with
   "Unbound value Ssl.native_library_version" — the version-mismatch this
   matrix demonstrates. *)

let () =
  Ssl.init ();
  ignore Ssl.native_library_version;
  print_endline "ssl nlv ok"
