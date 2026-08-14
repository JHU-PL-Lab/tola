open Base

(** Project-spec PIN tests (A5 phases 1–5) — pure, hermetic checks that a
    live project's DECLARED [project_spec] enumerates to exactly its expected
    scenario set. These reference the real project modules, so they live in
    [canary_project] (canary_lib's test/ sits BELOW this library; src/canary/main is the framework ABOVE it);
    `canary project-test` appends them to the pure project-definition suite
    via [Canary_project_test.run_tests ~extra].

    z3 (phase 1–2) and llvm (phase 5) share ONE shape — the two-chain
    project (dev build chain / stable fetch chain) — so their pins are one
    parameterized generator ([two_chain_pins]): the spec enumerates to the
    current 2 variants BEFORE any runner change, the dispatch reads only the
    lib placement, and the provider table backs the baseline provisions. *)

module B = Canary_basic
module EN = Canary_enumerate

let py_cext = Canary_artifact.a_binding Canary_lang.Python Canary_mechanism.Cext

(* The scenario-identity key: a Fetched artifact is version-AMBIENT (the
   PM/opam picks the concrete version), so its declared channel is not part
   of scenario identity — UNLESS the placement carries a STORE PIN (a
   pinned version id, 2026-08-12), which is identity-bearing. Built/Vendored
   versions are. Mirrors the general rule in
   [Canary_project_run.scenario_dir_of]; if that rule changes, change both. *)
let ambient_key (a : Canary_artifact.assignment) : string =
  List.map a ~f:(fun (id, (pl : Canary_artifact.placement)) ->
      Printf.sprintf "%s=%s@%s" (Canary_artifact.string_of_id id)
        (EN.string_of_provision pl.Canary_artifact.provision)
        (match pl.Canary_artifact.provision with
         | EN.Fetched ->
             if String.equal pl.Canary_artifact.version.Canary_basic.id "" then
               "ambient"
             else
               "pin-" ^ pl.Canary_artifact.version.Canary_basic.id
         | _ -> Canary_basic.string_of_build_id pl.Canary_artifact.version))
  |> List.sort ~compare:String.compare
  |> String.concat ~sep:"_"

let enumerate_full (spec : Canary_artifact.project_spec) : Canary_artifact.assignment list =
  Canary_enumerate.enumerate ~tag:(fun () -> "") ~policy:(Canary_enumerate.full_policy ()) spec

(* The three pins for a TWO-CHAIN project (the z3/llvm shape: source
   Fetched@{Stable,Dev}, lib Fetched@Stable | Built@Dev, python binding
   Fetched@Stable; the OCaml binding not enumerated — it follows the chain).
   [dispatch_is_dev] projects the project's own [scenario_case] dispatch to
   "is the dev build chain". *)
let two_chain_pins ~(prefix : string) ~(spec : Canary_artifact.project_spec)
    ~(artifacts : Canary_project_spec.artifact_row list)
    ~(dispatch_is_dev : Canary_artifact.assignment -> bool) :
    Canary_project_test.pure_test list =
  let lib_prov a = Canary_enumerate.provision_of a Canary_artifact.a_lib in
  (* dev variant: the coherent build chain — source@Dev, lib Built@Dev *)
  let is_dev a =
    EN.equal_provision (lib_prov a) EN.Built
    && Canary_basic.equal_version (Canary_enumerate.version_of a Canary_artifact.a_lib) (Canary_basic.good B.Dev)
    && Canary_basic.equal_version (Canary_enumerate.version_of a Canary_artifact.a_source) (Canary_basic.good B.Dev)
  in
  (* stable variant: the all-Fetched chain (source channel ambient) *)
  let is_stable_world a =
    EN.equal_provision (lib_prov a) EN.Fetched
    && EN.equal_provision (Canary_enumerate.provision_of a Canary_artifact.a_source) EN.Fetched
  in
  [ (* enumerate(spec) == the current 2 variants. Product-then-filter yields
       THREE assignments — the source-primary filter prunes (source@Stable ×
       lib Built@Dev), and the two all-Fetched assignments collapse under
       the ambient identity rule into ONE stable scenario — leaving exactly
       {dev chain, stable chain}, baseline (head) = the all-Fetched chain. *)
    { Canary_project_test.name =
        prefix ^ ".spec_enumerates_current_variants";
      check = (fun () ->
        let asgs = enumerate_full spec in
        let scenario_ids =
          List.dedup_and_sort ~compare:String.compare
            (List.map asgs ~f:ambient_key)
        in
        List.length asgs = 3
        && List.count asgs ~f:is_dev = 1
        && List.count asgs ~f:is_stable_world = 2
        (* the two all-Fetched assignments are ONE world: 2 ids total *)
        && List.length scenario_ids = 2
        (* the python binding row is variant-invariant: Fetched everywhere *)
        && List.for_all asgs ~f:(fun a ->
               EN.equal_provision (Canary_enumerate.provision_of a py_cext) EN.Fetched)
        (* source-primary pruned the incoherent build: no Built lib over
           the stable source *)
        && (not
              (List.exists asgs ~f:(fun a ->
                   EN.equal_provision (lib_prov a) EN.Built
                   && Canary_basic.equal_version (Canary_enumerate.version_of a Canary_artifact.a_source)
                        (Canary_basic.good B.Stable))))
        (* baseline (enumeration head) = the all-Fetched stable chain *)
        && match asgs with x :: _ -> is_stable_world x | [] -> false) };
    (* the dispatch is pure data over enumeration coordinates — pin that it
       reads the LIB placement only (Built ⇒ dev build chain), so BOTH
       all-Fetched assignments (either ambient source channel) dispatch to
       the stable chain: the dedup-surviving representative realizes the
       same chain no matter which one runs. [realize] is deliberately NOT
       called (command templates shell into distro/PM detection). *)
    { name = prefix ^ ".dispatch_reads_lib_placement_only";
      check = (fun () ->
        let asgs = enumerate_full spec in
        let cases = List.map asgs ~f:dispatch_is_dev in
        List.count cases ~f:Fn.id = 1
        && List.count cases ~f:not = 2
        && List.for_all2_exn asgs cases ~f:(fun a dev ->
               Bool.equal dev
                 (EN.equal_provision (lib_prov a) EN.Built))) };
    (* the provider table backs the BASELINE provisions — pin the drift
       check `spec` performs at display time (provider's coarse provision
       == the enumerated baseline placement, for every artifact the
       enumeration places), so the declared detail can't contradict the
       axis. *)
    { name = prefix ^ ".providers_match_baseline_provisions";
      check = (fun () ->
        match enumerate_full spec with
        | [] -> false
        | baseline :: _ ->
            List.for_all artifacts
              ~f:(fun (d : Canary_project_spec.artifact_row) ->
                match
                  ( d.Canary_project_spec.ar_provider,
                    Canary_enumerate.placement_of baseline d.Canary_project_spec.ar_artifact )
                with
                | None, _ -> true (* no provider declared — nothing to check *)
                | Some _, None ->
                    true (* display-only — no axis to contradict *)
                | Some p, Some pl ->
                    EN.equal_provision
                      (Canary_store_config.provision_of_provider p)
                      pl.Canary_artifact.provision)) } ]

let z3_pins : Canary_project_test.pure_test list =
  two_chain_pins ~prefix:"z3" ~spec:(Canary_project_spec.project_spec_of_rows Canary_project_z3.z3_artifacts)
    ~artifacts:Canary_project_z3.z3_artifacts
    ~dispatch_is_dev:(fun a ->
      Canary_enumerate.equal_provision
        (Canary_enumerate.provision_of a Canary_artifact.a_lib)
        Canary_artifact.Built)

let llvm_pins : Canary_project_test.pure_test list =
  two_chain_pins ~prefix:"llvm" ~spec:(Canary_project_spec.project_spec_of_rows Canary_project_llvm.llvm_artifacts)
    ~artifacts:Canary_project_llvm.llvm_artifacts
    ~dispatch_is_dev:(fun a ->
      Canary_enumerate.equal_provision
        (Canary_enumerate.provision_of a Canary_artifact.a_lib)
        Canary_artifact.Built)

(* ── A7 phase 3 pins: z3/llvm run the DERIVED lowering ──
   Pure shape of the expectation closure over the REAL binding tables (no
   runner_spec construction — that shells into PM detection). *)

let sm_is_success = function
  | Canary_step_model.Expect_success -> true
  | _ -> false

let pip_loc =
  Some
    (Canary_store.Pm
       (Canary_store.Lang_pm { lang = Canary_lang.Python; pm = Canary_store.Pip }))

(* z3: derived at the (python probe × pip) firing site, success everywhere
   else — the oracle knobs (violates/has_manifest) are gone; the runner's
   inspection of the wheel decides at run time. *)
let z3_lowering_derived : Canary_project_test.pure_test =
  { name = "z3.lowering_derived_at_python_probe";
    check = (fun () ->
      let lower =
        Canary_scenario.lower_expectation_agnostic
          ~bindings:Canary_project_z3.z3_contract_bindings
          ~langs:[ Canary_lang.Python ]
      in
      (match lower (B.Probe_binding Canary_lang.Python) pip_loc with
       | Canary_step_model.Expect_compat_derived { inputs; _ } ->
           List.exists inputs ~f:(function
             | Canary_compat.Python_attrs _ -> true
             | _ -> false)
       | _ -> false)
      && sm_is_success (lower (B.Probe_binding Canary_lang.OCaml) None)
      && sm_is_success (lower B.Build_lib None)) }

(* llvm: derived at the OCaml probe (any loc) with the full merged inputs
   bag; python probe stays success (llvmlite bundles its own lib). The
   PACK-FIRST input order is LOAD-BEARING — it is what exempts the dev
   chain (first-existing resolution reads the dev-built binding's inspects
   → empty prediction → success expected), replacing the retired
   has_manifest knob. *)
let llvm_lowering_derived : Canary_project_test.pure_test =
  { name = "llvm.lowering_derived_pack_side_first";
    check = (fun () ->
      let lower =
        Canary_scenario.lower_expectation_agnostic
          ~bindings:Canary_project_llvm.llvm_stable_contract_bindings
          ~langs:[ Canary_lang.OCaml ]
      in
      (match lower (B.Probe_binding Canary_lang.OCaml) None with
       | Canary_step_model.Expect_compat_derived { inputs; _ } ->
           let has p = List.exists inputs ~f:p in
           has (function Canary_compat.C_stub _ -> true | _ -> false)
           && has (function Canary_compat.Native_lib _ -> true | _ -> false)
           && has (function Canary_compat.Ocaml_mli _ -> true | _ -> false)
           (* dev-chain exemption: pack/build-tree path FIRST per input *)
           && List.for_all inputs ~f:(function
                | Canary_compat.C_stub (p :: _)
                | Canary_compat.Ocaml_mli (p :: _) ->
                    String.is_prefix p ~prefix:"pack_binding_ocaml/"
                | Canary_compat.Native_lib (p :: _) ->
                    String.is_prefix p ~prefix:"probe_lib/"
                | _ -> true)
       | _ -> false)
      && sm_is_success (lower (B.Probe_binding Canary_lang.Python) pip_loc)) }

(* ── milestone-(b) first slice pin: declared runtime edges (on the spec
   rows' [ax_runtime]) resolve to the two-instance pairing per scenario ──
   sqlite (the live case): python is Ambient in EVERY world (bundled lib —
   no run placement, never a deploy pairing); the OCaml pairing's run-lib
   IS the scenario's lib placement, and exactly the two Built worlds are
   deploy pairings (run-lib canary-supplied while the fetched binding was
   built against its provider's lib). *)
let sqlite_runtime_edges_pin : Canary_project_test.pure_test =
  { name = "sqlite.runtime_edges_two_instance_slice";
    check = (fun () ->
      let spec = Canary_project_spec.project_spec_of_rows Canary_project_sqlite.sqlite_artifacts in
      let asgs = enumerate_full spec in
      let oc = Canary_artifact.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs in
      let find c a =
        List.find (Canary_enumerate.runtime_pairings_of spec a) ~f:(fun p ->
            Canary_artifact.equal_artifact_id p.Canary_enumerate.rp_consumer c)
      in
      List.length asgs = 3
      && List.for_all asgs ~f:(fun a ->
             (match find py_cext a with
              | Some p -> (
                  match p.Canary_enumerate.rp_mode with
                  | Canary_store.Ambient _ ->
                      Option.is_none p.Canary_enumerate.rp_run && not p.Canary_enumerate.rp_deploy
                  | _ -> false)
              | None -> false)
             && (match find oc a with
                 | Some p ->
                     Poly.equal p.Canary_enumerate.rp_run (Canary_enumerate.placement_of a Canary_artifact.a_lib)
                 | None -> false))
      && List.count asgs ~f:(fun a ->
             match find oc a with Some p -> p.Canary_enumerate.rp_deploy | None -> false)
         = 2) }

(* ── The ARROW unification pin (user, 2026-08-06) ──
   provider → action → artifact, with fetch and build the same shape.
   Over EVERY live artifact table: the providing action must agree with
   the provider's coarse provision ([Fetched] ⇒ [Fetch kind]; [Built] ⇒
   the kind's Build action; [Vendored]/[Cached] ⇒ None — supplied, the
   boundary), and round-trip through the enumeration's INVERSE read
   ([provision_of_actions]: the action set implies the provision back). *)
let providing_arrow_pin : Canary_project_test.pure_test =
  { name = "arrow.providing_action_total_and_consistent";
    check = (fun () ->
      let tables =
        Canary_project_sqlite.sqlite_artifacts
        @ Canary_project_z3.z3_artifacts @ Canary_project_llvm.llvm_artifacts
        @ Canary_project_tiny.tiny_full_run.Canary_project_run.pr_artifacts
      in
      List.for_all tables
        ~f:(fun (d : Canary_project_spec.artifact_row) ->
          match d.Canary_project_spec.ar_provider with
          | None -> true
          | Some p -> (
              let id = d.Canary_project_spec.ar_artifact in
              let k = Canary_artifact.kind_of id in
              let act = Canary_store_config.providing_action_of k p in
              match
                (Canary_store_config.provision_of_provider p, act)
              with
              | Canary_store.Fetched, Some (B.Fetch k') -> Poly.equal k k'
              | Canary_store.Built, Some a ->
                  (match a with
                   | B.Build_lib | B.Build_binding _ | B.Build_headers -> true
                   | _ -> false)
                  (* the inverse read agrees: the arrow's action implies
                     the provision back (Fetch/Build → Fetched/Built) *)
                  && Poly.equal
                       (Canary_enumerate.provision_of_actions [ a ] id)
                       EN.Built
              | Canary_store.Vendored, None -> true
              | Canary_store.Absent, None -> true
              | _ -> false))
      (* and the Fetched half of the round-trip on a concrete row *)
      && Poly.equal
           (Canary_enumerate.provision_of_actions [ B.Fetch B.Lib ] Canary_artifact.a_lib)
           EN.Fetched
      (* self-contained providers must derive an Ambient runtime edge (A5
         residue (ii), 2026-08-06): the dep_mode value source is the
         provider, not a hand-written annotation. *)
      && List.for_all tables ~f:(fun (d : Canary_project_spec.artifact_row) ->
             match d.Canary_project_spec.ar_provider with
             | Some p -> (
                 match Canary_store_config.dep_mode_of_provider p with
                 | Some (Canary_store.Ambient _) ->
                     (* self-contained → Ambient: the provider bundles its
                        own lib (the co-provider case — z3-solver, llvmlite,
                        sqlite3 stdlib). *)
                     true
                 | None -> true
                 | _ -> false)
             | None -> true)) }

(* ── A5 residue (iii) pin: binding-follows-chain ──
   The OCaml binding's [ax_follows:a_lib] constrains its version channel to
   the lib's in every assignment. Pins this for z3 and llvm (the two projects
   that declare the OCaml binding as following the lib). *)
let binding_follows_chain_pin ~prefix ~(spec : Canary_artifact.project_spec) :
    Canary_project_test.pure_test =
  { name = prefix ^ ".binding_follows_chain";
    check = (fun () ->
      let asgs = Canary_enumerate.(enumerate ~tag:(fun () -> "") ~policy:(full_policy ()) spec) in
      let ocaml = Canary_artifact.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs in
      let lib = Canary_artifact.a_lib in
      List.for_all asgs ~f:(fun a ->
          (not (Canary_enumerate.provided a ocaml))
          || (not (Canary_enumerate.provided a lib))
          || Canary_basic.equal_channel
               (Canary_enumerate.channel_of a ocaml)
               (Canary_enumerate.channel_of a lib))
      && (* the follows constraint is doing work: the spec declares both
            provisions for the OCaml binding, yet no cross-channel pair
            survives *)
      (not
         (List.exists asgs ~f:(fun a ->
              Canary_enumerate.provided a ocaml && Canary_enumerate.provided a lib
              && not
                   (Canary_basic.equal_channel
                      (Canary_enumerate.channel_of a ocaml)
                      (Canary_enumerate.channel_of a lib)))))) }

(* ── integration smoke (2026-08-09) ──
   End-to-end: runs scenarios_of on every live project and checks
   scenario counts. Pure — no builds, no PM. *)

let integration_smoke : Canary_project_test.pure_test =
  { Canary_project_test.name = "integration.smoke";
    check = (fun () ->
      let check ~name ~want_count run =
        let asgs = Canary_project_run.scenarios_of run in
        let n = List.length asgs in
        if n <> want_count then
          Fmt.pr "  %s: want %d scenarios, got %d@." name want_count n;
        n = want_count
      in
      let ok1 = check ~name:"sqlite" ~want_count:3
          Canary_project_sqlite.sqlite_run in
      let ok2 = check ~name:"z3" ~want_count:3
          (Canary_project_z3.z3_run (Canary_basic.detect_distro ())) in
      let ok3 = check ~name:"llvm" ~want_count:3
          (Canary_project_llvm.llvm_run (Canary_basic.detect_distro ())) in
      let ok4 = check ~name:"tiny-full" ~want_count:1
          Canary_project_tiny.tiny_full_run in
      ok1 && ok2 && ok3 && ok4) }

(* ── registry pin (2026-08-12) ──
   The single source of truth for project names: every entry must enumerate
   to a non-empty scenario set, and ssl's pinned binding enumerates TWO
   distinct scenarios (one per store pin). Adding a project without a
   registry entry (or breaking an entry's enumeration) fails here. *)
let registry_pin : Canary_project_test.pure_test =
  { name = "registry.entries_enumerate";
    check = (fun () ->
      let entries = Canary_registry.all_projects in
      let names = List.map entries ~f:fst in
      let want_names =
        [ "sqlite"; "z3"; "llvm"; "tiny-full"; "zarith"; "cairo"; "libffi"; "ssl" ]
      in
      let sorted_names = List.sort names ~compare:String.compare in
      let sorted_want = List.sort want_names ~compare:String.compare in
      let names_ok = Poly.equal sorted_names sorted_want in
      if not names_ok then
        Fmt.pr "  registry names: got [%s]@."
          (String.concat ~sep:", " names);
      let projects_ok =
        List.for_all entries ~f:(fun (_n, pr) ->
            not (List.is_empty (Canary_project_run.scenarios_of pr)))
      in
      (* the store-pin axis: ssl's pinned binding enumerates 2 scenarios
         with distinct identity (the pins ARE the axis). *)
      let ssl_pins_ok =
        match List.Assoc.find entries "ssl" ~equal:String.equal with
        | None -> false
        | Some pr ->
            let asgs = Canary_project_run.scenarios_of pr in
            let binding = Canary_project_ssl.ssl_binding_art in
            List.length asgs = 2
            && List.for_all asgs ~f:(fun a ->
                   not
                     (String.equal
                        (Canary_enumerate.version_of a binding).Canary_basic.id
                        ""))
            && List.length
                 (List.dedup_and_sort
                    (List.map asgs ~f:(fun a ->
                         (Canary_enumerate.version_of a binding).Canary_basic.id))
                    ~compare:String.compare)
                 = 2
      in
      names_ok && projects_ok && ssl_pins_ok) }

(* ── tiny1-via-general-path bridge (2026-08-09) ──
   Two-part proof that tiny1 scenarios work through the general canary
   pipeline:

   Part A (structural): a tiny1 scenario converted to a [project_run]
   (all artifacts Vendored@Stable — canary knows nothing about the
   mutation) enumerates to exactly 1 assignment, and the runner_spec
   carries the agnostic expectation (not the oracle).

   Part B (expectation): for all 22 tiny1 scenarios, where the oracle
   says must-fail, the agnostic is NOT blind (Expect_success). The
   reverse doesn't hold: agnostic casts a wider net — a feature.

   Together they prove: take a tiny1 scenario → convert to project_run
   → run through general pipeline → agnostic detection covers every
   failure the oracle predicts. *)

let is_must_fail : Canary_step_model.step_expectation -> bool = function
  | Canary_step_model.Expect_compat_failure _ | Canary_step_model.Expect_failure _ -> true
  | _ -> false

let is_blind : Canary_step_model.step_expectation -> bool = function
  | Canary_step_model.Expect_success -> true
  | _ -> false

(* Actions where oracle expectations are meaningful. *)
let probe_actions : Canary_basic.action list =
  B.[ Build_lib; Build_binding Canary_lang.OCaml;
      Build_binding Canary_lang.Python; Probe_lib;
      Probe_binding Canary_lang.OCaml; Probe_binding Canary_lang.Python ]

let tiny1_bridge : Canary_project_test.pure_test =
  { name = "tiny1.project_run_and_oracle_cover";
    check = (fun () ->
      let module CS = Canary_scenario in
      let module SM = Canary_step_model in
      let module TS = Canary_tiny_scenario in
      let module SB = Canary_step_builder in
      (* ── Part A: a tiny1 scenario AS a project_run ── *)
      (* Dummy runner_spec — returns empty with agnostic expectation.
         The real [project_run_of_tiny1] calls [make_base_runner_spec]
         which shells out; this pure version verifies the enumeration
         structure without shelling. *)
      let pr : Canary_project_run.project_run =
        { pr_name = "tiny1/Bs.1";
          pr_artifacts = Canary_project_tiny.tiny_artifact_table;
          pr_runner_spec = (fun _a ~workspace:_ ->
            { SB.empty_runner_spec with
              SB.expectation = Canary_project_tiny.expectation_agnostic });
          pr_mismatch_probes = [];
          pr_wrapper_pkgs = [];
          pr_api_source = None;
          pr_tier = Canary_project_run.Light }
      in
      let asgs = Canary_project_run.scenarios_of pr in
      (* Exactly 1 scenario: all artifacts Vendored@Stable *)
      let ok_one = List.length asgs = 1 in
      let ok_all_vendored =
        match asgs with
        | [ a ] ->
            List.for_all a ~f:(fun (_id, pl) ->
                EN.equal_provision pl.Canary_artifact.provision EN.Vendored)
        | _ -> false
      in
      (* The runner_spec carries the agnostic expectation — not
         blind ([Expect_success]) at the probe site. Accepts both
         [Expect_compat_derived] (artifact inspection decides) and
         [Expect_failure] (behavioral grep — must fail). *)
      let ok_agnostic =
        match asgs with
        | a :: _ ->
            let spec = pr.Canary_project_run.pr_runner_spec a ~workspace:"/tmp" in
            let e = spec.SB.expectation (B.Probe_binding Canary_lang.OCaml) None in
            not (is_blind e)
        | _ -> false
      in
      (* ── Part B: oracle covered by agnostic across all 22 scenarios ── *)
      let agnostic = CS.lower_expectation_agnostic
          ~bindings:TS.tiny_contract_bindings
          ~langs:Canary_lang.[ OCaml; Python ]
      in
      let ok_entry (entry : TS.scenario_spec) =
        let oracle = TS.expectation_of_entry entry in
        List.for_all probe_actions ~f:(fun action ->
            let o = oracle action None in
            let a = agnostic action None in
            (not (is_must_fail o)) || not (is_blind a))
      in
      let gaps =
        List.filter TS.all_scenario_specs ~f:(fun e -> not (ok_entry e))
      in
      if not (List.is_empty gaps) then
        Fmt.pr "  oracle→agnostic gaps: %s@."
          (String.concat ~sep:", "
             (List.map gaps ~f:(fun e -> e.TS.scenario.Canary_scenario.name)));
      let ok_part_b = List.is_empty gaps in
      (* ── Part C: expected-outcome reference is well-formed ──
         [canary_expected_of] maps every scenario's recipe to canary
         step tags. For each xfail tag, the corresponding action string
         must parse back to a known action. This pins the mapping table
         — if a recipe step name changes or a tag string drifts, it
         breaks here. *)
      let ok_mapping (entry : TS.scenario_spec) =
        let ex = TS.canary_expected_of entry in
        List.for_all ex.TS.ce_must_xfail ~f:(fun tag ->
          Option.is_some (B.action_of_string tag))
      in
      let mapping_gaps =
        List.filter TS.all_scenario_specs ~f:(fun e -> not (ok_mapping e))
      in
      if not (List.is_empty mapping_gaps) then
        Fmt.pr "  canary_expected_of unparseable tags: %s@."
          (String.concat ~sep:", "
             (List.map mapping_gaps ~f:(fun e -> e.TS.scenario.Canary_scenario.name)));
      let ok_part_c = List.is_empty mapping_gaps in
      ok_one && ok_all_vendored && ok_agnostic && ok_part_b && ok_part_c) }

(* M2 step 4 pin (2026-08-13): the binding declaration's FACTS match
   tiny's existing hand-written declarations — the decl is the same
   project fact, typed. When the hand-written api_source moves fully
   behind the decl (step 4's command derivation), this pin is the
   no-behavior-change guarantee. *)
let binding_decl_pin : Canary_project_test.pure_test =
  { name = "tiny1.binding_decl_facts_match_handwritten";
    check = (fun () ->
      let module BD = Canary_binding_decl in
      let module TS = Canary_tiny_scenario in
      let decls = Canary_project_tiny.tiny_binding_decls in
      let find_mech m =
        List.find decls ~f:(fun (d : BD.binding_decl) ->
          Poly.equal d.mechanism m)
      in
      let c_api_matches (d : BD.binding_decl) =
        Poly.equal d.facts.c_api.functions TS.tiny_native_stable_symbols
      in
      let native_matches (d : BD.binding_decl) =
        String.equal d.facts.native.prefix "tiny_"
        && String.equal d.facts.native.soname "libtiny.so.1"
        && Poly.equal d.facts.native.headers.files [ "tiny.h" ]
      in
      match
        ( find_mech Canary_mechanism.Cstubs,
          find_mech Canary_mechanism.Cext,
          find_mech Canary_mechanism.Ctypes )
      with
      | Some cstubs, Some cext, Some ctypes ->
          (* every decl carries the shared c_api + native facts *)
          List.for_all [ cstubs; cext; ctypes ] ~f:(fun d ->
              c_api_matches d && native_matches d)
          && (* cstubs: the stub archive the hand-written build produces *)
          (match cstubs.facts.BD.coupling with
           | BD.Stub_archive sa ->
               Poly.equal sa.sources [ "ocaml/tiny_stubs.c" ]
               && String.equal sa.archive "ocaml/libtiny_stubs.a"
               && (match sa.build with
                   | BD.Dune { targets } ->
                       Poly.equal targets
                         [ "ocaml/tiny.cmxa"; "ocaml/libtiny_stubs.a" ])
           | _ -> false)
          && (* cext: the .so the hand-written cc produces *)
          (match cext.facts.BD.coupling with
           | BD.Compiled_ext ce ->
               String.equal ce.source "python_cext/tiny_cext/_native.c"
               && String.equal ce.product "_native.cpython-*.so"
               && (match ce.build with
                   | BD.Direct_cc dc -> Poly.equal dc.libs [ "tiny" ])
           | _ -> false)
          && (* ctypes: dlopen by the soname the loader resolves *)
          (match ctypes.facts.BD.coupling with
           | BD.Dlopen { name } -> String.equal name "libtiny.so.1"
           | _ -> false)
          && (* surface paths match the mli / py files the inspectors read *)
          String.equal cstubs.facts.BD.surface_path "ocaml/tiny.mli"
          && String.equal cext.facts.BD.surface_path
               "python_cext/tiny_cext/__init__.py"
          && String.equal ctypes.facts.BD.surface_path
               "python_ctypes/tiny_ctypes/__init__.py"
      | _ -> false) }

(* ── spec-check pins (2026-08-13) ── *)

(* (a) every registry entry yields a well-formed report (no crash, 8
   items, non-empty ids) — the smoke half. *)
let spec_check_every_project_pin : Canary_project_test.pure_test =
  { name = "spec_check.every_project_reports";
    check =
      (fun () ->
        List.for_all Canary_registry.all_projects ~f:(fun (name, pr) ->
            let r = Canary_spec_check.check pr in
            String.equal r.project name
            && List.length r.items = 8
            && List.for_all r.items ~f:(fun i ->
                   not (String.equal i.item_id "")))) }

(* (b) exact current Error/Warn/Na id-sets per project — THE fulfillment
   tracker: closing a gap (sqlite wiring a source row, pattern-A gaining
   typed providers, llvm's Publish row) fails this test until updated. *)
let spec_check_ratchet_pin : Canary_project_test.pure_test =
  let open Canary_spec_check in
  let ids sev r =
    List.filter_map r.items ~f:(fun i ->
        if Poly.equal i.severity sev then Some i.item_id else None)
    |> List.sort ~compare:String.compare
  in
  let want ~errs ~warns ~na name =
    let pr = List.Assoc.find_exn Canary_registry.all_projects name
        ~equal:String.equal in
    let r = check pr in
    let good =
      Poly.equal (ids Error r) errs
      && Poly.equal (ids Warn r) warns
      && Poly.equal (ids Na r) na
    in
    if not good then
      Fmt.pr "spec_check.ratchet_current: %s drifted (errors=%s warns=%s na=%s)@."
        name (String.concat ~sep:"," (ids Error r))
        (String.concat ~sep:"," (ids Warn r))
        (String.concat ~sep:"," (ids Na r));
    good
  in
  (* the remaining pattern-A warns (2026-08-13 fulfillment closed the
     errors): no wrapper pkg, no python binding, no Built binding axis. *)
  let pat_warns =
    [ "binding_dev_source"; "dev_wrapper_package"; "python_binding" ]
  in
  { name = "spec_check.ratchet_current";
    check =
      (fun () ->
        want ~errs:[] ~warns:[] ~na:[] "z3"
        && want ~errs:[] ~warns:[ "dev_wrapper_package" ] ~na:[] "llvm"
        && want ~errs:[]
             ~warns:[ "binding_dev_source"; "dev_wrapper_package" ] ~na:[]
             "sqlite"
        && want ~errs:[] ~warns:pat_warns ~na:[] "ssl"
        && want ~errs:[] ~warns:pat_warns ~na:[] "zarith"
        && want ~errs:[] ~warns:pat_warns ~na:[] "cairo"
        && want ~errs:[] ~warns:pat_warns ~na:[] "libffi"
        && want ~errs:[]
             ~warns:[ "binding_dev_source"; "dev_wrapper_package" ]
             ~na:[ "github_remote"; "opam_package" ] "tiny-full") }

(* The batch tier (2026-08-14): Heavy = source-built chains (z3/llvm);
   [batch_policy] maps Heavy → thin (Subset[Stable] bypasses the Dev
   builds), Light → full. THE pin for the batch default config. *)
let batch_tier_pin : Canary_project_test.pure_test =
  { name = "registry.batch_tiers";
    check =
      (fun () ->
        let pr_of name =
          List.Assoc.find_exn Canary_registry.all_projects name
            ~equal:String.equal
        in
        let tier name = (pr_of name).Canary_project_run.pr_tier in
        Poly.equal (tier "z3") Canary_project_run.Heavy
        && Poly.equal (tier "llvm") Canary_project_run.Heavy
        && List.for_all
             [ "sqlite"; "ssl"; "tiny-full"; "zarith"; "cairo"; "libffi" ]
             ~f:(fun n -> Poly.equal (tier n) Canary_project_run.Light)
        && Poly.equal (Canary_project_run.batch_policy (pr_of "z3"))
             Canary_project_run.Thin
        && Poly.equal (Canary_project_run.batch_policy (pr_of "sqlite"))
             Canary_project_run.Full
        && Poly.equal (Canary_project_run.batch_policy (pr_of "llvm"))
             Canary_project_run.Thin) }

let tests : Canary_project_test.pure_test list =
  z3_pins @ llvm_pins
  @ [ z3_lowering_derived; llvm_lowering_derived;
      binding_follows_chain_pin ~prefix:"z3" ~spec:(Canary_project_spec.project_spec_of_rows Canary_project_z3.z3_artifacts);
      binding_follows_chain_pin ~prefix:"llvm" ~spec:(Canary_project_spec.project_spec_of_rows Canary_project_llvm.llvm_artifacts);
      sqlite_runtime_edges_pin; providing_arrow_pin;
      tiny1_bridge;
      integration_smoke;
      registry_pin;
      spec_check_every_project_pin;
      spec_check_ratchet_pin;
      batch_tier_pin ]
