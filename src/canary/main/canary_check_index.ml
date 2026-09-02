(** The checking index — what a project actually checks, and where each
    check comes from (2026-09-02, user: "a tentative working checking
    index so we will be clear what is checked and where it comes from
    the registry").

    This is the SYNC POINT between the catalogue and a run. For a real
    project it walks the actions the project's scenarios derive, and for
    each one reports:

    - the INTRINSIC check — the action's own outcome, which the runner
      performs whether or not any agreement is declared (the marker
      table, [Canary_step_builder.marker_of_action]);
    - the ADDED checks — the agreement rows whose firing includes that
      action, with the claim they make and the evidence they read.

    It is deliberately STATIC: no run is needed, so the index states what
    WOULD be checked, which is the thing to compare a run against. *)

open Base
module R = Canary_agreement_registry

type entry = {
  en_action    : Canary_basic.action;
  en_intrinsic : string;                     (** the action's own postcondition *)
  en_added     : (string * R.claim * R.evidence) list;  (** slug, claim, evidence *)
}

(** The agreements that fire at [action] for a binding of this mechanism
    and language, under this provision. *)
let added_at ~(mechanism : Canary_mechanism.mechanism) ~(lang : Canary_lang.lang)
    ~(provision : Canary_store.provision) (action : Canary_basic.action) :
    (string * R.claim * R.evidence) list =
  List.filter_map R.agreement_registry ~f:(fun r ->
      let fires =
        List.exists (r.R.ag_firing mechanism lang provision) ~f:(fun a ->
            Poly.equal a action)
      in
      let enabled = r.R.ag_check.Canary_agreement.enabled in
      if fires then
        Some
          ( (if enabled then r.R.ag_slug else r.R.ag_slug ^ " (off)"),
            r.R.ag_claim,
            r.R.ag_evidence )
      else None)

(** The index for one project: every action its scenarios derive, paired
    with the checks that apply. [mechanism]/[lang] default to the
    project's first declared binding when it has one. *)
let of_project ?policy (pr : Canary_project_run.project_run) :
    (Canary_store.provision * entry list) list =
  let decl = List.hd pr.Canary_project_run.pr_binding_decls in
  let mechanism, lang =
    match decl with
    | Some d ->
        let m = d.Canary_binding_decl.mechanism in
        (m, (Canary_mechanism.info_of_mechanism m).Canary_mechanism.mi_lang)
    | None -> (Canary_mechanism.Cstubs, Canary_lang.OCaml)
  in
  (* actions come from the scenarios of THAT world, not from the whole
     project: a Fetched world has no build_lib, and pretending otherwise
     is the kind of table that agrees with you for the wrong reason. *)
  let by_provision =
    Canary_project_run.scenarios_of ?policy pr
    |> List.map ~f:(fun a ->
           let provision =
             Canary_enumerate.provision_of a Canary_artifact.a_lib
           in
           let spec = pr.Canary_project_run.pr_runner_spec a ~workspace:"_out/tmp" () in
           let steps =
             Canary_step_builder.derive_steps ~root:"_out"
               ~project:pr.Canary_project_run.pr_name
               ~langs:Canary_lang.[ OCaml; Python ] spec
           in
           ( provision,
             List.map steps ~f:(fun (s : Canary_step_model.step) ->
                 s.Canary_step_model.action) ))
    |> List.fold ~init:[] ~f:(fun acc (pv, acts) ->
           match List.Assoc.find acc pv ~equal:Poly.equal with
           | Some prev ->
               List.Assoc.add acc pv (prev @ acts) ~equal:Poly.equal
           | None -> List.Assoc.add acc pv acts ~equal:Poly.equal)
    |> List.map ~f:(fun (pv, acts) ->
           (pv, List.dedup_and_sort acts ~compare:Poly.compare))
  in
  List.map by_provision ~f:(fun (provision, actions) ->
      ( provision,
        List.map actions ~f:(fun action ->
            { en_action = action;
              en_intrinsic = Canary_step_builder.marker_of_action action;
              en_added = added_at ~mechanism ~lang ~provision action }) ))

let pp (pr : Canary_project_run.project_run)
    (index : (Canary_store.provision * entry list) list) : string =
  let buf = Buffer.create 2048 in
  Buffer.add_string buf
    (Printf.sprintf "%s — checking index\n" pr.Canary_project_run.pr_name);
  Buffer.add_string buf
    "  (intrinsic = the action's own outcome; added = an agreement row)\n";
  List.iter index ~f:(fun (provision, entries) ->
      Buffer.add_string buf
        (Printf.sprintf "\nlib %s:\n"
           (Canary_enumerate.string_of_provision provision));
      List.iter entries ~f:(fun e ->
          let added =
            if List.is_empty e.en_added then "—"
            else
              String.concat ~sep:", "
                (List.map e.en_added ~f:(fun (slug, cl, ev) ->
                     Printf.sprintf "%s [%s/%s]" slug
                       (match cl with R.Structural -> "struct" | R.Semantic -> "sem")
                       (match ev with
                        | R.Inspect_one -> "inspect"
                        | R.Compare_several -> "compare"
                        | R.Run_tool -> "tool"
                        | R.Run_program -> "run")))
          in
          Buffer.add_string buf
            (Printf.sprintf "  %-22s intrinsic %-12s added %s\n"
               (Canary_basic.string_of_action e.en_action)
               e.en_intrinsic added)));
  (* the totals are the sync signal: how much of the catalogue a project
     actually exercises *)
  let added_slugs =
    List.concat_map index ~f:(fun (_, es) ->
        List.concat_map es ~f:(fun e -> List.map e.en_added ~f:(fun (s,_,_) -> s)))
    |> List.dedup_and_sort ~compare:String.compare
  in
  Buffer.add_string buf
    (Printf.sprintf
       "\n%d agreement(s) fire in this project; the registry declares %d, \
        the catalogue lists more (§1.7).\n"
       (List.length added_slugs) (List.length R.agreement_registry));
  Buffer.contents buf
