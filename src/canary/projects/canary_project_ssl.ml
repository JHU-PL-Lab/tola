open Canary_basic
open Canary_toolchain_ocaml
open Canary

(* ── Project: ssl (Pattern A — system libssl/libcrypto + opam ssl binding) ──
   - Real-world version-drift target: OpenSSL 1.x → 3.x hid/removed many APIs;
     the watchlist catches drift at both library-version and binding levels.
   - Linux: apt libssl-dev provides libssl.so + libcrypto.so under the
     standard multilib path. macOS: keg-only via brew openssl@3, requires
     PKG_CONFIG_PATH (handled in lib_ssl_resolve).
   - Two native libs (libssl + libcrypto). For now we summarise libssl only;
     extending probe_lib to a list (mirroring probe_binding's per-location
     entries) would let us cover both — flagged in CLAUDE.md gap list. *)

let ssl_ocaml_config : ocaml_tool_config =
  {
    toolchain =
      {
        prefix_name = "OPENSSL_PREFIX";
        prefix_var = "$OPENSSL_PREFIX";
        prefix_envar = "${OPENSSL_PREFIX}";
        libdir_name = "OPENSSL_LIB_DIR";
        libdir_var = "$OPENSSL_LIB_DIR";
        local_repo_name = "canary-local";
        package_name = "ssl";
        package_version = "system";
        canary_src_var = "CANARY_OPENSSL_SRC";
      };
    ocaml =
      {
        example_file = "canary/examples/ssl/ssl_example.ml";
        example_target = "ssl_example";
        example_name = "ssl example";
        binding_lib_name = "ssl";
        build_api_path = None;
      };
    prebuilt =
      Some
        (mk_prebuilt_info ~opam_package:"ssl"
           ~system_package_linux:"libssl-dev" ~system_package_macos:"openssl@3" ());
  }

(* ── Action steps ── *)

let prebuilt = prebuilt_info_exn ssl_ocaml_config

(* OCaml-side watchlist: ssl ships two compilation units. Drift = major. *)
let ssl_ocaml_watchlist = [ "Ssl"; "Ssl_threads" ]

(* libssl.so watchlist: stable TLS-context construction & I/O entry points
   present in both OpenSSL 1.x and 3.x. Names that disappeared (e.g.
   `SSLv23_method` removed in 3.0) would surface as missing — exactly the
   1→3 drift signal canary should catch on a future libssl upgrade. *)
let openssl_native_watchlist = [
  "SSL_CTX_new";
  "SSL_new";
  "SSL_connect";
  "SSL_read";
  "SSL_write";
  "TLS_method";
]

(* Resolve libssl.so location across distros: standard multilib on Linux,
   brew-keg path on macOS. Exports $LIB_SSL for downstream commands. *)
let lib_ssl_resolve =
  {|LIB_SSL=$(ls /usr/lib/x86_64-linux-gnu/libssl.so.* 2>/dev/null \
        /usr/lib*/libssl.so.* 2>/dev/null \
        "$(brew --prefix openssl@3 2>/dev/null)/lib/libssl.dylib" 2>/dev/null \
        | head -1)
test -n "$LIB_SSL" -a -e "$LIB_SSL"|}

let script_spec : Canary_action.script_spec =
  let pm = Canary_store.detect_pm () in
  let ocaml = ssl_ocaml_config.ocaml in
  {
    Canary_action.empty_script_spec with
    fetch_lib = Some (Canary_action.fetch_lib_cmd pm prebuilt.system_package);
    fetch_binding =
      Some (Canary_action.fetch_binding_cmd prebuilt.opam_package_spec);
    probe_lib =
      Some (fun ~output_dir ->
        let probe = Canary_artifact_native.native_lib_probe_cmd
          ~lib:"$LIB_SSL" ~prefix:"SSL_" ~output_dir in
        [%string "%{lib_ssl_resolve}\n%{probe}"]);
    probe_binding =
      [
        (Canary_store.Lang_pm,
         (fun ~output_dir ->
           Canary_action.probe_ocaml_cmd ~binding_lib:ocaml.binding_lib_name
             ~example:ocaml.example_file ~target:ocaml.example_target
             ~output_dir));
      ];
    summary = (fun rule loc -> match rule, loc with
      | Probe Lib, _ ->
          Some (fun ~output_dir ->
            let sum = Canary_artifact_native.summary_cmd
              ~lib:"$LIB_SSL"
              ~prefixes:[ "SSL_"; "TLS_"; "BIO_" ]
              ~watchlist:openssl_native_watchlist
              ~output_dir () in
            [%string "%{lib_ssl_resolve}\n%{sum}"])
      | Probe Binding, _ ->
          Some (fun ~output_dir ->
            Canary_artifact_ocaml.summary_opam_pkg_cmd
              ~pkg:"ssl" ~watchlist:ssl_ocaml_watchlist ~output_dir ())
      | _ -> None);
  }

let action_steps ~root ~project =
  Canary_action.derive_steps ~root ~project script_spec

let run_info steps =
  Canary_action.mk_run_info ~project:"ssl" ~version:"system" ~ref_:""
    ~source:"prebuilt" steps
