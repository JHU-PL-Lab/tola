(** LEGACY — scenario pattern catalogue (Sc.N / Bs.N).

    This module holds the HAND-LISTED abstract scenario *patterns* —
    named collections of actions over artifact kinds, with optional
    mutation origins. It does NOT drive the enumeration engine; the
    engine lives in {!Canary_enumerate} and produces concrete
    [{!Canary_artifact.assignment}]s.

    Role of this module (2026-08-08):
    - The [good_scenarios] catalogue provides STABLE IDENTIFIERS
      ("Sc.1", "Sc.2.OCaml", …) that name the abstract shape of a
      scenario. These ids are SSOT-stable (like GitHub issue numbers)
      and appear in the manuscript.
    - Concrete scenarios produced by [Canary_enumerate.enumerate_follows_tree]
      instantiate one or more of these patterns. The naming bridge
      (assignment → pattern ids) is the next step.
    - The mutation vocabulary ([mutation_kind], [manifest], [detector],
      [origin]) and the contract-binding machinery serve the tiny
      factory's expectation lowering and the compat surface theory.

    NOT part of the enumeration pipeline. The word "pattern" (not
    "scenario") should be used for the constructs in this file; the
    word "scenario" belongs to concrete assignments from the engine.

    See [doc/canary/design/enumeration/stage0_naming.md] for the split
    (pattern vs scenario vs stage vs path pattern); it replaced the
    retired scenario_terms.md. *)

(** Scenario type — project-agnostic, unified for good and bad.

    A [scenario] names a collection of actions over related
    artifacts. Good scenarios (Sc.N) have [origin = None];
    bad scenarios (Bs.N) attach an [origin] naming the cause
    of badness (today: [Mutation]; reserved:
    [Version_mismatch], [Packaging]). From the artifact's
    perspective there is no structural difference — a bad
    scenario is just a scenario whose world has one origin.

    Design notes (per [doc/canary/design/ssot.md] §5 / §6 / §9.3):

    - [related_artifacts] is no longer a field — it derives
      from [actions] via [related_artifacts_of_actions]
      (§7.9, 2026-07-10). Per-action consumes/produces table
      lives in {!Canary_action.artifacts_of_action} (moved
      2026-07-22 to colocate with [store_actions]) and in
      SSOT §6.5.
    - [id] is a string. [Sc_id.t] as a distinct type is deferred
      until the Sc.N / Bs.N enumeration stabilises.
    - [manifest] and [detector] on [mutation] are
      possibilistic — they depend on tool strictness and probe
      design. Encoded here so the code can talk about
      "may-manifest" and "detection-gap" cases; they're
      annotations on the constructed scenario, not part of the
      physical setup.
    - [mutation_kind] reuses [artifact_kind] for
      artifact-flavoured mutations, with [On_behavior] as the
      one artifact-agnostic case (source patch with no surface
      change). Package mutations use
      [On_artifact <package-flavoured-kind>] once tiny grows a
      package variant. *)

(* ---------- mutation ---------- *)

type mutation_kind =
  | On_artifact of Canary_basic.artifact_kind
      (** [Source] → source patch;
          [Lib] → binary surgery on the built lib;
          [Binding L] → source patch on that binding's files;
          [Headers] → header patch;
          [App] → app-level mutation. *)
  | On_behavior
      (** Source-level change that leaves the surface intact —
          [behavior_silent] is the canonical case. Distinct
          because no surface comparator can catch it; only
          runtime probes can. *)

(** Where the failure produced by a mutation surfaces.
    Possibilistic — depends on tool strictness (e.g. mold vs
    permissive linker) and probe design. *)
type manifest =
  | Definite of string       (** always at this scenario id (Sc.N) *)
  | Possible of string list  (** one of these, tool-dependent *)
  | Unknown_gap              (** no known manifestation today (agreement gap) *)

(** Which checker catches the mutation, if any. Also
    possibilistic — [Detector_gap] means no checker is wired for
    this mutation today; the mutation constructs a bad
    artifact that no comparator observes. *)
type detector =
  | Wired of Canary_compat.contract_id
  | Detector_gap

type mutation = {
  target   : Canary_basic.artifact_kind;
                             (** the mutated artifact —
                                 invariant (checked by
                                 [validate_mutation_target]):
                                 must appear in the owning
                                 scenario's derived
                                 [related_artifacts]. *)
  kind     : mutation_kind;
  manifest : manifest;
  detector : detector;
}

(** Origin of a bad scenario's badness. Bad scenarios today
    all have [Mutation] origin (tiny's 13 Bs entries). Other
    origins are reserved for future modeling:
    - [Version_mismatch]: pair well-formed artifacts at
      incompatible versions (e.g. llvm 21 example against
      llvm.19-shared binding — currently modeled ad-hoc in
      the llvm/z3 stable variants, not through this type).
    - [Packaging]: wrong files in an opam/pip/apt payload
      (SSOT §5 roadmap; no code yet). *)
type origin =
  | Mutation of mutation
  | Version_mismatch    (** reserved; not wired *)
  | Packaging           (** reserved; not wired *)

(* ---------- scenario ---------- *)

(** Unified scenario — good scenarios have [origin = None];
    bad scenarios attach an [origin] naming the cause of
    badness.

    [related_artifacts] is not stored — it derives from
    [actions] via [related_artifacts_of_actions] below. See
    §6.5 (SSOT) for the per-action consumes/produces table. *)
type scenario = {
  id : string;                       (** "Sc.N" or "Bs.N" *)
  name : string;
  description : string;
  actions : Canary_basic.action list;
  origin : origin option;
  belongs_to : string list;          (** which Sc.N(s) this scenario
                                         relates to. For a Good scenario:
                                         its own id. For a Bad scenario:
                                         the Good scenario whose
                                         artifacts are involved
                                         (mutated_at, for Mutation origin;
                                         the paired-at Sc.N for
                                         Version_mismatch). *)
}

(* ---------- contract bindings ---------- *)

(** Where a contract's failure observation surfaces at runtime —
    which action-graph action's step will fail when this contract is
    violated. A contract may fire at multiple sites (c6 fires at
    both [Build_binding] and [Probe_binding], for example).

    Placeholder-friendly: [At_build_app] / [At_probe_app] carry a
    language directly rather than a full [app_info] record; the
    binding lookup projects a concrete action down to its
    lang-equivalent site. *)
type firing_site =
  | At_build_binding of Canary_lang.lang
  | At_probe_binding of Canary_lang.lang
  | At_build_app of Canary_lang.lang
  | At_probe_app of Canary_lang.lang


(** Project a concrete [Canary_basic.action] down to a [firing_site]
    so a contract binding can be matched by lookup. Rules with no
    firing-site equivalent (Build_lib, Fetch, etc.) return [None] —
    contracts never fire at those. *)
let firing_site_of_action : Canary_basic.action -> firing_site option =
  function
  | Canary_basic.Build_binding l -> Some (At_build_binding l)
  | Canary_basic.Probe_binding l -> Some (At_probe_binding l)
  | Canary_basic.Build_app a     -> Some (At_build_app a.lang)
  | Canary_basic.Probe_app a     -> Some (At_probe_app a.lang)
  | _ -> None

(** How the expected observation for a (contract, lang, site) is
    sourced. Two live families + a placeholder. Both live variants
    carry an optional [version_info] (Phase C 2026-07-21) so the
    lowering can thread human-readable provider/consumer version
    context through to the emitted [step_expectation]:

    - [From_artifact { inputs; version_info }] — the contract's
      [predict] closure (in {!Canary_compat_run}) reads the cached
      inspect JSONs listed in [inputs] and emits predicted failure
      substrings. Static source, dynamic check (grep of probe.log /
      build.log).
    - [From_behavior_grep { contains_any; version_info }] — no
      artifact prediction; assert the log contains one of
      [contains_any]. Purely behavioural (c3 [api_repack], c7
      [stub_orphan] fire this way — the probe emits [FAIL …] on
      mismatch).
    - [Placeholder { reason }] — the binding is *declared* but not
      *wired*: the shape commits, the content is TBD. Emits
      [Expect_success] at runtime; a startup validator can catch
      attempts to declare a scenario that would rely on it. *)
type expectation_source =
  | From_artifact of {
      inputs : Canary_compat.inspect_input list;
      version_info : Canary_step_model.version_info option;
    }
  | From_behavior_grep of {
      contains_any : string list;
      version_info : Canary_step_model.version_info option;
    }
  | Placeholder of { reason : string }

(** Runtime predicate on [loc] deciding whether a firing applies
    (Phase B 2026-07-21). The lowering evaluates the filter after
    matching by [firing_site]; a firing whose filter rejects the
    step's [loc] is skipped. Enables per-store expectations without
    duplicating whole bindings — e.g. llvm has c2 fire as
    [Expect_success] under pip-python (llvmlite bundles its own
    libLLVM) but [Expect_compat_failure] under opam-ocaml.

    - [Any] — passes always; the default tiny uses.
    - [At_pm_lang lang] — passes iff [loc] is [Pm (Lang_pm { lang })]
      for the given lang. For "opam-installed OCaml binding" etc.
    - [Not_pm_lang lang] — passes iff [loc] is NOT that lang's PM.
      For "everywhere except pip-python".
    - [Only_if p] — escape hatch; caller supplies a predicate. *)
type loc_filter =
  | Any
  | At_pm_lang of Canary_lang.lang
  | Not_pm_lang of Canary_lang.lang
  | Only_if of (Canary_store.location option -> bool)

let loc_filter_passes (f : loc_filter)
    (loc : Canary_store.location option) : bool
  =
  let open Base in
  let is_pm_lang target = function
    | Some (Canary_store.Pm (Canary_store.Lang_pm { lang; _ })) ->
        Poly.equal lang target
    | _ -> false
  in
  match f with
  | Any -> true
  | At_pm_lang l -> is_pm_lang l loc
  | Not_pm_lang l -> not (is_pm_lang l loc)
  | Only_if p -> p loc

(** One firing: where a contract's failure observation surfaces
    ([site]), which locations it applies to ([loc_filter]), and how
    the observation is sourced ([source]).

    A [contract_binding] may carry multiple firings for the same
    site with different [loc_filter]s — the lowering picks the
    first firing whose filter matches the runtime [loc]. Design
    order in a binding matters: put more specific filters (e.g.
    [At_pm_lang Python] for llvm's pip-python override) before
    the catch-all ([Any]).

    Record shape (not a 3-tuple) so future fields — say a per-firing
    enable flag or a per-firing note — can be added without a
    breaking change. *)
type firing = {
  site : firing_site;
  loc_filter : loc_filter;
  source : expectation_source;
}

(** A per-(contract, lang) declaration of where and how the contract's
    failure observation shows up. [firings] is a list because one
    contract can fire at multiple sites; empty means "this contract is
    silent for this language". *)
type contract_binding = {
  contract : Canary_compat.contract_id;
  lang     : Canary_lang.lang;
  firings  : firing list;
}

(** Look up whether a (contract, lang) binding is fully wired
    (at least one non-Placeholder firing site) in the given
    bindings table. Used by synthesis guards to decide whether
    a recipe for a given (contract, lang) will actually detect
    a mutation, rather than silently emit Expect_success. *)
let binding_has_live_firing
    (bindings : contract_binding list)
    (contract : Canary_compat.contract_id)
    (lang : Canary_lang.lang)
  : bool
  =
  let open Base in
  match
    List.find bindings ~f:(fun b ->
      Poly.equal b.contract contract && Poly.equal b.lang lang)
  with
  | None -> false
  | Some b ->
    List.exists b.firings ~f:(fun f ->
      match f.source with
      | From_artifact _ | From_behavior_grep _ -> true
      | Placeholder _ -> false)

(* [lower_expectation] — the ORACLE lowering (~violates/~has_manifest, emitted
   must-fail [Expect_compat_failure]) — was RETIRED here 2026-08-05 (A7): its
   last consumer, tiny1, now composes the same behavior as a factory-local
   COMBINATOR over {!lower_expectation_agnostic} (restrict the bindings data
   to the recipe's violated contracts, gate on manifestation, strengthen
   Derived → must-fail) — see [Canary_tiny_scenario.expectation_of_entry].
   The framework keeps ONE lowering: how a check DERIVES from declared
   bindings at a firing site; oracle-ness is caller policy, not machinery. *)

(** {b The expectation lowering} (P2b, 2026-08-02; THE framework lowering
    since A7 phase 3): derives the expectation from the project's [bindings]
    table + the (action, loc) ALONE, by UNIONing every contract's
    [From_artifact] inputs at the matching firing site and letting the compat
    runner ([predicted_by_contract_v2]) DISCOVER which contract actually
    breaks by inspecting the materialized artifacts. Nobody tells it which
    contract fires — the same way a real project works (status §1a P2b).

    Each contract's [predict] reads only its own input kinds, so unioning is
    safe: c1 fires iff a symbol vanished, c2 iff the mli lost a name, etc.

    {b Known limit — the empty-prediction question.} At a probe site the good
    build ALSO matches these firings, so this emits [Expect_compat_failure]
    with an *empty* runtime prediction for a clean artifact. Whether that
    verifies as success (the [has_manifest = false] role in the oracle path)
    is the semantics to settle before wiring this into the run; proven for c1
    at the *derivation* level first (see [scenario.lower_expectation_agnostic_c1]
    test). Generalising past statically-inspectable contracts (c3 behaviour,
    c6 grep-type) is the follow-up. *)
let lower_expectation_agnostic
    ~(bindings : contract_binding list)
    ~(langs : Canary_lang.lang list)
  : Canary_basic.action -> Canary_store.location option ->
    Canary_step_model.step_expectation
  =
  let open Base in
  fun action loc ->
    match firing_site_of_action action with
    | None -> Canary_step_model.Expect_success
    | Some site ->
      (* every firing (ANY contract) at this site whose loc filter passes *)
      let sources =
        List.concat_map bindings ~f:(fun b ->
          if not (List.mem langs b.lang ~equal:Poly.equal) then []
          else
            List.filter_map b.firings ~f:(fun f ->
              if Poly.equal f.site site && loc_filter_passes f.loc_filter loc
              then Some f.source else None))
      in
      let artifact_inputs =
        List.concat_map sources ~f:(function
          | From_artifact { inputs; _ } -> inputs | _ -> [])
      in
      let first_version_info =
        List.find_map sources ~f:(function
          | From_artifact { version_info; _ } -> version_info | _ -> None)
      in
      if not (List.is_empty artifact_inputs) then
        Canary_step_model.Expect_compat_derived
          { inputs = artifact_inputs; version_info = first_version_info }
      else
        (match
           List.find_map sources ~f:(function
             | From_behavior_grep { contains_any; version_info } ->
               Some (contains_any, version_info)
             | _ -> None)
         with
         | Some (contains_any, version_info) ->
           Canary_step_model.Expect_failure { contains_any; version_info }
         | None -> Canary_step_model.Expect_success)

(* ---------- Good scenarios (Sc.1..Sc.6) ---------- *)

(** Good scenarios from SSOT §4 — project-agnostic patterns.
    Each Sc.N describes a stage; language qualifiers appear
    as suffixes (Sc.N.<Lang>) for language-specific stages.
    Sc.1 is shared across languages (the native lib itself is
    language-agnostic).

    Concrete projects (tiny, z3, ...) instantiate the pattern
    with their own artifacts and probes. [origin = None] on
    all (good = no badness, by definition).

    {b Mechanism dimension — hardcoded to SCAB for now.} Binding
    mechanisms (SCAB = static C API binding via cext/cstubs;
    DFFI = dynamic FFI via ctypes; ...) currently collapse under
    a single SCAB assumption. Practical consequences:

    - Sc.1 stays shared even if we promote mechanism to an
      explicit axis later — the native lib is mechanism-agnostic.
    - OCaml scenarios (Sc.2.OCaml..Sc.6.OCaml) are all SCAB
      (tiny uses cstubs, no DFFI on the OCaml side).
    - Python scenarios (Sc.2.Python, Sc.4.Python) are the SCAB
      case (cext). ctypes = DFFI is not modeled today; when we
      add it, Sc.4.Python.cext (SCAB) and Sc.4.Python.ctypes
      (DFFI) become distinct, with an explicit mechanism →
      {stage × language} mapping replacing today's hardcoded
      list.

    Absence semantics (per user, 2026-07-07): a scenario is
    "shared" only when it's *exactly duplicated* across
    languages (Sc.1 case). Scenarios that don't exist for a
    language because the language has no such step (e.g. no
    Sc.3.Python — .py IS the app) are simply absent, not
    "skipped". Same for Sc.5/Sc.6 on the Python side — no
    Python helper in tiny, so those combinations don't
    exist. *)
let good_scenarios : scenario list =
  let open Canary_basic in
  let open Canary_lang in
  [
    (* Shared upstream *)
    { id = "Sc.1"; name = "build_native_lib";
      description = "Upstream — build the native library from source. \
                     Shared across languages (under the static C API \
                     binding assumption).";
      actions = [ Configure; Scan_sources; Build_lib; Install_lib ];
      origin = None;
      belongs_to = [ "Sc.1" ] };

    (* OCaml side *)
    { id = "Sc.2.OCaml"; name = "build_binding";
      description = "Build the OCaml binding against the native lib.";
      actions = [ Build_binding OCaml ];
      origin = None;
      belongs_to = [ "Sc.2.OCaml" ] };
    { id = "Sc.3.OCaml"; name = "build_app_with_binding";
      description = "Build an OCaml app that links against the OCaml \
                     binding.";
      actions = [ Build_app { lang = OCaml } ];
      origin = None;
      belongs_to = [ "Sc.3.OCaml" ] };
    { id = "Sc.4.OCaml"; name = "run_app_with_binding";
      description = "Run the OCaml app; loader resolves the native lib \
                     at load time.";
      actions = [ Probe_app { lang = OCaml } ];
      origin = None;
      belongs_to = [ "Sc.4.OCaml" ] };
    { id = "Sc.5.OCaml"; name = "build_app_helper";
      description = "Build the app via an intermediate helper library \
                     that wraps the OCaml binding.";
      actions = [ Build_app { lang = OCaml } ];
      origin = None;
      belongs_to = [ "Sc.5.OCaml" ] };
    { id = "Sc.6.OCaml"; name = "run_app_helper";
      description = "Run the app-via-helper chain.";
      actions = [ Probe_app { lang = OCaml } ];
      origin = None;
      belongs_to = [ "Sc.6.OCaml" ] };

    (* Python side — no Sc.3.Python (.py IS the app, no build step);
       no Sc.5/Sc.6 (no Python helper in tiny). *)
    { id = "Sc.2.Python"; name = "build_binding";
      description = "Build the Python binding (cext) against the \
                     native lib.";
      actions = [ Build_binding Python ];
      origin = None;
      belongs_to = [ "Sc.2.Python" ] };
    { id = "Sc.4.Python"; name = "run_app_with_binding";
      description = "Run the Python cext probe under SCAB (import \
                     the binding; loader resolves the native lib). \
                     ctypes probe would be a same-shape run under \
                     DFFI, not modeled today.";
      actions = [ Probe_app { lang = Python } ];
      origin = None;
      belongs_to = [ "Sc.4.Python" ] };
  ]

(* ---------- related_artifacts derivation (§7.9) ---------- *)

(** Derive a scenario's [related_artifacts] from its [actions]
    list. Union in first-appearance order (no dedup rearrangement)
    — order follows the "prerequisite first, target next"
    convention from {!Canary_action.artifacts_of_action}. *)
let related_artifacts_of_actions (actions : Canary_basic.action list)
  : Canary_basic.artifact_kind list =
  let open Base in
  List.concat_map actions ~f:Canary_action.artifacts_of_action
  |> List.fold ~init:[] ~f:(fun acc a ->
      if List.mem acc a ~equal:Poly.equal then acc else acc @ [ a ])

(** Getter: what artifacts does this scenario touch? Sole
    source of truth after §7.9 landed the type change (2026-07-10);
    the field was removed. Used by display code
    (A1/A2/A3 indexing) and by [validate_mutation_target]. *)
let related_artifacts (s : scenario) : Canary_basic.artifact_kind list =
  related_artifacts_of_actions s.actions

(* ---------- validators ---------- *)

(** Validate a Sc.N string against the [good_scenarios] catalogue.
    Returns [s] unchanged if valid; raises [Failure] with a
    helpful message otherwise. Used to catch typos in
    [manifest = Definite "Sc.4"] etc. at start-up.

    Closes drift risk #1 from the status report. *)
let sc_id_of_string (s : string) : string =
  match Base.List.find good_scenarios
          ~f:(fun g -> Base.String.equal g.id s) with
  | Some _ -> s
  | None ->
    let known = Base.List.map good_scenarios ~f:(fun g -> g.id) in
    Stdlib.failwith
      (Printf.sprintf "unknown Sc.N: %S. Known: %s"
         s (Base.String.concat ~sep:", " known))

(** Invariant check: if a scenario has a Mutation origin,
    its [target] must be in the scenario's derived
    [related_artifacts] (via the actions list). Raises
    [Failure] on violation. Closes drift risk #3 from the
    status report. *)
let validate_mutation_target (s : scenario) : unit =
  match s.origin with
  | None | Some (Version_mismatch | Packaging) -> ()
  | Some (Mutation p) ->
    if not (Base.List.mem (related_artifacts s) p.target
              ~equal:Base.Poly.equal) then
      Stdlib.failwith
        (Printf.sprintf
           "scenario %s (%s): mutation.target not in \
            related_artifacts" s.id s.name)

(** Validate that all Sc.N strings in a scenario's manifest are
    known. Combined with [validate_mutation_target], gives a
    full structural check per scenario. *)
let validate_manifest_sc_ids (s : scenario) : unit =
  match s.origin with
  | None | Some (Version_mismatch | Packaging) -> ()
  | Some (Mutation p) ->
    match p.manifest with
    | Definite sc -> let _ = sc_id_of_string sc in ()
    | Possible xs ->
      Base.List.iter xs ~f:(fun sc ->
        let _ = sc_id_of_string sc in ())
    | Unknown_gap -> ()

(** Validate that all Sc.N strings in [belongs_to] are known. *)
let validate_belongs_to (s : scenario) : unit =
  Base.List.iter s.belongs_to ~f:(fun sc ->
    let _ = sc_id_of_string sc in ())

(** Full structural check on a scenario. Raises on any
    invariant violation. [related_artifacts] is now derived
    from [actions], so no hand-vs-derived check is needed
    (used to be [validate_related_artifacts]; retired
    2026-07-10 with the field deletion). *)
let validate_scenario (s : scenario) : unit =
  validate_mutation_target s;
  validate_manifest_sc_ids s;
  validate_belongs_to s

(* ---------- derivation (§9.3 backlog: derive_entries) ---------- *)

(** Which mutation kinds are applicable to a given artifact
    kind. Encodes the Q4 constraint from the user's earlier note:
    "mutation_kind depends on related_artifact."

    - [Source] admits both [On_artifact Source] (source patch)
      and [On_behavior] (semantic change without surface diff).
    - [Headers], [Lib], [Binding _], [App] admit only
      [On_artifact <self>].

    Extend when the model grows. *)
let applicable_mutations (a : Canary_basic.artifact_kind)
    : mutation_kind list =
  match a with
  | Source -> [ On_artifact Source; On_behavior ]
  | Headers -> [ On_artifact Headers ]
  | Lib -> [ On_artifact Lib ]
  | Binding _ | Binding_source _ -> [ On_artifact a ]
  | App -> [ On_artifact App ]

(** Format a mutation_kind for use in a derived scenario id. *)
let string_of_mutation_kind = function
  | On_artifact a -> Canary_basic.string_of_artifact_kind a
  | On_behavior -> "behavior"

(** A derived cell — one (Good scenario × artifact × kind) tuple
    turned into a candidate scenario. All derived scenarios carry
    [manifest = Unknown_gap] and [detector = Detector_gap] since
    the derivation is structural, not backed by any specific
    tool observation. If a hardcoded Bs entry lands in this cell,
    that's where the concrete detector info lives. *)
let derive_scenario (good : scenario)
    (target : Canary_basic.artifact_kind)
    (kind : mutation_kind) : scenario =
  let id =
    Printf.sprintf "Dv.%s.%s.%s"
      good.id
      (Canary_basic.string_of_artifact_kind target)
      (string_of_mutation_kind kind)
  in
  let kind_str = string_of_mutation_kind kind in
  (* Use good.id (not good.name) — good.name isn't unique across
     Sc.N × language (Sc.2.OCaml.name == Sc.2.Python.name ==
     "build_binding"). Using good.id preserves lang suffix and
     keeps derived scenario names collision-free. *)
  let name = Printf.sprintf "mutate_%s_at_%s" kind_str good.id in
  let description =
    Printf.sprintf
      "Derived candidate: mutate %s of %s (%s) — abstract cell, \
       no concrete detector info until a hand-listed Bs fills it."
      (Canary_basic.string_of_artifact_kind target)
      good.id kind_str
  in
  { id; name; description;
    actions = good.actions;
    origin = Some (Mutation { target; kind;
                          manifest = Unknown_gap;
                          detector = Detector_gap });
    belongs_to = [ good.id ];
  }

(** Enumerate all valid (Good × artifact × applicable-kind)
    tuples, producing one derived scenario per cell. Input is
    the list of good scenarios to iterate over (typically a
    project's tiny_good_scenarios or the abstract
    [good_scenarios]).

    Diffing this against a project's hand-listed bad scenarios
    surfaces (a) gaps — derived cells with no hand-listed
    coverage; (b) extras — hand-listed scenarios that don't fit
    any derived cell (should be rare if [applicable_mutations]
    is complete). *)
let derive_scenarios (goods : scenario list) : scenario list =
  Base.List.concat_map goods ~f:(fun good ->
    Base.List.concat_map (related_artifacts good) ~f:(fun a ->
      Base.List.map (applicable_mutations a) ~f:(fun k ->
        derive_scenario good a k)))

(** Language set a scenario's contracts fire at, derived from
    [scenario.belongs_to] (the Good scenarios the entry
    attributes to). Suffix convention:
    - [Sc.N] (no suffix) = shared → both OCaml and Python
    - [Sc.N.OCaml] → OCaml only
    - [Sc.N.Python] → Python only

    Union over multiple [belongs_to] entries. General across
    projects — moved out of the tiny factory 2026-07-08. *)
let langs_of_scenario (scenario : scenario) : Canary_lang.lang list =
  let open Base in
  let lang_of_id id =
    if String.is_suffix id ~suffix:".OCaml" then [ Canary_lang.OCaml ]
    else if String.is_suffix id ~suffix:".Python" then [ Canary_lang.Python ]
    else [ Canary_lang.OCaml; Canary_lang.Python ]
  in
  scenario.belongs_to
  |> List.concat_map ~f:lang_of_id
  |> List.dedup_and_sort ~compare:Poly.compare

(** Does the scenario's mutation produce a probe-observable
    manifestation? [Unknown_gap] means no; good scenarios
    ([origin = None]) also count as no.

    A scenario without probe manifestation would misfire under
    derivation (canary would expect a FAIL that never comes) —
    the factory falls through to [Expect_success] uniformly.
    General across projects — moved out of the tiny factory
    2026-07-08. *)
let has_probe_manifestation (scenario : scenario) : bool =
  match scenario.origin with
  | None -> false
  | Some (Mutation { manifest = Unknown_gap; _ }) -> false
  | Some (Mutation _) -> true
  | Some (Version_mismatch | Packaging) -> true

