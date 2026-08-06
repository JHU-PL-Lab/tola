(** [project_run] — the interface a generic cross-project runner consumes
    (ssot §4.2.5 / the convergence). A project DECLARES these; the generic
    runner ([canary_main.run_project_run]) does the uniform
    enumerate → runner_spec → run for any project.

    THE PRINCIPLE (derive_steps-style, 2026-08-05): a project spec does NOT
    carry its enumeration. The project declares its static option space
    ([pr_spec] — stage 1, ssot §4.2); the GENERAL algorithm
    ([Canary_enumerate.enumerate], exposed here as [scenarios_of]) outputs the
    scenario list under an exploration [policy] (stage 2 — a RUNNER knob,
    [full_policy] by default, [thin_policy] for the `--thin` slice). Each
    enumerated case then runs through `derive_steps` with the project's
    expectations (the [runner_spec.expectation] closure — tiny-full's agnostic
    derivation, z3/llvm's contract lowering when they migrate); a case with no
    declared expectation simply must not fail ([Expect_success]). This mirrors
    `runner_spec → derive_steps → step list`: declaration in, derivation out —
    there is no per-project enumeration closure to hand-build (the old
    [pr_enumerate] field is retired).

    - [pr_spec] — the project's STATIC declaration ([Canary_enumerate.
      project_spec]): artifacts + per-artifact provision universes +
      per-(artifact × provision) version universes. Facts, not scenarios.
    - [pr_artifacts] — the DISPLAY artifact set for `spec` (may be wider than
      [pr_spec.ps_artifacts]: e.g. the display-only source behind a
      self-contained Built lib).
    - [pr_runner_spec] — the runner_spec for one scenario (assignment), given
      the assignment (so version/provision-parameterized actions read the
      per-artifact placement) and a runner-chosen [workspace] dir.
      STRUCTURE (the dispatch/realization split, 2026-08-05): implement it as
      [realize ∘ dispatch] — a PURE project-local [dispatch : assignment ->
      scenario_case] (a small case type = inspectable data) reading ONLY the
      general enumeration coordinates ([Canary_enumerate.provision_of] /
      [channel_of] / [provided] / [bad_placements]), and [realize :
      scenario_case -> ... -> runner_spec] holding the command templates.
      Command templates must be functions (they late-bind workspace/
      output_dir and stay lazy for the non-executing backends); the dispatch
      must not be — keep it data-shaped so it can be read and tested without
      running anything. (Making the dispatch fully DECLARED — a placement →
      template table instead of per-project code — is the open action-variant
      design; this split is its precondition.)
      ([canary_main.scenario_dir_of] — the scenario's output + identity dir).
      A project builds/fetches into that dir (sqlite); a project that needs a
      pre-assembled tree (tiny-full) assembles it INSIDE its own runner_spec
      closure — the "assemble/materialize" concern stays in tiny-factory
      ([canary_tiny_workspace]) and never appears in this general interface.
      `Built`/`Fetched` artifacts are NOT pre-placed — they are canary *actions*
      (build_lib / fetch_lib) the runner runs and observes.
    - [pr_provenance] — STATIC, per-artifact provider TABLE for `spec` (no
      execution): the typed [Canary_store_config.provider] backing the abstract
      [artifact_id] + [placement] can't carry — a vendored PATH, a source_repo
      to build from, or a PM + PACKAGE. Plain DATA (A8) — an artifact absent
      from the table is undeclared; read via [provenance_of]. A project
      DECLARES this; `spec` displays it (and cross-checks
      [provision_of_provider] against the baseline provision, so the two can't
      drift) — the artifact list is verifiably spec-sourced.

    tiny-full, sqlite, z3 and llvm all fill this (A5 phases 2+5); ssl is the
    last raw-script [run_project_multi] holdout (migrates with
    zarith/cairo). *)
type project_run = {
  pr_name : string;
  pr_artifacts : Canary_enumerate.artifact_id list;
  pr_spec : Canary_enumerate.project_spec;
  pr_runner_spec :
    Canary_enumerate.assignment -> workspace:string ->
    Canary_step_builder.runner_spec;
  pr_provenance :
    (Canary_enumerate.artifact_id * Canary_store_config.provider) list;
  pr_mismatch_probes :
    (Canary_enumerate.artifact_id * Canary_basic.channel
     * Canary_enumerate.mismatch_direction) list;
      (** DESIGN-INTENT table (data): consumer variants deliberately built to
          reveal a mismatch direction — [(consumer, channel, direction)]
          means "this consumer artifact at this channel carries a
          version-sensitive requirement designed to detect <direction>
          mismatches" (e.g. tiny's dev cstubs binding requires the dev-only
          [tiny_scale] ⇒ Forward). The per-scenario direction itself is
          computed ([Canary_enumerate.mismatch_direction_of]); this table
          says which pairings are DESIGNED probes vs incidental. [] = none
          declared (a positive-only real project). *)
  pr_runtime_edges :
    (Canary_enumerate.artifact_id * Canary_action.dep_mode) list;
      (** Milestone-(b) first slice (2026-08-05, bottom-up): the declared
          RUNTIME-EDGE mode per consumer artifact — who provides the lib a
          binding actually RUNS over, distinct from the lib it was BUILT
          against. This is the [dep_mode] value source A5 asked for, at
          binding granularity (the case the live projects actually have —
          none enumerates an App yet; [Canary_action.close_deps] stays the
          App-level machinery):
          - [Independent] — runs over the SCENARIO's lib placement, which
            is independent of the binding's own build-lib (a Fetched
            binding was compiled against its provider's lib). The two lib
            INSTANCES of one scenario become explicit: build-lib vs
            run-lib ([runtime_pairings_of] computes the pairing; a
            canary-supplied run-lib ⇒ the deploy pairing).
          - [Ambient s] — runs over its own bundled/external lib [s]; the
            scenario's lib axis never reaches it (sqlite's uv-python
            bundled sqlite; z3-solver / llvmlite wheels bundling their
            native lib — backlog #45's co-provider, DECLARED).
          - [Lockstep] — run-lib = build-lib (the matched chain).
          [] = undeclared (edges unresolved, as before). Declarations are
          per-edge STATIC data; an edge whose mode differs per chain (z3's
          OCaml binding) stays undeclared until a finer key is needed. *)
}

(** One resolved runtime pairing for a consumer in a concrete scenario:
    what it runs over ([rp_run] — the scenario's lib placement for
    [Independent]/[Lockstep]; [None] for [Ambient], whose lib is outside
    the enumeration), and whether the pairing is a DEPLOY pairing
    ([rp_deploy]: the run-lib is canary-supplied — Built/Vendored — while
    the consumer's own build-lib came from its provider; run-lib ≠
    build-lib made explicit). v1 rule, honest for the live cases; refines
    when a project declares a consumer's build-lib as data. *)
type runtime_pairing = {
  rp_consumer : Canary_enumerate.artifact_id;
  rp_mode : Canary_action.dep_mode;
  rp_run : Canary_enumerate.placement option;
  rp_deploy : bool;
}

(** Resolve [pr_runtime_edges] against ONE enumerated scenario — the
    two-instance structure (build-lib vs run-lib) surfaced from declared
    data + enumeration coordinates only; the runner's realization
    (loader repoint etc.) is unchanged. *)
let runtime_pairings_of (pr : project_run) (a : Canary_enumerate.assignment) :
    runtime_pairing list =
  List.map
    (fun (consumer, mode) ->
      let lib_pl = Canary_enumerate.placement_of a Canary_enumerate.a_lib in
      match (mode : Canary_action.dep_mode) with
      | Canary_action.Ambient _ ->
          { rp_consumer = consumer; rp_mode = mode; rp_run = None;
            rp_deploy = false }
      | Canary_action.Lockstep ->
          { rp_consumer = consumer; rp_mode = mode; rp_run = lib_pl;
            rp_deploy = false }
      | Canary_action.Independent ->
          let deploy =
            match lib_pl with
            | Some pl -> (
                match pl.Canary_enumerate.provision with
                | Canary_store.Built | Canary_store.Vendored -> true
                | Canary_store.Fetched | Canary_store.Absent -> false)
            | None -> false
          in
          { rp_consumer = consumer; rp_mode = mode; rp_run = lib_pl;
            rp_deploy = deploy })
    pr.pr_runtime_edges

(** Lookup over the [pr_provenance] table ([None] = undeclared artifact). *)
let provenance_of (pr : project_run) (id : Canary_enumerate.artifact_id) :
    Canary_store_config.provider option =
  List.find_opt
    (fun (a, _) -> Canary_enumerate.equal_artifact_id a id)
    pr.pr_provenance
  |> Option.map snd

(** The THIN exploration policy (ssot §4.2 config level): version
    [Subset [Stable]] — drop every Dev world, keep the provision axis Full.
    Project-agnostic; any [project_run] can be run thin. *)
let thin_policy () : unit Canary_enumerate.policy =
  { config =
      Canary_enumerate.
        { provision = Full;
          version = Subset [ Canary_basic.Stable ];
          mutation = Free };
    mutations = [] }

(** THE general algorithm: spec in, scenarios out. [policy] defaults to
    [full_policy] (walk the whole declared space, inject nothing — a real
    project's run). The runner and every `spec` view call THIS — no project
    supplies a scenario list. *)
let scenarios_of ?policy (pr : project_run) :
    Canary_enumerate.assignment list =
  let policy =
    match policy with
    | Some p -> p
    | None -> Canary_enumerate.full_policy ()
  in
  Canary_enumerate.enumerate ~tag:(fun () -> "") ~policy pr.pr_spec
