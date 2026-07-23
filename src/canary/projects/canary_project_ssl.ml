(* Project: ssl — the variant matrix + native-lib symbol probe.
   Consolidated 2026-07-23: canary projects test variants by default, so
   the variant form IS `ssl` (the former single-version pattern_a spec is
   retired and its native-lib symbol probe folded in here).

   2 binding versions × 2 apps on a fast Pattern-A lib (no source build):

                    ssl 0.6.0        ssl 0.7.0
     app_core       ✓ success        ✓ success      (core TLS-context API, both)
     app_nlv        ✗ FAIL           ✓ success      (Ssl.native_library_version,
                                                      added in 0.7.0 — #140)

   Each variant also runs the native-lib symbol probe over the system
   libssl (SSL_CTX_new … TLS_method) — version-independent, but included
   per variant so the matrix confirms the C lib too.

   The binding version dimension is realized by swapping the ssl version
   in the shared switch per variant (opam install ssl.<v>) — fast, no new
   OCaml switch. run_project_multi runs the four variants sequentially. *)

open Canary_basic
module SB = Canary_step_builder
module SM = Canary_step_model
module SC = Canary_store_config
module AN = Canary_artifact_native

type app = { aname : string; example : string; target : string }

let app_core =
  { aname = "core";
    example = "canary/examples/ssl_variant/app_core.ml";
    target = "ssl_app_core" }

let app_nlv =
  { aname = "nlv";
    example = "canary/examples/ssl_variant/app_nlv.ml";
    target = "ssl_app_nlv" }

(* Shared system libssl store — same native lib across all variants. *)
let libssl_spec : Canary_store.system_package_spec =
  { linux_pkg = "libssl-dev"; macos_pkg = "openssl@3";
    version_tag = None; locator_hint = None;
    behavior = Canary_store.Stateful_global }

(* Native-lib symbol probe, folded from the retired pattern_a ssl. *)
let ssl_lib_locator : Canary_pattern_a.lib_locator =
  { linux_glob = "/usr/lib/x86_64-linux-gnu/libssl.so.* /usr/lib*/libssl.so.*";
    brew_pkg = "openssl@3";
    brew_dylib = "libssl.dylib" }

let ssl_resolve = Canary_pattern_a.lib_resolve ssl_lib_locator
let ssl_native_prefixes = [ "SSL_"; "TLS_"; "BIO_" ]
let ssl_native_watchlist =
  [ "SSL_CTX_new"; "SSL_new"; "SSL_connect"; "SSL_read"; "SSL_write"; "TLS_method" ]

let pm = Canary_store.detect_pm ()

(* One (version × app) cell → a runner_spec. *)
let mk_variant ~version ~vkey ~(app : app) ~expect : string * SB.runner_spec =
  let name = [%string "%{vkey}_%{app.aname}"] in
  let opam_spec =
    Canary_toolchain.mk_opam_package_spec
      ~install_name:[%string "ssl.%{version}"] ()
  in
  let spec =
    { SB.empty_runner_spec with
      stores =
        { SC.empty_store_config with
          lib = Some
            { SC.location = Canary_store.Pm (Canary_store.Sys_pm { pm });
              system_pkg = Some libssl_spec; components = []; headers = None } };
      fetch_lib = Some (SB.Derived SB.Fetch_lib);
      (* Binding version dimension: install the pinned ssl version. *)
      fetch_binding =
        [ (Canary_lang.OCaml, SB.Raw (SB.fetch_binding_cmd opam_spec)) ];
      (* Native-lib symbol probe (folded from pattern_a ssl). *)
      probe_lib =
        [ (Canary_store.Pm (Canary_store.Sys_pm { pm }),
           fun ~output_dir ~variant_key ->
             let probe =
               AN.native_lib_probe_cmd ~lib:"$LIB_NATIVE" ~prefix:"SSL_"
                 ~output_dir ~variant_key
             in
             Printf.sprintf "%s\n%s" ssl_resolve probe) ];
      (* App dimension: compile this variant's one app against ssl. *)
      probe_binding =
        [ (Canary_lang.OCaml,
           Canary_store.Pm
             (Canary_store.Lang_pm { lang = Canary_lang.OCaml; pm = Canary_store.Opam }),
           SB.probe_ocaml_cmd ~binding_lib:"ssl"
             ~example:app.example ~target:app.target) ];
      inspect =
        (fun action _loc ->
          match action with
          | Probe_lib ->
              Some (fun ~output_dir ~variant_key ->
                  let sum =
                    AN.inspect_cmd ~lib:"$LIB_NATIVE" ~prefixes:ssl_native_prefixes
                      ~watchlist:ssl_native_watchlist ~output_dir ~variant_key ()
                  in
                  Printf.sprintf "%s\n%s" ssl_resolve sum)
          | _ -> None);
      expectation =
        (fun action _loc ->
          match action with
          | Probe_binding Canary_lang.OCaml -> expect
          | _ -> SM.Expect_success);
    }
  in
  (name, spec)

(* The 2×2 matrix. app_nlv × 0.6.0 is the one expected failure. *)
let variants : (string * SB.runner_spec) list =
  [
    mk_variant ~version:"0.6.0" ~vkey:"060" ~app:app_core ~expect:SM.Expect_success;
    mk_variant ~version:"0.6.0" ~vkey:"060" ~app:app_nlv
      ~expect:(SM.Expect_failure
                 { contains_any = [ "native_library_version" ]; version_info = None });
    mk_variant ~version:"0.7.0" ~vkey:"070" ~app:app_core ~expect:SM.Expect_success;
    mk_variant ~version:"0.7.0" ~vkey:"070" ~app:app_nlv ~expect:SM.Expect_success;
  ]

(* CI smoke: one positive variant (latest ssl, core app + native probe). *)
let ci_spec : SB.runner_spec =
  snd (mk_variant ~version:"0.7.0" ~vkey:"070" ~app:app_core ~expect:SM.Expect_success)
