(* Project: ssl — the binding-version matrix + native-lib symbol probe.
   Consolidated 2026-07-23; migrated to the general enumeration with
   STORE PINS on 2026-08-12 (the `Multi` registry hack retired — ssl is a
   plain [project_run] like every other project).

   2 binding versions × 2 apps on a fast Pattern-A lib (no source build):

                    ssl 0.6.0        ssl 0.7.0
     app_core       ✓ success        ✓ success      (core TLS-context API, both)
     app_nlv        ✗ xfail [c2]     ✓ success      (Ssl.native_library_version,
                                                      added in 0.7.0 — #140)

   The shape post-migration: 2 enumerated scenarios (one per PINNED binding
   version — the provider declares versions ["0.6.0"; "0.7.0"], the axis
   projects from it, a pinned Fetched placement is identity-bearing). Each
   scenario probes BOTH apps as different actions: core = Probe_binding
   OCaml, nlv = Probe_app OCaml — the expectation lowering merges inputs
   per ACTION, so the two probes derive separate predictions from separate
   evidence files. The 2×2's red cell survives as scenario@0.6.0's
   probe_app step (xfail [c2]).

   The shared opam switch is a SHARED MUTABLE STORE across the two
   scenarios (scenario-crossing hazard, status §A A7 finding (a)):
   - the binding fetch is a STORE-PIN operation — `opam install ssl.<pin>`
     with a pin-checked [check_post] ([SB.pin_check_post]): the warm-cache
     skip only fires when the switch provably holds the pin; otherwise the
     fetch re-runs and re-pins;
   - both probes carry a WORLD-IDENTITY ASSERTION (switch holds the pin)
     as a pre-check — a mismatch exits loudly before compiling, and its
     message matches no derived prediction, so it reads FAILED, never a
     fake xfail.

   A7 phase 4 (2026-08-05): the red cell is DERIVED, not hand-written —
   each app DECLARES what it requires ([app.requires]); the fetch steps
   INSPECT the installed binding's .mli against those watchlists
   (evidence); [ssl_contract_bindings] (c2, TWO firings) + the one
   framework lowering turn "requirement missing from evidence" into a
   must-fail prediction at the probe. The old four per-variant
   [Expect_failure]/[Expect_success] closures are retired. *)

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

(** The c2 (api completeness) declaration with TWO firings (2026-08-12) —
    one per probe ACTION, each reading its own evidence file:
    - [At_probe_binding OCaml] (core app): evidence = the mli inspect of
      the fetch step, watchlisted with [app_core.requires] — always
      present, so core never predicts a failure;
    - [At_probe_app OCaml] (nlv app): evidence = the mli inspect attached
      to the FETCH LIB step, watchlisted with [app_nlv.requires] —
      native_library_version missing at 0.6.0 → the derived must-fail. *)
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
                      { provider_version = "opam ssl (pinned)";
                        consumer_requires = "Ssl.create_context (core app)";
                        since = None; note = None } } };
          { site = CS.At_probe_app Canary_lang.OCaml;
            loc_filter = CS.Any;
            source =
              CS.From_artifact
                { inputs = CC.[ Ocaml_mli [ "fetch_binding_ocaml/inspect_nlv.json" ] ];
                  version_info =
                    Some
                      { provider_version = "opam ssl (pinned)";
                        consumer_requires = "Ssl.native_library_version";
                        since = Some "ssl 0.7.0 (#140)";
                        note = None } } } ] } ]

(* Shared system libssl store — same native lib across all variants. *)
let libssl_spec : Canary_store.system_package_spec =
  { linux_pkg = "libssl-dev"; macos_pkg = "openssl@3";
    version_tag = None; locator_hint = None;
    behavior = Canary_store.Stateful_global }

(* Native-lib symbol probe, folded from the retired pattern_a ssl. *)
let ssl_lib_locator : Canary_opam_binding.lib_locator =
  { linux_glob = "/usr/lib/x86_64-linux-gnu/libssl.so.* /usr/lib*/libssl.so.*";
    brew_pkg = "openssl@3";
    brew_dylib = "libssl.dylib" }

let ssl_resolve = Canary_opam_binding.lib_resolve ssl_lib_locator
let ssl_native_prefixes = [ "SSL_"; "TLS_"; "BIO_" ]
let ssl_native_watchlist =
  [ "SSL_CTX_new"; "SSL_new"; "SSL_connect"; "SSL_read"; "SSL_write"; "TLS_method" ]

(* OpenSSL sources (2026-08-13, spec-check fulfillment): the canonical
   github mirror. The stable ref matches the SYSTEM libssl (3.0.13, the lib
   the opam ssl binding links against); dev (master) is the not-yet-wired
   channel — the row carries the stable repo (same shape as z3's). *)
let ssl_api_source : Canary_artifact.t =
  { Canary_artifact.native_api =
      { kind = Canary_artifact.C;
        components = [ Canary_artifact.Headers; Canary_artifact.Runtime_lib ];
        headers =
          Some
            { Canary_artifact.dir = "include/openssl";
              files =
                [ "ssl.h"; "crypto.h"; "err.h"; "x509.h"; "x509v3.h"; "bio.h";
                  "evp.h"; "tls1.h" ] };
        symbol_prefixes = ssl_native_prefixes;
        stable_symbols = ssl_native_watchlist;
        versioned_symbols = [];
        soname = None;
        c_runtime = None;
        cxx_abi = None };
    binding_apis =
      [ { Canary_artifact.lang = Canary_lang.OCaml;
          source_dir = None;
          module_watchlist =
            [ "Ssl"; "Ssl.init"; "Ssl.create_context";
              "Ssl.native_library_version" ];
          type_watchlist = [] } ] }

let ssl_source_stable : Canary_artifact_source.source_repo =
  { Canary_artifact_source.name = "openssl";
    remote = Some (Git "https://github.com/openssl/openssl.git");
    locals = [];
    version = Canary_basic.{ channel = Canary_basic.Stable; id = "3.0.13" };
    ref_ = "openssl-3.0.13";
    official = true;
    build_sys_deps = [];
    api_source = Some ssl_api_source;
    label = None;
    (* the repo builds the C lib; the opam ssl binding is off-tree *)
    artifacts = [ Canary_artifact.a_lib ] }

(* dev (master) stays declared as the unwired latest channel — the
   per-(artifact × channel) source provider is the not-yet-wired
   provenance refinement. *)
let ssl_source_dev : Canary_artifact_source.source_repo =
  { ssl_source_stable with
    version = Canary_basic.{ channel = Canary_basic.Dev; id = "master" };
    ref_ = "master" }

let ssl_source_of (ch : Canary_basic.channel) : Canary_artifact_source.source_repo =
  match ch with
  | Canary_basic.Dev -> ssl_source_dev
  | Canary_basic.Stable -> ssl_source_stable

(* Per-call (M1, 2026-08-14): PM detection must not run at MODULE INIT —
   the registry loads every project module, so a top-level [detect_pm]
   shelled out on every CLI command, even PM-irrelevant ones. *)
let pm () = Canary_store.detect_pm ()

(* ── THE artifact table (2026-08-12) ──
   The binding's provider declares STORE PINS ([versions]) — the axis
   projects from it (mirror of [dep_mode_of_provider] → runtime). The App
   row lets the Probe_app terminal chain materialize. *)
let ssl_binding_art =
  Canary_artifact.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs

let ssl_artifacts : Canary_project_spec.artifact_row list =
  [ (* The source row (2026-08-13, spec-check fulfillment): Fetched@Stable
       (version-ambient identity — the scenario set stays the two pinned
       binding worlds; the run's fetch_source clones openssl@3.0.13 once,
       cached thereafter). *)
    Canary_project_spec.artifact_row ~artifact:Canary_artifact.a_source
      ~universe:[ (Canary_artifact.Fetched, [ Canary_basic.Stable ]) ]
      ~provider:(SC.Repo ssl_source_stable) ();
    Canary_project_spec.artifact_row ~artifact:Canary_artifact.a_lib
      ~universe:[ (Canary_artifact.Fetched, [ Canary_basic.Stable ]) ]
      ~provider:(SC.Sys_pkg libssl_spec) ();
    Canary_project_spec.artifact_row ~artifact:ssl_binding_art
      ~universe:[ (Canary_artifact.Fetched, [ Canary_basic.Stable ]) ]
      ~provider:
        (SC.Lang_pkg
           { lang = Canary_lang.OCaml; pm = Canary_store.Opam; package = "ssl";
             self_contained = false;
             versions =
               Some
                 [ { SC.pin_version = "0.6.0"; install_name = None };
                   { SC.pin_version = "0.7.0"; install_name = None } ] })
      ();
    Canary_project_spec.artifact_row
      ~artifact:(Canary_artifact.a_app Canary_artifact.Direct)
      ~universe:[ (Canary_artifact.Vendored, [ Canary_basic.Stable ]) ] () ]

(* The dispatch: the binding's pinned version id — the only coordinate the
   realization reads. *)
let ssl_pin_of (a : Canary_artifact.assignment) : string =
  let v = Canary_enumerate.version_of a ssl_binding_art in
  if String.equal v.Canary_basic.id "" then
    failwith "ssl realize: binding placement carries no pin"
  else v.Canary_basic.id

(* The world-identity assertion prefix (generalized 2026-08-12): the
   switch must hold THIS scenario's pin before any probe compiles —
   checked against the OPAM version (the store's own record). *)
let ssl_world_check (pin : string) =
  [%string
    {|eval $(opam env)
INSTALLED_SSL=$(opam list ssl --installed --short --columns=version 2>/dev/null)
test "$INSTALLED_SSL" = "%{pin}" || { echo "WORLD MISMATCH: switch has ssl $INSTALLED_SSL, scenario declares ssl %{pin}"; exit 1; }
|}]

(* One pinned scenario → a runner_spec with BOTH apps as different probe
   actions (core = probe_binding, nlv = probe_app), each with its own
   evidence file and its own world assertion. *)
let realize (a : Canary_artifact.assignment) : SB.runner_spec =
  let pin = ssl_pin_of a in
  let opam_spec =
    Canary_toolchain.mk_opam_package_spec
      ~install_name:[%string "ssl.%{pin}"] ()
  in
  { SB.empty_runner_spec with
    stores =
      { SC.empty_store_config with
        lib = Some
          { SC.provider = SC.Sys_pkg libssl_spec;
            components = []; headers = None } };
    fetch_lib = Some (SB.Derived SB.Fetch_lib);
    (* the declared source (spec-check fulfillment): a real one-time clone
       of openssl@3.0.13 (ssl never builds from it — the fetch is the
       declaration made runnable; cached via the source.ok marker). *)
    fetch_source =
      Some
        (fun ~output_dir ~variant_key ->
          Canary_artifact_source.source_fetch_cmd
            (Canary_basic.detect_distro ()) ssl_source_stable ~output_dir
            ~variant_key);
    (* STORE-PIN fetch: opam install ssl.<pin>; the warm-cache skip only
       fires when the switch provably holds the pin. *)
    fetch_binding =
      [ (Canary_lang.OCaml, SB.Raw (SB.fetch_binding_cmd opam_spec)) ];
    check_post =
      (function
      | Canary_basic.Fetch (Canary_basic.Binding Canary_lang.OCaml) ->
          Some (SB.pin_check_post ~pkg:"ssl" ~pin ~marker:"binding.ok")
      | _ -> None);
    (* Native-lib symbol probe (folded from pattern_a ssl). *)
    probe_lib =
      [ (Canary_store.Pm (Canary_store.Sys_pm { pm = pm () }),
         fun ~output_dir ~variant_key ->
           let probe =
             AN.native_lib_probe_cmd ~lib:"$LIB_NATIVE" ~prefix:"SSL_"
               ~output_dir ~variant_key
           in
           Printf.sprintf "%s\n%s" ssl_resolve probe) ];
    (* core app = the binding probe. *)
    probe_binding =
      [ (Canary_lang.OCaml,
         Canary_store.Pm
           (Canary_store.Lang_pm { lang = Canary_lang.OCaml; pm = Canary_store.Opam }),
         fun ~output_dir ~variant_key ->
           let base =
             SB.probe_ocaml_cmd ~binding_lib:"ssl"
               ~example:app_core.example ~target:app_core.target ~output_dir
               ~variant_key
           in
           ssl_world_check pin ^ base) ];
    (* nlv app = the app probe. *)
    probe_app =
      [ (Canary_lang.OCaml,
         fun ~output_dir ~variant_key ->
           let base =
             SB.probe_ocaml_cmd ~binding_lib:"ssl"
               ~example:app_nlv.example ~target:app_nlv.target ~output_dir
               ~variant_key
           in
           ssl_world_check pin ^ base) ];
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
        | Fetch (Canary_basic.Binding Canary_lang.OCaml) ->
            (* BOTH evidence files, on the fetch-binding inspect — the
               inspect child runs AFTER the parent's [opam install ssl.<pin>],
               so the evidence provably reads the PINNED binding (attaching
               to fetch_lib would race the pin: the lib fetch has no
               dependency on the binding fetch).
               - [inspect_<vk>.json] (the check_post-verified file) = core's
                 evidence, watchlisted with [app_core.requires];
               - [inspect_nlv_<vk>.json] = nlv's evidence, watchlisted with
                 [app_nlv.requires] — produced first, then renamed, so the
                 verified file holds core's. Referenced by the At_probe_app
                 firing as "fetch_binding_ocaml/inspect_nlv.json". *)
            Some
              (fun ~output_dir ~variant_key ->
                let base_inspect =
                  Canary_basic.filename ~variant_key ~base:"inspect" ~ext:"json"
                in
                let nlv_inspect =
                  Canary_basic.filename ~variant_key ~base:"inspect_nlv"
                    ~ext:"json"
                in
                let nlv_cmd =
                  Canary_artifact_lang.mli_inspect_opam_pkg_cmd ~pkg:"ssl"
                    ~watchlist:app_nlv.requires ~output_dir ~variant_key ()
                in
                let core_cmd =
                  Canary_artifact_lang.mli_inspect_opam_pkg_cmd ~pkg:"ssl"
                    ~watchlist:app_core.requires ~output_dir ~variant_key ()
                in
                Printf.sprintf "%s && mv %s/%s %s/%s && %s" nlv_cmd output_dir
                  base_inspect output_dir nlv_inspect core_cmd)
        | _ -> None);
    expectation =
      Canary_scenario.lower_expectation_agnostic
        ~bindings:ssl_contract_bindings ~langs:[ Canary_lang.OCaml ];
  }

let ssl_run : Canary_project_run.project_run =
  { pr_name = "ssl";
    pr_artifacts = ssl_artifacts;
    pr_runner_spec =
      (fun a ~workspace:_ () ->
        realize a);
    pr_mismatch_probes = [];
    pr_wrapper_pkgs = [];
    pr_api_source = None;
    pr_binding_decls = [];
    pr_raw_build_overrides = [];
    pr_tier = Canary_project_run.Light }

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
        [ (Canary_store.Pm (Canary_store.Sys_pm { pm = pm () }),
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
