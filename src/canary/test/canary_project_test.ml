(* canary_lib's own tests, of the project-definition layer, run by
   `canary project-test`. They are fast: no package-manager installs and
   no builds; some write fixtures under _out/canary/test. Vocabulary:
   doc/canary/design/enumeration/stage0_naming.md, Term ↔ code. *)

open Base

(* A row declares an origin per provision. The fixtures that test the
   axis shape (how many worlds a universe produces, which chains apply)
   have no realization, so [ax] fabricates a placeholder origin; a real
   project states where the artifact comes from. *)
let ax (pv : Canary_store.provision) :
    Canary_store_config.provision_spec =
  match pv with
  | Canary_store.Absent -> Canary_store_config.Absent
  | Canary_store.Fetched ->
      Canary_store_config.Fetched
        (Canary_store_config.Sys_pkg
           (Canary_store.mk_system_package_spec ~linux_pkg:"fixture"
              ~macos_pkg:"fixture" ()))
  | Canary_store.Built -> Canary_store_config.Built_from Canary_artifact.a_source
  | Canary_store.Installed -> Canary_store_config.Installed
  | Canary_store.Vendored -> Canary_store_config.Vendored_at "/fixture"

module A = Canary_action
module B = Canary_basic
module L = Canary_lang
module Mech = Canary_mechanism

(* A test: its name, the claim it holds in one sentence (the overview
   page lists it), and the check. *)
type pure_test = { name : string; holds : string; check : unit -> bool }

let run_pure_test (t : pure_test) = try t.check () with _ -> false

(* Helpers *)

let kinds_to_s (ks : B.artifact_kind list) : string =
  String.concat ~sep:";" (List.map ks ~f:B.string_of_artifact_kind)

(* the kinds as a test's sentence names them *)
let kinds_words (ks : B.artifact_kind list) : string =
  if List.is_empty ks then "nothing"
  else String.concat ~sep:", " (List.map ks ~f:B.string_of_artifact_kind)

let same_kinds (a : B.artifact_kind list) (b : B.artifact_kind list) : bool =
  List.equal Poly.equal a b

let ocaml = L.OCaml

(* Each row: an action with its expected consumes and produces sets. *)
let catalogue : (B.action * B.artifact_kind list * B.artifact_kind list) list =
  B.[
    (Configure,                       [ Source ],            []);
    (Scan_sources,                    [ Source ],            []);
    (Build_headers,                   [ Source ],            [ Headers ]);
    (Build_lib,                       [ Source ],            [ Lib ]);
    (Install_lib,                     [ Lib ],               [ Lib ]);
    (Build_binding ocaml,             [ Lib; Binding_source ocaml ], [ Binding ocaml ]);
    (Build_app { lang = ocaml },      [ Binding ocaml; Lib ],[ App ]);
    (Probe_lib,                       [ Lib ],               []);
    (Probe_binding ocaml,             [ Lib; Binding ocaml ],[]);
    (Probe_app { lang = ocaml },      [ App; Lib; Binding ocaml ], []);
    (Fetch Source,                    [],                    [ Source ]);
    (Fetch Lib,                       [],                    [ Lib ]);
    (Publish Lib,                     [ Lib ],               [ Lib ]);
  ]

(* The tests *)

let catalogue_tests : pure_test list =
  List.map catalogue ~f:(fun (a, exp_c, exp_p) ->
    { name =
        Printf.sprintf "consumes_produces.%s" (B.string_of_action a);
      holds =
        Printf.sprintf "%s consumes %s and produces %s." (B.string_of_action a)
          (kinds_words exp_c) (kinds_words exp_p);
      check = (fun () ->
        same_kinds (A.consumes_of_action a) exp_c
        && same_kinds (A.produces_of_action a) exp_p) })

(* This equivalence lets detection reuse artifacts_of_action at probe
   sites. *)
let probe_invariant : pure_test =
  { name = "probe_invariant.consumes_eq_artifacts";
    holds = "A probe action produces nothing, and what it consumes is exactly what artifacts_of_action lists for it.";
    check = (fun () ->
      let probes =
        B.[ Probe_lib; Probe_binding ocaml; Probe_app { lang = ocaml };
            Probe_binding L.Python ]
      in
      List.for_all probes ~f:(fun a ->
        same_kinds (A.consumes_of_action a) (A.artifacts_of_action a)
        && List.is_empty (A.produces_of_action a))) }

(* The consumed set is what detection would inspect. *)
let inventory_test : pure_test =
  { name = "inventory.sqlite_like";
    holds = "A sqlite-like project's actions consume, in order of first use, the source, the lib, the OCaml binding source and the OCaml binding.";
    check = (fun () ->
      let actions =
        B.[ Fetch Source; Build_lib; Fetch Lib;
            Build_binding ocaml; Probe_binding ocaml; Probe_lib ]
      in
      (* the fetches consume nothing; Build_lib consumes Source,
         Build_binding Lib and its Binding_source, Probe_binding Binding
         and Lib, Probe_lib Lib. Expected: their first-appearance union. *)
      same_kinds
        (A.consumed_artifacts_of_actions actions)
        B.[ Source; Lib; Binding_source ocaml; Binding ocaml ]) }

module SC = Canary_store_config
module SB = Canary_step_builder

(* command_of_step calls detect_pm () itself, so the expected command
   comes from the same detect_pm-based helper. *)
let derive_fetch_lib_test : pure_test =
  { name = "derive.fetch_lib_matches_helper";
    holds = "A derived fetch_lib step resolves to the command the runner helper emits, which names the library's package for this platform's package manager.";
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
      (* the package name is this PM's (brew's [sqlite] on macOS), asked
         the way [fetch_lib_cmd] asks it *)
      let expected_pkg =
        Canary_store.system_pkg_for_pm sys (Canary_store.detect_pm ())
      in
      String.equal derived direct
      && String.is_substring derived ~substring:expected_pkg) }

let surface_split_test : pure_test =
  { name = "surface.split_keeps_checks_drops_provenance";
    holds = "The surface derived from an API keeps its stable symbols, soname and binding watchlists, and drops its provenance.";
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

(* This identity makes wrapping a closure as Raw behaviour-preserving;
   Raw ignores the store_config. *)
let s2_raw_identity_test : pure_test =
  { name = "s2.command_of_step_raw_identity";
    holds = "A Raw step's command is its closure, unchanged by command_of_step.";
    check = (fun () ->
      let f ~output_dir ~variant_key = output_dir ^ ":" ^ variant_key in
      let g =
        SB.command_of_step ~store_config:SC.empty_store_config (SB.Raw f)
      in
      String.equal (g ~output_dir:"O" ~variant_key:"V") "O:V") }

let detect_simple_test : pure_test =
  { name = "detect.simple_finding";
    holds = "The simple detector classifies a step by its raw outcome alone: whether the command failed and whether its output is present.";
    check = (fun () ->
      let ok = Canary_detect.simple_finding ~tag:"t" ~cmd_ok:true ~output_present:true in
      let bad = Canary_detect.simple_finding ~tag:"t" ~cmd_ok:false ~output_present:false in
      (not ok.errored) && ok.output_present
      && bad.errored && (not bad.output_present)) }

let coverage_test : pure_test =
  { name = "coverage.logical_and_three_way";
    holds = "Each stage is marked covered, disabled or unspecified, and Probe_app alone, without Probe_binding, covers the run_app stage.";
    check = (fun () ->
      let module CV = Canary_scenario_coverage in
      let covered =
        B.[ Fetch Lib; Fetch (Binding ocaml); Probe_app { lang = ocaml };
            Probe_lib ]
      in
      let disabled = [ "build_lib" ] (* overrides an unspecified stage *) in
      let rows = CV.coverage ~langs:[ ocaml ] ~covered ~disabled in
      let mark label =
        List.find_map rows ~f:(fun ((st : CV.stage), m) ->
            if String.equal st.label label then Some m else None)
      in
      Poly.equal (mark "fetch_lib") (Some CV.Covered)
      (* run_app covered by Probe_app alone, as in tiny *)
      && Poly.equal (mark "run_app_ocaml") (Some CV.Covered)
      && Poly.equal (mark "build_lib") (Some CV.Disabled)
      && Poly.equal (mark "publish_lib") (Some CV.Unspecified)
      && Poly.equal (mark "build_binding_ocaml") (Some CV.Unspecified)) }

(* Design: doc/canary/design/agreement/components.md §3.3. *)
let mechanism_test : pure_test =
  { name = "mechanism.static_defaults_and_discipline";
    holds = "OCaml defaults to cstubs and Python to cext, both static C ABI; ctypes and dynlink are dynamic FFI; Rust has no mechanism yet.";
    check = (fun () ->
      let module M = Canary_mechanism in
      Poly.equal (M.default_mechanism_of_lang L.OCaml) (Some M.Cstubs)
      && Poly.equal (M.default_mechanism_of_lang L.Python) (Some M.Cext)
      && Poly.equal (M.discipline_of_mechanism M.Cstubs) M.Static_c_abi
      && Poly.equal (M.discipline_of_mechanism M.Cext) M.Static_c_abi
      && Poly.equal (M.discipline_of_mechanism M.Ctypes) M.Dynamic_ffi
      && Poly.equal (M.discipline_of_mechanism M.Dynlink) M.Dynamic_ffi
      && Canary_mechanism.is_static_binding_lang L.OCaml && Canary_mechanism.is_static_binding_lang L.Python
      (* an unmodelled language carries no mechanism *)
      && Poly.equal (M.default_mechanism_of_lang L.Rust) None
      && not (Canary_mechanism.is_static_binding_lang L.Rust)) }

(* One product-then-filter engine, two projections. Design:
   doc/canary/design/enumeration/stage3_enumerate_worlds.md. *)
let enumerate_test : pure_test =
  { name = "enumerate.two_projections_and_filter";
    holds = "The tiny projection is all built, a positive plus one point per mutation; the general one is mutation-free; no world provides a binding without its lib.";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let artifacts = EN.[ a_source; a_lib; a_binding ocaml Mech.Cstubs ] in
      let all_built (p : string EN.point) =
        List.for_all p.assignment ~f:(fun (_, pl) ->
            EN.equal_provision pl.Canary_artifact.provision EN.Built)
      in
      (* tiny: all Built × (positive + 2 mutations) = 3 points *)
      let muts =
        EN.[ (a_lib, "symbol_missing"); (a_binding ocaml Mech.Cstubs, "type_broken") ]
      in
      let tiny = EN.tiny_slice ~artifacts ~mutations:muts in
      let tiny_ok =
        List.length tiny = 3
        && List.count tiny ~f:(fun p -> List.is_empty p.EN.mutations) = 1
        && List.for_all tiny ~f:all_built
      in
      (* general: no mutations; an all-Fetched and an all-Built world *)
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
      (* with Absent allowed, a binding over an Absent lib is pruned *)
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

(* Per-axis levels Free, Subset and Full. Design:
   doc/canary/design/enumeration/stage4_select_worlds.md. *)
let config_level_test : pure_test =
  { name = "enumerate.config_levels";
    holds = "The tiny and general slices are two configs of one enumeration, and a Subset level keeps only the chosen provisions and mutations.";
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
          { provision = EN.Free; version = EN.Free; mutation = EN.Full; version_mode = EN.Lockstep; refs = EN.All_refs }
      in
      (* general config: provision Full, mutation Free → all positive *)
      let gen =
        EN.run_config ~artifacts ~all_provisions_of:(fun _ -> EN.[ Fetched; Built ])
          ~all_versions_of:(fun _ _ -> [ B.good B.Dev ]) ~all_mutations:muts
          { provision = EN.Full; version = EN.Full; mutation = EN.Free; version_mode = EN.Lockstep; refs = EN.All_refs }
      in
      (* mixed: provision Subset [Fetched] (all-Fetched only), mutation
         Subset [m1] (positive + exactly m1) *)
      let mixed =
        EN.run_config ~artifacts ~all_provisions_of:(fun _ -> EN.[ Absent; Fetched; Built ])
          ~all_versions_of:(fun _ _ -> [ B.good B.Dev ]) ~all_mutations:muts
          { provision = EN.Subset [ EN.Fetched ]; version = EN.Free;
            mutation = EN.Subset [ List.hd_exn muts ]; version_mode = EN.Lockstep; refs = EN.All_refs }
      in
      (* the two canonical wrappers equal their configs *)
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

let version_axis_test : pure_test =
  { name = "enumerate.version_axis";
    holds = "Versions are chosen per artifact, so a dev lib with a stable binding occurs, and a built lib always has its source's version.";
    check = (fun () ->
      let module EN = Canary_enumerate in
      (* two fetched artifacts, two versions each → the mismatch lib@Dev /
         binding@Stable is a valid assignment (the z3/llvm case). *)
      let mm_artifacts = EN.[ a_lib; a_binding ocaml Mech.Cstubs ] in
      let mm =
        EN.run_config ~artifacts:mm_artifacts ~all_provisions_of:(fun _ -> [ EN.Fetched ])
          ~all_versions_of:(fun _ _ -> List.map B.two_channels ~f:B.good) ~all_mutations:[]
          { provision = EN.Full; version = EN.Full; mutation = EN.Free; version_mode = EN.Lockstep; refs = EN.All_refs }
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
          { provision = EN.Full; version = EN.Full; mutation = EN.Free; version_mode = EN.Lockstep; refs = EN.All_refs }
      in
      let source_primary_holds =
        (not (List.is_empty built))
        && List.for_all built ~f:(fun p ->
               Canary_basic.equal_version
                 (EN.version_of p.EN.assignment Canary_artifact.a_lib)
                 (EN.version_of p.EN.assignment Canary_artifact.a_source))
      in
      has_mismatch && source_primary_holds) }

(* The sqlite shape. A single global provision universe could not express
   it: it would also emit a Built source and a Built binding. *)
let per_artifact_provisions_test : pure_test =
  { name = "enumerate.per_artifact_provisions";
    holds = "Provisions are per artifact: when only the lib may be built, worlds fetch or build the lib while the source and binding are always fetched.";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_ocaml = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let artifacts = EN.[ a_source; a_lib; a_ocaml ] in
      let provisions_of id =
        if Canary_artifact.equal_artifact_info id Canary_artifact.a_lib then EN.[ Fetched; Built ]
        else EN.[ Fetched ]
      in
      let pts =
        EN.run_config ~artifacts ~all_provisions_of:provisions_of
          ~all_versions_of:(fun _ _ -> [ B.good B.Dev ]) ~all_mutations:[]
          { provision = EN.Full; version = EN.Full; mutation = EN.Free; version_mode = EN.Lockstep; refs = EN.All_refs }
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

(* The version-axis analogue of [per_artifact_provisions_test]. A single
   global version universe could not express it: it would also emit a
   Stable binding. *)
let per_artifact_versions_test : pure_test =
  { name = "enumerate.per_artifact_versions";
    holds = "Versions are per artifact: the lib ranges over both channels while the binding stays dev-only, so a stable lib with a dev binding occurs.";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_ocaml = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let artifacts = EN.[ a_lib; a_ocaml ] in
      let versions_of id _pv =
        if Canary_artifact.equal_artifact_info id Canary_artifact.a_lib
        then List.map B.two_channels ~f:B.good
        else [ B.good B.Dev ]                        (* binding: Dev only *)
      in
      let pts =
        EN.run_config ~artifacts ~all_provisions_of:(fun _ -> [ EN.Fetched ])
          ~all_versions_of:versions_of ~all_mutations:[]
          { provision = EN.Full; version = EN.Full; mutation = EN.Free; version_mode = EN.Lockstep; refs = EN.All_refs }
      in
      let binding_ver p = EN.version_of p.EN.assignment a_ocaml in
      (not (List.is_empty pts))
      (* the binding is Dev in every assignment (its own axis) *)
      && List.for_all pts ~f:(fun p ->
             Canary_basic.equal_version (binding_ver p) (Canary_basic.good B.Dev))
      (* the lib@Stable / binding@Dev mismatch is present (lib's wider axis) *)
      && List.exists pts ~f:(fun p ->
             Canary_basic.equal_version (EN.version_of p.EN.assignment Canary_artifact.a_lib) (Canary_basic.good B.Stable))) }

let point_fold_test : pure_test =
  { name = "enumerate.point_to_assignment_fold";
    holds = "Folding a point into an assignment marks only the mutated artifact's version bad, tagged with the mutation; a positive point stays all good.";
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

(* The sqlite shape, self-contained: no source is declared. *)
let project_spec_test : pure_test =
  { name = "enumerate.project_spec_sqlite_shape";
    holds = "A declared spec with a fetched-or-built lib and a fetched binding enumerates two worlds, and the built-lib world still carries the binding.";
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

(* The sqlite shape: F@D, B@D and B@S. single_channel is [Dev], so the
   fetched lib and the binding are Dev. *)
let per_provision_versions_test : pure_test =
  { name = "enumerate.per_provision_versions";
    holds = "Versions depend on provision: a fetched lib gives one world and a built lib one per channel, so the sqlite shape has exactly three worlds.";
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

let thin_config_level_test : pure_test =
  { name = "enumerate.thin_is_version_subset";
    holds = "Thin is the version level Subset Stable: it narrows the tiny shape from three worlds to the two stable ones, and full keeps dev only on the built lib.";
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
                     mutation = Free; version_mode = EN.Lockstep; refs = EN.All_refs };              mutations = [] }
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

(* The Built side's version id is source-primary (the source's pin); both
   ids must be non-empty and equal, and the channels must match. *)
let shadow_policy_drops_same_cell_built_test : pure_test =
  { name = "enumerate.shadow_policy_drops_same_cell_built";
    holds = "A prebuilt lib shadows a built one of the same version and channel, dropping the built world, while libs from different cells both remain.";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let a_oc = Canary_artifact.a_binding ocaml Mech.Cstubs in
      let pin_1 =
        { Canary_basic.channel = B.Stable; id = "1.0.0"; quality = Canary_basic.Good }
      in
      (* same cell: prebuilt and built share the pin's id and channel *)
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
      (* different cells, the z3 shape: a Stable prebuilt (pin "1.0.0") and
         a Dev build over a Dev-pinned source ("dev-src"), whose ids differ *)
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
      let lib_prov a = EN.provision_of a Canary_artifact.a_lib in
      (* same cell: only the prebuilt survives *)
      List.length shadowed = 1
      && List.exists shadowed ~f:(fun a -> EN.equal_provision (lib_prov a) EN.Fetched)
      (* different cells: both worlds remain *)
      && List.length diff_shadowed = 2) }

(* The filter selects on the source's pin and is inert elsewhere. *)
let refs_subset_test : pure_test =
  { name = "enumerate.refs_subset";
    holds = "Selecting refs keeps only the worlds whose source is pinned to a selected ref, and worlds with an unpinned or absent source pass through.";
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
                (* the lib builds from the source: only a world that reads
                   the source has a refs axis. With nothing built, the
                   unread-source collapse ({!Canary_enumerate.source_ref_ok})
                   would fold the refs into the canonical one. *)
                Canary_artifact.(axes [ (Built, [ B.Stable ]) ]) );
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
      (* the survivor is the selected ref *)
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
      (* a declared but unpinned source passes: an ambient id is no ref
         to select on *)
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
      (* an absent source (a self-contained world) passes too *)
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

let mechanism_catalogue_test : pure_test =
  { name = "mechanism.catalogue_total_and_consistent";
    holds = "Every mechanism has a catalogue entry with the discipline the vocabulary derives, its lib coupling and a checking point, and each language's default mechanism is wired and of that language.";
    check = (fun () ->
      let all =
        Mech.[ Cstubs; Cext; Ctypes; Cffi; Dynlink ]
      in
      List.for_all all ~f:(fun m ->
          let i = Canary_mechanism.info_of_mechanism m in
          Poly.equal i.Canary_mechanism.mi_mechanism m
          && Poly.equal i.Canary_mechanism.mi_discipline (Mech.discipline_of_mechanism m)
          && (not (String.is_empty i.Canary_mechanism.mi_lib_coupling))
          && not (List.is_empty i.Canary_mechanism.mi_check_points))
      && List.for_all [ L.OCaml; L.Python ] ~f:(fun l ->
             match Mech.default_mechanism_of_lang l with
             | Some m ->
                 let i = Canary_mechanism.info_of_mechanism m in
                 i.Canary_mechanism.mi_wired && Poly.equal i.Canary_mechanism.mi_lang l
             | None -> false)
      (* the decidable fields the agreement layer relies on: an artifact
         that records NEEDED was compiled, so [mi_consumer_records_needed]
         implies [mi_compiles_a_stub]; and [mi_exposes_typed_stub] differs
         within Static_c_abi (cstubs declares [external]s a scanner reads,
         a cext's C has no extractor), so the fields are not derivable
         from the discipline *)
      && List.for_all all ~f:(fun m ->
             let i = Canary_mechanism.info_of_mechanism m in
             (not i.Canary_mechanism.mi_consumer_records_needed)
             || i.Canary_mechanism.mi_compiles_a_stub)
      && (Canary_mechanism.info_of_mechanism Mech.Cstubs)
           .Canary_mechanism.mi_exposes_typed_stub
      && (not
            (Canary_mechanism.info_of_mechanism Mech.Cext)
              .Canary_mechanism.mi_exposes_typed_stub)
      && Poly.equal
           (Canary_mechanism.info_of_mechanism Mech.Cstubs)
             .Canary_mechanism.mi_discipline
           (Canary_mechanism.info_of_mechanism Mech.Cext)
             .Canary_mechanism.mi_discipline) }

(* The line is written to install_fail.log because output_contains_any
   reads files, not stderr. *)
let cmake_install_assert_staged_test : pure_test =
  { name = "templates.cmake_install_assert_staged";
    holds = "Each path a cmake install must stage becomes a file test under the prefix, and a missing one writes an OCAML INSTALL MISSING line to install_fail.log.";
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

let source_fetch_local_test : pure_test =
  { name = "templates.source_fetch_local_skips_clone";
    holds = "A source fetch with a declared local checkout only tests that the directory exists and never clones, while one without it clones.";
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

(* The template is the standard: a row added here must match the paths
   the inspect steps write. A surface input lists both spellings, the
   framework's inspect.json and tiny's inspect_mli.json /
   inspect_attrs.json; the reader selects by the [kind] the inspector
   declared, so it cannot read a stub summary as a surface. *)
let inputs_template_test : pure_test =
  { name = "mechanism.inputs_template_covers_both_conventions";
    holds = "Each agreement's derived evidence paths offer both the framework's and tiny's file names where they differ, and the planned repack_complete reads nothing.";
    check = (fun () ->
      let module CC = Canary_agreement_common in
      let template = Canary_agreement.inputs_of_agreement in
      let eq c l expected =
        Poly.equal (template c l) expected
      in
      (* a pair agreement locates the library by world
         ([lib_evidence_paths]); asked with no world, the template reads
         Absent, which puts build_lib first *)
      eq CC.Required_symbols_exported L.OCaml
        CC.[ C_stub [ "build_binding_ocaml/inspect_stub.json";
                      "build_binding_ocaml/inspect.json" ];
             Native_lib [ "build_lib/inspect.json"; "probe_lib/inspect.json" ] ]
      && eq CC.Required_symbols_exported L.Python
        CC.[ C_stub [ "build_binding_python/inspect_stub.json";
                      "build_binding_python/inspect.json" ];
             Native_lib [ "build_lib/inspect.json"; "probe_lib/inspect.json" ] ]
      && eq CC.Api_names_present L.OCaml
        CC.[ Ocaml_mli [ "build_binding_ocaml/inspect.json";
                         "build_binding_ocaml/inspect_mli.json" ] ]
      && eq CC.Api_names_present L.Python
        CC.[ Python_attrs [ "build_binding_python/inspect.json";
                            "build_binding_python/inspect_attrs.json" ] ]
      (* the consumer's record: the linked probe executable first, the
         only consumer of a static archive that records NEEDED or a
         versioned reference; then the binding artifact, for a binding
         that is a shared object *)
      && eq CC.Soname_matches_requirement L.Python
        CC.[ Native_lib [ "build_lib/inspect.json"; "probe_lib/inspect.json" ];
             Abi_surface [ "probe_binding_python/inspect_abi.json";
                           "build_binding_python/inspect.json" ] ]
      && eq CC.Required_versions_exported L.Python
        CC.[ Versioned_exports [ "build_lib/inspect.json";
                                 "probe_lib/inspect.json" ];
             Versioned_req [ "probe_binding_python/inspect_abi.json";
                             "build_binding_python/inspect.json" ] ]
      && eq CC.Signatures_agree L.OCaml
        CC.[ Typed_header [ "scan_sources/inspect_typed_header.json" ];
             Typed_binding_stub
               [ "scan_sources/inspect_typed_binding_stub_ocaml.json" ] ]
      (* a declaration agreement reads the copy build_lib made
         ([built_lib_evidence_paths]); its declaration half comes from
         the step's context, which the template leaves empty *)
      && eq CC.Declared_symbols_exported L.OCaml
           CC.[ Native_lib [ "build_lib/inspect.json"; "probe_lib/inspect.json" ] ]
      && eq CC.Soname_matches_declaration L.OCaml
           CC.[ Native_lib [ "build_lib/inspect.json"; "probe_lib/inspect.json" ] ]
      && eq CC.Declared_versions_exported L.OCaml
           CC.[ Versioned_exports [ "build_lib/inspect.json";
                                    "probe_lib/inspect.json" ] ]
      (* under cstubs the consumer is the executable the probe links,
         which records NEEDED and the versioned references; the archive
         records none *)
      && eq CC.Soname_matches_requirement L.OCaml
           CC.[ Native_lib [ "build_lib/inspect.json"; "probe_lib/inspect.json" ];
                Abi_surface [ "probe_binding_ocaml/inspect_abi.json";
                              "build_binding_ocaml/inspect.json" ] ]
      (* planned — no evaluator, and nothing to read *)
      && List.is_empty (template CC.Repack_complete L.OCaml)) }

(* The stage set comes from the mechanism, not from a language guard. *)
let mechanism_chain_shape_test : pure_test =
  { name = "mechanism.dynamic_binding_has_no_build_chain";
    holds = "A spec whose only binding is dynamic admits no build_binding chain, one with a static binding does, and both still yield scenarios.";
    check = (fun () ->
      let module EN = Canary_enumerate in
      let dynamic_spec =
        Canary_project_spec.project_spec_of_rows
          [ Canary_project_spec.artifact_row ~artifact:EN.a_lib
              ~universe:[ (ax EN.Vendored, [ B.Stable ]) ] ();
            Canary_project_spec.artifact_row
              ~artifact:(Canary_artifact.a_binding Canary_lang.Python Canary_mechanism.Ctypes)
              ~universe:[ (ax EN.Vendored, [ B.Stable ]) ] () ]
      in
      let static_spec =
        Canary_project_spec.project_spec_of_rows
          [ Canary_project_spec.artifact_row ~artifact:EN.a_lib
              ~universe:[ (ax EN.Vendored, [ B.Stable ]) ] ();
            Canary_project_spec.artifact_row
              ~artifact:(Canary_artifact.a_binding Canary_lang.Python Canary_mechanism.Cext)
              ~universe:[ (ax EN.Vendored, [ B.Stable ]) ] () ]
      in
      (* a chain with build_binding_python: the first build chain is
         OCaml's, and the specs declare Python bindings only *)
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
      (* chain_applicable is the mechanism-aware gate *)
      let dyn_app = EN.chain_applicable dynamic_spec build_chain in
      let stat_app = EN.chain_applicable static_spec build_chain in
      (not dyn_app)
      && stat_app
      && (* both specs still enumerate scenarios *)
      List.length (EN.patterns_of dynamic_spec) > 0
      && List.length (EN.patterns_of static_spec) > 0) }

let subset_intersects_universe_test : pure_test =
  { name = "enumerate.subset_intersects_universe";
    holds = "A version subset never invents versions: asking a z3-shaped spec for stable keeps only the fetched lib's world, with no built stable world.";
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
                     mutation = Free; version_mode = EN.Lockstep; refs = EN.All_refs };              mutations = [] }
          spec
      in
      List.length thin = 1
      && List.for_all thin ~f:(fun a ->
             EN.equal_provision (EN.provision_of a Canary_artifact.a_lib) EN.Fetched)) }

(* A project's runner dispatch reads only these coordinates. *)
let dispatch_reads_test : pure_test =
  { name = "enumerate.dispatch_coordinate_reads";
    holds = "The dispatch reads give each artifact's placed channel and each bad-quality artifact with its tag, and no bad placements for a positive world.";
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
          | [ (id, "Bs.4") ] -> Canary_artifact.equal_artifact_info id Canary_artifact.a_lib
          | _ -> false)) }

(* The direction is named from the consumer's position. *)
let mismatch_direction_test : pure_test =
  { name = "enumerate.mismatch_direction";
    holds = "A dev consumer over a stable provider is a forward mismatch, a stable consumer over a dev provider a backward one, and anything else is none.";
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

(* [built_from_kinds] is read off Canary_action.consumes_of_action, so
   the two representations are one. *)
let built_from_test : pure_test =
  { name = "enumerate.built_from_of_assignment";
    holds = "Build edges read off the action catalogue match the graph's built_from: a built lib comes from its source, a built binding from its lib, a fetched artifact from nothing.";
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
        match edges id with [ e ] -> Canary_artifact.equal_artifact_info e target | _ -> false
      in
      one_edge Canary_artifact.a_lib Canary_artifact.a_source           (* Built lib ← Source *)
      && one_edge a_oc Canary_artifact.a_lib                (* Built binding ← Lib *)
      && List.is_empty (edges Canary_artifact.a_source)) }  (* Fetched source: no edge *)

let node_of_assignment_test : pure_test =
  { name = "action.node_of_assignment_chain";
    holds = "Lifting an assignment to the node graph links a built binding to its lib and the lib to its source, and the action graph's lib comes from the source too.";
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
      (* make_action_graph agrees: its lib node is built from Source *)
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

let close_deps_test : pure_test =
  { name = "action.close_deps_deploy_mismatch";
    holds = "An app's runtime lib follows its dependency mode: independent branches into stable and dev runs over a stable build chain, while lockstep or no app gives one graph.";
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
      (* app-less: the one graph [node_of_assignment] gives *)
      let degenerate =
        let a' = EN.[ (a_source, pl Fetched B.Stable); (a_lib, pl Built B.Stable);
                      (a_oc, pl Built B.Stable) ] in
        List.length
          (CA.close_deps ~run_versions_of ~mode_of:(fun _ -> CA.Lockstep) a') = 1
      in
      indep && lock && degenerate) }

(* Flavor 2, a mismatch between artifacts. Design:
   doc/canary/design/enumeration/stage6_realize_steps.md §5. *)
let deploy_mismatch_test : pure_test =
  { name = "enumerate.deploy_mismatch";
    holds = "A binding with an independent runtime, placed with a lib of another version, is reported by runtime_pairings_of as a deploy mismatch.";
    check = (fun () ->
      let open Canary_artifact in let open Canary_project_spec in let open Canary_enumerate in
      let module B = Canary_basic in
      let ocaml_b = a_binding Canary_lang.OCaml Canary_mechanism.Cstubs in
      let spec =
        project_spec_of_rows
          [ artifact_row ~artifact:a_lib
              ~universe:[ (ax Fetched, [ B.Stable ]); (ax Built, [ B.Dev ]) ] ();
            artifact_row ~artifact:ocaml_b
              ~runtime:Canary_store.Independent
              ~universe:[ (ax Fetched, [ B.Stable ]) ] () ]
      in
      let asgs = enumerate_follows_tree ~policy:(full_policy ()) spec in
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
                equal_artifact_info p.rp_consumer ocaml_b
                && Poly.equal p.rp_mode Canary_store.Independent
                && p.rp_deploy)
      in
      ok_count && ok_deploy) }

let agnostic_expectation_test : pure_test =
  { name = "scenario.lower_expectation_agnostic_symbols";
    holds = "From the bindings table alone, the OCaml probe expects a derived compat failure carrying the agreement's inputs, and build_lib expects success.";
    check = (fun () ->
      let module CS = Canary_scenario in
      let module CC = Canary_agreement_common in
      let module SM = Canary_step_model in
      let bindings =
        CS.[ { contract = CC.Required_symbols_exported; lang = ocaml;
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

(* Dependency order is checked as non-decreasing kind order: a built_from
   or runtime_dep is always a lower kind. The tiny shape puts a real build
   edge and initial (vendored) nodes in one plan. *)
let execution_plan_test : pure_test =
  { name = "action.execution_plan_topo_and_edges";
    holds = "The execution plan visits artifacts in dependency order, and each node's producing action matches its provision: build if built, fetch if fetched, none if vendored.";
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
        | B.Binding_source _ -> [ Canary_store.Vendored ]
        | B.App -> [ Canary_store.Vendored ]
        | B.Headers -> []
      in
      let plan = CA.execution_plan ~provisions_of_kind g in
      (* dependency order: kind_order non-decreasing down the plan *)
      let orders = List.map plan ~f:(fun n -> B.kind_order n.CA.a_kind) in
      let rec nondecreasing = function
        | a :: (b :: _ as t) -> a <= b && nondecreasing t
        | _ -> true
      in
      let topo_ok = nondecreasing orders in
      (* each node's producing action inverts its provision *)
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
      (* non-vacuous: a real Built lib edge and an initial vendored node
         both occur *)
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

(* Totality keeps a new agreement from being left out of the registry. A
   method with no evaluator must carry a reason, or [not_implemented]
   would report nothing. *)
let agreement_registry_complete_test : pure_test =
  { name = "agreements.registry_complete";
    holds = "Every agreement id has exactly one row stating its claim and expectation, every method has an evaluator or says why not, and fault tags match the catalogue.";
    check =
      (fun () ->
        let module CR = Canary_agreement in
        let module C = Canary_agreement_common in
        let rows = CR.agreement_registry in
        (* total: one row per declared id, and no row without an id *)
        let total_ok =
          List.for_all C.all_agreement_ids ~f:(fun id ->
              List.count rows ~f:(fun r -> Poly.equal r.CR.ag_id id) = 1)
          && List.length rows = List.length C.all_agreement_ids
        in
        (* every row states its claim, its reference expectation, a
           fault tag and at least one method *)
        let rows_ok =
          List.for_all rows ~f:(fun r ->
              (not (String.is_empty r.CR.ag.C.ag_says))
              && (not (String.is_empty r.CR.ag.C.ag_expects))
              (* every agreement says whose rule it recovers in note, tool
                 and artifact, so no table cell is blank, and is rooted
                 exactly when it names an action *)
              && (let rt = r.CR.ag.C.ag_rooted_in in
                  (not (String.is_empty rt.C.rt_note))
                  && (not (String.is_empty rt.C.rt_tool))
                  && (not (String.is_empty rt.C.rt_artifact))
                  && Bool.equal (C.is_rooted rt)
                       (not (String.is_empty rt.C.rt_action)))
              && (not (String.is_empty r.CR.ag.C.ag_fault_tag))
              && (not (List.is_empty r.CR.ag.C.ag_methods))
              (* some candidate slot of every agreement is an action of
                 each language's chain, or its outcome would have no
                 column to appear in *)
              && List.for_all [ Canary_lang.OCaml; Canary_lang.Python ]
                   ~f:(fun l ->
                     let chain = Canary_basic.actions_of_lang l in
                     Option.is_some
                       (C.slot_in_chain r.CR.ag.C.ag_slot ~lang:l ~chain))
              && String.equal r.CR.ag_slug (C.string_of_agreement_id r.CR.ag_id))
        in
        (* every method names itself and states its limits, and has
           either an evaluator or a planned reason, never both *)
        let methods_ok =
          List.for_all rows ~f:(fun r ->
              List.for_all r.CR.ag.C.ag_methods ~f:(fun m ->
                  (not (String.is_empty m.C.m_name))
                  && (not (String.is_empty m.C.m_limits))
                  &&
                  match m.C.m_eval with
                  | Some _ -> String.is_empty m.C.m_planned
                  | None -> not (String.is_empty m.C.m_planned)))
        in
        (* the fault-tag mapping (the scenario catalogue's) *)
        let tag id = (CR.row_of id).CR.ag.C.ag_fault_tag in
        let tags_ok =
          String.equal (tag C.Declared_symbols_exported) "sym_missing"
          && String.equal (tag C.Required_symbols_exported) "sym_missing"
          && String.equal (tag C.Api_names_present) "api_drop"
          && String.equal (tag C.Behavior_matches) "behavior"
          && String.equal (tag C.Soname_matches_declaration) "abi_soname"
          && String.equal (tag C.Soname_matches_requirement) "abi_soname"
          && String.equal (tag C.Declared_versions_exported) "sym_version"
          && String.equal (tag C.Required_versions_exported) "sym_version"
          && String.equal (tag C.Signatures_agree) "type_arity"
          && String.equal (tag C.Dependencies_provided) "needed_unprovided"
          && String.equal (tag C.Staged_interface_preserved) "staged_drift"
          && String.equal (tag C.Repack_preserves_api) "api_repack"
          && String.equal (tag C.Repack_complete) "api_add"
        in
        (* a claim is structural or behavioural, and the method kind
           varies independently of it *)
        let claim_is id exp = Poly.equal (CR.row_of id).CR.ag.C.ag_claim exp in
        let kind_is id exp =
          Poly.equal (List.hd_exn (CR.row_of id).CR.ag.C.ag_methods).C.m_kind exp
        in
        let axes_ok =
          claim_is C.Required_symbols_exported C.Structural
          && kind_is C.Required_symbols_exported C.Compare
          && claim_is C.Api_names_present C.Structural
          && kind_is C.Api_names_present C.Inspect
          && claim_is C.Behavior_matches C.Behavioral
          && kind_is C.Behavior_matches C.Run_program
          && claim_is C.Signatures_agree C.Structural
          && claim_is C.Repack_preserves_api C.Behavioral
        in
        (* the basis: a project's declaration and a consumer's recorded
           requirement are different authorities *)
        let basis_ok =
          Poly.equal
            (CR.row_of C.Declared_symbols_exported).CR.ag.C.ag_basis
            C.Project_declaration
          && Poly.equal
               (CR.row_of C.Required_symbols_exported).CR.ag.C.ag_basis
               C.Toolchain_rule
          && Poly.equal
               (CR.row_of C.Soname_matches_declaration).CR.ag.C.ag_basis
               C.Project_declaration
          && Poly.equal
               (CR.row_of C.Soname_matches_requirement).CR.ag.C.ag_basis
               C.Toolchain_rule
        in
        (* a row carries the very agreement value its family declares;
           physical equality because an agreement carries closures, which
           polymorphic compare raises on *)
        let wiring_ok =
          phys_equal (CR.row_of C.Required_symbols_exported).CR.ag
            Canary_agreement_symbols.required_symbols_exported
          && phys_equal (CR.row_of C.Declared_symbols_exported).CR.ag
               Canary_agreement_symbols.declared_symbols_exported
          && phys_equal (CR.row_of C.Api_names_present).CR.ag
               Canary_agreement_api_surface.api_names_present
          && phys_equal (CR.row_of C.Behavior_matches).CR.ag
               Canary_agreement_behaviour.behavior_matches
          && phys_equal (CR.row_of C.Soname_matches_requirement).CR.ag
               Canary_agreement_identity.soname_matches_requirement
          && phys_equal (CR.row_of C.Dependencies_provided).CR.ag
               Canary_agreement_identity.dependencies_provided
          && phys_equal (CR.row_of C.Signatures_agree).CR.ag
               Canary_agreement_types.signatures_agree
          && phys_equal (CR.row_of C.Repack_complete).CR.ag
               Canary_agreement_composed.repack_complete
        in
        (* names round-trip; the retired numbered spellings must fail to
           parse, so a cache entry or CLI word naming c1 resolves to
           nothing *)
        let names_ok =
          List.for_all C.all_agreement_ids ~f:(fun id ->
              match C.agreement_id_of_string (C.string_of_agreement_id id) with
              | Some back -> Poly.equal back id
              | None -> false)
          && List.for_all [ "c1"; "c2"; "c5"; "c9"; "ag1" ] ~f:(fun s ->
                 Option.is_none (C.agreement_id_of_string s))
          &&
          let known, unknown = C.agreement_ids_of_csv "api_names_present,c2" in
          List.length known = 1 && List.equal String.equal unknown [ "c2" ]
        in
        total_ok && rows_ok && methods_ok && tags_ok && axes_ok && basis_ok
        && wiring_ok && names_ok) }

let agreement_registry_firing_test : pure_test =
  { name = "agreements.firing_defaults";
    holds = "Declaration checks fire at build_lib, or probe_lib when the lib is fetched; binding checks fire at the binding's build and probe, or only its probe, never at build_lib.";
    check =
      (fun () ->
        let module CR = Canary_agreement in
        let module C = Canary_agreement_common in
        let eq got want = Poly.equal got want in
        (* each method fires on its own; an agreement's sites are the
           union *)
        let sites id m l w =
          List.concat_map (CR.row_of id).CR.ag.C.ag_methods ~f:(fun mm ->
              mm.C.m_firing m l w)
        in
        (* firing takes an assignment, so each world is spelled in full *)
        let ml = C.uniform_world ~lang:Canary_lang.OCaml
                   ~mechanism:Canary_mechanism.Cstubs in
        let built_ml = ml Canary_store.Built
        and fetched_ml = ml Canary_store.Fetched in
        let built_py =
          C.uniform_world ~lang:Canary_lang.Python
            ~mechanism:Canary_mechanism.Ctypes Canary_store.Built
        in
        (* static + Built: build and probe; static + Fetched: probe;
           dynamic: probe *)
        eq
          (sites C.Required_symbols_exported Canary_mechanism.Cstubs
             Canary_lang.OCaml built_ml)
          [ Canary_basic.Build_binding Canary_lang.OCaml;
            Canary_basic.Probe_binding Canary_lang.OCaml ]
        && eq
             (sites C.Required_symbols_exported Canary_mechanism.Cstubs
                Canary_lang.OCaml fetched_ml)
             [ Canary_basic.Probe_binding Canary_lang.OCaml ]
        && eq
             (sites C.Required_symbols_exported Canary_mechanism.Ctypes
                Canary_lang.Python built_py)
             [ Canary_basic.Probe_binding Canary_lang.Python ]
        && (* behavior fires at the probe *)
        eq
          (sites C.Behavior_matches Canary_mechanism.Cstubs Canary_lang.OCaml
             built_ml)
          [ Canary_basic.Probe_binding Canary_lang.OCaml ]
        && (* a declaration comparison is about the library alone, so it
              fires where the library's inspection lands *)
        eq
          (sites C.Soname_matches_declaration Canary_mechanism.Cstubs
             Canary_lang.OCaml built_ml)
          [ Canary_basic.Build_lib ]
        && (* in a Fetched world too: the compiler and linker ran on the
              distro's build machine, but the export table is the same.
              At the probe, because the probe writes the inspection *)
        eq
          (sites C.Soname_matches_declaration Canary_mechanism.Cstubs
             Canary_lang.OCaml fetched_ml)
          [ Canary_basic.Probe_lib ]
        && (* a pair check fires where the consumer exists: at
              build_lib the binding is not built yet *)
        eq
          (sites C.Soname_matches_requirement Canary_mechanism.Cstubs
             Canary_lang.OCaml built_ml)
          [ Canary_basic.Build_binding Canary_lang.OCaml;
            Canary_basic.Probe_binding Canary_lang.OCaml ]
        && List.for_all
             C.[ Soname_matches_requirement; Required_versions_exported;
                 Dependencies_provided ]
             ~f:(fun id ->
               not
                 (List.mem
                    (sites id Canary_mechanism.Cstubs Canary_lang.OCaml built_ml)
                    Canary_basic.Build_lib ~equal:Poly.equal))
        && (* a declaration comparison does not consult the binding
              mechanism: it is the same question under ctypes *)
        eq
          (sites C.Declared_symbols_exported Canary_mechanism.Ctypes
             Canary_lang.Python
             (C.uniform_world ~lang:Canary_lang.Python
                ~mechanism:Canary_mechanism.Ctypes Canary_store.Built))
          [ Canary_basic.Build_lib ]
        && (* applicability is a separate, static question (mechanism,
              language, declared API; no world). The pair identity
              agreement applies under cstubs, whose consumer is the
              executable the probe links, and not under a dynamic
              mechanism, which compiles nothing *)
        (let applicable_under m =
           match
             (List.hd_exn
                (CR.row_of C.Soname_matches_requirement).CR.ag.C.ag_methods)
               .C.m_applicable m Canary_lang.OCaml None
           with
           | C.Applicable -> true
           | C.Inapplicable _ -> false
         in
         applicable_under Canary_mechanism.Cstubs
         && not (applicable_under Canary_mechanism.Dynlink))) }

(* A new agreement lands with its counterexample. A fixture asserts an
   outcome label as well as the diagnostics, which tells "requirements
   met" from "evidence absent". *)
let agreement_fixture_tests : pure_test list =
  let module CR = Canary_agreement in
  let module C = Canary_agreement_common in
  let tmp_root = "_out/canary/test/agreement-fixtures" in
  let _ = Stdlib.Sys.command [%string "mkdir -p %{tmp_root}"] in
  let execute (id, (m : C.checking_method), (fx : C.fixture)) : bool =
    (* the loaders read from disk, so the fixture bodies are written out
       and [resolve] maps input-file names to them *)
    let resolve rel = [%string "%{tmp_root}/%{rel}"] in
    List.iter fx.C.fx_bodies ~f:(fun (rel, body) ->
        let oc = Stdlib.open_out (resolve rel) in
        Stdlib.output_string oc body;
        Stdlib.close_out oc);
    (* the fixture names its method; the method must be the one the
       registry holds for this agreement *)
    let registered =
      Option.value_map
        (C.method_of (CR.row_of id).CR.ag fx.C.fx_method)
        ~default:false ~f:(fun mm -> phys_equal mm m)
    in
    match m.C.m_eval with
    | None -> false
    | Some ev ->
        let outcome = ev ~resolve fx.C.fx_inputs in
        let got = m.C.m_diagnostics outcome in
        registered
        && String.equal (C.outcome_label outcome) fx.C.fx_outcome
        && List.for_all fx.C.fx_findings ~f:(fun s ->
               List.mem got s ~equal:String.equal)
  in
  let covered =
    List.map CR.agreement_fixtures ~f:(fun (id, _, _) -> id)
    |> List.dedup_and_sort ~compare:(fun a b ->
           String.compare (C.string_of_agreement_id a)
             (C.string_of_agreement_id b))
  in
  [ { name = "agreements.fixtures_execute";
      holds = "Without any project run, every agreement fixture reaches its stated outcome and diagnostics through the method the registry holds for it.";
      check = (fun () -> List.for_all CR.agreement_fixtures ~f:execute) };
    (* [rt_action] names a step, so the column can be sorted and matched
       against `canary paths`; a prose qualification goes in
       [rt_artifact]. *)
    { name = "agreements.rooting_names_an_action";
      holds = "Every agreement's rooting names an action that parses, or names none and is then unrooted.";
      check = (fun () ->
          List.for_all CR.agreement_registry ~f:(fun r ->
              let rt = r.CR.ag.C.ag_rooted_in in
              if String.is_empty rt.C.rt_action then
                (* unrooted: no tool's rule, so no action to name *)
                not (C.is_rooted rt)
              else Option.is_some (Canary_basic.action_of_string rt.C.rt_action))) };
    (* The code is derived from the slug and heads a check column of the
       result table, so a collision would make one column silently stand
       for another agreement. *)
    { name = "agreements.short_codes_are_unique";
      holds = "Every agreement has a non-empty short code and no two agreements share one.";
      check = (fun () ->
          let codes =
            List.map CR.agreement_registry ~f:(fun r ->
                C.short_code_of_slug r.CR.ag_slug)
          in
          List.for_all codes ~f:(fun c -> not (String.is_empty c))
          && List.length
               (List.dedup_and_sort codes ~compare:String.compare)
             = List.length codes) };
    (* behavior_matches, repack_preserves_api and repack_complete have no
       evaluator, so they have nothing to falsify and no fixture. *)
    { name = "agreements.fixtures_complete";
      holds = "An agreement has a fixture exactly when it has an evaluator.";
      check = (fun () ->
          Poly.equal covered
            C.[ Api_names_present; Declared_symbols_exported;
                Declared_versions_exported; Dependencies_provided;
                Gate_admits_the_world; Required_symbols_exported;
                Required_versions_exported; Signatures_agree;
                Soname_matches_declaration; Soname_matches_requirement;
                Staged_interface_preserved ]
          && List.for_all CR.agreement_registry ~f:(fun r ->
                 (* the invariant the set above is an instance of *)
                 Bool.equal
                   (C.has_evaluator r.CR.ag)
                   (CR.has_fixture r.CR.ag_id))) } ]

let matrix_marks_from_log_test : pure_test =
  { name = "matrix.marks_from_log";
    holds = "Per scenario and step, the matrix keeps the last verdict in the actions log, and marks a confirmed expected failure as xfail with its agreement.";
    check = (fun () ->
      let root = "_out/canary/test" in
      (* [log_path] is root/canary/projects/<p>/-run/actions.log *)
      let run_dir = root ^ "/canary/projects/matrix-fixture/-run" in
      let rec mkdir_p dir =
        let parent = Stdlib.Filename.dirname dir in
        if String.equal dir parent || Stdlib.Sys.file_exists dir then ()
        else begin
          mkdir_p parent;
          (try Stdlib.Sys.mkdir dir 0o755 with _ -> ())
        end
      in
      mkdir_p run_dir;
      let oc = Stdlib.open_out (run_dir ^ "/actions.log") in
      Stdlib.output_string oc
        "[2026-08-17 10:00:00.000] *                          variant_start  (scenA)\n\
         [2026-08-17 10:00:01.000] fetch_source                 done  \n\
         [2026-08-17 10:00:02.000] probe_binding_ocaml          failed  (postcondition failed)\n\
         [2026-08-17 10:00:03.000] probe_binding_ocaml          done  (expected failure confirmed (derived) [api_names_present])\n\
         [2026-08-17 10:00:04.000] *                          variant_start  (scenB)\n\
         [2026-08-17 10:00:05.000] fetch_source                 done  \n\
         [2026-08-17 10:00:06.000] probe_binding_ocaml          done  \n";
      Stdlib.close_out oc;
      let m = Canary_status.project_matrix ~root ~project:"matrix-fixture" in
      (match m with
       | [ ( "scenA",
             [ ("fetch_source", ("done", _));
               ("probe_binding_ocaml", ("done", Some d)) ] );
           ("scenB",
            [ ("fetch_source", ("done", _));
              ("probe_binding_ocaml", ("done", None)) ] ) ] ->
           (* failed then xfail: the last verdict wins, and the xfail
              mark carries the confirming agreement *)
           String.is_substring d ~substring:"expected failure"
           && String.equal
                (Canary_status.mark "done" (Some d))
                "xfail[api_names_present]"
           && String.equal
                (Canary_status.mark "done" None)
                "✓"
       | _ -> false)) }

let matrix_agreements_from_log_test : pure_test =
  { name = "matrix.agreements_from_log";
    holds = "Agreement outcomes are read from the actions log per scenario, the last per step and agreement winning, skipping lines that name no agreement.";
    check = (fun () ->
      let root = "_out/canary/test" in
      let run_dir = root ^ "/canary/projects/agmt-fixture/-run" in
      let rec mkdir_p dir =
        let parent = Stdlib.Filename.dirname dir in
        if String.equal dir parent || Stdlib.Sys.file_exists dir then ()
        else begin
          mkdir_p parent;
          (try Stdlib.Sys.mkdir dir 0o755 with _ -> ())
        end
      in
      mkdir_p run_dir;
      let oc = Stdlib.open_out (run_dir ^ "/actions.log") in
      Stdlib.output_string oc
        "[2026-09-14 10:00:00.000] *                          variant_start  (scenA)\n\
         [2026-09-14 10:00:01.000] build_lib                    agreement_outcome  (declared_symbols_exported/declared_exports_vs_library: holds)\n\
         [2026-09-14 10:00:02.000] probe_binding_ocaml          agreement_outcome  (required_symbols_exported/stub_requirements_vs_library_exports: unavailable: no native library inspection in this world)\n\
         [2026-09-14 10:00:03.000] probe_binding_ocaml          agreement_outcome  (required_symbols_exported/stub_requirements_vs_library_exports: violated: tiny_offset)\n\
         [2026-09-14 10:00:04.000] fetch_source                 agreement_outcome  (no agreement fires at this action)\n\
         [2026-09-14 10:00:05.000] *                          variant_start  (scenB)\n\
         [2026-09-14 10:00:06.000] probe_binding_ocaml          agreement_outcome  (api_names_present/watchlist_vs_user_surface: holds)\n";
      Stdlib.close_out oc;
      let m = Canary_status.project_agreements ~root ~project:"agmt-fixture" in
      match m with
      | [ ("scenA", a); ("scenB", b) ] ->
          let open Canary_status in
          (* scenA: two rows, not three; the re-evaluation replaced the
             earlier unavailable, and the fires-nowhere line added
             nothing *)
          (match a with
           | [ { ao_tag = "build_lib";
                 ao_agreement = "declared_symbols_exported";
                 ao_outcome = "holds"; _ };
               { ao_tag = "probe_binding_ocaml";
                 ao_agreement = "required_symbols_exported";
                 ao_outcome = "violated"; _ } ] -> true
           | _ -> false)
          && (match b with
              | [ { ao_agreement = "api_names_present";
                    ao_outcome = "holds"; _ } ] -> true
              | _ -> false)
      | _ -> false) }

let marker_stale_on_spec_change_test : pure_test =
  { name = "runner.marker_stale_on_spec_change";
    holds = "A verdict marker serves a warm skip only while its fingerprint matches the step; a changed command or expectation makes it stale, as does an old format.";
    check = (fun () ->
      let out = "_out/canary/test" in
      let mk_step cmd_s =
        { Canary_step_model.tag = "build_lib";
          output_tag = "build_lib";
          output_dir = out ^ "/marker-fixture";
          project_dir = "_out/canary/projects/marker-fixture";
          variant_id = "scenA";
          action = Canary_basic.Build_lib;
          deps = [];
          cmd = (fun ~output_dir:_ ~variant_key:_ -> cmd_s);
          dep_dirs = [];
          check_post = (fun ~output_dir:_ ~variant_key:_ -> true);
          expectation = Canary_step_model.Expect_success;
          symbol_check = None;
          disabled_agreements = [];
          agreement_ctx = None;
          dummy = None; location = None; inspects = None; bridge = None;
          placeholder = None }
      in
      let s1 = mk_step "echo build v1" in
      let marker = Canary_local_runner.verdict_marker s1 in
      (try
         Stdlib.Sys.mkdir (out ^ "/marker-fixture") 0o755
       with _ -> ());
      let write_lines lines =
        let oc = Stdlib.open_out marker in
        List.iter lines ~f:(fun l -> Stdlib.output_string oc (l ^ "\n"));
        Stdlib.close_out oc
      in
      (* old-format marker (no digest line) — stale *)
      write_lines [ "ok" ];
      let old_format = not (Canary_local_runner.verdict_matches_spec s1) in
      (* a freshly-written verdict matches *)
      Canary_local_runner.write_verdict s1 ~ok:true ~xfail:false
        ~xfail_contracts:[];
      let fresh = Canary_local_runner.verdict_matches_spec s1 in
      (* the fingerprint is stable across calls *)
      let stable =
        String.equal (Canary_local_runner.step_fingerprint s1)
          (Canary_local_runner.step_fingerprint s1)
      in
      (* a cmd change (the spec drifted) flips the match *)
      let s2 = mk_step "echo build v2" in
      let drifted = not (Canary_local_runner.verdict_matches_spec s2) in
      (* an expectation change flips it too *)
      let s3 =
        { s1 with
          Canary_step_model.expectation =
            Canary_step_model.Expect_failure
              { contains_any = [ "SIG" ]; version_info = None } }
      in
      let expectation_drifted =
        not (Canary_local_runner.verdict_matches_spec s3)
      in
      (* only the two compat forms carry the agreement schema epoch, so a
         change of epoch invalidates the verdicts the registry decided and
         leaves a build's or a fetch's marker warm *)
      let form = Canary_local_runner.expectation_form in
      let epoch = Canary_agreement_common.evaluation_schema in
      let has_epoch e = String.is_substring (form e) ~substring:epoch in
      let epoch_ok =
        has_epoch
          (Canary_step_model.Expect_compat_failure
             { inputs = []; version_info = None })
        && has_epoch
             (Canary_step_model.Expect_compat_derived
                { inputs = []; version_info = None })
        && (not (has_epoch Canary_step_model.Expect_success))
        && not
             (has_epoch
                (Canary_step_model.Expect_failure
                   { contains_any = [ "SIG" ]; version_info = None }))
      in
      old_format && fresh && stable && drifted && expectation_drifted
      && epoch_ok) }

(* The postcondition checks, with an offline rev-parse, that the checkout
   is at the declared ref. Run against a non-repo fixture it fails
   closed, so the gate would drop the marker and re-fetch; the test
   covers that wiring, and the rev-parse semantics are git's. *)
let source_fetch_pinned_ref_check_post_test : pure_test =
  { name = "templates.source_fetch_pinned_ref_check_post";
    holds = "A source fetch pinned to a ref gets its own postcondition, which fails closed outside a checkout, while a fetch of HEAD keeps the default.";
    check = (fun () ->
      let mk ~ref_ () =
        let spec =
          Canary_action_templates.realize_template
            (Canary_action_templates.Source_fetch
               { name = "z3"; ver_str = "pre"; ref_; url = "https://x.invalid";
                 local = None })
        in
        spec.Canary_step_builder.check_post (Canary_basic.Fetch Canary_basic.Source)
      in
      let pinned = mk ~ref_:"bc4585e0b" () in
      let head = mk ~ref_:"HEAD" () in
      (match pinned with
       | Some f ->
           not
             (f ~output_dir:"_out/canary/test/marker-fixture"
                ~variant_key:"scenA")
       | None -> false)
      && Option.is_none head) }

(* A binding may live in a different repo than its lib (zarith and the
   system gmp). Its source's fetch leads the per-language block of
   store_actions. *)
let binding_source_vocabulary_test : pure_test =
  { name = "vocab.binding_source_off_tree";
    holds = "A binding source is its own artifact kind, with no mechanism and its own fetch action in the catalogue.";
    check = (fun () ->
      String.equal
        (B.string_of_action (B.Fetch (B.Binding_source L.OCaml)))
        "fetch_binding_source_ocaml"
      && String.equal
           (B.string_of_artifact_kind (B.Binding_source L.OCaml))
           "binding_source_ocaml"
      (* the smart constructor builds the sum's own constructor; the
         pairing is structural, so what is left to check is the
         projection *)
      && Canary_artifact.equal_artifact_info
           (Canary_artifact.a_binding_source L.OCaml)
           (Canary_artifact.A_binding_source L.OCaml)
      && Poly.equal
           (Canary_artifact.kind_of (Canary_artifact.a_binding_source L.OCaml))
           (B.Binding_source L.OCaml)
      && Option.is_none
           (Canary_artifact.mechanism_of
              (Canary_artifact.a_binding_source L.OCaml))
      (* the catalogue carries the typed row *)
      && List.exists B.action_catalogue ~f:(fun (s : B.action_sig) ->
             Poly.equal s.B.as_action
               (B.Fetch (B.Binding_source L.OCaml)))) }

(* Ids feed scenario dirs, dedup keys and run-cache markers, so the
   unnamed lib's id must not change: a changed id would invalidate every
   cached run and read as a fresh pass. A named lib must differ from the
   unnamed one, or declaring two libs would collapse them into one
   placement. Design: doc/canary/design/enumeration/multi_lib.md §3a. *)
let lib_name_optional_test : pure_test =
  { name = "vocab.lib_name_optional";
    holds = "An unnamed lib still prints as plain lib, a named one adds a dash and its name, and libs with different names, or none, are different artifacts.";
    check = (fun () ->
      let unnamed = Canary_artifact.a_lib in
      let gmp = Canary_artifact.a_lib_named "gmp" in
      (* 1. the unnamed lib's id is plain lib *)
      String.equal (Canary_artifact.string_of_id unnamed) "lib"
      && String.equal (Canary_artifact.pretty_id unnamed) "lib"
      (* 2. the coarse kind carries no name *)
      && Poly.equal (Canary_artifact.kind_of unnamed) B.Lib
      && Poly.equal (Canary_artifact.kind_of gmp) B.Lib
      (* 3. a named lib refines the id with '-', born-safe like the rest *)
      && String.equal (Canary_artifact.string_of_id gmp) "lib-gmp"
      && not (String.contains (Canary_artifact.string_of_id gmp) ':')
      (* 4. the reader tells "not a lib" from "the project's only lib" *)
      && Option.is_none (Canary_artifact.lib_name_of Canary_artifact.a_source)
      && Poly.equal (Canary_artifact.lib_name_of unnamed) (Some None)
      && Poly.equal (Canary_artifact.lib_name_of gmp) (Some (Some "gmp"))
      (* 5. two libs are two artifacts *)
      && not (Canary_artifact.equal_artifact_info unnamed gmp)
      && not
           (Canary_artifact.equal_artifact_info gmp
              (Canary_artifact.a_lib_named "mpfr"))) }

let agreement_bridge_tests : pure_test list =
  let module CR = Canary_agreement in
  [ { name = "agreements.slugs_unique_and_named";
      holds = "Agreement slugs are unique, lowercase with underscores and no digits, and every agreement states a claim, an expectation and a doc section.";
      check =
        (fun () ->
          let slugs = List.map CR.all_agreements ~f:(fun e -> e.CR.e_slug) in
          let uniq = List.dedup_and_sort slugs ~compare:String.compare in
          List.length slugs = List.length uniq
          && List.for_all CR.all_agreements ~f:(fun e ->
                 (not (String.is_empty e.CR.e_slug))
                 && (not (String.is_empty e.CR.e_claim))
                 && (not (String.is_empty e.CR.e_expects))
                 && String.is_prefix e.CR.e_doc ~prefix:"\xc2\xa7")
          (* no numbered identifiers: a slug spelled c1, ag1 or check3
             fails *)
          && List.for_all slugs ~f:(fun s ->
                 (not (Char.is_digit s.[0]))
                 && (not (String.is_prefix s ~prefix:"ag"))
                 && String.for_all s ~f:(fun ch ->
                        Char.is_lowercase ch || Char.equal ch '_'))) };
    { name = "agreements.every_agreement_has_an_entry";
      holds = "The registry has as many rows as there are agreement ids, at least three agreements are proposed, and the full list is the rows plus the proposals.";
      check =
        (fun () ->
          (* structural rather than a literal count, so a new agreement
             needs no edit here *)
          List.length CR.agreement_registry
          = List.length Canary_agreement_common.all_agreement_ids
          && List.length CR.proposed_agreements >= 3
          && List.length CR.all_agreements
             = List.length CR.agreement_registry
               + List.length CR.proposed_agreements) };
    (* The catalogue states a rooting as text and the overview draws it as
       an R cell, so they can disagree silently: an [rt_action] that stops
       parsing just stops drawing its R. [expands] keeps the per-pattern
       expansion non-vacuous. *)
    { name = "agreements.overview_matches_rooting";
      holds = "Each overview row marks one root exactly when its agreement's rooting names an action, every agreement has a row, and some agreement has several.";
      check =
        (fun () ->
          let rows = CR.overview_rows () in
          let per_row_ok =
            List.for_all rows ~f:(fun (row : CR.overview_row) ->
                let roots =
                  List.count row.CR.ov_cells ~f:(fun (_, m) ->
                      match m with
                      | CR.Rooted | CR.Rooted_and_detected -> true
                      | _ -> false)
                in
                match CR.rooted_action_of row.CR.ov_agreement with
                | Some _ -> roots = 1
                | None -> roots = 0)
          in
          let slugs =
            List.map rows ~f:(fun r ->
                r.CR.ov_agreement.CR.ag_slug)
          in
          let covers_every =
            List.for_all CR.agreement_registry ~f:(fun r ->
                List.mem slugs r.CR.ag_slug ~equal:String.equal)
          in
          let expands =
            List.length rows > List.length CR.agreement_registry
          in
          per_row_ok && covers_every && expands) };
    (* The laws are data in [Canary_agreement.row_rules]: a rule added
       there is enforced here. `canary checks --firing` prints them beside
       the table, with any violation. *)
    { name = "agreements.rows_obey_their_own_laws";
      holds = "Every overview row obeys every rule listed in row_rules, and at least four rules are listed.";
      check =
        (fun () ->
          let bad = CR.audit_rows () in
          if not (List.is_empty bad) then
            List.iter bad ~f:(fun (rule, complaint) ->
                Fmt.pr "    [%s] %s@." rule complaint);
          (* non-vacuous: an empty rule list would pass any table *)
          List.is_empty bad && List.length CR.row_rules >= 4) };
    (* The overview is organised by claim, so an uncovered combination has
       no row to show in; this asks directly. A claim covers a cell when
       the mechanism can carry it and it ranges over that format,
       evaluator or not. The grid-size bounds keep an empty catalogue
       from passing. *)
    { name = "agreements.every_mechanism_format_cell_is_watched";
      holds = "Every catalogued mechanism, under every object format, is covered by at least one claim, implemented or not.";
      check =
        (fun () ->
          let holes = CR.saturation_holes () in
          List.iter holes ~f:(fun (m, f) ->
              Fmt.pr
                "    UNWATCHED: %s × %s — canary can build this and checks \
                 nothing about it@."
                (Canary_mechanism.string_of_mechanism m)
                (Canary_store.string_of_object_format f));
          List.is_empty holes
          && List.length (CR.saturation_grid ()) >= 5
          && List.for_all (CR.saturation_grid ()) ~f:(fun (_, cells) ->
                 List.length cells >= 2)) };
    (* [ag_kind] names the relation an agreement checks, not its second
       party; with fewer than three kinds in use it would not divide the
       catalogue. A kind held only by candidates is what the last line of
       the candidate table (`canary checks --firing`) reports. *)
    { name = "agreements.kind_partitions_the_catalogue";
      holds = "At least three agreement kinds are in use, admissibility and promise among them, and some kind is held only by proposed agreements.";
      check =
        (fun () ->
          let k r =
            Canary_agreement_common.string_of_agreement_kind
              r.CR.ag.Canary_agreement_common.ag_kind
          in
          let used =
            List.map CR.agreement_registry ~f:k
            |> List.dedup_and_sort ~compare:String.compare
          in
          let cand =
            List.map CR.proposed_agreements ~f:(fun p ->
                Canary_agreement_common.string_of_agreement_kind p.CR.prop_kind)
            |> List.dedup_and_sort ~compare:String.compare
          in
          let only_candidate =
            List.filter cand ~f:(fun c ->
                not (List.mem used c ~equal:String.equal))
          in
          let ok =
            List.length used >= 3
            && List.mem used "admissibility" ~equal:String.equal
            && List.mem used "promise" ~equal:String.equal
            && (not (List.is_empty cand))
            && not (List.is_empty only_candidate)
          in
          if not ok then
            Fmt.pr
              "    kinds in use: %s | candidate-only: %s@."
              (String.concat ~sep:"," used)
              (String.concat ~sep:"," only_candidate);
          ok) };
    (* A repeated code reads as one claim with several patterns only when
       its rows are adjacent. The trigger key is language-free, because a
       claim's OCaml and Python rows fire at the same action in different
       languages; keying [trigger_index] on the column index would break
       the grouping. The unit is the (agreement, trigger) pair, since a
       claim whose patterns fire at different actions forms two blocks. *)
    { name = "agreements.overview_groups_a_claims_patterns";
      holds = "An agreement's overview rows that fire at the same action, in whatever language, sit together, and some agreement has several such rows.";
      check =
        (fun () ->
          let rows = CR.overview_rows () in
          let keyed =
            List.map rows ~f:(fun (row : CR.overview_row) ->
                ( row.CR.ov_agreement.CR.ag_slug,
                  Option.map (CR.first_firing_action row)
                    ~f:(fun a ->
                      Canary_basic.string_of_action
                        (CR.retarget_action ~lang:Canary_lang.OCaml a)) ))
          in
          (* every (slug, trigger) pair occupies one contiguous run *)
          let runs =
            List.fold keyed ~init:[] ~f:(fun acc k ->
                match acc with
                | last :: _ when Poly.equal last k -> acc
                | _ -> k :: acc)
          in
          let distinct = List.dedup_and_sort runs ~compare:Poly.compare in
          let ok = List.length runs = List.length distinct in
          if not ok then
            Fmt.pr
              "    overview: a claim's rows are split — %d runs for %d \
               distinct (agreement, trigger) pairs@."
              (List.length runs) (List.length distinct);
          (* non-vacuous: some claim has several adjacent rows *)
          ok && List.length rows > List.length distinct) };
    (* [rt_action] is one string in one language's spelling
       (required_symbols_exported says build_binding_ocaml), yet a cext
       row's R belongs in a Python column. The lag bound of 2 catches a
       root measured from another language's column. *)
    { name = "agreements.rooting_speaks_the_rows_language";
      holds = "No overview row is rooted at another language's action, and no row's root sits more than two actions from its nearest detection.";
      check =
        (fun () ->
          let bad =
            List.concat_map (CR.overview_rows ()) ~f:(fun (row : CR.overview_row) ->
                match row.CR.ov_mechs with
                | [] -> []
                | m :: _ ->
                    let mine =
                      (Canary_mechanism.info_of_mechanism m)
                        .Canary_mechanism.mi_lang
                    in
                    (* an action belongs to another language exactly when
                       re-languaging it to this row's changes it;
                       [retarget_action] leaves language-free actions
                       alone *)
                    let misrooted =
                      List.filter_map row.CR.ov_cells ~f:(fun (a, mk) ->
                          match mk with
                          | CR.Rooted | CR.Rooted_and_detected ->
                              if Poly.equal (CR.retarget_action ~lang:mine a) a
                              then None
                              else
                                Some
                                  (Printf.sprintf
                                     "%s [%s] roots at %s — another \
                                      language's action"
                                     row.CR.ov_agreement.CR.ag_slug
                                     (Canary_lang.string_of_lang mine)
                                     (Canary_basic.string_of_action a))
                          | _ -> None)
                    in
                    let lag_bad =
                      match CR.row_lag row with
                      | Some d when d > 2 ->
                          [ Printf.sprintf
                              "%s [%s] has lag %d — suspiciously far; the \
                               language-blind rooting bug read 3..7"
                              row.CR.ov_agreement.CR.ag_slug
                              (Canary_lang.string_of_lang mine) d ]
                      | _ -> []
                    in
                    misrooted @ lag_bad)
          in
          if not (List.is_empty bad) then
            List.iter bad ~f:(fun b -> Fmt.pr "    %s@." b);
          List.is_empty bad) };
    (* Mach-O has no symbol versioning, hence the two ELF-only agreements.
       They are named so that a third ELF-only agreement has to be stated
       here. Not tested: a restricted agreement reporting not_applicable
       on the other format, since evaluation does not consult
       [ag_formats]. *)
    { name = "agreements.formats_restrict_the_version_claims";
      holds = "Exactly the two symbol-version agreements are ELF-only, and every other agreement covers both object formats.";
      check =
        (fun () ->
          let elf_only =
            List.filter_map CR.agreement_registry ~f:(fun r ->
                match r.CR.ag_formats with
                | [ Canary_store.Elf ] -> Some r.CR.ag_slug
                | _ -> None)
            |> List.sort ~compare:String.compare
          in
          let all_both =
            List.for_all CR.agreement_registry ~f:(fun r ->
                match r.CR.ag_formats with
                | [ _; _ ] -> true
                | [ Canary_store.Elf ] ->
                    List.mem elf_only r.CR.ag_slug ~equal:String.equal
                | _ -> false)
          in
          List.equal String.equal elf_only
            [ "declared_versions_exported"; "required_versions_exported" ]
          && all_both) };
    (* required_symbols_exported reads (lib, ml) under cstubs and
       (lib, py) under cext: different artifacts, two either way. If the
       count varied with the mechanism, the decomposition by target in
       doc/canary/design/agreement/README.md §6.11 would need a finer
       cell. *)
    { name = "agreements.target_count_is_a_property_of_the_claim";
      holds = "Each agreement reads the same number of artifacts in every overview row, whatever mechanism carries it.";
      check =
        (fun () ->
          let rows = CR.overview_rows () in
          let bad =
            List.filter_map CR.agreement_registry ~f:(fun r ->
                let counts =
                  List.filter rows ~f:(fun (row : CR.overview_row) ->
                      String.equal row.CR.ov_agreement.CR.ag_slug r.CR.ag_slug)
                  |> List.map ~f:(fun (row : CR.overview_row) ->
                         List.length row.CR.ov_reads)
                  |> List.dedup_and_sort ~compare:Int.compare
                in
                match counts with
                | [] | [ _ ] -> None
                | ns ->
                    Some
                      (Printf.sprintf
                         "%s targets %s artifacts depending on the mechanism \
                          — the count is no longer a property of the claim"
                         r.CR.ag_slug
                         (String.concat ~sep:"/"
                            (List.map ns ~f:Int.to_string))))
          in
          if not (List.is_empty bad) then
            List.iter bad ~f:(fun b -> Fmt.pr "    %s@." b);
          List.is_empty bad) };
    (* [ag_waiting_on] is prose a person writes, so no generator ensures
       it. The converse is not tested: an agreement with an evaluator may
       still be blocked, and requiring a reason there would force a line
       saying "nothing", which [None] already says. *)
    { name = "agreements.planned_says_what_it_waits_on";
      holds = "Every agreement with no evaluator states, in a non-empty reason, what it is waiting on.";
      check =
        (fun () ->
          let bad =
            List.filter_map CR.agreement_registry ~f:(fun r ->
                let planned =
                  List.for_all
                    r.CR.ag.Canary_agreement_common.ag_methods ~f:(fun m ->
                      Option.is_none m.Canary_agreement_common.m_eval)
                in
                match (planned, r.CR.ag_waiting_on) with
                | true, None -> Some r.CR.ag_slug
                | true, Some w when String.is_empty (String.strip w) ->
                    Some (r.CR.ag_slug ^ " (empty reason)")
                | _ -> None)
          in
          if not (List.is_empty bad) then
            Fmt.pr
              "    planned agreement(s) with no ag_waiting_on: %s@."
              (String.concat ~sep:", " bad);
          List.is_empty bad) } ]

(* A family module publishes the agreements it owns as [checks]. This
   tests the pattern, not the contents. *)
let check_module_pattern_test : pure_test =
  { name = "agreements.families_declare_the_catalogue";
    holds = "The families together declare every agreement id exactly once, each family declares some, and every agreement states a claim, an expectation and methods.";
    check =
      (fun () ->
        let module C = Canary_agreement_common in
        let families =
          [ ("symbols", Canary_agreement_symbols.checks);
            ("api_surface", Canary_agreement_api_surface.checks);
            ("identity", Canary_agreement_identity.checks);
            ("types", Canary_agreement_types.checks);
            ("behaviour", Canary_agreement_behaviour.checks);
            ("staging", Canary_agreement_staging.checks);
            ("bridge", Canary_agreement_bridge.checks);
            ("composed", Canary_agreement_composed.checks) ]
        in
        let all = List.concat_map families ~f:snd in
        let ids = List.map all ~f:fst in
        (* every declared id appears exactly once across the families,
           and the families declare every id there is *)
        List.for_all C.all_agreement_ids ~f:(fun id ->
            List.count ids ~f:(Poly.equal id) = 1)
        && List.length all = List.length C.all_agreement_ids
        && List.for_all families ~f:(fun (_, cs) -> not (List.is_empty cs))
        && List.for_all all ~f:(fun (_, a) ->
               (not (String.is_empty a.C.ag_says))
               && (not (String.is_empty a.C.ag_expects))
               && not (List.is_empty a.C.ag_methods))
        (* a declaration agreement and its pair counterpart state
           different claims *)
        && (not
              (String.equal
                 Canary_agreement_symbols.declared_symbols_exported.C.ag_says
                 Canary_agreement_symbols.required_symbols_exported.C.ag_says))
        && (not
              (String.equal
                 Canary_agreement_identity.soname_matches_declaration.C.ag_says
                 Canary_agreement_identity.soname_matches_requirement.C.ag_says))
        && String.equal (C.string_of_subject C.Action_outcome) "action-outcome") }

(* Facts in, checks out: no project names an agreement id. *)
let agreements_for_test : pure_test =
  { name = "agreements.facts_in_checks_out";
    holds = "The registry selects agreements from a world's facts alone: build_lib checks only when the lib is built, build_binding checks only when the binding is.";
    check =
      (fun () ->
        let module R = Canary_agreement in
        let world ~lib ~binding : Canary_artifact.assignment =
          let at id p =
            (id, { Canary_artifact.provision = p;
                   version = Canary_basic.good Canary_basic.Dev })
          in
          [ at Canary_artifact.a_lib lib;
            at
              (Canary_artifact.a_binding Canary_lang.OCaml
                 Canary_mechanism.Cstubs)
              binding ]
        in
        let got ?action w =
          R.agreements_for ~mechanism:Canary_mechanism.Cstubs
            ~lang:Canary_lang.OCaml ~world:w ?action ()
        in
        let slugs l = List.map l ~f:(fun (r, _) -> r.R.ag_slug) in
        let all_built =
          world ~lib:Canary_store.Built ~binding:Canary_store.Built
        in
        let built = got all_built in
        let at_build_lib = got ~action:Canary_basic.Build_lib all_built in
        (* a Built world reaches the declaration agreements at build_lib *)
        List.mem (slugs at_build_lib) "declared_symbols_exported"
          ~equal:String.equal
        && List.mem (slugs at_build_lib) "soname_matches_declaration"
             ~equal:String.equal
        && List.mem (slugs at_build_lib) "declared_versions_exported"
             ~equal:String.equal
        (* every returned row is enabled *)
        && List.for_all built ~f:(fun (r, _) -> r.R.ag_enabled)
        (* a Fetched world has no build_lib checks at all *)
        && List.is_empty
             (got ~action:Canary_basic.Build_lib
                (world ~lib:Canary_store.Fetched
                   ~binding:Canary_store.Fetched))
        (* lib and binding are asked separately: sqlite's shape (lib
           built, binding fetched from opam) reaches build_lib and claims
           no build_binding step *)
        && (not
              (List.is_empty
                 (got ~action:Canary_basic.Build_lib
                    (world ~lib:Canary_store.Built
                       ~binding:Canary_store.Fetched))))
        && List.is_empty
             (got
                ~action:(Canary_basic.Build_binding Canary_lang.OCaml)
                (world ~lib:Canary_store.Built ~binding:Canary_store.Fetched))
        (* the mirror image: a fetched lib with a binding built against
           it checks the build_binding cell and no build_lib cell *)
        && (not
              (List.is_empty
                 (got
                    ~action:(Canary_basic.Build_binding Canary_lang.OCaml)
                    (world ~lib:Canary_store.Fetched
                       ~binding:Canary_store.Built))))
        && List.is_empty
             (got ~action:Canary_basic.Build_lib
                (world ~lib:Canary_store.Fetched ~binding:Canary_store.Built))) }

(* The production path, end to end. The fixtures run evaluators directly;
   this runs a step through [Canary_local_runner.run_step], as a real
   scenario's chain does, and reads the actions.log it wrote. No input
   list is supplied: the registry selects from the step's action and its
   [agreement_ctx]. *)
let agreement_action_path_test : pure_test =
  { name = "agreements.action_path_reports_outcomes";
    holds = "Run through the runner, a probe step logs each agreement as holds, violated naming the symbol, unavailable or not implemented, and a violation alone does not fail it.";
    check = (fun () ->
      let root = "_out/canary/test" in
      let write path body =
        let dir = Stdlib.Filename.dirname path in
        ignore (Stdlib.Sys.command (Printf.sprintf "mkdir -p %s" dir) : int);
        let oc = Stdlib.open_out path in
        Stdlib.output_string oc body;
        Stdlib.close_out oc
      in
      (* one OCaml/cstubs world with everything built: a compiled-stub
         context *)
      let world =
        Canary_agreement_common.uniform_world ~lang:Canary_lang.OCaml
          ~mechanism:Canary_mechanism.Cstubs Canary_store.Built
      in
      (* [case] lays out a project dir, runs one probe step through the
         runner, and returns the step's status and the actions.log *)
      let case name ~lib_symbols =
        let project = "agreement-path-" ^ name in
        let project_dir = root ^ "/canary/projects/" ^ project in
        ignore (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" project_dir) : int);
        (* the consumer's recorded requirements … *)
        write (project_dir ^ "/build_binding/ocaml/inspect.json")
          {|{"kind": "c_stub", "path": "fx",
    "requires": ["tiny_sum", "tiny_offset"]}|};
        (* … its user-facing surface, with the watchlist satisfied … *)
        write (project_dir ^ "/build_binding/ocaml/inspect_mli.json")
          {|{"kind": "ocaml_mli", "path": "fx",
    "watchlist": {"present": ["Tiny.sum"], "missing": []}}|};
        (* … and the provider's exports, when this case has them *)
        (match lib_symbols with
         | None -> ()
         | Some syms ->
             write (project_dir ^ "/build_lib/inspect.json")
               (Printf.sprintf
                  {|{"kind": "native", "path": "fx", "symbols": [%s]}|}
                  (String.concat ~sep:", "
                     (List.map syms ~f:(fun s -> "\"" ^ s ^ "\"")))));
        let log_path = project_dir ^ "/actions.log" in
        let logger = Canary_step_model.create_logger ~log_path in
        let step : Canary_step_model.step =
          { tag = "probe_binding_ocaml";
            output_tag = "probe_binding_ocaml";
            output_dir = project_dir ^ "/probe_binding/ocaml";
            project_dir;
            variant_id = "";
            action = Canary_basic.Probe_binding Canary_lang.OCaml;
            deps = [];
            cmd = (fun ~output_dir:_ ~variant_key:_ -> "true");
            dep_dirs = [];
            check_post = (fun ~output_dir:_ ~variant_key:_ -> true);
            expectation = Canary_step_model.Expect_success;
            symbol_check = None;
            disabled_agreements = [];
            agreement_ctx =
              Some
                { Canary_agreement_common.ac_mechanism = Canary_mechanism.Cstubs;
                  ac_lang = Canary_lang.OCaml;
                  ac_world = world;
                  ac_declared = None };
            dummy = None; location = None; inspects = None; bridge = None;
          placeholder = None }
        in
        let status = Canary_local_runner.run_step logger ~root ~project step in
        logger.Canary_step_model.close ();
        let log =
          try Stdlib.In_channel.with_open_text log_path Stdlib.In_channel.input_all
          with _ -> ""
        in
        (status, log)
      in
      let has log s = String.is_substring log ~substring:s in
      (* 1 — requirements met *)
      let ok_status, ok_log =
        case "holds" ~lib_symbols:(Some [ "tiny_sum"; "tiny_offset" ])
      in
      let holds_ok =
        Poly.equal ok_status Canary_step_model.Step_done
        && has ok_log
             "required_symbols_exported/stub_requirements_vs_library_exports: \
              holds"
        && has ok_log "api_names_present/watchlist_vs_user_surface: holds"
      in
      (* 2 — a missing required symbol. The step still passes: an
         agreement outcome is a finding about artifacts, not a verdict
         on the command. So the disagreement is unconfirmed, detected
         in the artifacts but not surfaced by this action. *)
      let bad_status, bad_log = case "violated" ~lib_symbols:(Some [ "tiny_sum" ]) in
      let violated_ok =
        has bad_log
          "required_symbols_exported/stub_requirements_vs_library_exports: \
           violated: tiny_offset"
        && Poly.equal bad_status Canary_step_model.Step_done
        && has bad_log
             "agreement_unconfirmed  (required_symbols_exported: disagreement \
              detected, not surfaced by this action)"
        && not (has bad_log "agreement_confirmed")
      in
      (* 3 — evidence that was never produced *)
      let _, missing_log = case "unavailable" ~lib_symbols:None in
      let unavailable_ok =
        has missing_log
          "required_symbols_exported/stub_requirements_vs_library_exports: \
           unavailable: no native library inspection in this world"
      in
      (* 4 — an applicable agreement with no evaluator is logged with its
         reason in every case: selection does not drop it, and it never
         reports a synthetic success *)
      let planned_ok =
        List.for_all [ ok_log; bad_log; missing_log ] ~f:(fun l ->
            has l "behavior_matches/probe_assertions: not_implemented:"
            && has l
                 "repack_preserves_api/declared_repacking_relation: \
                  not_implemented:")
      in
      (* what a project cannot carry is not in the log: applicability is
         static, reported once from the spec. signatures_agree under cext
         is the example (no signature extractor for that boundary); both
         halves are checked, so the claim cannot simply vanish *)
      let inapplicable_ok =
        (not
           (has ok_log
              "signatures_agree/header_vs_stub_signature_summaries: \
               not_applicable"))
        && List.exists
             (Canary_agreement.unsuited_here ~mechanism:Canary_mechanism.Cext
                ~lang:Canary_lang.Python ~declared:None)
             ~f:(fun (u : Canary_agreement.unsuited) ->
               String.equal u.Canary_agreement.us_slug "signatures_agree"
               && not (String.is_empty u.Canary_agreement.us_why))
      in
      holds_ok && violated_ok && unavailable_ok && planned_ok
      && inapplicable_ok) }

(* A step whose acceptance consults the evaluation. An
   [Expect_compat_derived] step follows the record: a detected
   disagreement means the command must fail with that signature. The
   chain runs from evidence through evaluation, predicted diagnostics and
   acceptance to the confirmed attribution in the verdict. *)
let agreement_acceptance_test : pure_test =
  { name = "agreements.one_record_serves_reporting_and_acceptance";
    holds = "One evaluation decides both report and acceptance: a predicted failure that occurs is confirmed, one that does not fails the step, and a violation outranks a hold.";
    check = (fun () ->
      let root = "_out/canary/test" in
      let write path body =
        let dir = Stdlib.Filename.dirname path in
        ignore (Stdlib.Sys.command (Printf.sprintf "mkdir -p %s" dir) : int);
        let oc = Stdlib.open_out path in
        Stdlib.output_string oc body;
        Stdlib.close_out oc
      in
      let world =
        Canary_agreement_common.uniform_world ~lang:Canary_lang.OCaml
          ~mechanism:Canary_mechanism.Cstubs Canary_store.Built
      in
      (* [route]: `Derived puts the library evidence where the registry
         looks, `Declared only where a project-supplied input list names
         it (llvm's packed binding). The merge reaches a decided outcome
         either way. *)
      let case name ~route ~cmd =
        let project = "agreement-accept-" ^ name in
        let project_dir = root ^ "/canary/projects/" ^ project in
        ignore (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" project_dir) : int);
        write (project_dir ^ "/build_binding/ocaml/inspect.json")
          {|{"kind": "c_stub", "path": "fx",
    "requires": ["tiny_sum", "tiny_offset"]}|};
        write (project_dir ^ "/build_binding/ocaml/inspect_mli.json")
          {|{"kind": "ocaml_mli", "path": "fx",
    "watchlist": {"present": ["Tiny.sum"], "missing": []}}|};
        let lib_body =
          {|{"kind": "native", "path": "fx", "symbols": ["tiny_sum"]}|}
        in
        let declared_inputs =
          match route with
          | `Derived ->
              write (project_dir ^ "/build_lib/inspect.json") lib_body;
              []
          | `Declared ->
              (* only a place the derivation never looks *)
              write (project_dir ^ "/pack_lib/inspect.json") lib_body;
              Canary_agreement_common.
                [ C_stub [ "build_binding_ocaml/inspect.json" ];
                  Native_lib [ "pack_lib/inspect.json" ] ]
        in
        let log_path = project_dir ^ "/actions.log" in
        let logger = Canary_step_model.create_logger ~log_path in
        let step : Canary_step_model.step =
          { tag = "probe_binding_ocaml";
            output_tag = "probe_binding_ocaml";
            output_dir = project_dir ^ "/probe_binding/ocaml";
            project_dir;
            variant_id = "";
            action = Canary_basic.Probe_binding Canary_lang.OCaml;
            deps = [];
            cmd = (fun ~output_dir:_ ~variant_key:_ -> cmd);
            dep_dirs = [];
            check_post = (fun ~output_dir:_ ~variant_key:_ -> true);
            expectation =
              Canary_step_model.Expect_compat_derived
                { inputs = declared_inputs; version_info = None };
            symbol_check = None;
            disabled_agreements = [];
            agreement_ctx =
              Some
                { Canary_agreement_common.ac_mechanism = Canary_mechanism.Cstubs;
                  ac_lang = Canary_lang.OCaml;
                  ac_world = world;
                  ac_declared = None };
            dummy = None; location = None; inspects = None; bridge = None;
          placeholder = None }
        in
        let status = Canary_local_runner.run_step logger ~root ~project step in
        logger.Canary_step_model.close ();
        let log =
          try Stdlib.In_channel.with_open_text log_path Stdlib.In_channel.input_all
          with _ -> ""
        in
        let marker_ids = Canary_local_runner.step_xfail_contracts step in
        (status, log, marker_ids)
      in
      let has log s = String.is_substring log ~substring:s in
      (* the command fails and prints what the agreement predicted: it
         is accepted, and the attribution is the confirmed agreement *)
      let failing_cmd =
        "echo 'undefined reference to tiny_offset' >&2; exit 1"
      in
      let st, log, ids = case "confirmed" ~route:`Derived ~cmd:failing_cmd in
      let confirmed_ok =
        Poly.equal st Canary_step_model.Step_done_xfail
        && has log
             "required_symbols_exported/stub_requirements_vs_library_exports: \
              violated: tiny_offset"
        && has log "agreement_confirmed  (required_symbols_exported:"
        && (not (has log "agreement_unconfirmed"))
        && has log "expected failure confirmed (derived) [required_symbols_exported]"
        (* the attribution persists in the verdict marker, which warm
           runs and every display read *)
        && List.equal String.equal ids [ "required_symbols_exported" ]
      in
      (* the same artifacts and a command that succeeds: rejected,
         because the record predicted a failure and none happened *)
      let st_ok, log_ok, ids_ok =
        case "unexpected-success" ~route:`Derived ~cmd:"true"
      in
      let polarity_ok =
        Poly.equal st_ok Canary_step_model.Step_failed
        && has log_ok "compat failure predicted (derived) but command succeeded"
        && List.is_empty ids_ok
      in
      (* the declared route reaches evidence the derivation cannot see,
         and merged into the same record it decides the same way *)
      let st_d, log_d, ids_d = case "declared" ~route:`Declared ~cmd:failing_cmd in
      let declared_ok =
        Poly.equal st_d Canary_step_model.Step_done_xfail
        && has log_d
             "required_symbols_exported/stub_requirements_vs_library_exports: \
              violated: tiny_offset"
        (* the derived route found no library inspection, so the
           decided outcome is the declared route's and replaced the
           undecided entry. Matched on this method's name, since the
           identity agreements report the same unavailable reason. *)
        && (not
              (has log_d
                 "stub_requirements_vs_library_exports: unavailable"))
        && List.equal String.equal ids_d [ "required_symbols_exported" ]
      in
      (* both routes decide and disagree: the derived route sees a
         complete library at build_lib (holds), the declared route an
         object missing the symbol (violated). The merge keeps the
         violation. *)
      let both_project = "agreement-accept-both" in
      let both_dir = root ^ "/canary/projects/" ^ both_project in
      ignore (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" both_dir) : int);
      write (both_dir ^ "/build_binding/ocaml/inspect.json")
        {|{"kind": "c_stub", "path": "fx",
    "requires": ["tiny_sum", "tiny_offset"]}|};
      write (both_dir ^ "/build_binding/ocaml/inspect_mli.json")
        {|{"kind": "ocaml_mli", "path": "fx",
    "watchlist": {"present": ["Tiny.sum"], "missing": []}}|};
      write (both_dir ^ "/build_lib/inspect.json")
        {|{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_offset"]}|};
      write (both_dir ^ "/pack_lib/inspect.json")
        {|{"kind": "native", "path": "fx", "symbols": ["tiny_sum"]}|};
      let both_eval =
        Canary_agreement.evaluate_step
          ~context:
            { Canary_agreement_common.ac_mechanism = Canary_mechanism.Cstubs;
              ac_lang = Canary_lang.OCaml;
              ac_world = world;
              ac_declared = None }
          ~action:(Canary_basic.Probe_binding Canary_lang.OCaml)
          ~declared_inputs:
            Canary_agreement_common.
              [ C_stub [ "build_binding_ocaml/inspect.json" ];
                Native_lib [ "pack_lib/inspect.json" ] ]
          ~resolve:(fun rel ->
            match String.lsplit2 rel ~on:'/' with
            | Some (tag, file) ->
                both_dir ^ "/" ^ Canary_basic.step_dir_of_tag tag ^ "/" ^ file
            | None -> both_dir ^ "/" ^ rel)
          ()
      in
      let precedence_ok =
        (* one entry for the method, and it is the violation *)
        List.count both_eval.Canary_agreement.sv_all ~f:(fun e ->
            String.equal e.Canary_agreement.ev_method
              "stub_requirements_vs_library_exports")
        = 1
        && List.exists both_eval.Canary_agreement.sv_violations ~f:(fun e ->
               Poly.equal e.Canary_agreement.ev_id
                 Canary_agreement_common.Required_symbols_exported)
        && List.mem both_eval.Canary_agreement.sv_diagnostics "tiny_offset"
             ~equal:String.equal
      in
      confirmed_ok && polarity_ok && declared_ok && precedence_ok) }

(* A dummy step holds a place in the action graph and does no work.
   Evidence attaches to the graph: a binding's inspection is looked for
   at the step that installs it, and an artifact the interpreter already
   provides has no such step. The marker keeps "nothing to do" apart from
   "did not run", and the dummy mark lets `canary checks --dummies` list
   them. *)
let dummy_action_test : pure_test =
  { name = "steps.dummy_action_holds_a_place";
    holds = "A dummy step's command writes its marker and states its reason, and only the base step is marked dummy, not the inspector it hosts.";
    check = (fun () ->
      let module SB = Canary_step_builder in
      let why = "the interpreter already provides this binding" in
      let out = "_out/canary/test/dummy-fixture" in
      ignore (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" out) : int);
      (* the command a Dummy resolves to writes the action's marker *)
      let cmd =
        SB.command_of_step ~store_config:Canary_store_config.empty_store_config
          ~marker:"binding.ok" (SB.Dummy why)
      in
      let sh = cmd ~output_dir:out ~variant_key:"" in
      let ran = Stdlib.Sys.command (sh ^ " >/dev/null 2>&1") in
      let marker_written =
        ran = 0 && Stdlib.Sys.file_exists (out ^ "/binding.ok")
      in
      (* the reason travels with the command, so a log reader need not
         infer emptiness *)
      let says_why = String.is_substring sh ~substring:why in
      (* and a real spec: the base step is a dummy, its attached
         inspector is not *)
      let spec =
        { SB.empty_runner_spec with
          fetch_binding = [ (Canary_lang.Python, SB.Dummy why) ];
          probe_binding =
            [ ( Canary_lang.Python,
                Canary_store.Build_tree,
                fun ~output_dir:_ ~variant_key:_ -> "true" ) ];
          inspect =
            (fun action _ ->
              match action with
              | Canary_basic.Fetch (Canary_basic.Binding Canary_lang.Python) ->
                  Some (fun ~output_dir:_ ~variant_key:_ -> "true")
              | _ -> None) }
      in
      let steps =
        SB.derive_steps ~root:"_out" ~project:"dummy-fixture"
          ~langs:[ Canary_lang.Python ] spec
      in
      let dummy_tags =
        List.filter_map steps ~f:(fun (s : Canary_step_model.step) ->
            match s.Canary_step_model.dummy with
            | Some _ -> Some s.Canary_step_model.tag
            | None -> None)
      in
      let has tag =
        List.exists steps ~f:(fun (s : Canary_step_model.step) ->
            String.equal s.Canary_step_model.tag tag)
      in
      marker_written && says_why
      (* exactly the base step, and the inspector it hosts is real *)
      && List.equal String.equal dummy_tags [ "fetch_binding_python" ]
      && has "fetch_binding_python_inspect") }

let all_tests : pure_test list =
  catalogue_tests
  @ [ binding_source_vocabulary_test; lib_name_optional_test;
      probe_invariant; inventory_test;
      derive_fetch_lib_test; surface_split_test;
      s2_raw_identity_test; detect_simple_test; coverage_test;
      mechanism_test; enumerate_test; config_level_test; version_axis_test;
      per_artifact_provisions_test; per_artifact_versions_test;
      point_fold_test; project_spec_test;
      per_provision_versions_test; thin_config_level_test;
      shadow_policy_drops_same_cell_built_test;
      refs_subset_test;
      subset_intersects_universe_test; mechanism_catalogue_test; source_fetch_local_test; cmake_install_assert_staged_test; inputs_template_test; mechanism_chain_shape_test;
      dispatch_reads_test; mismatch_direction_test;
      built_from_test; node_of_assignment_test; close_deps_test;
      deploy_mismatch_test;
      agnostic_expectation_test; execution_plan_test;
      agreement_registry_complete_test; agreement_registry_firing_test;
      matrix_marks_from_log_test;
      matrix_agreements_from_log_test;
      marker_stale_on_spec_change_test;
      source_fetch_pinned_ref_check_post_test ]
  @ agreement_fixture_tests
  @ agreement_bridge_tests
  @ [ check_module_pattern_test;
      agreements_for_test; agreement_action_path_test;
      agreement_acceptance_test; dummy_action_test ]

(* [extra]: tests from the layers above canary_lib, which this suite
   cannot see; `canary project-test` passes [Canary_tests.tests] here. *)
let run_tests ?(extra : pure_test list = []) () : bool =
  let all_tests = all_tests @ extra in
  let results = List.map all_tests ~f:(fun t -> (t, run_pure_test t)) in
  List.iter results ~f:(fun (t, ok) ->
    Fmt.pr "[%s] %s@." (if ok then "PASS" else "FAIL") t.name;
    if not ok then
      (* for a catalogue row, print what it got and wanted *)
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
