(** Scenario type — project-agnostic, unified for good and bad.

    A [scenario] names a collection of actions over related
    artifacts. Good scenarios (Sc.N) have [perturbation = None];
    bad scenarios (Bs.N) attach a [perturbation] targeting one of
    the related artifacts. From the artifact's perspective there
    is no structural difference — a bad scenario is just a
    scenario whose world has one mutation.

    Design notes (per [doc/canary/design/ssot.md] §5 / §6 / §9.3):

    - [related_artifacts] is hand-listed for now. A future
      helper [consumes/produces : rule -> artifact_kind list] on
      the action graph will let us derive it — postponed.
    - [id] is a string. [Sc_id.t] as a distinct type is deferred
      until the Sc.N / Bs.N enumeration stabilises.
    - [manifest] and [detector] on [perturbation] are
      possibilistic — they depend on tool strictness and probe
      design. Encoded here so the code can talk about
      "may-manifest" and "detection-gap" cases; they're
      annotations on the constructed scenario, not part of the
      physical setup.
    - [perturbation_kind] reuses [artifact_kind] for
      artifact-flavoured perturbations, with [On_behavior] as the
      one artifact-agnostic case (source patch with no surface
      change). Package perturbations use
      [On_artifact <package-flavoured-kind>] once tiny grows a
      package variant. *)

(* ---------- perturbation ---------- *)

type perturbation_kind =
  | On_artifact of Canary_basic.artifact_kind
      (** [Source] → source patch;
          [Lib] → binary surgery on the built lib;
          [Binding L] → source patch on that binding's files;
          [Headers] → header patch;
          [App] → app-level mutation. *)
  | On_behavior
      (** Source-level change that leaves the surface intact —
          [behavior_silent] is the canonical case. Distinct
          because no surface comparator can catch it; only
          runtime probes can. *)

(** Where the failure produced by a perturbation surfaces.
    Possibilistic — depends on tool strictness (e.g. mold vs
    permissive linker) and probe design. *)
type manifest =
  | Definite of string       (** always at this scenario id (Sc.N) *)
  | Possible of string list  (** one of these, tool-dependent *)
  | Unknown_gap              (** no known manifestation today (agreement gap) *)

(** Which checker catches the perturbation, if any. Also
    possibilistic — [Detector_gap] means no checker is wired for
    this perturbation today; the perturbation constructs a bad
    artifact that no comparator observes. *)
type detector =
  | Wired of Canary_compat.contract_id
  | Detector_gap

type perturbation = {
  target   : Canary_basic.artifact_kind;
                             (** the perturbed artifact —
                                 invariant: must appear in the
                                 owning scenario's
                                 [related_artifacts]. *)
  kind     : perturbation_kind;
  manifest : manifest;
  detector : detector;
}

(* ---------- scenario ---------- *)

(** Unified scenario — good scenarios have [perturbation = None];
    bad scenarios attach a [perturbation]. *)
type scenario = {
  id : string;                       (** "Sc.N" or "Bs.N" or "Pc.N" *)
  name : string;
  description : string;
  actions : Canary_basic.rule list;
  related_artifacts : Canary_basic.artifact_kind list;
  perturbation : perturbation option;
  belongs_to : string list;          (** which Sc.N(s) this scenario
                                         relates to. For a Good scenario:
                                         its own id. For a Bad scenario:
                                         the Good scenario whose
                                         artifacts are perturbed
                                         (perturbed_at). For a Positive-
                                         coverage scenario: the Good
                                         scenarios it verifies. *)
}

(* ---------- Good scenarios (Sc.1..Sc.6) ---------- *)

(** The six good scenarios from SSOT §4 — project-agnostic
    patterns. Each Sc.N describes a stage; concrete projects
    (tiny, z3, ...) instantiate the pattern with their own
    artifacts and probes. [perturbation = None] on all of them
    (good = no perturbation, by definition). *)
let good_scenarios : scenario list =
  let open Canary_basic in
  let open Canary_lang in
  [
    { id = "Sc.1"; name = "build_native_lib";
      description = "Upstream — build the native library from source.";
      actions = [ Configure; Scan_sources; Build_lib; Install_lib ];
      related_artifacts = [ Source; Lib ];
      perturbation = None;
      belongs_to = [ "Sc.1" ] };
    { id = "Sc.2"; name = "build_binding";
      description = "Binding creation — build language bindings against \
                     the native lib.";
      actions = [ Build_binding OCaml; Build_binding Python ];
      related_artifacts = [ Lib; Binding OCaml; Binding Python ];
      perturbation = None;
      belongs_to = [ "Sc.2" ] };
    { id = "Sc.3"; name = "build_app_with_binding";
      description = "Binding use (direct) — build an app that links \
                     against a binding.";
      actions = [ Build_app ];
      related_artifacts = [ Binding OCaml; Binding Python; App ];
      perturbation = None;
      belongs_to = [ "Sc.3" ] };
    { id = "Sc.4"; name = "run_app_with_binding";
      description = "Binding use (direct) — run the app against the \
                     binding + native lib at runtime.";
      actions = [ Probe App ];
      related_artifacts = [ Binding OCaml; Binding Python; Lib; App ];
      perturbation = None;
      belongs_to = [ "Sc.4" ] };
    { id = "Sc.5"; name = "build_app_helper";
      description = "Binding use (indirect) — build an app via a helper \
                     library that wraps the binding.";
      actions = [ Build_app ];
      related_artifacts = [ Binding OCaml; App ];
      perturbation = None;
      belongs_to = [ "Sc.5" ] };
    { id = "Sc.6"; name = "run_app_helper";
      description = "Binding use (indirect) — run the app-via-helper chain.";
      actions = [ Probe App ];
      related_artifacts = [ Binding OCaml; Lib; App ];
      perturbation = None;
      belongs_to = [ "Sc.6" ] };
  ]

(* ---------- validators ---------- *)

(** Validate a Sc.N string against the [good_scenarios] catalogue.
    Returns [s] unchanged if valid; raises [Failure] with a
    helpful message otherwise. Used to catch typos in
    [manifest = Definite "Sc.4"] etc. at start-up.

    Closes drift risk #1 from the status report. *)
let sc_id_of_string (s : string) : string =
  match Base.List.find good_scenarios
          ~f:(fun g -> Base.String.equal g.id s) with
  | Some _ -> s
  | None ->
    let known = Base.List.map good_scenarios ~f:(fun g -> g.id) in
    Stdlib.failwith
      (Printf.sprintf "unknown Sc.N: %S. Known: %s"
         s (Base.String.concat ~sep:", " known))

(** Invariant check: if a scenario has a [perturbation], its
    [target] must be in [related_artifacts]. Raises [Failure] on
    violation. Closes drift risk #3 from the status report. *)
let validate_perturbation_target (s : scenario) : unit =
  match s.perturbation with
  | None -> ()
  | Some p ->
    if not (Base.List.mem s.related_artifacts p.target
              ~equal:Base.Poly.equal) then
      Stdlib.failwith
        (Printf.sprintf
           "scenario %s (%s): perturbation.target not in \
            related_artifacts" s.id s.name)

(** Validate that all Sc.N strings in a scenario's manifest are
    known. Combined with [validate_perturbation_target], gives a
    full structural check per scenario. *)
let validate_manifest_sc_ids (s : scenario) : unit =
  match s.perturbation with
  | None -> ()
  | Some p ->
    match p.manifest with
    | Definite sc -> let _ = sc_id_of_string sc in ()
    | Possible xs ->
      Base.List.iter xs ~f:(fun sc ->
        let _ = sc_id_of_string sc in ())
    | Unknown_gap -> ()

(** Validate that all Sc.N strings in [belongs_to] are known. *)
let validate_belongs_to (s : scenario) : unit =
  Base.List.iter s.belongs_to ~f:(fun sc ->
    let _ = sc_id_of_string sc in ())

(** Full structural check on a scenario. Raises on any
    invariant violation. *)
let validate_scenario (s : scenario) : unit =
  validate_perturbation_target s;
  validate_manifest_sc_ids s;
  validate_belongs_to s
