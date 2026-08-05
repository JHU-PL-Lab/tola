open Base

(** Project-spec PIN tests (A5 phase 1) — pure, hermetic checks that a live
    project's DECLARED [project_spec] enumerates to exactly its expected
    scenario set. These reference the real project modules, so they live in
    [canary_projects] (canary_lib's test/ sits BELOW this sub-library);
    `canary project-test` appends them to the pure project-definition suite
    via [Canary_project_test.run_tests ~extra].

    First pin (A5 phase 1): [Canary_project_z3.z3_spec] == the current two
    hand-written z3 variants (dev / stable), BEFORE any runner change — so
    phase 2 (dispatch/realize + `action z3` → [run_project_run]) lands on a
    spec already proven to enumerate the same worlds the raw-script runner
    runs today. llvm's pin joins with A5 phase 5. *)

module B = Canary_basic
module EN = Canary_enumerate

let z3_py = EN.a_binding Canary_lang.Python Canary_mechanism.Cext

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

(* A5 phase 1: enumerate(z3_spec) == the current 2 variants.
   Product-then-filter yields THREE assignments — the source-primary filter
   prunes (source@Stable × lib Built@Dev), and the two all-Fetched
   assignments (source@{Stable,Dev} × lib Fetched) collapse under the
   ambient identity rule into ONE stable scenario — leaving exactly
   {dev chain, stable chain}, baseline (head) = the all-Fetched chain. *)
let z3_spec_pins_variants : Canary_project_test.pure_test =
  { name = "z3.spec_enumerates_current_variants";
    check = (fun () ->
      let asgs =
        EN.enumerate ~tag:(fun () -> "") ~policy:(EN.full_policy ())
          Canary_project_z3.z3_spec
      in
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
      let scenario_ids =
        List.dedup_and_sort ~compare:String.compare
          (List.map asgs ~f:ambient_key)
      in
      List.length asgs = 3
      && List.count asgs ~f:is_dev = 1
      && List.count asgs ~f:is_stable_world = 2
      (* the two all-Fetched assignments are ONE world: 2 scenario ids total *)
      && List.length scenario_ids = 2
      (* the Python wheel row is variant-invariant: Fetched everywhere *)
      && List.for_all asgs ~f:(fun a ->
             EN.equal_provision (EN.provision_of a z3_py) EN.Fetched)
      (* source-primary pruned the incoherent build: no Built lib over the
         stable source *)
      && (not
            (List.exists asgs ~f:(fun a ->
                 EN.equal_provision (lib_prov a) EN.Built
                 && EN.equal_version (EN.version_of a EN.a_source)
                      (EN.good B.Stable))))
      (* baseline (enumeration head) = the all-Fetched stable chain *)
      && match asgs with first :: _ -> is_stable_world first | [] -> false) }

let tests : Canary_project_test.pure_test list = [ z3_spec_pins_variants ]
