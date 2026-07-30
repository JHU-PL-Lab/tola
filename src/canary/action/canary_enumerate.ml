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

(** Concise artifact label for display. *)
let string_of_artifact = function
  | Source -> "source"
  | Headers -> "headers"
  | Lib -> "lib"
  | Binding l -> "binding:" ^ Canary_lang.string_of_lang l
  | App -> "app"

(** A per-artifact cell: how the artifact is provided, and at which version
    (ssot §4.2.2). Version is only meaningful when provided (ignored for
    [Absent]). *)
type placement = { provision : provision; version : Canary_basic.channel }

(** An assignment: one placement per artifact. *)
type assignment = (artifact * placement) list

(** One point of the scenario space: an assignment plus an optional mutation
    on one *provided* artifact ([None] = the positive scenario). *)
type 'm point = { assignment : assignment; mutation : (artifact * 'm) option }

let equal_version (a : Canary_basic.channel) (b : Canary_basic.channel) : bool =
  Poly.equal a b

let string_of_version = function
  | Canary_basic.Dev -> "dev"
  | Canary_basic.Stable -> "stable"

let placement_of (a : assignment) (art : artifact) : placement option =
  List.Assoc.find a art ~equal:equal_artifact

let provision_of (a : assignment) (art : artifact) : provision =
  match placement_of a art with Some p -> p.provision | None -> Absent

let version_of (a : assignment) (art : artifact) : Canary_basic.channel =
  match placement_of a art with Some p -> p.version | None -> Canary_basic.Dev

let provided (a : assignment) (art : artifact) : bool =
  not (equal_provision (provision_of a art) Absent)

(** Dependency + version filter (product-then-filter, §4.2 / §4.2.2): a lib
    [Built] from source needs the source present; any provided binding needs
    the lib present; and (source-primary) a [Built] lib inherits the
    source's version. A binding's version may still differ from the lib's —
    that difference is the interesting version *mismatch*. *)
let assignment_ok (a : assignment) : bool =
  let lib = provision_of a Lib in
  (not (equal_provision lib Built) || provided a Source)
  && (not (equal_provision lib Built)
     || equal_version (version_of a Lib) (version_of a Source))
  && List.for_all a ~f:(fun (art, pl) ->
         match art with
         | Binding _ ->
             equal_provision pl.provision Absent || provided a Lib
         | _ -> true)

(* The product over [artifacts] of (provision × version) placements. *)
let rec assignments_of (artifacts : artifact list) (provisions : provision list)
    (versions : Canary_basic.channel list) : assignment list =
  match artifacts with
  | [] -> [ [] ]
  | art :: rest ->
      let tails = assignments_of rest provisions versions in
      List.concat_map provisions ~f:(fun pv ->
          List.concat_map versions ~f:(fun ver ->
              List.map tails ~f:(fun t ->
                  (art, { provision = pv; version = ver }) :: t)))

(** The full enumeration algorithm: the product of *valid* assignments ×
    (positive + each applicable mutation). A mutation is applicable to an
    assignment only when its target artifact is provided (§4.2: "a mutation
    applies only to a provided artifact"). *)
let enumerate ~(artifacts : artifact list) ~(provisions : provision list)
    ~(versions : Canary_basic.channel list) ~(mutations : (artifact * 'm) list) :
    'm point list =
  assignments_of artifacts provisions versions
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
  mutation : (artifact * 'm) level;
}

(** Instantiate the algorithm with a config, given each axis's universe (its
    full value set). Provision/version [Free] = one representative (the head
    of the universe — a project orders its universe so the representative is
    first); mutation [Free] = the [None] baseline, i.e. no injected fault
    (the positive point is always present), so it resolves to no placements. *)
let run_config ~(artifacts : artifact list) ~(all_provisions : provision list)
    ~(all_versions : Canary_basic.channel list)
    ~(all_mutations : (artifact * 'm) list) (cfg : 'm config) : 'm point list =
  let resolve lvl all =
    match lvl with
    | Free -> ( match all with x :: _ -> [ x ] | [] -> [] )
    | Subset vs -> vs
    | Full -> all
  in
  let provisions = resolve cfg.provision all_provisions in
  let versions = resolve cfg.version all_versions in
  let mutations =
    match cfg.mutation with
    | Free -> []  (* the None baseline — positive point only *)
    | Subset vs -> vs
    | Full -> all_mutations
  in
  enumerate ~artifacts ~provisions ~versions ~mutations

(** tiny's config: provision [Free] (collapse to one representative,
    [Built] — the whole pipeline built locally), mutation [Full] (walk every
    defect). Source-[Built] here just means "present locally" — the source
    is the pipeline root, its provision degenerate. *)
let tiny_slice ~(artifacts : artifact list) ~(mutations : (artifact * 'm) list)
    : 'm point list =
  run_config ~artifacts ~all_provisions:[ Built ]
    ~all_versions:Canary_basic.single_channel ~all_mutations:mutations
    { provision = Free; version = Free; mutation = Full }

(** A general project's config: provision [Full] (walk the provision axis
    over the project's universe), mutation [Free] (positive only). Yields
    one positive point per valid provision assignment (ssl `sys` = all
    [Fetched], ssl `src` = all [Built], … among them). *)
let general_slice ~(artifacts : artifact list) ~(provisions : provision list)
    ~(versions : Canary_basic.channel list) : 'm point list =
  run_config ~artifacts ~all_provisions:provisions ~all_versions:versions
    ~all_mutations:[] { provision = Full; version = Full; mutation = Free }

let string_of_provision = Canary_store.string_of_provision

(** Read a slot's provision off a concrete action set (which action-graph
    verbs a variant runs): [Build_*] ⇒ [Built], [Fetch _] ⇒ [Fetched], else
    [Absent]. This is the inverse of §6.5's "provision decides which actions
    run" — recovering the provision coordinate from a variant's steps, so a
    general project's hand-written variants can be rendered as enumeration algorithm
    assignments. *)
let provision_of_actions (acts : Canary_basic.action list) (art : artifact) :
    provision =
  let has a = List.mem acts a ~equal:Poly.equal in
  match art with
  | Source -> if has (Canary_basic.Fetch Canary_basic.Source) then Fetched else Absent
  | Lib ->
      if has Canary_basic.Build_lib then Built
      else if has (Canary_basic.Fetch Canary_basic.Lib) then Fetched
      else Absent
  | Binding l ->
      if has (Canary_basic.Build_binding l) then Built
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
let assignment_of_actions ~(artifacts : artifact list)
    ~(version : Canary_basic.channel) (acts : Canary_basic.action list) :
    assignment =
  List.map artifacts ~f:(fun art ->
      (art, { provision = provision_of_actions acts art; version }))

(** Pretty an assignment as "source=fetched@dev lib=built@dev …" (version
    shown only where the artifact is provided). *)
let string_of_assignment (a : assignment) : string =
  String.concat ~sep:" "
    (List.map a ~f:(fun (art, pl) ->
         let base = string_of_artifact art ^ "=" ^ string_of_provision pl.provision in
         if equal_provision pl.provision Absent then base
         else base ^ "@" ^ string_of_version pl.version))
