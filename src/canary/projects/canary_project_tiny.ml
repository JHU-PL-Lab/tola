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

(** Project identity (SSOT §6.1 bundle): name + the contract firing table
    canary lowers expectations through. *)
let project : Canary_project.project =
  { name = "tiny-full"; contract_bindings = TS.tiny_contract_bindings }

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
    placement → (artifact key, tag). All-good ⇒ []. *)
let overlays_of (a : Canary_enumerate.assignment) : (string * string) list =
  Base.List.filter_map a ~f:(fun (_, pl) ->
      match pl.Canary_enumerate.version.quality with
      | Canary_enumerate.Bad tag ->
          Base.Option.map (Canary_tiny_workspace.artifact_key_of_tag tag)
            ~f:(fun key -> (key, tag))
      | Canary_enumerate.Good -> None)

(* Static per-artifact provider (typed; the real vendored layout —
   canary_tiny_workspace.ml paths). All Vendored (the lib is a Cached built
   artifact); tiny-full is agnostic to tiny's prepare layer beyond these paths. *)
let tiny_provenance (id : Canary_enumerate.artifact_id) :
    Canary_store_config.provider option =
  match Canary_enumerate.kind_of id with
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

(** tiny-full as a [project_run] the generic runner consumes. Its [pr_runner_spec]
    ASSEMBLES tiny's vendored cached artifacts into a tree (all-good ⇒ the witness
    base; built-lib ⇒ compiled source tree; bad ⇒ overlay) and returns the base
    spec over that tree with the AGNOSTIC expectation. The assemble step is the
    tiny-factory concern ([Canary_tiny_workspace]) — it lives INSIDE the runner_spec
    closure and the general interface has no pre-placement hook for it. tiny-full
    ignores the runner-provided [workspace] dir (it runs over its assembled tree);
    a real project (sqlite) builds into that dir instead. *)
let tiny_full_run : project_run =
  { pr_name = "tiny-full";
    pr_artifacts = artifacts;
    (* the STATIC declaration (good baseline + built-lib axes; no mutations —
       those are tiny1's oracle). The generic runner enumerates it
       ([Canary_project_run.scenarios_of]) — like sqlite, a positive-only
       general project_run with no scenario list of its own. *)
    pr_spec = general_spec;
    pr_runner_spec =
      (fun a ~workspace:_ ->
        (* ASSEMBLE tiny's vendored tree (tiny-factory). dispatch by provision
           (ssot §4.2.5): the lib may be [Built] (canary compiles from a
           source-only tree) instead of [Vendored]. The channel goes in the label
           so Dev and Stable Built libs get distinct trees + variant_ids (cache
           separately; cache.md). *)
        let lib_built =
          match Canary_enumerate.provision_of a Canary_enumerate.a_lib with
          | Canary_enumerate.Built -> true
          | _ -> false
        in
        let channel =
          (Canary_enumerate.version_of a Canary_enumerate.a_lib)
            .Canary_enumerate.channel
        in
        let assembled =
          match overlays_of a with
          | [] when lib_built ->
              let chan =
                match channel with
                | Canary_basic.Dev -> "dev"
                | Canary_basic.Stable -> "stable"
              in
              Canary_tiny_workspace.materialize_built_lib
                ~label:("positive-built-lib-" ^ chan)
          | [] -> Some (Canary_tiny_workspace.witness_base_workspace ())
          | overlays ->
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
        (* the lib's version channel drives a channel-aware build (Dev ⇒
           -DTINY_DEV + dev version script) on the Built path. *)
        let lib_filename =
          Canary_tiny_workspace.detect_lib_filename ~workspace:tree
        in
        let stores =
          TS.stores_of_workspace ~lib_filename ~workspace_root:tree ()
        in
        { (TS.make_base_runner_spec ~channel ~stores ()) with
          Canary_step_builder.expectation = expectation_agnostic });
    pr_provenance = tiny_provenance }

(* ── THIN subset run (ssot §4.2 config level = Subset) ──
   The thin slice is a RUNNER policy ([Canary_project_run.thin_policy] —
   version [Subset [Stable]]) applied to the SAME declared spec; nothing
   thin-specific lives in the project. This record only renames the run so
   its cache never clashes with the full run's; `action/spec tiny-full
   --thin` pairs it with [thin_policy]. *)
let tiny_full_thin_run : project_run =
  { tiny_full_run with pr_name = "tiny-full-thin" }
