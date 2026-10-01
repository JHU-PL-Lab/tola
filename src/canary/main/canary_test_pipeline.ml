(** Pins on the pipeline: the passes (analyse, enumerate, select, order,
    realize), the steps they derive, and the action vocabulary. *)

open Base
module B = Canary_basic
module EN = Canary_enumerate

(* The providing arrow is provider → action → artifact, with fetch and
   build the same shape: [Fetched] ⇒ [Fetch kind]; [Built] ⇒ the kind's
   build action; [Vendored] and [Absent] ⇒ none, as no action of the run
   produces them. [provision_of_actions] reads the provision back. *)
let providing_arrow_pin : Canary_project_test.pure_test =
  { name = "arrow.providing_action_total_and_consistent";
    holds = "In the sqlite, z3, llvm and tiny-full tables, each provider's action is the one its provision implies, and an action reads back as its provision.";
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
              (* a Repo provides its axes' provision: the row's first,
                 since the live Repo rows are Fetched-only sources *)
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
                  (* the action reads back as the provision *)
                  && Poly.equal
                       (Canary_enumerate.provision_of_actions [ a ] id)
                       EN.Built
              | Canary_store.Vendored, None -> true
              | Canary_store.Absent, None -> true
              (* no provider yields Installed: projects declare it in
                 the universe (the round-trip below) *)
              | _ -> false))
      (* the Fetched half of the round-trip *)
      && Poly.equal
           (Canary_enumerate.provision_of_actions [ B.Fetch B.Lib ] Canary_artifact.a_lib)
           EN.Fetched
      (* the Installed half: [Install_lib], the staged lib's maker step,
         reads back as Installed *)
      && Poly.equal
           (Canary_enumerate.provision_of_actions
              [ B.Install_lib ] Canary_artifact.a_lib)
           EN.Installed
      (* a provider's derived runtime edge, if any, is Ambient: a
         self-contained package bundles its own lib *)
      && List.for_all tables ~f:(fun (d : Canary_project_spec.artifact_row) ->
             match Canary_project_spec.provider_of_row d with
             | Some p -> (
                 match Canary_store_config.dep_mode_of_provider p with
                 | Some (Canary_store.Ambient _) ->
                     true
                 | None -> true
                 | _ -> false)
             | None -> true)) }

(* A bridge step carries the install's action, depends on that install
   and selects no agreements; its bridge is the one the package gate
   names ([Canary_bridge.of_gate]); zarith's zarith-no-conf world builds
   its binding and has none. The rollout list names the (project, bridge)
   pairs that have a step; extending it is deliberate. *)
let bridge_step_pin : Canary_project_test.pure_test =
  { name = "steps.bridge_step_drives_the_declared_bridge";
    holds = "In every world of every active project, a bridge step drives the bridge its project declares, and exists only where the binding is fetched.";
    check =
      (fun () ->
        let module SM = Canary_step_model in
        let per_world =
          List.concat_map Canary_registry.all_projects ~f:(fun (name, pr) ->
              List.map (Canary_project_run.scenarios_of pr) ~f:(fun a ->
                  ( name,
                    pr,
                    a,
                    Canary_pipeline.steps_of ~warn:false ~root:"_out/canary" pr
                      ~ctx:(Canary_pipeline.ctx_of pr a) a )))
        in
        let found =
          List.concat_map per_world ~f:(fun (name, pr, a, steps) ->
              List.filter_map steps ~f:(fun (s : SM.step) ->
                  Option.map s.SM.bridge ~f:(fun b -> (name, pr, a, steps, s, b))))
        in
        let well_formed =
          List.for_all found ~f:(fun (_, pr, a, steps, (s : SM.step), b) ->
              match s.SM.action with
              | Canary_basic.Fetch (Canary_basic.Binding lang) ->
                  let install = Canary_basic.string_of_action s.SM.action in
                  List.mem s.SM.deps install ~equal:String.equal
                  && List.exists steps ~f:(fun (q : SM.step) ->
                         String.equal q.SM.tag install && Option.is_none q.SM.bridge)
                  && Option.is_none s.SM.agreement_ctx
                  && Option.is_none s.SM.inspects
                  && Poly.equal
                       (Option.bind
                          (Option.join (Canary_topology.gate_of pr lang))
                          ~f:Canary_bridge.of_gate)
                       (Some b)
                  && Poly.equal
                       (Canary_topology.origin_of ~pr ~world:a
                          (Canary_basic.Binding lang)
                       |> Option.map ~f:fst)
                       (Some Canary_store.Fetched)
              | _ -> false)
        in
        let rollout =
          List.map found ~f:(fun (name, _, _, _, _, b) ->
              name ^ " " ^ Canary_bridge.to_string b)
          |> List.dedup_and_sort ~compare:String.compare
        in
        (* and the bypass is real: a world of a bridged project that builds
           its binding has no bridge step *)
        let bypassed =
          List.exists per_world ~f:(fun (name, pr, a, steps) ->
              String.equal name "zarith"
              && Poly.equal
                   (Canary_topology.origin_of ~pr ~world:a
                      (Canary_basic.Binding Canary_lang.OCaml)
                   |> Option.map ~f:fst)
                   (Some Canary_store.Built)
              && List.for_all steps ~f:(fun (s : SM.step) -> Option.is_none s.SM.bridge))
        in
        well_formed && bypassed
        && List.equal String.equal rollout [ "zarith conf-gmp" ])
  }

(* In every world of every active project: each bridge step is tagged
   [bridge_record_tag], the name the bridge family reads the record
   under, and every probe of the language depends on the bridge step, so
   a cold run never reads the last run's record. Some bridge step must
   exist, or the check is vacuous. *)
let gate_after_bridge_pin : Canary_project_test.pure_test =
  { name = "steps.gate_is_read_after_its_bridge_runs";
    holds = "The package gate is read after its bridge runs, at the language's probe, from the record that bridge step writes.";
    check =
      (fun () ->
        let module SM = Canary_step_model in
        let module C = Canary_agreement_common in
        let gate =
          C.method_of
            (Canary_agreement.row_of C.Gate_admits_the_world).Canary_agreement.ag
            "bridge_check_in_this_world"
        in
        let checked = ref 0 in
        let ok =
          List.for_all Canary_registry.all_projects ~f:(fun (_, pr) ->
              List.for_all (Canary_project_run.scenarios_of pr) ~f:(fun a ->
                  let steps =
                    Canary_pipeline.steps_of ~warn:false ~root:"_out/canary" pr
                      ~ctx:(Canary_pipeline.ctx_of pr a) a
                  in
                  List.for_all steps ~f:(fun (b : SM.step) ->
                      match (b.SM.bridge, b.SM.action, gate) with
                      | None, _, _ -> true
                      | Some _, Canary_basic.Fetch (Canary_basic.Binding lang), Some m -> (
                          Int.incr checked;
                          match Canary_mechanism.default_mechanism_of_lang lang with
                          | None -> false
                          | Some mechanism ->
                          let reads =
                            List.concat_map
                              (m.C.m_inputs
                                 { C.ac_mechanism = mechanism; ac_lang = lang;
                                   ac_world = a; ac_declared = None })
                              ~f:C.paths_of_input
                          in
                          let probes =
                            List.filter steps ~f:(fun (s : SM.step) ->
                                Poly.equal s.SM.action (Canary_basic.Probe_binding lang))
                          in
                          String.equal b.SM.tag (C.bridge_record_tag lang)
                          && Poly.equal (m.C.m_firing mechanism lang a)
                               [ Canary_basic.Probe_binding lang ]
                          && List.equal String.equal reads
                               [ b.SM.tag ^ "/" ^ Canary_bridge_driver.record_base ^ ".json" ]
                          && (not (List.is_empty probes))
                          && List.for_all probes ~f:(fun (s : SM.step) ->
                                 List.mem s.SM.deps b.SM.tag ~equal:String.equal))
                      | Some _, _, _ -> false)))
        in
        ok && !checked > 0)
  }

(* Held in every world of every active project. The catalogue is
   [Canary_pm_action.inside_install]; the fetch is never a dummy, which
   installs nothing; a placeholder is named <fetch>_<pm>_<key> and selects
   no agreements; its command writes the marker and says what it stands
   for. Both reasons occur, and zarith's fetched world has the three opam
   pieces and the system package manager's one. *)
let placeholder_steps_pin : Canary_project_test.pure_test =
  { name = "steps.placeholders_stand_for_what_pms_do";
    holds = "Every placeholder step is an entry in its package manager's catalogue of unseen work, and depends only on a real fetch of the same action.";
    check =
      (fun () ->
        let module SM = Canary_step_model in
        let module PA = Canary_pm_action in
        let worlds =
          List.concat_map Canary_registry.all_projects ~f:(fun (name, pr) ->
              List.map (Canary_project_run.scenarios_of pr) ~f:(fun a ->
                  ( name,
                    Canary_pipeline.steps_of ~warn:false ~root:"_out/canary" pr
                      ~ctx:(Canary_pipeline.ctx_of pr a) a )))
        in
        let well_formed =
          List.for_all worlds ~f:(fun (_, steps) ->
              List.for_all steps ~f:(fun (s : SM.step) ->
                  match s.SM.placeholder with
                  | None -> true
                  | Some ph -> (
                      match (s.SM.action, s.SM.deps) with
                      | (Canary_basic.Fetch k as act), [ fetch ] ->
                          let of_binding =
                            match k with Canary_basic.Binding _ -> true | _ -> false
                          in
                          List.mem
                            (PA.inside_install ph.PA.ph_pm ~of_binding)
                            ph ~equal:Poly.equal
                          && String.equal s.SM.tag
                               (String.concat ~sep:"_"
                                  [ fetch; Canary_store.string_of_pm ph.PA.ph_pm;
                                    ph.PA.ph_key ])
                          && List.exists steps ~f:(fun (q : SM.step) ->
                                 String.equal q.SM.tag fetch
                                 && Poly.equal q.SM.action act
                                 && Option.is_none q.SM.dummy
                                 && Option.is_none q.SM.placeholder)
                          && Option.is_none s.SM.agreement_ctx
                          && Option.is_none s.SM.inspects
                          && Option.is_none s.SM.bridge
                      | _ -> false)))
        in
        let all = List.concat_map worlds ~f:snd in
        let phs = List.filter_map all ~f:(fun (s : SM.step) -> s.SM.placeholder) in
        let both_reasons =
          List.exists phs ~f:(fun p ->
              match p.PA.ph_unseen with PA.Not_yet _ -> true | _ -> false)
          && List.exists phs ~f:(fun p ->
                 match p.PA.ph_unseen with PA.Out_of_reach _ -> true | _ -> false)
        in
        let no_placeholder_beside_a_dummy =
          List.for_all worlds ~f:(fun (_, steps) ->
              List.for_all steps ~f:(fun (d : SM.step) ->
                  Option.is_none d.SM.dummy
                  || not
                       (List.exists steps ~f:(fun (s : SM.step) ->
                            Option.is_some s.SM.placeholder
                            && List.mem s.SM.deps d.SM.tag ~equal:String.equal))))
          (* and some world has a dummy, or this is vacuous *)
          && List.exists all ~f:(fun (s : SM.step) -> Option.is_some s.SM.dummy)
        in
        let sys = Canary_store.string_of_pm (Canary_store.detect_pm ()) in
        let zarith_fetched =
          List.exists worlds ~f:(fun (name, steps) ->
              String.equal name "zarith"
              && List.for_all
                   [ "fetch_binding_ocaml_opam_plan"; "fetch_binding_ocaml_opam_solver";
                     "fetch_binding_ocaml_opam_build"; "fetch_lib_" ^ sys ^ "_policy" ]
                   ~f:(fun t ->
                     List.exists steps ~f:(fun (s : SM.step) -> String.equal s.SM.tag t)))
        in
        let command_ok =
          match
            List.find all ~f:(fun (s : SM.step) -> Option.is_some s.SM.placeholder)
          with
          | None -> false
          | Some s ->
              let out = "_out/canary/test/placeholder-fixture" in
              ignore (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" out) : int);
              let sh = s.SM.cmd ~output_dir:out ~variant_key:"" in
              Stdlib.Sys.command (sh ^ " >/dev/null 2>&1") = 0
              && Stdlib.Sys.file_exists (out ^ "/placeholder.ok")
              && String.is_substring sh
                   ~substring:
                     (PA.string_of_unseen
                        (Option.value_exn s.SM.placeholder).PA.ph_unseen
                     |> String.split ~on:'\''
                     |> List.hd_exn)
        in
        well_formed && both_reasons && no_placeholder_beside_a_dummy && zarith_fetched
        && command_ok)
  }

(* [action_of_string] looks the name up in [all_actions]; a binding
   source's fetch reads, and an unknown name does not. *)
let action_names_pin : Canary_project_test.pure_test =
  { name = "basic.action_names_read_back";
    holds = "Every action's name reads back as that action, no two actions share a name, and an unknown name reads as no action.";
    check =
      (fun () ->
        let module B = Canary_basic in
        let names = List.map B.all_actions ~f:B.string_of_action in
        List.for_all B.all_actions ~f:(fun a ->
            Option.equal Poly.equal (B.action_of_string (B.string_of_action a)) (Some a))
        && List.length (List.dedup_and_sort names ~compare:String.compare) = List.length names
        && Option.equal Poly.equal
             (B.action_of_string "fetch_binding_source_ocaml")
             (Some (B.Fetch (B.Binding_source Canary_lang.OCaml)))
        && Option.is_none (B.action_of_string "fetch_binding_ocaml_extra"))
  }

(* A log line and a matrix column name the language, not the mechanism,
   so two mechanisms for one language make their outcomes ambiguous
   ([an_mechanisms] keeps the first). tiny-full declares Cext and Ctypes
   for Python on purpose and is the named exception; adding a project to
   the list needs a reason. *)
let mechanism_collision_known : string list = [ "tiny-full" ]
let one_mechanism_per_language_pin : Canary_project_test.pure_test =
  { name = "analysis.one_mechanism_per_language";
    holds = "Every active project except tiny-full declares at most one binding mechanism per language.";
    check =
      (fun () ->
        let bad =
          List.concat_map Canary_registry.all_projects ~f:(fun (name, pr) ->
              (* the language comes off the mechanism's catalogue entry,
                 as in [an_mechanisms] *)
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

(* Full adds no policy override, and Thin is the Subset [Stable] version
   level. Shadowing is unconditional, so the ladder only subsets
   versions. *)
let shadow_policy_ladder_pin : Canary_project_test.pure_test =
  { name = "shadow.policy_ladder";
    holds = "The full run policy is the enumeration's default, the thin one keeps only stable versions, and narrowing refs leaves every other axis full.";
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
        Option.is_none (ep Canary_project_run.Full)
        && (match ep Canary_project_run.Thin with
            | None -> false
            | Some (p : unit EN.policy) ->
                Poly.equal p.EN.config.EN.version
                  (EN.Subset [ Canary_basic.Stable ]))
        (* a refs-narrowed Full is still full in every other axis *)
        && full_like
             (Canary_project_run.enumeration_policy_of
                { Canary_project_run.platform = Canary_store.platform ();
                  policy = Canary_project_run.Full;
                  refs = EN.Refs [ "latest" ] })) }

(* A [Native_lib_probe] writes its inspection inside the probe command and
   declares it in [template_summaries]; an explicit [inspect] for the same
   action would be a second step writing the same file, so the step
   builder drops it with a message. The template wins because its answer
   is derived from the world. The same spec with and without the
   declaration differs by that one step. *)
let inspect_clash_pin : Canary_project_test.pure_test =
  { name = "steps.template_summary_beats_override";
    holds = "When a probe template declares its own summary, the step builder drops the explicit inspect step for that action and nothing else.";
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
        (* without the declaration the override is attached: a probe
           that writes no summary still needs one *)
        let loose = steps_of base in
        let attached =
          List.exists loose ~f:(fun t -> String.is_substring t ~substring:"inspect")
        in
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

(* A dep whose step is not in the list is held only to a non-empty
   directory. [dep_dirs] is the precondition as data
   (doc/canary/design/action_model.md §§4-5). It witnesses the rebind in
   [derive_steps] only where some step depends on a step with an
   [output_tag], whose [output_dir] differs from its tag's directory. *)
let dep_dirs_pin : Canary_project_test.pure_test =
  { name = "steps.dep_dirs_correspond_to_deps";
    holds = "A step has one non-empty directory per dependency, in order, each the output directory of that dependency's step.";
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
        (* some step must have a dep, or the check below is vacuous *)
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

(* The action × declaration join is [an_touches]: (a) it is total, so a
   declared kind the catalogue does not know fails here; (b) a probe is
   never where an artifact's evidence is first recorded ([produced_at] is
   empty for every [Probe_*]); (c) a lib's producers are build_lib,
   fetch_lib or install_lib, by the world's provision. *)
let touches_join_pin : Canary_project_test.pure_test =
  { name = "analysis.touches_joins_actions_to_declarations";
    holds = "For every catalogued project, every declared artifact is touched by some action, no probe produces anything, and a lib has more than one producer.";
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
            (* (c), asked of the project's lib *)
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

(* [worktree_ensure_cmd] runs the remote half (clone, fetch) inside the
   guard stamped with [$CANARY_RUN_ID] and writes the world's marker
   outside it. A shape check, not a timing one: move either across the
   guard and a world re-fetches or never records its own evidence. *)
let source_refresh_scope_pin : Canary_project_test.pure_test =
  { name = "source.refresh_is_run_scoped";
    holds = "A shared source checkout's refresh sits inside a guard stamped with the run id, and each world writes its marker after that guard.";
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
            (* the clone sits inside the run-stamped guard *)
            run_id < clone
            (* the marker is written after it, by every world *)
            && clone < marker
            && String.is_substring cmd ~substring:"if [ ! -e \"$SENTINEL\" ]"
        | _ -> false) }

(* See doc/canary/design/enumeration/stage6_realize_steps.md §3b.
   [drop_unread_fetches] keeps a fetch when some step in the world
   consumes what it produces, by the typed catalogue
   ([consumes_of_action]), not by [step.deps]. Checked as a pair, since
   pruning everything passes cairo and pruning nothing passes sqlite. *)
let demand_prune_pin : Canary_project_test.pure_test =
  { name = "derive.steps_are_demanded";
    holds = "A world realizes only the fetches its steps consume, so cairo's all-fetched world fetches no source while sqlite's built worlds do.";
    check =
      (fun () ->
        let tags_of pr a =
          let ctx = Canary_pipeline.ctx_of pr a in
          List.map
            (Canary_pipeline.steps_of ~root:"_out/canary" pr ~ctx a)
            ~f:(fun s -> s.Canary_step_model.tag)
        in
        let has ts t = List.mem ts t ~equal:String.equal in
        (* cairo's all-Fetched world reads no source: no fetch_source,
           and its checks survive *)
        let cairo_ok =
          match Canary_pipeline.ordered Canary_project_cairo.cairo_run with
          | [] -> false
          | a :: _ ->
              let ts = tags_of Canary_project_cairo.cairo_run a in
              (not (has ts "fetch_source"))
              && has ts "probe_lib"
              && has ts "probe_binding_ocaml"
              (* a probe's inspection is kept, though nothing depends
                 on it *)
              && has ts "probe_lib_inspect"
        (* sqlite's Built worlds keep fetch_source: build_lib depends
           on it *)
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

(* For every world of every catalogued project, [ctx_of] takes its
   workspace from [scenario_dir_of] and its project name as
   <project>/<basename>. Both strings reach output paths and env vars, so
   drift would relocate a scenario and orphan its cache markers. *)
let pipeline_ctx_pin : Canary_project_test.pure_test =
  { name = "pipeline.scenario_names_are_born_safe";
    holds = "Every world's scenario name needs no escaping in a path or a colon-separated variable, and its run context uses that name unchanged.";
    check =
      (fun () ->
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

(* Selection is a post-filter: the restriction before the product is
   [run_config]'s [resolve_versions], the filter after it [select]. One
   of the constraints after the product, [shadow_filter], is
   cross-assignment, so this is checked, not assumed. Thin differs from
   full only in the version level, so it pins the whole equivalence.
   Muted projects are included. *)
let select_post_filter_pin : Canary_project_test.pure_test =
  { name = "select.thin_post_filter_equals_universe_restriction";
    holds = "For every catalogued project, restricting versions before the product gives the same thin worlds as selecting from the product after it.";
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

(* Held for every catalogued project, so the encoder cannot drift from
   the pass. Realize is left out: encoding it applies [pr_runner_spec],
   which is not pure. *)
let json_per_pass_pin : Canary_project_test.pure_test =
  { name = "emit.each_pass_encodes_independently";
    holds = "The declare, enumerate and order encodings name their pass and project, and the enumerate one lists exactly the worlds the pass computed.";
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

(* [enumerate_product] is product then filter, mutation-aware;
   [enumerate_follows_tree] a root/child walk over [ax_follows],
   positive-only. They are compared on canonical assignment keys. It is
   the evidence for deleting one of them, and keeps them from drifting
   apart until then. *)
let two_constructions_agree_pin : Canary_project_test.pure_test =
  { name = "enumerate.two_constructions_agree";
    holds = "The two enumerations, product then filter and a walk of the follows tree, compute the same worlds for every catalogued project.";
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

(* Select under the full policy returns enumerate's worlds unchanged. A
   default that narrowed would shrink every run while every count still
   matched. *)
let select_default_is_identity_pin : Canary_project_test.pure_test =
  { name = "select.full_policy_selects_everything";
    holds = "For every catalogued project, the default run selects every world the enumeration produces.";
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

let select_subset_pin : Canary_project_test.pure_test =
  { name = "select.is_a_subset_of_stage2";
    holds = "For every catalogued project, the thin selection is a subset of the enumerated worlds, so selection only removes.";
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

(* Declare, select and order are total, muted projects included. A
   silent drop in [project_spec_of_rows] would shrink every later
   pass. *)
let pipeline_total_pin : Canary_project_test.pure_test =
  { name = "pipeline.stages_total_over_catalogue";
    holds = "For every catalogued project, the spec has one entry per declared row, the default run has a world, and ordering keeps every world.";
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

(* See doc/canary/design/enumeration/stage5_order_worlds.md §3. An opam
   switch holds one version of a package, so a pinned placement locks
   that store's state. Ordering is a sort: none added, dropped or
   duplicated. *)
let run_order_groups_state_pin : Canary_project_test.pure_test =
  { name = "run_order.groups_by_store_state";
    holds = "For every catalogued project, run order keeps the same scenarios and gives each store state one contiguous run.";
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
        (* every catalogued project, muted ones included: the ordering is
           a property of the enumeration, not of the run set *)
        let projects = List.map Canary_registry.all_specs ~f:snd in
        (* some project must have pinned state, or every check above is
           vacuous *)
        let any_pinned =
          List.exists projects ~f:(fun pr ->
              List.exists (Canary_project_run.scenarios_of pr) ~f:(fun a ->
                  not (List.is_empty (Canary_project_run.store_state_key pr a))))
        in
        any_pinned
        && List.for_all projects ~f:same_set
        && List.for_all projects ~f:grouped_ok) }

(* The vocabulary is [Canary_world]. A pre-command guard names `exit 1`,
   and a post-hoc claim is grepped from the log rather than appended
   after the command's own exit. *)
let world_assertion_vocabulary_pin : Canary_project_test.pure_test =
  { name = "world.one_vocabulary";
    holds = "Every world assertion renders one shell wherever it is declared, can abort before the command or grep the log after it, and carries a reason.";
    check =
      (fun () ->
        let module W = Canary_world in
        (* an opam pin claim renders one shell shape, whatever the
           package *)
        let pin_shell pkg =
          W.pre_shell [ W.Opam_pin { pkg; version = "1.2.3" } ]
        in
        let same_shape =
          List.for_all [ "ssl"; "z3"; "llvm" ] ~f:(fun pkg ->
              let a = pin_shell pkg in
              String.is_substring a ~substring:"opam list"
              && String.is_substring a ~substring:"WORLD MISMATCH"
              (* a guard must be able to abort *)
              && String.is_substring a ~substring:"exit 1"
              && String.is_substring a ~substring:pkg
              && String.is_substring a ~substring:"1.2.3")
        in
        (* the step builder's entry point renders the same shell *)
        let builder_agrees =
          String.equal
            (Canary_step_builder.opam_world_check ~pkg:"ssl" ~pin:"0.6.0")
            (W.pre_shell [ W.Opam_pin { pkg = "ssl"; version = "0.6.0" } ])
        in
        (* an opam pin is checked before the command and a log claim
           after it; neither is dropped *)
        let ws =
          [ W.Opam_pin { pkg = "zstd"; version = "0.4" };
            W.Log_names { text = "zstd version: 1.5.7"; why = "witness" } ]
        in
        let split_ok =
          Poly.equal (List.map ws ~f:W.is_pre) [ true; false ]
          && List.length (W.log_substrings ws) = 1
          && String.is_substring (W.pre_shell ws) ~substring:"zstd"
          (* and neither leaks into the other's check *)
          && (not
                (String.is_substring (W.pre_shell ws)
                   ~substring:"zstd version: 1.5.7"))
          && List.for_all (W.log_substrings ws) ~f:(fun s ->
                 not (String.is_substring s ~substring:"opam list"))
        in
        (* the command runs in a subshell, so its `exit $RC` cannot skip
           the grep *)
        let post_ok =
          let cmd =
            Canary_step_builder.with_world_asserts
              ~asserts:[ W.Log_names { text = "MARK"; why = "w" } ]
              ~output_dir:"/tmp/o" ~variant_key:"k" "echo hi; exit $RC"
          in
          String.is_substring cmd ~substring:"( echo hi; exit $RC )"
          && String.is_substring cmd ~substring:"&& grep -qF \"MARK\""
        in
        (* every assertion carries a reason for its failure message *)
        let reasons_ok =
          List.length (W.reasons ws) = 2
          && List.for_all (W.reasons ws) ~f:(fun (_, why) ->
                 not (String.is_empty why))
        in
        same_shape && builder_agrees && split_ok && post_ok && reasons_ok) }

(* For each listed opam-binding project with a prebuilt: (1) a Vendored
   world's OCaml probe carries the prebuilt's libdir; (2) no other
   world's does, so the pair is two worlds; (3) with [probe_names_lib],
   the Vendored probe also greps for that libdir, since pointing the
   loader is not checking that it obeyed. *)
let vendored_world_probe_pin : Canary_project_test.pure_test =
  { name = "vendored.probe_names_the_world";
    holds = "In each listed opam-binding project with a prebuilt, only the vendored world's OCaml probe names the prebuilt's library directory.";
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
                          (* (1) the libdir, and (3) the grep *)
                          String.is_substring cmd ~substring:libdir
                          && ((not d.Canary_opam_binding.probe_names_lib)
                             || String.is_substring cmd ~substring:"grep -qF")
                      | _ ->
                          (* (2) the other worlds must not carry it *)
                          not (String.is_substring cmd ~substring:libdir)))
        in
        (* the Vendored worlds must exist, or every check above is
           vacuous *)
        ok && !checked >= 4) }

let tests : Canary_project_test.pure_test list =
  [ providing_arrow_pin; shadow_policy_ladder_pin; vendored_world_probe_pin;
    world_assertion_vocabulary_pin; pipeline_ctx_pin; pipeline_total_pin;
    select_post_filter_pin; select_subset_pin; select_default_is_identity_pin;
    two_constructions_agree_pin; json_per_pass_pin; run_order_groups_state_pin;
    one_mechanism_per_language_pin; bridge_step_pin; gate_after_bridge_pin;
    placeholder_steps_pin; action_names_pin; touches_join_pin; inspect_clash_pin;
    dep_dirs_pin; demand_prune_pin; source_refresh_scope_pin ]
