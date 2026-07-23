(* Project: ssl-variant — the basic variant-combination matrix.
   2 binding versions × 2 apps on a fast Pattern-A lib (no source build):

                    ssl 0.6.0        ssl 0.7.0
     app_core       ✓ success        ✓ success      (core TLS-context API, both)
     app_nlv        ✗ FAIL           ✓ success      (Ssl.native_library_version,
                                                      added in 0.7.0 — #140)

   Realizes the version dimension by *swapping* the ssl version in the
   shared switch per variant (opam install ssl.<v>) — fast, no new OCaml
   switch. run_project_multi runs the four variants sequentially; each is
   an ordinary single-app runner_spec (the app dimension is one variant
   per app, since probe_binding keys by location, not by app).

   First project to exercise the variant machinery on a Pattern-A shape
   (same opam package, two versions) rather than z3/llvm's
   differently-named source packages. *)

open Canary_basic
module SB = Canary_step_builder
module SM = Canary_step_model
module SC = Canary_store_config

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

(* One (version × app) cell → a runner_spec. [vkey] is the dot-free
   variant label used in output filenames; [version] is the opam version. *)
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
            { SC.location =
                Canary_store.Pm (Canary_store.Sys_pm { pm = Canary_store.Apt });
              system_pkg = Some libssl_spec; components = []; headers = None } };
      fetch_lib = Some (SB.Derived SB.Fetch_lib);
      (* Binding version dimension: install the pinned ssl version. *)
      fetch_binding =
        [ (Canary_lang.OCaml, SB.Raw (SB.fetch_binding_cmd opam_spec)) ];
      (* App dimension: compile this variant's one app against ssl. *)
      probe_binding =
        [ (Canary_lang.OCaml,
           Canary_store.Pm
             (Canary_store.Lang_pm { lang = Canary_lang.OCaml; pm = Canary_store.Opam }),
           SB.probe_ocaml_cmd ~binding_lib:"ssl"
             ~example:app.example ~target:app.target) ];
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
