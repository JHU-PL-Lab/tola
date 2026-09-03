(** The contract registry — M2 step 6
    ([doc/canary/design/agreement_registry_audit.md], 2026-08-17; the
    former agreement_registry.md merged into it 2026-08-21).

    Producer-first: the BELIEF in one table — one row per contract.
    Consumers (the expectation lowering, the per-project binding
    tables, spec-check, the tiny oracle) migrate in phase 2; until
    then this module is additive and nothing reads it but the pins.

    A row states:
    - WHAT the invariant is ([ag_invariant], falsifier-phrased — a
      check is a DISPROVER, never a proof, design §5);
    - HOW we check it — the existing [Canary_agreement_common.agreement_check]
      pipeline (id/status/predict) + the input template;
    - what it CLAIMS and how that is observed ([ag_claim] /
      [ag_evidence]), plus its descriptive category ([ag_cat], taken
      from the check's own module);
    - WHERE it fires — over the ACTION CATALOGUE (any action kind),
      derived from mechanism × provision (design §3);
    - the fault tags it answers to (step 9's mapping as data).

    Layering: surface/ — depends only on base/ + the surface theory;
    the firing domain is [Canary_basic.action] (base vocabulary — no
    new firing type invented here). The action layer refines an action
    into a concrete [Canary_scenario.firing_site] in phase 2. *)

open Base

(* the shared vocabulary and derivations this list gathers over *)
open Canary_agreement_common

(* ── MOVED HERE 2026-09-01 (step B: one file to edit) ──
   The table and everything derived from it left
   [canary_agreement_run.ml], which now holds only the predicate
   IMPLEMENTATIONS. The registry is therefore the DEFINITION rather
   than a view over one, and adding an agreement means editing this
   file. Dependency direction: registry -> run -> agreement, no cycle. *)

(** The contract registry. Single source of truth for §2.4 of
    [doc/canary/research/surface_draft/surface.md] Part C — adding a contract = adding one entry. *)
let registered_checks : Canary_agreement_common.agreement_check list =
  let open Canary_agreement_common in
  [
  { id = C1; name = "cmp_symbol";            layer = "L0";  status = Wired;
    enabled = true;  predict = Canary_chk_symbols.c1_predict };
  { id = C2; name = "cmp_api_completeness";  layer = "L3";  status = Wired;
    enabled = true;  predict = Canary_chk_api_surface.c2_predict };
  { id = C3; name = "cmp_behavior";          layer = "dyn"; status = Blocked [];
    enabled = false; predict = Canary_chk_behaviour.c3_predict };
  { id = C4; name = "cmp_abi";               layer = "L4";  status = Wired;
    enabled = true;  predict = Canary_chk_identity.c4_predict };
  { id = C5; name = "cmp_sym_version";       layer = "L1b"; status = Wired;
    enabled = true;  predict = Canary_chk_identity.c5_predict };
  { id = C6; name = "cmp_type";              layer = "L2";  status = Wired;
    enabled = true;  predict = Canary_chk_types.c6_predict };
  (* c7 api_sound_repack — Contract that the binding's user-facing
     layer is a sound repacking of its stub-facing layer. Same check
     shape as c3 (probe-assertion refutation), different Contract
     (binding-layer bug vs native-layer bug). The probe IS the
     binding-side test; predict returns []. The variant declaration
     attributes the failure to c7 — canary doesn't disambiguate at
     the detection layer. See
     [Canary_tiny_scenario.make_binding_repack_broken_runner_spec]
     for the demo against harness scenario [api_repack] (e5). *)
  { id = C7; name = "api_sound_repack";      layer = "dyn"; status = Stubbed;
    enabled = false; predict = Canary_chk_api_surface.c7_predict };
  (* c8 disabled — no Contract for canary to maintain. Each binding
     is independent; cross-binding consistency isn't a canary-side
     agreement to check. Probes happen to assert the same constants
     across languages by project convention, not by a Contract.
     Candidate for removal in a future registry cleanup. *)
  { id = C8; name = "cmp_api_faithfulness";  layer = "n/a"; status = Stubbed;
    enabled = false; predict = Canary_chk_composed.c8_predict };
]

(** Derive expected failure substrings from declared inspector inputs.

    [resolve] turns a per-input relative path (e.g.
    [pack_binding_ocaml/inspect_stub.json]) into an absolute path. The
    runner picks the first input path whose resolved form exists on
    disk, then hands it to the pure comparators in {!Canary_agreement_common}.

    [?disabled] is the per-call list of contracts to skip on top of
    the registry's own [enabled] flag. Typical sources:
    - per-project: [runner_spec.disabled_agreements]
    - per-CLI: the [--disable-contract c5,c4] flag on canary action / compat / verify
    A contract fires iff its registry [enabled] is true AND its id is
    not in [disabled].

    Phase 12 (2026-06-02): the four L0/L1b/L3/L4 sections of this
    function moved into per-contract predict closures registered in
    [registered_checks]. The body is now a flat iterator over the
    registry. Behaviour is unchanged with default [?disabled = []] —
    c1, c2, c5 fire as before; c4 returns [].

    Phase 13 (2026-06-02): per-call [?disabled] override added. *)
(** Per-contract form (A7 phase 1): the registry rows that FIRED — each
    enabled, not-disabled contract whose [predict] returned substrings —
    paired with its (deduped) substrings. {!predicted_contains_any} is
    its flatten; keeping the grouping lets the runner log and report
    per-contract firings instead of one collapsed count (the status-§2
    "per-step contract outcome" seed). *)
let predicted_by_agreement ?(disabled = []) ~resolve
    (inputs : Canary_agreement_common.inspect_input list) :
    (Canary_agreement_common.agreement_check * string list) list =
  let open Canary_agreement_common in
  List.filter_map registered_checks ~f:(fun c ->
    if c.enabled && not (List.mem disabled c.id ~equal:Poly.equal) then
      match c.predict ~resolve inputs with
      | [] -> None
      | subs -> Some (c, List.dedup_and_sort ~compare:String.compare subs)
    else None)

(** The registry rows a [predicted_by_agreement] call does NOT consult,
    each with its human reason — the per-call [?disabled] override (a
    project's [disabled_agreements] / --disable-contract) vs the registry's
    own [enabled] flag (status names why). For the runner's
    [agreement_skipped] events. *)
let skipped_checks ?(disabled = []) () :
    (Canary_agreement_common.agreement_check * string) list =
  let open Canary_agreement_common in
  List.filter_map registered_checks ~f:(fun c ->
    if List.mem disabled c.id ~equal:Poly.equal then
      Some (c, "disabled per call")
    else if not c.enabled then
      Some
        ( c,
          "disabled in registry ("
          ^ Canary_agreement_common.string_of_agreement_status c.status
          ^ ")" )
    else None)

let predicted_contains_any ?(disabled = []) ~resolve
    (inputs : Canary_agreement_common.inspect_input list) : string list =
  predicted_by_agreement ~disabled ~resolve inputs
  |> List.concat_map ~f:snd
  |> List.dedup_and_sort ~compare:String.compare


(* [binding_evidence_tag] and the per-agreement [inputs_of_agreement]
   match moved out (2026-09-02): WHAT a check reads is something only
   the check knows, so each family states it in its own
   [description.inputs]; the shared tag derivation is in
   [Canary_agreement_common]. This file listed it per id. *)

(* [claim] / [evidence] / [provenance] moved to
   [Canary_agreement_common] beside [cat] — they are the descriptive
   types a family uses to describe ITSELF, so they must sit below the
   families rather than in the registry that gathers them. *)

type agreement_row = {
  ag_slug      : string;
      (** the stable NAME — the registry's to give, because uniqueness
          is a property of the list rather than of any one check *)
  ag_doc       : string;
      (** the anchor in doc/canary/design/agreement_registry.md, pinned
          by [agreements.doc_anchors_exist]. Also the registry's: a fact
          about the DOCUMENT, not about the check *)
  ag_check     : Canary_agreement_common.agreement_check;
      (** the registered predict closure (id, status, enabled) *)
  ag_desc      : Canary_agreement_common.description;
      (** EVERYTHING ELSE, stated by the check's own module: category,
          standing, the falsifier sentence, claim, evidence, provenance,
          the surfaces it reads, fault tags, where it fires and what it
          reads. The registry copies none of it (2026-09-02, user: "the
          registry just list the checked") — it used to restate the
          sentence and the category, and all eight sentences had
          drifted from the family's. *)
}

(* the firing derivations and [uniform_world] moved to
   [Canary_agreement_common]: a family states where it fires. *)

(* ── row assembly ── *)

let check_of (id : Canary_agreement_common.agreement_id) :
    Canary_agreement_common.agreement_check =
  List.find registered_checks
    ~f:(fun ck -> Poly.equal ck.Canary_agreement_common.id id)
  |> Option.value_exn
       ~message:
         (Printf.sprintf "contract registry: no registered check for %s"
            (Canary_agreement_common.string_of_agreement_id id))

let row ~slug ~doc ~desc (id : Canary_agreement_common.agreement_id) :
    agreement_row =
  { ag_slug = slug; ag_doc = doc; ag_check = check_of id; ag_desc = desc }

(** THE table — one row per contract (c1..c8). Each row's [ag_reads]
    grounds the evidence in the artifact surfaces it reads — the
    contract IS a named relation over those reads. *)
let agreement_registry : agreement_row list =
  [ row C1 ~slug:"symbol_exported" ~doc:"§3.3" ~desc:Canary_chk_symbols.c1;
    row C2 ~slug:"api_surface_complete" ~doc:"§3.3"
      ~desc:Canary_chk_api_surface.c2;
    row C3 ~slug:"behavior_matches" ~doc:"§8" ~desc:Canary_chk_behaviour.c3;
    row C4 ~slug:"soname_denotes_needed" ~doc:"§6"
      ~desc:Canary_chk_identity.c4;
    row C5 ~slug:"symbol_versions_present" ~doc:"§3.3"
      ~desc:Canary_chk_identity.c5;
    row C6 ~slug:"c_types_agree" ~doc:"§3.3" ~desc:Canary_chk_types.c6;
    row C7 ~slug:"repack_preserves_api" ~doc:"§5.3"
      ~desc:Canary_chk_api_surface.c7;
    row C8 ~slug:"repack_complete" ~doc:"§5.3" ~desc:Canary_chk_composed.c8 ]

(* ── the counterexamples, GATHERED ──
   Each family ships its own (in its [description.counterexamples]);
   this is the flat view the layer tests iterate. It used to be a
   hand-written table HERE, which put per-agreement data — synthetic
   inspect JSON, expected substrings, the declared facts a solo cell
   compares against — in the file that is supposed to list rather than
   describe (2026-09-02, user: "this looks too tiny related and some
   hardcoded llvm and solver ... why is it here").

   The layer tests execute every one hermetically (no project run —
   the framework-test axis), so a new agreement lands WITH its
   counterexample and a changed predict breaks the pin. *)

let agreement_fixtures :
    (Canary_agreement_common.agreement_id * Canary_agreement_common.fixture) list
    =
  List.concat_map agreement_registry ~f:(fun r ->
      List.map r.ag_desc.Canary_agreement_common.counterexamples ~f:(fun fx ->
          (r.ag_check.Canary_agreement_common.id, fx)))

(** Total lookup over the table. *)
let row_of (id : Canary_agreement_common.agreement_id) : agreement_row =
  List.find agreement_registry ~f:(fun r ->
      Poly.equal r.ag_check.Canary_agreement_common.id id)
  |> Option.value_exn
       ~message:
         (Printf.sprintf "contract registry: no row for %s"
            (Canary_agreement_common.string_of_agreement_id id))

(** What one agreement reads, by id — a LOOKUP in the list, now that
    each family states its own [inputs] (2026-09-02). It was a 65-line
    match on the id in this file; the registry knows which module
    describes C1, not what C1 reads.

    [mechanism] defaults to the language's default (static for
    OCaml/Python today); a dynamic binding has no compiled stub to
    inspect, which each family's [inputs] answers for itself. *)
let inputs_of_agreement ?mechanism ?(world = [])
    (c : Canary_agreement_common.agreement_id) (l : Canary_lang.lang) :
    Canary_agreement_common.inspect_input list =
  let m =
    Option.value mechanism
      ~default:
        (Option.value
           (Canary_mechanism.default_mechanism_of_lang l)
           ~default:Canary_mechanism.Cstubs)
  in
  (row_of c).ag_desc.Canary_agreement_common.inputs m l world

(* ── THE BELIEF MATRIX (2026-08-18) ──
   The registry's motivation made visible: enumerate every
   (contract × action) cell and give each a STATUS. The matrix is
   TOTAL by construction — every cell has a status, so "the possible
   invariant matrix" is a table you can read rather than an idea, and
   "filling it" is a concrete list of [Declared] cells.

   Reading the marks:
   - [Wired]    ✓ fires here AND ships a counterexample fixture;
   - [Declared] ~ fires here, predict exists, NO fixture yet — the
                  fill list;
   - [Blocked]  ⊘ the contract itself is blocked on deps;
   - [Empty]    · does not fire here (by the firing derivation) —
                  the reason is the derivation, not an omission. *)

type cell_status =
  | Wired
  | Declared
  | Blocked of Canary_agreement_common.agreement_id list
  | Empty

let mark_of_status = function
  | Wired -> "✓"
  | Declared -> "~"
  | Blocked _ -> "⊘"
  | Empty -> "·"

(** The COLUMNS — the general action space one lang's chain can carry
    (the action catalogue, SSOT §6.5). Actions with no cell wired yet
    still appear: the empty columns ARE the picture. *)
(** The matrix's columns: THE action catalogue, not a copy of it. *)
let matrix_actions (l : Canary_lang.lang) : Canary_basic.action list =
  Canary_basic.actions_of_lang l

let has_fixture (id : Canary_agreement_common.agreement_id) : bool =
  List.exists agreement_fixtures ~f:(fun (i, _) -> Poly.equal i id)

(** One cell's status under a concrete world. *)
let cell_status_of (r : agreement_row) ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(world : Canary_artifact.assignment)
    (a : Canary_basic.action) : cell_status =
  let fires =
    List.exists (r.ag_desc.Canary_agreement_common.firing mechanism lang world) ~f:(fun x ->
        Poly.equal x a)
  in
  if not fires then Empty
  else
    match r.ag_check.Canary_agreement_common.status with
    | Canary_agreement_common.Blocked deps -> Blocked deps
    | _ -> if has_fixture r.ag_check.Canary_agreement_common.id then Wired else Declared

(** THE matrix: rows = contracts, columns = actions, under one world. *)
let belief_matrix ?(mechanism = Canary_mechanism.Cstubs)
    ?(lang = Canary_lang.OCaml) ?(provision = Canary_store.Built) () :
    (agreement_row * (Canary_basic.action * cell_status) list) list =
  let world = uniform_world ~lang ~mechanism provision in
  List.map agreement_registry ~f:(fun r ->
      ( r,
        List.map (matrix_actions lang) ~f:(fun a ->
            (a, cell_status_of r ~mechanism ~lang ~world a)) ))

(** Render the matrix as a text table (the CLI view). *)
let pp_belief_matrix ?(mechanism = Canary_mechanism.Cstubs)
    ?(lang = Canary_lang.OCaml) ?(provision = Canary_store.Built) () : string =
  let m = belief_matrix ~mechanism ~lang ~provision () in
  let cols = matrix_actions lang in
  let head =
    "contract | "
    ^ String.concat ~sep:" | "
        (List.map cols ~f:Canary_basic.string_of_action)
  in
  let body =
    List.map m ~f:(fun (r, cells) ->
        Printf.sprintf "%-4s     | %s"
          (Canary_agreement_common.string_of_agreement_id r.ag_check.Canary_agreement_common.id)
          (String.concat ~sep:" | "
             (List.map cells ~f:(fun (a, st) ->
                  let w =
                    String.length (Canary_basic.string_of_action a)
                  in
                  let mk = mark_of_status st in
                  mk ^ String.make (max 0 (w - 1)) ' '))))
  in
  String.concat ~sep:"\n" (head :: body)

(** The fill list — every [Declared] cell (fires, but no counterexample
    fixture yet). The concrete answer to "what is left to fill". *)
let fill_list ?(mechanism = Canary_mechanism.Cstubs)
    ?(lang = Canary_lang.OCaml) ?(provision = Canary_store.Built) () :
    (Canary_agreement_common.agreement_id * Canary_basic.action) list =
  List.concat_map (belief_matrix ~mechanism ~lang ~provision ())
    ~f:(fun (r, cells) ->
      List.filter_map cells ~f:(fun (a, st) ->
          match st with
          | Declared -> Some (r.ag_check.Canary_agreement_common.id, a)
          | Wired | Blocked _ | Empty -> None))

(* ── PROPOSED agreements — the catalogue's holes, as data (2026-09-01) ──
   An agreement the doc STATES but the code does not yet implement gets a
   row here rather than being absent. The registry then lists its own
   gaps, which is the same principle as the belief matrix's `~` marks:
   a hole should be visible in the artifact that claims completeness.

   These carry no [agreement_check] — there is no predict to run — so they
   are a separate list that [all_agreements] unions with the implemented
   rows for display and pinning. *)

type proposed = {
  prop_slug   : string;
  prop_doc    : string;
  prop_claim  : string;   (** falsifier-phrased, like [ag_invariant] *)
  prop_reads  : (string * string) list;
  prop_needs  : string;   (** what implementing it requires *)
}

let proposed_agreements : proposed list =
  [ { prop_slug = "denotation_across_worlds";
      prop_doc = "§6.3.4";
      prop_claim =
        "a recorded library identity denotes the SAME implementation in \
         the deploy world as in the build world";
      prop_reads = [ ("Sf.2", "native") ];
      prop_needs =
        "compare the object each soname names in both provisions of a \
         2x2 world — static, no loader, no declaration (§6.3)" };
    { prop_slug = "no_duplicate_implementation";
      prop_doc = "§6.3.4";
      prop_claim =
        "the resolved set contains no two identities that are one \
         implementation (alternative spelling), and none that statically \
         absorbs another (containment)";
      prop_reads = [ ("Sf.2", "native") ];
      prop_needs =
        "the shipped objects' symbol sets + version namespaces; the \
         declared alternative-spelling fact is a convenience (§6.6)" };
    { prop_slug = "closure_satisfiable";
      prop_doc = "§6.3.4";
      prop_claim =
        "every name in the consumer's recorded NEEDED has a provider in \
         this world";
      prop_reads = [ ("Sf.5", "binding"); ("Sf.2", "native") ];
      prop_needs = "readelf -d on the consumer + the world's object set" };
    { prop_slug = "interposition_winner";
      prop_doc = "§6.3.4";
      prop_claim =
        "the definition that wins for a shared symbol is the one the \
         consumer was built against";
      prop_reads = [ ("Trace", "run") ];
      prop_needs =
        "LD_DEBUG=bindings at probe — the RESOLVED view; evidence only, \
         no verdict of its own (§6.7)" } ]

(* ── the unified view — one list to print, cite and pin ── *)

type status = Implemented of Canary_agreement_common.agreement_status | Not_wired

type entry = {
  e_slug  : string;
  e_doc   : string;
  e_claim : string;
  e_reads : (string * string) list;
  e_status : status;
}

(** EVERY agreement canary knows about, implemented or merely stated.
    This is what a catalogue section cites and what the alignment
    harness checks. *)
let all_agreements : entry list =
  List.map agreement_registry ~f:(fun r ->
      { e_slug = r.ag_slug;
        e_doc = r.ag_doc;
        e_claim = r.ag_desc.Canary_agreement_common.about.Canary_agreement_common.says;
        e_reads = r.ag_desc.Canary_agreement_common.reads;
        e_status = Implemented r.ag_check.Canary_agreement_common.status })
  @ List.map proposed_agreements ~f:(fun p ->
        { e_slug = p.prop_slug;
          e_doc = p.prop_doc;
          e_claim = p.prop_claim;
          e_reads = p.prop_reads;
          e_status = Not_wired })

let string_of_status = function
  | Implemented s -> Canary_agreement_common.string_of_agreement_status s
  | Not_wired -> "proposed"

(** The registry as a table — `canary agreements`. *)
let pp_agreements () : string =
  let line (e : entry) =
    Printf.sprintf "%-28s %-6s %-16s %s" e.e_slug e.e_doc
      (string_of_status e.e_status) e.e_claim
  in
  String.concat ~sep:"\n"
    (Printf.sprintf "%-28s %-6s %-16s %s" "agreement" "doc" "status" "claim"
     :: List.map all_agreements ~f:line)

(* ── FACTS IN, CHECKS OUT (user, 2026-09-02) ──
   A project declares what it IS — its language, its binding mechanism,
   how the artifact was provisioned. It has no business naming an
   agreement: which checks those facts imply, and what each needs to
   read, is the framework's knowledge.

   This is the direction [inputs_of_agreement] had backwards. A project
   calling `inputs_of_agreement C1 OCaml` has to know that C1 exists, and
   that it applies here — two facts it should never have had to learn.
   With this, no project writes an agreement id. *)

(** Every agreement that applies to a binding with these facts, paired
    with the inputs it would read. [world] is the enumeration's own
    [assignment] — it already records how EVERY artifact was
    provisioned, so nothing here has to choose which provision stands
    for the world (2026-09-02). [action] narrows to the checks that fire
    at one action; omit it for all of them. *)
let agreements_for ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(world : Canary_artifact.assignment)
    ?action () : (agreement_row * Canary_agreement_common.inspect_input list) list =
  List.filter_map agreement_registry ~f:(fun r ->
      let fires =
        let sites = r.ag_desc.Canary_agreement_common.firing mechanism lang world in
        match action with
        | None -> not (List.is_empty sites)
        | Some a -> List.exists sites ~f:(fun s -> Poly.equal s a)
      in
      if fires && r.ag_check.Canary_agreement_common.enabled then
        Some (r, r.ag_desc.Canary_agreement_common.inputs mechanism lang world)
      else None)
