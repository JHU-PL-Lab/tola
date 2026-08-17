(** The contract registry — M2 step 6
    ([doc/canary/design/contract_registry.md], 2026-08-17).

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
  | Inspection      (** inputs → predict → compat-derived expectation *)
  | Behavior_grep   (** probe.log substring → failure expectation *)
  | Placeholder     (** Expect_success until wired (missing-ness visible) *)
[@@deriving show, eq]

type contract_row = {
  cr_check     : Canary_compat.contract_check;
      (** id / name / layer / status / enabled / predict — the
          existing pipeline ([Canary_compat_run.registered_checks]) *)
  cr_invariant : string;
      (** the one-sentence agreement, falsifier-phrased (design §5);
          the reconciliation point for ssot's Ag.X ↔ C1..C8 drift *)
  cr_role      : role;
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
      | Canary_store.Built -> [ Canary_basic.Build_binding l; probe ]
      | Canary_store.Fetched | Canary_store.Vendored | Canary_store.Absent ->
          [ probe ])

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

let row ~invariant ~role ~firing ~source ~tags
    (id : Canary_compat.contract_id) : contract_row =
  { cr_check = check_of id;
    cr_invariant = invariant;
    cr_role = role;
    cr_inputs =
      (fun m l ->
        Canary_compat_run.inputs_of_contract ~mechanism:m id l);
    cr_firing = firing;
    cr_source = source;
    cr_fault_tags = tags }

(** THE table — one row per contract (c1..c8). *)
let contract_registry : contract_row list =
  [ row C1
      ~invariant:
        "every symbol the binding declares (its stub references) is \
         exported by the lib"
      ~role:Surface ~firing:firing_default ~source:Inspection
      ~tags:[ "sym_missing" ];
    row C2
      ~invariant:
        "every watchlisted entry is present on the user-facing surface"
      ~role:Surface ~firing:firing_default ~source:Inspection
      ~tags:[ "api_drop" ];
    row C3
      ~invariant:"the probe's trace matches the recorded expectation"
      ~role:Execution ~firing:firing_probe_only ~source:Behavior_grep
      ~tags:[ "behavior" ];
    row C4
      ~invariant:
        "the lib's soname matches what the consumer records it needs"
      ~role:Surface ~firing:firing_default ~source:Inspection
      ~tags:[ "abi_soname" ];
    row C5
      ~invariant:
        "versioned symbols carry the annotations the consumer expects"
      ~role:Surface ~firing:firing_default ~source:Inspection
      ~tags:[ "sym_version" ];
    row C6
      ~invariant:"C types at the header/stub boundary match"
      ~role:Meeting ~firing:firing_default ~source:Inspection
      ~tags:[ "type_arity" ];
    row C7
      ~invariant:"repackaging preserves the API"
      ~role:Meeting ~firing:firing_probe_only ~source:Behavior_grep
      ~tags:[ "api_repack" ];
    row C8
      ~invariant:
        "repackaging is complete — nothing the original had is lost"
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
  [ ( Canary_compat.C1,
      { fx_inputs =
          [ Canary_compat.C_stub [ "stub.json" ];
            Canary_compat.Native_lib [ "lib.json" ] ];
        fx_bodies =
          [ ("stub.json", c_stub_body); ("lib.json", native_body) ];
        fx_expect = [ "tiny_offset" ] } );
    ( Canary_compat.C2,
      { fx_inputs = [ Canary_compat.Ocaml_mli [ "mli.json" ] ];
        fx_bodies = [ ("mli.json", mli_body) ];
        (* the dotted-name expansion variants *)
        fx_expect = [ "Llvm.Opcode.UncondBr"; "Opcode.UncondBr"; "UncondBr" ] } );
    ( Canary_compat.C2,
      { fx_inputs = [ Canary_compat.Python_attrs [ "py.json" ] ];
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
