(** [Canary_project_spec] — the builder layer that wires project declarations
    into enumeration-ready [project_spec]s.

    Artifact identity types ([artifact_info], [artifact_axes], [project_spec],
    etc.) live in [Canary_artifact] (base/). This module provides the
    [artifact_row] builder (which knows about [Canary_store_config.provider]
    from tool/) and the build-dependency edges. *)

open Base
open Canary_artifact

(** A builder-style row for constructing a [project_spec] one artifact at a
    time. Wraps an [artifact_axes] with an optional provider for display.
    [project_spec_of_rows] converts a row list into a [project_spec]. *)
type artifact_row = {
  ar_artifact : artifact_info;
  ar_axes : artifact_axes;
  ar_provider : Canary_store_config.provider option;
  ar_rationale : string option;
      (** WHY this row's universe is what it is (2026-08-19, user: "add
          the project spec explanation ... to let other readers know our
          selection"). Where did each point of the axis come from, and —
          more importantly — why does the axis STOP there? A single-point
          axis is usually a fact about the world (apt ships one version;
          upstream publishes no Linux binary), not an omission, and
          without the rationale a reader cannot tell the two apart.
          Surfaced by `spec` and beside `spec-check`'s warnings. *)
}

let artifact_row ~artifact ~universe ?follows ?runtime ?provider ?rationale ()
    : artifact_row =
  let runtime =
    match runtime with
    | Some _ -> runtime
    | None -> Option.bind provider ~f:Canary_store_config.dep_mode_of_provider
  in
  (* STORE PINS (2026-08-12): the provider's declared versions project
     into the axes — same derivation pattern as [~runtime]. A project
     never hand-declares the pin axis. (2026-08-16, C1: the provider now
     projects [version] records, not [opam_pin]s — a [Repo_axes] family
     contributes per-channel pins with the CHANNEL PRESERVED, so the thin
     policy's [Subset [Stable]] drops the dev repos.) *)
  let pins =
    match Option.bind provider ~f:Canary_store_config.versions_of_provider with
    | Some vs ->
        List.map vs ~f:(fun v ->
            Canary_basic.{ channel = v.channel; id = v.id; quality = Good })
    | None -> []
  in
  let ax = axes ?runtime ?follows ~pins universe in
  { ar_artifact = artifact; ar_axes = ax; ar_provider = provider;
    ar_rationale = rationale }

(** From rows to spec: derive [ps_universe] from the row list. *)
let project_spec_of_rows (rows : artifact_row list) : project_spec =
  { ps_universe =
      List.map rows ~f:(fun r -> (r.ar_artifact, r.ar_axes)) }

(** The artifacts that [id] must be built from (build-dependency edges).
    Hardcoded for now: [Build_lib] consumes [Source]. When the action
    catalogue becomes available at this layer, this reads from it.
    Only returns artifacts that exist in [ps_universe] — a lib that
    builds from an undeclared source (e.g. sqlite's self-contained
    amalgamation) has no source build-dep. *)
let build_deps_of (s : project_spec) (id : artifact_info) : artifact_info list =
  let declared aid = Option.is_some (ps_axes_of s aid) in
  if equal_artifact_info id a_lib && declared a_source then [ a_source ] else []
