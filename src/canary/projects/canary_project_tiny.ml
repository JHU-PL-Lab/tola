(** tiny-full — the PROJECT (peer of [canary_project_z3] / [_sqlite]).

    The mutation-agnostic general project over tiny's vendored artifact
    resources (ssot §4.2.5). The split this module realizes:

    - the **factory** ([Canary_tiny_scenario] + [Canary_tiny_workspace]) MAKES
      the ingredients — every artifact variant as a built resource — and holds
      the tiny1 oracle (`canary tiny run`);
    - this **project_spec** DECLARES those ingredients + the scenario space;
    - the **runner** ([canary_main]) EXPLORES them via `canary action tiny-full`:
      enumerate → materialize (assemble) → run, with canary computing the
      expectation ([expectation_agnostic]).

    A project DECLARES; canary COMPUTES. The declarative surface a generic
    cross-project runner needs is gathered here ([project_run] below); wiring
    that generic runner (so z3/sqlite share one run path) is the next
    convergence step — today `action tiny-full` still calls [run]. The spec
    internals physically live in the factory file for now (they are tightly
    coupled to its [engine_*] data); relocating them is follow-up polish. *)

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

(** The good+bad scenario space as assignments (1 all-good + one per
    (artifact, bad-tag)). *)
let assignments () : Canary_enumerate.assignment list =
  TS.tiny_full_assignments spec

(** The multi-bad resource-sets — the scenarios *beyond* tiny1 (one project
    holds what tiny1 splits). *)
let combinations () : Canary_enumerate.assignment list =
  TS.tiny_full_combinations spec

(** The expectation canary uses: derived by inspection alone (no oracle) —
    canary decides per step whether to expect a failure. *)
let expectation_agnostic
  : Canary_basic.action -> Canary_store.location option ->
    Canary_step_model.step_expectation
  = TS.tiny_expectation_agnostic

(* ── the run entry consumed by `action tiny-full` ── *)

(** Render the positive-variant enumeration view. *)
let print_view : unit -> unit = TS.print_tiny_full

(** The algorithm-driven good+bad run: iterate the enumerated assignments and
    hand each to the caller's materialize-and-detect primitive. The runner
    ([canary_main.run_tiny_full_project]) supplies a [run] that assembles the
    vendored tree and runs canary over it with [expectation_agnostic]. *)
let run : run:(failfast:bool -> name:string -> string) -> unit = TS.run_tiny_full

(* ── tiny-full's implementation of the [Canary_project_run.project_run]
   interface (shared with sqlite; the generic runner consumes it) ── *)
type project_run = Canary_project_run.project_run

(** The vendored overlays a bad assignment asks for: each [Bad]-quality
    placement → (resource id, tag). All-good ⇒ []. *)
let overlays_of (a : Canary_enumerate.assignment) : (string * string) list =
  Base.List.filter_map a ~f:(fun (_, pl) ->
      match pl.Canary_enumerate.version.quality with
      | Canary_enumerate.Bad tag ->
          Base.Option.map (Canary_tiny_workspace.resource_id_of_tag tag)
            ~f:(fun rid -> (rid, tag))
      | Canary_enumerate.Good -> None)

(** tiny-full as a [project_run] the generic runner consumes. Materialize =
    ASSEMBLE vendored resources (all-good ⇒ the witness base; bad ⇒ overlay);
    runner_spec = the base spec over the materialized tree with the AGNOSTIC
    expectation. This is the whole tiny-full-specific surface; the runner is
    project-agnostic. (z3's would differ only in materialize = build.) *)
let tiny_full_run : project_run =
  { pr_name = "tiny-full";
    pr_artifacts = artifacts;
    pr_enumerate = assignments;
    pr_materialize =
      (fun a ->
        (* dispatch by provision (ssot §4.2.5): the lib may be [Built] (canary
           compiles from a source-only tree) instead of [Vendored]. The channel
           goes in the label so Dev and Stable Built libs get distinct trees +
           variant_ids (cache separately; cache.md). *)
        let lib_placement =
          Base.List.find a ~f:(fun (id, _) ->
              Canary_enumerate.equal_artifact_id id Canary_enumerate.a_lib)
        in
        let lib_built =
          match lib_placement with
          | Some (_, pl) -> (
              match pl.Canary_enumerate.provision with
              | Canary_enumerate.Built -> true
              | _ -> false)
          | None -> false
        in
        match overlays_of a with
        | [] when lib_built ->
            let chan =
              match lib_placement with
              | Some (_, pl) ->
                  let open Canary_enumerate in
                  (match pl.version.channel with
                   | Canary_basic.Dev -> "dev"
                   | Canary_basic.Stable -> "stable")
              | None -> "stable"
            in
            Canary_tiny_workspace.materialize_built_lib
              ~label:("positive-built-lib-" ^ chan)
        | [] -> Some (Canary_tiny_workspace.witness_base_workspace ())
        | overlays ->
            let label =
              Base.String.concat ~sep:"+"
                (Base.List.map overlays ~f:(fun (id, t) -> id ^ "#" ^ t))
            in
            Canary_tiny_workspace.materialize_assembled ~overlays ~label);
    pr_runner_spec =
      (fun a ~workspace ->
        (* the lib's version channel drives a channel-aware build (Dev ⇒
           -DTINY_DEV + dev version script) on the Built path. *)
        let channel =
          match
            Base.List.find a ~f:(fun (id, _) ->
                Canary_enumerate.equal_artifact_id id Canary_enumerate.a_lib)
          with
          | Some (_, pl) ->
              let open Canary_enumerate in
              pl.version.channel
          | None -> Canary_basic.Stable
        in
        let lib_filename =
          Canary_tiny_workspace.detect_lib_filename ~workspace
        in
        let stores =
          TS.stores_of_workspace ~lib_filename ~workspace_root:workspace ()
        in
        { (TS.make_base_runner_spec ~channel ~stores ()) with
          Canary_step_builder.expectation = expectation_agnostic }) }
