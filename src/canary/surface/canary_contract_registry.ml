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
    - WHERE it fires — stage-level [site] derived from mechanism ×
      provision (design §3);
    - the fault tags it answers to (step 9's mapping as data).

    Layering: surface/ — depends only on base/ + the surface theory.
    The action layer refines a [site] × lang into a concrete
    [Canary_scenario.firing_site] in phase 2. *)

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

(** Stage-level firing: WHERE a contract's check can manifest.
    [Build_site] — the build/link meeting ([Build_binding],
    [Build_app]); [Probe_site] — the load/run + the inspect
    attachments at probe. The action layer refines site × lang into
    [Canary_scenario.firing_site] in phase 2. *)
type site =
  | Build_site
  | Probe_site
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
  cr_firing    : Canary_mechanism.mechanism -> Canary_store.provision ->
                 site list;
      (** the default stage derivation (design §3): Static + Built →
          [build; probe]; Static + Fetched/Vendored → [probe] (no
          build step); Dynamic → [probe] (probe-only chains).
          Per-row refinements are the row's own function. *)
  cr_fault_tags : string list;
      (** step 9: sym_missing ↔ c1, … (scenario.md's catalogue) *)
}

(* ── the firing derivations ── *)

(** The default: mechanism × provision → stages. *)
let firing_default (m : Canary_mechanism.mechanism)
    (p : Canary_store.provision) : site list =
  match Canary_mechanism.discipline_of_mechanism m with
  | Canary_mechanism.Dynamic_ffi -> [ Probe_site ]
  | Canary_mechanism.Static_c_abi -> (
      match p with
      | Canary_store.Built -> [ Build_site; Probe_site ]
      | Canary_store.Fetched | Canary_store.Vendored | Canary_store.Absent ->
          [ Probe_site ])

(** Behavior needs a run — probe only, in every world. *)
let firing_probe_only (_ : Canary_mechanism.mechanism)
    (_ : Canary_store.provision) : site list = [ Probe_site ]

(* ── row assembly ── *)

let check_of (id : Canary_compat.contract_id) :
    Canary_compat.contract_check =
  List.find Canary_compat_run.registered_checks
    ~f:(fun ck -> Poly.equal ck.Canary_compat.id id)
  |> Option.value_exn
       ~message:
         (Printf.sprintf "contract registry: no registered check for %s"
            (Canary_compat.string_of_contract_id id))

let row ~invariant ~role ~firing ~tags
    (id : Canary_compat.contract_id) : contract_row =
  { cr_check = check_of id;
    cr_invariant = invariant;
    cr_role = role;
    cr_inputs =
      (fun m l ->
        Canary_compat_run.inputs_of_contract ~mechanism:m id l);
    cr_firing = firing;
    cr_fault_tags = tags }

(** THE table — one row per contract (c1..c8). *)
let contract_registry : contract_row list =
  [ row C1
      ~invariant:
        "every symbol the binding declares (its stub references) is \
         exported by the lib"
      ~role:Surface ~firing:firing_default ~tags:[ "sym_missing" ];
    row C2
      ~invariant:
        "every watchlisted entry is present on the user-facing surface"
      ~role:Surface ~firing:firing_default ~tags:[ "api_drop" ];
    row C3
      ~invariant:"the probe's trace matches the recorded expectation"
      ~role:Execution ~firing:firing_probe_only ~tags:[ "behavior" ];
    row C4
      ~invariant:
        "the lib's soname matches what the consumer records it needs"
      ~role:Surface ~firing:firing_default ~tags:[ "abi_soname" ];
    row C5
      ~invariant:
        "versioned symbols carry the annotations the consumer expects"
      ~role:Surface ~firing:firing_default ~tags:[ "sym_version" ];
    row C6
      ~invariant:"C types at the header/stub boundary match"
      ~role:Meeting ~firing:firing_default ~tags:[ "type_arity" ];
    row C7
      ~invariant:"repackaging preserves the API"
      ~role:Meeting ~firing:firing_probe_only ~tags:[ "api_repack" ];
    row C8
      ~invariant:
        "repackaging is complete — nothing the original had is lost"
      ~role:Meeting ~firing:firing_default ~tags:[ "api_add" ] ]

(** Total lookup over the table. *)
let row_of (id : Canary_compat.contract_id) : contract_row =
  List.find contract_registry ~f:(fun r ->
      Poly.equal r.cr_check.Canary_compat.id id)
  |> Option.value_exn
       ~message:
         (Printf.sprintf "contract registry: no row for %s"
            (Canary_compat.string_of_contract_id id))
