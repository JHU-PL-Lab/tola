(** Project-agnostic scenario helpers.

    Small helpers used by scenario-driven projects, extracted
    from [Canary_tiny_scenario] 2026-07-08 so a second project
    can reuse them without a tiny dependency. No interface / no
    functor here — just plain functions.

    See [doc/canary/design/tiny.md] for how tiny wires the
    pieces together; other projects (z3/llvm/sqlite/…) may
    adopt these helpers once they take on scenarios. *)

open Base

(** Build a {!Canary_scenario.mutation} option. Convenience
    wrapper for the common case where callers construct a
    scenario with a mutation. *)
let pert
    ~(target : Canary_basic.artifact_kind)
    ~(kind : Canary_scenario.mutation_kind)
    ~(manifest : Canary_scenario.manifest)
    ~(detector : Canary_scenario.detector)
    : Canary_scenario.mutation option =
  Some { target; kind; manifest; detector }

(** Compact contract label — ["c1"..."c8"] via
    {!Canary_compat.string_of_contract_id}, or ["gap"] for
    [Detector_gap]. *)
let detector_short = function
  | Canary_scenario.Wired c -> Canary_compat.string_of_contract_id c
  | Canary_scenario.Detector_gap -> "gap"

(** 1-based index of an artifact in a scenario's
    [related_artifacts], or [None] if not present. *)
let artifact_index (sc : Canary_scenario.scenario)
    (target : Canary_basic.artifact_kind) : int option =
  let rec find i = function
    | [] -> None
    | a :: _ when Poly.equal a target -> Some i
    | _ :: rest -> find (i + 1) rest
  in
  find 1 sc.related_artifacts

(** For a bad scenario, format its target relative to a Good
    scenario's [related_artifacts]: ["A<idx>"] or
    ["A<idx> (behavior)"] for [On_behavior] kind. Used by
    display code. *)
let bad_target_str (good : Canary_scenario.scenario)
    (bad : Canary_scenario.scenario) : string =
  match bad.mutation with
  | None -> ""
  | Some p ->
    let idx_str = match artifact_index good p.target with
      | Some i -> Printf.sprintf "A%d" i
      | None -> "A?" in
    (match p.kind with
     | On_behavior -> Printf.sprintf "%s (behavior)" idx_str
     | On_artifact _ -> idx_str)

(** Does a bad scenario fill a derived cell? Match rule: same
    Good scenario (via [belongs_to] intersection) + same target
    artifact + same kind. Used to compute the "filled vs empty"
    coverage view over the [derive_scenarios] enumeration. *)
let matches_derived_cell
    (bad : Canary_scenario.scenario)
    (derived : Canary_scenario.scenario) : bool =
  match bad.mutation, derived.mutation with
  | Some bp, Some dp ->
    Poly.equal bp.target dp.target
    && Poly.equal bp.kind dp.kind
    && List.exists bad.belongs_to ~f:(fun b ->
         List.mem derived.belongs_to b ~equal:String.equal)
  | _ -> false

(** Human-readable contract label — ["Symbol"], ["ABI"],
    ["Type"], … Distinct from
    {!Canary_compat.string_of_contract_id} (["c1"..."c8"]).
    Used by tiny's [confirm_ill.json] and [tiny expected] output
    for legacy parity with the Python harness. General enough
    that any project emitting contract labels can reuse. *)
let violates_label = function
  | Canary_compat.C1 -> "Symbol"
  | C2 -> "API-completeness"
  | C3 -> "Behavior"
  | C4 -> "ABI"
  | C5 -> "SymbolVersion"
  | C6 -> "Type"
  | C7 -> "API-repacking"
  | C8 -> "API-faithfulness"
