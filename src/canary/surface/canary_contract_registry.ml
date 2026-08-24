(** The contract registry — M2 step 6
    ([doc/canary/design/agreement_registry_audit.md], 2026-08-17; the
    former contract_registry.md merged into it 2026-08-21).

    Producer-first: the BELIEF in one table — one row per contract.
    Consumers (the expectation lowering, the per-project binding
    tables, spec-check, the tiny oracle) migrate in phase 2; until
    then this module is additive and nothing reads it but the pins.

    A row states:
    - WHAT the invariant is ([cr_invariant], falsifier-phrased — a
      check is a DISPROVER, never a proof, design §5);
    - HOW we check it — the existing [Canary_compat.contract_check]
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

type contract_row = {
  cr_check     : Canary_compat.contract_check;
      (** id / name / layer / status / enabled / predict — the
          existing pipeline ([Canary_compat_run.registered_checks]) *)
  cr_invariant : string;
      (** the one-sentence agreement, falsifier-phrased (design §5);
          the reconciliation point for ssot's Ag.X ↔ C1..C8 drift *)
  cr_reads     : (string * string) list;
      (** THE GROUNDING: which artifact-surface roles the cell's
          evidence reads — (surface_role, side), e.g. ("Sf.3",
          "binding"). The draft's five surfaces (Sf.1 native_header,
          Sf.2 native_lib, Sf.3 binding_stub, Sf.4 binding_header,
          Sf.5 binding_lib) + "Trace" (the runtime observation). A
          contract IS a named relation over these reads; the action
          says where the read attaches. *)
  cr_role      : role;
      (** PROSE tag at most (Surface/Meeting/Execution — the legacy
          evidence vocabulary). NOT a typed axis: the action column
          already implies the cell's subject (one artifact vs a pair)
          and its evidence flavor; the typed axis is [source] — how
          the expectation is produced. *)
  cr_inputs    : Canary_mechanism.mechanism -> Canary_lang.lang ->
                 Canary_compat.inspect_input list;
      (** the step-2 template ([Canary_compat_run.inputs_of_contract]) *)
  cr_firing    : Canary_mechanism.mechanism -> Canary_lang.lang ->
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
  cr_source    : source;
      (** HOW the expectation comes to be — the expectation half of
          the belief, mirroring the old per-project expectation_source
          shapes without their payload (inputs come from the template,
          version context from the scenario). *)
  cr_fault_tags : string list;
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

let check_of (id : Canary_compat.contract_id) :
    Canary_compat.contract_check =
  List.find Canary_compat_run.registered_checks
    ~f:(fun ck -> Poly.equal ck.Canary_compat.id id)
  |> Option.value_exn
       ~message:
         (Printf.sprintf "contract registry: no registered check for %s"
            (Canary_compat.string_of_contract_id id))

let row ~invariant ~reads ~role ~firing ~source ~tags
    (id : Canary_compat.contract_id) : contract_row =
  { cr_check = check_of id;
    cr_invariant = invariant;
    cr_reads = reads;
    cr_role = role;
    cr_inputs =
      (fun m l ->
        Canary_compat_run.inputs_of_contract ~mechanism:m id l);
    cr_firing = firing;
    cr_source = source;
    cr_fault_tags = tags }

(** THE table — one row per contract (c1..c8). Each row's [cr_reads]
    grounds the evidence in the artifact surfaces it reads — the
    contract IS a named relation over those reads. *)
let contract_registry : contract_row list =
  [ row C1
      ~invariant:
        "every symbol the binding declares (its stub references) is \
         exported by the lib"
      ~reads:[ ("Sf.3", "binding"); ("Sf.2", "native") ]
      ~role:Surface ~firing:firing_with_build_lib ~source:Inspection
      ~tags:[ "sym_missing" ];
    row C2
      ~invariant:
        "every watchlisted entry is present on the user-facing surface"
      ~reads:[ ("Sf.4", "binding") ]
      ~role:Surface ~firing:firing_default ~source:Inspection
      ~tags:[ "api_drop" ];
    row C3
      ~invariant:"the probe's trace matches the recorded expectation"
      ~reads:[ ("Trace", "run") ]
      ~role:Execution ~firing:firing_probe_only ~source:Behavior_grep
      ~tags:[ "behavior" ];
    row C4
      ~invariant:
        "the lib's soname matches what the consumer records it needs"
      ~reads:[ ("Sf.2", "native"); ("Sf.5", "binding") ]
      ~role:Surface ~firing:firing_with_build_lib ~source:Inspection
      ~tags:[ "abi_soname" ];
    row C5
      ~invariant:
        "versioned symbols carry the annotations the consumer expects"
      ~reads:[ ("Sf.2", "native"); ("Sf.5", "binding") ]
      ~role:Surface ~firing:firing_with_build_lib ~source:Inspection
      ~tags:[ "sym_version" ];
    row C6
      ~invariant:"C types at the header/stub boundary match"
      ~reads:[ ("Sf.1", "native"); ("Sf.3", "binding") ]
      ~role:Meeting ~firing:firing_default ~source:Inspection
      ~tags:[ "type_arity" ];
    row C7
      ~invariant:"repackaging preserves the API"
      ~reads:[ ("Sf.4", "binding") ]
      ~role:Meeting ~firing:firing_probe_only ~source:Behavior_grep
      ~tags:[ "api_repack" ];
    row C8
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
   [Canary_compat]). *)

type fixture = {
  fx_predict :
    (resolve:(string -> string) ->
     Canary_compat.inspect_input list -> string list) option;
      (** the closure under test — [None] = the row's
          [cr_check.predict]. Some = a CELL predict (e.g. the
          decl-comparison closures for the lib-only cells). *)
  fx_inputs : Canary_compat.inspect_input list;
      (** input-file references ([C_stub], [Native_lib], [Ocaml_mli],
          [Python_attrs], …) *)
  fx_bodies : (string * string) list;
      (** file name → synthetic inspect JSON (the [resolve] source) *)
  fx_expect : string list;
      (** the failure substrings [predict] must yield *)
}

let contract_fixtures : (Canary_compat.contract_id * fixture) list =
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
  [ ( Canary_compat.C1,
      (* the LIB-ONLY cell: every declared c_api function exported by
         the built lib (sym_missing at the source, no binding) *)
      { fx_predict =
          Some
            (Canary_compat_run.c1_decl_predict
               ~declared_functions:
                 [ "tiny_sum"; "tiny_diff"; "tiny_offset" ]);
        fx_inputs = [ Canary_compat.Native_lib [ "lib.json" ] ];
        fx_bodies = [ ("lib.json", c1_lib_body) ];
        fx_expect = [ "tiny_offset" ] } );
    ( Canary_compat.C4,
      (* the LIB-ONLY cell: the built lib's elf soname vs the declared *)
      { fx_predict =
          Some
            (Canary_compat_run.c4_decl_predict
               ~declared_soname:"libtiny.so.1");
        fx_inputs = [ Canary_compat.Native_lib [ "lib.json" ] ];
        fx_bodies = [ ("lib.json", c4_lib_body) ];
        fx_expect = [ "soname libtiny.so.2 != declared libtiny.so.1" ] } );
    ( Canary_compat.C5,
      (* the LIB-ONLY cell: the version script applied — the declared
         tag must appear among the built lib's @@VER annotations *)
      { fx_predict =
          Some
            (Canary_compat_run.c5_decl_predict ~declared_tags:[ "TINY_2.0" ]);
        fx_inputs = [ Canary_compat.Versioned_exports [ "lib.json" ] ];
        fx_bodies = [ ("lib.json", c5_lib_body) ];
        fx_expect = [ "version TINY_2.0 not exported" ] } );
    ( Canary_compat.C1,
      { fx_predict = None;
        fx_inputs =
          [ Canary_compat.C_stub [ "stub.json" ];
            Canary_compat.Native_lib [ "lib.json" ] ];
        fx_bodies =
          [ ("stub.json", c_stub_body); ("lib.json", native_body) ];
        fx_expect = [ "tiny_offset" ] } );
    ( Canary_compat.C2,
      { fx_predict = None;
        fx_inputs = [ Canary_compat.Ocaml_mli [ "mli.json" ] ];
        fx_bodies = [ ("mli.json", mli_body) ];
        (* the dotted-name expansion variants *)
        fx_expect = [ "Llvm.Opcode.UncondBr"; "Opcode.UncondBr"; "UncondBr" ] } );
    ( Canary_compat.C2,
      { fx_predict = None;
        fx_inputs = [ Canary_compat.Python_attrs [ "py.json" ] ];
        fx_bodies = [ ("py.json", py_body) ];
        fx_expect = [ "Solver.add"; "add"; "BitVec" ] } ) ]

(** Total lookup over the table. *)
let row_of (id : Canary_compat.contract_id) : contract_row =
  List.find contract_registry ~f:(fun r ->
      Poly.equal r.cr_check.Canary_compat.id id)
  |> Option.value_exn
       ~message:
         (Printf.sprintf "contract registry: no row for %s"
            (Canary_compat.string_of_contract_id id))

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
  | Blocked of Canary_compat.contract_id list
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

let has_fixture (id : Canary_compat.contract_id) : bool =
  List.exists contract_fixtures ~f:(fun (i, _) -> Poly.equal i id)

(** One cell's status under a concrete world. *)
let cell_status_of (r : contract_row) ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(provision : Canary_store.provision)
    (a : Canary_basic.action) : cell_status =
  let fires =
    List.exists (r.cr_firing mechanism lang provision) ~f:(fun x ->
        Poly.equal x a)
  in
  if not fires then Empty
  else
    match r.cr_check.Canary_compat.status with
    | Canary_compat.Blocked deps -> Blocked deps
    | _ -> if has_fixture r.cr_check.Canary_compat.id then Wired else Declared

(** THE matrix: rows = contracts, columns = actions, under one world. *)
let belief_matrix ?(mechanism = Canary_mechanism.Cstubs)
    ?(lang = Canary_lang.OCaml) ?(provision = Canary_store.Built) () :
    (contract_row * (Canary_basic.action * cell_status) list) list =
  List.map contract_registry ~f:(fun r ->
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
          (Canary_compat.string_of_contract_id r.cr_check.Canary_compat.id)
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
    (Canary_compat.contract_id * Canary_basic.action) list =
  List.concat_map (belief_matrix ~mechanism ~lang ~provision ())
    ~f:(fun (r, cells) ->
      List.filter_map cells ~f:(fun (a, st) ->
          match st with
          | Declared -> Some (r.cr_check.Canary_compat.id, a)
          | Wired | Blocked _ | Empty -> None))
