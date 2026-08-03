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

(* ── the convergence interface (pins the shape; not yet wired) ──
   What a generic cross-project runner will consume: a project DECLARES its
   artifacts, how to enumerate scenarios, how to materialize each into a
   runnable workspace, and how to build the [runner_spec] for a materialized
   workspace. The generic runner then does enumerate → materialize →
   runner_spec → run, uniformly across tiny-full and z3/sqlite. tiny-full's
   materialize is *assemble vendored resources*; z3's is *build from source*.
   Defined here as the target; z3/sqlite fill it when they move off their
   hand-written variant lists. *)
type project_run = {
  pr_name : string;
  pr_artifacts : Canary_enumerate.artifact_id list;
  pr_enumerate : unit -> Canary_enumerate.assignment list;
  pr_materialize : Canary_enumerate.assignment -> string option;
  pr_runner_spec : workspace:string -> Canary_step_builder.runner_spec;
}
