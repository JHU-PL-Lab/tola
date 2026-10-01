(** Pins on the pipeline: the passes (analyse, enumerate, select, order,
    realize), the steps they derive, and the action vocabulary. *)

open Base
module B = Canary_basic
module EN = Canary_enumerate

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

(* A BRIDGE STEP DRIVES THE BRIDGE ITS PROJECT DECLARED (2026-09-23,
   status.md §2.7 E). The step that runs a bridge's check in a world is
   derived, never hand-listed, so this holds the derivation over every
   world of every active project:

   - it carries the INSTALL's action, depends on that install in the same
     world, and selects no agreements (the install's claims are about the
     binding package, not the bridge);
   - the bridge it drives is the one the project's package gate names for
     that language ([Canary_bridge.of_gate]) — not a second statement of
     it;
   - it exists only where the binding is FETCHED: a world that builds its
     binding here does not install through the bridge (zarith's
     zarith-no-conf world bypasses conf-gmp);
   - THE ROLLOUT, as a list: which (project, bridge) pairs have a step
     today. One, by the plan's "one bridge on one project"; generalizing
     changes this list deliberately. *)
let bridge_step_pin : Canary_project_test.pure_test =
  { name = "steps.bridge_step_drives_the_declared_bridge";
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

(* THE GATE IS READ AFTER ITS BRIDGE RUNS (2026-09-27, E2). The agreement
   that reads a bridge record fires at the binding's probe; the record is
   written by the bridge step beside the install. Two things could make
   the reader look at the wrong file, and neither shows in a single run:

   - the TAG: the step builder names the bridge step and the family names
     the record's path — both through [bridge_record_tag] now, and this
     holds them to one answer;
   - the ORDER: a probe that did not wait for the bridge step would read
     the last run's record on a cold run and report it as this one's.

   Over every world of every active project: each bridge step carries the
   tag, the gate fires in that world exactly at the language's probe, it
   reads the file the bridge step writes, and every probe step of the
   language depends on the bridge step. Exercised on zarith's fetched
   world — the only bridge step today. *)
let gate_after_bridge_pin : Canary_project_test.pure_test =
  { name = "steps.gate_is_read_after_its_bridge_runs";
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

(* A PLACEHOLDER STEP STANDS FOR WHAT A PACKAGE MANAGER DOES, UNSEEN
   (2026-09-23, status.md §2.7 E; user: "I like the placeholder steps").
   Derived for every project from the providers it declares, so this holds
   the derivation over every world of every active project:

   - each stands for an entry of its package manager's catalogue
     ([Canary_pm_action.inside_install]) — not a free-floating string;
   - it sits beside a real fetch of the same action in the same world, not
     a dummy one (a dummy installs nothing, so nothing is done unseen),
     depends on it, is named <fetch>_<pm>_<key>, and selects no agreements;
   - a dummy fetch has none beside it (sqlite's CPython stdlib binding);
   - both reasons are exercised, and zarith's fetched world carries the
     three opam pieces and the system package manager's one;
   - its command writes the marker and says what it stands for. *)
let placeholder_steps_pin : Canary_project_test.pure_test =
  { name = "steps.placeholders_stand_for_what_pms_do";
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
          (* and exercised: some world has a dummy fetch *)
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
        (* the command a placeholder resolves to writes its marker and says
           what it stands for *)
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

(* EVERY ACTION'S NAME READS BACK (2026-10-01). [action_of_string] kept
   its own list of spellings and missed a binding source's fetch, so
   [canary view] failed on zarith, whose run state names one. It looks the
   name up in [all_actions]: every action reads back as itself, no two
   share a name, and that fetch reads. *)
let action_names_pin : Canary_project_test.pure_test =
  { name = "basic.action_names_read_back";
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

let tests : Canary_project_test.pure_test list =
  [ providing_arrow_pin; shadow_policy_ladder_pin; vendored_world_probe_pin;
    world_assertion_vocabulary_pin; pipeline_ctx_pin; pipeline_total_pin;
    select_post_filter_pin; select_subset_pin; select_default_is_identity_pin;
    two_constructions_agree_pin; json_per_pass_pin; run_order_groups_state_pin;
    one_mechanism_per_language_pin; bridge_step_pin; gate_after_bridge_pin;
    placeholder_steps_pin; action_names_pin; touches_join_pin; inspect_clash_pin;
    dep_dirs_pin; demand_prune_pin; source_refresh_scope_pin ]
