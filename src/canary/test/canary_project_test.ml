open Base

(* Project-definition layer tests (design: ssot.md §6.1).

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
    (Probe_binding ocaml,             [ Lib; Binding ocaml ],[]);
    (Probe_app { lang = ocaml },      [ App; Lib; Binding ocaml ], []);
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
          lib = Some { SC.provider = SC.Sys_pkg sys; components = []; headers = None } }
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
      let module Api = Canary_artifact in
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
      && Canary_mechanism.is_static_binding_lang L.OCaml && Canary_mechanism.is_static_binding_lang L.Python
      (* round 1: unmodeled languages carry no mechanism yet *)
      && Poly.equal (M.default_mechanism_of_lang L.Rust) None
      && not (Canary_mechanism.is_static_binding_lang L.Rust)) }

(* §4.2 enumeration core: one product-then-filter engine, two orthogonal
   projections. Pins the shape of each projection + the dependency filter. *)
let enumerate_test : pure_test =
  { name = "enumerate.two_projections_and_filter";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let artifacts = EN.[ a_source; a_lib; a_binding ocaml Mech.Cstubs ] in
      let all_built (p : string EN.point) =
        List.for_all p.assignment ~f:(fun (_, pl) ->
            EN.equal_provision pl.Canary_artifact.provision EN.Built)
      in
      (* tiny projection: all-Built × (positive + 2 mutations) = 3 points,
         one positive, every assignment all-Built. *)
      let muts =
        EN.[ (a_lib, "symbol_missing"); (a_binding ocaml Mech.Cstubs, "type_broken") ]
      in
      let tiny = EN.tiny_slice ~artifacts ~mutations:muts in
      let tiny_ok =
        List.length tiny = 3
        && List.count tiny ~f:(fun p -> List.is_empty p.EN.mutations) = 1
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
                EN.equal_provision pl.Canary_artifact.provision target))
      in
      let gen_ok =
        List.for_all gen ~f:(fun p -> List.is_empty p.EN.mutations)
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
              (EN.provided p.EN.assignment (Canary_artifact.a_binding ocaml Mech.Cstubs)
              && not (EN.provided p.EN.assignment Canary_artifact.a_lib)))
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
          ~all_versions_of:(fun _ _ -> [ B.good B.Dev ]) ~all_mutations:muts
          { provision = EN.Free; version = EN.Free; mutation = EN.Full; version_mode = EN.Lockstep; shadow = EN.Shadow_prebuilt; refs = EN.All_refs }
      in
      (* general config: provision Full, mutation Free → all positive *)
      let gen =
        EN.run_config ~artifacts ~all_provisions_of:(fun _ -> EN.[ Fetched; Built ])
          ~all_versions_of:(fun _ _ -> [ B.good B.Dev ]) ~all_mutations:muts
          { provision = EN.Full; version = EN.Full; mutation = EN.Free; version_mode = EN.Lockstep; shadow = EN.Shadow_prebuilt; refs = EN.All_refs }
      in
      (* mixed: provision Subset [Fetched] (all-Fetched only), mutation
         Subset [m1] (positive + exactly m1) *)
      let mixed =
        EN.run_config ~artifacts ~all_provisions_of:(fun _ -> EN.[ Absent; Fetched; Built ])
          ~all_versions_of:(fun _ _ -> [ B.good B.Dev ]) ~all_mutations:muts
          { provision = EN.Subset [ EN.Fetched ]; version = EN.Free;
            mutation = EN.Subset [ List.hd_exn muts ]; version_mode = EN.Lockstep; shadow = EN.Shadow_prebuilt; refs = EN.All_refs }
      in
      (* the two canonical wrappers equal their configs (backward compat) *)
      let wrappers_agree =
        Poly.equal tiny (EN.tiny_slice ~artifacts ~mutations:muts)
        && Poly.equal gen
             (EN.general_slice ~artifacts ~provisions:EN.[ Fetched; Built ]
                ~versions:B.single_channel)
      in
      List.length tiny = 3
      && List.for_all gen ~f:(fun p -> List.is_empty p.EN.mutations)
      && List.for_all mixed ~f:(fun p ->
             List.for_all p.EN.assignment ~f:(fun (_, pl) ->
                 EN.equal_provision pl.Canary_artifact.provision EN.Fetched))
      && List.count mixed ~f:(fun p -> not (List.is_empty p.EN.mutations)) = 1
      && List.count mixed ~f:(fun p -> List.is_empty p.EN.mutations) = 1
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
          ~all_versions_of:(fun _ _ -> List.map B.two_channels ~f:B.good) ~all_mutations:[]
          { provision = EN.Full; version = EN.Full; mutation = EN.Free; version_mode = EN.Lockstep; shadow = EN.Shadow_prebuilt; refs = EN.All_refs }
      in
      let has_mismatch =
        List.exists mm ~f:(fun p ->
            Canary_basic.equal_version (EN.version_of p.EN.assignment Canary_artifact.a_lib) (Canary_basic.good B.Dev)
            && Canary_basic.equal_version
                 (EN.version_of p.EN.assignment (Canary_artifact.a_binding ocaml Mech.Cstubs))
                 (Canary_basic.good B.Stable))
      in
      (* source-primary: a Built lib inherits the source's version, so every
         surviving assignment has lib.version = source.version (the
         Dev-lib-over-Stable-source combos are pruned). *)
      let built =
        EN.run_config ~artifacts:EN.[ a_source; a_lib ]
          ~all_provisions_of:(fun _ -> [ EN.Built ]) ~all_versions_of:(fun _ _ -> List.map B.two_channels ~f:B.good)
          ~all_mutations:[]
          { provision = EN.Full; version = EN.Full; mutation = EN.Free; version_mode = EN.Lockstep; shadow = EN.Shadow_prebuilt; refs = EN.All_refs }
      in
      let source_primary_holds =
        (not (List.is_empty built))
        && List.for_all built ~f:(fun p ->
               Canary_basic.equal_version
                 (EN.version_of p.EN.assignment Canary_artifact.a_lib)
                 (EN.version_of p.EN.assignment Canary_artifact.a_source))
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
      let a_ocaml = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let artifacts = EN.[ a_source; a_lib; a_ocaml ] in
      let provisions_of id =
        if Canary_artifact.equal_artifact_id id Canary_artifact.a_lib then EN.[ Fetched; Built ]
        else EN.[ Fetched ]
      in
      let pts =
        EN.run_config ~artifacts ~all_provisions_of:provisions_of
          ~all_versions_of:(fun _ _ -> [ B.good B.Dev ]) ~all_mutations:[]
          { provision = EN.Full; version = EN.Full; mutation = EN.Free; version_mode = EN.Lockstep; shadow = EN.Shadow_prebuilt; refs = EN.All_refs }
      in
      let always target id =
        List.for_all pts ~f:(fun p ->
            EN.equal_provision (EN.provision_of p.EN.assignment id) target)
      in
      let lib_is p = EN.provision_of p.EN.assignment Canary_artifact.a_lib in
      (not (List.is_empty pts))
      && always EN.Fetched Canary_artifact.a_source          (* source never Built *)
      && always EN.Fetched a_ocaml              (* binding never Built *)
      && List.exists pts ~f:(fun p -> EN.equal_provision (lib_is p) EN.Fetched)
      && List.exists pts ~f:(fun p -> EN.equal_provision (lib_is p) EN.Built)) }

(* PER-ARTIFACT versions — the version-axis analogue of
   [per_artifact_provisions_test]. Only the lib ranges over two channels; the
   binding is pinned Stable-only. A single GLOBAL version universe couldn't
   express this — it would also emit a Dev binding. Confirms the mismatch
   lib@Dev / binding@Stable survives while binding@Dev never appears. *)
let per_artifact_versions_test : pure_test =
  { name = "enumerate.per_artifact_versions";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_ocaml = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let artifacts = EN.[ a_lib; a_ocaml ] in
      let versions_of id _pv =
        if Canary_artifact.equal_artifact_id id Canary_artifact.a_lib
        then List.map B.two_channels ~f:B.good
        else [ B.good B.Dev ]                        (* binding: Dev only *)
      in
      let pts =
        EN.run_config ~artifacts ~all_provisions_of:(fun _ -> [ EN.Fetched ])
          ~all_versions_of:versions_of ~all_mutations:[]
          { provision = EN.Full; version = EN.Full; mutation = EN.Free; version_mode = EN.Lockstep; shadow = EN.Shadow_prebuilt; refs = EN.All_refs }
      in
      let binding_ver p = EN.version_of p.EN.assignment a_ocaml in
      (not (List.is_empty pts))
      (* binding is pinned Dev in every assignment (its per-artifact axis) *)
      && List.for_all pts ~f:(fun p ->
             Canary_basic.equal_version (binding_ver p) (Canary_basic.good B.Dev))
      (* the lib@Stable / binding@Dev mismatch is present (lib's wider axis) *)
      && List.exists pts ~f:(fun p ->
             Canary_basic.equal_version (EN.version_of p.EN.assignment Canary_artifact.a_lib) (Canary_basic.good B.Stable))) }

(* A2: point→assignment fold — the mutation folds into the target artifact's
   version quality=Bad tag; other artifacts stay Good; a positive point is
   unchanged. *)
let point_fold_test : pure_test =
  { name = "enumerate.point_to_assignment_fold";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_ocaml = Canary_artifact.a_binding ocaml Mech.Cstubs in
      (* a_source needed: tiny_slice is all-Built, and a Built lib requires the
         source present (assignment_ok). *)
      let artifacts = EN.[ a_source; a_lib; a_ocaml ] in
      let pts =
        EN.tiny_slice ~artifacts ~mutations:EN.[ (a_lib, "Bs.4") ]
      in
      let is_bad a id t =
        match EN.placement_of a id with
        | Some { Canary_artifact.version = { Canary_basic.quality = Canary_basic.Bad tag; _ }; _ } ->
            String.equal tag t
        | _ -> false
      in
      let is_good a id =
        match EN.placement_of a id with
        | Some { Canary_artifact.version = { Canary_basic.quality = Canary_basic.Good; _ }; _ } -> true
        | _ -> false
      in
      let fold = EN.assignment_of_point ~tag:Fn.id in
      let mutated =
        List.find pts ~f:(fun p -> not (List.is_empty p.EN.mutations))
      in
      let positive =
        List.find pts ~f:(fun p -> List.is_empty p.EN.mutations)
      in
      match mutated, positive with
      | Some pm, Some pp ->
          let am = fold pm and ap = fold pp in
          is_bad am Canary_artifact.a_lib "Bs.4" && is_good am a_ocaml  (* target Bad, rest Good *)
          && is_good ap Canary_artifact.a_lib && is_good ap a_ocaml     (* positive all Good *)
      | _ -> false) }

(* A3: a DECLARED project_spec enumerates the sqlite shape — self-contained Built
   (no a_source declared), lib={Fetched,Built}, binding=Fetched. Two assignments;
   the Built one carries the binding (Fetched) — NOT lib-only. This is the
   convergence changing sqlite: the binding-over-built-lib scenario appears. *)
let project_spec_test : pure_test =
  { name = "enumerate.project_spec_sqlite_shape";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_oc = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let spec : Canary_artifact.project_spec =
        { ps_universe =
            [ ( Canary_artifact.a_lib,
                Canary_artifact.(axes [ (Fetched, B.single_channel); (Built, B.single_channel) ]) );
              (a_oc, Canary_artifact.(axes [ (Fetched, B.single_channel) ])) ] }
      in
      let asgs =
        EN.enumerate ~tag:(fun () -> "") ~policy:(EN.full_policy ()) spec
      in
      let lib_is a = EN.provision_of a Canary_artifact.a_lib in
      List.length asgs = 2
      && List.exists asgs ~f:(fun a -> EN.equal_provision (lib_is a) EN.Fetched)
      && List.exists asgs ~f:(fun a ->
             EN.equal_provision (lib_is a) EN.Built
             && EN.equal_provision (EN.provision_of a a_oc) EN.Fetched)) }

(* PER-PROVISION versions — the version universe depends on HOW the artifact
   is provided (the faithful-combination refinement): a Fetched lib is
   version-ambient (one representative), only the Built lib ranges over
   channels. The sqlite shape: exactly 3 worlds (F@S, B@S, B@D) — no
   Fetched@Dev that would only dedup away downstream, and no Dev binding. *)
let per_provision_versions_test : pure_test =
  { name = "enumerate.per_provision_versions";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_oc = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let spec : Canary_artifact.project_spec =
        { ps_universe =
            [ ( Canary_artifact.a_lib,
                Canary_artifact.(axes [ (Fetched, B.single_channel); (Built, B.two_channels) ]) );
              (a_oc, Canary_artifact.(axes [ (Fetched, B.single_channel) ])) ] }
      in
      let asgs =
        EN.enumerate ~tag:(fun () -> "") ~policy:(EN.full_policy ()) spec
      in
      let lib_pl a = Option.value_exn (EN.placement_of a Canary_artifact.a_lib) in
      let has prov chan =
        List.exists asgs ~f:(fun a ->
            let pl = lib_pl a in
            EN.equal_provision pl.Canary_artifact.provision prov
            && Canary_basic.equal_version pl.Canary_artifact.version (Canary_basic.good chan))
      in
      List.length asgs = 3
      && has EN.Fetched B.Dev              (* the ambient representative *)
      && has EN.Built B.Dev && has EN.Built B.Stable
      (* Fetched never ranges: no second Fetched world *)
      && List.count asgs ~f:(fun a ->
             EN.equal_provision (lib_pl a).Canary_artifact.provision EN.Fetched) = 1) }

(* THIN as a CONFIG level, not a filter: version [Subset [Stable]] on the tiny
   shape (lib {Vendored,Built}, Vendored Stable-only, Built {Stable,Dev})
   narrows 3 worlds → 2; the Full policy keeps all 3 with no Vendored@Dev. *)
let thin_config_level_test : pure_test =
  { name = "enumerate.thin_is_version_subset";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_oc = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let spec : Canary_artifact.project_spec =
        { ps_universe =
            [ ( Canary_artifact.a_lib,
                Canary_artifact.(axes [ (Vendored, [ B.Stable ]); (Built, [ B.Stable; B.Dev ]) ]) );
              (a_oc, Canary_artifact.(axes [ (Vendored, [ B.Stable ]) ])) ] }
      in
      let full =
        EN.enumerate ~tag:(fun () -> "") ~policy:(EN.full_policy ()) spec
      in
      let thin =
        EN.enumerate ~tag:(fun () -> "")
          ~policy:
            { config =
                Canary_enumerate.{ provision = Full;
                     version = Subset [ B.Stable ];
                     mutation = Free; version_mode = EN.Lockstep; shadow = EN.Shadow_prebuilt; refs = EN.All_refs };              mutations = [] }
          spec
      in
      let no_dev asgs =
        List.for_all asgs ~f:(fun a ->
            List.for_all a ~f:(fun (_, (pl : EN.placement)) ->
                match pl.Canary_artifact.version.Canary_basic.channel with
                | B.Stable -> true
                | B.Dev ->
                    EN.equal_provision pl.Canary_artifact.provision EN.Built))
      in
      List.length full = 3 && no_dev full   (* Dev only on the Built lib *)
      && List.length thin = 2
      && List.for_all thin ~f:(fun a ->
             List.for_all a ~f:(fun (_, (pl : EN.placement)) ->
                 match pl.Canary_artifact.version.Canary_basic.channel with
                 | B.Stable -> true
                 | B.Dev -> false))) }

(* SHADOW policy (2026-08-17, active plan 3): a prebuilt lib shadows a
   Built one for the SAME cell — the firing condition is identity-bearing:
   the Built side's version id is SOURCE-PRIMARY (the source's pin), both
   ids must be non-empty and equal, and the channels must match. Same cell
   (Fetched@1.0.0 + Built@Stable over a 1.0.0-pinned source) drops the
   Built world under Shadow_prebuilt, keeps both under Materialize_source;
   DIFFERENT cells (Fetched@Stable + Built@Dev — the z3 shape) never
   shadow in either policy (the z3 dev chain builds from a dev checkout,
   so the built cell's source-primary id differs from the stable prebuilt
   pin's). *)
let shadow_policy_drops_same_cell_built_test : pure_test =
  { name = "enumerate.shadow_policy_drops_same_cell_built";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_oc = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let pin_1 =
        { Canary_basic.channel = B.Stable; id = "1.0.0"; quality = Canary_basic.Good }
      in
      (* SAME cell: prebuilt + built share the pin's id and channel. *)
      let same_cell_spec : Canary_artifact.project_spec =
        { ps_universe =
            [ ( Canary_artifact.a_source,
                Canary_artifact.(axes ~pins:[ pin_1 ] [ (Fetched, [ B.Stable ]) ]) );
              ( Canary_artifact.a_lib,
                Canary_artifact.(
                  axes ~pins:[ pin_1 ]
                    [ (Fetched, [ B.Stable ]); (Built, [ B.Stable ]) ]) );
              (a_oc, Canary_artifact.(axes [ (Fetched, [ B.Stable ]) ])) ] }
      in
      let shadowed =
        EN.enumerate ~tag:(fun () -> "") ~policy:(EN.full_policy ()) same_cell_spec
      in
      let materializing =
        EN.enumerate ~tag:(fun () -> "")
          ~policy:
            { config =
                { (EN.full_policy ()).config with shadow = EN.Materialize_source };
              mutations = [] }
          same_cell_spec
      in
      (* DIFFERENT cells: prebuilt Stable (pin "1.0.0") vs built Dev over a
         Dev-pinned source ("dev-src") — the z3 shape (the dev chain builds
         from a dev checkout; the prebuilt is the stable release). The
         built side's id differs from the prebuilt's, so no shadowing in
         either policy. *)
      let pin_dev =
        { Canary_basic.channel = B.Dev; id = "dev-src"; quality = Canary_basic.Good }
      in
      let diff_cell_spec : Canary_artifact.project_spec =
        { ps_universe =
            [ ( Canary_artifact.a_source,
                Canary_artifact.(axes ~pins:[ pin_dev ] [ (Fetched, [ B.Dev ]) ]) );
              ( Canary_artifact.a_lib,
                Canary_artifact.(
                  axes ~pins:[ pin_1 ]
                    [ (Fetched, [ B.Stable ]); (Built, [ B.Dev ]) ]) );
              (a_oc, Canary_artifact.(axes [ (Fetched, [ B.Stable ]) ])) ] }
      in
      let diff_shadowed =
        EN.enumerate ~tag:(fun () -> "") ~policy:(EN.full_policy ()) diff_cell_spec
      in
      let diff_materializing =
        EN.enumerate ~tag:(fun () -> "")
          ~policy:
            { config =
                { (EN.full_policy ()).config with shadow = EN.Materialize_source };
              mutations = [] }
          diff_cell_spec
      in
      let lib_prov a = EN.provision_of a Canary_artifact.a_lib in
      (* same cell: the prebuilt shadows the built under Shadow_prebuilt *)
      List.length shadowed = 1
      && List.exists shadowed ~f:(fun a -> EN.equal_provision (lib_prov a) EN.Fetched)
      (* …and the audit pass materializes both *)
      && List.length materializing = 2
      && List.exists materializing ~f:(fun a -> EN.equal_provision (lib_prov a) EN.Built)
      (* different cells: no shadowing in either policy (both worlds live) *)
      && List.length diff_shadowed = 2 && List.length diff_materializing = 2) }

(* REFS subset (2026-08-17, the z3 #10549 regression case): [Refs ids]
   keeps the source-repo worlds whose pinned id is selected — the
   [--refs latest,pre-10549] pair. Unpinned/absent sources pass through
   (the filter selects on repo PIN identity; inert elsewhere). *)
let refs_subset_test : pure_test =
  { name = "enumerate.refs_subset";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_oc = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let pin id =
        { Canary_basic.channel = B.Stable; id; quality = Canary_basic.Good }
      in
      let spec : Canary_artifact.project_spec =
        { ps_universe =
            [ ( Canary_artifact.a_source,
                Canary_artifact.(
                  axes ~pins:[ pin "latest"; pin "pre-10549" ]
                    [ (Fetched, [ B.Stable ]) ]) );
              ( Canary_artifact.a_lib,
                Canary_artifact.(axes [ (Fetched, [ B.Stable ]) ]) );
              (a_oc, Canary_artifact.(axes [ (Fetched, [ B.Stable ]) ])) ] }
      in
      let count refs =
        EN.enumerate ~tag:(fun () -> "")
          ~policy:
            { config = { (EN.full_policy ()).config with refs }; mutations = [] }
          spec
        |> List.length
      in
      let src_id a =
        (EN.version_of a Canary_artifact.a_source).Canary_basic.id
      in
      (* All_refs: both repo worlds *)
      count EN.All_refs = 2
      && count (EN.Refs [ "latest" ]) = 1
      && count (EN.Refs [ "latest"; "pre-10549" ]) = 2
      && count (EN.Refs [ "no-such-ref" ]) = 0
      (* the survivor is the SELECTED repo *)
      && (match
           EN.enumerate ~tag:(fun () -> "")
             ~policy:
               { config =
                   { (EN.full_policy ()).config with refs = EN.Refs [ "pre-10549" ] };
                 mutations = [] }
             spec
         with
         | [ a ] -> String.equal (src_id a) "pre-10549"
         | _ -> false)
      (* DECLARED-but-UNPINNED sources pass through (inert — an ambient
         id is no repo ref to select on) *)
      && (let unpinned : Canary_artifact.project_spec =
            { ps_universe =
                [ ( Canary_artifact.a_source,
                    Canary_artifact.(axes [ (Fetched, [ B.Stable ]) ]) );
                  ( Canary_artifact.a_lib,
                    Canary_artifact.(axes [ (Fetched, [ B.Stable ]) ]) );
                  (a_oc, Canary_artifact.(axes [ (Fetched, [ B.Stable ]) ])) ] }
          in
          EN.enumerate ~tag:(fun () -> "")
            ~policy:
              { config =
                  { (EN.full_policy ()).config with refs = EN.Refs [ "latest" ] };
                mutations = [] }
            unpinned
          |> List.length = 1)
      (* an ABSENT source (self-contained world) also passes *)
      && (let sourceless : Canary_artifact.project_spec =
            { ps_universe =
                [ ( Canary_artifact.a_lib,
                    Canary_artifact.(axes [ (Fetched, [ B.Stable ]) ]) );
                  (a_oc, Canary_artifact.(axes [ (Fetched, [ B.Stable ]) ])) ] }
          in
          EN.enumerate ~tag:(fun () -> "")
            ~policy:
              { config =
                  { (EN.full_policy ()).config with refs = EN.Refs [ "latest" ] };
                mutations = [] }
            sourceless
          |> List.length = 1)) }

(* The mechanism CATALOGUE (base/canary_mechanism.ml, 2026-08-05): total
   over the mechanism constructors; stored discipline == the derived one
   (the catalogue cannot drift from the vocabulary); each language's
   default mechanism is catalogued as wired; every entry names at least
   one artifact form and one checking point. *)
let mechanism_catalogue_test : pure_test =
  { name = "mechanism.catalogue_total_and_consistent";
    check = (fun () ->
      let all =
        Mech.[ Cstubs; Cext; Ctypes; Cffi; Dynlink ]
      in
      List.for_all all ~f:(fun m ->
          let i = Canary_mechanism.info_of_mechanism m in
          Poly.equal i.Canary_mechanism.mi_mechanism m
          && Poly.equal i.Canary_mechanism.mi_discipline (Mech.discipline_of_mechanism m)
          && (not (List.is_empty i.Canary_mechanism.mi_check_points))
          && not (List.is_empty i.Canary_mechanism.mi_check_points))
      && List.for_all [ L.OCaml; L.Python ] ~f:(fun l ->
             match Mech.default_mechanism_of_lang l with
             | Some m -> (Canary_mechanism.info_of_mechanism m).Canary_mechanism.mi_wired
             | None -> false)) }

(* M2 step 2 pin (2026-08-12): the contract×lang input template equals
   tiny's formerly hand-written rows — the refactor is provably
   no-behavior-change. The template IS the standard; a row added here
   must match the paths the inspect steps actually write. *)
(* M1 typed-template pin (2026-08-14): [Source_fetch]'s [local] field
   restores the old [source_fetch_cmd] behavior — a declared local
   checkout makes fetch a [test -d], no clone (the waste item in
   status_project.md). *)
(* The Cmake_install assert_staged primitive (2026-08-17, the z3
   #10549 regression): each prefix-relative path becomes a [test -f]
   with the "OCAML INSTALL MISSING" signature — ALSO written into
   install_fail.log (output_contains_any reads files, not stderr). *)
let cmake_install_assert_staged_pin : pure_test =
  { name = "templates.cmake_install_assert_staged";
    check = (fun () ->
      let spec =
        Canary_action_templates.realize_template
          (Canary_action_templates.Cmake_install
             { build = "B"; prefix = "P";
               assert_staged =
                 Some [ "lib/ocaml/z3/META"; "lib/ocaml/z3/z3ml.cmxa" ] })
      in
      match spec.Canary_step_builder.install_lib with
      | Some cmd ->
          let cmd = cmd ~output_dir:"OUT" ~variant_key:"vk" in
          String.is_substring cmd
            ~substring:"test -f \"$PREFIX/lib/ocaml/z3/META\""
          && String.is_substring cmd
               ~substring:"OCAML INSTALL MISSING: lib/ocaml/z3/z3ml.cmxa"
          && String.is_substring cmd ~substring:"OUT/install_fail.log"
      | None -> false) }

let source_fetch_local_pin : pure_test =
  { name = "templates.source_fetch_local_skips_clone";
    check = (fun () ->
      let mk ?local () =
        let spec =
          Canary_action_templates.realize_template
            (Canary_action_templates.Source_fetch
               { name = "z3"; ver_str = "dev"; ref_ = "HEAD";
                 url = "https://example.invalid/z3.git"; local })
        in
        match spec.Canary_step_builder.fetch_source with
        | Some cmd -> cmd ~output_dir:"OUT" ~variant_key:"vk"
        | None -> ""
      in
      let with_local = mk ~local:"/home/red/code/contrib/z3-all/z3" () in
      let without_local = mk () in
      String.is_substring with_local ~substring:"test -d"
      && (not (String.is_substring with_local ~substring:"git clone"))
      && String.is_substring without_local ~substring:"git clone") }

let inputs_template_pin : pure_test =
  { name = "mechanism.inputs_template_matches_tiny_convention";
    check = (fun () ->
      let module CC = Canary_compat in
      let template = Canary_compat_run.inputs_of_contract in
      let eq c l expected =
        Poly.equal (template c l) expected
      in
      eq CC.C1 L.OCaml
        CC.[ C_stub [ "build_binding_ocaml/inspect.json" ];
             Native_lib [ "build_lib/inspect.json" ] ]
      && eq CC.C1 L.Python
        CC.[ C_stub [ "build_binding_python/inspect.json" ];
             Native_lib [ "build_lib/inspect.json" ] ]
      && eq CC.C2 L.OCaml
        CC.[ Ocaml_mli [ "build_binding_ocaml/inspect_mli.json" ] ]
      && eq CC.C2 L.Python
        CC.[ Python_attrs [ "build_binding_python/inspect_attrs.json" ] ]
      && eq CC.C4 L.Python
        CC.[ Native_lib [ "build_lib/inspect.json" ];
             Abi_surface [ "build_binding_python/inspect.json" ] ]
      && eq CC.C5 L.Python
        CC.[ Versioned_exports [ "build_lib/inspect.json" ];
             Versioned_req [ "build_binding_python/inspect.json" ] ]
      && eq CC.C6 L.OCaml
        CC.[ Typed_header [ "scan_sources/inspect_typed_header.json" ];
             Typed_binding_stub
               [ "scan_sources/inspect_typed_binding_stub_ocaml.json" ] ]
      && List.is_empty (template CC.C4 L.OCaml)  (* placeholder — no inputs *)
      && List.is_empty (template CC.C8 L.OCaml)) (* blocked — no inputs *) }

(* M2 step 3 pin (2026-08-12): a spec whose ONLY binding is Dynamic_ffi
   (ctypes) gets NO build_binding chain — the enumeration derives the
   stage set from the mechanism key, not from a hardcoded lang guard.
   A spec with a static binding (cext) keeps the build chain. *)
let mechanism_chain_shape_pin : pure_test =
  { name = "mechanism.dynamic_binding_has_no_build_chain";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let dynamic_spec =
        Canary_project_spec.project_spec_of_rows
          [ Canary_project_spec.artifact_row ~artifact:EN.a_lib
              ~universe:[ (EN.Vendored, [ B.Stable ]) ] ();
            Canary_project_spec.artifact_row
              ~artifact:(Canary_artifact.a_binding Canary_lang.Python Canary_mechanism.Ctypes)
              ~universe:[ (EN.Vendored, [ B.Stable ]) ] () ]
      in
      let static_spec =
        Canary_project_spec.project_spec_of_rows
          [ Canary_project_spec.artifact_row ~artifact:EN.a_lib
              ~universe:[ (EN.Vendored, [ B.Stable ]) ] ();
            Canary_project_spec.artifact_row
              ~artifact:(Canary_artifact.a_binding Canary_lang.Python Canary_mechanism.Cext)
              ~universe:[ (EN.Vendored, [ B.Stable ]) ] () ]
      in
      (* find a chain containing build_binding_PYTHON (the first build chain
         is OCaml's — the specs declare Python bindings only) *)
      let build_chain =
        List.find_map EN.universal_chains ~f:(fun (_, chain) ->
          let has_py_build =
            List.exists chain ~f:(fun (a : B.action_sig) ->
              match a.B.as_action with
              | B.Build_binding Canary_lang.Python -> true
              | _ -> false) in
          if has_py_build then Some chain else None)
        |> Option.value ~default:[]
      in
      (* the derivation itself: chain_applicable is the mechanism-aware gate *)
      let dyn_app = EN.chain_applicable dynamic_spec build_chain in
      let stat_app = EN.chain_applicable static_spec build_chain in
      (not dyn_app)
      && stat_app
      && (* both specs still enumerate scenarios *)
      List.length (EN.patterns_of dynamic_spec) > 0
      && List.length (EN.patterns_of static_spec) > 0) }

(* Subset INTERSECTS the universe (found via z3 + thin, A5 phase 2): on a
   z3-shaped spec (lib Fetched@Stable | Built@Dev — Built has NO Stable),
   version Subset [Stable] must NOT fabricate a Built@Stable world; the Built
   provision simply contributes nothing and only the fetch chain remains. *)
let subset_intersects_universe_test : pure_test =
  { name = "enumerate.subset_intersects_universe";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let spec : Canary_artifact.project_spec =
        { ps_universe =
            [ (Canary_artifact.a_source, Canary_artifact.(axes [ (Fetched, B.[ Stable; Dev ]) ]));
              ( Canary_artifact.a_lib,
                Canary_artifact.(axes [ (Fetched, [ B.Stable ]); (Built, [ B.Dev ]) ]) ) ] }
      in
      let thin =
        EN.enumerate ~tag:(fun () -> "")
          ~policy:
            { config =
                Canary_enumerate.{ provision = Full;
                     version = Subset [ B.Stable ];
                     mutation = Free; version_mode = EN.Lockstep; shadow = EN.Shadow_prebuilt; refs = EN.All_refs };              mutations = [] }
          spec
      in
      List.length thin = 1
      && List.for_all thin ~f:(fun a ->
             EN.equal_provision (EN.provision_of a Canary_artifact.a_lib) EN.Fetched)) }

(* Dispatch-coordinate utilities (the dispatch/realization split): a project's
   runner dispatch reads ONLY these general coordinates. [channel_of] reads the
   placed channel; [bad_placements] extracts the Bad-quality (artifact, tag)
   pairs and is [] for a positive scenario. *)
let dispatch_reads_test : pure_test =
  { name = "enumerate.dispatch_coordinate_reads";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_oc = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let pl ?(q = Canary_basic.Good) ch : EN.placement =
        { provision = EN.Vendored; version = { channel = ch; id = ""; quality = q } }
      in
      let good =
        EN.[ (a_lib, pl B.Stable); (a_oc, pl B.Dev) ]
      in
      let bad =
        EN.[ (a_lib, pl ~q:(Canary_basic.Bad "Bs.4") B.Stable); (a_oc, pl B.Stable) ]
      in
      Poly.equal (EN.channel_of good Canary_artifact.a_lib) B.Stable
      && Poly.equal (EN.channel_of good a_oc) B.Dev
      && List.is_empty (EN.bad_placements good)
      && (match EN.bad_placements bad with
          | [ (id, "Bs.4") ] -> Canary_artifact.equal_artifact_id id Canary_artifact.a_lib
          | _ -> false)) }

(* Mismatch direction (named from the CONSUMER's position): consumer@Dev over
   provider@Stable = Forward; consumer@Stable over provider@Dev = Backward;
   same channel or absent = None. *)
let mismatch_direction_test : pure_test =
  { name = "enumerate.mismatch_direction";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_oc = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let pl ch : EN.placement =
        { provision = EN.Vendored; version = { channel = ch; id = ""; quality = Canary_basic.Good } }
      in
      let mk oc lib = EN.[ (a_oc, pl oc); (a_lib, pl lib) ] in
      let dir a = EN.mismatch_direction_of a ~consumer:a_oc ~provider:Canary_artifact.a_lib in
      Poly.equal (dir (mk B.Dev B.Stable)) (Some Canary_basic.Forward)
      && Poly.equal (dir (mk B.Stable B.Dev)) (Some Canary_basic.Backward)
      && Poly.equal (dir (mk B.Stable B.Stable)) None
      && Poly.equal
           (EN.mismatch_direction_of [ (a_oc, pl B.Dev) ] ~consumer:a_oc
              ~provider:Canary_artifact.a_lib)
           None) }

(* Seam (dynamic_enumeration.md): a flat assignment's build edges read off the
   ACTION catalogue agree with the graph's built_from — Built lib←Source, Built
   binding←Lib; a Fetched artifact has no edge. Injects
   Canary_action.consumes_of_action, proving the two representations are one. *)
let built_from_test : pure_test =
  { name = "enumerate.built_from_of_assignment";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let module CA = Canary_action in
      let built_from_kinds (k : B.artifact_kind) : B.artifact_kind list =
        match k with
        | B.Lib -> CA.consumes_of_action B.Build_lib
        | B.Binding l -> CA.consumes_of_action (B.Build_binding l)
        | _ -> []
      in
      let a_oc = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let pl p : EN.placement = { provision = p; version = Canary_basic.good B.Stable } in
      let a =
        EN.[ (a_source, pl Fetched); (a_lib, pl Built); (a_oc, pl Built) ]
      in
      let edges id = EN.built_from_of_assignment ~built_from_kinds a id in
      let one_edge id target =
        match edges id with [ e ] -> Canary_artifact.equal_artifact_id e target | _ -> false
      in
      one_edge Canary_artifact.a_lib Canary_artifact.a_source           (* Built lib ← Source *)
      && one_edge a_oc Canary_artifact.a_lib                (* Built binding ← Lib *)
      && List.is_empty (edges Canary_artifact.a_source)) }  (* Fetched source: no edge *)

(* M3: node_of_assignment lifts a flat chain assignment to the artifact_node
   graph with the full catalogue-derived chain — binding ← lib ← source. (Note:
   make_action_graph under-records this — its Build_lib node omits built_from=
   source, treating source as an implicit root; the seam is the complete view.) *)
let node_of_assignment_test : pure_test =
  { name = "action.node_of_assignment_chain";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let module CA = Canary_action in
      let a_oc = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let pl p : EN.placement = { provision = p; version = Canary_basic.good B.Stable } in
      let a = EN.[ (a_source, pl Fetched); (a_lib, pl Built); (a_oc, pl Built) ] in
      let nodes = CA.node_of_assignment a in
      let find k =
        List.find nodes ~f:(fun (n : CA.artifact_node) -> Poly.equal n.CA.a_kind k)
      in
      let seam_chain =
        match find (B.Binding ocaml) with
        | Some bind -> (
            match bind.CA.built_from with
            | Some libn when Poly.equal libn.CA.a_kind B.Lib -> (
                match libn.CA.built_from with
                | Some srcn -> Poly.equal srcn.CA.a_kind B.Source
                | None -> false)
            | _ -> false)
        | None -> false
      in
      (* make_action_graph now AGREES: its Build_lib node is built_from Source
         (the source-edge fix) — the two representations match on lib←source. *)
      let ar =
        CA.make_action_graph
          ~actions:(CA.store_actions ~langs:[ ocaml ])
          ~versions:[ B.Stable ] ~name:"pkg" ~source:Canary_store.store ()
      in
      let mag_lib_from_source =
        match CA.pool_get ar B.Lib with
        | libn :: _ -> (
            match libn.CA.built_from with
            | Some s -> Poly.equal s.CA.a_kind B.Source
            | None -> false)
        | [] -> false
      in
      seam_chain && mag_lib_from_source) }

(* Stage-3 v1: [close_deps] resolves an App's runtime_dep by its dep_mode.
   [Independent] over run-versions {Stable,Dev} on a build@Stable assignment
   BRANCHES into two graphs — one running against lib@Stable (matched), one
   against lib@Dev (the deploy mismatch) — while the build chain (app←binding←
   lib@Stable) is fixed. [Lockstep] collapses to one graph; an App-less
   assignment reduces to [node_of_assignment] (flat projects unchanged). *)
let close_deps_test : pure_test =
  { name = "action.close_deps_deploy_mismatch";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let module CA = Canary_action in
      let a_oc = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let a_ap = Canary_artifact.a_app Canary_artifact.Direct in
      let pl p v : EN.placement = { provision = p; version = Canary_basic.good v } in
      (* build side all @Stable (incl. the build-lib) *)
      let a =
        EN.[ (a_source, pl Fetched B.Stable); (a_lib, pl Built B.Stable);
             (a_oc, pl Built B.Stable); (a_ap, pl Built B.Stable) ]
      in
      let run_versions_of _ = [ B.Stable; B.Dev ] in
      let app_of g =
        List.find g ~f:(fun (n : CA.artifact_node) -> Poly.equal n.CA.a_kind B.App)
      in
      let run_ver g =
        match app_of g with
        | Some app -> Option.map app.CA.runtime_dep ~f:(fun rl -> rl.CA.version)
        | None -> None
      in
      (* build chain fixed at Stable in every graph: app ← binding ← lib@Stable *)
      let build_lib_stable g =
        match app_of g with
        | Some app -> (
            match app.CA.built_from with
            | Some bind -> (
                match bind.CA.built_from with
                | Some lib -> Canary_basic.equal_version lib.CA.version (Canary_basic.good B.Stable)
                | None -> false)
            | None -> false)
        | None -> false
      in
      (* Independent: 2 graphs, run-lib @Stable and @Dev (the mismatch) *)
      let indep =
        let gs =
          CA.close_deps ~run_versions_of
            ~mode_of:(function B.App -> CA.Independent | _ -> CA.Lockstep) a
        in
        let run_vers = List.filter_map gs ~f:run_ver in
        let has v = List.exists run_vers ~f:(Canary_basic.equal_version (Canary_basic.good v)) in
        List.length gs = 2 && has B.Stable && has B.Dev
        && List.for_all gs ~f:build_lib_stable
      in
      (* Lockstep: 1 graph, run-lib = build-lib @Stable *)
      let lock =
        let gs =
          CA.close_deps ~run_versions_of ~mode_of:(fun _ -> CA.Lockstep) a
        in
        match gs with
        | [ g ] -> Option.value_map (run_ver g) ~default:false
                     ~f:(Canary_basic.equal_version (Canary_basic.good B.Stable))
        | _ -> false
      in
      (* App-less assignment ⇒ exactly [node_of_assignment] (one graph) *)
      let degenerate =
        let a' = EN.[ (a_source, pl Fetched B.Stable); (a_lib, pl Built B.Stable);
                      (a_oc, pl Built B.Stable) ] in
        List.length
          (CA.close_deps ~run_versions_of ~mode_of:(fun _ -> CA.Lockstep) a') = 1
      in
      indep && lock && degenerate) }

(* Flavor 2 deploy-mismatch: binding with Independent runtime paired with
   a different-version lib produces rp_deploy=true. Pin that
   runtime_pairings_of surfaces it correctly. *)
let deploy_mismatch_test : pure_test =
  { name = "enumerate.deploy_mismatch";
    check = (fun () ->
      let open Canary_artifact in let open Canary_project_spec in let open Canary_enumerate in
      let module B = Canary_basic in
      let ocaml_b = a_binding Canary_lang.OCaml Canary_mechanism.Cstubs in
      let spec =
        project_spec_of_rows
          [ artifact_row ~artifact:a_lib
              ~universe:[ (Fetched, [ B.Stable ]); (Built, [ B.Dev ]) ] ();
            artifact_row ~artifact:ocaml_b
              ~runtime:Canary_store.Independent
              ~universe:[ (Fetched, [ B.Stable ]) ] () ]
      in
      let asgs = enumerate_assignments ~policy:(full_policy ()) spec in
      (* Two independent roots: lib(2) × binding(1) = 2 scenarios *)
      let ok_count = List.length asgs = 2 in
      (* Find the deploy-mismatch assignment: lib=B@D, binding=F@S *)
      let deploy =
        List.find asgs ~f:(fun a ->
            equal_provision (provision_of a a_lib) Built
            && equal_provision (provision_of a ocaml_b) Fetched)
      in
      let ok_deploy =
        match deploy with
        | None -> false
        | Some a ->
            let pairs = runtime_pairings_of spec a in
            List.exists pairs ~f:(fun p ->
                equal_artifact_id p.rp_consumer ocaml_b
                && Poly.equal p.rp_mode Canary_store.Independent
                && p.rp_deploy)
      in
      ok_count && ok_deploy) }

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

(* Stage-4 v1: [execution_plan] flattens the applicable DAG into the run's walk
   order. Invariants: (1) it is a valid topological order — kinds never decrease,
   so every built_from/runtime_dep (always a lower kind) precedes its consumer;
   (2) [producing_action_of_node] inverts the provision — a Built node has a
   Build_* edge, a Fetched node a Fetch edge, a Vendored node NO edge (an initial
   node that is supplied, not built). Marks a tiny-shaped project (Lib may be
   Built OR Vendored; everything else Vendored) so both a real build edge and
   initial nodes appear in one plan. *)
let execution_plan_test : pure_test =
  { name = "action.execution_plan_topo_and_edges";
    check = (fun () ->
      let module CA = Canary_action in
      let g =
        CA.make_action_graph
          ~actions:(CA.store_actions ~langs:[ ocaml ])
          ~versions:[ B.Stable ] ~name:"pkg" ~source:Canary_store.store
          ~vendored:true ()
      in
      (* tiny-shaped: lib Built|Vendored, source/binding/app Vendored, no headers *)
      let provisions_of_kind : B.artifact_kind -> Canary_store.provision list =
        function
        | B.Source -> [ Canary_store.Vendored ]
        | B.Lib -> Canary_store.[ Built; Vendored ]
        | B.Binding _ -> [ Canary_store.Vendored ]
        | B.App -> [ Canary_store.Vendored ]
        | B.Headers -> []
      in
      let plan = CA.execution_plan ~provisions_of_kind g in
      (* (1) topo: kind_order non-decreasing down the plan *)
      let orders = List.map plan ~f:(fun n -> B.kind_order n.CA.a_kind) in
      let rec nondecreasing = function
        | a :: (b :: _ as t) -> a <= b && nondecreasing t
        | _ -> true
      in
      let topo_ok = nondecreasing orders in
      (* (2) each node's producing action inverts its provision *)
      let edges_ok =
        List.for_all plan ~f:(fun (n : CA.artifact_node) ->
            match (n.CA.provision, CA.producing_action_of_node n) with
            | Canary_store.Vendored, None -> true
            | Canary_store.Built, Some (B.Build_lib | B.Build_headers)
            | Canary_store.Built, Some (B.Build_binding _)
            | Canary_store.Built, Some (B.Build_app _) -> true
            | Canary_store.Fetched, Some (B.Fetch _) -> true
            | _ -> false)
      in
      (* a real Built lib edge is present (from the vendored source) alongside
         initial vendored nodes — the plan mixes both, as tiny does *)
      let has_built_lib =
        List.exists plan ~f:(fun (n : CA.artifact_node) ->
            Poly.equal n.CA.a_kind B.Lib
            && Poly.equal n.CA.provision Canary_store.Built
            && Option.is_some (CA.producing_action_of_node n))
      in
      let has_initial =
        List.exists plan ~f:(fun (n : CA.artifact_node) ->
            Poly.equal n.CA.provision Canary_store.Vendored
            && Option.is_none (CA.producing_action_of_node n))
      in
      topo_ok && edges_ok && has_built_lib && has_initial) }

(* ── Tool-routing RATCHET (user, 2026-08-05) ──
   Shell verbs that have (or should get) a named primitive in
   `src/canary/tool` must not spread as raw strings through the project
   specs — that is exactly the code scattering TODO #18 fights. The
   baseline below freezes TODAY's per-file line counts; a count ABOVE
   baseline fails the suite (route the new use through a tool/ primitive
   instead); a count below baseline means cleanup happened — lower the
   baseline in the same commit. Comments count too (crude by design: a
   ratchet, not a parser). *)
let tool_routing_ratchet_test : pure_test =
  { name = "harness.tool_routing_ratchet";
    check = (fun () ->
      let dir = "src/canary/project" in
      let lines_with ~needle path =
        try
          Stdlib.In_channel.with_open_text path (fun ic ->
              let rec loop n =
                match Stdlib.In_channel.input_line ic with
                | None -> n
                | Some l ->
                    loop (if String.is_substring l ~substring:needle then n + 1 else n)
              in
              loop 0)
        with _ -> 0
      in
      (* verb → per-file baseline (absent file = 0 allowed) *)
      (* Burn-down log: sqlite's gcc/curl/unzip/nm went to ZERO 2026-08-05
         (routed via curl_unzip_cmd / cc_shared_lib_cmd /
         native_lib_probe_cmd). Next candidates: llvm's pip-install chain
         (needs a pip_install_any primitive with the uv fallback) and the
         opam-install raws (A9-step-2 territory). *)
      let baseline =
        [ ("cmake ",
           [ (* +1 vs the old 6 = the C2 cmake-source COMMENT (the
                realize-time probe misdiagnosis); the shell goes through
                cmake_configure_cmd *)
             ("canary_project_llvm.ml", 7); ("canary_tiny_scenario.ml", 4);
             (* the +1 vs the old 6 = a COMMENT noting cmake's default
                generator; the shell goes through cmake_configure_cmd *)
             ("canary_project_z3.ml", 7); ("canary_run.ml", 1) ]);
          ("ninja ",
           [ (* one COMMENT mention (the -G Ninja note above) *)
             ("canary_project_z3.ml", 1);
             (* one COMMENT mention (the ninja LLVM dylib note, 2026-08-13) *)
             ("canary_project_llvm.ml", 1) ]);
          ("gcc ", []);
          ("curl ", []);
          (* "unzip -" (flag form): the bare word also appears in the tool
             primitive's NAME (curl_unzip_cmd), which is exactly the
             routing we want — only raw invocations should count. *)
          ("unzip -", []);
          ("pip install", [ ("canary_project_llvm.ml", 3) ]);
          ("opam install",
           [ ("canary_opam_binding.ml", 1);
             (* all 3 occurrences are COMMENTS describing the routed verb —
                the shell goes through [SB.fetch_binding_cmd] *)
             ("canary_project_ssl.ml", 3);
             ("canary_project_llvm.ml", 1);
             (* 3 -> 2 (2026-08-17): the conf-* refactor removed one
                mention — the shell goes through [SB.fetch_binding_cmd] *)
             ("canary_project_z3.ml", 2) ]);
          ("nm -D",
           [ ("canary_tiny_workspace.ml", 2);
             ("canary_tiny_scenario.ml", 1) ]);
          ("git clone", []);
          (* one COMMENT mention (the gmp 6.2.1 Tarball remote, C2.5) —
             the fetch goes through the Tar remote machinery *)
          ("tar ", [ ("canary_project_zarith.ml", 1) ]) ]
      in
      match Stdlib.Sys.readdir dir with
      | exception _ -> false
      | files ->
          let ok = ref true in
          Array.iter files ~f:(fun f ->
              if String.is_suffix f ~suffix:".ml" then
                List.iter baseline ~f:(fun (verb, per_file) ->
                    let allowed =
                      Option.value
                        (List.Assoc.find per_file f ~equal:String.equal)
                        ~default:0
                    in
                    let n = lines_with ~needle:verb (dir ^ "/" ^ f) in
                    if n > allowed then begin
                      ok := false;
                      Fmt.pr
                        "    RATCHET %s: %d line(s) with %S (baseline %d) — \
                         route new uses through src/canary/tool@."
                        f n verb allowed
                    end));
          !ok) }

(* M2 step 6 (2026-08-17): the contract registry — the producer's own
   pins. Every contract has exactly one complete row (invariant,
   role, tags), every registered check is referenced exactly once,
   the fault-tag mapping matches scenario.md's catalogue, and the
   firing derivation follows mechanism × provision. *)
let contract_registry_complete_pin : pure_test =
  { name = "contracts.registry_complete";
    check =
      (fun () ->
        let module CR = Canary_contract_registry in
        let ids = Canary_compat.[ C1; C2; C3; C4; C5; C6; C7; C8 ] in
        let rows = CR.contract_registry in
        (* one row per id, non-empty invariant, exactly one tag *)
        let rows_ok =
          List.for_all ids ~f:(fun id ->
              match List.filter rows ~f:(fun r ->
                  Poly.equal r.CR.cr_check.Canary_compat.id id) with
              | [ r ] ->
                  (not (String.is_empty r.CR.cr_invariant))
                  && List.length r.CR.cr_fault_tags = 1
              | _ -> false)
        in
        (* every registered check referenced exactly once *)
        let checks_ok =
          List.for_all Canary_compat_run.registered_checks
            ~f:(fun ck ->
              List.count rows ~f:(fun r ->
                  Poly.equal r.CR.cr_check.Canary_compat.id ck.id)
              = 1)
          && List.length rows = List.length Canary_compat_run.registered_checks
        in
        (* the tag mapping (scenario.md's catalogue) *)
        let tag id =
          match CR.row_of id with r -> List.hd_exn r.CR.cr_fault_tags
        in
        let tags_ok =
          String.equal (tag C1) "sym_missing"
          && String.equal (tag C2) "api_drop"
          && String.equal (tag C3) "behavior"
          && String.equal (tag C4) "abi_soname"
          && String.equal (tag C5) "sym_version"
          && String.equal (tag C6) "type_arity"
          && String.equal (tag C7) "api_repack"
          && String.equal (tag C8) "api_add"
        in
        (* the roles (design §4) *)
        let role_is r exp = Poly.equal r.CR.cr_role exp in
        let roles_ok =
          role_is (CR.row_of C1) CR.Surface
          && role_is (CR.row_of C2) CR.Surface
          && role_is (CR.row_of C3) CR.Execution
          && role_is (CR.row_of C4) CR.Surface
          && role_is (CR.row_of C5) CR.Surface
          && role_is (CR.row_of C6) CR.Meeting
          && role_is (CR.row_of C7) CR.Meeting
          && role_is (CR.row_of C8) CR.Meeting
        in
        (* the expectation forms: inspection-derived for the surface
           + meeting contracts, behavior-grep for the trace contracts,
           placeholder while blocked *)
        let source_is r exp = Poly.equal r.CR.cr_source exp in
        let sources_ok =
          source_is (CR.row_of C1) CR.Inspection
          && source_is (CR.row_of C2) CR.Inspection
          && source_is (CR.row_of C3) CR.Behavior_grep
          && source_is (CR.row_of C4) CR.Inspection
          && source_is (CR.row_of C5) CR.Inspection
          && source_is (CR.row_of C6) CR.Inspection
          && source_is (CR.row_of C7) CR.Behavior_grep
          && source_is (CR.row_of C8) CR.Placeholder
        in
        rows_ok && checks_ok && tags_ok && roles_ok && sources_ok) }

let contract_registry_firing_pin : pure_test =
  { name = "contracts.firing_defaults";
    check =
      (fun () ->
        let module CR = Canary_contract_registry in
        let f = (CR.row_of C1).CR.cr_firing in
        let eq got want = Poly.equal got want in
        (* Static + Built → build + probe; Static + Fetched → probe;
           Dynamic → probe — over the ACTION catalogue *)
        eq (f Canary_mechanism.Cstubs Canary_lang.OCaml Canary_store.Built)
          [ Canary_basic.Build_binding Canary_lang.OCaml;
            Canary_basic.Probe_binding Canary_lang.OCaml ]
        && eq (f Canary_mechanism.Cstubs Canary_lang.OCaml
                 Canary_store.Fetched)
             [ Canary_basic.Probe_binding Canary_lang.OCaml ]
        && eq (f Canary_mechanism.Ctypes Canary_lang.Python
                 Canary_store.Built)
             [ Canary_basic.Probe_binding Canary_lang.Python ]
        && (* behavior fires at probe in every world *)
        eq ((CR.row_of C3).CR.cr_firing Canary_mechanism.Cstubs
              Canary_lang.OCaml Canary_store.Built)
             [ Canary_basic.Probe_binding Canary_lang.OCaml ]) }

(* M2 step 6 (2026-08-17): the spec fixtures execute AHEAD of any
   project run — every fixture's synthetic inputs go through the
   row's predict and must yield the expected failure substrings. A
   new contract lands WITH its fixture; a changed predict breaks
   this pin. *)
let contract_fixture_tests : pure_test list =
  let module CR = Canary_contract_registry in
  let tmp_root = "_out/canary/test/contract-fixtures" in
  let _ = Stdlib.Sys.command [%string "mkdir -p %{tmp_root}"] in
  let execute (_id, (fx : CR.fixture)) : bool =
    (* [resolve] maps input-file names to REAL files (the loaders
       read from disk), so the fixture bodies are written out *)
    let resolve rel = [%string "%{tmp_root}/%{rel}"] in
    List.iter fx.CR.fx_bodies ~f:(fun (rel, body) ->
        let oc = Stdlib.open_out (resolve rel) in
        Stdlib.output_string oc body;
        Stdlib.close_out oc);
    let got =
      (CR.row_of _id).cr_check.Canary_compat.predict ~resolve
        fx.CR.fx_inputs
    in
    List.for_all fx.CR.fx_expect ~f:(fun s ->
        List.mem got s ~equal:String.equal)
  in
  let covered =
    List.map CR.contract_fixtures ~f:fst
    |> List.dedup_and_sort ~compare:(fun a b ->
           String.compare (Canary_compat.string_of_contract_id a)
             (Canary_compat.string_of_contract_id b))
  in
  [ { name = "contracts.fixtures_execute";
      check = (fun () -> List.for_all CR.contract_fixtures ~f:execute) };
    (* the visible coverage set: C1, C2 today — C3/C7 blocked in the
       registry; C4/C5/C6 pend their fixture JSON shapes *)
    { name = "contracts.fixtures_complete";
      check = (fun () ->
          Poly.equal covered Canary_compat.[ C1; C2 ]) } ]

let all_tests : pure_test list =
  catalogue_tests
  @ [ probe_invariant; inventory_test;
      derive_fetch_lib_test; surface_split_test;
      s2_raw_identity_test; detect_simple_test; coverage_test;
      mechanism_test; enumerate_test; config_level_test; version_axis_test;
      per_artifact_provisions_test; per_artifact_versions_test;
      point_fold_test; project_spec_test;
      per_provision_versions_test; thin_config_level_test;
      shadow_policy_drops_same_cell_built_test;
      refs_subset_test;
      subset_intersects_universe_test; mechanism_catalogue_test; source_fetch_local_pin; cmake_install_assert_staged_pin; inputs_template_pin; mechanism_chain_shape_pin;
      dispatch_reads_test; mismatch_direction_test;
      built_from_test; node_of_assignment_test; close_deps_test;
      deploy_mismatch_test;
      agnostic_expectation_test; execution_plan_test;
      tool_routing_ratchet_test;
      contract_registry_complete_pin; contract_registry_firing_pin ]
  @ contract_fixture_tests

(* [extra] — pure tests appended by upper layers that this suite cannot see
   (layering: test/ is canary_lib; the concrete project specs are the
   canary_project library ON TOP of it). `canary project-test` passes
   the project-spec pin tests ([Canary_projects_test.tests]) through here. *)
let run_tests ?(extra : pure_test list = []) () : bool =
  let all_tests = all_tests @ extra in
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
