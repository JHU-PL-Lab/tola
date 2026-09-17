(** [Canary_agreement] — TIER 3: THE LIST, and everything derived from
    it. Design: [doc/canary/design/agreement/model.md].

    The agreement layer is three tiers: [Canary_agreement_common]
    declares the types; each [Canary_agreement_<topic>] is one family
    that uses them to describe ITSELF; this module gathers the families
    and is what everyone else consults.

    A ROW is three things and no more — the agreement's id (which IS
    its name), the anchor of the section that explains it, and whether
    it is switched on. Everything else comes from the family:

      row Required_symbols_exported ~doc:"§3.1.2"

    Everything here is DERIVED from that list: selection by action
    context ([evaluate_in_context], [agreements_for]), the legacy
    input-driven dispatch ([evaluate_over_inputs],
    [predicted_by_agreement]), [inputs_of_agreement], the gathered
    counterexamples, the firing table and its fill list, the
    proposed-agreement table, and the catalogue views.

    What is NOT here, deliberately: no sentence, no subject, no input
    path, no counterexample. Every one of those was here once, and
    every one of them had drifted from the family's copy.

    {1 What the 2026-09-12 migration changed}

    - Agreements are NAMED, not numbered. [c1..c9] said nothing and
      could not be read in a log.
    - Solo and pair are GONE from the identity. They were two claims
      with two references sharing one id, one status and one
      attribution; they are separate agreements now, which is what
      makes "the declaration comparison has no production caller" a
      fact the registry can state rather than a footnote.
    - A row no longer carries a single [status]. Implementation is a
      property of a METHOD, and an agreement may have several.
    - Evaluation returns an [outcome], not a substring list. An empty
      substring list used to mean seven different things.

    Layering: agreement/ depends only on base/. The firing domain is
    [Canary_basic.action] — base vocabulary, no new firing type
    invented here. *)

open Base
open Canary_agreement_common

(* ── the families, gathered ───────────────────────────────────────── *)

(** Every agreement every family declares. A family publishes
    [checks : (agreement_id * agreement) list]; this concatenates them,
    and [agreements.ids_are_total] pins that the union covers
    [all_agreement_ids] exactly once each. *)
(* The gathering, BY MODULE (2026-09-17). It used to be one flat
   [List.concat] of seven [checks] lists, which threw away the only fact
   that says where an agreement is implemented: an [agreement] record
   carries closures, and a closure reports neither its name nor its file.

   `composed` is in this list and is NOT a family — it publishes
   `composes` and reads other families' verdicts (CLAUDE.md states the
   property). It belongs here because the list's job is `id → module`,
   and `repack_complete` does live in `canary_agreement_composed.ml`. *)
let agreement_modules : (string * (agreement_id * agreement) list) list =
  [ ("symbols", Canary_agreement_symbols.checks);
    ("api_surface", Canary_agreement_api_surface.checks);
    ("behaviour", Canary_agreement_behaviour.checks);
    ("identity", Canary_agreement_identity.checks);
    ("types", Canary_agreement_types.checks);
    ("staging", Canary_agreement_staging.checks);
    ("composed", Canary_agreement_composed.checks) ]

let declared_agreements : (agreement_id * agreement) list =
  List.concat_map agreement_modules ~f:snd

(** WHICH MODULE DECLARED THIS — the topic half of
    [canary_agreement_<topic>.ml] (2026-09-17).

    Derived from the gathering above rather than declared per agreement,
    so it cannot drift: the list that produces the registry is the list
    that names the files. Only the FUNCTION half is written down
    ([m_impl]), which is the half a closure cannot report. *)
let family_of (id : agreement_id) : string =
  match
    List.find agreement_modules ~f:(fun (_, cs) ->
        List.exists cs ~f:(fun (i, _) -> Poly.equal i id))
  with
  | Some (name, _) -> name
  | None -> "?"

(** The repo-relative PATH, not the basename: the string is shown as a
    tooltip and copied into an editor, so it should be openable. *)
let family_file_of (id : agreement_id) : string =
  "src/canary/agreement/canary_agreement_" ^ family_of id ^ ".ml"

let agreement_of (id : agreement_id) : agreement =
  match
    List.find declared_agreements ~f:(fun (i, _) -> Poly.equal i id)
  with
  | Some (_, ag) -> ag
  | None ->
      failwith
        (Printf.sprintf "agreement registry: no family declares %s"
           (string_of_agreement_id id))

(* ── the rows ─────────────────────────────────────────────────────── *)

type agreement_row = {
  ag_id : agreement_id;
  ag_slug : string;
      (** the stable NAME. Not independent data: it is
          [string_of_agreement_id ag_id], carried on the row so the
          display layers do not each convert. *)
  ag_doc : string;
      (** the anchor in doc/canary/design/agreement/components.md —
          where an agreement's RATIONALE lives, as against
          [catalogue.md] which says what it is. Pinned by
          [agreements.doc_anchors_exist], so the numbering over there is
          load-bearing. The registry's to give: a fact about the
          DOCUMENT, not about the agreement.

          It pointed into `registry.md` until 2026-09-17, when that file
          split; the §-numbers did not move, only the filename. *)
  ag_formats : Canary_store.object_format list;
      (** THE OBJECT FORMATS this claim can range over (2026-09-17,
          user, when the recovery grid gained a platform column).

          A third reason a claim can be inapplicable, beside the
          mechanism and the project's declaration: **the format has no
          such thing.** Mach-O carries no symbol versioning at all, so
          the two version-node agreements are not unwired there and not
          missing evidence — there is nothing of that kind to read, on
          any project, ever.

          Stating it as a value rather than prose is what lets the grid
          have a column. It is NOT the open question about Mach-O's
          `compatibility_version` (`directions.md` §3): that asks
          whether to ADD a library-granularity floor agreement, and this
          only records that the SYMBOL-granularity ones do not apply.

          On the ROW rather than in the family's `agreement` record,
          like [ag_doc] and [ag_waiting_on]: a family states the CLAIM,
          and which formats carry it is a fact about the world the
          registry is placing that claim in. *)
  ag_waiting_on : string option;
      (** WHAT WOULD LAND THIS, or [None] when nothing known blocks it
          (2026-09-17, user: "a rewrite for catalogue with completed
          and to-do").

          It lives on the row rather than in a doc because the doc that
          used to hold it — `landing.md`'s per-agreement table — went
          stale the way every hand copy of a generated table does. One
          line here, beside the row it describes, is harder to forget
          than a table in another file.

          It is NOT the landed/not split. That is a fact about run
          LOGS, and the catalogue is generated from code alone — if it
          read logs it would change whenever anything ran and its pin
          would fail. `canary checks --landing` is the live answer;
          this says what is in the way. *)
  ag_enabled : bool;
      (** switched on for this build. NOT an implementation status —
          that is per-method ([m_eval = None] ⇒ planned). Every row
          ships enabled today; a planned agreement is still selected
          and still reports [not_implemented], which is the whole point
          of registering it *)
  ag : agreement;
      (** EVERYTHING ELSE, stated by the family's own module *)
}

let all_formats = Canary_store.[ Elf; Macho ]

let row ?(enabled = true) ?waiting_on ?(formats = all_formats) ~doc
    (id : agreement_id) : agreement_row =
  { ag_id = id;
    ag_slug = string_of_agreement_id id;
    ag_doc = doc;
    ag_waiting_on = waiting_on;
    ag_formats = formats;
    ag_enabled = enabled;
    ag = agreement_of id }

(** THE table. Order is catalogue order: symbols, api names, behaviour,
    identity, symbol versions, signatures, dependencies, repacking. *)
let agreement_registry : agreement_row list =
  [ row Declared_symbols_exported ~doc:"§2.2";
    row Required_symbols_exported ~doc:"§3.1.2";
    row Api_names_present ~doc:"§3.1.1";
    row Behavior_matches ~doc:"§6.3.2"
      ~waiting_on:
        "somebody to state a spec. This is one row standing for a \
         CATEGORY — derived compatibility tests, the project's own \
         suite, a provider/consumer round trip — and it needs both an \
         expectation and a comparison. Introduce one test-suite reuse \
         case, then one C/binding differential case: the first supplies \
         the expectation, the second the comparison";
    row Soname_matches_declaration ~doc:"§2.2";
    row Soname_matches_requirement ~doc:"§4.1";
    (* ELF ONLY: Mach-O has no symbol versioning, so there is nothing
       of this kind to range over there — not unwired, absent. *)
    row Declared_versions_exported ~doc:"§2.2" ~formats:[ Canary_store.Elf ]
      ~waiting_on:
        "a project that BUILDS a library carrying a version script. \
         sqlite builds without one, so there are no version nodes and \
         `vacuous` is the truth rather than a gap; openssl has one and \
         canary fetches its lib, so build_lib never fires there";
    row Required_versions_exported ~doc:"§4.1" ~formats:[ Canary_store.Elf ];
    row Signatures_agree ~doc:"§3.1.2"
      ~waiting_on:
        "the source-scanning inspectors, which no project wires. Also a \
         real signature extractor in place of the fixed binding-signature \
         table, so the check compares what the binding DECLARES rather \
         than what the inspector was told to assume";
    row Dependencies_provided ~doc:"§5.6";
    row Staged_interface_preserved ~doc:"§6.1";
    row Repack_preserves_api ~doc:"§6.3.1"
      ~waiting_on:
        "a statement of what \"preserves\" permits — a rename, a merge, \
         a deliberate omission (components.md §6.3.1). The claim has to \
         be scoped before it can be named properly, let alone checked";
    row Repack_complete ~doc:"§6.3.1"
      ~waiting_on:
        "the same scoping as repack_preserves_api, plus the two \
         agreements it composes. A composition cannot be better rooted \
         than its weakest part" ]

(** Total lookup over the table. *)
let row_of (id : agreement_id) : agreement_row =
  List.find agreement_registry ~f:(fun r -> Poly.equal r.ag_id id)
  |> Option.value_exn
       ~message:
         (Printf.sprintf "agreement registry: no row for %s"
            (string_of_agreement_id id))

(* ── evaluation results ───────────────────────────────────────────── *)

(** ONE method's verdict in one place. Carries the agreement's name and
    the method's, because an agreement with two methods can hold under
    one and be unavailable under the other, and a report that named
    only the agreement could not say which. *)
(** How the evidence a method read was named. It matters for reading a
    log: [Derived] means the registry resolved the method's own
    declared paths from the world, [Declared] means the project's
    expectation handed over an input list because its layout is not
    derivable yet (§7.1). *)
type evidence_route = Derived | Declared

let string_of_route = function Derived -> "derived" | Declared -> "declared"

type evaluation = {
  ev_id : agreement_id;
  ev_slug : string;
  ev_method : string;
  ev_route : evidence_route;
  ev_outcome : outcome;
  ev_diagnostics : string list;
      (** the predicted diagnostic text for a violation — empty for
          every other outcome. Separate from [ev_outcome] on purpose:
          the outcome is the verdict, these are the strings a failing
          log is expected to contain *)
}

(** The LOG form of an evaluation: agreement, method, outcome, and as
    much of the reason as belongs in a log line. A planned method's
    reason is a paragraph — it says what implementing it would take,
    which is worth stating once in the catalogue and not at every probe
    step of every scenario. [canary checks --catalogue] prints it in
    full. *)
let pp_evaluation (e : evaluation) : string =
  let head = Printf.sprintf "%s/%s: %s" e.ev_slug e.ev_method
      (outcome_label e.ev_outcome) in
  match outcome_detail e.ev_outcome with
  | "" -> head
  | d ->
      let limit = 110 in
      let d =
        if String.length d <= limit then d
        else String.prefix d limit ^ "…"
      in
      head ^ ": " ^ d

let is_disabled ~(disabled : agreement_id list) (r : agreement_row) : bool =
  (not r.ag_enabled) || List.mem disabled r.ag_id ~equal:Poly.equal

(* ── THE PRODUCTION PATH: action context in, outcomes out ──────────

   A step knows three facts about itself — the binding mechanism, the
   language, and the world the enumeration assigned — plus the action
   it is. That is enough to select every method whose evidence exists
   at that point, resolve what each reads, and evaluate it. No project
   names an agreement; no caller supplies an input list.

   This is the direction [inputs_of_agreement] had backwards, and the
   gap §7.4 item 3 recorded: production predictions went through the
   input-driven dispatch below, and the context query had test callers
   only. *)

(** Every method that FIRES at [action] under these facts, with its
    outcome. Planned methods are included and report
    [Not_implemented] — a selection that dropped them would report
    full coverage of an action while saying nothing about the claims
    nobody has implemented yet. *)

(** WHICH CLAIMS THIS PROJECT CANNOT CARRY, AND WHY — computed once
    from the three static facts a spec yields (2026-09-14, user).

    Applicability was a per-step gate: every method re-answered it at
    every firing site, and the runner logged the answer each time.
    sqlite emitted the same six [not_applicable] sentences on every one
    of ten scenarios — sixty lines restating one fact about cstubs.

    It is a property of the PROJECT, so it is derived here, once, and
    reported once. What varies per scenario is whether a run reaches
    the claim, and that is [m_firing]'s question and always was. *)
type unsuited = {
  us_slug : string;
  us_method : string;
  us_lang : Canary_lang.lang;
      (** WHICH SIDE cannot carry it. A project with two bindings can
          be unsuited on one and fine on the other — sqlite's cstubs
          archive records no NEEDED while its Python extension is a
          shared object that does — so a report that omitted the
          language would list a claim as impossible while the log
          beside it showed that claim running. *)
  us_why : string;
}

let unsuited_here ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(declared : Canary_artifact.t option) :
    unsuited list =
  List.concat_map agreement_registry ~f:(fun r ->
      List.filter_map r.ag.ag_methods ~f:(fun m ->
          match m.m_applicable mechanism lang declared with
          | Applicable -> None
          | Inapplicable why ->
              Some
                { us_slug = r.ag_slug; us_method = m.m_name; us_lang = lang;
                  us_why = why }))

(** The same question for one method — what the result table's columns
    and the runner's selection both ask. *)
let suits_here ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(declared : Canary_artifact.t option)
    (m : checking_method) : bool =
  match m.m_applicable mechanism lang declared with
  | Applicable -> true
  | Inapplicable _ -> false

let evaluate_in_context ?(disabled = []) ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(world : Canary_artifact.assignment)
    ?(declared : Canary_artifact.t option)
    ~(action : Canary_basic.action) ~(resolve : string -> string) () :
    evaluation list =
  List.concat_map agreement_registry ~f:(fun r ->
      let off = is_disabled ~disabled r in
      List.filter_map r.ag.ag_methods ~f:(fun m ->
          let fires =
            List.exists (m.m_firing mechanism lang world) ~f:(fun a ->
                Poly.equal a action)
          in
          (* A CLAIM THIS PROJECT CANNOT CARRY IS NOT AN OUTCOME
             (2026-09-14, user). It used to be evaluated and logged as
             [not_applicable] at every firing site, which restated one
             static fact once per step — sixty lines on a ten-scenario
             sqlite run saying that a cstubs archive records no NEEDED.
             The fact is reported once now, from the spec, by
             [Canary_pipeline.unsuited_of]; the RUN carries only what a
             run can discover. *)
          if (not fires) || not (suits_here ~mechanism ~lang ~declared m) then
            None
          else
            let outcome =
              evaluate_method ~disabled:off ~mechanism ~lang ~world ?declared
                ~resolve m
            in
            Some
              { ev_id = r.ag_id;
                ev_slug = r.ag_slug;
                ev_method = m.m_name;
                ev_route = Derived;
                ev_outcome = outcome;
                ev_diagnostics = m.m_diagnostics outcome }))

(** The violations among [evaluate_in_context]'s results — the subset a
    failing step's log should be greppable for. *)
let violations_in_context ?disabled ~mechanism ~lang ~world ~action ~resolve () =
  evaluate_in_context ?disabled ~mechanism ~lang ~world ~action ~resolve ()
  |> List.filter ~f:(fun e -> is_violation e.ev_outcome)

(* ── THE INPUT-DRIVEN PATH (legacy, still load-bearing) ────────────

   A project's [Expect_compat_failure { inputs }] names the evidence
   itself, because its layout deviates from the derived one (llvm's
   packed binding, z3's fetch-step attribute inspection). Naming the
   evidence IS the statement that the check applies, so this path does
   NOT consult [m_applicable] — doing so would silence the identity
   agreements under cstubs even where a project handed them a cext's
   dependency record on purpose.

   It stays until evidence routing is derived for those layouts; §7.4
   item 3's "migrate remaining consumers". *)

let evaluate_over_inputs ?(disabled = []) ~(resolve : string -> string)
    (inputs : inspect_input list) : evaluation list =
  List.concat_map agreement_registry ~f:(fun r ->
      let off = is_disabled ~disabled r in
      List.filter_map r.ag.ag_methods ~f:(fun m ->
          let outcome =
            if off then Disabled "switched off for this run"
            else
              match m.m_eval with
              | None ->
                  Not_implemented
                    (if String.is_empty m.m_planned then "no evaluator"
                     else m.m_planned)
              | Some ev -> (
                  try normalize_outcome (ev ~resolve inputs)
                  with exn -> Error (Exn.to_string exn))
          in
          match outcome with
          (* a method whose evidence kinds are simply absent from the
             supplied list is not a finding here — the caller named
             what it wanted checked *)
          | Unavailable _ -> None
          | _ ->
              Some
                { ev_id = r.ag_id;
                  ev_slug = r.ag_slug;
                  ev_method = m.m_name;
                  ev_route = Declared;
                  ev_outcome = outcome;
                  ev_diagnostics = m.m_diagnostics outcome }))

(** The rows that FIRED — each agreement whose evaluation over these
    inputs found a counterexample, paired with its (deduped) predicted
    diagnostic substrings. {!predicted_contains_any} is its flatten;
    keeping the grouping lets the runner log and report per-agreement
    firings instead of one collapsed count. *)
let predicted_by_agreement ?(disabled = []) ~resolve
    (inputs : inspect_input list) : (agreement_row * string list) list =
  evaluate_over_inputs ~disabled ~resolve inputs
  |> List.filter_map ~f:(fun e ->
         if is_violation e.ev_outcome && not (List.is_empty e.ev_diagnostics)
         then
           Some
             (row_of e.ev_id, List.dedup_and_sort ~compare:String.compare
                                e.ev_diagnostics)
         else None)

(* ── ONE RECORD PER STEP ───────────────────────────────────────────

   Both routes above answer the same question with the same
   evaluators, and until 2026-09-12 a compat step ran BOTH — the
   context path to report and the input path to decide — so a step
   evaluated its comparators twice and could in principle log one
   thing while accepting another. This is the single record both
   consumers read.

   The merge is not a concatenation. The two routes can reach the same
   (agreement, method) by different evidence, and when they do, the
   DECIDED one wins: declared inputs exist precisely to reach evidence
   the derivation cannot find (llvm packs its binding into opam), so a
   derived [unavailable] alongside a declared [violated] means the
   project was right about where its evidence lives. Two decided
   outcomes that disagree cannot happen from one evaluator over one
   world unless the two input sets point at different artifacts, which
   is the case the route tag exists to make visible in the log. *)

type step_evaluation = {
  sv_all : evaluation list;
      (** every method selected at this step, whatever its outcome —
          the REPORTING half *)
  sv_violations : evaluation list;
      (** the detected disagreements. A fact about the artifacts, true
          whether or not any step is expected to fail *)
  sv_diagnostics : string list;
      (** the union of those violations' predicted diagnostic text —
          what the ACCEPTANCE policy greps a failing run's output for *)
  sv_inputs : inspect_input list;
      (** every evidence reference this record consulted, for the
          callers that want to ask about the evidence itself *)
}

let empty_step_evaluation =
  { sv_all = []; sv_violations = []; sv_diagnostics = []; sv_inputs = [] }

(** Evaluate everything that applies to one step, once.

    [context] gives the derived route (selection by action and
    applicability, evidence resolved from the world). [declared_inputs]
    gives the declared route (the project named its own evidence).
    Either may be absent; with neither, the record is empty and no
    caller has anything to report or to accept on. *)
let evaluate_step ?(disabled = []) ?(context : action_context option)
    ?(action : Canary_basic.action option) ?(declared_inputs = [])
    ~(resolve : string -> string) () : step_evaluation =
  let derived =
    match (context, action) with
    | Some ctx, Some a ->
        evaluate_in_context ~disabled ~mechanism:ctx.ac_mechanism
          ~lang:ctx.ac_lang ~world:ctx.ac_world ?declared:ctx.ac_declared
          ~action:a ~resolve ()
    | _ -> []
  in
  let declared =
    if List.is_empty declared_inputs then []
    else evaluate_over_inputs ~disabled ~resolve declared_inputs
  in
  let key (e : evaluation) = (string_of_agreement_id e.ev_id, e.ev_method) in
  (* WHICH OF TWO OUTCOMES FOR ONE METHOD SURVIVES. Ordered so that a
     merge can never lose a finding:

       violated  >  holds  >  anything undecided

     A detected disagreement outranks a [holds] reached from other
     evidence, because the two input sets then point at different
     artifacts and the disagreement is the one worth acting on — losing
     it would be a checking tool quietly preferring the good news. A
     decided outcome outranks an undecided one, which is the ordinary
     case: the declared route exists precisely to reach evidence the
     derivation cannot find. Ties keep the derived entry, so the merge
     is deterministic. *)
  let rank (e : evaluation) =
    if is_violation e.ev_outcome then 2
    else if is_decided e.ev_outcome then 1
    else 0
  in
  let merged =
    List.fold declared ~init:derived ~f:(fun acc d ->
        match List.findi acc ~f:(fun _ e -> Poly.equal (key e) (key d)) with
        | None -> acc @ [ d ]
        | Some (i, existing) ->
            if rank d > rank existing then
              List.mapi acc ~f:(fun j e -> if j = i then d else e)
            else acc)
  in
  let violations = List.filter merged ~f:(fun e -> is_violation e.ev_outcome) in
  let derived_inputs =
    match (context, action) with
    | Some ctx, Some a ->
        List.concat_map agreement_registry ~f:(fun r ->
            List.concat_map r.ag.ag_methods ~f:(fun m ->
                if
                  List.exists (m.m_firing ctx.ac_mechanism ctx.ac_lang ctx.ac_world)
                    ~f:(fun x -> Poly.equal x a)
                then m.m_inputs ctx
                else []))
    | _ -> []
  in
  { sv_all = merged;
    sv_violations = violations;
    sv_diagnostics =
      List.concat_map violations ~f:(fun e -> e.ev_diagnostics)
      |> List.dedup_and_sort ~compare:String.compare;
    sv_inputs = declared_inputs @ derived_inputs }

(** WHICH DETECTED DISAGREEMENTS THIS RUN ACTUALLY SHOWED.

    The distinction this function exists to keep. A [violated] outcome
    is a finding about artifacts. A step passing as a confirmed
    expected failure is a fact about this run: its command failed AND
    the output carried what the agreement predicted. Either can occur
    without the other —

    - confirmed: the artifacts disagree and this action surfaced it.
      These are the agreements the verdict marker records, because they
      are what the expected-failure test actually observed.
    - unconfirmed: the artifacts disagree and this action did not
      surface it. Not a failure of the agreement and not a pass: the
      finding stands, and the step simply was not the place it shows.

    A step can also pass as an expected failure with NOTHING confirmed
    — the empty-prediction fallback — and that is recorded as an
    unattributed xfail rather than credited to an agreement. *)
let partition_confirmation (se : step_evaluation)
    ~(matches : string list -> bool) : evaluation list * evaluation list =
  List.partition_tf se.sv_violations ~f:(fun e -> matches e.ev_diagnostics)

let predicted_contains_any ?(disabled = []) ~resolve
    (inputs : inspect_input list) : string list =
  predicted_by_agreement ~disabled ~resolve inputs
  |> List.concat_map ~f:snd
  |> List.dedup_and_sort ~compare:String.compare

(** The registry rows a call does NOT consult, each with its reason —
    the per-call [?disabled] override (a project's
    [disabled_agreements] / [--disable-agreement]) vs the registry's own
    flag. For the runner's [agreement_skipped] events.

    Note what is NOT here any more: a planned agreement. It used to be
    reported as "disabled in registry (stubbed)", which put "nobody has
    implemented this" and "you switched this off" in one bucket. A
    planned agreement is selected and reports [not_implemented]. *)
let skipped_checks ?(disabled = []) () : (agreement_row * string) list =
  List.filter_map agreement_registry ~f:(fun r ->
      if List.mem disabled r.ag_id ~equal:Poly.equal then
        Some (r, "disabled per call")
      else if not r.ag_enabled then Some (r, "disabled in registry")
      else None)

(* ── what an agreement reads ──────────────────────────────────────── *)

(** What one agreement reads, by id — the union over its methods.

    [mechanism] defaults to the language's default (static for
    OCaml/Python today); a dynamic binding has no compiled stub to
    inspect, which each method's [m_inputs] answers for itself. *)
let inputs_of_agreement ?mechanism ?(world = []) (c : agreement_id)
    (l : Canary_lang.lang) : inspect_input list =
  let m =
    Option.value mechanism ~default:(Canary_mechanism.mechanism_of_lang_exn l)
  in
  List.concat_map (row_of c).ag.ag_methods ~f:(fun mm ->
      mm.m_inputs
        { ac_mechanism = m; ac_lang = l; ac_world = world; ac_declared = None })

(* ── FACTS IN, CHECKS OUT ──────────────────────────────────────────
   A project declares what it IS — its language, its binding mechanism,
   how each artifact was provisioned. It has no business naming an
   agreement: which checks those facts imply, and what each needs to
   read, is the framework's knowledge. *)

(** Every agreement that applies to a binding with these facts, paired
    with the inputs it would read. [world] is the enumeration's own
    [assignment] — it already records how EVERY artifact was
    provisioned, so nothing here has to choose which provision stands
    for the world. [action] narrows to the checks that fire at one
    action; omit it for all of them. *)
let agreements_for ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(world : Canary_artifact.assignment) ?action ()
    : (agreement_row * inspect_input list) list =
  List.filter_map agreement_registry ~f:(fun r ->
      let firing_methods =
        List.filter r.ag.ag_methods ~f:(fun m ->
            let sites = m.m_firing mechanism lang world in
            match action with
            | None -> not (List.is_empty sites)
            | Some a -> List.exists sites ~f:(fun s -> Poly.equal s a))
      in
      if (not (List.is_empty firing_methods)) && r.ag_enabled then
        Some
          ( r,
            List.concat_map firing_methods ~f:(fun m ->
                m.m_inputs
                  { ac_mechanism = mechanism; ac_lang = lang; ac_world = world;
                    ac_declared = None }) )
      else None)

(* ── the counterexamples, GATHERED ────────────────────────────────
   Each family ships its own (on the method that owns them); this is
   the flat view the layer tests iterate. They execute hermetically —
   no project run — so a new agreement lands WITH its counterexample
   and a changed evaluator breaks the pin. *)

let agreement_fixtures : (agreement_id * checking_method * fixture) list =
  List.concat_map agreement_registry ~f:(fun r ->
      List.concat_map r.ag.ag_methods ~f:(fun m ->
          List.map m.m_counterexamples ~f:(fun fx -> (r.ag_id, m, fx))))

let has_fixture (id : agreement_id) : bool =
  List.exists agreement_fixtures ~f:(fun (i, _, _) -> Poly.equal i id)

(* ── THE FIRING TABLE ─────────────────────────────────────────────
   The registry's motivation made visible: enumerate every
   (agreement × action) cell and give each a STATUS. It is TOTAL by
   construction — every cell has a status, so where an agreement takes
   effect is a table you can read rather than an idea, and "filling it"
   is a concrete list of [Declared] cells.

   Reading the marks:
   - [Wired]        ✓ fires here, is evaluated, and ships a counterexample;
   - [Declared]     ~ fires here and is evaluated, NO fixture yet — the
                      fill list;
   - [Planned]      ⊘ fires here and has no evaluator (reports
                      not_implemented);
   - [Inapplicable] ∅ fires here but this mechanism offers no such claim;
   - [Off]          × switched off in the registry;
   - [Empty]        · does not fire here. *)

type cell_status = Wired | Declared | Planned | Inapplicable_cell | Off | Empty

let mark_of_status = function
  | Wired -> "✓"
  | Declared -> "~"
  | Planned -> "⊘"
  | Inapplicable_cell -> "∅"
  | Off -> "×"
  | Empty -> "·"

(** The table's columns: THE action catalogue, not a copy of it.
    Actions with no cell wired yet still appear — the empty columns ARE
    the picture. *)
let firing_columns (l : Canary_lang.lang) : Canary_basic.action list =
  Canary_basic.actions_of_lang l

(** One cell's status under a concrete world. Consults the enabled flag
    and the method's applicability, which the previous version did not
    — a disabled planned row used to render as [~], the mark that
    means "evaluated, just missing a fixture". *)
let cell_status_of (r : agreement_row) ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(world : Canary_artifact.assignment)
    (a : Canary_basic.action) : cell_status =
  let firing =
    List.filter r.ag.ag_methods ~f:(fun m ->
        List.exists (m.m_firing mechanism lang world) ~f:(fun x -> Poly.equal x a))
  in
  if List.is_empty firing then Empty
  else if not r.ag_enabled then Off
  else
    let applicable =
      List.filter firing ~f:(suits_here ~mechanism ~lang ~declared:None)
    in
    if List.is_empty applicable then Inapplicable_cell
    else if List.for_all applicable ~f:(fun m -> Option.is_none m.m_eval) then
      Planned
    else if
      List.exists applicable ~f:(fun m ->
          Option.is_some m.m_eval && not (List.is_empty m.m_counterexamples))
    then Wired
    else Declared

(** THE firing table: rows = agreements, columns = actions, under one
    world. *)
let firing_table ?(mechanism = Canary_mechanism.Cstubs)
    ?(lang = Canary_lang.OCaml) ?(provision = Canary_store.Built) () :
    (agreement_row * (Canary_basic.action * cell_status) list) list =
  let world = uniform_world ~lang ~mechanism provision in
  List.map agreement_registry ~f:(fun r ->
      ( r,
        List.map (firing_columns lang) ~f:(fun a ->
            (a, cell_status_of r ~mechanism ~lang ~world a)) ))

(** Render the firing table as text (the CLI view). *)
let pp_firing_table ?(mechanism = Canary_mechanism.Cstubs)
    ?(lang = Canary_lang.OCaml) ?(provision = Canary_store.Built) () : string =
  let m = firing_table ~mechanism ~lang ~provision () in
  let cols = firing_columns lang in
  let head =
    Printf.sprintf "%-28s | " "agreement"
    ^ String.concat ~sep:" | "
        (List.map cols ~f:Canary_basic.string_of_action)
  in
  let body =
    List.map m ~f:(fun (r, cells) ->
        Printf.sprintf "%-28s | %s" r.ag_slug
          (String.concat ~sep:" | "
             (List.map cells ~f:(fun (a, st) ->
                  let w = String.length (Canary_basic.string_of_action a) in
                  let mk = mark_of_status st in
                  mk ^ String.make (max 0 (w - 1)) ' '))))
  in
  String.concat ~sep:"\n"
    (head :: body
    @ [ "";
        "✓ evaluated + counterexample   ~ evaluated, no counterexample   \
         ⊘ planned";
        "∅ mechanism offers no such claim   × off in registry   · does not \
         fire here" ])

(** A row's implementation status, DERIVED from its methods rather than
    declared. [Partly] is the state the old single [status] field could
    not express and the audit kept tripping over. *)
type status =
  | Evaluated       (** every method has an evaluator *)
  | Partly          (** some do *)
  | Planned_only    (** none do; it is selected and reports not_implemented *)
  | Off_in_registry
  | Proposed        (** no family implements it at all *)

let string_of_status = function
  | Evaluated -> "evaluated"
  | Partly -> "partly-evaluated"
  | Planned_only -> "planned"
  | Off_in_registry -> "off"
  | Proposed -> "proposed"

let status_of_row (r : agreement_row) : status =
  if not r.ag_enabled then Off_in_registry
  else
    let n = List.length r.ag.ag_methods in
    let impl = List.count r.ag.ag_methods ~f:(fun m -> Option.is_some m.m_eval) in
    if impl = 0 then Planned_only else if impl = n then Evaluated else Partly

(* ── THE RECOVERY GRID (2026-09-17, user) ───────────────────────────

   The firing table above answers *where is this DETECTED*. That is half
   of what theory.md §2 says an agreement is. The other half is where
   the information was LOST — the action whose tool established the
   relation and then threw the tuple away — and the two are usually
   different actions.

   The catalogue carries both, as prose columns: `action`, `tool`,
   `artifact` on the rooting table, and `checked at` beside them. A
   reader has to hold two tables in their head and subtract. Put them on
   ONE row over the action patterns and the subtraction is visual:

     declared_symbols_exported   ...  [R+D] build_lib ...
     required_symbols_exported   ...  [R] build_binding_ocaml ... [D] probe_binding_ocaml

   R and D in one cell is a DISTANCE-0 agreement — both sides of the
   comparison are still present where the rule ran, and it is the
   cheapest and strongest kind. R and D apart is the gap: how far the
   evidence had to travel, and every column between them is an action
   that could have dropped it.

   That makes landing.md's distance-0 backlog readable off the grid
   rather than maintained beside it, which is what the user asked for
   when they said the catalogue's `recovers`/`tool` columns were less
   clear than marking the action.

   **The row is per (agreement × mechanism)**, because both halves move
   with the mechanism: a Ctypes binding compiles no stub, so
   `required_symbols_exported` has no R and no D there at all. *)

type recovery_mark =
  | Rooted_and_detected  (** distance 0 — the rule ran here and the check fires here *)
  | Rooted  (** the tool ran here; the information was lost here *)
  | Detected  (** a method fires here, reading what survived *)
  | Nothing_here

let recovery_mark_char = function
  | Rooted_and_detected -> "◉"
  | Rooted -> "R"
  | Detected -> "D"
  | Nothing_here -> "·"

(** Where an agreement is ROOTED, as an action of THIS graph — or [None]
    when [rt_action] is prose standing in for a link that ran in a world
    canary never modelled. The catalogue already draws that distinction
    by backticking only what parses; this is the same test, used to
    decide whether a row can carry an R at all. *)
let rooted_action_of (r : agreement_row) : Canary_basic.action option =
  let rt = r.ag.ag_rooted_in in
  if not (is_rooted rt) then None
  else Canary_basic.action_of_string rt.rt_action

(** THE RECOVERY GRID: rows = agreements, columns = action patterns,
    cells = rooted / detected / both. *)
(** WHICH MECHANISMS CAN CARRY THIS CLAIM — the catalogue's five, asked
    one at a time (2026-09-17, user: "we can add a few columns … other
    columns for eight cells or mechanism").

    It is the same [suits_here] the result table and the check index
    ask, ranged over the mechanism axis instead of held fixed. A claim
    no mechanism can carry would be dead; one every mechanism carries is
    format- or declaration-gated instead, which is what the other two
    columns are for. *)
let carrying_mechanisms (r : agreement_row) :
    (Canary_mechanism.mechanism * bool) list =
  List.map Canary_mechanism.mechanism_catalogue ~f:(fun i ->
      let m = i.Canary_mechanism.mi_mechanism in
      let lang = i.Canary_mechanism.mi_lang in
      ( m,
        List.exists r.ag.ag_methods
          ~f:(suits_here ~mechanism:m ~lang ~declared:None) ))

(** A compact mechanism mark: the initials of the mechanisms that carry
    it, dotted where they do not. Two characters each would double the
    width for no information — the ORDER is the catalogue's and fixed,
    so position identifies the mechanism. *)
let mechanism_marks (r : agreement_row) : string =
  String.concat ~sep:""
    (List.map (carrying_mechanisms r) ~f:(fun (m, ok) ->
         if not ok then "·"
         else
           match m with
           | Canary_mechanism.Cstubs -> "S"
           | Canary_mechanism.Cext -> "E"
           | Canary_mechanism.Ctypes -> "T"
           | Canary_mechanism.Cffi -> "F"
           | Canary_mechanism.Dynlink -> "D"))

let format_marks (r : agreement_row) : string =
  String.concat ~sep:""
    (List.map all_formats ~f:(fun f ->
         if
           List.exists r.ag_formats ~f:(fun g ->
               Canary_store.equal_object_format f g)
         then match f with Canary_store.Elf -> "E" | Canary_store.Macho -> "M"
         else "·"))

(* ── ONE ROW PER PATTERN, NOT PER AGREEMENT (2026-09-17, user) ──────

   The grid above renders ONE SLICE — a fixed (mechanism, lang,
   provision) — and a `mech` column saying which other mechanisms carry
   the claim. The user's objection is exact: a compact mark is fine when
   the rows would be identical, and a lie when they would not. Firing is
   `mechanism × lang × world`, so a cstubs row and a cext row of the
   same agreement mark DIFFERENT COLUMNS (`build_binding_ocaml` vs
   `build_binding_python`), and collapsing them showed only the first.

   So: group a claim's carrying mechanisms by the pattern they produce,
   and emit one row per group. Uniform claims stay one row and say so in
   the `mech` column; the ones that differ expand, and the expansion IS
   the information.

   FORMAT does not expand, and the asymmetry is worth stating: a format
   changes whether a claim APPLIES, never where it fires. `E·` therefore
   annotates a whole row rather than splitting it — which is why the
   column belongs beside the name rather than at the far end. *)

type overview_row = {
  ov_agreement : agreement_row;
  ov_mechs : Canary_mechanism.mechanism list;
      (** the mechanisms sharing this pattern; [[]] = carried by none,
          and the row is shown anyway, because "no mechanism can carry
          this" is the loudest thing the table can say *)
  ov_reads : Canary_basic.artifact_kind list;
      (** THE ARTIFACTS THE CLAIM RANGES OVER — its target(s), from the
          methods' own [m_inputs] through [artifact_of_input]. A
          DECLARATION is not an artifact and maps to [None], which is
          what makes the declaration group read as a single target. *)
  ov_cells : (Canary_basic.action * recovery_mark) list;
}

(** The action columns: the union over BOTH modelled languages, because
    a row's mechanism decides which half it can mark and the emptiness
    of the other half is the point. *)
let overview_columns () : Canary_basic.action list =
  Canary_basic.store_actions ~langs:Canary_lang.[ OCaml; Python ]

let pattern_of (r : agreement_row) ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(provision : Canary_store.provision) :
    (Canary_basic.action * recovery_mark) list =
  let world = uniform_world ~lang ~mechanism provision in
  let root = rooted_action_of r in
  List.map (overview_columns ()) ~f:(fun a ->
      let is_root =
        match root with Some ra -> Poly.equal ra a | None -> false
      in
      let fires =
        match cell_status_of r ~mechanism ~lang ~world a with
        | Empty -> false
        | _ -> true
      in
      ( a,
        match (is_root, fires) with
        | true, true -> Rooted_and_detected
        | true, false -> Rooted
        | false, true -> Detected
        | false, false -> Nothing_here ))

(** What a claim reads, as artifact kinds, for one mechanism's language.
    Union over its methods; declarations contribute nothing. *)
let reads_of (r : agreement_row) ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(provision : Canary_store.provision) :
    Canary_basic.artifact_kind list =
  let world = uniform_world ~lang ~mechanism provision in
  List.concat_map r.ag.ag_methods ~f:(fun m ->
      List.filter_map
        (m.m_inputs
           { ac_mechanism = mechanism; ac_lang = lang; ac_world = world;
             ac_declared = None })
        ~f:(artifact_of_input ~lang))
  |> List.dedup_and_sort ~compare:Poly.compare

(** THE TABLE: one row per (agreement × distinct pattern). *)
let overview_rows ?(provision = Canary_store.Built) () : overview_row list =
  List.concat_map agreement_registry ~f:(fun r ->
      let carried =
        List.filter_map (carrying_mechanisms r) ~f:(fun (m, ok) ->
            if ok then
              Some (m, (Canary_mechanism.info_of_mechanism m).Canary_mechanism.mi_lang)
            else None)
      in
      match carried with
      | [] ->
          (* no mechanism carries it. Still a row — with the pattern its
             own default language would give, so the reader sees WHAT is
             unreachable rather than a blank. *)
          [ { ov_agreement = r;
              ov_mechs = [];
              ov_reads = [];
              ov_cells =
                pattern_of r ~mechanism:Canary_mechanism.Cstubs
                  ~lang:Canary_lang.OCaml ~provision } ]
      | _ ->
          let with_pattern =
            List.map carried ~f:(fun (m, l) ->
                ( m,
                  pattern_of r ~mechanism:m ~lang:l ~provision,
                  reads_of r ~mechanism:m ~lang:l ~provision ))
          in
          (* group by identical pattern, keeping catalogue order *)
          List.fold with_pattern ~init:[] ~f:(fun acc (m, cells, reads) ->
              match
                List.findi acc ~f:(fun _ (_, c, _) -> Poly.equal c cells)
              with
              | Some (i, (ms, c, rd)) ->
                  List.mapi acc ~f:(fun j x ->
                      if j = i then
                        ( ms @ [ m ], c,
                          List.dedup_and_sort (rd @ reads) ~compare:Poly.compare )
                      else x)
              | None -> acc @ [ ([ m ], cells, reads) ])
          |> List.map ~f:(fun (ms, cells, reads) ->
                 { ov_agreement = r; ov_mechs = ms; ov_reads = reads;
                   ov_cells = cells }))


(** The ARTIFACT columns, in the result matrix's own order — the
    leading "setting" block, reused (2026-09-17, user: "I also wish the
    table can have the leading columns as src/lib as the result
    matrix"). *)
let overview_artifact_columns : Canary_basic.artifact_kind list =
  Canary_basic.
    [ Source; Headers; Lib; Binding Canary_lang.OCaml;
      Binding Canary_lang.Python; App ]

let artifact_col_label (k : Canary_basic.artifact_kind) : string =
  match k with
  | Canary_basic.Source -> "src"
  | Canary_basic.Headers -> "hdr"
  | Canary_basic.Lib -> "lib"
  | Canary_basic.Binding Canary_lang.OCaml -> "ml"
  | Canary_basic.Binding Canary_lang.Python -> "py"
  | Canary_basic.Binding l -> Canary_lang.string_of_lang l
  | Canary_basic.Binding_source l -> Canary_lang.string_of_lang l ^ "src"
  | Canary_basic.App -> "app"

(** Pad to a DISPLAY width, not a byte count. Every mark in this table
    is a multibyte glyph (`▣` is three bytes, `·` two), so [%-3s] pads
    them differently and the columns drift — which is exactly the kind
    of thing a table about precision must not do. *)
let pad_display (n : int) (s : string) : string =
  let width =
    String.fold s ~init:0 ~f:(fun acc c ->
        (* count only the leading byte of a UTF-8 sequence *)
        if Char.to_int c land 0xC0 = 0x80 then acc else acc + 1)
  in
  s ^ String.make (max 0 (n - width)) ' '

(* ── LANG AND MECH, SPELLED OUT (2026-09-17, user: "single letters in
   mech is not reader-friendly … split mech into two columns as lang and
   mech … if it's on ocaml but not mech related, we can leave the mech
   empty").

   The rule that makes the second column meaningful: a mechanism name
   earns its place only when the row is a STRICT SUBSET of its
   language's mechanisms. A row covering every mechanism of OCaml is a
   fact about OCaml, not about cstubs, and writing "cstubs, dynlink"
   there would say something narrower than the truth.

   That is why `behavior_matches` renders as two rows reading `ocaml` /
   `python` with an EMPTY mech: its firing differs by language (a
   different probe action) and not by mechanism at all, which the
   letter-marks could not distinguish from a coincidence. *)

let langs_of_mechs (ms : Canary_mechanism.mechanism list) :
    Canary_lang.lang list =
  List.map ms ~f:(fun m ->
      (Canary_mechanism.info_of_mechanism m).Canary_mechanism.mi_lang)
  |> List.dedup_and_sort ~compare:Poly.compare

let mechs_of_lang (l : Canary_lang.lang) : Canary_mechanism.mechanism list =
  List.filter_map Canary_mechanism.mechanism_catalogue ~f:(fun i ->
      if Poly.equal i.Canary_mechanism.mi_lang l then
        Some i.Canary_mechanism.mi_mechanism
      else None)

(* The languages canary MODELS, read off the mechanism catalogue rather
   than listed here. `Canary_project_analysis.modelled_langs` is the same
   set, but it sits in `project/`, above this layer — and the catalogue
   is where the fact actually lives: a language canary models is one some
   mechanism binds in. *)
let catalogue_langs : Canary_lang.lang list =
  List.map Canary_mechanism.mechanism_catalogue ~f:(fun i ->
      i.Canary_mechanism.mi_lang)
  |> List.dedup_and_sort ~compare:Poly.compare

(** The LANG cell: the languages this row's mechanisms belong to, or
    ["any"] when it spans every modelled language — which is what a
    claim about the LIBRARY looks like, since no binding is involved. *)
let lang_label (ms : Canary_mechanism.mechanism list) : string =
  match langs_of_mechs ms with
  | [] -> ""
  | ls ->
      if List.length ls >= List.length catalogue_langs then "any"
      else String.concat ~sep:"," (List.map ls ~f:Canary_lang.string_of_lang)

(** The MECH cell: empty when the row covers every mechanism of its
    language(s), because then the row is not about a mechanism. *)
let mech_label (ms : Canary_mechanism.mechanism list) : string =
  match langs_of_mechs ms with
  | [] -> ""
  | ls ->
      let covers_all_of l =
        List.for_all (mechs_of_lang l) ~f:(fun m ->
            List.mem ms m ~equal:Poly.equal)
      in
      if List.for_all ls ~f:covers_all_of then ""
      else
        String.concat ~sep:","
          (List.map ms ~f:Canary_mechanism.string_of_mechanism)

(** WHERE THE CODE IS: the family file's topic and the evaluator's name,
    or [None] for the function when no evaluator exists — which the
    renderers show as a RED cell pointing at the file it would go in. *)
let impl_of (r : agreement_row) : string * string option =
  ( family_of r.ag_id,
    List.find_map r.ag.ag_methods ~f:(fun m -> m.m_impl) )

(** The IMPL cell as one string: [family·function], or [family·—] when
    no evaluator exists. The file is [canary_agreement_<family>.ml] —
    spelled out in the legend rather than in every row, because the
    prefix is the same thirteen times and the suffix is the answer. *)
let impl_label (r : agreement_row) : string =
  let family, fn = impl_of r in
  family ^ "·" ^ Option.value fn ~default:"—"

(* `mech_group_marks` lived here — a five-slot `S···D` string, one
   character per catalogue mechanism. It was deleted on 2026-09-17 when
   [lang_label] / [mech_label] replaced it, and the reason is worth
   keeping: the marks were dense but unreadable without the legend, AND
   they could not express the fact the split makes obvious — `S···D` and
   `ocaml`/(empty) are the same set, but only the second says that the
   claim is about the LANGUAGE rather than about two mechanisms that
   happen to agree. A notation that cannot distinguish a rule from a
   coincidence is the wrong notation. *)

(** The lag of ONE rendered row, over its own cells. *)
let row_lag (row : overview_row) : int option =
  let idx_of f =
    List.filter_mapi row.ov_cells ~f:(fun i (_, m) ->
        if f m then Some i else None)
  in
  let roots =
    idx_of (function Rooted | Rooted_and_detected -> true | _ -> false)
  in
  let dets =
    idx_of (function Detected | Rooted_and_detected -> true | _ -> false)
  in
  match (roots, dets) with
  | [], _ | _, [] -> None
  | rs, ds ->
      Some
        (List.fold ds ~init:Int.max_value ~f:(fun best d ->
             List.fold rs ~init:best ~f:(fun best rt ->
                 Int.min best (abs (d - rt)))))

let pp_agreement_overview ?(provision = Canary_store.Built) () : string =
  let rows = overview_rows ~provision () in
  let cols = overview_columns () in
  let head =
    Printf.sprintf "%-4s %-28s %-36s %-7s %-14s %-3s | %s | " "code"
      "agreement" "implemented at" "lang" "mech" "fmt"
      (String.concat ~sep:" "
         (List.map overview_artifact_columns ~f:(fun k ->
              pad_display 3 (artifact_col_label k))))
    ^ String.concat ~sep:" | "
        (List.map cols ~f:Canary_basic.string_of_action)
    ^ " | lag | status"
  in
  let body =
    List.map rows ~f:(fun row ->
        let r = row.ov_agreement in
        Printf.sprintf "%-4s %-28s %s %-7s %-14s %s | %s | %s | %3s | %s"
          (short_code_of_slug r.ag_slug) r.ag_slug
          (pad_display 36 (impl_label r))
          (lang_label row.ov_mechs) (mech_label row.ov_mechs)
          (pad_display 3 (format_marks r))
          (String.concat ~sep:" "
             (List.map overview_artifact_columns ~f:(fun k ->
                  pad_display 3
                    (if List.mem row.ov_reads k ~equal:Poly.equal then "▣"
                     else "·"))))
          (String.concat ~sep:" | "
             (List.map row.ov_cells ~f:(fun (a, mk) ->
                  let w = String.length (Canary_basic.string_of_action a) in
                  pad_display w (recovery_mark_char mk))))
          (match row_lag row with Some d -> Int.to_string d | None -> "-")
          (string_of_status (status_of_row r)))
  in
  String.concat ~sep:"\n"
    (Printf.sprintf "agreement overview — over a %s world"
       (Canary_enumerate.string_of_provision provision)
     :: ""
     :: head :: body
    @ [ "";
        "ONE ROW PER DISTINCT PATTERN. A claim whose firing differs between \
         mechanisms";
        "gets a row each — a cstubs row and a cext row mark different action \
         columns —";
        "and a claim that is uniform stays one row and says so in `mech`.";
        "";
        "▣  an ARTIFACT the claim ranges over (its target). A DECLARATION is \
         not an";
        "   artifact, so a declaration comparison shows exactly one ▣: the \
         thing it is";
        "   about. A peer comparison shows two — provider and consumer.";
        "R  the action whose rule RAN — the ORIGIN, where the information was \
         lost";
        "D  a method FIRES here, reading what survived";
        "◉  both: the check fires at the very action whose rule it recovers";
        "";
        "implemented at — `<family>·<function>` in \
         src/canary/agreement/canary_agreement_<family>.ml.";
        "       `·—` = NO EVALUATOR YET; the family names the file it would \
         go in.";
        "lang = the language(s) whose mechanisms carry this row. `any` = \
         every modelled";
        "       language, which is what a claim about the LIBRARY looks like \
         — no binding";
        "       is involved, so nothing about a binding can narrow it.";
        "mech = the MECHANISM(s), when the row is a strict subset of its \
         language's.";
        "       EMPTY means the row covers every mechanism of its \
         language(s), so the";
        "       claim is a fact about the language and naming a mechanism \
         would say less";
        "       than the truth. A blank lang AND mech = no mechanism carries \
         it at all.";
        "fmt  = which OBJECT FORMAT it can range over: E elf · M mach-o. A \
         format";
        "       changes whether a claim APPLIES, never where it fires — so \
         it annotates";
        "       a row rather than splitting one. `E·` is not a gap: Mach-O \
         has no";
        "       symbol versioning, so a version-node claim has nothing of \
         that kind there.";
        "";
        "lag = action columns between the root and the nearest firing. NOT \
         landing.md's";
        "DISTANCE, which measures how far apart the two SIDES of a \
         comparison are:";
        "required_symbols_exported is distance-1 and lag-0." ])

(** The fill list — every [Declared] cell (fires and is evaluated, but
    no counterexample yet). The concrete answer to "what is left to
    fill". Planned cells are NOT in it: they need an implementation,
    not a fixture. *)
let fill_list ?(mechanism = Canary_mechanism.Cstubs)
    ?(lang = Canary_lang.OCaml) ?(provision = Canary_store.Built) () :
    (agreement_id * Canary_basic.action) list =
  List.concat_map (firing_table ~mechanism ~lang ~provision ())
    ~f:(fun (r, cells) ->
      List.filter_map cells ~f:(fun (a, st) ->
          match st with Declared -> Some (r.ag_id, a) | _ -> None))

(* ── PROPOSED agreements — the catalogue's holes, as data ──────────
   An agreement the doc STATES but no family implements gets a row
   here rather than being absent. The registry then lists its own
   gaps, which is the same principle as the firing table's marks: a
   hole should be visible in the artifact that claims completeness.

   These carry no methods — there is nothing to select or evaluate —
   so they are a separate list that [all_agreements] unions with the
   implemented rows for display and pinning. *)

type proposed = {
  prop_slug : string;
  prop_doc : string;
  prop_claim : string;  (** falsifier-phrased, like [ag_says] *)
  prop_needs : string;  (** what implementing it requires *)
}

(* THE DISTANCE-0 HOLES (2026-09-15, user asked for the plan to live in
   the catalogue rather than in a reply).

   [theory.md] §5 walks every action and states, for each, the
   full-information agreement the real tool established and what
   post-fact checking can recover. Walking that against the registry
   leaves these. They come FIRST in the list because distance 0 — both
   sides still present at the one action — is where the least was lost
   and therefore where checking is cheapest and strongest, while the
   three older proposals below are all distance ≥2.

   Two of them are not speculative at all: z3 already performs §5.7 as
   a hand-listed shell assertion inside its install template
   (`assert_staged`), and §5.1 runs as a `git rev-parse` in a
   postcondition. "Already runs" is NOT "already produces evidence",
   which is why they are proposals rather than lifts — an evaluator
   needs a recorded fact to read, and a shell assert leaves none. *)
let proposed_agreements : proposed list =
  [ { prop_slug = "exports_accounted_for";
      prop_doc = "§5.3";
      prop_claim =
        "every symbol the library exports on its declared surface is \
         accounted for by the project's declaration — the CONVERSE of \
         declared_symbols_exported, which together with it makes the \
         pair an equality rather than an inclusion";
      prop_needs =
        "A DECLARATION KIND THAT DOES NOT EXIST YET. Filed 2026-09-15 as \
         the cheapest proposal — 'both sides are already in hand' — and \
         that was wrong. The two sides are not the same KIND of claim: \
         [native_api.stable_symbols] is a WATCHLIST ('these modern-API \
         symbols must be present', a probe for version drift), not a \
         manifest. sqlite declares 5 and its library exports 272, so the \
         converse would report 267 orphans on the project where \
         declared_symbols_exported is landed. A prefix filter does not \
         save it: all 272 share the prefix. What this needs is for a \
         project to be able to say 'this list is EXHAUSTIVE for this \
         surface', which is a different declaration from the one every \
         project writes today — so this is a spec change, not a free \
         comparator" };
    { prop_slug = "package_contains_declared_files";
      prop_doc = "§5.7";
      prop_claim =
        "the staged package contains every file the recipe said it \
         installs — and the consumer's side of it: what the prefix \
         holds is what a consumer reading the prefix will find";
      prop_needs =
        "a manifest of what the install actually staged, recorded as \
         evidence. z3 asserts exactly this today with a hand-listed \
         `assert_staged` and two shell guards, and declares the \
         pre-#10549 failure as two hand-written substrings; all four \
         retire when the claim has a row" };
    { prop_slug = "source_is_declared_ref";
      prop_doc = "§5.1";
      prop_claim =
        "the source tree a build read is the ref the project declared — \
         an IDENTITY claim, so unlike the relation ones it closes \
         exactly rather than converging";
      prop_needs =
        "the resolved commit RECORDED after the fetch. The check itself \
         already runs as a shell assertion in a check_post, which is \
         precisely why it has no row: there is no evidence file to read" };
    { prop_slug = "build_tree_configured_for_source";
      prop_doc = "§5.2";
      prop_claim =
        "the build tree was configured for THIS source tree and these \
         options — a warm tree configured from another ref answers \
         every later question about the wrong world";
      prop_needs =
        "an inspector over the configure cache (CMakeCache.txt, \
         config.status, dune's env) reducing it to the source path, the \
         ref and the option set" };
    { prop_slug = "signatures_match_debug_info";
      prop_doc = "§5.3";
      prop_claim =
        "the signatures the header declares are the ones the compiled \
         library was built with — the strongest available answer to the \
         type question, since it reads what the compiler recorded \
         rather than what the header says now";
      prop_needs =
        "a DWARF inspector and libraries built with -g. Strictly \
         stronger than signatures_agree, which compares two TEXTS and \
         cannot see a changed struct layout behind an unchanged \
         spelling" };
    { prop_slug = "denotation_stable_across_worlds";
      prop_doc = "§5.6";
      prop_claim =
        "a recorded library identity denotes the SAME implementation in \
         the deploy world as in the build world";
      prop_needs =
        "retain corresponding build/deploy evidence across worlds and \
         define an observable denotation criterion (components.md \
         §5.5.1)" };
    { prop_slug = "no_duplicate_implementation";
      prop_doc = "§5.6";
      prop_claim =
        "the resolved set contains no two identities that are one \
         implementation (alternative spelling), and none that statically \
         absorbs another (containment)";
      prop_needs =
        "the shipped objects' evidence plus an identity/containment \
         policy; symbol overlap alone is a discovery heuristic \
         (components.md §5.5.3)" };
    { prop_slug = "interposition_binds_build_target";
      prop_doc = "§5.6";
      prop_claim =
        "the definition that wins for a shared symbol is the one the \
         consumer was built against";
      prop_needs =
        "a resolved binding trace and an expected-target policy; the \
         recorder supplies evidence, the comparison a verdict \
         (components.md §5.6)" } ]

(* ── the unified view — one list to print, cite and pin ──────────── *)

type entry = {
  e_slug : string;
  e_doc : string;
  e_claim : string;
  e_expects : string;
  e_status : status;
}

(** EVERY agreement canary knows about, implemented or merely stated.
    This is what a catalogue section cites and what the alignment
    harness checks. *)
let all_agreements : entry list =
  List.map agreement_registry ~f:(fun r ->
      { e_slug = r.ag_slug;
        e_doc = r.ag_doc;
        e_claim = r.ag.ag_says;
        e_expects = r.ag.ag_expects;
        e_status = status_of_row r })
  @ List.map proposed_agreements ~f:(fun p ->
        { e_slug = p.prop_slug;
          e_doc = p.prop_doc;
          e_claim = p.prop_claim;
          e_expects = p.prop_needs;
          e_status = Proposed })

(** The registry as a table — `canary checks`.

    Grouped by SUBJECT (2026-09-12, user asked for the categorization).
    The subject is descriptive — nothing dispatches on it — but it is
    what makes the catalogue readable as a catalogue rather than a
    list: the three declaration/requirement pairs sit next to each
    other, and the two unscoped repacking claims sit together at the
    end. The proposals carry no subject, so they group last. *)
let pp_agreements () : string =
  let header =
    Printf.sprintf "%-32s %-8s %-17s %s" "agreement" "doc" "status" "claim"
  in
  let line (e : entry) =
    Printf.sprintf "  %-30s %-8s %-17s %s" e.e_slug e.e_doc
      (string_of_status e.e_status) e.e_claim
  in
  let subject_of slug =
    List.find_map agreement_registry ~f:(fun r ->
        if String.equal r.ag_slug slug then
          Some (string_of_subject r.ag.ag_subject)
        else None)
  in
  let subjects =
    List.filter_map agreement_registry ~f:(fun r ->
        Some (string_of_subject r.ag.ag_subject))
    |> List.dedup_and_sort ~compare:String.compare
  in
  let group name rows =
    match rows with
    | [] -> []
    | rows -> (name ^ ":") :: List.map rows ~f:line
  in
  String.concat ~sep:"\n"
    (header
     :: List.concat_map subjects ~f:(fun subj ->
            group subj
              (List.filter all_agreements ~f:(fun e ->
                   match subject_of e.e_slug with
                   | Some s -> String.equal s subj
                   | None -> false)))
    @ group "proposed"
        (List.filter all_agreements ~f:(fun e ->
             Option.is_none (subject_of e.e_slug))))

(** THE CATALOGUE — every agreement with its reference expectation and
    each of its checking methods: what the method compares, against
    what, where its evidence appears, whether it is implemented, and
    what a pass does not establish. This is the view §7.4 asks for —
    a claim followed from its reference through its comparator to the
    action it runs at. *)
let pp_catalogue () : string =
  let b = Buffer.create 4096 in
  let add fmt = Printf.ksprintf (Buffer.add_string b) fmt in
  List.iter agreement_registry ~f:(fun r ->
      add "%s  [%s]\n" r.ag_slug (string_of_status (status_of_row r));
      add "  subject   %s · %s · %s\n"
        (string_of_subject r.ag.ag_subject)
        (match r.ag.ag_claim with Structural -> "structural" | Behavioral -> "behavioral")
        (string_of_basis r.ag.ag_basis);
      add "  claims    %s\n" r.ag.ag_says;
      add "  against   %s\n" r.ag.ag_expects;
      List.iter r.ag.ag_methods ~f:(fun m ->
          add "  method    %s (%s vs %s) — %s\n" m.m_name
            (string_of_method_kind m.m_kind)
            (string_of_reference m.m_reference)
            (match m.m_eval with
             | Some _ ->
                 Printf.sprintf "implemented, %d counterexample(s)"
                   (List.length m.m_counterexamples)
             | None -> "planned: " ^ m.m_planned);
          add "            fires at %s\n"
            (let sites =
               m.m_firing Canary_mechanism.Cstubs Canary_lang.OCaml
                 (uniform_world ~lang:Canary_lang.OCaml
                    ~mechanism:Canary_mechanism.Cstubs Canary_store.Built)
             in
             if List.is_empty sites then "(nowhere in a built OCaml world)"
             else
               String.concat ~sep:", "
                 (List.map sites ~f:Canary_basic.string_of_action));
          add "            limits: %s\n" m.m_limits);
      add "\n");
  List.iter proposed_agreements ~f:(fun p ->
      add "%s  [proposed]\n" p.prop_slug;
      add "  claims    %s\n" p.prop_claim;
      add "  needs     %s\n\n" p.prop_needs);
  Buffer.contents b

(* ── ONE AGREEMENT, EVERYTHING ─────────────────────────────────────

   "What is api_names_present?" had no single answer (2026-09-12,
   user). The claim was in the family module, the doc anchor and the
   enabled flag on the registry row, the evidence paths behind a
   closure that needed a world to call, the counterexamples inside the
   method, the fault tag used by scenario naming somewhere else again,
   and the effective state only in run logs. Six places for one
   question.

   This is the whole record, generated. Nothing here is written down
   twice: every field is read from the registry, so the answer cannot
   drift from the code that implements it. The one thing it cannot see
   is what actually RAN — [Canary_status] appends that. *)

(** The worlds a record shows evidence paths for: one per language,
    each with that language's default mechanism, everything Built.
    Concrete on purpose — "where does it look" is the question a
    reader has when a method reports [unavailable], and the answer is
    a path, not a closure. *)
let record_worlds : (Canary_lang.lang * Canary_mechanism.mechanism) list =
  List.map [ Canary_lang.OCaml; Canary_lang.Python ] ~f:(fun l ->
      (l, Canary_mechanism.mechanism_of_lang_exn l))

let string_of_input (i : inspect_input) : string =
  let one name ps = name ^ " " ^ String.concat ~sep:" | " ps in
  match i with
  | C_stub ps -> one "compiled-stub summary" ps
  | Native_lib ps -> one "native summary" ps
  | Ocaml_mli ps -> one "OCaml surface" ps
  | Python_attrs ps -> one "Python surface" ps
  | Versioned_exports ps -> one "provider version tags" ps
  | Versioned_req ps -> one "consumer version tags" ps
  | Abi_surface ps -> one "consumer identity + NEEDED" ps
  | Typed_header ps -> one "header signatures" ps
  | Typed_binding_stub ps -> one "stub signatures" ps
  | Typed_binding_user ps -> one "user-level signatures" ps
  | Declared_exports d ->
      "DECLARED exports (" ^ Int.to_string (List.length d) ^ " name(s))"
  | Declared_soname s -> "DECLARED soname " ^ s
  | Declared_version_tags t ->
      "DECLARED version tags (" ^ Int.to_string (List.length t) ^ ")"
  | Staged_lib ps -> one "staged native summary" ps

(** THE record for one agreement, as text. [markdown] switches the
    same content to a doc section so the generated catalogue and the
    CLI cannot say different things. *)
let pp_agreement ?(markdown = false) (r : agreement_row) : string =
  let b = Buffer.create 2048 in
  let add fmt = Printf.ksprintf (Buffer.add_string b) fmt in
  let h2 s = if markdown then add "\n## %s\n\n" s else add "%s\n" s in
  let field k v =
    (* A VALUE MAY CONTAIN `|` and several do: [string_of_input] joins
       alternative evidence paths with it, so an unescaped `reads` row
       rendered as a four-column line inside a two-column table and the
       second path vanished into a cell of its own. *)
    if markdown then
      add "| %s | %s |\n" k
        (String.substr_replace_all v ~pattern:"|" ~with_:"\\|")
    else add "  %-12s %s\n" k v
  in
  let para s = if markdown then add "\n%s\n" s else add "  %s\n" s in
  let sub s = if markdown then add "\n### %s\n\n" s else add "\n  %s\n" s in
  let sub_of md s = if md then add "\n**%s**\n\n" s else add "  %s\n" s in
  h2 r.ag_slug;
  if markdown then add "| | |\n| --- | --- |\n";
  field "subject" (string_of_subject r.ag.ag_subject);
  (* "claim" was this row's label until 2026-09-17, which made it read
     as though the claim were the word "structural". The claim is the
     sentence under `### Claim`; this is what KIND of claim it is. *)
  field "about"
    (match r.ag.ag_claim with
     | Structural -> "structural — artifacts and their fit"
     | Behavioral -> "behavioral — what running it does");
  field "obligation" (string_of_basis r.ag.ag_basis);
  field "status" (string_of_status (status_of_row r));
  field "fault tag" r.ag.ag_fault_tag;
  (* the anchor names a FILE as well as a section now: a bare "§2.2"
     told a reader the number and not where to look *)
  field "why it exists" ("components.md " ^ r.ag_doc);
  (* ONLY WHEN IT IS OFF. Every row ships enabled, so printing "yes"
     thirteen times said nothing; printing "no" would be the news. *)
  if not r.ag_enabled then field "enabled" "no";
  (match r.ag_waiting_on with
   | None -> ()
   | Some w -> field "waiting on" w);
  let bold k v = if markdown then "**" ^ k ^ ":** " ^ v else k ^ ": " ^ v in
  sub "Claim";
  para (bold "Says" r.ag.ag_says);
  para (bold "Held against" r.ag.ag_expects);
  (* WHOSE RULE THIS RECOVERS — theory §2. It is what separates an
     agreement waiting on wiring from one waiting on somebody to state
     a specification, and those read identically without it. *)
  (let rt = r.ag.ag_rooted_in in
   para
     (bold "Recovers"
        (if is_rooted rt then
           Printf.sprintf "%s — %s, over %s. %s" rt.rt_action rt.rt_tool
             rt.rt_artifact rt.rt_note
         else "NO ACTION'S RULE. " ^ rt.rt_note)));
  (* WHERE A READER LOOKS FOR IT — the slot, per language, as the
     result table will label the column. Candidates in preference
     order: the first one this world's chain contains wins, so a
     project that fetches its binding falls through to the probe. *)
  para
    (bold "Checked at"
       (String.concat ~sep:"; "
          (List.map record_worlds ~f:(fun (lang, _) ->
               Printf.sprintf "%s: %s"
                 (Canary_lang.string_of_lang lang)
                 (String.concat ~sep:" → "
                    (List.map (r.ag.ag_slot lang) ~f:string_of_slot))))));
  List.iter r.ag.ag_methods ~f:(fun m ->
      sub ("Method: " ^ m.m_name);
      if markdown then add "| | |\n| --- | --- |\n";
      (* "compares | compare" was the old row, which is a tautology
         wearing a label. Say what the kind MEANS — the same four
         sentences model.md §1.5 tabulates. *)
      field "how"
        (match m.m_kind with
         | Inspect -> "reads one artifact's properties or presence"
         | Compare -> "inspects several artifacts and compares them"
         | Run_tool -> "compiles, links or loads"
         | Run_program -> "runs a probe and inspects its result");
      field "against" (string_of_reference m.m_reference);
      field "implemented"
        (match m.m_eval with Some _ -> "yes" | None -> "no — planned");
      (match m.m_eval with
       | Some _ -> ()
       | None -> field "why not" m.m_planned);
      (* WHERE it looks, per world. The answer to "why unavailable". *)
      List.iter record_worlds ~f:(fun (lang, mech) ->
          let world = uniform_world ~lang ~mechanism:mech Canary_store.Built in
          let sites = m.m_firing mech lang world in
          let applies =
            match m.m_applicable mech lang None with
            | Applicable -> None
            | Inapplicable why -> Some why
          in
          (* @built: the paths below are THIS world's. A Fetched
             binding's inspection sits at its fetch step instead —
             [binding_evidence_tag] reads the provision, so the same
             method reads different paths in different worlds. One
             representative world is shown because listing all of them
             would say the same thing five times. *)
          let key =
            Printf.sprintf "%s/%s@built"
              (Canary_lang.string_of_lang lang)
              (Canary_mechanism.string_of_mechanism mech)
          in
          if List.is_empty sites then field key "does not fire"
          else
            match applies with
            | Some why -> field key ("not applicable — " ^ why)
            | None ->
                field key
                  (Printf.sprintf "fires at %s"
                     (String.concat ~sep:", "
                        (List.map sites ~f:Canary_basic.string_of_action)));
                List.iter
                  (m.m_inputs
                     { ac_mechanism = mech; ac_lang = lang; ac_world = world;
                       ac_declared = None })
                  ~f:(fun i -> field "  reads" (string_of_input i)));
      field "limits" m.m_limits;
      match m.m_counterexamples with
      | [] -> field "counterexamples" "none — nothing shows it can fail"
      | fxs ->
          (* WORKED EXAMPLES, from the counterexamples themselves
             (2026-09-13, user). The fixtures already carry the
             synthetic evidence and the outcome it must reach; printing
             them turns "falsified by violated — tiny_offset" into
             something a reader can follow without opening the source.
             They are generated, so they cannot drift from the cases the
             test suite actually executes. *)
          sub_of markdown "Examples";
          List.iteri fxs ~f:(fun i fx ->
              let n = i + 1 in
              if markdown then (
                add "**%d. reports `%s`**%s\n\n" n fx.fx_outcome
                  (match fx.fx_findings with
                   | [] -> ""
                   | fs -> " — finding: `" ^ String.concat ~sep:"`, `" fs ^ "`");
                (* THE INPUTS, not only the file bodies (2026-09-17,
                   user). A fixture's evidence is an input LIST, and
                   some inputs carry their values inline rather than in
                   a file — `Declared_exports [...]` is one. Printing
                   only `fx_bodies` dropped exactly those, so
                   declared_symbols_exported's two examples rendered as
                   the same JSON twice with different outcomes, and the
                   thing that differed — one has a declaration, the
                   other does not — was invisible. *)
                add "reads: %s\n\n"
                  (match fx.fx_inputs with
                   | [] -> "_nothing_"
                   | ins ->
                       String.concat ~sep:", "
                         (List.map ins ~f:(fun i -> "`" ^ string_of_input i ^ "`")));
                List.iter fx.fx_bodies ~f:(fun (name, body) ->
                    add "`%s`:\n\n```json\n%s\n```\n\n" name
                      (String.strip body));
                if List.is_empty fx.fx_bodies then
                  add "_(no file evidence — that is the case)_\n\n")
              else (
                add "    %d. reports %s%s\n" n fx.fx_outcome
                  (match fx.fx_findings with
                   | [] -> ""
                   | fs -> " — finding: " ^ String.concat ~sep:", " fs);
                List.iter fx.fx_bodies ~f:(fun (name, body) ->
                    add "       %s = %s\n" name
                      (String.concat ~sep:" "
                         (List.filter
                            (String.split_on_chars (String.strip body)
                               ~on:[ ' '; '\n'; '\t' ])
                            ~f:(fun w -> not (String.is_empty w)))));
                if List.is_empty fx.fx_bodies then
                  add "       (no evidence supplied — that is the case)\n")));
  Buffer.contents b

let agreement_named (name : string) : agreement_row option =
  List.find agreement_registry ~f:(fun r -> String.equal r.ag_slug name)

(** THE SUMMARY TABLE — the registry at a glance, sorted by whose rule
    each agreement recovers (2026-09-13, user).

    It is the one view that answers "what is this list, actually?"
    without reading thirteen records: each row names the ACTION whose
    rule ran, the TOOL that applied it, and the ARTIFACT it ranged
    over. Those three came out of one prose sentence, which is why
    [rooting] is a record — a sentence cannot be a column.

    The split at the bottom is the point of the table rather than a
    footnote. An agreement no tool's rule roots is not a check waiting
    on wiring; it is a claim waiting on somebody to say what it means,
    and the two are indistinguishable in a flat list. That the
    unrooted rows are EXACTLY the rows with no evaluator is a finding,
    not a coincidence, and the table is where it shows. *)
(** ONE SUMMARY ROW, rendered by more than one medium (2026-09-14,
    user: "we can just use the same table in both the doc and the
    html"). The generated catalogue prints these as markdown and the
    result page prints them as its key — and the result page NEEDS a
    key, because its check columns are headed by short codes and three
    letters with no legend is a puzzle rather than a table.

    Sharing the rows rather than the rendered text is what keeps the
    two honest: a markdown table pasted into a web page would drift the
    first time either changed. *)
type summary_row = {
  sr_code : string;  (** the short code a narrow column head carries *)
  sr_slug : string;
  sr_action : string;  (** whose rule; "" when no tool's rule roots it *)
  sr_tool : string;
  sr_artifact : string;
  sr_slot : string;  (** where a reader looks for it, OCaml's spelling *)
  sr_status : string;
  sr_note : string;  (** for an unrooted row, why there is no rule *)
}

(** Sorted by the CANONICAL ACTION ORDER (2026-09-14, user), the same
    key the result table's columns use — [Canary_basic.compare_column],
    which moved down to [base/] for exactly this so the two orderings
    could be one. A reader going from this table to that one now finds
    the rows in the same sequence, and an unrooted agreement (no
    action) sorts last rather than wherever the registry happened to
    put it. *)
let summary_rows () : summary_row list =
  let rank (r : agreement_row) =
    match Canary_basic.action_of_string r.ag.ag_rooted_in.rt_action with
    | Some a -> (0, Canary_basic.column_group a, Canary_basic.column_stage a)
    | None -> (1, 0, 0)
  in
  List.stable_sort agreement_registry ~compare:(fun x y ->
      Stdlib.compare (rank x) (rank y))
  |> List.map ~f:(fun r ->
      let rt = r.ag.ag_rooted_in in
      { sr_code = short_code_of_slug r.ag_slug;
        sr_slug = r.ag_slug;
        sr_action = rt.rt_action;
        sr_tool = rt.rt_tool;
        sr_artifact = rt.rt_artifact;
        (* the OCaml slot stands for the row: the actions are
           per-language but the SHAPE is not, and printing both would
           double every cell to say the same thing twice. The record
           prints every language. *)
        sr_slot =
          String.concat ~sep:" → "
            (List.map (r.ag.ag_slot Canary_lang.OCaml) ~f:string_of_slot);
        sr_status = string_of_status (status_of_row r);
        sr_note = rt.rt_note })

let pp_rooting_table_md () : string =
  let b = Buffer.create 4096 in
  let add fmt = Printf.ksprintf (Buffer.add_string b) fmt in
  let rooted_rows, unrooted_rows =
    ( List.filter (summary_rows ()) ~f:(fun r ->
          not (String.is_empty r.sr_action)),
      List.filter (summary_rows ()) ~f:(fun r ->
          String.is_empty r.sr_action) )
  in
  add
    "## What each agreement recovers\n\n\
     Every row is one action's rule, re-derived from what survived it. \
     **Action** is where the rule ran — not where the check fires, which is \
     wherever the evidence lands and is usually later. **Tool** is what \
     applied it; **artifact** is what it ranged over.\n\n\
     A `code-set` action is one THIS graph contains, so the row can be read \
     against `canary paths`. A plain-prose one is not: the link that built a \
     consumer ran in a world this graph never modelled, and \"the link\" is \
     several actions depending on who is linking. Naming those in the action \
     type would be a lie in both directions; drawing them needs the \
     action-unit view, which is deferred in \
     [`backlog.md`](../../backlog.md) §51.\n\n";
  add "| code | agreement | action | tool | artifact | checked at | status |\n";
  add "| --- | --- | --- | --- | --- | --- | --- |\n";
  List.iter rooted_rows ~f:(fun r ->
      (* backtick only what the action type actually parses, so the
         column distinguishes an action in this graph from prose
         standing in for one that is not *)
      let action =
        match Canary_basic.action_of_string r.sr_action with
        | Some _ -> "`" ^ r.sr_action ^ "`"
        | None -> r.sr_action
      in
      add "| `%s` | [`%s`](#%s) | %s | %s | %s | `%s` | %s |\n" r.sr_code
        r.sr_slug r.sr_slug action r.sr_tool r.sr_artifact r.sr_slot
        r.sr_status);
  add
    "\n### Rooted in no action's rule\n\n\
     These %d are not checks waiting on evidence. No toolchain enforces \
     them, so there is no relation to recover — only one to state. They are \
     exactly the rows with no evaluator, which is what tells \"nobody \
     implemented this\" apart from \"nobody has said what it means\".\n\n"
    (List.length unrooted_rows);
  add "| code | agreement | why there is no rule | status |\n";
  add "| --- | --- | --- | --- |\n";
  List.iter unrooted_rows ~f:(fun r ->
      add "| `%s` | [`%s`](#%s) | %s | %s |\n" r.sr_code r.sr_slug r.sr_slug
        r.sr_note r.sr_status);
  Buffer.contents b

(** WHAT IS DONE AND WHAT IS LEFT (2026-09-17, user: "a rewrite for
    catalogue with completed and to-do").

    This was `landing.md`'s per-agreement table, maintained by hand, and
    it had reached the state of listing three agreements twice with
    contradictory verdicts. Generated, it cannot.

    The split it draws is deliberately NOT landed/not-landed — that
    needs run logs, which a build product must not read. It is
    *implemented and unblocked* against *blocked, and here is on what*,
    which is answerable from the registry alone and is the half a
    reader can act on. *)
let pp_todo_table_md () : string =
  let b = Buffer.create 2048 in
  let add fmt = Printf.ksprintf (Buffer.add_string b) fmt in
  let blocked =
    List.filter agreement_registry ~f:(fun r -> Option.is_some r.ag_waiting_on)
  in
  let ready = List.length agreement_registry - List.length blocked in
  add "## What is done, and what is left\n\n";
  add
    "%d of %d agreements are implemented with nothing known in their way. \
     The other %d are blocked, and this is on what. Whether an unblocked \
     one has actually been DECIDED by a real run is `canary checks \
     --landing`'s question, not this file's.\n\n"
    ready (List.length agreement_registry) (List.length blocked);
  if List.is_empty blocked then add "_Nothing is blocked._\n\n"
  else begin
    add "| agreement | status | waiting on |\n";
    add "| --- | --- | --- |\n";
    List.iter blocked ~f:(fun r ->
        add "| [`%s`](#%s) | %s | %s |\n" r.ag_slug r.ag_slug
          (string_of_status (status_of_row r))
          (Option.value r.ag_waiting_on ~default:""));
    add
      "\nThe `planned` rows are exactly the agreements no tool's rule \
       roots (see the second table below). That is not a coincidence: no \
       toolchain enforced the relation, so there is nothing to re-derive \
       and they wait on somebody to STATE a specification rather than on \
       wiring. **Prefer landing a tool-rooted one.**\n\n"
  end;
  Buffer.contents b

(** The generated catalogue: every agreement's full record, as
    markdown. Written to [doc/canary/design/agreement/catalogue.md] and
    pinned against this output, so the document is a build product
    rather than a second copy. *)
let pp_catalogue_md () : string =
  let b = Buffer.create 16384 in
  Buffer.add_string b
    "# The agreement catalogue\n\n\
     **Kind: reference, GENERATED.** The summary table, then one section \
     per agreement with its complete record — claim, obligation, where it \
     looks, what falsifies it, and what a pass does not establish.\n\n\
     Do not edit: regenerate with `make agreement-catalogue`. Everything \
     here comes from the registry, so it cannot drift from the code that \
     implements it.\n\n\
     **What it does NOT show is what actually RAN.** That is a fact about \
     run logs, and a generated file that read logs would change whenever \
     anything ran — so `canary checks --landing` is the live answer to \
     *which are landed*, and this file answers *what each one is and what \
     is in its way*.\n\n\
     Evidence paths are shown for a BUILT world. The world decides where \
     a binding's inspection sits — a Fetched binding's is at its fetch step \
     — so the same method reads different paths in different worlds.\n\n\
     The model these fields belong to is [`model.md`](model.md) §1; \
     why each agreement exists is [`components.md`](components.md), at \
     the anchor its row carries; how to land one is \
     [`landing.md`](landing.md).\n\n";
  Buffer.add_string b (pp_todo_table_md ());
  Buffer.add_string b (pp_rooting_table_md ());
  Buffer.add_string b "\n---\n\n# The records\n";
  List.iter agreement_registry ~f:(fun r ->
      Buffer.add_string b (pp_agreement ~markdown:true r));
  Buffer.add_string b "\n## Proposed\n\nNo family implements these yet.\n\n";
  List.iter proposed_agreements ~f:(fun p ->
      Printf.ksprintf (Buffer.add_string b)
        "### %s\n\n**Claim:** %s\n\n**Needs:** %s\n\n" p.prop_slug p.prop_claim
        p.prop_needs);
  Buffer.contents b
