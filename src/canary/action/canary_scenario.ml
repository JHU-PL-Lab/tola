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

(** Good scenarios from SSOT §4 — project-agnostic patterns.
    Each Sc.N describes a stage; language qualifiers appear
    as suffixes (Sc.N.<Lang>) for language-specific stages.
    Sc.1 is shared across languages (the native lib itself is
    language-agnostic).

    Concrete projects (tiny, z3, ...) instantiate the pattern
    with their own artifacts and probes. [perturbation = None]
    on all (good = no perturbation, by definition).

    {b Mechanism dimension — hardcoded to SCAB for now.} Binding
    mechanisms (SCAB = static C API binding via cext/cstubs;
    DFFI = dynamic FFI via ctypes; ...) currently collapse under
    a single SCAB assumption. Practical consequences:

    - Sc.1 stays shared even if we promote mechanism to an
      explicit axis later — the native lib is mechanism-agnostic.
    - OCaml scenarios (Sc.2.OCaml..Sc.6.OCaml) are all SCAB
      (tiny uses cstubs, no DFFI on the OCaml side).
    - Python scenarios (Sc.2.Python, Sc.4.Python) are the SCAB
      case (cext). ctypes = DFFI is not modeled today; when we
      add it, Sc.4.Python.cext (SCAB) and Sc.4.Python.ctypes
      (DFFI) become distinct, with an explicit mechanism →
      {stage × language} mapping replacing today's hardcoded
      list.

    Absence semantics (per user, 2026-07-07): a scenario is
    "shared" only when it's *exactly duplicated* across
    languages (Sc.1 case). Scenarios that don't exist for a
    language because the language has no such step (e.g. no
    Sc.3.Python — .py IS the app) are simply absent, not
    "skipped". Same for Sc.5/Sc.6 on the Python side — no
    Python helper in tiny, so those combinations don't
    exist. *)
let good_scenarios : scenario list =
  let open Canary_basic in
  let open Canary_lang in
  [
    (* Shared upstream *)
    { id = "Sc.1"; name = "build_native_lib";
      description = "Upstream — build the native library from source. \
                     Shared across languages (under the static C API \
                     binding assumption).";
      actions = [ Configure; Scan_sources; Build_lib; Install_lib ];
      related_artifacts = [ Source; Lib ];
      perturbation = None;
      belongs_to = [ "Sc.1" ] };

    (* OCaml side *)
    { id = "Sc.2.OCaml"; name = "build_binding";
      description = "Build the OCaml binding against the native lib.";
      actions = [ Build_binding OCaml ];
      related_artifacts = [ Lib; Binding OCaml ];
      perturbation = None;
      belongs_to = [ "Sc.2.OCaml" ] };
    { id = "Sc.3.OCaml"; name = "build_app_with_binding";
      description = "Build an OCaml app that links against the OCaml \
                     binding.";
      actions = [ Build_app ];
      related_artifacts = [ Binding OCaml; App ];
      perturbation = None;
      belongs_to = [ "Sc.3.OCaml" ] };
    { id = "Sc.4.OCaml"; name = "run_app_with_binding";
      description = "Run the OCaml app; loader resolves the native lib \
                     at load time.";
      actions = [ Probe App ];
      related_artifacts = [ Binding OCaml; Lib; App ];
      perturbation = None;
      belongs_to = [ "Sc.4.OCaml" ] };
    { id = "Sc.5.OCaml"; name = "build_app_helper";
      description = "Build the app via an intermediate helper library \
                     that wraps the OCaml binding.";
      actions = [ Build_app ];
      related_artifacts = [ Binding OCaml; App ];
      perturbation = None;
      belongs_to = [ "Sc.5.OCaml" ] };
    { id = "Sc.6.OCaml"; name = "run_app_helper";
      description = "Run the app-via-helper chain.";
      actions = [ Probe App ];
      related_artifacts = [ Binding OCaml; Lib; App ];
      perturbation = None;
      belongs_to = [ "Sc.6.OCaml" ] };

    (* Python side — no Sc.3.Python (.py IS the app, no build step);
       no Sc.5/Sc.6 (no Python helper in tiny). *)
    { id = "Sc.2.Python"; name = "build_binding";
      description = "Build the Python binding (cext) against the \
                     native lib.";
      actions = [ Build_binding Python ];
      related_artifacts = [ Lib; Binding Python ];
      perturbation = None;
      belongs_to = [ "Sc.2.Python" ] };
    { id = "Sc.4.Python"; name = "run_app_with_binding";
      description = "Run the Python cext probe under SCAB (import \
                     the binding; loader resolves the native lib). \
                     ctypes probe would be a same-shape run under \
                     DFFI, not modeled today.";
      actions = [ Probe App ];
      related_artifacts = [ Binding Python; Lib; App ];
      perturbation = None;
      belongs_to = [ "Sc.4.Python" ] };
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
