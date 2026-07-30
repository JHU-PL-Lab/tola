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

(* [provision] and [slot] are base vocabulary — defined in
   [Canary_store] / [Canary_basic] and re-exported here (constructor
   re-export keeps existing [Canary_enumerate.Built] / [.Slot_source]
   references working). See those base modules for the docs. *)
type provision = Canary_store.provision =
  | Absent | Fetched | Built | Vendored
[@@deriving show, eq]

type slot = Canary_basic.slot =
  | Slot_source | Slot_lib | Slot_binding of Canary_lang.lang
[@@deriving show, eq]

let string_of_slot = Canary_basic.string_of_slot

(** A per-slot cell: how the artifact is provided, and at which version
    (ssot §4.2.2). Version is only meaningful when provided (ignored for
    [Absent]). *)
type placement = { provision : provision; version : Canary_basic.channel }

(** An assignment: one placement per slot. *)
type assignment = (slot * placement) list

(** One point of the scenario space: an assignment plus an optional mutation
    on one *provided* slot ([None] = the positive scenario). *)
type 'm point = { assignment : assignment; mutation : (slot * 'm) option }

let equal_version (a : Canary_basic.channel) (b : Canary_basic.channel) : bool =
  Poly.equal a b

let string_of_version = function
  | Canary_basic.Dev -> "dev"
  | Canary_basic.Stable -> "stable"

let placement_of (a : assignment) (s : slot) : placement option =
  List.Assoc.find a s ~equal:equal_slot

let provision_of (a : assignment) (s : slot) : provision =
  match placement_of a s with Some p -> p.provision | None -> Absent

let version_of (a : assignment) (s : slot) : Canary_basic.channel =
  match placement_of a s with Some p -> p.version | None -> Canary_basic.Dev

let provided (a : assignment) (s : slot) : bool =
  not (equal_provision (provision_of a s) Absent)

(** Dependency + version filter (product-then-filter, §4.2 / §4.2.2): a lib
    [Built] from source needs the source present; any provided binding needs
    the lib present; and (source-primary) a [Built] lib inherits the
    source's version. A binding's version may still differ from the lib's —
    that difference is the interesting version *mismatch*. *)
let assignment_ok (a : assignment) : bool =
  let lib = provision_of a Slot_lib in
  (not (equal_provision lib Built) || provided a Slot_source)
  && (not (equal_provision lib Built)
     || equal_version (version_of a Slot_lib) (version_of a Slot_source))
  && List.for_all a ~f:(fun (s, pl) ->
         match s with
         | Slot_binding _ ->
             equal_provision pl.provision Absent || provided a Slot_lib
         | _ -> true)

(* The product over [slots] of (provision × version) placements. *)
let rec assignments_of (slots : slot list) (provisions : provision list)
    (versions : Canary_basic.channel list) : assignment list =
  match slots with
  | [] -> [ [] ]
  | s :: rest ->
      let tails = assignments_of rest provisions versions in
      List.concat_map provisions ~f:(fun pv ->
          List.concat_map versions ~f:(fun ver ->
              List.map tails ~f:(fun t ->
                  (s, { provision = pv; version = ver }) :: t)))

(** The full enumeration algorithm: the product of *valid* assignments ×
    (positive + each applicable mutation). A mutation is applicable to an
    assignment only when its target slot is provided (§4.2: "a mutation
    applies only to a provided artifact"). *)
let enumerate ~(slots : slot list) ~(provisions : provision list)
    ~(versions : Canary_basic.channel list) ~(mutations : (slot * 'm) list) :
    'm point list =
  assignments_of slots provisions versions
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
  mutation : (slot * 'm) level;
}

(** Instantiate the algorithm with a config, given each axis's universe (its
    full value set). Provision/version [Free] = one representative (the head
    of the universe — a project orders its universe so the representative is
    first); mutation [Free] = the [None] baseline, i.e. no injected fault
    (the positive point is always present), so it resolves to no placements. *)
let run_config ~(slots : slot list) ~(all_provisions : provision list)
    ~(all_versions : Canary_basic.channel list)
    ~(all_mutations : (slot * 'm) list) (cfg : 'm config) : 'm point list =
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
  enumerate ~slots ~provisions ~versions ~mutations

(** tiny's config: provision [Free] (collapse to one representative,
    [Built] — the whole pipeline built locally), mutation [Full] (walk every
    defect). Source-[Built] here just means "present locally" — the source
    is the pipeline root, its provision degenerate. *)
let tiny_slice ~(slots : slot list) ~(mutations : (slot * 'm) list) :
    'm point list =
  run_config ~slots ~all_provisions:[ Built ]
    ~all_versions:Canary_basic.single_channel ~all_mutations:mutations
    { provision = Free; version = Free; mutation = Full }

(** A general project's config: provision [Full] (walk the provision axis
    over the project's universe), mutation [Free] (positive only). Yields
    one positive point per valid provision assignment (ssl `sys` = all
    [Fetched], ssl `src` = all [Built], … among them). *)
let general_slice ~(slots : slot list) ~(provisions : provision list)
    ~(versions : Canary_basic.channel list) : 'm point list =
  run_config ~slots ~all_provisions:provisions ~all_versions:versions
    ~all_mutations:[] { provision = Full; version = Full; mutation = Free }

let string_of_provision = Canary_store.string_of_provision

(** Read a slot's provision off a concrete action set (which action-graph
    verbs a variant runs): [Build_*] ⇒ [Built], [Fetch _] ⇒ [Fetched], else
    [Absent]. This is the inverse of §6.5's "provision decides which actions
    run" — recovering the provision coordinate from a variant's steps, so a
    general project's hand-written variants can be rendered as enumeration algorithm
    assignments. *)
let provision_of_actions (acts : Canary_basic.action list) (s : slot) :
    provision =
  let has a = List.mem acts a ~equal:Poly.equal in
  match s with
  | Slot_source -> if has (Canary_basic.Fetch Canary_basic.Source) then Fetched else Absent
  | Slot_lib ->
      if has Canary_basic.Build_lib then Built
      else if has (Canary_basic.Fetch Canary_basic.Lib) then Fetched
      else Absent
  | Slot_binding l ->
      if has (Canary_basic.Build_binding l) then Built
      else if has (Canary_basic.Fetch (Canary_basic.Binding l)) then Fetched
      else Absent

(** The assignment a variant's action set implies: one provision per slot
    (via [provision_of_actions]), all at the variant's [version] (a variant
    picks a single version — actions do not encode version, so it is passed
    in; per-slot version *mismatch* is a capability of the algorithm the
    hand-written variants don't yet exercise, §4.2.2). *)
let assignment_of_actions ~(slots : slot list)
    ~(version : Canary_basic.channel) (acts : Canary_basic.action list) :
    assignment =
  List.map slots ~f:(fun s ->
      (s, { provision = provision_of_actions acts s; version }))

(** Pretty an assignment as "source=fetched@dev lib=built@dev …" (version
    shown only where the slot is provided). *)
let string_of_assignment (a : assignment) : string =
  String.concat ~sep:" "
    (List.map a ~f:(fun (s, pl) ->
         let base = string_of_slot s ^ "=" ^ string_of_provision pl.provision in
         if equal_provision pl.provision Absent then base
         else base ^ "@" ^ string_of_version pl.version))
