(** [Canary_pipeline] — the enumeration pipeline as NAMED PASSES.

    2026-08-24, the first step of [doc/canary/design/enumeration/stage3_enumerate_worlds.md Attribution]
    §8. Every stage boundary was already a total function over a distinct
    type; what was missing was a place to point at. Before this module the
    chain was assembled in {!Canary_runner.run_project_spec} and PARTIALLY
    re-assembled in {!Canary_matrix.actions_of}, which called
    [derive_steps] with its own workspace and project name. Two assemblies
    of one pipeline is how they drift.

    The passes, and the value each hands the next:

    {v
    pr_artifacts : artifact_row list
      │ spec_of                                            (pass 1 declare)
      ▼ project_spec
      │ analysed_of                                        (pass 2 analyse)
      ▼ analysis                 — what canary UNDERSTANDS of the spec
      │ worlds                                             (pass 3 enumerate)
      ▼ assignment list          — what worlds the project HAS
      │ enumerated ?policy                                 (pass 4 select)
      ▼ assignment list          — what this RUN asked for
      │ ordered ?policy                                    (pass 5 order)
      ▼ assignment list          — deduped, grouped by store state
      │ steps_of ~root                                     (pass 6 realize)
      ▼ step list                — realized commands
    v}

    RENUMBERED 2026-09-16 (user: "a clean model for pass as well as
    action / project is more worthy"), when ANALYSE became a pass. It
    cost four doc renames and a sweep of citations; what it bought is
    that the pipeline has no half-numbers and no unnumbered branch. The
    old numbering had both — [enumerated] was "stage 2.5" here and
    [chain_applicable] was a [(branch)] row in the pass table.

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
    disk. Passes 1–5 are pure; pass 6 is not, and a caller that only
    wants to LOOK at a project (a dump, a matrix cell) must know that.
    {!actions_of} exists for exactly that caller: it needs the action set,
    not the commands, and takes the throwaway workspace the matrix has
    always used. *)

open Canary_project_run

(* ── pass 1 — declare ── *)

(** The project's static declaration: the [artifact_row] table lifted to
    the [project_spec] the enumeration reads. Pure. *)
let spec_of (pr : project_run) : Canary_artifact.project_spec =
  Canary_project_spec.project_spec_of_rows pr.pr_artifacts

(* ── pass 2 — ANALYSE (2026-09-16, user) ────────────────────────────

   What canary UNDERSTANDS about the project, as against what the author
   WROTE. Pure, world-free, and named here for the same reason every
   other pass is: so there is one answer rather than one per consumer.

   The rule for what belongs in it is the absence of a world.
   Applicability takes no assignment, so it is knowable here; FIRING
   takes one, so it stays at realize. See
   [Canary_project_analysis] for why this is a pass and not the second
   unnumbered branch. *)

let analysed_of (pr : project_run) : Canary_project_analysis.t =
  Canary_project_analysis.of_project_run pr

(* ── pass 3 — enumerate ── *)

(** Which worlds the project HAS — the product with the five model
    constraints applied and NO selection. Invocation-independent: this
    list does not depend on [--thin] or [--refs], which is what makes an
    enumerate dump a fact about the project rather than about today's
    flags (pass 3 Attribution; was why_ledger.md §7). Pure. *)
let worlds (pr : project_run) : Canary_artifact.assignment list =
  let module EN = Canary_enumerate in
  (* THROUGH [scenarios_of], deliberately. Pass 3 has two
     implementations — [enumerate] (via [enumerate_product]) and
     [enumerate_follows_tree] (via [patterns_of], which is what
     [scenarios_of] and therefore the RUNNER use). Building [worlds] on
     the other one made this function a third opinion; the pin
     [select.full_policy_selects_everything] caught it immediately.

     They agree on content. What differs is the ORDER of the pairs
     within each assignment, which matters more than it sounds:
     [string_of_assignment] is the dedup key in [scenarios_of], and it is
     order-sensitive. [scenario_dir_of] was given a canonical kind order
     on 2026-08-19 for exactly this reason ("an enumeration change
     silently RENAMED every scenario dir"); the dedup key never was.
     Recorded in pass 3 Attribution (was why_ledger.md §4a). *)
  scenarios_of ~policy:(EN.unselected (EN.full_policy ())) pr

(* ── pass 4 — select ── *)

(** The worlds a RUN asked for: {!worlds} through the
    selection its policy carries. This IS
    {!Canary_project_run.scenarios_of}; the alias exists so a reader sees
    the pass sequence in one file, and so a consumer names the stage
    rather than the function. Pure. *)
let enumerated ?policy (pr : project_run) : Canary_artifact.assignment list =
  scenarios_of ?policy pr

(* ── pass 5 — order (identity + run order) ── *)

(** RUN order: {!enumerated} put through a stable sort on the
    single-valued store state each assignment locks, so scenarios needing
    the same state run consecutively. Pure.

    This is what the runner iterates. Since 2026-08-21 it is NOT the same
    list as {!enumerated} — which is why printing [enumerated] where the
    run order was meant would be wrong. *)
let ordered ?policy (pr : project_run) : Canary_artifact.assignment list =
  scenarios_in_run_order ?policy pr

(* ── pass 6 — realize ── *)

(** What one scenario needs before its commands can be built: the
    workspace directory (which is also the scenario's identity and its
    cache key) and the per-scenario project name [derive_steps] keys
    output under. *)
type scenario_ctx = {
  sc_workspace : string;  (** [scenario_dir_of] — identity + output dir *)
  sc_project : string;    (** "<project>/<safe-basename>" *)
}

(** The naming the runner used to compute inline.

    It used to map [':'], ['#'] and ['+'] out of the basename. That
    sanitizer was removed 2026-08-24, on the user's call that it was an
    old issue whose better answer is a valid naming scheme rather than a
    patch. It had already been dead code: [Canary_artifact.string_of_id]
    emits ['-'], never [':'], so no scenario dir has contained a
    character it mapped for some time. Removing a patch on the consumer
    is only safe if the producer is right, so
    [pipeline.scenario_names_are_born_safe] now asserts the producer's
    claim directly. *)
let ctx_of (pr : project_run) (a : Canary_artifact.assignment) : scenario_ctx =
  let ws = scenario_dir_of ~pr_name:pr.pr_name a in
  { sc_workspace = ws; sc_project = pr.pr_name ^ "/" ^ Filename.basename ws }

let langs = Canary_lang.[ OCaml; Python ]

(** The realized step list for one scenario — [realize ∘ dispatch] then
    [derive_steps]. NOT pure: see the module header. [ctx] is passed in
    rather than recomputed so a caller that already has it (the runner,
    which needs the workspace for other reasons) cannot drift from one
    that does not. *)
(** The binding mechanism the project declares for a language, or the
    language's default. This is the fact [derive_steps] needs in order
    to attach an action context to a step, and the project already has
    it — [pr_binding_decls] is where a project says what its binding IS
    (2026-09-12).

    ONE IMPLEMENTATION (2026-09-16): the body moved to pass 2
    ([Canary_project_analysis.mechanism_of]) and this delegates. Two
    copies of a derivation is the thing pass 2 exists to stop, so it
    would be absurd for pass 2 to land beside one. *)
let mechanism_of_project (pr : project_run) (l : Canary_lang.lang) :
    Canary_mechanism.mechanism =
  Canary_project_analysis.mechanism_of pr l

(** WHAT THE PROJECT ALREADY DECLARED, routed to the runner
    (2026-09-13).

    Two facts, one story. Every project declares an [api_source] — its
    header set, symbol prefixes, the symbols it says are stable, the
    per-language watchlists — and every project that fetches a binding
    from a language PM names that package. Both were declared where the
    RUNNER never looked: on the artifact table and the source repo
    record, which [spec-check] and the CI renderer read and
    [derive_steps] does not. So at run time [spec.api_source] was
    [None] for every project and [binding_user_facing_pkg] was empty
    for all but tiny — which is why the auto-generated summaries, the
    stub inspection among them, existed nowhere but tiny.

    This is the decorative-declaration class that also hid sqlite's
    Python side and its inspector closures. The pattern is always the
    same: a fact stated once, read by the reporting path, and never
    reaching the path that runs.

    Resolution order is [spec-check]'s, deliberately: a spec that fills
    the field itself wins, then the artifact table / source repo, then
    the project's own [pr_api_source]. Several places may say it; they
    now agree about which one answers. *)
(** The project's declared C API, wherever it declared it. The same
    walk [Canary_spec_check.source_repo_of] does — a project's source
    repo is whichever artifact row declares one — then its own
    [pr_api_source]. Exposed because the RESULT TABLE needs it too: to
    say which artifact a violated agreement was reading, it has to ask
    the agreement's methods what they read, and they now ask the
    context, which carries this.

    ONE IMPLEMENTATION (2026-09-16), as above: the body is pass 2's. *)
let declared_api_of (pr : project_run) : Canary_artifact.t option =
  Canary_project_analysis.declared_api_of pr

(** THE STATIC HALF OF COVERAGE (2026-09-14, user) — which claims this
    project cannot carry, and why, derived from its spec rather than
    from a run.

    It used to be a per-step outcome: every method re-answered
    applicability at every firing site and the runner logged the
    answer, so sqlite emitted the same six sentences on each of ten
    scenarios. The fact is a property of the project, so the run stops
    carrying it and this reports it once.

    That keeps the rule the per-step logging existed for — a report
    showing only what found something would read as full coverage —
    while paying for it once instead of sixty times. [--observed] now
    prints what RAN from the log and what CANNOT RUN from here.

    ONE IMPLEMENTATION (2026-09-16): pass 2's, and the move fixed a
    latent bug rather than only relocating one. This iterated the
    registry-wide [langs] — OCaml and Python, always — so a project
    binding only OCaml was asked what its PYTHON binding cannot carry
    and answered at length about a binding it does not have. Pass 2
    iterates the languages the project actually DECLARES, falling back
    to the pair only when it declares none. *)
let unsuited_of (pr : project_run) : Canary_agreement.unsuited list =
  (Canary_project_analysis.of_project_run pr).Canary_project_analysis.an_unsuited

let with_declared_facts (pr : project_run)
    (spec : Canary_step_builder.runner_spec) : Canary_step_builder.runner_spec =
  let api_source =
    match spec.Canary_step_builder.api_source with
    | Some _ as a -> a
    | None -> declared_api_of pr
  in
  (* AND THE PACKAGE EACH BINDING IS. Same story, different field: the
     artifact table names the opam/pip package as the binding row's
     provider, and [runner_spec.binding_user_facing_pkg] asked for it
     again. Only tiny — whose binding is in no store — ever answered,
     so the auto-generated summaries were effectively tiny-only. An
     explicit entry on the spec still wins. *)
  let declared_pkgs =
    List.filter_map
      (fun d ->
        match Canary_project_spec.provider_of_row d with
        | Some (Canary_store_config.Lang_pkg { lang; package; _ }) ->
            Some (lang, package)
        | _ -> None)
      pr.pr_artifacts
  in
  (* into [binding_store_pkg], NOT [binding_user_facing_pkg]: a derived
     package earns the stub inspection and not a surface one. See that
     field's comment for what merging the two cost. *)
  let binding_store_pkg =
    spec.Canary_step_builder.binding_store_pkg @ declared_pkgs
  in
  (* AND WHAT EACH PACKAGE MANAGER DOES INSIDE ITS FETCH, UNSEEN
     (2026-09-23, status.md §2.7 E): the placeholder steps, from the same
     providers. A system package is fetched by the platform's system
     package manager, a language package by its own; [Canary_pm_action]
     says, per package manager, what goes unrecorded inside. Derived for
     every project at once — it is knowledge about the package manager,
     not about a project. *)
  let placeholders =
    List.filter_map
      (fun d ->
        let open Canary_store_config in
        match (d.Canary_project_spec.ar_artifact, Canary_project_spec.provider_of_row d) with
        | Canary_artifact.A_lib _, Some (Sys_pkg _) ->
            Some
              ( Canary_basic.Fetch Canary_basic.Lib,
                Canary_pm_action.inside_install
                  (Canary_store.system_pm_of_platform (Canary_store.platform ()))
                  ~of_binding:false )
        | Canary_artifact.A_lib _, Some (Lang_pkg { pm; _ }) ->
            Some
              ( Canary_basic.Fetch Canary_basic.Lib,
                Canary_pm_action.inside_install pm ~of_binding:false )
        | Canary_artifact.A_binding (lang, _), Some (Lang_pkg { pm; _ }) ->
            Some
              ( Canary_basic.Fetch (Canary_basic.Binding lang),
                Canary_pm_action.inside_install pm ~of_binding:true )
        | _ -> None)
      pr.pr_artifacts
  in
  { spec with
    Canary_step_builder.api_source;
    binding_store_pkg;
    placeholders = spec.Canary_step_builder.placeholders @ placeholders }

let steps_of ?warn ~(root : string) (pr : project_run) ~(ctx : scenario_ctx)
    (a : Canary_artifact.assignment) : Canary_step_model.step list =
  let spec =
    with_declared_facts pr (pr.pr_runner_spec a ~workspace:ctx.sc_workspace ())
  in
  (* [~world:a] is what turns the registry's context query on for this
     scenario's steps: the assignment records how every artifact was
     provisioned, which is exactly what a firing derivation asks. *)
  Canary_step_builder.derive_steps ~root ~project:ctx.sc_project ~langs
    ~world:a ~mechanism_of:(mechanism_of_project pr) ?warn spec

(** One scenario's steps FOR DISPLAY: {!steps_of} itself, over a
    throwaway workspace. None of what a reader needs (tag, action, where a
    probe looks, what an inspection inspects) depends on the output path,
    and the throwaway keeps a display query from materializing a
    scenario's real tree.

    THE RUNNER'S DERIVATION, NOT A SECOND ONE (2026-09-23). This first
    re-derived from the bare runner spec, as [actions_of] always had, and
    so skipped {!with_declared_facts}: the declared binding package is
    what earns a fetched binding its stub inspection, so every such world
    showed one step fewer than it runs. The action SET came out the same —
    an inspection carries its parent's action — which is why nothing
    caught it until a record listed steps. *)
let display_steps_of (pr : project_run) (a : Canary_artifact.assignment) :
    Canary_step_model.step list =
  steps_of ~warn:false ~root:"_out" pr
    ~ctx:{ sc_workspace = "_out/tmp"; sc_project = pr.pr_name }
    a

(** The ACTIONS one scenario's steps carry, for callers that want the
    chain shape and not the commands (the result matrix). *)
let actions_of_steps (steps : Canary_step_model.step list) :
    Canary_basic.action list =
  List.map (fun (s : Canary_step_model.step) -> s.Canary_step_model.action) steps
  |> List.sort_uniq Stdlib.compare

let actions_of (pr : project_run) (a : Canary_artifact.assignment) :
    Canary_basic.action list =
  actions_of_steps (display_steps_of pr a)

(* ── JSON per pass (2026-08-24) ──

   One encoder per pass, living HERE rather than in the CLI, because the
   user's reason for wanting them is structural: if each pass can be
   serialized on its own, the layering is real rather than asserted. A
   pass whose value could not be encoded without reaching into a
   neighbour would be the counter-evidence.

   Stable by construction: assignments are keyed by
   [string_of_assignment], which became CANONICAL (sorted by artifact
   kind) on 2026-08-24 — before that, two runs could encode the same
   world two ways and a diff would show phantom churn. *)

let json_of_placement (id : Canary_artifact.artifact_info)
    (pl : Canary_artifact.placement) : Yojson.Basic.t =
  let v = pl.Canary_artifact.version in
  `Assoc
    [ ("artifact", `String (Canary_artifact.string_of_id id));
      ("provision",
       `String (Canary_artifact.string_of_provision pl.Canary_artifact.provision));
      ("channel", `String (Canary_basic.string_of_channel v.Canary_basic.channel));
      (* "" for a version-ambient placement — the distinction pass 5's
         identity rule turns on, so it is encoded rather than elided *)
      ("version_id", `String v.Canary_basic.id) ]

let json_of_assignment (a : Canary_artifact.assignment) : Yojson.Basic.t =
  `Assoc
    [ ("key", `String (Canary_enumerate.string_of_assignment a));
      ("placements", `List (List.map (fun (id, pl) -> json_of_placement id pl) a))
    ]

(** Pass 1 — declare. *)
let json_declare (pr : project_run) : Yojson.Basic.t =
  let spec = spec_of pr in
  let row (id, (ax : Canary_artifact.artifact_axes)) =
    `Assoc
      [ ("artifact", `String (Canary_artifact.string_of_id id));
        ("universe",
         `List
           (List.map
              (fun (pv, chs) ->
                `Assoc
                  [ ("provision", `String (Canary_artifact.string_of_provision pv));
                    ("channels",
                     `List
                       (List.map
                          (fun c -> `String (Canary_basic.string_of_channel c))
                          chs)) ])
              ax.Canary_artifact.ax_universe));
        ("pins",
         `List
           (List.map
              (fun b -> `String (Canary_basic.string_of_build_id b))
              ax.Canary_artifact.ax_pins));
        ("follows",
         match ax.Canary_artifact.ax_follows with
         | None -> `Null
         | Some f -> `String (Canary_artifact.string_of_id f));
        ("runtime",
         match ax.Canary_artifact.ax_runtime with
         | None -> `Null
         | Some Canary_store.Lockstep -> `String "lockstep"
         | Some Canary_store.Independent -> `String "independent"
         | Some (Canary_store.Ambient why) -> `String ("ambient:" ^ why)) ]
  in
  `Assoc
    [ ("project", `String pr.pr_name); ("pass", `String "declare");
      ("artifacts", `List (List.map row spec.Canary_artifact.ps_universe)) ]

(** Pass 2 — analyse. The chains come first because they are what the
    pass table used to carry as an unnumbered branch, and because
    nothing has ever printed them: [canary paths] shows the unfiltered
    38, and which of them a PROJECT admits was reachable only by
    reading [patterns_of]. *)
let json_analyse (pr : project_run) : Yojson.Basic.t =
  let module A = Canary_project_analysis in
  let an = analysed_of pr in
  let chain c =
    `List
      (List.map
         (fun (a : Canary_basic.action_sig) ->
           `String (Canary_basic.string_of_action a.Canary_basic.as_action))
         c)
  in
  `Assoc
    [ ("project", `String pr.pr_name); ("pass", `String "analyse");
      ("chains", `List (List.map chain an.A.an_chains));
      ("touches",
       `List
         (List.map
            (fun (act, (tc : A.touch)) ->
              let ids l =
                `List
                  (List.map
                     (fun i -> `String (Canary_artifact.string_of_id i))
                     l)
              in
              `Assoc
                [ ("action", `String (Canary_basic.string_of_action act));
                  ("consumes", ids tc.A.tc_consumes);
                  ("produces", ids tc.A.tc_produces) ])
            an.A.an_touches));
      ("bindings",
       `List
         (List.map
            (fun (l, m) ->
              `Assoc
                [ ("lang", `String (Canary_lang.string_of_lang l));
                  ("mechanism", `String (Canary_mechanism.string_of_mechanism m))
                ])
            an.A.an_mechanisms));
      ("declared_api", `Bool (Option.is_some an.A.an_declared));
      ("carries",
       `Assoc
         (List.map
            (fun (l, slugs) ->
              ( Canary_lang.string_of_lang l,
                `List (List.map (fun s -> `String s) slugs) ))
            an.A.an_carries));
      ("unsuited",
       `List
         (List.map
            (fun (u : Canary_agreement.unsuited) ->
              `Assoc
                [ ("agreement", `String u.Canary_agreement.us_slug);
                  ("method", `String u.Canary_agreement.us_method);
                  ("lang",
                   `String (Canary_lang.string_of_lang u.Canary_agreement.us_lang));
                  ("why", `String u.Canary_agreement.us_why) ])
            an.A.an_unsuited)) ]

(** Passes 3 and 4 — enumerate and select. [of_total] is present on
    select so a reader sees the narrowing without a second call. *)
let json_assignments ~(pass : string) ?(of_total : int option)
    (pr : project_run) (asgs : Canary_artifact.assignment list) : Yojson.Basic.t
    =
  `Assoc
    ([ ("project", `String pr.pr_name); ("pass", `String pass);
       ("count", `Int (List.length asgs)) ]
    @ (match of_total with None -> [] | Some n -> [ ("of_total", `Int n) ])
    @ [ ("assignments", `List (List.map json_of_assignment asgs)) ])

(** Pass 5 — order. Each entry carries the store state it locks, which is
    the sort key, so the grouping is readable from the encoding. *)
let json_order ?policy (pr : project_run) : Yojson.Basic.t =
  let rows =
    List.map
      (fun a ->
        `Assoc
          [ ("key", `String (Canary_enumerate.string_of_assignment a));
            ("store_state",
             `Assoc
               (List.map
                  (fun (p, v) -> (p, `String v))
                  (store_state_key pr a))) ])
      (ordered ?policy pr)
  in
  `Assoc
    [ ("project", `String pr.pr_name); ("pass", `String "order");
      ("count", `Int (List.length rows)); ("scenarios", `List rows) ]

(** Pass 6 — realize. NOT pure: see the module header. *)
let json_realize ~(root : string) (pr : project_run)
    (a : Canary_artifact.assignment) : Yojson.Basic.t =
  let ctx = ctx_of pr a in
  let steps = steps_of ~root pr ~ctx a in
  `Assoc
    [ ("project", `String pr.pr_name); ("pass", `String "realize");
      ("scenario", `String (Filename.basename ctx.sc_workspace));
      ("workspace", `String ctx.sc_workspace);
      ("steps",
       `List
         (List.map
            (fun (s : Canary_step_model.step) ->
              `Assoc
                [ ("tag", `String s.Canary_step_model.tag);
                  ("action",
                   `String
                     (Canary_basic.string_of_action s.Canary_step_model.action));
                  ("deps",
                   `List
                     (List.map
                        (fun d -> `String d)
                        s.Canary_step_model.deps)) ])
            steps)) ]
