open Base

(** Project-spec PIN tests (A5 phases 1–5) — pure, hermetic checks that a
    live project's DECLARED [project_spec] enumerates to exactly its expected
    scenario set. These reference the real project modules, so they live in
    [canary_project] (canary_lib's test/ sits BELOW this library; src/canary/main is the framework ABOVE it);
    `canary project-test` appends them to the pure project-definition suite
    via [Canary_project_test.run_tests ~extra].

    z3 (phase 1–2) and llvm (phase 5) share ONE shape — the 3-way project
    (C2, 2026-08-16: source Repo_axes pins {stable, latest, arbipher-fork}
    × {stable fetch chain / dev build chain}) — so their pins are one
    parameterized generator ([two_chain_pins]): the spec enumerates to the
    current 5 scenarios (3 all-Fetched source worlds + 2 dev build chains),
    the dispatch reads the SOURCE placement's pinned repo id, and the
    provider table backs the baseline provisions. *)

module B = Canary_basic
module EN = Canary_enumerate

let py_cext = Canary_artifact.a_binding Canary_lang.Python Canary_mechanism.Cext
let py_ctypes =
  Canary_artifact.a_binding Canary_lang.Python Canary_mechanism.Ctypes

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

(* The three pins for a 3-way project (the z3/llvm shape, C2: source
   Fetched@pins {4.15.2/19, latest, arbipher}, lib Fetched@Stable |
   Built@Dev (| Installed@Dev where the project declares a staged face),
   python binding Fetched@Stable; the OCaml binding not enumerated — it
   follows the chain).
   [source_of] projects the project's own [source_for_assignment]
   dispatch; [dispatch_is_dev] is "does this world build from source" —
   the BUILT FAMILY (Built or Installed: an Installed world builds and
   then stages), which is exactly what [realize_from_rows] fires the
   build rows for. [n_staged] (2026-08-19) counts the Installed worlds;
   0 for a project without a staged face. *)
let two_chain_pins ~(prefix : string) ~(spec : Canary_artifact.project_spec)
    ~(artifacts : Canary_project_spec.artifact_row list)
    ~(source_of : Canary_artifact.assignment -> Canary_artifact_source.source_repo)
    ~(dispatch_is_dev : Canary_artifact.assignment -> bool)
    ?(n_worlds = 5) ?(n_dev = 2) ?(n_stable = 3) ?(n_staged = 0) () :
    Canary_project_test.pure_test list =
  let lib_prov a = Canary_enumerate.provision_of a Canary_artifact.a_lib in
  (* dev variant: the coherent build chain — source@Dev (ANY dev repo —
     latest or the fork), lib Built@Dev (C2: channel-level coupling) *)
  let is_dev a =
    EN.equal_provision (lib_prov a) EN.Built
    && Canary_basic.equal_channel
         (Canary_enumerate.version_of a Canary_artifact.a_lib).Canary_basic.channel
         Canary_basic.Dev
    && Canary_basic.equal_channel
         (Canary_enumerate.version_of a Canary_artifact.a_source).Canary_basic.channel
         Canary_basic.Dev
  in
  (* staged variant (2026-08-19): the same build chain, consumed through
     the install prefix — an Installed lib over a dev source *)
  let is_staged a =
    EN.equal_provision (lib_prov a) Canary_artifact.Installed
    && Canary_basic.equal_channel
         (Canary_enumerate.version_of a Canary_artifact.a_source).Canary_basic.channel
         Canary_basic.Dev
  in
  (* stable variant: the all-Fetched chain (per-repo source pins) *)
  let is_stable_world a =
    EN.equal_provision (lib_prov a) EN.Fetched
    && EN.equal_provision (Canary_enumerate.provision_of a Canary_artifact.a_source) EN.Fetched
  in
  [ (* enumerate(spec) == the repo family's world set (C2; the counts are
       PARAMETERS now — z3's 4th repo, the #10549 regression ref, makes
       seven: 4 all-Fetched worlds + 3 dev chains; llvm keeps five).
       Product-then-filter — the source-primary filter prunes
       (source@Stable × lib Built@Dev), the repo pins keep every
       all-Fetched source world identity-bearing (stable / latest / fork
       / pre-10549), and each dev repo pairs with the Built lib (channel
       coupling) — leaving exactly {n_stable all-Fetched worlds, n_dev dev
       chains}, baseline (head) = the stable all-Fetched chain. *)
    { Canary_project_test.name =
        prefix ^ ".spec_enumerates_current_variants";
      check = (fun () ->
        let asgs = enumerate_full spec in
        let scenario_ids =
          List.dedup_and_sort ~compare:String.compare
            (List.map asgs ~f:ambient_key)
        in
        List.length asgs = n_worlds
        && List.count asgs ~f:is_dev = n_dev
        && List.count asgs ~f:is_stable_world = n_stable
        && List.count asgs ~f:is_staged = n_staged
        (* the three buckets PARTITION the world set — a world that is
           neither an all-Fetched chain nor a build chain nor its staged
           face would slip past the counts otherwise *)
        && n_dev + n_stable + n_staged = n_worlds
        (* each repo pin is ONE identity-bearing world *)
        && List.length scenario_ids = n_worlds
        (* the python binding row is variant-invariant: Fetched everywhere *)
        && List.for_all asgs ~f:(fun a ->
               EN.equal_provision (Canary_enumerate.provision_of a py_ctypes) EN.Fetched)
        (* source-primary pruned the incoherent build: no Built lib over
           the stable source (channel coupling) *)
        && (not
              (List.exists asgs ~f:(fun a ->
                   EN.equal_provision (lib_prov a) EN.Built
                   && Canary_basic.equal_channel
                        (Canary_enumerate.version_of a Canary_artifact.a_source).Canary_basic.channel
                        Canary_basic.Stable)))
        (* baseline (enumeration head) = the all-Fetched stable chain *)
        && match asgs with x :: _ -> is_stable_world x | [] -> false) };
    (* the dispatch is pure data over enumeration coordinates — pin that
       the repo selection follows the SOURCE placement's pinned id (C2:
       the repo IS the scenario's identity — [source_of]), and that the
       source-BUILDING discriminator is the lib provision's built FAMILY
       (Built or Installed ⇒ the build rows fire; [realize_from_rows]
       gates them by exactly that, so a staged world builds like a built
       one and then stages). [realize] is deliberately NOT called
       (command templates shell into distro/PM detection). *)
    { name = prefix ^ ".dispatch_reads_source_placement";
      check = (fun () ->
        let asgs = enumerate_full spec in
        let cases = List.map asgs ~f:dispatch_is_dev in
        List.count cases ~f:Fn.id = n_dev + n_staged
        && List.count cases ~f:not = n_stable
        && List.for_all2_exn asgs cases ~f:(fun a dev ->
               Bool.equal dev
                 (EN.equal_provision (lib_prov a) EN.Built
                 || EN.equal_provision (lib_prov a) Canary_artifact.Installed))
        && List.for_all asgs ~f:(fun a ->
               String.equal
                 (source_of a).Canary_artifact_source.version.Canary_basic.id
                 (Canary_enumerate.version_of a Canary_artifact.a_source)
                   .Canary_basic.id)) };
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

let built_family a =
  let pv = Canary_enumerate.provision_of a Canary_artifact.a_lib in
  Canary_enumerate.equal_provision pv Canary_artifact.Built
  || Canary_enumerate.equal_provision pv Canary_artifact.Installed

let z3_pins : Canary_project_test.pure_test list =
  (* SEVEN worlds (2026-08-19): ONE all-Fetched chain (the stable repo —
     the source follows the lib's channel) + each of the 3 dev repos
     twice, build-tree and staged (latest / fork / pre-10549). Before the
     Installed axis it was 4 all-Fetched + 3 dev chains, where 3 of those
     fetched worlds were the same world under different source refs. *)
  two_chain_pins ~prefix:"z3" ~spec:(Canary_project_spec.project_spec_of_rows Canary_project_z3.z3_artifacts)
    ~artifacts:Canary_project_z3.z3_artifacts
    ~source_of:Canary_project_z3.z3_source_for_assignment
    ~dispatch_is_dev:built_family
    ~n_worlds:7 ~n_dev:3 ~n_stable:1 ~n_staged:3 ()

let llvm_pins : Canary_project_test.pure_test list =
  two_chain_pins ~prefix:"llvm" ~spec:(Canary_project_spec.project_spec_of_rows Canary_project_llvm.llvm_artifacts)
    ~artifacts:Canary_project_llvm.llvm_artifacts
    ~source_of:Canary_project_llvm.llvm_source_for_assignment
    ~dispatch_is_dev:built_family ()

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
      (* 5 since the Installed worlds (2026-08-18): 2 built + 2
         installed + 1 fetched *)
      List.length asgs = 5
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
         = 4) }

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
              (* the Repo arrow reads the AXES' provision (the
                 unification): take the row's first declared provision —
                 the live Repo rows are Fetched-only sources. *)
              let provision =
                match d.Canary_project_spec.ar_axes.Canary_artifact.ax_universe with
                | (pv, _) :: _ -> pv
                | [] -> Canary_artifact.Fetched
              in
              let act =
                Canary_store_config.providing_action_of ~provision
                  k p
              in
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
              (* Installed never arrives here: providers construct
                 Fetched/Built only — projects declare Installed
                 directly in the universe (the round-trip below) *)
              | _ -> false))
      (* and the Fetched half of the round-trip on a concrete row *)
      && Poly.equal
           (Canary_enumerate.provision_of_actions [ B.Fetch B.Lib ] Canary_artifact.a_lib)
           EN.Fetched
      (* the Installed half (2026-08-18): the single-action round-trip
         [Install_lib] reads Installed — the maker step of the staged
         lib *)
      && Poly.equal
           (Canary_enumerate.provision_of_actions
              [ B.Install_lib ] Canary_artifact.a_lib)
           EN.Installed
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
      (* 5 since the Installed worlds (2026-08-18): fetched + 2 built
         + 2 installed *)
      let ok1 = check ~name:"sqlite" ~want_count:5
          Canary_project_sqlite.sqlite_run in
      (* C2: 5 = 3 all-Fetched source worlds + 2 dev build chains;
         7 since the pre-10549 regression ref (4 all-Fetched + 3 dev) *)
      let ok2 = check ~name:"z3" ~want_count:7
          (Canary_project_z3.z3_run (Canary_basic.detect_distro ())) in
      let ok3 = check ~name:"llvm" ~want_count:5
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
      (* the repo-axes axis (C1): zarith's per-channel SOURCE repos
         enumerate 2 scenarios — one per repo's pinned version, channel
         preserved (the thin policy drops the dev one). *)
      let zarith_axes_ok =
        match List.Assoc.find entries "zarith" ~equal:String.equal with
        | None -> false
        | Some pr ->
            let asgs = Canary_project_run.scenarios_of pr in
            let src (a : Canary_artifact.assignment) =
              Canary_enumerate.version_of a Canary_artifact.a_source
            in
            (* C2.5 (2026-08-17): the prebuilt-shadows-source shape —
               3 scenarios (see repo_model.axes_pins) *)
            List.length asgs = 3
            && List.for_all asgs ~f:(fun a -> not (String.equal (src a).Canary_basic.id ""))
            && Poly.equal
                 (List.dedup_and_sort
                    (List.map asgs ~f:(fun a ->
                         Printf.sprintf "%s:%s"
                           (Canary_basic.string_of_channel (src a).Canary_basic.channel)
                           (src a).Canary_basic.id))
                    ~compare:String.compare)
                 [ "dev:master"; "stable:1.14" ]
      in
      names_ok && projects_ok && ssl_pins_ok && zarith_axes_ok) }

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
          pr_runner_spec = (fun _a ~workspace:_ () ->
            { SB.empty_runner_spec with
              SB.expectation = Canary_project_tiny.expectation_agnostic });
          pr_mismatch_probes = [];
          pr_wrapper_pkgs = [];
          pr_api_source = None;
          pr_binding_decls = [];
    pr_raw_build_overrides = []; pr_tier = Canary_project_run.Light }
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
            let spec =
              pr.Canary_project_run.pr_runner_spec a ~workspace:"/tmp" ()
            in
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
        Poly.equal d.c_api.functions TS.tiny_native_stable_symbols
      in
      let native_matches (d : BD.binding_decl) =
        String.equal d.native.prefix "tiny_"
        && String.equal d.native.soname "libtiny.so.1"
        && Poly.equal d.native.headers.files [ "tiny.h" ]
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
          && (* cstubs: the stub archive the hand-written build produces
                (the build HOW is a separate stage — recipe_of_decl,
                pinned by tiny_binding_realization_pin) *)
          (match cstubs.BD.coupling with
           | BD.Stub_archive sa ->
               Poly.equal sa.sources [ "ocaml/tiny_stubs.c" ]
               && String.equal sa.archive "ocaml/libtiny_stubs.a"
           | _ -> false)
          && (* cext: the .so the hand-written cc produces *)
          (match cext.BD.coupling with
           | BD.Compiled_ext ce ->
               String.equal ce.source "python_cext/tiny_cext/_native.c"
               && String.equal ce.product "_native.cpython-*.so"
           | _ -> false)
          && (* ctypes: dlopen by the soname the loader resolves *)
          (match ctypes.BD.coupling with
           | BD.Dlopen { name } -> String.equal name "libtiny.so.1"
           | _ -> false)
          && (* surface paths match the mli / py files the inspectors read *)
          String.equal cstubs.BD.surface_path "ocaml/tiny.mli"
          && String.equal cext.BD.surface_path
               "python_cext/tiny_cext/__init__.py"
          && String.equal ctypes.BD.surface_path
               "python_ctypes/tiny_ctypes/__init__.py"
      | _ -> false) }

(* M2 step 4 step 3 pin (2026-08-15): the binding realization
   ([Canary_binding_templates]) emits the EXACT command strings the
   former hand-written [make_base_runner_spec] literals produced —
   captured with synthetic stores (source=/WS, lib=/WS/c/build, cext
   root=/WS/python_cext) from the pre-realization spec. When the
   realization changes, this pin fails and the diff IS the behavior
   change. *)
let tiny_binding_realization_pin : Canary_project_test.pure_test =
  { name = "tiny1.binding_realization_matches_handwritten";
    check = (fun () ->
      let module BT = Canary_binding_templates in
      let module TS = Canary_tiny_scenario in
      let decl_of mech =
        List.find TS.tiny_binding_decls
          ~f:(fun (d : Canary_binding_decl.binding_decl) ->
            Poly.equal d.mechanism mech)
        |> Option.value_exn
      in
      let cstubs = decl_of Canary_mechanism.Cstubs in
      let cext = decl_of Canary_mechanism.Cext in
      let ctypes = decl_of Canary_mechanism.Ctypes in
      let ctx : BT.ctx =
        { lib_dir = "$PWD//WS/c/build";
          (* caller-anchored, as make_base_runner_spec passes it *)
          lib_path = "/WS/c/build/libtiny.so.1";
          source_root = "/WS";
          binding_root = "/WS/python_cext";
          probe_exe = "ocaml/examples/probe_baseline.exe";
          probe_script = "examples/probe_baseline.py" }
      in
      let str = function
        | Some cmd -> Some (cmd ~output_dir:"/OUT" ~variant_key:"VK")
        | None -> None
      in
      List.for_all
        [ (* build_binding: dune the declared targets / verify the cext *)
          ( str (BT.build_binding_of cstubs ~ctx),
            Some "(LIBRARY_PATH=$PWD//WS/c/build LD_RUN_PATH=$PWD//WS/c/build dune build --root /WS ocaml/tiny.cmxa ocaml/libtiny_stubs.a) > /OUT/build_VK.log 2>&1 && echo 'ok' > /OUT/build_VK.ok" );
          ( str (BT.build_binding_of cext ~ctx),
            Some "ls /WS/python_cext/tiny_cext/_native.cpython-*.so > /dev/null && echo 'ok' > /OUT/build_VK.ok" );
          (* probe_binding: dune build+exec / cext runtime probe *)
          ( str (BT.probe_binding_of cstubs ~ctx),
            Some "(LIBRARY_PATH=$PWD//WS/c/build LD_RUN_PATH=$PWD//WS/c/build dune build --root /WS ocaml/examples/probe_baseline.exe && LD_LIBRARY_PATH=$PWD//WS/c/build /WS/_build/default/ocaml/examples/probe_baseline.exe) > /OUT/probe_VK.log 2>&1" );
          ( str (BT.probe_binding_of cext ~ctx),
            Some "LD_LIBRARY_PATH=$PWD//WS/c/build PYTHONPATH=/WS/python_cext python3 /WS/python_cext/examples/probe_baseline.py > /OUT/probe_VK.log 2>&1" );
          (* probe_lib: nm for the declared prefix *)
          ( Some
              (BT.probe_lib_of TS.tiny_native
                 ~lib_path:"/WS/c/build/libtiny.so.1"
                 ~output_dir:"/OUT" ~variant_key:"VK"),
            Some "nm -D /WS/c/build/libtiny.so.1 | grep -E '^[0-9a-f]+ T tiny_' > /OUT/probe_VK.log 2>&1" );
          (* user-facing pkg names derive from the surface path *)
          (BT.user_facing_pkg_of Canary_lang.OCaml cstubs, Some "tiny");
          (BT.user_facing_pkg_of Canary_lang.Python cext, Some "tiny_cext");
          (BT.user_facing_pkg_of Canary_lang.Python ctypes,
           Some "tiny_ctypes");
          (* Dlopen has no compile stage and is not wired in the base
             spec — the Cext entry serves both Python artifacts. *)
          (BT.build_binding_of ctypes ~ctx |> Option.map ~f:(fun _ -> ""),
           None);
          (BT.probe_binding_of ctypes ~ctx |> Option.map ~f:(fun _ -> ""),
           None);
        ]
        ~f:(fun (got, want) -> Poly.equal got want)) }

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
            && List.length r.items = 10
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
    [ "binding_decls"; "binding_dev_source"; "dev_wrapper_package";
      "python_binding" ]
  in
  { name = "spec_check.ratchet_current";
    check =
      (fun () ->
        want ~errs:[] ~warns:[ "raw_build_overrides" ] ~na:[] "z3"
        && want ~errs:[]
             ~warns:[ "dev_wrapper_package"; "raw_build_overrides" ]
             ~na:[] "llvm"
        && want ~errs:[]
             ~warns:[ "binding_dev_source"; "dev_wrapper_package" ]
             ~na:[ "raw_build_overrides" ] "sqlite"
        && want ~errs:[] ~warns:pat_warns ~na:[ "raw_build_overrides" ] "ssl"
        (* C2.5 (2026-08-17): zarith's binding Built axis LANDED with the
           2×2 — binding_dev_source went Ok *)
        (* active plan 2 (2026-08-17): the wrapper declaration closed the
           dev_wrapper_package gap *)
        (* active plan 4 (2026-08-17): the binding decl (empty-prefix +
           full watchlist) closed binding_decls — python_binding stays
           (OCaml-only project, expected) *)
        && want ~errs:[] ~warns:[ "python_binding" ] ~na:[] "zarith"
        && want ~errs:[] ~warns:pat_warns ~na:[ "raw_build_overrides" ] "cairo"
        && want ~errs:[] ~warns:pat_warns ~na:[ "raw_build_overrides" ] "libffi"
        && want ~errs:[]
             ~warns:[ "binding_dev_source"; "dev_wrapper_package" ]
             ~na:[ "github_remote"; "opam_package";
               "raw_build_overrides" ] "tiny-full") }

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

(* The run-policy ladder's enumeration mapping (2026-08-17, active plan
   3): Full → the enumeration default (Shadow_prebuilt), Thin → the
   Subset[Stable] enumeration (also shadowing), Audit_lib → the full
   enumeration with Materialize_source — the shadowed source-built
   placements materialize (the blame-driven audit pass). The ladder
   changes SHADOWING ONLY on the audit rung: thin is a version subset,
   not a shadow override. *)
let shadow_policy_ladder_pin : Canary_project_test.pure_test =
  { name = "shadow.policy_ladder";
    check =
      (fun () ->
        let module EN = Canary_enumerate in
        let ep p =
          Canary_project_run.enumeration_policy_of
            { Canary_project_run.policy = p; refs = EN.All_refs }
        in
        let shadow_of = function
          | None -> None
          | Some (p : unit EN.policy) -> Some p.EN.config.EN.shadow
        in
        let full_like (p : unit EN.policy option) =
          match p with
          | None -> false
          | Some p ->
              Poly.equal p.EN.config.EN.provision EN.Full
              && Poly.equal p.EN.config.EN.version EN.Full
              && Poly.equal p.EN.config.EN.mutation EN.Free
              && Poly.equal p.EN.config.EN.version_mode EN.Lockstep
        in
        Poly.equal (shadow_of (ep Canary_project_run.Full)) None
        && (match ep Canary_project_run.Thin with
            | None -> false
            | Some (p : unit EN.policy) ->
                Poly.equal p.EN.config.EN.version
                  (EN.Subset [ Canary_basic.Stable ])
                && Poly.equal p.EN.config.EN.shadow EN.Shadow_prebuilt)
        && (match ep Canary_project_run.Audit_lib with
            | None -> false
            | Some (p : unit EN.policy) ->
                full_like (Some p)
                && Poly.equal p.EN.config.EN.shadow EN.Materialize_source)) }

(* The repo-model settings (2026-08-15, design/repo_model.md): the
   contrib-root derivation + the worktree naming scheme (official repo
   name + ref slug; path separators slugged away). *)
let repo_model_pin : Canary_project_test.pure_test =
  { name = "repo_model.worktree_paths";
    check =
      (fun () ->
        let repo : Canary_artifact_source.source_repo =
          { name = "Zarith";
            remote = Some (Git
                "https://github.com/ocaml/Zarith.git");
            locals = [];
            version = Canary_basic.{ channel = Canary_basic.Stable; id = "1.14" };
            ref_ = "release-1.14";
            official = true;
            build_sys_deps = [];
            api_source = None;
            label = None;
            artifacts = [ Canary_artifact.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs ] }
        in
        let main =
          Canary_artifact_source.repo_main_path ~project:"zarith" ~repo
            Canary_store.Wsl
        in
        let wt =
          Canary_artifact_source.repo_worktree_path ~project:"zarith" ~repo
            ~ref_:"release-1.14" Canary_store.Wsl
        in
        String.is_suffix main ~suffix:"/contrib/zarith-all/Zarith"
        && String.equal wt (main ^ "-release-1.14")
        && String.equal
             (Canary_artifact_source.repo_worktree_path ~project:"zarith"
                ~repo ~ref_:"fix/bug-42" Canary_store.Wsl)
             (main ^ "-fix-bug-42")) }

(* The fork rule (2026-08-15, user): a LOCAL-ONLY fork (a label, no
   remote) is a WARNING, not an error — a per-project remote on the
   personal account is not required; we may not find a bug worth
   pushing. An official repo without a remote stays an error (the
   archive/PM-source distribution case — later refinement). *)
let local_fork_pin : Canary_project_test.pure_test =
  { name = "spec_check.local_fork_warns";
    check =
      (fun () ->
        let repo : Canary_artifact_source.source_repo =
          { name = "zarith";
            remote = None;
            locals = [];
            version = Canary_basic.{ channel = Canary_basic.Dev; id = "" };
            ref_ = "canary-fix";
            official = false;
            build_sys_deps = [];
            api_source = None;
            label = Some "local-fork";
            artifacts = [ Canary_artifact.a_lib ] }
        in
        let pr : Canary_project_run.project_run =
          { pr_name = "test-fork";
            pr_artifacts =
              [ Canary_project_spec.artifact_row ~artifact:Canary_artifact.a_source
                  ~universe:[ (Canary_artifact.Fetched, [ Canary_basic.Dev ]) ]
                  ~provider:(Canary_store_config.Repo repo) () ];
            pr_runner_spec =
              (fun _a ~workspace:_ () ->
                Canary_step_builder.empty_runner_spec);
            pr_mismatch_probes = [];
            pr_wrapper_pkgs = [];
            pr_api_source = None;
            pr_binding_decls = [];
    pr_raw_build_overrides = []; pr_tier = Canary_project_run.Light }
        in
        let r = Canary_spec_check.check pr in
        match
          List.find r.Canary_spec_check.items
            ~f:(fun i -> String.equal i.Canary_spec_check.item_id "github_remote")
        with
        | Some i -> Poly.equal i.Canary_spec_check.severity Canary_spec_check.Warn
        | None -> false) }

(* The repo-contents invariant over the LIVE registry (2026-08-16): every
   non-source artifact with a [Repo] provider must appear in that repo's
   [artifacts] contents (the multi-repo principle — repo → artifacts). *)
let repo_contents_pin : Canary_project_test.pure_test =
  { name = "repo_model.contents_invariant";
    check =
      (fun () ->
        List.for_all Canary_registry.all_projects ~f:(fun (n, pr) ->
            let vs = Canary_spec_check.repo_contents_violations pr in
            if not (List.is_empty vs) then
              Fmt.pr "repo_model.contents_invariant: %s violates %s@." n
                (String.concat ~sep:", "
                   (List.map vs ~f:(fun (a, r) -> a ^ " not in " ^ r)));
            List.is_empty vs)) }

(* The repo-axes axis (C1, 2026-08-16): a [Repo_axes] family's repos
   project into the source row's store pins — per-channel, identity-
   bearing placements, one scenario per repo, and the realization
   dispatches each scenario's fetch to ITS repo (the worktree ref
   appears in the emitted command). A single-repo family (cairo)
   becomes identity-bearing too — its worktree IS pinned to that ref. *)
let repo_axes_pin : Canary_project_test.pure_test =
  { name = "repo_model.axes_pins";
    check =
      (fun () ->
        let source_version a =
          Canary_enumerate.version_of a Canary_artifact.a_source
        in
        let zarith_asgs = Canary_project_run.scenarios_of Canary_project_zarith.zarith_run in
        let zarith_ok =
          (* C2.5 (2026-08-17, the prebuilt-shadows-source shape): 3
             scenarios — the current cell {1.14, F lib, F bind}, the
             master-source world, and the FORWARD cell {master, F lib,
             B bind} (the Built binding builds from the master worktree
             against the system lib — the designed mismatch probe). The
             lib axis stays Fetched-only: no source-built GMP column
             (the feedback rule). The Built-binding↔source channel
             coupling pruned the incoherent {1.14 source, B bind} cell. *)
          List.length zarith_asgs = 3
          && List.for_all zarith_asgs ~f:(fun a ->
                 not (String.equal (source_version a).Canary_basic.id ""))
          && List.length
               (List.dedup_and_sort
                  (List.map zarith_asgs ~f:(fun a ->
                       Canary_project_run.scenario_dir_of ~pr_name:"zarith" a))
                  ~compare:String.compare)
               = 3
        in
        (* the realize ∘ dispatch: each scenario's fetch_source command
           materializes ITS repo's worktree ref *)
        let fetch_cmd_of a =
          let spec =
            Canary_project_zarith.zarith_run.Canary_project_run.pr_runner_spec
              a ~workspace:"/tmp/c1" ()
          in
          match spec.Canary_step_builder.fetch_source with
          | Some f -> f ~output_dir:"/tmp/c1" ~variant_key:"c1"
          | None -> ""
        in
        let cmds_ok =
          List.for_all zarith_asgs ~f:(fun a ->
              let expect =
                match (source_version a).Canary_basic.channel with
                | Canary_basic.Stable -> "release-1.14"
                | Canary_basic.Dev -> "master"
              in
              String.is_substring (fetch_cmd_of a) ~substring:expect)
        in
        let cairo_ok =
          match Canary_project_run.scenarios_of Canary_project_cairo.cairo_run with
          | [ a ] ->
              String.equal (source_version a).Canary_basic.id "1.18.0"
          | _ -> false
        in
        zarith_ok && cmds_ok && cairo_ok) }

(* Active plan 1 (2026-08-17): the FORWARD cell's probe carries the c1
   compat-derived expectation — a future master×system-lib break must be
   a PREDICTED finding, not a raw FAIL. The other cells keep
   Expect_success. Pure — the realization builds closures only. *)
let forward_cell_expectation_pin : Canary_project_test.pure_test =
  { name = "repo_model.forward_cell_expectation";
    check =
      (fun () ->
        let module SM = Canary_step_model in
        let pr = Canary_project_zarith.zarith_run in
        let bind_art =
          Canary_artifact.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs
        in
        (* the c1 inputs must resolve to the build_binding step's OWN dir
           (the lang-tagged tag maps to build_binding/ocaml — the step
           writes its summary there). The lang-LESS tag would resolve to
           build_binding/ (a dir nothing writes) and the c1 would silently
           never pair — the 2026-08-17 finding (the forward cell's "no
           contract fired" was really "no inputs found"). *)
        let binding_tag =
          Canary_basic.string_of_action
            (Canary_basic.Build_binding Canary_lang.OCaml)
        in
        let inputs_resolve_to_step_dir =
          String.equal
            (Canary_basic.step_dir_of_tag binding_tag)
            "build_binding/ocaml"
          && (match Canary_compat_run.inputs_of_contract Canary_compat.C1 Canary_lang.OCaml with
              | [ Canary_compat.C_stub [ stub_rel ];
                  Canary_compat.Native_lib [ lib_rel ] ] ->
                  String.is_prefix stub_rel ~prefix:(binding_tag ^ "/")
                  && String.equal lib_rel "build_lib/inspect.json"
              | _ -> false)
        in
        inputs_resolve_to_step_dir
        && List.for_all (Canary_project_run.scenarios_of pr) ~f:(fun a ->
            let spec =
              pr.Canary_project_run.pr_runner_spec a ~workspace:"/tmp/fwd" ()
            in
            let bind_built =
              Canary_enumerate.equal_provision
                (Canary_enumerate.provision_of a bind_art)
                Canary_artifact.Built
            in
            match
              spec.Canary_step_builder.expectation
                (Canary_basic.Probe_binding Canary_lang.OCaml)
                (Some Canary_store.Build_tree)
            with
            | SM.Expect_compat_derived _ -> bind_built
            | _ -> not bind_built)) }

(* Active plan 2 (2026-08-17): the wrapper Publish is wired on the
   bind_built scenarios only — a pack_binding OCaml entry + the
   pin-checked postcondition on Publish; the other cells carry none.
   And the opam-template renderer reproduces the committed
   zarith-no-conf file byte-equal (the M2 byte-equal discipline —
   the committed repo file is the renderer's output). *)
let publish_wired_pin : Canary_project_test.pure_test =
  { name = "repo_model.publish_wired";
    check =
      (fun () ->
        let pr = Canary_project_zarith.zarith_run in
        let bind_art =
          Canary_artifact.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs
        in
        List.for_all (Canary_project_run.scenarios_of pr) ~f:(fun a ->
            let spec =
              pr.Canary_project_run.pr_runner_spec a ~workspace:"/tmp/pub" ()
            in
            let bind_built =
              Canary_enumerate.equal_provision
                (Canary_enumerate.provision_of a bind_art)
                Canary_artifact.Built
            in
            let has_pack =
              List.exists spec.Canary_step_builder.pack_binding
                ~f:(fun (l, _) -> Poly.equal l Canary_lang.OCaml)
            in
            let pin_checked =
              Option.is_some
                (spec.Canary_step_builder.check_post
                   (Canary_basic.Publish (Canary_basic.Binding Canary_lang.OCaml)))
            in
            Bool.equal has_pack bind_built && Bool.equal pin_checked bind_built)) }

let opam_template_render_pin : Canary_project_test.pure_test =
  { name = "tool.opam_template_render";
    check =
      (fun () ->
        let committed =
          Stdlib.In_channel.with_open_text
            "canary/templates/opam-local-repo/packages/zarith/zarith-no-conf.dev/opam.in"
            Stdlib.In_channel.input_all
        in
        String.equal
          (Canary_opam_template.render Canary_project_zarith.zarith_wrapper_decl)
          committed) }

(* M2 step 4 pin (2026-08-16): the binding declarations ride on the
   [project_run] — tiny's spec exposes its three decls and the lookup
   matches by the artifact's mechanism (the decl's identity label).
   Non-binding artifacts look up to [None]. *)
let binding_decls_on_project_run_pin : Canary_project_test.pure_test =
  { name = "tiny1.binding_decls_on_project_run";
    check =
      (fun () ->
        let module PR = Canary_project_run in
        let pr = Canary_project_tiny.tiny_full_run in
        let find mech =
          PR.binding_decl_of pr
            (Canary_artifact.a_binding Canary_lang.OCaml mech)
        in
        (match find Canary_mechanism.Cstubs with
        | Some d ->
            Poly.equal d.c_api.functions
              Canary_tiny_scenario.tiny_native_stable_symbols
            && String.equal d.surface_path "ocaml/tiny.mli"
        | None -> false)
        && (match find Canary_mechanism.Cext with
           | Some d ->
               String.equal d.surface_path
                 "python_cext/tiny_cext/__init__.py"
           | None -> false)
        && (match find Canary_mechanism.Ctypes with
           | Some d ->
               String.equal d.surface_path
                 "python_ctypes/tiny_ctypes/__init__.py"
           | None -> false)
        && Option.is_none (PR.binding_decl_of pr Canary_artifact.a_lib)
        && Option.is_none (PR.binding_decl_of pr Canary_artifact.a_source)
        && List.length pr.pr_binding_decls = 3) }

(* M2 step 4 pin (2026-08-16): sqlite's decls mirror its declared spec —
   mechanisms match the artifact table, native prefix/headers match
   [sqlite_api_source], c_api = the declared stable-symbol subset, and
   the run exposes them. *)
let sqlite_binding_decls_pin : Canary_project_test.pure_test =
  { name = "sqlite.binding_decls_match_declared";
    check =
      (fun () ->
        let pr = Canary_project_sqlite.sqlite_run in
        let d_of mech =
          Canary_project_run.binding_decl_of pr
            (Canary_artifact.a_binding Canary_lang.OCaml mech)
        in
        match (d_of Canary_mechanism.Cstubs, d_of Canary_mechanism.Cext) with
        | Some cstubs, Some cext ->
            let native_matches (d : Canary_binding_decl.binding_decl) =
              String.equal d.native.prefix "sqlite3_"
              && String.equal d.native.soname "libsqlite3.so.0"
              && Poly.equal d.native.headers.files [ "sqlite3.h" ]
              && Poly.equal d.c_api.functions
                   Canary_project_sqlite.sqlite_native_modern_watchlist
            in
            native_matches cstubs && native_matches cext
            && (match cstubs.coupling with
               | Canary_binding_decl.Stub_archive sa ->
                   String.equal sa.archive "libsqlite3_stubs.a"
               | _ -> false)
            && (match cext.coupling with
               | Canary_binding_decl.Compiled_ext ce ->
                   String.equal ce.product "_sqlite3*.so"
               | _ -> false)
            && String.equal cstubs.surface_path "sqlite3.mli"
        | _ -> false) }

(* M2 step 4 pin (2026-08-17): zarith's decl wraps the system GMP with
   the EMPTY-prefix convention (multi-prefix API — mpz_/mpq_/mpf_/mpn_;
   the FULL stub-required watchlist is the scoping, not an nm prefix),
   and the c_api = the complete stub-required surface (the 42 the built
   binding's inspect reports), not a representative subset. *)
let zarith_binding_decls_pin : Canary_project_test.pure_test =
  { name = "zarith.binding_decls_match_declared";
    check =
      (fun () ->
        let pr = Canary_project_zarith.zarith_run in
        match
          Canary_project_run.binding_decl_of pr
            (Canary_artifact.a_binding Canary_lang.OCaml
               Canary_mechanism.Cstubs)
        with
        | Some d ->
            String.equal d.Canary_binding_decl.native.prefix ""
            && String.equal d.native.soname "libgmp.so.10"
            && Poly.equal d.native.headers.files [ "gmp.h" ]
            && Poly.equal d.c_api.functions
                 Canary_project_zarith.zarith_native_watchlist
            && List.length d.c_api.functions = 42
            && (match d.coupling with
               | Canary_binding_decl.Stub_archive sa ->
                   Poly.equal sa.sources [ "caml_z.c" ]
                   && String.equal sa.archive "libzarith.a"
               | _ -> false)
            && String.equal d.surface_path "zarith.mli"
        | None -> false) }

(* The #10549 regression (2026-08-17): at the pre-fix ref the install
   CANNOT stage the OCaml package (the install rules never existed) —
   the Install_lib step carries a DECLARED expected failure (the
   historical-bug shape: Expect_failure + the "OCAML INSTALL MISSING"
   signature + version_info naming the fix). Every other ref expects
   the install to succeed. *)
let z3_regression_pre_10549_pin : Canary_project_test.pure_test =
  { name = "z3.regression_pre_10549_expectation";
    check =
      (fun () ->
        let module SM = Canary_step_model in
        let pr = Canary_project_z3.z3_run (Canary_basic.detect_distro ()) in
        List.for_all (Canary_project_run.scenarios_of pr) ~f:(fun a ->
            let spec =
              pr.Canary_project_run.pr_runner_spec a ~workspace:"/tmp/reg" ()
            in
            let exp =
              spec.Canary_step_builder.expectation
                Canary_basic.Install_lib None
            in
            let src_id =
              (Canary_enumerate.version_of a Canary_artifact.a_source)
                .Canary_basic.id
            in
            if String.equal src_id "pre-10549" then
              match exp with
              | SM.Expect_failure { contains_any; version_info } ->
                  List.mem contains_any "OCAML INSTALL MISSING"
                    ~equal:String.equal
                  && (match version_info with
                      | Some vi ->
                          String.is_substring vi.SM.provider_version
                            ~substring:"pre-10549"
                          && Option.is_some vi.SM.since
                      | None -> false)
              | _ -> false
            else Poly.equal exp SM.Expect_success)
        &&
        (* the installed-consumer half (2026-08-18; keyed on the WORLD
           since 2026-08-19): the staged-prefix failure is declared in
           exactly the INSTALLED world of the pre-fix ref — the Built
           world's probe stays agnostic (it passes; the build tree has the
           package) and so does every fetched world. The old form toggled
           the [--installed] policy on one scenario; now the two faces
           ARE two scenarios, so the pin quantifies over the enumeration
           and no policy argument exists to pass. *)
        let probe_exp a =
          let spec =
            pr.Canary_project_run.pr_runner_spec a ~workspace:"/tmp/reg" ()
          in
          spec.Canary_step_builder.expectation
            (Canary_basic.Probe_binding Canary_lang.OCaml) None
        in
        let scenarios = Canary_project_run.scenarios_of pr in
        let declared_signature e =
          match e with
          | SM.Expect_failure { contains_any; _ } ->
              List.mem contains_any "STAGED PACKAGE MISSING"
                ~equal:String.equal
          | _ -> false
        in
        let is_staged_world a =
          String.equal
            (Canary_enumerate.version_of a Canary_artifact.a_source)
              .Canary_basic.id "pre-10549"
          && Canary_enumerate.equal_provision
               (Canary_enumerate.provision_of a Canary_artifact.a_lib)
               Canary_artifact.Installed
        in
        (* the world must EXIST — otherwise the implication below is
           vacuously true and the pin would pass on a lost scenario *)
        List.exists scenarios ~f:is_staged_world
        && List.for_all scenarios ~f:(fun a ->
               Bool.equal (declared_signature (probe_exp a))
                 (is_staged_world a))) }

(* ISOLATION of the staging area (2026-08-19, the live finding): no two
   of z3's declared repos may stage into the same install prefix. They
   used to — arbipher builds in `z3-all/build`, pre-10549 in
   `z3-all/build-pre-10549`, and the prefix was each build tree's SIBLING
   `z3-all/install`. Harmless while install was a build-world side
   effect; load-bearing once the staged consumer became a world, because
   the fork's staged OCaml package would satisfy the pre-10549 world's
   staged probe and the #10549 xfail would silently stop firing. Read off
   the ROW DATA (the [Cmake_install] template's own prefix field), not a
   parsed command. *)
let z3_install_prefix_isolated_pin : Canary_project_test.pure_test =
  { name = "z3.install_prefix_isolated";
    check =
      (fun () ->
        let module AT = Canary_action_templates in
        let distro = Canary_basic.detect_distro () in
        (* Compare RESOLVED paths: the property is about directories, not
           spellings. The bug this pin guards spelled two prefixes
           differently (`z3-all/z3/../build/../install` vs
           `z3-all/z3-pre-10549/../build-pre-10549/../install`) while
           naming ONE directory, so a string comparison would have called
           them isolated and the pin would have been decorative. Collapse
           `..` segments first. *)
        let normalize p =
          String.split p ~on:'/'
          |> List.fold ~init:[] ~f:(fun acc seg ->
                 match (seg, acc) with
                 | "", _ :: _ -> acc (* keep a leading "" = the root *)
                 | ".", _ -> acc
                 | "..", _ :: rest -> rest
                 | _ -> seg :: acc)
          |> List.rev |> String.concat ~sep:"/"
        in
        let prefix_of (repo : Canary_artifact_source.source_repo) =
          List.find_map
            (Canary_project_z3.z3_table_rows ~source:repo ~distro
               ~lib_prov:Canary_artifact.Installed)
            ~f:(fun (row : AT.action_row) ->
              match (row.AT.ar_action, row.AT.ar_template) with
              | Canary_basic.Install_lib, AT.Cmake_install { prefix; _ } ->
                  Some prefix
              | _ -> None)
        in
        let repos =
          [ Canary_project_z3.z3_source_latest;
            Canary_project_z3.z3_source_dev;
            Canary_project_z3.z3_source_pre_10549 ]
        in
        let prefixes = List.filter_map repos ~f:prefix_of |> List.map ~f:normalize in
        List.length prefixes = List.length repos
        && List.length
             (List.dedup_and_sort prefixes ~compare:String.compare)
           = List.length repos
        (* and each is NAMED after its ref (`install-<id>`, the user's
           2026-08-19 scheme) — the property that makes isolation FOLLOW
           from ref ids being unique, instead of holding by accident of
           where the build tree happens to sit. Checked on the resolved
           basename, so a `..`-spelled sibling can't sneak past. *)
        && List.for_all repos ~f:(fun repo ->
               match prefix_of repo with
               | Some prefix ->
                   String.equal
                     (Stdlib.Filename.basename (normalize prefix))
                     ("install-"
                     ^ repo.Canary_artifact_source.version.Canary_basic.id)
               | None -> false)
        (* the build dirs carry the same per-ref naming — an install dir
           beside a SHARED build dir would still be two worlds writing one
           tree (the build half of the same hazard) *)
        && List.length
             (List.dedup_and_sort ~compare:String.compare
                (List.filter_map repos ~f:(fun repo ->
                     Option.map
                       (Canary_artifact_source.local_for distro repo)
                       ~f:(fun l ->
                         normalize l.Canary_artifact_source.build_path))))
           = List.length
               (List.filter_map repos ~f:(fun repo ->
                    Canary_artifact_source.local_for distro repo))) }

(* z3's REALIZATION check (2026-08-18 as a policy pin; re-keyed to the
   enumerated world 2026-08-19) — the half {!provider_rows_pin} can't
   derive, the sqlite.staged_probe_paths analogue: the Installed world's
   OCaml probe consumes the STAGED package (<prefix>/lib/ocaml/z3 +
   <prefix>/lib/libz3.so, with the STAGED-PACKAGE-MISSING guard the
   declared expectation greps), while the Built world's reads the build
   tree (src/api/ml) and mentions no prefix at all. Both worlds' probes
   must be DISTINCT commands — the consumer exclusivity realized. *)
let z3_installed_probe_consumes_prefix : Canary_project_test.pure_test =
  { name = "z3.installed_probe_consumes_prefix";
    check =
      (fun () ->
        let pr = Canary_project_z3.z3_run (Canary_basic.detect_distro ()) in
        let probe_cmds a =
          let spec =
            pr.Canary_project_run.pr_runner_spec a ~workspace:"/tmp/inst" ()
          in
          List.filter_map spec.Canary_step_builder.probe_binding
            ~f:(fun (l, _, f) ->
              if Poly.equal l Canary_lang.OCaml then
                Some (f ~output_dir:"/tmp/inst" ~variant_key:"pin")
              else None)
        in
        let raw_probe_of a =
          (* the dev chains' raw probe (the only one that reads a concrete
             tree; the fetched worlds' opam probe is prefix-agnostic) *)
          List.find (probe_cmds a) ~f:(fun c ->
              String.is_substring c ~substring:"z3_example")
        in
        let scenarios = Canary_project_run.scenarios_of pr in
        let of_provision pv =
          List.filter_map scenarios ~f:(fun a ->
              if
                Canary_enumerate.equal_provision
                  (Canary_enumerate.provision_of a Canary_artifact.a_lib)
                  pv
              then raw_probe_of a
              else None)
        in
        let staged = of_provision Canary_artifact.Installed in
        let build_tree = of_provision Canary_artifact.Built in
        (* both faces must be POPULATED (a lost world would make the
           for_alls vacuous) and each must read only its own tree *)
        (not (List.is_empty staged))
        && (not (List.is_empty build_tree))
        (* the staged paths are per-ref (`install-<id>`, 2026-08-19), so
           match the SHAPE rather than a literal prefix name *)
        && List.for_all staged ~f:(fun c ->
               String.is_substring c ~substring:"/install-"
               && String.is_substring c ~substring:"/lib/ocaml/z3"
               && String.is_substring c ~substring:"/lib/libz3.so"
               && String.is_substring c ~substring:"STAGED PACKAGE MISSING")
        && List.for_all build_tree ~f:(fun c ->
               String.is_substring c ~substring:"src/api/ml"
               && (not (String.is_substring c ~substring:"STAGED PACKAGE"))
               && not (String.is_substring c ~substring:"/install-"))) }

(* M2 step 4 pin (2026-08-17): z3/llvm's decls are HONEST — the wheel-
   bundled Python bindings are Ctypes + Dlopen (the previous Cext
   declaration was wrong), the OCaml cstubs facts match the built
   products (z3's .pre code-gen template / llvm's llvm_ocaml.c), and
   both declare their raw cmake/ninja OCaml builds. *)
let z3_llvm_binding_decls_pin : Canary_project_test.pure_test =
  { name = "z3_llvm.binding_decls_honest";
    check =
      (fun () ->
        let d_of pr mech =
          Canary_project_run.binding_decl_of pr
            (Canary_artifact.a_binding Canary_lang.OCaml mech)
        in
        let pr = Canary_project_z3.z3_run () in
        let ok_z3 =
          (match d_of pr Canary_mechanism.Cstubs with
          | Some d ->
              String.equal d.native.prefix "Z3_"
              && (match d.coupling with
                 | Canary_binding_decl.Stub_archive sa ->
                     Poly.equal sa.sources
                       [ "src/api/ml/z3native_stubs.c.pre" ]
                     && String.equal sa.archive "libz3ml.a"
                 | _ -> false)
          | None -> false)
          && (match d_of pr Canary_mechanism.Ctypes with
             | Some d -> (
                 match d.coupling with
                 | Canary_binding_decl.Dlopen { name } ->
                     String.equal name "libz3.so"
                 | _ -> false)
             | None -> false)
          && Poly.equal pr.pr_raw_build_overrides
               [ (Canary_lang.OCaml, Canary_mechanism.Cstubs) ]
        in
        let pr = Canary_project_llvm.llvm_run () in
        let ok_llvm =
          (match d_of pr Canary_mechanism.Cstubs with
          | Some d ->
              String.equal d.native.prefix "LLVM"
              && (match d.coupling with
                 | Canary_binding_decl.Stub_archive sa ->
                     String.equal sa.archive "libllvm.a"
                 | _ -> false)
          | None -> false)
          && (match d_of pr Canary_mechanism.Ctypes with
             | Some d -> (
                 match d.coupling with
                 | Canary_binding_decl.Dlopen { name } ->
                     String.equal name "libllvmlite.so"
                 | _ -> false)
             | None -> false)
          && Poly.equal pr.pr_raw_build_overrides
               [ (Canary_lang.OCaml, Canary_mechanism.Cstubs) ]
        in
        ok_z3 && ok_llvm) }

(* The result table's registry shape (2026-08-17): 23 rows = Σ of every
   project's enumerated scenarios (sqlite 3, z3 7, llvm 5, tiny-full 1,
   zarith 3, cairo 1, libffi 1, ssl 2); the column union carries the
   install + probe actions. The web identity: the pre-10549 row's ref
   links the REMOTE COMMIT (the regression case's own repo record) and
   its build_lib cell carries the provision choice B:d. Hermetic — no
   run data (marks are pinned separately by matrix.marks_from_log). *)
(* The ROW order (2026-08-18, user): within a project, rows group by
   the source REF (the declared repo family order), then the C lib
   (built before fetched), then each binding. Checked on z3's 7
   scenarios under the declared ref order [4.15.2, latest, arbipher,
   pre-10549]: per ref the dev chain (lib built) precedes the
   all-fetched world (lib fetched). *)
let matrix_row_order_pin : Canary_project_test.pure_test =
  { name = "matrix.row_order";
    check =
      (fun () ->
        let z3 =
          List.Assoc.find_exn Canary_registry.all_projects "z3"
            ~equal:String.equal
        in
        let sorted =
          List.stable_sort (Canary_project_run.scenarios_of z3)
            ~compare:(fun x y ->
              Stdlib.compare (Canary_matrix.row_key z3 x)
                (Canary_matrix.row_key z3 y))
        in
        let keyed =
          List.map sorted ~f:(fun a ->
              let src_id =
                (Canary_enumerate.version_of a Canary_artifact.a_source)
                  .Canary_basic.id
              in
              let lib_prov =
                match Canary_enumerate.placement_of a Canary_artifact.a_lib with
                | Some pl -> pl.Canary_artifact.provision
                | None -> Canary_artifact.Absent
              in
              (src_id, lib_prov))
        in
        (* 2026-08-19 (the z3 landing): each dev ref now shows its
           build/install PAIR instead of a build row plus a phantom
           fetched row (four all-Fetched worlds that differed only in a
           source ref none of them read). The stable ref keeps the single
           fetched row — the source follows the lib's channel. *)
        Poly.equal keyed
          [ ("4.15.2", Canary_artifact.Fetched);
            ("latest", Canary_artifact.Built);
            ("latest", Canary_artifact.Installed);
            ("arbipher", Canary_artifact.Built);
            ("arbipher", Canary_artifact.Installed);
            ("pre-10549", Canary_artifact.Built);
            ("pre-10549", Canary_artifact.Installed) ]) }

(* The GLOBAL row index (2026-08-18, user): every row carries its
   ordinal (#N, fast pointing in the rendered order) + a stable code
   (the digest of the row's identity — the historical pointer). Pure
   display: the index never feeds a cache key or scenario identity.
   Pin: ordinals are 1..N unique; codes are deterministic across two
   matrix_of calls and unique across rows. *)
let matrix_row_index_pin : Canary_project_test.pure_test =
  { name = "matrix.row_index";
    check =
      (fun () ->
        let m1 = Canary_matrix.matrix_of Canary_registry.all_projects in
        let m2 = Canary_matrix.matrix_of Canary_registry.all_projects in
        let n = List.length m1.Canary_matrix.rows in
        let indexes =
          List.map m1.Canary_matrix.rows ~f:(fun (r : Canary_matrix.row) ->
              r.Canary_matrix.index)
        in
        let uniq =
          Poly.equal (List.dedup_and_sort indexes ~compare:Int.compare)
            indexes
        in
        (* sorted = [1..n] → consecutive, 1-based *)
        let consecutive =
          Poly.equal (List.sort indexes ~compare:Int.compare)
            (List.init n ~f:(fun i -> i + 1))
        in
        let codes =
          List.map m1.Canary_matrix.rows ~f:(fun (r : Canary_matrix.row) ->
              (r.Canary_matrix.project, r.Canary_matrix.scenario,
               r.Canary_matrix.code))
        in
        let stable =
          Poly.equal codes
            (List.map m2.Canary_matrix.rows ~f:(fun (r : Canary_matrix.row) ->
                 (r.Canary_matrix.project, r.Canary_matrix.scenario,
                  r.Canary_matrix.code)))
        in
        let codes_uniq =
          List.length
            (List.dedup_and_sort
               (List.map codes ~f:(fun (_, _, c) -> c))
               ~compare:String.compare)
          = n
        in
        uniq && consecutive && stable && codes_uniq
        && List.for_all codes ~f:(fun (_, _, c) -> String.length c = 6)) }

(* The PROVIDER-EXCLUSIVE-ROWS invariant (2026-08-18, user) — a
   GENERAL factory, the same shape as [binding_follows_chain_pin]:
   any project that declares an Installed lib universe must enumerate
   the exclusive rows, and EVERYTHING here is DERIVED from the
   project (the declared universe, the {!Canary_matrix.row_key}
   ordering, the realized chains) — no hand-listed scenarios:
   (a) the pair axis — the Built and Installed universes declare the
       SAME channel list (each built version gets its staged face);
   (b) the row order, PER SOURCE-REF GROUP — build-then-install in
       declared channel order, fetched LAST (the "repo × 2 + 1 fetched"
       shape). Grouping by ref is what makes the check general
       (2026-08-19, the z3 landing): a single-ref project like sqlite is
       one group and reduces to the original check, while a multi-ref
       project like z3 repeats the shape per declared repo. The
       global-order-only form asserted one row per (channel, provision)
       and could not describe z3's three dev refs at all;
   (c) the twin count per group — as many Installed rows as Built rows.
       Without it (b) is satisfiable by a group that LOST its staged
       row (the filtered expectation would shrink with it);
   (d) the exclusivity — the Install_lib action fires IFF the lib
       provision is Installed (the rows' [ar_needs] gates).
   The row REALIZATION (what the staging/probe commands ARE) stays
   project data — see [sqlite_staged_probe_paths_pin] /
   [z3_installed_probe_consumes_prefix]. Projects opt in by declaring
   an Installed universe. *)
let provider_rows_pin ~prefix (pr : Canary_project_run.project_run) :
    Canary_project_test.pure_test =
  { name = prefix ^ ".provider_rows";
    check =
      (fun () ->
        let asgs = Canary_project_run.scenarios_of pr in
        let lib_prov a =
          match
            Canary_enumerate.placement_of a Canary_artifact.a_lib
          with
          | Some pl -> pl.Canary_artifact.provision
          | None -> Canary_artifact.Absent
        in
        let channels_of pv =
          let spec =
            Canary_project_spec.project_spec_of_rows pr.pr_artifacts
          in
          Canary_artifact.ps_versions_of spec Canary_artifact.a_lib pv
          |> List.map ~f:(fun (b : Canary_basic.build_id) ->
                 b.Canary_basic.channel)
        in
        let built_chs = channels_of Canary_artifact.Built in
        let installed_chs = channels_of Canary_artifact.Installed in
        let fetched_chs = channels_of Canary_artifact.Fetched in
        (* (a) the pair axis *)
        let ok_pair_axis = Poly.equal built_chs installed_chs in
        (* (b) + (c) the row order and twin count, PER REF GROUP *)
        let sorted =
          List.stable_sort asgs ~compare:(fun x y ->
              Stdlib.compare (Canary_matrix.row_key pr x)
                (Canary_matrix.row_key pr y))
        in
        let ref_of a =
          (Canary_enumerate.version_of a Canary_artifact.a_source)
            .Canary_basic.id
        in
        let pair_of a =
          (Canary_enumerate.channel_of a Canary_artifact.a_lib, lib_prov a)
        in
        (* the canonical shape one ref group may show, in order *)
        let canonical =
          List.concat_map built_chs ~f:(fun ch ->
              [ (ch, Canary_artifact.Built);
                (ch, Canary_artifact.Installed) ])
          @ List.map fetched_chs ~f:(fun ch ->
                (ch, Canary_artifact.Fetched))
        in
        let groups =
          List.group sorted ~break:(fun x y ->
              not (String.equal (ref_of x) (ref_of y)))
        in
        let group_ok g =
          let pairs = List.map g ~f:pair_of in
          let count pv =
            List.count pairs ~f:(fun (_, p) ->
                Canary_artifact.equal_provision p pv)
          in
          (* the group's rows appear in the canonical order … *)
          Poly.equal pairs
            (List.filter canonical ~f:(fun p ->
                 List.mem pairs p ~equal:Poly.equal))
          (* … and every built row in it kept its staged twin *)
          && count Canary_artifact.Built = count Canary_artifact.Installed
        in
        let ok_order =
          (not (List.is_empty groups)) && List.for_all groups ~f:group_ok
        in
        (* (d) the install exclusivity *)
        let ok_gating =
          List.for_all asgs ~f:(fun a ->
              let has_install =
                List.mem (Canary_matrix.actions_of pr a)
                  Canary_basic.Install_lib ~equal:Poly.equal
              in
              Poly.equal has_install
                (Canary_artifact.equal_provision (lib_prov a)
                   Canary_artifact.Installed))
        in
        ok_pair_axis && ok_order && ok_gating) }

(* The sqlite-specific REALIZATION check (2026-08-18) — the part the
   factory can't derive (the probe env is project data): the Installed
   world's OCaml probe reads the STAGED lib (LD_LIBRARY_PATH
   <ws>/install/lib) while the Built world's reads the build tree —
   the consumer exclusivity realized in commands. *)
let sqlite_staged_probe_paths_pin : Canary_project_test.pure_test =
  { name = "sqlite.staged_probe_paths";
    check =
      (fun () ->
        let pr = Canary_project_sqlite.sqlite_run in
        let probe_cmd_of a =
          let spec =
            pr.Canary_project_run.pr_runner_spec a ~workspace:"/tmp/ws" ()
          in
          match
            List.find spec.Canary_step_builder.probe_binding
              ~f:(fun (l, _, _) -> Poly.equal l Canary_lang.OCaml)
          with
          | Some (_, _, f) -> f ~output_dir:"/tmp/ws" ~variant_key:"pin"
          | None -> ""
        in
        List.for_all (Canary_project_run.scenarios_of pr) ~f:(fun a ->
            let cmd = probe_cmd_of a in
            match
              Canary_enumerate.provision_of a Canary_artifact.a_lib
            with
            | Canary_artifact.Installed ->
                String.is_substring cmd ~substring:"/install/lib"
            | Canary_artifact.Built ->
                String.is_substring cmd ~substring:"/lib"
                && not (String.is_substring cmd ~substring:"install/lib")
            | _ -> true)) }

let matrix_registry_shape_pin : Canary_project_test.pure_test =
  { name = "matrix.registry_shape";
    check =
      (fun () ->
        let rows =
          List.concat_map Canary_registry.all_projects ~f:(fun (name, pr) ->
              List.map (Canary_project_run.scenarios_of pr) ~f:(fun a ->
                  ( name,
                    Stdlib.Filename.basename
                      (Canary_project_run.scenario_dir_of ~pr_name:name a)
                  )))
        in
        let columns =
          List.concat_map Canary_registry.all_projects ~f:(fun (_, pr) ->
              Canary_project_run.covered_actions_of pr)
          |> Stdlib.List.sort_uniq Stdlib.compare
          |> List.map ~f:Canary_basic.string_of_action
        in
        let m = Canary_matrix.matrix_of Canary_registry.all_projects in
        let pre_10549_row =
          List.find m.Canary_matrix.rows ~f:(fun (r : Canary_matrix.row) ->
              String.equal r.Canary_matrix.scenario
                "ocaml_binding-built-dev_source-fetched-pre-10549_lib-built-dev_python_binding-fetched")
        in
        let arbipher_row =
          List.find m.Canary_matrix.rows ~f:(fun (r : Canary_matrix.row) ->
              String.equal r.Canary_matrix.scenario
                "ocaml_binding-built-dev_source-fetched-arbipher_lib-built-dev_python_binding-fetched")
        in
        (* z3's ONE all-fetched world (2026-08-19): the source follows the
           lib's channel, so the Fetched lib pairs only with the stable
           repo — the pre-10549/latest/arbipher fetched rows it used to
           name were phantoms (same lib, same binding, unread source). *)
        let stable_fetched_row =
          List.find m.Canary_matrix.rows ~f:(fun (r : Canary_matrix.row) ->
              String.equal r.Canary_matrix.scenario
                "ocaml_binding-fetched-4.16.0_source-fetched-4.15.2_lib-fetched_python_binding-fetched")
        in
        (* the staged twin of the pre-fix ref: the row exists, its
           install_lib cell names the INSTALLED lib, and the Built twin
           above carries no install_lib cell (the exclusivity, read off
           the rendered matrix rather than the action list) *)
        let pre_10549_installed_row =
          List.find m.Canary_matrix.rows ~f:(fun (r : Canary_matrix.row) ->
              String.equal r.Canary_matrix.scenario
                "ocaml_binding-built-dev_source-fetched-pre-10549_lib-installed-dev_python_binding-fetched")
        in
        let staged_cells_ok =
          let cell (r : Canary_matrix.row) tag =
            match List.Assoc.find r.Canary_matrix.cells tag ~equal:String.equal with
            | Some (Some c) -> Some c.Canary_matrix.provision
            | _ -> None
          in
          match (pre_10549_installed_row, pre_10549_row) with
          | Some inst, Some built ->
              Poly.equal (cell inst "install_lib") (Some "lib I:d")
              && Poly.equal (cell inst "probe_lib") (Some "lib I:d")
              && Option.is_none (cell built "install_lib")
          | _ -> false
        in
        let web_identity_ok =
          match pre_10549_row with
          | None -> false
          | Some (r : Canary_matrix.row) ->
              (match r.Canary_matrix.ref_url with
               | Some url ->
                   String.equal url
                     "https://github.com/Z3Prover/z3/commit/bc4585e0b"
               | None -> false)
              (* the label carries the identity AND the version the
                 built lib inherits *)
              && String.equal r.Canary_matrix.ref_label
                   "pre-10549 (bc4585e0b)"
              && (match
                    List.Assoc.find r.Canary_matrix.cells "build_lib"
                      ~equal:String.equal
                  with
                  | Some (Some c) ->
                      String.equal c.Canary_matrix.provision "lib B:d"
                  | _ -> false)
              (* the fork's label is its IDENTITY (arbipher), not the
                 literal HEAD it shares with latest — the two HEAD-ref
                 chains must not render as identical rows *)
              && (match arbipher_row with
                  | Some ar ->
                      String.equal ar.Canary_matrix.ref_label
                        "arbipher (HEAD)"
                  | None -> false)
              (* the all-fetched world names its providers + versions:
                 the lib is the SYSTEM PM's package (the live dpkg
                 version — the pin asserts the static prefix only, the
                 version is machine-dependent), the binding is the
                 opam package at its store pin *)
              && (match stable_fetched_row with
                  | Some fr -> (
                      match
                        List.Assoc.find fr.Canary_matrix.cells "fetch_lib"
                          ~equal:String.equal
                      with
                      | Some (Some c) ->
                          String.is_prefix c.Canary_matrix.provision
                            ~prefix:"lib apt z3."
                      | _ -> false)
                      && (match
                            List.Assoc.find fr.Canary_matrix.cells
                              "fetch_binding_ocaml"
                              ~equal:String.equal
                          with
                          | Some (Some c) ->
                              String.equal c.Canary_matrix.provision
                                "ocaml opam z3.4.16.0"
                          | _ -> false)
                  | None -> false)
        in
        (* 25 since sqlite's Installed worlds (+2, 2026-08-18) *)
        List.length rows = 25
        && List.count rows ~f:(fun (n, _) -> String.equal n "z3") = 7
        && List.count rows ~f:(fun (n, _) -> String.equal n "zarith") = 3
        && List.count rows ~f:(fun (n, _) -> String.equal n "ssl") = 2
        && List.mem columns "install_lib" ~equal:String.equal
        && List.mem columns "probe_binding_ocaml" ~equal:String.equal
        && web_identity_ok && staged_cells_ok
        (* the CANONICAL column order (ratchet, 2026-08-18): the
           native/lib group, then per language a same-shaped block
           (binding build/fetch/pack/probe + its app) — probe_app_ocaml
           sits INSIDE the ocaml block, not at the end *)
        && String.equal
             (String.concat ~sep:"," m.Canary_matrix.columns)
             (String.concat ~sep:","
                [ "fetch_source"; "configure"; "scan_sources";
                  "build_headers"; "build_lib"; "install_lib"; "fetch_lib";
                  "probe_lib"; "build_binding_ocaml"; "fetch_binding_ocaml";
                  "pack_binding_ocaml"; "probe_binding_ocaml";
                  "probe_app_ocaml"; "build_binding_python";
                  "probe_binding_python" ])
        (* the OFF-TREE binding-source slot (2026-08-18, user): the
           order key places fetch_binding_source at the FRONT of its
           language's block — the column appears once a project wires
           the fetch (the zarith migration is the natural first
           consumer) *)
        && Canary_matrix.compare_column
             (Canary_basic.Fetch
                (Canary_basic.Binding_source Canary_lang.OCaml))
             (Canary_basic.Build_binding Canary_lang.OCaml)
           < 0
        && Canary_matrix.compare_column
             (Canary_basic.Fetch
                (Canary_basic.Binding_source Canary_lang.OCaml))
             (Canary_basic.Probe_lib)
           > 0) }

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
      batch_tier_pin;
      shadow_policy_ladder_pin;
      repo_model_pin;
      local_fork_pin;
      repo_contents_pin;
      repo_axes_pin;
      forward_cell_expectation_pin;
      publish_wired_pin;
      opam_template_render_pin;
      tiny_binding_realization_pin;
      binding_decls_on_project_run_pin;
      sqlite_binding_decls_pin;
      z3_llvm_binding_decls_pin;
      zarith_binding_decls_pin;
      z3_regression_pre_10549_pin;
      z3_installed_probe_consumes_prefix;
      matrix_row_order_pin;
      matrix_row_index_pin;
      (* the GENERAL factory, instantiated per project that declares an
         Installed universe: sqlite (one ref group) and z3 (one group per
         declared repo) — the same derived invariants over both shapes *)
      provider_rows_pin ~prefix:"sqlite" Canary_project_sqlite.sqlite_run;
      sqlite_staged_probe_paths_pin;
      provider_rows_pin ~prefix:"z3"
        (Canary_project_z3.z3_run (Canary_basic.detect_distro ()));
      z3_install_prefix_isolated_pin;
      matrix_registry_shape_pin ]

