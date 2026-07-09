(* Project: ssl — Pattern A (system libssl + opam ssl binding).
   Real-world version-drift target: OpenSSL 1.x → 3.x hid/removed many APIs;
   the watchlist catches drift at both library-version and binding levels.
   Spec is a thin declaration over canary_pattern_a.

   Limitation: only summarises libssl. ssl actually links libcrypto too;
   covering both needs probe_lib to become a per-location list (mirroring
   probe_binding). Flagged in batch_candidates.md. *)

let decl : Canary_pattern_a.t = {
  name = "ssl";
  opam_pkg = "ssl";
  ocamlfind_pkg = "ssl";
  system_pkg_linux = "libssl-dev";
  system_pkg_macos = "openssl@3";
  example_file = "canary/examples/ssl/ssl_example.ml";
  example_target = "ssl_example";
  binding_lib = "ssl";
  lib = {
    (* libssl-dev provides /usr/lib/.../libssl.so.3 (versioned only on this
       Ubuntu); the unversioned .so symlink may be absent. Use *.so.* glob. *)
    linux_glob = "/usr/lib/x86_64-linux-gnu/libssl.so.* /usr/lib*/libssl.so.*";
    brew_pkg = "openssl@3";
    brew_dylib = "libssl.dylib";
  };
  native_probe_prefix = "SSL_";
  native_inspect_prefixes = [ "SSL_"; "TLS_"; "BIO_" ];
  (* Stable TLS-context construction & I/O entry points present in both
     OpenSSL 1.x and 3.x. Names that disappeared (e.g. `SSLv23_method`
     removed in 3.0) would surface as missing — exactly the 1→3 drift
     signal canary should catch on a future libssl upgrade. *)
  native_watchlist = [
    "SSL_CTX_new";
    "SSL_new";
    "SSL_connect";
    "SSL_read";
    "SSL_write";
    "TLS_method";
  ];
  (* ssl ships two compilation units. Drift = major. *)
  ocaml_module_watchlist = [ "Ssl"; "Ssl_threads" ];
}

let project_spec = Canary_pattern_a.project_spec decl
