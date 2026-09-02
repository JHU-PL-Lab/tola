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
    - HOW we check it — the existing [Canary_agreement.agreement_check]
      pipeline (id/status/predict) + the input template;
    - in which LOGICAL role (Surface / Meeting / Execution — the
      artifact-relationship axis, design §4);
    - WHERE it fires — over the ACTION CATALOGUE (any action kind),
      derived from mechanism × provision (design §3);
    - the fault tags it answers to (step 9's mapping as data).

    Layering: surface/ — depends only on base/ + the surface theory;
    the firing domain is [Canary_basic.action] (base vocabulary — no
    new firing type invented here). The action layer refines an action
    into a concrete [Canary_scenario.firing_site] in phase 2. *)

open Base

(* ── MOVED HERE 2026-09-01 (step B: one file to edit) ──
   The table and everything derived from it left
   [canary_agreement_run.ml], which now holds only the predicate
   IMPLEMENTATIONS. The registry is therefore the DEFINITION rather
   than a view over one, and adding an agreement means editing this
   file. Dependency direction: registry -> run -> agreement, no cycle. *)

(** The contract registry. Single source of truth for §2.4 of
    [doc/canary/research/surface_draft/surface.md] Part C — adding a contract = adding one entry. *)
let registered_checks : Canary_agreement.agreement_check list =
  let open Canary_agreement in
  [
  { id = C1; name = "cmp_symbol";            layer = "L0";  status = Wired;
    enabled = true;  predict = Canary_agreement_run.c1_predict };
  { id = C2; name = "cmp_api_completeness";  layer = "L3";  status = Wired;
    enabled = true;  predict = Canary_agreement_run.c2_predict };
  { id = C3; name = "cmp_behavior";          layer = "dyn"; status = Blocked [];
    enabled = false; predict = Canary_agreement_run.c3_predict };
  { id = C4; name = "cmp_abi";               layer = "L4";  status = Wired;
    enabled = true;  predict = Canary_agreement_run.c4_predict };
  { id = C5; name = "cmp_sym_version";       layer = "L1b"; status = Wired;
    enabled = true;  predict = Canary_agreement_run.c5_predict };
  { id = C6; name = "cmp_type";              layer = "L2";  status = Wired;
    enabled = true;  predict = Canary_agreement_run.c6_predict };
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
    enabled = false; predict = Canary_agreement_run.c7_predict };
  (* c8 disabled — no Contract for canary to maintain. Each binding
     is independent; cross-binding consistency isn't a canary-side
     agreement to check. Probes happen to assert the same constants
     across languages by project convention, not by a Contract.
     Candidate for removal in a future registry cleanup. *)
  { id = C8; name = "cmp_api_faithfulness";  layer = "n/a"; status = Stubbed;
    enabled = false; predict = Canary_agreement_run.c8_predict };
]

(** Derive expected failure substrings from declared inspector inputs.

    [resolve] turns a per-input relative path (e.g.
    [pack_binding_ocaml/inspect_stub.json]) into an absolute path. The
    runner picks the first input path whose resolved form exists on
    disk, then hands it to the pure comparators in {!Canary_agreement}.

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
    paired with its (deduped) substrings. {!predicted_contains_any_v2} is
    its flatten; keeping the grouping lets the runner log and report
    per-contract firings instead of one collapsed count (the status-§2
    "per-step contract outcome" seed). *)
let predicted_by_agreement_v2 ?(disabled = []) ~resolve
    (inputs : Canary_agreement.inspect_input list) :
    (Canary_agreement.agreement_check * string list) list =
  let open Canary_agreement in
  List.filter_map registered_checks ~f:(fun c ->
    if c.enabled && not (List.mem disabled c.id ~equal:Poly.equal) then
      match c.predict ~resolve inputs with
      | [] -> None
      | subs -> Some (c, List.dedup_and_sort ~compare:String.compare subs)
    else None)

(** The registry rows a [predicted_by_agreement_v2] call does NOT consult,
    each with its human reason — the per-call [?disabled] override (a
    project's [disabled_agreements] / --disable-contract) vs the registry's
    own [enabled] flag (status names why). For the runner's
    [agreement_skipped] events. *)
let skipped_checks ?(disabled = []) () :
    (Canary_agreement.agreement_check * string) list =
  let open Canary_agreement in
  List.filter_map registered_checks ~f:(fun c ->
    if List.mem disabled c.id ~equal:Poly.equal then
      Some (c, "disabled per call")
    else if not c.enabled then
      Some
        ( c,
          "disabled in registry ("
          ^ Canary_agreement.string_of_agreement_status c.status
          ^ ")" )
    else None)

let predicted_contains_any_v2 ?(disabled = []) ~resolve
    (inputs : Canary_agreement.inspect_input list) : string list =
  predicted_by_agreement_v2 ~disabled ~resolve inputs
  |> List.concat_map ~f:snd
  |> List.dedup_and_sort ~compare:String.compare


let inputs_of_agreement ?mechanism (c : Canary_agreement.agreement_id)
    (l : Canary_lang.lang) : Canary_agreement.inspect_input list =
  let open Canary_agreement in
  (* mechanism defaults to the language's default (static for OCaml/Python
     today) — current callers unchanged; a dynamic binding (ctypes/dynlink)
     has NO stub input (it dlopens at runtime). *)
  let m =
    Option.value mechanism
      ~default:
        (Option.value (Canary_mechanism.default_mechanism_of_lang l)
           ~default:Canary_mechanism.Cstubs)
  in
  let is_dynamic =
    Poly.equal (Canary_mechanism.discipline_of_mechanism m)
      Canary_mechanism.Dynamic_ffi
  in
  let tag action = Canary_basic.string_of_action action in
  let build_binding_tag = tag (Canary_basic.Build_binding l) in
  let build_lib_tag = tag Canary_basic.Build_lib in
  match c, l with
  | C1, (Canary_lang.OCaml | Canary_lang.Python) when not is_dynamic ->
      [ C_stub [ build_binding_tag ^ "/inspect.json" ];
        Native_lib [ build_lib_tag ^ "/inspect.json" ] ]
  | C1, (Canary_lang.OCaml | Canary_lang.Python) ->
      (* dynamic: no compiled stub to inspect — the runtime fallback
         (probe.log presence) catches missing-symbol failures *)
      []
  | C2, Canary_lang.OCaml ->
      [ Ocaml_mli [ build_binding_tag ^ "/inspect_mli.json" ] ]
  | C2, Canary_lang.Python ->
      [ Python_attrs [ build_binding_tag ^ "/inspect_attrs.json" ] ]
  | C4, Canary_lang.Python when not is_dynamic ->
      [ Native_lib [ build_lib_tag ^ "/inspect.json" ];
        Abi_surface [ build_binding_tag ^ "/inspect.json" ] ]
  | C5, Canary_lang.Python when not is_dynamic ->
      [ Versioned_exports [ build_lib_tag ^ "/inspect.json" ];
        Versioned_req [ build_binding_tag ^ "/inspect.json" ] ]
  | C6, Canary_lang.OCaml when not is_dynamic ->
      [ Typed_header [ "scan_sources/inspect_typed_header.json" ];
        Typed_binding_stub
          [ "scan_sources/inspect_typed_binding_stub_ocaml.json" ] ]
  | _ -> []  (* placeholder / unwired / behavior-grep / dynamic — no inputs *)


(** The three LOGICAL roles — the artifact-relationship axis of
    checking (design §4). Methods (inspections, strict-flag builds,
    shim recorders, probes, decl-derived programs, upstream suites)
    are PLACED into slots, not classified here. *)
type role =
  | Surface    (** one artifact: what it presents at its boundary *)
  | Meeting    (** two artifacts: compatible where they link/load *)
  | Execution  (** two artifacts running: what the trace shows *)
[@@deriving show, eq]

(** The expectation form per contract — HOW a check becomes an
    expectation (the three shapes of the old per-project
    [expectation_source], minus the payload). *)
type source =
  | Inspection      (** inspect JSONs → predict → compat-derived expectation *)
  | Behavior_grep   (** the run's log substring → failure expectation *)
  | Postcondition   (** the action's check_post family (markers, pin-checks,
                        staged-parity at Install_lib, freshness) *)
  | Placeholder     (** Expect_success until wired (missing-ness visible) *)
[@@deriving show, eq]

type agreement_row = {
  ag_slug      : string;
      (** THE STABLE NAME both the doc and the code use. The `c1..c8`
          ids are provisional (§0); the slug is what a catalogue
          section cites and what survives the renaming settle. *)
  ag_doc       : string;
      (** the catalogue section that DEFINES this agreement, e.g.
          "§6.3". Paired with [ag_slug] this is a two-way bridge, and
          [agreements.doc_anchors_exist] fails when it drifts. *)
  ag_check     : Canary_agreement.agreement_check;
      (** id / name / layer / status / enabled / predict — the
          existing pipeline ([registered_checks]) *)
  ag_invariant : string;
      (** the one-sentence agreement, falsifier-phrased (design §5);
          the reconciliation point for ssot's Ag.X ↔ C1..C8 drift *)
  ag_reads     : (string * string) list;
      (** THE GROUNDING: which artifact-surface roles the cell's
          evidence reads — (surface_role, side), e.g. ("Sf.3",
          "binding"). The draft's five surfaces (Sf.1 native_header,
          Sf.2 native_lib, Sf.3 binding_stub, Sf.4 binding_header,
          Sf.5 binding_lib) + "Trace" (the runtime observation). A
          contract IS a named relation over these reads; the action
          says where the read attaches. *)
  ag_role      : role;
      (** PROSE tag at most (Surface/Meeting/Execution — the legacy
          evidence vocabulary). NOT a typed axis: the action column
          already implies the cell's subject (one artifact vs a pair)
          and its evidence flavor; the typed axis is [source] — how
          the expectation is produced. *)
  ag_inputs    : Canary_mechanism.mechanism -> Canary_lang.lang ->
                 Canary_agreement.inspect_input list;
      (** the step-2 template ([inputs_of_agreement]) *)
  ag_firing    : Canary_mechanism.mechanism -> Canary_lang.lang ->
                 Canary_store.provision -> Canary_basic.action list;
      (** WHERE it fires — over the ACTION CATALOGUE
          ([Canary_basic.action], the general vocabulary; SSOT §6.5).
          Contracts are general for ALL artifacts, actions and
          mechanisms: any action kind can carry a check (fetch,
          configure, build, publish, probe, …); today's rows fire at
          the build/probe actions — the wired subset. A row returns
          [] for actions it does not fire at; the per-project
          enabled/disabled policy is the bypass. The action layer
          refines an action into [Canary_scenario.firing_site]
          (location, loc_filter) in phase 2. *)
  ag_source    : source;
      (** HOW the expectation comes to be — the expectation half of
          the belief, mirroring the old per-project expectation_source
          shapes without their payload (inputs come from the template,
          version context from the scenario). *)
  ag_fault_tags : string list;
      (** step 9: sym_missing ↔ c1, … (scenario.md's catalogue) *)
}

(* ── the firing derivations ── *)

(** The default: mechanism × lang × provision → actions. Static +
    Built → build then probe; Static + Fetched/Vendored → probe (no
    build step exists); Dynamic → probe (probe-only chains). *)
let firing_default (m : Canary_mechanism.mechanism) (l : Canary_lang.lang)
    (p : Canary_store.provision) : Canary_basic.action list =
  let probe = Canary_basic.Probe_binding l in
  match Canary_mechanism.discipline_of_mechanism m with
  | Canary_mechanism.Dynamic_ffi -> [ probe ]
  | Canary_mechanism.Static_c_abi -> (
      match p with
      (* Installed groups with Built (2026-08-18): its chain includes
         the real build + the staging — the build-family contracts fire. *)
      | Canary_store.Built | Canary_store.Installed ->
          [ Canary_basic.Build_binding l; probe ]
      | Canary_store.Fetched | Canary_store.Vendored | Canary_store.Absent ->
          [ probe ])

(** c4/c5's lib-only cell (2026-08-18): a BUILT lib carries its own
    inspection — elf soname / versioned exports vs the DECLARED facts.
    Fires at [Build_lib] in Built worlds: the tool (linker, version
    script) is a black box; its artifact is the evidence. *)
let firing_with_build_lib (m : Canary_mechanism.mechanism)
    (l : Canary_lang.lang) (p : Canary_store.provision) :
    Canary_basic.action list =
  match (Canary_mechanism.discipline_of_mechanism m, p) with
  | Canary_mechanism.Static_c_abi, Canary_store.Built ->
      [ Canary_basic.Build_lib; Canary_basic.Build_binding l;
        Canary_basic.Probe_binding l ]
  | _ -> firing_default m l p

(** Behavior needs a run — probe only, in every world. *)
let firing_probe_only (_ : Canary_mechanism.mechanism)
    (l : Canary_lang.lang) (_ : Canary_store.provision) :
    Canary_basic.action list = [ Canary_basic.Probe_binding l ]

(* ── row assembly ── *)

let check_of (id : Canary_agreement.agreement_id) :
    Canary_agreement.agreement_check =
  List.find registered_checks
    ~f:(fun ck -> Poly.equal ck.Canary_agreement.id id)
  |> Option.value_exn
       ~message:
         (Printf.sprintf "contract registry: no registered check for %s"
            (Canary_agreement.string_of_agreement_id id))

let row ~slug ~doc ~invariant ~reads ~role ~firing ~source ~tags
    (id : Canary_agreement.agreement_id) : agreement_row =
  { ag_slug = slug;
    ag_doc = doc;
    ag_check = check_of id;
    ag_invariant = invariant;
    ag_reads = reads;
    ag_role = role;
    ag_inputs =
      (fun m l ->
        inputs_of_agreement ~mechanism:m id l);
    ag_firing = firing;
    ag_source = source;
    ag_fault_tags = tags }

(** THE table — one row per contract (c1..c8). Each row's [ag_reads]
    grounds the evidence in the artifact surfaces it reads — the
    contract IS a named relation over those reads. *)
let agreement_registry : agreement_row list =
  [ row C1
      ~slug:"symbol_exported" ~doc:"§2.3"
      ~invariant:
        "every symbol the binding declares (its stub references) is \
         exported by the lib"
      ~reads:[ ("Sf.3", "binding"); ("Sf.2", "native") ]
      ~role:Surface ~firing:firing_with_build_lib ~source:Inspection
      ~tags:[ "sym_missing" ];
    row C2
      ~slug:"api_surface_complete" ~doc:"§2.3"
      ~invariant:
        "every watchlisted entry is present on the user-facing surface"
      ~reads:[ ("Sf.4", "binding") ]
      ~role:Surface ~firing:firing_default ~source:Inspection
      ~tags:[ "api_drop" ];
    row C3
      ~slug:"behavior_matches" ~doc:"§7"
      ~invariant:"the probe's trace matches the recorded expectation"
      ~reads:[ ("Trace", "run") ]
      ~role:Execution ~firing:firing_probe_only ~source:Behavior_grep
      ~tags:[ "behavior" ];
    row C4
      ~slug:"soname_denotes_needed" ~doc:"§5"
      ~invariant:
        "the lib's soname matches what the consumer records it needs"
      ~reads:[ ("Sf.2", "native"); ("Sf.5", "binding") ]
      ~role:Surface ~firing:firing_with_build_lib ~source:Inspection
      ~tags:[ "abi_soname" ];
    row C5
      ~slug:"symbol_versions_present" ~doc:"§2.3"
      ~invariant:
        "versioned symbols carry the annotations the consumer expects"
      ~reads:[ ("Sf.2", "native"); ("Sf.5", "binding") ]
      ~role:Surface ~firing:firing_with_build_lib ~source:Inspection
      ~tags:[ "sym_version" ];
    row C6
      ~slug:"c_types_agree" ~doc:"§2.3"
      ~invariant:"C types at the header/stub boundary match"
      ~reads:[ ("Sf.1", "native"); ("Sf.3", "binding") ]
      ~role:Meeting ~firing:firing_default ~source:Inspection
      ~tags:[ "type_arity" ];
    row C7
      ~slug:"repack_preserves_api" ~doc:"§4.3"
      ~invariant:"repackaging preserves the API"
      ~reads:[ ("Sf.4", "binding") ]
      ~role:Meeting ~firing:firing_probe_only ~source:Behavior_grep
      ~tags:[ "api_repack" ];
    row C8
      ~slug:"repack_complete" ~doc:"§4.3"
      ~invariant:
        "repackaging is complete — nothing the original had is lost"
      ~reads:[ ("Sf.4", "binding") ]
      ~role:Meeting ~firing:firing_default ~source:Placeholder
      ~tags:[ "api_add" ] ]

(* ── spec fixtures — testing AHEAD of project running ──
   Each contract ships its MINIMAL COUNTEREXAMPLE: synthetic inspect
   inputs + the failure substrings the row's predict MUST yield on
   them. The layer tests execute every fixture hermetically (no
   project run — the framework-test axis), so a new contract lands
   WITH its fixture and a changed predict breaks the pin. Coverage:
   C1, C2 today. C3/C7 are blocked in the registry; C4/C5/C6 pend
   their fixture JSON shapes (elf/versioned/typed loaders in
   [Canary_agreement]). *)

type fixture = {
  fx_predict :
    (resolve:(string -> string) ->
     Canary_agreement.inspect_input list -> string list) option;
      (** the closure under test — [None] = the row's
          [ag_check.predict]. Some = a CELL predict (e.g. the
          decl-comparison closures for the lib-only cells). *)
  fx_inputs : Canary_agreement.inspect_input list;
      (** input-file references ([C_stub], [Native_lib], [Ocaml_mli],
          [Python_attrs], …) *)
  fx_bodies : (string * string) list;
      (** file name → synthetic inspect JSON (the [resolve] source) *)
  fx_expect : string list;
      (** the failure substrings [predict] must yield *)
}

let agreement_fixtures : (Canary_agreement.agreement_id * fixture) list =
  let c_stub_body = {|{"kind": "c_stub", "path": "fx",
    "requires": ["tiny_sum", "tiny_offset"]}|} in
  let native_body = {|{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_diff"]}|} in
  let mli_body = {|{"kind": "ocaml_mli", "path": "fx",
    "watchlist": {"present": [], "missing": ["Llvm.Opcode.UncondBr"]}}|} in
  let py_body = {|{"kind": "python", "path": "fx",
    "watchlist": {"present": [], "missing": ["Solver.add", "BitVec"]}}|} in
  let c1_lib_body = {|{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_diff"]}|} in
  let c4_lib_body = {|{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum"],
    "elf": {"soname": "libtiny.so.2", "needed": []}}|} in
  let c5_lib_body = {|{"kind": "native", "path": "fx",
    "versioned_exports": {"tiny_sum": "TINY_1.0"}}|} in
  [ ( Canary_agreement.C1,
      (* the LIB-ONLY cell: every declared c_api function exported by
         the built lib (sym_missing at the source, no binding) *)
      { fx_predict =
          Some
            (Canary_agreement_run.c1_decl_predict
               ~declared_functions:
                 [ "tiny_sum"; "tiny_diff"; "tiny_offset" ]);
        fx_inputs = [ Canary_agreement.Native_lib [ "lib.json" ] ];
        fx_bodies = [ ("lib.json", c1_lib_body) ];
        fx_expect = [ "tiny_offset" ] } );
    ( Canary_agreement.C4,
      (* the LIB-ONLY cell: the built lib's elf soname vs the declared *)
      { fx_predict =
          Some
            (Canary_agreement_run.c4_decl_predict
               ~declared_soname:"libtiny.so.1");
        fx_inputs = [ Canary_agreement.Native_lib [ "lib.json" ] ];
        fx_bodies = [ ("lib.json", c4_lib_body) ];
        fx_expect = [ "soname libtiny.so.2 != declared libtiny.so.1" ] } );
    ( Canary_agreement.C5,
      (* the LIB-ONLY cell: the version script applied — the declared
         tag must appear among the built lib's @@VER annotations *)
      { fx_predict =
          Some
            (Canary_agreement_run.c5_decl_predict ~declared_tags:[ "TINY_2.0" ]);
        fx_inputs = [ Canary_agreement.Versioned_exports [ "lib.json" ] ];
        fx_bodies = [ ("lib.json", c5_lib_body) ];
        fx_expect = [ "version TINY_2.0 not exported" ] } );
    ( Canary_agreement.C1,
      { fx_predict = None;
        fx_inputs =
          [ Canary_agreement.C_stub [ "stub.json" ];
            Canary_agreement.Native_lib [ "lib.json" ] ];
        fx_bodies =
          [ ("stub.json", c_stub_body); ("lib.json", native_body) ];
        fx_expect = [ "tiny_offset" ] } );
    ( Canary_agreement.C2,
      { fx_predict = None;
        fx_inputs = [ Canary_agreement.Ocaml_mli [ "mli.json" ] ];
        fx_bodies = [ ("mli.json", mli_body) ];
        (* the dotted-name expansion variants *)
        fx_expect = [ "Llvm.Opcode.UncondBr"; "Opcode.UncondBr"; "UncondBr" ] } );
    ( Canary_agreement.C2,
      { fx_predict = None;
        fx_inputs = [ Canary_agreement.Python_attrs [ "py.json" ] ];
        fx_bodies = [ ("py.json", py_body) ];
        fx_expect = [ "Solver.add"; "add"; "BitVec" ] } ) ]

(** Total lookup over the table. *)
let row_of (id : Canary_agreement.agreement_id) : agreement_row =
  List.find agreement_registry ~f:(fun r ->
      Poly.equal r.ag_check.Canary_agreement.id id)
  |> Option.value_exn
       ~message:
         (Printf.sprintf "contract registry: no row for %s"
            (Canary_agreement.string_of_agreement_id id))

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
  | Blocked of Canary_agreement.agreement_id list
  | Empty

let mark_of_status = function
  | Wired -> "✓"
  | Declared -> "~"
  | Blocked _ -> "⊘"
  | Empty -> "·"

(** The COLUMNS — the general action space one lang's chain can carry
    (the action catalogue, SSOT §6.5). Actions with no cell wired yet
    still appear: the empty columns ARE the picture. *)
let matrix_actions (l : Canary_lang.lang) : Canary_basic.action list =
  [ Canary_basic.Fetch Canary_basic.Source;
    Canary_basic.Configure;
    Canary_basic.Scan_sources;
    Canary_basic.Build_headers;
    Canary_basic.Fetch Canary_basic.Lib;
    Canary_basic.Build_lib;
    Canary_basic.Install_lib;
    Canary_basic.Fetch (Canary_basic.Binding l);
    Canary_basic.Build_binding l;
    Canary_basic.Publish Canary_basic.Lib;
    Canary_basic.Probe_lib;
    Canary_basic.Probe_binding l;
    Canary_basic.Build_app { Canary_basic.lang = l };
    Canary_basic.Probe_app { Canary_basic.lang = l } ]

let has_fixture (id : Canary_agreement.agreement_id) : bool =
  List.exists agreement_fixtures ~f:(fun (i, _) -> Poly.equal i id)

(** One cell's status under a concrete world. *)
let cell_status_of (r : agreement_row) ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(provision : Canary_store.provision)
    (a : Canary_basic.action) : cell_status =
  let fires =
    List.exists (r.ag_firing mechanism lang provision) ~f:(fun x ->
        Poly.equal x a)
  in
  if not fires then Empty
  else
    match r.ag_check.Canary_agreement.status with
    | Canary_agreement.Blocked deps -> Blocked deps
    | _ -> if has_fixture r.ag_check.Canary_agreement.id then Wired else Declared

(** THE matrix: rows = contracts, columns = actions, under one world. *)
let belief_matrix ?(mechanism = Canary_mechanism.Cstubs)
    ?(lang = Canary_lang.OCaml) ?(provision = Canary_store.Built) () :
    (agreement_row * (Canary_basic.action * cell_status) list) list =
  List.map agreement_registry ~f:(fun r ->
      ( r,
        List.map (matrix_actions lang) ~f:(fun a ->
            (a, cell_status_of r ~mechanism ~lang ~provision a)) ))

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
          (Canary_agreement.string_of_agreement_id r.ag_check.Canary_agreement.id)
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
    (Canary_agreement.agreement_id * Canary_basic.action) list =
  List.concat_map (belief_matrix ~mechanism ~lang ~provision ())
    ~f:(fun (r, cells) ->
      List.filter_map cells ~f:(fun (a, st) ->
          match st with
          | Declared -> Some (r.ag_check.Canary_agreement.id, a)
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
      prop_doc = "§5.4";
      prop_claim =
        "a recorded library identity denotes the SAME implementation in \
         the deploy world as in the build world";
      prop_reads = [ ("Sf.2", "native") ];
      prop_needs =
        "compare the object each soname names in both provisions of a \
         2x2 world — static, no loader, no declaration (§6.3)" };
    { prop_slug = "no_duplicate_implementation";
      prop_doc = "§5.4";
      prop_claim =
        "the resolved set contains no two identities that are one \
         implementation (alternative spelling), and none that statically \
         absorbs another (containment)";
      prop_reads = [ ("Sf.2", "native") ];
      prop_needs =
        "the shipped objects' symbol sets + version namespaces; the \
         declared alternative-spelling fact is a convenience (§6.6)" };
    { prop_slug = "closure_satisfiable";
      prop_doc = "§5.4";
      prop_claim =
        "every name in the consumer's recorded NEEDED has a provider in \
         this world";
      prop_reads = [ ("Sf.5", "binding"); ("Sf.2", "native") ];
      prop_needs = "readelf -d on the consumer + the world's object set" };
    { prop_slug = "interposition_winner";
      prop_doc = "§5.4";
      prop_claim =
        "the definition that wins for a shared symbol is the one the \
         consumer was built against";
      prop_reads = [ ("Trace", "run") ];
      prop_needs =
        "LD_DEBUG=bindings at probe — the RESOLVED view; evidence only, \
         no verdict of its own (§6.7)" } ]

(* ── the unified view — one list to print, cite and pin ── *)

type status = Implemented of Canary_agreement.agreement_status | Not_wired

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
        e_claim = r.ag_invariant;
        e_reads = r.ag_reads;
        e_status = Implemented r.ag_check.Canary_agreement.status })
  @ List.map proposed_agreements ~f:(fun p ->
        { e_slug = p.prop_slug;
          e_doc = p.prop_doc;
          e_claim = p.prop_claim;
          e_reads = p.prop_reads;
          e_status = Not_wired })

let string_of_status = function
  | Implemented s -> Canary_agreement.string_of_agreement_status s
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
