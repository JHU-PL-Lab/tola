(* Project: ssl — the variant matrix + native-lib symbol probe.
   Consolidated 2026-07-23: canary projects test variants by default, so
   the variant form IS `ssl` (the former single-version pattern_a spec is
   retired and its native-lib symbol probe folded in here).

   2 binding versions × 2 apps on a fast Pattern-A lib (no source build):

                    ssl 0.6.0        ssl 0.7.0
     app_core       ✓ success        ✓ success      (core TLS-context API, both)
     app_nlv        ✗ xfail [c2]     ✓ success      (Ssl.native_library_version,
                                                      added in 0.7.0 — #140)

   A7 phase 4 (2026-08-05): the red cell is DERIVED, not hand-written.
   Each app DECLARES what it requires ([app.requires] — consumer facts);
   the fetch step INSPECTS the installed binding's .mli against that
   watchlist (evidence); [ssl_contract_bindings] (c2) + the one framework
   lowering turn "requirement missing from evidence" into a must-fail
   prediction at the probe. 0.6.0×nlv → native_library_version missing →
   xfail [c2]; the other three cells derive empty predictions → success.
   The old four per-variant [Expect_failure]/[Expect_success] closures
   (hand-picked substring, no evidence, no contract id) are retired.

   Each variant also runs the native-lib symbol probe over the system
   libssl (SSL_CTX_new … TLS_method) — version-independent, but included
   per variant so the matrix confirms the C lib too.

   The binding version dimension is realized by swapping the ssl version
   in the shared switch per variant (opam install ssl.<v>) — fast, no new
   OCaml switch; run_project_multi runs the four variants sequentially.
   Because that switch is a SHARED MUTABLE STORE across variants (the
   scenario-crossing hazard, status §A A7 phase 3 finding (a)), the probe
   carries a WORLD-IDENTITY ASSERTION: it verifies the switch really
   holds this variant's pinned ssl version before compiling, so a
   warm-cache-skipped install fails loudly as a world mismatch instead of
   silently probing the wrong world (sqlite's log_grep analogue, on the
   binding side). *)

open Canary_basic
module SB = Canary_step_builder
module SC = Canary_store_config
module AN = Canary_artifact_native

type app = {
  aname : string;
  example : string;
  target : string;
  requires : string list;
      (** the CONSUMER's declared requirement on the binding surface (mli
          watchlist) — the data the derived expectation reads; keep in sync
          with what the example source actually references. *)
}

let app_core =
  { aname = "core";
    example = "canary/examples/ssl_variant/app_core.ml";
    target = "ssl_app_core";
    requires = [ "Ssl"; "Ssl.init"; "Ssl.create_context" ] }

let app_nlv =
  { aname = "nlv";
    example = "canary/examples/ssl_variant/app_nlv.ml";
    target = "ssl_app_nlv";
    requires = [ "Ssl"; "Ssl.init"; "Ssl.native_library_version" ] }

(** The c2 (api completeness) declaration: the probe's failure derives from
    the fetched binding's mli inspect (evidence), per variant — each
    variant's inspect is watchlisted with ITS app's [requires], so the
    core cells never predict a failure. *)
let ssl_contract_bindings : Canary_scenario.contract_binding list =
  let module CC = Canary_compat in
  let module CS = Canary_scenario in
  [ { contract = CC.C2; lang = Canary_lang.OCaml;
      firings =
        [ { site = CS.At_probe_binding Canary_lang.OCaml;
            loc_filter = CS.Any;
            source =
              CS.From_artifact
                { inputs = CC.[ Ocaml_mli [ "fetch_binding_ocaml/inspect.json" ] ];
                  version_info =
                    Some
                      { provider_version = "opam ssl (variant-pinned)";
                        consumer_requires = "Ssl.native_library_version";
                        since = Some "ssl 0.7.0 (#140)";
                        note = None } } } ] } ]

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
let mk_variant ~version ~vkey ~(app : app) : string * SB.runner_spec =
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
            { SC.provider = SC.Sys_pkg libssl_spec;
              components = []; headers = None } };
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
      (* App dimension: compile this variant's one app against ssl —
         prefixed with the WORLD-IDENTITY ASSERTION (the switch must hold
         THIS variant's pinned version; see the header comment). A
         mismatch exits before compiling, and its message matches no
         derived prediction, so it reads FAILED, never a fake xfail. *)
      probe_binding =
        [ (Canary_lang.OCaml,
           Canary_store.Pm
             (Canary_store.Lang_pm { lang = Canary_lang.OCaml; pm = Canary_store.Opam }),
           fun ~output_dir ~variant_key ->
             let base =
               SB.probe_ocaml_cmd ~binding_lib:"ssl"
                 ~example:app.example ~target:app.target ~output_dir ~variant_key
             in
             [%string
               {|eval $(opam env)
INSTALLED_SSL=$(ocamlfind query -format '%v' ssl 2>/dev/null)
test "$INSTALLED_SSL" = "%{version}" || { echo "WORLD MISMATCH: switch has ssl $INSTALLED_SSL, scenario declares ssl %{version}"; exit 1; }
%{base}|}]) ];
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
          | Fetch (Binding Canary_lang.OCaml) ->
              (* the EVIDENCE the derived expectation reads: the installed
                 binding's mli surface vs THIS app's declared requirement.
                 (Caveat: if this inspect is warm-cache-skipped while the
                 switch moved on, the evidence is stale in lockstep with the
                 fetch marker; the probe's world assertion is the loud
                 backstop.) *)
              Some (fun ~output_dir ~variant_key ->
                  Canary_artifact_lang.mli_inspect_opam_pkg_cmd ~pkg:"ssl"
                    ~watchlist:app.requires ~output_dir ~variant_key ())
          | _ -> None);
      (* A7 phase 4: the ONE framework lowering over declared bindings —
         the per-variant hand-written expectations are retired; the 2×2
         outcomes are derived from evidence per variant. *)
      expectation =
        Canary_scenario.lower_expectation_agnostic
          ~bindings:ssl_contract_bindings ~langs:[ Canary_lang.OCaml ];
    }
  in
  (name, spec)

(* The 2×2 matrix — no per-cell expectations: app_nlv × 0.6.0 derives its
   must-fail (xfail [c2]) from the mli evidence; the rest derive success. *)
let variants : (string * SB.runner_spec) list =
  [
    mk_variant ~version:"0.6.0" ~vkey:"060" ~app:app_core;
    mk_variant ~version:"0.6.0" ~vkey:"060" ~app:app_nlv;
    mk_variant ~version:"0.7.0" ~vkey:"070" ~app:app_core;
    mk_variant ~version:"0.7.0" ~vkey:"070" ~app:app_nlv;
  ]

(* CI smoke: one positive variant (latest ssl, core app + native probe). *)
let ci_spec : SB.runner_spec =
  snd (mk_variant ~version:"0.7.0" ~vkey:"070" ~app:app_core)
