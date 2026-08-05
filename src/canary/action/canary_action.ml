(** [Canary_action] — the action-graph schema.

    The {i first} of the two main action-layer files. Defines what an
    action is (the [action] vocabulary lives in {!Canary_basic}) and how
    artifact nodes chain together into the universal graph. The
    {i runner} half lives in {!Canary_runner}.

    Split from [Canary] on 2026-06-01 (Phase 5); renamed from
    [Canary_action_graph] to [Canary_action] shortly after as part of
    the action/runner naming pass. Holds:
    - [mk_node], [node_tag]: artifact-node constructor and stable string
      tag (used for dedup + diagram labels).
    - [type action_graph]: the action list + materialised pools per
      [artifact_kind].
    - [pool_get], [store_actions]: standard action sets and pool access.
    - [make_action_graph]: instantiate an action_graph by applying every
      action to a starting source.
    - [nodes_of_action_graph]: flatten the pools to a deduped node list.
    - [type node_status]: per-step verdict for diagram rendering. *)

open Base
open Canary_store
open Canary_basic

(** Build-graph node: an artifact plus how it was produced ([built_from]) and what
    it needs at runtime ([runtime_dep]). Relocated from base (M1.0, 2026-08-04):
    base never used it — it is action-layer vocabulary, and lives here beside
    [make_action_graph] so it can (M1) merge with the enumerate-layer identity
    types (`artifact_id` / `build_id`). The graph is materialised by
    {!Canary.run_graph}. *)
type artifact_node = {
  a_kind : artifact_kind;
  ext : Canary_enumerate.artifact_ext;  (* M1: a_kind × ext = the precise id *)
  version : Canary_enumerate.build_id;  (* M1: typed version; a_name keeps the display suffix *)
  provision : Canary_store.provision;   (* M1: per-edge provider (Built/Fetched/…) *)
  a_name : string;
  origin : location;
  a_location : location;
  built_from : artifact_node option;
  runtime_dep : artifact_node option;
}

(* M1: [~version] + [~provision] required (populated from the producing action —
   Build_* ⇒ Built, Fetch ⇒ Fetched); [~ext] defaults to none (make_action_graph
   is coarse-kind). a_kind/a_name kept as display so node_tag stays byte-identical. *)
let mk_node a_kind a_name ~origin ~location
    ?(ext = Canary_enumerate.Ext_none) ~version ~provision ?built_from
    ?runtime_dep () : artifact_node =
  { a_kind; ext; version; provision; a_name; origin; a_location = location;
    built_from; runtime_dep }

let rec node_tag (n : artifact_node) =
  let name = n.a_name in
  let base =
    [%string
      "%{string_of_artifact_kind n.a_kind}(%{name})@%{string_of_location \
       n.a_location}"]
  in
  let with_built =
    match n.built_from with
    | None -> base
    | Some dep -> [%string "%{base}(%{node_tag dep})"]
  in
  match n.runtime_dep with
  | None -> with_built
  | Some rt -> [%string "%{with_built}[rt=%{node_tag rt}]"]

type action_graph = {
  actions : action list;
  pools : (artifact_kind * artifact_node list) list;
}

let pool_get ar kind =
  List.Assoc.find ar.pools ~equal:Poly.equal kind |> Option.value ~default:[]

(* Standard action sets.
   ~langs: binding languages this project supports (external loop).
   Each lang gets its own Build_binding / Fetch / Publish / Probe actions. *)
let store_actions ~langs =
  [ Fetch Source; Configure; Scan_sources; Build_headers; Fetch Headers; Build_lib; Install_lib; Fetch Lib ]
  @ List.concat_map langs ~f:(fun lang ->
      [ Build_binding lang; Fetch (Binding lang);
        Publish (Binding lang); Probe_binding lang;
        Build_app { lang }; Probe_app { lang } ])
  @ [ Fetch App; Publish Lib; Publish App; Probe_lib ]

(** The per-runtime-edge resolution mode (dynamic_enumeration.md), shared by the
    FORWARD construction ([make_action_graph]'s [Build_app]) and the lift
    ([close_deps]). [Lockstep] = run-lib is the build-lib (the matched chain);
    [Independent] = run-lib ranges over every lib ⇒ the deploy-mismatch cartesian
    (what `paths` wants — the default); [Ambient s] = an external lib (libc). *)
type dep_mode = Lockstep | Independent | Ambient of string

let make_action_graph ~actions ~versions ~name ~source ?(app_mode = Independent)
    () =
  let vs = channel_suffix in
  let get pools kind =
    List.Assoc.find pools ~equal:Poly.equal kind |> Option.value ~default:[]
  in
  let add pools kind nodes =
    let existing = get pools kind in
    List.Assoc.add pools ~equal:Poly.equal kind (existing @ nodes)
  in
  let pools =
    List.fold actions ~init:[] ~f:(fun pools action ->
        match action with
        | Build_lib ->
            let sources = get pools Source in
            let nodes =
              List.map versions ~f:(fun v ->
                  (* source-primary: lib@v is built FROM source@v (same version) —
                     the same [get pools _] + [~built_from] pattern Build_binding
                     uses for lib. Was missing (source-as-implicit-root); degrades
                     to that when no Source is in the graph. *)
                  let built_from =
                    List.find sources ~f:(fun s ->
                        Canary_enumerate.equal_build_id s.version
                          (Canary_enumerate.good v))
                  in
                  mk_node Lib
                    (name ^ vs v)
                    ~origin:Build_tree ~location:Build_tree
                    ~version:(Canary_enumerate.good v) ~provision:Built
                    ?built_from ())
            in
            add pools Lib nodes
        | Fetch kind ->
            let nodes =
              List.map versions ~f:(fun v ->
                  mk_node kind (name ^ vs v) ~origin:source ~location:source
                    ~version:(Canary_enumerate.good v) ~provision:Fetched ())
            in
            add pools kind nodes
        | Build_binding lang ->
            let libs = get pools Lib in
            (* SOURCE-PRIMARY: binding@v is built against lib@v (its OWN version),
               not every lib — a binding built against a mismatched lib is nonsense
               at BUILD time. A binding@v still has a build-variant per lib@v that
               EXISTS (built lib@v and/or fetched lib@v — paths 7 vs 8); the
               cross-version mismatch lives ONLY on the App's runtime edge. *)
            let nodes =
              List.concat_map versions ~f:(fun v ->
                  List.filter_map libs ~f:(fun lib ->
                      if
                        Canary_enumerate.equal_build_id lib.version
                          (Canary_enumerate.good v)
                      then
                        Some
                          (mk_node (Binding lang)
                             (name ^ vs v)
                             ~origin:Build_tree ~location:Build_tree
                             ~built_from:lib ~version:(Canary_enumerate.good v)
                             ~provision:Built ())
                      else None))
            in
            add pools (Binding lang) nodes
        | Build_app { lang } ->
            let bindings = get pools (Binding lang) in
            let libs = get pools Lib in
            (* the runtime lib(s) an App links against, per [app_mode]:
               - [Independent] (default, `paths`): EVERY lib → the deploy-mismatch
                 cartesian (all patterns).
               - [Lockstep] (engine): the binding's build-lib (matched chain), or —
                 for a fetched binding with no build-lib — the same-VERSION lib. *)
            let runtime_libs (binding : artifact_node) =
              match app_mode with
              | Independent | Ambient _ -> libs
              | Lockstep -> (
                  match binding.built_from with
                  | Some bl -> [ bl ]
                  | None ->
                      List.filter libs ~f:(fun l ->
                          Canary_enumerate.equal_build_id l.version
                            binding.version))
            in
            let nodes =
              List.concat_map bindings ~f:(fun binding ->
                  List.map (runtime_libs binding) ~f:(fun runtime_lib ->
                      mk_node App name ~origin:Build_tree ~location:Build_tree
                        ~built_from:binding ~runtime_dep:runtime_lib
                        ~version:binding.version ~provision:Built ()))
            in
            add pools App nodes
        | Build_headers ->
            let nodes =
              List.map versions ~f:(fun v ->
                  mk_node Headers (name ^ vs v)
                    ~origin:Build_tree ~location:Build_tree
                    ~version:(Canary_enumerate.good v) ~provision:Built ())
            in
            add pools Headers nodes
        (* Scan_sources doesn't produce new artifact nodes — it just
           emits inspect JSONs into the runner's output dirs.
           Configure / Install_lib / Publish / Probe likewise. *)
        | Configure | Scan_sources | Install_lib | Publish _
        | Probe_lib | Probe_binding _ | Probe_app _ -> pools)
  in
  { actions; pools }

let nodes_of_action_graph (ar : action_graph) =
  List.concat_map ar.pools ~f:snd
  |> List.dedup_and_sort ~compare:(fun a b ->
      String.compare (node_tag a) (node_tag b))

(** Project-aware coverage mark on the UNIVERSAL graph (the `canary scenarios`
    idiom, applied to nodes): a node is APPLICABLE to a project iff the project
    declares its (kind, provision) AND its build/runtime deps are applicable —
    the mark cascades along the edges. Undeclared kinds (App/Headers — no
    provision axis) are decided by their endpoints alone. Keeps
    [make_action_graph] universal; the project just filters after.
    [provisions_of_kind] = the project's [ps_provisions_of] keyed by kind
    ([[]] = kind not declared). *)
let rec node_applicable
    ~(provisions_of_kind : artifact_kind -> Canary_store.provision list)
    (n : artifact_node) : bool =
  (match provisions_of_kind n.a_kind with
   | [] -> true (* undeclared kind: endpoint-decided *)
   | provs -> List.mem provs n.provision ~equal:Canary_store.equal_provision)
  && (match n.built_from with
      | Some b -> node_applicable ~provisions_of_kind b
      | None -> true)
  && (match n.runtime_dep with
      | Some r -> node_applicable ~provisions_of_kind r
      | None -> true)

(** Consumes-and-produces enumeration for a single action.
    Order convention: prerequisite first, target next; runtime
    deps trail direct arguments. Companion to {!store_actions}
    (which enumerates {i which} actions run for a project) —
    together they form the "action catalogue" that SSOT §6.5
    documents. See §7.9 for the derivation this feeds.

    Colocated with [store_actions] on 2026-07-22 (was in
    [Canary_scenario]) so both views of the catalogue live in one
    place; adding a new action variant now touches one file.

    - [Configure] / [Scan_sources] — [Source].
    - [Build_headers] — [Source; Headers].
    - [Build_lib] — [Source; Lib].
    - [Install_lib] — [Lib].
    - [Build_binding L] — [Lib; Binding L].
    - [Build_app { lang = L }] — [Binding L; App].
    - [Probe_lib] — [Lib].
    - [Probe_binding L] — [Binding L; Lib] (runtime dep last).
    - [Probe_app { lang = L }] — [Binding L; Lib; App]
      (Binding to load, Lib runtime dep, App entry).
    - [Fetch k] / [Publish k] — [k]. *)
let artifacts_of_action (a : action) : artifact_kind list =
  match a with
  | Configure -> [ Source ]
  | Scan_sources -> [ Source ]
  | Build_headers -> [ Source; Headers ]
  | Build_lib -> [ Source; Lib ]
  | Install_lib -> [ Lib ]
  | Build_binding l -> [ Lib; Binding l ]
  | Build_app { lang } -> [ Binding lang; App ]
  | Probe_lib -> [ Lib ]
  | Probe_binding l -> [ Binding l; Lib ]
  | Probe_app { lang } -> [ Binding lang; Lib; App ]
  | Fetch k -> [ k ]
  | Publish k -> [ k ]

(** The explicit {b consumes}/{b produces} split of the action
    catalogue (project-definition redesign, 2026-07-22 — see
    [doc/canary/design/ssot.md] §6.1). The flat
    {!artifacts_of_action} above conflates the two by ordering
    convention and is kept as-is (its exact output feeds
    [related_artifacts], mutation-target validation, and the
    diagrams). Detection wants the distinction: at a probe step it
    inspects what the action {b consumes} (the consumer surface +
    its runtime provider) and compares them via the c1..c8
    contracts.

    Invariant detection relies on: probes produce nothing, so for
    every [Probe_*] action [consumes_of_action = artifacts_of_action].
    [Build_app] is the one place the flat view diverges — it omits
    the [Lib] runtime dep that [consumes_of_action] and
    [Probe_app] both list. *)
let consumes_of_action (a : action) : artifact_kind list =
  match a with
  | Configure -> [ Source ]
  | Scan_sources -> [ Source ]
  | Build_headers -> [ Source ]
  | Build_lib -> [ Source ]
  | Install_lib -> [ Lib ]
  | Build_binding _ -> [ Lib ]
  | Build_app { lang } -> [ Binding lang; Lib ]
  | Probe_lib -> [ Lib ]
  | Probe_binding l -> [ Binding l; Lib ]
  | Probe_app { lang } -> [ Binding lang; Lib; App ]
  | Fetch _ -> []
  | Publish k -> [ k ]

let produces_of_action (a : action) : artifact_kind list =
  match a with
  | Configure -> []
  | Scan_sources -> []
  | Build_headers -> [ Headers ]
  | Build_lib -> [ Lib ]
  | Install_lib -> [ Lib ]   (* relocates Lib into the Staged store *)
  | Build_binding l -> [ Binding l ]
  | Build_app _ -> [ App ]
  | Probe_lib -> []
  | Probe_binding _ -> []
  | Probe_app _ -> []
  | Fetch k -> [ k ]
  | Publish k -> [ k ]   (* relocates k into a Pm store *)

(* M2: lift a flat [Canary_enumerate.assignment] to the artifact_node graph — the
   [built_from] edges come from the SEAM ([built_from_of_assignment]) via the
   action catalogue ([consumes_of_action], §6.5), reused, not a new edge
   vocabulary. Chain scope (source→lib→binding, one version); [runtime_dep] (an
   app's run-lib) is deferred. The flat→node lift the graph merge builds on; the
   run still consumes assignments (unchanged). *)
let node_of_assignment (a : Canary_enumerate.assignment) : artifact_node list =
  let module EN = Canary_enumerate in
  let built_from_kinds (k : artifact_kind) : artifact_kind list =
    match k with
    | Lib -> consumes_of_action Build_lib
    | Binding l -> consumes_of_action (Build_binding l)
    | Headers -> consumes_of_action Build_headers
    | _ -> []
  in
  let rec build (id : EN.artifact_id) : artifact_node =
    let built_from =
      match EN.built_from_of_assignment ~built_from_kinds a id with
      | dep :: _ -> Some (build dep)   (* seam returns deps present in [a] *)
      | [] -> None
    in
    mk_node (EN.kind_of id) (EN.string_of_id id) ~origin:Build_tree
      ~location:Build_tree ~ext:(EN.ext_of id) ~version:(EN.version_of a id)
      ~provision:(EN.provision_of a id) ?built_from ()
  in
  List.map a ~f:(fun (id, _) -> build id)

(* [dep_mode] is defined before [make_action_graph] (both consume it: the forward
   construction and [close_deps] share one runtime-edge resolution knob). *)

(** Stage 3 — lift a flat assignment to REALISED node graph(s), resolving each
    App's [runtime_dep] by [mode_of] its kind. Build edges reuse
    [node_of_assignment] (the seam); the runtime edge (the flat view's one
    documented divergence — [consumes_of_action Build_app] lists [Lib] but
    [node_of_assignment] drops it) is added here. [Independent] BRANCHES — one
    graph per run-version in [run_versions_of Lib]; combined with the
    build-version axis already enumerated into [a], the full build×run cartesian
    appears (the mismatch). An assignment with NO App has no runtime edge to
    resolve ⇒ [[node_of_assignment a]] — so flat projects (sqlite/tiny) are
    byte-identical. v1: App→Lib edge only; a finer per-app-wiring key is later. *)
let close_deps
    ~(run_versions_of : artifact_kind -> Canary_basic.channel list)
    ~(mode_of : artifact_kind -> dep_mode)
    (a : Canary_enumerate.assignment) : artifact_node list list =
  let module EN = Canary_enumerate in
  let base = node_of_assignment a in
  let is_app (n : artifact_node) = match n.a_kind with App -> true | _ -> false in
  let apps = List.filter base ~f:is_app in
  let non_apps = List.filter base ~f:(fun n -> not (is_app n)) in
  let lib_node = List.find base ~f:(fun n -> Poly.equal n.a_kind Lib) in
  let binding_node =
    List.find base ~f:(fun n ->
        match n.a_kind with Binding _ -> true | _ -> false)
  in
  (* faithful app edges: built_from = the binding (generates); runtime = Lib (per
     mode). node_of_assignment leaves App built_from = None (built_from_kinds has
     no App case), so set it here. *)
  let resolve (app : artifact_node) : artifact_node list =
    let app = { app with built_from = binding_node } in
    match mode_of app.a_kind with
    | Lockstep -> [ { app with runtime_dep = lib_node } ]
    | Independent -> (
        match lib_node with
        | None -> [ app ]
        | Some lib ->
            List.map (run_versions_of Lib) ~f:(fun vr ->
                { app with runtime_dep = Some { lib with version = EN.good vr } }))
    | Ambient s ->
        let ext =
          mk_node Lib s ~origin:Build_tree ~location:Build_tree
            ~version:(EN.good Canary_basic.Dev) ~provision:EN.Fetched ()
        in
        [ { app with runtime_dep = Some ext } ]
  in
  match apps with
  | [] -> [ base ]
  | _ ->
      let variants = List.map apps ~f:resolve in
      let rec cart = function
        | [] -> [ [] ]
        | xs :: rest ->
            List.concat_map xs ~f:(fun x ->
                List.map (cart rest) ~f:(fun t -> x :: t))
      in
      List.map (cart variants) ~f:(fun avs -> non_apps @ avs)

(** Union in first-appearance order — the deduped set of artifacts a
    project {b inspects} across its actions. This is the detection
    scope inventory the forecast-agnostic [project] derives instead
    of a hand-authored watchlist of "where failures fire". Mirrors
    {!Canary_scenario.related_artifacts_of_actions} but consumes-only. *)
let consumed_artifacts_of_actions (actions : action list) : artifact_kind list =
  List.concat_map actions ~f:consumes_of_action
  |> List.fold ~init:[] ~f:(fun acc a ->
      if List.mem acc a ~equal:Poly.equal then acc else acc @ [ a ])

(** Per-step verdict the diagram renderer uses. Lives here because the
    natural place to attach status to an action graph is alongside the
    action/node definitions; the actual mermaid emission lives in
    [Canary_diagram]. *)
type node_status =
  | Done       (* expected success, confirmed *)
  | Done_fail  (* expected failure, confirmed *)
  | Failed     (* unexpected: expected success but failed, or expected failure but succeeded/mismatched *)
  | Skipped
  | Not_in_spec
