(** [Canary_agreement] — TIER 3: THE LIST, and everything derived from
    it. Design: [doc/canary/design/agreement/agreements.md].

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
    ("bridge", Canary_agreement_bridge.checks);
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
    row Gate_admits_the_world ~doc:"§5.7";
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
(** THE ROOTING NAMES ONE LANGUAGE, AND A ROW MAY BE ANOTHER'S
    (2026-09-17, user: "the R for python is on build_binding_ocaml
    cell").

    [rt_action] is a STRING, and for a claim that roots at a binding's
    link it has to pick a spelling — `required_symbols_exported` says
    `build_binding_ocaml`. That is the right answer for the cstubs row
    and the WRONG one for the cext row, which marked `R` in the OCaml
    column and then measured its lag from there: 7 columns, when the
    linker that wrote those undefined references ran at
    `build_binding_python`, lag 0.

    The claim is not about OCaml. `ag_rooted_in` says which ACTION the
    rule ran at; which language's instance of that action is a property
    of the row. So the row re-languages it. An action with no language
    in it — `build_lib`, `install_lib` — is returned unchanged, which is
    what makes this safe to apply everywhere. *)
let retarget_action ~(lang : Canary_lang.lang) (a : Canary_basic.action) :
    Canary_basic.action =
  match a with
  | Canary_basic.Build_binding _ -> Canary_basic.Build_binding lang
  | Canary_basic.Probe_binding _ -> Canary_basic.Probe_binding lang
  | Canary_basic.Fetch (Canary_basic.Binding _) ->
      Canary_basic.Fetch (Canary_basic.Binding lang)
  | Canary_basic.Fetch (Canary_basic.Binding_source _) ->
      Canary_basic.Fetch (Canary_basic.Binding_source lang)
  | Canary_basic.Publish (Canary_basic.Binding _) ->
      Canary_basic.Publish (Canary_basic.Binding lang)
  | Canary_basic.Build_app _ -> Canary_basic.Build_app { lang }
  | Canary_basic.Probe_app _ -> Canary_basic.Probe_app { lang }
  | a -> a

let rooted_action_of ?lang (r : agreement_row) : Canary_basic.action option =
  let rt = r.ag.ag_rooted_in in
  if not (is_rooted rt) then None
  else
    Option.map (Canary_basic.action_of_string rt.rt_action) ~f:(fun a ->
        match lang with Some l -> retarget_action ~lang:l a | None -> a)

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

(** THE OBJECT-FORMAT CELL, spelled out and EMPTY when it does not
    narrow (2026-09-17, user: "can we use the full name `elf` or
    `mach-o` to be more clear, and if a check has nothing to do with it,
    do you check the cell is empty. I also think `fmt` is not a good
    column name since it looks too like style format").

    Three changes, one rule. It was `EM` / `E·`: two letter marks that
    needed the legend, and `EM` — the common case, meaning "both, so
    this axis says nothing" — was the LOUDEST thing in the column.

    Now it follows `lang` and `mech`: an empty cell means the axis does
    not narrow the claim. Eleven of thirteen are empty and the two that
    are not say `elf`, which is the whole content of the column. The
    header is `object` rather than `fmt`, which read as a style. *)
let format_marks (r : agreement_row) : string =
  if List.length r.ag_formats >= List.length all_formats then ""
  else
    String.concat ~sep:","
      (List.map r.ag_formats ~f:Canary_store.string_of_object_format)

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

(** AN EXISTING TOOL THAT ANSWERS ONE OF OUR CLAIMS (2026-09-21, user:
    "even a tool is mainly for one agreement claim, I also wish to have
    it as a row … The agreement is sth abstract, while a tool is use to
    check under some implementation").

    The first design put the tool in a FIELD on the agreement, and that
    was wrong for a reason worth keeping: the relation is MANY-TO-MANY.
    `abidiff` answers four of our claims and does more besides, so
    filing it under one loses the rest — the user's objection, and it is
    correct. A row per (tool × claim it answers) keeps the plural, and
    the duplication that produces is honest: `abidiff` appearing four
    times IS the fact that it covers four claims.

    THE ROW IS NAMED AFTER OUR CLAIM, suffixed `_ext`, and sits adjacent
    to it — same kind, same targets, same rooting, because it answers
    the same question. What differs is `implemented at`: ours names a
    function in this tree, an external row names the tool. That column
    generalizes to "who implements this check", which is what makes the
    comparison a side-by-side read rather than two tables.

    ⚠ [xc_beyond] IS THE GUARD AGAINST THE ORIGINAL MISTAKE. A tool
    filed under one claim would still hide its other features, so each
    row says what the tool does that THIS claim does not. Where that
    sentence describes something we have no claim for at all, it is a
    candidate we have not written down — which is the second reason to
    carry these rows: a mature tool is a list of claims someone already
    thought were worth checking. *)
type external_checker = {
  xc_tool : string;  (** the tool, as it is invoked or published *)
  xc_answers : agreement_id;  (** which of our claims it decides *)
  xc_what : string;  (** what it compares, in its own terms *)
  xc_beyond : string;
      (** what it does that our claim does not — the feature we would
          otherwise overlook by filing it under one claim *)
  xc_adoption : string;
      (** the adoption class. Mostly from related/adoption-in-practice.md;
          where a row is NOT from that survey it says so, because the
          paper's comparison is against surveyed checkers and a system
          utility is a different population (2026-09-21, user: "I don't
          treat `ldd` as external research tool"). *)
  xc_langs : Canary_lang.lang list;
      (** THE TOOL'S OWN reach, not the claim's. [[]] = language-
          agnostic, following the table's convention that an empty cell
          does not narrow — `abicompat` reads ELF binaries and has no
          opinion about OCaml, while `auditwheel` is Python only.

          This exists because the first version INHERITED the claim's
          axes (2026-09-21, user: "why do we have lang non-empty for
          these tool rows?"). An external row showed `ocaml cstubs`
          because the claim's first pattern did, which said something
          false about the tool. *)
  xc_formats : Canary_store.object_format list;
      (** likewise the tool's own: libabigail is ELF+DWARF and does not
          read Mach-O, so an empty `object` cell on its row — meaning
          "ranges over both" — was a lie (user: "the object column for
          these tools e.g. abicompact, is empty, but is that only on one
          platform?"). Never empty: a tool that genuinely worked on both
          would list both. *)
}

type overview_row = {
  ov_agreement : agreement_row;
  ov_external : external_checker option;
      (** [None] = our own row. [Some t] = the same claim as answered by
          an EXISTING tool: the claim's kind, targets and rooting are
          reused (it is the same question), and the tool replaces
          `implemented at`. *)
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

(* THE TOOLS THAT ALREADY ANSWER SOME OF THESE CLAIMS.

   Drawn from `research/related/canary-practical-cross-language-bindings-report.md`
   §9, which sketches this mapping in prose, and the adoption classes in
   `research/related/adoption-in-practice.md`. Prose was the right place
   to work it out and the wrong place to keep it: a claim's row should
   say whether somebody already answers it.

   ⚠ WHAT THIS LIST IS FOR, and it is not flattering. Seven of the eight
   LANDED claims have a mature external answerer, and several answer
   better than we do — `abidiff` reads DWARF where `signatures_agree`
   compares two texts. The claims that are uniquely ours are mostly
   still CANDIDATES. Having that on the table rather than in a paper's
   prose is the point: it says which claims to stop deepening and call a
   tool for, and it keeps the gap honest as tools are added.

   NOT MODELLED YET, deliberately, and recorded so it is not mistaken
   for done: a tool's OWN applicability. `auditwheel` is Linux+Python
   while the claim it answers is format-neutral, so an external row
   currently inherits the claim's lang/mech/object rather than stating
   the tool's. And nothing here is RUN — naming a tool is what makes the
   overlap visible; invoking one needs the transport work in
   status.md §2.1. *)
let external_checkers : external_checker list =
  [ { xc_tool = "abicompat (libabigail)";
      xc_answers = Required_symbols_exported;
      xc_what =
        "takes an application and two versions of a library it links \
         against, and reports whether the newer one still satisfies what \
         the application needs";
      xc_beyond =
        "TYPES, not just names. Our claim is the linker's rule \
         re-implemented exactly for symbol NAMES; abicompat reads DWARF \
         and catches a changed struct layout behind an unchanged \
         spelling, which no symbol table can show";
      xc_adoption = "mature specialist infrastructure";
      (* ELF + DWARF. libabigail does not read Mach-O, so this row
         must SAY elf even though the claim it answers is
         format-neutral. Language-agnostic: it reads binaries. *)
      xc_langs = []; xc_formats = [ Canary_store.Elf ] };
    { xc_tool = "abidiff (libabigail)";
      xc_answers = Signatures_agree;
      xc_what =
        "compares two binaries' ABI as recorded in DWARF — function \
         types, struct layout, enum values, symbol versions";
      xc_beyond =
        "STRICTLY STRONGER than this claim, which compares return-type \
         and argument-type STRINGS scanned from source. Everything a \
         text comparison cannot see — padding, size, a typedef that \
         changed underneath — abidiff sees. This is the clearest case \
         for calling a tool rather than deepening ours; the candidate \
         `signatures_match_debug_info` is that plan";
      xc_adoption = "mature specialist infrastructure";
      xc_langs = []; xc_formats = [ Canary_store.Elf ] };
    { xc_tool = "abidiff (libabigail)";
      xc_answers = Required_versions_exported;
      xc_what =
        "reports symbol-version changes between two builds of a library";
      xc_beyond =
        "it compares two LIBRARY builds; our claim compares a consumer's \
         recorded requirements against one provider. Different pairing, \
         overlapping evidence — and abidiff also reports the type \
         changes that motivated the version bump";
      xc_adoption = "mature specialist infrastructure";
      xc_langs = []; xc_formats = [ Canary_store.Elf ] };
    { xc_tool = "abicheck";
      xc_answers = Declared_symbols_exported;
      xc_what =
        "checks an artifact's exported surface against what its \
         consumers require, across a whole set rather than one pairing";
      xc_beyond =
        "it has no notion of a project's DECLARATION — the half that \
         makes our claim a promise rather than a pairing. Too new for \
         established adoption, so it is a comparison target rather than \
         something to depend on";
      xc_adoption = "emerging tool";
      (* ⚠ formats ASSERTED, not verified: the ABI-checking
         tools in this space are ELF, and the survey says only
         that abicheck is too new for established adoption.
         Narrow it if that turns out wrong. *)
      xc_langs = []; xc_formats = [ Canary_store.Elf ] };
    { xc_tool = "ldd -r";
      xc_answers = Dependencies_provided;
      xc_what =
        "resolves a binary's recorded dependencies and reports the ones \
         that do not resolve, including undefined symbols";
      xc_beyond =
        "IT ACTUALLY LOADS. Our claim reasons about RECORDED \
         dependencies and never asks the loader — the role-3 gap written \
         up at `native_lib_probe_cmd`. A library can pass every static \
         check here and fail to load, and this is the cheapest tool that \
         would notice";
      xc_adoption =
        "system utility — NOT from the related-work survey (2026-09-21, \
         user: \"I don't treat `ldd` as external research tool\"). Kept \
         because its BEYOND is the most useful line here, and marked \
         because the paper's comparison is against surveyed checkers";
      xc_langs = []; xc_formats = [ Canary_store.Elf ] };
    { xc_tool = "auditwheel";
      xc_answers = Dependencies_provided;
      xc_what =
        "`auditwheel show` lists the external shared libraries a Python \
         wheel depends on and the manylinux policy it satisfies";
      xc_beyond =
        "POLICY and REPAIR. It judges against a published platform \
         policy rather than against this world's providers, and it can \
         vendor the libraries in — changing the artifact, which no claim \
         of ours does. Python + Linux only";
      xc_adoption = "production infrastructure";
      (* Python wheels on Linux — both axes real, both were
         being inherited from the claim before. *)
      xc_langs = [ Canary_lang.Python ];
      xc_formats = [ Canary_store.Elf ] };
    { xc_tool = "abi3audit";
      xc_answers = Repack_preserves_api;
      xc_what =
        "scans Python packages for violations of the Stable ABI they \
         claim to target";
      xc_beyond =
        "it checks a claim the PACKAGE makes about itself, which is a \
         narrower and more decidable question than `repack_preserves_api` \
         — and the reason that claim is unimplemented is exactly that \
         nobody has stated its scope. abi3audit's scope is stated for \
         it, by PEP 384";
      xc_adoption = "real but specialized";
      (* Python-specific but format-agnostic: it reads wheels,
         which exist for every platform. *)
      xc_langs = [ Canary_lang.Python ];
      xc_formats = all_formats };
    { xc_tool = "rpminspect";
      xc_answers = Staged_interface_preserved;
      xc_what =
        "compares a built RPM against its predecessor, including \
         artifact-level inspections of the installed payload";
      xc_beyond =
        "it compares two RELEASES; ours compares a build tree against \
         its own staged copy in one run. And it carries dozens of other \
         inspections — permissions, licences, changelogs — which is what \
         a distribution needs and a checker of bindings does not";
      xc_adoption = "production distribution QA";
      xc_langs = []; xc_formats = [ Canary_store.Elf ] } ]

(** The action columns: the union over BOTH modelled languages, because
    a row's mechanism decides which half it can mark and the emptiness
    of the other half is the point. *)
let overview_columns () : Canary_basic.action list =
  Canary_basic.store_actions ~langs:Canary_lang.[ OCaml; Python ]

let pattern_of (r : agreement_row) ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(provision : Canary_store.provision) :
    (Canary_basic.action * recovery_mark) list =
  let world = uniform_world ~lang ~mechanism provision in
  let root = rooted_action_of ~lang r in
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
      List.concat_map
        (m.m_inputs
           { ac_mechanism = mechanism; ac_lang = lang; ac_world = world;
             ac_declared = None })
        ~f:(artifacts_of_input ~lang))
  |> List.dedup_and_sort ~compare:Poly.compare

(* ── ROW ORDER: WHEN IT FIRES, THEN WHOSE (2026-09-17, user: "we also
   need a better order for the agreement, and the spirit is the same as
   the result columns … first rank on the D moment, then for the same D
   moment, sorting on lang and mech").

   Registry order was declaration order, which is a fact about the
   source file and about nothing else. Ordering by the FIRING moment
   makes the table read the way a run happens: everything decided at
   `build_lib` together, then the binding's build, then its probe. That
   is the result table's own principle — a column's place is its
   lifecycle stage — applied to rows.

   The key is the index of the EARLIEST `D`, in the table's own column
   order, so the table sorts itself by what it displays. A row that
   fires nowhere sorts last rather than first: `Int.max_value` is the
   honest key for "never", and putting it at the top would give the
   most prominent position to the least active claim. Ties break on
   language then mechanism, both in catalogue order, so a claim's cstubs
   and cext rows stay adjacent and in a stable order. *)
(** The earliest action where a method of this row FIRES. [ov_cells] is
    in column order, so the first hit is the earliest. *)
let first_firing_action (row : overview_row) : Canary_basic.action option =
  List.find_map row.ov_cells ~f:(fun (a, m) ->
      match m with Detected | Rooted_and_detected -> Some a | _ -> None)

(* THE TRIGGER IS THE ACTION, NOT THE ACTION-IN-A-LANGUAGE (2026-09-17,
   user: "we shall first sort on trigger action, which you did well,
   then we will group the same agreement").

   Those two instructions only compose if the trigger is language-free.
   The column list is the union over both languages and puts every OCaml
   action before every Python one, so `required_symbols_exported` fires
   at column 9 as cstubs and column 16 as cext — seven columns apart,
   with six other agreements in between. Sorting on that spreads one
   claim across the table and no later key can pull it back together.

   So the key is the trigger action with its language normalized away:
   both rows rank at `build_binding`, and the agreement — the next key —
   then puts them side by side. The table reads as "here is what fires
   when the binding is built, claim by claim, and for each claim the
   mechanisms that carry it", which is the grouping asked for. *)
let trigger_index (row : overview_row) : int =
  match first_firing_action row with
  | None -> Int.max_value
  | Some a -> (
      let abstract = retarget_action ~lang:Canary_lang.OCaml a in
      match
        List.findi (overview_columns ()) ~f:(fun _ c -> Poly.equal c abstract)
      with
      | Some (i, _) -> i
      | None -> Int.max_value)

(* Both ranks come off the mechanism catalogue, which is the one
   declared order this layer has — a language ranks by where its first
   mechanism appears. [langs_of_mechs] and [catalogue_langs] say the
   same thing but are defined below, with the label functions they
   serve. *)
let lang_rank (l : Canary_lang.lang) : int =
  match
    List.findi Canary_mechanism.mechanism_catalogue ~f:(fun _ i ->
        Poly.equal i.Canary_mechanism.mi_lang l)
  with
  | Some (i, _) -> i
  | None -> 99

let mech_rank (m : Canary_mechanism.mechanism) : int =
  match
    List.findi Canary_mechanism.mechanism_catalogue ~f:(fun _ i ->
        Poly.equal i.Canary_mechanism.mi_mechanism m)
  with
  | Some (i, _) -> i
  | None -> 99

(* WHAT WORKS COMES FIRST (2026-09-17, user: "I am also think whether we
   can put the un-landed agreement at the bottom rows of this table").

   An agreement with no evaluator sorts below every implemented one,
   whatever it fires at. It is the primary key rather than a tiebreak
   because the table's first job is to say what canary CAN check, and
   `repack_complete` sitting between two working claims at the same
   action reads as though it were one of them.

   The split is REGISTRY-level, not log-level — "has an evaluator", not
   "has decided something in a real run". Landing is a fact about run
   logs, and this table is generated from the registry alone so that it
   does not change whenever anything runs; `canary checks --landing` is
   the log-level answer. So the bottom block is the 3 unimplemented
   claims, not the 5 unlanded ones. *)
let is_planned (row : overview_row) : bool =
  List.for_all row.ov_agreement.ag.ag_methods ~f:(fun m ->
      Option.is_none m.m_eval)

let sort_overview_rows (rows : overview_row list) : overview_row list =
  let key (row : overview_row) =
    ( (if is_planned row then 1 else 0),
      trigger_index row,
      (* THE AGREEMENT, before language and mechanism: one claim's rows
         stay together, and the mechanisms that carry it read as its
         variants rather than as separate entries that happen to share a
         name. *)
      row.ov_agreement.ag_slug,
      (* ALL OF OUR PATTERNS FIRST, then the tools that answer the same
         claim — so the comparison reads downward: here is what we
         check, in every mechanism that carries it; here is who else
         checks it. Putting this key AFTER language would interleave a
         tool between a claim's own OCaml and Python rows. *)
      (match row.ov_external with None -> (0, "") | Some x -> (1, x.xc_tool)),
      (match row.ov_mechs with
       | m :: _ ->
           lang_rank (Canary_mechanism.info_of_mechanism m).Canary_mechanism.mi_lang
       | [] -> 99),
      (match row.ov_mechs with m :: _ -> mech_rank m | [] -> 99) )
  in
  List.stable_sort rows ~compare:(fun a b -> Poly.compare (key a) (key b))

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
              ov_external = None;
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
                 { ov_agreement = r; ov_external = None; ov_mechs = ms;
                   ov_reads = reads; ov_cells = cells }))
  (* THE EXISTING TOOLS, one row per (tool × claim it answers). Each
     reuses the claim's FIRST pattern — same kind, same targets, same
     rooting, because it is the same question — and differs in
     `implemented at`, which names the tool instead of one of our
     functions. Sorting puts it next to the claim it mirrors, which is
     what makes the comparison a side-by-side read. *)
  |> fun ours ->
  ours
  @ List.filter_map external_checkers ~f:(fun xc ->
        List.find ours ~f:(fun row ->
            Poly.equal row.ov_agreement.ag_id xc.xc_answers)
        |> Option.map ~f:(fun row -> { row with ov_external = Some xc }))
  |> sort_overview_rows


(** THE AGREEMENTS IN THE TABLE'S ORDER — each one at the position of
    its FIRST row, so a document that walks them walks the overview
    top to bottom. An agreement with several patterns has several rows
    and one record, so the mapping is first-row, not one-to-one. *)
let registry_in_table_order ?(provision = Canary_store.Built) () :
    agreement_row list =
  let seen = ref [] in
  List.filter_map (overview_rows ~provision ()) ~f:(fun row ->
      let s = row.ov_agreement.ag_slug in
      if List.mem !seen s ~equal:String.equal then None
      else (
        seen := s :: !seen;
        Some row.ov_agreement))

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

(** AN EMPTY CELL MEANS "THIS AXIS DOES NOT NARROW THE CLAIM", in BOTH
    columns (2026-09-17, user: "how do you mean by `any` or an empty
    cell? can we just use empty cell").

    `lang` said `any` and `mech` said nothing, which spelled ONE relation
    two ways — and `any` read like a third language value, sitting as it
    does in a column of `ocaml` / `python`. It is not a language; it is
    the absence of a restriction, which is what a blank says.

    That leaves the THIRD state needing a word of its own, because it
    had been sharing the blank: no mechanism carries this row at all.
    It is the loudest thing the table can say, so it may not look like
    the most ordinary one. *)
let nothing_carries = "none"

(** The LANG cell: the languages this row's mechanisms belong to, EMPTY
    when it spans every modelled language — which is what a claim about
    the LIBRARY looks like, since no binding is involved. *)
let lang_label (ms : Canary_mechanism.mechanism list) : string =
  match langs_of_mechs ms with
  | [] -> nothing_carries
  | ls ->
      if List.length ls >= List.length catalogue_langs then ""
      else String.concat ~sep:"," (List.map ls ~f:Canary_lang.string_of_lang)

(** The MECH cell: empty when the row covers every mechanism of its
    language(s), because then the row is not about a mechanism. *)
let mech_label (ms : Canary_mechanism.mechanism list) : string =
  match langs_of_mechs ms with
  | [] -> nothing_carries
  | ls ->
      let covers_all_of l =
        List.for_all (mechs_of_lang l) ~f:(fun m ->
            List.mem ms m ~equal:Poly.equal)
      in
      if List.for_all ls ~f:covers_all_of then ""
      else
        String.concat ~sep:","
          (List.map ms ~f:Canary_mechanism.string_of_mechanism)

(** WHERE THE CLAIM COMES FROM — the KIND cell (2026-09-17, user: "I
    would like to have the agreement kind on the table, on where the
    agreement comes from … we still have standalone agreement e.g. a
    native binary shouldn't contain local path if it's to installed").

    It was already modelled and never shown: [m_reference] names the
    SECOND PARTY a method compares against, which is exactly "where the
    claim comes from" —

      declaration    the project said so
      peer           the other artifact in this world says so
      artifact       nothing says so; it is the format's own rule, and
                     there is no second party at all
      sibling-world  evidence kept from another world says so
      test-suite     an upstream suite's expected results say so

    NOT to be confused with the ORIGIN, which the action columns carry.
    The origin is WHICH ACTION's rule ran; the kind is WHAT THE CLAIM IS
    HELD AGAINST. A declaration comparison whose origin produced its
    target is theory.md §5.11's top-left group — "is the thing you made
    what you said it would be" — and that group is the INTERSECTION of
    the two axes, not either one of them.

    ⚠ Today every one of the 13 is `declaration` or `peer`. The other
    three kinds are declared in the type and used by nothing, which the
    column makes visible: `artifact` in particular is the standalone
    well-formedness claim — an installed library carrying a RUNPATH into
    the build tree it was made in is wrong on its own terms, against no
    declaration and no peer — and it has no agreement. *)
let kind_label (r : agreement_row) : string =
  string_of_agreement_kind r.ag.ag_kind

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

(** THE ROW'S NAME. Ours is the claim's slug; an external row is the
    same slug suffixed `_ext`, so the two sort and read adjacent and a
    reader can tell at a glance which is the abstract claim and which is
    somebody's implementation of it. *)
let row_slug (row : overview_row) : string =
  match row.ov_external with
  | None -> row.ov_agreement.ag_slug
  | Some _ -> row.ov_agreement.ag_slug ^ "_ext"

(** WHO IMPLEMENTS THIS CHECK — the column that carries the whole
    difference between our row and a tool's. Ours names a function in
    this tree; an external row names the tool. *)
let row_impl_label (row : overview_row) : string =
  match row.ov_external with
  | None -> impl_label row.ov_agreement
  | Some x -> x.xc_tool

(* THE AXIS CELLS COME FROM WHOEVER IMPLEMENTS THE ROW (2026-09-21,
   user: "why do we have lang non-empty for these tool rows?" and "the
   object column for these tools e.g. abicompact, is empty, but is that
   only on one platform?").

   Both were bugs, and the same bug: an external row inherited the
   CLAIM's pattern, so it showed `ocaml cstubs` because the claim's
   first pattern did, and an empty `object` — meaning "ranges over both
   formats" — because the claim ranges over both. Neither said anything
   true about the tool. abicompat has no opinion about OCaml and cannot
   read Mach-O; auditwheel is Python and Linux.

   The convention is unchanged and now applies to the tool: an empty
   cell means that axis does not narrow THIS ROW. For our rows the
   narrowing is the claim's; for a tool's row it is the tool's. *)
let row_lang_label (row : overview_row) : string =
  match row.ov_external with
  | None -> lang_label row.ov_mechs
  | Some x ->
      if List.is_empty x.xc_langs then ""
      else
        String.concat ~sep:","
          (List.map x.xc_langs ~f:Canary_lang.string_of_lang)

(** A tool is not mechanism-specific in any way this table models — it
    reads artifacts, not bindings — so the cell is empty rather than
    borrowing the claim's. *)
let row_mech_label (row : overview_row) : string =
  match row.ov_external with
  | None -> mech_label row.ov_mechs
  | Some _ -> ""

let row_format_label (row : overview_row) : string =
  match row.ov_external with
  | None -> format_marks row.ov_agreement
  | Some x ->
      if List.length x.xc_formats >= List.length all_formats then ""
      else
        String.concat ~sep:","
          (List.map x.xc_formats ~f:Canary_store.string_of_object_format)

(** An external row has not run here, so it has no status of ours. *)
let row_status_label (row : overview_row) : string =
  match row.ov_external with
  | None -> string_of_status (status_of_row row.ov_agreement)
  | Some _ -> "external"

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
    Printf.sprintf "%-4s %-32s %-14s %-36s %-7s %-14s %-7s | %s | " "code"
      "agreement" "kind" "implemented at" "lang" "mech" "object"
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
        Printf.sprintf "%-4s %-32s %-14s %s %-7s %-14s %s | %s | %s | %3s | %s"
          (match row.ov_external with
           | None -> short_code_of_slug r.ag_slug
           | Some _ -> short_code_of_slug r.ag_slug ^ "*")
          (row_slug row) (kind_label r)
          (pad_display 36 (row_impl_label row))
          (row_lang_label row) (row_mech_label row)
          (pad_display 7 (row_format_label row))
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
          (row_status_label row))
  in
  String.concat ~sep:"\n"
    (Printf.sprintf "agreement overview — over a %s world"
       (Canary_enumerate.string_of_provision provision)
     :: ""
     (* THE KIND GLOSSARY GOES FIRST (2026-09-21, user: "can we prepend
        the kind explanation"). `kind` is the column a reader has no
        prior vocabulary for — every other one is a name, a file, a
        language or a mark — so meeting the six words after three
        screens of rows is meeting them too late. The detailed prose
        that used to sit in the trailing legend moved HERE rather than
        being copied: one place, before the data that uses it. *)
     :: "ROW ORDER  trigger action, then agreement, then language, then \
         mechanism —"
     :: "           so a claim's mechanisms sit together. Unimplemented \
         claims sort last."
     :: "code       the AGREEMENT's identity, so a repeated code is ONE \
         claim with"
     :: "           several patterns, shown adjacent. It is the key to \
         the result"
     :: "           table's check-column headings."
     :: "one row    per distinct PATTERN: a claim whose firing differs \
         between mechanisms"
     :: "           gets a row each; a uniform claim stays one row and \
         leaves `mech` empty."
     :: "▣          an ARTIFACT the claim ranges over — its target. A \
         declaration is not"
     :: "           an artifact, which is why some claims show one."
     :: "R · D · ◉  R = the action whose rule RAN; D = a method FIRES \
         here; ◉ = both."
     :: "           A row with no R roots in no action of this graph."
     :: "impl. at   `<module>·<function>` — the EVALUATOR, in \
         canary_agreement_<module>.ml."
     :: "           `·—` = none yet, and the module names the file it \
         would go in. The"
     :: "           agreement's METADATA is `let <slug> : agreement` in \
         the same file;"
     :: "           `canary checks --agreement NAME` prints it as \
         `declared at`."
     :: "lang mech  an EMPTY cell means that axis does not narrow the \
         claim — every"
     :: "object     modelled language, every mechanism of this row's \
         language, or every"
     :: "           object format. A value appears only where the row is \
         a strict subset;"
     :: "           `none` in lang and mech = no mechanism carries this \
         at all."
     :: "lag        action columns from the root to the nearest firing. \
         NOT the distance"
     :: "           between the two SIDES of a comparison, which is a \
         different measure."
     (* `kind` is the one column with no prior vocabulary, so it gets
        the glossary immediately above the table rather than a line
        here. A pointer, so the legend is still a complete list. *)
     :: "kind       what the claim ASSERTS — the six values are glossed \
         just below,"
     :: "           next to the table that uses them."
     :: "`_ext` rows an EXISTING TOOL that answers the same claim — same \
         kind, same"
     :: "           targets, same rooting, because it is the same \
         question. The code"
     :: "           carries `*` and `implemented at` names the tool \
         instead of one of"
     :: "           our functions. `decided` and `blame` are empty: \
         nothing here has run"
     :: "           it. One row per (tool × claim), so a tool answering \
         four claims"
     :: "           appears four times — the duplication IS the fact \
         that it covers"
     :: "           four. The table below the candidates says what each \
         does BEYOND"
     :: "           our claim, which is what filing a tool under one \
         claim would hide."
     :: ""
     :: "Why the table is shaped this way — the row-order key, why a \
         code repeats, why an"
     :: "empty cell is the right notation, why the rooting is \
         re-languaged per row — is"
     :: "doc/canary/design/matrix.md. One note that belongs here \
         because it misleads in"
     :: "the cell: `soname` is an ELF word for a format-neutral fact, \
         the library's own"
     :: "recorded identity — `DT_SONAME` on ELF, the `LC_ID_DYLIB` \
         install name on Mach-O,"
     :: "which the inspector writes into one field. Those claims are \
         NOT elf-only; the two"
     :: "version-node ones are."
     :: ""
     :: "KIND — what the claim ASSERTS. Not what it is held against \
         (the record's `against`),"
     :: "       and not whose rule it recovers (that is the R column)."
     :: "  admissibility  would ONE action have accepted these artifacts \
         together as its"
     :: "                 inputs? theory.md §2's `R_A` — the tuples a \
         rule accepts."
     :: "  promise        is this ONE artifact what its own producer \
         said it would be?"
     :: "  quality        is it sound on its own terms, whatever it is \
         paired with?"
     :: "  preservation   still the same thing after a transformation — \
         two COPIES of one"
     :: "                 artifact, so no disagreement between distinct \
         components can"
     :: "                 violate it."
     :: "  behaviour      does running it produce what was specified?  \
         composition — a"
     :: "                 verdict over other verdicts."
     :: ""
     :: "  `api_names_present` is an ADMISSIBILITY claim one of whose \
         members is a"
     :: "  DECLARATION — the watchlist stands in for the application's \
         uses. Naming the"
     :: "  evidence is not the same as naming the claim, which is why \
         `kind` and the"
     :: "  record's `against` are two fields."
     :: ""
     :: head :: body
    @ [ "" ])


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

(** WHY A PROPOSAL HAS NO ROW IN THE AGREEMENT OVERVIEW (2026-09-17,
    user: "I am thinking if we can group the agreement out-of-table in
    one place … which I can see them together").

    The eight proposals were ONE flat list, so the catalogue printed
    them as eight of a kind. They are not. Four are held up by a schema
    field; three the per-action model does not reach AT ALL, and
    [theory.md] §7 already says which; one has never been filed. That is
    four different kinds of work, and a reader deciding what to do next
    was being asked to re-derive the split from prose in three
    documents.

    So the reason is DATA now, and the grouping is generated from it.
    Pinned against the theory doc by
    [agreements.theory_names_the_frame_exclusions] — the model and the
    registry must name the same exclusions, or one of them is lying. *)
type frame_fit =
  | In_frame
      (** the per-action frame REACHES this claim; what is missing is
          that [proposed] carries no rooting and no target list, so
          there is nothing to put in the R and ▣ columns. A schema
          change, and it costs the row's meaning — [lag], decided and
          blame are undefined without a firing *)
  | Outside_the_frame of string
      (** [theory.md] §7: the model has no vocabulary for it. Set
          properties and cross-world properties are not per-edge, so
          §6's procedure will never find them and they need their own
          reasoning *)
  | Not_an_agreement of string
      (** [theory.md] §7.1: it recovers CANARY'S OWN rule, which makes
          it a world assertion — "this run tested something other than
          what it says" — rather than a finding about the software *)
  | Unfiled of string
      (** nobody has applied §7.1's filter to it. Distinct from the
          three above because it is an open QUESTION, not an answer,
          and it should not sit in a list looking like a peer *)

type proposed = {
  prop_slug : string;
  prop_doc : string;
  prop_claim : string;  (** falsifier-phrased, like [ag_says] *)
  prop_needs : string;  (** what implementing it requires *)
  prop_frame : frame_fit;  (** why it is not on the overview *)
  prop_kind : agreement_kind;
      (** WHAT IT WOULD ASSERT (2026-09-17, user: "we know their name,
          kind well, but no concrete ideas how to implement them yet").

          A candidate's kind is knowable long before its evidence is,
          which is exactly why it belongs on the candidate table: it
          says what sort of claim is missing. Three of the five kinds
          have no implemented agreement, and it is the candidates that
          would fill them — the first [Quality] claim and the first
          [Behaviour] one are both here. *)
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
  [ { prop_kind = Promise;
      prop_slug = "exports_accounted_for";
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
         comparator";
      prop_frame = In_frame };
    { prop_kind = Promise;
      prop_slug = "package_contains_declared_files";
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
         retire when the claim has a row";
      prop_frame = In_frame };
    { prop_kind = Promise;
      prop_slug = "source_is_declared_ref";
      prop_doc = "§5.1";
      prop_claim =
        "the source tree a build read is the ref the project declared — \
         an IDENTITY claim, so unlike the relation ones it closes \
         exactly rather than converging";
      prop_needs =
        "the resolved commit RECORDED after the fetch. The check itself \
         already runs as a shell assertion in a check_post, which is \
         precisely why it has no row: there is no evidence file to read";
      prop_frame =
        Not_an_agreement
          "it recovers CANARY'S OWN rule, not a toolchain's. \"Is the tree \
           at the commit we said\" is not a claim about the project's \
           artifacts; it is a claim about whether this run realized the \
           world it says it tested — which fails differently and is read \
           by different people. Canary already has a vocabulary for it: \
           the world assertions. The CHECK is worth having; the row is in \
           the wrong register" };
    { prop_kind = Admissibility;
      prop_slug = "build_tree_configured_for_source";
      prop_doc = "§5.2";
      prop_claim =
        "the build tree was configured for THIS source tree and these \
         options — a warm tree configured from another ref answers \
         every later question about the wrong world";
      prop_needs =
        "an inspector over the configure cache (CMakeCache.txt, \
         config.status, dune's env) reducing it to the source path, the \
         ref and the option set";
      prop_frame =
        Unfiled
          "theory.md §7.1's filter has never been applied to this one, and \
           it looks \
           like it falls the same way as source_is_declared_ref: \"was the \
           tree configured for the source we said\" has the same shape as \
           \"is the tree at the commit we said\". If so it is a world \
           assertion too. Nobody has decided, so it is not filed as either" };
    { prop_kind = Admissibility;
      prop_slug = "signatures_match_debug_info";
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
         spelling";
      prop_frame = In_frame };
    { prop_kind = Preservation;
      prop_slug = "denotation_stable_across_worlds";
      prop_doc = "§5.6";
      prop_claim =
        "a recorded library identity denotes the SAME implementation in \
         the deploy world as in the build world";
      prop_needs =
        "retain corresponding build/deploy evidence across worlds and \
         define an observable denotation criterion (components.md \
         §5.5.1)";
      prop_frame =
        Outside_the_frame
          "a CROSS-WORLD property. It compares two worlds, so there is no \
           single action whose relation it recovers — it is a claim about \
           two runs of one action, and the per-action model has no \
           vocabulary for that" };
    { prop_kind = Quality;
      prop_slug = "no_duplicate_implementation";
      prop_doc = "§5.6";
      prop_claim =
        "the resolved set contains no two identities that are one \
         implementation (alternative spelling), and none that statically \
         absorbs another (containment)";
      prop_needs =
        "the shipped objects' evidence plus an identity/containment \
         policy; symbol overlap alone is a discovery heuristic \
         (components.md §5.5.3)";
      prop_frame =
        Outside_the_frame
          "a SET property. It is about the whole resolved set rather than \
           about any one pairing, and nothing in the per-action model \
           speaks about sets" };
    (* ── NAMED, KIND KNOWN, NO IMPLEMENTATION IDEA (2026-09-17, user:
       "we know their name, kind well, but no concrete ideas how to
       implement them yet").

       These four had no row anywhere: three are the explorations in
       `directions.md` and the fourth is the user's own standalone
       example. They are proposals in exactly the sense the others are —
       a claim with a falsifier and no evaluator — and keeping them in a
       separate document meant the catalogue understated what is known
       to be missing. The candidate table is what they are for.

       Note that two of them are the FIRST of their kind: the RUNPATH
       claim would be the first `Quality`, and the correspondence one
       the first `Behaviour` with an oracle. Three of the six kinds have
       no implemented agreement, and this is where they would come
       from. *)
    { prop_kind = Quality;
      prop_slug = "no_build_paths_in_installed_library";
      prop_doc = "§6.1";
      prop_claim =
        "a library that is installed records no path into the tree it \
         was built in — no RUNPATH, RPATH or embedded reference that \
         resolves only on the machine that produced it. It is wrong ON \
         ITS OWN TERMS: against no declaration and no peer, whatever it \
         is later paired with";
      prop_needs =
        "NOTHING NEW TO RECORD — `inspect_native.py` already emits \
         `runpath` and `rpath`, and canary already knows a world's build \
         directory, which is the other half of the comparison. What it \
         needs is the POLICY: which paths are legitimate in an installed \
         artifact ($ORIGIN and @loader_path are, an absolute build path \
         is not, a system prefix is arguably fine) and whether a \
         relocatable-but-absolute prefix counts. Cheapest candidate on \
         this list, and the first of its kind";
      prop_frame = In_frame };
    { prop_kind = Promise;
      prop_slug = "compatibility_version_satisfied";
      prop_doc = "§4.1";
      prop_claim =
        "on Mach-O, the provider's `compatibility_version` is at least \
         what the consumer recorded — dyld's own gate, which has no ELF \
         counterpart";
      prop_needs =
        "nothing recorded and nothing derived: `inspect_native.py` has \
         extracted `compatibility_version` and `current_version` from \
         LC_ID_DYLIB since the macOS port and NO agreement reads either. \
         Written evidence with no reader. What blocks it is REPORTING, \
         not evidence — `canary checks --landing` is platform-blind, so \
         an agreement landed only on macOS would read as landed \
         everywhere (platform.md §6)";
      prop_frame = In_frame };
    { prop_kind = Behaviour;
      prop_slug = "correspondence_holds_across_the_binding";
      prop_doc = "§6.3.2";
      prop_claim =
        "an operation performed through the binding agrees with the same \
         operation performed directly against the C library — including \
         over SEQUENCES, where state makes the interesting cases";
      prop_needs =
        "a GENERATOR and a new action, not a comparator. Distinct from \
         `behavior_matches` in the one way that matters: it needs no \
         project-supplied expectation, because the C side IS the oracle \
         and canary already builds it. The generator is per-framework \
         (`c_api.functions` is the pairing, the positional convention \
         the argument mapping); a translation of a project's own suite \
         is per-project and can come later. See directions.md §2";
      prop_frame = In_frame };
    { prop_kind = Admissibility;
      prop_slug = "package_resolution_suffices";
      prop_doc = "§5.8";
      prop_claim =
        "the SAME consumer source, built by naming only the binding \
         PACKAGE, does what it does when every input is named by path. \
         Two programs, one source, two resolutions — and where they \
         disagree the package is at fault and the code is not, which no \
         other check in the registry can separate";
      prop_needs =
        "nothing new to record, and the axis already exists: \
         `runner_spec.probe_binding` is a (lang × LOCATION × command) \
         list, so a package-resolved probe is another entry with \
         `Pm (Lang_pm _)` as its location. z3 already runs both — \
         `probe_binding_ocaml` against the build tree and \
         `probe_binding_ocaml_opam` against the published package, both \
         compiling `canary/examples/z3/z3_example.ml`. What is missing is \
         (a) the lift being DERIVED rather than hand-written per project, \
         (b) something holding the two to one source, and (c) this claim \
         comparing their outcomes. ⚠ THE ESCAPE IS THE FINDING: where a \
         package cannot resolve the native library and the environment \
         has to settle it (ocaml-torch reaching libtorch through a \
         variable), that is this claim VIOLATED, not inapplicable — a \
         declared override is the project admitting the recipe is \
         insufficient, and recording it as a violation is the only way it \
         stays counted";
      prop_frame = In_frame };
    (* ── THE BRIDGE'S CLAIMS (2026-09-23, status.md §2.7 E) ──────────

       A bridge between package managers makes three statements, and a
       run now RECORDS all three for zarith's world (the bridge step's
       record): the binding package depends on it, it names a system
       package, and its check accepts the system. Each is a claim with
       both sides in hand — placeholders in the registry, as the user
       asked, drawn as candidate badges on the bridge edges. Three are
       the claims `package_gates.md` §6 proposed and never entered here;
       the fourth, the depext one, came out of recording the bridge.
       The first of them to get a comparator, `gate_admits_the_world`,
       left this list for the registry on 2026-09-27
       (`canary_agreement_bridge.ml`). *)
    { prop_kind = Promise;
      prop_slug = "declared_gate_matches_package";
      prop_doc = "§5.7";
      prop_claim =
        "the gate the project DECLARES for its binding (pm_gate) is the \
         one the binding package's own metadata states: the same bridge \
         package, with the same constraint. A declaration compared with a \
         declaration — package_gates.md §7.3 asks whether that deserves \
         an agreement's status";
      prop_needs =
        "a comparator: the bridge record keeps the binding package's \
         `depends` as opam prints it and whether it names the bridge; \
         what is missing is reading the constraint out of it and \
         comparing both with the declared gate. package_gates.md §7.2 \
         asks whether this belongs to the offline spec audit instead";
      prop_frame = In_frame };
    { prop_kind = Promise;
      prop_slug = "gate_bounds_the_library";
      prop_doc = "§5.7";
      prop_claim =
        "a version bound the binding package puts on its bridge really \
         bounds the C LIBRARY — the bridge's check enforces a version — \
         rather than the packaging of the check: conf-libffi's 2.0.0 is \
         the conf package's revision while libffi is 3.x. Measured at 13 \
         of 370 conf packages (surveys/conf_packages.md §G1a)";
      prop_needs =
        "the predicate is RECORDED (the bridge record keeps its text and \
         the pkg-config invocation, including any --atleast-version); \
         what is missing is the version-domain model the user deferred \
         (status.md §2.7 E, version transport) — today one declared bool, \
         tracks_lib";
      prop_frame = In_frame };
    { prop_kind = Admissibility;
      prop_slug = "depext_names_the_provided_package";
      prop_doc = "§5.7";
      prop_claim =
        "the system package the bridge maps to (its depexts, as opam \
         evaluates them for this platform) is the system package the world \
         provisions the library from — the symbolic path lands where the \
         artifact path is. opam's depext machinery would have installed \
         the one it names; canary installs the one the project declares";
      prop_needs =
        "a comparator over recorded facts: the bridge record's depexts \
         and the owner of the capability file its check found, against \
         the lib row's declared system package. Both sides exist for \
         zarith (libgmp-dev, libgmp-dev)";
      prop_frame = In_frame };
    { prop_kind = Admissibility;
      prop_slug = "discovery_matches_link";
      prop_doc = "§5.3";
      prop_claim =
        "the object a discovery mechanism ACCEPTED is the object the \
         link resolved, and the object the loader finds. Three resolvers \
         — `pkg-config` at solve time, the linker's search at build \
         time, RUNPATH at run time — and nothing checks that they agreed";
      prop_needs =
        "the first resolver's answer is now RECORDED where a bridge is: \
         the bridge step keeps what pkg-config answered for the \
         predicate's module, library directory included (zarith only, \
         2026-09-23). What is missing is the comparison with the library \
         the link resolved, and the answer everywhere else. Its falsifier \
         already exists as a written-up finding — the ncurses/libtinfo \
         report, where identical sonames, symbols and version nodes \
         segfaulted because two prefixes answered differently. ⚠ Open \
         question it raises: it roots in no toolchain's rule (nothing \
         ENFORCES the three agreeing) yet it has an oracle (run both \
         resolvers and compare), so it asks whether `rooted` should mean \
         a tool ENFORCED it or a tool ANSWERED it. See directions.md §1";
      prop_frame = In_frame };
    { prop_kind = Admissibility;
      prop_slug = "interposition_binds_build_target";
      prop_doc = "§5.6";
      prop_claim =
        "the definition that wins for a shared symbol is the one the \
         consumer was built against";
      prop_needs =
        "a resolved binding trace and an expected-target policy; the \
         recorder supplies evidence, the comparison a verdict \
         (components.md §5.6)";
      prop_frame = In_frame } ]

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
      (* WHY IT IS NOT ON THE OVERVIEW — the same four groups the
         catalogue's "Out of the table" section prints, one line each,
         so the terminal and the doc do not say different things. *)
      add "  no row    %s\n"
        (match p.prop_frame with
         | In_frame ->
             "the frame reaches it; a proposal carries no rooting or targets"
         | Unfiled _ -> "NOT FILED — theory §7.1's filter never applied"
         | Not_an_agreement _ ->
             "not an agreement — it recovers canary's own rule (theory §7.1)"
         | Outside_the_frame _ ->
             "outside the per-action frame (theory §7)");
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
  | Bridge_record ps -> one "bridge record" ps

(** THE record for one agreement, as text. [markdown] switches the
    same content to a doc section so the generated catalogue and the
    CLI cannot say different things. *)
let pp_agreement ?(markdown = false) ?(depth = 0) (r : agreement_row) : string =
  let b = Buffer.create 2048 in
  let add fmt = Printf.ksprintf (Buffer.add_string b) fmt in
  (* [depth] pushes every heading down a level. The records used to be
     the only `##`s in their file; spliced into a numbered document they
     sit under one, and a record heading at the same level as the part
     that contains it makes the table of contents lie. *)
  let hashes n = String.make (n + depth) '#' in
  let h2 s = if markdown then add "\n%s %s\n\n" (hashes 2) s else add "%s\n" s in
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
  let sub s = if markdown then add "\n%s %s\n\n" (hashes 3) s else add "\n  %s\n" s in
  let sub_of md s = if md then add "\n**%s**\n\n" s else add "  %s\n" s in
  h2 r.ag_slug;
  if markdown then add "| | |\n| --- | --- |\n";
  (* WHAT IT ASSERTS, first — it is the coarsest thing about a claim and
     it was missing from the record entirely, so the overview's `kind`
     column had no per-agreement explanation to point at. *)
  field "asserts" (string_of_agreement_kind r.ag.ag_kind);
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
  (* WHERE THE METADATA IS (2026-09-17, user: "we shall also track that
     the metadata of an agreement should also be in the code"). The
     overview's `implemented at` names the EVALUATOR; this names the
     record — kind, subject, claim, rooting, methods — which is code
     too, and which a reader asking "why does this say pairing" needs.

     Derived, not stored: every agreement binds to a value named exactly
     its slug in its family file, which
     `agreements.metadata_is_declared_under_its_slug` holds true. A
     field would be a second place to get it wrong. *)
  field "declared at"
    (Printf.sprintf "%s, as `let %s : agreement`" (family_file_of r.ag_id)
       r.ag_slug);
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
    "### What each agreement recovers\n\n\
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
  add "### What is done, and what is left\n\n";
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

(* ── THE ROW AUDIT (2026-09-17, user: "I plan to check all the
   agreement which declared to be landed from the table, based on all
   the cells to ensure each cell is correct. I wish we can make a
   harness somewhere so you can check on your own … we can write it
   down and revise it continuously").

   The overview says a lot per row and most of it is derived, which
   means most of it can be WRONG in a way no build error catches: a kind
   that does not match what the row's targets show, an `implemented at`
   naming a function that moved, an object-format cell that narrows
   nothing and says so anyway.

   These are the laws the cells must satisfy, as data. Each is a NAME, a
   sentence saying what it requires, and a function returning the
   complaint when a row breaks it. That shape is the point: the list is
   meant to grow, `canary checks --audit` prints it as a report, and
   `agreements.rows_obey_their_own_laws` fails the build on any
   violation, so a rule added here is enforced without touching a test.

   A rule belongs here when it relates two cells of ONE row. Facts about
   a single cell (does this function exist, is this doc anchor real) are
   ordinary pins; facts across rows (is a claim's target count stable)
   are too. This list is for "these two columns must agree". *)

type row_rule = {
  rr_name : string;
  rr_says : string;  (** the law, in one sentence *)
  rr_check : overview_row -> string option;
      (** [None] = the row obeys it; [Some complaint] = it does not *)
}

let n_targets (row : overview_row) : int = List.length row.ov_reads

let references (row : overview_row) (f : reference -> bool) : bool =
  List.exists row.ov_agreement.ag.ag_methods ~f:(fun m -> f m.m_reference)

let row_rules : row_rule list =
  [ { rr_name = "kind_matches_target_count";
      rr_says =
        "an ADMISSIBILITY claim ranges over two artifacts, unless one \
         member of its tuple is a declaration standing in for an \
         artifact; a PROMISE over exactly one; BEHAVIOUR and COMPOSITION \
         over none";
      rr_check =
        (fun row ->
          let n = n_targets row in
          let says what =
            Some
              (Printf.sprintf "%s is %s but shows %d target(s) — %s"
                 row.ov_agreement.ag_slug
                 (string_of_agreement_kind row.ov_agreement.ag.ag_kind)
                 n what)
          in
          match row.ov_agreement.ag.ag_kind with
          | Admissibility ->
              (* THE `api_names_present` CASE, which the user asked
                 about: an admissibility claim is about a TUPLE, and ▣
                 counts ARTIFACT targets, so a member of the tuple that
                 is a DECLARATION contributes none. The watchlist stands
                 in for the application's uses, so that row is one
                 artifact and two members. Any other one-target
                 admissibility claim is a real complaint.

                 The law reads `n = 2` because every tuple in the
                 catalogue is a pair today; `R_A` is n-ary, so the day a
                 three-input claim lands this becomes `n >= 2`. Left
                 strict on purpose — an unexpected arity should be
                 looked at rather than waved through. *)
              if n = 2 then None
              else if n = 1 && references row (function
                                | Declared_facts -> true
                                | _ -> false)
              then None
              else
                says
                  "an admissibility claim needs two members; one target \
                   is only honest when another member is a declaration"
          | Promise -> if n = 1 then None else says "a promise is about one artifact"
          | Behaviour | Composition ->
              if n = 0 then None
              else says "its evidence is an execution or other verdicts, not an artifact"
          | Quality -> if n = 1 then None else says "a quality claim is about one artifact"
          | Preservation ->
              (* one KIND, two instances — ▣ counts kinds, so a
                 preservation claim comparing two copies of a library
                 shows one. Zero means it ranges over nothing, which
                 for an unimplemented row is the honest state. *)
              if n <= 1 then None else says "two copies of one artifact is one KIND") };
    { rr_name = "promise_is_held_against_a_declaration";
      rr_says =
        "a PROMISE compares an artifact with what the project declared, \
         so some method of it must reference Declared_facts";
      rr_check =
        (fun row ->
          match row.ov_agreement.ag.ag_kind with
          | Promise
            when not
                   (references row (function
                     | Declared_facts -> true
                     | _ -> false)) ->
              Some
                (Printf.sprintf
                   "%s is a promise but no method references a declaration"
                   row.ov_agreement.ag_slug)
          | _ -> None) };
    { rr_name = "object_format_narrows_or_is_empty";
      rr_says =
        "the object column is EMPTY unless the claim is restricted to \
         fewer formats than exist — an axis that does not narrow says \
         nothing";
      rr_check =
        (fun row ->
          let r = row.ov_agreement in
          let narrows = List.length r.ag_formats < List.length all_formats in
          let shown = not (String.is_empty (format_marks r)) in
          if Bool.equal narrows shown then None
          else
            Some
              (Printf.sprintf
                 "%s declares %d of %d formats but its object cell is %s"
                 r.ag_slug (List.length r.ag_formats)
                 (List.length all_formats)
                 (if shown then "not empty" else "empty"))) };
    { rr_name = "an_evaluator_is_named";
      rr_says =
        "a row with an evaluator names it in `implemented at`, and a \
         row without one shows no function — the red cell must mean \
         what it says (OUR rows: an external row names a tool)";
      rr_check =
        (fun row ->
          (* SCOPE, stated in the law rather than in the runner. This
             one is about OUR implementation; an external row names a
             tool and is never red. Before 2026-09-21 the runner
             skipped external rows wholesale, which is how their own
             errors went unchecked. *)
          if Option.is_some row.ov_external then None
          else
          let r = row.ov_agreement in
          let has_eval =
            List.exists r.ag.ag_methods ~f:(fun m -> Option.is_some m.m_eval)
          in
          match (has_eval, snd (impl_of r)) with
          | true, None ->
              Some
                (Printf.sprintf
                   "%s has an evaluator but names none — the overview \
                    would show it as unimplemented"
                   r.ag_slug)
          | false, Some f ->
              Some
                (Printf.sprintf
                   "%s names the evaluator %s but has none wired" r.ag_slug f)
          | _ -> None) };
    { rr_name = "external_reach_is_declared_and_possible";
      rr_says =
        "a tool's row states the TOOL's reach, not the claim's: at \
         least one object format, and neither a format nor a language \
         the claim it answers cannot have";
      rr_check =
        (fun row ->
          match row.ov_external with
          | None -> None
          | Some x ->
              let claim = row.ov_agreement in
              let bad_fmt =
                List.filter x.xc_formats ~f:(fun f ->
                    not
                      (List.exists claim.ag_formats
                         ~f:(Canary_store.equal_object_format f)))
              in
              let carried =
                List.filter_map (carrying_mechanisms claim) ~f:(fun (m, ok) ->
                    if ok then
                      Some
                        (Canary_mechanism.info_of_mechanism m)
                          .Canary_mechanism.mi_lang
                    else None)
              in
              let bad_lang =
                List.filter x.xc_langs ~f:(fun l ->
                    not (List.mem carried l ~equal:Poly.equal))
              in
              if List.is_empty x.xc_formats then
                Some
                  (Printf.sprintf
                     "%s (%s) declares no object format — an empty cell \
                      would read as `both`, which is what the bug was"
                     claim.ag_slug x.xc_tool)
              else if not (List.is_empty bad_fmt) then
                Some
                  (Printf.sprintf
                     "%s (%s) claims a format the claim does not range \
                      over: %s"
                     claim.ag_slug x.xc_tool
                     (String.concat ~sep:","
                        (List.map bad_fmt ~f:Canary_store.string_of_object_format)))
              else if not (List.is_empty bad_lang) then
                Some
                  (Printf.sprintf
                     "%s (%s) claims a language no mechanism carries the \
                      claim in: %s"
                     claim.ag_slug x.xc_tool
                     (String.concat ~sep:","
                        (List.map bad_lang ~f:Canary_lang.string_of_lang)))
              else None) };
    { rr_name = "a_row_does_something";
      rr_says =
        "every row is either rooted somewhere or fires somewhere; a row \
         that is neither describes a claim no action can reach";
      rr_check =
        (fun row ->
          let any f = List.exists row.ov_cells ~f:(fun (_, m) -> f m) in
          let rooted =
            any (function Rooted | Rooted_and_detected -> true | _ -> false)
          in
          let fires =
            any (function Detected | Rooted_and_detected -> true | _ -> false)
          in
          if rooted || fires then None
          else
            Some
              (Printf.sprintf "%s neither roots nor fires at any action"
                 row.ov_agreement.ag_slug)) } ]

(* ── SATURATION (2026-09-17, user: "if currently we target ocaml and
   python with their mechanism, and consider the c side provider on
   platform elf and machos, can we also let the harness to ensure the
   row saturation (no missing check even it's not implement). currently
   this is no check for mach-o on the table").

   The row laws ask whether a row is self-consistent. This asks a
   question no row can: is any part of the modelled world UNWATCHED?

   The world canary models here is a product of two declared axes — the
   consumer's MECHANISM (the catalogue's five, across two languages) and
   the provider's OBJECT FORMAT (elf, mach-o). Ten cells. A cell with no
   claim is a combination canary can enumerate, build and run while
   checking nothing about it, and nothing else in the tool would say so:
   the overview is organised by claim, so an absence has no row to
   appear in.

   ⚠ TWO DIFFERENT EMPTINESSES, and only one is a hole. A cell is
   covered when some claim can be carried by that mechanism AND ranges
   over that format. `declared_versions_exported` is elf-only, so it
   covers (cstubs, elf) and not (cstubs, mach-o) — that is not a gap,
   because Mach-O genuinely has no symbol versioning. The gap is a cell
   NOTHING covers.

   The asymmetry the user names is finer than the grid and is reported
   under it: two claims are specific to ELF and NONE is specific to
   Mach-O, although Mach-O has a version gate with no ELF counterpart
   (`compatibility_version` in LC_ID_DYLIB, which `inspect_native.py`
   has extracted since the macOS port and no agreement reads). The grid
   cannot see that — every cell is covered by the format-neutral claims
   — which is exactly why it is said in words underneath. *)

let saturation_grid () :
    (Canary_mechanism.mechanism * (Canary_store.object_format * int * int) list)
    list =
  List.map Canary_mechanism.mechanism_catalogue ~f:(fun i ->
      let m = i.Canary_mechanism.mi_mechanism in
      ( m,
        List.map all_formats ~f:(fun f ->
            let carried r =
              List.exists (carrying_mechanisms r) ~f:(fun (m', ok) ->
                  ok && Poly.equal m' m)
            in
            let ranges r =
              List.exists r.ag_formats ~f:(Canary_store.equal_object_format f)
            in
            let here = List.filter agreement_registry ~f:(fun r -> carried r && ranges r) in
            let implemented =
              List.count here ~f:(fun r ->
                  List.exists r.ag.ag_methods ~f:(fun mm ->
                      Option.is_some mm.m_eval))
            in
            (f, List.length here, implemented)) ))

(** The cells of (mechanism × object format) that NO claim covers. *)
let saturation_holes () :
    (Canary_mechanism.mechanism * Canary_store.object_format) list =
  List.concat_map (saturation_grid ()) ~f:(fun (m, cells) ->
      List.filter_map cells ~f:(fun (f, total, _) ->
          if total = 0 then Some (m, f) else None))

(** How many claims are SPECIFIC to one format — the asymmetry the grid
    cannot show, because a format-neutral claim covers every cell. *)
let format_specific (f : Canary_store.object_format) : string list =
  List.filter_map agreement_registry ~f:(fun r ->
      match r.ag_formats with
      | [ g ] when Canary_store.equal_object_format g f -> Some r.ag_slug
      | _ -> None)

let pp_saturation () : string =
  let b = Buffer.create 2048 in
  let add fmt = Printf.ksprintf (Buffer.add_string b) fmt in
  add
    "saturation — is any (mechanism × object format) cell unwatched?\n\n\
    \  cells are `covered/implemented`; a claim covers a cell when that \
     mechanism\n\
    \  can carry it and it ranges over that format.\n\n";
  add "  %-10s" "mechanism";
  List.iter all_formats ~f:(fun f ->
      add " %-10s" (Canary_store.string_of_object_format f));
  add "\n";
  List.iter (saturation_grid ()) ~f:(fun (m, cells) ->
      add "  %-10s" (Canary_mechanism.string_of_mechanism m);
      List.iter cells ~f:(fun (_, total, impl) ->
          add " %-10s" (Printf.sprintf "%d/%d" total impl));
      add "\n");
  let holes = saturation_holes () in
  add "\n";
  if List.is_empty holes then
    add "  no unwatched cell: every mechanism × format has some claim.\n"
  else
    List.iter holes ~f:(fun (m, f) ->
        add "  UNWATCHED: %s × %s has no claim at all\n"
          (Canary_mechanism.string_of_mechanism m)
          (Canary_store.string_of_object_format f));
  add "\n  format-specific claims — the asymmetry the grid cannot show:\n";
  List.iter all_formats ~f:(fun f ->
      let s = format_specific f in
      add "    %-8s %s\n"
        (Canary_store.string_of_object_format f)
        (if List.is_empty s then "none"
         else String.concat ~sep:", " s));
  add
    "\n  A format with NO specific claim is not automatically a gap — it \
     is one\n\
    \  only where that format has something the other lacks. Mach-O \
     does: the\n\
    \  `compatibility_version` gate in LC_ID_DYLIB, which \
     inspect_native.py has\n\
    \  extracted since the macOS port and no agreement reads. It is in \
     the\n\
    \  candidate table, unimplemented.\n";
  Buffer.contents b

(** Run every rule over every row. [[]] = the table obeys its own
    laws. *)
let audit_rows ?(provision = Canary_store.Built) () : (string * string) list =
  (* EVERY ROW (2026-09-21, user: "why doesn't our agreement table
     checker find these errors?").

     It used to filter external rows out here, and that is exactly why
     it found none of them: the exemption was written in the same commit
     that introduced the rows, justified by the five laws that existed
     at the time, and became a blanket skip that no later law could see
     past. A checker whose scope excludes the new thing reports success
     about it forever.

     Now the audit runs over everything and each LAW states its own
     scope — the ones about our implementation return [None] for an
     external row, visibly, in one line each. Adding a law now covers
     external rows unless it says otherwise, which is the right default. *)
  List.concat_map (overview_rows ~provision ()) ~f:(fun row ->
      List.filter_map row_rules ~f:(fun rule ->
          Option.map (rule.rr_check row) ~f:(fun c -> (rule.rr_name, c))))

(** THE TABLE'S OWN VERDICT, in one line (2026-09-21, user: "I recall we
    are doing a harness or checking, how about the checking result").

    The audit and the saturation grid both printed their findings BELOW
    the table and only in the terminal, so the web page — the view the
    table is actually read in — never said whether the table had been
    checked at all. A harness whose result is invisible is a harness
    nobody trusts.

    One line, beside the table in both views: how many laws ran, whether
    any row broke one, and whether any part of the modelled world is
    unwatched. The detail stays in the report below; this is the
    answer. *)
let overview_verdict () : string =
  let bad = audit_rows () in
  let holes = saturation_holes () in
  let laws =
    if List.is_empty bad then
      Printf.sprintf "%d laws, every row obeys them" (List.length row_rules)
    else
      Printf.sprintf "%d laws, %d VIOLATION(S)" (List.length row_rules)
        (List.length bad)
  in
  let sat =
    if List.is_empty holes then "no unwatched mechanism × format cell"
    else Printf.sprintf "%d UNWATCHED cell(s)" (List.length holes)
  in
  Printf.sprintf "checked: %s · %s" laws sat

(** The audit as a report — the laws, then what breaks them. *)
let pp_row_audit () : string =
  let b = Buffer.create 4096 in
  let add fmt = Printf.ksprintf (Buffer.add_string b) fmt in
  let rows = overview_rows () in
  add "agreement overview — row audit (%d rows, %d laws)\n\n"
    (List.length rows) (List.length row_rules);
  List.iter row_rules ~f:(fun r -> add "  %-34s %s\n" r.rr_name r.rr_says);
  let bad = audit_rows () in
  add "\n";
  if List.is_empty bad then
    add "every row obeys every law.\n"
  else (
    add "%d violation(s):\n" (List.length bad);
    List.iter bad ~f:(fun (n, c) -> add "  [%s] %s\n" n c));
  add
    "\nA law relates two CELLS of one row. Single-cell facts (does this \n\
     function exist, does this anchor resolve) are ordinary pins; so are \n\
     facts across rows. Add one to `row_rules` and it is enforced.\n";
  Buffer.contents b

(** THE CANDIDATE TABLE (2026-09-17, user: "I didn't see the rows for
    the candidated agreements in the table. you can have another simple
    table with just names, agreements, kinds and reasons or plans").

    Deliberately NOT the overview's shape. The overview's columns —
    targets, origin, firing, lag — are all derived from METHODS, and a
    candidate has none, so every one of them would be blank and the row
    would say less than a sentence does. Four columns instead: what it
    is called, what kind of claim it is, what it claims, and what stands
    between it and a row.

    The KIND is the column that earns the table. A candidate's kind is
    knowable long before its evidence is, so the table says which SORTS
    of claim canary is missing — and three of the six kinds have no
    implemented agreement at all, which is a fact about the catalogue
    that nothing else reports. *)
let pp_candidate_table () : string =
  let b = Buffer.create 4096 in
  let add fmt = Printf.ksprintf (Buffer.add_string b) fmt in
  add "candidate agreements — named, kind known, no evaluator (%d)\n\n"
    (List.length proposed_agreements);
  add "%-38s %-13s %s\n" "name" "kind" "what stands in the way";
  List.iter proposed_agreements ~f:(fun p ->
      add "%-38s %-13s %s\n" p.prop_slug
        (string_of_agreement_kind p.prop_kind)
        (match p.prop_frame with
         | In_frame -> "an evaluator, and the evidence it reads"
         | Unfiled _ -> "NOT FILED — is it even an agreement? (theory §7.1)"
         | Not_an_agreement _ ->
             "not an agreement: it recovers canary's own rule"
         | Outside_the_frame _ -> "outside the per-action frame (theory §7)"));
  add "\nOne line each; the claim and the full plan are in the catalogue.\n";
  let implemented =
    List.map agreement_registry ~f:(fun r ->
        string_of_agreement_kind r.ag.ag_kind)
    |> List.dedup_and_sort ~compare:String.compare
  in
  let candidate_only =
    List.map proposed_agreements ~f:(fun p ->
        string_of_agreement_kind p.prop_kind)
    |> List.dedup_and_sort ~compare:String.compare
    |> List.filter ~f:(fun k ->
           not (List.mem implemented k ~equal:String.equal))
  in
  add "Kinds no implemented agreement covers, and a candidate would: %s\n"
    (if List.is_empty candidate_only then "none"
     else String.concat ~sep:", " candidate_only);
  Buffer.contents b

(** THE TOOLS, TRANSPOSED (2026-09-21, user: "It's also a good way to
    understand their roles").

    The overview reads by CLAIM — here is ours, here is who else answers
    it. This reads by TOOL: what each covers, and what it does beyond
    the claim it is filed under. Both are the same list inverted, so
    neither can drift from the other.

    The last line is the one that matters for the paper's argument, and
    it is computed rather than asserted: how many of our claims no
    existing tool answers. The related-work doc draws that gap as an
    illustrative bar chart; this counts it. *)
let pp_external_tools () : string =
  let b = Buffer.create 4096 in
  let add fmt = Printf.ksprintf (Buffer.add_string b) fmt in
  let tools =
    List.map external_checkers ~f:(fun x -> x.xc_tool)
    |> List.dedup_and_sort ~compare:String.compare
  in
  add "existing tools that answer one of these claims (%d tools, %d rows)\n\n"
    (List.length tools) (List.length external_checkers);
  List.iter tools ~f:(fun t ->
      let mine = List.filter external_checkers ~f:(fun x -> String.equal x.xc_tool t) in
      let adoption =
        match mine with x :: _ -> x.xc_adoption | [] -> ""
      in
      add "%s  — %s\n" t adoption;
      List.iter mine ~f:(fun x ->
          add "    answers  %s\n" (string_of_agreement_id x.xc_answers);
          add "      what   %s\n" x.xc_what;
          add "      BEYOND %s\n" x.xc_beyond);
      add "\n");
  let answered =
    List.map external_checkers ~f:(fun x -> x.xc_answers)
    |> List.dedup_and_sort ~compare:Poly.compare
  in
  let unanswered =
    List.filter agreement_registry ~f:(fun r ->
        not (List.mem answered r.ag_id ~equal:Poly.equal))
  in
  add "%d of our %d claims have an existing external answerer.\n"
    (List.length answered) (List.length agreement_registry);
  add "NO existing tool answers: %s\n\n"
    (if List.is_empty unanswered then "none"
     else
       String.concat ~sep:", " (List.map unanswered ~f:(fun r -> r.ag_slug)));
  (* BY KIND, because the interesting pattern is not a count.
     COMPUTED rather than asserted: the first prose version of this
     claimed "seven of the eight landed claims have a mature external
     answerer", and writing the list down said otherwise. Whatever the
     numbers become, they will be the numbers. *)
  add "by kind — answered / total:\n";
  let kinds =
    List.map agreement_registry ~f:(fun r ->
        string_of_agreement_kind r.ag.ag_kind)
    |> List.dedup_and_sort ~compare:String.compare
  in
  List.iter kinds ~f:(fun k ->
      let of_kind =
        List.filter agreement_registry ~f:(fun r ->
            String.equal (string_of_agreement_kind r.ag.ag_kind) k)
      in
      let n =
        List.count of_kind ~f:(fun r ->
            List.mem answered r.ag_id ~equal:Poly.equal)
      in
      add "  %-14s %d / %d\n" k n (List.length of_kind));
  add
    "\nWhat that split says: existing tools answer ADMISSIBILITY — would \n\
     these two have been accepted together — because both sides are \n\
     artifacts they can read. They do not answer PROMISE, and they \n\
     cannot: the second side is the PROJECT'S DECLARATION, and no tool \n\
     outside this one has it. That is a sharper statement of the gap \n\
     than a count, and it is a fact about this registry rather than a \n\
     paragraph in a paper.\n";
  Buffer.contents b

(** ONE PLACE FOR EVERYTHING THE OVERVIEW CANNOT SHOW (2026-09-17,
    user). The agreement overview is the table a reader works from, so
    what is NOT on it is invisible unless somewhere collects it — and it
    had been scattered across three documents and one flat list.

    Grouped by [prop_frame], because the groups are four different kinds
    of work and the order is deliberate: the ones a schema change would
    put on the table come first, the ones the model does not reach come
    last, and the undecided one is not allowed to hide among either. *)
let pp_out_of_table_md () : string =
  let b = Buffer.create 4096 in
  let add fmt = Printf.ksprintf (Buffer.add_string b) fmt in
  let group_of p =
    match p.prop_frame with
    | In_frame -> 0
    | Unfiled _ -> 1
    | Not_an_agreement _ -> 2
    | Outside_the_frame _ -> 3
  in
  let heading =
    [| ( "Held up by a schema field",
         "The per-action frame REACHES these. What is missing is that a \
          proposal carries no rooting and no target list, so there is \
          nothing to put in the overview's `R` and ▣ columns. Adding \
          those two fields would put each of these on the grid with its \
          origin marked and no `D` anywhere — which is worth seeing, \
          since it says where the information was lost for a claim \
          nobody checks yet. It costs the row's meaning: `lag`, decided \
          and blame are undefined without a firing." );
       ( "Not filed either way",
         "`theory.md` §7.1's filter — *whose* rule is being recovered — \
          has never been applied here. Listed separately so it does not \
          sit among the answered ones looking like a peer." );
       ( "Not an agreement",
         "`theory.md` §7.1. An agreement is a claim about the project's \
          artifacts. These recover CANARY'S OWN rule, which makes them \
          world assertions: a violated agreement is a finding about the \
          software, a failed world assertion means this run tested \
          something other than what it says and every verdict in it is \
          suspect. Kept here rather than deleted, because the CHECK is \
          worth having and only its register is wrong." );
       ( "Outside the per-action frame",
         "`theory.md` §7. The model reasons per edge, and these are not \
          per-edge. §6's procedure will never find them, so they need \
          their own reasoning rather than more wiring." ) |]
  in
  add
    "\n---\n\n## 3. What has no record yet — out of the table\n\n\
     The [agreement overview](../matrix.md) shows the %d implemented \
     agreements of §2. These %d have no row on it. The reason is carried \
     on each proposal (`prop_frame`) and this grouping is generated from \
     it, so the four kinds of work stay apart without anyone \
     maintaining a list.\n"
    (List.length agreement_registry)
    (List.length proposed_agreements);
  for g = 0 to 3 do
    let here = List.filter proposed_agreements ~f:(fun p -> group_of p = g) in
    if not (List.is_empty here) then begin
      let title, blurb = heading.(g) in
      add "\n### %s (%d)\n\n%s\n" title (List.length here) blurb;
      List.iter here ~f:(fun p ->
          add "\n#### %s\n\n**Claim:** %s\n\n" p.prop_slug p.prop_claim;
          (match p.prop_frame with
           | In_frame -> ()
           | Outside_the_frame w | Not_an_agreement w | Unfiled w ->
               add "**Why no row:** %s\n\n" w);
          add "**Needs:** %s\n\n" p.prop_needs)
    end
  done;
  Buffer.contents b

(** The generated catalogue: every agreement's full record, as
    markdown. Written to [doc/canary/design/agreement/agreements.md] and
    pinned against this output, so the document is a build product
    rather than a second copy. *)
let pp_catalogue_md () : string =
  let b = Buffer.create 16384 in
  Buffer.add_string b
    (* THE TITLE ANSWERS A QUESTION (2026-09-17, user:
       "catalogue/components/models even the title looks very alike and
       confusing"). All three were reference nouns. The subtitle each
       carries now is the phrase README.md's routing table already used
       for it, so a reader who followed the routing sees the same words
       at the top of the file they land in. *)
    "## 2. What there is — every agreement, one by one\n\n\
     **GENERATED from the registry**, so it cannot drift from the code \
     that implements it. The records are in the AGREEMENT OVERVIEW's \
     order — earliest firing action first, then language, then \
     mechanism — so reading down this section walks that table top to \
     bottom. It is not one-to-one: a claim whose firing differs between \
     mechanisms has several rows there and one record here, and it \
     appears at its first row's position.\n\n\
     **What this does NOT show is what actually RAN.** That is a fact \
     about run logs, and a generated file that read logs would change \
     whenever anything ran — so `canary checks --landing` is the live \
     answer to *which are landed*, and this answers *what each one is \
     and what is in its way*.\n\n\
     Evidence paths are shown for a BUILT world. The world decides where \
     a binding's inspection sits — a Fetched binding's is at its fetch step \
     — so the same method reads different paths in different worlds.\n\n\
     The model these fields belong to is §1 above; why each agreement \
     exists is [`components.md`](components.md), at the anchor its row \
     carries, and [`theory.md`](theory.md) for why there is anything to \
     check at all; how to \
     land one is §4 and §5 below.\n\n";
  Buffer.add_string b (pp_todo_table_md ());
  Buffer.add_string b (pp_rooting_table_md ());
  Buffer.add_string b "\n### The records\n";
  List.iter (registry_in_table_order ()) ~f:(fun r ->
      Buffer.add_string b (pp_agreement ~markdown:true ~depth:1 r));
  Buffer.add_string b (pp_out_of_table_md ());
  Buffer.contents b
