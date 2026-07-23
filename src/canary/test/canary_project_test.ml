open Base

(* Project-definition layer tests (project_definition.md §8).

   The third testing axis: fast, hermetic, pure tests of the
   project *definition* layers — no PM installs, no builds. Step 1
   covers the action → artifact consumes/produces relation that the
   forecast-agnostic detection derives its inputs from. Later steps
   append store-derivation, detection-over-fixtures, fail-mode
   policy, and the tiny oracle check.

   Pure predicate tests only (no shell); mirrors the pure_test half
   of canary_artifact_test.ml. *)

module A = Canary_action
module B = Canary_basic
module L = Canary_lang

type pure_test = { name : string; check : unit -> bool }

let run_pure_test (t : pure_test) = try t.check () with _ -> false

(* ── helpers ── *)

let kinds_to_s (ks : B.artifact_kind list) : string =
  String.concat ~sep:";" (List.map ks ~f:B.string_of_artifact_kind)

let same_kinds (a : B.artifact_kind list) (b : B.artifact_kind list) : bool =
  List.equal Poly.equal a b

(* One row: an action with its expected consumes + produces sets. *)
let ocaml = L.OCaml

let catalogue : (B.action * B.artifact_kind list * B.artifact_kind list) list =
  B.[
    (Configure,                       [ Source ],            []);
    (Scan_sources,                    [ Source ],            []);
    (Build_headers,                   [ Source ],            [ Headers ]);
    (Build_lib,                       [ Source ],            [ Lib ]);
    (Install_lib,                     [ Lib ],               [ Lib ]);
    (Build_binding ocaml,             [ Lib ],               [ Binding ocaml ]);
    (Build_app { lang = ocaml },      [ Binding ocaml; Lib ],[ App ]);
    (Probe_lib,                       [ Lib ],               []);
    (Probe_binding ocaml,             [ Binding ocaml; Lib ],[]);
    (Probe_app { lang = ocaml },      [ Binding ocaml; Lib; App ], []);
    (Fetch Source,                    [],                    [ Source ]);
    (Fetch Lib,                       [],                    [ Lib ]);
    (Publish Lib,                     [ Lib ],               [ Lib ]);
  ]

(* ── the tests ── *)

let catalogue_tests : pure_test list =
  List.map catalogue ~f:(fun (a, exp_c, exp_p) ->
    { name =
        Printf.sprintf "consumes_produces.%s" (B.string_of_action a);
      check = (fun () ->
        same_kinds (A.consumes_of_action a) exp_c
        && same_kinds (A.produces_of_action a) exp_p) })

(* Invariant detection relies on: probes produce nothing, so for
   every Probe_* action consumes_of_action = artifacts_of_action
   (the legacy flat view). Locks the equivalence that lets detection
   reuse the existing artifact derivation at probe sites. *)
let probe_invariant : pure_test =
  { name = "probe_invariant.consumes_eq_artifacts";
    check = (fun () ->
      let probes =
        B.[ Probe_lib; Probe_binding ocaml; Probe_app { lang = ocaml };
            Probe_binding L.Python ]
      in
      List.for_all probes ~f:(fun a ->
        same_kinds (A.consumes_of_action a) (A.artifacts_of_action a)
        && List.is_empty (A.produces_of_action a))) }

(* The detection-scope inventory for a sqlite-like positive-only
   project: fetch source, build+fetch lib, build+probe the OCaml
   binding, probe the lib. The consumes-inventory is the deduped set
   of artifacts detection would inspect. *)
let inventory_test : pure_test =
  { name = "inventory.sqlite_like";
    check = (fun () ->
      let actions =
        B.[ Fetch Source; Build_lib; Fetch Lib;
            Build_binding ocaml; Probe_binding ocaml; Probe_lib ]
      in
      (* Fetch consumes nothing; Build_lib→Source; Fetch Lib→(none);
         Build_binding→Lib; Probe_binding→Binding+Lib; Probe_lib→Lib.
         First-appearance union: Source, Lib, Binding OCaml. *)
      same_kinds
        (A.consumed_artifacts_of_actions actions)
        B.[ Source; Lib; Binding ocaml ]) }

(* ── step 2: store_config / surface / spec strawman ── *)

module SC = Canary_store_config
module SB = Canary_step_builder

(* S3: a Derived Fetch_lib step resolves (via command_of_step ~store_config)
   to exactly what the runner helper emits — the compatibility guarantee
   (old Raw closure == Derived slot). command_of_step uses detect_pm ()
   internally, so we compare against the same detect_pm-based helper call. *)
let derive_fetch_lib_test : pure_test =
  { name = "derive.fetch_lib_matches_helper";
    check = (fun () ->
      let sys : Canary_store.system_package_spec =
        { linux_pkg = "libsqlite3-dev"; macos_pkg = "sqlite";
          version_tag = None; locator_hint = None;
          behavior = Canary_store.Stateless }
      in
      let store_config : SC.store_config =
        { SC.empty_store_config with
          lib = Some { location = Canary_store.Pm (Canary_store.Sys_pm { pm = Canary_store.Apt });
                       system_pkg = Some sys; components = []; headers = None } }
      in
      let derived =
        (SB.command_of_step ~store_config (SB.Derived SB.Fetch_lib))
          ~output_dir:"OUT" ~variant_key:"vk"
      in
      let direct =
        SB.fetch_lib_cmd (Canary_store.detect_pm ()) sys
          ~output_dir:"OUT" ~variant_key:"vk"
      in
      String.equal derived direct
      && String.is_substring derived ~substring:"libsqlite3-dev") }

(* surface_of_api keeps the watchlists and drops the provenance. *)
let surface_split_test : pure_test =
  { name = "surface.split_keeps_checks_drops_provenance";
    check = (fun () ->
      let module Api = Canary_artifact_api in
      let native : Api.native_api =
        { kind = Api.C;
          components = [ Api.Headers; Api.Link_lib ];  (* provenance — must drop *)
          headers = Some { dir = "include"; files = [ "sqlite3.h" ] };
          symbol_prefixes = [ "sqlite3_" ];
          stable_symbols = [ "sqlite3_open"; "sqlite3_close" ];
          versioned_symbols = []; soname = Some "libsqlite3.so.0";
          c_runtime = None; cxx_abi = None }
      in
      let binding : Api.binding_api =
        { lang = ocaml; source_dir = Some "src";  (* provenance — must drop *)
          module_watchlist = [ "Sqlite3" ]; type_watchlist = [] }
      in
      let api : Api.t = { native_api = native; binding_apis = [ binding ] } in
      let s = Canary_surface.surface_of_api api in
      List.equal String.equal s.native.stable_symbols
        [ "sqlite3_open"; "sqlite3_close" ]
      && String.equal (Option.value s.native.soname ~default:"") "libsqlite3.so.0"
      && (match s.bindings with
          | [ (l, bs) ] ->
            Poly.equal l ocaml
            && List.equal String.equal bs.module_watchlist [ "Sqlite3" ]
          | _ -> false)) }

(* S2: command_of_step (Raw f) is f — the identity that makes wrapping
   every existing closure as Raw behavior-preserving. Raw ignores the
   store_config. *)
let s2_raw_identity_test : pure_test =
  { name = "s2.command_of_step_raw_identity";
    check = (fun () ->
      let f ~output_dir ~variant_key = output_dir ^ ":" ^ variant_key in
      let g =
        SB.command_of_step ~store_config:SC.empty_store_config (SB.Raw f)
      in
      String.equal (g ~output_dir:"O" ~variant_key:"V") "O:V") }

(* S5a: the trivial detector classifies a step by its raw outcome,
   independent of any expectation/contract. *)
let detect_simple_test : pure_test =
  { name = "detect.simple_finding";
    check = (fun () ->
      let ok = Canary_detect.simple_finding ~tag:"t" ~cmd_ok:true ~output_present:true in
      let bad = Canary_detect.simple_finding ~tag:"t" ~cmd_ok:false ~output_present:false in
      (not ok.errored) && ok.output_present
      && bad.errored && (not bad.output_present)) }

(* scenario coverage: an ssl-`sys`-like action set covers the fetch-path
   stages and is N/A on build/publish — symmetric with tiny's N/A on
   fetch/publish. *)
let coverage_test : pure_test =
  { name = "coverage.fetch_path_marks";
    check = (fun () ->
      let module CV = Canary_scenario_coverage in
      let covered =
        B.[ Fetch Lib; Fetch (Binding ocaml); Probe_binding ocaml; Probe_lib ]
      in
      let rows = CV.coverage ~langs:[ ocaml ] ~covered in
      let mark a = List.Assoc.find rows a ~equal:Poly.equal in
      Poly.equal (mark B.(Fetch Lib)) (Some CV.Covered)
      && Poly.equal (mark B.(Fetch (Binding ocaml))) (Some CV.Covered)
      && Poly.equal (mark B.(Probe_binding ocaml)) (Some CV.Covered)
      && Poly.equal (mark B.Build_lib) (Some CV.Na)
      && Poly.equal (mark B.(Publish Lib)) (Some CV.Na)
      && Poly.equal (mark B.(Build_binding ocaml)) (Some CV.Na)) }

let all_tests : pure_test list =
  catalogue_tests
  @ [ probe_invariant; inventory_test;
      derive_fetch_lib_test; surface_split_test;
      s2_raw_identity_test; detect_simple_test; coverage_test ]

let run_tests () : bool =
  let results = List.map all_tests ~f:(fun t -> (t, run_pure_test t)) in
  List.iter results ~f:(fun (t, ok) ->
    Fmt.pr "[%s] %s@." (if ok then "PASS" else "FAIL") t.name;
    if not ok then
      (* Re-run to surface the mismatch on the catalogue rows. *)
      List.iter catalogue ~f:(fun (a, exp_c, exp_p) ->
        if String.equal (Printf.sprintf "consumes_produces.%s"
                           (B.string_of_action a)) t.name then
          Fmt.pr "    consumes: got [%s] want [%s]; produces: got [%s] want [%s]@."
            (kinds_to_s (A.consumes_of_action a)) (kinds_to_s exp_c)
            (kinds_to_s (A.produces_of_action a)) (kinds_to_s exp_p)));
  let passed = List.count results ~f:snd in
  let total = List.length results in
  Fmt.pr "@.Project-definition layer tests: %d/%d passed.@." passed total;
  passed = total
