(** Tests on the overview page: its model, what it draws, its tables, the
    exported exhibits, and the agreement views it reads. *)

open Base
open Canary_test_fixtures

(* Were [Canary_topology.join_of]'s joins collapsed, an unreachable
   declaration and a deliberate absence would render alike, so each
   clause names the project that is the specimen of its constructor, and
   a project changing its declaration fails here rather than quietly
   moving rows. *)
let topology_joins_test : Canary_project_test.pure_test =
  { name = "topology.joins_are_distinguished";
    holds = "Joins between a binding and its library stay distinct: bridged, absorbed, no package manager between and undeclared each have a specimen project.";
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
        (* z3's opam package builds libz3: the bridge is absorbed, not
           absent *)
        && is_absorbed (join "z3" Canary_lang.OCaml)
        && is_absorbed (join "z3" Canary_lang.Python)
        (* sqlite's Python side is CPython's stdlib: a declaration exists
           and says no package manager is in between *)
        && is_no_pm (join "sqlite" Canary_lang.Python)
        (* ...while sqlite's OCaml side does declare a conf package *)
        && is_bridged (join "sqlite" Canary_lang.OCaml)
        (* these four leave pr_binding_decls empty and are bridged by the
           gate the template routes ([pr_pm_gates]); no registry project
           is Undeclared, so an un-routed copy of cairo exercises it *)
        && List.for_all
             [ "cairo"; "libffi"; "zlib"; "zstd" ]
             ~f:(fun p -> is_bridged (join p Canary_lang.OCaml))
        && (match List.Assoc.find Canary_registry.all_specs "cairo" ~equal:String.equal with
            | Some pr ->
                is_undeclared
                  (Some
                     (T.join_of
                        { pr with Canary_project_run.pr_pm_gates = [] }
                        Canary_lang.OCaml))
            | None -> false)
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

(* [Canary_topology.claim_sites] is hand-written, and a renamed agreement
   or edge would leave a claim site pointing at nothing while the page
   carried on drawing a count. An action with no edge is a hole in the
   model, so those actions are listed. *)
let topology_graph_test : Canary_project_test.pure_test =
  { name = "topology.graph_matches_the_registry";
    holds = "The layered graph agrees with the agreement registry and the action catalogue.";
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
        (* the multi-edge structure is in use: the declaration-facing lib
           claims sit on both producers of the library node *)
        && List.exists T.claim_sites ~f:(fun p -> List.length p.T.cs_edges > 1)
        (* the bare-relation census excludes observations such as
           probe_lib, which records evidence rather than relating two
           parties *)
        && List.for_all (T.bare_edges ()) ~f:(fun e -> not e.T.eg_observation)
        (* each annotation is well formed: an action family the catalogue
           runs, a claim the registry or the candidate list knows *)
        && List.for_all T.edges ~f:(fun e ->
               match e.T.eg_annotation with
               | T.Action f ->
                   List.mem (Canary_action_family.of_catalogue ()) f
                     ~equal:Canary_action_family.equal
               | T.Agreement slug -> List.mem known slug ~equal:String.equal
               | T.Info s -> not (String.is_empty s))
        (* and all three kinds are in use *)
        && List.exists T.edges ~f:(fun e ->
               match e.T.eg_annotation with T.Action _ -> true | _ -> false)
        && List.exists T.edges ~f:(fun e ->
               match e.T.eg_annotation with T.Agreement _ -> true | _ -> false)
        && List.exists T.edges ~f:(fun e ->
               match e.T.eg_annotation with T.Info _ -> true | _ -> false)
        (* a family is its actions' name with the language dropped, over
           the whole catalogue *)
        && List.for_all
             (Canary_basic.store_actions ~langs:Canary_lang.[ OCaml; Python ])
             ~f:(fun a ->
               let name = Canary_basic.string_of_action a in
               let fam =
                 Canary_action_family.to_string (Canary_action_family.of_action a)
               in
               String.equal name fam
               || List.exists Canary_lang.[ OCaml; Python ] ~f:(fun l ->
                      String.equal name
                        (fam ^ "_" ^ Canary_lang.string_of_lang l)))
        (* the action families with no edge, listed, so a change to this
           list is a decision rather than a silent re-render *)
        && List.equal String.equal
             (List.map (T.families_without_edge ())
                ~f:Canary_action_family.to_string)
             [ "fetch_source"; "configure"; "scan_sources"; "fetch_headers";
               "fetch_binding_source"; "build_app"; "probe_app"; "fetch_app";
               "pack_lib"; "pack_app" ])
  }

(* The worlds are derived as the runner derives them, so no log is read.
   The steps the page cannot place, and the bindings included with their
   language, are listed: a new one fails here rather than rendering as a
   quiet grey. Every action edge is realized by some world. *)
let every_step_placed_test : Canary_project_test.pure_test =
  { name = "topology.every_step_has_a_place";
    holds = "Every step of every active project's worlds has a place on the graph, or a listed reason it has none.";
    check =
      (fun () ->
        let module T = Canary_topology in
        let module SM = Canary_step_model in
        (* the withheld [depends] needs a project with no known gate, and
           no active project is one: an un-routed copy of cairo exercises
           it, and its gaps are cairo's, so the listed set does not move *)
        let ungated =
          List.filter_map Canary_registry.all_projects ~f:(fun (name, pr) ->
              if String.equal name "cairo" then
                Some (name ^ "-ungated", { pr with Canary_project_run.pr_pm_gates = [] })
              else None)
        in
        let placed =
          List.concat_map (Canary_registry.all_projects @ ungated) ~f:(fun (name, pr) ->
              List.map (Canary_project_run.scenarios_of pr) ~f:(fun a ->
                  let steps =
                    Canary_pipeline.steps_of ~warn:false ~root:"_out/canary" pr
                      ~ctx:(Canary_pipeline.ctx_of pr a) a
                  in
                  let gones = T.world_gone ~pr ~world:a in
                  ( name,
                    steps,
                    List.map steps ~f:(fun (s : SM.step) ->
                        ( s,
                          T.place_step ~gone:(T.gone_for_action gones s.SM.action)
                            ~pr ~world:a ~action:s.SM.action
                            ~location:s.SM.location ~inspects:s.SM.inspects
                            ~dummy:s.SM.dummy ~bridge:s.SM.bridge
                            ~placeholder:s.SM.placeholder )) )))
        in
        let all = List.concat_map placed ~f:(fun (_, _, places) -> places) in
        let edge_exists id =
          List.exists T.edges ~f:(fun e -> String.equal e.T.eg_id id)
        in
        let family (s : SM.step) =
          Canary_action_family.to_string (Canary_action_family.of_action s.SM.action)
        in
        let well_formed =
          List.for_all placed ~f:(fun (_, steps, places) ->
              List.for_all places ~f:(fun ((s : SM.step), p) ->
                  match p with
                  | T.On ids -> (not (List.is_empty ids)) && List.for_all ids ~f:edge_exists
                  (* a placeholder marks edges that exist, and only a step
                     that is a placeholder is placed this way *)
                  | T.Placeholder_for ids ->
                      Option.is_some s.SM.placeholder
                      && (not (List.is_empty ids))
                      && List.for_all ids ~f:edge_exists
                  (* an included binding marks action edges that exist,
                     and only a dummy that stands in for a binding's fetch
                     is placed this way *)
                  | T.Included_for ids ->
                      Option.is_some s.SM.dummy
                      && (match s.SM.action with
                          | Canary_basic.Fetch (Canary_basic.Binding _) -> true
                          | _ -> false)
                      && (not (List.is_empty ids))
                      && List.for_all ids ~f:(fun id ->
                             List.exists T.edges ~f:(fun e ->
                                 String.equal e.T.eg_id id
                                 && match e.T.eg_annotation with T.Action _ -> true | _ -> false))
                  | T.Evidence_for parent ->
                      List.exists steps ~f:(fun (q : SM.step) ->
                          String.equal q.SM.tag parent
                          && Option.is_none q.SM.inspects
                          && Poly.equal q.SM.action s.SM.action)
                  | T.Unplaced (T.Unexpected _) -> false
                  | T.Unplaced _ -> true))
        in
        (* the listed gaps, by action family, so a second language adds
           no row *)
        let gaps =
          List.filter_map all ~f:(fun (s, p) ->
              match p with
              | T.Unplaced u -> Some (family s ^ " " ^ T.code_of_unplaced u)
              | T.On _ | T.Evidence_for _ | T.Placeholder_for _ | T.Included_for _ -> None)
          |> List.dedup_and_sort ~compare:String.compare
        in
        (* [probe_lib unused_system_copy] is sqlite's [probe_lib_apt], and
           also a declaration bug: the opam-binding template's
           vendored-library world (cairo, libffi, zlib, zstd) keeps its lib
           probe at [Pm (Sys_pm _)] while the command probes the prebuilt
           copy; [Canary_store.location] has no constructor for a supplied
           copy *)
        let listed =
          [ "configure no_edge";
            "fetch_binding_source no_edge"; "fetch_lib lib_from_language_pm";
            "fetch_source no_edge"; "probe_app no_edge";
            "probe_lib staged_copy"; "probe_lib unused_system_copy";
            "scan_sources no_edge" ]
        in
        (* every action edge is realized somewhere *)
        let realized =
          List.concat_map all ~f:(fun (_, p) ->
              match p with
              | T.On ids -> ids
              | T.Evidence_for _ | T.Placeholder_for _ | T.Included_for _ | T.Unplaced _ -> [])
        in
        let action_edges_realized =
          List.for_all T.edges ~f:(fun e ->
              match e.T.eg_annotation with
              | T.Action _ -> List.mem realized e.T.eg_id ~equal:String.equal
              | T.Agreement _ | T.Info _ -> true)
        in
        let fetch_binding_places =
          List.filter_map all ~f:(fun ((s : SM.step), p) ->
              match (s.SM.action, s.SM.bridge, p) with
              | Canary_basic.Fetch (Canary_basic.Binding _), None, T.On ids ->
                  Some ids
              | _ -> None)
        in
        let bridge_places =
          List.filter_map all ~f:(fun ((s : SM.step), p) ->
              match (s.SM.bridge, p) with Some _, p -> Some p | None, _ -> None)
        in
        (* the bindings included with their language, by project and
           action family, with the relations each stands on: sqlite's
           CPython stdlib binding, whose chain (a C extension) has no stub
           build of its own. A second case is added deliberately *)
        let included =
          List.concat_map placed ~f:(fun (name, _, places) ->
              List.filter_map places ~f:(fun ((s : SM.step), p) ->
                  match p with
                  | T.Included_for ids -> Some (name ^ " " ^ family s, ids)
                  | _ -> None))
          |> List.dedup_and_sort ~compare:Poly.compare
        in
        well_formed
        && Poly.equal included
             [ ("sqlite fetch_binding", [ "install_lang"; "install_surf"; "link_mod" ]) ]
        && List.equal String.equal gaps listed
        && action_edges_realized
        (* the narrowings are exercised: both consumer programs, and
           [depends] both present and withheld *)
        && List.mem realized "run" ~equal:String.equal
        && List.mem realized "run_packaged" ~equal:String.equal
        && List.exists fetch_binding_places ~f:(fun ids ->
               List.mem ids "depends" ~equal:String.equal)
        && List.exists fetch_binding_places ~f:(fun ids ->
               not (List.mem ids "depends" ~equal:String.equal))
        (* a bridge's check is its own step's: a step driving a bridge sits
           on [conf_probe] and nothing else, and no install does, since
           opam dispatches the check only when it installs the bridge *)
        && List.for_all fetch_binding_places ~f:(fun ids ->
               not (List.mem ids "conf_probe" ~equal:String.equal))
        && (not (List.is_empty bridge_places))
        && List.for_all bridge_places ~f:(function
             | T.On [ "conf_probe" ] -> true
             | _ -> false))
  }

(* What a claim relates comes before where it is checked: each placed
   claim names its parts, and each part's node lies in its layer. *)
let claim_parts_test : Canary_project_test.pure_test =
  { name = "topology.claims_name_their_parts";
    holds = "Every placed claim names its parts, each on a node of the chain that lies in the part's layer.";
    check =
      (fun () ->
        let module T = Canary_topology in
        let bad =
          List.concat_map T.claim_sites ~f:(fun cs ->
              if List.is_empty cs.T.cs_parts then [ cs.T.cs_claim ^ ": no parts" ]
              else
                List.filter_map cs.T.cs_parts ~f:(fun pt ->
                    match T.node_by_id pt.T.pt_node with
                    | Some n when T.component_admits pt.T.pt_component n -> None
                    | Some _ ->
                        Some
                          (Printf.sprintf "%s: %s is not in %s" cs.T.cs_claim pt.T.pt_node
                             (T.string_of_component pt.T.pt_component))
                    | None -> Some (Printf.sprintf "%s: no node %s" cs.T.cs_claim pt.T.pt_node)))
        in
        List.iter bad ~f:(Fmt.pr "    %s@.");
        (not (List.is_empty T.claim_sites)) && List.is_empty bad)
  }

(* The two sides meet only through a join: a claim relating a system-side
   layer to a language-side one has the bridge, the binding or the
   program among its parts. *)
let sides_meet_test : Canary_project_test.pure_test =
  { name = "topology.sides_meet_through_a_join";
    holds = "No claim relates a system-side layer to a language-side layer unless the bridge, the binding or the program is among its parts.";
    check =
      (fun () ->
        let module T = Canary_topology in
        let bad =
          List.filter T.claim_sites ~f:(fun cs ->
              let sides =
                List.map cs.T.cs_parts ~f:(fun pt -> T.side_of_component pt.T.pt_component)
              in
              let has s = List.mem sides (Some s) ~equal:Poly.equal in
              has T.S_sys && has T.S_lang && not (List.mem sides None ~equal:Poly.equal))
        in
        List.iter bad ~f:(fun cs ->
            Fmt.pr "    %s relates both sides with no join among its parts@." cs.T.cs_claim);
        List.is_empty bad)
  }

(* Where a claim is checked follows from what it relates: each edge it
   sits on starts or ends at one of its parts. *)
let sits_by_parts_test : Canary_project_test.pure_test =
  { name = "topology.claims_sit_where_their_parts_are";
    holds = "Every edge a claim sits on starts or ends at one of the claim's parts.";
    check =
      (fun () ->
        let module T = Canary_topology in
        let bad =
          List.concat_map T.claim_sites ~f:(fun cs ->
              let parts = List.map cs.T.cs_parts ~f:(fun pt -> pt.T.pt_node) in
              List.filter_map cs.T.cs_edges ~f:(fun id ->
                  match List.find T.edges ~f:(fun e -> String.equal e.T.eg_id id) with
                  | None -> Some (cs.T.cs_claim ^ ": no edge " ^ id)
                  | Some e ->
                      if
                        List.exists (e.T.eg_to :: e.T.eg_from) ~f:(fun n ->
                            List.mem parts n ~equal:String.equal)
                      then None
                      else Some (Printf.sprintf "%s: %s touches none of its parts" cs.T.cs_claim id)))
        in
        List.iter bad ~f:(Fmt.pr "    %s@.");
        (not (List.is_empty T.claim_sites)) && List.is_empty bad)
  }

(* The figure that groups the chain by component draws what the topology
   says: each node is owned by one component that admits it, and on Figure
   2's layout each node's box lies inside exactly its owner's container and
   those of the joins that span it. *)
let components_contain_test : Canary_project_test.pure_test =
  { name = "overview.components_contain_their_nodes";
    holds = "Every node is owned by one component that admits it, and in the chain drawn by component each node lies inside exactly its owner's container and those of the joins that span it.";
    check =
      (fun () ->
        let module T = Canary_topology in
        let module D = Canary_overview_diagram in
        (* ray casting: is the point strictly inside the polygon? *)
        let inside pts (x, y) =
          let a = Array.of_list pts in
          let n = Array.length a in
          let rec go i acc =
            if i = n then acc
            else
              let xi, yi = a.(i) and xj, yj = a.((i + n - 1) % n) in
              let crosses =
                (not (Bool.equal (yi > y) (yj > y)))
                &&
                let dx = Float.of_int (xj - xi)
                and dy = Float.of_int (yj - yi)
                and ry = Float.of_int (y - yi) in
                Float.(of_int x < (dx * ry / dy) + of_int xi)
              in
              go (i + 1) (if crosses then not acc else acc)
          in
          go 0 false
        in
        let corners id =
          let p = D.pos_of id and w = D.box_w_of id in
          let x0 = p.D.px - (w / 2) and y0 = p.D.py - (D.box_h / 2) in
          [ (x0, y0); (x0 + w, y0); (x0, y0 + D.box_h); (x0 + w, y0 + D.box_h) ]
        in
        let bad =
          List.filter_map T.nodes ~f:(fun n ->
              match T.component_of_node n.T.nd_id with
              | None -> Some (n.T.nd_id ^ ": no component")
              | Some c when not (T.component_admits c n) ->
                  Some (Printf.sprintf "%s: not admitted by %s" n.T.nd_id (T.string_of_component c))
              | Some c ->
                  let expected =
                    c
                    :: List.filter_map T.join_spans ~f:(fun (j, ns) ->
                           Option.some_if (List.mem ns n.T.nd_id ~equal:String.equal) j)
                  in
                  let cs = corners n.T.nd_id in
                  let ok =
                    List.for_all D.containers ~f:(fun (c', pts) ->
                        if List.mem expected c' ~equal:Poly.equal then List.for_all cs ~f:(inside pts)
                        else not (List.exists cs ~f:(inside pts)))
                  in
                  if ok then None
                  else
                    Some
                      (n.T.nd_id
                     ^ ": not inside exactly its owner's container and the joins spanning it"))
        in
        let spans_named =
          List.for_all T.join_spans ~f:(fun (_, ns) ->
              List.for_all ns ~f:(fun id -> Option.is_some (T.node_by_id id)))
        in
        List.iter bad ~f:(Fmt.pr "    %s@.");
        (not (List.is_empty D.containers)) && spans_named && List.is_empty bad)
  }

(* Every action edge is in exactly one piece of one frame; no node
   repeats within a frame (it repeats across frames, where it is consumed
   again); and every agreement with an evaluator has a check column at
   each of its site edges, in that edge's frame, and no other. See
   design/overview.md §6.4. *)
let frames_test : Canary_project_test.pure_test =
  { name = "frames.derive_the_confirmed_layout";
    holds = "The frames reproduce the confirmed column layout, line by line.";
    check =
      (fun () ->
        let module Fr = Canary_frames in
        let module T = Canary_topology in
        let want =
          [ "system fetch_lib: pm_sys ▸resolve pkg_sys ▸realize lib_sys hdr_sys »dse »dve »smd";
            "system build_lib: src_sys ▸build_lib lib_sys »dse »dve »smd";
            "system build_headers: src_sys ▸build_hdr hdr_sys";
            "system install_lib: lib_sys ▸stage staged_sys »sip";
            "system probe_lib: lib_sys ▸probe_lib";
            "binding build_binding: src_lang hdr_sys ›sa ▸build_stub stub_lang lib_sys ›dp \
             ›rse ›rve ›smr ▸link_mod mod_lang";
            "language fetch_binding: pm_lang ▸resolve pkg_lang ▸depends bridge ▸conf_probe cap \
             ›gatw ▸install mod_lang surf_lang ›anp";
            "language pack_binding: mod_lang ▸pack pkg_lang";
            "program probe_binding · run: mod_lang lib_sys ▸run consumer_artifact";
            "program probe_binding · run_packaged: pkg_lang ▸run_packaged consumer_package" ]
        in
        let got = List.map Fr.frames ~f:Fr.pp_frame in
        let lines_ok = List.equal String.equal want got in
        if not lines_ok then List.iter got ~f:(fun l -> Fmt.pr "    got: %s@." l);
        let pieces =
          List.concat_map Fr.frames ~f:(fun fr ->
              List.filter_map fr.Fr.fr_columns ~f:(function
                | Fr.Piece { edges; _ } -> Some edges
                | _ -> None))
          |> List.concat
        in
        let action_edges =
          List.filter_map T.edges ~f:(fun e ->
              match e.T.eg_annotation with T.Action _ -> Some e.T.eg_id | _ -> None)
        in
        let edges_once =
          List.for_all action_edges ~f:(fun id ->
              List.count pieces ~f:(String.equal id) = 1)
          && List.length pieces = List.length action_edges
        in
        let nodes_once =
          List.for_all Fr.frames ~f:(fun fr ->
              let ns =
                List.filter_map fr.Fr.fr_columns ~f:(function Fr.Node n -> Some n | _ -> None)
              in
              List.length ns = List.length (List.dedup_and_sort ns ~compare:String.compare))
        in
        (* each check in the frame that holds its site edge, and every
           checked agreement at every one of its sites *)
        let checks =
          List.concat_map Fr.frames ~f:(fun fr ->
              let own =
                List.concat_map fr.Fr.fr_columns ~f:(function
                  | Fr.Piece { edges; _ } -> edges
                  | _ -> [])
              in
              List.filter_map fr.Fr.fr_columns ~f:(function
                | Fr.Check { slug; site; _ } -> Some (slug, site, List.mem own site ~equal:String.equal)
                | _ -> None))
        in
        let in_own_frame = List.for_all checks ~f:(fun (_, _, ok) -> ok) in
        let every_site =
          List.for_all Fr.checked_rows ~f:(fun r ->
              let slug = r.Canary_agreement.ag_slug in
              List.for_all (Fr.sites_of slug) ~f:(fun site ->
                  List.count checks ~f:(fun (s, e, _) ->
                      String.equal s slug && String.equal e site)
                  = 1))
          && List.length checks
             = List.sum (module Int) Fr.checked_rows ~f:(fun r ->
                   List.length (Fr.sites_of r.Canary_agreement.ag_slug))
        in
        lines_ok && edges_once && nodes_once && in_own_frame && every_site)
  }

(* The one reader of an inspection is
   [Canary_matrix.reading_of_inspection]; on fixtures each kind renders
   its cell, name and count. See design/overview.md §6.4. *)
let one_reader_test : Canary_project_test.pure_test =
  { name = "overview.one_reader_per_inspection";
    holds = "Each kind of inspection reads, through Canary_matrix's reader, into its table cell, its node name and its count.";
    check =
      (fun () ->
        let module M = Canary_matrix in
        let read s = M.reading_of_inspection (Yojson.Basic.from_string s) in
        let renders s ~cell ~name ~count =
          match read s with
          | None -> false
          | Some r ->
              Poly.equal (M.cell_text_of_reading r) cell
              && Poly.equal (M.name_text_of_reading r) name
              && Poly.equal (M.count_text_of_reading r) count
        in
        renders
             {|{"kind":"native","path":"/usr/lib/x86_64-linux-gnu/libgmp.so",
                "elf":{"soname":"libgmp.so.10"},"counts":{"total":620}}|}
             ~cell:(Some "so.10 620") ~name:(Some "libgmp.so.10") ~count:(Some "620 exports")
        && renders {|{"kind":"c_stub","path":"/x/libzarith.a","requires":["a","b"]}|}
             ~cell:(Some "2 req") ~name:(Some "libzarith.a") ~count:(Some "2 required")
        && renders {|{"kind":"ocaml","path":"zarith","modules":["Z","Q","Big_int_Z","Zarith_version"]}|}
             ~cell:(Some "4 mod") ~name:(Some "zarith (4 modules)") ~count:None
        && renders {|{"kind":"python","path":"sqlite3","attrs":["connect","Row","Error"]}|}
             ~cell:(Some "3 attr") ~name:(Some "sqlite3 (3 names)") ~count:None
        (* an mli summary's path is the package: no name, only a count *)
        && renders {|{"kind":"ocaml_mli","path":"zarith","modules":["Z","Q"]}|}
             ~cell:(Some "2 mod") ~name:None ~count:(Some "2 modules")
        && Option.is_none (read {|{"kind":"bridge","package":"conf-gmp"}|})
        (* a library's reading describes the copy its step looked at *)
        &&
        let lib = Yojson.Basic.from_string {|{"kind":"native","elf":{"soname":"libz.so.1"}}|} in
        let node ?location () =
          Option.map (M.reading_of_inspection ?location lib) ~f:(fun r -> r.M.rd_node)
        in
        Poly.equal (node ()) (Some "lib_sys")
        && Poly.equal (node ~location:Canary_store.Build_tree ()) (Some "lib_sys")
        && Poly.equal (node ~location:Canary_store.Staged ()) (Some "staged_sys"))
  }

(* A slot with no value, a value with no slot, or an unclosed slot fails
   the fill. *)
let template_test : Canary_project_test.pure_test =
  { name = "overview.template_slots_are_filled";
    holds = "The page is its template, page.html, with every slot filled.";
    check =
      (fun () ->
        let module A = Canary_overview_assets in
        let raises f = match f () with _ -> false | exception Failure _ -> true in
        let page =
          Canary_overview_page.render Canary_registry.all_specs ~overview:"" ~generated_at:"test"
        in
        String.equal
          (A.fill_text ~what:"t" "a{{x}}b{{y}}c" [ ("x", "1"); ("y", "{{z}}") ])
          "a1b{{z}}c"
        && raises (fun () -> A.fill_text ~what:"t" "a{{x}}b" [])
        && raises (fun () -> A.fill_text ~what:"t" "ab" [ ("x", "1") ])
        && raises (fun () -> A.fill_text ~what:"t" "a{{x" [ ("x", "1") ])
        && String.is_prefix page ~prefix:"<!DOCTYPE html>")
  }

let results_table_test : Canary_project_test.pure_test =
  { name = "overview.results_table_is_the_column_model";
    holds = "The result table is the column model: cells are computed and filed by column when a runs file is written, and the page only lays them out.";
    check =
      (fun () ->
        let module Fr = Canary_frames in
        let module R = Canary_overview_runs in
        let module M = Canary_matrix in
        let page =
          Canary_overview_page.render Canary_registry.all_specs ~overview:"" ~generated_at:"test"
        in
        let module Rs = Canary_overview_results in
        (* the columns, one per frame column in order, each filed once *)
        let keys = Rs.keys () in
        let model_ok =
          List.length keys = List.sum (module Int) Fr.frames ~f:(fun fr -> List.length fr.Fr.fr_columns)
          && List.length (List.dedup_and_sort keys ~compare:String.compare) = List.length keys
          && List.equal String.equal keys
               (List.concat_map Fr.frames ~f:(fun fr ->
                    List.map fr.Fr.fr_columns ~f:(fun c -> fr.Fr.fr_label ^ "|" ^ match c with
                      | Fr.Node n -> "n|" ^ n
                      | Fr.Piece { label; _ } -> "p|" ^ label
                      | Fr.Check { slug; site; stage; _ } ->
                          String.concat ~sep:"|"
                            [ "c"; slug; Canary_agreement_common.string_of_stage stage; site ])))
          (* the page carries the header and the keys; the frames in order *)
          && String.is_substring page ~substring:(Rs.thead ())
          && String.is_substring page ~substring:(Rs.columns_json ())
          && (let at =
                List.map Fr.frames ~f:(fun fr ->
                    String.substr_index page
                      ~pattern:(Printf.sprintf {|<th class="rt-fr" colspan="%d">%s</th>|}
                                  (List.length fr.Fr.fr_columns)
                                  (Canary_overview_assets.esc fr.Fr.fr_label)))
              in
              List.for_all at ~f:Option.is_some
              &&
              let ps = List.filter_map at ~f:Fn.id in
              List.for_all2_exn (List.drop_last_exn ps) (List.tl_exn ps) ~f:(fun a b -> a < b))
        in
        (* §1.2's script lays rows out by key after the runs files load,
           and computes nothing; a row's name draws its chain in §1
           ([window.canaryDraw]) and a drawn run links back to its row *)
        let script = Canary_overview_assets.read "results.js" in
        let section_ok =
          String.is_substring page ~substring:{|<h3 id="results">1.2 |}
          && String.is_substring page ~substring:"window.canaryDraw="
          && String.is_substring page ~substring:"'#row-'+v.key"
          && List.for_all [ "C.keys"; "w.row"; "C.missing" ] ~f:(fun s ->
                 String.is_substring script ~substring:s)
          && List.for_all [ "absent"; "rt-ok"; "outcomes"; "blames"; "FR." ] ~f:(fun s ->
                 not (String.is_substring script ~substring:s))
          &&
          match
            ( String.substr_index page ~pattern:"overview_runs.js",
              String.substr_index page ~pattern:"getElementById('rtcols')" )
          with
          | Some runs, Some table -> runs < table
          | _ -> false
        in
        let m = M.matrix_of Canary_registry.all_projects in
        let views = R.views m in
        let row_of (v : R.view) =
          List.find m.M.rows ~f:(fun (r : M.row) ->
              String.equal r.M.project v.R.vw_project && String.equal r.M.scenario v.R.vw_scenario)
        in
        let in_lang (v : R.view) l = Option.is_none l || Poly.equal l (Some v.R.vw_lang) in
        let checked slug =
          List.exists Fr.checked_rows ~f:(fun r -> String.equal r.Canary_agreement.ag_slug slug)
        in
        (* a view's check outcome is the worst its world's log recorded for
           that claim in that language, or [n/a] where the chain's
           mechanism cannot carry it *)
        let outcomes_ok =
          List.for_all views ~f:(fun v ->
              match row_of v with
              | None -> false
              | Some r ->
                  List.for_all v.R.vw_outcomes ~f:(fun (slug, o) ->
                      String.equal o "n/a"
                      ||
                      let logged =
                        List.filter_map r.M.verdicts ~f:(fun (s, l, label) ->
                            if String.equal s slug && in_lang v l then Some label else None)
                      in
                      List.mem logged o ~equal:String.equal
                      && List.for_all logged ~f:(fun x -> M.outcome_rank x <= M.outcome_rank o)))
        in
        (* no logged verdict is left out: the table reads the site, not the
           slot, because zarith's fetched-library worlds decide the
           library's declaration checks at probe_lib and have no build_lib
           slot to show them in *)
        let none_left_out =
          List.for_all views ~f:(fun v ->
              match row_of v with
              | None -> false
              | Some r ->
                  List.for_all r.M.verdicts ~f:(fun (slug, l, _) ->
                      (not (in_lang v l)) || (not (checked slug))
                      || List.Assoc.mem v.R.vw_outcomes slug ~equal:String.equal))
        in
        (* every recorded row has a cell for every column, and only those *)
        let rows_ok =
          List.for_all views ~f:(fun v ->
              List.equal String.equal
                (List.map (R.row_of_view ~machine:"test" v).Rs.rw_cells ~f:fst)
                keys)
        in
        model_ok && section_ok && outcomes_ok && none_left_out && rows_ok)
  }

(* The overlay's words are computed here. Everything the page's script
   trusts is held: the file's shape, every view naming exactly the
   template's edges and only its nodes, each hand-drawn case with a
   counterpart resolving to a view that shows the facts it is about, and
   the page holding no run state of its own. *)
let overview_overlay_test : Canary_project_test.pure_test =
  { name = "overview.recorded_runs_are_an_overlay";
    holds = "A recorded run is an overlay on the template: a word per edge, badge and node, shipped in a per-machine runs file beside the page.";
    check =
      (fun () ->
        let module M = Canary_matrix in
        let module T = Canary_topology in
        let module R = Canary_overview_runs in
        let module F = Record_fixture in
        let m = M.matrix_of Canary_registry.all_projects in
        let text = R.payload m ~generated_at:"test" in
        let words =
          [ "ran"; "warm"; "xfail"; "fail"; "blocked"; "unrecorded"; "absent";
            "inside"; "included"; "not_ours"; "observed"; "claim" ]
        in
        let edge_ids = List.map T.edges ~f:(fun e -> e.T.eg_id) in
        let assoc_keys j k =
          match F.field j k with Some (`Assoc kv) -> List.map kv ~f:fst | _ -> []
        in
        let file_ok, views =
          if
            not
              (String.is_prefix text ~prefix:R.prefix
              && String.is_suffix text ~suffix:R.suffix)
          then (false, [])
          else
            match
              Yojson.Basic.from_string
                (String.sub text ~pos:(String.length R.prefix)
                   ~len:
                     (String.length text - String.length R.prefix
                    - String.length R.suffix))
            with
            | exception _ -> (false, [])
            | j -> (true, F.items j "views")
        in
        (* each hand-drawn case's recorded world, by view id *)
        let cases = R.case_views (R.views m) in
        (* every view names the package it realizes, one of §1's, which is
           how choosing a package finds its recorded worlds *)
        let packages =
          List.map (Canary_overview_join.of_projects Canary_registry.all_specs).Canary_overview_join.jn_cases
            ~f:(fun c -> c.Canary_overview_join.cs_id)
        in
        let views_name_packages =
          List.for_all views ~f:(fun v ->
              match F.str v "case" with
              | Some id -> List.mem packages id ~equal:String.equal
              | None -> false)
        in
        let view_by_id id =
          List.find views ~f:(fun v -> Poly.equal (F.str v "id") (Some id))
        in
        let ids = List.filter_map views ~f:(fun v -> F.str v "id") in
        let views_ok =
          (not (List.is_empty views))
          && List.length (List.dedup_and_sort ids ~compare:String.compare)
             = List.length ids
          && List.for_all views ~f:(fun v ->
                 let edges =
                   match F.field v "edges" with Some (`Assoc kv) -> kv | _ -> []
                 in
                 let row =
                   List.find m.M.rows ~f:(fun (r : M.row) ->
                       Poly.equal (F.str v "project") (Some r.M.project)
                       && Poly.equal (F.str v "scenario") (Some r.M.scenario))
                 in
                 List.equal String.equal (List.map edges ~f:fst) edge_ids
                 && List.for_all edges ~f:(fun (_, w) ->
                        match w with
                        | `String s -> List.mem words s ~equal:String.equal
                        | _ -> false)
                 && List.for_all (assoc_keys v "nodes") ~f:(fun n ->
                        Option.is_some (T.node_by_id n))
                 && List.for_all (assoc_keys v "badges") ~f:(fun e ->
                        not (List.is_empty (T.claim_sites_on e)))
                 (* an observation is about a template edge, and an edge
                    reads [observed] only where it is someone else's rule
                    and the view recorded something there *)
                 && List.for_all (assoc_keys v "observed") ~f:(fun e ->
                        List.mem edge_ids e ~equal:String.equal)
                 && List.for_all edges ~f:(fun (id, w) ->
                        match w with
                        | `String "observed" ->
                            List.mem (assoc_keys v "observed") id ~equal:String.equal
                            && List.exists T.edges ~f:(fun e ->
                                   String.equal e.T.eg_id id
                                   &&
                                   match e.T.eg_annotation with
                                   | T.Info _ -> true
                                   | T.Action _ | T.Agreement _ -> false)
                        (* [inside] only on an action edge a placeholder
                           stands for: a package manager established it,
                           unseen *)
                        | `String "inside" ->
                            List.mem (assoc_keys v "placeholders") id ~equal:String.equal
                            && List.exists T.edges ~f:(fun e ->
                                   String.equal e.T.eg_id id
                                   &&
                                   match e.T.eg_annotation with
                                   | T.Action _ -> true
                                   | T.Info _ | T.Agreement _ -> false)
                        | _ -> true)
                 (* every placeholder is on a template edge, with a known
                    reason *)
                 && List.for_all (assoc_keys v "placeholders") ~f:(fun e ->
                        List.mem edge_ids e ~equal:String.equal)
                 && (match F.field v "placeholders" with
                    | Some (`Assoc kv) ->
                        List.for_all kv ~f:(fun (_, xs) ->
                            match xs with
                            | `List items ->
                                (not (List.is_empty items))
                                && List.for_all items ~f:(fun it ->
                                       List.mem [ "not_yet"; "out_of_reach" ]
                                         (Option.value (F.str it "unseen") ~default:"")
                                         ~equal:String.equal)
                            | _ -> false)
                    | _ -> false)
                 &&
                 match row with
                 | None -> false
                 | Some r ->
                     List.for_all (assoc_keys v "unplaced") ~f:(fun t ->
                         List.exists r.M.steps ~f:(fun w ->
                             String.equal w.M.ws_tag t)))
        in
        (* each counterpart resolves, to its project, in its language *)
        let cases_ok =
          List.for_all R.counterparts ~f:(fun (k, (project, _, lang)) ->
              match List.Assoc.find cases k ~equal:String.equal with
              | None -> false
              | Some id -> (
                  match view_by_id id with
                  | None -> false
                  | Some v ->
                      Poly.equal (F.str v "project") (Some project)
                      && Poly.equal (F.str v "lang")
                           (Some (Canary_lang.string_of_lang lang))))
        in
        let edge_word case e =
          Option.bind (List.Assoc.find cases case ~equal:String.equal)
            ~f:(fun id ->
              Option.bind (view_by_id id) ~f:(fun v ->
                  match F.field v "edges" with
                  | Some edges -> F.str edges e
                  | None -> None))
        in
        let is case e w = Poly.equal (edge_word case e) (Some w) in
        let drawn case e =
          match edge_word case e with
          | Some w -> not (List.mem [ "absent"; "not_ours"; "claim" ] w ~equal:String.equal)
          | None -> false
        in
        (* the facts the cases are about: the conf world's consumer is the
           package-linked one, torch's unified world has no system side,
           the built world builds its library and still resolves the
           bridge, and sqlite's Python view is not painted by its OCaml
           fetch *)
        let facts_ok =
          drawn "conf" "run_packaged" && is "conf" "run" "absent"
          (* the conf world drives its bridge, so its check is drawn: a
             step realizes it whether or not that step has run yet *)
          && drawn "conf" "conf_probe"
          (* and the conf world fetches its binding, so opam compiled the
             stub and linked the module inside its install: placeholders,
             not absences *)
          && is "conf" "build_stub" "inside" && is "conf" "link_mod" "inside"
          && List.for_all T.edges ~f:(fun e ->
                 match e.T.eg_annotation with
                 | T.Info _ ->
                     is "conf" e.T.eg_id "not_ours" || is "conf" e.T.eg_id "observed"
                 | T.Agreement _ -> is "conf" e.T.eg_id "claim"
                 | T.Action _ -> true)
          && is "unified" "resolve_sys" "absent" && drawn "unified" "run_packaged"
          && drawn "built" "build_lib" && is "built" "resolve_sys" "absent"
          && drawn "built" "depends"
          && is "none" "resolve_lang" "absent" && drawn "none" "run_packaged"
          (* CPython's stdlib binding: nothing resolved it, but its module,
             surface and link to the library came with the interpreter *)
          && is "none" "install_lang" "included" && is "none" "install_surf" "included"
          && is "none" "link_mod" "included"
        in
        let page =
          Canary_overview_page.render Canary_registry.all_specs ~overview:""
            ~generated_at:"test"
        in
        let section =
          match String.substr_index page ~pattern:{|<div class="join" id="join">|} with
          | None -> ""
          | Some i -> (
              let rest = String.drop_prefix page i in
              match String.substr_index rest ~pattern:{|<p id="edet"|} with
              | None -> ""
              | Some j -> String.prefix rest j)
        in
        let before a b =
          match (String.substr_index page ~pattern:a, String.substr_index page ~pattern:b) with
          | Some i, Some j -> i < j
          | _ -> false
        in
        let page_ok =
          (not (String.is_empty section))
          && List.for_all edge_ids ~f:(fun id ->
                 String.is_substring section
                   ~substring:(Printf.sprintf {|data-edge="%s"|} id))
          && List.for_all T.nodes ~f:(fun n ->
                 String.is_substring section
                   ~substring:(Printf.sprintf {|data-node="%s"|} n.T.nd_id))
          (* the recorded run's controls and key are in §1's panel *)
          && List.for_all [ {|id="jworld"|}; {|id="jrec"|}; {|id="jnorec"|}; {|class="key reckey"|} ]
               ~f:(fun s -> String.is_substring section ~substring:s)
          (* each machine's runs file loads before the script that draws
             from it *)
          && List.for_all R.all_file_names ~f:(fun f ->
                 before (Printf.sprintf {|<script src="%s">|} f) "THE CHAIN, CHOSEN")
          (* no run state in the page: the views live only in the file *)
          && not (String.is_substring page ~substring:"CANARY_RUNS.push")
          (* a placeholder slot on every edge, hidden by class: SVG does
             not honour the [hidden] attribute *)
          && List.length (String.substr_index_all section ~may_overlap:false ~pattern:{|class="phm"|})
             >= List.length edge_ids
          && String.is_substring page ~substring:".phm{display:none}"
          && not (String.is_substring section ~substring:{|class="phm" hidden|})
        in
        file_ok && views_ok && views_name_packages && cases_ok && facts_ok && page_ok
        (* a [--platform] render writes outside [docs/] *)
        && String.is_prefix (R.target ~hypothetical:true) ~prefix:"_out/"
        && String.is_prefix (R.target ~hypothetical:false) ~prefix:"docs/canary/")
  }

(* the hand-drawn cases, [Canary_overview_cases.hand_cases], which the
   page does not draw: the oracle these tests hold the derivations to, in
   the shape the tests read *)
let hand_cases_json () : Yojson.Basic.t =
  let strs l = `List (List.map l ~f:(fun s -> `String s)) in
  `Assoc
    (List.map Canary_overview_cases.hand_cases ~f:(fun (c : Canary_overview_cases.case) ->
         ( c.Canary_overview_cases.ca_key,
           `Assoc
             [ ( "names",
                 `Assoc
                   (List.map c.Canary_overview_cases.ca_names ~f:(fun (n, l) -> (n, `String l)))
               );
               ("hidden", strs c.Canary_overview_cases.ca_hidden);
               ("dead", strs c.Canary_overview_cases.ca_dead) ] )))

(* What the case hides, the view dims; what the case greys, the view does
   not realize. Each tested name reads the same on a checkout that has
   never run: its declared fallback is the recorded string. *)
let recorded_names_test : Canary_project_test.pure_test =
  { name = "overview.recorded_views_are_named";
    holds = "A recorded view names its world's nodes from what the run recorded, else from the project's declaration, and keeps its hand-drawn case's shape.";
    check =
      (fun () ->
        let module M = Canary_matrix in
        let module T = Canary_topology in
        let module R = Canary_overview_runs in
        let m = M.matrix_of Canary_registry.all_projects in
        let views = R.views m in
        let view_of key =
          Option.bind (List.Assoc.find (R.case_views views) key ~equal:String.equal)
            ~f:(fun id -> List.find views ~f:(fun v -> String.equal v.R.vw_id id))
        in
        let node_ids = List.map T.nodes ~f:(fun n -> n.T.nd_id) in
        let well_formed =
          List.for_all views ~f:(fun v ->
              List.for_all v.R.vw_names ~f:(fun (n, (label, from)) ->
                  List.mem node_ids n ~equal:String.equal
                  && (not (String.is_empty label))
                  && List.mem [ "recorded"; "declared" ] from ~equal:String.equal)
              && List.for_all v.R.vw_dim ~f:(List.mem node_ids ~equal:String.equal))
        in
        (* the hand-drawn cases: the oracle *)
        let hand = Some (hand_cases_json ()) in
        let field j k =
          match j with
          | `Assoc kv -> List.Assoc.find kv k ~equal:String.equal
          | _ -> None
        in
        let strings j =
          match j with
          | Some (`List xs) -> List.filter_map xs ~f:(function `String s -> Some s | _ -> None)
          | _ -> []
        in
        let hand_case key = Option.bind hand ~f:(fun h -> field h key) in
        let shape_agrees =
          List.for_all R.counterparts ~f:(fun (key, _) ->
              match (hand_case key, view_of key) with
              | Some c, Some v ->
                  List.for_all (strings (field c "hidden")) ~f:(fun n ->
                      List.mem v.R.vw_dim n ~equal:String.equal)
                  && List.for_all (strings (field c "dead")) ~f:(fun e ->
                         match List.Assoc.find v.R.vw_edges e ~equal:String.equal with
                         | Some w ->
                             List.mem [ "absent"; "not_ours"; "claim" ] w ~equal:String.equal
                         | None -> false)
              | _ -> false)
        in
        let agrees key node =
          match (hand_case key, view_of key) with
          | Some c, Some v -> (
              match
                ( Option.bind (field c "names") ~f:(fun names -> field names node),
                  List.Assoc.find v.R.vw_names node ~equal:String.equal )
              with
              | Some (`String h), Some (label, _) -> String.equal h label
              | _ -> false)
          | _ -> false
        in
        (* a declaration names only what the world uses: where a view's
           binding is not fetched, no bridge is named, and the package node
           is unnamed or the package the world publishes. Not vacuous:
           zarith's built world names zarith-no-conf and no bridge *)
        let binding_not_fetched (v : R.view) =
          match
            List.find m.M.rows ~f:(fun (r : M.row) ->
                String.equal r.M.project v.R.vw_project
                && String.equal r.M.scenario v.R.vw_scenario)
          with
          | None -> false
          | Some r -> (
              match R.assignment_of_row r with
              | None -> false
              | Some (_, a) ->
                  List.exists a ~f:(fun (id, (pl : Canary_artifact.placement)) ->
                      Poly.equal (Canary_artifact.kind_of id)
                        (Canary_basic.Binding v.R.vw_lang)
                      && not
                           (Poly.equal pl.Canary_artifact.provision
                              Canary_artifact.Fetched)))
        in
        let unfetched = List.filter views ~f:binding_not_fetched in
        let names_only_the_world =
          List.for_all unfetched ~f:(fun v ->
              (not (List.Assoc.mem v.R.vw_names "bridge" ~equal:String.equal))
              &&
              match List.Assoc.find v.R.vw_names "pkg_lang" ~equal:String.equal with
              | None -> true
              | Some (label, _) ->
                  List.exists Canary_registry.all_projects ~f:(fun (name, pr) ->
                      String.equal name v.R.vw_project
                      && List.exists pr.Canary_project_run.pr_wrapper_pkgs
                           ~f:(fun (l, w) ->
                             Poly.equal l v.R.vw_lang && String.equal w label)))
          && List.exists unfetched ~f:(fun v ->
                 String.equal v.R.vw_project "zarith"
                 && Poly.equal
                      (List.Assoc.find v.R.vw_names "pkg_lang" ~equal:String.equal)
                      (Some ("zarith-no-conf", "declared")))
        in
        (* the ratchet: the (case, node) pairs whose derived name equals the
           drawn one. A pair may be added but must not quietly fall out.
           The drawings' system names are Linux's, so those pairs are held
           only on Linux *)
        let on_linux = Poly.equal (Canary_store.platform ()) Canary_store.Wsl in
        let ratchet =
          [ ("conf", [ "bridge"; "hdr_sys"; "lib_sys"; "pm_lang"; "pkg_lang";
                       "src_lang"; "surf_lang" ]);
            ("unified", [ "pm_lang"; "pkg_lang"; "stub_lang"; "surf_lang" ]);
            ("none", [ "hdr_sys"; "lib_sys" ]);
            ("built", [ "pm_lang" ]) ]
          @ (if on_linux then [ ("conf", [ "pm_sys"; "pkg_sys" ]); ("none", [ "pm_sys" ]) ]
             else [])
        in
        well_formed && Option.is_some hand && shape_agrees && names_only_the_world
        && List.for_all ratchet ~f:(fun (key, nodes) ->
               List.for_all nodes ~f:(agrees key)))
  }

(* An edge several steps realize shows the worst word. Tested as values,
   because a reordering would quietly repaint the overlay. *)
let overlay_words_test : Canary_project_test.pure_test =
  { name = "overview.overlay_words_rank_worst_first";
    holds = "The overlay's step words rank worst first, and a badge holds only when every claim on its edge holds.";
    check =
      (fun () ->
        let module R = Canary_overview_runs in
        let module S = Canary_status in
        let order = [ "ran"; "warm"; "unrecorded"; "xfail"; "blocked"; "fail" ] in
        List.for_all2_exn (List.drop_last_exn order) (List.tl_exn order)
          ~f:(fun a b -> R.step_rank a < R.step_rank b)
        && String.equal (R.step_word (S.Warm S.Pass)) "warm"
        && String.equal (R.step_word (S.Ran (S.Xfail []))) "xfail"
        && String.equal (R.badge_word [ "holds"; "holds" ]) "holds"
        && String.equal (R.badge_word [ "holds"; "undecided" ]) "partial"
        && String.equal (R.badge_word [ "holds"; "violated" ]) "violated"
        && String.equal (R.badge_word [ "undecided"; "unevaluated" ]) "undecided"
        && String.equal (R.badge_word [ "unevaluated" ]) "unevaluated"
        && String.equal (R.outcome_word (Some "error")) "violated"
        && String.equal (R.outcome_word None) "unevaluated")
  }

(* The fixture carries the fields of [Canary_bridge_driver.record_fields],
   which the framework test holds the script to writing, so writer and
   reader meet at one list rather than at a run. *)
let bridge_record_test : Canary_project_test.pure_test =
  { name = "overview.bridge_record_is_read";
    holds = "A bridge step's record is read as what it says: three node names, their sublabels, and one sentence per edge around the bridge.";
    check =
      (fun () ->
        let module R = Canary_overview_runs in
        let module T = Canary_topology in
        let fixture ~holds ~dispatched ~names_bridge =
          Yojson.Basic.from_string
            (Printf.sprintf
               {|{ "kind": "bridge", "pm": "opam", "bridge_kind": "conf_package",
                   "package": "conf-gmp", "installed_version": "5",
                   "depexts": [ "libgmp-dev" ],
                   "depext_versions": { "libgmp-dev": "2:6.3.0+dfsg-2ubuntu6.1" },
                   "sys_pm": "apt", "binding_package": "zarith",
                   "binding_depends": "\"ocaml\" \"conf-gmp\"",
                   "binding_names_bridge": %b,
                   "predicate": "[ \"sh\" \"-c\" \"pkg-config --print-errors --exists gmp\" ]",
                   "query": { "tool": "pkg-config",
                              "argv": [ "pkg-config", "--print-errors", "--exists", "gmp" ],
                              "modules": [ "gmp" ], "fallback": null },
                   "check": { "dispatched": %b, "holds": %s, "rc": 0, "output": null },
                   "capability": [ { "module": "gmp", "version": "6.3.0",
                                     "libdir": "/usr/lib/x86_64-linux-gnu",
                                     "pcfile": "/usr/lib/x86_64-linux-gnu/pkgconfig/gmp.pc",
                                     "owner": "libgmp-dev" } ] }|}
               names_bridge dispatched
               (if dispatched then Bool.to_string holds else "null"))
        in
        let ok = fixture ~holds:true ~dispatched:true ~names_bridge:true in
        let fields_ok =
          match ok with
          | `Assoc kv ->
              List.for_all Canary_bridge_driver.record_fields ~f:(fun f ->
                  List.Assoc.mem kv f ~equal:String.equal)
          | _ -> false
        in
        let obs j e = List.Assoc.find (R.bridge_observations j) e ~equal:String.equal in
        let has_sub s sub = String.is_substring s ~substring:sub in
        fields_ok
        && Poly.equal (R.bridge_names ok)
             [ ("bridge", "conf-gmp"); ("cap", "gmp.pc"); ("pkg_sys", "libgmp-dev") ]
        && Poly.equal (R.bridge_sublabels ok)
             [ ("bridge", "installed 5");
               ("pkg_sys", "2:6.3.0+dfsg-2ubuntu6.1");
               ("cap", "gmp 6.3.0") ]
        && Poly.equal (R.bridge_observations ok)
             [ ("depends", "zarith's depends names conf-gmp");
               ("conf_probe",
                "conf-gmp's check: pkg-config --print-errors --exists gmp — holds");
               ("depext", "conf-gmp maps to libgmp-dev");
               ("resolve_sys", "installed here: libgmp-dev 2:6.3.0+dfsg-2ubuntu6.1");
               ("realize_cap",
                "libgmp-dev ships /usr/lib/x86_64-linux-gnu/pkgconfig/gmp.pc");
               ("discover", "pkg-config gmp → 6.3.0 in /usr/lib/x86_64-linux-gnu") ]
        && List.for_all (R.bridge_names ok) ~f:(fun (n, _) ->
               Option.is_some (T.node_by_id n))
        && List.for_all (R.bridge_observations ok) ~f:(fun (e, _) ->
               List.exists T.edges ~f:(fun x -> String.equal x.T.eg_id e))
        && (match obs (fixture ~holds:false ~dispatched:true ~names_bridge:true) "conf_probe" with
            | Some s -> has_sub s "does NOT hold"
            | None -> false)
        && (match obs (fixture ~holds:false ~dispatched:false ~names_bridge:true) "conf_probe" with
            | Some s -> has_sub s "not dispatched" && not (has_sub s "holds")
            | None -> false)
        && (match obs (fixture ~holds:true ~dispatched:true ~names_bridge:false) "depends" with
            | Some s -> has_sub s "does NOT name"
            | None -> false))
  }

(* An edge with claims has two badges: a filled one, shown only where an
   agreement on the edge has an evaluator, and a hollow one, shown only
   where an agreement on it has none. Held over every edge against the
   registry, read directly rather than through
   [Canary_topology.implemented], so a claim that lands flips its badge
   and this says so. *)
let placeholder_badges_test : Canary_project_test.pure_test =
  { name = "overview.placeholders_are_drawn_as_such";
    holds = "A claim with no evaluator is drawn as a placeholder, never as a checked claim.";
    check =
      (fun () ->
        let module T = Canary_topology in
        let page =
          Canary_overview_page.render Canary_registry.all_specs ~overview:""
            ~generated_at:"test"
        in
        (* §1's diagram draws every edge (a choice hides one by class), so
           its group is the one read *)
        let template =
          match String.substr_index page ~pattern:{|<div class="join" id="join">|} with
          | None -> ""
          | Some i -> String.drop_prefix page i
        in
        let group_of id =
          match
            String.substr_index template ~pattern:(Printf.sprintf {|data-edge="%s"|} id)
          with
          | None -> None
          | Some i ->
              let rest = String.drop_prefix template i in
              Option.map (String.substr_index rest ~pattern:"</g>") ~f:(String.prefix rest)
        in
        (* the registry's own answer, not the topology's *)
        let evaluated slug =
          match Canary_agreement.agreement_named slug with
          | None -> false
          | Some r ->
              List.exists r.Canary_agreement.ag.Canary_agreement_common.ag_methods
                ~f:(fun m -> Option.is_some m.Canary_agreement_common.m_eval)
        in
        let bridge_edges = [ "depends"; "conf_probe"; "depext"; "discover" ] in
        let shown g cls = String.is_substring g ~substring:(Printf.sprintf {|class="cbadge %s"|} cls) in
        (* every bridge edge carries a claim; the gate on conf_probe is
           checked, and every other one is a candidate, named with no
           evaluator *)
        List.for_all bridge_edges ~f:(fun id ->
            (not (List.is_empty (T.claim_sites_on id)))
            && List.for_all (T.claim_sites_on id) ~f:(fun p ->
                   if String.equal p.T.cs_claim "gate_admits_the_world" then
                     evaluated p.T.cs_claim && String.equal id "conf_probe"
                   else
                     (not (evaluated p.T.cs_claim))
                     && List.exists Canary_agreement.proposed_agreements ~f:(fun c ->
                            String.equal c.Canary_agreement.prop_slug p.T.cs_claim)))
        && List.for_all T.edges ~f:(fun e ->
               let sites = T.claim_sites_on e.T.eg_id in
               match group_of e.T.eg_id with
               | None -> false
               | Some g ->
                   (* an edge nothing is placed on has no badge at all *)
                   (if List.is_empty sites then
                      not (String.is_substring g ~substring:"cbadge")
                    else
                      String.is_substring g ~substring:"cbadge chk"
                      && String.is_substring g ~substring:"cbadge cand")
                   && ((not (shown g "chk"))
                      || List.exists sites ~f:(fun p -> evaluated p.T.cs_claim))
                   && ((not (shown g "cand"))
                      || List.exists sites ~f:(fun p -> not (evaluated p.T.cs_claim))))
        (* the census and the table's [?] marks read [implemented]: it is
           the registry's answer, whatever route computes it *)
        && List.for_all T.claim_sites ~f:(fun cs ->
               Bool.equal (T.implemented cs) (evaluated cs.T.cs_claim))
        (* [pack] and [run] show only the hollow badge *)
        && List.for_all [ "pack"; "run" ] ~f:(fun id ->
               match group_of id with
               | Some g -> (not (shown g "chk")) && shown g "cand"
               | None -> false))
  }

(* The list of hints is [Canary_overview_looks.visual_hints]. Every
   stylesheet rule for §1's diagram and §0.2's figure belongs to exactly
   one hint or to the base look, every hint is applied and explained, and
   no two hints that can show on one kind of element look alike. Only a
   hint's own rules count, which is why the muted term's rule states its
   italics. See design/overview.md §5. *)
let visual_vocabulary_test : Canary_project_test.pure_test =
  { name = "overview.visual_vocabulary_is_one_list";
    holds = "The overview's visual vocabulary is one list of hints.";
    check =
      (fun () ->
        let module P = Canary_overview_looks in
        let words s =
          List.filter (String.split_on_chars s ~on:[ ' '; '\n'; '\t' ]) ~f:(fun w ->
              not (String.is_empty w))
        in
        let norm s = String.concat ~sep:" " (words s) in
        (* the stylesheet's innermost blocks: selector → declarations *)
        let rules =
          let s = Canary_overview_page.css () in
          let n = String.length s in
          let rec go i start acc =
            if i >= n then List.rev acc
            else
              match s.[i] with
              | '{' -> (
                  match String.index_from s (i + 1) '}' with
                  | None -> List.rev acc
                  | Some j ->
                      let body = String.sub s ~pos:(i + 1) ~len:(j - i - 1) in
                      if String.mem body '{' then go (i + 1) (i + 1) acc
                      else
                        go (j + 1) (j + 1)
                          ((norm (String.sub s ~pos:start ~len:(i - start)), body) :: acc))
              | '}' -> go (i + 1) (i + 1) acc
              | _ -> go (i + 1) start acc
          in
          go 0 0 []
        in
        let ident c = Char.is_alphanum c || Char.equal c '-' || Char.equal c '_' in
        (* does a selector name the class [c]? *)
        let has_class sel c =
          let pat = "." ^ c in
          List.exists (String.substr_index_all sel ~may_overlap:false ~pattern:pat) ~f:(fun i ->
              let k = i + String.length pat in
              k >= String.length sel || not (ident sel.[k]))
        in
        let scope =
          [ "band"; "bandlabel"; "sidecap"; "node"; "ncase"; "nplace"; "edge"; "elabel";
            "cbadge"; "cnum"; "phm"; "declmark"; "gone";
            (* the components' boxes, which Figure 3 names the same way *)
            "cbx"; "cbox"; "ctab"; "cname"; "csub"; "shown";
            (* §0.2's figure *)
            "flow"; "fbox"; "fshape"; "ffold"; "fline"; "fhead"; "flink"; "flane"; "fsub";
            "fnote"; "fdot"; "fagent" ]
        in
        let in_scope sel =
          List.exists scope ~f:(has_class sel) || String.is_prefix sel ~prefix:".selbar button"
        in
        let scoped = List.filter_map rules ~f:(fun (sel, _) -> Option.some_if (in_scope sel) sel) in
        let hints = P.visual_hints in
        let claimed_once =
          List.for_all scoped ~f:(fun sel ->
              List.count hints ~f:(fun h -> List.mem h.P.vh_rules sel ~equal:String.equal)
              + (if List.mem P.vocabulary_base sel ~equal:String.equal then 1 else 0)
              = 1)
        in
        let rules_exist =
          List.for_all hints ~f:(fun h ->
              List.for_all h.P.vh_rules ~f:(List.mem scoped ~equal:String.equal))
          && List.for_all P.vocabulary_base ~f:(List.mem scoped ~equal:String.equal)
        in
        let page =
          Canary_overview_page.render Canary_registry.all_specs ~overview:"" ~generated_at:"test"
        in
        (* every class token the page's markup uses *)
        let markup_classes =
          List.concat_map
            (String.substr_index_all page ~may_overlap:false ~pattern:{|class="|})
            ~f:(fun i ->
              let from = i + String.length {|class="|} in
              match String.index_from page from '"' with
              | None -> []
              | Some j -> words (String.sub page ~pos:from ~len:(j - from)))
        in
        let applied c =
          List.mem markup_classes c ~equal:String.equal
          || String.is_substring page ~substring:(Printf.sprintf "'%s'" c)
          || List.exists [ "st-"; "cl-" ] ~f:(fun prefix ->
                 String.is_prefix c ~prefix
                 && String.is_substring page ~substring:(Printf.sprintf "'%s'+" prefix)
                 && String.is_substring page
                      ~substring:(Printf.sprintf "'%s'" (String.chop_prefix_exn c ~prefix)))
        in
        let all_applied =
          List.for_all hints ~f:(fun h -> List.for_all h.P.vh_classes ~f:applied)
        in
        let keyed h =
          match h.P.vh_key with P.Chain_key | P.Run_key | P.Flow_key -> true | _ -> false
        in
        let explained =
          List.for_all hints ~f:(fun h ->
              match h.P.vh_key with
              | P.Chain_key | P.Run_key | P.Flow_key ->
                  (not (String.is_empty h.P.vh_sample)) && not (String.is_empty h.P.vh_says)
              | P.Drawn texts ->
                  (not (List.is_empty texts))
                  && List.for_all texts ~f:(fun t -> String.is_substring page ~substring:t)
              | P.No_key why -> not (String.is_empty why))
          && String.is_substring page ~substring:(P.key_html P.Chain_key)
          && String.is_substring page ~substring:(P.key_html P.Run_key)
          && String.is_substring page ~substring:(P.key_html P.Flow_key)
        in
        let samples = List.filter_map hints ~f:(fun h -> Option.some_if (keyed h) h.P.vh_sample) in
        let samples_unique =
          List.length (List.dedup_and_sort samples ~compare:String.compare) = List.length samples
        in
        (* every sample the stylesheet styles belongs to an entry *)
        let sample_classes =
          List.filter_map rules ~f:(fun (sel, _) ->
              if List.exists [ ".sw"; ".swl"; ".nm-"; ".kbtn"; ".clm" ] ~f:(fun p ->
                     String.is_prefix sel ~prefix:p)
              then
                List.last
                  (List.filter (String.split_on_chars sel ~on:[ '.'; ' ' ]) ~f:(fun w ->
                       not (String.is_empty w)))
              else None)
        in
        let samples_used =
          List.for_all sample_classes ~f:(fun c ->
              List.exists samples ~f:(fun s ->
                  List.exists (String.substr_index_all s ~may_overlap:false ~pattern:{|class="|})
                    ~f:(fun i ->
                      let from = i + String.length {|class="|} in
                      match String.index_from s from '"' with
                      | None -> false
                      | Some j ->
                          List.mem (words (String.sub s ~pos:from ~len:(j - from))) c
                            ~equal:String.equal)))
        in
        (* the look, bucketed the way a reader sees it: a 1.8px and a 2px
           line are one width, a dash of 1 and one of 2 are both dots *)
        let number s =
          Float.of_string_opt (String.strip (String.chop_suffix_if_exists s ~suffix:"px"))
        in
        let bucket (prop, value) : (string * string) list =
          let v = String.strip value in
          let colours =
            List.filter_map (words v) ~f:(fun w ->
                Option.some_if (String.is_prefix w ~prefix:"var(" || String.is_prefix w ~prefix:"#") w)
          in
          match prop with
          | "stroke" | "fill" | "color" | "border-color" | "background" ->
              [ ("colour", v) ]
          | "stroke-dasharray" -> (
              match List.filter_map (words v) ~f:number with
              | [] -> [ ("dash", "solid") ]
              | [ a; _ ] when Float.(a <= 2.) -> [ ("dash", "dots") ]
              | [ _; _ ] -> [ ("dash", "dashes") ]
              | _ -> [ ("dash", "dash-dot") ])
          | "stroke-width" -> (
              match number v with
              | Some w ->
                  [ ("width", if Float.(w < 1.5) then "thin" else if Float.(w < 2.5) then "medium" else "thick") ]
              | None -> [])
          | "opacity" -> (
              match number v with
              | Some o ->
                  [ ("opacity", if Float.(o < 0.3) then "faint" else if Float.(o < 0.75) then "half" else "full") ]
              | None -> [])
          | "font-style" -> [ ("slant", v) ]
          | "font-weight" -> [ ("weight", v) ]
          | "display" -> [ ("display", v) ]
          | "font" -> if String.is_substring v ~substring:"italic" then [ ("slant", "italic") ] else []
          | "border" | "border-top" ->
              List.map colours ~f:(fun c -> ("colour", c))
              @ List.filter_map [ ("dashed", "dashes"); ("dotted", "dots"); ("solid", "solid") ]
                  ~f:(fun (w, d) -> Option.some_if (String.is_substring v ~substring:w) ("dash", d))
          | _ -> []
        in
        let look (h : P.visual_hint) =
          List.concat_map h.P.vh_rules ~f:(fun sel ->
              match List.Assoc.find rules sel ~equal:String.equal with
              | None -> []
              | Some body ->
                  List.concat_map (String.split body ~on:';') ~f:(fun decl ->
                      match String.lsplit2 decl ~on:':' with
                      | None -> []
                      | Some (p, v) -> bucket (String.strip p, v)))
          |> List.dedup_and_sort ~compare:Poly.compare
        in
        let overlap a b =
          match (a, b) with
          | P.Always, _ | _, P.Always -> true
          | P.Generic, P.Generic | P.Recorded, P.Recorded -> true
          | P.Generic, P.Recorded | P.Recorded, P.Generic -> false
        in
        let distinct_looks =
          List.for_all hints ~f:(fun a ->
              List.for_all hints ~f:(fun b ->
                  String.equal a.P.vh_id b.P.vh_id
                  || (not (Poly.equal a.P.vh_element b.P.vh_element))
                  || (not (overlap a.P.vh_mode b.P.vh_mode))
                  || List.is_empty (look a)
                  || not (Poly.equal (look a) (look b))))
        in
        (not (List.is_empty scoped)) && claimed_once && rules_exist && all_applied && explained
        && samples_unique && samples_used && distinct_looks)
  }

(* §0's outline, figure and table are [Canary_overview_flow]'s data.
   Every slot of page.html belongs to exactly one section or to the page,
   so a new part of the page takes a place in the outline; each heading
   reads as the outline lists it, in order; every section the data links
   to exists; and the figure's boxes fit the canvas without overlapping,
   every arrow straight between ends that face each other. See
   design/overview.md §1. *)
let flow_test : Canary_project_test.pure_test =
  { name = "overview.flow_is_the_page";
    holds = "Every template slot of §0 belongs to one section, each heading reads as the outline lists it, and Figure 1's boxes fit without overlapping.";
    check =
      (fun () ->
        let module F = Canary_overview_flow in
        let slots = Canary_overview_assets.slots "page.html" in
        let claimed =
          F.page_slots @ F.front_slots @ List.concat_map F.sections ~f:(fun s -> s.F.sc_slots)
        in
        let slots_ok =
          List.for_all slots ~f:(fun sl -> List.count claimed ~f:(String.equal sl) = 1)
          && List.for_all claimed ~f:(List.mem slots ~equal:String.equal)
        in
        (* with §2 itself, whose subsection §2.1 it renders *)
        let page =
          Canary_overview_page.render Canary_registry.all_specs
            ~overview:
              (Canary_agreement_overview.render
                 (Canary_agreement_overview.chains_of
                    (Canary_matrix.matrix_of Canary_registry.all_projects)))
            ~generated_at:"test"
        in
        (* each heading, as the outline lists it, at increasing places *)
        let at =
          List.map F.sections ~f:(fun s ->
              String.substr_index page
                ~pattern:(Printf.sprintf {|id="%s">%s<|} s.F.sc_anchor (F.heading s)))
        in
        let anchors_ok =
          List.for_all at ~f:Option.is_some
          && (let ps = List.filter_map at ~f:Fn.id in
              List.for_all2_exn (List.drop_last_exn ps) (List.tl_exn ps) ~f:(fun a b -> a < b))
        in
        let named =
          List.concat_map F.subjects ~f:(fun s ->
              List.concat_map [ s.F.sj_code; s.F.sj_run ] ~f:(fun l ->
                  List.concat_map l.F.ly_shown ~f:snd))
          @ List.concat_map F.boxes ~f:(fun b ->
                List.filter_map b.F.bx_lines ~f:(function F.Link (n, _) -> Some n | _ -> None))
        in
        let sections_ok = List.for_all named ~f:(fun n -> Option.is_some (F.section_of n)) in
        let inside b =
          b.F.bx_x >= 0 && b.F.bx_y >= 0
          && b.F.bx_x + b.F.bx_w <= F.canvas_w
          && b.F.bx_y + b.F.bx_h <= F.canvas_h
        in
        let apart a b =
          a.F.bx_x + a.F.bx_w <= b.F.bx_x
          || b.F.bx_x + b.F.bx_w <= a.F.bx_x
          || a.F.bx_y + a.F.bx_h <= b.F.bx_y
          || b.F.bx_y + b.F.bx_h <= a.F.bx_y
        in
        let geometry_ok =
          List.for_all F.boxes ~f:inside
          && List.for_all F.boxes ~f:(fun a ->
                 List.for_all F.boxes ~f:(fun b -> String.equal a.F.bx_id b.F.bx_id || apart a b))
          && List.for_all F.arrows ~f:(fun a -> Option.is_some (F.route a))
        in
        slots_ok && anchors_ok && sections_ok && geometry_ok)
  }

(* Figure 1 draws information flow: steps write files, and files are read,
   so an arrow into a file leaves a step. *)
let flow_files_written_test : Canary_project_test.pure_test =
  { name = "overview.flow_files_are_written_by_steps";
    holds = "In Figure 1 every arrow into a file leaves a step, so no file is drawn as making another.";
    check =
      (fun () ->
        let module F = Canary_overview_flow in
        let kind id = Option.map (F.box_by_id id) ~f:(fun b -> b.F.bx_kind) in
        let into_files =
          List.filter F.arrows ~f:(fun a -> Poly.equal (kind a.F.ar_to) (Some F.File))
        in
        let bad =
          List.filter into_files ~f:(fun a -> not (Poly.equal (kind a.F.ar_from) (Some F.Step)))
        in
        List.iter bad ~f:(fun a ->
            Fmt.pr "    %s -> %s: a file not written by a step@." a.F.ar_from a.F.ar_to);
        (not (List.is_empty into_files)) && List.is_empty bad)
  }

(* A recorded row can be flushed only if it says how it was read: a value,
   the date it was read, and how to read it again. The page shows every
   computed and recorded row. *)
let status_rows_test : Canary_project_test.pure_test =
  { name = "overview.status_says_how_each_number_is_read";
    holds = "Every recorded row of where the project stands has a value, the date it was read and how to read it again, and the page shows every row.";
    check =
      (fun () ->
        let module S = Canary_overview_status in
        let d = S.data () in
        let dated s =
          String.length s = 10
          && String.for_alli s ~f:(fun i c ->
                 if i = 4 || i = 7 then Char.equal c '-' else Char.is_digit c)
        in
        let row_ok (r : S.recorded) =
          let ok =
            (not (String.is_empty r.S.rc_what))
            && (not (String.is_empty r.S.rc_value))
            && (not (String.is_empty r.S.rc_how))
            && dated r.S.rc_as_of
          in
          if not ok then Fmt.pr "    %S lacks a value, a date or a how@." r.S.rc_what;
          ok
        in
        let recorded_ok =
          dated d.S.d_flushed
          && (not (List.is_empty d.S.d_recorded))
          && List.for_all d.S.d_recorded ~f:row_ok
          && List.for_all d.S.d_tracks ~f:(fun t ->
                 dated t.S.tr_judged_on && not (String.is_empty t.S.tr_now))
        in
        let esc = Canary_overview_assets.esc in
        let page =
          Canary_overview_page.render Canary_registry.all_specs ~overview:"" ~generated_at:"test"
        in
        let shown =
          String.is_substring page ~substring:{|<section id="status"|}
          && List.for_all (S.live ()) ~f:(fun (w, _, _) -> String.is_substring page ~substring:(esc w))
          && List.for_all d.S.d_recorded ~f:(fun r ->
                 String.is_substring page ~substring:(esc r.S.rc_value))
        in
        recorded_ok && shown)
  }

(* Each exhibit appears once, in list order, captioned with its label and
   title, and §0 lists it; every table on the page, and every drawing (an
   svg with role="img"), is one of them, except the front matter's tables:
   the project's working state, not the paper's. See design/overview.md §1. *)
let exhibits_test : Canary_project_test.pure_test =
  { name = "overview.exhibits_are_captioned";
    holds = "Every figure and table outside the front matter is numbered and titled, so the page and the manuscript cite one by its id.";
    check =
      (fun () ->
        let module E = Canary_overview_exhibits in
        let page =
          Canary_overview_page.render Canary_registry.all_specs
            ~overview:
              (Canary_agreement_overview.render
                 (Canary_agreement_overview.chains_of
                    (Canary_matrix.matrix_of Canary_registry.all_projects)))
            ~generated_at:"test"
        in
        let all pattern = String.substr_index_all page ~may_overlap:false ~pattern in
        let tag_at i =
          match String.index_from page i '>' with
          | Some j -> String.sub page ~pos:i ~len:(j - i + 1)
          | None -> ""
        in
        let at e = all (Printf.sprintf {|id="%s"|} e.E.ex_id) in
        let captioned e =
          match at e with
          | [ p ] -> (
              match e.E.ex_kind with
              | E.Table ->
                  String.is_substring_at page ~pos:p
                    ~substring:
                      (Printf.sprintf {|id="%s"><caption>%s</caption>|} e.E.ex_id
                         (E.caption_text e))
              | E.Figure -> (
                  let close =
                    Printf.sprintf "<figcaption>%s</figcaption></figure>" (E.caption_text e)
                  in
                  match
                    ( String.substr_index page ~pos:p ~pattern:"</figure>",
                      String.substr_index page ~pos:p ~pattern:close )
                  with
                  | Some f, Some c -> f = c + String.length close - String.length "</figure>"
                  | _ -> false))
          | _ -> false
        in
        let listed e =
          String.is_substring page
            ~substring:
              (Printf.sprintf {|<li><a href="#%s">%s</a></li>|} e.E.ex_id (E.caption_text e))
        in
        let ordered =
          let ps = List.filter_map E.exhibits ~f:(fun e -> List.hd (at e)) in
          List.length ps = List.length E.exhibits
          && List.for_all2_exn (List.drop_last_exn ps) (List.tl_exn ps) ~f:(fun a b -> a < b)
        in
        let front =
          Option.bind (String.substr_index page ~pattern:{|<section id="status"|}) ~f:(fun a ->
              Option.map (String.substr_index page ~pos:a ~pattern:"</section>") ~f:(fun b ->
                  (a, b)))
        in
        let in_front i = match front with Some (a, b) -> a <= i && i < b | None -> false in
        let tables_ok =
          List.for_all (all "<table") ~f:(fun i ->
              in_front i || String.is_substring (tag_at i) ~substring:{| id="tab-|})
        in
        let drawings =
          List.filter (all "<svg") ~f:(fun i ->
              String.is_substring (tag_at i) ~substring:{|role="img"|})
        in
        let drawings_ok =
          List.length drawings
          = List.count E.exhibits ~f:(fun e -> Poly.equal e.E.ex_kind E.Figure)
          && List.for_all drawings ~f:(fun i ->
                 match String.rsplit2 (String.prefix page i) ~on:'<' with
                 | Some (_, t) ->
                     String.is_prefix t ~prefix:{|figure class="exhibit" id="fig-|}
                     && String.is_suffix t ~suffix:">"
                 | None -> false)
        in
        List.for_all E.exhibits ~f:(fun e -> captioned e && listed e)
        && ordered && tables_ok && drawings_ok)
  }

(* The band a choice of the four buttons draws is its own where some
   chain has it, else the nearest (the native side's package manager let
   go first, then the language side's), and the note names what was let
   go; a recorded world's names come before its package's; the page opens
   in the drawing the export draws; and the page's script holds only the
   lookups. See design/overview.md §1. *)
let choice_resolved_test : Canary_project_test.pure_test =
  { name = "overview.choice_is_resolved_once";
    holds = "What a choice on the page draws is resolved once, in OCaml.";
    check =
      (fun () ->
        let module J = Canary_overview_join in
        let module Dr = Canary_overview_draw in
        let module R = Canary_overview_runs in
        let j = J.of_projects Canary_registry.all_specs in
        let has_band ps pl k =
          List.Assoc.mem j.J.jn_bands
            (String.concat ~sep:"|" [ k; Option.value ps ~default:"*"; Option.value pl ~default:"*" ])
            ~equal:String.equal
        in
        let resolved_ok =
          List.for_all (J.choice_keys j) ~f:(fun (key, (k, ps, pl)) ->
              let r = J.resolve j ~k ~native:ps ~lang:pl in
              let expect =
                List.find [ (ps, pl); (None, pl); (ps, None); (None, None) ] ~f:(fun (a, b) ->
                    has_band a b k)
              in
              let dropped =
                match expect with
                | Some (a, b) ->
                    List.filter_opt
                      [ (if Option.is_none a then ps else None); (if Option.is_none b then pl else None) ]
                | None -> []
              in
              Option.equal String.equal r.J.rv_band
                (Option.map expect ~f:(fun (a, b) ->
                     String.concat ~sep:"|"
                       [ k; Option.value a ~default:"*"; Option.value b ~default:"*" ]))
              && Bool.equal (String.is_empty r.J.rv_note) (List.is_empty dropped)
              && List.for_all dropped ~f:(fun p -> String.is_substring r.J.rv_note ~substring:p)
              && (List.Assoc.mem j.J.jn_bands key ~equal:String.equal
                 || not (List.is_empty dropped)))
        in
        (* no chain canary has tells the two orders apart, so a made-up
           pair of bands does: the native side's manager goes first *)
        let native_first =
          match (j.J.jn_bands, J.pms J.Native, J.pms J.Language) with
          | (_, b) :: _, ps :: _, pl :: _ ->
              let ps = Canary_store.string_of_pm ps and pl = Canary_store.string_of_pm pl in
              let j' = { j with J.jn_bands = [ ("k|*|" ^ pl, b); ("k|" ^ ps ^ "|*", b) ] } in
              let r = J.resolve j' ~k:"k" ~native:(Some ps) ~lang:(Some pl) in
              Option.equal String.equal r.J.rv_band (Some ("k|*|" ^ pl))
              && String.is_substring r.J.rv_note ~substring:("chain with " ^ ps ^ " —")
              && String.is_substring r.J.rv_note ~substring:("chains with " ^ pl ^ ".")
          | _ -> false
        in
        let views =
          Dr.keyed_views (R.views (Canary_matrix.matrix_of Canary_registry.all_projects))
        in
        let recorded_first =
          List.for_all views ~f:(fun (key, v) ->
              let d =
                Dr.drawing j ~views
                  { (Dr.opening j) with Dr.ch_package = Some v.R.vw_case; ch_world = Some key }
              in
              List.for_all (R.view_lines v) ~f:(fun (n, l) ->
                  Option.exists (List.Assoc.find d.Dr.dr_lines n ~equal:String.equal) ~f:(fun x ->
                      String.equal x.R.ln_text l.R.ln_text
                      && Bool.equal x.R.ln_recorded l.R.ln_recorded)))
        in
        let opening_ok =
          let d = Dr.drawing j ~views:[] (Dr.opening j) in
          let gone, dead = J.default_drawing j in
          List.equal String.equal d.Dr.dr_gone gone && List.equal String.equal d.Dr.dr_dead dead
        in
        let script = Canary_overview_assets.read "page.js" in
        let script_ok =
          List.for_all [ "J.choices"; "edge_counts"; "mech.counts"; "v.lines" ] ~f:(fun s ->
              String.is_substring script ~substring:s)
          && List.for_all
               [ "nearest"; "pm_terms"; "sys_pm"; "J.sources"; "J.kinds"; ".pms"; "'checked'" ]
               ~f:(fun s -> not (String.is_substring script ~substring:s))
        in
        (not (List.is_empty views)) && resolved_ok && native_first && recorded_first && opening_ok
        && script_ok)
  }

(* A written table is the page's without its caption; a written figure
   ends with the page's drawing and stands alone (its size, its
   namespace, every colour it uses defined, no dark mode, no entity XML
   lacks); and a choice of chain writes only Figure 2 and the lines
   table. See design/overview.md §1. *)
let exhibits_export_test : Canary_project_test.pure_test =
  { name = "overview.exhibits_are_exported";
    holds = "The export writes each of the page's exhibits as the page shows it, without its number, or names it as not written, with why.";
    check =
      (fun () ->
        let module E = Canary_overview_exhibits in
        let module X = Canary_overview_export in
        let overview =
          Canary_agreement_overview.(
            render (chains_of (Canary_matrix.matrix_of Canary_registry.all_projects)))
        in
        let page =
          Canary_overview_page.render Canary_registry.all_specs ~overview ~generated_at:"test"
        in
        let files = X.files Canary_registry.all_specs ~overview in
        let file_of e = List.Assoc.find files (E.file_name e) ~equal:String.equal in
        (* the captions name exactly the files the export writes *)
        let named =
          let pat = {|<code class="exfile" title="|} in
          List.filter_map (String.substr_index_all page ~may_overlap:false ~pattern:pat) ~f:(fun i ->
              Option.bind (String.index_from page (i + String.length pat) '>') ~f:(fun o ->
                  Option.map (String.index_from page o '<') ~f:(fun c ->
                      String.sub page ~pos:(o + 1) ~len:(c - o - 1))))
          |> List.dedup_and_sort ~compare:String.compare
          |> List.equal String.equal (List.sort (List.map files ~f:fst) ~compare:String.compare)
        in
        let accounted =
          List.for_all E.exhibits ~f:(fun e ->
              Bool.( <> ) (Option.is_some (file_of e))
                (List.Assoc.mem X.not_exported e.E.ex_id ~equal:String.equal))
          && List.length files + List.length X.not_exported = List.length E.exhibits
        in
        (* the page's drawing for a figure: what follows its opening tag *)
        let drawing id =
          let key = Printf.sprintf {|id="%s">|} id in
          Option.bind (String.substr_index page ~pattern:(key ^ "<svg")) ~f:(fun p ->
              Option.both
                (String.index_from page (p + String.length key) '>')
                (String.substr_index page ~pos:p ~pattern:"</svg><figcaption>"))
          |> Option.map ~f:(fun (o, c) -> String.sub page ~pos:(o + 1) ~len:(c + 6 - o - 1))
        in
        let stands_alone svg =
          let vars_used =
            List.map (String.substr_index_all svg ~may_overlap:false ~pattern:"var(--") ~f:(fun i ->
                let s = i + 4 in
                String.sub svg ~pos:s
                  ~len:(Option.value (String.index_from svg s ')') ~default:s - s))
          in
          let named_entities =
            List.filter_map (String.substr_index_all svg ~may_overlap:false ~pattern:"&") ~f:(fun i ->
                match String.index_from svg i ';' with
                | Some j when j - i < 8 -> Some (String.sub svg ~pos:(i + 1) ~len:(j - i - 1))
                | _ -> None)
          in
          String.is_prefix svg ~prefix:{|<svg xmlns="http://www.w3.org/2000/svg" width="|}
          && List.for_all vars_used ~f:(fun v -> String.is_substring svg ~substring:(v ^ ":"))
          && (not (String.is_substring svg ~substring:"@media"))
          && (not (String.is_substring svg ~substring:"data-theme"))
          && List.for_all named_entities ~f:(fun n ->
                 List.mem [ "amp"; "lt"; "gt"; "quot"; "apos" ] n ~equal:String.equal
                 || String.is_prefix n ~prefix:"#")
        in
        (* §1.2's rows come with the runs files: the page's script lays
           them out when the page is read, the export when it writes *)
        let body = {|<tbody id="rtbody">|} in
        let without_rows s =
          match (String.substr_index s ~pattern:body, String.substr_index s ~pattern:"</tbody>") with
          | Some a, Some b -> String.prefix s (a + String.length body) ^ String.drop_prefix s b
          | _ -> s
        in
        let rows_ok =
          match file_of (E.find "tab-results") with
          | Some c ->
              List.length (String.substr_index_all c ~may_overlap:false ~pattern:{|<tr id="row-|})
              = List.length (Canary_overview_runs.recorded_rows ())
          | None -> false
        in
        let matches e content =
          match e.E.ex_kind with
          | E.Table ->
              let same = if String.equal e.E.ex_id "tab-results" then without_rows else Fn.id in
              Option.equal String.equal
                (Option.map (E.bare_table e.E.ex_id page) ~f:same)
                (Some (same (String.strip content)))
          | E.Figure -> (
              match drawing e.E.ex_id with
              | Some d -> String.is_suffix content ~suffix:d && stands_alone content
              | None -> false)
        in
        let unnumbered content =
          not
            (List.exists [ "<caption"; "<figcaption"; "<b>Figure "; "<b>Table " ] ~f:(fun p ->
                 String.is_substring content ~substring:p))
        in
        (* a choice of chain writes only what it draws *)
        let chosen =
          let j = Canary_overview_join.of_projects Canary_registry.all_specs in
          match j.Canary_overview_join.jn_cases with
          | c :: _ -> (
              match
                Canary_overview_draw.choose j ~views:[] ~package:c.Canary_overview_join.cs_id ()
              with
              | Ok choice ->
                  List.equal String.equal
                    (List.map (X.files ~choice Canary_registry.all_specs ~overview) ~f:fst)
                    (List.map X.drawn_by_choice ~f:(fun id -> E.file_name (E.find id)))
              | Error _ -> false)
          | [] -> false
        in
        accounted && chosen && rows_ok && named
        && List.for_all E.exhibits ~f:(fun e ->
               match file_of e with Some c -> matches e c && unnumbered c | None -> true))
  }

(* §1.2 likewise lays out the rows of every runs file the page loads.
   Held over one made-up runs file per machine, each deciding the same
   claim: §2 counts it once per machine. *)
let every_machine_test : Canary_project_test.pure_test =
  { name = "overview.agreements_count_every_machine";
    holds = "§2 counts the views of every machine whose runs file the page loads.";
    check =
      (fun () ->
        let module R = Canary_overview_runs in
        let dir = "_out/canary/test/every_machine" in
        Canary_step_model.ensure_dir dir;
        match Canary_frames.checked_rows with
        | [] -> false
        | r :: _ ->
            let slug = r.Canary_agreement.ag_slug in
            List.iter R.all_file_names ~f:(fun f ->
                let view =
                  `Assoc
                    [ ("outcomes", `Assoc [ (slug, `String "holds") ]);
                      ("blames", `Assoc []) ]
                in
                Stdio.Out_channel.write_all (Stdlib.Filename.concat dir f)
                  ~data:
                    (R.prefix
                    ^ Yojson.Basic.to_string (`Assoc [ ("machine", `String f); ("views", `List [ view ]) ])
                    ^ R.suffix));
            let machines = List.length R.all_file_names in
            let chains = R.recorded_chains ~dir () in
            machines > 1
            && List.length chains = machines
            && String.is_substring
                 (Canary_agreement_overview.render chains)
                 ~substring:(Printf.sprintf "%d ✓" machines))
  }

let firing_frames_test : Canary_project_test.pure_test =
  { name = "checks.firing_is_over_the_frames";
    holds = "The agreement overview that canary checks --firing prints has the page's frames as its columns, not one per action, each lined up under its label.";
    check =
      (fun () ->
        let labels, _ = Canary_frames.text_columns in
        let text =
          Canary_agreement.pp_agreement_overview ~columns:Canary_frames.text_columns ()
        in
        let table =
          List.filter (String.split_lines text) ~f:(fun l -> String.is_substring l ~substring:" | ")
        in
        (* where each column separator falls, in characters *)
        let seps l =
          List.map (String.substr_index_all l ~may_overlap:false ~pattern:" | ") ~f:(fun i ->
              String.count (String.prefix l i) ~f:(fun c -> Char.to_int c land 0xC0 <> 0x80))
        in
        let n = List.length labels + 2 in
        match table with
        | head :: (_ :: _ as rows) ->
            let at =
              List.map labels ~f:(fun l -> String.substr_index head ~pattern:(" " ^ l ^ " "))
            in
            List.length labels = List.length Canary_frames.frames
            && List.for_all at ~f:Option.is_some
            && (let ps = List.filter_map at ~f:Fn.id in
                List.for_all2_exn (List.drop_last_exn ps) (List.tl_exn ps) ~f:(fun a b -> a < b))
            && (not (String.is_substring head ~substring:"fetch_binding_source"))
            && List.for_all rows ~f:(fun r ->
                   List.equal Int.equal (List.take (seps r) n) (List.take (seps head) n))
        | _ -> false)
  }

(* §1.2's cells are computed once, in [Canary_overview_results.cells]. A
   node's first cell shows its name and count, and a later one, where it
   is consumed, repeats the name. *)
let result_cells_test : Canary_project_test.pure_test =
  { name = "overview.result_cells_keep_their_rules";
    holds = "§1.2's cells keep their rules: a frame no step realized is hatched, a piece shows its first recorded edge, and every state has a mark.";
    check =
      (fun () ->
        let module Rs = Canary_overview_results in
        let module Fr = Canary_frames in
        let facts ?(names = []) ?(counts = []) edges =
          { Rs.f_edges = edges; f_gone = []; f_names = names; f_nodes = []; f_counts = counts;
            f_outcomes = []; f_blames = [] }
        in
        let all_ran = List.map Canary_topology.edges ~f:(fun e -> (e.Canary_topology.eg_id, "ran")) in
        let first_recorded =
          match
            List.find_map Rs.columns ~f:(fun (_, c, k) ->
                match c with Fr.Piece { edges = e1 :: e2 :: _; _ } -> Some (e1, e2, k) | _ -> None)
          with
          | None -> false
          | Some (e1, e2, k) ->
              let shows f mark =
                Option.exists (List.Assoc.find (Rs.cells f) k ~equal:String.equal)
                  ~f:(String.is_suffix ~suffix:(">" ^ mark ^ "</td>"))
              in
              shows (facts [ (e1, "absent"); (e2, "ran") ]) "✓"
              && shows (facts [ (e1, "xfail"); (e2, "ran") ]) "xf"
        in
        let hatched =
          List.for_all (Rs.cells (facts [])) ~f:(fun (_, td) ->
              String.is_substring td ~substring:"rt-off")
        in
        let node_once =
          let node_keys n =
            List.filter_map Rs.columns ~f:(fun (_, c, k) ->
                match c with Fr.Node m when String.equal m n -> Some k | _ -> None)
          in
          match
            List.find_map Canary_topology.nodes ~f:(fun nd ->
                match node_keys nd.Canary_topology.nd_id with
                | k1 :: (_ :: _ as later) -> Some (nd.Canary_topology.nd_id, k1, later)
                | _ -> None)
          with
          | None -> false
          | Some (n, k1, later) ->
              let cells =
                Rs.cells
                  (facts ~names:[ (n, ("libx", "recorded")) ] ~counts:[ (n, "3 exports") ] all_ran)
              in
              let td k = Option.value (List.Assoc.find cells k ~equal:String.equal) ~default:"" in
              String.is_substring (td k1) ~substring:{|libx <span class="rt-x">3 exports</span>|}
              && List.for_all later ~f:(fun k ->
                     String.is_substring (td k) ~substring:"rt-rep"
                     && not (String.is_substring (td k) ~substring:"rt-x"))
        in
        let marked =
          List.for_all (Canary_overview_runs.views (Canary_matrix.matrix_of Canary_registry.all_projects))
            ~f:(fun v ->
              List.for_all (Canary_overview_runs.row_of_view ~machine:"test" v).Rs.rw_cells
                ~f:(fun (_, td) -> not (String.is_suffix td ~suffix:">?</td>")))
        in
        first_recorded && hatched && node_once && marked)
  }

(* The list of marks is [Canary_matrix.outcome_marks]; a check cell
   shows its outcome's mark and look, and §2 shows the key. *)
let outcome_marks_test : Canary_project_test.pure_test =
  { name = "overview.outcome_marks_are_one_list";
    holds = "One list spells every outcome's mark: each label a log records has one entry, and the page's script spells no mark of its own.";
    check =
      (fun () ->
        let module C = Canary_agreement_common in
        let module M = Canary_matrix in
        let labels = List.map M.outcome_marks ~f:(fun o -> o.M.om_label) in
        let recorded =
          List.map ~f:C.outcome_label
            [ C.Holds; C.Violated []; C.Unavailable (C.Missing_evidence "");
              C.Unavailable (C.Missing_declaration ""); C.Unavailable (C.Nothing_to_check "");
              C.Inconclusive ""; C.Not_implemented ""; C.Not_applicable ""; C.Disabled "";
              C.Error "" ]
        in
        let script = Canary_overview_assets.read "results.js" in
        let overview =
          Canary_agreement_overview.(render (chains_of (M.matrix_of Canary_registry.all_projects)))
        in
        (* a check cell shows its outcome's mark and look: every frame
           recorded, one claim decided *)
        let module Rs = Canary_overview_results in
        let cell_shows (o : M.outcome_mark) =
          match
            List.find_map Rs.columns ~f:(fun (_, c, _) ->
                match c with Canary_frames.Check { slug; _ } -> Some slug | _ -> None)
          with
          | None -> false
          | Some slug ->
              let f =
                { Rs.f_edges =
                    List.map Canary_topology.edges ~f:(fun e -> (e.Canary_topology.eg_id, "ran"));
                  f_gone = [];
                  f_names = [];
                  f_nodes = [];
                  f_counts = [];
                  f_outcomes = [ (slug, o.M.om_label) ];
                  f_blames = [] }
              in
              List.exists (Rs.cells f) ~f:(fun (k, td) ->
                  String.is_substring k ~substring:("|c|" ^ slug ^ "|")
                  && String.is_substring td ~substring:(Printf.sprintf {|class="rt-c %s"|} o.M.om_look)
                  && String.is_suffix td ~suffix:(">" ^ Canary_overview_assets.esc o.M.om_mark ^ "</td>"))
        in
        List.for_all recorded ~f:(List.mem labels ~equal:String.equal)
        && List.length (List.dedup_and_sort labels ~compare:String.compare)
           = List.length labels
        && List.for_all M.outcome_marks ~f:cell_shows
        && List.for_all M.outcome_marks ~f:(fun o ->
               (* the word marks are the outcomes' alone; ✓ and ✗ are
                  shared with the step states by design *)
               ((not (String.for_all o.M.om_mark ~f:Char.is_print))
               || not (String.is_substring script ~substring:("'" ^ o.M.om_mark ^ "'")))
               && String.is_substring overview
                    ~substring:(Printf.sprintf "<td><code>%s</code></td>" o.M.om_label)))
  }

let agreement_laws_test : Canary_project_test.pure_test =
  { name = "overview.agreement_laws_are_listed";
    holds = "§2 lists every law the agreement rows keep, in the registry's words, under a heading that counts them.";
    check =
      (fun () ->
        let overview =
          Canary_agreement_overview.(
            render (chains_of (Canary_matrix.matrix_of Canary_registry.all_projects)))
        in
        (not (List.is_empty Canary_agreement.row_rules))
        && String.is_substring overview
             ~substring:
               (Printf.sprintf "The %d laws every row keeps" (List.length Canary_agreement.row_rules))
        && List.for_all Canary_agreement.row_rules ~f:(fun r ->
               String.is_substring overview
                 ~substring:(Canary_overview_assets.esc r.Canary_agreement.rr_says)))
  }

let mechanism_claims_test : Canary_project_test.pure_test =
  { name = "overview.mechanisms_list_their_claims";
    holds = "§3.2 lists, for each binding mechanism, exactly the registered claims that pass 2 says it carries.";
    check =
      (fun () ->
        let table = Canary_overview_tables.binding_table Canary_registry.all_specs in
        List.for_all Canary_mechanism.mechanism_catalogue ~f:(fun i ->
            let name = Canary_mechanism.string_of_mechanism i.Canary_mechanism.mi_mechanism in
            match String.substr_index table ~pattern:("<b>" ^ name ^ "</b>") with
            | None -> false
            | Some at ->
                let row =
                  let rest = String.drop_prefix table at in
                  match String.substr_index rest ~pattern:"</tr>" with
                  | Some j -> String.prefix rest j
                  | None -> rest
                in
                let shown =
                  List.filter_map Canary_agreement.agreement_registry ~f:(fun r ->
                      let s = r.Canary_agreement.ag_slug in
                      Option.some_if
                        (String.is_substring row ~substring:(Printf.sprintf {|title="%s"|} s))
                        s)
                in
                List.equal String.equal
                  (List.sort shown ~compare:String.compare)
                  (List.sort (Canary_overview_tables.carried_by i) ~compare:String.compare)))
  }

(* Each registry agreement and candidate has exactly one claim site; the
   specimens cover each reach, so a change to the rule that decides reach
   shows up as a named disagreement; the agreement table's "sits on" cell
   is the claim site's edges; and no agreement a run decided lacks an
   evaluator. *)
let agreements_sit_test : Canary_project_test.pure_test =
  { name = "overview.agreements_sit_on_the_chain";
    holds = "Every agreement sits somewhere on the chain, and every view of the agreements says where.";
    check =
      (fun () ->
        let module T = Canary_topology in
        let module M = Canary_matrix in
        let module A = Canary_agreement in
        let slugs =
          List.map A.agreement_registry ~f:(fun r -> r.A.ag_slug)
          @ List.map A.proposed_agreements ~f:(fun p -> p.A.prop_slug)
        in
        let once =
          List.for_all slugs ~f:(fun s ->
              List.count T.claim_sites ~f:(fun cs -> String.equal cs.T.cs_claim s) = 1)
          && List.length T.claim_sites = List.length slugs
        in
        let is s reach layers =
          match T.sitting_of s with
          | Some st -> Poly.equal st.T.st_reach reach && Poly.equal st.T.st_layers layers
          | None -> false
        in
        let specimens =
          is "required_symbols_exported" T.Across_sides [ T.L_artifact ]
          && is "declared_symbols_exported" (T.Own_side T.S_sys) [ T.L_package; T.L_artifact ]
          && is "api_names_present" (T.Own_side T.S_lang) [ T.L_package; T.L_artifact ]
          && is "gate_admits_the_world" T.Across_sides [ T.L_package ]
          && is "behavior_matches" T.Across_sides [ T.L_artifact; T.L_program ]
          && is "package_resolution_suffices" T.End_to_end [ T.L_pm; T.L_package; T.L_program ]
        in
        let module AO = Canary_agreement_overview in
        let m = M.matrix_of Canary_registry.all_projects in
        let overview = AO.render (AO.chains_of m) in
        (* the first cell after a row's slug that carries the site *)
        let site_cell slug =
          match String.substr_index overview ~pattern:(Printf.sprintf "<td>%s</td>" slug) with
          | None -> None
          | Some i -> (
              let rest = String.drop_prefix overview i in
              let pat = {|class="lm site">|} in
              match String.substr_index rest ~pattern:pat with
              | None -> None
              | Some j ->
                  let from = j + String.length pat in
                  Option.map (String.substr_index rest ~pos:from ~pattern:"</td>") ~f:(fun k ->
                      String.sub rest ~pos:from ~len:(k - from)))
        in
        let table_ok =
          List.for_all A.agreement_registry ~f:(fun r ->
              match (site_cell r.A.ag_slug, T.sitting_of r.A.ag_slug) with
              | Some cell, Some st -> String.equal cell (String.concat ~sep:", " st.T.st_edges)
              | _ -> false)
        in
        (* the logs agree with the registry: a run decides only a placed
           agreement with an evaluator *)
        let decided_ok =
          List.for_all (AO.decided_slugs (AO.chains_of m)) ~f:(fun s ->
              List.exists T.claim_sites ~f:(fun cs ->
                  String.equal cs.T.cs_claim s && T.implemented cs))
        in
        once && specimens && table_ok && decided_ok)
  }

(* §2's first table holds what the claim sites and the registry say: a
   row per placed claim, each part under its layer, and n/a where the
   registry row excludes a format. Specimens for each word: version tags
   are ELF-only, required symbols are checked on both formats, behaviour
   is planned, and a candidate states no format. *)
let agreements_by_layer_test : Canary_project_test.pure_test =
  { name = "overview.agreements_by_layer_lists_every_claim";
    holds = "§2's first table lists every placed claim once, each part under its layer, and marks n/a on exactly the formats its registry row excludes.";
    check =
      (fun () ->
        let module T = Canary_topology in
        let module A = Canary_agreement in
        let module Tb = Canary_overview_tables in
        let html = Tb.layers_table () in
        let rows_once =
          List.for_all T.claim_sites ~f:(fun cs ->
              List.length
                (String.substr_index_all html ~may_overlap:false
                   ~pattern:(Printf.sprintf "<td><code>%s</code></td>" cs.T.cs_claim))
              = 1)
        in
        let parts_placed =
          List.for_all T.claim_sites ~f:(fun cs ->
              let cells = Tb.layer_cells cs in
              List.for_all cs.T.cs_parts ~f:(fun pt ->
                  match List.findi T.all_components ~f:(fun _ c -> Poly.equal c pt.T.pt_component) with
                  | None -> false
                  | Some (i, _) ->
                      List.exists (List.nth_exn cells i) ~f:(fun cell ->
                          String.is_suffix cell ~suffix:(": " ^ pt.T.pt_reads))
                      && String.is_substring html
                           ~substring:(Canary_overview_assets.esc pt.T.pt_reads)))
        in
        let n_a_ok =
          List.for_all T.claim_sites ~f:(fun cs ->
              List.for_all A.all_formats ~f:(fun f ->
                  let excluded =
                    match A.agreement_named cs.T.cs_claim with
                    | Some r ->
                        not (List.mem r.A.ag_formats f ~equal:Canary_store.equal_object_format)
                    | None -> false
                  in
                  Bool.equal excluded (String.equal (Tb.format_word cs f) "n/a")))
        in
        let word slug f =
          Option.map
            (List.find T.claim_sites ~f:(fun cs -> String.equal cs.T.cs_claim slug))
            ~f:(fun cs -> Tb.format_word cs f)
        in
        let specimens =
          Poly.equal (word "declared_versions_exported" Canary_store.Macho) (Some "n/a")
          && Poly.equal (word "declared_versions_exported" Canary_store.Elf) (Some "checked")
          && Poly.equal (word "required_symbols_exported" Canary_store.Macho) (Some "checked")
          && Poly.equal (word "behavior_matches" Canary_store.Elf) (Some "planned")
          && Poly.equal (word "exports_accounted_for" Canary_store.Elf) (Some "candidate")
        in
        rows_once && parts_placed && n_a_ok && specimens)
  }

(* Nodes are drawn after edges, so a box masks what runs under it: a
   straight line may pass behind a node, but a label or badge under a box
   is lost, and an edge under a source would draw the source as package
   content. Held over the template, where every edge is drawn, with each
   label's extent estimated from its characters. *)
let edge_marks_test : Canary_project_test.pure_test =
  { name = "overview.edge_marks_clear_the_boxes";
    holds = "On the diagram, no edge's label or badge hides under a box, and no edge runs under a source.";
    check =
      (fun () ->
        let module P = Canary_overview_diagram in
        let module T = Canary_topology in
        let module J = Canary_overview_join in
        let rect_of n =
          let p = P.pos_of n and w = P.box_w_of n in
          (p.P.px - (w / 2), p.P.py - (P.box_h / 2), p.P.px + (w / 2), p.P.py + (P.box_h / 2))
        in
        let hit (a0, a1, a2, a3) (b0, b1, b2, b3) = a0 < b2 && b0 < a2 && a1 < b3 && b1 < a3 in
        let node_ids = List.map T.nodes ~f:(fun n -> n.T.nd_id) in
        (* characters, not bytes: a band label carries an em dash *)
        let chars s = String.count s ~f:(fun c -> Char.to_int c land 0xC0 <> 0x80) in
        (* the badge slots some mechanism can show on an edge: 1 = the
           first place, 2 = the hollow badge beside a filled one *)
        let slots e =
          List.concat_map (J.variants ()) ~f:(fun v ->
              match List.Assoc.find (J.mechanism_claims v) e ~equal:String.equal with
              | None -> []
              | Some xs ->
                  let c = List.count xs ~f:(fun (_, st) -> Poly.equal st T.Checked) in
                  let p = List.length xs - c in
                  (if c > 0 then [ 1 ] else []) @ if p > 0 then [ (if c > 0 then 2 else 1) ] else [])
          |> List.dedup_and_sort ~compare:Int.compare
        in
        let segments =
          List.concat_map T.edges ~f:(fun e ->
              List.filter_map e.T.eg_from ~f:(fun f ->
                  if String.equal f e.T.eg_to then None else Some (e, f)))
        in
        (* every mark, with the segment it belongs to *)
        let marks =
          List.concat_map segments ~f:(fun (e, f) ->
              let src = P.pos_of f and dst = P.pos_of e.T.eg_to in
              let mx, my = P.anchor_of e ~src ~dst in
              let w = chars (P.annotation_label e.T.eg_annotation) * 66 / 10 in
              let label =
                if List.mem P.label_starts_at_midpoint e.T.eg_id ~equal:String.equal then
                  (mx, my - 14, mx + w, my - 6)
                else (mx - (w / 2), my - 14, mx + (w / 2), my - 6)
              in
              List.map
                (label
                :: List.map (slots e.T.eg_id) ~f:(fun k ->
                       let bx = if k = 1 then mx + 46 else mx + 67 in
                       (bx - 9, my - 9, bx + 9, my + 9)))
                ~f:(fun m -> ((e.T.eg_id, f), m)))
        in
        let band_labels =
          List.map P.bands_def ~f:(fun (y, _, label, _) ->
              let w = chars label * 72 / 10 in
              ((P.canvas_w / 2) - (w / 2), y + 11, (P.canvas_w / 2) + (w / 2), y + 22))
        in
        let under_a_box m = List.find node_ids ~f:(fun n -> hit m (rect_of n)) in
        let seg (e, f) = e ^ " from " ^ f in
        let fails =
          List.filter_map marks ~f:(fun (s, m) ->
              Option.map (under_a_box m) ~f:(fun n -> seg s ^ ": a mark under " ^ n))
          @ List.concat_map marks ~f:(fun (s, m) ->
                List.filter_map marks ~f:(fun (s', m') ->
                    Option.some_if
                      ((not (Poly.equal s s')) && Poly.(s < s') && hit m m')
                      (seg s ^ " and " ^ seg s' ^ ": marks overlap")))
          @ List.filter_map marks ~f:(fun (s, m) ->
                Option.some_if (List.exists band_labels ~f:(hit m)) (seg s ^ ": a mark on a band's title"))
          @ List.filter_map band_labels ~f:(fun b ->
                Option.map (under_a_box b) ~f:(fun n -> "a band's title under " ^ n))
          @ List.concat_map segments ~f:(fun (e, f) ->
                let src = P.pos_of f and dst = P.pos_of e.T.eg_to in
                List.filter_map P.side_nodes ~f:(fun n ->
                    let b0, b1, b2, b3 = rect_of n in
                    Option.some_if
                      ((not (String.equal n f || String.equal n e.T.eg_to))
                      && List.exists (List.range 1 100) ~f:(fun t ->
                             let px = src.P.px + ((dst.P.px - src.P.px) * t / 100)
                             and py = src.P.py + ((dst.P.py - src.P.py) * t / 100) in
                             b0 < px && px < b2 && b1 < py && py < b3))
                      (seg (e.T.eg_id, f) ^ ": runs under " ^ n)))
          |> List.dedup_and_sort ~compare:String.compare
        in
        List.iter fails ~f:(Fmt.pr "    %s@.");
        List.is_empty fails)
  }

(* §1's filled count per mechanism is pass 2's answer, asked
   independently: the agreements on the edge that
   [Canary_project_analysis.carried_slugs] lists for it. A recorded view
   counts the same list for its chain's mechanism, and the page's script
   recounts from those lists. *)
let badge_counts_test : Canary_project_test.pure_test =
  { name = "overview.badges_count_what_applies";
    holds = "A badge counts exactly the agreements pass 2 says apply on its edge for the drawn mechanism, and a recorded view's badges count the same.";
    check =
      (fun () ->
        let module T = Canary_topology in
        let module J = Canary_overview_join in
        let module R = Canary_overview_runs in
        let variant_of m =
          List.find (J.variants ()) ~f:(fun v -> Poly.equal v.T.av_mechanism m)
        in
        let per_mechanism_ok =
          List.for_all (J.variants ()) ~f:(fun v ->
              let carried =
                Canary_project_analysis.carried_slugs ~mechanism:v.T.av_mechanism
                  ~lang:v.T.av_lang ~declared:None
              in
              let counted = J.mechanism_claims v in
              List.for_all T.edges ~f:(fun e ->
                  let listed =
                    Option.value ~default:[]
                      (List.Assoc.find counted e.T.eg_id ~equal:String.equal)
                  in
                  let checked =
                    List.filter_map listed ~f:(fun (s, st) ->
                        if Poly.equal st T.Checked then Some s else None)
                  in
                  let hidden = List.mem (T.with_edges v.T.av_hidden) e.T.eg_id ~equal:String.equal in
                  if hidden then List.is_empty listed
                  else
                    List.equal String.equal
                      (List.sort checked ~compare:String.compare)
                      (List.sort ~compare:String.compare
                         (List.filter_map (T.claim_sites_on e.T.eg_id) ~f:(fun cs ->
                              if List.mem carried cs.T.cs_claim ~equal:String.equal then
                                Some cs.T.cs_claim
                              else None)))
                    && List.for_all listed ~f:(fun (s, _) ->
                           List.exists (T.claim_sites_on e.T.eg_id) ~f:(fun cs ->
                               String.equal cs.T.cs_claim s))))
        in
        let m = Canary_matrix.matrix_of Canary_registry.all_projects in
        let views = R.views m in
        let views_ok =
          (not (List.is_empty views))
          && List.for_all views ~f:(fun (v : R.view) ->
                 match v.R.vw_chain with
                 | None -> false
                 | Some c -> (
                     match variant_of c.Canary_matrix.ch_mechanism with
                     | None -> false
                     | Some var ->
                         let from_join = J.mechanism_claims var in
                         let absent e =
                           Poly.equal (List.Assoc.find v.R.vw_edges e ~equal:String.equal)
                             (Some "absent")
                         in
                         List.for_all v.R.vw_edge_claims ~f:(fun (e, xs) ->
                             Poly.equal (List.Assoc.find from_join e ~equal:String.equal) (Some xs))
                         (* the same list exactly, less the edges this chain
                            lacks and the ones this world does not realize *)
                         && List.for_all from_join ~f:(fun (e, _) ->
                                Bool.equal
                                  (List.Assoc.mem v.R.vw_edge_claims e ~equal:String.equal)
                                  (not (List.mem v.R.vw_gone e ~equal:String.equal || absent e)))
                         && List.for_all v.R.vw_edge_claims ~f:(fun (e, xs) ->
                                Bool.equal
                                  (List.Assoc.mem v.R.vw_badges e ~equal:String.equal)
                                  (List.exists xs ~f:(fun (_, st) -> Poly.equal st T.Checked)))
                         && List.for_all v.R.vw_badges ~f:(fun (e, _) ->
                                List.Assoc.mem v.R.vw_edge_claims e ~equal:String.equal)))
        in
        let j = J.of_projects Canary_registry.all_specs in
        let agreements_ok =
          match J.json j with
          | `Assoc kv -> (
              match List.Assoc.find kv "agreements" ~equal:String.equal with
              | Some (`Assoc ags) ->
                  List.for_all T.claim_sites ~f:(fun cs ->
                      match List.Assoc.find ags cs.T.cs_claim ~equal:String.equal with
                      | Some (`Assoc f) -> (
                          match List.Assoc.find f "edges" ~equal:String.equal with
                          | Some (`List es) ->
                              List.equal Poly.equal es
                                (List.map cs.T.cs_edges ~f:(fun e -> `String e))
                          | _ -> false)
                      | _ -> false)
              | _ -> false)
          | _ -> false
        in
        let page =
          Canary_overview_page.render Canary_registry.all_specs ~overview:"" ~generated_at:"test"
        in
        let page_ok =
          List.for_all
            [ "v.edge_claims"; ".claims)||{})[e]"; "J.agreements[x[0]]"; "'.cbadge.chk'";
              "'.cbadge.cand'"; ".cbadge.none"; ".join .edge.jdead .cbadge" ]
            ~f:(fun s -> String.is_substring page ~substring:s)
        in
        per_mechanism_ok && views_ok && agreements_ok && page_ok)
  }

(* The PM-solo table has a row for exactly the package managers canary
   has a driver for, its scope and store read from that driver; the
   binding table is the mechanism catalogue; and the page draws one chain
   per instance. *)
let coverage_tables_test : Canary_project_test.pure_test =
  { name = "overview.tables_list_what_canary_covers";
    holds = "The tables of §3 list every package manager with a driver, and every world's join is a cooperation they catalogue.";
    check =
      (fun () ->
        let module T = Canary_topology in
        let projects = Canary_registry.all_specs in
        let pms = Canary_store.[ Apt; Brew; Opam; Pip; Unsupported ] in
        let with_driver =
          List.filter pms ~f:(fun pm -> Option.is_some (Canary_pm.properties pm))
        in
        let rows = List.map Canary_pm_solo.table ~f:(fun r -> r.Canary_pm_solo.ps_pm) in
        let used =
          List.concat_map projects ~f:(fun (_, pr) ->
              List.concat_map pr.Canary_project_run.pr_artifacts ~f:(fun row ->
                  match Canary_project_spec.provider_of_row row with
                  | Some (Canary_store_config.Sys_pkg _) -> Canary_store.[ Apt; Brew ]
                  | Some (Canary_store_config.Lang_pkg { pm; _ }) -> [ pm ]
                  | _ -> []))
        in
        let pm_solo_ok =
          List.equal Poly.equal
            (List.sort rows ~compare:Poly.compare)
            (List.sort with_driver ~compare:Poly.compare)
          && List.for_all used ~f:(List.mem rows ~equal:Poly.equal)
          && List.for_all rows ~f:(fun pm ->
                 (not (String.equal (Canary_pm_solo.scope_of pm) "—"))
                 && not (String.equal (Canary_pm_solo.store_of pm) "—"))
          (* opam defines the bridges; the others define none *)
          && (not (List.is_empty (Canary_bridge.kinds_of_pm Canary_store.Opam)))
          && List.for_all Canary_store.[ Apt; Brew; Pip ] ~f:(fun pm ->
                 List.is_empty (Canary_bridge.kinds_of_pm pm))
        in
        (* per world: the cooperation a world realizes, both sides from its
           own placements *)
        let topos = List.concat_map projects ~f:T.topologies_of_worlds in
        (* and worlds that differ from their project read differently:
           zarith's built world bypasses conf-gmp and llvm's dev worlds
           build both sides, while their fetched worlds are bridged *)
        let kinds_of name =
          List.filter_map topos ~f:(fun ((t : T.t), (i : T.instance)) ->
              if String.equal i.T.in_project name then Some (T.coop_of t) else None)
        in
        let per_world_ok =
          List.mem (kinds_of "zarith") T.Co_conf ~equal:Poly.equal
          && List.mem (kinds_of "zarith") T.Co_artifacts ~equal:Poly.equal
          && List.mem (kinds_of "llvm") T.Co_conf ~equal:Poly.equal
          && List.mem (kinds_of "llvm") T.Co_local ~equal:Poly.equal
        in
        (* every world's topology is a catalogued cooperation kind
           ([info_of_coop] is total over them), named as its kind except
           where its join says why in its own words *)
        let coop_ok =
          List.for_all topos ~f:(fun ((t : T.t), _) ->
              match Option.try_with (fun () -> T.info_of_coop (T.coop_of t)) with
              | None -> false
              | Some info -> (
                  match t.T.tp_join with
                  | T.No_pm_between _ | T.Bridge_absorbed _ -> true
                  | T.Bridged _ | T.Artifacts_only | T.Undeclared_join ->
                      String.equal (T.character t) info.T.co_name))
          && List.length
               (List.dedup_and_sort
                  (List.map T.coop_catalogue ~f:(fun i -> i.T.co_kind))
                  ~compare:Poly.compare)
             = List.length T.coop_catalogue
        in
        let page =
          Canary_overview_page.render projects ~overview:"" ~generated_at:"test"
        in
        let section =
          match String.substr_index page ~pattern:{|<h2 id="tables">|} with
          | None -> ""
          | Some i -> (
              let rest = String.drop_prefix page i in
              match String.substr_index rest ~pattern:{|<div class="foot">|} with
              | None -> rest
              | Some j -> String.prefix rest j)
        in
        let instantiated =
          List.map topos ~f:(fun (t, _) -> T.coop_of t)
          |> List.dedup_and_sort ~compare:Poly.compare
        in
        let page_ok =
          (not (String.is_empty section))
          && List.for_all
               [ "3.1 Each package manager on its own"; "3.2 Binding mechanisms";
                 "3.3 How two package managers cooperate"; "3.4 The chains canary runs" ]
               ~f:(fun h -> String.is_substring section ~substring:h)
          (* a binding row per catalogued mechanism *)
          && List.for_all Canary_mechanism.mechanism_catalogue ~f:(fun i ->
                 String.is_substring section
                   ~substring:
                     ("<b>"
                     ^ Canary_mechanism.string_of_mechanism i.Canary_mechanism.mi_mechanism
                     ^ "</b>"))
          (* a cooperation row exactly for what is instantiated; the rest
             named as not yet covered *)
          && List.for_all T.coop_catalogue ~f:(fun i ->
                 let as_row =
                   String.is_substring section
                     ~substring:("<b>" ^ Canary_overview_assets.esc i.T.co_name ^ "</b>")
                 in
                 Bool.equal as_row (List.mem instantiated i.T.co_kind ~equal:Poly.equal))
          (* one chain per distinct instance, with its mechanism named *)
          && List.for_all projects ~f:(fun ((name, pr) as p) ->
                 let an = Canary_pipeline.analysed_of pr in
                 List.for_all (T.topologies_of_worlds p) ~f:(fun ((t : T.t), (i : T.instance)) ->
                     String.is_substring section
                       ~substring:
                         (String.concat
                            [ name; "</a></td><td>";
                              Canary_lang.string_of_lang i.T.in_lang; "</td><td>";
                              Canary_mechanism.string_of_mechanism
                                (Canary_project_analysis.mechanism_for an i.T.in_lang);
                              "</td><td>"; T.string_of_supplier t.T.tp_lang ]))
               )
        in
        pm_solo_ok && coop_ok && per_world_ok && page_ok)
  }

(* The band's rules are [Canary_topology.band_hidden]. For each
   hand-drawn case, its world's band hides exactly the band nodes the
   drawing hides and greys no edge it does not (the wheel's world comes
   from the catalogue, since z3 is muted). How the page lets a reader
   choose a band is held by [overview.chain_choices_draw_one_chain]. *)
let package_band_test : Canary_project_test.pure_test =
  { name = "overview.package_band_is_one_cooperation";
    holds = "The package band is one cooperation: its rules are one function of a topology, and a kind's band is what none of its worlds has.";
    check =
      (fun () ->
        let module T = Canary_topology in
        let module R = Canary_overview_runs in
        let projects = Canary_registry.all_specs in
        let hand = Some (hand_cases_json ()) in
        let field j k =
          match j with
          | `Assoc kv -> List.Assoc.find kv k ~equal:String.equal
          | _ -> None
        in
        let strings j =
          match j with
          | Some (`List xs) -> List.filter_map xs ~f:(function `String s -> Some s | _ -> None)
          | _ -> []
        in
        let band_only l =
          List.filter l ~f:(List.mem T.band_nodes ~equal:String.equal)
          |> List.sort ~compare:String.compare
        in
        let python_fetched a =
          Poly.equal
            (R.provision_of_kind a (Canary_basic.Binding Canary_lang.Python))
            (Some Canary_artifact.Fetched)
        in
        let cases = R.counterparts @ [ ("wheel", ("z3", python_fetched, Canary_lang.Python)) ] in
        let reproduces =
          List.for_all cases ~f:(fun (key, (project, pred, lang)) ->
              match
                ( Option.bind hand ~f:(fun h -> field h key),
                  List.Assoc.find projects project ~equal:String.equal )
              with
              | Some c, Some pr -> (
                  match List.find (Canary_project_run.scenarios_of pr) ~f:pred with
                  | None -> false
                  | Some world ->
                      let t = T.topology_of_world ~pr ~world lang in
                      let hidden =
                        T.band_hidden ~publishes:(T.publishes_of_world ~pr ~world lang) t
                      in
                      List.equal String.equal (band_only hidden)
                        (band_only (strings (field c "hidden")))
                      && List.for_all (T.band_dead t)
                           ~f:(List.mem (strings (field c "dead")) ~equal:String.equal)
                      (* and the case illustrates the cooperation its world
                         has, since §1 shows its notes with it *)
                      && List.exists Canary_overview_cases.hand_cases
                           ~f:(fun (h : Canary_overview_cases.case) ->
                             String.equal h.Canary_overview_cases.ca_key key
                             && Poly.equal h.Canary_overview_cases.ca_coop (T.coop_of t)))
              | _ -> false)
          && List.length cases = 5
        in
        let bands = T.coop_bands projects in
        let band k = List.find bands ~f:(fun b -> Poly.equal b.T.cb_kind k) in
        let hides k n =
          Option.exists (band k) ~f:(fun b -> List.mem b.T.cb_hidden n ~equal:String.equal)
        in
        let keeps k n =
          Option.exists (band k) ~f:(fun b -> not (List.mem b.T.cb_hidden n ~equal:String.equal))
        in
        let greys k e =
          Option.exists (band k) ~f:(fun b -> List.mem b.T.cb_dead e ~equal:String.equal)
        in
        let facts =
          keeps T.Co_conf "bridge" && keeps T.Co_conf "cap" && hides T.Co_conf "src_sys"
          (* opam compiles the binding source inside its install *)
          && keeps T.Co_conf "src_lang"
          && hides T.Co_unified "pm_sys" && hides T.Co_unified "pkg_sys"
          && hides T.Co_absorbed "pm_sys" && hides T.Co_absorbed "bridge"
          && hides T.Co_no_pm "bridge" && hides T.Co_no_pm "cap"
          && greys T.Co_gated_local "realize_sys" && hides T.Co_local "bridge"
          && List.for_all bands ~f:(fun b ->
                 T.has_band b.T.cb_kind
                 && List.for_all b.T.cb_hidden ~f:(List.mem T.band_nodes ~equal:String.equal))
        in
        Option.is_some hand && reproduces && facts)
  }

(* What each choice draws is data ([Canary_overview_join]) that the
   page's script only looks up, so the data is held: the concrete chains
   are §3.4's rows, each its own worlds; a mechanism depends on the
   package manager that ships its language's bindings; every chain is
   picked out by the four choices it lights; and the page opens drawn in
   the default choice. *)
let chain_choices_test : Canary_project_test.pure_test =
  { name = "overview.chain_choices_draw_one_chain";
    holds = "The chain §1 draws is chosen from its parts: two package managers, a mechanism and a cooperation.";
    check =
      (fun () ->
        let module T = Canary_topology in
        let module J = Canary_overview_join in
        let projects = Canary_registry.all_specs in
        let j = J.of_projects projects in
        let node_ids = List.map T.nodes ~f:(fun n -> n.T.nd_id) in
        let rows =
          List.concat_map projects ~f:(fun ((name, pr) as p) ->
              let an = Canary_pipeline.analysed_of pr in
              List.map (T.topologies_of_worlds p) ~f:(fun ((t : T.t), (i : T.instance)) ->
                  ( name,
                    Canary_lang.string_of_lang i.T.in_lang,
                    Canary_mechanism.string_of_mechanism
                      (Canary_project_analysis.mechanism_for an i.T.in_lang),
                    T.string_of_supplier t.T.tp_lang,
                    T.string_of_supplier t.T.tp_sys,
                    T.character t )))
          |> List.dedup_and_sort ~compare:Poly.compare
        in
        let ids = List.map j.J.jn_cases ~f:(fun c -> c.J.cs_id) in
        let cases_are_rows =
          List.equal Poly.equal rows (List.map j.J.jn_cases ~f:J.sort_key)
          && List.length (List.dedup_and_sort ~compare:String.compare ids) = List.length ids
          && List.for_all ids ~f:(String.for_all ~f:(fun ch ->
                 Char.is_alphanum ch || Char.equal ch '-' || Char.equal ch '_'))
        in
        let own (c : J.case) (i : T.band_instance) =
          String.equal i.T.bi_project c.J.cs_project
          && Poly.equal i.T.bi_lang c.J.cs_lang
          && Poly.equal i.T.bi_topology.T.tp_lang c.J.cs_topology.T.tp_lang
          && Poly.equal i.T.bi_topology.T.tp_sys c.J.cs_topology.T.tp_sys
        in
        (* each chain is its own worlds: pass 2's mechanism, its topology's
           cooperation, the band over those worlds, and its project's
           declared names on template nodes *)
        let cases_are_their_worlds =
          List.for_all j.J.jn_cases ~f:(fun c ->
              let mine = List.filter j.J.jn_instances ~f:(own c) in
              let k = T.coop_of c.J.cs_topology in
              (not (List.is_empty mine))
              && List.for_all mine ~f:(fun i ->
                     Poly.equal i.T.bi_mechanism c.J.cs_mechanism
                     && Poly.equal (T.coop_of i.T.bi_topology) k)
              && Poly.equal (Some c.J.cs_band) (T.band_over mine k)
              && List.for_all c.J.cs_names ~f:(fun (n, l) ->
                     List.mem node_ids n ~equal:String.equal && not (String.is_empty l)))
        in
        let sys_pm = Canary_store.system_pm_of_platform (Canary_store.platform ()) in
        let sys = Canary_store.string_of_pm sys_pm in
        let case id = List.find j.J.jn_cases ~f:(fun c -> String.equal c.J.cs_id id) in
        (* zarith's fetched chain names conf-gmp and lights the platform's
           system PM and opam; its built chain names no bridge *)
        let names_ok =
          match (case ("zarith-ocaml-opam-" ^ sys), case ("zarith-ocaml-built-" ^ sys)) with
          | Some fetched, Some built ->
              Poly.equal
                (List.Assoc.find fetched.J.cs_names "bridge" ~equal:String.equal)
                (Some "conf-gmp")
              && List.Assoc.mem fetched.J.cs_names "pkg_sys" ~equal:String.equal
              && Poly.equal (J.case_pms fetched) (Some sys_pm, Some Canary_store.Opam)
              && not (List.Assoc.mem built.J.cs_names "bridge" ~equal:String.equal)
          | _ -> false
        in
        let deps m = J.dependent_pms j.J.jn_cases m in
        let depends_ok =
          List.for_all Canary_mechanism.[ Cstubs; Dynlink ] ~f:(fun m ->
              Poly.equal (deps m) [ Canary_store.Opam ])
          && List.for_all Canary_mechanism.[ Cext; Ctypes; Cffi ] ~f:(fun m ->
                 Poly.equal (deps m) [ Canary_store.Pip ])
        in
        let band_at key = List.Assoc.find j.J.jn_bands key ~equal:String.equal in
        let hides key n =
          Option.exists (band_at key) ~f:(fun b -> List.mem b.T.cb_hidden n ~equal:String.equal)
        in
        (* narrowing by package manager is real: absorbed over pip has no
           binding source while absorbed over every world does, a choice no
           chain has is no band at all, and each kind's all-worlds band is
           the cooperation bar's *)
        let narrows =
          hides "absorbed|*|pip" "src_lang"
          && Option.is_some (band_at "absorbed|*|*")
          && (not (hides "absorbed|*|*" "src_lang"))
          && Option.is_none (band_at ("unified|" ^ sys ^ "|*"))
          && List.for_all (T.coop_bands projects) ~f:(fun b ->
                 Poly.equal (band_at (J.band_key b.T.cb_kind None None)) (Some b))
          && Poly.equal (List.map j.J.jn_kinds ~f:(fun b -> b.T.cb_kind))
               (List.map (T.coop_bands projects) ~f:(fun b -> b.T.cb_kind))
        in
        let runs_ok =
          List.for_all j.J.jn_cases ~f:(fun c ->
              let native, lang = J.case_pms c in
              let k = T.coop_of c.J.cs_topology in
              List.for_all [ None; native ] ~f:(fun n ->
                  List.for_all [ None; lang ] ~f:(fun l ->
                      match
                        List.Assoc.find j.J.jn_runs (J.runs_key c.J.cs_mechanism k n l)
                          ~equal:String.equal
                      with
                      | Some ids -> List.mem ids c.J.cs_id ~equal:String.equal
                      | None -> false)))
        in
        let page = Canary_overview_page.render projects ~overview:"" ~generated_at:"test" in
        let between a b =
          match String.substr_index page ~pattern:a with
          | None -> ""
          | Some i -> (
              let rest = String.drop_prefix page i in
              match String.substr_index rest ~pattern:b with
              | None -> ""
              | Some k -> String.prefix rest k)
        in
        let panel = between {|<div class="join" id="join">|} {|<p id="edet"|} in
        let has s = String.is_substring panel ~substring:s in
        let count s = List.length (String.substr_index_all panel ~may_overlap:false ~pattern:s) in
        let data =
          let tag = {|<script type="application/json" id="joindata">|} in
          match String.substr_index panel ~pattern:tag with
          | None -> None
          | Some i -> (
              let rest = String.drop_prefix panel (i + String.length tag) in
              match String.substr_index rest ~pattern:"</script>" with
              | None -> None
              | Some k -> (
                  try Some (Yojson.Basic.from_string (String.prefix rest k)) with _ -> None))
        in
        let button g v = has (Printf.sprintf {|data-g="%s" data-v="%s"|} g v) in
        let gone0, _ = J.default_drawing j in
        let page_ok =
          (not (String.is_empty panel))
          && count {|class="diagram"|} = 1
          && count {|class="ncase|} = List.length T.nodes
          && List.for_all (J.pms J.Native) ~f:(fun p -> button "ps" (Canary_store.string_of_pm p))
          && List.for_all (J.pms J.Language) ~f:(fun p -> button "pl" (Canary_store.string_of_pm p))
          && List.for_all Canary_mechanism.mechanism_catalogue ~f:(fun i ->
                 button "m" (Canary_mechanism.string_of_mechanism i.Canary_mechanism.mi_mechanism))
          && List.for_all T.coop_catalogue ~f:(fun i ->
                 Bool.equal
                   (button "k" (T.code_of_coop i.T.co_kind))
                   (List.exists j.J.jn_kinds ~f:(fun b -> Poly.equal b.T.cb_kind i.T.co_kind)))
          && List.for_all ids ~f:(button "c")
          && (not (button "k" "undeclared"))
          && Poly.equal data (Some (J.json j))
          && (not (List.is_empty gone0))
          && List.for_all gone0 ~f:(fun id ->
                 has (Printf.sprintf {|gone" data-node="%s"|} id)
                 || has (Printf.sprintf {|gone" data-edge="%s"|} id))
          && List.for_all ids ~f:(fun id ->
                 String.is_substring page ~substring:(Printf.sprintf {|href="#chain=%s"|} id))
        in
        (* the mechanisms grouped by language, the two OCaml ones together;
           each cooperation labelled with its package managers; the
           concrete row named "package in canary"; and the package nodes
           each other button is about *)
        let in_order g =
          let tag = Printf.sprintf {|data-g="%s" data-v="|} g in
          List.map (String.substr_index_all panel ~may_overlap:false ~pattern:tag) ~f:(fun i ->
              let rest = String.drop_prefix panel (i + String.length tag) in
              String.prefix rest (Option.value (String.index rest '"') ~default:0))
        in
        let lang_of m =
          List.find_map Canary_mechanism.mechanism_catalogue ~f:(fun i ->
              if String.equal (Canary_mechanism.string_of_mechanism i.Canary_mechanism.mi_mechanism) m
              then Some i.Canary_mechanism.mi_lang
              else None)
        in
        let rec contiguous seen = function
          | a :: (b :: _ as rest) ->
              if Poly.equal a b then contiguous seen rest
              else (not (List.mem seen b ~equal:Poly.equal)) && contiguous (a :: seen) rest
          | _ -> true
        in
        let grouped =
          let ms = in_order "m" in
          contiguous [] (List.map ms ~f:lang_of)
          && (match ms with "cstubs" :: "dynlink" :: _ -> true | _ -> false)
        in
        let labelled =
          List.for_all j.J.jn_kinds ~f:(fun b ->
              let info = T.info_of_coop b.T.cb_kind in
              has
                (Printf.sprintf {|>%s <span class="bl">%s</span></button>|}
                   (Canary_overview_assets.esc info.T.co_label)
                   (Canary_overview_assets.esc (J.pm_label j b.T.cb_kind))))
          && String.equal (J.pm_label j T.Co_conf) ("opam ↔ " ^ sys)
          && String.equal (J.pm_label j T.Co_local) "no PM"
          && has {|>package in canary<|}
        in
        let rel key = List.Assoc.find (J.related j) key ~equal:String.equal in
        let related_ok =
          Poly.equal (rel ("ps|" ^ sys)) (Some [ "pkg_sys" ])
          && Poly.equal (rel "pl|opam") (Some [ "pkg_lang"; "bridge" ])
          && Poly.equal (rel "pl|pip") (Some [ "pkg_lang" ])
          && Poly.equal (rel "k|conf") (Some [ "pkg_sys"; "bridge"; "pkg_lang" ])
          && List.for_all (J.related j) ~f:(fun (_, ns) ->
                 List.for_all ns ~f:(List.mem J.package_nodes ~equal:String.equal))
          (* every button but a package's has an entry *)
          && List.for_all [ "ps"; "pl"; "m"; "k" ] ~f:(fun g ->
                 List.for_all (in_order g) ~f:(fun v -> Option.is_some (rel (g ^ "|" ^ v))))
        in
        (* one diagram, carrying every component's box with a button of
           its own to show it, with no separate recorded-run or cases
           section, and each hand-drawn case's prose in §1 with its
           cooperation *)
        let count pattern = List.length (String.substr_index_all page ~may_overlap:false ~pattern) in
        let boxes = Canary_overview_diagram.containers in
        let merged =
          count {|class="diagram"|} = 1
          && count {|<polygon class="cbox"|} = List.length boxes
          && count {|<rect class="ctab"|} = List.length boxes
          && count {|<button data-box="|} = List.length boxes
          && List.for_all boxes ~f:(fun (c, _) ->
                 let key = Canary_overview_diagram.box_key c in
                 count (Printf.sprintf {|<g class="cbx" data-c="%s">|} key) = 2
                 && has (Printf.sprintf {|<button data-box="%s"|} key))
          && (not (String.is_substring page ~substring:{|id="recwrap"|}))
          && (not (String.is_substring page ~substring:{|id="cases"|}))
          && List.for_all Canary_overview_cases.hand_cases ~f:(fun (c : Canary_overview_cases.case) ->
                 has (Canary_overview_assets.esc c.Canary_overview_cases.ca_title))
        in
        (* the package layer's two in-between nodes say the package
           managers' terms: the capability file a manager ships (§3.1's
           column) and the kinds of bridge a cooperation's chains join
           through (§3.3's); every bridge's term is one its manager
           defines *)
        let bridges_of key = List.Assoc.find j.J.jn_bridges key ~equal:String.equal in
        let terms_ok =
          Poly.equal (bridges_of "conf|*|*") (Some [ "conf-* package" ])
          && Poly.equal (bridges_of "unified|*|*") (Some [ "depext field" ])
          && List.for_all j.J.jn_instances ~f:(fun i ->
                 List.for_all (T.bridges_of_join i.T.bi_topology.T.tp_join) ~f:(fun g ->
                     let b = g.T.gb_bridge in
                     List.mem
                       (List.map (Canary_bridge.kinds_defined (Canary_bridge.pm_of b)) ~f:fst)
                       (Canary_bridge.kind_term b) ~equal:String.equal))
          && Poly.equal (Canary_pm_solo.capability_of sys_pm) (Some ".pc file")
          && List.for_all [ "<b>.pc file</b>"; "<b>conf-* package</b>"; "<b>depext field</b>" ]
               ~f:(fun s -> String.is_substring page ~substring:s)
        in
        (* every package in canary carries a cooperation, derived from
           declarations alone (its world's two placements and its binding
           package's declared gate), so this holds on a checkout that has
           never run: every package's kind has a cooperation button *)
        let every_package_cooperates =
          List.for_all j.J.jn_cases ~f:(fun c ->
              let k = T.coop_of c.J.cs_topology in
              T.has_band k
              && List.exists j.J.jn_kinds ~f:(fun b -> Poly.equal b.T.cb_kind k)
              && button "k" (T.code_of_coop k))
        in
        (* where a project states its gate twice (zarith: its binding
           declaration and the template's routed gate), the two agree *)
        let gates_agree =
          List.for_all projects ~f:(fun (_, pr) ->
              List.for_all pr.Canary_project_run.pr_pm_gates ~f:(fun (lang, g) ->
                  List.for_all pr.Canary_project_run.pr_binding_decls ~f:(fun d ->
                      (not
                         (Poly.equal
                            (Canary_mechanism.info_of_mechanism d.Canary_binding_decl.mechanism)
                              .Canary_mechanism.mi_lang lang))
                      || Poly.equal d.Canary_binding_decl.pm_gate (Some g))))
        in
        cases_are_rows && cases_are_their_worlds && names_ok && depends_ok && narrows
        && runs_ok && page_ok && grouped && labelled && related_ok && merged && terms_ok
        && every_package_cooperates && gates_agree)
  }

(* The overview stops drawing what a world's chain does not have (its
   mechanism's artifact band joined with its cooperation's package band),
   and a claim sitting only there stops applying. That is decided without
   reading the run, so every recorded view checks it, and no claim a run
   decided is dropped as not applying. *)
let chain_absence_test : Canary_project_test.pure_test =
  { name = "overview.chain_absence_is_never_recorded";
    holds = "What a world's chain lacks is never drawn as recorded.";
    check =
      (fun () ->
        let module M = Canary_matrix in
        let module T = Canary_topology in
        let module R = Canary_overview_runs in
        let m = M.matrix_of Canary_registry.all_projects in
        let views = R.views m in
        let is_node id = List.exists T.nodes ~f:(fun n -> String.equal n.T.nd_id id) in
        let sound (v : R.view) =
          List.for_all v.R.vw_gone ~f:(fun id ->
              if is_node id then
                List.mem v.R.vw_dim id ~equal:String.equal
                && not
                     (List.exists v.R.vw_names ~f:(fun (n, (_, from)) ->
                          String.equal n id && String.equal from "recorded"))
              else
                (match List.Assoc.find v.R.vw_edges id ~equal:String.equal with
                 | Some w -> List.mem [ "absent"; "not_ours"; "claim" ] w ~equal:String.equal
                 | None -> false)
                && (not (List.Assoc.mem v.R.vw_placeholders id ~equal:String.equal))
                && (not (List.Assoc.mem v.R.vw_observed id ~equal:String.equal))
                && not (List.Assoc.mem v.R.vw_badges id ~equal:String.equal))
        in
        (* the claims a run decided, per view, read from the row, before
           the view kept only those that apply *)
        let col_in_lang lang label =
          match
            List.find m.M.typed_columns ~f:(fun c -> String.equal (M.label_of_col c) label)
          with
          | Some c -> R.in_lang lang (M.action_of_col c)
          | None -> false
        in
        let keeps_decided (v : R.view) =
          match
            List.find m.M.rows ~f:(fun (r : M.row) ->
                String.equal r.M.project v.R.vw_project
                && String.equal r.M.scenario v.R.vw_scenario)
          with
          | None -> false
          | Some r ->
              List.for_all r.M.claims ~f:(fun (slug, cols) ->
                  let decided =
                    List.exists cols ~f:(fun (label, o) ->
                        col_in_lang v.R.vw_lang label
                        && match o with Some ("holds" | "violated") -> true | _ -> false)
                  in
                  (not decided) || List.Assoc.mem v.R.vw_claims slug ~equal:String.equal)
        in
        (* the bridge's claims: the gate is checked, the other three are
           candidates *)
        let bridge_candidates =
          [ "declared_gate_matches_package"; "gate_bounds_the_library";
            "depext_names_the_provided_package" ]
        in
        let checked_on (v : R.view) edge claim =
          match List.Assoc.find v.R.vw_edge_claims edge ~equal:String.equal with
          | Some cs ->
              List.exists cs ~f:(fun (c, st) ->
                  String.equal c claim && Poly.equal st T.Checked)
          | None -> false
        in
        let zarith k =
          List.find views ~f:(fun v ->
              String.equal v.R.vw_project "zarith"
              && Option.exists v.R.vw_chain ~f:(fun c -> Poly.equal c.M.ch_coop k))
        in
        (* exercised both ways on zarith: its bridged view keeps the bridge,
           checks the gate on conf_probe and lists the other bridge claims
           as candidates; its artifact-only view has none of them *)
        let exercised =
          match (zarith T.Co_conf, zarith T.Co_artifacts) with
          | Some bridged, Some bare ->
              (not (List.mem bridged.R.vw_gone "bridge" ~equal:String.equal))
              && List.for_all bridge_candidates
                   ~f:(List.mem bridged.R.vw_candidates ~equal:String.equal)
              && checked_on bridged "conf_probe" "gate_admits_the_world"
              && List.mem bare.R.vw_gone "bridge" ~equal:String.equal
              && List.mem bare.R.vw_gone "conf_probe" ~equal:String.equal
              && (not
                    (List.exists bridge_candidates
                       ~f:(List.mem bare.R.vw_candidates ~equal:String.equal)))
              && not (checked_on bare "conf_probe" "gate_admits_the_world")
          | _ -> false
        in
        let page =
          Canary_overview_page.render Canary_registry.all_specs ~overview:"" ~generated_at:"test"
        in
        (* the page hides what a chain lacks by class *)
        let page_ok =
          String.is_substring page ~substring:".join .gone{display:none}"
          && String.is_substring page ~substring:"g.classList.toggle('gone'"
        in
        List.for_all views ~f:sound && List.for_all views ~f:keeps_decided && exercised
        && page_ok
        && List.exists views ~f:(fun v -> not (List.is_empty v.R.vw_gone)))
  }

(* A recorded name cites a file the run wrote, which exists; a declared
   name, a §1 package's names and the generic lines cite code. What is
   not traced yet is listed in doc/canary/design/overview.md §4. *)
let drawn_line_sources_test : Canary_project_test.pure_test =
  { name = "overview.every_drawn_line_has_a_source";
    holds = "Every line §1 writes under a node label carries a source computed with its value, and the page lists the sources under the diagram.";
    check =
      (fun () ->
        let module M = Canary_matrix in
        let module R = Canary_overview_runs in
        let module J = Canary_overview_join in
        let keys l = List.sort (List.map l ~f:fst) ~compare:String.compare in
        let is_kind k (s : R.source) = Poly.equal s.R.src_kind k in
        let view_ok (v : R.view) =
          List.equal String.equal (keys v.R.vw_names) (keys v.R.vw_name_sources)
          && List.equal String.equal (keys v.R.vw_nodes) (keys v.R.vw_place_sources)
          && List.for_all v.R.vw_names ~f:(fun (n, (_, from)) ->
                 match List.Assoc.find v.R.vw_name_sources n ~equal:String.equal with
                 | None -> false
                 | Some s -> (
                     match from with
                     | "recorded" -> is_kind R.Run s && Stdlib.Sys.file_exists s.R.src_what
                     | "declared" -> is_kind R.Code s
                     | _ -> false))
          && List.for_all v.R.vw_place_sources ~f:(fun (_, s) ->
                 (not (is_kind R.Run s)) || Stdlib.Sys.file_exists s.R.src_what)
        in
        Hashtbl.clear M.sys_pkg_versions;
        let views = R.views (M.matrix_of Canary_registry.all_projects) in
        let asked = Hashtbl.keys M.sys_pkg_versions in
        (* the rendering machine answers a sentinel everywhere, and a
           placement is flagged [render] exactly where it shows; the memo
           is cleared after, so no later test sees it *)
        let sentinel = "9.9.9sentinel" in
        List.iter asked ~f:(fun k -> Hashtbl.set M.sys_pkg_versions ~key:k ~data:sentinel);
        let views' = R.views (M.matrix_of Canary_registry.all_projects) in
        Hashtbl.clear M.sys_pkg_versions;
        let flagged_where_it_shows (v : R.view) =
          List.for_all v.R.vw_nodes ~f:(fun (n, text) ->
              match List.Assoc.find v.R.vw_place_sources n ~equal:String.equal with
              | None -> false
              | Some s ->
                  Bool.equal (String.is_substring text ~substring:sentinel) (is_kind R.Render s))
        in
        let rendered =
          List.exists views' ~f:(fun v ->
              List.exists v.R.vw_place_sources ~f:(fun (_, s) -> is_kind R.Render s))
        in
        let j = J.of_projects Canary_registry.all_specs in
        let cases_ok =
          (not (List.is_empty j.J.jn_cases))
          && List.for_all j.J.jn_cases ~f:(fun c ->
                 List.equal String.equal (keys c.J.cs_names) (keys c.J.cs_name_sources)
                 && List.for_all c.J.cs_name_sources ~f:(fun (_, s) -> is_kind R.Code s))
        in
        (* every line a choice or a package writes carries its source,
           computed with it; a recorded world's names carry theirs *)
        let from_code (_, (l : R.line)) = Option.exists l.R.ln_src ~f:(is_kind R.Code) in
        let sources_ok =
          List.for_all (J.choice_keys j) ~f:(fun (_, (k, native, lang)) ->
              List.for_all (J.resolve j ~k ~native ~lang).J.rv_lines ~f:from_code)
          && List.for_all j.J.jn_cases ~f:(fun c -> List.for_all (J.case_lines c) ~f:from_code)
          && List.for_all views ~f:(fun v ->
                 List.for_all (R.view_lines v) ~f:(fun (_, l) -> Option.is_some l.R.ln_src))
        in
        let page =
          Canary_overview_page.render Canary_registry.all_specs ~overview:"" ~generated_at:"test"
        in
        (* the page's script reads each source from the line it shows, and
           finds none by a route of its own *)
        let page_ok =
          List.for_all
            [ {|id="jprov"|}; {|id="jprovbody"|}; {|id="jprovsum"|}; "v.lines"; "n.src";
              "v.place_sources" ]
            ~f:(fun s -> String.is_substring page ~substring:s)
          && List.for_all [ "J.sources"; "names_src"; "name_sources"; "pm_terms" ] ~f:(fun s ->
                 not (String.is_substring page ~substring:s))
        in
        (not (List.is_empty views)) && List.for_all views ~f:view_ok
        && (not (List.is_empty asked)) && rendered
        && List.for_all views' ~f:flagged_where_it_shows
        && cases_ok && sources_ok && page_ok)
  }

(* The page template numbers the sections by hand, so reordering them
   needs this guard. *)
let overview_sections_test : Canary_project_test.pure_test =
  { name = "overview.sections_numbered_in_order";
    holds = "The overview page's sections are numbered in order, from 0.";
    check =
      (fun () ->
        let h =
          Canary_overview_page.render Canary_registry.all_specs ~overview:"" ~generated_at:"test"
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
          && List.equal Int.equal nums (List.init (List.length nums) ~f:Fn.id))
  }

(* The index and the result table's check columns are not held to the
   same cells: a column is the agreement's slot (world-blind), an index
   cell its firing in a world, so [staged_interface_preserved] slots at
   llvm's [install_lib] and fires nowhere, since no llvm world is
   [Installed]. *)
let check_index_language_test : Canary_project_test.pure_test =
  { name = "checks.index_speaks_each_action_language";
    holds = "The checking index asks each action in its own language, and no cell claims an agreement its mechanism cannot carry.";
    check =
      (fun () ->
        (* a root nothing has written to: the index's third column reads
           run logs, and this test is about the first two *)
        let root = "_out/canary/test/no-such-run" in
        let cells_of pr =
          Canary_check_index.of_project ~root pr
          |> List.concat_map ~f:(fun (_, es) -> es)
          |> List.concat_map ~f:(fun (e : Canary_check_index.entry) ->
                 List.map e.Canary_check_index.en_added
                   ~f:(fun (a : Canary_check_index.added) ->
                     (e.Canary_check_index.en_action, a)))
        in
        (* sqlite's Python probe carries [api_names_present], which is
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
        (* no cell claims what its language cannot carry, asked of every
           project since the filter is generic *)
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

(* z3 is where the declaration and the default differ: it declares its
   Python binding as Ctypes, which compiles no stub archive, so
   [required_symbols_exported] is not carried, while Python's default,
   Cext, would carry it. z3 is muted and derives no Python step, so this
   holds the divergence before it fires. *)
let applicability_reads_declaration_test : Canary_project_test.pure_test =
  { name = "checks.applicability_reads_the_declaration";
    holds = "Whether an agreement applies is pass 2's one answer, read from the project's declaration rather than its language's default.";
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
            (* what the language default would say *)
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

(* A chain is a world in one binding language. Over the chain-cell
   fixture, every §2 row of every checked agreement is parsed back and
   held to the views; the witness clause keeps the comparison from passing
   on two empty sides. A cell whose frame the chain lacks is counted in §2
   and hatched in §1.2 (design/overview.md §6.4). *)
let agreement_counts_test : Canary_project_test.pure_test =
  { name = "overview.agreement_counts_are_the_tables";
    holds = "§2 counts what §1.2 shows: its decided and blame columns count §1.2's cells, one per chain.";
    check =
      (fun () ->
        let module M = Canary_matrix in
        let module R = Canary_overview_runs in
        let module F = Record_fixture in
        match chain_cell_fixture () with
        | None -> false
        | Some (pr, m, views) ->
            let overview = Canary_agreement_overview.(render (chains_of m)) in
            (* the text of a cell, its tags dropped *)
            let text s =
              let b = Buffer.create (String.length s) in
              let depth = ref 0 in
              String.iter s ~f:(fun c ->
                  if Char.equal c '<' then Int.incr depth
                  else if Char.equal c '>' then Int.decr depth
                  else if !depth = 0 then Buffer.add_char b c);
              String.split (Buffer.contents b) ~on:' '
              |> List.filter ~f:(fun w -> not (String.is_empty w))
            in
            (* every §2 row of this agreement: its last two cells, decided
               and blame *)
            let rows_of slug =
              let pat = Printf.sprintf "<td>%s</td>" slug in
              let rec go pos acc =
                match String.substr_index overview ~pos ~pattern:pat with
                | None -> List.rev acc
                | Some i -> (
                    match String.substr_index overview ~pos:i ~pattern:"</tr>" with
                    | None -> List.rev acc
                    | Some j ->
                        let cells =
                          String.substr_replace_all (String.sub overview ~pos:i ~len:(j - i))
                            ~pattern:"</td>" ~with_:"\n"
                          |> String.split ~on:'\n'
                          |> List.filter ~f:(fun c -> not (String.is_empty c))
                        in
                        let acc =
                          match List.rev cells with
                          | blame :: decided :: _ -> (text decided, text blame) :: acc
                          | _ -> acc
                        in
                        go j acc)
              in
              go 0 []
            in
            (* "14 ✓ · 8 ✗" → the number before each mark *)
            let before mark ws =
              let rec go = function
                | n :: m :: _ when String.equal m mark ->
                    Option.value (Int.of_string_opt n) ~default:(-1)
                | _ :: rest -> go rest
                | [] -> 0
              in
              go ws
            in
            let shown slug =
              let os =
                List.filter_map views ~f:(fun v ->
                    List.Assoc.find v.R.vw_outcomes slug ~equal:String.equal)
              in
              (List.count os ~f:(String.equal "holds"), List.count os ~f:(String.equal "violated"))
            in
            let decided_agree =
              List.for_all Canary_frames.checked_rows ~f:(fun r ->
                  let slug = r.Canary_agreement.ag_slug in
                  let rows = rows_of slug in
                  (not (List.is_empty rows))
                  && List.for_all rows ~f:(fun (decided, _) ->
                         Poly.equal (before "✓" decided, before "✗" decided) (shown slug)))
            in
            (* "11 evidence · 4 version" → the count per blame word *)
            let pairs ws =
              let rec go acc = function
                | n :: w :: rest when Option.is_some (Int.of_string_opt n) ->
                    go ((w, Int.of_string n) :: acc) rest
                | _ :: rest -> go acc rest
                | [] -> acc
              in
              List.sort (go [] ws) ~compare:Poly.compare
            in
            let blamed slug =
              List.filter_map views ~f:(fun v -> List.Assoc.find v.R.vw_blames slug ~equal:String.equal)
              |> List.sort_and_group ~compare:String.compare
              |> List.map ~f:(fun g -> (List.hd_exn g, List.length g))
              |> List.sort ~compare:Poly.compare
            in
            let blames_agree =
              List.for_all Canary_frames.checked_rows ~f:(fun r ->
                  let slug = r.Canary_agreement.ag_slug in
                  List.for_all (rows_of slug) ~f:(fun (_, blame) ->
                      Poly.equal (pairs blame) (blamed slug)))
            in
            (* the fixture's library verdicts, one per world, where no slot is *)
            let worlds = List.length (Canary_project_run.scenarios_of pr) in
            let witness =
              Poly.equal (shown "declared_symbols_exported") (worlds, 0)
              && Poly.equal (blamed "soname_matches_declaration") [ ("declaration", worlds) ]
              && Poly.equal (blamed "dependencies_provided") [ ("evidence", worlds) ]
            in
            (* the record carries the cells: parsed back, each row's are its own *)
            let exported =
              match Yojson.Basic.from_string (M.json_export m) with
              | exception _ -> false
              | j ->
                  let rows = F.items j "rows" in
                  List.length rows = List.length m.M.rows
                  && List.for_all2_exn rows m.M.rows ~f:(fun jr (r : M.row) ->
                         List.for_all r.M.checks ~f:(fun (lang, cells) ->
                             match
                               Option.bind (F.field jr "checks") ~f:(fun c ->
                                   F.field c (Canary_lang.string_of_lang lang))
                             with
                             | Some (`Assoc kv) ->
                                 List.length kv = List.length cells
                                 && List.for_all cells ~f:(fun (slug, c) ->
                                        match List.Assoc.find kv slug ~equal:String.equal with
                                        | Some jc ->
                                            Poly.equal (F.str jc "outcome") (Some c.M.chk_outcome)
                                            && Poly.equal (F.str jc "blame") c.M.chk_blame
                                        | None -> false)
                             | _ -> false))
            in
            (* and §1.2 shows each cell's blame, glossed from the one list *)
            let tooltip =
              let glossed w =
                Canary_overview_assets.esc
                  (Printf.sprintf "blame: %s (%s)" w
                     (Option.value (List.Assoc.find M.blame_gloss w ~equal:String.equal) ~default:""))
              in
              let shown =
                List.concat_map views ~f:(fun v ->
                    let cells = (R.row_of_view ~machine:"test" v).Canary_overview_results.rw_cells in
                    List.map v.R.vw_blames ~f:(fun (slug, w) ->
                        ( List.filter cells ~f:(fun (k, td) ->
                              String.is_substring k ~substring:("|c|" ^ slug ^ "|")
                              && not (String.is_substring td ~substring:"rt-off")),
                          w )))
              in
              List.exists shown ~f:(fun (cs, _) -> not (List.is_empty cs))
              && List.for_all shown ~f:(fun (cs, w) ->
                     List.for_all cs ~f:(fun (_, td) -> String.is_substring td ~substring:(glossed w)))
            in
            decided_agree && blames_agree && witness && exported && tooltip) }

(* A badge's word is [badge_word] over the checked agreements on its
   edge, each in the word of its chain's cell, [unevaluated] where no run
   decided anything. Held over the chain-cell fixture's views and this
   machine's recorded ones. See design/overview.md §6.4. *)
let badge_words_test : Canary_project_test.pure_test =
  { name = "overview.badges_colour_from_the_cells";
    holds = "§1's badges colour from §1.2's cells, each combining the checked agreements on its edge as its chain's cells show them.";
    check =
      (fun () ->
        let module R = Canary_overview_runs in
        let module T = Canary_topology in
        let from_cells (v : R.view) =
          List.for_all v.R.vw_badges ~f:(fun (e, word) ->
              match List.Assoc.find v.R.vw_edge_claims e ~equal:String.equal with
              | None -> false
              | Some xs ->
                  String.equal word
                    (R.badge_word
                       (List.filter_map xs ~f:(fun (slug, st) ->
                            match st with
                            | T.Checked ->
                                Some
                                  (R.outcome_word
                                     (List.Assoc.find v.R.vw_outcomes slug ~equal:String.equal))
                            | T.Placeholder -> None))))
        in
        (* and a claim with no outcome is listed only where a badge counts
           it: a built world does not stage, so staged_interface_preserved
           is no claim of its run *)
        let unevaluated_only_where_counted (v : R.view) =
          List.for_all v.R.vw_claims ~f:(fun (slug, word) ->
              (not (String.equal word "unevaluated"))
              || List.exists v.R.vw_edge_claims ~f:(fun (_, xs) ->
                     List.exists xs ~f:(fun (s, st) ->
                         String.equal s slug && Poly.equal st T.Checked)))
        in
        match chain_cell_fixture () with
        | None -> false
        | Some (pr, _, views) ->
            let recorded = R.views (Canary_matrix.matrix_of Canary_registry.all_projects) in
            List.for_all (views @ recorded) ~f:(fun v ->
                from_cells v && unevaluated_only_where_counted v)
            && List.length views = List.length (Canary_project_run.scenarios_of pr)
            (* the witness: the fixture's realize_sys badge is partial, from
               declared_symbols_exported holding, soname_matches_declaration
               undeclared and declared_versions_exported unevaluated *)
            && List.for_all views ~f:(fun v ->
                   Poly.equal (List.Assoc.find v.R.vw_badges "realize_sys" ~equal:String.equal)
                     (Some "partial"))) }

(* An installed world inspects two copies of its library, the build
   tree's after build_lib and the staged one at probe_lib_staged; the
   reader takes where the step looked, so the two carry distinct names
   (lib_sys, staged_sys) and neither can stand for the other. Held over a
   fixture tree in sqlite's shape, with no log. See design/overview.md
   §6.4. *)
let staged_copy_test : Canary_project_test.pure_test =
  { name = "overview.staged_copy_is_named";
    holds = "The staged copy of a library is named apart from the build tree's copy.";
    check =
      (fun () ->
        let module M = Canary_matrix in
        let module R = Canary_overview_runs in
        let project = "sqlite" in
        match List.Assoc.find Canary_registry.all_projects project ~equal:String.equal with
        | None -> false
        | Some pr ->
            let root = "_out/canary/test/staged-fixture" in
            let module F = Record_fixture in
            let native soname total =
              Printf.sprintf
                {|{"kind":"native","path":"/x/libsqlite3.so","elf":{"soname":"%s"},"counts":{"total":%d}}|}
                soname total
            in
            let scenario_of a =
              Stdlib.Filename.basename (Canary_project_run.scenario_dir_of ~pr_name:project a)
            in
            let file tag a =
              Printf.sprintf "%s/canary/projects/%s/%s/%s" root project
                (Canary_basic.step_dir_of_tag tag)
                (Canary_basic.filename ~variant_key:(scenario_of a) ~base:"inspect" ~ext:"json")
            in
            let installed =
              List.filter (Canary_project_run.scenarios_of pr) ~f:(fun a ->
                  Poly.equal (R.provision_of_kind a Canary_basic.Lib) (Some Canary_artifact.Installed))
            in
            List.iter installed ~f:(fun a ->
                F.write (file "build_lib" a) (native "libsqlite3.so.build" 9);
                F.write (file "probe_lib_staged" a) (native "libsqlite3.so.staged" 7));
            let views = R.views ~root (M.matrix_of ~root [ (project, pr) ]) in
            let of_installed =
              List.filter views ~f:(fun v ->
                  List.exists installed ~f:(fun a -> String.equal (scenario_of a) v.R.vw_scenario))
            in
            let name (v : R.view) n = List.Assoc.find v.R.vw_names n ~equal:String.equal in
            (not (List.is_empty of_installed))
            && List.for_all of_installed ~f:(fun v ->
                   Poly.equal (name v "staged_sys") (Some ("libsqlite3.so.staged", "recorded"))
                   && Poly.equal
                        (List.Assoc.find v.R.vw_counts "staged_sys" ~equal:String.equal)
                        (Some "7 exports")
                   && Poly.equal (name v "lib_sys") (Some ("libsqlite3.so.build", "recorded")))) }

let tests : Canary_project_test.pure_test list =
  [ topology_joins_test; topology_graph_test; overview_sections_test; every_step_placed_test;
    claim_parts_test; sides_meet_test; sits_by_parts_test; components_contain_test; frames_test; one_reader_test; template_test; results_table_test; agreement_counts_test;
    badge_words_test; staged_copy_test; overview_overlay_test; recorded_names_test;
    overlay_words_test; bridge_record_test; placeholder_badges_test; coverage_tables_test;
    package_band_test; chain_choices_test; chain_absence_test; drawn_line_sources_test;
    badge_counts_test; agreements_sit_test; agreements_by_layer_test; edge_marks_test;
    visual_vocabulary_test; flow_test;
    flow_files_written_test; status_rows_test; exhibits_test; exhibits_export_test;
    choice_resolved_test; result_cells_test;
    every_machine_test; firing_frames_test; outcome_marks_test;
    agreement_laws_test; mechanism_claims_test; check_index_language_test;
    applicability_reads_declaration_test ]
