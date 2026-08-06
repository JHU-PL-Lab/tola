(** tiny-full — the PROJECT (peer of [canary_project_z3] / [_sqlite]).

    The mutation-agnostic general project over tiny's cached artifacts
    (ssot §4.2.5). The split this module realizes:

    - the **factory** ([Canary_tiny_scenario] + [Canary_tiny_workspace]) MAKES
      the ingredients — every artifact variant as a cached artifact — and holds
      the tiny1 oracle (`canary tiny run`);
    - this **project_spec** DECLARES those ingredients + the scenario space;
    - the **runner** ([canary_main]) EXPLORES them via `canary action tiny-full`:
      enumerate → runner_spec (which assembles tiny's vendored tree) → run, with
      canary computing the expectation ([expectation_agnostic]).

    A project DECLARES; canary COMPUTES. The declarative surface is the
    [project_run] below ([tiny_full_run]); `action tiny-full` runs it through
    the generic [canary_main.run_project_run] — the SAME path sqlite uses (the
    convergence: one runner, per-project specs). The scenario set is NOT
    declared here: [pr_spec] is the static declaration and the general
    algorithm ([Canary_project_run.scenarios_of]) enumerates it. Remaining
    convergence work: relocate the spec internals, which physically live in
    the factory file for now (tightly coupled to its [engine_*] data); the
    multi-bad [tiny_full_combinations] stay tiny-factory machinery. *)

module TS = Canary_tiny_scenario

(* Project identity IS [tiny_full_run] below (SSOT §6.1 top level; A6: the
   never-read [Canary_project.project] bundle was deleted 2026-08-05). The
   contract firing table stays where it is consumed:
   [TS.tiny_contract_bindings] → [tiny_expectation_agnostic]. *)

(* ── the declarative project surface ── *)

(** tiny-full's declared artifact set (source, lib, the three binding
    instances, both app wirings) — all [Vendored]. *)
let artifacts : Canary_enumerate.artifact_id list = TS.tiny_full_artifacts

(** The mutation-agnostic spec: which artifacts, and the bad-variant catalogue
    (tags) per artifact. *)
let spec : TS.tiny_full_spec = TS.tiny_full_spec

(** tiny-full's GENERAL declared spec (NO mutations): the good baseline +
    built-lib variants all fall out of enumerating this — the general axes,
    like sqlite. The mutation faults (flavor-1) are tiny1's oracle
    (`canary tiny run`), decoupled from tiny-full;
    [TS.tiny_full_assignments]/[TS.tiny_full_combinations] remain in the
    tiny-factory for tiny1 / a future post-process. *)
let general_spec : Canary_enumerate.project_spec =
  TS.tiny_full_general_spec spec

(** The expectation canary uses: derived by inspection alone (no oracle) —
    canary decides per step whether to expect a failure. *)
let expectation_agnostic
  : Canary_basic.action -> Canary_store.location option ->
    Canary_step_model.step_expectation
  = TS.tiny_expectation_agnostic

(* ── the run entry consumed by `action tiny-full` ── *)

(** Render the positive-variant enumeration view. *)
let print_view : unit -> unit = TS.print_tiny_full

(* ── tiny-full's implementation of the [Canary_project_run.project_run]
   interface (shared with sqlite; the generic runner consumes it) ── *)
type project_run = Canary_project_run.project_run

(** The cached-artifact overlays a bad assignment asks for: each [Bad]-quality
    placement → (artifact key, tag). All-good ⇒ []. The general half is
    [Canary_enumerate.bad_placements]; only the tag → cache-key mapping is
    tiny's. *)
let overlays_of (a : Canary_enumerate.assignment) : (string * string) list =
  Base.List.filter_map (Canary_enumerate.bad_placements a) ~f:(fun (_, tag) ->
      Base.Option.map (Canary_tiny_workspace.artifact_key_of_tag tag)
        ~f:(fun key -> (key, tag)))

(* Static per-artifact provider TABLE (typed data, A8; the real vendored
   layout — canary_tiny_workspace.ml paths). All Vendored (the lib is a
   Cached built artifact); tiny-full is agnostic to tiny's prepare layer
   beyond these paths. Built from the declared artifact list via a per-kind
   map so the artifact set stays single-source. *)
let tiny_providers :
    (Canary_enumerate.artifact_id * Canary_store_config.provider) list =
  let provider_of_kind : Canary_basic.artifact_kind ->
      Canary_store_config.provider option = function
    | Canary_basic.Source ->
        Some (Canary_store_config.Vendored "canary/examples/tiny/c (C source + include)")
    | Canary_basic.Lib ->
        Some
          (Canary_store_config.Cached
             "canary/examples/tiny/scenarios/_cache (libtiny.so.1)")
    | Canary_basic.Binding Canary_lang.OCaml ->
        Some (Canary_store_config.Vendored "canary/examples/tiny/ocaml (cstubs source)")
    | Canary_basic.Binding Canary_lang.Python ->
        Some
          (Canary_store_config.Vendored
             "canary/examples/tiny/python_cext/tiny_cext (cext + ctypes)")
    | Canary_basic.App ->
        Some (Canary_store_config.Vendored "tiny probe example (assembled)")
    | _ -> None
  in
  Base.List.filter_map artifacts ~f:(fun id ->
      Base.Option.map (provider_of_kind (Canary_enumerate.kind_of id))
        ~f:(fun p -> (id, p)))

(** tiny-full as a [project_run] the generic runner consumes. Its [pr_runner_spec]
    ASSEMBLES tiny's vendored cached artifacts into a tree (all-good ⇒ the witness
    base; built-lib ⇒ compiled source tree; bad ⇒ overlay) and returns the base
    spec over that tree with the AGNOSTIC expectation. The assemble step is the
    tiny-factory concern ([Canary_tiny_workspace]) — it lives INSIDE the runner_spec
    closure and the general interface has no pre-placement hook for it. tiny-full
    ignores the runner-provided [workspace] dir (it runs over its assembled tree);
    a real project (sqlite) builds into that dir instead. *)
(* ── dispatch / realization split ──
   [scenario_case] is the PURE dispatch result — inspectable data computed
   from enumeration coordinates only (general reads:
   [Canary_enumerate.provision_of]/[channel_of]/[provided]/[bad_placements]);
   [realize] maps a case to its realization: WHICH tiny-factory materializer
   assembles the tree + the base command templates. [pr_runner_spec] is just
   their composition — no placement digging inside it. *)
type scenario_case =
  | Base                               (* the all-vendored good witness *)
  | Built_lib of Canary_basic.channel  (* lib compiled from source @channel *)
  | Dev_binding of { lib_built : Canary_basic.channel option }
      (* dev OCaml cstubs binding (the tiny_scale consumer — the mismatch
         axis); [lib_built = Some ch] when the lib is also Built @ch,
         [None] = over the vendored stable lib *)
  | Assembled of (string * string) list
      (* bad-overlay scenarios: (cache key, tag) — tiny1/factory machinery *)

let dispatch (a : Canary_enumerate.assignment) : scenario_case =
  let module E = Canary_enumerate in
  let a_oc = E.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs in
  match overlays_of a with
  | (_ :: _) as overlays -> Assembled overlays
  | [] ->
      let lib_built =
        match E.provision_of a E.a_lib with E.Built -> true | _ -> false
      in
      let binding_dev =
        E.provided a a_oc
        && (match E.channel_of a a_oc with
            | Canary_basic.Dev -> true
            | Canary_basic.Stable -> false)
      in
      if binding_dev then
        Dev_binding
          { lib_built =
              (if lib_built then Some (E.channel_of a E.a_lib) else None) }
      else if lib_built then Built_lib (E.channel_of a E.a_lib)
      else Base

let realize (c : scenario_case) : Canary_step_builder.runner_spec =
  let chan_str = function
    | Canary_basic.Dev -> "dev"
    | Canary_basic.Stable -> "stable"
  in
  (* the lib's channel drives the channel-aware build (Dev ⇒ -DTINY_DEV +
     dev version script) on the Built path; Stable otherwise. *)
  let channel =
    match c with
    | Built_lib ch | Dev_binding { lib_built = Some ch } -> ch
    | Base | Dev_binding { lib_built = None } | Assembled _ ->
        Canary_basic.Stable
  in
  (* WHICH materializer assembles the tree (tiny-factory; labels carry the
     axes so distinct cases get distinct trees + variant_ids — cache.md). *)
  let assembled =
    match c with
    | Base -> Some (Canary_tiny_workspace.witness_base_workspace ())
    | Built_lib ch ->
        Canary_tiny_workspace.materialize_built_lib
          ~label:("positive-built-lib-" ^ chan_str ch)
    | Dev_binding { lib_built } ->
        let lib_desc =
          match lib_built with
          | Some ch -> "built-lib-" ^ chan_str ch
          | None -> "vendored-lib"
        in
        Canary_tiny_workspace.materialize_dev_binding
          ~lib_built:(Base.Option.is_some lib_built)
          ~label:("dev-binding-over-" ^ lib_desc)
    | Assembled overlays ->
        let label =
          Base.String.concat ~sep:"+"
            (Base.List.map overlays ~f:(fun (id, t) -> id ^ "#" ^ t))
        in
        Canary_tiny_workspace.materialize_assembled ~overlays ~label
  in
  let tree =
    match assembled with
    | Some w -> w
    | None -> failwith "tiny-full: workspace assembly failed"
  in
  let lib_filename =
    Canary_tiny_workspace.detect_lib_filename ~workspace:tree
  in
  let stores = TS.stores_of_workspace ~lib_filename ~workspace_root:tree () in
  { (TS.make_base_runner_spec ~channel ~stores ()) with
    Canary_step_builder.expectation = expectation_agnostic }

let tiny_full_run : project_run =
  { pr_name = "tiny-full";
    pr_artifacts = artifacts;
    (* the STATIC declaration (good baseline + built-lib axes; no mutations —
       those are tiny1's oracle). The generic runner enumerates it
       ([Canary_project_run.scenarios_of]) — like sqlite, a positive-only
       general project_run with no scenario list of its own. *)
    pr_spec = general_spec;
    (* tiny-full ignores the runner-provided [workspace]: its realizations
       assemble the vendored tree themselves (tiny-factory concern). *)
    pr_runner_spec = (fun a ~workspace:_ -> realize (dispatch a));
    pr_provenance = tiny_providers;
    (* the ocaml_dev cstubs variant is the DESIGNED forward probe: it
       requires the dev-only [tiny_scale], so deploying it over a stable lib
       reveals the forward mismatch (shipped 2026-08-05; status §B). No
       backward probe in the general run — backward breaks are tiny1's
       mutations (Bs.3/Bs.4). *)
    pr_mismatch_probes =
      [ ( Canary_enumerate.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs,
          Canary_basic.Dev, Canary_enumerate.Forward ) ];
    (* Undeclared this slice: tiny's vendored bindings carry their build-lib
       identity inside the cached artifact (V:S built against stable lib,
       V:D against dev) — a per-VARIANT build-lib, which the static
       per-edge table can't express yet. Declare when the finer key lands. *)
    pr_runtime_edges = [] }

(* ── THIN subset run (ssot §4.2 config level = Subset) ──
   The thin slice is a RUNNER policy ([Canary_project_run.thin_policy] —
   version [Subset [Stable]]) applied to the SAME declared spec; nothing
   thin-specific lives in the project. This record only renames the run so
   its cache never clashes with the full run's; `action/spec tiny-full
   --thin` pairs it with [thin_policy]. *)
let tiny_full_thin_run : project_run =
  { tiny_full_run with pr_name = "tiny-full-thin" }
