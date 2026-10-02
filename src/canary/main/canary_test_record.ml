(** Tests on the run record: the matrix, the manifest, the exported
    record, and the machines a run is recorded on. *)

open Base
open Canary_test_fixtures

(* The manifest is [Canary_manifest] (design/overview.md §6.4 step 6).
   Held: the codec round-trips every action, location kind, bridge kind
   and package-manager placeholder; every world of every active project
   round-trips; and in a fixture tree, a zarith world whose manifest drops
   a step shows the manifest's steps and says [run], while the other
   world says [code]. *)
let manifest_test : Canary_project_test.pure_test =
  { name = "manifest.records_what_a_run_realized";
    holds = "The record shows each world's steps as its run wrote them in a manifest, re-deriving them from code only where no run wrote one.";
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

(* Carried so a reader of the run need not re-derive the chain. The
   cooperation is [coop_of_world]'s, the mechanism pass 2's. zarith's
   rows exercise both kinds: a bridged chain and an artifact-centric
   one. *)
let record_chains_test : Canary_project_test.pure_test =
  { name = "matrix.record_carries_each_worlds_chain";
    holds = "The record carries each world's chains, one per binding language in order, with the world's cooperation and mechanism, and exports them as such.";
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
        (* a world publishes its binding exactly where a pack step exists:
           the package band reads the declaration without deriving steps,
           so the two must agree. Both answers occur (zarith's built world
           publishes, its fetched world does not). *)
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
        (* what each chain lacks is the world's answer ([world_gone]), and
           a claim applies where one of its edges survives; both are
           exported. zarith's bridged chain carries the bridge's claims;
           its artifact-only chain lacks the bridge and all of them. *)
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

(* A wrong blame hides work or invents it. A check column exists only
   where its claim can be decided, so a non-verdict cell is a defect and
   the blame says whose. An inconclusive declaration comparison found the
   declaration empty, a spec gap; an inconclusive peer comparison found
   nothing of its kind in either artifact, which is [vacuous], the one
   blame that asks for nothing. *)
let blame_attribution_test : Canary_project_test.pure_test =
  { name = "matrix.blame_is_static_and_glossed";
    holds = "A cell's blame depends only on its outcome and what it compared against, a pass blames nothing, and every blame word has a gloss.";
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
        (* a moving axis is seen as moving (sqlite's lib), a thin one as
           thin (zarith's: apt already ships GMP's newest) *)
        let sqlite_moves = points "sqlite" > 1 in
        let zarith_is_thin = points "zarith" = 1 in
        (* inconclusive splits on the reference kind *)
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
        (* a violation is a finding, not a defect, unless the
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
        (* every blame word is glossed, or it would reach a reader as a
           bare noun *)
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

(* [distro_base] looks the roots up in a table the entry declares. That
   works only if nothing resolves a root while modules initialize, the
   property most likely to regress: calling
   [libdir_of pb (detect_distro ())] in a project declaration puts an
   absolute path in a top-level [let]. *)
let machine_roots_test : Canary_project_test.pure_test =
  { name = "machine_roots.declared_at_entry";
    holds = "Machine roots resolve from the table the entry point declares, an undeclared root is an error, and a project declaration needs no root.";
    check =
      (fun () ->
        let saved = !Canary_store.machine_roots in
        let restore () = Canary_store.machine_roots := saved in
        (* the lookup answers for both machines: the cross-render needs
           the other one, which no $HOME could supply *)
        Canary_store.set_machine_roots
          [ (Canary_store.Wsl, "/w"); (Canary_store.MacOS_local, "/m") ];
        let resolves =
          String.equal (Canary_store.distro_base Canary_store.Wsl) "/w"
          && String.equal (Canary_store.distro_base Canary_store.MacOS_local) "/m"
          && String.equal (Canary_store.contrib_root Canary_store.Wsl) "/w/contrib"
        in
        (* undeclared is a failure, not a guess: a fabricated root would
           send a build somewhere real and wrong *)
        Canary_store.machine_roots := [];
        let refuses =
          try
            ignore (Canary_store.distro_base Canary_store.Wsl : string);
            false
          with _ -> true
        in
        (* a declaration needs no root, built here with the table empty.
           A root resolved at module init kills the binary at startup;
           this covers paths init does not take. zlib is the witness: its
           prebuilt lib's libdir is the tempting place to resolve. *)
        let declares_without_roots =
          try
            let pr = Canary_opam_binding.run Canary_project_zlib.decl in
            not (List.is_empty pr.Canary_project_run.pr_artifacts)
          with _ -> false
        in
        restore ();
        resolves && refuses && declares_without_roots) }

(* [detect_env] reads the selection rather than re-probing the box, since
   a record that re-probes describes a different session than its own. *)
let run_info_session_test : Canary_project_test.pure_test =
  { name = "run_info.records_the_session";
    holds = "The run record names the session's selected opam switch and platform rather than re-probing the machine, and calls an unselected switch ambient.";
    check =
      (fun () ->
        let saved_sw = !Canary_store.opam_switch in
        let saved_pl = !Canary_store.platform_override in
        let restore () =
          Canary_store.opam_switch := saved_sw;
          Canary_store.platform_override := saved_pl
        in
        (* a session this machine is not: an overridden platform and a
           named switch, both of which must reach the record *)
        Canary_store.opam_switch := Some "canary";
        Canary_store.set_platform Canary_store.MacOS_local;
        let distro, _pm, switch, _ocaml = Canary_run_info.detect_env () in
        let ok =
          String.equal distro
            (Canary_store.string_of_platform Canary_store.MacOS_local)
          && String.equal switch "canary"
        in
        (* the ambient selection renders as such, not as whatever
           `opam switch show` prints *)
        Canary_store.opam_switch := None;
        let _, _, ambient, _ = Canary_run_info.detect_env () in
        restore ();
        ok && String.equal ambient "(ambient)") }

(* The ref order is the declared repo family order, and each binding
   sorts after the lib. Held over every catalogued project, and exactly
   on z3 under its declared ref order [4.15.2, latest, arbipher,
   pre-10549]. *)
let matrix_row_order_test : Canary_project_test.pure_test =
  { name = "matrix.row_order";
    holds = "In every project, rows follow the declared order of source refs and a fetched lib sorts after the built and staged ones; z3's rows are exactly its declared sequence.";
    check =
      (fun () ->
        let sorted_rows pr =
          List.stable_sort (Canary_project_run.scenarios_of pr) ~compare:(fun x y ->
              Stdlib.compare (Canary_matrix.row_key pr x) (Canary_matrix.row_key pr y))
        in
        let src a = (Canary_enumerate.version_of a Canary_artifact.a_source).Canary_basic.id in
        let fetched_lib a =
          match Canary_enumerate.placement_of a Canary_artifact.a_lib with
          | Some pl -> Poly.equal pl.Canary_artifact.provision Canary_artifact.Fetched
          | None -> false
        in
        (* per project: the declared ref ranks, and the sorted rows *)
        let projects =
          List.map Canary_registry.all_specs ~f:(fun (_, pr) ->
              let spec = Canary_project_spec.project_spec_of_rows pr.Canary_project_run.pr_artifacts in
              let pins =
                Canary_artifact.ps_versions_of spec Canary_artifact.a_source Canary_artifact.Fetched
              in
              let rank id =
                match List.findi pins ~f:(fun _ (b : Canary_basic.build_id) -> String.equal b.Canary_basic.id id) with
                | Some (i, _) -> i
                | None -> List.length pins
              in
              (rank, sorted_rows pr))
        in
        let rec ordered rank = function
          | x :: (y :: _ as rest) ->
              (rank (src x) < rank (src y)
              || (rank (src x) = rank (src y) && ((not (fetched_lib x)) || fetched_lib y)))
              && ordered rank rest
          | _ -> true
        in
        let general_ok = List.for_all projects ~f:(fun (rank, rows) -> ordered rank rows) in
        (* not vacuous: some project's rows span refs, and some ref holds
           a fetched lib beside a built or staged one *)
        let exercised =
          List.exists projects ~f:(fun (rank, rows) ->
              List.length (List.dedup_and_sort (List.map rows ~f:(fun a -> rank (src a))) ~compare:Int.compare) > 1)
          && List.exists projects ~f:(fun (_, rows) ->
                 List.exists rows ~f:fetched_lib
                 && List.exists rows ~f:(fun a ->
                        (not (fetched_lib a)) && Option.is_some (Canary_enumerate.placement_of a Canary_artifact.a_lib)))
        in
        general_ok && exercised
        &&
        (* z3's spec, not its registry entry: row order is a property of
           the enumeration, which exists whether or not z3 is in the run
           set *)
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
        (* per dev ref five rows: the built lib under each binding (dev
           baseline, then backward), the staged lib under each binding,
           and the released lib under the built binding (forward, last
           because a fetched lib sorts last in the lib key). The
           ref-independent both-released baseline leads, on the stable
           ref. *)
        let per_ref r =
          [ (r, Canary_artifact.Built); (r, Canary_artifact.Built);
            (r, Canary_artifact.Installed); (r, Canary_artifact.Installed);
            (r, Canary_artifact.Fetched) ]
        in
        Poly.equal keyed
          (("4.15.2", Canary_artifact.Fetched)
          :: (per_ref "latest" @ per_ref "arbipher" @ per_ref "pre-10549"))) }

(* The ordinal is #N in the rendered order and the code a digest of the
   row's identity, both display only: neither feeds a cache key or
   scenario identity. *)
let matrix_row_index_test : Canary_project_test.pure_test =
  { name = "matrix.row_index";
    holds = "Rows are numbered 1 to N, and each carries a six-character code that is unique and the same every time the matrix is built.";
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

(* A row then reads left to right as the artifact's progression. Held
   over every registry project that enumerates an Installed lib. *)
let matrix_cell_stage_test : Canary_project_test.pure_test =
  { name = "matrix.cell_stage_progression";
    holds = "In a staged world, the build_lib cell names the tree it built and the install_lib and probe_lib cells name the staged lib.";
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
        (* the staged worlds must exist, or every check below is vacuous *)
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

(* The setting block leads each row, and its cells are the row's
   assignment. Held: (a) one column per kind, no duplicates (the
   mechanism rides the artifact id, so deduping by id would double
   `ocaml`/`py`); (b) a cell exists exactly when the project declares
   that kind; (c) no two rows of a project share their setting tuple. *)
let matrix_setting_block_test : Canary_project_test.pure_test =
  { name = "matrix.setting_block_identifies_world";
    holds = "A row's setting cells, one column per artifact kind and filled where its project declares that kind, identify its world within the project.";
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
        (* (c) distinct worlds, distinct tuples *)
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

(* The rows are [overview_rows], and the page's cells are counted
   against their marks, since two renderings of one table drift. The page
   names its tables, and with the old page a pointer, neither table can
   decay into a copy on both. *)
let matrix_page_has_the_grid_test : Canary_project_test.pure_test =
  { name = "matrix.page_titles_and_agreement_overview";
    holds = "The overview page's agreement table carries as many marks of each kind as the registry's rows, and the old result page is only a pointer to it.";
    check =
      (fun () ->
        (* the page as the code renders it now, with §2's table *)
        let h =
          Canary_overview_page.render Canary_registry.all_specs
            ~overview:
              (Canary_agreement_overview.render
                 (Canary_agreement_overview.chains_of
                    (Canary_matrix.matrix_of Canary_registry.all_projects)))
            ~generated_at:"test"
        in
        let matrix_has sub =
          String.is_substring Canary_overview_page.pointer_html ~substring:sub
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
          (* §2 shares §1.2's frame columns (design/overview.md §6.4 step
             4), and its marks are [Canary_frames.row_marks] *)
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
          (* the agreement table is named, and the check key it absorbed
             is gone *)
          String.is_substring h ~substring:{|<h2 id="overview">2. The agreements</h2>|}
          && not (String.is_substring h ~substring:"The check key")
          (* one page (design/overview.md §6.4 step 5): the result table
             is §1.2 here, and the old result page's address is a pointer
             to it that holds neither table *)
          && (not (matrix_has "Agreement overview"))
          && (not (matrix_has "<table"))
          && matrix_has "overview.html#results"
          && String.is_substring h ~substring:{|<h3 id="results">|}
          (* one `g` cell per (row × frame column) *)
          && count "class=\"g " = List.length rows * width
          && count "class=\"g rd\"" = tally "R+D"
          && count "class=\"g rr\"" = tally "R"
          && count "class=\"g dd\"" = tally "D"
          (* the target marks: the nodes each row reads, in its site's frames *)
          && count "class=\"g tgt\"" = tally "▣"
          && count "class=\"g own\"" = tally "◆"
          && own_ok
          (* the format column, absorbed from the key, one cell per row *)
          && count "class=\"mk\"" >= List.length rows
          (* where the code is, one cell per row *)
          && count "class=\"impl" = List.length rows
          (* a red cell is one of our rows with no evaluator, counted from
             the registry; an external row names a tool, so it is never
             red *)
          && count "class=\"impl none\""
             = List.count rows ~f:(fun (row : overview_row) ->
                   Option.is_none row.ov_external
                   && Option.is_none (snd (impl_of row.ov_agreement)))
          (* the existing tools, one row per (tool × claim it answers),
             counted from the list so a new checker cannot silently render
             nothing *)
          && count "class=\"impl ext\"" = List.length external_checkers
          && count "class=\"extrow\"" = List.length external_checkers
          (* lang and mech, one cell each per row, in full terms *)
          && count "class=\"lm\"" = 2 * List.length rows
          && String.is_substring h ~substring:">cstubs<"
          && String.is_substring h ~substring:">ocaml<"
          (* where the claim comes from, one cell per row, in its own
             class so the `lm` count above stays two per row *)
          && count "class=\"kind\"" = List.length rows
          (* the two kinds most of the catalogue is, asserted by name so
             a registry that stopped distinguishing them fails here
             rather than rendering a constant column *)
          && String.is_substring h ~substring:">admissibility<"
          && String.is_substring h ~substring:">promise<"
          (* the page carries the row audit's verdict, the same string
             the audit computes *)
          && String.is_substring h ~substring:"class=\"verdict"
          && String.is_substring h ~substring:(Canary_agreement.overview_verdict ())
          (* the kind glossary sits above the rows that use it *)
          && (match
                ( String.substr_index h ~pattern:"class=\"kinds\"",
                  String.substr_index h ~pattern:"class=\"kc\"" )
              with
              | Some glossary, Some first_row -> glossary < first_row
              | _ -> false)
          (* an empty lang or mech cell means the axis does not narrow the
             row, so the blanks are counted too, from the row's labels:
             an external row's axes are the tool's, not the claim's *)
          && count "class=\"lm\"></td>"
             = List.count rows ~f:(fun (row : overview_row) ->
                   String.is_empty (row_lang_label row))
               + List.count rows ~f:(fun (row : overview_row) ->
                     String.is_empty (row_mech_label row))
          (* every agreement's short code is a cell *)
          && List.for_all agreement_registry ~f:(fun r ->
                 String.is_substring h
                   ~substring:
                     (">"
                     ^ Canary_agreement_common.short_code_of_slug r.ag_slug
                     ^ "</td>"))) }

(* Held: (a) the cell is that claim's own outcome, not a count; (b) a
   violation at one firing site outranks a pass at another, so a finding
   cannot be lost, and it dates the cell; (c) an outcome evaluated but
   undecided ([not_applicable]) is distinguishable from one never
   evaluated; (d) a violation implicates the artifacts its evidence
   named, and nothing else does. *)
let matrix_check_cell_test : Canary_project_test.pure_test =
  { name = "matrix.check_cell_merges_worst";
    holds = "A check cell shows its claim's worst outcome over methods and firing sites, dated by the observation that gave it.";
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
        (* one OCaml cstubs binding, nothing declared: a literal, so the
           merge's inputs do not depend on a real project's declarations *)
        let an : Canary_project_analysis.t =
          { an_project = "test";
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
        (* (a) one cell, one claim *)
        String.equal good.Canary_matrix.mark "✓"
        && String.equal silent.Canary_matrix.mark "·"
        (* (b) the violation wins, and the cell's time is the
           violation's: a time from the losing observation would date a
           finding by a line that found nothing *)
        && String.equal bad.Canary_matrix.mark "✗"
        && Poly.equal bad.Canary_matrix.recorded
             (Canary_matrix.R_check (Some "violated"))
        && Poly.equal bad.Canary_matrix.at (Some "t-violated")
        && Poly.equal silent.Canary_matrix.recorded (Canary_matrix.R_check None)
        && Option.is_none silent.Canary_matrix.at
        (* (c) the mark carries the difference: [stale] for a cell whose
           log predates the registry, [·] for one no run has touched *)
        && String.equal na.Canary_matrix.mark "stale"
        && Option.value_map na.Canary_matrix.detail ~default:false ~f:(fun d ->
               String.is_substring d ~substring:"not_applicable")
        && Option.value_map silent.Canary_matrix.detail ~default:false
             ~f:(fun d -> String.is_substring d ~substring:"not evaluated")
        (* (d) required_symbols_exported compares the stub with the
           library, so its violation implicates both and blames neither *)
        && List.is_empty silent_impl
        && List.is_empty na_impl
        && Poly.equal
             (List.map bad_impl ~f:fst
             |> List.dedup_and_sort ~compare:Stdlib.compare)
             [ Canary_basic.Lib; Canary_basic.Binding Canary_lang.OCaml ]
        && List.for_all bad_impl ~f:(fun (_, slug) ->
               String.equal slug "required_symbols_exported")) }

(* The key is [Canary_agreement.summary_rows]. Only that direction can
   break: the key lists what the registry can decide and the columns what
   the chains reach, so a key row no column uses is expected. *)
let matrix_key_covers_codes_test : Canary_project_test.pure_test =
  { name = "matrix.key_explains_every_check_column";
    holds = "Every check column's short code has a row in the agreement key.";
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

(* The run record (`canary overview --json`) is what the overview draws
   recorded runs from. Over a log the fixture deals across zarith's real
   scenarios: (1) the record reads the log, each step state typed and
   dated by the line that won, each row with the platform the run logged
   (the fixture's is the one this machine is not); (2) the export is the
   matrix: the printed JSON, decoded by field name independently of the
   encoder, gives back every column and cell. *)
let record_export_test : Canary_project_test.pure_test =
  { name = "matrix.record_export_is_the_matrix";
    holds = "The run record reads step states, their times and the run's platform from the log, and its JSON export gives back every column and cell.";
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
                    (* an inspection on disk, so an artifact cell exists *)
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
                    (* the cell's time: the stamp of the script's last
                       line, which is always its verdict *)
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
            (* (1) the record reads the log *)
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
            (* (2) the export is the matrix *)
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

(* The overview joins steps onto its edges, and a world has more of them
   than actions. Over a fixture log for zarith (one probe tag, two
   consumer programs) and sqlite (a library probed at several locations),
   each row (1) lists exactly the world's steps in order, never a log tag
   no step has; (2) types them as the builder did; (3) gives each the
   state and time of its own log line; (4) exports them unchanged. *)
let record_steps_test : Canary_project_test.pure_test =
  { name = "matrix.record_carries_every_step";
    holds = "The record lists exactly a world's steps in order, not one entry per action, each with the state and time of its own log line.";
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
        (* the steps as the runner derives them ([steps_of] over the
           scenario's real context), not [display_steps_of], which the
           record itself uses. [~warn:false] only silences a print. *)
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
           fetched world drives conf-gmp *)
        let bridge_carried =
          List.exists m.M.rows ~f:(fun (r : M.row) ->
              List.exists r.M.steps ~f:(fun w -> Option.is_some w.M.ws_bridge))
        in
        (* the fact the join rests on: one tag, two consumer programs,
           probed through opam when the binding is fetched and in the
           build tree when it is built; both occur *)
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
        (* and not vacuously: every state, an inspection, and a library
           probed at two locations *)
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

(* With the join's result in the record, the overlay draws and computes
   nothing. Held over the real registry: the edges are recomputed here
   from the steps' places, in the graph's order; a listed claim is one
   the graph places, with its check columns and their cells' outcomes,
   none left out; the printed JSON decodes to both. *)
let record_join_test : Canary_project_test.pure_test =
  { name = "matrix.record_joins_edges_and_claims";
    holds = "Each row of the record carries the edges its world realizes with the steps that realize them, and each placed claim with its outcomes.";
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

(* Hermetic: no run data; marks are tested by matrix.marks_from_log.
   Also z3's web identity: the pre-10549 row's ref links the remote
   commit, and its build_lib cell carries the provision B:d. *)
let matrix_registry_shape_test : Canary_project_test.pure_test =
  { name = "matrix.registry_shape";
    holds = "The result table has one row per enumerated scenario, the expected count for each active project, and its columns in the canonical order.";
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
        (* z3's rows are read from a matrix over its spec, so muting z3
           does not delete these checks; the counts above stay over the
           active registry, which is what a run produces *)
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
        (* z3's one all-fetched world: the source follows the lib's
           channel, so a fetched lib pairs only with the stable repo *)
        let stable_fetched_row =
          List.find mz3.Canary_matrix.rows ~f:(fun (r : Canary_matrix.row) ->
              String.equal r.Canary_matrix.scenario
                "source-fetched-4.15.2_lib-fetched_ocaml_binding-fetched-4.16.0_python_binding-fetched")
        in
        (* the staged twin of the pre-fix ref: its install_lib cell names
           the installed lib, and the built twin has no install_lib cell *)
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
              (* the label carries the identity and the version the
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
              (* the fork's label is its identity (arbipher), not the HEAD
                 it shares with latest, so the two HEAD chains render as
                 distinct rows *)
              && (match arbipher_row with
                  | Some ar ->
                      String.equal ar.Canary_matrix.ref_label
                        "arbipher (HEAD)"
                  | None -> false)
              (* the all-fetched world names its providers and versions:
                 the lib is the system PM's package (only the prefix is
                 asserted; the version is the machine's), the binding
                 the opam package at its store pin *)
              && (match stable_fetched_row with
                  | Some fr -> (
                      match
                        List.Assoc.find fr.Canary_matrix.cells "fetch_lib"
                          ~equal:String.equal
                      with
                      | Some (Some c) ->
                          (* the cell names whichever system PM this
                             machine has; the test holds the shape, not
                             the PM *)
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
        (* expected rows per project, from the one count table, the total
           derived from the active ones, so a failure names the project
           that moved *)
        let expected = world_counts in
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
        (* the canonical column order, a ratchet over columns the
           registry derives: the lib group, then one same-shaped block
           per language (binding build, fetch, pack, probe, then its
           app). Per action: its pre-checks, the action, what it made,
           then the post-checks, a verdict after what it judges. An
           artifact column needs an action that produces something and an
           agreement reading evidence at its tag, so no probe has one,
           nor pack_binding_ocaml. *)
        && String.equal
             (String.concat ~sep:"," m.Canary_matrix.columns)
             (String.concat ~sep:","
                [ "fetch_source"; "configure"; "scan_sources";
                  "build_headers"; "build_lib"; "build_lib=lib";
                  (* dse/dve/smd = declared_symbols_exported,
                     declared_versions_exported,
                     soname_matches_declaration. The code is the column
                     name; [agreements.short_codes_are_unique] keeps it
                     from meaning two things. *)
                  "build_lib_post:dse"; "build_lib_post:dve";
                  "build_lib_post:smd"; "install_lib"; "install_lib=lib";
                  "install_lib_post:sip"; "fetch_lib"; "probe_lib";
                  (* the off-tree binding-source fetch (zarith declares
                     its binding's repo as [Binding_source ocaml]) leads
                     the ocaml block *)
                  "fetch_binding_source_ocaml";
                  (* cstubs has dp, rve and smr because they read the
                     executable the probe links, which records NEEDED
                     and symbol versions; the [.a] archive records
                     neither *)
                  "build_binding_ocaml_pre:dp"; "build_binding_ocaml_pre:rse";
                  "build_binding_ocaml_pre:rve"; "build_binding_ocaml_pre:sa";
                  "build_binding_ocaml_pre:smr";
                  "build_binding_ocaml"; "build_binding_ocaml=ocaml";
                  (* gate_admits_the_world: a requirement the install
                     depends on, so it reads in front of the fetch. OCaml
                     only: pip defines no bridge *)
                  "fetch_binding_ocaml_pre:gatw";
                  "fetch_binding_ocaml"; "fetch_binding_ocaml=ocaml";
                  "pack_binding_ocaml"; "probe_binding_ocaml_pre:anp";
                  "probe_binding_ocaml_pre:dp";
                  "probe_binding_ocaml_pre:rse";
                  "probe_binding_ocaml_pre:rve";
                  "probe_binding_ocaml_pre:sa";
                  "probe_binding_ocaml_pre:smr"; "probe_binding_ocaml";
                  (* no build_app_ocaml_pre: no registry project declares
                     [build_app], so [api_names_present] falls through to
                     its next candidate, the probe *)
                  (* no post-check column on any binding: the three
                     claims that slot there (behavior_matches and the
                     repacking pair) are planned, and a planned claim
                     gets no column *)
                  "probe_app_ocaml";
                  (* no [sa] in the python block: a cext has no
                     [external] declarations to scan and no other
                     signature extractor exists; `checks <p> --observed`
                     states the gap once *)
                  "build_binding_python_pre:dp";
                  "build_binding_python_pre:rse";
                  "build_binding_python_pre:rve";
                  "build_binding_python_pre:smr"; "build_binding_python";
                  (* fetch_binding_python is sqlite's dummy install for
                     CPython's stdlib sqlite3, which gives the derivation
                     somewhere to look for its surface inspection *)
                  "build_binding_python=py"; "fetch_binding_python";
                  "fetch_binding_python=py"; "probe_binding_python_pre:anp";
                  "probe_binding_python_pre:dp";
                  "probe_binding_python_pre:rse";
                  "probe_binding_python_pre:rve";
                  "probe_binding_python_pre:smr"; "probe_binding_python" ])
        (* the order key places fetch_binding_source at the front of its
           language's block, after the lib group *)
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
  [ matrix_row_order_test; matrix_row_index_test; matrix_cell_stage_test;
    matrix_setting_block_test; matrix_registry_shape_test; matrix_check_cell_test;
    matrix_page_has_the_grid_test; matrix_key_covers_codes_test; record_export_test;
    record_steps_test; record_join_test; manifest_test; record_chains_test;
    blame_attribution_test; run_info_session_test; machine_roots_test ]
