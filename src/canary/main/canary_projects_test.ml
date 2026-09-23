open Base

(* ── coarse fixtures (2026-08-25) ──
   A row now declares an ORIGIN per provision, not a bare provision. The
   fixtures below test the AXIS shape — how many worlds a universe
   produces, which chains apply — and have no realization to speak of, so
   they need a placeholder origin. [ax] fabricates one, and its name says
   it is about the axis; a real project must state where the artifact
   actually comes from. *)
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

(** A project's declared SOURCE artifact — [a_source] for a project whose
    repos carry the C lib (cairo, libffi, z3, llvm), or
    [a_binding_source lang] when the repos carry a BINDING's source
    (zarith's ocaml/Zarith.git over an apt libgmp, 2026-08-19). Pins that
    ask "the source's pinned ref" must ask the project, not assume
    [a_source]. *)
let source_artifact_of (pr : Canary_project_run.project_run) :
    Canary_artifact.artifact_info =
  Option.value
    (List.find (Canary_project_run.artifact_infos pr) ~f:(fun id ->
         match Canary_artifact.kind_of id with
         | Canary_basic.Source | Canary_basic.Binding_source _ -> true
         | _ -> false))
    ~default:Canary_artifact.a_source

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
    ?(n_worlds = 5) ?(n_dev = 2) ?(n_stable = 3) ?(n_staged = 0)
    ?(n_forward = 0) () : Canary_project_test.pure_test list =
  (* [artifacts] became unused when
     [<prefix>.providers_match_baseline_provisions] retired (2026-08-25).
     Kept in the signature: it is the ROWS, and the next per-project pin
     that reads a declaration rather than an enumeration wants them. *)
  ignore artifacts;
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
  let ocaml_binding =
    Canary_artifact.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs
  in
  let binding_built a =
    EN.equal_provision (Canary_enumerate.provision_of a ocaml_binding) EN.Built
  in
  (* stable baseline: everything released — a Fetched lib under a Fetched
     binding. The binding clause matters since 2026-08-19: with the
     binding's channel freed, a Fetched lib also pairs with a BUILT
     binding, and that world is the FORWARD cell, not a baseline. *)
  let is_stable_world a =
    EN.equal_provision (lib_prov a) EN.Fetched
    && EN.equal_provision (Canary_enumerate.provision_of a Canary_artifact.a_source) EN.Fetched
    && not (binding_built a)
  in
  (* the FORWARD cell: the released lib under a binding built from a dev
     tree — "does today's binding still work against the lib users have?" *)
  let is_forward a =
    EN.equal_provision (lib_prov a) EN.Fetched && binding_built a
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
        && List.count asgs ~f:is_forward = n_forward
        (* the buckets PARTITION the world set — a world that is none of
           {all-Fetched baseline, build chain, staged face, forward cell}
           would slip past the counts otherwise *)
        && n_dev + n_stable + n_staged + n_forward = n_worlds
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
        (* the non-building worlds: the stable baseline plus the FORWARD
           cells, whose lib is the platform's even though their binding is
           built (the build there is the binding's, keyed on the source) *)
        && List.count cases ~f:not = n_stable + n_forward
        && List.for_all2_exn asgs cases ~f:(fun a dev ->
               Bool.equal dev
                 (EN.equal_provision (lib_prov a) EN.Built
                 || EN.equal_provision (lib_prov a) Canary_artifact.Installed))
        && List.for_all asgs ~f:(fun a ->
               String.equal
                 (source_of a).Canary_artifact_source.version.Canary_basic.id
                 (Canary_enumerate.version_of a Canary_artifact.a_source)
                   .Canary_basic.id)) } ]
    (* [<prefix>.providers_match_baseline_provisions] RETIRED 2026-08-25.

       It asserted that a row's single provider derived the same coarse
       provision as the baseline scenario's placement — a drift check
       between two declarations that had to be kept in step by hand. The
       spec model removed the second declaration: a row now states one
       [provision_spec] per admissible provision, the coarse axis is
       [provision_of_spec] over it, and there is nothing left that could
       drift. The type does what the pin used to watch for. *)

let built_family a =
  let pv = Canary_enumerate.provision_of a Canary_artifact.a_lib in
  Canary_enumerate.equal_provision pv Canary_artifact.Built
  || Canary_enumerate.equal_provision pv Canary_artifact.Installed

let z3_pins : Canary_project_test.pure_test list =
  (* SIXTEEN worlds (2026-08-19, the mismatch matrix): the binding's
     channel became its own axis, so each of the 3 dev refs carries the
     2×2 — dev baseline (lib B × binding B), BACKWARD (lib B × binding
     F:4.16.0), FORWARD (lib F:apt × binding B) — plus the staged face of
     each lib-built cell. The 4th cell of the matrix, both-released, is
     ref-INDEPENDENT (nothing is built, so the source ref is unread) and
     is therefore the single collapsed all-Fetched world.
       3 refs × {(B,B), (B,F)} = 6 dev
     + 3 refs × {(I,B), (I,F)} = 6 staged
     + 3 refs × {(F,B)}        = 3 forward
     + 1 both-released baseline           = 16 *)
  two_chain_pins ~prefix:"z3" ~spec:(Canary_project_spec.project_spec_of_rows Canary_project_z3.z3_artifacts)
    ~artifacts:Canary_project_z3.z3_artifacts
    ~source_of:Canary_project_z3.z3_source_for_assignment
    ~dispatch_is_dev:built_family
    ~n_worlds:16 ~n_dev:6 ~n_stable:1 ~n_staged:6 ~n_forward:3 ()

let llvm_pins : Canary_project_test.pure_test list =
  two_chain_pins ~prefix:"llvm" ~spec:(Canary_project_spec.project_spec_of_rows Canary_project_llvm.llvm_artifacts)
    ~artifacts:Canary_project_llvm.llvm_artifacts
    ~source_of:Canary_project_llvm.llvm_source_for_assignment
    ~dispatch_is_dev:built_family
    (* THREE worlds (2026-08-19): 2 dev build chains + ONE both-released
       baseline. It was 5 — the three all-Fetched worlds differed only in a
       source ref none of them read, and the unread-source collapse
       ({!Canary_enumerate.source_ref_ok}) folded them into one. llvm keeps
       its binding `follows` for now, so it has no forward/backward cells:
       opening its 2×2 needs the same two probe realizations z3 grew. *)
    ~n_worlds:3 ~n_dev:2 ~n_stable:1 ()

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
          ~bindings:Canary_project_z3.z3_agreement_bindings
          ~langs:[ Canary_lang.Python ]
      in
      (match lower (B.Probe_binding Canary_lang.Python) pip_loc with
       | Canary_step_model.Expect_compat_derived { inputs; _ } ->
           List.exists inputs ~f:(function
             | Canary_agreement_common.Python_attrs _ -> true
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
          ~bindings:Canary_project_llvm.llvm_stable_agreement_bindings
          ~langs:[ Canary_lang.OCaml ]
      in
      (match lower (B.Probe_binding Canary_lang.OCaml) None with
       | Canary_step_model.Expect_compat_derived { inputs; _ } ->
           let has p = List.exists inputs ~f:p in
           has (function Canary_agreement_common.C_stub _ -> true | _ -> false)
           && has (function Canary_agreement_common.Native_lib _ -> true | _ -> false)
           && has (function Canary_agreement_common.Ocaml_mli _ -> true | _ -> false)
           (* dev-chain exemption: pack/build-tree path FIRST per input *)
           && List.for_all inputs ~f:(function
                | Canary_agreement_common.C_stub (p :: _)
                | Canary_agreement_common.Ocaml_mli (p :: _) ->
                    String.is_prefix p ~prefix:"pack_binding_ocaml/"
                | Canary_agreement_common.Native_lib (p :: _) ->
                    String.is_prefix p ~prefix:"probe_lib/"
                | _ -> true)
       | _ -> false)
      && sm_is_success (lower (B.Probe_binding Canary_lang.Python) pip_loc)) }

(* The framework's DERIVED evidence path must be the one the projects
   independently hand-wrote (2026-09-02). Three tables written at three
   different times agree on the rule — a binding's inspection lives in
   its INSTALL step's output dir — and until now the template
   contradicted all three by naming [build_binding_<lang>], a step that
   carries no binding inspection in any world. The check is worth having
   as a pin rather than a comment because it is what lets these tables
   be deleted: a derivation that reproduces them is a safe replacement,
   and this fails the moment it stops reproducing them. *)
let derived_evidence_matches_projects : Canary_project_test.pure_test =
  { name = "agreements.derived_evidence_matches_projects";
    check = (fun () ->
      let module R = Canary_agreement in
      let module CS = Canary_scenario in
      let world lang provision : Canary_artifact.assignment =
        [ ( Canary_artifact.a_binding lang Canary_mechanism.Cstubs,
            { Canary_artifact.provision;
              version = Canary_basic.good Canary_basic.Dev } ) ]
      in
      (* what the framework derives, as a flat path list *)
      let paths_of = List.concat_map ~f:(function
        | Canary_agreement_common.Ocaml_mli ps | Canary_agreement_common.Python_attrs ps
        | Canary_agreement_common.C_stub ps -> ps
        | _ -> [])
      in
      let derived lang provision id =
        paths_of (R.inputs_of_agreement ~world:(world lang provision) id lang)
      in
      (* what a project declared, as the same flat list *)
      let declared (bs : CS.agreement_binding list) =
        List.concat_map bs ~f:(fun b ->
            List.concat_map b.CS.firings ~f:(fun f ->
                match f.CS.source with
                | CS.From_artifact { inputs; _ } -> paths_of inputs
                | _ -> []))
      in
      let tag p = match String.lsplit2 p ~on:'/' with
        | Some (t, _) -> t | None -> p
      in
      let tags l = List.map l ~f:tag in
      let derived_tag lang provision =
        match derived lang provision Canary_agreement_common.Api_names_present with
        | p :: _ -> tag p
        | [] -> "«none»"
      in
      (* ssl: an opam-fetched OCaml binding. Its C2 firing names
         fetch_binding_ocaml; the second firing's inspect_nlv.json is a
         project-specific SECOND view of the same artifact, so only the
         tag is shared — which is the part being derived. *)
      let ssl_tags = tags (declared Canary_project_ssl.ssl_agreement_bindings) in
      let ssl_ok =
        (not (List.is_empty ssl_tags))
        && List.for_all ssl_tags ~f:(String.equal "fetch_binding_ocaml")
        && String.equal (derived_tag Canary_lang.OCaml Canary_store.Fetched)
             "fetch_binding_ocaml"
      in
      (* z3: a pip-fetched Python binding *)
      let z3_ok =
        List.equal String.equal
          (tags (declared Canary_project_z3.z3_agreement_bindings))
          [ "fetch_binding_python" ]
        && String.equal (derived_tag Canary_lang.Python Canary_store.Fetched)
             "fetch_binding_python"
      in
      (* tiny and the Pattern A template pass NO world and mean the
         build tree — the convention this template was written for, and
         the one an unconverted caller must keep getting *)
      let workspace_ok =
        String.equal (derived_tag Canary_lang.OCaml Canary_store.Built)
          "build_binding_ocaml"
        && String.equal (derived_tag Canary_lang.OCaml Canary_store.Absent)
             "build_binding_ocaml"
      in
      (* llvm is the THIRD case and the one still out of reach: it packs
         its built binding into opam and inspects the published package,
         and nothing declares that a project publishes. So its table
         names pack_binding_ocaml where the derivation says
         build_binding_ocaml. This asserts the gap rather than hiding
         it: add the publish bit and this pin fails, which is the
         reminder to derive llvm's path and delete its table. *)
      let llvm_binding_tags =
        List.filter
          (tags (declared Canary_project_llvm.llvm_stable_agreement_bindings))
          ~f:(fun t -> String.is_substring t ~substring:"binding")
      in
      let llvm_gap_still_open =
        List.mem llvm_binding_tags "pack_binding_ocaml" ~equal:String.equal
        && not
             (String.equal
                (derived_tag Canary_lang.OCaml Canary_store.Built)
                "pack_binding_ocaml")
      in
      ssl_ok && z3_ok && workspace_ok && llvm_gap_still_open) }

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
            Canary_artifact.equal_artifact_info p.Canary_enumerate.rp_consumer c)
      in
      (* 10 since the binding's channel pair (2026-08-19): the lib's 5
         placements (2 built + 2 installed + 1 fetched) × 2 opam pins *)
      List.length asgs = 10
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
         (* the deploy pairings are the built-family lib worlds (canary
            supplies the run lib under a fetched binding): 4 lib
            placements × 2 binding pins *)
         = 8) }

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
          match Canary_project_spec.provider_of_row d with
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
             match Canary_project_spec.provider_of_row d with
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

(* THE PACKAGE-MANAGER GATE (2026-08-19, user: "add a datatype for it and
   mark it for the current opam binding part in the project spec"). Every
   declared binding says how its PACKAGE declares its dependency on the C
   lib, because that — and only that — decides what it takes to force a
   combination opam would not pick. Pinned:
   (a) every declared binding_decl of an EXTERNAL project carries a gate
       (tiny is exempt: in-tree, no package manager between the sides);
   (b) the measured groups, so a spec edit that quietly reclassifies a
       project fails here: the conf-* projects are Free (no constraint),
       ctypes-foreign is Bounded (conf-libffi >= 2.0.0), the llvm binding
       is Fixed (conf-llvm-shared = 19 — the only one needing a wrapper),
       z3's opam package builds its own lib, and both wheels bundle theirs;
   (c) the freedom derivation agrees with the group — the answer to "how
       hard is this project's 2×2". *)
(* THE VENDORED PREBUILT (2026-08-19, user's sourcing rule): a project
   whose distro ships one lib version gets its LATEST point as a
   downloaded prebuilt, declared [Vendored] and prepared before any run.
   Pinned:
   (a) a project declaring [prebuilt_latest] enumerates BOTH points —
       Fetched@Stable (the system PM) and Vendored@Dev (the prebuilt);
   (b) the two worlds RESOLVE DIFFERENT FILES. This is the teeth: cairo's
       two versions export identical symbol counts (420/420), so a
       vendored world that silently fell back to the system lib would
       look exactly like a pass. The realized probe command must name the
       prebuilt path in the Vendored world and the system glob in the
       Fetched one;
   (c) every declared prebuilt carries a RATIONALE on its lib row, and so
       does every project that declares NONE — a one-point axis must say
       why (zarith: apt already ships upstream's newest GMP). *)
let vendored_prebuilt_pin : Canary_project_test.pure_test =
  { name = "spec.vendored_prebuilt_pair";
    check =
      (fun () ->
        let module PB = Canary_prebuilt in
        let lib_probe_cmd pr a =
          let spec =
            pr.Canary_project_run.pr_runner_spec a ~workspace:"/tmp/pb" ()
          in
          List.fold spec.Canary_step_builder.probe_lib ~init:""
            ~f:(fun acc (_, f) ->
              acc ^ f ~output_dir:"/tmp/pb" ~variant_key:"pin")
        in
        let binding_probe_cmd pr a =
          let spec =
            pr.Canary_project_run.pr_runner_spec a ~workspace:"/tmp/pb" ()
          in
          List.fold spec.Canary_step_builder.probe_binding ~init:""
            ~f:(fun acc (_, _, f) ->
              acc ^ f ~output_dir:"/tmp/pb" ~variant_key:"pin")
        in
        let pair_ok (pr : Canary_project_run.project_run) (pb : PB.t) =
          let asgs = Canary_project_run.scenarios_of pr in
          let of_prov pv =
            List.filter asgs ~f:(fun a ->
                Canary_artifact.equal_provision
                  (Canary_enumerate.provision_of a Canary_artifact.a_lib)
                  pv)
          in
          let fetched = of_prov Canary_artifact.Fetched in
          let vendored = of_prov Canary_artifact.Vendored in
          (* (a) both points enumerate *)
          (not (List.is_empty fetched))
          && (not (List.is_empty vendored))
          (* (b) and they read DIFFERENT files — the LIB probe … *)
          && List.for_all vendored ~f:(fun a ->
                 String.is_substring (lib_probe_cmd pr a)
                   ~substring:pb.PB.tag)
          && List.for_all fetched ~f:(fun a ->
                 not
                   (String.is_substring (lib_probe_cmd pr a)
                      ~substring:pb.PB.tag))
          (* … AND the CONSUMER. Added after the consumer half was found
             silently testing the system lib in both worlds (2026-08-19):
             a plain `ocamlfind -package` run resolves the ambient copy, so
             the vendored world's binding probe must carry the prebuilt on
             LD_LIBRARY_PATH or the cell tests a world it does not name. *)
          && List.for_all vendored ~f:(fun a ->
                 String.is_substring (binding_probe_cmd pr a)
                   ~substring:pb.PB.tag)
          && List.for_all fetched ~f:(fun a ->
                 not
                   (String.is_substring (binding_probe_cmd pr a)
                      ~substring:pb.PB.tag))
        in
        let rationale_ok (pr : Canary_project_run.project_run) =
          List.exists pr.Canary_project_run.pr_artifacts ~f:(fun r ->
              Canary_artifact.equal_artifact_info
                r.Canary_project_spec.ar_artifact Canary_artifact.a_lib
              && Option.is_some r.Canary_project_spec.ar_rationale)
        in
        (match Canary_project_libffi.decl.Canary_opam_binding.prebuilt_latest with
        | Some pb -> pair_ok Canary_project_libffi.libffi_run pb
        | None -> false)
        && (match Canary_project_cairo.decl.Canary_opam_binding.prebuilt_latest with
           | Some pb -> pair_ok Canary_project_cairo.cairo_run pb
           | None -> false)
        (* (c) including the project that declares NO prebuilt *)
        && Option.is_none
             Canary_project_zarith.decl.Canary_opam_binding.prebuilt_latest
        && rationale_ok Canary_project_zarith.zarith_run
        && rationale_ok Canary_project_libffi.libffi_run
        && rationale_ok Canary_project_cairo.cairo_run) }

(* THE FIVE JOINS STAY FIVE (2026-09-22). [Canary_topology]'s first cut
   had one value — an empty bridge list — standing for four different
   situations, and the terminal view made all four read as "no bridge".
   This pin holds the distinction that fixed it, because the collapse is
   invisible in the output once it happens: an unreachable declaration
   and a deliberate absence render identically unless something asserts
   they do not.

   Each clause names a project that is the SPECIMEN of its constructor,
   so a project changing its declaration fails here rather than quietly
   moving rows. *)
let topology_joins_pin : Canary_project_test.pure_test =
  { name = "topology.joins_are_distinguished";
    check =
      (fun () ->
        let module T = Canary_topology in
        let join name lang =
          match
            List.Assoc.find Canary_registry.all_specs name
              ~equal:String.equal
          with
          | None -> None
          | Some pr -> Some (T.join_of pr lang)
        in
        let is_bridged = function Some (T.Bridged _) -> true | _ -> false in
        let is_absorbed = function
          | Some (T.Bridge_absorbed _) -> true
          | _ -> false
        in
        let is_no_pm = function Some (T.No_pm_between _) -> true | _ -> false in
        let is_undeclared = function
          | Some T.Undeclared_join -> true
          | _ -> false
        in
        (* zarith declares conf-gmp and routes it *)
        is_bridged (join "zarith" Canary_lang.OCaml)
        (* z3's opam package builds libz3 — the bridge is absorbed, not
           absent, and the native side is therefore opam's own *)
        && is_absorbed (join "z3" Canary_lang.OCaml)
        && is_absorbed (join "z3" Canary_lang.Python)
        (* sqlite's Python side is CPython's stdlib: a declaration EXISTS
           and states that no package manager is in between. This is the
           clause that fails if the two [None]s are conflated again *)
        && is_no_pm (join "sqlite" Canary_lang.Python)
        (* ...while sqlite's OCaml side does declare a conf package *)
        && is_bridged (join "sqlite" Canary_lang.OCaml)
        (* ⚠ project/issues.md §2, held as a KNOWN gap rather than
           tolerated silently: these four declare a gate on the template's
           record and leave pr_binding_decls empty. When the routing is
           fixed this pin fails, which is the point — the fix must move
           them into a bridged row deliberately, not by accident *)
        && List.for_all
             [ "cairo"; "libffi"; "zlib"; "zstd" ]
             ~f:(fun p -> is_undeclared (join p Canary_lang.OCaml))
        (* and an absorbed join collapses the native side onto the
           language side, so one topology is not counted once per
           irrelevant native provision *)
        &&
        let rows = T.topologies Canary_registry.all_specs in
        let absorbed =
          List.filter rows ~f:(fun ((t : T.t), _) ->
              match t.T.tp_join with T.Bridge_absorbed _ -> true | _ -> false)
        in
        List.for_all absorbed ~f:(fun ((t : T.t), _) ->
            Poly.equal t.T.tp_sys t.T.tp_lang)
        && List.length absorbed = 3)
  }

(* THE LAYERED GRAPH DOES NOT DRIFT FROM THE REGISTRY (2026-09-22).
   [Canary_topology.claim_sites] is hand-written — it says which edge each
   claim sits on — and the page draws a badge per claim site. Two ways it
   rots silently: a renamed agreement leaves a claim site pointing at
   nothing, and a renamed edge leaves one pointing nowhere. Neither is
   visible on the page, which would carry on drawing a count.

   It also holds the ACTION coverage, because the point of the diagram is
   that it has every step: an action in the graph with no edge naming it
   is a hole in the model. *)
let topology_graph_pin : Canary_project_test.pure_test =
  { name = "topology.graph_matches_the_registry";
    check =
      (fun () ->
        let module T = Canary_topology in
        let known =
          List.map Canary_agreement.agreement_registry ~f:(fun r ->
              r.Canary_agreement.ag_slug)
          @ List.map Canary_agreement.proposed_agreements ~f:(fun p ->
                p.Canary_agreement.prop_slug)
        in
        (* every placed claim is a real registry row or candidate *)
        List.is_empty (T.unknown_claim_sites ~known)
        (* every placed edge exists *)
        && List.is_empty (T.dangling_claim_sites ())
        (* every node an edge names exists *)
        && List.for_all T.edges ~f:(fun e ->
               List.for_all (e.T.eg_to :: e.T.eg_from) ~f:(fun n ->
                   Option.is_some (T.node_by_id n)))
        (* the multi-edge structure is EXERCISED, not merely available:
           the declaration-facing lib claims sit on both producers of the
           library node, which is what stopped `realize_sys` reading as
           an edge nothing checks *)
        && List.exists T.claim_sites ~f:(fun p -> List.length p.T.cs_edges > 1)
        (* the bare-relation census excludes observations, so probe_lib —
           which records evidence rather than relating two parties — does
           not inflate it *)
        && List.for_all (T.bare_edges ()) ~f:(fun e -> not e.T.eg_observation))
  }

(* THE OVERVIEW PAGE'S SECTIONS ARE NUMBERED 1..n (2026-09-23). The page
   template numbers its sections by hand, and moving the agreement table
   in produced two sections called "3." — found by reading the page, not
   by any check. Reordering sections is now a thing the user asks for, so
   the numbering needs a guard rather than care. *)
let overview_sections_pin : Canary_project_test.pure_test =
  { name = "overview.sections_numbered_in_order";
    check =
      (fun () ->
        let path = "docs/canary/overview.html" in
        if not (Stdlib.Sys.file_exists path) then true (* not generated yet *)
        else
          let h =
            Stdlib.In_channel.with_open_text path Stdlib.In_channel.input_all
          in
          (* every "<h2 ...>N. " in document order *)
          let nums =
            let rec go i acc =
              match String.substr_index h ~pos:i ~pattern:"<h2" with
              | None -> List.rev acc
              | Some j -> (
                  match String.index_from h j '>' with
                  | None -> List.rev acc
                  | Some k ->
                      let rest = String.drop_prefix h (k + 1) in
                      let digits =
                        match String.lfindi rest ~f:(fun _ c -> not (Char.is_digit c)) with
                        | None -> rest
                        | Some n -> String.prefix rest n
                      in
                      let acc =
                        if String.is_empty digits then acc
                        else Int.of_string digits :: acc
                      in
                      go (k + 1) acc)
            in
            go 0 []
          in
          (not (List.is_empty nums))
          && List.equal Int.equal nums
               (List.init (List.length nums) ~f:(fun i -> i + 1)))
  }

let pm_gate_pin : Canary_project_test.pure_test =
  { name = "spec.pm_dep_gate_groups";
    check =
      (fun () ->
        let module BD = Canary_binding_decl in
        let gate_of pr lang mech =
          match
            Canary_project_run.binding_decl_of pr
              (Canary_artifact.a_binding lang mech)
          with
          | Some d -> d.BD.pm_gate
          | None -> None
        in
        let distro = Canary_basic.detect_distro () in
        let z3 = Canary_project_z3.z3_run distro in
        let llvm = Canary_project_llvm.llvm_run distro in
        let oc = Canary_lang.OCaml and py = Canary_lang.Python in
        (* (b) the measured groups *)
        let groups_ok =
          Poly.equal
            (gate_of Canary_project_sqlite.sqlite_run oc Canary_mechanism.Cstubs)
            (Some (BD.Free_with_conf "conf-sqlite3"))
          && Poly.equal
               (gate_of Canary_project_zarith.zarith_run oc
                  Canary_mechanism.Cstubs)
               (Some (BD.Free_with_conf "conf-gmp"))
          && Poly.equal
               (gate_of Canary_project_ssl.ssl_run oc Canary_mechanism.Cstubs)
               (Some (BD.Free_with_conf "conf-libssl"))
          (* cairo/libffi carry no binding_decl yet (the opam-binding
             template does not build one — the recorded "binding
             declarations 0/1" warning), so their gate lives on the
             template record, which is the opam-binding part itself *)
          && Poly.equal Canary_project_cairo.decl.Canary_opam_binding.pm_gate
               (BD.Free_with_conf "conf-cairo")
          && Poly.equal Canary_project_libffi.decl.Canary_opam_binding.pm_gate
               (BD.Bounded_with_conf
                  { conf = "conf-libffi";
                    lower = Some "2.0.0";
                    upper = None;
                    tracks_lib = false })
          && Poly.equal Canary_project_zarith.decl.Canary_opam_binding.pm_gate
               (BD.Free_with_conf "conf-gmp")
          (* zlib vs zstd: the pair that shows metadata alone is not
             enough. Both bindings declare a BARE conf dependency, so
             `opam show --field=depends` reads identical for the two. The
             conf packages do not: conf-zlib.1's build is `pkg-config
             zlib` (presence), conf-zstd.1.3.8's is
             `pkg-config --atleast-version=1.3.8 libzstd` (a floor that
             reaches the library). Declaring zstd Free_with_conf would be
             convenient and false — this pin is what stops that. *)
          && Poly.equal Canary_project_zlib.decl.Canary_opam_binding.pm_gate
               (BD.Free_with_conf "conf-zlib")
          && Poly.equal Canary_project_zstd.decl.Canary_opam_binding.pm_gate
               (BD.Bounded_with_conf
                  { conf = "conf-zstd";
                    lower = Some "1.3.8";
                    upper = None;
                    tracks_lib = true })
          (* …and the two therefore derive DIFFERENT freedoms, which is
             the whole point of tracks_lib *)
          && Poly.equal
               (BD.combination_freedom_of
                  Canary_project_zlib.decl.Canary_opam_binding.pm_gate)
               BD.Any_version
          && (match
                BD.combination_freedom_of
                  Canary_project_zstd.decl.Canary_opam_binding.pm_gate
              with
             | BD.Within_bound s -> String.is_substring s ~substring:"1.3.8"
             | _ -> false)
          && Poly.equal
               (gate_of llvm oc Canary_mechanism.Cstubs)
               (Some
                  (BD.Fixed_with_conf
                     { conf = "conf-llvm-shared"; version = "19" }))
          && Poly.equal
               (gate_of z3 oc Canary_mechanism.Cstubs)
               (Some BD.Package_builds_lib)
          && (match gate_of z3 py Canary_mechanism.Ctypes with
             | Some (BD.Bundled _) -> true
             | _ -> false)
          && (match gate_of llvm py Canary_mechanism.Ctypes with
             | Some (BD.Bundled _) -> true
             | _ -> false)
        in
        (* (c) the freedom derivation — the "how hard is the 2×2" answer *)
        let freedom_ok =
          Poly.equal
            (BD.combination_freedom_of (BD.Free_with_conf "conf-gmp"))
            BD.Any_version
          && Poly.equal
               (BD.combination_freedom_of
                  (BD.Fixed_with_conf
                     { conf = "conf-llvm-shared"; version = "19" }))
               (BD.Wrapper_needed "conf-llvm-shared")
          (* THE §G1a pin (2026-08-20). A version bound on a conf package
             reaches the LIBRARY only when that conf package's own check
             enforces a version — measured: 13 of 370 do, by a pkg-config
             predicate (8, floors) or the opam version variable fed to a
             script (5, generations). So the SAME range derives two
             different answers, and the discriminator is [tracks_lib]:

             - conf-libffi {>= "2.0.0"}: conf-libffi.2.0.0's build is a
               bare `pkg-config libffi`, the lib is 3.x → packaging only
               → [Any_version], exactly like conf-gmp;
             - conf-libclang {< "16"} (clangml): conf-libclang.N passes
               `version` to its configure.sh → a real bound on clang.

             Falsified before landing: flipping either flag flips the
             derived freedom, so this pin fails if the distinction is
             dropped or wired backwards. *)
          && Poly.equal
               (BD.combination_freedom_of
                  (BD.Bounded_with_conf
                     { conf = "conf-libffi";
                       lower = Some "2.0.0";
                       upper = None;
                       tracks_lib = false }))
               BD.Any_version
          && (match
                BD.combination_freedom_of
                  (BD.Bounded_with_conf
                     { conf = "conf-libclang";
                       lower = None;
                       upper = Some "16";
                       tracks_lib = true })
              with
             | BD.Within_bound s -> String.is_substring s ~substring:"16"
             | _ -> false)
          && Poly.equal
               (BD.combination_freedom_of BD.Package_builds_lib)
               BD.No_pairing
        in
        (* (a) no EXTERNAL project's declared binding is left ungated *)
        let all_gated =
          List.for_all Canary_registry.all_projects ~f:(fun (name, pr) ->
              if
                String.is_prefix name ~prefix:"tiny"
                (* in-tree witness: no package manager between the sides *)
              then true
              else
                List.for_all pr.Canary_project_run.pr_binding_decls
                  ~f:(fun d ->
                    (* CPython's stdlib extension has no PM gate either *)
                    Option.is_some d.BD.pm_gate
                    || Poly.equal d.BD.mechanism Canary_mechanism.Cext))
        in
        groups_ok && freedom_ok && all_gated) }

(* ONE MECHANISM PER LANGUAGE, WHICH EVERYTHING DOWNSTREAM ASSUMES
   (2026-09-17, user asking how an agreement's short code is handled and
   "how may it affect the cache or log").

   The overview repeats a claim's short code across rows because a row
   is a (lang, mech) PATTERN and the code names the AGREEMENT. That is
   safe only because nothing downstream keys on the code, and what
   disambiguates instead is always the step or the column:

     log     `<step tag> agreement_outcome (<slug>/<method>: <label>)` —
             the tag carries the language, the slug the claim
     matrix   a check column is (action, stage, code) and the action
             carries the language, so `build_binding_ocaml_pre:rse` and
             `probe_binding_python_pre:rse` are different columns; the
             worst-wins merge happens only WITHIN one
     cache    neither the code nor the agreement enters a fingerprint;
             verdict markers are per step, and two patterns are two steps

   THE MECHANISM IS RECOVERABLE, NOT RECORDED. Nothing writes it down:
   the log gives the language and the reader infers the mechanism from
   the project's spec. That inference is sound exactly while a project
   declares one mechanism per language — `an_mechanisms` is an assoc
   list and `List.Assoc.find` takes the first, so a second declaration
   for one language would be silently shadowed, and BOTH the log line
   and the matrix column would become ambiguous with nothing to say so.

   ⚠ AND IT IS ALREADY FALSE ONCE. tiny-full declares BOTH `Cext` and
   `Ctypes` for Python — deliberately, it is the witness project — and
   the consequences are exactly the ones above, today:

     * `Probe_binding of lang` carries no mechanism, so both bindings
       realize ONE `probe_binding_python` step. `emit tiny-full --stage
       realize` shows one, not two;
     * that step is one log tag and one matrix column, so an outcome
       cannot say which binding produced it;
     * `mechanism_for Python` returns the FIRST — Cext — so pass 2
       computes applicability for Cext alone and the Ctypes side is
       never asked.

   The artifact axis distinguishes the two (`a_binding Python Cext` vs
   `… Ctypes`); the ACTION axis does not, and that is the gap. Fixing it
   means a mechanism in the action vocabulary, which is a base/ change
   and not this pin's business.

   So tiny-full is a NAMED exception rather than a failure, and the pin
   is a ratchet: a second project doing this fails here, and adding to
   the list requires saying why. *)
let mechanism_collision_known : string list = [ "tiny-full" ]
let one_mechanism_per_language_pin : Canary_project_test.pure_test =
  { name = "analysis.one_mechanism_per_language";
    check =
      (fun () ->
        let bad =
          List.concat_map Canary_registry.all_projects ~f:(fun (name, pr) ->
              (* a decl carries a MECHANISM, and the language comes off
                 the catalogue — which is the same derivation
                 `an_mechanisms` does when it builds the assoc list this
                 pin protects *)
              let langs =
                List.map pr.Canary_project_run.pr_binding_decls ~f:(fun d ->
                    (Canary_mechanism.info_of_mechanism
                       d.Canary_binding_decl.mechanism)
                      .Canary_mechanism.mi_lang)
              in
              List.filter_map
                (List.dedup_and_sort langs ~compare:Poly.compare)
                ~f:(fun l ->
                  let n =
                    List.count langs ~f:(fun x -> Poly.equal x l)
                  in
                  if
                    n > 1
                    && not
                         (List.mem mechanism_collision_known name
                            ~equal:String.equal)
                  then
                    Some
                      (Printf.sprintf "%s declares %d mechanisms for %s" name n
                         (Canary_lang.string_of_lang l))
                  else None))
        in
        if not (List.is_empty bad) then
          List.iter bad ~f:(fun b ->
              Fmt.pr
                "    %s — the log records a language, not a mechanism, so \
                 its outcomes become ambiguous@."
                b);
        List.is_empty bad) }

(* THE MISMATCH MATRIX on z3 (2026-08-19, user: "for each artifact, either
   c lib or any binding, we need two choices, one stable and one latest").
   With the binding's channel freed from the lib's, each dev ref carries
   the 2×2. This pin states the four cells POSITIVELY — that they exist,
   which is the whole point of freeing the axis — and states what still
   couples:
   (a) per dev ref: a FORWARD cell (released lib × built binding) and a
       BACKWARD cell (built lib × released binding) both exist;
   (b) the both-released baseline exists exactly ONCE — it is
       ref-independent, since nothing is built from the source there;
   (c) cross-channel pairs DO survive (the inverse of the old lockstep);
   (d) a BUILT binding still matches its SOURCE's channel — you cannot
       build a dev binding from the stable tree ({!binding_couples}).
   The realizations those cells need are pinned separately
   ([z3.mismatch_cells_probe_their_own_world]). *)
let z3_mismatch_matrix_pin : Canary_project_test.pure_test =
  { name = "z3.mismatch_matrix_cells";
    check =
      (fun () ->
        let spec =
          Canary_project_spec.project_spec_of_rows
            Canary_project_z3.z3_artifacts
        in
        let asgs = enumerate_full spec in
        let oc = Canary_project_z3.z3_binding_art in
        let prov a id = Canary_enumerate.provision_of a id in
        let src_id a =
          (Canary_enumerate.version_of a Canary_artifact.a_source)
            .Canary_basic.id
        in
        let dev_refs = [ "latest"; "arbipher"; "pre-10549" ] in
        let cell ~lib_pv ~bind_pv ref_ =
          List.exists asgs ~f:(fun a ->
              String.equal (src_id a) ref_
              && Canary_artifact.equal_provision (prov a Canary_artifact.a_lib)
                   lib_pv
              && Canary_artifact.equal_provision (prov a oc) bind_pv)
        in
        (* (a) both cross cells, for every dev ref *)
        let cross_ok =
          List.for_all dev_refs ~f:(fun r ->
              cell ~lib_pv:Canary_artifact.Fetched ~bind_pv:Canary_artifact.Built
                r
              && cell ~lib_pv:Canary_artifact.Built
                   ~bind_pv:Canary_artifact.Fetched r)
        in
        (* (b) one both-released baseline, and none on a dev ref *)
        let baselines =
          List.filter asgs ~f:(fun a ->
              Canary_artifact.equal_provision (prov a Canary_artifact.a_lib)
                Canary_artifact.Fetched
              && Canary_artifact.equal_provision (prov a oc)
                   Canary_artifact.Fetched)
        in
        let baseline_ok =
          List.length baselines = 1
          && List.for_all baselines ~f:(fun a ->
                 not (List.mem dev_refs (src_id a) ~equal:String.equal))
        in
        (* (c) the lockstep is really gone *)
        let cross_channel_exists =
          List.exists asgs ~f:(fun a ->
              not
                (Canary_basic.equal_channel
                   (Canary_enumerate.channel_of a oc)
                   (Canary_enumerate.channel_of a Canary_artifact.a_lib)))
        in
        (* (d) what still couples: a built binding's source channel *)
        let source_coupled =
          List.for_all asgs ~f:(fun a ->
              (not
                 (Canary_artifact.equal_provision (prov a oc)
                    Canary_artifact.Built))
              || Canary_basic.equal_channel
                   (Canary_enumerate.channel_of a oc)
                   (Canary_enumerate.channel_of a Canary_artifact.a_source))
        in
        cross_ok && baseline_ok && cross_channel_exists && source_coupled) }

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
      (* 10 since the binding's channel pair (2026-08-19): the lib's 5
         placements (fetched + 2 built + 2 installed) × 2 opam pins — the
         2×2 the mismatch matrix wants, crossed with the staged faces *)
      let ok1 = check ~name:"sqlite" ~want_count:10
          Canary_project_sqlite.sqlite_run in
      (* 16 since the mismatch matrix (2026-08-19): per dev ref the 2×2's
         three ref-dependent cells plus the staged faces, and ONE
         both-released baseline (ref-independent). See z3_pins. *)
      let ok2 = check ~name:"z3" ~want_count:16
          (Canary_project_z3.z3_run (Canary_basic.detect_distro ())) in
      (* 3: 2 dev chains + the collapsed baseline — llvm's three
         all-Fetched worlds differed only in an unread source ref *)
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
      (* SUBSET, not equality (2026-08-21). A registry entry can be
         commented out to mute an expensive project — z3's full run is
         ~30 min because opam rebuilds libz3 on every binding pin flip
         (stage5_order_worlds.md §3). Equality made that a test failure, which
         would push someone to edit the pin instead of the registry.

         What is still caught: an UNKNOWN name (not in the catalogue) is
         an error, so a typo or an unregistered project still fails, and
         the catalogue is asserted to be a superset — so deleting a
         project outright means deleting it from the catalogue too, which
         is a visible act rather than a silent one. *)
      let names_ok =
        List.for_all names ~f:(fun n ->
            List.mem Canary_registry.catalogue n ~equal:String.equal)
      in
      if not names_ok then
        Fmt.pr "  registry names not in catalogue: [%s]@."
          (String.concat ~sep:", "
             (List.filter names ~f:(fun n ->
                  not (List.mem Canary_registry.catalogue n ~equal:String.equal))));
      let muted = Canary_registry.muted () in
      if not (List.is_empty muted) then
        Fmt.pr "  (muted: %s)@." (String.concat ~sep:", " muted);
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
              (* zarith's declared source is the BINDING's (2026-08-19) *)
              Canary_enumerate.version_of a (source_artifact_of pr)
            in
            (* 2 since the unread-source collapse (2026-08-19): the
               forward cell (binding built from master) + the both-released
               baseline; the third world had an unread master worktree
               (see repo_model.axes_pins) *)
            List.length asgs = 2
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
          ~bindings:TS.tiny_agreement_bindings
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
          (* the LOADER variable is per-platform (2026-08-26): these
             asserted [LD_LIBRARY_PATH] literally, which would have made
             a correct macOS template — dyld reads DYLD_LIBRARY_PATH and
             ignores the other — read as drift. What the pin is about is
             that the world's libdir reaches the probe, not what the
             variable is called here, so it asks [ld_only] the same
             question the template asks. *)
          ( str (BT.probe_binding_of cstubs ~ctx),
            Some
              (Printf.sprintf
                 "(LIBRARY_PATH=$PWD//WS/c/build LD_RUN_PATH=$PWD//WS/c/build dune build --root /WS ocaml/examples/probe_baseline.exe && %s /WS/_build/default/ocaml/examples/probe_baseline.exe) > /OUT/probe_VK.log 2>&1"
                 (Canary_basic.ld_only "$PWD//WS/c/build")) );
          ( str (BT.probe_binding_of cext ~ctx),
            Some
              (Printf.sprintf
                 "%s PYTHONPATH=/WS/python_cext python3 /WS/python_cext/examples/probe_baseline.py > /OUT/probe_VK.log 2>&1"
                 (Canary_basic.ld_only "$PWD//WS/c/build")) );
          (* probe_lib: nm for the declared prefix *)
          ( Some
              (BT.probe_lib_of TS.tiny_native
                 ~lib_path:"/WS/c/build/libtiny.so.1"
                 ~output_dir:"/OUT" ~variant_key:"VK"),
            Some
              (Printf.sprintf
                 "nm %s /WS/c/build/libtiny.so.1 | grep -E '^[0-9a-f]+ T %stiny_' > /OUT/probe_VK.log 2>&1"
                 (Canary_artifact_native.nm_dynamic_flag ())
                 (Canary_artifact_native.c_symbol_prefix ())) );
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
            && List.length r.items = 12
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
    (* [all_specs], not [all_projects] (2026-08-21): spec-check is a
       CHECKING pin, and muting a project removes it from the run set, not
       from the audit. A muted spec that rots would otherwise pass here by
       disappearing. *)
    let pr = List.Assoc.find_exn Canary_registry.all_specs name
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
     errors): no wrapper pkg, no python binding, no Built binding axis —
     and, since 2026-08-25, no BINDING PAIR. The last one is the 2×2's
     other half: the template hardcodes `versions = None` on the opam
     provider, so a pattern-A project can declare a lib pair (a prebuilt)
     but has no way to declare a second binding point. That is
     status_project §1 E, now said by the audit instead of by a note. *)
  let pat_warns =
    [ "binding_decls"; "binding_dev_source"; "binding_pair";
      "dev_wrapper_package"; "python_binding" ]
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
        (* ssl's binding_decls warn CLOSED 2026-08-19: declaring the decl
           gave its package-manager gate a home (spec.pm_dep_gate_groups),
           and closing the warn was the side effect *)
        (* ssl's lib_pair warn (2026-08-25): openssl HAS an obtainable
           pair (apt 3.0.13 vs conda-forge 4.0.1 — a major bump, measured
           in landing.md §3) and ssl declares one lib point. Unlike
           zarith's, this warn is a to-do, which is the distinction the
           printed rationale is there to carry. *)
        && want ~errs:[]
             ~warns:
               [ "binding_dev_source"; "dev_wrapper_package"; "lib_pair";
                 "python_binding" ]
             ~na:[ "raw_build_overrides" ] "ssl"
        (* C2.5 (2026-08-17): zarith's binding Built axis LANDED with the
           2×2 — binding_dev_source went Ok *)
        (* active plan 2 (2026-08-17): the wrapper declaration closed the
           dev_wrapper_package gap *)
        (* active plan 4 (2026-08-17): the binding decl (empty-prefix +
           full watchlist) closed binding_decls — python_binding stays
           (OCaml-only project, expected) *)
        (* zarith's lib_pair warn is PERMANENT and correct: GMP's newest
           release is three years old and apt already ships it, so the
           axis has one point as a fact about the world (landing.md §3).
           The row's rationale says so and the warn prints it.

           binding_dev_source joined it 2026-09-13, and it is NEW
           INFORMATION rather than a regression: zarith builds its
           binding from source and no binding_api says where that
           source is, so the source-scanning inspectors cannot run
           against it. The gap always existed; it was invisible while
           the runner never saw this project's api_source, and it used
           to be a [failwith] the moment it could. *)
        && want ~errs:[]
             ~warns:[ "binding_dev_source"; "lib_pair"; "python_binding" ]
             ~na:[] "zarith"
        && want ~errs:[] ~warns:pat_warns ~na:[ "raw_build_overrides" ] "cairo"
        && want ~errs:[] ~warns:pat_warns ~na:[ "raw_build_overrides" ] "libffi"
        (* zlib/zstd (landed 2026-08-20) join the ratchet here — they had
           never been pinned. Same shape as cairo/libffi: a prebuilt lib
           pair, no binding pair. *)
        && want ~errs:[] ~warns:pat_warns ~na:[ "raw_build_overrides" ] "zlib"
        && want ~errs:[] ~warns:pat_warns ~na:[ "raw_build_overrides" ] "zstd"
        (* tiny-full warns on BOTH axes — the in-tree witness enumerates
           one world (issues.md §1), and this is the audit finally saying
           so. It is exempt from the reporting-oriented checks, not from
           the 2×2 bar. *)
        && want ~errs:[]
             ~warns:[ "binding_dev_source"; "binding_pair";
                      "dev_wrapper_package"; "lib_pair" ]
             ~na:[ "github_remote"; "opam_package";
               "raw_build_overrides" ] "tiny-full") }

(* The batch tier (2026-08-14): Heavy = source-built chains (z3/llvm);
   [batch_policy] maps Heavy → thin (Subset[Stable] bypasses the Dev
   builds), Light → full. THE pin for the batch default config. *)
let batch_tier_pin : Canary_project_test.pure_test =
  { name = "registry.batch_tiers";
    check =
      (fun () ->
        (* the two Heavy projects are read from their SPECS, not from the
           registry (2026-08-21): a muted project is still a project, and
           its tier is exactly the property that says why muting it was
           tempting. Checking through the registry would make this pin
           evaporate the moment someone comments the entry out. *)
        let z3 = Canary_project_z3.z3_run (Canary_basic.detect_distro ()) in
        let llvm = Canary_project_llvm.llvm_run (Canary_basic.detect_distro ()) in
        let pr_of name =
          List.Assoc.find_exn Canary_registry.all_projects name
            ~equal:String.equal
        in
        let tier name = (pr_of name).Canary_project_run.pr_tier in
        Poly.equal z3.Canary_project_run.pr_tier Canary_project_run.Heavy
        && Poly.equal llvm.Canary_project_run.pr_tier Canary_project_run.Heavy
        (* the Light set is checked over whatever is ACTIVE — these are the
           cheap projects, so a muted one is a real signal, not a cost
           decision, and the subset check in registry.entries_enumerate
           already guards the names *)
        && List.for_all
             [ "sqlite"; "ssl"; "tiny-full"; "zarith"; "cairo"; "libffi" ]
             ~f:(fun n ->
               (not (Canary_registry.is_active n))
               || Poly.equal (tier n) Canary_project_run.Light)
        && Poly.equal (Canary_project_run.batch_policy z3)
             Canary_project_run.Thin
        && Poly.equal (Canary_project_run.batch_policy (pr_of "sqlite"))
             Canary_project_run.Full
        && Poly.equal (Canary_project_run.batch_policy llvm)
             Canary_project_run.Thin) }

(* The run-policy ladder's enumeration mapping (2026-08-17; the audit rung
   removed 2026-08-19, user): Full → the enumeration default (no policy
   override at all), Thin → the Subset[Stable] enumeration. Shadowing is
   unconditional now, so the ladder is purely a VERSION-subset ladder —
   there is no rung that changes what shadows what. *)
let shadow_policy_ladder_pin : Canary_project_test.pure_test =
  { name = "shadow.policy_ladder";
    check =
      (fun () ->
        let module EN = Canary_enumerate in
        let ep p =
          Canary_project_run.enumeration_policy_of
            { Canary_project_run.platform = Canary_store.platform ();
              policy = p; refs = EN.All_refs }
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
        (* Full needs no override — the enumeration default IS full *)
        Option.is_none (ep Canary_project_run.Full)
        && (match ep Canary_project_run.Thin with
            | None -> false
            | Some (p : unit EN.policy) ->
                Poly.equal p.EN.config.EN.version
                  (EN.Subset [ Canary_basic.Stable ]))
        (* and a refs-narrowed Full is still full in every other axis *)
        && full_like
             (Canary_project_run.enumeration_policy_of
                { Canary_project_run.platform = Canary_store.platform ();
                  policy = Canary_project_run.Full;
                  refs = EN.Refs [ "latest" ] })) }

(* The repo-model settings (2026-08-15, design/enumeration/stage1_declare_spec.md): the
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
                  ~universe:
                    [ ( Canary_store_config.Fetched
                          (Canary_store_config.Repo repo),
                        [ Canary_basic.Dev ] ) ]
                  () ];
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

(* THE PAIR CHECKS COUNT POINTS, NOT CELLS OR CHANNELS (2026-08-25).

   Falsification pin for status_project §2 item 0. The item says "counts
   admissible points on the lib row and warns below two", and there are
   three plausible readings of "point" that agree on every project except
   the two that matter:

     universe cells   — ssl's binding is ONE cell → wrongly Warn
     distinct channels— ssl's two pins are both @stable → wrongly Warn
     (provision, version) after pin expansion → Ok, which is right

   ssl and sqlite realize their binding pair as two opam store pins, the
   CHEAPEST way to declare one. A check that cannot see a pin would warn
   at exactly the projects doing it best. Case (b) is the same row minus
   the second pin, so a check that ignored pins entirely (always Ok on a
   Fetched cell) fails here too — both ways to be wrong are covered.

   Nothing else in the suite would catch this: the ratchet pins the
   CURRENT verdicts, so a wrong reading that was wrong from the start
   just gets recorded (issues.md §1's "the ratchet recorded the new
   number instead of contesting it"). *)
let pair_counts_points_pin : Canary_project_test.pure_test =
  { name = "spec_check.pair_counts_points";
    check =
      (fun () ->
        let sys_lib linux =
          Canary_store_config.Fetched
            (Canary_store_config.Sys_pkg
               { Canary_store.linux_pkg = linux; macos_pkg = linux;
                 version_tag = None; locator_hint = None;
                 behavior = Canary_store.Stateful_global })
        in
        let opam_binding versions =
          Canary_store_config.Fetched
            (Canary_store_config.Lang_pkg
               { lang = Canary_lang.OCaml; pm = Canary_store.Opam;
                 package = "p"; self_contained = false; versions })
        in
        let pin v =
          { Canary_store_config.pin_version = v; install_name = None }
        in
        let pr ~lib_universe ~binding_universe : Canary_project_run.project_run =
          { pr_name = "test-pair";
            pr_artifacts =
              [ Canary_project_spec.artifact_row
                  ~artifact:Canary_artifact.a_lib ~universe:lib_universe ();
                Canary_project_spec.artifact_row
                  ~artifact:
                    (Canary_artifact.a_binding Canary_lang.OCaml
                       Canary_mechanism.Cstubs)
                  ~universe:binding_universe () ];
            pr_runner_spec =
              (fun _a ~workspace:_ () -> Canary_step_builder.empty_runner_spec);
            pr_mismatch_probes = []; pr_wrapper_pkgs = []; pr_api_source = None;
            pr_binding_decls = []; pr_raw_build_overrides = [];
            pr_tier = Canary_project_run.Light }
        in
        let sev pr id =
          match
            List.find (Canary_spec_check.check pr).Canary_spec_check.items
              ~f:(fun i -> String.equal i.Canary_spec_check.item_id id)
          with
          | Some i -> Some i.Canary_spec_check.severity
          | None -> None
        in
        let one_lib = [ (sys_lib "libfoo-dev", [ Canary_basic.Stable ]) ] in
        (* (a) TWO STORE PINS, one cell, one channel — the ssl/sqlite
           shape. Ok is the answer a cell- or channel-count gets wrong. *)
        let a =
          pr ~lib_universe:one_lib
            ~binding_universe:
              [ (opam_binding (Some [ pin "0.6.0"; pin "0.7.0" ]),
                 [ Canary_basic.Stable ]) ]
        in
        (* (b) the same row with ONE pin — the falsifier for (a): a check
           that shrugged at Fetched cells would call this a pair too. *)
        let b =
          pr ~lib_universe:one_lib
            ~binding_universe:
              [ (opam_binding (Some [ pin "0.6.0" ]), [ Canary_basic.Stable ]) ]
        in
        (* (c) a two-CELL lib (apt + a prebuilt): the zlib/cairo shape,
           the other way a pair is declared. *)
        let c =
          pr
            ~lib_universe:
              (one_lib
              @ [ (Canary_store_config.Vendored_at "/prebuilt/lib",
                   [ Canary_basic.Dev ]) ])
            ~binding_universe:
              [ (opam_binding None, [ Canary_basic.Stable ]) ]
        in
        let open Canary_spec_check in
        Poly.equal (sev a "binding_pair") (Some Ok)
        && Poly.equal (sev a "lib_pair") (Some Warn)
        && Poly.equal (sev b "binding_pair") (Some Warn)
        && Poly.equal (sev c "lib_pair") (Some Ok)
        && Poly.equal (sev c "binding_pair") (Some Warn)) }

(* THE CANARY SWITCH (2026-08-26, user: "prepare another ocaml switch for
   all the canary experimenting").

   Canary installs and uninstalls opam packages as it runs, and a binding
   channel pair is realized by flipping a pin — which for zstd removes
   [ocaml-compiler] and recompiles 157 packages. Doing that to a person's
   working switch is why the binding axis sat blocked; canary therefore
   defaults to a switch of its own.

   Three properties, and the third is the one with teeth:

   1. the default is the MACHINE's default (2026-08-26 evening): the
      dedicated [canary] switch on the box that has one, ambient on the
      mac, which does not. What the pin holds is that the shipped default
      is not an accident — it is whatever [default_opam_switch] decides,
      so a person who forgets a flag gets the protection their machine
      was set up with;
   2. selecting none restores the pre-2026-08-26 behaviour EXACTLY (an
      empty prologue, so the emitted shell is byte-identical);
   3. the switch is part of the step fingerprint. A verdict earned in one
      switch says nothing about another, and serving it across a switch
      change is precisely the stale-hit class the fingerprint exists to
      close (landing.md §4). Falsified by construction: if the label were
      dropped from the digest the two hashes below would coincide. *)
let canary_switch_pin : Canary_project_test.pure_test =
  { name = "switch.selection";
    check =
      (fun () ->
        let saved = !Canary_store.opam_switch in
        let restore () = Canary_store.opam_switch := saved in
        let fingerprint_under sw =
          Canary_store.opam_switch := sw;
          let step : Canary_step_model.step =
            { tag = "probe"; output_tag = "o"; output_dir = "d";
              project_dir = "p"; variant_id = "v"; action = Canary_basic.Probe_lib;
              deps = []; cmd = (fun ~output_dir:_ ~variant_key:_ -> "echo hi");
              dep_dirs = [];
              check_post = (fun ~output_dir:_ ~variant_key:_ -> true);
              expectation = Canary_step_model.Expect_success; symbol_check = None;
              disabled_agreements = []; agreement_ctx = None; dummy = None;
              location = None; inspects = None }
          in
          Canary_local_runner.step_fingerprint step
        in
        (* (1) the shipped default is the machine's default — and on a
           box that HAS a dedicated switch, that default is it *)
        let machine_default = Lazy.force Canary_store.default_opam_switch in
        let default_is_machine_default =
          Poly.equal saved machine_default
          && (match machine_default with
              | Some s -> String.equal s "canary"
              | None -> true)
        in
        (* (2) no switch selected => empty prologue, byte-identical shell *)
        Canary_store.opam_switch := None;
        let ambient_prologue = String.equal (Canary_store.opam_switch_prologue ()) "" in
        (* and a selected one exports it *)
        Canary_store.opam_switch := Some "canary";
        let exports =
          String.is_substring (Canary_store.opam_switch_prologue ())
            ~substring:"OPAMSWITCH"
        in
        (* (3) the fingerprint separates the two worlds *)
        let f_canary = fingerprint_under (Some "canary") in
        let f_default = fingerprint_under (Some "default") in
        let f_ambient = fingerprint_under None in
        restore ();
        (* (4) THE TEST AXIS USES THE SAME PROLOGUE (2026-08-26). Both
           suites' shell cases run through [Canary_pm_test.run_test]; if
           it stopped applying the prologue the framework tests would go
           back to certifying the ambient toolchain while runs used
           canary's. Checked by construction: run_test must compose the
           prologue with the case's cmd. *)
        Canary_store.opam_switch := Some "canary";
        (* the probe must be one only the PROLOGUE can satisfy — `true`
           succeeds either way, which is how the first version of this
           check passed its own falsification. Asking the shell what
           OPAMSWITCH holds cannot. *)
        let case : Canary_pm_test.test_case =
          { name = "probe"; cmd = "test \"$OPAMSWITCH\" = canary";
            expected_rc = 0 }
        in
        let ran = Canary_pm_test.run_test case in
        let axis_ok = ran.Canary_pm_test.actual_rc = 0 in
        (* (5) AND SO DOES OCAML'S OWN SHELL-OUT (2026-08-26). A step's
           command is not the only thing canary runs: [pin_check_post] and
           [is_installed] ask a store what it holds, from OCaml, outside
           any step. Those were bare [Sys.command] and inherited a process
           environment with no OPAMSWITCH — so on WSL the sqlite pin check
           read `default` (5.4.1) while the fetch had installed 5.1.0 into
           `canary`: five scenarios red, and the other five green for the
           same wrong reason. Same falsification as (4): only the prologue
           can satisfy this probe. *)
        Canary_store.opam_switch := Some "canary";
        let ocaml_side_ok =
          Canary_store.sh_in_switch "test \"$OPAMSWITCH\" = canary" = 0
        in
        restore ();
        default_is_machine_default && ambient_prologue && exports && axis_ok
        && ocaml_side_ok
        && (not (String.equal f_canary f_default))
        && (not (String.equal f_canary f_ambient))) }

(* THE PLATFORM IS ONE VALUE (2026-08-26, user: "the canary config should
   carry the platform argument").

   Three modules used to sniff the machine independently —
   [Canary_basic.detect_distro] (uname), [Canary_store.detect_pm] (which
   brew / which apt-get) and [Canary_artifact_native.is_macos] (uname
   again) — and they could DISAGREE: [detect_pm] tried brew first, so a
   Linux box with Linuxbrew answered [Brew] against a [Wsl] distro, and
   [system_pkg_for_pm] would then pick the macOS package name on Linux.

   Four properties, and the second is the one that closes that hole:

   1. every consumer reports the SAME platform, override included — a
      [--platform] that reached the package names but not the nm flags
      would be worse than no override at all;
   2. the system PM is DERIVED from the platform, not sniffed beside it,
      so brew-on-Linux cannot be represented;
   3. the platform-dependent vocabulary actually moves with it (the
      loader variable and the nm flag are the two that decide whether a
      probe tests the world it names);
   4. it is part of the step fingerprint, so a verdict earned on one
      platform is never served to the other. Falsified by construction:
      drop the platform from the digest and the two hashes coincide. *)
let platform_single_source_pin : Canary_project_test.pure_test =
  { name = "platform.single_source";
    check =
      (fun () ->
        let saved = !Canary_store.platform_override in
        let restore () = Canary_store.platform_override := saved in
        let fingerprint_under d =
          Canary_store.set_platform d;
          let step : Canary_step_model.step =
            { tag = "probe"; output_tag = "o"; output_dir = "d";
              project_dir = "p"; variant_id = "v"; action = Canary_basic.Probe_lib;
              deps = []; cmd = (fun ~output_dir:_ ~variant_key:_ -> "echo hi");
              dep_dirs = [];
              check_post = (fun ~output_dir:_ ~variant_key:_ -> true);
              expectation = Canary_step_model.Expect_success; symbol_check = None;
              disabled_agreements = []; agreement_ctx = None; dummy = None;
              location = None; inspects = None }
          in
          Canary_local_runner.step_fingerprint step
        in
        (* (1) + (2) + (3), under each platform in turn *)
        let agrees_under d ~want_pm ~want_ld ~want_nm ~want_macos =
          Canary_store.set_platform d;
          Poly.equal (Canary_basic.detect_distro ()) d
          && Poly.equal (Canary_store.detect_pm ()) want_pm
          && String.equal (Canary_basic.ld_path_var ()) want_ld
          && String.equal (Canary_artifact_native.nm_dynamic_flag ()) want_nm
          && Bool.equal (Canary_artifact_native.is_macos ()) want_macos
        in
        let mac =
          agrees_under Canary_store.MacOS_local ~want_pm:Canary_store.Brew
            ~want_ld:"DYLD_LIBRARY_PATH" ~want_nm:"-g" ~want_macos:true
        in
        let wsl =
          agrees_under Canary_store.Wsl ~want_pm:Canary_store.Apt
            ~want_ld:"LD_LIBRARY_PATH" ~want_nm:"-D" ~want_macos:false
        in
        (* (4) the fingerprint separates the two *)
        let f_mac = fingerprint_under Canary_store.MacOS_local in
        let f_wsl = fingerprint_under Canary_store.Wsl in
        (* (5) THE DEFAULT SWITCH IS A FUNCTION OF THE PLATFORM
           (2026-08-26): the mac has no dedicated switch and runs
           ambient; the WSL box has [canary] and defaults to it. Pins the
           MAPPING, which is the falsifiable half — flip either row and
           this goes red.

           What is NOT pinned, deliberately: that [default_opam_switch]
           reads [detected_platform] rather than [platform ()], so a
           `--platform=macos` RENDER cannot repoint the store this
           machine installs into. That property is real and is why the
           code is written the way it is, but it is not observable — the
           lazy is forced at module init, before any override exists, so
           both spellings memoize the same answer. A test asserting it
           would pass either way, which is worse than no test. *)
        let mapping_ok =
          Poly.equal (Canary_store.default_switch_of Canary_store.MacOS_local) None
          && Poly.equal
               (Canary_store.default_switch_of Canary_store.Wsl)
               (Some "canary")
        in
        restore ();
        mac && wsl && mapping_ok
        && not (String.equal f_mac f_wsl)) }

(* STRICT MODE IS AN ARGUMENT OF THE INVOCATION (2026-09-15, user: "it's
   good during the development that the running shall fail fast for
   better debugging for ourself, rather than expected fails (xf)").

   Third flag of the [--switch] / [--platform] shape, and the same three
   things have to be true of it. What makes this one worth a pin of its
   own is that both directions are dangerous:

   1. IT IS OFF BY DEFAULT. Every landed project's steps accept "the
      command succeeded and the postcondition holds"; a violated
      agreement at a passing step is a finding about artifacts, not a
      broken step, and ssl's `dependencies_provided: violated
      libcrypto.so.3` is a real one that must not turn ssl red. If this
      row flips, ten projects change meaning at once and nothing else in
      the suite would say so;
   2. THE DEFAULT DIGEST DID NOT MOVE. Landing a fingerprint input
      normally costs one cold refresh of every step in every output tree
      (that is written down at [expectation_form]). This one must not,
      because the permissive question is exactly the question those
      markers already answered. Pinned as an EQUALITY against the digest
      spelled out longhand — appending a "lax" tag "for symmetry" would
      throw away every warm verdict on the box, silently;
   3. STRICT DOES separate it. A marker earned permissively answers a
      weaker question; serving it to a strict run would report PASS for
      a step that was never asked. Falsified by construction — drop the
      suffix and the two hashes coincide.

   NOT pinned here: that a violation actually fails the step. That is a
   claim about a real evaluation over real evidence, and the project's
   standard for it is a REAL project's log plus a deliberate break
   (agreement/agreements.md), not a synthetic [agreement_ctx] that would
   pass by agreeing with whatever the derivation happens to do today. *)
let strict_mode_pin : Canary_project_test.pure_test =
  { name = "strict.acceptance_policy";
    check =
      (fun () ->
        let saved = Canary_agreement_common.strict_mode () in
        let restore () = Canary_agreement_common.set_strict saved in
        let step : Canary_step_model.step =
          { tag = "probe"; output_tag = "o"; output_dir = "d";
            project_dir = "p"; variant_id = "v"; action = Canary_basic.Probe_lib;
            deps = []; cmd = (fun ~output_dir:_ ~variant_key:_ -> "echo hi");
            dep_dirs = [];
            check_post = (fun ~output_dir:_ ~variant_key:_ -> true);
            expectation = Canary_step_model.Expect_success; symbol_check = None;
            disabled_agreements = []; agreement_ctx = None; dummy = None;
              location = None; inspects = None }
        in
        let fingerprint_under b =
          Canary_agreement_common.set_strict b;
          Canary_local_runner.step_fingerprint step
        in
        (* (1) off unless the invocation says otherwise *)
        Canary_agreement_common.set_strict false;
        let default_is_permissive = not (Canary_agreement_common.strict_mode ()) in
        (* (2) the permissive digest is the pre-strict digest, longhand *)
        let f_lax = fingerprint_under false in
        let expected_lax =
          Stdlib.Digest.to_hex
            (Stdlib.Digest.string
               (step.cmd ~output_dir:step.output_dir ~variant_key:step.variant_id
               ^ "\x00" ^ "success" ^ "\x00"
               ^ Canary_store.opam_switch_label () ^ "\x00"
               ^ Canary_store.string_of_platform (Canary_store.platform ())))
        in
        (* (3) and strict is a different question *)
        let f_strict = fingerprint_under true in
        restore ();
        default_is_permissive
        && String.equal f_lax expected_lax
        && not (String.equal f_lax f_strict)) }

(* TWO WRITERS, ONE FILE — THE CLASH IS LOUD NOW (2026-09-15).

   Summaries reach a step by two routes. Most go through
   [attach_inspect], which already replaces a generated summary with an
   explicit one of the same base name. A [Native_lib_probe] does NOT:
   it appends its inspection to the probe's own command, so an explicit
   [inspect] for the same action became a SECOND step writing the same
   file into the same directory, and the last writer won.

   z3 paid for it in silence. Its three probe rows are world-aware — the
   PM library, the build tree, the staged prefix — and one override that
   resolved the library with `pkg-config` overwrote all three. Every
   recorded `probe_lib/inspect.json` in the project named the SYSTEM
   libz3, including the worlds that build their own, and
   `required_symbols_exported` was being decided against the wrong
   artifact. Nothing was missing, nothing failed; the file was simply
   another library's.

   The template now declares what it writes, and the step builder drops
   the override with a message rather than letting the two race. The
   TEMPLATE wins because its answer is derived from the world and the
   override's is hand-written — which is exactly the direction z3 proved.

   Pinned by construction: the same spec with and without the
   declaration differs by one step, so removing either half shows here. *)
let inspect_clash_pin : Canary_project_test.pure_test =
  { name = "steps.template_summary_beats_override";
    check =
      (fun () ->
        let module SB = Canary_step_builder in
        let probe ~output_dir:_ ~variant_key:_ = "true" in
        let override ~output_dir:_ ~variant_key:_ = "echo override" in
        let base =
          { SB.empty_runner_spec with
            probe_lib = [ (Canary_store.Build_tree, probe) ];
            inspect =
              (fun action _ ->
                match action with
                | Canary_basic.Probe_lib -> Some override
                | _ -> None) }
        in
        let steps_of spec =
          SB.derive_steps ~root:"_out/canary/test/no-such-run"
            ~project:"clash-test" ~langs:[ Canary_lang.OCaml ] spec
          |> List.map ~f:(fun (s : Canary_step_model.step) ->
                 s.Canary_step_model.tag)
        in
        (* WITHOUT the declaration the override is attached, as it has
           always been for a hand-written probe — that route stays open,
           because a project whose probe writes no summary still needs
           one *)
        let loose = steps_of base in
        let attached =
          List.exists loose ~f:(fun t -> String.is_substring t ~substring:"inspect")
        in
        (* WITH it, the override is dropped: the template already wrote
           that file and knows which library the world placed *)
        let tight =
          steps_of
            { base with
              template_summaries = [ (Canary_basic.Probe_lib, "inspect") ] }
        in
        let dropped =
          not
            (List.exists tight ~f:(fun t ->
                 String.is_substring t ~substring:"inspect"))
        in
        (* and nothing else moved *)
        let same_otherwise =
          List.length loose = List.length tight + 1
        in
        attached && dropped && same_otherwise) }

(* THE PRECONDITION IS CHECKABLE AT ALL (2026-09-21).

   [check_pre : unit -> bool] was a closure, and nothing pinned it in
   the years it existed — a closure can be called but not read, so a
   test could only re-run it and get the same answer it would give in
   production. Now it is [dep_dirs : string list] and there is something
   to assert. That is the smallest concrete argument for
   doc/canary/design/action_model.md §§4-5: making a check data makes it
   testable, transportable and renderable in one move, and this pin is
   the first of the three to arrive.

   WHAT IT ASSERTS is the CORRESPONDENCE: one resolved directory per
   dep, in the same order, each equal to that dep step's own
   [output_dir] when the dep is in the list. That is exactly the
   sentence the closure evaluated.

   WHAT IT DOES NOT ASSERT, stated because a pin that overclaims is
   worse than none: it cannot currently witness the RESOLUTION the
   rebind in [derive_steps] performs. That rebind exists because a dep's
   [output_dir] differs from its tag's directory when [output_tag] is
   set — and measured across the roster (2026-09-21), **nothing depends
   on a step that has an [output_tag]**. The steps that carry one are
   the attached inspectors (`build_lib_inspect` writes into `build_lib/`)
   and `scan_source`, and nothing lists any of them as a dep. So the
   map lookup and the tag-derived fallback agree everywhere today, and a
   revert to the fallback would not fire this pin.

   It still earns its place: it catches the realistic failure, which is
   a list that stops corresponding — a dep added without a directory, a
   truncation, a misalignment — and it starts firing on the resolution
   the moment any step depends on an inspector, which §9 step 4 makes
   likely, since deriving inspections from the join is precisely about
   giving those steps consumers. *)
let dep_dirs_pin : Canary_project_test.pure_test =
  { name = "steps.dep_dirs_correspond_to_deps";
    check =
      (fun () ->
        let module SM = Canary_step_model in
        let module SB = Canary_step_builder in
        let probe ~output_dir:_ ~variant_key:_ = "true" in
        let spec =
          { SB.empty_runner_spec with
            build_lib = Some probe;
            build_binding = [ (Canary_lang.OCaml, probe) ];
            probe_lib = [ (Canary_store.Build_tree, probe) ];
            probe_binding =
              [ (Canary_lang.OCaml, Canary_store.Build_tree, probe) ] }
        in
        let steps =
          SB.derive_steps ~root:"_out/canary/test/no-such-run"
            ~project:"dep-dirs-test"
            ~langs:[ Canary_lang.OCaml; Canary_lang.Python ] spec
        in
        let by_tag = Hashtbl.create (module String) in
        List.iter steps ~f:(fun (s : SM.step) ->
            Hashtbl.set by_tag ~key:s.SM.tag ~data:s.SM.output_dir);
        (* the list must be non-trivial, or the invariant below is
           vacuous and the pin would pass on an empty graph *)
        let saw_a_dep =
          List.exists steps ~f:(fun (s : SM.step) ->
              not (List.is_empty s.SM.deps))
        in
        let corresponds =
          List.for_all steps ~f:(fun (s : SM.step) ->
              List.length s.SM.deps = List.length s.SM.dep_dirs
              && List.for_all2_exn s.SM.deps s.SM.dep_dirs
                   ~f:(fun dep dir ->
                     (not (String.is_empty dir))
                     &&
                     match Hashtbl.find by_tag dep with
                     | Some out -> String.equal out dir
                     | None -> true (* dep filtered out by langs/spec *)))
        in
        if not (saw_a_dep && corresponds) then
          Fmt.pr
            "    steps.dep_dirs_correspond_to_deps: saw_a_dep=%b \
             corresponds=%b@."
            saw_a_dep corresponds;
        saw_a_dep && corresponds) }

(* BLAME IS A STATIC SCAN, AND IT HAS TO BE RIGHT TO BE WORTH COUNTING
   (2026-09-15, user: "before we fix that, can we attribute it as one
   thing to blame in the table, so we can see how eager we need to fix
   it").

   A check column exists only where the claim CAN be decided, so a
   non-verdict cell in one is a defect and the blame says whose. The
   number is meant to be a work queue, which means a wrong blame is
   worse than no blame — it either hides work or invents it. Both
   failure modes happened while this was being written, and both are
   pinned:

   1. EVERY PROJECT WAS VERSION-BLIND-FREE, because the first cut keyed
      version points on [build_id.id] — which is [""] for an unpinned
      placement ([Canary_basic.good]). sqlite's Built@Stable and
      Built@Dev collapsed to one point and nothing was ever flagged.
      Pinned on the pair that distinguishes: sqlite's lib genuinely
      moves (3.43.2 built, 3.46.1 built, apt's), zarith's genuinely does
      not (apt already ships GMP's newest — a permanently thin axis, and
      a single-valued declaration is CORRECT there).

   2. TEN PERMANENT ROWS ON THE WORK QUEUE, because [inconclusive] was
      blamed [declaration] whatever the comparison was. A DECLARATION
      comparison that reaches it found the declaration empty — a spec
      gap. A PEER comparison that reaches it read both artifacts and
      neither carried anything of this kind: sqlite's libsqlite3 has no
      symbol versioning, so [required_versions_exported] has nothing to
      compare and never will. That is [vacuous], and it is the one blame
      that asks for nothing.

   Also pinned: every word [blame_of] can produce is glossed. The gloss
   is what the key table and the terminal legend print, so an unglossed
   word would reach a reader as a bare noun. *)
let blame_attribution_pin : Canary_project_test.pure_test =
  { name = "matrix.blame_is_static_and_glossed";
    check =
      (fun () ->
        let points name =
          match
            List.Assoc.find Canary_registry.all_projects name
              ~equal:String.equal
          with
          | None -> 0
          | Some pr ->
              Canary_matrix.version_points_of_kind
                (Canary_project_run.scenarios_of pr)
                Canary_basic.Lib
        in
        (* (1) a moving axis is seen as moving, a thin one as thin *)
        let sqlite_moves = points "sqlite" > 1 in
        let zarith_is_thin = points "zarith" = 1 in
        (* (2) inconclusive splits on the reference kind *)
        let peer_is_vacuous =
          Poly.equal
            (Canary_matrix.blame_of ~outcome:"inconclusive"
               ~is_declaration:false ~version_blind:false)
            (Some "vacuous")
        in
        let decl_is_spec =
          Poly.equal
            (Canary_matrix.blame_of ~outcome:"inconclusive"
               ~is_declaration:true ~version_blind:false)
            (Some "declaration")
        in
        (* a VIOLATION is a finding, not a defect — unless the
           declaration it contradicts cannot follow the version *)
        let plain_violation_is_a_finding =
          Poly.equal
            (Canary_matrix.blame_of ~outcome:"violated" ~is_declaration:true
               ~version_blind:false)
            None
        in
        let blind_violation_is_suspect =
          Poly.equal
            (Canary_matrix.blame_of ~outcome:"violated" ~is_declaration:true
               ~version_blind:true)
            (Some "version")
        in
        (* a passing cell blames nothing, whatever its shape *)
        let holds_blames_nothing =
          List.for_all [ true; false ] ~f:(fun d ->
              List.for_all [ true; false ] ~f:(fun v ->
                  Option.is_none
                    (Canary_matrix.blame_of ~outcome:"holds"
                       ~is_declaration:d ~version_blind:v)))
        in
        (* (3) nothing reaches a reader unglossed *)
        let all_glossed =
          List.for_all
            [ "holds"; "violated"; "error"; "inconclusive"; "unavailable";
              "not_applicable"; "not_implemented"; "disabled"; "" ]
            ~f:(fun outcome ->
              List.for_all [ true; false ] ~f:(fun d ->
                  List.for_all [ true; false ] ~f:(fun v ->
                      match
                        Canary_matrix.blame_of ~outcome ~is_declaration:d
                          ~version_blind:v
                      with
                      | None -> true
                      | Some b ->
                          List.Assoc.mem Canary_matrix.blame_gloss b
                            ~equal:String.equal)))
        in
        sqlite_moves && zarith_is_thin && peer_is_vacuous && decl_is_spec
        && plain_violation_is_a_finding && blind_violation_is_suspect
        && holds_blames_nothing && all_glossed) }

(* THE CHECKING INDEX IS ASKED IN EACH ACTION'S OWN LANGUAGE
   (2026-09-15).

   [canary checks <project>] used to compute the WHOLE index with "the
   project's first declared binding". So sqlite's index was OCaml
   throughout and reported that nothing fires at [probe_binding_python]
   — while the same project's result table carried five Python check
   columns and its own run log decided [api_names_present] on that very
   step six times. Three views of one project, two answers, and the
   wrong one understated coverage, which is the direction nobody
   notices.

   Two properties, and each was a separate defect:

   1. an action that NAMES a language carries the agreements that fire
      for THAT language. Pinned on the concrete fact that made it
      visible — sqlite's Python probe carries [api_names_present], which
      is landed there and has the log to prove it. Revert the per-action
      language and this cell goes empty;
   2. no cell claims an agreement the language cannot carry. The index
      skipped the applicability filter the result table already applied,
      so it listed [signatures_agree] at a Python probe, where the
      mechanism declares its types as values and there are no stub
      signatures to read — a cell that could never say anything, counted
      as coverage.

   NOT pinned: that the index and the result table's check columns name
   the same cells. They do not, and the difference is by design rather
   than by drift — a column comes from the agreement's SLOT resolved
   against the chain (world-blind: the claim BELONGS at that action),
   an index cell from the method's FIRING in an actual world. llvm
   derives an [install_lib] step, no llvm world is [Installed], so
   [staged_interface_preserved] slots there and fires nowhere, and
   `canary result llvm` carries an [install_lib_post:sip] column that no
   llvm world can fill. That is a real observation about the result
   table and it is written down in issues rather than pinned here —
   pinning a containment that is false would only teach the next person
   to weaken it. *)
let check_index_language_pin : Canary_project_test.pure_test =
  { name = "checks.index_speaks_each_action_language";
    check =
      (fun () ->
        (* a root nothing has written to: the index's third column reads
           run logs, and this pin is about the first two *)
        let root = "_out/canary/test/no-such-run" in
        let cells_of pr =
          Canary_check_index.of_project ~root pr
          |> List.concat_map ~f:(fun (_, es) -> es)
          |> List.concat_map ~f:(fun (e : Canary_check_index.entry) ->
                 List.map e.Canary_check_index.en_added
                   ~f:(fun (a : Canary_check_index.added) ->
                     (e.Canary_check_index.en_action, a)))
        in
        (* (1) sqlite's Python probe carries the agreement that is
           landed there *)
        let sqlite_python_anp =
          match List.Assoc.find Canary_registry.all_projects "sqlite"
                  ~equal:String.equal with
          | None -> false
          | Some pr ->
              List.exists (cells_of pr) ~f:(fun (act, a) ->
                  Poly.equal act (Canary_basic.Probe_binding Canary_lang.Python)
                  && String.equal a.Canary_check_index.ad_slug
                       "api_names_present")
        in
        (* (2) no cell claims what its language cannot carry — asked of
           every project, since the filter is generic *)
        let no_unsuited_cell =
          List.for_all Canary_registry.all_projects ~f:(fun (_, pr) ->
              let declared = Canary_pipeline.declared_api_of pr in
              List.for_all (cells_of pr) ~f:(fun (act, a) ->
                  match act with
                  | Canary_basic.Build_binding l
                  | Canary_basic.Probe_binding l
                  | Canary_basic.Fetch (Canary_basic.Binding l)
                  | Canary_basic.Build_app { lang = l } ->
                      let mech = Canary_pipeline.mechanism_of_project pr l in
                      not
                        (List.exists
                           (Canary_agreement.unsuited_here ~mechanism:mech ~lang:l
                              ~declared)
                           ~f:(fun (u : Canary_agreement.unsuited) ->
                             String.equal u.Canary_agreement.us_slug
                               a.Canary_check_index.ad_slug))
                  | _ -> true))
        in
        sqlite_python_anp && no_unsuited_cell) }

(* ONE APPLICABILITY ANSWER, AND IT IS PASS 2's (2026-09-16).

   [checks.index_speaks_each_action_language] above pins one INSTANCE of
   the class — the index must not claim what a language cannot carry.
   This pins the class's cause: both views used to build their own
   [(mechanism, declared)] pair on the way into [suits_here], and the
   result table's was the LANGUAGE DEFAULT while the index's was the
   project's DECLARATION. Wherever those differ the two views answer
   different questions, and nothing said which was right.

   z3 is where they differ, and it is why this pin names a project.
   z3 declares its Python binding as Ctypes; Python's default is Cext;
   and applicability genuinely turns on the difference — Ctypes compiles
   no stub archive, so [required_symbols_exported] has nothing to read,
   while Cext's extension module does. So:

     pass 2 (declaration) says NOT carried
     the language default says carried

   and the pin asserts the first. Nothing in today's OUTPUT moves either
   way, because no z3 world derives a Python step and z3 is muted — this
   is the divergence caught BEFORE it fired, which is the only time it
   is cheap. *)
let applicability_reads_declaration_pin : Canary_project_test.pure_test =
  { name = "checks.applicability_reads_the_declaration";
    check =
      (fun () ->
        match
          List.Assoc.find Canary_registry.all_specs "z3" ~equal:String.equal
        with
        | None -> false
        | Some pr ->
            let an = Canary_pipeline.analysed_of pr in
            let declared_is_ctypes =
              Poly.equal
                (Canary_project_analysis.mechanism_for an Canary_lang.Python)
                Canary_mechanism.Ctypes
            in
            let slug = "required_symbols_exported" in
            (* what pass 2 says, reading the declaration *)
            let by_declaration =
              Canary_project_analysis.carries an ~lang:Canary_lang.Python slug
            in
            (* what the language default would have said — the answer the
               result table used to compute for itself *)
            let by_default =
              List.mem
                (Canary_project_analysis.carried_slugs
                   ~mechanism:
                     (Canary_mechanism.mechanism_of_lang_exn Canary_lang.Python)
                   ~lang:Canary_lang.Python
                   ~declared:an.Canary_project_analysis.an_declared)
                slug ~equal:String.equal
            in
            declared_is_ctypes && (not by_declaration) && by_default) }

(* THE ACTION × DECLARATION JOIN (2026-09-16, user) — three claims, and
   the third is the one a hook will stand on.

   (a) TOTAL over the declarations. Every artifact a project declares is
   touched by at least one action in the catalogue. A declared artifact
   no action reaches is unreachable: nothing can fetch it, build it,
   consume it or check it, and the spec is describing something outside
   canary's model. This is the invariant that would fire first if a new
   `artifact_kind` were declared before the catalogue learned about it.

   (b) A PROBE PRODUCES NOTHING. `produced_at` is empty for every
   `Probe_*`, which is `produces_of_action`'s claim restated in the
   project's own vocabulary. It matters because a probe is where three
   roles are currently fused (existence, inspection, execution — see
   `probe_lib`'s survey), and the typed fact that it creates nothing is
   why a probe cannot be where an artifact's evidence is FIRST recorded,
   whatever a tag map currently says.

   (c) A LIB HAS SEVERAL PRODUCERS, and that is the point of the join
   rather than a defect in it. `build_lib` in a Built world, `fetch_lib`
   in a Fetched one, `install_lib` in an Installed one — all produce the
   same declared artifact. A hook that wants a lib inspection should
   attach at whichever of them this world runs, which is exactly the
   "from the invoking side" the action model asks for. *)
let touches_join_pin : Canary_project_test.pure_test =
  { name = "analysis.touches_joins_actions_to_declarations";
    check =
      (fun () ->
        let module A = Canary_project_analysis in
        List.for_all Canary_registry.all_specs ~f:(fun (_, pr) ->
            let an = Canary_pipeline.analysed_of pr in
            let id_str = Canary_artifact.string_of_id in
            let touched =
              List.concat_map an.A.an_touches ~f:(fun (_, tc) ->
                  List.map (tc.A.tc_consumes @ tc.A.tc_produces) ~f:id_str)
            in
            (* (a) *)
            let total =
              List.for_all
                (Canary_artifact.ps_artifacts an.A.an_spec)
                ~f:(fun i ->
                  List.mem touched (id_str i) ~equal:String.equal)
            in
            (* (b) *)
            let probes_produce_nothing =
              List.for_all an.A.an_touches ~f:(fun (act, _) ->
                  match act with
                  | Canary_basic.Probe_lib | Canary_basic.Probe_binding _
                  | Canary_basic.Probe_app _ ->
                      List.is_empty (A.produced_at an act)
                  | _ -> true)
            in
            (* (c) — asked of the lib every project declares *)
            let lib_has_producers =
              match
                List.find (Canary_artifact.ps_artifacts an.A.an_spec)
                  ~f:(fun i ->
                    Poly.equal (Canary_artifact.kind_of i) Canary_basic.Lib)
              with
              | None -> true (* a project with no lib declares nothing here *)
              | Some lib -> List.length (A.producers_of an lib) > 1
            in
            total && probes_produce_nothing && lib_has_producers)) }

(* THE GH RENDERING MUST AGREE WITH THE EXPECTATION'S POLARITY
   (2026-08-28).

   [Expect_compat_derived] computes its own polarity — a prediction means
   the step must fail, NO prediction means the artifact is good and the
   step must SUCCEED. The GH backend rendered it like the ORACLE variant
   ([Expect_compat_failure]), which always expects a failure, so a step
   the local runner expects to pass became a continue-on-error + verify
   pair asserting the opposite. ssl's first CI job said so:

     FAIL: expected failure but step succeeded

   on [probe_binding_ocaml], whose red cell locally is not there at all —
   it sits on [probe_app_ocaml]. A CI backend that disagrees with the
   runner about WHICH step is red is worse than one that does not run. *)
let gh_derived_polarity_pin : Canary_project_test.pure_test =
  { name = "gh.derived_expectation_polarity";
    check =
      (fun () ->
        let step_with exp : Canary_step_model.step =
          { tag = "probe_binding_ocaml"; output_tag = "probe_binding_ocaml";
            output_dir = "d"; project_dir = "p"; variant_id = "v";
            action = Canary_basic.Probe_binding Canary_lang.OCaml; deps = [];
            cmd = (fun ~output_dir:_ ~variant_key:_ -> "run it");
            dep_dirs = [];
            check_post = (fun ~output_dir:_ ~variant_key:_ -> true);
            expectation = exp; symbol_check = None; disabled_agreements = [];
            agreement_ctx = None; dummy = None;
              location = None; inspects = None }
        in
        let rendered exp =
          String.concat ~sep:"\n"
            (Canary_gh.render_gh_step ~project:"x" (step_with exp))
        in
        let has_verify r = String.is_substring r ~substring:"(verify)" in
        (* no prediction: DERIVED must render as a plain step, the ORACLE
           must still assert a failure — the project declared one *)
        let derived_empty =
          rendered (Canary_step_model.Expect_compat_derived { inputs = []; version_info = None })
        and oracle_empty =
          rendered (Canary_step_model.Expect_compat_failure { inputs = []; version_info = None })
        in
        (not (has_verify derived_empty))
        && has_verify oracle_empty
        (* and a plain success is never a failure check *)
        && not (has_verify (rendered Canary_step_model.Expect_success))
        (* THE VERIFY MUST GREP THE LOG THE STEP WRITES (2026-08-28).
           It grepped a bare "probe.log", which existed only while CI ran
           one chain per project with an EMPTY variant key. A
           pipeline-rendered job has a real key, so every expected-failure
           verify grepped a file that does not exist and reported
           "expected message not found" — ssl's app probe, red for
           failing exactly as predicted. *)
        && (let with_strings =
              rendered
                (Canary_step_model.Expect_failure
                   { contains_any = [ "boom" ]; version_info = None })
            in
            String.is_substring with_strings
              ~substring:(Canary_basic.variant_file ~variant_key:"v" "probe.log")
            && not (String.is_substring with_strings ~substring:"/probe.log\""))) }

(* PREPARE ONCE, ENSURE PER WORLD (2026-08-28, user: "in one canary run
   ... we can assume the stable/latest is fixed ... the first request
   check the local then asked the remote").

   The checkout is SHARED — [<contrib>/<project>-all/<repo>] carries no
   scenario — but the marker is per-world, so N worlds at one ref used to
   run N `git fetch`es to converge on a tree that was already right
   (1.1s each, measured on cairo). The remote half is now guarded by a
   sentinel stamped with [$CANARY_RUN_ID]; the local half is not.

   Measured on the emitted shell: 0.317s cold, 0.004s for the next world
   in the same run, 0.278s again under a new run id — so a moving ref
   still refreshes once per run rather than never.

   This pin is a SHAPE check and says so: it asserts where the guard sits,
   not that the second invocation is fast. What makes it more than
   decoration is the polarity — the clone must be INSIDE the guard and the
   marker write OUTSIDE it. Swap either and a world either re-fetches or
   never records its own evidence. *)
let source_refresh_scope_pin : Canary_project_test.pure_test =
  { name = "source.refresh_is_run_scoped";
    check =
      (fun () ->
        let cmd =
          Canary_artifact_source.worktree_ensure_cmd ~project:"p"
            ~repo:
              { Canary_artifact_source.name = "r";
                remote = Some (Canary_artifact_source.Git "https://example/r.git");
                locals = Canary_artifact_source.mk_locals "contrib/r-all/r";
                version = Canary_basic.{ channel = Stable; id = "1" };
                ref_ = "v1"; official = true; build_sys_deps = [];
                api_source = None; label = None; artifacts = [] }
            ~ref_:"v1" ~output_dir:"OUT" ~variant_key:"" ()
        in
        let idx sub = String.substr_index cmd ~pattern:sub in
        match (idx "CANARY_RUN_ID", idx "git clone", idx "> OUT/") with
        | Some run_id, Some clone, Some marker ->
            (* the guard is stamped with the run, and the clone sits
               inside it *)
            run_id < clone
            (* the marker — this world's own evidence — is written after
               and outside the guarded block, so every world records it
               whether or not it did the remote work *)
            && clone < marker
            && String.is_substring cmd ~substring:"if [ ! -e \"$SENTINEL\" ]"
        | _ -> false) }

(* DEMAND, NOT DECLARATION ([design/enumeration/stage6_realize_steps.md]
   §3b).

     Declaration makes an action available; dependency makes it necessary.

   [derive_steps] realizes every action a project declares, so cairo's
   all-Fetched world cloned a repository whose tree no later step read.
   [drop_unread_fetches] asks one question per fetch — does any step in
   this world CONSUME what it produces? — against the typed catalogue
   ([consumes_of_action], pinned by [consumes_produces.*]), not against
   [step.deps].

   The pin is the PAIR, because either half alone is satisfiable by a
   broken rule: prune everything and cairo passes; prune nothing and
   sqlite passes. Only both together say the rule is about demand. *)
let demand_prune_pin : Canary_project_test.pure_test =
  { name = "derive.steps_are_demanded";
    check =
      (fun () ->
        let tags_of pr a =
          let ctx = Canary_pipeline.ctx_of pr a in
          List.map
            (Canary_pipeline.steps_of ~root:"_out/canary" pr ~ctx a)
            ~f:(fun s -> s.Canary_step_model.tag)
        in
        let has ts t = List.mem ts t ~equal:String.equal in
        (* (1) cairo's world is all-Fetched: nothing consumes the source,
           so no fetch_source — and the checks themselves survive, which
           is what says the rule pruned rather than emptied. *)
        let cairo_ok =
          match Canary_pipeline.ordered Canary_project_cairo.cairo_run with
          | [] -> false
          | a :: _ ->
              let ts = tags_of Canary_project_cairo.cairo_run a in
              (not (has ts "fetch_source"))
              && has ts "probe_lib"
              && has ts "probe_binding_ocaml"
              (* evidence hanging off a probe is kept, not pruned as a
                 leaf with no dependents of its own *)
              && has ts "probe_lib_inspect"
        (* (2) sqlite has a world whose lib is BUILT from that source, and
           there the very same rule must KEEP the fetch — build_lib
           depends on it. A rule that drops it fails here. *)
        and sqlite_ok =
          let pr = Canary_project_sqlite.sqlite_run in
          let built =
            List.filter_map (Canary_pipeline.ordered pr) ~f:(fun a ->
                let ts = tags_of pr a in
                if has ts "build_lib" then Some ts else None)
          in
          (not (List.is_empty built))
          && List.for_all built ~f:(fun ts -> has ts "fetch_source")
        in
        cairo_ok && sqlite_ok) }

(* IS THE ENUMERATION PLATFORM-AGNOSTIC? (2026-08-26, user: "how about
   the platform affecting the enumeration? it should be agnostic until
   the runner, but can we confirm that?")

   [platform.md] §2b asserts passes 1–4 never see the platform and only
   pass 5 + the tool wrappers do. This turns the assertion into a
   measurement: run each pass under BOTH platforms and compare.

   The trap this pin has to avoid is being vacuous. "Identical under both
   platforms" is also what you get if the override reaches nothing at
   all — a spec frozen at module init compares equal to itself. So the
   pin asserts BOTH directions: passes 1–4 identical, AND a realized
   command that genuinely changes. Without the second half the first
   half proves nothing.

   WHAT IS COMPARED, stated exactly, because the first falsification of
   this pin slipped through it: the snapshot is the WORLD SET and its
   order — which artifacts exist, at which provisions, at which versions,
   which of those a run selects, and in what sequence. It is not the
   realization data hanging off a declaration: making the [Vendored_at]
   payload platform-dependent does NOT turn this red, because
   [json_declare] reports the provision, not its origin string. That is
   the right scope — an origin string is what pass 5 resolves, and pass 5
   is allowed to know the platform — but it means this pin says "both
   machines enumerate the same worlds", not "nothing downstream of a
   declaration mentions a platform".

   Falsified by making the world set itself depend on the platform (drop
   the Dev version point on macOS in the Pattern-A lib row): red, as it
   must be. *)
let platform_enumeration_pin : Canary_project_test.pure_test =
  { name = "platform.enumeration_is_agnostic";
    check =
      (fun () ->
        let saved = !Canary_store.platform_override in
        let restore () = Canary_store.platform_override := saved in
        let under d f = Canary_store.set_platform d; f () in
        let js x = Yojson.Basic.to_string x in
        (* passes 1 (declare), 2 (enumerate), 3 (select) and 4 (order),
           for every CATALOGUED project — a muted one still has a spec,
           and a spec that reads the platform is a spec that would make
           the two machines enumerate different worlds and stop being
           comparable, which is the whole point of running both. *)
        let snapshot d pr =
          under d (fun () ->
              js (Canary_pipeline.json_declare pr)
              ^ js
                  (`List
                    (List.map (Canary_pipeline.worlds pr)
                       ~f:Canary_pipeline.json_of_assignment))
              ^ js
                  (`List
                    (List.map
                       (Canary_pipeline.enumerated pr)
                       ~f:Canary_pipeline.json_of_assignment))
              ^ js (Canary_pipeline.json_order pr))
        in
        let invariant =
          List.for_all Canary_registry.all_specs ~f:(fun (_n, pr) ->
              String.equal
                (snapshot Canary_store.Wsl pr)
                (snapshot Canary_store.MacOS_local pr))
        in
        (* NON-VACUITY: the override must reach pass 5. sqlite is the
           witness — its lib comes from the system PM, so the realized
           step set carries [probe_lib_apt] on one platform and
           [probe_lib_brew] on the other. If this ever holds equal, the
           override stopped reaching the runner and the invariant above
           became a tautology.

           [steps_of] is not pure for every project (tiny-full
           materializes a tree), so the witness is a project whose
           realization only builds strings. *)
        let realized d pr =
          under d (fun () ->
              let a = List.hd_exn (Canary_pipeline.ordered pr) in
              let ctx = Canary_pipeline.ctx_of pr a in
              List.map (Canary_pipeline.steps_of ~root:"_out/canary" pr ~ctx a)
                ~f:(fun s ->
                  s.Canary_step_model.tag ^ "\n"
                  ^ s.Canary_step_model.cmd ~output_dir:"D" ~variant_key:"V")
              |> String.concat ~sep:"\n")
        in
        (* AND THE SPEC REBUILT UNDER EACH PLATFORM. The check above
           re-runs the passes over one already-constructed [project_run],
           so it catches a pass that READS the platform — but not a spec
           that BAKED it in while the module initialized. A frozen spec
           compares equal to itself, which is the same vacuity trap in a
           second costume, and the registry makes it concrete: it hands
           [z3_run]/[llvm_run] a literal [Wsl], so if their declaration
           honoured that argument nothing above would notice.

           So rebuild the declaration under each platform — argument AND
           ambient override — and compare. Covers the seven projects that
           expose a builder, including every prebuilt-bearing one (the
           tempting place to resolve a machine path). sqlite, tiny-full
           and ssl are eager values with no builder to call; they are
           covered by the weaker check only. *)
        let rebuilt_invariant =
          let cmp build =
            String.equal
              (under Canary_store.Wsl (fun () -> snapshot Canary_store.Wsl (build Canary_store.Wsl)))
              (under Canary_store.MacOS_local (fun () ->
                   snapshot Canary_store.MacOS_local (build Canary_store.MacOS_local)))
          in
          (* the two that TAKE a distro — the registry's claim that they
             ignore it, asserted instead of documented *)
          cmp (fun d -> Canary_project_z3.z3_run d)
          && cmp (fun d -> Canary_project_llvm.llvm_run d)
          (* Pattern A: the template builds the whole declaration *)
          && List.for_all
               [ Canary_project_zlib.decl; Canary_project_cairo.decl;
                 Canary_project_libffi.decl; Canary_project_zstd.decl ]
               ~f:(fun decl -> cmp (fun _ -> Canary_opam_binding.run decl))
        in
        let sqlite = Canary_project_sqlite.sqlite_run in
        let pass5_varies =
          not
            (String.equal
               (realized Canary_store.Wsl sqlite)
               (realized Canary_store.MacOS_local sqlite))
        in
        restore ();
        invariant && rebuilt_invariant && pass5_varies) }

(* THE MACHINE ROOTS ARE ENTRY CONFIG (2026-08-26, user: "this can be
   almost hardcoded in the entry side once as the config value choice for
   two of my machines. It shouldn't be hardcoded any more").

   [distro_base] used to BE the two absolute paths. It is now a lookup
   into a table the entry declares, which is only possible because
   nothing resolves a root while modules initialize — the property (3)
   below is what makes the whole arrangement work, and it is the one that
   will silently regress: the natural way to write a project declaration
   is to call [libdir_of pb (detect_distro ())] in it, which puts an
   absolute path in a top-level [let] and re-freezes the paths at load. *)
let machine_roots_pin : Canary_project_test.pure_test =
  { name = "machine_roots.declared_at_entry";
    check =
      (fun () ->
        let saved = !Canary_store.machine_roots in
        let restore () = Canary_store.machine_roots := saved in
        (* (1) the lookup answers for BOTH machines — the cross-render
           needs the other one, which no $HOME could supply *)
        Canary_store.set_machine_roots
          [ (Canary_store.Wsl, "/w"); (Canary_store.MacOS_local, "/m") ];
        let resolves =
          String.equal (Canary_store.distro_base Canary_store.Wsl) "/w"
          && String.equal (Canary_store.distro_base Canary_store.MacOS_local) "/m"
          && String.equal (Canary_store.contrib_root Canary_store.Wsl) "/w/contrib"
        in
        (* (2) undeclared is a FAILURE, not a guess — a fabricated root
           would send a build somewhere real and wrong *)
        Canary_store.machine_roots := [];
        let refuses =
          try
            ignore (Canary_store.distro_base Canary_store.Wsl : string);
            false
          with _ -> true
        in
        (* (3) A DECLARATION NEEDS NO ROOT. Built with the table empty:
           if any part of stating what a project HAS reaches for a machine
           path, this raises — which is exactly what happened at module
           init before the paths were made relative. zlib is the witness
           because it declares a prebuilt (a Vendored lib whose libdir is
           the tempting place to resolve).

           How the regression actually shows up, measured by putting
           [libdir_of pb (detect_distro ())] back into the artifact table:
           for a spec that is a top-level [let] the binary dies at
           STARTUP, before any test runs, with [distro_base]'s message
           naming the fix — louder than a red pin. This claim covers the
           case that death does not: a root reached for on a path that
           module init happens not to take. *)
        let declares_without_roots =
          try
            let pr = Canary_opam_binding.run Canary_project_zlib.decl in
            not (List.is_empty pr.Canary_project_run.pr_artifacts)
          with _ -> false
        in
        restore ();
        resolves && refuses && declares_without_roots) }

(* THE RUN RECORD IS THE SESSION (2026-08-26, user: "the config and driver
   side is like a session, and no hardcoded is necessary").

   [run_info.json] said `"opam_switch": "default"` on a run whose every
   actions.log line said `opam_switch (canary)`, and reported the distro
   from a private fourth [uname] that no override could reach. A record
   that re-probes the box is describing a different session than the one
   it belongs to. Pins that [detect_env] READS the two session values. *)
let run_info_session_pin : Canary_project_test.pure_test =
  { name = "run_info.records_the_session";
    check =
      (fun () ->
        let saved_sw = !Canary_store.opam_switch in
        let saved_pl = !Canary_store.platform_override in
        let restore () =
          Canary_store.opam_switch := saved_sw;
          Canary_store.platform_override := saved_pl
        in
        (* a session this machine is NOT: an overridden platform and a
           named switch. Both must survive into the record. *)
        Canary_store.opam_switch := Some "canary";
        Canary_store.set_platform Canary_store.MacOS_local;
        let distro, _pm, switch, _ocaml = Canary_run_info.detect_env () in
        let ok =
          String.equal distro
            (Canary_store.string_of_platform Canary_store.MacOS_local)
          && String.equal switch "canary"
        in
        (* and the ambient selection renders as such rather than as
           whatever `opam switch show` happens to print *)
        Canary_store.opam_switch := None;
        let _, _, ambient, _ = Canary_run_info.detect_env () in
        restore ();
        ok && String.equal ambient "(ambient)") }

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
        (* the version of the project's OWN source artifact — zarith's is
           the OCaml binding's source ([source_artifact_of], 2026-08-19) *)
        let source_version pr a =
          Canary_enumerate.version_of a (source_artifact_of pr)
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
          (* 2 since the unread-source collapse (2026-08-19): the third
             world was `binding Fetched × source master` — an opam-installed
             binding beside a master worktree nothing built from, i.e. the
             same run as `binding Fetched × source 1.14` with a different
             unread ref. What remains is the forward cell (binding built
             from master) and the both-released baseline. *)
          List.length zarith_asgs = 2
          && List.for_all zarith_asgs ~f:(fun a ->
                 not
                   (String.equal
                      (source_version Canary_project_zarith.zarith_run a)
                        .Canary_basic.id ""))
          && List.length
               (List.dedup_and_sort
                  (List.map zarith_asgs ~f:(fun a ->
                       Canary_project_run.scenario_dir_of ~pr_name:"zarith" a))
                  ~compare:String.compare)
               = 2
        in
        (* the realize ∘ dispatch: each scenario's fetch command
           materializes ITS repo's worktree ref. zarith's source is the
           BINDING's (2026-08-19), so the cmd lives in the
           [fetch_binding_source] slot — the [Fetch (Binding_source ocaml)]
           action — not [fetch_source]. *)
        let fetch_cmd_of a =
          let spec =
            Canary_project_zarith.zarith_run.Canary_project_run.pr_runner_spec
              a ~workspace:"/tmp/c1" ()
          in
          match
            List.find spec.Canary_step_builder.fetch_binding_source
              ~f:(fun (l, _) -> Poly.equal l Canary_lang.OCaml)
          with
          | Some (_, f) -> f ~output_dir:"/tmp/c1" ~variant_key:"c1"
          | None -> ""
        in
        let cmds_ok =
          List.for_all zarith_asgs ~f:(fun a ->
              let expect =
                match
                  (source_version Canary_project_zarith.zarith_run a)
                    .Canary_basic.channel
                with
                | Canary_basic.Stable -> "release-1.14"
                | Canary_basic.Dev -> "master"
              in
              String.is_substring (fetch_cmd_of a) ~substring:expect)
        in
        let cairo_ok =
          (* cairo now enumerates TWO worlds (2026-08-19): the system lib
             and the vendored conda-forge prebuilt. The repo-axes claim is
             about the SOURCE ref, which both share, so check it on the
             system-lib world. *)
          match
            List.filter
              (Canary_project_run.scenarios_of Canary_project_cairo.cairo_run)
              ~f:(fun a ->
                Canary_artifact.equal_provision
                  (Canary_enumerate.provision_of a Canary_artifact.a_lib)
                  Canary_artifact.Fetched)
          with
          | [ a ] ->
              (* cairo's repo IS the C lib's — it keeps [a_source] *)
              String.equal
                (source_version Canary_project_cairo.cairo_run a)
                  .Canary_basic.id "1.18.0"
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
          && (match
                Canary_agreement.inputs_of_agreement
                  Canary_agreement_common.Required_symbols_exported
                  Canary_lang.OCaml
              with
              (* the stub carries BOTH filename conventions since
                 2026-09-12 (the framework's inspect_stub.json and
                 tiny's inspect.json); what this pins is unchanged —
                 every candidate resolves under the BINDING's step dir,
                 which is the lang-less-tag bug it was written for *)
              | [ Canary_agreement_common.C_stub stub_rels;
                  Canary_agreement_common.Native_lib lib_rels ] ->
                  (not (List.is_empty stub_rels))
                  && List.for_all stub_rels
                       ~f:(String.is_prefix ~prefix:(binding_tag ^ "/"))
                  && String.equal (List.hd_exn lib_rels) "build_lib/inspect.json"
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
        (* the staged world of the pre-fix ref AND a built binding: since
           the mismatch matrix opened (2026-08-19) the staged face carries
           two cells, and only the built-binding one consumes the staged
           OCaml package. The other cell's consumer is the released opam
           package, which the missing install rules cannot affect. *)
        let is_staged_world a =
          String.equal
            (Canary_enumerate.version_of a Canary_artifact.a_source)
              .Canary_basic.id "pre-10549"
          && Canary_enumerate.equal_provision
               (Canary_enumerate.provision_of a Canary_artifact.a_lib)
               Canary_artifact.Installed
          && Canary_enumerate.equal_provision
               (Canary_enumerate.provision_of a
                  Canary_project_z3.z3_binding_art)
               Canary_artifact.Built
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
(* z3's CROSS CELLS ASSERT THEIR WORLD (2026-08-20, plan item A2).

   z3 exists to put a DIFFERENT libz3 in front of the same binding — the
   dev build tree, the staged install prefix, apt's 4.8.12. Until now the
   probe's `z3 version:` line was evidence a reader could check, not a
   condition the run enforced: an ambient lib answering still went green.

   Two properties, and the second is the one with teeth: the Built and
   Installed worlds must assert DIFFERENT directories (else the pair is
   one world twice — the same check sqlite.staged_probe_paths makes on
   emitted commands), and no asserted path may carry a `..` segment,
   because the probe reports what the loader RESOLVED and a spelling
   comparison against an unnormalised path silently never matches. That
   exact mismatch turned all five z3 cells red on the first attempt. *)
let z3_cross_cell_world_asserts_pin : Canary_project_test.pure_test =
  { name = "z3.cross_cells_assert_world";
    check =
      (fun () ->
        let pr = Canary_project_z3.z3_run Canary_store.Wsl in
        let asserted_dirs a =
          let spec =
            pr.Canary_project_run.pr_runner_spec a ~workspace:"/tmp/ws" ()
          in
          List.concat_map spec.Canary_step_builder.asserts
            ~f:(fun (_, _, ws) -> Canary_world.log_substrings ws)
        in
        let by_prov prov =
          List.filter (Canary_project_run.scenarios_of pr) ~f:(fun a ->
              Canary_enumerate.equal_provision
                (Canary_enumerate.provision_of a Canary_artifact.a_lib)
                prov)
          |> List.concat_map ~f:asserted_dirs
          |> List.dedup_and_sort ~compare:String.compare
        in
        let built = by_prov Canary_artifact.Built in
        let installed = by_prov Canary_artifact.Installed in
        (* both worlds must actually declare something — otherwise every
           check below is vacuous and the pin passes on a lost assertion *)
        (not (List.is_empty built))
        && (not (List.is_empty installed))
        (* ...and they must not name the same place *)
        && List.for_all built ~f:(fun b ->
               not (List.mem installed b ~equal:String.equal))
        (* ...and nothing may carry an unresolved `..`, which is what the
           loader's report can never match *)
        && List.for_all (built @ installed) ~f:(fun d ->
               not (String.is_substring d ~substring:".."))) }

(* RUN ORDER GROUPS BY STORE STATE (2026-08-21, stage5_order_worlds.md §3).

   An opam switch holds ONE version of a package, so a pinned placement is
   an exclusive lock on that store's state. The enumerated list has always
   been the run order, and its product ranges over the lib axis outermost
   — so a pinned binding alternated on nearly every row and the switch was
   torn down and rebuilt between neighbours that wanted the same thing.

   Two properties, and both are needed:

   (a) SAME SET. Ordering must not add, drop or duplicate a scenario —
       it is a sort, not a policy. Checked as multiset equality on the
       assignment strings.
   (b) GROUPED. Each distinct store-state key occupies ONE contiguous run.
       This is the property that saves the work; without it the sort could
       "succeed" while still interleaving.

   Measured on sqlite before/after: ten pin operations of which nine were
   real swaps, down to ten of which TWO are real and the rest no-ops. *)
(* ── THE PIPELINE IS ONE ASSEMBLY (2026-08-24; stage 2 Attribution, was why_ledger.md §8 step 2) ──

   [Canary_pipeline] exists because the chain was assembled in
   [Canary_runner.run_project_spec] and PARTIALLY re-assembled in
   [Canary_matrix.actions_of]. These two pins guard the move.

   [pipeline.ctx_matches_scenario_dir] is the one with teeth: the runner
   used to compute the workspace and the per-scenario project name INLINE,
   and those strings reach output paths and env vars. If [ctx_of] drifts
   from [scenario_dir_of], every scenario silently writes somewhere
   else — and the run-cache would serve markers from the old location. *)
let pipeline_ctx_pin : Canary_project_test.pure_test =
  { name = "pipeline.scenario_names_are_born_safe";
    check =
      (fun () ->
        (* TWO claims, and the second is the one that lets the first be
           simple. (1) [ctx_of] agrees with [scenario_dir_of] and derives
           the project name from it — the runner used to compute both
           inline, and they reach output paths and env vars, so drift
           relocates every scenario and orphans its cache markers.
           (2) the names are BORN safe: no scenario dir basename contains
           a character that would need escaping in a path or a
           ':'-separated env var. The runner carried a sanitizer for
           exactly that until 2026-08-24; it was dead code, and the
           honest replacement is to assert the producer rather than patch
           the consumer. *)
        let unsafe c =
          match c with
          | ':' | '#' | '+' | ' ' | '\'' | '"' | '$' | '&' | '|' | ';'
          | '(' | ')' | '*' | '?' | '<' | '>' ->
              true
          | _ -> false
        in
        List.for_all Canary_registry.all_specs ~f:(fun (name, pr) ->
            List.for_all (Canary_pipeline.ordered pr) ~f:(fun a ->
                let ctx = Canary_pipeline.ctx_of pr a in
                let ws = Canary_project_run.scenario_dir_of ~pr_name:name a in
                let base = Stdlib.Filename.basename ws in
                let agrees =
                  String.equal ctx.Canary_pipeline.sc_workspace ws
                  && String.equal ctx.Canary_pipeline.sc_project
                       (name ^ "/" ^ base)
                in
                let born_safe = not (String.exists base ~f:unsafe) in
                if not agrees then
                  Fmt.pr "  pipeline.ctx: %s → %s / %s@." name
                    ctx.Canary_pipeline.sc_workspace
                    ctx.Canary_pipeline.sc_project;
                if not born_safe then
                  Fmt.pr "  pipeline.name: %s has an unsafe scenario name %s@."
                    name base;
                agrees && born_safe))) }

(* ── SELECTION IS A POST-FILTER (2026-08-24; stage 2 Attribution, was why_ledger.md §7) ──

   The claim the selection pass rests on: restricting each artifact's
   version universe BEFORE the product (what [run_config]'s
   [resolve_versions] does) gives the same assignments as filtering the
   product AFTER it (what [select] does). True because restricting a
   factor of a product equals filtering the product on that factor — but
   the product here is followed by five constraints, one of which
   ([shadow_filter]) is CROSS-assignment, so the argument is not
   self-evident and is checked instead.

   Thin is the case that matters: it differs from full in exactly one
   axis, the version level, so this pins the whole equivalence. Run over
   every catalogued project, muted included. *)
let select_post_filter_pin : Canary_project_test.pure_test =
  { name = "select.thin_post_filter_equals_universe_restriction";
    check =
      (fun () ->
        let module EN = Canary_enumerate in
        let thin = Canary_project_run.thin_policy () in
        let key asgs =
          List.map asgs ~f:EN.string_of_assignment
          |> List.sort ~compare:String.compare
        in
        List.for_all Canary_registry.all_specs ~f:(fun (name, pr) ->
            let spec =
              Canary_project_spec.project_spec_of_rows
                pr.Canary_project_run.pr_artifacts
            in
            let restricted =
              EN.enumerate ~tag:(fun () -> "") ~policy:thin spec
            in
            let post_filtered =
              EN.enumerate ~tag:(fun () -> "")
                ~policy:(EN.unselected thin) spec
              |> EN.select (EN.selection_of_policy thin)
            in
            let ok =
              List.equal String.equal (key restricted) (key post_filtered)
            in
            if not ok then
              Fmt.pr "  select: %s restricted=%d post_filtered=%d@." name
                (List.length restricted) (List.length post_filtered);
            ok)) }

(* ── EACH PASS ENCODES ON ITS OWN (2026-08-24) ──

   The user's reason for wanting per-pass JSON was structural: if every
   pass can be serialized independently, the layering is real rather than
   asserted. This pin is that claim made testable — every pure pass
   encodes, for every catalogued project, and each encoding NAMES its own
   pass and carries the project. (Pass 5 is excluded: encoding it applies
   [pr_runner_spec], which is not pure — see the pipeline header.)

   The second half is the one with teeth: the encoded assignment keys
   must equal the pass's own keys. An encoder that re-derived its content
   could drift from the pass it claims to serialize, which is the same
   failure the pipeline module exists to prevent one level up. *)
let json_per_pass_pin : Canary_project_test.pure_test =
  { name = "emit.each_pass_encodes_independently";
    check =
      (fun () ->
        let field name = function
          | `Assoc kvs -> List.Assoc.find kvs name ~equal:String.equal
          | _ -> None
        in
        let str name j =
          match field name j with Some (`String s) -> Some s | _ -> None
        in
        let keys j =
          match field "assignments" j with
          | Some (`List xs) ->
              List.filter_map xs ~f:(fun x ->
                  match str "key" x with Some k -> Some k | None -> None)
          | _ -> []
        in
        List.for_all Canary_registry.all_specs ~f:(fun (name, pr) ->
            let declare = Canary_pipeline.json_declare pr in
            let enumerate =
              Canary_pipeline.json_assignments ~pass:"enumerate" pr
                (Canary_pipeline.worlds pr)
            in
            let order = Canary_pipeline.json_order pr in
            let named j want =
              Poly.equal (str "project" j) (Some name)
              && Poly.equal (str "pass" j) (Some want)
            in
            let self_describing =
              named declare "declare" && named enumerate "enumerate"
              && named order "order"
            in
            (* the encoding is the pass, not a re-derivation *)
            let faithful =
              List.equal String.equal (keys enumerate)
                (List.map (Canary_pipeline.worlds pr)
                   ~f:Canary_enumerate.string_of_assignment)
            in
            if not (self_describing && faithful) then
              Fmt.pr "  emit.json: %s self=%b faithful=%b@." name
                self_describing faithful;
            self_describing && faithful)) }

(* ── THE TWO STAGE-2 CONSTRUCTIONS AGREE (2026-08-24) ──

   [enumerate_product] (product-then-filter, mutation-aware) and
   [enumerate_follows_tree] (a root/child walk over ax_follows,
   positive-only) are different algorithms that should compute the same
   worlds. Until today they could not be compared, because
   [string_of_assignment] printed pairs in list order and the two build
   them in different orders; making the key canonical made the question
   answerable, and this pin answers it for every catalogued project.

   Its value is forward-looking: it is the evidence for eventually
   deleting one of them, and until then it is what stops them drifting
   apart unnoticed while the docs describe only the first. *)
let two_constructions_agree_pin : Canary_project_test.pure_test =
  { name = "enumerate.two_constructions_agree";
    check =
      (fun () ->
        let module EN = Canary_enumerate in
        let full = EN.unselected (EN.full_policy ()) in
        let key asgs =
          List.map asgs ~f:EN.string_of_assignment
          |> List.sort ~compare:String.compare
          |> List.dedup_and_sort ~compare:String.compare
        in
        List.for_all Canary_registry.all_specs ~f:(fun (name, pr) ->
            let spec =
              Canary_project_spec.project_spec_of_rows
                pr.Canary_project_run.pr_artifacts
            in
            let product =
              key (EN.enumerate_product ~tag:(fun () -> "") ~policy:full spec)
            in
            let tree = key (EN.enumerate_follows_tree ~policy:full spec) in
            let ok = List.equal String.equal product tree in
            if not ok then begin
              Fmt.pr "  enumerate: %s product=%d follows_tree=%d@." name
                (List.length product) (List.length tree);
              List.iter
                (List.filter product ~f:(fun x ->
                     not (List.mem tree x ~equal:String.equal)))
                ~f:(fun x -> Fmt.pr "    only in product: %s@." x);
              List.iter
                (List.filter tree ~f:(fun x ->
                     not (List.mem product x ~equal:String.equal)))
                ~f:(fun x -> Fmt.pr "    only in follows_tree: %s@." x)
            end;
            ok)) }

(* The DEFAULT run asks for everything: stage 2.5 under the full policy
   is stage 2 unchanged. Without this, a selection that quietly narrowed
   by default would shrink every run while every count still "matched" —
   and stage 2 would stop being the honest inventory it is now printed
   as. *)
let select_default_is_identity_pin : Canary_project_test.pure_test =
  { name = "select.full_policy_selects_everything";
    check =
      (fun () ->
        let module EN = Canary_enumerate in
        let key asgs =
          List.map asgs ~f:EN.string_of_assignment
          |> List.sort ~compare:String.compare
        in
        List.for_all Canary_registry.all_specs ~f:(fun (name, pr) ->
            let all = Canary_pipeline.worlds pr in
            let default = Canary_pipeline.enumerated pr in
            let ok = List.equal String.equal (key all) (key default) in
            if not ok then
              Fmt.pr "  select: %s worlds=%d default-run=%d@." name
                (List.length all) (List.length default);
            ok)) }

(* Selection only REMOVES. It can never invent a world, which is what
   makes stage 2's output the honest "everything this project has". *)
let select_subset_pin : Canary_project_test.pure_test =
  { name = "select.is_a_subset_of_stage2";
    check =
      (fun () ->
        let module EN = Canary_enumerate in
        let thin = Canary_project_run.thin_policy () in
        List.for_all Canary_registry.all_specs ~f:(fun (name, pr) ->
            let spec =
              Canary_project_spec.project_spec_of_rows
                pr.Canary_project_run.pr_artifacts
            in
            let all =
              EN.enumerate ~tag:(fun () -> "") ~policy:(EN.unselected thin) spec
              |> List.map ~f:EN.string_of_assignment
            in
            let selected =
              EN.enumerate ~tag:(fun () -> "")
                ~policy:(EN.unselected thin) spec
              |> EN.select (EN.selection_of_policy thin)
              |> List.map ~f:EN.string_of_assignment
            in
            let ok =
              List.for_all selected ~f:(fun x ->
                  List.mem all x ~equal:String.equal)
            in
            if not ok then Fmt.pr "  select: %s invented a world@." name;
            ok)) }

(* Stages 1-3 are TOTAL over the catalogue — muted projects included, since
   a dump of a muted project is exactly when you want one. Stage 1's
   universe must also have one entry per declared row: [project_spec_of_rows]
   is a map, and a silent drop there would shrink every later stage. *)
let pipeline_total_pin : Canary_project_test.pure_test =
  { name = "pipeline.stages_total_over_catalogue";
    check =
      (fun () ->
        List.for_all Canary_registry.all_specs ~f:(fun (name, pr) ->
            let spec = Canary_pipeline.spec_of pr in
            let rows = List.length pr.Canary_project_run.pr_artifacts in
            let declared = List.length spec.Canary_artifact.ps_universe in
            let enumerated = List.length (Canary_pipeline.enumerated pr) in
            let ordered = List.length (Canary_pipeline.ordered pr) in
            let ok =
              declared = rows && enumerated > 0 && ordered = enumerated
            in
            if not ok then
              Fmt.pr
                "  pipeline.total: %s rows=%d declared=%d stage2=%d stage3=%d@."
                name rows declared enumerated ordered;
            ok)) }

let run_order_groups_state_pin : Canary_project_test.pure_test =
  { name = "run_order.groups_by_store_state";
    check =
      (fun () ->
        let grouped_ok pr =
          let ordered = Canary_project_run.scenarios_in_run_order pr in
          let keys =
            List.map ordered ~f:(Canary_project_run.store_state_key pr)
          in
          (* a key may not reappear after a different key has intervened *)
          let rec contiguous seen prev = function
            | [] -> true
            | k :: rest ->
                if Poly.equal (Some k) prev then contiguous seen prev rest
                else if List.mem seen k ~equal:Poly.equal then false
                else contiguous (k :: seen) (Some k) rest
          in
          contiguous [] None keys
        in
        let same_set pr =
          let norm xs =
            List.map xs ~f:Canary_enumerate.string_of_assignment
            |> List.sort ~compare:String.compare
          in
          Poly.equal
            (norm (Canary_project_run.scenarios_of pr))
            (norm (Canary_project_run.scenarios_in_run_order pr))
        in
        (* checked over every catalogued project, muted ones included: the
           ordering is a property of the enumeration, not of the run set *)
        let projects = List.map Canary_registry.all_specs ~f:snd in
        (* and at least one project must actually HAVE pinned state, else
           every check above is vacuous *)
        let any_pinned =
          List.exists projects ~f:(fun pr ->
              List.exists (Canary_project_run.scenarios_of pr) ~f:(fun a ->
                  not (List.is_empty (Canary_project_run.store_state_key pr a))))
        in
        any_pinned
        && List.for_all projects ~f:same_set
        && List.for_all projects ~f:grouped_ok) }

(* ONE WORLD-ASSERTION VOCABULARY (2026-08-20).

   "Did this step run in the world its scenario names?" existed in five
   implementations, four of which had failed: three byte-identical
   `<project>_world_check` copies (ssl / z3 / llvm), sqlite's `asserts`
   greped after `exit $RC` so it never ran, and the opam template's
   `world_check` + `log_grep` pair that was never wired for Vendored lib
   worlds. They now all render through [Canary_world].

   The pin asserts the property that made them worth unifying — that the
   SAME claim produces the SAME shell wherever it is declared — plus the
   two things each old copy got individually wrong: a pre-command guard
   must be able to abort (it names `exit 1`), and a post-hoc claim must be
   greped from the log rather than appended after the command's own exit. *)
let world_assertion_vocabulary_pin : Canary_project_test.pure_test =
  { name = "world.one_vocabulary";
    check =
      (fun () ->
        let module W = Canary_world in
        (* (1) the three former copies now render identically for the same
           claim — the dedup is real, not a rename *)
        let pin_shell pkg =
          W.pre_shell [ W.Opam_pin { pkg; version = "1.2.3" } ]
        in
        let same_shape =
          List.for_all [ "ssl"; "z3"; "llvm" ] ~f:(fun pkg ->
              let a = pin_shell pkg in
              String.is_substring a ~substring:"opam list"
              && String.is_substring a ~substring:"WORLD MISMATCH"
              (* it must be able to FAIL — a guard that cannot abort is
                 the class of bug this whole exercise is about *)
              && String.is_substring a ~substring:"exit 1"
              && String.is_substring a ~substring:pkg
              && String.is_substring a ~substring:"1.2.3")
        in
        (* and the shared step-builder entry point agrees with the
           vocabulary, so a caller cannot pick a different spelling *)
        let builder_agrees =
          String.equal
            (Canary_step_builder.opam_world_check ~pkg:"ssl" ~pin:"0.6.0")
            (W.pre_shell [ W.Opam_pin { pkg = "ssl"; version = "0.6.0" } ])
        in
        (* (2) the two kinds are routed to different enforcement points and
           NEITHER is silently dropped *)
        let ws =
          [ W.Opam_pin { pkg = "zstd"; version = "0.4" };
            W.Log_names { text = "zstd version: 1.5.7"; why = "witness" } ]
        in
        let split_ok =
          Poly.equal (List.map ws ~f:W.is_pre) [ true; false ]
          && List.length (W.log_substrings ws) = 1
          && String.is_substring (W.pre_shell ws) ~substring:"zstd"
          (* a log claim must NOT leak into the pre-command shell, and a
             pin must NOT be looked for in the log *)
          && (not
                (String.is_substring (W.pre_shell ws)
                   ~substring:"zstd version: 1.5.7"))
          && List.for_all (W.log_substrings ws) ~f:(fun s ->
                 not (String.is_substring s ~substring:"opam list"))
        in
        (* (3) the post-hoc form is greped from the log, inside a subshell,
           so a command ending in `exit $RC` cannot kill the check — the
           exact bug that made sqlite's assert dead code *)
        let post_ok =
          let cmd =
            Canary_step_builder.with_world_asserts
              ~asserts:[ W.Log_names { text = "MARK"; why = "w" } ]
              ~output_dir:"/tmp/o" ~variant_key:"k" "echo hi; exit $RC"
          in
          String.is_substring cmd ~substring:"( echo hi; exit $RC )"
          && String.is_substring cmd ~substring:"&& grep -qF \"MARK\""
        in
        (* (4) every assertion carries a reason — a check whose failure
           message says nothing is barely a check (the prebuilt guard that
           printed "run  first") *)
        let reasons_ok =
          List.length (W.reasons ws) = 2
          && List.for_all (W.reasons ws) ~f:(fun (_, why) ->
                 not (String.is_empty why))
        in
        same_shape && builder_agrees && split_ok && post_ok && reasons_ok) }

(* THE ENV GUARD MUST NAME A REAL DIRECTORY (2026-08-20).

   z3's Build_binding row carries an [env_guard] that puts the freshly
   built <build>/src/api/ml first on CAML_LD_LIBRARY_PATH, because z3's
   POST_BUILD self-check runs ml_example with ambient dll search and the
   opam switch's stale dllz3ml.so otherwise wins ("unknown C primitive
   'n_solver_register_on_clause'", 2026-08-13).

   The guard absolutised its path with a `$(pwd)/` prefix. That was right
   while [build] was relative; the per-ref build dirs of 2026-08-19 made
   it ABSOLUTE, so the guard started expanding to
   `<repo>//home/red/code/contrib/...` — a path that cannot exist. It
   still SET the variable, so nothing failed loudly; the shadowing simply
   came back, and stayed hidden until the pre-10549 ref was run on
   2026-08-20.

   Two properties, and the first is the one that was violated: no path in
   the guard may contain `//` after its leading root (the signature of a
   prefix glued onto an already-absolute path), and the guard must still
   name the build tree it is protecting. Checked over every declared z3
   source, so a fourth ref inherits it. *)
let z3_env_guard_paths_pin : Canary_project_test.pure_test =
  { name = "z3.env_guard_paths";
    check =
      (fun () ->
        let module AT = Canary_action_templates in
        let distro = Canary_basic.detect_distro () in
        let guard_of (repo : Canary_artifact_source.source_repo) =
          List.find_map
            (Canary_project_z3.z3_table_rows ~source:repo ~distro
               ~lib_prov:Canary_artifact.Built)
            ~f:(fun (row : AT.action_row) ->
              match row.AT.ar_template with
              | AT.Ninja_build_binding { env_guard = Some g; build; _ } ->
                  Some (g, build)
              | _ -> None)
        in
        let repos =
          [ Canary_project_z3.z3_source_latest;
            Canary_project_z3.z3_source_dev;
            Canary_project_z3.z3_source_pre_10549 ]
        in
        let guards = List.filter_map repos ~f:guard_of in
        (* the guards must EXIST — else every check below is vacuous *)
        List.length guards = List.length repos
        && List.for_all guards ~f:(fun (g, build) ->
               (* a doubled slash anywhere past the root means a prefix
                  was glued onto an absolute path *)
               (not (String.is_substring g ~substring:"//"))
               (* ...and it still has to point AT the build tree *)
               && String.is_substring g ~substring:build
               && String.is_substring g ~substring:"CAML_LD_LIBRARY_PATH"
               && String.is_substring g ~substring:"/src/api/ml")) }

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
                         normalize (Canary_artifact_source.build_path_of l)))))
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
          (* the BUILT binding's probe — the only one that reads a concrete
             tree. Keyed on the binding's provision since the matrix opened
             (2026-08-19): a staged world also hosts the released binding,
             whose probe is the opam one and names no tree. *)
          if
            Canary_enumerate.equal_provision
              (Canary_enumerate.provision_of a Canary_project_z3.z3_binding_art)
              Canary_artifact.Built
          then
            List.find (probe_cmds a) ~f:(fun c ->
                String.is_substring c ~substring:"z3_example")
          else None
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
        (* z3's SPEC, not its registry entry (2026-08-21): row ordering is
           a property of the enumeration, which exists whether or not the
           project is currently in the run set *)
        let z3 = Canary_project_z3.z3_run (Canary_basic.detect_distro ()) in
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
        (* 2026-08-19, the mismatch matrix: per dev ref FIVE rows — the
           built lib under each binding (dev baseline, then BACKWARD), the
           staged lib under each binding, and the released lib under the
           built binding (FORWARD, sorting last because a Fetched lib is
           last in the lib key). The both-released baseline leads, on the
           stable ref, and is ref-independent. *)
        let per_ref r =
          [ (r, Canary_artifact.Built); (r, Canary_artifact.Built);
            (r, Canary_artifact.Installed); (r, Canary_artifact.Installed);
            (r, Canary_artifact.Fetched) ]
        in
        Poly.equal keyed
          (("4.15.2", Canary_artifact.Fetched)
          :: (per_ref "latest" @ per_ref "arbipher" @ per_ref "pre-10549"))) }

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
          (* One (channel, provision) may now own SEVERAL adjacent rows —
             a second axis on another artifact multiplies them (sqlite's
             two binding pins, 2026-08-19). The ORDER claim is about the
             lib's blocks, so compare the sequence of distinct blocks;
             the twin COUNT below still uses every row, so a lost staged
             row is caught whatever the multiplicity. *)
          let blocks =
            List.remove_consecutive_duplicates pairs
              ~equal:(fun x y -> Poly.equal x y)
          in
          Poly.equal blocks
            (List.filter canonical ~f:(fun p ->
                 List.mem blocks p ~equal:Poly.equal))
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

(* THE VENDORED-WORLD PIN (2026-08-20, the zlib landing). The landing
   checklist's step with teeth: a project whose lib pair is
   "apt vs a downloaded prebuilt" is only testing two worlds if the two
   worlds' realized probe commands NAME DIFFERENT FILES. cairo is why —
   its two cairo versions export identical symbol counts, so a probe that
   silently resolved the system copy passed for the wrong reason and no
   verdict could tell.

   Three things are asserted, and each one failed somewhere before:

   1. the Vendored world's probe carries the PREBUILT's libdir
      (the repoint exists at all — the cairo bug);
   2. the Fetched world's probe does NOT (they are distinguishable, so
      the pair is a pair);
   3. when the project says its probe NAMES the library it resolved
      ([probe_names_lib]), the Vendored probe also GREPS for that libdir
      — pointing the loader is not the same as checking it obeyed.

   Derived over the registry: every project declaring a prebuilt is
   checked, so a new Vendored landing inherits the pin instead of
   re-deriving it. *)
let vendored_world_probe_pin : Canary_project_test.pure_test =
  { name = "vendored.probe_names_the_world";
    check =
      (fun () ->
        let distro = Canary_basic.detect_distro () in
        let decls =
          [ ("zlib", Canary_project_zlib.decl, Canary_project_zlib.zlib_run);
            ("cairo", Canary_project_cairo.decl, Canary_project_cairo.cairo_run);
            ("libffi", Canary_project_libffi.decl,
             Canary_project_libffi.libffi_run);
            ("zstd", Canary_project_zstd.decl, Canary_project_zstd.zstd_run) ]
        in
        let probe_cmd_of pr a =
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
        let checked = ref 0 in
        let ok =
          List.for_all decls ~f:(fun (_name, d, pr) ->
              match d.Canary_opam_binding.prebuilt_latest with
              | None -> true
              | Some pb ->
                  let libdir = Canary_prebuilt.libdir_of pb distro in
                  List.for_all (Canary_project_run.scenarios_of pr)
                    ~f:(fun a ->
                      let cmd = probe_cmd_of pr a in
                      match
                        Canary_enumerate.provision_of a Canary_artifact.a_lib
                      with
                      | Canary_artifact.Vendored ->
                          Int.incr checked;
                          (* (1) the repoint, and (3) the assert when the
                             probe can name what answered *)
                          String.is_substring cmd ~substring:libdir
                          && ((not d.Canary_opam_binding.probe_names_lib)
                             || String.is_substring cmd ~substring:"grep -qF")
                      | _ ->
                          (* (2) the OTHER world must not carry it, or the
                             pair is one world twice *)
                          not (String.is_substring cmd ~substring:libdir)))
        in
        (* the Vendored worlds must EXIST — otherwise every for_all above
           is vacuous and this passes on a lost axis (the same trap
           matrix.cell_stage_progression guards) *)
        ok && !checked >= 4) }

(* The CELL STAGE progression (2026-08-19, user): in a staged world the
   build step names the tree it BUILT and only install/probe name the
   staged face, so a row reads left-to-right as the artifact's
   progression. Before, every cell carried the world's provision and all
   three read [lib I:s] — the row said "installed" three times and never
   said a build happened. Derived over every registry project that
   enumerates an Installed lib. *)
let matrix_cell_stage_pin : Canary_project_test.pure_test =
  { name = "matrix.cell_stage_progression";
    check =
      (fun () ->
        let m = Canary_matrix.matrix_of Canary_registry.all_projects in
        let cell (r : Canary_matrix.row) tag =
          match
            List.Assoc.find r.Canary_matrix.cells tag ~equal:String.equal
          with
          | Some (Some c) -> Some c.Canary_matrix.provision
          | _ -> None
        in
        let staged_rows =
          List.concat_map Canary_registry.all_projects ~f:(fun (name, pr) ->
              List.filter_map (Canary_project_run.scenarios_of pr)
                ~f:(fun a ->
                  if
                    Canary_enumerate.equal_provision
                      (Canary_enumerate.provision_of a Canary_artifact.a_lib)
                      Canary_artifact.Installed
                  then
                    Some
                      ( name,
                        Stdlib.Filename.basename
                          (Canary_project_run.scenario_dir_of ~pr_name:name a)
                      )
                  else None))
        in
        (* the staged worlds must EXIST — else every for_all below is
           vacuous and the pin would pass on a lost axis *)
        (not (List.is_empty staged_rows))
        && List.for_all staged_rows ~f:(fun (proj, scen) ->
               match
                 List.find m.Canary_matrix.rows ~f:(fun r ->
                     String.equal r.Canary_matrix.project proj
                     && String.equal r.Canary_matrix.scenario scen)
               with
               | None -> false
               | Some r ->
                   (* built by the build step … *)
                   (match cell r "build_lib" with
                   | Some c -> String.is_prefix c ~prefix:"lib B:"
                   | None -> false)
                   (* … staged by the install step … *)
                   && (match cell r "install_lib" with
                      | Some c -> String.is_prefix c ~prefix:"lib I:"
                      | None -> false)
                   (* … and read from the staged face by the probe *)
                   && (match cell r "probe_lib" with
                      | Some c -> String.is_prefix c ~prefix:"lib I:"
                      | None -> true))) }

(* The SETTING block (2026-08-19, user: "move all the provider ahead …
   more clear to readers on which is the setting for this row"): the
   leading columns are one per artifact KIND, and a row's setting cells
   ARE its assignment — so the row identifies its world without the old
   single `ref` column (which named a different artifact's source per
   project and could not tell z3's build-tree world from its staged one).
   Pinned: (a) one column per kind, no duplicates — the mechanism rides
   the artifact id, so deduping by id would double `ocaml`/`py`;
   (b) a cell exists exactly when the project declares that kind;
   (c) the block DISTINGUISHES worlds — no two rows of a project share
   their full setting tuple, which is the property the ref column
   lacked. *)
let matrix_setting_block_pin : Canary_project_test.pure_test =
  { name = "matrix.setting_block_identifies_world";
    check =
      (fun () ->
        let m = Canary_matrix.matrix_of Canary_registry.all_projects in
        let labels = m.Canary_matrix.setting_columns in
        (* (a) *)
        let no_dups =
          List.length
            (List.dedup_and_sort labels ~compare:String.compare)
          = List.length labels
        in
        (* (b) — the declared kinds of each row's project *)
        let declared_ok =
          List.for_all Canary_registry.all_projects ~f:(fun (name, pr) ->
              let kinds =
                List.map (Canary_project_run.artifact_infos pr)
                  ~f:Canary_artifact.kind_of
              in
              let want =
                List.map kinds ~f:(fun k -> Canary_matrix.kind_label k)
                |> List.dedup_and_sort ~compare:String.compare
              in
              List.for_all m.Canary_matrix.rows ~f:(fun r ->
                  if not (String.equal r.Canary_matrix.project name) then true
                  else
                    List.for_all r.Canary_matrix.settings
                      ~f:(fun (label, s) ->
                        Bool.equal (Option.is_some s)
                          (List.mem want label ~equal:String.equal))))
        in
        (* (c) the block is an IDENTITY: distinct worlds, distinct tuples *)
        let identifies =
          List.for_all Canary_registry.all_projects ~f:(fun (name, _) ->
              let tuples =
                List.filter_map m.Canary_matrix.rows ~f:(fun r ->
                    if String.equal r.Canary_matrix.project name then
                      Some
                        (List.map r.Canary_matrix.settings
                           ~f:(fun (_, s) ->
                             match s with
                             | Some s -> s.Canary_matrix.text
                             | None -> ""))
                    else None)
              in
              List.length
                (List.dedup_and_sort tuples ~compare:Poly.compare)
              = List.length tuples)
        in
        (not (List.is_empty labels)) && no_dups && declared_ok && identifies) }

(* THE PAGE CARRIES THE GRID, AND THE SAME ONE (2026-09-17, user:
   "can you land the second table in the `make view` and give each
   table a title name").

   [matrix.html] now renders three tables, and the middle one is the
   recovery grid — the same value `canary checks --firing` prints. Two
   renderings of one table is how they drift, so this counts cells: the
   HTML must carry exactly one per (agreement × action column), and the
   R / D / R+D tallies must match what [overview_rows] computes.

   It also pins the TITLES, because the reason the page was hard to read
   was that three tables sat under one heading and a reader could not
   tell the template from the record. A table without a name is the
   defect this fixes, so the names are part of the contract. *)
let matrix_page_has_the_grid_pin : Canary_project_test.pure_test =
  { name = "matrix.page_titles_and_agreement_overview";
    check =
      (fun () ->
        (* THE OVERVIEW MOVED (2026-09-23, user), and this pin caught it
           — which is what it is for. It reads the METHODOLOGY page now,
           because the table describes the shape of the checking and that
           page is where shape lives; the result matrix keeps only
           verdicts and a link.

           Both files are asserted, so the split cannot silently become a
           duplication: the overview must be on exactly one of them. *)
        let path = "docs/canary/overview.html" in
        let matrix_path = "docs/canary/projects/matrix.html" in
        if not (Stdlib.Sys.file_exists path) then true (* not generated yet *)
        else
          let h =
            Stdlib.In_channel.with_open_text path Stdlib.In_channel.input_all
          in
          let matrix_has sub =
            (not (Stdlib.Sys.file_exists matrix_path))
            ||
            let mh =
              Stdlib.In_channel.with_open_text matrix_path
                Stdlib.In_channel.input_all
            in
            String.is_substring mh ~substring:sub
          in
          let count sub =
            let n = String.length sub and len = String.length h in
            let rec go i acc =
              if i + n > len then acc
              else if String.equal (String.sub h ~pos:i ~len:n) sub then
                go (i + n) (acc + 1)
              else go (i + 1) acc
            in
            go 0 0
          in
          let open Canary_agreement in
          let rows = overview_rows () in
          let acts = List.length (overview_columns ()) in
          let arts = List.length overview_artifact_columns in
          let tally f =
            List.sum
              (module Int)
              rows
              ~f:(fun (row : overview_row) ->
                List.count row.ov_cells ~f:(fun (_, m) -> f m))
          in
          (* every table on the page is named. TWO since 2026-09-17:
             the check key was absorbed into the overview, because its
             columns were five of its columns and two of its tooltips. *)
          String.is_substring h ~substring:"agreement overview"
          && not (String.is_substring h ~substring:"The check key")
          (* it is on the methodology page and NOT on the result page,
             so the move cannot decay into a copy on both *)
          && (not (matrix_has "Agreement overview"))
          && matrix_has "The result matrix"
          (* and the result page still POINTS at it — a split that loses
             the link is worse than no split, because the overview is the
             template an empty column there is looked up in *)
          && matrix_has "overview.html"
          (* one ACTION cell per (row × action column) and one TARGET
             cell per (row × artifact column) — both in the `g` family,
             so the total counts them together *)
          && count "class=\"g " = List.length rows * (acts + arts)
          && count "class=\"g rd\""
             = tally (function Rooted_and_detected -> true | _ -> false)
          && count "class=\"g rr\"" = tally (function Rooted -> true | _ -> false)
          && count "class=\"g dd\""
             = tally (function Detected -> true | _ -> false)
          (* the TARGET marks — the artifacts each row ranges over *)
          && count "class=\"g tgt\""
             = List.sum (module Int) rows ~f:(fun (row : overview_row) ->
                   List.length row.ov_reads)
          (* the absorbed columns: fmt per row, and the short code that
             WAS the key's first column *)
          && count "class=\"mk\"" >= List.length rows
          (* WHERE THE CODE IS, one cell per row — and the RED ones are
             exactly the agreements with no evaluator (2026-09-17). The
             count is what makes the colour mean something: if a landed
             agreement ever rendered red the number would move, and a
             red cell that is not a real hole is worse than no column.
             Cross-checked against the registry rather than a literal,
             so implementing one of the three moves both sides. *)
          && count "class=\"impl" = List.length rows
          (* A RED cell is one of OUR rows with no evaluator. An
             external row names a tool, so it is never red however
             unimplemented the claim it answers is — the colour means
             "nobody has written this", and somebody has. *)
          && count "class=\"impl none\""
             = List.count rows ~f:(fun (row : overview_row) ->
                   Option.is_none row.ov_external
                   && Option.is_none (snd (impl_of row.ov_agreement)))
          (* THE EXISTING TOOLS, one row per (tool × claim it answers)
             (2026-09-21, user: "even a tool is mainly for one agreement
             claim, I also wish to have it as a row"). The count is the
             list's, so adding a checker shows up here rather than
             silently rendering nothing. *)
          && count "class=\"impl ext\"" = List.length external_checkers
          && count "class=\"extrow\"" = List.length external_checkers
          (* LANG and MECH, one cell each per row, full terms rather
             than the letter marks they replaced (2026-09-17, user:
             "single letters in mech is not reader-friendly").

             AN EMPTY CELL IS MEANINGFUL HERE — it says the axis does
             not narrow the claim — so the pin counts the cells that
             are BLANK and matches them against the labels, rather than
             only looking for text. A renderer that dropped the column
             entirely would otherwise pass by writing nothing. *)
          && count "class=\"lm\"" = 2 * List.length rows
          && String.is_substring h ~substring:">cstubs<"
          && String.is_substring h ~substring:">ocaml<"
          (* WHERE THE CLAIM COMES FROM, one cell per row (2026-09-17).
             `kind` has its OWN class rather than sharing `lm`'s: three
             cells under one class silently broke the count above, which
             is how the column arrived. Both kinds in use are asserted
             by name, so a registry that stopped distinguishing them —
             every method declared `Declared_facts`, say — fails here
             rather than rendering a constant column. *)
          && count "class=\"kind\"" = List.length rows
          (* the two kinds most of the catalogue is, asserted by name so
             a registry that stopped distinguishing them — every claim
             declared one kind — fails here rather than rendering a
             constant column. They were `declaration` and `peer` until
             2026-09-17, when the vocabulary moved from naming the
             SECOND PARTY to naming the RELATION. *)
          && String.is_substring h ~substring:">admissibility<"
          && String.is_substring h ~substring:">promise<"
          (* THE HARNESS REPORTS ON THE PAGE (2026-09-21, user asked
             where its checking result was). The row audit and the
             saturation grid printed only in the terminal, so the view
             the table is actually read in never said whether it had
             been checked at all. The verdict must be there, and it must
             be the SAME string the audit computes — a page claiming
             "every row obeys them" beside a failing audit would be
             worse than no line. *)
          && String.is_substring h ~substring:"class=\"verdict"
          && String.is_substring h ~substring:(Canary_agreement.overview_verdict ())
          (* and the kind glossary sits ABOVE the data that uses it —
             the whole point of prepending it *)
          && (match
                ( String.substr_index h ~pattern:"class=\"kinds\"",
                  String.substr_index h ~pattern:"class=\"kc\"" )
              with
              | Some glossary, Some first_row -> glossary < first_row
              | _ -> false)
          (* the blank count reads the ROW's labels, not the claim's —
             an external row's axes are the TOOL's, and counting the
             claim's here is the same mistake the renderer made *)
          && count "class=\"lm\"></td>"
             = List.count rows ~f:(fun (row : overview_row) ->
                   String.is_empty (row_lang_label row))
               + List.count rows ~f:(fun (row : overview_row) ->
                     String.is_empty (row_mech_label row))
          && List.for_all agreement_registry ~f:(fun r ->
                 String.is_substring h
                   ~substring:
                     (">"
                     ^ Canary_agreement_common.short_code_of_slug r.ag_slug
                     ^ "</td>"))) }

(* THE CHECK CELL (2026-09-14): the three things it must get right,
   each of which it got wrong at least once while being written.

   (a) the DENOMINATOR counts what the registry slots at that point,
   not what the log mentioned — a cell that counted only what ran would
   read 2/2 and look like full coverage;
   (b) a VIOLATION at one firing site outranks a pass at another, so a
   finding cannot be lost to a later [unavailable];
   (c) an undecided outcome that WAS evaluated ([not_applicable]) is
   distinguishable from one that was never evaluated at all — those
   ranked equal at first, and the fold silently kept its own initial
   value for every rank-0 outcome. *)
let matrix_check_cell_pin : Canary_project_test.pure_test =
  { name = "matrix.check_cell_merges_worst";
    check =
      (fun () ->
        let module S = Canary_status in
        let chain =
          Canary_basic.
            [ Probe_binding Canary_lang.OCaml;
              Fetch (Binding Canary_lang.OCaml) ]
        in
        let ob ?(at = "") ag outcome =
          { S.ao_tag = "probe_binding_ocaml"; ao_agreement = ag;
            ao_method = "m"; ao_outcome = outcome; ao_at = at }
        in
        let world =
          Canary_agreement_common.uniform_world ~lang:Canary_lang.OCaml
            ~mechanism:Canary_mechanism.Cstubs Canary_store.Built
        in
        (* the analysed spec this cell is read against: one OCaml
           cstubs binding, nothing declared. A literal rather than a
           registry project, because the pin is about the MERGE and a
           real project would make its inputs depend on that project's
           declarations. *)
        let an : Canary_project_analysis.t =
          { an_project = "pin";
            an_spec = { Canary_artifact.ps_universe = [] };
            an_chains = [];
            an_declared = None;
            an_mechanisms = [ (Canary_lang.OCaml, Canary_mechanism.Cstubs) ];
            an_unsuited = [];
            an_touches = [];
            an_carries = [] }
        in
        let cell ?(version_points = fun _ -> 1) obs slug =
          Canary_matrix.check_cell ~chain ~obs ~world ~version_points ~an
            (Canary_basic.Probe_binding Canary_lang.OCaml)
            Canary_agreement_common.Pre slug
        in
        let good, _ =
          cell [ ob "required_symbols_exported" "holds" ]
            "required_symbols_exported"
        in
        let na, na_impl =
          cell [ ob "soname_matches_requirement" "not_applicable" ]
            "soname_matches_requirement"
        in
        let bad, bad_impl =
          cell
            [ ob ~at:"t-holds" "required_symbols_exported" "holds";
              ob ~at:"t-violated" "required_symbols_exported" "violated" ]
            "required_symbols_exported"
        in
        let silent, silent_impl = cell [] "required_symbols_exported" in
        (* (a) one cell, one claim — its own outcome, not a count *)
        String.equal good.Canary_matrix.mark "✓"
        && String.equal silent.Canary_matrix.mark "·"
        (* (b) the violation wins over a pass at another firing site —
           and the cell's WHEN is the violation's, not the pass's
           (2026-09-23: the record carries a timestamp per cell, and a
           [when] taken from the losing observation would date a finding
           by a line that found nothing) *)
        && String.equal bad.Canary_matrix.mark "✗"
        && Poly.equal bad.Canary_matrix.recorded
             (Canary_matrix.R_check (Some "violated"))
        && Poly.equal bad.Canary_matrix.at (Some "t-violated")
        && Poly.equal silent.Canary_matrix.recorded (Canary_matrix.R_check None)
        && Option.is_none silent.Canary_matrix.at
        (* (c) evaluated-but-undecided is not silence: not_applicable
           reads as itself, never as "not evaluated". STRENGTHENED
           2026-09-15 — it used to be true only of the tooltip, because
           the MARK was the same dot as silence and the distinction was
           one hover away. The mark carries it now: [stale] for a cell
           whose log predates the registry, [·] for one no run has
           touched. If those two ever collapse back to one glyph this
           goes red, which is the whole point of the pair below. *)
        && String.equal na.Canary_matrix.mark "stale"
        && Option.value_map na.Canary_matrix.detail ~default:false ~f:(fun d ->
               String.is_substring d ~substring:"not_applicable")
        && Option.value_map silent.Canary_matrix.detail ~default:false
             ~f:(fun d -> String.is_substring d ~substring:"not evaluated")
        (* (d) a VIOLATION implicates the artifacts its evidence named,
           and nothing else does. required_symbols_exported is a PEER
           comparison — the stub and the library — so it implicates two
           artifacts and blames neither. *)
        && List.is_empty silent_impl
        && List.is_empty na_impl
        && Poly.equal
             (List.map bad_impl ~f:fst
             |> List.dedup_and_sort ~compare:Stdlib.compare)
             [ Canary_basic.Lib; Canary_basic.Binding Canary_lang.OCaml ]
        && List.for_all bad_impl ~f:(fun (_, slug) ->
               String.equal slug "required_symbols_exported")) }

(* THE KEY EXPLAINS EVERY CODE THE TABLE USES (2026-09-14, user asked
   what harness keeps the page's key and the generated catalogue in
   step). Sharing [Canary_agreement.summary_rows] is the mechanism;
   this is the check. A check column is headed by a code and NOTHING
   else names it, so a column whose code has no key row is unreadable —
   and the failure is silent, because the table still renders.

   It pins the direction that can actually break: every code in use is
   explained. The reverse — a key row for a code no column uses — is
   fine and expected, since the key lists what the registry can decide
   while the columns list what this project's chain reaches. *)
let matrix_key_covers_codes_pin : Canary_project_test.pure_test =
  { name = "matrix.key_explains_every_check_column";
    check =
      (fun () ->
        let m = Canary_matrix.matrix_of Canary_registry.all_projects in
        let known =
          List.map (Canary_agreement.summary_rows ())
            ~f:(fun r -> r.Canary_agreement.sr_code)
        in
        List.for_all m.Canary_matrix.check_columns ~f:(fun c ->
            match String.lsplit2 c ~on:':' with
            | Some (_, code) -> List.mem known code ~equal:String.equal
            | None -> false)) }

(* THE FIXTURE THE RECORD PINS WRITE (2026-09-23, status.md §2.7): a run
   log in the runner's own line shape ([Canary_step_model.create_logger]),
   stamped from a counter so every line's time is distinct and known; one
   script per step state the log can express; and the reading of a state
   back out of the JSON, by field name and independently of the encoder.
   Shared, so the pins cannot come to disagree about what a state is. *)
module Record_fixture = struct
  module S = Canary_status

  let rec mkdir_p dir =
    let parent = Stdlib.Filename.dirname dir in
    if String.equal dir parent || Stdlib.Sys.file_exists dir then ()
    else begin
      mkdir_p parent;
      (try Stdlib.Sys.mkdir dir 0o755 with _ -> ())
    end

  let write path text =
    mkdir_p (Stdlib.Filename.dirname path);
    let oc = Stdlib.open_out path in
    Stdlib.output_string oc text;
    Stdlib.close_out oc

  (* the platform this machine is NOT: a record that answered with the
     renderer's platform fails on either machine *)
  let elsewhere () =
    if String.equal (Canary_matrix.platform_label ()) "wsl_ubuntu" then
      "macos_local"
    else "wsl_ubuntu"

  (* ONE SCRIPT PER STATE the log can express: the lines the runner
     writes for it, and the state they must read as. Every script's last
     line is its verdict. *)
  let scripts ~platform : ((string * string option) list * S.step_state) list
      =
    let xfail_confirmed =
      "expected failure confirmed (derived) [api_names_present]"
    in
    [ ([ ("platform", Some platform); ("done", None) ], S.Ran S.Pass);
      ( [ ("warm_gate", Some "marker + fingerprint + check_post passed");
          ("skip", Some "verdict marker (prior success)") ],
        S.Warm S.Pass );
      ( [ ("platform", Some platform); ("done", Some xfail_confirmed) ],
        S.Ran (S.Xfail [ "api_names_present" ]) );
      ( [ ("platform", Some platform); ("failed", Some "postcondition failed") ],
        S.Ran S.Fail );
      ( [ ("skip", Some "verdict marker (prior xfail) [api_names_present]") ],
        S.Warm (S.Xfail [ "api_names_present" ]) );
      ( [ ("check_pre", Some "FAIL"); ("blocked", Some "precondition failed") ],
        S.Blocked );
      ([], S.Unrecorded);
      (* a RE-RUN: the last verdict wins, and so does its time *)
      ( [ ("platform", Some platform);
          ("failed", Some "postcondition failed");
          ("platform", Some platform); ("done", None) ],
        S.Ran S.Pass ) ]

  type log = { buf : Buffer.t; mutable n : int }

  let create () = { buf = Buffer.create 4096; n = 0 }

  (* one line; returns its stamp *)
  let line (log : log) tag event detail =
    log.n <- log.n + 1;
    let stamp =
      Printf.sprintf "2026-01-01 00:%02d:%02d.000" (log.n / 60)
        (Int.rem log.n 60)
    in
    let padded =
      if String.length tag < 25 then
        tag ^ String.make (25 - String.length tag) ' '
      else tag
    in
    Buffer.add_string log.buf
      (Printf.sprintf "[%s] %s  %s%s\n" stamp padded event
         (match detail with Some d -> "  (" ^ d ^ ")" | None -> ""));
    stamp

  (* one script for [tag]: the stamp of its verdict line, which is the
     WHEN the record must report — [None] when it writes nothing *)
  let play (log : log) ~tag ((lines, _) : (string * string option) list * _) =
    List.fold lines ~init:None ~f:(fun _ (event, detail) ->
        Some (line log tag event detail))

  let save (log : log) ~root ~project =
    write
      (Printf.sprintf "%s/canary/projects/%s/-run/actions.log" root project)
      (Buffer.contents log.buf)

  let uniq xs =
    List.fold xs ~init:[] ~f:(fun acc x ->
        if List.mem acc x ~equal:String.equal then acc else acc @ [ x ])

  let field j k =
    match j with
    | `Assoc kv -> List.Assoc.find kv k ~equal:String.equal
    | _ -> None

  let str j k = match field j k with Some (`String s) -> Some s | _ -> None

  let strs j k =
    match field j k with
    | Some (`List xs) ->
        Some (List.filter_map xs ~f:(function `String s -> Some s | _ -> None))
    | _ -> None

  let items j k = match field j k with Some (`List xs) -> xs | _ -> []

  (* a step state, read back by its field names *)
  let step_state_of_json jc : S.step_state option =
    let verdict =
      match str jc "verdict" with
      | Some "pass" -> Some S.Pass
      | Some "fail" -> Some S.Fail
      | Some "xfail" ->
          Some (S.Xfail (Option.value (strs jc "agreements") ~default:[]))
      | _ -> None
    in
    match (str jc "state", verdict) with
    | Some "ran", Some v -> Some (S.Ran v)
    | Some "warm", Some v -> Some (S.Warm v)
    | Some "blocked", None -> Some S.Blocked
    | Some "unrecorded", None -> Some S.Unrecorded
    | _ -> None
end

(* THE RUN RECORD (2026-09-23, status.md §2.7 phase A). `canary result
   --json` is what the overview will draw recorded runs from, so two
   things must hold, and this pins both against a log it writes itself.

   (1) THE RECORD READS THE LOG. Every step state the log can express
       reaches its cell TYPED — ran, warm, blocked, unrecorded, and each
       verdict — with the timestamp of the line that won, including when
       a re-run replaced an earlier verdict. A claim's outcome is dated
       by a line that reported it. And the row carries the platform the
       RUN logged: the fixture's platform is the one this machine is
       NOT, so a record that answered with the renderer's platform fails
       here on either machine — §2.7 finding 2's rule, that a record
       carries what the run saw, applied to the platform.
   (2) THE EXPORT IS THE MATRIX. The exact text the command prints
       ([json_export]) parses, and decoding it gives back every column
       and every cell — the mark AND the typed value it renders — with
       none added or lost. The decoder is written against the field
       names, independently of the encoder, so a renamed or dropped
       field fails here rather than in the page that reads it.

   zarith supplies the SHAPE — its real scenarios, chains and check
   columns — and the fixture deals the states out over them, so the pin
   follows the project when its chain changes and cannot pass vacuously
   on a checkout that has never run anything. *)
let record_export_pin : Canary_project_test.pure_test =
  { name = "matrix.record_export_is_the_matrix";
    check =
      (fun () ->
        let module S = Canary_status in
        let module M = Canary_matrix in
        let project = "zarith" in
        match
          List.Assoc.find Canary_registry.all_projects project
            ~equal:String.equal
        with
        | None -> false
        | Some pr ->
            let root = "_out/canary/test/record-fixture" in
            let module F = Record_fixture in
            let write = F.write in
            let there = F.elsewhere () in
            let scripts = F.scripts ~platform:there in
            let log = F.create () in
            let line = F.line log in
            let uniq = F.uniq in
            let dealt = ref 0 in
            let expected = Hashtbl.Poly.create () in
            let logged_platform = Hashtbl.Poly.create () in
            let outcome_stamps = ref [] in
            List.iter (Canary_project_run.scenarios_of pr) ~f:(fun a ->
                let scenario =
                  Stdlib.Filename.basename
                    (Canary_project_run.scenario_dir_of ~pr_name:project a)
                in
                ignore (line "*" "variant_start" (Some scenario) : string);
                List.iter
                  (uniq (List.map (M.actions_of pr a) ~f:Canary_basic.string_of_action))
                  ~f:(fun tag ->
                    (* two claims, so the record carries outcomes as well
                       as their absence: a finding where the stub is
                       built, a pass where the program runs *)
                    (if String.equal tag "build_binding_ocaml" then
                       outcome_stamps :=
                         line tag "agreement_outcome"
                           (Some
                              "required_symbols_exported/stub_requirements_vs_library_exports: violated")
                         :: !outcome_stamps);
                    (if String.equal tag "probe_binding_ocaml" then
                       outcome_stamps :=
                         line tag "agreement_outcome"
                           (Some "api_names_present/watchlist_vs_user_surface: holds")
                         :: !outcome_stamps);
                    (* an inspection on disk, so an ARTIFACT cell exists *)
                    write
                      (Printf.sprintf "%s/canary/projects/%s/%s/%s" root project
                         (Canary_basic.step_dir_of_tag tag)
                         (Canary_basic.filename ~variant_key:scenario
                            ~base:"inspect" ~ext:"json"))
                      {|{"kind": "ocaml", "modules": ["A", "B", "C"]}|};
                    let lines, state =
                      List.nth_exn scripts (Int.rem !dealt (List.length scripts))
                    in
                    Int.incr dealt;
                    if List.exists lines ~f:(fun (e, _) -> String.equal e "platform")
                    then Hashtbl.set logged_platform ~key:scenario ~data:();
                    (* the WHEN the cell must carry: the stamp of the
                       script's last line, which is always its verdict *)
                    let last =
                      List.fold lines ~init:None ~f:(fun _ (event, detail) ->
                          Some (line tag event detail))
                    in
                    Hashtbl.set expected ~key:(scenario, tag) ~data:(state, last)));
            F.save log ~root ~project;
            let m = M.matrix_of ~root [ (project, pr) ] in
            let cells =
              List.concat_map m.M.rows ~f:(fun (r : M.row) ->
                  List.filter_map r.M.cells ~f:(fun (tag, c) ->
                      Option.map c ~f:(fun c -> (r, tag, c))))
            in
            (* (1) THE RECORD READS THE LOG *)
            let reads_the_log =
              List.for_all m.M.rows ~f:(fun (r : M.row) ->
                  Poly.equal r.M.recorded_on
                    (if Hashtbl.mem logged_platform r.M.scenario then [ there ]
                     else [])
                  && not (String.equal r.M.platform there))
              && List.for_all cells ~f:(fun ((r : M.row), tag, (c : M.cell)) ->
                     match c.M.recorded with
                     | M.R_act st ->
                         let want_st, want_at =
                           Option.value
                             (Hashtbl.find expected (r.M.scenario, tag))
                             ~default:(S.Unrecorded, None)
                         in
                         Poly.equal st want_st && Poly.equal c.M.at want_at
                         && String.equal c.M.mark (S.mark_of_state st)
                     | M.R_check (Some _) -> (
                         match c.M.at with
                         | Some s -> List.mem !outcome_stamps s ~equal:String.equal
                         | None -> false)
                     | M.R_check None -> Option.is_none c.M.at
                     | M.R_artifact -> String.equal c.M.mark "3 mod")
            in
            (* and not vacuously: every state, both kinds of check cell,
               an artifact cell, and a row that logged its platform *)
            let seen p = List.exists cells ~f:(fun (_, _, c) -> p c.M.recorded) in
            let covers =
              List.for_all scripts ~f:(fun (_, st) ->
                  seen (Poly.equal (M.R_act st)))
              && seen (function M.R_check (Some _) -> true | _ -> false)
              && seen (Poly.equal (M.R_check None))
              && seen (Poly.equal M.R_artifact)
              && List.exists m.M.rows ~f:(fun (r : M.row) ->
                     not (List.is_empty r.M.recorded_on))
            in
            (* (2) THE EXPORT IS THE MATRIX *)
            let export_is_the_matrix =
              match Yojson.Basic.from_string (M.json_export m) with
              | exception _ -> false
              | j ->
                  let field = F.field and str = F.str and strs = F.strs
                  and items = F.items in
                  let recorded kind jc : M.recorded option =
                    match kind with
                    | "action" ->
                        Option.map (F.step_state_of_json jc) ~f:(fun st ->
                            M.R_act st)
                    | "check" -> (
                        match field jc "outcome" with
                        | Some (`String o) -> Some (M.R_check (Some o))
                        | Some `Null -> Some (M.R_check None)
                        | _ -> None)
                    | "artifact" -> Some M.R_artifact
                    | _ -> None
                  in
                  let jcols = items j "columns" in
                  let kind_of_label =
                    List.map jcols ~f:(fun jc ->
                        ( Option.value (str jc "label") ~default:"",
                          Option.value (str jc "kind") ~default:"" ))
                  in
                  let col_ok (c : M.col) jc =
                    let is k v = Poly.equal (str jc k) (Some v) in
                    is "label" (M.label_of_col c)
                    &&
                    match c with
                    | M.Act a ->
                        is "kind" "action"
                        && is "action" (Canary_basic.string_of_action a)
                    | M.Check (a, s, slug) ->
                        is "kind" "check"
                        && is "action" (Canary_basic.string_of_action a)
                        && is "stage" (Canary_agreement_common.string_of_stage s)
                        && is "agreement" slug
                        && is "code"
                             (Canary_agreement_common.short_code_of_slug slug)
                    | M.Artifact a -> (
                        is "kind" "artifact"
                        && is "action" (Canary_basic.string_of_action a)
                        &&
                        match str jc "artifact" with
                        | Some k ->
                            String.is_suffix (M.label_of_col c) ~suffix:("=" ^ k)
                        | None -> false)
                  in
                  let jrows = items j "rows" in
                  Poly.equal (strs j "setting_columns") (Some m.M.setting_columns)
                  && List.length jcols = List.length m.M.typed_columns
                  && List.for_all2_exn m.M.typed_columns jcols ~f:col_ok
                  && List.length jrows = List.length m.M.rows
                  && List.for_all2_exn m.M.rows jrows ~f:(fun (r : M.row) jr ->
                         let jcells =
                           match field jr "cells" with
                           | Some (`Assoc kv) -> kv
                           | _ -> []
                         in
                         let present =
                           List.filter_map r.M.cells ~f:(fun (tag, c) ->
                               Option.map c ~f:(fun c -> (tag, c)))
                         in
                         Poly.equal (str jr "project") (Some r.M.project)
                         && Poly.equal (str jr "scenario") (Some r.M.scenario)
                         && Poly.equal (field jr "index") (Some (`Int r.M.index))
                         && Poly.equal (str jr "code") (Some r.M.code)
                         && Poly.equal (strs jr "recorded_on") (Some r.M.recorded_on)
                         && Poly.equal
                              (match field jr "settings" with
                               | Some (`Assoc kv) ->
                                   List.map kv ~f:(fun (k, v) ->
                                       ( k,
                                         match v with
                                         | `String s -> s
                                         | _ -> "(not a string)" ))
                               | _ -> [])
                              (List.filter_map r.M.settings ~f:(fun (l, s) ->
                                   Option.map s ~f:(fun (s : M.setting) ->
                                       (l, s.M.text))))
                         (* none added, none lost: the same keys, in order *)
                         && Poly.equal (List.map jcells ~f:fst)
                              (List.map present ~f:fst)
                         && List.for_all present ~f:(fun (tag, (c : M.cell)) ->
                                match List.Assoc.find jcells tag ~equal:String.equal with
                                | None -> false
                                | Some jc ->
                                    let kind =
                                      Option.value
                                        (List.Assoc.find kind_of_label tag
                                           ~equal:String.equal)
                                        ~default:""
                                    in
                                    Poly.equal (str jc "mark") (Some c.M.mark)
                                    && Poly.equal (recorded kind jc)
                                         (Some c.M.recorded)
                                    && Poly.equal (str jc "at") c.M.at
                                    && Poly.equal (str jc "detail") c.M.detail
                                    && Poly.equal (str jc "blame") c.M.blame
                                    && String.equal
                                         (Option.value (str jc "provision")
                                            ~default:"")
                                         c.M.provision))
            in
            reads_the_log && covers && export_is_the_matrix) }

(* EVERY STEP OF A WORLD IS IN THE RECORD (2026-09-23, status.md §2.7
   phase B1). The cells hold one entry per action, while the overview
   joins STEPS onto its edges, and a world has more of them: a lib probe
   per location, a package-linked consumer beside the artifact-linked one,
   an inspection after each artifact. Pinned over a log the fixture
   writes, for zarith — whose one probe tag is two different consumer
   programs — and sqlite, whose library is probed at several locations.

   (1) EXACTLY THE WORLD'S STEPS: each row lists the realize pass's
       steps, in its order. Not the log's tags — a tag no current step
       has (the fixture writes one) is history, not a step.
   (2) TYPED AS THE BUILDER TYPED THEM. A probe carries its location and
       nothing else does; an inspection names a step of the same world
       that performs the same action; a probe's tag is the one the
       builder derives from its location, canonical when it is alone.
       And, for zarith, the fact the join rests on: the fetched binding's
       probe is [Pm (Lang_pm opam)], the built binding's [Build_tree].
   (3) IN THE STATE ITS OWN LOG LINE SAYS, dated by that line.
   (4) EXPORTED AS SUCH: the printed JSON decodes to the same steps. *)
let record_steps_pin : Canary_project_test.pure_test =
  { name = "matrix.record_carries_every_step";
    check =
      (fun () ->
        let module M = Canary_matrix in
        let module F = Record_fixture in
        let module SM = Canary_step_model in
        let names = [ "zarith"; "sqlite" ] in
        let projects =
          List.filter_map names ~f:(fun n ->
              Option.map
                (List.Assoc.find Canary_registry.all_projects n
                   ~equal:String.equal)
                ~f:(fun pr -> (n, pr)))
        in
        List.length projects = List.length names
        &&
        let root = "_out/canary/test/steps-fixture" in
        let scripts = F.scripts ~platform:(F.elsewhere ()) in
        (* the steps per world AS THE RUNNER DERIVES THEM — its own call,
           [steps_of] over the scenario's real context, keyed the way the
           rows are. Not [display_steps_of]: the first version of this pin
           compared the record against the very function the record is
           built from, and so could not catch the gap that function had
           (it skipped the declared facts, and every fetched binding lost
           its stub inspection). [~warn:false] only silences a print. *)
        let worlds =
          List.concat_map projects ~f:(fun (project, pr) ->
              List.map (Canary_project_run.scenarios_of pr) ~f:(fun a ->
                  ( project,
                    Stdlib.Filename.basename
                      (Canary_project_run.scenario_dir_of ~pr_name:project a),
                    a,
                    Canary_pipeline.steps_of ~warn:false ~root:"_out/canary" pr
                      ~ctx:(Canary_pipeline.ctx_of pr a) a )))
        in
        let stale = "retired_step_inspect" in
        let dealt = ref 0 in
        let expected = Hashtbl.Poly.create () in
        List.iter projects ~f:(fun (project, _) ->
            let log = F.create () in
            List.iter worlds ~f:(fun (p, scenario, _, steps) ->
                if String.equal p project then begin
                  ignore (F.line log "*" "variant_start" (Some scenario) : string);
                  ignore (F.line log stale "done" None : string);
                  List.iter steps ~f:(fun (s : SM.step) ->
                      let script =
                        List.nth_exn scripts
                          (Int.rem !dealt (List.length scripts))
                      in
                      Int.incr dealt;
                      let at = F.play log ~tag:s.SM.tag script in
                      Hashtbl.set expected ~key:(project, scenario, s.SM.tag)
                        ~data:(snd script, at))
                end);
            F.save log ~root ~project);
        let m = M.matrix_of ~root projects in
        let row_of project scenario =
          List.find m.M.rows ~f:(fun (r : M.row) ->
              String.equal r.M.project project
              && String.equal r.M.scenario scenario)
        in
        let is_probe = function
          | Canary_basic.Probe_lib | Canary_basic.Probe_binding _ -> true
          | _ -> false
        in
        (* (1) exactly the world's steps, and (2) typed as the builder
           typed them *)
        let exact_and_typed =
          List.length m.M.rows = List.length worlds
          && List.for_all worlds ~f:(fun (project, scenario, _, steps) ->
                 match row_of project scenario with
                 | None -> false
                 | Some r -> (
                     let ws = r.M.steps in
                     match List.zip ws steps with
                     | List.Or_unequal_lengths.Unequal_lengths -> false
                     | List.Or_unequal_lengths.Ok pairs ->
                         List.for_all pairs ~f:(fun ((w : M.world_step), s) ->
                             String.equal w.M.ws_tag s.SM.tag
                             && Poly.equal w.M.ws_action s.SM.action
                             && Poly.equal w.M.ws_location s.SM.location
                             && Poly.equal w.M.ws_inspects s.SM.inspects)
                         && (not
                               (List.exists ws ~f:(fun w ->
                                    String.equal w.M.ws_tag stale)))
                         && List.for_all ws ~f:(fun w ->
                                Bool.equal (is_probe w.M.ws_action)
                                  (Option.is_some w.M.ws_location))
                         && List.for_all ws ~f:(fun w ->
                                match w.M.ws_inspects with
                                | None -> true
                                | Some p ->
                                    List.exists ws ~f:(fun p' ->
                                        String.equal p'.M.ws_tag p
                                        && Option.is_none p'.M.ws_inspects
                                        && Poly.equal p'.M.ws_action
                                             w.M.ws_action))
                         &&
                         let probes =
                           List.filter ws ~f:(fun w ->
                               is_probe w.M.ws_action
                               && Option.is_none w.M.ws_inspects)
                         in
                         List.for_all probes ~f:(fun w ->
                             let alone =
                               List.count probes ~f:(fun w' ->
                                   Poly.equal w'.M.ws_action w.M.ws_action)
                               = 1
                             in
                             match (w.M.ws_action, w.M.ws_location) with
                             | _, None -> false
                             | a, Some _ when alone ->
                                 String.equal w.M.ws_tag
                                   (Canary_basic.string_of_action a)
                             | Canary_basic.Probe_lib, Some loc ->
                                 String.equal w.M.ws_tag
                                   (Canary_step_builder.tag_of_probe_lib_location
                                      loc)
                             | Canary_basic.Probe_binding lang, Some loc ->
                                 String.equal w.M.ws_tag
                                   (Canary_step_builder.tag_of_probe_location
                                      ~lang loc)
                             | _ -> false)))
        in
        (* the fact the join rests on: one tag, two consumer programs *)
        let consumer_of (a : Canary_artifact.assignment) (r : M.row) =
          ( List.find_map a ~f:(fun (id, (pl : Canary_artifact.placement)) ->
                match Canary_artifact.kind_of id with
                | Canary_basic.Binding Canary_lang.OCaml ->
                    Some pl.Canary_artifact.provision
                | _ -> None),
            Option.bind
              (List.find r.M.steps ~f:(fun w ->
                   String.equal w.M.ws_tag "probe_binding_ocaml"))
              ~f:(fun w -> w.M.ws_location) )
        in
        let zarith_pairs =
          List.filter_map worlds ~f:(fun (project, scenario, a, _) ->
              if not (String.equal project "zarith") then None
              else Option.map (row_of project scenario) ~f:(consumer_of a))
        in
        let by_package =
          Some
            (Canary_store.Pm
               (Canary_store.Lang_pm
                  { lang = Canary_lang.OCaml; pm = Canary_store.Opam }))
        in
        let linking_typed =
          List.for_all zarith_pairs ~f:(function
            | Some Canary_artifact.Fetched, loc -> Poly.equal loc by_package
            | Some Canary_artifact.Built, loc ->
                Poly.equal loc (Some Canary_store.Build_tree)
            | _ -> true)
          && List.exists zarith_pairs ~f:(fun (p, _) ->
                 Poly.equal p (Some Canary_artifact.Fetched))
          && List.exists zarith_pairs ~f:(fun (p, _) ->
                 Poly.equal p (Some Canary_artifact.Built))
        in
        (* (3) in the state its log line says, at that line's time *)
        let states_ok =
          List.for_all m.M.rows ~f:(fun (r : M.row) ->
              List.for_all r.M.steps ~f:(fun w ->
                  match
                    Hashtbl.find expected (r.M.project, r.M.scenario, w.M.ws_tag)
                  with
                  | None -> false
                  | Some (st, at) ->
                      Poly.equal w.M.ws_state st && Poly.equal w.M.ws_at at))
        in
        (* (4) exported as such *)
        let exported =
          match Yojson.Basic.from_string (M.json_export m) with
          | exception _ -> false
          | j ->
              let jrows = F.items j "rows" in
              List.length jrows = List.length m.M.rows
              && List.for_all2_exn m.M.rows jrows ~f:(fun (r : M.row) jr ->
                     let jsteps = F.items jr "steps" in
                     List.length jsteps = List.length r.M.steps
                     && List.for_all2_exn r.M.steps jsteps ~f:(fun w js ->
                            Poly.equal (F.str js "tag") (Some w.M.ws_tag)
                            && Poly.equal (F.str js "action")
                                 (Some (Canary_basic.string_of_action w.M.ws_action))
                            && Poly.equal (F.str js "location")
                                 (Option.map w.M.ws_location
                                    ~f:Canary_store.string_of_location)
                            && Poly.equal (F.str js "inspects") w.M.ws_inspects
                            && Poly.equal (F.step_state_of_json js)
                                 (Some w.M.ws_state)
                            && Poly.equal (F.str js "at") w.M.ws_at
                            && Poly.equal (F.str js "detail") w.M.ws_detail))
        in
        (* and not vacuously: every state, an inspection, both kinds of
           consumer location, and a library probed at two locations *)
        let all_steps = List.concat_map m.M.rows ~f:(fun r -> r.M.steps) in
        let covers =
          List.for_all scripts ~f:(fun (_, st) ->
              List.exists all_steps ~f:(fun w -> Poly.equal w.M.ws_state st))
          && List.exists all_steps ~f:(fun w -> Option.is_some w.M.ws_inspects)
          && List.exists m.M.rows ~f:(fun (r : M.row) ->
                 List.count r.M.steps ~f:(fun w ->
                     Poly.equal w.M.ws_action Canary_basic.Probe_lib
                     && Option.is_none w.M.ws_inspects)
                 > 1)
        in
        exact_and_typed && linking_typed && states_ok && exported && covers) }

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
        (* the z3 row-shape assertions below read a matrix built over z3's
           SPEC (2026-08-21), so muting z3 out of the run set does not
           silently delete four checks about how its rows render. The
           COUNTS above stay over the active registry — that is what a
           run will actually produce. *)
        let mz3 =
          Canary_matrix.matrix_of
            [ ("z3", Canary_project_z3.z3_run (Canary_basic.detect_distro ())) ]
        in
        let pre_10549_row =
          List.find mz3.Canary_matrix.rows ~f:(fun (r : Canary_matrix.row) ->
              String.equal r.Canary_matrix.scenario
                "source-fetched-pre-10549_lib-built-dev_ocaml_binding-built-dev_python_binding-fetched")
        in
        let arbipher_row =
          List.find mz3.Canary_matrix.rows ~f:(fun (r : Canary_matrix.row) ->
              String.equal r.Canary_matrix.scenario
                "source-fetched-arbipher_lib-built-dev_ocaml_binding-built-dev_python_binding-fetched")
        in
        (* z3's ONE all-fetched world (2026-08-19): the source follows the
           lib's channel, so the Fetched lib pairs only with the stable
           repo — the pre-10549/latest/arbipher fetched rows it used to
           name were phantoms (same lib, same binding, unread source). *)
        let stable_fetched_row =
          List.find mz3.Canary_matrix.rows ~f:(fun (r : Canary_matrix.row) ->
              String.equal r.Canary_matrix.scenario
                "source-fetched-4.15.2_lib-fetched_ocaml_binding-fetched-4.16.0_python_binding-fetched")
        in
        (* the staged twin of the pre-fix ref: the row exists, its
           install_lib cell names the INSTALLED lib, and the Built twin
           above carries no install_lib cell (the exclusivity, read off
           the rendered matrix rather than the action list) *)
        let pre_10549_installed_row =
          List.find mz3.Canary_matrix.rows ~f:(fun (r : Canary_matrix.row) ->
              String.equal r.Canary_matrix.scenario
                "source-fetched-pre-10549_lib-installed-dev_ocaml_binding-built-dev_python_binding-fetched")
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
                          (* the system PM's own name (2026-08-26): the
                             cell renders whichever PM this machine has,
                             so a literal "apt" made a correct macOS
                             render ("lib brew z3.…") read as drift. The
                             SHAPE is what this pin is about — the cell
                             names the pm and the package — not which
                             pm the machine happens to run. *)
                          let pm =
                            Canary_store.string_of_pm
                              (Canary_store.detect_pm ())
                          in
                          String.is_prefix c.Canary_matrix.provision
                            ~prefix:[%string "lib %{pm} z3."]
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
        (* 38 (2026-08-19): sqlite 10 + z3 16 + llvm 3 + tiny-full 1 +
           zarith 2 + cairo 2 + libffi 2 + ssl 2 — cairo and libffi gained
           their VENDORED prebuilt point (the lib pair's latest, downloaded
           from conda-forge), on top of the channel pairs (sqlite +5,
           z3 +9) and the unread-source collapse (llvm −2, zarith −1).
           +2 on 2026-08-20: zlib lands with BOTH lib points at once
           (apt Fetched 1.3 + conda-forge Vendored 1.3.2), the first
           project whose 2×2 lib axis needed no build; +2 the same day for
           zstd, the same shape over a gate that really bounds the lib. *)
        (* PER-PROJECT expected counts, and the total DERIVED from whichever
           projects are active (2026-08-21). The single `= 42` this
           replaces had two problems: muting any project failed it for a
           reason unrelated to drift, and it could not say WHICH project
           moved. Summing a declared table catches both — a changed count
           anywhere fails, and the failure names the project. Every
           catalogued project needs a row here, so adding one to the
           registry without stating its expected shape also fails. *)
        let expected =
          [ ("sqlite", 10); ("z3", 16); ("llvm", 3); ("tiny-full", 1);
            ("zarith", 2); ("cairo", 2); ("libffi", 2); ("zlib", 2);
            ("zstd", 2); ("ssl", 2);
            (* torch's 2 are the binding's two PACKAGING points at one
               upstream version — the stock package (a declared build
               xfail: it does not build with dune 3.23.1) and the
               canary-local patched one. Not a channel pair; the lib axis
               is the one still to grow (2026-08-30 landing). *)
            ("torch", 2) ]
        in
        let catalogued_ok =
          List.for_all Canary_registry.catalogue ~f:(fun n ->
              List.Assoc.mem expected n ~equal:String.equal)
        in
        let per_project_ok =
          List.for_all expected ~f:(fun (n, want) ->
              if not (Canary_registry.is_active n) then true
              else
                let got = List.count rows ~f:(fun (p, _) -> String.equal p n) in
                if got <> want then (
                  Fmt.pr "  matrix rows: %s want %d got %d@." n want got;
                  false)
                else true)
        in
        let want_total =
          List.fold expected ~init:0 ~f:(fun acc (n, want) ->
              if Canary_registry.is_active n then acc + want else acc)
        in
        catalogued_ok && per_project_ok
        && List.length rows = want_total
        && List.mem columns "install_lib" ~equal:String.equal
        && List.mem columns "probe_binding_ocaml" ~equal:String.equal
        && web_identity_ok && staged_cells_ok
        (* the CANONICAL column order (ratchet, 2026-08-18): the
           native/lib group, then per language a same-shaped block
           (binding build/fetch/pack/probe + its app) — probe_app_ocaml
           sits INSIDE the ocaml block, not at the end.

           CHECK SLOTS joined it 2026-09-14: [_pre] immediately before
           its action, then what the action MADE, then the verdicts on
           it — so one action's columns read in the order they mean:
           what it needs, the run, the result, the verdict on the
           result. The artifact precedes the post-checks because a
           verdict printed left of the thing it judges reads
           backwards. Both derived sets come from the registry — [_pre]
           and [_post] from [ag_slot], [_out] from the evidence paths
           the methods name — so a new agreement can add a column here
           and fail this ratchet, which is the point.

           An [_out] column appears only where the action PRODUCES
           something (no probe does) and some agreement reads evidence
           at that action's own tag. That is why probe_lib has none
           despite writing an inspection, and why pack_binding_ocaml
           has none despite producing an artifact. *)
        && String.equal
             (String.concat ~sep:"," m.Canary_matrix.columns)
             (String.concat ~sep:","
                [ "fetch_source"; "configure"; "scan_sources";
                  "build_headers"; "build_lib"; "build_lib=lib";
                  (* dse/dve/smd = declared_symbols_exported,
                     declared_versions_exported,
                     soname_matches_declaration. The code IS the column
                     name; [agreements.short_codes_are_unique] keeps it
                     from meaning two things. *)
                  "build_lib_post:dse"; "build_lib_post:dve";
                  "build_lib_post:smd"; "install_lib"; "install_lib=lib";
                  "install_lib_post:sip"; "fetch_lib"; "probe_lib";
                  (* the off-tree binding-source fetch (2026-08-19): the
                     column appears now that zarith declares its binding's
                     repo as [Binding_source ocaml], and the order key puts
                     it at the FRONT of the ocaml block *)
                  "fetch_binding_source_ocaml";
                  (* OCAML CSTUBS GAINED THREE COLUMNS on 2026-09-15 —
                     dp, rve, smr. They were absent because a [.a]
                     archive records no NEEDED and no symbol versions,
                     which is true of the archive and the wrong
                     artifact to have been asking about: the consumer
                     that runs is the executable the probe links, and
                     it records both. The two language blocks now
                     differ only in [sa], because cstubs spells its
                     boundary as [external] declarations a scanner can
                     read and a cext does not. *)
                  "build_binding_ocaml_pre:dp"; "build_binding_ocaml_pre:rse";
                  "build_binding_ocaml_pre:rve"; "build_binding_ocaml_pre:sa";
                  "build_binding_ocaml_pre:smr";
                  "build_binding_ocaml"; "build_binding_ocaml=ocaml";
                  "fetch_binding_ocaml"; "fetch_binding_ocaml=ocaml";
                  "pack_binding_ocaml"; "probe_binding_ocaml_pre:anp";
                  "probe_binding_ocaml_pre:dp";
                  "probe_binding_ocaml_pre:rse";
                  "probe_binding_ocaml_pre:rve";
                  "probe_binding_ocaml_pre:sa";
                  "probe_binding_ocaml_pre:smr"; "probe_binding_ocaml";
                  (* NOT build_app_ocaml_pre: no registry project
                     declares [build_app], so [api_names_present]'s
                     first candidate is absent from every chain and it
                     falls through to the probe — which is the
                     candidate list doing its job. *)
                  (* no [_post] column on any binding: all three
                     claims that slot there — behavior_matches and the
                     repacking pair — are planned, and a column of
                     dots forever is worse than no column *)
                  "probe_app_ocaml";
                  (* fetch_binding_python appeared 2026-09-12 when sqlite
                     declared a DUMMY install for CPython's stdlib
                     sqlite3 — the step that stands for a binding the
                     interpreter already provides, so the derivation has
                     somewhere to look for its surface inspection. The
                     order key puts it in the python block beside its
                     OCaml twin. *)
                  (* no [sa] in the PYTHON block: signatures_agree
                     reports that no signature extractor exists for a
                     language other than OCaml's stub surface, which is
                     a canary gap worth naming — see landing.md's
                     order. It is stated once by
                     `checks <p> --observed`, not as a column of
                     permanent dots. *)
                  "build_binding_python_pre:dp";
                  "build_binding_python_pre:rse";
                  "build_binding_python_pre:rve";
                  "build_binding_python_pre:smr"; "build_binding_python";
                  "build_binding_python=py"; "fetch_binding_python";
                  "fetch_binding_python=py"; "probe_binding_python_pre:anp";
                  "probe_binding_python_pre:dp";
                  "probe_binding_python_pre:rse";
                  "probe_binding_python_pre:rve";
                  "probe_binding_python_pre:smr"; "probe_binding_python" ])
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

let base_tests : Canary_project_test.pure_test list =
  z3_pins @ llvm_pins
  @ [ z3_lowering_derived; llvm_lowering_derived;
      derived_evidence_matches_projects;
      (* z3's binding no longer follows the lib (2026-08-19) — the
         mismatch-matrix pin below asserts the opposite claim for it;
         llvm still follows, so the lockstep pin still applies there *)
      pm_gate_pin;
      topology_joins_pin;
      topology_graph_pin;
      overview_sections_pin;
      vendored_prebuilt_pin;
      z3_mismatch_matrix_pin;
      binding_follows_chain_pin ~prefix:"llvm" ~spec:(Canary_project_spec.project_spec_of_rows Canary_project_llvm.llvm_artifacts);
      sqlite_runtime_edges_pin; providing_arrow_pin;
      tiny1_bridge;
      integration_smoke;
      registry_pin;
      spec_check_every_project_pin;
      spec_check_ratchet_pin;
      pair_counts_points_pin;
      canary_switch_pin;
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
      vendored_world_probe_pin;
      provider_rows_pin ~prefix:"z3"
        (Canary_project_z3.z3_run (Canary_basic.detect_distro ()));
      z3_install_prefix_isolated_pin;
      z3_env_guard_paths_pin;
      world_assertion_vocabulary_pin;
      pipeline_ctx_pin;
      pipeline_total_pin;
      select_post_filter_pin;
      select_subset_pin;
      select_default_is_identity_pin;
      two_constructions_agree_pin;
      json_per_pass_pin;
      run_order_groups_state_pin;
      z3_cross_cell_world_asserts_pin;
      matrix_cell_stage_pin;
      matrix_setting_block_pin;
      matrix_registry_shape_pin;
      matrix_check_cell_pin;
      matrix_page_has_the_grid_pin;
      one_mechanism_per_language_pin;
      matrix_key_covers_codes_pin;
      record_export_pin;
      record_steps_pin;
      platform_single_source_pin;
      strict_mode_pin;
      check_index_language_pin;
      applicability_reads_declaration_pin;
      touches_join_pin;
      blame_attribution_pin;
      inspect_clash_pin;
      dep_dirs_pin;
      run_info_session_pin;
      machine_roots_pin;
      platform_enumeration_pin;
      demand_prune_pin;
      source_refresh_scope_pin;
      gh_derived_polarity_pin ]

let tests : Canary_project_test.pure_test list = base_tests

