(** [Canary_enumerate] — the shared abstract enumeration core (ssot §4.2).

    **One** enumeration algorithm over (provision assignment) × (mutation),
    product-then-filter. tiny and every general project are two orthogonal
    *projections* of the same product:

    - **tiny** = fix provision = all [Built], walk the mutation axis
      (§5's `Bs.N`).
    - **a general project** = fix mutation = none, walk the provision axis
      (its variants; ssl `sys` = all [Fetched], ssl `src` = all [Built]).

    This module is the enumeration algorithm. [run_config] instantiates it
    with a [config] — one [level] (`Free`/`Subset`/`Full`) per axis (ssot
    §4.2); [tiny_slice] and [general_slice] are the two canonical configs.
    Backing tiny's designed 22 and each project's variants
    out to *be* projections of this enumeration algorithm (replacing the two hand-written
    enumerations in `canary_scenario.ml` / the per-project variant lists) is
    the convergence named in §4.2 — a later round. For now the enumeration algorithm stands
    alongside them, with tests pinning each projection's shape.

    Separate file only while it stands alongside the hand-written
    enumerations: once the convergence lands (this enumeration algorithm backing both),
    **fold this into `canary_scenario.ml` (or a scenario util)** — it is the
    scenario-enumeration core and belongs beside the scenario types.

    The enumeration algorithm is **polymorphic in the mutation** (['m]): it is pure
    combinatorics — which artifacts are provided and from where, and which
    provided artifact is mutated — agnostic to what a mutation *means*. tiny
    supplies real mutations; a general project supplies none. *)

open Base

(* [provision] is base vocabulary (Canary_store); the enumeration ranges
   over [artifact] = the full artifact set (Canary_basic.artifact_kind),
   re-exported here so [Canary_enumerate.Source] / [.Built] resolve. Every
   artifact carries a placement (provision × version); Headers/App are
   simply artifacts whose provision is usually [Absent] (not independently
   provided) — no special subset type. *)
type provision = Canary_store.provision =
  | Absent | Fetched | Built | Vendored
[@@deriving show, eq]

type artifact = Canary_basic.artifact_kind =
  | Source | Headers | Lib | Binding of Canary_lang.lang | App
[@@deriving show, eq]

(** Concise artifact label for display (coarse kind only). *)
let string_of_artifact = function
  | Source -> "source"
  | Headers -> "headers"
  | Lib -> "lib"
  | Binding l -> "binding-" ^ Canary_lang.string_of_lang l
  | App -> "app"

(* ── precise artifact identity (ssot §4.2.3) ──
   The coarse [artifact] (= Canary_basic.artifact_kind) can't tell two
   bindings of one lib apart (cext vs ctypes) or two apps apart (direct vs
   via-helper), and enriching it would touch ~200 mechanism-agnostic sites.
   So the enumeration's identity is the pair (artifact, artifact_ext) — the
   coarse kind + an [ext] that refines a binding by its mechanism and an app
   by its wiring. When this settles, the pair folds into an enriched
   artifact_kind and the rest of the project migrates (the diagram, ~61
   sites, last). *)

(** How an app consumes the library (decision 2, ssot §4.2.3). *)
type app_wiring = Direct | Via_helper [@@deriving show, eq]

let string_of_app_wiring = function Direct -> "direct" | Via_helper -> "via_helper"

(** Per-kind extension distinguishing several artifacts of the same coarse
    kind: a binding by its mechanism, an app by its wiring. *)
type artifact_ext =
  | Ext_none  (** source / headers / lib *)
  | Ext_mechanism of Canary_mechanism.mechanism  (** a binding *)
  | Ext_wiring of app_wiring  (** an app *)
[@@deriving show, eq]

(** The enumeration's precise artifact identity — the coarse [kind] plus its
    [ext] (≡ the (artifact, artifact_ext) pair, as a record so it extends
    cleanly). [kind_of] projects back to the coarse [Canary_basic.artifact_kind]. *)
type artifact_id = { kind : artifact; ext : artifact_ext } [@@deriving show, eq]

let kind_of (id : artifact_id) : artifact = id.kind
let ext_of (id : artifact_id) : artifact_ext = id.ext

(* smart constructors *)
let a_source : artifact_id = { kind = Source; ext = Ext_none }
let a_headers : artifact_id = { kind = Headers; ext = Ext_none }
let a_lib : artifact_id = { kind = Lib; ext = Ext_none }

let a_binding (lang : Canary_lang.lang) (m : Canary_mechanism.mechanism) :
    artifact_id =
  { kind = Binding lang; ext = Ext_mechanism m }

let a_app (w : app_wiring) : artifact_id = { kind = App; ext = Ext_wiring w }

(** Concise label for a precise identity: coarse kind + its extension. *)
(* The canonical id string is BORN-SAFE (filesystem + env-var safe): the ext
   delimiter is '-', not ':'. ':' is the PYTHONPATH/LD_LIBRARY_PATH separator, so
   a ':' here would split those vars when the id lands in a workspace dir name
   (the bug that made only lib scenarios detect). Safe by construction ⇒ no
   downstream sanitizer needed; a prettier display form can be a separate pp if
   ever wanted. Nothing parses this string back, so the delimiter is free. *)
let string_of_id (id : artifact_id) : string =
  let base = string_of_artifact id.kind in
  match id.ext with
  | Ext_none -> base
  | Ext_mechanism m -> base ^ "-" ^ Canary_mechanism.string_of_mechanism m
  | Ext_wiring w -> base ^ "-" ^ string_of_app_wiring w

(* DISPLAY-ONLY pretty form: the ':' delimiter reads the kind:lang:mechanism
   hierarchy (binding:ocaml:cstubs). NEVER use for keys/paths/labels — those take
   the born-safe [string_of_id]/[string_of_artifact] above. Only human-facing
   views (e.g. `canary spec`) should call these. *)
let pretty_artifact = function
  | Source -> "source"
  | Headers -> "headers"
  | Lib -> "lib"
  | Binding l -> "binding:" ^ Canary_lang.string_of_lang l
  | App -> "app"

let pretty_id (id : artifact_id) : string =
  let base = pretty_artifact id.kind in
  match id.ext with
  | Ext_none -> base
  | Ext_mechanism m -> base ^ ":" ^ Canary_mechanism.string_of_mechanism m
  | Ext_wiring w -> base ^ ":" ^ string_of_app_wiring w

(** An artifact instance's version identity (ssot §4.2.2, P2a). A build is a
    release [channel] plus a [quality]: a [Good] build, or a [Bad]-tagged
    build that breaks a contract. The tag is OPAQUE here — the enumeration
    treats a bad build like any other version; only a project's materializer
    knows a tag corresponds to a mutation (the mutation-agnostic principle,
    status §1a). This "special version string" folds the old separate
    mutation-tag into the version identity. *)
type quality = Good | Bad of string [@@deriving show, eq]

type build_id = { channel : Canary_basic.channel; quality : quality }
[@@deriving show, eq]

let good (channel : Canary_basic.channel) : build_id = { channel; quality = Good }

let string_of_build_id (b : build_id) : string =
  (match b.channel with
   | Canary_basic.Dev -> "dev"
   | Canary_basic.Stable -> "stable")
  ^ (match b.quality with Good -> "" | Bad t -> "#" ^ t)

(** A per-artifact cell: how the artifact is provided, and at which version
    identity (ssot §4.2.2). Version is only meaningful when provided (ignored
    for [Absent]). *)
type placement = { provision : provision; version : build_id }

(** An assignment: one placement per (precise) artifact identity. *)
type assignment = (artifact_id * placement) list

(** One point of the scenario space: an assignment plus an optional mutation
    on one *provided* artifact ([None] = the positive scenario). *)
type 'm point =
  { assignment : assignment; mutation : (artifact_id * 'm) option }

let equal_version : build_id -> build_id -> bool = equal_build_id

let string_of_version : build_id -> string = string_of_build_id

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

let any_binding_provided (a : assignment) : bool =
  List.exists a ~f:(fun (id, pl) ->
      match id.kind with
      | Binding _ -> not (equal_provision pl.provision Absent)
      | _ -> false)

(** Dependency + version filter (product-then-filter, §4.2 / §4.2.2): a lib
    [Built] from source needs the source present; any provided binding needs
    the lib present; any provided app needs a binding to consume (an app with
    no binding is a degenerate combination); and (source-primary) a [Built]
    lib inherits the source's version. A binding's version may still differ
    from the lib's — that difference is the interesting version *mismatch*.
    (The app→binding dependency is "any binding" for now; making it the app's
    *own language* binding needs App to carry a lang — ssot §4.2.3.) *)
let assignment_ok (a : assignment) : bool =
  let lib = provision_of a a_lib in
  (* A Built lib needs its source present AND at the same version — but only when
     [a_source] is a DECLARED artifact (tiny models source as a separate vendored
     artifact). A project that models Built as self-contained (fetches source
     internally, e.g. sqlite's amalgamation) omits [a_source], and the check is
     moot. *)
  let source_declared = Option.is_some (placement_of a a_source) in
  (not (equal_provision lib Built) || not source_declared || provided a a_source)
  && (not (equal_provision lib Built) || not source_declared
     || equal_version (version_of a a_lib) (version_of a a_source))
  && List.for_all a ~f:(fun (id, pl) ->
         match kind_of id with
         | Binding _ ->
             equal_provision pl.provision Absent || provided a a_lib
         | App -> equal_provision pl.provision Absent || any_binding_provided a
         | _ -> true)

(* The product over [artifacts] (precise identities) of (provision × version)
   placements. [provisions_of] is PER-ARTIFACT (A1): each artifact draws from its
   own provision universe — real projects are heterogeneous (source=Fetched,
   lib={Fetched,Built}, binding=Fetched); a single global list was a tiny-shaped
   simplification (tiny is uniform). *)
let rec assignments_of (artifacts : artifact_id list)
    (provisions_of : artifact_id -> provision list)
    (versions : Canary_basic.channel list) : assignment list =
  match artifacts with
  | [] -> [ [] ]
  | id :: rest ->
      let tails = assignments_of rest provisions_of versions in
      List.concat_map (provisions_of id) ~f:(fun pv ->
          List.concat_map versions ~f:(fun ver ->
              List.map tails ~f:(fun t ->
                  (id, { provision = pv; version = good ver }) :: t)))

(** The full enumeration algorithm: the product of *valid* assignments ×
    (positive + each applicable mutation). A mutation is applicable to an
    assignment only when its target artifact is provided (§4.2: "a mutation
    applies only to a provided artifact"). *)
let enumerate ~(artifacts : artifact_id list)
    ~(provisions_of : artifact_id -> provision list)
    ~(versions : Canary_basic.channel list)
    ~(mutations : (artifact_id * 'm) list) : 'm point list =
  assignments_of artifacts provisions_of versions
  |> List.filter ~f:assignment_ok
  |> List.concat_map ~f:(fun a ->
         let positive = { assignment = a; mutation = None } in
         let muts =
           List.filter_map mutations ~f:(fun (s, m) ->
               if provided a s then Some { assignment = a; mutation = Some (s, m) }
               else None)
         in
         positive :: muts)

(** How much of an axis a config expands (ssot §4.2): [Free] collapses to
    one representative; [Subset] is a curated list; [Full] is every value. *)
type 'a level = Free | Subset of 'a list | Full

(** A config assigns one [level] per axis. Instantiating the algorithm with
    a config yields a project's concrete scenarios (ssot §4.2 — "every use
    is one config"). Today the ranged axes are provision and mutation;
    version / mechanism / app-wiring are axes still to add, each becoming a
    field here. *)
type 'm config = {
  provision : provision level;
  version : Canary_basic.channel level;
  mutation : (artifact_id * 'm) level;
}

(** Instantiate the algorithm with a config, given each axis's universe (its
    full value set). Provision/version [Free] = one representative (the head
    of the universe — a project orders its universe so the representative is
    first); mutation [Free] = the [None] baseline, i.e. no injected fault
    (the positive point is always present), so it resolves to no placements. *)
let run_config ~(artifacts : artifact_id list)
    ~(all_provisions_of : artifact_id -> provision list)
    ~(all_versions : Canary_basic.channel list)
    ~(all_mutations : (artifact_id * 'm) list) (cfg : 'm config) : 'm point list =
  let resolve lvl all =
    match lvl with
    | Free -> ( match all with x :: _ -> [ x ] | [] -> [] )
    | Subset vs -> vs
    | Full -> all
  in
  (* provision level applies PER-ARTIFACT to that artifact's own universe *)
  let provisions_of id = resolve cfg.provision (all_provisions_of id) in
  let versions = resolve cfg.version all_versions in
  let mutations =
    match cfg.mutation with
    | Free -> []  (* the None baseline — positive point only *)
    | Subset vs -> vs
    | Full -> all_mutations
  in
  enumerate ~artifacts ~provisions_of ~versions ~mutations

(** tiny's config: provision [Free] (collapse to one representative,
    [Built] — the whole pipeline built locally), mutation [Full] (walk every
    defect). Source-[Built] here just means "present locally" — the source
    is the pipeline root, its provision degenerate. *)
let tiny_slice ~(artifacts : artifact_id list)
    ~(mutations : (artifact_id * 'm) list) : 'm point list =
  run_config ~artifacts ~all_provisions_of:(fun _ -> [ Built ])
    ~all_versions:Canary_basic.single_channel ~all_mutations:mutations
    { provision = Free; version = Free; mutation = Full }

(** A general project's config: provision [Full] (walk the provision axis
    over the project's universe), mutation [Free] (positive only). Yields
    one positive point per valid provision assignment (ssl `sys` = all
    [Fetched], ssl `src` = all [Built], … among them). *)
(* [~provisions] here is the GLOBAL convenience form (all artifacts share one
   universe); [run_config] itself is per-artifact (A1). A project with
   heterogeneous provisions calls [run_config ~all_provisions_of] directly. *)
let general_slice ~(artifacts : artifact_id list)
    ~(provisions : provision list)
    ~(versions : Canary_basic.channel list) : 'm point list =
  run_config ~artifacts ~all_provisions_of:(fun _ -> provisions)
    ~all_versions:versions ~all_mutations:[]
    { provision = Full; version = Full; mutation = Free }

(** A2 — fold a [point] into a concrete [assignment], the form the run/materialize
    consume. The algorithm keeps the mutation SEPARATE from the all-Good
    assignment ([point.mutation]); the run wants it FOLDED into the target
    artifact's version [quality = Bad tag] (the mutation-agnostic identity, §4.2.2
    P2a). [tag] projects the polymorphic mutation to its opaque string tag. A
    positive point ([mutation = None]) is already an all-Good assignment. *)
let assignment_of_point ~(tag : 'm -> string) (p : 'm point) : assignment =
  match p.mutation with
  | None -> p.assignment
  | Some (aid, m) ->
      List.map p.assignment ~f:(fun (id, pl) ->
          if equal_artifact_id id aid then
            (id, { pl with version = { pl.version with quality = Bad (tag m) } })
          else (id, pl))

(** A3 — a project's DECLARED enumeration axes (static data): its artifacts, each
    artifact's provision universe (A1), the version channels, the mutation
    universe ([[]] for a positive-only real project; tiny is the only one that
    populates it, [’m = string] bad-tags), and a [config] level per axis. The
    consumer computes the scenarios — a project DECLARES, canary ENUMERATES. This
    is what replaces a hand-built [pr_enumerate] closure. *)
type 'm project_spec = {
  ps_artifacts : artifact_id list;
  ps_provisions_of : artifact_id -> provision list;
  ps_versions : Canary_basic.channel list;
  ps_mutations : (artifact_id * 'm) list;
  ps_config : 'm config;
}

(** Enumerate a declared spec into concrete assignments: run the algorithm over
    the axes, then fold each point's mutation into its version quality (A2). *)
let assignments_of_spec ~(tag : 'm -> string) (s : 'm project_spec) :
    assignment list =
  run_config ~artifacts:s.ps_artifacts ~all_provisions_of:s.ps_provisions_of
    ~all_versions:s.ps_versions ~all_mutations:s.ps_mutations s.ps_config
  |> List.map ~f:(assignment_of_point ~tag)

let string_of_provision = Canary_store.string_of_provision

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
      if has Canary_basic.Build_lib then Built
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
let string_of_assignment (a : assignment) : string =
  String.concat ~sep:" "
    (List.map a ~f:(fun (id, pl) ->
         let base = string_of_id id ^ "=" ^ string_of_provision pl.provision in
         if equal_provision pl.provision Absent then base
         else base ^ "@" ^ string_of_version pl.version))
