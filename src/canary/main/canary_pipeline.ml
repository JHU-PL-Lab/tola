(** [Canary_pipeline] — the enumeration pipeline as NAMED PASSES.

    2026-08-24, the first step of [doc/canary/design/enumeration/stage2_enumerate_worlds.md Attribution]
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
      │ worlds                                             (stage 2)
      ▼ assignment list          — what worlds the project HAS
      │ enumerated ?policy                                 (stage 2.5)
      ▼ assignment list          — what this RUN asked for
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

(** Which worlds the project HAS — the product with the five model
    constraints applied and NO selection. Invocation-independent: this
    list does not depend on [--thin] or [--refs], which is what makes a
    stage-2 dump a fact about the project rather than about today's flags
    (stage 2 Attribution; was why_ledger.md §7). Pure. *)
let worlds (pr : project_run) : Canary_artifact.assignment list =
  let module EN = Canary_enumerate in
  (* THROUGH [scenarios_of], deliberately. Stage 2 has two
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
     Recorded in stage 2 Attribution (was why_ledger.md §4a). *)
  scenarios_of ~policy:(EN.unselected (EN.full_policy ())) pr

(** Stage 2.5 — the worlds a RUN asked for: {!worlds} through the
    selection its policy carries. This IS
    {!Canary_project_run.scenarios_of}; the alias exists so a reader sees
    the pass sequence in one file, and so a consumer names the stage
    rather than the function. Pure. *)
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
    (2026-09-12). *)
let mechanism_of_project (pr : project_run) (l : Canary_lang.lang) :
    Canary_mechanism.mechanism =
  match
    List.find_opt
      (fun (d : Canary_binding_decl.binding_decl) ->
        Stdlib.( = )
          (Canary_mechanism.info_of_mechanism d.Canary_binding_decl.mechanism)
            .Canary_mechanism.mi_lang
          l)
      pr.pr_binding_decls
  with
  | Some d -> d.Canary_binding_decl.mechanism
  | None ->
      Option.value
        (Canary_mechanism.default_mechanism_of_lang l)
        ~default:Canary_mechanism.Cstubs

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
    context, which carries this. *)
let declared_api_of (pr : project_run) : Canary_artifact.t option =
  let from_source =
    List.find_map
      (fun d ->
        match Canary_project_spec.provider_of_row d with
        | Some (Canary_store_config.Repo r)
        | Some (Canary_store_config.Repo_axes (r :: _)) ->
            r.Canary_artifact_source.api_source
        | _ -> None)
      pr.pr_artifacts
  in
  match from_source with Some _ -> from_source | None -> pr.pr_api_source

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
  { spec with Canary_step_builder.api_source; binding_store_pkg }

let steps_of ~(root : string) (pr : project_run) ~(ctx : scenario_ctx)
    (a : Canary_artifact.assignment) : Canary_step_model.step list =
  let spec =
    with_declared_facts pr (pr.pr_runner_spec a ~workspace:ctx.sc_workspace ())
  in
  (* [~world:a] is what turns the registry's context query on for this
     scenario's steps: the assignment records how every artifact was
     provisioned, which is exactly what a firing derivation asks. *)
  Canary_step_builder.derive_steps ~root ~project:ctx.sc_project ~langs
    ~world:a ~mechanism_of:(mechanism_of_project pr) spec

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
      (* "" for a version-ambient placement — the distinction stage 4's
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

(** Passes 2 and 3 — enumerate and select. [of_total] is present on
    select so a reader sees the narrowing without a second call. *)
let json_assignments ~(pass : string) ?(of_total : int option)
    (pr : project_run) (asgs : Canary_artifact.assignment list) : Yojson.Basic.t
    =
  `Assoc
    ([ ("project", `String pr.pr_name); ("pass", `String pass);
       ("count", `Int (List.length asgs)) ]
    @ (match of_total with None -> [] | Some n -> [ ("of_total", `Int n) ])
    @ [ ("assignments", `List (List.map json_of_assignment asgs)) ])

(** Pass 4 — order. Each entry carries the store state it locks, which is
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

(** Pass 5 — realize. NOT pure: see the module header. *)
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
