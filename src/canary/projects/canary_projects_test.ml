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

let tests : Canary_project_test.pure_test list = z3_pins @ llvm_pins
