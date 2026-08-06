open Base

(** Project-spec PIN tests (A5 phases 1–5) — pure, hermetic checks that a
    live project's DECLARED [project_spec] enumerates to exactly its expected
    scenario set. These reference the real project modules, so they live in
    [canary_projects] (canary_lib's test/ sits BELOW this sub-library);
    `canary project-test` appends them to the pure project-definition suite
    via [Canary_project_test.run_tests ~extra].

    z3 (phase 1–2) and llvm (phase 5) share ONE shape — the two-chain
    project (dev build chain / stable fetch chain) — so their pins are one
    parameterized generator ([two_chain_pins]): the spec enumerates to the
    current 2 variants BEFORE any runner change, the dispatch reads only the
    lib placement, and the provider table backs the baseline provisions. *)

module B = Canary_basic
module EN = Canary_enumerate

let py_cext = EN.a_binding Canary_lang.Python Canary_mechanism.Cext

(* The scenario-identity key: a Fetched artifact is version-AMBIENT (the
   PM/opam picks the concrete version), so its declared channel is not part
   of scenario identity; Built/Vendored versions are. Mirrors the general
   rule in [canary_main.scenario_dir_of] (bin layer — not importable here);
   if that rule changes, change both. *)
let ambient_key (a : EN.assignment) : string =
  List.map a ~f:(fun (id, (pl : EN.placement)) ->
      Printf.sprintf "%s=%s@%s" (EN.string_of_id id)
        (EN.string_of_provision pl.EN.provision)
        (match pl.EN.provision with
         | EN.Fetched -> "ambient"
         | _ -> EN.string_of_version pl.EN.version))
  |> List.sort ~compare:String.compare
  |> String.concat ~sep:"_"

let enumerate_full (spec : EN.project_spec) : EN.assignment list =
  EN.enumerate ~tag:(fun () -> "") ~policy:(EN.full_policy ()) spec

(* The three pins for a TWO-CHAIN project (the z3/llvm shape: source
   Fetched@{Stable,Dev}, lib Fetched@Stable | Built@Dev, python binding
   Fetched@Stable; the OCaml binding not enumerated — it follows the chain).
   [dispatch_is_dev] projects the project's own [scenario_case] dispatch to
   "is the dev build chain". *)
let two_chain_pins ~(prefix : string) ~(spec : EN.project_spec)
    ~(providers : (EN.artifact_id * Canary_store_config.provider) list)
    ~(dispatch_is_dev : EN.assignment -> bool) :
    Canary_project_test.pure_test list =
  let lib_prov a = EN.provision_of a EN.a_lib in
  (* dev variant: the coherent build chain — source@Dev, lib Built@Dev *)
  let is_dev a =
    EN.equal_provision (lib_prov a) EN.Built
    && EN.equal_version (EN.version_of a EN.a_lib) (EN.good B.Dev)
    && EN.equal_version (EN.version_of a EN.a_source) (EN.good B.Dev)
  in
  (* stable variant: the all-Fetched chain (source channel ambient) *)
  let is_stable_world a =
    EN.equal_provision (lib_prov a) EN.Fetched
    && EN.equal_provision (EN.provision_of a EN.a_source) EN.Fetched
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
               EN.equal_provision (EN.provision_of a py_cext) EN.Fetched)
        (* source-primary pruned the incoherent build: no Built lib over
           the stable source *)
        && (not
              (List.exists asgs ~f:(fun a ->
                   EN.equal_provision (lib_prov a) EN.Built
                   && EN.equal_version (EN.version_of a EN.a_source)
                        (EN.good B.Stable))))
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
            List.for_all providers ~f:(fun (id, p) ->
                match EN.placement_of baseline id with
                | None -> true (* display-only — no axis to contradict *)
                | Some pl ->
                    EN.equal_provision
                      (Canary_store_config.provision_of_provider p)
                      pl.EN.provision)) } ]

let z3_pins : Canary_project_test.pure_test list =
  two_chain_pins ~prefix:"z3" ~spec:Canary_project_z3.z3_spec
    ~providers:Canary_project_z3.z3_providers
    ~dispatch_is_dev:(fun a ->
      match Canary_project_z3.dispatch a with
      | Canary_project_z3.Dev_chain -> true
      | Canary_project_z3.Stable_chain -> false)

let llvm_pins : Canary_project_test.pure_test list =
  two_chain_pins ~prefix:"llvm" ~spec:Canary_project_llvm.llvm_spec
    ~providers:Canary_project_llvm.llvm_providers
    ~dispatch_is_dev:(fun a ->
      match Canary_project_llvm.dispatch a with
      | Canary_project_llvm.Dev_chain -> true
      | Canary_project_llvm.Stable_chain -> false)

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

(* ── #47 drift guard ──
   Until the has_build_* → provision-axis fold lands (status §A A5
   residue), the source flags and the declared universe are TWO encodings
   of build capability. Pin them consistent per chain: the lib's declared
   Built channels must say exactly what the per-chain source flags say —
   so neither encoding can drift silently while both are live. *)
let flags_match_spec_pin ~prefix ~(spec : EN.project_spec)
    ~(dev_src : Canary_artifact_source.source_repo)
    ~(stable_src : Canary_artifact_source.source_repo) :
    Canary_project_test.pure_test =
  { name = prefix ^ ".build_flags_match_declared_provisions";
    check = (fun () ->
      let built = EN.ps_versions_of spec EN.a_lib EN.Built in
      let has ch = List.mem built ch ~equal:Poly.equal in
      Bool.equal dev_src.Canary_artifact_source.has_build_lib (has B.Dev)
      && Bool.equal stable_src.Canary_artifact_source.has_build_lib
           (has B.Stable)) }

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
      let spec = Canary_project_sqlite.sqlite_spec in
      let asgs = enumerate_full spec in
      let oc = EN.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs in
      let find c a =
        List.find (EN.runtime_pairings_of spec a) ~f:(fun p ->
            EN.equal_artifact_id p.EN.rp_consumer c)
      in
      List.length asgs = 3
      && List.for_all asgs ~f:(fun a ->
             (match find py_cext a with
              | Some p -> (
                  match p.EN.rp_mode with
                  | Canary_store.Ambient _ ->
                      Option.is_none p.EN.rp_run && not p.EN.rp_deploy
                  | _ -> false)
              | None -> false)
             && (match find oc a with
                 | Some p ->
                     Poly.equal p.EN.rp_run (EN.placement_of a EN.a_lib)
                 | None -> false))
      && List.count asgs ~f:(fun a ->
             match find oc a with Some p -> p.EN.rp_deploy | None -> false)
         = 2) }

let tests : Canary_project_test.pure_test list =
  z3_pins @ llvm_pins
  @ [ z3_lowering_derived; llvm_lowering_derived;
      flags_match_spec_pin ~prefix:"z3" ~spec:Canary_project_z3.z3_spec
        ~dev_src:Canary_project_z3.z3_source_dev
        ~stable_src:Canary_project_z3.z3_source_stable;
      flags_match_spec_pin ~prefix:"llvm" ~spec:Canary_project_llvm.llvm_spec
        ~dev_src:Canary_project_llvm.llvm_source_dev
        ~stable_src:Canary_project_llvm.llvm_source_stable;
      sqlite_runtime_edges_pin ]
