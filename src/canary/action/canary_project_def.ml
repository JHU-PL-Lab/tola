(** [Canary_project_def] — DRAFT strawman for the detection-first,
    forecast-agnostic project definition (step 2 of
    [doc/canary/design/project_definition.md]).

    NOT wired into any runner yet. It exists so the {b shape} can be
    reviewed and so the [project-test] layer test can golden-string a
    [Derived] step and exercise the [api_source → surface] split. The
    old [Canary_project.project = { name; contract_bindings }] is left
    untouched (tiny still consumes it).

    Type names marked {b PLACEHOLDER} are unsettled — the project-vs-
    bundle name collision (§3) is decided when this graduates from
    strawman to the live type.

    The three concerns this file separates (was all fused into the old
    [runner_spec] + its [api_source]):

    - [surface] — the checking points (watchlists + expected
      symbols/soname/abi). What detection inspects. §3.3.
    - [store_config] — provenance: where the source / headers / lib /
      binding source code live, and how each artifact is fetched. The
      store owns this. Absorbs the provenance half of the old
      [api_source] ([components], [headers], [source_dir]).
    - [step_source] — [Derived] (generated from [store_config], the
      clean path) or [Raw] (a closure identical to the old runner_spec
      command — the escape hatch for bespoke shell). §3.1. *)

open Base

module Api = Canary_artifact_api
module SB = Canary_step_builder

(* ── surface: the checking points (ex-api_source, split) ── *)

type native_surface = {
  symbol_prefixes : string list;
  stable_symbols : string list; (* L1a: must be exported *)
  versioned_symbols : string list; (* L1b *)
  soname : string option; (* L4 *)
  c_runtime : string option;
  cxx_abi : string option;
}

type binding_surface = {
  module_watchlist : string list; (* L3 *)
  type_watchlist : string list; (* L2 *)
}

type surface = {
  native : native_surface;
  bindings : (Canary_lang.lang * binding_surface) list;
}

let empty_native_surface =
  {
    symbol_prefixes = [];
    stable_symbols = [];
    versioned_symbols = [];
    soname = None;
    c_runtime = None;
    cxx_abi = None;
  }

let empty_surface = { native = empty_native_surface; bindings = [] }

(** Migration helper — extract the checking-half from an existing
    {!Canary_artifact_api.t}. The provenance half ([components],
    [headers], [source_dir]) is dropped here because it goes to
    {!store_config} instead. z3 / llvm / tiny already carry an
    [api_source]; this is how they graduate to [surface]. *)
let surface_of_api (api : Api.t) : surface =
  let na : Api.native_api = api.native_api in
  {
    native =
      {
        symbol_prefixes = na.symbol_prefixes;
        stable_symbols = na.stable_symbols;
        versioned_symbols = na.versioned_symbols;
        soname = na.soname;
        c_runtime = na.c_runtime;
        cxx_abi = na.cxx_abi;
      };
    bindings =
      List.map api.binding_apis ~f:(fun (b : Api.binding_api) ->
          ( b.lang,
            {
              module_watchlist = b.module_watchlist;
              type_watchlist = b.type_watchlist;
            } ));
  }

(* ── store_config: provenance (where artifacts live / come from) ── *)

type lib_provenance = {
  system_pkg : Canary_store.system_package_spec option; (* fetch_lib: apt/brew *)
  components : Api.api_component list; (* moved from native_api: what the lib exposes *)
  headers : Api.headers_spec option; (* moved from native_api: header dir + files *)
}

type binding_provenance = {
  opam_pkg : Canary_toolchain.opam_package_spec option; (* fetch_binding (opam) *)
  pip_pkg : string option; (* fetch_binding (pip) *)
  source_dir : string option; (* moved from binding_api: gates Build_binding *)
}

type store_config = {
  source : Canary_artifact_source.source_repo option; (* src store *)
  lib : lib_provenance; (* lib store *)
  bindings : (Canary_lang.lang * binding_provenance) list; (* binding store per lang *)
}

let empty_lib_provenance = { system_pkg = None; components = []; headers = None }
let empty_store_config = { source = None; lib = empty_lib_provenance; bindings = [] }

(* ── steps: declarative Derived | Raw escape hatch ── *)

type store_slot =
  | Fetch_lib
  | Fetch_binding of Canary_lang.lang
  | Probe_lib
  | Probe_binding of Canary_lang.lang
  | Scan_source

type step_source =
  | Derived of store_slot
  | Raw of (output_dir:string -> variant_key:string -> string)

(* ── the runnable spec (PLACEHOLDER name — replaces runner_spec) ── *)

type spec = {
  name : string;
  surface : surface;
  stores : store_config;
  steps : (Canary_basic.action * step_source) list;
  contracts_in_scope : Canary_compat.contract_id list;
  (* NO expectation, NO violates, NO contract_bindings *)
}

(* ── the aggregation bundle (PLACEHOLDER name) ── *)

type suite = { suite_name : string; variants : spec list }

(* ── derivations that tie back to step 1 ── *)

let actions_of_spec (s : spec) : Canary_basic.action list =
  List.map s.steps ~f:fst

(** The detection-scope inventory — the deduped artifacts detection
    inspects, derived from the spec's steps via step 1's
    consumes relation. Forecast-agnostic: no hand-authored watchlist of
    "where failures fire". *)
let detection_inventory (s : spec) : Canary_basic.artifact_kind list =
  Canary_action.consumed_artifacts_of_actions (actions_of_spec s)

(* ── slot derivation (partial; Raw covers the rest) ──
   Proves compatibility: a [Derived] slot reuses the existing runner
   command helpers verbatim, so it emits exactly what the old
   runner_spec closure did. Only the two simplest slots are wired in
   this strawman; the rest return [None] (documented not-yet-wired). *)
let derive_slot ~(pm : Canary_store.package_manager) (cfg : store_config)
    (slot : store_slot) :
    (output_dir:string -> variant_key:string -> string) option =
  match slot with
  | Fetch_lib -> Option.map cfg.lib.system_pkg ~f:(fun spec -> SB.fetch_lib_cmd pm spec)
  | Fetch_binding Canary_lang.OCaml -> (
      match
        List.Assoc.find cfg.bindings ~equal:Poly.equal Canary_lang.OCaml
      with
      | Some { opam_pkg = Some spec; _ } -> Some (SB.fetch_binding_cmd spec)
      | _ -> None)
  | Fetch_binding _ | Probe_lib | Probe_binding _ | Scan_source ->
      None (* not yet wired in the strawman *)

(** Resolve one step to its command. [Raw] is verbatim; [Derived] may be
    unwired in this strawman ([None]). *)
let command_of_step ~(pm : Canary_store.package_manager) (cfg : store_config)
    (source : step_source) :
    (output_dir:string -> variant_key:string -> string) option =
  match source with
  | Raw f -> Some f
  | Derived slot -> derive_slot ~pm cfg slot
