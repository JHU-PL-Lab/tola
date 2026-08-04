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
module Mech = Canary_mechanism

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

(* scenario coverage — logical stages + three-way marks. The covered set
   runs Probe_app (build path), NOT Probe_binding; the `run_app` logical
   stage must still be Covered (the realization merge — tiny's case). *)
let coverage_test : pure_test =
  { name = "coverage.logical_and_three_way";
    check = (fun () ->
      let module CV = Canary_scenario_coverage in
      let covered =
        B.[ Fetch Lib; Fetch (Binding ocaml); Probe_app { lang = ocaml };
            Probe_lib ]
      in
      let disabled = [ "build_lib" ] (* config overrides an unspec stage *) in
      let rows = CV.coverage ~langs:[ ocaml ] ~covered ~disabled in
      let mark label =
        List.find_map rows ~f:(fun ((st : CV.stage), m) ->
            if String.equal st.label label then Some m else None)
      in
      Poly.equal (mark "fetch_lib") (Some CV.Covered)
      (* run_app Covered via Probe_app — the realization merge *)
      && Poly.equal (mark "run_app_ocaml") (Some CV.Covered)
      && Poly.equal (mark "build_lib") (Some CV.Disabled)
      && Poly.equal (mark "publish_lib") (Some CV.Unspecified)
      && Poly.equal (mark "build_binding_ocaml") (Some CV.Unspecified)) }

(* §4.2.1b round 1: mechanism/discipline vocabulary. Only Static is wired
   (OCaml=cstubs, Python=cext); the Dynamic constructors are typed but not
   produced. Locks the static defaults + the discipline map. *)
let mechanism_test : pure_test =
  { name = "mechanism.static_defaults_and_discipline";
    check = (fun () ->
      let module M = Canary_mechanism in
      Poly.equal (M.default_mechanism_of_lang L.OCaml) (Some M.Cstubs)
      && Poly.equal (M.default_mechanism_of_lang L.Python) (Some M.Cext)
      && Poly.equal (M.discipline_of_mechanism M.Cstubs) M.Static_c_abi
      && Poly.equal (M.discipline_of_mechanism M.Cext) M.Static_c_abi
      && Poly.equal (M.discipline_of_mechanism M.Ctypes) M.Dynamic_ffi
      && Poly.equal (M.discipline_of_mechanism M.Dynlink) M.Dynamic_ffi
      && M.is_static_binding_lang L.OCaml && M.is_static_binding_lang L.Python
      (* round 1: unmodeled languages carry no mechanism yet *)
      && Poly.equal (M.default_mechanism_of_lang L.Rust) None
      && not (M.is_static_binding_lang L.Rust)) }

(* §4.2 enumeration core: one product-then-filter engine, two orthogonal
   projections. Pins the shape of each projection + the dependency filter. *)
let enumerate_test : pure_test =
  { name = "enumerate.two_projections_and_filter";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let artifacts = EN.[ a_source; a_lib; a_binding ocaml Mech.Cstubs ] in
      let all_built (p : string EN.point) =
        List.for_all p.assignment ~f:(fun (_, pl) ->
            EN.equal_provision pl.EN.provision EN.Built)
      in
      (* tiny projection: all-Built × (positive + 2 mutations) = 3 points,
         one positive, every assignment all-Built. *)
      let muts =
        EN.[ (a_lib, "symbol_missing"); (a_binding ocaml Mech.Cstubs, "type_broken") ]
      in
      let tiny = EN.tiny_slice ~artifacts ~mutations:muts in
      let tiny_ok =
        List.length tiny = 3
        && List.count tiny ~f:(fun p -> Option.is_none p.EN.mutation) = 1
        && List.for_all tiny ~f:all_built
      in
      (* general projection: mutation=none, walk provisions; all-Fetched
         and all-Built assignments both present. *)
      let gen =
        EN.general_slice ~artifacts ~provisions:EN.[ Fetched; Built ]
          ~versions:B.single_channel
      in
      let has_uniform target =
        List.exists gen ~f:(fun p ->
            List.for_all p.EN.assignment ~f:(fun (_, pl) ->
                EN.equal_provision pl.EN.provision target))
      in
      let gen_ok =
        List.for_all gen ~f:(fun p -> Option.is_none p.EN.mutation)
        && has_uniform EN.Fetched && has_uniform EN.Built
      in
      (* filter: with Absent allowed, a provided binding over an Absent lib
         must be pruned. *)
      let gen2 =
        EN.general_slice ~artifacts ~provisions:EN.[ Absent; Fetched; Built ]
          ~versions:B.single_channel
      in
      let no_orphan_binding =
        List.for_all gen2 ~f:(fun p ->
            not
              (EN.provided p.EN.assignment (EN.a_binding ocaml Mech.Cstubs)
              && not (EN.provided p.EN.assignment EN.a_lib)))
      in
      tiny_ok && gen_ok && no_orphan_binding) }

(* §4.2 config levels: one algorithm, per-axis Free/Subset/Full. tiny and
   general are two configs; a mixed Subset config sits between them. *)
let config_level_test : pure_test =
  { name = "enumerate.config_levels";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let artifacts = EN.[ a_source; a_lib; a_binding ocaml Mech.Cstubs ] in
      let muts =
        EN.[ (a_lib, "m1"); (a_binding ocaml Mech.Cstubs, "m2") ]
      in
      (* tiny config: provision/version Free, mutation Full → 1 pos + 2 *)
      let tiny =
        EN.run_config ~artifacts ~all_provisions_of:(fun _ -> [ EN.Built ])
          ~all_versions:B.single_channel ~all_mutations:muts
          { provision = EN.Free; version = EN.Free; mutation = EN.Full }
      in
      (* general config: provision Full, mutation Free → all positive *)
      let gen =
        EN.run_config ~artifacts ~all_provisions_of:(fun _ -> EN.[ Fetched; Built ])
          ~all_versions:B.single_channel ~all_mutations:muts
          { provision = EN.Full; version = EN.Full; mutation = EN.Free }
      in
      (* mixed: provision Subset [Fetched] (all-Fetched only), mutation
         Subset [m1] (positive + exactly m1) *)
      let mixed =
        EN.run_config ~artifacts ~all_provisions_of:(fun _ -> EN.[ Absent; Fetched; Built ])
          ~all_versions:B.single_channel ~all_mutations:muts
          { provision = EN.Subset [ EN.Fetched ]; version = EN.Free;
            mutation = EN.Subset [ List.hd_exn muts ] }
      in
      (* the two canonical wrappers equal their configs (backward compat) *)
      let wrappers_agree =
        Poly.equal tiny (EN.tiny_slice ~artifacts ~mutations:muts)
        && Poly.equal gen
             (EN.general_slice ~artifacts ~provisions:EN.[ Fetched; Built ]
                ~versions:B.single_channel)
      in
      List.length tiny = 3
      && List.for_all gen ~f:(fun p -> Option.is_none p.EN.mutation)
      && List.for_all mixed ~f:(fun p ->
             List.for_all p.EN.assignment ~f:(fun (_, pl) ->
                 EN.equal_provision pl.EN.provision EN.Fetched))
      && List.count mixed ~f:(fun p -> Option.is_some p.EN.mutation) = 1
      && List.count mixed ~f:(fun p -> Option.is_none p.EN.mutation) = 1
      && wrappers_agree) }

(* §4.2.2 version axis: per-slot version enables cross-slot mismatch, and
   the source-primary filter keeps a Built lib's version = its source's. *)
let version_axis_test : pure_test =
  { name = "enumerate.version_axis";
    check = (fun () ->
      let module EN = Canary_enumerate in
      (* two fetched artifacts, two versions each → the mismatch lib@Dev /
         binding@Stable is a valid assignment (the z3/llvm case). *)
      let mm_artifacts = EN.[ a_lib; a_binding ocaml Mech.Cstubs ] in
      let mm =
        EN.run_config ~artifacts:mm_artifacts ~all_provisions_of:(fun _ -> [ EN.Fetched ])
          ~all_versions:B.two_channels ~all_mutations:[]
          { provision = EN.Full; version = EN.Full; mutation = EN.Free }
      in
      let has_mismatch =
        List.exists mm ~f:(fun p ->
            EN.equal_version (EN.version_of p.EN.assignment EN.a_lib) (EN.good B.Dev)
            && EN.equal_version
                 (EN.version_of p.EN.assignment (EN.a_binding ocaml Mech.Cstubs))
                 (EN.good B.Stable))
      in
      (* source-primary: a Built lib inherits the source's version, so every
         surviving assignment has lib.version = source.version (the
         Dev-lib-over-Stable-source combos are pruned). *)
      let built =
        EN.run_config ~artifacts:EN.[ a_source; a_lib ]
          ~all_provisions_of:(fun _ -> [ EN.Built ]) ~all_versions:B.two_channels
          ~all_mutations:[]
          { provision = EN.Full; version = EN.Full; mutation = EN.Free }
      in
      let source_primary_holds =
        (not (List.is_empty built))
        && List.for_all built ~f:(fun p ->
               EN.equal_version
                 (EN.version_of p.EN.assignment EN.a_lib)
                 (EN.version_of p.EN.assignment EN.a_source))
      in
      has_mismatch && source_primary_holds) }

(* A1: PER-ARTIFACT provisions — the sqlite shape (source Fetched-only, lib
   {Fetched,Built}, binding Fetched). Only lib varies; source/binding are never
   Built. A single GLOBAL provision universe couldn't express this — it would
   also emit Built source / Built binding. *)
let per_artifact_provisions_test : pure_test =
  { name = "enumerate.per_artifact_provisions";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_ocaml = EN.a_binding ocaml Mech.Cstubs in
      let artifacts = EN.[ a_source; a_lib; a_ocaml ] in
      let provisions_of id =
        if EN.equal_artifact_id id EN.a_lib then EN.[ Fetched; Built ]
        else EN.[ Fetched ]
      in
      let pts =
        EN.run_config ~artifacts ~all_provisions_of:provisions_of
          ~all_versions:B.single_channel ~all_mutations:[]
          { provision = EN.Full; version = EN.Full; mutation = EN.Free }
      in
      let always target id =
        List.for_all pts ~f:(fun p ->
            EN.equal_provision (EN.provision_of p.EN.assignment id) target)
      in
      let lib_is p = EN.provision_of p.EN.assignment EN.a_lib in
      (not (List.is_empty pts))
      && always EN.Fetched EN.a_source          (* source never Built *)
      && always EN.Fetched a_ocaml              (* binding never Built *)
      && List.exists pts ~f:(fun p -> EN.equal_provision (lib_is p) EN.Fetched)
      && List.exists pts ~f:(fun p -> EN.equal_provision (lib_is p) EN.Built)) }

(* A2: point→assignment fold — the mutation folds into the target artifact's
   version quality=Bad tag; other artifacts stay Good; a positive point is
   unchanged. *)
let point_fold_test : pure_test =
  { name = "enumerate.point_to_assignment_fold";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_ocaml = EN.a_binding ocaml Mech.Cstubs in
      (* a_source needed: tiny_slice is all-Built, and a Built lib requires the
         source present (assignment_ok). *)
      let artifacts = EN.[ a_source; a_lib; a_ocaml ] in
      let pts =
        EN.tiny_slice ~artifacts ~mutations:EN.[ (a_lib, "Bs.4") ]
      in
      let is_bad a id t =
        match EN.placement_of a id with
        | Some { EN.version = { EN.quality = EN.Bad tag; _ }; _ } ->
            String.equal tag t
        | _ -> false
      in
      let is_good a id =
        match EN.placement_of a id with
        | Some { EN.version = { EN.quality = EN.Good; _ }; _ } -> true
        | _ -> false
      in
      let fold = EN.assignment_of_point ~tag:Fn.id in
      let mutated =
        List.find pts ~f:(fun p -> Option.is_some p.EN.mutation)
      in
      let positive =
        List.find pts ~f:(fun p -> Option.is_none p.EN.mutation)
      in
      match mutated, positive with
      | Some pm, Some pp ->
          let am = fold pm and ap = fold pp in
          is_bad am EN.a_lib "Bs.4" && is_good am a_ocaml  (* target Bad, rest Good *)
          && is_good ap EN.a_lib && is_good ap a_ocaml     (* positive all Good *)
      | _ -> false) }

(* A3: a DECLARED project_spec enumerates the sqlite shape — self-contained Built
   (no a_source declared), lib={Fetched,Built}, binding=Fetched. Two assignments;
   the Built one carries the binding (Fetched) — NOT lib-only. This is the
   convergence changing sqlite: the binding-over-built-lib scenario appears. *)
let project_spec_test : pure_test =
  { name = "enumerate.project_spec_sqlite_shape";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_oc = EN.a_binding ocaml Mech.Cstubs in
      let spec : unit EN.project_spec =
        { ps_artifacts = [ EN.a_lib; a_oc ];
          ps_provisions_of =
            (fun id ->
              if EN.equal_artifact_id id EN.a_lib then EN.[ Fetched; Built ]
              else EN.[ Fetched ]);
          ps_versions = B.single_channel;
          ps_mutations = [];
          ps_config = { provision = EN.Full; version = EN.Full; mutation = EN.Free } }
      in
      let asgs = EN.assignments_of_spec ~tag:(fun () -> "") spec in
      let lib_is a = EN.provision_of a EN.a_lib in
      List.length asgs = 2
      && List.exists asgs ~f:(fun a -> EN.equal_provision (lib_is a) EN.Fetched)
      && List.exists asgs ~f:(fun a ->
             EN.equal_provision (lib_is a) EN.Built
             && EN.equal_provision (EN.provision_of a a_oc) EN.Fetched)) }

(* P2b spike: [lower_expectation_agnostic] derives a scenario's expectation
   from the bindings table + (action, loc) ALONE — no per-scenario [violates].
   For a c1-OCaml binding it must produce Expect_compat_failure carrying c1's
   inputs at the OCaml probe (canary discovers c1, nobody tells it), and
   Expect_success at a non-firing action. *)
let agnostic_expectation_test : pure_test =
  { name = "scenario.lower_expectation_agnostic_c1";
    check = (fun () ->
      let module CS = Canary_scenario in
      let module CC = Canary_compat in
      let module SM = Canary_step_model in
      let bindings =
        CS.[ { contract = CC.C1; lang = ocaml;
               firings =
                 [ { site = At_probe_binding ocaml; loc_filter = Any;
                     source = From_artifact {
                       inputs = CC.[ C_stub [ "stub.json" ];
                                     Native_lib [ "lib.json" ] ];
                       version_info = None } } ] } ]
      in
      let lower = CS.lower_expectation_agnostic ~bindings ~langs:[ ocaml ] in
      let derived_c1 =
        match lower (B.Probe_binding ocaml) None with
        | SM.Expect_compat_derived { inputs; _ } ->
            List.exists inputs ~f:(function CC.C_stub _ -> true | _ -> false)
            && List.exists inputs ~f:(function CC.Native_lib _ -> true | _ -> false)
        | _ -> false
      in
      let build_ok =
        match lower B.Build_lib None with
        | SM.Expect_success -> true
        | _ -> false
      in
      derived_c1 && build_ok) }

let all_tests : pure_test list =
  catalogue_tests
  @ [ probe_invariant; inventory_test;
      derive_fetch_lib_test; surface_split_test;
      s2_raw_identity_test; detect_simple_test; coverage_test;
      mechanism_test; enumerate_test; config_level_test; version_axis_test;
      per_artifact_provisions_test; point_fold_test; project_spec_test;
      agnostic_expectation_test ]

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
