(** [Canary_enumerate] — the shared abstract enumeration core (ssot §4.2).

    **One** enumeration algorithm over (provision assignment) × (mutation),
    product-then-filter. tiny and every general project are two orthogonal
    *projections* of the same product.

    Stage 1 (project declaration) lives in [Canary_project_spec]; stage 2
    (the enumeration engine) lives here. The dependency is one-way: this
    module consumes [Canary_project_spec] types; [Canary_project_spec] does
    NOT depend on this module. *)

open Base
open Canary_artifact
open Canary_project_spec

(* ── base vocabulary (re-exported for backward compat) ──
   Defined independently from [Canary_project_spec] but equal to the same
   store types — the two definitions are the same type via [Canary_store]. *)

type provision = Canary_store.provision =
  | Absent | Fetched | Built | Installed | Vendored
[@@deriving show, eq]

type artifact = Canary_basic.artifact_kind =
  | Source | Headers | Lib | Binding of Canary_lang.lang
  | Binding_source of Canary_lang.lang | App
[@@deriving show, eq]

let string_of_provision = Canary_store.string_of_provision

(* Re-export [Canary_project_spec] symbols that call sites use via
   [Canary_enumerate.xxx]. *)
let string_of_artifact = Canary_artifact.string_of_artifact
let string_of_id = Canary_artifact.string_of_id
let string_of_app_wiring = Canary_artifact.string_of_app_wiring
let pretty_artifact = Canary_artifact.pretty_artifact
let pretty_id = Canary_artifact.pretty_id
let a_source = Canary_artifact.a_source
let a_headers = Canary_artifact.a_headers
let a_lib = Canary_artifact.a_lib
let a_binding = Canary_artifact.a_binding
let a_app = Canary_artifact.a_app
let kind_of = Canary_artifact.kind_of
let ext_of = Canary_artifact.ext_of

(* ────────────────────────────────────────────────────────────────────
   Dynamic — used / updated during enumeration.
   Types produced by the enumeration or configuring its behaviour.
   ──────────────────────────────────────────────────────────────────── *)

(* ── re-exports from base/ ──
   [build_id], [quality], [good] live in [Canary_basic];
   [placement], [assignment] live in [Canary_artifact].
   Re-exported as type aliases for backward compat. *)

type build_id = Canary_basic.build_id
type quality = Canary_basic.quality
let good = Canary_basic.good
let string_of_build_id = Canary_basic.string_of_build_id
let equal_version = Canary_basic.equal_version
let string_of_version = Canary_basic.string_of_build_id
let equal_build_id = Canary_basic.equal_build_id

type placement = Canary_artifact.placement
type assignment = Canary_artifact.assignment

(** One point of the scenario space: an assignment plus an optional mutation
    on one *provided* artifact ([None] = the positive scenario). *)
(* [mutations] is a LIST (not a single option): a positive point is [[]], a
   single-bad is one, a COMBINATION is several (multiple bad artifacts in one
   scenario). [assignment_of_point] folds them all into their targets' Bad
   quality. enumerate emits 0/1-element lists today; multi-element (curated
   combinations) is the project-policy layer (A4, retiring tiny_full_combinations). *)
type 'm point =
  { assignment : assignment; mutations : (artifact_id * 'm) list }

let placement_of (a : assignment) (id : artifact_id) : placement option =
  List.Assoc.find a id ~equal:equal_artifact_id

let provision_of (a : assignment) (id : artifact_id) : provision =
  match placement_of a id with Some p -> p.provision | None -> Absent

let version_of (a : assignment) (id : artifact_id) : build_id =
  match placement_of a id with
  | Some p -> p.version
  | None -> good Canary_basic.Dev

let provided (a : assignment) (id : artifact_id) : bool =
  not (equal_provision (provision_of a id) Absent)

(* ── dispatch-coordinate reads (general utilities) ──
   A project's runner DISPATCH (which realization a scenario gets) must read
   only these enumeration coordinates — provision / channel / quality of the
   declared artifacts — never dig placement records by hand. Keeping the
   reads here (general) and the case analysis in the project (a pure,
   project-local `case` type) is the dispatch/realization split: dispatch is
   enumeration vocabulary; realizations are the project's command templates. *)

(** The release channel [id] is placed at (Dev when the artifact is absent —
    matches [version_of]'s default; dispatch on provided artifacts only). *)
let channel_of (a : assignment) (id : artifact_id) : Canary_basic.channel =
  (version_of a id).channel

(** The Bad-quality placements of a scenario: [(artifact, opaque tag)] per
    artifact whose version quality is [Bad tag] — [] for a positive scenario.
    The general half of a bad-overlay dispatch (a project maps the tags to
    its own cached-artifact keys). *)
let bad_placements (a : assignment) : (artifact_id * string) list =
  List.filter_map a ~f:(fun (id, pl) ->
      match pl.version.quality with
      | Bad tag -> Some (id, tag)
      | Good -> None)

(* ── mismatch direction (general vocabulary) ──
   Named from the CONSUMER's position relative to the provider:
   [Forward] = consumer ahead (built against a newer API, deployed over an
   older provider — fails on a not-yet-added requirement, c1/c2);
   [Backward] = consumer behind (deployed over a newer provider that BROKE
   compatibility — removed/renamed symbol, soname/symver, c4/c5). *)
type mismatch_direction = Canary_basic.mismatch_direction
let string_of_mismatch_direction = Canary_basic.string_of_mismatch_direction

(** The direction of the consumer↔provider version pairing in scenario [a]
    ([None] = same channel, or either artifact absent). DERIVABLE per
    scenario — what is NOT derivable is whether a consumer variant was
    DESIGNED to carry a version-sensitive requirement; that intent is
    declared data ([Canary_project_run.pr_mismatch_probes]). *)
let mismatch_direction_of (a : assignment) ~(consumer : artifact_id)
    ~(provider : artifact_id) : mismatch_direction option =
  if not (provided a consumer && provided a provider) then None
  else
    match (channel_of a consumer, channel_of a provider) with
    | Canary_basic.Dev, Canary_basic.Stable -> Some Forward
    | Canary_basic.Stable, Canary_basic.Dev -> Some Backward
    | _ -> None

let any_binding_provided (a : assignment) : bool =
  List.exists a ~f:(fun (id, pl) ->
      match id.kind with
      | Binding _ -> not (equal_provision pl.provision Absent)
      | _ -> false)

(** The build edges of a flat assignment, read off the action catalogue (§6.5) —
    the SEAM to the action graph ([make_action_graph]), with NO new edge
    vocabulary. A [Built] artifact's [built_from] = the assignment's other
    artifacts whose kind its Build action CONSUMES (`Build_lib` consumes Source,
    `Build_binding` consumes Lib, …). [built_from_kinds] is INJECTED (the caller
    composes kind→Build-action→[Canary_action.consumes_of_action]) so this layer
    stays free of an action-catalogue dependency. A non-[Built] artifact (Fetched
    from a PM, Vendored) has no build edge. This is the read that proves the flat
    `assignment` and the action graph are the same graph (dynamic_enumeration.md). *)
let built_from_of_assignment
    ~(built_from_kinds :
       Canary_basic.artifact_kind -> Canary_basic.artifact_kind list)
    (a : assignment) (id : artifact_id) : artifact_id list =
  match provision_of a id with
  (* Installed has the same build edges as Built (2026-08-18): it was
     built from the same inputs, then staged *)
  | Built | Installed ->
      let ks = built_from_kinds id.kind in
      List.filter_map a ~f:(fun (other, _) ->
          if (not (equal_artifact_id other id))
             && List.mem ks other.kind ~equal:Poly.equal
          then Some other
          else None)
  | _ -> []

(** Dependency + version filter (product-then-filter, §4.2 / §4.2.2): a lib
    [Built] from source needs the source present; any provided binding needs
    the lib present; any provided app needs a binding to consume (an app with
    no binding is a degenerate combination); and (source-primary) a [Built]
    lib inherits the source's version. A binding's version may still differ
    from the lib's — that difference is the interesting version *mismatch*.
    (The app→binding dependency is "any binding" for now; making it the app's
    *own language* binding needs App to carry a lang — ssot §4.2.3.) *)
(** The source a BUILT binding is built FROM (2026-08-19): its OWN
    declared [Binding_source lang] when the project has one — an off-tree
    binding repo over a prebuilt lib, e.g. zarith's repo above an apt
    libgmp — else the project's lib source, which is the on-tree case
    (z3/llvm build lib and bindings from one checkout). *)
let binding_source_of (s : project_spec) (l : Canary_lang.lang) : artifact_id =
  let own = a_binding_source l in
  if Option.is_some (ps_axes_of s own) then own else a_source

(** The Built-binding↔source channel coupling, for ONE artifact: a binding
    canary builds must match the channel of the source it builds from
    (a Dev-built binding over a stable worktree is not a world). The
    forward cell (Built binding × FETCHED lib — the designed mismatch
    probe) survives: only the source couples, the lib pairing stays free.

    ONE definition, called from both enumeration paths. It was written
    twice — in the product path's post-filter and in the walk's — and the
    copies silently disagreed the moment one learned about off-tree
    binding sources (the walk's copy is the one that runs for zarith, so
    fixing only the other left a Dev binding paired with the 1.14
    worktree). *)
let binding_couples (s : project_spec) (a : assignment) (id : artifact_id) :
    bool =
  match kind_of id with
  | Canary_basic.Binding l ->
      let src = binding_source_of s l in
      (not (equal_provision (provision_of a id) Built))
      || (not (provided a src))
      || Canary_basic.equal_channel
           (version_of a id).Canary_basic.channel
           (version_of a src).Canary_basic.channel
  | _ -> true

(** Is anything in this world BUILT FROM [src]? (2026-08-19) The lib
    builds from the project source; a Built binding builds from its own
    source ({!binding_source_of}). Nothing else consumes a source. *)
let source_is_read (s : project_spec) (a : assignment) (src : artifact_id) :
    bool =
  let lib_builds =
    equal_artifact_id src a_source
    && (equal_provision (provision_of a a_lib) Built
       || equal_provision (provision_of a a_lib) Installed)
  in
  let a_binding_builds =
    List.exists (ps_artifacts s) ~f:(fun id ->
        match kind_of id with
        | Canary_basic.Binding l ->
            equal_provision (provision_of a id) Built
            && equal_artifact_id (binding_source_of s l) src
        | _ -> false)
  in
  lib_builds || a_binding_builds

(** The UNREAD-SOURCE collapse (2026-08-19, the phantom-ref-axis rule
    stated precisely). A world where nothing is built from a source still
    fetches it, but WHICH ref it names changes nothing observable — so N
    declared refs would give N identical runs. Such a world keeps only the
    source's canonical pin (the first declared, stable-first by
    convention).

    This replaces the blunt [~follows:a_lib] the source rows carried: that
    locked the source's channel to the LIB's, which killed the phantoms
    but also forbade the FORWARD cell — a binding built from a dev tree
    probed against the released lib, which is a genuine world precisely
    because something IS built from the dev source there. *)
let source_ref_ok (s : project_spec) (a : assignment) (id : artifact_id) :
    bool =
  match kind_of id with
  | Canary_basic.Source | Canary_basic.Binding_source _ ->
      (not (provided a id))
      || source_is_read s a id
      ||
      (* unread: only the canonical ref survives *)
      (match ps_versions_of s id Fetched with
      | canonical :: _ ->
          Canary_basic.equal_build_id (version_of a id) canonical
      | [] -> true)
  | _ -> true

let assignment_ok (a : assignment) : bool =
  let lib = provision_of a a_lib in
  (* A Built lib needs its source present AND at the same CHANNEL — but only
     when [a_source] is a DECLARED artifact (tiny models source as a separate
     vendored artifact). A project that models Built as self-contained
     (fetches source internally, e.g. sqlite's amalgamation) omits
     [a_source], and the check is moot.

     CHANNEL-level, not build_id-level (2026-08-16, C2): exact-id equality
     was right while sources were version-ambient ([id = ""]). Identity-
     bearing sources (repo pins — a [Repo_axes] family's per-channel repos)
     carry ids the Built lib's channel-level placement can never mirror;
     under id-equality BOTH dev build chains would die. The lib built from
     a checkout inherits its channel — WHICH checkout the scenario is, is
     the source placement's id, already part of the assignment's identity
     (two dev chains: source-fetched-latest vs source-fetched-arbipher). *)
  let source_declared = Option.is_some (placement_of a a_source) in
  (* the built FAMILY (2026-08-18): an Installed lib was built from
     source at that channel too — same coupling as Built *)
  let lib_built_family =
    equal_provision lib Built || equal_provision lib Installed
  in
  (not lib_built_family || not source_declared || provided a a_source)
  && (not lib_built_family || not source_declared
     || Canary_basic.equal_channel
          (version_of a a_lib).Canary_basic.channel
          (version_of a a_source).Canary_basic.channel)
  && List.for_all a ~f:(fun (id, pl) ->
         match kind_of id with
         | Binding _ ->
             equal_provision pl.provision Absent || provided a a_lib
         | App -> equal_provision pl.provision Absent || any_binding_provided a
         | _ -> true)

(* The product over [artifacts] of (provision × version) placements. BOTH
   [provisions_of] and [versions_of] are PER-ARTIFACT (A1 + the version axis):
   each artifact draws from its own universe — real projects are heterogeneous
   (lib={Fetched,Built} at {Stable,Dev}; a binding only Fetched@Stable). A single
   global list for either was a tiny-shaped simplification.

   [versions_of] is additionally PER-PROVISION: an artifact's version universe
   depends on HOW it is provided — a [Fetched] lib is version-ambient (the PM
   picks; declare one representative), a [Built] lib ranges over the versions
   canary can build, a [Vendored] one over the cached variants. Without this the
   flat provision × version product over-generates (e.g. a Vendored@Dev world no
   cached artifact backs, or a Fetched@Dev that only dedups away downstream). *)
let rec assignments_of (artifacts : artifact_id list)
    (provisions_of : artifact_id -> provision list)
    (versions_of : artifact_id -> provision -> Canary_basic.build_id list) :
    assignment list =
  match artifacts with
  | [] -> [ [] ]
  | id :: rest ->
      let tails = assignments_of rest provisions_of versions_of in
      List.concat_map (provisions_of id) ~f:(fun pv ->
          List.concat_map (versions_of id pv) ~f:(fun ver ->
              List.map tails ~f:(fun t ->
                  (id, { provision = pv; version = ver }) :: t)))

(** The full enumeration algorithm: the product of *valid* assignments ×
    (positive + each applicable mutation), producing [point]s. A mutation is
    applicable to an assignment only when its target artifact is provided
    (§4.2: "a mutation applies only to a provided artifact"). Low-level: takes
    already-resolved universes; [run_config] resolves config levels into these,
    and [enumerate] (stage 2) drives it from a declared [project_spec]. *)
let enumerate_points ~(artifacts : artifact_id list)
    ~(provisions_of : artifact_id -> provision list)
    ~(versions_of : artifact_id -> provision -> Canary_basic.build_id list)
    ~(mutations : (artifact_id * 'm) list) : 'm point list =
  assignments_of artifacts provisions_of versions_of
  |> List.filter ~f:assignment_ok
  |> List.concat_map ~f:(fun a ->
         let positive = { assignment = a; mutations = [] } in
         let muts =
           List.filter_map mutations ~f:(fun (s, m) ->
               if provided a s then Some { assignment = a; mutations = [ (s, m) ] }
               else None)
         in
         positive :: muts)

type version_mode = Lockstep | Independent

(* The prebuilt-shadows-source heuristic is UNCONDITIONAL (2026-08-17 as a
   policy item; the policy dropped 2026-08-19, user: "I think we remove
   this feature"). When a Built placement and a prebuilt placement
   (Fetched/Vendored) would materialize the SAME cell — same artifact,
   channel, and version id, everything else identical — the prebuilt wins
   and the Built assignment is dropped: the belief that a same-version
   prebuilt, built with an unknown script, behaves like a self-built one.

   The [Materialize_source] variant (keep both — a separate AUDIT PASS,
   run when we had decided to blame the lib) and its `--audit-lib` rung
   are gone: nothing had used them, and a project that wants its
   source-built lib visible should declare it as a distinct version
   rather than ask a run flag to unhide it. *)

(** Which source-repo REFS a config enumerates (2026-08-17, the z3
    regression-test case): [All_refs] keeps every declared repo; [Refs
    ids] keeps the repos whose source placement's pinned version id is
    in the list (e.g. ["latest"; "pre-10549"] — the bugfix-commit
    regression pair). The SOURCE placement carries the identity (a
    repo's pin id); projects without a declared/pinned source are
    unaffected (nothing to filter). Orthogonal to the [version] axis:
    thin (channel subset) and refs (id subset) compose. *)
type source_ref_level = All_refs | Refs of string list

(** How much of an axis a config expands (ssot §4.2): [Free] collapses to
    one representative; [Subset] is a curated list; [Full] is every value. *)
type 'a level = Free | Subset of 'a list | Full

(** A config assigns one [level] per axis. Instantiating the algorithm with
    a config yields a project's concrete scenarios (ssot §4.2 — "every use
    is one config"). Today the ranged axes are provision, version (per
    artifact × provision) and mutation; mechanism / app-wiring are ranged via
    the artifact-identity set (each [a_binding lang mech] / [a_app wiring] is
    its own enumerated artifact) — a dedicated config axis for them is still
    open. *)
type 'm config = {
  provision : provision level;
  version : Canary_basic.channel level;
  version_mode : version_mode;
  mutation : (artifact_id * 'm) level;
  refs : source_ref_level;
}

(** Instantiate the algorithm with a config, given each axis's universe (its
    full value set). Provision/version [Free] = one representative (the head
    of the universe — a project orders its universe so the representative is
    first); mutation [Free] = the [None] baseline, i.e. no injected fault
    (the positive point is always present), so it resolves to no placements. *)
let run_config ~(artifacts : artifact_id list)
    ~(all_provisions_of : artifact_id -> provision list)
    ~(all_versions_of : artifact_id -> provision -> Canary_basic.build_id list)
    ~(all_mutations : (artifact_id * 'm) list) (cfg : 'm config) : 'm point list =
  (* [Subset] INTERSECTS the axis universe (preserving universe order): a
     config level selects from the declared facts, it never invents a value
     the universe doesn't contain. (Found via z3 + thin_policy, A5 phase 2:
     z3's Built lib ranges over [Dev] only; the verbatim Subset [Stable]
     fabricated a lib Built@Stable world no realization backs — exactly the
     over-generation the per-provision version axis exists to prevent.
     Per-artifact: an artifact whose universe misses every Subset value
     contributes no placement for that provision — e.g. thin z3 drops the
     Built provision entirely and keeps only the fetch chain.) *)
  let resolve lvl all =
    match lvl with
    | Free -> ( match all with x :: _ -> [ x ] | [] -> [] )
    | Subset vs -> List.filter all ~f:(fun x -> List.mem vs x ~equal:Poly.equal)
    | Full -> all
  in
  (* Version levels are channel-typed ([Subset [Stable]]) while the
     universe is build_ids (pinned ids included) — filter by channel. *)
  let resolve_versions lvl all =
    match lvl with
    | Free -> ( match all with x :: _ -> [ x ] | [] -> [] )
    | Subset vs ->
        List.filter all ~f:(fun (x : Canary_basic.build_id) ->
            List.mem vs x.Canary_basic.channel ~equal:Poly.equal)
    | Full -> all
  in
  (* provision + version levels apply PER-ARTIFACT (version additionally
     per-provision) to each artifact's own universe *)
  let provisions_of id = resolve cfg.provision (all_provisions_of id) in
  let versions_of id pv = resolve_versions cfg.version (all_versions_of id pv) in
  let mutations =
    match cfg.mutation with
    | Free -> []  (* the None baseline — positive point only *)
    | Subset vs -> vs
    | Full -> all_mutations
  in
  enumerate_points ~artifacts ~provisions_of ~versions_of ~mutations

(** tiny's config: provision [Free] (collapse to one representative,
    [Built] — the whole pipeline built locally), mutation [Full] (walk every
    defect). Source-[Built] here just means "present locally" — the source
    is the pipeline root, its provision degenerate. *)
let tiny_slice ~(artifacts : artifact_id list)
    ~(mutations : (artifact_id * 'm) list) : 'm point list =
  run_config ~artifacts ~all_provisions_of:(fun _ -> [ Built ])
    ~all_versions_of:(fun _ _ -> [ Canary_basic.good Canary_basic.Dev ])
    ~all_mutations:mutations
    { provision = Free; version = Free; mutation = Full; version_mode = Lockstep;
      refs = All_refs }

(** A general project's config: provision [Full] (walk the provision axis
    over the project's universe), mutation [Free] (positive only). Yields
    one positive point per valid provision assignment (ssl `sys` = all
    [Fetched], ssl `src` = all [Built], … among them). *)
(* [~provisions]/[~versions] here are the GLOBAL convenience form (all artifacts
   share one universe); [run_config] itself is per-artifact. A project with
   heterogeneous universes calls [run_config ~all_provisions_of ~all_versions_of]
   directly. *)
let general_slice ~(artifacts : artifact_id list)
    ~(provisions : provision list)
    ~(versions : Canary_basic.channel list) : 'm point list =
  let versions = List.map versions ~f:Canary_basic.good in
  run_config ~artifacts ~all_provisions_of:(fun _ -> provisions)
    ~all_versions_of:(fun _ _ -> versions) ~all_mutations:[]
    { provision = Full; version = Full; mutation = Free; version_mode = Lockstep;
      refs = All_refs }

(** The repo-REF resolution (2026-08-17, the z3 regression-test case):
    under [Refs ids], keep only the assignments whose SOURCE placement's
    pinned version id is in the list — the bugfix-commit regression pair
    ([--refs latest,pre-10549]) runs just those repos' worlds. Keyed on
    the SOURCE (a repo's identity is its source placement's pin id);
    assignments without a declared source (self-contained builds) pass
    through, and so do UNPINNED sources (an ambient id is no repo ref to
    select on — the filter is inert on projects without repo pins, as
    the CLI flag documents). [All_refs] keeps every declared repo. The
    two resolution passes (shadow, refs) run back to back; the product
    itself is untouched. *)
let ref_filter ~(refs : source_ref_level) (asgs : assignment list) :
    assignment list =
  match refs with
  | All_refs -> asgs
  | Refs ids ->
      let keep (a : assignment) =
        match placement_of a a_source with
        | None -> true
        | Some (pl : placement) ->
            let id = pl.Canary_artifact.version.Canary_basic.id in
            String.is_empty id
            || List.mem ids id ~equal:String.equal
      in
      List.filter asgs ~f:keep

(* ── STAGE 2.5 — SELECTION (2026-08-24, why_ledger.md §7) ──

   Three different things have been called "policy", and only one of them
   is a pass between stage 2 and stage 3:

   - MODEL CONSTRAINTS ({!assignment_ok}, {!binding_couples},
     {!source_ref_ok}, {!shadow_filter}) say a world cannot exist or is
     indistinguishable from another. Not policy: turning one off buys
     wrong or duplicate worlds, not coverage. They stay unconditional
     inside stage 2.
   - SELECTION — "run a subset of the worlds that exist, this time" — is
     THIS. It does not change what exists; it changes what you asked for.
   - RUN CONFIGURATION (tier, failfast, parallelism) is stage 4 and later.

   Why a pass rather than a stage-3 refinement: selection COMMUTES with
   all of stage 3 (dedup keys on the pin id and so does {!ref_filter}; a
   stable sort survives filtering), so correctness does not decide it.
   Legibility does — stage 2's output becomes invocation-independent, so
   it is a fact about the PROJECT rather than about today's flags, and
   "why is this scenario not running" splits into "it does not exist"
   versus "you did not ask for it". *)

(** What a run asked for, as opposed to what the project has. *)
type selection = {
  sel_version : Canary_basic.channel level;
  sel_refs : source_ref_level;
}

let select_all : selection = { sel_version = Full; sel_refs = All_refs }

(** Apply a selection to stage 2's output.

    The version half is the post-filter form of what {!run_config}'s
    [resolve_versions] does by restricting each artifact's universe before
    the product. The two are equivalent for [Subset] because restricting a
    factor of a product equals filtering the product on that factor — and
    that equivalence is CHECKED, not assumed:
    [select.thin_post_filter_equals_universe_restriction] runs both over
    every catalogued project.

    [Free] ("one representative — the head of the universe") has no
    post-filter form that means the same thing, and no policy reaching
    {!enumerate} uses it on the version axis: [full_policy] and
    [thin_policy] use [Full] and [Subset]. The slice functions that do use
    [Free] ({!tiny_slice}, {!general_slice}) build points directly and
    never pass through here. Treated as "no restriction" so the total
    function is total. *)
let select (sel : selection) (asgs : assignment list) : assignment list =
  let version_ok (a : assignment) =
    match sel.sel_version with
    | Full | Free -> true
    | Subset chs ->
        List.for_all a ~f:(fun ((_ : artifact_id), (pl : placement)) ->
            List.mem chs pl.Canary_artifact.version.Canary_basic.channel
              ~equal:Poly.equal)
  in
  asgs |> List.filter ~f:version_ok |> ref_filter ~refs:sel.sel_refs

(** The shadow resolution (2026-08-17, active plan 3): under
    [Shadow_prebuilt], drop an assignment whose artifact has a [Built]
    placement when an OTHERWISE-IDENTICAL assignment carries a prebuilt
    (Fetched/Vendored) placement at the same (channel, version id) — the
    same cell, the prebuilt wins. Conservative: only exact-cell
    duplicates drop — a built binding over a prebuilt lib (the forward
    cell) is a designed scenario, not a shadow duplicate.
    Unconditional since 2026-08-19 (the [Materialize_source] escape and
    its `--audit-lib` rung were removed). *)
let shadow_filter (asgs : assignment list) : assignment list =
  let () = () in
      let prebuilt (pl : placement) =
        match pl.provision with
        | Fetched | Vendored -> true
        (* Installed is deliberately NOT prebuilt (2026-08-18): it is
           a built artifact's staged face — the shadow heuristic only
           collapses Fetched/Vendored onto Built same-version cells *)
        | Built | Installed | Absent -> false
      in
      (* the built side's version identity: SOURCE-PRIMARY — a Built
         artifact's version IS its source's (the explainer's Follows_input
         rule), so the id inherits from the source placement's pin. An
         unknown (empty) version never shadows: the heuristic requires
         the SAME VERSION to be known on both sides (an ambient prebuilt
         can't be believed equivalent to a specific built version — the
         sqlite case: its built amalgamation versions are NOT the
         system's). *)
      let built_version_id (a : assignment) : string =
        if provided a a_source then (version_of a a_source).id else ""
      in
      let same_cell (a : assignment) (id, (pl : placement))
          (other : assignment) =
        let built_id = built_version_id a in
        if String.equal built_id "" then false
        else
          match placement_of other id with
          | Some op ->
              prebuilt op
              && String.equal op.version.id built_id
              && Canary_basic.equal_channel op.version.channel
                   pl.version.channel
              && List.for_all a ~f:(fun (id2, (pl2 : placement)) ->
                     equal_artifact_id id2 id
                     || (match placement_of other id2 with
                         | Some op2 ->
                             equal_build_id op2.version pl2.version
                             && equal_provision op2.provision pl2.provision
                         | None -> false))
          | None -> false
      in
      List.filter asgs ~f:(fun a ->
          not
            (List.exists a ~f:(fun (id, (pl : placement)) ->
                 equal_provision pl.provision Built
                 && List.exists asgs ~f:(same_cell a (id, pl)))))

(** A2 — fold a [point] into a concrete [assignment], the form the run
    consumes. The algorithm keeps the mutation SEPARATE from the all-Good
    assignment ([point.mutation]); the run wants it FOLDED into the target
    artifact's version [quality = Bad tag] (the mutation-agnostic identity, §4.2.2
    P2a). [tag] projects the polymorphic mutation to its opaque string tag. A
    positive point ([mutation = None]) is already an all-Good assignment. *)
let assignment_of_point ~(tag : 'm -> string) (p : 'm point) : assignment =
  List.fold p.mutations ~init:p.assignment ~f:(fun a (aid, m) ->
      List.map a ~f:(fun (id, pl) ->
          if equal_artifact_id id aid then
            (id, { pl with version = { pl.version with quality = Bad (tag m) } })
          else (id, pl)))

(* ── runtime pairings (milestone-(b) slice, general processing) ──
   Resolve each declared [ax_runtime] against ONE enumerated scenario: the
   two-instance structure (what a consumer RUNS over vs what it was built
   against) surfaced from spec data + enumeration coordinates alone — the
   runner's realization is not consulted. GENERAL machinery (this layer),
   not a project-level special case; the node graph ([close_deps]) can
   read the same [ax_runtime] when it wakes. *)

(** One resolved pairing: [rp_run] = the scenario's lib placement
    ([None] for [Ambient] — its lib is outside the enumeration);
    [rp_deploy] = the run-lib is canary-supplied (Built/Vendored) while
    the consumer's own build-lib came from its provider — run-lib ≠
    build-lib, the deploy pairing (v1 rule; refines when a consumer's
    build-lib becomes declarable data). *)
type runtime_pairing = {
  rp_consumer : artifact_id;
  rp_mode : Canary_store.dep_mode;
  rp_run : placement option;
  rp_deploy : bool;
}

let runtime_pairings_of (s : project_spec) (a : assignment) :
    runtime_pairing list =
  let lib_pl = placement_of a a_lib in
  List.filter_map s.ps_universe ~f:(fun (id, ax) ->
      Option.map ax.ax_runtime ~f:(fun mode ->
          match (mode : Canary_store.dep_mode) with
          | Canary_store.Ambient _ ->
              { rp_consumer = id; rp_mode = mode; rp_run = None;
                rp_deploy = false }
          | Canary_store.Lockstep ->
              { rp_consumer = id; rp_mode = mode; rp_run = lib_pl;
                rp_deploy = false }
          | Canary_store.Independent ->
              let deploy =
                match lib_pl with
                | Some pl -> (
                    match pl.provision with
                    (* Installed deploys like Built (2026-08-18): the
                       staged lib is a deployable concrete artifact *)
                    | Built | Installed | Vendored -> true
                    | Fetched | Absent -> false)
                | None -> false
              in
              { rp_consumer = id; rp_mode = mode; rp_run = lib_pl;
                rp_deploy = deploy }))

(** STAGE 2 input — the exploration policy: HOW MUCH of the declared space to
    walk THIS run, plus any faults to inject. [config] sets a [level] per axis
    (Free/Subset/Full); [mutations] is the fault universe — [[]] for a real
    project, ([’m = string] bad-tags) for the tiny-factory. Unlike
    provision/version (whose universes are project facts in the spec), the
    mutation universe is INJECTED — it's a testing policy, so it lives here. *)
type 'm policy = {
  config : 'm config;
  mutations : (artifact_id * 'm) list;
}

(** A real project: walk the whole declared space ([Full] on every axis), inject
    nothing. Every declared provision×version combo becomes one positive
    scenario. (A function, not a value, so its ['m] doesn't get locked by the
    value restriction across projects.) *)
let full_policy () : 'm policy =
  { config = { provision = Full; version = Full; version_mode = Lockstep; mutation = Free;
               refs = All_refs }; mutations = [] }

(** STAGE 2 — enumerate a declared [project_spec] under a [policy] into concrete
    assignments: resolve the config levels over the spec's per-artifact universes
    (+ the policy's mutation universe), then fold each point's mutation into its
    target's version [quality = Bad tag] (A2). A project DECLARES (stage 1),
    canary ENUMERATES (here). [tag] projects the polymorphic mutation to its
    opaque string tag; unused for a positive-only project ([mutations = []]). *)
(** The SELECTION a policy carries — the two axes that are about what a
    run asked for rather than about what exists (why_ledger.md §7). The
    rest of the config ([provision], [version_mode], [mutation]) is not
    selection: it shapes the product itself. *)
let selection_of_policy (p : 'm policy) : selection =
  { sel_version = p.config.version; sel_refs = p.config.refs }

(** The policy with its SELECTION removed — everything a project has,
    before a run narrows it. Pairs with {!select}: for the policies that
    actually reach {!enumerate},
    [enumerate ~policy = select (selection_of_policy policy) ∘
     enumerate ~policy:(unselected policy)]. Pinned by
    [select.thin_post_filter_equals_universe_restriction]. *)
let unselected (p : 'm policy) : 'm policy =
  { p with config = { p.config with version = Full; refs = All_refs } }

(** STAGE 2 proper — every world the project HAS, before a run narrows
    it. Invocation-independent: {!enumerate} passes {!unselected}, so the
    version and refs axes are wide open here and only the model
    constraints prune. That is what makes a stage-2 dump a fact about the
    project rather than about today's flags. *)
let enumerate_product ~(tag : 'm -> string) ~(policy : 'm policy)
    (s : project_spec) : assignment list =
  let assignments =
    run_config ~artifacts:(ps_artifacts s)
      ~all_provisions_of:(ps_provisions_of s)
      ~all_versions_of:(ps_versions_of s) ~all_mutations:policy.mutations
      policy.config
    |> List.map ~f:(assignment_of_point ~tag)
  in
  (* Post-filter: [ax_follows] constraint + the Built-binding↔source
     channel coupling. An artifact whose [ax_follows] points to a leader
     must match the leader's version (Lockstep only); a BUILT binding
     builds FROM the scenario's source (source-primary, the same rule as
     the Built lib) so its channel must match the source's — the forward
     cell (Built binding × FETCHED lib, the designed mismatch probe)
     survives: only the source couples, the lib pairing stays free.
     (Independent mode skips both — the raw free product.) *)
  let assignments =
    if Poly.equal policy.config.version_mode Lockstep then
      List.filter assignments ~f:(fun a ->
          List.for_all (ps_artifacts s) ~f:(fun id ->
              match ps_axes_of s id with
              | Some ax -> (
                  match ax.ax_follows with
                  | Some leader ->
                      (not (provided a id))
                      || (not (provided a leader))
                      || Canary_basic.equal_channel
                           (version_of a id).channel
                           (version_of a leader).channel
                  (* the shared coupling ({!binding_couples}) — a Built
                     binding matches its own source's channel — plus the
                     unread-source collapse ({!source_ref_ok}) *)
                  | None -> binding_couples s a id && source_ref_ok s a id)
              | None -> true))
    else assignments
  in
  assignments |> shadow_filter

(** STAGE 2 then 2.5: the worlds, then the selection a run asked for.
    Split 2026-08-24 (why_ledger.md §7); the composition is pinned
    equal to the old single pass by
    [select.thin_post_filter_equals_universe_restriction]. *)
let enumerate ~(tag : 'm -> string) ~(policy : 'm policy) (s : project_spec) :
    assignment list =
  enumerate_product ~tag ~policy:(unselected policy) s
  |> select (selection_of_policy policy)

(** Read a slot's provision off a concrete action set (which action-graph
    verbs a variant runs): [Build_*] ⇒ [Built], [Fetch _] ⇒ [Fetched], else
    [Absent]. This is the inverse of §6.5's "provision decides which actions
    run" — recovering the provision coordinate from a variant's steps, so a
    general project's hand-written variants can be rendered as enumeration algorithm
    assignments. *)
let provision_of_actions (acts : Canary_basic.action list) (id : artifact_id) :
    provision =
  let has a = List.mem acts a ~equal:Poly.equal in
  match id.kind with
  | Source -> if has (Canary_basic.Fetch Canary_basic.Source) then Fetched else Absent
  | Lib ->
      (* Install first (2026-08-18): the single-action round-trip
         [Install_lib] reads Installed. A REAL world's action set is
         lossy here — the built family shares the build steps, so an
         Installed world's set reads [Built] — this inverse is the
         synthetic round-trip tool, not a world classifier. *)
      if has Canary_basic.Install_lib then Installed
      else if has Canary_basic.Build_lib then Built
      else if has (Canary_basic.Fetch Canary_basic.Lib) then Fetched
      else Absent
  | Binding l ->
      (* the concrete binding *instance* (lang × mechanism): a *static*
         binding (cext/cstubs) is compiled — [Build_binding l] ⇒ [Built],
         else [Fetch (Binding l)] ⇒ [Fetched]. A *dynamic* binding
         (ctypes/dynlink) has no compile verb — it is pure source that
         dlopens the lib at runtime, so it is provided (present locally)
         wherever the lang's binding is set up. *)
      let dynamic =
        match id.ext with
        | Ext_mechanism m ->
            (match Canary_mechanism.discipline_of_mechanism m with
             | Canary_mechanism.Dynamic_ffi -> true
             | Canary_mechanism.Static_c_abi -> false)
        | _ -> false
      in
      if dynamic then
        (* no Build_binding verb for it; present once the lang binding exists *)
        if has (Canary_basic.Build_binding l)
           || has (Canary_basic.Fetch (Canary_basic.Binding l))
        then Built
        else Absent
      else if has (Canary_basic.Build_binding l) then Built
      else if has (Canary_basic.Fetch (Canary_basic.Binding l)) then Fetched
      else Absent
  | Headers | App ->
      (* not independently provisioned by an action verb (Headers ride the
         source/lib; App is the consumer) — [Absent] in the action view. *)
      Absent
  | Binding_source l ->
      if has (Canary_basic.Fetch (Canary_basic.Binding_source l)) then Fetched
      else Absent

(** The assignment a variant's action set implies: one provision per artifact
    (via [provision_of_actions]), all at the variant's [version] (a variant
    picks a single version — actions do not encode version, so it is passed
    in; per-artifact version *mismatch* is a capability of the algorithm the
    hand-written variants don't yet exercise, §4.2.2). *)
let assignment_of_actions ~(artifacts : artifact_id list)
    ~(version : Canary_basic.channel) (acts : Canary_basic.action list) :
    assignment =
  List.map artifacts ~f:(fun id ->
      (id, { provision = provision_of_actions acts id; version = good version }))

(** Pretty an assignment as "source=fetched@dev lib=built@dev …" (version
    shown only where the artifact is provided). *)
(** The assignment's CANONICAL string — the dedup key in
    [Canary_project_run.scenarios_of], the scenario label the pre/post
    join matches on, and (2026-08-24) the key a JSON dump must be stable
    under.

    CANONICAL since 2026-08-24: the pairs are sorted by artifact kind
    before printing, so the string is a function of the assignment's
    CONTENT rather than of the order the enumerator happened to build it
    in. The two enumerators ({!enumerate_product} and
    {!enumerate_follows_tree}) produce the same assignments in different
    pair orders, so without this the same world could key two ways —
    and the key is what dedup compares. [scenario_dir_of] was given the
    same treatment on 2026-08-19, for the same reason and with the same
    argument: "sorting by artifact kind makes the name a function of the
    assignment's CONTENT". The dedup key was simply missed then. *)
let string_of_assignment (a : assignment) : string =
  let canonical =
    List.stable_sort a ~compare:(fun (x, _) (y, _) ->
        Int.compare
          (Canary_basic.kind_order (kind_of x))
          (Canary_basic.kind_order (kind_of y)))
  in
  String.concat ~sep:" "
    (List.map canonical ~f:(fun (id, pl) ->
         let base = string_of_id id ^ "=" ^ string_of_provision pl.provision in
         if equal_provision pl.provision Absent then base
         else base ^ "@" ^ string_of_version pl.version))

(* ── tree-structured enumeration (2026-08-07) ──
   Walks the dependency DAG instead of flattening into a product. Children
   are additive; version propagates along build edges; constraints are
   embedded in the walk structure itself — no external cartesian filter.

   Source is a build-dependency child of lib (not an independent root):
   when lib is Built, source is walked inside lib's walk with lockstep
   (this IS the source-primary constraint, structural not a filter);
   when lib is Fetched, source is walked unconstrained. The
   multiplication of source × lib exists because building a binding
   needs both; without a Built lib (or without a lib at all), source
   and lib don't need pairing. *)

(* ── THE SECOND STAGE-2 CONSTRUCTION (named 2026-08-24) ──

   There are TWO enumerators, and neither is legacy — they are different
   constructions that agree on content for every spec we have:

   - {!enumerate_product} — product-then-filter, the model the docs
     describe (design/enumeration/stage2_filters.md). MUTATION-AWARE: it
     takes [~tag] and folds each point's mutation into its target's
     [quality = Bad tag]. tiny's oracle needs that; the general projects
     do not use it.
   - {!enumerate_follows_tree} (here) — a ROOT/CHILD walk over the
     [ax_follows] relation, positive-only (no mutation axis at all). This
     is what {!patterns_of} calls, so it is what [scenarios_of] and
     therefore the RUNNER use.

   Measured 2026-08-24 over every catalogued project: same assignments,
   but the PAIRS WITHIN an assignment come out in different orders — and
   [string_of_assignment] is the dedup key in [scenarios_of], which is
   order-sensitive. [scenario_dir_of] was given a canonical kind order on
   2026-08-19 for exactly this reason; the dedup key never was. Both
   follow-ons (canonical key, then reconciling the two) are in
   doc/canary/project/status_project.md.

   Until then: a caller that needs what the RUNNER enumerates must reach
   this one, and {!Canary_pipeline.worlds} routes through [scenarios_of]
   so it cannot become a third opinion. *)
let enumerate_follows_tree ~(policy : 'm policy) (s : project_spec) : assignment list =
  let artifacts = ps_artifacts s in
  let follows_of id = match ps_axes_of s id with Some ax -> ax.ax_follows | None -> None in
  let provisions_of id = ps_provisions_of s id in
  let versions_of id pv = ps_versions_of s id pv in
  let resolve lvl all =
    match lvl with
    | Free -> ( match all with x :: _ -> [ x ] | [] -> [] )
    | Subset vs -> List.filter all ~f:(fun x -> List.mem vs x ~equal:Poly.equal)
    | Full -> all
  in
  (* Version levels are channel-typed while the universe is build_ids —
     filter by channel. *)
  let resolve_versions lvl all =
    match lvl with
    | Free -> ( match all with x :: _ -> [ x ] | [] -> [] )
    | Subset vs ->
        List.filter all ~f:(fun (x : Canary_basic.build_id) ->
            List.mem vs x.Canary_basic.channel ~equal:Poly.equal)
    | Full -> all
  in
  let cfg = policy.config in
  (* Follows children: artifacts whose [ax_follows] points to [parent]. *)
  let follows_children_of parent =
    List.filter artifacts ~f:(fun child ->
        match follows_of child with
        | Some leader -> equal_artifact_id leader parent
        | None -> false)
  in
  (* An artifact is a root when it doesn't follow anyone AND it is not a
     build-dependency of another declared artifact (source is walked
     inside lib's sub-tree, not as a peer root). An artifact that IS
     followed by others is the leader of a sub-tree — it stays a root;
     its followers are children and are excluded from roots. *)
  let is_build_dep id =
    List.exists artifacts ~f:(fun other ->
        List.exists (build_deps_of s other) ~f:(fun bd ->
            equal_artifact_id bd id))
  in
  let is_root id =
    Option.is_none (follows_of id)           (* doesn't follow anyone *)
    && not (is_build_dep id)                  (* not a build-dep *)
  in
  let roots = List.filter artifacts ~f:is_root in
  (* Walk: enumerate placements for an artifact, then walk its children
     (follows-children + build-deps). Children are added via cartesian
     product so every assignment carries ALL children (one variant per
     child). Lockstep applies: always for follows-children, only for
     build-deps when the parent is Built (source-primary: a Built lib
     must be built from source at the same version). *)
  let rec walk (ancestors : assignment) (id : artifact_id) : assignment list =
    let pvs = resolve cfg.provision (provisions_of id) in
    List.concat_map pvs ~f:(fun pv ->
        let vers = resolve_versions cfg.version (versions_of id pv) in
        List.concat_map vers ~f:(fun ver ->
            let placement = { provision = pv; version = ver } in
            let a = (id, placement) :: ancestors in
            let follows_kids = follows_children_of id in
            let build_kids = build_deps_of s id in
            (* Source is always walked (for header inspection when lib is
               Fetched, for build when lib is Built). The difference is
               only in lockstep: source is lockstep'd when parent is Built
               (source-primary), unconstrained when parent is Fetched. *)
            let all_kids = follows_kids @ build_kids in
            if List.is_empty all_kids then [ a ]
            else
              let child_results_per_kid =
                List.map all_kids ~f:(fun kid ->
                    let results = walk a kid in
                    let lockstep =
                      if Poly.equal cfg.version_mode Lockstep then
                        match follows_of kid with
                        | Some _ -> true
                        | None ->
                            (* the built family: an Installed parent was
                               built from source at the same channel too *)
                            equal_provision pv Built
                            || equal_provision pv Installed
                      else false
                    in
                    if lockstep then
                      List.filter results ~f:(fun ka ->
                          match placement_of ka kid with
                          | Some kp ->
                              Canary_basic.equal_channel
                                kp.version.channel ver.Canary_basic.channel
                          | None -> true)
                    else results)
              in
              (* Merge children into the parent. Each child's walk
                 result includes the full ancestor chain; merge takes
                 the union per artifact_id (last write wins — children
                 override ancestors on their own artifact). *)
              let merge_assignments (base : assignment)
                  (child : assignment) : assignment =
                List.fold child ~init:base ~f:(fun acc (id, pl) ->
                    if List.exists acc ~f:(fun (id', _) ->
                        equal_artifact_id id id')
                    then acc
                    else (id, pl) :: acc)
              in
              let rec merge_children = function
                | [] -> [ a ]  (* no children: parent + ancestors *)
                | kids :: rest ->
                    List.concat_map kids ~f:(fun kid_a ->
                        List.map (merge_children rest) ~f:(fun rest_a ->
                            merge_assignments rest_a kid_a))
              in
              merge_children child_results_per_kid))
  in
  let root_results = List.map roots ~f:(walk []) in
  (* Cartesian product of root sub-trees. No source-primary filter needed —
     it's already encoded in the walk (source is a child of lib, lockstep'd
     when lib is Built). *)
  let rec cart = function
    | [] -> [ [] ]
    | xs :: rest ->
        List.concat_map xs ~f:(fun x ->
            List.map (cart rest) ~f:(fun t -> x @ t))
  in
  let assignments = cart root_results in
  (* Lockstep matching policies beyond the structural walk (2026-08-17,
     the zarith 2×2): the shared {!binding_couples} — a BUILT binding
     matches the channel of the source it builds from (its own
     [Binding_source] when declared, else the lib's). Independent mode
     skips it — the raw free product (the enumeration/config split). *)
  let assignments =
    if Poly.equal cfg.version_mode Lockstep then
      List.filter assignments ~f:(fun a ->
          List.for_all (ps_artifacts s) ~f:(fun id ->
              binding_couples s a id && source_ref_ok s a id))
    else assignments
  in
  assignments
  |> shadow_filter
  |> ref_filter ~refs:cfg.refs

(* ── pattern naming (2026-08-08) ──
   Maps a concrete assignment to the abstract action-chain pattern it
   instantiates. The pattern is determined by which artifacts are provided
   and at which provisions — the action composition falls out from that. *)

(** The abstract shape of a scenario — which actions compose to produce it. *)
type scenario_pattern =
  | Fetch_chain             (** every artifact Fetched — PM provides all *)
  | Build_chain_follows     (** source@v → Built lib@v → Built binding@v *)
  | Build_chain_independent (** Built lib, Fetched binding, no follows *)
  | Mixed_provision         (** Fetched lib → Built binding *)
  | No_source_build         (** Built lib, no source declared *)
  | Deploy_mismatch         (** Fetched binding over Built lib, channels differ *)
  | Unknown                 (** any shape not covered above *)

let string_of_scenario_pattern = function
  | Fetch_chain -> "fetch-chain"
  | Build_chain_follows -> "build-chain(follows)"
  | Build_chain_independent -> "build-chain(independent)"
  | Mixed_provision -> "mixed-provision"
  | No_source_build -> "no-source-build"
  | Deploy_mismatch -> "deploy-mismatch"
  | Unknown -> "unknown"

(** Classify an assignment into its scenario pattern.
    The pattern is the action chain implied by the provisions:
    - Fetched → Fetch actions (PM provides)
    - Built → Build actions (compiled from source)
    - Version channels tell whether follows/lockstep holds. *)
let pattern_of_assignment (a : assignment) : scenario_pattern =
  let lib_prov = provision_of a a_lib in
  let source_declared = Option.is_some (placement_of a a_source) in
  let any_binding_built =
    List.exists a ~f:(fun (id, pl) ->
        match kind_of id with Binding _ -> equal_provision pl.provision Built | _ -> false)
  in
  let any_binding_fetched =
    List.exists a ~f:(fun (id, pl) ->
        match kind_of id with Binding _ -> equal_provision pl.provision Fetched | _ -> false)
  in
  let has_binding = any_binding_built || any_binding_fetched in
  let all_bindings_fetched = has_binding && not any_binding_built in
  let lib_chan = channel_of a a_lib in
  let binding_chan =
    match List.find a ~f:(fun (id, _) -> match kind_of id with Binding _ -> true | _ -> false) with
    | Some (id, _) -> channel_of a id
    | None -> lib_chan
  in
  let lockstep = Canary_basic.equal_channel binding_chan lib_chan in
  if not has_binding then Unknown
  else match lib_prov with
  | Fetched when all_bindings_fetched -> Fetch_chain
  | Fetched when any_binding_built -> Mixed_provision
  (* Installed groups with Built (2026-08-18): the staged chain IS a
     build chain plus its staging *)
  | (Built | Installed) when any_binding_built && lockstep && source_declared ->
      Build_chain_follows
  | (Built | Installed) when any_binding_built && lockstep && not source_declared ->
      No_source_build
  | (Built | Installed) when all_bindings_fetched && lockstep ->
      Build_chain_independent
  | (Built | Installed) when all_bindings_fetched && not lockstep ->
      Deploy_mismatch
  | (Built | Installed) when any_binding_built && not lockstep ->
      Unknown   (* cross-channel built binding over built lib — shouldn't happen *)
  | _ -> Unknown

(* ── pattern-based enumeration (2026-08-08) ──
   Enumerates scenarios as action chains rather than artifact placements.
   Action signatures live in [Canary_action]; this module uses them to
   build chains and enumerate version combinations. *)

(** Find the declared artifact id for a coarse [kind] in the spec. *)
let find_artifact_of_kind (s : project_spec) (k : artifact) : artifact_id option =
  List.find (ps_artifacts s) ~f:(fun id -> equal_artifact id.kind k)

(** Whether the spec declares [kind] at all. *)
let spec_has_kind (s : project_spec) (k : artifact) =
  Option.is_some (find_artifact_of_kind s k)

(** Does the spec declare at least one STATIC binding artifact for
    [lang]? A build_binding chain only applies when some binding of
    that language compiles (M2 step 3 — a Dynamic_ffi binding has no
    build stage; the derivation reads the artifact's mechanism key). *)
let has_static_binding (s : project_spec) (l : Canary_lang.lang) : bool =
  List.exists (ps_artifacts s) ~f:(fun id ->
      match id.Canary_artifact.kind with
      | Canary_basic.Binding l' when Poly.equal l l' -> (
          match id.Canary_artifact.ext with
          | Canary_artifact.Ext_mechanism m ->
              Poly.equal (Canary_mechanism.discipline_of_mechanism m)
                Canary_mechanism.Static_c_abi
          | _ -> false)
      | _ -> false)

(** Which build_ids the spec declares for Fetching [kind] (pins included). *)
let fetch_versions_of (s : project_spec) (kind : artifact)
    : Canary_basic.build_id list =
  match find_artifact_of_kind s kind with
  | Some id -> ps_versions_of s id Fetched
  | None -> []

(* ── universal chain table (2026-08-09) ──
   Pre-computed from the action catalogue. Every possible ordered action
   chain ending at a terminal (probe). A chain is valid for a project if
   the spec declares all required artifact kinds. Version enumeration
   happens within each valid chain. *)

(** The terminal (probe) actions from the catalogue. *)
let terminals : Canary_basic.action_sig list =
  List.filter Canary_basic.action_catalogue ~f:(fun a ->
      match a.Canary_basic.as_action with
      | Canary_basic.Probe_binding _ | Canary_basic.Probe_lib
      | Canary_basic.Probe_app _ -> true
      | _ -> false)

(** The non-terminal (Fetch/Build) actions from the catalogue. *)
let non_terminals : Canary_basic.action_sig list =
  List.filter Canary_basic.action_catalogue ~f:(fun a ->
      not (List.mem terminals a ~equal:Poly.equal))

(** Build all possible chains ending at [terminal] by walking backward
    through the action catalogue. For each input kind of an action,
    both Fetch and Build variants are tried. Returns the set of chains
    (each chain is ordered: inputs before outputs, terminal last).
    [seen] prevents infinite loops from circular deps. *)
let chains_for (terminal : Canary_basic.action_sig)
    : Canary_basic.action_sig list list =
  let module B = Canary_basic in
  let producers_of (kind : artifact) : B.action_sig list =
    List.filter non_terminals ~f:(fun a ->
        equal_artifact a.B.as_produces kind)
  in
  let rec build (needed : artifact list) (seen : artifact list)
      : B.action_sig list list =
    match needed with
    | [] -> [ [] ]
    | k :: rest ->
        if List.mem seen k ~equal:equal_artifact then
          build rest seen
        else
          let prods = producers_of k in
          if List.is_empty prods then
            build rest seen
          else
            (* OPTIONAL consume (2026-08-18, the OFF-TREE binding source):
               a Binding_source consumed by the binding build branches
               BOTH ways — WITH its fetch (the off-tree spec: the binding
               lives in its own repo) and WITHOUT (the on-tree spec: the
               binding's source rides the lib's — no fetch step). A
               mandatory consume would demand the artifact in EVERY spec
               and break all on-tree projects. *)
            let with_prods =
              List.concat_map prods ~f:(fun prod ->
                  let subs = build (prod.B.as_consumes @ rest) (k :: seen) in
                  List.map subs ~f:(fun sub -> prod :: sub))
            in
            (match k with
             | Binding_source _ -> build rest seen @ with_prods
             | _ -> with_prods)
  in
  let chains = build terminal.B.as_consumes [] in
  List.map chains ~f:(fun c -> c @ [ terminal ])

(** The universal chain table — all possible chains for all terminals.
    Computed once from the action catalogue; shared across projects. *)
let universal_chains : (Canary_basic.action_sig * Canary_basic.action_sig list) list =
  List.concat_map terminals ~f:(fun term ->
      List.map (chains_for term) ~f:(fun chain -> (term, chain)))

(** Whether a chain is applicable to [spec]: every non-terminal action's
    output kind must be declared with the right provision in the spec.
    Vendored artifacts (supplied, no action) pass through — they don't
    need Fetch or Build in the chain. *)
let chain_applicable (s : project_spec)
    (chain : Canary_basic.action_sig list) : bool =
  List.for_all chain ~f:(fun act ->
      let kind = act.Canary_basic.as_produces in
      equal_artifact kind App  (* terminals *)
      || ((match act.Canary_basic.as_action with
           (* M2 step 3: a build_binding action needs a STATIC binding —
              a dynamic binding (ctypes/dynlink) has no build stage. *)
           | Canary_basic.Build_binding l -> has_static_binding s l
           | _ -> true)
         && (match find_artifact_of_kind s kind with
             | Some id ->
                 let provs = ps_provisions_of s id in
                 let needed = match act.Canary_basic.as_version with
                   | Canary_basic.Ambient -> Fetched
                   | Canary_basic.Follows_input -> Built
                 in
                 List.mem provs needed ~equal:equal_provision
                 (* Vendored is also valid: the artifact exists, just not
                    built/fetched by canary. The chain doesn't need an action. *)
                 || List.mem provs Vendored ~equal:equal_provision
             | None ->
                 equal_artifact kind Source)))

(** The provision each action in a chain requires: Ambient → Fetched,
    Follows_input → Built. Terminals (probes) are skipped. *)
let provision_of_action (act : Canary_basic.action_sig) : provision option =
  if List.mem terminals act ~equal:Poly.equal then None
  else match act.Canary_basic.as_version with
  | Canary_basic.Ambient -> Some Fetched
  | Canary_basic.Follows_input -> Some Built

(** Pattern-based enumeration using the universal chain table.
    1. Filter universal chains applicable to the spec (provision-aware).
    2. Enumerate version combinations via [enumerate_follows_tree]
       (handles lockstep and source-primary).
    3. Match each assignment to its chain by provision. *)
let patterns_of ?(policy = full_policy ()) (s : project_spec)
    : (Canary_basic.action_sig list * assignment) list =
  let chains =
    List.filter_map universal_chains ~f:(fun (_, chain) ->
        if chain_applicable s chain then Some chain else None)
  in
  let matches a chain =
    List.for_all chain ~f:(fun act ->
        match provision_of_action act with
        | None -> true
        | Some needed ->
            match find_artifact_of_kind s act.Canary_basic.as_produces with
            | Some id ->
                let pv = provision_of a id in
                (* Vendored: artifact is supplied, the action doesn't
                   fire. Installed: provided by the staging action — the
                   chain matches like the built family (2026-08-18). *)
                equal_provision pv Vendored
                || equal_provision pv Installed
                || equal_provision pv needed
            | None -> true)
  in
  let assignments = enumerate_follows_tree ~policy s in
  let seen = Hashtbl.create (module String) in
  List.concat_map assignments ~f:(fun a ->
      let key = string_of_assignment a in
      if Hashtbl.mem seen key then []
      else (
        Hashtbl.set seen ~key ~data:();
        match List.find chains ~f:(fun c -> matches a c) with
        | Some chain -> [ (chain, a) ]
        | None -> []))
