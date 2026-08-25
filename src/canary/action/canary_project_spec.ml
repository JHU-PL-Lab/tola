(** [Canary_project_spec] — the builder layer that wires project declarations
    into enumeration-ready [project_spec]s.

    Artifact identity types ([artifact_info], [artifact_axes], [project_spec],
    etc.) live in [Canary_artifact] (base/). This module provides the
    [artifact_row] builder (which knows about [Canary_store_config.provider]
    from tool/) and the build-dependency edges. *)

open Base
open Canary_artifact

(** A builder-style row: ONE artifact, and one declaration per admissible
    provision. [project_spec_of_rows] converts a row list into the coarse
    [project_spec] the enumeration reads.

    {1 One declaration, not two (2026-08-25)}

    A row used to carry a coarse [~universe] AND a separate [?provider]
    for the whole artifact, and the two only agreed for one of the
    provisions — sqlite's lib declared [Sys_pkg libsqlite3-dev] beside a
    universe of {Fetched, Built, Installed}, where the package explains
    only the Fetched case. Keeping them consistent needed a rule ("the
    provider's provision is a BASELINE") and a per-project pin.

    Now [~universe] carries a {!Canary_store_config.provision_spec} per
    entry, each stating its own origin, and everything else is DERIVED
    from it:

    - [ar_axes] — the coarse [(provision * channels)] view the
      enumeration ranges over, via [provision_of_spec]. Stored because
      the enumeration reads it hot, not declared.
    - the store pins — from the Fetched entry's provider.
    - [ax_runtime] — from the Fetched entry's provider, unless the row
      states it. The Fetched one is the right source and there is no
      ambiguity to resolve: [Ambient] means the PACKAGE bundles its own
      native lib, and a Built artifact is built here and bundles nothing.

    The relationship is the one the artifact identity already has:
    {v
    provision_spec  ──provision_of_spec──▶  provision
    artifact_info   ──kind_of────────────▶  artifact_kind
    v} *)
type artifact_row = {
  ar_artifact : artifact_info;
  ar_universe : (Canary_store_config.provision_spec * Canary_basic.channel list) list;
      (** THE declaration. Everything below is derived from it. *)
  ar_axes : artifact_axes;  (** derived coarse view — the enumeration's input *)
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

(** The row's FETCH origin, if it declares a Fetched provision. [None] is
    the honest answer for a row that is only built, staged or vendored —
    where the old model had to invent a provider. *)
let provider_of_row (r : artifact_row) : Canary_store_config.provider option =
  List.find_map r.ar_universe ~f:(fun (spec, _) ->
      Canary_store_config.fetch_provider_of spec)

(** Every (provision, version) point this row declares — [Absent]
    dropped, store pins expanded. The row-level face of
    {!Canary_artifact.ax_points}; see there for why the count is over
    POINTS rather than universe cells or channels. *)
let points_of_row (r : artifact_row) :
    (Canary_artifact.provision * Canary_basic.build_id) list =
  Canary_artifact.ax_points r.ar_axes

let artifact_row ~artifact ~universe ?follows ?runtime ?rationale ()
    : artifact_row =
  let fetch =
    List.find_map universe ~f:(fun (spec, _) ->
        Canary_store_config.fetch_provider_of spec)
  in
  let runtime =
    match runtime with
    | Some _ -> runtime
    | None -> Option.bind fetch ~f:Canary_store_config.dep_mode_of_provider
  in
  (* STORE PINS (2026-08-12): the Fetched entry's declared versions
     project into the axes. A project never hand-declares the pin axis.
     (2026-08-16, C1: a [Repo_axes] family contributes per-channel pins
     with the CHANNEL PRESERVED, so the thin policy's [Subset [Stable]]
     drops the dev repos.) *)
  let pins =
    match Option.bind fetch ~f:Canary_store_config.versions_of_provider with
    | Some vs ->
        List.map vs ~f:(fun v ->
            Canary_basic.{ channel = v.channel; id = v.id; quality = Good })
    | None -> []
  in
  let coarse =
    List.map universe ~f:(fun (spec, chs) ->
        (Canary_store_config.provision_of_spec spec, chs))
  in
  let ax = axes ?runtime ?follows ~pins coarse in
  { ar_artifact = artifact; ar_universe = universe; ar_axes = ax;
    ar_rationale = rationale }

(** From rows to spec: derive [ps_universe] from the row list. *)
let project_spec_of_rows (rows : artifact_row list) : project_spec =
  { ps_universe =
      List.map rows ~f:(fun r -> (r.ar_artifact, r.ar_axes)) }

(** The artifacts that [id] must be built from (build-dependency edges) —
    READ OFF THE ROWS since 2026-08-25.

    It used to be hardcoded:

    {[
      if id = a_lib && declared a_source then [ a_source ] else []
    ]}

    with a standing note that it should come from the catalogue. It never
    needed the catalogue — it needed the declaration to SAY it, which
    [Built_from] now does. Two things fall out: a lib that builds from an
    undeclared source (sqlite's self-contained amalgamation) simply has
    no [Built_from], and zarith's binding — built from
    [a_binding_source OCaml] rather than the lib's source — stops being a
    special case. *)
let build_deps_of_rows (rows : artifact_row list) (id : artifact_info) :
    artifact_info list =
  match List.find rows ~f:(fun r -> equal_artifact_info r.ar_artifact id) with
  | None -> []
  | Some r ->
      List.filter_map r.ar_universe ~f:(fun (spec, _) ->
          match spec with
          | Canary_store_config.Built_from src -> Some src
          | Canary_store_config.Absent | Canary_store_config.Fetched _
          | Canary_store_config.Installed | Canary_store_config.Vendored_at _ ->
              None)
      |> List.dedup_and_sort ~compare:Poly.compare

(** The coarse-spec form, for callers that only hold a [project_spec].
    Still hardcoded, and now visibly so: a [project_spec] has had the
    origins projected away, so this cannot do better. Callers with rows
    should use {!build_deps_of_rows}. *)
let build_deps_of (s : project_spec) (id : artifact_info) : artifact_info list =
  let declared aid = Option.is_some (ps_axes_of s aid) in
  if equal_artifact_info id a_lib && declared a_source then [ a_source ] else []
