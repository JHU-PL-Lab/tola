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
  id : string;                       (** "Sc.N" or "Bs.N" *)
  name : string;
  description : string;
  actions : Canary_basic.rule list;
  related_artifacts : Canary_basic.artifact_kind list;
  perturbation : perturbation option;
}
