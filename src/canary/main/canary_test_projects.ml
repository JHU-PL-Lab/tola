(** Pins on the projects: each spec's worlds, bindings and providers, the
    registry, the spec audit and the tiny factory. *)

open Base
module B = Canary_basic
module EN = Canary_enumerate

let py_cext = Canary_artifact.a_binding Canary_lang.Python Canary_mechanism.Cext
let py_ctypes =
  Canary_artifact.a_binding Canary_lang.Python Canary_mechanism.Ctypes

(* The scenario-identity key. A Fetched artifact is version-ambient (the
   package manager picks the version), so its declared channel is not
   part of the key unless the placement carries a store pin; Built and
   Vendored versions always are. Mirrors
   [Canary_project_run.scenario_dir_of]; change both together. *)
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

(** A project's declared source artifact: [a_source] when its repos carry
    the C lib (cairo, libffi, z3, llvm), [a_binding_source lang] when they
    carry a binding's source (zarith). Pins asking for the source's pinned
    ref ask the project rather than assume [a_source]. *)
let source_artifact_of (pr : Canary_project_run.project_run) :
    Canary_artifact.artifact_info =
  Option.value
    (List.find (Canary_project_run.artifact_infos pr) ~f:(fun id ->
         match Canary_artifact.kind_of id with
         | Canary_basic.Source | Canary_basic.Binding_source _ -> true
         | _ -> false))
    ~default:Canary_artifact.a_source

(* The pins for a project whose worlds come from a family of source repos
   (z3, llvm): the enumerated world counts and the dispatch. [source_of]
   is the project's own [source_for_assignment]; [dispatch_is_dev] says
   whether a world builds from source, which is the built family (Built
   or Installed: an Installed world builds, then stages), the gate
   [realize_from_rows] puts on the build rows. [n_staged] counts the
   Installed worlds, [n_forward] the forward cells. *)
let two_chain_pins ~(prefix : string) ~(spec : Canary_artifact.project_spec)
    ~(artifacts : Canary_project_spec.artifact_row list)
    ~(source_of : Canary_artifact.assignment -> Canary_artifact_source.source_repo)
    ~(dispatch_is_dev : Canary_artifact.assignment -> bool)
    ?(n_worlds = 5) ?(n_dev = 2) ?(n_stable = 3) ?(n_staged = 0)
    ?(n_forward = 0) () : Canary_project_test.pure_test list =
  (* [artifacts] is unused, kept in the signature as the declared rows
     for a pin that reads the declaration rather than the enumeration *)
  ignore artifacts;
  let lib_prov a = Canary_enumerate.provision_of a Canary_artifact.a_lib in
  (* the build chain: a Built@Dev lib over any dev source ref *)
  let is_dev a =
    EN.equal_provision (lib_prov a) EN.Built
    && Canary_basic.equal_channel
         (Canary_enumerate.version_of a Canary_artifact.a_lib).Canary_basic.channel
         Canary_basic.Dev
    && Canary_basic.equal_channel
         (Canary_enumerate.version_of a Canary_artifact.a_source).Canary_basic.channel
         Canary_basic.Dev
  in
  (* the staged face: an Installed lib over a dev source *)
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
  (* the both-released baseline: Fetched lib and source, and a binding
     that is not built (a Fetched lib under a built binding is the
     forward cell) *)
  let is_stable_world a =
    EN.equal_provision (lib_prov a) EN.Fetched
    && EN.equal_provision (Canary_enumerate.provision_of a Canary_artifact.a_source) EN.Fetched
    && not (binding_built a)
  in
  (* the forward cell: the released lib under a binding built from a dev
     tree *)
  let is_forward a =
    EN.equal_provision (lib_prov a) EN.Fetched && binding_built a
  in
  [ (* The enumeration is the project's world set: each bucket has the
       count the caller gives, the buckets partition the worlds, and the
       head is the both-released baseline. *)
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
        (* the buckets partition the worlds, so none slips past the
           counts *)
        && n_dev + n_stable + n_staged + n_forward = n_worlds
        (* each world has its own identity *)
        && List.length scenario_ids = n_worlds
        (* the python binding row is variant-invariant: Fetched everywhere *)
        && List.for_all asgs ~f:(fun a ->
               EN.equal_provision (Canary_enumerate.provision_of a py_ctypes) EN.Fetched)
        (* channel coupling: no Built lib over the stable source *)
        && (not
              (List.exists asgs ~f:(fun a ->
                   EN.equal_provision (lib_prov a) EN.Built
                   && Canary_basic.equal_channel
                        (Canary_enumerate.version_of a Canary_artifact.a_source).Canary_basic.channel
                        Canary_basic.Stable)))
        (* baseline (enumeration head) = the all-Fetched stable chain *)
        && match asgs with x :: _ -> is_stable_world x | [] -> false) };
    (* The dispatch is pure data over the enumeration: [source_of] picks
       the repo by the source placement's pinned id, and a world builds
       from source exactly when its lib is in the built family. [realize]
       is not called: its command templates shell out to detect the
       distro and package manager. *)
    { name = prefix ^ ".dispatch_reads_source_placement";
      check = (fun () ->
        let asgs = enumerate_full spec in
        let cases = List.map asgs ~f:dispatch_is_dev in
        List.count cases ~f:Fn.id = n_dev + n_staged
        (* the non-building worlds: the baseline and the forward cells,
           a platform lib under a built binding *)
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

let built_family a =
  let pv = Canary_enumerate.provision_of a Canary_artifact.a_lib in
  Canary_enumerate.equal_provision pv Canary_artifact.Built
  || Canary_enumerate.equal_provision pv Canary_artifact.Installed

let z3_pins : Canary_project_test.pure_test list =
  (* Sixteen worlds. The binding's channel is its own axis, so each of the
     three dev refs carries the (lib, binding) cells, with B = Built,
     I = Installed, F = Fetched. The both-released baseline is one world:
     nothing is built there, so the source ref is unread.
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
    (* Three worlds: two dev build chains and one both-released baseline
       (the unread-source collapse, {!Canary_enumerate.source_ref_ok}).
       llvm's binding follows the lib, so it has no forward or backward
       cells. *)
    ~n_worlds:3 ~n_dev:2 ~n_stable:1 ()

(* z3's and llvm's derived expectations, over their real binding tables. *)

let sm_is_success = function
  | Canary_step_model.Expect_success -> true
  | _ -> false

let pip_loc =
  Some
    (Canary_store.Pm
       (Canary_store.Lang_pm { lang = Canary_lang.Python; pm = Canary_store.Pip }))

(* z3's expectation is derived at the Python probe under pip and is
   success everywhere else; the runner's inspection of the wheel decides
   at run time. *)
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

(* llvm's expectation is derived at the OCaml probe from the merged
   inputs, and the Python probe expects success (llvmlite bundles its own
   lib). Each input lists the pack or build-tree path first: resolution
   reads the first that exists, so the dev chain reads its own built
   binding, predicts nothing and expects success. *)
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
           (* dev-chain exemption: pack or build-tree path first *)
           && List.for_all inputs ~f:(function
                | Canary_agreement_common.C_stub (p :: _)
                | Canary_agreement_common.Ocaml_mli (p :: _) ->
                    String.is_prefix p ~prefix:"pack_binding_ocaml/"
                | Canary_agreement_common.Native_lib (p :: _) ->
                    String.is_prefix p ~prefix:"probe_lib/"
                | _ -> true)
       | _ -> false)
      && sm_is_success (lower (B.Probe_binding Canary_lang.Python) pip_loc)) }

(* The evidence path the framework derives for a binding's inspection is
   the one the projects' hand-written tables name: the output dir of the
   step that installs the binding. A derivation that reproduces the
   tables can replace them; this fails when it stops reproducing them. *)
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
      (* ssl: an opam-fetched OCaml binding. Its second firing reads
         inspect_nlv.json, a project-specific view of the same artifact,
         so only the step tag is compared. *)
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
      (* tiny and the opam-binding template pass no world (an Absent
         binding) and mean the build tree, as a built binding does *)
      let workspace_ok =
        String.equal (derived_tag Canary_lang.OCaml Canary_store.Built)
          "build_binding_ocaml"
        && String.equal (derived_tag Canary_lang.OCaml Canary_store.Absent)
             "build_binding_ocaml"
      in
      (* llvm is the named exception: it packs its built binding into
         opam and inspects the published package, and nothing declares
         that a project publishes, so its table names pack_binding_ocaml
         where the derivation says build_binding_ocaml. Once publishing
         is declared this fails, and llvm's table can go. *)
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

(* Declared runtime edges (the spec rows' [ax_runtime]) resolve to a
   pairing in each world. On sqlite, Python is ambient in every world (no
   run placement, never a deploy pairing); the OCaml pairing's run lib is
   the world's lib placement, and the built-family worlds are deploy
   pairings (canary supplies the run lib under a fetched binding). *)
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
      (* the lib's 5 placements (2 built, 2 installed, 1 fetched) × 2 opam
         pins *)
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
         (* the built-family worlds: 4 lib placements × 2 binding pins *)
         = 8) }

(* A project whose distro ships one lib version gets its latest point as
   a downloaded prebuilt, declared [Vendored]. Checked on libffi and
   cairo: (a) both points enumerate, Fetched (the system package manager)
   and Vendored (the prebuilt); (b) the two worlds read different files,
   since a Vendored world that fell back to the system lib would pass
   unnoticed (cairo's two versions export identical symbol counts); (c)
   the lib row carries a rationale, also on zarith, which declares no
   prebuilt: a one-point axis says why. *)
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
          (* (b) they read different files: the lib probe … *)
          && List.for_all vendored ~f:(fun a ->
                 String.is_substring (lib_probe_cmd pr a)
                   ~substring:pb.PB.tag)
          && List.for_all fetched ~f:(fun a ->
                 not
                   (String.is_substring (lib_probe_cmd pr a)
                      ~substring:pb.PB.tag))
          (* … and the binding probe: a plain `ocamlfind -package` run
             resolves the ambient copy, so the Vendored world's probe must
             name the prebuilt *)
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
        (* (c) including the project that declares no prebuilt *)
        && Option.is_none
             Canary_project_zarith.decl.Canary_opam_binding.prebuilt_latest
        && rationale_ok Canary_project_zarith.zarith_run
        && rationale_ok Canary_project_libffi.libffi_run
        && rationale_ok Canary_project_cairo.cairo_run) }

(* Every declared binding carries a package-manager gate: how its package
   declares its dependency on the C lib, which decides what it takes to
   force a combination opam would not pick. Checked: (a) every binding of
   an external project is gated; (b) each project's measured group, so a
   spec edit that reclassifies one fails here; (c) the combination
   freedom derived from each kind of gate. *)
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
          (* cairo and libffi carry no binding_decl (the opam-binding
             template builds none), so their gates are read from the
             template record *)
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
          (* zlib and zstd both declare a bare conf dependency, but
             conf-zstd's check is a pkg-config version floor that reaches
             the library, while conf-zlib's only checks presence *)
          && Poly.equal Canary_project_zlib.decl.Canary_opam_binding.pm_gate
               (BD.Free_with_conf "conf-zlib")
          && Poly.equal Canary_project_zstd.decl.Canary_opam_binding.pm_gate
               (BD.Bounded_with_conf
                  { conf = "conf-zstd";
                    lower = Some "1.3.8";
                    upper = None;
                    tracks_lib = true })
          (* so the two derive different freedoms, through tracks_lib *)
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
        (* (c) the freedom derivation *)
        let freedom_ok =
          Poly.equal
            (BD.combination_freedom_of (BD.Free_with_conf "conf-gmp"))
            BD.Any_version
          && Poly.equal
               (BD.combination_freedom_of
                  (BD.Fixed_with_conf
                     { conf = "conf-llvm-shared"; version = "19" }))
               (BD.Wrapper_needed "conf-llvm-shared")
          (* a bound on a conf package reaches the library only when the
             conf package's own check enforces a version ([tracks_lib]):
             conf-libffi's build is a bare `pkg-config libffi`, so its
             bound is packaging only; conf-libclang passes the version to
             its configure.sh, a real bound on clang *)
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
        (* (a) no external project's declared binding is left ungated *)
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

(* z3's mismatch matrix: the binding's channel is free of the lib's, so
   each dev ref carries the (lib, binding) cells. (a) Per dev ref, the
   forward cell (released lib, built binding) and the backward cell
   (built lib, released binding) exist; (b) the both-released baseline
   exists once, since nothing is built there and the source ref is
   unread; (c) cross-channel pairs survive; (d) a built binding still
   matches its source's channel ({!binding_couples}). *)
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
        (* (c) a cross-channel pair exists *)
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

(* The OCaml binding's [ax_follows:a_lib] keeps its channel equal to the
   lib's in every world. Applied to llvm, whose binding follows its lib. *)
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
      && (* the constraint does work: the spec declares both provisions
            for the OCaml binding, yet no cross-channel pair survives *)
      (not
         (List.exists asgs ~f:(fun a ->
              Canary_enumerate.provided a ocaml && Canary_enumerate.provided a lib
              && not
                   (Canary_basic.equal_channel
                      (Canary_enumerate.channel_of a ocaml)
                      (Canary_enumerate.channel_of a lib)))))) }

(* [scenarios_of] gives sqlite, z3, llvm and tiny-full their expected
   world counts. Pure: no builds, no package manager. *)
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
      (* the lib's 5 placements × 2 opam pins *)
      let ok1 = check ~name:"sqlite" ~want_count:10
          Canary_project_sqlite.sqlite_run in
      (* see z3_pins *)
      let ok2 = check ~name:"z3" ~want_count:16
          (Canary_project_z3.z3_run (Canary_basic.detect_distro ())) in
      (* 2 dev chains and one both-released baseline *)
      let ok3 = check ~name:"llvm" ~want_count:3
          (Canary_project_llvm.llvm_run (Canary_basic.detect_distro ())) in
      let ok4 = check ~name:"tiny-full" ~want_count:1
          Canary_project_tiny.tiny_full_run in
      ok1 && ok2 && ok3 && ok4) }

(* Every registry entry is a catalogue name and enumerates to a non-empty
   world set; ssl's binding enumerates two worlds, one per store pin, and
   zarith's source repos two, one per channel. *)
let registry_pin : Canary_project_test.pure_test =
  { name = "registry.entries_enumerate";
    check = (fun () ->
      let entries = Canary_registry.all_projects in
      let names = List.map entries ~f:fst in
      (* subset, not equality: an entry can be commented out to mute an
         expensive project; a name missing from the catalogue (a typo, an
         unregistered project) still fails *)
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
      (* ssl: two worlds, one per binding store pin *)
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
      (* zarith: two worlds, one per source repo, each keeping its
         channel *)
      let zarith_axes_ok =
        match List.Assoc.find entries "zarith" ~equal:String.equal with
        | None -> false
        | Some pr ->
            let asgs = Canary_project_run.scenarios_of pr in
            let src (a : Canary_artifact.assignment) =
              (* zarith's declared source is the binding's *)
              Canary_enumerate.version_of a (source_artifact_of pr)
            in
            (* the forward cell (binding built from master) and the
               both-released baseline *)
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

(* tiny1 scenarios run through the general pipeline. Part A: a tiny1
   scenario as a [project_run] (every artifact Vendored, canary knowing
   nothing of the mutation) enumerates to one world, and its runner_spec
   carries the agnostic expectation. Part B: wherever the oracle says
   must-fail, the agnostic expectation is not blind; the reverse need not
   hold. Part C: every xfail tag of [canary_expected_of] parses back to
   an action. *)
let tiny1_bridge : Canary_project_test.pure_test =
  { name = "tiny1.project_run_and_oracle_cover";
    check = (fun () ->
      let module CS = Canary_scenario in
      let module SM = Canary_step_model in
      let module TS = Canary_tiny_scenario in
      let module SB = Canary_step_builder in
      (* Part A: a tiny1 scenario as a project_run *)
      (* a dummy runner_spec with the agnostic expectation: the real one
         ([project_run_of_tiny1]) shells out *)
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
      (* not blind at the OCaml probe: derived or must-fail, never
         [Expect_success] *)
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
      (* Part B: the agnostic expectation covers the oracle *)
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
      (* Part C: the xfail tags parse back to actions *)
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

(* tiny's binding declarations state the same facts as its hand-written
   ones: the shared C API and native facts, each mechanism's coupling,
   and the surface paths the inspectors read. *)
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
          && (* cstubs: the stub archive the hand-written build produces *)
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

(* The binding realization ([Canary_binding_templates]) emits the exact
   commands captured from tiny's hand-written runner spec, over synthetic
   stores (source /WS, lib /WS/c/build, cext root /WS/python_cext). A
   change to the realization fails here, and the diff is the behaviour
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
          (* probe_binding: dune build+exec / cext runtime probe. The
             loader variable is per-platform, so the expected command
             asks [ld_only], as the template does. *)
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

(* Every registry entry yields a well-formed spec-check report: twelve
   items, none with an empty id. *)
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

(* Each project's spec-check report has exactly the Error, Warn and Na
   item sets listed here; closing a gap fails this until the list is
   updated. *)
let spec_check_ratchet_pin : Canary_project_test.pure_test =
  let open Canary_spec_check in
  let ids sev r =
    List.filter_map r.items ~f:(fun i ->
        if Poly.equal i.severity sev then Some i.item_id else None)
    |> List.sort ~compare:String.compare
  in
  let want ~errs ~warns ~na name =
    (* [all_specs], not [all_projects]: a muted project is still
       audited *)
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
  (* the opam-binding template's warns: no binding decl, no Built binding
     axis, no binding pair, no wrapper package, no Python binding. The
     template sets `versions = None` on the opam provider, so such a
     project can declare a lib pair (a prebuilt) but not a second binding
     point. *)
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
        (* ssl's lib_pair warn is a to-do: openssl has an obtainable
           second point (a conda-forge prebuilt), unlike zarith's GMP *)
        && want ~errs:[]
             ~warns:
               [ "binding_dev_source"; "dev_wrapper_package"; "lib_pair";
                 "python_binding" ]
             ~na:[ "raw_build_overrides" ] "ssl"
        (* zarith: lib_pair is permanent, since apt already ships GMP's
           newest release (the row's rationale says so); binding_dev_source
           because no binding_api says where the source of its built
           binding is; python_binding because it is OCaml-only *)
        && want ~errs:[]
             ~warns:[ "binding_dev_source"; "lib_pair"; "python_binding" ]
             ~na:[] "zarith"
        && want ~errs:[] ~warns:pat_warns ~na:[ "raw_build_overrides" ] "cairo"
        && want ~errs:[] ~warns:pat_warns ~na:[ "raw_build_overrides" ] "libffi"
        && want ~errs:[] ~warns:pat_warns ~na:[ "raw_build_overrides" ] "zlib"
        && want ~errs:[] ~warns:pat_warns ~na:[ "raw_build_overrides" ] "zstd"
        (* tiny-full warns on both pairs: the in-tree witness enumerates
           one world. It is exempt from the reporting checks, not from the
           pairs. *)
        && want ~errs:[]
             ~warns:[ "binding_dev_source"; "binding_pair";
                      "dev_wrapper_package"; "lib_pair" ]
             ~na:[ "github_remote"; "opam_package";
               "raw_build_overrides" ] "tiny-full") }

(* z3 and llvm, built from source, are Heavy, and the batch runs them
   thin (the stable worlds only, bypassing the dev builds); the listed
   cheap projects are Light and run in full. *)
let batch_tier_pin : Canary_project_test.pure_test =
  { name = "registry.batch_tiers";
    check =
      (fun () ->
        (* z3 and llvm are read from their specs, so muting one in the
           registry does not drop its check *)
        let z3 = Canary_project_z3.z3_run (Canary_basic.detect_distro ()) in
        let llvm = Canary_project_llvm.llvm_run (Canary_basic.detect_distro ()) in
        let pr_of name =
          List.Assoc.find_exn Canary_registry.all_projects name
            ~equal:String.equal
        in
        let tier name = (pr_of name).Canary_project_run.pr_tier in
        Poly.equal z3.Canary_project_run.pr_tier Canary_project_run.Heavy
        && Poly.equal llvm.Canary_project_run.pr_tier Canary_project_run.Heavy
        (* the Light set is checked over the active projects *)
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

(* A repo's main checkout lies under the contrib root, and a worktree is
   named by the official repo name plus the ref slug, path separators
   slugged away (doc/canary/design/enumeration/stage1_declare_spec.md). *)
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

(* A local-only fork (a label, no remote) is a spec-check warning, not an
   error: a fork need not be pushed. An official repo without a remote
   stays an error. *)
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

(* The pair checks count points, (provision, version) after store-pin
   expansion, not universe cells or channels. (a) Two store pins in one
   Fetched cell and one channel, the way ssl and sqlite declare their
   binding pair, are a pair, which a cell or channel count gets wrong;
   (b) the same row with one pin is not, which a check that ignores pins
   gets wrong; (c) a lib with two cells is a pair. *)
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
        (* (a) two store pins, one cell, one channel: the ssl and sqlite
           shape *)
        let a =
          pr ~lib_universe:one_lib
            ~binding_universe:
              [ (opam_binding (Some [ pin "0.6.0"; pin "0.7.0" ]),
                 [ Canary_basic.Stable ]) ]
        in
        (* (b) the same row with one pin *)
        let b =
          pr ~lib_universe:one_lib
            ~binding_universe:
              [ (opam_binding (Some [ pin "0.6.0" ]), [ Canary_basic.Stable ]) ]
        in
        (* (c) a two-cell lib (apt and a prebuilt): the zlib and cairo
           shape *)
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

(* In every active project, each non-source artifact with a [Repo]
   provider appears in that repo's [artifacts]. *)
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

(* A [Repo_axes] family's repos become the source row's store pins: one
   identity-bearing world per repo, each keeping its channel, and each
   world's fetch command names its own repo's worktree ref. A single-repo
   family (cairo) is pinned to its ref too. *)
let repo_axes_pin : Canary_project_test.pure_test =
  { name = "repo_model.axes_pins";
    check =
      (fun () ->
        (* the project's own source artifact: zarith's is the OCaml
           binding's ([source_artifact_of]) *)
        let source_version pr a =
          Canary_enumerate.version_of a (source_artifact_of pr)
        in
        let zarith_asgs = Canary_project_run.scenarios_of Canary_project_zarith.zarith_run in
        let zarith_ok =
          (* the forward cell (binding built from master) and the
             both-released baseline *)
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
        (* each world's fetch command checks out its repo's worktree ref;
           zarith's source is the binding's, so the command is in
           [fetch_binding_source], not [fetch_source] *)
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
          (* cairo's two worlds (system lib, vendored prebuilt) share the
             source ref, so check it on the system-lib one *)
          match
            List.filter
              (Canary_project_run.scenarios_of Canary_project_cairo.cairo_run)
              ~f:(fun a ->
                Canary_artifact.equal_provision
                  (Canary_enumerate.provision_of a Canary_artifact.a_lib)
                  Canary_artifact.Fetched)
          with
          | [ a ] ->
              (* cairo's repo is the C lib's: it keeps [a_source] *)
              String.equal
                (source_version Canary_project_cairo.cairo_run a)
                  .Canary_basic.id "1.18.0"
          | _ -> false
        in
        zarith_ok && cmds_ok && cairo_ok) }

(* In zarith's forward cell (binding built from master) the OCaml probe
   carries a derived compat expectation, so a break against the system
   lib is a predicted finding, not a raw failure; the other worlds carry
   none. Pure: the realization only builds closures. *)
let forward_cell_expectation_pin : Canary_project_test.pure_test =
  { name = "repo_model.forward_cell_expectation";
    check =
      (fun () ->
        let module SM = Canary_step_model in
        let pr = Canary_project_zarith.zarith_run in
        let bind_art =
          Canary_artifact.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs
        in
        (* the agreement's inputs resolve under the step's own dir,
           build_binding/ocaml, where it writes its summary; a lang-less
           tag would name build_binding/, which nothing writes *)
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
              (* every stub candidate (the framework's inspect_stub.json,
                 tiny's inspect.json) lies under the binding's step dir *)
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

(* zarith's wrapper Publish is wired in the worlds whose binding is built,
   and only there: a pack_binding OCaml entry and a pin-checked
   postcondition on Publish. *)
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

(* tiny's [project_run] carries its three binding declarations, looked up
   by the artifact's mechanism; a non-binding artifact looks up [None]. *)
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

(* sqlite's binding declarations match its declared spec: the native
   prefix, soname and headers, the c_api as the native watchlist, each
   mechanism's coupling, and the OCaml surface path. *)
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

(* zarith's declaration wraps the system GMP with an empty prefix: its API
   spans mpz_, mpq_, mpf_ and mpn_, so the stub-required watchlist does
   the scoping. Its c_api is that whole surface, 42 functions. *)
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

(* The z3 #10549 regression: at the pre-fix ref the install cannot stage
   the OCaml package. Install_lib declares the expected failure (the
   OCAML INSTALL MISSING signature, version_info naming the fix) at that
   ref only, and the staged consumer's probe declares
   STAGED PACKAGE MISSING in that ref's Installed world only. *)
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
        (* the staged consumer; the Built world's probe passes, since the
           build tree has the package *)
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
        (* the staged world of the pre-fix ref with a built binding; the
           other staged cell consumes the released opam package *)
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
        (* the world must exist, or the check below is vacuous *)
        List.exists scenarios ~f:is_staged_world
        && List.for_all scenarios ~f:(fun a ->
               Bool.equal (declared_signature (probe_exp a))
                 (is_staged_world a))) }

(* z3's worlds assert the libz3 their probe loads. The Built and
   Installed worlds assert different directories (else the pair is one
   world twice), and no asserted path carries a `..` segment: the probe
   reports the path the loader resolved, which an unnormalised spelling
   never matches. *)
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
        (* both worlds must assert something, or the checks below are
           vacuous *)
        (not (List.is_empty built))
        && (not (List.is_empty installed))
        (* ...and they must not name the same place *)
        && List.for_all built ~f:(fun b ->
               not (List.mem installed b ~equal:String.equal))
        (* ...and nothing carries an unresolved `..` *)
        && List.for_all (built @ installed) ~f:(fun d ->
               not (String.is_substring d ~substring:".."))) }

(* z3's env guard names a real directory. The Build_binding row's
   [env_guard] puts the freshly built <build>/src/api/ml first on
   CAML_LD_LIBRARY_PATH, so z3's POST_BUILD self-check does not load the
   opam switch's stale dllz3ml.so. No path in it contains `//` (a prefix
   glued onto an absolute path), and it still names the build tree.
   Checked over every declared z3 source. *)
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
        (* every repo has a guard, or the checks below are vacuous *)
        List.length guards = List.length repos
        && List.for_all guards ~f:(fun (g, build) ->
               (* no prefix glued onto an absolute path *)
               (not (String.is_substring g ~substring:"//"))
               (* ...and it still points at the build tree *)
               && String.is_substring g ~substring:build
               && String.is_substring g ~substring:"CAML_LD_LIBRARY_PATH"
               && String.is_substring g ~substring:"/src/api/ml")) }

(* No two of z3's declared repos stage into the same install prefix, or
   one ref's staged OCaml package would satisfy another ref's staged
   probe and the #10549 xfail would stop firing. Each prefix is named
   after its ref, and the build dirs are distinct too. Read off the rows'
   [Cmake_install] prefix field, not a parsed command. *)
let z3_install_prefix_isolated_pin : Canary_project_test.pure_test =
  { name = "z3.install_prefix_isolated";
    check =
      (fun () ->
        let module AT = Canary_action_templates in
        let distro = Canary_basic.detect_distro () in
        (* compare resolved paths: two spellings with `..` segments can
           name one directory *)
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
        (* and each is named after its ref (install-<id>), so isolation
           follows from unique ref ids; checked on the resolved basename *)
        && List.for_all repos ~f:(fun repo ->
               match prefix_of repo with
               | Some prefix ->
                   String.equal
                     (Stdlib.Filename.basename (normalize prefix))
                     ("install-"
                     ^ repo.Canary_artifact_source.version.Canary_basic.id)
               | None -> false)
        (* the build dirs are distinct too: a shared build dir is two
           worlds writing one tree *)
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

(* z3's Installed world's OCaml probe consumes the staged package
   (<prefix>/lib/ocaml/z3 and <prefix>/lib/libz3.so, with the
   STAGED PACKAGE MISSING guard the declared expectation greps), while the
   Built world's reads the build tree (src/api/ml) and names no prefix:
   the realization half {!provider_rows_pin} cannot derive. *)
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
          (* only a built binding's probe reads a tree; the released
             binding's probe is the opam one *)
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
        (* both faces must be populated, or the checks below are vacuous;
           each reads only its own tree *)
        (not (List.is_empty staged))
        && (not (List.is_empty build_tree))
        (* staged prefixes are per-ref (install-<id>), so match the
           shape *)
        && List.for_all staged ~f:(fun c ->
               String.is_substring c ~substring:"/install-"
               && String.is_substring c ~substring:"/lib/ocaml/z3"
               && String.is_substring c ~substring:"/lib/libz3.so"
               && String.is_substring c ~substring:"STAGED PACKAGE MISSING")
        && List.for_all build_tree ~f:(fun c ->
               String.is_substring c ~substring:"src/api/ml"
               && (not (String.is_substring c ~substring:"STAGED PACKAGE"))
               && not (String.is_substring c ~substring:"/install-"))) }

(* z3's and llvm's declarations match what they ship: the wheel-bundled
   Python bindings are Ctypes, loaded by Dlopen; the OCaml cstubs facts
   match the built products (z3's stubs come from a .pre code-gen
   template); both declare raw cmake/ninja OCaml builds. *)
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

(* A project with an Installed lib universe enumerates exclusive rows,
   derived from its declaration and {!Canary_matrix.row_key}: (a) the
   Built and Installed universes declare the same channels; (b) per
   source-ref group, rows run build then install in channel order,
   fetched last; (c) each group has as many Installed rows as Built, or
   one that lost its staged row would still pass (b); (d) Install_lib
   fires exactly when the lib is Installed. *)
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
        (* (b) and (c), per ref group *)
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
          (* a (channel, provision) owns several adjacent rows when
             another artifact has an axis (sqlite's binding pins): the
             order compares distinct blocks, the twin count every row *)
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

(* sqlite's Installed world's OCaml probe reads the staged lib
   (<ws>/install/lib) and the Built world's reads the build tree: the
   realization half {!provider_rows_pin} cannot derive. *)
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
      pm_gate_pin;
      vendored_prebuilt_pin;
      z3_mismatch_matrix_pin;
      (* llvm only: z3's binding does not follow its lib *)
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
      (* per project with an Installed universe: sqlite (one ref group)
         and z3 (one group per declared repo) *)
      provider_rows_pin ~prefix:"sqlite" Canary_project_sqlite.sqlite_run;
      sqlite_staged_probe_paths_pin;
      provider_rows_pin ~prefix:"z3"
        (Canary_project_z3.z3_run (Canary_basic.detect_distro ()));
      z3_install_prefix_isolated_pin;
      z3_env_guard_paths_pin;
      z3_cross_cell_world_asserts_pin ]
