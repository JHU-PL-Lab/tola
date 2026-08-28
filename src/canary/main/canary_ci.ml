(** [Canary_ci] — GH Actions jobs rendered from the LIVE pipeline.

    2026-08-27, user: *"we don't touch the GH CI running for a long while
    and I think we shall recover it. In general, GH CI is a backend of the
    canary runner."*

    That framing is the design. {!Canary_gh} is one of the four backends
    over a [step list] — it renders, it does not decide — so a CI job
    should be the SAME steps the local runner executes, passed to a
    different consumer. Before this module they were not: [ci_jobs]
    ({!Canary_run}) built jobs from per-project [*_ci_spec] values, a
    second assembly of the pipeline maintained by hand.

    What that cost, measured 2026-08-27 while recovering CI: the generated
    sqlite job had silently lost its binding half. [sqlite_ci_spec] passes
    an assignment naming only [a_lib], so no binding row realizes, and the
    job that once ran [fetch_binding] + two probes emitted [fetch_lib] +
    [probe_lib] and nothing else. Nobody noticed because the checked-in
    YAML was four months stale and never regenerated. That is the same
    "two assemblies of one pipeline is how they drift" that
    {!Canary_pipeline} was written to end — CI was simply the copy nobody
    had migrated yet.

    So: one job per SCENARIO, steps from {!Canary_pipeline.steps_of}. The
    legacy [ci_jobs] path is untouched for now and still renders
    [canary_ci.yml]; this renders the minimal ubuntu workflow the
    recovery starts from.

    {1 Why a scenario maps cleanly onto a job}

    Pass 4 exists because scenarios share exclusive state on one machine —
    an opam switch, an install prefix, a build tree — and must be
    serialized ([stage4_order_worlds.md]). A GH job gets a FRESH runner,
    so that constraint evaporates: scenarios that must be sequential
    locally are independent jobs remotely, and the ordering pass is simply
    not needed. This is the one place where the enumeration's hardest
    scheduling problem is free.

    {1 What CI does NOT do}

    CI runs rendered shell, never the [canary] binary. So [check_post],
    the run cache and the verdict markers are absent; an expectation
    survives only because {!Canary_gh} resolves it at GENERATION time
    (an [Expect_failure] becomes a [continue-on-error] step plus a verify
    step). A green CI run therefore means "every command exited as
    predicted", not "canary agreed with itself" — weaker than a local
    run, and worth remembering before reading CI as the source of truth. *)

open Base

(** The generation-time root. Paths inside the emitted commands are
    rebuilt by {!Canary_gh.output_dir_of} against [$GITHUB_WORKSPACE], so
    this root only decides where the GENERATOR looks for the cached
    inspector summaries an [Expect_compat_failure] is resolved from — a
    local path, on the machine running [canary ci]. *)
let generation_root = "_out"

(** The cheapest world a project has: every artifact [Fetched]. No source
    build, no staged install — the shape the pre-A5 CI jobs approximated
    by hand, now selected from the real enumeration instead of asserted.

    Deliberately not [--thin]: thin is a VERSION policy (drop the dev
    points) and still keeps sqlite's Built and Installed lib placements,
    six worlds where a first recovery wants one.

    [Vendored] counts too WHEN THE ARTIFACT IS IN-TREE (2026-08-28).
    A runner has the repository after `checkout`, so an in-tree example
    costs nothing — ssl's `app-direct` and tiny-full's whole artifact
    table are of that kind, and excluding them cost two projects. What
    must stay excluded is the OTHER `Vendored`: a conda-forge prebuilt
    (cairo/zlib/zstd/libffi's dev lib point) lives under a machine root
    and needs `canary prebuilt` before a job can use it.

    IN-TREE IS NOT ENOUGH FOR tiny-full, though its artifacts qualify.
    Its `pr_runner_spec` MATERIALIZES a workspace while steps are being
    derived (`Canary_tiny_workspace.witness_base_workspace` — the
    impurity `Canary_pipeline`'s header states), so the emitted commands
    point at `_out/canary/tiny/scenarios/_cache/…/workspace/`: a tree the
    GENERATOR built, gitignored, and absent on a runner. The witness
    cannot go to CI until materialization is a STEP rather than a
    generation-time side effect — the same "prepare as a dispatched
    action" item already tracked in status.md.

    The two are told apart by the declared ORIGIN, not by the provision —
    which is why this reads the ROWS (`pr_artifacts`, where
    `Vendored_at <origin>` survives) rather than the assignment or the
    derived `ax_universe`, both of which keep only the coarse provision.
    The marker is the `<machine>/` prefix that `Canary_opam_binding`
    writes for a prebuilt's libdir; an in-tree origin is repo-relative. *)
let vendored_in_tree (pr : Canary_project_run.project_run)
    (id : Canary_artifact.artifact_info) : bool =
  List.exists pr.Canary_project_run.pr_artifacts ~f:(fun row ->
      Canary_artifact.equal_artifact_info row.Canary_project_spec.ar_artifact id
      && List.exists row.Canary_project_spec.ar_universe ~f:(fun (spec, _) ->
             match spec with
             | Canary_store_config.Vendored_at at ->
                 not (String.is_prefix at ~prefix:"<machine>/")
             | _ -> false))

let all_fetched (pr : Canary_project_run.project_run)
    (a : Canary_artifact.assignment) : bool =
  List.for_all a ~f:(fun (id, pl) ->
      match pl.Canary_artifact.provision with
      | Canary_store.Fetched -> true
      | Canary_store.Vendored -> vendored_in_tree pr id
      | _ -> false)

(** One job from one scenario. [project] carries the per-scenario name so
    the YAML says which world it is; {!Canary_gh.output_dir_of} keys the
    output path on the part before the [/], which is right here — each job
    owns a fresh runner, so two scenarios of one project cannot collide
    the way they would in a shared local [_out]. *)
let job_of_scenario ~(name : string) ~(pr : Canary_project_run.project_run)
    (a : Canary_artifact.assignment) : Canary_gh.job_spec =
  let ctx = Canary_pipeline.ctx_of pr a in
  let steps = Canary_pipeline.steps_of ~root:generation_root pr ~ctx a in
  let world = Stdlib.Filename.basename ctx.Canary_pipeline.sc_workspace in
  { Canary_gh.id = Canary_gh.sanitize_id name;
    name = Printf.sprintf "%s — %s" name world;
    project = ctx.Canary_pipeline.sc_project;
    sys_deps = [];
    preamble_steps = [];
    steps }

(** THE RUNNER IS A DIFFERENT MACHINE (2026-08-27).

    A rendered command may contain a machine root — cairo's [fetch_source]
    clones into [<root>/contrib/cairo-all/cairo] — and the generator runs
    on a laptop, so without this the YAML tells a GH runner to clone into
    [/home/red/code/contrib], a path it can neither find nor create. Five
    such lines were sitting in the checked-in workflow (zarith's), which
    is part of why CI stopped being run.

    So CI renders under its own machine roots, the same way
    [--platform=macos] renders under another platform: [$GITHUB_WORKSPACE]
    is the runner's root, and the shell expands it at run time. This is
    what the entry-side machine table bought — before it, the roots were
    literals in [base/] and no caller could say "render as if elsewhere".

    Scoped and restored: a rendering choice must not leak into whatever
    the process does next. *)
let with_ci_machine_roots (f : unit -> 'a) : 'a =
  let saved = !Canary_store.machine_roots in
  Canary_store.set_machine_roots
    [ (Canary_store.Wsl, "$GITHUB_WORKSPACE");
      (Canary_store.MacOS_local, "$GITHUB_WORKSPACE") ];
  let restore () = Canary_store.machine_roots := saved in
  match f () with
  | r -> restore (); r
  | exception e -> restore (); raise e

(** The minimal recovery set: the all-[Fetched] world of each project
    given, one job each. A project with no such world is skipped rather
    than guessed at — [None] here means "this project cannot be run
    without building something", which is a real answer for a first
    ubuntu deployment. *)
let minimal_jobs (projects : (string * Canary_project_run.project_run) list) :
    Canary_gh.job_spec list =
  List.filter_map projects ~f:(fun (name, pr) ->
      match List.filter (Canary_pipeline.ordered pr) ~f:(all_fetched pr) with
      | [] -> None
      | a :: _ -> Some (job_of_scenario ~name ~pr a))


(* ── The two renderings of one job ──────────────────────────────────────

   The z3 fork's canary infra (contrib/canary/, 2026-04) is the precedent
   and the better shape: every job exists TWICE — once as the YAML a
   runner executes ([backend_yaml/]) and once as a bash script that runs
   the same steps on a laptop ([backend_shell/], which emulates
   [$GITHUB_ENV] with a temp file). The old Makefile carried the same
   idea as the [canary.ci.*.cmd] / [.local] target pairs.

   The point is not symmetry, it is that a CI job you can only run by
   pushing is a job you debug by pushing. Here the twin is nearly free:
   the command text is identical, and [$GITHUB_WORKSPACE] is the only
   thing GitHub supplies that the script has to fill in itself. *)

(** The job's YAML, using the composite setup action instead of repeating
    setup-ocaml + apt + the opam repo in every job. *)
let render_job_yaml ~(ocaml_version : string) ~(runner_os : string)
    (j : Canary_gh.job_spec) : string =
  let steps =
    List.concat_map j.Canary_gh.steps
      ~f:(Canary_gh.render_gh_step ~project:j.Canary_gh.project)
    |> String.concat ~sep:"\n"
  in
  [%string
    {|  %{j.Canary_gh.id}:
    name: %{j.Canary_gh.name}
    runs-on: %{runner_os}
    steps:
      - uses: actions/checkout@v6
      - uses: ./.github/actions/canary-setup
        with:
          ocaml-version: "%{ocaml_version}"

%{steps}
|}]

(** The same job as a standalone bash script.

    Each step runs in a SUBSHELL. That is not tidiness: a probe command
    ends in [exit $RC] (it captures the status, cats its log, then
    exits), and without the subshell that [exit] would end the whole
    script at the first probe — the same trap [run_cmd_logged] and
    [with_world_asserts] each hit once. *)
let shell_of_job ~(ocaml_version : string) (j : Canary_gh.job_spec) : string =
  let body =
    List.map j.Canary_gh.steps ~f:(fun (st : Canary_step_model.step) ->
        let out =
          Canary_gh.output_dir_of ~project:j.Canary_gh.project
            ~tag:st.Canary_step_model.output_tag
        in
        let cmd =
          st.Canary_step_model.cmd ~output_dir:out
            ~variant_key:st.Canary_step_model.variant_id
        in
        let tag = st.Canary_step_model.tag in
        match st.Canary_step_model.expectation with
        | Canary_step_model.Expect_success ->
            [%string
              {|step "%{tag}"
if ( set -e
mkdir -p "%{out}"
%{cmd}
); then :; else echo "FAIL: %{tag}"; exit 1; fi
|}]
        | _ ->
            (* an expected failure: the step must NOT succeed. The
               predicted substrings are checked by the YAML twin at
               generation time; here the polarity alone is asserted. *)
            [%string
              {|step "%{tag} (expected failure)"
if ( set -e
mkdir -p "%{out}"
%{cmd}
); then echo "FAIL: %{tag} succeeded but a failure was expected"; exit 1
else echo "PASS: %{tag} failed as predicted"; fi
|}])
    |> String.concat ~sep:"\n"
  in
  [%string
    {|#!/usr/bin/env bash
# GENERATED by `canary ci --min` — do not edit.
#
# The shell twin of job "%{j.Canary_gh.id}" in canary_min.yml: the same
# steps, same command text, runnable without pushing. Use it to debug a
# CI job locally before spending a runner on it.
#
# OCaml switch: CI has exactly one, a laptop has several. Unless you say
# otherwise this runs in canary's switch, because these steps INSTALL and
# REMOVE opam packages and doing that to your working switch is how a
# binding pin flip eats an afternoon.
# GitHub runs each step with `bash -e {0}`, NOT -u: a probe command does
# `export LD_LIBRARY_PATH=...:$LD_LIBRARY_PATH`, which under -u aborts on
# a machine where that variable is unset. Matching GH's shell is the
# point of a twin, so: no -u. Per-step `set -e` lives in the subshells.
set -o pipefail

: "${GITHUB_WORKSPACE:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export GITHUB_WORKSPACE
cd "$GITHUB_WORKSPACE"

if [ -z "${CI:-}" ] && [ -z "${OPAMSWITCH:-}" ]; then
  export OPAMSWITCH=canary
  echo "note: OPAMSWITCH unset — using the canary switch (set it to override)"
fi

echo "workspace: $GITHUB_WORKSPACE"
echo "switch:    ${OPAMSWITCH:-(ambient)}"
echo "ocaml:     %{ocaml_version} expected on CI; local is $(ocamlopt -version 2>/dev/null || echo unknown)"

step () { printf '\n== %s ==\n' "$1"; }

%{body}
echo
echo "ALL STEPS PASSED: %{j.Canary_gh.id}"
|}]

(* Manual dispatch FIRST, and path filters, because a workflow you cannot
   run without pushing is a workflow you debug by pushing. *)
let minimal_triggers =
  "on:\n\
  \  workflow_dispatch:\n\
  \  push:\n\
  \    paths:\n\
  \      - 'canary/**'\n\
  \      - 'src/canary/**'\n\
  \      - 'src/bin/canary_main.ml'\n\
  \      - '.github/workflows/canary_min.yml'\n\
  \  pull_request:\n\
  \    paths:\n\
  \      - 'canary/**'\n\
  \      - 'src/canary/**'\n\
  \      - 'src/bin/canary_main.ml'\n\
  \      - '.github/workflows/canary_min.yml'"

(* The override wraps the RENDERING, not just the job construction, and
   the difference is load-bearing: a step's [cmd] is a CLOSURE, so the
   command text is not built until {!Canary_gh.render_workflow} applies
   it. Wrapping [minimal_jobs] alone left all five machine-root lines in
   the YAML — the paths resolved after the roots had been restored.
   Deferred resolution is what made the roots configurable at all
   (see [Canary_artifact_source.path_of]); it also decides where the
   scope has to go. *)
(* 5.4, not the backend's 5.2 default: the canary switch is OCaml 5.4.1
   and every local measurement comes from there, so a CI run on 5.2 would
   resolve a different package universe than the one the verdicts were
   earned in. Matching it keeps a CI disagreement meaningful. *)
let ocaml_version = "5.4"
let runner_os = "ubuntu-latest"

(** The workflow and the per-job shell twins, from ONE job list — so the
    two renderings cannot drift the way the YAML and the generator did. *)
let render_minimal
    (projects : (string * Canary_project_run.project_run) list) :
    string * (string * string) list =
  let jobs = minimal_jobs projects in
  (* The SAME jobs, rendered under two machine configurations — which is
     possible only because a step's cmd is a closure and a path is
     resolved when the command text is built.

     YAML gets the CI roots ($GITHUB_WORKSPACE): a runner has no contrib
     tree and clones into its workspace. The shell twin gets THIS
     machine's roots, deliberately: run under CI roots it clones cairo
     into the repo itself, which cost 250MB the first time I ran it. The
     twin is for debugging on a laptop, so it should reach the laptop's
     existing checkout — the same steps, each under the machine
     configuration that is true where it runs. *)
  let jobs_yaml =
    with_ci_machine_roots (fun () ->
        List.map jobs ~f:(render_job_yaml ~ocaml_version ~runner_os)
        |> String.concat ~sep:"\n")
  in
  let yaml =
    [%string
      {|name: Canary — minimal (ubuntu)

%{minimal_triggers}

jobs:
%{jobs_yaml}|}]
  in
  let shells =
    List.map jobs ~f:(fun j -> (j.Canary_gh.id, shell_of_job ~ocaml_version j))
  in
  (yaml, shells)
