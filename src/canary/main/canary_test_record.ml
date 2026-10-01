(** Pins on the run record: the matrix, the manifest, the exported
    record, and the machines a run is recorded on. *)

open Base
open Canary_test_fixtures

(* THE RECORD READS WHAT A RUN REALIZED (2026-09-28, design/overview.md
   §6.4 step 6). The runner writes each world's realized steps as a
   manifest ([Canary_manifest]); the record reads it and re-derives from
   today's code only where no run wrote one. Held:

   - the codec is total: every action the type has, every kind of
     location, both kinds of bridge and every placeholder a package
     manager's catalogue names come back as they went in;
   - every world of every active project round-trips: its realized steps,
     written and read back, are the same entries;
   - THE RECORD PREFERS THE MANIFEST. In a fixture tree, one zarith world
     gets a manifest with a step left out: its row shows exactly the
     manifest's steps and says [run]; the other world, with none, is
     re-derived and says [code]. *)
let manifest_pin : Canary_project_test.pure_test =
  { name = "manifest.records_what_a_run_realized";
    check =
      (fun () ->
        let module Mf = Canary_manifest in
        let module M = Canary_matrix in
        let roundtrip e = Poly.equal (Mf.entry_of_json (Mf.json_of_entry e)) (Some e) in
        let bare a =
          { Mf.me_tag = Canary_basic.string_of_action a; me_action = a; me_location = None;
            me_inspects = None; me_dummy = None; me_bridge = None; me_placeholder = None;
            me_deps = [ "x" ] }
        in
        let e0 = bare Canary_basic.Probe_lib in
        let codec_total =
          List.for_all Canary_basic.all_actions ~f:(fun a -> roundtrip (bare a))
          && List.for_all
               Canary_store.
                 [ Build_tree; Staged; Pm (Sys_pm { pm = Apt });
                   Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam }) ]
               ~f:(fun l -> roundtrip { e0 with Mf.me_location = Some l })
          && List.for_all
               Canary_bridge.[ Opam (Conf_package "conf-gmp"); Opam (Depext_field "libtorch") ]
               ~f:(fun b -> roundtrip { e0 with Mf.me_bridge = Some b })
          && List.for_all Mf.pms ~f:(fun pm ->
                 List.for_all
                   (Canary_pm_action.inside_install pm ~of_binding:true
                   @ Canary_pm_action.inside_install pm ~of_binding:false)
                   ~f:(fun ph -> roundtrip { e0 with Mf.me_placeholder = Some ph }))
          && roundtrip { e0 with Mf.me_inspects = Some "fetch_lib"; me_dummy = Some "nothing" }
        in
        let worlds_roundtrip =
          List.for_all Canary_registry.all_projects ~f:(fun (_, pr) ->
              List.for_all (Canary_project_run.scenarios_of pr) ~f:(fun a ->
                  List.for_all (Canary_pipeline.display_steps_of pr a) ~f:(fun s ->
                      roundtrip (Mf.of_step s))))
        in
        let prefers_the_manifest =
          let root = "_out/canary/test/manifest-fixture" in
          ignore (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" (Stdlib.Filename.quote root)) : int);
          let pr = Canary_project_zarith.zarith_run in
          match Canary_project_run.scenarios_of pr with
          | a :: b :: _ ->
              let scenario w =
                Stdlib.Filename.basename (Canary_project_run.scenario_dir_of ~pr_name:"zarith" w)
              in
              let steps = Canary_pipeline.display_steps_of pr a in
              let dropped = List.last_exn steps in
              let kept =
                List.filter steps ~f:(fun s -> not (phys_equal s dropped))
              in
              Mf.write ~root ~project:"zarith" ~scenario:(scenario a) kept;
              let m = M.matrix_of ~root [ ("zarith", pr) ] in
              let row w =
                List.find m.M.rows ~f:(fun r -> String.equal r.M.scenario (scenario w))
              in
              let tags r = List.map r.M.steps ~f:(fun w -> w.M.ws_tag) in
              (match (row a, row b) with
               | Some ra, Some rb ->
                   String.equal ra.M.steps_from "run"
                   && List.equal String.equal (tags ra)
                        (List.map kept ~f:(fun s -> s.Canary_step_model.tag))
                   && String.equal rb.M.steps_from "code"
                   && List.equal String.equal (tags rb)
                        (List.map (Canary_pipeline.display_steps_of pr b) ~f:(fun s ->
                             s.Canary_step_model.tag))
               | _ -> false)
          | _ -> false
        in
        codec_total && worlds_roundtrip && prefers_the_manifest)
  }

(* THE RECORD CARRIES EACH WORLD'S CHAIN (2026-09-23, status.md §2.7):
   per binding language, the mechanism, both sides and the cooperation —
   so a reader of the run need not re-derive them. Held over the real
   registry:

   - one chain per binding language of the row's project, in order;
   - each is the WORLD's (its cooperation is [coop_of_world] for that
     row's assignment) with pass 2's mechanism;
   - exported as such;
   - exercised both ways: zarith's rows carry a bridged chain and an
     artifact-centric one. *)
let record_chains_pin : Canary_project_test.pure_test =
  { name = "matrix.record_carries_each_worlds_chain";
    check =
      (fun () ->
        let module M = Canary_matrix in
        let module T = Canary_topology in
        let m = M.matrix_of Canary_registry.all_projects in
        let typed =
          List.for_all m.M.rows ~f:(fun (r : M.row) ->
              match Canary_overview_runs.assignment_of_row r with
              | None -> false
              | Some (pr, a) ->
                  let an = Canary_pipeline.analysed_of pr in
                  let langs = T.binding_langs pr in
                  List.length r.M.chains = List.length langs
                  && List.for_all2_exn r.M.chains langs ~f:(fun c lang ->
                         Poly.equal c.M.ch_lang lang
                         && Poly.equal c.M.ch_coop (T.coop_of_world ~pr ~world:a lang)
                         && Poly.equal c.M.ch_mechanism
                              (Canary_project_analysis.mechanism_for an lang)))
        in
        let exported =
          match Yojson.Basic.from_string (M.json_export m) with
          | exception _ -> false
          | j ->
              let items j k =
                match j with
                | `Assoc kv -> (
                    match List.Assoc.find kv k ~equal:String.equal with
                    | Some (`List xs) -> xs
                    | _ -> [])
                | _ -> []
              in
              let str j k =
                match j with
                | `Assoc kv -> (
                    match List.Assoc.find kv k ~equal:String.equal with
                    | Some (`String s) -> Some s
                    | _ -> None)
                | _ -> None
              in
              let jrows = items j "rows" in
              List.length jrows = List.length m.M.rows
              && List.for_all2_exn m.M.rows jrows ~f:(fun (r : M.row) jr ->
                     let js = items jr "chains" in
                     List.length js = List.length r.M.chains
                     && List.for_all2_exn r.M.chains js ~f:(fun c jc ->
                            Poly.equal (str jc "cooperation") (Some (T.code_of_coop c.M.ch_coop))
                            && Poly.equal (str jc "mechanism")
                                 (Some (Canary_mechanism.string_of_mechanism c.M.ch_mechanism))))
        in
        let zarith_kinds =
          List.concat_map m.M.rows ~f:(fun (r : M.row) ->
              if String.equal r.M.project "zarith" then
                List.map r.M.chains ~f:(fun c -> c.M.ch_coop)
              else [])
        in
        (* THE WRAPPER DECLARATION SAYS WHAT THE STEPS DO: a world publishes
           its binding exactly where a pack step exists. The package band
           reads the declaration (it is drawn without deriving steps); this
           is what keeps it the same answer. Exercised: zarith's built
           world publishes, its fetched world does not. *)
        let publishing =
          List.concat_map m.M.rows ~f:(fun (r : M.row) ->
              match Canary_overview_runs.assignment_of_row r with
              | None -> [ None ]
              | Some (pr, a) ->
                  List.map (T.binding_langs pr) ~f:(fun lang ->
                      let declared = T.publishes_of_world ~pr ~world:a lang in
                      let stepped =
                        List.exists r.M.steps ~f:(fun w ->
                            Poly.equal w.M.ws_action
                              (Canary_basic.Publish (Canary_basic.Binding lang))
                            && Option.is_none w.M.ws_inspects)
                      in
                      if Bool.equal declared stepped then Some declared else None))
        in
        (* WHAT EACH CHAIN LACKS, AND WHICH CLAIMS APPLY TO IT: the world's
           own answer ([world_gone]), and a claim applies where one of its
           edges survives — exported as such. Exercised: zarith's bridged
           chain carries the bridge's claims, its artifact-only chain has
           no bridge and none of them *)
        let bridge_claims =
          [ "gate_admits_the_world"; "declared_gate_matches_package";
            "gate_bounds_the_library"; "depext_names_the_provided_package" ]
        in
        let lacks =
          List.for_all m.M.rows ~f:(fun (r : M.row) ->
              match Canary_overview_runs.assignment_of_row r with
              | None -> false
              | Some (pr, a) ->
                  let gones = T.world_gone ~pr ~world:a in
                  List.for_all r.M.chains ~f:(fun c ->
                      Poly.equal (Some c.M.ch_gone)
                        (List.Assoc.find gones c.M.ch_lang ~equal:Poly.equal)
                      && List.equal String.equal c.M.ch_claims
                           (T.claims_of_chain ~gone:c.M.ch_gone)))
        in
        let lacks_exported =
          match Yojson.Basic.from_string (M.json_export m) with
          | exception _ -> false
          | j ->
              let strs j k =
                match j with
                | `Assoc kv -> (
                    match List.Assoc.find kv k ~equal:String.equal with
                    | Some (`List xs) ->
                        List.filter_map xs ~f:(function `String s -> Some s | _ -> None)
                    | _ -> [])
                | _ -> []
              in
              let items j k =
                match j with
                | `Assoc kv -> (
                    match List.Assoc.find kv k ~equal:String.equal with
                    | Some (`List xs) -> xs
                    | _ -> [])
                | _ -> []
              in
              List.for_all2_exn m.M.rows (items j "rows") ~f:(fun (r : M.row) jr ->
                  List.for_all2_exn r.M.chains (items jr "chains") ~f:(fun c jc ->
                      List.equal String.equal (strs jc "gone") c.M.ch_gone
                      && List.equal String.equal (strs jc "applicable_claims") c.M.ch_claims))
        in
        let zarith_chain k =
          List.find_map m.M.rows ~f:(fun (r : M.row) ->
              if String.equal r.M.project "zarith" then
                List.find r.M.chains ~f:(fun c -> Poly.equal c.M.ch_coop k)
              else None)
        in
        let bridge_where_bridged =
          match (zarith_chain T.Co_conf, zarith_chain T.Co_artifacts) with
          | Some bridged, Some bare ->
              List.for_all bridge_claims ~f:(List.mem bridged.M.ch_claims ~equal:String.equal)
              && (not (List.mem bridged.M.ch_gone "bridge" ~equal:String.equal))
              && List.mem bare.M.ch_gone "bridge" ~equal:String.equal
              && not (List.exists bridge_claims ~f:(List.mem bare.M.ch_claims ~equal:String.equal))
          | _ -> false
        in
        typed && exported && lacks && lacks_exported && bridge_where_bridged
        && List.mem zarith_kinds T.Co_conf ~equal:Poly.equal
        && List.mem zarith_kinds T.Co_artifacts ~equal:Poly.equal
        && List.for_all publishing ~f:Option.is_some
        && List.mem publishing (Some true) ~equal:(Option.equal Bool.equal)
        && List.mem publishing (Some false) ~equal:(Option.equal Bool.equal))
  }

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
          (* THE FRAME COLUMNS since 2026-09-28 (design/overview.md §6.4
             step 4): §2 shares §1.2's header, and its marks are
             [Canary_frames.row_marks] *)
          let width =
            List.sum (module Int) Canary_frames.frames ~f:(fun fr ->
                List.length fr.Canary_frames.fr_columns)
          in
          let marks = List.concat_map rows ~f:(fun row -> List.concat (Canary_frames.row_marks row)) in
          let tally w = List.count marks ~f:(String.equal w) in
          (* a checked claim shows ◆ at each of its sites, a planned one at
             none — the join between the registry and the frames *)
          let own_ok =
            List.for_all rows ~f:(fun (row : overview_row) ->
                let slug = row.ov_agreement.ag_slug in
                let own = List.count (List.concat (Canary_frames.row_marks row)) ~f:(String.equal "◆") in
                if List.exists Canary_frames.checked_rows ~f:(fun r -> String.equal r.ag_slug slug)
                then own = List.length (Canary_frames.sites_of slug)
                else own = 0)
          in
          (* every table on the page is named. TWO since 2026-09-17:
             the check key was absorbed into the overview, because its
             columns were five of its columns and two of its tooltips. *)
          String.is_substring h ~substring:{|<h2 id="overview">2. The agreements</h2>|}
          && not (String.is_substring h ~substring:"The check key")
          (* ONE PAGE since 2026-09-28 (user; design/overview.md §6.4 step
             5): the result table is §1.2 of this page, and the old
             result page's address is a pointer landing there — it holds
             neither table, so nothing can decay into a copy on both *)
          && (not (matrix_has "Agreement overview"))
          && (not (matrix_has "<table"))
          && matrix_has "overview.html#results"
          && String.is_substring h ~substring:{|<h3 id="results">|}
          (* one ACTION cell per (row × action column) and one TARGET
             cell per (row × artifact column) — both in the `g` family,
             so the total counts them together *)
          && count "class=\"g " = List.length rows * width
          && count "class=\"g rd\"" = tally "R+D"
          && count "class=\"g rr\"" = tally "R"
          && count "class=\"g dd\"" = tally "D"
          (* the TARGET marks — the nodes each row reads, in its site's frames *)
          && count "class=\"g tgt\"" = tally "▣"
          && count "class=\"g own\"" = tally "◆"
          && own_ok
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

(* THE RUN RECORD (2026-09-23, status.md §2.7 phase A). The record
   (`canary overview --json`) is what the overview draws recorded runs from, so two
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
                             && Poly.equal w.M.ws_inspects s.SM.inspects
                             && Poly.equal w.M.ws_bridge s.SM.bridge)
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
        (* the bridge field is carried, not vacuously absent: zarith's
           fetched world drives conf-gmp (status.md §2.7 E) *)
        let bridge_carried =
          List.exists m.M.rows ~f:(fun (r : M.row) ->
              List.exists r.M.steps ~f:(fun w -> Option.is_some w.M.ws_bridge))
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
                            && Poly.equal (F.str js "bridge")
                                 (Option.map w.M.ws_bridge
                                    ~f:Canary_bridge.to_string)
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
        exact_and_typed && linking_typed && states_ok && exported && covers
        && bridge_carried) }

(* THE JOIN'S RESULT IS IN THE RECORD (2026-09-23, status.md §2.7 phase
   B2). Each row carries the edges its world realizes, with the steps that
   realize them, and each placed claim with its outcomes — so the overlay
   draws and computes nothing. Over the real registry:

   (1) the row's edges ARE its steps' places, grouped by edge in the
       graph's order — recomputed here from the steps, so the two views
       cannot drift;
   (2) a claim listed is one the graph places, each column is a check
       column of that very agreement, its outcome is that cell's, and no
       such column of the row is left out;
   (3) the printed JSON decodes to both, unchanged. *)
let record_join_pin : Canary_project_test.pure_test =
  { name = "matrix.record_joins_edges_and_claims";
    check =
      (fun () ->
        let module M = Canary_matrix in
        let module T = Canary_topology in
        let module F = Record_fixture in
        let m = M.matrix_of Canary_registry.all_projects in
        let placed_claims =
          List.map T.claim_sites ~f:(fun cs -> cs.T.cs_claim)
        in
        let slug_of_label label =
          List.find_map m.M.typed_columns ~f:(fun c ->
              match c with
              | M.Check (_, _, slug) when String.equal (M.label_of_col c) label ->
                  Some slug
              | _ -> None)
        in
        let row_ok (r : M.row) =
          let expected_edges =
            List.filter_map T.edges ~f:(fun e ->
                let tags =
                  List.filter_map r.M.steps ~f:(fun w ->
                      match w.M.ws_place with
                      | T.On ids when List.mem ids e.T.eg_id ~equal:String.equal ->
                          Some w.M.ws_tag
                      | _ -> None)
                in
                if List.is_empty tags then None else Some (e.T.eg_id, tags))
          in
          let check_cells_of_placed_claims =
            List.filter_map r.M.cells ~f:(fun (label, c) ->
                match (c, slug_of_label label) with
                | Some (c : M.cell), Some slug
                  when List.mem placed_claims slug ~equal:String.equal ->
                    Some (label, slug, c)
                | _ -> None)
          in
          Poly.equal r.M.edges expected_edges
          && List.for_all r.M.claims ~f:(fun (slug, outcomes) ->
                 List.mem placed_claims slug ~equal:String.equal
                 && List.for_all outcomes ~f:(fun (label, o) ->
                        List.exists check_cells_of_placed_claims
                          ~f:(fun (l, s, c) ->
                            String.equal l label && String.equal s slug
                            && Poly.equal c.M.recorded (M.R_check o))))
          && List.for_all check_cells_of_placed_claims ~f:(fun (label, slug, _) ->
                 match List.Assoc.find r.M.claims slug ~equal:String.equal with
                 | Some outcomes ->
                     List.Assoc.mem outcomes label ~equal:String.equal
                 | None -> false)
        in
        let exported =
          match Yojson.Basic.from_string (M.json_export m) with
          | exception _ -> false
          | j ->
              let jrows = F.items j "rows" in
              List.length jrows = List.length m.M.rows
              && List.for_all2_exn m.M.rows jrows ~f:(fun (r : M.row) jr ->
                     let edges =
                       match F.field jr "edges" with
                       | Some (`Assoc kv) ->
                           List.map kv ~f:(fun (id, v) ->
                               ( id,
                                 match v with
                                 | `List xs ->
                                     List.filter_map xs ~f:(function
                                       | `String s -> Some s
                                       | _ -> None)
                                 | _ -> [] ))
                       | _ -> []
                     in
                     let claims =
                       match F.field jr "claims" with
                       | Some (`Assoc kv) ->
                           List.map kv ~f:(fun (slug, v) ->
                               ( slug,
                                 match v with
                                 | `List xs ->
                                     List.map xs ~f:(fun x ->
                                         ( Option.value (F.str x "column") ~default:"",
                                           F.str x "outcome" ))
                                 | _ -> [] ))
                       | _ -> []
                     in
                     Poly.equal edges r.M.edges && Poly.equal claims r.M.claims)
        in
        let realized id =
          List.exists m.M.rows ~f:(fun (r : M.row) ->
              List.Assoc.mem r.M.edges id ~equal:String.equal)
        in
        List.for_all m.M.rows ~f:row_ok
        && exported
        && realized "run" && realized "run_packaged"
        && List.exists m.M.rows ~f:(fun (r : M.row) -> not (List.is_empty r.M.claims)))
  }

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
                  (* gate_admits_the_world (2026-09-27): a requirement
                     the install depends on, so it reads in front of the
                     fetch. OCaml only — pip defines no bridge, so the
                     python block has no such column *)
                  "fetch_binding_ocaml_pre:gatw";
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

let tests : Canary_project_test.pure_test list =
  [ matrix_row_order_pin; matrix_row_index_pin; matrix_cell_stage_pin;
    matrix_setting_block_pin; matrix_registry_shape_pin; matrix_check_cell_pin;
    matrix_page_has_the_grid_pin; matrix_key_covers_codes_pin; record_export_pin;
    record_steps_pin; record_join_pin; manifest_pin; record_chains_pin;
    blame_attribution_pin; run_info_session_pin; machine_roots_pin ]
