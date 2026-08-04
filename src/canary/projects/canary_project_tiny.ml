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

    A project DECLARES; canary COMPUTES. The declarative surface is the
    [project_run] below ([tiny_full_run]); `action tiny-full` runs it through
    the generic [canary_main.run_project_run] — the SAME path sqlite uses (the
    convergence: one runner, per-project specs). Remaining convergence work:
    derive [pr_enumerate] from a declared spec (absorb [tiny_full_assignments]/
    [_combinations] into the general enumeration) and relocate the spec
    internals, which physically live in the factory file for now (tightly
    coupled to its [engine_*] data). *)

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

(** tiny-full as a [project_run] the generic runner consumes. Materialize =
    ASSEMBLE cached artifacts (all-good ⇒ the witness base; bad ⇒ overlay);
    runner_spec = the base spec over the materialized tree with the AGNOSTIC
    expectation. This is the whole tiny-full-specific surface; the runner is
    project-agnostic. (z3's would differ only in materialize = build.) *)
let tiny_full_run : project_run =
  { pr_name = "tiny-full";
    pr_artifacts = artifacts;
    (* the scenario space the generic runner sweeps: good + built-lib +
       single-bad ([assignments]) AND the multi-bad [combinations] (the
       scenarios beyond tiny1). Combos flow through the same vendored-overlay
       materialize path ([overlays_of] → [materialize_assembled]); canary runs
       fail-fast and discovers the collapse. *)
    pr_enumerate = (fun () -> assignments () @ combinations ());
    pr_materialize =
      (fun a ->
        (* dispatch by provision (ssot §4.2.5): the lib may be [Built] (canary
           compiles from a source-only tree) instead of [Vendored]. The channel
           goes in the label so Dev and Stable Built libs get distinct trees +
           variant_ids (cache separately; cache.md). *)
        let lib_built =
          match Canary_enumerate.provision_of a Canary_enumerate.a_lib with
          | Canary_enumerate.Built -> true
          | _ -> false
        in
        match overlays_of a with
        | [] when lib_built ->
            let chan =
              match
                (Canary_enumerate.version_of a Canary_enumerate.a_lib)
                  .Canary_enumerate.channel
              with
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
            Canary_tiny_workspace.materialize_assembled ~overlays ~label);
    pr_runner_spec =
      (fun a ~workspace ->
        (* the lib's version channel drives a channel-aware build (Dev ⇒
           -DTINY_DEV + dev version script) on the Built path. *)
        let channel =
          (Canary_enumerate.version_of a Canary_enumerate.a_lib)
            .Canary_enumerate.channel
        in
        let lib_filename =
          Canary_tiny_workspace.detect_lib_filename ~workspace
        in
        let stores =
          TS.stores_of_workspace ~lib_filename ~workspace_root:workspace ()
        in
        { (TS.make_base_runner_spec ~channel ~stores ()) with
          Canary_step_builder.expectation = expectation_agnostic }) }

(* ── THIN subset config (ssot §4.2 config level = Subset) ──
   A small, debuggable slice of the SAME enumeration: Stable channel only (drop
   the built-lib Dev positive), single-bad (no combinations), and the
   python:ctypes scenarios dropped (ctypes is intentionally not canary-driven,
   so those are noise that alias cext). Same materialize / runner_spec — only
   the scenario set narrows. Selected by `action tiny-full --thin` /
   `spec tiny-full --thin`. *)
let thin_assignments () : Canary_enumerate.assignment list =
  let is_dev (pl : Canary_enumerate.placement) =
    match pl.Canary_enumerate.version.channel with
    | Canary_basic.Dev -> true
    | Canary_basic.Stable -> false
  in
  let bad_on_ctypes (a : Canary_enumerate.assignment) =
    Base.List.exists a ~f:(fun (id, pl) ->
        (match pl.Canary_enumerate.version.quality with
         | Canary_enumerate.Bad _ -> true
         | Canary_enumerate.Good -> false)
        && Base.String.is_substring
             (Canary_enumerate.string_of_id id) ~substring:"ctypes")
  in
  Base.List.filter (assignments ()) ~f:(fun a ->
      (not (Base.List.exists a ~f:(fun (_, pl) -> is_dev pl)))
      && not (bad_on_ctypes a))

(* Same project_run as [tiny_full_run] with the narrowed enumeration and a
   distinct name (so its run cache never clashes with the full run's). *)
let tiny_full_thin_run : project_run =
  { tiny_full_run with
    pr_name = "tiny-full-thin";
    pr_enumerate = thin_assignments }
