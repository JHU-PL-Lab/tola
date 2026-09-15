(** The checking index — what a project actually checks, where each
    check comes from, and whether a run ever decided it (2026-09-02,
    user: "a tentative working checking index so we will be clear what
    is checked and where it comes from the registry").

    This is the SYNC POINT between the catalogue and a run. For a real
    project it walks the actions the project's scenarios derive, and for
    each one reports:

    - the INTRINSIC check — the action's own outcome, which the runner
      performs whether or not any agreement is declared (the marker
      table, [Canary_step_builder.marker_of_action]);
    - the ADDED checks — the agreement rows whose firing includes that
      action, with the claim they make and the evidence they read;
    - what the recorded runs SAID at that cell.

    COULD DECIDE vs DID DECIDE (2026-09-15, user). The first two
    columns are static: no run is needed, so they state what WOULD be
    checked — and that was always described here as "the thing to
    compare a run against", while nothing did the comparing. The third
    column is that comparison, and the summary at the foot is the gap:
    a claim this project's shape says belongs here, with an evaluator
    ready, whose evidence no run has found. That number is the work
    queue; the other three rows are not.

    It degrades rather than requires: with no log the third column is
    empty and the first two are exactly what they were. *)

open Base
module R = Canary_agreement
module C = Canary_agreement_common

(** One agreement at one action, with what the log says about it. *)
type added = {
  ad_slug : string;
  ad_enabled : bool;
      (** the registry row's own switch. Kept as a FIELD rather than
          spelled into the slug, so a consumer joining this index
          against another view of the same cells is not parsing a
          display suffix back out *)
  ad_claim : C.claim;
  ad_how : string;
      (** the method summary — "2 evaluated, 1 planned" (2026-09-12).
          It used to be one [evidence] tag per agreement, which stopped
          being expressible when an agreement gained several methods
          with different kinds. *)
  ad_has_evaluator : bool;
      (** does ANY method firing here carry an evaluator? If not, no
          run can decide this cell and its silence is a registry fact,
          not a wiring gap — which is the distinction the summary turns
          on *)
  ad_observed : (string * int) list;
      (** outcome word × how many observations, from the recorded runs.
          [[]] = the log never mentioned this agreement at this step *)
}

type entry = {
  en_action    : Canary_basic.action;
  en_intrinsic : string;                     (** the action's own postcondition *)
  en_added     : added list;
}

let decided_words = [ "holds"; "violated" ]

let is_decided (a : added) : bool =
  List.exists a.ad_observed ~f:(fun (w, _) ->
      List.mem decided_words w ~equal:String.equal)

(** THE (MECHANISM, LANGUAGE) PAIRS TO ASK AN ACTION WITH (2026-09-15).

    An action that NAMES a language is asked with that language alone: a
    Python probe is not evidence about the OCaml binding. Asking every
    action with "the project's first declared binding" is how sqlite's
    index came to report that NOTHING fires at [probe_binding_python]
    while the same project's run decided [api_names_present] there six
    times — the index disagreed with the log, in the direction that
    understates coverage.

    A lib-side action names no language, so it is asked with every
    binding the project declares: what fires at [build_lib] is a union
    over the project's consumers, exactly as it is already a union over
    the group's worlds. *)
let pairs_for ~(decls : (Canary_mechanism.mechanism * Canary_lang.lang) list)
    (action : Canary_basic.action) :
    (Canary_mechanism.mechanism * Canary_lang.lang) list =
  let for_lang l =
    match List.filter decls ~f:(fun (_, l') -> Poly.equal l l') with
    | [] -> [ (Canary_mechanism.mechanism_of_lang_exn l, l) ]
    | ps -> ps
  in
  match action with
  | Canary_basic.Build_binding l
  | Canary_basic.Probe_binding l
  | Canary_basic.Fetch (Canary_basic.Binding l)
  | Canary_basic.Build_app { lang = l } ->
      for_lang l
  | _ -> decls

(** The agreements that fire at [action] for these bindings, in any of
    [worlds]. A row of this index stands for a GROUP of worlds (those
    sharing a lib provision), so the checks are unioned over the group
    exactly as its actions are — and each world is asked as itself,
    which is what stops a world's binding provision from being read off
    its lib's.

    APPLICABILITY IS APPLIED HERE (2026-09-15), the same static filter
    [Canary_matrix.check_cols_of_chain] uses, so the index and the
    result table's check columns cannot disagree about which cells
    exist. Without it the index claimed [signatures_agree] at a Python
    probe, where the mechanism declares its types as values and there
    are no stub signatures to read — a cell that could never say
    anything, counted as coverage. *)
let added_at ~(pairs : (Canary_mechanism.mechanism * Canary_lang.lang) list)
    ~(declared : Canary_artifact.t option)
    ~(worlds : Canary_artifact.assignment list)
    ~(observed : (string * string, (string, int) Hashtbl.t) Hashtbl.t)
    (action : Canary_basic.action) : added list =
  let tag = Canary_basic.string_of_action action in
  List.filter_map R.agreement_registry ~f:(fun r ->
      (* the METHODS that fire here, in any of the group's worlds, for
         any of the bindings this action speaks for. An agreement can
         reach an action through one method and not another, so the
         index counts methods rather than rows (2026-09-12). *)
      let firing =
        List.filter r.R.ag.C.ag_methods ~f:(fun m ->
            List.exists pairs ~f:(fun (mech, lang) ->
                R.suits_here ~mechanism:mech ~lang ~declared m
                && List.exists worlds ~f:(fun w ->
                       List.exists (m.C.m_firing mech lang w) ~f:(fun a ->
                           Poly.equal a action))))
      in
      if List.is_empty firing then None
      else
        let planned =
          List.count firing ~f:(fun m -> Option.is_none m.C.m_eval)
        in
        let how =
          match (List.length firing, planned) with
          | n, 0 -> Printf.sprintf "%d evaluated" n
          | n, p when n = p -> Printf.sprintf "%d planned" p
          | n, p -> Printf.sprintf "%d evaluated, %d planned" (n - p) p
        in
        let ad_observed =
          match Hashtbl.find observed (tag, r.R.ag_slug) with
          | None -> []
          | Some counts ->
              Hashtbl.to_alist counts
              |> List.sort ~compare:(fun (wa, na) (wb, nb) ->
                     match Int.compare nb na with
                     | 0 -> String.compare wa wb
                     | c -> c)
        in
        Some
          { ad_slug = r.R.ag_slug;
            ad_enabled = r.R.ag_enabled;
            ad_claim = r.R.ag.C.ag_claim;
            ad_how = how;
            ad_has_evaluator = List.length firing > planned;
            ad_observed })

(** Every agreement outcome the recorded runs carry, keyed by the step
    that evaluated it and the agreement it is about — the join key the
    static half already has, since a step's tag IS its action's name.

    It reads every scenario, because the index's rows are world GROUPS
    rather than scenarios: "did anything ever decide this here" is the
    question, and a single scenario cannot answer it. *)
let observed_table ~root ~project :
    (string * string, (string, int) Hashtbl.t) Hashtbl.t =
  let tbl : (string * string, (string, int) Hashtbl.t) Hashtbl.t =
    Hashtbl.Poly.create ()
  in
  List.iter (Canary_status.project_agreements ~root ~project)
    ~f:(fun (_scenario, obs) ->
      List.iter obs ~f:(fun (o : Canary_status.agreement_obs) ->
          let counts =
            Hashtbl.find_or_add tbl
              (o.Canary_status.ao_tag, o.Canary_status.ao_agreement)
              ~default:(fun () -> Hashtbl.create (module String))
          in
          Hashtbl.update counts o.Canary_status.ao_outcome ~f:(function
            | None -> 1
            | Some n -> n + 1)));
  tbl

(** The index for one project: every action its scenarios derive, paired
    with the checks that apply and with what the runs under [root] said
    about each. *)
let of_project ?policy ?(root = "_out") (pr : Canary_project_run.project_run) :
    (Canary_store.provision * entry list) list =
  let declared = Canary_pipeline.declared_api_of pr in
  (* WHAT THIS PROJECT'S BINDINGS ARE, all of them. The project already
     says so; taking only the first is what made the index single-
     language. A project with no declared binding keeps the old
     fallback, since something has to be asked. *)
  let decls =
    match
      List.map pr.Canary_project_run.pr_binding_decls
        ~f:(fun (d : Canary_binding_decl.binding_decl) ->
          let m = d.Canary_binding_decl.mechanism in
          (m, (Canary_mechanism.info_of_mechanism m).Canary_mechanism.mi_lang))
      |> List.dedup_and_sort ~compare:Poly.compare
    with
    | [] -> [ (Canary_mechanism.Cstubs, Canary_lang.OCaml) ]
    | ds -> ds
  in
  let observed = observed_table ~root ~project:pr.Canary_project_run.pr_name in
  (* actions come from the scenarios of THAT world, not from the whole
     project: a Fetched world has no build_lib, and pretending otherwise
     is the kind of table that agrees with you for the wrong reason. *)
  let by_provision =
    Canary_project_run.scenarios_of ?policy pr
    |> List.map ~f:(fun a ->
           let provision = Canary_artifact.provision_of_lib a in
           let spec = pr.Canary_project_run.pr_runner_spec a ~workspace:"_out/tmp" () in
           let steps =
             Canary_step_builder.derive_steps ~root:"_out"
               ~project:pr.Canary_project_run.pr_name
               ~langs:Canary_lang.[ OCaml; Python ] spec
           in
           ( provision,
             ( [ a ],
               List.map steps ~f:(fun (s : Canary_step_model.step) ->
                   s.Canary_step_model.action) ) ))
    (* the group carries its WORLDS, not just their shared lib
       provision: what fires depends on each world in full, so the
       group cannot be collapsed to one provision before asking *)
    |> List.fold ~init:[] ~f:(fun acc (pv, (ws, acts)) ->
           match List.Assoc.find acc pv ~equal:Poly.equal with
           | Some (prev_ws, prev) ->
               List.Assoc.add acc pv (prev_ws @ ws, prev @ acts)
                 ~equal:Poly.equal
           | None -> List.Assoc.add acc pv (ws, acts) ~equal:Poly.equal)
    |> List.map ~f:(fun (pv, (ws, acts)) ->
           (pv, (ws, List.dedup_and_sort acts ~compare:Poly.compare)))
  in
  List.map by_provision ~f:(fun (provision, (worlds, actions)) ->
      ( provision,
        List.map actions ~f:(fun action ->
            { en_action = action;
              en_intrinsic = Canary_step_builder.marker_of_action action;
              en_added =
                added_at
                  ~pairs:(pairs_for ~decls action)
                  ~declared ~worlds ~observed action }) ))

(* ── rendering ──────────────────────────────────────────────────── *)

let string_of_claim = function
  | C.Structural -> "struct"
  | C.Behavioral -> "behav"

let pp_observed_cell (a : added) : string =
  match a.ad_observed with
  | [] -> if a.ad_has_evaluator then "(never asked)" else "(no evaluator)"
  | os ->
      String.concat ~sep:", "
        (List.map os ~f:(fun (w, n) -> Printf.sprintf "%s x%d" w n))

(** THE GAP, per agreement rather than per cell — an agreement decided
    at one of its firing sites is decided, and the reader wants to know
    which claims this project has actually established. Five classes,
    and three of them are work queues with three different jobs:

    - DECIDED: a recorded run reached [holds] or [violated] somewhere;
    - COULD NOT: an evaluator ran and could not conclude. The outcome
      words say why — [unavailable] is missing evidence (a WIRING gap:
      nothing wrote it, or the reader ran before the writer),
      [inconclusive] is evidence read with nothing to compare against
      (usually a DECLARATION gap);
    - STOOD DOWN: the log says [not_applicable] (or [disabled]) at a
      cell this index says the claim belongs to. Since applicability
      became a static property of the project (2026-09-14) the two
      cannot disagree in a fresh run — the static filter would have
      dropped the cell — so this means the log PREDATES that change.
      The job is to re-run, not to wire anything;
    - NEVER ASKED: it fires here, has an evaluator, and no log line
      mentions it — the step has not run cold since it was registered;
    - NO EVALUATOR: every method firing here is planned. Nothing to
      wire; it waits on somebody to state a spec, which is why the
      three unrooted agreements sit here in every project.

    The classes read a cell's outcome words as a whole, which is exact
    while an agreement has ONE method firing per action — true of all 13
    today. An agreement that grew a planned method beside an evaluated
    one would show [not_implemented] mixed in and land in [Could_not],
    which is still the right queue (its evaluator is what is stuck) but
    stops being the whole story. *)
type gap_class = Decided | Could_not | Stood_down | No_evaluator | Never_asked

let stood_down_words = [ "not_applicable"; "disabled" ]

let classify (rows : added list) : gap_class =
  if List.exists rows ~f:is_decided then Decided
  else if not (List.exists rows ~f:(fun a -> a.ad_has_evaluator)) then
    No_evaluator
  else if List.for_all rows ~f:(fun a -> List.is_empty a.ad_observed) then
    Never_asked
  else if
    (* every word the log carries for this claim stood the method down,
       so no evaluator ever ran — not the same as one that ran and
       found nothing to read *)
    List.for_all rows ~f:(fun a ->
        List.for_all a.ad_observed ~f:(fun (w, _) ->
            List.mem stood_down_words w ~equal:String.equal))
  then Stood_down
  else Could_not

let pp (pr : Canary_project_run.project_run)
    (index : (Canary_store.provision * entry list) list) : string =
  let buf = Buffer.create 4096 in
  Buffer.add_string buf
    (Printf.sprintf "%s — checking index\n" pr.Canary_project_run.pr_name);
  Buffer.add_string buf
    "  (intrinsic = the action's own outcome; added = an agreement row;\n\
    \   the last column is what the recorded runs decided there)\n";
  List.iter index ~f:(fun (provision, entries) ->
      Buffer.add_string buf
        (Printf.sprintf "\nlib %s:\n"
           (Canary_enumerate.string_of_provision provision));
      List.iter entries ~f:(fun e ->
          Buffer.add_string buf
            (Printf.sprintf "  %-22s intrinsic %-12s %s\n"
               (Canary_basic.string_of_action e.en_action)
               e.en_intrinsic
               (if List.is_empty e.en_added then "— no agreement fires here"
                else ""));
          List.iter e.en_added ~f:(fun a ->
              Buffer.add_string buf
                (Printf.sprintf "      %-30s %-6s %-18s %s\n"
                   (if a.ad_enabled then a.ad_slug else a.ad_slug ^ " (off)")
                   (string_of_claim a.ad_claim) a.ad_how (pp_observed_cell a)))));
  (* ── COULD DECIDE vs DID DECIDE ── the reason this report exists *)
  let by_slug : (string, added list) Hashtbl.t = Hashtbl.create (module String) in
  let order = ref [] in
  List.iter index ~f:(fun (_, es) ->
      List.iter es ~f:(fun e ->
          List.iter e.en_added ~f:(fun a ->
              (match Hashtbl.find by_slug a.ad_slug with
               | None -> order := a.ad_slug :: !order
               | Some _ -> ());
              Hashtbl.update by_slug a.ad_slug ~f:(function
                | None -> [ a ]
                | Some xs -> a :: xs))));
  let slugs = List.dedup_and_sort (List.rev !order) ~compare:String.compare in
  let classified =
    List.map slugs ~f:(fun s ->
        let rows = Hashtbl.find_exn by_slug s in
        (s, classify rows, rows))
  in
  let pick k = List.filter classified ~f:(fun (_, c, _) -> Poly.equal c k) in
  let names ~with_reason rows =
    String.concat ~sep:", "
      (List.map rows ~f:(fun (s, _, xs) ->
           if not with_reason then s
           else
             let why =
               List.concat_map xs ~f:(fun a -> List.map a.ad_observed ~f:fst)
               |> List.dedup_and_sort ~compare:String.compare
             in
             if List.is_empty why then s
             else s ^ " (" ^ String.concat ~sep:"/" why ^ ")"))
  in
  let line label rows ~with_reason =
    if List.is_empty rows then ""
    else
      Printf.sprintf "  %-14s %2d  %s\n" label (List.length rows)
        (names ~with_reason rows)
  in
  Buffer.add_string buf
    (Printf.sprintf
       "\nCOULD DECIDE vs DID DECIDE — %d agreement(s) fire in this project; \
        the registry declares %d\n"
       (List.length slugs) (List.length R.agreement_registry));
  Buffer.add_string buf (line "decided" (pick Decided) ~with_reason:false);
  Buffer.add_string buf (line "could not" (pick Could_not) ~with_reason:true);
  Buffer.add_string buf
    (line "never asked" (pick Never_asked) ~with_reason:false);
  Buffer.add_string buf (line "stood down" (pick Stood_down) ~with_reason:false);
  Buffer.add_string buf
    (line "no evaluator" (pick No_evaluator) ~with_reason:false);
  let gap =
    List.length (pick Could_not)
    + List.length (pick Never_asked)
    + List.length (pick Stood_down)
  in
  Buffer.add_string buf
    (if gap = 0 then
       "\n  No gap: every claim with an evaluator has been decided here.\n"
     else
       Printf.sprintf
         "\n  THE GAP IS %d: claim(s) this project's shape says belong here, \
          with an\n  evaluator ready, that no recorded run has decided.\n\
         \    could not   — the evaluator ran: `unavailable` is missing \
          evidence,\n\
         \                  `inconclusive` is evidence with nothing to \
          compare against.\n\
         \    never asked — no log line at all; the step has not run cold \
          since.\n\
         \    stood down  — the log says not_applicable where the registry \
          now says\n\
         \                  the claim applies, so the log predates that: \
          re-run it.\n"
         gap);
  Buffer.contents buf
