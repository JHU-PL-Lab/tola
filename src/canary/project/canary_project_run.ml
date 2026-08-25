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
    - [pr_artifacts] — THE artifact table (2026-08-06, user-directed: the
      old separate [pr_provenance] assoc merged in — a provider is a
      per-ARTIFACT fact, so it rides the artifact row; only genuinely
      project-level information stays as project fields). Each
      [artifact_decl] = the identity + the typed
      [Canary_store_config.provider] detail the abstract [artifact_info] +
      [placement] can't carry (a vendored PATH, a source_repo, a PM +
      PACKAGE). Structural invariant the two parallel tables lacked: a
      provider can only be declared on a declared artifact. `spec`
      displays the provider per row and cross-checks
      [provision_of_provider] against the baseline provision (drift
      check). The table may be WIDER than [pr_spec.ps_universe]
      (display-only artifacts — sqlite's source behind the self-contained
      Built lib, z3/llvm's chain-following OCaml binding — carry
      providers too, which is why the provider does NOT live on the
      enumerated spec rows / [artifact_axes]).

    tiny-full, sqlite, z3 and llvm all fill this (A5 phases 2+5); ssl is the
    last raw-script [run_project_multi] holdout (migrates with
    zarith/cairo). *)
(** Run-cost tier (2026-08-14, the batch runner): [Heavy] projects carry
    long source-built chains (z3/llvm's Dev builds) — the batch
    default runs them THIN (Subset[Stable], see [batch_policy]); [Light]
    runs full. Explicit single-project runs ignore the tier. *)
type project_tier = Light | Heavy

let string_of_project_tier = function Light -> "light" | Heavy -> "heavy"

type project_run = {
  pr_name : string;
  (** THE artifact table — one row per artifact. Each row carries identity,
      axes (provision × version ranges, runtime mode, follows constraint),
      and optional provider. The enumeration reads axes; the display reads
      providers. Replaces the separate [pr_spec] + [pr_artifacts] tables. *)
  pr_artifacts : Canary_project_spec.artifact_row list;
  pr_runner_spec :
    Canary_artifact.assignment -> workspace:string -> unit ->
    Canary_step_builder.runner_spec;
      (** the realization of ONE enumerated world. Which concrete lib the
          consumer reads is a coordinate of the [assignment] (an
          [Installed] lib provision = the staged face), never a run
          policy — the [?consumer_lib] parameter of the 2026-08-18
          installed-consumer experiment retired 2026-08-19 when the
          provision axis absorbed it. *)
  pr_mismatch_probes :
    (Canary_artifact.artifact_info * Canary_basic.channel
     * Canary_basic.mismatch_direction) list;
  (** Our wrapper package(s) publishing the dev source into a package store
      (the Publish action) — e.g. z3's [(OCaml, "z3.dev")] opam package.
      A DECLARATION, not a derivation: the action table lives inside the
      realization, which the static spec audit must not execute. Empty =
      not provided (yet). *)
  pr_wrapper_pkgs : (Canary_lang.lang * string) list;
  (** Project-level api_source declaration, for projects whose source is
      NOT repo-carried (e.g. tiny-full's in-tree vendored source — its
      [Canary_project_tiny.pr_api_source] lives in the realization).
      Repo-carried projects (z3/llvm/sqlite) declare it on the source
      record instead. *)
  pr_api_source : Canary_artifact.t option;
  (** The binding declarations (M2 step 4, 2026-08-16) — one flat typed
      record per binding (mechanism + payload: c_api/native/coupling/
      surface_path). UNIVERSAL: what checker/contract selection reads,
      declared regardless of how the project builds. [] = not declared
      yet (external projects fill in as they land). *)
  pr_binding_decls : Canary_binding_decl.binding_decl list;
  (** The bindings whose build_binding the project does NOT derive from
      the mechanism template (M2 step 5, 2026-08-17) — it builds raw,
      its original command respected as-is. The spec audit warns on
      every override where a template exists. [] = templates consumed. *)
  pr_raw_build_overrides :
    (Canary_lang.lang * Canary_mechanism.mechanism) list;
  (** Run-cost tier — the batch runner's default config key (see
      [project_tier]). *)
  pr_tier : project_tier;
}

(** The binding declaration for an artifact, if the project declares one —
    matched by the artifact's mechanism (the decl's identity label).
    [None] for non-binding artifacts and undeclared bindings. *)
let binding_decl_of (pr : project_run)
    (id : Canary_artifact.artifact_info) :
    Canary_binding_decl.binding_decl option =
  match id with
  | Canary_artifact.A_binding (_, mech) ->
      List.find_opt
        (fun (d : Canary_binding_decl.binding_decl) ->
          Canary_mechanism.equal_mechanism d.mechanism mech)
        pr.pr_binding_decls
  | _ -> None

(** The bare artifact identities of the table (display loops, langs). *)
let artifact_infos (pr : project_run) : Canary_artifact.artifact_info list =
  List.map (fun d -> d.Canary_project_spec.ar_artifact) pr.pr_artifacts

(** Provider lookup over the artifact table ([None] = artifact absent from
    the table OR declared without a provider). *)
let provenance_of (pr : project_run) (id : Canary_artifact.artifact_info) :
    Canary_store_config.provider option =
  List.find_opt
    (fun d -> Canary_artifact.equal_artifact_info d.Canary_project_spec.ar_artifact id)
    pr.pr_artifacts
  |> fun d -> Option.bind d (fun d -> d.Canary_project_spec.ar_provider)

(** The THIN exploration policy (ssot §4.2 config level): version
    [Subset [Stable]] — drop every Dev world, keep the provision axis Full.
    Project-agnostic; any [project_run] can be run thin. *)
let thin_policy () : unit Canary_enumerate.policy =
  { config =
      Canary_enumerate.
        { provision = Canary_enumerate.Full;
          version = Canary_enumerate.Subset [ Canary_basic.Stable ];
          version_mode = Canary_enumerate.Lockstep;
          mutation = Canary_enumerate.Free;
          refs = Canary_enumerate.All_refs };
    mutations = [] }

let independent_policy () : unit Canary_enumerate.policy =
  { config =
      Canary_enumerate.
        { provision = Canary_enumerate.Full; version = Canary_enumerate.Full;
          version_mode = Canary_enumerate.Independent;
          mutation = Canary_enumerate.Free;
          refs = Canary_enumerate.All_refs };
    mutations = [] }

(** THE run-layer policy choice (2026-08-14): ONE named variant the CLI /
    batch set; consumers match on it exhaustively. Today two cases — the
    open MODE LADDER extends this variant (sharing the run cache):

    - [Fetch]   — only the fetch steps (warm every store + clone);
    - [Smoke]   — build only the latest sources (project + binding
      commands validated, no combinatorial probing);
    - [Thin]    — today's rung: run the combinations WITHOUT extra
      source-building (version Subset[Stable]; for source-built projects
      this IS "don't build from source" — their builds are Dev worlds;
      the name stays for now, per the ladder discussion);
    - [Full]    — every enumerated world.

    Each rung maps to an enumeration policy (and, later, a step-class
    filter) via [enumeration_policy_of]. *)
(* [Audit_lib] (2026-08-17) removed 2026-08-19, user: the audit pass
   materialized the shadowed source-built placements on demand. Nothing
   consumed it, and prebuilt-shadows-source is now unconditional — a
   project that wants its source-built lib visible declares it as a
   distinct version instead of asking a flag to unhide it. *)
type run_policy =
  | Full
  | Thin

let string_of_run_policy = function
  | Full -> "full"
  | Thin -> "thin"

(** The run config — the IMMUTABLE settings a run consumes. [policy] is
    the first field; the space is open for the batch's future knobs
    (scenario parallelism, forced cache cleanup, …). Deliberately NO
    mutable global state: the config flows down the call chain — the CLI
    / batch set its [policy] value, consumers respect the variant. *)
type run_config = {
  policy : run_policy;
  refs : Canary_enumerate.source_ref_level;
      (** which source-repo refs the run enumerates (2026-08-17, the z3
          regression-test case) — [All_refs] by default; the CLI's
          [--refs a,b] narrows to the declared repos with those pinned
          ids (e.g. ["latest"; "pre-10549"]). The batch never sets it. *)
  (* [consumer_lib] (2026-08-18) retired 2026-08-19: which concrete lib
     the consumer reads is an ENUMERATION coordinate (an [Installed] lib
     provision = the staged face), so it belongs to the scenario, not to
     the run config. Selecting a subset of worlds is [refs]-shaped
     work — see the selection-config item in status_project. *)
}

let default_config : run_config =
  { policy = Full; refs = Canary_enumerate.All_refs }

(** The mapping to the enumeration policy — the ONE place the run layer
    touches [Canary_enumerate.policy]. [Full] = [None] (the full default
    of [scenarios_of]); [Thin] = the Subset[Stable] enumeration;
    (the [Audit_lib] rung retired 2026-08-19). The
    [refs] level rides on top of whichever rung: a rung-specific policy
    gets the run's [refs] injected; [Full] (None) becomes a full policy
    when [refs] narrows. *)
let enumeration_policy_of (c : run_config) : unit Canary_enumerate.policy option =
  let inject_refs (p : unit Canary_enumerate.policy) : unit Canary_enumerate.policy =
    { p with
      Canary_enumerate.config =
        { p.Canary_enumerate.config with
          Canary_enumerate.refs = c.refs } }
  in
  match c.policy with
  | Full -> (
      match c.refs with
      | Canary_enumerate.All_refs -> None
      | Canary_enumerate.Refs _ -> Some (inject_refs (Canary_enumerate.full_policy ())))
  | Thin -> Some (inject_refs (thin_policy ()))

(** THE batch default policy (2026-08-14): [Heavy] projects run THIN
    (their source-built chains are Dev worlds, so thin bypasses them),
    [Light] projects run full. The batch folds this into a [run_config].
    Explicit single-project runs ignore the tier; the CLI's [--thin]
    overrides the batch config everywhere. *)
let batch_policy (pr : project_run) : run_policy =
  match pr.pr_tier with
  | Heavy -> Thin
  | Light -> Full

let batch_config (pr : project_run) : run_config =
  { policy = batch_policy pr; refs = Canary_enumerate.All_refs }

(** Pattern-annotated scenarios: each assignment paired with its action
    chain. The chain IS the pattern — the ordered list of actions from
    initial Fetch through Build to terminal Probe. *)
let scenarios_with_patterns ?policy (pr : project_run)
    : (Canary_basic.action_sig list * Canary_artifact.assignment) list =
  let policy =
    match policy with
    | Some p -> p
    | None -> Canary_enumerate.full_policy ()
  in
  let spec =
    Canary_project_spec.project_spec_of_rows pr.pr_artifacts
  in
  Canary_enumerate.patterns_of ~policy spec

(** THE general algorithm: spec in, scenarios out. Internally calls
    [patterns_of] which produces (chain × assignment) pairs — one per
    terminal. Deduplicates assignments (same assignment may appear
    with multiple terminals). *)
let scenarios_of ?policy (pr : project_run) :
    Canary_artifact.assignment list =
  scenarios_with_patterns ?policy pr
  |> List.map snd
  |> List.sort_uniq (fun a b ->
      String.compare
        (Canary_enumerate.string_of_assignment a)
        (Canary_enumerate.string_of_assignment b))

(** [store_state_key pr a] — the SINGLE-VALUED STORE STATE this assignment
    requires (2026-08-21, stage4_order.md §3).

    An opam switch is [Isolated_store "switch"]: isolated from the system
    and internally single-valued, holding ONE version of a package. So an
    assignment that places a binding at a declared pin is not expressing a
    preference — it is taking an exclusive lock on that store's state for
    the duration of its steps.

    The key is the set of (artifact, pinned version) pairs the assignment
    locks: artifacts whose PROVIDER declares store pins
    ([versions_of_provider] returns [Some _]) and which this assignment
    places at a concrete version. Everything else — Built, Vendored, or a
    version-ambient Fetched — locks nothing and contributes nothing. *)
let store_state_key (pr : project_run) (a : Canary_artifact.assignment) :
    (string * string) list =
  List.filter_map
    (fun id ->
      match provenance_of pr id with
      | Some p when Option.is_some (Canary_store_config.versions_of_provider p)
        -> (
          let v = Canary_enumerate.version_of a id in
          match v.Canary_basic.id with
          | "" -> None
          | vid -> Some (Canary_artifact.string_of_id id, vid))
      | _ -> None)
    (artifact_infos pr)
  |> List.sort compare

(** [scenarios_in_run_order] — [scenarios_of], grouped so scenarios needing
    the SAME single-valued store state run consecutively.

    Why this is not a micro-optimisation. The enumeration's product ranges
    over the lib axis outermost and the binding axis innermost, and the
    enumerated list has always BEEN the run order (stage4_order.md §3
    item 2 — a deliberate decision not to have a scheduler). The result is
    that a pinned binding alternates on nearly every row. Measured
    2026-08-20: sqlite performed TEN opam pin operations for ten
    scenarios where two would do, and z3 paid SIX full libz3 source
    builds per run — the opam z3 package is [Package_builds_lib], so each
    flip recompiles it — which is most of z3's ~30 minute wall clock.

    It is an ORDERING, not an axis: [List.stable_sort] on the key, so the
    scenario SET is untouched and ties keep their enumerated order. That
    matters — the enumeration's order carries meaning (the baseline world
    first), and this preserves it within each state group.

    Correctness does not depend on it. [pin_check_post] re-pins whenever a
    pin is not held, so a scenario cannot inherit a neighbour's state
    whatever the order; grouping only stops us paying to undo and redo the
    same pin. *)
let scenarios_in_run_order ?policy (pr : project_run) :
    Canary_artifact.assignment list =
  List.stable_sort
    (fun a b -> compare (store_state_key pr a) (store_state_key pr b))
    (scenarios_of ?policy pr)

(* ── display helpers (moved from bin 2026-08-10) ──
   Pure functions over assignments and project_runs. Used by both
   the CLI [spec]/[action] display and by library tests. *)

let prov_short : Canary_enumerate.provision -> string = function
  | Canary_enumerate.Vendored -> "V"
  | Canary_enumerate.Built -> "B"
  | Canary_enumerate.Installed -> "I"
  | Canary_enumerate.Fetched -> "F"
  | Canary_enumerate.Absent -> "A"

let placement_str (pl : Canary_artifact.placement) =
  Printf.sprintf "%s:%s" (prov_short pl.Canary_artifact.provision)
    (Canary_enumerate.string_of_build_id pl.Canary_artifact.version)

(* Is every placement Good-quality? Generic over assignments — previously
   lived in the tiny factory ([Canary_tiny_scenario]), but the run layer
   needs it too and the factory is a project-side module: it belongs here,
   in the project-utils layer (2026-08-14, the run/main library split). *)
let assignment_is_all_good (a : Canary_artifact.assignment) : bool =
  List.for_all
    (fun (_, pl) ->
      match pl.Canary_artifact.version.Canary_basic.quality with
      | Canary_basic.Good -> true
      | Canary_basic.Bad _ -> false)
    a

let baseline_of (scenarios : Canary_artifact.assignment list) =
  try List.find assignment_is_all_good scenarios
  with Not_found -> (match scenarios with a :: _ -> a | [] -> [])

(* The pre/post join key: MUST equal the run-side [r_result_key] format in
   [run_project_spec] (pretty_id=id=fetched@ver — the assignment format),
   not [placement_str]'s "F:ver" form — the two drifted, so delta scenarios
   rendered "·" (not run) though they ran (the scenario-count mismatch,
   2026-08-12). *)
let scenario_label ~baseline (a : Canary_artifact.assignment) : string =
  let deltas =
    List.filter_map
      (fun (id, pl) ->
        let s = Canary_enumerate.string_of_assignment [ (id, pl) ] in
        match Canary_enumerate.placement_of baseline id with
        | Some bl ->
            if String.equal s
                 (Canary_enumerate.string_of_assignment [ (id, bl) ])
            then None
            else Some (Printf.sprintf "%s=%s" (Canary_artifact.pretty_id id) s)
        | None -> None)
      a
  in
  match deltas with [] -> "(baseline)" | _ -> String.concat "  " deltas

(* The binding languages a project's artifacts span. *)
let langs_of (arts : Canary_artifact.artifact_info list) : Canary_lang.lang list =
  List.filter_map
    (fun a ->
      match Canary_artifact.kind_of a with
      | Canary_basic.Binding l -> Some l
      | _ -> None)
    arts
  |> List.sort_uniq Stdlib.compare

(* Which artifact kinds a kind can BUILD (derived from the action catalogue:
   a Build action that CONSUMES this kind → what it PRODUCES). *)
let builds_of_kind ~(langs : Canary_lang.lang list) (k : Canary_basic.artifact_kind) =
  let open Canary_basic in
  match k with
  | Source -> [ Headers; Lib ] @ Stdlib.List.concat_map (fun l -> [ Canary_basic.Binding l ]) langs
  | Headers -> []
  | Lib -> App :: Stdlib.List.concat_map (fun l -> [ Canary_basic.Binding l ]) langs
  | Binding _ -> [ App ]
  | Binding_source l -> [ Canary_basic.Binding l ]
  | App -> []

let builds_of ~langs a = builds_of_kind ~langs (Canary_artifact.kind_of a)

(* Coarse artifact GROUP for the spec listing. *)
let group_of_kind : Canary_basic.artifact_kind -> string = function
  | Canary_basic.Source -> "source"
  | Canary_basic.Headers | Canary_basic.Lib -> "native"
  | Canary_basic.Binding _ | Canary_basic.Binding_source _ -> "bindings"
  | Canary_basic.App -> "app"

let group_order = [ "source"; "native"; "bindings"; "app" ]

(* ── shared run pipeline (2026-08-09) ──
   The function both the CLI [action] command and project tests call.
   Enumerate → runner_spec → derive_steps → execute → results.
   Display/printing stays in the bin layer; assertions stay in tests. *)

(** A born-safe per-scenario output directory — the identity of one
    assignment. [Fetched] artifacts are version-ambient (the PM picks),
    so their declared version is dropped from the id; [Built]/[Vendored]
    versions ARE identity. *)
let scenario_dir_of ~pr_name (a : Canary_artifact.assignment) : string =
  let chan_s = function
    | Canary_basic.Stable -> "stable"
    | Canary_basic.Dev -> "dev"
  in
  (* STORE PIN identity (2026-08-12): a Fetched artifact is version-ambient
     unless its placement carries a pinned id — a pinned Fetched is
     identity-bearing (the store holds that concrete version). *)
  let fetched_s (pl : Canary_artifact.placement) =
    if String.equal pl.Canary_artifact.version.Canary_basic.id "" then
      "fetched"
    else
      "fetched-"
      ^ String.map (function '/' -> '-' | c -> c)
          pl.Canary_artifact.version.Canary_basic.id
  in
  let part (id, (pl : Canary_artifact.placement)) =
    let k =
      String.map (function ':' -> '-' | c -> c)
        (Canary_basic.string_of_artifact_kind (Canary_artifact.kind_of id))
    in
    match pl.Canary_artifact.provision with
    | Canary_artifact.Fetched -> k ^ "-" ^ fetched_s pl
    | Canary_artifact.Built -> Printf.sprintf "%s-built-%s" k (chan_s pl.Canary_artifact.version.Canary_basic.channel)
    | Canary_artifact.Installed -> Printf.sprintf "%s-installed-%s" k (chan_s pl.Canary_artifact.version.Canary_basic.channel)
    | Canary_artifact.Vendored -> Printf.sprintf "%s-vendored-%s" k (chan_s pl.Canary_artifact.version.Canary_basic.channel)
    | Canary_artifact.Absent -> Printf.sprintf "%s-absent" k
  in
  (* KIND ORDER, not list order (2026-08-19). The parts used to be
     concatenated in the assignment's own order, which is an artifact of
     how the enumeration happened to build it — so an enumeration change
     (removing a [follows], say) silently RENAMED every scenario dir, and
     the dir name is the cache key: every warm marker orphaned, every
     project re-run cold, with nothing in the diff pointing at it. Sorting
     by artifact kind makes the name a function of the assignment's
     CONTENT, and it reads in pipeline order (source → lib → binding →
     app) as a bonus. *)
  let ordered =
    List.stable_sort
      (fun (x, _) (y, _) ->
        let k id = Canary_basic.kind_order (Canary_artifact.kind_of id) in
        match compare (k x) (k y) with
        | 0 ->
            String.compare
              (Canary_artifact.string_of_id x)
              (Canary_artifact.string_of_id y)
        | c -> c)
      a
  in
  Printf.sprintf "_out/canary/projects/%s/%s" pr_name
    (String.concat "_" (List.map part ordered))

(** The union of all actions that actually fire across all scenarios
    of a project_run. Derives the step list for each scenario via
    [derive_steps] (shells out for project-specific templates) and
    collects the action set. Used by [canary scenarios] (F5). *)
let covered_actions_of ?policy (pr : project_run) : Canary_basic.action list =
  let scenarios = scenarios_of ?policy pr in
  let actions =
    Stdlib.List.concat_map (fun a ->
      let spec = pr.pr_runner_spec a ~workspace:"_out/tmp" () in
      let steps =
        Canary_step_builder.derive_steps ~root:"_out" ~project:pr.pr_name
          ~langs:Canary_lang.[ OCaml; Python ] spec
      in
      Stdlib.List.map (fun (s : Canary_step_model.step) -> s.action) steps)
      scenarios
  in
  Stdlib.List.sort_uniq Stdlib.compare actions

(* ── Run-data helpers (moved from bin 2026-08-10) ── *)

let run_state_path_of ~project =
  Printf.sprintf "_out/canary/projects/%s/-run/run_state.json" project

(* PASS iff every step is "done" or "xfail" (confirmed expected failure). *)
let scenario_status_of_run_state ?(project = "tiny") () : string =
  let path = run_state_path_of ~project in
  if not (Stdlib.Sys.file_exists path) then "N/A"
  else
    match Yojson.Basic.from_file path with
    | `Assoc top ->
      (match List.assoc_opt "steps" top with
       | Some (`List steps) ->
         let all_done =
           List.for_all (function
             | `Assoc a ->
               (match List.assoc_opt "status" a with
                | Some (`String ("done" | "xfail")) -> true
                | _ -> false)
             | _ -> false) steps
         in
         if all_done then "PASS" else "FAIL"
       | _ -> "N/A")
    | _ -> "N/A"
    | exception _ -> "N/A"

let scenario_summary_path_of ~project =
  Printf.sprintf "_out/canary/projects/%s/-run/scenarios.tsv" project

(* Load the persisted per-scenario run summary as a [(label, (verdict,
   is_bad, xfail_steps))] list — the POST view joined to the pre listing
   by [scenario_label]. *)
let load_scenario_post ~project : (string * (string * bool * string)) list =
  let path = scenario_summary_path_of ~project in
  if not (Stdlib.Sys.file_exists path) then []
  else
    let ic = Stdlib.open_in path in
    let rec loop acc =
      match Stdlib.input_line ic with
      | line -> (
          match String.split_on_char '\t' line with
          | verdict :: bad :: xf :: rest when rest <> [] ->
              let label = String.concat "\t" rest in
              let xf = if String.equal xf "-" then "" else xf in
              loop ((label, (verdict, String.equal bad "bad", xf)) :: acc)
          | verdict :: bad :: [ label ] ->
              loop ((label, (verdict, String.equal bad "bad", "")) :: acc)
          | _ -> loop acc)
      | exception End_of_file ->
          Stdlib.close_in ic;
          acc
    in
    loop []

(* ── Spec display (moved from bin 2026-08-10) ── *)
let lib_watchlist_post ~pr_name (a : Canary_artifact.assignment) :
    (int * string list) option =
  let safe =
    String.map
      (function ':' | '#' | '+' -> '-' | c -> c)
      (Filename.basename (scenario_dir_of ~pr_name a))
  in
  let path =
    Printf.sprintf "_out/canary/projects/%s/build_lib/inspect_%s.json" pr_name
      safe
  in
  if not (Stdlib.Sys.file_exists path) then None
  else
    try
      let j = Yojson.Basic.from_file path in
      let open Yojson.Basic.Util in
      let w = j |> member "watchlist" in
      let strs k = w |> member k |> to_list |> List.map to_string in
      Some (List.length (strs "present"), strs "missing")
    with _ -> None



let print_spec ?policy (pr : project_run) : unit =
  let module E = Canary_enumerate in
  let scenarios = scenarios_of ?policy pr in
  let all_good = assignment_is_all_good in
  let baseline = baseline_of scenarios in
  let baseline_str id =
    match Canary_enumerate.placement_of baseline id with
    | Some pl -> placement_str pl
    | None -> "\xE2\x80\x94" (* em dash *)
  in
  let post = load_scenario_post ~project:pr.pr_name in
  Fmt.pr "@.spec: %s — %s@." pr.pr_name
    (if post = [] then "enumeration (no run yet)"
     else "enumeration + last-run verdicts");
  (* artifacts, grouped, each with its baseline provision@version, the
     project-declared provenance detail, and what it can BUILD (derived from the
     action catalogue: which Build actions consume this kind → what they produce). *)
  let arts = artifact_infos pr in
  let langs = langs_of arts in
  let builds_of a = builds_of ~langs a in
  Fmt.pr "@.artifacts (%d), by group [baseline provision@@version + provenance]:@."
    (List.length arts);
  List.iter
    (fun grp ->
      let in_grp =
        List.filter
          (fun a -> String.equal (group_of_kind (Canary_artifact.kind_of a)) grp)
          arts
      in
      if in_grp <> [] then begin
        Fmt.pr "  %s:@." grp;
        List.iter
          (fun a ->
            Fmt.pr "    %-26s %s@." (Canary_artifact.pretty_id a) (baseline_str a);
            (match provenance_of pr a with
             | Some p ->
                 (* drift check: the provider's coarse provision must equal the
                    baseline's — if not, the declared detail contradicts the
                    axis. Skipped for an artifact the enumeration doesn't
                    place (baseline "—"): a display-only artifact (e.g. the
                    source behind a self-contained Built lib) has no axis to
                    contradict. *)
                 let drift =
                   match Canary_enumerate.placement_of baseline a with
                   | None -> ""
                   | Some _ ->
                       if
                         Canary_store.equal_provision
                           (Canary_store_config.provision_of_provider p)
                           (Canary_enumerate.provision_of baseline a)
                       then ""
                       else "   ⚠ provider≠baseline provision"
                 in
                 (* the ARROW: provider → action → artifact (fetch and build
                    are the same shape; a vendored copy has no producing
                    action — the provider is the boundary). *)
                 let arrow =
                   match
                     Canary_store_config.providing_action_of ~provision:(Canary_enumerate.provision_of baseline a) (Canary_artifact.kind_of a) p
                   with
                   | Some act ->
                       "  ⟶ " ^ Canary_basic.string_of_action act
                   | None -> "  (supplied — no producing action)"
                 in
                 Fmt.pr "        provider: %s%s%s@."
                   (Canary_store_config.string_of_provider p) arrow drift
             | None ->
                 Fmt.pr "        provider: (undeclared — spec carries no detail)@.");
            (* mechanism detail comes from THE catalogue
               (base/canary_mechanism.ml) — the spec references a mechanism
               by name (the identity's own mechanism); no project inlines
               these facts. *)
            (match Canary_artifact.mechanism_of a with
             | Some m ->
                 Fmt.pr "        mechanism: %s@."
                   (Canary_mechanism.one_line_of_info
                      (Canary_mechanism.info_of_mechanism m))
             | None -> ());
            List.iter
              (fun (id, ch, dir) ->
                if Canary_artifact.equal_artifact_info id a then
                  Fmt.pr "        mismatch probe: %s variant designed to reveal %s mismatch@."
                    (match ch with
                     | Canary_basic.Dev -> "dev"
                     | Canary_basic.Stable -> "stable")
                    (Canary_enumerate.string_of_mismatch_direction dir))
              pr.pr_mismatch_probes;
            match builds_of a with
            | [] -> ()
            | ks ->
                Fmt.pr "        builds → %s@."
                  (String.concat ", "
                     (List.map Canary_basic.string_of_artifact_kind ks)))
          in_grp
      end)
    group_order;
  (* The WORLDS, each in FULL flat form (the assignment the run walks): one
     placement per artifact identity — this is the enumerated object itself,
     not a delta. Cross-instance combinations (two libs in one world = the
     build-lib ≠ run-lib mismatch) are NOT expressible here — that is the
     node-graph enumeration (`construct`, close_deps). Annotated with the
     last-run verdict where a run summary exists (join by [scenario_label]). *)
  let ngood = List.length (List.filter all_good scenarios) in
  let total = List.length scenarios in
  Fmt.pr
    "@.scenarios — %d enumerated (%d good, %d bad); ONE placement per artifact \
     (the flat assignment the run walks):@."
    total ngood (total - ngood);
  Fmt.pr
    "  key: F=fetched (a PM provides the consumable artifact — apt ships a \
     binary, opam BUILDS the package source at install; version ambient, the \
     PM picks)@.       B=built (canary builds it — version IS identity)  \
     V=vendored (supplied local artifact — version IS identity)@.";
  List.iter
    (fun a ->
      let label = scenario_label ~baseline a in
      let is_bad = not (all_good a) in
      let mark =
        match List.assoc_opt label post with
        | Some ("PASS", _, xf) when not (String.equal xf "") ->
            (* the world PASSED via a confirmed expected failure — a
               DETECTED mismatch (the xfail steps name where) *)
            "✓ xfail"
        | Some ("PASS", _, _) -> if is_bad then "✓ detected" else "✓"
        | Some (_, _, _) -> if is_bad then "✗ missed" else "✗ REGRESSED"
        | None -> if post = [] then " " else "·"
      in
      let world =
        String.concat "  "
          (List.map
             (fun (id, pl) ->
               Printf.sprintf "%s=%s" (Canary_artifact.pretty_id id) (placement_str pl))
             a)
      in
      (* designed-probe mark: a declared (consumer, channel, direction) probe
         is ACTIVE in this scenario when the consumer is placed at that
         channel AND the computed consumer↔lib pairing direction matches. *)
      let probe_marks =
        List.filter_map
          (fun (id, ch, dir) ->
            let placed =
              match Canary_enumerate.placement_of a id with
              | Some pl -> pl.Canary_artifact.version.Canary_basic.channel = ch
              | None -> false
            in
            if
              placed
              && Canary_enumerate.mismatch_direction_of a ~consumer:id ~provider:Canary_artifact.a_lib
                 = Some dir
            then Some (Canary_enumerate.string_of_mismatch_direction dir)
            else None)
          pr.pr_mismatch_probes
      in
      let watchlist_note =
        match lib_watchlist_post ~pr_name:pr.pr_name a with
        | None -> ""
        | Some (npresent, []) ->
            Printf.sprintf "   [lib watchlist: %d/%d]" npresent npresent
        | Some (npresent, missing) ->
            Printf.sprintf "   [lib watchlist: %d present, missing %s]"
              npresent (String.concat "," missing)
      in
      Fmt.pr "  %-10s %s%s%s%s@." mark world
        (match probe_marks with
         | [] -> ""
         | ms -> "   [" ^ String.concat "+" ms ^ "-mismatch probe]")
        watchlist_note
        (if String.equal label "(baseline)" then "   (baseline)" else "");
      (* Milestone-(b) first slice: the scenario's RUNTIME pairings from the
         spec rows' [ax_runtime] — the second lib instance (what a consumer
         RUNS over vs what it was built against) as enumeration data, not
         realization folklore. Printed only when declared. *)
      (match Canary_enumerate.runtime_pairings_of (Canary_project_spec.project_spec_of_rows pr.pr_artifacts) a with
       | [] -> ()
       | ps ->
           let part (p : Canary_enumerate.runtime_pairing) =
             let name = Canary_artifact.pretty_id p.E.rp_consumer in
             match p.E.rp_mode with
             | Canary_store.Ambient s ->
                 Printf.sprintf "%s → ambient (%s)" name s
             | _ ->
                 let run =
                   match p.E.rp_run with
                   | Some pl -> placement_str pl
                   | None -> "—"
                 in
                 Printf.sprintf "%s → lib %s%s" name run
                   (if p.E.rp_deploy then
                      "  [build-lib ≠ run-lib: DEPLOY]"
                    else "")
           in
           Fmt.pr "             ↳ runtime: %s@."
             (String.concat "  ·  " (List.map part ps))))
    scenarios;
  (if post <> [] then begin
     let bads = List.filter (fun (_, (_, b, _)) -> b) post in
     let detected =
       List.length
         (List.filter (fun (_, (v, _, _)) -> String.equal v "PASS") bads)
     in
     let xfail_worlds =
       List.filter (fun (_, (_, _, xf)) -> not (String.equal xf "")) post
     in
     Fmt.pr "  last run (`action %s`): %d/%d bad detected · %d scenario(s) ran.@."
       pr.pr_name detected (List.length bads)
       (List.length post);
     List.iter
       (fun (label, (_, _, xf)) ->
         Fmt.pr "    xfail %s — %s@." xf
           (if String.equal label "(baseline)" then "(baseline)" else label))
       xfail_worlds
   end);
  Fmt.pr
    "@.  use `spec %s --by-artifact` for a per-artifact view.@."
    pr.pr_name

(* Is artifact [id] DIRECTLY mutated (Bad quality) in scenario [a]? *)
let artifact_bad_in (a : Canary_artifact.assignment)
    (id : Canary_artifact.artifact_info) : bool =
  match Canary_enumerate.placement_of a id with
  | Some { version = { quality = Canary_basic.Bad _; _ }; _ } -> true
  | _ -> false

(* F3 — the ARTIFACT-centric dual of [print_spec]: for each artifact, the
   scenarios that directly mutate it (with post verdict + a per-artifact
   detection rate), then a compact count of scenarios that mutate an UPSTREAM
   artifact (this one is downstream-affected). Same pre/post join by
   [scenario_label]. Rows = artifacts, whereas [print_spec]'s rows = scenarios. *)
let print_artifacts ?policy (pr : project_run) : unit =
  let module E = Canary_enumerate in
  let scenarios = scenarios_of ?policy pr in
  let baseline = baseline_of scenarios in
  let post = load_scenario_post ~project:pr.pr_name in
  let verdict a = List.assoc_opt (scenario_label ~baseline a) post in
  let is_detected a =
    match verdict a with Some ("PASS", _, _) -> true | _ -> false
  in
  let bads =
    List.filter
      (fun a -> not (assignment_is_all_good a))
      scenarios
  in
  Fmt.pr "@.artifacts: %s — %s (scenarios that touch each)@."
    pr.pr_name
    (if post = [] then "enumeration (no run yet)"
     else "enumeration + last-run verdicts");
  List.iter
    (fun grp ->
      let in_grp =
        List.filter
          (fun id -> String.equal (group_of_kind (Canary_artifact.kind_of id)) grp)
          (artifact_infos pr)
      in
      if in_grp <> [] then begin
        Fmt.pr "  %s:@." grp;
        List.iter
          (fun id ->
            let ord = Canary_basic.kind_order (Canary_artifact.kind_of id) in
            let direct = List.filter (fun a -> artifact_bad_in a id) bads in
            let upstream =
              List.filter
                (fun a ->
                  List.exists
                    (fun (other, (pl : Canary_artifact.placement)) ->
                      Canary_basic.kind_order (Canary_artifact.kind_of other)
                      < ord
                      && match pl.version.quality with Canary_basic.Bad _ -> true | _ -> false)
                    a)
                bads
            in
            let rate =
              if post = [] then ""
              else
                Printf.sprintf " · %d/%d detected"
                  (List.length (List.filter is_detected direct))
                  (List.length direct)
            in
            let up =
              if upstream = [] then ""
              else Printf.sprintf " · +%d upstream" (List.length upstream)
            in
            Fmt.pr "    %-26s %d mutated%s%s@." (Canary_artifact.pretty_id id)
              (List.length direct) rate up;
            List.iter
              (fun a ->
                let mark =
                  match verdict a with
                  | None -> if post = [] then "" else "·"
                  | Some ("PASS", _, _) -> "✓ detected"
                  | Some _ -> "✗ missed"
                in
                Fmt.pr "      %-46s %s@." (scenario_label ~baseline a) mark)
              direct)
          in_grp
      end)
    group_order;
  Fmt.pr
    "@.  legend: N mutated = scenarios with THIS artifact at a Bad version; \
     +M upstream = scenarios mutating an upstream artifact (downstream-affected); \
     ✓ detected / ✗ missed / · not run.@."

(* (provisions_of_runner_spec — the closure-sniffing provision read for the
   raw z3/llvm variant view — retired with that view, A5 phase 5.) *)

(* Machine-readable `spec --json`: the same artifacts × scenarios, parseable.
   Reuses the exact pre/post data print_spec renders (same [scenario_label] join,
   same catalogue [builds_of], same typed provider) — a second projection, not a
   second source of truth. *)

let spec_json_t ?policy (pr : project_run) : Yojson.Basic.t =
  let module E = Canary_enumerate in
  let scenarios = scenarios_of ?policy pr in
  let baseline = baseline_of scenarios in
  let all_good = assignment_is_all_good in
  let post = load_scenario_post ~project:pr.pr_name in
  let langs = langs_of (artifact_infos pr) in
  let verdict a = List.assoc_opt (scenario_label ~baseline a) post in
  let artifact_json a =
    `Assoc
      [ ("id", `String (Canary_artifact.pretty_id a));
        ("group", `String (group_of_kind (Canary_artifact.kind_of a)));
        ( "provision",
          `String
            (Canary_store.string_of_provision (Canary_enumerate.provision_of baseline a)) );
        ("version", `String (Canary_basic.string_of_build_id (Canary_enumerate.version_of baseline a)));
        ( "provider",
          match provenance_of pr a with
          | Some p -> `String (Canary_store_config.string_of_provider p)
          | None -> `Null );
        ( "providing_action",
          match provenance_of pr a with
          | Some p -> (
              match
                Canary_store_config.providing_action_of ~provision:(Canary_enumerate.provision_of baseline a) (Canary_artifact.kind_of a) p
              with
              | Some act -> `String (Canary_basic.string_of_action act)
              | None -> `Null)
          | None -> `Null );
        ( "builds",
          `List
            (List.map
               (fun k -> `String (Canary_basic.string_of_artifact_kind k))
               (builds_of ~langs a)) ) ]
  in
  let scenario_json a =
    let good = all_good a in
    let fields =
      [ ("good", `Bool good); ("label", `String (scenario_label ~baseline a)) ]
      @
      match verdict a with
      | None -> []
      | Some (v, _, xf) ->
          ("verdict", `String v)
          :: (if String.equal xf "" then []
              else [ ("xfail", `String xf) ])
          @ (if good then [] else [ ("detected", `Bool (String.equal v "PASS")) ])
    in
    `Assoc fields
  in
  `Assoc
    [ ("project", `String pr.pr_name);
      ("kind", `String "project_run");
      ( "artifacts",
        `List
          (List.map artifact_json (artifact_infos pr)) );
      ("scenarios", `List (List.map scenario_json scenarios)) ]

(* (print_spec_variants + spec_variants_json_t — the raw z3/llvm variant
   view and its JSON twin, with their variant_kinds/source_repo_* helpers —
   retired 2026-08-05, A5 phase 5: every project `spec` serves is a
   [project_run] now, rendered by [print_spec]/[spec_json_t] above.) *)

(* ── Project registry: see canary_registry.ml ──
   (The registry references every project module, each of which references
   this module for the [project_run] type — a module cycle dune rejects.
   It lives in its own module, canary_registry.ml, which depends on both.) *)

(* [simple] retired 2026-08-13 (spec-check fulfillment): its providerless
   rows made the opam-binding projects opaque to the spec audit. The
   pattern now
   declares typed rows + its run via [Canary_opam_binding.artifacts] /
   [Canary_opam_binding.run] (source row + system-pkg lib + opam binding,
   mechanism declared per project — libffi's honest [Ctypes] included). *)

