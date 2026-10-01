(** Pins on the projects: each spec's worlds, bindings and providers, the
    registry, the spec audit and the tiny factory. *)

open Base
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
          pr_pm_gates = [];
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
            pr_pm_gates = [];
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
            pr_binding_decls = []; pr_pm_gates = []; pr_raw_build_overrides = [];
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

let tests : Canary_project_test.pure_test list =
  z3_pins @ llvm_pins
  @ [ z3_lowering_derived; llvm_lowering_derived;
      derived_evidence_matches_projects;
      (* z3's binding no longer follows the lib (2026-08-19) — the
         mismatch-matrix pin below asserts the opposite claim for it;
         llvm still follows, so the lockstep pin still applies there *)
      pm_gate_pin;
      vendored_prebuilt_pin;
      z3_mismatch_matrix_pin;
      binding_follows_chain_pin ~prefix:"llvm" ~spec:(Canary_project_spec.project_spec_of_rows Canary_project_llvm.llvm_artifacts);
      sqlite_runtime_edges_pin;
      tiny1_bridge;
      integration_smoke;
      registry_pin;
      spec_check_every_project_pin;
      spec_check_ratchet_pin;
      pair_counts_points_pin;
      batch_tier_pin;
      repo_model_pin;
      local_fork_pin;
      repo_contents_pin;
      repo_axes_pin;
      forward_cell_expectation_pin;
      publish_wired_pin;
      tiny_binding_realization_pin;
      binding_decl_pin;
      binding_decls_on_project_run_pin;
      sqlite_binding_decls_pin;
      z3_llvm_binding_decls_pin;
      zarith_binding_decls_pin;
      z3_regression_pre_10549_pin;
      z3_installed_probe_consumes_prefix;
      (* the GENERAL factory, instantiated per project that declares an
         Installed universe: sqlite (one ref group) and z3 (one group per
         declared repo) — the same derived invariants over both shapes *)
      provider_rows_pin ~prefix:"sqlite" Canary_project_sqlite.sqlite_run;
      sqlite_staged_probe_paths_pin;
      provider_rows_pin ~prefix:"z3"
        (Canary_project_z3.z3_run (Canary_basic.detect_distro ()));
      z3_install_prefix_isolated_pin;
      z3_env_guard_paths_pin;
      z3_cross_cell_world_asserts_pin ]
