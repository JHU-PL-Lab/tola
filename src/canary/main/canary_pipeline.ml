(** [Canary_pipeline] — the enumeration pipeline as NAMED PASSES.

    2026-08-24, the first step of [doc/canary/design/enumeration/emit_stages.md]
    §8. Every stage boundary was already a total function over a distinct
    type; what was missing was a place to point at. Before this module the
    chain was assembled in {!Canary_runner.run_project_spec} and PARTIALLY
    re-assembled in {!Canary_matrix.actions_of}, which called
    [derive_steps] with its own workspace and project name. Two assemblies
    of one pipeline is how they drift.

    The passes, and the value each hands the next:

    {v
    pr_artifacts : artifact_row list
      │ spec_of                                            (stage 1)
      ▼ project_spec
      │ enumerated ?policy                                 (stage 2)
      ▼ assignment list          — what worlds EXIST
      │ ordered ?policy                                    (stage 3)
      ▼ assignment list          — deduped, grouped by store state
      │ steps_of ~root                                     (stage 4)
      ▼ step list                — realized commands
    v}

    {1 Two properties this module is FOR}

    - {b The dump is the value.} [enumerated] and [ordered] are the very
      functions the runner calls, not re-derivations of them. A printer
      built on this module cannot agree with itself while disagreeing with
      what runs — which is the failure mode
      [emit.stage3_is_run_order] exists to prevent.
    - {b Scenario naming lives in ONE place.} [scenario_ctx] holds the
      workspace dir and the per-scenario project name that
      [derive_steps] needs. The runner used to compute them inline.

    {1 The impurity, stated plainly}

    [steps_of] APPLIES [pr_runner_spec], and that application is not pure
    for every project: tiny-full's realization calls
    [Canary_tiny_workspace.witness_base_workspace] /
    [materialize_built_lib], so deriving its steps materializes a tree on
    disk. Stages 1–3 are pure; stage 4 is not, and a caller that only
    wants to LOOK at a project (a dump, a matrix cell) must know that.
    {!actions_of} exists for exactly that caller: it needs the action set,
    not the commands, and takes the throwaway workspace the matrix has
    always used. *)

open Canary_project_run

(* ── stage 1 — declaration ── *)

(** The project's static declaration: the [artifact_row] table lifted to
    the [project_spec] the enumeration reads. Pure. *)
let spec_of (pr : project_run) : Canary_artifact.project_spec =
  Canary_project_spec.project_spec_of_rows pr.pr_artifacts

(* ── stage 2 — enumeration ── *)

(** Which worlds EXIST: the product over (provision × version × mutation)
    with the five constraints applied. Enumeration order. Pure.

    This IS {!Canary_project_run.scenarios_of}; the alias exists so a
    reader can see the pass sequence in one file, and so a consumer names
    the stage rather than the function. *)
let enumerated ?policy (pr : project_run) : Canary_artifact.assignment list =
  scenarios_of ?policy pr

(* ── stage 3 — identity + order ── *)

(** RUN order: {!enumerated} put through a stable sort on the
    single-valued store state each assignment locks, so scenarios needing
    the same state run consecutively. Pure.

    This is what the runner iterates. Since 2026-08-21 it is NOT the same
    list as {!enumerated} — which is why printing [enumerated] where the
    run order was meant would be wrong. *)
let ordered ?policy (pr : project_run) : Canary_artifact.assignment list =
  scenarios_in_run_order ?policy pr

(* ── stage 4 — realization ── *)

(** What one scenario needs before its commands can be built: the
    workspace directory (which is also the scenario's identity and its
    cache key) and the per-scenario project name [derive_steps] keys
    output under. *)
type scenario_ctx = {
  sc_workspace : string;  (** [scenario_dir_of] — identity + output dir *)
  sc_project : string;    (** "<project>/<safe-basename>" *)
}

(** The naming the runner used to compute inline. [':'], ['#'] and ['+']
    are mapped out because the basename reaches paths and env vars. *)
let ctx_of (pr : project_run) (a : Canary_artifact.assignment) : scenario_ctx =
  let ws = scenario_dir_of ~pr_name:pr.pr_name a in
  let safe =
    String.map
      (function ':' | '#' | '+' -> '-' | c -> c)
      (Filename.basename ws)
  in
  { sc_workspace = ws; sc_project = pr.pr_name ^ "/" ^ safe }

let langs = Canary_lang.[ OCaml; Python ]

(** The realized step list for one scenario — [realize ∘ dispatch] then
    [derive_steps]. NOT pure: see the module header. [ctx] is passed in
    rather than recomputed so a caller that already has it (the runner,
    which needs the workspace for other reasons) cannot drift from one
    that does not. *)
let steps_of ~(root : string) (pr : project_run) ~(ctx : scenario_ctx)
    (a : Canary_artifact.assignment) : Canary_step_model.step list =
  let spec = pr.pr_runner_spec a ~workspace:ctx.sc_workspace () in
  Canary_step_builder.derive_steps ~root ~project:ctx.sc_project ~langs spec

(** The ACTIONS one scenario's steps carry, for callers that want the
    chain shape and not the commands (the result matrix). Uses a
    throwaway workspace: the action set does not depend on the output
    path, and this keeps a display query from materializing a scenario's
    real tree. *)
let actions_of (pr : project_run) (a : Canary_artifact.assignment) :
    Canary_basic.action list =
  let spec = pr.pr_runner_spec a ~workspace:"_out/tmp" () in
  let steps =
    Canary_step_builder.derive_steps ~root:"_out" ~project:pr.pr_name ~langs
      spec
  in
  List.map (fun (s : Canary_step_model.step) -> s.Canary_step_model.action) steps
  |> List.sort_uniq Stdlib.compare
